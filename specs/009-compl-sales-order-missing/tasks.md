---

description: "Task list template for feature implementation"
---

# Tasks: Sales Order Missing-Compliance Alert

**Input**: Design documents from `/specs/009-compl-sales-order-missing/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/, quickstart.md

**Tests**: Not explicitly requested in spec.md — no dedicated test tasks are included below (per task-generation rule: tests are optional unless the spec or user asks for them). The existing `compliance-sys-api/tests/ComplianceSysApi.UnitTests` project already has one test class per service (xUnit + Moq); adding `ComplNotificationServiceSalesOrderAlertTests.cs` / `ComplSoMissingRepositoryTests.cs` there later is a natural, optional follow-up but out of scope for this task list.

**Organization**: Tasks are grouped by user story (US1 = P1 refresh snapshot, US2 = P2 notify stakeholders) to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Include exact file paths in descriptions

## Path Conventions

Single existing backend project (`compliance-sys-api/`), Clean Architecture layers `ComplianceSys.Api` / `ComplianceSys.Application` / `ComplianceSys.Domain` / `ComplianceSys.Infrastructure`, per plan.md. No frontend paths — this feature has no UI.

---

## Phase 1: Setup

**Purpose**: Confirm a clean baseline; no new project, package, or scaffolding is required for this feature.

- [X] T001 Verify the existing solution builds cleanly (`dotnet build` from `compliance-sys-api/`) before making any changes, to establish a clean baseline. No new NuGet packages are needed — Dapper (`Res.Shared.Dapper`), `Newtonsoft.Json`, and Serilog used by this feature are already referenced by the existing projects.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The new `compl_so_missing` persistence path (entity, table, repository, DI wiring) that BOTH user stories read and write. Nothing in Phase 3 or 4 can compile/run until this phase is done.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T002 [P] Create `ComplSoMissing` entity in `compliance-sys-api/src/ComplianceSys.Domain/Entities/ComplSoMissing.cs` with every column from `compl_so_missing` per data-model.md (`SalesId`, `MasterId`, `MasterCode`, `MasterName`, `MasterValidFrom`, `MasterValidTo`, `MasterNumDayAlert`, `MasterDescription`, `MasterVersionNo`, `Status`, `Id`, `Code`, `Name`, `FileId`, `ValidFrom`, `ValidTo`, `NumDayAlert`, `VersionNo`, `ReplacedById`, `Description`, `AlertGroupsJson`, `ResponsibleGroupsJson`, `ConditionsJson`, `MappedRefTypeId`, `MappedRefTypeCode`, `MappedRefTypeName`, `MappedInputValue`).
- [X] T003 [P] Add migration `compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Migration/17_create_compl_so_missing.sql` — `CREATE TABLE IF NOT EXISTS compl_so_missing` with columns identical to `Sqls/Tables/compl_so_missing.sql`, plus a Vietnamese header comment following the convention in `16_create_compl_master_hierarchies.sql` (feature id, cross-reference, manual-apply-to-existing-DBs caveat) per research.md R7.
- [X] T004 Create `IComplSoMissingRepository` interface (place alongside the existing repository interfaces used by `ComplNotificationService`, e.g. `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Repositories/IComplSoMissingRepository.cs`) declaring `Task DeleteBySalesIdAsync(string salesId, CancellationToken ct = default)`, `Task InsertManyAsync(IEnumerable<ComplSoMissing> rows, CancellationToken ct = default)`, `Task<IEnumerable<ComplSoMissing>> GetAllAsync(CancellationToken ct = default)` (depends on T002).
- [X] T005 Implement `ComplSoMissingRepository : DapperRepository<ComplSoMissing, long>, IComplSoMissingRepository` in `compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/ComplSoMissingRepository.cs`, following the delete-then-insert raw-SQL Dapper pattern from `EutrTemplatesRepository.ReplaceDetailsAsync` per research.md R5 (`DELETE FROM compl_so_missing WHERE SalesId = @salesId`, then one parameterized `INSERT` per row in the same transaction; `GetAllAsync` = `SELECT * FROM compl_so_missing`) (depends on T002, T004).
- [X] T006 Register `IComplSoMissingRepository` → `ComplSoMissingRepository` in `compliance-sys-api/src/ComplianceSys.Infrastructure/DependencyInjection.cs`, following the existing `AddScoped<I..., ...>()` pattern used for the other repositories in that file (depends on T005).

**Checkpoint**: `compl_so_missing` is a fully wired persistence path (entity + table + repository + DI). User story implementation can now begin.

---

## Phase 3: User Story 1 - Refresh the missing-compliance snapshot for every open sales order (Priority: P1) 🎯 MVP

**Goal**: Recompute and persist the current MISSING compliance items for every open sales order, replacing any stale prior snapshot per sales order.

**Independent Test**: Invoke the refresh logic directly (e.g. a temporary manual call or a unit test constructed against `ComplNotificationService`) and query `compl_so_missing` to confirm every currently open sales order was evaluated and its stored rows match exactly what its compliance lookup currently reports as MISSING — with no leftovers from a previous run. (This story has no HTTP endpoint of its own yet; the endpoint is wired in User Story 2, consistent with spec.md's Independent Test wording for this story.)

### Implementation for User Story 1

- [X] T007 [P] [US1] Fix the `refType = 18` gap in `compliance-sys-api/src/ComplianceSys.Application/Services/ComplDynamicsService.cs`: add the missing `EntityMappings` entry `{ (int)ObjectType.SALE_ORDER_OPEN, ("RSVNSalesOrderOpenInvoiceCogs", "SalesId", "CustName") }` so `GetDynRefePagedAsync((int)ObjectType.SALE_ORDER_OPEN, ...)` reaches the existing (currently dead) "Open order" filter branch instead of short-circuiting to an empty result, per research.md R2.
- [X] T008 [US1] Add `IComplDynamicsService` and `IComplSoMissingRepository` as new constructor parameters of `ComplNotificationService` in `compliance-sys-api/src/ComplianceSys.Application/Services/ComplNotificationService.cs`, stored as new private readonly fields (depends on T006; `IComplDynamicsService` is already DI-registered, no new registration needed for it).
- [X] T009 [US1] Implement private method `RefreshSalesOrderMissingComplianceAsync(CancellationToken ct = default)` in `ComplNotificationService.cs`: call `_complDynamicsService.GetDynRefePagedAsync((int)ObjectType.SALE_ORDER_OPEN, request, ct)` to get open sales orders; loop each sales order, each iteration wrapped in its own `try/catch` that logs via `Log.Error(ex, "...", so.Code)` and continues to the next sales order (research.md R6, satisfies spec.md FR-011); per sales order, call `_viewCompliancesService.GetViewCompliancesAsync(new List<ViewCompliancesRequestDto> { new() { ReferenceType = ObjectType.SALE_ORDER, ReferenceValue = so.Code } }, so.DeliveryDate, so.CustAccount, ct)`, filter results to `Status == "MISSING"`, map each to a `ComplSoMissing` row with `SalesId = so.Code` per data-model.md's column table, then call `_complSoMissingRepository.DeleteBySalesIdAsync(so.Code, ct)` followed by `InsertManyAsync(missingRows, ct)` (only if `missingRows` is non-empty; the delete alone is sufficient to clear a now-fully-compliant sales order per spec.md Acceptance Scenario 3) (depends on T007, T008, T005).

**Checkpoint**: At this point, User Story 1 is fully functional and independently testable — calling `RefreshSalesOrderMissingComplianceAsync` leaves `compl_so_missing` accurately reflecting every open sales order's current MISSING items.

---

## Phase 4: User Story 2 - Notify responsible stakeholders after the snapshot is refreshed (Priority: P2)

**Goal**: After the snapshot is refreshed, send one consolidated email + in-app notification summarizing every current missing-compliance record, reachable via a manual/test trigger endpoint.

**Independent Test**: With `compl_so_missing` already populated (via User Story 1 or seeded directly), invoke the notify step and confirm exactly one alert is sent listing every current record addressed to the correct recipients; with the table empty, confirm no alert is sent.

### Implementation for User Story 2

- [X] T010 [P] [US2] Create `ComplSoMissingResponseDto` in `compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/ComplSoMissingResponseDto.cs`, mirroring `ComplSoMissing`'s fields plus parsed `AlertGroups`/`RespGroups` properties (`List<GroupEmailsDto>`, deserialized from `AlertGroupsJson`/`ResponsibleGroupsJson` via `JsonConvert.DeserializeObject`, same pattern as `ViewCompliancesResponseDto.AlertGroups`/`RespGroups`) per research.md R4 and data-model.md.
- [X] T011 [US2] Add `Task SendMailAndNotificationForSalesOrderMissing(IEnumerable<ComplSoMissingResponseDto> compliances, string? userEmail, SendAlertType sendAlerType, List<string>? additionEmails = null, string? additionMessage = null, string uri = "/compliance-management")` to `IComplNotificationService` in `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Services/IComplNotificationService.cs`, mirroring the existing `SendMailAndNotificationForMaster` signature shape (depends on T010).
- [X] T012 [US2] Implement `SendMailAndNotificationForSalesOrderMissing` in `ComplNotificationService.cs`: build the HTML summary table and email title/content the same way as the private `SendMailAndNotification`, but derive recipients by flattening each row's `AlertGroups`/`RespGroups` (`GroupEmailsDto.Emails`) instead of `SplitEmails` on a flat string (research.md R4); send via the existing `MailAlert.SendMailV2` call shape; build one `ComplNotification` per compliance × per recipient and persist via the existing `SaveNotificationsBatchAsync` helper (depends on T011).
- [X] T013 [US2] Add `Task SendSalesOrderAlertAsync()` to `IComplNotificationService` in `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Services/IComplNotificationService.cs` (depends on T012).
- [X] T014 [US2] Implement `SendSalesOrderAlertAsync()` in `ComplNotificationService.cs`: outer `try/catch` (`Log.Error(ex, "Error in SendSalesOrderAlertAsync")`, rethrow) mirroring `SendAlertAsync`'s shape; call `RefreshSalesOrderMissingComplianceAsync(ct)` (User Story 1, T009); then `var alertCompliances = (await _complSoMissingRepository.GetAllAsync(ct))?.ToList() ?? []`; if empty, `Log.Information(...)` and return without sending (spec.md FR-010); otherwise map to `ComplSoMissingResponseDto` and call `SendMailAndNotificationForSalesOrderMissing(alertCompliances, null, SendAlertType.AutoSendAlert)` (depends on T009, T013).
- [X] T015 [US2] Add `[HttpGet("test-sales-order-alert")]` action to `ComplNotificationController` in `compliance-sys-api/src/ComplianceSys.Api/Controllers/ComplNotificationController.cs`, mirroring `TestAlert()` exactly: call `await _complNotificationService.SendSalesOrderAlertAsync();` then `return Ok(ApiResponse<string>.Ok("", "TestSalesOrderAlert successfully"));` per contracts/test-sales-order-alert.md (depends on T014).

**Checkpoint**: All user stories should now be independently functional — `GET /api/notification/test-sales-order-alert` runs the full refresh-then-notify pipeline end-to-end.

---

## Phase 5: Update - Replace per-SalesId delete with delete-all-before-run (2026-08-04)

**Purpose**: The feature spec was revised to remove the `DeleteBySalesIdAsync` logic (delete scoped to one sales order, called inside the per-sales-order loop) and replace it with a single delete-all step run once before the loop begins (spec.md FR-006, plan.md 2026-08-04 update, research.md R5/R6). This phase updates the already-implemented code (T002–T015 above) to match; it does not touch the table schema, entity, DTO, controller, or notification/mail logic, which are unaffected by this change.

**⚠️ CRITICAL**: This phase modifies code paths shared by both user stories (the repository interface/implementation and the refresh method) — complete it fully before relying on `SendSalesOrderAlertAsync` behaving per the revised spec.

- [X] T019 [P] Modify `IComplSoMissingRepository` in `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Repositories/IComplSoMissingRepository.cs`: remove `Task DeleteBySalesIdAsync(string salesId, CancellationToken ct = default)`, add `Task DeleteAllAsync(CancellationToken ct = default)`. `InsertManyAsync`/`GetAllAsync` signatures are unchanged.
- [X] T020 [P] Modify `ComplSoMissingRepository` in `compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/ComplSoMissingRepository.cs`: remove the `DeleteBySalesIdAsync` method body (`DELETE FROM compl_so_missing WHERE SalesId = @salesId`), add `DeleteAllAsync` executing `DELETE FROM compl_so_missing` (no `WHERE` clause, no parameters) via the same `Connection.ExecuteAsync(new CommandDefinition(sql, transaction: Transaction, cancellationToken: ct))` shape used by the method it replaces (depends on T019).
- [X] T021 [US1] Modify `RefreshSalesOrderMissingComplianceAsync` in `compliance-sys-api/src/ComplianceSys.Application/Services/ComplNotificationService.cs`: remove the `await _complSoMissingRepository.DeleteBySalesIdAsync(so.Code, ct);` call currently inside the per-sales-order `try` block (right before `InsertManyAsync`); add a single `await _complSoMissingRepository.DeleteAllAsync(ct);` call before the `while (true)` open-sales-order paging loop starts, outside any per-item `try/catch` (research.md R6: a failure here must propagate to the method's outer `try/catch` and abort the run, not be swallowed per sales order) (depends on T020).
- [X] T022 Update the Vietnamese comments immediately above `RefreshSalesOrderMissingComplianceAsync` and above `ComplSoMissingRepository`/`IComplSoMissingRepository` (currently describing "xoa-roi-chen lai ... theo SalesId") to describe the new delete-all-once-then-insert-per-sales-order flow, per Constitution Principle IV (depends on T021). Also fixed a stale reference in `ComplSoMissing.cs`'s entity-level comment that named `DeleteBySalesIdAsync` directly.

**Checkpoint**: `compl_so_missing` is cleared exactly once per run, before any sales order is evaluated; no `DeleteBySalesIdAsync` reference remains anywhere in the codebase.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final checks that span both user stories.

- [X] T016 [P] Review all new/changed C# files (T002–T015) and confirm code comments are written in Vietnamese where a comment is warranted, per Constitution Principle IV (identifiers stay in English).
- [ ] T017 Run `specs/009-compl-sales-order-missing/quickstart.md` end-to-end against a local environment (fix the `compl_so_missing` migration if not yet applied, call `test-sales-order-alert`, verify the table and the sent alert) to validate spec.md's SC-001 through SC-004, including the revised idempotency check in quickstart.md step 4 (depends on Phase 5). **Not run this session** — requires a live MySQL + Dynamics-connected environment; needs manual verification.
- [X] T018 Confirm `dotnet build` succeeds for the whole `compliance-sys-api` solution after all changes (no regressions to `test-alert` / `SendAlertAsync`, which must remain unchanged; no remaining reference to `DeleteBySalesIdAsync`) (depends on Phase 5). Verified `ComplianceSys.Infrastructure` and `ComplianceSys.Application` build with 0 errors; `ComplianceSys.Api`'s own build was blocked only by file locks from a running `ComplianceSys.Api` process (PID 12136) on this machine, not a compile error — restart that process to pick up the change and re-verify the full solution build.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately.
- **Foundational (Phase 2)**: Depends on Setup — BLOCKS both user stories (neither story compiles without the `ComplSoMissing` entity and repository).
- **User Story 1 (Phase 3)**: Depends on Foundational only. No dependency on User Story 2.
- **User Story 2 (Phase 4)**: Depends on Foundational; also calls User Story 1's `RefreshSalesOrderMissingComplianceAsync` (T009) from within `SendSalesOrderAlertAsync` (T014) — so Phase 4 cannot be *fully* exercised end-to-end until Phase 3 is done, even though T010–T013 (DTO, interface additions, mail method) can be authored in parallel with Phase 3.
- **Update (Phase 5)**: Depends on Phases 3 and 4 both being complete (it modifies code those phases already wrote) — T019/T020 (repository layer) before T021 (call site in the US1 refresh method) before T022 (comments).
- **Polish (Phase 6)**: Depends on Phase 5 being complete (T017/T018 must validate the post-update behavior, not the superseded per-`SalesId` behavior).

### Within Each User Story

- Foundational entity/repository before any story logic that reads/writes `compl_so_missing`.
- US1: the `ComplDynamicsService` fix (T007) and the constructor-param addition (T008) before the refresh method itself (T009); the Phase 5 update (T019–T022) further modifies T009's method body.
- US2: DTO (T010) before interface addition (T011) before mail implementation (T012) before the orchestrating method (T013→T014) before the controller endpoint (T015).

### Parallel Opportunities

- T002 and T003 (different files: entity vs. SQL migration) can run in parallel.
- T007 (`ComplDynamicsService.cs`) can run in parallel with T008–T009 (`ComplNotificationService.cs`) — different files.
- T010 (`ComplSoMissingResponseDto.cs`) can be authored in parallel with Phase 3 (US1) — different file, no shared dependency beyond the already-complete Foundational phase.
- T019 and T020 (interface vs. implementation) can be drafted together, though T020's body depends on T019's final signature.
- T016 (comment review) can run in parallel with T017/T018 once both stories are code-complete.

---

## Parallel Example: Foundational + User Story 1 kickoff

```bash
# Once Setup (T001) is done, launch these together:
Task: "Create ComplSoMissing entity in compliance-sys-api/src/ComplianceSys.Domain/Entities/ComplSoMissing.cs"
Task: "Add migration compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Migration/17_create_compl_so_missing.sql"

