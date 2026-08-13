# Data Model: EUTR Synchronize Data (Sales Order Template Sync)

No new database table and no change to an existing table's schema. This feature reads an existing
D365 reference entity and writes to an existing local table, using an existing local entity as-is.

## Existing entities reused (no changes)

### `EutrPurchaseAttachments` (local, `eutr_purchase_attachments` table)

`ComplianceSys.Domain/Entities/EutrPurchaseAttachments.cs` — unchanged.

| Column | Type | Notes |
|---|---|---|
| `Id` | int, PK, identity | unchanged |
| `SalesId` | string, NOT NULL | populated from D365 `InterCompanyOriginalSalesId` |
| `PurchId` | string, NOT NULL | populated from D365 `RSVNRefPurchId` |
| `TemplateCode` | string, NOT NULL, FK → `eutr_templates.Code` | populated from D365 `RSVNEutrTemplate` |
| `CreatedBy` / `CreatedDate` / `UpdatedBy` / `UpdatedDate` | audit columns from `BaseEntity` | set by the sync run (see below) |

Existing uniqueness behavior relied on by this feature: **none is enforced by the schema** — the
"one row per new `SalesId`" guarantee comes entirely from this feature's own pre-insert check
(research.md R5), matching the spec's explicit "check before add" instruction. Rows already present
for a `SalesId` (however they got there — this sync or Map File) are left untouched.

### `RSVNEutrSalesOrderTemplates` (D365 reference entity, read-only)

`ComplianceSys.Domain/Dynamics/RSVNEutrSalesOrderTemplates.cs` — unchanged. `ModelType = 19`,
`EntityName = "RSVNEutrSalesOrderTemplates"`.

| Field | Maps to local field |
|---|---|
| `InterCompanyOriginalSalesId` | `EutrPurchaseAttachments.SalesId` |
| `RSVNRefPurchId` | `EutrPurchaseAttachments.PurchId` |
| `RSVNEutrTemplate` | `EutrPurchaseAttachments.TemplateCode` |

## Changed (existing file, additive fix — research.md R2/R3)

### `ComplDynamicsService.EntityMappings` (dictionary literal, not a data model per se)

Add the missing entry so `refType = 19` stops short-circuiting to an empty result:

```csharp
{ 19, ("RSVNEutrSalesOrderTemplates", "InterCompanyOriginalSalesId", "RSVNEutrTemplate") }
```

### `ComplDynamicsService.MapDynamicsResponse`, `case 19`

Additionally populate the DTO's named fields (alongside the existing `Id`/`Code`/`Name`) so callers
don't have to remember the `Id`/`Code`/`Name` remapping:

```csharp
case 19:
    responseItems = items.ToObject<List<RSVNEutrSalesOrderTemplates>>()
        ?.Select(x => new ComplDynReferenceResponseDto
        {
            Id = x.InterCompanyOriginalSalesId,
            Code = x.RSVNEutrTemplate,
            Name = x.RSVNRefPurchId,
            InterCompanyOriginalSalesId = x.InterCompanyOriginalSalesId,
            EutrTemplate = x.RSVNEutrTemplate,
            RSVNRefPurchId = x.RSVNRefPurchId,
        })
        .ToList() ?? new();
    break;
```

(`ComplDynReferenceResponseDto` already declares `InterCompanyOriginalSalesId`, `EutrTemplate`, and
`RSVNRefPurchId` — used today by `case 16`/`case 20` — so no DTO change is needed.)

## New DTO (response shape only, no persistence)

### `EutrSynchronizeSummaryDto` (new — `ComplianceSys.Application/Dtos/Response/`)

Returned by the sync endpoint so the caller can tell what happened without checking logs or the
database directly (spec FR-007 / SC-004).

| Field | Type | Meaning |
|---|---|---|
| `TotalFetched` | int | Total D365 reference records read across all pages |
| `Added` | int | New `eutr_purchase_attachments` rows created this run |
| `Skipped` | int | Records not added (already existed, or missing a required field) |
| `Success` | bool | `false` if the run stopped early due to a source-fetch error |
| `Message` | string | Human-readable summary (e.g. counts, or the error that stopped the run) |

## Sequence (for reference — implementation detail, not a new persisted entity)

```
EutrSynchronizeDataController.TestSoTemplateSync (GET test-so-template-sync)
  -> IEutrSynchronizeDataService.SyncSalesOrderTemplatesAsync(ct)
       -> IEutrPurchaseAttachmentsRepository.GetSalesIdsWithTemplateAsync(ct)   // preload existing SalesIds (R5)
       -> loop pages: IComplDynamicsService.GetDynRefePagedAsync(19, ..., ct)   // R1, R2, R4
            -> for each record: skip if SalesId/PurchId/TemplateCode missing (FR-006)
            -> skip if SalesId already in the in-memory set (FR-003/FR-004)
            -> else: IRepository<EutrPurchaseAttachments,int>.AddAsync(...) and add SalesId to the set (FR-005, R6)
       -> return EutrSynchronizeSummaryDto
```
