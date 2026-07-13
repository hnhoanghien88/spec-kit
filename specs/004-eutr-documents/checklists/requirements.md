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
- 2026-07-07 `/speckit-clarify` session: resolved 3 remaining ambiguities interactively (Name
  column BIGINT→VARCHAR migration, allowed upload file types/size, no uniqueness constraint on
  File name). Recorded under spec.md `## Clarifications` and reflected in FR-007a, FR-007b, Key
  Entities, and Success Criteria SC-003a. All checklist items were already passing before this
  session and remain passing after — no regressions.
- 2026-07-07 `/speckit-specify` update: corrected scope per user feedback — the Add page collects
  information only (File name, Valid from, Valid to) with NO file selection/upload in this
  iteration; the file-type/size rule from the earlier clarify session is now deferred (FR-007a
  removed, superseded by FR-006's explicit "no upload control" statement). The View action is now
  documented as a non-functional placeholder icon (FR-013, User Story 5, SC-006). All checklist
  items remain passing after this correction.
- 2026-07-07 `/speckit-clarify` session 2: resolved 3 follow-up ambiguities from the scope
  correction above — toolbar button renamed "Upload" → "Add" (FR-005, FR-015), View icon confirmed
  to render active-looking with a silent no-op click (FR-013, User Story 5), and a Back button
  added to the Add page (new FR-006a, User Story 2, SC-007). All checklist items remain passing.
- 2026-07-07 `/speckit-specify` update 3: added the Type (PO/Manual) selector and the Screen1/
  Screen2 layouts from `docs/design/eutr/eutr_documents_overview.md` to the Add page, UI-only —
  resolved 3 clarifications interactively (existing File name/Valid from/Valid to fields and Save/
  Back kept working unchanged; List PO and the Manual file list render static demo data, not real
  PO/API data; all new interactions — drag-and-drop, Assign condition, View/Delete/checkbox in the
  demo tables — are silent no-ops). Reflected in User Story 2, new FR-016 to FR-020, new Key
  Entities note, SC-008/SC-009, and new Edge Cases. All checklist items remain passing after this
  update.
- 2026-07-08 `/speckit-specify` update 4: registered two D365 entities (`RSVNEutrPurchOrders` =
  `refType 15`, `RSVNEutrSalesOrderPurchases` = `refType 16`) in the existing generic reference
  endpoint `POST /api/dynamics/reference` (mirroring how `VendorsV3` is already registered as
  `refType 14`) — corrected from an earlier draft of this update that proposed two brand-new GET
  endpoints, per user feedback that integration must reuse the shared reference endpoint pattern
  instead. Resolved 2 clarifications interactively — the List PO grid's PO name column now sources
  real data via `refType = 15` (superseding the Update 3 demo data for that column only; File name
  stays a UI placeholder), while `refType = 16` is registered backend-only with no UI consumer in
  this feature. Reflected in Clarifications, User Story 2 (narrative + acceptance scenarios
  8/8a/8b), FR-021/FR-022, Key Entities notes, SC-010, and Edge Cases. As with Update 3 and the
  `003-eutr-templates` precedent, entity/refType names appear because the user's request named the
  specific D365 entities and controller pattern to mirror — these are treated as business-domain
  integration references, not incidental implementation detail. All checklist items remain passing
  after this update.
- 2026-07-08 `/speckit-specify` update 5: the PO search box above the List PO grid (Type = PO,
  introduced as an implementation detail during Update 4's build, not previously described in the
  spec) now MUST query the shared reference API (`refType = 15`) with the user's search term
  instead of filtering only the already-loaded page of PO data. Clearing the term reloads the
  unfiltered default list; a non-matching term shows the existing empty state (not an error). The
  prior comma-separated multi-term local-filter behavior is dropped in favor of a single free-text
  "contains" search, matching the pattern already used by other reference search inputs (e.g.
  `ReferenceObjectAutocomplete.jsx`). Reflected in Clarifications, User Story 2 (narrative +
  acceptance scenarios 8c/8d/8e), new FR-023, new Edge Cases, new SC-011, and a new Assumptions
  note. No [NEEDS CLARIFICATION] markers were needed — the request was unambiguous and scoped to a
  single, well-understood change. All checklist items remain passing after this update.
- 2026-07-08 `/speckit-specify` update 6: the "Drag and drop files to upload" area in Screen1
  (Type = PO) is replaced by a real **Upload** button — user selects (clicks) one PO row in List PO
  to enable it, picks multiple files via the OS file picker, and the system uploads them to
  SharePoint (new endpoint `POST /api/sharepoint/eutr-upload-multi` in the existing
  `SharePointController`, using config `SharePointEutrPath`, a new `_eutrUploadService` — not
  reusing `_complUploadService`), then creates one `eutr_documents` record per successfully uploaded
  file (File name = file name, Valid from = today, Valid to = max date sentinel `9999-12-31`,
  FileId = SharePoint file id). Screen2's drag-and-drop remains an unchanged silent no-op. Resolved
  2 clarifications interactively: (1) the selected PO is used only to locate/create the SharePoint
  destination folder — no PO reference is persisted on `eutr_documents`, so List PO's File name
  column stays blank as before; (2) the file type/size restriction deferred at Update 1 (PDF,
  DOC/DOCX, XLS/XLSX, JPG/PNG, max 10MB) is reactivated for this button. Reflected in Clarifications
  Update 6, User Story 2 narrative + acceptance scenarios 8/8f-8l, revised FR-006/FR-017/FR-019/
  FR-020, new FR-024 to FR-030, Key Entities, new SC-012 to SC-015, new Edge Cases, and new
  Assumptions notes. All checklist items remain passing after this update.
- 2026-07-08 `/speckit-specify` update 7: redesigned the Screen1 Upload area per a reference image
  (`upload.png`) — "Upload File" heading, dashed drop zone with a cloud-upload icon, "Drop file here
  or click to browse" text, a format/size subtext, and a chip row below — now supporting real
  drag-and-drop in addition to Update 6's click-to-browse. Added a new file-name validation: the
  file name must start with (case-insensitive) a `Prefix` that exists in `eutr_master_documents`
  (feature `002-eutr-masters`); files with no matching prefix are rejected with a clear warning
  (per-file, same non-blocking pattern as the format/size check). For each successfully uploaded
  file, the system now also inserts a linking row into `eutr_references` (`DocumentId` = the new
  `eutr_documents.Id`, `RefId` = the matched `eutr_master_documents.StepId`, `RefType` = the "PO"
  value of `TAKE_FROM_OPTIONS` (`0`), `RefValue` = the selected PO code). Resolved 2 clarifications
  interactively: (1) the reference image's file-type/size text ("PDF, DOCX, XLSX — max 50 MB") is
  NOT adopted — the Update 6 rule (PDF/DOC/DOCX/XLS/XLSX/JPG/PNG, max 10MB) stays in force; the
  image is a layout/style reference only; (2) since `Prefix` is unique only per (StepId, Prefix) —
  not globally — when a file name matches prefixes tied to multiple StepIds, the system
  auto-selects the `eutr_master_documents` record with the smallest `Id` rather than blocking the
  upload. Also documented (as an Assumption, not a spec clarification — a plan-level concern) that
  `eutr_references.RefId` currently has a FK constraint to `eutr_template_details(Id)` which
  conflicts with storing a `StepId` there; since `eutr_references` has no other real writer yet,
  this is flagged for a migration decision in `/speckit-plan`. Reflected in Clarifications Update 7,
  User Story 2 narrative, new acceptance scenarios 8m-8q, new Edge Cases, new FR-031 to FR-033, new
  Key Entities (`EUTR Master Document`, `EUTR Reference`), new SC-016 to SC-018, and new Assumptions
  notes. All checklist items remain passing after this update.
- 2026-07-08 `/speckit-specify` update 7 (correction): per direct user feedback, the Update 7 write
  target was changed from the existing `eutr_references.RefId` column to a **new** `StepId` column
  to be added to `eutr_references` — this cleanly resolves the FK conflict flagged above (no need to
  loosen/drop the existing `RefId` → `eutr_template_details` constraint; `RefId` is simply left
  unwritten by this feature). Updated FR-033, the `EUTR Reference` Key Entity, acceptance scenarios
  8i/8p, SC-018, the Independent Test note, and the Assumptions entry accordingly. All checklist
  items remain passing after this correction.
- 2026-07-08 `/speckit-specify` update 7 (correction 2): per direct user feedback, changed the
  ambiguous-prefix resolution rule — when a file name matches `Prefix` values tied to multiple
  distinct `StepId`s in `eutr_master_documents`, the system no longer picks a single winning record
  (the earlier "smallest `Id`" rule is superseded); instead it now inserts **one `eutr_references`
  row per matched `StepId`**, all sharing the same `DocumentId` (the one document created for that
  file), each with its own `StepId`/same `RefType`/same `RefValue`. Updated the Clarifications Q&A,
  User Story 2 narrative, acceptance scenario 8p, the relevant Edge Case, FR-032/FR-033, the `EUTR
  Master Document`/`EUTR Reference` Key Entities, SC-018, and the Assumptions entry accordingly. All
  checklist items remain passing after this correction.
- 2026-07-09 `/speckit-specify` update 8: the Step name/Type columns on the EUTR documents list
  (User Story 1) and the File name/Step name columns on the Add page's List PO grid (User Story 2,
  Screen1/Type=PO) are no longer permanently blank. Both now look up `eutr_references` by
  `DocumentId` (list) or by `RefType=0`/`RefValue`=selected PO code (List PO), joining `StepId` to
  `eutr_steps.Name` for Step name and mapping `RefType` to its `TAKE_FROM_OPTIONS` label for Type;
  rows with no matching `eutr_references` record keep showing blank, unchanged from before. No
  [NEEDS CLARIFICATION] markers were needed — the request was unambiguous; the multi-value display
  convention (chip + "+N more" + tooltip) was picked as an informed default matching the existing
  "Country Codes" column pattern in `useCountryGroupColumns.jsx`, since no data model change is
  needed (all required columns already exist from Update 7). Reflected in a new Clarifications
  Update 8 session, User Story 1 (narrative + new acceptance scenarios 2a/2b), User Story 2
  (narrative + updated scenario 8, new 8r, revised 8l), revised FR-003/FR-017, new FR-034 to FR-038,
  revised Key Entities (`EUTR Reference`), new SC-019/SC-020, revised/new Edge Cases, and revised/
  new Assumptions notes. All checklist items remain passing after this update.
