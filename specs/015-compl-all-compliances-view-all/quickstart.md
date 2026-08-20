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

## Additional validation (2026-08-20, User Story 5 — `BomStatus`)

Prerequisite: migration `Sqls/Migration/25_add_bomstatus_to_compl_summary_so.sql` has been applied
to the target database (adds `compl_summary_so.BomStatus`).

1. Trigger the compliance-summary job (`GetAndSaveSummarySo`, e.g. via its Hangfire trigger or
   directly) for a sales order with no BOM yet but with order lines (same sales order used above).
2. Query `compl_summary_so` for that sales order. Confirm `BomStatus = 'No BOM'`.
3. Repeat for a sales order that already has BOM data. Confirm its saved row's `BomStatus` is `NULL`
   (or unchanged from before this feature, if it never had the fallback triggered).
4. If BOM data is subsequently created for the sales order from step 1–2 and the job is re-run,
   confirm its saved row's `BomStatus` reverts to `NULL` (FR-015, Acceptance Scenario 3).

## Additional validation (2026-08-20, second writer — `GetViewCompliancesAsync`'s background save, FR-016)

5. Call `POST api/view-compliances/get-all` (as in the main manual validation above, step 1) for a
   sales order with no BOM yet but with order lines. This enqueues a background job
   (`ComplSummarySoService.SaveSummarySo`) independently of the summary job above.
6. After the background job completes (check Hangfire dashboard/logs, or allow a few seconds), query
   `compl_summary_so` for that sales order. Confirm `BomStatus = 'No BOM'` — set by this path, not by
   the summary job in step 1–2 above.
7. Repeat with a sales order that already has BOM data via the same `get-all` call. Confirm its saved
   row's `BomStatus` is `NULL`.

## Additional validation (2026-08-20, User Story 6 — BOM column on the list screen)

Prerequisite: at least one sales order in `compl_summary_so` with `BomStatus = 'No BOM'` and at least
one with `BomStatus IS NULL` (e.g. from the validations above), both also present in Dynamics
`RSVNSalesOrderOpenInvoiceCogs` (so they appear on the list screen's underlying data source).

1. Open `compliance-view?ref-type=11&page=1&page-size=50` in the browser (or call
   `GET api/view-compliances/get-dynamics?refType=11&page=1&pageSize=50` directly).
2. Confirm a "BOM" column is visible immediately after "Invoice date" and before "Status".
3. Find the row for the sales order with `BomStatus = 'No BOM'`. Confirm its BOM column shows
   "Missing".
4. Find the row for the sales order with `BomStatus IS NULL` (or one with no `compl_summary_so`
   record at all). Confirm its BOM column is blank.

## Expected outcome

- Sales orders without a BOM yet, but with order lines, now surface compliance results instead of
  an empty response (SC-001).
- Sales orders with BOM data are completely unaffected (SC-002).
- `InterSalesId`, `ProductType`, and `ProductRange` on fallback-derived rows match the mapping in
  [data-model.md](data-model.md) and [research.md R5](research.md#r5--field-mapping-t2-sales-order-line--t1-sales-line-open-material-per-fr-004fr-007)
  (SC-003, SC-004).
- Saved compliance summaries (`compl_summary_so`) correctly flag which sales orders were computed
  via the fallback: `BomStatus = 'No BOM'` if and only if the job's BOM-based lookup returned zero
  records for that sales order (SC-008) — true for both writers, the summary job and the "get-all"
  lookup's own background save (SC-009).
- The All Compliances list screen for Sale Order shows a "BOM" column that surfaces this saved value
  at a glance — "Missing" for `BomStatus = 'No BOM'`, blank otherwise (SC-010).
