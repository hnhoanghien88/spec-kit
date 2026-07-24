# Specification Quality Checklist: EUTR Templates Management

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-07-02
**Updated**: 2026-07-24 (Update 20)
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
- [x] User scenarios cover primary flows (View, Add, Edit, Delete, Import)
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

- Spec references database table names (eutr_templates, eutr_template_details) and D365 entity
  names (VendorsV3) in domain context — these are business domain references, not implementation
  details.
- Edit uses versioning mechanism: new row with VersionId+1, old row marked IsHide=1, details
  copied to new Id. This is a business rule, not implementation detail.
- Delete uses soft delete: IsDeleted=1 instead of hard delete. Grid filters IsDeleted=0 AND
  IsHide=0.
- Import feature follows existing eutr-masters pattern — detailed format deferred to plan phase.
- DB schema updated: eutr_templates now includes IsDeleted and IsHide columns.

### Update 2026-07-03 — Changes Added

- **Bug fix: Vendor API** — FR-005b added to ensure Vendor combobox calls D365 VendorsV3 API.
  Acceptance scenarios updated in US2 (scenario 2) and US3 (scenario 7).
- **Bug fix: ParentId save** — FR-009 updated to explicitly require ParentId to be saved correctly.
  SC-010 added for measurable verification.
- **New: Edit step** — FR-008b added for inline Edit step functionality (change step,
  RequirementType, TakeFrom). Acceptance scenarios 6, 6a, 6b, 6c added to US2; scenarios 5, 6
  added to US3. SC-011 added.
- **New: 2-column layout** — FR-004a added for Add/Edit 2-column layout (header left, steps right).
  US2 scenario 1 and US3 updated to reflect layout. SC-012 added.
- Edge cases added for edit step behavior (auto-cancel, no unique constraint on StepId).

### Update 2026-07-03 — Dedicated Vendors API

- **Change: Dedicated vendors endpoint** — FR-018 added: backend MUST provide
  `GET /api/dynamics/vendors` in DynController (same pattern as `data-area` endpoint) to query
  D365 VendorsV3 directly, replacing refType=13 usage in the generic reference API.
- **Change: Frontend vendor API switch** — FR-002 and FR-005b updated: Vendor column lookup and
  Vendor combobox MUST use the new dedicated `GET /api/dynamics/vendors` endpoint instead of the
  generic `POST /api/dynamics/reference` with refType. Frontend must remove
  ReferenceObjectAutocomplete dependency for vendor field.
- **API contracts updated** — D365 Vendor Lookup section in api-endpoints.md rewritten to reflect
  the new `GET /api/dynamics/vendors` endpoint with skip/top/filter/order_by query parameters.
- SC-009 updated to verify dedicated endpoint usage. All user story references updated from
  "D365 VendorsV3 API" to "API vendors" / "`GET /api/dynamics/vendors`".
- Assumptions updated: VendorsV3 domain entity already exists at
  ComplianceSys.Domain.Dynamics.VendorsV3.

### Update 2026-07-03 — Vendors Column Selection

- **Change: FR-018 updated** — vendors endpoint MUST use OData `$select` to return only 3 columns
  (`dataAreaId`, `VendorAccountNumber`, `VendorOrganizationName`) instead of all VendorsV3 fields.
  Reduces API response payload size and improves performance.
- Key Entities: D365 Vendor updated to note `$select` constraint on returned columns.

### Update 2026-07-03 — Conditional Versioning + Add/Edit UI Changes

- **Clarification resolved**: Edit within 24h of CreatedDate → update in place (no new row, no
  VersionId increment, no IsHide). After 24h → existing versioning behavior (new row, VersionId+1,
  old row IsHide=1).
- **Change: FR-012 updated** — versioning is now conditional on template age (CreatedDate vs.
  current time, 24-hour threshold). Acceptance scenarios 1a, 1b added to US3.
- **Change: FR-004a, FR-009, FR-009a added** — Save button moves from the title bar to directly
  below the "Set as default template" checkbox in the left column; Back button stays in the title
  bar. Left column widened, right column (step tree) narrowed. Acceptance scenarios 2a-2d added
  to US2.
- **Change: FR-015 updated** — Back button MUST show a confirmation warning if unsaved step
  additions/edits exist in the tree; otherwise navigates directly. Edge cases added.
- SC-007 updated for conditional versioning; SC-013, SC-014, SC-015 added for the new behaviors.
- Assumptions updated: 24h threshold calculation basis, dirty-tracking scope (step tree changes
  only, not header field changes), column ratio deferred to plan phase.

### Update 2026-07-03 — Plan: Conditional Versioning + Add/Edit UI Changes

- **plan.md**: New "Conditional Versioning (24h) + Add/Edit UI Changes" section added. Constitution
  re-check confirms PASS — new repository method follows existing pattern (Principle II), frontend
  changes reuse existing `ConfirmDialog` component instead of introducing a new one. Project
  structure updated: `EutrTemplatesService.cs`, `IEutrTemplatesRepository.cs`,
  `EutrTemplatesRepository.cs` marked MODIFY (add `ReplaceDetailsAsync` + conditional branch in
  `UpdateAsync`); `EutrTemplatesAddEdit.jsx` and `useStepTree.js` MODIFY notes updated. Key
  Differences table updated for Edit behavior and new "Back navigation" row.
- **research.md**: Sections 13 (24h conditional versioning), 14 (Save button position + column
  ratio), 15 (Back button dirty-check) added with Decision/Rationale/Alternatives/Implementation.
  Section 12 (original 2-column layout, now superseded by Section 14) annotated with a pointer.
- **data-model.md**: EutrTemplates business rules and state-transition diagram updated for
  conditional versioning (≥24h → new version; <24h → in-place update). EutrTemplateDetails
  business rule updated for conditional detail replacement vs. copy-to-new-TemplateId.
- **contracts/api-endpoints.md**: Update Template endpoint (`PUT api/eutr-templates/{id}`)
  documents both response shapes (new version vs. in-place) and the 24h branching behavior.
- **quickstart.md**: Scenario 2 updated for Save button position/title bar change. Scenario 3
  split into 3a (in-place, <24h) and 3b (versioning, ≥24h, with a `CreatedDate` backdating SQL
  snippet for testing). New Scenario 12 (Back button warning) added. Edge cases and
  Post-Validation Checks updated accordingly.

### Update 2026-07-06 — Free-solo Step Combobox + Auto-create Step

- **New: Free-solo Step combobox** — FR-007, FR-008b updated: combobox Step in Add step / Edit
  step MUST support both selecting an existing EUTR step and typing a new step name not in the
  list (free-solo). Acceptance scenario 3a added to US2; scenario 8 added to US3.
- **New: Auto-create step on Save** — FR-007a added: on Save template, any step with a
  freely-typed name that doesn't match (case-insensitive, trimmed) an existing EUTR step MUST be
  auto-created in `eutr_steps` before saving `eutr_template_details`, then referenced by the new
  StepId. Duplicate new names within the same Save MUST reuse one newly-created StepId.
  Cross-references feature 001-eutr-steps (new step appears immediately in that screen).
