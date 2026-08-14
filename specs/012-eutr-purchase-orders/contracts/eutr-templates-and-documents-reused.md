# Contract: `003-eutr-templates` and `004-eutr-documents` endpoints reused as-is

**Status**: Existing endpoints, zero change. Documented here only to record exactly what this
feature relies on from each, per Constitution Principle III (verify, don't regenerate).

## `POST /api/eutr-templates/by-codes` (owner: `003-eutr-templates`)

`EutrTemplatesController.cs:70`, `GetManyByCodes([FromBody] List<string>? codes)`.

**Request**: `["TPL-A", "TPL-B"]` — the distinct `EutrTemplate` values from the current page of
Purchase Orders (list screen), or a single-element list for the detail screen.

**Response**: existing `EutrTemplatesResponseDto[]`, each with its full step-detail tree
(`StepId`/step name, `RequirementType`, `TakeFrom`, parent/child ordering) — everything
`computeProgress()` and the detail screen's tree renderer need. Unresolvable codes (no matching
Template) are simply absent from the response — treated as "no Template" per data-model.md §1.

## `GET /api/eutr-templates/{id}` (owner: `003-eutr-templates`)

`EutrTemplatesController.cs:57` — alternative single-template fetch, usable on the detail screen if
resolving by `Id` is more convenient in context than `by-codes` with a one-element list. Either is
acceptable; `by-codes` is preferred for the list screen's page-batched call.

## `POST /api/eutr-documents/list-po-references` (owner: `004-eutr-documents`)

`EutrDocumentsController.cs:147`, `GetPoReferences([FromBody] EutrDocumentsListPoReferencesRequestDto)`.

**Request**: the page's union of Purch ids (list screen) or the single Purch id in the URL (detail
screen) — same shape `005-eutr-sales-orders`'s `MapFilePage.jsx`/`SalesOrderOverviewPage.jsx` already
send for their own PO-scoped document lookups.

**Response**: existing `EutrDocumentsPoReferenceItemDto[]`, each carrying `poCode`, `stepIds`,
`typeName`, `fileId`, and the other fields `MapFilePage.jsx`'s AVAILABLE FILES already renders.
Reused verbatim for this feature's AVAILABLE FILES list and its step "missing" derivation.

## Document write paths (owner: `004-eutr-documents`, reused via existing UI component)

`EutrDocumentsFormDialog.jsx` (Add and Edit modes) is imported into the new
`PurchaseOrderViewPage.jsx` exactly as `MapFilePage.jsx` already imports it (spec 005 Update 6) —
no new request/response contract; the popup's own existing calls (`POST /api/eutr-documents`,
`PUT /api/eutr-documents/{id}`, `PUT /api/eutr-documents/{id}/step`, plus the SharePoint upload
endpoints it already wraps) are unchanged and out of scope for this feature to alter.

`EutrFileViewerDialog.jsx` (owner: `004-eutr-documents`) is reused for the AVAILABLE FILES "View"
action, backed by the existing `GET /api/eutr-documents/get-file-by-idref` — unchanged.
