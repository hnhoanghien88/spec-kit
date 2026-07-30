---

description: "Task list for Compliance Master Alert Type"

---

# Tasks: Compliance Master Alert Type

**Input**: Design documents from `/specs/007-compl-master/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/compliance-master-alerttype.md](./contracts/compliance-master-alerttype.md), [quickstart.md](./quickstart.md)

**Tests**: Not requested in the feature spec — no automated test tasks are included. Validation is manual, via `quickstart.md`.

**Organization**: Tasks are grouped by user story (US1 = Create, P1; US2 = Edit, P2; US3 = List column, P3) to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
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

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final end-to-end confirmation across all three stories.

- [ ] T018 [P] Run the full [quickstart.md](./quickstart.md) validation pass (all 8 scenarios), including the Regression check (existing paged list/detail views still load; saving without touching Alert type still succeeds and defaults correctly; sorting/filtering/paging and the Status column are unaffected) — **not yet done**, blocked on the same lack of browser access as T012/T014/T017

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately.
- **Foundational (Phase 2)**: Depends on Setup. BLOCKS all three user stories — the enum/entity/DTO/stored-procedure plumbing must exist before any screen can use `alertType`.
- **User Story 1 (Phase 3)**: Depends on Foundational completion only.
- **User Story 2 (Phase 4)**: Depends on Foundational completion **and** on User Story 1's `ComplianceMasterForm.jsx` changes (T009/T010), because Create and Edit share the exact same form component and the same "Alert type" field — Edit's task is purely to populate that already-added field from loaded data. This is a deliberate exception to full story independence, made explicit here rather than pretended away, since both screens are literally one component.
- **User Story 3 (Phase 5)**: Depends on Foundational completion only for its *implementation* (T015/T016 need nothing from US1/US2's frontend work — the list reads the same backend field independently). Its *manual validation* (T017) is easier to do meaningfully once US1/US2 exist, since that's how you'd create masters with non-default Alert types to check against — but this is a testing convenience, not a hard code dependency.
- **Polish (Phase 6)**: Depends on all three user stories being complete.

### Parallel Opportunities

- T002, T003, T004, T008 (different files: backend enum, backend entity, backend request DTO, frontend helpers) can run in parallel.
- T006 and T007 can run in parallel with each other (different files) once T005 is done.
- T009, T010, T011 all touch the same file (`ComplianceMasterForm.jsx`) and must be done sequentially, not in parallel.
- T015 can run in parallel with any Phase 3/4 task (different file, no shared state) once Foundational is done; T016 depends only on T015.

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
5. Polish → full quickstart regression pass across all three stories

---

## Notes

- No test tasks were generated — the feature spec did not request automated tests, and the existing compliance-master feature has no test suite to extend.
- Total tasks: 18 (1 Setup + 7 Foundational + 4 US1 + 2 US2 + 3 US3 + 1 Polish). 17 are code/build-verified done (T001-T011, T013, T015-T016); only T012, T014, T017, T018 remain — all four are manual browser click-throughs (no browser-automation tool was available in any session so far), not implementation work.
- Excel import/export, and the read-only `ComplianceMasterDetail.jsx` summary view, are explicitly out of scope per [research.md](./research.md) R6/R7 — no tasks generated for them.
- This spec was merged from two originally separate feature specs (`007-compl-master-alert-type` and `008-compl-master-alerttype-column`); their directories have been removed in favor of this single `007-compl-master` spec.
