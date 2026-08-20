---

description: "Task list for Compliance Master Alert Type & Delete Fix"

---

# Tasks: Compliance Master Alert Type & Delete Fix

**Input**: Design documents from `/specs/007-compl-master/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/compliance-master-alerttype.md](./contracts/compliance-master-alerttype.md), [contracts/compl-master-delete.md](./contracts/compl-master-delete.md), [quickstart.md](./quickstart.md)

**Tests**: Not requested in the feature spec — no automated test tasks are included. Validation is manual, via `quickstart.md`.

**Organization**: Tasks are grouped by user story (US1 = Create, P1; US2 = Edit, P2; US3 = List column, P3; US4 = Delete fix, P1, added 2026-08-20) to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4)
- Paths are relative to the repository root (`E:\Working\Eutr`)

## Path Conventions

- Backend: `compliance-sys-api/src/ComplianceSys.{Domain,Application,Infrastructure,Api}/...`
- Frontend: `compliance-client/src/...`

---

## Phase 1: Setup

**Purpose**: Confirm the environment this feature depends on is ready; no code changes.

- [X] T001 Confirm local `compliance-sys-api` and `compliance-client` run against a database where the `compl_masters.AlertType` column already exists, per Prerequisites in [quickstart.md](./quickstart.md) — confirmed live against dev DB `compliance_sys_db_260601` (column existed as `TINYINT(1)`, see T005 for a correctness fix required on it)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core enum/entity/DTO/stored-procedure/frontend-enum plumbing that ALL THREE user stories (Create, Edit, and the List column all read/write the same backend field through the same stored procedures) depend on.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T002 [P] Add `AlertType` enum in `compliance-sys-api/src/ComplianceSys.Domain/Enums/AlertType.cs` — `public enum AlertType : byte { All = 0, Missing = 1, Expired = 2 }`, matching the exact style of `ComplType.cs`/`GroupEmailType.cs` in the same folder
- [X] T003 [P] Add `public int AlertType { get; set; } = 0` property to the `ComplMaster` entity in `compliance-sys-api/src/ComplianceSys.Domain/Entities/ComplMaster.cs`
- [X] T004 [P] Add `public int AlertType { get; set; } = 0` property to `compliance-sys-api/src/ComplianceSys.Application/Dtos/Request/ComplMasterRequest.cs` (no `[Required]`, field is always defaulted)
- [X] T005 Pull the live definitions of `compl_sp_get_compl_master_paging` and `compl_sp_get_compl_master_by_id` directly from the target database (e.g. `SHOW CREATE PROCEDURE compl_sp_get_compl_master_by_id;`) — do NOT trust the checked-in `.sql` files, they are stale (see [research.md](./research.md) R4) — then create `compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Migration/15_add_alerttype_to_compl_masters_procs.sql` containing `DROP PROCEDURE IF EXISTS` + `CREATE PROCEDURE` for both, identical to the live definitions except `AlertType` (or `cm.AlertType AS AlertType`, matching the alias style already used) is added to each SELECT's column list (depends on T003) — **also found and fixed a real data-corruption bug**: the column was live as `TINYINT(1)`, which the `MySql.Data` driver auto-coerces to `bool`, silently collapsing `AlertType=2` (Expired) into `1` (Missing) on read; migration now also runs `ALTER TABLE compl_masters MODIFY COLUMN AlertType TINYINT NOT NULL DEFAULT 0;` first. Applied to the local dev DB and round-trip-verified (see [research.md](./research.md) R4b)
- [X] T006 [P] Refresh the stale reference copies `compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Procedures/compl_sp_get_compl_master_paging.sql` and `compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Procedures/compl_sp_get_compl_master_by_id.sql` to match the new live definitions captured in T005 (documentation-only, keeps the repo's reference copies in sync going forward) (depends on T005)
- [X] T007 [P] Update `compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Tables/compl_masters.sql` to add the `AlertType` column to the documented `CREATE TABLE` DDL (column already exists live; this is a documentation-only sync, per [data-model.md](./data-model.md))
- [X] T008 [P] Add an `AlertType` value map (`ALERT_TYPE`) + `{value, label}` options array (`ALERT_TYPE_OPTIONS`) to `compliance-client/src/utils/helpers.js`, mirroring the existing `TEMPLATE_STATUS`/`REQUIREMENT_TYPES` patterns (values `All=0`, `Missing=1`, `Expired=2`), per [research.md](./research.md) R2 — used by the Create/Edit form (US1/US2)

**Checkpoint**: Enum/entity/DTO/stored-procedure/frontend-enum plumbing is in place — `AlertType` now round-trips through Create/Update and is selectable by the read stored procedures (both the get-by-id path used by Edit and the paging path used by the List). No UI shows it yet. Verified `ComplMasterMappingProfile.cs` and `ComplMasterResponse.cs` need no edits — they map/inherit `AlertType` automatically by name now that T003/T004 have landed.

---

## Phase 3: User Story 1 - Choose Alert Type when creating a Compliance Master (Priority: P1) 🎯 MVP

**Goal**: A user creating a new Compliance Master sees an "Alert type" field (default "All") below Description, can change it, and the chosen value is persisted on save.

**Independent Test**: Open `compliance-master/new`, confirm the field and its default, change it, save, and confirm the persisted value via a reload or the paged list.

### Implementation for User Story 1

- [X] T009 [US1] Add `alertType: 0` to the initial `masterInfo` `useState` object and to the `handleAddNew` reset object, both in `compliance-client/src/presentation/pages/compliance-master/components/ComplianceMasterForm.jsx` (depends on T008)
- [X] T010 [US1] Add an "Alert type" `Select`/`FormControl` directly below the Description `TextField` in the "MASTER INFO" panel of `compliance-client/src/presentation/pages/compliance-master/components/ComplianceMasterForm.jsx`, populated from the `AlertType` options array added in T008, bound to `masterInfo.alertType`, and disabled under the same condition already used for the Valid From/To date fields in the same panel (`masterInfo.isActive && !isRenew`) (depends on T009) — note: Description/Master Name themselves have no `disabled` prop in this form today, so Alert type follows the nearest actually-gated sibling field instead
- [X] T011 [US1] Include `alertType: masterInfo.alertType` in the `payload` object built inside `handleSave` in `compliance-client/src/presentation/pages/compliance-master/components/ComplianceMasterForm.jsx` (depends on T009)
- [ ] T012 [US1] Manually validate Scenario 1 (create with default "All") and Scenario 2 (create with "Missing"/"Expired") from [quickstart.md](./quickstart.md) — **not yet done**: no browser-automation tool was available to click through the Create screen. What WAS verified instead: `dotnet build` of Domain/Application succeeds with the new `AlertType` property/enum; `npm run build` and `eslint` on the changed files are clean; and the redeployed stored procedures were called directly against the dev DB and correctly return `AlertType` as a real numeric value (not the earlier boolean-corrupted one). A human (or a future session with browser access) should still open `compliance-master/new` and click through this scenario before calling US1 fully done

**Checkpoint**: Implementation for User Story 1 is code-complete and builds/lints clean; a manual browser click-through (T012) is still outstanding before calling it fully verified.

---

## Phase 4: User Story 2 - View and change Alert Type when editing an existing Compliance Master (Priority: P2)

**Goal**: Opening an existing Compliance Master shows its saved Alert type (below Description, same field introduced in US1), editable or read-only per the form's existing rules.

**Independent Test**: Open `compliance-master/{id}` for an existing master, confirm the field shows the saved value, change it (if editable) and save, then reload to confirm; separately confirm it is read-only when the form itself is disabled.

### Implementation for User Story 2

- [X] T013 [US2] In the `fetchDetail` effect of `compliance-client/src/presentation/pages/compliance-master/components/ComplianceMasterForm.jsx`, add `alertType: data.alertType ?? 0` to the `setMasterInfo` update so the edit form loads the persisted value (falls back to "All" for pre-existing records per spec FR-007) (depends on T010)
- [ ] T014 [US2] Manually validate Scenario 3 (edit and change Alert type), Scenario 4 (view-only/disabled state shows but doesn't allow editing), and Scenario 5 (pre-existing record with no stored value displays "All") from [quickstart.md](./quickstart.md) — **not yet done**, same browser-access limitation as T012. Needs a human/browser pass on the Edit screen before calling US2 fully done

**Checkpoint**: Implementation for User Story 2 is code-complete and builds/lints clean; a manual browser click-through (T014) is still outstanding before calling it fully verified.

---

## Phase 5: User Story 3 - See each master's Alert type in the list (Priority: P3)

**Goal**: The Compliance Master list shows an "Alert type" column directly after "Status", with the correct label ("All"/"Missing"/"Expired") for every row, visible by default.

**Independent Test**: Open the Compliance Master list, confirm the column's position and that it shows the correct label per row (including "All" as the fallback for rows with no stored value).

### Implementation for User Story 3

- [X] T015 [P] [US3] Add `ALERT_TYPE_LABELS = { 0: 'All', 1: 'Missing', 2: 'Expired' }` to `compliance-client/src/utils/helpers.js`, mirroring the existing `TEMPLATE_STATUS_LABELS`/`REQUIREMENT_LABELS`/`TAKE_FROM_LABELS` convention, per [research.md](./research.md) R9 (depends on Foundational only — independent of T008's `ALERT_TYPE_OPTIONS`, though both live in the same file)
- [X] T016 [US3] In `compliance-client/src/presentation/pages/compliance-master/hooks/useComplianceMasterColumns.jsx`, insert a new column definition (`field: "alertType"`, `headerName: "Alert type"`) immediately after the existing `status` column and before `description`, rendering `ALERT_TYPE_LABELS[row.alertType] ?? ALERT_TYPE_LABELS[0]`; also add `alertType: true` to `defaultColumnVisibility` (depends on T015)
- [ ] T017 [US3] Manually validate Scenario 6 (column appears directly after Status), Scenario 7 (correct label per row — ideally using masters set up via T012/T014's manual passes), and Scenario 8 (pre-existing record without a stored value shows "All") from [quickstart.md](./quickstart.md) — **not yet done**, same browser-access limitation as T012/T014

**Checkpoint**: All three user stories are code-complete; manual browser verification (T012, T014, T017) remains outstanding across all of them.

---

## Phase 6: User Story 4 - Reliably delete a Compliance Master from the list (Priority: P1)

**Goal**: Deleting/bulk-deleting a Compliance Master the list presents as eligible (e.g. `MAS-01104`) succeeds, instead of failing with a generic 500 error — without weakening the `fk_compl_references_master` FK or losing any linked data.

**Independent Test**: Delete `MAS-01104` (or any master with Status "Missing" that already has a linked/mapped compliance) from the Compliance Master list; confirm it succeeds and the master no longer appears on reload. Fully independent of US1/US2/US3 — no shared files, no shared Foundational plumbing (this story does not touch `AlertType` at all).

### Implementation for User Story 4

- [X] T019 [US4] Add `Task DeleteAsync(long id, string userEmail, CancellationToken ct = default)` and `Task DeleteMultiAsync(IEnumerable<long> ids, CancellationToken ct = default)` method signatures to `compliance-sys-api/src/ComplianceSys.Application/Services/Master/IComplMasterCommandService.cs` — note: `DeleteMultiAsync` intentionally has **no** `userEmail` param, to match `IBaseService<,,>.DeleteMultiAsync`'s existing shared signature (see T020 note)
- [X] T020 [US4] Implement `DeleteAsync` in `compliance-sys-api/src/ComplianceSys.Application/Services/Master/ComplMasterCommandService.cs`: begin transaction → `_complMasterBaseRepository.GetByIdAsync(id, ct)` (throw `KeyNotFoundException` if null) → set `existing.IsDelete = 1`, `existing.UpdatedBy = userEmail`, `existing.UpdatedDate = DateTime.UtcNow` → `_complMasterBaseRepository.UpdateAsync(existing, ct)` → `_sideEffectService.AddHistoryAsync(...)` (mirrors `AddAsync`'s existing history call) → commit; this mirrors `ComplCompliancesMutationService.DeleteAsync` exactly (soft delete, not a hard `DELETE`) per [research.md](./research.md) R13 (depends on T019)
- [X] T021 [US4] Implement `DeleteMultiAsync` in the same file: one transaction covering the whole `ids` batch, soft-deleting each existing id the same way as T020 (skip ids that don't exist rather than failing the whole batch, matching the current generic `BaseService.DeleteMultiAsync`'s tolerance), per [research.md](./research.md) R15 (depends on T019, written alongside T020) — **deviation from the original task wording**: since `ComplMasterController.BulkDelete` never extracts `userEmail` from `HttpContext` today (unlike single `Delete`) and the shared `IBaseService.DeleteMultiAsync` contract has no `userEmail` parameter, changing that shared interface was out of scope (would ripple into every other feature built on `BaseService`); `UpdatedBy`/history for the batch path use a `SystemUserEmail = "system"` constant, matching the existing `"system"` fallback convention already used in `ComplReferenceTypesController.cs`/`ComplNotificationController.cs`/etc. for the same "no user context available" situation
- [X] T022 [US4] In `compliance-sys-api/src/ComplianceSys.Application/Services/ComplMasterService.cs`, override `DeleteAsync`/`DeleteMultiAsync` (currently inherited from `BaseService`, which hard-deletes) to delegate to `_commandService.DeleteAsync`/`_commandService.DeleteMultiAsync`, mirroring the existing `AddAsync` override pattern in the same file (depends on T020, T021) — verified: `dotnet build` of `ComplianceSys.Application.csproj` succeeds with 0 errors (pre-existing warnings only, none in the touched files)
- [X] T023 [US4] Create `compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Migration/26_fix_compl_master_delete_soft_delete.sql` containing `DROP PROCEDURE IF EXISTS` + `CREATE PROCEDURE` for `compl_sp_get_compl_master_paging`, `compl_sp_get_compl_master_paging_count`, and `compl_sp_get_compl_master_missing_for_alert`, adding `cd.IsDelete = 0` to each one's `WHERE`/CTE filter, per [research.md](./research.md) R14 and [data-model.md](./data-model.md) (independent of T019-T022) — drafted from `Sqls/Migration/24_...sql`'s bodies (last migration to redefine these procedures); **applied to and verified against the live dev DB** (`compliance_sys_db_260601`) in a follow-up pass: `SHOW CREATE PROCEDURE` on all three confirmed the live definitions matched this migration's assumed base exactly (still `WHERE 1=1`, no `IsDelete` filter) before applying, then the migration was executed and re-verified — see T025
- [X] T024 [P] [US4] Refresh the reference copies `compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Procedures/compl_sp_get_compl_master_paging.sql`, `compl_sp_get_compl_master_paging_count.sql`, and `compl_sp_get_compl_master_missing_for_alert.sql` to match T023 (added `cd.IsDelete = 0`/`WHERE cd.IsDelete = 0` to each; `compl_sp_get_compl_master_paging.sql`'s existing `cd.AlertType` column from the earlier Alert type work was left untouched) (depends on T023)
- [X] T025 [US4] Validate Scenario 9 and part of the Regression check from [quickstart.md](./quickstart.md), directly at the DB layer (a `MySql.Data` scratch console app, not the browser — no UI-automation tool was available): confirmed `compl_masters` `Id=1179` (`MAS-01104`, VersionNo 2) had `IsDelete=1` after the user deleted it via the running app (the C# delete fix works end-to-end in real use); confirmed `CALL compl_sp_get_compl_master_paging(...)` with `page=1, page-size=50` (matching the reported URL) no longer returns it (0 occurrences in 50 rows, `TotalCount` dropped accordingly via `compl_sp_get_compl_master_paging_count`); confirmed `CALL compl_sp_get_compl_master_by_id(1179)` still resolves it (`IsDelete=1`) as intentionally designed (R14). **Still not done**: Scenario 10 (no-linked-data master), Scenario 11 (bulk delete), Scenario 12 (404 on non-existent id), and the `missing_for_alert` exclusion — these need either a full browser pass through the app or further direct DB/API probing, neither done yet

**Checkpoint**: User Story 4's code (T019-T022) and migration/reference-copy files (T023-T024) are complete, the C# side builds clean, **and Migration 26 has now been applied to and verified against the live dev DB** (`compliance_sys_db_260601`) — the originally reported bug (`MAS-01104` reappearing on `compliance-master?page=1&page-size=50` after a reported-successful delete) is confirmed fixed at the data layer. Scenarios 10-12 and the `missing_for_alert` check remain for full end-to-end confidence.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final end-to-end confirmation across all four stories.

- [ ] T018 [P] Run the full [quickstart.md](./quickstart.md) validation pass (Scenarios 1-8), including the Regression check (existing paged list/detail views still load; saving without touching Alert type still succeeds and defaults correctly; sorting/filtering/paging and the Status column are unaffected) — **not yet done**, blocked on the same lack of browser access as T012/T014/T017
- [X] T026 [P] Confirm the `ComplianceMaster.Delete`-gated UI flow (`compliance-master/index.jsx` confirm-delete dialog) requires zero code changes and simply starts succeeding once T019-T024 land — spot-check that no other caller of the generic `IComplMasterService.DeleteAsync`/`DeleteMultiAsync` (search the backend for other usages) was relying on the old hard-delete behavior: confirmed via grep — `ComplMasterController.cs` (lines 350, 389) is the **only** caller of `_complMasterService.DeleteAsync`/`DeleteMultiAsync` anywhere in `compliance-sys-api`; no background jobs, other controllers, or services invoke master deletion, so the fix's blast radius is exactly the two existing endpoints as planned

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately.
- **Foundational (Phase 2)**: Depends on Setup. BLOCKS all three user stories — the enum/entity/DTO/stored-procedure plumbing must exist before any screen can use `alertType`.
- **User Story 1 (Phase 3)**: Depends on Foundational completion only.
- **User Story 2 (Phase 4)**: Depends on Foundational completion **and** on User Story 1's `ComplianceMasterForm.jsx` changes (T009/T010), because Create and Edit share the exact same form component and the same "Alert type" field — Edit's task is purely to populate that already-added field from loaded data. This is a deliberate exception to full story independence, made explicit here rather than pretended away, since both screens are literally one component.
- **User Story 3 (Phase 5)**: Depends on Foundational completion only for its *implementation* (T015/T016 need nothing from US1/US2's frontend work — the list reads the same backend field independently). Its *manual validation* (T017) is easier to do meaningfully once US1/US2 exist, since that's how you'd create masters with non-default Alert types to check against — but this is a testing convenience, not a hard code dependency.
- **User Story 4 (Phase 6)**: **No dependency on Setup/Foundational/US1/US2/US3** — the delete fix touches an entirely different code path (`DeleteAsync`/`DeleteMultiAsync`, unrelated stored procedures) from the `AlertType` work. Can be implemented and shipped independently, in either order relative to US1-3, or in parallel by a different session/developer.
- **Polish (Phase 7)**: Depends on all four user stories being complete.

### Parallel Opportunities

- T002, T003, T004, T008 (different files: backend enum, backend entity, backend request DTO, frontend helpers) can run in parallel.
- T006 and T007 can run in parallel with each other (different files) once T005 is done.
- T009, T010, T011 all touch the same file (`ComplianceMasterForm.jsx`) and must be done sequentially, not in parallel.
- T015 can run in parallel with any Phase 3/4 task (different file, no shared state) once Foundational is done; T016 depends only on T015.
- T023 (stored procedure migration) can run in parallel with T019-T022 (C# service-layer changes) — different layers, no shared files; T024 depends only on T023.
- The entire Phase 6 (User Story 4) can run in parallel with Phases 2-5 (US1/US2/US3) — no shared files or shared Foundational dependency between them.

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (blocks everything)
3. Complete Phase 3: User Story 1 — Create screen has a working, persisted Alert type field
4. **STOP and VALIDATE**: Run Scenario 1/2 from `quickstart.md`
5. This alone is a shippable MVP: new masters can be tagged All/Missing/Expired

### Incremental Delivery

1. Setup + Foundational → plumbing ready, nothing user-visible yet
2. User Story 1 → Create screen complete → validate → this is the MVP
3. User Story 2 → Edit screen complete → validate → full form feature done
4. User Story 3 → List column complete → validate → fully done end to end
5. User Story 4 → delete/bulk-delete fixed → validate → can be delivered before, after, or interleaved with 1-4, since it shares no files or plumbing with them
6. Polish → full quickstart regression pass across all four stories

### Delete Fix Only (User Story 4, if shipped as its own change)

1. Complete Phase 6: T019 → T020/T021 (parallel) → T022 → T023 (parallel with T019-T022) → T024
2. **STOP and VALIDATE**: Run Scenarios 9-12 from `quickstart.md` (T025)
3. Shippable on its own: deleting/bulk-deleting Compliance Masters works reliably, including for masters with linked compliance data

---

## Notes

- No test tasks were generated — the feature spec did not request automated tests, and the existing compliance-master feature has no test suite to extend.
- Total tasks: 26 (1 Setup + 7 Foundational + 4 US1 + 2 US2 + 3 US3 + 6 US4 + 2 Polish). T001-T011, T013, T015-T016 (17 tasks, Alert type) and T019-T026 (8 tasks, delete fix) are done — 25/26; Migration 26 is applied to and verified against the live dev DB. Only T012, T014, T017, T018 (the Alert-type manual browser passes) remain, none available in any session so far (no browser-automation tool). T025's DB-layer verification is done, but a full browser click-through of Scenarios 9-12 is still recommended before calling User Story 4 fully verified end to end.
- Excel import/export, and the read-only `ComplianceMasterDetail.jsx` summary view, are explicitly out of scope per [research.md](./research.md) R6/R7 — no tasks generated for them.
- This spec was merged from two originally separate feature specs (`007-compl-master-alert-type` and `008-compl-master-alerttype-column`); their directories have been removed in favor of this single `007-compl-master` spec. A third, later request (the delete bug reproduced with `MAS-01104`) was folded in as User Story 4 on 2026-08-20, at the requester's direction — see `spec.md` Input and `research.md` R12-R16.
