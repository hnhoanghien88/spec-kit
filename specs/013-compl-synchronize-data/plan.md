# Implementation Plan: Compliance Synchronize Data (Sales Line + Variant Attributes)

**Branch**: `013-compl-synchronize-data` | **Date**: 2026-08-19 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/013-compl-synchronize-data/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Add a single manually-triggered backend action (`GET api/compl-synchronize-data/test-compl-synchronize-data`)
that, in one run: (1) pulls every ERP Sales Line record (`RSVNSalesLineOpenInvoiceCogs`, endpoint
`sales-line`), enriches each with its matching Product's Name/Description/Type/Range from the ERP's
Product reference data (reference type 6, `RSVNProductVariantAlls`, matched on ProductCode/ConfigId),
and stores the result in a new table `compl_sync_sales_line`; then (2) derives the distinct
ProductCode+ConfigId combinations from that stored data and, for each one, pulls its Variant
Attribute data (`ProductVariantAttributes`, endpoint `product-variant-attributes`) into a second new
table, `compl_sync_variant_attributes`. This clones the shape of the existing
`011-eutr-synchronize-data` feature (`EutrSynchronizeDataController` / `EutrSynchronizeDataService`)
— same "test-" GET action naming, same page-until-short-page loop, same clear-then-repopulate local
store pattern, same self-describing summary-DTO response.

## Technical Context

**Language/Version**: C# / .NET 8 (existing `compliance-sys-api` solution)

**Primary Dependencies**: ASP.NET Core Web API, Dapper (`Shared.Dapper`), `Shared.ExternalServices`
(`IDynamicService`, `DynamicsParameterManager` — the existing D365/Dynamics OData client already
used by `DynController` and `ComplDynamicsService`), Newtonsoft.Json (`OdataMapper<T>` deserialization,
matching the existing but currently-commented-out pattern in `DynController.RSVNSalesLineOpenInvoiceCogs`
/ `.ProductVariantAttributes`)

**Storage**: MySQL via Dapper (no EF Core, no migrations framework — hand-written SQL under
`ComplianceSys.Infrastructure/Sqls/Migration/` + `Sqls/Tables/`, per this repo's established
convention)

**Testing**: xUnit + Moq (`ComplianceSysApi.UnitTests`), mirroring the existing
`EutrSynchronizeDataServiceTests.cs`

**Target Platform**: Backend only — ASP.NET Core Web API (`ComplianceSys.Api`). No frontend/UI
change; this is a manually-triggered "test-" endpoint like its 011 precedent, not a screen.

**Project Type**: Backend feature addition (single project: `compliance-sys-api/`)

**Performance Goals**: No explicit throughput target (manually-triggered, test-oriented action, same
as 011). Must page through the full ERP Sales Line dataset without truncation (spec SC-001) and must
perform exactly one Variant Attribute lookup per distinct Product+Config combination, not per Sales
Line row (spec SC-003) — the phase 1 Product-reference enrichment lookup (type 6) is bulk-fetched
once, in memory, rather than once per Sales Line row, for the same reason `SendPurchaseMissingAlertAsync`
(011 User Story 2) bulk-fetches vendors/templates instead of querying per purchase order.

**Constraints**: Must reuse the existing `IDynamicService`/`DynamicsParameterManager` D365 client and
`IComplDynamicsService.GetDynRefePagedAsync` reference-lookup mechanism rather than introducing a new
HTTP client; must follow the clear-then-repopulate pattern already established by `compl_so_missing`
(009) and `eutr_purchase_missing` (011) for both new tables (confirmed via `/speckit-specify`
clarification, spec.md).

**Scale/Scope**: One new controller (1 action), one new Application service (1 method, 2 internal
phases), two new repositories, two new entities/tables, one new summary DTO, additive changes to the
existing `ComplDynReferenceResponseDto` / `ComplDynamicsService.MapDynamicsResponse` (case 6) to
surface the fields this feature needs from the Product reference lookup. No frontend work.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Layered Clean Architecture** — PASS. Controller stays thin (one action, delegates to
  `IComplSynchronizeDataService`); business logic lives in `ComplianceSys.Application/Services`;
  new entities in `ComplianceSys.Domain/Entities`; Dapper SQL in `ComplianceSys.Infrastructure/Repositories`.
