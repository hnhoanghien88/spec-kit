# Research: Compliance Synchronize Data (Sales Line + Variant Attributes)

All items below were resolved by reading the existing codebase (`compliance-sys-api/`), specifically
`DynController.cs`, `ComplDynamicsService.cs`, `EutrSynchronizeDataService.cs`, and the
`ComplianceSys.Domain/Dynamics/*.cs` entity models — no external/live D365 access was available, so
one item (R3) carries a residual verification step for implementation time.

## R1 — Which existing building blocks does `sales-line` map to?

**Decision**: `DynController.RSVNSalesLineOpenInvoiceCogs` (`[HttpGet("sales-line")]`,
`DynController.cs:718`) queries D365 entity `RSVNSalesLineOpenInvoiceCogs` via
`DynamicsParameterManager.SetEntity(...).AddFilter(filter).SetOrderBy(...).SetPaging(top, skip).BuildUrl()`
+ `IDynamicService.QueryAsync(url)`, returning the raw JSON string. The domain model
`ComplianceSys.Domain.Dynamics.RSVNSalesLineOpenInvoiceCogs` already declares exactly the fields this
feature needs: `SalesId`, `SalesStatus`, `ItemId`, `ConfigId` (plus `InventDimId`, `AreaId`,
`CustName`, `CustAccount`, `WorkerSalesResponsible`, `WorkerSalesTaker`, `CountryRegionId`, unused
here). This confirms the spec's FR-003 field names (Item ID → Product Code, Sales ID, Sales Status)
map 1:1 to real fields, and Config ID is available for the FR-004 join key.

**Rationale**: This entity/endpoint is not registered in `ComplDynamicsService.EntityMappings` (the
`refType`-driven generic reference lookup) — it is a standalone raw endpoint. The new service must
therefore build its own `DynamicsParameterManager` query directly (same technique, not the same call
path) rather than going through `IComplDynamicsService.GetDynRefePagedAsync`.

**Alternatives considered**: Calling `DynController`'s own HTTP endpoint via an internal HTTP client —
rejected; Controllers must stay thin per Constitution Principle I, and every existing sync feature
(011) calls Application/Infrastructure services directly, never its own or another controller over
HTTP.

## R2 — Paging without a total count

**Decision**: Unlike `IComplDynamicsService.GetDynRefePagedAsync` (which calls `.EnableCount()` and
reads `@odata.count`), the raw `sales-line` and `product-variant-attributes` query-building pattern in
`DynController` does **not** enable OData count. Termination must therefore rely solely on
`returned item count < requested page size` (the same fallback condition already used alongside the
total-count check in `EutrSynchronizeDataService.SyncSalesOrderTemplatesAsync`'s
`if (items.Count < PageSize || page * PageSize >= pagedResult.TotalCount)`) — here only the first half
of that condition is available.

**Rationale**: No total-count field exists in the raw D365 JSON returned by these two endpoints today
(no `.EnableCount()` call in their `DynamicsParameterManager` chain); adding one is an unnecessary
`DynController` change when the "short page = last page" heuristic already fully satisfies spec FR-002
(evaluate every page).

**Alternatives considered**: Modify `DynController`'s `sales-line`/`product-variant-attributes` actions
to call `.EnableCount()` too — rejected as an unnecessary, unrequested change to an existing shared
endpoint (Constitution Principle III) when the short-page heuristic already works.

## R3 — Product reference (type 6) field gap: `Range` is not currently mapped, and may not exist on this entity

