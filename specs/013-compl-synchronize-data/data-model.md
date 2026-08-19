# Data Model: Compliance Synchronize Data (Sales Line + Variant Attributes)

Two new local tables, plus additive (non-breaking) changes to one existing shared DTO and one existing
shared mapping method. No existing table's schema changes, and no existing D365 domain model's
existing fields are removed or renamed.

## Phase 1 — Existing entities reused (read-only)

### `RSVNSalesLineOpenInvoiceCogs` (D365 entity, read-only, endpoint `sales-line`)

`ComplianceSys.Domain/Dynamics/RSVNSalesLineOpenInvoiceCogs.cs` — unchanged. Fields used by this
feature: `ItemId` (→ local `ProductCode`), `SalesId`, `SalesStatus`, `ConfigId` (join key to the
Product reference lookup, and to Phase 2's grouping).

### `RSVNProductVariantAlls` (D365 entity, read-only, endpoint `product-variant-info` — research.md R10)

`ComplianceSys.Domain/Dynamics/RSVNProductVariantAlls.cs` — **modified, additive**: adds `ProductRange`
and `ProductType` properties (`string`), alongside its existing `ProductCode`, `ConfigId`,
`ProductVariantType`, `ProductDescription`, `ProductName` (all already present and reused as-is;
`ProductVariantType` itself is no longer used by this feature, kept for any other current/future
caller). `ProductRange`/`ProductType` were originally added as a single guessed `Range` property
(research.md R3) and mapped from `ProductVariantType`, but both were corrected after live D365 testing
confirmed the entity's real field names are `ProductRange` and `ProductType` — a separate field from
`ProductVariantType` (research.md R12). As of research.md R10, this entity is read via a new dedicated
endpoint (`DynController` `[HttpGet("product-variant-info")]`, structurally identical to the existing
`product-variant-attributes`/`sales-line` actions), one call per distinct `(ProductCode, ConfigId)`
combination present in that run's Sales Line data, filtered by an OData `$filter` clause — **not**
the generic `[HttpPost("reference")]` type-6 mechanism this document originally specified.

| Field (existing, reused) | Maps to local field |
|---|---|
| `ProductCode` | join key — matched against Sales Line's `ItemId` |
| `ConfigId` | join key — matched against Sales Line's `ConfigId` |
| `ProductName` | `ComplSyncSalesLine.ProductName` |
| `ProductDescription` | `ComplSyncSalesLine.ProductDescription` |
| `ProductType` (research.md R12 — corrected from `ProductVariantType`) | `ComplSyncSalesLine.ProductType` |
| `ProductRange` (research.md R12 — corrected from a guessed `Range`) | `ComplSyncSalesLine.ProductRange` |

**Superseded (research.md R10)**: this document originally specified additive changes to
`ComplDynReferenceResponseDto` (new `ProductCode`/`ConfigId`/`Description`/`Type`/`Range` properties)
and `ComplDynamicsService.MapDynamicsResponse`'s `case 6` branch, to support a bulk fetch of the
entire `RSVNProductVariantAlls` catalog via the generic reference type-6 mechanism. Per explicit
follow-up request to stop using that mechanism, **both changes were reverted** — nothing in this
codebase uses `refType = 6` any more. `ComplSynchronizeDataService` deserializes D365's
`product-variant-info` response directly into `RSVNProductVariantAlls` (via `OdataMapper<RSVNProductVariantAlls>`),
with no intermediate DTO.

## Phase 1 — New persisted entity

### `ComplSyncSalesLine` (local, `compl_sync_sales_line` table — new)

`ComplianceSys.Domain/Entities/ComplSyncSalesLine.cs` — new, no `BaseEntity` (single plain
`CreatedDate` column instead). **Table was already pre-created ahead of `/speckit-plan` with a real
schema that differs from this feature's original speculative design — see research.md R9 for the full
discovery and rationale.** This table's data is fully replaced every run (research.md R6).

| Column | Type | Notes |
|---|---|---|
| `Id` | bigint unsigned, PK, AUTO_INCREMENT | not a business key |
| `SalesId` | varchar(50), NULL | from Sales Line's `SalesId` (FR-003) |
| `SalesStatus` | varchar(50), NOT NULL | from Sales Line's `SalesStatus`, copied directly — confirmed via live D365 data to be an enum **label** (`"Invoiced"`, `"Backorder"`, ...), not numeric; column widened from the original speculative `tinyint` (research.md R12, corrects R9) |
| `ProductCode` | varchar(50), NOT NULL | from Sales Line's `ItemId` — rows with a blank `ItemId` are skipped before insert (FR-007), so this is always populated |
| `ConfigId` | varchar(20), NOT NULL | from Sales Line's `ConfigId`; empty string (not NULL) when the source has no value; used as Phase 2's join/grouping key (FR-009/FR-010) |
| `ProductName` | varchar(250), NOT NULL | from the matched Product reference's `ProductName`; empty string when no match (FR-005/FR-006) |
| `ProductDescription` | varchar(250), NOT NULL | from the matched Product reference's `ProductDescription`; empty string when no match |
| `ProductType` | varchar(100), NOT NULL | from the matched Product reference's `ProductType` (research.md R12 — the real field name, not `ProductVariantType`); empty string when no match |
| `ProductRange` | varchar(100), NOT NULL | from the matched Product reference's `ProductRange` (research.md R12 — the real field name, confirmed to exist; not `Range`); empty string when no match or field unavailable |
| `CreatedDate` | datetime, NOT NULL | set to `DateTime.UtcNow` at insert time |

**Business rules**: The table is fully cleared (`DELETE FROM compl_sync_sales_line`, no `WHERE`) at the
start of Phase 1 (FR-008), before any Sales Line record is evaluated. Every retrieved Sales Line record
that has both an Item ID and a Sales ID is inserted (FR-007) — including ones with no Product reference
match (`ProductName`/`ProductDescription`/`ProductType`/`ProductRange` left as empty string, FR-006).
No `UPDATE` is ever issued — every run is a full delete-then-insert.

## Phase 2 — Existing entities reused (read-only)

### `ProductVariantAttributes` (D365 entity, read-only, endpoint `product-variant-attributes`)

`ComplianceSys.Domain/Dynamics/ProductVariantAttributes.cs` — **modified, additive**: add one new
property, `GroupId` (`string`), alongside its existing `DistinctProductVariant`, `AttributeType`,
`AttributeTypeName`, `AttributeValue`, `AttributeValueName`, `ConfigId`, `ProductCode`,
`ProductVariant`, `GroupValue`. See research.md R9 for why `GroupId` needs adding (the real, already
pre-created `compl_sync_variant_attributes` table requires it) and the same live-D365-verification
caveat as `RSVNProductVariantAlls.Range` (research.md R3). **Only `ConfigId`, `ProductCode`,
`GroupId`, `GroupValue`, `AttributeType`, `AttributeTypeName`, `AttributeValue`, `AttributeValueName`
are persisted** — `DistinctProductVariant` and `ProductVariant` are read from D365 but have no column
in the real table (research.md R9) and are not stored locally by this feature.

## Phase 2 — New persisted entity

### `ComplSyncVariantAttributes` (local, `compl_sync_variant_attributes` table — new)

`ComplianceSys.Domain/Entities/ComplSyncVariantAttributes.cs` — new, no `BaseEntity` (single plain
`CreatedDate` column instead), same rationale as `ComplSyncSalesLine`. **Table was already pre-created
ahead of `/speckit-plan` with a real schema that differs from this feature's original speculative
design — see research.md R9.**

| Column | Type | Notes |
|---|---|---|
| `Id` | bigint unsigned, PK, AUTO_INCREMENT | not a business key |
| `ProductCode` | varchar(50), NULL | the combination's Product Code (from `compl_sync_sales_line`'s distinct grouping, FR-009) |
| `ConfigId` | varchar(20), NOT NULL | the combination's Config ID; empty string when unavailable |
| `GroupId` | varchar(50), NOT NULL | from D365 `ProductVariantAttributes.GroupId` (research.md R9); empty string when unavailable |
| `GroupValue` | varchar(50), NOT NULL | from D365 `GroupValue`; empty string when unavailable |
| `AttributeType` | bigint, NOT NULL | from D365 `AttributeType` |
| `AttributeTypeName` | varchar(150), NOT NULL | from D365 `AttributeTypeName`; empty string when unavailable |
| `AttributeValue` | bigint, NOT NULL | from D365 `AttributeValue` |
| `AttributeValueName` | varchar(150), NOT NULL | from D365 `AttributeValueName`; empty string when unavailable |
| `CreatedDate` | datetime, NOT NULL | set to `DateTime.UtcNow` at insert time |

