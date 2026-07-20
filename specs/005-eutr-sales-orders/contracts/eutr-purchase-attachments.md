# Contract: `POST /api/eutr-purchase-attachments/by-sales-ids`

New endpoint (new controller `EutrPurchaseAttachmentsController`) — introduced by spec Update 1
(2026-07-16) to back the **Template** column on `SalesOrderOverviewPage.jsx` with real data. See
`research.md` Decisions 5-8 for why this is a new backend surface rather than an extension of the
existing `DynController`/`ComplDynamicsService` reference proxy.

## Request

```
POST /api/eutr-purchase-attachments/by-sales-ids
Authorization: Bearer <token>   // Policy: EutrPurchaseAttachments.Read
Body: string[]                  // e.g. ["SO007071", "SO007080"]
```

- Body is the list of Sales IDs currently visible on the grid's current page (not the whole
  dataset) — see research.md Decision 7.
- An empty array MUST return an empty result (`{ "items": [] }`), not an error.

## Response

```json
{
  "data": [
    { "salesId": "SO007071", "templateCode": "TPL-001", "templateName": "Template A - V1" },
    { "salesId": "SO007071", "templateCode": "TPL-002", "templateName": "Template B - V2" }
  ]
}
```

(Wrapped in this codebase's standard `ApiResponse<List<SalesOrderTemplateDto>>` envelope, matching
every other `Eutr*Controller` response shape.)

- Zero, one, or many rows per requested `SalesId`:
  - Zero rows for a given `SalesId` → frontend renders the empty/"-" state for that row (FR-007b).
  - Multiple rows for the same `SalesId` with different `templateCode` → frontend renders each as a
    separate item in that row's Template cell (FR-007a).
  - A `SalesId` requested but absent from `eutr_purchase_attachments`, or whose only
    `eutr_purchase_attachments` rows reference a `TemplateCode` no longer present in `eutr_templates`,
    both produce **zero** rows for that `SalesId` (the `INNER JOIN` in research.md Decision 6 skips
    orphaned `TemplateCode`s rather than erroring).
  - Duplicate `(SalesId, TemplateCode)` pairs (e.g. two `PurchId`s sharing one template) are
    pre-deduplicated server-side (`SELECT DISTINCT`) — the frontend never needs to dedup itself.

## Before this feature (current behavior)

No endpoint reads `eutr_purchase_attachments` today — the table exists in the schema
(`docs/design/eutr/eutr_db.sql`) but has zero backend code referencing it (verified by full-repo
search). `SalesOrderOverviewPage.jsx`'s Template column is a hardcoded `DEMO_TEMPLATE_LABEL` string,
identical on every row.

## Backward compatibility

Net-new endpoint and net-new DTO — no existing caller or contract is affected.
