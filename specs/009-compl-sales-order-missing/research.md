# Phase 0 Research: Sales Order Missing-Compliance Alert

## R1. Where does each piece of reused logic live, and how is it called?

**Decision**: Call `IComplDynamicsService.GetDynRefePagedAsync(refType, request, ct)` and `IViewCompliancesService.GetViewCompliancesAsync(filters, deliveryDate, cusCode, ct)` directly from `ComplNotificationService` via constructor injection, exactly as the controllers already do — no new HTTP calls, no duplicated query logic.

**Rationale**: Both are already registered in DI (`ComplianceSys.Application/DependencyInjection.cs`: `AddScoped<IComplDynamicsService, ComplDynamicsService>()` and `AddScoped<IViewCompliancesService, ViewCompliancesService>()`), so an in-process service-to-service call is idiomatic and matches Constitution Principle III (reuse existing backend as-is). `IViewCompliancesService` is already a constructor parameter of `ComplNotificationService` (used for `ManualSendAlertAsync`); only `IComplDynamicsService` needs to be added as a new constructor parameter.

**Alternatives considered**: Issuing real HTTP calls to `DynController`/`ViewCompliancesController` from the service — rejected, since it would add network hops and auth complexity for what is an in-process orchestration, and the existing codebase never calls its own controllers over HTTP internally.

**Exact call shape**:
```csharp
var request = new PagedRequest { Page = 1, PageSize = 500, Filters = new List<FilterRequest>() };
var soPage = await _complDynamicsService.GetDynRefePagedAsync((int)ObjectType.SALE_ORDER_OPEN, request, ct);
foreach (var so in soPage.Items) { ... }
```
```csharp
var filters = new List<ViewCompliancesRequestDto> {
    new ViewCompliancesRequestDto { ReferenceType = ObjectType.SALE_ORDER, ReferenceValue = so.Code }
};
var results = await _viewCompliancesService.GetViewCompliancesAsync(filters, so.DeliveryDate, so.CustAccount, ct);
var missing = results.Where(r => r.Status == "MISSING");
```
`PagedRequest`/`FilterRequest`/`PagedResult<T>` come from `Shared.Dapper.Models` (already used by `DynController`).

## R2. `refType = 18` currently returns an empty result — must this be fixed?

**Decision**: Yes. Add a missing entry to `ComplDynamicsService.EntityMappings` for `18` (`ObjectType.SALE_ORDER_OPEN`), mapping to the same target as `11` (`("RSVNSalesOrderOpenInvoiceCogs", "SalesId", "CustName")`), so the existing "Open order" filter branch (already coded further down in `GetDynRefePagedAsync`, but currently unreachable because the method returns early when `EntityMappings.TryGetValue(refType, ...)` fails) is actually exercised.

**Rationale**: The feature spec explicitly requires reftype 18 ("open sales orders"). Verified via code read that `GetDynRefePagedAsync` has a dead special-case branch for `refType == (int)ObjectType.SALE_ORDER_OPEN` that already applies the `SalesStatus eq 'Open order'` filter — it's just unreachable today because `18` has no dictionary entry. Adding the one entry activates existing, already-written logic; it is a minimal, scoped bug fix to an existing method, not new parallel logic, and stays inside Constitution Principle III (reuse existing backend, verified-gap fixes only).

**Alternatives considered**:
- Use `refType = 11` (`SALE_ORDER`, works today) and filter the returned list in C# by `SalesStatus == "Open order"` — rejected because it deviates from the feature spec's explicit reftype=18 instruction and duplicates filtering logic that already exists (in dead-code form) inside `ComplDynamicsService`.
- Leave `EntityMappings` untouched and treat "always empty for refType=18" as acceptable — rejected because it would make the entire feature a no-op in practice.

## R3. `SendMailAndNotification` is private and typed to `ComplCompliancesResponseDto` — how does the new alert get sent?

