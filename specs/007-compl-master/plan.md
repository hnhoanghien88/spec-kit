# Implementation Plan: Compliance Master Alert Type & Delete Fix

**Branch**: `007-compl-master` | **Date**: 2026-07-30 | **Updated**: 2026-09-08 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/007-compl-master/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Add an `AlertType` field (All=0 / Missing=1 / Expired=2, default All) to the existing Compliance Master feature, end to end: backend `AlertType` enum + entity/DTO property + read-path stored procedure updates (US1/US2), a frontend enum + form field (rendered directly below Description on both `compliance-master/new` and `compliance-master/{id}`) wired into the existing save/load flow (US1/US2), and an "Alert type" column in the Compliance Master list positioned directly after "Status" (US3). US3 is purely a display consumer of the value US1/US2 introduce — no new backend work is needed for it, since the paged list already returns the field once US1/US2's backend work lands. No new screens, routes, or endpoints — this extends the existing `ComplMasterController` payload shape only, per Constitution Principle III.

**User Story 4 (delete fix, added 2026-08-20)**: Fix the Compliance Master delete/bulk-delete actions, which currently fail with a generic 500 error for any master that still has linked `compl_references` rows (reproduced with `MAS-01104`) because the generic delete path performs a hard `DELETE` blocked by the `fk_compl_references_master ON DELETE RESTRICT` constraint. The fix is backend-only: override `ComplMasterService.DeleteAsync`/`DeleteMultiAsync` to soft-delete (`IsDelete = 1`) via a new command-service method, mirroring the working `ComplCompliancesService`/`ComplCompliancesMutationService.DeleteAsync` pattern, and update the affected read stored procedures to exclude soft-deleted masters. See `research.md` R12–R16.

**User Story 5 (Customer Table logic, added 2026-09-08)**: On the Compliance Master detail screen's rule-condition builder (`compliance-master/{id}`, e.g. `compliance-master/1021`, "Individual Rule Conditions (AND only)" / "CONDITIONS"), the Customer condition's Type selector can currently only offer "Value"/"NOT IN" whenever another condition in the same AND block already uses "Table" — because of a frontend-only rule, `blockHasTable` in `ComplianceMasterForm.jsx`, that limits Table logic to at most one condition per rule block, regardless of reference type. This is frontend-only: relax that rule so any number of conditions in a block (Customer, Product Type, or any other reference type) can independently use Table logic. The Master Preview already renders a Table condition generically by reference type (header line `"<ObjectType> IN"` + one bullet per selected value) — per explicit confirmation from the requester, Customer reuses this exact presentation unchanged, so no preview-formatting code changes. No backend/DTO/validator changes are needed (confirmed: `DisplayType` is stored and validated identically regardless of `RefTypeId`, see `research.md` R17). The "kiểm tra lại logic" ask against `sp_load_compl_by_conditions`/`sp_load_compl_by_conditions_count` is satisfied as a verification finding, not a code change: both procedures already match Table-logic conditions (any reference type, including Customer) generically by row count in `compl_master_condition_values`, with no `RefTypeCode`-specific branching outside the pre-existing COUNTRY-group case — see `research.md` R18–R19.

## Technical Context

**Language/Version**: Backend: C# / .NET 8. Frontend: JavaScript (React 18+ / Vite), MUI (including MUI X Data Grid for the list).

**Primary Dependencies**: Backend: AutoMapper, Dapper (`Shared.Dapper`), FluentValidation, Serilog. Frontend: MUI (`@mui/material`, `@mui/x-data-grid`), `dayjs`, React Router.

**Storage**: MySQL (`compl_masters` table — `AlertType` column already added per the original request; read stored procedures need updating, see `research.md` R4/R4b).

**Testing**: No existing automated test suite was found for this feature slice (manual verification via the app, per `quickstart.md`); this plan does not introduce new testing infrastructure — consistent with the rest of the compliance-master feature, which has no test files today.

**Target Platform**: Web application (ASP.NET Core Web API backend + React SPA frontend).

**Project Type**: Web application (existing monorepo: `compliance-sys-api` + `compliance-client`).

**Performance Goals**: N/A — a handful of new scalar/read-only surfaces (one form field, one grid column) on an existing form/record; no new performance-sensitive paths.

**Constraints**: Must not change the shape/behavior of unrelated fields, existing authorization policies, the Status column's own behavior, or the stored procedures' existing parameters/output columns beyond adding one column to two read procedures. (US4) Must not change the `DELETE`/bulk-delete endpoints' request/response shape or authorization policy — only their internal success/failure behavior; must not remove or alter any existing FK constraint (`fk_compl_references_master` stays `ON DELETE RESTRICT` — the fix stops triggering it, it does not weaken it). (US5) Must not change the Master Preview's existing rendering format for Table/NOT-IN conditions (per requester confirmation, reuse as-is); must not change `compl_master_conditions`/`compl_master_condition_values` schema, the `DisplayType`/`Operator` semantics, or any other reference type's current behavior; the `sp_load_compl_by_conditions`/`sp_load_compl_by_conditions_count` review is verification-only — no stored-procedure edit is authorized unless a real defect is found and confirmed with the requester first (per spec FR-019 and this project's "kiểm tra" = verify-only convention).

