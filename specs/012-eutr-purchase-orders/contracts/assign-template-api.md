# Contract: Assign template (Update 13)

**Owner**: `compliance-sys-api` — `EutrPurchaseOrdersController`, route `api/eutr-purchase-orders`. Auth: `[Authorize(Policy = "EutrPurchaseOrders.Update")]`.

## `GET api/eutr-purchase-orders/active-templates`
Response `ApiResponse<List<ActiveTemplateDto>>`: `[{ "id": 1, "code": "TPL-001", "name": "...", "versionId": "2" }]` — only `IsDeleted=0, IsHide=0, Status=1`.

## `POST api/eutr-purchase-orders/assign-template`
Request: `{ "purchId": "PO000123", "templateId": "TPL-001", "versionId": "2" }` (all strings, required).
Behavior: validate pair against active set → 400 if no match → `POST {Dynamics:ApiUrl}/data/RSVNPurchTables/Microsoft.Dynamics.DataEntities.updateEutr?cross-company=true` with the same 3 fields. 200 `ApiResponse` on success; D365 error → error response with message (FR-046). No local persistence.
