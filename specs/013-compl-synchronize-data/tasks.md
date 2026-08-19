---

description: "Task list template for feature implementation"
---

# Tasks: Compliance Synchronize Data (Sales Line + Variant Attributes)

**Input**: Design documents from `/specs/013-compl-synchronize-data/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: Not explicitly requested by the feature spec. Unit-test tasks (T016 for US1, T024 for US2)
are included to cover each story's acceptance scenarios, matching the existing
`ComplianceSysApi.UnitTests` convention already used by `EutrSynchronizeDataServiceTests.cs` — not a
TDD-first requirement.

**Organization**: The spec defines two user stories: US1 (P1, Sales Line + Product enrichment sync —
Phase 3 below) and US2 (P2, Variant Attributes sync — Phase 4 below). Unlike the 011 precedent (three
independently-triggerable endpoints), this feature exposes exactly **one** endpoint that runs both
phases in a single call (spec FR-001) — so both stories extend the *same* `RunAsync` method and the
*same* summary DTO/interface/controller, created once in the shared Foundational phase, rather than
each story adding its own separate action/DTO. US2 is still independently testable per spec's own
"Independent Test" description: its unit tests seed/mock the distinct-combination read directly,
without depending on US1's logic actually having run first.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1 or US2)
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
  Technical Context). *(Confirmed: `ComplianceSys.Domain`/`ComplianceSys.Application` build cleanly
  in isolation; full `dotnet build` on the whole solution hits only file-lock copy errors from a
  locally-running `ComplianceSys.Api` dev instance (PID 24708), not a code issue — same class of noise
  011's tasks.md T001 documented. Pre-existing test suite: 120 passed, 1 failed —
  `MappingConfigurationTests.ApplicationMappingProfiles_ShouldBeValid`, the same unrelated pre-existing
  AutoMapper config gap 011 already documented, untouched by this feature.)*

**Checkpoint**: Baseline verified — safe to start Phase 2.

---

## Phase 2: Foundational (Blocking Prerequisites for both user stories)

**Purpose**: Build the pieces both stories share — the additive D365 reference-type-6 field extension
US1's enrichment step needs, and the single response DTO / service interface both phases' logic will
be added to (since FR-001 requires one action, not one action per story).

**⚠️ CRITICAL**: No user story implementation can begin until this phase is complete.

- [X] T002 [P] In `compliance-sys-api/src/ComplianceSys.Domain/Dynamics/RSVNProductVariantAlls.cs`,
  add a new `public string Range { get; set; }` property and a matching `"Range", "Range"` entry in
  `FilterableFields`, alongside the existing `ProductCode`/`ConfigId`/`ProductVariantType`/
  `ProductDescription`/`ProductName`/`ProductVariant` members — per research.md R3. Add a short
  Vietnamese comment flagging that this field's presence on the live D365 `RSVNProductVariantAlls`
  OData entity has not been confirmed (the only local precedent for a product "Range" column is a
  different entity, `RSVNInventTables`, refType 4) and must be verified against D365 metadata during
  testing; if it does not exist there, this property always deserializes as `null`, which is
  acceptable per spec FR-006 ("blank when unavailable").

- [X] T003 [P] In `compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/ComplDynReferenceResponseDto.cs`,
  add five new nullable `string` properties: `ProductCode`, `ConfigId`, `Description`, `Type`,
  `Range` — alongside the existing `Id`/`Code`/`Name`/`CustAccount`/`SalesStatus`/etc. Do not modify,
  rename, or remove any existing property (research.md R3, data-model.md).

- [X] T004 In `compliance-sys-api/src/ComplianceSys.Application/Services/ComplDynamicsService.cs`,
  update the existing `case 6:` branch inside `MapDynamicsResponse` (depends on T002, T003) to
  additionally populate `ProductCode = x.ProductCode`, `ConfigId = x.ConfigId`, `Description =
  x.ProductDescription`, `Type = x.ProductVariantType`, `Range = x.Range` on the returned
  `ComplDynReferenceResponseDto`, alongside the existing `Id`/`Code`/`Name` assignments — per
  data-model.md's exact code block. Do not touch the `EntityMappings` dictionary (the `6` entry is
  already correct) or any other `case` branch.

- [X] T005 [P] Create `ComplSynchronizeDataSummaryDto` in
  `compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/ComplSynchronizeDataSummaryDto.cs`
  with fields `SalesLineFetched` (int), `SalesLineAdded` (int), `SalesLineSkipped` (int),
  `DistinctProductConfigCount` (int), `VariantAttributeAdded` (int), `Success` (bool), `Message`
  (string) — per data-model.md "New response DTO".

- [X] T006 [P] Create `IComplSynchronizeDataService` in
  `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Services/IComplSynchronizeDataService.cs`
  declaring a single member: `Task<ComplSynchronizeDataSummaryDto> RunAsync(CancellationToken ct = default);`
  (references the DTO from T005). One method, not one per story — FR-001 requires a single triggered
  action covering both phases.

**Checkpoint**: Foundation ready — User Story 1 implementation can begin (User Story 2 also depends on
this phase, but additionally depends on User Story 1's table/repository existing — see Dependencies).

---

## Phase 3: User Story 1 - Populate Sales Line + Product master data from the ERP (Priority: P1) 🎯 MVP

**Goal**: `RunAsync`'s first phase: read every page of D365 `RSVNSalesLineOpenInvoiceCogs`
(`sales-line`), enrich each record with its matching Product's Name/Description/Type/Range from D365
reference type 6 (`RSVNProductVariantAlls`, matched on ProductCode/ConfigId), and save one row per
retrieved Sales Line into a new table `compl_sync_sales_line` — fully cleared and repopulated each run.

**Independent Test**: Per spec.md — trigger the endpoint against a D365 Sales Line dataset containing
records whose Item ID + Config ID has a matching reference type 6 record and records that don't;
confirm `compl_sync_sales_line` ends up with one row per retrieved Sales Line, with Product
Code/Sales ID/Sales Status copied from the source and Name/Description/Type/Range populated only
where a match exists (blank otherwise). See quickstart.md steps 1-5.

### Implementation for User Story 1

- [X] T007 [US1] Create `compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Migration/22_create_compl_sync_sales_line.sql`
  (manual-apply migration) and the byte-identical
  `compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Tables/compl_sync_sales_line.sql`
  (auto-run-on-fresh-DB bootstrap copy) — `CREATE TABLE IF NOT EXISTS compl_sync_sales_line`: `Id`
  (int unsigned, PK, AUTO_INCREMENT), `ProductCode` (varchar(50), NULL), `ConfigId` (varchar(50),
  NULL), `SalesId` (varchar(50), NOT NULL), `SalesStatus` (varchar(50), NULL), `Name` (varchar(255),
  NULL), `Description` (varchar(1000), NULL), `Type` (varchar(50), NULL), `Range` (varchar(50), NULL)
  — per data-model.md "Phase 1 — New persisted entity". Apply the migration to the local dev DB and
  verify with `DESCRIBE compl_sync_sales_line`.
  *(Discovered while applying: `compl_sync_sales_line` was already pre-created ahead of `/speckit-plan`
  with a different real schema — `Id` bigint unsigned, `SalesId` nullable, `SalesStatus` **tinyint NOT
  NULL**, `ProductCode`/`ConfigId`/`ProductName`/`ProductDescription`/`ProductType`/`ProductRange` all
  **NOT NULL** (not `Name`/`Description`/`Type`/`Range`), plus a `CreatedDate` column — same situation
  011's `eutr_purchase_missing` table was in. Migration/Tables SQL files rewritten to match the real
  `SHOW CREATE TABLE` output exactly; data-model.md and research.md (new R9) updated accordingly. Applied
  via `mysql.exe` — confirmed via `DESCRIBE`/`SHOW CREATE TABLE` against `compliance_sys_db_260601`.)*

- [X] T008 [P] [US1] Create `ComplSyncSalesLine` in
  `compliance-sys-api/src/ComplianceSys.Domain/Entities/ComplSyncSalesLine.cs`: plain class (no
  `BaseEntity`, single `CreatedDate` column), `[Table("compl_sync_sales_line")]`, properties matching
  the real schema discovered in T007 (`Id` long, `SalesId` string?, `SalesStatus` byte, `ProductCode`/
  `ConfigId`/`ProductName`/`ProductDescription`/`ProductType`/`ProductRange` non-nullable `string`
  defaulting to `""`, `CreatedDate` DateTime) — per data-model.md (updated) / research.md R9.

- [X] T009 [P] [US1] Create `IComplSyncSalesLineRepository` in
  `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Repositories/IComplSyncSalesLineRepository.cs`:
  `Task DeleteAllAsync(CancellationToken ct = default)`,
  `Task InsertManyAsync(IEnumerable<ComplSyncSalesLine> rows, CancellationToken ct = default)`, and
  `Task<IEnumerable<(string ProductCode, string ConfigId)>> GetDistinctProductConfigCombinationsAsync(CancellationToken ct = default)`.
  Does **not** extend the generic `IRepository<,>` — narrow interface, mirroring
  `IComplSoMissingRepository`/`IEutrPurchaseMissingRepository` (research.md R6/R7).

- [X] T010 [US1] Implement `ComplSyncSalesLineRepository` in
  `compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/ComplSyncSalesLineRepository.cs`
  (depends on T008, T009): `: DapperRepository<ComplSyncSalesLine, long>, IComplSyncSalesLineRepository`
  — `DeleteAllAsync` → `DELETE FROM compl_sync_sales_line` (no `WHERE`); `InsertManyAsync` → one
  `INSERT` per row against the real column set (`Id` omitted — auto-increment), same structural shape
  as `ComplSoMissingRepository`; `GetDistinctProductConfigCombinationsAsync` → `SELECT DISTINCT
  ProductCode, ConfigId FROM compl_sync_sales_line WHERE ProductCode <> '' AND ConfigId <> ''`
  (research.md R7/R9 — both columns are `NOT NULL`, so "blank" means empty string, not SQL `NULL`),
  queried into a small private row class and projected to `(string, string)` tuples (Dapper does not
  map columns directly onto `ValueTuple` by name).

- [X] T011 [US1] Register the repository in
  `compliance-sys-api/src/ComplianceSys.Infrastructure/DependencyInjection.cs` (depends on T009,
  T010): add `services.AddScoped<IComplSyncSalesLineRepository, ComplSyncSalesLineRepository>();`
  near the other `Compl*`/`Eutr*` repository registrations.

- [X] T012 [US1] Create `ComplSynchronizeDataService` in
  `compliance-sys-api/src/ComplianceSys.Application/Services/ComplSynchronizeDataService.cs`
  (depends on T004, T006, T010, T011), implementing `IComplSynchronizeDataService`. Implemented per
  the task description, adapted to the real schema from T007/T009 (research.md R9): Phase 1 clears
  `compl_sync_sales_line`, bulk-fetches reference type 6 into a `(ProductCode, ConfigId) ->
  ComplDynReferenceResponseDto` dictionary (first match wins), then loops `FetchAllSalesLinesAsync`
  (T013), skipping records with blank `ItemId`/`SalesId` (FR-007) and inserting one
  `ComplSyncSalesLine` row per remaining record with `SalesStatus` defensively parsed to `byte`
  (`0` on parse failure) and `ProductName`/`ProductDescription`/`ProductType`/`ProductRange` set to
  `""` when unmatched (NOT NULL columns — FR-005/FR-006 "blank" = empty string here, not SQL NULL).
  Any D365 fetch failure stops the run immediately (FR-017). Phase 2 body (T022) appended in the same
  method, after Phase 1's loop, not returning early.

- [X] T013 [US1] Add a private helper `FetchAllSalesLinesAsync(CancellationToken ct)` inside
  `ComplSynchronizeDataService` (same file, depends on T012) that pages through D365 entity
  `RSVNSalesLineOpenInvoiceCogs` directly via the injected `IDynamicService`/`DynamicsParameterManager`
  — the same low-level building blocks `DynController.RSVNSalesLineOpenInvoiceCogs`
  (`[HttpGet("sales-line")]`) already uses, deserializing via
  `JsonConvert.DeserializeObject<OdataMapper<RSVNSalesLineOpenInvoiceCogs>>(data)` (`OdataMapper<T>.Items`,
  confirmed via decompiling `Res.Shared.ExternalServices` 1.0.11 — not `.Value`/`.value`). Pages with
  `top = 1000`, stopping when a page returns fewer than `top` items (no `@odata.count` on this raw
  endpoint — research.md R1/R2). Calls `_paramManager.Clear()` before every build, since
  `DynamicsParameterManager` is a scoped instance shared with `IComplDynamicsService`/`DynController`
  within the same request and `AddFilter` accumulates across calls if not cleared (confirmed via
  decompile — same defensive pattern `ComplDynamicsService.GetFromDynamics<T>` already uses).

- [X] T014 [US1] Register the new service in
  `compliance-sys-api/src/ComplianceSys.Application/DependencyInjection.cs` (depends on T006, T012):
  add `services.AddScoped<IComplSynchronizeDataService, ComplSynchronizeDataService>();` near the
  existing `IEutrSynchronizeDataService` registration.

- [X] T015 [US1] Create `ComplSynchronizeDataController` in
  `compliance-sys-api/src/ComplianceSys.Api/Controllers/ComplSynchronizeDataController.cs` (depends
  on T006, T014), modeled directly on `EutrSynchronizeDataController`'s shape: `[Authorize]`,
  `[ApiController]`, `[Route("api/compl-synchronize-data")]`, constructor-injecting
  `IComplSynchronizeDataService`. One action:
  ```csharp
  [HttpGet("test-compl-synchronize-data")]
  public async Task<IActionResult> TestComplSynchronizeData(CancellationToken ct)
  {
      var result = await _complSynchronizeDataService.RunAsync(ct);
      return Ok(ApiResponse<ComplSynchronizeDataSummaryDto>.Ok(result, result.Message));
  }
  ```
  matching the `ApiResponse<T>.Ok(data, message)` pattern used by `EutrSynchronizeDataController` —
  see contracts/compl-synchronize-data-test-compl-synchronize-data.md for the exact response
  envelope.

- [X] T016 [P] [US1] Add unit tests in
  `compliance-sys-api/tests/ComplianceSysApi.UnitTests/Services/ComplSynchronizeDataServiceTests.cs`
  (depends on T012, T013), covering spec.md User Story 1's six Acceptance Scenarios: (1) multi-page
  Sales Line fetch evaluates every page (mock ≥2 pages via the injected `IDynamicService`); (2)
  `ProductCode`/`SalesId`/`SalesStatus` copied verbatim from a Sales Line record; (3) a Sales Line
  record whose Item ID + Config ID matches a type-6 reference record gets
  `Name`/`Description`/`Type`/`Range` populated from that match; (4) no match → row still saved with
  those four fields blank; (5) a Sales Line record missing Item ID or Sales ID is skipped, no row
  created; (6) empty Sales Line source → zero rows added, `Success = true`. Mock
  `IComplDynamicsService`, `IComplSyncSalesLineRepository`, and `IDynamicService`.
  *(Implemented as 6 test methods (one per scenario) plus a shared constructor default-stub setup,
  mirroring `EutrSynchronizeDataServiceTests`'s style. `IDynamicService.QueryAsync` responses are
  built as JSON matching `OdataMapper<T>`'s `"value"`/`Items` shape via `JsonConvert.SerializeObject`.
  The multi-page test generates exactly 1000 synthetic items for page 1 (same technique
  `EutrSynchronizeDataServiceTests.SyncSalesOrderTemplatesAsync_ShouldFetchAllPages_WhenDataSpansMultiplePages`
  already uses) since the paging loop's only termination condition is "page returned fewer than
  1000 items" (research.md R1/R2 — no `@odata.count` on this raw endpoint). `DynamicsParameterManager`
  is a real instance (not mockable — concrete class), constructed the same way
  `DynamicsDataServiceTests`/`MasterDefaultRefSyncServiceTests` already do (in-memory `IConfiguration`
  with `Dynamics:ApiUrl` set). All 6 tests pass.)*

**Checkpoint**: User Story 1's phase of the run is fully functional and independently testable —
`compl_sync_sales_line` is correctly populated end-to-end (Phase 2 of `RunAsync` is still a no-op
until Phase 4 lands).

---

## Phase 4: User Story 2 - Derive distinct Product/Config combinations and populate Variant Attribute data (Priority: P2)

**Goal**: Extend `RunAsync` with its second phase: after Phase 1 fully completes, derive the distinct
Product Code + Config ID combinations from `compl_sync_sales_line`, look up each combination's Variant
Attribute data from D365 `ProductVariantAttributes` (`product-variant-attributes`), and save the
results into a new table `compl_sync_variant_attributes` — fully cleared and repopulated each run.

**Independent Test**: Per spec.md — with `compl_sync_sales_line` populated (via User Story 1, or
seeded/mocked directly with rows sharing the same Product Code + Config ID and rows with distinct
combinations), confirm `compl_sync_variant_attributes` ends up with data for exactly one Variant
Attribute lookup per distinct combination — never once per Sales Line row. Because Phase 2 always
reads its input via `IComplSyncSalesLineRepository.GetDistinctProductConfigCombinationsAsync` (not
from Phase 1's in-memory state, research.md R7), this story's unit tests can mock that call directly
and verify Phase 2's behavior without depending on Phase 1's logic having actually run. See
quickstart.md steps 6-9.

### Implementation for User Story 2

- [X] T017 [US2] Create `compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Migration/23_create_compl_sync_variant_attributes.sql`
  and the byte-identical
  `compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Tables/compl_sync_variant_attributes.sql`
  — per data-model.md "Phase 2 — New persisted entity". Apply the migration to the local dev DB and
  verify with `DESCRIBE compl_sync_variant_attributes`.
  *(Same discovery as T007: `compl_sync_variant_attributes` was also already pre-created ahead of
  `/speckit-plan`. Real schema: `Id` bigint unsigned, `ProductCode` nullable, `ConfigId`/`GroupId`/
  `GroupValue`/`AttributeType`/`AttributeTypeName`/`AttributeValue`/`AttributeValueName`/`CreatedDate`
  all NOT NULL — with a `GroupId` column that has no corresponding property on the existing
  `ProductVariantAttributes` domain model, and **no** `DistinctProductVariant`/`ProductVariant`
  columns at all (both present on the domain model but not persisted by this feature). Migration/
  Tables SQL rewritten to match; data-model.md/research.md (R9) updated. Confirmed via `SHOW CREATE
  TABLE` against `compliance_sys_db_260601` — 0 existing rows.)*

- [X] T018 [P] [US2] Create `ComplSyncVariantAttributes` in
  `compliance-sys-api/src/ComplianceSys.Domain/Entities/ComplSyncVariantAttributes.cs`: plain class
  (no `BaseEntity`, single `CreatedDate` column), `[Table("compl_sync_variant_attributes")]`,
  properties matching the real schema discovered in T017 (`Id` long, `ProductCode` string?, `ConfigId`/
  `GroupId`/`GroupValue`/`AttributeTypeName`/`AttributeValueName` non-nullable `string` defaulting to
  `""`, `AttributeType`/`AttributeValue` long, `CreatedDate` DateTime) — per data-model.md (updated) /
  research.md R9.

- [X] T019 [P] [US2] Create `IComplSyncVariantAttributesRepository` in
  `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Repositories/IComplSyncVariantAttributesRepository.cs`:
  `Task DeleteAllAsync(CancellationToken ct = default)` and
  `Task InsertManyAsync(IEnumerable<ComplSyncVariantAttributes> rows, CancellationToken ct = default)`
  — narrow interface, mirroring `IComplSyncSalesLineRepository`'s shape (research.md R6).

- [X] T020 [US2] Implement `ComplSyncVariantAttributesRepository` in
  `compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/ComplSyncVariantAttributesRepository.cs`
  (depends on T018, T019): `: DapperRepository<ComplSyncVariantAttributes, long>,
  IComplSyncVariantAttributesRepository` — `DeleteAllAsync` → `DELETE FROM
  compl_sync_variant_attributes` (no `WHERE`); `InsertManyAsync` → one `INSERT` per row against the
  real column set (`Id` omitted — auto-increment; no `DistinctProductVariant`/`ProductVariant`
  columns to insert), same structural shape as `ComplSyncSalesLineRepository`.

- [X] T021 [US2] Register the repository in
  `compliance-sys-api/src/ComplianceSys.Infrastructure/DependencyInjection.cs` (depends on T019,
  T020): add `services.AddScoped<IComplSyncVariantAttributesRepository, ComplSyncVariantAttributesRepository>();`
  near the `IComplSyncSalesLineRepository` registration (T011).

- [X] T022 [US2] Extend `RunAsync` in
  `compliance-sys-api/src/ComplianceSys.Application/Services/ComplSynchronizeDataService.cs` (depends
  on T012, T020, T021), appending Phase 2's logic after Phase 1's loop (only reached when Phase 1
  completed without a fetch error, per T012's early-return-on-failure). Constructor-inject
  `IComplSyncVariantAttributesRepository` alongside the existing dependencies. Body:
  - Call `_complSyncSalesLineRepository.GetDistinctProductConfigCombinationsAsync(ct)`; set
    `DistinctProductConfigCount` to the returned count (FR-009/FR-010 — the repository query already
    excludes blank `ProductCode`/`ConfigId` rows, T010).
  - Call `_complSyncVariantAttributesRepository.DeleteAllAsync(ct)` before looking up any combination
    (FR-012).
  - For each distinct `(ProductCode, ConfigId)`: call `FetchVariantAttributesAsync(productCode,
    configId, ct)` (T023); if it returns one or more records, map each to a
    `ComplSyncVariantAttributes` row (carrying that combination's `ProductCode`/`ConfigId` alongside
    the D365 fields) and `InsertManyAsync(rows, ct)`, incrementing `VariantAttributeAdded` by the
    number of rows inserted; zero returned records is not an error — continue to the next combination
    (FR-013/FR-014).
  - If any Variant Attribute lookup throws, stop immediately, set `Success = false` and `Message`
    describing the failure (including which phase was in progress) and the counts accumulated across
    both phases so far, and return (FR-017).
  - On reaching the end without any failure in either phase, set `Success = true` and `Message` to a
    short two-phase summary (e.g. `$"Sales line: fetched {SalesLineFetched}, added {SalesLineAdded},
    skipped {SalesLineSkipped}. Distinct product/config: {DistinctProductConfigCount}. Variant
    attributes added: {VariantAttributeAdded}"`, per contracts/compl-synchronize-data-test-compl-synchronize-data.md).

