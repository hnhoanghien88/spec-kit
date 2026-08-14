# Quickstart: Validate EUTR Synchronize Data (Sales Order Template Sync + Purchase-Order Missing-Documentation Alert)

## Part A — User Story 1: Sales Order Template Sync

## Prerequisites

- `compliance-sys-api` running locally (or against the target environment) with a valid D365
  connection configured (same connection `DynController`/`ComplDynamicsService` already use — no
  new configuration is introduced by this feature).
- A bearer token for an authenticated user (same auth used for any other `Eutr*`/`Compl*` endpoint).
- Access to the `eutr_purchase_attachments` table for before/after inspection (MySQL client or the
  existing `EutrPurchaseAttachmentsController` read endpoints).

## 1. Baseline: confirm `refType = 19` is currently dead (pre-fix)

Before applying research.md R2/R3, calling the existing reference endpoint should return an empty
result regardless of D365 data:

```
POST /api/dynamics/reference?refType=19&page=1&pageSize=10
Authorization: Bearer <token>
Body: []
```

Expected (pre-fix): `data.items = []`, `data.totalCount = 0`. This confirms the gap this feature
fixes (see research.md R2) before relying on it.

## 2. Post-fix: confirm `refType = 19` now returns real rows

Re-run the same request after the `EntityMappings`/`MapDynamicsResponse` fix. Expected: `data.items`
contains records with non-empty `InterCompanyOriginalSalesId` (or `Id`), `RSVNEutrTemplate` (or
`Code`), `RSVNRefPurchId` (or `Name`) — count matching what exists in D365 for this entity.

## 3. Note the "before" state of `eutr_purchase_attachments`

```sql
SELECT COUNT(*) AS before_count FROM eutr_purchase_attachments;
SELECT SalesId FROM eutr_purchase_attachments; -- note a few existing SalesIds, if any
```

## 4. Trigger the sync

```
GET /api/eutr-synchronize-data/test-so-template-sync
Authorization: Bearer <token>
```

Expected: `200 OK`, `data.success = true`, `data.totalFetched` roughly matching the D365 record
count from step 2, `data.added + data.skipped == data.totalFetched`.

## 5. Confirm new rows (User Story 1, Acceptance Scenario 1)

```sql
SELECT COUNT(*) AS after_count FROM eutr_purchase_attachments;
-- after_count - before_count should equal data.added from step 4
```

Spot-check one newly added `SalesId` from the D365 response in step 2 against
`eutr_purchase_attachments` — `PurchId`/`TemplateCode` should match that record's
`RSVNRefPurchId`/`RSVNEutrTemplate`.

## 6. Confirm existing rows are left alone (Acceptance Scenario 2)

Pick a `SalesId` noted in step 3 (existed before the run). Confirm its row in
`eutr_purchase_attachments` is byte-for-byte unchanged (same `PurchId`, `TemplateCode`,
`UpdatedDate`) after step 4.

## 7. Confirm idempotency (Acceptance Scenario 4 / SC-002)

Re-run step 4 immediately with no changes to D365 data in between. Expected:
`data.added = 0`, `data.skipped = data.totalFetched`, and the `eutr_purchase_attachments` row count
is unchanged from step 5.

## 8. Confirm full-dataset coverage (Acceptance Scenario 3 / SC-003)

If the D365 reference dataset for type 19 spans more than one page (more than the sync's internal
page size), confirm `data.totalFetched` from step 4 matches the `@odata.count` reported by manually
paging through `POST /api/dynamics/reference?refType=19` with `page=1,2,3,...` until exhausted —
i.e., the sync did not stop at the first page.

---

## Part B — User Story 2: Purchase-Order Missing-Documentation Alert (added 2026-08-13)

## Prerequisites

- Everything in Part A's Prerequisites, plus:
- `SharePointEutrPath` configured (already added by feature 004-eutr-documents — no new
  configuration key is introduced by this story).
- At least one `eutr_templates` row with a non-empty `AlertFor` pointing to a `compl_group_email`
  group that itself has at least one `compl_group_email_detail` recipient email, so at least one
  notification email can actually be observed.
- Access to a test mailbox (or a way to inspect outgoing mail, e.g. a dev SMTP catcher) matching
  whatever this environment already uses to verify other alert emails (`test-alert`,
  `test-sales-order-alert`).

## 9. Baseline: confirm `refType = 15` already returns data, without `OrderAccount` yet (pre-fix)

```
POST /api/dynamics/reference?refType=15&page=1&pageSize=10
Authorization: Bearer <token>
Body: []
```