**Decision**: Add a new method to `ComplNotificationService`, following the exact convention already used for `SendMailAndNotificationForMaster` (a public, `IComplNotificationService`-exposed sibling of the private `ComplCompliancesResponseDto` overload, built for a different row shape). Name it `SendMailAndNotificationForSalesOrderMissing(IEnumerable<ComplSoMissingResponseDto> compliances, string? userEmail, SendAlertType sendAlerType, ...)`, added to both `IComplNotificationService` and its implementation.

**Rationale**: The codebase already has this exact "one overload per source shape" pattern (`ComplCompliancesResponseDto` for the general alert, `ComplMasterResponse` for master-only alerts) — a third overload for `ComplSoMissingResponseDto` rows is a direct continuation of an established convention, not a new one. The HTML table build, recipient aggregation, and `ComplNotification` construction logic get re-implemented for the new row shape (see R4 for the one real difference), reusing the same private helpers (`BuildEmailTitle`, `SplitEmails`, `SaveNotificationsBatchAsync`) wherever the field shapes line up.

**Alternatives considered**: Changing the private `SendMailAndNotification`'s parameter type to a common interface/base implemented by both `ComplCompliancesResponseDto` and the new DTO — rejected as a larger, riskier refactor of a method already used by the production `test-alert`/`manual-alert` flows, for a benefit (one shared method vs. two near-identical ones) the codebase's own existing convention (separate `...ForMaster` overload) shows it does not value.

## R4. Recipient email extraction differs between `compl_so_missing` and `ComplCompliancesResponseDto`

**Decision**: The new `ComplSoMissingResponseDto`/entity has `AlertGroupsJson`/`ResponsibleGroupsJson` (matching `compl_so_missing` table columns) but **no flat `ResponsibleEmails`/`AlertEmails`/`ResponsibleForAddition`/`AlertForAddition` string columns** (unlike `ComplCompliancesResponseDto`/`ViewCompliancesResponseDto`, which have both forms). The new mail method must derive recipients by parsing `AlertGroupsJson`/`ResponsibleGroupsJson` into `List<GroupEmailsDto>` (same `JsonConvert.DeserializeObject<List<GroupEmailsDto>>(...)` pattern already used by `ViewCompliancesResponseDto.AlertGroups`/`RespGroups` and `ComplMasterResponse.AlertGroups`/`RespGroups`) and flattening each group's `Emails` list, instead of calling the existing `SplitEmails(string?)` helper (which expects a comma/semicolon-delimited flat string that this table does not have).

**Rationale**: Confirmed by reading the `compl_so_missing.sql` DDL (no flat email columns) against `ComplCompliancesResponseDto`'s fields (has both JSON and flat forms). Since `ViewCompliancesResponseDto` — the source of every row inserted into `compl_so_missing` — already exposes parsed `AlertGroups`/`RespGroups` properties, the new DTO can reuse that exact parsing logic when copying a `ViewCompliancesResponseDto` result into a `ComplSoMissingResponseDto`/entity for storage, and again when reading rows back for the mail step.

**Alternatives considered**: Adding new flat email columns to `compl_so_missing` to reuse `SplitEmails` verbatim — rejected as an unnecessary schema change; the table was clearly designed to carry the JSON group form only (it mirrors the subset of `ViewCompliancesResponseDto` fields that includes `*GroupsJson` but not the flat email fields), and group-JSON parsing is already a proven, repeated pattern in this codebase.

## R5. Delete-all-then-insert persistence pattern for `compl_so_missing` (revised 2026-08-04)

**Decision (superseded)**: The initial implementation added `DeleteBySalesIdAsync(string salesId, CancellationToken ct)` (raw `DELETE FROM compl_so_missing WHERE SalesId = @salesId`), called once per sales order inside the evaluation loop, immediately before that sales order's `InsertManyAsync`.

