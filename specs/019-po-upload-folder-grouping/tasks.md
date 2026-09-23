---

description: "Task list template for feature implementation"
---

# Tasks: PO Upload Folder Grouping

**Input**: Design documents from `/specs/019-po-upload-folder-grouping/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/upload-endpoints.md](./contracts/upload-endpoints.md), [quickstart.md](./quickstart.md)

**Tests**: Included — this backend service currently has zero direct unit test coverage
(`EutrUploadServiceTests.cs` does not exist yet) and this is a storage-path correctness change, so
test tasks are added following the existing `EutrSynchronizeDataServiceTests.cs` pattern.

**Organization**: Tasks are grouped by user story (spec.md P1/P2/P2), plus one required
cross-cutting phase for a regression discovered during research (see
[research.md Decision 3](./research.md#decision-3--eutrsynchronizedataservice-must-move-in-lockstep-discovered-dependency)).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)

## Path Conventions

Backend-only change, existing `compliance-sys-api` solution:
- `compliance-sys-api/src/ComplianceSys.Application/Services/`
- `compliance-sys-api/tests/ComplianceSysApi.UnitTests/Services/`

No frontend paths — confirmed in research.md Decision 4 that `compliance-client/` needs no changes.

## Phase 1: Setup

**Purpose**: Confirm a clean baseline before changing shared upload/sync logic

- [X] T001 Run `dotnet test compliance-sys-api/tests/ComplianceSysApi.UnitTests` and confirm all
      existing tests (including `EutrSynchronizeDataServiceTests.cs`) pass before any change, to
      have a clean baseline to compare against

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared constant both user-story code paths need

**⚠️ CRITICAL**: Must complete before Phase 3/4 implementation tasks

- [X] T002 Add `private const string PoGroupFolderName = "PO";` next to the existing `PoRefType`
      constant in `compliance-sys-api/src/ComplianceSys.Application/Services/EutrUploadService.cs`
      (near line 27), with a short Vietnamese comment noting it is the shared parent folder name
      for every PO-code folder (research.md Decision 2)

**Checkpoint**: Constant available — User Story 1 implementation can begin

---

## Phase 3: User Story 1 - New PO gets its folder nested under "PO" (Priority: P1) 🎯 MVP

**Goal**: Every Type = PO upload creates/reuses `{basePath}/PO/{PoCode}` instead of
`{basePath}/{PoCode}`, for both upload entry points

**Independent Test**: Upload a document with Type = PO for a brand-new PO code and verify the
resulting SharePoint path is `.../PO/<PoCode>/<file>` (see quickstart.md "Validate User Story 1")

### Tests for User Story 1

> Write these tests first; they must FAIL against the pre-change code, then pass after T005/T006

- [X] T003 [US1] Create `compliance-sys-api/tests/ComplianceSysApi.UnitTests/Services/EutrUploadServiceTests.cs`
      following the mock/constructor pattern already used in
      `EutrSynchronizeDataServiceTests.cs` (Mock `ISharepointService`, `IRepository<EutrDocuments,long>`,
      `IRepository<EutrReferences,long>`, `IRepository<EutrStep,long>`, `IEutrMastersRepository`,
      `IUnitOfWork`, `IConfiguration` with `SharePointEutrPath` returning `"Sandbox/Eutr"`); add one
      test for `UploadMultipleToSharePointAndSaveDataAsync` (Acceptance Scenario 1: no existing
      folders at all) asserting `_sharepointService.CreateFolder` is called first with
      `"Sandbox/Eutr/PO"` and then with `"Sandbox/Eutr/PO/PO000123"`, and that
      `_sharepointService.UploadFile` is called with target folder `"Sandbox/Eutr/PO/PO000123"`
- [X] T004 [US1] In the same file, add a test for `UploadMultipleForReferenceTypeAsync` when
      `request.TypeName = "PO"` (case-insensitive) and `request.RefValues = ["PO000123"]`, asserting
      the same nested `"Sandbox/Eutr/PO/PO000123"` target folder is used, mirroring T003's
      assertions for the type-based endpoint (depends on T003 for the shared test-class scaffolding)

### Implementation for User Story 1

- [X] T005 [US1] In `compliance-sys-api/src/ComplianceSys.Application/Services/EutrUploadService.cs`,
      change `UploadMultipleToSharePointAndSaveDataAsync` (around line 66) from
      `var targetFolder = await ResolveOrCreatePoFolderAsync(basePath, request.PoCode);` to first
      resolving the shared group folder via
      `var poGroupFolder = await ResolveOrCreatePoFolderAsync(basePath, PoGroupFolderName);` and then
      `var targetFolder = await ResolveOrCreatePoFolderAsync(poGroupFolder, request.PoCode);`; add a
      short Vietnamese comment referencing this feature's nested-folder requirement
- [X] T006 [US1] In the same file, change `UploadMultipleForReferenceTypeAsync` (around lines
      203-204) so that when `ResolveFolderName(request.TypeName, request.RefValues)` corresponds to
      the `"po"` branch, the target folder is resolved the same two-step way as T005 (nest under
      `PoGroupFolderName`); every other `TypeName` branch (`vendor`, `invoice`, `delivery note`,
      `general agreement`, default) MUST keep calling
      `ResolveOrCreatePoFolderAsync(basePath, folderName)` exactly as before (FR-005) — e.g. compare
      `request.TypeName?.Trim().ToLowerInvariant() == "po"` to branch between the nested vs. flat
      resolution before/after computing `folderName`

**Checkpoint**: User Story 1 fully functional and independently testable — run
`dotnet test compliance-sys-api/tests/ComplianceSysApi.UnitTests --filter FullyQualifiedName~EutrUploadServiceTests`

---

## Phase 4: User Story 2 - Repeat uploads reuse the existing nested folder (Priority: P2)

**Goal**: Confirm the existing resolve-or-create logic remains idempotent once nested — no
duplicate `PO` or `PO/<PoCode>` folders on repeat uploads

**Independent Test**: Upload two documents in sequence for the same PO code; both land in the same
nested folder with no duplicate folder creation (see quickstart.md "Validate User Story 2")

**Note**: No production code change is needed for this story — `ResolveOrCreatePoFolderAsync`'s
existing `GetFolders`+match-before-create logic (line 342-355) already provides idempotency; this
phase only needs to prove it holds once nested (depends on Phase 3 completion).

### Tests for User Story 2

- [X] T007 [US2] In `compliance-sys-api/tests/ComplianceSysApi.UnitTests/Services/EutrUploadServiceTests.cs`,
      add a test (Acceptance Scenario: "PO group folder exists but PO code folder does not") where
      `GetFolders("Sandbox/Eutr")` mock returns a folder named `"PO"` but `GetFolders("Sandbox/Eutr/PO")`
      returns no `"PO000124"` child — assert `CreateFolder` is called only for
      `"Sandbox/Eutr/PO/PO000124"` and NOT for `"Sandbox/Eutr/PO"` (the group folder must be reused,
      not recreated)
- [X] T008 [US2] In the same file, add a test where both `GetFolders("Sandbox/Eutr")` returns
      `"PO"` and `GetFolders("Sandbox/Eutr/PO")` returns `"PO000123"` already — assert
      `CreateFolder` is never called at all, and the upload still succeeds into
      `"Sandbox/Eutr/PO/PO000123"`

**Checkpoint**: User Stories 1 AND 2 both verified independently

---

## Phase 5: User Story 3 - Sales Orders & Purchase Orders screens keep working (Priority: P2)

**Goal**: PO-type documents uploaded/viewed/downloaded from the Sales Orders overview screen
(`005-eutr-sales-orders`) and the Purchase Orders screen (`012-eutr-purchase-orders`) resolve
correctly to the new nested `PO/<PoCode>` location, since both screens delegate to the same
`EutrUploadService` fixed in Phase 3

**Independent Test**: From each screen, upload a Type = PO document, then list/view/download it
from the same screen and confirm it resolves to the nested folder (quickstart.md "Validate User
Story 3")

**Note**: No code changes are needed in `005-eutr-sales-orders` or `012-eutr-purchase-orders`
themselves — both were confirmed in research.md to have zero independent folder-resolution logic.
These tasks are manual/functional validation only, exercising the already-fixed shared service.

- [ ] T009 [US3] Manually validate: from the Sales Orders overview screen
      (`compliance-client/src/.../sales-orders` upload flow reusing
      `EutrDocumentsFormDialog.jsx`), upload a Type = PO document for a test PO code, then open the
      document list and download the file; confirm success and that the file now lives under
      `Sandbox/Eutr/PO/<PoCode>` (or the environment's configured `SharePointEutrPath`) —
      **not run in this session**: requires a live/dev SharePoint site and a running app
- [ ] T010 [US3] Manually validate: from the Purchase Orders screen
      (`compliance-client/src/.../purchase-orders`, same shared `EutrDocumentsFormDialog.jsx`
      popup per `012-eutr-purchase-orders` data-model.md §4), upload a Type = PO document for a
      different test PO code, then open the document list and download the file; confirm success
      and the nested folder location — **not run in this session**: same reason as T009

**Checkpoint**: All three affected screens (004/005/012) verified end-to-end

---

## Phase 6: Regression Fix - Missing-PO-Folder Alert Stays Accurate (Required, cross-cutting)

**Purpose**: Without this fix, every PO uploaded after Phase 3 ships would incorrectly be flagged
"Have no PO folder" by the existing `011-eutr-synchronize-data` / `018-compl-group-email-dk-alert`
alert, because it currently lists folders directly under `basePath` (research.md Decision 3,
data-model.md "Read-side impact"). This is a verified correctness gap, not new scope creep, and
MUST ship together with Phase 3.

- [X] T011 In `compliance-sys-api/src/ComplianceSys.Application/Services/EutrSynchronizeDataService.cs`,
      change the folder listing in `SendPurchaseMissingAlertAsync` (around line 231-235) from
      `var folders = await _sharepointService.GetFolders(basePath);` to
      `var folders = await _sharepointService.GetFolders($"{basePath.TrimEnd('/')}/PO");`
      (matching the `PoGroupFolderName` constant's value `"PO"` added in T002 — either reference
      the same literal or a shared constant, whichever keeps the two services consistent), keeping
      the rest of `existingFolderNames` construction (line 234-235) unchanged
- [X] T012 [P] In `compliance-sys-api/tests/ComplianceSysApi.UnitTests/Services/EutrSynchronizeDataServiceTests.cs`,
      update the existing tests that mock `GetFolders` (e.g.
      `SendPurchaseMissingAlertAsync_ShouldFlagNoPoFolder_WhenFolderDoesNotExist`,
      `SendPurchaseMissingAlertAsync_ShouldListMissingStepsByName_WhenSomeStepsHaveNoDocument`,
      `SendPurchaseMissingAlertAsync_ShouldJoinMultipleMissingStepNames_WithNewline`,
      `SendPurchaseMissingAlertAsync_ShouldNotThrow_WhenTemplateLookupReturnsMultipleVersionsOfSameCode`,
      `SendPurchaseMissingAlertAsync_ShouldNotFlag_WhenPurchaseOrderIsFullyComplete`) to assert
      `GetFolders` is called with `"Sandbox/Eutr/PO"` (not `"Sandbox/Eutr"`), and update the
      Vietnamese comments describing the mocked folder list to say it represents the contents of
      the `PO` subfolder rather than the root

**Checkpoint**: Full test suite green; no regression window between Phase 3 shipping and this fix

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final verification across the whole feature

- [X] T013 [P] Run `dotnet test compliance-sys-api/tests/ComplianceSysApi.UnitTests` and confirm
      100% pass, including all new/updated tests from Phases 3, 4, and 6 — **note**: the full suite
      has 3 pre-existing failures unrelated to this feature (`ComplSynchronizeDataServiceTests`
      x2, `MappingConfigurationTests` x1), confirmed present on the unmodified baseline via
      `git stash`; all 40 EutrUploadService/EutrSynchronizeDataService tests touched by this
      feature pass (206 passed / 209 total overall, unchanged failure count before/after)
- [ ] T014 Walk through every scenario in [quickstart.md](./quickstart.md) end-to-end (new PO
      upload, repeat upload, Sales Orders screen, Purchase Orders screen, missing-folder alert) and
      confirm each expected outcome — **not run in this session**: requires a live/dev SharePoint
      site and a running frontend+backend, neither available here; left for manual QA before merge

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies
- **Foundational (Phase 2)**: Depends on Phase 1 — BLOCKS Phase 3/4
- **User Story 1 (Phase 3)**: Depends on Phase 2 — this is the MVP
- **User Story 2 (Phase 4)**: Depends on Phase 3 (tests the same code path for idempotency)
- **User Story 3 (Phase 5)**: Depends on Phase 3 (validates the same fix from the other two screens)
- **Regression Fix (Phase 6)**: Independent of Phases 3-5's code (touches a different service) but
  MUST ship in the same release as Phase 3 — no hard task dependency, only a release-order
  requirement
- **Polish (Phase 7)**: Depends on Phases 3-6 all being complete

### Within Each Phase

- Tests before implementation in Phase 3 (T003/T004 before T005/T006)
- T006 depends on T005 only in the sense both edit the same file sequentially (not parallelizable)
- T007/T008 depend on T005/T006 (Phase 3 implementation) being complete
- T012 can run in parallel with T011 only in the sense it's a different file, but should assert
  against T011's actual output — implement T011 first, then T012

### Parallel Opportunities

- T002 has no parallel counterpart (single small change, blocking)
- T012 is marked [P] relative to Phase 7 tasks (different file, no shared state) but logically
  follows T011
- T009 and T010 (different screens, no shared file) can be validated in parallel by different people

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 (baseline) + Phase 2 (constant)
2. Complete Phase 3 (User Story 1) — this alone delivers the user's core request for
   `004-eutr-documents`, and transitively for `005`/`012` since they share the code path
3. **STOP and VALIDATE**: run T005/T006's tests, confirm nested folders in a real/dev SharePoint
4. Ship Phase 6 (regression fix) in the same release — do not ship Phase 3 without Phase 6

### Incremental Delivery

1. Setup + Foundational → Phase 3 (MVP, P1) → Phase 6 (required regression fix, same release)
2. Phase 4 (P2, idempotency proof) and Phase 5 (P2, cross-screen validation) can follow immediately
   after, in either order
3. Phase 7 (Polish) closes out the feature
