# Implementation Plan: EUTR Synchronize Data (Sales Order Template Sync + Purchase-Order Missing-Documentation Alert + Outbound Template Sync)

**Branch**: `011-eutr-synchronize-data` | **Date**: 2026-08-11 (updated 2026-08-13, 2026-08-14, 2026-08-17) | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/011-eutr-synchronize-data/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Three independent, manually-triggered actions on the same `EutrSynchronizeDataController` (modeled on
`ComplNotificationController`):

1. **User Story 1 — Sales Order Template Sync** (`[HttpGet("test-so-template-sync")]`): pulls the
   full D365 "Sales Order Templates" reference dataset (reference type 19) via the existing
   `IComplDynamicsService.GetDynRefePagedAsync` pipeline and creates a corresponding
   `eutr_purchase_attachments` row (`SalesId`/`PurchId`/`TemplateCode`) for every sales order that
   doesn't already have one, skipping any that do. Research (research.md R2) found that reference
   type 19 currently returns an empty result due to a missing `EntityMappings` entry in
   `ComplDynamicsService` (the same class of gap already fixed once for type 18 in feature 009) —
   fixing that is a required, in-scope prerequisite for this action to do anything at all.

2. **User Story 2 — Purchase-Order Missing-Documentation Alert** (new,
   `[HttpGet("test-purchase-missing")]`): pulls the full D365 "Purchase Orders" reference dataset
   (reference type 15) plus a one-time D365 "Vendors" lookup (reference type 14) via the same
   `GetDynRefePagedAsync` pipeline, flags every purchase order missing its template, its SharePoint
   document folder (`ISharepointService.GetFolders`, base path `SharePointEutrPath`), or one or more
   of its template's document steps (checked via `IEutrTemplatesRepository.GetManyByCodesWithDetailsAsync`
   for template/step data and `IEutrReferencesRepository.GetDocumentsByPoCodesAsync` for recorded
   documents), and emails each flagged purchase order's responsible Alert group
   (`IGroupDetailRepository.GetEmailsByGroupIdsAsync`) a per-group Excel report (`ClosedXML`, same
   technique as `ComplNotificationService.BuildSalesOrderMissingExcelAttachment`). Research
   (research.md R9) found that reference type 15's existing D365→DTO mapping doesn't yet surface the
   vendor account field (`OrderAccount`) needed for the report's "Vendor code" column — adding that
   one field to the existing `case 15` mapping is the only other in-scope backend gap this story
   fixes, alongside User Story 1's `case 19`/`EntityMappings` fix.

   **Update 2026-08-14 (persistence redesign)**: flagged findings are no longer kept in memory only.
   A new table, `eutr_purchase_missing` (columns `PurchId`/`VendorCode`/`VendorName`/`TemplateId`/
   `Note`/`AlertForGroupId`, already created via migration
   `Sqls/Migration/19_create_eutr_purchase_missing.sql` + `Sqls/Tables/eutr_purchase_missing.sql`),
   is fully cleared at the start of every run, then repopulated with exactly the flagged findings from
   that run; the per-group emails/Excel attachments are then built by reading the table back, not
   from the in-memory list computed during evaluation. This mirrors the existing
   `compl-sales-order-missing` feature's (009) `compl_so_missing` clear-then-repopulate-then-read-back
   pattern exactly (research.md R17) — same dedicated-repository shape
   (`DeleteAllAsync`/`InsertManyAsync`/`GetAllAsync`, not the generic `IRepository<,>`), same call
   order (delete once → insert as findings are computed → read back once after the loop finishes).

