# Specification Quality Checklist: EUTR Sales Orders Management

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-07-14
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

- Spec references the existing shared reference lookup mechanism and its `reference type` parameter
  because this is how prior EUTR specs in this repo document data-source decisions (see
  `specs/004-eutr-documents/spec.md`) — these are treated as business-facing integration facts
  (which existing capability supplies the data), not internal implementation detail like code
  structure or language choice.
- FR-009 documents that reference type 11 is not yet wired to return the needed fields; this is a
  known gap to close during planning, not a [NEEDS CLARIFICATION] marker, since the required
  behavior (must return Sales ID/Customer/Customer name/Delivery date) is unambiguous.
- **2026-07-16 (Update 1)**: Re-validated after replacing the Template column's fixed demo value
  (old FR-007) with real data sourced from `eutr_purchase_attachments` (new FR-007/FR-007a/FR-007b).
  Naming the source table/columns (`SalesId`, `PurchId`, `TemplateCode`) is treated the same as the
  existing `reference type` references above — a business-facing data-source fact, not an
  implementation detail — consistent with this checklist's established precedent. No new
  [NEEDS CLARIFICATION] markers introduced: display-as-name-not-code and multi-value-as-a-list-in-
  one-cell are documented as Assumptions (reasonable defaults consistent with existing UI patterns
  in this codebase), not open questions.
- **2026-07-16 (Update 2)**: Re-validated after adding User Story 4 and FR-014..FR-030, covering the
  **Map File** screen (`MapFilePage`) — Sales Order existence check/header sourced from reference
  type = 11 (same as Overview), Step 1 PO list sourced from reference type = 16 filtered by
  `InterCompanyOriginalSalesId`, Step 1 PO selection now **writes** to `eutr_purchase_attachments`
  (previously read-only per Update 1), Step 2 template tree/AVAILABLE FILES sourced from
  `eutr_purchase_attachments`/`eutr_references`, and Upload/Save on Step 2 explicitly staying
  display-only (no-op) for this update. Naming these tables/columns/reference types follows the same
  established precedent as Update 1 (business-facing data-source fact, not implementation detail).
  No new [NEEDS CLARIFICATION] markers introduced — ambiguous points (exact PO column mapping for
  Step 1, "Save PO Mapping" replace-semantics, template-per-PO-not-user-chosen) are resolved as
  Assumptions with reasonable defaults grounded in the existing D365 entity/table shapes, deferred
  implementation-column-mapping specifics explicitly pushed to the planning phase where they belong.
- **2026-07-20 (Update 3)**: Re-validated after adding FR-031..FR-033 and related acceptance
  scenarios/edge cases — Step 1 keeps not-yet-attached POs selectable (checkbox enabled) as long as
  D365 supplies a template value, Save PO Mapping additively records newly selected POs while keeping
  the existing replace-to-match-UI semantics from Update 2 (FR-021), and the Back button now
  navigates to EUTR Sales Orders. The one open question (what `TemplateCode` to persist for newly
  selected POs) was resolved directly with the requester before drafting — confirmed to reuse the
  existing `eutrTemplate` field from the Step 1 PO data source (reference type = 16), the same source
  already used by FR-020 — so no [NEEDS CLARIFICATION] marker was needed in the spec text.
- **2026-07-20 (Update 4)**: Re-validated after adding User Story 5 and FR-034..FR-046, covering the
  **View Sales Order** screen (`ViewSalesOrderPage`) — existence check/header sourced from reference
  type = 11 (same as Overview/Map File), the "Purchase Orders đã chọn" list and Template Checklist
  reuse the same real data sources already wired for Map File (`eutr_purchase_attachments`,
  reference type = 16, `eutr_references`), the screen is explicitly read-only (no PO
  select/map/unmap/upload), Edit/Map File navigates to Map File, Download stays a no-op, and
  Validation Summary is recomputed from real step data (selected POs, steps with/without files). No
  new [NEEDS CLARIFICATION] markers introduced: this update closely mirrors the already-validated
  Update 2/3 pattern for a sibling screen reading the same tables, so the same precedent applies —
  the one previously-mock-only condition ("File không hết hạn") that has no real data source yet is
  resolved as a documented Assumption (dropped until an expiry data source exists), not an open
  question.