**Business rules**: The table is fully cleared (`DELETE FROM compl_sync_variant_attributes`, no
`WHERE`) at the start of Phase 2 (FR-012), before any combination is looked up. One row is inserted per
attribute record returned by a combination's lookup (a single Product+Config combination's D365 result
can itself contain multiple attribute rows — one per `AttributeType`); a combination whose lookup
returns no data contributes zero rows and is not treated as an error (FR-014).

## New response DTO (response shape only)

### `ComplSynchronizeDataSummaryDto` (new — `ComplianceSys.Application/Dtos/Response/`)

Returned by the sync endpoint so the caller can tell what happened without inspecting logs or the
database directly (spec FR-015/SC-005).

| Field | Type | Meaning |
|---|---|---|
| `SalesLineFetched` | int | Total Sales Line records read across all pages (Phase 1) |
| `SalesLineAdded` | int | `compl_sync_sales_line` rows inserted this run |
| `SalesLineSkipped` | int | Sales Line records skipped (missing Item ID or Sales ID, FR-007) |
| `DistinctProductConfigCount` | int | Distinct Product+Config combinations derived from `compl_sync_sales_line` after Phase 1 (FR-009/FR-010) |
| `VariantAttributeAdded` | int | `compl_sync_variant_attributes` rows inserted this run (Phase 2) |
| `Success` | bool | `false` if the run stopped early due to a source-fetch error in either phase |
| `Message` | string | Human-readable summary (counts, or the error that stopped the run) |

