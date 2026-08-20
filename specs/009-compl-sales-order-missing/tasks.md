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

## Phase 6: Update - Alert email column layout, computed Status/Days remaining (2026-08-10)

**Purpose**: The feature spec was revised to finalize the alert email's exact 14-column layout and to require that the `Status` and `Days remaining` columns be computed at send time from each record's own `Code`/`ValidTo`, rather than shown as-is from storage (spec.md FR-012–FR-014, plan.md 2026-08-10 update, research.md R8). This phase updates the already-implemented `SendMailAndNotificationForSalesOrderMissing` (T012) to match; it does not touch `ComplSoMissing`, `ComplSoMissingResponseDto`, the repository, `RefreshSalesOrderMissingComplianceAsync`, or the controller endpoint, none of which are affected by this change.

**⚠️ CRITICAL**: This phase only touches the email-rendering method — do not change the entity, DTO, repository, or refresh logic while completing it.

- [X] T023 [US2] Add two new private static helper methods to `compliance-sys-api/src/ComplianceSys.Application/Services/ComplNotificationService.cs`, next to the existing `SplitEmails`/`BuildEmailTitle` private helpers, per research.md R8:
  - `ComputeSalesOrderMissingStatus(string code, DateTime? validTo)` → returns `"Missing"` when `code` is null/empty; `"Expired"` when `code` is present and `validTo.HasValue && validTo.Value.Date < DateTime.Today`; otherwise `"Valid"` (spec.md FR-013).
  - `FormatDaysRemaining(DateTime? validTo)` → returns `null` when `validTo` is null; otherwise `$"{(validTo.Value.Date - DateTime.Today).Days} days left"` (positive N when still valid, negative N with a leading minus when already expired) (spec.md FR-014).
- [X] T024 [US2] Modify the `complianceList` anonymous projection and `customHeaders` dictionary inside `SendMailAndNotificationForSalesOrderMissing` (`ComplNotificationService.cs`, currently lines ~767-793) to the 14-column layout from spec.md FR-012, in this exact order: `SalesId, MasterCode, MasterName, Status, Code, Name, ValidFrom, ValidTo, DaysRemaining, ResponsibleEmails, Description, MappedRefTypeCode, MappedInputValue, MappedRefTypeName`, with `customHeaders` labels `"Sales order", "Master code", "Master name", "Status", "Code", "Name", "Valid from", "Valid to", "Days remaining", "Responsible emails", "Description", "Type", "Product", "Product name"` respectively. Set `Status = ComputeSalesOrderMissingStatus(c.Code, c.ValidTo)` and `DaysRemaining = FormatDaysRemaining(c.ValidTo)` using T023's helpers; add `ResponsibleEmails = string.Join("<br/>", (c.RespGroups ?? []).SelectMany(g => g.Emails ?? []).Distinct())` as a new per-row value (distinct from the existing aggregate `responsibleEmails`/`allRecipientEmails` used for the mail's To/Cc header further down in the same method, which is unchanged) (depends on T023).
- [X] T025 [US2] Update the Vietnamese comment immediately above `SendMailAndNotificationForSalesOrderMissing` in `ComplNotificationService.cs` to describe the new 14-column layout and that `Status`/`Days remaining` are computed at send time from each row's own `Code`/`ValidTo` (not copied from the stored `Status` column), per Constitution Principle IV (depends on T024).

**Checkpoint**: The alert email shows exactly the 14 columns from spec.md FR-012, with `Status`/`Days remaining` correctly reflecting each row's current `Code`/`ValidTo` as of send time.

---

## Phase 7: Update - Excel attachment on the alert email (2026-08-10)

**Purpose**: The feature spec was further revised to require an Excel (`.xlsx`) attachment on every sent alert email, mirroring the same columns/data as the email body, named `compl-sales-order-missing-<yyyyMMddHHmmss>` (spec.md FR-015–FR-017, plan.md 2026-08-10 Excel-attachment update, research.md R9/R10). This phase adds that attachment to the already-implemented `SendMailAndNotificationForSalesOrderMissing` (T012, revised by T023-T025); it does not touch `ComplSoMissing`, `ComplSoMissingResponseDto`, the repository, `RefreshSalesOrderMissingComplianceAsync`, or the controller endpoint.

**⚠️ CRITICAL**: This phase only touches the email-sending method — do not change the entity, DTO, repository, or refresh logic while completing it. `ClosedXML` is already a `PackageReference` in `ComplianceSys.Application.csproj` (v0.102.3) — do not add a new Excel library.

