---

description: "Task list template for feature implementation"
---

# Tasks: EUTR Synchronize Data (Sales Order Template Sync + Purchase-Order Missing-Documentation Alert + Outbound Template Sync)

**Input**: Design documents from `/specs/011-eutr-synchronize-data/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: Not explicitly requested by the feature spec. Unit-test tasks (T008 for US1, T014 and T023
for US2, T032 for US3) are included to cover each story's acceptance scenarios, matching the existing
`ComplianceSysApi.UnitTests` convention already used elsewhere in this solution — not a TDD-first
requirement.

**Organization**: The spec defines three user stories, all P1: US1 (Sales Order Template Sync,
already implemented — see Phase 3), US2 (Purchase-Order Missing-Documentation Alert, added
2026-08-13, persisted to a new store per the 2026-08-14 update — see Phase 4, including its
"persistence redesign" sub-section), and US3 (Outbound Template Sync, added 2026-08-17 — see Phase
5). Each has its own foundational fix/prerequisite scoped to only what it needs; there is no
cross-story foundational work shared by all three.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, or US3)
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

## Phase 2: Foundational (Blocking Prerequisites for US1)

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

## Phase 4: User Story 2 - Detect and alert on purchase orders with incomplete EUTR documentation (Priority: P1)

**Goal**: A second, independent manually-triggered endpoint that reads the full D365 Purchase Order
reference dataset (refType 15), flags every purchase order missing its template, its SharePoint
document folder, or one or more of its template's document steps, and emails each flagged purchase
order's responsible Alert group a per-group Excel report — without touching User Story 1's sync
logic or any database table.

**Independent Test**: Per spec.md — trigger the endpoint against a D365 purchase-order dataset
containing a mix of purchase orders with no template, a template but no folder, a folder but
incomplete steps, and fully-complete purchase orders; confirm exactly one email per distinct
responsible Alert group is sent, each with an Excel attachment listing only that group's flagged
purchase orders (plus any "Missing template id" rows from the same run), and that fully-complete
purchase orders appear in no email/attachment. See quickstart.md Part B (steps 9-17) for the full
walkthrough.

### Implementation for User Story 2

- [X] T009 [P] [US2] In `compliance-sys-api/src/ComplianceSys.Application/Services/ComplDynamicsService.cs`,
  update the existing `case 15:` branch inside `MapDynamicsResponse` (around line 434-443) to
  additionally populate `OrderAccount = x.OrderAccount` on the returned `ComplDynReferenceResponseDto`,
  alongside the existing `Id`/`Code`/`Name`/`EutrTemplate` assignments — per data-model.md "User
  Story 2 — `RSVNEutrPurchOrders`" and research.md R9. Do not touch the `EntityMappings` entry for
  `15` (already correct) or any other `case` branch. Add a short Vietnamese comment noting this
  sources the new Purchase-Order Missing-Documentation report's "Vendor code" column.

- [X] T010 [P] [US2] Create `EutrPurchaseMissingSummaryDto` in
  `compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/EutrPurchaseMissingSummaryDto.cs`
  with fields `TotalFetched` (int), `FlaggedCount` (int), `GroupsNotified` (int), `Success` (bool),
  `Message` (string) — per data-model.md "User Story 2 — New DTO".

- [X] T011 [US2] Extend `IEutrSynchronizeDataService` in
  `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Services/IEutrSynchronizeDataService.cs`
  (depends on T010): add `Task<EutrPurchaseMissingSummaryDto> SendPurchaseMissingAlertAsync(CancellationToken ct = default);`
  alongside the existing `SyncSalesOrderTemplatesAsync` member — same interface, no new file.

- [X] T012 [US2] Implement `SendPurchaseMissingAlertAsync` in
  `compliance-sys-api/src/ComplianceSys.Application/Services/EutrSynchronizeDataService.cs`
  (depends on T009, T010, T011), extending the existing `EutrSynchronizeDataService` class:
  - Constructor-inject four more existing dependencies alongside the current ones:
    `ISharepointService` (`Shared.ExternalServices.Interfaces`), `IEutrTemplatesRepository`,
    `IEutrReferencesRepository`, `IGroupDetailRepository`, and `IConfiguration` (for
    `SharePointEutrPath`).
  - Loop pages of `GetDynRefePagedAsync(15, ..., ct)` (same `pageSize = 1000` while-loop shape as R4)
    to fetch every purchase order (`PurchId`, `OrderAccount`, `EutrTemplate`).
  - Loop pages of `GetDynRefePagedAsync(14, ..., ct)` once (same shape) to build a
    `Dictionary<string, string>` of `VendorAccountNumber -> VendorOrganizationName` (research.md R9).
  - Call `_sharepointService.GetFolders(_configuration["SharePointEutrPath"])` once; build a
    `HashSet<string>(StringComparer.OrdinalIgnoreCase)` of existing folder names (research.md R12) —
    do **not** call `CreateFolder` anywhere in this method.
  - Collect the distinct non-blank `EutrTemplate` values across all fetched purchase orders and call
    `IEutrTemplatesRepository.GetManyByCodesWithDetailsAsync(codes, ct)` once; build a
    `Dictionary<string, EutrTemplatesResponseDto>` keyed by `Code` (research.md R10).
  - Add a private helper `FlattenTemplateSteps(List<EutrTemplateDetailsResponseDto> details)` that
    walks the tree depth-first from `ParentId = 0`, ordering siblings by `DisplayOrder`, and returns
    an ordered `List<EutrTemplateDetailsResponseDto>` numbered implicitly by list position
    (research.md R11).
  - Collect the `PurchId`s of every purchase order that has a matched template AND an existing
    folder, and call `IEutrReferencesRepository.GetDocumentsByPoCodesAsync(purchIds, ct)` once;
    filter the result in-memory to `RefType == 15` and build a `HashSet<(string PoCode, long
    StepId)>` of already-covered pairs (research.md R13).
  - For each fetched purchase order, compute its `Note` per FR-010/FR-011/FR-013 (blank/unmatched
    template → `"Missing template id"`; matched template but folder missing → `"Have no PO
    folder"`; folder present → one `"{Template.Name} - step {n} : Missing"` line per flattened step
    with no `(PurchId, StepId)` match, `n` = 1-based position from `FlattenTemplateSteps`). Keep only
    purchase orders with a non-blank `Note` as `PurchaseMissingFinding` records (`PurchId`,
    `VendorCode = OrderAccount`, `VendorName` = vendor dictionary lookup by `OrderAccount` (blank if
    not found), `TemplateId = EutrTemplate`, `Note`, `AlertForGroupId` = matched template's
    `AlertFor` or `null`) — FR-014 discards everything else.
  - Group flagged findings by `AlertForGroupId` (excluding `null`); every finding with
    `AlertForGroupId == null` (i.e. `Note == "Missing template id"`) is added to **every** distinct
    group's row set for this run (spec clarification, FR-016).
  - Add a private helper `BuildPurchaseMissingExcelAttachment(List<PurchaseMissingFinding> rows)`
    mirroring `ComplNotificationService.BuildSalesOrderMissingExcelAttachment`'s `ClosedXML`
    technique: one worksheet, headers `Purch id`, `Vendor code`, `Vendor name`, `Template id`,
    `Note` in that exact order, one row per finding (research.md R14).
  - For each distinct group with at least one row: call
    `IGroupDetailRepository.GetEmailsByGroupIdsAsync(new[] { groupId }, ct)`; if it returns no
    usable recipient emails, log a warning and skip this group (do not increment `GroupsNotified`,
    do not throw, continue with remaining groups — spec Acceptance Scenario 10); otherwise build the
    Excel attachment (file name `eutr-purchase-missing-{groupId}-{yyyyMMddHHmmss}.xlsx`) and send via
    the existing `MailAlert`/`AttachmentInfo` helpers (same call shape as
    `ComplNotificationService.SendMailAndNotificationForSalesOrderMissing`'s `mailAlert.SendMailV2(...)`),
    then increment `GroupsNotified`.
  - Send **no** email and produce **no** attachment when the flagged-findings set is empty after
    evaluation (FR-018), or when every flagged finding has `AlertForGroupId == null` and there is
    consequently no distinct group to iterate at all (spec Assumptions — accepted gap, not a
    fallback-recipient feature).
  - This method performs **no writes** anywhere — no `IUnitOfWork`, no repository `AddAsync`/`Update`
    calls. If the D365 fetch (`refType 15` or `14`) or the SharePoint `GetFolders` call throws, stop
    immediately, set `Success = false` and `Message` to describe the failure, and return the partial
    counts accumulated so far — do **not** send any email for a partial/failed run.
  - On normal completion, set `Success = true` and `Message` to a short summary (e.g.
    `$"Fetched {TotalFetched}, flagged {FlaggedCount}, notified {GroupsNotified} group(s)"`).
  *(Implemented as specified. `dotnet build` on `ComplianceSys.Application`/`ComplianceSys.Api`
  succeeds with 0 compiler errors — the only build output is pre-existing MSB3027/MSB3021 file-copy
  warnings from a locally-running `ComplianceSys.Api` dev instance, same class of noise as T001's
  note, not a code issue. Note: `SendMailV2`'s underlying `MailAlert` is constructed inline
  (`new MailAlert(_configuration)`), same as `ComplNotificationService` — with no live SMTP config
  in tests it throws, which the per-group try/catch already treats as a skip-and-continue; this is
  an accepted, pre-existing testability limit shared with `ComplNotificationService` (which itself
  has no unit tests), not something introduced or fixed by this task.)*
  *(Post-implementation fix, found via live testing against real data: `GetManyByCodesWithDetailsAsync`
  filters only `IsDeleted = 0`, not `IsHide` — a template Code with a superseded version (Update 16
  Request change: old row `IsHide = 1`, new row `IsHide = 0`, same `Code`) returns 2+ rows for that
  Code, and the original direct `.ToDictionary(t => t.Code, ...)` threw
  `ArgumentException: An item with the same key has already been added` (observed live: `Templates-002`).
  Fixed by grouping by `Code` first and picking the row with `IsHide = 0` (falling back to the
  highest `VersionId` on a further tie) before building the dictionary — added a regression test
  reproducing this exact 2-rows-same-Code shape.)*

- [X] T013 [US2] Add `[HttpGet("test-purchase-missing")]` action to
  `compliance-sys-api/src/ComplianceSys.Api/Controllers/EutrSynchronizeDataController.cs` (depends
  on T011, T012), alongside the existing `TestSoTemplateSync` action, same controller/injected
  service instance:
  ```csharp
  [HttpGet("test-purchase-missing")]
  public async Task<IActionResult> TestPurchaseMissing(CancellationToken ct)
  {
      var result = await _eutrSynchronizeDataService.SendPurchaseMissingAlertAsync(ct);
      return Ok(ApiResponse<EutrPurchaseMissingSummaryDto>.Ok(result, result.Message));
  }
  ```
  matching the same `ApiResponse<T>.Ok(data, message)` pattern as `TestSoTemplateSync` — see
  contracts/eutr-synchronize-data-test-purchase-missing.md for the exact response envelope.

- [X] T014 [P] [US2] Add unit tests in
  `compliance-sys-api/tests/ComplianceSysApi.UnitTests/Services/EutrSynchronizeDataServiceTests.cs`
  (depends on T012), covering spec.md User Story 2's ten Acceptance Scenarios: (1) multi-page
  `refType=15` fetch evaluates every page (mock ≥2 pages); (2) blank/unmatched template → `"Missing
  template id"`, no folder/step check performed; (3) matched template, folder missing → `"Have no PO
  folder"`, no step check performed; (4) matched template, folder present, incomplete steps → one
  `"{Template} - step {n} : Missing"` line per missing step, correctly numbered; (5) fully-complete
  purchase order → not flagged; (6) only flagged purchase orders appear in the built report/email
  content; (7) findings spanning 2+ distinct Alert groups → one email per group, each with only that
  group's rows; (8) a `"Missing template id"` finding appears in every group's email that run; (9) no
  flagged purchase order → no email sent, `GroupsNotified = 0`; (10) a resolved group with no
  recipient emails is skipped and the run continues with remaining groups. Mock
  `IComplDynamicsService`, `ISharepointService`, `IEutrTemplatesRepository`,
  `IEutrReferencesRepository`, `IGroupDetailRepository`, and `IConfiguration`.
  *(Implemented as 9 test methods covering Scenarios 1, 2, 3, 4, 5/6, 7, 9, 10, plus a D365-failure
  edge case. Verified via `FlaggedCount`/`TotalFetched`/`GroupsNotified` and via
  `IGroupDetailRepository.GetEmailsByGroupIdsAsync` call verification (exact groupId arrays) for
  grouping/routing — NOT via inspecting the actual Note text or sent email content, since
  `PurchaseMissingFinding` and the Excel/email body are private to the method and `MailAlert` is
  constructed inline (same reason T012's note above gives); this is a knowledge/observability limit
  of the design, not a gap in what T012 implements. Also fixed a pre-existing compile break in this
  same file, unrelated to User Story 2: `CreateService()` was calling
  `EutrSynchronizeDataService`'s constructor with only 3 arguments while the class (already, from a
  prior T005 session) requires a 4th `IUnitOfWork` parameter — added a `Mock<IUnitOfWork>` field and
  passed it through, with no change to `SyncSalesOrderTemplatesAsync`'s behavior or its own 6
  existing tests. All 15 tests in this file pass; full suite: 105 passed, 1 failed (the same
  pre-existing unrelated `MappingConfigurationTests` failure noted in T001) — no regression.)*

**Checkpoint (2026-08-13 shape)**: User Story 2 is fully functional and independently testable —
the endpoint can be called end-to-end per quickstart.md Part B, without affecting User Story 1's
already-shipped behavior. *(Superseded below — findings are now persisted, not in-memory-only.)*

### Implementation for User Story 2 — persistence redesign (added 2026-08-14)

**Goal**: Replace the in-memory-only findings list from T012 with a dedicated store
(`eutr_purchase_missing`) that is fully cleared at the start of every run, repopulated with each
run's flagged purchase orders as they're found, and read back once (after evaluation finishes) to
build the per-group emails/Excel attachments — mirroring `compl_so_missing`'s
(feature 009) exact entity/repository/orchestration shape (research.md R17).

- [X] T017 [US2] Create the table (already done, ahead of `/speckit-plan`, per explicit user
  request): `compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Migration/19_create_eutr_purchase_missing.sql`
  (manual-apply migration) and `compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Tables/eutr_purchase_missing.sql`
  (auto-run-on-fresh-DB bootstrap copy, byte-identical `CREATE TABLE` body) — columns `Id` (int
  unsigned, PK, AUTO_INCREMENT), `PurchId` (varchar(50), NOT NULL), `VendorCode` (varchar(50)),
  `VendorName` (varchar(255)), `TemplateId` (varchar(50)), `Note` (text, NOT NULL),
  `AlertForGroupId` (bigint unsigned) — per data-model.md "User Story 2 — New persisted entity".
  *(Applied to the local dev DB (`compliance_sys_db_260601`) via `mysql.exe`; verified with
  `DESCRIBE eutr_purchase_missing` — 7 columns, `Id` PK auto_increment, matching the DDL exactly.)*

- [X] T018 [P] [US2] Create `EutrPurchaseMissing` in
  `compliance-sys-api/src/ComplianceSys.Domain/Entities/EutrPurchaseMissing.cs`: plain class (no
  `BaseEntity` — table has no audit columns, mirrors `ComplSoMissing.cs`'s shape), `[Table("eutr_purchase_missing")]`,
  properties `Id` (int), `PurchId` (string), `VendorCode` (string?), `VendorName` (string?),
  `TemplateId` (string?), `Note` (string), `AlertForGroupId` (long?) — per data-model.md.

- [X] T019 [P] [US2] Create `IEutrPurchaseMissingRepository` in
  `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Repositories/IEutrPurchaseMissingRepository.cs`:
  exactly three members, copied from `IComplSoMissingRepository`'s shape —
  `Task DeleteAllAsync(CancellationToken ct = default)`,
  `Task InsertManyAsync(IEnumerable<EutrPurchaseMissing> rows, CancellationToken ct = default)`,
  `Task<IEnumerable<EutrPurchaseMissing>> GetAllAsync(CancellationToken ct = default)`. Does **not**
  extend the generic `IRepository<,>` (same reasoning as `IComplSoMissingRepository` — research.md R17).

- [X] T020 [US2] Create `EutrPurchaseMissingRepository` in
  `compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/EutrPurchaseMissingRepository.cs`
  (depends on T018, T019), `: DapperRepository<EutrPurchaseMissing, int>, IEutrPurchaseMissingRepository` —
  direct structural copy of `ComplSoMissingRepository.cs`: `DeleteAllAsync` → `DELETE FROM
  eutr_purchase_missing` (no `WHERE`); `InsertManyAsync` → one `INSERT INTO eutr_purchase_missing
  (PurchId, VendorCode, VendorName, TemplateId, Note, AlertForGroupId) VALUES (@PurchId, @VendorCode,
  @VendorName, @TemplateId, @Note, @AlertForGroupId)` per row in a loop (`Id` omitted — auto-increment);
  `GetAllAsync` → `SELECT * FROM eutr_purchase_missing`.

- [X] T021 [US2] Register the new repository in
  `compliance-sys-api/src/ComplianceSys.Infrastructure/DependencyInjection.cs` (depends on T019, T020):
  add `services.AddScoped<IEutrPurchaseMissingRepository, EutrPurchaseMissingRepository>();` next to
  the existing `IComplSoMissingRepository`/`IEutrTemplatesRepository`/`IEutrReferencesRepository`
  registrations.

- [X] T022 [US2] Rewire `SendPurchaseMissingAlertAsync` in
  `compliance-sys-api/src/ComplianceSys.Application/Services/EutrSynchronizeDataService.cs` (depends
  on T012, T020, T021) to use the new store instead of the in-memory `findings` list:
  - Constructor-inject `IEutrPurchaseMissingRepository` alongside the existing dependencies.
  - Call `_eutrPurchaseMissingRepository.DeleteAllAsync(ct)` once, as the very first statement in the
    method — before the `refType=15` fetch even starts (FR-020). A failure here stops the run the
    same way a D365/SharePoint fetch failure already does (no partial run continues).
  - Keep the existing per-purchase-order evaluation loop (template/folder/step Note computation)
    exactly as T012 built it, but instead of only appending each flagged `PurchaseMissingFinding` to
    an in-memory list, also map it onto an `EutrPurchaseMissing` row (`PurchId`, `VendorCode`,
    `VendorName`, `TemplateId`, `Note`, `AlertForGroupId`) and call
    `_eutrPurchaseMissingRepository.InsertManyAsync([row], ct)` immediately for that one row
    (FR-021) — do not batch inserts until the end of the loop.
  - After the evaluation loop finishes (all purchase orders processed), call
    `_eutrPurchaseMissingRepository.GetAllAsync(ct)` once; use **that** result (not the in-memory
    list) as the basis for grouping by `AlertForGroupId` and building each group's email/Excel
    attachment (FR-022) — the grouping/shared-"Missing template id"-rows/per-group-send/skip-if-no-
    recipients logic itself is unchanged from T012.
  - `FlaggedCount` in the returned `EutrPurchaseMissingSummaryDto` is set from the count of rows
    actually inserted (or equivalently the read-back row count before per-group filtering) —
    unchanged in meaning from T012, just now sourced from the store instead of the in-memory list.

- [X] T023 [P] [US2] Update unit tests in
  `compliance-sys-api/tests/ComplianceSysApi.UnitTests/Services/EutrSynchronizeDataServiceTests.cs`
  (depends on T022): add a `Mock<IEutrPurchaseMissingRepository>` field, pass it through
  `CreateService()`'s constructor call, and default-stub `GetAllAsync` to return whatever rows were
  passed to `InsertManyAsync` during the same test run (so the existing T014 assertions on
  `FlaggedCount`/`GroupsNotified`/group-routing keep working unchanged against the new read-back
  path). Add new assertions verifying `DeleteAllAsync` is called exactly once per run, before any
  `InsertManyAsync` call, and that `InsertManyAsync` is called once per flagged purchase order with
  the correct `EutrPurchaseMissing` field values.
  *(Implemented: an in-memory `List<EutrPurchaseMissing>` backs `DeleteAllAsync`/`InsertManyAsync`/
  `GetAllAsync` so the existing 9 US2 tests keep passing unchanged against the new read-back path,
  plus 2 new tests — one verifying `DeleteAllAsync` called once and `InsertManyAsync` called once
  with the correct row values, one using a Moq `MockSequence` to verify `DeleteAllAsync` happens
  strictly before `InsertManyAsync`. All 18 tests in this file pass (9 US1 + 9 old US2... actually 6
  US1 + 12 US2); full suite: 108 passed, 1 failed (same pre-existing unrelated
  `MappingConfigurationTests` failure) — no regression. Also clarified, per explicit user direction,
  a pre-existing `TestSafetyMaxFlaggedRowsPerRun = 10` cap found already present in
  `EutrSynchronizeDataService.cs` (not written by any task in this file) — kept, but renamed from an
  unnamed `numCount`/mislabeled-as-"FR-015" magic number to a clearly-named, clearly-commented
  temporary test-safety constant.)*
  *(Post-implementation fix, found via live testing: the error log
  (`logs/error/compliance-sys-20260813.log`) showed "Loi gui email nhom 2" for a group with correct,
  non-empty recipient emails and correctly-flagged rows — the real cause was
  `BuildPurchaseMissingExcelAttachment`'s worksheet name, `"Purchase orders missing documentation"`
  (37 characters), exceeding Excel's 31-character sheet-name limit; `ClosedXML.Excel.Worksheets.Add`
  threw `ArgumentException`, silently caught by the per-group try/catch, so no email was ever built
  or sent for ANY group, despite the group/email/row data all being correct. Fixed by shortening the
  sheet name to `"Purchase orders missing"` (23 characters). Added a reflection-based regression test
  invoking the private `BuildPurchaseMissingExcelAttachment` directly (can't exercise it through
  `SendPurchaseMissingAlertAsync` in a unit test, since `MailAlert` needs real SMTP config) that
  parses the produced bytes back with `ClosedXML.Excel.XLWorkbook` and asserts the sheet name length
  is within Excel's 1-31 limit. 19 tests in this file pass; full suite: 109 passed, 1 failed (same
  pre-existing unrelated failure) — no regression.)*
  *(Post-implementation fix, per explicit user request: `IGroupDetailRepository.GetEmailsByGroupIdsAsync`
  (`compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/GroupDetailRepository.cs`) was
  not filtering by `IsActive` at all — it returned every `compl_group_email_detail` row for a group,
  including inactive/removed members, unlike the sibling `GetGroupEmailsByGroupIdsAsync` which
  already filters `IsActive = true`. Verified live for group 2: 4 rows total, only 1 `IsActive = 1`
  (`hienhnh@response.com.vn`) — the old query returned all 4 concatenated. Added `AND IsActive =
  true` to match the sibling method's convention; re-verified against the dev DB that group 2 now
  resolves to exactly the one active email. This method has no other caller in the codebase besides
  `EutrSynchronizeDataService`, so the fix is scoped to this feature with no risk to other alerts.
  Full suite still 109 passed, 1 pre-existing unrelated failure.)*

**Checkpoint**: User Story 2 now persists every run's flagged purchase orders to
`eutr_purchase_missing` (cleared and repopulated each run) and builds its emails from that table,
per spec FR-020/FR-021/FR-022 — independently testable per quickstart.md Part B steps 11-11a and 18.

---

## Phase 5: User Story 3 - Push eligible local Templates and their active Vendor mappings out to the ERP (Priority: P1) (added 2026-08-17)

**Goal**: A third, independent manually-triggered endpoint that reads every local `eutr_templates` row
matching `IsDeleted=0`/`IsHide=0`/`Status=1`, removes each one's existing ERP-side `RSVNEutrTemplates`
record via D365's `deleteTemplate` bound action (Phase 1, all eligible templates before Phase 2
starts), then pushes one `RSVNEutrTemplates` create record per eligible template's currently active
`eutr_template_references` Vendor mapping (Phase 2) — without touching User Story 1's sync logic,
User Story 2's alert logic, or any local table (this story only reads locally and writes to D365).