- [X] T023 [US2] Add a private helper `FetchVariantAttributesAsync(string productCode, string
  configId, CancellationToken ct)` inside `ComplSynchronizeDataService` (same file, depends on T022)
  that queries D365 entity `ProductVariantAttributes` via the same `IDynamicService`/
  `DynamicsParameterManager` building blocks as T013 — same low-level pattern
  `DynController.ProductVariantAttributes` (`[HttpGet("product-variant-attributes")]`) already uses —
  with filter `$"ProductCode eq '{Helper.EscapeODataValue(productCode)}' and ConfigId eq
  '{Helper.EscapeODataValue(configId)}'"` (research.md R5; use the existing `Helper.EscapeODataValue`
  utility already used elsewhere in `ComplDynamicsService.cs` for OData string escaping), deserializing
  via `JsonConvert.DeserializeObject<OdataMapper<ProductVariantAttributes>>(data)`. A single call per
  combination is sufficient — no paging loop needed here (one Product+Config combination's attribute
  set is not expected to span multiple pages of 50+ rows, unlike Sales Line/reference data).

- [X] T024 [P] [US2] Add unit tests in
  `compliance-sys-api/tests/ComplianceSysApi.UnitTests/Services/ComplSynchronizeDataServiceTests.cs`
  (depends on T022, T023), covering spec.md User Story 2's six Acceptance Scenarios: (1) multiple
  Sales Line rows sharing the same Product Code + Config ID → exactly one Variant Attribute lookup for
  that combination, not one per row (mock `GetDistinctProductConfigCombinationsAsync` to return the
  already-deduplicated set, and verify `IDynamicService.QueryAsync`/equivalent is called exactly once
  per distinct combination); (2) several distinct combinations → each looked up exactly once, with the
  correct Product/Config filter; (3) a lookup that returns data → saved to
  `compl_sync_variant_attributes` associated with that combination's Product Code/Config ID; (4) the
  repository-level distinct-combination query already excludes blank Product Code/Config ID rows
  (T010) — assert Phase 2 never attempts a lookup with a blank key; (5) a lookup that returns no data
  → no row added, `Success` stays `true`, remaining combinations still processed; (6) Phase 2 is only
  reached after Phase 1 completes without error (verify via a Moq `MockSequence` that
  `GetDistinctProductConfigCombinationsAsync` is called after the Phase 1 Sales Line fetch, and that a
  forced Phase 1 failure prevents any Phase 2 call). Mock `IComplSyncSalesLineRepository`,
  `IComplSyncVariantAttributesRepository`, and `IDynamicService`.
  *(Implemented as 7 test methods: the 6 Acceptance Scenarios plus a D365-failure edge case (stop
  mid-run, `Success = false`, `GetDistinctProductConfigCombinationsAsync` never called). Scenario 2's
  "correct Product/Config filter" and Scenario 4's "blank key never looked up" are verified indirectly
  — via `QueryAsync` call-count matching the number of distinct combinations supplied, and via the
  repository's own `GetDistinctProductConfigCombinationsAsync` filtering (already covered by T010's
  `WHERE ProductCode <> '' AND ConfigId <> ''`) rather than decoding the opaque D365 URL string built
  by `DynamicsParameterManager.BuildUrl()` — asserting on literal OData filter substrings inside a URL
  whose exact encoding is controlled by an external package would be brittle. Scenario 6 verified via
  `MockSequence` across `DeleteAllAsync` (Phase 1) → `GetDistinctProductConfigCombinationsAsync` →
  `DeleteAllAsync` (Phase 2). All 7 tests pass; combined with T016's 6, all 13 tests in
  `ComplSynchronizeDataServiceTests.cs` pass. Full suite: 133 passed, 1 failed (same pre-existing
  unrelated `MappingConfigurationTests` failure noted in T001) — no regression.)*

