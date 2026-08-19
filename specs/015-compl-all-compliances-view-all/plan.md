# Implementation Plan: All Compliances Sales-Line Fallback for Missing BOM

**Branch**: `015-compl-all-compliances-view-all` | **Date**: 2026-08-19 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/015-compl-all-compliances-view-all/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

When `ViewCompliancesService.GetViewCompliancesAsync`'s sales-order branch (backing
`[HttpPost("get-all")]`) gets zero rows back from the BOM-based sales-line lookup
(`GetSalesLineOpenMaterialFromDynamics`) — because no BOM has been created yet for that sales
order — it currently returns an empty compliance result even though the order's lines already
exist elsewhere in Dynamics. This plan adds a fallback: when that lookup is empty, fetch the sales
order's lines from the `RSVNSalesLineOpenInvoiceCogs` entity (`sales-line`), map them into the same
`RSVNSalesLineOpenMaterialRvns` shape the BOM-based lookup produces (`InterSalesId = "cog" + SalesId`,
`ProductCode = ItemId`, same-named fields copied directly), enrich `ProductType`/`ProductRange` via
a `RSVNProductVariantAlls` (`product-variant-info`) lookup keyed on `ProductCode` + `ConfigId`, and
feed the result into the exact same downstream code the BOM-based path already uses. No HTTP
contract, database schema, or frontend changes are involved — this is a backend-only extension of
existing Application-layer services.

## Technical Context

**Language/Version**: C# / .NET 8 (ASP.NET Core Web API) — `compliance-sys-api`.

**Primary Dependencies**: Existing `IDynamicService` / `DynamicsParameterManager` / `Helper.ParseDynamicsResponse`
(Dynamics 365 F&O OData proxy) and `ICacheHelper` (existing cache abstraction) — the same
dependencies `DynamicsDataService` already uses for every sibling entity fetch. No new package.

**Storage**: N/A. Data is read live from Dynamics 365 F&O via OData (`RSVNSalesLineOpenInvoiceCogs`,
`RSVNProductVariantAlls`), optionally cached through the existing `ICacheHelper`, same as every
other `DynamicsDataService` method. No new SQL/database schema.

**Testing**: xUnit + Moq, matching `ComplianceSysApi.UnitTests/Services/ViewCompliances/DynamicsDataServiceTests.cs`
and `ViewCompliancesTransformServiceTests.cs` conventions (mock `IDynamicService`/`ICacheHelper` or
`IDynamicsDataService`, assert on the built OData filter and the mapped output).

**Target Platform**: Existing ASP.NET Core Web API service (`ComplianceSys.Api`) — same deployment
target as today, no new platform.

**Project Type**: Backend-only extension to a single existing web-service project; no frontend
project or new project is created.

**Performance Goals**: No new explicit target. The fallback must add zero extra Dynamics calls or
latency to the (majority) case where BOM data already exists — FR-003 requires the fallback to be
skipped entirely whenever the primary lookup returns data.

**Constraints**: Must not change the `[HttpPost("get-all")]` request/response contract (see
[contracts/sales-line-fallback.md](contracts/sales-line-fallback.md)); must not change behavior for
sales orders that already have BOM data (SC-002); must reuse the existing Dynamics OData client and
caching abstractions rather than introducing a new external client (Constitution Principle III).

**Scale/Scope**: One new fallback branch inside `ViewCompliancesService.GetViewCompliancesAsync`'s
existing sales-order case, two new data-fetch methods on `IDynamicsDataService`/`DynamicsDataService`,
one new composition method on `IViewCompliancesTransformService`/`ViewCompliancesTransformService`.
No new controller routes; the two Domain models involved (`RSVNSalesLineOpenInvoiceCogs`,
`RSVNProductVariantAlls`) already exist and need no changes.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Layered Clean Architecture** — PASS. New fetch methods stay in `DynamicsDataService`
  (Application layer, one entity per method, no business rules); the new field-mapping/composition
  method stays in `ViewCompliancesTransformService` (Application layer, already responsible for
  composing multiple Dynamics entities into one shape); `ViewCompliancesController` is untouched
  (still thin). No Infrastructure/Dapper layer involvement — this is pure Dynamics OData read
  composition, same as the code it extends.
