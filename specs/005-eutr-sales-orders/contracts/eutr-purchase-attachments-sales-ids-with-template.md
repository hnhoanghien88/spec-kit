# Contract: `GET /api/eutr-purchase-attachments/sales-ids-with-template`

New endpoint (added to the already-existing `EutrPurchaseAttachmentsController`) — introduced by spec
Update 16 (2026-07-28) to back `SalesOrderOverviewPage.jsx`'s new default (empty-search) row set: only
Sales IDs that already have at least one saved `eutr_purchase_attachments` row (spec FR-107). See
`research.md` Decision 60 for why this is a small, additive sibling read on the same controller rather
than a widened variant of an existing action, and Decision 61 for how the frontend uses this endpoint's
result to filter the existing D365 `refType = 11` list without any change to `ComplDynamicsService`/
`DynController`.

## Request

```
GET /api/eutr-purchase-attachments/sales-ids-with-template
Authorization: Bearer <token>   // Policy: EutrPurchaseAttachments.Read (same policy as by-sales-ids,
                                //   by-sales-id/{salesId}, by-sales-ids-raw — no new policy)
```

No request body, no query parameters — this is an unconditional "give me every distinct Sales ID that
has at least one row" read, not scoped to a caller-supplied list (unlike `by-sales-ids`/
`by-sales-ids-raw`, which both require an input list).

## Response

```json
{
  "data": ["SO007071", "SO007080", "SO007099"]
}
```

(Wrapped in the standard `ApiResponse<List<string>>` envelope — no new DTO class; a bare `string[]` of
distinct `SalesId` values.)

- `SELECT DISTINCT SalesId FROM eutr_purchase_attachments WHERE TemplateCode IS NOT NULL;` — the
  `TemplateCode IS NOT NULL` predicate is always true today given `TemplateCode`'s existing `NOT NULL`
  column constraint (spec FR-022), so this read is equivalent to "every Sales ID with at least one saved
  row"; the predicate is kept explicit for clarity and to stay correct if that constraint is ever
  relaxed (same forward-consistency reasoning as spec Update 11/research.md Decision on `AUTO_SOURCES`).
- If the table has zero rows, the response is `{"data": []}`, not an error — the frontend treats this as
  "no Sales ID has a Template yet" (spec FR-112, "No data").
- Order is unspecified — the frontend never renders this list directly, it only uses it to build filter
  entries for the existing `POST /api/dynamics/reference?refType=11` call (Decision 61).

## Before this feature (current behavior)

No "every distinct Sales ID with a saved row, no input list" read exists today — every existing action on
this controller (`by-sales-ids`, `by-sales-id/{salesId}`, `by-sales-ids-raw`, `save-po-mapping`) takes a
specific Sales ID or list of Sales IDs as input. This is the first action on this controller with no
input at all.

## Backward compatibility

Net-new endpoint, no new DTO, no new policy — no existing caller or contract is affected. Every other
action on `EutrPurchaseAttachmentsController` is unchanged.
