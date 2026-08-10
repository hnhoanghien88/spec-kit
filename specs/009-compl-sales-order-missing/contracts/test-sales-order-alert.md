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
4. **(2026-08-10)** The email's table body shows exactly 14 columns per row, in this order: Sales order, Master code, Master name, Status, Code, Name, Valid from, Valid to, Days remaining, Responsible emails, Description, Type, Product, Product name (spec.md FR-012). `Status` and `Days remaining` are computed at the moment the email is generated from that row's own Code/Valid to — not copied from the stored `compl_so_missing.Status` value, which is always `"MISSING"` (spec.md FR-013/FR-014, research.md R8).
5. **(2026-08-10, Excel attachment)** The email also carries exactly one Excel (`.xlsx`) attachment, unconditionally (independent of the existing `Mail.SendAttachment` config-gated per-row SharePoint attachments), containing the same 14 columns and the same row data as the email body. Its file name follows `compl-sales-order-missing-<yyyyMMddHHmmss>`, timestamped at the moment the alert was generated (spec.md FR-015–FR-017, research.md R9/R10).

## Non-goals for this contract

- No new request parameters (e.g. filtering to a single sales order) — out of scope per spec.md, which describes a full-list refresh only.
- No pagination of the response — the endpoint reports only success/failure of the whole run, not per-sales-order results.