- 2026-07-09 `/speckit-specify` update 9: the Delete function (User Story 4, single or bulk) MUST
  now also delete every `eutr_references` row whose `DocumentId` points to the deleted document —
  these rows are written by the Screen1 Upload flow (Update 7) and were previously left as orphans
  after a document delete. Resolved 2 clarifications interactively (informed defaults, no
  ambiguity requiring user input): (1) the document delete and its `eutr_references` cleanup are
  treated as a single per-document transaction — if the `eutr_references` deletion fails, that
  document is not deleted (rollback), but in a bulk delete this does not block deleting other
  documents in the same batch (per-item semantics, same pattern as FR-030's per-file upload
  handling); (2) documents with zero linked `eutr_references` rows are unaffected — the cleanup
  step simply deletes 0 rows, not an error. Also noted as an Assumption that
  `eutr_references_documentid_foreign` has no `ON DELETE CASCADE`, so this MUST be handled at the
  application level, not left to the database. Reflected in a new Clarifications Update 9 session,
  User Story 4 (narrative + new acceptance scenarios 4/5/6), revised FR-011/FR-012, new
  FR-039/FR-040, revised `EUTR Reference` Key Entity, new SC-021/SC-022, new Edge Cases, and a new
  Assumptions note. All checklist items remain passing after this update.
