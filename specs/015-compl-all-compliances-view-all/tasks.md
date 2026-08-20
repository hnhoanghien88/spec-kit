---

description: "Task list for feature implementation"
---

# Tasks: All Compliances Sales-Line Fallback for Missing BOM

**Input**: Design documents from `/specs/015-compl-all-compliances-view-all/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/sales-line-fallback.md](contracts/sales-line-fallback.md), [quickstart.md](quickstart.md)

**Tests**: Not explicitly requested as TDD in the spec, but this codebase's existing convention pairs
every Application-layer service with an xUnit test file (`DynamicsDataServiceTests.cs`,
`ViewCompliancesTransformServiceTests.cs`), and quickstart.md already names the exact test filters
to run. Test tasks below add cases to those existing files as a normal implementation deliverable
(not a pre-implementation TDD gate).

**Organization**: This feature has a single user story (P1) in spec.md, so all implementation work
lives in one phase. There is no cross-story Foundational work.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1 — the only story in this feature)
- Paths are relative to the repository root (`e:\Working\Eutr`)

## Path Conventions

Backend-only change inside the existing `compliance-sys-api` Clean Architecture layout
(`Api` → `Application` → `Domain`). No frontend files are touched (see plan.md "Structure Decision").

---

## Phase 1: Setup

**Purpose**: Establish a clean starting point. No new project, package, or config is introduced.

- [X] T001 Run `dotnet build compliance-sys-api/ComplianceSys.sln` from the repo root and confirm it succeeds, to establish a clean baseline before any change in this feature. (Solution-wide build only fails on the Api project's output-copy step because a dev instance of ComplianceSys.Api is currently running and holding its DLLs locked — unrelated to this feature. `dotnet build src/ComplianceSys.Application/ComplianceSys.Application.csproj`, the project this feature modifies, builds clean with 0 errors.)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented.

**None required.** This feature has a single user story with no cross-story shared prerequisites.
The Domain models it depends on (`RSVNSalesLineOpenInvoiceCogs`, `RSVNProductVariantAlls`,
`RSVNSalesLineOpenMaterialRvns`) already exist and require no changes (data-model.md). No database
schema, auth, or routing changes are needed (Constitution Check in plan.md).

---

## Phase 3: User Story 1 - See compliance results for a sales order that has no BOM yet (Priority: P1) 🎯 MVP

**Goal**: When the BOM-based sales-line lookup (`GetSalesLineOpenMaterialFromDynamics`) returns zero
rows for a sales order in the All Compliances `get-all` lookup, fall back to the sales-order-line
reference data (`RSVNSalesLineOpenInvoiceCogs`, "sales-line"), map it into the same
`RSVNSalesLineOpenMaterialRvns` shape (enriching `ProductType`/`ProductRange` via
`RSVNProductVariantAlls`, "product-variant-info"), and feed it into the existing downstream
compliance-mapping logic unchanged — so a sales order without a BOM yet still produces compliance
results instead of an empty one.

**Independent Test**: Pick a sales order whose BOM-based sales-line lookup currently returns no
records but which has one or more order lines in the sales-order-line reference data. Run the All
Compliances `get-all` lookup for that sales order. Confirm the response is no longer empty solely
because of the missing BOM. Then repeat with a sales order that already has BOM data and confirm the
response is unchanged from today's behavior (see quickstart.md for the exact steps).

### Implementation for User Story 1

- [X] T002 [US1] Add two new method signatures to `IDynamicsDataService` in `compliance-sys-api/src/ComplianceSys.Application/Services/ViewCompliances/IDynamicsDataService.cs`: `Task<List<RSVNSalesLineOpenInvoiceCogs>> GetSalesLineOpenInvoiceCogsFromDynamics(string salesOrder)` and `Task<List<RSVNProductVariantAlls>> GetRSVNProductVariantAllsByProductConfigFromDynamics(IEnumerable<(string ProductCode, string ConfigId)> variants)` (contracts/sales-line-fallback.md).

- [X] T003 [US1] Implement `GetSalesLineOpenInvoiceCogsFromDynamics` in `compliance-sys-api/src/ComplianceSys.Application/Services/ViewCompliances/DynamicsDataService.cs`: query entity `"RSVNSalesLineOpenInvoiceCogs"` with filter `(SalesId eq '{salesOrder}')`, following the exact cache-key/cache-read/OData-query/`Helper.ParseDynamicsResponse`/cache-write structure already used by `GetSalesLineOpenMaterialFromDynamics` in the same file (research.md R2). Depends on: T002.

- [X] T004 [US1] Implement `GetRSVNProductVariantAllsByProductConfigFromDynamics` in `compliance-sys-api/src/ComplianceSys.Application/Services/ViewCompliances/DynamicsDataService.cs`: for the distinct `(ProductCode, ConfigId)` pairs given, build an OR-of-ANDs filter — `(ProductCode eq '...' and ConfigId eq '...')` per pair — against entity `"RSVNProductVariantAlls"`, mirroring `GetRSVNProductVariantMaterialsFromDynamics`'s existing filter-building/cache pattern in the same file; return `[]` immediately for an empty input without querying (research.md R3). Depends on: T002.

- [X] T005 [P] [US1] Add unit tests for the two new methods in `compliance-sys-api/tests/ComplianceSysApi.UnitTests/Services/ViewCompliances/DynamicsDataServiceTests.cs`: cache-hit short-circuit, cache-miss builds the expected OData filter and caches the result, and empty-input returns `[]` without calling `IDynamicService`/`ICacheHelper` — following the existing test style in this file (e.g. `GetSalesLineOpenMaterialFromDynamics_ShouldQueryDynamicsAndCacheResult_WhenCacheMiss`, `GetProductVariantAttributesFromDynamics_ShouldReturnEmpty_WhenProductVariantsEmpty`). Depends on: T003, T004.

- [X] T006 [US1] Add `Task<List<RSVNSalesLineOpenMaterialRvns>> BuildSalesLineOpenMaterialFallbackAsync(string salesOrder)` signature to `IViewCompliancesTransformService` in `compliance-sys-api/src/ComplianceSys.Application/Services/ViewCompliances/IViewCompliancesTransformService.cs`. Depends on: T002.

- [X] T007 [US1] Implement `BuildSalesLineOpenMaterialFallbackAsync` in `compliance-sys-api/src/ComplianceSys.Application/Services/ViewCompliances/ViewCompliancesTransformService.cs`: call `GetSalesLineOpenInvoiceCogsFromDynamics(salesOrder)`; return `[]` immediately if it is empty (FR-009). Otherwise build the distinct `(ProductCode, ConfigId)` pairs from the results (`ProductCode` = row's `ItemId`), call `GetRSVNProductVariantAllsByProductConfigFromDynamics` once for all pairs, and map each row into a `RSVNSalesLineOpenMaterialRvns` per the field table in research.md R5 / data-model.md: `SalesId`, `ConfigId`, `AreaId`, `CountryRegionId`, `SalesStatus` copied directly; `ProductCode` = `ItemId`; `InterSalesId` = `"cog" + SalesId`; `ProductType`/`ProductRange` from the matched product-variant-info row (or blank if none); `MaterialCode`, `MaterialName`, `MaterialType`, `CostGroupId`, `ProductGroup` left blank. Depends on: T003, T004, T006.

- [X] T008 [P] [US1] Add unit tests for `BuildSalesLineOpenMaterialFallbackAsync` in `compliance-sys-api/tests/ComplianceSysApi.UnitTests/Services/ViewCompliances/ViewCompliancesTransformServiceTests.cs`: (a) returns `[]` when the sales-line source is empty; (b) maps a full row correctly (all copied fields, `"cog"`-prefixed `InterSalesId`, matched `ProductType`/`ProductRange`); (c) leaves `ProductType`/`ProductRange` blank when no product-variant-info match exists; (d) leaves the BOM-only fields blank — following the existing test style in this file (e.g. `TransformSoToRequestForSql_ShouldCreateMaterialAndAttributeRows`, mocking `IDynamicsDataService`). Depends on: T007.

- [X] T009 [US1] Wire the fallback into `ViewCompliancesService.GetViewCompliancesAsync`'s sales-order branch in `compliance-sys-api/src/ComplianceSys.Application/Services/ViewCompliancesService.cs` (currently around line 64): immediately after `salesLineOpenMaterials = await _dynamicsDataService.GetSalesLineOpenMaterialFromDynamics(so.ReferenceValue);`, add `if (!salesLineOpenMaterials.Any()) { salesLineOpenMaterials = await _transformService.BuildSalesLineOpenMaterialFallbackAsync(so.ReferenceValue); }` exactly as specified in contracts/sales-line-fallback.md "Call-site change" — no other line in the method changes. Depends on: T006, T007.

- [X] T010 [US1] Run `dotnet test compliance-sys-api/tests/ComplianceSysApi.UnitTests --filter "FullyQualifiedName~DynamicsDataServiceTests|FullyQualifiedName~ViewCompliancesTransformServiceTests"`, fix any failures, then perform the manual before/after validation from quickstart.md (a no-BOM sales order with order lines now returns non-empty results; a sales order that already has BOM data is byte-for-byte unchanged and the fallback Dynamics calls are not made for it; a sales order with neither BOM nor order lines still returns an empty result). Depends on: T005, T008, T009.
  - Filtered run: 16/16 passed (0 failed), including the new `DynamicsDataServiceTests`/`ViewCompliancesTransformServiceTests` cases for this feature.
  - Full `ComplianceSysApi.UnitTests` suite: 139/142 passed. The 3 failures (`ComplSynchronizeDataServiceTests.RunAsync_ShouldFetchAllSalesLinePages_WhenDataSpansMultiplePages`, `ComplSynchronizeDataServiceTests.RunAsync_ShouldStopProcessing_AtTestSafetyLimit`, `MappingConfigurationTests.ApplicationMappingProfiles_ShouldBeValid`) are pre-existing, unrelated to this feature — they belong to the separate, already-uncommitted `013-compl-synchronize-data` work in this working tree (files this feature never touched) and an AutoMapper profile gap on unrelated DTOs (`EutrReferenceTypeDetails`, `EutrDocuments`). None of them import or exercise `ViewCompliancesService`, `DynamicsDataService`, or `ViewCompliancesTransformService`.
  - Manual end-to-end quickstart.md validation against a live Dynamics environment was not run (no reachable Dynamics 365 F&O dev credentials in this session) — see completion report caveat.

**Checkpoint**: User Story 1 is fully functional and independently testable — this is the entire feature (single-story MVP).

---

## Final Phase: Polish & Cross-Cutting Concerns

- [X] T011 [P] Confirm no other caller of `GetSalesLineOpenMaterialFromDynamics` was touched — specifically `ViewCompliancesService.Test` (~line 183) and the sales-order-line detail/breakdown method (~line 294) — per spec.md's Assumptions that this fallback is scoped only to the `get-all` sales-order branch (`GetViewCompliancesAsync`).
  - Verified: `Test` (now line 190) and the breakdown method (now line 301) still call `GetSalesLineOpenMaterialFromDynamics` directly with no fallback branch — only `GetViewCompliancesAsync`'s sales-order branch (line 64-70) was changed.

---

## Follow-up: User Story 2 (2026-08-19) — Sales order compliance detail tab

Reported symptom: for sales order `SO007370` (no BOM), the main "get-all" list showed data (US1)
but the "Sales order compliance detail" tab stayed empty. Root cause: that tab is built from a
second, separate method, `TransformSoAsync` (behind `GET transform-so/{salesId}`), which also calls
`GetSalesLineOpenMaterialFromDynamics` directly with no fallback — the exact gap T011 confirmed was
intentionally out of scope for User Story 1. See spec.md User Story 2 / FR-010 / SC-005.

- [X] T012 [US2] Wire the existing `BuildSalesLineOpenMaterialFallbackAsync` fallback (built in T007, unchanged) into `ViewCompliancesService.TransformSoAsync` in `compliance-sys-api/src/ComplianceSys.Application/Services/ViewCompliancesService.cs`: immediately after `var salesLineOpenMaterials = await _dynamicsDataService.GetSalesLineOpenMaterialFromDynamics(salesId);`, add the same `if (!salesLineOpenMaterials.Any()) { salesLineOpenMaterials = await _transformService.BuildSalesLineOpenMaterialFallbackAsync(salesId); }` before the existing `if (!salesLineOpenMaterials.Any()) return [];` check. No new backend method — reuses T003/T004/T007 as-is. Depends on: T007 (already complete).
  - Verified: `dotnet build src/ComplianceSys.Application/ComplianceSys.Application.csproj` — 0 errors; `dotnet test --filter "FullyQualifiedName~DynamicsDataServiceTests|FullyQualifiedName~ViewCompliancesTransformServiceTests"` — 16/16 passed (unchanged, since no new method was added, only a second call site wired to the existing one).
  - `ViewCompliancesService.Test` (diagnostic-only, no UI consumer) intentionally still excluded, per the revised spec.md Assumptions.

---

## Follow-up: User Story 3 (2026-08-19) — GetAndSaveSummarySo / compliance-summary job

Reported symptom: `ViewCompliancesService.GetAndSaveSummarySo` (a one-line delegate to
`ViewCompliancesSummaryService.GetAndSaveSummarySo`, the `daily_update_count_all_compliances`
Hangfire job) has the same `salesLineOpenMaterials` gap in its per-sales-order loop. See spec.md
User Story 3 / FR-011 / SC-006.

- [X] T013 [US3] Wire the existing `BuildSalesLineOpenMaterialFallbackAsync` fallback into `ViewCompliancesSummaryService.GetAndSaveSummarySo` in `compliance-sys-api/src/ComplianceSys.Application/Services/ViewCompliances/ViewCompliancesSummaryService.cs`: immediately after `var salesLineOpenMaterials = await _dynamicsDataService.GetSalesLineOpenMaterialFromDynamics(salesOrders[i].SalesId);` (inside the per-sales-order loop), add `if (!salesLineOpenMaterials.Any()) { salesLineOpenMaterials = await _transformService.BuildSalesLineOpenMaterialFallbackAsync(salesOrders[i].SalesId); }` before it feeds into `TransformSoToRequestForSql`. No new backend method — `ViewCompliancesSummaryService` already had `IViewCompliancesTransformService` injected. Depends on: T007 (already complete).
  - Verified: `dotnet build src/ComplianceSys.Application/ComplianceSys.Application.csproj` — 0 errors. No existing unit test file covers `ViewCompliancesSummaryService`, so there was nothing to re-run for this specific class; the shared `DynamicsDataServiceTests`/`ViewCompliancesTransformServiceTests` (16/16) already cover the fallback method itself.
  - Two more callers with the identical pattern (`ViewCompliancesDownloadService`, `ViewCompliancesAlertService`) were flagged to the user rather than changed here — see the User Story 4 follow-up below.

---

## Follow-up: User Story 4 (2026-08-19) — Download & Alert flows

User confirmed extending the fallback to the two remaining callers flagged in T013: file download
and missing-compliance alert generation for a sales order. See spec.md User Story 4 / FR-012 / SC-007.

- [X] T014 [P] [US4] Wire the existing `BuildSalesLineOpenMaterialFallbackAsync` fallback into `ViewCompliancesDownloadService.GetViewCompliancesForDownloadAsync` in `compliance-sys-api/src/ComplianceSys.Application/Services/ViewCompliances/ViewCompliancesDownloadService.cs`: immediately after `var salesLineOpenMaterials = await _dynamicsDataService.GetSalesLineOpenMaterialFromDynamics(salesId);`, add `if (!salesLineOpenMaterials.Any()) { salesLineOpenMaterials = await _transformService.BuildSalesLineOpenMaterialFallbackAsync(salesId); }` before it feeds into `TransformSoToRequestForSql`. No new backend method — already had `IViewCompliancesTransformService` injected. Depends on: T007 (already complete).
- [X] T015 [P] [US4] Wire the same fallback into `ViewCompliancesAlertService.GetViewCompliancesForSendAlertAsync` in `compliance-sys-api/src/ComplianceSys.Application/Services/ViewCompliances/ViewCompliancesAlertService.cs`, identical pattern. Depends on: T007 (already complete).
  - Verified: `dotnet build src/ComplianceSys.Application/ComplianceSys.Application.csproj` — 0 errors. `dotnet test --filter "FullyQualifiedName~DynamicsDataServiceTests|FullyQualifiedName~ViewCompliancesTransformServiceTests|FullyQualifiedName~ViewCompliancesDownloadServiceTests|FullyQualifiedName~ViewCompliancesAlertServiceTests"` — 20/20 passed. Existing tests for both services always mock a non-empty `GetSalesLineOpenMaterialFromDynamics` result, so the new fallback branch is never exercised by them (not a regression risk) — no new fallback-triggered test cases were added for these two services since neither had prior direct fallback coverage requested.
  - `ViewCompliancesService.Test` (diagnostic-only, no known consumer) remains the only unchanged caller of `GetSalesLineOpenMaterialFromDynamics`.

---

## Follow-up: User Story 5 (2026-08-20) — `BomStatus` column on `compl_summary_so`

Requested change: `ViewCompliancesSummaryService.GetAndSaveSummarySo` (the only writer of
`compl_summary_so`, User Story 3) should record, on each saved row, whether that sales order's
summary was computed via the no-BOM fallback (User Story 3's `BuildSalesLineOpenMaterialFallbackAsync`)
or from real BOM data. See spec.md User Story 5 / FR-013–FR-015 / SC-008, plan.md Summary/Technical
Context/Constitution Check ("Update 2026-08-20"), research.md R7, data-model.md `ComplSummarySo`,
contracts/sales-line-fallback.md ("Added 2026-08-20"), quickstart.md "Additional validation
(2026-08-20, User Story 5)".

- [X] T016 [P] [US5] Add migration `compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Migration/25_add_bomstatus_to_compl_summary_so.sql`: `ALTER TABLE compl_summary_so ADD COLUMN BomStatus VARCHAR(50) NULL AFTER TotalCompliances;`, prefaced with a Vietnamese comment header citing this feature/update, following the exact style of `13_add_status_to_eutr_templates.sql` / `20_add_invoice_to_eutr_documents.sql`. ALSO add the same column to the baseline snapshot `compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Tables/compl_summary_so.sql` (`BomStatus VARCHAR(50)` alongside `TotalCompliances`) — `DatabaseInitializer.InitTables()` executes every file under `Sqls/Tables/` verbatim when bootstrapping a brand-new database, so this snapshot must also carry the new column (research.md R7 "Correction"). Do not backfill that snapshot's other, pre-existing missing columns (`TotalOverdue`, `MissingMasterIds`, `OverdueMasterIds`, `ResponsibleEmails`, `AlertEmails`) — out of scope for this feature.
  - Done: both files updated as specified.

- [X] T017 [P] [US5] Add `public string? BomStatus { get; set; }` to `ComplSummarySo` in `compliance-sys-api/src/ComplianceSys.Domain/Entities/ComplSummarySo.cs`, placed alongside the other nullable string fields (e.g. next to `AlertEmails`). No `[Column(...)]` attribute needed — the property name already matches the new column name (Dapper convention, docs/database/conventions.md).
  - Done.

- [X] T018 [US5] In `ViewCompliancesSummaryService.GetAndSaveSummarySo` (`compliance-sys-api/src/ComplianceSys.Application/Services/ViewCompliances/ViewCompliancesSummaryService.cs`): immediately after `var salesLineOpenMaterials = await _dynamicsDataService.GetSalesLineOpenMaterialFromDynamics(salesOrders[i].SalesId);` (before the existing fallback `if`), capture `var bomStatus = salesLineOpenMaterials.Any() ? null : "No BOM";`. Set `BomStatus = bomStatus` on the `newSummarySO` object literal (insert path) and `exist.BomStatus = bomStatus;` alongside the other `exist.*` assignments (update path, immediately before `exist.UpdatedDate = DateTime.UtcNow;`). Do not change where `bomStatus` is computed relative to the fallback call — it must reflect the *primary* lookup's emptiness (FR-014/FR-015), not whether the fallback itself found data. Depends on: T017 (entity property must exist to compile).
  - Done: `bomStatus` captured right after the primary lookup, before the fallback overwrites `salesLineOpenMaterials`; set on both `newSummarySO` and `exist`.

- [X] T019 [US5] Run `dotnet build compliance-sys-api/src/ComplianceSys.Application/ComplianceSys.Application.csproj` and `dotnet build compliance-sys-api/src/ComplianceSys.Domain/ComplianceSys.Domain.csproj`, confirm 0 errors. Apply migration T016 to a reachable dev database, then perform the manual validation from quickstart.md "Additional validation (2026-08-20, User Story 5 — `BomStatus`)": trigger `GetAndSaveSummarySo` for (a) a sales order with no BOM yet but with order lines — confirm its saved `compl_summary_so` row has `BomStatus = 'No BOM'`; (b) a sales order that already has BOM data — confirm `BomStatus` is `NULL`; (c) re-run for the sales order from (a) after its BOM has since been created — confirm `BomStatus` reverts to `NULL`. No existing unit test file covers `ViewCompliancesSummaryService` (plan.md Technical Context "Testing"), so this manual pass is the primary validation. Depends on: T016, T018.
  - `dotnet build` for both `ComplianceSys.Domain` and `ComplianceSys.Application` — 0 errors (pre-existing nullable-reference warnings only, unrelated to this change).
  - Manual DB validation against a live/reachable Dynamics + MySQL dev environment was not run in this session (no reachable credentials) — same caveat as T010's original quickstart validation. The migration and code change are ready to apply; someone with dev-environment access should run the quickstart.md steps before deploying.

**Checkpoint**: `compl_summary_so.BomStatus` correctly flags every sales order processed by the summary job, self-correcting on each run — no other behavior of this feature changes.

---

## Follow-up: User Story 5, second writer (2026-08-20) — `GetViewCompliancesAsync`'s background save

User asked to verify ("kiểm tra") every function carrying the no-BOM fallback logic to confirm all
of them that save to `compl_summary_so` also update `BomStatus`. That check found a second,
previously-missed writer: `ViewCompliancesService.GetViewCompliancesAsync` (User Story 1's "get-all"
lookup) enqueues a Hangfire background job calling `ComplSummarySoService.SaveSummarySo`, which does
its own independent insert/update into `compl_summary_so` — separate from `GetAndSaveSummarySo`'s
(T018) — and had no `BomStatus` logic. `TransformSoAsync`, `GetViewCompliancesForDownloadAsync`, and
`GetViewCompliancesForSendAlertAsync` were checked and confirmed to not persist to `compl_summary_so`
at all, so none of them need this change. See spec.md FR-016 / SC-009 / User Story 1 Acceptance
Scenario 4, research.md R8, data-model.md `ComplSummarySo`, contracts/sales-line-fallback.md
"Added 2026-08-20 (second writer, FR-016)".

- [X] T020 [US5] Add `string? bomStatus = null` parameter to `SaveSummarySo` in `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Services/IComplSummarySoService.cs`, placed before the existing `CancellationToken ct = default` parameter.
  - Done.

- [X] T021 [P] [US5] In `compliance-sys-api/src/ComplianceSys.Application/Services/ComplSummarySoService.cs`, update `SaveSummarySo`'s signature to match T020, and set `BomStatus = bomStatus` on both the insert path (`newSummarySO` object literal) and the update-existing path (`exist.BomStatus = bomStatus;`, alongside the other `exist.*` assignments). Depends on: T020.
  - Done.

- [X] T022 [US5] In `ViewCompliancesService.GetViewCompliancesAsync` (`compliance-sys-api/src/ComplianceSys.Application/Services/ViewCompliancesService.cs`): declare `string? bomStatus = null;` near the method's other local declarations; immediately after `salesLineOpenMaterials = await _dynamicsDataService.GetSalesLineOpenMaterialFromDynamics(so.ReferenceValue);` (before the existing fallback `if`), set `bomStatus = salesLineOpenMaterials.Any() ? null : "No BOM";`; pass `bomStatus` as the new argument in the existing `BackgroundJob.Enqueue<IComplSummarySoService>(service => service.SaveSummarySo(so.ReferenceValue, tran, deliveryDate, bomStatus, ct))` call. Depends on: T020, T021.
  - Done.

- [X] T023 [US5] Run `dotnet build compliance-sys-api/src/ComplianceSys.Application/ComplianceSys.Application.csproj`, confirm 0 errors. Confirm no other caller of `IComplSummarySoService.SaveSummarySo` exists (grep `SaveSummarySo` across `src/` and `tests/`) that would need updating. Depends on: T020, T021, T022.
  - Build: 0 errors (pre-existing nullable-reference warnings only). `dotnet build` of `ComplianceSys.Api` hit the same pre-existing dev-instance file-lock copy failure noted in T001 (unrelated to this change — no compile errors, only `MSB3021`/`MSB3027` output-copy errors because a running dev instance holds the DLLs locked).
  - Grep confirmed exactly one call site (`ViewCompliancesService.cs:174-176`, updated in T022) plus one now-updated commented-out reference at line 172; no test file references `SaveSummarySo`.
  - Manual DB validation (quickstart.md "Additional validation (2026-08-20, second writer...)") not run in this session — same reachable-environment caveat as T019/T010.

**Checkpoint**: Both writers of `compl_summary_so` (`GetAndSaveSummarySo` and `GetViewCompliancesAsync`'s background save) now set `BomStatus` independently and consistently — no other function that saves to this table remains unaccounted for.

---

## Follow-up: User Story 6 (2026-08-20) — BOM column on the All Compliances list screen

Requested change: surface the saved `BomStatus` (User Story 5) as a new "BOM" column on the All
Compliances list screen for Sale Order (`compliance-view?ref-type=11&page=1&page-size=50`),
positioned immediately after "Invoice date" and before "Status": "Missing" when `BomStatus = "No
BOM"`, blank otherwise. This is the feature's first frontend-visible change. See spec.md User Story
6 / FR-017–FR-020 / SC-010, plan.md Summary/Technical Context/Constitution Check/Project Structure
("Update 2026-08-20, User Story 6"), research.md R9, data-model.md `RSVNSalesOrderOpenInvoiceCogs`,
contracts/sales-line-fallback.md "Contract addition: GET api/view-compliances/get-dynamics (Get365)".

