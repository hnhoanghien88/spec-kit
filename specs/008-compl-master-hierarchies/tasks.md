---

description: "Task list for Compliance Master Hierarchies"
---

# Tasks: Compliance Master Hierarchies

**Input**: Design documents from `/specs/008-compl-master-hierarchies/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/compl-master-hierarchies-api.md, quickstart.md

**Tests**: Not requested in the spec (repo has no automated test framework for similar CRUD screens — see plan.md Technical Context "Testing"). Verification is manual, via `quickstart.md`.

**Organization**: Tasks are grouped by user story (US1-US6 — priorities P1, P2, P3, P4, P3, P4 respectively, from spec.md) so each can be implemented and demoed independently. US5 (drag-and-drop) was added in a spec update after US1-US4 were already implemented (see Phase 7 below); it reuses the cycle-check graph logic from US2 (T037) and the duplicate-root check from US1 (T026), so build it after those two even though nothing structurally forces the order. **T080-T081 (Code/Name search textbox, FR-025-027) were added in a later spec update, after US1-US5 were already fully implemented** — they extend `MasterPickerDialog.jsx` (originally built in US1/T032) and are appended to the end of Phase 3 (US1) since that is where FR-025-027 live in spec.md; the search is shared by both Add root and Add child, but the component itself is owned by US1. **US6 (T082-T083, View condition on each tree row, FR-028-030) was added in a later spec update (2026-08-10), after US1-US5 and the search textbox were already fully implemented** — it is frontend-only, touching only `ComplMasterHierarchiesPage.jsx`, and reuses the same `GetConditionsByMasterIdUseCase`/`ConditionsView` pair already wired into `MasterPickerDialog.jsx` for US4 (see Phase 9 below, plan.md, research.md §11).

## Path Conventions

- Backend: `compliance-sys-api/src/ComplianceSys.{Domain,Application,Infrastructure,Api}/...`
- Frontend: `compliance-client/src/{domain,infrastructure,application,presentation}/...`

## Phase 1: Setup

**Purpose**: Database schema files (no code depends on these yet, but they must exist before any repository/service work is meaningfully testable against a real DB)

- [x] T001 [P] Create table DDL `compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Tables/compl_master_hierarchies.sql` per data-model.md (`Id`, `MasterCode`, `ParentCode` default `''`, `DisplayOrder`, audit columns, `UNIQUE(MasterCode, ParentCode)`, `KEY` on `ParentCode`) — auto-applied on fresh installs by `DatabaseInitializer.InitTables()`
- [x] T002 [P] Create manual-apply migration `compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Migration/16_create_compl_master_hierarchies.sql` with the same `CREATE TABLE IF NOT EXISTS` DDL as T001, for already-existing dev/prod databases

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Backend read path (Domain → Repository → Service.GetTreeAsync → GET endpoint) and frontend page shell that every user story builds on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T003 Create `ComplMasterHierarchy` domain entity in `compliance-sys-api/src/ComplianceSys.Domain/Entities/ComplMasterHierarchy.cs` (`[Table("compl_master_hierarchies")] : BaseEntity`, `Id`/`MasterCode`/`ParentCode` (default `""`)/`DisplayOrder`)
- [x] T004 [P] Create `ComplMasterHierarchyResponseDto` in `compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/ComplMasterHierarchyResponseDto.cs` (`: ComplMasterHierarchy` + `Name`, `Description`)
- [x] T005 [P] Create `IComplMasterHierarchyRepository` in `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Repositories/IComplMasterHierarchyRepository.cs` — extends `IRepository<ComplMasterHierarchy, long>`, adds `GetAllWithMasterInfoAsync()`, `ExistsAsync(masterCode, parentCode)`, `GetMaxDisplayOrderAsync(parentCode)`, `GetSiblingsAsync(parentCode)`
- [x] T006 Implement `ComplMasterHierarchyRepository : DapperRepository<ComplMasterHierarchy, long>` in `compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/ComplMasterHierarchyRepository.cs`, implementing all T005 methods (the `GetAllWithMasterInfoAsync` query per data-model.md, joining latest-version `compl_masters` for `Name`/`Description`) (depends on T003, T005)
- [x] T007 [P] Create `IComplMasterHierarchyService` in `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Services/IComplMasterHierarchyService.cs` declaring `GetTreeAsync()`, `AddRootsAsync(masterCodes, userEmail)`, `AddChildrenAsync(parentCode, masterCodes, userEmail)`, `MoveAsync(id, direction, userEmail)`, `DeleteWithDescendantsAsync(id, userEmail)` (bodies for all but `GetTreeAsync` are filled in by later story phases)
- [x] T008 Create `ComplMasterHierarchyService` class in `compliance-sys-api/src/ComplianceSys.Application/Services/ComplMasterHierarchyService.cs` implementing `IComplMasterHierarchyService`, with `GetTreeAsync()` fully implemented (calls `GetAllWithMasterInfoAsync`) and the other 4 methods stubbed with `throw new NotImplementedException()` (filled in by US1/US2/US3) (depends on T004, T005, T007)
- [x] T009 Create `ComplMasterHierarchyController` in `compliance-sys-api/src/ComplianceSys.Api/Controllers/ComplMasterHierarchyController.cs` — `[Authorize]`, `[Route("api/compl-master-hierarchies")]`, with only `[HttpGet]` (`Policy = "ComplianceMaster.ReadAll"`) calling `GetTreeAsync()` for now (depends on T008)
- [x] T010 Register `IComplMasterHierarchyRepository`/`IComplMasterHierarchyService` in `ComplianceSys.Infrastructure/DependencyInjection.cs` and `ComplianceSys.Application/DependencyInjection.cs` (depends on T006, T008)
- [x] ~~T011~~ [P] Skipped as unnecessary: `ComplMasterHierarchyService` never calls `IMapper.Map<>()` (all `ComplMasterHierarchy` entities are constructed directly and `ComplMasterHierarchyResponseDto` rows come straight from Dapper's `GetAllWithMasterInfoAsync`/`GetByIdsWithMasterInfoAsync` SQL projections) — adding an unused AutoMapper profile entry would be dead configuration
- [x] T012 [P] Create `ComplMasterHierarchyNode` domain entity in `compliance-client/src/domain/entities/ComplMasterHierarchyNode.js` (`{ id, masterCode, parentCode, displayOrder, name, description, createdBy, createdDate, updatedBy, updatedDate }`)
- [x] T013 [P] Create `IComplMasterHierarchyRepository` interface in `compliance-client/src/domain/interfaces/IComplMasterHierarchyRepository.js` (`getTree`, `addRoots`, `addChildren`, `move`, `remove` — throw `'Not implemented'`)
- [x] T014 Create `compliance-client/src/infrastructure/api/complMasterHierarchyApi.js` — axios wrapper, base `/compl-master-hierarchies`, with `getTree: () => axiosInstance.get('/compl-master-hierarchies')` only for now (other methods added by later story phases)
- [x] T015 Create `RestComplMasterHierarchyRepository.js` in `compliance-client/src/infrastructure/repositories/RestComplMasterHierarchyRepository.js` implementing `getTree()` (wraps rows in `ComplMasterHierarchyNode`), other interface methods stubbed for now (depends on T012, T013, T014)
- [x] T016 [P] Create `GetTreeComplMasterHierarchyUseCase.js` in `compliance-client/src/application/usecases/compl-master-hierarchies/GetTreeComplMasterHierarchyUseCase.js`
- [x] T017 Register `complMasterHierarchy: new RestComplMasterHierarchyRepository()` in `compliance-client/src/di/repositories.js` (depends on T015)
- [x] T018 [P] Create `compliance-client/src/presentation/pages/compl-master-hierarchies/utils/masterHierarchyTreeUtils.js` with `buildTree(rows)` — groups by `parentCode`, resolves each node's children as `rows.filter(r => r.parentCode === node.masterCode)` per data-model.md ("Frontend — cấu trúc cây")
- [x] T019 Create `useComplMasterHierarchyTree.js` hook in `compliance-client/src/presentation/pages/compl-master-hierarchies/hooks/useComplMasterHierarchyTree.js` with `loadFromServer()` (calls `GetTreeComplMasterHierarchyUseCase`, stores flat rows + calls `buildTree`) and exposed `treeData`/`flatRows`/`selectedId` state (depends on T016, T018)
- [x] T020 Create `ComplMasterHierarchiesPage.jsx` shell in `compliance-client/src/presentation/pages/compl-master-hierarchies/ComplMasterHierarchiesPage.jsx` — renders the tree read-only via `@mui/x-tree-view` `SimpleTreeView`/`TreeItem` (Code - Name per node, per FR-018) using `useComplMasterHierarchyTree`, plus a "Back" button (`ArrowBack`, `navigate(-1)`); toolbar action buttons added by later phases (depends on T019)
- [x] T021 Add lazy import + route `{ path: '/compliance-master/hierarchies', element: <ComplMasterHierarchiesPage /> }` to `compliance-client/src/app/routes/groups/MainRoutes.jsx` (depends on T020)
- [x] T022 Add a "Master hierarchies" button to `compliance-client/src/presentation/pages/compliance-master/index.jsx` that navigates to `/compliance-master/hierarchies` (depends on T021)

**Checkpoint**: Opening `/compliance-master/hierarchies` shows the (possibly empty) tree read-only. User story implementation can now begin.

---

## Phase 3: User Story 1 - Build the top level of a hierarchy with Add root (Priority: P1) 🎯 MVP

**Goal**: Let a user open the picker via "Add root", multi-select Compliance Masters across pages, and add them as new top-level nodes with sequential `DisplayOrder`, rejecting duplicates.

**Independent Test**: Per spec.md — open the screen, click "Add root", select masters across ≥2 pages, click "Add", confirm they appear as root nodes in selection order with `DisplayOrder` 0,1,2,...; retry adding an existing root code and confirm it is rejected with a clear message.

### Implementation for User Story 1

- [x] T023 [P] [US1] Create `AddRootsRequestDto` (`{ List<string> MasterCodes }`) in `compliance-sys-api/src/ComplianceSys.Application/Dtos/Request/AddRootsRequestDto.cs`
- [x] T024 [P] [US1] Create `AddHierarchyResultDto` (`{ List<ComplMasterHierarchyResponseDto> Added, List<RejectedHierarchyItemDto> Rejected }`) and `RejectedHierarchyItemDto` (`{ string MasterCode, string Reason }`) in `compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/AddHierarchyResultDto.cs`
- [x] T025 [P] [US1] Create `AddRootsRequestDtoValidator` (`MasterCodes` not empty, no blank entries) in `compliance-sys-api/src/ComplianceSys.Application/Validators/AddRootsRequestDtoValidator.cs`
- [x] T026 [US1] Implement `ComplMasterHierarchyService.AddRootsAsync` in `compliance-sys-api/src/ComplianceSys.Application/Services/ComplMasterHierarchyService.cs` — for each code in input order: reject via `ExistsAsync(code, "")` with reason `"{code} is already a root."`; otherwise insert with `DisplayOrder = GetMaxDisplayOrderAsync("") + 1 + <count already added this call>`; return `AddHierarchyResultDto` (depends on T005/T006, T023, T024)
- [x] T027 [US1] Add `[HttpPost("roots")]` (`Policy = "ComplianceMaster.ReadAll"`) endpoint to `ComplMasterHierarchyController.cs` calling `AddRootsAsync`, returning `201` if any added, `422` if all rejected (per contracts/compl-master-hierarchies-api.md) (depends on T026)
- [x] T028 [US1] Register `IValidator<AddRootsRequestDto>` in `ComplianceSys.Application/DependencyInjection.cs` (depends on T025)
- [x] T029 [P] [US1] Add `addRoots: (masterCodes) => axiosInstance.post('/compl-master-hierarchies/roots', { masterCodes })` to `compliance-client/src/infrastructure/api/complMasterHierarchyApi.js`
- [x] T030 [P] [US1] Implement `addRoots(masterCodes)` in `RestComplMasterHierarchyRepository.js` (depends on T029)
- [x] T031 [P] [US1] Create `AddRootsComplMasterHierarchyUseCase.js` in `compliance-client/src/application/usecases/compl-master-hierarchies/AddRootsComplMasterHierarchyUseCase.js`
- [x] T032 [US1] Create `MasterPickerDialog.jsx` in `compliance-client/src/presentation/pages/compl-master-hierarchies/components/MasterPickerDialog.jsx` — modeled on `BulkAddStepsDialog.jsx`: paginated checkbox table (Code, Name, Description, Action column with a placeholder "View condition" button wired in US4) sourced from the existing `GetPagingComplianceMasterUseCase` (page=1, pageSize=50, no filters), preserving checked codes across page navigation, footer "{N} selected" + Cancel/Add
- [x] T033 [US1] Add `addRoots(masterCodes)` to `useComplMasterHierarchyTree.js` — calls `AddRootsComplMasterHierarchyUseCase`, merges `data.added` into tree state, surfaces `data.rejected` reasons to the caller (depends on T030, T031)
- [x] T034 [US1] Wire the "Add root" toolbar button (`AddBox` icon) in `ComplMasterHierarchiesPage.jsx` to open `MasterPickerDialog` and call `addRoots` on confirm, showing any rejected-code errors (e.g. via snackbar) (depends on T032, T033)

**Update (2026-07-30, follow-up 2 — FR-025-027)**: Search-by-Code/Name textbox added to the shared picker, per research.md §10 — reuses the existing `GetPagingComplianceMasterUseCase`/`POST /compliance-master/get-all` `payload` filter mechanism (no new API/DTO/stored-procedure).

- [x] T080 [US1] In `MasterPickerDialog.jsx` (`compliance-client/src/presentation/pages/compl-master-hierarchies/components/MasterPickerDialog.jsx`), add a search `TextField` (Code/Name) above the table that calls `GetPagingComplianceMasterUseCase.execute(1, pageSize, sortColumn, sortOrder, false, searchText ? [{ column: 'searchText', operator: 'like', value: searchText }] : [])` — always resets to page 1 on a new search, and re-runs with an empty filter array when cleared (restores the full unfiltered list per FR-027); render a search-specific empty-state message when the filtered result set is empty (FR-025, research.md §10) — **implemented as explicit Search/Clear (icon-adornment) actions + Enter-key trigger, matching the existing `ComplianceFilterBar.jsx`/`compliance-master/index.jsx` search convention already used elsewhere in the repo (Nguyên tắc II), instead of the auto-debounce originally sketched in plan.md/research.md** (depends on T032)
- [x] T081 [US1] In `MasterPickerDialog.jsx`, move the checked-master selection to a state independent of the currently displayed rows (e.g. a `Set<code>` keyed by `Code`, not by row index/page) so that masters checked before or during a search remain checked — and are still included when "Add" is clicked — even after they are filtered out of view by a later search (FR-026) — **confirmed already satisfied**: `selected` was already a `Map<code, master>` populated independently of `rows`/pagination since US1's original implementation, so no change was needed beyond keeping it untouched across search/clear (depends on T080)

**Checkpoint**: User Story 1 fully functional and independently testable (quickstart.md scenarios 1 and 1b).

---

## Phase 4: User Story 2 - Nest masters under a parent with Add child (Priority: P2)

**Goal**: Let a user select an existing node, open the same picker via "Add child", and add masters as children, with duplicate-sibling and ancestor-cycle validation.

**Independent Test**: Per spec.md — select a node, confirm "Add child" is disabled with none selected and enabled once selected; add children (they nest correctly with `DisplayOrder` starting at 0); attempt to add an ancestor of the selected node as its own child and confirm rejection; attempt to add a code already a direct child of that parent and confirm rejection.

### Implementation for User Story 2

- [x] T035 [P] [US2] Create `AddChildrenRequestDto` (`{ List<string> MasterCodes }`) in `compliance-sys-api/src/ComplianceSys.Application/Dtos/Request/AddChildrenRequestDto.cs`
- [x] T036 [P] [US2] Create `AddChildrenRequestDtoValidator` in `compliance-sys-api/src/ComplianceSys.Application/Validators/AddChildrenRequestDtoValidator.cs`
- [x] T037 [US2] Implement `ComplMasterHierarchyService.AddChildrenAsync` in `ComplMasterHierarchyService.cs` — load `GetAllWithMasterInfoAsync()` once, build `code → set<parentCode>` graph, compute `ancestors(parentCode)` via BFS (research.md §2); for each input code reject if `code == parentCode` or `code` ∈ `ancestors(parentCode) ∪ {parentCode}` (`"Adding {code} here would create a circular relationship."`), else reject via `ExistsAsync(code, parentCode)` (`"{code} is already a child of {parentCode}."`), else insert with next `DisplayOrder` in that parent's sibling group; return `AddHierarchyResultDto` (depends on T006, T024, T035)
- [x] T038 [US2] Add `[HttpPost("{parentCode}/children")]` (`Policy = "ComplianceMaster.ReadAll"`) endpoint to `ComplMasterHierarchyController.cs` calling `AddChildrenAsync(parentCode, ...)` (depends on T037)
- [x] T039 [US2] Register `IValidator<AddChildrenRequestDto>` in `ComplianceSys.Application/DependencyInjection.cs` (depends on T036)
- [x] T040 [P] [US2] Add `addChildren: (parentCode, masterCodes) => axiosInstance.post(\`/compl-master-hierarchies/${encodeURIComponent(parentCode)}/children\`, { masterCodes })` to `complMasterHierarchyApi.js`
- [x] T041 [P] [US2] Implement `addChildren(parentCode, masterCodes)` in `RestComplMasterHierarchyRepository.js` (depends on T040)
- [x] T042 [P] [US2] Create `AddChildrenComplMasterHierarchyUseCase.js` in `compliance-client/src/application/usecases/compl-master-hierarchies/AddChildrenComplMasterHierarchyUseCase.js`
- [x] T043 [US2] Add `addChildren(parentCode, masterCodes)` to `useComplMasterHierarchyTree.js`, merging results the same way as `addRoots` (depends on T042)
- [x] T044 [US2] Add selected-node state + "Add child" toolbar button (`PlaylistAdd` icon, disabled unless a node is selected) in `ComplMasterHierarchiesPage.jsx`, reusing `MasterPickerDialog` from US1 and calling `addChildren` on confirm (depends on T032, T043)

**Checkpoint**: User Stories 1 AND 2 both work independently (quickstart.md scenario 2).

---

## Phase 5: User Story 3 - Reorder and remove nodes to maintain the tree (Priority: P3)

**Goal**: Let a user move a selected node up/down among its siblings, delete a node (cascading to descendants with a confirmed count), and expand/collapse the whole tree.

**Independent Test**: Per spec.md — move a node with siblings up/down and confirm on-screen order updates immediately; confirm no-op at the ends of a sibling group; delete a leaf node immediately; delete a node with descendants and confirm the warned count matches what disappears; expand-all/collapse-all toggles every node.

### Implementation for User Story 3

- [x] T045 [P] [US3] Create `MoveHierarchyRequestDto` (`{ string Direction }`) in `compliance-sys-api/src/ComplianceSys.Application/Dtos/Request/MoveHierarchyRequestDto.cs`
- [x] T046 [P] [US3] Create `MoveHierarchyRequestDtoValidator` (`Direction` must be `"up"`/`"down"`, case-insensitive) in `compliance-sys-api/src/ComplianceSys.Application/Validators/MoveHierarchyRequestDtoValidator.cs`
- [x] T047 [US3] Implement `ComplMasterHierarchyService.MoveAsync(id, direction, userEmail)` in `ComplMasterHierarchyService.cs` — load the row, load its siblings via `GetSiblingsAsync(row.ParentCode)` ordered by `DisplayOrder`, swap `DisplayOrder` with the adjacent sibling in `direction`, no-op at either end (depends on T006, T045)
- [x] T048 [US3] Implement `ComplMasterHierarchyService.DeleteWithDescendantsAsync(id, userEmail)` in `ComplMasterHierarchyService.cs` — resolve the row's `MasterCode`, BFS the descendant closure (rows whose `ParentCode` chains back to that code, per data-model.md §5), delete the row plus all descendant rows in one transaction (`IUnitOfWork`), return count deleted (depends on T006)
- [x] T049 [US3] Add `[HttpPut("{id:long}/move")]` (`Policy = "ComplianceMaster.ReadAll"`) endpoint to `ComplMasterHierarchyController.cs` calling `MoveAsync`, `404` if `id` not found (depends on T047)
- [x] T050 [US3] Add `[HttpDelete("{id:long}")]` (`Policy = "ComplianceMaster.ReadAll"`) endpoint to `ComplMasterHierarchyController.cs` calling `DeleteWithDescendantsAsync`, `404` if `id` not found (depends on T048)
- [x] T051 [US3] Register `IValidator<MoveHierarchyRequestDto>` in `ComplianceSys.Application/DependencyInjection.cs` (depends on T046)
- [x] T052 [P] [US3] Add `move: (id, direction) => axiosInstance.put(\`/compl-master-hierarchies/${id}/move\`, { direction })` and `remove: (id) => axiosInstance.delete(\`/compl-master-hierarchies/${id}\`)` to `complMasterHierarchyApi.js`
- [x] T053 [P] [US3] Implement `move(id, direction)`/`remove(id)` in `RestComplMasterHierarchyRepository.js` (depends on T052)
- [x] T054 [P] [US3] Create `MoveComplMasterHierarchyUseCase.js` in `compliance-client/src/application/usecases/compl-master-hierarchies/MoveComplMasterHierarchyUseCase.js`
- [x] T055 [P] [US3] Create `DeleteComplMasterHierarchyUseCase.js` in `compliance-client/src/application/usecases/compl-master-hierarchies/DeleteComplMasterHierarchyUseCase.js`
- [x] T056 [US3] Add `getDescendantIds(rows, rowId)` to `masterHierarchyTreeUtils.js` per data-model.md ("Frontend — cấu trúc cây") for the client-side delete-confirmation count (depends on T018)
- [x] T057 [US3] Add `moveNode(id, direction)`/`removeNode(id)` to `useComplMasterHierarchyTree.js`, calling the new use cases and refreshing tree state (depends on T054, T055, T056)
- [x] T058 [US3] Wire move-up/move-down (`ArrowUpward`/`ArrowDownward`, disabled at sibling-group ends), delete (`Delete` icon → confirm dialog showing `getDescendantIds` count → `removeNode`), and expand-all/collapse-all (`UnfoldMore`/`UnfoldLess`) toolbar buttons in `ComplMasterHierarchiesPage.jsx` (depends on T057)

**Checkpoint**: User Stories 1-3 all independently functional (quickstart.md scenario 3).

---

## Phase 6: User Story 4 - Review a master's conditions before adding it (Priority: P4)

**Goal**: Let a user click "View condition" on any picker row to see that master's existing compliance conditions read-only, without losing picker state.

**Independent Test**: Per spec.md — open the picker, click "View condition" on a row, confirm conditions display in a read-only view; close it and confirm prior checkbox selections and current page are unchanged.

### Implementation for User Story 4

- [x] T059 [US4] In `MasterPickerDialog.jsx`, wire each row's "View condition" action to the existing `GetConditionsByMasterIdUseCase`/`repositories.complianceMaster` (via `row.id`) and the existing `ConditionsView` component (`@presentation/components/common/ConditionsView.jsx`) as a nested dialog, without closing the picker or clearing checked codes/current page (depends on T032)

**Checkpoint**: All user stories independently functional (quickstart.md scenario 4).

---

## Phase 7: User Story 5 - Reorder siblings by dragging and dropping nodes (Priority: P3)

**Goal**: Let a user drag a node to reorder it among its current siblings (arbitrary position, not just adjacent swap), persisting every valid drop immediately (no separate Save step, consistent with US1-US3). Drag-and-drop is intentionally restricted to the same level — dropping onto a node under a different parent has no effect.

**Independent Test**: Per spec.md — drag a node to a new position among its siblings and confirm `DisplayOrder` updates to match; attempt to drag a node onto a node under a different parent and confirm the drop has no effect and the tree is unchanged; drop outside any valid target and confirm the drag is cancelled with no change.

**Scope note (2026-07-30, follow-up)**: This phase originally also supported dragging a node onto a different parent ("reparent") or onto a dedicated root drop zone ("Drop here to make root"). Per user feedback ("bỏ phần Drop here to make root, chỉ drap drop ở cùng level"), that capability was removed — the tasks that implemented it are struck through below with the reason, and the corresponding code/docs were deleted (see research.md §9, plan.md Complexity Tracking).

### Implementation for User Story 5

- [x] T064 [P] [US5] Create `ReorderHierarchyRequestDto` (`{ int TargetIndex }`) in `compliance-sys-api/src/ComplianceSys.Application/Dtos/Request/ReorderHierarchyRequestDto.cs`
- [x] ~~T065~~ [P] [US5] REMOVED: `ReparentHierarchyRequestDto` — deleted along with the rest of the reparent-via-drag capability per user feedback; no longer needed
- [x] T066 [P] [US5] Create `ReorderHierarchyRequestDtoValidator` (`TargetIndex >= 0`) in `compliance-sys-api/src/ComplianceSys.Application/Validators/ReorderHierarchyRequestDtoValidator.cs`
- [x] ~~T067~~ [P] [US5] REMOVED: `ReparentHierarchyRequestDtoValidator` — deleted along with `ReparentHierarchyRequestDto`
- [x] T068 [US5] Implement `ComplMasterHierarchyService.ReorderAsync(id, targetIndex, userEmail)` in `ComplMasterHierarchyService.cs` per data-model.md §6 — load the row's current siblings (same `ParentCode`) ordered by `DisplayOrder`, remove the dragged row, insert it at `targetIndex` (clamped to `[0, count]`), reassign `DisplayOrder = 0..n-1` sequentially to the whole sibling group in one transaction, return the full updated sibling list (depends on T006, T064)
- [x] ~~T069~~ [US5] REMOVED: `ComplMasterHierarchyService.ReparentAsync` — deleted, along with the `ExistsExcludingIdAsync` repository method (interface + Dapper impl) it was the only caller of
- [x] T070 [US5] Add `[HttpPut("{id:long}/reorder")]` (`Policy = "ComplianceMaster.ReadAll"`) endpoint to `ComplMasterHierarchyController.cs` calling `ReorderAsync`, `404` if `id` not found (depends on T068)
- [x] ~~T071~~ [US5] REMOVED: `PUT {id}/reparent` endpoint — deleted from `ComplMasterHierarchyController.cs`
- [x] T072 [US5] Register `IValidator<ReorderHierarchyRequestDto>` in `ComplianceSys.Application/DependencyInjection.cs` (depends on T066) — the `IValidator<ReparentHierarchyRequestDto>` registration was removed along with the DTO
- [x] T073 [P] [US5] Add `reorder: (id, targetIndex) => axiosInstance.put(\`/compl-master-hierarchies/${id}/reorder\`, { targetIndex })` to `compliance-client/src/infrastructure/api/complMasterHierarchyApi.js` — the `reparent` method was removed
- [x] T074 [P] [US5] Implement `reorder(id, targetIndex)` in `RestComplMasterHierarchyRepository.js` (depends on T073) — the `reparent` method/interface stub were removed
- [x] T075 [P] [US5] Create `ReorderComplMasterHierarchyUseCase.js` in `compliance-client/src/application/usecases/compl-master-hierarchies/ReorderComplMasterHierarchyUseCase.js`
- [x] ~~T076~~ [P] [US5] REMOVED: `ReparentComplMasterHierarchyUseCase.js` — file deleted
- [x] ~~T077~~ [P] [US5] REMOVED: `RootDropZone.jsx` — file deleted, along with its import/render in `ComplMasterHierarchiesPage.jsx`
- [x] T078 [US5] Add `reorderNode(id, targetIndex)` to `useComplMasterHierarchyTree.js` — calls `ReorderComplMasterHierarchyUseCase` immediately on drop (no pending/dirty state), patches the affected rows into `flatRows` on success, and on failure leaves tree state untouched and surfaces the rejection reason to the caller (depends on T075, T018) — `reparentNode` was removed
- [x] T079 [US5] In `ComplMasterHierarchiesPage.jsx`, wrap the tree in a `DndContext` with `PointerSensor`+`KeyboardSensor` and wrap each sibling group in its own `SortableContext` (cloning the sensor/context setup from `TemplateBuilderPage.jsx`), and implement `handleDragEnd` to call `reorderNode` ONLY when `active`/`over` share the same `parentCode` — restored `TemplateBuilderPage.jsx`'s original guard clause (no-op on cross-parent drop) instead of branching into reparent (depends on T078) — also fixed a pre-existing dead `navigate` var (T020's promised "Back" button was imported but never wired) since it now fails the `no-unused-vars` lint gate

