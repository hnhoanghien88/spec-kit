# Contract: `POST /api/eutr-purchase-attachments/by-sales-ids-raw`

New endpoint (added to the already-existing `EutrPurchaseAttachmentsController`) — introduced by spec
Update 12 (2026-07-27) to back the **Progress** column on `SalesOrderOverviewPage.jsx` with a batched,
raw (non-deduplicated, non-joined) source of `{SalesId, PurchId, TemplateCode}` for every Sales ID
visible on the current page. See `research.md` Decision 43 for why the existing `by-sales-ids` action
(also on this controller) cannot be reused/widened for this purpose without breaking its own existing
consumer (the Template column).

## Request

```
POST /api/eutr-purchase-attachments/by-sales-ids-raw
Authorization: Bearer <token>   // Policy: EutrPurchaseAttachments.Read (same policy as by-sales-ids
                                //   and by-sales-id/{salesId} — no new policy)
Body: string[]                  // e.g. ["SO007071", "SO007080"]
```

- Body is the list of Sales IDs currently visible on the grid's current page — same sourcing as the
  existing `by-sales-ids` action's request (research.md Decision 7), reused here for a second, parallel
  batch call.
- An empty array MUST return an empty result, not an error (same convention as `by-sales-ids`).

## Response

```json
{
  "data": [
    { "salesId": "SO007071", "purchId": "PO00014347", "templateCode": "TPL-001" },
    { "salesId": "SO007071", "purchId": "PO00014399", "templateCode": "TPL-002" },
    { "salesId": "SO007080", "purchId": "PO00014400", "templateCode": "TPL-001" }
  ]
}
```

(Wrapped in the standard `ApiResponse<List<PurchaseAttachmentDto>>` envelope — reuses the existing
`PurchaseAttachmentDto` class as-is, unchanged from Update 2.)

- One row per `eutr_purchase_attachments` record whose `SalesId` is in the request — **not**
  deduplicated (unlike `by-sales-ids`), and **not** joined to `eutr_templates` (no `TemplateName`
  field — the frontend already gets template names from the existing `by-sales-ids` call for the
  Template column, and separately from the new `by-codes` batch endpoint for full step details).
- A `SalesId` with zero `eutr_purchase_attachments` rows is simply absent from the response — the
  frontend treats this as the Progress column's `empty` state (FR-083), same empty condition as the
  Template column's own FR-007b.

## Before this feature (current behavior)

No batch, raw (`PurchId`-preserving) read of `eutr_purchase_attachments` exists across multiple Sales
IDs today — only `GET /api/eutr-purchase-attachments/by-sales-id/{salesId}` (singular, one Sales ID per
call) returns raw rows; `by-sales-ids` (plural) returns pre-aggregated, deduplicated, `TemplateName`-
joined rows with `PurchId` dropped. Neither is suitable as-is for computing per-row Progress across a
whole page (research.md Decision 43).

## Backward compatibility

Net-new endpoint, reusing an already-existing DTO — no existing caller or contract is affected. The
existing `by-sales-ids`/`by-sales-id/{salesId}` actions are unchanged.