- [X] T024 [P] [US6] Add `public string? BomStatus { get; set; }` to `RSVNSalesOrderOpenInvoiceCogs` in `compliance-sys-api/src/ComplianceSys.Domain/Dynamics/RSVNSalesOrderOpenInvoiceCogs.cs`, alongside the other enriched-at-request-time fields (`TotalCompliances`, `TotalMissing`, etc.).
  - Done.

- [X] T025 [US6] In `ViewCompliancesController.Get365`'s existing per-row enrichment loop (`compliance-sys-api/src/ComplianceSys.Api/Controllers/ViewCompliancesController.cs`, ~line 109-128): in the `if (summary != null)` branch, add `so.BomStatus = summary.BomStatus;` alongside the other `so.Total*`/`so.*Emails` assignments. Do not add anything to the `else` branch — `so.BomStatus` stays at its default `null` there, matching FR-020. Depends on: T024.
  - Done.

- [X] T026 [P] [US6] In `compliance-client/src/presentation/pages/compliance-view/hooks/useAllCompliancesColumnsSaleOrder.jsx`: add a new `GridColDef` to the `columns` array immediately after the `invoiceDate` block and before the `statusForUi` block — `field: "bomStatus"`, `headerName: "BOM"`, `width: 90`, `filterable: false`, `renderCell` returning a `Typography` showing `"Missing"` when `params.value === "No BOM"`, empty string otherwise (research.md R9 has the exact snippet). Also add `bomStatus: true` to `defaultColumnVisibility` alongside `invoiceDate`. Do not edit the sibling, unrouted `compliance-view/index.jsx` — confirm via `RouteResolver.jsx` that `index_new.jsx` is the routed component (research.md R9 "File-routing correction").
  - Done.

