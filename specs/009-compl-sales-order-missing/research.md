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
