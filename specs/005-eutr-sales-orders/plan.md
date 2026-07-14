# Implementation Plan: EUTR Sales Orders Management

**Branch**: `005-eutr-sales-orders` | **Date**: 2026-07-14 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/005-eutr-sales-orders/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Wire the already-scaffolded `SalesOrderOverviewPage.jsx` (route `/eutr/sales-orders`, menu code
`eutr-sales-orders` — already registered and reachable) to real Sales Order data instead of its
current hardcoded mocks. The 4 real columns (Sales ID, Customer, Customer name, Delivery date) MUST
come from the existing shared D365 reference endpoint (`POST /api/dynamics/reference`) using
reference type **11**, which is the codebase's own pre-defined `ObjectType.SALE_ORDER = 11` — already
used elsewhere (`compliance-view-so`) but **not yet registered** in `ComplDynamicsService.EntityMappings`
(currently returns an empty list for `refType=11`). The Template and Progress columns stay as fixed
demo/placeholder values per row (no computation, no new entity/table). This is a small, additive
change: one new `EntityMappings` entry + one new mapping case + two new response fields on the
backend, and a data-source swap (mock → existing generic reference use case) plus two static columns
on the frontend. No new endpoint, page, route, or menu entry is created.

## Technical Context

**Language/Version**: .NET 8 (backend, `ComplianceSys.Api`/`Application`/`Domain`/`Infrastructure`); React 18 + Vite (frontend, `compliance-client`) — existing stack, unchanged.

**Primary Dependencies**: ASP.NET Core Web API + Dapper (backend, existing); MUI (Material UI), React Router, existing DI container (`di/repositories.js`) (frontend, existing). No new dependency introduced.

**Storage**: N/A for this feature — Sales Order data is read live from D365 via the existing OData-backed reference lookup (`IDynamicService`/`DynamicsParameterManager`); Template/Progress are fixed demo constants with no persisted table.

**Testing**: Existing backend unit test project `ComplianceSysApi.UnitTests` (add/extend a test for the new `EntityMappings[11]` + mapping case if a suitable existing test class covers `ComplDynamicsService`); frontend has no dedicated automated test harness for this page — verify manually per `quickstart.md`, consistent with how prior EUTR features in this repo were validated.

**Target Platform**: Web (existing `compliance-client` SPA consumed via browser, calling existing `compliance-sys-api` Web API).

**Project Type**: Web application (monorepo: frontend + backend), per Constitution "Technology & Structure Constraints".

**Performance Goals**: Matches spec SC-001 — list loads within ~3s under normal network/load, consistent with other EUTR reference grids (e.g. List PO in `eutr-documents`, refType=15).

**Constraints**: MUST reuse the existing shared reference endpoint and `ComplDynReferenceResponseDto` shape (Principle III); MUST NOT create a new dedicated endpoint or duplicate `DynController`/`ComplDynamicsService` logic; the DTO extension MUST be additive (new nullable fields) so existing consumers of other `refType`s are unaffected.

**Scale/Scope**: One backend mapping entry + DTO extension; one existing frontend page updated to swap its data source for 4 of its 6 already-rendered columns. No new files needed on the frontend (only edits), one backend service/DTO file edited each.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Layered Clean Architecture** — PASS. Backend change stays in `ComplianceSys.Application`
  (`ComplDynamicsService` + its response DTO); `ComplianceSys.Api`'s `DynController` is unchanged
  (it already delegates to the service and takes `refType` as a plain parameter). Frontend change
  stays within `presentation/pages/eutr-sales-orders/SalesOrderOverviewPage.jsx`, consuming the
  existing `application/usecases/dynamics/GetReferenceDataUseCase` through the existing
  `domain/interfaces/IDynamicsRepository` → `infrastructure/repositories/RestDynamicsRepository`
  chain — no layer is bypassed.