**Checkpoint**: User Stories 1-5 all independently functional (quickstart.md scenario 5).

---

## Phase 8: Polish & Cross-Cutting Concerns

- [x] T060 [P] Run `dotnet build` in `compliance-sys-api` and fix any compile errors — **partially run this session**: a real `dotnet build` was executed (not just hand-verification, unlike last session). `ComplianceSys.Domain`/`ComplianceSys.Application`/`ComplianceSys.Infrastructure` each built individually with **0 warnings, 0 errors** (confirms the new US5 code — DTOs, validators, service methods, repository method — compiles). The full solution build (`ComplianceSys.Api.csproj`) still fails at the final DLL-copy step only, because `ComplianceSys.Api.exe` (PID 32276) is running locally and holds a lock on its own `bin/` output (`MSB3027`/`MSB3021`, 0 `error CS*`); the user previously chose to skip stopping this process, so the same choice was kept this session — recommend stopping that process and re-running `dotnet build` once to get a fully clean solution-level pass before merging
- [x] T061 [P] Run `npm run build` / `eslint` in `compliance-client` and fix any lint/build errors — both re-run after adding US5 code and ran clean (`npx eslint` on all new/changed US5 files: 0 errors, after also fixing a pre-existing dead `navigate` var in `ComplMasterHierarchiesPage.jsx` that started failing lint once other unused imports in that file were exercised; `npm run build`: succeeded, `ComplMasterHierarchiesPage` chunk emitted at 11.64 kB, up from before US5)
- [ ] T062 Execute all `quickstart.md` scenarios end-to-end manually against a dev environment with the T002 migration applied — **not run this session** (no dev DB/API session available); recommend running scenarios 1-5 (including the new §5 drag-and-drop scenarios) before merging
- [x] T063 [P] Confirm the DDL in T001 (`Sqls/Tables/`) and T002 (`Sqls/Migration/`) stay byte-for-byte equivalent (same constraints/defaults), so fresh installs and manually-migrated environments end up with an identical schema — unchanged by US5 (no schema changes needed for reorder)

