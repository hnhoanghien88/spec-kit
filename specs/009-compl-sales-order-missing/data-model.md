# Phase 1 Data Model: Sales Order Missing-Compliance Alert

## Entity: `ComplSoMissing` (new Domain entity, table `compl_so_missing`)

Persists one row per (Sales Order, missing Compliance item) as of the last refresh. No primary key exists on the table (per the existing DDL in `Sqls/Tables/compl_so_missing.sql`); "current run only" is enforced procedurally by a single delete-all step run once before the evaluation loop begins (R5 in research.md, updated 2026-08-04), not by a database constraint and not by a per-sales-order-code delete.

| Column | Type (C#) | Type (MySQL) | Source (per FR-007 / spec) | Notes |
|---|---|---|---|---|
| `SalesId` | `string` | `varchar(45)` | `SalesOrder.Code` | The owning open sales order's code. No longer a delete key (2026-08-04): the store is cleared as a whole before the run, not filtered by `SalesId` (FR-006). |
| `MasterId` | `long` | `bigint NOT NULL` | `ViewCompliancesResponseDto.MasterId` | Compliance master identifier. |
| `MasterCode` | `string?` | `varchar(50)` | `ViewCompliancesResponseDto.MasterCode` | |
| `MasterName` | `string?` | `varchar(255)` | `ViewCompliancesResponseDto.MasterName` | |
| `MasterValidFrom` | `DateTime?` | `datetime` | *(not present on `ViewCompliancesResponseDto`; left null unless a future lookup enrichment supplies it)* | See Assumptions below. |
| `MasterValidTo` | `DateTime?` | `datetime` | *(same as above)* | |
| `MasterNumDayAlert` | `int?` | `int` | *(same as above)* | |
| `MasterDescription` | `string?` | `varchar(500)` | `ViewCompliancesResponseDto.MasterDescription` | |
| `MasterVersionNo` | `int?` | `int` | `ViewCompliancesResponseDto.MasterVersionNo` | |
| `Status` | `string` | `varchar(7) NOT NULL` | `ViewCompliancesResponseDto.Status` | Always `"MISSING"` for rows this feature writes (FR-005 pre-filter). |
| `Id` | `long` | `bigint NOT NULL` | `ViewCompliancesResponseDto.Id` | Compliance document id (may be `0`/expired-doc id per existing MISSING semantics). |
| `Code` | `string` | `varchar(100) NOT NULL` | `ViewCompliancesResponseDto.Code` | |
| `Name` | `string` | `varchar(511) NOT NULL` | `ViewCompliancesResponseDto.Name` | |
| `FileId` | `string` | `varchar(255) NOT NULL` | `ViewCompliancesResponseDto.FileId` | |
| `ValidFrom` | `DateTime?` | `datetime` | `ViewCompliancesResponseDto.ValidFrom` | |
| `ValidTo` | `DateTime?` | `datetime` | `ViewCompliancesResponseDto.ValidTo` | |
| `NumDayAlert` | `int?` | `int` | `ViewCompliancesResponseDto.NumDayAlert` | |
| `VersionNo` | `int?` | `int` | `ViewCompliancesResponseDto.VersionNo` | |
| `ReplacedById` | `long?` | `bigint` | `ViewCompliancesResponseDto.ReplacedById` | |
| `Description` | `string` | `longtext NOT NULL` | `ViewCompliancesResponseDto.Description` | |
| `AlertGroupsJson` | `string?` | `json` | `ViewCompliancesResponseDto.AlertGroupsJson` | Raw JSON copy-through; parsed on read for mail recipients (R4). |
| `ResponsibleGroupsJson` | `string?` | `json` | `ViewCompliancesResponseDto.ResponsibleGroupsJson` | Same as above. |
| `ConditionsJson` | `string?` | `json` | `ViewCompliancesResponseDto.ConditionsJson` | Carried over unchanged. |
| `MappedRefTypeId` | `long?` | `bigint unsigned` | `ViewCompliancesResponseDto.MappedRefTypeId` | |
| `MappedRefTypeCode` | `string?` | `varchar(150)` | `ViewCompliancesResponseDto.MappedRefTypeCode` | |
| `MappedRefTypeName` | `string?` | `varchar(300)` | `ViewCompliancesResponseDto.MappedRefTypeName` | |
| `MappedInputValue` | `string?` | `varchar(255)` | `ViewCompliancesResponseDto.MappedInputValue` | |

**Validation rules** (enforced in the service before insert, not via `IValidator<T>`/`BaseService`, since this entity is written via raw repository calls, not the CRUD base service — consistent with R5):
- `SalesId` MUST be non-empty (the owning sales order's code) — rows are never inserted without it.
- Only rows where `Status == "MISSING"` (per FR-005) are ever passed to `InsertManyAsync`.

**Lifecycle (revised 2026-08-04)**: All existing rows in `compl_so_missing` are deleted exactly once, at the start of a run, before any sales order is evaluated (FR-006) — not per `SalesId`. Each subsequently-evaluated sales order then inserts only its own current MISSING rows. A sales order that is evaluated and currently has zero MISSING items simply contributes no rows for that run (nothing to insert) — combined with the initial clear, this is what "the store reflects only the current run" means in FR-003/Edge Cases. If the same sales order code appears more than once in the open-sales-order list for a run, each occurrence inserts independently (see research.md R5); this is expected, not deduplicated.

## Application DTO: `ComplSoMissingResponseDto` (new, Application/Dtos/Response)

Mirrors the entity 1:1 for the read-back-and-mail step, adding the same parsed-JSON convenience properties already used by `ViewCompliancesResponseDto`/`ComplMasterResponse`:

```csharp
public class ComplSoMissingResponseDto : ComplSoMissing   // or a standalone class mirroring the same fields — decided at /speckit-tasks time
{
    [JsonIgnore] // already on base if entity carries it; otherwise re-declared here
    public List<GroupEmailsDto>? AlertGroups => string.IsNullOrWhiteSpace(AlertGroupsJson)
        ? new List<GroupEmailsDto>() : JsonConvert.DeserializeObject<List<GroupEmailsDto>>(AlertGroupsJson);

    public List<GroupEmailsDto>? RespGroups => string.IsNullOrWhiteSpace(ResponsibleGroupsJson)
        ? new List<GroupEmailsDto>() : JsonConvert.DeserializeObject<List<GroupEmailsDto>>(ResponsibleGroupsJson);

    // Cap nhat 2026-08-20 (spec.md FR-008/FR-019, research.md R13): danh sach cac sales order code
    // rieng biet da gop lai khi doc-back deduplicate theo MasterCode/Code/Type/Product, noi lai
    // thanh 1 chuoi "SO1, SO2" de hien thi o cot Sales order (cuoi cung) trong email/Excel. Khac
    // voi SalesId (van la 1 gia tri dai dien duy nhat, dung cho noi dung thong bao in-app khong doi).
    public string? CombinedSalesIds { get; set; }
}
```

## External / non-persisted shapes referenced by this feature

- **`ComplDynReferenceResponseDto`** (existing, unchanged) — the "Open Sales Order" shape from `IComplDynamicsService.GetDynRefePagedAsync(refType=18, ...)`. Fields used: `Code` (→ `SalesId`/`ReferenceValue`), `DeliveryDate`, `CustAccount`.
- **`ViewCompliancesRequestDto`** (existing, unchanged) — request shape for `IViewCompliancesService.GetViewCompliancesAsync`: `ReferenceType = ObjectType.SALE_ORDER` (11), `ReferenceValue = so.Code`.
- **`ViewCompliancesResponseDto`** (existing, unchanged) — response shape; this feature filters `Status == "MISSING"` and maps every field listed in the table above into a new `ComplSoMissing` row.

## Assumptions carried from spec.md into the data model

- `MasterValidFrom`/`MasterValidTo`/`MasterNumDayAlert` exist as columns in `compl_so_missing` (per the pre-existing DDL) but have no corresponding source field on `ViewCompliancesResponseDto`. This plan leaves them `NULL` on insert unless `/speckit-tasks` identifies a low-cost enrichment (e.g. an additional lookup by `MasterId` against `compl_masters`) that the spec's FR-007 ("carrying over all other compliance detail fields returned by the lookup") would otherwise not satisfy for these three columns. Flagged here rather than silently guessed, since it affects what the alert email can show for a master's own validity window.

## Display-only computed values (2026-08-10, not persisted)

Per spec.md FR-012–FR-014, the alert email shows two values that are **not** entity/DTO columns and are never written to `compl_so_missing`:

- **Status (display)**: computed per row at alert-generation time from that row's `Code`/`ValidTo` — `"Missing"` / `"Expired"` / `"Valid"` (research.md R8). Distinct from the entity's own `Status` column above, which is always the literal `"MISSING"` (FR-005 pre-filter) and is left untouched.
- **Days remaining (display)**: computed per row at alert-generation time from `ValidTo` — blank when `ValidTo` is null, otherwise `"N days left"` (positive) or `"-N days left"` (negative, already expired). No `DaysRemaining` column exists on `ComplSoMissing`/`ComplSoMissingResponseDto`; unlike the general alert's `ViewCompliancesResponseDto.DaysRemaining` (populated by a SQL stored procedure at query time, see research.md R8 alternatives), this value is computed in C# at send time.

Both are computed inline in `ComplNotificationService.SendMailAndNotificationForSalesOrderMissing`'s anonymous email-row projection (research.md R8) — no entity or DTO change.

## Alert read-back deduplication and column drop (2026-08-18, not persisted)

Per spec.md FR-008/FR-012, the read-back step in `SendSalesOrderAlertAsync` now deduplicates the rows it reads from `compl_so_missing` by `MasterCode`, `Code`, `MappedRefTypeCode`, `MappedInputValue` (`DistinctBy`, first-occurrence-wins, research.md R11) before mapping to `ComplSoMissingResponseDto` and passing them into `SendMailAndNotificationForSalesOrderMissing`. This is a read-time, in-memory operation only:

- `compl_so_missing` itself is unaffected — it still stores one row per (sales order, MISSING item) exactly as before (FR-006/FR-007 unchanged); the dedup never deletes or merges rows in the table.
- `ComplSoMissing`/`ComplSoMissingResponseDto` still declare `SalesId` as a column/property, unchanged — it is simply excluded from the `complianceList` anonymous projection and `customHeaders` dictionary that drive the HTML email table and the Excel export (research.md R8–R11), so the alert's displayed layout goes from 14 columns to 13. `compliance.SalesId` remains available and is still used, unchanged, by the per-recipient in-app notification message text built later in the same method.

## Excel attachment (2026-08-10, transient, not persisted)

Per spec.md FR-015–FR-017, every sent alert email carries one additional Excel attachment. It is **not** a new entity, table, or file stored anywhere — it is a `byte[]` generated in memory from the same `complianceList`/`customHeaders` used for the HTML email body (research.md R9/R10), wrapped in a `MemoryStream` and attached to the outgoing email, then disposed once the email is sent. Its file name (`compl-sales-order-missing-<yyyyMMddHHmmss>.xlsx`) is derived from the send-time timestamp, not stored as a column anywhere.

## Excel row highlighting (2026-08-20, display-only, not persisted)

Per spec.md FR-018, each row in the Excel attachment whose (already-computed, per row above) `Status` display value is `"Expired"` gets a yellow cell-fill background across its full row range (research.md R12), matching the yellow highlight the email body already applies to the same rows (`Helper.cs:244`). This is a rendering property of the generated workbook only — it is derived from the same computed `Status` value described above ("Status (display)"), never written to `compl_so_missing`, and does not change which rows are included, their order, or their cell values.

## Sales order column, re-added and combined (2026-08-20, display-only, not persisted)

Per spec.md FR-008/FR-012/FR-019, the alert-building read-back in `SendSalesOrderAlertAsync` now groups (rather than merely deduplicates) `compl_so_missing` rows by `MasterCode`, `Code`, `MappedRefTypeCode`, `MappedInputValue` (research.md R13). Each resulting `ComplSoMissingResponseDto` carries a new `CombinedSalesIds` property (`string?`) — the distinct `SalesId` values from every row in that group, joined as `"SO1, SO2"` — which is shown as the last ("Sales order") column in both the email body and the Excel attachment. This is a display-only value:

- `compl_so_missing` itself is unaffected — it still stores one row per (sales order, MISSING item) exactly as before (FR-006/FR-007 unchanged); grouping never merges or deletes rows in the table.
- `ComplSoMissingResponseDto.SalesId` (inherited from `ComplSoMissing`) is unchanged in meaning — it remains the single sales order code of the group's first underlying row, and continues to be the value used, unchanged, by the per-recipient in-app notification message text built later in `SendMailAndNotificationForSalesOrderMissing`. `CombinedSalesIds` is a separate, additive property used only by the `complianceList`/`customHeaders`-driven email table and Excel export (research.md R8–R13).