# After T002/T003 land, and after T004-T006 complete the repository, US1 and the US2 DTO can proceed together:
Task: "Fix refType=18 gap in compliance-sys-api/src/ComplianceSys.Application/Services/ComplDynamicsService.cs"
Task: "Create ComplSoMissingResponseDto in compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/ComplSoMissingResponseDto.cs"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL — blocks both stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: confirm `compl_so_missing` refreshes correctly for a known open sales order, independent of any notification
5. This alone delivers no user-visible endpoint yet (the endpoint is added in US2) — treat US1 as an internal MVP checkpoint, not a deployable increment on its own, since spec.md's own User Story 2 Acceptance Scenario 3 ties the manual trigger to the combined refresh-then-notify flow.

### Incremental Delivery

1. Complete Setup + Foundational → persistence path ready
2. Add User Story 1 → validate the refresh logic directly → internal checkpoint
3. Add User Story 2 → validate end-to-end via `GET /api/notification/test-sales-order-alert` → deployable/demoable increment
4. Apply Phase 5 update (delete-all-before-run) → repository and refresh method now match the revised spec.md
5. Polish → confirm no regression to the existing `test-alert` flow, and no remaining `DeleteBySalesIdAsync` reference

---

## Notes

- [P] tasks = different files, no unmet dependencies
- [Story] label maps task to specific user story for traceability
- No test tasks were generated (see Tests note at the top); add them later under `compliance-sys-api/tests/ComplianceSysApi.UnitTests/Services/` following the existing one-class-per-service convention if desired
- Commit after each task or logical group
- Verify `test-alert` / `SendAlertAsync` still work unchanged after every task that touches `ComplNotificationService.cs` or `ComplNotificationController.cs`
- T019–T022 (Phase 5) are the only open tasks needed to bring the already-implemented code in line with the 2026-08-04 spec revision; T001–T016 remain checked off as still valid (unaffected by the revision) rather than being re-done.
