# Reused endpoints (no contract changes) — `SalesOrderOverviewPage.jsx`, spec Updates 12/13

Endpoints below are owned by earlier updates of this same feature (or by `004-eutr-documents`) and are
consumed **as-is** by `SalesOrderOverviewPage.jsx` — no request/response shape change, no new backend
code for these specific rows. Listed here for traceability only; the authoritative contracts remain in
each endpoint's owning contract file. The two genuinely new endpoints these updates introduce
(`by-sales-ids-raw`, `by-codes`) have their own contract files — see below.

## Update 12 (2026-07-27) — Progress column: 2 new endpoints + 1 reused endpoint, batched per page

| Endpoint | Owning contract | Used for | Request shape used |
|---|---|---|---|
| `POST /api/eutr-purchase-attachments/by-sales-ids-raw` | `contracts/eutr-purchase-attachments-by-sales-ids-raw.md` (**new**) | Raw `{salesId, purchId, templateCode}` for every visible row (FR-082) | `string[]` of every visible `salesId` |
| `POST /api/eutr-templates/by-codes` | `contracts/eutr-templates-by-codes.md` (**new**) | Full step-detail tree per distinct `templateCode` referenced by any visible row | `string[]` of distinct `templateCode`s across the whole page |
| `POST /api/eutr-documents/list-po-references` | `contracts/map-file-reused-endpoints.md` | Mapped documents per PO, used to compute per-template completion (FR-082) | `{ poCodes: [...union of every purchId from by-sales-ids-raw across the page] }` — confirmed already SalesId-agnostic (research.md Decision 45), zero contract change |

All three calls are fired once per page load/search/pagination change (parallel to the existing
`fetchTemplatesForRows` batch for the Template column), never per row (FR-085).

## Update 13 (2026-07-27) — Download button: zero new endpoint, on-demand per row

| Endpoint | Owning contract | Used for | Request shape used |
|---|---|---|---|
| `GET /api/eutr-purchase-attachments/by-sales-id/{salesId}` | `contracts/eutr-purchase-attachments-map-file.md` | This row's own raw `{purchId, templateCode}` pairs, fetched only when this row's Download is clicked | path param `salesId` |
| `POST /api/eutr-templates/by-codes` | `contracts/eutr-templates-by-codes.md` (**new**, Update 12) | This row's own distinct `templateCode`s' full step-detail trees | `string[]` of just this row's own codes |
| `POST /api/eutr-documents/list-po-references` | `contracts/map-file-reused-endpoints.md` | Mapped documents for this row's own POs only | `{ poCodes: [...this row's own purchIds] }` |
| `POST /api/eutr-documents/download-zip` | `contracts/eutr-documents-download-zip.md` | Builds and returns the zip — identical contract already shipped for `ViewSalesOrderPage.jsx`'s Download (Update 10) | `{ salesId, customerCode, customerName, folders: [...] }`, built client-side from the 3 rows above via the shared `buildTemplateComputations` util (research.md Decision 42) |

Unlike Update 12, none of these four calls are batched across rows — each fires only when that row's
own Download button is clicked (FR-088), and only for that one Sales ID's own data.

No policy changes, no DTO changes to any reused endpoint. See `data-model.md`'s "Update 12"/"Update 13"
sections and `research.md` Decisions 42-52 for the full data flow and per-row state handling.

## Update 16 (2026-07-28) — Default (empty-search) row set scoped to Sales IDs with Template

| Endpoint | Owning contract | Used for | Request shape used |
|---|---|---|---|
| `GET /api/eutr-purchase-attachments/sales-ids-with-template` | `contracts/eutr-purchase-attachments-sales-ids-with-template.md` (**new**) | The whitelist of Sales IDs that already have a saved Template (FR-107) | none (no request body/params) |
| `POST /api/dynamics/reference?refType=11` | `contracts/dynamics-reference-refType-11.md` | Same generic paged Sales Order list Overview has always used — now called with a computed `FilterRequest[]` of `N × {column:"Code", operator:"eq", value: salesId}` entries (one per whitelisted Sales ID) **only when the search box is empty** | `FilterRequest[]` — reuses this endpoint's own existing same-bucket-OR'd filter behavior (`ComplDynamicsService.BuildFilterString`, unchanged); zero contract change |

- When the search box is empty (initial load, or cleared back to empty — including via Update 14's
  Back-navigation restore, FR-110), `SalesOrderOverviewPage.jsx` first calls the new
  `sales-ids-with-template` endpoint. If it returns an empty list, the screen renders "No data" (FR-112)
  and skips the `refType=11` call entirely — sending zero filter entries to `refType=11` would mean "no
  filter" (matches everything), the opposite of the intended default view.
- When the search box has a non-empty keyword, this whitelist call is skipped entirely and `refType=11`
  is called with the existing Code/Name search filter exactly as before (FR-109/FR-011) — unaffected by
  this update.
- `ComplDynamicsService`/`DynController`/`ODataOperatorConverter` are **not modified** — same-bucket
  (`code`) `FilterRequest` entries already join with `or` (verified in `BuildFilterString`), so an
  N-entry whitelist filter is expressed with the exact request shape this endpoint already accepts.
  See `research.md` Decisions 60-61.