**Checkpoint**: Both user stories complete — a single `RunAsync` call fully populates both
`compl_sync_sales_line` and `compl_sync_variant_attributes` each run.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Final validation across the whole feature (both user stories).

- [ ] T025 Verify research.md R3's open question: confirm against the live D365 environment (UI,
  `$metadata` endpoint, or a manual `GET` against `RSVNProductVariantAlls`) whether a `Range` field
  actually exists on that entity — and, per R9, whether `ProductVariantAttributes` actually exposes a
  `GroupId` field, and whether `RSVNSalesLineOpenInvoiceCogs.SalesStatus` serializes as a small
  integer or a string label. If any assumption is wrong, update research.md and data-model.md
  accordingly; a missing field is not itself an error (spec FR-006 already treats blank enrichment as
  valid), but a `SalesStatus` that doesn't parse to a number would silently store `0` for every row,
  which is worth knowing about explicitly rather than leaving unverified.
  **NOT COMPLETED** — this development environment has no live D365 connection/credentials to verify
  against. The implementation (T002, T004, ComplSyncSalesLine/ComplSyncVariantAttributes population)
  degrades safely either way (blank/`0` on a missing or unparseable field, per FR-006), but a human (or
  an environment with D365 access) should confirm this before the feature is considered fully verified.

