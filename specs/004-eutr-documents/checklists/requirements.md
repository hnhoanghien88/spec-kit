# Specification Quality Checklist: EUTR Documents Management

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-07-07
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

- Items marked incomplete require spec updates before `/speckit-clarify` or `/speckit-plan`
- 2026-07-07 → 2026-07-23 (Updates 1-18): the spec evolved through a separate Add page, Screen1
  (List PO + real SharePoint upload)/Screen2 (Upload File + "Assign condition" popup writing
  `eutr_reference_details`) layouts, and finally a unified "Add EUTR documents" popup
  (Type/Step/Value chips/Upload) that replaced the old Add page. Edit still branched by Type across
  a simple popup (PO) and the Assign-condition popup (Upload manual). Full history of that period is
  condensed in spec.md's Clarifications section; see prior git history of this file for the
  per-update checklist notes if needed.
- 2026-07-23 `/speckit-specify` update 19: per direct user request, consolidated **Add** and **Edit**
  onto a single reused popup, and simplified the **Conditions** column's data source. (1) Removed the
  old separate Add page, Screen1/Screen2 layouts, and the "Assign condition" popup entirely from
  scope — `eutr_reference_details` is no longer read or written by this feature (table itself is left
  untouched in the schema). (2) The Conditions column now shows every non-null `RefValue` from a
  document's `eutr_references` rows as a chip, for every Type (previously blank for Type = "PO" and
  sourced from `eutr_reference_details` only for Type = "Upload manual"). (3) The Add popup gained two
  new fields, **Valid from** (default: today) and **Valid to** (default: max date `9999-12-31`), both
  editable before Upload and used as the created document(s)' Valid from/Valid to. (4) **Edit** now
  reopens the same Add popup in an edit mode: Type is locked (disabled), the chip Value area is
  read-only, and only Step and Valid from/Valid to remain editable; Save updates the document's
  `ValidFrom`/`ValidTo` directly and updates `StepId` on every linked `eutr_references` row (no
  add/remove of rows, `RefValue`/`RefType` unchanged). No [NEEDS CLARIFICATION] markers were needed —
  the request was unambiguous; a few mechanics (how Edit's Save applies one chosen Step across
  multiple existing `eutr_references` rows; how a legacy document with no `eutr_references` at all
  behaves in Edit) were resolved as informed defaults and documented as embedded Q&A in the new
  Clarifications "Session 2026-07-23 (Update 19)" entry. spec.md was substantially rewritten (all User
  Stories, Requirements, Key Entities, Success Criteria, and Assumptions sections) to reflect only the
  current end-state and drop now-removed historical flows, per the user's explicit request to fully
  remove the old Add/Edit/Assign logic. All checklist items pass after this rewrite — no regressions;
  downstream artifacts (plan.md, tasks.md, data-model.md, contracts, quickstart.md, research.md) still
  reflect the pre-Update-19 design and should be regenerated via `/speckit-plan` and `/speckit-tasks`.
- 2026-07-24 `/speckit-specify` update 20: per direct user request, the Step combobox in the Add/Edit
  popup (Type other than "PO") now only lists Steps that have an "Assign Steps" record in
  `eutr_reference_type_details` for the currently selected Type (`TypeId` match), instead of every row
  in `eutr_steps`; the combobox also defaults to the first row of that filtered list in Add mode (no
  longer opens empty). Edit applies the same filter against the document's current (locked) Type, but
  always guarantees the document's existing Step stays selectable even if it was later unassigned from
  that Type in the "Assign Steps" screen (`006-eutr-reference-types`) — avoids silently discarding
  existing data. Added FR-043/FR-044/FR-045, SC-010, two new Edge Cases, a new read-only Key Entity for
  `eutr_reference_type_details`, and two new Assumptions; extended User Story 2 and User Story 3
  narratives/acceptance scenarios accordingly. No [NEEDS CLARIFICATION] markers were needed — the two
  edge behaviors (empty filtered list; current Step no longer in the filtered list) were resolved as
  informed defaults and documented as embedded Q&A in the new "Session 2026-07-24 (Update 20)" entry.
  All checklist items pass after this update — no regressions; downstream artifacts (plan.md, tasks.md,
  data-model.md, contracts, quickstart.md, research.md) still reflect the pre-Update-20 design and
  should be regenerated via `/speckit-plan` and `/speckit-tasks`.
- 2026-07-24 `/speckit-specify` update 21: per direct user request, added a **search box** above the
  main list (Type dropdown / Step name dropdown / Conditions free-text / Search button) letting users
  filter the document list. Added User Story 6, FR-046 through FR-050, SC-011, two new Edge Cases, and
  three new Assumptions (client-side filter reusing the existing list API; Step name dropdown lists
  all `eutr_steps` independent of the Type selected in the same search box, unlike the Assign-Steps
  filter in the Add/Edit popup from Update 20; Conditions uses a case-insensitive "contains" match). No
  [NEEDS CLARIFICATION] markers were needed — three embedded Q&A entries in the new "Session
  2026-07-24 (Update 21)" Clarifications section resolve the filter-combination semantics (independent
  per-criterion match, not required on the same `eutr_references` row), search trigger (button click
  only, no live search), and Step name dropdown scope (unfiltered by Type) as informed defaults. All
  checklist items pass after this update — no regressions; downstream artifacts (plan.md, tasks.md,
  data-model.md, contracts, quickstart.md, research.md) still reflect the pre-Update-21 design and
  should be regenerated via `/speckit-plan` and `/speckit-tasks`.
