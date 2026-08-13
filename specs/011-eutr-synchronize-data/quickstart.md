# Quickstart: Validate EUTR Synchronize Data (Sales Order Template Sync)

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