**Independent Test**: Per spec.md — trigger the endpoint against a local Template population with a
mix of eligible templates (one active mapping, several active mappings, zero active mappings) and
ineligible templates (Draft, hidden, or deleted); confirm the ERP received exactly one removal
request per eligible template and exactly one push per eligible template's currently active mapping,
with no request at all for ineligible templates or expired/future-dated mappings. See quickstart.md
Part C (steps 19-25) for the full walkthrough.

### Implementation for User Story 3

- [X] T026 [P] [US3] Create `EutrSynchronizeTemplatesSummaryDto` in
  `compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/EutrSynchronizeTemplatesSummaryDto.cs`
  with fields `TemplatesEligible` (int), `DeleteCallsSent` (int), `PushCallsSent` (int), `Success`
  (bool), `Message` (string) — per data-model.md "User Story 3 — New DTO".

- [X] T027 [P] [US3] In `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Repositories/IEutrTemplatesRepository.cs`,
  add `Task<IEnumerable<EutrTemplates>> GetEligibleForDynamicsSyncAsync(CancellationToken ct = default);`
  to the interface; implement it in
  `compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/EutrTemplatesRepository.cs`
  following the existing `SetStatusAsync`/`SetIsDefaultAsync` style (`Connection.QueryAsync<EutrTemplates>`
  with a `CommandDefinition`), SQL: `SELECT * FROM eutr_templates WHERE IsDeleted = 0 AND IsHide = 0
  AND Status = 1` — per data-model.md/research.md R18. Add a short Vietnamese comment noting this
  differs from `GetPagedAsync` by additionally filtering `Status` and returning plain entities, not a
  paged DTO.
  *(Implemented exactly as specified — appended after `ResolveAlertGroupIdByNameAsync`.)*

