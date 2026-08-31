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

## R12. Highlighting Expired rows yellow in the Excel attachment (2026-08-20)

**Decision**: In `BuildSalesOrderMissingExcelAttachment` (`ComplNotificationService.cs:427-464`, research.md R9), after writing a data row's cell values, check that row's already-computed `Status` value (the same `Status` property already present on each `complianceList` item per R8, computed via `ComputeSalesOrderMissingStatus`) and, when it equals `"Expired"`, apply a yellow fill to the whole row's cell range — matching the email body's existing yellow highlight from `Helper.GenerateHtmlTableValidTo` (`Helper.cs:244`, `background-color: #fff59d`):
```csharp
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

    var status = propsByKey.TryGetValue("Status", out var statusProp) ? statusProp?.GetValue(item)?.ToString() : null;
    if (status == "Expired")
    {
        sheet.Range(row, 1, row, customHeaders.Count).Style.Fill.BackgroundColor = XLColor.FromHtml("#fff59d");
    }

    row++;
}
```
`XLColor.FromHtml("#fff59d")` reuses the exact same hex value already hardcoded in `Helper.cs:244` for the email row, so the two representations always show the identical shade of yellow, not merely a visually-similar one.

**Rationale**: Reading `Status` off the already-materialized `complianceList` item (rather than re-deriving it from `Code`/`ValidTo` a second time) reuses the single computation already performed once per row for the email projection (research.md R8), so the Excel highlight can never disagree with the email highlight or with the displayed `Status` cell value in the same row — all three read from the same computed value. Applying `Style.Fill.BackgroundColor` to a `sheet.Range(row, 1, row, columnCount)` follows the exact ClosedXML row-highlight pattern already established elsewhere in this codebase (`ComplComplianceImportService.cs:951-954`, `errorRowRange.Style.Fill.BackgroundColor = XLColor.Red`), so no new highlighting technique is introduced — only a different color and a different trigger condition (`Status == "Expired"` instead of "import error").

**Alternatives considered**:
- Re-deriving expiry from `ValidTo < DateTime.Today` directly inside the Excel helper (mirroring `Helper.cs:244`'s own condition, rather than reading the already-computed `Status` cell) — rejected: `BuildSalesOrderMissingExcelAttachment` receives `List<dynamic>`/reflection-driven column access already keyed by `customHeaders`, so reading the existing `Status` value via the same `propsByKey` lookup already used for every other column is simpler and guarantees the highlight and the `Status` text cell can never drift apart (e.g. if `ComputeSalesOrderMissingStatus`'s rule ever changes in `ComplNotificationService.cs:399-407`, the Excel highlight picks up the change automatically since it reads the same computed value, not a re-implemented copy of the rule).
- Extracting `#fff59d` into a shared named constant used by both `Helper.cs:244` and the new Excel helper — considered, but out of scope: `Helper.cs:244`'s color is not currently a named constant (it is inline in that file), and introducing one there is a larger refactor than this update's minimal-diff scope requires; the new Excel code instead duplicates the same literal hex value as a comment-documented match, which keeps the diff small while still guaranteeing the two colors are visually identical today.
- Highlighting only the `Status` cell instead of the whole row — rejected: the email body's existing highlight (`Helper.cs:244`) colors the entire `<tr>`, not a single `<td>`; matching that whole-row treatment in Excel keeps the two representations visually consistent, per spec.md's explicit "same yellow background color used for Expired rows in the email body" requirement (FR-018).

## R13. Re-adding a combined Sales order column (2026-08-20)

