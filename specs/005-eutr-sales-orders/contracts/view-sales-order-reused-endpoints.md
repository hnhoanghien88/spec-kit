# Reused endpoints (no contract changes) — `ViewSalesOrderPage.jsx`, spec Update 4

All four endpoints below are owned by earlier updates of this same feature (or by other features) and
are consumed **as-is** by `ViewSalesOrderPage.jsx` — no request/response shape change, no new backend
code. Listed here for traceability only (per `research.md` Update 4 Decisions 18-21); the authoritative
contracts remain in each endpoint's owning contract file.

| Endpoint | Owning contract | Used for | Request shape used |
|---|---|---|---|
| `POST /api/dynamics/reference?refType=11` | `contracts/dynamics-reference-refType-11.md` | Existence check + header (FR-034/FR-036) | `filters: [{ column: "Code", operator: "eq", value: salesId }]`, `page=1, pageSize=1` |
| `GET /api/eutr-purchase-attachments/by-sales-id/{salesId}` | `contracts/eutr-purchase-attachments-map-file.md` | Purchase Orders đã chọn — saved `PurchId`/`TemplateCode` set (FR-037/FR-038) | path param `salesId` only |
| `POST /api/dynamics/reference?refType=16` | `contracts/map-file-reused-endpoints.md` | Purchase Orders đã chọn — display fields (Name/Order account/Qty), joined client-side against the saved set above (FR-037, research.md Decision 19) | `filters: [{ column: "InterCompanyOriginalSalesId", operator: "eq", value: salesId }]` |
| `POST /api/eutr-templates/get-all` + `GET /api/eutr-templates/{id}` | `contracts/map-file-reused-endpoints.md` | Template Checklist tree (FR-039/FR-040/FR-041) | `get-all` filter `{ column: "Code", operator: "eq", value: templateCode }, pageSize=1` → `{id}` from the one result → `GetById` |
| `POST /api/eutr-documents/list-po-references` | `contracts/map-file-reused-endpoints.md` | Per-step mapped/missing status (FR-041) | `{ poCodes: [...saved PurchIds] }` |

Deliberately **not** called from this screen (read-only, spec FR-042):

- `POST /api/eutr-purchase-attachments/save-po-mapping` — no Save action exists on this screen.

No policy changes, no DTO changes, no new controller actions for any row above.