3. **User Story 3 — Outbound Template Sync** (new, added 2026-08-17, corrected 2026-08-17,
   `[HttpGet("test-synchronize-templates")]`): the reverse direction of User Story 1/2 — pushes local
   `eutr_templates` data **out to** D365 instead of reading D365 in. Reads every local template with
   `IsDeleted=0`/`IsHide=0`/`Status=1` (new repository method,
   `IEutrTemplatesRepository.GetEligibleForDynamicsSyncAsync`, research.md R18); Phase 1 sends one
   `POST .../RSVNEutrTemplates/Microsoft.Dynamics.DataEntities.deleteTemplate?cross-company=true` per
   eligible template (`{code}` body) before Phase 2 begins for any of them (research.md R21); Phase 2
   looks up each eligible template's currently active `eutr_template_references` mapping(s) (new
   repository method, `IEutrTemplateReferencesRepository.GetActiveByTemplateIdsAsync`, research.md
   R19) and, per template, **left-joins** that result in application code (research.md R24): sends one
   `POST .../RSVNEutrTemplates?cross-company=true` per active mapping (`{Code, Name, VendorCode}`
   body) when the template has one or more, or exactly one such POST with `VendorCode = ""` when it
   has none — every eligible template receives at least one Phase 2 push, never zero (corrected
   2026-08-17 from an earlier inner-join version that pushed nothing for a template with no active
   mapping). Both POST calls go through the existing `IDynamicService.PostAsync<T>` (the same
   underlying HTTP client `ComplDynamicsService` already uses for its read-only GET calls, confirmed
   to send `application/json`, not `multipart/form-data` — research.md R20) — this is the first
   *outbound* write to D365 in the codebase. A D365 call failure in either phase stops the whole run,
   matching User Story 1/2's existing failure-handling shape (research.md R21, spec Assumptions).

## Technical Context

**Language/Version**: C# / .NET 8 (existing `compliance-sys-api` solution)

**Primary Dependencies**: ASP.NET Core Web API, Dapper (via `Res.Shared.Dapper` NuGet package),
existing `IComplDynamicsService` (D365 OData reference proxy), existing
`IEutrPurchaseAttachmentsRepository` / generic `IRepository<EutrPurchaseAttachments,int>` (User
Story 1); existing `ISharepointService` (`Shared.ExternalServices.Interfaces`), existing
`IEutrTemplatesRepository.GetManyByCodesWithDetailsAsync`, existing
`IEutrReferencesRepository.GetDocumentsByPoCodesAsync`, existing
`IGroupDetailRepository.GetEmailsByGroupIdsAsync`, existing `MailAlert`/`AttachmentInfo` mail
helpers, `ClosedXML` (already a transitive dependency via `ComplNotificationService`'s Excel
attachment), and a **new** dedicated repository, `IEutrPurchaseMissingRepository`
(`DeleteAllAsync`/`InsertManyAsync`/`GetAllAsync`, modeled directly on the existing
`IComplSoMissingRepository`/`ComplSoMissingRepository` shape — research.md R17) for User Story 2;
existing `Shared.ExternalServices.Interfaces.IDynamicService.PostAsync<T>` (the same package's HTTP
client `IComplDynamicsService` already depends on for reads, now called directly for writes) and the
existing-but-previously-unused `ComplianceSys.Domain/Dynamics/RSVNEutrTemplates.cs` domain model,
plus two **new** repository methods on existing interfaces —
`IEutrTemplatesRepository.GetEligibleForDynamicsSyncAsync` and
`IEutrTemplateReferencesRepository.GetActiveByTemplateIdsAsync` (research.md R18/R19/R20) — for User
Story 3

**Storage**: MySQL — existing `eutr_purchase_attachments` table (no schema change, User Story 1);
User Story 2 reads existing tables read-only (`eutr_templates`, `eutr_template_details`,
`eutr_steps`, `eutr_references`, `eutr_documents`, `compl_group_email`/`compl_group_email_detail`),
and now writes to one **new** table, `eutr_purchase_missing` (`Id`/`PurchId`/`VendorCode`/
`VendorName`/`TemplateId`/`Note`/`AlertForGroupId` — already created via migration
`Sqls/Migration/19_create_eutr_purchase_missing.sql`, matching
`Sqls/Tables/eutr_purchase_missing.sql`), fully cleared and repopulated on every run (spec FR-020/
FR-021, Assumptions). D365 (Dynamics 365) as the read-only source for User Story 1/2: reference
entities `RSVNEutrSalesOrderTemplates` (refType 19, User Story 1), `RSVNEutrPurchOrders` (refType 15)
and `VendorsV3` (refType 14, User Story 2) — all already modeled. User Story 3 (added 2026-08-17)
reads existing local tables read-only (`eutr_templates`, `eutr_template_references` — no schema
change, no new local table) and **writes to D365** (`RSVNEutrTemplates` entity, via its
`deleteTemplate` bound action and a plain POST) — the only write target for this story is external;
no local table is ever written to by this story.

