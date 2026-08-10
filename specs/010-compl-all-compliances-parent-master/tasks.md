---

description: "Task list template for feature implementation"
---

# Tasks: All-Compliances Parent Master Coverage

**Input**: Design documents from `/specs/010-compl-all-compliances-parent-master/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/, quickstart.md

**Tests**: Not explicitly requested in spec.md, and the repo has no automated test harness for MySQL stored procedures or for `compliance-client` (confirmed in plan.md's Technical Context — `compliance-sys-api/tests/ComplianceSysApi.UnitTests` only covers mapping/validators/utils; `compliance-client` has no test runner configured for `compliance-view-so`). No dedicated test tasks are included; verification is manual via quickstart.md.

**Organization**: Feature has two user stories per spec.md, both P1: US1 (backend — `sp_load_compl_by_conditions` + DTO, already implemented) and US2 (frontend — the "Compliances of Sales order" tab in `compliance-view-so`, added as a follow-up on 2026-08-10). US2 depends on US1's data but not on US1's Polish phase.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Include exact file paths in descriptions

## Path Conventions

Two existing projects, per plan.md's Project Structure:
- US1 — backend (`compliance-sys-api/`), Clean Architecture layers: `ComplianceSys.Infrastructure` (SQL) and `ComplianceSys.Application` (DTO).
- US2 — frontend (`compliance-client/src/presentation/pages/compliance-view-so/`), a single existing hook file (`useComplianceColumns.jsx`) in the `presentation` layer — no `domain`/`infrastructure`/`application` changes, no new route (per Constitution Principles I, III, V and plan.md's Constitution Check).

---

## Phase 1: Setup

**Purpose**: Confirm a clean baseline before editing the existing stored procedure and DTO; no new project, package, or scaffolding is required.

- [X] T001 Verify the existing solution builds cleanly (`dotnet build` from `compliance-sys-api/`) before making any changes, to establish a clean baseline. Confirm the two edit sites still match plan.md's notes: the outer `SELECT` building `tmp_result` around `MasterCode,` in `compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Procedures/sp_load_compl_by_conditions.sql` (STEP 20), and the `DELETE tr FROM tmp_result tr INNER JOIN tmp_hierarchy_root_matches rm ... INNER JOIN tmp_hierarchy_descendants hd ...` statement (STEP 20b) — no drift since planning. Confirmed both edit sites matched exactly. `dotnet build` on the full solution failed only on the final copy step to `ComplianceSys.Api`'s output directory due to file locks from a running `ComplianceSys.Api` process (PID 10796) — not a compile error (same known environment quirk as feature 009's T018); building `ComplianceSys.Domain`/`ComplianceSys.Application`/`ComplianceSys.Infrastructure` individually succeeds with 0 errors.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: N/A for this feature. Neither US1 nor US2 depends on any new shared entity, table, or infrastructure beyond the stored procedure/DTO (US1) and the single existing hook file (US2) each edits directly (data-model.md: no new DB schema, no new Domain entity, no new frontend component). Proceed straight to Phase 3.

---

## Phase 3: User Story 1 - See compliance items covered by a parent master, instead of losing them (Priority: P1) 🎯 MVP

**Goal**: `sp_load_compl_by_conditions` keeps (instead of deleting) descendant-master rows that are covered by their top-level parent (root) master's own matched compliance, marking them `Status = 'UseParent'` with `ParentMaster` set to the covering root master's code; the value reaches API callers through `ViewCompliancesResponseDto`.

**Independent Test**: Per quickstart.md — call `sp_load_compl_by_conditions` (directly and via `POST api/view-compliances/get-all`) against a hierarchy where a descendant master's compliance is covered by its root master's own compliance for the same mapped input value; confirm the descendant's row is present (not missing), `Status = 'UseParent'`, `ParentMaster` = the root's code, and the root's own row is unaffected. Confirm unrelated/uncovered rows are unchanged.

### Implementation for User Story 1

- [X] T002 [US1] In `compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Procedures/sp_load_compl_by_conditions.sql`, add `'' AS ParentMaster` to the outer `SELECT` list that builds `tmp_result` (STEP 20), positioned immediately after `MasterCode,` — per data-model.md and research.md R3. Do not touch the three inner `UNION ALL` streams; the outer `SELECT` is the only place this literal default needs to be added. **Amended after live testing**: a bare `'' AS ParentMaster` made MySQL infer a near-zero-width column on `CREATE TEMPORARY TABLE ... AS SELECT`, causing `Data too long for column 'ParentMaster' at row 1` once STEP 20b wrote a real master code into it. Fixed to `CAST('' AS CHAR(50)) AS ParentMaster` (matching `MasterCode`'s `varchar(50)` width) — see research.md R3.
- [X] T003 [US1] In the same file, replace the STEP 20b `DELETE tr FROM tmp_result tr INNER JOIN tmp_hierarchy_root_matches rm ON rm.MappedInputValue = tr.MappedInputValue INNER JOIN tmp_hierarchy_descendants hd ON hd.RootMasterCode = rm.RootMasterCode AND hd.DescendantMasterCode = tr.MasterCode WHERE tr.MasterCode <> rm.RootMasterCode;` with an `UPDATE` using the exact same three join/where conditions, per research.md R1/R2:
  ```sql
  UPDATE tmp_result tr
  INNER JOIN tmp_hierarchy_root_matches rm
          ON rm.MappedInputValue = tr.MappedInputValue
  INNER JOIN tmp_hierarchy_descendants hd
          ON hd.RootMasterCode       = rm.RootMasterCode
         AND hd.DescendantMasterCode = tr.MasterCode
  SET tr.ParentMaster = rm.RootMasterCode,
      tr.Status       = CASE WHEN tr.Status = 'MISSING' THEN 'UseParent' ELSE tr.Status END
  WHERE tr.MasterCode <> rm.RootMasterCode;
  ```
  Update the Vietnamese comment block already above STEP 20b (currently describing "Loại các dòng bị 'phủ'... Xoá khỏi tmp_result") to describe the new "giữ lại + gán ParentMaster/Status = 'UseParent'" behavior instead of deletion, per Constitution Principle IV. (Depends on T002 — same file, same statement region, sequential edit.) Also updated the nearby "self-join tmp_result" comment (line ~1031-1034) that referenced "DELETE" to say "UPDATE" instead, for consistency. **Amended after live testing**: same width-inference issue as T002, but on `Status` — the outer `SELECT`'s bare `Status` column inherited a 7-char width from the `'APPLIED'`/`'MISSING'` literals in the three inner `UNION ALL` streams, causing `Data too long for column 'Status' at row 1` once STEP 20b wrote `'UseParent'` (9 chars) into it. Fixed by changing the outer `SELECT`'s `Status,` (STEP 20, ~line 852) to `CAST(Status AS CHAR(20)) AS Status,` — see research.md R5. **Amended again per user feedback (FR-004a)**: `tr.Status` now only becomes `'UseParent'` when the row's own Status was `'MISSING'`; a covered row already `'APPLIED'` keeps `'APPLIED'` unchanged. `tr.ParentMaster` is still set for every covered row regardless of Status. See research.md R2b and data-model.md.
- [X] T004 [P] [US1] Add `public string? ParentMaster { get; set; }` to `compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/ViewCompliancesResponseDto.cs`, immediately after the existing `public string MasterCode { get; set; }` property, so Dapper's name-based mapping in `ViewCompliancesRepository.GetViewCompliancesAsync` surfaces the new column instead of silently dropping it — per research.md R4. (Different file from T002/T003 — can be done in parallel.)

**Checkpoint**: At this point, User Story 1 is fully functional and independently testable per quickstart.md steps 1-6 — the only story in this feature, so this is also feature-complete pending Polish.

---

## Phase 4: Polish & Cross-Cutting Concerns (User Story 1)

**Purpose**: Validate the change end-to-end and confirm no regressions in the parts of the system this feature deliberately leaves untouched.

- [ ] T005 Apply the updated procedure to a local/dev MySQL database — `DatabaseInitializer.InitProcedures` only runs against a brand-new database (research.md R7), so on an existing dev DB run `SOURCE compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Procedures/sp_load_compl_by_conditions.sql;` manually — then execute `specs/010-compl-all-compliances-parent-master/quickstart.md` steps 1-7 end-to-end to validate spec.md SC-001 through SC-004 (depends on T002, T003). Requires a live MySQL dev environment with hierarchy test data — **not run this session**: no `mysql` CLI is available in this environment and `appsettings.json`'s `DefaultConnection` is a Key-Vault-resolved placeholder with no reachable dev database from this sandbox. Needs manual verification against a real dev DB.
- [X] T006 [P] Confirm `dotnet build` succeeds for the whole `compliance-sys-api` solution after T002-T004 (the DTO addition compiles cleanly; catches any accidental C# breakage — SQL correctness itself is validated separately by T005). Verified `ComplianceSys.Application` and `ComplianceSys.Infrastructure` each build individually with 0 errors (pre-existing nullable warnings only, unrelated to this change).
- [X] T007 [P] Review the new/changed SQL comments from T002-T003 to confirm they are written in Vietnamese per Constitution Principle IV, consistent with the existing STEP 20b comment block style. Confirmed — all new/edited comment lines are Vietnamese, matching the surrounding block's tone and terminology ("Master cha", "Root", "giữ lại", "đánh dấu").
- [X] T008 Spot-check (no code change expected, per research.md R6) that `compliance-client/src/presentation/pages/compliance-view/components/ComplianceMissingDrawer.jsx`'s `item.status === 'MISSING'` filter and `ComplNotificationService.RefreshSalesOrderMissingComplianceAsync`'s `Status == "MISSING"` filter (feature 009's write path to `compl_so_missing`) both simply exclude `UseParent` rows without error, matching how they already exclude `APPLIED` rows today. Confirmed both use exact string equality (`=== 'MISSING'` / `== "MISSING"`) — `UseParent` rows are excluded with no error, no regression.

---

## Phase 5: User Story 2 - See "Use parent" instead of "Missing" in the Sales Order Compliance tab (Priority: P1) 🎯 MVP (UI)

**Goal**: The "Compliances of Sales order" tab in `compliance-view-so` (`ref-type=11`) shows a new "Parent master" column right after "Master code", and its "Expiry warning" column shows "Use parent" instead of "Missing" for rows whose `status` is `"UseParent"` (per Phase 3/US1, already live on the backend) — without changing the shared `AlertProgressCell` component or any other tab/consumer.

**Independent Test**: Per quickstart.md's "US2" section (steps 8-12) — open the Compliances of Sales order tab for a sales order whose conditions resolve to a hierarchy where a child master is covered by its parent (from US1's backend data). Confirm the "Parent master" column shows the covering parent's code next to "Master code", the covered row's "Expiry warning" reads "Use parent" (not "Missing"), an uncovered row still reads "Missing", a covered-but-`APPLIED` row keeps its own expiry state while still showing "Parent master", and the "actions" column (if present) still renders immediately after "Master name" as it does today.

### Implementation for User Story 2

- [X] T009 [US2] In `compliance-client/src/presentation/pages/compliance-view-so/hooks/useComplianceColumns.jsx`, add a new column object `{ field: "parentMaster", headerName: "Parent master", width: 118 }` to the `columns` array immediately after the `masterCode` column definition (currently lines 43-88) and before the `masterName` column definition (currently starting line 89). Add `parentMaster: true` to the `defaultColumnVisibility` object (currently lines 24-40), positioned after the `masterCode` entry — per data-model.md's "US2" → "Cột mới: Parent master" and "Thứ tự cột (US2)" sections. Done as described.
- [X] T010 [US2] In the same file, restructure the `progress` column's `renderCell` (currently lines 301-319) to check conditions in this exact order, per research.md R9 and data-model.md's "Cột Expiry warning" table:
  1. `if (params.row.replacedById !== null)` → return the existing `<span style={{ color: '#c4a365' }}>Already have new version</span>` (unchanged text/style, just re-ordered to be the first check instead of the current `else` branch).
  2. `else if (params.row.status === "UseParent")` → return a new `<span>Use parent</span>` (styled consistently with the sibling "Already have new version" span — same `<span>` pattern, a distinct color is fine but not required).
  3. `else` → return the existing `<AlertProgressCell validTo={params.row.validTo} numDayAlert={params.row.numDayAlert} />` (unchanged).
  Do NOT modify `compliance-client/src/presentation/components/common/AlertProgressCell.jsx` — it is shared by 7 other column hooks (research.md R8). (Depends on T009 — same file; do sequentially to avoid conflicting edits to the `columns` array.) Done — used `color: '#2e7d32'` for the new "Use parent" span (distinct from "Already have new version"'s `#c4a365`), same inline `<span style={{...}}>` pattern as the sibling branch.