- [X] T027 [US6] Run `dotnet build compliance-sys-api/src/ComplianceSys.Domain/ComplianceSys.Domain.csproj` and `dotnet build compliance-sys-api/src/ComplianceSys.Api/ComplianceSys.Api.csproj` (or `ComplianceSys.Application` if the Api project's dev-instance file lock — T001/T019's known issue — is active), confirm 0 compile errors. Perform the manual validation from quickstart.md "Additional validation (2026-08-20, User Story 6 — BOM column on the list screen)": open the list screen, confirm the "BOM" column appears in the right position, shows "Missing" for a sales order with saved `BomStatus = 'No BOM'`, and is blank for one with `BomStatus IS NULL`. Depends on: T024, T025, T026.
  - Backend build: `ComplianceSys.Domain` — 0 errors. `ComplianceSys.Api` hit the same pre-existing dev-instance file-lock output-copy failure as T001/T019 (`MSB3021`/`MSB3027`, not a compile error) — confirmed via `grep -i "error CS"` on the build output that there are zero actual C# compile errors. `ComplianceSys.Application` (unaffected by this task's files, re-checked for regressions) — 0 errors.
  - Frontend: ran `npx eslint` on the modified file. 2 pre-existing `no-unused-vars` errors remain (`isOverdue` in the untouched `statusForUi` block, `totalMissing` in the untouched `actions` block) — neither is in the new `bomStatus` column code, which is lint-clean. A full `npm run build` was not run in this session.
  - Manual browser validation against a live app + reachable dev database was not run in this session (no reachable environment) — same caveat as T019/T010's quickstart validation.

