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