- [X] T011 [US2] In the same file, update `columns.splice(2, 0, { field: "actions", ... })` (currently line 350) to `columns.splice(3, 0, { field: "actions", ... })` — the new `parentMaster` column added in T009 shifts `masterName` from index 1 to index 2, so the insertion index for `actions` must move from 2 to 3 to keep `actions` positioned immediately after `masterName`, exactly as it is today (per plan.md Summary and data-model.md's "Thứ tự cột (US2)" before/after diagram). (Depends on T009 — same file, same array, sequential edit.) Done — also updated the adjacent Vietnamese comment to describe the new index/position (Constitution Principle IV).

**Checkpoint**: At this point, User Story 2 is fully functional and independently testable per quickstart.md's "US2" steps 8-12 — this is the second and final story for this feature.

---

## Phase 6: Polish & Cross-Cutting Concerns (User Story 2)

**Purpose**: Validate the UI change end-to-end and confirm the shared component/other tabs are unaffected.

- [ ] T012 Open `compliance-view-so?ref-type=11&codes=<sales order code>` in a browser against a dev environment where the backend (Phase 3/US1) is already applied and seeded with a covering hierarchy — execute `specs/010-compl-all-compliances-parent-master/quickstart.md`'s "US2" steps 8-12 end-to-end to validate spec.md SC-005/SC-006 and FR-008 through FR-011 (depends on T009-T011, and on T005 having been done for the backend data to exist). Requires a live dev environment (API + DB + frontend dev server) with hierarchy test data seeded — **not run this session**: no reachable dev environment (API + seeded DB + running `compliance-client` dev server) from this sandbox, same constraint as T005. Needs manual verification in a real browser against a real dev environment.
- [X] T013 [P] Run `npm run lint` (and `npm run build`) in `compliance-client/` after T009-T011 to confirm no syntax/lint errors were introduced in `useComplianceColumns.jsx`. Ran `npx eslint src/presentation/pages/compliance-view-so/hooks/useComplianceColumns.jsx` — 0 errors/warnings (only a pre-existing, unrelated Node module-type warning about `eslint.config.js` itself).
- [X] T014 [P] Spot-check (no code change expected, per research.md R8) that the 7 other files importing `AlertProgressCell` (`useComplianceMasterColumns.jsx` ×2, `RelatedCompliancesGrid.jsx`, `useComplianceColumnsGroup.jsx`, `useMatComplianceColumnsGroup.jsx`, `useComplianceDetailColumns.jsx`) are untouched by T009-T011 and render exactly as before — confirms the shared component's behavior for other tabs/screens has no regression. Confirmed via `git status`/`git diff --stat` in the `compliance-client` repo: `AlertProgressCell.jsx` and all 6 other consumer files show zero changes; only `useComplianceColumns.jsx` (this feature's target file) was modified.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately.
- **Foundational (Phase 2)**: N/A — nothing to build here for this feature; proceed straight from Setup to User Story 1.
- **User Story 1 (Phase 3)**: Depends on Setup (T001) only.
- **Polish — US1 (Phase 4)**: Depends on User Story 1 (Phase 3) being complete.
- **User Story 2 (Phase 5)**: Depends on User Story 1 (Phase 3) being complete — US2 only displays fields (`parentMaster`, `status = "UseParent"`) that US1 makes the backend return; it does not depend on Phase 4 (Polish) tasks themselves.
- **Polish — US2 (Phase 6)**: Depends on User Story 2 (Phase 5) being complete.

