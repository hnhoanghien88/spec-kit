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