- Key Entities: EUTR Step updated to document the auto-create behavior and dependency on
  001-eutr-steps' create flow. Assumptions updated with the name-matching rule (case-insensitive,
  trimmed) and dedupe-within-save behavior.
- Edge cases updated: empty EUTR steps list no longer blocks Add step (free-solo allows typing);
  added cases for name-match reuse (no duplicate creation) and blank/whitespace-only typed names.
- SC-016 added to verify auto-created steps appear immediately in the EUTR Steps screen.

### Update 2026-07-06 — Revert Vendor API to Generic Reference (refType=13)

- **Change: Vendor API reverted** — FR-002, FR-005, FR-005b, FR-011 updated: Vendor combobox
  (`options={vendors}` in `EutrTemplatesAddEdit.jsx`) and Vendor name grid lookup MUST switch back
  from the dedicated `GET /api/dynamics/vendors` endpoint to the generic
  `POST /api/dynamics/reference` API with `refType = 13`. Frontend reuses the generic reference
  component/hook (e.g. `ReferenceObjectAutocomplete` / `useReferenceObjects`) instead of the
  `useVendors` hook.
- **FR-018 marked Superseded** — the dedicated `GET /api/dynamics/vendors` endpoint added in
  Update 2/3 is no longer the data source for this feature; it may still exist in `DynController`
  unused by EUTR Templates.
- User stories (1, 2, 3), acceptance scenarios, Key Entities (D365 Vendor), Success Criteria
  (SC-003, SC-009), and Assumptions updated to reflect refType=13 as the vendor data source.
  Historical Update 2/3 clarification entries preserved as-is for traceability.

### Update 2026-07-07 — Alert For Combobox from compl_group_email

- **Change: Alert for field type** — FR-005, FR-010 updated: Alert for switches from a free-text
  textbox to a single-select combobox sourced from `compl_group_email` via `GET /api/group-email`
  (`ComplGroupEmailController`), filtered to `GroupType=Alert(2)` and `IsAddition=false`, reusing
  the existing "Alert group" combobox pattern already used elsewhere in the app (e.g.
  `ComplianceMasterForm`, `MasterDefaultForm` via `GetAllGroupEmailUseCase` / `groupEmailType.ALERT`).
- **New: FR-005c, FR-002a** — on Save, the selected group's Id (not Name) MUST be persisted into
  the `AlertFor` column; on the main grid, the Alert for column MUST look up and display the
  group's Name from `compl_group_email` by that Id. FR-001, FR-011 updated accordingly.
- Acceptance scenarios added: US1 (2a — grid displays group Name), US2 (1a, 1b — combobox load +
  Id persisted on save), US3 (7a, 7b — combobox pre-selects current group on Edit + save on
  change).
- Edge cases added: AlertFor Id no longer found in `compl_group_email` (blank display); empty
  Alert group list blocks Save until a group exists.
- Key Entities updated: EUTR Template's AlertFor attribute redefined as an Id reference to
  `compl_group_email.Id` (was free text); new "Compl Group Email" key entity added.
- SC-017, SC-018 added to verify combobox data source/pre-selection and Id-persist/Name-display
  round trip.
- Assumptions updated: reuse of existing group-email API/frontend pattern, single-select vs. the
  multi-select many-to-many pattern used by other forms, AlertFor column type change (free text →
  numeric Id) to flag for the plan phase, and behavior when a referenced group is later deleted.
- No new [NEEDS CLARIFICATION] markers — GroupType=Alert filtering and single-select behavior are
  reasonable defaults derived from the existing codebase convention (Content Quality and
  Requirement Completeness items above remain unaffected).

### Update 2026-07-07 — Shared RequirementType/TakeFrom Constants (frontend refactor)

- **Change**: REQUIREMENT_TYPES, TAKE_FROM_OPTIONS, REQUIREMENT_LABELS, TAKE_FROM_LABELS moved
  from `StepTree.jsx` to `compliance-client/src/utils/helpers.js` for reuse. `StepFormRow.jsx`'s
  duplicate local declaration of REQUIREMENT_TYPES/TAKE_FROM_OPTIONS is also removed in favor of
  the shared helpers.js export.
- Key Entities: EUTR Template Detail updated with a note on the shared frontend constant location.
- No functional/UI behavior change — same constant names, shapes, and values; pure code
  organization change. No new [NEEDS CLARIFICATION] markers; all checkbox items above remain
  passing, no regressions.

### Update 2026-07-13 — TemplateListPage Rename + 2-Step Create/Edit Flow

- **Input**: Update the UI per design reference `E:\Working\design\eutr` (`TemplateListPage.jsx`,
  `TemplateBuilderPage.jsx`); rename the index page to TemplateListPage; add a Code column, drop
  Status, add Alert for; drop Preview checklist/Archive from the Action column; split Add into a
  2-step flow (quick create with Name/Alert for/Set as default only, then Edit to add/build steps).
- **Change: Page rename** — FR-019 added: the list page MUST be organized/named as
  **TemplateListPage** (renamed from `EutrTemplatesPage`/`index.jsx`), per the design reference.
- **Confirmed, no functional change: Grid columns & Action column** — FR-020 added to explicitly
  confirm the grid column set (Code, Name, Vendor code, Vendor name, Alert for, Is default,
  Version, Created by, Created date) and Action column (Edit + Delete only) already match the
  request — Code and Alert for already exist, there is no Status column, and there is no Preview
  checklist/Archive/Publish/Clone. This is a confirmation against the design mockup's differing
  column/action set, not a behavior change to the current implementation.
- **Change: 2-step Create/Edit flow (the substantive change)** — FR-004, FR-004a, FR-005, FR-005b,
  FR-005c, FR-006 through FR-009a, FR-010, FR-011 updated:
  - **Step 1 (Create)**: the "Create Template" button now opens a lightweight dialog/modal with
    only 3 fields — Name (required), Alert for (required combobox), Set as default (checkbox). No
    Vendor field, no step tree. Code remains system-generated but is not shown in the dialog. Save
    creates a new template row (VersionId=1, VendorCode=null, no step details), closes the dialog,
    and refreshes the list — no auto-navigation to Edit.
  - **Step 2 (Edit)**: clicking Edit on any row (including one just quick-created) opens the
    existing full 2-column Edit screen (Code readonly/Name/Alert for/Vendor/Default/Save left,
    step tree right) — now the sole place to set Vendor and add/edit/remove steps, including the
    very first steps of a template.
- User Story 2 rewritten (quick create, dialog-based); User Story 3 (Edit) intro and acceptance
  scenarios updated to describe it as the sole location for Vendor + step tree work, including new
  scenarios 9-10 for editing a freshly quick-created (0-step, no-Vendor) template.
- SC-002, SC-009, SC-012, SC-014, SC-016, SC-017 updated to scope Vendor/step-tree/layout claims to
  the Edit screen only; SC-019, SC-020 added for the quick-create dialog shape and first-edit flow.