**Testing**: xUnit (`ComplianceSysApi.UnitTests`), matching the existing test project's conventions

**Target Platform**: Existing ASP.NET Core Web API backend (`compliance-sys-api`), server-side only
— no frontend/UI change

**Project Type**: Web service (backend-only feature; no `compliance-client` changes)

**Performance Goals**: No new explicit target; reuses the existing 1000-row page size convention
from `ComplNotificationService.RefreshSalesOrderMissingComplianceAsync` for every D365 paging loop
(refType 19 for User Story 1; refType 15 and refType 14 for User Story 2), so a full run of either
action stays proportional to existing similar batch jobs. User Story 2 additionally loads the
SharePoint folder list (`GetFolders`), the batch of matching templates
(`GetManyByCodesWithDetailsAsync`), and the batch of recorded documents
(`GetDocumentsByPoCodesAsync`) **once each per run**, not once per purchase order, to keep a
>3,000-row run from becoming thousands of round-trips (research.md R9–R12). User Story 3 fetches
active Vendor mappings for every eligible template in **one** batched query
(`GetActiveByTemplateIdsAsync`, research.md R19) rather than one query per template, but still sends
one D365 HTTP call per eligible template (Phase 1) plus one per active mapping (Phase 2) — no
batching is possible there since D365 exposes no bulk delete/create for this entity; expected volume
(Approved templates × active vendor mappings) is orders of magnitude smaller than User Story 2's
>3,000-row purchase-order population, so this is not expected to be a bottleneck.

**Constraints**: Must not alter behavior for any other `refType` value in `ComplDynamicsService`
(the `EntityMappings`/`MapDynamicsResponse` changes are additive, scoped to `19` (User Story 1,
research.md R2/R3) and to enriching `case 15` with one extra field, `OrderAccount` (User Story 2,
research.md R9) — no existing `refType` behavior changes). Must not wrap User Story 1's whole run in
a single DB transaction (spec allows partial progress on mid-run failure — research.md R7). User
Story 2 must not create SharePoint folders (unlike `EutrUploadService`'s create-if-missing
behavior) — it only reads the existing folder list (research.md R12). User Story 2's store writes
(`DeleteAllAsync`/`InsertManyAsync`) MUST run outside any single wrapping transaction, mirroring
`ComplSoMissingRepository`'s own unwrapped calls — a delete-then-insert failure partway through still
leaves the store in a "this run's partial progress" state rather than rolling back to the previous
run's stale data (research.md R17). User Story 3 MUST NOT begin Phase 2 (push) for any template until
Phase 1 (delete) has completed for every eligible template (spec FR-025, research.md R21) — the two
phases are not interleaved per template. User Story 3 MUST stop the entire run on the first D365 call
failure in either phase (no per-item continue-on-error), consistent with User Story 1/2's own
established failure handling (research.md R21, spec Assumptions) — this is a deliberate consistency
choice, not a technical limitation of `IDynamicService`.

