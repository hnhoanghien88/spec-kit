# Quickstart: Validating Sales Order Missing-Compliance Alert

## Prerequisites

- `compliance-sys-api` running locally against a MySQL database that already has `compl_masters`, `compl_compliances`, `compl_references`, etc. populated (existing compliance data), plus network/config access to the Dynamics 365 data source used by `IComplDynamicsService`/`IViewCompliancesService` (same config this feature's dependencies already require today for `DynController`/`ViewCompliancesController` to work).
- The `compl_so_missing` table exists in that database. If the database was provisioned before this feature, run the new migration manually (per research.md R7):
  ```sql
  SOURCE compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Migration/17_create_compl_so_missing.sql;
  ```
  (Fresh databases created after this feature ships get the table automatically via `Sqls/Tables/compl_so_missing.sql` at first-run `DatabaseInitializer` time — no manual step needed there.)
- At least one currently "open" sales order (per `SalesStatus = 'Open order'` in the Dynamics source) that is known to have at least one MISSING compliance item, to get a non-empty result. Ask a Compliance Admin which sales order code to use, or pick one already visible as MISSING in the existing Compliance view screen.

## Steps

1. **Confirm the reftype-18 fix is in place** (research.md R2): call the existing endpoint directly and confirm it no longer returns an empty list —
   ```http
   POST /api/dynamics/reference?refType=18&page=1&pageSize=50
   Content-Type: application/json

   []
   ```
   Expected: `data.items` contains open sales orders (non-empty, assuming open sales orders exist), each with `code`, `custAccount`, `deliveryDate` populated.

2. **Trigger the new alert endpoint**:
   ```http
   GET /api/notification/test-sales-order-alert
   ```
   Expected: `200 OK` with `succeeded: true` (see contracts/test-sales-order-alert.md). This call may take longer than `test-alert` since it loops every open sales order.

3. **Verify the `compl_so_missing` snapshot**:
   ```sql
   SELECT SalesId, MasterCode, Code, Status FROM compl_so_missing ORDER BY SalesId;
   ```
   Expected: one row per (open sales order, MISSING compliance item) as of this run; a sales order known to be fully compliant has zero rows; a sales order known to have N missing items has exactly N rows, none left over from a prior run.

4. **Re-run and confirm idempotency** (spec.md Acceptance Scenario 4, revised 2026-08-04): repeat step 2, then step 3's query again. The whole table is cleared once at the start of the run before any sales order is evaluated (no longer a per-`SalesId` delete), so the resulting rows should reflect only this run's evaluation — not accumulate additional rows from the previous run for any sales order code.

5. **Verify the alert was sent**: check the mailbox configured for the resolved recipients (per research.md R4, derived from each row's `ResponsibleGroupsJson`/`AlertGroupsJson`) for one consolidated email listing every current `compl_so_missing` row, and check the `compl_notifications` table (or the notification bell in the UI, if reachable) for one new row per recipient per compliance item.
   - **(2026-08-10; revised 2026-08-18)** Confirm the email table shows exactly these 13 columns, in this order: Master code, Master name, Status, Code, Name, Valid from, Valid to, Days remaining, Responsible emails, Description, Type, Product, Product name — no Sales order column (spec.md FR-012).
   - For a row whose `Code` is blank, confirm Status reads "Missing"; for a row with a `Code` and a `Valid to` date already in the past, confirm Status reads "Expired"; otherwise confirm it reads "Valid" (FR-013).
   - For a row with no `Valid to` date, confirm Days remaining is blank; for a `Valid to` date N days in the future, confirm it reads "N days left"; for a `Valid to` date N days in the past, confirm it reads "-N days left" (FR-014).
   - **(2026-08-10, Excel attachment; revised 2026-08-18, 2026-08-20)** Confirm the email carries exactly one `.xlsx` attachment named `compl-sales-order-missing-<yyyyMMddHHmmss>` (timestamp matching roughly when the alert was sent), and that opening it shows the same 14 columns, in the same order, with the same row values as the email body (FR-015/FR-016).
   - **(2026-08-18; revised 2026-08-20)** If step 3's `compl_so_missing` snapshot has two or more rows sharing the same `MasterCode`, `Code`, `MappedRefTypeCode`, `MappedInputValue` combination (e.g. two different sales orders missing the same compliance item), confirm they appear as exactly one row in both the email body and the Excel attachment (FR-008, SC-007).
   - **(2026-08-20)** For each row shown as Status = "Expired" in the email body (highlighted yellow there already), open the Excel attachment and confirm that same row is also highlighted with the same yellow background; confirm rows with Status "Missing" or "Valid" have no yellow highlight in either the email or the attachment (FR-018, SC-008).
   - **(2026-08-20, Sales order column)** Confirm the last column in both the email body and the Excel attachment is "Sales order". For a row built from the deduplicated combination in the prior check (two or more underlying sales orders), confirm that column shows every distinct contributing sales order code combined into one cell, e.g. "SO1, SO2" (FR-019, SC-009). For a row that came from only one underlying sales order, confirm the column shows just that one code with no separator.
   - **(2026-08-21, header styling)** Open the Excel attachment and compare its header row (row 1) to the email body's header row: confirm both have the same shaded background color, bold header text, and cell borders — not a plain/unstyled header row in the attachment (FR-022, SC-011).

6. **Verify the empty-run case** (FR-010): temporarily point at an environment/sales-order set where every open sales order is fully compliant (or verify by inspection that step 3's table is empty after a run), and confirm no email/notification was produced for that run.

7. **Verify the check-date sentinel fallback** (2026-08-21, FR-020/FR-021, SC-010): pick an open sales order with no delivery date recorded (or the `1900-01-01` placeholder) that has at least one compliance master whose validity window has already started as of today — e.g. SO006831 with masters MAS-01021/MAS-01081 from the original bug report.
   - Open that sales order on the compliance screen (`compliance-view-so?ref-type=11&codes=<SO code>&check-date=<today>`) and confirm the relevant master(s) do **not** show as missing.
   - Trigger step 2's alert endpoint and re-run step 3's query filtered to that sales order (`WHERE SalesId = '<SO code>'`); confirm no row is stored for that master combination — matching what the screen shows.
   - As a regression check, pick a different open sales order that has a genuine (non-placeholder) delivery date and at least one currently missing master; confirm it is still correctly stored as missing after this update, unchanged from before.

8. **Verify the diagnostic without-Sales-order trigger** (2026-08-31, FR-023/FR-024, SC-012; see [contracts/test-sales-order-alert-without-salesid.md](./contracts/test-sales-order-alert-without-salesid.md)):
   ```http
   GET /api/notification/test-sales-order-alert-without-salesId
   ```
   Expected: `200 OK` with `succeeded: true`, and `compl_so_missing` refreshed exactly as step 2/3 already verify (same shared refresh logic).
   - Check the mailbox for the resulting email: confirm the table shows exactly 13 columns, in the same order as step 5's list, but with **no "Sales order" column at all** (not present, not shown blank).
   - Open the accompanying `.xlsx` attachment (same `compl-sales-order-missing-<yyyyMMddHHmmss>` naming pattern as step 5) and confirm it also has exactly 13 columns, matching the email body record-for-record, with no Sales order column.
   - Confirm Status/Days remaining values, Expired-row yellow highlighting, and the Excel header's shaded/bold/bordered styling all still behave exactly as verified in step 5 for `test-sales-order-alert` — unaffected by the missing column.
   - Confirm the email's title (subject line and the heading shown above the table in the body) reads "Missing compliance Information" — not "Sales orders with missing compliance" (FR-025, SC-013).
   - Re-run step 2 (`test-sales-order-alert`) afterward and confirm its email/Excel still show the full 14-column layout with the Sales order column present, and its title still reads "Sales orders with missing compliance" — this new endpoint does not alter the existing trigger's output.
   - If `compl_so_missing` is empty after the refresh, confirm no email/notification/attachment is produced for this trigger either (same FR-010 rule).

9. **Verify per-trigger recipient-group exclusion** (2026-09-03, FR-026/FR-027/FR-028, SC-014/SC-015): pick a current `compl_so_missing` snapshot whose records resolve at least one email in both the Responsible emails group and the Alert emails group (distinct groups, per research.md R4), so both groups are non-empty for this check.
   - Re-run step 2 (`test-sales-order-alert`) and inspect the sent email's To/Cc headers: confirm every Responsible emails group address is present (To), and confirm **no** Alert emails group address appears in either the To or Cc line (FR-026, SC-014). Confirm the email's content (columns, computed values, highlighting, title) is unchanged from step 5.
   - Re-run step 8 (`test-sales-order-alert-without-salesId`) and inspect the sent email's To/Cc headers: confirm every Alert emails group address is present, and confirm **no** Responsible emails group address appears in either the To or Cc line (FR-027, SC-015). Confirm the Responsible emails *column* inside the email table/Excel attachment still shows each row's responsible emails as data, unchanged — only the addressing is affected (FR-028).
   - If in-app notifications are reachable (`compl_notifications` table or the notification bell), confirm the same exclusion holds there too for each trigger's own run: no notification row is created for an address belonging to the trigger's excluded group.

## Expected outcomes (ties back to spec.md Success Criteria)

- SC-001: every sales order returned in step 1 appears exactly once, evaluated, in the run's logs (`Log.Information`/`Log.Error` per sales order, per research.md R6) — none silently skipped.
- SC-002: step 3 and step 4 show no stale rows.
- SC-003: exactly one email/notification batch per run with at least one row; zero when the table is empty.
- SC-004: steps 2–3 require no manual intervention beyond calling the endpoint once.
- SC-005: step 5's per-row Status/Days remaining checks show every row's displayed value matching its own current Code/Valid to as of when the alert was generated.
- SC-006: step 5's Excel-attachment check shows exactly one correctly-named, correctly-populated attachment on every sent alert.
- SC-007: step 5's dedup check shows each distinct Master code/Code/Type/Product combination appearing exactly once, with no Sales order column, in both the email and the Excel attachment.
- SC-008: step 5's Excel-highlight check shows the same set of rows highlighted yellow in the attachment as are shown Expired in the email — none missing, none extra.
- SC-009: step 5's Sales order column check shows every distinct contributing sales order code present exactly once per row, with no missing or duplicated codes.
- SC-011: step 5's header-styling check shows the Excel attachment's header row visually matching the email body's header row (background color, bold text, borders).
- SC-012: step 8 shows the diagnostic trigger's email and Excel attachment both containing exactly 13 columns (no Sales order column, blank or otherwise), with every other column's value matching what `test-sales-order-alert` would show for the same data.
- SC-013: step 8's title check shows the diagnostic trigger's alert titled "Missing compliance Information", while `test-sales-order-alert` continues to show "Sales orders with missing compliance".
- SC-014: step 9's `test-sales-order-alert` check shows zero Alert emails group addresses in the sent email's To/Cc or the in-app notification recipients, while Responsible emails group addresses continue to receive it.
- SC-015: step 9's `test-sales-order-alert-without-salesId` check shows zero Responsible emails group addresses in the sent email's To/Cc or the in-app notification recipients, while Alert emails group addresses continue to receive it.