- Edge cases added: closing the Create dialog without Save creates nothing; a freshly
  quick-created template shows an empty step tree and blank Vendor combobox on first Edit (not an
  error); no auto-navigation from Create to Edit after Save.
- Assumptions added: Create dialog implemented as a standard Dialog/Modal (not a page navigation),
  per the design reference and the request's literal 3-field list; Vendor is fully excluded from
  Create (deferred to Edit) as a reasonable inference, not an explicit user confirmation; the page
  rename is organizational only and carries no other behavior change beyond this update.
- No new [NEEDS CLARIFICATION] markers — the Create-dialog UI shape and Vendor-exclusion-from-Create
  decisions are documented as reasonable defaults (see Assumptions) rather than blocking questions,
  since the request's literal field list and the design reference both point to the same answer.

### Update 2026-07-13 (Update 10) — Reverses Update 9's UI Decision: TemplateListPage Table Layout + Edit Opens TemplateBuilderPage

- **Input**: "cập nhật 003-eutr-templates, lấy tính năng đã viết từ TemplateListPageOld sang
  TemplateListPage, ở màn hình index {tmpl.name} hiển thông tin code, {tmpl.description} là name,
  chức năng create template, Delete sẽ hoạt động giống cũ, chức năng Add/Edit sẽ mở form
  TemplateBuilderPage".
- Two scope questions were asked back to the user before writing this update (both answered):
  (1) keep the DataGrid layout from Update 9, or switch to the Table/search/chip layout of the
  `TemplateListPage.jsx` design reference → **answered: switch to the Table layout**; (2) what to
  do with the mock "Clone"/"Apply to Customer" row actions already present in that design → 
  **answered: keep the icons but disable them (placeholder)**.
- **Change: FR-019/FR-020 (Update 9) reversed** — FR-021, FR-021a, FR-021b, FR-026 added: the list
  screen now uses the Table + search-box + Version/Default chip + Steps-count layout of
  `TemplateListPage.jsx` instead of the 9-column DataGrid confirmed in Update 9. The bold/primary
  text position shows the template's real **Code**; the secondary/caption text position shows the
  real **Name**. Vendor code/Vendor name/Alert for/Created by/Created date are no longer shown as
  list columns (still viewable/editable in TemplateBuilderPage). Import/Export, column-visibility
  toggling, and per-column filter/sort are deferred (no equivalent affordance in the new layout).
- **Change: FR-004a/FR-011 (Update 9) reversed** — FR-023, FR-024, FR-025 added: clicking Edit now
  opens **TemplateBuilderPage** (tree-view + right-hand config panel, already wired into
  `MainRoutes.jsx` at `/eutr/templates/edit/:id`) instead of the 2-column form/list layout of
  `EutrTemplatesAddEdit.jsx`. TemplateBuilderPage must be wired to the real backend/use-cases that
  `EutrTemplatesAddEdit.jsx` already implements (load/save, conditional 24h versioning, free-solo
  step auto-create, Vendor/Alert-for lookups) — reusing that logic rather than rewriting it.
  `EutrTemplatesAddEdit.jsx` is no longer referenced by any route after this change.
- **Change: FR-022 added** — Delete on TemplateListPage must reuse `TemplateListPageOld.jsx`'s
  exact behavior: per-row delete via `ConfirmDialog` + `DeleteEutrTemplatesUseCase`, plus a new
  per-row checkbox + bulk-delete toolbar button via `ConfirmDialog` + `DeleteMultiEutrTemplatesUseCase`
  (the new Table layout previously had no bulk-select affordance).
- User Story 1, User Story 3, User Story 4 rewritten to describe the Table layout, the
  TemplateBuilderPage edit target, and bulk delete respectively. User Story 5 (Import) marked
  deferred/out of scope for this update (kept for historical reference only).