- [X] T028 [P] [US3] In `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Repositories/IEutrTemplateReferencesRepository.cs`,
  add `Task<IEnumerable<EutrTemplateReferences>> GetActiveByTemplateIdsAsync(IEnumerable<long> templateIds, DateTime asOfDate, CancellationToken ct = default);`
  to the interface; implement it in
  `compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/EutrTemplateReferencesRepository.cs`
  following the existing `GetByTemplateIdAsync` style (`Connection.QueryAsync<EutrTemplateReferences>`
  with a `CommandDefinition`), SQL: `SELECT id AS Id, TemplateId, VendorCode, FromDate, ToDate,
  CreatedBy, CreatedDate, UpdatedBy, UpdatedDate FROM eutr_template_references WHERE TemplateId IN
  @templateIds AND FromDate <= @asOfDate AND ToDate >= @asOfDate` — one call for every eligible
  template's `Id` at once, not one call per template — per data-model.md/research.md R19.
  *(Implemented exactly as specified — appended after `CopyReferencesAsync`.)*

- [X] T029 [US3] Extend `IEutrSynchronizeDataService` in
  `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Services/IEutrSynchronizeDataService.cs`
  (depends on T026): add `Task<EutrSynchronizeTemplatesSummaryDto> SyncTemplatesToDynamicsAsync(CancellationToken ct = default);`
  alongside the existing two members — same interface, no new file.

