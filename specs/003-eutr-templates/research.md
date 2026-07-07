# Research: EUTR Templates Management

**Feature**: 003-eutr-templates | **Date**: 2026-07-03

## 1. VendorsV3 D365 Integration

**Decision (superseded by Section 16 — Update 5, 2026-07-06)**: ~~Add a dedicated
`GET /api/dynamics/vendors` endpoint in `DynController` following the `data-area` pattern,
instead of using the generic reference API.~~ Reverted — see Section 16. This entry is kept for
historical context only; the dedicated endpoint it describes still exists in `DynController.cs`
but is no longer the vendor data source for this feature.

**Original rationale (2026-07-03, no longer current)**: The codebase already integrates with
D365 via OData through `IDynamicService` + `DynamicsParameterManager`. The `data-area` endpoint
pattern (`[HttpGet]` with `skip`, `top`, `filter`, `order_by` query params → `SetEntity()` →
`ParseAndValidate()` → `QueryAsync()` → return raw OData JSON) was judged the simplest approach
for dedicated entity lookups. The generic reference API (`POST /api/dynamics/reference` with
refType=13) already has a `VendorsV3` mapping in `ComplDynamicsService`, but at the time this was
seen as introducing unnecessary indirection due to a known `ReferenceObjectAutocomplete`
`referenceType === 13 → refType 4` quirk on initial load.

**Alternatives considered (original decision)**:
- Fix the `ReferenceObjectAutocomplete` referenceType 13→4 conversion bug — rejected at the time:
  the component is shared and changing its behavior may break other consumers.
- Use the generic reference API with corrected refType — rejected at the time: judged to add
  unnecessary abstraction when a direct OData query seemed simpler.
- Direct D365 OData calls from frontend — rejected: violates the backend-mediated architecture.

**Implementation (historical, from the now-reverted decision)**:
1. `VendorsV3.cs` already exists in `Domain/Dynamics/` — no changes needed.
2. `[HttpGet("vendors")]` method was added to `DynController.cs` following the `data-area`
   pattern — still present in the codebase but unused by this feature after Update 5.
3. `DynamicsParameterManager` (from `Res.Shared.ExternalServices` v1.0.11 NuGet package) does not
   have a `SetSelect()` method; `$select` was appended manually to the URL string.
4. See Section 16 for the current (Update 5) approach.

---

## 2. Tree View Component

**Decision**: Use `@mui/x-tree-view` (`SimpleTreeView` + `TreeItem2`) with custom content rendering for checkboxes, action buttons, and step metadata.

**Rationale**: The package is already installed in `package.json` but unused. It integrates natively with the MUI ecosystem (theming, icons, sx props) used throughout the frontend. Supports expand/collapse, multi-selection, and custom item rendering out of the box.

**Alternatives considered**:
- Custom recursive component with `<List>` — rejected: reinvents collapse/expand state, keyboard nav, and accessibility already handled by `@mui/x-tree-view`.
- `react-arborist` — rejected: adds a new dependency when a compatible one is already installed.

---

## 3. Drag-and-Drop for Step Reordering

**Decision**: Use `@dnd-kit/core` + `@dnd-kit/sortable` for drag-and-drop reordering within the step tree.

**Rationale**: Both `@dnd-kit` packages are already installed (v6.3.1 core, v10.0.0 sortable). `@dnd-kit` is the modern standard for React DnD — it supports tree-like sortable contexts, keyboard-accessible dragging, and smooth animations. It composes well with `@mui/x-tree-view` by wrapping tree items in sortable containers per tree level.

**Alternatives considered**:
- `react-beautiful-dnd` — rejected: also installed but unmaintained (last release 2022), poorer tree support, and deprecated in favor of `@dnd-kit`.
- Native HTML5 drag-and-drop — rejected: inconsistent browser behavior, no built-in animation, poor accessibility.

**Implementation**: Group sibling steps (same `ParentId`) into `SortableContext` containers. Each step item uses `useSortable` hook. On drag end, recalculate `DisplayOrder` for all siblings at the affected level.

---

## 4. Code Auto-Generation Strategy

**Decision**: Backend generates `Code` on create by querying the max existing code number, incrementing, and padding. Default configuration: prefix = `"Templates"`, separator = `"-"`, padding = 3 digits.

**Rationale**: Server-side generation ensures uniqueness even under concurrent creates. The `Code` column has no UNIQUE constraint in the DB schema, but sequential generation with `MAX()` query + increment provides practical uniqueness. A future configuration feature will allow customizing prefix and padding.