- **II. Reference-Pattern Reuse** — PASS. The concrete reference for "register a new refType end to
  end" is how `EUTR_PURCH_ORDER` (`refType=15`) and `EUTR_SALES_ORDER_PURCHASE` (`refType=16`) were
  added for feature `004-eutr-documents` (see that spec's Update 4): an `EntityMappings` entry in
  `ComplDynamicsService`, a `case` in `MapDynamicsResponse`, and frontend consumption via
  `GetReferenceDataUseCase`/`useReferenceObjects` (see `EutrDocumentsAdd.jsx`'s
  `EUTR_PURCH_ORDER_REF_TYPE = 15` constant and its `fetchPoList` calls). This feature clones that
  exact pattern for `refType=11`.
- **III. Reuse Existing Backend** — PASS, with a verified, scoped gap. `POST /api/dynamics/reference`
  already exists and MUST be reused as-is (no new controller action). The only backend change is
  filling a verified gap: `refType=11` (`ObjectType.SALE_ORDER`, already defined in `ComplEnum.cs`
  and already treated as "Sales order" elsewhere, e.g. `compliance-view-so/index.jsx`'s
  `isSalesOrderRefType = refType === "11"`) has **no** `EntityMappings` entry today, so it currently
  returns an empty list. The underlying D365 entity (`RSVNSalesOrderOpenInvoiceCogs`, `ModelType =
  11`) already has every field needed (`SalesId`, `CustAccount`, `CustName`, `DeliveryDate`) — it is
  just registered under the unrelated raw key `0` in `EntityMappings`, not under `11`. No new D365
  entity class is created.
- **IV. Vietnamese Comments; Localizable UI Labels** — PASS. New/changed backend code comments are
  Vietnamese. The frontend page's existing column headers ("Sales ID", "Customer", "Customer Name",
  "Template", "Delivery Date", "Progress") were already shipped in English by a prior iteration of
  this scaffold; this feature does not introduce new English labels, it only rewires data — so it is
  not a new deviation requiring a spec-level justification. Search placeholder and empty-state text
  remain Vietnamese as already implemented.
- **V. Routing & Menu Registration** — PASS, already satisfied. Route (`/eutr/sales-orders` →
  `MainRoutes.jsx`'s implicit resolver path) and menu (`code: 'eutr-sales-orders'`, `url:
  '/eutr/sales-orders'`, title "Sales orders" in `ComplianceSystem.jsx`) and `RouteResolver.jsx`'s
  `codeToComponent['eutr-sales-orders'] = <SalesOrderOverviewPage />` all already exist. Per
  memory/prior findings, actual reachability additionally requires the backend-seeded `userMenu` +
  `canAccessMenu('eutr-sales-orders')` permission for the user's role — this is a DB/ops step
  outside this feature's code, consistent with every other EUTR screen; no action item here beyond
  noting the dependency.

No violations to record in Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/005-eutr-sales-orders/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
│   └── dynamics-reference-refType-11.md
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

**Structure Decision**: Existing monorepo, web application layout (backend + frontend), per
Constitution "Technology & Structure Constraints". No new top-level structure — only edits inside
the two existing projects.

```text
compliance-sys-api/
└── src/ComplianceSys.Application/
    ├── Services/ComplDynamicsService.cs        # EDIT: EntityMappings[11] + MapDynamicsResponse case 11
    └── Dtos/Response/ComplDynReferenceResponseDto.cs  # EDIT: add CustAccount, DeliveryDate (nullable)

compliance-client/
└── src/presentation/pages/eutr-sales-orders/
    └── SalesOrderOverviewPage.jsx               # EDIT: real data for 4 columns, fixed demo for 2
```

Unchanged (verified reusable as-is, no edits needed):
- `compliance-sys-api/src/ComplianceSys.Api/Controllers/DynController.cs` (generic `reference` action)
- `compliance-client/src/infrastructure/api/dynamicsApi.js`, `RestDynamicsRepository.js`
- `compliance-client/src/application/usecases/dynamics/index.js` (`GetReferenceDataUseCase`)
- `compliance-client/src/presentation/hooks/useReferenceObjects.js`
- `compliance-client/src/di/repositories.js` (`dynamics: new RestDynamicsRepository()`)
- `compliance-client/src/app/routes/groups/MainRoutes.jsx`, `RouteResolver.jsx`,
  `presentation/menu-items/ComplianceSystem.jsx` (route/menu already wired)
- `compliance-client/src/presentation/pages/eutr-sales-orders/MapFilePage.jsx`,
  `ViewSalesOrderPage.jsx`, and everything under `mock/` — out of scope for this feature; they still
  depend on the mock fixtures (`eutrSalesOrders.js`, `eutrTemplates.js`, `eutrTemplateDetails.js`,
  `eutrSteps.js`) for their own logic and MUST NOT be deleted or altered by this feature.

## Complexity Tracking

*No entries — Constitution Check passed without violations.*
