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

## Updated non-goals (Update 2)

- Upload (new file) and Save (file↔step mapping) on Step 2 remain display-only/no-op — no backend
  endpoint is added or called for either action in this update (spec FR-029/FR-030).
- `ViewSalesOrderPage.jsx` remains fully on mock data — out of scope for this update (not named in the
  feature description); still MUST NOT be broken by shared `mock/` file edits (same guardrail as
  Update 1's non-goals).
- No change to `SalesOrderOverviewPage.jsx` or the Update 1 `by-sales-ids` (plural) endpoint/contract —
  Update 2 only adds two new actions alongside it on the same controller.