- [X] T027 [US2] Add a new private static helper method `BuildSalesOrderMissingExcelAttachment(List<dynamic> complianceList, Dictionary<string, string> customHeaders)` returning `byte[]` to `compliance-sys-api/src/ComplianceSys.Application/Services/ComplNotificationService.cs`, following the exact from-scratch-workbook pattern already used by `EutrMastersExportService.ExportToExcelAsync` (`new XLWorkbook()` → `workbook.Worksheets.Add(...)` → header row from `customHeaders.Values` → data rows read via reflection over `customHeaders.Keys` against the first item's type → `SaveAs(MemoryStream)` → `outputStream.ToArray()`), per research.md R9. When the column key is `"ResponsibleEmails"`, replace `"<br/>"` in the cell value with `"\n"` (same underlying email list as the HTML table, re-rendered for a spreadsheet cell instead of HTML).
- [X] T028 [US2] In `SendMailAndNotificationForSalesOrderMissing` (`ComplNotificationService.cs`), after `complianceList`/`customHeaders` are built (T024) and before the existing `Mail.SendAttachment`-gated per-row SharePoint attachment loop (currently ~lines 884-908), call T027's helper and unconditionally add its result to the `attachments` list: `attachments.Add(new AttachmentInfo { Type = AttachmentType.Stream, FileStream = new MemoryStream(excelBytes), FileName = $"compl-sales-order-missing-{DateTime.Now:yyyyMMddHHmmss}.xlsx" });` — do not gate this behind the `Mail.SendAttachment` config flag (spec.md FR-015 is unconditional, unlike the existing per-row attachment feature) (depends on T027).
- [X] T029 [US2] Update the Vietnamese comment immediately above `SendMailAndNotificationForSalesOrderMissing` in `ComplNotificationService.cs` (already updated by T025) to also mention the new unconditional Excel attachment and its file-naming convention, per Constitution Principle IV (depends on T028).

**Checkpoint**: Every alert email sent by `SendSalesOrderAlertAsync` carries exactly one `.xlsx` attachment whose columns/data match the email body and whose file name follows `compl-sales-order-missing-<yyyyMMddHHmmss>`.

---

## Phase 9: Update - Deduplicate alert rows, drop Sales order column (2026-08-18)

**Purpose**: The feature spec was further revised so the alert read-back deduplicates records by `MasterCode`, `Code`, `MappedRefTypeCode`, `MappedInputValue`, and the Sales order column is removed from both the email body and the Excel attachment (spec.md FR-008, FR-012, SC-007; plan.md 2026-08-18 update; research.md R11). This phase updates the already-implemented `SendSalesOrderAlertAsync` and `SendMailAndNotificationForSalesOrderMissing` (T014, T012/T024) to match; it does not touch `ComplSoMissing`, `ComplSoMissingResponseDto`, the repository, `RefreshSalesOrderMissingComplianceAsync`, the controller, or the schema — `SalesId` remains a stored/DTO field and is still used, unchanged, by the per-recipient notification message text.

**⚠️ CRITICAL**: This phase only touches `ComplNotificationService.cs` (the read-back step in `SendSalesOrderAlertAsync` and the `complianceList`/`customHeaders` in `SendMailAndNotificationForSalesOrderMissing`) — do not change the entity, DTO, repository, refresh logic, or controller while completing it.

- [X] T031 [US2] Modify `SendSalesOrderAlertAsync` in `compliance-sys-api/src/ComplianceSys.Application/Services/ComplNotificationService.cs` (currently lines ~176-206): insert `.DistinctBy(r => new { r.MasterCode, r.Code, r.MappedRefTypeCode, r.MappedInputValue })` on the `IEnumerable<ComplSoMissing>` returned by `_complSoMissingRepository.GetAllAsync()`, immediately before the existing `.Select(r => new ComplSoMissingResponseDto { ... })` projection, so the resulting `alertCompliances` contains at most one row per distinct combination (spec.md FR-008, research.md R11). Do not remove `SalesId` from the `ComplSoMissingResponseDto` projection itself.
- [X] T032 [US2] Modify the `complianceList` anonymous projection and `customHeaders` dictionary inside `SendMailAndNotificationForSalesOrderMissing` (`ComplNotificationService.cs`, currently lines ~843-877): remove `c.SalesId` from `complianceList` and remove the `{ "SalesId", "Sales order" }` entry from `customHeaders`, leaving the 13-column layout from spec.md FR-012 (`MasterCode, MasterName, Status, Code, Name, ValidFrom, ValidTo, DaysRemaining, ResponsibleEmails, Description, MappedRefTypeCode, MappedInputValue, MappedRefTypeName`). Leave the rest of the method (recipient resolution, `BuildSalesOrderMissingExcelAttachment` call, per-recipient `ComplNotification` construction using `compliance.SalesId`) unchanged (depends on T031 for the dedup to apply to the same call, independent file location otherwise).
- [X] T033 [US2] Update the Vietnamese comments immediately above `SendSalesOrderAlertAsync` and above `SendMailAndNotificationForSalesOrderMissing` in `ComplNotificationService.cs` to describe the new dedup-by-four-columns read-back step and the 13-column layout (no Sales order column) in the email/Excel content, per Constitution Principle IV (depends on T031, T032).

**Checkpoint**: `SendSalesOrderAlertAsync` reads back `compl_so_missing` deduplicated by Master code/Code/Type/Product, and the sent email + Excel attachment show exactly 13 columns with no Sales order column; `compl_so_missing` storage and the per-recipient notification message are unaffected.

---

## Phase 10: Update - Highlight Expired rows yellow in the Excel attachment (2026-08-20)

**Purpose**: The feature spec was further revised so the Excel attachment highlights each row whose Status is "Expired" with the same yellow background the email body already applies to those rows (spec.md FR-018, SC-008; plan.md 2026-08-20 update; research.md R12). This phase updates the already-implemented `BuildSalesOrderMissingExcelAttachment` (T027) to match; it does not touch `ComplSoMissing`, `ComplSoMissingResponseDto`, the repository, `RefreshSalesOrderMissingComplianceAsync`, the controller, the schema, or the email body's own highlighting (`Helper.GenerateHtmlTableValidTo`, unchanged).

**⚠️ CRITICAL**: This phase only touches `BuildSalesOrderMissingExcelAttachment` in `ComplNotificationService.cs` — do not change the entity, DTO, repository, refresh logic, controller, or the email-rendering helper (`Helper.cs`) while completing it. `ClosedXML`'s `XLColor` is already available via the existing `ClosedXML` package reference — no new package needed.

- [X] T035 [US2] Modify `BuildSalesOrderMissingExcelAttachment` in `compliance-sys-api/src/ComplianceSys.Application/Services/ComplNotificationService.cs` (T027, currently the row-writing loop around lines ~448-459): after writing a row's cell values, look up that row's already-computed `Status` value via the same `propsByKey` reflection lookup already used for the other columns (`propsByKey["Status"]?.GetValue(item)?.ToString()`), and when it equals `"Expired"`, apply `sheet.Range(row, 1, row, customHeaders.Count).Style.Fill.BackgroundColor = XLColor.FromHtml("#fff59d")` — the same hex value already hardcoded for the email row highlight in `Helper.cs:244` (spec.md FR-018, research.md R12). Do not apply the fill when Status is `"Missing"` or `"Valid"`.
- [X] T036 [US2] Update the Vietnamese comment immediately above `BuildSalesOrderMissingExcelAttachment` in `ComplNotificationService.cs` to mention the new Expired-row yellow highlight and that it mirrors the email body's existing highlight color, per Constitution Principle IV (depends on T035).

**Checkpoint**: Every Excel attachment produced by `SendSalesOrderAlertAsync` highlights Expired rows in the same yellow already used in the email body; non-Expired rows remain unhighlighted in both.

---

## Phase 11: Update - Re-add a combined Sales order column (2026-08-20)

**Purpose**: The feature spec was further revised to reintroduce a Sales order column as the last column in both the email body and the Excel attachment, superseding the 2026-08-18 removal — now showing every distinct sales order code collapsed into each Master code/Code/Type/Product group, combined into one value (e.g. "SO1, SO2") (spec.md FR-008, FR-012, FR-019, SC-007, SC-009; plan.md 2026-08-20 update; research.md R13). This phase updates the already-implemented `SendSalesOrderAlertAsync` (T014, revised by T031) and `SendMailAndNotificationForSalesOrderMissing` (T012, revised by T024/T032) plus `ComplSoMissingResponseDto` (T010) to match; it does not touch `ComplSoMissing`, the repository, `RefreshSalesOrderMissingComplianceAsync`, the controller, or the schema, and it does not change `ComplSoMissingResponseDto.SalesId`'s existing meaning or the per-recipient notification message text that reads it.

**⚠️ CRITICAL**: This phase touches `ComplSoMissingResponseDto.cs` (new property only) and `ComplNotificationService.cs` (the read-back grouping in `SendSalesOrderAlertAsync` and the `complianceList`/`customHeaders` in `SendMailAndNotificationForSalesOrderMissing`) — do not change the entity, repository, refresh logic, controller, or the per-recipient notification message text (`compliance.SalesId` usage) while completing it. No new NuGet package needed.

- [X] T038 [P] [US2] Add `public string? CombinedSalesIds { get; set; }` to `compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/ComplSoMissingResponseDto.cs` (T010), alongside the existing `AlertGroups`/`RespGroups` properties, with a Vietnamese comment explaining it holds the distinct sales order codes from a dedup group joined `", "`, distinct from `SalesId` (single value, unchanged) (spec.md FR-019, research.md R13).
- [X] T039 [US2] Modify `SendSalesOrderAlertAsync` in `compliance-sys-api/src/ComplianceSys.Application/Services/ComplNotificationService.cs` (T031, currently lines ~179-210): change `.DistinctBy(r => new { r.MasterCode, r.Code, r.MappedRefTypeCode, r.MappedInputValue })` to `.GroupBy(r => new { r.MasterCode, r.Code, r.MappedRefTypeCode, r.MappedInputValue })`, and change the subsequent `.Select(r => new ComplSoMissingResponseDto { ... })` to build from each group's first item (`var first = g.First();` then map every existing field from `first` exactly as before, `SalesId = first.SalesId`), adding `CombinedSalesIds = string.Join(", ", g.Select(x => x.SalesId).Where(s => !string.IsNullOrWhiteSpace(s)).Distinct())` (spec.md FR-008, research.md R13) (depends on T038).
- [X] T040 [US2] Modify the `complianceList` anonymous projection and `customHeaders` dictionary inside `SendMailAndNotificationForSalesOrderMissing` (`ComplNotificationService.cs`, T032, currently lines ~857-889): add `SalesOrder = c.CombinedSalesIds` as the last entry in `complianceList`, and add `{ "SalesOrder", "Sales order" }` as the last entry in `customHeaders`, producing the 14-column layout from spec.md FR-012 with Sales order last. Leave the rest of the method (recipient resolution, `BuildSalesOrderMissingExcelAttachment` call, per-recipient `ComplNotification` construction using `compliance.SalesId`) unchanged (depends on T039).
- [X] T041 [US2] Update the Vietnamese comments immediately above `SendSalesOrderAlertAsync` and above `SendMailAndNotificationForSalesOrderMissing` in `ComplNotificationService.cs` to describe the grouping (not just dedup) read-back step and the 14-column layout (Sales order last, combined value) in the email/Excel content, per Constitution Principle IV (depends on T039, T040).

**Checkpoint**: `SendSalesOrderAlertAsync` reads back `compl_so_missing` grouped by Master code/Code/Type/Product, and the sent email + Excel attachment show exactly 14 columns with Sales order last, showing every distinct contributing sales order code combined per row; `compl_so_missing` storage, `ComplSoMissingResponseDto.SalesId`, and the per-recipient notification message are unaffected.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Final checks that span both user stories.

- [X] T016 [P] Review all new/changed C# files (T002–T015) and confirm code comments are written in Vietnamese where a comment is warranted, per Constitution Principle IV (identifiers stay in English).
- [ ] T017 Run `specs/009-compl-sales-order-missing/quickstart.md` end-to-end against a local environment (fix the `compl_so_missing` migration if not yet applied, call `test-sales-order-alert`, verify the table and the sent alert) to validate spec.md's SC-001 through SC-009, including the revised idempotency check in quickstart.md step 4, the per-row column/Status/Days-remaining checks in step 5, the Excel-attachment check in step 5, the dedup check in step 5, the Excel Expired-row yellow-highlight check in step 5, and the combined Sales order column check in step 5 (depends on Phase 5, Phase 6, Phase 7, Phase 9, Phase 10, and Phase 11). **Not run this session** — requires a live MySQL + Dynamics-connected environment; needs manual verification.
- [X] T018 Confirm `dotnet build` succeeds for the whole `compliance-sys-api` solution after all changes (no regressions to `test-alert` / `SendAlertAsync`, which must remain unchanged; no remaining reference to `DeleteBySalesIdAsync`) (depends on Phase 5). Verified `ComplianceSys.Infrastructure` and `ComplianceSys.Application` build with 0 errors; `ComplianceSys.Api`'s own build was blocked only by file locks from a running `ComplianceSys.Api` process (PID 12136) on this machine, not a compile error — restart that process to pick up the change and re-verify the full solution build.
- [X] T026 Re-run `dotnet build` for the whole `compliance-sys-api` solution after Phase 6's changes to `ComplNotificationService.cs` (T023–T025), confirming no regressions to `test-alert`/`SendAlertAsync` or to `RefreshSalesOrderMissingComplianceAsync` (depends on Phase 6). Verified `ComplianceSys.Application` (the only project touched) builds standalone with 0 errors. The full-solution build reported 2 errors, both file-lock `MSB3491`/`CS0016` write-access failures against `ComplianceSys.Api`'s and the test project's `obj`/`bin` output — caused by a currently-running `ComplianceSys.Api.exe` process (PID 25052) holding those files open, not a compile error in this feature's code (same pre-existing environmental issue already noted under T018). Restart that process and re-build to confirm a fully clean solution build.
- [X] T030 Re-run `dotnet build` for the whole `compliance-sys-api` solution after Phase 7's changes to `ComplNotificationService.cs` (T027–T029), confirming ClosedXML usage compiles cleanly (it is already referenced by `ComplianceSys.Application.csproj`, so no restore/package-reference change is expected) and no regressions to `test-alert`/`SendAlertAsync` or the email-column layout from Phase 6 (depends on Phase 7). Verified `ComplianceSys.Application` builds standalone with 0 errors (`using ClosedXML.Excel;` resolved without a package-reference change, confirming the existing 0.102.3 reference is sufficient). The full-solution build hit the same pre-existing environmental file-lock error (`CS2012`, `ComplianceSys.Infrastructure.dll` access denied) caused by the still-running `ComplianceSys.Api.exe` process — not a compile error in this feature's code (same class of issue as T018/T026).
- [X] T034 Re-run `dotnet build` for the whole `compliance-sys-api` solution after Phase 9's changes to `ComplNotificationService.cs` (T031–T033), confirming `DistinctBy` (BCL, no new package) compiles cleanly and no regressions to `test-alert`/`SendAlertAsync`, the Phase 6 column layout (now 13 columns), or the Phase 7 Excel attachment (depends on Phase 9). Verified `ComplianceSys.Application` builds standalone with 0 errors (435 pre-existing nullable-reference warnings only, none new). Full-solution build not re-verified this session — same pre-existing `ComplianceSys.Api.exe` file-lock issue noted under T018/T026/T030 would need that process stopped first; not a compile error in this feature's code.
- [X] T037 Re-run `dotnet build` for the whole `compliance-sys-api` solution after Phase 10's changes to `ComplNotificationService.cs` (T035–T036), confirming `XLColor.FromHtml` (already available via the referenced `ClosedXML` package) compiles cleanly and no regressions to `test-alert`/`SendAlertAsync`, the Phase 6 column layout, the Phase 7 Excel attachment, or the Phase 9 dedup/column-drop (depends on Phase 10). Verified `ComplianceSys.Application` builds standalone with 0 errors (438 pre-existing nullable-reference warnings only, none new). Full-solution build hit the same pre-existing `ComplianceSys.Api.exe` file-lock issue noted under T018/T026/T030/T034 (`CS2012` on `ComplianceSys.Infrastructure.dll`) — not a compile error in this feature's code.
- [X] T042 Re-run `dotnet build` for the whole `compliance-sys-api` solution after Phase 11's changes to `ComplSoMissingResponseDto.cs` and `ComplNotificationService.cs` (T038–T041), confirming `GroupBy` (BCL, no new package) compiles cleanly, `compliance.SalesId` (per-recipient notification message text) still resolves unchanged, and no regressions to `test-alert`/`SendAlertAsync`, the Phase 6 column layout, the Phase 7 Excel attachment, the Phase 9 dedup, or the Phase 10 highlight (depends on Phase 11). Verified `ComplianceSys.Application` builds standalone with 0 errors. Full-solution build failed with `MSB3027`/`MSB3021` (not a compile error) — a **currently running** `ComplianceSys.Api` process (PID 26988) has `ComplianceSys.Infrastructure.dll`/`ComplianceSys.Application.dll` locked, blocking the output copy. This is very likely the root cause of the "treo, không ra được file" (hangs, no file produced) issue reported earlier in this session — stop that process before rebuilding/running to pick up all of this feature's changes.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately.
- **Foundational (Phase 2)**: Depends on Setup — BLOCKS both user stories (neither story compiles without the `ComplSoMissing` entity and repository).
- **User Story 1 (Phase 3)**: Depends on Foundational only. No dependency on User Story 2.
- **User Story 2 (Phase 4)**: Depends on Foundational; also calls User Story 1's `RefreshSalesOrderMissingComplianceAsync` (T009) from within `SendSalesOrderAlertAsync` (T014) — so Phase 4 cannot be *fully* exercised end-to-end until Phase 3 is done, even though T010–T013 (DTO, interface additions, mail method) can be authored in parallel with Phase 3.
- **Update (Phase 5)**: Depends on Phases 3 and 4 both being complete (it modifies code those phases already wrote) — T019/T020 (repository layer) before T021 (call site in the US1 refresh method) before T022 (comments).
- **Update (Phase 6)**: Depends on Phase 4 being complete (it modifies `SendMailAndNotificationForSalesOrderMissing`, written in T012); independent of Phase 5 (different method in the same file — Phase 5 touches `RefreshSalesOrderMissingComplianceAsync`, Phase 6 touches the mail method) but sequenced after it here since both update the same file — T023 (helpers) before T024 (projection/headers) before T025 (comment).
- **Update (Phase 7)**: Depends on Phase 6 being complete — it builds on the `complianceList`/`customHeaders` shape T024 produced and re-touches the comment T025 wrote — T027 (Excel-build helper) before T028 (call site/attach) before T029 (comment).
- **Update (Phase 9)**: Depends on Phase 7 being complete — it further modifies the same `complianceList`/`customHeaders` shape T024/T027/T028 produced and the `alertCompliances` read-back T014 wrote — T031 (dedup at read-back) before T032 (drop Sales order column from projection/headers) before T033 (comments).
- **Update (Phase 10)**: Depends on Phase 7 being complete (it modifies `BuildSalesOrderMissingExcelAttachment`, written in T027); independent of Phase 9 (different concern — dedup/columns vs. row fill — though both touch the same file, so sequenced after Phase 9 here) — T035 (highlight logic) before T036 (comment).
- **Update (Phase 11)**: Depends on Phase 9 being complete (it changes the `DistinctBy` Phase 9 introduced into a `GroupBy`, and further extends the `complianceList`/`customHeaders` shape Phase 9 last touched) and on Phase 10 being complete (both modify `ComplNotificationService.cs`, sequenced after Phase 10 here to avoid concurrent edits) — T038 (DTO property) before T039 (grouping/read-back) before T040 (projection/headers) before T041 (comments).
- **Polish (Phase 8)**: Depends on Phases 5, 6, 7, 9, 10, and 11 all being complete (T017 must validate the post-update behavior for the delete-all change, the new email columns, the Excel attachment, the dedup, the Excel highlight, and the combined Sales order column; T026 validates the build after Phase 6; T030 validates the build after Phase 7; T034 validates the build after Phase 9; T037 validates the build after Phase 10; T042 validates the build after Phase 11).

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
- Phase 6 (T023–T025) can be drafted in parallel with Phase 5 (T019–T022) — different methods in the same file, no shared logic — though both should land before Phase 8's T017/T026 validate the combined result.
- Phase 7's T027 (the new `BuildSalesOrderMissingExcelAttachment` helper) has no dependency on Phase 5 and could be drafted alongside it, but T028 (wiring it into `SendMailAndNotificationForSalesOrderMissing`) needs Phase 6's `complianceList`/`customHeaders` shape (T024) to exist first, so in practice Phase 7 is sequenced after Phase 6.
- Phase 10's T035 (Excel highlight logic) touches the same `BuildSalesOrderMissingExcelAttachment` method as Phase 7's T027/T028, so it must land after Phase 7; it does not need to wait on Phase 9 (different lines in the same file — Phase 9 touches the read-back and `complianceList`/`customHeaders`, Phase 10 touches only the row-fill logic inside the Excel helper), but is sequenced after it here to avoid concurrent edits to the same file.
- Phase 11's T038 (new `CombinedSalesIds` property on `ComplSoMissingResponseDto.cs`) has no dependency on Phase 9/10 and could be drafted in parallel with either, but T039 (the `GroupBy` change in `SendSalesOrderAlertAsync`) directly replaces the `DistinctBy` Phase 9's T031 introduced, so in practice Phase 11 is sequenced after Phase 9 (and after Phase 10, to avoid concurrent edits to the same file).

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
5. Apply Phase 6 update (email column layout + computed Status/Days remaining) → alert email now matches the revised spec.md
6. Apply Phase 7 update (Excel attachment) → every sent alert now carries a matching `.xlsx` attachment per the revised spec.md
7. Apply Phase 9 update (dedup + drop Sales order column) → the alert now shows one row per distinct Master code/Code/Type/Product combination, with 13 columns (no Sales order) in both the email and the Excel attachment, per the revised spec.md
8. Apply Phase 10 update (highlight Expired rows yellow in the Excel attachment) → the Excel attachment now visually matches the email body's Expired-row yellow highlight, per the revised spec.md
9. Apply Phase 11 update (re-add a combined Sales order column) → the alert now shows a 14th column, Sales order (last), combining every distinct contributing sales order code per grouped row, per the revised spec.md
10. Polish → confirm no regression to the existing `test-alert` flow, no remaining `DeleteBySalesIdAsync` reference, the alert email's columns render correctly (14, Sales order last), the Excel attachment matches the email body (including the Expired-row highlight and the combined Sales order column), and duplicate Master code/Code/Type/Product rows collapse to one with their sales order codes combined

---

## Notes

- [P] tasks = different files, no unmet dependencies
- [Story] label maps task to specific user story for traceability
- No test tasks were generated (see Tests note at the top); add them later under `compliance-sys-api/tests/ComplianceSysApi.UnitTests/Services/` following the existing one-class-per-service convention if desired
- Commit after each task or logical group
- Verify `test-alert` / `SendAlertAsync` still work unchanged after every task that touches `ComplNotificationService.cs` or `ComplNotificationController.cs`
- T019–T022 (Phase 5) are the only open tasks needed to bring the already-implemented code in line with the 2026-08-04 spec revision; T001–T016 remain checked off as still valid (unaffected by the revision) rather than being re-done.
- T023–T026 (Phase 6) are the only open tasks needed to bring the already-implemented `SendMailAndNotificationForSalesOrderMissing` in line with the 2026-08-10 spec revision (FR-012–FR-014); no other checked-off task is affected.
- T027–T030 (Phase 7) are the only open tasks needed to add the Excel attachment per the 2026-08-10 spec revision (FR-015–FR-017); they build directly on Phase 6's `complianceList`/`customHeaders` shape and reuse the `ClosedXML` package already referenced by `ComplianceSys.Application.csproj` — no new package, no other checked-off task affected.
- T031–T034 (Phase 9) are the only open tasks needed to bring the already-implemented `SendSalesOrderAlertAsync`/`SendMailAndNotificationForSalesOrderMissing` in line with the 2026-08-18 spec revision (FR-008, FR-012, SC-007); they reuse the built-in `DistinctBy` (no new package) and further narrow Phase 6/7's `complianceList`/`customHeaders` shape — no other checked-off task affected, and `SalesId` remains on the entity/DTO/notification-message path unchanged.
- T035–T037 (Phase 10) are the only tasks needed to bring the already-implemented `BuildSalesOrderMissingExcelAttachment` in line with the 2026-08-20 spec revision (FR-018, SC-008); they reuse the already-referenced `ClosedXML` package's `XLColor` (no new package) and the existing `Style.Fill.BackgroundColor` row-highlight pattern already used elsewhere in this codebase — no other checked-off task affected, and the email body's own highlighting (`Helper.cs:244`) is untouched.
- T038–T042 (Phase 11) are the only tasks needed to bring `ComplSoMissingResponseDto`/`SendSalesOrderAlertAsync`/`SendMailAndNotificationForSalesOrderMissing` in line with the 2026-08-20 combined-Sales-order-column spec revision (FR-008, FR-012, FR-019, SC-007, SC-009); they reuse the built-in `GroupBy` (no new package) in place of Phase 9's `DistinctBy` and add one new DTO property — no other checked-off task affected, and `ComplSoMissingResponseDto.SalesId`/the per-recipient notification message text that reads it are untouched.
