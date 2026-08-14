# Research: EUTR Synchronize Data (Sales Order Template Sync + Purchase-Order Missing-Documentation Alert)

## User Story 1 — Sales Order Template Sync

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

---

## User Story 2 — Purchase-Order Missing-Documentation Alert (research added 2026-08-13)

## R9: Where do "Vendor code" and "Vendor name" come from for a `refType = 15` (Purchase Order) row?

**Decision**: "Vendor code" = `RSVNEutrPurchOrders.OrderAccount` (the D365 vendor account field
already present on the domain model, `ComplianceSys.Domain/Dynamics/RSVNEutrPurchOrders.cs:21`, and
already declared — but currently unpopulated for `refType = 15` — on the shared
`ComplDynReferenceResponseDto.OrderAccount`, `ComplianceSys.Application/Dtos/Response/ComplDynReferenceResponseDto.cs:20`).
Add one line to `MapDynamicsResponse`'s existing `case 15`
(`ComplianceSys.Application/Services/ComplDynamicsService.cs:434-443`): `OrderAccount =
x.OrderAccount`. "Vendor name" has no equivalent field on `RSVNEutrPurchOrders` at all (its `Name`
field is the purchase order's own descriptive name, per feature 004-eutr-documents research.md
Quyết định 9 — it is NOT the vendor's name), so it is resolved via a second, one-time bulk fetch of
`refType = 14` (`VendorsV3`, already registered, `case 14` already maps `Code = VendorAccountNumber`,
`Name = VendorOrganizationName`) at the start of the run, built into an in-memory
`Dictionary<string, string>` (`VendorAccountNumber -> VendorOrganizationName`), looked up per
purchase order by its `OrderAccount` value.

**Rationale**: `refType = 15` already works today (feature 004 registered it for the Assign-condition
"PO" autocomplete) — this is a narrow, additive enrichment of its existing mapping, not a rewrite,
consistent with the same "the DTO already declares the field, case 19 just wasn't populating it yet"
shape as R3 above. A per-row `refType = 14` lookup for every one of >3,000 purchase orders would be
thousands of extra D365 round-trips; one bulk fetch + dictionary lookup mirrors this exact feature's
own R5 decision (User Story 1) and this codebase's established anti-N+1 convention.

**Alternatives considered**: (a) Add a `VendorName` field directly to `RSVNEutrPurchOrders` sourced
from a D365-side join — rejected, would require a D365/OData entity change outside this codebase's
control, and no evidence the D365 entity actually carries it; (b) call `refType = 14` once per
distinct `OrderAccount` instead of once for the whole vendor list — rejected as unnecessary extra
round-trips when the full vendor list is bounded and already paged the same way everywhere else in
this codebase.

## R10: How to resolve, for each purchase order, its template's name/steps/Alert group?

**Decision**: After the full `refType = 15` fetch (R4's paging shape, reused), collect the distinct
non-blank `EutrTemplate` values across all fetched purchase orders and call
`IEutrTemplatesRepository.GetManyByCodesWithDetailsAsync(codes, ct)` (already exists,
`ComplianceSys.Application/Interfaces/Repositories/IEutrTemplatesRepository.cs:18`, already used by
feature 005 for the exact same "batch template+steps lookup by Code" need) **once**, building a
`Dictionary<string, EutrTemplatesResponseDto>` keyed by `Code`. A purchase order's `EutrTemplate`
value that isn't blank but also isn't a key in this dictionary is treated identically to a blank
value — flagged "Missing template id" (spec Edge Case) — since there is no template row to check
steps against either way. `EutrTemplatesResponseDto.AlertFor`/`AlertForName` (existing fields) and
`.Details` (existing, the step tree) are read directly off the same DTO — no separate lookup needed.

**Rationale**: `GetManyByCodesWithDetailsAsync` was purpose-built for exactly this "many templates by
Code, once, with full step details" shape (its own code comment cites feature 005's per-batch
Progress-column need) — reusing it here is a direct Constitution Principle II/III match, and avoids
one `GetByIdWithDetailsAsync` call per purchase order (up to 3,000+ calls) in favor of one query.

**Alternatives considered**: `GetByIdWithDetailsAsync` per distinct template Code — rejected, exactly
the N-round-trip pattern `GetManyByCodesWithDetailsAsync` already exists to avoid.

## R11: How to flatten a template's step tree into the report's "step 1", "step 2", … numbering?

**Decision**: Add one small private helper to the new service (no existing shared helper does this
today — the equivalent tree-walk currently only exists client-side in `TemplateBuilderPage.jsx`) that
takes `EutrTemplatesResponseDto.Details` (a flat list of `EutrTemplateDetailsResponseDto`, each
carrying `Id`/`ParentId`/`DisplayOrder`), and recursively walks it depth-first starting from
`ParentId = 0` (root), at each level ordering siblings by `DisplayOrder` — the same tree shape and
ordering convention the frontend already uses (spec Assumptions: "flattens the full set of steps in
the same order they are configured/displayed in Template Management") — and numbers the flattened
result sequentially starting at 1.

**Rationale**: `EutrTemplateDetails`'s `ParentId`/`DisplayOrder` fields are exactly the fields the
frontend's own reorder/tree logic already relies on (data-model.md of feature 003, Entity 2's
business rules); re-deriving the same order server-side from the same fields is the only way to match
what an admin sees in Template Management, and no existing backend code does this flatten today (it
has never needed to before this feature).

**Alternatives considered**: Number by `eutr_template_details.Id` (insertion order) instead of the
configured tree order — rejected, would not match what's displayed in Template Management and could
silently reorder if a step is edited/moved without being re-inserted.

## R12: How to check "does a SharePoint folder named `{PurchId}` already exist" for >3,000 purchase orders without >3,000 SharePoint calls?

**Decision**: Call `ISharepointService.GetFolders(basePath)` (already exists, already used exactly
this way by `EutrUploadService.ResolveOrCreatePoFolderAsync`,
`ComplianceSys.Application/Services/EutrUploadService.cs:318-331`, where `basePath =
_configuration["SharePointEutrPath"]`) **once** at the start of the run, build a
`HashSet<string>(StringComparer.OrdinalIgnoreCase)` of folder names, and check membership per
purchase order in-memory. Unlike `ResolveOrCreatePoFolderAsync`, this feature never calls
`CreateFolder` — a missing folder is a finding ("Have no PO folder"), not something to fix.

**Rationale**: Same one-bulk-call-then-in-memory-check shape as R5 (User Story 1) and R9/R10 above —
established, repeated pattern in this feature for exactly this "avoid N round-trips over a
>3,000-row loop" problem. Read-only reuse of `ISharepointService.GetFolders` also satisfies
Constitution Principle III without adding any new SharePoint-facing code.

**Alternatives considered**: A "does folder exist" call per purchase order (if the underlying
SharePoint client exposes one) — rejected even if available, for the same N-round-trip reason; also
would diverge from the one already-proven pattern (`GetFolders` + `Any`) this codebase uses for the
identical folder-name check.

## R13: How to determine, per purchase order and template step, whether a document is already recorded — and how to resolve/send per Alert group?

**Decision**: For every purchase order that reaches the step-check stage (has a template match and an
existing folder), collect its `PurchId` into one batch and call
`IEutrReferencesRepository.GetDocumentsByPoCodesAsync(purchIds, ct)` (already exists,
`ComplianceSys.Infrastructure/Repositories/EutrReferencesRepository.cs:47-68`, already used by the
"List PO" grid and the `eutr-sales-orders` Template Checklist for this exact "documents recorded
against these PO codes" need) **once** for the whole batch. Filter the returned rows in-memory to
`RefType == 15` (the "PO" condition type per feature 004 research Quyết định 39/1073 — the same
`refType` numbering this feature's own D365 side also uses for Purchase Orders, though the two `15`s
are unrelated namespaces: one is a D365 `refType`, the other an `eutr_reference_types.Id`), then
build a `HashSet<(string PoCode, long StepId)>` of "already covered" pairs. A template step is
"Missing" for a purchase order when `(PurchId, StepId)` is not in that set.

For Alert-group routing: for every flagged purchase order that resolved to a template (R10), read that
template's `AlertFor` (Id). Group all such purchase orders by distinct `AlertFor` value. For each
distinct group, call `IGroupDetailRepository.GetEmailsByGroupIdsAsync(new[] { alertForId }, ct)`
(already exists, `ComplianceSys.Application/Interfaces/Repositories/IGroupDetailRepository.cs:8`,
the same method used elsewhere for alert/responsible-group email resolution) to get that group's
recipient emails, and send that group's own rows plus every "Missing template id" row from the same
run (spec clarification) as one email with one Excel attachment (R14). A group with zero resolvable
recipient emails is logged and skipped — the run continues with the remaining groups (spec Acceptance
Scenario 10).

**Rationale**: `GetDocumentsByPoCodesAsync` already returns exactly `(PoCode, StepId, RefType, ...)`
rows for a batch of PO codes — no new SQL is needed, only an in-memory `RefType` filter and a
`HashSet` build, avoiding one query per purchase order. `GetEmailsByGroupIdsAsync` already exists for
per-group recipient resolution and is reused as-is rather than reimplementing the
Responsible/Alert-group email join `ComplNotificationService` already has for other alerts.

**Alternatives considered**: A new dedicated "documents by PO+Step" repository method — rejected,
`GetDocumentsByPoCodesAsync` already returns everything needed; adding a narrower method would
duplicate an existing, actively-used query. A single consolidated email to the union of all groups
(mirroring `ComplNotificationService`'s existing sales-order-missing alert pattern) — explicitly
rejected per the `/speckit-specify` clarification in favor of one email per distinct group.

## R14: How to build the per-group Excel attachment and name the file?

**Decision**: Add one small private helper to the new service, structurally identical to
`ComplNotificationService.BuildSalesOrderMissingExcelAttachment`
(`ComplianceSys.Application/Services/ComplNotificationService.cs:423-455`): open a `ClosedXML`
`XLWorkbook`, add one worksheet, write the 5 fixed headers (`Purch id`, `Vendor code`, `Vendor name`,
`Template id`, `Note`) to row 1, then one row per flagged purchase order in that group's (plus
"Missing template id" rows') result set. File name: `eutr-purchase-missing-{groupId}-<yyyyMMddHHmmss>.xlsx`,
timestamped at the moment that group's email is generated — the `{groupId}` segment (distinct from
`compl-sales-order-missing`'s single-file naming, research.md of feature 009) is required here
specifically because one run can produce more than one file (one per distinct Alert group), so a
per-group segment avoids every attachment in the same run colliding on the same timestamp-only name.

**Rationale**: `ClosedXML` is already a proven, working dependency in this exact codebase for
"columns from a dictionary + rows from a dynamic list" Excel generation — reusing the same technique
(Constitution Principle II) avoids introducing a second Excel library or a bespoke writer for 5
columns.

**Alternatives considered**: Reuse `BuildSalesOrderMissingExcelAttachment` itself (not just its
technique) by parameterizing its worksheet title/headers — rejected: that method is `private` to
`ComplNotificationService` and belongs to a different feature/table; duplicating its ~15-line body
into the new service (rather than trying to share the method across two unrelated features/services)
is the smaller, more isolated change and avoids coupling two independent alert features together.

## R15: Paging loop reuse for `refType = 15` and `refType = 14`

**Decision**: Reuse the exact same pagination-loop shape as R4 (User Story 1), once for `refType =
15` (purchase orders) and once for `refType = 14` (vendors, R9) — same `pageSize = 1000`,
`while (true)` + break-on-short-page/`TotalCount` reached convention.

**Rationale**: No reason to invent a second loop shape when R4 already established the correct one
for this exact `GetDynRefePagedAsync` pipeline; consistency also makes the two loops trivially
factorable into one private helper if desired during implementation (not required by this plan).

## R16: Controller/route shape for the second action

**Decision**: Add `[HttpGet("test-purchase-missing")]` as a second action on the **same**
`EutrSynchronizeDataController` (not a new controller) — same `[Authorize]`/`[ApiController]` scope
already on the class, same `ApiResponse<T>.Ok(...)` response-wrapping convention as
`test-so-template-sync`. Returns `ApiResponse<EutrPurchaseMissingSummaryDto>` (new, small response
DTO: total fetched, flagged count, distinct groups notified, success flag, message) — the User
Story 2 analogue of `EutrSynchronizeSummaryDto`.

**Rationale**: Directly requested by the feature description ("thêm controller
[HttpGet("test-purchase-missing")]") — same controller because both actions are manually-triggered
"test" diagnostics under the same `eutr-synchronize-data` feature area, matching
`ComplNotificationController`'s own precedent of hosting multiple unrelated `test-*` actions
(`test-alert`, `test-sales-order-alert`) on one controller.

---

## User Story 2 — Persistence redesign (research added 2026-08-14)

## R17: How should per-run findings be persisted, and how should the per-group emails read them back?

**Decision**: Clone `compl_so_missing`'s (feature 009) entity/repository/orchestration shape exactly,
onto a new table `eutr_purchase_missing` (already created via
`Sqls/Migration/19_create_eutr_purchase_missing.sql` + `Sqls/Tables/eutr_purchase_missing.sql`,
applied to the local dev DB):

- New Domain entity `EutrPurchaseMissing` (`Id`, `PurchId`, `VendorCode`, `VendorName`, `TemplateId`,
  `Note`, `AlertForGroupId`) — no `BaseEntity` audit columns, matching `ComplSoMissing`'s own
  no-audit-columns shape (this table's "current" data is fully replaced every run; there is nothing
  to audit per row).
- New dedicated repository interface `IEutrPurchaseMissingRepository` with exactly three members —
  `DeleteAllAsync(ct)`, `InsertManyAsync(IEnumerable<EutrPurchaseMissing> rows, ct)`,
  `GetAllAsync(ct)` — the same three-member shape as `IComplSoMissingRepository`
  (`ComplianceSys.Application/Interfaces/Repositories/IComplSoMissingRepository.cs`). Unlike
  `ComplSoMissing`, `eutr_purchase_missing` does have a real primary key (`Id`, auto-increment), but
  the access pattern this feature needs is identical (delete-all, per-row insert, select-all) so the
  same minimal three-method interface is used rather than the generic `IRepository<T,TKey>` (which
  has no bulk "delete all" primitive).
- New `EutrPurchaseMissingRepository : DapperRepository<EutrPurchaseMissing, int>` implementing that
  interface with the exact same SQL shape as `ComplSoMissingRepository.cs`: `DELETE FROM
  eutr_purchase_missing` (no `WHERE`), one `INSERT` per row in `InsertManyAsync`'s loop (no bulk/
  multi-row insert), `SELECT * FROM eutr_purchase_missing` for `GetAllAsync`.
- Orchestration in `SendPurchaseMissingAlertAsync` now follows
  `ComplNotificationService.RefreshSalesOrderMissingComplianceAsync` +
  `SendSalesOrderAlertAsync`'s exact call order: `DeleteAllAsync(ct)` once, before the D365 paging
  loop even starts; then, as each purchase order is evaluated and found to have a non-blank Note,
  `InsertManyAsync` (or an equivalent single-row insert reusing the same method) that one row
  immediately rather than accumulating it only in a local list; after every purchase order has been
  evaluated, `GetAllAsync(ct)` once to read back the complete, current store contents, group those
  rows by `AlertForGroupId`, and build/send each group's email/Excel attachment from that read-back
  list (spec FR-020/FR-021/FR-022).

**Rationale**: `compl_so_missing` is the closest possible in-repo precedent for "clear a diagnostic
snapshot table once per run, repopulate it as a source dataset is walked, then read it back to build
an alert" — reusing its exact shape (Constitution Principle II) is far safer than inventing a new
persistence pattern, and the user's request explicitly asked for this same clear-then-populate-
then-read-back behavior.

**Alternatives considered**: (a) Reuse the generic `IRepository<EutrPurchaseMissing,int>` for
`InsertManyAsync`-equivalent work (looping `AddAsync`) and hand-write a one-off `DELETE` via raw
`IUnitOfWork`/`Connection` access from the service itself — rejected: `ComplSoMissingRepository`
already establishes the "small dedicated repository interface, not the generic one" precedent for
exactly this delete-all/insert-many/select-all shape, and duplicating that logic in the service layer
instead of a repository would violate Constitution Principle I's layering. (b) A true SQL bulk
multi-row `INSERT ... VALUES (...), (...), ...` instead of one `INSERT` per row in a loop — rejected
for this update: `ComplSoMissingRepository.InsertManyAsync` itself loops one `INSERT` per row, and
matching that exactly (Principle II) was judged more valuable here than a performance optimization
the existing precedent doesn't also make (row counts here — flagged purchase orders only, not the
full >3,000 population — are expected to be small enough that this is not a bottleneck).
