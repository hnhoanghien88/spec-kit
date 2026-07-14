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
