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
(currently returns an empty list for `refType=11`). The Progress column stays a fixed demo/placeholder
value per row (no computation, no new entity/table). This is a small, additive backend change: one
new `EntityMappings` entry + one new mapping case + two new response fields.

**Update 1 (2026-07-16)**: The **Template** column is no longer a fixed demo value (spec supersedes
the old FR-007). It now MUST show real data joined from the existing MySQL table
`eutr_purchase_attachments` (by `SalesId`) and `eutr_templates` (by `TemplateCode` → `Name`), including
the case where one Sales ID has multiple templates (multiple `PurchId` rows with different
`TemplateCode`s). `eutr_purchase_attachments` has **zero existing backend surface** today (verified:
no entity/repository/service/controller references it anywhere), so this update adds one small, new,
read-only backend feature (new `EutrPurchaseAttachmentsController`/`Service`/`Repository`/`Entity`,
cloned from the existing `EutrTemplates` stack — see research.md Decisions 5-8) plus one new
frontend read path (new repository/use case layer, cloned from the existing `eutr-templates` frontend
layering) that the grid calls once per page of visible Sales IDs. No new page, route, or menu entry
is created; the only presentation-layer edit is inside the already-existing
`SalesOrderOverviewPage.jsx`.

**Update 2 (2026-07-16)**: Wire `MapFilePage.jsx` (route `/eutr/sales-orders/:salesId/map-file`,
already registered — unchanged) off its current 100%-mock data to real sources for the existence
check/header, Step 1 (PO list + Save PO Mapping), and Step 2 (template tree + AVAILABLE FILES); Step
2's Upload/Save stay display-only per spec (no backend call for either). Investigation
(`research.md` Decisions 9-14) found almost everything already exists on the backend:
`refType=16` (`RSVNEutrSalesOrderPurchases`) is already fully registered in `ComplDynamicsService`,
including every field Step 1 needs, and is already filterable by `InterCompanyOriginalSalesId`
through the existing generic filter mechanism (zero backend change for Step 1's PO list);
`POST /api/eutr-documents/list-po-references` (feature `004-eutr-documents`) already returns exactly
the document↔PO↔step data Step 2's AVAILABLE FILES needs (zero backend change); `POST /api/eutr-
templates/get-all` + `GET /api/eutr-templates/{id}` (feature `003-eutr-templates`) already expose a
template's full step tree by `Code`/`Id` (zero backend change for Step 2's tree). The only new
backend work: `eutr_purchase_attachments` (read-only since Update 1) gets one new read action
(`GetBySalesIdAsync` — raw `PurchId`+`TemplateCode` rows for one Sales ID, backing both Step 1's
pre-checked state and Step 2's template list) and one new write action (`SavePoMappingAsync` —
transactional delete-then-reinsert for "Save PO Mapping"), both added to the already-existing
`EutrPurchaseAttachmentsController`. No new controller, no migration.

## Technical Context

**Language/Version**: .NET 8 (backend, `ComplianceSys.Api`/`Application`/`Domain`/`Infrastructure`); React 18 + Vite (frontend, `compliance-client`) — existing stack, unchanged.

**Primary Dependencies**: ASP.NET Core Web API + Dapper (backend, existing); MUI (Material UI), React Router, existing DI container (`di/repositories.js`) (frontend, existing). No new dependency introduced.

**Storage**: Sales ID/Customer/Customer name/Delivery date are read live from D365 via the existing OData-backed reference lookup (`IDynamicService`/`DynamicsParameterManager`) — unaffected by Update 1. Progress remains a fixed demo constant with no persisted table. **Update 1**: Template is now read from the existing MySQL tables `eutr_purchase_attachments` (join key) and `eutr_templates` (name lookup), via Dapper (`IUnitOfWork`) — the same local-DB access path already used by every other `Eutr*Repository` in this codebase; no migration needed, both tables already exist. **Update 2**: `eutr_purchase_attachments` gains a write path (delete-then-reinsert per Sales ID, same Dapper/`IUnitOfWork` access); Step 1's PO list is read live from D365 (`refType=16`, already-registered `RSVNEutrSalesOrderPurchases`); Step 2's tree/files are read from the already-existing `eutr_template_details`/`eutr_steps` (via `EutrTemplatesController`) and `eutr_references`/`eutr_documents` (via `EutrDocumentsController`'s `list-po-references`) — no new tables, no migration.

**Testing**: Existing backend unit test project `ComplianceSysApi.UnitTests` (add/extend a test for the new `EntityMappings[11]` + mapping case if a suitable existing test class covers `ComplDynamicsService`; **Update 1**: add a test class for `EutrPurchaseAttachmentsRepository`/`Service` if the project has an equivalent existing test for `EutrTemplatesRepository`/`Service` to model it on); frontend has no dedicated automated test harness for this page — verify manually per `quickstart.md`, consistent with how prior EUTR features in this repo were validated. **Update 2**: extend the same `EutrPurchaseAttachmentsRepository`/`Service` test class (if added) with cases for `GetBySalesIdAsync`/`SavePoMappingAsync`; `MapFilePage.jsx` remains manually verified per `quickstart.md` (no automated UI harness in this repo).

**Performance Goals**: Matches spec SC-001 — list loads within ~3s under normal network/load, consistent with other EUTR reference grids (e.g. List PO in `eutr-documents`, refType=15). **Update 1**: the new Template lookup is batched once per visible page of Sales IDs (research.md Decision 7), not per row, to stay within this same budget. **Update 2**: `MapFilePage.jsx` loads one Sales Order at a time (not a paged grid), so its handful of sequential calls (refType=11 → refType=16 → `GetBySalesIdAsync` → per-distinct-`TemplateCode` tree lookup → `list-po-references`) stay well within SC-005's per-screen load budget without needing batching across rows.

**Constraints**: MUST reuse the existing shared reference endpoint and `ComplDynReferenceResponseDto` shape (Principle III) for the 4 D365-sourced columns; MUST NOT create a new dedicated endpoint or duplicate `DynController`/`ComplDynamicsService` logic for those; the DTO extension MUST be additive (new nullable fields) so existing consumers of other `refType`s are unaffected. **Update 1**: the new `eutr_purchase_attachments` read path MUST follow the existing 4-layer `Eutr*` backend convention (Principle I/II) since no reusable backend exists for it yet (Principle III only mandates reuse of what already exists); the query MUST dedupe repeated templates per Sales ID and silently skip orphaned `TemplateCode`s (spec FR-007a/Edge Cases) rather than erroring. **Update 2**: MUST NOT add a new `BuildFilterString` special case for `InterCompanyOriginalSalesId` (the existing generic "other column" branch already handles it — Principle III); MUST NOT duplicate `list-po-references` or the `EutrTemplates` get-all/`GetById` endpoints; the new `save-po-mapping` write MUST run delete+reinsert inside one transaction (spec FR-021's "replace, don't diff" semantics) and MUST reject an item with an empty `TemplateCode` (spec FR-022, `NOT NULL` column).

**Scale/Scope**: One backend mapping entry + DTO extension for the 4 D365 columns; one existing frontend page updated to swap its data source for those columns and for Progress's already-decided fixed value. **Update 1** adds: 1 new backend entity + repository interface/impl + service interface/impl + controller (5 new backend files) for `eutr_purchase_attachments`; 1 new DTO file; 4 new frontend files (domain interface, api client, REST repository, use case) plus edits to `di/repositories.js` and `SalesOrderOverviewPage.jsx`. Still no new page, route, or menu entry. **Update 2** adds: 2 new controller actions + 2 new repository methods + 2 new service methods (all on already-existing `EutrPurchaseAttachmentsController`/`Service`/`IEutrPurchaseAttachmentsRepository`) + 3 new small DTOs (`PurchaseAttachmentDto`, `SavePoMappingRequestDto`, `PurchaseAttachmentItemDto`); frontend adds 2 new use cases (`GetPurchaseAttachmentsBySalesIdUseCase`, `SavePoMappingUseCase`) + 2 new methods each on the existing `eutrPurchaseAttachmentsApi.js`/`IEutrPurchaseAttachmentsRepository.js`/`RestEutrPurchaseAttachmentsRepository.js` (no new files there, just new methods) plus a substantial rewrite of `MapFilePage.jsx`'s data-loading logic (still no new page/route/menu entry). No new backend files (entity/repository/service/controller classes) are created — Update 2 only adds methods to files Update 1 already created.

**Target Platform**: Web (existing `compliance-client` SPA consumed via browser, calling existing `compliance-sys-api` Web API).

**Project Type**: Web application (monorepo: frontend + backend), per Constitution "Technology & Structure Constraints".

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Layered Clean Architecture** — PASS. Backend change stays in `ComplianceSys.Application`
  (`ComplDynamicsService` + its response DTO); `ComplianceSys.Api`'s `DynController` is unchanged
  (it already delegates to the service and takes `refType` as a plain parameter). Frontend change
  stays within `presentation/pages/eutr-sales-orders/SalesOrderOverviewPage.jsx`, consuming the
  existing `application/usecases/dynamics/GetReferenceDataUseCase` through the existing
  `domain/interfaces/IDynamicsRepository` → `infrastructure/repositories/RestDynamicsRepository`
  chain — no layer is bypassed. **Update 1**: the new `eutr_purchase_attachments` read path adds its
  own full stack on both sides — backend `Api → Application → Domain`/`Infrastructure`
  (`EutrPurchaseAttachmentsController` → `IEutrPurchaseAttachmentsService`/`EutrPurchaseAttachmentsService`
  → `IEutrPurchaseAttachmentsRepository`/`EutrPurchaseAttachmentsRepository`); frontend
  `domain/interfaces/IEutrPurchaseAttachmentsRepository.js` → `infrastructure/api/eutrPurchaseAttachmentsApi.js` +
  `infrastructure/repositories/RestEutrPurchaseAttachmentsRepository.js` → `application/usecases/
  eutr-purchase-attachments/GetTemplatesBySalesIdsUseCase.js` → `presentation/pages/eutr-sales-orders/
  SalesOrderOverviewPage.jsx`. No layer is skipped on either side.
- **II. Reference-Pattern Reuse** — PASS. The concrete reference for "register a new refType end to
  end" is how `EUTR_PURCH_ORDER` (`refType=15`) and `EUTR_SALES_ORDER_PURCHASE` (`refType=16`) were
  added for feature `004-eutr-documents` (see that spec's Update 4): an `EntityMappings` entry in
  `ComplDynamicsService`, a `case` in `MapDynamicsResponse`, and frontend consumption via
  `GetReferenceDataUseCase`/`useReferenceObjects` (see `EutrDocumentsAdd.jsx`'s
  `EUTR_PURCH_ORDER_REF_TYPE = 15` constant and its `fetchPoList` calls). This feature clones that
  exact pattern for `refType=11`. **Update 1**: the new `eutr_purchase_attachments` backend stack
  clones `EutrTemplates` end to end (closest same-shape existing table-backed feature — entity,
  repository, service, controller, all under the `Eutr*` naming/layering convention), and the new
  frontend files clone the `eutr-templates` feature's frontend layering (`domain/entities`,
  `domain/interfaces`, `infrastructure/api`, `infrastructure/repositories`,
  `application/usecases/eutr-templates/Get*UseCase.js`) — see research.md Decisions 5 and 7.
  **Update 2**: the two new `EutrPurchaseAttachmentsController` actions clone
  `EutrDocumentsService.DeleteAsync`'s Update 9 transaction shape (delete-then-reinsert under one
  `IUnitOfWork`) and `EutrUploadService`'s Update 7 per-row `AddAsync`-with-manual-audit-fields loop;
  everything else in Update 2 (refType=16 filter, `list-po-references`, `EutrTemplates` get-all/
  GetById) is pure reuse of already-working endpoints, not a clone of a pattern — see research.md
  Decisions 9-14.
- **III. Reuse Existing Backend** — PASS, with a verified, scoped gap. `POST /api/dynamics/reference`
  already exists and MUST be reused as-is (no new controller action). The only backend change for
  the 4 D365 columns is filling a verified gap: `refType=11` (`ObjectType.SALE_ORDER`, already
  defined in `ComplEnum.cs` and already treated as "Sales order" elsewhere, e.g.
  `compliance-view-so/index.jsx`'s `isSalesOrderRefType = refType === "11"`) has **no**
  `EntityMappings` entry today, so it currently returns an empty list. The underlying D365 entity
  (`RSVNSalesOrderOpenInvoiceCogs`, `ModelType = 11`) already has every field needed (`SalesId`,
  `CustAccount`, `CustName`, `DeliveryDate`) — it is just registered under the unrelated raw key `0`
  in `EntityMappings`, not under `11`. No new D365 entity class is created. **Update 1**: verified by
  full-repo search that `eutr_purchase_attachments` has **zero** existing backend code referencing it
  — there is nothing to reuse for the Template column, so Principle III does not apply to block a new
  read path here; it only requires that no *already-existing* backend for this table be duplicated
  (none exists) and that the D365 reference endpoint stay untouched by this addition (confirmed — the
  new controller/service/repository are entirely separate files).
  **Update 2**: verified `refType=16`'s `EntityMappings` entry, `InterCompanyOriginalSalesId` filter
  support, `POST /api/eutr-documents/list-po-references`, and `EutrTemplatesController`'s
  `get-all`/`GetById` actions **all already exist and already return every field needed** (research.md
  Decisions 10/13/14) — Principle III requires reusing them as-is, which is exactly what
  `MapFilePage.jsx`'s rewrite does; zero new backend code for any of the three. The only verified gap
  is `eutr_purchase_attachments`'s write side (never existed, Update 1 only added a read) — Principle
  III doesn't block filling a genuine gap, and the two new actions are added to the controller Update 1
  already created (no new controller/service/repository/entity class, just new methods on them).
- **IV. Vietnamese Comments; Localizable UI Labels** — PASS. New/changed backend code comments are
  Vietnamese. The frontend page's existing column headers ("Sales ID", "Customer", "Customer Name",
  "Template", "Delivery Date", "Progress") were already shipped in English by a prior iteration of
  this scaffold; this feature does not introduce new English labels, it only rewires data — so it is
  not a new deviation requiring a spec-level justification. Search placeholder and empty-state text
  remain Vietnamese as already implemented. **Update 1**: all new backend files
  (`EutrPurchaseAttachmentsController`/`Service`/`Repository`/`Entity`) MUST carry Vietnamese
  comments, matching the unaccented-ASCII Vietnamese comment style already used in
  `EutrTemplatesRepository.cs`/`IEutrTemplatesRepository.cs`; the Template cell's rendered content is
  data (template names), not a new UI label, so no localization decision is introduced.
  **Update 2**: the two new methods/actions on `EutrPurchaseAttachmentsController`/`Service`/
  `Repository` MUST carry Vietnamese comments matching that same file's existing style (Update 1); no
  new UI label is introduced in `MapFilePage.jsx` — its existing Vietnamese/English labels (Step 1/2
  headers, buttons) are unchanged, only the data feeding them changes. `TAKE_FROM_LABELS`/
  `REQUIREMENT_LABELS` (`utils/helpers.js`, already English: "PO"/"Upload manual"/"Optional"/
  "Required") are already the codebase's own precedent for these two enums (used by
  `003-eutr-templates`'s own screens) — reused as-is, not a new localization decision for this feature.
- **V. Routing & Menu Registration** — PASS, already satisfied. Route (`/eutr/sales-orders` →
  `MainRoutes.jsx`'s implicit resolver path) and menu (`code: 'eutr-sales-orders'`, `url:
  '/eutr/sales-orders'`, title "Sales orders" in `ComplianceSystem.jsx`) and `RouteResolver.jsx`'s
  `codeToComponent['eutr-sales-orders'] = <SalesOrderOverviewPage />` all already exist. Per
  memory/prior findings, actual reachability additionally requires the backend-seeded `userMenu` +
  `canAccessMenu('eutr-sales-orders')` permission for the user's role — this is a DB/ops step
  outside this feature's code, consistent with every other EUTR screen; no action item here beyond
  noting the dependency. **Update 1**: the new endpoint's authorization policy
  (`EutrPurchaseAttachments.Read`, research.md Decision 8) is a second, analogous DB-seeding
  dependency — no new route/page/menu entry, just one more permission code an operator must seed
  before the Template column can return data for a given role (same category of ops dependency
  already noted above for `eutr-sales-orders` itself).
  **Update 2**: the new `EutrPurchaseAttachments.Update` policy (research.md Decision 15) is a third
  such DB-seeded dependency, additive to `EutrPurchaseAttachments.Read` (Update 1) — no new route,
  page, or menu entry; `MapFilePage.jsx`'s route (`/eutr/sales-orders/:salesId/map-file`) already
  exists and is unaffected.

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
│   ├── dynamics-reference-refType-11.md
│   ├── eutr-purchase-attachments.md   # NEW (Update 1)
│   ├── eutr-purchase-attachments-map-file.md   # NEW (Update 2)
│   └── map-file-reused-endpoints.md            # NEW (Update 2) - traceability only, no new contract
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

**Structure Decision**: Existing monorepo, web application layout (backend + frontend), per
Constitution "Technology & Structure Constraints". No new top-level structure — only edits inside
the two existing projects.

```text
compliance-sys-api/
└── src/
    ├── ComplianceSys.Application/
    │   ├── Services/ComplDynamicsService.cs        # EDIT: EntityMappings[11] + MapDynamicsResponse case 11
    │   ├── Dtos/Response/ComplDynReferenceResponseDto.cs  # EDIT: add CustAccount, DeliveryDate (nullable)
    │   ├── Dtos/Response/SalesOrderTemplateDto.cs         # NEW (Update 1)
    │   ├── Interfaces/Repositories/IEutrPurchaseAttachmentsRepository.cs  # NEW (Update 1)
    │   │                                            # EDIT (Update 2): + GetBySalesIdAsync, DeleteBySalesIdAsync
    │   ├── Interfaces/Services/IEutrPurchaseAttachmentsService.cs         # NEW (Update 1)
    │   │                                            # EDIT (Update 2): + SavePoMappingAsync (calls the new
    │   │                                            #       repository methods + IRepository<EutrPurchaseAttachments,int>)
    │   ├── Services/EutrPurchaseAttachmentsService.cs                    # NEW (Update 1)
    │   │                                            # EDIT (Update 2): implement SavePoMappingAsync (Decision 11)
    │   ├── Dtos/Response/PurchaseAttachmentDto.cs           # NEW (Update 2) - {SalesId,PurchId,TemplateCode}
    │   ├── Dtos/Request/SavePoMappingRequestDto.cs          # NEW (Update 2) - {SalesId, Items[]}
    │   ├── Dtos/Request/PurchaseAttachmentItemDto.cs        # NEW (Update 2) - {PurchId,TemplateCode}
    │   └── DependencyInjection.cs                  # EDIT (Update 1): register the two new interfaces
    ├── ComplianceSys.Domain/
    │   └── Entities/EutrPurchaseAttachments.cs     # NEW (Update 1) - unchanged in Update 2
    ├── ComplianceSys.Infrastructure/
    │   ├── Repositories/EutrPurchaseAttachmentsRepository.cs  # NEW (Update 1)
    │   │                                            # EDIT (Update 2): + GetBySalesIdAsync, DeleteBySalesIdAsync
    │   └── DependencyInjection.cs                  # EDIT (Update 1): register the new repository
    └── ComplianceSys.Api/
        └── Controllers/EutrPurchaseAttachmentsController.cs  # NEW (Update 1)
                                                      # EDIT (Update 2): + GET by-sales-id/{salesId},
                                                      #       + POST save-po-mapping (policy
                                                      #       EutrPurchaseAttachments.Update, NEW policy code)

compliance-client/
└── src/
    ├── domain/interfaces/IEutrPurchaseAttachmentsRepository.js       # NEW (Update 1)
    │                                                # EDIT (Update 2): + getBySalesId, savePoMapping
    ├── infrastructure/api/eutrPurchaseAttachmentsApi.js              # NEW (Update 1)
    │                                                # EDIT (Update 2): + getBySalesId, savePoMapping
    ├── infrastructure/repositories/RestEutrPurchaseAttachmentsRepository.js  # NEW (Update 1)
    │                                                # EDIT (Update 2): implement the 2 new methods
    ├── application/usecases/eutr-purchase-attachments/
    │   ├── GetTemplatesBySalesIdsUseCase.js        # NEW (Update 1) - unchanged in Update 2
    │   ├── GetPurchaseAttachmentsBySalesIdUseCase.js  # NEW (Update 2)
    │   └── SavePoMappingUseCase.js                    # NEW (Update 2)
    ├── di/repositories.js                           # EDIT (Update 1): register eutrPurchaseAttachments
    └── presentation/pages/eutr-sales-orders/
        ├── SalesOrderOverviewPage.jsx               # EDIT: real data for 4 D365 columns, fixed demo
        │                                             #       for Progress; EDIT (Update 1): real,
        │                                             #       possibly multi-value Template column
        └── MapFilePage.jsx                          # EDIT (Update 2): real data for `if (!so)`/header
                                                       #       (refType=11), Step 1 PO list (refType=16)
                                                       #       + Save PO Mapping (new write endpoint),
                                                       #       Step 2 tree (EutrTemplates get-all/GetById)
                                                       #       + AVAILABLE FILES (list-po-references);
                                                       #       Upload/Save on Step 2 stay no-op (unchanged)
```

Unchanged (verified reusable as-is, no edits needed):
- `compliance-sys-api/src/ComplianceSys.Api/Controllers/DynController.cs` (generic `reference` action)
- `compliance-client/src/infrastructure/api/dynamicsApi.js`, `RestDynamicsRepository.js`
- `compliance-client/src/application/usecases/dynamics/index.js` (`GetReferenceDataUseCase`)
- `compliance-client/src/presentation/hooks/useReferenceObjects.js`
- `compliance-client/src/di/repositories.js`'s existing `dynamics: new RestDynamicsRepository()` entry
  (Update 1 only adds a new sibling entry, doesn't touch this one)
- `compliance-client/src/app/routes/groups/MainRoutes.jsx`, `RouteResolver.jsx`,
  `presentation/menu-items/ComplianceSystem.jsx` (route/menu already wired; `MapFilePage.jsx`'s own
  route was already registered before this feature and needs no change in Update 2 either)
- `compliance-client/src/presentation/pages/eutr-sales-orders/ViewSalesOrderPage.jsx` and everything
  under `mock/` — still out of scope for this feature (not named in either the original or Update 2
  feature description); `ViewSalesOrderPage.jsx` keeps depending on the mock fixtures
  (`eutrSalesOrders.js`, `eutrTemplates.js`, `eutrTemplateDetails.js`, `eutrSteps.js`) for its own
  logic and these files MUST NOT be deleted (still imported elsewhere), even though `MapFilePage.jsx`
  itself stops importing them as of Update 2.
- `eutr_templates`/`EutrTemplatesController` and its full stack — Update 1 only *reads* `eutr_templates`
  (join for `TemplateName`) via the new `EutrPurchaseAttachmentsRepository`; **Update 2** additionally
  *reads* `EutrTemplatesController`'s existing `get-all`/`GetById` actions from `MapFilePage.jsx` — no
  existing `EutrTemplates*` file (controller, service, repository, DTOs) is modified by either update.
- `EutrDocumentsController`'s `list-po-references` action, `EutrDocumentsService.GetPoReferencesAsync`,
  `EutrReferencesRepository.GetDocumentsByPoCodesAsync`, and the frontend
  `GetEutrDocumentsPoReferencesUseCase`/`RestEutrDocumentsRepository.getPoReferences` chain (all from
  feature `004-eutr-documents`) — **Update 2** calls this existing, already-frontend-wired chain
  as-is from `MapFilePage.jsx` for AVAILABLE FILES; none of these files are modified.
- `ComplDynamicsService.cs`'s `EntityMappings[16]`/`case 16` and `RSVNEutrSalesOrderPurchases.cs` —
  **Update 2** is the first caller to filter `refType=16` by `InterCompanyOriginalSalesId`, but no
  code change is needed there (research.md Decision 10); file listed here only for traceability.

## Complexity Tracking

*No entries — Constitution Check passed without violations.*
