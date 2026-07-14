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

> **Scope narrowed by Section 20** (2026-07-13 update 9): this 2-column layout, and the Save
> button position, now apply ONLY to `EutrTemplatesAddEdit.jsx` in its Edit-only role — Create is
> a separate 3-field `Dialog` (`CreateTemplateDialog.jsx`) that does not use this layout at all.

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

## 19. Shared RequirementType/TakeFrom Constants — Move to utils/helpers.js

**Decision**: Move `REQUIREMENT_TYPES`, `TAKE_FROM_OPTIONS` (both `{value, label}[]` arrays used as
Autocomplete `options`), and `REQUIREMENT_LABELS`, `TAKE_FROM_LABELS` (both `{0: label, 1: label}`
lookup maps) out of `StepTree.jsx` and into `compliance-client/src/utils/helpers.js` as named
exports. `StepFormRow.jsx`'s identical duplicate local declaration of `REQUIREMENT_TYPES`/
`TAKE_FROM_OPTIONS` is deleted; both components import the shared exports instead. No change to
constant names, shapes, or values — pure relocation.

**Rationale**: `StepTree.jsx` and `StepFormRow.jsx` already carry byte-for-byte duplicate
declarations of `REQUIREMENT_TYPES`/`TAKE_FROM_OPTIONS`, which is exactly the kind of divergence
risk `helpers.js` already exists to prevent (it already centralizes cross-feature constants such as
`ObjectType`/`ObjectTypeLabelMap`/`getObjectTypeLabel` and `groupEmailType`). Centralizing lets any
future EUTR (or other) screen that needs to render/label a Required/Optional or PO/Upload-manual
value reuse the same source instead of re-declaring it a third time.

**Alternatives considered**:
- Extract into a new dedicated file (e.g. `eutr-templates/constants.js`) — rejected: the enums are
  generic (Requirement type, document take-from source), not specific to the templates feature, and
  the spec explicitly asks to centralize them "để tận dụng cho các chức năng khác" (for reuse by
  other features); `helpers.js` is the established shared location others already reuse from
  (`ObjectType`, `groupEmailType`).
- Refactor into the `Object.freeze` constant + separate `LabelMap` + `getXLabel(value)` accessor
  pattern used by `ObjectType`/`ObjectTypeLabelMap`/`getObjectTypeLabel` — rejected for this change:
  `REQUIREMENT_TYPES`/`TAKE_FROM_OPTIONS` are consumed directly as MUI `Autocomplete` `options` props
  (array of `{value, label}`), so reshaping them into a frozen value-only object plus a separate
  label map would require rewriting every call site's `options={...}` and `.find(...)` usage for no
  behavioral gain. Kept as plain arrays/objects to minimize diff and risk, per the clarified scope
  (no shape change).
- Leave `StepFormRow.jsx`'s duplicate as-is and only update `StepTree.jsx` — rejected per
  clarification: the spec explicitly resolved this to update both files, since leaving the
  duplicate defeats the stated reuse goal.

**Implementation**:
1. **`compliance-client/src/utils/helpers.js`**: add and export `REQUIREMENT_TYPES`,
   `TAKE_FROM_OPTIONS`, `REQUIREMENT_LABELS`, `TAKE_FROM_LABELS` (values copied verbatim from
   `StepTree.jsx`).
2. **`StepTree.jsx`**: delete the local `REQUIREMENT_LABELS`, `TAKE_FROM_LABELS`,
   `REQUIREMENT_TYPES`, `TAKE_FROM_OPTIONS` declarations; import all four from `utils/helpers.js`.
3. **`StepFormRow.jsx`**: delete the local `REQUIREMENT_TYPES`, `TAKE_FROM_OPTIONS` declarations;
   import both from `utils/helpers.js`.
4. No backend, database, or API contract changes. No new dependency. Purely a frontend
   presentation-layer internal reorganization — call-site usage (`options={REQUIREMENT_TYPES}`,
   `REQUIREMENT_TYPES.find(...)`, `REQUIREMENT_LABELS[value]`, etc.) is unchanged.

---

## 20. Two-Step Create/Edit Split — TemplateListPage + CreateTemplateDialog

**Decision**: Split template creation away from the step-tree builder. The list page (renamed
`index.jsx` → `TemplateListPage.jsx`) renders a new `CreateTemplateDialog.jsx` (MUI `Dialog`) with
only 3 fields — Name, Alert for (combobox), Set as default (checkbox) — instead of navigating to
`EutrTemplatesAddEdit.jsx`. Saving the dialog calls the existing `CreateEutrTemplatesUseCase` with
`{ name, alertFor, isDefault, vendorCode: null, details: [] }`, closes the dialog, and refreshes the
list — no navigation to Edit. `EutrTemplatesAddEdit.jsx` keeps its current 2-column layout (Code,
Name, Alert for, Vendor, Default, Save left; step tree right) unchanged, but is now reached only via
`/eutr/templates/edit/:id` — the `/eutr/templates/add` route is removed and the component's
`isEdit` branch is simplified away (always true).

**Rationale**: Per explicit request (following the design reference at
`E:\Working\design\eutr\pages\TemplateListPage.jsx`, which uses a `Dialog` for quick create),
creating a template should be a fast, minimal action — Vendor assignment and step-tree
construction are deferred to a deliberate follow-up Edit action. This also means a freshly created
template legitimately has 0 steps and no Vendor; `EutrTemplatesAddEdit.jsx` already renders an
empty-tree state (`treeData.length === 0` case, per the design reference's `TemplateBuilderPage`
pattern) so no new empty-state UI is needed — the Edit screen already tolerates this.

