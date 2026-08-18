# Specification Quality Checklist: Sales Order Missing-Compliance Alert

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-08-03
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

- The user's original request named specific existing controllers, services, and endpoints (e.g. `test-alert`, `DynController.reference` with reftype 18, `ViewCompliancesController.get-all`, table `compl_so_missing`). These are recorded as reusable existing dependencies in the Assumptions section rather than as new implementation choices, keeping the Functional Requirements and Success Criteria technology-agnostic.
- All items pass on first validation pass; no iteration was required.
- **2026-08-04 update**: Spec revised to replace the per-sales-order-code delete-before-insert step (`DeleteBySalesIdAsync`) with a single delete-all-records step run once before the evaluation loop begins. Updated User Story 1 acceptance scenarios, Edge Cases (duplicate sales order codes now accumulate within a run instead of being replaced; a failed lookup now leaves that sales order with no records for the run, since nothing remains to fall back to), FR-006, the Missing Compliance Record entity description, SC-002, and the store-related Assumptions. Re-validated against all checklist items; all still pass.
- **2026-08-10 update**: Spec revised to finalize the exact 14-column layout of the consolidated alert and to specify that its Status and Days remaining columns are recomputed at alert-generation time from each record's Code and Valid To, rather than reused from stored values. Added User Story 2 acceptance scenarios 4-10, two new Edge Cases (Valid To equal to today; a record originally captured as MISSING later displaying as "Expired"), FR-012 through FR-014, updated the Compliance Alert Notification entity, added SC-005, and added three Assumptions (default "Valid" status label, Days remaining sign convention, no change to Responsible emails resolution). Re-validated against all checklist items; all still pass.
- **2026-08-10 update (Excel attachment)**: Spec revised to require an Excel attachment on every sent alert email, mirroring the email body's columns/data, named `compl-sales-order-missing-<yyyyMMddHHmmss>`. Added User Story 2 acceptance scenarios 11-13, two new Edge Cases (same-second timestamp collision; attachment-generation failure handling), FR-015 through FR-017, updated the Compliance Alert Notification entity, added SC-006, and added three Assumptions (`.xlsx` extension inferred, distinct from the existing per-record file-attachment behavior, same-second collision accepted as low-probability). Re-validated against all checklist items; all still pass.
- **2026-08-18 update (deduplicate and drop Sales order column)**: Spec revised so the alert-building read deduplicates missing-compliance records by Master code, Code, Type, and Product, and the Sales order column is removed from both the email body and the Excel attachment (the underlying `compl_so_missing` store and its per-sales-order population are unchanged). Added User Story 2 acceptance scenario 14, two new Edge Cases (records sharing the four-column key collapsing into one row; a hypothetical mismatch among the non-key columns for the same key), updated FR-008 and FR-012, updated the Missing Compliance Record and Compliance Alert Notification entities (14 columns → 13, no Sales order column), added SC-007, and added two Assumptions (why the four-column dedup is safe; that this change is scoped to the alert read/display, not the store). Re-validated against all checklist items; all still pass.