- FR-001, FR-002, FR-002a, FR-004a, FR-011, FR-020 marked "(Superseded by Update 10)" in place
  (body preserved for traceability, per this doc's existing convention for superseded requirements).
- SC-003 marked superseded (no more Vendor-name list column); SC-008, SC-012 reworded for the new
  layout; SC-021 through SC-025 added for search filtering, Code/Name mapping, bulk delete,
  Edit-opens-TemplateBuilderPage, and Clone/Apply disabled state.
- Assumptions updated: TemplateListPage.jsx/TemplateBuilderPage.jsx are pre-existing mock-data
  design-reference files already wired into routing; scope of this update is replacing their mock
  data/logic with real data/logic reused from TemplateListPageOld.jsx/EutrTemplatesAddEdit.jsx, not
  rewriting the visual layout. Steps-count column falls back to 0/blank if the list API doesn't yet
  return it — not a blocking condition. Clone/Apply-to-Customer icons only need a disabled state, no
  click handling.
- No new [NEEDS CLARIFICATION] markers were embedded in the spec — the two scope decisions above
  were resolved interactively before writing, per the "resolve via question, not marker" path.

### Update 2026-07-13 (Update 11) — /speckit-clarify: Search Scope + Steps-Count Backend Scope

- Ambiguity scan run against the full taxonomy (functional scope, data model, UX flow,
  non-functional, integrations, edge cases, constraints, terminology, completion signals,
  placeholders). Two high-impact gaps surfaced; the rest were Clear or low-impact.
- **Q1 (resolved)**: The Update 10 search box (FR-021a) didn't say whether it filters server-side
  or only the currently-loaded page — material because `useEutrTemplatesData` already runs
  `paginationMode="server"`/`filterMode="server"`, so a client-side-only filter would miss matches
  sitting on other pages. → **A: server-side** — extend the list API/hook with a Code-or-Name
  keyword parameter, debounce keystrokes, and reset to page 1 on each search.
  - FR-021a rewritten to require server-side search with debounce + page-1 reset.
  - US1 acceptance scenario 3 and SC-021 reworded to state the search re-queries the server across
    the full dataset, not just the loaded page.
  - Assumptions: new bullet documenting the server-side search mechanism, extending the existing
    `filterModel`-to-server pattern with a single free-text keyword field.
- **Q2 (resolved)**: FR-021 said the Steps column MUST show a real per-template step count, but the
  Update 10 Assumption contradicted it by allowing a permanent 0/blank placeholder "until backend
  is enhanced later." → **A: in scope** — the list API MUST be extended in this update to return
  each template's real step count (count of active `eutr_template_details` rows).
  - New **FR-021c** added: list API MUST return real step count per template as part of this
    update's backend scope.
  - FR-021's Steps-column bullet cross-references FR-021c instead of allowing a placeholder.
  - The contradictory Update 10 Assumption bullet ("falls back to 0/blank, not blocking") was
    replaced with a bullet stating the count is real and in scope, cross-referencing FR-021c.
  - New **SC-026** added to make the real-count requirement measurable/testable.
- Sections touched: Clarifications (new `### Session 2026-07-13 (Update 11)` subheading), User
  Story 1 (acceptance scenario 3), Functional Requirements (FR-021, FR-021a, new FR-021c), Success
  Criteria (SC-021 reworded, new SC-026), Assumptions (Steps-count bullet replaced, new search
  bullet added).
- No contradictory statements remain: the FR-021/Assumption conflict on Steps count from Update 10
  is resolved (both now agree the count is real and in-scope). No new [NEEDS CLARIFICATION]
  markers were embedded — both ambiguities were resolved through the interactive clarification
  question flow before being written into the spec.
- Spec Quality Checklist re-validated against the updated spec: all 16/16 items remain passing (no
  regressions, no newly-failing items) — the two resolved ambiguities were scope/consistency gaps
  in already-written requirements, not missing checklist criteria.

### Update 2026-07-13 (Update 12) — Bulk Add Multiple Steps (Root Group / Child Step)

- **Input**: Update the Add Root Group / Add Child Step feature on TemplateBuilderPage to allow
  adding multiple steps at once, per an attached design image — a checkbox table of master EUTR
  steps (e.g. P1-P8) with per-row Requirement Type/Take From dropdowns, a selected-count footer,
  and Cancel/Add actions.
- **One scope question asked back to the user before writing this update (answered)**: the current
  Add Root Group/Add Child Step dialog supports free-solo typing of a brand-new step name
  (auto-created in `eutr_steps` on Save, per FR-007a/Update 6-8); the design image only shows a
  checkbox table of existing master steps with no text-entry row. → **answered: keep the
  bulk-select table as the primary flow (per the design), and add a separate "Add new step" area
  within the same dialog for free-solo entry of a brand-new name** — the new step is merged into
  the same "pending" batch as the ticked master steps and added together on a single Add click.
- **Change: FR-025 marked "Superseded một phần"** — FR-027 through FR-030 added: Add Root
  Group/Add Child Step now opens a bulk-select table (checkbox per row, Step Master column,
  per-row Requirement Type/Take From editable only once ticked, header select-all, footer counter
  "{N} step available - {M} selected", disabled Add button when 0 selected) instead of the
  single-step-at-a-time form. FR-028 defines the multi-add save behavior (ParentId per trigger
  button, DisplayOrder appended in row order). FR-029 defines de-duplication (exclude steps already
  a direct child of the target parent). FR-030 defines the dedicated free-solo "Add new step" area,
  reusing the existing FR-007a auto-create-on-save mechanism.
- **New: FR-031** — Edit step on an existing node (FR-008b) is explicitly called out as unchanged
  by this update (still single-step, not bulk).
- User Story 3 intro rewritten to describe the bulk-select flow; new acceptance scenarios 11-15
  added (open dialog with 0 selected/Add disabled, bulk-add 5 steps as roots, bulk-add mixed
  master+free-solo steps as children, Cancel discards the pending batch, already-added steps
  excluded from "available").
- SC-027 through SC-030 added for measurable verification (multi-step add in one click, correct
  ParentId/Requirement Type/Take From per row, Add-button disabled state, free-solo step
  auto-created on Save).
- Edge cases added: select-all/partial-unselect counter accuracy, empty "available" list still
  allows free-solo entry, duplicate-name merge rule between ticked and free-solo entries in the
  same batch, Cancel discards everything, Root Group ignores any currently-selected tree node.
- Assumptions added: "step available" source is the same `GetEutrStepsUseCase` list already used
  for the free-solo combobox (no new API); default Requirement Type/Take From on newly-ticked rows
  match the existing `stepForm` defaults (Optional/PO); `StepFormRow.jsx` may be reused for the
  "Add new step" area (implementation detail deferred to `/speckit-plan`).
- No new [NEEDS CLARIFICATION] markers were embedded in the spec — the one scope decision above was
  resolved interactively before writing, per the established "resolve via question, not marker"
  path used in Update 10/11.
- Spec Quality Checklist re-validated against the updated spec: all 16/16 items remain passing (no
  regressions, no newly-failing items).

### Update 2026-07-13 (Update 13) — Remove VendorCode, Add Apply-to-Customer, Fix Steps-Count Bug

- **Input**: "cập nhật 003-eutr-templates bỏ cột VendorCode ở eutr_templates và các logic liên
  quan. Thêm tính năng Apply to customer... Màn hình EUTR template, cột steps vẫn chưa hiển thị
  count từ eutr_template_details."
- **Three scope questions asked back to the user before writing this update (all answered)**:
  (1) migrate existing VendorCode data into `eutr_template_references` on column removal, or
  discard it → **answered: discard, drop the column outright**; (2) after removing VendorCode,
  should the "1 default template" constraint become global or be removed entirely →
  **answered: global (single default across the whole system)**; (3) should the same vendor be
  blocked from overlapping date-range mappings across *different* templates, or only within the
  same template → **answered: only within the same template** (matches the existing
  `ApplyCustomerPage.jsx` mock's `hasOverlap` scope).
- **Pre-write implementation audit** (via Explore agent + direct file reads) confirmed: VendorCode
  is fully implemented end-to-end today (entity, DTOs, repository sort/filter whitelist, service
  default-per-vendor logic, import/export, `TemplateBuilderPage.jsx`, `useEutrTemplatesColumns.jsx`,
  `CreateTemplateDialog.jsx`) — this is a real removal, not a no-op; `eutr_template_references` has
  no backend at all yet (new CRUD needed); and the Steps-count backend/frontend wiring
  (`StepsCount` subquery in `EutrTemplatesRepository.GetPagedWithVendorNameAsync`,
  `tmpl.stepsCount` in `TemplateListPage.jsx`) already exists in code despite the user-reported bug
  — root cause left for `/speckit-plan`/`/speckit-implement` to investigate (FR-042, Assumptions).
- **Change: FR-039 through FR-041 added** — VendorCode removed entirely from `eutr_templates` and
  all related backend/frontend logic (no data migration); FR-040 replaces FR-005a with a global
  (not per-vendor) single-default constraint; FR-041 removes the Vendor combobox from
  TemplateBuilderPage's config panel. FR-005a, FR-005b, FR-010, FR-024 marked "(Superseded/Cập
  nhật by Update 13)" in place (body preserved for traceability).
- **New: FR-032 through FR-038** — new **User Story 6 (Apply to Customer)**: the previously-disabled
  Apply to Customer icon on TemplateListPage (FR-026) becomes active, navigating to a new
  **ApplyCustomerPage** (route `/eutr/templates/apply/:id`) that lists/creates/edits/deletes vendor
  mappings in `eutr_template_references` (Vendor via the existing refType=13 reference API, From
  date/To date, same-template-same-vendor overlap validation, hard delete — no soft-delete column
  on this table).
- **New: FR-042 (bug fix)** — Steps column on TemplateListPage MUST actually display the real step
  count for 100% of rows; despite the code already appearing wired, this remains an open,
  user-reported defect that MUST be root-caused and fixed, not just re-confirmed as "already done."
- Edge Cases: 7 new bullets added (template-not-found on ApplyCustomerPage, empty mapping list,
  To-date-before-From-date validation, blank-To-date = unlimited, overlap check excludes the record
  being edited, no VendorCode-data migration is expected behavior, global-default unmarking).
- Key Entities: EUTR Template's "Vendor code" attribute removed; new **EUTR Template Reference**
  entity added (`eutr_template_references` — all audit columns NOT NULL, no soft-delete flag); D365
  Vendor entity's usage note updated to point at ApplyCustomerPage instead of TemplateBuilderPage.
- Success Criteria: SC-031 through SC-035 added (mapping persistence round-trip, same-template
  overlap blocking + cross-template non-blocking, zero remaining VendorCode references outside
  `eutr_template_references`, global default-unmarking, Steps column accuracy).
- Assumptions: 6 new bullets added — VendorCode data discarded on column removal (per Q1 above);
  default constraint now global; proposed route `/eutr/templates/apply/:id` (to be finalized at
  `/speckit-plan`); `ApplyCustomerPage.jsx` already exists as a mock-data reference UI (Customer/
  `MOCK_CUSTOMERS` concept + a `status !== 'Published'` gate that doesn't apply to real templates)
  whose mock data/gating this update replaces with real Vendor/API data — its `hasOverlap` logic is
  reused nearly as-is, just rescoped from customerId to VendorCode+TemplateId; `eutr_template_references`
  needs an entirely new backend CRUD; and the Steps-count bug's root cause is explicitly left
  unresolved for the plan/implement phase.
- No new [NEEDS CLARIFICATION] markers were embedded in the spec — all three scope decisions above
  were resolved interactively (via targeted questions with recommended defaults) before writing,
  per the established "resolve via question, not marker" path used in Update 10/11/12.
- Spec Quality Checklist re-validated against the updated spec: all 16/16 items remain passing (no
  regressions, no newly-failing items).

### Update 2026-07-14 (Update 14) — Import/Export Vendor Mapping on ApplyCustomerPage

- **Input**: "cập nhật 003-eutr-templates chức năng apply to customer, thêm 2 nút Import và Export,
  file template gồm 2 cột là TemplateCode, VendorCode, FromDate, ToDate. Logic giống như Add. Khi
  Export, import sẽ dựa vào liên kết template code để xuất, add dữ liệu, chỉ chấp nhận file excel,
  khi thành công có thông báo dòng nào ok, dòng nào bị lỗi."
- **One scope question asked back to the user before writing this update (answered)**: whether
  Import on ApplyCustomerPage (a single-template screen, route `/eutr/templates/apply/:id`) is
  scoped to only the currently-open template, or can create mappings across multiple templates in
  one file using the TemplateCode column per row → **answered: scoped to the currently-open
  template only** — the TemplateCode column is used to cross-check/validate each row, not to route
  rows to other templates; mismatched rows fail with a per-row error.
- **Change: FR-043 through FR-048 added** — Import/Export buttons added to the ApplyCustomerPage
  toolbar. Export downloads an .xlsx file (TemplateCode, VendorCode, FromDate, ToDate columns) of
  the current template's mappings, including a header-only file when the mapping list is empty
  (doubling as the import template file). Import accepts only .xlsx, validates each row with the
  same rules as the existing Add Vendor dialog (FR-034/FR-036 — required VendorCode/FromDate,
  optional ToDate, same-vendor-same-template overlap check spanning both existing mappings and
  earlier valid rows within the same file, TemplateCode-must-match-current-template), creates new
  mappings only (no update-on-match), and reports a per-row OK/error result after processing.
- User Story 6 intro updated to describe the Import/Export buttons; 6 new acceptance scenarios
  (11-16) added covering Export with data, Export when empty, non-.xlsx rejection, mixed
  valid/invalid rows with per-row reporting, in-file overlap handling, and header-only file import.
- 9 new edge cases added: non-.xlsx rejection, missing/renamed required columns, header-only file,
  mismatched TemplateCode per row, in-file overlap sequencing, ToDate < FromDate per row, blank
  ToDate = unlimited, and Import never updates existing mappings (duplicate data is treated as an
  overlap error, not a silent update).
- Key Entities: EUTR Template Reference updated with a note on bulk Import/Export (Add-only, same
  validation as manual Add).
- Success Criteria: SC-036 through SC-039 added (Export column/content accuracy including the
  empty-list case, non-.xlsx rejection, per-row Import result reporting, mismatched-TemplateCode
  row isolation).
- Assumptions: 4 new bullets added — reuse of the existing Excel import/export mechanism (no new
  library), Export-when-empty doubling as the template file (resolving the "file template"
  wording), the request's literal "2 columns" vs. the 4 column names actually listed (treated as a
  wording slip, processed as 4 columns), and Import being Add-only (never updates an existing
  mapping, even on an exact duplicate).
- No new [NEEDS CLARIFICATION] markers were embedded in the spec — the one scope decision above was
  resolved interactively before writing, per the established "resolve via question, not marker"
  path used in Update 10/11/12/13.
- Spec Quality Checklist re-validated against the updated spec: all 16/16 items remain passing (no
  regressions, no newly-failing items).

### Update 2026-07-15 (Update 15) — Clone Template + Copy eutr_template_references on Version-up

- **Input**: "cập nhật 003-eutr-templates khi lên version, copy thêm cả dữ liệu
  eutr_template_references, thêm tính năng clone, khi click vào sẽ hiển thị popup clone template từ
  template đã chọn sang template mới, có ô cho user nhập tên template mới, alert for, user đồng ý
  sẽ copy toàn bộ dữ liệu template cũ, tạo ra template mới."
- **Bug fix: version-up drops vendor mappings** — FR-049 added: the >24h branch of FR-012 (creates
  a new TemplateId, VersionId+1) previously copied only `eutr_template_details` (step tree) to the
  new TemplateId, leaving `eutr_template_references` (vendor mappings, Update 13) attached only to
  the now-hidden old TemplateId. FR-049 requires the same copy-to-new-TemplateId behavior for
  `eutr_template_references`. The <24h in-place branch is unaffected (TemplateId unchanged).
- **New: Clone Template feature** — FR-050 through FR-054 added: the previously-disabled Clone icon
  (FR-026) becomes active, opening a popup with a read-only source-template identifier, a required
  **New template name** field, and a required **Alert for** combobox (same `compl_group_email`
  source as Create Template). Confirming shows a `ConfirmDialog`-style warning before the actual
  copy runs. On confirm, the system creates a brand-new template (new auto-generated Code,
  VersionId=1, IsDefault=0 always) and copies both the full step tree
  (`eutr_template_details`, preserving StepId/RequirementType/TakeFrom/DisplayOrder/ParentId
  structure) and the full vendor mapping set (`eutr_template_references`, preserving
  VendorCode/FromDate/ToDate) from the source template. New **User Story 7** added.
- **Two scope questions resolved via informed default (not asked back, per the spec's own
  "reasonable defaults over blocking markers" guidance, given low ambiguity/reversibility)**:
  (1) whether "toàn bộ dữ liệu template cũ" for Clone also includes `eutr_template_references`
  (not just step tree) → resolved yes, since the same user message introduces
  `eutr_template_references`-copying in the same breath as the Clone request; (2) whether the
  cloned template inherits the source's IsDefault flag → resolved no (always IsDefault=0), to avoid
  silently violating the FR-040 global single-default constraint.
- FR-026 updated in place to note Clone is no longer disabled (superseded pointer to FR-050),
  consistent with how FR-032 previously updated the Apply-to-Customer half of the same requirement.
- Key Entities: EUTR Template, EUTR Template Detail, and EUTR Template Reference each updated with a
  Update 15 note describing the copy-on-version-up and copy-on-clone behavior.
- Success Criteria: SC-040 through SC-044 added (version-up mapping-copy completeness, Clone icon no
  longer disabled, Clone copy accuracy for both step tree and mappings, Clone validation blocking,
  Clone confirmation-dialog gating).
- Edge cases added: empty step tree/mapping list on Clone source (not an error), no re-creation of
  already-existing StepIds during Clone, repeated Clone from the same source is unbounded, no
  overlap-check interference between source and cloned TemplateId (different TemplateId is out of
  FR-036's same-template scope), full independence between source and cloned template after Clone,
  and old (now-hidden) mapping rows are preserved (not moved/deleted) after a version-up copy.
- No [NEEDS CLARIFICATION] markers were embedded in the spec — both scope questions above were
  resolved as documented Assumptions with explicit rationale, consistent with this spec's
  established pattern (e.g. Update 7, 9, 12) of using reasonable defaults for low-impact/reversible
  UX details instead of blocking on every open question.
- Spec Quality Checklist re-validated against the updated spec: all 16/16 items remain passing (no
  regressions, no newly-failing items).

### Update 2026-07-21 (Update 16) — Status Draft/Approved, replaces 24h versioning with Approved→Draft trigger

- **Input**: "cập nhật 003-eutr-templates thêm 1 cột Status là enum sẽ định nghĩa trong helpers.js
  gồm 2 trạng thái Draft, Approved, cập nhật lại logic, khi vừa tạo template, mặc định status =
  Draft. Khi user nhấn nút Approve, có hiện box xác nhận Yes/No, Yes dữ liệu chuyển sang Approved,
  No đóng box. User muốn chỉnh sửa sẽ bấm nút Request change cũng hiển thị box xác nhận Yes/No.
  Đồng thời logic lên version sẽ bỏ sau 24h, chỉ lên version khi user chuyển từ trạng thái Approve
  sang Draft."
- **Three scope questions resolved interactively (AskUserQuestion) before writing**, per this
  spec's established "resolve via question, not marker" path for UX-impacting decisions (Update
  9/10/11/13/14/15): (1) where the Approve/Request change controls live → answered: toolbar buttons
  on TemplateListPage, next to Create Template (not per-row icons, not on TemplateBuilderPage); (2)
  how TemplateBuilderPage should behave when Status=Approved → answered: fully read-only (mirrors
  the reference mockup's `isReadOnly` behavior); (3) when the version bump actually happens on
  Request change confirm → answered: immediately on Yes (not deferred to the next Save).
- **New: Status enum (Draft/Approved)** — FR-055 adds a `Status` column to `eutr_templates`, enum
  defined in `compliance-client/src/utils/helpers.js` following the feature's existing shared-enum
  convention (REQUIREMENT_TYPES, TAKE_FROM_OPTIONS, groupEmailType). FR-056 defaults new templates
  (Create Template and Clone) to Status=Draft. FR-062 adds a Status Chip to each TemplateListPage
  row (next to the Default chip).
- **Replaced: FR-012's 24-hour versioning branch removed entirely** — FR-057 (supersedes FR-012):
  Save on TemplateBuilderPage (only available when Draft) now always overwrites the current row in
  place, regardless of CreatedDate age. VersionId increments exactly once in the template's entire
  lifecycle: at the moment Request change is confirmed (Approved → Draft transition), which
  immediately creates a new row (VersionId+1, Status=Draft), copies the full step tree
  (`eutr_template_details`) and vendor mapping (`eutr_template_references`) from the old Approved
  row, and hides the old row (IsHide=1) as an immutable historical snapshot. Approve (Draft →
  Approved, FR-059) does NOT create a new version — it only flips Status on the same row.
- **New: Approve / Request change toolbar actions** — FR-058 adds both buttons to the
  TemplateListPage toolbar, reusing the existing per-row checkbox selection (FR-022); each button
  is enabled only when exactly 1 row is selected and its Status matches (Draft for Approve,
  Approved for Request change). FR-059/FR-060 define the Yes/No `ConfirmDialog` behavior for each
  action. New **User Story 8** (Approve) and **User Story 9** (Request change) added.
- **New: Approved templates are read-only** — FR-061: when Status=Approved, TemplateBuilderPage
  shows a warning banner and disables all header fields, Save, and every step-tree action (Add
  Root/Child, Edit step, Delete step) — mirrors the reference mockup's `isReadOnly` treatment for
  non-Draft templates.
- User Story 3 (Edit) updated in place: the old 24h-branch narrative and acceptance scenarios
  1/1a/1b are marked superseded (struck through, kept for history) and replaced with new scenario
  1c (Draft always overwrites in place) and 1d (Approved opens read-only); scenarios 2/3/5/6/7b/8/10
  had their "new row if >24h, overwrite if <24h" phrasing replaced with "always overwrites in
  place (Update 16)".
- Key Entities: EUTR Template updated with the Status attribute and the new versioning narrative
  (24h branch struck through, kept for history); EUTR Template Reference updated to note the
  version-bump trigger is now Request change, not the ">24h" branch of the old FR-012.
- Success Criteria: SC-007 and SC-013 marked superseded (pointing to the new SC-045/SC-046);
  SC-040 updated to point at the new trigger; SC-045 through SC-050 added (Status defaults to Draft
  on create, Draft Save never versions, Approve/Request change confirm-dialog behavior, Approved
  read-only enforcement, toolbar button enable/disable rules).
- Edge Cases: the two 24h-boundary edge cases replaced with Update 16 notes (Approved templates
  reject direct API updates outside the Request change flow; Approve/Request change are single-row
  actions only, disabled for 0 or 2+ selected rows; Request change on a 0-step/0-mapping template is
  not an error).
- Assumptions: the 24h-based versioning assumption marked superseded (struck through, kept for
  history); two new Update 16 assumptions added (versioning tied to the Draft/Approved lifecycle
  instead of a time threshold; Approve/Request change are single-record actions, no bulk mode). Also
  corrected a stale Update 13 assumption that claimed "the real EUTR Template has no Status concept"
  — now noted that Update 16 reintroduces Status, but it does not gate Apply to Customer.
- No [NEEDS CLARIFICATION] markers were embedded in the spec — the three scope questions above were
  all resolved interactively via AskUserQuestion before writing, consistent with this spec's
  established "resolve via question, not marker" pattern for UX-impacting decisions.
- Spec Quality Checklist re-validated against the updated spec: all 16/16 items remain passing (no
  regressions, no newly-failing items). Historical FR/SC/Assumption text describing the removed
  24-hour logic was kept (struck through) rather than deleted, consistent with this spec's
  established layered-update convention (e.g. how FR-001/FR-002/FR-020 retain superseded text with
  forward pointers).

### Update 2026-07-22 (Update 17) — Drag-and-drop Step Reorder Alongside Move Up/Down

- **Input**: "cập nhật 003-eutr-templates màn hình edit. hiện tại muốn di chuyển step lên xuống
  phải bấm move up, move down, giờ thêm tính năng cho user kéo step lên xuống." (TemplateBuilderPage
  currently only supports reordering sibling steps via Move Up/Move Down toolbar buttons; add
  drag-and-drop as an additional way to reorder.)
- **Pre-write code audit**: confirmed `TemplateBuilderPage.jsx`'s `moveNode()` calls
  `reorderSiblings()` from `useStepTree.js` (same-parent-only reorder, updates local state +
  `isDirty`, persisted only on Save) — no drag-and-drop exists anywhere in `StepTree.jsx` or
  `TemplateBuilderPage.jsx` today, despite the original FR-006 text (Update 9 era) having already
  described drag-and-drop aspirationally. This update makes that description real and explicit.
- **One scope question asked back to the user before writing (answered via AskUserQuestion)**:
  whether dragging a step should be restricted to reordering among same-level siblings (matching
  Move Up/Down's existing constraint) or should also support dropping onto another step to reparent
  it (change ParentId) → **answered: same-level reorder only, no reparenting via drag** (the
  Recommended option).
- **Change: FR-006 updated in place** — annotated "(Cập nhật ở Update 17 — xem FR-064 đến FR-066)",
  body preserved describing the existing Move Up/Move Down mechanism, now cross-referencing the new
  drag-and-drop FRs as an additional (not replacement) interaction.
- **New: FR-064 through FR-067 added** — FR-064 requires TemplateBuilderPage to add drag-and-drop
  reordering on step rows, additive to Move Up/Down (both remain available). FR-065 restricts valid
  drop targets to same-ParentId siblings only — dropping onto a different branch MUST NOT change
  ParentId. FR-066 requires DisplayOrder to update immediately in the UI on a valid drop (reusing
  `reorderSiblings`), marking the screen dirty, persisted only on the next Save (no auto-save on
  drop). FR-067 requires drag-and-drop to be disabled whenever Status=Approved (read-only per
  FR-061), matching Move Up/Down's existing disabled state.
- User Story 3 intro updated to mention drag-and-drop as an equivalent second way (alongside Move
  Up/Move Down) to reorder sibling steps. Three new acceptance scenarios (16-18) added: drag-drop
  reorder produces the same result as Move Up/Down and stays unsaved until Save; dragging onto a
  different branch is a no-op (no reparenting); drag-and-drop is disabled when Status=Approved.
- Success Criteria: SC-051 added (100% of same-level drag-drop reorders update DisplayOrder
  correctly and match Move Up/Down's result; 0% change ParentId or apply while Approved).
- Assumptions: 2 new bullets added — this is a frontend-only change (no backend/API changes needed,
  since the drop result is saved through the existing Save flow, reusing `reorderSiblings` from
  `useStepTree.js`; specific drag library/technique choice deferred to `/speckit-plan`); and because
  scope is same-level-only, no cycle-detection/reparent-validation logic is needed (complexity stays
  equivalent to the existing Move Up/Down feature).
- No [NEEDS CLARIFICATION] markers were embedded in the spec — the one scope question above was
  resolved interactively via AskUserQuestion before writing, consistent with this spec's established
  "resolve via question, not marker" pattern (Update 10/11/12/13/14/15/16).
- Spec Quality Checklist re-validated against the updated spec: all 16/16 items remain passing (no
  regressions, no newly-failing items).

### Update 2026-07-23 (Update 18) — Allow Editing "Set as default template" When Approved

- **Input**: "cập nhật 003-eutr-templates. với template trạng thái approve, cho chỉnh sửa Set as
  default template." (For an Approved-status template, allow editing "Set as default template".)
- **One scope question asked back to the user before writing this update (answered via
  AskUserQuestion)**: FR-061 (Update 16) says the Save button is fully hidden/disabled when
  Status=Approved — so if the Set as default checkbox becomes editable in that state, how does the
  change actually get persisted? → **answered: auto-save with a `ConfirmDialog` Yes/No** — toggling
  the checkbox shows a Yes/No confirmation (matching the existing Approve/Request change pattern);
  choosing Yes immediately calls a dedicated update (only the `IsDefault` column) independent of the
  main Save flow; choosing No reverts the checkbox to its prior value.
- **Change: FR-061 partially reversed** — the checkbox **Set as default template** is now the one
  exception to Approved read-only mode; it stays enabled and persists via the new FR-068 mechanism
  instead of the disabled/Save-gated behavior FR-061 previously required for all header fields. The
  rest of FR-061 (Name/Alert for disabled, Save hidden, step-tree actions locked) is unchanged.
- **New: FR-068** — defines the Yes/No confirm-then-persist mechanism for toggling Set as default
  while Approved: Yes updates only `IsDefault` (applying the existing global single-default
  constraint, FR-040) without touching Name/AlertFor/Status/VersionId/step tree/vendor mappings, and
  without requiring the (still hidden) Save button; No reverts the checkbox with no API call.
- Edge case (Update 16, "Approved templates reject direct API updates outside Request change") is
  updated to carve out an explicit exception: backend MUST still allow a dedicated IsDefault-only
  update while Approved, independent from the header/step-tree update path it otherwise rejects.
- User Story 8 (Approve template) acceptance scenario 5 updated to note the Set as default exception;
  new acceptance scenario 6 added describing the Yes/No confirm-then-persist round trip.
- Success Criteria: SC-052 added (100% of Set as default toggles on an Approved template show the
  confirm dialog; Yes persists only IsDefault; No leaves it unchanged).
- No [NEEDS CLARIFICATION] markers were embedded in the spec — the one scope question above was
  resolved interactively via AskUserQuestion before writing, consistent with this spec's established
  "resolve via question, not marker" pattern (Update 10/11/12/13/14/15/16/17).
- Spec Quality Checklist re-validated against the updated spec: all 16/16 items remain passing (no
  regressions, no newly-failing items).

### Update 2026-07-24 (Update 19) — TakeFrom Sourced from `eutr_reference_types` + TemplateListPage Switches to DataGridStyled

- **Input**: "cập nhật 003-eutr-templates thông tin take from lấy từ bảng eutr_reference_types và
  TableContainer ở TemplateListPage sửa lại thành DataGridStyled." (Two independent technical
  changes: (1) the TakeFrom field's options/labels move from a hardcoded frontend constant to the
  `eutr_reference_types` table; (2) TemplateListPage's raw MUI `TableContainer`/`Table` markup is
  replaced with the shared `DataGridStyled` + MUI `DataGrid` pattern already used by other EUTR list
  pages.)
- **Pre-write code audit**: confirmed `eutr_db.sql` already declares
  `eutr_template_details_takefrom_foreign FOREIGN KEY(TakeFrom) REFERENCES eutr_reference_types(Id)`
  — the DB design already intended TakeFrom to reference this table; the frontend just never used
  it (`TAKE_FROM_OPTIONS`/`TAKE_FROM_LABELS` in `helpers.js` hardcode 5 values that happen to line up
  with the currently-seeded rows). Feature 006-eutr-reference-types already ships a working
  `GET /api/eutr-reference-types` (all rows) endpoint with CRUD, so no new backend work is needed —
  the templates feature only needs to consume it. Confirmed `eutr-reference-types/index.jsx` and
  `eutr-steps/index.jsx` as the canonical `DataGridStyled` + `DataGrid` usage pattern (server-side
  pagination/sort/filter, `checkboxSelection`, `columnVisibilityModel`) to follow for
  TemplateListPage.
- **Two scope questions resolved via informed default (not asked back)**, consistent with this
  spec's "reasonable defaults over blocking markers" convention for low-ambiguity/reversible
  decisions: (1) whether the TakeFrom data-source change applies to every combobox/label lookup
  (Add step, Edit step, bulk-select dialog, step-tree label display) or only some → resolved: all of
  them, since they all currently read the same two hardcoded constants; (2) whether switching to
  DataGridStyled also means restoring the old 9-column DataGrid/re-enabling column sort/filter/
  visibility (Update 9 style) or keeping Update 10-18's exact columns/features and only swapping the
  rendering technology → resolved: keep everything currently on TemplateListPage (2-line Code/Name
  cell, Status/Version/Default chips, Steps count, search box, checkbox bulk-select, 4 action icons)
  exactly as-is; sort/filter/column-visibility/Import-Export remain deferred per FR-021b, unchanged
  by this update.
- **New: FR-069 through FR-071 added** — TemplateListPage's list MUST render via `DataGridStyled` +
  MUI `DataGrid` instead of `TableContainer`/`Table`/`TableHead`/`TableRow`/`TableCell`/`TableBody`/
  `TablePagination` (FR-069); every existing column becomes a `DataGrid` column with `renderCell`
  preserving current content/behavior exactly, using DataGrid's built-in server-side pagination
  instead of manual `TablePagination` (FR-070); the manual per-row `Checkbox` for bulk-delete
  selection becomes DataGrid's built-in `checkboxSelection`/`onRowSelectionModelChange` (FR-071).
  FR-021 annotated in place (body preserved) noting the render technology changed at Update 19 while
  its described content stays authoritative.
- **New: FR-072, FR-073 added** — TakeFrom comboboxes (Add step FR-007, Edit step FR-008b,
  bulk-select FR-027-030) MUST load options from `GET /api/eutr-reference-types` (Name as label, Id
  as value) instead of the hardcoded `TAKE_FROM_OPTIONS` (FR-072); every place that looks up a
  TakeFrom display label by Id (step-tree rendering in `StepTree.jsx`/`TemplateBuilderPage.jsx`)
  MUST look up `Name` from the same loaded list instead of the hardcoded `TAKE_FROM_LABELS` map,
  rendering blank if the Id no longer exists (FR-073). `REQUIREMENT_TYPES`/`REQUIREMENT_LABELS` are
  explicitly out of scope — unchanged. FR-007, FR-008b annotated in place with pointers to FR-072.
- User Story 1 intro updated to note DataGridStyled/DataGrid now render the list (content per row
  unchanged). Key Entities: EUTR Template Detail's TakeFrom attribute redescribed as an
  `eutr_reference_types.Id` foreign key (no longer a 2-value hardcoded enum); new **EUTR Reference
  Type** key entity added documenting the table/API this feature now reuses.
- Success Criteria: SC-053 (TakeFrom comboboxes reflect eutr_reference_types CRUD changes live, no
  code change needed) and SC-054 (DataGridStyled swap preserves 100% of prior list behavior) added.
- Assumptions: 4 new bullets added — `eutr_reference_types`/`GET /api/eutr-reference-types` already
  exist from feature 006 (no new backend), existing seeded Ids retain their meaning (no data
  migration needed for already-saved `TakeFrom` values), `DataGridStyled` is an existing shared
  styling wrapper (no new component), and the `useEutrTemplatesData` hook's API contract
  (`paginationModel`/`filterModel`/`total`/`data`/`loading`) is unchanged — only how those values feed
  the grid changes.
- No [NEEDS CLARIFICATION] markers were embedded in the spec — both scope decisions above were
  resolved as documented Assumptions/Clarification Q&A with explicit rationale, consistent with this
  spec's established pattern (e.g. Update 7, 9, 12, 15) of using reasonable defaults for low-impact,
  easily-reversible technical/UX decisions instead of blocking on every open question.
- Spec Quality Checklist re-validated against the updated spec: all 16/16 items remain passing (no
  regressions, no newly-failing items). Both changes are scoped as data-source/rendering-technology
  swaps that preserve all existing user-facing behavior, so no acceptance-scenario contradictions
  were introduced.

### Update 2026-07-24 (Update 20) — Column Filters on TemplateListPage (Matching country-groups/index.jsx)

- **Input**: "thêm filter các cột giống E:\Working\Eutr\compliance-client\src\presentation\pages\country-groups\index.jsx" — a direct follow-up request (not routed through `/speckit-specify`), applied here retroactively for traceability.
- **Change: FR-021b marked partially superseded** — FR-074/FR-075 added: TemplateListPage's `DataGrid` enables per-column filtering (`filterMode="server"`, column-menu filter panel) for Template Name/Status/Version/Default, matching `country-groups/index.jsx`'s pattern; Steps (computed) and Actions stay non-filterable, mirroring how `country-groups` itself excludes its own computed `memberCount`/`countryCodes` columns. Sort and column-visibility remain deferred — only filter was requested.
- **Change: Backend `EutrTemplatesRepository.FilterMap` extended** — added `Status`, `VersionId`, `IsDefault` (all already selected in the existing query, just missing from the filter whitelist); no new endpoint, no contract change.
- **Change: Quick-search + column-filter coexistence** — the existing Code/Name search box and the new column-filter panel both write to the same `filterModel`; merge logic added so neither one clobbers the other's items.
- Success Criteria: SC-055, SC-056 added.
- No new [NEEDS CLARIFICATION] markers — scope (which columns get real filter support) was resolved by auditing the backend's existing `FilterMap`/`SortMap` whitelist before writing, consistent with this spec's established pattern of pre-write code audits (Update 13, 17, 19).