**Checkpoint**: The BOM column is visible on the Sale Order list screen and correctly reflects each row's saved `BomStatus` — the feature's saved backend signal (User Stories 3/5, 1/6) is now visible to end users, closing the loop from "detect no BOM" (User Stories 1-4) → "save it" (User Story 5/second writer) → "show it" (User Story 6).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately.
- **Foundational (Phase 2)**: Empty — nothing blocks Phase 3.
- **User Story 1 (Phase 3)**: Depends on Setup completion (T001) only.
- **Polish (Final Phase)**: Depends on User Story 1 completion (T009, T010).
- **User Story 5 follow-up (T016–T019)**: Independent of User Stories 1–4's task chain (different
  files: entity + migration + `ViewCompliancesSummaryService`, none of which User Stories 1–4 touch
  except reusing `BuildSalesLineOpenMaterialFallbackAsync` — already complete). Can start immediately;
  T016/T017 are parallel, T018 depends on T017, T019 depends on T016 and T018.
- **User Story 5, second writer (T020–T023)**: Depends on T017 (`ComplSummarySo.BomStatus` must exist
  to compile). Independent of T018/T019 (different files: `IComplSummarySoService.cs`,
  `ComplSummarySoService.cs`, `ViewCompliancesService.cs`) — can run in parallel with the T018/T019
  pair once T017 is done. T020 → T021 (interface signature before implementation) → T022 (depends on
  both) → T023 (validation, depends on all three).