**Alternatives considered**:
- GUID-based codes — rejected: spec explicitly requires human-readable sequential codes (e.g., `Templates-001`).
- Database auto-increment with formatting — rejected: MySQL auto-increment doesn't support prefix/padding formatting.

**Implementation**:
1. In `EutrTemplatesService.AddAsync()`, before insert:
   - Query `SELECT MAX(CAST(SUBSTRING_INDEX(Code, '-', -1) AS UNSIGNED)) FROM eutr_templates`
   - Increment by 1, pad to configured width
   - Concatenate: `{prefix}{separator}{paddedNumber}`
2. Default values hardcoded until the configuration feature is built.
3. Thread safety: handled by the transaction isolation level (ReadCommitted) already used in `BaseService.AddAsync`.

---

## 5. Template Versioning Mechanism

**Decision**: On edit/save, the backend creates a new template row with `VersionId + 1`, copies all template details to the new template ID (applying changes), and marks the old row `IsHide = 1`. All within a single transaction.

**Rationale**: This preserves a complete audit trail — every version of every template remains in the database. The grid filters `IsHide=0 AND IsDeleted=0` to show only the latest active version. This is a spec-mandated business rule, not an implementation choice.

**Implementation** (in `EutrTemplatesService.UpdateAsync`):
1. Begin transaction
2. Load old template + details
3. Create new template row: same Code, updated fields, `VersionId = old.VersionId + 1`, `IsHide = 0`, `IsDeleted = 0`
4. Insert new template details (from request, with new `TemplateId`)
5. Set old template `IsHide = 1`
6. Handle IsDefault constraint (see below)
7. Commit transaction

---

## 6. IsDefault Constraint Enforcement

**Decision**: Backend enforces the "max 1 default per VendorCode" constraint by clearing existing defaults before setting a new one, within the same transaction.

**Rationale**: Server-side enforcement prevents race conditions. The constraint applies only to active records (`IsDeleted=0, IsHide=0`).

**Implementation**:
1. In both `AddAsync` and `UpdateAsync`, if `IsDefault = 1` and `VendorCode` is not null:
   - Execute: `UPDATE eutr_templates SET IsDefault = 0 WHERE VendorCode = @vendorCode AND IsDefault = 1 AND IsDeleted = 0 AND IsHide = 0 AND Id != @currentId`
2. If `VendorCode` is null and `IsDefault = 1`: clear defaults for all templates where `VendorCode IS NULL`.

---

## 7. Import Pattern

**Decision**: Follow the `eutr-masters` import pattern using ClosedXML for Excel reading.

**Rationale**: Proven pattern in the codebase. Consistent UX with existing import features.

**Implementation**:
- Excel columns: Name, VendorCode, AlertFor, IsDefault
- Code is auto-generated per row (not imported)
- VersionId defaults to 1
- Validation: Name and AlertFor required
- Duplicate handling: report but allow (no unique constraint on Name)
- Result DTO: `{ TotalRows, SuccessCount, FailCount, Errors[] }`

---

## 8. Step Deletion Cascade

**Decision**: When a step is deleted from the tree (either single via icon X or batch via checkbox + Delete), all child steps are recursively removed from the in-memory tree. This is a client-side operation — the final tree state is sent to the backend on Save.

**Rationale**: The step tree is managed entirely in frontend state during add/edit. Steps are not individually persisted until the user clicks Save. Cascade deletion is a UI behavior, not a database cascade.

**Implementation**: Recursive function in `useStepTree` hook: `removeStepAndChildren(stepId)` filters out the step and all descendants from the tree state array.

---

## 9. Vendor Combobox — Dedicated Endpoint (superseded by Section 16 — Update 5)

**Decision (historical, reverted 2026-07-06)**: ~~Replace the vendor combobox implementation to
call the new dedicated `GET /api/dynamics/vendors` endpoint instead of the generic reference
API.~~ See Section 16 for the current approach.

**Original rationale**: The previous approach used `ReferenceObjectAutocomplete` with
`referenceType={13}`, which has a known quirk: initial load calls
`fetchReferenceObjects(4, ...)` instead of `fetchReferenceObjects(13, ...)`, while subsequent
search/pagination calls do pass `13` directly. At the time this was judged reason enough to
introduce a dedicated endpoint.

