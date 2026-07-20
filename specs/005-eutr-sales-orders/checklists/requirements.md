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
