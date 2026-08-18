# Specification Quality Checklist: Compliance Master Hierarchies

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-07-30
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

- All ambiguities in the original request (cycle-prevention scope, immediate-persist vs. draft/save, reuse of a master across branches, popup multi-select) were resolved with documented, low-risk defaults in the Assumptions section rather than blocking on clarification, since each had a reasonable default grounded in the referenced `eutr/templates/edit/{id}` screen's existing behavior.
- No [NEEDS CLARIFICATION] markers were needed; spec passed quality validation on the first pass.
- **2026-07-30 update**: Added User Story 5 (drag and drop) plus FR-022–FR-027, edge cases, SC-007, and supporting assumptions to cover reordering and re-parenting nodes by dragging them in the tree. The scope decision (drag-and-drop supports both sibling reorder and cross-parent re-parenting, reusing the existing Add child/Add root validation rules) was resolved as a documented assumption rather than a clarification question, since it mirrors standard tree-UI behavior and this spec's existing validation rules. Re-validated against all checklist items; still passes.
- **2026-07-30 update (follow-up 2)**: Added a Code/Name search textbox to the Add root / Add child picker popup — new acceptance scenarios under User Story 1, new edge cases, FR-025–FR-027, SC-008, and two supporting assumptions (single OR-match field; server-side re-query rather than client-side filtering of the loaded page). Resolved as documented defaults rather than clarification questions, since both follow the existing paginated-load pattern already specified for the popup. Re-validated against all checklist items; still passes.
- **2026-08-10 update**: Added User Story 6 (View condition directly from a tree row on the index screen, distinct from the existing picker-popup lookup in User Story 4) plus FR-028–FR-030, SC-009, three new edge cases, and two supporting assumptions (same underlying read-only lookup as the picker's View condition; independent of node selection). Resolved as documented defaults rather than clarification questions, since the read-only condition view and its data source already exist and are simply exposed at a second entry point. Re-validated against all checklist items; still passes.
- **2026-08-18 update (bug fix)**: Two critical duplicate-data bugs found in testing — (1) Add root only checked existing roots, not the whole tree, letting a master be added as root while already present elsewhere; (2) Add child only checked the ancestor chain (cycle prevention) and direct siblings, not the whole tree, letting a master be added under an unrelated parent while already present in a different branch. Revised FR-011–FR-013 to require a whole-tree duplicate check for both Add root and Add child, added a new Clarifications session documenting the reversal of the earlier "master may appear in multiple branches" assumption, updated User Story 1/2 acceptance scenarios, the Edge Cases list, Key Entities, Assumptions, and SC-002 accordingly. Re-validated against all checklist items; still passes.
- **2026-08-18 update, follow-up (delete confirmation correction)**: An initial pass at the 3rd reported item (delete confirmation) incorrectly concluded no code change was needed — reasoning that the confirmation popup was only ever intended for nodes with descendants. That was wrong: the user confirmed the popup must appear on EVERY delete, with the descendant-count warning as an addition (not a replacement) when the node has descendants. Reverted the earlier FR-015/User Story 3 wording change accordingly, and fixed `ComplMasterHierarchiesPage.jsx`'s `handleDeleteClick`/`ConfirmDialog` to always open the confirmation dialog, varying only the title/message/button label based on `descendantCount`. Re-validated against all checklist items; still passes.