**Decision (current, 2026-08-04)**: Per the updated spec.md (FR-006, Edge Cases), `DeleteBySalesIdAsync` is removed entirely from `IComplSoMissingRepository`/`ComplSoMissingRepository`. In its place, add `DeleteAllAsync(CancellationToken ct)` — raw `DELETE FROM compl_so_missing` with no `WHERE` clause — called exactly **once**, in `RefreshSalesOrderMissingComplianceAsync`, immediately before the open-sales-order paging loop starts (not inside it, and not per sales order). `InsertManyAsync(IEnumerable<ComplSoMissing> rows, CancellationToken ct)` (raw parameterized `INSERT`, one statement per row via Dapper) and `GetAllAsync(CancellationToken ct)` (raw `SELECT * FROM compl_so_missing`) are unchanged.

**Rationale**: `compl_so_missing` has no primary key defined in its DDL, so there is no natural per-row key to `UPDATE`, and the feature no longer needs per-sales-order isolation for the delete step — the spec now requires the entire table to be cleared once before the run's evaluation begins, not per sales order code. This is a simpler statement (`DELETE FROM compl_so_missing` vs. a parameterized per-code delete) and removes one round-trip per sales order from the loop. It still follows the same raw-SQL Dapper style as `EutrTemplatesRepository.ReplaceDetailsAsync` (`Connection.ExecuteAsync(new CommandDefinition(sql, ..., transaction: Transaction, cancellationToken: ct))`).

**Consequence for duplicate sales order codes**: Because the delete is no longer scoped to a `SalesId`, if the same sales order code appears more than once in a single run's open-sales-order list, each occurrence's `InsertManyAsync` call adds its own rows independently — nothing removes the earlier occurrence's rows before the later occurrence inserts. This matches the updated spec's Edge Cases section, which now documents this as expected behavior for this run's data.

**Alternatives considered**: Using a MySQL stored procedure (the pattern `ComplCompliancesRepository` uses for its alert-source queries) — rejected because there is no existing `compl_sp_*` procedure for this table, and introducing one would require a new `Sqls/Procedures/*.sql` file plus `DELIMITER` handling for no benefit over parameterized Dapper SQL for a straightforward delete-all+insert.

## R6. Per-sales-order failure handling during the loop (delete-all step scoped, 2026-08-04)

**Decision**: Wrap each sales order's evaluation (compliance lookup + insert) in its own `try/catch`, logging via `Log.Error(ex, "...", so.Code)` and continuing to the next sales order, rather than letting one failure abort the whole run. The new `DeleteAllAsync()` call (R5) sits **outside** this per-item try/catch — it runs once, before the loop starts, so a failure there is not a "one sales order failed" case; it is caught only by `SendSalesOrderAlertAsync`'s outer `try/catch { Log.Error(...); throw; }`, which aborts the whole run (same as a `GetDynRefePagedAsync` failure would).

**Rationale**: The feature spec's Edge Cases and FR-011 explicitly require that a lookup failure for one sales order must not stop the rest of the run from being evaluated — that still holds for the per-item loop body. But `DeleteAllAsync()` is no longer inside that loop at all (R5), so it was never a candidate for per-item retry/continue semantics; letting it fail the whole run (rather than silently continuing with a possibly-uncleared table) is consistent with FR-006's "before evaluating any open sales order" ordering guarantee. The codebase has precedent for both styles (outer-only try/catch with rethrow in `SendAlertAsync`; per-item try/catch-and-continue in `ComplSharepointCompensationService.RevertMappedSourceFilesAsync`) — per-item remains correct for the loop body, outer-only is correct for the one-time delete-all step.

**Alternatives considered**: Matching `SendAlertAsync`'s single outer try/catch with no per-item isolation for the loop body — rejected, contradicts FR-011 directly. Wrapping `DeleteAllAsync()` in its own try/catch-and-continue (i.e., proceeding with the refresh even if the clear failed) — rejected, since inserting a new run's rows on top of an uncleared table would silently reintroduce the exact stale-data problem FR-006 exists to prevent.

## R7. Migration file for `compl_so_missing`

