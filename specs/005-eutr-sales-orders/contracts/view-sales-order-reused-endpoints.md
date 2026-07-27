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

## Update 8 (2026-07-27) — Template Tree Toolbar + PO/Template-scoped status: zero contract change

Spec Update 8 (FR-058..FR-063) introduces **no new and no changed endpoint**. It reuses the same two
rows already listed above, now reading one more already-returned field from the second one:

- `GET /api/eutr-purchase-attachments/by-sales-id/{salesId}` — unchanged; its `PurchaseAttachmentDto[]`
  (`purchId`/`templateCode` per row) is now also used to build the PO→Template scoping lookup
  (research.md Decision 33), the same way `MapFilePage.jsx` already uses it (Update 7).
- `POST /api/eutr-documents/list-po-references` — unchanged; its response already carries `poCode` per
  document (additive field from this feature's own Update 5, owned by `004-eutr-documents`). This
  screen's own `realAvailableFiles` builder previously omitted `poCode` from its file objects; Update 8
  starts reading it (research.md Decision 32) — no request/response shape change.

No request/response shape changes, no new endpoint, no policy change. See `data-model.md`'s "Update 8"
section and `research.md` Decisions 31-34 for how these two already-available fields are used
client-side.

## Update 10 (2026-07-27) — Download button: one new endpoint, not a reused one

Unlike every prior update in this table, spec Update 10 (FR-069..FR-076, real zip Download) introduces
a genuinely **new** endpoint — `POST /api/eutr-documents/download-zip` — because no existing endpoint
in this codebase accepts a client-supplied, folder-grouped list of `fileId`s and returns a
folder-organized zip. See `contracts/eutr-documents-download-zip.md` for its full contract and
`research.md` Decisions 36-40 for why its naming/zip-building mechanics are cloned from
`AllCompliancesController`/`ComplianceDownloadService` rather than invented fresh. All other data this
button's `onClick` needs (Sales ID/Customer/Customer name, template names, Mapped file
lists-per-template) is already loaded by this page (Update 4/7/8) — no new read endpoint, no new fetch.
