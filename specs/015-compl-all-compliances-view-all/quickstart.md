# Quickstart: All Compliances Sales-Line Fallback for Missing BOM

## Prerequisites

- `compliance-sys-api` runnable locally (or a reachable dev environment) with valid Dynamics 365
  F&O OData credentials configured (`Dynamics:ApiUrl`, etc. — see existing app settings).
- A sales order code (`SalesId`) known to have:
  - zero rows in Dynamics entity `RSVNSalesLineOpenMaterialRvns` for that `SalesId` (no BOM
    created yet), and
  - one or more rows in Dynamics entity `RSVNSalesLineOpenInvoiceCogs` for that `SalesId` (order
    lines exist).
  Use `DynController`'s `GET api/dynamics/sales-line?filter=SalesId eq '<code>'` to confirm the
  second condition ahead of time.

## Automated validation (unit tests)

From `compliance-sys-api/`:

```powershell
dotnet test tests/ComplianceSysApi.UnitTests --filter "FullyQualifiedName~DynamicsDataServiceTests|FullyQualifiedName~ViewCompliancesTransformServiceTests"
```

Expected new/updated cases (see [contracts/sales-line-fallback.md](contracts/sales-line-fallback.md)):

- `GetSalesLineOpenInvoiceCogsFromDynamics` — queries `RSVNSalesLineOpenInvoiceCogs` with
  `SalesId eq '<code>'`, honors cache hit/miss like sibling methods.
- `GetRSVNProductVariantAllsByProductConfigFromDynamics` — builds one
  `(ProductCode eq '...' and ConfigId eq '...')` OR-clause per distinct pair; returns `[]` for an
  empty input list without querying.
- `BuildSalesLineOpenMaterialFallbackAsync`:
  - returns `[]` when the sales-line source itself is empty (FR-009).
  - maps `SalesId`, `ConfigId`, `AreaId`, `CountryRegionId`, `SalesStatus` directly; `ProductCode`
    from `ItemId`; `InterSalesId` as `"cog" + SalesId` (FR-004).
  - fills `ProductType`/`ProductRange` from a matched product-variant-info row, leaves them blank
    when no match exists (FR-005–FR-006).
  - leaves `MaterialCode`, `MaterialName`, `MaterialType`, `CostGroupId`, `ProductGroup` blank
    (FR-007).

## Manual end-to-end validation

1. Call `POST api/view-compliances/get-all?deliveryDate=<date>&cusCode=<customer>` with body
   `[{ "referenceType": 11, "referenceValue": "<sales order code without BOM>" }]`
   (`referenceType: 11` = `SALE_ORDER`, matching `ObjectType.SALE_ORDER` used by
   `ViewCompliancesService.GetViewCompliancesAsync`).
2. **Before this feature**: response is an empty list (or empty-derived result) solely because the
   BOM-based sales-line lookup found nothing.
3. **After this feature**: response reflects compliance results derived from the sales order's
   lines (User Story 1, Acceptance Scenario 1) — non-empty when the order has lines and at least
   one compliance master applies to their product/customer/etc.
4. Repeat with a sales order that already has BOM data (existing `RSVNSalesLineOpenMaterialRvns`
   rows). Confirm the response is byte-for-byte identical to the pre-change behavior (User Story 1,
   Acceptance Scenario 2 / SC-002) — check application logs to confirm the fallback path was not
   invoked (no call to the `sales-line` or `product-variant-info` Dynamics entities for that
   request).
5. Repeat with a sales order that has neither BOM data nor any order line in
   `RSVNSalesLineOpenInvoiceCogs`. Confirm the response is empty, matching today's existing
   "no data" behavior (Acceptance Scenario 6 / FR-009).

## Expected outcome

- Sales orders without a BOM yet, but with order lines, now surface compliance results instead of
  an empty response (SC-001).
- Sales orders with BOM data are completely unaffected (SC-002).
- `InterSalesId`, `ProductType`, and `ProductRange` on fallback-derived rows match the mapping in
  [data-model.md](data-model.md) and [research.md R5](research.md#r5--field-mapping-t2-sales-order-line--t1-sales-line-open-material-per-fr-004fr-007)
  (SC-003, SC-004).
