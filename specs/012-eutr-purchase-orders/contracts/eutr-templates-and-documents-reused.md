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

**Component prop contract addendum (spec Update 1, FR-024/FR-025/FR-026, research.md Decision 9)**:
`EutrDocumentsFormDialog` gains two new **optional** props, meaningful only when `mode="add"`:

| Prop | Type | Effect when set | When omitted |
|---|---|---|---|
| `addDefaultTypeName` | `string` | Initial `Type` is the reference-type entry whose name matches (case-insensitive), instead of `null` | `Type` starts `null` (unchanged existing behavior) |
| `resolveAddDefaultChips` | `(typeName: string) => array` | Initial `Value` chips are `resolveAddDefaultChips(addDefaultTypeName)`, instead of `[]` (superseded — see Update 2 addendum below, this prop also now drives every subsequent Type change, not only the initial open) | `Value` starts `[]` (unchanged existing behavior) |

Only `PurchaseOrderViewPage.jsx` passes these (`addDefaultTypeName="PO"`,
`resolveAddDefaultChips={...}`, see Update 2 addendum). `MapFilePage.jsx`'s existing call site passes
neither, so its popup's reset-to-empty behavior is unchanged — this addendum does not alter any
existing consumer of `EutrDocumentsFormDialog`.

**Component prop contract addendum (spec Update 2, FR-027/FR-028/FR-029, research.md Decision 10)**:
the static `addDefaultChips` prop (Update 1) is replaced by the function prop `resolveAddDefaultChips`
above, now consulted on **every** Type change while the popup is open in `mode="add"` (not only at
open time), replacing the dialog's previous unconditional "clear chips on Type change" behavior when
a resolver is supplied:

| Type selected in the popup | `resolveAddDefaultChips(typeName)` returns | Value chips become |
|---|---|---|
| `PO`, `Invoice`, `Delivery note` | `[po]` (the Purchase Order being viewed) | `[po]` (overwrites current chips) |
| `Vendor` | `[{ code: po.orderAccount, name: vendorName }]` | that single Vendor chip (overwrites current chips) |
| any other Type (e.g. `General agreement`), or no resolver supplied | `[]` | `[]` (existing reset-to-empty behavior, unchanged) |

The re-filled Value is still not locked — `showEditableChips`/`EutrAddValueAutocomplete` continue to
accept user edits/removals/additions exactly as before (FR-025/FR-028). `MapFilePage.jsx` passes no
`resolveAddDefaultChips`, so its Type-change handler keeps clearing chips to `[]` exactly as before —
unaffected by this addendum.

`EutrFileViewerDialog.jsx` (owner: `004-eutr-documents`) is reused for the AVAILABLE FILES "View"
action, backed by the existing `GET /api/eutr-documents/get-file-by-idref` — unchanged.
