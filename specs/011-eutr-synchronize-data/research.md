# Research: EUTR Synchronize Data (Sales Order Template Sync)

## R1: Where does the "call DynController's reference/type=19 API" requirement actually resolve to?

**Decision**: Inject `IComplDynamicsService` directly into the new service and call
`GetDynRefePagedAsync(19, request, ct)` in-process. Do **not** issue an HTTP call from the new
controller/service to `DynController`'s `POST /api/dynamics/reference` endpoint.

**Rationale**: `DynController.ReferenceData` (`[HttpPost("reference")]`,
`compliance-sys-api/src/ComplianceSys.Api/Controllers/DynController.cs:43-83`) is itself a thin
pass-through to `IComplDynamicsService.GetDynRefePagedAsync(refType, request, ct)`. Every existing
backend consumer that needs "reference type N data" from another server-side feature calls this
service directly rather than looping back through its own HTTP API — see
`ComplNotificationService.RefreshSalesOrderMissingComplianceAsync` (refType 18) and
`EutrTemplateReferencesService.GetByTemplateIdAsync` (via `GetFromDynamics`, refType 14). Calling
back into the same process over HTTP would add latency, a second auth hop, and no benefit.
Constitution Principle III (Reuse Existing Backend) favors reusing the existing service method.

**Alternatives considered**: A literal loopback `HttpClient` call to
`POST /api/dynamics/reference?refType=19` — rejected as an anti-pattern already avoided everywhere
else in this codebase for this exact kind of internal reference lookup.

## R2: Does `refType = 19` actually return data today?

**Decision**: No — it currently always returns an empty result, and this feature must fix that as
a verified gap before the sync can work at all.

**Rationale**: `GetDynRefePagedAsync` short-circuits to `Items = [], TotalCount = 0` whenever
`EntityMappings.TryGetValue(refType, ...)` fails
(`ComplianceSys.Application/Services/ComplDynamicsService.cs:68-75`). The `EntityMappings`
dictionary (lines 27-49) currently has entries for `0,1,2,3,4,5,6,7,8,9,10,11,12,14,15,16,18` but
**not `19`**. Meanwhile, `MapDynamicsResponse`'s `case 19` (lines 463-472) already contains working
mapping logic for `RSVNEutrSalesOrderTemplates` (the exact D365 entity the spec's `InterCompanyOriginalSalesId`
/ `RSVNRefPurchId` / `RSVNEutrTemplate` fields come from — confirmed against
`ComplianceSys.Domain/Dynamics/RSVNEutrSalesOrderTemplates.cs`), but that branch is unreachable
because the method returns before ever reaching the switch. This is the identical class of bug
already fixed once in this codebase for `refType = 18` (feature `009-compl-sales-order-missing`,
`tasks.md` T007): a switch-case existed but the entity was missing from `EntityMappings`, so the
whole reference type was silently dead.

**Fix required** (small, additive, no consumer currently depends on the old dead behavior since it
never returned data): add to `EntityMappings`:
```csharp
{ 19, ("RSVNEutrSalesOrderTemplates", "InterCompanyOriginalSalesId", "RSVNEutrTemplate") }
```
`CodeColumn`/`NameColumn` chosen to match the existing (already-present) `MapSortColumn` entries for
`"RSVNEutrSalesOrderTemplates"` (lines 274-275), which expect `InterCompanyOriginalSalesId` for
`code`/`id` sorting and `RSVNEutrTemplate` for `name` sorting.

**Alternatives considered**: Bypass `ComplDynamicsService` entirely and query D365 through a new,
parallel code path dedicated to this sync — rejected: duplicates working logic
(`BuildFilterString`, paging, OData URL building) that already exists and is exercised by other
reference types, for no benefit, and diverges from Constitution Principle III.

## R3: How should the DTO fields be read for `refType = 19`?

**Decision**: `MapDynamicsResponse`'s existing `case 19` maps
`Id = InterCompanyOriginalSalesId`, `Code = RSVNEutrTemplate`, `Name = RSVNRefPurchId` onto the
shared `ComplDynReferenceResponseDto` — instead of the DTO's dedicated named properties
(`InterCompanyOriginalSalesId`, `EutrTemplate`, `RSVNRefPurchId`) that `case 16` and `case 20` use
for the same underlying D365 fields. Since `refType = 19` has zero real consumers today (R2 — it
has never returned data), this feature also updates `case 19` to additionally populate those three
named properties, so the new sync service (and any future caller) can read
`item.InterCompanyOriginalSalesId` / `item.RSVNRefPurchId` / `item.EutrTemplate` directly instead of
the ambiguous `Id`/`Code`/`Name` triple. `Id`/`Code`/`Name` are left populated as-is for backward
compatibility with the (currently nonexistent) generic reference-picker usage pattern other
`refType`s rely on.

**Rationale**: Matches the sibling case 16 (`RSVNEutrSalesOrderPurchases`) and case 20
(`RSVNEutrSalesOrderPurchLines`) mapping style already in the same switch, and removes the need for
the new sync service to carry a comment explaining the `Id`/`Code`/`Name` remapping trick.

