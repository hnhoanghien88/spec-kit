# Contracts: `EutrPurchaseAttachmentsController` — Update 2 additions

New actions added by spec Update 2 (2026-07-16) alongside the existing `by-sales-ids` action
(Update 1, see `contracts/eutr-purchase-attachments.md`) — same controller, same DB table
(`eutr_purchase_attachments`), no migration. Backs `MapFilePage.jsx` Step 1 (pre-check + Save PO
Mapping) and Step 2 (template tree source). See `research.md` Decisions 11/12/15.

## `GET /api/eutr-purchase-attachments/by-sales-id/{salesId}`

```
Authorization: Bearer <token>   // Policy: EutrPurchaseAttachments.Read (reused, unchanged)
```

### Response

```json
{
  "data": [
    { "salesId": "SO007071", "purchId": "PO10001", "templateCode": "TPL-001" },
    { "salesId": "SO007071", "purchId": "PO10002", "templateCode": "TPL-002" }
  ]
}
```

(`ApiResponse<List<PurchaseAttachmentDto>>`.)

- Zero, one, or many rows for the given `salesId` — zero rows means this Sales Order has never had a
  PO mapping saved (Step 1 all-unchecked, Step 2 "no template tree yet"; spec FR-018/FR-025).
- Unlike `by-sales-ids` (plural, Update 1), this action is single-`SalesId`, returns raw `PurchId`
  rows (no `eutr_templates` JOIN, no `TemplateName`, no dedup) — the caller (`MapFilePage.jsx`) needs
  per-`PurchId` granularity to pre-check specific checkboxes, which the plural/deduped endpoint
  cannot provide.
- `salesId` not found in `eutr_purchase_attachments` at all → `{ "data": [] }`, not a 404 (this
  action never validates the Sales Order itself exists — that check is FR-014, against `refType=11`,
  done separately by the caller before this call).

## `POST /api/eutr-purchase-attachments/save-po-mapping`

```
Authorization: Bearer <token>   // Policy: EutrPurchaseAttachments.Update (NEW policy code)
Body:
{
  "salesId": "SO007071",
  "items": [
    { "purchId": "PO10001", "templateCode": "TPL-001" },
    { "purchId": "PO10003", "templateCode": "TPL-001" }
  ]
}
```

- `items` is the **complete current selection** for this `salesId` — not a delta. The server
  replaces the entire existing row set for that `salesId` with exactly these rows (delete-then-
  reinsert in one transaction; spec FR-021). An empty `items` array is valid and means "save zero
  POs for this Sales Order" (all prior rows for it are removed, none re-added).
- `templateCode` per item is taken by the frontend from that PO's own D365 `EutrTemplate` field
  (`refType=16` row) — the backend does not validate that `templateCode` matches any particular PO's
  D365 template; it just persists whatever the client sends (client is trusted here the same way
  every other `Eutr*` write endpoint trusts its request DTO — no cross-system validation against
  D365 on write, consistent with this codebase's existing pattern of one-way D365 reads).
- `templateCode` MUST NOT be null/empty per item (`eutr_purchase_attachments.TemplateCode` is
  `NOT NULL`) — a request item with an empty `templateCode` is rejected with `400 Bad Request`
  (`ApiResponse<string>.Fail(...)`), consistent with spec Edge Case "PO without a template can't be
  saved" (FR-022). The frontend is expected to disable/omit such POs from `items` before calling this
  endpoint, so this is a defensive validation, not the primary UX (the primary UX is Step 1 disabling
  the checkbox).

### Response

```json
{ "success": true, "message": "PO mapping saved successfully", "data": "" }
```

(`ApiResponse<string>` — simple ack, no echo of what was saved; the caller already has that data.)

## Before this update (current behavior)

`EutrPurchaseAttachmentsController` has exactly one action (`by-sales-ids`, Update 1, read-only).
`MapFilePage.jsx`'s Step 1 "Save PO Mapping" button is currently `setPoSaved(true)` only — no API
call, no persistence (`MOCK_SO_PO_MAPPINGS` is a static import, never written to).

## Backward compatibility

Both are net-new actions on an existing controller — no existing caller or contract (Update 1's
`by-sales-ids`, or any other feature) is affected.