- 2026-07-09 `/speckit-specify` update 10: the View icon on the Action column (EUTR documents list,
  User Story 1) stops being a no-op placeholder — clicking it now opens an inline file-preview
  popup for the document's uploaded file, mirroring the exact pattern already built in
  `compliance-client/src/presentation/pages/compliance-detail` (`FilePreviewer.jsx`/
  `DialogFilePreviewer.jsx`) and its backend endpoint
  `ComplCompliancesController.GetFileByIds` (`[HttpGet("get-file-by-idref")]`) — a new mirrored
  endpoint `GET /api/eutr-documents/get-file-by-idref` is added to the existing
  `EutrDocumentsController`, reusing the same SharePoint read-with-metadata service (no new file
  service). On the Add page's List PO grid (Screen1, Type = PO), the File name column can show
  multiple linked files per PO row since Update 8 — the old row-level Action column View/Delete
  icons (silent no-op) are retired and replaced with a View and a Delete icon on each individual
  file entry. Resolved 3 clarifications interactively (asked directly to the user, given real UX/
  scope impact): (1) View/Delete apply per individual file entry, not per PO row, since a row can
  have multiple linked files; (2) a document with no `FileId` (created via the manual Save form,
  never uploaded) shows a disabled View icon with a "No file to view" tooltip rather than a
  friendly no-op message; (3) deleting a file only removes its `eutr_documents`/`eutr_references`
  rows (reusing the existing single-delete API, FR-011/FR-039/FR-040) and does NOT call any
  SharePoint file-delete API — the physical file stays on SharePoint. Reflected in a new
  Clarifications Update 10 session, User Story 1 (narrative + new acceptance scenarios 5/6/7),
  User Story 2 (narrative + new acceptance scenarios 8s-8v), a rewritten User Story 5 (no longer a
  placeholder), revised FR-013/FR-017/FR-019, new FR-041 to FR-045, revised Key Entities
  (`EUTR Document`, new `SharePoint File Content`), revised SC-006/SC-009, new SC-023/SC-024, new
  Edge Cases, revised FR-015, and new Assumptions notes. All checklist items remain passing after
  this update.