**Historical implementation** (kept for reference, no longer the active approach):
1. `getVendors(skip, top, filter, orderBy)` was added to `dynamicsApi.js` /
   `RestDynamicsRepository.js` calling `GET /dynamics/vendors?...` — code may still exist but is
   unused by this feature after Update 5.
2. `useVendors.js` hook in `eutr-templates/hooks/` managed pagination/search/vendor list state —
   removed per Update 5 (Section 16).
3. `EutrTemplatesAddEdit.jsx` used a plain MUI `Autocomplete` (`options={vendors}`) backed by
   `useVendors` — replaced per Update 5 with `ReferenceObjectAutocomplete`.

---

## 10. Bug Fix: ParentId Not Saved to eutr_template_details

**Decision**: Fix the `flattenForSave` function in `useStepTree.js` to properly map temporary client-side IDs to sequential IDs before sending to the backend.

**Rationale**: When new steps are added, they receive temporary string IDs like `"temp-1"`, `"temp-2"`. The current `flattenForSave` function converts any string `parentId` to `0` (root), which destroys the parent-child relationship for any step whose parent was newly added in the current session. Steps under existing (server-assigned numeric ID) parents are unaffected.

**Root cause**: In `useStepTree.js`, line 102: `parentId: typeof s.parentId === 'string' ? 0 : s.parentId` strips all temp-ID parent references.

**Implementation**:
1. In `flattenForSave`, build a mapping from temp `_id` to a sequential placeholder (e.g., negative numbers or simple counter) that preserves the tree structure.
2. During the recursive walk, assign each node a sequential `clientId` and record `parentId` as the parent's `clientId` (not the raw `_id`).
3. Root steps get `parentId = 0`. Children get `parentId = parent's clientId`.
4. Backend already handles the parent resolution: it inserts steps in order and maps client-side parent references to actual server IDs after insert.

---

## 11. Edit Step Inline — UX Pattern

**Decision**: Add an Edit icon (pencil) on each step tree item. Clicking it toggles that row into edit mode — replacing the display labels with comboboxes for Step, RequirementType, and TakeFrom (pre-filled with current values), plus Save and Cancel buttons.

**Rationale**: The codebase uses inline form controls in table rows (see `MasterDefaultForm.jsx`, `ComplianceMasterForm.jsx`) for similar edit-in-place patterns. The step tree uses `TreeItem2` with custom content — the `ContentComponent` slot already renders step info, so adding conditional edit controls fits naturally. Only one step can be in edit mode at a time (editing another auto-cancels the current).

**Alternatives considered**:
- Always-editable controls (all steps show comboboxes at all times) — rejected: too cluttered for a tree view with many steps, and inconsistent with the display-focused tree UX.
- Edit via modal dialog — rejected: adds unnecessary interaction overhead for changing 1-3 fields.

**Implementation**:
1. Add `editingStepId` state to `useStepTree` hook (or directly in `StepTree.jsx`).
2. Add `editStep(stepId, updatedFields)` function to `useStepTree` — updates `stepId`, `requirementType`, `takeFrom` in the tree state array.
3. In `StepTree.jsx`, each tree item gets an Edit icon button. When clicked, set `editingStepId` to that step's `_id`.
4. If `editingStepId === node._id`, render comboboxes (Step, RequirementType, TakeFrom) with current values pre-selected, plus Save and Cancel buttons.
5. Save: call `editStep()` with new values, clear `editingStepId`.
6. Cancel: clear `editingStepId` without changes.
7. Clicking Edit on another step while one is being edited: auto-cancel the current edit.

---

## 12. Two-Column Layout for Add/Edit Screen

**Decision**: Split the `EutrTemplatesAddEdit.jsx` page into a MUI Grid 2-column layout — left column (xs=12, md=5) for header form fields, right column (xs=12, md=7) for step tree and step actions.

**Rationale**: The header form has 5 fields (Code, Name, AlertFor, Vendor, Default) which stack vertically and don't require much horizontal space. The step tree is the primary working area and benefits from more space. A 5:7 ratio gives the tree ~58% of the width on desktop while keeping header fields comfortably readable. On narrow screens (xs), columns stack vertically for mobile compatibility.

**Alternatives considered**:
- 6:6 even split — rejected: header form doesn't need that much space, wastes horizontal room for the tree.
- Tabs (Header tab / Steps tab) — rejected: user needs to see both simultaneously per spec requirement SC-012.
- 4:8 split — rejected: too narrow for the Vendor combobox dropdown and field labels.

