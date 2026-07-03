# Specification Quality Checklist: EUTR Templates Management

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-07-02
**Updated**: 2026-07-03
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
