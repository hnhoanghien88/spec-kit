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

**Added 2026-08-20 (User Story 5, FR-013–FR-015)** — `ViewCompliancesSummaryService.GetAndSaveSummarySo`
also now sets a new field on the record it saves, `BomStatus` (see
[data-model.md](../data-model.md#complsummaryso-compliance-summary-persisted-compl_summary_so-table)
and [research.md R7](../research.md#r7--bomstatus-column-on-compl_summary_so-2026-08-20-update-user-story-5)):

```csharp
var salesLineOpenMaterials = await _dynamicsDataService.GetSalesLineOpenMaterialFromDynamics(salesOrders[i].SalesId);
var bomStatus = salesLineOpenMaterials.Any() ? null : "No BOM";
if (!salesLineOpenMaterials.Any())
{
    salesLineOpenMaterials = await _transformService.BuildSalesLineOpenMaterialFallbackAsync(salesOrders[i].SalesId);
}
var tran = await _transformService.TransformSoToRequestForSql(salesLineOpenMaterials, salesOrders[i].CustAccount);
// ...
newSummarySO.BomStatus = bomStatus;   // insert path
// ...
exist.BomStatus = bomStatus;          // update path
```

`bomStatus` is captured from the *primary* lookup's emptiness (before the fallback runs), matching
FR-014/FR-015's trigger condition exactly — it does not depend on whether the fallback itself found
any sales-order-line rows (FR-009's "fallback also empty" edge case still yields `"No BOM"`, per
spec.md Edge Cases). Both the insert (`newSummarySO`) and update-existing (`exist`) branches set it,
so a previously-`"No BOM"` record is overwritten back to `null` once the sales order's BOM exists.
**Correction (2026-08-20)**: `GetAndSaveSummarySo` is not the *only* writer of `compl_summary_so` —
see the next entry, found by explicitly auditing every fallback-carrying function for whether it also
persists there (`TransformSoAsync`, `GetViewCompliancesForDownloadAsync`, and
`GetViewCompliancesForSendAlertAsync` were checked and confirmed to persist nothing).

**Added 2026-08-20 (second writer, FR-016)** — `ViewCompliancesService.GetViewCompliancesAsync`
(the "get-all" lookup itself, User Story 1) also persists to `compl_summary_so`, indirectly via a
Hangfire background job it enqueues after building its response
([ViewCompliancesService.cs:169-177](../../../compliance-sys-api/src/ComplianceSys.Application/Services/ViewCompliancesService.cs#L169-L177)),
which runs `ComplSummarySoService.SaveSummarySo`
([ComplSummarySoService.cs:29](../../../compliance-sys-api/src/ComplianceSys.Application/Services/ComplSummarySoService.cs#L29)) —
a second, independent insert/update into the same table:

```csharp
// IComplSummarySoService (interface change — new optional parameter, source-compatible with the
// one existing caller):
Task<bool> SaveSummarySo(string salesOrder, IEnumerable<ViewCompliancesRequest> tran,
    DateTime? deliveryDate, string? bomStatus = null, CancellationToken ct = default);

// ViewCompliancesService.GetViewCompliancesAsync — compute bomStatus right after the primary
// (pre-fallback) lookup, same rule as GetAndSaveSummarySo:
salesLineOpenMaterials = await _dynamicsDataService.GetSalesLineOpenMaterialFromDynamics(so.ReferenceValue);
bomStatus = salesLineOpenMaterials.Any() ? null : "No BOM";
if (!salesLineOpenMaterials.Any())
{
    salesLineOpenMaterials = await _transformService.BuildSalesLineOpenMaterialFallbackAsync(so.ReferenceValue);
}
// ...
BackgroundJob.Enqueue<IComplSummarySoService>(service =>
    service.SaveSummarySo(so.ReferenceValue, tran, deliveryDate, bomStatus, ct)
);

// ComplSummarySoService.SaveSummarySo — sets BomStatus on both its insert and update-existing paths,
// mirroring GetAndSaveSummarySo:
newSummarySO.BomStatus = bomStatus;   // insert path
exist.BomStatus = bomStatus;          // update path
```

This writer computes `bomStatus` independently from its own fresh BOM-based lookup — it does not
read or depend on `GetAndSaveSummarySo`'s most recent saved value, and vice versa (spec.md Edge
Cases: last write wins when both run close together for the same sales order, same as every other
field they both save).

## Contract addition: `GET api/view-compliances/get-dynamics` (Get365) — BOM column (2026-08-20, User Story 6)

Endpoint already exists (`ViewCompliancesController.Get365`,
[ViewCompliancesController.cs:60](../../../compliance-sys-api/src/ComplianceSys.Api/Controllers/ViewCompliancesController.cs#L60)),
consumed by the All Compliances list screen for Sale Order
(`compliance-view?ref-type=11&page=1&page-size=50`, `useAllCompliancesData.js` → `allCompliancesApi.get365Paging`).
This feature does not change its route, request shape, or auth policy — only adds one field to the
response row shape for `ref-type=11` (`RSVNSalesOrderOpenInvoiceCogs`) and reads it in the frontend.

**Response field addition**: `BomStatus` (`string?`), enriched per-row the same way
`TotalCompliances`/`TotalMissing`/etc. already are — copied from the matched `compl_summary_so` row
(matched by `SalesId == SalesOrder`), `null` when no match exists (data-model.md
`RSVNSalesOrderOpenInvoiceCogs`, research.md R9). No other reference type's response row shape
changes — `BomStatus` is sales-order-specific.

**Frontend contract**: `useAllCompliancesColumnsSaleOrder` (the column-definition hook selected for
`ref-type=11` by `useAllCompliancesColumnsByType`) gains one `GridColDef` (`field: "bomStatus"`,
`headerName: "BOM"`) positioned between the existing `invoiceDate` and `statusForUi` columns,
rendering `"Missing"` when `row.bomStatus === "No BOM"`, blank otherwise (research.md R9 for the
exact code). No other component changes; `index_new.jsx` (the routed page — see research.md R9's
"File-routing correction") needs no change since it already renders whatever `useAllCompliancesColumnsByType`
returns.

**Breaking-change note**: purely additive response field; no existing consumer of `Get365` reads or
depends on the absence of a `BomStatus` field, so this cannot break any existing caller (SC-010) —
folded into the overall breaking-change assessment below.

## Breaking-change assessment

- No change to the HTTP request/response contract of `get-all` — purely an internal data-source
  substitution for one previously-empty case.
- No change to behavior when the BOM-based lookup already returns data (FR-003, SC-002).
- The only externally observable difference: sales orders that previously returned an empty
  compliance result solely because their BOM had not been created will now return results derived
  from their order lines instead (SC-001). This is the intended fix, not a regression.
- **2026-08-20**: `compl_summary_so` gains a new nullable column (`BomStatus`) — additive schema
  change, no existing column is renamed/removed/retyped, so it does not break any existing reader of
  that table (SC-008).
- **2026-08-20 (second writer)**: `IComplSummarySoService.SaveSummarySo` gains a new optional
  parameter with a safe default (`bomStatus = null`) — its one existing caller
  (`GetViewCompliancesAsync`) is updated to pass a value, but the signature change itself is
  source-compatible with any hypothetical caller that omits it (SC-009).
- **2026-08-20 (User Story 6)**: `Get365`'s response row gains one additive field (`BomStatus`); the
  frontend gains one additive grid column. Neither removes, renames, or retypes anything existing.