**Decision**: Extend `ComplDynReferenceResponseDto` with new nullable fields (`ProductCode`,
`ConfigId`, `Description`, `Type`, `Range`) and extend `ComplDynamicsService.MapDynamicsResponse`
`case 6` to populate `ProductCode`/`ConfigId`/`Description` (`ProductDescription`)/`Type`
(`ProductVariantType`) from the existing `RSVNProductVariantAlls` domain model — all three fields
already exist on that model (`ProductVariantAlls.cs:31-38`: `ProductCode`, `ConfigId`,
`ProductVariantType`, `ProductDescription`, `ProductName`). **`Range` has no equivalent property on
`RSVNProductVariantAlls` today** — the only local precedent for a product "Range" column is
`RSVNInventTables.Range` (a *different*, product-level, not variant-level, entity — refType 4, no
`ConfigId`). Add a `Range` property to `RSVNProductVariantAlls` and map it in case 6 on the
assumption that the live D365 `RSVNProductVariantAlls` OData entity exposes a same-named `Range`
field not yet surfaced by this partial local model (D365 custom entities routinely have more columns
than a given local C# projection declares) — **this must be confirmed against the live D365 endpoint/
metadata before or during implementation**; if the field truly does not exist there, `Range` is left
blank for every row, which is already consistent with spec FR-006's "leave blank when unavailable"
behavior and does not block the rest of the feature.

**Rationale**: The user's instruction is explicit and internally consistent on the join key
("type = 6", matched on `ProductCode(t2) = ItemId(t1)` and `ConfigId(t2) = ConfigId(t1)"`) — this
match condition only makes sense against `RSVNProductVariantAlls` (refType 6), since `RSVNInventTables`
(refType 4, the only entity in this codebase with a literal `Range` field) has no `ConfigId` at all and
cannot support the variant-level join the user asked for. Trusting "type = 6" literally, and treating
`Range` as a to-be-confirmed additional field on that same entity, is more consistent with the explicit
instruction than silently switching source entities for one of four requested fields.

**Alternatives considered**:
1. Source `Range` from `RSVNInventTables` (refType 4) instead, alongside Name/Description/Type/etc.
   from refType 6 — rejected: contradicts the user's explicit single-source instruction ("type = 6"),
   and would require a second, differently-keyed (ProductCode-only, no ConfigId) lookup per row purely
   for one field.
2. Drop `Range` from scope entirely — rejected: it is explicitly requested in the spec (FR-005) and in
   the original feature description; the correct resolution is to add the field and verify it against
   the live source, not to silently omit it.

## R4 — Product reference lookup, one call per DISTINCT (ProductCode, ConfigId) combination (superseded — see R10)

**Superseded by R10**: this decision originally called for bulk-fetching all of D365 reference type 6
(`RSVNProductVariantAlls`) once via `IComplDynamicsService.GetDynRefePagedAsync(6, ...)`. Per explicit
follow-up request ("không sử dụng [HttpPost("reference")] 6 nữa" — stop using the generic reference
endpoint with type 6), this is no longer used — see R10 for the replacement design. The core
principle this decision established — avoid one D365 call per raw Sales Line row — still holds and
carries over into R10's design, just via a different mechanism (a dedicated new endpoint, called once
per **distinct** combination instead of a single bulk fetch).

