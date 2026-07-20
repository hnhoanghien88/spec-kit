# Reused endpoints (no contract changes) — `MapFilePage.jsx`, spec Update 2

These three endpoints are owned by other features/controllers and are consumed **as-is** by
`MapFilePage.jsx` — no request/response shape change, no new backend code. Listed here for
traceability only (per `research.md` Decisions 9/10/13/14); the authoritative contracts remain in
each endpoint's owning feature.

| Endpoint | Owning feature | Used for | Request shape used |
|---|---|---|---|
| `POST /api/dynamics/reference?refType=11` | `005-eutr-sales-orders` (this feature, Update 0/1) | Header/existence check (FR-014/FR-016) | `filters: [{ column: "Code", operator: "eq", value: salesId }]`, `page=1, pageSize=1` |
| `POST /api/dynamics/reference?refType=16` | `004-eutr-documents` (registered `EntityMappings[16]`); consumed here for the first time with this filter | Step 1 PO list (FR-017) | `filters: [{ column: "InterCompanyOriginalSalesId", operator: "eq", value: salesId }]` |
| `POST /api/eutr-documents/list-po-references` | `004-eutr-documents` (Update 8) | Step 2 AVAILABLE FILES (FR-026/FR-027) | `{ poCodes: [...selected/saved PurchIds] }` |
| `POST /api/eutr-templates/get-all` + `GET /api/eutr-templates/{id}` | `003-eutr-templates` | Step 2 template tree (FR-023/FR-024) | `get-all` filter `{ column: "Code", operator: "eq", value: templateCode }, pageSize=1` → `{id}` from the one result → `GetById` |

No policy changes, no DTO changes, no new controller actions for any of the four rows above.