**Alternatives considered**:
- Keep a single Add/Edit page, just hide the step tree and Vendor fields when `!isEdit` — rejected:
  still requires a page navigation + breadcrumb for what the request describes as a fast, 3-field
  action; a `Dialog` matches the design reference and other quick-create patterns already in the
  codebase (e.g. `ImportResultDialog.jsx`'s modal shape, `ConfirmDialog` usage elsewhere).
- Auto-navigate to Edit immediately after the dialog's Save — rejected per the request's explicit
  two-step wording ("lần 2 khi nhấn vào Edit mới thêm sửa steps"): the user must deliberately click
  Edit to continue, so the dialog closes back to the list instead.
- Send `vendorCode` as an optional field in the dialog (kept present but empty) instead of removing
  it outright — rejected: the request's literal 3-field list (Name, Alert for, Set as default)
  excludes Vendor; keeping it (even optionally) would contradict "chỉ cần hiện thông tin Name,
  alert for, set as default".
- Keep `index.jsx` as the file name and only rename the exported component to `TemplateListPage` —
  rejected: `EutrTemplatesAddEdit.jsx` in the same folder is already a named file (not
  `index.jsx`), so renaming the file itself to `TemplateListPage.jsx` is more consistent with the
  folder's existing convention and makes FR-019 (page naming) visible at the file level, not just
  in-code.

**Implementation**:
1. Rename `presentation/pages/eutr-templates/index.jsx` → `TemplateListPage.jsx`; rename the
   exported function `EutrTemplatesPage` → `TemplateListPage`.
2. Update `RouteResolver.jsx`'s lazy import path accordingly (`@presentation/pages/eutr-templates`
   → `@presentation/pages/eutr-templates/TemplateListPage`).
3. Add `components/CreateTemplateDialog.jsx`: MUI `Dialog` with `TextField` (Name), the existing
   Alert-for `Autocomplete` pattern from `EutrTemplatesAddEdit.jsx` (reused, not reinvented — same
   `GetAllGroupEmailUseCase`/`groupEmailType.ALERT` filtering), and a `Checkbox` (Set as default).
   Props: `open`, `onClose`, `onCreated` (callback to refresh the list). Internally instantiates
   `CreateEutrTemplatesUseCase` exactly as `EutrTemplatesAddEdit.jsx` currently does.
4. In `TemplateListPage.jsx`, replace the toolbar's `onClick={() => navigate('/eutr/templates/add')}`
   with local dialog-open state; on the dialog's `onCreated`, call the existing `fetchData()`.
5. In `EutrTemplatesAddEdit.jsx`, remove the `isEdit` ternary (title, breadcrumb, Code field
   visibility) since the component is now only reached with an `id` param; keep all Vendor/step-tree
   logic unchanged.
6. Remove the `{ path: "/eutr/templates/add", ... }` entry from `MainRoutes.jsx`; keep
   `/eutr/templates/edit/:id` unchanged.
7. No backend change: `POST api/eutr-templates` already accepts `vendorCode: null` and
   `details: []` (both already nullable/optional per the existing contract and validator — Name and
   AlertFor are the only required fields, matching FR-010 unchanged).

> **Reversed in part by Section 22** (2026-07-13, spec Update 10): `/eutr/templates/edit/:id` is
> repointed from `EutrTemplatesAddEdit.jsx` to `TemplateBuilderPage.jsx` — see Section 22. Steps 1–4
> and 6–7 above (rename, dialog, list-page wiring, no backend change) remain current; only the
> Edit-screen target changes.

---

## 21. TemplateListPage — Table-Layout Real-Data Wiring, Bulk Delete, Disabled Clone/Apply (spec Update 10)

**Decision**: `TemplateListPage.jsx` already contains a Table + search-box + chip (Version/Default)
+ Steps-count + 4-icon-Action-column layout — but it runs entirely on local mock arrays
(`mock/eutrTemplates.js`, `mock/eutrTemplateDetails.js`) with client-side `Array.filter`/`useState`
mutations. Reverse Update 9's decision to keep the DataGrid instead: keep this Table layout exactly
as it looks today, and rewire its data layer to the same working pieces
`TemplateListPageOld.jsx` already uses: `useEutrTemplatesData` (server pagination/filter/sort),
`permissionList` (via `getMenuDataFromStorage`, matched against menu code `eutr-templates`),
`DeleteEutrTemplatesUseCase` + `DeleteMultiEutrTemplatesUseCase` + `ConfirmDialog` (single + new
bulk delete), and `CreateTemplateDialog` (already exists, already correct per Update 9 — no
change). Clone and Apply-to-Customer stay visible but `disabled`.

**Rationale**: The two competing designs (DataGrid-with-filters vs. Table-with-chips) each already
exist in full as separate files; picking one to keep and wiring it to real data is far less risky
than merging their features into a new third design. The user explicitly asked to keep the Table
layout (2026-07-13 clarifying question), so `TemplateListPageOld.jsx`'s DataGrid becomes a
reference/backup file only — its logic is copied over, the file itself is untouched.

**Alternatives considered**:
- Merge DataGrid features (column visibility, per-column filter, Import/Export) into the Table
  layout — rejected: spec Update 10 (FR-021b) explicitly defers these; the Table layout has no
  natural slot for them without a redesign the user didn't ask for.
- Keep the DataGrid and only change 2 cells' data-binding (Code/Name mapping) — rejected: this is
  exactly what Update 9 already decided and Update 10 explicitly reverses.
- Add row selection via MUI's `Checkbox` inside a plain array of selected ids (matching
  `TemplateListPageOld.jsx`'s own `selectionModel` state shape) — chosen over introducing a
  dedicated selection library; the existing pattern is already proven and needs no new dependency.

**Implementation**:
1. Remove `mock/eutrTemplates.js`/`mock/eutrTemplateDetails.js` imports and the local
   `templates`/`setTemplates` state from `TemplateListPage.jsx`.
2. Add `useEutrTemplatesData()` (unchanged hook) for `data`, `total`, `loading`, `error`,
   `paginationModel`/`setPaginationModel`, `filterModel`/`setFilterModel`, `sortModel`/
   `setSortModel`, `fetchData` — call `fetchData()` in a mount `useEffect`, same as
   `TemplateListPageOld.jsx`.