- 2026-07-10 `/speckit-specify` update 11: Screen2 ("Upload manual") stops being a UI-only demo — the
  static drag-and-drop area is replaced by the same "Upload File" component built for Screen1
  (Update 7), but always enabled (no PO selection required) and without the prefix check; uploaded
  files land in a fixed `{SharePointEutrPath}/UploadManual` SharePoint folder (auto-created) and each
  becomes an `eutr_documents` row with no `eutr_references` yet. The file grid below now loads every
  `eutr_documents` row that has no `eutr_references` at all (regardless of how it was created), with
  real per-row View/Delete (reusing the Update 10 List PO logic) and multi-select checkboxes. The
  "Assign condition" button opens a real popup (per `condition.png`): a fixed, mandatory "Step" row
  plus user-added "Conditions type" (PO/Vendor) rows whose "Condition value" multi-select loads from
  the shared `POST /api/dynamics/reference` endpoint (`refType=15` for PO, `refType=14` for Vendor).
  Saving writes one `eutr_references` row per selected file (`RefType=1`, the file's chosen Step,
  `RefValue=null`) plus one `eutr_reference_details` row per chosen condition value (`ConditionType`
  = the refType used, `ConditionValue` = the chosen value) — the `eutr_reference_details` table
  already existed in `eutr_db.sql` with no migration needed. The main list's previously-always-blank
  Conditions column now shows these grouped values (e.g. "PO: PO1, PO2") for "Upload manual" rows.
  No [NEEDS CLARIFICATION] markers were needed — the request was fully detailed (including two
  reference images), so ambiguous points (the `ConditionType` numeric convention, one
  `eutr_references` row per selected file, no edit/reassign after save, removable condition rows)
  were resolved as informed defaults, documented as embedded Q&A in a new Clarifications Update 11
  session, matching this spec's established self-documenting convention. Reflected in a new
  Clarifications Update 11 session, revised User Story 1 (narrative + new acceptance scenarios
  2c/2d), revised User Story 2 (Screen2 narrative + revised acceptance scenarios 9/10), a new User
  Story 6 (20 acceptance scenarios), revised FR-003/FR-006/FR-018/FR-019/FR-036, new FR-046 to
  FR-054, a new `EUTR Reference Detail` Key Entity, revised `EUTR Reference`/`Type (PO/Manual)` Key
  Entities, a new `SharePoint Folder "UploadManual"` Key Entity, new SC-025 to SC-029, revised
  SC-008/SC-009, new Edge Cases, and revised/new Assumptions notes. All checklist items remain
  passing after this update.