- **2026-07-27 (Update 5)**: Re-validated after adding FR-047..FR-052 and related acceptance
  scenarios/edge cases — the Map File Step 2 template-tree toolbar (`data-marker=
  "template-tree-toolbar"`) keeps showing the selected/saved templates and gains a new click-to-reload
  interaction for `templatesData`; AVAILABLE FILES' three previously-static labels ("Map status",
  "File type", "PO value") are replaced with dynamic values sourced from `eutr_references`
  (`StepId` match against the current template tree for Map status, `RefType` — via
  `eutr_reference_types` — for File type, `RefValue` for PO value). Naming these
  tables/columns follows the same established precedent as Updates 1-4 (business-facing data-source
  fact, not implementation detail). No new [NEEDS CLARIFICATION] markers introduced: the two points
  with more than one reasonable reading — whether clicking one template chip reloads only that
  template or the whole `templatesData` list, and how to display File type/PO value when a document
  has multiple `eutr_references` rows in the same PO context — are resolved as documented Assumptions
  (reload the whole list, since Step 2 always shows every template tree together; use the first
  matching reference row, since `RefType`/`RefValue` are expected to stay consistent per
  document/PO pair in current business practice) rather than open questions.
- **2026-07-27 (Update 6)**: Re-validated after replacing FR-029/FR-030 (previously demo/no-op) and
  adding FR-030a/FR-030b, covering the Map File Step 2 Upload and per-file Edit actions now reusing
  the existing Add/Edit document popups from `004-eutr-documents` in full (same Type/Step/Value-chip/
  Valid-from-to fields and validation rules, same real-write behavior to `eutr_documents`/
  `eutr_references`), plus a refresh requirement so AVAILABLE FILES/Map status reflect newly
  written data without a full page reload. Referencing `004-eutr-documents`'s own FR ranges by number
  follows the same established precedent as prior updates (naming an existing capability being reused,
  not an implementation detail). No new [NEEDS CLARIFICATION] markers introduced: the two scope
  questions with more than one reasonable reading — whether Upload should auto-lock Type/Value/Step to
  the PO/step currently selected in Map File, and whether Edit should fully replace the old local
  Source/PO mapping dialog or run alongside it — were resolved directly with the requester before
  drafting (full unrestricted Add popup; full replacement of the old Edit dialog), so both are recorded
  as explicit FR/Assumption text rather than open markers.