- 2026-07-24 `/speckit-specify` update 22: per direct user request, the Edit popup's chip **Value**
  area is no longer universally read-only — for any document Type **other than "PO"** (including
  "Vendor"), the chip area now behaves like Add: an editable Value combobox (same per-Type suggestion
  source as FR-011/FR-012) to add new chips, and a delete button on each existing chip, still subject
  to the existing max-1-chip rule for "Vendor" (FR-013) and a minimum of 1 chip at Save time. Save now
  reconciles `eutr_references` against the displayed chip set for Type != "PO" (create rows for newly
  added chips, delete rows for removed chips, update `StepId` on all remaining rows) instead of only
  updating `StepId`; Type = "PO" keeps the prior fully-read-only/Step-only-update behavior unchanged.
  Updated FR-028/FR-033, added FR-051 through FR-055, SC-012, new acceptance scenarios 13-18 and edge
  cases under User Story 3, and two new Assumptions. No [NEEDS CLARIFICATION] markers were needed — the
  one real fork (whether "Vendor", which also caps at 1 chip, is treated like "PO" or like the other
  editable types) was resolved as an informed default favoring the literal request wording ("type khác
  PO" includes Vendor) and documented as embedded Q&A in the new "Session 2026-07-24 (Update 22)"
  Clarifications entry. All checklist items pass after this update — no regressions; downstream
  artifacts (plan.md, tasks.md, data-model.md, contracts, quickstart.md, research.md) still reflect the
  pre-Update-22 design and should be regenerated via `/speckit-plan` and `/speckit-tasks`.
- 2026-08-17 `/speckit-specify` update 23: per direct user request, the Add popup gains a new
  **Invoice number** field (free-text string, required) shown only when Type = "Invoice"; on
  successful Upload its value is written to a new column **`Invoice`** on the `eutr_documents` row
  created for that document (one document per uploaded file). Edit mirrors this: when the document's
  (locked) Type = "Invoice", the field is pre-filled from that document's own `Invoice` value and
  remains editable/required; Save updates `eutr_documents.Invoice` directly, the same way Save already
  updates `ValidFrom`/`ValidTo` — no `eutr_references` row is read or written for this field. Added
  FR-056 through FR-060, SC-013/SC-014, three new/updated Edge Cases, updated both the EUTR Document
  and EUTR Reference Key Entities, and four new Assumptions; extended User Story 2 and User Story 3
  narratives/acceptance scenarios. Two clarifying questions were asked via `AskUserQuestion` before the
  first draft (both resolved to the recommended/only sensible option): (1) Invoice number is
  **required** before Upload/Save, not optional; (2) the value **is editable** in Edit mode, not
  read-only. A third point — the same Invoice number value applies uniformly to every document created
  within one Upload batch, mirroring the Valid from/Valid to pattern from Update 19 — had only one
  sensible interpretation and was recorded directly as an Assumption rather than asked.
  **Immediately after the first draft**, a follow-up user message changed the storage target: "không
  lưu Invoice vào bảng eutr_references, chuyển sang lưu vào bảng eutr_documents, cột Invoice" — the
  entire Update 23 section, User Story 2/3 text, Edge Cases, FR-056–FR-060, both Key Entities,
  SC-013/SC-014, and the Assumptions were revised in place to read/write `eutr_documents.Invoice`
  instead of `eutr_references.Invoice`; this also **removed** the need for the "lowest-`Id` row" lookup
  rule Update 23's first draft had borrowed from Step (FR-032), since `eutr_documents` is already
  one-row-per-document. All checklist items pass after this update — no regressions; downstream
  artifacts (plan.md, tasks.md, data-model.md, contracts, quickstart.md, research.md) still reflect the
  pre-Update-23 design (including the DB migration for the new `Invoice` column on `eutr_documents`)
  and should be regenerated via `/speckit-plan` and `/speckit-tasks`.
- 2026-08-17 `/speckit-specify` update 24: per direct user request, the main list (User Story 1) gains
  a new **Invoice** column placed immediately after **Step name** (full order: File name, Step name,
  Invoice, Conditions, Type, Valid from, Valid to, Created by, Created date, Action). Unlike Step
  name/Conditions/Type, it reads directly from `eutr_documents.Invoice` (added in Update 23, one value
  per document) — no `eutr_references` JOIN needed — and renders as plain text (not a chip list), since
  a document only ever has one Invoice value. Blank when `Invoice` is `null`. Added FR-061, SC-015, two
  new acceptance scenarios under User Story 1, one new Edge Case, and updated the EUTR Document Key
  Entity. No `[NEEDS CLARIFICATION]` markers were needed — the two embedded Q&A entries in the new
  "Session 2026-08-17 (Update 24)" Clarifications section (plain text vs. chip rendering; whether the
  search box also gains an Invoice filter) were resolved as informed defaults matching the request's
  literal scope. All checklist items pass after this update — no regressions; downstream artifacts
  (plan.md, tasks.md, data-model.md, contracts, quickstart.md, research.md) still reflect the
  pre-Update-24 design and should be regenerated via `/speckit-plan` and `/speckit-tasks`.
