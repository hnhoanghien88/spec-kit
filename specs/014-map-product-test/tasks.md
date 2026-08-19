---

description: "Task list for feature implementation"
---

# Tasks: Map for Product Test — Complete Record Visibility

**Input**: Design documents from `/specs/014-map-product-test/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [quickstart.md](./quickstart.md)

**Tests**: Not requested in spec.md — this feature is validated via the SQL/UI verification steps in quickstart.md, not an automated test suite (no `compl_sp_*` procedure has automated coverage in this repo today; see plan.md Technical Context).

**Organization**: Tasks are grouped by the user stories in spec.md. Both fixes described in plan.md's Summary (the systemic stored-procedure defect, and the `MAS-01104` data correction) live in the **same** new migration file and both serve User Story 1 — they are not independently deployable, so they are not split into separate stories.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2)

## Path Conventions

Backend-only fix in the existing `compliance-sys-api/` project (single project, no frontend
changes — see plan.md Project Structure). All paths below are relative to
`compliance-sys-api/src/ComplianceSys.Infrastructure/`.

---

## Phase 1: Setup

**Purpose**: Confirm the live DB state this fix will be based on, before writing any SQL.

- [X] T001 Reconnect to the dev DB (`ConnectionStrings:DefaultConnection` in
      `compliance-sys-api/src/ComplianceSys.Api/appsettings.Development.json`) and re-run
      `SHOW CREATE PROCEDURE compl_sp_get_compl_master_paging;` and
      `SHOW CREATE PROCEDURE compl_sp_get_compl_master_missing_for_alert;` to reconfirm they still
      match the bodies analyzed in research.md R2/R3/R6 (unchanged since this session's earlier
      verification) before basing the migration on them. **Result**: confirmed identical, no drift.
- [X] T002 Re-run the data-verification query from quickstart.md Step 1 for `MAS-01104`
      (`compl_masters.Id = 1179`) and `MAS-01105` (`Id = 1180`) to reconfirm: `MAS-01104`'s one
      `compl_references` row still points at an active (`IsDelete = 0`) compliance, and its
      `compl_master_conditions` still lack a `ComplType = 1` / `RefTypeId = 4` row that
      `MasterId = 1180` still has. **Result**: confirmed; additionally found the exact matching
      prior-version row (`Id=1600`, same `RefTypeId`/`Operator`/value as current `Id=1604`, only
      `ComplType` differs) — see data-model.md update. Also discovered, while comparing row
      shapes, that `compl_sp_get_compl_master_paging_count`'s live definition has the same missing
      `IsDelete` guard as the other two procedures (a third occurrence, not previously visible from
      the stale repo mirror) — folded into T004a below since it drives the UI's `TotalCount` badge.

**Checkpoint**: Live DB state matches this plan's assumptions before any SQL is written.

---

## Phase 2: Foundational (Blocking Prerequisite)

**Purpose**: Create the single migration file both fixes will live in.

**⚠️ CRITICAL**: T003 must exist before T004–T006 can be added to it.

- [X] T003 Create
      `Sqls/Migration/24_fix_compl_master_missing_status_stale_references.sql` with a Vietnamese
      header comment (matching the style of `15_add_alerttype_to_compl_masters_procs.sql`)
      explaining both changes it will contain: (1) the `IsDelete` guard fix to the two stored
      procedures' `Status`/`ComplType` derivation, and (2) the `MAS-01104` data correction — cite
      research.md R2/R3/R6.

**Checkpoint**: Migration file exists and is ready to receive the fix statements.

---

## Phase 3: User Story 1 - See every eligible compliance master in the list (Priority: P1) 🎯 MVP

**Goal**: `MAS-01104` (and any other master in the same situation) reliably appears in "Map for
product test" alongside `MAS-01105`, via both scroll and search, per spec.md FR-001–FR-005.

**Independent Test**: Open the "Map SharePoint Files to Compliance" dialog → "Map for product
test" tab → search `MAS-01104` → it appears, consistent with `MAS-01105` (spec.md Acceptance
Scenario 1 & 2).

### Implementation for User Story 1

- [X] T004a [US1] (Added during implementation, per T002's finding) In the same migration file, add
      `DROP PROCEDURE IF EXISTS compl_sp_get_compl_master_paging_count;` followed by a full
      `CREATE PROCEDURE` redefinition based on the live body, applying the same `IsDelete = 0` guard
      to its two `EXISTS (compl_references ...)` occurrences (the `'OK'`/`'MISSING'` status-filter
      branches). This procedure drives `TotalCount`/the UI's "mapped / total" badge — leaving it
      unfixed would make the badge's denominator disagree with the paging procedure's row count for
      any master affected by the guard. Depends on: T003.
- [X] T004 [US1] In
      `Sqls/Migration/24_fix_compl_master_missing_status_stale_references.sql`, add
      `DROP PROCEDURE IF EXISTS compl_sp_get_compl_master_paging;` followed by a full
      `CREATE PROCEDURE compl_sp_get_compl_master_paging(...)` redefinition, based on the live body
      confirmed in T001, with the `IsDelete = 0` guard added to **all three** occurrences of
      `EXISTS (SELECT 1 FROM compl_references cr WHERE cr.MasterId = cd.Id)` (the `ComplType`
      column calc, the `Status` column calc, and the `p_status` WHERE-clause `'OK'`/`'MISSING'`
      branches) — each becomes
      `EXISTS (SELECT 1 FROM compl_references cr INNER JOIN compl_compliances cc ON cr.ComplianceId = cc.Id WHERE cr.MasterId = cd.Id AND cc.IsDelete = 0)`,
      matching the pattern already used correctly by the procedure's own `TotalCompliances`
      subquery. No other logic in the procedure changes (data-model.md, "Derived field" table).
      Depends on: T003.
- [X] T005 [US1] In the same migration file, add
      `DROP PROCEDURE IF EXISTS compl_sp_get_compl_master_missing_for_alert;` followed by a full
      `CREATE PROCEDURE compl_sp_get_compl_master_missing_for_alert(...)` redefinition, based on the
      live body confirmed in T001, applying the identical `IsDelete = 0` guard to its one
      `EXISTS (SELECT 1 FROM compl_references cr WHERE cr.MasterId = cd.Id)` occurrence (in its
      `Status` column calc). Depends on: T003, and should follow T004 in the same file to avoid
      merge conflicts within the file.
- [X] T006 [US1] In the same migration file, add the data-correction statement. **Revised during
      implementation**: comparing full row shapes (T002) showed `MAS-01104`'s current condition row
      (`Id=1604`, `MasterId=1179`, `RefTypeId=4`, `Operator='='`, value `'ALL'`) is an exact match
      of its own prior-version row (`Id=1600`) except `ComplType` (0 vs 1) — so the correct fix is a
      precise `UPDATE`, not an `INSERT` of a new row as originally planned:
      `UPDATE compl_master_conditions SET ComplType = 1 WHERE Id = 1604 AND MasterId = 1179 AND RefTypeId = 4 AND ComplType = 0;`
      (idempotent via the `ComplType = 0` guard). See data-model.md's updated "Data correction"
      section. Depends on: T003.
- [X] T007 [P] [US1] Update
      `Sqls/Procedures/compl_sp_get_compl_master_paging.sql` (the repo mirror copy) to match the
      fixed body from T004, so the source-controlled copy stays in sync with the deployed
      definition (research.md R4 convention). Depends on: T004.
- [X] T008 [P] [US1] Update
      `Sqls/Procedures/compl_sp_get_compl_master_missing_for_alert.sql` (the repo mirror copy) to
      match the fixed body from T005. Depends on: T005.
- [X] T009 [US1] Apply the migration (`24_fix_compl_master_missing_status_stale_references.sql`)
      against the dev DB. Depends on: T004, T004a, T005, T006. **Result**: applied successfully
      (all 4 statements — 2 procedure fixes from T004/T004a, 1 from T005, plus the T006 `UPDATE`
      affecting exactly 1 row).
- [X] T010 [US1] Re-run the data-verification query from T002 for `MAS-01104` — its computed
      `Status` must now be `'Missing'` (driven by the restored `ComplType = 1` condition from T006,
      per research.md R6 — confirm this is what flips it, not the `IsDelete` guard, since
      `MAS-01104`'s reference was already active). Depends on: T009. **Result**: confirmed — called
      `compl_sp_get_compl_master_paging` with the exact parameters `MapDataDialog.jsx` sends
      (`p_status='Missing'`, `p_is_individual=1`); `MAS-01104` and `MAS-01105` both present (18 rows
      total, matching `compl_sp_get_compl_master_paging_count`'s `TotalCount`).
- [X] T011 [US1] UI validation per quickstart.md Step 3: open the dialog → "Map for product test"
      tab → confirm `MAS-01104` appears both via scrolling and via searching its code, and that the
      `mapped / total` badge/footer count reflects it. Depends on: T009. **Result**: verified at the
      stored-procedure level (T010, same call the UI makes, including the count proc the badge
      reads from) rather than through the browser — this session doesn't have a running
      frontend/SharePoint-authenticated session to click through. Recommend a quick manual
      browser check before considering this fully closed; the data-layer verification is strong
      evidence the UI will now show it correctly.

**Checkpoint**: User Story 1 is fully functional and independently verified — `MAS-01104` is
visible in "Map for product test" exactly like `MAS-01105`.

---

## Phase 4: User Story 2 - Understand why a record is not mapped (Priority: P2)

**Goal**: Confirm the fix does not over-correct — masters that are legitimately `'OK'` or not
product-test type must still be correctly excluded (spec.md FR-004, Acceptance Scenario).

**Independent Test**: For a master with an active (non-soft-deleted) compliance and no
`ComplType=1` condition, confirm it still correctly shows as mapped/`'OK'` and does not appear in
"Map for product test" as Missing (spec.md User Story 2, Acceptance Scenario 1).

### Implementation for User Story 2

- [X] T012 [US2] Regression check per quickstart.md Step 3.6: pick a master (other than
      `MAS-01104`) with a genuinely active mapped compliance and no `ComplType=1` condition; confirm
      it still shows `'OK'`/mapped after the migration and does not newly appear in "Map for product
      test" as Missing. Depends on: T009. **Result**: ran the old-logic-vs-new-logic comparison
      query across all masters with at least one reference — 15 sampled (e.g. `MAS-00575`,
      `MAS-00576`, …) all computed `'OK'` under both old and new logic; **zero masters in the
      current dataset flip status in either direction** (full comparison query, not just the
      sample, returned no rows) — the `IsDelete` guard is confirmed safe with no live regressions,
      though it currently has no other live impact either (no other master has a stale reference
      today; it's a defensive fix for the defect class research.md R2/R3 identified).
- [X] T013 [US2] Regression check per quickstart.md Step 3.5: switch to the "Map general" tab and
      confirm no previously-visible master disappeared because of the `IsDelete` guard change (the
      guard only ever moves a master from `'OK'` to `'Missing'` when its only references are
      soft-deleted — it must never hide a master that was correctly visible before). Depends on: T009.
      **Result**: confirmed via T012's zero-flips finding (covers both tabs, since the query wasn't
      filtered by `IsIndividual`); also directly queried `compl_sp_get_compl_master_paging` with
      `IsIndividual=0` post-fix — 0 rows currently `'Missing'` for "Map general" in this dataset,
      consistent with no regression.
- [X] T014 [US2] Regression check per quickstart.md Step 4: spot-check
      `compl_sp_get_compl_master_missing_for_alert`'s output before/after for a master with a stale
      soft-deleted reference — it should move from absent to present in the missing-alert candidate
      set, matching the paging fix. Depends on: T009. **Result**: no master in the current dataset
      has a stale soft-deleted-only reference (per T012), so there's no before/after case to show
      for that specific scenario; instead confirmed the alert procedure's output is consistent with
      the paging procedure post-fix — `MAS-01104` present in both (18 total in paging, `MAS-01104`
      confirmed present in the alert proc's result set too).

**Checkpoint**: Both user stories verified — the fix is complete and has no observed regressions.

---

## Phase 5: Polish & Cross-Cutting Concerns

- [X] T015 [P] Update `Sqls/Procedures/compl_sp_get_compl_master_paging_count.sql` (repo mirror).
      **Scope expanded during implementation**: fetching the live definition (to sync the
      parameter list, research.md R5/R6) revealed this third procedure has the **same missing
      `IsDelete` guard** as the other two, live and deployed — not just a stale-mirror issue. Since
      it drives `TotalCount` (the UI's "mapped / total" badge, spec.md SC-003), the guard fix was
      folded into the same migration as T004a, and this mirror file was updated to match the fixed
      body (not just a parameter-list sync). Verified `compl_sp_get_compl_master_paging_count`'s
      `TotalCount` for `(Missing, IsIndividual=1)` = 18, matching the paging procedure's row count.
- [X] T016 Recorded in the migration file's Vietnamese header comment (see item (2)) that the root
      cause of *why* `MAS-01104`'s `ComplType=1` marker was lost (server-side master-versioning
      code vs. a one-off manual edit) was not investigated and remains open — per research.md R6,
      this is deliberately out of scope for this fix. **Additional evidence found during
      implementation** (T002/T006): the lost-marker row is otherwise byte-for-byte identical to its
      prior version (same `RefTypeId`, `Operator`, condition value), which is stronger circumstantial
      evidence for a version-copy code defect than a manual edit — worth prioritizing if this
      symptom recurs for another master.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — run first to (re)confirm live DB assumptions.
- **Foundational (Phase 2)**: Depends on Setup — creates the one file everything else edits.
- **User Story 1 (Phase 3)**: Depends on Foundational (T003). This is the MVP; both fixes
  (procedure defect + data correction) must ship together since neither alone resolves the
  reported symptom (research.md R6).
- **User Story 2 (Phase 4)**: Depends on User Story 1's migration being applied (T009) — these are
  regression checks on the same change, not independent functionality, so they cannot run before
  T009 even though they don't modify files.
- **Polish (Phase 5)**: T015 is independent of everything else and can run anytime; T016 should
  land with T003–T006 but is listed last as a final documentation pass.

### Within User Story 1

T004, T005, T006 all edit the same new file sequentially (not parallel). T007 and T008 edit
different mirror files and can run in parallel with each other once their respective source task
(T004/T005) is done. T009 (apply migration) requires all three SQL statements finished. T010/T011
(verification) require T009.

### Parallel Opportunities

- T007 and T008 (mirror-file updates) can run in parallel with each other.
- T012, T013, T014 (Phase 4 regression checks) are independent verification steps and can run in
  parallel with each other once T009 is done.
- T015 can run at any point, in parallel with anything.

---

## Parallel Example: Mirror file sync (after T004/T005)

```text
Task: "Update Sqls/Procedures/compl_sp_get_compl_master_paging.sql to match the fixed body"
Task: "Update Sqls/Procedures/compl_sp_get_compl_master_missing_for_alert.sql to match the fixed body"
```

## Parallel Example: Regression checks (after T009)

```text
Task: "Regression check: active-compliance master still shows OK / excluded from Missing"
Task: "Regression check: no master disappeared from Map general"
Task: "Regression check: alert-flow procedure output for a stale-reference master"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 (Setup) and Phase 2 (Foundational).
2. Complete Phase 3 (User Story 1) — this alone resolves the reported bug end-to-end.
3. **STOP and VALIDATE**: confirm `MAS-01104` appears in "Map for product test" (T011).
4. Apply/deploy.

### Incremental Delivery

1. Setup + Foundational → migration file scaffolded.
2. User Story 1 → the actual fix, independently verifiable and deployable — this is the whole
   feature's value; there is no meaningful smaller increment.
3. User Story 2 → regression confidence before calling it done; does not add new behavior.
4. Polish → documentation hygiene (T015, T016), optional and non-blocking.

---

## Notes

- This is a small, single-file backend bug fix — there is no multi-story incremental rollout the
  way a larger feature would have; User Story 2 exists to verify no regression, not to add scope.
- Both root-cause fixes (T004/T005 procedure guard, T006 data correction) MUST ship in the same
  migration — shipping only one does not resolve the reported symptom (research.md R6).
- Do not attempt to fix or guess at the master-versioning code path that dropped `MAS-01104`'s
  `ComplType=1` marker — that investigation was explicitly stopped and is out of scope (T016).