**Decision**: In `SendSalesOrderAlertAsync` (`ComplNotificationService.cs:173-224`), change the read-back step's `.DistinctBy(...)` to `.GroupBy(r => new { r.MasterCode, r.Code, r.MappedRefTypeCode, r.MappedInputValue })`, and for each group build one `ComplSoMissingResponseDto` from the group's first item (unchanged field-by-field mapping, `SalesId = first.SalesId` as before) plus one new property, `CombinedSalesIds`, set to `string.Join(", ", group.Select(x => x.SalesId).Where(s => !string.IsNullOrWhiteSpace(s)).Distinct())`:
```csharp
var alertCompliances = (await _complSoMissingRepository.GetAllAsync())?
    .GroupBy(r => new { r.MasterCode, r.Code, r.MappedRefTypeCode, r.MappedInputValue })
    .Select(g =>
    {
        var first = g.First();
        return new ComplSoMissingResponseDto
        {
            /* ... unchanged field-by-field mapping from `first`, exactly as today ... */
            SalesId = first.SalesId,
            CombinedSalesIds = string.Join(", ", g.Select(x => x.SalesId).Where(s => !string.IsNullOrWhiteSpace(s)).Distinct())
        };
    }).ToList() ?? [];
```
Add `public string? CombinedSalesIds { get; set; }` to `ComplSoMissingResponseDto` (`Dtos/Response/ComplSoMissingResponseDto.cs`) as a new plain settable property (not JSON-parsed like `AlertGroups`/`RespGroups`). In `SendMailAndNotificationForSalesOrderMissing`'s `complianceList` projection and `customHeaders` dictionary (research.md R8/R11), add `SalesOrder = c.CombinedSalesIds` and `{ "SalesOrder", "Sales order" }` as the **last** entries, so `Helper.GenerateHtmlTableValidTo` and `BuildSalesOrderMissingExcelAttachment` (both driven by `customHeaders.Keys` iteration order, per R8/R9) render it as the final column in both the email table and the Excel attachment.

**Rationale**: `GroupBy` is a minimal, one-line change from the existing `DistinctBy` (same key selector, same LINQ family) — it keeps every member of a duplicate-key group available (`DistinctBy` discards all but the first), which FR-008/FR-019 now require to build the combined Sales order value. Keeping `SalesId` itself unchanged (still `first.SalesId`, a single value) preserves the per-recipient in-app notification message text later in the same method (`$"Sales order {compliance.SalesId} is missing this compliance..."`, `ComplNotificationService.cs:999/1003`) exactly as it behaves today — the user's request scoped this update to "bảng nội dung email và file excel" (the email table and the Excel file), not the notification text, matching the same scoping precedent already established by the 2026-08-18 update's Assumptions. Adding a new `CombinedSalesIds` property (rather than repurposing `SalesId` for the combined value) avoids any ambiguity about which meaning `SalesId` carries elsewhere in the DTO/entity family (`ComplSoMissing.SalesId` remains a single stored sales order code, per data-model.md, unaffected by this change). Placing the new column last in both `complianceList` and `customHeaders` satisfies FR-012's "Sales order MUST be the last column" by construction, since both renderers iterate `customHeaders.Keys`/`.Values` in dictionary insertion order (an established, already-relied-upon behavior — see R8/R9).

**Alternatives considered**:
- Keeping `.DistinctBy(...)` and issuing a second, separate query/grouping over the same `GetAllAsync()` result just to compute the combined Sales order list — rejected: doing both in one `GroupBy` pass avoids reading/iterating the repository result twice for what is fundamentally the same grouping operation.
- Overwriting `ComplSoMissingResponseDto.SalesId` with the combined string instead of adding a new property — rejected: `SalesId` is a single sales order's code by definition on the base `ComplSoMissing` entity/DTO family (data-model.md), and the per-recipient notification message (`ComplNotificationService.cs:999/1003`) already reads it as a single value; overloading its meaning would silently change that message's text for any group with more than one contributing sales order, which is out of scope for this update per the user's request.
- Computing `CombinedSalesIds` as a `List<string>` property instead of a pre-joined `string` — rejected: every other display-only computed value on this DTO/projection path (`Status`, `DaysRemaining`, `ResponsibleEmails`) is already a pre-formatted string ready for direct cell/HTML-table insertion (R8); keeping `CombinedSalesIds` consistent with that shape avoids a special case in the `complianceList` projection or the Excel/HTML renderers, both of which already expect string-typed cell values via reflection (R9).

## R14. Check-date sentinel fallback for open sales orders with no delivery date (2026-08-21)