**Implementation**:
1. Wrap the page content in `<Grid container spacing={3}>`.
2. Left column: `<Grid item xs={12} md={5}>` containing Card with header form fields.
3. Right column: `<Grid item xs={12} md={7}>` containing Card with StepTree, Add step button, and StepFormRow.
4. Footer (Save + Back buttons) spans full width below both columns.

> **Superseded by Section 14** (2026-07-03 update): the 5:7 ratio and footer Save button placement
> described above no longer reflect the current requirement. See Section 14 for the updated
> `md={7}`/`md={5}` ratio and the Save button's new position below the Default checkbox.

---

## 13. Conditional Versioning — 24-Hour Threshold

**Decision**: In `EutrTemplatesService.UpdateAsync`, branch on
`(DateTime.UtcNow - existing.CreatedDate) >= TimeSpan.FromHours(24)`:
- **True** (≥24h): keep existing versioning behavior — new row with `VersionId+1`, insert details
  under the new `TemplateId`, mark old row `IsHide=1`.
- **False** (<24h): update the existing row in place — same `Id`, same `VersionId`, `CreatedDate`
  unchanged; only mutable header fields (Name, VendorCode, IsDefault, AlertFor) plus
  `UpdatedBy`/`UpdatedDate` change. Replace all rows in `eutr_template_details` for that
  `TemplateId` (delete existing, insert the new tree) rather than inserting under a new
  `TemplateId`.

**Rationale**: Prevents version-history clutter when a user makes several quick corrections
shortly after creating a template (e.g., fixing a typo minutes after Save). After 24 hours, the
template is assumed to be in active use elsewhere (referenced by EUTR processes), so edits must
preserve the prior state via versioning for audit purposes.

**Alternatives considered**:
- Always version (current behavior) — rejected per this update's explicit requirement.
- Configurable threshold (admin-configurable hours) — rejected: no such configuration feature
  exists yet; hardcoded 24h constant is simpler and matches the spec's literal requirement.
- Measure the window from `UpdatedDate` (sliding window, reset on each in-place edit) instead of
  the original `CreatedDate` — rejected: the spec's clarification explicitly anchors the window to
  `CreatedDate`, so an edit at hour 23 does not extend the window past hour 24.

**Implementation**:
1. Add `ReplaceDetailsAsync(templateId, details, ct)` to `IEutrTemplatesRepository` /
   `EutrTemplatesRepository` — within the existing transaction, delete all
   `eutr_template_details` rows for `templateId`, then reuse the existing bulk-insert logic from
   `BulkInsertDetailsAsync` to insert the new tree under the same `templateId`.
2. In `UpdateAsync`, after loading `existing`, compute the age check. In the <24h branch: map the
   DTO onto a copy of `existing` (preserve `Id`, `VersionId`, `CreatedDate`, `CreatedBy`), call the
   base repository's `UpdateAsync` (generic header update), then call `ReplaceDetailsAsync`. Skip
   `SetIsHideAsync` entirely in this branch.
3. `IsDefault` constraint enforcement (`ClearIsDefaultForVendorAsync`) applies identically in both
   branches, using the current `Id` (unchanged in the <24h branch, new `Id` in the ≥24h branch).

---

## 14. Add/Edit Screen — Save Button Position & Column Ratio

**Decision**: Move the Save `<Button>` from the top title `Box` (currently next to Back) into the
left column, placed immediately after the `Default` checkbox `FormControlLabel`. Change the
`Grid item` width props from `md={5}` (header) / `md={7}` (steps) to `md={7}` (header) / `md={5}`
(steps).

**Rationale**: Per explicit UI feedback: the header input fields (Code, Name, AlertFor, Vendor)
felt cramped at `md={5}`, and Save being paired with Back in the title bar was inconsistent with
the natural top-to-bottom flow of filling the header form before saving. Widening the header
column to `md={7}` gives text fields more breathing room; narrowing steps to `md={5}` is
acceptable since the tree itself scrolls vertically and doesn't need maximum width.

**Alternatives considered**:
- Keep Save in the title bar, only resize columns — rejected: user explicitly asked to relocate
  Save under the Default checkbox.
- `md={6}`/`md={6}` even split — rejected: user asked for a bigger expansion of the left column
  specifically, not a modest rebalance.

**Implementation**:
1. In `EutrTemplatesAddEdit.jsx`, remove the Save `<Button>` from the top `Box` (leave Back
   alone there).
2. Add the Save `<Button>` inside the left column's `<Box display="flex" flexDirection="column">`,
   right after the `FormControlLabel` (Default checkbox).
