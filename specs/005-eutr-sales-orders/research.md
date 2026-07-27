# Phase 0 Research: EUTR Sales Orders Management

All unknowns below were resolved by reading the existing codebase; there is no remaining
`NEEDS CLARIFICATION` in Technical Context.

## Decision 1 — Which reference type / entity backs `refType = 11`

- **Decision**: Register `{ (int)ObjectType.SALE_ORDER, ("RSVNSalesOrderOpenInvoiceCogs", "SalesId",
  "CustName") }` in `ComplDynamicsService.EntityMappings` (`compliance-sys-api/src/
  ComplianceSys.Application/Services/ComplDynamicsService.cs`).
- **Rationale**:
  - `ObjectType.SALE_ORDER = 11` is already defined in `ComplianceSys.Application/Constants/
    ComplEnum.cs` and already treated as "Sales order" elsewhere in the codebase (e.g.
    `compliance-client/.../compliance-view-so/index.jsx`: `isSalesOrderRefType = refType === "11"`).
    Using `11` for Sales Orders here is not a new convention — it is filling a gap in a mapping the
    rest of the codebase already assumes exists.
  - `RSVNSalesOrderOpenInvoiceCogs` (`compliance-sys-api/src/ComplianceSys.Domain/Dynamics/
    RSVNSalesOrderOpenInvoiceCogs.cs`) declares `ModelType => 11` and already has every field the
    spec needs: `SalesId`, `CustAccount`, `CustName`, `DeliveryDate`.
  - Today this entity is registered in `EntityMappings` only under the unrelated raw key `0`
    (`{ 0, ("RSVNSalesOrderOpenInvoiceCogs", "SalesId", "CustName") }`), which is not wired to
    `ObjectType.SALE_ORDER` and is not what the spec's `reftype = 11` refers to. `refType = 11`
    itself is currently **absent** from the dictionary, so `GetDynRefePagedAsync` short-circuits to
    an empty result for it today (see `EntityMappings.TryGetValue` check).
- **Alternatives considered**:
  - *Reuse `refType = 0` instead of registering `11`*: rejected — contradicts the feature's explicit
    requirement (`reftype = 11`) and the already-established meaning of `11` elsewhere in the
    codebase; would leave `11` still broken for any other future consumer expecting `SALE_ORDER`.
  - *New dedicated endpoint (e.g. `GET /api/dynamics/sales-orders`)*: rejected — violates
    Constitution Principle III (reuse existing backend) and Principle II (reference-pattern reuse);
    the generic reference endpoint already exists and just needs its mapping table extended, exactly
    like `refType=15`/`16` were added for feature `004-eutr-documents`.
  - *New D365 domain entity class*: rejected — `RSVNSalesOrderOpenInvoiceCogs` already has all
    required fields; no new entity needed.

## Decision 2 — How to surface 4 distinct fields through a 3-field generic DTO

- **Decision**: Extend `ComplDynReferenceResponseDto` (`compliance-sys-api/src/
  ComplianceSys.Application/Dtos/Response/ComplDynReferenceResponseDto.cs`) with two new **nullable**
  fields, e.g. `CustAccount` and `DeliveryDate`, populated only by the new `case 11` branch of
  `MapDynamicsResponse`; `Id`/`Code` continue to carry `SalesId`, `Name` continues to carry
  `CustName` (matching the `EntityMappings` `CodeColumn`/`NameColumn` tuple, so search-by-code/name
  filtering — already generic in `BuildFilterString` — keeps working unmodified).
- **Rationale**: The DTO is shared by every `refType`; adding new nullable fields is additive and
  backward compatible — all other `refType`s (customers, vendors, products, …) simply leave them
  `null`, matching Constitution Principle III (extend, don't rewrite, a verified gap only).
  `useReferenceObjects.js` (frontend) already passes through whatever JSON fields the backend sends
  (`response?.data?.items`, no field whitelist), so no frontend infrastructure change is required to
  carry the two new fields end to end.
- **Alternatives considered**:
  - *A refType-specific sibling DTO (e.g. `SalesOrderReferenceResponseDto`)*: rejected — the paging/
    filter/mapping pipeline (`GetDynRefePagedAsync`) is generically typed to
    `PagedResult<ComplDynReferenceResponseDto>`; branching the return type per `refType` would touch
    significantly more code for no behavioral gain at this feature's scope.
  - *Encode extra data into `Code`/`Name` (e.g. composite strings)*: rejected — would break the
    existing generic filter-by-code/name logic and require ad-hoc parsing on the frontend.

## Decision 3 — Frontend data source for `SalesOrderOverviewPage.jsx`

- **Decision**: Replace the `MOCK_SALES_ORDERS` array (from `./mock/eutrSalesOrders.js`) with a fetch
  through the already-generic `GetReferenceDataUseCase` (`compliance-client/src/application/
  usecases/dynamics/index.js`) using a local `EUTR_SALES_ORDER_REF_TYPE = 11` constant, following the
  exact pattern already used in `EutrDocumentsAdd.jsx` (`EUTR_PURCH_ORDER_REF_TYPE = 15` +
  `fetchPoList`). Either call the use case directly (page needs the full list, not the 20-per-page
  autocomplete slice `useReferenceObjects` defaults to) or call `useReferenceObjects` with an
  explicit larger `pageSize` — decide in `data-model.md` per the grid's own pagination needs (spec
  FR-010).
- **Rationale**: No new repository/use case/DI wiring needed — everything already exists and is
  refType-agnostic.
- **Alternatives considered**:
  - *New dedicated frontend hook (`useSalesOrders`)*: rejected as unnecessary — `useReferenceObjects`
    (or a direct `GetReferenceDataUseCase.execute` call) already covers pagination, search-filter
    payload shape, and loading/error state.

## Decision 4 — Template / Progress columns (SUPERSEDED — see Decisions 5-8 below)

> **Superseded by spec Update 1 (2026-07-16)**: Template is no longer a fixed demo value; it now
> reads real data from `eutr_purchase_attachments`. This decision record is kept for history.
> Progress is unaffected and stays exactly as decided here.

- **Decision**: Replace the current mock-driven computation (`EUTR_TEMPLATES.find(...)`,
  `computeProgress()` reading `EUTR_TEMPLATE_DETAILS_MAP`/`MOCK_FILE_MAPPINGS`) with a fixed, static
  demo value rendered identically on every row (e.g. a constant label and a constant percentage),
  per spec FR-007/FR-008 ("cố định dữ liệu demo").
- **Rationale**: The spec explicitly asks for these two columns to be frozen placeholders, not
  business logic, until a future feature defines them for real. Keeping the mock-lookup computation
  would still depend on `MOCK_SALES_ORDERS`-shaped `templateId`/`salesId` keys that won't exist once
  real Sales Order rows (keyed by D365 `SalesId`) replace the mock rows — those mock lookups would
  silently return empty/zero, so removing them (rather than leaving dead code) is the accurate
  representation of "fixed demo".
- **Alternatives considered**:
  - *Keep computing per-row progress from `EUTR_TEMPLATE_DETAILS_MAP` keyed by mock `templateId`*:
    rejected — spec explicitly calls for fixed demo values, and the mock keys don't correspond to
    real Sales Orders, so the computation would be meaningless once real data replaces the mock rows.
- **Current status (Progress only)**: Progress keeps this exact decision — still a fixed demo value,
  per spec Update 1's explicit note that Progress is out of scope for the Template change.

## Decision 5 — Backend read path for the Template column (`eutr_purchase_attachments`)

- **Decision**: `eutr_purchase_attachments` has **zero existing backend surface** (verified: no
  entity, repository, service, or controller anywhere in `compliance-sys-api` references this table
  or `PurchId`+`TemplateCode` together — confirmed by a full-repo search). This is a genuinely new,
  small read capability, built by cloning the closest same-shape existing feature end to end:
  `EutrTemplates` (`compliance-sys-api/src/ComplianceSys.{Domain,Application,Infrastructure,Api}`).
  New files:
  - `ComplianceSys.Domain/Entities/EutrPurchaseAttachments.cs` — POCO, `[Table("eutr_purchase_attachments")]`,
    `EutrPurchaseAttachments : BaseEntity` (audit fields inherited), `Id` (`int`, matches the table's
    `INT UNSIGNED` PK — note this differs from `EutrTemplates.Id` which is `long`/`BIGINT UNSIGNED`),
    `SalesId`, `PurchId`, `TemplateCode` (all `string`).
  - `ComplianceSys.Application/Interfaces/Repositories/IEutrPurchaseAttachmentsRepository.cs` — a
    **standalone** custom-query interface (does NOT extend generic `IRepository<,>`), matching the
    established precedent of `IEutrReferencesRepository`/`IEutrReferenceDetailsRepository` (read-only
    JOIN-query repositories in this same codebase that also don't extend the generic interface,
    since nothing in this feature needs generic Create/Update/Delete on this table): one method,
    `Task<List<SalesOrderTemplateDto>> GetTemplatesBySalesIdsAsync(IEnumerable<string> salesIds, CancellationToken ct = default)`.
  - `ComplianceSys.Infrastructure/Repositories/EutrPurchaseAttachmentsRepository.cs` extends
    `DapperRepository<EutrPurchaseAttachments, int>` (for the shared `Connection`/`Transaction`
    accessors, same as `EutrReferencesRepository` does) and implements
    `IEutrPurchaseAttachmentsRepository`, implementing that method (see Decision 6 for the query).
  - `ComplianceSys.Application/Dtos/Response/SalesOrderTemplateDto.cs` — new, flat: `SalesId`,
    `TemplateCode`, `TemplateName` (all `string`).
  - `ComplianceSys.Application/Interfaces/Services/IEutrPurchaseAttachmentsService.cs` +
    `ComplianceSys.Application/Services/EutrPurchaseAttachmentsService.cs` — a standalone service
    (does NOT extend `BaseService`/`IBaseService`, matching the precedent of other non-full-CRUD
    services in this codebase such as `EutrConditionAssignmentService`) with thin pass-through to the
    repository (same shape as `EutrTemplatesService`'s simplest methods).
  - `ComplianceSys.Api/Controllers/EutrPurchaseAttachmentsController.cs` — new controller,
    `[Authorize] [Route("api/eutr-purchase-attachments")]`, one action:
    `[Authorize(Policy = "EutrPurchaseAttachments.Read")] [HttpPost("by-sales-ids")]` accepting
    `[FromBody] List<string> salesIds`, returning `ApiResponse<List<SalesOrderTemplateDto>>`.
  - DI: register `IEutrPurchaseAttachmentsService`/`EutrPurchaseAttachmentsService` in
    `ComplianceSys.Application/DependencyInjection.cs` and
    `IEutrPurchaseAttachmentsRepository`/`EutrPurchaseAttachmentsRepository` in
    `ComplianceSys.Infrastructure/DependencyInjection.cs` (same lines pattern as the existing
    `EutrTemplates*` registrations).
- **Rationale**: Constitution Principle III requires reusing backend that **already exists**; it does
  not forbid building backend for a verified, currently-nonexistent capability — and Principle II
  requires modeling new features on an existing same-shape feature rather than inventing structure.
  `EutrTemplates` is the closest analog: a simple MySQL-backed, Dapper-accessed, FK-related-to-templates
  table exposed through the standard 4-layer stack.
- **Alternatives considered**:
  - *Extend `DynController`/`ComplDynamicsService` (the D365 reference proxy) to also read this MySQL
    table*: rejected — that controller/service is specifically for the D365 OData-backed reference
    lookup (`IDynamicService`); `eutr_purchase_attachments` is a local MySQL table with a completely
    different access path (Dapper via `IUnitOfWork`), so shoehorning it in would blur an established,
    working abstraction boundary for no benefit.
  - *Add the query directly onto `EutrTemplatesController`/`EutrTemplatesService`* (since it joins to
    `eutr_templates`): rejected — `eutr_purchase_attachments` is a distinct entity/table with its own
    identity (`SalesId`+`PurchId`+`TemplateCode`), not a sub-resource of templates; a dedicated
    controller keeps resource boundaries aligned with the DB schema, matching how every other table in
    this codebase gets its own controller.

## Decision 6 — Query shape: join + de-duplication + orphan handling

- **Decision**: The repository method issues:
  ```sql
  SELECT DISTINCT pa.SalesId, pa.TemplateCode, t.Name AS TemplateName
  FROM eutr_purchase_attachments pa
  INNER JOIN eutr_templates t ON t.Code = pa.TemplateCode
  WHERE pa.SalesId IN @SalesIds
  ```
  called with the batch of Sales IDs currently visible on the grid's **current page only** (not the
  entire dataset — see Decision 7).
