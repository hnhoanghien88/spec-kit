# Implementation Plan: Compliance Master Alert Type

**Branch**: `007-compl-master` | **Date**: 2026-07-30 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/007-compl-master/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Add an `AlertType` field (All=0 / Missing=1 / Expired=2, default All) to the existing Compliance Master feature, end to end: backend `AlertType` enum + entity/DTO property + read-path stored procedure updates (US1/US2), a frontend enum + form field (rendered directly below Description on both `compliance-master/new` and `compliance-master/{id}`) wired into the existing save/load flow (US1/US2), and an "Alert type" column in the Compliance Master list positioned directly after "Status" (US3). US3 is purely a display consumer of the value US1/US2 introduce — no new backend work is needed for it, since the paged list already returns the field once US1/US2's backend work lands. No new screens, routes, or endpoints — this extends the existing `ComplMasterController` payload shape only, per Constitution Principle III.

## Technical Context

**Language/Version**: Backend: C# / .NET 8. Frontend: JavaScript (React 18+ / Vite), MUI (including MUI X Data Grid for the list).

**Primary Dependencies**: Backend: AutoMapper, Dapper (`Shared.Dapper`), FluentValidation, Serilog. Frontend: MUI (`@mui/material`, `@mui/x-data-grid`), `dayjs`, React Router.

**Storage**: MySQL (`compl_masters` table — `AlertType` column already added per the original request; read stored procedures need updating, see `research.md` R4/R4b).

**Testing**: No existing automated test suite was found for this feature slice (manual verification via the app, per `quickstart.md`); this plan does not introduce new testing infrastructure — consistent with the rest of the compliance-master feature, which has no test files today.

**Target Platform**: Web application (ASP.NET Core Web API backend + React SPA frontend).

**Project Type**: Web application (existing monorepo: `compliance-sys-api` + `compliance-client`).

**Performance Goals**: N/A — a handful of new scalar/read-only surfaces (one form field, one grid column) on an existing form/record; no new performance-sensitive paths.

**Constraints**: Must not change the shape/behavior of unrelated fields, existing authorization policies, the Status column's own behavior, or the stored procedures' existing parameters/output columns beyond adding one column to two read procedures.

**Scale/Scope**: One new field across 2 forms (create, edit) + 1 list column, 1 entity, 1 DTO, 1 new small enum (both layers), 2 stored procedures' `SELECT` lists, 1 migration file, 1 frontend label lookup.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Layered Clean Architecture** — PASS. Backend changes stay within `Domain` (new enum, entity property) and `Application` (DTO property); `ComplMasterController.cs` itself needs no changes (already thin, delegates to `IComplMasterService`). Frontend changes stay within the existing `presentation/pages/compliance-master` form component and columns hook, plus `utils/helpers.js`, matching how every other scalar field/column on this feature is already wired — no new layer-crossing introduced.
- **II. Reference-Pattern Reuse** — PASS (with a noted pre-existing gap). The new backend enum follows the exact style of `ComplType.cs`/`GroupEmailType.cs`. The new frontend enum/label lookups follow `TEMPLATE_STATUS`/`REQUIREMENT_TYPES`/`TEMPLATE_STATUS_LABELS` in `helpers.js`. The new list column follows the exact shape of the existing `status` column immediately preceding it. Note: compliance-master itself was never fully built to the `document-type` reference pattern (no `ComplianceMaster.js` domain entity exists); this plan does not retrofit that, it only follows the feature's own established (if imperfect) conventions.
- **III. Reuse Existing Backend** — PASS. `ComplMasterController.cs`, its policies, and its overall service/repository structure are reused unchanged. The only backend additions are the verified gap: a DB column that already exists but isn't yet surfaced through the entity/DTO/stored procedures. The list column (US3) requires zero backend changes beyond that.
- **IV. Vietnamese Comments; Localizable UI Labels** — PASS. The compliance-master form's and list's existing UI labels ("Master Name", "Description", "Status", etc.) are already in English, so "Alert type" matches the feature's own established UI language; new backend code comments (if any) will be written in Vietnamese per the existing file style.
- **V. Routing & Menu Registration** — PASS / N/A. No new routes or menu entries — `compliance-master/new`, `compliance-master/{id}`, and the list are already registered and reachable.

No violations; Complexity Tracking section is empty.

## Project Structure

### Documentation (this feature)

```text
specs/007-compl-master/
├── plan.md                                  # This file
├── research.md                               # Phase 0 output
├── data-model.md                             # Phase 1 output
├── quickstart.md                             # Phase 1 output
├── contracts/
│   └── compliance-master-alerttype.md        # Phase 1 output (US1/US2 payload delta; US3 needs no contract change)
└── tasks.md                                  # Phase 2 output (/speckit-tasks)
```

### Source Code (repository root)

```text
compliance-sys-api/
└── src/
    ├── ComplianceSys.Domain/
    │   ├── Entities/
    │   │   └── ComplMaster.cs                          # `public int AlertType { get; set; }`
    │   └── Enums/
    │       └── AlertType.cs                             # enum All=0, Missing=1, Expired=2 (byte)
    ├── ComplianceSys.Application/
    │   └── Dtos/
    │       └── Request/
    │           └── ComplMasterRequest.cs                # `AlertType` property
    │           # ComplMasterMappingProfile.cs and ComplMasterResponse.cs: no change needed
    │           # (auto-mapped by name / inherited — see research.md R3)
    ├── ComplianceSys.Infrastructure/
    │   └── Sqls/
    │       ├── Migration/
    │       │   └── 15_add_alerttype_to_compl_masters_procs.sql   # redefines the 2 read procs
    │       │                                                      # (+ ALTER TABLE column-width fix, R4b)
    │       ├── Procedures/
    │       │   ├── compl_sp_get_compl_master_paging.sql          # refreshed reference copy
    │       │   └── compl_sp_get_compl_master_by_id.sql           # refreshed reference copy
    │       └── Tables/
    │           └── compl_masters.sql                              # documents the AlertType column
    └── ComplianceSys.Api/
        └── Controllers/
            └── ComplMasterController.cs                # NO CHANGE (payload shape only)

compliance-client/
└── src/
    ├── utils/
    │   └── helpers.js                                   # ALERT_TYPE / ALERT_TYPE_OPTIONS (US1/US2) +
    │                                                     # ALERT_TYPE_LABELS (US3)
    └── presentation/
        └── pages/
            └── compliance-master/
                ├── components/
                │   └── ComplianceMasterForm.jsx          # US1/US2: masterInfo.alertType state, field UI
                │                                          # below Description, edit-load population, save payload
                └── hooks/
                    └── useComplianceMasterColumns.jsx     # US3: "alertType" column right after "status",
                                                            # defaultColumnVisibility.alertType = true
```

**Structure Decision**: Existing web-application layout (`compliance-sys-api` + `compliance-client`) is reused unchanged. All backend changes stay within `Domain` → `Application` → `Infrastructure` (no `Api` controller change needed); all frontend changes stay within the existing `presentation/pages/compliance-master` feature folder plus the shared `utils/helpers.js`. No new files outside what's listed above.

## Complexity Tracking

*No Constitution Check violations — this section is intentionally empty.*
