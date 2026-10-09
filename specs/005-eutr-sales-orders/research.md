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

## Update 12 (2026-07-27) — Progress column on Overview: real per-row progress, batched across the page

Spec Update 12 (FR-082..FR-086) replaces `SalesOrderOverviewPage.jsx`'s fixed `DEMO_PROGRESS` constant
with real, per-`salesId` progress, computed with the **exact same formula** `MapFilePage.jsx` uses for
its own `progress` (`computeProgress()`, Required-only, `AUTO_SOURCES`-excluded, PO/Template-scoped per
FR-055/FR-056) — FR-082 explicitly forbids "defining a separate formula for Overview". The hard
constraint is FR-085: this must be computed for every row on the current page (`pageSize`, default 100)
via a **batch** load, not one API round-trip per row (N+1), mirroring the batching precedent already
established for the Template column (`GetTemplatesBySalesIdsUseCase`, Update 1).

Investigation (see plan.md Summary/Technical Context) found the existing Template-column batch endpoint
(`POST /api/eutr-purchase-attachments/by-sales-ids`) is unsuitable to reuse as-is for this: it returns an
already-`DISTINCT`, aggregated `{SalesId, TemplateCode, TemplateName}` (no `PurchId`), while
`computeProgress`'s per-template scoping (via `templateComputations`, Update 7) needs the raw
`PurchId → TemplateCode` link to know which PO's documents belong to which template. Likewise, there is
today no way to fetch more than one template's full step-detail tree in a single HTTP round trip — both
`MapFilePage.jsx` and `ViewSalesOrderPage.jsx` resolve each distinct `TemplateCode` with 2 sequential
calls per code (`get-all` filtered by `Code`, then `GetById`). Doing this per Overview row, for up to 100
rows, would be the exact N+1 shape FR-085 prohibits.

### Decision 42 — Extract `AUTO_SOURCES`/`computeProgress`/per-template file-scoping into a shared util; `SalesOrderOverviewPage.jsx` becomes a 3rd consumer, not a 3rd copy

- **Decision**: Create `compliance-client/src/presentation/pages/eutr-sales-orders/utils/
  progressUtils.js` (colocated the same way `utils/treeUtils.js` already is, per the existing
  page-local `utils/` convention), exporting `AUTO_SOURCES`, `computeProgress(details, fileMappings)`
  (moved verbatim from `MapFilePage.jsx`), and a new `buildTemplateComputations(templatesData,
  filesByPurchId, purchIdToTemplateCode)` helper that generalizes the per-template `derivedFileMappings`/
  `filesForTemplate` grouping already duplicated between `MapFilePage.jsx` (Update 7) and
  `ViewSalesOrderPage.jsx` (Update 8, its own clone). `MapFilePage.jsx` and `ViewSalesOrderPage.jsx` are
  refactored (behavior-preserving) to import from this shared module instead of keeping their own local
  `AUTO_SOURCES` constant/`computeProgress` function/inline `templateComputations` body;
  `SalesOrderOverviewPage.jsx` imports the same module as its 3rd consumer, for both Update 12 (progress)
  and Update 13 (its `buildDownloadFolders`-equivalent needs the same `derivedFileMappings`/
  `filesForTemplate` shape).
- **Rationale**: FR-082's "không định nghĩa công thức tính riêng cho Overview" (do not define a separate
  formula for Overview) is best guaranteed structurally, not just by convention — a 3rd hand-copied
  version of `AUTO_SOURCES`/`computeProgress` is exactly the kind of silent divergence Update 11 already
  had to fix once (one of 4 near-identical filter predicates had drifted). Decision 41 (Update 11)
  explicitly flagged extracting a shared `isCountableRequired`-style helper as "reasonable for a future
  cleanup, but out of scope for this one-line fix... YAGNI" — Update 12 is that future cleanup moment,
  since it adds a 3rd (and, via Update 13, a 4th call site) consumer of the same logic. This also matches
  Decision 40's own reasoning about the zip-naming helpers ("reasonable future cleanup if a third
  consumer appears") — the same threshold is now crossed here.
- **Alternatives considered**:
  - *Copy `computeProgress`/`AUTO_SOURCES` into `SalesOrderOverviewPage.jsx` a third time, leave
    `MapFilePage.jsx`/`ViewSalesOrderPage.jsx` untouched*: rejected — recreates the exact 3-copies
    drift risk Update 11 fixed once already; a future formula change (e.g. a new exclusion rule) would
    again require finding and editing 3 (soon 4, with Update 13) separate inline copies instead of one.
  - *Leave the extraction for a later update, ship Overview's progress with its own inline copy for
    now*: rejected — Update 12's own FR-082 explicitly calls out reusing "đúng công thức" (the exact
    formula), and this feature's own track record (Update 11) shows inline duplication of this exact
    logic silently drifts; doing the extraction now while all 3 call sites are being touched in the same
    session is lower-risk than doing it later against 3 already-independently-evolved copies.

### Decision 43 — New batch endpoint: raw purchase attachments for many Sales IDs at once

- **Decision**: Add `POST /api/eutr-purchase-attachments/by-sales-ids-raw` to the already-existing
  `EutrPurchaseAttachmentsController` (policy `EutrPurchaseAttachments.Read`, reused — same policy as
  the existing `by-sales-ids`/`by-sales-id/{salesId}` actions), accepting `List<string> salesIds` and
  returning `List<PurchaseAttachmentDto>` — reusing the existing `PurchaseAttachmentDto` class
  (`{SalesId, PurchId, TemplateCode}`) as-is, since it already carries `SalesId` per row (added in
  Update 2 for the single-`salesId` `GetBySalesIdAsync`/`by-sales-id/{salesId}` action). New repository
  method `GetBySalesIdsAsync(IEnumerable<string> salesIds)` clones `GetBySalesIdAsync`'s existing SQL
  (`SELECT SalesId, PurchId, TemplateCode FROM eutr_purchase_attachments WHERE SalesId = @SalesId`)
  widened to `WHERE SalesId IN @SalesIds` — no `DISTINCT`, no join, same shape as the existing
  single-id query, just parameterized over a list. New service method
  `GetRawBySalesIdsAsync(IEnumerable<string> salesIds, CancellationToken ct)` is a thin pass-through,
  mirroring `GetTemplatesBySalesIdsAsync`'s own pass-through shape.
- **Rationale**: the existing `by-sales-ids` action's `DISTINCT ... INNER JOIN eutr_templates`
  aggregation (built for the Template column, Update 1) throws away `PurchId`, which is exactly the
  field `computeProgress`'s per-template PO-scoping (`purchIdToTemplateCode`, Update 7) needs; widening
  that existing action in place would break its current consumer (Template column expects
  aggregated `{SalesId, TemplateCode, TemplateName}`, not raw per-PO rows) — Principle III's "additive,
  don't break an existing consumer of a shared endpoint" rule (already applied identically in Update 5
  to `list-po-references`) argues for a new, small, additive action instead of changing the existing
  one's response shape. Reusing the existing `PurchaseAttachmentDto` class (rather than inventing a new
  one) follows Principle II — it's already exactly the right shape.
- **Alternatives considered**:
  - *Widen `by-sales-ids` to also return `PurchId`, drop the `DISTINCT`*: rejected — this is a breaking
    change to `SalesOrderOverviewPage.jsx`'s own existing Template-column consumer (`fetchTemplatesForRows`
    expects one deduped row per `{SalesId, TemplateCode}`, keyed by `templateName`); would force
    `SalesOrderOverviewPage.jsx` to re-dedupe client-side for the exact behavior it already gets for free
    from the server today, for no benefit over adding one new action.
  - *Call the existing singular `by-sales-id/{salesId}` once per row*: rejected outright — this is the
    literal N+1 shape FR-085 prohibits (up to 100 sequential/parallel calls for one page load).

### Decision 44 — New batch endpoint: full template details for many Template Codes in one round trip

- **Decision**: Add `POST /api/eutr-templates/by-codes` to the already-existing `EutrTemplatesController`
  (policy `EutrTemplates.ReadAll`, reused — the same "read many" policy already guarding `get-all`),
  accepting `List<string> codes` and returning `List<EutrTemplatesResponseDto>` (the same response class
  `GetById`/`get-all` already use, `Details` populated). New repository method
  `GetManyByCodesWithDetailsAsync(IEnumerable<string> codes)` clones `GetByIdWithDetailsAsync`'s existing
  2-query shape (header query, then details query) but widened from a single `Id` to a `Code IN @Codes`
  header query, then a single details query scoped to `WHERE d.TemplateId IN @Ids` (the header query's
  resulting `Id`s) — **2 SQL round trips total for however many distinct codes are requested**, not 2 per
  code. Details rows are grouped back onto their owning template client-side in the repository (by
  `TemplateId`), mirroring the existing single-template method's `template.Details = details.ToList()`
  assignment, generalized to a dictionary keyed by `Id`.
- **Rationale**: this is the single biggest N+1 risk in the feature — today, resolving one template's
  full tree costs 2 sequential calls (Code→Id via `get-all`, then `GetById`), and both `MapFilePage.jsx`
  and `ViewSalesOrderPage.jsx` already do this once per distinct `TemplateCode` for a single Sales Order.
  An Overview page of up to 100 Sales Orders could reference many distinct `TemplateCode`s (though
  typically far fewer distinct codes than rows, since templates are reused across Sales Orders) — without
  a batch endpoint, computing Progress for a full page would multiply an already-2-call-per-template cost
  across every distinct code needed by any visible row, all sequentially. A single new action, doing the
  Code→Id resolution and detail-hydration server-side for the whole requested set in one round trip each,
  collapses this to exactly 2 database queries regardless of how many codes are requested — the same
  reasoning already applied by this feature to `by-sales-ids-raw` (Decision 43) and by Update 1 to the
  original Template-column batch endpoint.
- **Alternatives considered**:
  - *Client calls the existing `get-all` (filtered by `Code`) + `GetById` loop, just with `Promise.all`
    across all distinct codes instead of per-row*: rejected — still 2×N HTTP round trips (N = distinct
    codes on the page), and still no server-side batching of the underlying SQL; a single new action is
    not meaningfully harder to add (it clones existing, already-working SQL almost verbatim) and removes
    both the round-trip multiplication and the awkward Code→Id indirection the client currently has to do
    per code.
  - *Extend `get-all`'s paged response to include `Details` when a `Code IN (...)` filter is used*:
    rejected — `get-all` is also used by other 003-eutr-templates screens expecting `Details` to stay
    `null` in the paged/list view (confirmed: `GetPagedAsync` never populates `Details`, only
    `GetByIdWithDetailsAsync` does) — conditionally changing that shape based on filter content would be
    a surprising, filter-dependent contract change to a shared, already-consumed endpoint (Principle III).

### Decision 45 — Reuse `list-po-references` unchanged; send the page-wide union of PO codes

- **Decision**: No backend change to `POST /api/eutr-documents/list-po-references` at all. Its request
  DTO already takes a flat `List<string> PoCodes` with no `SalesId` field, and its repository query
  (`GetDocumentsByPoCodesAsync`, `WHERE r.RefValue IN @PoCodes`) already groups its response purely by
  `PoCode`, with zero cross-sales-order coupling. `SalesOrderOverviewPage.jsx` calls it once per page
  load with the **union of every `PurchId`** returned by the new `by-sales-ids-raw` call (Decision 43)
  across all rows on the current page, then re-groups the flat response back to each row's own Sales ID
  client-side using the same `by-sales-ids-raw` data (`PurchId → SalesId`, and `PurchId → TemplateCode`
  for per-template scoping via `buildTemplateComputations`, Decision 42).
- **Rationale**: verified in research (see plan.md Technical Context) that this endpoint is already
  fully SalesId-agnostic — it was never scoped to "one Sales Order's POs" in its contract, only in how
  `MapFilePage.jsx`/`ViewSalesOrderPage.jsx` happened to call it (each with one Sales Order's own PO
  codes). Principle III requires reusing this as-is; there is no gap to fill here, only a new caller
  supplying a larger `PoCodes` array than before.
- **Alternatives considered**:
  - *Call it once per row (per Sales Order), like Map File/View do*: rejected — reintroduces N+1 for
    this specific call, defeating the entire purpose of Decision 43/44's batching.
  - *Add a `salesIds` variant of this endpoint that internally resolves POs and returns results grouped
    by SalesId*: rejected — unnecessary; the client already has (or will have, via Decision 43) the
    `PurchId → SalesId` link needed to do this grouping itself, and reusing the existing flat-by-PoCode
    contract avoids touching a `004-eutr-documents`-owned endpoint that three other features/screens
    already depend on unchanged.

### Decision 46 — Frontend orchestration: `fetchProgressForRows`, parallel to the existing `fetchTemplatesForRows`

- **Decision**: `SalesOrderOverviewPage.jsx` adds a second batch loader, `fetchProgressForRows(items)`,
  fired alongside (not instead of) the existing `fetchTemplatesForRows(items)` right after
  `fetchSalesOrders` lands a page of rows. It runs, per page load: (1) `by-sales-ids-raw` for all visible
  `salesId`s (Decision 43); (2) from that result, the distinct `TemplateCode`s across the whole page →
  `by-codes` (Decision 44); (3) from (1), the distinct `PurchId`s across the whole page →
  `list-po-references` (Decision 45, unchanged endpoint). All three run as soon as (1) resolves — (2)
  and (3) do not depend on each other, only on (1) — via `Promise.all`. Once all three land, a `useMemo`
  (or a plain reduce right after the 3 responses are set into state) computes, per `salesId`, its own
  `templatesData`-equivalent slice + `buildTemplateComputations` (Decision 42) + `computeProgress` summed
  across that Sales ID's own templates — the exact same per-template-then-sum shape `MapFilePage.jsx`'s
  page-level `progress` `useMemo` already uses (Update 7), just repeated once per row instead of once per
  page.
- **Rationale**: mirrors the already-established `fetchTemplatesForRows` pattern (one batch call,
  keyed by `salesId` into state, fired once per page/search/pagination change) — Principle II favors
  extending an already-working in-file precedent over inventing a new data-loading shape. Running (2)
  and (3) off of (1)'s result via `Promise.all` (not sequentially) keeps the added latency to "1 round
  trip, then 2 round trips in parallel" regardless of page size, matching SC-001's existing 3-second
  budget expectation for the whole screen.
- **Alternatives considered**:
  - *One combined backend endpoint that takes `salesIds` and returns fully-computed progress per Sales
    ID, doing all the joins/aggregation server-side*: considered, but rejected for this update — it
    would require re-implementing `computeProgress`/`AUTO_SOURCES`/PO-Template scoping as a second,
    server-side copy of logic that Principle II says should stay a single client-side source of truth
    (already relied upon identically by Map File/View); it would also be a much larger, EUTR-specific
    aggregation endpoint where the spec's own Update 12 clarification explicitly left "the exact number/
    kind of data calls" as a plan-time decision, not a mandate for a single monolithic endpoint. The
    3-call batch (raw attachments → templates-by-codes + po-references in parallel) is the smaller,
    additive, most reuse-favoring shape available given what already exists.

### Decision 47 — Three-way Progress cell state: empty vs. no-required-steps vs. computed vs. error