- **2026-07-27 (Update 7)**: Re-validated after adding FR-053..FR-057 and related acceptance
  scenarios/edge cases/success criteria — fixes a real gap confirmed by reading `MapFilePage.jsx`:
  Map status/tree "already has a file" indicators and the AVAILABLE FILES list currently match/merge
  across **all** saved templates' steps and **all** selected POs' documents, without checking that a
  document's own PO actually belongs (via `eutr_purchase_attachments`) to the template being evaluated
  — since different templates can reuse the same `StepId` from the shared `eutr_steps` table, this can
  mark a document "Mapped" against an unrelated template's node. This update requires both PO-correctness
  and Step-correctness before something counts as mapped, and scopes AVAILABLE FILES to the
  currently-viewed template's own PO(s). No new [NEEDS CLARIFICATION] markers introduced: whether the
  header's aggregate progress should narrow to only the currently-viewed template or stay
  Sales-Order-wide was resolved as an Assumption (stays Sales-Order-wide/aggregate across all templates,
  each template's own contribution now computed with the corrected PO/Template scoping before summing)
  since narrowing it would silently hide missing-document counts for templates not currently displayed.
- **2026-07-27 (Update 8)**: Re-validated after adding FR-058..FR-063 and related acceptance
  scenarios/edge cases/success criteria — extends the View Sales Order screen (`ViewSalesOrderPage`)
  to match the Map File template-tree toolbar behavior confirmed by reading both `MapFilePage.jsx` and
  `ViewSalesOrderPage.jsx`: View's toolbar (`data-marker="template-tree-toolbar"`) currently renders
  hardcoded demo chip labels with no click handler, and its Template Checklist stacks every saved
  template's tree at once with "has document" status matched by step name across **all** templates
  combined (the same cross-template mismatch class already fixed for Map File in Update 7). This
  update makes View's toolbar chips real (sourced from `templatesData`), adds click-to-select-one-
  template display switching defaulting to the first template, and applies the same PO/Template
  scoping rule from Update 7 to View's "has document" status and aggregate progress calculation.
  Naming these tables/columns/reused-mechanism-from-Map-File follows the same established precedent as
  prior updates. No new [NEEDS CLARIFICATION] markers introduced: the one point with more than one
  reasonable reading — whether selecting a template in View's toolbar should also refetch PO/document
  data from the real source (like Map File's FR-048) — is resolved as a documented Assumption (no
  refetch needed; View is read-only with no concurrent edit happening on the same screen, so the data
  already loaded on page open is sufficient to switch which template is displayed).
- **2026-07-27 (Update 9)**: Re-validated after adding FR-064..FR-068 and related acceptance
  scenarios/edge cases/success criteria — adds a **View** button next to the existing Edit button on
  each document in Map File's AVAILABLE FILES list, opening a read-only file-content preview popup.
  Confirmed by codebase research that this reuses an existing mechanism end to end: `004-eutr-
  documents` already has a working "View" popup (`EutrFileViewerDialog`, wrapping the shared
  `FilePreviewer` component) on its own document grid, backed by an existing file-content-by-id
  endpoint, and Map File's own AVAILABLE FILES file objects already carry the `fileId` needed to call
  it — so this update is a pure reuse (Constitution Principle III), not a new preview mechanism.
  Naming the reused component/mechanism follows the same established precedent as prior updates
  (business-facing fact: which existing capability is being reused, not implementation detail). No
  new [NEEDS CLARIFICATION] markers introduced: the one point with more than one reasonable reading —
  exact button placement (left/right of Edit) and icon choice — is resolved as a documented Assumption
  (left to the technical design/plan phase; the only business requirement is "placed next to Edit,
  same control group per row").
- **2026-07-27 (Update 10)**: Re-validated after adding FR-069..FR-076 and related acceptance
  scenarios/edge cases/success criteria — replaces the View Sales Order screen's Download button
  no-op (FR-044/Update 4) with a real zip download: root folder/file named dynamically
  `{SalesId}-{CustomerCode}-{CustomerName}`, one subfolder per saved template (named with the
  template's real display name), each subfolder containing only that template's "Mapped" documents
  (per the existing PO/Template Map-status rule from Update 7, FR-055/FR-056). Three scope-defining
  ambiguities were resolved directly with the requester before drafting (per the "max 3 clarification
  markers, resolve directly when possible" rule) rather than left as open markers: (1) which documents
  populate each template subfolder — Mapped-only vs. all-documents-of-that-PO — resolved to Mapped-only,
  since that's the set already treated as "belonging to" a template's checklist elsewhere in this spec;
  (2) subfolder naming — real template name vs. a fixed "Template 01/02" order label — resolved to real
  template name, consistent with this spec's established display-name-not-code/order convention; (3)
  behavior when there's nothing to download — disable the button vs. always-clickable-with-an-error-
  message — resolved to always-clickable-with-an-error-message. All three are recorded as explicit
  FR/Assumption text (FR-072/FR-071/FR-074 and matching Assumptions bullets), not
  [NEEDS CLARIFICATION] markers. The exact archive mechanism (zip library, client- vs. server-side
  generation) is left to the plan phase as a documented Assumption, consistent with how this spec has
  always deferred implementation-mechanism choices.
- **2026-07-27 (Update 11, revised same session)**: The first draft of this update (see prior git
  history of this checklist/spec) misread the request as "broaden `progress.total`/`progress.completed`
  to include Optional steps too" — the requester corrected this immediately after: the count must stay
  **Required-only**, with "toàn bộ template" ("the whole template set") referring to the existing
  cross-template aggregation (Update 7/FR-057), not to including Optional steps. Re-validated after
  rewriting FR-077..FR-081 accordingly, following a full review (requested explicitly) of every
  variable in both `MapFilePage.jsx` and `ViewSalesOrderPage.jsx` that counts mapped/missing step
  status: `progress.total`/`progress.completed`/`missingRequired` (Map File) and `requiredDetails`/
  `mappedRequired`/`missingRequired`/`pct` (View). That review surfaced one real inconsistency:
  `computeProgress()` (Map File's `progress.total`/`progress.completed`) never excluded the legacy
  `AUTO_SOURCES` `takeFrom` values, while `missingRequired` (same screen) and all four View-screen
  variables already do — meaning `progress.total - progress.completed` would not always equal
  `missingRequired` if an unmapped Required step ever had an `AUTO_SOURCES` `takeFrom`. View's own
  `requiredDetails`/`mappedRequired`/`missingRequired`/`pct` were confirmed already correct (Required-
  only, `AUTO_SOURCES`-excluded, PO/Template-scoped per FR-061, aggregated across all saved templates)
  and needed no change. No new [NEEDS CLARIFICATION] markers introduced: whether to fix the
  `AUTO_SOURCES` inconsistency now or leave it, given it has no observable effect on today's real data
  (`eutr_template_details.takeFrom` is only ever "PO"/"Upload manual") — resolved as an explicit FR
  (FR-079) plus a documented Assumption explaining it's a forward-consistency fix, not a behavior change
  with current data, rather than left as an open question.
- **2026-07-27 (Update 12)**: Re-validated after replacing FR-008 (previously the fixed `DEMO_PROGRESS`
  demo value) and adding FR-082..FR-086 — the Overview screen's (`SalesOrderOverviewPage.jsx`) Progress
  column now computes real per-row progress by `salesId`, reusing byte-for-byte the same formula Map
  File already uses for its own `progress` variable (`computeProgress()` + the `templateComputations`
  summation confirmed in Update 7/11: Required-only, `AUTO_SOURCES`-excluded, PO/Template-paired
  "mapped" rule from FR-055/FR-056, aggregated across every saved template of that Sales ID) — not a new
  or independently-defined formula for Overview. Confirmed by reading both `SalesOrderOverviewPage.jsx`
  (currently the `DEMO_PROGRESS` constant, identical on every row) and `MapFilePage.jsx`'s `progress`
  useMemo before drafting. No new [NEEDS CLARIFICATION] markers introduced: the two points with more
  than one reasonable reading — what to show for a Sales ID with no saved template at all vs. one with
  saved templates but zero Required steps after excluding `AUTO_SOURCES`, and how to avoid N+1 calls when
  computing this for every visible row — are resolved as explicit FR/Assumption text (FR-083/FR-084 for
  the two distinct empty states; FR-085 plus an Assumption for batching the same way the Template column
  already does, exact API shape deferred to the plan phase) rather than left as open questions.
- **2026-07-27 (Update 13)**: Re-validated after adding FR-087..FR-092 and related acceptance
  scenarios/edge cases/success criteria — wires up the Overview screen's per-row Download button
  (`DownloadIcon`, currently no `onClick` at all — confirmed by reading `SalesOrderOverviewPage.jsx`)
  to trigger the exact same zip-download behavior already specified for View's Download button in
  Update 10 (FR-069..FR-076): same dynamic root name, same one-subfolder-per-template/Mapped-only-files
  structure, same "nothing to download" message instead of an empty zip. This is a pure reuse of an
  already-specified mechanism (Constitution Principle III), not a new download format. No new
  [NEEDS CLARIFICATION] markers introduced: the one point with more than one reasonable reading —
  whether the data needed to build the zip (per-template Mapped documents) should be preloaded in a
  batch for every visible row (like the Template/Progress columns) or loaded on-demand only for the row
  actually clicked — is resolved as an explicit FR (FR-088) plus a documented Assumption (on-demand per
  clicked row, since preloading it for every row on every page load would be wasted work whenever the
  user never clicks Download for most rows), rather than left open. Per-row loading/error state
  (independent per row, not a single table-wide state) is likewise resolved as explicit FR/Assumption
  text (FR-090/FR-091 and a matching Assumption) rather than left ambiguous.
- **2026-07-28 (Update 14)**: Re-validated after adding FR-093..FR-099 and related acceptance
  scenarios/edge cases/success criteria — fixes a reported bug: filtering Overview to "SO004957", then
  opening Map File or View and pressing Back, returns to Overview with the search box empty and the
  full unfiltered list. Confirmed by reading the actual source: `SalesOrderOverviewPage.jsx` keeps
  `search`/`page`/`pageSize` as plain local `useState` with no URL/sessionStorage sync, and its initial
  `useEffect` always fetches page 0 with an empty search string on every mount; `MapFilePage.jsx` and
  `ViewSalesOrderPage.jsx` both navigate their Back button to the fixed route `/eutr/sales-orders`
  (not browser-history back), so Overview always remounts from scratch and loses whatever
  search/page state it had. This update requires restoring the search keyword and page on
  Back-navigation from either screen (FR-094/FR-095), re-fetching live data rather than replaying a
  stale snapshot (FR-096), treating the in-app Back button and the browser/device Back button
  identically (FR-097), and explicitly documents View's previously-unspecified Back button (FR-093,
  confirmed present at `ViewSalesOrderPage.jsx:812-819`, mirroring Map File's FR-033). No new
  [NEEDS CLARIFICATION] markers introduced: the one point with more than one reasonable reading —
  whether navigating to Overview directly via the nav menu/breadcrumb (not via Back) should also keep
  a previous search — is resolved as an explicit FR/Assumption (FR-098: menu/breadcrumb entry always
  shows the default unfiltered, page-one list; restoration is scoped to the Back-navigation round trip
  only), matching the user's literal request (preserve search across Map File/View → Back, not across
  unrelated visits). The exact persistence mechanism (URL query params vs. sessionStorage) is left to
  the plan phase as a documented Assumption, noting this codebase already has both patterns available
  to reuse (`useSearchParams` in `compliance-master/index.jsx` and others; `sessionStorage` in
  `dashboard/index.jsx`/`search-result/index.jsx`) — consistent with how this spec has always deferred
  implementation-mechanism choices.
- **2026-07-28 (Update 15)**: Re-validated after adding FR-100..FR-106 and related acceptance
  scenarios/edge cases/success criteria — adds a new **AVAILABLE FILES** section to the View Sales
  Order screen's right-hand box (below the existing "Steps missing files" list), styled after Map
  File's AVAILABLE FILES list (Update 5/7: file name + Map status/File type/PO value/Step name chips)
  but without the Edit/Upload controls (View stays read-only per FR-042). Confirmed by reading
  `ViewSalesOrderPage.jsx`: the right sidebar's Validation Summary card currently only renders a
  "Steps missing files:" name-only list (no real document rows), while `MapFilePage.jsx`'s AVAILABLE
  FILES list and per-document View button (Update 9's `EutrFileViewerDialog` reuse) already exist and
  are reused here rather than re-specified. New interaction not previously present on either screen:
  clicking a step node in the Template Checklist tree narrows the new list to that step's (and its
  descendants') Mapped documents, and clicking any template chip in `template-tree-toolbar` clears
  that filter back to the full file set of the newly-active template — resolved as explicit FR-102/
  FR-104 rather than left ambiguous, since the requester described this exact toggle behavior. No new
  [NEEDS CLARIFICATION] markers introduced: whether a parent-node click should aggregate its
  descendant steps' files (vs. show nothing, since only leaf steps get documents mapped directly) is
  resolved as an explicit FR (FR-102) plus a matching edge case, since leaving parent nodes
  non-interactive/empty would make large trees harder to use than the source is worth.