**Decision**: Add `compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Migration/17_create_compl_so_missing.sql`, using `CREATE TABLE IF NOT EXISTS` with column definitions identical to the existing `Sqls/Tables/compl_so_missing.sql`, plus a Vietnamese header comment following the convention set by `16_create_compl_master_hierarchies.sql` (feature id, cross-reference note, and the "apply manually to existing DBs" caveat).

**Rationale**: `Sqls/Tables/*.sql` files (including the already-existing `compl_so_missing.sql`) only run automatically via `DatabaseInitializer.InitTables()` when a brand-new database is being created; environments with a pre-existing database never see that file execute. `Sqls/Migration/*.sql` is this repo's established, purely-manual convention for backfilling schema onto already-existing databases, confirmed by reading `DatabaseInitializer.cs` and the header comment of `16_create_compl_master_hierarchies.sql`. Since `compl_so_missing` already has a `Sqls/Tables/` definition but no corresponding `Sqls/Migration/` file, this feature is the first to actually need the table populated on an existing DB, so the migration file must be added now.

**Alternatives considered**: Skipping the migration file and relying on `Sqls/Tables/compl_so_missing.sql` alone — rejected, would silently no-op on every already-provisioned environment (which is virtually all real deployments of this system).

## R8. Email column layout, and where `Status`/`DaysRemaining` get computed (2026-08-10)

**Decision**: Change only the `complianceList` anonymous projection and `customHeaders` dictionary inside the already-implemented `ComplNotificationService.SendMailAndNotificationForSalesOrderMissing` (`ComplianceSys.Application/Services/ComplNotificationService.cs:767-793`) to the 14-column layout from spec.md FR-012: `SalesId, MasterCode, MasterName, Status, Code, Name, ValidFrom, ValidTo, DaysRemaining, ResponsibleEmails, Description, MappedRefTypeCode, MappedInputValue, MappedRefTypeName`, labeled per FR-012 ("Sales order", "Master code", "Master name", "Status", "Code", "Name", "Valid from", "Valid to", "Days remaining", "Responsible emails", "Description", "Type", "Product", "Product name"). Compute `Status` and `DaysRemaining` per row, inline in that projection, via two small new private static helpers on `ComplNotificationService` (following the existing `SplitEmails`/`BuildEmailTitle` private-helper convention):
```csharp
private static string ComputeSalesOrderMissingStatus(string code, DateTime? validTo)
{
    if (string.IsNullOrWhiteSpace(code)) return "Missing";
    return validTo.HasValue && validTo.Value.Date < DateTime.Today ? "Expired" : "Valid";
}

private static string? FormatDaysRemaining(DateTime? validTo)
{
    if (!validTo.HasValue) return null;
    int n = (validTo.Value.Date - DateTime.Today).Days; // e.g. +10 (10 days left) or -5 (5 days overdue)
    return $"{n} days left";
}
```
`ResponsibleEmails` becomes a fourth per-row derived value: `string.Join("<br/>", (c.RespGroups ?? []).SelectMany(g => g.Emails ?? []).Distinct())`, mirroring the `<br/>`-joined pattern `SendMailAndNotification` already uses for its own `ResponsibleEmails` column (line 415) and `Helper.GenerateHtmlTableValidTo`'s existing `htmlAllowedFields` allow-list (which already includes `"ResponsibleEmails"`, so no renderer change is needed to let the `<br/>` tags through unescaped).

