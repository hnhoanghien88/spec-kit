---

description: "Task list for feature 012-eutr-purchase-orders"

---

# Tasks: EUTR Purchase Orders

**Input**: Design documents from `/specs/012-eutr-purchase-orders/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md (all present)

**Tests**: Not requested in the spec — no test tasks generated (matches this codebase's existing
practice for sibling EUTR features 003/004/005, which also ship without an automated test suite;
validation is via `quickstart.md`).

**Organization**: Tasks are grouped by user story (US1/US2/US3, priorities from spec.md) so each can
be implemented and demoed independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an incomplete task)
- **[Story]**: Maps the task to spec.md's US1/US2/US3
- File paths are exact, repo-relative from `e:\Working\Eutr`

## Path Conventions

Existing web monorepo (see plan.md): `compliance-client/src/...` (frontend), `compliance-sys-api/src/...` (backend). No new project, no new `application/usecases/*` files — every use case this feature needs already exists and is imported unchanged (research.md Decisions 1-5).

---

## Phase 1: Setup

**Purpose**: Create the new frontend feature folder with real (but minimal) page files so Phase 2's routing tasks have a concrete import target.

- [X] T001 [P] Create `compliance-client/src/presentation/pages/eutr-purchase-orders/PurchaseOrderOverviewPage.jsx` — minimal default-export component (MUI `Card`/`CardContent` shell, no data logic yet), mirroring the top of `eutr-sales-orders/SalesOrderOverviewPage.jsx`'s imports/structure.
- [X] T002 [P] Create `compliance-client/src/presentation/pages/eutr-purchase-orders/PurchaseOrderViewPage.jsx` — minimal default-export component (MUI `Card`/`CardContent` shell, no data logic yet), mirroring the top of `eutr-sales-orders/MapFilePage.jsx`'s imports/structure.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Make both new screens reachable in-app. **Both P1 user stories (US1, US2) require this to demo**, even though each story's own logic is otherwise independent.

**⚠️ CRITICAL**: Complete before starting Phase 3/4 UI work that needs to be viewed in the browser (the components themselves can be edited beforehand, but won't be navigable until this phase lands).

- [X] T003 Register the Overview screen in `compliance-client/src/app/routes/RouteResolver.jsx`: add `const PurchaseOrderOverviewPage = Loadable(lazy(() => import('@presentation/pages/eutr-purchase-orders/PurchaseOrderOverviewPage')));` alongside the other `Loadable(lazy(...))` declarations, and add `'eutr-purchase-orders': <PurchaseOrderOverviewPage />` to the `codeToComponent` map (sibling to the existing `'eutr-sales-orders'` entry). Depends on: T001.
- [X] T004 Register the detail screen in `compliance-client/src/app/routes/groups/MainRoutes.jsx`: add a `Loadable(lazy(() => import('@presentation/pages/eutr-purchase-orders/PurchaseOrderViewPage')))` declaration near the existing `MapFilePage`/`ViewSalesOrderPage` ones, and add `{ path: '/eutr/purchase-orders/:purchId/view', element: <PurchaseOrderViewPage /> }` to the route children array, right next to the existing `/eutr/sales-orders/:salesId/map-file` and `/eutr/sales-orders/:salesId/view` entries (lines ~104-110). Depends on: T002.
- [X] T005 [P] Add a static menu entry in `compliance-client/src/presentation/menu-items/ComplianceSystem.jsx`: a new child item under the "EUTR system" group — `code: 'eutr-purchase-orders'`, `title: 'Purchase orders'`, `type: 'item'`, `url: '/eutr/purchase-orders'`, same `icon`/`breadcrumbs: true` shape as the existing `'eutr-sales-orders'` sibling entry (id 24). (Used id 28, the next free id in this file.)

**Checkpoint**: Both new routes resolve to real (if empty) pages once an operator also seeds the corresponding `userMenu`/`canAccessMenu('eutr-purchase-orders')` DB rows (research.md Decision 8 — an operational step outside this task list, already called out in `quickstart.md` Prerequisite #4). User story implementation can now proceed.

---

## Phase 3: User Story 1 - Xem danh sách EUTR Purchase Orders (Priority: P1) 🎯 MVP

**Goal**: The Overview table shows real Purch id / Vendor code / Vendor name / Template / Progress data for every Purchase Order, with an Action column to open the detail screen.

**Independent Test**: Open the Overview screen; confirm all 6 columns render real data (not mock), including a Purchase Order with a Template and partial document coverage (Progress shows the correct completed/total/%) and one without a Template (Progress/Template show a clear empty state, not `0%`).

### Implementation for User Story 1

- [X] T006 [US1] In `compliance-client/src/presentation/pages/eutr-purchase-orders/PurchaseOrderOverviewPage.jsx`, implement the paged Purchase Order fetch using the existing `GetReferenceDataUseCase` (`repositories.dynamics`, `refType = 15`) and render the base MUI `Table`/`TableHead`/`TableBody`/`TablePagination` with columns Purch id (`Code`), Vendor code (`OrderAccount`), Vendor name (placeholder until T007), Template (`EutrTemplate`, placeholder until T010), Progress (placeholder until T010), Action.
- [X] T007 [US1] In the same file, add a batched Vendor-name resolution step: after each page fetch, collect the distinct `OrderAccount` values present, call `GetReferenceDataUseCase` with `refType = 14` using one `{ column: 'Code', operator: 'eq', value: orderAccount }` filter entry per distinct code (OR-joined server-side, matching the whitelist technique `SalesOrderOverviewPage.jsx` already uses — see research.md Decision 2), and merge the resolved `Name` onto each row as Vendor name (blank when unmatched, FR-003). Depends on: T006.
- [X] T008 [US1] In the same file, add a batched Template-steps fetch: collect the distinct non-blank `EutrTemplate` codes on the current page and call `GetEutrTemplatesByCodesUseCase` (`repositories.eutrTemplates`) once per page to get each Template's full step-detail tree. Depends on: T006.
- [X] T009 [US1] In the same file, add a batched Documents fetch: call `GetEutrDocumentsPoReferencesUseCase` (`repositories.eutrDocuments`) once per page with the page's Purch id list, to get each Purchase Order's recorded documents/step mappings. Depends on: T006.
- [X] T010 [US1] In the same file, compute the Progress column per row via `computeProgress()` imported from `@presentation/pages/eutr-sales-orders/utils/progressUtils` (Required steps only, `AUTO_SOURCES`-excluded — reused unchanged, research.md Decision 5), using that row's own Template details (T008) and its own file mappings (T009); render the real Template name; render a distinct "no Template" state when `EutrTemplate` is blank or unmatched (FR-004/FR-006) and a distinct "no Required steps" state when total is 0 (FR-007), never a bare `0%`. Depends on: T007, T008, T009.
- [X] T011 [US1] In the same file, add the Action column's **View** `IconButton`, navigating to `` `/eutr/purchase-orders/${row.purchId}/view` `` on click (FR-012). Depends on: T006.
- [X] T012 [US1] In the same file, add loading/error state for the page-level fetch (network/ERP failure, FR edge case) and a clear "No data" empty state when the page has zero rows. Depends on: T006.

**Checkpoint**: User Story 1 is fully functional and independently testable/demoable — the list renders live data end to end.

---

## Phase 4: User Story 2 - Xem và quản lý tài liệu compliance của một Purchase Order (Priority: P1)

**Goal**: Clicking **View** opens `/eutr/purchase-orders/{purchId}/view`, showing that Purchase Order's own header info, its Template's step tree, its recorded documents, and working Upload/Edit/View actions — with no PO-selection step and no Selected-POs table.

**Independent Test**: From the Overview list, click View on a Purchase Order with a Template and partial document coverage; confirm the header shows Purch id/Vendor code/Vendor name (not Sales ID/Customer), the tree shows the correct missing/mapped steps, and uploading a document for a missing step updates the screen immediately without a reload.

### Implementation for User Story 2

- [X] T013 [US2] In `compliance-client/src/presentation/pages/eutr-purchase-orders/PurchaseOrderViewPage.jsx`, implement the existence check + header: read `purchId` from the route, fetch it via `GetReferenceDataUseCase` (`refType = 15`, filter `{ column: 'Code', operator: 'eq', value: purchId }`); on no match render the "Purchase Order không tồn tại" error state and stop (FR-013/FR-014); on match, resolve Vendor name via the same `refType = 14` lookup pattern as T007, and render the Purch id / Vendor code / Vendor name header (FR-015) in place of Map File's Sales ID/Customer header.
- [X] T014 [US2] In the same file, build the template step tree: resolve this Purchase Order's `EutrTemplate` value via `GetEutrTemplatesByCodesUseCase` (single-code call) and build the tree with `flatToTree` from `@presentation/pages/eutr-sales-orders/utils/treeUtils`, cloning `MapFilePage.jsx`'s Step 2 tree-building logic; render a "chưa có Template" empty state (not an empty-looking tree) when `EutrTemplate` is blank or unmatched (FR-016/FR-019 — no Step 1, no Selected-POs table anywhere on this screen). Depends on: T013.
- [X] T015 [US2] In the same file, implement AVAILABLE FILES: call `GetEutrDocumentsPoReferencesUseCase` for this single `purchId`, render each returned document with its mapped step, and mark each tree node Mapped/Missing by matching document `stepIds` against that node's `stepId` (FR-017/FR-020), cloning `MapFilePage.jsx`'s Step 2 AVAILABLE FILES rendering. Depends on: T014.
- [X] T016 [US2] In the same file, render a Progress indicator for this Purchase Order using the same `computeProgress()` call as T010 (single Template, this PO's own file mappings), matching `MapFilePage.jsx`'s existing `data-marker="progress-bar"` element, for SC-002 parity with the Overview row. Depends on: T014, T015.
- [X] T017 [US2] In the same file, wire the **Upload** action to `EutrDocumentsFormDialog` (Add mode) imported from `@presentation/pages/eutr-documents/components/EutrDocumentsFormDialog` (reusing `004-eutr-documents`'s existing validation/upload flow unchanged — FR-021); on success, refetch T015's AVAILABLE FILES and T016's Progress/tree status immediately (FR-023). Depends on: T015.
- [X] T018 [US2] In the same file, wire each document's **Edit** `IconButton` to the same `EutrDocumentsFormDialog` (Edit mode, FR-022); on success, refetch as in T017 (FR-023). Depends on: T015.
- [X] T019 [US2] [P] In the same file, wire each document's **View** action to `EutrFileViewerDialog` imported from `@presentation/pages/eutr-documents/components/EutrFileViewerDialog`, matching `MapFilePage.jsx`'s existing usage. Depends on: T015.
- [X] T020 [US2] Review `PurchaseOrderViewPage.jsx` end to end and confirm/remove any leftover "Step 1 — Choose Purchase Order" markup or "Selected POs" table if either was carried over while cloning `MapFilePage.jsx` (FR-016/FR-017) — this screen must render neither. Depends on: T013-T019. (Verified: page has no Accordion/Step-1 markup and no Selected-POs table — never carried over, written directly as the single-template layout described in the plan.)

**Checkpoint**: User Stories 1 AND 2 both work independently — the full Overview → View flow is usable end to end.

---

## Phase 5: User Story 3 - Tìm kiếm Purchase Order theo Purch Id hoặc Vendor (Priority: P2)

**Goal**: A single search box on the Overview screen filters by Purch id, Vendor code, or Vendor name.

**Independent Test**: Type a known Purch id — list narrows to that row. Type a substring of a known Vendor code — list still narrows correctly (this specifically exercises T021's backend change). Type a non-matching keyword — "No data" appears, not an error.

### Implementation for User Story 3

- [X] T021 [US3] In `compliance-sys-api/src/ComplianceSys.Application/Services/ComplDynamicsService.cs`, extend `BuildFilterString`'s column-bucketing `GroupBy` switch with one additional reserved bucket — a `"vendorcode"` column label that resolves to `OrderAccount` **only when `mapping.Entity == "RSVNEutrPurchOrders"`** — and fold it into the same OR-joined `searchFilters` list the existing `code`/`name` buckets already build (exact diff in `specs/012-eutr-purchase-orders/contracts/dynamics-reference-purchase-orders.md`, research.md Decision 6). No other `refType` changes behavior. (Backend builds clean — `dotnet build` on `ComplianceSys.Application` succeeded with 0 errors.)
- [X] T022 [US3] In `compliance-client/src/presentation/pages/eutr-purchase-orders/PurchaseOrderOverviewPage.jsx`, add a debounced search `TextField` that sends `{ column: 'Code', operator: 'like', value }` and `{ column: 'VendorCode', operator: 'like', value }` filters to T006's fetch call and resets to page 0 on each new keyword (FR-009), mirroring `SalesOrderOverviewPage.jsx`'s `buildSearchFilters`/`debounce` pattern. Depends on: T006, T021.
- [X] T023 [US3] In the same file, confirm/add the "No data" empty state specifically covers a non-matching search keyword (FR-010) — distinct message from T012's page-level error state. Depends on: T022.

**Checkpoint**: All three user stories are independently functional; the Overview screen's full spec scope (list + search) plus the View screen are complete.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [ ] T024 [P] Run the full `specs/012-eutr-purchase-orders/quickstart.md` validation checklist end to end against a real environment (both screens, all edge-case states). **NOT run by this implementation pass** — requires a live backend + real D365/SharePoint data, unavailable in this working session. Do this before shipping.
- [X] T025 [P] Review `compliance-client/src/presentation/pages/eutr-purchase-orders/PurchaseOrderOverviewPage.jsx` and `PurchaseOrderViewPage.jsx` for Vietnamese code comments on non-obvious logic (batched Vendor lookup, per-row Progress scoping, existence-check flow), per Constitution Principle IV.
- [ ] T026 Cross-check SC-002: for at least one Purchase Order, verify its Overview-row Progress figure exactly matches its own View-screen Progress figure at the same data point. **NOT run by this implementation pass** — same reason as T024 (needs live data); the two screens share the exact same `computeProgress`/`buildTemplateComputations` call shape by construction (T010/T016), so this is expected to hold, but must still be confirmed against real data before shipping.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately.
- **Foundational (Phase 2)**: Depends on Phase 1 (T001/T002 create the files T003/T004 import). Blocks in-browser demoing of Phase 3/4, though those phases' code can be written in parallel with Phase 2.
- **User Story 1 (Phase 3)**: Depends on Phase 2 for routing; otherwise self-contained.
- **User Story 2 (Phase 4)**: Depends on Phase 2 for routing; otherwise self-contained (does not depend on Phase 3's code, only reuses the same `computeProgress` util).
- **User Story 3 (Phase 5)**: Depends on Phase 3 (T006's fetch call is what T022 adds filters to) and includes its own backend task (T021).
- **Polish (Phase 6)**: Depends on Phases 3-5 being complete.

### Parallel Opportunities

- T001/T002 (Setup) — different files, run together.
- T005 (menu entry) can run in parallel with T003/T004 (different files).
- T003 and T004 touch different files (`RouteResolver.jsx` vs `MainRoutes.jsx`) and can run in parallel once T001/T002 exist.
- Phase 3 (US1) and Phase 4 (US2) touch different files (`PurchaseOrderOverviewPage.jsx` vs `PurchaseOrderViewPage.jsx`) and can be worked on in parallel by two developers once Phase 2 is done — Phase 4 does not depend on Phase 3.
- T021 (backend) can run in parallel with any frontend task — different codebase area entirely.
- T019 is marked [P] within Phase 4 only in the sense that it's independent MUI wiring inside the same already-open file; if another developer is mid-edit on the same file for T017/T018, treat as sequential in practice.
- T024/T025 (Polish) — independent, run together.

---

## Parallel Example: Setup + Foundational

```text
# Phase 1, together:
Task: "Create PurchaseOrderOverviewPage.jsx placeholder"
Task: "Create PurchaseOrderViewPage.jsx placeholder"

# Phase 2, together (after Phase 1):
Task: "Wire RouteResolver.jsx codeToComponent entry"
Task: "Wire MainRoutes.jsx nested detail route"
Task: "Add ComplianceSystem.jsx menu entry"
```

## Parallel Example: US1 + US2 (two developers)

```text
# After Phase 2 checkpoint, in parallel:
Developer A: T006 → T007 → T008 → T009 → T010 → T011 → T012  (PurchaseOrderOverviewPage.jsx)
Developer B: T013 → T014 → T015 → T016 → T017 → T018 → T019 → T020  (PurchaseOrderViewPage.jsx)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup.
2. Complete Phase 2: Foundational (routing/menu).
3. Complete Phase 3: User Story 1.
4. **STOP and VALIDATE**: run the Overview-screen portion of `quickstart.md` independently.
5. Demo the list screen (View button can exist and navigate even before Phase 4 lands — the target route just won't be fully built yet).

### Incremental Delivery

1. Setup + Foundational → both routes resolve to placeholder pages.
2. Add US1 → Overview list fully real → demo.
3. Add US2 → View screen fully functional → demo full Overview → View flow.
4. Add US3 → search → demo complete feature scope.
5. Polish → final cross-checks against `quickstart.md`/SC-002.

### Parallel Team Strategy

1. Team completes Setup + Foundational together (small, ~3 tasks).
2. Once Foundational is done: Developer A takes US1 (Phase 3), Developer B takes US2 (Phase 4) — independent files, no conflict.
3. US3 (Phase 5) starts once US1's `PurchaseOrderOverviewPage.jsx` fetch (T006) exists, and includes the one backend task (T021) any developer can pick up independently at any time.

---

## Notes

- No new `application/usecases/*`, `domain/*`, or `infrastructure/*` files are needed anywhere in this
  feature — every use case/repository call is an existing, unchanged import (research.md Decisions
  1-5; plan.md Project Structure). This is a deliberate consequence of Constitution Principle III,
  not an oversight — do not add wrapper use-case classes "for consistency."
- T021 is the **only** planned backend code change in this feature. One additional, unplanned backend
  fix (T027, added post-implementation) was required — see below.
- Commit after each task or logical group, per repo convention.
- Stop at each phase checkpoint to validate that story independently before moving on.

---

## Post-implementation fix (found via live user report, not in original task breakdown)

- [X] T027 Fix `GetManyByCodesWithDetailsAsync`'s header SQL in
  `compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/EutrTemplatesRepository.cs`
  (backing `POST /api/eutr-templates/by-codes`, consumed by T008/T014): it filtered only
  `IsDeleted = 0`, missing the `IsHide = 0` filter every other read on `eutr_templates` already
  applies. Root cause: `RequestChangeAsync` (Approved → Draft) inserts a new row with the **same**
  `Code` and sets the old row's `IsHide = 1` (kept, not deleted, as an immutable history record) —
  so for any Code that has ever gone through "Request change," `by-codes` returned **both** the
  superseded row and the current one, with no `ORDER BY`, and the frontend's `[0]` pick could
  non-deterministically land on the stale version. Symptom reported by user: a step
  ("Import Documentation Package") showing `Required` on `PurchaseOrderViewPage.jsx` while the
  Templates screen (which correctly filters `IsHide = 0`) showed it as `Optional` for what looked
  like the same template. Fix: add `AND t.IsHide = 0` to the header query, matching every other
  query on this table. This also fixes the same latent risk in `005-eutr-sales-orders`'
  `SalesOrderOverviewPage.jsx` Progress column, which calls the same endpoint — a correctness fix,
  not a scope change to that feature. `dotnet build` on `ComplianceSys.Infrastructure` succeeded
  with 0 errors after the change.

- [X] T028 Fix AVAILABLE FILES/Progress in both `PurchaseOrderViewPage.jsx` and
  `PurchaseOrderOverviewPage.jsx`: they only looked up documents by Purch id
  (`GetEutrDocumentsPoReferencesUseCase.execute([purchId, ...])`), but `eutr_references.RefValue`
  is not always the Purch id — for a step whose Type is "Vendor" (e.g. "General agreement",
  Required), the document is registered with `RefValue = Vendor code` (`OrderAccount`), not the
  Purch id. `list-po-references`'s SQL matches generically on `r.RefValue IN @PoCodes` regardless
  of Type, so it *would* have found the document — but neither page ever included the PO's own
  Vendor code in that call, and `buildTemplateComputations`'s `purchIdToTemplateCode` map (which
  scopes which files belong to which template) only had an entry for the Purch id, so even a
  correctly-fetched Vendor-code-keyed file would have been filtered back out. Fix, in both files:
  (1) fetch `list-po-references` with the Purch id **and** the PO's Vendor code together (page-wide
  union of both, deduplicated, for the Overview batch call); (2) add the Vendor code as a second key
  in `purchIdToTemplateCode`, mapped to the same template code as the Purch id. Symptom reported by
  user: a "General agreement" (Required, Type=Vendor) document existed with `RefValue = CC01253`
  (the PO's own Vendor code) but never appeared in AVAILABLE FILES / never counted toward Progress
  for that PO. Verified via `eslint` (clean) and `vite build` (succeeds) after the change — full
  confirmation needs a live environment (same constraint as T024/T026).

- [X] T029 Backport the T028 fix to `005-eutr-sales-orders`' Map File (`MapFilePage.jsx`) and View
  (`ViewSalesOrderPage.jsx`) screens, per explicit user request. Both screens had the exact same two
  gaps as the purchase-orders pages before T028: (1) AVAILABLE FILES/Template Checklist only fetched
  `list-po-references` by the saved PurchId(s), never each PO's own Vendor code, so Type="Vendor"
  documents (`RefValue = OrderAccount`) never appeared; (2) `purchIdToTemplateCode` (used by the
  shared `buildTemplateComputations`, `utils/progressUtils.js`) only had PurchId keys, so even a
  correctly-fetched Vendor-code file would be filtered back out by template scoping.
  Unlike the purchase-orders pages (one PO, one template — no ambiguity possible), a Sales Order can
  have several PurchIds/Templates, so a Vendor code could in principle map to more than one distinct
  Template within the same Sales Order. To keep this a **non-invasive fix that does not change
  `buildTemplateComputations`'s existing contract** (which `SalesOrderOverviewPage.jsx`'s Progress
  column and zip-Download building also depend on, out of this request's stated scope), two new
  shared helpers were added to `utils/progressUtils.js` instead of inlining ad-hoc logic per screen:
  - `buildPurchIdToTemplateCodeMap(attachments, poByPurchId)` — builds the PurchId→TemplateCode map
    as before, and additionally adds a Vendor-code→TemplateCode entry **only when that Vendor code
    maps to exactly one distinct Template** in the given attachments (an ambiguous Vendor code —
    used by POs on two different Templates — falls back to the old PurchId-only behavior for those
    POs, avoiding misattributing a Vendor-level document to the wrong Template).
  - `buildReferenceCodes(purchIds, poByPurchId)` — the PurchId list widened with each PO's own Vendor
    code, deduplicated, for the `list-po-references` call itself.

  `MapFilePage.jsx`: `purchIdToTemplateCode` now built via `buildPurchIdToTemplateCodeMap(purchaseAttachments, poByPurchId)`
  (`poByPurchId` from the existing `poList` state); `loadAvailableFiles` now widens its input PurchIds
  via `buildReferenceCodes` before calling `list-po-references`.

  `ViewSalesOrderPage.jsx`: same two changes, using its existing `allPos` state (equivalent to
  `MapFilePage.jsx`'s `poList`) for the Vendor-code lookup. Its Download button and "All" chip/tree
  needed **no separate change** — both already derive from the page's `templateComputations`
  (built from the now-fixed `purchIdToTemplateCode`), so the fix propagates through automatically
  (verified by reading `buildDownloadFolders`/`stepIdToFileIds`/`allChipFiles`, all `useMemo`s keyed
  on `templateComputations`).

  `SalesOrderOverviewPage.jsx` was deliberately **not** touched at this step — out of that request's
  explicit scope ("màn hình view và map file"); it had the same latent gap in its own
  `fetchProgressForRows`/`handleDownload` (built independently, not sharing state with the other two
  screens). Verified via `eslint` (only pre-existing, unrelated `no-unused-vars` errors remain —
  confirmed identical before/after via `git stash`) and `vite build` (succeeds, 0 errors) after the
  change.

- [X] T030 Follow-up user request: checked every Download function in both `005-eutr-sales-orders`
  and `012-eutr-purchase-orders` for the same Vendor-code gap.
  - `012-eutr-purchase-orders`: **no Download function exists** in either
    `PurchaseOrderOverviewPage.jsx` or `PurchaseOrderViewPage.jsx` (confirmed by grep — zero matches
    for "download"/"Download" anywhere in `presentation/pages/eutr-purchase-orders/`), matching the
    spec's own Assumption that Download/zip-export was explicitly out of scope for this feature.
    Nothing to check or fix here.
  - `005-eutr-sales-orders` has two Download entry points:
    - `ViewSalesOrderPage.jsx`'s `handleDownload`/`buildDownloadFolders` — **already correct**, no
      change needed. Confirmed by reading the call chain: it builds its zip folders from the page's
      own `templateComputations` (and `stepIdToFileIds`/`allChipFiles` for the "All" folder), all of
      which are `useMemo`s derived from the page-level `purchIdToTemplateCode` that T029 already
      fixed — the fix propagates through automatically.
    - `SalesOrderOverviewPage.jsx`'s row-level `handleDownload` (the Download icon per row on the
      Overview list) — **had the same bug**, fixed now. Unlike `ViewSalesOrderPage.jsx`, this
      function builds its own `purchIdToTemplateCode` and its own `list-po-references` call
      independently on every click, and (unlike `MapFilePage.jsx`/`ViewSalesOrderPage.jsx`) this
      screen never loads a PO display-fields list (`refType=16`) at all — it only knows
      `{purchId, templateCode}` pairs from `eutr_purchase_attachments`, which has no Vendor-code
      column. Fix: added one more parallel fetch inside `handleDownload` — `refType=16`
      (`RSVNEutrSalesOrderPurchases`) filtered by this Sales Order's `InterCompanyOriginalSalesId`,
      to resolve each `purchId`'s `orderAccount` — then rebuilt `purchIdToTemplateCode` via
      `buildPurchIdToTemplateCodeMap` and widened both the `list-po-references` call and
      `filesForSalesOrder` to include each PO's Vendor code, same pattern as T029. This is an
      additional network round-trip only when the user actually clicks Download for a row (not on
      every page load), consistent with this button's existing on-demand-per-row design (spec 005
      Update 13, FR-088).
  - Explicitly **not** changed in this pass: `SalesOrderOverviewPage.jsx`'s `fetchProgressForRows`
    (the Progress **column**, as opposed to the Download **button**) still has the identical
    unfixed gap — it was flagged as out-of-scope after T029 and the user's follow-up request named
    "hàm download" specifically, not the Progress column. Flagged again here for visibility; fix on
    request using the exact same pattern (T029/T030).
  - Verified via `eslint` (clean) and `vite build` (succeeds, 0 errors) after the change.

- [X] T031 Follow-up user request: checked `011-eutr-synchronize-data`'s "purchase missing" check
  (`EutrSynchronizeDataService.SendPurchaseMissingAlertAsync`, `test-purchase-missing`) for the same
  document-loading gap. **Confirmed present, fixed.**
  - Root cause, identical class of bug: step 5 of the service only called
    `_eutrReferencesRepository.GetDocumentsByPoCodesAsync(purchIdsNeedingStepCheck, ct)` with the
    list of **PurchIds** needing a step check — never each PO's own Vendor code (`OrderAccount`,
    already available on the same `purchaseOrders` list, refType=15). A document recorded against a
    step whose Type is "Vendor" has `RefValue = Vendor code`, not the PurchId, so `coveredSteps`
    (built from the returned `(PoCode, StepId)` pairs) never contained an entry keyed by that PO's
    own PurchId for such a step — every Purchase Order with a Vendor-type Required step was
    unconditionally flagged `"{n} - {step name} - Missing"` for that step and included in the alert
    email/Excel report, **even when the Vendor-level document actually existed**. Given this check
    runs unattended over the entire ERP Purchase Order population (3,000+ rows) and emails the
    responsible Alert group automatically, this was producing systematic false-positive "missing
    documentation" alerts for every Purchase Order using a Vendor-type step — a real-impact bug, not
    a cosmetic one.
  - Fix, in `EutrSynchronizeDataService.cs`: (1) alongside the existing `purchIdsNeedingStepCheck`
    list, also collect the distinct `OrderAccount` values of those same Purchase Orders
    (`vendorCodesNeedingStepCheck`), and pass the union of both
    (`referenceCodesNeedingStepCheck`) to `GetDocumentsByPoCodesAsync`; (2) when checking whether a
    step is covered for a given PO, test `coveredSteps.Contains((purchId, stepId))` **OR**
    `coveredSteps.Contains((vendorCode, stepId))` (`vendorCode` was already resolved earlier in the
    same loop iteration for the report's own VendorCode column — reused, not recomputed).
  - Verified: `dotnet build` on `ComplianceSys.Application` succeeded with 0 errors; the existing
    `EutrSynchronizeDataServiceTests.cs` suite (20 tests, mocks `GetDocumentsByPoCodesAsync` with
    `It.IsAny<IEnumerable<string>>()` rather than asserting a specific argument list, so the widened
    call is compatible) — all 20 pass unchanged (`dotnet test --filter
    FullyQualifiedName~EutrSynchronizeDataServiceTests`).
  - Not touched: User Story 1 (`SyncSalesOrderTemplatesAsync`, the `test-so-template-sync` action)
    does not read `eutr_references`/documents at all — no such gap exists there.