3. Compute `permissionList` via `getMenuDataFromStorage().find(m => m.code === 'eutr-templates')`
   (same as `TemplateListPageOld.jsx`); gate Create/Delete-related UI on
   `permissionList.includes('Create'|'Delete')`, Edit on `.includes('Update')` (matches
   `useEutrTemplatesColumns.jsx`'s existing `canEdit` convention).
4. Replace the `filtered = templates.filter(...)` client-side search with the search box calling
   (debounced ~300ms) `setFilterModel({ items: value ? [{ field: 'keyword', operator: 'contains',
   value }] : [], logicOperator: 'and' })` and `setPaginationModel(prev => ({ ...prev, page: 0 }))`;
   render `data` directly (already the current page's server-filtered rows).
5. In each row: bold text binds to `tmpl.code`, caption text binds to `tmpl.name` (FR-021), Version
   chip to `tmpl.versionId`, Default chip visibility to `tmpl.isDefault === 1`, Steps count to
   `tmpl.stepsCount` (Section 24) instead of the `EUTR_TEMPLATE_DETAILS_MAP` lookup.
6. Replace the ad-hoc Create dialog (`createOpen`/`form`/`handleCreate`, only mutating local mock
   state) with the existing `CreateTemplateDialog` component, `onCreated={fetchData}`.
7. Remove `cloneOpen`/`cloneTarget`/`handleClone` state and the Clone confirmation `<Dialog>` JSX
   entirely; render the Clone `IconButton` with `disabled` and no `onClick`. Same for the "Apply to
   Customer" `IconButton` (remove its `navigate(...)` call, render `disabled`).
8. Wire the Delete `IconButton` (currently has no `onClick` in the mock) to
   `setRowToDelete(tmpl); setConfirmOpen(true)`, then a `ConfirmDialog` calling
   `DeleteEutrTemplatesUseCase.execute(rowToDelete.id)` → `fetchData()` → `CustomSnackbar`, matching
   `TemplateListPageOld.jsx`'s message text exactly ("Are you sure you want to delete the template
   \"{name}\" ({code})?").
9. Add a per-row `Checkbox` (new — the mock had none) bound to a `selectionModel` array of ids, plus
   a header/toolbar "select all" checkbox for the current page and a bulk-delete `IconButton`
   (disabled when `selectionModel.length === 0` or the user lacks Delete permission) opening a
   second `ConfirmDialog` calling `DeleteMultiEutrTemplatesUseCase.execute(selectionModel)` →
   `fetchData()` → clear selection → `CustomSnackbar`.
10. Add a `TablePagination` (new — the mock rendered the full unpaginated array with no page
    control) bound to `paginationModel.page`/`paginationModel.pageSize`/`total`, calling
    `setPaginationModel`.
11. Add a `CustomSnackbar` (new — the mock had no success/error feedback) for delete/bulk-delete
    results, matching `TemplateListPageOld.jsx`.

---

## 22. TemplateBuilderPage — Real-Data Wiring via the Existing `useStepTree`/EutrTemplatesAddEdit Logic (spec Update 10)

**Decision**: `TemplateBuilderPage.jsx` already renders a tree-view (left) + "Step Configuration"
side panel (right) + toolbar (Add Root Group / Add Child Step / Move Up / Move Down / Delete /
Expand / Collapse) — but against mock data (`mock/eutrTemplates.js`, `mock/eutrTemplateDetails.js`,
`mock/eutrSteps.js`) and its own hand-rolled flat-tree state + `utils/treeUtils.js` helpers
(`flatToTree`, `generateId`, `removeNodeAndDescendants`, `getDescendantIds`). `/eutr/templates/edit/:id`
in `MainRoutes.jsx` already routes here (this was never actually reverted back to
`EutrTemplatesAddEdit.jsx`), so wiring it to real data makes it the feature's actual Edit screen.
Reuse the existing `useStepTree` hook (already implements everything `treeUtils.js` reinvents, plus
`editStep`/`isDirty` which `treeUtils.js` doesn't have) and the same use cases/components
`EutrTemplatesAddEdit.jsx` already uses (`GetEutrTemplatesUseCase`, `UpdateEutrTemplatesUseCase`,
`GetEutrStepsUseCase`, `GetAllGroupEmailUseCase`, `ReferenceObjectAutocomplete` refType=13). Keep
`TemplateBuilderPage.jsx`'s own visual shell — do not swap in `StepTree.jsx`'s different UI
(per-row inline add forms + checkbox multi-select), per FR-024's explicit "keep the current
bố cục" instruction.

**Rationale**: `useStepTree` is the single already-tested source of truth for step-tree mutation
semantics (cascade delete, ParentId-preserving flatten-for-save, dirty tracking) — re-deriving the
same behavior a second time in `treeUtils.js`/local state would create two divergent
implementations of the same business rules (FR-006 through FR-008b) that could drift apart on the
next change. Keeping the visual shell separate from the data layer is exactly what "reuse existing
logic, not rewrite" (Principle II/III) means when two different UI designs both need to manage the
same underlying tree.

**Alternatives considered**:
- Replace `TemplateBuilderPage.jsx`'s tree rendering with `StepTree.jsx` wholesale — rejected: FR-024
  explicitly preserves the tree-view + side-panel + toolbar shell; `StepTree.jsx`'s per-row
  inline-add-form UI is a different interaction model the user didn't ask to adopt here.
- Keep `treeUtils.js` and only swap the data source (mock arrays → real API responses) — rejected:
  `treeUtils.js` duplicates logic `useStepTree` already has (and lacks `editStep`/`isDirty`), so
  keeping it means maintaining two parallel tree implementations for no benefit.
- Add real drag-and-drop (`@dnd-kit`) to `TemplateBuilderPage.jsx` to fully match `StepTree.jsx`'s
  reordering UX — rejected: the existing Move Up/Down buttons already update `DisplayOrder`
  correctly once wired to `reorderSiblings`; FR-024 asks to keep the current toolbar, and adding a
  drag interaction is a UI addition beyond what was requested.
- Keep the Type/FSC mock fields as inert display-only remnants instead of removing them — rejected:
  they don't exist in `EutrTemplateDetails` (Section on data-model), so keeping them either silently
  discards user input or requires fabricating backend support nobody asked for; removing them is the
  only option consistent with the real schema.

**Implementation**:
1. Remove `mock/eutrTemplates.js`, `mock/eutrTemplateDetails.js`, `mock/eutrSteps.js`, and
   `utils/treeUtils.js` imports; remove local `flatDetails`/`setFlatDetails` state.
2. Add `useState` for header fields (`code`, `name`, `vendorCode`, `vendorName`, `alertFor`,
   `isDefault`) plus `loading`/`saving`/`snackbar`, mirroring `EutrTemplatesAddEdit.jsx`.
3. On mount: `GetEutrTemplatesUseCase.execute(id)` → populate header state, call
   `useStepTree().loadFromServer(template.details)`; `GetEutrStepsUseCase.execute()` → steps list
   for the free-solo comboboxes; `GetAllGroupEmailUseCase.execute()` (filtered to
   `groupType === groupEmailType.ALERT && !isAddition`) → Alert-for combobox options.
4. Replace `treeData = useMemo(() => flatToTree(flatDetails), ...)` with `useStepTree`'s own
   `buildTree(0)`; replace `allIds`/expand-all/collapse-all logic to walk this same tree shape
   (unchanged behavior, different data source).
5. `moveNode('up'|'down')`: keep the existing sibling-lookup logic to compute `fromIndex`/`toIndex`,
   but call `reorderSiblings(parentId, fromIndex, toIndex)` from the hook instead of manually
   swapping two items' `displayOrder` fields.
6. `handleDeleteNode`/`doDelete`: call the hook's `removeStep(selectedId)` (already cascade-aware)
   instead of `removeNodeAndDescendants` from `treeUtils.js`; keep the existing
   "N descendants, confirm?" dialog UX as-is (client-side count still computed the same way, just
   reading from `useStepTree`'s `items` instead of `flatDetails`).
7. Add Root Group / Add Child Steps dialogs: replace the `Select` (bound to `EUTR_STEPS` mock) with
   a free-solo `Autocomplete` bound to the real steps list (same pattern as `StepFormRow.jsx` —
   selecting an option sets `{stepId, stepName}`, typing sets `{stepId: null, stepName: <text>}`);
   remove the 8-option mock `TAKE_FROM_OPTIONS`/`CHIP_COLORS` and the Type/FSC `RadioGroup`s
   entirely; import `REQUIREMENT_TYPES`/`TAKE_FROM_OPTIONS`/`REQUIREMENT_LABELS`/`TAKE_FROM_LABELS`
   from `utils/helpers.js`. On confirm, call the hook's `addStep(...)` instead of pushing directly
   into `flatDetails`.
8. Right-hand "Step Configuration" panel: when `selectedId === null`, render the header form (Code
   readonly, Name `TextField`, Alert-for `Autocomplete` — select-only, sourced from
   `GetAllGroupEmailUseCase` — Vendor `ReferenceObjectAutocomplete` with `referenceType={13}`,
   Set-as-default `Checkbox`, Save `Button`) instead of the current "Chọn một step..." placeholder.
   When a step is selected, keep the existing step-detail panel shape but bind Step Master to the
   real steps list (free-solo, not the mock `Select`), RequirementType/TakeFrom to the shared
   `utils/helpers.js` constants, and drop the Type/FSC `RadioGroup`s; Save calls the hook's
   `editStep(selectedId, {...})` (client-side only, matching FR-008b — no template Save needed for
   this), Delete calls `removeStep`/opens the existing descendant-count confirm dialog.
9. `handleSaveDraft` → `handleSave`: build
   `{ name, vendorCode, alertFor: alertFor, isDefault: isDefault ? 1 : 0, details:
   flattenForSave() }`, call `UpdateEutrTemplatesUseCase.execute(id, payload)`; on success,
   `navigate('/eutr/templates')` (matching `EutrTemplatesAddEdit.jsx`'s existing redirect — the
   mock's "stay on page, show a message" behavior is replaced); on failure, show an error
   `CustomSnackbar` and stay on the page.
10. Back button: add the same `isDirty` (from `useStepTree`) + `ConfirmDialog` wiring already
    implemented for `EutrTemplatesAddEdit.jsx` (Section 15) — no new pattern, just applied here too.
11. Replace the `if (!template) return <Typography>Template không tồn tại</Typography>` guard with
    a loading spinner while the initial fetch is in flight, and a proper not-found state if the
    fetch resolves with no data (matching `EutrTemplatesAddEdit.jsx`'s existing loading pattern).
12. Breadcrumb text changes from `{template.name} — {template.versionId}` to the feature's
    established wording, "EUTR system > EUTR templates > Edit" (matches the wording already used by
    `EutrTemplatesAddEdit.jsx` per FR-011).
13. `EutrTemplatesAddEdit.jsx` is left in place, unreferenced by any route after this change — not
    deleted (Principle III precedent from Update 5's unused vendors endpoint). `mock/eutrTemplates.js`,
    `mock/eutrTemplateDetails.js`, `mock/eutrSteps.js`, and `utils/treeUtils.js` become fully
    orphaned (verified: no other file in the repo imports them) and are likewise left in place.

---

## 23. Server-Side Keyword Search — Code OR Name (spec Update 11)

**Decision**: Reuse the existing filter pipeline end-to-end on the frontend
(`useEutrTemplatesData`'s `filterModel` → `useFilterPayload` → `getPagingUseCase.execute(...,
filterPayload)`, all unchanged) by sending one filter item with `field: 'keyword'`. The only new
code is on the backend: inside `EutrTemplatesRepository`'s WHERE-clause builder for
`GetPagedWithVendorNameAsync`, special-case a `Keyword` column (after `useFilterPayload` title-cases
`keyword` → `Keyword`) into `(Code LIKE @p OR Name LIKE @p)` instead of mapping it to one SQL
column, the same way `AlertFor` was special-cased to the joined `g.Name` column in Update 7.

**Rationale**: The existing filter payload shape is a flat list of independent
`{column, operator, value}` entries that the repository's WHERE builder combines with AND — it has
no way to express "Code OR Name" as two separate entries. Special-casing one pseudo-column name is
the smallest change that fits inside the existing contract: no new endpoint, no new request/response
shape, no frontend hook change (verified: `useFilterPayload` already produces `column: "Keyword"`
for a `field: 'keyword'` input via its existing `.charAt(0).toUpperCase() + field.slice(1)` logic).

**Alternatives considered**:
- Add a dedicated `keyword` query parameter to a new/separate search endpoint — rejected: duplicates
  the paging/sorting logic `get-all` already has, and the existing filter-list contract already has
  room for one more entry without a breaking change.
- Send two filter entries (`Code contains X`, `Name contains X`) and change the WHERE builder to
  support a mixed AND/OR combination via `filterModel.logicOperator` — rejected: bigger blast radius
  (every other filter consumer of this builder would need to reason about a new OR-grouping
  behavior); a single special-cased pseudo-column is scoped to exactly this one need.
- Perform the Code/Name matching entirely client-side against the currently loaded page — rejected
  per the Update 11 clarification: pagination is server-driven, so a client-side filter would miss
  matches on pages not currently loaded.

**Implementation**:
1. Frontend: no hook/component change beyond what Section 21 already describes — the search box's
   debounced `setFilterModel({ items: [{ field: 'keyword', operator: 'contains', value: term }] })`
   is exactly the same call shape `useEutrTemplatesData` already accepts for any other column.
2. Backend (`EutrTemplatesRepository`, wherever the dynamic WHERE clause is assembled from the
   incoming filter list — the same place `FilterMap["AlertFor"] = "g.Name"` already lives): add a
   branch that recognizes `column == "Keyword"` and appends
   `(Code LIKE @pN OR Name LIKE @pN)` (parameterized, same `%value%` wrapping already used for
   other `like` operators) instead of looking it up in `FilterMap` as a single-column rename.
3. No DTO or contract shape change — the request body still sends a `filters` array; this one entry
   just has `field: "Keyword"` instead of a real column name.

---

## 24. Real Steps Count on the List (spec Update 11)

**Decision**: Add `(SELECT COUNT(*) FROM eutr_template_details d WHERE d.TemplateId = t.Id) AS
StepsCount` to the same `SELECT` list `GetPagedWithVendorNameAsync` already builds (alongside the
existing `VendorName`/`AlertForName` resolution), and add a matching `StepsCount` (int) property to
`EutrTemplatesResponseDto`.

**Rationale**: The clarification (spec Update 11) resolved a direct contradiction — FR-021 required
the Steps column to show real data, but an earlier Assumption said 0/blank was an acceptable
permanent placeholder. A correlated subquery is the simplest way to get an accurate per-row count in
the same query that already returns one row per template, with no new round trip and no N+1 query
risk (a separate per-template count call, once per row, would not scale with page size the way this
does).

**Alternatives considered**:
- Fetch counts in a second batched query (`WHERE TemplateId IN (@ids)` after the main page query,
  then merge in C#) — rejected: adds a second round trip and merge step for no benefit over a
  correlated subquery MySQL can already optimize reasonably well at this data volume (hundreds of
  templates, tens of steps each, per the spec's stated Scale/Scope).
- Compute the count client-side by having the frontend call `GET /eutr-templates/{id}` per row —
  rejected: exactly the N+1 pattern the correlated subquery avoids, and would need one request per
  visible row on every page load.
- Store a denormalized `StepsCount` column on `eutr_templates`, updated whenever
  `eutr_template_details` changes — rejected: adds a new write-path invariant to keep in sync across
  every insert/delete/replace path (Create, in-place Update, versioned Update) for a value that's
  cheap to compute on read; the correlated subquery has no write-side risk of drifting out of sync.

**Implementation**:
1. `EutrTemplatesResponseDto`: add `public int StepsCount { get; set; }`.
2. `EutrTemplatesRepository.GetPagedWithVendorNameAsync`: add the correlated-subquery column to the
   existing `SELECT` (same statement that already adds `VendorName`/`AlertForName`).
3. Frontend: `TemplateListPage.jsx`'s Steps column reads `tmpl.stepsCount` directly from the list
   response — no separate fetch, no client-side count derivation.

---

## 25. Bulk-Select Add Root Group / Add Child Step (spec Update 12)

**Decision**: Replace the `StepFormRow`-based single-step-at-a-time Dialog content in
`TemplateBuilderPage.jsx`'s Add Root Group/Add Child Step modal with a new
`BulkAddStepsDialog.jsx` component: a checkbox table of the real EUTR steps list (same
`GetEutrStepsUseCase` data already used), one row per step (Step Master label, per-row
Requirement Type/Take From `Autocomplete`s enabled only once that row is ticked), a header
select-all checkbox, a footer "{N} step available - {M} selected" counter, and a dedicated
"Add new step" input row (free-solo name entry, its own Requirement Type/Take From) that folds
its single pending entry into the same batch. Clicking **Add** calls one new `useStepTree`
function, `addSteps(stepsArray)`, that appends every ticked/typed step to the tree in a single
state update — instead of the dialog calling `onAdd` once per step (which existing `addStep`
already supports, but only one row at a time via `StepFormRow`).

**Rationale**: The design reference makes this a batch-selection interaction, not N repetitions of
the existing single-add flow — reusing `addStep` in a loop from the dialog's Add handler would
work functionally (each call reads the latest `prev` via the functional `setItems` updater), but
folds several intents ("add these 5 steps together") into N separate state transitions and N
`isDirty` flips for what the user experiences as one action; a single `addSteps` call keeps the
existing "one mutation → one dirty flip" shape `useStepTree`'s other bulk method
(`removeMultiSteps`) already established for its own multi-select delete. Building the table itself
from plain `@mui/material` (`Table`/`TableRow`/`Checkbox`) needs no new dependency — the same
package already renders every other list surface in this feature.

**Alternatives considered**:
- Keep calling `addStep` once per ticked row in a `for` loop inside the dialog's Add handler —
  rejected: works, but produces N intermediate tree states and N `isDirty` sets for a single user
  gesture; a dedicated `addSteps` batching function is a small addition that keeps the mutation
  atomic and matches the existing `removeMultiSteps` precedent for batch operations.
- Reuse `StepTree.jsx`'s per-row inline-form UI (checkbox multi-select + per-row inline edit) for
  this dialog instead of a new component — rejected: `StepTree.jsx`'s multi-select checkboxes exist
  for *deleting* already-added tree nodes, a different data shape (existing tree items, not the
  master steps list) and a different visual context (inline in the tree) than a modal listing
  available master steps to add; forcing it to serve both roles would tangle two independent
  concerns into one component.
- Support multiple simultaneous free-solo "Add new step" rows (an add/remove list of pending new
  names) — rejected as unnecessary for this update: the design reference and FR-030 describe a
  single dedicated entry area; a user who needs several brand-new step names can still invoke this
  dialog again per name, or (more commonly) type new names one at a time and click Add per batch.
  Kept as a documented default rather than a blocking clarification since a single-entry area is
  the literal, simplest reading of "một khu vực/hàng riêng biệt" (a separate area/row, singular).
- Auto-select all available steps by default when the dialog opens (assuming the common case is
  "add most of them") — rejected: FR-027 explicitly requires the footer counter to start at
  "0 đã chọn" and the Add button disabled until the user ticks something, matching the attached
  design image's initial (unticked) state exactly.

**Implementation**:
1. **`useStepTree.js`** — add `addSteps(newSteps)`: a single `setItems` call that, for each entry in
   `newSteps` (in array order), computes `displayOrder` continuing from the current count of
   siblings under that entry's `parentId` (recomputed as each entry is appended within the same
   updater pass, so entries sharing a `parentId` in one call still get sequential, non-colliding
   `displayOrder` values), assigns a fresh temp `_id` via the existing `nextTempId()`, and appends
   all resulting items in one array spread; sets `isDirty(true)` once. Exported alongside `addStep`
   (kept as-is — still used by `EutrTemplatesAddEdit.jsx`'s existing single-add flow, which stays
   out of scope per Update 10's decision to leave that file unrouted/unmodified).
2. **New `components/BulkAddStepsDialog.jsx`**: props `steps` (full master list from
   `GetEutrStepsUseCase`), `existingChildStepIds` (array/Set of `stepId`s already present as direct
   children of the target parent — computed by the caller per FR-029), `onAdd(stepsArray)`,
   `onClose`. Internal state: `checked` (Map: stepId → `{requirementType, takeFrom}` for ticked
   master rows, defaults `{0, 0}` applied the moment a row is ticked, per FR-027), `newStepDraft`
   (`{name, requirementType, takeFrom}` for the single "Add new step" area, `null` when empty).
   `available = steps.filter(s => !existingChildStepIds.includes(s.id))`. Renders a `Table` with a
   header row (`Checkbox` indeterminate/checked bound to `checked.size === available.length`), one
   `TableRow` per `available` step (row `Checkbox`, Step Master `TableCell`, Requirement
   Type/Take From `Autocomplete`s `disabled` until that row's `Checkbox` is ticked), then a final
   non-table "Add new step" row (`TextField`/`Autocomplete freeSolo` for the name, its own
   Requirement Type/Take From). Footer: `Typography` showing
   `` `${available.length} step available - ${checked.size + (newStepDraft ? 1 : 0)} selected` ``,
   `Button` Cancel (`onClose`, discards all local state), `Button` Add (`disabled` when
   `checked.size === 0 && !newStepDraft`) that builds the final array — `[...available.filter(s =>
   checked.has(s.id)).map(s => ({ stepId: s.id, stepName: s.name, parentId, ...checked.get(s.id)
   })), ...(newStepDraft ? [{ stepId: null, stepName: newStepDraft.name.trim(), parentId,
   requirementType: newStepDraft.requirementType, takeFrom: newStepDraft.takeFrom }] : [])]` — and
   calls `onAdd(thatArray)`, then `onClose()`.
3. **`TemplateBuilderPage.jsx`**: replace the `<StepFormRow ref={addStepFormRef} ... />` +
   `DialogActions` Add/Close pairing inside the existing `Dialog` (the one opened by `openAddRoot`/
   `openAddChild`) with `<BulkAddStepsDialog steps={steps} existingChildStepIds={...}
   onAdd={addSteps} onClose={() => setAddModal({ open: false, type: null })} />`.
   `existingChildStepIds` computed inline as
   `stepItems.filter(s => s.parentId === (addModal.type === 'root' ? 0 : selectedId)).map(s =>
   s.stepId)`. `addStepFormRef`/`addStepValid` state (only needed for the old single-row
   `StepFormRow` submit-via-ref pattern) are removed — `BulkAddStepsDialog` owns its own Add
   button/disabled logic internally, no parent-driven `ref.current.submit()` needed.
4. No backend, DTO, or contract change (see `contracts/api-endpoints.md` Update 12 note) — the
   existing `flattenForSave()`/Update-template payload shape is unaffected by how many rows were
   authored per dialog interaction.

---

## 26. Remove VendorCode from EutrTemplates (spec Update 13)

**Decision**: Delete `VendorCode` from `EutrTemplates` (entity), `EutrTemplatesRequestDto`, and the
derived `VendorName` from `EutrTemplatesResponseDto`, across every layer that touches it (see
plan.md's "VendorCode removal (backend)"/"(frontend)" subsections for the exhaustive file list).
Existing `VendorCode` data on live rows is discarded — no backfill into the new
`eutr_template_references` table. The `IsDefault` uniqueness constraint changes from per-VendorCode
to global (`ClearIsDefaultForVendorAsync(vendorCode, excludeId)` → `ClearGlobalDefaultAsync(excludeId)`).

**Rationale**: The user explicitly requested removing the column and its logic, replacing the
"one optional Vendor per template" model with a separate many-to-many, time-bound mapping
(`eutr_template_references` — Section 27). Discarding old data (rather than backfilling) was a
direct clarification answer (asked during `/speckit-specify`) — the user judged the old
single-Vendor-per-template values not worth preserving given the new model has fundamentally
different semantics (multiple vendors, date ranges) that a naive 1:1 backfill wouldn't represent
faithfully anyway (what `FromDate` would the migration invent for existing data? the confirmed
answer was: don't try, start clean). Making `IsDefault` global (rather than deleting the
constraint outright) was the other confirmed answer — a "no constraint at all" reading would let
arbitrarily many templates claim `IsDefault=1` simultaneously, which conflicts with every existing
UI affordance (`Default` chip, "Set as default" checkbox) implying a single, meaningful default.

**Alternatives considered**:
- Backfill existing `VendorCode` values into one `eutr_template_references` row per template before
  dropping the column — rejected per explicit user decision (see Q1 in spec.md's Update 13
  Clarifications): the two data models aren't equivalent (point value vs. date range), so any
  invented `FromDate`/`ToDate` would misrepresent history rather than preserve it.
- Keep `VendorCode` nullable but unused (soft-deprecate instead of dropping) — rejected: the user's
  explicit ask was "bỏ cột VendorCode... và các logic liên quan" (remove the column and related
  logic), not deprecate it; keeping a dead column/field would leave confusing surface area across
  ~10 files for no benefit, and this codebase's own precedent (the unused `GET /api/dynamics/vendors`
  endpoint left in place after Update 5) is reserved for cases where deleting risked breaking an
  unverified caller — here every caller is this feature's own code, fully traced.
- Leave the `IsDefault` constraint per-VendorCode by keying it off a "virtual" concept once Vendor
  moves to `eutr_template_references` (e.g., "default among templates applied to the same vendor
  set") — rejected as needlessly complex: a template can now be applied to zero, one, or many
  vendors via time-bound mappings, so "per-vendor default" has no single well-defined scope anymore;
  global is the simplest constraint that still gives "Default" a stable, unambiguous meaning.

**Implementation**: see plan.md's "VendorCode removal (backend)" and "(frontend)" subsections for
the complete, file-by-file change list (already traced via a dedicated Explore pass — every
touch-point has a concrete line reference, not a guess).

---

## 27. New `eutr_template_references` CRUD Stack (spec Update 13 — Apply to Customer)

**Decision**: Build a complete new CRUD stack (`EutrTemplateReferences` entity/DTOs/repository/
service/controller/validator, plus the matching frontend domain/infrastructure/application/
presentation layers) modeled directly on the existing `EutrTemplates`/`EutrTemplateDetails` stack,
rather than searching further for a closer-fit reference feature.

**Rationale**: `compl_template_reference` — a similarly-named table — was checked first as a
candidate reference (Principle II requires modeling new CRUD on an existing, working feature of the
same shape) but rejected: it has zero C# code, only three orphaned SQL stored procedures with no
application-layer caller found anywhere in the codebase. Reusing dead SQL as a "reference pattern"
would mean reverse-engineering conventions from unverified, unexercised code — worse than just
mirroring the `EutrTemplates` stack, which is proven working (handles the same audit-field
conventions, the same Dapper repository base class, the same policy-based controller shape) and
sits in the exact same feature folder structure the new table needs to fit into.

**Alternatives considered**:
- Model `EutrTemplateReferencesRepository`'s overlap check as a database-level constraint (e.g., a
  MySQL trigger or a generated/exclusion constraint) instead of an application-layer query —
  rejected: MySQL has no native date-range exclusion constraint (unlike PostgreSQL's `EXCLUDE`), and
  a trigger would bury business logic outside the Application layer, violating Principle I (business
  rules must not live in the database for this codebase's established pattern — every other
  cross-field validation in this feature, e.g. the 24h versioning threshold, lives in
  `EutrTemplatesService`, not in SQL).
- Give `EutrTemplateReferences` a soft-delete flag for consistency with `EutrTemplates` (`IsDeleted`)
  — rejected: the confirmed table design (`docs/design/eutr/eutr_db.sql`) has no such column, and
  the spec (FR-037) explicitly requires a hard delete; adding a flag not in the approved schema
  would silently diverge from the design doc for no requested benefit.
- Reuse the `EutrTemplatesController`/`EutrTemplatesService` classes directly (add
  reference-mapping methods onto the existing controller/service instead of new classes) — rejected:
  would conflate two different aggregates (Template header+steps vs. Template-to-Vendor mapping)
  behind one controller/service, working against Principle I's layer/responsibility boundaries and
  making the existing `EutrTemplatesController`/`Service` harder to reason about; a new, small,
  single-purpose stack is more consistent with how `eutr_template_details` already gets its own
  repository methods (not folded into a generic "everything EUTR" service) despite living under the
  same feature.

**Implementation**: see plan.md's "New: `eutr_template_references` backend CRUD" and "New:
Apply-to-Customer frontend" subsections; data-model.md's Entity 6; contracts/api-endpoints.md
Section 9.

---

## 28. Steps-Count Bug — Verify Before Fixing (spec Update 13, FR-042)

**Decision**: Do not write a speculative code fix for the user-reported "Steps column doesn't show
count" bug. Instead, trace the complete data path first (done during planning — see plan.md's
"Steps-Count Investigation" subsection) and hand `/speckit-tasks` a verification-first task: call
the real endpoint, compare against the DB, and only then decide whether/where a fix is needed.

**Rationale**: Two independent code audits (one during `/speckit-specify`, one during this
`/speckit-plan` pass) traced `EutrTemplatesController.GetPaged` → `EutrTemplatesService.GetPagedAsync`
→ `EutrTemplatesRepository.GetPagedWithVendorNameAsync`'s `StepsCount` correlated subquery →
`EutrTemplatesResponseDto.StepsCount` → default ASP.NET Core camelCase JSON serialization (verified
no `AddJsonOptions` override exists in `Program.cs`) → `TemplateListPage.jsx`'s
`tmpl.stepsCount ?? 0` binding, and found every link correct. The versioning path (`UpdateAsync`'s
≥24h branch correctly calls `BulkInsertDetailsAsync(newId, ...)`, inserting copied details under the
NEW `TemplateId` the grid will actually display) was also checked, ruling out the most plausible
"stale count after versioning" hypothesis. Writing a fix for a bug that cannot be located in the
current source risks either a no-op change (masking the real cause) or an unnecessary refactor of
already-correct code. The responsible move is to first establish whether the bug reproduces against
the CURRENT source (vs. an older deployed build, which is unverifiable from source alone) before
touching anything.

**Alternatives considered**:
- Rename/refactor `GetPagedWithVendorNameAsync`'s `StepsCount` subquery defensively (e.g., add an
  explicit `COALESCE(..., 0)` or switch to a `LEFT JOIN ... GROUP BY` instead of a correlated
  subquery) "just in case" — rejected: this is a solution in search of a problem; the existing
  subquery already returns `0` for a template with zero details (COUNT of an empty set is 0, not
  NULL), so a defensive `COALESCE` changes nothing behaviorally and would just be code churn.
- Add extensive backend logging around `StepsCount` to catch the bug next time it's reported —
  rejected as premature: a single manual Network-tab check (Scenario 18) answers the question
  immediately and costs nothing to run before implementation begins; logging can be added later if
  the manual check is inconclusive or the bug turns out to be intermittent.
- Assume the bug report is stale (already fixed by whichever update actually added `StepsCount`,
  i.e. Update 11) and simply mark FR-042/SC-035 resolved without further verification — rejected:
  the user re-reported this specific bug in the same message that asked for VendorCode removal and
  Apply-to-Customer, i.e., freshly, in this update — treating it as certainly-stale without checking
  would risk shipping a still-broken feature.

**Implementation**: see quickstart.md Scenario 18 for the exact verification steps and where to
record the outcome; plan.md's Steps-Count Investigation subsection for the full traced call path and
next-step triage order if the bug does reproduce.

---

## 29. Import/Export Vendor Mapping — Reuse the EutrTemplates* Excel Pattern + Reuse AddAsync Per Row (spec Update 14)

**Decision**: Build `EutrTemplateReferencesImportService`/`EutrTemplateReferencesExportService` as
close structural copies of the already-shipped `EutrTemplatesImportService`/
`EutrTemplatesExportService` (same ClosedXML usage, same row-loop/error-accumulation shape, same
controller-level `.xlsx`-only check and try/catch mapping), scoped by `templateId` instead of
operating on the whole table. Critically, each valid Import row is turned into an
`EutrTemplateReferencesRequestDto` and passed to the EXISTING `EutrTemplateReferencesService.AddAsync`
— the same method the manual "Apply Vendor" dialog already calls — rather than re-implementing its
`FluentValidation` rules or `HasOverlapAsync` check inside the import service.

**Rationale**: The request states "Logic giống như Add" (logic same as Add) explicitly — the most
direct, lowest-risk way to satisfy that in code is to literally call the same `AddAsync` method, not
to hand-copy its validation/overlap logic into a second place where the two could drift out of sync
over time (e.g., if `HasOverlapAsync`'s query changes later, an import-side copy would silently go
stale). This also solves the in-file overlap-sequencing requirement (FR-046 — a later row in the
same file must be checked against an earlier row's just-created mapping) for free: because each row's
`AddAsync` call commits its own transaction (`IUnitOfWork.BeginTransactionAsync`/`CommitAsync`,
already implemented) before the next row is read, `HasOverlapAsync` on row N+1 naturally sees row N's
already-persisted mapping — no separate in-memory "pending batch" tracking needed, unlike (for
example) the frontend's `BulkAddStepsDialog.jsx` (Update 12) which DOES need in-memory
de-duplication because its steps aren't persisted until the whole tree is saved at once. The two
situations look similar ("multiple rows added together") but resolve differently once you notice one
path persists row-by-row and the other batches everything into one client-side Save.

**Alternatives considered**:
- Pre-load all `templateId`'s existing mappings into memory, do a single custom overlap-check loop
  across (existing + all file rows) in the import service, then bulk-insert survivors — rejected:
  this duplicates `HasOverlapAsync`'s exact same date-range-intersection logic in a second place
  (Principle II violation — the point of reference-pattern reuse is to have ONE authoritative
  implementation, not two that need to stay in sync), and buys no real performance benefit at the
  expected scale ("a small number of vendor mappings per template", per data-model.md's Entity 6
  note) to justify the duplication risk.
- Make Import capable of creating templates too, if a `TemplateCode` in the file doesn't match any
  existing template (auto-provisioning) — rejected during the interactive scope clarification before
  writing spec Update 14: the user confirmed Import is scoped to the currently-open template only:
  TemplateCode in the file is a cross-check, not a routing key to other templates, so an unmatched
  code is always a row-level error, never an implicit create-elsewhere.
- Have Import UPDATE an existing mapping when a row's (VendorCode, exact FromDate/ToDate) matches one
  already in the table, instead of always inserting — rejected: the spec's Update 14 assumptions
  section explicitly rules this out ("Import KHÔNG hỗ trợ cập nhật... mọi dòng hợp lệ đều tạo bản ghi
  MỚI"); a duplicate row is intentionally treated as an overlap error like any other overlapping
  range, keeping Import's semantics identical to clicking "Apply Vendor" N times, never to clicking
  "Edit" on an existing row.
- Include a resolved `VendorName` column in the Export file for readability — rejected: the spec
  names exactly 4 columns (TemplateCode, VendorCode, FromDate, ToDate) and Export doubling as the
  Import template file only works if Export's column set exactly matches what Import expects; adding
  a 5th column would either break round-trip re-import (if Import then rejects the extra column) or
  require Import to silently ignore it — both worse than just not adding it. It also removes a D365
  call from Export entirely, which is a nice side benefit, not the primary reason.
- Introduce a new `EutrTemplateReferences.*` authorization policy family for the two new endpoints —
  rejected: the already-shipped `EutrTemplateReferencesController` (Update 13, verified in code during
  this planning pass) resolved its own "verify policy wiring" open item by reusing
  `EutrTemplates.Read/.Update/.Delete` directly, not by seeding new policies; the two new Import/
  Export actions follow that same already-established, working precedent instead of reopening a
  question Update 13 already answered in the shipped code.

**Implementation**: see plan.md's "Update 2026-07-14 (Update 14)" section for the full file-by-file
backend/frontend design; contracts/api-endpoints.md Section 9.5/9.6; quickstart.md Scenario 19.
