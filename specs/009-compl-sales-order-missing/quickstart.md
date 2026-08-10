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
   - **(2026-08-10)** Confirm the email table shows exactly these 14 columns, in this order: Sales order, Master code, Master name, Status, Code, Name, Valid from, Valid to, Days remaining, Responsible emails, Description, Type, Product, Product name (spec.md FR-012).
   - For a row whose `Code` is blank, confirm Status reads "Missing"; for a row with a `Code` and a `Valid to` date already in the past, confirm Status reads "Expired"; otherwise confirm it reads "Valid" (FR-013).
   - For a row with no `Valid to` date, confirm Days remaining is blank; for a `Valid to` date N days in the future, confirm it reads "N days left"; for a `Valid to` date N days in the past, confirm it reads "-N days left" (FR-014).
   - **(2026-08-10, Excel attachment)** Confirm the email carries exactly one `.xlsx` attachment named `compl-sales-order-missing-<yyyyMMddHHmmss>` (timestamp matching roughly when the alert was sent), and that opening it shows the same 14 columns, in the same order, with the same row values as the email body (FR-015/FR-016).

6. **Verify the empty-run case** (FR-010): temporarily point at an environment/sales-order set where every open sales order is fully compliant (or verify by inspection that step 3's table is empty after a run), and confirm no email/notification was produced for that run.

## Expected outcomes (ties back to spec.md Success Criteria)

- SC-001: every sales order returned in step 1 appears exactly once, evaluated, in the run's logs (`Log.Information`/`Log.Error` per sales order, per research.md R6) — none silently skipped.
- SC-002: step 3 and step 4 show no stale rows.
- SC-003: exactly one email/notification batch per run with at least one row; zero when the table is empty.
- SC-004: steps 2–3 require no manual intervention beyond calling the endpoint once.
- SC-005: step 5's per-row Status/Days remaining checks show every row's displayed value matching its own current Code/Valid to as of when the alert was generated.
- SC-006: step 5's Excel-attachment check shows exactly one correctly-named, correctly-populated attachment on every sent alert.