**Decision**: Fix `ViewCompliancesRepository.GetViewCompliancesAsync(IEnumerable<ViewCompliancesRequest> request, DateTime? deliveryDate, CancellationToken ct)` (`compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/ViewCompliancesRepository.cs:23-46`) — the single shared method both the compliance screen's `get-all` endpoint and `RefreshSalesOrderMissingComplianceAsync` (`ComplNotificationService.cs:271-328`, call at line 303) already call — by adding, at its top, the exact same sentinel guard its sibling method `GetCountForViewCompliancesAsync` already has (`ViewCompliancesRepository.cs:74-77`):
```csharp
public async Task<IEnumerable<ViewCompliancesResponseDto>> GetViewCompliancesAsync(IEnumerable<ViewCompliancesRequest> request, DateTime? deliveryDate, CancellationToken ct = default)
{
    if (!deliveryDate.HasValue || deliveryDate.Value.Date == new DateTime(1900, 1, 1))
    {
        deliveryDate = DateTime.UtcNow;
    }

    // ... unchanged: serialize request, call sp_load_compl_by_conditions with p_check_date = deliveryDate ...
}
```
No change is made to `ComplNotificationService.cs`, `ViewCompliancesService.cs`, `ViewCompliancesController.cs`, or the stored procedure itself — `so.DeliveryDate` is still passed through unchanged at the `RefreshSalesOrderMissingComplianceAsync` call site; the sanitization now happens once, at the shared repository entry point both callers already funnel through.