- **Rationale**:
  - `DISTINCT` directly satisfies spec FR-007a/Edge Cases: when multiple `PurchId` rows for the same
    `SalesId` reference the *same* `TemplateCode`, it collapses to one row — no extra grouping/dedup
    logic needed in the service or frontend layers.
  - `INNER JOIN` (not `LEFT JOIN`) directly satisfies the Edge Case "a `TemplateCode` that no longer
    matches any `eutr_templates` row is skipped, not surfaced as an error" — an orphaned
    `TemplateCode` simply produces no row, which the frontend already treats as "no template for this
    Sales ID" (FR-007b's empty state).
  - Filtering `IN @SalesIds` (Dapper's native list-parameter expansion) rather than fetching the whole
    table keeps the query bounded to the page size already in play (spec SC-001's ~3s budget), and
    needs no new pagination concept of its own.
- **Alternatives considered**:
  - *`GROUP BY SalesId, TemplateCode` instead of `DISTINCT`*: equivalent result, `DISTINCT` chosen for
    readability since no aggregate columns are needed.
  - *`LEFT JOIN` + filter nulls in C#*: rejected — pushes work to the app layer that SQL already does
    more simply via `INNER JOIN`.

## Decision 7 — Frontend: batch-fetch per page, merge client-side

- **Decision**: New frontend files mirroring the `eutr-templates` feature's layering:
  - `domain/interfaces/IEutrPurchaseAttachmentsRepository.js` (abstract-class-style interface, same
    convention as `IEutrTemplatesRepository.js`).
  - `infrastructure/api/eutrPurchaseAttachmentsApi.js` — `POST /api/eutr-purchase-attachments/by-sales-ids`
    with the Sales ID array as body.
  - `infrastructure/repositories/RestEutrPurchaseAttachmentsRepository.js` — implements the interface,
    calls the api client.
  - `application/usecases/eutr-purchase-attachments/GetTemplatesBySalesIdsUseCase.js` — `execute(salesIds)`.
  - Register in `di/repositories.js`: `eutrPurchaseAttachments: new RestEutrPurchaseAttachmentsRepository()`.
  - In `SalesOrderOverviewPage.jsx`: after the existing `refType=11` fetch resolves for the current
    page, collect that page's Sales IDs, call the new use case once with that batch, group the
    response by `salesId` into `{ [salesId]: string[] templateNames }`, and render the Template cell
    as a list of chips (one per template name) — reusing the existing single-`Chip` visual, just
    repeated per template — or a clear empty/"-" state when the map has no entry for that row's
    Sales ID.
- **Rationale**: One batched call per page (not one call per row) keeps request count constant
  regardless of page size, matching spec SC-001. Fetching only the current page's Sales IDs (rather
  than the whole dataset up front) mirrors how the primary Sales Order list is already paginated
  (spec FR-010) — no new pagination concept for this secondary data.
- **Alternatives considered**:
  - *Per-row fetch (one call per Sales ID)*: rejected — N+1 requests per page, contradicts SC-001's
    load-time budget with larger page sizes.
  - *Fetch templates for the entire dataset once and cache*: rejected — Sales Order totals are
    unbounded (D365-sourced); batching per visible page is the same pattern the primary list itself
    already uses and avoids an unbounded `IN (...)` clause.

## Decision 8 — Authorization policy for the new endpoint

- **Decision**: `[Authorize(Policy = "EutrPurchaseAttachments.Read")]`, a new policy code, seeded in
  the DB the same way every other `Eutr*Controller` policy already is (e.g. `EutrTemplates.Read`,
  `EutrDocuments.ReadAll`) — an ops step, not code, consistent with the existing note in this plan
  about the `eutr-sales-orders` menu permission also being DB-seeded.
- **Rationale**: Every existing `Eutr*Controller` in this codebase (`EutrTemplatesController`,
  `EutrDocumentsController`, `EutrTemplateReferencesController`, …) gates each action behind its own
  `{Resource}.{Action}` policy string checked against DB-seeded permissions — `DynController` is the
  one exception, but only because it's a generic D365 reference proxy, not a resource-owning
  controller. Since `eutr_purchase_attachments` is its own resource/table (Decision 5), the consistent
  choice is to follow the resource-owning-controller convention, not the generic-proxy one.
- **Alternatives considered**:
  - *Plain `[Authorize]` only (any authenticated user), matching `DynController`*: rejected as
    inconsistent with how every other resource-owning `Eutr*Controller` in this codebase is secured;
    would also mean the read endpoint has weaker access control than the templates data it exposes.

## Non-goals confirmed out of scope (from spec Assumptions)

- No Create/Edit/Delete for Sales Orders (read-only feature).
- `MapFilePage.jsx` / `ViewSalesOrderPage.jsx` and the `mock/` fixtures they still depend on are not
  touched by this feature.
- Menu/permission DB seeding for `eutr-sales-orders` is an ops step outside this feature's code
  (already assumed wired per Constitution Principle V check above).

---

## Update 2 (2026-07-16) — `MapFilePage.jsx` real data

Spec Update 2 adds User Story 4 / FR-014..FR-030: wire `MapFilePage.jsx` (currently 100% mock-driven)
to real data for existence-check/header, Step 1 PO list + PO-mapping save, and Step 2 template
tree + AVAILABLE FILES, while Upload/Save on Step 2 stay display-only. Investigation below found that
almost everything needed on the **backend already exists** — this update's backend footprint is
deliberately tiny (one new read action + one new write action, both on the already-existing
`EutrPurchaseAttachmentsController`).

## Decision 9 — Header/existence check: reuse the Overview's refType=11 call, no new code path

- **Decision**: `MapFilePage.jsx` calls the same `GetReferenceDataUseCase.execute(1, 1, 'Code', 'asc',
  11, [{ column: 'Code', operator: 'eq', value: salesId }])` that `SalesOrderOverviewPage.jsx` already
  uses (Decision 1/3), requesting a single row filtered by the URL's `salesId`. `so` = the returned
  item (or `null`/`undefined` if `items` is empty) — replaces `MOCK_SALES_ORDERS.find(...)`. Header
  card fields (`Sales ID`, `Customer`, `Customer name`) render straight from that item's
  `code`/`custAccount`/`name`, matching `SalesOrderOverviewPage.jsx`'s existing field mapping
  (`data-model.md`'s "Frontend row shape" table).
- **Rationale**: `BuildFilterString` already routes a `Code`-column filter to `SalesId eq '<value>'`
  for `refType=11` (mapping's `CodeColumn`), so filtering to exactly one Sales Order is a pure
  frontend call-site change — no backend touch, satisfying Constitution Principle III.
- **Alternatives considered**:
  - *New single-item-by-id endpoint (e.g. `GET /api/dynamics/reference/{refType}/{code}`)*: rejected —
    the existing paged/filtered endpoint already supports an exact-match filter; a new endpoint would
    duplicate it for no gain.

## Decision 10 — Step 1 PO list: `refType=16` is already fully wired, including the required filter

- **Decision**: `MapFilePage.jsx` calls `GetReferenceDataUseCase.execute(1, <pageSize>, 'Code', 'asc',
  16, [{ column: 'InterCompanyOriginalSalesId', operator: 'eq', value: salesId }])` — replacing
  `MOCK_SO_POS[salesId]`. **No backend change is needed**: verified in
  `ComplDynamicsService.cs` that `refType = 16` → `RSVNEutrSalesOrderPurchases` is already registered
  in `EntityMappings` (line 44) and `MapDynamicsResponse`'s `case 16` (already populates `Id`/`Code` =
  `RSVNRefPurchId`, `Name`, `InterCompanyOriginalSalesId`, `OrderAccount`, `EutrTemplate` (=
  `RSVNEutrTemplate`), `Qty` on `ComplDynReferenceResponseDto` — all fields the D365 entity's own
  `FilterableFields` dictionary lists). Critically, `InterCompanyOriginalSalesId` is **not** the
  mapping's `CodeColumn`/`NameColumn`, so `BuildFilterString` routes it through its generic "other
  column" branch (`filter.Column` used verbatim as the OData field name) — which already produces the
  exact filter this feature needs (`InterCompanyOriginalSalesId eq '<salesId>'`) with zero backend
  code changes. This existing capability was added for feature `004-eutr-documents` (per this plan's
  Constitution Principle II note on `refType=15`/`16`) but has had no caller using the
  `InterCompanyOriginalSalesId` filter until now.
- **Column mapping consequence** (resolves spec's Assumption on Step 1 columns): the real PO row has
  no `Vendor`/`Vendor Name`/`Rate`/`Material` fields (none exist on `RSVNEutrSalesOrderPurchases` or
  anywhere in scope) — Step 1's table columns change to **PO** (`code`), **Name** (`name`),
  **Order account** (`orderAccount`), **Qty** (`qty`); **EutrTemplate** (`eutrTemplate`) is carried on
  the row (needed for Decision 11) but not necessarily rendered as its own visible column — decide
  final visibility in `data-model.md`'s frontend row-shape table.
- **Rationale**: Principle III — reuse a verified, already-working capability outright rather than
  adding a new filter/column to `ComplDynamicsService`.
- **Alternatives considered**:
  - *Add a bespoke `InterCompanyOriginalSalesId` case to `BuildFilterString`'s column-name switch
    (alongside `"code"`/`"name"`)*: rejected as unnecessary — the existing generic "other" branch
    already produces the correct OData filter without any special-casing.

## Decision 11 — Save PO Mapping: one new write action on `EutrPurchaseAttachmentsController`

- **Decision**: `eutr_purchase_attachments` currently has **only a read path** (Update 1). Add:
  - `IEutrPurchaseAttachmentsRepository.DeleteBySalesIdAsync(string salesId, CancellationToken ct)` —
    raw `DELETE FROM eutr_purchase_attachments WHERE SalesId = @SalesId;`, cloned verbatim from
    `EutrReferencesRepository.DeleteByDocumentIdAsync`'s shape (Update 9 precedent).
  - `EutrPurchaseAttachmentsService.SavePoMappingAsync(string salesId, List<PurchaseAttachmentItemDto>
    items, string userEmail, CancellationToken ct)` — injects `IUnitOfWork` +
    `IRepository<EutrPurchaseAttachments, int>` (generic, resolves via the same open-generic DI
    registration that already backs `IRepository<EutrReferences, long>` in `EutrUploadService`/
    `EutrConditionAssignmentService` — no new DI registration needed) alongside the existing
    `IEutrPurchaseAttachmentsRepository`. Opens a transaction
    (`_unitOfWork.BeginTransactionAsync(IsolationLevel.ReadCommitted)`), calls
    `_repository.DeleteBySalesIdAsync(salesId, ct)`, then loops `items` calling
    `_genericRepository.AddAsync(new EutrPurchaseAttachments { SalesId = salesId, PurchId = i.PurchId,
    TemplateCode = i.TemplateCode, CreatedBy = userEmail, CreatedDate = DateTime.UtcNow, UpdatedBy =
    userEmail, UpdatedDate = DateTime.UtcNow }, ct)` per item — audit fields set inline exactly like
    `EutrUploadService`'s `AddAsync(reference, ct)` call (Update 7 precedent) — then `CommitAsync()`;
    `RollbackAsync()` on exception (clone of `EutrDocumentsService.DeleteAsync`'s Update 9 transaction
    shape).
  - New controller action: `EutrPurchaseAttachmentsController` gets
    `[Authorize(Policy = "EutrPurchaseAttachments.Update")] [HttpPost("save-po-mapping")]` accepting
    `[FromBody] SavePoMappingRequestDto { string SalesId; List<PurchaseAttachmentItemDto> Items; }`
    where `PurchaseAttachmentItemDto { string PurchId; string TemplateCode; }`.
  - New read action on the same controller (needed for Decision 12/FR-019/FR-023 — pre-checking POs
    and sourcing Step 2's `TemplateCode`(s), neither of which the existing `by-sales-ids` batch
    endpoint can serve since it returns `TemplateName` grouped, not per-`PurchId` rows):
    `IEutrPurchaseAttachmentsRepository.GetBySalesIdAsync(string salesId, CancellationToken ct)` — a
    plain `SELECT PurchId, TemplateCode FROM eutr_purchase_attachments WHERE SalesId = @SalesId;` (no
    join needed — `TemplateName` isn't required here), exposed as
    `[Authorize(Policy = "EutrPurchaseAttachments.Read")] [HttpGet("by-sales-id/{salesId}")]` returning
    `ApiResponse<List<PurchaseAttachmentDto>>` (`PurchaseAttachmentDto { string SalesId; string
    PurchId; string TemplateCode; }`).
- **Rationale**: this is the one genuinely new capability (no existing write path for this table);
  Principle II models it on the two closest precedents already in this codebase for
  "delete-then-reinsert under one transaction" (`EutrDocumentsService.DeleteAsync`'s Update 9
  transaction) and "generic-repository `AddAsync` with manually-set audit fields in a loop"
  (`EutrUploadService`'s Update 7 per-`StepId` insert loop) rather than inventing a new shape.
  Delete-then-reinsert (not diff/upsert) directly implements spec FR-021's "replace the whole set"
  semantics with the least code — no need to compute an add/remove delta.
- **Alternatives considered**:
  - *Diff-based update (compute added/removed `PurchId`s, issue targeted INSERT/DELETE per row)*:
    rejected — more code for behavior spec FR-021 doesn't require (it explicitly wants "current
    selection replaces the prior set", not an audit trail of incremental changes); delete-then-reinsert
    is transactionally atomic and simpler.
  - *Extend the existing `by-sales-ids` (plural) endpoint/DTO to also carry `PurchId`*: rejected — that
    endpoint is deliberately shaped for the Overview grid's multi-`SalesId` batch/dedup-by-template use
    case (Decision 6/7); overloading it with per-`PurchId` rows for a single-`SalesId` caller would
    complicate its existing contract for an unrelated consumer. A separate single-`SalesId` action is
    the smaller, additive change (new action, not a breaking DTO reshape).

## Decision 12 — Step 1 default-checked state and Step 2's `TemplateCode` source both read from Decision 11's new `GetBySalesIdAsync`

- **Decision**: On `MapFilePage.jsx` load, call the new
  `GET /api/eutr-purchase-attachments/by-sales-id/{salesId}` once. Its `PurchId` values become the
  initial `selectedPOs` `Set` (replacing `MOCK_SO_PO_MAPPINGS[salesId]`) — satisfies FR-019. Its
  distinct `TemplateCode` values are exactly the input to Decision 13's per-template tree lookups —
  satisfies FR-023/FR-024. One call serves both needs; no second read is required.
- **Rationale**: avoids two separate calls for what is really one underlying fact (this Sales Order's
  saved PO↔template rows); keeps the page's initial load at a small, fixed number of requests.
- **Alternatives considered**: none — this is the natural single source for both UI needs once
  Decision 11's endpoint exists.

## Decision 13 — Step 2 template tree: reuse existing `EutrTemplates` endpoints, no new backend

- **Decision**: For each distinct `TemplateCode` from Decision 12, resolve the tree via two already-
  existing calls (both already wired frontend-to-backend for feature `003-eutr-templates`):
  1. `GetPagingEutrTemplatesUseCase.execute(1, 1, 'Code', 'asc', [{ column: 'Code', operator: 'eq',
     value: templateCode }])` → `POST /api/eutr-templates/get-all` → resolves the template's numeric
     `Id` (and display `Name`) for that `Code`.
  2. `GetEutrTemplatesUseCase.execute(id)` → `GET /api/eutr-templates/{id}` →
     `EutrTemplatesResponseDto.Details: EutrTemplateDetailsResponseDto[]` (`Id`, `ParentId`, `StepId`,
     `StepName`, `RequirementType` (byte: 0=Optional/1=Required, per frontend
     `REQUIREMENT_LABELS`/`utils/helpers.js`), `TakeFrom` (byte: 0=PO/1=Upload manual, per
     `TAKE_FROM_LABELS`), `DisplayOrder`) — this **is** the real, flat `eutr_template_details` rows for
     that template, replacing `EUTR_TEMPLATE_DETAILS_MAP[so.templateId]`. Feed it through the same
     `flatToTree()` util `MapFilePage.jsx` already uses (keyed by `ParentId`, unchanged) to render the
     tree(s) — one call-pair per distinct `TemplateCode` (FR-024: multiple trees shown side by side/
     labeled, mirrors how the Overview grid already renders multiple Template chips for one Sales ID).
- **Rationale**: Principle III — `EutrTemplatesController` already exposes exactly this data
  (confirmed: `GetByIdWithDetailsAsync` is the same method the Templates screens use to show a
  template's step tree); no `GetByCode` shortcut exists, but chaining the existing filter-search +
  get-by-id is a pure frontend orchestration change, not a backend gap.
  - **Known UI narrowing**: real `TakeFrom` only has 2 values (PO / Upload manual) — the mock's richer
    vocabulary (`Vendor`, `D365-Invoice`, `D365-PackingList`, `Company`, `D365`) and the tree's
    `AUTO_SOURCES`-driven "auto-detect" icon/copy have no real equivalent once real
    `eutr_template_details` rows are used. This degrades gracefully (`isAuto` is simply always `false`
    for real nodes — no crash, just the icon defaults to the manual/required look) and is treated as
    an accepted UI simplification, not a gap to backfill in this update (out of spec Update 2's scope).
- **Alternatives considered**:
  - *New backend `GetByCodeWithDetailsAsync` convenience method*: rejected — would just fold the two
    existing calls into one for marginal convenience; Principle III favors reusing the two verified
    working endpoints over adding backend surface for a frontend-only orchestration concern.

## Decision 14 — AVAILABLE FILES: reuse existing `list-po-references` endpoint verbatim, no new backend

- **Decision**: For the `PurchId`s in `selectedPOs` (Step 1's current/saved selection), call the
  already-existing, already-frontend-wired
  `GetEutrDocumentsPoReferencesUseCase.execute(purchIds)` → `POST /api/eutr-documents/list-po-
  references` (feature `004-eutr-documents`, Update 8) → `EutrDocumentsPoReferenceDto[]`
  (`{ poCode, documents: [{ documentId, fileId, fileName, stepNames }] }`, sourced from
  `EutrReferencesRepository.GetDocumentsByPoCodesAsync` — `RefType = 0`/`RefValue = PurchId` JOIN
  `eutr_documents`+`eutr_steps`). Flatten `documents` across the selected PO(s) into the AVAILABLE
  FILES list (replacing `MOCK_AVAILABLE_FILES`); a document's `stepNames` (array of `eutr_steps.Name`
  strings) is matched against each Step 2 tree node's own `StepName` (Decision 13) to decide which
  node(s) show it as "already mapped" (FR-027) — string match on step name, since this endpoint
  surfaces names, not `StepId`s (see Alternatives).
- **Rationale**: this is the exact same data shape (`document ↔ PO ↔ step`) `EutrDocumentsAdd.jsx`'s
  own "List PO" panel already renders for feature `004-eutr-documents` — reusing it outright is
  Principle III/II in their purest form: zero new backend, zero new frontend infra (api client,
  repository, use case all already exist and are DI-registered).
- **Alternatives considered**:
  - *Add a `stepId`-returning variant of `GetDocumentsByPoCodesAsync`/the endpoint*: rejected as
    unnecessary churn on a working, already-consumed contract for another feature; a step-name string
    match is sufficient given step names are unique per template in practice (same assumption the
    existing List PO panel already relies on) and this update's spec doesn't require `StepId`-exact
    (only "correct step", which name-matching satisfies).
  - *Build a new MapFilePage-specific endpoint mirroring `GetDocumentsByPoCodesAsync`*: rejected — pure
    duplication of an existing, working, unrelated-feature-owned endpoint.

## Decision 15 — Policy naming for the two new actions

- **Decision**: `EutrPurchaseAttachments.Update` for `save-po-mapping` (mutating), reusing the existing
  `EutrPurchaseAttachments.Read` for the new `by-sales-id/{salesId}` action (also a read) — both DB-
  seeded the same way as every other `Eutr*Controller` policy (ops step, per Decision 8's existing
  note).
- **Rationale**: `.Update` matches the verb this action performs (replaces existing rows) and follows
  the same `{Resource}.{Action}` convention as `EutrTemplates.Update`/`.Create`/`.Delete`; no need for
  a `.Create` distinct from `.Update` since the single action always does delete-then-reinsert
  (Decision 11), never a plain insert-only path.
- **Alternatives considered**:
  - *New `.Write` catch-all policy covering both actions*: rejected — inconsistent with every other
    `Eutr*Controller` in this codebase, which distinguishes `.Read`/`.Create`/`.Update`/`.Delete`
    rather than collapsing mutations into one code.

---

## Update 3 (2026-07-20) — Step 1 "select more" confirmation + Back button fix

Spec Update 3 adds FR-031/FR-032/FR-033. Before writing any code, the existing `MapFilePage.jsx`
(shipped under Update 2) was re-inspected line-by-line to check whether it already satisfies the new
requirements or genuinely needs a change.

## Decision 16 — FR-031/FR-032 require no code change; already satisfied by the Update 2 implementation

- **Decision**: No change to the Step 1 checkbox rendering, its disable condition, or the
  `save-po-mapping` write path.
- **Rationale**: The existing `MapFilePage.jsx` checkbox disable condition is `disabled =
  !po.eutrTemplate` — it only disables a PO when D365 itself returns no template value for that PO
  (the genuine FR-022 case). It never disables a PO merely because that PO has no prior
  `eutr_purchase_attachments` row. So any PO that has a real `eutrTemplate` from D365 but hasn't been
  saved before is **already** checkable today — exactly what FR-031 asks for. Separately, Save PO
  Mapping's existing write path (Decision 11) is delete-then-reinsert of *whatever is currently
  checked* at the moment Save is clicked, built from `poList` filtered by `selectedPOs` (not filtered
  by "was this PO previously saved") — so a newly-checked, previously-unsaved PO is written to
  `eutr_purchase_attachments` on Save exactly the same way an already-saved one is, satisfying FR-032
  with zero additional logic.
- **Alternatives considered**:
  - *Add an explicit `isNewlySelected` flag/branch to distinguish "add" from "re-save" POs*: rejected
    — there is nothing to distinguish; the existing replace-the-whole-set semantics (FR-021, kept
    unchanged per Update 3's spec text) already produce the correct end state for both previously-saved
    and newly-added POs in a single Save action.
  - *Loosen the `disabled = !po.eutrTemplate` condition further (e.g. allow selecting POs with no D365
    template and let the user type a Template code)*: rejected — out of scope; the spec's Update 3
    clarification (confirmed directly with the requester before drafting) keeps `TemplateCode` sourced
    only from the PO's own `eutrTemplate` field, so the FR-022 block for template-less POs stays exactly
    as Update 2 left it.

## Decision 17 — Back button: reuse the existing breadcrumb's `navigate` call

- **Decision**: Add `onClick={() => navigate('/eutr/sales-orders')}` to the Back `<Button>` in
  `MapFilePage.jsx`, using the same `navigate` (from `useNavigate()`) already imported and already
  used by this page's breadcrumb link one section above it — not a new navigation helper, not
  `window.history.back()`.
- **Rationale**: The breadcrumb link already proves this exact target/mechanism works correctly on
  this page; reusing it verbatim is the smallest possible change and guarantees identical behavior
  between the two affordances (Principle II — model on an existing, already-correct pattern in the
  same file, rather than inventing a second way to express "go back to the Overview").
- **Alternatives considered**:
  - *`navigate(-1)` (browser history back)*: rejected — spec FR-033 explicitly requires landing on
    **EUTR Sales Orders**, not "wherever the user came from" (which could be an external link, a
    refresh, or direct URL entry with no history entry) — `navigate(-1)` cannot guarantee that target.

## Updated non-goals (Update 3)

- No backend change of any kind (no new/edited controller, service, repository, entity, or DTO).
- No change to the Step 1 checkbox-disable condition or to `SavePoMappingAsync`'s
  delete-then-reinsert behavior — both already do what FR-031/FR-032 require.
- No manual-Template-selection UI added for POs without a D365 `eutrTemplate` value — FR-022's block
  for those stays exactly as Update 2 implemented it.

## Updated non-goals (Update 2)

- Upload (new file) and Save (file↔step mapping) on Step 2 remain display-only/no-op — no backend
  endpoint is added or called for either action in this update (spec FR-029/FR-030).
- `ViewSalesOrderPage.jsx` remains fully on mock data — out of scope for this update (not named in the
  feature description); still MUST NOT be broken by shared `mock/` file edits (same guardrail as
  Update 1's non-goals).
- No change to `SalesOrderOverviewPage.jsx` or the Update 1 `by-sales-ids` (plural) endpoint/contract —
  Update 2 only adds two new actions alongside it on the same controller.

---

## Update 4 (2026-07-20) — `ViewSalesOrderPage.jsx` real data, read-only

Spec Update 4 adds User Story 5 / FR-034..FR-046: wire `ViewSalesOrderPage.jsx` (currently 100%
mock-driven, the last remaining consumer of the `eutr-sales-orders/mock/*` fixtures) to the same real
data `MapFilePage.jsx` already reads, rendered strictly read-only. Because every read this screen needs
was already built and verified working for `MapFilePage.jsx` (Update 2/3), this update's investigation
is short: there is no backend gap to fill at all, only a frontend orchestration/rendering question.

## Decision 18 — Reuse every one of `MapFilePage.jsx`'s real-data effects verbatim, minus the write path

- **Decision**: `ViewSalesOrderPage.jsx` gets the same four data-loading `useEffect`/`useCallback`
  blocks `MapFilePage.jsx` already has (Decisions 9, 10, 12, 13, 14 combined): (1) `refType=11`
  single-row fetch for existence/header, (2) `GET /api/eutr-purchase-attachments/by-sales-id/{salesId}`
  for the saved `PurchId`/`TemplateCode` pairs, (3) per-distinct-`TemplateCode` `EutrTemplates`
  get-all/GetById tree lookup, (4) `list-po-references` for AVAILABLE-FILES-shaped step-mapped status.
  **Not** carried over: `selectedPOs` as mutable state (it becomes a plain derived `Set`/array from (2),
  never ticked by the user), `handleSavePOMapping`/`SavePoMappingUseCase` (no Save button on this
  screen), and every map/unmap/upload handler (`handleMapClick`, `handleUnmapFile`, `handleUpload`,
  dialog state) — none of it applies to a read-only screen.
- **Rationale**: Principle II — `MapFilePage.jsx` is the closest possible model (same Sales Order,
  same tables, same endpoints), already verified correct in production use since Update 2/3; cloning
  its read effects is strictly less risky than re-deriving the same queries independently. Principle
  III — every one of the four calls already exists; nothing new to build.
- **Alternatives considered**:
  - *Build a single new aggregate read endpoint (e.g. `GET /api/eutr-sales-orders/{salesId}/summary`)
    that bundles all four reads server-side*: rejected — would be new backend surface for a capability
    that already works as four small, independently-reusable calls; Principle III favors reusing what
    exists over consolidating it into something new for marginal round-trip savings the spec's
    performance goals (SC-001/SC-005, ~3s) don't require.

## Decision 19 — Purchase Orders "đã chọn" table: join `GetBySalesIdAsync`'s saved `PurchId`s against the `refType=16` PO list for display fields

- **Decision**: `GetBySalesIdAsync`'s response (`PurchaseAttachmentDto[]`: `SalesId`, `PurchId`,
  `TemplateCode`) has no `Name`/`OrderAccount`/`Qty` — those only exist on the `refType=16` D365 rows
  (Decision 10). So: fetch `refType=16` filtered by `InterCompanyOriginalSalesId = salesId` (same call
  `MapFilePage.jsx`'s Step 1 already makes), then filter that result client-side to only the rows whose
  `code` (`PurchId`) is present in `GetBySalesIdAsync`'s saved set — producing exactly the "Purchase
  Orders đã chọn" list (spec FR-037), with the same columns already decided for Step 1 (PO / Name /
  Order account / Qty, Decision 10's "column mapping consequence").
- **Rationale**: no backend change needed — both calls already exist and already return everything
  required; the join is a trivial client-side `Array.prototype.filter` by membership in a `Set`, not a
  new query.
- **Alternatives considered**:
  - *New backend endpoint that joins `eutr_purchase_attachments` to `RSVNEutrSalesOrderPurchases`
    server-side*: rejected — `eutr_purchase_attachments` is a local MySQL table and
    `RSVNEutrSalesOrderPurchases` is a live D365 OData entity; joining across that boundary in SQL is
    not possible (different data sources), and joining in C# would just move the same client-side
    filter into a new, unnecessary controller action (Principle III).

## Decision 20 — Validation Summary: recompute the same three checks locally, dropped to two (no real expiry data)

- **Decision**: Port `MapFilePage.jsx`'s existing `computeProgress(details, fileMappings)` pure
  function (small, no side effects) into `ViewSalesOrderPage.jsx` and drive the Validation Summary from
  it: "đã chọn ít nhất 1 PO" (saved `PurchId`s count > 0), "Required steps đủ file" (`computeProgress`'s
  `completed`/`total`), and a per-step missing list (`allDetails` filtered by
  `requirementType === 'Required'` and no mapped file, same predicate `MapFilePage.jsx`'s own
  `missingRequired` already uses). The old mock version's third check ("File không hết hạn") is
  **dropped** — real documents from `list-po-references` carry no `validFrom`/`expiredDate` field at
  all (Decision 14/`data-model.md`'s "Field-availability note"), so there is no real data to check
  against; keeping a check that can only ever evaluate to "pass" would misrepresent it as a real
  validation (spec Assumptions, Update 4).
- **Rationale**: matches spec FR-045/FR-046 exactly (2 conditions: PO selected, Required steps
  complete) and avoids fabricating a signal the backend doesn't provide.
- **Alternatives considered**:
  - *Extract `computeProgress` into a shared util module instead of duplicating it in both pages*:
    considered reasonable but treated as optional polish, not required for spec compliance — the
    function is a handful of lines with no external dependency; duplicating it is a smaller diff than
    introducing a new shared file for a two-caller function, and either is compliant with the spec.
    Left as an implementation-time choice, not a decision this update mandates.
  - *Keep the "File không hết hạn" row, always green*: rejected — spec Update 4's own Assumptions
    section explicitly says this condition doesn't apply until a real expiry data source exists;
    showing an always-true check would be misleading, not merely redundant.

## Decision 21 — Read-only rendering: reuse this page's own existing `ViewNode`, not `MapFilePage.jsx`'s `TreeNode`

- **Decision**: `ViewSalesOrderPage.jsx` already has its own tree-row component, `ViewNode` (distinct
  from `MapFilePage.jsx`'s interactive `TreeNode`) — no `onClick`/`onSelect`/`onUnmap` handlers, purely
  presentational (status icon, chips, mapped-file name). Keep using it, just feed it the real
  `templatesData`-derived tree(s) and real `fileMappings` (derived from `list-po-references`' matched
  `stepNames`, same derivation `MapFilePage.jsx`'s `derivedFileMappings` already computes) instead of
  the mock tree/mappings. Expand/collapse state (`collapsedIds`) stays exactly as already implemented
  (local UI state only, not a write).
- **Rationale**: satisfies spec FR-042 (read-only) by construction — `ViewNode` was never given
  interactive handlers to begin with, so there is nothing to strip out or disable; reusing it is less
  code than adapting `TreeNode` (which would require deleting several props/handlers) and keeps this
  page's own established component instead of pulling in one built for a different (editable) screen.
- **Alternatives considered**:
  - *Reuse `MapFilePage.jsx`'s `TreeNode` with all interactive props stubbed to no-ops*: rejected —
    more code (passing dummy handlers) for a worse outcome (a component built for interactivity,
    artificially neutered) than this page's own already-correct read-only component.

## Decision 22 — Delete the now-fully-unused `eutr-sales-orders/mock/*` fixtures (except `eutrSteps.js`)

- **Decision**: Once `ViewSalesOrderPage.jsx` no longer imports `MOCK_SALES_ORDERS`/`MOCK_SO_POS`/
  `MOCK_SO_PO_MAPPINGS`/`MOCK_AVAILABLE_FILES`/`MOCK_FILE_MAPPINGS` (`mock/eutrSalesOrders.js`),
  `EUTR_TEMPLATE_DETAILS_MAP` (`mock/eutrTemplateDetails.js`), or `EUTR_TEMPLATES`
  (`mock/eutrTemplates.js`), a full-repo search confirms no other file imports any of these three —
  delete them. `mock/eutrSteps.js` is the one exception: `utils/treeUtils.js`'s `getStepName()` still
  imports `EUTR_STEPS` from it directly as a fallback inside `flatToTree()`, and `treeUtils.js` is
  shared by both `MapFilePage.jsx` and `ViewSalesOrderPage.jsx` — deleting it would break that shared
  util's import unless `treeUtils.js` itself is also edited to drop the fallback (out of this update's
  scope; noted as a candidate for a later small cleanup, not required for spec compliance).
- **Rationale**: this repo's own convention (and Principle-adjacent good practice already followed
  elsewhere in this feature, e.g. Update 1/2's "no dead mock left behind for a removed consumer")
  favors deleting verified-unused code over leaving it as an orphaned fixture nobody imports.
- **Alternatives considered**:
  - *Keep all four mock files "just in case" a future screen needs them again*: rejected — this repo's
    conventions favor deleting confirmed-dead code over speculative retention; if a future feature
    needs similar fixtures it can add them fresh, informed by whatever that feature actually needs
    (which may differ from this now-obsolete mock shape).

## Updated non-goals (Update 4)

- No backend change of any kind (no new/edited controller, service, repository, entity, or DTO) — every
  read this screen needs already exists (Decisions 9/10/13/14 from Update 2, reused as-is).
- No PO tick/Save Mapping, no file map/unmap, no Upload — `ViewSalesOrderPage.jsx` never imports
  `SavePoMappingUseCase` or any of `MapFilePage.jsx`'s write-path handlers (spec FR-042).
- No change to `MapFilePage.jsx` itself — this update only reads the same tables/endpoints it already
  reads, from a second, independent page component.
- No "File không hết hạn" check in the Validation Summary — dropped for lack of real expiry data
  (Decision 20), not silently kept as an always-passing check.
- `mock/eutrSteps.js` and its one remaining consumer (`utils/treeUtils.js`'s `getStepName` fallback)
  are left untouched — cleaning that up is out of scope for this update (Decision 22).

## Update 5 (2026-07-27) — Template tree toolbar reload + AVAILABLE FILES dynamic badges

Covers spec FR-047..FR-052: (a) clicking a template chip in the Step 2 toolbar
(`data-marker="template-tree-toolbar"`) refetches `templatesData`; (b) the three currently-static
labels on each AVAILABLE FILES row ("Map status", "File type", "PO value") become dynamic, sourced
from `eutr_references`.

## Decision 23 — Toolbar reload: extract the existing template-build effect into a callable function

- **Decision**: `MapFilePage.jsx`'s `useEffect` that builds `templatesData` from
  `purchaseAttachments` (Update 2, Decision 13) currently only re-runs when `purchaseAttachments`
  changes. Extract its body into a `loadTemplatesData(templateCodes)` `useCallback` (same pattern
  already used for `loadPurchaseAttachments`, Decision 12) and call it both from the `useEffect`
  (auto-load) and from an `onClick` on each template `Chip` in the toolbar (manual reload). Both call
  sites resolve `templateCodes` the same way — `[...new Set(purchaseAttachments.map(pa =>
  pa.templateCode))]` — so a manual click re-fetches the exact same set fresh from
  `GetPagingEutrTemplatesUseCase`/`GetEutrTemplatesUseCase`, picking up any change made elsewhere
  (e.g. a template's steps edited in `003-eutr-templates` since page load) without a full page reload.
- **Rationale**: this is the same "extract effect body into a reusable callback" shape already
  established in this same file for `loadPurchaseAttachments` (Decision 12) — Principle II reuse of
  an in-file precedent, not a new pattern. Zero new backend, zero new use case — same two existing
  calls (`get-all` filtered by `Code`, then `GetById`), just invoked on demand as well as on mount.
- **Alternatives considered**:
  - *Force-reload via a state "cache-buster" key (e.g. bump a `reloadNonce` counter, add it as a
    `useEffect` dependency)*: rejected — indirect and harder to read than calling the extracted
    function directly from the `onClick`; no benefit here since there is no request de-duplication
    concern (`Promise.all` over a handful of distinct `TemplateCode`s is cheap, same as today).
  - *Reload only the clicked template's own tree, leave the others as-is*: rejected — spec Update 5
    explicitly documents (as an Assumption) that Step 2 always renders every template tree together,
    so a full-list reload is the reasonable default; a per-template partial reload would need to key
    `templatesData` differently (by which entries are "stale") for no material benefit, since a full
    reload of a handful of templates is already fast.

## Decision 24 — Map status badge: extend `list-po-references`'s response additively with raw `StepId`s

- **Decision**: `POST /api/eutr-documents/list-po-references` (owned by `004-eutr-documents`, Decision
  14) currently returns `stepNames: string[]` per document (JOIN `eutr_steps.Name`), no raw `StepId`.
  Spec FR-049 requires comparing `StepId` directly, not step name. Add one **additive** field
  `stepIds: long[]` to `EutrDocumentsPoReferenceItemDto` (`ComplianceSys.Application/Dtos/Response/`),
  populated the same way `stepNames` already is (`EutrReferencesRepository.GetDocumentsByPoCodesAsync`
  already `SELECT`s from `eutr_references r`, which already carries `r.StepId` — just add it to the
  `SELECT` list and the `EutrReferencePoDocumentInfo` projection class, then group/distinct it into
  `stepIds` in `EutrDocumentsService.GetPoReferencesAsync` the same way `stepNames` is grouped today).
  `stepNames` itself is left untouched (still consumed as-is by `ViewSalesOrderPage.jsx`'s own Template
  Checklist mapping, Decision 14/19 — out of scope for this update). Frontend: a file is "Mapped" when
  `file.stepIds` intersects the `stepId` of any node in `allDetails` (already carries `stepId`,
  Decision 13's `normalizeTemplateDetail`) — "No map" otherwise.
- **Rationale**: Principle III — reuse the already-existing, already-correct JOIN
  (`eutr_references r LEFT JOIN eutr_documents d LEFT JOIN eutr_steps s WHERE r.RefValue IN
  @PoCodes`); the only gap is one column missing from the `SELECT`/DTO, not a new query or endpoint.
  This mirrors the exact same additive-DTO-extension precedent already used repeatedly in this
  codebase (e.g. `004-eutr-documents` Update 8/10/14 adding `stepNames`/`refType`/`fileId`/`typeName`
  to existing DTOs without breaking existing consumers).
- **Alternatives considered**:
  - *Keep matching by `stepName` string, like the tree's own existing "already mapped" indicator
    (Decision 14)*: rejected — spec FR-049 explicitly requires `StepId` equality, and step names are
    not guaranteed globally unique the way `StepId` is (the existing name-match was an accepted
    approximation for the tree's internal indicator, not a hard spec requirement at the time).
  - *Add a brand-new endpoint specific to this page*: rejected — pure duplication of a working,
    shared, already-frontend-wired endpoint (Principle III).

## Decision 25 — File type / PO value badges: additive `RefType`/`TypeName`; PO value needs no backend change

- **Decision**: PO value is already returned today — `EutrDocumentsPoReferenceDto.poCode` (the same
  `RefValue` the query filtered on, since `GetDocumentsByPoCodesAsync`'s `WHERE r.RefValue IN
  @PoCodes` guarantees `PoCode == RefValue` for every row it returns). No backend or DTO change is
  needed for FR-051 — `MapFilePage.jsx` only needs to carry `poDoc.poCode` through onto each file
  object it already builds inside its existing `poReferenceDocs.forEach(poDoc => ...)` loop (today it
  reads `doc.*` but drops `poDoc.poCode` on the floor). For File type (FR-050), add one more additive
  field alongside `stepIds` (Decision 24): `refType: byte?` + `typeName: string?` on
  `EutrDocumentsPoReferenceItemDto`, sourced by extending the same SQL with `LEFT JOIN
  eutr_reference_types t ON t.Id = r.RefType` + `t.Name AS TypeName`, and grouping `refType`/`typeName`
  as "first non-null value across the document's rows for this PO" — the exact same aggregation shape
  `EutrDocumentsService.AttachStepAndConditionInfoAsync` already uses for `get-all`/`get-by-id` (Update
  13/14 of `004-eutr-documents`), cloned here rather than invented.
- **Rationale**: Principle II/III — clone the already-working `RefType`→`TypeName` lookup-and-attach
  pattern from `AttachStepAndConditionInfoAsync` instead of inventing a new join or a new lookup
  endpoint; Principle III — `poCode` reuse for PO value needs zero backend change at all, just a
  frontend field that was already available and simply unused.
- **Alternatives considered**:
  - *Display raw `RefType` (numeric) instead of a joined name*: rejected — spec FR-050 explicitly says
    "hiển thị tên loại" (show the type name), and every other Type-like column in this codebase
    already resolves a name from an id (`004-eutr-documents`'s own Type column, Update 14) — showing a
    bare number would be an inconsistent regression against that established UI convention.
  - *Re-fetch `RefValue` per document via a second call*: rejected — unnecessary extra round-trip; the
    value is already present as `poCode` on the exact same response object, one loop away from where
    it is currently discarded.

## Updated non-goals (Update 5)

- No new endpoint, no new controller action, no migration — `eutr_references.StepId`/`RefType` and
  `eutr_reference_types.Name` already exist; this update only widens one existing response DTO
  additively (`stepIds`, `refType`, `typeName`) and reads one existing field the frontend already
  receives but currently discards (`poCode`).
- No change to `stepNames`' existing shape/consumers — `ViewSalesOrderPage.jsx`'s own Template
  Checklist mapping (Decision 19) keeps reading `stepNames` exactly as before; this update is purely
  additive on the shared DTO.
- No change to the tree's own existing "already mapped" indicator (the `derivedFileMappings`
  stepName-based match driving the tree's success/error coloring, Decision 14) — FR-049's Map status
  badge is a separate, new, per-file-row computation living alongside it, not a replacement of it.
- No change to Step 2's Upload/Save no-op behavior (FR-029/FR-030, unaffected by this update).

---

## Update 6 (2026-07-27) — Wire Step 2 Upload/Edit to `004-eutr-documents`' Add/Edit popup

Spec Update 6 replaces FR-029/FR-030 (previously demo/no-op) and adds FR-030a/FR-030b: Step 2's
Upload button (UploadIcon) and each file's Edit action in `MapFilePage.jsx` MUST now perform real
writes, by reusing the already-built Add/Edit document popup from `004-eutr-documents`
(`EutrDocumentsFormDialog.jsx`) rather than continuing with the page's own two fully-local dialogs
(`UploadDialog`, `MapFileDialog`). Investigation confirms this is a pure frontend reuse — the popup
already performs every real write this update needs; the only genuinely new question is how to
source enough real data to open it in **edit** mode for a document `MapFilePage.jsx` did not create
the row for.

## Decision 26 — Reuse `EutrDocumentsFormDialog.jsx` directly, not a fork or a new dialog

- **Decision**: `MapFilePage.jsx` imports `EutrDocumentsFormDialog` from `presentation/pages/
  eutr-documents/components/EutrDocumentsFormDialog.jsx` and renders it twice: once for **Add**
  (`mode="add"`, `initialData={null}`) wired to the Step 2 Upload button, once for **Edit**
  (`mode="edit"`, `initialData={<fetched row, see Decision 27>}`) wired to each AVAILABLE FILES row's
  Edit icon — replacing the two fully-local components this page currently defines internally
  (`UploadDialog`, `MapFileDialog`) and their local-state-only handlers (`handleUpload`,
  `handleMapDialogConfirm`, and the `newlyUploadedFiles`/`stepFilePO` local state they mutate).
- **Rationale**: the spec (Update 6, confirmed with the requester before drafting) explicitly calls
  for reusing 004-eutr-documents' Add/Edit functionality — the **full**, unrestricted Add popup (no
  Type/Step/Value auto-lock to the PO/node currently selected in Map File) and a **full replacement**
  of the old local Edit dialog. `EutrDocumentsFormDialog` already implements every rule the new
  FR-029/FR-030 require (Type/Step/Value-chip/Valid-dates fields and validation, real SharePoint
  upload, real `eutr_documents`/`eutr_references` writes) — reusing the component outright is
  Principle II/III in their purest form: zero duplicated logic, zero new backend code. Verified: the
  component has no dependency on anything specific to the `eutr-documents` page/route context (it
  only reads its own props and calls already-DI-registered use cases), so importing it cross-feature
  works today with no relocation needed.
- **Alternatives considered**:
  - *Fork a copy of the dialog's JSX/logic into a new `eutr-sales-orders/components/` file*: rejected
    — pure duplication of a working, already-tested component; any future fix to 004's Add/Edit rules
    would then need to be applied twice, violating Principle II.
  - *Move `EutrDocumentsFormDialog` into a shared/common presentation folder before reuse*: considered
    reasonable long-term hygiene, but out of scope for this update — nothing about the component
    requires relocation to be importable from another page folder; treated as a candidate for a later
    cleanup, not required for spec compliance.
  - *Build a smaller, Map-File-scoped dialog (Type/Value auto-locked to the current PO/node)*:
    rejected — the requester's clarification explicitly asked for the full, unrestricted 004 Add
    popup, not a scoped-down variant.

## Decision 27 — Edit-detail fetch: reuse `GetPagingEutrDocumentsUseCase` filtered by `Id`, no new backend endpoint

- **Decision**: before opening the Edit popup for a given `documentId` (from the AVAILABLE FILES row
  the user clicked Edit on), `MapFilePage.jsx` calls the same
  `GetPagingEutrDocumentsUseCase.execute(1, 1, 'Id', 'asc', [{ column: 'Id', operator: 'eq', value:
  documentId }])` that `eutr-documents/index.jsx`'s own grid already uses for its listing
  (`POST /api/eutr-documents/get-all`) — the one returned row (`EutrDocumentsResponseDto`: `id`,
  `name`, `refType`, `stepId`, `conditions`, `validFrom`, `validTo`) is passed straight through as
  `initialData` to `EutrDocumentsFormDialog` in edit mode. This exactly matches the fields the dialog
  reads in edit mode (verified by reading the component: `initialData.id`/`.name`/`.refType`/
  `.stepId`/`.conditions`/`.validFrom`/`.validTo`, nothing else — the dialog performs **no** internal
  re-fetch by `initialData.id` itself; it relies entirely on what the caller passes in).
- **Rationale**: two existing single-document read paths were considered and ruled out first:
  - `GET /api/eutr-documents/get-by-id/{id}` falls through to the generic `BaseService.GetByIdAsync`
    and returns the bare `EutrDocuments` domain entity (`Id, Name, FileId, ValidFrom, ValidTo` + audit
    fields only) — **no** `RefType`/`StepId`/`Conditions`/`TypeName` — confirmed by reading
    `EutrDocumentsService.cs` (no override of `GetByIdAsync`) and the domain entity class. Cannot feed
    the dialog as-is.
  - There is no dedicated frontend use case wrapping any "get one document's full edit-ready detail"
    endpoint today (`GetEutrDocumentsFileByIdRefUseCase` is unrelated — it fetches the raw file
    blob/URL for the View/preview dialog, not document metadata).
  - However, `EutrDocumentsService.GetPagedAsync`'s own internal search-box-filter rewrite
    (`ApplySearchBoxFiltersAsync`) already injects a `FilterRequest { Column = "Id", Operator = "in",
    Value = "<ids>" }` into this exact same paging pipeline (verified by reading
    `EutrDocumentsService.cs`) — direct, in-code proof that the underlying generic repository filter
    mechanism already supports filtering this endpoint by `Id` server-side. Repurposing the paging
    endpoint with a single-`Id` filter (`page=1, pageSize=1`) is therefore a verified-working,
    zero-backend-change path to exactly the `EutrDocumentsResponseDto` shape the dialog needs — a
    pure frontend orchestration change (one more use-case call site), not a backend gap.
- **Alternatives considered**:
  - *Add a new backend action returning `EutrDocumentsResponseDto` for a single `Id`* (e.g.
    `GET /api/eutr-documents/get-detail/{id}`): rejected as unnecessary churn — Principle III favors
    reusing the already-existing, already-correct paging pipeline (proven to support `Id` filtering
    internally) over adding a new, narrowly-scoped endpoint that would just wrap the same underlying
    query for one row.
  - *Widen `list-po-references`'s response (already used by Map File, Update 2/5) to also carry
    `conditions`/`validFrom`/`validTo`/a singular `stepId`*: rejected — that endpoint is deliberately
    shaped per-PO-context (values/steps aggregated across a document's rows within one PO's context);
    forcing it to also carry the full edit-ready document shape would conflate two different response
    shapes for two different consumers (AVAILABLE FILES display vs. Edit-popup hydration) for no
    benefit, when a second, already-existing endpoint (paging, filtered) already returns exactly the
    right shape.

## Decision 28 — Refresh AVAILABLE FILES/Map status after Upload or Edit succeeds

- **Decision**: pass an `onSubmitted` callback to both `EutrDocumentsFormDialog` instances that
  re-invokes the same `GetEutrDocumentsPoReferencesUseCase.execute(purchIds)` call Step 2's AVAILABLE
  FILES already uses on load (Decision 14/Update 2), using the currently-selected/saved `PurchId`s —
  mirroring the extraction-into-a-callable-function pattern already established in this same file for
  `loadPurchaseAttachments` (Decision 12) and `loadTemplatesData` (Decision 23).
- **Rationale**: spec FR-030a requires AVAILABLE FILES/Map status to reflect a just-completed
  Upload/Edit without a full page reload; re-running the exact same already-correct query is the
  simplest way to guarantee this without risking client-side state drifting from what the backend
  actually persisted — especially relevant for Edit, whose real chip-diff/step-sync rules
  (`004-eutr-documents` FR-052/FR-053: rows added/removed per Save) are non-trivial to replicate by
  hand-patching local state.
- **Alternatives considered**:
  - *Optimistically patch local `availableFiles` state from the popup's own submitted values*:
    rejected — would require re-implementing Edit's chip-diff/step-sync rules a second time on the
    005 side just to predict the resulting rows, for a result the backend can already tell us
    authoritatively with one more read call.

## Updated non-goals (Update 6)

- No new backend endpoint, controller action, DTO, or migration — Upload writes go through the
  already-existing `POST /api/sharepoint/eutr-upload-multi` (Type = "PO") /
  `POST /api/sharepoint/eutr-upload-multi-by-type` (other Types) actions; Edit writes go through the
  already-existing `PUT /api/eutr-documents/{id}` (document fields) and
  `PUT /api/eutr-documents/{id}/step` (step + reference values) actions; the one new read reuses
  `POST /api/eutr-documents/get-all` filtered by `Id`.
- `EutrDocumentsFormDialog.jsx` itself, and every use case/repository/api-client it internally calls
  (`GetEutrReferenceTypesUseCase`, `GetEutrStepsUseCase`, `GetByTypeIdEutrReferenceTypeDetailsUseCase`,
  `UploadToSharePointUseCase`, `UpdateEutrDocumentsUseCase`,
  `UpdateEutrDocumentReferenceStepUseCase`), are unchanged — reused as-is, not edited, by this update.
- The old local `UploadDialog`/`MapFileDialog` components and the local-state-only mutation logic
  they drove (`newlyUploadedFiles`, `stepFilePO`, local `fileMappings` edits) are **removed** from
  `MapFilePage.jsx`, not kept running in parallel — the requester confirmed a full replacement, not a
  side-by-side second path, before this update was drafted.

---

## Update 7 (2026-07-27) — Map status/AVAILABLE FILES scoped by PO ↔ Template

Spec Update 7 adds FR-053..FR-057: Step 2's AVAILABLE FILES list and its Map status badges/tree
"already has a file" indicators currently match/merge across **all** saved templates' steps and
**all** selected POs' documents, without checking that a document's own PO actually belongs (via
`eutr_purchase_attachments`) to the template being evaluated. Investigation of the shipped
`MapFilePage.jsx` (Updates 2/5) confirms the exact mechanism: `allDetails =
templatesData.flatMap(t => t.flatDetails)` flattens every saved template's step definitions into one
combined list, and both `derivedFileMappings` (the tree's own "already mapped" indicator, matched by
`stepName`) and `isMappedByStepId` (the AVAILABLE FILES Map-status badge, matched by `stepId`) compare
against this combined list — with no check that the candidate file's PO belongs to the template the
step came from. Since different templates can legitimately reuse the same `StepId`/step name from the
shared `eutr_steps` table (e.g. both templates define an "Invoice" step), this can mark a document
"Mapped" against an unrelated template's node purely by name/id coincidence.

## Decision 29 — Scope AVAILABLE FILES + Map status by PO→Template via already-loaded `purchaseAttachments`, zero backend change

- **Decision**: `MapFilePage.jsx` already loads `purchaseAttachments` (`{purchId, templateCode}[]`,
  from Update 2's `GetBySalesIdAsync`/`GET /api/eutr-purchase-attachments/by-sales-id/{salesId}`) and
  each AVAILABLE FILES entry already carries its own `poCode` (added in Update 5, `realAvailableFiles`
  in the current implementation). Build one new small lookup:
  ```js
  const purchIdToTemplateCode = useMemo(() => {
    const map = new Map();
    purchaseAttachments.forEach(pa => map.set(pa.purchId, pa.templateCode));
    return map;
  }, [purchaseAttachments]);
  ```
  Then, for a given template `t` (identified by `t.templateCode`), scope its own candidate files:
  `filesForTemplate = realAvailableFiles.filter(f => purchIdToTemplateCode.get(f.poCode) ===
  t.templateCode)`. AVAILABLE FILES' rendered list (search, pagination, the Map-status badge) MUST use
  `filesForTemplate(selectedTemplateCode)` instead of the full, unscoped `realAvailableFiles`/`allFiles`
  list — this directly implements FR-053/FR-054. The tree's own "already mapped" indicator (currently
  `derivedFileMappings`, matched by `stepName` against `allDetails`) MUST likewise be recomputed per
  template, matching `t.flatDetails` only against `filesForTemplate(t.templateCode)` — never against
  another template's files, even when `stepName`/`stepId` coincide (FR-055/FR-056). Because both sides
  of the match (steps and files) are now scoped to the same `templateCode` before comparing, a document
  belonging to an unrelated template's PO can never satisfy the match, regardless of `StepId`/name
  coincidence — the fix is structural (scope-then-match), not an extra conditional bolted onto the old
  global match.
- **Rationale**: the PO→Template link this fix needs (`eutr_purchase_attachments.PurchId`→
  `TemplateCode`) is already fully available client-side — no new endpoint, no new DTO field, no new
  query. This is Constitution Principle III in its purest form: the gap is a client-side under-use of
  already-fetched data, not a missing backend capability. Scoping by filtering-then-matching (rather
  than matching-then-filtering) is also the simplest correct shape: it reuses the exact same per-detail
  `stepName`-match / per-file `stepIds`-vs-`stepId`-match logic already written for
  `derivedFileMappings`/`isMappedByStepId` (Update 2/5), just called once per template against that
  template's own scoped file subset instead of once globally against everything combined.
- **Alternatives considered**:
  - *Keep one global match, but add a post-hoc filter that discards a match if the file's PO doesn't
    belong to the matched node's template*: rejected — requires threading "which template does this
    node belong to" back through every matched pair after the fact (the flattened `allDetails` loses
    that association), more code and more error-prone than simply never mixing the two lists together
    in the first place.
  - *Add a new backend endpoint that returns documents pre-grouped by `TemplateCode`*: rejected — the
    grouping key (`PurchId`→`TemplateCode`) is a local, already-fetched, tiny lookup; standing up new
    backend surface for a client-side `Map.get()` would be unjustified new API surface for zero backend
    gap (Principle III explicitly limits backend changes to verified gaps only — there is none here).
  - *Filter `poReferenceDocs` at fetch time (only request `list-po-references` for the currently-viewed
    template's own POs)*: rejected — `loadAvailableFiles` is called with the full `selectedPOs` set for
    reasons independent of this fix (Step 1's selection, not the toolbar's per-template view), and
    re-fetching on every toolbar click would be slower than filtering the already-fetched response
    client-side (no new network round-trip needed since `poCode` is already present per file).

## Decision 30 — Aggregate progress: sum of per-template, correctly-scoped completions

- **Decision**: The header card's aggregate progress (`Required/completed`, `%`, missing-step count)
  stays **Sales-Order-wide** (sum across every saved template), per the spec's explicit Update 7
  clarification — it is NOT narrowed to only the currently-viewed template. To keep this aggregate
  correct under the Decision 29 scoping fix: for each `t` in `templatesData`, compute
  `computeProgress(t.flatDetails, effectiveMappingsForT)` using that template's own
  `filesForTemplate(t.templateCode)`-scoped mappings (Decision 29), then sum `completed`/`total` across
  all templates' results before deriving the displayed `%`. This replaces the current single call
  `computeProgress(allDetails, effectiveFileMappings)` (one global match across every template's steps
  and every selected PO's files combined) with N small per-template calls whose results are summed —
  same final shape (`{completed, total, pct}`), corrected inputs.
- **Rationale**: narrowing the header's aggregate to only the currently-viewed template would silently
  hide missing-document counts for templates not currently displayed — a regression the spec explicitly
  does not want (a user who only opens Template A's tab should still see the true total across A and B
  combined). Computing per-template first and summing after is the only way to keep both correctness
  (no cross-template contamination, Decision 29) and completeness (every template's contribution still
  counted) at the same time.
- **Alternatives considered**:
  - *Narrow the header's aggregate to only the currently-selected template*: rejected — contradicts the
    spec's explicit Update 7 requirement that the aggregate stay Sales-Order-wide; would also make the
    header's number change every time the user clicks a different toolbar chip, which is confusing for
    a value meant to represent the whole Sales Order's completion state.
  - *Keep the single global `computeProgress(allDetails, effectiveFileMappings)` call, since the sum of
    per-template completions equals a naive global count only when no cross-template contamination
    exists*: rejected — this is exactly the bug being fixed; a global match over-counts `completed`
    whenever a step in one template is (wrongly) satisfied by a file that actually belongs to another
    template's PO, so the sum must be computed from the corrected per-template inputs, not the old
    flattened one.

## Updated non-goals (Update 7)

- No backend change of any kind (no new/edited controller, service, repository, entity, DTO, or
  migration) — the PO↔Template link needed is already delivered by the existing
  `by-sales-id/{salesId}` response (Update 2) and the existing `poCode` field on each AVAILABLE FILES
  entry (Update 5).

## Update 8 (2026-07-27) — View Sales Order: Template Tree Toolbar + PO/Template-scoped Map status

Spec Update 8 adds FR-058..FR-063: `ViewSalesOrderPage.jsx`'s toolbar (`data-marker=
"template-tree-toolbar"`, lines 815-825) currently renders three hardcoded `Chip`s ("template
code1"/"template code2"/"All", not sourced from `templatesData`) with no `onClick`, and the Template
Checklist below (lines 872-899) stacks **every** saved template's tree in sequence via
`templatesData.map(...)`. The per-step "has document" status (`fileMappings`, lines 535-545) is
matched by `stepName` against `allDetails = templatesData.flatMap(t => t.flatDetails)` — every saved
template's steps flattened together — with no check that a candidate document's own PO belongs (via
`eutr_purchase_attachments`) to the template the step came from. This is the exact same class of
cross-template mismatch already found and fixed for `MapFilePage.jsx` in Update 7 (both screens share
the same underlying data shapes; `ViewSalesOrderPage.jsx` was modeled on `MapFilePage.jsx` as of
Update 4, before the Update 7 fix existed to clone).

## Decision 31 — Give the toolbar real per-template chips + click-to-select-one-template, defaulting to the first template (clone `MapFilePage.jsx` verbatim)

- **Decision**: Add a `selectedTemplateCode` state to `ViewSalesOrderPage.jsx`, initialized `null`,
  cloned from `MapFilePage.jsx` line 360. Add a default-first-template `useEffect` cloned verbatim
  from `MapFilePage.jsx` lines 500-509 (runs whenever `templatesData` changes: if there's no previous
  selection, or the previous selection no longer exists in `templatesData`, fall back to
  `templatesData[0].templateCode`; if `templatesData` is empty, `selectedTemplateCode` is `null`).
  Replace the toolbar's 3 hardcoded `Chip`s (lines 822-824) with `templatesData.map(t => <Chip
  label={t.templateName} variant={t.templateCode === selectedTemplateCode ? 'filled' : 'outlined'}
  onClick={() => setSelectedTemplateCode(t.templateCode)} />)`, cloned from `MapFilePage.jsx` lines
  1145-1187 minus the `loadTemplatesData(...)` refetch call inside that `onClick` (spec FR-063 — this
  screen is read-only, no refetch needed). Replace the Template Checklist's `templatesData.map(...)`
  stacked-tree render (lines 872-899) with a single selected-template render, cloned from
  `MapFilePage.jsx` lines 1226-1231: `const t = templatesData.find(item => item.templateCode ===
  selectedTemplateCode) ?? templatesData[0]`, then render only `t.tree` (one `Box`/header/tree, not one
  per template).
- **Rationale**: this is a straight clone of already-shipped, already-working code in the sibling
  screen (Principle II) — `MapFilePage.jsx`'s toolbar/default-selection/single-tree-render logic is
  the concrete reference the spec explicitly asks View to match. Cloning verbatim (rather than
  re-deriving a similar-but-different implementation) minimizes the risk of the two screens drifting
  in subtly different ways for what the spec treats as one behavior.
- **Alternatives considered**:
  - *Keep rendering all templates' trees but visually highlight the "selected" one*: rejected — does
    not satisfy spec FR-059 ("chỉ hiển thị đúng cây của template được chọn"), and does not fix the
    underlying cross-template Map-status contamination this update also needs to address (Decision
    33 below still requires per-template scoping regardless of how many trees are visible at once).
  - *Extract the toolbar/single-tree-render into a genuinely shared component used by both
    `MapFilePage.jsx` and `ViewSalesOrderPage.jsx`*: rejected for this update — `MapFilePage.jsx`'s
    toolbar is interactive (drives `loadTemplatesData` refetch, Step 2 editing state) while View's is
    purely a display selector; extracting a shared component now would require carefully separating
    the read-only display concern from Map File's write-capable one, a larger refactor than this
    update's scope (FR-058..FR-063) calls for. Cloning the JSX shape (not the component) is the
    smaller, lower-risk change consistent with how Update 4 already related the two files.

## Decision 32 — Add `poCode` to `ViewSalesOrderPage.jsx`'s `realAvailableFiles` builder (field already exists in the response, just not yet read)

- **Decision**: `ViewSalesOrderPage.jsx`'s `realAvailableFiles` `useMemo` (lines 512-527) builds one
  file object per document from `poReferenceDocs` (the `list-po-references` response), but does not
  currently copy `poDoc.poCode` onto the built object — even though `poDoc.poCode` is already present
  on every element of `poReferenceDocs` (same response shape `MapFilePage.jsx` consumes, and
  `MapFilePage.jsx`'s own builder has copied `poCode` since this feature's own Update 5, line 559).
  Add `poCode: poDoc.poCode` to the object literal at line ~522, immediately available for Decision 33
  below.
- **Rationale**: zero backend change — the field is already in the response payload today; this is a
  one-line additive fix to a frontend builder that simply never read a field it already had access
  to. Confirmed via direct code read of both pages' `realAvailableFiles` builders side by side.
- **Alternatives considered**: none — there is no other way to obtain this value that isn't already
  strictly worse (e.g. re-deriving PO from `stepNames` is not possible; the field is already present
  and named, it just needs to be read).

## Decision 33 — Scope the Template Checklist's "has document" status by PO→Template, cloning Update 7's `purchIdToTemplateCode`/`templateComputations` pattern verbatim

- **Decision**: Add a `purchIdToTemplateCode` `useMemo` to `ViewSalesOrderPage.jsx`, built from its
  already-loaded `purchaseAttachments` state (`new Map(purchaseAttachments.map(pa => [pa.purchId,
  pa.templateCode]))`) — identical in shape to `MapFilePage.jsx`'s own (lines 571-575, added in
  Update 7). Add a `templateComputations` `useMemo`, cloned from `MapFilePage.jsx` lines 582-605: for
  each `t` in `templatesData`, compute `filesForTemplate = realAvailableFiles.filter(f =>
  purchIdToTemplateCode.get(f.poCode) === t.templateCode)` (using Decision 32's newly-added `poCode`
  field), then match `t.flatDetails` against `filesForTemplate` by `stepName` to build that template's
  own `derivedFileMappings` — never against another template's files, even when `stepName` coincides.
  Feed the single selected-template tree (Decision 31) with `selectedTemplateComputation.
  derivedFileMappings` directly as its `fileMappings` prop (unlike `MapFilePage.jsx`, `ViewSalesOrderPage.jsx`
  has no local map/unmap overrides to merge in — Decision 21/Update 4 already established this screen
  has nothing else to combine, so no `mergeWithLocalFileMappings`-equivalent step is needed here), and
  `selectedTemplateComputation.filesForTemplate` as its `files` prop (replacing the current global
  `fileMappings`/`realAvailableFiles` props at lines 892-893).
- **Rationale**: identical reasoning to Update 7's Decision 29 (Constitution Principle III in its
  purest form — the PO→Template link is already client-side, no new endpoint/DTO/query needed) plus
  Principle II (clone the already-verified-correct pattern rather than re-deriving a parallel one for
  the sibling screen). Scoping by filtering-then-matching (not matching-then-filtering) structurally
  rules out cross-template contamination for the same reason it did for `MapFilePage.jsx`.
- **Alternatives considered**: same three alternatives Decision 29 already rejected for
  `MapFilePage.jsx` (post-hoc filter after a global match; new backend endpoint pre-grouping by
  template; fetch-time filtering of `poReferenceDocs`) — rejected here for the identical reasons, with
  no new considerations specific to the read-only screen.

## Decision 34 — Validation Summary: sum of per-template, correctly-scoped completions (clone Update 7's Decision 30 verbatim)

- **Decision**: Replace `ViewSalesOrderPage.jsx`'s current single-pass computation (`requiredDetails`/
  `mappedRequired`/`missingRequired`/`pct`, lines 580-588, computed once over the globally-flattened
  `allDetails`/`fileMappings`) with a per-template computation summed across all of `templatesData`,
  cloned from `MapFilePage.jsx`'s `progress` `useMemo` (Update 7, lines 707-721): for each `t` in
  `templateComputations` (Decision 33), filter `t.flatDetails` to `Required` steps (excluding
  `AUTO_SOURCES`, preserving `ViewSalesOrderPage.jsx`'s own existing exclusion from Decision 20/Update
  4 — `MapFilePage.jsx`'s own `computeProgress` helper does not exclude `AUTO_SOURCES`, a pre-existing,
  out-of-scope difference between the two pages not touched by this update), determine
  completed/missing per step from `t.derivedFileMappings`, then sum `completed`/`total` across every
  template and concatenate each template's own missing-step names into one combined `missingRequired`
  list for display. The aggregate stays Sales-Order-wide (every saved template contributes,
  regardless of which one is currently selected in the toolbar) per spec FR-062.
- **Rationale**: identical reasoning to Update 7's Decision 30 — narrowing the Validation Summary to
  only the currently-selected template would hide missing-document counts for templates not currently
  displayed (a regression the spec explicitly disallows, FR-062), and would make the number change
  every time the user clicks a different toolbar chip, confusing for a value meant to represent the
  whole Sales Order.
- **Alternatives considered**: same two alternatives Decision 30 already rejected for `MapFilePage.jsx`
  (narrow to only the selected template; keep one global match despite the cross-template
  over-counting bug) — rejected here for the identical reasons.

## Updated non-goals (Update 8)

- No backend change of any kind (no new/edited controller, service, repository, entity, DTO, or
  migration) — the PO↔Template link needed is already delivered by the existing
  `by-sales-id/{salesId}` response (Update 4) and the existing `poCode` field already returned by
  `list-po-references` (Update 5), just not yet read by `ViewSalesOrderPage.jsx`'s own builder.
- No refetch of PO/document data on toolbar click — unlike `MapFilePage.jsx`'s FR-048
  reload-on-click, `ViewSalesOrderPage.jsx` stays read-only with no concurrent edit happening on this
  screen, so the data already loaded when the page opened is sufficient (spec FR-063, Assumptions).
- No change to `AUTO_SOURCES`-exclusion behavior already established for this page in Update 4
  (Decision 20) — this update only re-scopes which files count as a match per template, not which
  steps count as "Required" for progress purposes.
- No new frontend file (no new use case, repository, or component) — the fix is confined to
  `ViewSalesOrderPage.jsx`'s existing state/derived-state (`useState`/`useEffect`/`useMemo`)
  computations.
- The header's/Validation Summary's aggregate progress is NOT narrowed to only the currently-viewed
  template — it remains a sum across every saved template, per spec Update 8's explicit
  clarification (Decision 34), mirroring the same rule already established for Map File (Update 7,
  Decision 30).
- No change to the "Purchase Orders đã chọn" table, the Edit/Map File button, or the Download button
  (Update 4) — this update only touches the Template Checklist toolbar/tree render and the Validation
  Summary's underlying computation.

## Update 9 (2026-07-27) — View button on AVAILABLE FILES (Map File), reusing `004-eutr-documents`'s file-content preview popup

Spec Update 9 adds FR-064..FR-068: each document in `MapFilePage.jsx`'s Step 2 AVAILABLE FILES list
currently has only an Edit button (opens `EutrDocumentsFormDialog` in edit mode, Update 6) — users
want to quickly view a file's actual content (PDF/Word/Excel/image) without opening the Edit popup
(which is about editing Type/Step/Value/Valid dates, not rendering file content) or downloading the
file. Investigation of the codebase found this exact capability already built and shipped for
`004-eutr-documents`'s own document grid.

## Decision 35 — Reuse `EutrFileViewerDialog.jsx` directly; add a View `IconButton` next to Edit

- **Decision**: `004-eutr-documents/index.jsx` already has a working "View" action on its grid: a
  `viewerFile` state (`{ open, fileId, fileName }`), an `onView` handler
  (`row => setViewerFile({ open: true, fileId: row.fileId, fileName: row.name })`), and a rendered
  `<EutrFileViewerDialog open={viewerFile.open} fileId={viewerFile.fileId}
  fileName={viewerFile.fileName} onClose={...} />`. `EutrFileViewerDialog.jsx`
  (`presentation/pages/eutr-documents/components/EutrFileViewerDialog.jsx`) wraps the shared
  `presentation/components/FilePreviewer.jsx` (already handles PDF via `<object>`, DOCX via
  `docx-preview`, XLSX via Luckysheet, and images inline, given base64 content), fetching content via
  `fetchFile={(idRef) => getEutrDocumentsFileByIdRefUseCase.execute(idRef)}` — i.e.
  `GetEutrDocumentsFileByIdRefUseCase` → `GET /api/eutr-documents/get-file-by-idref?idRef={fileId}`,
  returning `{ content (base64), contentType, fileName }`. The dialog also has its own simple
  Download button (blob-download from the already-loaded preview content, no zip/progress dialog) and
  a Close button — no Type/Step/Value/Valid-dates field, no Save action, matching spec FR-066/FR-067's
  read-only requirement exactly as-is, with zero new code needed for that constraint.

  `MapFilePage.jsx`'s own AVAILABLE FILES file objects (`realAvailableFiles`, built since Update 5)
  already carry `fileId: doc.fileId` on every entry — the exact field `EutrFileViewerDialog` needs.
  The fix: import `EutrFileViewerDialog` from `../eutr-documents/components/EutrFileViewerDialog`
  (same cross-feature presentation-to-presentation import already established for
  `EutrDocumentsFormDialog` in Update 6); add one new `viewerFile` state, cloned from
  `004-eutr-documents/index.jsx`'s own shape; add one new View `IconButton` (MUI `Visibility` icon,
  matching the icon `004-eutr-documents`'s own `EutrDocumentsActionCell.jsx` already uses for its View
  action) next to the existing Edit `IconButton` at `MapFilePage.jsx` lines 1434-1450, with
  `onClick={() => setViewerFile({ open: true, fileId: file.fileId, fileName: file.name })}`; render
  `<EutrFileViewerDialog open={viewerFile.open} fileId={viewerFile.fileId}
  fileName={viewerFile.fileName} onClose={() => setViewerFile(prev => ({ ...prev, open: false }))} />`
  once, alongside the page's existing `EutrDocumentsFormDialog` renders.
- **Rationale**: this is Constitution Principle III/II in their purest form — an already-working
  component, already-working endpoint, and an already-available field on the exact object being
  rendered. Building a second preview mechanism (or forking `EutrFileViewerDialog`'s JSX into a
  `005`-owned copy) would duplicate working code for zero benefit, directly against Principle III's
  reuse mandate; the View button's independence from Edit (spec FR-067) and its read-only guarantee
  (spec FR-066) are automatic consequences of reusing this specific dialog as-is, not something that
  needs to be separately implemented.
- **Alternatives considered**:
  - *Build a new, Map-File-specific preview dialog*: rejected — `EutrFileViewerDialog`/`FilePreviewer`
    already do exactly what's needed, with the same `fileId`-based fetch already available; a new
    dialog would duplicate rendering logic for PDF/DOCX/XLSX/images for no reason.
  - *Add view/preview fields directly inside the existing Edit popup (`EutrDocumentsFormDialog`)*:
    rejected — would blur a strictly-editing popup with a strictly-viewing one (spec FR-066 requires
    View to have no editable fields/Save action at all), and would require changing a component
    shared with `004-eutr-documents`'s own screen for a concern that screen doesn't need.
  - *Open the file in a new browser tab/window via a direct URL instead of a popup*: rejected — no
    public/direct URL exists for a stored document (content is fetched by id as base64 through the
    existing endpoint, not served at a stable URL); a new tab would also require re-implementing
    PDF/DOCX/XLSX rendering that `FilePreviewer` already provides inside a popup.

## Updated non-goals (Update 9)

- No backend change of any kind (no new/edited controller, service, repository, entity, DTO, or
  migration) — `GET /api/eutr-documents/get-file-by-idref` already exists, already implemented, and
  already DI-wired for `004-eutr-documents`'s own View action.
- No new frontend component, use case, repository, or domain interface — `EutrFileViewerDialog.jsx`,
  `FilePreviewer.jsx`, and `GetEutrDocumentsFileByIdRefUseCase` are all reused verbatim, unmodified.
- No change to the existing Edit button/popup (`EutrDocumentsFormDialog`, Update 6) — View is an
  additive, independent control; Edit's own behavior, props, and write flow are untouched.
- No change to Map status/File type/PO value badges (Update 5/7), Upload (Update 6), the toolbar
  (Update 5), or any Step 1 behavior — this update only adds one new button + one new popup render to
  Step 2's AVAILABLE FILES row markup.

---

## Update 10 (2026-07-27) — Real Download on View Sales Order: zip organized by Template

Spec Update 10 adds FR-069..FR-076: the Download button on `ViewSalesOrderPage.jsx`, currently a
no-op (FR-044/Update 4), must download a real zip named `{SalesId}-{CustomerCode}-{CustomerName}`,
containing one subfolder per saved template (named with the template's real display name), each
containing only that template's **"Mapped"** documents. Three scope-defining points were confirmed
directly with the requester before drafting the spec (recorded there as Assumptions, not
`[NEEDS CLARIFICATION]` markers): Mapped-only document scope, real-template-name folders, and an
always-clickable button that shows an error message when there is nothing to download.

## Decision 36 — Reuse the exact zip-building/naming mechanics already shipped for `AllCompliances`, not a new pattern

- **Decision**: A full-repo search for existing zip/download capability (before designing anything new)
  found `AllCompliancesController.cs`/`ComplianceDownloadService.cs` (`compliance-sys-api/src/
  ComplianceSys.Api/Controllers/`, `.../ComplianceSys.Application/Services/`) already implement
  "download a Sales Order's files as a folder-organized zip" end to end for a different, unrelated
  feature (`POST /api/all-compliances/download-so-zip`, folder = Product there). Three pieces of this
  existing code are an exact, verified match for what spec Update 10 needs and are cloned (not
  imported/reused as a dependency — see Decision 40 on why) into the new EUTR-owned action:
  1. `AllCompliancesController.SanitizeFileNamePart`/`BuildSoZipFileName` already produce **exactly**
     the root zip name format spec FR-070 requires — `{SalesId}-{CustomerCode}-{CustomerName}.zip`,
     with invalid filename characters replaced via `Path.GetInvalidFileNameChars()`.
  2. `ComplianceDownloadService.BuildFolderName` already replaces invalid filename characters in a
     free-text folder name the same way spec FR-071 requires for template names.
  3. `ComplianceDownloadService.GetUniqueEntryName` (folder-scoped) / `AllCompliancesController.
     GetUniqueFileNameFromSet` (flat) already implement the `name_1.ext`, `name_2.ext` counter-suffix
     disambiguation spec FR-075 requires for same-folder filename collisions.
  All three download entirely through `ISharepointService.DownloadByFileId(fileId)` (package
  `Shared.ExternalServices`, already DI-registered) into a `System.IO.Compression.ZipArchive` — the
  exact same interface/mechanism this update needs for EUTR documents' own `FileId` values (same
  SharePoint-backed storage, confirmed by `EutrDocumentsController.GetFileByIdRef`'s own use of the
  sibling method `ISharepointService.ReadFileWithMetaAsync` on the same interface, added for
  `004-eutr-documents`'s Update 10/this feature's own Update 9).
- **Rationale**: Constitution Principle II — the concrete reference for "download a Sales Order's files
  as a folder-organized zip" already exists in this exact codebase; cloning its proven naming/
  sanitization/disambiguation mechanics is strictly lower-risk than inventing parallel logic that could
  subtly disagree with the already-shipped, user-facing convention for the *same* root-zip-name format
  (a user who has downloaded an `AllCompliances` SO zip before would reasonably expect the same
  `{SalesId}-{CustomerCode}-{CustomerName}` shape from this feature's own zip).
- **Alternatives considered**:
  - *Take a dependency on `AllCompliancesController`/`ComplianceDownloadService` directly (call their
    methods instead of cloning them)*: rejected — those methods are `private`/`private static` on a
    controller/service that owns an unrelated domain (Compliance products, not EUTR documents/
    templates); reaching into another feature's private controller internals is worse coupling than a
    small, independent clone of a handful of pure string-sanitization/zip-naming helper methods (see
    Decision 40).
  - *Invent a new naming/sanitization scheme specific to this feature*: rejected — would risk a
    different root-zip-name shape than the one already shipped and presumably already familiar to users
    from `AllCompliances`' own SO zip download, for no benefit.

## Decision 37 — New endpoint carries zero EUTR business logic; client supplies the already-correct folder→file grouping

- **Decision**: `POST /api/eutr-documents/download-zip` (new action on the already-`ISharepointService`-
  injected `EutrDocumentsController`, per Decision 25/Update 9's established thin-proxy precedent)
  accepts `{ salesId, customerCode, customerName, folders: [{ folderName, files: [{ fileId, fileName }] }] }`
  and performs **no** re-derivation of which documents are "Mapped" or which PO belongs to which
  template (spec FR-055/FR-056) — `ViewSalesOrderPage.jsx` already computes this correctly client-side
  via `templateComputations`/`derivedFileMappings` (Update 7/8, Decisions 29/33), and re-implementing
  the same matching rule a second time, server-side, in a different language, would risk the two
  implementations silently drifting apart over time (the same category of risk this feature's own
  Update 7/8 fixed for the *first* case of duplicated matching logic). The endpoint's only job: for each
  folder, create a zip directory entry (even if `files` is empty — see Decision 39), and for each file
  in it, fetch via `_sharepointService.DownloadByFileId(fileId)` and write it into that folder's zip
  entry (client-supplied `fileName` used directly — no separate SharePoint metadata lookup needed,
  since `list-po-references`' response already carries a real file name for every entry the client
  builds `folders` from).
- **Rationale**: this mirrors an already-accepted precedent in the very code this update clones from —
  `AllCompliancesController.InitiateDownloadMultipleFiles`/`DownloadMultipleFiles` already accept a
  raw, client-supplied `FileIds: string[]` list with **zero** server-side re-validation of "should this
  file be included" business rules; the server's job there, too, is purely "fetch what I'm told, zip
  it, stream it back". Extending that same accepted shape to also carry a folder path per file (instead
  of only a flat file list) is a minimal, additive generalization, not a new trust model.
- **Alternatives considered**:
  - *Re-derive the Mapped/PO↔Template scoping server-side from `salesId` alone (fetch
    `eutr_purchase_attachments`/`eutr_templates`/`eutr_references` again, server-side)*: rejected — this
    is exactly the class of duplicated business logic Constitution Principle III/the feature's own
    Update 7/8 already moved away from; it would also require the backend to independently re-implement
    the "Mapped" step-matching rule a second time for zero benefit, since the frontend already computes
    it correctly for on-screen rendering.
  - *Pass only `salesId` + a list of `documentId`s (no folder grouping), and have the backend derive
    which template folder each document belongs to*: rejected — this still requires the backend to
    know the PO↔Template mapping (re-deriving Decision 29/33's logic) just to pick a folder name; no
    benefit over having the client (which already computed this) supply the grouping directly.

## Decision 38 — Server-side sanitization of names, even though the client already computes them

- **Decision**: `salesId`/`customerCode`/`customerName` (root zip name inputs) and each `folderName`
  are sanitized **server-side** inside the new action (cloning `SanitizeFileNamePart`/`BuildFolderName`,
  Decision 36), not trusted as pre-sanitized from the client, even though `ViewSalesOrderPage.jsx`
  already has real template names and Sales Order header fields available.
- **Rationale**: the server is the layer that actually writes filesystem-adjacent names (zip entry
  paths); trusting client-side sanitization would mean a future caller of this endpoint (or a modified
  frontend build) could send unsanitized names straight into `ZipArchive.CreateEntry`, which is the
  exact class of defensive-boundary validation Constitution's "only validate at system boundaries"
  guidance calls for — this endpoint's request body is a system boundary (any authenticated client can
  call it directly, not only through the UI).
- **Alternatives considered**:
  - *Trust the client's already-correct template names, skip server-side sanitization*: rejected —
    cheap to add (a few lines, already proven in `SanitizeFileNamePart`/`BuildFolderName`), and removes
    a class of bug (a template display name containing `/` or another invalid character breaking the
    zip's folder structure) that costs nothing to close given the exact fix already exists to clone.

## Decision 39 — Empty-folder and fully-empty-request handling

- **Decision**: A folder entry with `files: []` still gets a `ZipArchive.CreateEntry("{folderName}/")`
  empty-directory entry (spec FR-073) — the action does not skip folders with no files. If `folders`
  is empty, or every folder's `files` list is empty (spec FR-074 — nothing to download anywhere), the
  action returns `400 BadRequest` with a clear message instead of producing a technically-valid but
  empty zip. `ViewSalesOrderPage.jsx` checks this condition **client-side first** (it already knows the
  total Mapped-file count from `templateComputations` before ever calling the endpoint) and shows the
  same "không có tài liệu nào để tải" message without firing the network call at all — the
  server-side check is a defensive backstop for a direct API call bypassing the UI, not the primary
  path a real user hits.
- **Rationale**: FR-073/FR-074 are explicit spec requirements; checking client-side first avoids a
  wasted round-trip for the common "nothing to download" case (the same instinct already applied
  elsewhere in this feature, e.g. View's toolbar deliberately not refetching data it already has,
  FR-063) while the server-side check keeps the endpoint itself correct and self-defending regardless
  of caller.
- **Alternatives considered**:
  - *Skip empty folders entirely (don't create a directory entry for a template with zero Mapped
    documents)*: rejected — contradicts spec FR-073's explicit requirement that every saved template
    gets its own subfolder in the zip, even when empty, so a user can see at a glance which templates
    have no Mapped documents yet.
  - *Only check emptiness server-side (skip the client-side pre-check)*: rejected — would always cost a
    network round-trip even for the common "nothing to download" case, for no benefit given the client
    already has the exact count needed to decide this locally.

## Decision 40 — Clone the small helper methods into `EutrDocumentsController`, do not extract a shared util

- **Decision**: `SanitizeFileNamePart`-equivalent, `BuildFolderName`-equivalent, and
  `GetUniqueEntryName`-equivalent logic are each re-implemented as new, small, private methods scoped
  to `EutrDocumentsController` (or a private helper class local to it) — not extracted into a new
  shared/common util module referenced by both `AllCompliancesController` and `EutrDocumentsController`.
- **Rationale**: this is the second use of this exact shape of helper in this codebase (the first being
  `AllCompliancesController`/`ComplianceDownloadService`'s own internal duplication of similar
  filename-sanitizing/unique-naming logic between `DownloadMultipleFiles` and `BuildSoZipWithProgressAsync`
  themselves) — this codebase's own established precedent (confirmed in `004-eutr-documents`'s own
  research.md, which explicitly copied `ComplUploadService`'s unique-filename helper rather than
  extracting a shared util "vì đây là lần dùng thứ 2 duy nhất — YAGNI") is to clone a small helper on
  its second use rather than introducing a new shared module prematurely. Extracting a shared util
  would also require touching `AllCompliancesController`/`ComplianceDownloadService` (a different
  feature's owned files) merely to change how they call an internal helper — out of scope and
  unnecessary churn for an unrelated feature's working code.
- **Alternatives considered**:
  - *Extract a shared `ZipNamingHelpers` static class used by both controllers*: rejected for this
    update as premature — reasonable future cleanup if a *third* consumer appears, but not required now
    (YAGNI, consistent with the codebase's own stated precedent above); would also require modifying
    `AllCompliancesController`'s already-shipped, unrelated-feature code, which this update's scope does
    not call for.

## Updated non-goals (Update 10)

- No new controller, Application service, repository, entity, or migration — the new action lives
  directly on the already-existing, already-`ISharepointService`-injected `EutrDocumentsController`.
- No new authorization policy — reuses the already-DB-seeded `EutrDocuments.ReadAll` policy (same
  policy `list-po-references` already uses).
- No re-derivation of Map status/PO↔Template scoping server-side — the endpoint trusts the
  already-correct, already-loaded client-side computation (`templateComputations`) for which documents
  belong in which folder; it only fetches and zips.
- No dependency taken on `AllCompliancesController`/`ComplianceDownloadService` — their naming/
  zip-building mechanics are cloned (Decision 36/40), not imported or called into.
- No change to the async/SSE/temp-file-cache download infrastructure (`IDownloadProgressService`,
  `IMemoryCache`-based temp file caching) — this update's expected file volume doesn't need it (see
  plan.md Summary); the new action is fully synchronous, in-memory, single-request/response.

## Update 11 (2026-07-27) — Progress figures stay Required-only; fix an `AUTO_SOURCES`-exclusion inconsistency between Map File and View

Spec Update 11 (FR-077..FR-081) corrects a same-session misreading: an earlier draft of this update
mistakenly broadened `progress.total`/`progress.completed` (Map File's `data-marker="progress-bar"`, the
"Mapped" chip, and the footer's "Required: x/y" line) to count Optional steps as well as Required. The
requester corrected this immediately — the count MUST stay Required-only; "tổng"/"toàn bộ template"
("total"/"the whole template set") only ever meant the pre-existing cross-template aggregation (Update
7/FR-057), not a broader set of step types. The requester also asked for a full review of every variable
in both `MapFilePage.jsx` and `ViewSalesOrderPage.jsx` that counts mapped/missing step status, to make
them consistent across both screens.

## Decision 41 — Add the missing `AUTO_SOURCES` exclusion to `computeProgress()`, do not touch anything else

- **Decision**: The review (reading `MapFilePage.jsx` and `ViewSalesOrderPage.jsx` side by side) found
  four variables that count Required-step mapped/missing status:
  1. `MapFilePage.jsx`'s `computeProgress()` (backs `progress.total`/`progress.completed`, line ~105) —
     filters `d.requirementType === 'Required'` only; does **not** exclude `AUTO_SOURCES`.
  2. `MapFilePage.jsx`'s `missingRequired` (line ~816) — filters `requirementType === 'Required'` **and**
     `!AUTO_SOURCES.includes(d.takeFrom)`.
  3. `ViewSalesOrderPage.jsx`'s `requiredDetails`/`mappedRequired` (line ~649/654) — same two conditions
     as (2).
  4. `ViewSalesOrderPage.jsx`'s `missingRequired` (line ~662) — same two conditions as (2).
  Three of the four already exclude `AUTO_SOURCES`; only `computeProgress()` does not. This is fixed by
  adding the exact same condition to `computeProgress()`'s existing `required = details.filter(d =>
  d.requirementType === 'Required')` line: `details.filter(d => d.requirementType === 'Required' &&
  !AUTO_SOURCES.includes(d.takeFrom))`. `ViewSalesOrderPage.jsx`'s own four variables need **no** edit —
  they already implement the correct, consistent logic (Required-only, `AUTO_SOURCES`-excluded,
  PO/Template-scoped per FR-061/Update 8 Decision 33-34, aggregated across all saved templates).
- **Rationale**: without this fix, `progress.total - progress.completed` (Map File) would not always
  equal `missingRequired` on the same screen — if an unmapped Required step ever had a `takeFrom` in
  `AUTO_SOURCES`, the progress bar/chip would count it as "still outstanding" while the "Still missing X
  file" line would silently omit it, a visibly self-contradictory pair of numbers on the same screen.
  The same mismatch would also make Map File's aggregate progress diverge from View's for the same Sales
  Order, breaking spec SC-026's matching expectation. Cloning the exclusion already applied in 3 of the 4
  places (Constitution Principle II) is lower-risk than leaving one outlier or, worse, removing the
  exclusion from the other three to "simplify" — removing it would be a behavior change to
  `missingRequired`/View's variables, which the requester did not ask for and which are already correct.
- **Alternatives considered**:
  - *Leave `computeProgress()` as-is (no exclusion), since `AUTO_SOURCES` never matches real data
    today*: rejected — the requester explicitly asked for a review-and-fix, not just a note; leaving a
    known, quiet inconsistency in place would resurface silently if `AUTO_SOURCES` values ever populate
    real data again (e.g. a future D365 auto-detect feature), exactly the kind of latent bug this
    review's purpose was to surface and close.
  - *Remove the `AUTO_SOURCES` exclusion from `missingRequired`/View's variables instead, to match
    `computeProgress()`'s current (unfiltered) behavior*: rejected — this would be a real behavior change
    to 3 already-correct variables that the requester never asked to change, purely to make the one wrong
    variable "consistent" in the opposite direction; the fix should converge on the already-correct
    majority, not the one outlier.
  - *Extract a shared `isCountableRequired(detail)` helper used by all four variables*: considered
    reasonable for a future cleanup, but out of scope for this one-line fix — none of the four variables
    currently share a helper for this condition (each inlines its own filter), so introducing one now
    would touch more surface area than this fix requires (YAGNI, consistent with this feature's own
    established precedent of not extracting shared utilities on their second/third use, see Decision 40).

## Updated non-goals (Update 11)

- No broadening of `progress.total`/`progress.completed` to include Optional steps — the count stays
  Required-only, per the requester's correction.
- No change to `missingRequired` (Map File) or to any of `ViewSalesOrderPage.jsx`'s `requiredDetails`/
  `mappedRequired`/`missingRequired`/`pct` — all four were confirmed already correct by this review.
- No new backend endpoint, DTO, migration, or policy — this is a single client-side filter-predicate
  edit inside an already-existing function.
- No shared helper/utility extraction for the `AUTO_SOURCES` condition — out of scope for this fix
  (see Decision 41's rejected alternatives).