**Scale/Scope**: One controller (`EutrSynchronizeDataController`, 3 actions total — 2 existing + 1
new), one Application service interface/implementation extended with a third method, three response
DTOs (two existing, one new for User Story 3), two small additive fixes to one existing service file
(`ComplDynamicsService` — `EntityMappings[19]`/`case 19` for User Story 1, `case 15` for User Story
2), one new small Excel-builder helper (private, in the same service, mirroring
`ComplNotificationService.BuildSalesOrderMissingExcelAttachment`'s technique). **One new table**
(`eutr_purchase_missing`, already created), **one new domain entity** (`EutrPurchaseMissing`), **one
new repository interface + implementation** (`IEutrPurchaseMissingRepository`/
`EutrPurchaseMissingRepository`, modeled on `IComplSoMissingRepository`), one new DI registration.
**User Story 3** adds: two new methods on existing repository interfaces/implementations
(`IEutrTemplatesRepository.GetEligibleForDynamicsSyncAsync`,
`IEutrTemplateReferencesRepository.GetActiveByTemplateIdsAsync`), one new response DTO
(`EutrSynchronizeTemplatesSummaryDto`), one new service method
(`SyncTemplatesToDynamicsAsync`) plus one new constructor dependency
(`IDynamicService`) on the existing `EutrSynchronizeDataService`, one new controller action. No new
table, no new domain entity, no new repository interface, no new DI registration (both touched
repository interfaces are already registered). No frontend work for any of the three stories.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Layered Clean Architecture** — PASS. All three actions stay in `ComplianceSys.Api/Controllers`
  (`EutrSynchronizeDataController`) and delegate immediately to `Application` service methods
  (`EutrSynchronizeDataService`); no business logic in the controller. The service depends only on
  existing/new `Application`/`Domain` abstractions (`IComplDynamicsService`,
  `IEutrPurchaseAttachmentsRepository`, `IRepository<EutrPurchaseAttachments,int>`,
  `IEutrTemplatesRepository`, `IEutrReferencesRepository`, `IGroupDetailRepository`,
  `IEutrPurchaseMissingRepository` (new), `ISharepointService`, `IConfiguration`; `IUnitOfWork` not
  required for either action — User Story 1 per R7, User Story 2's new repository calls are
  unwrapped too, mirroring `ComplSoMissingRepository`, research.md R17). The new
  `EutrPurchaseMissingRepository` (`ComplianceSys.Infrastructure`) implements the new
  `IEutrPurchaseMissingRepository` (`ComplianceSys.Application`), respecting the same
  `Api → Application → Domain`, `Infrastructure` implements `Application` layering as every other
  repository in this solution. User Story 3 adds `IDynamicService` (an existing
  `Shared.ExternalServices` abstraction, same layer `IComplDynamicsService` already depends on) as a
  new constructor dependency of the same `Application`-layer service — no new layer, no controller
  logic, and its two new repository methods live on the existing `Application`-layer interfaces,
  implemented in the existing `Infrastructure`-layer classes, exactly like every other method already
  there. No frontend layer is touched by any of the three stories (backend-only feature).
- **II. Reference-Pattern Reuse** — PASS. Controller attribute shape and action style explicitly
  clone `ComplNotificationController` (per the feature request) — User Story 3's action follows the
  identical shape as the controller's other two. The D365-paging loop (both refType
  19 for User Story 1 and refType 15/14 for User Story 2) clones
  `ComplNotificationService.RefreshSalesOrderMissingComplianceAsync`'s exact shape (research.md R4).
  User Story 1's write path clones `EutrPurchaseAttachmentsService.SavePoMappingAsync`'s use of the
  generic `IRepository<EutrPurchaseAttachments,int>.AddAsync` (research.md R6). User Story 2's
  SharePoint folder check clones `EutrUploadService.ResolveOrCreatePoFolderAsync`'s
  `GetFolders`+`Any(name match)` technique, minus the create step (research.md R12); its Excel
  attachment clones `ComplNotificationService.BuildSalesOrderMissingExcelAttachment`'s
  reflection-over-a-header-dictionary technique (research.md R14); its per-group alert-group email
  lookup reuses `IGroupDetailRepository.GetEmailsByGroupIdsAsync`, the same method
  `ComplNotificationService` already calls for other alerts' group resolution (research.md R13). Its
  **new** persisted store (`eutr_purchase_missing`) directly clones `compl_so_missing`'s entity/
  repository/orchestration shape end to end — same `DeleteAllAsync`→loop-`InsertManyAsync`→
  `GetAllAsync` call order as `ComplNotificationService.RefreshSalesOrderMissingComplianceAsync` +
  `SendSalesOrderAlertAsync` (research.md R17), the closest possible reference for "clear a store,
  repopulate it per source item, then read it back to build an alert."