- [ ] T026 Run [quickstart.md](./quickstart.md) steps 1-10 against a real or test D365 connection:
  confirm the new `product-variant-info` endpoint (step 1, updated per research.md R10), Phase 1
  population and enrichment correctness
  including the matched/unmatched cases (steps 2-5), full multi-page Sales Line coverage (step 5),
  distinct Product/Config grouping and the one-lookup-per-combination behavior (step 6), Phase 2
  population (step 7), phase ordering (step 8), idempotency on a second run (step 9), and failure
  handling (step 10). Depends on Phase 3 and Phase 4 being complete; needs live D365 access this
  development environment may not have — if so, note that gap explicitly rather than marking this
  complete without having actually run it.
  **NOT COMPLETED** — same reason as T025: no live D365 connection/credentials in this environment.
  Unit tests (T016, T024 — 13 tests total) cover the same scenarios against mocked D365 responses,
  and both new tables/columns were confirmed against the real local dev DB (T007/T017). A human (or
  an environment with D365 access) should run this quickstart against real data — in particular to
  confirm the `SalesStatus`/`Range`/`GroupId` assumptions from T025 — before this feature is
  considered fully verified end-to-end.

---

## Post-implementation addition: test-safety record limit (added after T026)

**Goal**: Per explicit follow-up request ("thêm biến cấu hình để có thể test trước 10 dữ liệu, khi
chạy thật có thể chỉnh chạy hết" — add a variable to test with 10 records first, adjustable to run
everything for the real run), cap how many Sales Line records get processed (inserted) per run during
testing.