**Original rationale (still valid for why per-row calls are avoided)**: Matches the exact same
performance convention `SendPurchaseMissingAlertAsync` (011 User Story 2) already established for
exactly this situation — bulk-fetching `refType=14`/`15` once into dictionaries instead of querying
per purchase order (explicitly called out in that method's own comments: "tránh gọi riêng cho từng PO
(>3000 dòng)"). Sales Line volumes are of a similar or larger order of magnitude, so calling per raw
row would repeat this same avoided problem.

**Alternatives considered**: One D365 call per raw Sales Line row — rejected (both originally and in
R10's replacement) as an unbounded-N call pattern the codebase has already identified and avoided
elsewhere for this exact class of problem.

## R5 — Variant Attribute lookup (`product-variant-attributes`) stays one call per distinct combination

**Decision**: For Phase 2, call `DynController`'s underlying query pattern for entity
`ProductVariantAttributes` once per distinct `(ProductCode, ConfigId)` combination, with an OData
filter built as `ProductCode eq '{code}' and ConfigId eq '{configId}'` (same filter-string shape as
`sales-line`'s own default `filter` parameter, e.g. `"SalesId eq 'SO58611'"`).

**Rationale**: The user's own description explicitly frames this as a loop — "loop compl_sync_sales_line
lấy Group ra 2 cột ProductCode, ConfigId, rồi kết nối API product-variant-attributes theo lọc Product,
Config" — one call per group, filtered to that exact Product/Config pair, matching spec FR-011 exactly.
The existing batch-OR-filter helper in this codebase (`ComplDynamicsService.GetFromDynamics<T>`) only
supports a single-field IN-style OR filter (e.g. many `Code`s at once), not paired two-field
(ProductCode+ConfigId) batching — extending it to a new two-field-pair batching shape is a bigger,
unrequested change than the straightforward per-combination loop the user described, and combination
counts are expected to be far smaller than raw Sales Line row counts (many rows collapse to few
combinations — spec SC-003), so the per-combination call volume is bounded and reasonable.

**Alternatives considered**: Build a single large OR-filter across all distinct combinations in one
call — rejected as unrequested extra complexity (no existing helper supports paired-field OR-filter
batching) for a call count that is already bounded by the distinct-combination count, not the raw row
count.

## R6 — New tables follow the `compl_so_missing` / `eutr_purchase_missing` clear-then-repopulate shape, not `BaseEntity`

**Decision**: Both `ComplSyncSalesLine` and `ComplSyncVariantAttributes` are plain POCOs — no
`BaseEntity`, but each does carry one plain `CreatedDate` column, matching the real pre-provisioned
schema discovered in R9 — each with an `Id` (`bigint unsigned`, `AUTO_INCREMENT`) primary key,
mirroring `EutrPurchaseMissing`'s shape (has an `Id` PK, unlike `ComplSoMissing` which has none) —
chosen over the no-PK shape because these new tables are freshly-computed synchronization result sets
(not a passthrough of a source table's own natural key), matching `eutr_purchase_missing`'s precedent
more closely than `compl_so_missing`'s. Repository interfaces are narrow
(`DeleteAllAsync`/`InsertManyAsync`/read methods only — not the generic `IRepository<,>`), mirroring
`IComplSoMissingRepository`/`IEutrPurchaseMissingRepository` exactly.

**Rationale**: This shape was explicitly confirmed for this feature via the `/speckit-specify`
clarification (spec.md "Clarification — Run Repeatability"): both stores are cleared and fully
repopulated every run. `docs/database/conventions.md`'s "audit fields required for business entities"
rule is not violated in spirit — this repo already carries two precedented exceptions
(`compl_so_missing`, `eutr_purchase_missing`) for exactly this class of table (fully-replaced-every-run
synchronization snapshots), and this feature's tables are the same class.

**Alternatives considered**: Inherit `BaseEntity` for audit columns — rejected as inconsistent with the
two closest precedents for this exact table shape, and not required by the spec (no requirement to
know who/when triggered a given row — the summary DTO response already answers "did this run succeed
and how much did it process," spec FR-015).

## R7 — Distinct Product/Config combinations are read back from the table, not carried over in memory

**Decision**: `IComplSyncSalesLineRepository` exposes a dedicated
`GetDistinctProductConfigCombinationsAsync(ct)` (`SELECT DISTINCT ProductCode, ConfigId FROM
compl_sync_sales_line WHERE ProductCode <> '' AND ConfigId <> ''` — both columns are `NOT NULL` in the
real schema, R9, so blank means empty string here, not SQL `NULL`) rather than having Phase 2 reuse an
in-memory list accumulated during Phase 1.

**Rationale**: The spec's own User Story 2 "Independent Test" describes seeding
`compl_sync_sales_line` directly and running Phase 2 against that seeded data — this only works if
Phase 2 actually reads from the table rather than from Phase 1's in-memory state. It also matches the
user's literal phrasing ("loop compl_sync_sales_line lấy Group ra 2 cột...") — grouping the table, not
an in-memory collection — and the store is guaranteed identical to Phase 1's in-memory results by that
point anyway (clear-then-repopulate, R6), so there is no correctness difference, only a testability/
decoupling one.

**Alternatives considered**: Reuse Phase 1's in-memory list of successfully-inserted rows directly —
rejected as it would make Phase 2 untestable independent of a live Phase 1 run, contradicting the
spec's own Independent Test description for User Story 2.

## R8 — Response DTO shape

**Decision**: New `ComplSynchronizeDataSummaryDto` (`Application/Dtos/Response/`) with:
`SalesLineFetched`, `SalesLineAdded`, `SalesLineSkipped` (Phase 1 counts — mirrors
`EutrSynchronizeSummaryDto`'s `TotalFetched`/`Added`/`Skipped`), `DistinctProductConfigCount`,
`VariantAttributeAdded` (Phase 2 counts), `Success` (bool), `Message` (string).

**Rationale**: Matches the exact self-describing-response convention already established by all three
existing summary DTOs in `EutrSynchronizeDataService` (`EutrSynchronizeSummaryDto`,
`EutrPurchaseMissingSummaryDto`, `EutrSynchronizeTemplatesSummaryDto`) — satisfies spec FR-015/SC-005
("caller can tell what happened from the response alone").

**Alternatives considered**: Two separate summary DTOs (one per phase) — rejected; the feature is one
triggered action per spec FR-001, so one combined response is more consistent with how the caller
experiences the run.

## R9 — Both tables were already pre-created in the dev DB with a different real schema (discovered during implementation)

**Decision**: During T007/T017 implementation, `SHOW CREATE TABLE` against the local dev DB revealed
`compl_sync_sales_line` and `compl_sync_variant_attributes` already exist (0 rows each) — pre-created
ahead of `/speckit-plan`, the same way `eutr_purchase_missing` was pre-created ahead of `/speckit-plan`
for feature 011. The real schema differs from this document's original (speculative, pre-DB-check)
design in several ways that the implementation now follows instead:

`compl_sync_sales_line` (real): `Id` (bigint unsigned PK), `SalesId` (varchar(50), **nullable**),
`SalesStatus` (**tinyint, NOT NULL** — not the `varchar` originally planned), `ProductCode`
(varchar(50), **NOT NULL**), `ConfigId` (varchar(20), **NOT NULL**), `ProductName` (varchar(250), **NOT
NULL**, not `Name`), `ProductDescription` (varchar(250), **NOT NULL**, not `Description`),
`ProductType` (varchar(100), **NOT NULL**, not `Type`), `ProductRange` (varchar(100), **NOT NULL**,
not `Range`), `CreatedDate` (datetime, NOT NULL — a single audit timestamp, not full `BaseEntity`).

`compl_sync_variant_attributes` (real): `Id` (bigint unsigned PK), `ProductCode` (varchar(50),
nullable), `ConfigId` (varchar(20), NOT NULL), **`GroupId`** (varchar(50), NOT NULL — a column with no
corresponding property on the local `ProductVariantAttributes` domain model before this feature),
`GroupValue` (varchar(50), NOT NULL), `AttributeType` (bigint, NOT NULL), `AttributeTypeName`
(varchar(150), NOT NULL), `AttributeValue` (bigint, NOT NULL), `AttributeValueName` (varchar(150), NOT
NULL), `CreatedDate` (datetime, NOT NULL). **`DistinctProductVariant` and `ProductVariant` — both
present on the `ProductVariantAttributes` domain model and originally planned as stored columns — have
no column in the real table and are not persisted.**

Consequences for the implementation:
- `ComplSyncSalesLine`/`ComplSyncVariantAttributes` entities and their repositories' `INSERT` SQL use
  the real column names/types/nullability, not this document's original table.
- Every NOT NULL `varchar` column that the spec describes as "left blank when unavailable" (FR-006,
  Name/Description/Type/Range; similarly Group/Attribute fields when a D365 field is genuinely absent)
  is populated with an **empty string**, not SQL `NULL`, to satisfy the constraint — "blank" in the
  spec's business language maps to `""` here, not the SQL null the original speculative design assumed.
- `SalesStatus` (`tinyint NOT NULL`) requires a numeric value, but D365's `RSVNSalesLineOpenInvoiceCogs.SalesStatus`
  is declared as a `string` locally, and this codebase's other Sales-Order-shaped entities
  (`RSVNSalesOrderOpenInvoiceCogs.SalesStatus`, used by `ComplDynamicsService` cases 0/11/18) are
  treated as string *labels* (e.g. the `SalesStatus eq Microsoft.Dynamics.DataEntities.SalesStatus'Backorder'`
  filter literal at `ComplDynamicsService.cs:118`). Whether `RSVNSalesLineOpenInvoiceCogs`'s own
  `SalesStatus` actually serializes as a small integer (common for custom RSVN* OData enums) or as a
  string label is **unconfirmed** without live D365 access. The implementation parses it defensively —
  `byte.TryParse(item.SalesStatus, out var code)`, falling back to `0` on failure — so the column is
  always satisfied, but this must be verified against live D365 data (added to T025's verification
  scope, alongside the pre-existing `Range` question).
- A `GroupId` property was added to `ComplianceSys.Domain/Dynamics/ProductVariantAttributes.cs`
  (same treatment as `RSVNProductVariantAlls.Range` in R3 — assumed present on the live D365 entity,
  unconfirmed locally, defaults to blank/empty-string-on-save if actually absent).
- `DistinctProductVariant`/`ProductVariant` are read from the D365 response (already on the domain
  model) but simply not mapped onto `ComplSyncVariantAttributes`, since the real table has no column
  for them — no data is lost from D365's response, it is just not this feature's job to persist those
  two fields locally.

**Rationale**: The real, already-provisioned schema is the actual target the running system must write
to — a document written before that schema existed cannot override what the database actually requires
once discovered. This mirrors 011's own precedent of the implementation deferring to a table the user
had already created ahead of planning.

**Alternatives considered**: `ALTER TABLE` the already-created tables to match this document's original
design — rejected; the tables were deliberately pre-provisioned (by the user or a DB owner) with
specific types/constraints/indexes (e.g. `tinyint` for `SalesStatus`, dedicated `KEY` indexes on
`ProductType`/`ProductRange`/`AttributeType`/`AttributeValue`) that look like informed schema design
choices, not accidental — altering them without being asked risks breaking an intended downstream use
of these columns.

## R10 — Product reference lookup moved to a new dedicated endpoint, one call per distinct combination (supersedes R4)

**Decision**: Per explicit follow-up request ("không sử dụng [HttpPost("reference")] 6 nữa, viết
thêm 1 API trong DynController là [HttpGet("product-variant-info")] tương tự
[HttpGet("product-variant-attributes")]" — stop using the generic reference endpoint with type 6; add
a new `DynController` action `product-variant-info`, shaped like the existing
`product-variant-attributes` action, sourcing `RSVNProductVariantAlls`), Phase 1's Product-reference
enrichment step was redesigned:

1. `DynController` gained `[HttpGet("product-variant-info")]` (skip/top/filter/order_by params,
   `SetEntity("RSVNProductVariantAlls")`, returns raw D365 JSON) — structurally identical to the
   existing `product-variant-attributes`/`sales-line` actions, added right after
   `product-variant-attributes` in the controller.
2. `ComplSynchronizeDataService` no longer depends on `IComplDynamicsService` at all (its only use was
   the now-removed type-6 bulk fetch). It now fetches Sales Line data **first**, derives the distinct
   `(ItemId, ConfigId)` combinations present across the *valid* rows (same FR-007 filter: non-blank
   Item ID and Sales ID), and calls a new private `FetchProductVariantInfoAsync(productCode, configId,
   ct)` once per distinct combination — same technique, same file, same OData filter-building pattern
   as `FetchVariantAttributesAsync` (research.md R5) — deserializing directly into the existing
   `RSVNProductVariantAlls` domain model (`OdataMapper<RSVNProductVariantAlls>`), not into
   `ComplDynReferenceResponseDto`. "First match wins" (spec Assumptions) still applies when a lookup
   returns more than one record: `page?.Items?.FirstOrDefault()`.
3. The additive `ComplDynReferenceResponseDto` fields and `ComplDynamicsService.MapDynamicsResponse`
   `case 6` mapping added for the original R4 design (data-model.md's "Phase 1 — Existing entities
   reused" section) were **reverted** — nothing in the codebase uses `refType = 6` any more, so keeping
   those additive fields would be dead code. The `RSVNProductVariantAlls.Range` property added in R3
   is **kept**, since it is now read directly off the domain model used for deserialization.

**Filter field name — confirmed via `/speckit` clarification**: the user's own example request text
used `"...and Config eq '31631'"`, but `RSVNProductVariantAlls`'s existing C# property (and therefore
the JSON field D365 actually returns, per how `Newtonsoft.Json` deserializes without a `JsonProperty`
override) is `ConfigId`, not `Config`. Asked directly; confirmed to use `ConfigId eq '...'` — matching
the property already established in this codebase over the literal example text, since OData `$filter`
clauses filter against an entity's real field names, which should match the response field names.

**Rationale**: Honors the explicit instruction to stop using the generic reference endpoint for this
lookup, while preserving R4's original goal (never one D365 call per raw Sales Line row) by keying the
new per-combination calls off **distinct** combinations, exactly like Phase 2 (R5) already does for
Variant Attributes — this also happens to avoid over-fetching D365's entire `RSVNProductVariantAlls`
catalog (which the original bulk-fetch design pulled in full, regardless of whether most of it was
even relevant to the Sales Line data in a given run).

**Alternatives considered**:
1. Call `FetchProductVariantInfoAsync` once per raw Sales Line row (not per distinct combination) —
   rejected, reintroduces the exact unbounded-N-calls problem R4/R5 already established as unacceptable.
2. Derive distinct combinations from `compl_sync_sales_line` (the DB table, after Phase 1 inserts) the
   same way Phase 2 does (research.md R7), instead of from the in-memory `salesLines` list before
   inserting — rejected: Phase 1 needs the enrichment data *before* it can build and insert each row,
   so the lookup must happen before (or interleaved with) insertion, not after; Phase 2 can defer to
   the table precisely because its consumers (Variant Attribute lookups) don't feed back into how
   Phase 1's own rows are built.

## R11 — Filter the Sales Line fetch to `SalesStatus = 'Backorder'`; root-caused the "both tables empty" report as an unfiltered-fetch request timeout

**Decision**: `FetchAllSalesLinesAsync`'s OData filter changed from `string.Empty` to
`"SalesStatus eq Microsoft.Dynamics.DataEntities.SalesStatus'Backorder'"` — an explicit follow-up
request. The exact enum-literal syntax (type-qualified `Microsoft.Dynamics.DataEntities.SalesStatus`
prefix, not a plain string comparison) mirrors the filter `ComplDynamicsService.cs:118` already uses
for a different entity's own `SalesStatus` field (`refType = 18`, `RSVNSalesOrderOpenInvoiceCogs`),
confirming `SalesStatus` really is a D365 `Edm.Enum` type on this entity too, not a raw number — this
also means the JSON *response* field is very likely a string label (e.g. `"Backorder"`), not numeric,
reinforcing the residual `SalesStatus` verification already flagged in R9/T025.

**Root cause found for the "runs OK, but both tables end up empty" report**: local log inspection
(`compliance-sys-api/src/ComplianceSys.Api/logs/error/compliance-sys-20260819.log`) of two real test
runs against this endpoint showed both ended in:

```
System.OperationCanceledException: The operation was canceled.
   at System.Threading.CancellationToken.ThrowOperationCanceledException()
   at System.Threading.CancellationToken.ThrowIfCancellationRequested()
   at ComplSynchronizeDataService.FetchAllSalesLinesAsync(...)
   at ComplSynchronizeDataService.RunAsync(...)
```

— thrown from `ct.ThrowIfCancellationRequested()` inside the Sales Line paging loop, **~125–133
seconds** into each run (matching the info log's `responded 200 in 132948 ms` / `125214 ms` — the
controller's `CancellationToken ct` parameter is bound by ASP.NET Core to the HTTP request's own
abort/timeout token, so a request that runs long enough gets cancelled out from under it). Both runs
were made against the **unfiltered** (`filter = ""`) version of `FetchAllSalesLinesAsync` — i.e.
before this same request's filter change — meaning the loop was paging through
`RSVNSalesLineOpenInvoiceCogs` with no scoping at all. That entity is evidently large enough in the
real D365 environment that an unfiltered full-table page-through takes longer than whatever imposes
the ~2-minute cancellation (Kestrel's default request timeout, a reverse proxy, or the calling
browser/client — not confirmed which), so the run always aborts partway through Phase 1's fetch,
**before a single row is ever inserted** — `compl_sync_sales_line`'s `DeleteAllAsync` (FR-008) had
already run and cleared it, but nothing ever go as far as `InsertManyAsync`. The HTTP response itself
still came back `200 OK` (the controller always wraps the summary in `Ok(...)`, regardless of the
summary's own `Success` flag), which is almost certainly why this looked like "ran fine" from the
caller's side — `data.success` in that response body was `false`, with a message describing the Sales
Line fetch failure, but that detail is easy to miss if only the HTTP status is checked.

**Rationale**: Scoping the fetch to `SalesStatus = 'Backorder'` directly addresses the timeout's root
cause by sharply reducing how much data the endpoint has to page through — the same reasoning D365
production entities of this shape are typically queried with *some* status/date scope rather than a
full unfiltered scan, and the existing `sales-line` action's own non-empty default filter parameter
(`"SalesId eq 'SO58611'"`) was itself a hint that this entity isn't meant to be queried unfiltered.

**Follow-up needed**: if the `Backorder`-filtered volume is still large enough to risk hitting the
same ~2-minute cancellation, the next lever is the request/response timeout itself (e.g. a longer
`CancellationToken` timeout configured specifically for this manually-triggered test action) — not
attempted here since the filter change should substantially shrink the dataset first; revisit only if
a real run against the new filter still times out. Separately: **the currently-running dev server
process was serving a build from before this fix** (confirmed via the log's `Dynamics Filter String:`
empty-filter entries, which only come from the pre-`product-variant-info`-refactor code path, and via
`FetchAllSalesLinesAsync`'s own empty filter in the timeout stack traces) — it must be rebuilt and
restarted before re-testing, or the fix won't be observed.

## R12 — `SalesStatus` corrected to `string`; `ProductVariantAlls.Range`/`ProductVariantType` corrected to real field names `ProductRange`/`ProductType` (confirmed against live D365 data)

**Decision**: After R11's filter fix let a real run reach D365, the user tested against the running
dev server and confirmed, from actual response data: `SalesStatus` returns enum **labels**
(`"Invoiced"`, `"Backorder"`, ...) as expected from R11's reasoning, and `RSVNProductVariantAlls`'s
real field names for the "type" and "range" values are `ProductType` and `ProductRange` — **not**
`ProductVariantType`/`Range`, which were this feature's original (unconfirmed) guesses (R3). The user
applied the following directly: renamed `RSVNProductVariantAlls.Range` → `ProductRange` and added a
new `ProductType` property (`ProductVariantType` is kept — unused by this feature now, but not
removed, since some other current/future caller could still rely on it); changed the live DB
`compl_sync_sales_line.SalesStatus` column from `tinyint` to `varchar(50)`. This request's follow-up
work brought the rest of the codebase into sync with those two confirmed facts:

- `ComplSyncSalesLine.SalesStatus`: `byte` → `string` (default `""`, matching the NOT NULL `varchar`
  column).
- `ComplSynchronizeDataService`: the `byte.TryParse(item.SalesStatus, ...)` defensive-parse (R9) is
  gone — `SalesStatus` is now copied directly (`item.SalesStatus ?? string.Empty`), and the
  `ProductType`/`ProductRange` row fields now read `matched?.ProductType`/`matched?.ProductRange`
  (was `matched?.ProductVariantType`/`matched?.Range`).
- `Sqls/Migration/22_create_compl_sync_sales_line.sql` and `Sqls/Tables/compl_sync_sales_line.sql`:
  `SalesStatus tinyint NOT NULL` → `SalesStatus varchar(50) NOT NULL`, to match the live DB (which the
  user had already altered directly) and keep a fresh-DB bootstrap producing the same schema.

**Root cause of the "`SalesStatus` shows `0` for every row" symptom observed in the live data** (10
rows already synced by the time of this request, confirmed via `SELECT ... FROM compl_sync_sales_line`):
the DB column had been widened to `varchar(50)` already, but the C# service was still running the old
`byte.TryParse` logic — parsing a label like `"Backorder"` as a number always fails, silently
defaulting to `0` (not an error, so nothing surfaced this until the actual column values were
inspected). Widening the column alone doesn't fix a producer that's still emitting the wrong value;
both sides needed to change together, which is what this correction does.

**Residual note**: the same 10 already-synced rows show `ProductRange` blank for every row. This may
be genuinely blank in D365 for those specific products, or may indicate the `ProductRange` rename
still isn't the exactly-right field — inconclusive from this sample alone. Folded into T025's existing
D365-field-verification scope (alongside the already-flagged `GroupId` question) rather than treated
as a new confirmed bug.

**Rationale**: Live D365 response data is strictly more authoritative than this feature's original,
pre-D365-access guesses (R3/R9) — once real data contradicts an assumption, the assumption loses,
consistent with how this feature has already treated every previous live-data correction this session
(R9's schema discovery, R10's endpoint switch, R11's filter/timeout diagnosis).

**Alternatives considered**: Keep `SalesStatus` as `byte`/`tinyint` and add a label→code lookup table
— rejected; no such mapping was requested or exists anywhere in this codebase, and D365's own field is
evidently string-typed at the source, so storing the label as-is is the more direct, lower-maintenance
choice.
