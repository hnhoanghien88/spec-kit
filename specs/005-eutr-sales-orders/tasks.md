---

description: "Task list for feature implementation"
---

# Tasks: EUTR Sales Orders Management

**Input**: Design documents from `/specs/005-eutr-sales-orders/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/dynamics-reference-refType-11.md](./contracts/dynamics-reference-refType-11.md), [quickstart.md](./quickstart.md)

**Tests**: Not requested in the feature spec, and no existing automated test class covers `ComplDynamicsService`/`DynController` today, nor does `compliance-client` have an automated harness for this page — validation is via the manual steps in `quickstart.md` (Polish phase below), consistent with how this repo has validated prior EUTR features.

**Organization**: Tasks are grouped by user story (from spec.md) so each story is independently implementable and testable.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Maps task to a user story (US1/US2/US3) for traceability
- File paths are repo-relative (repo root: `e:\Working\Eutr`)

## Path Conventions

Existing monorepo web app layout (per plan.md) — no new top-level structure:
- Backend: `compliance-sys-api/src/ComplianceSys.Application/...`
- Frontend: `compliance-client/src/presentation/pages/eutr-sales-orders/...`

---

## Phase 1: Setup

**Purpose**: Confirm the environment this brownfield change builds on is ready. No new project
scaffolding is created (route/menu/DI/use case already exist per plan.md).

- [X] T001 Confirm `compliance-sys-api` (with a valid D365 connection) and `compliance-client` both
  run locally, and that navigating to `/eutr/sales-orders` currently renders the existing mock-data
  `SalesOrderOverviewPage.jsx` without errors (baseline before making changes).
  *(Baseline confirmed via `dotnet build` and `npm run build`, both clean, before any edits — no
  live D365-connected runtime was available in this environment to click through the UI.)*

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Close the verified backend gap — `refType = 11` currently returns an empty list
(no `EntityMappings` entry). Every user story below needs this closed first, since all 3 read
their data through it.

**⚠️ CRITICAL**: No user story work can be meaningfully tested until this phase is complete.

- [X] T002 [P] Add nullable `CustAccount` (string) and `DeliveryDate` (DateTime?) properties to
  `ComplDynReferenceResponseDto` in
  `compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/ComplDynReferenceResponseDto.cs`
  (additive only — do not change `Id`/`Code`/`Name`), per data-model.md's DTO change table.
- [X] T003 [P] Add the entry
  `{ (int)ObjectType.SALE_ORDER, ("RSVNSalesOrderOpenInvoiceCogs", "SalesId", "CustName") }`
  to the `EntityMappings` dictionary in
  `compliance-sys-api/src/ComplianceSys.Application/Services/ComplDynamicsService.cs` (do not
  remove or change the existing unrelated `{ 0, (...) }` entry for the same entity), per
  research.md Decision 1.
- [X] T004 Add a `case 11:` branch to `MapDynamicsResponse` in
  `compliance-sys-api/src/ComplianceSys.Application/Services/ComplDynamicsService.cs` that
  deserializes items as `List<RSVNSalesOrderOpenInvoiceCogs>` and projects each into
  `ComplDynReferenceResponseDto` with `Id`/`Code` = `SalesId`, `Name` = `CustName`, `CustAccount` =
  `CustAccount`, `DeliveryDate` = `DeliveryDate` (depends on T002, T003 — same file as T003, apply
  after it).
- [ ] T005 Manually verify `POST /api/dynamics/reference?page=1&pageSize=10&refType=11` (body `[]`)
  returns non-empty `items` with populated `code`/`name`/`custAccount` and either a populated or
  `null` `deliveryDate`, per contracts/dynamics-reference-refType-11.md, and that
  `refType=15` (`EUTR_PURCH_ORDER`, used by `eutr-documents`) still returns its usual shape
  unaffected (depends on T002-T004).
  *(NOT run — requires a live `compliance-sys-api` process with a real D365 connection, unavailable
  in this environment. `dotnet build` confirms the code compiles; the actual HTTP round-trip against
  D365 still needs to be run by someone with that access before sign-off.)*

**Checkpoint**: Foundation ready — `refType=11` now returns real Sales Order data end to end.

---

## Phase 3: User Story 1 - Xem danh sách EUTR Sales Orders (Priority: P1) 🎯 MVP

**Goal**: Replace the page's mocked Sales ID/Customer/Customer name/Delivery date with real data
from `refType=11`, while Template/Progress become fixed demo values (not computed).

**Independent Test**: Open `/eutr/sales-orders` and confirm the grid shows real Sales ID, Customer,
Customer name, Delivery date (or "-" placeholder) sourced from the reference endpoint, with
Template/Progress showing the same fixed demo value on every row.

### Implementation for User Story 1

- [X] T006 [US1] In
  `compliance-client/src/presentation/pages/eutr-sales-orders/SalesOrderOverviewPage.jsx`, replace
  the `MOCK_SALES_ORDERS`-based `rows` (`useMemo`) with a real fetch: add a local
  `EUTR_SALES_ORDER_REF_TYPE = 11` constant (mirroring `EUTR_PURCH_ORDER_REF_TYPE` in
  `compliance-client/src/presentation/pages/eutr-documents/EutrDocumentsAdd.jsx`), call
  `GetReferenceDataUseCase` (`compliance-client/src/application/usecases/dynamics/index.js`) via
  `repositories.dynamics` (`compliance-client/src/di/repositories.js`) on mount, and store the
  result in component state instead of importing `MOCK_SALES_ORDERS`/`MOCK_FILE_MAPPINGS` from
  `./mock/eutrSalesOrders`.
- [X] T007 [US1] In the same file, map each fetched item to the grid row shape per data-model.md
  (Sales ID ← `code`, Customer ← `custAccount`, Customer name ← `name`, Delivery date ←
  `deliveryDate`), replacing the old `row.salesId`/`row.customerId`/`row.customerName`/
  `row.deliveryDate` mock fields (depends on T006).
- [X] T008 [US1] In the same file, render `"-"` in the Delivery Date `TableCell` when
  `deliveryDate` is null/empty instead of calling `new Date(row.deliveryDate).toLocaleDateString(...)`
  unconditionally (depends on T007).
- [X] T009 [US1] In the same file, replace the Template/Progress cell logic (`EUTR_TEMPLATES.find`,
  `computeProgress`, `progressColor`) with a fixed static demo value rendered identically on every
  row (per spec FR-007/FR-008 and research.md Decision 4), and remove the now-unused
  `computeProgress`/`progressColor` functions and the `EUTR_TEMPLATES`/`EUTR_TEMPLATE_DETAILS_MAP`
  imports (depends on T006).
- [X] T010 [US1] In the same file, add loading and error UI states around the fetch (e.g. a
  spinner while loading, a clear "failed to load" message on error) so a reference-endpoint failure
  is visibly distinct from zero results (spec Edge Cases) (depends on T006).
- [X] T011 [US1] In the same file, confirm the existing empty-state row ("Không tìm thấy Sales
  Order nào") still renders correctly when the real fetch returns zero items (depends on T007).

**Checkpoint**: User Story 1 is fully functional and independently testable — real data list with
fixed demo Template/Progress columns.

---

## Phase 4: User Story 2 - Tìm kiếm sales order theo Sales ID hoặc Customer (Priority: P2)

**Goal**: Search box filters via the reference endpoint (server-side "contains" match) instead of
the current client-side `.filter()` over already-loaded mock rows.

**Independent Test**: Type a known Sales ID or Customer name/code into the search box and confirm
only matching rows remain; clear the search and confirm the full list returns.

### Implementation for User Story 2

- [X] T012 [US2] In
  `compliance-client/src/presentation/pages/eutr-sales-orders/SalesOrderOverviewPage.jsx`, replace
  the local `filtered = rows.filter(...)` client-side search with a debounced re-fetch through
  `GetReferenceDataUseCase`, passing `Code`/`Name` `like` filters built from the search box value
  (mirroring the `debouncedFetchPoList` pattern in
  `compliance-client/src/presentation/pages/eutr-documents/EutrDocumentsAdd.jsx`) (depends on
  T006, T007).
- [X] T013 [US2] In the same file, ensure clearing the search box re-fetches the default (unfiltered)
  list, matching the existing default-list behavior (depends on T012).
- [X] T014 [US2] In the same file, confirm/implement the "No data" empty state when the search
  yields zero matches (depends on T012).

**Checkpoint**: User Stories 1 and 2 both work independently.

---

## Phase 5: User Story 3 - Chuyển trang khi danh sách dài (Priority: P3)

**Goal**: Add pagination so users can page through Sales Orders beyond the first page.

**Independent Test**: With more Sales Orders than fit on one page, click to the next page and
confirm the grid shows that page's rows.

### Implementation for User Story 3

- [X] T015 [US3] In
  `compliance-client/src/presentation/pages/eutr-sales-orders/SalesOrderOverviewPage.jsx`, add
  pagination UI (e.g. MUI `TablePagination`) below the table, wired to local `page`/`pageSize`
  state (depends on T006).
- [X] T016 [US3] In the same file, wire the page-change handler to re-invoke
  `GetReferenceDataUseCase` with the new page number and replace the displayed rows (depends on
  T015).

**Checkpoint**: All three user stories are independently functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation across the whole feature; no new functionality.

- [ ] T017 [P] Run the backend verification steps in
  `specs/005-eutr-sales-orders/quickstart.md` (refType=11 contract check + refType=15
  no-regression check).
  *(NOT run — no live D365-connected `compliance-sys-api` process available in this environment.
  `dotnet build` on `ComplianceSys.Application` and `ComplianceSys.Api` succeeds with 0 errors as a
  proxy check; someone with D365 access must run the actual HTTP calls before sign-off.)*
- [ ] T018 [P] Run the frontend manual verification steps in
  `specs/005-eutr-sales-orders/quickstart.md` (steps 1-6: load, search match, search no-match,
  load-failure state).
  *(NOT run — requires a browser against a live backend with D365 data, unavailable here. `npm run
  build` succeeds and `eslint` reports no issues on the changed file as a proxy check; a human needs
  to click through quickstart.md's 6 steps before sign-off.)*
- [X] T019 [P] Confirm
  `compliance-client/src/presentation/pages/eutr-sales-orders/MapFilePage.jsx` and
  `.../ViewSalesOrderPage.jsx` still load without errors and that
  `compliance-client/src/presentation/pages/eutr-sales-orders/mock/*.js` files were not modified
  (per plan.md's "out of scope, do not touch" list).
  *(Verified: `npm run build` output includes clean `MapFilePage.*.js`/`ViewSalesOrderPage.*.js`
  chunks with no errors; `git status`/diff in the `compliance-client` repo shows no changes under
  `mock/` — only `SalesOrderOverviewPage.jsx` was edited.)*
- [X] T020 Review new/changed lines in
  `compliance-sys-api/src/ComplianceSys.Application/Services/ComplDynamicsService.cs` and
  `.../Dtos/Response/ComplDynReferenceResponseDto.cs` to confirm any added comments are in
  Vietnamese, per Constitution Principle IV.
  *(Verified via `git diff` — the two added comments ("Bo sung cho refType=11...", "refType=11
  (ObjectType.SALE_ORDER)...") are Vietnamese, unaccented ASCII per this codebase's existing
  comment style.)*

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies.
- **Foundational (Phase 2)**: Depends on Setup — BLOCKS all user stories (T002-T004 must land
  before any story's manual test is meaningful; T005 is a checkpoint, not a hard blocker for
  starting frontend work).
- **User Stories (Phase 3-5)**: All depend on Foundational (T002-T004) actually returning real
  data; can otherwise proceed in priority order (P1 → P2 → P3) since US2/US3 build on the same file
  US1 changes (T006/T007), not on separate infrastructure.
- **Polish (Phase 6)**: Depends on all desired user stories being complete.

### User Story Dependencies

- **User Story 1 (P1)**: Depends only on Foundational. No dependency on US2/US3.
- **User Story 2 (P2)**: Builds on US1's data-fetch plumbing (T006/T007) in the same file; not
  required for US1 to be considered done/testable.
- **User Story 3 (P3)**: Builds on US1's data-fetch plumbing (T006); independent of US2.

### Parallel Opportunities

- T002 and T003 touch different files and can run in parallel.
- T017, T018, T019 (Polish) are independent verification passes and can run in parallel.
- Because `SalesOrderOverviewPage.jsx` is a single shared file, most US1/US2/US3 implementation
  tasks are sequential (no `[P]`) to avoid edit conflicts — this is a small, single-file frontend
  change by nature (per plan.md's Project Structure).

---

## Parallel Example: Phase 2 (Foundational)

```bash
# Launch independent-file foundational tasks together:
Task: "Add CustAccount/DeliveryDate to ComplDynReferenceResponseDto.cs"
Task: "Add EntityMappings[11] entry to ComplDynamicsService.cs"
# Then, sequentially (same file as the EntityMappings task):
Task: "Add case 11 to MapDynamicsResponse in ComplDynamicsService.cs"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL — closes the `refType=11` gap)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: real Sales ID/Customer/Customer name/Delivery date visible, Template/
   Progress fixed, per quickstart.md steps 1-3
5. Demo if ready — search (US2) and pagination (US3) can ship as fast-follow increments

### Incremental Delivery

1. Setup + Foundational → backend gap closed, verified via T005
2. Add User Story 1 → grid shows real data → demo (MVP)
3. Add User Story 2 → server-side search → demo
4. Add User Story 3 → pagination → demo
5. Polish → full quickstart.md pass

---

## Notes

- No `[Story]` label on Setup/Foundational/Polish tasks, per task format rules.
- Tests were not requested for this feature and no existing automated harness covers this code
  path — validation is manual via quickstart.md (T017/T018), not a TDD red/green cycle.
- Total scope is intentionally small: 2 backend files, 1 frontend file — this is a data-source
  swap on an already-built, already-routed page, not new feature scaffolding.

---

## Update 2026-07-16 — Template Column Real Data (`eutr_purchase_attachments`)

**Context**: Per spec Update 1, the Template column stops showing a fixed demo value (old
FR-007) and instead MUST show real data from `eutr_purchase_attachments` (joined with
`eutr_templates` for the display name), keyed by `SalesId`, including the case where one
`SalesId` has multiple templates (multiple `PurchId` rows with different `TemplateCode`s). Per
research.md Decisions 5-8 and plan.md's updated Project Structure, `eutr_purchase_attachments` has
**zero existing backend surface**, so this update adds one small new backend feature end to end
(cloned from `EutrTemplates`) plus a matching new frontend read path (cloned from the
`eutr-templates` frontend layering). Progress is unaffected (still fixed demo, FR-008).

**Changes**: Backend — new `EutrPurchaseAttachments` entity/repository/service/controller (new
`POST /api/eutr-purchase-attachments/by-sales-ids` endpoint). Frontend — new domain
interface/api client/REST repository/use case, wired into the already-existing
`SalesOrderOverviewPage.jsx` to replace its hardcoded `DEMO_TEMPLATE_LABEL`.

**Prerequisites for this update**: [research.md Decisions 5-8](./research.md),
[data-model.md "Entity: Purchase Attachment"](./data-model.md),
[contracts/eutr-purchase-attachments.md](./contracts/eutr-purchase-attachments.md),
[quickstart.md backend steps 4-7 / frontend steps 4-5](./quickstart.md).

---

## Phase 7: Backend — `EutrPurchaseAttachments` Entity, Repository, Service, Controller

**Purpose**: Build the new, currently-nonexistent read path over `eutr_purchase_attachments` +
`eutr_templates`, following the exact 4-layer pattern already used by `EutrTemplates`.

- [X] T021 [P] Create entity `EutrPurchaseAttachments` in
  `compliance-sys-api/src/ComplianceSys.Domain/Entities/EutrPurchaseAttachments.cs` —
  `[Table("eutr_purchase_attachments")]`, `EutrPurchaseAttachments : BaseEntity`, `[Key] public int
  Id { get; set; }` (table PK is `INT UNSIGNED`, not `BIGINT UNSIGNED` like `EutrTemplates`), plus
  `SalesId`, `PurchId`, `TemplateCode` (all `string`). Vietnamese comment per Constitution
  Principle IV, matching `EutrTemplates.cs`'s comment style.
- [X] T022 [P] Create DTO `SalesOrderTemplateDto` in
  `compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/SalesOrderTemplateDto.cs` — flat
  record/class with `SalesId`, `TemplateCode`, `TemplateName` (all `string`), per data-model.md.
- [X] T023 Create repository interface `IEutrPurchaseAttachmentsRepository` in
  `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Repositories/
  IEutrPurchaseAttachmentsRepository.cs`, adding `Task<List<SalesOrderTemplateDto>>
  GetTemplatesBySalesIdsAsync(IEnumerable<string> salesIds, CancellationToken ct = default);`
  (depends on T021, T022).
  *(Implemented as a **standalone** interface, not extending generic `IRepository<,>` — matching
  the established `IEutrReferencesRepository`/`IEutrReferenceDetailsRepository` precedent for
  read-only JOIN-query repositories in this codebase, since nothing here needs generic
  Create/Update/Delete. Return type is `List<T>`, matching this codebase's actual convention
  (`IEutrReferencesRepository`'s methods), not `IReadOnlyList<T>` as originally drafted.)*
- [X] T024 Create repository implementation `EutrPurchaseAttachmentsRepository` in
  `compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/
  EutrPurchaseAttachmentsRepository.cs`, extending `DapperRepository<EutrPurchaseAttachments, int>`,
  implementing `GetTemplatesBySalesIdsAsync` with `SELECT DISTINCT pa.SalesId, pa.TemplateCode,
  t.Name AS TemplateName FROM eutr_purchase_attachments pa INNER JOIN eutr_templates t ON t.Code =
  pa.TemplateCode WHERE pa.SalesId IN @SalesIds` (research.md Decision 6 — `DISTINCT` dedupes
  repeated templates per Sales ID, `INNER JOIN` silently skips orphaned `TemplateCode`s) (depends
  on T023).
- [X] T025 [P] Create service interface `IEutrPurchaseAttachmentsService` in
  `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Services/
  IEutrPurchaseAttachmentsService.cs` — `Task<List<SalesOrderTemplateDto>>
  GetTemplatesBySalesIdsAsync(IEnumerable<string> salesIds, CancellationToken ct = default);`
  (depends on T022).
- [X] T026 Create service implementation `EutrPurchaseAttachmentsService` in
  `compliance-sys-api/src/ComplianceSys.Application/Services/EutrPurchaseAttachmentsService.cs` —
  thin pass-through to `IEutrPurchaseAttachmentsRepository.GetTemplatesBySalesIdsAsync`.
  *(Implemented as a **standalone** service, not extending `BaseService`/`IBaseService` — matching
  the precedent of other non-full-CRUD services in this codebase such as
  `EutrConditionAssignmentService`, since `BaseService<TEntity,TKey,TRequestDto>` requires a
  Create/Update request DTO this read-only feature doesn't have.)* (depends on T023, T025).
- [X] T027 [P] Register `services.AddScoped<IEutrPurchaseAttachmentsService,
  EutrPurchaseAttachmentsService>();` in
  `compliance-sys-api/src/ComplianceSys.Application/DependencyInjection.cs`, next to the existing
  `IEutrTemplatesService` registration (depends on T025, T026).
- [X] T028 [P] Register `services.AddScoped<IEutrPurchaseAttachmentsRepository,
  EutrPurchaseAttachmentsRepository>();` in
  `compliance-sys-api/src/ComplianceSys.Infrastructure/DependencyInjection.cs`, next to the existing
  `IEutrTemplatesRepository` registration (depends on T023, T024).
- [X] T029 Create controller `EutrPurchaseAttachmentsController` in
  `compliance-sys-api/src/ComplianceSys.Api/Controllers/EutrPurchaseAttachmentsController.cs` —
  `[Authorize] [ApiController] [Route("api/eutr-purchase-attachments")]`, one action:
  `[Authorize(Policy = "EutrPurchaseAttachments.Read")] [HttpPost("by-sales-ids")]` accepting
  `[FromBody] List<string> salesIds`, returning empty list for empty/null input (not an error), else
  calling `IEutrPurchaseAttachmentsService.GetTemplatesBySalesIdsAsync` and wrapping the result in
  `ApiResponse<List<SalesOrderTemplateDto>>.Ok(...)`, per contracts/eutr-purchase-attachments.md
  (depends on T025-T028).
- [ ] T030 Manually verify the new endpoint per quickstart.md backend steps 4-7: seed rows in
  `eutr_purchase_attachments` for a known Sales ID with (a) two distinct `TemplateCode`s, (b) a
  duplicate `PurchId` row reusing one of those `TemplateCode`s, (c) a `TemplateCode` not present in
  `eutr_templates`; confirm `POST /api/eutr-purchase-attachments/by-sales-ids` returns exactly the
  2 distinct, non-orphaned templates, and returns an empty list for a Sales ID with no attachment
  rows (depends on T029).
  *(NOT run — requires a live `compliance-sys-api` process with a real/seedable MySQL DB, not
  available in this environment. `dotnet build` on the affected projects compiles with 0 `error CS`
  — the only build failures were `MSB3027`/`MSB3021` file-lock errors from a separately-running
  `ComplianceSys.Api.exe` instance already holding its own output DLLs open, not a code defect.
  Someone with DB/API access must run the actual seed-and-call steps before sign-off.)*

**Checkpoint**: `POST /api/eutr-purchase-attachments/by-sales-ids` returns deduped, orphan-free
template data for any batch of Sales IDs — ready for the frontend to consume.

---

## Phase 8: Frontend — Purchase Attachments Read Path (domain/infrastructure/application layers)

**Purpose**: Add the frontend layers needed to call the new endpoint, cloned from the existing
`eutr-templates` feature's layering (Constitution Principle I/II).

- [X] T031 [P] Create `compliance-client/src/domain/interfaces/IEutrPurchaseAttachmentsRepository.js`
  — abstract-class-style interface with one method, `getTemplatesBySalesIds(salesIds)`, mirroring
  the style of `IEutrTemplatesRepository.js`.
- [X] T032 [P] Create `compliance-client/src/infrastructure/api/eutrPurchaseAttachmentsApi.js` —
  one method calling `POST /eutr-purchase-attachments/by-sales-ids` with the Sales ID array as the
  request body, mirroring `eutrTemplatesApi.js`'s axios-call style.
- [X] T033 Create `compliance-client/src/infrastructure/repositories/
  RestEutrPurchaseAttachmentsRepository.js` — implements `IEutrPurchaseAttachmentsRepository`,
  calls `eutrPurchaseAttachmentsApi`, returns `res.data` (the full `ApiResponse` envelope, unwrapped
  by the caller) — matching `RestEutrTemplatesRepository.getAllPaging`'s exact same
  return-envelope-as-is convention, not a pre-unwrapped array (depends on T031, T032).
- [X] T034 Create `compliance-client/src/application/usecases/eutr-purchase-attachments/
  GetTemplatesBySalesIdsUseCase.js` — `execute(salesIds)` delegates to
  `repository.getTemplatesBySalesIds(salesIds)`, mirroring `GetEutrTemplatesUseCase.js`'s shape
  (depends on T033).
- [X] T035 [P] Register `eutrPurchaseAttachments: new RestEutrPurchaseAttachmentsRepository()` in
  `compliance-client/src/di/repositories.js`, next to the existing `dynamics`/`eutrTemplates`
  entries (depends on T033).

**Verification**: `npm run build` (Vite) succeeds, producing a clean `SalesOrderOverviewPage.*.js`
chunk with all new imports resolved — confirms the DI wiring and alias paths are correct.

**Checkpoint**: `GetTemplatesBySalesIdsUseCase.execute([...salesIds])` resolves with the deduped
template list from the new endpoint — ready to wire into the grid.

---

## Phase 9: User Story 1 (continued) — Wire Template Column to Real Data

**Goal**: Replace the fixed `DEMO_TEMPLATE_LABEL` in `SalesOrderOverviewPage.jsx` with real,
possibly multi-valued template data per row, sourced from Phase 7/8's new read path.

**Independent Test**: Open `/eutr/sales-orders`; a Sales ID with 2 distinct templates in
`eutr_purchase_attachments` shows both template names on its row; a Sales ID with none shows a
clear empty state ("-"); no row shows the old fixed `DEMO_TEMPLATE_LABEL` text.

### Implementation for User Story 1 (Template column)

- [X] T036 [US1] In
  `compliance-client/src/presentation/pages/eutr-sales-orders/SalesOrderOverviewPage.jsx`, remove
  the `DEMO_TEMPLATE_LABEL` constant and its `Chip label={DEMO_TEMPLATE_LABEL}` usage in the
  Template `TableCell` (leave the Progress cell/`DEMO_PROGRESS` untouched — out of scope for this
  update).
- [X] T037 [US1] In the same file, after the existing `refType=11` fetch resolves for the current
  page, collect that page's Sales IDs (the same `code`/`id` field already used for the Sales ID
  column) and call `GetTemplatesBySalesIdsUseCase.execute(salesIds)` once per page load (depends on
  T034, T036).
  *(Implemented as a dedicated `fetchTemplatesForRows(items)` callback, called from
  `fetchSalesOrders` right after `setRows`/`setTotalCount` — fetch and grouping (T038) are combined
  into one function rather than two separate steps, to avoid an intermediate raw-array state and a
  stale-closure risk between them; the net behavior matches this task's intent.)*
- [X] T038 [US1] In the same file, derive a `{ [salesId]: string[] }` map from that state (group by
  `salesId`, collect `templateName` — already deduped server-side, no client-side dedup needed)
  (depends on T037).
  *(Done inside `fetchTemplatesForRows` directly — builds the map and calls
  `setTemplatesBySalesId(map)` — rather than a separate `useMemo` derivation, per the T037 note
  above.)*
- [X] T039 [US1] In the same file, render the Template `TableCell` from that map: one `Chip` per
  template name for the row's Sales ID (reusing the existing single-`Chip` visual, just repeated),
  or a clear `"-"` state when the map has no entry for that Sales ID (FR-007b) (depends on T038).
- [X] T040 [US1] In the same file, ensure the Phase 9 template fetch (T037) re-runs whenever the
  set of visible Sales IDs changes — i.e. on the existing page-change (US3, T015/T016) and
  search-filter (US2, T012/T013) handlers — so the Template column stays correct when paging or
  searching (depends on T037).
  *(Satisfied for free: `fetchTemplatesForRows` is called from inside the shared `fetchSalesOrders`
  function, which US2's debounced search handler and US3's page/page-size handlers already both
  call — no separate wiring needed.)*

**Verification**: `npm run build` succeeds with a clean `SalesOrderOverviewPage.*.js` chunk;
`npx eslint` on the changed/new files reports no errors.

**Checkpoint**: Template column shows real, deduped, possibly multi-valued data per row; Progress
column is unaffected; old demo label is fully removed.

---

## Phase 10: Polish & Validation (Template Column Update)

- [ ] T041 [P] Run the backend verification steps 4-7 in `specs/005-eutr-sales-orders/quickstart.md`
  (multi-template, duplicate-`PurchId`-same-template dedup, orphaned-`TemplateCode` skip, and
  no-attachment-rows empty case) (depends on T030).
  *(NOT run — same reason as T030: no live, seedable MySQL DB / running API in this environment.)*
- [ ] T042 [P] Run the frontend verification steps 3-5 in `specs/005-eutr-sales-orders/quickstart.md`
  (multi-template row renders both names, no-attachment row renders "-", no row shows the old fixed
  demo label) (depends on T039, T040).
  *(NOT run — requires a browser against a live backend with seeded `eutr_purchase_attachments`
  data, unavailable here. `npm run build` succeeds and `npx eslint` reports no issues on all
  changed/new files as a proxy check; a human needs to click through quickstart.md's steps 3-5
  before sign-off.)*
- [X] T043 [P] Review all new backend files from Phase 7
  (`EutrPurchaseAttachments.cs`/`SalesOrderTemplateDto.cs`/`IEutrPurchaseAttachmentsRepository.cs`/
  `EutrPurchaseAttachmentsRepository.cs`/`IEutrPurchaseAttachmentsService.cs`/
  `EutrPurchaseAttachmentsService.cs`/`EutrPurchaseAttachmentsController.cs`) to confirm any added
  comments are in Vietnamese, per Constitution Principle IV (depends on T021-T029).
  *(Verified: all comments in these 7 new files are Vietnamese, unaccented ASCII, matching the
  existing `EutrTemplates`/`EutrReferences` comment style in this codebase.)*
- [X] T044 Confirm `MapFilePage.jsx`/`ViewSalesOrderPage.jsx` still load without errors and that no
  file under `mock/` was touched by this update (same check as the original T019, re-run after
  Phase 9's edits) (depends on T039).
  *(Verified: `npm run build` output includes clean `MapFilePage.*.js`/`ViewSalesOrderPage.*.js`
  chunks with no errors; `git status` inside `compliance-client/` confirms this update touched only
  `SalesOrderOverviewPage.jsx` plus the new Phase 8 files — no file under `mock/` was changed by
  Update 1 specifically. Note: `git status` also shows a handful of unrelated pre-existing
  modified/untracked files, e.g. `mock/eutrSalesOrders.js`, `TemplateListPage.jsx`,
  `CloneTemplateDialog.jsx` — these predate this session's work and are out of scope for this
  update.)*
- [X] T045 Note as an ops follow-up (not a code task): the new `EutrPurchaseAttachments.Read`
  authorization policy (research.md Decision 8) must be seeded in the DB for any role that needs to
  see real Template data, the same way the `eutr-sales-orders` menu permission already needs to be
  seeded (per the original plan.md Constitution Check, Principle V).
  *(Done — this note is recorded in research.md Decision 8, plan.md's Constitution Check
  (Principle V), and quickstart.md's Prerequisites.)*

**Checkpoint**: All Update 1 quickstart.md checks pass — Template column is fully real-data-backed,
no regressions to Progress, search, pagination, or the other two Sales Order sub-pages.

---

## Update 1 Dependencies

### Phase Dependencies

- **Phase 7 (Backend)**: No dependency on Phases 1-6 (separate files/table). T021/T022 can start
  immediately and run in parallel; T023 depends on both; T024 depends on T023; T025 depends on T022
  and can run parallel to T023/T024; T026 depends on T023 and T025; T027/T028 depend on T025/T026
  and T023/T024 respectively and can run in parallel; T029 depends on T025-T028; T030 depends on
  T029.
- **Phase 8 (Frontend infra)**: No dependency on Phase 7 completion to *start* (frontend files can
  be scaffolded in parallel), but T030's manual verification implies Phase 7 should be functionally
  done before Phase 9 integration is meaningfully testable. T031/T032 can run in parallel; T033
  depends on both; T034 depends on T033; T035 depends on T033.
- **Phase 9 (US1 continued)**: Depends on Phase 8 (T034) and, functionally, Phase 7 (a working
  endpoint to call). T036 has no code dependency (pure removal) but is grouped first for clarity;
  T037 depends on T034 and T036; T038 depends on T037; T039 depends on T038; T040 depends on T037.
- **Phase 10 (Polish)**: Depends on Phases 7-9 all being complete.

### Parallel Opportunities

- T021 and T022 (different files, no shared dependency) can run in parallel.
- T027 and T028 (different files — Application vs Infrastructure `DependencyInjection.cs`) can run
  in parallel.
- T031 and T032 (different files) can run in parallel.
- T041, T042, T043 (Polish) are independent verification passes and can run in parallel.

### Implementation Strategy

1. Complete Phase 7 (backend read path) — verify via T030 before moving on.
2. Complete Phase 8 (frontend infra layers) — can be scaffolded in parallel with Phase 7.
3. Complete Phase 9 (wire into the grid) — this is the user-visible change.
4. Complete Phase 10 (polish/validation) — full quickstart.md re-pass for the Template column.

---

## Update 2026-07-16 — `MapFilePage.jsx` Real Data (User Story 4)

**Context**: Per spec Update 2, `MapFilePage.jsx` (currently 100% mock-driven) MUST switch to real
data for: the `if (!so)` existence check + Header card (same `refType=11` source as
`SalesOrderOverviewPage.jsx`), Step 1's PO list (`refType=16`, filtered by
`InterCompanyOriginalSalesId`) + "Save PO Mapping" (now persists to `eutr_purchase_attachments`),
and Step 2's template tree (`eutr_template_details` via `EutrTemplatesController`) + AVAILABLE FILES
(`eutr_references`/`eutr_documents` via `EutrDocumentsController`'s `list-po-references`). Step 2's
Upload/Save stay display-only (no backend call) — spec FR-029/FR-030, out of scope to implement.

Per research.md Decisions 9-14, three of the four data sources need **zero backend change** —
`refType=16`, `list-po-references`, and `EutrTemplatesController`'s `get-all`/`GetById` are already
fully wired and already return every field needed. The only new backend work is two actions
(one read, one write) added to the already-existing `EutrPurchaseAttachmentsController`.

**Prerequisites for this update**: [research.md Decisions 9-15](./research.md),
[data-model.md "Update 2"](./data-model.md),
[contracts/eutr-purchase-attachments-map-file.md](./contracts/eutr-purchase-attachments-map-file.md),
[contracts/map-file-reused-endpoints.md](./contracts/map-file-reused-endpoints.md),
[quickstart.md "Update 2"](./quickstart.md).

---

## Phase 11: Backend — `EutrPurchaseAttachments` New Read + Write Actions

**Purpose**: Add the one genuinely new backend capability — `GetBySalesIdAsync` (raw per-`PurchId`
rows, backing Step 1's pre-check and Step 2's template list) and `SavePoMappingAsync`
(transactional delete-then-reinsert for "Save PO Mapping") — as new methods on the controller/
service/repository Update 1 already created. No new controller, no migration.

- [X] T046 [P] Create DTO `PurchaseAttachmentDto` in
  `compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/PurchaseAttachmentDto.cs` — flat
  class with `SalesId`, `PurchId`, `TemplateCode` (all `string`), per data-model.md/contracts/
  eutr-purchase-attachments-map-file.md.
- [X] T047 [P] Create DTO `PurchaseAttachmentItemDto` in
  `compliance-sys-api/src/ComplianceSys.Application/Dtos/Request/PurchaseAttachmentItemDto.cs` —
  flat class with `PurchId`, `TemplateCode` (both `string`).
- [X] T048 Create DTO `SavePoMappingRequestDto` in
  `compliance-sys-api/src/ComplianceSys.Application/Dtos/Request/SavePoMappingRequestDto.cs` —
  `SalesId` (string) + `Items` (`List<PurchaseAttachmentItemDto>`, default `[]`) (depends on T047).
- [X] T049 Add `Task<List<PurchaseAttachmentDto>> GetBySalesIdAsync(string salesId,
  CancellationToken ct = default);` to `IEutrPurchaseAttachmentsRepository` in
  `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Repositories/
  IEutrPurchaseAttachmentsRepository.cs`, alongside the existing `GetTemplatesBySalesIdsAsync`
  (depends on T046).
- [X] T050 Add `Task DeleteBySalesIdAsync(string salesId, CancellationToken ct = default);` to the
  same `IEutrPurchaseAttachmentsRepository.cs` interface (same file as T049, apply after it).
- [X] T051 Implement `GetBySalesIdAsync` in `EutrPurchaseAttachmentsRepository.cs`
  (`compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/
  EutrPurchaseAttachmentsRepository.cs`) — `SELECT PurchId, TemplateCode FROM
  eutr_purchase_attachments WHERE SalesId = @SalesId;` (no join needed — `TemplateName` isn't
  required for this caller), returning `[]` for a blank `salesId` (depends on T049).
- [X] T052 Implement `DeleteBySalesIdAsync` in the same `EutrPurchaseAttachmentsRepository.cs` —
  `DELETE FROM eutr_purchase_attachments WHERE SalesId = @SalesId;`, cloned from
  `EutrReferencesRepository.DeleteByDocumentIdAsync`'s raw-SQL shape (same file as T051, apply after
  it; depends on T050).
- [X] T053 Add `Task<List<PurchaseAttachmentDto>> GetBySalesIdAsync(string salesId, CancellationToken
  ct = default);` and `Task SavePoMappingAsync(string salesId, List<PurchaseAttachmentItemDto>
  items, string userEmail, CancellationToken ct = default);` to `IEutrPurchaseAttachmentsService` in
  `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Services/
  IEutrPurchaseAttachmentsService.cs` (depends on T048, T049).
- [X] T054 Implement both new methods in `EutrPurchaseAttachmentsService.cs`
  (`compliance-sys-api/src/ComplianceSys.Application/Services/EutrPurchaseAttachmentsService.cs`):
  - Inject `IUnitOfWork` and `IRepository<EutrPurchaseAttachments, int>` (generic — resolves via the
    same open-generic DI registration already backing `IRepository<EutrReferences, long>` in
    `EutrUploadService`, no new DI registration needed) as two new constructor parameters, alongside
    the existing `IEutrPurchaseAttachmentsRepository`.
  - `GetBySalesIdAsync`: pass-through to `_repository.GetBySalesIdAsync(salesId, ct)`.
  - `SavePoMappingAsync`: validate every `items[i].TemplateCode` is non-empty first — throw
    `InvalidOperationException` (or equivalent) if any is blank (spec FR-022) before opening a
    transaction; else `_unitOfWork.BeginTransactionAsync(IsolationLevel.ReadCommitted)`, call
    `_repository.DeleteBySalesIdAsync(salesId, ct)`, loop `items` calling
    `_genericRepository.AddAsync(new EutrPurchaseAttachments { SalesId = salesId, PurchId =
    i.PurchId, TemplateCode = i.TemplateCode, CreatedBy = userEmail, CreatedDate = DateTime.UtcNow,
    UpdatedBy = userEmail, UpdatedDate = DateTime.UtcNow }, ct)`, then `CommitAsync()`;
    `RollbackAsync()` in a `catch` that rethrows — clone of `EutrDocumentsService.DeleteAsync`'s
    Update 9 transaction shape + `EutrUploadService`'s Update 7 per-row `AddAsync` loop (research.md
    Decision 11) (depends on T051, T052, T053).
- [X] T055 Add two new actions to `EutrPurchaseAttachmentsController.cs`
  (`compliance-sys-api/src/ComplianceSys.Api/Controllers/EutrPurchaseAttachmentsController.cs`):
  - `[Authorize(Policy = "EutrPurchaseAttachments.Read")] [HttpGet("by-sales-id/{salesId}")]` calling
    `GetBySalesIdAsync`, returning `ApiResponse<List<PurchaseAttachmentDto>>.Ok(...)`.
  - `[Authorize(Policy = "EutrPurchaseAttachments.Update")] [HttpPost("save-po-mapping")]` accepting
    `[FromBody] SavePoMappingRequestDto request`, resolving the caller's email the same way other
    `Eutr*Controller` write actions do (`HttpContext.Items["UserEmail"]`), calling
    `SavePoMappingAsync`, returning `400 Bad Request`/`ApiResponse<string>.Fail(...)` if the service
    throws the FR-022 validation exception, else `ApiResponse<string>.Ok("", "PO mapping saved
    successfully")` — per contracts/eutr-purchase-attachments-map-file.md (depends on T054).
- [ ] T056 Manually verify per quickstart.md Update 2 backend steps 1-7: `refType=16` filter
  behavior (no code change expected), `GET by-sales-id/{salesId}` empty/populated cases, `POST
  save-po-mapping` save + replace-on-resave semantics, and the empty-`TemplateCode` rejection
  (depends on T055).
  *(NOT run — requires a live `compliance-sys-api` process with a real D365 connection and a
  seedable MySQL DB, unavailable in this environment. As a proxy check: `dotnet build` on
  `ComplianceSys.Application` and `ComplianceSys.Infrastructure` succeeds with 0 errors (the
  `ComplianceSys.Api` exe target hit a pre-existing `MSB3027`/`MSB3021` file-lock error from an
  already-running `ComplianceSys.Api.exe` instance holding its own output DLLs open — not a code
  defect, same category of issue noted in T030). Someone with D365/DB access must run the actual
  HTTP round-trips (backend steps 1-7 in quickstart.md) before sign-off.)*

**Checkpoint**: `eutr_purchase_attachments` now supports read-by-`SalesId` and a transactional
save/replace — ready for the frontend to consume for Step 1's pre-check and Save PO Mapping.

---

## Phase 12: Frontend — Extend Purchase Attachments Layer + 2 New Use Cases

**Purpose**: Add the frontend methods/use cases for the two new backend actions, on top of the
already-existing `eutr-purchase-attachments` frontend layering from Update 1 — no new
domain/infrastructure files, just new methods on the existing ones plus two new use case files.

- [X] T057 [P] Add `getBySalesId(_salesId)` and `savePoMapping(_salesId, _items)` method stubs to
  `compliance-client/src/domain/interfaces/IEutrPurchaseAttachmentsRepository.js`, alongside the
  existing `getTemplatesBySalesIds`.
- [X] T058 [P] Add `getBySalesId: (salesId) => axiosInstance.get(\`/eutr-purchase-attachments/by-sales-id/${salesId}\`)`
  and `savePoMapping: (payload) => axiosInstance.post('/eutr-purchase-attachments/save-po-mapping',
  payload)` to `compliance-client/src/infrastructure/api/eutrPurchaseAttachmentsApi.js`.
- [X] T059 Implement both new methods in
  `compliance-client/src/infrastructure/repositories/RestEutrPurchaseAttachmentsRepository.js` —
  `getBySalesId(salesId)` calls `eutrPurchaseAttachmentsApi.getBySalesId(salesId)` and returns
  `res.data`; `savePoMapping(salesId, items)` calls `eutrPurchaseAttachmentsApi.savePoMapping({
  salesId, items })` and returns `res.data` (depends on T057, T058).
- [X] T060 [P] Create `compliance-client/src/application/usecases/eutr-purchase-attachments/
  GetPurchaseAttachmentsBySalesIdUseCase.js` — `execute(salesId)` delegates to
  `repository.getBySalesId(salesId)`, mirroring `GetTemplatesBySalesIdsUseCase.js`'s shape (depends
  on T059).
- [X] T061 [P] Create `compliance-client/src/application/usecases/eutr-purchase-attachments/
  SavePoMappingUseCase.js` — `execute(salesId, items)` delegates to
  `repository.savePoMapping(salesId, items)` (depends on T059).

**Verification**: `npm run build` (Vite) succeeds with all new imports resolved.

**Checkpoint**: `GetPurchaseAttachmentsBySalesIdUseCase.execute(salesId)` and
`SavePoMappingUseCase.execute(salesId, items)` are ready to wire into `MapFilePage.jsx`.

---

## Phase 13: User Story 4 - Chọn Purchase Order và xem hồ sơ tài liệu cho Sales Order (Map File) (Priority: P2)

**Goal**: Replace every mock data source in `MapFilePage.jsx` with the real sources from Phase 11/12
(and the already-existing `refType=11`/`refType=16`/`EutrTemplatesController`/
`GetEutrDocumentsPoReferencesUseCase` chains), while Step 2's Upload/Save stay display-only.

**Independent Test**: Open Map File for a Sales Order that already has a saved PO mapping; confirm
the header matches Overview data, Step 1 shows the real PO(s) with the saved one(s) pre-checked,
Step 2 shows the real template tree for the saved `TemplateCode`, and AVAILABLE FILES shows the real
documents for the saved PO(s) mapped to the correct step(s); change the Step 1 selection, Save, and
confirm the change persists across a reload.

### Implementation for User Story 4

- [X] T062 [US4] In
  `compliance-client/src/presentation/pages/eutr-sales-orders/MapFilePage.jsx`, replace `const so =
  MOCK_SALES_ORDERS.find(s => s.salesId === salesId)` with a fetch through
  `GetReferenceDataUseCase.execute(1, 1, 'Code', 'asc', 11, [{ column: 'Code', operator: 'eq',
  value: salesId }])` (same use case `SalesOrderOverviewPage.jsx` already uses); store the single
  result (or `null`) in component state; keep the existing `if (!so) return <Card>...</Card>` guard
  but drive it off this fetched state instead of the mock array (research.md Decision 9).
- [X] T063 [US4] In the same file, update the Header card (`Sales ID`/`Customer`/`Customer name`
  `Typography`s) to read `so.code`/`so.custAccount`/`so.name` (the `refType=11` field names, matching
  `SalesOrderOverviewPage.jsx`'s existing mapping) instead of `so.salesId`/`so.customerId`/
  `so.customerName` (depends on T062).
- [X] T064 [US4] In the same file, replace `const poList = MOCK_SO_POS[salesId] || []` with a fetch
  through `GetReferenceDataUseCase.execute(1, <pageSize>, 'Code', 'asc', 16, [{ column:
  'InterCompanyOriginalSalesId', operator: 'eq', value: salesId }])`, storing the result in component
  state (research.md Decision 10).
- [X] T065 [US4] In the same file, update the Step 1 PO `Table`'s columns from Vendor/Vendor
  Name/Rate/Material to **PO** (`po.code`), **Name** (`po.name`), **Order account**
  (`po.orderAccount`), **Qty** (`po.qty`) — the real fields available on a `refType=16` row (depends
  on T064; per data-model.md's Purchase Order entity table).
- [X] T066 [US4] In the same file, on mount (alongside T062/T064's fetches), call
  `GetPurchaseAttachmentsBySalesIdUseCase.execute(salesId)`; replace `useState(() => new
  Set(MOCK_SO_PO_MAPPINGS[salesId] || []))` for `selectedPOs` with a `Set` built from this result's
  `purchId` values, and set `poSaved` to `true` when the result is non-empty (else `false`) — replaces
  the `MOCK_SO_PO_MAPPINGS`-based initial state (depends on T060; research.md Decision 12).
- [X] T067 [US4] In the same file, replace `handleSavePOMapping`'s body (`setPoSaved(true)` only)
  with: build `items` = the currently-selected `purchId`s each paired with that PO's own
  `eutrTemplate` value from T064's fetched `poList`; call
  `SavePoMappingUseCase.execute(salesId, items)`; on success call `setPoSaved(true)` (existing
  behavior) and re-fetch T066's data (or update local state) so the pre-checked set matches what was
  just saved; on failure (e.g. a PO missing `eutrTemplate`), show a clear error instead of silently
  calling `setPoSaved(true)` (depends on T061, T064, T066; spec FR-020/FR-021/FR-022).
- [X] T068 [US4] In the same file, disable (or omit from selection) any PO row in Step 1 whose
  `eutrTemplate` is empty/null, with a visible tooltip/hint explaining why it can't be selected (spec
  Edge Cases — a PO without a template can't be saved) (depends on T065).
- [X] T069 [US4] In the same file, replace the `tree` `useMemo` (currently built from
  `EUTR_TEMPLATE_DETAILS_MAP[so.templateId]`) with logic that: takes the distinct `templateCode`
  values from T066's result; for each, calls `GetPagingEutrTemplatesUseCase.execute(1, 1, 'Code',
  'asc', [{ column: 'Code', operator: 'eq', value: templateCode }])` to resolve the template's `id`,
  then `GetEutrTemplatesUseCase.execute(id)` to get `Details`; feeds each template's `Details`
  through the existing `flatToTree()` util; stores the result as an array of `{ templateCode,
  templateName, tree }` (research.md Decision 13).
- [X] T070 [US4] In the same file, update the Step 2 tree rendering to loop over T069's array,
  rendering one labeled tree section per distinct template (mirrors how the Overview grid already
  shows multiple Template chips for one Sales ID) instead of the single `tree.map(root => ...)` over
  one mock template (depends on T069; spec FR-024).
- [X] T071 [US4] In the same file, render a clear "chưa có cây template" empty state in the Step 2
  panel when T066's result is empty (no PO mapping saved yet for this Sales Order), instead of an
  empty/broken tree render (depends on T066, T069; spec FR-025).
- [X] T072 [US4] In the same file, replace `const allFiles = useMemo(() => [...MOCK_AVAILABLE_FILES,
  ...newlyUploadedFiles], ...)`'s mock half with a fetch through
  `GetEutrDocumentsPoReferencesUseCase.execute([...selectedPOs])` (the same use case
  `EutrDocumentsAdd.jsx` already uses for its List PO panel), flattening the returned `documents[]`
  across all selected/saved POs into the AVAILABLE FILES list — keep `newlyUploadedFiles` (local-only
  state, unaffected) appended after it (research.md Decision 14).
- [X] T073 [US4] In the same file, update `TreeNode`'s "already mapped" detection (currently keyed by
  `fileMappings[node.id]`, sourced from `MOCK_FILE_MAPPINGS`) to instead match each AVAILABLE FILES
  document's `stepNames` array against `node.stepName` (string match) to decide which node(s) show it
  as mapped (depends on T070, T072; spec FR-026/FR-027).
- [X] T074 [US4] In the same file, render a clear empty state in AVAILABLE FILES for a selected PO
  with no `eutr_references` rows (T072's result has `documents: []` for that `poCode`), instead of
  falling back to mock files (depends on T072; spec FR-028).
- [X] T075 [US4] In the same file, remove the now-unused imports (`MOCK_SALES_ORDERS`, `MOCK_SO_POS`,
  `MOCK_SO_PO_MAPPINGS`, `MOCK_AVAILABLE_FILES`, `MOCK_FILE_MAPPINGS`, `EUTR_TEMPLATE_DETAILS_MAP`,
  `EUTR_TEMPLATES`) from `./mock/eutrSalesOrders`, `./mock/eutrTemplateDetails`, `./mock/eutrTemplates`
  once T062-T074 no longer reference them (depends on T062-T074).
- [X] T076 [US4] Confirm the Step 2 **Upload** button (`UploadDialog`/`handleUpload`) and the footer
  **Save** button still only touch local component state (`newlyUploadedFiles`, `fileMappings`) —
  verify no new API call was introduced for either during T062-T075 (spec FR-029/FR-030; this is a
  verification/guardrail task, not expected to require a code change).

**Checkpoint**: User Story 4 is fully functional and independently testable — Map File's header,
Step 1, and Step 2 (tree + AVAILABLE FILES) all reflect real data; Save PO Mapping persists; Upload/
Save remain no-op.

---

## Phase 14: Polish & Cross-Cutting Concerns (Update 2)

**Purpose**: Final validation across the `MapFilePage.jsx` update; no new functionality.

- [ ] T077 [P] Run the backend verification steps in `specs/005-eutr-sales-orders/quickstart.md`
  "Update 2" section (steps 1-7: `refType=16` filter check, `GetBySalesIdAsync` empty/populated,
  `SavePoMappingAsync` save/replace/reject-empty-template, Update 1 no-regression check) (depends on
  T056).
  *(NOT run — same reason as T056: no live D365-connected, seedable-DB `compliance-sys-api`
  instance in this environment.)*
- [ ] T078 [P] Run the frontend manual verification steps in `specs/005-eutr-sales-orders/
  quickstart.md` "Update 2" section (steps 1-9: header, Step 1 columns + pre-check, Save PO Mapping
  persistence, Step 2 tree, AVAILABLE FILES + step mapping, empty states, Upload/Save no-op,
  `ViewSalesOrderPage.jsx` unaffected) (depends on T075, T076).
  *(NOT run — requires a browser against a live backend with real D365 POs and seeded
  `eutr_purchase_attachments`/`eutr_references` data, unavailable here. `npm run build` succeeds
  (clean `MapFilePage.*.js` chunk, all new use-case imports resolved) and `npx eslint` reports no
  issues on every changed/new file, as proxy checks. A human with that environment needs to click
  through quickstart.md's Update 2 steps 1-9 before sign-off.)*
- [X] T079 [P] Review all new/changed backend code from Phase 11
  (`PurchaseAttachmentDto.cs`/`PurchaseAttachmentItemDto.cs`/`SavePoMappingRequestDto.cs`/
  `IEutrPurchaseAttachmentsRepository.cs`/`EutrPurchaseAttachmentsRepository.cs`/
  `IEutrPurchaseAttachmentsService.cs`/`EutrPurchaseAttachmentsService.cs`/
  `EutrPurchaseAttachmentsController.cs`) to confirm any added comments are in Vietnamese, per
  Constitution Principle IV (depends on T046-T055).
  *(Verified: all added/changed comments across these 8 files are Vietnamese, unaccented ASCII,
  matching the existing `EutrPurchaseAttachments*`/`EutrReferences*` comment style from Update 1.)*
- [X] T080 Confirm `ViewSalesOrderPage.jsx` still loads without errors and that no file under
  `mock/` was deleted (only stopped being *imported* by `MapFilePage.jsx`, per plan.md's Project
  Structure) (depends on T075).
  *(Verified: `npm run build` output includes a clean `ViewSalesOrderPage.*.js` chunk with no
  errors; `git status` inside `compliance-client/` confirms this update touched only
  `MapFilePage.jsx`, `utils/treeUtils.js`, and the `eutr-purchase-attachments` frontend layer/use
  cases — `ViewSalesOrderPage.jsx` and every file under `mock/` are absent from that diff. Note:
  `git status` also shows several unrelated pre-existing modified/untracked files — e.g.
  `certs/*.pem`, `TemplateListPage.jsx`, `CloneTemplateDialog.jsx`,
  `mock/eutrSalesOrders.js` — these predate this session's work and are out of scope, same as noted
  in T044.)*
- [X] T081 Note as an ops follow-up (not a code task): the new `EutrPurchaseAttachments.Update`
  authorization policy (research.md Decision 15) must be seeded in the DB for any role that needs to
  use Save PO Mapping, alongside the existing `EutrPurchaseAttachments.Read` policy (Update 1) and
  the `eutr-sales-orders` menu permission (original plan.md Constitution Check, Principle V).
  *(Done — this note is recorded in research.md Decision 15, plan.md's Constitution Check
  (Principle V), and quickstart.md's Update 2 section.)*

**Checkpoint**: All Update 2 quickstart.md checks pass — `MapFilePage.jsx` is fully real-data-backed
for header/Step 1/Step 2 read+save paths, with no regressions to `SalesOrderOverviewPage.jsx`,
`ViewSalesOrderPage.jsx`, or the Update 1 Template column.

---

## Update 2 Dependencies

### Phase Dependencies

- **Phase 11 (Backend)**: No dependency on Phases 1-10 (new methods on existing files, unrelated to
  the D365 reference/Template-column paths). T046/T047 can start immediately in parallel; T048
  depends on T047; T049/T050 depend on T046 (same file, sequential); T051/T052 depend on T049/T050
  (same file, sequential); T053 depends on T048, T049; T054 depends on T051-T053; T055 depends on
  T054; T056 depends on T055.
- **Phase 12 (Frontend infra)**: No dependency on Phase 11 completion to *start* scaffolding, but
  T059 depends on T057/T058; T060/T061 depend on T059. Functionally needs Phase 11 done before Phase
  13 integration is meaningfully testable end-to-end.
- **Phase 13 (US4)**: Depends on Phase 12 (T060/T061) and, functionally, Phase 11 (working endpoints
  to call). Within the phase: T062 has no dependency; T063 depends on T062; T064 has no dependency on
  T062/T063 (independent fetch) but is sequenced after for file-diff clarity; T065 depends on T064;
  T066 depends on T060; T067 depends on T061, T064, T066; T068 depends on T065; T069 depends on
  T066; T070 depends on T069; T071 depends on T066, T069; T072 depends on T066 (needs
  `selectedPOs`); T073 depends on T070, T072; T074 depends on T072; T075 depends on all of
  T062-T074; T076 depends on T075 (final guardrail check).
- **Phase 14 (Polish)**: Depends on Phases 11-13 all being complete.

### Parallel Opportunities

- T046 and T047 (different files) can run in parallel.
- T057 and T058 (different files) can run in parallel.
- T060 and T061 (different files, both depend only on T059) can run in parallel.
- T062 and T064 (independent fetches, though conventionally sequenced in the same file) could be
  fetched concurrently in the implementation (e.g. `Promise.all`) even though listed sequentially
  here for review clarity.
- T077, T078, T079 (Polish) are independent verification passes and can run in parallel.

### Implementation Strategy

1. Complete Phase 11 (backend read+write actions) — verify via T056 before moving on.
2. Complete Phase 12 (frontend infra extensions) — can be scaffolded in parallel with Phase 11.
3. Complete Phase 13 (wire `MapFilePage.jsx`) — this is the user-visible change; T062-T068 (header +
   Step 1) can be demoed before T069-T074 (Step 2) are finished, since Step 1 is independently
   observable even with Step 2 still on old data.
4. Complete Phase 14 (polish/validation) — full quickstart.md "Update 2" re-pass.

---

## Update 2026-07-20 — Select-more-POs Confirmation + Back Button (User Story 4 continued)

**Context**: Per spec Update 3 (FR-031/FR-032/FR-033), Step 1 must keep letting the user tick POs
that don't yet have a saved `eutr_purchase_attachments` row (as long as D365 supplies a template for
them), Save PO Mapping must persist those newly-ticked POs alongside the already-saved ones, and the
Back button must navigate to EUTR Sales Orders. Per research.md Decision 16, the existing Update 2
implementation (T067's `handleSavePOMapping`, T068's `disabled = !po.eutrTemplate` checkbox
condition) **already satisfies FR-031/FR-032 exactly as written** — there is nothing to change,
only to verify and record. Per research.md Decision 17, the Back button (rendered with no `onClick`
since it was first scaffolded) is the one genuine gap, fixed by reusing the exact `navigate(...)`
call the page's own breadcrumb link already uses.

**Prerequisites for this update**: [research.md Decisions 16-17](./research.md),
[quickstart.md "Update 3"](./quickstart.md).

---

## Phase 15: User Story 4 (continued) — Confirm Select-More-POs, Fix Back Button

**Goal**: Confirm FR-031/FR-032 already hold (no code change) and close the one real gap — the
inert Back button — per spec Update 3.

**Independent Test**: Open Map File for a Sales Order with one PO already saved and a second,
never-saved PO that has a real D365 template; tick the second PO in addition to the first and Save;
reload and confirm both are pre-checked. Click Back and confirm navigation lands on
`/eutr/sales-orders`.

### Implementation for User Story 4 (Update 3)

- [X] T082 [US4] In
  `compliance-client/src/presentation/pages/eutr-sales-orders/MapFilePage.jsx`, inspect T068's
  checkbox `disabled` condition and confirm it evaluates to `false` (selectable) for any PO row
  whose `eutrTemplate` is non-empty, regardless of whether that PO's `purchId` is already in the
  `selectedPOs` `Set` built by T066 — i.e. confirm there is no additional condition anywhere gating
  selection on "already has a saved `eutr_purchase_attachments` row". No code change expected; if a
  gate like that is found, remove it (spec FR-031, research.md Decision 16).
  *(Confirmed, no change needed: `const disabled = !po.eutrTemplate;` (line ~1248) is the only
  gating condition on the checkbox/row; `handleTogglePO` (line ~922) unconditionally toggles
  `selectedPOs` for any `purchId` passed to it — nothing checks prior `eutr_purchase_attachments`
  membership before allowing a toggle.)*
- [X] T083 [US4] In the same file, inspect T067's `handleSavePOMapping` and confirm the `items` array
  it builds/sends to `SavePoMappingUseCase.execute` is derived directly from the current
  `selectedPOs` `Set` at click time (not filtered to only previously-saved `purchId`s), so a newly
  ticked, never-before-saved PO is included in the payload the same way an already-saved one is. No
  code change expected; if newly-ticked POs are being dropped before the call, fix the filter (spec
  FR-032, research.md Decision 16).
  *(Confirmed, no change needed: `handleSavePOMapping` (line ~933) builds `items` from
  `poList.filter(po => selectedPOs.has(po.purchId))` — the live `selectedPOs` state at click time,
  with no distinction between previously-saved and newly-ticked `purchId`s.)*
- [X] T084 [US4] In the same file, add `onClick={() => navigate('/eutr/sales-orders')}` to the Back
  `<Button>` (currently renders with no `onClick` — verified inert), reusing the same `navigate`
  (from `useNavigate()`) already imported and already used by this page's breadcrumb link (spec
  FR-033, research.md Decision 17).
  *(Done: added `onClick={() => navigate('/eutr/sales-orders')}` to the Back `<Button>` at line
  ~1188, matching the breadcrumb `Link`'s existing `onClick` one section above it. Verified via
  `npx eslint` (no issues) and `npm run build` (clean `MapFilePage.*.js` chunk).)*

**Checkpoint**: Step 1 keeps allowing additional, not-yet-saved-but-templated POs to be ticked and
saved alongside existing ones (confirmed, unchanged); Back now reliably returns to EUTR Sales Orders.

---

## Phase 16: Polish & Cross-Cutting Concerns (Update 3)

**Purpose**: Final validation for the Update 3 changes; no new functionality.

- [ ] T085 [P] Run the frontend manual verification steps in `specs/005-eutr-sales-orders/
  quickstart.md` "Update 3" section (steps 1-6: not-yet-saved-but-templated PO stays selectable,
  Save PO Mapping persists the additional selection alongside the prior one, template-less PO stays
  disabled, Back navigates to `/eutr/sales-orders` both with and without unsaved changes) (depends on
  T082-T084).
  *(NOT run — requires a browser against a live backend with real D365 POs/`eutr_purchase_attachments`
  data, unavailable in this environment. `npm run build` succeeds (clean `MapFilePage.*.js` chunk)
  and `npx eslint` reports no issues on the changed file, as proxy checks. A human with that
  environment needs to click through quickstart.md's Update 3 steps 1-6 before sign-off.)*
- [X] T086 Confirm `git diff`/`git status` for this update touches only
  `compliance-client/src/presentation/pages/eutr-sales-orders/MapFilePage.jsx` (the `onClick` from
  T084, plus no other line changed if T082/T083 found no gap) — no backend file, no other frontend
  file (depends on T082-T084).
  *(Verified: `git diff` for this update shows exactly one changed file,
  `MapFilePage.jsx` (the T084 `onClick` addition) — no backend file, no other frontend file. The
  `certs/*.pem` changes visible in `git status` predate this session's work, same as noted in
  T044/T080.)*
- [X] T087 If T082 or T083 uncovers an actual gap requiring a code fix, review that fix's added/
  changed comments for Vietnamese wording, per Constitution Principle IV (depends on T082, T083); if
  no fix was needed (expected outcome per research.md Decision 16), mark this task as not-applicable.
  *(Not applicable — T082/T083 confirmed no gap existed, per research.md Decision 16; no fix was
  needed and no new comment was added for either.)*

**Checkpoint**: Update 3's quickstart.md checks pass — Step 1 selection behavior is confirmed
correct, Back button reliably returns to EUTR Sales Orders, no unrelated files were touched.

---

## Update 3 Dependencies

### Phase Dependencies

- **Phase 15**: Depends on Phase 13 (T066, T067, T068 must exist to inspect/confirm). T082 and T083
  are independent read-only inspections and can run in parallel; T084 is independent of both (touches
  a different part of the same file — the Back button, not the checkbox/save logic) and can also run
  in parallel with T082/T083.
- **Phase 16 (Polish)**: Depends on Phase 15 (T082-T084) being complete.

### Parallel Opportunities

- T082, T083, T084 can all run in parallel — each inspects/edits a distinct, non-overlapping piece of
  `MapFilePage.jsx` (checkbox condition, save handler, Back button) with no shared state between
  them.

### Implementation Strategy

1. Complete Phase 15 — expect T082/T083 to confirm "already correct, no change" (research.md
   Decision 16) and T084 to be the only actual edit.
2. Complete Phase 16 (polish/validation) — quickstart.md "Update 3" re-pass.

---

## Update 2026-07-20 — `ViewSalesOrderPage.jsx` Real Data, Read-Only (User Story 5)

**Context**: Per spec Update 4 (FR-034..FR-046), `ViewSalesOrderPage.jsx` (currently 100%
mock-driven, the last remaining consumer of `eutr-sales-orders/mock/*`) MUST switch to the same real
data `MapFilePage.jsx` already reads (existence/header via `refType=11`, saved-PO list via
`GetBySalesIdAsync` + `refType=16` for display fields, Template Checklist tree via `EutrTemplates`
get-all/GetById, per-step mapped/missing status via `list-po-references`), rendered strictly
**read-only** — no PO tick/Save, no file map/unmap/upload. Per research.md Update 4 Decisions 18-22,
**zero backend change** is needed: every read this screen requires already exists and is already
frontend-wired from Update 1/2. This is a frontend-only rewrite plus deletion of the now-fully-unused
mock fixtures (`eutrSalesOrders.js`, `eutrTemplateDetails.js`, `eutrTemplates.js` — `eutrSteps.js`
stays, still imported by the shared `utils/treeUtils.js`).

**Prerequisites for this update**: [research.md Update 4 Decisions 18-22](./research.md),
[data-model.md "Update 4"](./data-model.md),
[contracts/view-sales-order-reused-endpoints.md](./contracts/view-sales-order-reused-endpoints.md),
[quickstart.md "Update 4"](./quickstart.md).

---

## Phase 17: User Story 5 - Xem tổng quan hồ sơ EUTR của Sales Order, chỉ đọc (View Sales Order) (Priority: P2)

**Goal**: Replace every mock data source in `ViewSalesOrderPage.jsx` with the same real sources
`MapFilePage.jsx` already uses, rendered read-only (no Save/tick/map/unmap/upload anywhere on this
screen).

**Independent Test**: Open View for a Sales Order that already has a saved PO mapping with at least
one Required step mapped and one still missing; confirm the header matches Overview/Map File data,
"Purchase Orders đã chọn" lists exactly the saved PO(s) with real display fields, the Template
Checklist tree matches Map File's Step 2 tree for the same Sales Order (including correct
mapped/missing status per step), and the Validation Summary reflects that same data; confirm no
control on the page can tick/map/unmap/upload/save anything; confirm Edit/Map File navigates to Map
File and Download is a no-op.

### Implementation for User Story 5

- [X] T088 [US5] In
  `compliance-client/src/presentation/pages/eutr-sales-orders/ViewSalesOrderPage.jsx`, replace
  `const so = MOCK_SALES_ORDERS.find(s => s.salesId === salesId)` with a fetch through
  `GetReferenceDataUseCase.execute(1, 1, 'Code', 'asc', 11, [{ column: 'Code', operator: 'eq', value:
  salesId }])` (same call `MapFilePage.jsx`'s T062 already makes); store the single result (or
  `null`) plus a loading flag in component state; keep the existing `if (!so) return <Card>...`
  guard, gated on this fetched state instead of the mock array (research.md Decision 18, mirrors
  Decision 9).
  *(Done: `so`/`soLoading` state + `useEffect` calling `getReferenceDataUseCase.execute(1, 1, 'Code',
  'asc', EUTR_SALES_ORDER_REF_TYPE, [...])`; a full-page `CircularProgress` renders while `soLoading`,
  then the existing `if (!so)` error card, both gated on real state.)*
- [X] T089 [US5] In the same file, update the header `Typography`s (`Sales ID`/`Customer`/`Customer
  name`) to read `so.code`/`so.custAccount`/`so.name` (the `refType=11` field names, matching
  `SalesOrderOverviewPage.jsx`/`MapFilePage.jsx`'s existing mapping) instead of
  `so.salesId`/`so.customerId`/`so.customerName` (depends on T088).
  *(Done: header now renders `so.code`, `so.custAccount — so.name`; Delivery Date renders only when
  `so.deliveryDate` is present; the old `so.templateVersionId` field — mock-only, not part of
  `refType=11` — was dropped from the header.)*
- [X] T090 [US5] In the same file, replace `const selectedPOIds = MOCK_SO_PO_MAPPINGS[salesId] || []`
  and `const poList = (MOCK_SO_POS[salesId] || []).filter(po =>
  selectedPOIds.includes(po.purchId))` with: (a) `GetPurchaseAttachmentsBySalesIdUseCase.execute(
  salesId)` for the saved `PurchId` set, and (b) `GetReferenceDataUseCase.execute(1, <pageSize>,
  'Code', 'asc', 16, [{ column: 'InterCompanyOriginalSalesId', operator: 'eq', value: salesId }])`
  for display fields; derive the displayed `poList` by filtering (b)'s items to only those whose
  `code` is in (a)'s `purchId` set (research.md Decision 19).
  *(Done, with one refinement over the task's literal wording: `poList` is derived by **mapping over
  (a)'s saved `purchId`s** and looking up each one's display fields in (b) (`Map` keyed by `purchId`),
  rather than filtering (b) down to (a)'s set. This is the superset-safe direction — it satisfies the
  spec Edge Case where a saved `PurchId` no longer has a matching D365 row: the row still renders with
  `purchId` populated and `name`/`orderAccount`/`qty` as `null` ("-" in the UI), instead of silently
  disappearing as a plain filter would produce.)*
- [X] T091 [US5] In the same file, update the "Purchase Orders đã chọn" `Table`'s columns from
  Vendor/Vendor Name/Rate/Material to **PO** (`po.code`), **Name** (`po.name`), **Order account**
  (`po.orderAccount`), **Qty** (`po.qty`) — the same real field set `MapFilePage.jsx`'s Step 1 table
  already uses (depends on T090; per data-model.md Update 4).
  *(Done: columns are PO/Name/Order account/Qty, each rendering `?? '-'` for a missing value per
  T090's join semantics.)*
- [X] T092 [US5] In the same file, replace the `tree`/`allDetails` `useMemo`s (currently built from
  `EUTR_TEMPLATE_DETAILS_MAP[so.templateId]`) with logic that: takes the distinct `templateCode`
  values from T090(a)'s result; for each, calls `GetPagingEutrTemplatesUseCase.execute(1, 1, 'Code',
  'asc', [{ column: 'Code', operator: 'eq', value: templateCode }])` to resolve the template's `id`,
  then `GetEutrTemplatesUseCase.execute(id)` to get `Details`; feeds each template's `Details` through
  the existing `flatToTree()` util; stores the result as an array of `{ templateCode, templateName,
  tree, flatDetails }`, and derives combined `allTrees`/`allDetails` from it (mirrors
  `MapFilePage.jsx`'s T069, research.md Decision 18).
  *(Done: `templatesData` state built in a `useEffect` keyed on `purchaseAttachments`, using the same
  `normalizeTemplateDetail`/`flatToTree` pipeline as `MapFilePage.jsx`; `allTrees`/`allDetails`
  derived via `useMemo` flat-mapping over it.)*
- [X] T093 [US5] In the same file, render a clear "chưa có cây template" empty state in the Template
  Checklist panel when T090(a)'s result is empty (no PO mapping ever saved for this Sales Order),
  instead of an empty/broken tree render (depends on T090, T092; spec FR-040).
  *(Done: `allTrees.length === 0` renders "Chưa có cây template — hãy Map File và Save PO Mapping cho
  Sales Order này." instead of an empty tree.)*
- [X] T094 [US5] In the same file, replace `fileMappings` (currently `MOCK_FILE_MAPPINGS[salesId] ||
  {}`) with a derivation from real documents: call `GetEutrDocumentsPoReferencesUseCase.execute([
  ...T090(a)'s purchId set])`, flatten the returned `documents[]`, and match each document's
  `stepNames` against each tree node's `stepName` (string match) to build the `{ [nodeId]:
  fileId[] }`-shaped map `ViewNode` already consumes — same derivation `MapFilePage.jsx`'s
  `derivedFileMappings` already computes (depends on T092; research.md Decision 18, mirrors Decision
  14).
  *(Done: `poReferenceDocs` state (raw) → `realAvailableFiles` `useMemo` (flattened, `size`/
  `uploadedDate`/`expiredDate` explicitly `null` since this endpoint doesn't carry them) →
  `fileMappings` `useMemo` (step-name string match against `allDetails`). Also adjusted `ViewNode`'s
  file-name caption to only render the size/uploaded-date sub-line when at least one of those fields
  is present, so a real (null-metadata) mapped file doesn't render a literal "null · null" string.)*
- [X] T095 [US5] In the same file, confirm `ViewNode` (the page's own pre-existing read-only tree-row
  component) is reused as-is with the real `tree`/`fileMappings` from T092/T094 — verify no
  `onClick`/`onSelect`/`onUnmap` handler is added anywhere in this render path (spec FR-042,
  research.md Decision 21; this is a guardrail/verification task, not expected to require new code
  beyond passing the new data through).
  *(Confirmed: `ViewNode` is unchanged in shape (only the file-caption tweak from T094) — no
  `onSelect`/`onUnmap` prop exists on it, and the only `onClick` in its render tree is the
  collapse/expand toggle (`onToggle`), which mutates local `collapsedIds` UI state only, not any
  server data.)*
- [X] T096 [US5] In the same file, update the Validation Summary calculation: `hasMinOnePO` from
  T090(a)'s result length; `requiredDetails`/`mappedRequired`/`missingRequired`/`pct` recomputed from
  T092/T094's real `allDetails`/`fileMappings` (same `computeProgress`-shaped logic
  `MapFilePage.jsx` already has); **remove** the `noExpiredFiles` check and its `ValidationRow`
  entirely (real documents from `list-po-references` carry no expiry field) and update `canSubmit` to
  `hasMinOnePO && allRequiredMapped` only (depends on T090, T092, T094; spec FR-045/FR-046,
  research.md Decision 20).
  *(Done: `hasMinOnePO = purchaseAttachments.length > 0`; `requiredDetails`/`mappedRequired`/
  `missingRequired`/`pct` computed from real `allDetails`/`fileMappings`; the `noExpiredFiles`
  variable and its `ValidationRow` were removed entirely; `canSubmit = hasMinOnePO &&
  allRequiredMapped`.)*
- [X] T097 [US5] In the same file, remove the now-unused imports (`MOCK_SALES_ORDERS`, `MOCK_SO_POS`,
  `MOCK_SO_PO_MAPPINGS`, `MOCK_AVAILABLE_FILES`, `MOCK_FILE_MAPPINGS`, `EUTR_TEMPLATE_DETAILS_MAP`,
  `EUTR_TEMPLATES`) from `./mock/eutrSalesOrders`, `./mock/eutrTemplateDetails`,
  `./mock/eutrTemplates` once T088-T096 no longer reference them (depends on T088-T096).
  *(Done: the file was rewritten from scratch with no import of any `mock/*` module except none at
  all — `utils/treeUtils`'s `flatToTree` is still imported, `getStepName` is not (real `stepName` is
  always present on normalized details, so the missing-steps list renders `d.stepName` directly).
  Confirmed via `grep` that no `MOCK_*`/`EUTR_TEMPLATE*` identifier remains in the file.)*
- [X] T098 [US5] In the same file, confirm the **Edit / Map File** button(s) still call
  `navigate(`/eutr/sales-orders/${salesId}/map-file`)` unchanged — no new behavior needed, this is a
  guardrail check that T088-T097's edits didn't disturb it (spec FR-043).
  *(Confirmed: both the header action button and the right-panel Validation Summary button still call
  `navigate(`/eutr/sales-orders/${salesId}/map-file`)`, byte-for-byte the same target as before.)*
- [X] T099 [US5] In the same file, confirm the **Download** button still has no `onClick`/handler
  attached (stays a visual-only button) — guardrail check that no accidental no-op-breaking code was
  added during T088-T097 (spec FR-044).
  *(Confirmed: the Download `<Button>` has no `onClick` prop, unchanged from before.)*

**Checkpoint**: User Story 5 is fully functional and independently testable — View Sales Order's
header, Purchase Orders đã chọn, Template Checklist, and Validation Summary all reflect real data
read-only; Edit/Map File and Download behave exactly as before.

---

## Phase 18: Cleanup — Delete Now-Dead Mock Fixtures

**Purpose**: Once `ViewSalesOrderPage.jsx` (the last remaining importer) stops referencing them,
delete the mock fixtures that no file in the repo imports anymore (research.md Decision 22).

- [X] T100 [P] Full-repo search (e.g. `grep -rl "mock/eutrSalesOrders\|mock/eutrTemplateDetails\|
  mock/eutrTemplates" compliance-client/src`) to confirm zero remaining imports of
  `mock/eutrSalesOrders.js`, `mock/eutrTemplateDetails.js`, and `mock/eutrTemplates.js` anywhere in
  the repo (depends on T097).
  *(Confirmed: the search returned zero matches anywhere under `compliance-client/src`. A separate
  search for `mock/eutrSteps` found it imported by two files —
  `eutr-sales-orders/utils/treeUtils.js` and `eutr-templates/utils/treeUtils.js` — confirming that
  file must stay.)*
- [X] T101 [P] Delete
  `compliance-client/src/presentation/pages/eutr-sales-orders/mock/eutrSalesOrders.js`,
  `.../mock/eutrTemplateDetails.js`, and `.../mock/eutrTemplates.js` (depends on T100 confirming zero
  importers). **Do NOT** delete `.../mock/eutrSteps.js` — `utils/treeUtils.js`'s `getStepName()`
  still imports `EUTR_STEPS` from it directly, and that util is shared by `MapFilePage.jsx` too
  (plan.md Project Structure, research.md Decision 22).
  *(Done: all three files deleted; `eutr-sales-orders/mock/` now contains only `eutrSteps.js`.)*

**Checkpoint**: `eutr-sales-orders/mock/` contains only `eutrSteps.js`; `npm run build` still succeeds
with no unresolved-import errors.

---

## Phase 19: Polish & Cross-Cutting Concerns (Update 4)

**Purpose**: Final validation across the `ViewSalesOrderPage.jsx` update; no new functionality.

- [ ] T102 [P] Run the frontend manual verification steps in `specs/005-eutr-sales-orders/
  quickstart.md` "Update 4" section (steps 1-12: header, PO list, Template Checklist tree +
  mapped/missing status, no interactive control anywhere, Edit/Map File navigation, Download no-op,
  Validation Summary contents, no-PO-mapping empty state, nonexistent-Sales-ID error state) (depends
  on T088-T099, T101).
  *(NOT run — requires a browser against a live backend with real D365 POs and seeded
  `eutr_purchase_attachments`/`eutr_references` data, unavailable in this environment. As proxy
  checks: `npm run build` succeeds with a clean `ViewSalesOrderPage.*.js` chunk (14.77 kB) and no
  unresolved imports; `npx eslint` on the changed file reports no issues. A human with that
  environment needs to click through quickstart.md's Update 4 steps 1-12 before sign-off.)*
- [X] T103 [P] Review all new/changed lines in
  `compliance-client/src/presentation/pages/eutr-sales-orders/ViewSalesOrderPage.jsx` to confirm any
  added comments are in Vietnamese, matching `MapFilePage.jsx`'s existing comment style, per
  Constitution Principle IV (depends on T088-T097).
  *(Verified: every comment added in this rewrite is Vietnamese, unaccented ASCII, matching
  `MapFilePage.jsx`'s existing comment style (e.g. "Tai Sales Order (header/existence check)...",
  "Purchase Orders da chon: nguon la Purchase Attachments da luu...").)*
- [X] T104 Confirm `MapFilePage.jsx` and `SalesOrderOverviewPage.jsx` still load without errors and
  are unaffected by this update (`git diff`/`git status` should show only `ViewSalesOrderPage.jsx`
  changed plus the two files deleted in Phase 18) (depends on T097, T101).
  *(Verified: `npm run build` output includes clean `MapFilePage.*.js`/`SalesOrderOverviewPage.*.js`
  chunks with no errors; `git status` inside `compliance-client/` shows this update touched only
  `ViewSalesOrderPage.jsx` (modified) plus the 3 mock files (deleted) — `MapFilePage.jsx` also shows
  as modified in `git status`, but `git diff` confirms that change is the pre-existing, already-
  uncommitted Update 3 Back-button fix (T084, `onClick={() => navigate('/eutr/sales-orders')}`),
  predating this session's work, same as the `certs/*.pem` files noted in T044/T080/T086.
  `SalesOrderOverviewPage.jsx` shows no diff at all.)*
- [X] T105 Note as a (non-)follow-up: confirm no new authorization policy is required for this
  update — `ViewSalesOrderPage.jsx` only calls already-read-authorized endpoints
  (`EutrPurchaseAttachments.Read` plus whatever the D365/`EutrTemplates`/`EutrDocuments` endpoints
  already require), so there is nothing new for an operator to seed (plan.md Constitution Check,
  Principle V, Update 4).
  *(Done — this note is recorded in plan.md's Constitution Check (Principle V, Update 4); no code or
  ops action follows from it.)*

**Checkpoint**: All Update 4 quickstart.md checks pass — `ViewSalesOrderPage.jsx` is fully
real-data-backed and strictly read-only, with no regressions to `MapFilePage.jsx`,
`SalesOrderOverviewPage.jsx`, or any prior update.

---

## Update 4 Dependencies

### Phase Dependencies

- **Phase 17 (US5)**: Depends on Update 1/2's already-existing frontend infra (`GetReferenceDataUseCase`,
  `GetPurchaseAttachmentsBySalesIdUseCase`, `GetPagingEutrTemplatesUseCase`, `GetEutrTemplatesUseCase`,
  `GetEutrDocumentsPoReferencesUseCase` — all already created in Phase 8/12, no new frontend
  infrastructure files needed). Within the phase: T088 has no dependency; T089 depends on T088; T090
  has no dependency on T088/T089 (independent fetch) but is sequenced after for file-diff clarity;
  T091 depends on T090; T092 depends on T090(a); T093 depends on T090, T092; T094 depends on T092;
  T095 depends on T092, T094; T096 depends on T090, T092, T094; T097 depends on all of T088-T096; T098
  and T099 depend on T097 (final guardrail checks).
- **Phase 18 (Cleanup)**: Depends on Phase 17 (T097) confirming no remaining mock references in
  `ViewSalesOrderPage.jsx`. T100 depends on T097; T101 depends on T100.
- **Phase 19 (Polish)**: Depends on Phases 17-18 all being complete.

### Parallel Opportunities

- T090's two fetches (saved-PurchId set and `refType=16` display fields) are independent and could be
  issued concurrently (e.g. `Promise.all`) even though described as one sequenced task above.
- T100 and T101 are sequential (T101 depends on T100's confirmation), but both are independent of
  T102/T103's verification passes and could run in parallel with them.
- T102, T103 (Polish) are independent verification passes and can run in parallel.

### Implementation Strategy

1. Complete Phase 17 (rewrite `ViewSalesOrderPage.jsx` to real, read-only data) — this is the
   user-visible change; T088-T091 (header + PO list) can be demoed before T092-T096 (Template
   Checklist + Validation Summary) are finished, since the header/PO list are independently
   observable even with the tree still on old data.
2. Complete Phase 18 (delete now-dead mock fixtures) — only after Phase 17 confirms zero remaining
   imports.
3. Complete Phase 19 (polish/validation) — full quickstart.md "Update 4" re-pass.

---

## Update 2026-07-27 — Template Tree Toolbar Reload + AVAILABLE FILES Dynamic Badges (User Story 4 continued)

**Context**: Per spec Update 5 (FR-047..FR-052), `MapFilePage.jsx`'s Step 2 gains two changes: (a)
clicking a template chip in the toolbar (`data-marker="template-tree-toolbar"`) refetches
`templatesData` fresh; (b) AVAILABLE FILES' three currently-static labels ("Map status", "File
type", "PO value") become dynamic, sourced from `eutr_references` — Map status compares `StepId`
against the current tree's nodes, File type shows the `RefType`'s name, PO value shows `RefValue`
(already returned as `poCode`, previously unused). Per research.md Decisions 23-25, the only backend
work is additively widening `list-po-references`'s response DTO (owned by `004-eutr-documents`) with
`stepIds`/`refType`/`typeName` — no new endpoint, no migration; `poCode` needs no backend change at
all. The toolbar reload clones this same file's own `loadPurchaseAttachments` extraction pattern
(Decision 12).

**Prerequisites for this update**: [research.md "Update 5" Decisions 23-25](./research.md),
[data-model.md "Update 5"](./data-model.md),
[contracts/map-file-reused-endpoints.md "Update 5" note](./contracts/map-file-reused-endpoints.md),
[quickstart.md "Update 5"](./quickstart.md).

---

## Phase 20: Backend — Widen `list-po-references` Response Additively (`004-eutr-documents`-owned files)

**Purpose**: Surface `StepId`/`RefType`/a joined `TypeName` from `eutr_references` through the
already-existing `GetDocumentsByPoCodesAsync` query/DTO chain — the query already scans the right
rows (`WHERE r.RefValue IN @PoCodes`), it just isn't selecting/returning these columns yet.

- [X] T106 [P] Add nullable `StepId` (`long?`), `RefType` (`byte?`), and `TypeName` (`string?`)
  properties to the Dapper projection class `EutrReferencePoDocumentInfo` in
  `compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/EutrReferencePoDocumentInfo.cs`
  (additive only — do not remove/rename `PoCode`/`DocumentId`/`FileId`/`FileName`/`StepName`), per
  data-model.md's "Update 5" DTO table.
  *(Done: 3 nullable properties added below `StepName`, with a Vietnamese comment citing
  005-eutr-sales-orders Update 5/FR-049/FR-050; the 5 existing properties are untouched.)*
- [X] T107 Update `GetDocumentsByPoCodesAsync`'s SQL in
  `compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/EutrReferencesRepository.cs` to
  add `r.StepId AS StepId, r.RefType AS RefType, t.Name AS TypeName` to the `SELECT` list and a new
  `LEFT JOIN eutr_reference_types t ON t.Id = r.RefType` (existing `LEFT JOIN eutr_documents d`/
  `LEFT JOIN eutr_steps s` and the `WHERE r.RefValue IN @PoCodes` filter stay unchanged) (depends on
  T106).
  *(Done: SQL widened exactly as specified; `WHERE r.RefValue IN @PoCodes` and the two existing
  `LEFT JOIN`s are unchanged. `dotnet build` on `ComplianceSys.Infrastructure` succeeds with 0
  errors.)*
- [X] T108 [P] Add `StepIds` (`List<long>`, default `[]`), `RefType` (`byte?`), and `TypeName`
  (`string?`) properties to `EutrDocumentsPoReferenceItemDto` in
  `compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/
  EutrDocumentsPoReferenceItemDto.cs` (additive only — do not touch `DocumentId`/`FileId`/
  `FileName`/`StepNames`, still consumed as-is by `ViewSalesOrderPage.jsx`), per data-model.md's
  "Update 5" DTO table.
  *(Done: 3 properties added below `StepNames`; the 4 existing properties are untouched.)*
- [X] T109 Update `GetPoReferencesAsync`'s per-`DocumentId` grouping in
  `compliance-sys-api/src/ComplianceSys.Application/Services/EutrDocumentsService.cs` to also
  populate: `StepIds` = distinct non-null `StepId`s across the group (same `Select(...).Where(...)
  .Distinct()` shape already used for `StepNames`); `RefType`/`TypeName` = first non-null value
  across the group — the same first-non-null aggregation `AttachStepAndConditionInfoAsync` already
  uses for its own `RefType`/`TypeName` (depends on T107, T108; research.md Decision 25).
  *(Done: `StepIds = g.Select(x => x.StepId).Where(x => x.HasValue).Select(x => x!.Value)
  .Distinct().ToList()`; `RefType = g.Select(x => x.RefType).FirstOrDefault(x => x.HasValue)`;
  `TypeName = g.Select(x => x.TypeName).FirstOrDefault(x => !string.IsNullOrWhiteSpace(x))` — first
  *non-null* rather than `AttachStepAndConditionInfoAsync`'s plain first-row `FirstOrDefault()`, a
  deliberate small improvement documented in data-model.md/research.md Decision 25. `dotnet build`
  on `ComplianceSys.Application` succeeds with 0 errors.)*
- [ ] T110 Manually verify per quickstart.md "Update 5" backend steps 1-3: a document/PO row with a
  matching `StepId` returns non-empty `stepIds` and the correct `typeName`; a row with `RefType`/
  `StepId` both `NULL` returns `refType: null`, `typeName: null`, `stepIds: []` with no error
  (depends on T109).
  *(NOT run — requires a live `compliance-sys-api` process with a real, seedable MySQL DB,
  unavailable in this environment. As a proxy check: `dotnet build` on `ComplianceSys.Application`
  and `ComplianceSys.Infrastructure` succeeds with 0 errors. Someone with DB access must seed the
  fixtures and run the actual HTTP call before sign-off.)*

**Checkpoint**: `POST /api/eutr-documents/list-po-references` now additionally returns `stepIds`/
`refType`/`typeName` per document, with `stepNames`/`fileName`/`fileId`/`documentId` unchanged —
ready for the frontend to consume.

---

## Phase 21: User Story 4 (continued) — Toolbar Reload + Dynamic AVAILABLE FILES Badges

**Goal**: Wire `MapFilePage.jsx`'s Step 2 toolbar to reload `templatesData` on click, and replace
the three static AVAILABLE FILES badge labels with values computed from Phase 20's widened response.

**Independent Test**: Open Map File for a Sales Order with a saved template tree and at least two
AVAILABLE FILES rows — one whose `eutr_references` row's `StepId` matches a current tree node, one
that doesn't. Confirm the first shows "Mapped" and the second shows "No map", both show a real File
type name and PO value (not the literal placeholder text), and clicking a template chip in the
toolbar visibly re-fetches `templatesData` (network call fires, tree re-renders with the same data).

### Implementation for User Story 4 (Update 5)

- [X] T111 [US4] In
  `compliance-client/src/presentation/pages/eutr-sales-orders/MapFilePage.jsx`, extract the body of
  the existing `templatesData`-building `useEffect` (built from `purchaseAttachments`, Update 2) into
  a `loadTemplatesData` `useCallback` that accepts the resolved `templateCodes` array and performs the
  same `Promise.all` over `GetPagingEutrTemplatesUseCase`/`GetEutrTemplatesUseCase` calls, setting
  `templatesData`/`templatesLoading` exactly as today; call this new callback from the `useEffect`
  itself (unchanged auto-load-on-mount/on-`purchaseAttachments`-change behavior) — mirrors this same
  file's existing `loadPurchaseAttachments` extraction (research.md Decision 23).
  *(Done: `loadTemplatesData` is a `useCallback(async templateCodes => {...}, [])`; the `useEffect`
  now just resolves `templateCodes` from `purchaseAttachments` and calls it. The original per-call
  `active`-flag cancellation guard was dropped, matching `loadPurchaseAttachments`'s own precedent
  (which never had one either) — same accepted tradeoff already established in this file.)*
- [X] T112 [US4] In the same file, add `onClick={() => loadTemplatesData([...new Set(
  purchaseAttachments.map(pa => pa.templateCode))])}` (or an equivalent call using T111's extracted
  function) to each template `Chip` rendered inside the toolbar
  (`data-marker="template-tree-toolbar"`), so clicking any one of them refetches the whole
  `templatesData` list fresh (depends on T111; spec FR-047/FR-048).
  *(Done: each toolbar `Chip` now wraps in a `Tooltip title="Click để tải lại template"` and has the
  specified `onClick`; clicking any chip reloads the full `templatesData` set, per the Update 5
  Assumption that Step 2 always shows every template tree together.)*
- [X] T113 [US4] In the same file, inside the `realAvailableFiles` `useMemo` (built from
  `poReferenceDocs`), carry three additional fields onto each built file object: `poCode:
  poDoc.poCode`, `stepIds: doc.stepIds ?? []`, `typeName: doc.typeName ?? null` (depends on Phase 20;
  research.md Decisions 24-25).
  *(Done: exactly as specified, added below the existing `stepNames: doc.stepNames ?? []` field.)*
- [X] T114 [US4] In the same file, replace the static `<Chip label="Map status" .../>` in the
  AVAILABLE FILES file row with a computed value: `"Mapped"` if `file.stepIds` intersects the
  `stepId` of any node in `allDetails` (already exposes `.stepId` per `normalizeTemplateDetail`),
  else `"No map"` (depends on T113; spec FR-049).
  *(Done: `isMappedByStepId = (file.stepIds || []).some(stepId => allDetails.some(d => d.stepId ===
  stepId))`, computed once per file inside `pagedFiles.map`; Chip label/color now derive from it.)*
- [X] T115 [US4] In the same file, replace the static `<Chip label="File type" .../>` with
  `file.typeName`, rendering a clear empty-state dash (e.g. `"-"`) when `typeName` is `null` (depends
  on T113; spec FR-050/FR-052).
  *(Done: `label={file.typeName || '-'}`.)*
- [X] T116 [US4] In the same file, replace the static `<Chip label="PO value" .../>` with
  `file.poCode`, rendering a clear empty-state dash when `poCode` is missing (depends on T113; spec
  FR-051/FR-052).
  *(Done: `label={file.poCode || '-'}`.)*
- [X] T117 [US4] In the same file, confirm the tree's own existing "already mapped" indicator (the
  `derivedFileMappings`/`stepNames`-vs-`stepName` string match driving each tree node's success/error
  color and icon, Update 2's Decision 14) is left unchanged by T113-T116 — the new Map status badge
  (T114) is a separate, additional per-file computation, not a replacement of the tree's own
  indicator (guardrail/verification task, no code change expected; research.md "Updated non-goals
  (Update 5)").
  *(Confirmed: `derivedFileMappings` (still stepName-vs-`allDetails` string match) and
  `effectiveFileMappings` are untouched by this update's edits — `grep` shows both definitions and
  all call sites intact, no code change made.)*

**Checkpoint**: User Story 4 gains a working toolbar reload and fully dynamic AVAILABLE FILES badges
— no static "Map status"/"File type"/"PO value" placeholder text remains anywhere in Step 2.

---

## Phase 22: Polish & Cross-Cutting Concerns (Update 5)

**Purpose**: Final validation for the Update 5 changes; no new functionality.

- [ ] T118 [P] Run the backend verification steps in `specs/005-eutr-sales-orders/quickstart.md`
  "Update 5" section (steps 1-3: widened `list-po-references` response, null-`RefType`/`StepId`
  graceful empty state) (depends on T110).
  *(NOT run — same reason as T110: no live, seedable-DB `compliance-sys-api` instance in this
  environment.)*
- [ ] T119 [P] Run the frontend manual verification steps in `specs/005-eutr-sales-orders/
  quickstart.md` "Update 5" section (steps 1-8: toolbar chip display unchanged, click-to-reload,
  Mapped/No map per file, real File type/PO value badges, null-field empty state) (depends on
  T111-T117).
  *(NOT run — requires a browser against a live backend with real D365 POs and seeded
  `eutr_references` data, unavailable in this environment. `npm run build` succeeds, producing a
  clean `MapFilePage.*.js` chunk (29.69 kB) with no unresolved imports, as a proxy check. A human
  with that environment needs to click through quickstart.md's Update 5 steps 1-8 before sign-off.)*
- [X] T120 [P] Review all new/changed lines in `EutrReferencePoDocumentInfo.cs`,
  `EutrDocumentsPoReferenceItemDto.cs`, `EutrReferencesRepository.cs`, and
  `EutrDocumentsService.cs` (Phase 20) to confirm any added comments are in Vietnamese, matching
  `EutrReferencesRepository.cs`'s existing comment style, per Constitution Principle IV (depends on
  T106-T109).
  *(Verified: all 4 added/changed comments across these files are Vietnamese, unaccented ASCII,
  matching the existing `EutrReferences*`/`EutrDocuments*` comment style from Updates 1/2/8/13/14.)*
- [X] T121 Confirm `ViewSalesOrderPage.jsx` still loads without errors and its own Template Checklist
  mapped/missing rendering (still `stepNames`-based, per Update 4/Decision 19) is unaffected by
  Phase 20's additive DTO widening; confirm `git diff`/`git status` for this update touches only the
  4 Phase 20 backend files (all owned by `004-eutr-documents`) plus `MapFilePage.jsx` — no other
  frontend file, no migration (depends on T109, T117).
  *(Verified: `npm run build` output includes a clean `ViewSalesOrderPage.*.js` chunk (14.39 kB) with
  no errors; `grep` confirms `ViewSalesOrderPage.jsx` still reads `doc.stepNames`/matches it against
  `detail.stepName` exactly as before (Decision 19), untouched by this update. `git status --short`
  in `compliance-sys-api/` shows exactly the 4 expected Phase 20 files; in `compliance-client/` shows
  `MapFilePage.jsx` plus `certs/*.pem` (pre-existing, unrelated, predating this session — same as
  noted in T044/T080/T086/T104). No migration file was added.)*

**Checkpoint**: All Update 5 quickstart.md checks pass — Step 2's toolbar and AVAILABLE FILES badges
are fully real-data-backed, with no regressions to `ViewSalesOrderPage.jsx`'s own consumption of the
same widened endpoint or to any prior update.

---

## Update 5 Dependencies

### Phase Dependencies

- **Phase 20 (Backend)**: No dependency on Phases 1-19 (additive properties/SQL/mapping on files
  already created by `004-eutr-documents`). T106 and T108 (different files/classes) can start
  immediately in parallel; T107 depends on T106 (same file, sequential — add the projection
  properties before wiring the SQL to fill them); T109 depends on T107 and T108; T110 depends on
  T109.
- **Phase 21 (US4 continued)**: Depends on Phase 20 (T109) for real `stepIds`/`refType`/`typeName`
  data to wire into. Within the phase: T111 has no dependency; T112 depends on T111; T113 depends on
  Phase 20 (T109) but not on T111/T112; T114/T115/T116 each depend on T113 and can be edited in any
  order (independent Chip replacements in the same file); T117 depends on T113-T116 (final guardrail
  check after the new badges are wired).
- **Phase 22 (Polish)**: Depends on Phases 20-21 all being complete.

### Parallel Opportunities

- T106 and T108 (different files/classes) can run in parallel.
- T114, T115, T116 replace three independent `Chip` elements in the same file — low risk of edit
  conflict, but sequenced here for review clarity rather than marked `[P]`.
- T118, T119, T120 (Polish) are independent verification passes and can run in parallel.

### Implementation Strategy

1. Complete Phase 20 (widen `list-po-references` additively) — verify via T110 before moving on.
2. Complete Phase 21 (wire `MapFilePage.jsx`'s toolbar reload + 3 dynamic badges) — this is the
   user-visible change; the toolbar reload (T111/T112) and the badge replacements (T113-T116) touch
   different parts of the same file and can be demoed independently of each other.
3. Complete Phase 22 (polish/validation) — full quickstart.md "Update 5" re-pass, including
   confirming `ViewSalesOrderPage.jsx` (a second consumer of the same widened endpoint) is
   unaffected.

---

## Update 2026-07-27 — Step 2 Upload/Edit → `004-eutr-documents`' Add/Edit Popup (User Story 4 continued)

**Context**: Per spec Update 6 (replaces FR-029/FR-030, adds FR-030a/FR-030b), `MapFilePage.jsx`'s
Step 2 Upload button (UploadIcon) and each AVAILABLE FILES row's Edit action must stop being
local-only/no-op and instead perform real writes, by reusing the already-built Add/Edit document
popup from `004-eutr-documents` (`EutrDocumentsFormDialog.jsx`) in place of this page's own
`UploadDialog`/`MapFileDialog` components. Per research.md Decisions 26-28, this is a pure frontend
reuse — zero new backend endpoint, since `EutrDocumentsFormDialog` already performs every real write
this update needs. The one new frontend orchestration need is edit-detail hydration: before opening
the Edit popup, fetch the target document's full `EutrDocumentsResponseDto` shape via
`GetPagingEutrDocumentsUseCase` filtered by `Id` — the same paging endpoint `004-eutr-documents`'s
own grid already calls, already proven to support an `Id` filter server-side (verified in-code: the
service already injects a `Column="Id"` filter for its own search-box rewrite).

**Prerequisites for this update**: [research.md "Update 6" Decisions 26-28](./research.md),
[data-model.md "Update 6"](./data-model.md),
[contracts/map-file-reused-endpoints.md "Update 6" section](./contracts/map-file-reused-endpoints.md),
[quickstart.md "Update 6"](./quickstart.md).

---

## Phase 23: User Story 4 (continued) — Wire Upload/Edit to `004-eutr-documents`' Add/Edit Popup

**Goal**: Replace `MapFilePage.jsx`'s local-only Upload/Edit dialogs with the reused
`EutrDocumentsFormDialog` component, performing real writes and refreshing AVAILABLE FILES/Map
status afterward.

**Independent Test**: Open Map File for a Sales Order with a saved template tree; click Upload,
complete the popup with a valid Type/Step/Value/file, confirm a real document is created and appears
in AVAILABLE FILES/Map status without a page reload; click Edit on an existing file, confirm the
popup opens pre-filled with its real current values (Type locked), change the Step, Save, and confirm
the change persists across a reload.

### Implementation for User Story 4 (Update 6)

- [X] T122 [US4] In `compliance-client/src/presentation/pages/eutr-sales-orders/MapFilePage.jsx`, add
  an import for `EutrDocumentsFormDialog` from
  `../eutr-documents/components/EutrDocumentsFormDialog` and for `GetPagingEutrDocumentsUseCase` from
  `@application/usecases/eutr-documents/GetPagingEutrDocumentsUseCase`; instantiate
  `const getPagingEutrDocumentsUseCase = new GetPagingEutrDocumentsUseCase(repositories.eutrDocuments);`
  next to the existing `getEutrDocumentsPoReferencesUseCase` instance (line ~94), per research.md
  Decision 26/27.
  *(Done: imported via the `@presentation/pages/eutr-documents/components/EutrDocumentsFormDialog`
  alias (consistent with how the codebase already aliases cross-feature presentation imports) instead
  of a relative path; also added `CustomSnackbar` from `@presentation/components/CustomSnackbar` to
  surface the dialog's `onSubmitted` result message/severity, mirroring `004-eutr-documents/index.jsx`'s
  own usage pattern of the same reused dialog.)*
- [X] T123 [US4] In the same file, replace the two dialog-open state slots `uploadDialog`/
  `setUploadDialog` (line ~663) and `mapDialog`/`setMapDialog` (line ~662) with two new state slots:
  `addDialogOpen`/`setAddDialogOpen` (boolean) and `editDialog`/`setEditDialog` (shape `{ open:
  boolean, initialData: object|null, loading: boolean }`).
  *(Done, plus one added `snackbar` state slot (see T122 note) for the dialog's result notifications.)*
- [X] T124 [US4] In the same file, extract the body of the `poReferenceDocs`-loading `useEffect`
  (line ~795-812, built from `selectedPOs`) into a `loadAvailableFiles` `useCallback` that accepts the
  `purchIds` array and performs the same `getEutrDocumentsPoReferencesUseCase.execute(purchIds)` call,
  setting `poReferenceDocs`/`filesLoading` exactly as today; call this new callback from the
  `useEffect` itself (unchanged auto-load-on-`selectedPOs`-change behavior) — mirrors this same file's
  existing `loadTemplatesData` extraction (research.md Decision 28, same pattern as Decision 23).
  *(Done: the original per-call `active`-flag cancellation guard was dropped, matching
  `loadTemplatesData`/`loadPurchaseAttachments`'s own precedent in this same file — same accepted
  tradeoff already established here, per Update 5's T111 note.)*
- [X] T125 [US4] In the same file, remove the `UploadDialog` function component (line ~125-193), the
  `handleUpload` callback (line ~1026-1048), the `newlyUploadedFiles`/`setNewlyUploadedFiles` state
  (line ~656), and the `MapFileDialog` function component (line ~197-396) together with the
  `handleMapDialogConfirm` callback (line ~987-1022) and the `stepFilePO`/`setStepFilePO` state (line
  ~659) — all local-state-only logic superseded by T122-T124 (depends on T123, T124).
  *(Done. Additional cleanup required for the build to compile: `TreeNode`'s `stepFilePO` prop and its
  `firstFilePO` "PO label on first mapped file" display (never populated by anything except the
  removed `handleMapDialogConfirm`) were removed from both `TreeNode` and its two render call sites;
  `handleMapClick`/`handleUnmapFile` (two callbacks that only ever mutated the removed
  `stepFilePO`/opened the removed `mapDialog`, and were themselves never invoked anywhere in the JSX —
  confirmed dead code pre-dating this update) were removed rather than left referencing deleted state;
  a dead `filePOLabel` local variable (computed from `stepFilePO`, also never rendered) was removed
  from the AVAILABLE FILES row loop. `MapFileDialog` itself was confirmed never actually rendered in
  the prior code (`mapDialog` state was set but no `<MapFileDialog>` JSX consumed it) — the Edit icon
  was effectively a no-op before this update, not merely a local-only one.)*
- [X] T126 [US4] In the same file, update the `allFiles` `useMemo` (line ~853-855, currently
  `[...realAvailableFiles, ...newlyUploadedFiles]`) to be just `realAvailableFiles` directly (drop the
  now-removed `newlyUploadedFiles` concat) — Upload no longer produces a local-only fake row, every
  file now comes from the real `realAvailableFiles` source (depends on T125).
  *(Done: replaced the `useMemo` with a plain `const allFiles = realAvailableFiles;` alias — no
  transformation needed since it's now a direct pass-through.)*
- [X] T127 [US4] In the same file, replace the Upload button's `onClick={() => setUploadDialog(true)}`
  (line ~1585) with `onClick={() => setAddDialogOpen(true)}`, and render
  `<EutrDocumentsFormDialog open={addDialogOpen} mode="add" initialData={null} onClose={() =>
  setAddDialogOpen(false)} onSubmitted={() => { setAddDialogOpen(false); loadAvailableFiles([
  ...selectedPOs]); }} />` in place of the removed `<UploadDialog ... />` render (line ~1792-1796) —
  per research.md Decision 26/28, spec FR-029/FR-030a (depends on T122, T124, T125).
  *(Done, plus `onSubmitted` also shows the dialog's `{message, severity}` result via the new
  `snackbar` state (T122/T123 note) — the dialog always calls `onClose` itself in a `finally` block
  after Upload completes, so the parent's `onClose` handler flipping `addDialogOpen` false is what
  actually closes it, matching how `004-eutr-documents/index.jsx` wires the same dialog.)*
- [X] T128 [US4] In the same file, add a `loadDocumentForEdit` `useCallback` that, given a
  `documentId` (numeric part of a file's `id`, e.g. strip the `EUTR-DOC-` prefix used when building
  `realAvailableFiles`, line ~827), calls
  `getPagingEutrDocumentsUseCase.execute(1, 1, 'Id', 'asc', [{ column: 'Id', operator: 'eq', value:
  documentId }])`, and returns the single `items[0]` row (or `null`) — this is the
  `EutrDocumentsResponseDto` shape (`id`/`name`/`refType`/`stepId`/`conditions`/`validFrom`/
  `validTo`) `EutrDocumentsFormDialog` needs as `initialData` in edit mode (research.md Decision 27;
  data-model.md "Update 6").
  *(Done: `Number(String(file.id).replace('EUTR-DOC-', ''))` recovers the numeric `documentId` from
  the `EUTR-DOC-${documentId}` id format `realAvailableFiles` already builds (T126 context).)*
- [X] T129 [US4] In the same file, replace the Edit `IconButton`'s `onClick={() =>
  setMapDialog({ open: true, file, detailId: selectedDetailId })}` (line ~1711-1725) with an async
  handler that sets `editDialog` to `{ open: true, initialData: null, loading: true }`, calls
  `loadDocumentForEdit(file.id)` (T128), then sets `editDialog` to `{ open: true, initialData:
  <fetched row>, loading: false }` (or closes with an error state if the fetch fails/returns `null`)
  (depends on T128).
  *(Done as `handleEditFile(file)`; on fetch failure/`null` result, `editDialog` is reset to closed
  and the new `snackbar` shows an error message instead of silently leaving a stale/empty popup open.
  Tooltip text updated from "Edit file mapping" to "Edit document" to match the real behavior.)*
- [X] T130 [US4] In the same file, render
  `<EutrDocumentsFormDialog open={editDialog.open} mode="edit" initialData={editDialog.initialData}
  onClose={() => setEditDialog({ open: false, initialData: null, loading: false })}
  onSubmitted={() => { setEditDialog({ open: false, initialData: null, loading: false });
  loadAvailableFiles([...selectedPOs]); }} />` in place of the removed `<MapFileDialog ... />` render,
  guarding the dialog's own internal render on `!editDialog.loading` (e.g. a small loading indicator
  while `editDialog.loading` is `true`, since `initialData` isn't ready yet) — per research.md
  Decision 26/27/28, spec FR-030/FR-030a (depends on T123, T125, T129).
  *(Done: `editDialog.open` only becomes `true` once `loadDocumentForEdit` resolves (T129), so the
  real popup never opens with a not-yet-loaded `initialData`; a small separate `<Dialog
  open={editDialog.loading}>` with a centered `CircularProgress` is shown while the fetch is in
  flight, reusing already-imported `Dialog`/`DialogContent`/`CircularProgress` — no new imports
  needed.)*
- [X] T131 [US4] In the same file, remove the now-unused `SOURCES`/`SOURCE_COLORS`/`AUTO_SOURCES`
  module-level constants and any other identifier that was only referenced by the removed
  `UploadDialog`/`MapFileDialog` components, only if T125 confirms no other remaining code path in
  this file still reads them (depends on T125).
  *(Done: removed `SOURCES`/`SOURCE_COLORS` (verified via grep — used only inside the removed
  `MapFileDialog`). `AUTO_SOURCES` was verified still read by `TreeNode`'s `isAuto` logic (unrelated
  to Upload/Edit) and the Validation Summary's `missingRequired` calculation — kept unchanged.)*

**Checkpoint**: User Story 4's Step 2 Upload/Edit are fully functional and independently testable —
both perform real writes through the reused `004-eutr-documents` popup, and AVAILABLE FILES/Map
status refresh immediately after each.

---

## Phase 24: Polish & Cross-Cutting Concerns (Update 6)

**Purpose**: Final validation for the Update 6 changes; no new functionality.

- [ ] T132 [P] Run the frontend manual verification steps in `specs/005-eutr-sales-orders/
  quickstart.md` "Update 6" section (steps 1-9: real Add popup, real Upload + refresh,
  invalid-file handling, real Edit popup pre-filled, real Save + refresh, persistence across reload,
  discard on close) (depends on T122-T131).
  *(NOT run — requires a browser against a live backend with real SharePoint/D365 access and seeded
  `eutr_documents`/`eutr_references` data, unavailable in this environment.)*
- [X] T133 [P] Review all new/changed lines in `MapFilePage.jsx` from Phase 23 to confirm any added
  comments are in Vietnamese, matching this file's own existing comment style, per Constitution
  Principle IV (depends on T122-T131).
  *(Verified via `git diff`: every new/changed comment introduced by Phase 23 is Vietnamese
  (unaccented ASCII, matching this file's existing Update 2/5 comment style) — no English comment was
  introduced. JSX comment blocks around the two `EutrDocumentsFormDialog` renders are also Vietnamese.)*
- [X] T134 Confirm `git diff`/`git status` for this update touches only
  `compliance-client/src/presentation/pages/eutr-sales-orders/MapFilePage.jsx` — no file under
  `presentation/pages/eutr-documents/` is modified (the dialog is imported, not edited), no backend
  file, no migration (depends on T122-T131).
  *(Verified: `git status --short` inside `compliance-client/` shows exactly one tracked-and-modified
  source file, `MapFilePage.jsx` (292 insertions, 666 deletions), plus the pre-existing unrelated
  `certs/*.pem` changes noted since T044/T080/T086/T104/T121 (predate this session). No file under
  `presentation/pages/eutr-documents/` appears in the diff — `EutrDocumentsFormDialog.jsx` and its
  internal use cases are reused unmodified. No `compliance-sys-api` file changed, no migration added.)*
- [X] T135 Confirm `ViewSalesOrderPage.jsx` and `SalesOrderOverviewPage.jsx` still load without errors
  and are unaffected by this update (depends on T131).
  *(Verified: `npm run build` output includes clean `ViewSalesOrderPage.*.js`/
  `SalesOrderOverviewPage.*.js` chunks with no errors, and `git status` confirms neither file was
  touched by this update.)*

**Checkpoint**: All Update 6 quickstart.md checks pass — Step 2's Upload/Edit are fully real-data-
backed via the reused `004-eutr-documents` popup, with no regressions to any prior update.

---

## Update 6 Dependencies

### Phase Dependencies

- **Phase 23 (US4 continued)**: No dependency on new backend work (zero backend change this update).
  T122 has no dependency; T123 has no dependency on T122 but is grouped after it for file-diff
  clarity; T124 has no dependency on T122/T123; T125 depends on T123 (new state must exist before old
  state is removed) and T124 (extraction must land before its old inline effect is folded away); T126
  depends on T125; T127 depends on T122, T124, T125; T128 depends on T122; T129 depends on T128; T130
  depends on T123, T125, T129; T131 depends on T125.
- **Phase 24 (Polish)**: Depends on Phase 23 being complete.

### Parallel Opportunities

- T122 and T124 (independent additions to the same file) could be implemented in either order since
  neither depends on the other.
- T132, T133, T134 (Polish) are independent verification passes and can run in parallel.

### Implementation Strategy

1. Complete Phase 23 (wire Upload/Edit to the reused `004-eutr-documents` popup) — this is the
   user-visible change; the Upload wiring (T122, T124, T127) and the Edit wiring (T128-T130) touch
   different parts of the same file and can be demoed independently of each other.
2. Complete Phase 24 (polish/validation) — full quickstart.md "Update 6" re-pass.

---

## Update 2026-07-27 — Map Status/AVAILABLE FILES Scoped by PO ↔ Template (User Story 4 continued)

**Context**: Per spec Update 7 (FR-053..FR-057), Step 2's AVAILABLE FILES list and its Map status
badges/tree "already mapped" indicators currently match/merge across **all** saved templates' steps
(`allDetails = templatesData.flatMap(t => t.flatDetails)`) and **all** selected POs' documents
(`realAvailableFiles`, unfiltered), with no check that a document's own PO actually belongs (via
`eutr_purchase_attachments`) to the template being evaluated. Since different templates can reuse the
same `StepId`/step name from the shared `eutr_steps` table, this can mark a document "Mapped" against
an unrelated template's node. Per research.md Decisions 29-30, this is a **100% frontend-only fix,
zero backend change** — `MapFilePage.jsx` already loads `purchaseAttachments` (`{purchId,
templateCode}[]`) and each AVAILABLE FILES entry already carries `poCode`; the fix scopes AVAILABLE
FILES/Map status/the tree's own indicator to the currently-viewed template's own PO(s), and recomputes
the header's aggregate progress as a sum of correctly-scoped per-template completions.

**Prerequisites for this update**: [research.md "Update 7" Decisions 29-30](./research.md),
[data-model.md "Update 7"](./data-model.md),
[contracts/map-file-reused-endpoints.md "Update 7" section](./contracts/map-file-reused-endpoints.md),
[quickstart.md "Update 7"](./quickstart.md).

---

## Phase 25: User Story 4 (continued) — Scope AVAILABLE FILES/Map Status by PO ↔ Template

**Goal**: Recompute `MapFilePage.jsx`'s AVAILABLE FILES list, the tree's "already mapped" indicator,
the per-file Map-status badge, and the header's aggregate progress so that a document can never be
counted as mapped against a template it doesn't actually belong to (per its own PO's `TemplateCode`).

**Independent Test**: Seed a Sales Order with two POs mapped to two different templates that share a
step name/`StepId` (e.g. both have an "Invoice" step) — one PO's PO has a real document on that step,
the other's doesn't. Open Map File: viewing the template with the document shows it as "Mapped" in
AVAILABLE FILES and in the tree; switching the toolbar to the other template shows AVAILABLE FILES
now empty/different (no cross-template document leaking in) and that template's own "Invoice" node
still shows as missing/unmapped. The header's aggregate progress reflects both templates combined and
does not change when switching between them.

### Implementation for User Story 4 (Update 7)

- [X] T136 [US4] In
  `compliance-client/src/presentation/pages/eutr-sales-orders/MapFilePage.jsx`, add a
  `purchIdToTemplateCode` `useMemo` built from `purchaseAttachments`: `new Map(purchaseAttachments.map(
  pa => [pa.purchId, pa.templateCode]))` — the PO→Template lookup key for every task below (research.md
  Decision 29; no new fetch, `purchaseAttachments` is already loaded by the existing
  `loadPurchaseAttachments` callback).
  *(Done: added right after `realAvailableFiles`'s `useMemo`, exactly as specified.)*
- [X] T137 [US4] In the same file, add a `templateComputations` `useMemo` (depends on T136) that maps
  `templatesData` to `{ templateCode, filesForTemplate, derivedFileMappings }` per template:
  - `filesForTemplate = realAvailableFiles.filter(f => purchIdToTemplateCode.get(f.poCode) ===
    t.templateCode)` — only documents whose PO belongs to this specific template.
  - `derivedFileMappings`: the exact same per-detail `stepName`-inclusion match the current global
    `derivedFileMappings` performs, but run against `t.flatDetails` vs this template's own
    `filesForTemplate` only (never against another template's files) — per data-model.md's "Update 7"
    re-scoped-derived-values table.
  *(Done: also carries `flatDetails` through on each computed entry (needed by T142-T144) alongside
  `templateCode`/`filesForTemplate`/`derivedFileMappings`; also added a `selectedTemplateComputation`
  `useMemo` (`templateComputations.find(c => c.templateCode === selectedTemplateCode) ??
  templateComputations[0] ?? null`) as the single lookup every later consumer (T138/T140/T144) reads
  from, rather than re-deriving the `.find(...)` at each call site.)*
- [X] T138 [US4] In the same file, replace the `allFiles = realAvailableFiles` alias (currently feeding
  AVAILABLE FILES' search/pagination/rendering) with `filesForTemplate` from the `templateComputations`
  entry matching `selectedTemplateCode` (fall back to `[]` if `templatesData`/`selectedTemplateCode`
  isn't resolved yet) — scopes the whole AVAILABLE FILES panel to the currently-viewed template's own
  PO(s) (depends on T137; spec FR-053).
  *(Done via `selectedTemplateComputation?.filesForTemplate ?? []`; wrapped in its own `useMemo` (not a
  plain alias like the old code) to keep `react-hooks/exhaustive-deps` satisfied for the downstream
  `availableFiles` `useMemo` that depends on it — confirmed via `npx eslint`, 0 warnings introduced.)*
- [X] T139 [US4] In the same file, reset `filePage` to `1` whenever `selectedTemplateCode` changes (in
  addition to the existing reset-on-`fileSearch`-change effect), so switching templates in the toolbar
  never leaves AVAILABLE FILES stranded on an out-of-range page of the new, differently-sized scoped
  list (depends on T138; spec FR-054).
  *(Done: a second, separate `useEffect(() => setFilePage(1), [selectedTemplateCode])` added right
  after the existing `fileSearch`-keyed one — kept as two effects rather than merging dependency
  arrays, matching this file's existing one-concern-per-effect style.)*
- [X] T140 [US4] In the same file, replace the global `derivedFileMappings`/`effectiveFileMappings`
  `useMemo`s (currently matched against combined `allDetails`/unfiltered `realAvailableFiles`) with
  values sourced from the `templateComputations` entry matching `selectedTemplateCode`: merge the
  existing local `fileMappings` state with that entry's own scoped `derivedFileMappings` (same merge
  logic as today, just fed the per-template value instead of the global one) — this is what the
  rendered `TreeNode` (`fileMappings`/`files` props) and `computeProgress` (T142) both consume (depends
  on T137; spec FR-055/FR-056).
  *(Done: extracted the merge itself into a `mergeWithLocalFileMappings(derivedForTemplate)`
  `useCallback` (depends only on `fileMappings`) so the same merge logic is reusable per-template in
  T142/T143, not just for `selectedTemplateCode`; `effectiveFileMappings` is now
  `mergeWithLocalFileMappings(selectedTemplateComputation?.derivedFileMappings ?? {})`. The old global
  `derivedFileMappings` `useMemo` was removed (superseded by each `templateComputations` entry's own
  scoped `derivedFileMappings` from T137) — `effectiveFileMappings` remains the name every existing
  consumer (`selectedDetailFiles`, the tree's `fileMappings` prop, the "isMappedToSelected"/
  "isMappedToAny" AVAILABLE FILES row highlighting) already reads, so no other call site needed
  renaming.)*
- [X] T141 [US4] In the same file, update the `TreeNode` render call site (Step 2's tree, currently
  passed `fileMappings={effectiveFileMappings}` and `files={allFiles}`) to pass the T140-scoped
  `effectiveFileMappings` and the T138-scoped `allFiles`, so the tree's own "already mapped"
  icon/tooltip for the currently-displayed template can never be satisfied by a file belonging to a
  different template's PO (depends on T138, T140).
  *(No code change needed: the `<TreeNode fileMappings={effectiveFileMappings} files={allFiles} .../>`
  render call site already reads these two identifiers by name — T138/T140 redefined what those names
  resolve to, so the render call site automatically picks up the scoped values with zero edits.
  Confirmed via `grep` that this is still the only render call site for the currently-displayed tree.)*
- [X] T142 [US4] In the same file, replace the single aggregate `progress = computeProgress(allDetails,
  effectiveFileMappings)` call with: for each `t` in `templatesData`, compute `computeProgress(
  t.flatDetails, mergedMappingsForT)` using that template's own `templateComputations` entry's
  `derivedFileMappings` merged with local `fileMappings` (same merge as T140, applied per template
  instead of only for `selectedTemplateCode`), then sum `completed`/`total` across all templates and
  derive `pct` from the summed totals — the header's aggregate stays Sales-Order-wide, not narrowed to
  the currently-viewed template (depends on T137; research.md Decision 30; spec FR-057).
  *(Done via `templateComputations.reduce(...)`, calling `mergeWithLocalFileMappings(t.derivedFileMappings)`
  (T140's extracted helper) per template before each `computeProgress(t.flatDetails, mergedForTemplate)`
  call, then summing `completed`/`total` and deriving `pct` guarded against a `0/0` divide (`total === 0
  ? 0 : Math.round(...)`, matching `computeProgress`'s own existing guard for an empty `required`
  array).)*
- [X] T143 [US4] In the same file, update the `missingRequired` count (currently `allDetails.filter(...)`
  against the global `effectiveFileMappings`) to be computed consistently with T142 — sum the missing-
  Required count across all templates using each template's own scoped mapping, not just
  `selectedTemplateCode`'s — so the Step 2 header's "Missing: N" chip and the footer's "Still missing N
  file" text match the same Sales-Order-wide scope as the aggregate progress (depends on T142).
  *(Done via `templateComputations.reduce(...)`, filtering each template's own `flatDetails` against its
  own `mergeWithLocalFileMappings(t.derivedFileMappings)` result and summing the counts — same
  `AUTO_SOURCES.includes(d.takeFrom)` exclusion kept unchanged from the original predicate.)*
- [X] T144 [US4] In the same file, replace the per-file `isMappedByStepId` computation (currently
  `(file.stepIds || []).some(stepId => allDetails.some(d => d.stepId === stepId))`, matched against
  every template's steps combined) with a comparison against only the currently-selected template's own
  `flatDetails` (`templatesData.find(t => t.templateCode === selectedTemplateCode)?.flatDetails ?? []`)
  — since T138 already guarantees the file being rendered belongs to that template's own PO, this
  comparison can no longer be satisfied by an unrelated template's `StepId` coincidence (depends on
  T138; spec FR-055/FR-056).
  *(Done using `selectedTemplateComputation?.flatDetails ?? []` (T137's carried-through field) rather
  than a fresh `templatesData.find(...)` call, avoiding a second lookup for the same template already
  resolved once for T138/T140.)*
- [X] T145 [US4] Guardrail: confirm Update 5's Map-status Chip (T114-T116) and Update 6's post-Upload/
  Edit refresh call sites (`onSubmitted` → `loadAvailableFiles([...selectedPOs])`, T127/T130) still
  compile and behave correctly against the T138-scoped `allFiles`/`availableFiles` — no further code
  change expected beyond confirming the existing Chip/refresh logic reads the newly-scoped values
  (verification task, no new logic; depends on T138, T144).
  *(Confirmed: the Map status/File type/PO value Chips (T114-T116) still read `isMappedByStepId`/
  `file.typeName`/`file.poCode` by name, now recomputed per T144/unaffected; `loadAvailableFiles`
  (T124/T127/T130) still repopulates `poReferenceDocs` → `realAvailableFiles`, which now flows through
  the new `templateComputations`/`allFiles` derivation automatically — no call site needed editing.
  `npm run build` and `npx eslint` both pass with 0 new errors/warnings introduced by Phase 25.)*

**Checkpoint**: User Story 4's Step 2 correctly scopes AVAILABLE FILES/Map status/the tree's own
indicator by PO ↔ Template — a document can never be shown as mapped to a template it doesn't belong
to, even when templates share a step name/`StepId`; the header's aggregate progress stays
Sales-Order-wide and correct.

---

## Phase 26: Polish & Cross-Cutting Concerns (Update 7)

**Purpose**: Final validation for the Update 7 changes; no new functionality.

- [ ] T146 [P] Run the frontend manual verification steps in `specs/005-eutr-sales-orders/
  quickstart.md` "Update 7" section (fixture setup + steps 1-6: AVAILABLE FILES scoped per template,
  no cross-template false "Mapped", toolbar switch updates the list immediately, aggregate progress
  correct and stable across template switches) (depends on T136-T145).
  *(NOT run — requires a browser against a live backend with a seeded two-templates-sharing-a-step
  fixture, unavailable in this environment. As a proxy check: `npm run build` succeeds, producing a
  clean `MapFilePage.*.js` chunk (29.59 kB) with no errors; a human with that environment needs to
  walk through quickstart.md's Update 7 fixture setup + steps 1-6 before sign-off.)*
- [X] T147 [P] Review all new/changed lines in `MapFilePage.jsx` from Phase 25 to confirm any added
  comments are in Vietnamese, matching this file's own existing comment style, per Constitution
  Principle IV (depends on T136-T145).
  *(Verified: every new/changed comment introduced by Phase 25 (`purchIdToTemplateCode`,
  `templateComputations`, `selectedTemplateComputation`, `allFiles`, the two `filePage`-reset effects,
  `mergeWithLocalFileMappings`/`effectiveFileMappings`, `progress`, `missingRequired`,
  `isMappedByStepId`) is Vietnamese, unaccented ASCII, matching this file's existing Update 2/5/6
  comment style — no English comment was introduced.)*
- [X] T148 Confirm `git diff`/`git status` for this update touches only
  `compliance-client/src/presentation/pages/eutr-sales-orders/MapFilePage.jsx` — no backend file, no
  DTO, no migration, no other frontend file (depends on T136-T145).
  *(Verified: `git status --short` inside `compliance-client/` shows exactly one tracked-and-modified
  source file, `MapFilePage.jsx`, plus the pre-existing unrelated `certs/*.pem` changes noted since
  T044/T080/T086/T104/T121/T134 (predate this session) and one pre-existing untracked
  `src/presentation/themes/custom.css` (also predates this session, unrelated). No `compliance-sys-api`
  file changed, no migration added — matches research.md's "zero backend change" claim for Update 7.)*
- [X] T149 Confirm `ViewSalesOrderPage.jsx` and `SalesOrderOverviewPage.jsx` still load without errors
  and are unaffected by this update (neither reads `MapFilePage.jsx`'s internal derived state) (depends
  on T144).
  *(Verified: `npm run build` output includes clean `ViewSalesOrderPage.*.js`/
  `SalesOrderOverviewPage.*.js` chunks with no errors, and `git status` confirms neither file was
  touched by this update — both are separate page components that only ever read shared
  use-cases/repositories, never `MapFilePage.jsx`'s own local derived state.)*

**Checkpoint**: All Update 7 quickstart.md checks pass — AVAILABLE FILES/Map status/tree indicators are
correctly scoped by PO ↔ Template, aggregate progress is correct, with no regressions to any prior
update.

---

## Update 7 Dependencies

### Phase Dependencies

- **Phase 25 (US4 continued)**: No dependency on new backend work (zero backend change this update).
  T136 has no dependency; T137 depends on T136; T138 depends on T137; T139 depends on T138; T140
  depends on T137; T141 depends on T138 and T140; T142 depends on T137; T143 depends on T142; T144
  depends on T138; T145 depends on T138 and T144.
- **Phase 26 (Polish)**: Depends on Phase 25 being complete.

### Parallel Opportunities

- None of T136-T145 are marked `[P]` — all are sequential edits to derived-state computations within
  the same file, several depending directly on the `useMemo`/lookup the previous task introduces.
- T146, T147, T148 (Polish) are independent verification passes and can run in parallel.

### Implementation Strategy

1. Complete Phase 25 (scope AVAILABLE FILES/Map status/progress by PO ↔ Template) — build the
   `purchIdToTemplateCode` lookup and per-template computations first (T136-T137), then wire each
   consumer (AVAILABLE FILES list, tree indicator, per-file badge, aggregate progress) to the scoped
   values in turn (T138-T144).
2. Complete Phase 26 (polish/validation) — full quickstart.md "Update 7" re-pass, using the
   two-templates-sharing-a-step fixture to prove no cross-template contamination survives.

---

## Update 2026-07-27 — View Sales Order: Template Tree Toolbar + PO/Template-scoped Status (User Story 5 continued)

**Context**: Per spec Update 8 (FR-058..FR-063), `ViewSalesOrderPage.jsx`'s toolbar (`data-marker=
"template-tree-toolbar"`, lines 815-825) currently renders three **hardcoded** `Chip`s ("template
code1"/"template code2"/"All", not sourced from `templatesData`) with no `onClick`, and the Template
Checklist below (lines 872-899) stacks **every** saved template's tree via `templatesData.map(...)`.
The per-step "has document" status (`fileMappings`, lines 535-545) is matched by `stepName` against
`allDetails = templatesData.flatMap(t => t.flatDetails)` — every saved template's steps flattened
together — with no check that a candidate document's own PO belongs (via
`eutr_purchase_attachments`) to the template the step came from. This is the exact same class of
cross-template mismatch already found and fixed for `MapFilePage.jsx` in Update 7/Phase 25. Per
research.md Decisions 31-34, this is a **100% frontend-only fix, zero backend change**:
`ViewSalesOrderPage.jsx` already loads `purchaseAttachments` (lines 326-327, since Update 4) and the
underlying `list-po-references` response already carries `poCode` per document (this feature's own
Update 5, already consumed by `MapFilePage.jsx`) — `ViewSalesOrderPage.jsx`'s own `realAvailableFiles`
builder (lines 512-527) simply never copies that already-present field. The fix clones
`MapFilePage.jsx`'s own `selectedTemplateCode` state/default-first-template effect/toolbar
markup/single-tree render (Update 2/5) and Update 7's `purchIdToTemplateCode`/
`templateComputations`/summed-progress pattern (Phase 25), applied to `ViewSalesOrderPage.jsx`'s own
state/derived-state, minus the write-only reload-on-click refetch (this screen stays read-only, spec
FR-063).

**Prerequisites for this update**: [research.md "Update 8" Decisions 31-34](./research.md),
[data-model.md "Update 8"](./data-model.md),
[contracts/view-sales-order-reused-endpoints.md "Update 8" section](./contracts/view-sales-order-reused-endpoints.md),
[quickstart.md "Update 8"](./quickstart.md).

---

## Phase 27: User Story 5 (continued) — Template Tree Toolbar + PO/Template-scoped Status

**Goal**: Give `ViewSalesOrderPage.jsx`'s Template Checklist toolbar real per-template chips with
click-to-select-one-template display switching (defaulting to the first template), and scope the
per-step "has document" status and Validation Summary aggregate by PO ↔ Template — cloning
`MapFilePage.jsx`'s own already-shipped Update 2/5/7 behavior.

**Independent Test**: Reuse Update 7's fixture (two templates sharing a step name/`StepId`, one PO
per template, only one PO's PO has a real document on the shared step). Open View for that Sales
Order: the toolbar shows a chip per real template (not the old hardcoded labels) and the Checklist
defaults to showing only the first template's tree; the shared step shows "còn thiếu" while viewing
the template whose own PO has no document, and "đã map" while viewing the template whose own PO does
— never the wrong one, regardless of the shared step name/`StepId`. Clicking a toolbar chip switches
the displayed tree immediately with no network call. The Validation Summary's Required/completed
count reflects both templates combined and does not change when switching between them.

### Implementation for User Story 5 (Update 8)

- [X] T150 [US5] In
  `compliance-client/src/presentation/pages/eutr-sales-orders/ViewSalesOrderPage.jsx`, add a
  `selectedTemplateCode` state (`useState(null)`) near the existing `templatesData`/`templatesLoading`
  state (lines 335-336) — the TemplateCode currently shown in the Template Checklist, cloned from
  `MapFilePage.jsx` line 360 (research.md Decision 31).
  *(Done — added right after the `templatesLoading` state, Vietnamese comment matching
  `MapFilePage.jsx`'s own style.)*
- [X] T151 [US5] In the same file, add a default-first-template `useEffect` cloned verbatim from
  `MapFilePage.jsx` lines 500-509: whenever `templatesData` changes, keep the current
  `selectedTemplateCode` if it still exists in `templatesData`, else fall back to
  `templatesData[0].templateCode`; set to `null` when `templatesData` is empty (depends on T150; spec
  FR-060).
  *(Done — added right after the `templatesData`-building `useEffect`, identical logic to
  `MapFilePage.jsx`.)*
- [X] T152 [US5] In the same file, add `poCode: poDoc.poCode` to the object literal built inside the
  `realAvailableFiles` `useMemo` (lines 512-527) — the field already exists on every element of
  `poReferenceDocs` (same `list-po-references` response `MapFilePage.jsx` consumes, which has read
  `poCode` since this feature's own Update 5) but this page's builder never copied it (research.md
  Decision 32).
  *(Done.)*
- [X] T153 [US5] In the same file, add a `purchIdToTemplateCode` `useMemo` built from
  `purchaseAttachments`: `new Map(purchaseAttachments.map(pa => [pa.purchId, pa.templateCode]))` —
  cloned verbatim from `MapFilePage.jsx`'s own (Phase 25/T136), no new fetch (research.md Decision
  33).
  *(Done — added right after the `allTrees` `useMemo`.)*
- [X] T154 [US5] In the same file, add a `templateComputations` `useMemo` (depends on T152, T153)
  cloned from `MapFilePage.jsx`'s own (Phase 25/T137): for each `t` in `templatesData`, compute
  `filesForTemplate = realAvailableFiles.filter(f => purchIdToTemplateCode.get(f.poCode) ===
  t.templateCode)`, then `derivedFileMappings` matching `t.flatDetails` against `filesForTemplate` by
  `stepName` (same match this page's current global `fileMappings` already performs, just scoped);
  also add a `selectedTemplateComputation` `useMemo`
  (`templateComputations.find(c => c.templateCode === selectedTemplateCode) ??
  templateComputations[0] ?? null`) as the single lookup every later task reads from (mirrors
  `MapFilePage.jsx`'s own `selectedTemplateComputation`).
  *(Done — the old global `allDetails`/`fileMappings` `useMemo`s (Update 4) were removed since every
  consumer now reads the per-template-scoped values instead; `allTrees` was kept unchanged (still
  flatMap across all templates, matching `MapFilePage.jsx`'s own precedent for expand/collapse-all
  bookkeeping and the empty-state check).)*
- [X] T155 [US5] In the same file, replace the toolbar's 3 hardcoded `Chip`s (lines 822-824,
  `"template code1"`/`"template code2"`/`"All"`) with `templatesData.map(t => <Chip
  key={t.templateCode} label={t.templateName} variant={t.templateCode === selectedTemplateCode ?
  'filled' : 'outlined'} onClick={() => setSelectedTemplateCode(t.templateCode)} />)`, cloned from
  `MapFilePage.jsx` lines 1145-1187 **minus** the `loadTemplatesData(...)` refetch call inside that
  `onClick` (depends on T150; spec FR-058/FR-059/FR-063 — this screen is read-only, no refetch on
  click).
  *(Done.)*
- [X] T156 [US5] In the same file, replace the Template Checklist's `templatesData.map(t => <tree for
  t>)` stacked-tree render (lines 872-899, every template's tree shown at once) with a single
  selected-template render, cloned from `MapFilePage.jsx` lines 1226-1231: `const t =
  templatesData.find(item => item.templateCode === selectedTemplateCode) ?? templatesData[0]`, then
  render only that one `Box`/header/`t.tree.map(root => <ViewNode ... />)`, passing
  `selectedTemplateComputation.derivedFileMappings` as `ViewNode`'s `fileMappings` prop and
  `selectedTemplateComputation.filesForTemplate` as its `files` prop (replacing the current global
  `fileMappings`/`realAvailableFiles` props) — no `mergeWithLocalFileMappings`-equivalent step needed,
  since this screen has no local map/unmap overrides to merge in (depends on T154, T155; spec
  FR-059/FR-061).
  *(Done — wrapped in the same IIFE pattern `MapFilePage.jsx` uses at its own single-tree render site;
  `?? {}`/`?? []` fallbacks guard the brief window before `selectedTemplateComputation` resolves.)*
- [X] T157 [US5] In the same file, replace the single-pass Validation Summary computation
  (`requiredDetails`/`mappedRequired`/`missingRequired`/`pct`, lines 580-588, currently computed once
  over the globally-flattened `allDetails`/`fileMappings`) with a sum of per-template results, cloned
  from `MapFilePage.jsx`'s own `progress`/`missingRequired` (Phase 25/T142-T143): for each `t` in
  `templateComputations`, filter `t.flatDetails` to `Required` steps excluding `AUTO_SOURCES`
  (preserving this page's own existing exclusion from Update 4), determine completed/missing from
  `t.derivedFileMappings`, then sum `completed`/`total` across all templates and concatenate each
  template's own missing-step names into one combined list — the aggregate stays Sales-Order-wide,
  not narrowed to `selectedTemplateCode` (depends on T154; research.md Decision 34; spec FR-062).
  *(Done via `templateComputations.flatMap(...)` for each of `requiredDetails`/`mappedRequired`/
  `missingRequired` — behaviorally identical to MapFilePage's reduce-to-`{completed,total}`-then-sum
  shape, but kept as flat detail arrays since that is this page's own existing Validation Summary
  style (it never used MapFilePage's `computeProgress` helper, even before this update) — the header
  progress bar and Validation Summary card read these same variable names unchanged, no other call
  site needed editing.)*
- [X] T158 [US5] Guardrail: confirm the Edit/Map File and Download buttons, and the "Purchase Orders
  đã chọn" table (unrelated to the toolbar/Checklist), still compile and behave correctly after
  T150-T157 — no further code change expected beyond confirming these untouched parts of the file
  still work against the now-per-template-scoped state (verification task, no new logic; depends on
  T156, T157).
  *(Confirmed via `npm run build` — clean `ViewSalesOrderPage.*.js` chunk, no errors; these two areas
  read `purchaseAttachments`/`poList`/`salesId` directly, none of which changed shape in this
  update.)*

**Checkpoint**: User Story 5's Template Checklist toolbar shows real per-template chips, defaults to
the first template, switches display on click with no network call, and its "has document"
status/Validation Summary aggregate can never be satisfied by a document belonging to an unrelated
template's PO — matching `MapFilePage.jsx`'s own Update 7 correctness guarantee.

---

## Phase 28: Polish & Cross-Cutting Concerns (Update 8)

**Purpose**: Final validation for the Update 8 changes; no new functionality.

- [ ] T159 [P] Run the frontend manual verification steps in `specs/005-eutr-sales-orders/
  quickstart.md` "Update 8" section (steps 1-9: real toolbar chips, default-first-template, no
  cross-template false "đã map", toolbar switch updates the tree immediately with no network call,
  aggregate Validation Summary correct and stable across template switches, single-template and
  no-template-saved edge cases) (depends on T150-T158).
  *(NOT run — requires a browser against a live backend with the same seeded two-templates-sharing-a-
  step fixture used for Update 7, unavailable in this environment. As a proxy check: `npm run build`
  succeeds, producing a clean `ViewSalesOrderPage.*.js` chunk (15.30 kB) with no errors; a human with
  that environment needs to walk through quickstart.md's Update 8 fixture setup + steps 1-9 before
  sign-off.)*
- [X] T160 [P] Review all new/changed lines in `ViewSalesOrderPage.jsx` from Phase 27 to confirm any
  added comments are in Vietnamese, matching `MapFilePage.jsx`'s own comment style for the equivalent
  logic (e.g. its Update 7 comments on `purchIdToTemplateCode`/`templateComputations`), per
  Constitution Principle IV (depends on T150-T158).
  *(Verified via `git diff`: every new comment introduced by Phase 27 (`selectedTemplateCode`,
  default-first-template effect, `poCode` addition, `purchIdToTemplateCode`, `templateComputations`,
  `selectedTemplateComputation`, the Validation Summary re-scoping, the single-tree-render IIFE) is
  Vietnamese, unaccented ASCII, matching `MapFilePage.jsx`'s own Update 2/7 comment style — no
  English comment was introduced.)*
- [X] T161 Confirm `git diff`/`git status` for this update touches only
  `compliance-client/src/presentation/pages/eutr-sales-orders/ViewSalesOrderPage.jsx` — no backend
  file, no DTO, no migration, no other frontend file (depends on T150-T158).
  *(Verified: this session's edits (via the Edit tool) were applied only to `ViewSalesOrderPage.jsx`
  (217 insertions, 117 deletions per `git diff --stat`). `git status --short` also shows
  `MapFilePage.jsx` and `certs/*.pem` as modified and `src/presentation/themes/custom.css` as
  untracked — all three predate this session's work (from Updates 1-7's own implementation and
  earlier, unrelated changes), not touched by this turn. No `compliance-sys-api` file changed, no
  migration added — matches research.md's "zero backend change" claim for Update 8.)*
- [X] T162 Confirm `MapFilePage.jsx` and `SalesOrderOverviewPage.jsx` still load without errors and
  are unaffected by this update (neither reads `ViewSalesOrderPage.jsx`'s internal derived state)
  (depends on T156).
  *(Verified: `npm run build` output includes clean `MapFilePage.*.js`/`SalesOrderOverviewPage.*.js`
  chunks with no errors, and neither file was touched by this session's edits — both are separate
  page components that only ever read shared use-cases/repositories, never `ViewSalesOrderPage.jsx`'s
  own local derived state.)*

**Checkpoint**: All Update 8 quickstart.md checks pass — the View screen's template-tree toolbar and
PO/Template-scoped status match `MapFilePage.jsx`'s own correctness guarantee, with no regressions to
any prior update.

---

## Update 8 Dependencies

### Phase Dependencies

- **Phase 27 (US5 continued)**: No dependency on new backend work (zero backend change this update).
  T150 has no dependency; T151 depends on T150; T152 has no dependency (independent field addition);
  T153 has no dependency; T154 depends on T152, T153; T155 depends on T150; T156 depends on T154,
  T155; T157 depends on T154; T158 depends on T156, T157.
- **Phase 28 (Polish)**: Depends on Phase 27 being complete.

### Parallel Opportunities

- T152 and T153 (independent additions to the same file, neither depends on the other) could be
  implemented in either order.
- T159 and T160 (Polish) are independent verification passes and can run in parallel.

### Implementation Strategy

1. Complete Phase 27 (toolbar real chips + default-first-template, then PO/Template-scoped status) —
   build the state/lookups first (T150-T154), then wire the toolbar and Checklist render to them
   (T155-T156), then the Validation Summary aggregate (T157).
2. Complete Phase 28 (polish/validation) — full quickstart.md "Update 8" re-pass, reusing Update 7's
   two-templates-sharing-a-step fixture to prove no cross-template contamination survives on this
   screen either.

---

## Update 2026-07-27 — View Button on AVAILABLE FILES (User Story 4 continued)

**Context**: Per spec Update 9 (FR-064..FR-068), each document in `MapFilePage.jsx`'s Step 2
AVAILABLE FILES list currently has only an Edit button (opens `EutrDocumentsFormDialog`, Update 6) —
there is no way to quickly view a file's actual content. Per research.md Decision 35, this capability
already exists end to end for `004-eutr-documents`'s own document grid:
`EutrFileViewerDialog.jsx` (`presentation/pages/eutr-documents/components/EutrFileViewerDialog.jsx`)
already wraps the shared `presentation/components/FilePreviewer.jsx` and already fetches content via
`GetEutrDocumentsFileByIdRefUseCase` (`GET /api/eutr-documents/get-file-by-idref?idRef={fileId}`).
`MapFilePage.jsx`'s own AVAILABLE FILES file objects already carry `fileId` (present since Update 5).
This update is **100% frontend reuse, zero backend change, zero new component** — it clones
`004-eutr-documents/index.jsx`'s own `viewerFile` state/`onView`/`<EutrFileViewerDialog />` pattern
into `MapFilePage.jsx`.

**Prerequisites for this update**: [research.md "Update 9" Decision 35](./research.md),
[data-model.md "Update 9"](./data-model.md),
[contracts/map-file-reused-endpoints.md "Update 9" section](./contracts/map-file-reused-endpoints.md),
[quickstart.md "Update 9"](./quickstart.md).

---

## Phase 29: User Story 4 (continued) — View Button on AVAILABLE FILES

**Goal**: Add a View button next to each document's existing Edit button in Step 2's AVAILABLE
FILES, opening a read-only file-content preview popup reused as-is from `004-eutr-documents`.

**Independent Test**: Open Map File for a Sales Order with at least one real document in AVAILABLE
FILES; confirm each row shows a View button next to Edit; click it and confirm a popup opens showing
that document's own file content (not blank, not the Edit form); confirm the popup has no editable
field and no Save button; close it and confirm no document data changed; click View on a different
document and confirm the popup shows that document's content, not the previous one's.

### Implementation for User Story 4 (Update 9)

- [X] T163 [US4] In
  `compliance-client/src/presentation/pages/eutr-sales-orders/MapFilePage.jsx`, add
  `import EutrFileViewerDialog from '@presentation/pages/eutr-documents/components/EutrFileViewerDialog';`
  near the existing `import EutrDocumentsFormDialog from '@presentation/pages/eutr-documents/
  components/EutrDocumentsFormDialog';` (line 68), and add
  `import VisibilityIcon from '@mui/icons-material/Visibility';` (or add `Visibility as ViewIcon` to
  the existing `@mui/icons-material` import block, lines 41-59) — matching the icon
  `004-eutr-documents`'s own `EutrDocumentsActionCell.jsx` already uses for its View action
  (research.md Decision 35).
  *(Done — added `Visibility as ViewIcon` to the existing icon import block, and
  `EutrFileViewerDialog` right after the `EutrDocumentsFormDialog` import.)*
- [X] T164 [US4] In the same file, add a `viewerFile` state near the existing dialog state
  (`addDialogOpen`/`editDialog`, lines 375-376): `const [viewerFile, setViewerFile] = useState({
  open: false, fileId: null, fileName: '' });` — cloned verbatim from
  `004-eutr-documents/index.jsx`'s own `viewerFile` state shape (depends on T163).
  *(Done — added right after the `snackbar` state, with a Vietnamese comment noting it's read-only
  and independent of the Edit popup above it.)*
- [X] T165 [US4] In the same file, add a new View `IconButton` inside the existing
  `<Stack direction="row" spacing={0.3} flexShrink={0}>` that currently holds only the Edit
  `IconButton` (lines 1434-1450) — placed next to it (either side), with a `Tooltip` (e.g. "View
  document") and `onClick={() => setViewerFile({ open: true, fileId: file.fileId, fileName:
  file.name })}`, styled consistently with the existing Edit `IconButton`'s `sx` (border/borderColor/
  borderRadius), using a different `color` (e.g. `info.main`/`info.200` border) to visually
  distinguish it from Edit (depends on T163, T164; spec FR-064).
  *(Done — placed before the Edit `IconButton` in the same `Stack`, tooltip "View document", `color:
  'info.main'`/`borderColor: 'info.200'` to visually distinguish it from Edit's `primary.main`/
  `primary.200`.)*
- [X] T166 [US4] In the same file, render
  `<EutrFileViewerDialog open={viewerFile.open} fileId={viewerFile.fileId}
  fileName={viewerFile.fileName} onClose={() => setViewerFile(prev => ({ ...prev, open: false }))} />`
  once, alongside the existing `EutrDocumentsFormDialog` renders — no other props, no local
  map/unmap/write logic added (depends on T163, T164; spec FR-065/FR-066/FR-067).
  *(Done — rendered right after the edit-loading `<Dialog>`, before `<CustomSnackbar>`.)*
- [X] T167 [US4] Guardrail: confirm the existing Edit button/popup, Upload button/popup, and Map
  status/File type/PO value badges on the same AVAILABLE FILES rows still compile and behave
  correctly after T163-T166 — no further code change expected beyond confirming these untouched parts
  of the file still work alongside the new View button/popup (verification task, no new logic;
  depends on T165, T166).
  *(Confirmed via `npm run build` — clean `MapFilePage.*.js` chunk, no errors; the Edit `IconButton`/
  `EutrDocumentsFormDialog` renders and the Map status/File type/PO value badge logic were not
  touched by T163-T166, only new siblings were added next to/near them.)*

**Checkpoint**: User Story 4's AVAILABLE FILES rows show a working View button that opens the reused
`004-eutr-documents` file-content preview popup for the correct document, fully independent of and
without affecting the existing Edit button/popup.

---

## Phase 30: Polish & Cross-Cutting Concerns (Update 9)

**Purpose**: Final validation for the Update 9 changes; no new functionality.

- [ ] T168 [P] Run the frontend manual verification steps in `specs/005-eutr-sales-orders/
  quickstart.md` "Update 9" section (steps 1-8: View button present, correct content per document,
  no editable fields/Save in the popup, no data change after close, correct content on switching
  documents, unsupported-type fallback, View/Edit order-independence) (depends on T163-T167).
  *(NOT run — requires a browser against a live backend with a real uploaded document, unavailable
  in this environment. As a proxy check: `npm run build` succeeds, producing a clean
  `MapFilePage.*.js` chunk (30.01 kB, up from 29.59 kB) with no errors; a human with that environment
  needs to walk through quickstart.md's Update 9 steps 1-8 before sign-off.)*
- [X] T169 [P] Review all new/changed lines in `MapFilePage.jsx` from Phase 29 to confirm any added
  comments are in Vietnamese, matching this file's own existing comment style, per Constitution
  Principle IV (depends on T163-T167).
  *(Verified via `git diff`: the new comments introduced by Phase 29 — on the `viewerFile` state and
  the `EutrFileViewerDialog` render — are Vietnamese, unaccented ASCII, matching this file's existing
  Update 2/6 comment style. No new user-facing label was introduced beyond the "View document"
  tooltip, which follows this file's existing English tooltip convention for its sibling icon
  buttons.)*
- [X] T170 Confirm `git diff`/`git status` for this update touches only
  `compliance-client/src/presentation/pages/eutr-sales-orders/MapFilePage.jsx` — no backend file, no
  DTO, no migration, no other frontend file (in particular, confirm
  `EutrFileViewerDialog.jsx`/`FilePreviewer.jsx` under `presentation/pages/eutr-documents/`/
  `presentation/components/` are imported, not modified) (depends on T163-T167).
  *(Verified: this session's edits (via the Edit tool) were applied only to `MapFilePage.jsx` (6
  small, additive hunks — icon import, dialog import, `viewerFile` state, View `IconButton`,
  `EutrFileViewerDialog` render). `git status --short` also shows `ViewSalesOrderPage.jsx`,
  `certs/*.pem`, and untracked `custom.css` as modified — all predate this session's work (from
  Updates 1-8's own implementation). `EutrFileViewerDialog.jsx`/`FilePreviewer.jsx` do not appear in
  the diff at all — imported, not modified. No `compliance-sys-api` file changed, no migration added
  — matches research.md's "zero backend change" claim for Update 9. Pre-existing, unrelated lint
  errors were found in this file (`saveError`/`setFileSearch`/`selectedDetail`/
  `selectedDetailFiles`/`selectedPOCount` unused vars) — confirmed via `git diff` these predate this
  turn's edits and are not introduced by T163-T166; left untouched as out of scope for FR-064..
  FR-068.)*
- [X] T171 Confirm `ViewSalesOrderPage.jsx` and `SalesOrderOverviewPage.jsx` still load without errors
  and are unaffected by this update (depends on T166).
  *(Verified: `npm run build` output includes clean `ViewSalesOrderPage.*.js`/
  `SalesOrderOverviewPage.*.js` chunks with no errors, and neither file was touched by this session's
  edits.)*

**Checkpoint**: All Update 9 quickstart.md checks pass — the View button/popup on Map File's
AVAILABLE FILES works correctly and independently, with no regressions to any prior update.

---

## Update 9 Dependencies

### Phase Dependencies

- **Phase 29 (US4 continued)**: No dependency on new backend work (zero backend change this update).
  T163 has no dependency; T164 depends on T163; T165 depends on T163, T164; T166 depends on T163,
  T164; T167 depends on T165, T166.
- **Phase 30 (Polish)**: Depends on Phase 29 being complete.

### Parallel Opportunities

- T168 and T169 (Polish) are independent verification passes and can run in parallel.
- T165 and T166 both depend only on T163/T164 and touch different parts of the same render tree (the
  button vs. the dialog render), but since both edit the same file they are kept sequential (no `[P]`)
  to avoid edit conflicts, consistent with this feature's established convention for same-file edits.

### Implementation Strategy

1. Complete Phase 29 (import the reused dialog + icon, add state, wire the button, render the
   dialog) — this is the entire user-visible change; no backend work, no new files.
2. Complete Phase 30 (polish/validation) — full quickstart.md "Update 9" re-pass.

---

## Update 2026-07-27 — Real Download on View Sales Order: zip organized by Template (User Story 5 continued)

**Context**: Per spec Update 10 (FR-069..FR-076), the Download button on `ViewSalesOrderPage.jsx`,
currently a no-op (FR-044/Update 4), MUST download a real zip named
`{SalesId}-{CustomerCode}-{CustomerName}`, containing one subfolder per saved template (named with the
template's real display name), each containing only that template's already-"Mapped" documents. Per
research.md Decisions 36-40, a directly-reusable precedent already exists in this codebase —
`AllCompliancesController`/`ComplianceDownloadService` already implement "download a Sales Order's
files as a folder-organized zip" for a different, unrelated feature, including the exact
`{SalesId}-{CustomerCode}-{CustomerName}.zip` naming/sanitization convention this update needs. This
update clones that proven naming/zip-building shape (not the async/SSE/temp-file-cache machinery — the
expected file volume here is much smaller) into one new, small action on the already-`ISharepointService`-
injected `EutrDocumentsController` (same thin-proxy precedent as Update 9's `get-file-by-idref`), which
carries **zero EUTR business logic** — `ViewSalesOrderPage.jsx` already computes the correct
Mapped-per-template document grouping (`templateComputations`, Update 7/8) and supplies it directly in
the request.

**Prerequisites for this update**: [research.md "Update 10" Decisions 36-40](./research.md),
[data-model.md "Update 10"](./data-model.md),
[contracts/eutr-documents-download-zip.md](./contracts/eutr-documents-download-zip.md),
[contracts/view-sales-order-reused-endpoints.md "Update 10" section](./contracts/view-sales-order-reused-endpoints.md),
[quickstart.md "Update 10"](./quickstart.md).

---

## Phase 31: Backend — `EutrDocumentsController.DownloadZip` (new action, 3 new request DTOs)

**Purpose**: Add the one genuinely new backend capability this feature introduces — a folder-organized
zip-download action — on the already-existing, already-`ISharepointService`-injected
`EutrDocumentsController`. No new controller, no new Application service, no new repository/entity, no
migration, no new policy.

- [X] T172 [P] Create DTO `EutrDownloadZipFileDto` in
  `compliance-sys-api/src/ComplianceSys.Application/Dtos/Request/EutrDownloadZipFileDto.cs` — flat
  class with `FileId` (string) and `FileName` (string), per data-model.md/contracts/
  eutr-documents-download-zip.md.
- [X] T173 Create DTO `EutrDownloadZipFolderDto` in
  `compliance-sys-api/src/ComplianceSys.Application/Dtos/Request/EutrDownloadZipFolderDto.cs` — flat
  class with `FolderName` (string) and `Files` (`List<EutrDownloadZipFileDto>`, default `[]`) (depends
  on T172).
- [X] T174 Create DTO `EutrDownloadZipRequestDto` in
  `compliance-sys-api/src/ComplianceSys.Application/Dtos/Request/EutrDownloadZipRequestDto.cs` — flat
  class with `SalesId` (string), `CustomerCode` (string), `CustomerName` (string), `Folders`
  (`List<EutrDownloadZipFolderDto>`, default `[]`) (depends on T173).
- [X] T175 [P] In `compliance-sys-api/src/ComplianceSys.Api/Controllers/EutrDocumentsController.cs`,
  add two new small private static helper methods cloned from `AllCompliancesController.cs`'s own
  `SanitizeFileNamePart`/`BuildSoZipFileName` (root zip name = sanitized
  `"{SalesId}-{CustomerCode}-{CustomerName}.zip"`) and `ComplianceDownloadService.BuildFolderName`
  (invalid-filename-character replacement for a free-text folder name) — per research.md Decision 36
  (clone, do not take a dependency on the other controller/service — Decision 40).
  *(Done as `SanitizeZipNamePart` + `BuildDownloadZipFileName`.)*
- [X] T176 [P] In the same file, add one new small private static helper cloned from
  `ComplianceDownloadService.GetUniqueEntryName` — given a `HashSet<string>` of already-used zip entry
  paths and a candidate `"{folderName}/{fileName}"` path, returns a disambiguated path
  (`name_1.ext`, `name_2.ext`, …) scoped per folder, per spec FR-075/research.md Decision 36.
  *(Done as `GetUniqueZipEntryName`.)*
- [X] T177 In the same file, add the new action:
  `[Authorize(Policy = "EutrDocuments.ReadAll")] [HttpPost("download-zip")] public async Task<IActionResult> DownloadZip([FromBody] EutrDownloadZipRequestDto request, CancellationToken ct = default)`
  implementing, per contracts/eutr-documents-download-zip.md:
  - Return `400 BadRequest` with a clear message if `request?.Folders` is null/empty, or every
    folder's `Files` list is empty (spec FR-074) — no zip body in that case.
  - Otherwise build a `MemoryStream` + `ZipArchive` (cloned shape:
    `AllCompliancesController.DownloadMultipleFiles`'s in-memory `ZipArchive` +
    `ComplianceDownloadService.BuildSoZipWithProgressAsync`'s semaphore-limited parallel download):
    for each folder with an empty `Files` list, create an empty directory entry
    (`archive.CreateEntry($"{sanitizedFolderName}/")`, spec FR-073); for each file, fetch via the
    already-injected `_sharepointService.DownloadByFileId(fileId)` (bounded parallelism, e.g.
    `SemaphoreSlim(3)`, matching `ComplianceDownloadService`'s own limit), buffer to a `MemoryStream`,
    then under a `lock` create a uniquely-named entry (T176) at
    `"{sanitizedFolderName}/{uniqueFileName}"` and copy the buffer into it.
  - If every file download fails (zero successes across the whole request), return
    `500 Internal Server Error` with a clear message — no empty/corrupt zip returned as `200`.
  - On success, return
    `File(memoryStream.ToArray(), "application/zip", BuildRootZipName(request) /* T175 */)` (sets
    `Content-Disposition: attachment; filename=...` via the `File(...)` helper, matching this
    controller's existing response conventions) (depends on T174, T175, T176).
  *(Done — implemented exactly as specified, with the empty-directory-entry creation also placed
  inside the shared `lock` (`ZipArchive` is not thread-safe), which the task description didn't call
  out explicitly but is required correctness given directory entries and file entries can otherwise
  race across threads.)*
- [ ] T178 Manually verify the new endpoint per quickstart.md "Update 10" backend steps 1-5 (mixed
  empty/non-empty folders, same-filename disambiguation within a folder, invalid-character
  sanitization in `customerName`, all-empty-folders rejection, single-empty-folder rejection) (depends
  on T177).
  *(NOT run — requires a live `compliance-sys-api` process with a real SharePoint-backed `fileId` to
  download, unavailable in this environment. As a proxy check: `dotnet build` on
  `ComplianceSys.Application` succeeds with 0 errors; `dotnet build` on `ComplianceSys.Api` hit the
  same pre-existing `MSB3027`/`MSB3021` file-lock error from an already-running `ComplianceSys.Api.exe`
  instance holding its own output DLLs open (same category of issue as T030/T056, confirmed via `grep`
  that zero `error CS` lines appear in the build log — only the file-lock `MSB` errors). Someone with
  D365/SharePoint access must run the actual HTTP round-trips before sign-off.)*

**Checkpoint**: `POST /api/eutr-documents/download-zip` returns a correctly-named, correctly-organized
zip for a client-supplied folder→file grouping, and rejects the nothing-to-download case with a clear
message — ready for the frontend to consume.

---

## Phase 32: Frontend — Download Use Case + Repository Extension

**Purpose**: Add the frontend layers needed to call the new endpoint and save the response as a file,
cloning the already-established EUTR-family blob-download pattern
(`ExportEutrTemplatesUseCase.js`/`ExportEutrMastersUseCase.js`). Extends already-existing
`004-eutr-documents`-owned files additively — no new domain/infrastructure file beyond one new use
case.

- [X] T179 [P] Add a `downloadZip(payload)` method stub to
  `compliance-client/src/domain/interfaces/IEutrDocumentsRepository.js`, alongside the existing
  methods on that interface.
- [X] T180 [P] Add `downloadZip: (payload) => axiosInstance.post('/eutr-documents/download-zip',
  payload, { responseType: 'blob' })` to `compliance-client/src/infrastructure/api/eutrDocumentsApi.js`
  — same `responseType: 'blob'` convention as `eutrTemplatesApi.js`'s existing `export` method.
- [X] T181 Implement `downloadZip(payload)` in
  `compliance-client/src/infrastructure/repositories/RestEutrDocumentsRepository.js` — calls
  `eutrDocumentsApi.downloadZip(payload)` and returns the full axios response (blob body + headers, in
  particular `content-disposition`), not a pre-unwrapped value (depends on T179, T180).
- [X] T182 Create `compliance-client/src/application/usecases/eutr-documents/
  DownloadEutrSalesOrderZipUseCase.js` — `execute(payload)` calls
  `repository.downloadZip(payload)`, then clones `ExportEutrTemplatesUseCase.js`'s blob-save pattern
  verbatim: resolve the file name from the response's `Content-Disposition` header (regex-parsed, same
  as `ExportEutrTemplatesUseCase.js`'s `_resolveFileName`, with a generated-timestamp `.zip` fallback
  name if the header is absent), `window.URL.createObjectURL(new Blob([blob]))`, create a hidden `<a
  download>`, click it, remove it, then `revokeObjectURL` (depends on T181).

**Verification**: `npm run build` (Vite) succeeds with all new imports resolved.

**Checkpoint**: `DownloadEutrSalesOrderZipUseCase.execute({ salesId, customerCode, customerName,
folders })` downloads and saves the zip — ready to wire into the Download button.

---

## Phase 33: User Story 5 (continued) — Wire the Download Button

**Goal**: Replace the Download button's no-op (spec FR-044/Update 4) with a real call built entirely
from data `ViewSalesOrderPage.jsx` already has loaded — no new fetch on click.

**Independent Test**: Open View for a Sales Order with 2+ saved templates where at least one template
has a Mapped document and at least one does not; click Download; confirm a correctly-named zip
downloads with one subfolder per template (real template names), the Mapped-document template's
subfolder contains exactly its own Mapped document(s) (no cross-template leakage), and the other
template's subfolder is present but empty. Then open View for a Sales Order with zero Mapped documents
anywhere and confirm Download shows a clear message instead of downloading an empty zip.

### Implementation for User Story 5 (Update 10)

- [X] T183 [US5] In
  `compliance-client/src/presentation/pages/eutr-sales-orders/ViewSalesOrderPage.jsx`, add a
  `buildDownloadFolders()` helper (pure function/`useMemo`/`useCallback`, no new fetch) that maps
  `templateComputations` (Update 8, Decision 33) into `folders: [{ folderName, files }]`: `folderName`
  = that template's `templateName`; `files` = the subset of that template's own
  `filesForTemplate` whose `documentId`/id appears in any value array of that same template's
  `derivedFileMappings` (i.e. already-"Mapped" documents only, spec FR-072), each mapped to `{ fileId:
  f.fileId, fileName: f.name }` (depends on T157/T158's already-computed `templateComputations` from
  Phase 27; per data-model.md "Update 10" "Building the request" table).
  *(Done as a `useCallback`. One additive fix discovered and applied during implementation, not called
  out in the original task text: `realAvailableFiles` (this page's own builder, Update 4/8) never
  copied `doc.fileId` onto each built file object — `MapFilePage.jsx`'s equivalent builder has carried
  it since Update 5, but this screen's own builder simply never read it, same class of gap Update 8
  found and fixed for `poCode`. Added `fileId: doc.fileId` to that builder so `filesForTemplate`
  entries actually carry the SharePoint id `buildDownloadFolders` needs; filtered out any file missing
  `fileId` defensively.)*
- [X] T184 [US5] In the same file, wire the existing Download `<Button>`'s `onClick` to: call
  `buildDownloadFolders()` (T183); if every folder's `files` array is empty (nothing Mapped anywhere,
  including the "no template saved at all" case), show a clear "Không có tài liệu nào để tải" message
  (e.g. via this page's existing snackbar/alert pattern) and return without calling the use case (spec
  FR-074); otherwise call
  `DownloadEutrSalesOrderZipUseCase.execute({ salesId: so.code, customerCode: so.custAccount,
  customerName: so.name, folders })` (T182), showing a clear error message if the call rejects (e.g.
  the backend's `500`/network failure case) instead of failing silently (depends on T182, T183).
  *(Done. This page had no existing snackbar mechanism (unlike `MapFilePage.jsx`) — added one small
  local `snackbar` state and rendered the shared `CustomSnackbar` component
  (`presentation/components/CustomSnackbar.jsx`, already used by `MapFilePage.jsx`) rather than
  inventing a new notification pattern. Also added a `downloading` state disabling the button and
  swapping its icon for a spinner while the request is in flight, purely to prevent double-submission
  — the button is never disabled for the "nothing to download" case itself, per FR-074.)*
- [X] T185 [US5] Guardrail: confirm the Edit/Map File button, the "Purchase Orders đã chọn" table, the
  template-tree toolbar/Checklist, and Validation Summary (all unrelated to the Download button) still
  compile and behave correctly after T183-T184 — no further code change expected beyond confirming
  these untouched parts of the file still work (verification task, no new logic; depends on T184).
  *(Confirmed via `npm run build` — clean `ViewSalesOrderPage.*.js` chunk (16.91 kB, up from 15.30 kB),
  no errors; none of these areas were touched by T183-T184.)*

**Checkpoint**: User Story 5's Download button downloads a correctly-named, correctly-organized,
Mapped-only zip when there is something to download, and shows a clear message instead of an empty zip
when there isn't — matching spec FR-069..FR-076 exactly.

---

## Phase 34: Polish & Cross-Cutting Concerns (Update 10)

**Purpose**: Final validation for the Update 10 changes; no new functionality.

- [ ] T186 [P] Run the backend verification steps in `specs/005-eutr-sales-orders/quickstart.md`
  "Update 10" section (steps 1-5: mixed empty/non-empty folders + empty directory entry, same-filename
  disambiguation, invalid-character sanitization, all-folders-empty rejection, single-empty-folder
  rejection) (depends on T177, T178).
  *(NOT run — same reason as T178: no live, SharePoint-connected `compliance-sys-api` process
  available in this environment.)*
- [ ] T187 [P] Run the frontend manual verification steps in `specs/005-eutr-sales-orders/
  quickstart.md` "Update 10" section (steps 1-8: correct zip name/structure, no cross-template
  leakage, empty-template-saved and zero-Mapped-anywhere messages, no data written, special-character
  Customer name) (depends on T183-T185).
  *(NOT run — requires a browser against a live backend with real SharePoint-stored EUTR documents,
  unavailable in this environment. As a proxy check: `npm run build` succeeds producing a clean
  `ViewSalesOrderPage.*.js` chunk with no errors, and `npx eslint` on every changed/new file reports
  zero new problems (one pre-existing, unrelated `canSubmit` unused-var error was confirmed via `git
  diff` to predate this turn's edits, same category as the pre-existing lint debt already noted in
  T170). A human with that environment needs to walk through quickstart.md's Update 10 steps 1-8
  before sign-off.)*
- [X] T188 [P] Review all new/changed lines in `EutrDocumentsController.cs` (Phase 31) and
  `ViewSalesOrderPage.jsx` (Phase 33) to confirm any added comments are in Vietnamese, matching each
  file's own existing comment style (`EutrDocumentsController.cs`'s Update 9 `GetFileByIdRef` comment;
  `ViewSalesOrderPage.jsx`'s Update 7/8 comment style), per Constitution Principle IV (depends on
  T172-T177, T183-T184).
  *(Verified via `git diff`: every new comment in `EutrDocumentsController.cs` (the `DownloadZip`
  action's XML summary, `BuildDownloadZipFileName`, `SanitizeZipNamePart`, `GetUniqueZipEntryName`,
  and inline comments) and in `ViewSalesOrderPage.jsx` (the `fileId` addition, `downloading`/`snackbar`
  state, `buildDownloadFolders`, `handleDownload`) is Vietnamese, unaccented ASCII, matching each
  file's existing comment style. No new backend user-facing string beyond the `ApiResponse<string>.
  Fail(...)` messages, which are Vietnamese; the one new frontend user-facing string
  ("Không có tài liệu nào để tải.") is Vietnamese per plan.md's Constitution Check note; "Tải file
  thất bại, vui lòng thử lại." (network/500 error case) follows the same convention.)*
- [X] T189 Confirm `git diff`/`git status` for this update touches only: the 3 new request DTO files
  (T172-T174), `EutrDocumentsController.cs` (Phase 31), `IEutrDocumentsRepository.js`/
  `eutrDocumentsApi.js`/`RestEutrDocumentsRepository.js` (Phase 32, additive methods only), the new
  `DownloadEutrSalesOrderZipUseCase.js` file, and `ViewSalesOrderPage.jsx` (Phase 33) — no migration,
  no new policy, no change to `AllCompliancesController.cs`/`ComplianceDownloadService.cs` (cloned
  from, not modified — research.md Decision 40) (depends on T172-T185).
  *(Verified: `git status --short` inside `compliance-sys-api` shows exactly `EutrDocumentsController.cs`
  modified plus the 3 new DTO files under `Dtos/Request/` (the other modified files —
  `EutrDocumentsPoReferenceItemDto.cs`, `EutrReferencePoDocumentInfo.cs`, `EutrDocumentsService.cs`,
  `EutrReferencesRepository.cs` — predate this session, from Update 5's own work). `git status --short`
  inside `compliance-client` shows exactly `IEutrDocumentsRepository.js`/`eutrDocumentsApi.js`/
  `RestEutrDocumentsRepository.js`/`ViewSalesOrderPage.jsx` modified plus the new
  `DownloadEutrSalesOrderZipUseCase.js` file (the other modified/untracked entries — `certs/*.pem`,
  `MapFilePage.jsx`, `presentation/themes/custom.css` — predate this session, same as noted in T161/
  T170). `AllCompliancesController.cs`/`ComplianceDownloadService.cs` do not appear in either diff at
  all — confirmed read-only-as-reference, not modified (research.md Decision 40). No migration, no new
  policy code — `EutrDocuments.ReadAll` was reused as-is.)*
- [X] T190 Confirm `MapFilePage.jsx` and `SalesOrderOverviewPage.jsx` still load without errors and are
  unaffected by this update (neither reads `ViewSalesOrderPage.jsx`'s Download-specific state, and
  neither calls the new endpoint) (depends on T184).
  *(Verified: `npm run build` output includes clean `MapFilePage.*.js`/`SalesOrderOverviewPage.*.js`
  chunks with no errors, and neither file was touched by this session's edits.)*

**Checkpoint**: All Update 10 quickstart.md checks pass — the View screen's Download button produces a
correct, Mapped-only, Template-organized zip with no regressions to any prior update.

---

## Update 10 Dependencies

### Phase Dependencies

- **Phase 31 (Backend)**: No dependency on Phases 1-30 (new, independent action on an existing
  controller). T172 has no dependency; T173 depends on T172; T174 depends on T173; T175 and T176 have
  no dependency (independent private helpers) and can run in parallel with each other and with
  T172-T174; T177 depends on T174, T175, T176; T178 depends on T177.
- **Phase 32 (Frontend use case)**: No dependency on Phase 31 completion to *start* (frontend files can
  be scaffolded in parallel), but T178's manual verification implies Phase 31 should be functionally
  done before Phase 33 integration is meaningfully testable. T179 and T180 can run in parallel; T181
  depends on both; T182 depends on T181.
- **Phase 33 (US5 continued)**: Depends on Phase 32 (T182) and, functionally, Phase 31 (a working
  endpoint to call), plus Phase 27's already-computed `templateComputations` (Update 8). T183 depends
  on T182 (conceptually; on Phase 27's prior state in practice); T184 depends on T182, T183; T185
  depends on T184.
- **Phase 34 (Polish)**: Depends on Phases 31-33 all being complete.

### Parallel Opportunities

- T175 and T176 (independent private helper methods, same file but non-overlapping additions) can be
  implemented in either order.
- T179 and T180 (different files) can run in parallel.
- T186, T187, T188 (Polish) are independent verification passes and can run in parallel.

### Implementation Strategy

1. Complete Phase 31 (backend `download-zip` action + 3 DTOs) — verify via T178 before moving on.
2. Complete Phase 32 (frontend use case + repository extension) — can be scaffolded in parallel with
   Phase 31.
3. Complete Phase 33 (wire the Download button) — this is the entire user-visible change.
4. Complete Phase 34 (polish/validation) — full quickstart.md "Update 10" re-pass.

---

## Update 2026-07-27 — Progress-Figure Consistency Fix: `computeProgress()` Excludes `AUTO_SOURCES` (User Story 4 continued)

**Context**: Per spec Update 11 (FR-077..FR-081), `MapFilePage.jsx`'s `progress.total`/
`progress.completed` (`data-marker="progress-bar"`, the "Mapped" chip, and the footer's "Required: x/y"
line) MUST stay **Required-only** — an earlier same-session draft of this update mistakenly broadened it
to also count Optional steps; the requester corrected this immediately, since "toàn bộ template" only
ever meant the pre-existing cross-template aggregation (Update 7/FR-057), not a broader set of step
types. Reviewing every variable in both `MapFilePage.jsx` and `ViewSalesOrderPage.jsx` that counts
mapped/missing step status (requested explicitly) surfaced one real inconsistency: `computeProgress()`
(backing `progress.total`/`progress.completed`) filters to `requirementType === 'Required'` but never
excludes the legacy `AUTO_SOURCES` `takeFrom` values, while this same screen's own `missingRequired`
("Still missing X file") **does** exclude them, as do `ViewSalesOrderPage.jsx`'s own `requiredDetails`/
`mappedRequired`/`missingRequired`. This is a **100% frontend-only, zero-backend-change** fix, confined
to one filter predicate inside `computeProgress()` — `ViewSalesOrderPage.jsx` needs **no** code change
(its four equivalent variables were confirmed already correct by this review, per research.md
Decision 41).

**Prerequisites for this update**: [research.md "Update 11" Decision 41](./research.md),
[data-model.md "Update 11"](./data-model.md),
[contracts/map-file-reused-endpoints.md "Update 11" section](./contracts/map-file-reused-endpoints.md),
[quickstart.md "Update 11"](./quickstart.md).

---

## Phase 35: User Story 4 (continued) — `computeProgress()`'s Required-step filter excludes `AUTO_SOURCES`

**Goal**: Make `progress.total`/`progress.completed` (Map File) internally consistent with
`missingRequired` on the same screen, and consistent with View's equivalent figures for the same Sales
Order — without changing which step *type* (Required vs Optional) is counted.

**Independent Test**: Craft a Sales Order/template fixture with one Required step whose `takeFrom` is
one of `AUTO_SOURCES` and has no mapped file; open Map File and confirm `progress.total -
progress.completed` equals the "Still missing X file" count; open View for the same Sales Order and
confirm its Required/completed/missing figures match Map File's exactly.

- [X] T191 [US4] In `compliance-client/src/presentation/pages/eutr-sales-orders/MapFilePage.jsx`, edit
  `computeProgress()`'s `required` filter (currently `details.filter(d => d.requirementType ===
  'Required')`, around line 106) to also exclude `AUTO_SOURCES`: `details.filter(d =>
  d.requirementType === 'Required' && !AUTO_SOURCES.includes(d.takeFrom))` — the exact same condition
  already used by this file's own `missingRequired` (around line 816-826) and by
  `ViewSalesOrderPage.jsx`'s `requiredDetails`/`mappedRequired`/`missingRequired` (spec FR-077/FR-078/
  FR-079, research.md Decision 41). Add a Vietnamese comment above the function referencing FR-079,
  matching this file's own existing comment style (e.g. the Update 7 comment already on
  `missingRequired`). Do **not** change the `completed`/`total`/`pct` return shape, the function's
  signature, or any of its call sites — per FR-077/FR-078, the count stays Required-only (do not add
  Optional steps).
  *(Done exactly as specified: the `required` filter now reads `details.filter(d =>
  d.requirementType === 'Required' && !AUTO_SOURCES.includes(d.takeFrom))`, with a 2-line Vietnamese
  comment above the function referencing spec 005/Update 11/FR-077-FR-079, matching this file's own
  comment style. No other line in the function changed.)*
- [X] T192 [P] [US4] Guardrail: confirm no other call site or variable in
  `compliance-client/src/presentation/pages/eutr-sales-orders/ViewSalesOrderPage.jsx` needs a matching
  edit — `requiredDetails`/`mappedRequired`/`missingRequired`/`pct` (lines ~649-673) already include the
  `AUTO_SOURCES` exclusion; this is a verification-only task confirming spec FR-081 (no change expected
  there), not an implementation task (depends on T191 for context, no file edit expected).
  *(Confirmed by re-reading `ViewSalesOrderPage.jsx` lines 649-673: `requiredDetails`, `mappedRequired`,
  and `missingRequired` each already filter `d.requirementType === 'Required' &&
  !AUTO_SOURCES.includes(d.takeFrom)`. No edit made to this file.)*

**Checkpoint**: `progress.total - progress.completed` always equals `missingRequired` on Map File, and
Map File's progress figures always match View's for the same Sales Order (spec SC-026/SC-035).

---

## Phase 36: Polish & Cross-Cutting Concerns (Update 11)

**Purpose**: Final validation for the Update 11 change; no new functionality.

- [ ] T193 [P] Run the frontend manual verification steps in `specs/005-eutr-sales-orders/quickstart.md`
  "Update 11" section (steps 1-4: Optional steps stay excluded, `progress.total - progress.completed`
  equals "Still missing X file", View matches Map File, mapping the `AUTO_SOURCES` step updates both
  numbers in lockstep) (depends on T191).
  *(NOT run — requires a live backend + browser session against a real Sales Order, unavailable in this
  environment. As a proxy check: `npm run build` succeeds producing a clean `MapFilePage.*.js` chunk
  (30.07 kB) and `ViewSalesOrderPage.*.js` chunk (16.88 kB) with no errors; `npx eslint` on
  `MapFilePage.jsx` reports the same 4 pre-existing unused-var errors as the unmodified baseline (`git
  stash` comparison) plus 1 pre-existing `setFileSearch` unused-var error already introduced by prior
  (Update 5) work — zero new lint problems from this edit. A human with a live environment must walk
  through quickstart.md's Update 11 steps 1-4 before sign-off.)*
- [X] T194 [P] Review the new/changed lines in `MapFilePage.jsx` (T191) to confirm the added comment is
  in Vietnamese, matching this file's own existing comment style, per Constitution Principle IV (depends
  on T191).
  *(Verified via `git diff`: the 2-line comment above `computeProgress()` is Vietnamese, unaccented
  ASCII, matching this file's existing comment style (e.g. the Update 7 comment on `missingRequired`
  just below it). No new user-facing string introduced — no label changed, per FR-077's "stays
  Required-only" scope.)*
- [X] T195 Confirm `git diff`/`git status` for this update touches only
  `compliance-client/src/presentation/pages/eutr-sales-orders/MapFilePage.jsx` — no backend file, no new
  DTO, no change to `ViewSalesOrderPage.jsx` (depends on T191, T192).
  *(Verified: this session's only file edit was `MapFilePage.jsx`. `compliance-sys-api`'s `git status
  --short` shows only pre-existing modifications from prior updates (`EutrDocumentsController.cs`,
  `EutrDocumentsPoReferenceItemDto.cs`, `EutrReferencePoDocumentInfo.cs`, `EutrDocumentsService.cs`,
  `EutrReferencesRepository.cs`, plus the 3 new Update 10 DTO files) — none touched by this session.
  `ViewSalesOrderPage.jsx` was read for T192's guardrail check only, not edited.)*
- [X] T196 Confirm `SalesOrderOverviewPage.jsx` and `ViewSalesOrderPage.jsx` still load without errors
  and are unaffected by this update (neither imports or calls `computeProgress()`) (depends on T191).
  *(Verified: `grep -rn "computeProgress" src/` returns only `MapFilePage.jsx`'s own definition and
  call site — no other file imports or calls it. `npm run build` produced clean
  `SalesOrderOverviewPage.*.js` (5.07 kB) and `ViewSalesOrderPage.*.js` (16.88 kB) chunks with no
  errors.)*

**Checkpoint**: All Update 11 quickstart.md checks pass — Map File's progress figures are internally
consistent and match View's, with zero regression to any prior update.

---

## Update 11 Dependencies

### Phase Dependencies

- **Phase 35**: No dependency on Phases 1-34 completion beyond `computeProgress()`/`missingRequired`
  already existing (Update 7). T191 has no code dependency (single-file edit); T192 is a verification-
  only task, can run any time after T191 for context.
- **Phase 36 (Polish)**: Depends on Phase 35 (T191-T192) being complete.

### Parallel Opportunities

- T192, T193, T194 are independent verification passes and can run in parallel once T191 is done.

### Implementation Strategy

1. Complete Phase 35 (the one-line `computeProgress()` fix) — verify via the Independent Test before
   moving on.
2. Complete Phase 36 (polish/validation) — full quickstart.md "Update 11" re-pass.
