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

## R7 — `BomStatus` column on `compl_summary_so` (2026-08-20 update, User Story 5)

**Decision**: Add a nullable `VARCHAR` column `BomStatus` to the `compl_summary_so` table via a new
numbered migration file `compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Migration/25_add_bomstatus_to_compl_summary_so.sql`,
following the exact `ALTER TABLE ... ADD COLUMN ...` pattern (with a Vietnamese comment header
citing this feature/update) already used by every prior single-column addition in that folder — e.g.
[`13_add_status_to_eutr_templates.sql`](../../../compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Migration/13_add_status_to_eutr_templates.sql)
and [`20_add_invoice_to_eutr_documents.sql`](../../../compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Migration/20_add_invoice_to_eutr_documents.sql).
Add a matching `public string? BomStatus { get; set; }` property to the
`ComplianceSys.Domain.Entities.ComplSummarySo` entity — no `[Column(...)]` attribute needed since the
property name already matches the new column name (`docs/database/conventions.md` PascalCase
convention), and Dapper (this codebase's data-access technology, no EF Core) maps it automatically
like every other property on that entity.

**Rationale**: This codebase has no EF Core / auto-migration runner — schema changes are hand-written
SQL files, manually applied against the database, with the numbered `Migration/` folder as the
append-only history of ALTERs (confirmed: no `.cs` file references that folder path, and the most
recent file there is `24_fix_compl_master_missing_status_stale_references.sql`, dated 2026-08-19).
This is the only existing convention for adding a column to an existing table, so it is reused as-is
(Principle III).

**Correction**: `Sqls/Tables/compl_summary_so.sql` is *not* dead documentation — 
`DatabaseInitializer.InitTables()` (`compliance-sys-api/src/ComplianceSys.Infrastructure/DatabaseInit/DatabaseInitializer.cs`)
executes every file under `Sqls/Tables/` verbatim, but **only** the first time the app starts against
a database that does not yet exist (`InitializeAsync` short-circuits with "Database already exists,
skipping initialization" otherwise). So this snapshot is what a brand-new environment's schema is
actually built from; `Migration/*.sql` files are never executed by the app (no code references that
folder) and are applied by hand only to already-existing databases. Both must therefore be updated:
the migration file (for existing databases) **and** `Sqls/Tables/compl_summary_so.sql` (so a fresh
database also gets `BomStatus`).

**Pre-existing gap, not touched by this feature**: that snapshot file is already missing several
other columns that exist on the live `ComplSummarySo` entity today (`TotalOverdue`,
`MissingMasterIds`, `OverdueMasterIds`, `ResponsibleEmails`, `AlertEmails`) — evidently added via past
migrations without the snapshot being updated at the time. This feature adds `BomStatus` to the
snapshot (purely additive, does not make the pre-existing gap worse) but does **not** backfill those
other missing columns — that is a separate, pre-existing cleanup outside this feature's scope.

**Value semantics** (spec.md FR-013–FR-015, Assumptions): set to the literal string `"No BOM"` when
`ViewCompliancesSummaryService.GetAndSaveSummarySo`'s own `GetSalesLineOpenMaterialFromDynamics` call
returns zero records for that sales order (the same condition already gating the fallback, R1/FR-011)
— for both the insert path (`newSummarySO`) and the update-existing-record path (`exist`). Left
`null` otherwise; an existing record previously saved as `"No BOM"` is overwritten back to `null` the
next time the job runs and finds BOM data, since the job unconditionally re-sets every field on
`exist` each run (no partial-update logic exists to preserve a stale value).

## R8 — Second `compl_summary_so` writer found (2026-08-20 update, FR-016)

**Decision**: `ViewCompliancesService.GetViewCompliancesAsync` (the User Story 1 "get-all" lookup)
also writes to `compl_summary_so`, but indirectly and via a *different* code path than R7 covers —
after computing its response, it fires `BackgroundJob.Enqueue<IComplSummarySoService>(service =>
service.SaveSummarySo(so.ReferenceValue, tran, deliveryDate, ct))`
([ViewCompliancesService.cs:174-176](../../../compliance-sys-api/src/ComplianceSys.Application/Services/ViewCompliancesService.cs#L174-L176)),
a Hangfire job that runs `ComplSummarySoService.SaveSummarySo`
([ComplSummarySoService.cs:29](../../../compliance-sys-api/src/ComplianceSys.Application/Services/ComplSummarySoService.cs#L29))
— its own independent insert/update into `ComplSummarySo`, separate from `GetAndSaveSummarySo`'s.
Extended `IComplSummarySoService.SaveSummarySo` with a new optional parameter,
`string? bomStatus = null` (placed before the existing optional `CancellationToken ct = default`, so
the one existing caller stays source-compatible aside from the explicit value now passed).
`GetViewCompliancesAsync` computes `bomStatus` the same way as `GetAndSaveSummarySo` (R7) —
`salesLineOpenMaterials.Any() ? null : "No BOM"`, evaluated right after the primary
`GetSalesLineOpenMaterialFromDynamics` call and before the fallback overwrites the list — and passes
it through the `BackgroundJob.Enqueue` call. `SaveSummarySo` sets `BomStatus = bomStatus` on both its
insert (`newSummarySO`) and update-existing (`exist`) paths, mirroring R7.

**Rationale**: This gap was found by explicitly auditing every function in this feature that carries
the "Chưa tạo BOM ... giống GetViewCompliancesAsync" fallback comment
(`GetViewCompliancesAsync`, `TransformSoAsync`, `GetAndSaveSummarySo`,
`GetViewCompliancesForDownloadAsync`, `GetViewCompliancesForSendAlertAsync`) for whether each one also
persists to `compl_summary_so` — user request: "kiểm tra các function có cải thiện logic nếu không
có BOM ... có lưu bảng compl_summary_so thì đều add logic cập nhật BomStatus vào". Of the five,
`GetAndSaveSummarySo` (R7) and `GetViewCompliancesAsync` (this decision) are the only two that
persist anything; the other three only read/return data. An optional parameter with a safe default
(`null`) was chosen over an overload to avoid duplicating `SaveSummarySo`'s body, and keeps the change
additive per Principle III.

**Alternatives considered**: Reusing `GetAndSaveSummarySo`'s BOM-based lookup result instead of
computing `bomStatus` independently in `GetViewCompliancesAsync`. Rejected — the two paths trigger
independently (one on-demand per "get-all" call, one on a schedule/on-demand trigger) and neither
should block on or depend on the other's most recent run; each computes `bomStatus` from its own
fresh `GetSalesLineOpenMaterialFromDynamics` call, consistent with how they already independently
compute their own counts.

## R9 — BOM column on the All Compliances list screen (2026-08-20 update, User Story 6, FR-017–FR-020)

**Decision**: Surface the saved `BomStatus` (R7/R8) as a new "BOM" column on the existing All
Compliances list screen for Sale Order (`compliance-view?ref-type=11&page=1&page-size=50`). Two
small, existing-file changes, no new files beyond what's listed:

1. **Backend DTO**: add `public string? BomStatus { get; set; }` to
   `RSVNSalesOrderOpenInvoiceCogs`
   ([RSVNSalesOrderOpenInvoiceCogs.cs](../../../compliance-sys-api/src/ComplianceSys.Domain/Dynamics/RSVNSalesOrderOpenInvoiceCogs.cs)) —
   this is the exact type `ViewCompliancesController.Get365` returns to the frontend for this screen.
2. **Backend controller**: in `Get365`'s existing per-row enrichment loop
   ([ViewCompliancesController.cs:109-128](../../../compliance-sys-api/src/ComplianceSys.Api/Controllers/ViewCompliancesController.cs#L109-L128)),
   which already copies `TotalCompliances`/`TotalMissing`/`TotalApplied`/`TotalOverdue`/`ResponsibleEmails`/`AlertEmails`
   from the matched `compl_summary_so` row onto `so` (matched by `so.SalesId == summary.SalesOrder`),
   add `so.BomStatus = summary.BomStatus;` in the `if (summary != null)` branch. The `else` branch
   (no matching summary found) is left as-is — `so.BomStatus` stays at its default `null`, matching
   FR-020's "no saved summary record → blank" rule without adding a new line there.
3. **Frontend column**: add one `GridColDef` to
   `useAllCompliancesColumnsSaleOrder`
   ([useAllCompliancesColumnsSaleOrder.jsx](../../../compliance-client/src/presentation/pages/compliance-view/hooks/useAllCompliancesColumnsSaleOrder.jsx)),
   positioned in the `columns` array immediately after the `invoiceDate` block (line ~113) and before
   the `statusForUi` block (line ~115):
   ```jsx
   {
     field: "bomStatus",
     headerName: "BOM",
     width: 90,
     filterable: false,
     renderCell: (params) => (
       <Typography variant="body2">{params.value === "No BOM" ? "Missing" : ""}</Typography>
     ),
   },
   ```
   Also add `bomStatus: true` to `defaultColumnVisibility` (line ~29-36), alongside `invoiceDate`.

**Rationale**: `field: "bomStatus"` (camelCase) matches this API's existing JSON serialization of
every sibling PascalCase C# property on the same row shape (`SalesId` → `params.row.salesId`,
`InvoiceDate` → `params.row.invoiceDate`, etc., confirmed by reading the existing column defs in the
same file) — no explicit `[JsonPropertyName]` needed, consistent with every other field on this DTO.
The `renderCell` mirrors the existing `salesStatus` column's simple conditional-`Typography` pattern
(Principle II) rather than the richer `statusForUi` column's `LinearProgress`/`Tooltip` pattern —
"BOM" only ever needs to show one of two states (`"Missing"` or blank), not a percentage/progress
value, so the simpler pattern is the right fit, not the more complex one.

**File-routing correction**: `compliance-view/index.jsx` (a same-named sibling file) is **not** the
routed component — `RouteResolver.jsx` maps the `compliance-view` route to
`compliance-view/index_new.jsx`. Both files exist in the repo, but only `index_new.jsx` calls
`useAllCompliancesColumnsByType` → `useAllCompliancesColumnsSaleOrder` for `ref-type=11`, confirmed
by reading both files. `useAllCompliancesColumnsSaleOrder.jsx` itself is shared/correct regardless
(only one such hook file exists), so this correction only matters for anyone who might otherwise
edit or test against `index.jsx` expecting to see the change.

**Alternatives considered**: Computing the "No BOM"→"Missing" mapping on the backend (returning an
already-display-ready string, e.g. `DisplayBomStatus`) instead of the raw `BomStatus` value plus a
frontend mapping. Rejected — every other status-like column on this screen (`salesStatus`,
`statusForUi`) already does its display mapping in the frontend column definition from a raw backend
value, so mapping `"No BOM"` → `"Missing"` in `renderCell` is the established, consistent place for
this kind of decision, not the backend (Principle II).