## R4: How to fetch "the full dataset" instead of one page?

**Decision**: Reuse the exact pagination-loop shape already used in
`ComplNotificationService.RefreshSalesOrderMissingComplianceAsync`
(`ComplianceSys.Application/Services/ComplNotificationService.cs:229-284`):

```csharp
const int pageSize = 1000;
var page = 1;
while (true)
{
    var pagedRequest = new PagedRequest { Page = page, PageSize = pageSize, Filters = [] };
    var result = await _complDynamicsService.GetDynRefePagedAsync(19, pagedRequest, ct);
    var items = result.Items?.ToList() ?? [];
    if (items.Count == 0) break;
    // ... process items ...
    if (items.Count < pageSize || page * pageSize >= result.TotalCount) break;
    page++;
}
```

**Rationale**: Same paged reference source (`GetDynRefePagedAsync`), same need to exhaust every
page rather than the first one — no reason to invent a different loop shape.

## R5: How to detect "SalesId already exists" without one DB round-trip per record?

**Decision**: At the start of a sync run, call the existing
`IEutrPurchaseAttachmentsRepository.GetSalesIdsWithTemplateAsync()`
(`ComplianceSys.Application/Interfaces/Repositories/IEutrPurchaseAttachmentsRepository.cs:36-40`,
already implemented in `EutrPurchaseAttachmentsRepository.cs:93-106`) once, and load the result into
an in-memory `HashSet<string>`. For each candidate record fetched from Dynamics, check membership
in that set before inserting; on insert, add the new `SalesId` to the same set immediately. This
also naturally satisfies spec Edge Case 1 (two records for the same `SalesId` within one run — the
second is skipped because the first insert already added that `SalesId` to the in-memory set,
without needing a fresh DB query).

**Rationale**: `GetSalesIdsWithTemplateAsync` already returns "every distinct `SalesId` currently in
`eutr_purchase_attachments`" (its `WHERE TemplateCode IS NOT NULL` filter is a no-op today since the
column is `NOT NULL`, per its own code comment) — exactly the existence set this feature needs, with
zero new repository code. Checking per-row against the database (`SELECT 1 WHERE SalesId = ...` for
every one of potentially thousands of Dynamics rows) would be far slower and is not how any existing
bulk sync in this codebase behaves.

**Alternatives considered**: A new `ExistsBySalesIdAsync(string)` repository method queried per row —
rejected as unnecessary N-round-trip overhead when the existing bulk method already covers the need
in one query.

## R6: How to persist new rows?

**Decision**: Reuse the existing generic write path, `IRepository<EutrPurchaseAttachments, int>.AddAsync(entity, ct)` —
the same one `EutrPurchaseAttachmentsService.SavePoMappingAsync` already uses
(`ComplianceSys.Application/Services/EutrPurchaseAttachmentsService.cs:63-76`) — one `AddAsync` call
per new mapping row, no transaction wrapping the whole run (see R7).

**Rationale**: No entity/schema change is needed; `EutrPurchaseAttachments` already has `SalesId`,
`PurchId`, `TemplateCode`, `CreatedBy`, `CreatedDate`, `UpdatedBy`, `UpdatedDate` — exactly what the
spec asks to populate.

## R7: Transaction and error-handling shape for the run

**Decision**: No single transaction wraps the entire run. Each accepted record is inserted with its
own `AddAsync` call. If the Dynamics fetch itself fails (network/API error) for any page, the run
stops immediately and reports failure (per spec Edge Case: "the run stops and reports failure;
records already added before the failure remain"). If an individual row fails to insert (e.g. an
unexpected constraint violation), that row is logged and skipped, and the run continues with the
remaining rows — mirroring the per-item `try/catch` + `continue` shape in
`RefreshSalesOrderMissingComplianceAsync` (lines 254-276), rather than aborting the whole run over
one bad row.

**Rationale**: `SavePoMappingAsync`'s single transaction exists because it does a delete-then-insert
*replace* that must be atomic. This sync has no such all-or-nothing requirement — the spec explicitly
allows partial progress on failure — so wrapping thousands of independent inserts in one transaction
would only add lock/log overhead without a correctness benefit, and would contradict the spec's
"records already added before the failure remain" behavior if the whole batch were rolled back.

## R8: Controller/route shape

**Decision**: New controller `EutrSynchronizeDataController` at `[Route("api/eutr-synchronize-data")]`,
`[Authorize]`, `[ApiController]` — same attribute shape as `ComplNotificationController`. Single
action `[HttpGet("test-so-template-sync")]` returning `ApiResponse<EutrSynchronizeSummaryDto>` (new,
small response DTO: fetched/added/skipped counts + success flag), matching the `ApiResponse<T>.Ok(...)`
pattern used by every action in `ComplNotificationController` (e.g. `TestAlert`, `TestSalesOrderAlert`).

**Rationale**: Directly requested by the feature description ("viết chức năng
EutrSynchronizeDataController tham khảo ComplNotificationController"); kebab-case route matches the
constitution's API routing convention (`api/eutr-steps`-style).
