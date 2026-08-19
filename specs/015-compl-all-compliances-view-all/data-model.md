# Phase 1 Data Model: All Compliances Sales-Line Fallback for Missing BOM

No new persisted storage or database schema is introduced by this feature — all entities below are
existing Dynamics 365 F&O OData-backed Domain models (`compliance-sys-api/src/ComplianceSys.Domain/Dynamics/`)
already present in the codebase. This feature adds a new *fallback construction path* that produces
records of an existing shape (t1) from data read out of two other existing shapes (t2, t3); it does
not add or change any entity's fields.

## Entities

### t1 — `RSVNSalesLineOpenMaterialRvns` (Sales-Line Open Material; target/output shape)

Existing entity, unchanged. Normally produced by the BOM-based lookup
(`GetSalesLineOpenMaterialFromDynamics`); this feature adds a second way to populate it when that
lookup returns nothing.

| Field | Type | Fallback population (this feature) |
|---|---|---|
| `SalesId` | string | copied from t2 `SalesId` |
| `InterSalesId` | string | `"cog"` + t2 `SalesId` |
| `ProductCode` | string | copied from t2 `ItemId` |
| `ConfigId` | string | copied from t2 `ConfigId` |
| `MaterialCode` | string | blank |
| `CountryRegionId` | string | copied from t2 `CountryRegionId` |
| `ProductType` | string | matched from t3 by `(ProductCode, ConfigId)`, else blank |
| `MaterialType` | string | blank |
| `CostGroupId` | string | blank |
| `AreaId` | string | copied from t2 `AreaId` |
| `MaterialName` | string | blank |
| `ProductGroup` | string | blank |
| `SalesStatus` | string | copied from t2 `SalesStatus` |
| `ProductRange` | string | matched from t3 by `(ProductCode, ConfigId)`, else blank |

### t2 — `RSVNSalesLineOpenInvoiceCogs` (Sales Order Line; fallback source)

Existing entity, unchanged. Fetched (new, R2) filtered by `SalesId eq '{salesOrder}'` — the same
sales order code passed into the primary BOM-based lookup.

| Field | Type | Used by this feature? |
|---|---|---|
| `SalesId` | string | yes → t1 `SalesId`, and via `"cog"` + value → t1 `InterSalesId` |
| `SalesStatus` | string | yes → t1 `SalesStatus` |
| `ItemId` | string | yes → t1 `ProductCode` |
| `InventDimId` | string | no |
| `ConfigId` | string | yes → t1 `ConfigId`, and used as match key into t3 |
| `AreaId` | string | yes → t1 `AreaId` |
| `WorkerSalesResponsible` | long | no |
| `CustName` | string | no |
| `CustAccount` | string | no |
| `WorkerSalesTaker` | long | no |
| `CountryRegionId` | string | yes → t1 `CountryRegionId` |

### t3 — `RSVNProductVariantAlls` (Product Variant Info; fallback enrichment source)

Existing entity, unchanged. Fetched (new, R3) matched by the distinct `(ProductCode, ConfigId)`
pairs present across all t2 rows for the sales order: filter
`(ProductCode eq '{ItemId}' and ConfigId eq '{ConfigId}')`, OR-combined across pairs.

| Field | Type | Used by this feature? |
|---|---|---|
| `ProductCode` | string | yes, match key |
| `ConfigId` | string | yes, match key |
| `ProductType` | string | yes → t1 `ProductType` |
| `ProductRange` | string | yes → t1 `ProductRange` |
| (all other fields) | — | no |

## Relationships

- One t2 row (one sales order line) produces exactly one t1 row (1:1) — unlike the BOM-based path,
  where one product/config variant can expand into multiple t1 rows (one per material component);
  the fallback has no material breakdown to expand from (FR-007).
- Zero or one t3 row is matched per distinct `(ProductCode, ConfigId)` pair; when none matches, the
  corresponding t1 rows simply have `ProductType`/`ProductRange` blank (FR-006). Multiple t2 rows
  sharing the same `(ProductCode, ConfigId)` share the same t3 match.

## Validation / Business Rules

- The fallback path only runs when the primary BOM-based lookup returns a zero-length list
  (FR-002); it must not run when that lookup returns any records (FR-003).
- If the fallback source (t2) also returns zero rows, no t1 rows are produced and downstream
  behavior is identical to today's "no data" case (FR-009) — this is not an error condition.
- No state transitions apply; this is a read-only, per-request data composition, not a stored
  entity with a lifecycle.