3. Update `<Grid item xs={12} md={5}>` → `md={7}` for the header column and
   `<Grid item xs={12} md={7}>` → `md={5}` for the step tree column.

---

## 15. Back Button — Unsaved Step Changes Warning

**Decision**: Track a boolean `isDirty` flag in `useStepTree.js`, set to `true` whenever
`addStep`, `editStep`, `removeStep`, `removeMultiSteps`, or `reorderSiblings` mutates the tree, and
reset to `false` by `loadFromServer` (initial page load) and explicitly by the page after a
successful Save. The Back button's `onClick` checks `isDirty`: if `true`, opens the existing
`ConfirmDialog` component (same pattern as `group-email/components/ConfirmDialog.jsx`) asking the
user to confirm leaving; if confirmed, navigate to the list (discarding changes); if `false`,
navigate immediately without a dialog.

**Rationale**: The spec scopes the warning to step-tree changes specifically (add/edit steps),
not header field edits — matching the literal requirement. Tracking dirtiness inside
`useStepTree` (rather than the page component) keeps the tree's own mutation methods as the
single source of truth for "has the tree changed," avoiding duplicated dirty-check logic if the
tree is reused elsewhere.

**Alternatives considered**:
- Track dirty state via deep-equality comparison of `items` on every render — rejected: more
  expensive and unnecessary when explicit mutation methods can just flip a flag.
- Extend dirty-tracking to header fields too — rejected: spec explicitly scopes the warning to
  step add/edit actions, not header field changes (see spec Assumptions).
- Browser-native `beforeunload` warning — rejected: only fires on tab close/refresh, not on
  in-app `navigate()` calls triggered by the Back button; doesn't address the actual requirement.

**Implementation**:
1. Add `const [isDirty, setIsDirty] = useState(false)` to `useStepTree.js`.
2. In `addStep`, `editStep`, `removeStep`, `removeMultiSteps`, `reorderSiblings`: call
   `setIsDirty(true)` alongside the existing state mutation.
3. In `loadFromServer`: call `setIsDirty(false)` after mapping items (covers both Edit-mode
   initial load and any future re-load).
4. Export `isDirty` and `setIsDirty` from the hook.
5. In `EutrTemplatesAddEdit.jsx`: after a successful `handleSave`, call `setIsDirty(false)`
   (belt-and-suspenders, in case the user stays on the page after Save in a future flow).
6. Add local state `const [confirmBackOpen, setConfirmBackOpen] = useState(false)`. Back button
   `onClick`: `if (isDirty) setConfirmBackOpen(true); else navigate('/eutr/templates')`. Render
   `<ConfirmDialog open={confirmBackOpen} onConfirm={() => navigate('/eutr/templates')} onCancel={() => setConfirmBackOpen(false)} message="..." />`.

---

## 16. Vendor Data Source — Revert to Generic Reference API (refType=13)

**Decision**: Revert Sections 1 and 9 — the vendor combobox in `EutrTemplatesAddEdit.jsx`
(`options={vendors}`) and the grid's Vendor name lookup MUST use the generic reference API
`POST /api/dynamics/reference` with `refType = 13`, via the existing `ReferenceObjectAutocomplete`
component (or its underlying `useReferenceObjects` hook), instead of the dedicated
`GET /api/dynamics/vendors` endpoint introduced in Update 2/3.

**Rationale**: Explicit business decision (spec Update 5, 2026-07-06) to standardize vendor
lookup on the same generic reference mechanism used by every other reference field in the
codebase, rather than maintaining a feature-specific vendor endpoint/hook pair. `refType = 13`
is already mapped to D365 `VendorsV3` in `ComplDynamicsService`, so no backend change is needed
(Principle III — reuse existing backend).

**Alternatives considered**:
- Keep the dedicated `GET /api/dynamics/vendors` endpoint — rejected: explicitly reversed by the
  spec update; the business preference is to consolidate on the generic reference pattern.
- Fix the `ReferenceObjectAutocomplete` referenceType 13→4 initial-load quirk as part of this
  change — rejected as in-scope: the spec update only asks for the data-source swap, not a fix to
  the shared component's pre-existing behavior. If verification during `/speckit-implement` shows
  this quirk breaks the vendor combobox, flag it as a separate follow-up rather than silently
  patching a shared component.