Expected (pre-fix): `data.items` is non-empty (unlike User Story 1's `refType = 19`, this reference
type already works today), but nothing in the response distinguishes a vendor account — confirms
the narrow gap this story's `case 15` fix (research.md R9) closes.

## 10. Prepare a mixed test population

Using data already in D365/the local system (or a sandbox subset), confirm you have at least:

- One purchase order with a blank/unmatched `EutrTemplate` value.
- One purchase order with a valid `EutrTemplate` but no SharePoint folder yet at
  `{SharePointEutrPath}/{PurchId}`.
- One purchase order with a valid `EutrTemplate`, an existing folder, and at least one of its
  template's steps having no recorded document in `eutr_documents`/`eutr_references`.
- One fully-complete purchase order (template assigned, folder present, every step covered).

## 11. Note the "before" state of `eutr_purchase_missing`, then trigger the check

```sql
SELECT COUNT(*) AS before_count FROM eutr_purchase_missing;
```

```
GET /api/eutr-synchronize-data/test-purchase-missing
Authorization: Bearer <token>
```

Expected: `200 OK`, `data.success = true`, `data.totalFetched` roughly matching the D365 `refType =
15` record count, `data.flaggedCount` counting only the non-compliant purchase orders prepared in
step 10 (the fully-complete one is not counted).

## 11a. Confirm the store was cleared and repopulated (Acceptance Scenario 11, spec FR-020/FR-021)

```sql
SELECT COUNT(*) AS after_count FROM eutr_purchase_missing;
SELECT PurchId, VendorCode, VendorName, TemplateId, Note, AlertForGroupId FROM eutr_purchase_missing;
```

Expected: `after_count` equals `data.flaggedCount` from step 11 (not `before_count + data.flaggedCount`
— the table was fully cleared first, not appended to), and every row shown matches one of the
non-compliant purchase orders prepared in step 10, with `Note`/`AlertForGroupId` matching what steps
12-14 below expect. The fully-complete purchase order from step 10 must not appear in this table at
all.

## 12. Confirm "Missing template id" (Acceptance Scenario 2)

Inspect the email sent to every notified group (per the clarified per-group-plus-shared-rows
behavior — Acceptance Scenario 8) and/or its Excel attachment: the blank/unmatched-template purchase
order from step 10 appears with `Note = "Missing template id"`.

## 13. Confirm "Have no PO folder" (Acceptance Scenario 3)

In the email/attachment for the group whose template's `AlertFor` matches that purchase order, the
no-folder purchase order from step 10 appears with `Note = "Have no PO folder"`.

## 14. Confirm per-step "Missing" notes (Acceptance Scenario 4)

The purchase order with an existing folder but incomplete steps appears with one `"{Template name} -
step {n} : Missing"` line per step that has no recorded document — `n` matching that step's position
in Template Management's own step order for that template.

## 15. Confirm fully-complete purchase orders are excluded (Acceptance Scenarios 5 & 6)

The fully-complete purchase order from step 10 appears in **no** email and **no** Excel attachment
from this run.

## 16. Confirm per-group email routing (Acceptance Scenario 7)

If step 10's flagged purchase orders span more than one distinct `AlertFor` group, confirm exactly
one email (with its own Excel attachment) was sent per distinct group, and that each email/
attachment contains only that group's own template-matched rows (plus every "Missing template id"
row from this run, per Acceptance Scenario 8) — never another group's unrelated rows.

## 17. Confirm the no-op case (Acceptance Scenario 9)

Re-run step 11 against a population where every purchase order is fully complete (or temporarily
narrow the test data to only the fully-complete one from step 10). Expected: `data.flaggedCount =
0`, `data.groupsNotified = 0`, no email/attachment is produced, and `SELECT COUNT(*) FROM
eutr_purchase_missing` now returns `0` (the table was cleared per FR-020 and nothing new qualified
for FR-021's insert).

## 18. Confirm emails are built from the store, not from memory (Acceptance Scenario 12, spec FR-022)

Immediately after step 11 (before running the check again), re-run:

```sql
SELECT PurchId, VendorCode, VendorName, TemplateId, Note FROM eutr_purchase_missing
WHERE AlertForGroupId = <one groupId from a notified group's email in step 16>;
```

Expected: this result set matches, row-for-row, the corresponding group's email content/Excel
attachment from step 16 (plus any `AlertForGroupId IS NULL` "Missing template id" rows also shown in
that same email) — confirming the email was built by reading `eutr_purchase_missing` back, not from
a value still held in memory from evaluation.
