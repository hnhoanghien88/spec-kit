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
- 2026-09-18 `/speckit-specify` update 25: per direct user request, every file uploaded through the
  shared Add popup now gets an **automatically computed File name** instead of keeping the user's
  original file name: (Prefix from `eutr_master_documents`, if the relevant Step has a configured row
  there) + the Step's `Name`, sanitized (invalid filename characters and any `..` sequence stripped,
  falling back to `Step{StepId}` if the result would be empty) + the original file's extension. For
  Type other than "PO" this uses the explicitly chosen Step; for Type = "PO" the existing prefix-match
  logic that can resolve multiple Steps (FR-020/FR-023, unchanged) is kept exactly as-is, with one new
  step added afterward that picks the master row with the **longest matching Prefix** to source the
  name. Added FR-062 through FR-067, SC-016, six new acceptance scenarios under User Story 2, five new
  Edge Cases, six new Assumptions, and updated FR-021 plus the EUTR Document / EUTR Master Document Key
  Entities. Also documented (in the new "Session 2026-09-18 (Update 25)" Clarifications entry and in
  the Assumptions) that `005-eutr-sales-orders` and `012-eutr-purchase-orders` inherit this behavior
  automatically since both call the exact same shared Upload/Add-popup flow with no naming logic of
  their own — matching one-line cross-reference notes were added to those two specs' own Clarifications
  sections rather than duplicating any requirement text there. Three clarifying questions were asked via
  `AskUserQuestion` before drafting (real product-impact forks with no safe default): (1) whether the
  new rename logic applies to Type = "PO" at all, given Step there is inferred rather than user-chosen
  — resolved to "yes, as an additional step after the existing prefix-match, not a replacement for it";
  (2) whether the new name fully replaces the original file name or keeps it as a traceability suffix —
  resolved to full replacement; (3) for Type = "PO" matching multiple Steps at once, which Step/Prefix
  to use for the single physical file's name — resolved to the longest-matching Prefix (most specific
  match), with lowest-`Id` as the tie-breaker. Lower-impact mechanics (no separator between Prefix and
  Step Name; picking the lowest-`Id` master row when one Step has several Prefix rows; keeping the
  original extension casing as-is; Edit never recomputing an existing document's File name) were
  resolved as informed defaults and recorded as Assumptions rather than asked. All checklist items pass
  after this update — no regressions; downstream artifacts (plan.md, tasks.md, data-model.md, contracts,
  quickstart.md, research.md) still reflect the pre-Update-25 design (including the sanitize/rename
  logic itself, which has no existing implementation to reuse per research) and should be regenerated
  via `/speckit-plan` and `/speckit-tasks`.
- 2026-09-24 `/speckit-specify` update 26: per direct user request (after confirming scope via
  `AskUserQuestion` — the Update 25 rename-on-upload behavior already existed, so the ask was to verify
  what specifically should change), the computed File name formula drops the **Prefix** component
  entirely — it is now just the Step's sanitized `Name` + original extension, for both the Type = "PO"
  and Type-other-than-"PO" branches. The Prefix-based tie-break used to pick a winning
  `eutr_master_documents` row when Type = "PO" matches multiple Steps is unchanged (still needed to pick
  which Step's name to use) — only the act of concatenating that row's `Prefix` text into the file name
  is removed. Added FR-068 through FR-070 (superseding the naming half of FR-062/FR-063, which are kept
  as historical record per this repo's convention rather than rewritten in place), SC-017 (SC-016
  annotated as superseded), one new Edge Case replacing an obsolete one, two new Assumptions replacing
  obsolete ones, and corrected the specific acceptance-scenario/quickstart example values that stated
  concrete Prefix-inclusive file names (since those are testable pass/fail criteria, not just narrative
  history). Documented that `005-eutr-sales-orders`/`012-eutr-purchase-orders` inherit this change
  automatically (no code of their own) via a one-line cross-reference note in each spec's own
  Clarifications section. One clarifying question was asked before drafting (the request as literally
  stated already matched existing FR-062/FR-063 — real scope ambiguity with no safe default): what,
  concretely, should differ from the already-implemented Update 25 behavior — resolved to "drop the
  Prefix, keep only the Step Name." All checklist items pass after this update — no regressions;
  `plan.md`/`data-model.md`/`research.md`/`tasks.md`/`contracts/eutr-documents-api.md` were updated in
  place (not regenerated) to match this repo's established per-update-append convention, and the
  `EutrUploadService.cs`/`IEutrMastersRepository.cs`/`EutrMastersRepository.cs` code changes described
  here should be applied to match.
- 2026-09-24 `/speckit-specify` update 27: per direct user request to allow one Step to hold multiple
  files of different extensions (e.g. `.pdf` and `.xml`) sharing the same Prefix, with the matching
  files clearly shown together in the view — codebase research (before drafting) found this almost
  entirely already works: no unique/dedupe constraint exists anywhere blocking multiple
  `eutr_documents`/`eutr_references` rows from sharing one `StepId`, and the Step-tree UI in
  `005-eutr-sales-orders` (`MapFilePage.jsx`) and `012-eutr-purchase-orders`
  (`PurchaseOrderViewPage.jsx`, a clone of the same tree) already renders a "(+N)" badge and a tooltip
  listing every matching file's name whenever more than one file maps to a Step node. The one real gap:
  `.xml` was not in the upload's allowed-extension whitelist (and `.json`/`.geojson` never were), so the
  `.pdf` + `.xml` scenario in the request was blocked at format validation before ever reaching the
  already-working matching/display logic. Confirmed this narrowed scope directly with the user via
  `AskUserQuestion` before drafting (a real, high-impact fork — building a second file-grouping
  mechanism versus just widening the whitelist — with no safe default) — user confirmed: just add
  `.xml`, `.json`, `.geojson`. Added FR-071/FR-072 (extending FR-018's format list; documenting the
  already-existing multi-file-per-Step behavior as an explicit requirement, since it had never actually
  been exercised with `.xml`), SC-018, two new acceptance scenarios, one new Edge Case, one new
  Assumption. No [NEEDS CLARIFICATION] markers — the single real fork was resolved via the
  `AskUserQuestion` above rather than left open. All checklist items pass after this update — no
  regressions; downstream artifacts were updated to match (`plan.md`, `data-model.md`, `research.md`,
  `tasks.md` Phase 32, `contracts/eutr-documents-api.md`), and the `EutrUploadService.cs`
  (`AllowedExtensions`) plus `EutrDocumentsFormDialog.jsx` (`ALLOWED_EUTR_UPLOAD_EXTENSIONS`, the one
  frontend file this update touches) code changes described here should be applied to match.
- 2026-09-24 `/speckit-specify` update 28: per direct user request ("mở giới hạn file upload lên
  20MB"), the per-file size limit rises from 10MB to 20MB — checked Kestrel's `MaxRequestBodySize`
  (`Program.cs`, already 200MB API-wide) before drafting to confirm no server-level infrastructure
  change was needed. Updated FR-018 in place (small numeric change, unlike the format-list expansion at
  Update 27 which was superseded via a new FR) and added FR-073 documenting the change explicitly,
  SC-019, corrected the one existing acceptance scenario that stated the old "vượt quá 10MB" threshold
  (a testable pass/fail criterion, not just narrative history) plus the primary-flow narrative text, and
  added one new acceptance scenario for the 10MB–20MB range. No [NEEDS CLARIFICATION] markers — trivial,
  unambiguous numeric change with no reasonable alternative reading. All checklist items pass after this
  update — no regressions; downstream artifacts were updated to match (`plan.md`, `data-model.md`,
  `research.md`, `tasks.md` Phase 33, `contracts/eutr-documents-api.md`), and the
  `EutrUploadService.cs`/`EutrDocumentsFormDialog.jsx` size-limit constant changes described here should
  be applied to match.