- 2026-07-10 `/speckit-specify` update 11 (correction): per direct user feedback, tightened the Save
  validation in the Assign condition popup — Update 11's original rule let Save succeed with only a
  Step selected (no Conditions type row required); it now also requires **at least one** Conditions
  type row with at least one Condition value chosen, blocking Save with a clear warning otherwise
  (in addition to the existing block when Step is unselected). Updated the Clarifications Update 11
  "Change"/Q&A entries, User Story 6 acceptance scenarios 11/11a/19, FR-052, the `EUTR Reference
  Detail` Key Entity note, and SC-027/SC-028. All checklist items remain passing after this
  correction.
- 2026-07-10 `/speckit-specify` update 12: the Edit action on the main EUTR documents list (User
  Story 3) now branches by document Type instead of always opening the same simple popup. Type =
  "PO" keeps the simple popup (File name/Valid from/Valid to) but adds a single-select Step field
  pre-filled with the document's current Step; saving replaces the document's entire
  `eutr_references` row-set (there can be more than one if Update 7's prefix match hit multiple
  Steps) with exactly one row carrying the newly chosen `StepId`. Type = "Upload manual" no longer
  opens the simple popup at all — Edit reopens the Update 11 Assign-condition popup in an edit mode
  scoped to that single document (read-only file name at the top, no checkbox), pre-loaded with its
  current Step and Conditions type/value groups; saving updates the existing `eutr_references` row's
  `StepId` directly (no new row) and replaces the document's entire `eutr_reference_details` set
  (delete-all-then-reinsert, not a diff/merge) — both choices (single-select Step; full-replace
  Conditions) were confirmed directly with the user via two clarifying questions before drafting,
  given the real data/UX impact of guessing wrong. Documents with no `eutr_references` (blank Type)
  keep the unchanged simple-popup behavior. File name/Valid from/Valid to remain unreachable via
  Edit for "Upload manual" documents in this update's scope (explicit user request only mentioned
  Step/Conditions), noted as a deliberate, revisitable limitation. Reflected in a new Clarifications
  Update 12 session, revised User Story 3 (narrative + 11 acceptance scenarios), revised
  FR-009/FR-010, new FR-055 to FR-058, revised `EUTR Reference`/`EUTR Reference Detail` Key Entities,
  new SC-030 to SC-033, new/revised Edge Cases, and new Assumptions notes. All checklist items
  remain passing after this update.
- 2026-07-10 `/speckit-clarify` session (Update 13): resolved 2 remaining ambiguities interactively
  before planning — (1) when a Type = "PO" document links to multiple Steps, the Edit popup's Step
  dropdown now deterministically pre-fills the Step tied to the `eutr_references` row with the
  smallest `Id` (earliest-created), instead of an unspecified "first one found"; (2) the Assign
  condition popup's "Conditions type" dropdown now disables types already used by another row in
  the same popup, so a Save can never produce two rows of the same Conditions type (create or edit
  mode) — closing a gap where duplicate/ambiguous condition groupings were unaddressed. Recorded
  under spec.md `## Clarifications` as a new "Session 2026-07-10 (Update 13)" entry and reflected in
  revised FR-051/FR-055, new User Story 3 scenario 7a, new User Story 6 scenarios 12a/12b, new Edge
  Cases, and new SC-034. All checklist items remain passing after this session — no regressions.