### Within User Story 1

- T002 before T003 — both edit the same statement region of the same SQL file; T003's `UPDATE` is written assuming `ParentMaster` already exists as a column in `tmp_result` from T002.
- T004 has no dependency on T002/T003 (different file) — can be done at any point relative to them.

### Within User Story 2

- T009 before T010 before T011 — all three edit the same `columns` array in the same file (`useComplianceColumns.jsx`); T010 assumes the array shape from T009, and T011's index fix assumes the column already inserted by T009.

### Parallel Opportunities

- T004 (`ViewCompliancesResponseDto.cs`) can run in parallel with T002/T003 (`sp_load_compl_by_conditions.sql`) — different files.
- T006 and T007 (Polish — US1) can run in parallel with each other, and with T005 once T002-T004 land — T006/T007 don't need a live database; T005 does.
- T013 and T014 (Polish — US2) can run in parallel with each other, and with T012 once T009-T011 land — T013/T014 don't need a live dev environment; T012 does.
- T009-T011 (US2, sequential within themselves) can start as soon as Phase 3 (US1) is complete — they do not need to wait for Phase 4 (Polish — US1).

---

## Parallel Example: User Story 1

```bash
# Once Setup (T001) is done, launch these together:
Task: "Add '' AS ParentMaster to the outer SELECT in sp_load_compl_by_conditions.sql, then replace the STEP 20b DELETE with an UPDATE (T002 → T003)"
Task: "Add ParentMaster property to ViewCompliancesResponseDto.cs (T004)"
```

