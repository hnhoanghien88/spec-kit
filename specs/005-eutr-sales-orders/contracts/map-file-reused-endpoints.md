# Reused endpoints (no contract changes) — `MapFilePage.jsx`, spec Update 2

These endpoints are owned by other features/controllers and are consumed **as-is** by
`MapFilePage.jsx` — no request/response shape change, no new backend code. Listed here for
traceability only (per `research.md` Decisions 9/10/13/14/26/27/28); the authoritative contracts
remain in each endpoint's owning feature.

| Endpoint | Owning feature | Used for | Request shape used |
|---|---|---|---|
| `POST /api/dynamics/reference?refType=11` | `005-eutr-sales-orders` (this feature, Update 0/1) | Header/existence check (FR-014/FR-016) | `filters: [{ column: "Code", operator: "eq", value: salesId }]`, `page=1, pageSize=1` |
| `POST /api/dynamics/reference?refType=16` | `004-eutr-documents` (registered `EntityMappings[16]`); consumed here for the first time with this filter | Step 1 PO list (FR-017) | `filters: [{ column: "InterCompanyOriginalSalesId", operator: "eq", value: salesId }]` |
| `POST /api/eutr-documents/list-po-references` | `004-eutr-documents` (Update 8; response DTO widened additively by **this feature's Update 5**, see below) | Step 2 AVAILABLE FILES (FR-026/FR-027, FR-049/FR-050/FR-051) | `{ poCodes: [...selected/saved PurchIds] }` |
| `POST /api/eutr-templates/get-all` + `GET /api/eutr-templates/{id}` | `003-eutr-templates` | Step 2 template tree (FR-023/FR-024); also re-invoked on demand by the Update 5 toolbar-reload interaction (FR-048) | `get-all` filter `{ column: "Code", operator: "eq", value: templateCode }, pageSize=1` → `{id}` from the one result → `GetById` |

No policy changes, no new controller actions for any of the four rows above.

**Update 5 (2026-07-27) exception**: `POST /api/eutr-documents/list-po-references`'s response DTO
(`EutrDocumentsPoReferenceItemDto`, owned by `004-eutr-documents`) gains three **additive** fields —
`stepIds: long[]`, `refType: byte?`, `typeName: string?` — needed for FR-049/FR-050 (Map
status/File type badges). This is the only DTO change on this page; see `data-model.md`'s "Update 5"
section and `research.md` Decisions 24-25 for the exact SQL/mapping change. `poCode` (already
returned, unchanged) is now also read as "PO value" (FR-051) — zero backend change for that field.

## Update 6 (2026-07-27) — Step 2 Upload/Edit reuse `004-eutr-documents`' Add/Edit write paths

Four more endpoints, all owned by `004-eutr-documents`, are now consumed **as-is** by
`MapFilePage.jsx` — via the reused `EutrDocumentsFormDialog.jsx` component itself (Upload/Edit no
longer call any endpoint directly from `MapFilePage.jsx`'s own code) plus one direct new call site
for edit-detail hydration:

| Endpoint | Owning feature | Used for | Notes |
|---|---|---|---|
| `POST /api/sharepoint/eutr-upload-multi` | `004-eutr-documents` | Upload popup, Type = "PO" | Called internally by `EutrDocumentsFormDialog`'s own `UploadToSharePointUseCase.executeEutrMulti` — `MapFilePage.jsx` never calls this directly |
| `POST /api/sharepoint/eutr-upload-multi-by-type` | `004-eutr-documents` | Upload popup, Type ≠ "PO" | Called internally by the same dialog's `executeEutrMultiByType` |
| `PUT /api/eutr-documents/{id}` | `004-eutr-documents` | Edit popup → Save (document fields) | Called internally by the dialog's `UpdateEutrDocumentsUseCase` |
| `PUT /api/eutr-documents/{id}/step` | `004-eutr-documents` | Edit popup → Save (step/value sync) | Called internally by the dialog's `UpdateEutrDocumentReferenceStepUseCase` |
| `POST /api/eutr-documents/get-all` (filtered `{ column: "Id", operator: "eq", value: documentId }`, `page=1,pageSize=1`) | `004-eutr-documents` | Edit-detail hydration, called directly by `MapFilePage.jsx` before opening the Edit popup | Same paging endpoint `004-eutr-documents`' own grid uses for its listing — reused with a single-`Id` filter (research.md Decision 27); zero backend change |
| `POST /api/eutr-documents/list-po-references` | `004-eutr-documents` | Re-invoked (not newly added — already listed above) after Upload/Edit succeeds, to refresh AVAILABLE FILES/Map status (FR-030a) | See research.md Decision 28 |

No new endpoint, no new controller action, no DTO change, no policy change for any of the four rows
above — all four already exist and are already exercised by `004-eutr-documents`' own screen; this
update is `MapFilePage.jsx` becoming a second caller of the same, unmodified endpoints (mostly
indirectly, through the reused dialog component itself).

## Update 7 (2026-07-27) — Zero endpoint changes; fixes a client-side scoping gap only

Spec Update 7 (FR-053..FR-057) introduces **no new and no changed endpoint at all**. The fix (Map
status/AVAILABLE FILES scoped correctly by PO ↔ Template) is built entirely from two already-returned
fields on endpoints already listed in this document:

- `GET /api/eutr-purchase-attachments/by-sales-id/{salesId}` (listed in `research.md` Decision 12,
  contract in `eutr-purchase-attachments-map-file.md`) — its `PurchaseAttachmentDto[]` already carries
  `purchId`/`templateCode` per row; this is the entire PO→Template lookup the fix needs.
- `POST /api/eutr-documents/list-po-references` (row above) — each flattened AVAILABLE FILES entry
  already carries `poCode` (Update 5, `EutrDocumentsPoReferenceDto.poCode`).

No request/response shape changes for either. See `data-model.md`'s "Update 7" section and
`research.md` Decisions 29-30 for how these two already-available fields are joined client-side.

## Update 9 (2026-07-27) — View button reuses `004-eutr-documents`'s file-content preview popup

One more endpoint, owned by `004-eutr-documents`, is now consumed **as-is** by `MapFilePage.jsx` —
indirectly, through the reused `EutrFileViewerDialog` component (no direct call from
`MapFilePage.jsx`'s own code):

| Endpoint | Owning feature | Used for | Notes |
|---|---|---|---|
| `GET /api/eutr-documents/get-file-by-idref?idRef={fileId}` | `004-eutr-documents` | View popup — fetches file content (base64) for preview | Called internally by `EutrFileViewerDialog`'s `fetchFile` prop, via `GetEutrDocumentsFileByIdRefUseCase` — `MapFilePage.jsx` never calls this directly. Same endpoint `004-eutr-documents`'s own grid already uses for its own View action. |

No new endpoint, no new controller action, no DTO change, no policy change — this update is
`MapFilePage.jsx` becoming a second caller of an already-existing, unmodified endpoint (indirectly,
through the reused `EutrFileViewerDialog` component). `fileId` (already present on every
`realAvailableFiles` entry since Update 5) is the only value `MapFilePage.jsx` itself needs to supply.
See `data-model.md`'s "Update 9" section and `research.md` Decision 35.

## Update 11 (2026-07-27) — Zero endpoint changes; client-side filter-predicate fix only

Spec Update 11 (FR-077..FR-081) introduces **no new and no changed endpoint at all**. The fix (align
`MapFilePage.jsx`'s `computeProgress()` with the `AUTO_SOURCES` exclusion already applied by
`missingRequired` and by `ViewSalesOrderPage.jsx`'s own equivalent variables) is a single filter-
predicate edit over data already delivered by endpoints already listed in this document — no request or
response shape changes anywhere. See `research.md` Decision 41.

## Update 17 (2026-08-11) — Variants/Materials columns on Step 1, via a second call to the existing generic reference endpoint

| Endpoint | Owning feature | Used for | Request shape used |
|---|---|---|---|
| `POST /api/dynamics/reference?refType=20` | `005-eutr-sales-orders` (this feature, Update 17) — first working caller | Step 1 Variants/Materials columns (FR-113..FR-116) | `filters: [{ column: "InterCompanyOriginalSalesId", operator: "eq", value: salesId }]`, `page=1, pageSize=500` |

This is the same generic `POST /api/dynamics/reference` action already listed above for `refType=16` and
`refType=11` — no new controller action, no new DTO. **`refType=20` itself needed one backend fix**: its
D365 entity (`RSVNEutrSalesOrderPurchLines`), `MapDynamicsResponse` case, and `ComplDynReferenceResponseDto`
fields already existed and already compiled, but `ComplDynamicsService.EntityMappings` had no dictionary
entry for key `20` — so the endpoint silently returned an empty list for this `refType` regardless of the
filter sent, the same class of "entity/case shipped, registration missing" bug this file's owning
`ComplDynamicsService.cs` already documents having been found and fixed twice before, for `refType=18`
(`009-compl-sales-order-missing`) and `refType=19` (`011-eutr-synchronize-data`). This feature's fix is the
third instance of that same one-line pattern: `{ 20, ("RSVNEutrSalesOrderPurchLines",
"InterCompanyOriginalSalesId", "ProductVariant") },`. See `research.md` Decision 63 and `data-model.md`'s
"Update 17" section.
