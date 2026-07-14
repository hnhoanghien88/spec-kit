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

## Decision 4 — Template / Progress columns

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

## Non-goals confirmed out of scope (from spec Assumptions)

- No Create/Edit/Delete for Sales Orders (read-only feature).
- `MapFilePage.jsx` / `ViewSalesOrderPage.jsx` and the `mock/` fixtures they still depend on are not
  touched by this feature.
- Menu/permission DB seeding for `eutr-sales-orders` is an ops step outside this feature's code
  (already assumed wired per Constitution Principle V check above).
