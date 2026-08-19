# Phase 0 Research: All Compliances Sales-Line Fallback for Missing BOM

All items below were resolved from the existing codebase (no external unknowns remain); this
feature has no `NEEDS CLARIFICATION` entries in the Technical Context.

## R1 — Where the fallback is triggered

**Decision**: Trigger the fallback inside `ViewCompliancesService.GetViewCompliancesAsync`, in the
existing `so != null` branch, immediately after the current call to
`_dynamicsDataService.GetSalesLineOpenMaterialFromDynamics(so.ReferenceValue)`
([ViewCompliancesService.cs:64](../../../compliance-sys-api/src/ComplianceSys.Application/Services/ViewCompliancesService.cs#L64)).
When that call returns an empty list, call the new fallback-building method (R4) and use its
result as `salesLineOpenMaterials` for the rest of the method, unchanged otherwise.

**Rationale**: This is the exact line quoted in the feature request, and it is the single place
that produces `salesLineOpenMaterials` for the `[HttpPost("get-all")]` sales-order lookup
(FR-001–FR-003). No other caller of `GetSalesLineOpenMaterialFromDynamics` is in scope
(`Test` at line 183 is a diagnostic method not covered by this feature's Assumptions).

**Alternatives considered**: Pushing the fallback decision into `DynamicsDataService` itself (i.e.
making `GetSalesLineOpenMaterialFromDynamics` fall back internally) was rejected — that method is
also called from `Test` (line 183) and other flows outside the scope confirmed with the user
(Assumptions in spec.md), and `DynamicsDataService`'s existing responsibility is one-entity-per-method
(Principle I); cross-entity fallback composition belongs in the layer above it.

## R2 — New fetch method for the sales-order-line fallback source (t2)

**Decision**: Add `Task<List<RSVNSalesLineOpenInvoiceCogs>> GetSalesLineOpenInvoiceCogsFromDynamics(string salesOrder)`
to `IDynamicsDataService` / `DynamicsDataService`, querying entity `"RSVNSalesLineOpenInvoiceCogs"`
with filter `(SalesId eq '{salesOrder}')`, mirroring the existing
`GetSalesLineOpenMaterialFromDynamics` method's structure (cache-key `RSVNSalesLineOpenInvoiceCogs:{salesOrder}`,
cache read → OData query via `DynamicsParameterManager` + `IDynamicService.QueryAsync` →
`Helper.ParseDynamicsResponse<RSVNSalesLineOpenInvoiceCogs>` → cache write).

**Rationale**: This is the data source behind `DynController`'s
[`[HttpGet("sales-line")]`](../../../compliance-sys-api/src/ComplianceSys.Api/Controllers/DynController.cs#L749)
endpoint (t2 in the request), entity `RSVNSalesLineOpenInvoiceCogs`, which already has a Domain
model but no existing `DynamicsDataService` method — every other Dynamics entity used by this
service layer is fetched through a dedicated method on `IDynamicsDataService`, so this follows the
established one-method-per-entity convention (Principle II reference pattern:
`GetSalesLineOpenMaterialFromDynamics`).

**Alternatives considered**: Calling `IDynamicService.QueryAsync` directly from the new
orchestration method (R4), bypassing `DynamicsDataService`. Rejected — it would break the
established layering where all direct Dynamics OData access goes through `DynamicsDataService`,
and would forgo caching consistency with sibling methods.

## R3 — New fetch method for the product-variant-info enrichment source

**Decision**: Add `Task<List<RSVNProductVariantAlls>> GetRSVNProductVariantAllsByProductConfigFromDynamics(IEnumerable<(string ProductCode, string ConfigId)> variants)`
to `IDynamicsDataService` / `DynamicsDataService`, querying entity `"RSVNProductVariantAlls"` with an
OR-of-ANDs filter — `(ProductCode eq 'x' and ConfigId eq 'y') or (...)` — one AND-clause per
distinct `(ProductCode, ConfigId)` pair, mirroring the existing
`GetRSVNProductVariantMaterialsFromDynamics` / `GetRSVNCustVendExternalItemsFromDynamics` methods
(same distinct/order/cache-key-join/OR-filter pattern).

**Rationale**: This is the data source behind `DynController`'s
[`[HttpGet("product-variant-info")]`](../../../compliance-sys-api/src/ComplianceSys.Api/Controllers/DynController.cs#L647)
endpoint (entity `RSVNProductVariantAlls`), and the feature request explicitly specifies a
`ProductCode eq ... and ConfigId eq ...` filter shape (FR-005) — the same two-field AND-filter
shape already used by `GetRSVNProductVariantMaterialsFromDynamics` for the same entity's sibling
lookup, just against a different entity name.

**Alternatives considered**: Reusing the existing `GetRSVNProductVariantAllsFromDynamics(List<string> productVariants)`,
which already queries `RSVNProductVariantAlls` but filters by a single concatenated
`ProductVariant eq 'x'` value. Rejected — changing that method's filter shape would alter its
existing contract for its current callers (`TransformSoToRequestForSql`'s sibling variant-description
lookups), violating Principle III ("reused as-is" for already-working code); adding a new method
keeps both call sites independent and correct.

## R4 — Where the t2→t1 mapping/orchestration lives

**Decision**: Add `Task<List<RSVNSalesLineOpenMaterialRvns>> BuildSalesLineOpenMaterialFallbackAsync(string salesOrder)`
to `IViewCompliancesTransformService` / `ViewCompliancesTransformService`. It calls R2's method; if
empty, returns `[]` (FR-009). Otherwise it builds the distinct `(ProductCode, ConfigId)` pairs from
the t2 rows (`ProductCode` = t2 `ItemId`), calls R3's method once for all pairs, and maps each t2
row into a `RSVNSalesLineOpenMaterialRvns` per the field table in R5.

**Rationale**: `ViewCompliancesTransformService` already owns the job of composing multiple raw
Dynamics entities into one target shape for this exact flow (`TransformSoToRequestForSql` combines
customer, attribute, and sales-line data). Placing the t2→t1 mapping here keeps
`DynamicsDataService` a thin per-entity fetch layer (Principle I: business rules do not belong in
the data-fetch layer) and keeps `ViewCompliancesService` free of field-mapping detail, consistent
with how it already delegates transformation work to `_transformService`.

**Alternatives considered**: Inlining the mapping directly in `ViewCompliancesService.GetViewCompliancesAsync`.
Rejected — that method already delegates all shape-transformation work to `_transformService`; inlining
a second, different mapping style there would be inconsistent with the file's existing structure.

## R5 — Field mapping (t2 sales-order-line → t1 sales-line-open-material, per FR-004–FR-007)

| t1 field (`RSVNSalesLineOpenMaterialRvns`) | Source | Rule |
|---|---|---|
| `SalesId` | t2 `SalesId` | direct copy (same name) |
| `InterSalesId` | t2 `SalesId` | literal `"cog"` + t2 `SalesId` (no separator) |
| `ProductCode` | t2 `ItemId` | direct copy (renamed field) |
| `ConfigId` | t2 `ConfigId` | direct copy (same name) |
| `AreaId` | t2 `AreaId` | direct copy (same name) |
| `CountryRegionId` | t2 `CountryRegionId` | direct copy (same name) |
| `SalesStatus` | t2 `SalesStatus` | direct copy (same name) |
| `ProductType` | product-variant-info match on `(ProductCode, ConfigId)` | matched value, else blank |
| `ProductRange` | product-variant-info match on `(ProductCode, ConfigId)` | matched value, else blank |
| `MaterialCode`, `MaterialName`, `MaterialType`, `CostGroupId`, `ProductGroup` | — | always blank (no BOM data available) |

t2 fields not used: `InventDimId`, `WorkerSalesResponsible`, `CustName`, `CustAccount`,
`WorkerSalesTaker` (no corresponding t1 field).

## R6 — Caching

**Decision**: Both new `DynamicsDataService` methods (R2, R3) use the existing `ICacheHelper`
read/write pattern, same `_cacheExpiration` setting, same cache-key style as sibling methods
(`EntityName:{key}` / `EntityName:{joined-keys}`).

**Rationale**: Consistent with every existing method in `DynamicsDataService`; no new caching
strategy or infrastructure is introduced (Principle III — reuse existing infrastructure).