- **User Story 6, BOM column (T024–T027)**: Independent of every other task in this feature (reads
  `compl_summary_so.BomStatus` at request time — does not depend on T016-T023 having run first,
  though it obviously needs the column and its writers to exist for the value to be meaningful at
  runtime). T024 (backend DTO) and T026 (frontend column) can run in parallel — different projects,
  no shared file. T025 depends on T024 (needs the new property to compile). T027 depends on T024,
  T025, T026.

### Task-Level Dependencies (within US1)

- T002 → T003, T004, T006 (interface signatures before their implementations/consumers)
- T003, T004 → T005 (implementations before their tests)
- T003, T004, T006 → T007 (fetch methods + transform-service signature before the transform-service implementation)
- T007 → T008 (implementation before its tests)
- T006, T007 → T009 (fallback method must exist before the call site uses it)
- T005, T008, T009 → T010 (all tests and the call-site wiring must exist before the full validation pass)

### Parallel Opportunities

- T005 (DynamicsDataService tests) and T008 (TransformService tests) touch different files and can
  run in parallel once their respective implementation tasks (T003/T004 and T007) are done.
- T002, T003, T004 all touch the same two files (`IDynamicsDataService.cs`, `DynamicsDataService.cs`)
  and must be done sequentially, not in parallel.