- **Decision**: The per-row computed result is one of 4 discriminated states, mirroring FR-083/FR-084's
  explicit requirement that "no template yet" and "template(s) exist but 0 Required steps after
  `AUTO_SOURCES` exclusion" render as two visibly different placeholders (neither is `0/0`/`0%`):
  `{status:'empty'}` (no `by-sales-ids-raw` rows at all for this `salesId` — same empty condition as the
  Template column's own FR-007b), `{status:'no-required'}` (has purchase-attachment rows, but every
  matched template's `flatDetails` yields zero Required-non-`AUTO_SOURCES` steps),
  `{status:'ok', completed, total, pct}` (the normal case), and `{status:'error'}` (this row's data
  could not be computed because one of the 3 batch calls failed — see Decision 48).
- **Rationale**: FR-083/FR-084 are explicit about needing 2 distinguishable empty-ish states, not one;
  encoding this as a small discriminated result (rather than overloading `total === 0` to mean two
  different things) keeps the render logic in `SalesOrderOverviewPage.jsx` a simple `switch`/lookup,
  the same shape already used for the Template column's own empty-state handling.
- **Alternatives considered**:
  - *Reuse `computeProgress`'s existing `{completed:0, total:0, pct:0}` return for both empty cases*:
    rejected — this is exactly what FR-084 says NOT to do ("không suy diễn thành 0% chưa hoàn thành");
    the two cases need to render distinguishably, so the data shape passed to the cell must already
    distinguish them, not be reverse-engineered from a single ambiguous zero.

### Decision 48 — Batch-failure granularity: a failed batch call errors every row on the current page's Progress cell, not the whole table

- **Decision**: If any of the 3 batched calls (Decision 43/44/45) rejects, `fetchProgressForRows` catches
  it once (same try/catch shape as the existing `fetchTemplatesForRows`) and marks every currently
  visible row's Progress cell as `{status:'error'}` — it does **not** throw up to a page-level error
  boundary, and it does **not** clear/replace the already-successfully-loaded Sales ID rows, Template
  cells, or Download buttons (FR-085's "không chặn phần còn lại của bảng" — other columns/rows keep
  working).
- **Rationale**: because Progress is computed by combining all 3 batched responses together, a genuine
  network/data-source failure in any one of them makes it impossible to compute Progress for **any** row
  on the current page (there is no partial-row fallback once the calls are batched) — so "every row
  affected" is the correct, honest scope for this failure mode, not an inconsistency with FR-085's intent.
  FR-085 requires errors to stay localized to the Progress cell/column, which this satisfies: Sales ID/
  Customer/Template/Download all remain fully functional even if this specific batch fails.
- **Alternatives considered**:
  - *Retry each of the 3 calls independently with per-call partial-success handling (e.g. show Progress
    only for rows whose `PurchId`s happened to be in a `list-po-references` response that partially
    succeeded)*: rejected as over-engineered for this update — `list-po-references`/`by-codes`/
    `by-sales-ids-raw` are single atomic HTTP calls with no partial-success response shape today; adding
    one would require backend changes out of scope for what is otherwise a zero-new-failure-mode batch
    reuse of existing/newly-additive endpoints.

## Updated non-goals (Update 12)

- No change to the Template column's existing `by-sales-ids`/`GetTemplatesBySalesIdsUseCase` behavior —
  `by-sales-ids-raw` (Decision 43) is a new, additive action, not a replacement.
- No server-side computation of Progress — the formula stays a single client-side source of truth
  (`progressUtils.js`, Decision 42), consistent with how `MapFilePage.jsx`/`ViewSalesOrderPage.jsx`
  already compute it.
- No new migration, no new table — every new/widened query reads `eutr_purchase_attachments`,
  `eutr_templates`, `eutr_template_details`, `eutr_steps`, `eutr_references`, `eutr_documents`,
  `eutr_reference_types`, all already read by this feature's prior updates.
- No per-row network call for Progress — everything is batched per page load (FR-085), consistent with
  the Template column's own existing batching.

## Update 13 (2026-07-27) — Download button on Overview: real per-row, on-demand zip download

Spec Update 13 (FR-087..FR-092) replaces the Overview grid's Download `IconButton` — which today has no
`onClick` at all (verified: the only action button on this row without a handler) — with the exact same
zip-download behavior already shipped for `ViewSalesOrderPage.jsx`'s Download button (Update 10), scoped
to the Sales Order of the clicked row. Unlike Update 12's Progress column, this is explicitly **not**
batched per page (FR-088) — the data needed to build one row's zip is fetched only when that row's
Download button is clicked.

### Decision 49 — Zero backend change; reuse `download-zip` exactly as Update 10 shipped it

- **Decision**: No change of any kind to `EutrDocumentsController.DownloadZip`/`EutrDownloadZipRequestDto`/
  `EutrDownloadZipFolderDto`/`EutrDownloadZipFileDto` (`compliance-sys-api`) or to
  `DownloadEutrSalesOrderZipUseCase.js`/`eutrDocumentsApi.js`'s `downloadZip` method
  (`compliance-client`) — all reused verbatim from Update 10.
- **Rationale**: verified this endpoint is already fully generic — it takes a client-supplied
  `{salesId, customerCode, customerName, folders[]}` payload and does not care which screen built it;
  `ViewSalesOrderPage.jsx`'s own `handleDownload`/`buildDownloadFolders` (Update 10) already prove the
  exact request shape works end to end. Principle III leaves nothing to change here.
- **Alternatives considered**: none seriously considered — this is the same reasoning already applied to
  every other "reuse an already-generic endpoint from a new caller" decision in this feature (e.g.
  Decision 45 above, or Update 9's reuse of `get-file-by-idref`).

### Decision 50 — Per-row, on-demand data pipeline (not the page-wide Progress batch)

- **Decision**: Clicking a row's Download button runs, only for that row's `salesId`: (1)
  `GetPurchaseAttachmentsBySalesIdUseCase` (the existing **singular** `by-sales-id/{salesId}` use case,
  Update 2 — already exists, unchanged) to get that row's raw `{purchId, templateCode}` pairs; (2) the
  new `by-codes` batch template-detail endpoint (Decision 44), called with just this row's own distinct
  `TemplateCode`s (typically a handful) — reused here as a single-row "batch of N codes" rather than
  introducing a third copy of the 2-call-per-template loop `MapFilePage.jsx`/`ViewSalesOrderPage.jsx`
  each already have; (3) `GetEutrDocumentsPoReferencesUseCase` (existing, unchanged) for this row's own
  `PurchId`s. The 3 results feed the same shared `buildTemplateComputations` (Decision 42) used by
  Update 12, producing this one Sales Order's `derivedFileMappings`/`filesForTemplate` per template, from
  which the `folders` payload (template name → Mapped files) is built exactly like
  `ViewSalesOrderPage.jsx`'s `buildDownloadFolders` (Update 10).
- **Rationale**: FR-088 explicitly requires on-demand, single-Sales-ID loading for Download — reusing
  Update 12's page-wide batched Progress data is not equivalent even when it happens to already be
  in-memory for the clicked row, because FR-088 additionally requires this data to reflect the state "at
  the moment the user clicks Download" (freshness), and because a user may click Download on a row whose
  Progress batch failed (Decision 48) or is still loading — Download must work independently of Progress
  succeeding. Reusing `by-codes` (Decision 44) here — rather than re-deriving a 3rd inline
  2-call-per-template loop — keeps template-detail fetching to exactly 2 implementations in the whole
  feature (the new batch endpoint, called either page-wide-batched or single-row-on-demand), not 3.
- **Alternatives considered**:
  - *Reuse whatever `templatesData`/`templateComputations` Update 12's Progress batch already computed
    for this row, if available*: rejected — couples Download's correctness to Progress having
    succeeded and being fresh, which FR-088/FR-091 don't want; Download must independently succeed or
    fail per row regardless of Progress's own state for that row.
  - *Clone `MapFilePage.jsx`/`ViewSalesOrderPage.jsx`'s existing 2-call-per-template-code loop a third
    time instead of reusing the new `by-codes` batch endpoint*: rejected — `by-codes` already exists
    (built for Decision 44) and is strictly fewer round trips even for a single row's handful of
    templates; reusing it here is pure Principle II/III reuse, not scope creep.

### Decision 51 — Per-row loading/disabled state as a `Set` of in-flight `salesId`s, not a single page-wide boolean

- **Decision**: A new `downloadingSalesIds` state (a `Set<string>`, not a single boolean) tracks which
  row(s) currently have an in-flight Download; the clicked row's `IconButton` shows a small
  `CircularProgress` in place of `DownloadIcon` while its own `salesId` is in the set (mirroring
  `ViewSalesOrderPage.jsx`'s own single-boolean `downloading` state, generalized to per-row), and the
  button itself is never `disabled` based on data-emptiness (FR-089 — always clickable up front, same
  as View).
- **Rationale**: FR-090 explicitly requires that one row's in-flight Download must not block search,
  pagination, or another row's Download click — a single shared boolean (as `ViewSalesOrderPage.jsx`
  uses, correct there since it only ever has one Sales Order/one Download button on screen) would
  incorrectly show every row as "downloading" the moment any one row starts, or would need to disable
  all other Download buttons meanwhile; a per-`salesId` `Set` isolates each row's own in-flight state.
- **Alternatives considered**:
  - *A single page-wide `downloading` boolean, disabling all Download buttons while any one is
    in-flight*: rejected outright — directly violates FR-090's explicit "không chặn... Download ở một
    dòng khác" requirement.

### Decision 52 — Empty-Mapped-files and failure handling mirror View's `handleDownload` exactly, per row

- **Decision**: Before calling `download-zip`, the same client-side pre-check `ViewSalesOrderPage.jsx`
  already does (Decision 39/Update 10 — `folders.length === 0 || !folders.some(f => f.files.length > 0)`)
  runs against the clicked row's own freshly-fetched `templateComputations`; if it trips, the same
  "không có tài liệu nào để tải" message (FR-089, reusing FR-074's exact copy) shows scoped to that row
  (e.g. a row-level `Snackbar`/inline alert, not a page-wide one), and `download-zip` is never called. A
  thrown error from any of the 3 fetch calls (Decision 50) or from `download-zip` itself is caught the
  same way `ViewSalesOrderPage.jsx`'s `handleDownload` catches it, surfaced against that row only
  (FR-091) — other rows' state, search, and pagination are unaffected.
- **Rationale**: FR-089/FR-091/FR-092 ask for byte-for-byte the same behavior already verified correct
  for View's Download (Update 10) — Principle II says clone the already-working, already-spec-verified
  pattern rather than inventing new empty/error copy or a new failure-handling shape for Overview.
- **Alternatives considered**: none — this is a direct, intentional clone of an already-shipped, already
  spec-required behavior; no alternative shape was considered worth evaluating.

## Updated non-goals (Update 13)

- No new backend endpoint, DTO, migration, or policy — `download-zip` is reused byte-for-byte from
  Update 10.
- No batching of Download's data fetch across rows — FR-088 explicitly requires on-demand, single-row
  loading, the opposite of Update 12's Progress batching.
- No change to `ViewSalesOrderPage.jsx`'s own Download wiring — it keeps its already-shipped
  `buildDownloadFolders`/`handleDownload`, now calling into the same shared `buildTemplateComputations`
  util (Decision 42) rather than its own inline copy, but with identical behavior/output.
- No write of any kind to `eutr_documents`/`eutr_references`/`eutr_purchase_attachments` from this
  interaction (FR-092), consistent with every other read-only Download path already shipped.

## Update 14 (2026-07-28) — Preserve Overview's search/page when Back-navigating from Map File or View

Spec Update 14 (FR-093..FR-099) fixes a reported bug: filtering Overview to "SO004957", opening Map
File or View, then pressing Back returns to Overview with the search box empty and the full,
unfiltered list. Root cause, confirmed by reading the actual source: `SalesOrderOverviewPage.jsx`
keeps `search`/`page`/`pageSize` as plain local `useState` (lines 86/89-90) with no persistence
anywhere, and its mount effect (lines 386-390) unconditionally calls `fetchSalesOrders(0, pageSize,
'')` — page 0, empty search — every time the component mounts. `MapFilePage.jsx:900` and
`ViewSalesOrderPage.jsx:816`'s Back buttons both hard-navigate to the fixed route
`navigate('/eutr/sales-orders')`, which is a fresh push, not a history pop — so Overview always
remounts from that same blank slate, regardless of which Back button (in-app, or the browser's own)
sent the user there.

### Decision 53 — Persist `search`/`page`/`page-size` on Overview's own URL via `useSearchParams`, cloning the existing `page`/`page-size` convention

- **Decision**: `SalesOrderOverviewPage.jsx` adds `useSearchParams` (react-router-dom) and reads its
  initial `search`/`page`/`pageSize` state from the URL's `search`/`page`/`page-size` query params on
  first render (falling back to `''`/`0`/`DEFAULT_PAGE_SIZE` when absent) instead of the current
  hardcoded literals. Whenever the user changes search (inside the existing 500ms-debounced callback,
  so the URL updates once per settled keystroke burst, not per keystroke), page, or page size, the new
  values are written back with `setSearchParams(next, { replace: true })` — `replace: true` so typing
  or paginating updates the current history entry in place rather than pushing a new one per change.
- **Rationale**: this codebase already has exactly this pattern for pagination —
  `compliance-master/index.jsx` (lines 66-68, 309-346) reads `page`/`page-size` from
  `useSearchParams()` on mount and keeps them in sync with `{ replace: true }` on every pagination
  model change; the same pattern is also used by `compliance-management/index.jsx` and
  `compliance-detail/index.jsx`. Cloning it (Principle II) rather than inventing a new persistence
  shape keeps `SalesOrderOverviewPage.jsx` consistent with every other paginated list screen in this
  app, and — critically — makes the URL the single source of truth for "what was Overview showing",
  which is exactly what both the browser's native Back button and an in-app "smart back" (Decision 54)
  need to restore correctly (FR-094/FR-095/FR-097).
- **Alternatives considered**:
  - *`sessionStorage`, mirroring `dashboard/index.jsx`/`search-result/index.jsx`'s existing pattern
    (save on navigate-away, read on mount)*: rejected as the primary mechanism — it requires explicit
    save/read wiring on both ends and does not, by itself, make the browser's own Back button behave
    identically to an in-app Back button (FR-097), since the browser's Back button only ever restores
    the URL, not arbitrary `sessionStorage` keys a screen chose to write. The URL-based approach
    satisfies FR-097 automatically, with no separate code path for "the user pressed the physical
    Back button."
  - *Component-local state only, with no persistence at all (today's behavior)*: this is precisely
    the bug being fixed — rejected.
  - *Push a new history entry per keystroke instead of `{ replace: true }`*: rejected — would let a
    user land on 20 near-identical history entries after typing a 20-character search term, breaking
    the browser's Back button for unrelated navigation (each Back press would just retype one fewer
    character rather than leaving the page); `compliance-master/index.jsx`'s own precedent already
    established `{ replace: true }` as the fix for this exact class of problem.

### Decision 54 — "Smart back" on Map File/View: `navigate(-1)` when the visit came from Overview, else the existing fixed-route fallback

- **Decision**: `SalesOrderOverviewPage.jsx`'s two existing `navigate(`/eutr/sales-orders/${row.code}/
  map-file`)`/`navigate(`/eutr/sales-orders/${row.code}/view`)` calls (lines 569/591) additionally pass
  `{ state: { fromOverview: true } }` as the second argument. `MapFilePage.jsx` and
  `ViewSalesOrderPage.jsx` each add `useLocation` and replace their Back button's inline `onClick` with
  a small `handleBack`: if `location.state?.fromOverview` is `true`, call `navigate(-1)` (pops the
  browser history stack back to the exact prior Overview URL — search/page query params intact, per
  Decision 53); otherwise, fall back to the exact same `navigate('/eutr/sales-orders')` call already
  shipped since Update 3 (FR-033) — a fresh, default-list navigation.
- **Rationale**: `navigate(-1)` alone (unconditionally) would be unsafe — if a user deep-links or
  hard-reloads directly into Map File/View (no Overview entry in this tab's history to pop back to),
  popping history could leave the app entirely or land on an unrelated prior page. Gating it on a
  `location.state` flag set only by Overview's own navigation calls means `navigate(-1)` only ever
  fires when we know, for certain, that the immediately-prior history entry is Overview's own URL with
  the correct query params already on it — exactly the case FR-094/FR-095/FR-096 need, and exactly the
  case where `navigate(-1)` is safe. Falling back to the pre-existing fixed-route call for every other
  case (menu/breadcrumb entry, deep link, hard reload) is also precisely what FR-098 asks for: those
  entries show the default, unfiltered list, since there genuinely is nothing to restore.
- **Why this also satisfies FR-097 (in-app Back and the browser's own Back behave identically)**: the
  browser's native Back button does not run any of this code — it simply pops browser history itself,
  landing on Overview's URL with its query params intact (Decision 53 alone already guarantees this).
  The in-app Back button, once wired per this Decision, performs the exact same history-pop for the
  one case where it's safe to (`fromOverview: true`) — so both paths converge on identical behavior by
  construction, not by writing matching logic twice.
- **Alternatives considered**:
  - *Unconditional `navigate(-1)` with no fallback*: rejected — unsafe for deep-link/hard-reload
    entry, per Rationale above.
  - *Reconstruct Overview's URL explicitly (e.g. pass `returnTo=/eutr/sales-orders?search=...&page=...`
    as a query param on the Map File/View URL itself, and have Back navigate there with `replace:
    true`)*: considered as a more "explicit," non-history-dependent alternative. Rejected in favor of
    `navigate(-1)` because Decision 53 already keeps Overview's own URL correct at all times, making a
    second, parallel encoding of the same information (a `returnTo` param carried through a second
    screen's URL) redundant — it would need to stay in sync with Decision 53's query params by hand,
    a second source of truth for the exact same 3 values, with no benefit `navigate(-1)` doesn't
    already provide once gated by the `fromOverview` flag.
  - *Track "came from Overview" via `document.referrer` or `window.history.length` instead of an
    explicit `location.state` flag*: rejected — both are unreliable/browser-dependent signals for
    same-SPA in-app navigation depth, whereas `location.state` set by the exact `navigate()` call that
    sent the user here is precise and requires no heuristics.

### Decision 55 — Restored search/page always re-fetch live data, never replay a stale snapshot

- **Decision**: no caching of the previous fetch's `rows`/`templatesBySalesId`/`progressBySalesId` is
  introduced. On every mount — restored-from-URL or fresh-default alike — `SalesOrderOverviewPage.jsx`
  calls the exact same `fetchSalesOrders`/`fetchTemplatesForRows`/`fetchProgressForRows` chain it
  already calls today (Update 1/12), just seeded with the URL-restored `search`/`page`/`pageSize`
  instead of hardcoded defaults.
- **Rationale**: spec FR-096 explicitly requires the restored view to reflect the freshest real data,
  not a snapshot frozen at the moment the user navigated away to Map File/View — this matters
  concretely because a Save PO Mapping in Map File can change that very row's own Template/Progress
  cells (Update 1/12's own real-data requirements). Introducing any client-side cache here would
  reintroduce exactly the kind of "stale demo-like data" problem every prior Update in this feature
  (1/12/13) has deliberately avoided.
- **Alternatives considered**:
  - *Cache the previous page's rows/derived data (e.g. in a module-level variable or React Router's
    own loader cache) and skip refetching on restore*: rejected — directly conflicts with FR-096 and
    with this feature's established "always real, always fresh" precedent.

### Decision 56 — No new shared util or shared hook; the fix stays inline in the 3 files it touches

- **Decision**: no new `utils/` file (unlike Update 12's `progressUtils.js`) and no new custom hook is
  introduced for this fix — `useSearchParams`/`useLocation` usage and the small `handleBack` function
  are written directly inside each of the 3 already-existing files.
- **Rationale**: the amount of new logic per file is small (a handful of lines each), there are only 2
  Back buttons involved (not 3+ call sites of an identical formula, unlike Update 12's
  `computeProgress`/`buildTemplateComputations`, which had 3 independently-drifting copies before
  extraction) — extracting a shared `useSmartBack()` hook for exactly 2 near-identical call sites would
  add an abstraction layer without a proven 3rd consumer to justify it, the same "don't extract for a
  hypothetical future 3rd copy" restraint already applied by Update 10 (Decision 40, declining to
  extract shared zip-naming helpers) and reused here for the same reason.
- **Alternatives considered**:
  - *Extract a `useSmartBack()` hook shared by `MapFilePage.jsx`/`ViewSalesOrderPage.jsx`*: considered
    and rejected for now, per Rationale — revisit if a 3rd screen ever needs the same "back to
    Overview, preserving filters" behavior.

## Updated non-goals (Update 14)

- No new backend endpoint, DTO, migration, or policy of any kind — this update is 100% frontend
  routing/state, the same category as Update 11's pure frontend fix.
- No new shared util/hook file — the fix stays inline in the 3 files it touches (Decision 56).
- No caching/snapshotting of Overview's previous fetch results — every restore re-fetches live data
  (Decision 55, FR-096).
- No change to the menu/breadcrumb entry path into Overview — it continues to show the default,
  unfiltered, page-one list, exactly as it does today (FR-098).
- No change to `compliance-master/index.jsx` or any other screen outside this feature's own 3 files —
  their existing `useSearchParams` pattern is read as a design reference only (Decision 53), not
  imported or modified.

## Update 15 (2026-07-28) — AVAILABLE FILES panel on View, filtered by the selected step, reusing the Map File popup

Spec Update 15 (FR-100..FR-106) adds a new file-list panel to `ViewSalesOrderPage.jsx`'s right-hand
sidebar, styled after `MapFilePage.jsx`'s own Step 2 AVAILABLE FILES list, with one new interaction not
present on either screen today: clicking a step in the Template Checklist tree narrows the panel to
that step's own (and its descendants') Mapped documents, and clicking any template chip in
`template-tree-toolbar` clears that filter back to the full file set of the newly-active template.
Confirmed by re-reading the shipped `ViewSalesOrderPage.jsx`: its right sidebar (`Validation Summary`
card) currently renders only two pass/fail rows and a name-only "Steps missing files:" list (lines
~1036-1072 as of Update 14) — no file rows, no chips, no View button anywhere on this screen.
`MapFilePage.jsx`'s AVAILABLE FILES list (Update 5/7/9) already has the exact row shape this update
needs to copy visually (name + Map status/File type/PO value/Step name chips + View icon button), and
this feature's own shared `buildTemplateComputations` (Update 12, `utils/progressUtils.js`) already
computes, per template, both `filesForTemplate` (every document belonging to that template's own PO(s))
and `derivedFileMappings` (a step/detail-id → matched-file-ids map) — both already sitting in
`ViewSalesOrderPage.jsx`'s `selectedTemplateComputation` (Update 8/12), just never rendered as a file
list on this screen.

### Decision 57 — Reuse `EutrFileViewerDialog` a second time, not a new/forked preview component

- **Decision**: `ViewSalesOrderPage.jsx` imports `EutrFileViewerDialog` from
  `@presentation/pages/eutr-documents/components/EutrFileViewerDialog` (the exact alias path
  `MapFilePage.jsx` already uses) and adds one new `viewerFile` state
  (`{ open: false, fileId: null, fileName: '' }`, cloned verbatim from `MapFilePage.jsx`'s own Update 9
  state), rendering `<EutrFileViewerDialog open={viewerFile.open} fileId={viewerFile.fileId}
  fileName={viewerFile.fileName} onClose={...} />` once, near the bottom of the component (same
  placement pattern as `MapFilePage.jsx`).
- **Rationale**: Principle II/III — this is the same component, same props contract, already reused
  once (Update 9, for `MapFilePage.jsx`); reusing it a second time for a sibling read-only screen is a
  strictly smaller ask than Update 9's original reuse (View has no write paths to accidentally expose
  through it at all, unlike Map File which also has Upload/Edit on the same screen). No new file, no
  new component, no new backend call — `EutrFileViewerDialog` already performs its own
  `GetEutrDocumentsFileByIdRefUseCase` call internally.
- **Alternatives considered**:
  - *Build a second, `View`-only preview dialog*: rejected — would duplicate an already-correct,
    already-reused component for no behavioral difference; directly against Principle II/III.

### Decision 58 — Step-scoped filtering walks the already-built tree + `derivedFileMappings`; no new matching algorithm

- **Decision**: `ViewSalesOrderPage.jsx` adds one new state, `selectedStepId` (default `null`), set by a
  new `onSelect` prop threaded through the existing `ViewNode` tree (today `ViewNode` only wires a click
  handler to its collapse/expand arrow — `onSelect` is a second, independent click target on the row
  itself, added without touching the existing collapse/expand `onToggle` wiring). A new
  `availableFilesForPanel` `useMemo` resolves the panel's contents:
  - When `selectedStepId` is `null` → `selectedTemplateComputation.filesForTemplate` unfiltered
    (FR-101) — the exact same array `MapFilePage.jsx`'s own AVAILABLE FILES list source already is for
    its currently-viewed template.
  - When `selectedStepId` is set → walk the clicked node's own subtree (self + every descendant,
    already present as `node.children` on the tree `flatToTree` already builds, Update 2/4) collecting
    every node id in it, then union `selectedTemplateComputation.derivedFileMappings[id]` for each id in
    that set, de-duplicate by file `id`, and map the resulting id set back to file objects from
    `filesForTemplate` (FR-102).
  - Clicking any chip in `template-tree-toolbar` (the existing `onClick={() =>
    setSelectedTemplateCode(t.templateCode)}`, Update 8) additionally calls `setSelectedStepId(null)` —
    the same handler already re-fires on every click, including a click on the already-selected chip, so
    "click the same template again clears the filter" (FR-104) falls out of this for free, with no
    special-casing for "was it actually a different template."
- **Rationale**: Principle II/III — this is the exact same "build a lookup once, filter-before-match"
  shape this feature's own Update 7/8 already established for per-template scoping (`purchIdToTemplateCode`
  + `buildTemplateComputations`), applied one level deeper (per-step instead of per-template) over data
  that is already fully computed and already in memory; no new fetch, no new matching predicate invented
  from scratch. Walking `node.children` (already present on every tree node since `flatToTree` was
  introduced, Update 2) rather than re-flattening `flatDetails` and re-filtering by `parentId` chains
  avoids introducing a second tree representation just for this feature.
- **Alternatives considered**:
  - *Only show the clicked node's own directly-mapped files, not its descendants' too*: rejected — the
    requester's own description ("khi user click vào step ở tree, sẽ chỉ hiển thị file của step đó")
    reads naturally for leaf steps, but a parent/category node in this tree (e.g. a top-level template
    section with no document mapped directly to it, only to its children) would then always show an
    empty panel on click, which is a worse experience than aggregating its subtree — resolved as an
    explicit FR (FR-102) rather than left ambiguous, consistent with the spec's own "no reasonable
    default exists → resolve directly" limit-of-3-clarifications rule.
  - *Recompute `derivedFileMappings` scoped to the clicked step, from scratch, instead of reusing the
    already-built map*: rejected — `derivedFileMappings` already contains a complete, correct per-step
    entry for every detail id in the current template (Update 7/8's own scoping rules already applied);
    recomputing it would just re-derive the same values through a second code path, a divergence risk
    for no benefit.

### Decision 59 — `typeName` data-mapping fix, mirroring Update 8's `poCode` fix

- **Decision**: `ViewSalesOrderPage.jsx`'s `realAvailableFiles` builder (the `useMemo` that shapes
  `list-po-references`'s response into the objects `ViewNode`/the new panel consume) adds
  `typeName: doc.typeName` alongside the existing `stepNames`/`poCode`/`fileId` fields it already
  copies.
- **Rationale**: `list-po-references`'s response has carried `typeName` since this feature's own
  Update 5 (`EutrDocumentsPoReferenceItemDto.TypeName`, already consumed by `MapFilePage.jsx`'s own
  AVAILABLE FILES row for its "File type" chip) — `ViewSalesOrderPage.jsx`'s builder simply never copied
  it onto its own file objects, the exact same category of "already-returned, already-fetched field this
  screen doesn't yet read" gap Update 8 found and fixed for `poCode`. Without this one-line addition, the
  new panel's File type chip would have nothing real to render even though the data is already sitting
  in the already-fetched response.
- **Alternatives considered**:
  - *Add a second fetch just for File type*: rejected — the field is already present in a response this
    screen already calls; no new fetch is needed or justified.

## Updated non-goals (Update 15)

- No new backend endpoint, DTO, migration, or policy of any kind — `get-file-by-idref` (via
  `EutrFileViewerDialog`) is reused unmodified, exactly as Update 9 already shipped it for `MapFilePage.jsx`.
- No new shared util/hook file — the new `availableFilesForPanel` `useMemo`/`selectedStepId`/`viewerFile`
  state live directly inside `ViewSalesOrderPage.jsx`, the same "don't extract for a single consumer"
  restraint Update 14 (Decision 56) already applied.
- No change to `MapFilePage.jsx` of any kind — this update touches only `ViewSalesOrderPage.jsx`; Map
  File's own AVAILABLE FILES list, Edit/Upload actions, and existing View button (Update 6/9) are
  unaffected.
- No refetch of PO/document data on step click or template click — both interactions only change what
  is rendered from data already loaded when the screen opened (same read-only, no-refetch-on-click
  precedent Update 8 established for this screen's template-tree toolbar, FR-063).
- No Edit button, Upload button, or any write action of any kind on the new panel — the screen stays
  strictly read-only (FR-042).

## Update 16 (2026-07-28) — Overview's default (empty-search) row set scoped to Sales IDs with Template; search ignores the filter

Spec Update 16 (FR-107..FR-112) changes `SalesOrderOverviewPage.jsx`'s **default** row set (search box
empty, including initial load and after clearing a search) to only include Sales IDs that already have
at least 1 saved row in `eutr_purchase_attachments` (the same condition that already makes the Template
column non-empty, FR-007/FR-007a, as opposed to FR-007b's empty state) — while a non-empty search keyword
continues to match every Sales ID per the existing FR-011 rule, unfiltered by Template. Investigated
whether any existing mechanism already lets a D365-sourced, server-paginated list (`refType = 11`, via
`ComplDynamicsService.GetDynRefePagedAsync`) be intersected with a local MySQL table's key set:
`ComplDynamicsService.cs`'s `GetFromDynamics<T>` (lines 433-484) already does a **one-directional** local
→ D365 lookup (codes → names, an OR-chained `eq` filter, used for country/factory/customer/product name
enrichment elsewhere in this codebase) but is a separate, non-paginated bulk fetch, not wired into
`GetDynRefePagedAsync`'s own paged/filtered/sorted path. `BuildFilterString` (lines 119-197), however,
already OR-joins multiple `FilterRequest` entries that land in the same "code"/"name" bucket (line
189-190) — this existing behavior, unmodified, is exactly the mechanism needed to express "Sales ID in
this specific set" as a plain `FilterRequest[]` body, with zero change to `ComplDynamicsService`/
`DynController`/`ODataOperatorConverter`.

### Decision 60 — New read: distinct Sales IDs with a saved Template, on the already-existing `EutrPurchaseAttachments` stack

- **Decision**: Add `GetSalesIdsWithTemplateAsync()` (repository) → `GetSalesIdsWithTemplateAsync()`
  (service) → `GET api/eutr-purchase-attachments/sales-ids-with-template` (controller, policy
  `EutrPurchaseAttachments.Read`, reused) to the already-existing `EutrPurchaseAttachmentsController`/
  `Service`/`Repository` (Update 1/2/12). SQL: `SELECT DISTINCT SalesId FROM eutr_purchase_attachments
  WHERE TemplateCode IS NOT NULL;` — closest existing template is `GetTemplatesBySalesIdsAsync` (Update
  1, `SELECT DISTINCT ... INNER JOIN eutr_templates ... WHERE SalesId IN @SalesIds`), with the `SalesId
  IN @SalesIds` input predicate dropped (this read takes no input) and the `eutr_templates` join dropped
  (only `SalesId` itself is needed, not a template name). Returns a bare `List<string>` — no new DTO
  class.
- **Rationale**: Principle III — verified (same full-repo-search method as Update 1) that no existing
  action already returns "every Sales ID with a saved row, unscoped to a caller-supplied list" — every
  action on this controller today requires an input Sales ID or list. This is a small, additive gap-fill
  on files this feature already owns, not a new controller/service/repository/entity class.
  `TemplateCode IS NOT NULL` is kept explicit in the SQL even though it is always true today (the column
  is `NOT NULL`, spec FR-022) — same forward-consistency reasoning already applied once in this feature
  (Update 11's `AUTO_SOURCES` exclusion: correct-by-construction today, defensive if the schema
  constraint is ever relaxed).
- **Alternatives considered**:
  - *Reuse `by-sales-ids-raw` with an "all Sales IDs" sentinel value*: rejected — that action requires a
    non-empty input list (`if (ids.Count == 0) return []`) and returns raw, non-deduplicated
    `{SalesId, PurchId, TemplateCode}` rows; repurposing it would mean either changing its own contract
    (breaking its existing Progress-column consumer, Update 12) or adding special-case sentinel handling
    to a batch action that has no such concept today — a new, small, purpose-built action is simpler and
    safer.
  - *Compute this client-side by paging through `by-sales-ids-raw` for every Sales ID ever seen*:
    rejected — there is no existing "every Sales ID" list to seed that from without first querying D365
    for the full, unfiltered `refType=11` set (defeating the point of filtering it), and would be far
    more network calls than one small, indexed `SELECT DISTINCT`.

### Decision 61 — Reuse the existing generic reference endpoint's code-bucket OR-join for the whitelist filter; zero change to `ComplDynamicsService`/`DynController`

- **Decision**: When the search box is empty, `SalesOrderOverviewPage.jsx` calls the new
  `sales-ids-with-template` endpoint (Decision 60) once, then calls the **existing**
  `POST /api/dynamics/reference?refType=11` exactly as it already does today, except the `FilterRequest[]`
  body is built as `whitelist.map(salesId => ({ column: "Code", operator: "eq", value: salesId }))`
  instead of the empty array it sends today. `BuildFilterString`'s already-existing same-bucket `or`-join
  (line 189-190, verified unmodified) turns this into `(SalesId eq 'a') or (SalesId eq 'b') or ...` against
  D365 — the server-side `$skip`/`$top`/`$count` pagination `GetDynRefePagedAsync` already performs
  (`SetPaging`, `EnableCount`) then applies over exactly this filtered set, so `totalCount`/page count
  (FR-108) is correct with zero new pagination logic.
- **Rationale**: Principle III in its purest form — no gap exists on the D365-filtering side at all;
  `ODataOperatorConverter.ToODataOperator` already supports `eq` (verified: `eq`/`=`/`like` all map to
  `eq`), and same-bucket OR-joining is existing, already-tested behavior (it is exactly how the search
  box's own Code/Name "contains" filter already works today when a user's keyword could match either
  column). No new backend code of any kind is needed for this half of the update. When the search box has
  a keyword instead, this whole path is skipped — `refType=11` is called with today's unmodified FR-011
  filter, so Update 16 changes nothing about how search results are produced (FR-109).
- **Alternatives considered**:
  - *Add an `"in"` operator to `ODataOperatorConverter`*: rejected — confirmed unsupported today (only
    `eq/ne/gt/ge/lt/le`); adding it would be new, generic-endpoint-wide backend code for a need the
    existing `eq`-per-value + same-bucket-OR mechanism already satisfies without any change.
  - *Add a `restrictToSalesIds` parameter to `GetDynRefePagedAsync`/`DynController.ReferenceData`*:
    rejected — would touch the shared, generic reference endpoint used by many other `refType`s for a
    need expressible entirely through its existing, unmodified `FilterRequest[]` contract; a larger,
    riskier change for no functional benefit over Decision 61's approach.
  - *Fetch all of `refType=11` unfiltered, then filter to the whitelist client-side per page*: rejected —
    breaks correct pagination (FR-108: a page might yield fewer than `pageSize` rows after client-side
    filtering, with no way to know how many more matching rows exist on the next D365 page without
    fetching it first) and re-introduces exactly the kind of client-side-filtering-over-a-server-paginated-
    source problem this decision's OR-filter approach avoids entirely.

### Decision 62 — Frontend orchestration: fetch the whitelist once per empty-search entry, skip the network call when it's empty

- **Decision**: `SalesOrderOverviewPage.jsx` fetches the Decision 60 whitelist once whenever it
  transitions into the "search box empty" state — on mount, when the user clears the search box back to
  empty, or when Update 14's Back-navigation restore (FR-094) lands on an empty restored keyword (FR-110)
  — and reuses the same in-memory list across page/page-size changes within that same empty-search
  session (re-fetched again on the next such transition, not cached indefinitely, matching the spec's own
  edge case about staleness being resolved "at the next list load"). If the whitelist is empty, the
  fetch call to `refType=11` is skipped entirely and the table renders "No data" directly (FR-112) —
  sending zero `FilterRequest` entries to `refType=11` means "no filter" (existing behavior, matches
  everything), the opposite of what an empty whitelist should produce.
- **Rationale**: Mirrors this feature's own established "fetch once per page-load/search/pagination
  change, not per row" batching discipline (Update 1/12's `fetchTemplatesForRows`/`fetchProgressForRows`)
  — here applied to "once per entry into the empty-search state" rather than "once per page," since the
  whitelist itself does not depend on which page is being viewed (the same whitelist filter is sent
  regardless of `page`/`pageSize`; D365's own `$skip`/`$top` handles pagination over the filtered set).
  Explicitly short-circuiting the empty-whitelist case avoids the single most likely correctness bug this
  update could introduce (accidentally showing the full unfiltered list when it should show none).
- **Alternatives considered**:
  - *Re-fetch the whitelist on every page change too*: rejected as unnecessary extra network traffic —
    the whitelist does not change based on which page of D365 results is being viewed; only fetching it
    once per empty-search "session" (mount/clear/restore) is enough to keep pagination correct while
    avoiding redundant calls.
  - *Cache the whitelist across searches (never re-fetch once fetched)*: rejected — the spec's own edge
    case explicitly allows staleness to persist only until the next list load, not indefinitely; a
    long-lived cache could show a Sales ID that lost its last `eutr_purchase_attachments` row (or hide one
    that just gained its first) well past what the spec's leniency intends.

## Updated non-goals (Update 16)

- No change to `ComplDynamicsService.cs`, `DynController.cs`, or `ODataOperatorConverter.cs` — the
  same-bucket OR-join behavior this update depends on already exists and is already exercised by the
  search box's own Code/Name filter.
- No new DTO class — the new `sales-ids-with-template` endpoint returns a bare `string[]`.
- No new policy — reuses `EutrPurchaseAttachments.Read`, already seeded for this controller's other read
  actions.
- No batching/N+1 concern — this update adds exactly one new network call (the whitelist fetch), fired
  once per empty-search entry, not once per row or once per page.
- No change to search behavior — a non-empty keyword continues to use the exact same `refType=11` filter
  construction FR-011 already established, completely bypassing the new whitelist path (FR-109).

## Update 17 (2026-08-11) — Variants/Materials columns on Map File's Step 1 PO table, sourced from `refType = 20`

Spec Update 17 (FR-113..FR-120) adds two dynamic columns, **Variants** and **Materials**, to
`MapFilePage.jsx`'s Step 1 PO table (`TableContainer` under "Chọn Purchase Order") — sourced from a
second D365 reference type (`refType = 20`), filtered by both `InterCompanyOriginalSalesId` = the
current Sales ID and `RSVNRefPurchId` = each row's PO, with each matching record's `ProductVariant`
feeding Variants and `ItemId` feeding Materials, combined per PO into one comma-separated cell (e.g.
"M01, M02"). Investigation of `ComplDynamicsService.cs` (the same file Update 2/16 already touched)
found something unusual for this feature: **every piece this update needs already exists in code except
one missing dictionary entry.**

- `RSVNEutrSalesOrderPurchLines` (`compliance-sys-api/src/ComplianceSys.Domain/Dynamics/
  RSVNEutrSalesOrderPurchLines.cs`) already exists, with `ModelType => 20` and `FilterableFields`
  already including `InterCompanyOriginalSalesId`, `RSVNRefPurchId`, `ItemId`, `ProductVariant`, `Name`,
  `OrderAccount`, `Qty`, `RSVNEutrTemplate`.
- `ComplDynamicsService.MapDynamicsResponse`'s `switch` already has a full `case 20:` (lines 484-498)
  mapping `RSVNEutrSalesOrderPurchLines` → `ComplDynReferenceResponseDto { Id = InterCompanyOriginalSalesId,
  Code = ItemId, Name, Qty, CustAccount = OrderAccount, ProductVariant, EutrTemplate = RSVNEutrTemplate,
  RSVNRefPurchId }`.
- `ComplDynamicsService.MapSortColumn` already has `("code", "RSVNEutrSalesOrderPurchLines") =>
  "InterCompanyOriginalSalesId"` / `("name", "RSVNEutrSalesOrderPurchLines") => "ProductVariant"` (lines
  281-282) — sort-column support for this entity was already anticipated.
- `ComplDynReferenceResponseDto` (`ComplianceSys.Application/Dtos/Response/ComplDynReferenceResponseDto.cs`)
  already declares every field `case 20` assigns (`Code`, `ProductVariant`, `RSVNRefPurchId`,
  `InterCompanyOriginalSalesId`, `Qty`, `CustAccount`) — it compiles today, so no DTO change is needed.
- `DynController.ReferenceData` (`POST /api/dynamics/reference`) takes `refType` as a plain, unrestricted
  `[FromQuery] int` — no allowlist, no per-`refType` route — so no controller change is needed either.

The one gap: `ComplDynamicsService.EntityMappings` (lines 25-53), the dictionary
`GetDynRefePagedAsync` looks `refType` up in *before* running any query, has **no entry for key `20`** —
so `TryGetValue` fails today and `GetDynRefePagedAsync(20, ...)` returns an empty list unconditionally,
regardless of `case 20`'s correctness. This is the exact same class of bug the dictionary's own inline
comments already document being found and fixed twice before, for `refType=18` (feature
`009-compl-sales-order-missing`) and `refType=19` (feature `011-eutr-synchronize-data`) — a D365 entity
class, response-mapping `case`, and (for 19) even DTO fields all shipped correctly, but the endpoint stayed
silently dead because the one dictionary entry gating it was never added. `refType=20` is the same pattern,
just not yet caught/fixed by any prior feature.

### Decision 63 — Fix the verified `EntityMappings[20]` gap; zero other backend change

- **Decision**: Add one entry to `ComplDynamicsService.EntityMappings`:
  `{ 20, ("RSVNEutrSalesOrderPurchLines", "InterCompanyOriginalSalesId", "ProductVariant") },` — the
  `CodeColumn`/`NameColumn` pair chosen to match `MapSortColumn`'s own already-existing, already-correct
  assumption for this entity (lines 281-282), so a future `sortColumn=code`/`sortColumn=name` request
  against `refType=20` resolves consistently with what the dictionary now says its "code"/"name" columns
  are. No entity class, `MapDynamicsResponse` case, DTO field, or controller action is touched — all four
  already exist and already compile correctly; this single dictionary entry is what makes `case 20`
  reachable for the first time.
- **Rationale**: Principle III in its most literal form — the "existing backend" to reuse is not just
  present, it is *already fully implemented*, gated only by one missing registration line. Filling exactly
  that gap (and nothing else) is the smallest possible change; touching `case 20`, the DTO, or the
  controller would be redundant edits to already-correct code. `InterCompanyOriginalSalesId`/
  `RSVNRefPurchId` — the two columns this feature's filter actually uses — are matched by
  `BuildFilterString`'s generic "other column" branch (neither name is `code`/`id`/`name`), the same
  already-proven mechanism `refType=16`'s `InterCompanyOriginalSalesId` filter already relies on since
  Update 2 (research.md Decision 10) — so the `CodeColumn`/`NameColumn` values in the new entry only matter
  for `code`/`name`-bucketed filters or sorting, never for this feature's own two filter columns.
- **Alternatives considered**:
  - *Leave `EntityMappings[20]` unregistered and add a dedicated new controller action/entity-specific
    endpoint instead*: rejected — would duplicate an already-fully-built generic path (entity class,
    response mapping, DTO fields) for no reason other than the one missing dictionary line; directly
    against Principle III.
  - *Register `refType=20` with `CodeColumn="RSVNRefPurchId"`/`NameColumn="Name"` (mirroring `refType=16`'s
    own `("RSVNEutrSalesOrderPurchases", "RSVNRefPurchId", "Name")` shape) instead of matching
    `MapSortColumn`*: rejected — would leave `MapSortColumn`'s own already-shipped `code`/`name` sort
    mapping for this entity (lines 281-282, `InterCompanyOriginalSalesId`/`ProductVariant`) inconsistent
    with what `EntityMappings` says those buckets mean, a latent bug for the first caller that ever sorts
    by `code`/`name` against `refType=20`. Matching the sort-column mapping avoids introducing that
    inconsistency, at zero extra cost.

### Decision 64 — Frontend: one new batched fetch per Sales ID, grouped client-side by PO (no N+1)

- **Decision**: `MapFilePage.jsx` adds one new `useEffect` (parallel to the existing `refType=16` PO-list
  effect, same `[salesId]` dependency), calling `getReferenceDataUseCase.execute(1, 500, 'Code', 'asc', 20,
  [{ column: 'InterCompanyOriginalSalesId', operator: 'eq', value: salesId }])` — filtered **only** by
  Sales ID, the same single-call-per-Sales-ID shape the existing `refType=16` PO-list effect already uses
  (not one call per PO/`RSVNRefPurchId`). The response is grouped client-side into a
  `Map<purchId, { materials: string[], variants: string[] }>` keyed by each item's `rsvnRefPurchId`,
  appending `item.code` (the D365 `ItemId`, mapped by `case 20`) to `materials` and `item.productVariant`
  to `variants` only if not already present for that PO (dedupe, preserve first-seen order). The Step 1
  table then reads each PO row's own `materials`/`variants` arrays from this map by `po.purchId`, joining
  each with `", "` for display (FR-116), and renders "—" when a PO has no entry (FR-118).
- **Rationale**: FR-117 explicitly mandates the no-N+1 batching rule already established for the Overview
  Progress column (spec FR-085) — one call per Sales ID, not one per PO/row. A page size of `500` (vs. the
  existing PO-list effect's `100`) is a deliberate, generous margin: one Sales Order can have several POs,
  each with several purchase lines, so the total row count for `refType=20` can exceed the PO count itself;
  `500` follows this codebase's own established convention of a single, non-paginated fixed page size for
  a per-screen (not per-grid) reference fetch (Update 2's `refType=16` call already does exactly this at
  `100`), rather than introducing this feature's first multi-page aggregation loop for a screen that has
  never needed one.
- **Alternatives considered**:
  - *One `refType=20` call per PO, filtered by both `InterCompanyOriginalSalesId` and `RSVNRefPurchId`*:
    rejected outright — this is the literal N+1 shape FR-117 prohibits; for a Sales Order with, say, 8 POs,
    this would be 8 additional round trips fired together on every Step 1 load, for data obtainable in one.
  - *Fetch once per Sales ID but skip client-side grouping, filtering the full array per PO at render
    time*: rejected as unnecessary repeated work — grouping once into a `Map` after the fetch resolves is
    the same total computation done once instead of once per rendered row, with no behavioral difference;
    this feature already uses the "build a lookup once, reuse at each call site" shape for other derived
    state (`purchIdToTemplateCode`, Update 7 Decision 29).
  - *Hard-cap page size at the existing `100` (matching the PO-list call) instead of `500`*: rejected as a
    silent-truncation risk for a Sales Order with unusually many purchase lines — a larger, still-bounded
    single page size costs nothing extra when the real row count is small (which is expected to be the
    common case) but avoids quietly dropping some POs' materials/variants when it is not.

### Decision 65 — Response field casing: `rsvnRefPurchId`/`productVariant`/`code` (camelCase of the PascalCase DTO), verify during implementation

- **Decision**: Frontend code reads `item.rsvnRefPurchId`, `item.productVariant`, and `item.code` (the
  `ItemId`/Material value, per `case 20`'s `Code = x.ItemId` mapping) off each `refType=20` response item —
  following this API's existing camelCase JSON convention (already relied on today for this same DTO's
  `item.code`/`item.name`/`item.orderAccount`/`item.qty`/`item.eutrTemplate` fields on the `refType=16`
  call, `MapFilePage.jsx` lines 409-415). Standard ASP.NET Core camelCase naming policy lowercases a
  leading all-caps run up to (but not including) the capital that starts the next word, so
  `RSVNRefPurchId` → `rsvnRefPurchId` (not `rSVNRefPurchId`) — but this feature has no existing frontend
  code reading an acronym-prefixed field from this DTO to confirm it by direct precedent, unlike the other
  three (`Code`/`ProductVariant`/single-leading-capital, already unambiguous either way). Flagged
  explicitly as a one-line manual verification step during implementation (log the raw response once, or
  check the Swagger/network-tab payload for one `refType=20` call) rather than treated as a settled fact.
- **Rationale**: Every other field this feature reads off this same generic reference endpoint already
  uses this exact casing convention with no transformation layer in `RestDynamicsRepository.js` (`return
  res.data` verbatim) — there is no reason to expect `RSVNRefPurchId` to be serialized differently from
  every sibling field on the same DTO. Calling this out as a verify-don't-assume step (rather than silently
  assuming it and moving on) is proportionate to it being this feature's first-ever consumption of a
  multi-capital-acronym-prefixed field from this DTO — a small, cheap check that avoids a silent
  `undefined`-grouping bug if the assumption is wrong.
- **Alternatives considered**:
  - *Add `PropertyNameCaseInsensitive`-style defensive lookup on the frontend (try both `rsvnRefPurchId`
    and `RSVNRefPurchId`)*: rejected — adds permanent complexity to guard against a naming-convention
    question this feature can answer once, cheaply, during implementation; every other field on this same
    endpoint is trusted at face value already, and this one does not need a different, more defensive
    standard.
  - *Rename the DTO/entity property server-side to avoid the acronym ambiguity entirely (e.g. `RsvnRefPurchId`)*:
    rejected — `RSVNRefPurchId` is already a shared, multi-feature D365 entity/DTO property name (also used
    by `case 16`/`case 19`); renaming it would be a breaking, unrelated change far outside this update's
    scope for a naming-style preference, not a functional necessity.

## Updated non-goals (Update 17)

- No entity class, `MapDynamicsResponse` case, DTO field, or controller action change — all four already
  exist for `refType=20`; the only backend edit is the one missing `EntityMappings` dictionary entry
  (Decision 63).
- No new frontend use case, repository, or API client method — reuses the existing, refType-parameterized
  `GetReferenceDataUseCase` → `IDynamicsRepository` → `RestDynamicsRepository` chain verbatim, the same
  chain the existing `refType=16` PO-list call already uses.
- No per-PO network call — exactly one new batched call per Sales ID (Decision 64), grouped client-side,
  matching FR-117's explicit no-N+1 requirement.
- No change to Step 1's tick/checkbox/Save PO Mapping logic (FR-120) — Variants/Materials are
  display-only additions to the existing PO table, not a new selection condition.

## Update 18 (2026-08-12) — Variants/Materials columns on View's Selected Purchase Orders table, cloned from Map File's Update 17

Spec Update 18 (FR-121..FR-128) fixes a gap found by reading `ViewSalesOrderPage.jsx`: its Selected
Purchase Orders table (`data-marker="selected-po-table"`, same marker name as `MapFilePage.jsx`'s Step
1 table) already renders **Variants**/**Materials** column headers, but the table body hardcodes the
literal JSX text `<Typography variant="body2">Variants</Typography>` / `Materials` for every row — no
data binding of any kind, unlike Map File's own `data-marker="selected-po-table"`, which has read real
per-PO data from `refType = 20` since Update 17. Both tables share the exact same underlying need (each
PO's `ProductVariant`/`ItemId` values from its own purchase lines), and `ViewSalesOrderPage.jsx` already
loads the same `poList` (from `refType=16`, filtered by `InterCompanyOriginalSalesId`) that
`MapFilePage.jsx` uses to key its own `poLinesByPurchId` lookup — so nothing new needs to be designed,
only cloned.

### Decision 66 — Clone Update 17's `refType=20` fetch/grouping/rendering into `ViewSalesOrderPage.jsx` verbatim; zero backend change

- **Decision**: `ViewSalesOrderPage.jsx` adds the exact same `EUTR_SALES_ORDER_PURCH_LINE_REF_TYPE = 20`
  constant, the exact same `useEffect` shape (`getReferenceDataUseCase.execute(1, 500, 'Code', 'asc', 20,
  [{ column: 'InterCompanyOriginalSalesId', operator: 'eq', value: salesId }])`, dependency `[salesId]`),
  and the exact same `poLinesByPurchId`/`poLinesLoading`/`poLinesError` state group Decision 64 already
  specified for `MapFilePage.jsx` — copied, not redesigned. The two hardcoded `Variants`/`Materials`
  `Typography` cells in the Selected Purchase Orders table are replaced with the same
  `(poLinesByPurchId.get(po.purchId)?.variants ?? []).join(', ') || '—'` / `materials` pattern Map File
  already uses, plus the same loading/error indicator sourced from `poLinesLoading`/`poLinesError`.
  `EntityMappings[20]` (Decision 63) needs no change — it already serves any caller, not just
  `MapFilePage.jsx`.
- **Rationale**: Principle II (clone proven patterns) and Principle III (reuse existing capabilities) both
  point the same direction here — Update 17 already solved this exact problem (fetch shape, filter
  columns, dedupe/join formatting, empty/error states) for the sibling screen reading the same PO/Sales
  Order data; inventing a second, independently-derived formula for View would risk the two screens
  silently drifting apart (e.g. a different join separator or dedupe order), directly undermining SC-065's
  explicit cross-screen consistency requirement. Since `ViewSalesOrderPage.jsx` already has its own
  `salesId`/`poList` in scope, no new prop, context, or shared hook is needed to make the clone work — a
  plain copy-and-adapt of the effect/state/render code is the smallest change that satisfies FR-121.
- **Alternatives considered**:
  - *Extract `MapFilePage.jsx`'s Update 17 fetch/grouping logic into a shared hook (e.g.
    `usePoLinesByPurchId(salesId)`) and have both screens call it*: considered stronger long-term hygiene
    (avoids two copies of the same `useEffect`/grouping code), but rejected for this update specifically —
    refactoring a working, already-shipped `MapFilePage.jsx` effect into a shared hook is a larger,
    riskier change than the requester's literal ask ("show the columns like Map File does"), and this
    feature has repeatedly deferred such extractions until a third consumer appears (e.g. `progressUtils.js`
    was only extracted at Update 12, once Overview became a third screen needing the same formula as Map
    File/View). If a third screen ever needs this same Variants/Materials logic, extracting a shared hook
    at that point — following the same precedent — would be the right call.
  - *Have `ViewSalesOrderPage.jsx` call a new batch-by-PO-list endpoint instead of re-filtering by
    `InterCompanyOriginalSalesId`*: rejected — would duplicate `EntityMappings[20]`'s existing, already-
    correct `InterCompanyOriginalSalesId`-based filter path (Decision 63) for no behavioral gain; View
    already has `salesId` in scope, so filtering by it directly (identical to Map File) is strictly
    simpler and avoids a second query shape for the same data.
  - *Fetch `refType=20` scoped to each row's `RSVNRefPurchId` individually (N+1) since View shows a
    small, already-loaded PO list*: rejected — FR-125 explicitly carries forward FR-117's no-N+1 rule
    regardless of how few POs a given Sales Order happens to have; consistency with Map File's batching
    approach is also required for SC-064.

## Updated non-goals (Update 18)

- No backend change of any kind — `EntityMappings[20]` (Update 17, Decision 63) already serves this new
  caller unchanged.
- No new entity class, DTO field, controller action, migration, or policy.
- No new frontend use case, repository, or API client method — reuses the exact same
  `GetReferenceDataUseCase` → `IDynamicsRepository` → `RestDynamicsRepository` chain Update 17 already
  wired for Map File.
- No per-PO network call — exactly one new batched call per Sales ID (Decision 66), grouped
  client-side, matching FR-125's explicit no-N+1 requirement.
- No change to View's read-only guarantee (FR-042), Edit/Map File, Download, Back, Template Checklist,
  Validation Summary, or AVAILABLE FILES (FR-128) — Variants/Materials are display-only additions to
  the existing table, not a new interaction.

### Decision 67 — Fetch the default template with the exact same paged-then-`GetById` call already used per real template chip, filtered by `IsDefault` instead of `Code`; zero backend change

- **Decision**: On click of the All chip, `ViewSalesOrderPage.jsx` calls
  `getPagingEutrTemplatesUseCase.execute(1, 1, 'Code', 'asc', [{ column: 'IsDefault', operator: 'eq',
  value: 1 }])` — the identical use case already called once per real template chip (lines 553-558,
  Update 4), with its filter swapped from `{ column: 'Code', ... }` to `IsDefault`. If a result comes
  back, `getEutrTemplatesUseCase.execute(templateSummary.id)` fetches its full detail tree, exactly as
  already done for every other template. Verified in
  `compliance-sys-api/.../EutrTemplatesRepository.cs`: `GetPagedAsync` already whitelists `IsDefault` as
  a filter column (`FilterMap["IsDefault"] = "t.IsDefault"`, line 47) and already applies
  `t.IsDeleted = 0`/`t.IsHide = 0` unconditionally to every call (line 55) — so no backend change of any
  kind is needed to satisfy FR-130's `IsDefault = 1`/`IsHide = 0`/`IsDeleted = 0` condition. Also
  verified: `ClearGlobalDefaultAsync`/`SetIsDefaultAsync` (same repository, `003-eutr-templates`) already
  enforce at most one global default at a time, so this query is expected to return 0 or 1 row; a 0-row
  result maps directly to FR-131's "no default template configured" state.
- **Rationale**: Principle III requires reusing what already exists before adding anything new — this
  is the purest form of that: the exact same 2-call shape, the exact same use cases, the exact same
  backend query path, only a different filter *value*. No new endpoint, DTO, or repository method is
  justified when the existing one already accepts the exact filter this feature needs.
- **Alternatives considered**:
  - *Add a new dedicated backend endpoint (e.g. `GET /api/eutr-templates/default`)*: rejected — would
    duplicate `GetPagedAsync`'s already-correct `IsDefault`/`IsHide`/`IsDeleted` handling for a single-row
    convenience that the existing generic paged endpoint already provides with one filter argument;
    Principle III explicitly discourages adding a new backend surface when an existing one already
    covers the need.
  - *Cache the default template for the lifetime of the page instead of refetching on every All click*:
    rejected — the requester's framing ("khi vào [All] sẽ tải...") describes a fetch-on-entry action, and
    every other toolbar interaction on this screen already re-derives its display from a fresh action
    (Update 8's per-click template switch, itself explicitly not requiring a refetch only because that
    data was already loaded at page-open, FR-063) — there is no already-loaded copy of the default
    template to reuse here, so a fresh fetch on each click is the simplest correct behavior and keeps the
    displayed default template current if an admin changes it in `003-eutr-templates` between clicks.

### Decision 68 — New pure function for filter-and-reparent, colocated in `utils/treeUtils.js`; union files across all templates for AVAILABLE FILES when All is active

- **Decision**: Add one new exported function to the existing `utils/treeUtils.js` (alongside
  `flatToTree`/`treeToFlat`/`removeNodeAndDescendants`, which it composes with), e.g.
  `filterFlatListByStepIds(flatList, keepStepIds)`: walks `flatList`, keeps only items whose `stepId` is
  in `keepStepIds`, and for each kept item whose `parentId` pointed at a *removed* item, rewrites
  `parentId` to that removed item's own nearest surviving ancestor (or `'0'` if none survives) —
  returning a flat list in the same shape `flatToTree` already expects, so the existing `flatToTree` call
  builds the All tree with no further changes. Separately, a new `useMemo` in `ViewSalesOrderPage.jsx`
  computes `allTemplatesFiles = templateComputations.flatMap(c => c.filesForTemplate)` (deduplicated by
  file `id`) for AVAILABLE FILES when `selectedTemplateCode === null` (All active) — a plain union of
  data `buildTemplateComputations` (Update 7/8/12) already computes per template, not a new fetch or a
  new per-template computation. "Has document" status for a surviving All-tree node is derived by
  checking, across every template in `templateComputations`, whether any node sharing that `stepId` has
  a non-empty `derivedFileMappings` entry (OR across templates) — reusing each template's own
  already-correct per-PO/per-template mapping rule (FR-055/FR-061) rather than recomputing it.
- **Rationale**: no existing utility in this codebase performs "filter a tree's flat list down to a
  subset while keeping surviving descendants reachable" — Decision requires one new function, but
  Principle II still applies to *where* it lives and *how* it's shaped: colocated with the other
  tree-shape utilities this feature already established, taking/returning the same flat-list shape
  `flatToTree`/`treeToFlat` already use, so it composes with them instead of introducing a second,
  divergent tree representation. Reusing `buildTemplateComputations`'s already-computed
  `filesForTemplate`/`derivedFileMappings` for both the file union and the has-document lookup avoids a
  second, parallel implementation of the PO/Template scoping rule that could silently drift from the
  one Update 7/8 already got right.
- **Alternatives considered**:
  - *Drop a step's entire subtree when the step itself doesn't exist in the SO's templates (no
    re-parenting)*: rejected — spec FR-133 explicitly requires surviving descendants to stay visible; a
    valid, present-in-the-SO step disappearing from the All view just because an ancestor category didn't
    happen to match would hide real data the user asked to see.
  - *Recompute "has document" for the All tree via a brand-new global StepId→files lookup on
    `poReferenceDocs`, independent of `templateComputations`*: rejected — would re-implement the PO/
    Template attribution rule FR-055/FR-061 a third time (after Map File and View's per-template views
    already implement it once each), risking exactly the kind of silent drift Update 11 already had to
    fix once; reusing `templateComputations` guarantees the All view's status matches what a user would
    see by clicking through each template individually and checking the same step.
  - *Build the All tree once from `templatesData` itself (union of every saved template's own steps)
    instead of starting from the default template*: rejected — this is a different feature from what was
    requested; the requester was explicit that All starts from the default template's own structure/
    ordering and only removes what the SO doesn't have, not "show every step across every saved
    template regardless of the default template."

## Updated non-goals (Update 19)

- No backend change of any kind — the default-template lookup reuses `GetPagedAsync`'s already-
  whitelisted `IsDefault` filter and already-unconditional `IsHide`/`IsDeleted` clauses (Decision 67) —
  zero new endpoint, DTO, entity, repository method, migration, or policy.
- No new frontend use case, repository, or API client method — reuses
  `GetPagingEutrTemplatesUseCase`/`GetEutrTemplatesUseCase` exactly as already wired for real template
  chips since Update 4.
- No change to FR-060's existing first-template default selection on page load — All only activates on
  explicit click (FR-138).
- No change to header/Validation Summary aggregate progress (FR-062) or the Download zip mechanism
  (Update 10) — both stay Sales-Order-wide regardless of All (FR-139).
- No change to View's read-only guarantee (FR-042) — All adds no write of any kind to `eutr_templates`,
  `eutr_template_details`, `eutr_purchase_attachments`, `eutr_references`, or `eutr_documents`.

## Update 21 (2026-08-12): Download zip gains an All folder — nested step tree, mirrored from the toolbar's All chip

> Covers spec FR-142..FR-151. No new entity, no new endpoint, no new policy, no migration — generalizes
> the one existing `download-zip` request DTO from a single-segment `FolderName` to an ordered
> `FolderPath`, and reuses Update 19/20's already-computed All-tree state (`ViewSalesOrderPage.jsx`) plus
> the same default-template fetch (Decision 67) for Overview's on-demand Download. See Decisions 69-70.

### Decision 69 — Generalize `EutrDownloadZipFolderDto.FolderName` (string) into `FolderPath` (ordered `List<string>`), sanitized per segment; zero new endpoint

- **Decision**: Rename/reshape the existing `EutrDownloadZipFolderDto.FolderName` (a single string,
  sanitized as one unit by `EutrDocumentsController.SanitizeZipNamePart`) into `FolderPath`, an ordered
  list of path segments from the zip root (e.g. `["Template A"]` for today's per-template folders,
  `["All", "Forest", "Plantation forest location map"]` for a nested All step folder). Server-side,
  `DownloadZip` sanitizes **each segment individually** with the exact same, unchanged
  `SanitizeZipNamePart` helper, then joins them with `/` to form the zip entry's directory prefix —
  everything downstream (`archive.CreateEntry($"{folderName}/")` for an empty folder, and
  `GetUniqueZipEntryName`'s per-folder filename disambiguation) is untouched, because both already treat
  their `folderName` input as a `/`-delimited path string and neither assumes it is exactly one segment
  deep (`GetUniqueZipEntryName` already calls `Path.GetDirectoryName`, which handles multi-level paths
  correctly today). Both existing callers (`ViewSalesOrderPage.jsx`'s `buildDownloadFolders`,
  `SalesOrderOverviewPage.jsx`'s inline `folders` builder) change their per-template entries from
  `{ folderName: t.templateName, files }` to `{ folderPath: [t.templateName], files }` — a 1-element
  array, functionally identical to today's single-segment behavior.
- **Rationale**: Principle III (reuse existing backend) and the endpoint's own established design
  (research.md Decision 37 — the server trusts the caller's folder grouping entirely, zero business
  logic) both point the same direction: the only genuinely new backend capability this update needs is
  "a folder can be nested," and the cleanest way to add that to an endpoint that already treats
  `folderName` as an opaque path-ish string is to make the nesting explicit as an ordered list, rather
  than overloading the existing string field with an implicit `/`-separator convention the caller would
  have to know to pre-join and the server would have to know to *not* sanitize away. Reshaping one
  existing field on a request DTO owned entirely by this feature (both call sites are inside
  005-eutr-sales-orders) is far cheaper than adding a second endpoint or a parallel nested-payload shape.
- **Alternatives considered**:
  - *Keep `FolderName` as a single string and let the client pre-join segments with `/`, changing
    `SanitizeZipNamePart` to skip `/` when sanitizing*: rejected — `Path.GetInvalidFileNameChars()`
    (used today to sanitize the whole string as one unit) already includes `/` and `\` on Windows, so a
    template name that legitimately contains `/` would collide with the new path-separator convention;
    an explicit array removes any ambiguity between "a literal `/` in a folder's own name" (which must
    still be sanitized away per segment) and "a path separator between nested folders" (which must not
    be sanitized away).
  - *Add a second, tree-shaped request field (`subFolders: EutrDownloadZipFolderDto[]` on
    `EutrDownloadZipFolderDto` itself, recursive) instead of flattening to a list of paths*: rejected —
    would require the controller to recurse when writing zip entries (new control flow) and would leave
    two different ways to express "a folder" in the same request (flat `Folders[]` for templates, nested
    `subFolders` for All); a single flat list of `{FolderPath, Files}` entries — one entry per tree node,
    already flattened client-side — keeps the controller's existing flat `foreach (var folder in folders)`
    loop completely unchanged, only touching how `folderName` is derived from each entry.
  - *Add a brand-new endpoint (e.g. `POST /api/eutr-documents/download-zip-with-all`) instead of changing
    the existing one*: rejected — Principle III discourages a second backend surface for what is still
    exactly the same "client supplies folder→file grouping, server fetches+zips" contract; the only
    change is the shape of one field on one request DTO used by this feature alone.

### Decision 70 — Frontend: flatten the already-computed All tree into folder-path entries; reuse Update 19's loaded state for View, add one on-demand fetch for Overview

- **Decision**: Add one new pure function to the existing `utils/treeUtils.js` (colocated with
  `flatToTree`/`filterFlatListByStepIds`), e.g. `flattenTreeToFolderEntries(tree, derivedFileMappings,
  filesById, parentPath)`: walks a tree (the same shape `flatToTree` already produces), and for every
  node emits one `{ folderPath: [...parentPath, node.stepName], files }` entry — `files` resolved from
  `derivedFileMappings[node.id]` (an array of document ids, the exact same field
  `allChipDerivedFileMappings` already computes per Update 19) looked up against a `Map<id, file>` built
  from `allChipFiles` (also already computed) — before recursing into `node.children` with the extended
  path. In `ViewSalesOrderPage.jsx`'s `buildDownloadFolders`, call this once as
  `flattenTreeToFolderEntries(allChipTree, allChipDerivedFileMappings, filesById, ['All'])` and append the
  result (plus a bare `{ folderPath: ['All'], files: [] }` fallback entry when the flattened list comes
  back empty, so the All folder always exists per FR-147) to the per-template entries already built. No
  new fetch is added to View's Download handler — `allChipTree`/`allChipDerivedFileMappings`/
  `allChipFiles` are already populated by Update 20's auto-load-on-mount effect (`loadDefaultTemplate`,
  Decision 67) by the time a user can click Download; if that fetch is still in flight or errored at
  click time (rare race — Download has no dependency on `defaultTemplateLoading`), `allChipTree` is
  simply empty and the All folder is built empty, which FR-147 already treats as an acceptable outcome
  rather than one requiring the Download click to block/await a fetch. `SalesOrderOverviewPage.jsx`'s
  per-row Download handler has no equivalent pre-loaded state (Overview renders no Template Checklist),
  so it gains one new on-demand call to the exact same 2-call chain `loadDefaultTemplate` already uses
  (`getPagingEutrTemplatesUseCase` filtered by `IsDefault`, then `getEutrTemplatesUseCase`), added to the
  existing `Promise.all` alongside the templates-by-codes/po-references calls already fetched there
  (Update 13) — wrapped so that a failure of *this one* call degrades to an empty All folder rather than
  failing the whole Download (the existing per-template folders must not regress because of it).
- **Rationale**: Principle II/III — `allChipTree`/`allChipDerivedFileMappings`/`allChipFiles` already
  correctly implement exactly the tree-filter-and-reparent and cross-template file-union rules this
  folder needs (Update 19, Decisions 67-68); re-deriving them a second way for Download would risk the
  same kind of silent drift Update 11 already had to fix once for progress figures. Flattening to
  `{folderPath, files}` entries — one per tree node — lets the existing flat `folders` array/backend
  contract (Decision 69) represent the nested structure with no new payload shape.
- **Alternatives considered**:
  - *Have View's Download handler always trigger a fresh `loadDefaultTemplate()` call and await it before
    building `folders`*: rejected — redundant with the auto-load already firing on mount (Update 20); the
    spec's own Update 21 clarification explicitly accepts an empty All folder when the default template
    isn't available, so blocking/awaiting a guaranteed-fresh fetch on every Download click buys no
    required behavior and adds latency/complexity Download doesn't need.
  - *Give Overview's Download handler its own new derived-state hooks mirroring View's `useMemo` chain
    (`soStepIds`/`allChipFlatDetails`/`allChipTree`/…)*: rejected — Overview's handler is a single
    imperative `async` callback (Update 13), not a component render path with memoized state; computing
    the same values as plain local variables inside that one callback (calling `filterFlatListByStepIds`/
    `flatToTree`/the new `flattenTreeToFolderEntries` directly, same as View's `useMemo` bodies do) reuses
    the exact same pure functions without forcing Overview to adopt View's `useMemo`-per-derived-value
    shape it has no other use for.
  - *Compute `stepId → files` directly from `poReferenceDocs`/`filesForSalesOrder` instead of going through
    `derivedFileMappings`*: rejected — would re-implement the PO/Template Mapped-status attribution rule
    (FR-055/FR-061) a further time; reusing `derivedFileMappings` (already computed by
    `buildTemplateComputations`, shared across Map File/View/Overview since Update 12) keeps the All
    folder's file grouping guaranteed-consistent with what Template Checklist/AVAILABLE FILES already
    show for the exact same Sales Order.

## Updated non-goals (Update 21)

- No new backend endpoint, policy, entity, table, or migration — `POST /api/eutr-documents/download-zip`
  is reused as-is; only one existing request DTO field is reshaped (`FolderName` → `FolderPath`).
- No change to `ComplianceDownloadService`/`AllCompliancesController` (the unrelated feature this
  endpoint's mechanics were originally cloned from, Decision 36) — this update only touches
  `EutrDocumentsController.DownloadZip` and its own request DTOs.
- No new frontend fetch on `ViewSalesOrderPage.jsx`'s Download click — reuses `allChipTree`/
  `allChipDerivedFileMappings`/`allChipFiles`, already populated by Update 20's mount-time
  `loadDefaultTemplate` effect.
- No change to the per-template folders' content, naming, or empty-folder/dedup rules (FR-071..FR-075) —
  the All folder is purely additive alongside them.
- No change to the "no Mapped documents anywhere → show a message, don't call the endpoint" check
  (FR-074/FR-089) — it still short-circuits before any folder (including All) is built or sent.

## Update 22 (2026-09-07): Download shows a choice popup (Combined All / By Template) instead of always packaging both

> Covers spec FR-152..FR-160. No backend change at all — `download-zip` already treats `folders` as an
> opaque, client-supplied list (Decision 37/69); this update only changes which subset of the
> already-computed `templateFolders`/All-folder entries (Update 21, Decision 70) the client assembles
> into that list, gated by a new small choice dialog. See Decisions 71-73.

### Decision 71 — New `DownloadFormatDialog.jsx`, modeled on the existing `ConfirmDialog.jsx` shape, not a new dialog pattern

- **Decision**: Add one new small presentation component,
  `presentation/pages/eutr-sales-orders/components/DownloadFormatDialog.jsx`, cloning
  `presentation/components/ConfirmDialog.jsx`'s existing `Dialog`/`DialogTitle`/`DialogContent`/
  `DialogActions` structure and prop shape (`open`, `onClose`, `onConfirm`) — the only genuinely new
  piece is a `RadioGroup` inside `DialogContent` with two `FormControlLabel`/`Radio` options, value
  `'combined'` (label **"Combined (All)"**) and `'byTemplate'` (label **"By Template"**), plus one new
  local `format` state (`useState(null)`, no option pre-selected). `DialogActions` keeps `ConfirmDialog`'s
  existing Cancel button unchanged, and its confirm button (relabeled **"Download"**) stays `disabled`
  until `format` is non-null, calling `onConfirm(format)` then closing. Both `ViewSalesOrderPage.jsx` and
  `SalesOrderOverviewPage.jsx` import this one shared component — it is not duplicated per screen.
- **Rationale**: Constitution Principle II (reference-pattern reuse) — a full repo/feature search
  (`004-eutr-documents`, `003-eutr-templates`, `presentation/components/`) found no existing
  "pick exactly one of two mutually exclusive options, then confirm" modal to reuse as-is (the only
  `RadioGroup` usage anywhere in the client is an inline form field in an unrelated legacy page, not a
  modal), but `ConfirmDialog.jsx` already establishes this codebase's lightweight two-button
  (Cancel/Confirm) modal shape and is already reused by `CloneTemplateDialog.jsx` — cloning its structure
  keeps the new dialog visually/behaviorally consistent with the one existing precedent instead of
  inventing an unrelated one. A single shared component (not one per screen) avoids duplicating the
  radio-option list/labels the spec fixes as exactly two (FR-153).
- **Alternatives considered**:
  - *Two separate buttons ("Download Combined" / "Download By Template") instead of a popup*: rejected —
    contradicts the spec's explicit requirement for a single Download entry point that opens a popup
    (FR-152), and would double the row/toolbar footprint for a choice made rarely per download.
  - *Extend `ConfirmDialog.jsx` itself with an optional `options` prop instead of a new component*:
    rejected — `ConfirmDialog` is a generic yes/no confirmation already reused elsewhere for unrelated
    single-action confirmations (`CloneTemplateDialog.jsx`); overloading it with a radio-choice mode
    specific to Download would couple an unrelated shared component to this one feature's needs.
  - *Pre-select one option as a "recommended" default (e.g. By Template, matching pre-Update-21
    behavior)*: rejected — the spec's own Update 22 Assumption states the popup presents both options
    "ngang nhau" (on equal footing) with no default marked; forcing an active choice (confirm disabled
    until one is picked) matches that intent more directly than a silently-pre-checked radio a user could
    miss.

### Decision 72 — `ViewSalesOrderPage.jsx`: Download button opens the dialog; `buildDownloadFolders` becomes format-aware, returning only the chosen folder set

- **Decision**: The Download button's `onClick` (currently `handleDownload` directly, line ~1104-1114)
  now opens `DownloadFormatDialog` (`setDownloadDialogOpen(true)`); its `onConfirm` calls the existing
  `handleDownload`, now accepting a `format` argument. `buildDownloadFolders` (currently lines 947-962)
  is changed from unconditionally returning `[...templateFolders, ...allFolders-or-fallback]` to a
  format-gated return: `format === 'byTemplate' ? templateFolders : (allFolders.length > 0 ? allFolders :
  [{ folderPath: ['All'], files: [] }])`. No new fetch is introduced by this change — `templatesData`/
  `allChipTree`/`allChipDerivedFileMappings`/`allChipFiles` are already loaded on mount (Update 4/20)
  regardless of which format the user eventually picks, since they also drive the always-visible
  Template Checklist/toolbar; the dialog only changes which of the two **already-computed** sets gets
  sent, never what gets fetched.
- **Rationale**: Principle III/reuse — every input `buildDownloadFolders` needs already exists in state
  by Update 21; the only change this update requires is a conditional at the point where the two
  already-built lists are concatenated, matching the spec's explicit framing that internal folder/file
  logic (FR-071..FR-075, FR-142..FR-148) is unchanged and only "how many/which folders get packaged"
  changes (FR-156).
- **Alternatives considered**:
  - *Compute both folder sets and let the backend discard the unwanted one via a `format` field on the
    request*: rejected — would require a backend change (a new discriminator field plus server-side
    branching) for a decision that is entirely about what the client chooses to send; Decision 69/37
    already established the server has and needs zero business-logic awareness of "All" vs "template".
  - *Skip building the unchosen set entirely (e.g. don't compute `allFolders` when `format ===
    'byTemplate'`)*: considered but not adopted — `templateFolders`/`allFolders` are cheap `useMemo`
    derivations over already-in-memory data (Update 7/8/19/21), evaluated once per relevant dependency
    change regardless of Download; skipping one based on a value only known after the dialog closes would
    need to move these from `useMemo` into the click handler for a negligible client-side compute saving,
    adding complexity FR-156 doesn't ask for.

### Decision 73 — `SalesOrderOverviewPage.jsx`: single per-row dialog state; skip the default-template fetch chain entirely when the user picks By Template

- **Decision**: Add one new state, `downloadDialogRow` (`{ salesId, customerCode, customerName } | null`,
  not a per-row `Set`/`Map`) — since only one modal dialog can be meaningfully open/interacted with at a
  time, a single value identifies which row's dialog is open without colliding with
  `downloadingSalesIds` (Update 13's existing per-row in-flight `Set`, unaffected). Clicking a row's
  Download `IconButton` now sets `downloadDialogRow` instead of calling `handleDownload` directly;
  `DownloadFormatDialog`'s `onConfirm(format)` calls the existing `handleDownload(salesId, customerCode,
  customerName, format)` (now taking a 4th argument) and clears `downloadDialogRow`. Inside
  `handleDownload`, the format gates two things: (1) the same `templateFolders`-vs-All-entries choice as
  View (Decision 72), applied to the handler's own inline builder; (2) — a genuine optimization Update 21
  did not have — the on-demand default-template 2-call chain (Update 21/Decision 70's addition to this
  handler's `Promise.all`) is only issued when `format === 'combined'`; when the user picks **By
  Template**, that fetch is skipped entirely, since its only consumer (the All-folder entries) will not be
  sent. The already-existing raw-purchase-attachments/by-codes/`list-po-references` calls run
  unconditionally either way, since both formats need them (per-template folders always need them; the
  Combined format's per-step Mapped-document union, FR-145, is built from the same `poReferenceDocs` these
  calls already fetch).
- **Rationale**: Principle III — `downloadingSalesIds` (per-row concurrency) and the new dialog's
  open/closed state are orthogonal concerns (which rows are fetching vs. which row's popup is showing) and
  keeping them as two separate, simply-typed pieces of state avoids overloading one structure to track
  both. Skipping the default-template chain for **By Template** is a direct, low-risk performance win
  enabled by the fact that Overview's Download (unlike View's) fetches everything on-demand at click
  time (FR-088) rather than having it already sitting in memory — there is no equivalent saving available
  on View, since its default-template data is already fetched on mount for the always-visible All chip
  regardless of Download (Decision 72).
- **Alternatives considered**:
  - *Key dialog state by `salesId` in a `Map`/object, allowing multiple simultaneous per-row popups*:
    rejected — a modal `Dialog` visually blocks the rest of the page while open; nothing in the spec asks
    for multiple simultaneous open popups across rows, and a single `downloadDialogRow` value is simpler
    and matches how a user actually interacts with one modal at a time.
  - *Always fetch the default-template chain regardless of format, matching Update 21's unconditional
    behavior, for consistency with View*: rejected — View's default-template data has a second consumer
    (the always-on-screen All chip/Template Checklist) that justifies fetching it unconditionally on
    mount; Overview's row has no such second consumer, so fetching it for a **By Template** download
    would be pure waste with no spec requirement forcing it, and FR-158's per-format empty-check already
    implies each format's own data need only be resolved for the format actually picked.

## Updated non-goals (Update 22)

- No new backend endpoint, controller, DTO, entity, table, migration, or policy — `download-zip` and its
  request DTOs (Decision 69) are reused completely unchanged; this update is a 100% frontend change.
- No change to the per-template or All-folder internal content rules (naming, Mapped-only filtering,
  empty-folder creation, duplicate-filename suffixing — FR-071..FR-075, FR-142..FR-148) — only which of
  the two already-correct folder sets gets included in a given download.
- No change to `downloadingSalesIds` (Update 13's per-row in-flight spinner state) — the new
  `downloadDialogRow` state is additive and orthogonal to it.
- No persisted/remembered "last chosen format" across downloads — every Download click re-opens the
  dialog with no option pre-selected (spec Assumption, Update 22).
- No change to View's mount-time default-template fetch (Update 20) — it continues to fire unconditionally
  regardless of Download, since the always-visible All chip/Template Checklist depend on it independently
  of Download.

## Update 24 (2026-09-18): Overview gains an ETD column, a Year/ETD Week search block, brown View/Download buttons, and a Delivery-date-descending default sort — matching `compliance-view`'s `ref-type = 11` screen

> Covers spec FR-161..FR-169. Investigation confirmed `SalesOrderOverviewPage.jsx` fetches its rows via
> a **different** backend path (`DynController`/`ComplDynamicsService`, the generic dynamics-reference
> lookup) than `compliance-view` (`AllCompliancesController`/`AllCompliancesService`), even though both
> read the same D365 entity `RSVNSalesOrderOpenInvoiceCogs` and both happen to key it as "`11`". So this
> update cannot simply copy `compliance-view`'s request payload verbatim into Overview's existing
> `getReferenceDataUseCase` call — the year/week operators (`inyear`/`inweeks`) and the `RsVnETD` field
> are meaningful to `AllCompliancesService` but not (yet) to `ComplDynamicsService`. Decisions 74-76 close
> that gap by reusing the exact same underlying utilities (`EtdWeekFilterBuilder`/`IsoWeekRange`,
> `DynamicModelService`) from a second call site, not by re-deriving the date math.

### Decision 74 — Add `RsVnETD` to `ComplDynReferenceResponseDto` and case-11 mapping; zero migration, zero new entity field

- **Decision**: `RSVNSalesOrderOpenInvoiceCogs.RsVnETD` (`Domain/Dynamics/RSVNSalesOrderOpenInvoiceCogs.cs:37`)
  already exists and is already declared in that entity's `FilterableFields` (line 24) — it is simply not
  yet copied onto the response DTO. Add one new nullable property, `public DateTime? RsVnETD { get; set; }`,
  to `ComplDynReferenceResponseDto` (same file/pattern as the existing `DeliveryDate` property), and add
  one new assignment, `RsVnETD = so.RsVnETD`, to `MapDynamicsResponse`'s `case 11:` branch
  (`ComplDynamicsService.cs:406-419`), alongside the existing `DeliveryDate = so.DeliveryDate` line.
- **Rationale**: this is the exact "already-returned-by-the-entity, not-yet-projected-onto-the-DTO" gap
  class this feature has already found and fixed twice (Update 5's `stepIds`/`refType`/`typeName` widening
  of `EutrDocumentsPoReferenceItemDto`; Update 8's discovery that `poCode` was already available but
  unread) — Principle III (reuse existing backend) is satisfied by projection, not by adding a new query,
  join, or D365 field.
- **Alternatives considered**:
  - *Register a second `EntityMappings`/response-DTO pair scoped only to this new column*: rejected — the
    existing `case 11:` mapping already reads every other field this screen needs from the same `so`
    object; a second mapping would duplicate the entire case for one extra field.
  - *Have the frontend read ETD from a separate call (e.g. reuse `AllCompliancesService`'s own response
    shape)*: rejected — would require Overview to call a second, unrelated backend service just to get one
    field already present on the same row its existing call already fetches.

### Decision 75 — Year/ETD Week filter: reuse `EtdWeekFilterBuilder`/`IsoWeekRange` (backend) and `isoWeek.js` (frontend) from a second call site — not a second date-range implementation

- **Decision**: `ComplDynamicsService` gains one new constructor dependency, `DynamicModelService`
  (already registered in DI and already injected into the sibling `AllCompliancesService` —
  `AllCompliancesService.cs:30`) — no new registration needed. Inside `GetDynRefePagedAsync`, before
  calling the existing `BuildFilterString`, split `request.Filters` into ETD year/week filters
  (`EtdWeekFilterBuilder.IsYearFilter`/`IsWeekFilter`, unchanged, `Utils/EtdWeekFilterBuilder.cs:44-59`)
  and every other filter, fetch `var modelInstance = await _dynamicModelService.GetModelInstance(refType)`,
  and — when any ETD filter is present — build `etdCondition` via `EtdWeekFilterBuilder.Build(modelInstance,
  weekFilters)` (weeks chosen) or `.BuildYear(modelInstance, yearFilters)` (year-only), then AND it onto
  the string `BuildFilterString` already returns for the remaining filters — the exact same
  extract-then-AND shape `AllCompliancesService.GetDataAsync` already uses (lines 77-114 of that file),
  cloned to a second call site. `EtdWeekFilterBuilder.Build`/`.BuildYear` require no changes: both already
  guard on `model.FilterableFields.TryGetValue("RsVnETD", ...)`, and `RSVNSalesOrderOpenInvoiceCogs`
  already declares that key (line 24) — the same row `ComplReferenceTypes` already seeds for refType 11
  (proven working today, since `AllCompliancesService`'s own `ref-type=11` compliance-view screen already
  resolves `GetModelInstance(11)` to this exact entity). Frontend: `SalesOrderOverviewPage.jsx` imports
  `getYearOptions`, `getWeekOptions`, `buildEtdWeekFilters` directly from
  `@presentation/pages/compliance-view/utils/isoWeek` (cross-feature import; the same alias-based import
  `compliance-missing/index.jsx:43` already uses to reuse this same util file) — no new frontend date-math
  file. `buildEtdWeekFilters(year, weeks)`'s existing output shape (`{column:"RsVnETD",
  operator:"inyear"|"inweeks", value}`) is sent unchanged, concatenated with the existing
  `buildSearchFilters(searchValue)` array (both arrays' entries AND together in `BuildFilterString`'s
  "other" bucket once ETD filters are pulled out first, per Decision above) — satisfying FR-165's AND
  requirement with no new combining logic.
- **Rationale**: Principle II (reference-pattern reuse) in its most literal form — the isoWeek.js file's
  own header comment states the date-range math intentionally lives in exactly one place
  (`IsoWeekRange.cs`) "để tránh lệch quy tắc giữa hai phía" (to avoid the two sides drifting apart); adding
  a second, frontend-only date-range calculation for Overview would directly violate that stated invariant.
  `EtdWeekFilterBuilder.Build`/`.BuildYear` already return a complete, ready-to-AND OData condition string
  (`ComplianceSys.Application/Utils/EtdWeekFilterBuilder.cs:71-158`), so the new call site needs no
  understanding of ISO week boundaries at all.
- **Alternatives considered**:
  - *Teach `ODataOperatorConverter.ToODataOperator` to recognize `inyear`/`inweeks` directly, formatting a
    computed range inline in `BuildFilterString`*: rejected — would duplicate `IsoWeekRange`'s leap-year/
    ISO-week-boundary math a second time inside a generic, entity-agnostic converter that has no business
    knowing about ETD-specific semantics; `EtdWeekFilterBuilder` already exists precisely to keep that
    logic in one place.
  - *Have the frontend compute concrete date boundaries itself and send plain `ge`/`le` filters*: rejected
    — `isoWeek.js`'s own design explicitly avoids this ("Frontend chỉ gửi ... không tự tính biên ngày"),
    and `ODataOperatorConverter.FormatValue`'s `Edm.DateTimeOffset` case (already implemented,
    `ODataOperatorConverter.cs:77-81`) would need a `dataType="Edm.DateTimeOffset"` hint threaded through
    `BuildFilterString`'s generic "other" branch — solvable, but reinvents exactly what
    `EtdWeekFilterBuilder.BuildConditions` already does (including OR-merging adjacent/overlapping weeks,
    `EtdWeekFilterBuilder.cs:166-208`), for no benefit over calling it directly.
  - *Register a brand-new dedicated endpoint for Overview's filtered list*: rejected — the existing
    `POST /api/dynamics/reference?refType=11` call already returns exactly the rows/columns this screen
    needs; a second endpoint would duplicate `EntityMappings`/`MapDynamicsResponse`'s case-11 logic.

### Decision 76 — Default sort (`DeliveryDate desc`) needs zero backend change; brown buttons reuse the existing `chip-brown` theme class

- **Decision**: `SalesOrderOverviewPage.jsx`'s existing fetch call (`getReferenceDataUseCase.execute(page,
  pageSize, sortColumn, sortOrder, refType, filters)`, currently hardcoded `'Code'`/`'asc'`) changes its
  literal sort arguments to `'DeliveryDate'`/`'desc'`. `MapSortColumn`'s switch
  (`ComplDynamicsService.cs:246-297`) has no case for `("deliverydate", "RSVNSalesOrderOpenInvoiceCogs")`,
  so it falls to the existing default arm (`_ => sortColumn`, confirmed present at the end of the switch),
  passing `"DeliveryDate"` straight through as the literal D365 field name it already is — the exact same
  passthrough Update 17's own investigation already relied on being present. Zero backend change. For the
  two Actions-column buttons, `SalesOrderOverviewPage.jsx`'s View/Download `IconButton`s add the already-
  existing `chip-brown` CSS class (`presentation/themes/custom.css:1-4`, `background-color: #ba7351;
  color: white;`) — today defined but unused anywhere in the client — instead of their current `color=
  "primary"`/default MUI color prop.
- **Rationale**: Principle III — both changes are pure reuse of something already present (a passthrough
  code path already exercised by Update 17's investigation; a CSS class already shipped in the shared
  theme file) with zero new backend surface.
- **Alternatives considered**:
  - *Add an explicit `("deliverydate", "RSVNSalesOrderOpenInvoiceCogs") => "DeliveryDate"` case to
    `MapSortColumn`*: considered for symmetry with the other explicit cases, but rejected as unnecessary —
    the default arm already produces the identical result for this literal column name, and adding a
    same-result case would be dead code, not a behavior change.
  - *Pick a new color value instead of `chip-brown`*: rejected — spec FR-168/Assumption (Update 24)
    explicitly calls for reusing an existing theme color, not inventing a new one; `#ba7351` is the only
    "brown" value anywhere in the client's theme files.

## Updated non-goals (Update 24)

- No new backend endpoint, controller, entity, table, or migration — the ETD field is a projection
  addition to an already-returned entity; the Year/Week filter reuses `EtdWeekFilterBuilder`/
  `IsoWeekRange`/`DynamicModelService` unchanged from a second call site; the default sort needs no new
  `MapSortColumn` case (existing passthrough already handles it).
- No change to `ODataOperatorConverter`'s recognized operator set (`eq`/`ne`/`gt`/`ge`/`lt`/`le`) — ETD
  year/week filters are intercepted and resolved by `EtdWeekFilterBuilder` before `BuildFilterString`
  ever calls `ToODataOperator` on them, so `inyear`/`inweeks` never reach that converter.
- No change to any other `refType`'s behavior — `DynamicModelService`/`EtdWeekFilterBuilder` are only
  exercised when the incoming `Filters` actually contain an ETD year/week entry (guarded by
  `EtdWeekFilterBuilder.IsEtdPeriodFilter`), which only `SalesOrderOverviewPage.jsx` will ever send.
- No change to the existing Sales ID/Customer search behavior (FR-011/FR-109) or the Update 16 Template
  whitelist default-view filter (FR-107) — both continue to combine with the new Year/ETD Week filter via
  the same AND-joined "other" bucket `BuildFilterString` already produces.
- No new CSS file/token — `chip-brown`/`#ba7351` is reused exactly as already defined; no other button or
  screen changes color as a result of this update.

## Update 25 (2026-09-18): Sales status column — "Backorder" → "Open order" display-label mapping

### Decision 77 — One client-side string-comparison label mapping; no mapping table, no backend change

**Decision**: Change `SalesOrderOverviewPage.jsx`'s existing Sales status cell (currently
`row.salesStatus || '-'`, confirmed at line 857) to render `"Open order"` when
`row.salesStatus?.toLowerCase() === 'backorder'`, else keep the existing `row.salesStatus || '-'`
expression unchanged.

**Rationale**: Codebase research (Explore agent, confirmed by direct file reads before drafting this
update) established that the Sales status column already exists end to end — `SalesOrderOverviewPage.jsx`
already renders it, `ComplDynReferenceResponseDto.SalesStatus` already carries it, and
`ComplDynamicsService`'s `case 11:` already assigns it from `RSVNSalesOrderOpenInvoiceCogs.SalesStatus` —
with zero label mapping applied anywhere in the codebase (backend or frontend). The user's request is
scoped to exactly one raw value ("Backorder") mapping to exactly one display label ("Open order"); a
single inline comparison is proportionate and matches this feature's own established precedent for
small, one-off value→label render decisions (Update 5's "Mapped"/"No map" chip labels are computed
inline, not via a shared mapping table).

**Alternatives considered**:
- *Backend-side mapping (translate `SalesStatus` before it reaches the DTO)* — rejected: would silently
  change the API's contract for any other future consumer of `refType=11`'s `salesStatus` field (Principle
  III/data-integrity concern — the raw D365 label is a fact about the order, the display text is a
  presentation choice); also inconsistent with how every other "value → badge text" decision in this
  feature (Update 5) is made at the point of render, not at the data-fetch layer.
- *A general `SALES_STATUS_LABELS` lookup object/shared util* — rejected as over-engineering for a
  single-value mapping with no second value in scope today; would also imply this update has classified
  every possible D365 `SalesStatus` value, which the spec's own Assumption explicitly disclaims. Easy to
  introduce later if a second mapping is ever requested, without needing to revisit this update.
- *Case-sensitive exact match only* — rejected: D365 data occasionally varies in casing across
  environments/sync runs (see `013-compl-synchronize-data`'s own note that `SalesStatus` is copied
  verbatim as a string, not normalized); a case-insensitive compare is a one-line addition that avoids a
  silent miss with no downside.

### Updated non-goals (Update 25)

- No new backend endpoint, controller, entity, table, migration, or DTO field — `SalesStatus` is already
  fully delivered by the existing, unmodified `refType=11` response.
- No general status-mapping table/enum for values other than "Backorder" — a future request to map a
  different value is a new, separate update, not pre-built here.
- No change to `ComplDynamicsService`, `DynController`, `ODataOperatorConverter`, `EntityMappings`, or
  `MapSortColumn`.
- No change to any other Overview column/control established by Updates 1-24 (Sales ID, Customer,
  Customer name, Delivery date, ETD, Template, Progress, search, Year/ETD Week filter, sort, pagination,
  Back-navigation restore, View/Download/Map File actions).

### Decision 78 — View header/toolbar swap reuses `poList`/`templatesData` already in state; toolbar array literal shrinks to 1 entry

**Decision**: On `ViewSalesOrderPage.jsx` only: (1) the header's `Template` field
(`templatesData.map(t => <Chip label={t.templateCode} .../>)`) is replaced with a `Purchase Order(s)`
field iterating `poList` (`poList.map(po => <Chip label={po.purchId} .../>)`) instead — `poList` is the
exact array already powering the "Selected Purchase Orders" table (`data-marker="selected-po-table"`),
not a new derivation; (2) the toolbar's chip source array,
`[{ templateCode: null, templateName: 'All' }, ...templatesData]`, is shortened to
`[{ templateCode: null, templateName: 'Template' }]` — dropping the `...templatesData` spread entirely
— so only the one entry (previously "All") renders, and its label reads "Template" instead of "All".

**Rationale**: Re-reading the current `ViewSalesOrderPage.jsx` (this session) confirms both `poList`
(built from `purchaseAttachments` + `allPos`, `useMemo` near the top of the component) and
`templatesData` (the saved templates' tree data) are already fully computed before either the header or
the toolbar renders — this is a pure "read a different already-computed array, render fewer array
entries" change, not a new data requirement. The toolbar's `onClick` handler (which sets
`selectedTemplateCode`/clears `selectedStepId`, and for the `templateCode === null` entry additionally
calls `loadDefaultTemplate()` per Update 19/20) is attached to each rendered array entry generically —
shrinking the array to one entry does not require touching the handler itself, only the array literal it
maps over.

**Alternatives considered**:
- *Keep rendering all chips but hide the per-template ones with CSS (`display:none`)* — rejected: leaves
  dead interactive elements in the DOM (still clickable via keyboard/automation), contradicts the spec's
  explicit "ẩn đi không hiển thị" (hidden, not displayed) framing and this feature's own Update 26
  Assumption (full removal from render, not a disabled/hidden-but-present state).
- *Introduce a new `selectedPOs`-style derived array for the header instead of reusing `poList`* —
  rejected as unnecessary duplication (Principle III/reuse) — `poList` already has exactly the
  `purchId` values needed, in the same order already shown in the table below it, so a second computation
  would only risk the two areas silently drifting out of sync.
- *Rename the `data-marker="template-tree-toolbar"` attribute to something PO/Template-neutral* —
  rejected: this attribute is referenced by this feature's own `quickstart.md` verification steps across
  many prior updates (5/8/15/19 and others) by its literal string; renaming it would be a breaking,
  purely-cosmetic change with no spec-mandated benefit (spec Assumption, Update 26).

### Updated non-goals (Update 26)

- No new backend endpoint, controller, entity, table, migration, or DTO field — both `poList` and
  `templatesData` are already delivered by existing, unmodified endpoints/use cases.
- No change to the toolbar's click/reload mechanism (FR-130 to FR-141) — only which array it maps over
  and that array's single entry's label.
- No change to any other View screen behavior (Selected Purchase Orders table, Template Checklist tree
  content, AVAILABLE FILES, Download/popup, Validation Summary, Edit/Map File, Back) — spec FR-178.
- No change to `MapFilePage.jsx` or `SalesOrderOverviewPage.jsx` — this update is scoped to
  `ViewSalesOrderPage.jsx` only, per the spec's explicit "trong màn hình này" (in this screen) framing.

### Decision 79 — Overview search OR-matches `CustAccount`: clone the existing `"vendorcode"` entity-guarded case in `BuildFilterString`, not a new filter mechanism

**Decision**: Extend `ComplDynamicsService.BuildFilterString`'s column-grouping switch (the same method
Update 24 already extended for ETD year/week) with one new case:
`"custaccount" when mapping.Entity == "RSVNSalesOrderOpenInvoiceCogs" => "custaccount"`, resolved to the
OData column `"CustAccount"` alongside the existing `code`→`mapping.CodeColumn`/`name`→
`mapping.NameColumn` resolution, and included in the existing OR-bucket check
(`group.Key is "code" or "name" or "vendorcode"` → `... or "custaccount"`). On the frontend,
`SalesOrderOverviewPage.jsx`'s `buildSearchFilters(search)` (lines 106-113) gains one more array entry:
`{ column: 'CustAccount', operator: 'like', value }`, alongside its existing `Code`/`Name` entries.

**Rationale**: Codebase research (confirmed by reading `ComplDynamicsService.cs` directly) found this
exact pattern already exists for a sibling screen: the Purchase Orders overview (`refType = 15`) already
sends an extra `{ column: 'VendorCode', ... }` filter (`PurchaseOrderOverviewPage.jsx`), matched by a
`"vendorcode"` case in the same switch, guarded to `mapping.Entity == "RSVNEutrPurchOrders"` so it has no
effect on any other `refType`. `CustAccount` is already a real property on
`RSVNSalesOrderOpenInvoiceCogs` and is already projected onto `ComplDynReferenceResponseDto.custAccount`
(feature Update 1, FR-004's Customer column) — the only gap is that `BuildFilterString` never resolved a
column name for it. Cloning the `"vendorcode"` case's exact shape (Constitution Principle II) for
`custaccount`/`RSVNSalesOrderOpenInvoiceCogs` closes this gap with the smallest possible diff: one new
`switch` arm, one new resolved-column mapping, and `"custaccount"` added to the OR-bucket membership
check — no new filter-combination logic, no new endpoint, no new DTO field (already exists), no new UI
element (the existing single search `TextField` is reused unchanged).

**Alternatives considered**:
- *Add `CustAccount` to the generic "other column" (AND-joined) `filterParts` bucket instead of the
  OR-joined `searchFilters` bucket* — rejected: this would silently change the search box from "match
  Sales ID OR Customer OR Customer name" to "match Sales ID AND Customer AND Customer name," breaking
  every existing single-field search (e.g. typing just a Sales ID would then require Customer/Customer
  name to also literally contain that same string) — directly contradicts spec FR-179/FR-180's explicit
  OR requirement.
- *Make the new case ungated (apply to every `refType`, not just `RSVNSalesOrderOpenInvoiceCogs`)* —
  rejected: `EntityMappings`'s other 20-ish `refType` entries have no `CustAccount` property on their
  underlying D365 entities at all, so an ungated case would either no-op unpredictably or throw depending
  on `ODataOperatorConverter`'s handling of an unknown column for that entity — the existing
  `"vendorcode"` precedent already established the entity-guard pattern precisely to avoid this class of
  cross-`refType` risk (spec FR-181).
- *Register a second, dedicated `EntityMappings`/response-DTO pair or a new endpoint scoped to this one
  extra column* — rejected: `CustAccount` is already fully delivered by the existing `case 11:` mapping
  used by every other column on this screen; a second mapping/endpoint would duplicate that entire case
  for one extra filterable column, the same reasoning already rejected for `RsVnETD` in Decision 74.

### Updated non-goals (Update 27)

- No new backend endpoint, controller, entity, DTO field, or migration — `CustAccount` is already
  delivered end to end since this feature's own Update 1; only the search-filter column set changes.
- No change to `EntityMappings[11]`'s `(CodeColumn, NameColumn)` tuple or `MapDynamicsResponse`'s
  `case 11:` — Sales ID/Customer name filtering and mapping stay exactly as they were (spec FR-180).
- No change to any other `refType`'s filtering behavior — the new case is guarded to
  `RSVNSalesOrderOpenInvoiceCogs` only, cloning the existing `"vendorcode"`/Purchase-Orders guard shape
  (spec FR-181).
- No new UI element — the existing single search `TextField` (placeholder "Tìm theo Sales ID,
  Customer...") is reused unchanged; no new input, button, or label.
- No change to how the search keyword combines with Year/ETD Week (Update 24, AND) or with the
  Template-whitelist default-view filter (Update 16) — this update only widens which columns the
  existing keyword is OR-matched against.

## Update 28 (2026-09-22): Map File/Edit/Download icons gated by `permissionList` ('Update'/'Download') on menu `eutr-sales-orders`

### Decision 80 — Reuse the existing `permissionList`/`getMenuDataFromStorage` pattern verbatim; no new permission helper, string, or backend policy

**Decision**: On both `SalesOrderOverviewPage.jsx` and `ViewSalesOrderPage.jsx`, add
`import { getMenuDataFromStorage } from '@utils/helpers'` and a `permissionList` `useMemo`:
`getMenuDataFromStorage().find(m => m.code === 'eutr-sales-orders')?.permissionList || []` — the exact
shape `eutr-documents/index.jsx` (lines 26-31) already uses for its own menu. Wrap the Map File icon
(Overview)/Edit-Map-File button (View) in `permissionList.includes('Update') && (...)`, and the Download
icon/button (both screens) in `permissionList.includes('Download') && (...)`. The View summary icon and
Back button are left unwrapped.

**Rationale**: Codebase research (confirmed by reading `SalesOrderOverviewPage.jsx` ~lines 954-1011 and
`ViewSalesOrderPage.jsx` ~lines 1098-1118) found these 3 icons/buttons render unconditionally today, with
zero `permissionList` check — a real, verified gap relative to every other EUTR screen in this codebase
(`eutr-documents`, `eutr-templates`, `compliance-view-so`, `eutr-reference-types`), which already gate
their own Edit/Delete/Download actions the same way. Menu code `eutr-sales-orders` is already the code
this feature's route/menu registration uses (confirmed in `RouteResolver.jsx`); no new menu code, no new
permission string (`'Update'`/`'Download'` already exist and are already assignable per menu through the
existing menu-admin mechanism), no new helper function, no backend call of any kind (Constitution
Principle II/III — clone the existing reference pattern, don't invent a parallel one).

**Alternatives considered**:
- *Add a shared `hasPermission(menu, action)` helper instead of inline `.includes()` calls* — rejected:
  no such helper exists anywhere in this codebase today (confirmed by research); every other EUTR screen
  inlines the same `.includes()` check locally rather than through a shared utility, so introducing one
  now would be a new abstraction this update doesn't need and no other screen would adopt retroactively
  (scope creep beyond what the request asks for).
- *Disable (grey out) the icons/buttons instead of hiding them* — rejected: every existing precedent in
  this codebase (`eutr-documents`, `eutr-templates`) fully unmounts the gated element (conditional render,
  not a `disabled` prop) rather than showing a disabled control; matching that precedent keeps this
  update consistent with the rest of the system rather than introducing a second visual convention for
  "no permission."
- *Add a backend-side check (e.g. reject the Map File navigation or Download call server-side if the
  user lacks the permission)* — out of scope for this update: the request is specifically about
  icon/button visibility ("hiển thị icon"), and no other EUTR screen in this codebase enforces its
  per-action `permissionList` server-side either (menu-level `canAccessMenu` is the only
  backend-enforced gate) — adding server-side enforcement now would be an inconsistent, unrequested
  scope expansion relative to the established pattern this update is asked to replicate.

### Updated non-goals (Update 28)

- No new backend endpoint, controller, entity, DTO, migration, or authorization policy — `permissionList`
  is already delivered end to end by the existing external menu/auth service.
- No new frontend helper/hook (e.g. `hasPermission()`) — reuses the exact inline
  `permissionList.includes(...)` pattern every other EUTR screen already uses.
- No change to the View summary icon (Overview) or Back button (View) — both stay unconditionally
  visible, unaffected by this update (spec FR-187).
- No change to what Map File/Edit/Download/View summary/Back actually *do* once shown — this update only
  changes whether 2 of them render, never their `onClick`/navigation/download behavior (spec FR-188).
- No change to any other Overview/View control — search, pagination, sort, Year/ETD Week filter,
  Progress/Template columns, Template Checklist, AVAILABLE FILES, Validation Summary, and the Download
  popup's own internal folder/file rules are all untouched.

## Update 29 (2026-09-23): Map File Step 2 Upload/Edit buttons gated by `EutrDocuments.Create`/`EutrDocuments.Update`

### Decision 81 — Gate on `permissionList` of menu `eutr-documents` (Update 28's exact mechanism, new menu code), not a live backend probe

**Decision (as shipped, after correction)**: `MapFilePage.jsx` reads `permissionList` for menu code
`'eutr-documents'` via the exact `getMenuDataFromStorage()` mechanism `SalesOrderOverviewPage.jsx`/
`ViewSalesOrderPage.jsx` already use for menu `eutr-sales-orders` (Update 28), and derives
`canUploadDocuments = permissionList.includes('Create')` /
`canEditDocuments = permissionList.includes('Update')` as plain `useMemo`-derived values — no state, no
effect, no network call. `PurchaseOrderViewPage.jsx` (`012-eutr-purchase-orders`) was corrected the same
way in the same session, replacing its Update 4 `can-create` probe.

**What was tried first, and why it was wrong**: An earlier draft of this Update assumed
`EutrDocuments.Create`/`EutrDocuments.Update` were *not* obtainable from `permissionList` — reasoning
by analogy from `012-eutr-purchase-orders` Update 4's own Decision 11, which stated the frontend "only
has menu-level access data" and that action-level policies like `EutrDocuments.Create` were a different
domain unreachable without a live probe. That draft added two new backend endpoints
(`GET /api/eutr-documents/can-create` reused, `GET /api/eutr-documents/can-update` new) and had both
`MapFilePage.jsx`/`PurchaseOrderViewPage.jsx` call them on mount. The person requesting the feature
tested this live and reported both buttons still visible after revoking the permissions — a browser
DevTools capture of `GET .../menu-managements/permissions?appCode=ComplApi&email=...`'s response showed
the menu entry for `eutr-documents` (id 242) already carries a `permissionList` array (in that capture:
`['Download', 'ReadAll', 'ReadOne', 'ViewMenu']`, missing `'Create'`/`'Update'` for the test role) — the
exact same shape Update 28 already reads for menu `eutr-sales-orders`. This directly falsified Decision
11's premise for this specific menu: `'Create'`/`'Update'` **are** valid `permissionList` entries for
`eutr-documents`, they just weren't granted to the test role. (Separately, live testing also surfaced
that `appsettings.Development.json`'s pre-existing `AuthZ:EnablePolicyCheck: false` bypasses the real
`[Authorize(Policy = ...)]` checks in Development entirely — a real, independent config issue, but not
the cause here once `permissionList` was confirmed to already carry the right data.)

**Rationale**: `permissionList` is simpler (no new endpoint, no network round trip, no loading-state
window where the button is wrongly hidden/shown before the probe resolves), consistent with the one
proven working pattern already used for every other menu-gated action in this codebase, and confirmed
correct by direct observation rather than by inference. The two now-dead probe endpoints/use cases
(`can-create`'s brand-new `can-update` sibling, `CheckEutrDocumentsCanCreateUseCase.js`,
`CheckEutrDocumentsCanUpdateUseCase.js`, and the `canCreate`/`canUpdate` repository/API methods) were
deleted per the requester's explicit choice, rather than left unused, consistent with this repo's
no-dead-code convention.

**Alternatives considered**:
- *Keep both mechanisms (permissionList for instant UI gating, live probe as a secondary confirmation)*
  — rejected: `permissionList` already reflects the same underlying role/permission data; a second,
  redundant network round trip adds latency and a loading-state race for no additional correctness,
  and the requester explicitly asked to remove the now-unused probe code rather than keep it dormant.
- *Disable (grey out) Upload/Edit instead of hiding them* — rejected, same reasoning as Update 28: every
  precedent in this codebase fully unmounts the gated element.

### Updated non-goals (Update 29)

- No backend change of any kind (as shipped) — `EutrDocuments.Create`/`EutrDocuments.Update` remain
  exactly the policies already protecting `POST /api/eutr-documents`/`PUT /api/eutr-documents/{id}`,
  unaffected by this update; the two probe endpoints from the earlier draft were added and then removed
  within this same session, net zero backend surface change.
- No change to Update 28's `permissionList` gating of menu `eutr-sales-orders` (Map File/Edit-Map-File/
  Download icons) — independent menu code, independent condition (spec FR-192 edge-case note).
- No change to the View button, Step 1 (PO selection/Save PO Mapping), template tree, or any other part
  of Map File — only Upload's and each row's Edit's visibility condition changes.
- No change to Upload/Edit's own behavior once shown (popup contents, save flow, AVAILABLE FILES
  refresh) — purely a visibility gate.

## Decision 82 — Row-level Download button fetches directly (no dialog), reuses `get-file-by-idref`; download name recomputed client-side, never written to DB (spec Update 33, FR-194 to FR-197)

- **Decision**: New Download `IconButton` on each AVAILABLE FILES row calls
  `getEutrDocumentsFileByIdRefUseCase.execute(file.fileId)` directly (same use case/endpoint already
  used by `EutrFileViewerDialog`) and builds the `Blob`/`<a download>` inline in `MapFilePage.jsx` —
  it does NOT open `EutrFileViewerDialog` first. `EutrFileViewerDialog`'s own existing Download button
  (inside the View popup) is also updated to use the same new `buildStepOnlyFileName(originalFileName,
  stepNames)` helper (new file, `eutr-documents/utils/buildStepOnlyFileName.js`) instead of the raw
  stored file name, for consistency between the two download entry points.
- **Rationale**: The user's screenshot showed a document created before `004-eutr-documents` Update 26
  (Prefix removed from the naming formula at Upload time going forward, no backfill) still downloading
  with its old Prefix+StepName name via the existing popup Download button — confirmed via
  `AskUserQuestion` that the fix should be a **fresh computation on every download**, not a read of
  whatever `eutr_documents.Name` happens to hold, so it also fixes legacy documents without any
  DB migration/backfill. Building the row-level button as a direct fetch (skip the dialog) keeps the
  new interaction minimal — one click, one download — matching how "Download" buttons behave elsewhere
  in this codebase (e.g. `EutrFileViewerDialog`'s own button), rather than requiring the user to open a
  preview first just to get a file they may not want to view.
- **Alternatives considered**: (1) Backfill `eutr_documents.Name` for legacy documents to strip the
  Prefix — rejected because `004-eutr-documents` Update 26 explicitly decided against backfill (File
  name shown elsewhere, e.g. the main list/tooltips, is out of scope for that decision and this one);
  recomputing only at download time achieves the user's actual goal (correct file name when downloading)
  without touching stored data or any other UI. (2) Route the new row-level button through
  `EutrFileViewerDialog` (open it, then trigger its Download) — rejected as an unnecessary UX detour
  (extra click, extra network round-trip for content already fetchable directly) when the same use
  case/endpoint is trivially callable standalone.

## Decision 83 — Multi-Step file uses the first `stepNames` entry for the download name; no Prefix-based tie-break (spec Update 33, FR-196)

- **Decision**: `buildStepOnlyFileName` always uses `stepNames?.[0]` when the array is non-empty,
  regardless of how many Step chips a row shows.
- **Rationale**: A file can legitimately match more than one Step (Type = "PO" matching multiple
  `eutr_master_documents.Prefix` rows) — there is no single "correct" Step name in that case, only the
  one that historically won the Prefix-length tie-break used to compute `eutr_documents.Name` at Upload
  time (`004-eutr-documents` Update 25/26). Reconstructing that exact historical tie-break at download
  time would require re-fetching the original file name and re-running the same prefix-matching query
  against `eutr_master_documents` — real backend work for an edge case the user's request never
  mentioned. The first array entry is simple, deterministic, and correct for the overwhelming common
  case (exactly one Step per file, as in the screenshot).
- **Alternatives considered**: Re-run the Prefix tie-break server-side for multi-Step files — rejected
  as over-engineering relative to the actual request ("đổi tên file thành step name"), which did not
  ask for byte-for-byte parity with the Upload-time naming algorithm for this rare edge case.

## Bug fix (2026-09-24, same Update 33) — `handleDownloadFile` must unwrap the `ApiResponse<T>` envelope itself

- **Symptom**: Clicking the new row-level Download button threw `Cannot read properties of undefined
  (reading 'replace')` — `loadedFile.content.replace(...)` failed because `loadedFile.content` was
  `undefined`.
- **Root cause**: `GET /eutr-documents/get-file-by-idref` (`EutrDocumentsController.cs:174`) returns
  `ApiResponse<SharepointFileContent>.Ok(files, ...)`, i.e. the JSON body is
  `{ success, message, data: { content, contentType, fileName } }` — `RestEutrDocumentsRepository.
  getFileByIdRef` (`RestEutrDocumentsRepository.js:31-34`) passes this through unwrapped
  (`return res.data`, the raw axios body, envelope and all). `EutrFileViewerDialog`'s existing Download
  button never hit this bug because its `loadedFile` state comes from `FilePreviewer.jsx`'s `onLoaded`
  callback, which already destructures `response.data` (`FilePreviewer.jsx:75-81`) before calling
  `onLoaded`. `handleDownloadFile` (`MapFilePage.jsx`/`PurchaseOrderViewPage.jsx`) calls the use case
  directly — bypassing `FilePreviewer` entirely, by design (FR-194: no popup) — so it received the
  still-wrapped envelope and read `.content` directly off it.
- **Fix**: `handleDownloadFile` now checks `response.success`/`response.data` and reads
  `response.data` as `loadedFile`, mirroring `FilePreviewer.jsx`'s own unwrapping exactly, before doing
  anything else with it.

## Update 34/35 (2026-09-29/30): Step 1 (Map File) & Selected Purchase Orders (View) read every column directly from `RSVNEutrSalesOrderPurchLines` (refType=20); `QtyPercent`/`Unit` added end-to-end

### Decision 84 — Make refType=20 the sole row source for both tables; drop refType=16 and the Update 17/18 group-by-PO string join entirely (spec FR-198/FR-199)

- **Decision**: `MapFilePage.jsx` Step 1 and `ViewSalesOrderPage.jsx`'s Selected Purchase Orders table
  both stop calling reference type = 16 (`RSVNEutrSalesOrderPurchases`) for PO/Template/Order account/
  Vendor name. Instead, a single refType=20 (`RSVNEutrSalesOrderPurchLines`) call — already fetched by
  both screens since Update 17/18 — supplies every column: `RSVNRefPurchId`→PO, `RSVNEutrTemplate`→
  Template, `OrderAccount`→Order account, `Name`→Vendor name, `ProductVariant`→Variant, `ItemId`→
  Material, `Qty`→Qty. The table row grain changes from "1 row per PO" to "1 row per refType=20 record"
  — a PO with N line records now renders N rows, each with that record's own Variant/Material/Qty
  values, rather than 1 row with all N records' Variant/Material values joined into one comma-separated
  cell.
- **Rationale**: The request was explicit and literal — "chỉ lấy dữ liệu từ api
  `RSVNEutrSalesOrderPurchLines` để hiển thị, bỏ logic hiển thị chuỗi nối" (only take data from this one
  API to display, remove the string-join display logic). `RSVNEutrSalesOrderPurchLines` already carries
  every field the table needs (confirmed by reading the domain model) — there is no missing column that
  would force keeping refType=16 for anything in this table. Dropping the join also fixes a latent
  correctness gap the join mechanism had: a PO with multiple lines showed the *same* joined
  Variants/Materials string on every duplicate PO row the underlying refType=16 source could already
  produce (see Decision 85), so no individual row's Variant/Material was actually traceable to its own
  Qty — reading directly off each refType=20 record removes that mismatch entirely.
- **Alternatives considered**: (1) Keep refType=16 for PO/Template/Order account/Vendor name and only
  swap the Variant/Material *values* to per-record instead of joined-string, dropping the join but
  keeping 1-row-per-PO by showing only the first matching line's Variant/Material — rejected: this
  either silently drops data for multi-line POs (which line "wins"?) or reintroduces some other
  aggregation the request explicitly asked to remove; it also ignores the literal "chỉ lấy dữ liệu từ
  api ... để hiển thị" instruction, which names one API as the *only* source, not "the only source for
  2 of 8 columns." (2) Keep both refType=16 and refType=20 calls, with refType=20 now also supplying
  Qty/Unit/Percentage-used per-row while refType=16 still backs Select/disable logic — rejected: this
  doubles the network calls this table needs for no behavioral gain, since refType=20 already carries
  `RSVNEutrTemplate` (usable for the disable condition, Decision 86) and the two API calls could disagree
  on which POs exist for edge-case D365 data, which the single-source design avoids by construction.

### Decision 85 — Select/disable/Save PO Mapping stay keyed by `purchId` (`Set`), unaffected by the new multi-row-per-PO grain (spec FR-203)

- **Decision**: `handleTogglePO(purchId)` and the `selectedPOs` `Set<purchId>` in `MapFilePage.jsx` are
  unchanged. Each table row's Checkbox reads `selectedPOs.has(line.purchId)` and the disable condition
  reads `!line.eutrTemplate` off that same row's own record — both already correct for a PO spanning
  multiple rows, since every row of the same PO carries the same `purchId` key (toggling one row updates
  the shared `Set` entry, which every other row with that `purchId` also reads on next render) and the
  same `RSVNEutrTemplate` value (a per-PO attribute in D365, replicated onto every one of that PO's line
  records). `handleSavePOMapping` still derives its payload from `poList` (deduped by `purchId`), so
  Save persists exactly 1 `{purchId, templateCode}` entry per unique PO regardless of how many table rows
  that PO occupies.
- **Rationale**: No code change was needed here because the pre-existing design already keyed selection
  state by PO identity, not by row/array index — a fact confirmed by reading `MapFilePage.jsx` before
  making any edit (Constitution Principle III: don't rebuild a mechanism that's already correct for the
  new shape). This also explains a screenshot the requester attached alongside the original Update 34
  ask, showing the same PO number appearing twice in the Step 1 table with identical Template/Order
  account values: today's (pre-Update-34) refType=16 PO source can itself return more than one record
  for the same `PurchId` (confirmed: `poList.map(po => ...)` has no client-side dedupe), so duplicate PO
  rows already existed before this update — Update 34 does not introduce row duplication, it makes the
  already-duplicated rows' Variant/Material/Qty values individually correct instead of each showing an
  identical, PO-wide joined string.
- **Alternatives considered**: Re-key selection state by a composite `purchId+lineIndex` to give each
  displayed row its own independent checkbox — rejected: the spec (FR-203) explicitly requires selection
  to keep operating at the PO level ("Select checkbox ... MUST tiếp tục hoạt động đúng ở cấp PO"), and a
  per-line checkbox would let a user select only *some* lines of one PO, a state `eutr_purchase_
  attachments` (`{SalesId, PurchId, TemplateCode}`, no line-level column) has no way to represent.

### Decision 86 — `QtyPercent`/`Unit` added as new `string` properties, threaded through 3 files (domain model → shared DTO → `case 20:` mapping); `FilterableFields` and every other `case N:` left untouched (spec FR-202/FR-208)

- **Decision**: `RSVNEutrSalesOrderPurchLines.cs` gains `public string QtyPercent { get; set; }` (Update
  34) and `public string Unit { get; set; }` (Update 35), alongside the existing `string Qty` property.
  `ComplDynReferenceResponseDto.cs` (the one flat DTO shared by every `refType`) gains matching
  `QtyPercent`/`Unit` string properties. `ComplDynamicsService.MapDynamicsResponse`'s `case 20:` gains
  `QtyPercent = x.QtyPercent` and `Unit = x.Unit` — every other assignment already in that `case` block
  (`Code = x.ItemId`, `CustAccount = x.OrderAccount`, `Qty = long.TryParse(...)`, etc.) is unchanged.
  Both new DTO fields serialize via the default `System.Text.Json` camelCase formatter (confirmed:
  `Program.cs` registers no custom naming policy) as `qtyPercent`/`unit` — the frontend reads
  `item.qtyPercent`/`item.unit`.
- **Rationale**: Codebase research (confirmed before writing any code) established that
  `ComplDynReferenceResponseDto` is a single, fixed, flat DTO reused across every `refType`'s hand-written
  `case N:` mapping — there is no generic/reflection-based passthrough, so a new domain-model property is
  **not** automatically visible in the API response; it must also be added to the shared DTO and to the
  one `case` block that owns this `refType`. `string` (not a numeric type) was chosen for both new
  properties to mirror the existing `Qty` *domain-model* property's own type (also `string` — the D365
  entity's raw field type) and to avoid making an unverified assumption about `QtyPercent`'s numeric
  format (e.g. whether D365 already includes a `%` suffix, decimal precision, etc.); the frontend appends
  a literal `%` when rendering `qtyPercent` only if a value is present, matching the pre-Update-34
  placeholder's own `{po.qty} %` display convention.
- **Alternatives considered**: (1) Add `QtyPercent`/`Unit` to `FilterableFields` too — rejected: codebase
  research confirmed this dictionary is consumed only by `ODataFilterBuilder`/`EtdWeekFilterBuilder` for
  WHERE-clause/`$orderby` column validation on the `reference` endpoint's `filters`/`sortColumn`
  parameters, never for controlling which fields serialize in the response; neither new field needs to be
  filterable/sortable per the spec, so adding them would be unused surface area. (2) Parse `QtyPercent`
  into a numeric DTO field (like `Qty`'s `long`) — rejected: `Qty`'s numeric parse exists because the
  *display* need is a plain number; `Percentage used` had no such established numeric contract before
  this update (its pre-existing placeholder just borrowed `Qty`'s already-parsed number), so introducing
  a new numeric-parse assumption for a field with an unconfirmed raw D365 format carries needless risk of
  a `TryParse` silently defaulting to `0` for values that don't fit whatever numeric shape was guessed.

### Decision 87 — Frontend reads refType=20's Order account off `item.custAccount`, not `item.orderAccount`; the existing `case 20:` `OrderAccount`→`CustAccount` rename is left as-is

- **Decision**: `case 20:`'s pre-existing `CustAccount = x.OrderAccount` line (present before Update 34)
  is **not** changed to also/instead populate the DTO's own `OrderAccount` property. `MapFilePage.jsx`/
  `ViewSalesOrderPage.jsx` read `item.custAccount` when building each `poLines`/`poRows` entry's
  `orderAccount` field for refType=20 responses.
- **Rationale**: Codebase research (a dedicated investigation before writing any code) found that
  `case 20:`'s existing mapping already renames `OrderAccount`→`CustAccount` on the shared DTO — a
  different choice than `case 16:`'s `OrderAccount = x.OrderAccount` (no rename) — and that nothing in
  the frontend reads `item.custAccount` for refType=20 today (the whole field was unused pre-Update-34).
  Two ways to reconcile this were available: change the backend mapping to also emit `OrderAccount =
  x.OrderAccount` for refType=20 (making both refTypes consistent under the same DTO field name), or
  leave the 4-year-old mapping alone and have the frontend read the field name refType=20 actually
  returns. The second was chosen because it is the smaller, lower-risk diff (Constitution Principle
  III/"smallest reasonable diff") — `case 20:`'s `CustAccount` assignment already compiles and already
  works for whatever (if any) other caller of refType=20 exists outside this feature's own 2 files
  (confirmed by a repo-wide grep: none do), so changing it carries a small but non-zero risk of an
  unintended effect elsewhere for a purely cosmetic consistency gain. This decision does **not** change
  any DTO field's meaning or add a new one — it only decides which of two already-shipped field names the
  new frontend code should read.
- **Alternatives considered**: Add `OrderAccount = x.OrderAccount` to `case 20:` alongside the existing
  `CustAccount` line (both populated, frontend reads the more semantically-named `orderAccount`) —
  seriously considered, ultimately deferred as unnecessary: it would touch a backend file not otherwise
  broken, for a naming-clarity improvement the spec never asked for, when the minimal fix (read
  `custAccount` in the 2 already-being-edited frontend files) fully satisfies FR-199 with a smaller diff.
  If a future update needs refType=20's Order account under the `orderAccount` name for some third
  consumer, this decision can be revisited then.

### Updated non-goals (Update 34/35)

- No change to `SalesOrderOverviewPage.jsx` or its own reference type = 16 usage (a different, unrelated
  Order-account lookup for that screen's own Progress/Download batching) — scope is Map File Step 1 +
  View's Selected Purchase Orders table only.
- No change to Step 2 (template tree, AVAILABLE FILES, Upload/Edit/View/Download), Template Checklist,
  Validation Summary, Back navigation, or any permission gating (Update 28/29) on either screen — this
  update only changes the Step 1/Selected-Purchase-Orders table's data source and columns.
- No database migration, no new endpoint, no new DTO class, no new frontend file — additive properties on
  2 already-existing backend classes, 2 new assignment lines in an already-existing `case` block, and
  edits confined to 2 already-existing frontend pages.
- No change to the batch-loading mechanism (1 call per Sales ID, grouped/consumed client-side, no N+1)
  already established by Update 17/125 — Update 34/35 reuses it unchanged, just consumes more fields per
  record and no longer groups multiple records into one row.

## Update 37 (2026-09-30): Template tree label shows the mapped file's name once uploaded; download for Type = "PO" documents no longer recomputes the file name as Step Name

### Decision 88 — Swap the tree node's primary label to the first mapped file's name (extension stripped) instead of adding a second display mechanism (spec FR-216)

- **Decision**: In `TreeNode` (`MapFilePage.jsx`), the `Typography` that renders `{node.stepName}`
  (around line 245) becomes `{mappedFiles.length > 0 ? stripFileExtension(mappedFiles[0].name) :
  node.stepName}`. `stripFileExtension` is a new small exported helper in `progressUtils.js` (same regex
  `buildStepOnlyFileName.js` already uses to strip an extension), shared with `PurchaseOrderViewPage.jsx`
  (`012-eutr-purchase-orders`) since both files import from this module already.
- **Rationale**: Reading `TreeNode` before editing revealed it already renders a *second* line below the
  step name — a caption showing `mappedFiles[0].name` (full name, with extension) plus a `(+N)` badge for
  additional matches — added at some point after the "+N badge/tooltip" behavior Update 31 documented as
  pre-existing. The request's example ("step là 1.Invoice, tên file đã upload là 1.Invoice AP-PD.pdf thì
  hiển thị 1.Invoice AP-PD") describes the *primary*, bold label changing to the file name, not a second
  line being added — that already exists. So this update only touches the primary `Typography`, leaving
  the existing secondary caption, its `(+N)` badge, and the status-icon tooltip (`Đã map: fileA, fileB`,
  listing every matched file's full name) untouched, per the spec's explicit "badge/tooltip unchanged"
  clause. The result is intentionally a little redundant (primary label = file name minus extension,
  caption directly below = the same file's full name) — removing the caption instead was considered and
  rejected (see Alternatives) since the spec never asked for it to be removed.
- **Alternatives considered**: (1) Replace the secondary caption instead of the primary label, leaving
  `node.stepName` as the bold primary text always — rejected: this does not match the request's example,
  where the *prominent* label (the one described as "phần tên step") is what changes. (2) Remove the
  now-partially-redundant secondary caption line since the primary label already shows the (truncated)
  file name — rejected as scope creep: the spec (`005-eutr-sales-orders` FR-216) explicitly says the
  badge/tooltip mechanism "giữ nguyên không đổi," and collapsing the two into one display is a UI
  redesign decision nobody asked for; if the duplication reads as visual noise once shipped, that is a
  follow-up request, not an inference to make now.

### Decision 89 — Skip the Step-Name download-name recompute for Type = "PO" documents specifically, gated on the already-present `typeName` field (spec FR-217)

- **Decision**: `handleDownloadFile` (`MapFilePage.jsx`) and `EutrFileViewerDialog.handleDownload` both
  gain a check: when the document's Type is "PO" (`file.typeName`/a new `typeName` prop, compared
  case-insensitively), `link.download` is set directly from `loadedFile.fileName || file.name` (the
  stored/returned name, which — since `004-eutr-documents` Update 29 — already equals the original
  uploaded file name for new Type = "PO" documents) instead of calling `buildStepOnlyFileName(...)`. Every
  other Type continues to call `buildStepOnlyFileName(...)` exactly as Update 33 left it.
- **Rationale**: `realAvailableFiles` (`MapFilePage.jsx`) already carries a `typeName` field per document,
  populated straight from the `list-po-references` response (added for Update 5's Map-status/File-type/
  PO-value computation) — no new backend field, DTO change, or round-trip is needed to make this decision
  Type-aware; the data was already there. Gating narrowly on Type = "PO" (rather than removing the
  recompute for every Type) matches the amendment's own framing, which opens with "khi upload file với
  type = PO" and only asks for original-file-name behavior in that context — Type ≠ "PO" documents keep
  the Update 33 behavior verbatim (their `eutr_documents.Name` already equals the Step-Name formula from
  `004-eutr-documents`'s own Upload-time rename, unaffected by Update 29, so recomputing it again at
  download time remains a correct no-op for freshly-created documents and a deliberate normalization for
  documents created before Update 26 still carrying a stale Prefix+StepName).
- **Alternatives considered**: (1) Remove the recompute-to-Step-Name behavior entirely, for every Type —
  rejected: the amendment is explicitly scoped to Type = "PO" ("khi upload file với type = PO... tên file
  ntn giữ nguyên khi up và khi tải"); silently changing Type ≠ "PO" download behavior nobody asked to
  change risks an unannounced regression for users relying on the current Step-Name download convention
  for non-PO documents. (2) Thread a fresh `type`/`refType` lookup through a new prop instead of reusing
  the already-present `typeName` field — rejected as needless extra plumbing once `typeName` was confirmed
  already available on the exact object both call sites already receive.

## Update 40 (2026-09-30): Template tree toolbar groups by PurchId instead of TemplateCode; View's single collapsed "Template" tab is replaced with per-PO tabs

### Decision 90 — Introduce `buildPoTemplateComputations` as a sibling function, not a replacement of `buildTemplateComputations`

- **Decision**: `progressUtils.js` gains a new exported `buildPoTemplateComputations(poTemplates,
  files)`. The existing `buildTemplateComputations(templatesData, files, purchIdToTemplateCode)` is left
  completely untouched. `MapFilePage.jsx`/`ViewSalesOrderPage.jsx` switch their own toolbar-tab
  computation to the new function; `SalesOrderOverviewPage.jsx`, `PurchaseOrderOverviewPage.jsx`, and
  `012-eutr-purchase-orders`'s `PurchaseOrderViewPage.jsx` keep calling the old one, unchanged.
- **Rationale**: Grepping every caller of `buildTemplateComputations` before making any edit (Constitution
  Principle III) found 6 call sites across 4 files. Only 2 of them (`MapFilePage.jsx`,
  `ViewSalesOrderPage.jsx`) render a multi-item toolbar where 2+ POs sharing 1 TemplateCode could
  plausibly appear side by side — the bug the requester is describing. The other 3 call sites
  (`SalesOrderOverviewPage.jsx`/`PurchaseOrderOverviewPage.jsx`'s Progress column, `PurchaseOrderViewPage.jsx`'s
  own single-PO page) each invoke the function once per row/page with a `templatesData` array already
  scoped to exactly one PO's own template — they never had this bug, because they were never merging
  multiple POs' files into one computation in the first place. Changing the shared function's signature
  or behavior would have been unnecessary churn on 3 files that don't need it, and risks a regression on
  the Overview Progress columns most other update sessions haven't touched.
- **Alternatives considered**: Modify `buildTemplateComputations` in place to accept a `groupBy: 'template'
  | 'po'` parameter, letting every caller opt in — rejected: none of the other 3 callers need the new
  grouping, so a parameter only they never pass is pure complexity for no behavioral gain; a new,
  separately-named function documents the actual distinction (group by Template vs. group by PO) more
  clearly than a boolean/enum flag would.

### Decision 91 — Per-PO file matching drops the "ambiguous vendor code" exclusion `buildPurchIdToTemplateCodeMap` used

- **Decision**: `buildPoTemplateComputations` matches a file to a PO with `f.poCode === purchId ||
  f.poCode === orderAccount` — the PO's *own* PurchId or the PO's *own* Order account (Vendor code), full
  stop. No cross-PO ambiguity check is performed.
- **Rationale**: The old `buildPurchIdToTemplateCodeMap` (used to build `purchIdToTemplateCode` for the
  now-untouched `buildTemplateComputations`) had to solve a harder problem: given a Vendor code that might
  belong to several POs on several *different* templates, which single template should a Vendor-level
  document (Type = "Vendor", RefValue = that Vendor code) be merged into? It answered this by excluding
  the Vendor code from the map entirely whenever it mapped to more than one distinct TemplateCode —
  meaning, before Update 40, a Vendor-level document from a vendor supplying POs on 2+ different templates
  never showed up on ANY template's tree at all. Once every computation is already scoped to exactly one
  PO (Update 40's whole point), that ambiguity dissolves by construction: a file matches this PO's own
  Order account or it doesn't — there is no "which of several templates does this belong to" question left
  to answer, because we're never comparing across POs in the first place. This is strictly more correct
  than the old behavior, not just simpler: a vendor-level document (e.g. "General agreement") now
  correctly appears on every one of that vendor's PO tabs, instead of silently vanishing whenever that
  vendor happened to supply POs on more than one template.
- **Alternatives considered**: Keep calling `buildPurchIdToTemplateCodeMap` to precompute a
  `purchIdToTemplateCode` map and pass it into the new per-PO function too, purely for consistency with the
  old code path — rejected: the per-PO function doesn't need a PurchId→TemplateCode lookup at all (each
  `poTemplates` entry already carries its own `templateCode` directly from `eutr_purchase_attachments`),
  so calling the old map-builder here would be dead computation that also silently reintroduces the exact
  ambiguity-exclusion this update makes obsolete.

### Decision 92 — View's toolbar loses its "All" tab entirely; the underlying All-mode computations stay, because Download still needs them

- **Decision**: The toolbar's hardcoded `[{templateCode: null, templateName: 'Template'}]` single-tab
  array (Update 26) is replaced by `poTemplates.map(...)` — real per-PO tabs, no "All" tab anywhere in the
  list. `selectedPurchId` can therefore no longer become `null` through any user click. However,
  `defaultTemplate`, `loadDefaultTemplate`, `allChipTree`, `allChipDerivedFileMappings`, `allChipFiles`,
  and `soStepIds` (the entire Update 19/20/21 "All" computation stack) are left completely in place, and
  the `isAllActive`/`selectedPurchId === null` branches in `availableFilesForPanel` and the tree-display
  ternary are also left in place (now practically unreachable, not deleted).
- **Rationale**: Reading `buildDownloadFolders` before touching anything revealed the Download button's
  "Combined All" zip format (Update 21/22, a real, separately-specced feature with its own FR range,
  FR-142..FR-160) builds its zip payload directly from `allChipTree`/`allChipDerivedFileMappings`/
  `allChipFiles` — computed independently of `selectedPurchId`/which toolbar tab happens to be active.
  Deleting the "All" computation stack to fully clean up after removing the "All" tab would break a
  working, independently-specced download feature the requester never asked to change (the request was
  about the toolbar's tab *grouping*, not about the zip download's format options). Leaving the dead
  toolbar-reachable branches in place (rather than deleting them) is a deliberate, minimal-diff choice:
  removing them requires re-verifying every remaining reference to `defaultTemplate`/`allChip*` compiles
  and behaves the same, for a code-cleanliness benefit with no user-visible effect, on a screen this
  session cannot test end-to-end in a real browser.
- **Alternatives considered**: (1) Fully delete the All-mode UI branches and hoist `allChipTree`/etc.'s
  Download-only usage directly into `buildDownloadFolders`/`handleDownload` — a genuine simplification,
  but a strictly larger, riskier diff for a request that only asked to change what the toolbar *shows*,
  not to refactor the Download feature's internals; deferred as a follow-up if ever requested explicitly.
  (2) Keep one "All" tab alongside the new per-PO tabs, so users can still reach the merged view visually
  — rejected: the request explicitly says "không nhóm theo template nữa" (no longer grouped by template)
  and asks for the section to show PO-by-PO "rõ ràng" (clearly) — reintroducing a merged/grouped tab
  option directly contradicts that ask, even if it's additive rather than a replacement.

### Decision 93 — Fix `buildDownloadFolders`'s "By Template" zip folders to iterate `templateComputations` directly, not `templatesData.map(...).find(...)`

- **Decision**: `templateFolders` now maps over `templateComputations` (1 entry per PO after this
  update) directly, building 1 zip folder per PO named `"{purchId} - {templateName}"`. The previous
  `templatesData.map(t => { const tc = templateComputations.find(c => c.templateCode ===
  t.templateCode); ... })` pattern is removed.
- **Rationale**: This was not an optional cleanup — it was a correctness fix required by Decision 90/91.
  Once `templateComputations` can hold 2+ entries sharing the same `templateCode` (one per PO), the old
  `.find(c => c.templateCode === t.templateCode)` would silently return only the *first* matching entry,
  meaning the "By Template" zip download would silently drop every file belonging to the second (and
  any further) PO sharing that template — a data-loss regression that would have shipped invisibly
  alongside the toolbar change if not caught while tracing every consumer of `templateComputations`
  before editing (Constitution Principle III). Folder-naming by `"{purchId} - {templateName}"` (rather
  than just `templateName`, which could now collide across 2 folders) keeps each PO's downloaded files
  in their own clearly-labeled folder.
- **Alternatives considered**: Keep grouping zip folders by `templateName` alone, merging 2 POs' mapped
  files into 1 folder when they share a template — rejected: this reintroduces, at the zip-download
  layer, the exact "which PO does this file really belong to" confusion Update 40 exists to eliminate
  from the on-screen toolbar; a downloaded zip should be at least as unambiguous as the screen it was
  downloaded from.

## Update 41 — Bỏ popup chọn định dạng tải; Download luôn tách theo từng PO, mỗi folder chứa toàn bộ file

### Decision 94 — Xóa hẳn toàn bộ "All mode" computation stack, thay vì tiếp tục giữ nhưng không dùng (đảo ngược Quyết định 92)

- **Decision**: `DownloadFormatDialog.jsx` bị xóa khỏi codebase; trong `ViewSalesOrderPage.jsx`, toàn bộ
  nhánh "All mode" mà Quyết định 92 quyết định giữ lại (khi đó chưa dùng tới nhưng chưa xóa) — `defaultTemplate`
  state, `loadDefaultTemplate` + effect gọi nó, `soStepIds`, `allChipFlatDetails`, `allChipTree`,
  `stepIdToFileIds`, `allChipDerivedFileMappings`, `allChipFiles` — nay bị xóa hoàn toàn, cùng với nhánh
  `isAllActive`/`selectedPurchId === null` trong `availableFilesForPanel` và nhánh tương ứng trong khối
  render cây. `buildDownloadFolders`/`handleDownload` bỏ tham số `format`, luôn build folder theo từng PO
  (tái dùng trực tiếp `templateComputations` đã có sẵn từ Update 40, vốn đã là per-PO).
- **Rationale**: Quyết định 92 cố tình giữ lại stack "All mode" vì khi đó Download vẫn còn cung cấp lựa
  chọn "Combined (All)" qua `DownloadFormatDialog`, và đây là hàm tiêu thụ duy nhất còn lại của stack đó
  (mọi tab "All" trên toolbar đã bị xóa từ Update 40). Yêu cầu lần này ("không cần hiển thị popup này nữa,
  mặc định tách ra theo từng po") xóa bỏ chính điểm tiêu thụ cuối cùng đó — khi popup và lựa chọn "Combined
  (All)" không còn tồn tại, `allChipTree`/`allChipDerivedFileMappings`/`allChipFiles`/`soStepIds`/
  `defaultTemplate*` trở thành dead code thực sự (không chỉ "hiện chưa reachable qua UI" như trước), nên xóa
  hẳn theo đúng quy ước "no dead code" đã áp dụng nhất quán trong toàn bộ phiên làm việc này (vd. xóa
  `GetPrefixByStepIdAsync`, `IEutrMastersRepository`, `loadDistinctMasterSteps`). Giữ lại `flatToTree` (từ
  `treeUtils.js`) vì cây per-PO (`poTemplates`/`templateComputations`) vẫn cần build từ danh sách phẳng.
- **Alternatives considered**: Tiếp tục giữ nguyên stack "All mode" như Quyết định 92 (không xóa, chỉ bỏ
  điểm gọi) — rejected: một khi không còn bất kỳ code path nào (UI hay Download) có thể kích hoạt
  `selectedPurchId === null`, việc giữ lại ~7 state/computation không ai gọi tới chỉ tăng diện tích bảo trì
  mà không phục vụ mục đích gì, đi ngược quy ước "no dead code" đã dùng xuyên suốt phiên này.

### Decision 95 — `SalesOrderOverviewPage.jsx` cũng phải chuyển sang `buildPoTemplateComputations`, dù Update 40 không đụng tới file này

- **Decision**: `handleDownload` trong `SalesOrderOverviewPage.jsx` (nút Download trên từng dòng ở màn
  hình Overview) bỏ tham số `format`, xóa hẳn `fetchDefaultTemplateForZip`, build `poTemplates` inline
  (theo đúng pattern Update 40 đã dùng ở 2 file kia), và đổi từ `buildTemplateComputations` (nhóm theo
  TemplateCode) sang `buildPoTemplateComputations` (nhóm theo PurchId, thêm ở Update 40) khi build folder
  zip.
- **Rationale**: File này có logic build-folder-zip của riêng nó (độc lập với `MapFilePage.jsx`/
  `ViewSalesOrderPage.jsx`), và trước Update 41 vẫn dùng `buildTemplateComputations`/nhóm theo
  TemplateCode — nghĩa là mắc đúng lỗi mất dữ liệu mà Quyết định 93 đã sửa ở 2 file kia (2 PO dùng chung 1
  template → `.find(c => c.templateCode === ...)` chỉ giữ 1 PO). Lỗi này nằm ngoài phạm vi Update 40 (khi
  đó chỉ sửa toolbar tabs của Map File/View), nhưng vì Update 41 xóa hẳn popup chọn format — biến "By
  Template" (tức per-PO) thành hành vi duy nhất, mặc định, không thể tắt — thì lỗi tiềm ẩn này ở Overview
  page giờ chắc chắn sẽ bị người dùng gặp phải mỗi lần bấm Download, nên bắt buộc phải sửa cùng lúc thay vì
  để lại như một bug riêng biệt.
- **Alternatives considered**: Chỉ xóa popup ở Overview page, giữ nguyên `buildTemplateComputations` cho
  tới khi có báo lỗi thực tế — rejected: lỗi đã được xác nhận tồn tại qua việc đọc code (không phải suy
  đoán), và vì Update 41 khiến đường dẫn lỗi này trở thành mặc định/không thể né tránh, để lại một lỗi mất
  dữ liệu đã biết trước trong lúc đang sửa chính đường dẫn đó là không phù hợp với quy ước của phiên làm
  việc này (luôn dò hết các nơi gọi liên quan trước khi coi một thay đổi là hoàn tất — Constitution
  Principle III).

## Update 42 — Bảng `eutr_progression` lưu sẵn Total/Missing/Finished; Overview đọc qua JOIN; `test-so-template-sync` lưu thêm ProductVariant/ItemId

### Decision 96 — Thêm bảng cache `eutr_progression` thay vì tối ưu 4 lượt gọi động hiện có

- **Decision**: Thay vì tối ưu lại (giảm số lượt gọi, thêm index, v.v.) 4 lượt gọi API +
  vòng lặp client-side hiện có của `fetchProgressForRows` (`SalesOrderOverviewPage.jsx:203-338`), thêm
  hẳn 1 bảng mới `eutr_progression` (`Id, SalesId, Total, Missing, Finished`) lưu sẵn (cache) kết quả
  tính theo đúng công thức hiện có, và đổi Overview sang đọc thẳng bảng này qua 1 câu JOIN duy nhất theo
  `SalesId`.
- **Rationale**: Yêu cầu gốc chỉ định rõ giải pháp ("tạo 1 bảng eutr_progression ... màn hình
  eutr/sales-orders chỉ cần dựa vào SalesId, join với bảng eutr_progression") — không phải một yêu cầu
  mở ("làm cho nhanh hơn") để tự chọn giải pháp. Cách này cũng triệt để hơn tối ưu lượt gọi: dù giảm
  xuống còn 1-2 lượt gọi, Overview vẫn phải lặp qua từng Sales ID × PO × Template × Step ở client mỗi
  lần hiển thị trang — chuyển hẳn phép tính đó sang thời điểm ghi dữ liệu (4 trigger cố định, xem Quyết
  định 97) khiến thời điểm ĐỌC (Overview) chỉ còn là 1 SELECT đơn giản theo khóa `SalesId`, không phụ
  thuộc số PO/Template/Step của Sales Order đó.
- **Alternatives considered**: (a) Giữ tính động nhưng thêm cache tầng ứng dụng (in-memory/Redis, TTL
  ngắn) — rejected, không khớp yêu cầu gốc (không phải bảng DB), và cache tầng ứng dụng không tự làm
  mới đúng lúc dữ liệu đổi (Save PO Mapping/Upload tài liệu) như 1 bảng được recompute tường minh tại
  đúng các thời điểm đó. (b) Vẫn tính động ở Overview nhưng chuyển toàn bộ phép tính (JOIN/GROUP BY
  ngay trong SQL, không lặp ở client) — rejected, vẫn phải tính lại mỗi lần hiển thị trang thay vì chỉ 1
  lần tại 4 thời điểm dữ liệu thực sự đổi; không khớp yêu cầu gốc.

### Decision 97 — Recompute đúng 1 `SalesId` tại mỗi trigger, không recompute toàn bảng

- **Decision**: Cả 4 trigger (View, Save PO Mapping, Upload/Xóa tài liệu, `test-so-template-sync`) chỉ
  recompute `eutr_progression` cho đúng (các) `SalesId` liên quan trực tiếp tới hành động đó — 3 trigger
  đầu luôn đúng 1 `SalesId`; trigger job đồng bộ recompute cho mọi `SalesId` job đó có xử lý trong lần
  chạy (thêm mới hoặc bỏ qua vì đã tồn tại, xem Quyết định 99), không phải TOÀN BỘ `SalesId` đang có
  trong `eutr_purchase_attachments`.
- **Rationale**: Recompute toàn bảng ở mỗi trigger (đặc biệt View/Save PO Mapping — xảy ra thường xuyên,
  mỗi lần 1 user mở 1 Sales Order) sẽ tạo lại đúng vấn đề hiệu năng ban đầu (chỉ chuyển từ "tính động lúc
  đọc" sang "tính động lúc ghi", không giảm khối lượng tính toán) — đi ngược mục tiêu chính của Update
  này. Vì `Total`/`Missing`/`Finished` chỉ phụ thuộc vào dữ liệu của đúng 1 `SalesId` (không có phép
  tính liên Sales Order nào), recompute phạm vi hẹp là đủ và đúng.
- **Alternatives considered**: Recompute toàn bảng theo lịch (job riêng chạy định kỳ, độc lập với 4
  trigger) — rejected, không thuộc yêu cầu gốc (chỉ định rõ 3 [nay 4] thời điểm cụ thể, không phải theo
  lịch) và làm tăng độ trễ giữa lúc dữ liệu đổi và lúc Overview phản ánh đúng.

### Decision 98 — Thêm Upload/Xóa tài liệu (Step 2 Map File) làm trigger thứ 4 (xác nhận qua AskUserQuestion)

- **Decision**: Ngoài 3 trigger nêu trong yêu cầu gốc (mở View, Save PO Mapping, chạy job
  `test-so-template-sync`), thêm Upload/Xóa tài liệu thành công ở Step 2 Map File (feature
  `004-eutr-documents`) làm trigger thứ 4 — recompute đúng `SalesId` sở hữu PO/step vừa Upload/Xóa.
- **Rationale**: Rà soát mã nguồn xác nhận Upload/Xóa tài liệu (popup "Add tài liệu thật",
  `MapFilePage.jsx`) là một hành động RIÊNG, độc lập với nút Save PO Mapping (chỉ ghi lại lựa chọn PO ở
  `eutr_purchase_attachments`, không liên quan tài liệu) — và chính hành động Upload/Xóa mới là thứ làm
  thay đổi `Finished`/`Missing` (số step "đã đủ hồ sơ"), trong khi `Total` chỉ phụ thuộc PO/Template đã
  lưu. Nếu không có trigger thứ 4 này, `eutr_progression` sẽ hiển thị sai (cũ) ngay sau khi user upload
  tài liệu, cho tới khi họ tình cờ quay lại màn View hoặc bấm lại Save PO Mapping — một hồi quy rõ ràng
  so với hành vi tính động hiện tại (luôn đúng ngay lập tức). Người yêu cầu tính năng xác nhận bổ sung
  trigger này khi được hỏi trực tiếp (xem Clarifications, Update 42).
- **Alternatives considered**: Giữ đúng 3 trigger như yêu cầu gốc liệt kê — rejected bởi người yêu cầu
  tính năng (lựa chọn "Có, thêm làm trigger thứ 4") đúng vì độ trễ hiển thị sai ngay sau thao tác chính
  (upload chứng từ) là rủi ro trải nghiệm cao hơn chi phí thêm 1 điểm gọi recompute.

### Decision 99 — Job `test-so-template-sync` recompute — SỬA LẠI khi triển khai: chỉ `SalesId` MỚI THÊM, không phải cả `SalesId` bị bỏ qua

- **Decision (bản gốc, viết trước khi triển khai)**: Sau khi vòng lặp thêm/bỏ qua bản ghi D365
  refType=19 hoàn tất, job recompute `eutr_progression` cho MỌI `SalesId` mà lần chạy đó có xử lý — kể
  cả `SalesId` bị bỏ qua vì đã tồn tại sẵn trong `eutr_purchase_attachments`.
- **Decision (SỬA LẠI khi triển khai — đây là hành vi thực tế đã code)**: Job chỉ recompute
  `eutr_progression` cho các `SalesId` MỚI THÊM vào `eutr_purchase_attachments` trong lần chạy đó
  (`summary.Added`) — KHÔNG recompute cho `SalesId` bị bỏ qua vì đã tồn tại sẵn (dedupe hiện có,
  `existingSalesIds.Add(salesId)` trả `false`).
- **Rationale (lý do sửa lại)**: Rà soát mã nguồn khi triển khai cho thấy job này, trên dữ liệu thật, đã
  từng xử lý hàng nghìn PO/SalesId trong 1 lần chạy (xem log lỗi thực tế trong
  `compliance-sys-api/src/ComplianceSys.Api/logs/error/`). `RecomputeAsync` cho 1 `SalesId` tự nó không
  rẻ — gọi `IEutrTemplatesService.GetManyByCodesWithDetailsAsync` + 1 lượt D365 refType=16 (OR-join theo
  PurchId) + `IEutrDocumentsService.GetPoReferencesAsync`. Nếu recompute cho MỌI `SalesId` job đọc qua
  (không chỉ SalesId mới), mỗi lần job chạy sẽ nhân số lượt gọi phụ trợ này lên hàng nghìn lần — biến
  chính job "đồng bộ" (vốn đã ghi nhận log lỗi hiệu năng/timeout trong quá khứ) thành điểm nghẽn hiệu
  năng mới, đi ngược đúng mục tiêu chính của Update 42 (giảm tải tính toán). Phần "SalesId bị bỏ qua có
  thể có tài liệu mới từ Upload/Xóa" (rationale gốc) đã được phủ bởi trigger 4 (Quyết định 98) — Upload/
  Xóa tài liệu tự nó đã trigger `RecomputeForPurchIdAsync` ngay tại thời điểm xảy ra, không cần đợi job
  chạy lại mới cập nhật.
- **Alternatives considered**: Giữ nguyên quyết định gốc (recompute cả SalesId bị bỏ qua) — rejected khi
  triển khai vì lý do hiệu năng nêu trên; SalesId đã tồn tại từ trước, chưa từng qua 1 trong 4 trigger
  sau khi Update 42 triển khai, được phủ bởi backfill 1 lần (FR-230,
  `EutrProgressionController.BackfillAll`, `GET /api/eutr-progression/backfill-all`) thay vì job định kỳ.
- **Theo dõi sau triển khai**: Nếu thực tế cho thấy nhiều SalesId vẫn có `eutr_progression` lệch dữ liệu
  dài ngày dù đã có backfill + trigger 4 (ví dụ do Upload tài liệu qua 1 đường khác không đi qua
  `EutrUploadService`), cân nhắc mở rộng lại phạm vi recompute của job hoặc thêm 1 job quét định kỳ
  riêng — chưa cần thiết ở Update 42 này.

### Decision 100 — `ItemId` cần thêm field mới trên `ComplDynReferenceResponseDto`/mapping refType=19; `ProductVariant` tái dùng field đã có

- **Decision**: `ProductVariant` khi ghi vào `eutr_purchase_attachments` từ `SyncSalesOrderTemplatesAsync`
  dùng lại field `ComplDynReferenceResponseDto.ProductVariant` đã có sẵn (hiện chỉ gán cho refType=15);
  `ItemId` cần thêm 1 field mới trên DTO này (và mapping tương ứng cho refType=19 trong
  `ComplDynamicsService`) vì hiện chưa tồn tại field nào tương đương.
- **Rationale**: Rà soát `ComplDynReferenceResponseDto.cs` xác nhận `ProductVariant` đã tồn tại (dùng
  cho refType=15/RSVNEutrPurchOrders) nhưng chưa từng được gán khi map dữ liệu refType=19
  (RSVNEutrSalesOrderPurchases — nguồn của `SyncSalesOrderTemplatesAsync`); và không có field `ItemId`
  nào trên DTO này ở bất kỳ refType nào. Việc thêm field/mapping cụ thể (tên trường D365 tương ứng) là
  chi tiết triển khai ở giai đoạn plan, cần xác nhận với nguồn D365 refType=19 xem có trả về giá trị
  Item tương ứng hay không.
- **Alternatives considered**: Suy ra `ItemId` từ `PurchId` qua một lượt tra cứu riêng (ví dụ query lại
  refType=20 theo PurchId) — rejected, không cần thiết nếu D365 refType=19 đã trả sẵn trường tương ứng
  trong cùng lượt đọc hiện có (research cần xác nhận ở giai đoạn plan/implement); tránh phát sinh thêm 1
  lượt gọi D365 cho mỗi trang dữ liệu chỉ để lấy 1 trường.

### Decision 101 — Backfill 1 lần khi triển khai, không phải trigger tự động lặp lại

- **Decision**: Một lượt backfill chạy 1 lần khi triển khai Update 42 (tính `eutr_progression` cho mọi
  `SalesId` đang có ≥1 bản ghi `eutr_purchase_attachments` từ trước) — không phải một trigger thứ 5 tự
  động chạy lại định kỳ.
- **Rationale**: Không có yêu cầu backfill định kỳ trong mô tả gốc; nếu không backfill 1 lần, Overview
  sẽ hiển thị trạng thái trống cho MỌI Sales Order đã có Template/tài liệu từ trước Update 42 cho tới khi
  user tình cờ mở View/Save PO Mapping/Upload tài liệu cho từng Sales Order đó — một hồi quy hiển thị rõ
  ràng ngay sau khi triển khai. Cơ chế cụ thể (script một lần, hay gọi lặp qua endpoint recompute có sẵn
  cho từng `SalesId`) là quyết định kỹ thuật ở giai đoạn plan.
- **Triển khai thực tế**: `GET /api/eutr-progression/backfill-all` (policy `EutrProgression.Update`,
  `EutrProgressionController.BackfillAll` → `EutrProgressionService.BackfillAllAsync`) — đọc toàn bộ
  `SalesId` qua `GetSalesIdsWithTemplateAsync` (hàm đã có sẵn từ Update 16) rồi gọi `RecomputeAsync` tuần
  tự cho từng SalesId, trả về số lượng đã backfill. Đây là 1 endpoint vận hành gọi thủ công 1 lần sau
  khi deploy (giống tinh thần `test-so-template-sync`/`test-purchase-missing` — các "test-" endpoint
  khác của `011-eutr-synchronize-data` cũng được gọi thủ công, không chạy tự động theo lịch), KHÔNG phải
  1 job chạy định kỳ — có thể mất nhiều thời gian trên dữ liệu thật lớn (mỗi SalesId là 1 lượt
  `RecomputeAsync` đầy đủ, xem chi phí đã nêu ở Quyết định 99).
- **Alternatives considered**: Không backfill, chấp nhận Overview "trống dần lấp đầy" qua 4 trigger tự
  nhiên — rejected, gây hồi quy hiển thị ngay sau khi deploy cho toàn bộ dữ liệu lịch sử, không chấp
  nhận được cho một tính năng đang ở production.

## Update 43 — Thêm 2 ô tìm ItemId/ConfigId ở Overview, lọc qua danh sách SalesId tra từ `RSVNSalesLineOpenInvoiceCogs`

### Decision 102 — Đăng ký `refType = 21` cho `RSVNSalesLineOpenInvoiceCogs` thay vì tạo endpoint riêng

- **Decision**: `RSVNSalesLineOpenInvoiceCogs.cs` (đã tồn tại sẵn, dùng trực tiếp bởi
  `ComplSynchronizeDataService`/`DynamicsDataService` cho mục đích khác) được bổ sung kế thừa
  `RSVNModelBase` (`ModelType = 21`, `EntityName`, `FilterableFields = {ItemId, ConfigId, SalesId}`),
  thêm entry mới vào `EntityMappings` và 1 case mới trong `MapDynamicsResponse` — dùng qua đúng cơ chế
  `POST /api/dynamics/reference` dùng chung mà mọi refType khác (bao gồm refType=11 của chính Overview)
  đang dùng, KHÔNG tạo controller/action riêng cho tra cứu ItemId/ConfigId.
- **Rationale**: Đây là cách nhất quán với TOÀN BỘ lịch sử cập nhật của tính năng này — mọi nguồn dữ
  liệu D365 mới (refType=16 ở Update 1, refType=20 ở Update 17, v.v.) đều đăng ký qua đúng cơ chế
  `EntityMappings`/`MapDynamicsResponse` này thay vì viết controller riêng, giữ đúng 1 con đường duy
  nhất cho mọi truy vấn D365 tham chiếu (Constitution Principle III — tái dùng backend hiện có). Việc
  `RSVNSalesLineOpenInvoiceCogs` đã tồn tại (dùng cho tính năng khác) chỉ thiếu phần kế thừa
  `RSVNModelBase` — bổ sung phần đó không ảnh hưởng 2 nơi đang dùng trực tiếp class này
  (`FetchAllSalesLinesAsync`/`GetSalesLineOpenInvoiceCogsFromDynamics`, cả hai đọc D365 thẳng qua
  `_paramManager`/`_dynamicService`, không đi qua `GetDynRefePagedAsync`/`EntityMappings`).
- **Alternatives considered**: Viết 1 action riêng (ví dụ trong `EutrSynchronizeDataController` hoặc
  1 controller mới) gọi thẳng `RSVNSalesLineOpenInvoiceCogs` giống `DynamicsDataService` đang làm —
  rejected, sẽ tạo 1 con đường D365 thứ hai riêng cho đúng 1 tính năng tìm kiếm, đi ngược nguyên tắc
  dùng chung `POST /api/dynamics/reference` đã áp dụng xuyên suốt tính năng này từ Update 1.

### Decision 103 — Bucket AND-search mới (`"salesidin"`), KHÔNG gộp vào cụm OR-search hiện có của `"custaccount"`/`"vendorcode"`

- **Decision**: `BuildFilterString` (`ComplDynamicsService.cs:177-267`) được thêm 1 bucket mới, ví dụ
  `"salesidin"`, chỉ áp dụng khi `mapping.Entity == "RSVNSalesOrderOpenInvoiceCogs"` — nhận nhiều
  `FilterRequest` cùng tên cột (1 `FilterRequest{Column:"SalesIdIn", Operator:"eq", Value:salesId}`/1
  SalesId), OR các giá trị đó lại thành 1 cụm `(SalesId eq 'A' or SalesId eq 'B' or ...)` **riêng biệt**,
  rồi đưa cụm đó vào `filterParts` (AND với phần còn lại) — KHÔNG dùng chung biến `searchFilters` mà
  `"code"`/`"name"`/`"custaccount"`/`"vendorcode"` đang OR chung với nhau.
- **Rationale**: `"custaccount"` (Update 27) cố tình OR-search cùng cụm với `"code"`/`"name"` vì cả 3
  cùng trả lời 1 câu hỏi "ô tìm kiếm này khớp Sales Order nào" (mở rộng phạm vi khớp). Yêu cầu lần này
  ngược lại về ngữ nghĩa: danh sách SalesId tra được từ ItemId/ConfigId phải THU HẸP kết quả (chỉ những
  Sales Order nào vừa khớp từ khóa/Year/Week VỪA có SalesId trong danh sách đó) — nếu tái dùng
  `searchFilters` chung, 2 nhóm điều kiện có ngữ nghĩa đối lập (mở rộng vs thu hẹp) sẽ bị gộp sai thành
  1 cụm OR, phá vỡ đúng cả 2 mục đích cùng lúc.
- **Alternatives considered**: Gộp thẳng vào `searchFilters` như `"custaccount"` — rejected vì lý do
  ngữ nghĩa trên (đã xác nhận qua đọc kỹ `BuildFilterString`, không phải suy đoán). Dùng toán tử `"in"`
  có sẵn trên `FilterRequest` — rejected, xác nhận `ODataOperatorConverter.ToODataOperator`
  (`Application/Utils/ODataOperatorConverter.cs:20-37`) chỉ hỗ trợ `eq/ne/gt/ge/lt/le` và ném
  `ArgumentException` cho `"in"`; toán tử đó chỉ hoạt động ở các nơi filter local qua Dapper (khác hẳn
  đường D365/OData của tính năng này) — OR-chain nhiều `eq` (đã dùng ở Quyết định 42's
  `GetOrderAccountsByPurchIdsAsync`) là cách duy nhất khả thi cho D365 OData.

### Decision 104 — Quy trình 2 bước chạy ở frontend, không thêm endpoint tổng hợp phía backend

- **Decision**: `SalesOrderOverviewPage.jsx` tự gọi tuần tự/song song 2 lượt `POST /api/dynamics/reference`
  khi Search: (1) `refType=21` lấy danh sách SalesId theo ItemId/ConfigId (nếu có giá trị); (2)
  `refType=11` với danh sách đó đưa vào filter qua bucket `"salesidin"` mới, kết hợp cùng
  `buildSearchFilters()`/`etdFiltersRef` hiện có. Không thêm endpoint backend mới nào gộp 2 bước này
  làm 1.
- **Rationale**: Đây là đúng mô hình hiện có của toàn bộ Overview — Update 24 (Year/ETD Week) và Update
  27 (CustAccount) đều xây filter hoàn toàn ở frontend rồi gọi `POST /api/dynamics/reference` (dùng
  chung), không có endpoint tổng hợp riêng cho tìm kiếm. Giữ nguyên mô hình này tránh phải thêm 1
  controller/DTO mới chỉ để làm việc mà 2 lượt gọi tuần tự ở frontend đã làm được, và nhất quán với
  cách `handleDownload`/`fetchProgressForRows` (trước Update 42) cũng từng gọi nhiều lượt API tuần tự từ
  frontend.
- **Alternatives considered**: Thêm 1 endpoint backend mới nhận `{itemId, configId, ...cácFilterKhac}`
  rồi tự làm cả 2 bước — cân nhắc vì gọn hơn cho frontend, nhưng rejected để giữ nhất quán kiến trúc
  hiện có của đúng màn hình này (mọi filter khác đều ở frontend) và tránh nhân đôi logic
  `BuildFilterString` ở 1 nơi mới.

## Update 42 — Bug fix (phát hiện sau khi triển khai): `RecomputeAsync` ghi `Total=0` cho SalesId KHÔNG có `eutr_purchase_attachments`, khiến Overview hiển thị sai "Không có step bắt buộc" thay vì trạng thái trống

### Decision 105 — Xóa bản ghi `eutr_progression` thay vì ghi `0/0/0` khi SalesId không còn attachment

- **Decision**: `EutrProgressionService.RecomputeAsync`, khi `SalesId` không có bản ghi
  `eutr_purchase_attachments` nào, MUST gọi `IEutrProgressionRepository.DeleteAsync(salesId)` (xóa bản
  ghi `eutr_progression` nếu có) thay vì `UpsertAsync(salesId, 0, 0, 0, ...)` như thiết kế gốc (Quyết
  định ban đầu của Update 42, spec Edge Cases). "Không có bản ghi `eutr_progression`" trở thành điều
  kiện DUY NHẤT cho trạng thái trống ở Overview (FR-228 sửa lại).
- **Rationale**: Xác nhận lỗi thực tế bằng cách đọc trực tiếp dữ liệu production sau khi triển khai:
  nhiều `SalesId` (`SO002778`, `SO001484`, `SO006671`) có bản ghi `eutr_progression` với `Total = 0`
  nhưng **0 bản ghi** `eutr_purchase_attachments` — nghĩa là các Sales Order này CHƯA từng được Save PO
  Mapping, chỉ từng bị mở màn View (trigger 1) một lần, khiến thiết kế gốc ghi nhầm `0/0/0` vào
  `eutr_progression`. Overview sau đó không phân biệt được bản ghi này với 1 SalesId THẬT SỰ có Template
  đã lưu nhưng 0 step bắt buộc (FR-084) — cả hai đều chỉ là `Total = 0` trong bảng, nên hiển thị nhầm
  "Không có step bắt buộc" cho các Sales Order thực ra hoàn toàn chưa có Template nào, trong khi cột
  Template của cùng dòng đó (đọc từ nguồn khác, không qua `eutr_progression`) vẫn hiển thị đúng trạng
  thái trống — 2 cột mâu thuẫn nhau trên cùng 1 dòng, dấu hiệu rõ ràng của lỗi.
  Thiết kế gốc dựa trên tiền đề "cần phân biệt 'chưa từng trigger' với 'đã trigger nhưng rỗng'" — tiền
  đề này sai: cả hai trạng thái đều phải hiển thị GIỐNG HỆT nhau cho người dùng (trạng thái trống,
  FR-083), nên việc phân biệt chúng trong dữ liệu lưu trữ là thừa và chính là nguồn gốc lỗi.
- **Khắc phục dữ liệu đã có**: chạy 1 lần `DELETE FROM eutr_progression WHERE SalesId NOT IN (SELECT
  DISTINCT SalesId FROM eutr_purchase_attachments)` để dọn các bản ghi "mồ côi" đã ghi sai trước khi có
  bản sửa này (xác nhận đã chạy, xóa đúng 3 bản ghi nêu trên).
- **Alternatives considered**: Thêm 1 cột/cờ riêng trên `eutr_progression` để đánh dấu "đã từng
  trigger" tách biệt với `Total` — rejected, thêm phức tạp không cần thiết khi giải pháp đơn giản hơn
  (xóa bản ghi) đã giải quyết đúng vấn đề và khớp lại đúng ngữ nghĩa gốc của FR-083 (không có bản ghi
  `eutr_purchase_attachments` = trạng thái trống) mà không cần khái niệm mới nào.

## Update 44 — Remove AVAILABLE FILES pagination

- **Decision 1**: Render all files in one scrollable list; drop `filePage` state entirely. Rationale: data is already fully loaded client-side, pagination only sliced it; the container already scrolls. Alternatives: virtualization (rejected — overkill for tens/hundreds of rows); "show more" button (rejected — user asked to remove paging).
- **Decision 2**: Footer shows "N files" (count after tree-node filter). Alternative: remove footer (rejected — losing the count is a regression).
- **Decision 3**: Step-filter change no longer needs to reset the page; remove any `setFilePage(1)` calls.

## Update 45 — Group Step 1 / View PO table by sales line

- **Decision 1**: Reuse refType=21 (Update 43) for the line list, extending its response with ProductName/ProductDescription; no new endpoint. Alternative: a new aggregate server endpoint (rejected — pages already compose generic reference calls client-side, Constitution II/III).
- **Decision 2** (revised): Group key = `ItemId-ConfigId` (just `ItemId` when no ConfigId), compared case-insensitively/trimmed to the PO line's `ProductVariant`; header label `ItemId-ConfigId  ProductName / ProductDescription`. Alternative: match on PO ItemId/Material + variant (rejected by the business — ProductVariant already carries `ItemId-ConfigId`).
- **Decision 3**: Dedupe refType=21 rows by (ItemId, ConfigId) since one sales line = one row but repeated keys must merge into one group (spec edge case).
- **Decision 4**: Orphan POs go to an "Other purchase orders" group and lines without PO show "No purchase order", so nothing selectable/visible disappears.
- **Decision 5** (revised): Expansion state is local UI state (`Set` of expanded group keys), independent from `selectedPOs`; default all collapsed.
- **Decision 6**: ProductName/ProductDescription come from the D365 entity columns (as requested), not from the refType=6 enrichment used by the sync job.
- **Decision 7**: Wait for both refType=20 and refType=21 before rendering groups (shared loading flag) — rendering early put every PO into "Other purchase orders" until the lines arrived. The two requests already run in parallel (independent effects).
- **Decision 8**: View's Selected Purchase Orders reuses the same grouped table and full PO list as Map File; saved POs are shown ticked, checkboxes locked (`readOnly`), no Save PO Mapping button.

- **Decision 9 (thay thế Decision 1–4, 7)**: Chỉ dùng `RSVNEutrSalesOrderPurchLines` (type = 20), gom theo ProductVariant, thêm ProductName/ProductDescription vào entity này; không gọi refType=21. Lý do: ProductVariant đã là khóa của nhóm, bỏ 1 lần gọi D365 và loại bỏ nhu cầu ghép khóa/chờ 2 nguồn.


## Update 46 — Group header from `RSVNEutrOpenSalesLines`, POs matched by ProductVariant

- **Decision 1**: Dùng refType mới = 22 (`RSVNEutrOpenSalesLines`, `ModelType` đã khai báo) qua cơ chế tham chiếu chung, lọc `SalesId eq <id>`; không thêm endpoint. Alternative: endpoint tổng hợp phía server (loại — các trang đã ghép nhiều lời gọi tham chiếu).
- **Decision 2**: Khóa nhóm = `ItemId-configId` (chỉ `ItemId` nếu configId rỗng), so khớp với `ProductVariant` của PO đã trim/lowercase. Giữ cách so khớp của Update 45 nên Select/Save PO Mapping không đổi.
- **Decision 3**: Tiêu đề = `ItemId-configId  Name / Description` lấy từ cột `Name`/`Description` của API 22; thay vai trò `ProductName/ProductDescription` của refType=20 (các trường này giữ lại nhưng không dùng cho tiêu đề).
- **Decision 4**: Trùng ItemId-configId gộp một nhóm; nhóm không PO vẫn hiển thị "No purchase orders"; PO không khớp vào nhóm cuối "—" (không mất PO).
- **Decision 5**: Chờ cả refType=20 và 22 xong mới render (cờ loading chung); lỗi refType=22 hiển thị thông báo lỗi sẵn có kèm retry.

## Update 51 — Save PO Mapping ghi lịch sử `eutr_history` (FR-255)

- **Decision 1**: Trong `EutrPurchaseAttachmentsService.SavePoMappingAsync`, TRƯỚC `DeleteBySalesIdAsync` đọc tập PurchId cũ (`_repository.GetBySalesIdAsync`, distinct); tập mới = distinct PurchId của `validItems`. Rationale: `SavePoMapping` xóa-rồi-ghi-lại toàn bộ theo SalesId nên phải diff trước khi xóa.
- **Decision 2**: Đơn vị so sánh là **PO (PurchId)**, không phải (PO, Variant, ItemId): thêm/bớt dòng hàng của một PO đã map không sinh dòng lịch sử. Added = mới − cũ → Note `checked`; Removed = cũ − mới → Note `Unchecked`. Mỗi PO một dòng.
- **Decision 3**: Ghi lịch sử SAU `CommitAsync` thành công (ngoài transaction), bọc try/catch + log; lỗi ghi không làm thất bại Save và không rollback mapping. Không ghi nếu Save lỗi/rollback.
- **Decision 4**: Dòng: Type=1, Value=SalesId, RefValue=PurchId, Version=null, CreatedBy=userEmail (đã có trong chữ ký), CreatedDate=UtcNow. Không đổi controller/DTO/FE.
- **Decision 5**: Bảng/entity/migration dùng chung với 012 Update 15: Entity `EutrHistory` ([Table("eutr_history")], `long Id`, KHÔNG kế thừa `BaseEntity` vì bảng không có UpdatedBy/UpdatedDate — cùng kiểu `ComplMasterDefaultLog`), ghi qua `IRepository<EutrHistory, long>` generic (đã đăng ký open-generic ở `Infrastructure/DependencyInjection.cs`), không cần repository riêng. Migration: `Sqls/Migration/37_create_eutr_history.sql` (CREATE TABLE IF NOT EXISTS, giống hệt `Sqls/Tables/eutr_history.sql`); cột: `Id` BIGINT AUTO_INCREMENT PK, `Type` TINYINT NOT NULL, `Value` VARCHAR(50) NOT NULL, `RefValue` VARCHAR(50) NOT NULL, `Version` INT NULL, `Note` VARCHAR(50) NULL, `CreatedBy` VARCHAR(50) NOT NULL, `CreatedDate` DATETIME NOT NULL. Index gợi ý `(Type, Value)` để tra theo PO/SalesId.
- **Decision 6 (sửa sau khi chạy thật)**: `DapperRepository.AddAsync` ném "requires an active transaction" nếu gọi ngoài transaction → việc ghi `eutr_history` MUST bọc trong `BeginTransactionAsync`/`CommitAsync` riêng (rollback khi lỗi), sau transaction chính / sau khi D365 thành công.

## Update 52 — `eutr_history.ProductVariant`

- **Decision 1**: Cột mới gộp thẳng vào `37_create_eutr_history.sql` và `Sqls/Tables/eutr_history.sql` (không có migration riêng).
- **Decision 2**: Diff `SavePoMappingAsync` theo khóa (PurchId, ProductVariant) thay vì PurchId (xem spec Update 52).
