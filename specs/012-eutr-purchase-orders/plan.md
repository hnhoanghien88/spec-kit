# Implementation Plan: EUTR Purchase Orders

**Branch**: `012-eutr-purchase-orders` | **Date**: 2026-08-14 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/012-eutr-purchase-orders/spec.md`

## Summary

Add a new EUTR Purchase Orders module: an Overview list screen (`/eutr/purchase-orders`) showing
Purch id / Vendor code / Vendor name / Template / Progress / Action(View), and a detail screen
(`/eutr/purchase-orders/:purchId/view`) that is `005-eutr-sales-orders`'s **Map File Step 2**
(template step tree + AVAILABLE FILES + Upload/Edit) reused as-is, minus Step 1 (Choose PO) and the
Selected POs table, with the header swapped from Sales ID/Customer to Purch id/Vendor code/Vendor
name.

Investigation (research.md) found this is **almost entirely a frontend-reuse feature**: the ERP
reference data this feature needs — `refType = 15` (`RSVNEutrPurchOrders`: `PurchId`, `Name`,
**`EutrTemplate`**, **`OrderAccount`**) and `refType = 14` (`VendorsV3`, for Vendor name lookup by
Vendor code) — is already fully registered in `ComplDynamicsService.EntityMappings` and already
returns the `EutrTemplate`/`OrderAccount` fields (added additively by `011-eutr-synchronize-data`
for its own missing-documentation report, which uses these exact same two reference types and the
exact same "Purch id / Vendor code / Vendor name / Template" terminology this spec's columns match).
Unlike `005-eutr-sales-orders` (where a Sales Order's Template must be joined through the local
`eutr_purchase_attachments` table because one Sales Order can carry several Purchase Orders/
Templates), **each Purchase Order here carries exactly one Template directly on itself**
(`EutrTemplate`) — so there is no PO-selection step and no local join table to read or write; the
detail screen only ever renders one template's step tree for the one Purchase Order in its URL.

`POST /api/eutr-templates/by-codes` (003, added by 005 Update 12) and
`POST /api/eutr-documents/list-po-references` (004) already return everything needed to build the
step tree and the AVAILABLE FILES list; the Upload/Edit dialogs (`EutrDocumentsFormDialog.jsx`) and
the shared `computeProgress()` util (`eutr-sales-orders/utils/progressUtils.js`) are reused
byte-for-byte, the same cross-feature-import precedent `005` itself already established for these
exact pieces.

The one genuine gap (research.md Decision 6): the generic reference endpoint's OR-search only
special-cases each entity's `Code`/`Name` columns (`PurchId`/`Name` for `refType=15`) — there is no
existing way to OR a third column (`OrderAccount`, i.e. Vendor code) into the same free-text search.
This needs one small, additive backend change to `ComplDynamicsService.BuildFilterString`
(`compliance-sys-api`) — not a new endpoint, not a new table, not a new controller.

## Technical Context

**Language/Version**: Backend .NET 8 (C#, existing `ComplianceSys.Api`/`Application`/`Domain`/
`Infrastructure`); Frontend React 18 + Vite (existing `compliance-client`).

**Primary Dependencies**: Existing stack only — MUI (`@mui/material`), `react-router-dom`, `lodash`
(debounce), Dapper (backend data access, no new queries needed beyond the one filter-builder change).

**Storage**: MySQL via Dapper — **no new table, no migration**. All data this feature reads is
either live ERP reference data (via the existing `POST /api/dynamics/reference` proxy) or already
read via existing `003-eutr-templates`/`004-eutr-documents` endpoints.

**Testing**: Manual end-to-end validation per `quickstart.md` (matching this codebase's existing
practice for `003`/`004`/`005` — no automated test suite was added by those features either).

**Target Platform**: Web (existing `compliance-client` SPA), same authenticated admin area as the
other EUTR screens.

**Project Type**: Web application (existing monorepo: `compliance-client` frontend +
`compliance-sys-api` backend).

**Performance Goals**: List screen must page/search without loading the full ERP Purchase Order
population (confirmed by `011-eutr-synchronize-data` to be 3,000+ rows) client-side — reuse the
existing server-side paged `POST /api/dynamics/reference` call, and batch the Template-steps/
Documents lookups needed for Progress **once per visible page** (same batching pattern
`SalesOrderOverviewPage.jsx` already uses for its own Progress column — spec 005 Update 12), not
once per row.

**Constraints**: Must not duplicate the `computeProgress`/step-vs-document matching logic that
already exists in `eutr-sales-orders/utils/progressUtils.js` — reuse it directly per Constitution
Principle II precedent (005 Update 12 already centralized this specifically to prevent drift across
consumers).

**Scale/Scope**: 2 new frontend pages (Overview list, Purchase Order View/manage-documents), 1
small additive backend change (search filter), 1 new route + 1 new top-level menu entry (operational
DB seeding required, see Constitution Principle V / research.md Decision 8).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Layered Clean Architecture**: PASS. Frontend stays within the existing `presentation/pages/*`
  + `application/usecases/*` + `di/repositories.js` layering already used by every sibling EUTR
  feature (no new domain/infrastructure classes needed — every repository this feature calls
  already exists: `repositories.dynamics`, `repositories.eutrTemplates`, `repositories.eutrDocuments`).
  Backend's one small change stays inside `ComplianceSys.Application.Services.ComplDynamicsService`
  (existing service, existing layer boundary — no controller/domain change).
- **II. Reference-Pattern Reuse**: PASS, with one explicit deviation from the constitution's named
  canonical reference (`document-type`): this feature clones **`005-eutr-sales-orders`**
  (`SalesOrderOverviewPage.jsx` for the list, `MapFilePage.jsx` Step 2 for the detail screen)
  instead, because `005` is "an existing, working feature of the same shape" in the sense the
  principle actually asks for — same ERP-reference-data-driven list + Template + Document
  step-completion domain — which `document-type` (a plain local CRUD entity) is not. `005` itself
  already established this same deviation (cloning `004-eutr-documents`'s dialogs rather than
  `document-type`'s), so this is consistent precedent, not a new pattern.
- **III. Reuse Existing Backend**: PASS. `refType=15`/`refType=14`, `EutrTemplates.by-codes`,
  `EutrDocuments.list-po-references`/Add/Edit are reused unchanged. The one verified gap (OR-search
  needing a third column) is the only backend edit, and it is additive-only (widens
  `BuildFilterString`'s existing switch, touches no other `refType`'s behavior).
- **IV. Vietnamese Comments; Localizable UI Labels**: PASS. New code comments in Vietnamese; UI
  labels follow the spec (Vietnamese screen, matching `005`'s own UI language) — no deviation
  requested by the spec, so no localization exception needed.
- **V. Routing & Menu Registration**: Addressed in Project Structure/research.md Decision 8 — new
  route registered in `RouteResolver.jsx` (`codeToComponent['eutr-purchase-orders']`) and
  `MainRoutes.jsx` (nested `:purchId/view` route, mirroring `MapFilePage`/`ViewSalesOrderPage`'s
  existing entries), plus the static `menu-items/ComplianceSystem.jsx` entry sibling features all
  have. Per this repo's established convention (see memory: routing is backend-userMenu-driven),
  the screen is not reachable until an operator also seeds a `userMenu` row (`code:
  'eutr-purchase-orders'`, `url: '/eutr/purchase-orders'`) and grants `canAccessMenu` in the DB —
  this is an operational step, not a code task, and is called out explicitly so it isn't missed.

No violations requiring Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/012-eutr-purchase-orders/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md         # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
compliance-sys-api/
└── src/ComplianceSys.Application/Services/
    └── ComplDynamicsService.cs        # ONE additive edit: BuildFilterString gains an
                                        # "OrderAccount" (Vendor code) OR-search bucket for
                                        # refType=15, alongside the existing Code/Name buckets
                                        # (research.md Decision 6). No new file.

compliance-client/
├── src/app/routes/
│   ├── RouteResolver.jsx              # + codeToComponent['eutr-purchase-orders']
│   └── groups/MainRoutes.jsx          # + nested route '/eutr/purchase-orders/:purchId/view'
│                                       #   (mirrors the existing MapFilePage/ViewSalesOrderPage
│                                       #   nested-route entries)
├── src/presentation/menu-items/
│   └── ComplianceSystem.jsx           # + one new EUTR-system child entry
│                                       #   (code: eutr-purchase-orders, url: /eutr/purchase-orders)
└── src/presentation/pages/eutr-purchase-orders/     # NEW feature folder (mirrors eutr-sales-orders/)
    ├── PurchaseOrderOverviewPage.jsx   # NEW — list screen (clones SalesOrderOverviewPage.jsx's
    │                                   #   data-fetch/search/pagination/Progress-batching shape)
    └── PurchaseOrderViewPage.jsx       # NEW — detail screen (clones MapFilePage.jsx's Step 2 only:
                                        #   template tree + AVAILABLE FILES + Upload/Edit; no Step 1,
                                        #   no Selected POs table, header shows Purch id/Vendor
                                        #   code/Vendor name instead of Sales ID/Customer)
```

**Structure Decision**: Existing web monorepo (`compliance-client` + `compliance-sys-api`), no new
projects. New work is one small backend service-layer edit plus a new frontend feature folder
`presentation/pages/eutr-purchase-orders/` with 2 page components, following the exact
route/menu-registration shape `005-eutr-sales-orders` already established (nested detail route in
`MainRoutes.jsx`, top-level menu entry via `RouteResolver.jsx` + `menu-items/`). No new
`application/usecases/*` files are needed — every use case this feature calls
(`GetReferenceDataUseCase`, `GetEutrTemplatesByCodesUseCase`, `GetEutrDocumentsPoReferencesUseCase`,
plus the Add/Edit use cases already wired inside `EutrDocumentsFormDialog.jsx`) already exists and
is reused unchanged.

## Complexity Tracking

*No Constitution Check violations — table not needed.*

## Update 1 (2026-09-07) — Upload default Type/Value on `PurchId/View`

**Spec delta**: FR-024/FR-025/FR-026 (spec.md Update 1). When the user clicks **Upload** on the
`PurchId/View` detail screen only, the shared `EutrDocumentsFormDialog` (004-eutr-documents) now
opens pre-filled with Type = `PO` and Value = the Purchase Order currently being viewed, still fully
editable. The Map File screen (005-eutr-sales-orders) is explicitly unaffected — Decision 26 of that
spec's "full, unrestricted popup" stays in force there.

**Summary**: Purely additive frontend change, no backend/API/data-model change. Two optional props
(`addDefaultTypeName`, `addDefaultChips`) are added to `EutrDocumentsFormDialog.jsx` — consumed only
when `mode="add"` and only set by `PurchaseOrderViewPage.jsx`. `MapFilePage.jsx` (005) passes neither
prop, so its existing reset-to-empty behavior on open is byte-for-byte unchanged. The default Value
chip is not fetched separately — it reuses the same `po` reference-data object (`refType=15`, already
loaded for the page header, shape-compatible with the chips `EutrAddValueAutocomplete` normally
produces) already held in `PurchaseOrderViewPage.jsx` state (see research.md Decision 9).

**Technical Context delta**: No change to Language/Version, Primary Dependencies, Storage, Testing,
Target Platform, or Project Type. No new network call is introduced — the prefill source (`po` state)
is already fetched by the existing FR-013/FR-014 existence-check call.

**Constitution Check (re-evaluated)**: Still PASS on all five principles — no new backend surface
(III), no new route/menu (V), no new local storage (I), no localization deviation (IV). Principle II
(Reference-Pattern Reuse) is reinforced, not weakened: the change deliberately keeps `005`'s Map File
call site untouched rather than changing the shared dialog's default behavior globally, preserving
that spec's own explicit "no auto-lock" decision as prior, unmodified precedent.

### Project Structure delta

```text
compliance-client/src/presentation/pages/
├── eutr-documents/components/
│   └── EutrDocumentsFormDialog.jsx     # + 2 new optional props (addDefaultTypeName, addDefaultChips),
│                                       #   consumed only in the mode="add" init effect; no prop ->
│                                       #   no behavior change (MapFilePage.jsx call site unaffected)
└── eutr-purchase-orders/
    └── PurchaseOrderViewPage.jsx       # Upload button's <EutrDocumentsFormDialog mode="add" .../>
                                        #   now passes addDefaultTypeName="PO" and
                                        #   addDefaultChips={po ? [po] : []} (reuses existing `po` state)
```

No files added, no files removed, no backend files touched.

## Update 2 (2026-09-10) — Re-fill Value on every Type change (`PurchId/View`)

**Spec delta**: FR-027/FR-028/FR-029 (spec.md Update 2). Extends Update 1: previously the Upload
popup's Type/Value defaulted to PO/this-Purchase-Order only once, at open. Now, while the popup stays
open on `PurchId/View`, **every** time the user changes Type, Value is re-derived: Type = PO, Invoice,
or Delivery note → Value = this Purchase Order's Purch id; Type = Vendor → Value = this Purchase
Order's Vendor code. Any other Type is unaffected (no auto-fill, existing free-entry behavior). The
re-filled Value overwrites whatever was in the field, and remains fully editable afterward (FR-028).

**Summary**: Purely additive frontend change, no backend/API/data-model change. The static
`addDefaultChips` prop (Update 1) is replaced by a function prop, `resolveAddDefaultChips(typeName)`,
consulted both at initial open (superseding `addDefaultChips`) and — newly — inside
`EutrDocumentsFormDialog`'s existing `handleTypeChange` handler, in place of its previous
unconditional `setChips([])` reset. `PurchaseOrderViewPage.jsx` supplies the resolver, built from
state it already holds (`po` for the PO-like branch, `{code: po.orderAccount, name: vendorName}` for
the Vendor branch — no new network call). `MapFilePage.jsx` passes no resolver, so its Type-change
handler keeps clearing chips to `[]` exactly as before (FR-029). See research.md Decision 10,
data-model.md §6, and the contracts addendum in `eutr-templates-and-documents-reused.md`.

**Technical Context delta**: No change to Language/Version, Primary Dependencies, Storage, Testing,
Target Platform, or Project Type. No new network call — both branches of the resolver reuse `po` and
`vendorName` state already fetched by the existing header/Vendor-name-lookup effects (FR-003/FR-015).

**Constitution Check (re-evaluated)**: Still PASS on all five principles — no new backend surface
(III), no new route/menu (V), no new persisted state (I), no localization deviation (IV). Principle II
is reinforced the same way as Update 1: `MapFilePage.jsx`'s call site is left untouched (no resolver
passed), so `005`'s Decision 26 ("no auto-lock") stays in force there unmodified.

### Project Structure delta

```text
compliance-client/src/presentation/pages/
├── eutr-documents/components/
│   └── EutrDocumentsFormDialog.jsx     # addDefaultChips prop replaced by resolveAddDefaultChips(typeName)
│                                       #   function prop; used both in the mode="add" init effect and in
│                                       #   handleTypeChange (replaces its unconditional setChips([]) when
│                                       #   a resolver is supplied); no resolver -> unchanged behavior
│                                       #   (MapFilePage.jsx call site unaffected)
└── eutr-purchase-orders/
    └── PurchaseOrderViewPage.jsx       # Upload button's <EutrDocumentsFormDialog mode="add" .../> now
                                        #   passes resolveAddDefaultChips instead of addDefaultChips —
                                        #   maps Type name -> [po] (PO/Invoice/Delivery note) or
                                        #   [{code: po.orderAccount, name: vendorName}] (Vendor) or []
```

No files added, no files removed, no backend files touched.

## Update 3 (2026-09-18) — Inherited file-rename-by-Step behavior from `004-eutr-documents` Update 25

No code change in this feature — Upload/Edit on `PurchId/View` already call the shared
`004-eutr-documents` Add/Edit flow unchanged, so the Step/Prefix file-rename behavior added there is
inherited automatically. See spec.md Update 3 and `004-eutr-documents`'s own plan for the actual
change. No Project Structure delta.

## Update 4 (2026-09-22) — Hide Upload button without permission (`PurchId/View`)

**Spec delta**: FR-030/FR-031/FR-032 (spec.md Update 4). The **Upload** button on `PurchId/View`
MUST only render when the current user holds the permission that already guards the real Upload
action — the same `EutrDocuments.Create` policy `POST /api/eutr-documents` is already gated by
(clarified with the user: "quyền Update" in the original request maps to this real capability, not a
literal `EutrDocuments.Update` policy or a new PO-specific permission — see spec.md Clarifications).
When absent, the button is fully hidden (not disabled); the Edit button and the rest of the screen are
unaffected.

**Summary**: One small additive backend endpoint plus one small additive frontend check —
`GET /api/eutr-documents/can-create` (`EutrDocumentsController`, new action, guarded by the existing
`[Authorize(Policy = "EutrDocuments.Create")]`) is called once by `PurchaseOrderViewPage.jsx` on
mount, alongside the existing PO-existence check; the resulting boolean (`canUploadDocuments`, default
`false` until resolved) conditionally renders the Upload button. See research.md Decision 11 for why a
dedicated, policy-scoped endpoint was chosen over a generic policy-check endpoint or extending the
external AuthZ microservice.

**Technical Context delta**: No change to Language/Version, Primary Dependencies, Storage, Testing,
Target Platform, or Project Type. One new lightweight backend endpoint (no new controller, no new
DTO/table/migration — reuses `ApiResponse<bool>`) and one new frontend network call per page load (no
new dependency).

**Constitution Check (re-evaluated)**: Still PASS on all five principles.
- **I. Layered Clean Architecture**: PASS — the new action lives directly on the existing
  `EutrDocumentsController` (Api layer), delegating entirely to the framework's own authorization
  pipeline; no new Application/Domain/Infrastructure classes are needed since the action performs no
  business logic beyond the `[Authorize]` check itself.
- **II. Reference-Pattern Reuse**: PASS — follows the exact `[Authorize(Policy = "...")]` attribute
  convention every other action on `EutrDocumentsController` already uses; no new pattern introduced.
- **III. Reuse Existing Backend**: PASS, most directly of any Update so far — the new endpoint reuses
  the *exact* pre-existing `EutrDocuments.Create` policy (already seeded/granted per role for the real
  Upload action across `004`/`005`/`012`); zero new AuthZ resource/DB seeding.
- **IV. Vietnamese Comments; Localizable UI Labels**: PASS — no new user-facing text is introduced
  (the button simply does not render; no new label/message needed).
- **V. Routing & Menu Registration**: N/A — no new route or menu entry.

No violations requiring Complexity Tracking.

### Project Structure delta

```text
compliance-sys-api/
└── src/ComplianceSys.Api/Controllers/
    └── EutrDocumentsController.cs      # + one new GET action, can-create, guarded by the existing
                                          #   [Authorize(Policy = "EutrDocuments.Create")] — no new
                                          #   DTO, no business logic, returns ApiResponse<bool>.Ok(true)

compliance-client/
└── src/presentation/pages/eutr-purchase-orders/
    └── PurchaseOrderViewPage.jsx        # + one new state field (canUploadDocuments, default false)
                                          #   resolved by a new call to GET /api/eutr-documents/can-create
                                          #   on mount (parallel to the existing PO-existence check);
                                          #   the Upload button's render is now guarded by this flag —
                                          #   the Edit button and everything else are unaffected
```

No files removed. `MapFilePage.jsx` (005-eutr-sales-orders) is not touched — this Update's scope is
limited to `PurchId/View`'s Upload button only (spec.md Update 4 Decision).

## Update 5 (2026-09-23) — Gate Upload/Edit on `permissionList` of menu `eutr-documents` (corrects Update 4's mechanism too)

**Spec delta**: FR-030 (mechanism corrected), FR-033/FR-034/FR-035/FR-036 (spec.md Update 5). The
per-row **Edit** button on `PurchId/View` MUST only render when `permissionList` for menu
`eutr-documents` includes `'Update'`; the **Upload** button (FR-030, originally Update 4) is corrected
to use the same mechanism instead of a live backend probe. Independent conditions. When either is
absent, that button is fully hidden (not disabled); the other button and the rest of the screen are
unaffected.

**Summary — as shipped, after correction**: an early draft of this Update added a new backend endpoint
(`GET /api/eutr-documents/can-update`, owned by `005-eutr-sales-orders`'s own Update 29) mirroring
Update 4's pre-existing `can-create`. Live testing (browser DevTools) showed both probes were
unnecessary: the menu `eutr-documents`'s `permissionList` — already delivered by the same external
menu/auth service `005-eutr-sales-orders` Update 28 already reads for menu `eutr-sales-orders` — already
carries `'Create'`/`'Update'` whenever the role is granted them. Both `can-create` (Update 4) and
`can-update` (this Update's early draft) were removed; `PurchaseOrderViewPage.jsx` now derives
`canUploadDocuments`/`canEditDocuments` from `permissionList` directly (research.md Decision 11).

**Technical Context delta**: No change to Language/Version, Primary Dependencies, Storage, Testing,
Target Platform, or Project Type. Net **zero** backend files (both probe endpoints were added and then
removed within this session) and **zero** new network calls per page load (a decrease from Update 4's
original 1 call — `permissionList` is read from `localStorage`, already cached at login/menu-load time).

**Constitution Check (re-evaluated)**: Still PASS on all five principles — **II. Reference-Pattern
Reuse** applies more directly now than either prior draft: this Update reuses the exact
`permissionList`/`getMenuDataFromStorage` pattern already established by Update 28, rather than
introducing a second, parallel live-probe convention.

No violations requiring Complexity Tracking.

### Project Structure delta

```text
compliance-client/
└── src/presentation/pages/eutr-purchase-orders/
    └── PurchaseOrderViewPage.jsx        # Upload/Edit gating reworked: removed
                                          #   CheckEutrDocumentsCanCreateUseCase/CanUpdateUseCase
                                          #   imports+state+effects; added getMenuDataFromStorage import
                                          #   + eutrDocumentsPermissionList useMemo + 2 derived consts
                                          #   (canUploadDocuments, canEditDocuments) — the Upload Button
                                          #   and per-row Edit IconButton's own conditional wrappers are
                                          #   unchanged, only what feeds them changed
```

No new file in `compliance-sys-api` — the `can-create`/`can-update` actions this Update's early draft
depended on (one pre-existing from Update 4, one added by `005-eutr-sales-orders`'s Update 29) were both
removed from `EutrDocumentsController.cs`; `CheckEutrDocumentsCanCreateUseCase.js`/
`CheckEutrDocumentsCanUpdateUseCase.js` and the `canCreate`/`canUpdate` repository/API methods were
deleted (no remaining callers).

## Update 6 (2026-09-24) — Inherited Prefix-removal from `004-eutr-documents` Update 26

No code change in this feature — Upload/Edit on `PurchId/View` already call the shared
`004-eutr-documents` Add/Edit flow unchanged, so dropping the Prefix component from the file-rename
formula (`004-eutr-documents` Update 26, FR-068–FR-070, superseding the Update 25 formula this feature
already inherited at its own Update 3) applies automatically. See spec.md Update 6 and
`004-eutr-documents`'s own plan for the actual change. No Project Structure delta.

## Update 7 (2026-09-24) — Inherited expanded upload-format whitelist from `004-eutr-documents` Update 27

No code change in this feature — Upload/Edit on `PurchId/View` already call the shared
`004-eutr-documents` Add/Edit flow unchanged, so allowing `.xml`/`.json`/`.geojson` uploads
(`004-eutr-documents` Update 27, FR-071) applies automatically. Confirmed via codebase research that
the "multiple files per Step, clearly shown" half of the originating request needs no change here
either — `PurchaseOrderViewPage.jsx`'s Step tree is a clone of `005-eutr-sales-orders`'s `TreeNode`
logic (already noted at this feature's own Update 3/plan.md) and already renders the same "(+N)"
badge/full-name tooltip for multiple files mapped to one Step. See spec.md Update 7 and
`004-eutr-documents`'s own plan for the actual change. No Project Structure delta.

## Update 8 (2026-09-24) — Inherited raised size limit from `004-eutr-documents` Update 28

No code change in this feature — Upload/Edit on `PurchId/View` already call the shared
`004-eutr-documents` Add/Edit flow unchanged, so the raised per-file size limit (10MB → 20MB,
`004-eutr-documents` Update 28, FR-073) applies automatically. See spec.md Update 8 and
`004-eutr-documents`'s own plan for the actual change. No Project Structure delta.

## Update 9 (2026-09-24) — New per-row Download button on AVAILABLE FILES; download file name = Step Name (FR-037/FR-038)

Unlike Update 3/6/7/8 above, this update has **real code of its own** — `PurchaseOrderViewPage.jsx`'s
AVAILABLE FILES rows are this feature's own duplicated copy of the tree/row UI (not a call into a
shared `005-eutr-sales-orders` component), so the Download button and the download-time file-name
recompute (decided at `005-eutr-sales-orders` Update 33 — see that feature's research.md Decision
82/83 for full rationale) had to be applied here too:

```text
compliance-client/
└── src/presentation/pages/eutr-purchase-orders/
    └── PurchaseOrderViewPage.jsx   # EDIT: new `Download as DownloadIcon` + `GetEutrDocumentsFileByIdRefUseCase`
                                     #   + `buildStepOnlyFileName` (from `005-eutr-sales-orders` Update 33's
                                     #   new shared `eutr-documents/utils/buildStepOnlyFileName.js`) imports;
                                     #   module-level `getEutrDocumentsFileByIdRefUseCase` instance; new
                                     #   `handleDownloadFile(file)` callback (same shape as
                                     #   `MapFilePage.jsx`'s); new Download `IconButton` after Edit on each
                                     #   AVAILABLE FILES row; `stepNames` added to `viewerFile` state,
                                     #   `setViewerFile(...)` call, and `<EutrFileViewerDialog stepNames={...}>`
```

`compliance-client/src/presentation/pages/eutr-documents/utils/buildStepOnlyFileName.js` and
`compliance-client/src/presentation/pages/eutr-documents/components/EutrFileViewerDialog.jsx` are
**shared** with `005-eutr-sales-orders` — both were added/edited once (tracked in that feature's own
plan.md, Update 33) and reused here verbatim, not duplicated. Zero backend change — reuses the
existing `GET /eutr-documents/get-file-by-idref` endpoint.

## Update 10 (2026-09-24) — Explicit Search button next to the search box on the Purchase Orders list (FR-039)

Same pattern already established at `005-eutr-sales-orders`'s Overview (`SalesOrderOverviewPage.jsx`,
Update 24) — a `<Button variant="contained">Search</Button>` next to the existing `TextField`, calling
the same fetch function the debounced `onChange` already uses, just without waiting for the 500ms
debounce. No URL query-param sync was added (unlike the Sales Orders version), since this screen has
no existing Back-restore infrastructure and the request didn't ask for one.

```text
compliance-client/src/presentation/pages/eutr-purchase-orders/
└── PurchaseOrderOverviewPage.jsx   # EDIT: add `Stack`/`Button` imports; wrap the existing search
                                     #   `TextField` in a `Stack` (row); new `handleSearchClick`
                                     #   (resets page to 0, calls `fetchPurchaseOrders(0, pageSize,
                                     #   search)` directly — bypasses the 500ms debounce); new
                                     #   `<Button variant="contained">Search</Button>` next to the field
```

Unchanged: the debounced auto-search on every keystroke (`handleSearchChange`/`debouncedFetch`), the
backend `GetReferenceDataUseCase`/`buildSearchFilters` query — no new/changed endpoint, entity, DTO, or
route.

## Update 11 (2026-09-30) — Template tree label shows the mapped file's name once uploaded; download for Type = "PO" documents no longer recomputes the file name as Step Name (FR-040/FR-041)

Same pattern as Update 9 above — `PurchaseOrderViewPage.jsx`'s tree/row UI is this feature's own
duplicated copy (not a shared component call), so both changes decided at `005-eutr-sales-orders`
Update 37 (see that feature's research.md Decisions 88/89) had to be applied here too. The Upload-time
matching/no-rename change for Type = "PO" itself needs **zero** code here — it lives entirely in
`004-eutr-documents` Update 29's `EutrUploadService.cs`, and this screen's Upload/Edit buttons already
call that same shared popup/endpoint.

```text
compliance-client/
└── src/presentation/pages/eutr-purchase-orders/
    └── PurchaseOrderViewPage.jsx   # EDIT:
                                     #   - TreeNode: primary label changes from `{node.stepName}` to
                                     #     `{mappedFiles.length > 0
                                     #        ? stripFileExtension(mappedFiles[0].name)
                                     #        : node.stepName}` (FR-040) — new import
                                     #     `stripFileExtension` from
                                     #     `@presentation/pages/eutr-sales-orders/utils/progressUtils`
                                     #     (already added there for `005-eutr-sales-orders` Update 37);
                                     #     the existing secondary caption (`mappedFiles[0].name` + "(+N)")
                                     #     and status-icon tooltip are unchanged
                                     #   - `handleDownloadFile(file)`: skip `buildStepOnlyFileName(...)`
                                     #     and use `loadedFile.fileName || file.name` as-is when
                                     #     `file.typeName` is `'PO'` (case-insensitive) (FR-041)
                                     #   - `EutrFileViewerDialog` call site: pass new
                                     #     `typeName={viewerFile.typeName}` prop; `viewerFile` state gains
                                     #     a `typeName` field alongside `stepNames`
```

`EutrFileViewerDialog.jsx` itself (shared with `004-eutr-documents`/`005-eutr-sales-orders`) already
gained its `typeName` prop/Type-conditional skip at `005-eutr-sales-orders` Update 37 — reused here
verbatim, not duplicated.

Unchanged: every backend file (matching/no-rename lives in `004-eutr-documents`'s `EutrUploadService.cs`
only); the per-row Download button and its handler added in Update 9 (only the file-name computation
inside it becomes Type-conditional); the "(+N)" badge and status-icon tooltip (still show the full stored
name including extension).

# Update 12 (2026-10-05) — Remove pagination from AVAILABLE FILES (FR-042, SC-012; frontend-only)

**Scope**: `compliance-client/src/presentation/pages/eutr-purchase-orders/PurchaseOrderViewPage.jsx` only. Delete `FILES_PER_PAGE`, the `filePage` state, the `pagedFiles`/`totalFilePages` derivations and the `<Pagination>` control; render the full file list (already loaded in one call, filtered by tree node) inside the existing scrollable box. Footer keeps only "N files". No backend, entity, DTO, route or menu change.
**Constitution Check**: PASS — UI-only simplification, no new dependency or surface; no violations.

# Update 13 (2026-10-07) — "Assign template" button on the Purchase Orders list (FR-043..FR-047, SC-013)

**Scope**: Frontend `PurchaseOrderOverviewPage.jsx` (new button + new `AssignTemplateDialog.jsx` in the same folder) + new use cases/repository/api methods for two new endpoints; backend: new `EutrPurchaseOrdersController` (`api/eutr-purchase-orders`), `IEutrPurchaseOrdersService`/`EutrPurchaseOrdersService` (registered in `Application/DependencyInjection.cs`), request/response DTOs. No DB table/column/migration change, no new local entity.

**Design**:
- `GET api/eutr-purchase-orders/active-templates` (policy `EutrPurchaseOrders.Update`) → templates with `IsDeleted=0 AND IsHide=0 AND Status=1` (reuses `IEutrTemplatesRepository.GetEligibleForDynamicsSyncAsync`, the exact "active/Approved" rule the D365 sync already uses). Returns `{ id, code, name, versionId }`.
- `POST api/eutr-purchase-orders/assign-template` body `{ purchId, templateId, versionId }` (all strings, policy `EutrPurchaseOrders.Update`) → service re-validates that `templateId`/`versionId` match a currently active template (reject 400 otherwise), then `IDynamicService.PostAsync($"{apiUrl}/data/RSVNPurchTables/Microsoft.Dynamics.DataEntities.updateEutr?cross-company=true", body)`; `apiUrl` from `Dynamics:ApiUrl` (same as `EutrSynchronizeDataService.GetDynamicsApiUrl`). D365 failures propagate as an error response (FR-046); nothing local is written.
- Client: Action column gets an `AssignIcon` IconButton after View, rendered only when `permissionList` of menu `eutr-purchase-orders` includes `'Update'` (same mechanism as `PurchaseOrderViewPage` FR-033, `menuData.find(m => m.code === 'eutr-purchase-orders')`). Dialog loads active templates, single-select via radio list, current template (`row.eutrTemplate`, matched by Code) preselected + "Current" chip; OK disabled until selection ≠ current; on success close, snackbar, refetch list (`fetchPurchaseOrders(page, pageSize, search)`) so Template/Progress refresh; on error keep dialog open and show Alert. Double-submit blocked via `submitting` state.

**Technical Context additions**: Storage — none (D365 only). Testing — backend xUnit for service (mock `IDynamicService`, `IEutrTemplatesRepository`): valid push, mismatched template/version rejected, D365 exception propagates; frontend manual per quickstart. Performance — one small list call on dialog open + one POST. Constraints — policy name derived from menu code (`EutrPurchaseOrders.Update`) is assumed from the existing `EutrDocuments.Update` convention; verify at implementation/run time.

**Constitution Check**: PASS — no new dependency; follows existing Clean-architecture layering (controller → service → external `IDynamicService`).