**Rationale**: `compl_so_missing`/`ComplSoMissingResponseDto` has no `DaysRemaining` column at all (data-model.md), and its `Status` column is always the literal `"MISSING"` (FR-005's pre-filter) — neither can be read back as-is and satisfy spec.md FR-013/FR-014, which require values current as of the moment the alert is generated, not as of the last refresh. Computing them inline in the existing projection is the smallest change consistent with Constitution Principle III: it reuses the same renderer (`Helper.GenerateHtmlTableValidTo`), the same header-dictionary-driven column-ordering mechanism already used by every other alert projection in this file (`SendMailAndNotification` at line 419, `SendMailAndNotificationForMaster`), and the same JSON group-parsing already established in R4 — it does not add a new rendering path, a new entity column, or a new repository method.

**Alternatives considered**:
- Adding a computed `DaysRemaining`/richer `Status` column to the `compl_so_missing` table (schema change) and populating it during `RefreshSalesOrderMissingComplianceAsync` — rejected: FR-013/FR-014 require these values to reflect "the moment the alert is generated," which can be later than the refresh (e.g. a slow per-sales-order loop, or if send is ever decoupled from refresh in the future); computing at send time is simpler and always correct, and avoids a schema change for two display-only fields.
- Reusing the SQL `DATEDIFF(...)`/`CONCAT(..., ' days left')` pattern from `compl_sp_get_alert_compliances.sql` (used by the *other*, non-SO alert) by adding an equivalent stored procedure for `compl_so_missing` — rejected: there is no existing `compl_sp_*` procedure for this table (R5 already rejected introducing one for the delete-all step, for the same reason), and the two-line C# computation above is simpler than adding a stored procedure for a per-row projection that already happens in C#.
- Naming the computed field something other than `Status` to avoid colliding with the entity's existing `Status` property — unnecessary: the anonymous projection type used for the HTML table is independent of `ComplSoMissingResponseDto`; assigning `Status = ComputeSalesOrderMissingStatus(c.Code, c.ValidTo)` inside the anonymous object shadows nothing on the underlying DTO/entity, which keeps its own `Status` ("MISSING") unchanged for FR-005/data-model.md purposes.

## R9. Generating the Excel attachment (2026-08-10)

**Decision**: Add a new private helper, `BuildSalesOrderMissingExcelAttachment(List<dynamic> complianceList, Dictionary<string, string> customHeaders)`, to `ComplNotificationService.cs`, using **ClosedXML** (already a `PackageReference` in `ComplianceSys.Application.csproj` — version 0.102.3) to build a brand-new workbook (no template), following the exact pattern already established by `EutrMastersExportService.ExportToExcelAsync` (`EutrMastersExportService.cs:19-51`):
```csharp
using var workbook = new XLWorkbook();
var sheet = workbook.Worksheets.Add("Sales orders missing compliance");
var headers = customHeaders.Values.ToList();
for (int i = 0; i < headers.Count; i++)
{
    sheet.Cell(1, i + 1).Value = headers[i];
}

var propsByKey = complianceList.Count > 0
    ? customHeaders.Keys.ToDictionary(k => k, k => ((object)complianceList[0]).GetType().GetProperty(k))
    : new Dictionary<string, System.Reflection.PropertyInfo?>();

int row = 2;
foreach (var item in complianceList)
{
    int col = 1;
    foreach (var key in customHeaders.Keys)
    {
        var raw = propsByKey[key]?.GetValue(item)?.ToString() ?? string.Empty;
        sheet.Cell(row, col).Value = key == "ResponsibleEmails" ? raw.Replace("<br/>", "\n") : raw;
        col++;
    }
    row++;
}

using var outputStream = new MemoryStream();
workbook.SaveAs(outputStream);
return outputStream.ToArray();
```
The caller passes it the *same* `complianceList`/`customHeaders` already built for the HTML email table in `SendMailAndNotificationForSalesOrderMissing` (research.md R8), so the Excel file's columns, order, and values are derived from one source, not a second hand-maintained mapping. The one deliberate difference: the `ResponsibleEmails` cell's `<br/>` HTML line-break markers (meaningful in an email body) are replaced with a literal `\n` for a spreadsheet cell — same underlying multi-email data, just re-rendered for the target medium, not re-derived from a different source.

**Rationale**: ClosedXML is already the established, repo-wide choice for from-scratch Excel export (`EutrMastersExportService`, `ComplMasterTemplateExportService`, `EutrTemplatesExportService`, etc.) — introducing a second Excel library (EPPlus, NPOI, OpenXML SDK) for one more export would violate Constitution Principle III (reuse existing backend) for no benefit. Reading columns via `customHeaders.Keys`/reflection (the same technique `Helper.GenerateHtmlTableValidTo` already uses internally, R8) guarantees FR-015 ("same columns... as the email body") by construction — the Excel export cannot drift out of sync with the email table because it reads the identical projection and header dictionary, not a duplicated list of property names.

**Alternatives considered**:
- A separate, purpose-built `ComplSoMissingResponseDto`-typed export method (iterating the DTO's own properties directly rather than the anonymous `complianceList`) — rejected: it would require the Status/DaysRemaining/ResponsibleEmails computations (research.md R8) to be duplicated a second time (once for the email projection, once for the Excel export), directly risking the two outputs disagreeing — exactly what FR-015 requires not to happen.
- Keeping the `<br/>` markers verbatim in the Excel cell — rejected: they would render as literal text (`user1@x.com<br/>user2@x.com`) in a spreadsheet, which is not "the same data" in any user-meaningful sense; replacing with `\n` (optionally with `sheet.Cell(...).Style.Alignment.WrapText = true` for readability) preserves the same list of emails in a spreadsheet-appropriate form.
- Using EPPlus or the OpenXML SDK directly — rejected: no existing usage anywhere in this repo (confirmed by search), so either would be a brand-new dependency where ClosedXML already satisfies the need and is already proven in this exact "no-template export" shape.

## R10. Attaching the generated workbook and naming the file (2026-08-10)

**Decision**: In `SendMailAndNotificationForSalesOrderMissing`, after building `complianceList`/`customHeaders` (research.md R8) and before the existing `Mail.SendAttachment`-gated per-row SharePoint attachment loop (`ComplNotificationService.cs:884-908`), unconditionally add one attachment:
```csharp
var excelBytes = BuildSalesOrderMissingExcelAttachment(complianceList, customHeaders);
attachments.Add(new AttachmentInfo
{
    Type = AttachmentType.Stream,
    FileStream = new MemoryStream(excelBytes),
    FileName = $"compl-sales-order-missing-{DateTime.Now:yyyyMMddHHmmss}.xlsx"
});
```
This reuses the exact `AttachmentInfo`/`AttachmentType.Stream` shape and `mailAlert.SendMailV2(...)` consumption already exercised by the per-row SharePoint attachments in the same method (and in `SendMailAndNotification`), and the same post-send `attachments.Where(a => a.FileStream != null)` disposal loop already present (`ComplNotificationService.cs:913-916`) already disposes this new stream too — no new disposal logic needed.

**Rationale**: `AttachmentInfo.Type = AttachmentType.Stream` reads only `FileStream`/`FileName` (confirmed against `MailAlert.SendMailV2`'s implementation), which is exactly what an in-memory-generated (not downloaded) file needs — no `FilePath` variant, no temp file on disk. Placing this unconditionally (not behind the `Mail.SendAttachment` config flag) matches spec.md FR-015 ("whenever the alert email is sent... MUST attach"), which is unconditional, unlike the existing per-row SharePoint attachment feature that is explicitly config-gated for a different reason (large per-document files, opt-in). `DateTime.Now` (local server time) is used for the file-name timestamp, matching this file's existing convention of using local-time comparisons for user-facing values (`DateTime.Today` in `ComputeSalesOrderMissingStatus`/`FormatDaysRemaining`, R8) rather than `DateTime.UtcNow`.

**Alternatives considered**:
- Gating the new Excel attachment behind the same `Mail.SendAttachment` config flag as the per-row SharePoint attachments — rejected: spec.md FR-015 states the attachment happens "whenever the alert email is sent," with no mention of a toggle; conflating it with the existing flag would make the two attachment behaviors (existing per-document downloads vs. this new always-on summary) toggle together for no reason the spec gives.
- Writing the workbook to a temp file on disk and using `AttachmentType.FilePath` — rejected: adds filesystem cleanup responsibility (temp file deletion, path collisions under concurrent runs) for no benefit over an in-memory `MemoryStream`, which `SendMailV2`'s `Stream` branch already supports directly.

## R11. Deduplicating alert rows and dropping the Sales order column (2026-08-18)

**Decision**: In `SendSalesOrderAlertAsync` (`ComplNotificationService.cs:176-206`), insert `.DistinctBy(r => new { r.MasterCode, r.Code, r.MappedRefTypeCode, r.MappedInputValue })` on the `IEnumerable<ComplSoMissing>` returned by `_complSoMissingRepository.GetAllAsync()`, before the existing `.Select(r => new ComplSoMissingResponseDto { ... })` projection:
```csharp
var alertCompliances = (await _complSoMissingRepository.GetAllAsync())?
    .DistinctBy(r => new { r.MasterCode, r.Code, r.MappedRefTypeCode, r.MappedInputValue })
    .Select(r => new ComplSoMissingResponseDto { /* unchanged, still includes SalesId */ })
    .ToList() ?? [];
```
Separately, in `SendMailAndNotificationForSalesOrderMissing`'s `complianceList` projection (research.md R8) and `customHeaders` dictionary, remove the `SalesId`/`"Sales order"` entry, leaving the 13-column layout from spec.md FR-012.

**Rationale**: `Enumerable.DistinctBy` (BCL, .NET 6+) is a one-line, first-occurrence-wins dedup with no new dependency — the simplest way to satisfy spec.md FR-008 ("deduplicated by the combination of Master code, Code, Type, and Product"). Applying it once, at the single read-back call site that already exists (`SendSalesOrderAlertAsync`), means the same deduplicated set automatically flows into everything `SendMailAndNotificationForSalesOrderMissing` already builds from its `compliances` parameter — the HTML email table, the Excel attachment (both via `complianceList`), and the per-record `ComplNotification` rows (via the `compliances` enumerable itself) — with no separate dedup logic needed for each. Dropping `SalesId`/`"Sales order"` from `complianceList`/`customHeaders` only (not from `ComplSoMissingResponseDto` itself) satisfies FR-012's "Sales order column MUST NOT be included" for the email/Excel content specifically, while leaving `compliance.SalesId` available, unchanged, for the per-recipient notification message text a few lines later in the same method (`$"Sales order {compliance.SalesId} is missing this compliance..."`) — the user's request scoped the column removal to "nội dung email và nội dung file đính kèm" (email content and attachment content), not the in-app notification text.

**Alternatives considered**:
- Changing `ComplSoMissingRepository.GetAllAsync()`'s SQL to `SELECT DISTINCT ...` — rejected: plain SQL `DISTINCT` only collapses rows that are identical across *every* selected column, and this table's other columns (e.g. `SalesId`, `Description`, `AlertGroupsJson`) are expected to still vary per underlying sales order even when the four dedup-key columns match; a `GROUP BY` with per-column aggregate picks would be needed instead, which is more SQL complexity for the same one-line LINQ result, and would also require deciding a tie-break rule in SQL rather than in the already-reviewed C# service code.
- Deduplicating inside `SendMailAndNotificationForSalesOrderMissing` (on `compliances`) instead of at the `SendSalesOrderAlertAsync` read-back call site — rejected: `SendMailAndNotificationForSalesOrderMissing` is also usable in principle as a general-purpose sender for any `IEnumerable<ComplSoMissingResponseDto>`; keeping the dedup at the one call site that reads from `compl_so_missing` (FR-008's "read back... deduplicated") keeps the method itself a pure "given rows, send an alert" helper, matching its existing shape.
- Removing `SalesId` from `ComplSoMissingResponseDto`/the entity entirely — rejected: `compl_so_missing` still stores and is keyed on `SalesId` per FR-006/FR-007 (unchanged), and the per-recipient notification message still displays it; only the alert's displayed columns (email/Excel) drop it.