---

## Parallel Example: User Story 1

```bash
# After T003 and T004 (DynamicsDataService implementations) and T007 (transform-service implementation) are done:
Task: "Add unit tests for the two new DynamicsDataService methods in compliance-sys-api/tests/ComplianceSysApi.UnitTests/Services/ViewCompliances/DynamicsDataServiceTests.cs"
Task: "Add unit tests for BuildSalesLineOpenMaterialFallbackAsync in compliance-sys-api/tests/ComplianceSysApi.UnitTests/Services/ViewCompliances/ViewCompliancesTransformServiceTests.cs"
```

---

## Implementation Strategy

### MVP First (and only) — User Story 1

1. Complete Phase 1: Setup (T001).
2. Phase 2: Foundational — nothing to do.
3. Complete Phase 3: User Story 1 (T002–T010), in the dependency order listed above.
4. **STOP and VALIDATE**: quickstart.md's before/after checks (T010) confirm the fix without
   regressing sales orders that already have BOM data.
5. Complete the Final Phase (T011) as a quick scope-containment check, then this feature is done —
   there is no incremental multi-story rollout for this change.

---

## Notes

- Single-story feature: every implementation task is `[US1]`; there is no story-independence
  concern to manage between multiple stories.
- T002, T003, T004 share two files and must be sequenced as listed — do not parallelize them.
- Commit after each task or logical group, per repository convention.
- New code comments must be in Vietnamese, matching the surrounding file's existing style
  (Constitution Principle IV) — no UI labels are involved since this feature has no frontend surface.
- T016–T019 (User Story 5) are the only tasks in this feature that touch persisted schema
  (`compl_summary_so`) — apply the migration (T016) to every environment **before** deploying the
  code change (T018). `ComplSummarySoService`'s Dapper-based insert/update writes every mapped
  property by column name, so if `BomStatus` is added to the entity while the DB column does not yet
  exist, every save to `compl_summary_so` on that environment (not just this feature's new field)
  will fail with an "unknown column" SQL error until the migration is applied — this is a hard
  ordering requirement, not just a preference.
- T020–T023 (second writer) exist because `compl_summary_so` turned out to have two independent
  writers, not one — always check for every persister of a table before assuming a single write path
  is the whole picture, especially when a fire-and-forget background job (`BackgroundJob.Enqueue`)
  is involved, since those are easy to miss by only reading a method's direct, synchronous calls.
- T024–T027 (User Story 6) is the only frontend work in this feature. Two files with the same name
  exist in `compliance-view/` (`index.jsx` and `index_new.jsx`) — only `index_new.jsx` is routed
  (confirmed via `RouteResolver.jsx`, research.md R9); do not edit `index.jsx` by mistake. The column
  hook itself (`useAllCompliancesColumnsSaleOrder.jsx`) is unambiguous — only one such file exists.