**Implementation**:
1. In `EutrTemplatesAddEdit.jsx`, remove the `Autocomplete` bound to `options={vendors}` /
   `useVendors` and replace it with `ReferenceObjectAutocomplete` configured with
   `referenceType={13}`, bound to `vendorCode`/`vendorName` state, mirroring how other reference
   fields in the codebase are wired (see `ReferenceObjectAutocomplete.jsx` consumers for the
   established prop pattern: `value`, `onChange`, `label`, `size`).
2. Remove `compliance-client/src/presentation/pages/eutr-templates/hooks/useVendors.js` — no
   longer used.
3. Remove or stop calling `getVendors` from `dynamicsApi.js` / `RestDynamicsRepository.js` for
   this feature (leave the methods in place if other features might still reference them; verify
   with a repo-wide search before deleting).
4. For the grid's Vendor name column, resolve `VendorCode → VendorOrganizationName` via the
   generic reference lookup (`useReferenceObjects` or an equivalent one-off fetch with
   `referenceType=13`) instead of `GET /api/dynamics/vendors`.
5. In Edit mode, pre-select the template's current vendor the same way other
   `ReferenceObjectAutocomplete` consumers pre-select an existing value (pass the current
   `vendorCode` as `value` on mount).
6. Leave `DynController.cs`'s `GET /api/dynamics/vendors` endpoint in place (unused by this
   feature) rather than deleting it, since removing a backend endpoint is outside this update's
   scope and could affect other undiscovered consumers.

---

## 17. Free-solo Step Combobox + Auto-create Step in eutr_steps

**Decision**: The Step `Autocomplete` in `StepFormRow.jsx` (Add step) and the inline edit form in
`StepTree.jsx` (Edit step) become `freeSolo`. A step in the tree carries both `stepId` (nullable)
and `stepName` (always set). Selecting an existing option sets both; typing free text sets
`stepId = null` and `stepName = <typed text>`. On template Save, the backend resolves each
`stepId: null` detail against `eutr_steps` by name (trimmed, case-insensitive); if no match, it
inserts a new `eutr_steps` row and uses the new Id. Multiple details sharing the same new name in
one Save reuse a single created row.

**Rationale**: The user should not have to leave the Add/Edit Template screen, go create the step
in the separate EUTR Steps screen (001-eutr-steps), then come back — that round trip is the exact
friction this change removes. Resolving on Save (not on blur/immediately when typed) keeps the
step tree a pure client-side draft until the user commits, consistent with how the rest of the
tree already behaves (nothing is persisted until template Save).

**Alternatives considered**:
- Create the step immediately when the user finishes typing it into the combobox (on blur) —
  rejected: would create orphan `eutr_steps` rows if the user cancels out of Add/Edit without
  saving the template (Back → discard), or if they retype/correct the name before saving.
- Call `POST api/eutr-steps` (the existing create endpoint from `EutrStepService`/`BaseService`)
  from `EutrTemplatesService` for each unresolved name — rejected: pulls a cross-feature service
  dependency into `EutrTemplatesService` for what is a single-table insert; matching the existing
  pattern of `EutrTemplatesRepository` already doing direct SQL against `eutr_steps` (it already
  `LEFT JOIN eutr_steps` in `GetByIdWithDetailsAsync`) is simpler and keeps `eutr_steps` writes
  colocated with the one method that needs them.
- Exact (case-sensitive) name matching only — rejected: would create duplicate steps differing
  only by casing/whitespace (e.g., "forest " vs "Forest"), cluttering `eutr_steps` for users who
  don't retype names exactly.
- Client-side pre-check (call a "does this step name exist" endpoint before Save) — rejected:
  adds a network round trip and a TOCTOU race between check and Save; resolving atomically inside
  the same Save transaction is simpler and race-free.

**Implementation**:
1. `EutrTemplateDetailsRequestDto`: add `public string? StepName { get; set; }`.
2. `EutrTemplatesRequestDtoValidator`: add a rule that each `Details[i]` has `StepId != null` OR
   `!string.IsNullOrWhiteSpace(StepName)`.
3. `IEutrTemplatesRepository` / `EutrTemplatesRepository`: add
   `Task<Dictionary<string, long>> ResolveOrCreateStepsByNameAsync(IEnumerable<string> names, string userEmail, CancellationToken ct)`.
   Dedupe input names (`Distinct(StringComparer.OrdinalIgnoreCase)`, trimmed), `SELECT Id, Name
   FROM eutr_steps WHERE Name IN @names` for existing matches (relies on the DB's default
   case-insensitive collation, consistent with the rest of the codebase's unqualified `LIKE`
   filters), then `INSERT INTO eutr_steps (Name, CreatedBy, CreatedDate, UpdatedBy, UpdatedDate)`
   for any name with no match. Runs inside the same transaction as the rest of the Save.
