---

description: "Task list template for feature implementation"
---

# Tasks: EUTR Synchronize Data (Sales Order Template Sync)

**Input**: Design documents from `/specs/011-eutr-synchronize-data/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: Not explicitly requested by the feature spec. One unit-test task (T008) is included to
cover the spec's four acceptance scenarios, matching the existing `ComplianceSysApi.UnitTests`
convention already used elsewhere in this solution — not a TDD-first requirement.

**Organization**: The spec defines a single user story (US1, P1), so all functional work lives in
one phase. Foundational work is limited to the one shared-file fix every part of US1 depends on.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1 — the only story in this feature)
- Include exact file paths in descriptions

## Path Conventions

Existing `compliance-sys-api/` .NET 8 Clean Architecture solution (see plan.md Project Structure).
No `compliance-client/` (frontend) paths are involved — this is a backend-only feature.

---

## Phase 1: Setup

**Purpose**: Confirm a clean baseline before touching shared code.

- [X] T001 Confirm `compliance-sys-api/ComplianceSys.sln` builds and the existing
  `compliance-sys-api/tests/ComplianceSysApi.UnitTests` project runs green before any change, so any
  later failure is attributable to this feature's edits. No new NuGet packages are required (plan.md
  Technical Context). *(Confirmed: `ComplianceSys.Application`/`ComplianceSys.Api` compile cleanly;
  full `dotnet build` on the whole solution hits only file-lock copy errors from a locally-running
  `ComplianceSys.Api` dev instance, not a code issue. Pre-existing test suite: 96 passing, 1 failing
  — `MappingConfigurationTests.ApplicationMappingProfiles_ShouldBeValid`, an unrelated pre-existing
  AutoMapper config gap on `EutrDocuments`/compl-steps DTOs, untouched by this feature.)*

**Checkpoint**: Baseline verified — safe to start Phase 2.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Fix the shared `refType = 19` gap that every part of User Story 1 depends on.

**⚠️ CRITICAL**: User Story 1 cannot produce any synced rows until this phase is complete — today
`GetDynRefePagedAsync(19, ...)` always returns an empty result (research.md R2).

- [X] T002 In `compliance-sys-api/src/ComplianceSys.Application/Services/ComplDynamicsService.cs`:
  (a) add the missing entry `{ 19, ("RSVNEutrSalesOrderTemplates", "InterCompanyOriginalSalesId", "RSVNEutrTemplate") }`
  to the `EntityMappings` dictionary (around line 27-49, alongside the existing `14`/`15`/`16`/`18`
  entries), and (b) update the existing `case 19:` branch inside `MapDynamicsResponse` (around line
  463-472) to additionally populate `InterCompanyOriginalSalesId`, `EutrTemplate`, and
  `RSVNRefPurchId` on the returned `ComplDynReferenceResponseDto`, alongside the existing `Id`/`Code`/`Name`
  assignments — per the exact code shown in data-model.md "Changed (existing file, additive fix)".
  Add a short Vietnamese comment above the new dictionary entry noting it fixes the same class of
  gap as `refType = 18` (feature 009). Do not touch any other `EntityMappings` entry or `case` branch.

**Checkpoint**: `POST /api/dynamics/reference` with `refType=19` now returns real D365 rows (verify
manually per quickstart.md steps 1-2) — User Story 1 implementation can begin.

---

## Phase 3: User Story 1 - Populate purchase attachment records from the ERP's Sales Order Template data (Priority: P1) 🎯 MVP

**Goal**: A manually-triggered endpoint that reads the full D365 Sales Order Template reference
dataset (refType 19) and creates one `eutr_purchase_attachments` row per sales order that doesn't
already have one, skipping sales orders that do.

**Independent Test**: Per spec.md — trigger the endpoint against a D365 dataset containing a mix of
sales orders with and without an existing mapping row; confirm every previously-unmapped sales order
gets exactly one new row with the correct `PurchId`/`TemplateCode`, and previously-mapped sales
orders are left untouched. See quickstart.md steps 3-8 for the full walkthrough (including the
idempotency and full-page-coverage checks).

### Implementation for User Story 1

- [X] T003 [P] [US1] Create `EutrSynchronizeSummaryDto` in
  `compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/EutrSynchronizeSummaryDto.cs`
  with fields `TotalFetched` (int), `Added` (int), `Skipped` (int), `Success` (bool), `Message`
  (string) — per data-model.md "New DTO".

- [X] T004 [P] [US1] Create `IEutrSynchronizeDataService` in
  `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Services/IEutrSynchronizeDataService.cs`
  declaring `Task<EutrSynchronizeSummaryDto> SyncSalesOrderTemplatesAsync(CancellationToken ct = default);`
  (references the DTO from T003 — write both files' shapes from data-model.md so they align even
  though the files are created independently).

- [X] T005 [US1] Implement `EutrSynchronizeDataService` in
  `compliance-sys-api/src/ComplianceSys.Application/Services/EutrSynchronizeDataService.cs`
  (depends on T002, T003, T004), implementing `IEutrSynchronizeDataService`:
  - Constructor-inject `IComplDynamicsService`, `IEutrPurchaseAttachmentsRepository`, and
    `IRepository<EutrPurchaseAttachments,int>` (generic write path — same combination
    `EutrPurchaseAttachmentsService` already uses).
  - At the start of `SyncSalesOrderTemplatesAsync`, call `GetSalesIdsWithTemplateAsync(ct)` once and
    load the result into an in-memory `HashSet<string>` of existing `SalesId`s (research.md R5).
  - Loop pages of `GetDynRefePagedAsync(19, ..., ct)` with `pageSize = 1000`, cloning the exact
    while-loop shape from `ComplNotificationService.RefreshSalesOrderMissingComplianceAsync`
    (research.md R4) — continue until a page returns zero items or `page * pageSize >= TotalCount`.
  - For each item: read `SalesId`/`PurchId`/`TemplateCode` from
    `InterCompanyOriginalSalesId`/`RSVNRefPurchId`/`RSVNEutrTemplate` (available directly once T002
    lands); skip (increment `Skipped`) if any of the three is null/whitespace (FR-006), or if
    `SalesId` is already in the in-memory set (FR-003/FR-004); otherwise `AddAsync` a new
    `EutrPurchaseAttachments { SalesId, PurchId, TemplateCode, CreatedBy = "system", CreatedDate = UtcNow, UpdatedBy = "system", UpdatedDate = UtcNow }`,
    add `SalesId` to the in-memory set, and increment `Added` (FR-005, research.md R6).
  - No `IUnitOfWork` transaction wraps the loop (research.md R7): if an individual `AddAsync` throws,
    log it (Vietnamese comment explaining why, per existing `ComplNotificationService` per-item
    try/catch style) and continue to the next item rather than aborting the run.
  - If the D365 fetch itself throws (any page), stop the loop immediately, set
    `Success = false` and `Message` to describe the failure, and return the partial counts
    accumulated so far (FR-007, spec Edge Case on source failure).
  - On normal completion, set `Success = true` and `Message` to a short summary
    (e.g. `$"Fetched {TotalFetched}, added {Added}, skipped {Skipped}"`).

- [X] T006 [US1] Register the new service in
  `compliance-sys-api/src/ComplianceSys.Application/DependencyInjection.cs`: add
  `services.AddScoped<IEutrSynchronizeDataService, EutrSynchronizeDataService>();` near the existing
  `IEutrPurchaseAttachmentsService`/`IComplNotificationService` registrations (depends on T004, T005).

- [X] T007 [US1] Create `EutrSynchronizeDataController` in
  `compliance-sys-api/src/ComplianceSys.Api/Controllers/EutrSynchronizeDataController.cs` (depends
  on T004, T006), modeled directly on `ComplNotificationController`'s shape: `[Authorize]`,
  `[ApiController]`, `[Route("api/eutr-synchronize-data")]`, constructor-injecting
  `IEutrSynchronizeDataService`. Add one action:
  ```csharp
  [HttpGet("test-so-template-sync")]
  public async Task<IActionResult> TestSoTemplateSync(CancellationToken ct)
  {
      var result = await _eutrSynchronizeDataService.SyncSalesOrderTemplatesAsync(ct);
      return Ok(ApiResponse<EutrSynchronizeSummaryDto>.Ok(result, result.Message));
  }
  ```
  matching the `ApiResponse<T>.Ok(data, message)` pattern used by every existing
  `ComplNotificationController` action — see contracts/eutr-synchronize-data-test-so-template-sync.md
  for the exact response envelope.

- [X] T008 [P] [US1] Add unit tests in
  `compliance-sys-api/tests/ComplianceSysApi.UnitTests/Services/EutrSynchronizeDataServiceTests.cs`
  (depends on T005), covering spec.md's four Acceptance Scenarios: (1) new `SalesId` → row created
  with correct `PurchId`/`TemplateCode`; (2) `SalesId` already present → no new row, existing row
  untouched; (3) more D365 rows than one page → every page is fetched and evaluated (mock
  `IComplDynamicsService.GetDynRefePagedAsync` to return ≥2 pages); (4) running twice with unchanged
  source data → second run adds zero rows. Mock `IComplDynamicsService`,
  `IEutrPurchaseAttachmentsRepository`, and `IRepository<EutrPurchaseAttachments,int>`.
  *(Also added two edge-case tests: missing required field → skipped; D365 fetch throws → run stops,
  reports failure. All 6 tests pass; full suite otherwise unaffected — see T001 note.)*

**Checkpoint**: User Story 1 is fully functional and independently testable — the endpoint can be
called end-to-end per quickstart.md.

---

## Phase 4: Polish & Cross-Cutting Concerns

**Purpose**: Final validation across the whole feature.

- [ ] T009 Run the full [quickstart.md](./quickstart.md) validation (steps 1-8) against a real or
  test D365 connection: confirm the pre-fix empty result (step 1), the post-fix real data (step 2),
  new-row creation (steps 3-5), existing-row preservation (step 6), idempotency on a second run
  (step 7), and full multi-page coverage (step 8).
  **NOT COMPLETED** — this environment has no live D365 connection/credentials to exercise the real
  endpoint end-to-end. Unit tests (T008) cover the same scenarios against mocked dependencies;
  T009 still needs a human (or an environment with D365 access) to run before this feature is
  considered fully verified.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately.
- **Foundational (Phase 2)**: Depends on Setup (T001). BLOCKS all of User Story 1 — T003-T008 cannot
  produce real synced data until T002 lands (though T003/T004 can be *written* in parallel with T002
  since they touch different files; they just can't be meaningfully *verified* end-to-end until T002
  is done).
- **User Story 1 (Phase 3)**: Depends on Foundational (T002) completion for correct runtime behavior.
- **Polish (Phase 4)**: Depends on User Story 1 (all of Phase 3) being complete.

### Within User Story 1

- T003 and T004 have no code dependency on each other and can be done in parallel.
- T005 depends on T002 (correct data), T003 (DTO shape), and T004 (interface signature).
- T006 depends on T004 and T005 (both concrete types must exist to register them).
- T007 depends on T004 (interface to inject) and T006 (DI registration, so the controller resolves
  at runtime) — write order can be T007 before T006 if preferred, but T006 must land before the
  application can start with the controller present.
- T008 depends on T005 (the service under test must exist) but not on T006/T007.

### Parallel Opportunities

- T003 and T004 (Phase 3) — different files, no shared code.
- T002 (Phase 2) can be written in parallel with T003/T004 (Phase 3) since all three touch different
  files — the *runtime dependency* is only that T002 must be merged before end-to-end testing works.
- T008 can be written in parallel with T006/T007 once T005 exists.

---

## Parallel Example: User Story 1

```bash
# Launch these two together once Phase 2 (T002) is underway:
Task: "Create EutrSynchronizeSummaryDto in compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/EutrSynchronizeSummaryDto.cs"
Task: "Create IEutrSynchronizeDataService in compliance-sys-api/src/ComplianceSys.Application/Interfaces/Services/IEutrSynchronizeDataService.cs"

