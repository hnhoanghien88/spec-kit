# Implementation Plan: EUTR Synchronize Data (Sales Order Template Sync)

**Branch**: `011-eutr-synchronize-data` | **Date**: 2026-08-11 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/011-eutr-synchronize-data/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Add a manually-triggered synchronization endpoint (`EutrSynchronizeDataController`, modeled on
`ComplNotificationController`) that pulls the full D365 "Sales Order Templates" reference dataset
(reference type 19) via the existing `IComplDynamicsService.GetDynRefePagedAsync` pipeline and
creates a corresponding `eutr_purchase_attachments` row (`SalesId`/`PurchId`/`TemplateCode`) for
every sales order that doesn't already have one, skipping any that do. Research (research.md R2)
found that reference type 19 currently returns an empty result due to a missing `EntityMappings`
entry in `ComplDynamicsService` (the same class of gap already fixed once for type 18 in feature
009) — fixing that is a required, in-scope prerequisite for this feature to do anything at all.

## Technical Context

**Language/Version**: C# / .NET 8 (existing `compliance-sys-api` solution)

**Primary Dependencies**: ASP.NET Core Web API, Dapper (via `Res.Shared.Dapper` NuGet package),
existing `IComplDynamicsService` (D365 OData reference proxy), existing
`IEutrPurchaseAttachmentsRepository` / generic `IRepository<EutrPurchaseAttachments,int>`

**Storage**: MySQL — existing `eutr_purchase_attachments` table (no schema change); D365 (Dynamics
365) as the read-only source, reference entity `RSVNEutrSalesOrderTemplates` (already modeled)

**Testing**: xUnit (`ComplianceSysApi.UnitTests`), matching the existing test project's conventions

**Target Platform**: Existing ASP.NET Core Web API backend (`compliance-sys-api`), server-side only
— no frontend/UI change

**Project Type**: Web service (backend-only feature; no `compliance-client` changes)

**Performance Goals**: No new explicit target; reuses the existing 1000-row page size convention
from `ComplNotificationService.RefreshSalesOrderMissingComplianceAsync` for the D365 paging loop, so
a full sync run stays proportional to existing similar batch jobs.

**Constraints**: Must not alter behavior for any other `refType` value in `ComplDynamicsService`
(the `EntityMappings`/`MapDynamicsResponse` change is additive, scoped to `19` only — research.md
R2/R3). Must not wrap the whole run in a single DB transaction (spec allows partial progress on
mid-run failure — research.md R7).

**Scale/Scope**: One new controller (1 action), one new Application service + interface, one new
response DTO, a small additive fix to one existing service file (`ComplDynamicsService`), one new DI
registration. No new table, no new domain entity, no frontend work.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Layered Clean Architecture** — PASS. New controller stays in `ComplianceSys.Api/Controllers`
  and delegates immediately to a new `Application` service (`EutrSynchronizeDataService`); no
  business logic in the controller. The service depends only on existing `Application`/`Domain`
  abstractions (`IComplDynamicsService`, `IEutrPurchaseAttachmentsRepository`,
  `IRepository<EutrPurchaseAttachments,int>`, `IUnitOfWork` not required per R7). No frontend layer
  is touched (backend-only feature).
- **II. Reference-Pattern Reuse** — PASS. Controller attribute shape and action style explicitly
  clone `ComplNotificationController` (per the feature request). The D365-paging loop clones
  `ComplNotificationService.RefreshSalesOrderMissingComplianceAsync`'s exact shape (research.md R4).
  The write path clones `EutrPurchaseAttachmentsService.SavePoMappingAsync`'s use of the generic
  `IRepository<EutrPurchaseAttachments,int>.AddAsync` (research.md R6).
- **III. Reuse Existing Backend** — PASS with one scoped, verified-gap exception: this feature edits
  `ComplDynamicsService.cs` (existing file) to add the missing `refType = 19` `EntityMappings` entry
  and enrich `case 19`'s DTO mapping (research.md R2/R3). This is not a rewrite/duplication of
  working code — it is the same "fix a missing reference-type mapping" gap already fixed once before
  for `refType = 18` (feature 009), and it is a prerequisite: without it, `refType = 19` always
  returns empty and the feature has nothing to sync. No other existing controller/service/DTO is
  regenerated or duplicated; `IEutrPurchaseAttachmentsRepository`, `EutrPurchaseAttachments`, and
  `IComplDynamicsService` are reused exactly as they exist today.
- **IV. Vietnamese Comments; Localizable UI Labels** — PASS. Backend-only feature; no UI labels.
  New code comments (in the new service, and around the `ComplDynamicsService` fix) will be written
  in Vietnamese per existing file conventions (see the Vietnamese comments already in
  `ComplDynamicsService.cs`, `EutrPurchaseAttachmentsService.cs`).
- **V. Routing & Menu Registration** — N/A. No new frontend screen/route; this is a backend-only,
  manually-triggered test endpoint with no UI entry point (consistent with
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
│   └── eutr-synchronize-data-test-so-template-sync.md
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
compliance-sys-api/
├── src/
│   ├── ComplianceSys.Api/
│   │   └── Controllers/
│   │       └── EutrSynchronizeDataController.cs          # NEW — [Authorize], api/eutr-synchronize-data
│   ├── ComplianceSys.Application/
│   │   ├── Interfaces/Services/
│   │   │   └── IEutrSynchronizeDataService.cs             # NEW
│   │   ├── Services/
│   │   │   ├── EutrSynchronizeDataService.cs              # NEW — orchestrates R1/R4/R5/R6/R7
│   │   │   └── ComplDynamicsService.cs                    # EDIT — EntityMappings[19] + case 19 (R2/R3)
│   │   ├── Dtos/Response/
│   │   │   └── EutrSynchronizeSummaryDto.cs               # NEW
│   │   └── DependencyInjection.cs                         # EDIT — register IEutrSynchronizeDataService
│   └── ComplianceSys.Domain/                               # unchanged (EutrPurchaseAttachments, RSVNEutrSalesOrderTemplates reused as-is)
└── tests/
    └── ComplianceSysApi.UnitTests/
        └── Services/
            └── EutrSynchronizeDataServiceTests.cs          # NEW — covers spec Acceptance Scenarios 1-4
```

No `compliance-sys-api/src/ComplianceSys.Infrastructure/` change: this feature reuses
`IEutrPurchaseAttachmentsRepository.GetSalesIdsWithTemplateAsync` and the generic Dapper
`IRepository<EutrPurchaseAttachments,int>` exactly as they exist today (research.md R5/R6). No
`compliance-client/` change: this is a backend-only, manually-triggered test endpoint with no UI.

**Structure Decision**: Single-project backend addition inside the existing `compliance-sys-api`
Clean Architecture layering (Constitution Principle I) — `Api` → `Application` → `Domain`, with the
one `Infrastructure`-adjacent touch point being reuse (not modification) of the existing
`EutrPurchaseAttachmentsRepository`. No `compliance-client` (frontend) directories are involved.

## Complexity Tracking

*No Constitution Check violations — this section is not applicable.*