4. `EutrTemplatesService`: extract a private `BuildDetailEntitiesAsync(details, now, userEmail,
   ct)` helper used by `AddAsync` and both `UpdateAsync` branches — collects distinct typed names
   (`StepId == null && !string.IsNullOrWhiteSpace(StepName)`), calls
   `ResolveOrCreateStepsByNameAsync` once, then maps each DTO to an `EutrTemplateDetails` entity,
   substituting the resolved Id for unresolved details before setting audit fields.
5. Frontend `useStepTree.js`: `flattenForSave()` includes `stepName` on every emitted item (not
   only for unresolved ones) — simplest to always send it since the backend only reads it when
   `stepId` is null.
6. Frontend `StepFormRow.jsx` / `StepTree.jsx` inline edit: `Autocomplete freeSolo`, `onChange`
   handles both an option object (existing step) and a raw string (typed value, when the user
   presses Enter/blurs without selecting an option) — mirrors the existing `freeSolo` handling
   already used for the `Alert for` field in `EutrTemplatesAddEdit.jsx`.
7. New step names created this way appear immediately in the `001-eutr-steps` grid on next load —
   no change needed there since it queries the same `eutr_steps` table.

---

## 18. Alert For — Combobox Sourced from compl_group_email

**Decision**: Change `AlertFor` from a free-text/hardcoded-options field (currently a `freeSolo`
`Autocomplete` in `EutrTemplatesAddEdit.jsx` with `options={['PO', 'Upload manual']}` — a copy-paste
placeholder, not real data) to a single-select combobox backed by `compl_group_email`
(`ComplGroupEmailController`), reusing the frontend's existing `GetAllGroupEmailUseCase` /
`repositories.groupEmail` (already used by `ComplianceMasterForm.jsx` / `MasterDefaultForm.jsx` for
their "Alert" group pickers). The combobox shows each group's `Name`; on Save, the selected group's
`Id` is what gets persisted — not the Name. `AlertFor` changes from a `string` column/property to a
numeric reference (`long?`) to `compl_group_email.Id`. Display resolution (Id → Name) happens via a
SQL `LEFT JOIN compl_group_email` directly in the existing repository queries, not a separate
service call — `compl_group_email` is a local table (unlike D365 VendorsV3), so no external lookup
service is needed; this mirrors how `StepName` is already resolved via `LEFT JOIN eutr_steps` in
`GetByIdWithDetailsAsync`.

**Rationale**: `GetAllGroupEmailUseCase`/`repositories.groupEmail` and the
`groupEmailType.ALERT`/`isAddition` filtering convention already exist and are proven in two other
forms — reusing them is a direct application of Principle II (reference-pattern reuse) and adds zero
new frontend files. On the backend, a `LEFT JOIN` is strictly simpler than the D365 vendor pattern
(which needs `IComplDynamicsService` because VendorsV3 is external/OData) — `compl_group_email` is
queryable with a plain SQL join in the same query that already builds the paged/detail response.

**Alternatives considered**:
- Inject `IComplGroupService` into `EutrTemplatesService` and resolve names in C# (mirroring the
  `GetPagedAsync` VendorName resolution loop) — rejected: adds an unnecessary service dependency and
  a second query when a `LEFT JOIN` in the existing SQL does it in one round trip, since
  `compl_group_email` is a local table (no OData/external round trip to shield against).
- Multi-select (many-to-many via a join table), like `ComplianceMasterForm`'s Responsible/Alert
  group pickers — rejected: the spec explicitly stores a single Id in a single `AlertFor` column,
  not an array; `eutr_templates` has no supporting join table and adding one is out of scope for
  this change.
- Validate the selected Id exists in `compl_group_email` server-side before Save (extra query) —
  rejected for consistency with the existing `VendorCode` field, which is also unvalidated
  server-side (any string is accepted, trusting the frontend combobox); adding asymmetric validation
  only for `AlertFor` would be inconsistent with the established pattern in this same entity.
- Auto-create a new group (like the free-solo Step combobox does for `eutr_steps`) when the user
  types a name not in the list — rejected: `compl_group_email` groups are a managed, cross-feature
  resource (used by compliance notifications elsewhere in the app, see `ComplNotificationService`);
  silently creating one from the Templates screen would pollute that shared list. The combobox is
  select-only (no `freeSolo`), unlike the Step combobox.