# After T005 lands, these two can run together:
Task: "Add unit tests in compliance-sys-api/tests/ComplianceSysApi.UnitTests/Services/EutrSynchronizeDataServiceTests.cs"
Task: "Register IEutrSynchronizeDataService in compliance-sys-api/src/ComplianceSys.Application/DependencyInjection.cs"
```

---

## Implementation Strategy

### MVP First (and only) Scope

Since this feature has a single P1 user story, the MVP **is** the whole feature:

1. Complete Phase 1: Setup (T001).
2. Complete Phase 2: Foundational (T002) — CRITICAL, blocks everything else.
3. Complete Phase 3: User Story 1 (T003-T008).
4. **STOP and VALIDATE**: Run Phase 4 (T009, quickstart.md) before considering this feature done.

### Suggested Sequencing for a Single Implementer

T001 → T002 → {T003, T004 in either order} → T005 → {T006, T008 in either order} → T007 → T009.

---

## Notes

- [P] tasks = different files, no dependencies.
- [US1] label maps every Phase 3 task to the feature's single user story for traceability.
- T002 (Foundational) is the highest-risk task: it edits a shared file (`ComplDynamicsService.cs`)
  used by many other `refType` values. Keep the diff scoped exactly to the `19` entry/case per
  research.md R2/R3 — do not reformat or touch neighboring entries.
- Commit after each task or logical group, per repository convention.
- No frontend (`compliance-client/`) tasks exist for this feature — it is backend-only (plan.md
  Constitution Check, Principle V: N/A).