**Rationale**: Investigation (see spec.md's 2026-08-21 Input update) traced the SO006831/MAS-01021/MAS-01081 discrepancy to `RefreshSalesOrderMissingComplianceAsync` passing `so.DeliveryDate` — the raw `RSVNSalesOrderOpenInvoiceCogs.DeliveryDate` field, which is `1900-01-01` (the source ERP's "no delivery date recorded" sentinel) for an open sales order that has not yet been scheduled — straight into `GetViewCompliancesAsync`, which only substitutes `CURDATE()` for a true SQL `NULL` inside `sp_load_compl_by_conditions` (`sp_load_compl_by_conditions.sql:6`), not for the `1900-01-01` sentinel. The compliance screen never hits this because its frontend already sanitizes the date it sends (falling back to `dayjs()`/today whenever the source date is `1900-01-01`, e.g. `useAllCompliancesColumnsSaleOrder.jsx:51`), so the two callers silently disagreed only when a caller skipped that sanitization — which the background service did. `GetCountForViewCompliancesAsync` already carries the identical guard, proving this exact sentinel is a known, already-solved problem in this codebase (Constitution Principle III: reuse existing backend, verified-gap fix, same shape as R2's `EntityMappings[18]` fix); moving/copying that guard into `GetViewCompliancesAsync` closes the gap for both of its callers (the screen and this feature) at once, in the one place they both already share, rather than adding a second, duplicated sanitization step inside `ComplNotificationService` that could drift out of sync with the repository's existing rule over time.

**Alternatives considered**:
- Sanitizing `so.DeliveryDate` inside `RefreshSalesOrderMissingComplianceAsync` itself (e.g. a local `so.DeliveryDate is null or == 1900-01-01 ? DateTime.Today : so.DeliveryDate` check before the `GetViewCompliancesAsync` call) — rejected: this would fix only this feature's call site, leaving `GetViewCompliancesAsync`'s other direct caller (`ViewCompliancesService` → the screen's `get-all` endpoint) still relying entirely on frontend-side sanitization to avoid the same bug; it also duplicates the sentinel-check literal (`new DateTime(1900, 1, 1)`) a third time in the codebase instead of reusing the one that already exists one layer down.
- Adding the guard to `ViewCompliancesService.GetViewCompliancesAsync` (the Application-layer service both the controller and `ComplNotificationService` call) instead of the Infrastructure-layer repository — considered, but rejected in favor of the repository: `GetCountForViewCompliancesAsync`'s existing precedent for this exact guard already lives at the repository layer, immediately next to the `p_check_date` parameter it protects, and `ViewCompliancesRepository.GetViewCompliancesForOneObjectAsync` (a third method sharing the same `checkDate`-to-stored-procedure pattern) is left unguarded for now since no caller of it has been reported to hit this bug — matching this fix's minimal, verified-gap scope rather than speculatively hardening every date-taking method in the file.
- Changing the frontend to always sanitize before calling `get-all` (making the backend never receive `1900-01-01`) — rejected: the backend's own background job (`RefreshSalesOrderMissingComplianceAsync`) is not a frontend call at all, so a frontend-only fix cannot close this gap for this feature regardless.

## R15. Styling the Excel attachment's header row to match the email's header row (2026-08-21)

**Decision**: In `BuildSalesOrderMissingExcelAttachment` (`ComplNotificationService.cs:467-511`, research.md R9), immediately after the existing header-writing loop (lines 472-476), style the whole header range to match the email's header:
```csharp
var headers = customHeaders.Values.ToList();
for (int col = 0; col < headers.Count; col++)
{
    sheet.Cell(1, col + 1).Value = headers[col];
}

var headerRange = sheet.Range(1, 1, 1, headers.Count);
headerRange.Style.Fill.BackgroundColor = XLColor.FromHtml("#C18C75");
headerRange.Style.Font.Bold = true;
headerRange.Style.Border.OutsideBorder = XLBorderStyleValues.Thin;
headerRange.Style.Border.InsideBorder = XLBorderStyleValues.Thin;
```
This mirrors the email header's existing appearance, produced by `Helper.GenerateHtmlTableValidTo` (`Helper.cs:131-265`): the CSS block `th { background-color: #C18C75; ... }` (`Helper.cs:161-166`, `#C18C75` passed in as `backgroundColorHeader` from the `SendMailAndNotificationForSalesOrderMissing` call site, `ComplNotificationService.cs:934`), the browser-default bold rendering of `<th>` (no explicit `font-weight` is set anywhere — R15 makes this explicit in Excel via `Style.Font.Bold = true`, since ClosedXML cells are not bold by default the way a `<th>` renders in a browser), and the shared `td, th { border: 1px solid #dddddd; }` rule (`Helper.cs:156-160`) applied to every cell including headers.

**Rationale**: `XLColor.FromHtml("#C18C75")` reuses the exact same hex value already passed into `Helper.GenerateHtmlTableValidTo` for this feature's email (`ComplNotificationService.cs:934`), the same way R12 reused `#fff59d` for the Expired-row highlight — so the header color can never drift from the email's, short of both being changed together at their respective call sites. Applying the fill/font/border via `sheet.Range(1, 1, 1, headers.Count).Style...` follows the exact row-range styling technique R12 already established in this same method for the Expired-row highlight (`sheet.Range(row, 1, row, headers.Count).Style.Fill.BackgroundColor`), just anchored to row 1 instead of a data row — no new ClosedXML API surface is introduced. `XLBorderStyleValues.Thin` is ClosedXML's standard thin-line border, the closest built-in equivalent to the email's `1px solid #dddddd`; ClosedXML does not expose arbitrary hex border colors on `OutsideBorder`/`InsideBorder` the same way `Style.Fill.BackgroundColor` accepts `XLColor.FromHtml(...)`, so the border match is "thin ruled lines" (visually equivalent) rather than a pixel-identical `#dddddd` shade — consistent with spec.md's Assumption that "visually match" means color/weight/border equivalence, not byte-identical styling metadata.

**Alternatives considered**:
- Styling each header cell individually in the existing `for` loop (`sheet.Cell(1, col + 1).Style...` per iteration) instead of one `sheet.Range(...)` call after the loop — rejected: a single range-level style call is fewer statements, matches how R12 already treats a header/data row as one styled unit rather than per-cell, and ClosedXML applies range styles to every cell in the range identically either way.
- Extracting `"#C18C75"` into a shared constant referenced by both `Helper.cs:934`'s call site and the new Excel styling call — considered, but out of scope for the same reason R12 already gave for `#fff59d`: the color is not currently a named constant anywhere in the codebase, and introducing one is a larger refactor than this minimal-diff update requires.
- Leaving the header unstyled and only adding a bold font (skipping the background fill and border) — rejected: the user's report (spec.md's 2026-08-21 Input update, with side-by-side screenshots) explicitly shows the Excel header lacking the shaded background the email header has, not just the bold weight, so the fix must cover fill, font weight, and border to actually resolve the reported mismatch.

## R16. A second diagnostic trigger whose alert omits the Sales order column entirely (2026-08-31)

**Decision**: Add a new manually-triggerable entry point, `GET /api/notification/test-sales-order-alert-without-salesId` → `IComplNotificationService.SendSalesOrderAlertWithoutSalesIdAsync()`, that performs the exact same refresh (`RefreshSalesOrderMissingComplianceAsync`, unchanged) and the exact same read-back/group-by-dedup step (research.md R11/R13) as `SendSalesOrderAlertAsync`, then calls the already-existing `SendMailAndNotificationForSalesOrderMissing` with one new trailing optional parameter, `includeSalesOrderColumn: false`:
```csharp
public async Task SendSalesOrderAlertWithoutSalesIdAsync()
{
    try
    {
        var alertCompliances = await BuildCurrentSalesOrderAlertComplianceListAsync();
        if (!alertCompliances.Any())
        {
            NotifyJobSuccess("sent_alert_sales_order", "SendSalesOrderAlertWithoutSalesIdAsync", hadContent: false, "No sales order missing compliances found for alert");
            return;
        }

        await SendMailAndNotificationForSalesOrderMissing(alertCompliances, null, SendAlertType.AutoSendAlert, includeSalesOrderColumn: false);
        NotifyJobSuccess("sent_alert_sales_order", "SendSalesOrderAlertWithoutSalesIdAsync", hadContent: true, $"{alertCompliances.Count} sales-order missing compliance(s) alerted");
    }
    catch (Exception ex)
    {
        Log.Error(ex, "Error in SendSalesOrderAlertWithoutSalesIdAsync");
        throw;
    }
}
```
The read-back/dedup block already inside `SendSalesOrderAlertAsync` (`ComplNotificationService.cs:208-246`, the `RefreshSalesOrderMissingComplianceAsync()` call plus the `GetAllAsync()` → `GroupBy` → `Select` → `alertCompliances` chain) is extracted, unchanged line-for-line, into a new private helper `BuildCurrentSalesOrderAlertComplianceListAsync()` returning `Task<List<ComplSoMissingResponseDto>>`, called by both `SendSalesOrderAlertAsync` and the new method — so the two triggers can never disagree on which records are current or how they are grouped.

Inside `SendMailAndNotificationForSalesOrderMissing` (`ComplNotificationService.cs:901-903`), add one new optional parameter, `bool includeSalesOrderColumn = true` (default preserves today's behavior for the existing trigger and any other caller), and make the single `customHeaders` entry that adds the Sales order column conditional on it:
```csharp
var customHeaders = new Dictionary<string, string>
{
    { "MasterCode", "Master code" },
    // ... the other 11 entries, unchanged ...
    { "MappedRefTypeName", "Product name" },
};
if (includeSalesOrderColumn)
{
    customHeaders.Add("SalesOrder", "Sales order");
}
```
**Correction (2026-08-31, verified against a live send)**: The initial version of this decision assumed the `complianceList` anonymous projection could keep `SalesOrder = c.CombinedSalesIds` unconditionally and that omitting the `customHeaders` entry alone would be enough to drop the column from both representations. A live test proved this wrong for the email body: `BuildSalesOrderMissingExcelAttachment` (research.md R9/R11) does only iterate `customHeaders.Keys`, so the Excel attachment correctly dropped the column — but `Helper.GenerateHtmlTableValidTo` (research.md R8, `Helper.cs:184-198`) does not purely filter by `customHeaders`: after building the ordered column list from `customHeaders.Keys`, it appends **every remaining property of the item that wasn't already added** (`foreach (var p in allProps) { if (!properties.Contains(p)) properties.Add(p); }`), rendering it with its raw C# property name as the header (`headerTitle = prop.Name` when `customHeaders` has no matching key). Since `SalesOrder` still existed as a property on the anonymous type, it reappeared in the email table as a column literally titled "SalesOrder" — visible in a live send even though the Excel attachment and the email title were both already correct.

**Corrected decision**: `Helper.GenerateHtmlTableValidTo` is a shared helper also called by three unrelated flows in the same file (`ComplNotificationService.cs:605,610,862` — `SendMailAndNotification`/`SendMailAndNotificationForMaster`), so its leftover-property-append behavior is left untouched (Constitution Principle III — do not modify shared logic other flows may depend on). Instead, `complianceList` itself is built via two separate anonymous-type projections gated on `includeSalesOrderColumn`: the `true` branch (unchanged, includes `SalesOrder = c.CombinedSalesIds` as before) and a new `false` branch with the identical 13 fields but no `SalesOrder` property at all, so there is no leftover property for `GenerateHtmlTableValidTo` to append. The `customHeaders` entry is still conditionally added (research.md R13's mechanism), which still governs `BuildSalesOrderMissingExcelAttachment`'s column set and would also govern `GenerateHtmlTableValidTo`'s labeling of the column if the property existed — but the property's own absence is now what makes the column disappear from the email body, not the dictionary entry alone.

**Rationale**: `BuildSalesOrderMissingExcelAttachment` (research.md R9/R11) already derives its entire column set — which properties to read, in what order, under what header text — purely from `customHeaders.Keys`/`.Values` via reflection; it never assumes a fixed/hardcoded column list, so omitting one dictionary entry is sufficient, on its own, to drop that column from the Excel attachment (FR-024) — no change needed there. For the email body, since `Helper.GenerateHtmlTableValidTo` cannot be changed without risking the three other alert flows that share it, the fix has to happen one layer up, at the shape of the object being rendered — which is exactly what the two-branch projection does, with no change to `ComplSoMissingResponseDto`, `ComplSoMissing`, the repository, `RefreshSalesOrderMissingComplianceAsync`, or the Excel file-naming pattern (FR-016, unaffected). Extracting the read-back/dedup block into a shared helper avoids duplicating ~35 lines of `GroupBy`/projection logic that must stay identical between the two triggers per spec.md User Story 3 Acceptance Scenario 1 (FR-023's "identical refresh-and-notify process") — that part of the original decision still holds; only the `complianceList` projection needed correcting.

**Alternatives considered**:
- Duplicating `SendSalesOrderAlertAsync`'s full body into a second method instead of extracting a shared helper — rejected: the two methods would then need to be kept in sync by hand every time the read-back/dedup logic changes (as it already has three times: R11, R13, and any future update), risking silent divergence; extracting a helper makes that impossible by construction.
- Building a second, separate overload of the entire `SendMailAndNotificationForSalesOrderMissing` method (full recipient resolution, Excel generation, notification persistence duplicated) just to get a `complianceList` without `SalesOrder` — rejected: only the ~13-line anonymous projection needs two shapes (see Corrected decision above); duplicating the whole method for that would far exceed the actual scope of the difference.
- Reusing the existing `sendAlerType` parameter (e.g. introducing a new `SendAlertType` enum value meaning "without Sales order") to signal the column omission — rejected: `sendAlerType` is a cross-cutting concept already used elsewhere (`ManualSendAlertAsync`, `SendMailAndNotificationForMaster`, etc.) to distinguish manual vs. automatic recipient-resolution rules; overloading it to also control a column-layout detail specific to this one alert type would conflate two unrelated concerns and affect call sites that have nothing to do with this feature.
- Making `includeSalesOrderColumn` apply to the Excel file name as well (e.g. a different suffix) — rejected: spec.md's Assumptions state the Excel naming pattern (FR-016) is unaffected by this update; only the column set changes.

**Addendum (2026-08-31, without-Sales-order alert title, FR-025)**: Since the diagnostic trigger's alert no longer carries any sales order information, its title must not reuse the existing "Sales orders with missing compliance" wording. Inside `SendMailAndNotificationForSalesOrderMissing`, immediately before the two existing call sites that hardcode that title string (`Helper.GenerateHtmlTableValidTo(...)`'s second argument and `BuildEmailTitle(...)`'s argument), a local `string alertTitle = includeSalesOrderColumn ? "Sales orders with missing compliance" : "Missing compliance Information";` is computed and passed to both call sites instead of the literal string. This reuses the same `includeSalesOrderColumn` parameter R16 already introduced — no new parameter, no new method — and keeps the title and the column-omission decision from ever disagreeing (a caller cannot get one without the other). The Excel worksheet's own internal tab name (`workbook.Worksheets.Add("Sales orders missing compliance")` inside `BuildSalesOrderMissingExcelAttachment`) is out of scope for this addendum — the user's request named only "tiêu đề email" (the email title), not the workbook's internal sheet name, which is not user-visible the way the email subject/heading is.