**Implementation**:
1. **Backend entity/DTOs**: `EutrTemplates.AlertFor` (`Domain/Entities/EutrTemplates.cs`),
   `EutrTemplatesRequestDto.AlertFor` change type from `string` to `long?`.
   `EutrTemplatesResponseDto` gains `AlertForName` (`string?`), parallel to the existing
   `VendorName`.
2. **Validator**: `EutrTemplatesRequestDtoValidator` — replace
   `RuleFor(x => x.AlertFor).NotEmpty()` with a rule requiring a positive value, e.g.
   `RuleFor(x => x.AlertFor).Must(v => v.HasValue && v.Value > 0).WithMessage("Alert for is required")`.
3. **Repository**: In `EutrTemplatesRepository.GetPagedWithVendorNameAsync` and
   `GetByIdWithDetailsAsync`, add `LEFT JOIN compl_group_email g ON g.Id = t.AlertFor` and select
   `g.Name AS AlertForName` alongside the existing `t.AlertFor` column. `FilterMap["AlertFor"]`
   changes from `t.AlertFor` to `g.Name` so the existing grid filter searches by group Name (a raw
   numeric Id is not a meaningful text-search target for end users) — mirrors how Vendor is only
   filterable by `VendorCode`, the human-facing identifier.
4. **Migration**: `eutr_templates.AlertFor` changes from `VARCHAR` to `BIGINT UNSIGNED NULL`. Any
   existing rows hold placeholder text (`'PO'` / `'Upload manual'` from the current hardcoded
   options, not real business data — this feature has no production usage yet). Migration script:
   ```sql
   UPDATE eutr_templates SET AlertFor = NULL
     WHERE AlertFor IS NOT NULL AND AlertFor NOT REGEXP '^[0-9]+$';
   ALTER TABLE eutr_templates MODIFY COLUMN AlertFor BIGINT UNSIGNED NULL DEFAULT NULL;
   ```
   No DB-level `FOREIGN KEY` constraint is added from `AlertFor` to `compl_group_email.Id` — same
   treatment as `VendorCode` (no FK to the external vendor source). This avoids coupling
   `compl_group_email`'s delete behavior (`ComplGroupEmailController.Delete`, currently a hard
   delete with no reference check) to this feature; a deleted group simply resolves to a blank
   `AlertForName` on the grid (see spec Edge Cases).
5. **Import** (`EutrTemplatesImportService`): column B in the Excel template now holds the Alert
   group's **Name** (text), not a raw Id. The service resolves it via a new repository lookup
   (`SELECT Id FROM compl_group_email WHERE Name = @name AND GroupType = 2 AND IsAddition = 0`,
   exact match — no auto-create, unlike the Step free-solo resolution). If no match, the row fails
   with `"Alert for group not found"` (new error case, added alongside the existing "Alert for is
   required" for a blank cell).
6. **Export** (`EutrTemplatesExportService`): column D writes `item.AlertForName` (resolved Name)
   instead of the raw `item.AlertFor` Id, so round-tripping an exported file back through Import
   continues to work (Import expects a Name, Export now produces one).
7. **Frontend** (`EutrTemplatesAddEdit.jsx`): replace the `Autocomplete` bound to
   `options={ALERT_FOR_OPTIONS}` (`freeSolo`, hardcoded `['PO', 'Upload manual']`) with one backed
   by `GetAllGroupEmailUseCase.execute()` (via `repositories.groupEmail`, same import already used
   in `ComplianceMasterForm.jsx`), filtered client-side to
   `g.groupType === groupEmailType.ALERT && g.isAddition === false`, `getOptionLabel={g => g.name}`,
   **not** `freeSolo`. State changes from a single `alertFor` string to storing the selected group's
   `id` (submitted as `alertFor`) with the option object kept for display; in Edit mode, the current
   `template.alertFor` Id is matched against the loaded groups list to pre-select the option.
8. **Frontend grid** (`useEutrTemplatesColumns.jsx`): the `alertFor` column's `field` changes to
   `alertForName` (display), matching the `vendorCode`/`vendorName` split — the raw Id remains
   available on the row (as `alertFor`) for populating the Edit form but is not itself a grid
   column.
9. **Frontend entity** (`EutrTemplates.js`): constructor gains `alertForName` alongside the existing
   `alertFor`, mirroring `vendorName`/`vendorCode`.