- **II. Reference-Pattern Reuse** — PASS. `GetSalesLineOpenInvoiceCogsFromDynamics` clones
  `GetSalesLineOpenMaterialFromDynamics`'s structure; `GetRSVNProductVariantAllsByProductConfigFromDynamics`
  clones `GetRSVNProductVariantMaterialsFromDynamics`'s OR-of-ANDs filter pattern (see research.md
  R2–R3). No invented shape.
- **III. Reuse Existing Backend** — PASS. This is explicitly a verified gap in existing backend
  behavior (empty result when BOM is missing) — the fix reuses the existing Dynamics OData client,
  cache abstraction, and transform-service composition role rather than introducing new
  infrastructure. No existing working endpoint, DTO, or entity is regenerated or duplicated.
- **IV. Vietnamese Comments; Localizable UI Labels** — PASS (comments only). New code comments
  follow the existing Vietnamese-comment convention in this file (e.g. the "Lấy sale line..." style
  already present). No UI labels are involved — this feature has no frontend surface.
- **V. Routing & Menu Registration** — N/A. No new frontend screen or route; the existing
  `[HttpPost("get-all")]` route and its existing consumers are unchanged.

No violations — Complexity Tracking is not needed.

## Project Structure

### Documentation (this feature)

```text
specs/015-compl-all-compliances-view-all/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md         # Phase 1 output (/speckit-plan command)
├── quickstart.md         # Phase 1 output (/speckit-plan command)
├── contracts/
│   └── sales-line-fallback.md
└── tasks.md              # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
compliance-sys-api/
├── src/
│   ├── ComplianceSys.Api/
│   │   └── Controllers/
│   │       └── ViewCompliancesController.cs        # unchanged (existing get-all route)
│   ├── ComplianceSys.Application/
│   │   └── Services/
│   │       ├── ViewCompliancesService.cs            # MODIFY: call fallback when so-branch lookup is empty
│   │       └── ViewCompliances/
│   │           ├── IDynamicsDataService.cs           # MODIFY: add 2 method signatures
│   │           ├── DynamicsDataService.cs             # MODIFY: implement the 2 new fetch methods
│   │           ├── IViewCompliancesTransformService.cs # MODIFY: add fallback-build method signature
│   │           └── ViewCompliancesTransformService.cs  # MODIFY: implement fallback mapping
│   └── ComplianceSys.Domain/
│       └── Dynamics/
│           ├── RSVNSalesLineOpenMaterialRvns.cs      # unchanged (target/t1 shape, existing)
│           ├── RSVNSalesLineOpenInvoiceCogs.cs        # unchanged (t2 shape, existing, newly consumed)
│           └── RSVNProductVariantAlls.cs              # unchanged (t3 shape, existing, newly queried by Product+Config)
└── tests/
    └── ComplianceSysApi.UnitTests/
        └── Services/
            └── ViewCompliances/
                ├── DynamicsDataServiceTests.cs             # ADD cases for the 2 new fetch methods
                └── ViewCompliancesTransformServiceTests.cs # ADD cases for BuildSalesLineOpenMaterialFallbackAsync
```

**Structure Decision**: Backend-only change within the existing `compliance-sys-api` Clean
Architecture layout (`Api` → `Application` → `Domain`, Principle I). No frontend
(`compliance-client/`) files are touched — the spec identifies no UI-visible change, only a data
source substitution behind an existing endpoint. No new project or directory is created; all
changes land in files that already exist in the `ViewCompliances` service group.

## Complexity Tracking

*No Constitution Check violations — this section is intentionally empty.*
