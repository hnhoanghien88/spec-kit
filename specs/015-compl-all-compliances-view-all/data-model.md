# Phase 1 Data Model: All Compliances Sales-Line Fallback for Missing BOM

Originally, no new persisted storage or database schema was introduced by this feature — all
entities below (t1–t3) are existing Dynamics 365 F&O OData-backed Domain models
(`compliance-sys-api/src/ComplianceSys.Domain/Dynamics/`) already present in the codebase. This
feature added a new *fallback construction path* that produces records of an existing shape (t1)
from data read out of two other existing shapes (t2, t3); it did not add or change any of their
fields.

**Update (2026-08-20, User Story 5)**: one persisted entity does gain a new field — see
`ComplSummarySo` below.

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

### `ComplSummarySo` (Compliance Summary; persisted, `compl_summary_so` table)

Existing entity (`compliance-sys-api/src/ComplianceSys.Domain/Entities/ComplSummarySo.cs`), written
by **two independent paths**: `ViewCompliancesSummaryService.GetAndSaveSummarySo` (User Story 3, the
nightly/on-demand summary job) and `ComplSummarySoService.SaveSummarySo` (called via a background job
enqueued from `ViewCompliancesService.GetViewCompliancesAsync`, User Story 1's "get-all" lookup —
found 2026-08-20 while verifying this feature's coverage, R8). This update adds one new
column/property, set by both writers.

| Field | Type | Change (this feature) |
|---|---|---|
| `BomStatus` | `string?` | **New.** Set to literal `"No BOM"` by whichever writer is running, when *that writer's own* BOM-based sales-line lookup (`GetSalesLineOpenMaterialFromDynamics`) returns zero records for that sales order — the same condition that already triggers the fallback (R1/FR-011, R8/FR-016); left `null` otherwise. Applies on both insert (new saved record) and update (existing saved record) paths in both writers, so a record previously marked `"No BOM"` reverts to `null` once the sales order's BOM is created and either writer reprocesses it (FR-013–FR-016). The two writers do not coordinate — each independently overwrites the field with its own lookup's result (spec.md Edge Cases). |
| *(all other existing fields)* | — | unchanged |

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
- `ComplSummarySo.BomStatus` (new) does have a simple two-state lifecycle driven entirely by the
  BOM-based lookup's emptiness at save time: `"No BOM"` ↔ `null`, re-evaluated and overwritten every
  time either writer (`GetAndSaveSummarySo` or `SaveSummarySo`) processes that sales order — no
  independent state is preserved across runs or between the two writers (see research.md R7, R8).

### `RSVNSalesOrderOpenInvoiceCogs` (Get365 list-screen response row; not persisted)

Existing Domain model (`compliance-sys-api/src/ComplianceSys.Domain/Dynamics/RSVNSalesOrderOpenInvoiceCogs.cs`),
returned by `ViewCompliancesController.Get365` for the All Compliances Sale Order list screen
(`ref-type=11`). Already carries several fields copied in from `compl_summary_so` at request time
(`TotalCompliances`, `TotalMissing`, `TotalApplied`, `TotalOverdue`, `ResponsibleEmails`,
`AlertEmails`) — not stored on this row itself, just enriched onto it per-request by `Get365`
(R9). This update adds one more such enriched field.

| Field | Type | Change (this feature) |
|---|---|---|
| `BomStatus` | `string?` | **New.** Copied from the matched `compl_summary_so` row's `BomStatus` (same match-by-`SalesId` the other enriched fields already use) when a match exists; left `null` when no matching summary row is found for that sales order (User Story 6, FR-018/FR-020). Read by the frontend's new "BOM" column (R9) — not itself persisted anywhere. |
| *(all other fields)* | — | unchanged |

## Schema Change

- `compl_summary_so` gains one nullable `VARCHAR` column, `BomStatus`, added via migration
  `Sqls/Migration/25_add_bomstatus_to_compl_summary_so.sql` (for already-existing databases) **and**
  a matching edit to the baseline snapshot `Sqls/Tables/compl_summary_so.sql` (so a brand-new
  database, bootstrapped by `DatabaseInitializer.InitTables()`, also gets the column — research.md
  R7). No other table is changed.