- [X] T030 [US3] Implement `SyncTemplatesToDynamicsAsync` in
  `compliance-sys-api/src/ComplianceSys.Application/Services/EutrSynchronizeDataService.cs` (depends
  on T027, T028, T029), extending the existing `EutrSynchronizeDataService` class:
  - Constructor-inject `Shared.ExternalServices.Interfaces.IDynamicService` alongside the existing
    dependencies.
  - Call `_eutrTemplatesRepository.GetEligibleForDynamicsSyncAsync(ct)` once; set `TemplatesEligible`
    to its count. If the call throws, set `Success = false`, `Message` describing the failure, and
    return immediately (no partial phase runs).
  - Build the two D365 URLs once from `_configuration["Dynamics:ApiUrl"]` (throw
    `InvalidOperationException` if unset, matching `SendPurchaseMissingAlertAsync`'s
    `SharePointEutrPath` null-check style): `{apiUrl}/data/RSVNEutrTemplates/Microsoft.Dynamics.DataEntities.deleteTemplate`
    and `{apiUrl}/data/RSVNEutrTemplates`.
  - **Phase 1**: loop every eligible template in order; call
    `_dynamicService.PostAsync(deleteUrl, new { Code = template.Code }, ct)`; increment
    `DeleteCallsSent` on success. If any call throws, log it (Vietnamese comment), set `Success =
    false`, `Message` reporting how many delete calls completed before the failure, and return
    immediately — do **not** proceed to Phase 2 (research.md R21, spec FR-025/Assumptions).
  - **Phase 2** (only reached once Phase 1 has completed for every eligible template): call
    `_eutrTemplateReferencesRepository.GetActiveByTemplateIdsAsync(eligibleTemplates.Select(t =>
    t.Id), DateTime.UtcNow.Date, ct)` once. Build a `Dictionary<long, EutrTemplates>` from the
    eligible-templates list keyed by `Id`. Loop every returned mapping; look up its `TemplateId` in
    that dictionary (skip if not found — should not happen since the query was scoped to the same
    `Id` list); call `_dynamicService.PostAsync(createUrl, new RSVNEutrTemplates { Code =
    template.Code, Name = template.Name, VendorCode = mapping.VendorCode }, ct)`; increment
    `PushCallsSent` on success. If any call throws, log it, set `Success = false`, `Message`
    reporting how many delete/push calls completed before the failure, and return immediately (same
    stop-the-run shape as Phase 1 — research.md R21).
  - On normal completion, set `Success = true` and `Message` to a short summary (e.g.
    `$"Eligible {TemplatesEligible}, deleted {DeleteCallsSent}, pushed {PushCallsSent}"`).
  - This method performs **no local writes** anywhere — no `IUnitOfWork`, no repository
    `AddAsync`/`Update` calls; every write this method performs is the `IDynamicService.PostAsync`
    call to D365.
  *(Implemented as specified, with one deliberate deviation from the task text: the Phase 1 delete
  payload uses a new private nested class `DeleteTemplateRequest { Code }` instead of an anonymous
  type `new { Code = template.Code }` — `IDynamicService.PostAsync<T>` is a generic method, and Moq
  can only Setup/Verify a generic method against a concrete, nameable `T`; an anonymous type can't be
  referenced from the test project. The wire-format JSON body is identical either way (`{"Code":
  "..."}`). `dotnet build` on `ComplianceSys.Application` succeeds with 0 compiler errors (only
  pre-existing warnings, same class of noise as prior tasks' notes).)*
  *(Post-implementation fix, prompted by explicit user request to compare against
  `DynController`'s existing `[HttpPost("reference")]`: decompiling `DynamicsParameterManager.BuildUrl()`
  (`Res.Shared.ExternalServices` 1.0.11 — the same package/version `IComplDynamicsService` and every
  `DynController` action already use) showed every existing Dynamics call in this codebase always
  appends `?cross-company=true` to its URL. Both `deleteUrl` and `createUrl` were missing it — since
  `RSVNEutrTemplates` has no `dataAreaId` field, this risked D365 scoping the write to one default
  company instead of behaving like every other call against this entity. Fixed by appending
  `?cross-company=true` to both URLs (research.md R20 updated with the full decompiled evidence and
  rationale). All 30 tests in this file (including the `DeleteUrl`/`CreateUrl` test constants, updated
  to match) still pass after the fix.)*

- [X] T031 [US3] Add `[HttpGet("test-synchronize-templates")]` action to
  `compliance-sys-api/src/ComplianceSys.Api/Controllers/EutrSynchronizeDataController.cs` (depends on
  T029, T030), alongside the existing two actions, same controller/injected service instance:
  ```csharp
  [HttpGet("test-synchronize-templates")]
  public async Task<IActionResult> TestSynchronizeTemplates(CancellationToken ct)
  {
      var result = await _eutrSynchronizeDataService.SyncTemplatesToDynamicsAsync(ct);
      return Ok(ApiResponse<EutrSynchronizeTemplatesSummaryDto>.Ok(result, result.Message));
  }
  ```
  matching the same `ApiResponse<T>.Ok(data, message)` pattern as the other two actions — see
  contracts/eutr-synchronize-data-test-synchronize-templates.md for the exact response envelope.
  *(Implemented exactly as specified. `dotnet build` on `ComplianceSys.Api` hits only the same
  pre-existing MSB3027/MSB3021 file-copy lock errors from a locally-running dev instance noted in
  T001/T012 — actual C# compilation of the controller succeeds with 0 code errors.)*

- [X] T032 [P] [US3] Add unit tests in
  `compliance-sys-api/tests/ComplianceSysApi.UnitTests/Services/EutrSynchronizeDataServiceTests.cs`
  (depends on T030), covering spec.md User Story 3's eight Acceptance Scenarios: (1) eligible template
  → `deleteTemplate` called with its `Code` before any push; (2) Draft/hidden/deleted template →
  excluded, no delete/push call at all; (3) eligible template with one currently active mapping → one
  push with matching `Code`/`Name`/`VendorCode`; (4) mapping whose date range excludes today → no
  push; (5) eligible template with 2+ active mappings → one push per mapping, same `Code`/`Name`,
  different `VendorCode`; (6) eligible template with zero active mappings → delete still happens, no
  push; (7) multi-item eligible/mapping sets are all processed (no early stop absent a failure); (8)
  re-running with unchanged mock data produces the same `DeleteCallsSent`/`PushCallsSent` counts both
  times. Also cover the two failure-handling edge cases: a `PostAsync` throw during Phase 1 stops the
  run before any Phase 2 call is made; a `PostAsync` throw during Phase 2 stops the run and does not
  affect templates already pushed. Add `Mock<IEutrTemplateReferencesRepository>` and
  `Mock<IDynamicService>` fields, wire them into `CreateService()`, and verify call counts/arguments
  via `_dynamicService.Verify(...)` rather than a live HTTP call.
  *(Implemented as 11 test methods — the 8 Acceptance Scenarios plus 3 edge cases: no eligible
  templates found (a variant of Scenario 2 at the service level, since eligibility filtering itself
  lives in the mocked repository), Phase 1 failure stops before Phase 2, Phase 2 failure stops the
  run with prior successes intact. Since `IDynamicService.PostAsync<T>` is a generic method, calls are
  matched/verified using Moq 4.20's `It.IsAny<It.IsAnyType>()` generic-type-parameter wildcard for the
  delete payload (whose concrete type, `DeleteTemplateRequest`, is private) and by the concrete,
  public `RSVNEutrTemplates` type for push-payload assertions (e.g. asserting `Code`/`Name`/
  `VendorCode` via `It.Is<RSVNEutrTemplates>(...)`). All 30 tests in this file pass (19 previous + 11
  new); full suite: 120 passed, 1 failed (same pre-existing unrelated `MappingConfigurationTests`
  failure noted in T001/T014/T023) — no regression.)*

### Correction for User Story 3 — left join, not inner join (added 2026-08-17)

**Goal**: Fix Phase 2 so an eligible template with zero currently active Vendor mappings still
receives exactly one push (with a blank Vendor Code), instead of being skipped entirely — per explicit
follow-up request ("bảng eutr_templates left join với eutr_template_references, nếu
eutr_template_references không tồn tại thì đẩy dữ liệu VendorCode = ''"), spec Acceptance Scenario 6/
FR-026/FR-027/FR-028 (corrected), research.md R24.

- [X] T034 [US3] Rewrite Phase 2 of `SyncTemplatesToDynamicsAsync` in
  `compliance-sys-api/src/ComplianceSys.Application/Services/EutrSynchronizeDataService.cs` (depends
  on T030) to iterate the **eligible templates** list (not the `activeMappings` list) as the outer
  loop: build `activeMappings.ToLookup(m => m.TemplateId)` once; for each eligible template, look up
  its mappings from that `Lookup` — if one or more, push one record per mapping exactly as before
  (`VendorCode = mapping.VendorCode`); if zero, push exactly one record with `VendorCode =
  string.Empty` instead of skipping the template. Keep the same stop-the-run-on-failure behavior in
  both branches (research.md R21, unchanged). Do not change `GetActiveByTemplateIdsAsync`'s SQL or
  return type (research.md R19 unaffected) — the left join is applied in C# only (research.md R24).
  *(Implemented exactly as specified. `dotnet build` on `ComplianceSys.Application` succeeds with 0
  compiler errors (only pre-existing warnings).)*

- [X] T035 [P] [US3] Update unit tests in
  `compliance-sys-api/tests/ComplianceSysApi.UnitTests/Services/EutrSynchronizeDataServiceTests.cs`
  (depends on T034) to match the corrected behavior: rename/rewrite
  `SyncTemplatesToDynamicsAsync_ShouldNotPush_WhenMappingDateRangeExcludesToday` →
  `..._ShouldPushBlankVendorCode_WhenMappingDateRangeExcludesToday` (now asserts `PushCallsSent == 1`
  with `VendorCode == ""`, not `Times.Never()`); rename/rewrite
  `..._ShouldDeleteButNotPush_WhenTemplateHasNoActiveMapping` →
  `..._ShouldDeleteAndPushBlankVendorCode_WhenTemplateHasNoActiveMapping` (now asserts
  `PushCallsSent == 1` with a verified blank-`VendorCode` call, not `PushCallsSent == 0`); update
  `..._ShouldProcessEveryEligibleTemplateAndMapping_WhenNoFailure`'s expected `PushCallsSent` from `2`
  to `3` (the third template, with no active mapping, now contributes one blank-`VendorCode` push) and
  add a verification for that push.
  *(Implemented as specified — all 3 tests renamed/updated. All 30 tests in this file still pass
  (same 30, none added/removed — this was a correction to existing tests, not new coverage); full
  suite: 120 passed, 1 failed (same pre-existing unrelated `MappingConfigurationTests` failure) — no
  regression.)*

**Checkpoint**: User Story 3 is fully functional and independently testable, now with corrected
left-join Phase 2 behavior — the endpoint can be called end-to-end per quickstart.md Part C, without
affecting User Story 1's or User Story 2's already-shipped behavior.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation across the whole feature (all three user stories).

- [ ] T024 Run [quickstart.md](./quickstart.md) Part A validation (steps 1-8) against a real or test
  D365 connection: confirm the pre-fix empty result (step 1), the post-fix real data (step 2),
  new-row creation (steps 3-5), existing-row preservation (step 6), idempotency on a second run
  (step 7), and full multi-page coverage (step 8).
  **NOT COMPLETED** — this environment has no live D365 connection/credentials to exercise the real
  endpoint end-to-end. Unit tests (T008) cover the same scenarios against mocked dependencies;
  T024 still needs a human (or an environment with D365 access) to run before User Story 1 is
  considered fully verified. *(Renumbered from T009, then T015 — no content change.)*

- [ ] T025 Run [quickstart.md](./quickstart.md) Part B validation (steps 9-18, including the
  2026-08-14 persistence steps 11a and 18) against a real or test D365 + SharePoint + mailbox + MySQL
  setup: confirm the `case 15` `OrderAccount` fix (step 9), the mixed test population's four outcomes
  (step 10), the store being cleared-then-repopulated (step 11a), each Note variant (steps 12-14),
  fully-complete exclusion (step 15), per-group email routing including the "Missing template id"
  join (step 16), the no-op case including the store ending up empty (step 17), and that emails are
  built from the store rather than from memory (step 18). Depends on T009-T014 and T017-T023 being
  complete; needs the same kind of live D365/SharePoint/mailbox/MySQL access as T024 (also not
  completable in this environment). *(Renumbered from T016.)*

- [ ] T033 Run [quickstart.md](./quickstart.md) Part C validation (steps 19-25) against a real or test
  D365 sandbox environment: confirm eligibility filtering excludes Draft/hidden/deleted templates
  (step 21), active-mapping pushes carry the correct `Code`/`Name`/`VendorCode` including the
  multi-mapping and expired-mapping cases (step 22), an eligible template with zero active mappings
  gets its ERP record removed then recreated with a blank Vendor Code — never left with zero ERP
  records (step 23, corrected 2026-08-17 per T034/T035), re-running with unchanged data is idempotent
  (step 24), and a forced D365 failure stops the run with an accurate partial-progress `Message`
  (step 25). Depends on T026-T032 **and** T034-T035 (the left-join correction) being complete; needs
  live D365 sandbox access (same class of gap as T024/T025 — not completable in this environment
  without D365 credentials).
  **NOT COMPLETED** — this environment has no live D365 sandbox connection/credentials to exercise the
  real endpoint end-to-end. Unit tests (T032, corrected by T035) cover the same eight Acceptance
  Scenarios plus the two failure-handling edge cases against mocked dependencies; T033 still needs a
  human (or an environment with D365 sandbox access) to run before User Story 3 is considered fully
  verified.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately.
- **Foundational (Phase 2)**: Depends on Setup (T001). BLOCKS all of User Story 1 — T003-T008 cannot
  produce real synced data until T002 lands (though T003/T004 can be *written* in parallel with T002
  since they touch different files; they just can't be meaningfully *verified* end-to-end until T002
  is done). Does **not** block User Story 2 — US2 has its own, separately-scoped fix (T009).
- **User Story 1 (Phase 3)**: Depends on Foundational (T002) completion for correct runtime behavior.
- **User Story 2 (Phase 4)**: Depends only on Setup (Phase 1) and its own scoped fix (T009) — does
  **not** depend on Phase 2 or Phase 3 completion. Both stories touch the same
  `EutrSynchronizeDataController`/`EutrSynchronizeDataService`/`IEutrSynchronizeDataService` files
  (adding a second action/method to each, not modifying the first), so in practice implement Phase 4
  after Phase 3 lands to avoid two people editing the same files concurrently — but there is no
  *functional* dependency between the two stories' behavior.
- **User Story 3 (Phase 5)**: Depends only on Setup (Phase 1) — does **not** depend on Phase 2, Phase
  3, or Phase 4 completion (it has no shared foundational fix; `IEutrTemplatesRepository`/
  `IEutrTemplateReferencesRepository` are extended additively, not fixed). All three stories touch
  the same `EutrSynchronizeDataController`/`EutrSynchronizeDataService`/`IEutrSynchronizeDataService`
  files (adding a third action/method to each, not modifying the first two), so in practice implement
  Phase 5 after Phase 4 lands to avoid concurrent edits to the same files — but there is no
  *functional* dependency between User Story 3's behavior and User Story 1's or User Story 2's.
- **Polish (Phase 6)**: T024 depends on User Story 1 (all of Phase 3) being complete. T025 depends on
  User Story 2 (all of Phase 4, including the T017-T023 persistence redesign) being complete. T033
  depends on User Story 3 (all of Phase 5, including the T034-T035 left-join correction) being
  complete.

### Within User Story 1

- T003 and T004 have no code dependency on each other and can be done in parallel.
- T005 depends on T002 (correct data), T003 (DTO shape), and T004 (interface signature).
- T006 depends on T004 and T005 (both concrete types must exist to register them).
- T007 depends on T004 (interface to inject) and T006 (DI registration, so the controller resolves
  at runtime) — write order can be T007 before T006 if preferred, but T006 must land before the
  application can start with the controller present.
- T008 depends on T005 (the service under test must exist) but not on T006/T007.

### Within User Story 2

- T009 and T010 have no code dependency on each other and can be done in parallel.
- T011 depends on T010 (DTO shape referenced by the new interface member).
- T012 depends on T009 (correct `OrderAccount` data), T010 (DTO shape), and T011 (interface
  signature) — and is written into the same class T005 already created, as a second method.
- T013 depends on T011 (interface to inject — already satisfied by Phase 3, extended here) and T012
  (the method it calls must exist and be implemented).
- T014 depends on T012 (the method under test must exist) but not on T013.
- T017 (table creation) has no code dependency on anything else and was completed first.
- T018 and T019 have no code dependency on each other (or on T017 beyond the table already existing)
  and can be done in parallel.
- T020 depends on T018 (entity shape) and T019 (interface signature).
- T021 depends on T019 (interface to register) and T020 (concrete type to register it as).
- T022 depends on T012 (the method it rewires must already exist), T020 (repository implementation),
  and T021 (DI registration, so the constructor-injected dependency resolves at runtime).
- T023 depends on T022 (the rewired method under test must exist).

### Within User Story 3

- T026, T027, and T028 have no code dependency on each other (three different files/interfaces) and
  can all be done in parallel.
- T029 depends on T026 (DTO shape referenced by the new interface member).
- T030 depends on T027 (eligible-templates query), T028 (active-mappings query), and T029 (interface
  signature) — and is written into the same class T005/T012 already created, as a third method.
- T031 depends on T029 (interface to inject — already satisfied by Phase 3, extended here) and T030
  (the method it calls must exist and be implemented).
- T032 depends on T030 (the method under test must exist) but not on T031.
- T034 depends on T030 (the method it rewrites Phase 2 of must already exist).
- T035 depends on T034 (the corrected behavior under test must exist) — it is a correction to T032's
  own test file, not new coverage, so T032 is a prerequisite transitively but not a direct one.

### Parallel Opportunities

- T003 and T004 (Phase 3) — different files, no shared code.
- T002 (Phase 2) can be written in parallel with T003/T004 (Phase 3) since all three touch different
  files — the *runtime dependency* is only that T002 must be merged before end-to-end testing works.
- T008 can be written in parallel with T006/T007 once T005 exists.
- T009 and T010 (Phase 4) — different files, no shared code.
- T014 can be written in parallel with T013 once T012 exists.
- T018 and T019 — different files, no shared code.
- Phase 4 (User Story 2) as a whole has no functional dependency on Phase 2/Phase 3 and could be
  staffed/implemented by a different person in parallel with Phase 3, at the cost of both people
  touching `EutrSynchronizeDataController.cs`/`EutrSynchronizeDataService.cs`/
  `IEutrSynchronizeDataService.cs` concurrently (merge-conflict risk, not a correctness risk).
- T026, T027, and T028 (Phase 5) — three different files, no shared code.
- T032 can be written in parallel with T031 once T030 exists.
- Phase 5 (User Story 3) as a whole has no functional dependency on Phase 2/Phase 3/Phase 4 and could
  be staffed/implemented by a different person in parallel with either, at the same
  `EutrSynchronizeDataController.cs`/`EutrSynchronizeDataService.cs`/`IEutrSynchronizeDataService.cs`
  merge-conflict risk (not a correctness risk) already noted for Phase 4.

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

## Parallel Example: User Story 2

```bash
# Launch these two together at the start of Phase 4:
Task: "Fix case 15 OrderAccount mapping in compliance-sys-api/src/ComplianceSys.Application/Services/ComplDynamicsService.cs"
Task: "Create EutrPurchaseMissingSummaryDto in compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/EutrPurchaseMissingSummaryDto.cs"

# After T012 lands, this can run alongside T013:
Task: "Add unit tests in compliance-sys-api/tests/ComplianceSysApi.UnitTests/Services/EutrSynchronizeDataServiceTests.cs"
```

## Parallel Example: User Story 2 — persistence redesign

```bash
# Launch these two together at the start of the persistence redesign:
Task: "Create EutrPurchaseMissing entity in compliance-sys-api/src/ComplianceSys.Domain/Entities/EutrPurchaseMissing.cs"
Task: "Create IEutrPurchaseMissingRepository in compliance-sys-api/src/ComplianceSys.Application/Interfaces/Repositories/IEutrPurchaseMissingRepository.cs"
```

## Parallel Example: User Story 3

```bash
# Launch these three together at the start of Phase 5:
Task: "Create EutrSynchronizeTemplatesSummaryDto in compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/EutrSynchronizeTemplatesSummaryDto.cs"
Task: "Add + implement GetEligibleForDynamicsSyncAsync on IEutrTemplatesRepository/EutrTemplatesRepository"
Task: "Add + implement GetActiveByTemplateIdsAsync on IEutrTemplateReferencesRepository/EutrTemplateReferencesRepository"

# After T030 lands, this can run alongside T031:
Task: "Add unit tests in compliance-sys-api/tests/ComplianceSysApi.UnitTests/Services/EutrSynchronizeDataServiceTests.cs"
```

---

## Implementation Strategy

### MVP First

User Story 1 is the original, already-shipped MVP:

1. Complete Phase 1: Setup (T001).
2. Complete Phase 2: Foundational (T002) — CRITICAL, blocks User Story 1.
3. Complete Phase 3: User Story 1 (T003-T008).
4. **STOP and VALIDATE**: Run Phase 6's T024 (quickstart.md Part A) before considering User Story 1
   fully done.

### Incremental Delivery (User Story 2)

5. Complete Phase 4: User Story 2 (T009-T014) — independent of Phase 2/3, addable at any time.
6. Complete Phase 4's persistence redesign (T017-T023) — replaces T012's in-memory findings list
   with the `eutr_purchase_missing` store; no functional change to what gets emailed to whom, only
   where the data is read from immediately before sending.
7. **STOP and VALIDATE**: Run Phase 6's T025 (quickstart.md Part B, including steps 11a/18) before
   considering User Story 2 fully done.

### Incremental Delivery (User Story 3, added 2026-08-17)

8. Complete Phase 5: User Story 3 (T026-T032) — independent of Phase 2/3/4, addable at any time; the
   reverse direction from User Story 1/2 (pushes local data to D365 instead of reading D365 in).
9. Complete Phase 5's left-join correction (T034-T035) — an eligible template with zero currently
   active Vendor mappings now still gets exactly one push, with a blank Vendor Code, instead of being
   skipped entirely.
10. **STOP and VALIDATE**: Run Phase 6's T033 (quickstart.md Part C) before considering User Story 3
    fully done.

### Suggested Sequencing for a Single Implementer

T001 → T002 → {T003, T004 in either order} → T005 → {T006, T008 in either order} → T007 → T024 →
{T009, T010 in either order} → T011 → T012 → {T013, T014 in either order} → T017 →
{T018, T019 in either order} → T020 → T021 → T022 → T023 → T025 →
{T026, T027, T028 in any order} → T029 → T030 → {T031, T032 in either order} → T034 → T035 → T033.

---

## Notes

- [P] tasks = different files, no dependencies.
- [US1]/[US2]/[US3] labels map every Phase 3/Phase 4/Phase 5 task to its user story for traceability.
- T002 (Foundational, US1) and T009 (US2) are each the highest-risk task in their story: both edit
  the same shared file (`ComplDynamicsService.cs`, different `case`s) used by many other `refType`
  values. Keep each diff scoped exactly to its own entry/case per research.md R2/R3 (T002) and R9
  (T009) — do not reformat or touch neighboring entries/cases. User Story 3 (T027/T028) has no
  equivalent shared-file risk — both new methods live on interfaces/implementations dedicated to this
  feature's own repositories, not a shared switch/dictionary used by unrelated `refType`s.
- T012 extends the same class T005 created (`EutrSynchronizeDataService`) with a second method —
  do not create a second service class or a second `IEutrSynchronizeDataService` file. T030 extends
  it further with a third method, same rule applies.
- T030 (User Story 3) is the first method in this codebase to call `IDynamicService.PostAsync` — it
  has no existing in-repo call site to copy the exact usage from (unlike every other task in this
  file, which clones an established pattern per research.md's R-numbered decisions); research.md R20
  is this task's primary reference instead.
- T022 modifies (not replaces) the body of the same `SendPurchaseMissingAlertAsync` method T012
  wrote — the template/folder/step Note-computation logic is unchanged; only where flagged findings
  end up (a new table instead of only an in-memory list) and where the per-group email-building step
  reads from (that table, read back once, instead of the in-memory list) changes.
- T020 (`EutrPurchaseMissingRepository`) is a direct structural copy of `ComplSoMissingRepository.cs`
  — resist the urge to "improve" it (e.g. switching to a bulk multi-row `INSERT`) beyond what the
  precedent already does; research.md R17 explicitly chose to match the existing pattern over a
  performance micro-optimization the precedent itself doesn't make.
- Commit after each task or logical group, per repository convention.
- No frontend (`compliance-client/`) tasks exist for this feature — it is backend-only (plan.md
  Constitution Check, Principle V: N/A), for all three user stories, including the 2026-08-14
  persistence redesign and the 2026-08-17 outbound Template sync.