## Sequence

```
ComplSynchronizeDataController.TestComplSynchronizeData (GET test-compl-synchronize-data)
  -> IComplSynchronizeDataService.RunAsync(ct)
       -- Phase 1 --
       -> IComplSyncSalesLineRepository.DeleteAllAsync(ct)                          // FR-008
       -> loop pages: raw D365 query against RSVNSalesLineOpenInvoiceCogs (sales-line)  // R1/R2
       -> derive distinct (ItemId, ConfigId) from valid Sales Line records (ItemId+SalesId present)
       -> for each distinct (ItemId, ConfigId): raw D365 query against RSVNProductVariantAlls
            (product-variant-info), filter "ProductCode eq '{code}' and ConfigId eq '{configId}'",
            build Dictionary<(ProductCode,ConfigId), RSVNProductVariantAlls>              // R10
       -> for each Sales Line record:
            -> skip if ItemId/SalesId missing (FR-007)
            -> else: dictionary lookup by (ItemId, ConfigId) -> populate ProductName/
               ProductDescription/ProductType/ProductRange if found, leave blank if not (FR-005/FR-006)
            -> IComplSyncSalesLineRepository.InsertManyAsync(...)                    // FR-003..FR-006
       -- Phase 2 (only after Phase 1 fully completes, FR-009) --
       -> IComplSyncSalesLineRepository.GetDistinctProductConfigCombinationsAsync(ct) // FR-009/FR-010, R7
       -> IComplSyncVariantAttributesRepository.DeleteAllAsync(ct)                   // FR-012
       -> for each distinct (ProductCode, ConfigId):
            -> raw D365 query against ProductVariantAttributes (product-variant-attributes),
               filter "ProductCode eq '{code}' and ConfigId eq '{configId}'"          // FR-011, R5
            -> IComplSyncVariantAttributesRepository.InsertManyAsync(...) if any rows returned // FR-013/FR-014
       -> return ComplSynchronizeDataSummaryDto
```

Any D365 call failure in either phase stops the run and returns `Success = false` with a partial-counts
message (FR-017), consistent with 011's established failure handling — no automatic rollback of rows
already saved before the failure.