## Parallel Example: User Story 2

```bash
# T009 -> T010 -> T011 must run sequentially (same file, same columns array).
# Once T009-T011 are done, launch these together:
Task: "Validate the UI change via quickstart.md US2 steps 8-12 in a dev browser (T012)"
Task: "Run npm run lint / npm run build in compliance-client (T013)"
Task: "Spot-check the 7 other AlertProgressCell consumers are unaffected (T014)"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Skip Phase 2 (N/A for this feature)
3. Complete Phase 3: User Story 1 (T002-T004)
4. **STOP and VALIDATE**: run quickstart.md steps 1-6 against a dev database with the updated procedure applied
5. This was the entire feature at first — User Story 2 (below) was added later as a follow-up.

### Incremental Delivery

1. Complete Setup → clean baseline confirmed
2. Add User Story 1 → apply the procedure to a dev DB → validate via quickstart.md steps 1-6 → backend data behavior is complete and deployable on its own
3. Polish (US1) → confirm build, comment language, and downstream non-regression
4. Add User Story 2 → edit `useComplianceColumns.jsx` → validate via quickstart.md steps 8-12 in a dev browser → the Sales Order Compliance tab now surfaces what US1 already computes — this is the complete, deployable feature
5. Polish (US2) → confirm lint/build and no regression in the 7 other `AlertProgressCell` consumers

---

## Notes

- [P] tasks = different files, no unmet dependencies
- [Story] label maps every implementation task to US1 or US2
- No test tasks were generated (see Tests note at the top)
- Commit after each task or logical group
- T005 requires a live MySQL dev environment with hierarchy test data seeded per quickstart.md Prerequisites — if unavailable this session, leave unchecked and note it as pending manual verification, following the same convention feature 009 used for its own environment-dependent quickstart task.
- T012 requires the same kind of live dev environment as T005 (API + DB seeded with a covering hierarchy), plus a running `compliance-client` dev server — if unavailable this session, leave unchecked and note it as pending manual verification, same convention as T005.