- **II. Reference-Pattern Reuse** — PASS. This feature is explicitly modeled on
  `011-eutr-synchronize-data` (`EutrSynchronizeDataController`/`EutrSynchronizeDataService`), per the
  user's own request ("giống EutrSynchronizeDataController"). The "document-type" canonical CRUD
  reference does not apply here — this is a one-shot sync action, not a CRUD screen, so the more
  specific, already-precedented sync-feature shape (011, and its own `compl_so_missing`/009 local-store
  pattern) is the correct reference to clone, consistent with how 011 itself was planned.
- **III. Reuse Existing Backend** — PASS with additive extension. The D365 client
  (`IDynamicService`/`DynamicsParameterManager`), the generic reference lookup
  (`IComplDynamicsService.GetDynRefePagedAsync`), and the `sales-line`/`product-variant-attributes`
  raw query building blocks already exist and are reused as-is. The one extension —
  `ComplDynReferenceResponseDto` gains new nullable fields and `MapDynamicsResponse` case 6 gains a
  new mapping branch — is strictly additive (no existing field removed or renamed), matching the
  precedent already set by 011's own research.md R2/R3 (case 19 additive fix). No controller/service/
  DTO already in production is rewritten or duplicated.
- **IV. Vietnamese Comments; Localizable UI Labels** — PASS. No UI. Code comments for the new
  service/repositories will be written in Vietnamese, consistent with `EutrSynchronizeDataService.cs`.
- **V. Routing & Menu Registration** — N/A. No frontend screen; nothing to route or add to the menu.

No violations. Complexity Tracking section is not needed.

## Project Structure

### Documentation (this feature)

```text
specs/013-compl-synchronize-data/
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
├── src/
│   ├── ComplianceSys.Api/
│   │   └── Controllers/
│   │       └── ComplSynchronizeDataController.cs         # NEW — GET test-compl-synchronize-data
│   ├── ComplianceSys.Application/
│   │   ├── Interfaces/Services/IComplSynchronizeDataService.cs   # NEW
│   │   ├── Services/ComplSynchronizeDataService.cs                # NEW
│   │   ├── Interfaces/Repositories/IComplSyncSalesLineRepository.cs           # NEW
│   │   ├── Interfaces/Repositories/IComplSyncVariantAttributesRepository.cs   # NEW
│   │   ├── Dtos/Response/ComplSynchronizeDataSummaryDto.cs        # NEW
│   │   ├── Dtos/Response/ComplDynReferenceResponseDto.cs          # MODIFIED (additive fields)
│   │   ├── Services/ComplDynamicsService.cs                       # MODIFIED (case 6 additive mapping)
│   │   └── DependencyInjection.cs                                  # MODIFIED (register new service)
│   ├── ComplianceSys.Domain/
│   │   └── Entities/
│   │       ├── ComplSyncSalesLine.cs         # NEW
│   │       └── ComplSyncVariantAttributes.cs # NEW
│   └── ComplianceSys.Infrastructure/
│       ├── Repositories/
│       │   ├── ComplSyncSalesLineRepository.cs           # NEW
│       │   └── ComplSyncVariantAttributesRepository.cs   # NEW
│       ├── DependencyInjection.cs                         # MODIFIED (register new repositories)
│       └── Sqls/
│           ├── Migration/
│           │   ├── 22_create_compl_sync_sales_line.sql          # NEW
│           │   └── 23_create_compl_sync_variant_attributes.sql  # NEW
│           └── Tables/
│               ├── compl_sync_sales_line.sql          # NEW
│               └── compl_sync_variant_attributes.sql  # NEW
└── tests/
    └── ComplianceSysApi.UnitTests/
        └── Services/
            └── ComplSynchronizeDataServiceTests.cs   # NEW — mirrors EutrSynchronizeDataServiceTests.cs
```

**Structure Decision**: Single existing backend project (`compliance-sys-api/`), Clean Architecture
layers as already established. No frontend changes — this is a backend-only, manually-triggered sync
action with no UI, matching its 011 precedent exactly.

## Complexity Tracking

*Not applicable — no Constitution Check violations.*
