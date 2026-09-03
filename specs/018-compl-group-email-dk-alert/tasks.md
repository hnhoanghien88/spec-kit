---

description: "Task list for Group Email — Add \"DK Alert\" Type Option"

---

# Tasks: Group Email — Add "DK Alert" Type Option

**Input**: Design documents from `/specs/018-compl-group-email-dk-alert/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/group-email-type.md](./contracts/group-email-type.md), [quickstart.md](./quickstart.md)

**Tests**: Not requested in the feature spec — no automated test tasks are included (no existing automated test suite covers this slice, per `research.md` R6). Validation is manual, via `quickstart.md`.

**Organization**: Tasks are grouped by user story (US1 = Create, P1; US2 = Edit, P2; US3 = Index display, P3) to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Paths are relative to the repository root (`E:\Working\Eutr`)

## Path Conventions

- Backend: `compliance-sys-api/src/ComplianceSys.Application/...`
- Frontend: `compliance-client/src/...`

---

## Phase 1: Setup

**Purpose**: Confirm the environment this feature depends on is ready; no code changes (no schema/migration is needed — see `research.md` R1).

- [X] T001 Confirm local `compliance-sys-api` and `compliance-client` run against a database where `compl_group_email.GroupType` already exists and accepts arbitrary integers (it does today — no DDL change required), and spot-check `SELECT DISTINCT GroupType FROM compl_group_email` to confirm no existing row already uses `3` or `4` with an unrelated meaning, per `research.md` R3 — **partially done**: no DB client was available in this session to run the live query; relied instead on the static migration-history audit already performed in `research.md` R3 (no migration/`INSERT`/`UPDATE` script anywhere writes `GroupType` 3 or 4 into `compl_group_email`, and no UI has ever exposed those values). A human with DB access should still run the `SELECT DISTINCT` spot-check once before/at deployment.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Backend label-mapping and validation, plus the shared frontend options constant, that ALL THREE user stories depend on (Create and Edit both write through the same validator; Create, Edit, and the index list all read the same mapped label after `fetchData()` reloads the list — see `plan.md` Summary).

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T002 [P] In `compliance-sys-api/src/ComplianceSys.Application/Mappings/CommonMappingProfile.cs`, change the `CreateMap<ComplGroupEmail, ComplGroupEmailResponseDto>()` mapping for `GroupTypeName` (currently `src.GroupType == 1 ? "Responsible" : "Alert"`) to a 3-way mapping: `1` → `"Responsible"`, `2` → `"Alert"`, `3` → `"DK Alert"`, per `research.md` R2 and `data-model.md` — implemented as nested ternaries (`src.GroupType == 1 ? "Responsible" : src.GroupType == 3 ? "DK Alert" : "Alert"`), not a `switch` expression: AutoMapper's `MapFrom` builds an expression tree and C# disallows `switch` expressions inside expression trees (`CS8514`), caught by `dotnet build`
- [X] T003 [P] In `compliance-sys-api/src/ComplianceSys.Application/Validators/ComplGroupRequestDtoValidator.cs`, add `RuleFor(x => x.GroupType).Must(v => ValidGroupTypes.Contains(v)).WithMessage(...)` so Create/Update reject any `GroupType` outside `{1, 2, 3}` (value `4` stays intentionally excluded/reserved), per `research.md` R5 and spec FR-006
- [X] T004 [P] In `compliance-client/src/utils/helpers.js`, add `GROUP_EMAIL_TYPE` (`{ RESPONSIBLE: 1, ALERT: 2, DK_ALERT: 3 }`, `Object.freeze`d) and `GROUP_EMAIL_TYPE_OPTIONS` (`[{ value: 1, label: 'Responsible' }, { value: 2, label: 'Alert' }, { value: 3, label: 'DK Alert' }]`), mirroring the existing `ALERT_TYPE`/`ALERT_TYPE_OPTIONS` pattern (feature 007-compl-master), per `research.md` R4

**Checkpoint**: Backend now maps `GroupType == 3` to "DK Alert" and rejects invalid values on save; the shared frontend options list exists. No dropdown shows the new option yet — that's US1/US2.

---

## Phase 3: User Story 1 - Select "DK Alert" when creating a new Group Email (Priority: P1) 🎯 MVP

**Goal**: A user adding a new group email sees "DK Alert" as a third Type option, can select it, and it persists and displays correctly after save.

**Independent Test**: Open the Group Email index screen, start "add new group", open the Type dropdown, confirm 3 options, select "DK Alert", save, and confirm the new row shows Type "DK Alert".

### Implementation for User Story 1

- [X] T005 [US1] In `compliance-client/src/presentation/pages/group-email/components/NewGroupRow.jsx`, replace the hardcoded `<MenuItem value={1}>Responsible</MenuItem>` / `<MenuItem value={2}>Alert</MenuItem>` pair with a `.map()` over the imported `GROUP_EMAIL_TYPE_OPTIONS` (from `@utils/helpers` per this file's existing import style), keeping the existing `<MenuItem value=""><em>Select type</em></MenuItem>` placeholder unchanged (depends on T004)
- [ ] T006 [US1] Manually validate Scenario 1 from [quickstart.md](./quickstart.md): create a group with Type "DK Alert" and confirm it saves and displays correctly on the index list (depends on T002, T003, T005) — **not done**: no running backend+DB+authenticated browser session was available in this environment. Verified instead via `npm run build` (production bundle, including `IndexEmailGroup`, compiles clean) and `eslint` on the changed file. A human should click through this scenario in a real environment before calling US1 fully done.

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently.

---

## Phase 4: User Story 2 - Change an existing Group Email's Type to or from "DK Alert" (Priority: P2)

**Goal**: A user editing an existing group email sees the same 3-option Type dropdown (with the current value pre-selected) and can change it to or away from "DK Alert".

**Independent Test**: Open an existing group row in edit mode, change its Type to "DK Alert", save, confirm the index list reflects it; repeat changing away from "DK Alert".

### Implementation for User Story 2

- [X] T007 [US2] In `compliance-client/src/presentation/pages/group-email/components/GroupRow.jsx`, replace the hardcoded `<MenuItem value={1}>Responsible</MenuItem>` / `<MenuItem value={2}>Alert</MenuItem>` pair in the edit-mode `Select` (bound to `groupEditing.groupType`) with a `.map()` over the imported `GROUP_EMAIL_TYPE_OPTIONS`, keeping the existing `<MenuItem value=""><em>Select type</em></MenuItem>` placeholder unchanged (depends on T004)
- [ ] T008 [US2] Manually validate Scenario 2 from [quickstart.md](./quickstart.md): edit an existing "Responsible"/"Alert" group to "DK Alert" and back, confirming the index list reflects each change (depends on T002, T003, T007) — **not done**, same environment limitation as T006 (no running backend+DB+authenticated browser session). Verified instead via build/lint of the changed file.

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently.

---

## Phase 5: User Story 3 - View "DK Alert" groups on the index screen (Priority: P3)

**Goal**: Groups with Type "DK Alert" show that label clearly (not blank/numeric) in the index list's Type column.

**Independent Test**: With at least one "DK Alert" group present (from US1/US2), reload the index screen and confirm the Type column reads "DK Alert" for it.

### Implementation for User Story 3

- [ ] T009 [US3] Manually validate Scenario 3 from [quickstart.md](./quickstart.md): confirm every group with `groupType == 3` displays "DK Alert" in the index list's Type column — no code change is expected here beyond T002, since `GroupRow.jsx`'s read-only display (`{g.groupTypeName == 0 ? "" : g.groupTypeName}`) already renders whatever label the backend returns (depends on T002, T006, T008) — **not done**, same environment limitation (depends on T006/T008 having produced a live "DK Alert" row to observe).

**Checkpoint**: All three user stories are independently functional — the Group Email index/Add/Edit screen fully supports "DK Alert" end to end.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final verification spanning all stories.

- [ ] T010 [P] Manually validate Scenario 4 (edge case) from [quickstart.md](./quickstart.md): attempt to save a group with an out-of-range `groupType` (e.g. `9`) via a direct API call and confirm it is rejected (depends on T003) — **not done**: no running, authenticated backend instance was available in this session to call `POST /api/group-email` against. The `.Must(v => ValidGroupTypes.Contains(v))` rule added in T003 is a direct, deterministic check (build-verified) that will reject `9`; a human should still confirm the live HTTP behavior (400 response) before deployment.
- [X] T011 [P] Run `dotnet build` on `ComplianceSys.Application` (and dependents) to confirm the backend changes (T002, T003) compile clean — 0 errors (279 pre-existing warnings, unrelated to this change). Note: a full `dotnet build` of the whole solution/`ComplianceSys.Api` failed with file-lock errors (`MSB3027`) because a `ComplianceSys.Api` process was already running locally and holding its output DLLs — unrelated to this feature's code; the `ComplianceSys.Application` project containing the actual changes built cleanly on its own.
- [X] T012 [P] Run the frontend lint/build (`eslint`, `npm run build`) on the changed files (`helpers.js`, `NewGroupRow.jsx`, `GroupRow.jsx`) — `eslint` reported zero errors/warnings on the three files; `npm run build` completed successfully (`IndexEmailGroup.*.js` chunk built with no errors; the pre-existing ">500kB chunk" warning is unrelated to this change)
- [ ] T013 Full end-to-end run-through of [quickstart.md](./quickstart.md) (all 4 scenarios) as a final sign-off — **not done**, blocked on the same missing live backend+DB+browser environment as T006/T008/T009/T010. Recommend a human (or a future session with app/DB access) runs this before/at deployment.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately.
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories.
- **User Stories (Phase 3-5)**: All depend on Foundational phase completion.
  - US1 and US2 touch different files (`NewGroupRow.jsx` vs `GroupRow.jsx`) and can proceed in parallel.
  - US3 has no unique implementation task and only requires US1 or US2 to have produced at least one "DK Alert" row to validate against.
- **Polish (Phase 6)**: Depends on all three user stories being complete.

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) — no dependency on US2/US3.
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) — no dependency on US1's code (different file), though its manual validation is easiest once at least one group exists to edit.
- **User Story 3 (P3)**: Can start after Foundational (Phase 2) — its validation depends on a "DK Alert" row existing, which US1 or US2 produces.

### Parallel Opportunities

- T002, T003, T004 (Foundational) touch three different files and can run in parallel.
- T005 (US1, `NewGroupRow.jsx`) and T007 (US2, `GroupRow.jsx`) touch different files and can run in parallel once T004 is done.
- T010, T011, T012 (Polish) are independent checks and can run in parallel.

---

## Parallel Example: Foundational Phase

```bash
# Launch all Foundational tasks together (different files, no cross-dependencies):
Task: "Extend GroupTypeName mapping in CommonMappingProfile.cs to handle GroupType == 3"
Task: "Add GroupType range validation in ComplGroupRequestDtoValidator.cs"
Task: "Add GROUP_EMAIL_TYPE / GROUP_EMAIL_TYPE_OPTIONS to helpers.js"
```

## Parallel Example: User Stories 1 & 2

```bash
# Once Foundational is done, US1 and US2 can proceed in parallel (different files):
Task: "Update Type Select in NewGroupRow.jsx to use GROUP_EMAIL_TYPE_OPTIONS"
Task: "Update Type Select in GroupRow.jsx (edit mode) to use GROUP_EMAIL_TYPE_OPTIONS"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL — blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Run Scenario 1 from `quickstart.md`
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy/Demo (MVP!)
3. Add User Story 2 → Test independently → Deploy/Demo
4. Add User Story 3 (validation-only) → Deploy/Demo
5. Polish → Final sign-off

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- This feature has no schema/migration work and no new routes — all backend changes are within `ComplianceSys.Application`; all frontend changes are within `presentation/pages/group-email/components` plus `utils/helpers.js`
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