**Scale/Scope**: One new field across 2 forms (create, edit) + 1 list column, 1 entity, 1 DTO, 1 new small enum (both layers), 2 stored procedures' `SELECT` lists, 1 migration file, 1 frontend label lookup. (US4, additive) 2 new command-service methods (single + batch soft delete), 1 service-layer override wiring, 3 stored procedures updated to exclude soft-deleted masters, 1 migration file — no frontend changes. (US5, additive) 1 frontend logic change (one conditional in `ComplianceMasterForm.jsx`'s Type-selector gating) — no new fields, no new components, no backend/DB changes, no migration file.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Layered Clean Architecture** — PASS. Backend changes stay within `Domain` (new enum, entity property) and `Application` (DTO property); `ComplMasterController.cs` itself needs no changes (already thin, delegates to `IComplMasterService`). Frontend changes stay within the existing `presentation/pages/compliance-master` form component and columns hook, plus `utils/helpers.js`, matching how every other scalar field/column on this feature is already wired — no new layer-crossing introduced. (US4) The delete fix stays entirely within `Application` (`ComplMasterService`, `IComplMasterCommandService`/`ComplMasterCommandService`) and `Infrastructure` (stored procedures); `ComplMasterController.cs` needs no changes here either — its `Delete`/`BulkDelete` actions already delegate to `IComplMasterService`, which is exactly the seam this fix uses. (US5) The entire change is one conditional inside `presentation/pages/compliance-master/components/ComplianceMasterForm.jsx` (`Domain`/`Application`/`Infrastructure` untouched — confirmed no backend restriction exists to relax); no new layer-crossing.
- **II. Reference-Pattern Reuse** — PASS (with a noted pre-existing gap). The new backend enum follows the exact style of `ComplType.cs`/`GroupEmailType.cs`. The new frontend enum/label lookups follow `TEMPLATE_STATUS`/`REQUIREMENT_TYPES`/`TEMPLATE_STATUS_LABELS` in `helpers.js`. The new list column follows the exact shape of the existing `status` column immediately preceding it. Note: compliance-master itself was never fully built to the `document-type` reference pattern (no `ComplianceMaster.js` domain entity exists); this plan does not retrofit that, it only follows the feature's own established (if imperfect) conventions. (US4) The soft-delete fix directly clones `ComplCompliancesService.DeleteAsync` → `ComplCompliancesMutationService.DeleteAsync`'s already-working pattern (set `IsDelete`/`ValidTo`, `UpdateAsync`, record history) — the strongest form of this principle: a live, already-shipped sibling solving the identical problem. (US5) Customer already goes through the exact same generic `objectTypes`/`RefTypeId`-driven Type-selector code as Product Type (see `research.md` R17) — this fix makes the one restriction (`blockHasTable`) match how every reference type is otherwise already treated identically, rather than introducing a Customer-specific branch.
- **III. Reuse Existing Backend** — PASS. `ComplMasterController.cs`, its policies, and its overall service/repository structure are reused unchanged. The only backend additions are the verified gap: a DB column that already exists but isn't yet surfaced through the entity/DTO/stored procedures. The list column (US3) requires zero backend changes beyond that. (US4) Same controller, same routes, same `[Authorize]` policies (`ComplianceMaster.Delete`) — only the service-layer implementation behind `DeleteAsync`/`DeleteMultiAsync` changes, closing a verified gap (`IsDelete` column exists and is already partially read but never written) rather than adding new surface. (US5) No backend change at all — confirmed the API/DTO/validator/stored-procedure layer already accepts and evaluates `DisplayType = 1` (Table) for any `RefTypeId` including Customer with zero code changes needed (`research.md` R17–R19); this is the strongest form of the principle, a pure frontend fix against an already-capable backend.
- **IV. Vietnamese Comments; Localizable UI Labels** — PASS. The compliance-master form's and list's existing UI labels ("Master Name", "Description", "Status", etc.) are already in English, so "Alert type" matches the feature's own established UI language; new backend code comments (if any) will be written in Vietnamese per the existing file style. (US4) No new UI labels — this fix is backend-only; new C# code comments (if any) follow the existing Vietnamese-comment style, matching `ComplCompliancesMutationService.cs`. (US5) No new UI labels — "Table"/"Value"/"NOT IN" option labels already exist and are unchanged; any new inline comment in `ComplianceMasterForm.jsx` follows the file's existing comment-language convention (already mixed English/no-comment in this file; no new Vietnamese comment is required where the existing code has none).
- **V. Routing & Menu Registration** — PASS / N/A. No new routes or menu entries — `compliance-master/new`, `compliance-master/{id}`, and the list are already registered and reachable. (US4) N/A — no new routes; existing `DELETE api/compliance-master/{id}` and `POST api/compliance-master/bulk-delete` routes and their `ComplianceMaster.Delete` policy are unchanged. (US5) N/A — no new routes; the same `compliance-master/{id}` detail screen is used unchanged.

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
│   ├── compliance-master-alerttype.md        # Phase 1 output (US1/US2 payload delta; US3 needs no contract change)
│   ├── compl-master-delete.md                # Phase 1 output (US4: delete/bulk-delete behavior contract, no payload change)
│   └── compl-master-condition-table-logic.md # Phase 1 output (US5: confirms no payload/API/SP contract change)
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