---

## Phase 9: User Story 6 - Review a master's conditions directly from the tree (Priority: P4)

**Goal**: Let a user click "View condition" directly on any node's row in the built hierarchy tree on the index screen (not the Add root/Add child picker), showing that node's Compliance Master conditions read-only, without changing the tree's expand/collapse state or the currently selected node.

**Independent Test**: Per spec.md — open the Compliance Master Hierarchies screen with at least one existing node, click "View condition" on that node's row, confirm conditions display in a read-only view; close it and confirm the tree's expand/collapse state and currently selected node are unchanged.

### Implementation for User Story 6

- [x] T082 [US6] In `ComplMasterHierarchiesPage.jsx` (`SortableMasterLabel` sub-component, `compliance-client/src/presentation/pages/compl-master-hierarchies/ComplMasterHierarchiesPage.jsx`), add a "View condition" `IconButton` (`Visibility` icon wrapped in `Tooltip`, matching the row-action affordance already used in `MasterPickerDialog.jsx`) next to the existing Code - Name text; add an `onViewCondition` prop and call `event.stopPropagation()` before invoking it, so clicking it never triggers the existing `onClick`/`onSelect(node.id)` on the row (FR-028, FR-029)
- [x] T083 [US6] In `ComplMasterHierarchiesPage.jsx`, add `conditionsOpen`/`conditions`/`loadingConditions` state and a `handleViewCondition(node)` function that calls the existing `GetConditionsByMasterIdUseCase.execute(node.id)` (same use case already imported by `MasterPickerDialog.jsx` from `@application/usecases/compliance-master`, per research.md §11 — no new use case/API), thread it down through `renderTree` to each `SortableMasterLabel` as `onViewCondition`, and render the existing `<ConditionsView>` component (`@presentation/components/common/ConditionsView`) bound to this state — kept fully independent of `selectedId` and the tree's expand/collapse state (FR-028, FR-030) (depends on T082) — **implemented**: also wired the pre-existing dead `navigate`/`ArrowBackIcon` imports (from T020, FR-019) into an actual "Back" toolbar button, since `eslint`'s `no-unused-vars` failed on this file once it was touched again; `npx eslint` and `npm run build` both ran clean afterward (`ComplMasterHierarchiesPage` chunk: 11.95 kB, up from 11.64 kB)
- [x] **Bug fix (2026-08-10, found during manual testing right after T082-T083)**: "View condition" on tree rows always showed "No conditions defined" — `handleViewCondition` was calling `GetConditionsByMasterIdUseCase.execute(node.id)`, but `node.id` is the `compl_master_hierarchies` row's own key (used for move/delete/reorder), not the Compliance Master's real `Id` that `GET /compliance-master/{id}/conditions` expects. Fixed by adding `m.Id AS MasterId` to `ComplMasterHierarchyRepository.SelectWithMasterInfoSql` (`compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/ComplMasterHierarchyRepository.cs`) and a matching `MasterId` field on `ComplMasterHierarchyResponseDto.cs` — flows through automatically to all endpoints (GetTree/AddRoots/AddChildren/Move/Reorder) since they share this one SQL source. Frontend `handleViewCondition` now uses `node.masterId`, with a null-guard (shows empty state instead of calling the API) for the edge case where the underlying Compliance Master was deleted. No DB migration needed (join-only field, not a new column). `dotnet build` (Application + Infrastructure) and `npx eslint`/`npm run build` (frontend) all ran clean.