**Correction (same day)**: T027-T030 below were first implemented as a config-driven limit
(`ComplSynchronizeData:MaxSalesLineRecords` in `appsettings.json`/`appsettings.Development.json`,
`IConfiguration` injected into the service, `FetchAllSalesLinesAsync` requesting a smaller `$top` per
page). Per explicit follow-up ("không cần add vào appsettings, thêm biến trong foreach ... rồi break
được rồi" — no need for appsettings, just add a variable inside the `foreach` loop and break), this was
simplified: **no config, no `IConfiguration` dependency, no change to the D365 fetch behavior**. The
appsettings entries were removed. Final shape:

- [X] T027 Add `private const int TestSafetyMaxSalesLineRecordsPerRun = 10;` to
  `ComplSynchronizeDataService` — same shape and same explicit "TEMPORARY, not a spec requirement,
  raise or remove before a real run" framing as `EutrSynchronizeDataService.TestSafetyMaxFlaggedRowsPerRun`
  (011 User Story 2). No `appsettings.json` changes — to run for real, edit this constant (or remove
  the `break` below) and redeploy, matching how the 011 precedent constant is adjusted.

- [X] T028 In `RunAsync`'s `foreach (var item in salesLines)` loop (Phase 1), after each item is
  processed (added or skipped), `break` once `summary.SalesLineAdded + summary.SalesLineSkipped >=
  TestSafetyMaxSalesLineRecordsPerRun`. `FetchAllSalesLinesAsync` is unchanged — it still fetches every
  page from D365 as before (FR-002 unaffected); only the per-item *processing* loop is capped, matching
  the user's literal instruction ("thêm biến trong foreach ... rồi break").

- [X] T029 Update `ComplSynchronizeDataServiceTests.cs`: reverted the `IConfiguration`-parameterized
  `CreateService`/`CreateConfiguration` back to the original fixed setup (only needed for
  `DynamicsParameterManager`); removed the 2 config-based tests; fixed
  `RunAsync_ShouldFetchAllSalesLinePages_WhenDataSpansMultiplePages` (its `SalesLineAdded` assertion
  now expects the 10-record test-safety cap, not the full 1001-record fetch count — `SalesLineFetched`
  still asserts the full count, since fetching itself is unaffected); added one new test verifying the
  cap stops processing at exactly 10 records with 10 `InsertManyAsync` calls. 14 tests in this file
  pass (13 prior, net +1/-2+... see count); full suite: 134 passed, 1 failed (same pre-existing
  unrelated `MappingConfigurationTests` failure noted in T001) — no regression.

---

## Post-implementation correction: stop using `[HttpPost("reference")]` type 6, add dedicated `product-variant-info` endpoint (research.md R10)

**Goal**: Per explicit follow-up request ("không sử dụng [HttpPost("reference")] 6 nữa, viết thêm 1
API trong DynController là [HttpGet("product-variant-info")] tương tự
[HttpGet("product-variant-attributes")]..." — stop using the generic reference endpoint with type 6;
add a dedicated `product-variant-info` action to `DynController`, shaped like the existing
`product-variant-attributes` action, sourcing `RSVNProductVariantAlls`), replace Phase 1's bulk
type-6 fetch (original R4/T002-T004) with per-distinct-combination lookups via the new endpoint —
mirroring exactly how Phase 2 already looks up Variant Attributes (research.md R5).

**Clarification obtained**: the user's own filter example text used `"Config eq '31631'"`, but the
existing `RSVNProductVariantAlls` C# model (and therefore the JSON field D365 returns) declares this
field `ConfigId`. Asked directly; confirmed to use `ConfigId eq '...'`, matching the property already
established in this codebase over the literal example text.

- [X] T031 Add `[HttpGet("product-variant-info")]` to
  `compliance-sys-api/src/ComplianceSys.Api/Controllers/DynController.cs`, placed after
  `product-variant-attributes` — byte-for-byte the same shape (`skip`, `top`, `filter`, `order_by`
  params; `SetEntity("RSVNProductVariantAlls")`; returns raw D365 JSON via `Ok(data)`).

- [X] T032 Rework Phase 1 of `RunAsync` in
  `compliance-sys-api/src/ComplianceSys.Application/Services/ComplSynchronizeDataService.cs`:
  removed the `IComplDynamicsService` dependency entirely (its only use, the type-6 bulk fetch, no
  longer exists); reordered so Sales Line data is fetched **first**, then the distinct
  `(ItemId, ConfigId)` combinations across valid records (non-blank Item ID + Sales ID, same FR-007
  filter) are derived and looked up one-by-one via a new private `FetchProductVariantInfoAsync`
  (same low-level `IDynamicService`/`DynamicsParameterManager` pattern as
  `FetchVariantAttributesAsync`, filter `ProductCode eq '...' and ConfigId eq '...'`, deserializing
  directly into `RSVNProductVariantAlls` via `OdataMapper<RSVNProductVariantAlls>` — no
  `ComplDynReferenceResponseDto` involved). Replaced `BulkFetchProductReferenceAsync` entirely.
  `matched?.Name`/`.Description`/`.Type`/`.Range` field access updated to
  `matched?.ProductName`/`.ProductDescription`/`.ProductVariantType`/`.Range` (the real domain model's
  property names).

- [X] T033 Revert the now-unused additive changes from the original T003/T004: removed the
  `ProductCode`/`ConfigId`/`Description`/`Type`/`Range` properties from
  `ComplDynReferenceResponseDto.cs`, and reverted `ComplDynamicsService.MapDynamicsResponse`'s
  `case 6:` branch back to its original `Id`/`Code`/`Name`-only mapping — nothing in the codebase
  calls `GetDynRefePagedAsync(6, ...)` any more, so keeping those fields would be dead code.
  `RSVNProductVariantAlls.Range` (T002) is **kept**, since it's now used directly by the
  `product-variant-info` deserialization path.

- [X] T034 Rewrite `ComplSynchronizeDataServiceTests.cs`: removed `Mock<IComplDynamicsService>` and
  the `MakeProductReference`/`ComplDynReferenceResponseDto`-based mocking entirely; added a
  `ProductVariantInfoPageJson` helper (raw JSON matching `RSVNProductVariantAlls`'s field names) for
  mocking the new endpoint via `IDynamicService.QueryAsync`. Fixed an off-by-one across several tests'
  `SetupSequence` chains — a Sales Line page with fewer than 1000 items ends `FetchAllSalesLinesAsync`'s
  loop after exactly one call, so an extra queued "empty page to end the loop" entry pushed the
  *real* next-queued response (e.g. `RunAsync_ShouldPopulateEnrichmentFields_WhenProductReferenceMatches`'s
  match data) one call too late, silently starving the actual `product-variant-info` lookup and
  breaking that one test (confirmed via a full run: 13 passed, 1 failed, before this fix). All 14
  tests in this file pass after the fix; full suite: 134 passed, 1 failed (same pre-existing unrelated
  `MappingConfigurationTests` failure noted in T001) — no regression. `dotnet build` on
  `ComplianceSys.Api` (compile-only, ignoring the known pre-existing file-lock copy errors from a
  locally-running dev instance) succeeds with 0 `error CS*`.

---

## Post-implementation fix: Sales Line filter + root-caused "both tables empty" bug report (research.md R11)

**Goal**: Per explicit follow-up ("khi lấy sales line filter thêm SalesStatus eq
Microsoft.Dynamics.DataEntities.SalesStatus'Backorder'. ngoài ra kiểm tra api chạy
test-compl-synchronize-data chạy ok mà 2 bảng ko có dữ liệu" — add a `SalesStatus = 'Backorder'`
filter to the Sales Line fetch; also investigate why the endpoint reports success but both tables end
up empty), scope the Sales Line fetch and diagnose the empty-tables report.

- [X] T035 Add `SalesLineFilter = "SalesStatus eq Microsoft.Dynamics.DataEntities.SalesStatus'Backorder'"`
  constant to `ComplSynchronizeDataService.cs`, used in `FetchAllSalesLinesAsync`'s `.AddFilter(...)`
  call (previously `string.Empty`) — same enum-literal filter syntax `ComplDynamicsService.cs:118`
  already uses for a different entity's own `SalesStatus` (refType 18). `dotnet build` on
  `ComplianceSys.Application`: 0 errors; all 14 `ComplSynchronizeDataServiceTests` still pass
  (mocks match on `It.IsAny<string>()`, unaffected by the literal filter text).

- [X] T036 Investigated the "runs OK, tables empty" report via
  `compliance-sys-api/src/ComplianceSys.Api/logs/error/compliance-sys-20260819.log` and
  `.../logs/info/compliance-sys-20260819.log` for the two real requests the user made against the
  running dev server. **Root cause found**: both requests threw
  `System.OperationCanceledException` from `ct.ThrowIfCancellationRequested()` inside
  `FetchAllSalesLinesAsync`, ~125–133 seconds in (matching the info log's `responded 200 in 132948 ms`/
  `125214 ms`) — the controller's `CancellationToken` is bound to the HTTP request's own abort/timeout
  token, and paging through `RSVNSalesLineOpenInvoiceCogs` **unfiltered** (`filter = ""`, before T035)
  apparently takes long enough in the real D365 environment to exceed whatever imposes that ~2-minute
  cutoff. The run aborts partway through Phase 1's fetch, before any row is ever inserted — but the
  HTTP response still comes back `200 OK` (the controller always wraps the summary in `Ok(...)`
  regardless of the summary's own `Success` flag), which is why it looked like "it ran fine" from the
  outside; `data.success` in that response body was actually `false`. T035's filter is expected to
  fix this by sharply narrowing the dataset — not independently verified against live D365 in this
  environment (no such access here); see research.md R11 for the full log excerpts and reasoning.
  **Separately confirmed**: the running dev server process was serving a build from *before* the
  `product-variant-info` refactor even finished stabilizing (debug log shows `Dynamics Filter String:`
  entries, which only come from the now-removed `IComplDynamicsService.GetDynRefePagedAsync` code
  path) for the earlier of the two requests — the dev server must be rebuilt and restarted to pick up
  this session's changes, including T035, before re-testing.

---

## Post-implementation fix: `SalesStatus` string type + `ProductRange`/`ProductType` real field names (research.md R12)

**Goal**: Per explicit follow-up ("SalesStatus là enum của D365, nhưng API trả về là Invoiced hoặc
Backorder, tôi đã đổi cột SalesStatus bảng compl_sync_sales_line thành string, cập nhật lại file
migration, và code lưu" — `SalesStatus` is a D365 enum but the API returns label text like "Invoiced"
or "Backorder"; the user had already changed the live DB column to `varchar` and asked for the rest of
the codebase to catch up), and following up on a live-data discovery the user made while testing
(`RSVNProductVariantAlls`'s real fields are `ProductRange`/`ProductType`, not the originally-guessed
`Range`/`ProductVariantType` — already applied by the user directly to `RSVNProductVariantAlls.cs` and
`ComplSynchronizeDataService.cs`'s field mapping), bring the rest of the codebase into consistency.

- [X] T037 Changed `ComplSyncSalesLine.SalesStatus` from `byte` to `string` (default `""`) in
  `compliance-sys-api/src/ComplianceSys.Domain/Entities/ComplSyncSalesLine.cs`; changed
  `ComplSynchronizeDataService`'s row-building code from `byte.TryParse(item.SalesStatus, ...)` to a
  direct `item.SalesStatus ?? string.Empty` copy; widened `SalesStatus tinyint NOT NULL` to
  `SalesStatus varchar(50) NOT NULL` in both
  `Sqls/Migration/22_create_compl_sync_sales_line.sql` and `Sqls/Tables/compl_sync_sales_line.sql`, to
  match the live DB (which the user had already altered directly) and keep a fresh-DB bootstrap
  producing the same schema. **Found via live data while investigating**: the 10 rows already synced
  (from the R11 test run) all showed `SalesStatus = "0"` — the DB column had already been widened to
  `varchar`, but the C# service was still parsing it as a number, silently defaulting to `0` for every
  row (`byte.TryParse("Backorder", ...)` always fails). Widening the column alone didn't fix the
  producer still emitting the wrong value; both needed to change together.

- [X] T038 Updated `ComplSynchronizeDataServiceTests.cs` for the `SalesStatus` type change (one test's
  assertion changed from `r.SalesStatus == 3` — a compile error once the property is `string` — to
  `r.SalesStatus == "Backorder"`, using a realistic label now that live data confirms the shape), and
  fixed `ProductVariantInfoPageJson`'s field names (`ProductVariantType`/`Range` → `ProductType`/
  `ProductRange`), which had gone stale relative to the user's already-applied
  `RSVNProductVariantAlls.cs` rename and were silently starving
  `RunAsync_ShouldPopulateEnrichmentFields_WhenProductReferenceMatches` (mismatched JSON field names
  deserialize to `null`/default, not a compile error, so this wasn't caught until the test was run).
  All 14 tests in this file pass; full suite: 134 passed, 1 failed (same pre-existing unrelated
  `MappingConfigurationTests` failure noted in T001) — no regression. `dotnet build` on
  `ComplianceSys.Api` (compile-only) succeeds with 0 `error CS*`.
  **Residual note carried into T025's scope**: the same 10 already-synced rows show `ProductRange`
  blank for every row — may be genuinely blank in D365 for those products, or the rename may still not
  be exactly right; inconclusive from this sample, not treated as a new confirmed bug.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately.
- **Foundational (Phase 2)**: Depends on Setup (T001). BLOCKS both user stories — T007 onward cannot
  compile/run meaningfully until T002-T006 exist (the DTO/interface every later task references).
- **User Story 1 (Phase 3)**: Depends on Foundational (Phase 2) completion.
- **User Story 2 (Phase 4)**: Depends on Foundational (Phase 2) **and** User Story 1 (Phase 3) — unlike
  a typical independent-story pair, T022 literally appends code to the same `RunAsync` method T012
  creates, and T017-T021 mirror T007-T011's table/entity/repository shape one-for-one. This is a
  structural consequence of FR-001 requiring one single triggered action for both phases (see
  "Organization" note above) — Phase 4 cannot be implemented in a vacuum before `ComplSynchronizeDataService`
  exists. It remains independently *testable* (T024's mocks don't require Phase 1's logic to have
  actually executed), just not independently *implementable* before Phase 3.
- **Polish (Phase 5)**: T025 has no code dependency (pure verification) but should happen before or
  during Phase 3 in practice, since it affects whether `Range` mapping (T002/T004) needs revisiting.
  T026 depends on both Phase 3 and Phase 4 being complete.

### Within User Story 1

- T007 (migration/table) has no dependency on T008-T016 and can be done first or in parallel with T008/T009.
- T008 and T009 have no code dependency on each other and can be done in parallel.
- T010 depends on T008 (entity shape) and T009 (interface signature).
- T011 depends on T009 and T010 (both concrete types must exist to register them).
- T012 depends on T004 (correct type-6 data), T006 (interface signature), T010 and T011 (repository
  usable via DI).
- T013 depends on T012 (same file, same class — the constructor and calling code already exist).
- T014 depends on T006 and T012 (both concrete types must exist to register them).
- T015 depends on T006 (interface to inject) and T014 (DI registration, so the controller resolves at
  runtime).
- T016 depends on T012 and T013 (the service under test must exist) but not on T014/T015.

### Within User Story 2

- T017 (migration/table) has no dependency on T018-T024 and can be done first or in parallel with T018/T019.
- T018 and T019 have no code dependency on each other and can be done in parallel.
- T020 depends on T018 and T019.
- T021 depends on T019 and T020.
- T022 depends on T012 (extends the same method/class), T020, and T021.
- T023 depends on T022 (same file, same class).
- T024 depends on T022 and T023.

### Parallel Opportunities

- T002 and T003 (Phase 2) touch different files and can run in parallel; T005 and T006 likewise.
- T008/T009 (Phase 3) and T018/T019 (Phase 4) each touch different files within their own story and
  can run in parallel within that story.
- T016 and T024 (the two unit-test tasks) touch the same test file but different test methods — treat
  as sequential in practice to avoid merge conflicts, even though they're logically independent.

---

## Parallel Example: Foundational Phase

```bash
# Launch the two independent DTO/entity edits together:
Task: "Add Range property to RSVNProductVariantAlls in compliance-sys-api/src/ComplianceSys.Domain/Dynamics/RSVNProductVariantAlls.cs"
Task: "Extend ComplDynReferenceResponseDto with ProductCode/ConfigId/Description/Type/Range in compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/ComplDynReferenceResponseDto.cs"

# Launch the two independent new-file creations together:
Task: "Create ComplSynchronizeDataSummaryDto in compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/ComplSynchronizeDataSummaryDto.cs"
Task: "Create IComplSynchronizeDataService in compliance-sys-api/src/ComplianceSys.Application/Interfaces/Services/IComplSynchronizeDataService.cs"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL — blocks both stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: `compl_sync_sales_line` is correctly populated end-to-end (quickstart.md
   steps 1-5); `RunAsync`'s response already reports accurate Phase 1 counts even though
   `DistinctProductConfigCount`/`VariantAttributeAdded` are still `0`.
5. Deploy/demo if ready — Phase 1 alone already delivers standalone value (a local, enriched Sales
   Line dataset), even before Phase 2 exists.

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready.
2. Add User Story 1 → validate independently → Deploy/Demo (MVP!).
3. Add User Story 2 → validate independently (including that it doesn't regress User Story 1's Phase
   1 behavior) → Deploy/Demo — the full two-phase `test-compl-synchronize-data` action is now complete.
4. Run Phase 5 Polish (D365 metadata verification, full quickstart pass) once both stories are done.

### Parallel Team Strategy

Given Phase 4 structurally depends on Phase 3 (same method, same class — see "Within User Story 2"
above), this feature is a poor fit for two developers working the two stories fully in parallel.
Recommended split instead: one developer completes Setup + Foundational + User Story 1 end-to-end
(Phases 1-3), then a second developer picks up User Story 2 (Phase 4) once `ComplSynchronizeDataService`
and its Phase 1 body exist — with the table/entity/repository files (T017-T021) freely startable in
parallel by the second developer *while* the first is still finishing T012/T013, since those files
don't depend on `ComplSynchronizeDataService` itself.

---

## Notes

- [P] tasks = different files, no dependencies.
- [Story] label maps task to specific user story for traceability.
- Verify tests fail before implementing (if following TDD) or pass immediately after (if implementing
  first, per this list's task ordering — implementation before tests within each story).
- Commit after each task or logical group.
- Stop at the Phase 3 checkpoint to validate User Story 1 independently before starting Phase 4.
- T025 (D365 `Range` field verification) is time-sensitive — do it as early as practical (ideally
  right after T002/T004 land) so any needed correction to the `Range` mapping happens before T016's
  unit tests and T026's quickstart pass are written against a possibly-wrong assumption.
