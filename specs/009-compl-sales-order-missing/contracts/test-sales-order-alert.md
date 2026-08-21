# Contract: `GET /api/notification/test-sales-order-alert`

New endpoint on the existing `ComplNotificationController` (route base `api/notification`), mirroring the existing `GET /api/notification/test-alert`.

## Request

- **Method / Path**: `GET /api/notification/test-sales-order-alert`
- **Auth**: `[Authorize]` (inherited from the controller's class-level attribute — same policy as every other action on `ComplNotificationController`; no new policy introduced)
- **Body / Query params**: none

## Behavior

Synchronously runs `IComplNotificationService.SendSalesOrderAlertAsync()` to completion, then returns. This is a diagnostic/manual trigger (per spec.md FR-001), not a paginated or filtered query — it always processes the full current set of open sales orders.

## Response

- **200 OK** — always returned once the underlying process completes without throwing (including the "nothing to alert" case — mirrors `test-alert`'s behavior of always returning success even when `SendAlertAsync` short-circuits with zero items):
  ```json
  {
    "data": "",
    "message": "TestSalesOrderAlert successfully",
    "succeeded": true
  }
  ```
  (Exact envelope shape per `ApiResponse<T>.Ok(data, message)`, same helper used by every other action in this controller.)
- **5xx** — only if `SendSalesOrderAlertAsync`'s outer try/catch re-throws (an unexpected failure before or after the per-sales-order loop, per research.md R6) and the global exception-handling middleware converts it to an error response — same behavior as `test-alert` today; no new error contract is introduced.

## Side effects (not visible in the HTTP response, verified via quickstart.md)

1. `compl_so_missing` table is cleared entirely once, before any open sales order is evaluated, then repopulated with each evaluated sales order's current MISSING items (see data-model.md, revised 2026-08-04 — no longer a per-sales-order delete).
2. If any row exists in `compl_so_missing` after the refresh, exactly one email is sent and one `ComplNotification` row is inserted per resolved recipient (see research.md R3/R4).
3. If zero rows exist after the refresh, no email or notification is sent (FR-010).
4. **(2026-08-10; columns revised 2026-08-18, 2026-08-20)** The email's table body shows exactly 14 columns per row, in this order: Master code, Master name, Status, Code, Name, Valid from, Valid to, Days remaining, Responsible emails, Description, Type, Product, Product name, Sales order (spec.md FR-012). `Status` and `Days remaining` are computed at the moment the email is generated from that row's own Code/Valid to — not copied from the stored `compl_so_missing.Status` value, which is always `"MISSING"` (spec.md FR-013/FR-014, research.md R8).
5. **(2026-08-10, Excel attachment; columns revised 2026-08-18, 2026-08-20)** The email also carries exactly one Excel (`.xlsx`) attachment, unconditionally (independent of the existing `Mail.SendAttachment` config-gated per-row SharePoint attachments), containing the same 14 columns and the same row data as the email body. Its file name follows `compl-sales-order-missing-<yyyyMMddHHmmss>`, timestamped at the moment the alert was generated (spec.md FR-015–FR-017, research.md R9/R10).
6. **(2026-08-18)** Before either the email or the Excel attachment is built, the rows read back from `compl_so_missing` are deduplicated by the combination of Master code, Code, Type, and Product — if multiple sales orders in the store share the same combination, only one row for that combination appears in the alert (spec.md FR-008, research.md R11). The underlying `compl_so_missing` table itself is unaffected — it is not deduplicated in storage, only in what is read back for this alert.
7. **(2026-08-20)** In the Excel attachment, every row whose displayed Status is "Expired" is highlighted with the same yellow background color already used for that row in the email body; rows with Status "Missing" or "Valid" are left unhighlighted (spec.md FR-018, research.md R12).
8. **(2026-08-20, Sales order column)** The last column, "Sales order", shows every distinct sales order code from the `compl_so_missing` rows collapsed into that alert row by the Master code/Code/Type/Product dedup, combined into one value (e.g. "SO1, SO2"). This is a display-only value built at read-back time; it does not change the per-recipient in-app notification message text, which continues to reference a single representative sales order code as before (spec.md FR-008, FR-019, research.md R13).
9. **(2026-08-21, check-date sentinel fallback)** For each open sales order evaluated during the refresh (side effect 1), when its delivery date is absent or equals the source ERP's `1900-01-01` "no delivery date recorded" placeholder, the compliance lookup for that sales order now uses today's date as the check date instead of the placeholder — matching what the compliance screen already shows for the same sales order. This changes which items a given sales order's lookup reports as MISSING (and therefore what gets stored in `compl_so_missing` and shown in the alert) for exactly this class of sales order; it does not change any request/response shape (spec.md FR-020/FR-021, research.md R14).

## Non-goals for this contract

- No new request parameters (e.g. filtering to a single sales order) — out of scope per spec.md, which describes a full-list refresh only.
- No pagination of the response — the endpoint reports only success/failure of the whole run, not per-sales-order results.