**Checkpoint**: All user stories (US1-US6) independently functional (quickstart.md scenario 6).

---

## Phase 10: Bug fix (2026-08-18) - Whole-tree duplicate check + delete confirmation popup

**Goal**: Fix 3 issues found in manual testing — (1) `AddRootsAsync` only checked against existing roots (not the whole tree), (2) `AddChildrenAsync` only checked the ancestor chain and direct siblings (not the whole tree), both letting the same Compliance Master end up at 2 positions in the hierarchy, and (3) deleting a leaf node skipped the confirmation popup entirely instead of showing a generic "are you sure?" prompt. Enforce "1 `MasterCode` occupies at most 1 position in the entire tree" per spec.md Clarifications session 2026-08-18 and research.md §12, and "every delete shows a confirmation popup" per spec.md FR-015 (corrected 2026-08-18 follow-up) and research.md §13.

**Independent Test**: Per quickstart.md (updated) — create root A, add child M under A; select unrelated root B and try Add child M under B → rejected "already exists elsewhere in the hierarchy". Try Add root with a master that is already a child anywhere in the tree → rejected the same way. A leaf-node delete now also shows a confirmation popup (see T089 — corrected from an earlier, incorrect "not a bug" read of this same report).

### Implementation for bug fix

- [x] T084 [US1] Modify `ComplMasterHierarchyService.AddRootsAsync` in `compliance-sys-api/src/ComplianceSys.Application/Services/ComplMasterHierarchyService.cs` — replace the per-code `_repository.ExistsAsync(code, "")` round-trip with a single `GetAllWithMasterInfoAsync()` load before the loop; build `existingCodes` (every `MasterCode` in the tree) and `existingRootCodes` (subset with `ParentCode == ""`); for each input code reject with `"{code} is already a root."` if in `existingRootCodes`, else reject with `"{code} already exists elsewhere in the hierarchy."` if in `existingCodes`, else insert and add the code to both in-memory sets (per data-model.md "Quy tắc nghiệp vụ" #2, research.md §12)
- [x] T085 [US2] Modify `ComplMasterHierarchyService.AddChildrenAsync` in the same file — reuse the `allRows` already loaded for the ancestor-chain graph to also build `existingCodes = allRows.Select(r => r.MasterCode).ToHashSet()`; after the existing circular-relationship check (`forbidden`) and direct-sibling-duplicate check (`existingChildren`), add a third check: reject with `"{code} already exists elsewhere in the hierarchy."` if `code` is in `existingCodes` but wasn't caught by the first two checks; add the code to `existingCodes` (alongside the existing `existingChildren.Add(code)`) after each successful insert (per data-model.md "Quy tắc nghiệp vụ" #3, research.md §12) (depends on T084 only in that both touch the same file — no functional dependency)
- [x] T086 [P] Remove the now-unused `ExistsAsync(string masterCode, string parentCode, CancellationToken ct)` method from `IComplMasterHierarchyRepository` (`compliance-sys-api/src/ComplianceSys.Application/Interfaces/Repositories/IComplMasterHierarchyRepository.cs`) and its Dapper implementation in `ComplMasterHierarchyRepository.cs` (`compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/ComplMasterHierarchyRepository.cs`) — confirm via `grep -rn "ExistsAsync"` that T084 removed the only caller before deleting (depends on T084)
- [x] T087 [P] Change the UNIQUE KEY from `(MasterCode, ParentCode)` to `(MasterCode)` in `compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Tables/compl_master_hierarchies.sql` (fresh-install DDL), and create `compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Migration/21_unique_mastercode_compl_master_hierarchies.sql` with `ALTER TABLE compl_master_hierarchies DROP INDEX uq_compl_master_hierarchy, ADD UNIQUE KEY uq_compl_master_hierarchy (MasterCode);` for already-existing databases (per data-model.md, research.md §12 — DB-level defense-in-depth against race conditions)
- [x] T089 [US3] **(follow-up correction)** Fix `handleDeleteClick` in `compliance-client/src/presentation/pages/compl-master-hierarchies/ComplMasterHierarchiesPage.jsx` to always call `setDeleteConfirmOpen(true)` (removed the `if (descendantCount > 0) {...} else { doDelete() }` branch that skipped the popup for leaf nodes); update the `ConfirmDialog`'s `title`/`content`/`labelConfirm` to render conditionally on `descendantCount` — has-descendants keeps the existing "N descendant node(s) will also be removed" message and "Delete all" label, no-descendants shows a generic "Are you sure you want to delete node ...?" message and "Delete" label (per spec.md FR-015 corrected 2026-08-18 follow-up, research.md §13)
- [ ] T088 Execute the 2 new quickstart.md bug-fix scenarios (§1 "Add root với master đã là con ở nhánh khác", §2 "Add child với master đã tồn tại ở nhánh không liên quan") end-to-end against a dev environment with migration 21 applied, plus re-run the delete-confirmation scenarios in §3 (both leaf and has-descendants cases now show the popup) (depends on T084, T085, T087, T089)

**Checkpoint**: A Compliance Master can occupy only one position anywhere in the tree; attempts to place it a second time (as root or as child, in any branch) are rejected with a clear reason, matching spec.md SC-002. Every delete action shows a confirmation popup, with the descendant-count warning appended only when the node has descendants, matching spec.md FR-015.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately.
- **Foundational (Phase 2)**: Depends on Phase 1 (schema exists) — BLOCKS all user stories.
- **User Story 1 (Phase 3)**: Depends on Foundational only. **MVP — implement first.** T080-T081 (search textbox, FR-025-027) depend on T032 (`MasterPickerDialog.jsx` already existing) and were added after the rest of US1-US5 were already implemented.
- **User Story 2 (Phase 4)**: Depends on Foundational; reuses `MasterPickerDialog` built in US1 (T032) — build US1 first even though the backend halves (T035-T039) have no code dependency on US1.
- **User Story 3 (Phase 5)**: Depends on Foundational only; independent of US1/US2 backend code (different service methods/endpoints), but needs at least one node to exist to be demoed (created via US1).
- **User Story 4 (Phase 6)**: Depends on `MasterPickerDialog` existing (T032, from US1) — purely additive UI wiring inside it, no backend work.
- **User Story 5 (Phase 7)**: Depends on Foundational only (T006 repository, T018 tree utils) — reorder-within-siblings does not touch `ParentCode`, so it needs no validation reuse from US1/US2. Independent of US1-US4 otherwise (just needs at least one node with siblings to be demoed).
- **Polish (Phase 8)**: After all desired user stories are complete.
- **User Story 6 (Phase 9)**: Depends on `ComplMasterHierarchiesPage.jsx` existing (T020, Foundational) — purely additive UI wiring inside it (frontend-only, no backend/API work, per plan.md/research.md §11). Independent of US1-US5 and of Polish; only needs at least one node in the tree to be demoed. Added after Polish (Phase 8) in task numbering only because it was specified later (2026-08-10) — it has no actual dependency on Phase 8 completing.
- **Bug fix (Phase 10)**: T084-T087 depend on US1 (T026, `AddRootsAsync` must exist to modify it) and US2 (T037, `AddChildrenAsync` must exist to modify it) — backend-only, no new DTO/endpoint. T089 depends on US3 (T058, the delete toolbar button/`ConfirmDialog` wiring must exist to modify it) — frontend-only. Independent of US4-US6. Must run after US1, US2, and US3 are implemented (which they already are, per the checkmarks above).

### Parallel Opportunities

- T001/T002 (Setup) in parallel.
- T004, T005, T007 (Foundational, distinct backend files) in parallel; T012, T013, T016, T018 (Foundational, distinct frontend files) in parallel.
- Within US1: T023/T024/T025 in parallel; T029/T030/T031 in parallel.
- Within US2: T035/T036 in parallel; T040/T041/T042 in parallel.
- Within US3: T045/T046 in parallel; T052/T053/T054/T055 in parallel.
- Within US5: T064/T066 in parallel; T073/T074/T075 in parallel.
- Within US6: none — T082/T083 both touch `ComplMasterHierarchiesPage.jsx` and T083 depends on the `onViewCondition` prop T082 adds, so they run sequentially.
- Backend halves of US2 (T035-T039) and US3 (T045-T051) touch different DTOs/methods than US1 and each other (aside from the shared `ComplMasterHierarchyService.cs`/`ComplMasterHierarchyController.cs` files) — two developers can work US2-backend and US3-backend concurrently once Foundational is done, coordinating only on those two shared files.

---

## Parallel Example: User Story 1

```bash
# Backend DTOs/validator together:
Task: "Create AddRootsRequestDto in .../Dtos/Request/AddRootsRequestDto.cs"
Task: "Create AddHierarchyResultDto + RejectedHierarchyItemDto in .../Dtos/Response/AddHierarchyResultDto.cs"
Task: "Create AddRootsRequestDtoValidator in .../Validators/AddRootsRequestDtoValidator.cs"

# Frontend API/repository/use-case together (after backend endpoint T027 exists):
Task: "Add addRoots to complMasterHierarchyApi.js"
Task: "Implement addRoots in RestComplMasterHierarchyRepository.js"
Task: "Create AddRootsComplMasterHierarchyUseCase.js"
```

---

## Parallel Example: User Story 5

```bash
# Backend DTO/validator together:
Task: "Create ReorderHierarchyRequestDto in .../Dtos/Request/ReorderHierarchyRequestDto.cs"
Task: "Create ReorderHierarchyRequestDtoValidator in .../Validators/ReorderHierarchyRequestDtoValidator.cs"

# Frontend API/repository/use-case together (after backend endpoint T070 exists):
Task: "Add reorder to complMasterHierarchyApi.js"
Task: "Implement reorder in RestComplMasterHierarchyRepository.js"
Task: "Create ReorderComplMasterHierarchyUseCase.js"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 (Setup) + Phase 2 (Foundational).
2. Complete Phase 3 (US1 — Add root).
3. **STOP and VALIDATE**: run quickstart.md scenario 1 independently.
4. Demo: a working forest of root-level Compliance Masters, duplicate-root rejection.

### Incremental Delivery

1. Setup + Foundational → tree screen loads (empty).
2. + US1 → add/see roots (MVP).
3. + US2 → nest children, cycle/duplicate-sibling protection.
4. + US3 → reorder and delete, with cascade-delete confirmation.
5. + US4 → view conditions inline from the picker.
6. + US5 → drag-and-drop reorder within the same level (no reparent).
7. Polish → build/lint clean, full quickstart pass.
8. + US6 → view a node's conditions directly from its row in the tree, without opening the picker.

## Notes

- No test tasks are included (tests not requested — see plan.md "Testing"); `quickstart.md` is the verification mechanism (T062, plus scenario 1b for T080-T081).
- `[P]` tasks touch different files and have no unmet dependency within their phase.
- `ComplMasterHierarchyService.cs` and `ComplMasterHierarchyController.cs` are edited across Foundational, US1, US2, US3, and US5 — treat those specific tasks as sequential even when other tasks in the same phase are parallel.
- Commit after each task or logical group; stop at any checkpoint to validate a story independently.
- US1-US5 (T001-T079) are now all implemented, with US5 trimmed down to same-level reorder only per user feedback (2026-07-30 follow-up) — the reparent-via-drag tasks (T065/T067/T069/T071/T076/T077) are struck through with reasons rather than deleted, so the history of what was tried and rolled back stays visible. Remaining open item: T062 (full manual `quickstart.md` walkthrough against a real dev DB/API) was not run in this session — no dev environment was available — and T060's solution-level `dotnet build` is blocked by a locally-running `ComplianceSys.Api.exe` holding its own `bin/` output; per-project builds confirm 0 compile errors in the new code. Stop that process and re-run `dotnet build` + `quickstart.md` scenarios 1-5 before merging.
- **T080-T081 (Code/Name search textbox, FR-025-027) are now implemented** — frontend-only (no backend/API/DTO changes — see research.md §10), touching only `MasterPickerDialog.jsx`. Deviated from plan.md/research.md's originally-sketched debounce-on-type in favor of the repo's existing explicit Search/Clear + Enter-key convention (`ComplianceFilterBar.jsx`), for consistency with Nguyên tắc II. `eslint`/`npm run build` both ran clean after the change. `quickstart.md` scenario 1b still needs a manual run against a live dev environment (not available this session).
- **T082-T083 (User Story 6 — "View condition" on each tree row, FR-028-030) are now implemented** — frontend-only, touching only `ComplMasterHierarchiesPage.jsx` (its `SortableMasterLabel` sub-component), per plan.md's 2026-08-10 update and research.md §11. No backend/API/DTO/table changes: reuses the exact `GetConditionsByMasterIdUseCase` + `ConditionsView` pair already implemented for US4/T059 in `MasterPickerDialog.jsx`. Also fixed a pre-existing gap found while touching this file: the "Back" button promised by T020/FR-019 was never actually wired (imports for `useNavigate`/`ArrowBackIcon` existed but were unused) — added a working "Back" toolbar button using those same imports. `npx eslint` and `npm run build` both ran clean. `quickstart.md` scenario 6 still needs a manual run against a live dev environment (not available this session).
- **T084-T087 (Bug fix, 2026-08-18) are now implemented** — 2 critical data-duplication bugs found in testing: `AddRootsAsync` only checked existing roots, `AddChildrenAsync` only checked the ancestor chain + direct siblings, neither scanned the whole tree, so the same master could end up at 2 positions. Fixed by loading the whole tree once (`GetAllWithMasterInfoAsync`) in both methods and rejecting with `"{code} already exists elsewhere in the hierarchy."` when a code is found anywhere else in the tree that the existing checks didn't already catch; removed the now-dead `ExistsAsync(masterCode, parentCode)` repository method (confirmed via `grep -rn "ExistsAsync"` it had no other callers); changed the DB `UNIQUE KEY` from `(MasterCode, ParentCode)` to `(MasterCode)` in `Sqls/Tables/compl_master_hierarchies.sql` plus new migration `21_unique_mastercode_compl_master_hierarchies.sql` for existing databases (DB-level defense-in-depth against race conditions). `dotnet build` on `ComplianceSys.Application` and `ComplianceSys.Infrastructure` both ran clean (0 errors — pre-existing warnings only, unrelated to this change). This reverses the original "DAG with shared branches" design (research.md §2, now struck through) in favor of "1 MasterCode = 1 position in the whole tree" per spec.md's Clarifications session 2026-08-18.
- **T089 (follow-up correction) is now implemented** — the 3rd reported item (delete confirmation popup) was initially misread as NOT a code bug, concluding `ComplMasterHierarchiesPage.jsx`'s `handleDeleteClick` (which only opened the popup when `descendantCount > 0`, calling `doDelete()` directly otherwise) was already correct and only the spec wording needed fixing. The user corrected this: the popup MUST appear for every delete, with the descendant-count warning as an addition, not a gate. Fixed `handleDeleteClick` to always `setDeleteConfirmOpen(true)`, and made `ConfirmDialog`'s `title`/`content`/`labelConfirm` conditional on `descendantCount` (generic message + "Delete" label when 0, descendant-count message + "Delete all" label when > 0). While in this file, also wired the previously-dead `navigate`/`ArrowBackIcon` imports into an actual "Back" toolbar button (`navigate(-1)`) — `no-unused-vars` failed on `navigate` once the file was touched again, same recurring pattern noted at T083/T020. `npx eslint` and `npm run build` both ran clean afterward (`ComplMasterHierarchiesPage` chunk: 12.13 kB).
- **T088 (manual quickstart re-run) was NOT run this session** — no live dev DB/API session available; needs a manual pass against a dev environment with migration 21 applied before merging (same limitation as pre-existing T062).