- **III. Reuse Existing Backend** — PASS with two scoped, verified-gap exceptions, both additive
  edits to the same already-modified file (`ComplDynamicsService.cs`): (1) User Story 1's `refType =
  19` `EntityMappings` entry + `case 19` DTO enrichment (research.md R2/R3) — the same "fix a missing
  reference-type mapping" gap already fixed once before for `refType = 18` (feature 009); without it
  `refType = 19` always returns empty. (2) User Story 2's `case 15` enrichment to also populate the
  DTO's existing (already-declared, currently-unused-by-case-15) `OrderAccount` field (research.md
  R9) — `refType = 15` already works today (feature 004 registered it), this only adds one more field
  to its existing mapping so the Vendor code column has a source; no other `refType`'s behavior
  changes. Every other piece User Story 2 needs — `IEutrTemplatesRepository.GetManyByCodesWithDetailsAsync`,
  `IEutrReferencesRepository.GetDocumentsByPoCodesAsync`, `IGroupDetailRepository.GetEmailsByGroupIdsAsync`,
  `ISharepointService.GetFolders`, `MailAlert`/`AttachmentInfo` — is reused exactly as it exists
  today. The one genuinely new piece of backend (the `eutr_purchase_missing` table/entity/repository)
  is a verified, explicitly-requested gap — no existing table serves this feature's own per-run
  missing-documentation snapshot — and it is itself built by cloning `compl_so_missing`'s shape
  rather than inventing a new one. User Story 3 reuses `IDynamicService.PostAsync<T>` (existing,
  `Shared.ExternalServices`) and the existing-but-previously-dormant `RSVNEutrTemplates` domain model
  as-is (research.md R20) — its two new repository methods
  (`GetEligibleForDynamicsSyncAsync`/`GetActiveByTemplateIdsAsync`) are additive methods on already-
  registered repository interfaces, not new repositories, since no existing method covers this
  filter/join shape (research.md R18/R19) — a verified gap, not a reimplementation of anything that
  already exists.
- **IV. Vietnamese Comments; Localizable UI Labels** — PASS. Backend-only feature; no UI labels.
  New code comments (in the service, and around both `ComplDynamicsService` fixes, and around User
  Story 3's new repository methods/service method) will be written in Vietnamese per existing file
  conventions (see the Vietnamese comments already in `ComplDynamicsService.cs`,
  `EutrPurchaseAttachmentsService.cs`, `EutrUploadService.cs`).
- **V. Routing & Menu Registration** — N/A. No new frontend screen/route; all three actions are
  backend-only, manually-triggered test endpoints with no UI entry point (consistent with
  `ComplNotificationController`'s own `test-alert`/`test-sales-order-alert` actions, which also have
  no menu entry).

No violations requiring the Complexity Tracking table.

## Project Structure

### Documentation (this feature)

```text
specs/011-eutr-synchronize-data/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
│   ├── eutr-synchronize-data-test-so-template-sync.md
│   ├── eutr-synchronize-data-test-purchase-missing.md     # NEW (User Story 2)
│   └── eutr-synchronize-data-test-synchronize-templates.md # NEW (User Story 3, 2026-08-17)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
compliance-sys-api/
├── src/
│   ├── ComplianceSys.Api/
│   │   └── Controllers/
│   │       └── EutrSynchronizeDataController.cs          # EDIT — add [HttpGet("test-synchronize-templates")] action (User Story 3)
│   ├── ComplianceSys.Application/
│   │   ├── Interfaces/Repositories/
│   │   │   ├── IEutrPurchaseMissingRepository.cs          # NEW — DeleteAllAsync/InsertManyAsync/GetAllAsync (mirrors IComplSoMissingRepository)
│   │   │   ├── IEutrTemplatesRepository.cs                 # EDIT — add GetEligibleForDynamicsSyncAsync(ct) (User Story 3, research.md R18)
│   │   │   └── IEutrTemplateReferencesRepository.cs         # EDIT — add GetActiveByTemplateIdsAsync(templateIds, asOfDate, ct) (User Story 3, research.md R19)
│   │   ├── Interfaces/Services/
│   │   │   └── IEutrSynchronizeDataService.cs             # EDIT — add SyncTemplatesToDynamicsAsync(ct) (User Story 3)
│   │   ├── Services/
│   │   │   ├── EutrSynchronizeDataService.cs              # EDIT — SendPurchaseMissingAlertAsync now calls DeleteAllAsync → InsertManyAsync (per flagged PO) → GetAllAsync before building per-group emails (research.md R17); constructor gains IEutrPurchaseMissingRepository. User Story 3: constructor gains IDynamicService; new SyncTemplatesToDynamicsAsync method (Phase 1 delete loop, then Phase 2 push loop — research.md R18-R23)
│   │   │   └── ComplDynamicsService.cs                    # unchanged in this update (case 15/19 fixes already landed 2026-08-13)
│   │   ├── Dtos/Response/
│   │   │   ├── EutrPurchaseMissingSummaryDto.cs           # unchanged (TotalFetched/FlaggedCount/GroupsNotified/Success/Message)
│   │   │   └── EutrSynchronizeTemplatesSummaryDto.cs       # NEW — TemplatesEligible/DeleteCallsSent/PushCallsSent/Success/Message (User Story 3)
│   │   └── DependencyInjection.cs                         # unchanged — IEutrSynchronizeDataService already registered
│   ├── ComplianceSys.Domain/
│   │   └── Entities/
│   │       └── EutrPurchaseMissing.cs                     # NEW — PurchId/VendorCode/VendorName/TemplateId/Note/AlertForGroupId (mirrors EutrPurchaseAttachments' plain-entity shape, no BaseEntity audit columns — table has none)
│   └── ComplianceSys.Infrastructure/
│       ├── Repositories/
│       │   ├── EutrPurchaseMissingRepository.cs           # NEW — Dapper impl, mirrors ComplSoMissingRepository.cs exactly (DELETE FROM / per-row INSERT / SELECT *)
│       │   ├── EutrTemplatesRepository.cs                  # EDIT — implement GetEligibleForDynamicsSyncAsync (User Story 3, research.md R18)
│       │   └── EutrTemplateReferencesRepository.cs          # EDIT — implement GetActiveByTemplateIdsAsync (User Story 3, research.md R19)
│       ├── DependencyInjection.cs                         # EDIT — services.AddScoped<IEutrPurchaseMissingRepository, EutrPurchaseMissingRepository>()
│       └── Sqls/
│           ├── Migration/19_create_eutr_purchase_missing.sql   # ALREADY CREATED — manual-apply DDL, applied to the local dev DB
│           └── Tables/eutr_purchase_missing.sql                # ALREADY CREATED — auto-run by DatabaseInitializer.InitTables() on a fresh DB
└── tests/
    └── ComplianceSysApi.UnitTests/
        └── Services/
            └── EutrSynchronizeDataServiceTests.cs          # EDIT — existing User Story 2 tests updated to mock IEutrPurchaseMissingRepository (DeleteAllAsync/InsertManyAsync/GetAllAsync) instead of asserting purely on in-memory findings. User Story 3: new test method group for SyncTemplatesToDynamicsAsync, mocking IEutrTemplatesRepository/IEutrTemplateReferencesRepository/IDynamicService added to CreateService()
