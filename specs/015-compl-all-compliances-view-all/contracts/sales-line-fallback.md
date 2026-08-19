# Contract Delta: `POST api/view-compliances/get-all` (internal fallback)

## External HTTP contract — unchanged

Endpoint already exists (`ViewCompliancesController`, `[Route("api/view-compliances")]`,
`[HttpPost("get-all")]`, [ViewCompliancesController.cs:141](../../../compliance-sys-api/src/ComplianceSys.Api/Controllers/ViewCompliancesController.cs#L141)).
This feature does **not** change the request shape, route, auth policy, or the
`ApiResponse<IEnumerable<ViewCompliancesResponseDto>>` response shape. It only changes what data
feeds the sales-order branch internally when the BOM-based sales-line lookup returns nothing
(FR-001–FR-003). No consumer of the HTTP endpoint needs to change.

## Internal contract additions

Two new methods on `IDynamicsDataService`, plus one new method on `IViewCompliancesTransformService`.
These are internal Application-layer interfaces (`compliance-sys-api/src/ComplianceSys.Application/`);
they are not exposed over HTTP.

### `IDynamicsDataService.GetSalesLineOpenInvoiceCogsFromDynamics`

```csharp
Task<List<RSVNSalesLineOpenInvoiceCogs>> GetSalesLineOpenInvoiceCogsFromDynamics(string salesOrder);
```

- **Input**: a sales order code (same value passed to `GetSalesLineOpenMaterialFromDynamics`).
- **Behavior**: queries Dynamics entity `RSVNSalesLineOpenInvoiceCogs` filtered by
  `SalesId eq '{salesOrder}'` (mirrors `DynController`'s `[HttpGet("sales-line")]`), through the
  existing cache-then-OData-query pattern used by every other `DynamicsDataService` method.
- **Output**: zero or more rows for the sales order code; empty list when the sales order has no
  lines in this source (not an error).
- **Corresponds to spec.md**: FR-002 (fallback source), t2 in the Key Entities section.

### `IDynamicsDataService.GetRSVNProductVariantAllsByProductConfigFromDynamics`

```csharp
Task<List<RSVNProductVariantAlls>> GetRSVNProductVariantAllsByProductConfigFromDynamics(
    IEnumerable<(string ProductCode, string ConfigId)> variants);
```

- **Input**: the distinct `(ProductCode, ConfigId)` pairs present across the sales order's t2 rows
  (`ProductCode` = t2 `ItemId`).
- **Behavior**: queries Dynamics entity `RSVNProductVariantAlls` with an OR-of-ANDs filter — one
  `(ProductCode eq '...' and ConfigId eq '...')` clause per pair — mirroring
  `GetRSVNProductVariantMaterialsFromDynamics`'s existing filter-building pattern (mirrors
  `DynController`'s `[HttpGet("product-variant-info")]`).
- **Output**: zero or more matched rows; a pair with no match simply contributes nothing (caller
  leaves `ProductType`/`ProductRange` blank for that pair — FR-006).
- **Corresponds to spec.md**: FR-005–FR-006, t3 ("Product Variant Info") in the Key Entities section.

### `IViewCompliancesTransformService.BuildSalesLineOpenMaterialFallbackAsync`

```csharp
Task<List<RSVNSalesLineOpenMaterialRvns>> BuildSalesLineOpenMaterialFallbackAsync(string salesOrder);
```

- **Input**: the sales order code.
- **Behavior**: calls the two methods above and maps each t2 row into a `RSVNSalesLineOpenMaterialRvns`
  per the field table in [research.md R5](../research.md#r5--field-mapping-t2-sales-order-line--t1-sales-line-open-material-per-fr-004fr-007)
  / [data-model.md](../data-model.md). Returns `[]` when t2 itself has no rows (FR-009) — the
  caller then proceeds exactly as today's existing "no data" case.
- **Output**: a list shaped exactly like `GetSalesLineOpenMaterialFromDynamics`'s return type, so
  the caller (`ViewCompliancesService.GetViewCompliancesAsync`) can use it as a drop-in replacement
  for `salesLineOpenMaterials` without any other code change (FR-008).
- **Corresponds to spec.md**: FR-004–FR-009, User Story 1 Acceptance Scenarios 1, 3–6.

## Call-site changes

`ViewCompliancesService.GetViewCompliancesAsync`
([ViewCompliancesService.cs:64](../../../compliance-sys-api/src/ComplianceSys.Application/Services/ViewCompliancesService.cs#L64)):

```csharp
salesLineOpenMaterials = await _dynamicsDataService.GetSalesLineOpenMaterialFromDynamics(so.ReferenceValue);
if (!salesLineOpenMaterials.Any())
{
    salesLineOpenMaterials = await _transformService.BuildSalesLineOpenMaterialFallbackAsync(so.ReferenceValue);
}
```

Everything after this point in the method (`TransformSoToRequestForSql`, the repository call, and
the `SaveSummarySo` background job) is unchanged — it already consumes `salesLineOpenMaterials` by
its existing shape, regardless of which path populated it (FR-008).

**Added 2026-08-19 (User Story 2, FR-010)** — `ViewCompliancesService.TransformSoAsync`
(behind `GET api/view-compliances/transform-so/{salesId}`, consumed by the "Sales order compliance
detail" tab in `compliance-view-so`):

```csharp
var salesLineOpenMaterials = await _dynamicsDataService.GetSalesLineOpenMaterialFromDynamics(salesId);
if (!salesLineOpenMaterials.Any())
{
    salesLineOpenMaterials = await _transformService.BuildSalesLineOpenMaterialFallbackAsync(salesId);
}
if (!salesLineOpenMaterials.Any())
    return [];
```

Same fallback method, no new backend logic — `TransformSoAsync`'s existing grouping into
`SalesOrderDto`/`SalesOrderDetailDto`/`MaterialDto` runs unchanged on whichever list populated
`salesLineOpenMaterials`. `ViewCompliancesService.Test` (diagnostic-only, no UI consumer) still
calls `GetSalesLineOpenMaterialFromDynamics` directly with no fallback.

**Added 2026-08-19 (User Story 3, FR-011)** — `ViewCompliancesSummaryService.GetAndSaveSummarySo`
(the `daily_update_count_all_compliances` Hangfire job; `ViewCompliancesService.GetAndSaveSummarySo`
is a one-line delegate to it, unchanged):

```csharp
var salesLineOpenMaterials = await _dynamicsDataService.GetSalesLineOpenMaterialFromDynamics(salesOrders[i].SalesId);
if (!salesLineOpenMaterials.Any())
{
    salesLineOpenMaterials = await _transformService.BuildSalesLineOpenMaterialFallbackAsync(salesOrders[i].SalesId);
}
var tran = await _transformService.TransformSoToRequestForSql(salesLineOpenMaterials, salesOrders[i].CustAccount);
```

Same fallback method again, no new backend logic. `ViewCompliancesSummaryService` already had
`IViewCompliancesTransformService` injected, so no DI change was needed.

**Added 2026-08-19 (User Story 4, FR-012)** — `ViewCompliancesDownloadService.GetViewCompliancesForDownloadAsync`
([ViewCompliancesDownloadService.cs:32](../../../compliance-sys-api/src/ComplianceSys.Application/Services/ViewCompliances/ViewCompliancesDownloadService.cs#L32))
and `ViewCompliancesAlertService.GetViewCompliancesForSendAlertAsync`
([ViewCompliancesAlertService.cs:31](../../../compliance-sys-api/src/ComplianceSys.Application/Services/ViewCompliances/ViewCompliancesAlertService.cs#L31)):

```csharp
var salesLineOpenMaterials = await _dynamicsDataService.GetSalesLineOpenMaterialFromDynamics(salesId);
if (!salesLineOpenMaterials.Any())
{
    salesLineOpenMaterials = await _transformService.BuildSalesLineOpenMaterialFallbackAsync(salesId);
}
var tran = await _transformService.TransformSoToRequestForSql(salesLineOpenMaterials, cusCode);
```

Same fallback method again in both, no new backend logic — both services already had
`IViewCompliancesTransformService` injected. This closes out every user-reachable/scheduled-job
caller of `GetSalesLineOpenMaterialFromDynamics` except the diagnostic-only `ViewCompliancesService.Test`.

## Breaking-change assessment

- No change to the HTTP request/response contract of `get-all` — purely an internal data-source
  substitution for one previously-empty case.
- No change to behavior when the BOM-based lookup already returns data (FR-003, SC-002).
- The only externally observable difference: sales orders that previously returned an empty
  compliance result solely because their BOM had not been created will now return results derived
  from their order lines instead (SC-001). This is the intended fix, not a regression.
