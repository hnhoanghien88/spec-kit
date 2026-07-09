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