```

**Infrastructure change this update** (new, unlike the 2026-08-13 update which touched none): one new
repository, `EutrPurchaseMissingRepository`, implementing the new `IEutrPurchaseMissingRepository` —
built by direct structural copy of `ComplSoMissingRepository.cs` (research.md R17), registered once
in `ComplianceSys.Infrastructure/DependencyInjection.cs` alongside the existing
`IComplSoMissingRepository` registration. User Story 3 (2026-08-17) adds two methods to already-
registered repositories (`EutrTemplatesRepository`, `EutrTemplateReferencesRepository`) — no new
repository class, no new DI registration. No `compliance-client/` change: all three actions remain
backend-only, manually-triggered test endpoints with no UI.

**Structure Decision**: Single-project backend addition inside the existing `compliance-sys-api`
Clean Architecture layering (Constitution Principle I) — `Api` → `Application` → `Domain`, with
`Infrastructure` now also implementing one new repository (`EutrPurchaseMissingRepository`) for this
feature, alongside the pure-reuse touch points already established in the 2026-08-13 update
(`EutrPurchaseAttachmentsRepository`, `EutrTemplatesRepository`, `EutrReferencesRepository`,
`GroupDetailRepository`). No `compliance-client` (frontend) directories are involved.

## Complexity Tracking

*No Constitution Check violations — this section is not applicable.*
