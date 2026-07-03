# Research: EUTR Templates Management

**Feature**: 003-eutr-templates | **Date**: 2026-07-03

## 1. VendorsV3 D365 Integration

**Decision**: Add a dedicated `GET /api/dynamics/vendors` endpoint in `DynController` following the
`data-area` pattern, instead of using the generic reference API.

**Rationale**: The codebase already integrates with D365 via OData through `IDynamicService` +
`DynamicsParameterManager`. The `data-area` endpoint pattern (`[HttpGet]` with `skip`, `top`,
`filter`, `order_by` query params → `SetEntity()` → `ParseAndValidate()` → `QueryAsync()` →
return raw OData JSON) is the simplest and most consistent approach for dedicated entity lookups.
The `VendorsV3.cs` domain model already exists in `Domain/Dynamics/` with `VendorAccountNumber`,
`VendorOrganizationName`, `dataAreaId`. The generic reference API (`POST /api/dynamics/reference`
with refType=13) already has a `VendorsV3` mapping in `ComplDynamicsService` but introduces
unnecessary indirection: the frontend `ReferenceObjectAutocomplete` component has an inconsistent
`referenceType === 13 → refType 4` conversion on initial load, causing the initial dropdown to
show Products instead of Vendors. A dedicated endpoint eliminates this bug at the architecture
level.

**Alternatives considered**:
- Fix the `ReferenceObjectAutocomplete` referenceType 13→4 conversion bug — rejected: the
  component is shared and changing its behavior may break other consumers. A dedicated endpoint
  is cleaner and avoids coupling to the shared reference component.
- Use the generic reference API with corrected refType — rejected: adds unnecessary abstraction
  layers (refType mapping, unified DTO) when a direct OData query is simpler and returns richer
  data (dataAreaId).
- Direct D365 OData calls from frontend — rejected: violates the backend-mediated architecture.

**Implementation**:
1. `VendorsV3.cs` already exists in `Domain/Dynamics/` — no changes needed.
2. Add `[HttpGet("vendors")]` method to `DynController.cs` following `data-area` pattern:
   `SetEntity("VendorsV3")` → `AddFilter(safeFilter)` → `SetOrderBy(order_by)` →
   `SetPaging(top, skip)` → `BuildUrl()` → append `$select=dataAreaId,VendorAccountNumber,VendorOrganizationName` to URL → `QueryAsync(url)` → return raw OData JSON.
3. `DynamicsParameterManager` (from `Res.Shared.ExternalServices` v1.0.11 NuGet package) does NOT
   have a `SetSelect()` method. The `$select` parameter must be appended manually to the URL string
   after `BuildUrl()` returns. Use string concatenation: check if URL already contains `?` then
   append `&$select=...`, otherwise `?$select=...`.
4. Frontend calls `GET /api/dynamics/vendors` directly (not the reference API).

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

## 9. Vendor Combobox — Dedicated Endpoint

**Decision**: Replace the vendor combobox implementation to call the new dedicated
`GET /api/dynamics/vendors` endpoint instead of the generic reference API.

**Rationale**: The previous approach used `ReferenceObjectAutocomplete` with `referenceType={13}`,
which has a known bug: initial load converts `referenceType 13` to `refType 4` (fetching Products
instead of Vendors), while subsequent search/pagination operations pass `13` directly (fetching
Vendors). This inconsistency means the initial dropdown may show product data. The dedicated
`GET /api/dynamics/vendors` endpoint returns raw OData with `VendorAccountNumber` and
`VendorOrganizationName` directly — no refType mapping, no shared component coupling.

**Alternatives considered**:
- Fix `ReferenceObjectAutocomplete` referenceType 13→4 mapping — rejected: the component is
  shared across features; changing it risks breaking other consumers.
- Use `ReferenceObjectAutocomplete` with `referenceType={13}` as-is — rejected: initial load
  bug shows wrong data (Products instead of Vendors).

**Implementation**:
1. Add `getVendors(skip, top, filter, orderBy)` method to `dynamicsApi.js` calling
   `GET /dynamics/vendors?skip=...&top=...&filter=...&order_by=...`.
2. Add `getVendors` method to `RestDynamicsRepository.js` and `IDynamicsRepository.js`.
3. Create `useVendors.js` hook in `eutr-templates/hooks/` — manages pagination, search
   debounce, and vendor list state by calling `getVendors`.
4. In `EutrTemplatesAddEdit.jsx`, replace `ReferenceObjectAutocomplete` with MUI Autocomplete
   backed by `useVendors` hook. Display `VendorAccountNumber + VendorOrganizationName`.
   In Edit mode, pre-select the template's current vendor.
5. For grid `vendorName` column: call the vendors endpoint to resolve VendorCode → name.

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
