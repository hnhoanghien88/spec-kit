# Contract: `GET /api/notification/test-sales-order-alert-without-salesId`

New endpoint on the existing `ComplNotificationController` (route base `api/notification`), mirroring `GET /api/notification/test-sales-order-alert` (see [test-sales-order-alert.md](./test-sales-order-alert.md)) — added 2026-08-31 (spec.md FR-023/FR-024).

## Request

- **Method / Path**: `GET /api/notification/test-sales-order-alert-without-salesId`
- **Auth**: `[Authorize]` (inherited from the controller's class-level attribute — same policy as every other action on `ComplNotificationController`; no new policy introduced)
- **Body / Query params**: none

## Behavior

Synchronously runs `IComplNotificationService.SendSalesOrderAlertWithoutSalesIdAsync()` to completion, then returns. This entry point performs the **identical** refresh-and-read-back process as `test-sales-order-alert` (same `RefreshSalesOrderMissingComplianceAsync` clear-and-repopulate step, same Master code/Code/Type/Product grouping — research.md R16) — it is not a filtered or reduced-scope run. The only difference is in the alert content this trigger sends: the Sales order column is omitted.

## Response

- **200 OK** — always returned once the underlying process completes without throwing (including the "nothing to alert" case, same as `test-sales-order-alert`):
  ```json
  {
    "data": "",
    "message": "TestSalesOrderAlertWithoutSalesId successfully",
    "succeeded": true
  }
  ```
  (Exact envelope shape per `ApiResponse<T>.Ok(data, message)`, same helper used by every other action in this controller.)
- **5xx** — only if `SendSalesOrderAlertWithoutSalesIdAsync`'s outer try/catch re-throws (an unexpected failure before or after the per-sales-order loop) and the global exception-handling middleware converts it to an error response — same behavior as `test-sales-order-alert` today; no new error contract is introduced.

## Side effects (not visible in the HTTP response, verified via quickstart.md)

1. `compl_so_missing` is cleared and repopulated exactly as it is for `test-sales-order-alert` (same shared refresh step) — triggering this endpoint has the same effect on the store as triggering the existing one.
2. If any row exists in `compl_so_missing` after the refresh, exactly one email is sent and one `ComplNotification` row is inserted per resolved recipient — same group-resolution logic as `test-sales-order-alert` (research.md R3/R4), but as of 2026-09-03 this trigger's own send addresses only the Alert emails group, not the Responsible emails group (side effect 8 below).
3. If zero rows exist after the refresh, no email or notification is sent (FR-010, unchanged).
4. **(FR-024)** The email's table body shows exactly 13 columns per row, in this order: Master code, Master name, Status, Code, Name, Valid from, Valid to, Days remaining, Responsible emails, Description, Type, Product, Product name — **no Sales order column**. `Status` and `Days remaining` are computed the same way as `test-sales-order-alert` (FR-013/FR-014).
5. **(FR-024)** The email carries exactly one Excel (`.xlsx`) attachment, named `compl-sales-order-missing-<yyyyMMddHHmmss>` (same naming pattern as `test-sales-order-alert`, FR-016 unaffected), containing the same 13 columns and the same row data as this trigger's own email body — no Sales order column in the attachment either.
6. Deduplication by Master code/Code/Type/Product (FR-008), Expired-row yellow highlighting (FR-018), and the Excel header's visual styling (FR-022) all apply identically to this trigger's alert as they do to `test-sales-order-alert`'s.
7. **(FR-025)** The alert's title — both the email subject and the heading shown above the table in the email body — reads "Missing compliance Information", not "Sales orders with missing compliance", since the alert's content is no longer tied to individual sales orders.
8. This endpoint does not change the behavior of `test-sales-order-alert`, `SendSalesOrderAlertAsync`, or any other existing alert — it is an additional, independent manual entry point (FR-023).
9. **(2026-09-03, recipient-group exclusion)** The email's To/Cc addressing and the in-app notification recipients (side effect 2) no longer include any email address from the Responsible emails recipient group — only the Alert emails group receives this trigger's alert. This does not change the alert's content (side effects 4-7 above are unaffected, including the Responsible emails *column* still shown as data); it only narrows who receives it (spec.md FR-027, FR-028, research.md R17).

## Non-goals for this contract

- No new request parameters — mirrors `test-sales-order-alert`'s full-list-refresh-only scope.
- No pagination of the response — reports only success/failure of the whole run.
- No change to the Excel attachment's file-naming pattern, Status/Days-remaining computation, Expired highlighting, or header styling — all of those are reused unchanged from `test-sales-order-alert` (spec.md Assumptions). As of 2026-09-03, recipient *resolution* itself (how each group's member emails are derived) is also unchanged — only which resolved group this trigger's own send excludes (spec.md FR-027).