# --- User Story 4 (delete fix) ---
compliance-sys-api/
└── src/
    ├── ComplianceSys.Application/
    │   ├── Interfaces/Services/
    │   │   └── (no change — IComplMasterService already exposes DeleteAsync/DeleteMultiAsync
    │   │       via the base BaseService contract)
    │   └── Services/
    │       ├── ComplMasterService.cs                    # override DeleteAsync + DeleteMultiAsync,
    │       │                                             # delegate to _commandService (mirrors AddAsync)
    │       └── Master/
    │           ├── IComplMasterCommandService.cs         # + DeleteAsync(long, string, ct), 
    │           │                                          #   DeleteMultiAsync(IEnumerable<long>, string, ct)
    │           └── ComplMasterCommandService.cs           # + implementations: load, IsDelete=1, UpdatedBy/Date,
    │                                                       #   UpdateAsync, AddHistoryAsync, all in a transaction
    │                                                       #   (single = one row; batch = one transaction, N rows)
    └── ComplianceSys.Infrastructure/
        └── Sqls/
            ├── Migration/
            │   └── 26_fix_compl_master_delete_soft_delete.sql   # redefines compl_sp_get_compl_master_paging,
            │                                                     # compl_sp_get_compl_master_paging_count,
            │                                                     # compl_sp_get_compl_master_missing_for_alert
            │                                                     # to exclude cd.IsDelete = 1 (master's own flag)
            └── Procedures/
                ├── compl_sp_get_compl_master_paging.sql               # refreshed reference copy
                ├── compl_sp_get_compl_master_paging_count.sql         # refreshed reference copy
                └── compl_sp_get_compl_master_missing_for_alert.sql    # refreshed reference copy
                # compl_sp_get_compl_master_by_id.sql: NO CHANGE (single-record lookup keeps
                # resolving soft-deleted masters by id on purpose — see research.md R14)

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

# --- User Story 5 (Customer Table logic) ---
compliance-client/
└── src/
    └── presentation/
        └── pages/
            └── compliance-master/
                └── components/
                    └── ComplianceMasterForm.jsx          # ONLY file touched: relax `blockHasTable`
                                                            # (~line 1397-1400) so Table availability is no
                                                            # longer gated by another condition in the same
                                                            # block already using Table; the two menu-item
                                                            # branches that currently read `blockHasTable`
                                                            # (~line 1456, ~line 1478) collapse accordingly.
                                                            # No other file changes — MasterPreview memo (:326-352),
                                                            # the rendered MASTER PREVIEW panel (:1856+), payload
                                                            # build (:611-644), and ConditionsView.jsx are already
                                                            # fully generic per RefTypeId and need no edits.

# No backend/DB files touched for User Story 5 — see research.md R17-R19 (verified, not assumed):
#   compliance-sys-api/.../Domain/Entities/ComplMasterCondition.cs        — unchanged (DisplayType already generic)
#   compliance-sys-api/.../Application/Dtos/Request/ComplMasterConditionDto.cs — unchanged (no per-RefType validation)
#   compliance-sys-api/.../Application/Validators/ComplMasterDtoValidator.cs  — unchanged (no DisplayType rule at all)
#   compliance-sys-api/.../Infrastructure/Sqls/Procedures/sp_load_compl_by_conditions.sql       — unchanged (verified)
#   compliance-sys-api/.../Infrastructure/Sqls/Procedures/sp_load_compl_by_conditions_count.sql — unchanged (verified)
```

**Structure Decision**: Existing web-application layout (`compliance-sys-api` + `compliance-client`) is reused unchanged. All backend changes stay within `Domain` → `Application` → `Infrastructure` (no `Api` controller change needed); all frontend changes stay within the existing `presentation/pages/compliance-master` feature folder plus the shared `utils/helpers.js`. No new files outside what's listed above. User Story 4 is entirely backend (`Application` + `Infrastructure`), with zero frontend files touched — the existing delete UI already calls the same unchanged endpoints, so once the service-layer behavior and stored procedures are fixed, the existing "Confirm delete" flow in `compliance-master/index.jsx` starts succeeding with no client-side change required. User Story 5 is the inverse shape: entirely frontend, a single conditional in one existing file, with the backend/DB layer verified (not modified) — the smallest-footprint story in this spec.

## Complexity Tracking

*No Constitution Check violations — this section is intentionally empty.*
