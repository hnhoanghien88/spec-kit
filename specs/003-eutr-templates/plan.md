# Implementation Plan: EUTR Templates Management

**Branch**: `003-eutr-templates` | **Date**: 2026-07-03 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/003-eutr-templates/spec.md`

## Summary

Full-stack CRUD feature for managing EUTR compliance templates with recursive step trees.
Backend: .NET 8 API with Dapper/MySQL — template versioning (new row on edit, VersionId+1),
soft delete (IsDeleted=1), auto-generated sequential Code, D365 VendorsV3 integration via the
generic reference API (`POST /api/dynamics/reference`, `refType = 13`), and Excel import/export.
Frontend: React/MUI SPA — paginated grid, full-page Add/Edit form with **2-column layout**
(header left, step tree right), `@mui/x-tree-view` step tree with **inline Edit step** capability,
`@dnd-kit` drag-and-drop reordering, and vendor combobox backed by the generic reference API.

### Update 2026-07-03 — Bug Fixes & New Features

- **Fix**: Vendor combobox — replace broken `getReference()` call with `ReferenceObjectAutocomplete`
- **Fix**: ParentId — fix `flattenForSave` temp-ID-to-0 mapping to preserve parent-child tree
- **New**: Inline Edit step — toggle edit mode per step to change Step, RequirementType, TakeFrom
- **New**: 2-column layout — split Add/Edit page into header (left) + steps (right) columns

### Update 2026-07-03 — Dedicated Vendors API

- **Backend**: Add `GET /api/dynamics/vendors` endpoint in `DynController.cs` — follows `data-area`
  pattern (skip/top/filter/order_by query params, `SetEntity("VendorsV3")`,
  `_dynamicService.QueryAsync`). Uses existing `VendorsV3.cs` domain model.
- **Frontend**: Replace `ReferenceObjectAutocomplete` (referenceType=13) for vendor field with
  a direct call to `GET /api/dynamics/vendors`. New vendor API layer + custom autocomplete hook.
  Removes dependency on the generic reference API for vendor lookup.

### Update 2026-07-03 — Vendors Column Selection ($select)

- **Backend**: The `GET /api/dynamics/vendors` endpoint MUST append OData `$select` to the query
  URL to only retrieve 3 columns: `dataAreaId`, `VendorAccountNumber`, `VendorOrganizationName`.
  `DynamicsParameterManager` (from `Res.Shared.ExternalServices` NuGet package) does not have a
  `SetSelect()` method, so `$select` must be appended manually to the URL after `BuildUrl()`.
  This reduces the OData response payload from D365 and improves query performance.

### Update 2026-07-03 — Conditional Versioning (24h) + Add/Edit UI Changes

- **Backend**: `EutrTemplatesService.UpdateAsync` branches on `(DateTime.UtcNow - existing.CreatedDate) >= TimeSpan.FromHours(24)`.
  - **≥24h** (existing behavior): create new row (`VersionId+1`), copy details, hide old row (`IsHide=1`).
  - **<24h** (new behavior): update the existing row in place via the generic repository `UpdateAsync`
    (same `Id`/`VersionId`/`CreatedDate`, only mutable fields + `UpdatedBy`/`UpdatedDate` change),
    then replace `eutr_template_details` for that `TemplateId` (delete existing rows, bulk insert
    new tree) instead of inserting under a new `TemplateId`. Requires one new repository method:
    `ReplaceDetailsAsync(templateId, details, ct)` (delete-then-insert, reusing the existing
    `BulkInsertDetailsAsync` insert logic).
- **Frontend — Save button position**: Move the `<Button>` with `SaveIcon` out of the top title
  `Box` in `EutrTemplatesAddEdit.jsx` into the left column, placed directly after the `Default`
  `FormControlLabel`/checkbox. The Back button stays in the top title bar alone.
- **Frontend — column ratio**: Change `Grid item` width props in `EutrTemplatesAddEdit.jsx` from
  `md={5}` (header)/`md={7}` (steps) to `md={7}` (header)/`md={5}` (steps) — widening the header
  column, narrowing the step tree column.
- **Frontend — Back button dirty-check**: Add an `isDirty` boolean to `useStepTree.js`, flipped to
  `true` by `addStep`, `editStep`, `removeStep`, `removeMultiSteps`, and `reorderSiblings`; reset to
  `false` by `loadFromServer` (initial load) and explicitly after a successful Save. `Back` button
  onClick checks `isDirty`: if true, opens the existing `ConfirmDialog` component (pattern from
  `group-email/components/ConfirmDialog.jsx`) asking the user to confirm leaving with unsaved
  changes; if the user confirms, navigate away (changes discarded); if false, navigate immediately.

### Update 2026-07-06 — Free-solo Step Combobox + Auto-create Step

- **Frontend**: `StepFormRow.jsx` and the inline edit form in `StepTree.jsx` change the Step
  `Autocomplete` to `freeSolo`. Selecting an existing option sets `{ stepId, stepName }`; typing a
  name not in `options` sets `{ stepId: null, stepName: <typed text> }` (via `onInputChange`/
  `onChange` handling both option-object and raw-string values, same pattern already used for the
  `Alert for` field's `freeSolo` Autocomplete in `EutrTemplatesAddEdit.jsx`).
- **Frontend**: `useStepTree.js`'s `flattenForSave()` includes `stepName` in every emitted detail
  (not just `stepId`), so the backend receives the typed name even when `stepId` is `null`.
- **Backend**: `EutrTemplateDetailsRequestDto` gains `StepName` (string?, used only when `StepId`
  is null). `EutrTemplatesRequestDtoValidator` adds a per-detail rule: each detail MUST have either
  `StepId` or a non-blank `StepName`.
- **Backend**: `IEutrTemplatesRepository`/`EutrTemplatesRepository` gains
  `ResolveOrCreateStepsByNameAsync(names, userEmail, ct)` — case-insensitive/trimmed match against
  `eutr_steps`; creates missing ones; returns a name→Id map. Relies on MySQL's default
  case-insensitive collation for the match (same assumption already implicit in the codebase's
  plain `LIKE` filters, which use no explicit `LOWER()`).
- **Backend**: `EutrTemplatesService` calls this resolver (inside the existing transaction, before
  building detail entities) in `AddAsync` and both branches of `UpdateAsync`, then substitutes the
  resolved `StepId` for any detail whose `StepId` was null. Extracted into one private helper
  (`BuildDetailEntitiesAsync`) reused by all three call sites to avoid tripling the logic.

### Update 2026-07-06 — Revert Vendor API to Generic Reference (refType=13)

- **Reverts Update 2/3 (Dedicated Vendors API)**: The vendor combobox in `EutrTemplatesAddEdit.jsx`
  (`options={vendors}`) and the grid's Vendor name lookup MUST switch back from the dedicated
  `GET /api/dynamics/vendors` endpoint to the generic reference API
  `POST /api/dynamics/reference` with `refType = 13`.
- **Frontend**: Replace the `useVendors` hook (calling `dynamicsApi.getVendors`) with
  `ReferenceObjectAutocomplete` (or the underlying `useReferenceObjects` hook) configured with
  `referenceType={13}`, matching how other reference fields in the codebase already work.
  `EutrTemplatesAddEdit.jsx`'s `options={vendors}` Autocomplete is replaced by
  `ReferenceObjectAutocomplete` bound to `vendorCode`/`vendorName` state (or the grid's
  `vendorName` resolution switches to the same `useReferenceObjects` source).
- **Backend**: No backend change required — `POST /api/dynamics/reference` with `refType = 13`
  already exists and is already mapped to D365 VendorsV3 in `ComplDynamicsService` (per
  Principle III — reuse existing backend). The dedicated `GET /api/dynamics/vendors` endpoint
  added in Update 2/3 is left in place in `DynController.cs` but is no longer called by this
  feature (superseded, not deleted, to avoid an unreviewed backend removal).
- **Known quirk carried over**: `ReferenceObjectAutocomplete.jsx` has an existing special case —
  on initial (non-search) load it calls `fetchReferenceObjects(4, ...)` instead of the requested
  `referenceType` when `referenceType === 13` (see `ReferenceObjectAutocomplete.jsx` line ~65).
  This pre-dates this feature and affects other refType=13 consumers too; fixing it is out of
  scope for this reversal unless the user reports it as a regression during verification.

### Update 2026-07-07 — Alert For Combobox from compl_group_email

- **Change**: `AlertFor` switches from a free-text/hardcoded-options field (currently a `freeSolo`
  `Autocomplete` with placeholder `options={['PO', 'Upload manual']}` — copy-pasted from the
  TakeFrom field, not real data) to a single-select combobox sourced from `compl_group_email`
  (`GET /api/group-email`, `ComplGroupEmailController` — already exists, no new backend endpoint).
  The frontend reuses the existing `GetAllGroupEmailUseCase`/`repositories.groupEmail` pattern
  already used by `ComplianceMasterForm.jsx`/`MasterDefaultForm.jsx` for their "Alert" group
  pickers, filtered to `groupType === 2` (Alert) and `isAddition === false`.
- **Backend**: `AlertFor` changes type from `string` to `long?` in `EutrTemplates` (entity) and
  `EutrTemplatesRequestDto`. `EutrTemplatesResponseDto` gains `AlertForName` (resolved via a new
  `LEFT JOIN compl_group_email` in `EutrTemplatesRepository`, mirroring the existing
  `LEFT JOIN eutr_steps` for `StepName` — no external service call needed since
  `compl_group_email` is a local table, unlike D365 VendorsV3). Validator rule changes from
  `NotEmpty()` (string) to "must be a positive value" (numeric); existence in `compl_group_email`
  is NOT validated server-side, matching the existing unvalidated `VendorCode` field.
- **Migration**: `eutr_templates.AlertFor` column changes from `VARCHAR` to `BIGINT UNSIGNED NULL`.
  No DB-level FK constraint to `compl_group_email.Id` (same treatment as `VendorCode` → D365,
  which also has no FK) — avoids coupling group deletion to this feature.
- **Import/Export**: Import's AlertFor Excel column now expects the group's **Name** (exact match
  against `compl_group_email` where `GroupType=2`); no match → new error "Alert for group not
  found" (no auto-create, unlike the free-solo Step combobox). Export writes the resolved
  `AlertForName` instead of the raw Id, so exported files remain re-importable.
- **Frontend grid**: the `alertFor` grid column's `field` changes to `alertForName` (display),
  mirroring the existing `vendorCode`/`vendorName` split.
- See research.md Section 18 for full rationale and alternatives considered.

### Update 2026-07-07 — Shared RequirementType/TakeFrom Constants (frontend refactor)

- **Change**: Move `REQUIREMENT_TYPES`, `TAKE_FROM_OPTIONS`, `REQUIREMENT_LABELS`,
  `TAKE_FROM_LABELS` from `StepTree.jsx` into `compliance-client/src/utils/helpers.js` as named
  exports (verbatim values/shapes — no reshaping). Delete `StepFormRow.jsx`'s duplicate local
  `REQUIREMENT_TYPES`/`TAKE_FROM_OPTIONS` declaration; both files import from `utils/helpers.js`.
- **Scope**: Frontend-only, no backend/DB/contract changes. Pure presentation-layer internal
  reorganization — call sites (`options={REQUIREMENT_TYPES}`, `.find(...)`,
  `REQUIREMENT_LABELS[value]`) are unchanged.
- See research.md Section 19 for full rationale and alternatives considered.

### Update 2026-07-13 — TemplateListPage Rename + 2-Step Create/Edit Split

- **Frontend-only.** No backend/DB/contract changes — the existing Create/Update endpoints already
  accept `vendorCode: null` and `details: []`, which is exactly what the new lightweight Create
  payload needs (Principle III — reuse existing backend, verify only).
- **Rename**: `presentation/pages/eutr-templates/index.jsx` → renamed to
  `TemplateListPage.jsx`, component renamed `EutrTemplatesPage` → `TemplateListPage` (FR-019,
  per design reference `E:\Working\design\eutr\pages\TemplateListPage.jsx`). Follows the same
  file-naming convention already used by `EutrTemplatesAddEdit.jsx` in the same folder (a named
  file, not `index.jsx`).
- **New: `CreateTemplateDialog.jsx`** (`components/`) — a MUI `Dialog` with 3 fields (Name, Alert
  for combobox, Set as default checkbox) and Save/Cancel actions. Rendered from
  `TemplateListPage.jsx`, replacing the previous `navigate('/eutr/templates/add')` call. On Save,
  calls the existing `CreateEutrTemplatesUseCase` with `{ name, alertFor, isDefault, vendorCode:
  null, details: [] }`; on success, closes the dialog and calls the existing `fetchData()` list
  refresh (no navigation).
- **`EutrTemplatesAddEdit.jsx` becomes Edit-only**: the `/eutr/templates/add` route is removed
  (Create no longer navigates to a page); this component is only ever reached via
  `/eutr/templates/edit/:id`, so the `isEdit` branch is always true. Simplify by removing the
  `isEdit` conditionals (title always "Edit EUTR template", breadcrumb always "... > Edit", Code
  field always rendered). Vendor combobox and step tree (unchanged) remain here — this is now the
  sole place they appear (FR-004a, FR-011).
- **`MainRoutes.jsx` MODIFY** — remove the `{ path: "/eutr/templates/add", element:
  <EutrTemplatesAddEdit /> }` route entry; keep `/eutr/templates/edit/:id` as-is.
- **`RouteResolver.jsx` MODIFY** — update the lazy import from
  `@presentation/pages/eutr-templates` to `@presentation/pages/eutr-templates/TemplateListPage`.
- **No change (verified against FR-020)**: `useEutrTemplatesColumns.jsx` and
  `EutrTemplatesActionCell.jsx` already match the required column/action set (Code, Alert for
  present; no Status; Action = Edit + Delete only) — no code change needed.
- See research.md Section 20 for full rationale and alternatives considered.

### Update 2026-07-13 — TemplateListPage Table-Layout Reversal + TemplateBuilderPage Real-Data Wiring (spec Update 10) + Server-Side Search & Real Steps Count (spec Update 11)

**Mostly frontend.** Two small, additive backend changes (a `Keyword` pseudo-filter and a
`StepsCount` response field on the existing list query); everything else reuses
already-implemented use cases/components verbatim (Principle III).

- **Reverses Update 9's list-screen decision**: `TemplateListPage.jsx` no longer stays a 9-column
  DataGrid. It keeps its own pre-existing Table/search-box/chip layout (the file already looked
  like this, but ran on `EUTR_TEMPLATES`/`EUTR_TEMPLATE_DETAILS_MAP` mock data) and gets rewired to
  real data and real actions, reusing `TemplateListPageOld.jsx`'s already-working plumbing:
  `useEutrTemplatesData`, `permissionList` (via `getMenuDataFromStorage`), `DeleteEutrTemplatesUseCase`,
  `DeleteMultiEutrTemplatesUseCase`, `CreateTemplateDialog`, `ConfirmDialog`, `CustomSnackbar`.
  `TemplateListPageOld.jsx` itself is untouched — it stays as a reference/backup file, unrouted.
- **Reverses Update 9's Edit-target decision**: Edit no longer opens `EutrTemplatesAddEdit.jsx`'s
  2-column form/list layout. It opens `TemplateBuilderPage.jsx` (already the `MainRoutes.jsx` route
  target for `/eutr/templates/edit/:id` — this route was never actually changed back to
  `EutrTemplatesAddEdit`, so no routing file changes here), which gets rewired from its own mock
  data (`EUTR_TEMPLATES`, `EUTR_TEMPLATE_DETAILS_MAP`, `EUTR_STEPS`, `utils/treeUtils.js`) to the
  exact same real use cases/hook `EutrTemplatesAddEdit.jsx` already uses:
  `GetEutrTemplatesUseCase`, `UpdateEutrTemplatesUseCase`, `GetEutrStepsUseCase`,
  `GetAllGroupEmailUseCase`, `ReferenceObjectAutocomplete` (refType=13), and — this is the key
  reuse — the existing `useStepTree` hook (already implements `addStep`/`removeStep`(cascade)/
  `removeMultiSteps`/`editStep`/`reorderSiblings`/`flattenForSave`/`loadFromServer`/`isDirty`)
  instead of `TemplateBuilderPage.jsx`'s own parallel hand-rolled tree state + `utils/treeUtils.js`.
  `TemplateBuilderPage.jsx` keeps its own visual shell (tree on the left + side "Step Configuration"
  panel + toolbar with Add Root Group/Add Child Step/Move Up/Move Down/Delete/Expand/Collapse
  buttons) — this is *not* replaced with `StepTree.jsx`'s different UI (per-row inline forms,
  checkbox multi-select rows). Only the **data layer underneath** changes.
- **`EutrTemplatesAddEdit.jsx` becomes fully unrouted** (Update 9 already removed the `/add` route;
  this update removes its last remaining route, `/eutr/templates/edit/:id`, which now points at
  `TemplateBuilderPage.jsx`). Per the same conservative precedent as Update 5 (left the unused
  dedicated vendors endpoint in place rather than deleting it), `EutrTemplatesAddEdit.jsx` is left
  in the codebase, unreferenced by any route — a cleanup/removal candidate for a separate future
  task, not deleted as a side effect of this feature.
- **Mock fixtures become fully orphaned** after this change (verified by repo search — nothing else
  imports them): `mock/eutrTemplates.js`, `mock/eutrTemplateDetails.js`, `mock/eutrSteps.js`,
  `utils/treeUtils.js`. Same treatment: left in place, not deleted.
- **New backend addition — `Keyword` pseudo-filter** (spec Update 11, FR-021a): the search box on
  `TemplateListPage.jsx` reuses the *existing* filter pipeline as-is on the frontend
  (`useEutrTemplatesData`'s `filterModel`/`useFilterPayload`, unchanged) by sending one filter item
  `{ field: 'keyword', operator: 'contains', value: <term> }` (debounced, resets
  `paginationModel.page` to 0). `useFilterPayload` already title-cases the field name to `Keyword`
  automatically — no frontend hook change needed. The one addition is backend-only: inside
  `EutrTemplatesRepository`'s existing WHERE-clause builder for `GetPagedWithVendorNameAsync`, a
  `Keyword` column is special-cased (like `AlertFor → g.Name` in Update 7) into
  `(Code LIKE @p OR Name LIKE @p)` instead of a single-column comparison.
- **New backend addition — real `StepsCount`** (spec Update 11, FR-021c): `GetPagedWithVendorNameAsync`
  gains one more selected expression,
  `(SELECT COUNT(*) FROM eutr_template_details d WHERE d.TemplateId = t.Id) AS StepsCount`,
  alongside the existing `VendorName`/`AlertForName` resolution. `EutrTemplatesResponseDto` gains
  `StepsCount` (int).
- **Delete — bulk select added to the Table UI** (spec Update 10, FR-022): `TemplateListPage.jsx`
  gains a per-row checkbox + toolbar bulk-delete button, reusing `DeleteMultiEutrTemplatesUseCase`
  + `ConfirmDialog` exactly as `TemplateListPageOld.jsx` already does (this affordance did not
  exist in the Table-layout mock before).
- **Clone / Apply to Customer — disabled, not removed** (spec Update 10, FR-026): the two action
  icons already present in `TemplateListPage.jsx`'s mock markup are kept but rendered `disabled`;
  their mock `onClick` handlers (`setCloneOpen`, `navigate('/eutr/templates/:id/customers')`) and
  the Clone confirmation dialog are removed since Update 10 explicitly decided "kept but disabled,"
  not "kept functional against mock data."
- **Pagination control — new, was missing**: `TemplateListPage.jsx`'s existing Table markup has no
  pagination control at all (the mock rendered the full in-memory array). FR-003 requires
  pagination; add a `TablePagination` (already available via `@mui/material`, no new dependency)
  bound to `paginationModel`/`setPaginationModel`/`total` from `useEutrTemplatesData`.
- **Add Root Group / Add Child Step forms on TemplateBuilderPage** (spec Update 10, FR-025): the
  `Select` bound to the `EUTR_STEPS` mock array becomes a free-solo `Autocomplete` bound to the
  real steps list (same pattern as `StepFormRow.jsx`), and the 8-option mock `TAKE_FROM_OPTIONS`
  (`'Vendor'`, `'PO'`, `'D365-Invoice'`, …) plus the mock-only **Type** (Cá nhân/Tổ chức) and **FSC**
  (Yes/No) fields are removed — none of these exist in the real `EutrTemplateDetails` schema, which
  only has `RequirementType` (0/1) and `TakeFrom` (0/1). `REQUIREMENT_TYPES`/`TAKE_FROM_OPTIONS`/
  `REQUIREMENT_LABELS`/`TAKE_FROM_LABELS` are imported from `utils/helpers.js` (already shared
  since Update 8) instead of the mock file's own `TAKE_FROM_OPTIONS`/`CHIP_COLORS`.
- **Step reordering — buttons, not drag-and-drop, on this screen**: `TemplateBuilderPage.jsx`
  already has Move Up/Move Down toolbar buttons (not a drag handle). Per FR-024's explicit
  "keep the current bố cục" instruction, these are wired to `useStepTree`'s `reorderSiblings`
  (already implemented for `@dnd-kit` drag-and-drop in `StepTree.jsx`) instead of adding a drag
  interaction here. This is a deliberate, spec-compliant interaction-pattern difference between the
  two screens that both edit the same `RequirementType`/`TakeFrom`/`DisplayOrder` data — not a gap.
- **Save behavior on TemplateBuilderPage**: the current mock `handleSaveDraft` (no-op, shows a
  local success message, stays on page) is replaced with a real Save — build
  `{ name, vendorCode, alertFor, isDefault, details: flattenForSave() }`, call
  `UpdateEutrTemplatesUseCase.execute(id, payload)` (conditional 24h versioning already implemented
  server-side, Section 13), then **navigate to `/eutr/templates`** on success (matching
  `EutrTemplatesAddEdit.jsx`'s existing post-Save redirect — not "stay on page" like the mock did).
- **Right-hand "Step Configuration" panel dual role** (FR-024): when no step is selected, it shows
  the header form (Code readonly, Name, Alert for combobox, Vendor combobox, Set-as-default
  checkbox, Save button) — reusing the exact same field bindings `EutrTemplatesAddEdit.jsx` already
  has. When a step is selected, it shows that step's detail (Step Master via the real free-solo
  steps list, RequirementType/TakeFrom via the shared `utils/helpers.js` constants) with Save/Delete
  — Type/FSC removed as above.
- **Back button dirty-check reused as-is**: `TemplateBuilderPage.jsx`'s Back button gets the same
  `isDirty` (from `useStepTree`) + `ConfirmDialog` wiring already implemented for
  `EutrTemplatesAddEdit.jsx` (Section 15) — no new pattern.
- See research.md Sections 21–24 for full rationale and alternatives considered.

### Update 2026-07-13 (Update 12) — Bulk-Select Add Root Group / Add Child Step

**Frontend-only, no backend/DB/contract changes** — the Create/Update payload's `details[]` array
shape is identical whether it was authored one row per dialog open (previous behavior) or several
rows per dialog open (this update); the existing `flattenForSave()`/Update endpoint already accept
any number of detail rows (Principle III — verify only, no backend change needed).

- **New `components/BulkAddStepsDialog.jsx`**: replaces the `StepFormRow`-based single-step Dialog
  content in `TemplateBuilderPage.jsx`'s Add Root Group/Add Child Step modal. Renders a checkbox
  table of the real EUTR steps list (`GetEutrStepsUseCase`, unchanged), one row per available step
  with per-row Requirement Type/Take From `Autocomplete`s enabled only once ticked, a header
  select-all checkbox, a footer "{N} step available - {M} selected" counter with Cancel/Add
  (disabled at 0 selected), and a single dedicated "Add new step" free-solo entry row that folds
  into the same batch on Add.
- **`useStepTree.js` MODIFY** — add `addSteps(newSteps)`, a bulk sibling of the existing `addStep`:
  appends N items to the tree in one `setItems` call (sequential `displayOrder` per target
  `parentId`, one `isDirty(true)` flip) instead of the dialog looping `addStep` N times. `addStep`
  itself is unchanged (still used by `EutrTemplatesAddEdit.jsx`'s single-add flow, which stays
  out of scope — that file remains unrouted/unmodified per Update 10).
- **`TemplateBuilderPage.jsx` MODIFY** — swap the `<StepFormRow>` + ref-driven submit pairing inside
  the existing Add Root/Child `Dialog` for `<BulkAddStepsDialog onAdd={addSteps} ... />`; compute
  `existingChildStepIds` (direct children of the target parent, by `stepId`) and pass it to the
  dialog so already-added-under-this-parent steps are excluded from the selectable list (FR-029);
  remove the now-unused `addStepFormRef`/`addStepValid` state (the old ref-driven single-submit
  pattern `StepFormRow` needed).
- **Edit step on an existing tree node is unchanged** — still `editStep` via the right-hand panel's
  single-step form (FR-008b/FR-031), not touched by this update.
- See research.md Section 25 for full rationale and alternatives considered.

### Update 2026-07-13 (Update 13) — Remove VendorCode, Add Apply-to-Customer, Investigate Steps-Count Bug

**Backend: real removal + real new CRUD.** VendorCode is fully implemented today (entity, DTOs,
repository whitelist/SQL, service default-per-vendor logic, import/export, D365 sync model) — this
is a genuine deletion across ~10 backend files, not a no-op. `eutr_template_references` has zero
backend today — a full new CRUD stack must be built from scratch, modeled on the `EutrTemplates*`
stack per Principle II. Steps-count: traced the full call path (Controller → Service → Repository
SQL → DTO → Dapper → JSON camelCase → `TemplateListPage.jsx`'s `tmpl.stepsCount` binding) and found
**no code defect** — every layer is correctly wired. See the Steps-Count Investigation subsection
below for how this is handled without inventing a speculative fix.

#### VendorCode removal (backend)

- **`ComplianceSys.Domain/Entities/EutrTemplates.cs`** MODIFY — delete `public string? VendorCode
  { get; set; }` (line 16).
- **`ComplianceSys.Application/Dtos/Request/EutrTemplatesRequestDto.cs`** MODIFY — delete
  `VendorCode` property (line 7).
- **`ComplianceSys.Application/Dtos/Response/EutrTemplatesResponseDto.cs`** MODIFY — delete
  `VendorName` property (line 8); `VendorCode` disappears automatically once removed from the base
  `EutrTemplates` entity.
- **`ComplianceSys.Infrastructure/Repositories/EutrTemplatesRepository.cs`** MODIFY:
  - `SortMap`/`FilterMap` — delete the `"VendorCode"` entries.
  - `GetPagedWithVendorNameAsync` (rename to `GetPagedAsync` — it no longer resolves a vendor name)
    and `GetByIdWithDetailsAsync` — drop `t.VendorCode` from both header `SELECT` lists.
  - `ClearIsDefaultForVendorAsync(string vendorCode, long? excludeId, ct)` → renamed
    `ClearGlobalDefaultAsync(long? excludeId, ct)`, dropping the `VendorCode = @vendorCode` WHERE
    predicate entirely (global default constraint per FR-040).
- **`ComplianceSys.Application/Interfaces/Repositories/IEutrTemplatesRepository.cs`** MODIFY — same
  signature rename/change on the interface.
- **`ComplianceSys.Application/Services/EutrTemplatesService.cs`** MODIFY:
  - `GetPagedAsync` — delete the entire D365 `VendorsV3` vendor-name-resolution block (lines 46–72);
    method reduces to `return await _repository.GetPagedAsync(request, ct);`. `IComplDynamicsService
    _dynamicsService` field/ctor param and the `ComplianceSys.Domain.Dynamics` `using` become unused
    and are removed (not used elsewhere in this class).
  - `AddAsync` and both branches of `UpdateAsync` (3 call sites total) — replace the
    `if (dto.IsDefault == 1 && !string.IsNullOrWhiteSpace(dto.VendorCode)) await
    _repository.ClearIsDefaultForVendorAsync(dto.VendorCode, id, ct);` guard with
    `if (dto.IsDefault == 1) await _repository.ClearGlobalDefaultAsync(id, ct);` (using `id` or
    `newId` as appropriate per branch — matches FR-040).
  - Class-level Vietnamese comment ("rang buoc IsDefault toi da 1 per VendorCode") updated to
    reflect the global constraint.
- **`ComplianceSys.Application/Services/EutrTemplatesImportService.cs`** MODIFY — Excel column
  layout shifts left by one: was `A=Name, B=AlertFor, C=VendorCode, D=IsDefault`; becomes
  `A=Name, B=AlertFor, C=IsDefault`. Delete the `vendorCode` cell read (line 44) and the
  `VendorCode = ...` line in the constructed DTO (line 94); change `row.Cell("D")` (IsDefault) to
  `row.Cell("C")`. Update the class doc-comment (lines 10–11) to match the new layout.
- **`ComplianceSys.Application/Services/EutrTemplatesExportService.cs`** MODIFY — headers array
  `{ "Code", "Name", "Vendor code", "Alert for", "Default", "Version" }` → `{ "Code", "Name", "Alert
  for", "Default", "Version" }`; delete the `item.VendorCode` cell write (was column 3), shift
  `AlertForName`/`IsDefault`/`VersionId` writes from columns 4/5/6 to 3/4/5. Update class comment.
- **`ComplianceSys.Domain/Dynamics/RSVNEutrTemplates.cs`** MODIFY — delete the `VendorCode` property
  and its `FilterableFields` dictionary entry (this is the D365-sync-facing model, `ModelType =>
  17`; no other caller of this class was found in this pass — `/speckit-tasks` should re-verify with
  a repo-wide grep before deleting, in case a sync job references it elsewhere).
- **`ComplianceSys.Application/Validators/EutrTemplatesRequestDtoValidator.cs`** — verified, no
  VendorCode rule exists today; **no change needed** (avoids inventing a phantom task).
- **`ComplianceSys.Application/Mappings/EutrMappingProfile.cs`** — no explicit `.ForMember` for
  VendorCode exists (was mapped by convention); **verify only**, no code change expected.
- **`ComplianceSys.Api/Controllers/EutrTemplatesController.cs`** — confirmed no vendor-specific
  endpoints/params; **no controller change needed** beyond what cascades from the DTOs.

#### VendorCode removal (frontend)

- **`domain/entities/EutrTemplates.js`** MODIFY — delete `vendorCode`/`vendorName`
  constructor params + assignments.
- **`presentation/pages/eutr-templates/hooks/useEutrTemplatesColumns.jsx`** MODIFY — delete the
  `vendorCode`/`vendorName` entries from `defaultColumnVisibility` and the `columns` array (this
  hook feeds the unrouted `TemplateListPageOld.jsx` DataGrid — kept in sync for consistency even
  though it's not on the active route, same conservative precedent as prior updates).
- **`presentation/pages/eutr-templates/TemplateBuilderPage.jsx`** MODIFY — delete `vendorCode`/
  `vendorName` state (`useState`), the two `setVendorCode`/`setVendorName` calls in the template-load
  effect, the `vendorCode: vendorCode || null` line in the Save payload, and the entire `Vendor`
  `ReferenceObjectAutocomplete` block (refType=13/14 picker) between the Alert-for field and the
  Set-as-default checkbox. Remove the now-unused `ReferenceObjectAutocomplete` import (this file's
  only usage of it — implements FR-041).
- **`presentation/pages/eutr-templates/components/CreateTemplateDialog.jsx`** MODIFY — delete the
  `vendorCode: null` line from the `createUseCase.execute({...})` payload (the dialog never had a
  Vendor UI control; this was a hardcoded placeholder value only).

#### New: `eutr_template_references` backend CRUD (Apply to Customer)

No existing C# code to reuse for this table — `compl_template_reference` (a similarly-named but
unrelated table used by a different, orphaned feature) has only stray `.sql` stored procedures with
zero C# callers, so it is not a viable structural reference. The new stack is modeled directly on
the working `EutrTemplates*` stack instead (Principle II):

- **`ComplianceSys.Domain/Entities/EutrTemplateReferences.cs`** NEW — inherits `BaseEntity` (same
  as `EutrTemplates`/`EutrTemplateDetails`, gives `CreatedBy/CreatedDate/UpdatedBy/UpdatedDate`).
  Properties: `TemplateId` (long), `VendorCode` (string), `FromDate` (DateTime), `ToDate`
  (DateTime). No `IsDeleted`/`IsHide` — per spec this table has no soft-delete flag.
- **`ComplianceSys.Application/Dtos/Request/EutrTemplateReferencesRequestDto.cs`** NEW —
  `TemplateId`, `VendorCode`, `FromDate`, `ToDate`.
- **`ComplianceSys.Application/Dtos/Response/EutrTemplateReferencesResponseDto.cs`** NEW — inherits
  `EutrTemplateReferences` + adds `VendorName` (string?, resolved via the existing D365 refType=13
  reference lookup — the SAME `IComplDynamicsService`/generic reference mechanism used previously
  for the template's own Vendor field, now relocated here).
- **`ComplianceSys.Application/Interfaces/Repositories/IEutrTemplateReferencesRepository.cs`** NEW —
  `GetByTemplateIdAsync(templateId, ct)`, `HasOverlapAsync(templateId, vendorCode, fromDate, toDate,
  excludeId, ct)` (same-template-same-vendor overlap check per FR-036), plus base CRUD via
  `IRepository<EutrTemplateReferences, long>`.
- **`ComplianceSys.Infrastructure/Repositories/EutrTemplateReferencesRepository.cs`** NEW — extends
  `DapperRepository<EutrTemplateReferences, long>`. `GetByTemplateIdAsync`: `SELECT ... FROM
  eutr_template_references r WHERE r.TemplateId = @templateId ORDER BY r.FromDate DESC` (Vendor
  name resolved in the service layer via D365, same pattern as the old template-level vendor
  resolution — reused, not reinvented). `HasOverlapAsync`: `SELECT COUNT(1) FROM
  eutr_template_references WHERE TemplateId = @templateId AND VendorCode = @vendorCode AND
  FromDate <= @toDate AND ToDate >= @fromDate` + `AND Id <> @excludeId` when editing (implements
  FR-036's same-template-only overlap scope — deliberately does NOT filter by `VendorCode` across
  different `TemplateId`s, per the confirmed decision).
- **`ComplianceSys.Application/Interfaces/Services/IEutrTemplateReferencesService.cs`** +
  **`.../Services/EutrTemplateReferencesService.cs`** NEW — `BaseService<EutrTemplateReferences,
  long, EutrTemplateReferencesRequestDto>` override: `AddAsync`/`UpdateAsync` call
  `HasOverlapAsync` first and throw a validation error if overlapping (FR-036); `DeleteAsync` is a
  genuine hard delete (`_repository.DeleteAsync(id, ct)` from the base `IRepository`, no soft-delete
  override — FR-037).
- **`ComplianceSys.Application/Validators/EutrTemplateReferencesRequestDtoValidator.cs`** NEW —
  `VendorCode` NotEmpty, `FromDate` required, `ToDate` optional but `Must(dto => !dto.ToDate.HasValue
  || dto.ToDate >= dto.FromDate)` when present (FR-036).
- **`ComplianceSys.Api/Controllers/EutrTemplateReferencesController.cs`** NEW — `[Route("api/eutr-
  template-references")]`, mirrors `EutrTemplatesController.cs`'s shape: `GET by-template/{templateId:long}`
  (list, FR-033), `POST` (create/apply, FR-034), `PUT {id:long}` (edit, FR-035), `DELETE {id:long}`
  (hard delete, FR-037). New authorization policies `EutrTemplateReferences.ReadAll/.Create/.Update/
  .Delete` — **flagged for verification during `/speckit-implement`** (matching the precedent set in
  Update 7 for `GroupEmail.ReadAll`): confirm the policy-registration mechanism (appsettings/DB seed)
  and whether these can simply reuse the existing `eutr-templates` menu's permission list instead of
  a brand-new menu entry, since Apply-to-Customer is reached via a row action icon, not a new
  top-level menu item.
- **Migration**: `ComplianceSys.Infrastructure/Sqls/Migration/11_create_eutr_template_references.sql`
  NEW — `CREATE TABLE eutr_template_references (...)` per `docs/design/eutr/eutr_db.sql`'s DDL
  (numbered after the existing `10_add_stepid_to_eutr_references.sql`; this folder is applied
  manually against existing environments — confirmed not wired into `DatabaseInitializer.cs`).
  **`ComplianceSys.Infrastructure/Sqls/Tables/eutr_db.sql`** MODIFY — also add the same CREATE TABLE
  there, since that script (unlike `Sqls/Migration/`) IS auto-executed by `DatabaseInitializer` for
  brand-new/fresh databases (`InitTables()`); skipped entirely if the DB already exists. Note:
  `eutr_db.sql` is already drifted from the live schema (missing `Code`/`AlertFor`/`IsDeleted`/
  `IsHide` on `eutr_templates`) — a pre-existing gap, not introduced by this update.
- **DI registration** — `ComplianceSys.Application/DependencyInjection.cs` MODIFY: add
  `services.AddScoped<IEutrTemplateReferencesService, EutrTemplateReferencesService>();` +
  `services.AddScoped<IValidator<EutrTemplateReferencesRequestDto>,
  EutrTemplateReferencesRequestDtoValidator>();`, alongside the existing `EutrTemplates*`
  registrations. `ComplianceSys.Infrastructure/DependencyInjection.cs` MODIFY: add
  `services.AddScoped<IEutrTemplateReferencesRepository, EutrTemplateReferencesRepository>();`.
- **`ComplianceSys.Application/Mappings/EutrMappingProfile.cs`** MODIFY — add
  `CreateMap<EutrTemplateReferencesRequestDto, EutrTemplateReferences>()` (ignore `Id`/audit fields,
  same pattern as the existing `EutrTemplates`/`EutrTemplateDetails` maps).

#### New: Apply-to-Customer frontend

- **`domain/entities/EutrTemplateReferences.js`** NEW — mirrors `EutrTemplates.js`/
  `EutrTemplateDetails.js`'s constructor-destructuring pattern: `id, templateId, vendorCode,
  vendorName, fromDate, toDate, createdBy, createdDate, updatedBy, updatedDate`.
- **`domain/interfaces/IEutrTemplateReferencesRepository.js`** NEW — mirrors
  `IEutrTemplatesRepository.js`'s interface shape.
- **`infrastructure/api/eutrTemplateReferencesApi.js`** NEW — axios wrapper, mirrors
  `eutrTemplatesApi.js` (get-by-template, create, update, delete; no import/export needed).
- **`infrastructure/repositories/RestEutrTemplateReferencesRepository.js`** NEW — mirrors
  `RestEutrTemplatesRepository.js`'s method shape (`getByTemplateId(templateId)`, `create(payload)`,
  `update(id, payload)`, `delete(id)`), wrapping results in `EutrTemplateReferences`.
- **`application/usecases/eutr-template-references/`** NEW — one file per operation, matching this
  codebase's established one-use-case-per-operation convention:
  `GetByTemplateIdEutrTemplateReferencesUseCase.js`, `CreateEutrTemplateReferencesUseCase.js`,
  `UpdateEutrTemplateReferencesUseCase.js`, `DeleteEutrTemplateReferencesUseCase.js`.
- **`presentation/pages/eutr-templates/ApplyCustomerPage.jsx`** MODIFY (rewrite mock → real) — this
  file already exists as a reference-design UI built against `MOCK_CUSTOMERS`/
  `MOCK_TEMPLATE_CUSTOMERS` (`mock/eutrTemplates.js`) and a `template.status !== 'Published'` gate.
  Rewire it: "Customer" concept → "Vendor" (combobox sourced from the generic reference API
  `POST /api/dynamics/reference`, `refType = 13`, same source already used elsewhere in this
  feature — via `ReferenceObjectAutocomplete`/`useReferenceObjects`, NOT a new dedicated vendor
  endpoint, per the Update 5/6 precedent of reusing the generic reference mechanism); drop the
  `status !== 'Published'` gate entirely (real `EutrTemplate` has no Status concept); load/save
  through the new `eutr-template-references` use cases instead of local component state; keep the
  existing `hasOverlap()` client-side pre-check logic nearly as-is, just rescoped from `customerId`
  to `vendorCode` (server-side `HasOverlapAsync` is the authoritative check — FR-036 — the
  client-side check is a fast-fail UX nicety, not the source of truth).
- **`presentation/pages/eutr-templates/TemplateListPage.jsx`** MODIFY — the "Apply to Customer"
  `IconButton` (currently `disabled`, per Update 10/FR-026) becomes active:
  `onClick={() => navigate(\`/eutr/templates/apply/${tmpl.id}\`)}`, gated the same way the existing
  Edit icon is (`permissionList.includes('Update')` or an equivalent check — to confirm at
  `/speckit-tasks` per the policy-naming question above). Clone stays disabled/unchanged.
- **`di/repositories.js`** MODIFY — add `import { RestEutrTemplateReferencesRepository } from
  '@infrastructure/repositories/RestEutrTemplateReferencesRepository';` and
  `eutrTemplateReferences: new RestEutrTemplateReferencesRepository(),` alongside the existing
  `eutrTemplates` entry.
- **`app/routes/groups/MainRoutes.jsx`** MODIFY — add a lazy `ApplyCustomerPage` import (same
  `Loadable(lazy(() => import('@presentation/pages/eutr-templates/ApplyCustomerPage')))` pattern as
  `TemplateBuilderPage`) and a new route object `{ path: '/eutr/templates/apply/:id', element:
  <ApplyCustomerPage /> }` in the same `PrivateRoute`-guarded children array, right after the
  existing `/eutr/templates/edit/:id` entry.

#### Steps-Count Investigation (FR-042) — verify-first, no speculative fix

Traced the full path end to end and found **every layer already correct**:
`EutrTemplatesController.GetPaged` → `EutrTemplatesService.GetPagedAsync` →
`EutrTemplatesRepository.GetPagedWithVendorNameAsync` (the `StepsCount` correlated subquery, SQL
alias `StepsCount`, binds case-insensitively to `EutrTemplatesResponseDto.StepsCount`) → default
ASP.NET Core `System.Text.Json` camelCase policy (no `AddJsonOptions` override found in `Program.cs`,
so `stepsCount` serializes consistently with every other field) → `TemplateListPage.jsx` reads
`tmpl.stepsCount ?? 0` directly from the unwrapped API response. The versioning path
(`EutrTemplatesService.UpdateAsync`, ≥24h branch) was also checked — `BulkInsertDetailsAsync(newId,
details, ct)` correctly inserts the copied step tree under the **new** `TemplateId`, so a
freshly-versioned template's `StepsCount` subquery (which joins on the currently-displayed row's
`Id`) should reflect the copied steps correctly, not zero.

**Given no code defect surfaced across two independent audits, this update does NOT introduce a
speculative code change for FR-042.** Instead, `/speckit-tasks` MUST include a verification-first
task: call `POST api/eutr-templates/get-all` directly (e.g. via the browser network tab or a REST
client) against a template with known steps — one freshly created (<24h) and one that has gone
through a version bump (≥24h) — and inspect the raw JSON for `stepsCount`. If the bug reproduces
there, the next investigation targets are (in order): (a) whether the currently-deployed backend
build actually matches this source (stale deploy), (b) MySQL collation/edge-cases in the correlated
subquery against production data, (c) any client-side caching (React state not refreshing after
Save). If it does NOT reproduce, FR-042/SC-035 are marked resolved with the verification evidence
recorded in `quickstart.md`, and no code change is needed for this item.

### Update 2026-07-14 (Update 14) — Import/Export Vendor Mapping on ApplyCustomerPage

**Backend: two new Excel services, modeled 1:1 on the existing `EutrTemplatesImportService`/
`EutrTemplatesExportService`, plus two new controller actions scoped by `templateId`. Frontend:
Import/Export buttons added to the already-implemented `ApplyCustomerPage.jsx` toolbar.** No new
DB table/columns, no new route, no new authorization policy family — the row-level "Add" logic is
reused directly from the existing `EutrTemplateReferencesService.AddAsync` (already live in the
codebase per Update 13), which is exactly what "Logic giống như Add" in the request means in code
terms: call the same method, don't reimplement its validation/overlap-check.

**Verified against the actual (already-implemented) code, not just the spec**: `ApplyCustomerPage.jsx`,
`EutrTemplateReferencesController.cs`, `EutrTemplateReferencesService.cs`,
`EutrTemplateReferencesRequestDtoValidator.cs`, and `IEutrTemplatesService.GetByIdWithDetailsAsync`
all already exist and match plan.md's Update 13 design as shipped. One drift from the Update 13
contracts.md draft is corrected here rather than carried forward: the controller does **not** use a
new `EutrTemplateReferences.*` policy family (contracts.md had flagged this as "verify wiring" —
unresolved at plan time); the shipped controller instead reuses `EutrTemplates.Read/.Update/.Delete`
directly. The new Import/Export actions below follow that same already-resolved pattern.

#### Backend

- **`ComplianceSys.Application/Dtos/Response/ImportEutrTemplateReferencesResultDto.cs`** NEW —
  mirrors `ImportEutrTemplatesResultDto.cs`'s shape exactly: `TotalRows`/`SuccessCount`/`FailCount`/
  `Errors` (list of `ImportEutrTemplateReferencesRowError { Row, TemplateCode, VendorCode, Message }`).
- **`ComplianceSys.Application/Interfaces/Services/IEutrTemplateReferencesImportService.cs`** +
  **`.../Services/EutrTemplateReferencesImportService.cs`** NEW —
  `ImportFromExcelAsync(long templateId, Stream fileStream, string userEmail, CancellationToken ct)`:
  1. `await _eutrTemplatesService.GetByIdWithDetailsAsync(templateId, ct)` — if `null`, throw
     `KeyNotFoundException` (controller → 404; same "template not found" condition already called
     out as an edge case for the mapping-list load in Update 13).
  2. Open the workbook (ClosedXML, same as `EutrTemplatesImportService`); read the header row and
     verify it has exactly 4 columns named `TemplateCode`, `VendorCode`, `FromDate`, `ToDate`
     (case-insensitive, trimmed) — mismatch throws `InvalidOperationException` (controller already
     has a `catch (InvalidOperationException)` → 400 branch, same pattern as
     `EutrTemplatesController.Import`), so no row is ever processed against a malformed file.
  3. For each data row (row 2..last, skipping fully-empty rows), `TotalRows++`, then validate in
     order: (a) `TemplateCode` (trimmed) must equal `template.Code` exactly — mismatch adds a row
     error `"TemplateCode does not match the current template"` and `continue`s (FR-046, FR-048 —
     this row is skipped entirely, never dispatched to any other template); (b) `VendorCode`/
     `FromDate` non-blank; (c) `ToDate` blank → sentinel `9999-12-31` (same `UNLIMITED_DATE` constant
     already used in `ApplyCustomerPage.jsx`), else parsed; (d) `ToDate >= FromDate`. Each failed
     check adds a row error and `continue`s — no per-check throw, same flat-validation style as
     `EutrTemplatesImportService`.
  4. Build `new EutrTemplateReferencesRequestDto { TemplateId = templateId, VendorCode, FromDate,
     ToDate }` and call `await _eutrTemplateReferencesService.AddAsync(dto, userEmail, ct)` inside a
     `try/catch` — this is the literal reuse of "Logic giống như Add": the SAME `AddAsync` the manual
     Apply Vendor dialog calls, which already runs `EutrTemplateReferencesRequestDtoValidator` and
     `HasOverlapAsync` before inserting. Because each row's `AddAsync` commits its own transaction
     before the next row is read, `HasOverlapAsync` on a later row automatically sees an earlier
     row's just-inserted mapping — satisfying the in-file overlap-sequencing requirement (FR-046's
     "earlier valid rows within the same file" clause) with **zero extra in-memory bookkeeping**,
     simply by virtue of processing rows in file order and reusing the existing service method.
     `ValidationException`/`InvalidOperationException` (overlap) → row error with `ex.Message`,
     `FailCount++`; any other exception → logged, generic `"Failed to import row"` error,
     `FailCount++`; otherwise `SuccessCount++`.
  5. If `TotalRows == 0` after the loop (header-only file), the result still returns with
     `TotalRows=0`/`SuccessCount=0`/`FailCount=0` — the controller's response message covers the
     "nothing to import" case (FR-047) without a special-cased error path.
- **`ComplianceSys.Application/Interfaces/Services/IEutrTemplateReferencesExportService.cs`** +
  **`.../Services/EutrTemplateReferencesExportService.cs`** NEW —
  `ExportToExcelAsync(long templateId, CancellationToken ct)`:
  1. `await _eutrTemplatesService.GetByIdWithDetailsAsync(templateId, ct)` — `null` → throw
     `KeyNotFoundException` (404; reuses the exact same not-found condition as Import).
  2. `await _eutrTemplateReferencesService.GetByTemplateIdAsync(templateId, ct)` (already exists,
     Update 13) for the mapping rows — **no D365 vendor-name resolution needed here**, since the
     4-column export format (FR-044) doesn't include `VendorName`, only `VendorCode`; this keeps
     Export from making any external D365 call at all.
  3. Build a workbook with headers `TemplateCode, VendorCode, FromDate, ToDate` (ClosedXML, same
     `sheet.Cell(...).Value = ...` + `AdjustToContents()` pattern as `EutrTemplatesExportService`);
     one row per mapping with `TemplateCode` = `template.Code` (repeated per row) and `FromDate`/
     `ToDate` written as real Excel date values with a `"yyyy-mm-dd"` number format (round-trips
     cleanly back through Import's date-cell read, avoiding locale-dependent string parsing). Zero
     mappings → header-only workbook (FR-044's "Export doubles as the template file" case).
- **`ComplianceSys.Api/Controllers/EutrTemplateReferencesController.cs`** MODIFY — add two actions,
  following the exact try/catch shape already used by `EutrTemplatesController.Import`/`.Export`:
  - `[Authorize(Policy = "EutrTemplates.Update")] [HttpPost("import/{templateId:long}")]` —
    validates `file` not null/empty and extension `.xlsx` (same check as
    `EutrTemplatesController.Import`) before calling the import service; catches
    `KeyNotFoundException` → 404, `InvalidOperationException` → 400, else 500. Returns
    `ApiResponse<ImportEutrTemplateReferencesResultDto>` with a summary message (`"Import finished:
    {SuccessCount} success, {FailCount} errors."`, same phrasing convention as the existing
    Templates import endpoint).
  - `[Authorize(Policy = "EutrTemplates.Read")] [HttpGet("export/{templateId:long}")]` — calls the
    export service, catches `KeyNotFoundException` → 404, returns the file as
    `eutr-template-references-{code}-{yyyyMMddHHmmss}.xlsx` (same `File(...)` content-type pattern
    as `EutrTemplatesController.Export`).
  - Policy choice reuses `EutrTemplates.Update` (Import mutates — same policy already gating
    Create/Update on this controller) and `EutrTemplates.Read` (Export is read-only — same policy
    already gating `GetByTemplateId`) — no new policy is introduced, matching how this controller
    already resolved Update 13's open "verify policy wiring" item by reusing `EutrTemplates.*`
    outright rather than seeding a new `EutrTemplateReferences.*` family.
- **`ComplianceSys.Application/DependencyInjection.cs`** MODIFY — register
  `IEutrTemplateReferencesImportService`/`EutrTemplateReferencesImportService` and
  `IEutrTemplateReferencesExportService`/`EutrTemplateReferencesExportService`, alongside the
  existing `EutrTemplateReferencesService` registration.

#### Frontend

- **`infrastructure/api/eutrTemplateReferencesApi.js`** MODIFY — add `importByTemplate(templateId,
  file)` (POST multipart `FormData` to `/eutr-template-references/import/${templateId}`, same
  `FormData`/`multipart/form-data` construction as `eutrTemplatesApi.js`'s `import`) and
  `exportByTemplate(templateId)` (GET `/eutr-template-references/export/${templateId}` with
  `responseType: 'blob'`, same as `eutrTemplatesApi.js`'s `export`).
- **`infrastructure/repositories/RestEutrTemplateReferencesRepository.js`** MODIFY — add
  `importByTemplate(templateId, file)`/`exportByTemplate(templateId)` passthrough methods, mirroring
  `RestEutrTemplatesRepository.js`'s `import`/`export` wrapper shape.
- **`application/usecases/eutr-template-references/ImportEutrTemplateReferencesUseCase.js`** NEW —
  mirrors `ImportEutrTemplatesUseCase.js` verbatim shape: `execute(templateId, file)` →
  `repository.importByTemplate(templateId, file)`.
- **`application/usecases/eutr-template-references/ExportEutrTemplateReferencesUseCase.js`** NEW —
  mirrors `ExportEutrTemplatesUseCase.js`'s blob-download-trigger logic (`execute(templateId)` calls
  the repository, then builds a temporary `<a download>` link from the blob response and clicks it);
  default filename when no `Content-Disposition` header is present:
  `eutr-template-references-${templateId}-${timestamp}.xlsx` (same `_resolveFileName` fallback
  pattern, just a different default prefix).
- **`presentation/pages/eutr-templates/components/ImportMappingResultDialog.jsx`** NEW — copies
  `ImportResultDialog.jsx`'s structure (Total/Success/Error `Chip`s + error table + Close button)
  verbatim, with the error table's columns changed to **Row, TemplateCode, VendorCode, Reason**
  (instead of Row/Name/Alert for/Reason) to match `ImportEutrTemplateReferencesRowError`'s shape.
- **`presentation/pages/eutr-templates/ApplyCustomerPage.jsx`** MODIFY — add **Import** and
  **Export** `Button`s to the existing header `Stack` (next to Back/Apply Vendor, per FR-043): a
  hidden `<input type="file" accept=".xlsx" hidden>` wired to a `ref` + `onChange` handler that (1)
  does a fast-fail client-side extension check (`.xlsx` only — server is still authoritative, same
  precedent as every other validated field in this feature), (2) calls
  `ImportEutrTemplateReferencesUseCase.execute(id, file)`, (3) opens the new
  `ImportMappingResultDialog` with the returned result, (4) calls the existing `fetchMappings()` to
  refresh the table regardless of partial success, and (5) resets the file `<input>`'s value so
  re-selecting the same filename re-fires `onChange`. The Export button's `onClick` simply calls
  `ExportEutrTemplateReferencesUseCase.execute(id)` (no dialog — direct browser download, same as
  the Templates-list Export precedent). New local state: `importing` (disables both buttons while an
  Import request is in flight, preventing double-submit) and `importResult`/`importDialogOpen`.

### Update 2026-07-15 (Update 15) — Copy `eutr_template_references` on Version-up + Clone Template

**Backend: one new cross-repository call (bug fix) + one new service method/endpoint reusing
existing insert pipelines. Frontend: one new dialog + use case, wired to the existing Clone icon
that Update 10 already added (disabled) to `TemplateListPage.jsx`.** No new DB table/column, no new
route, no new authorization policy family.

#### Bug fix: copy `eutr_template_references` on version-up (FR-049)

- **`ComplianceSys.Application/Interfaces/Repositories/IEutrTemplateReferencesRepository.cs`**
  MODIFY — add `Task CopyReferencesAsync(long sourceTemplateId, long newTemplateId, CancellationToken ct = default)`.
- **`ComplianceSys.Infrastructure/Repositories/EutrTemplateReferencesRepository.cs`** MODIFY —
  implement `CopyReferencesAsync` as a single set-based `INSERT INTO eutr_template_references
  (TemplateId, VendorCode, FromDate, ToDate, CreatedBy, CreatedDate, UpdatedBy, UpdatedDate) SELECT
  @newTemplateId, VendorCode, FromDate, ToDate, CreatedBy, CreatedDate, UpdatedBy, UpdatedDate FROM
  eutr_template_references WHERE TemplateId = @sourceTemplateId` — preserves original audit fields
  (this is a straight copy, not a new user action on each row). See research.md Section 30.
- **`ComplianceSys.Application/Services/EutrTemplatesService.cs`** MODIFY — constructor gains a new
  `IEutrTemplateReferencesRepository` dependency; `UpdateAsync`'s ≥24h branch calls
  `await _templateReferencesRepository.CopyReferencesAsync(id, newId, ct);` immediately after
  `BulkInsertDetailsAsync(newId, details, ct)`, inside the same transaction. The <24h branch is
  unchanged (TemplateId doesn't change, so no copy is needed).
- **`ComplianceSys.Application/DependencyInjection.cs`** — no change needed;
  `IEutrTemplateReferencesRepository` is already registered (Update 13); `EutrTemplatesService`'s
  constructor injection is resolved automatically by the existing DI container wiring.

#### New: Clone Template (FR-050 to FR-054)

- **`ComplianceSys.Application/Dtos/Request/CloneEutrTemplatesRequestDto.cs`** NEW — `Name` (string),
  `AlertFor` (long?).
- **`ComplianceSys.Application/Validators/CloneEutrTemplatesRequestDtoValidator.cs`** NEW — `Name`
  NotEmpty; `AlertFor` must be a positive value (same two rules `EutrTemplatesRequestDtoValidator`
  already enforces, extracted as a small standalone validator since the Clone DTO has no other
  fields to validate).
- **`ComplianceSys.Application/Services/EutrTemplatesService.cs`** MODIFY — add
  `CloneAsync(long sourceId, CloneEutrTemplatesRequestDto dto, string userEmail, CancellationToken ct)`:
  1. `GetByIdWithDetailsAsync(sourceId, ct)` → `KeyNotFoundException` if not found (same 404
     convention as every other `templateId`-scoped lookup in this feature).
  2. Generate the new Code via a small shared private helper `GenerateNextCodeAsync` (extracted from
     `AddAsync`'s existing `GetMaxCodeNumberAsync` + zero-pad logic, now called from both places — no
     format-string duplication).
  3. Insert the new header row: `Name`/`AlertFor` from `dto`, `IsDefault = 0` (always — FR-053),
     `VersionId = 1`, `IsDeleted = 0`, `IsHide = 0`, `CreatedBy`/`CreatedDate` = current user/now.
  4. Re-index the source's DB-Id-based detail tree into the same 1-based sequential-`ParentId`
     convention the frontend's `flattenForSave()` already produces (source rows ordered by `Id`
     ascending — always parent-before-child), then pass the result straight into the EXISTING
     `BuildDetailEntitiesAsync` + `BulkInsertDetailsAsync(newId, details, ct)` pipeline — no new
     tree-insert SQL (see research.md Section 31 for the full rationale).
  5. `await _templateReferencesRepository.CopyReferencesAsync(sourceId, newId, ct);` (same method as
     the version-up fix above — second call site, no duplicated copy logic).
  6. Single transaction wraps steps 3-5.
- **`ComplianceSys.Api/Controllers/EutrTemplatesController.cs`** MODIFY — add
  `[Authorize(Policy = "EutrTemplates.Create")] [HttpPost("{id:long}/clone")]` action, same
  try/catch shape as the existing Create action (`KeyNotFoundException` → 404,
  `ValidationException` → 400), returns `{ id, code, versionId }` (same response shape as Create).

#### Frontend

- **`presentation/pages/eutr-templates/components/CloneTemplateDialog.jsx`** NEW — MUI `Dialog`
  showing the source template's Code/Name (read-only), a required **New template name** `TextField`,
  a required **Alert for** `Autocomplete` (reuses the exact same `GetAllGroupEmailUseCase`-backed,
  `groupType===2 && isAddition===false`-filtered combobox pattern already implemented in
  `CreateTemplateDialog.jsx` — Principle II), and Cancel/Clone buttons. Clicking Clone (with valid
  input) opens the existing `ConfirmDialog` component with a warning message before actually calling
  the use case — reusing `ConfirmDialog` exactly as Delete/Bulk-Delete already do, not a new
  confirmation component.
- **`application/usecases/eutr-templates/CloneEutrTemplatesUseCase.js`** NEW — mirrors
  `CreateEutrTemplatesUseCase.js`'s shape: `execute(sourceId, { name, alertFor })` → POST
  `eutr-templates/{sourceId}/clone`.
- **`infrastructure/api/eutrTemplatesApi.js`** MODIFY — add `clone(id, payload)` (POST
  `eutr-templates/${id}/clone`), mirroring the existing `create`/`update` method shapes.
- **`infrastructure/repositories/RestEutrTemplatesRepository.js`** MODIFY — add `clone(id, payload)`
  passthrough, mirroring `create`/`update`.
- **`presentation/pages/eutr-templates/TemplateListPage.jsx`** MODIFY — the Clone `IconButton`
  (currently `disabled`, per Update 10/FR-026) becomes active: `onClick={() =>
  setCloneDialogTemplate(row)}` opening `CloneTemplateDialog` for that row; on successful Clone, the
  dialog closes and the existing `fetchData()`/list-refresh call (same one `CreateTemplateDialog`
  already triggers) re-runs so the new template appears. Apply-to-Customer icon is unaffected by
  this update.

### Update 2026-07-21 (Update 16) — Status Draft/Approved Replaces 24h Versioning

**Backend: simplifies `EutrTemplatesService.UpdateAsync` (deletes the age-based branch entirely)
and adds two small new endpoints (`Approve`, `RequestChange`) that reuse the exact copy pipeline
Update 15 already built for Clone.** One new column (`Status`), one new migration. Frontend: one
new shared enum in `helpers.js`, two new toolbar buttons on `TemplateListPage.jsx` (reusing the
per-row checkbox selection from Update 10's bulk-delete), and a read-only gate on
`TemplateBuilderPage.jsx`.

#### Status column + defaults (FR-055, FR-056)

- **`ComplianceSys.Domain/Entities/EutrTemplates.cs`** MODIFY — add `public string Status { get; set; }`.
- **`ComplianceSys.Application/Dtos/Response/EutrTemplatesResponseDto.cs`** MODIFY — add `Status`
  (inherited from the entity automatically; listed for traceability).
- **`ComplianceSys.Application/Services/EutrTemplatesService.cs`** MODIFY — `AddAsync` and
  `CloneAsync` both set `Status = 0 (Draft)` unconditionally on the new row (ignoring any client-sent
  value — Status is server-controlled, never accepted from `EutrTemplatesRequestDto`/
  `CloneEutrTemplatesRequestDto`).
- **`ComplianceSys.Infrastructure/Sqls/Migration/13_add_status_to_eutr_templates.sql`** NEW —
  `ALTER TABLE eutr_templates ADD COLUMN Status TINYINT NULL DEFAULT 0` (the `DEFAULT` clause
  backfills all existing rows to `0` automatically — no separate `UPDATE` statement needed). Numbered
  13, not 12 (12 was already taken by Update 13's `12_drop_eutr_templates_vendorcode.sql`). **Column
  type revised from the original `VARCHAR(20)` plan to `TINYINT` (0=Draft, 1=Approved) during
  `/speckit-implement`** — the live dev DB already had an unused `Status TINYINT` column with no
  matching migration/code/design-doc anywhere (see research.md §33 for the full discovery and the
  user's decision to keep the existing column's type). This migration only applies to environments
  that don't already have the column. **`ComplianceSys.Infrastructure/Sqls/Tables/eutr_db.sql`**
  MODIFY — add the same `TINYINT NULL DEFAULT 0` column to the fresh-install `CREATE TABLE
  eutr_templates` (same dual-file convention as every prior column addition in this feature, e.g.
  Update 7's `AlertFor` migration).
- **`compliance-client/src/utils/helpers.js`** MODIFY — add
  `export const TEMPLATE_STATUS = Object.freeze({ DRAFT: 0, APPROVED: 1 });` (FR-055), following the
  exact `Object.freeze` shape already used for `groupEmailType`/`ObjectType` in this same file
  (Principle II), **plus** `export const TEMPLATE_STATUS_LABELS = { 0: 'Draft', 1: 'Approved' };`
  for the Chip display text — added during `/speckit-implement` once `Status` turned out to be
  numeric (`TINYINT`, matching a pre-existing DB column — see research.md §33), the exact same
  value/label-map split already used for `REQUIREMENT_TYPES`/`REQUIREMENT_LABELS` and
  `TAKE_FROM_OPTIONS`/`TAKE_FROM_LABELS`.
- **`compliance-client/src/domain/entities/EutrTemplates.js`** MODIFY — add `status` to the
  constructor-destructuring list (same pattern as the existing `versionId`/`isDefault` fields).

#### Versioning logic replaced (FR-057; supersedes the Update 4 24h branch)

- **`ComplianceSys.Application/Services/EutrTemplatesService.cs`** MODIFY — `UpdateAsync` drops the
  `(DateTime.UtcNow - existing.CreatedDate) >= TimeSpan.FromHours(24)` branch entirely (both the
  ≥24h new-row-creation path and its `BuildDetailEntitiesAsync`/`BulkInsertDetailsAsync` call, and
  the `CopyReferencesAsync` call Update 15 added to that branch — all now dead code, deleted, not
  left commented out). The method becomes: (1) load `existing`; (2) if
  `existing.Status == (byte)TemplateStatusEnum.Approved` (`TemplateStatusEnum : byte { Draft = 0,
  Approved = 1 }` — a small enum in `ComplianceSys.Application.Constants`, mirroring the frontend's
  numeric `TEMPLATE_STATUS`/`TEMPLATE_STATUS_LABELS` on the backend side, avoiding magic-number
  literals scattered across the service — see research.md §33 for why this is numeric rather than
  the originally-planned string), throw a `ValidationException("Template is Approved — use Request
  change before
  editing.")` (backend-enforced gate, not just a frontend disabled button, per FR-061's "system MUST
  reject" wording); (3) otherwise, run the **same in-place update** the old <24h branch already
  implemented verbatim (generic repository `UpdateAsync` on the existing row + `ReplaceDetailsAsync`
  for the step tree) — this becomes the ONLY path, unconditional. No new row is ever created by
  `UpdateAsync` anymore.
- **`ComplianceSys.Application/Interfaces/Repositories/IEutrTemplatesRepository.cs`** /
  **`.../EutrTemplatesRepository.cs`** MODIFY — extract the detail-tree-copy logic Update 15's
  `CloneAsync` already built (re-index source rows into the sequential-ParentId convention, feed
  `BuildDetailEntitiesAsync` + `BulkInsertDetailsAsync(newId, ...)`) into one shared method,
  `CopyDetailTreeAsync(sourceTemplateId, newTemplateId, ct)`, called by both `CloneAsync` (unchanged
  behavior) and the new `RequestChangeAsync` below (Principle II — one copy implementation, two call
  sites, instead of duplicating the re-index logic a second time).

#### New: Approve / Request change (FR-058 to FR-061)

- **`ComplianceSys.Application/Services/EutrTemplatesService.cs`** MODIFY — add:
  - `ApproveAsync(long id, string userEmail, ct)`: load `existing`; if `Status != Draft`, throw
    `ValidationException("Only a Draft template can be Approved.")`; else update only `Status =
    Approved` (+ `UpdatedBy`/`UpdatedDate`) on the SAME row via a new small repository method
    `SetStatusAsync(id, status, userEmail, ct)` — no VersionId change, no new row, no detail/reference
    copy (FR-059).
  - `RequestChangeAsync(long id, string userEmail, ct)`: load `existing`; if `Status != Approved`,
    throw `ValidationException("Only an Approved template can request change.")`; else, in one
    transaction: (1) insert a new `eutr_templates` row with the SAME `Code`, `Name`, `AlertFor`,
    `IsDefault` as `existing` (copied verbatim — Request change takes no payload, it is a pure
    state-transition action), `VersionId = existing.VersionId + 1`, `Status = Draft`, `IsHide = 0`,
    `IsDeleted = 0`; (2) `CopyDetailTreeAsync(existing.Id, newId, ct)` (step tree, reused from
    Clone); (3) `await _templateReferencesRepository.CopyReferencesAsync(existing.Id, newId, ct)`
    (vendor mappings, the exact same method Update 15 already added); (4) `SetStatusAsync`-style
    update on the OLD row: `IsHide = 1` (kept, not deleted — immutable historical Approved snapshot,
    per FR-060). Returns the new row's response DTO.
- **`ComplianceSys.Application/Interfaces/Repositories/IEutrTemplatesRepository.cs`** /
  **`.../EutrTemplatesRepository.cs`** MODIFY — add `SetStatusAsync(long id, string status, string
  userEmail, CancellationToken ct)` — a single-column `UPDATE eutr_templates SET Status = @status,
  UpdatedBy = @userEmail, UpdatedDate = @now WHERE Id = @id` (also reused for the old-row `IsHide=1`
  flip in `RequestChangeAsync`, since that's the same one-column-update shape — the method takes an
  arbitrary column/value pair via two small dedicated calls rather than a generic key/value updater,
  keeping the repository's existing explicit-method style).
- **`ComplianceSys.Api/Controllers/EutrTemplatesController.cs`** MODIFY — add
  `[Authorize(Policy = "EutrTemplates.Update")] [HttpPost("{id:long}/approve")]` and
  `[Authorize(Policy = "EutrTemplates.Update")] [HttpPost("{id:long}/request-change")]`, both no-body
  actions following the exact try/catch shape as the existing `{id}/clone` action
  (`KeyNotFoundException` → 404, `ValidationException` → 400), returning the updated/new
  `EutrTemplatesResponseDto`.

#### Frontend: toolbar actions + read-only gate (FR-058, FR-059, FR-060, FR-061, FR-062)

- **`infrastructure/api/eutrTemplatesApi.js`** / **`infrastructure/repositories/RestEutrTemplatesRepository.js`**
  MODIFY — add `approve(id)` (POST `eutr-templates/${id}/approve`) and `requestChange(id)` (POST
  `eutr-templates/${id}/request-change`), mirroring the existing `clone(id, payload)` shape (no
  payload needed for either).
- **`application/usecases/eutr-templates/ApproveEutrTemplatesUseCase.js`** NEW and
  **`.../RequestChangeEutrTemplatesUseCase.js`** NEW — mirror `CloneEutrTemplatesUseCase.js`'s
  one-line `execute(id) → repository.approve(id)` / `.requestChange(id)` shape.
- **`presentation/pages/eutr-templates/TemplateListPage.jsx`** MODIFY — add a Status `Chip` per row
  (color-mapped locally, e.g. `{ Draft: 'warning', Approved: 'success' }`, same `Chip` component
  already used for the Version/Default chips — FR-062); add two toolbar `Button`s, **Approve** and
  **Request change**, next to the existing **Create Template** button, reusing the per-row checkbox
  `selectedIds` state Update 10 already added for bulk-delete (FR-058): each button is `disabled`
  unless `selectedIds.length === 1` AND the corresponding row's `status` matches (`Draft` for
  Approve, `Approved` for Request change). Clicking either button opens the existing `ConfirmDialog`
  component with a Yes/No prompt (same component already used for Delete/Bulk-Delete/Clone's warning
  step — Principle II, no new confirmation UI); confirming calls
  `ApproveEutrTemplatesUseCase`/`RequestChangeEutrTemplatesUseCase.execute(selectedId)`, then clears
  the selection, re-runs the existing `fetchData()` list refresh, and shows a `CustomSnackbar`
  success/error message (same pattern as every other mutating action on this page).
- **`presentation/pages/eutr-templates/TemplateBuilderPage.jsx`** MODIFY — read `template.status`
  from the already-loaded template; when `status === TEMPLATE_STATUS.APPROVED`, render a warning
  `Alert` banner (same component/placement pattern the reference mockup already uses for its
  `isReadOnly` case) and set `disabled` on: every header field (Name `TextField`, Alert for
  `Autocomplete`, Set-as-default `Checkbox`), the Save button, the Root Group/Child Step toolbar
  buttons, and each step row's Edit/Delete icon buttons (FR-061). When `status === DRAFT`, the page
  behaves exactly as before this update — no change to the Draft code path.

See research.md Section 32 for the full rationale (why Request change reuses Clone's copy pipeline
instead of the old UpdateAsync branch) and Section 33 for the Status-as-string-column decision.

### Update 2026-07-22 (Update 17) — Drag-and-Drop Step Reorder, Additive to Move Up/Down

**Frontend-only, no backend/API change.** Adds real drag-and-drop reordering to
`TemplateBuilderPage.jsx`'s step tree using the already-installed (but until now unused anywhere in
this codebase) `@dnd-kit/core` + `@dnd-kit/sortable` packages, additive to the existing Move
Up/Move Down toolbar buttons — both call the same `reorderSiblings` function in `useStepTree.js`.

**Pre-write code audit correction**: this plan's own "Key Differences from Reference Features" table
and data-model.md previously stated that `StepTree.jsx` already had a working `@dnd-kit`
drag-and-drop pattern that `TemplateBuilderPage.jsx` (Update 10) chose not to adopt. A repo-wide
grep for `@dnd-kit` across `compliance-client/src` returns zero matches — this was never actually
implemented anywhere; the claim was aspirational, carried over from the original spec's FR-006
wording. Both documents are corrected below and in data-model.md's EutrTemplateDetail business
rules. See research.md Section 34 for the full audit and rationale.

#### Frontend: drag-and-drop on the step tree (FR-064 to FR-067)

- **`presentation/pages/eutr-templates/TemplateBuilderPage.jsx`** MODIFY — wrap `<SimpleTreeView>`
  in a single `<DndContext onDragEnd={handleDragEnd} sensors={...}>`; `renderTree()` wraps each
  recursion level's `nodes.map(...)` in `<SortableContext items={nodes.map(n => n._id)}
  strategy={verticalListSortingStrategy}>` — one context per sibling group (same `ParentId`), not
  one context for the whole tree, so a drop landing outside the dragged item's own group cannot
  produce a same-group `over` match by construction (research.md §34). Each `TreeItem`'s label
  gains a small `DragIndicatorIcon` drag handle wired to `useSortable({ id: node._id, disabled:
  isReadOnly })` — `listeners`/`attributes` spread only onto that handle (not the whole row), so
  the existing click-to-select and the tree's expand/collapse chevron are unaffected;
  `transform`/`transition` applied via inline style to a thin wrapper around the label content.
  `handleDragEnd` resolves `active.id`/`over?.id` against `stepItems`; if `over` is missing or the
  two nodes' `parentId` differ, it is a no-op (FR-065 — no reparenting); otherwise it computes
  `fromIndex`/`toIndex` within that `parentId`'s siblings (same computation `moveNode()` already
  does) and calls the existing `reorderSiblings(parentId, fromIndex, toIndex)` (FR-066) — zero new
  tree-mutation logic. `disabled: isReadOnly` on every `useSortable()` call covers FR-067 (disabled
  when Status=Approved) via dnd-kit's own per-item flag, matching Move Up/Down's existing disabled
  state.
- **`presentation/pages/eutr-templates/hooks/useStepTree.js`** NO CHANGE — `reorderSiblings` is
  already generic over the caller's gesture (button click or drag drop); it takes `parentId`,
  `fromIndex`, `toIndex` and has no knowledge of how those were computed.
- **No new dependency** — `@dnd-kit/core`/`@dnd-kit/sortable`/`@dnd-kit/utilities` are already in
  `package.json` (installed since this feature's original plan, never previously imported).
- **No backend/contract change** — see contracts/api-endpoints.md's Update 17 note; the reordered
  tree is submitted through the exact same Update Template request body Move Up/Down already
  produces.

#### Documentation corrections (this update)

- **plan.md** "Key Differences from Reference Features" table: the "Step reordering on Edit (Update
  10)" row's reference-column claim (`@dnd-kit` drag-and-drop already existing via "StepTree.jsx
  pattern") is corrected — verified never implemented; a new row is added for Update 17's actual
  addition.
- **data-model.md** `EutrTemplateDetail.DisplayOrder` business rule bullet corrected to remove the
  same false claim and describe Update 17 accurately.

See research.md Section 34 for the full rationale, the audit evidence, and the alternatives
considered (in particular, why per-sibling-group `SortableContext`s make cross-parent reparenting
structurally awkward instead of requiring extra guard code).

### Update 2026-07-23 (Update 18) — Editable "Set as Default" While Approved

**Backend: one new single-purpose endpoint that bypasses the Approved edit gate Update 16 added to
`UpdateAsync`, reusing the existing global-default-clearing logic.** Frontend: the Set-as-default
checkbox on `TemplateBuilderPage.jsx` gets a second, Approved-only code path (confirm-then-call, not
part of the disabled header-field group), gated behind a `ConfirmDialog` (the same component used by
Approve/Request change).

**One scope question asked back to the user before writing this update (answered via
AskUserQuestion)**: since the Save button is hidden/disabled whenever Status=Approved (FR-061), how
should a Set-as-default toggle actually persist while Approved? → **answered: auto-save with a
Yes/No `ConfirmDialog`** — toggling shows a confirmation; Yes calls a dedicated update immediately
(independent of Save); No reverts the checkbox with no request sent.

#### Backend: dedicated `SetDefaultAsync` (FR-068)

- **`ComplianceSys.Application/Services/EutrTemplatesService.cs`** MODIFY — add `SetDefaultAsync(long
  id, bool isDefault, string userEmail, ct)`: loads `existing` (no `Status` check — this is the one
  path deliberately NOT gated by the Approved-rejects-edits rule `UpdateAsync` enforces); if
  `isDefault == true`, calls the existing `ClearGlobalDefaultAsync(id, ct)` (Update 13) first, then
  updates only `IsDefault` (+ `UpdatedBy`/`UpdatedDate`) on this row via a new repository method; if
  `isDefault == false`, updates only `IsDefault = 0` directly (no need to clear anything else).
  Returns the updated response DTO. Deliberately does not touch `Name`/`AlertFor`/`Status`/
  `VersionId`/`eutr_template_details`/`eutr_template_references`.
- **`ComplianceSys.Application/Interfaces/Repositories/IEutrTemplatesRepository.cs`** /
  **`.../EutrTemplatesRepository.cs`** MODIFY — add `SetIsDefaultAsync(long id, bool isDefault, string
  userEmail, CancellationToken ct)`, a single-column `UPDATE eutr_templates SET IsDefault = @isDefault,
  UpdatedBy = @userEmail, UpdatedDate = @now WHERE Id = @id` — same one-column-update shape as the
  existing `SetStatusAsync` (Update 16), not a generic key/value updater.
- **`ComplianceSys.Application/Dtos/Request/SetDefaultEutrTemplatesRequestDto.cs`** NEW — single
  field `bool IsDefault`.
- **`ComplianceSys.Api/Controllers/EutrTemplatesController.cs`** MODIFY — add
  `[Authorize(Policy = "EutrTemplates.Update")] [HttpPost("{id:long}/set-default")]
  SetDefault(long id, [FromBody] SetDefaultEutrTemplatesRequestDto dto)`, same try/catch shape
  (`KeyNotFoundException` → 404) as every other `{id}`-scoped action on this controller. No
  `ValidationException`/400 path here — unlike `PUT {id}` and unlike Approve/Request change, this
  endpoint has no Status precondition to reject on (that is the entire point of FR-068).

#### Frontend: Approved-only confirm-then-persist toggle (FR-068)

- **`infrastructure/api/eutrTemplatesApi.js`** / **`infrastructure/repositories/RestEutrTemplatesRepository.js`**
  MODIFY — add `setDefault(id, isDefault)` (POST `eutr-templates/${id}/set-default`, body
  `{ isDefault }`), mirroring the existing `approve(id)`/`requestChange(id)` shape.
- **`application/usecases/eutr-templates/SetDefaultEutrTemplatesUseCase.js`** NEW — mirrors
  `ApproveEutrTemplatesUseCase.js`'s one-line `execute(id, isDefault) →
  repository.setDefault(id, isDefault)` shape.
- **`presentation/pages/eutr-templates/TemplateBuilderPage.jsx`** MODIFY — the Set-as-default
  `Checkbox`'s `disabled` prop no longer follows the blanket `isReadOnly`/`status === APPROVED` flag
  the rest of the header fields use (FR-061); it stays enabled at all times. Its `onChange` branches
  on `status`: when `Draft`, unchanged existing behavior (flips local `isDefault` state, part of the
  dirty-tracked header, persisted only on the next Save); when `Approved`, the handler does NOT flip
  local state directly — it opens the existing `ConfirmDialog` (Yes/No, same component Approve/
  Request change already use) with the intended new value; **Yes** calls
  `SetDefaultEutrTemplatesUseCase.execute(id, intendedValue)`, and on success sets local `isDefault`
  to the confirmed value and shows a `CustomSnackbar` success message (on failure, leaves the
  checkbox at its prior value and shows an error snackbar); **No** just closes the dialog — the
  checkbox was never optimistically flipped, so nothing needs to be reverted.

See research.md Section 35 for the full rationale and alternatives considered.

## Technical Context

**Language/Version**: .NET 8 (backend), JavaScript/React 18 + Vite 7 (frontend)

**Primary Dependencies**:

- Backend: Dapper + Dapper.SimpleCRUD (MySQL dialect), FluentValidation, AutoMapper, ClosedXML, Res.Shared.Dapper (IRepository, BaseService, PagedRequest), Res.Shared.ExternalServices (IDynamicService, DynamicsParameterManager), Res.Shared.AuthN/AuthZ
- Frontend: MUI v7 (@mui/material, @mui/x-data-grid, @mui/x-tree-view), @dnd-kit/core + @dnd-kit/sortable, axios, React Router v6

**Storage**: MySQL (via Dapper, `SimpleCRUD.Dialect.MySQL`). Tables: `eutr_templates`, `eutr_template_details` (already defined in `Infrastructure/Sqls/Tables/eutr_db.sql`)

**Testing**: Unit tests (`ComplianceSysApi.UnitTests`)

**Target Platform**: Web application (SPA + REST API), deployed internally

**Project Type**: Monorepo — web service (`compliance-sys-api`) + SPA (`compliance-client`)

**Performance Goals**: Standard CRUD performance. Server-side pagination/filtering/sorting for grid.

**Constraints**: Clean Architecture layers, backend-driven routing, reference-pattern reuse from existing EUTR features

**Scale/Scope**: Internal compliance tool. Expected: hundreds of templates, tens of steps per template.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle                                      | Status | Notes                                                                                                                                                                         |
| ---------------------------------------------- | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| I. Layered Clean Architecture                  | PASS   | Backend: Api → Application → Domain + Infrastructure. Frontend: domain → infrastructure → application → presentation. All files follow layer boundaries.                 |
| II. Reference-Pattern Reuse                    | PASS   | Clones from `eutr-masters` (backend CRUD + import/export) and `eutr-steps` (frontend layered pattern). Vendor endpoint reuses `data-area` pattern in DynController. Add/Edit full page follows `compliance-master/:id` route pattern. |
| III. Reuse Existing Backend                    | PASS   | Backend CRUD already built. Vendor lookup reuses the existing generic `POST /api/dynamics/reference` endpoint (`refType=13`, already mapped to VendorsV3) — no new backend endpoint required for vendor data as of Update 5. Frontend: fix ParentId mapping, add Edit step inline, restructure layout to 2 columns, and (Update 5) swap vendor combobox back to the generic reference component. |
| IV. Vietnamese Comments; Localizable UI Labels | PASS   | Code comments in Vietnamese. UI text in English per FR-017 (spec explicitly requires it).                                                                                     |
| V. Routing & Menu Registration                 | PASS   | Route registered in`RouteResolver.jsx` codeToComponent. Backend menu entry seeded with code + url + permissions. Add/Edit sub-routes in MainRoutes.jsx.                     |

**Post-design re-check (2026-07-03 update 3)**: All principles still PASS. Vendor endpoint `$select` addition is a minor change within the existing `DynController.Vendors()` method (Principle III — reuse existing backend, minimal modification). Appending `$select` to URL after `BuildUrl()` stays within the controller layer (Principle I — thin controller logic). No new dependencies or layer violations.

**Post-design re-check (2026-07-03 update 4)**: All principles still PASS. Conditional versioning stays inside `EutrTemplatesService.UpdateAsync` (Application layer — Principle I); one new repository method (`ReplaceDetailsAsync`) follows the existing `BulkInsertDetailsAsync` pattern (Principle II). Save button relocation, column ratio change, and Back dirty-check are frontend-only, presentation-layer changes reusing the existing `ConfirmDialog` component (Principle II — reference-pattern reuse) instead of introducing a new dialog. No new dependencies or layer violations.

**Post-design re-check (2026-07-06 update 5)**: All principles still PASS. Reverting the vendor
combobox to the generic reference API is a pure frontend, presentation-layer change that reuses
the existing `ReferenceObjectAutocomplete`/`useReferenceObjects` components (Principle II —
reference-pattern reuse) instead of the feature-specific `useVendors` hook. No backend change is
needed (Principle III — the generic reference endpoint and its VendorsV3 mapping already exist).
No new dependencies or layer violations.

**Post-design re-check (2026-07-06 update 6)**: All principles still PASS. The step-resolution
logic stays inside `EutrTemplatesService`/`EutrTemplatesRepository` (Application/Infrastructure
layers — Principle I); `ResolveOrCreateStepsByNameAsync` follows the same
query-then-insert-if-missing shape already used elsewhere in the repository (Principle II).
Auto-created steps are written directly to `eutr_steps` via the existing table/entity — no new
service dependency on `EutrStepService` is introduced, avoiding a cross-feature service coupling
(feature 001-eutr-steps' own CRUD flow and this template-save flow both write to the same table
independently). Frontend change (`freeSolo` Autocomplete) reuses the pattern already present for
the `Alert for` field. No new dependencies or layer violations.

**Post-design re-check (2026-07-07 update 7)**: All principles still PASS. The `AlertFor` name
resolution is added as a `LEFT JOIN` inside the existing `EutrTemplatesRepository` query methods
(Infrastructure layer — Principle I; no new service). The frontend combobox reuses
`GetAllGroupEmailUseCase`/`repositories.groupEmail`, already established by
`ComplianceMasterForm`/`MasterDefaultForm` (Principle II — reference-pattern reuse) — zero new
frontend files. `GET /api/group-email` already exists and needs no backend change (Principle III —
reuse existing backend), though it sits under a different policy (`GroupEmail.ReadAll`) than
`EutrTemplates.*`; this is flagged as an access-control dependency to verify during
`/speckit-implement`, not a layering or architecture concern. No new dependencies or layer
violations.

**Post-design re-check (2026-07-07 update 8)**: All principles still PASS. Moving
`REQUIREMENT_TYPES`/`TAKE_FROM_OPTIONS`/`REQUIREMENT_LABELS`/`TAKE_FROM_LABELS` into the existing
shared `compliance-client/src/utils/helpers.js` (already the established home for cross-feature
frontend constants such as `ObjectType`/`groupEmailType` — Principle II, reference-pattern reuse)
is a presentation-layer-internal move with no new files, no backend change (Principle III), and no
layer boundary crossed (Principle I — `utils/` is a shared cross-cutting module already consumed
across features, not feature-specific). No new dependencies or layer violations.

**Post-design re-check (2026-07-13 update 9)**: All principles still PASS. `CreateTemplateDialog.jsx`
is a presentation-layer component that calls the existing `CreateEutrTemplatesUseCase` unchanged
(Principle I — layering respected; Principle III — no backend change, the endpoint already accepts
a minimal payload). The `Dialog` pattern it uses already exists in this same folder
(`ImportResultDialog.jsx`) and elsewhere in the codebase (`ConfirmDialog`), so this is
reference-pattern reuse (Principle II), not a new UI pattern. Renaming `index.jsx` →
`TemplateListPage.jsx` and simplifying `EutrTemplatesAddEdit.jsx` to Edit-only are presentation-layer
internal changes; routing still goes through `RouteResolver.jsx`/`MainRoutes.jsx` (Principle V —
routing/menu registration maintained, menu code `eutr-templates` unchanged). No new dependencies or
layer violations.

**Post-design re-check (2026-07-13 update 10/11)**: All principles still PASS.
`TemplateListPage.jsx`/`TemplateBuilderPage.jsx` swap mock data for the already-existing
use cases/hooks from `TemplateListPageOld.jsx`/`EutrTemplatesAddEdit.jsx`
(Principle III — reuse existing backend/frontend logic, verified working; Principle II —
reference-pattern reuse, specifically reusing `useStepTree`/`StepFormRow.jsx`/`utils/helpers.js`
constants instead of re-implementing tree state or requirement/take-from options a third time).
The two backend additions (`Keyword` filter special-case, `StepsCount` subquery) are both
minimal, additive changes inside the existing `EutrTemplatesRepository` query method — no new
service, controller, or DTO beyond one new response field (Principle I — stays in the
Infrastructure layer, mirrors the existing `AlertFor → g.Name` special-case from Update 7).
`EutrTemplatesAddEdit.jsx` and the mock fixture files become unreferenced but are left in place
rather than deleted, per the same conservative precedent set in Update 5 (Principle III — avoid
unverified removals). Routing is unchanged — `/eutr/templates/edit/:id` already pointed at
`TemplateBuilderPage.jsx` before this update (Principle V — routing/menu registration already
satisfied, no new route needed).

**Post-design re-check (2026-07-13 update 12)**: All principles still PASS. `BulkAddStepsDialog.jsx`
is a new presentation-layer component (Principle I — stays in `presentation/`, no layer crossed) that
reuses the existing `GetEutrStepsUseCase` data and the same free-solo entry pattern already
established by `StepFormRow.jsx`/the Alert-for field (Principle II — reference-pattern reuse, not a
new interaction paradigm). `useStepTree.js`'s new `addSteps` is additive alongside the unchanged
`addStep`, following the same single-mutation-per-call shape already set by `removeMultiSteps`
(Principle II). No backend/DTO/contract change — the Update endpoint's `details[]` payload shape is
unaffected by how many rows are authored per dialog interaction (Principle III — reuse existing
backend, verified only). No new dependency — the checkbox table uses `@mui/material` components
already used throughout this feature. No routing change (Principle V — unaffected).

**Post-design re-check (2026-07-13 update 13)**: All principles still PASS.
`EutrTemplateReferences*` (entity/DTOs/repository/service/controller/validator) is a brand-new
CRUD stack modeled directly on the existing `EutrTemplates*` stack (Principle II — reference-pattern
reuse; `compl_template_reference` was checked and rejected as a reference since it has no C# code,
only orphaned SQL). Layering is respected end-to-end: `EutrTemplateReferencesController` stays thin
and delegates to `IEutrTemplateReferencesService`, which owns the overlap-validation business rule
(FR-036) — controller/repository do not contain business logic (Principle I). VendorCode removal
deletes code across all four backend layers plus the frontend, but each deletion stays within its
own existing layer boundary (no new cross-layer coupling introduced by the removal). The Vendor
combobox on the new `ApplyCustomerPage.jsx` reuses the exact same generic reference API
(`POST /api/dynamics/reference`, `refType=13`) already established for this feature (Principle III —
reuse existing backend, no new D365 endpoint). New route `/eutr/templates/apply/:id` registered in
`MainRoutes.jsx` following the identical pattern as `/eutr/templates/edit/:id` (Principle V —
routing/menu registration maintained); the exact authorization-policy/menu-permission wiring for the
new controller is flagged as a verification item for `/speckit-implement` (same treatment as the
`GroupEmail.ReadAll` cross-policy dependency flagged in Update 7 — not a layering violation, an
implementation-time confirmation). The Steps-count item introduces no code change at all pending
verification, so it cannot violate any principle. No new dependencies.

**Post-design re-check (2026-07-14 update 14)**: All principles still PASS.
`EutrTemplateReferencesImportService`/`EutrTemplateReferencesExportService` are new Application-layer
services modeled directly on `EutrTemplatesImportService`/`EutrTemplatesExportService` — same
ClosedXML usage, same row-loop/error-accumulation shape, same controller-level try/catch mapping
(Principle II — reference-pattern reuse; Principle I — layering, no business logic leaks into the
new controller actions). Row-level "Add" reuses the EXISTING `EutrTemplateReferencesService.AddAsync`
(validator + `HasOverlapAsync` already implemented, Update 13) instead of duplicating that logic in
the import path (Principle III — reuse existing backend, verified in code, not just in the spec).
No new DB table/column — Import/Export operate on the same `eutr_template_references` table via the
same service. No new authorization policy family — the two new controller actions reuse
`EutrTemplates.Update`/`EutrTemplates.Read`, the exact policies this controller's other actions
already use in the shipped code (resolving, rather than reopening, Update 13's "verify policy
wiring" item). No new route — Import/Export are buttons on the already-routed
`/eutr/templates/apply/:id` page (Principle V — routing/menu registration unaffected, no new
route/menu entry needed). Frontend additions (`ImportMappingResultDialog.jsx`, the two new use
cases) are pattern-for-pattern copies of the already-working Templates-level Import/Export UI
(Principle II). No new dependencies — reuses ClosedXML (backend) and the existing blob-download/
`FormData` upload conventions (frontend).

**Post-design re-check (2026-07-15 update 15)**: All principles still PASS.
`EutrTemplatesService.CloneAsync` stays in the Application layer and reuses the existing
`BuildDetailEntitiesAsync`/`BulkInsertDetailsAsync` pipeline instead of writing a second, parallel
tree-insert implementation (Principle I — layering; Principle II — reference-pattern reuse, the same
insert/ParentId-remap logic `AddAsync`/`UpdateAsync` already rely on). The new
`CopyReferencesAsync` repository method is a single set-based SQL statement added to the existing
`EutrTemplateReferencesRepository` (Update 13) — no new table/repository stack. `EutrTemplatesService`
gaining a constructor dependency on `IEutrTemplateReferencesRepository` is a same-layer,
Application-to-Infrastructure-interface dependency, matching how this service already depends on its
own `IEutrTemplatesRepository` (no new layer crossed). The new Clone endpoint reuses the
`EutrTemplates.Create` policy (Principle V is unaffected — no new route/menu entry; Clone is a row
action on the already-routed `TemplateListPage.jsx`, same pattern as Apply-to-Customer's icon in
Update 13). `CloneTemplateDialog.jsx` reuses `CreateTemplateDialog.jsx`'s Alert-for combobox pattern
and the existing `ConfirmDialog` component for the warning step (Principle II — no new dialog
paradigm introduced). No new dependencies.

**Post-design re-check (2026-07-21 update 16)**: All principles still PASS.
`ApproveAsync`/`RequestChangeAsync` stay in the Application layer (`EutrTemplatesService`) and the
controller actions are thin, no-body POSTs delegating immediately (Principle I). `RequestChangeAsync`
reuses the exact same `CopyDetailTreeAsync`/`CopyReferencesAsync` pipeline `CloneAsync` (Update 15)
already established, rather than inventing a second copy mechanism (Principle II — reference-pattern
reuse, this time reusing a pattern from *within the same feature's own prior update*, the strongest
form of this principle). Deleting the age-based branch from `UpdateAsync` is a net reduction in
service-layer complexity (one unconditional path replaces two), not a new violation. The frontend
toolbar buttons reuse the existing `selectedIds` checkbox-selection state (Update 10) and the
existing `ConfirmDialog` component (Update 9/13/15) — no new selection mechanism, no new dialog
component (Principle II). `TEMPLATE_STATUS` is added to the same shared `compliance-client/src/
utils/helpers.js` module already holding `REQUIREMENT_TYPES`/`groupEmailType` (Principle II). No new
route, no new menu entry — Approve/Request change are toolbar actions on the already-routed
`TemplateListPage.jsx` (Principle V unaffected). No new backend authorization policy family — both
new actions reuse `EutrTemplates.Update`, the same policy already gating this controller's other
mutating actions. No new dependencies.

**Post-design re-check (2026-07-22 update 17)**: All principles still PASS. Drag-and-drop is added
entirely within `TemplateBuilderPage.jsx` (presentation layer — Principle I unaffected; no new
service, controller, or DTO). It reuses `reorderSiblings` from the existing `useStepTree.js` hook
verbatim (Principle II — reference-pattern reuse, the strongest form: reusing this feature's own
already-tested tree-mutation function rather than writing a second reordering implementation) and
`@dnd-kit/core`/`@dnd-kit/sortable`, dependencies already declared in `package.json` since this
feature's original plan (no new dependency added). No backend change at all (Principle III — the
Update Template endpoint's request shape is unaffected, contracts/api-endpoints.md's Update 17 note
confirms zero contract change). No new route, no new menu entry (Principle V unaffected — this is an
interaction added to the already-routed `/eutr/templates/edit/:id` page).

**Post-design re-check (2026-07-23 update 18)**: All principles still PASS. `SetDefaultAsync` stays
in the Application layer (`EutrTemplatesService`), the new controller action is a thin, single-line
delegation matching every other `{id}`-scoped action's shape (Principle I). `SetIsDefaultAsync`
follows the exact same single-column-`UPDATE` shape as the existing `SetStatusAsync` (Update 16 —
Principle II, reference-pattern reuse within this same feature). `ClearGlobalDefaultAsync` (Update
13) is reused verbatim, not reimplemented, when the new value is `true` (Principle III — reuse
existing backend). The frontend change reuses the existing `ConfirmDialog` component (Update 9/13/
15/16) — no new dialog paradigm (Principle II). No new route, no new menu entry — this is a new
action on the already-routed `EutrTemplatesController`/`TemplateBuilderPage.jsx` (Principle V
unaffected). No new authorization policy family — the new endpoint reuses `EutrTemplates.Update`,
the same policy already gating this controller's other mutating actions. No new dependency.

## Project Structure

### Documentation (this feature)

```text
specs/003-eutr-templates/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0: research decisions
├── data-model.md        # Phase 1: entity model
├── quickstart.md        # Phase 1: validation guide
├── contracts/
│   └── api-endpoints.md # Phase 1: REST API contracts
├── checklists/
│   └── requirements.md  # Spec quality checklist
└── tasks.md             # Phase 2 output (/speckit-tasks)
```

### Source Code (repository root)

```text
compliance-sys-api/src/
├── ComplianceSys.Domain/
│   ├── Entities/
│   │   ├── EutrTemplates.cs              # NEW — template entity; MODIFY (Update 7) — AlertFor: string → long?; (Update 13) MODIFY — remove VendorCode; (Update 16) MODIFY — add Status (string, "Draft"/"Approved")
│   │   ├── EutrTemplateDetails.cs       # NEW — template detail entity
│   │   ├── EutrTemplateReferences.cs    # NEW (Update 13) — Apply-to-Customer mapping entity (TemplateId, VendorCode, FromDate, ToDate; inherits BaseEntity, no IsDeleted/IsHide)
│   │   └── ComplGroupEmail.cs           # EXISTS — group-email entity, read via LEFT JOIN (Update 7)
│   └── Dynamics/
│       ├── VendorsV3.cs                 # EXISTS — D365 vendor model
│       └── RSVNEutrTemplates.cs         # (Update 13) MODIFY — remove VendorCode property + FilterableFields entry (D365 sync model, ModelType=17); re-verify no other caller before deleting
├── ComplianceSys.Application/
│   ├── Dtos/
│   │   ├── Request/
│   │   │   ├── EutrTemplatesRequestDto.cs        # NEW; MODIFY (Update 7) — AlertFor: string → long?; (Update 13) MODIFY — remove VendorCode
│   │   │   ├── EutrTemplateDetailsRequestDto.cs # MODIFY — add StepName (used when StepId is null)
│   │   │   ├── EutrTemplateReferencesRequestDto.cs # NEW (Update 13) — TemplateId, VendorCode, FromDate, ToDate
│   │   │   ├── CloneEutrTemplatesRequestDto.cs # NEW (Update 15) — Name, AlertFor (used by POST {id}/clone)
│   │   │   └── SetDefaultEutrTemplatesRequestDto.cs # NEW (Update 18) — single field IsDefault (bool), used by POST {id}/set-default
│   │   └── Response/
│   │       ├── EutrTemplatesResponseDto.cs       # NEW; MODIFY (Update 7) — add AlertForName (string?); (Update 11) add StepsCount (int); (Update 13) MODIFY — remove VendorName; (Update 16) MODIFY — add Status
│   │       ├── EutrTemplateDetailsResponseDto.cs # NEW
│   │       ├── ImportEutrTemplatesResultDto.cs  # NEW
│   │       ├── EutrTemplateReferencesResponseDto.cs # NEW (Update 13) — inherits EutrTemplateReferences + VendorName (D365 refType=13 lookup)
│   │       └── ImportEutrTemplateReferencesResultDto.cs # NEW (Update 14) — TotalRows/SuccessCount/FailCount/Errors (Row, TemplateCode, VendorCode, Message)
│   ├── Validators/
│   │   ├── EutrTemplatesRequestDtoValidator.cs  # MODIFY — each detail requires StepId OR non-blank StepName; (Update 7) AlertFor rule: NotEmpty(string) → Must(v => v.HasValue && v.Value > 0); (Update 13) verified — no VendorCode rule existed, no change needed
│   │   ├── EutrTemplateReferencesRequestDtoValidator.cs # NEW (Update 13) — VendorCode NotEmpty, FromDate required, ToDate >= FromDate when present
│   │   └── CloneEutrTemplatesRequestDtoValidator.cs # NEW (Update 15) — Name NotEmpty, AlertFor positive value (same two rules as EutrTemplatesRequestDtoValidator)
│   ├── Interfaces/
│   │   ├── Services/
│   │   │   ├── IEutrTemplatesService.cs          # NEW
│   │   │   ├── IEutrTemplatesImportService.cs    # NEW
│   │   │   ├── IEutrTemplatesExportService.cs    # NEW
│   │   │   ├── IEutrTemplateReferencesService.cs # NEW (Update 13)
│   │   │   ├── IEutrTemplateReferencesImportService.cs # NEW (Update 14) — ImportFromExcelAsync(templateId, stream, userEmail, ct)
│   │   │   └── IEutrTemplateReferencesExportService.cs # NEW (Update 14) — ExportToExcelAsync(templateId, ct)
│   │   └── Repositories/
│   │       ├── IEutrTemplatesRepository.cs       # MODIFY — add ReplaceDetailsAsync (in-place update) + ResolveOrCreateStepsByNameAsync (free-solo step auto-create); (Update 7) add ResolveAlertGroupIdByNameAsync (Import lookup, exact match, no auto-create); (Update 13) MODIFY — ClearIsDefaultForVendorAsync(vendorCode, excludeId) → ClearGlobalDefaultAsync(excludeId); (Update 16) MODIFY — add CopyDetailTreeAsync(sourceTemplateId, newTemplateId, ct) (extracted from Clone's re-index logic, now shared with RequestChangeAsync) + SetStatusAsync(id, status, userEmail, ct); (Update 18) MODIFY — add SetIsDefaultAsync(id, isDefault, userEmail, ct) (single-column IsDefault update, same shape as SetStatusAsync)
│   │       └── IEutrTemplateReferencesRepository.cs # NEW (Update 13) — GetByTemplateIdAsync, HasOverlapAsync (same-template-same-vendor); (Update 15) MODIFY — add CopyReferencesAsync(sourceTemplateId, newTemplateId, ct)
│   ├── Services/
│   │   ├── EutrTemplatesService.cs               # MODIFY — conditional versioning (24h threshold) in UpdateAsync; resolve/auto-create free-solo step names before saving details (AddAsync + both UpdateAsync branches); (Update 13) MODIFY — remove D365 vendor-name resolution block from GetPagedAsync + IComplDynamicsService ctor dependency; AddAsync/UpdateAsync (3 call sites) switch ClearIsDefaultForVendorAsync → ClearGlobalDefaultAsync; (Update 15) MODIFY — constructor gains IEutrTemplateReferencesRepository dependency; UpdateAsync's ≥24h branch calls CopyReferencesAsync(id, newId, ct) after BulkInsertDetailsAsync (FR-049); add CloneAsync(sourceId, dto, userEmail, ct) reusing BuildDetailEntitiesAsync/BulkInsertDetailsAsync + CopyReferencesAsync (FR-050 to FR-054); (Update 16) MODIFY — AddAsync/CloneAsync set Status="Draft" unconditionally; UpdateAsync DELETES the 24h-branch entirely — rejects with ValidationException when existing.Status=="Approved", else always in-place update (old <24h path, now unconditional); add ApproveAsync(id, userEmail, ct) (Draft→Approved via SetStatusAsync, no new row) and RequestChangeAsync(id, userEmail, ct) (Approved→Draft: new row VersionId+1 via CopyDetailTreeAsync + CopyReferencesAsync, old row IsHide=1 via SetStatusAsync-adjacent update); (Update 18) MODIFY — add SetDefaultAsync(id, isDefault, userEmail, ct) — no Status check (deliberately bypasses the Approved-rejects-edits gate); isDefault=true calls the existing ClearGlobalDefaultAsync(id, ct) first, then SetIsDefaultAsync; isDefault=false calls SetIsDefaultAsync directly
│   │   ├── EutrTemplatesImportService.cs         # NEW — Excel import; MODIFY (Update 7) — resolve AlertFor Excel cell (group Name) to Id via ResolveAlertGroupIdByNameAsync, new "Alert for group not found" error case; (Update 13) MODIFY — drop VendorCode cell (was col C), IsDefault shifts D→C
│   │   ├── EutrTemplatesExportService.cs         # NEW — Excel export; MODIFY (Update 7) — write AlertForName instead of raw AlertFor Id; (Update 13) MODIFY — drop "Vendor code" header/cell (was col 3), AlertForName/IsDefault/VersionId shift 4/5/6→3/4/5
│   │   ├── ComplDynamicsService.cs              # EXISTS — VendorsV3 refType already mapped
│   │   ├── EutrTemplateReferencesService.cs     # NEW (Update 13) — AddAsync/UpdateAsync call HasOverlapAsync first (FR-036); DeleteAsync is a real hard delete (no soft-delete override)
│   │   ├── EutrTemplateReferencesImportService.cs # NEW (Update 14) — modeled on EutrTemplatesImportService; validates TemplateCode/VendorCode/FromDate/ToDate per row, reuses EutrTemplateReferencesService.AddAsync per valid row (no duplicated validation/overlap logic)
│   │   └── EutrTemplateReferencesExportService.cs # NEW (Update 14) — modeled on EutrTemplatesExportService; 4 columns (TemplateCode, VendorCode, FromDate, ToDate), no D365 call needed
│   ├── Mappings/
│   │   └── EutrMappingProfile.cs                # MODIFY — add template mappings (AutoMapper copies AlertFor by name/type automatically — no profile change needed for the long? switch itself); (Update 13) MODIFY — add CreateMap<EutrTemplateReferencesRequestDto, EutrTemplateReferences>() (ignore Id/audit fields); verify VendorCode had no explicit .ForMember (removal needs no profile change)
│   └── DependencyInjection.cs                   # MODIFY — register services + validator; (Update 13) MODIFY — register IEutrTemplateReferencesService + IValidator<EutrTemplateReferencesRequestDto>; (Update 14) MODIFY — register IEutrTemplateReferencesImportService/IEutrTemplateReferencesExportService
├── ComplianceSys.Infrastructure/
│   ├── Repositories/
│   │   ├── EutrTemplatesRepository.cs            # MODIFY — add ReplaceDetailsAsync (delete+insert details for in-place update) + ResolveOrCreateStepsByNameAsync (match/insert into eutr_steps); (Update 7) add `LEFT JOIN compl_group_email g ON g.Id = t.AlertFor` + `g.Name AS AlertForName` to GetPagedWithVendorNameAsync/GetByIdWithDetailsAsync; FilterMap["AlertFor"] → "g.Name"; add ResolveAlertGroupIdByNameAsync; (Update 10/11) GetPagedWithVendorNameAsync gains `(SELECT COUNT(*) FROM eutr_template_details d WHERE d.TemplateId = t.Id) AS StepsCount` + a `Keyword` column special-case → `(Code LIKE @p OR Name LIKE @p)`; (Update 13) MODIFY — drop VendorCode from SortMap/FilterMap + both header SELECT lists; rename method → GetPagedAsync; ClearIsDefaultForVendorAsync → ClearGlobalDefaultAsync (drop VendorCode predicate)
│   │   └── EutrTemplateReferencesRepository.cs   # NEW (Update 13) — extends DapperRepository<EutrTemplateReferences, long>; GetByTemplateIdAsync, HasOverlapAsync (date-range overlap query, same TemplateId + VendorCode only); (Update 15) MODIFY — add CopyReferencesAsync (single INSERT ... SELECT, preserves original audit fields)
│   ├── Sqls/
│   │   ├── Tables/
│   │   │   └── eutr_db.sql                       # (Update 13) MODIFY — add CREATE TABLE eutr_template_references (fresh-install parity; only auto-executed by DatabaseInitializer.InitTables() on a brand-new DB). Note: this file is already drifted from the live schema (missing Code/AlertFor/IsDeleted/IsHide on eutr_templates) — pre-existing gap. (Update 16) MODIFY — add Status TINYINT NULL DEFAULT 0 to the fresh-install eutr_templates DDL.
│   │   └── Migration/
│   │       ├── 08_migrate_eutr_templates_alertfor.sql  # NEW (Update 7) — clear non-numeric AlertFor placeholders, then MODIFY COLUMN AlertFor to BIGINT UNSIGNED NULL (see research.md §18 step 4). Prior eutr_templates column additions (Code/AlertFor/IsDeleted/IsHide) were applied out-of-band, not as numbered migration files — this one follows the numbered convention for traceability going forward.
│   │       ├── 11_create_eutr_template_references.sql # NEW (Update 13) — CREATE TABLE eutr_template_references per docs/design/eutr/eutr_db.sql's DDL (manually applied against existing environments, per this folder's established convention)
│   │       └── 13_add_status_to_eutr_templates.sql # NEW (Update 16) — ALTER TABLE eutr_templates ADD COLUMN Status TINYINT NULL DEFAULT 0 (DEFAULT clause backfills existing rows)
│   └── DependencyInjection.cs                   # MODIFY — register repository; (Update 13) MODIFY — register IEutrTemplateReferencesRepository
└── ComplianceSys.Api/
    └── Controllers/
        ├── EutrTemplatesController.cs           # NEW — REST endpoints; (Update 15) MODIFY — add POST {id:long}/clone (EutrTemplates.Create policy, same try/catch shape as Create); (Update 16) MODIFY — add POST {id:long}/approve and POST {id:long}/request-change (both EutrTemplates.Update policy, no-body, same try/catch shape); (Update 18) MODIFY — add POST {id:long}/set-default (EutrTemplates.Update policy, body { isDefault: bool }, same try/catch shape — no Status precondition to reject on)
        ├── ComplGroupEmailController.cs          # UNCHANGED (Update 7) — GET /api/group-email reused as-is by the frontend combobox
        ├── DynController.cs                     # UNCHANGED (Update 5) — GET vendors endpoint from Update 2/3 kept but no longer called by this feature
        └── EutrTemplateReferencesController.cs   # NEW (Update 13) — GET by-template/{templateId}, POST, PUT {id}, DELETE {id}; policies confirmed as shipped = reuse EutrTemplates.Read/.Update/.Delete (no new policy family); (Update 14) MODIFY — add POST import/{templateId:long} (EutrTemplates.Update) and GET export/{templateId:long} (EutrTemplates.Read), same try/catch shape as EutrTemplatesController.Import/.Export

compliance-client/src/
├── domain/
│   ├── entities/
│   │   ├── EutrTemplates.js                      # NEW; MODIFY (Update 7) — add alertForName alongside alertFor (mirrors vendorName/vendorCode); (Update 13) MODIFY — remove vendorCode/vendorName; (Update 16) MODIFY — add status
│   │   ├── EutrTemplateDetails.js               # NEW
│   │   └── EutrTemplateReferences.js            # NEW (Update 13) — id, templateId, vendorCode, vendorName, fromDate, toDate, audit fields
│   └── interfaces/
│       ├── IEutrTemplatesRepository.js          # NEW
│       └── IEutrTemplateReferencesRepository.js # NEW (Update 13)
├── infrastructure/
│   ├── api/
│   │   ├── eutrTemplatesApi.js                  # NEW; (Update 15) MODIFY — add clone(id, payload) (POST eutr-templates/{id}/clone); (Update 16) MODIFY — add approve(id)/requestChange(id); (Update 18) MODIFY — add setDefault(id, isDefault) (POST eutr-templates/{id}/set-default)
│   │   ├── groupEmailApi.js                     # EXISTS (Update 7) — GET /group-email reused as-is via GetAllGroupEmailUseCase, no change needed
│   │   ├── dynamicsApi.js                       # UNCHANGED (Update 5) — getVendors kept but unused by this feature; reference API client already exists
│   │   └── eutrTemplateReferencesApi.js         # NEW (Update 13) — get-by-template, create, update, delete; (Update 14) MODIFY — add importByTemplate(templateId, file)/exportByTemplate(templateId)
│   └── repositories/
│       ├── RestEutrTemplatesRepository.js       # NEW; (Update 15) MODIFY — add clone(id, payload) passthrough; (Update 16) MODIFY — add approve(id)/requestChange(id) passthroughs; (Update 18) MODIFY — add setDefault(id, isDefault) passthrough
│       ├── RestDynamicsRepository.js            # UNCHANGED (Update 5) — getVendors kept but unused by this feature
│       └── RestEutrTemplateReferencesRepository.js # NEW (Update 13) — getByTemplateId/create/update/delete, wraps EutrTemplateReferences; (Update 14) MODIFY — add importByTemplate/exportByTemplate passthroughs
├── application/
│   └── usecases/
│       ├── eutr-templates/
│       │   ├── CreateEutrTemplatesUseCase.js      # NEW
│       │   ├── UpdateEutrTemplatesUseCase.js      # NEW
│       │   ├── DeleteEutrTemplatesUseCase.js      # NEW
│       │   ├── DeleteMultiEutrTemplatesUseCase.js # NEW
│       │   ├── GetEutrTemplatesUseCase.js         # NEW
│       │   ├── GetPagingEutrTemplatesUseCase.js  # NEW
│       │   ├── ImportEutrTemplatesUseCase.js     # NEW
│       │   ├── ExportEutrTemplatesUseCase.js     # NEW
│       │   ├── CloneEutrTemplatesUseCase.js      # NEW (Update 15) — execute(sourceId, {name, alertFor}) → POST eutr-templates/{sourceId}/clone
│       │   ├── ApproveEutrTemplatesUseCase.js    # NEW (Update 16) — execute(id) → POST eutr-templates/{id}/approve
│       │   ├── RequestChangeEutrTemplatesUseCase.js # NEW (Update 16) — execute(id) → POST eutr-templates/{id}/request-change
│       │   └── SetDefaultEutrTemplatesUseCase.js # NEW (Update 18) — execute(id, isDefault) → POST eutr-templates/{id}/set-default
│       ├── eutr-template-references/             # NEW (Update 13) — one file per operation
│       │   ├── GetByTemplateIdEutrTemplateReferencesUseCase.js
│       │   ├── CreateEutrTemplateReferencesUseCase.js
│       │   ├── UpdateEutrTemplateReferencesUseCase.js
│       │   ├── DeleteEutrTemplateReferencesUseCase.js
│       │   ├── ImportEutrTemplateReferencesUseCase.js # NEW (Update 14) — mirrors ImportEutrTemplatesUseCase.js
│       │   └── ExportEutrTemplateReferencesUseCase.js # NEW (Update 14) — mirrors ExportEutrTemplatesUseCase.js's blob-download trigger
│       └── group-email/
│           └── GetAllGroupEmailUseCase.js         # EXISTS (Update 7) — reused as-is from ComplianceMasterForm/MasterDefaultForm, no change needed
├── presentation/
│   └── pages/
│       └── eutr-templates/
│           ├── TemplateListPage.jsx              # RENAME (Update 9) — was index.jsx/EutrTemplatesPage; (Update 10/11) MODIFY — keep its own Table/search/chip layout, swap mock data (`mock/eutrTemplates.js`, `mock/eutrTemplateDetails.js`) for `useEutrTemplatesData`/`permissionList`/`DeleteEutrTemplatesUseCase`/`DeleteMultiEutrTemplatesUseCase`/`CreateTemplateDialog`/`ConfirmDialog`/`CustomSnackbar` (reused from TemplateListPageOld.jsx, itself unchanged); Code shown bold, Name as caption; Steps column reads real `stepsCount`; add per-row checkbox + bulk-delete toolbar button; add `TablePagination`; search box sends a debounced `{field:'keyword', operator:'contains', value}` filter item and resets to page 0; Clone/Apply-to-Customer icons kept but `disabled` (mock onClick/dialog removed); **(Update 13) MODIFY** — Apply-to-Customer icon becomes active: `onClick={() => navigate(\`/eutr/templates/apply/${tmpl.id}\`)}`, gated by the same permission check as Edit; Clone stays disabled; **(Update 15) MODIFY** — Clone icon becomes active: `onClick={() => setCloneDialogTemplate(row)}` opens `CloneTemplateDialog` for that row; on successful Clone, closes the dialog and re-runs the existing list-refresh (same `fetchData()` call `CreateTemplateDialog` already triggers); **(Update 16) MODIFY** — add a Status `Chip` per row; add **Approve**/**Request change** toolbar `Button`s next to Create Template, enabled only when the existing `selectedIds` (bulk-delete checkbox state) has exactly 1 entry whose row status matches; clicking either opens `ConfirmDialog` (Yes/No), confirming calls `ApproveEutrTemplatesUseCase`/`RequestChangeEutrTemplatesUseCase.execute(id)`, clears selection, re-runs `fetchData()`, shows `CustomSnackbar`
│           ├── TemplateBuilderPage.jsx           # (Update 10) MODIFY — keep its own tree-view + toolbar + side-panel layout, swap mock data (`mock/eutrTemplates.js`, `mock/eutrTemplateDetails.js`, `mock/eutrSteps.js`, `utils/treeUtils.js`) for `GetEutrTemplatesUseCase`/`UpdateEutrTemplatesUseCase`/`GetEutrStepsUseCase`/`GetAllGroupEmailUseCase`/`ReferenceObjectAutocomplete` (refType=13) and the existing `useStepTree` hook (replaces its own hand-rolled tree state); Add Root/Add Child step-picker becomes free-solo Autocomplete over the real steps list; Type/FSC fields and the 8-option mock TakeFrom list removed (not in the real schema); Move Up/Down buttons call `reorderSiblings`; side panel shows the header form (Code/Name/AlertFor/Vendor/Default/Save) when no step is selected, step detail (real RequirementType/TakeFrom) when one is; Save calls `UpdateEutrTemplatesUseCase` then navigates to `/eutr/templates`; Back reuses the `isDirty` + `ConfirmDialog` pattern from EutrTemplatesAddEdit.jsx; **(Update 12) MODIFY** — Add Root Group/Add Child Step `Dialog` content swaps `<StepFormRow>` (+ `addStepFormRef`/`addStepValid`, removed) for `<BulkAddStepsDialog onAdd={addSteps} existingChildStepIds={...} />`; **(Update 13) MODIFY** — remove `vendorCode`/`vendorName` state, the two setters in the load effect, `vendorCode` from the Save payload, and the entire Vendor `ReferenceObjectAutocomplete` block + its now-unused import from the side panel (FR-041); **(Update 16) MODIFY** — read `template.status`; when `TEMPLATE_STATUS.APPROVED`, render a warning `Alert` banner and `disabled` every header field, the Save button, Root Group/Child Step toolbar buttons, and each step row's Edit/Delete icons (FR-061); Draft behaves unchanged; **(Update 17) MODIFY** — wrap `<SimpleTreeView>` in a `<DndContext>`, wrap each tree level's siblings in their own `<SortableContext>`, add a drag-handle icon per `TreeItem` wired to `useSortable` (`disabled: isReadOnly`), and add `handleDragEnd` which calls the existing `reorderSiblings` when the dragged/target nodes share a `parentId` (no-op otherwise) — additive to the unchanged Move Up/Down buttons (FR-064 to FR-067; research.md §34); **(Update 18) MODIFY** — Set-as-default `Checkbox` no longer follows the blanket `isReadOnly` disabled flag; its `onChange` branches on `status` — Draft: unchanged (local state, saved via Save); Approved: opens `ConfirmDialog` with the intended value, Yes calls `SetDefaultEutrTemplatesUseCase.execute(id, value)` and updates local state from the result, No closes the dialog with no change (FR-068; research.md §35)
│           ├── ApplyCustomerPage.jsx             # NEW-scope, EXISTS as mock (Update 13) MODIFY — rewrite from `MOCK_CUSTOMERS`/`MOCK_TEMPLATE_CUSTOMERS` (`mock/eutrTemplates.js`) + `status !== 'Published'` gate to real data: Vendor combobox via `ReferenceObjectAutocomplete`(refType=13), load/save via the new `eutr-template-references` use cases keyed by the `:id` route param, drop the Published gate (no Status concept on real templates at that time), keep the existing `hasOverlap()` client pre-check rescoped from `customerId` to `vendorCode` (server `HasOverlapAsync` is authoritative); **(Update 14) MODIFY** — add Import/Export `Button`s to the header `Stack` (FR-043): hidden `<input type="file" accept=".xlsx">` wired to `ImportEutrTemplateReferencesUseCase.execute(id, file)`, opens `ImportMappingResultDialog` with the result and calls `fetchMappings()` to refresh; Export button calls `ExportEutrTemplateReferencesUseCase.execute(id)` directly (no dialog); new `importing`/`importResult`/`importDialogOpen` state; **(Update 16) NO CHANGE** — the real Status added by this update does NOT gate Apply to Customer; this page keeps working at any Status (Draft or Approved), per FR-032
│           ├── EutrTemplatesAddEdit.jsx          # MODIFY (through Update 9) — 2-column layout (widened header/narrowed steps), vendor via ReferenceObjectAutocomplete (refType=13) (Update 5), Save button moved below Default checkbox, Back dirty-check confirm dialog; (Update 7) Alert for `Autocomplete` switches from `freeSolo`/hardcoded `ALERT_FOR_OPTIONS` to `GetAllGroupEmailUseCase`-backed, select-only, filtered to `groupType===2 && isAddition===false`, storing the selected group's `id`; (Update 9) becomes Edit-only; **(Update 10) UNCHANGED but no longer routed** — `/eutr/templates/edit/:id` now points at TemplateBuilderPage.jsx; left in place unreferenced (cleanup candidate for a future task, same precedent as the unused vendors endpoint from Update 5), not deleted by this feature
│           ├── components/
│           │   ├── EutrTemplatesActionCell.jsx   # NEW — row action buttons; (Update 9) verified against FR-020, no change (Edit + Delete only, already correct)
│           │   ├── CreateTemplateDialog.jsx      # NEW (Update 9) — quick-create dialog: Name, Alert for combobox, Set as default checkbox only; calls CreateEutrTemplatesUseCase with vendorCode=null, details=[]; (Update 10) reused as-is by TemplateListPage.jsx's Table layout, no change needed; (Update 13) MODIFY — delete the hardcoded `vendorCode: null` line from the Save payload
│           │   ├── StepTree.jsx                  # MODIFY — add inline Edit step mode; (Update 6) inline-edit Step combobox becomes freeSolo; (Update 8) delete local REQUIREMENT_TYPES/TAKE_FROM_OPTIONS/REQUIREMENT_LABELS/TAKE_FROM_LABELS, import from utils/helpers.js; (Update 10) not reused by TemplateBuilderPage.jsx (which keeps its own tree-rendering shell) — only its underlying `useStepTree` hook and `utils/helpers.js` constants are shared
│           │   ├── StepFormRow.jsx               # NEW — add step form; (Update 6) Step combobox becomes freeSolo (pick existing or type new name); (Update 8) delete local REQUIREMENT_TYPES/TAKE_FROM_OPTIONS duplicate, import from utils/helpers.js; (Update 10) same free-solo Autocomplete pattern reused inside TemplateBuilderPage.jsx's own Add Root/Add Child dialogs; **(Update 12) no longer used by TemplateBuilderPage.jsx** (replaced there by BulkAddStepsDialog.jsx) — still used by the unrouted EutrTemplatesAddEdit.jsx, left unchanged
│           │   ├── BulkAddStepsDialog.jsx        # NEW (Update 12) — checkbox table of available EUTR steps (per-row Requirement Type/Take From once ticked) + a single free-solo "Add new step" entry row + "{N} available - {M} selected" footer; used only by TemplateBuilderPage.jsx's Add Root Group/Add Child Step dialogs
│           │   ├── ImportResultDialog.jsx        # NEW — import result display; (Update 9) reference pattern reused by CreateTemplateDialog
│           │   ├── ImportMappingResultDialog.jsx # NEW (Update 14) — copies ImportResultDialog.jsx's structure, error table columns Row/TemplateCode/VendorCode/Reason; used only by ApplyCustomerPage.jsx's Import button
│           │   └── CloneTemplateDialog.jsx       # NEW (Update 15) — read-only source Code/Name, required New template name field, required Alert for combobox (reuses CreateTemplateDialog's GetAllGroupEmailUseCase-backed pattern), Cancel/Clone buttons; Clone opens the existing ConfirmDialog warning before calling CloneEutrTemplatesUseCase
│           ├── mock/
│           │   ├── eutrTemplates.js              # (Update 10) UNCHANGED but orphaned — no longer imported by TemplateListPage.jsx/TemplateBuilderPage.jsx after real-data wiring; left in place
│           │   ├── eutrTemplateDetails.js        # (Update 10) UNCHANGED but orphaned — same as above
│           │   └── eutrSteps.js                  # (Update 10) UNCHANGED but orphaned — no longer imported by TemplateBuilderPage.jsx or utils/treeUtils.js's (now-unused) consumers
│           ├── utils/
│           │   └── treeUtils.js                  # (Update 10) UNCHANGED but orphaned — TemplateBuilderPage.jsx now uses `useStepTree`'s buildTree/flattenForSave instead
│           └── hooks/
│               ├── useEutrTemplatesColumns.jsx   # NEW — grid column definitions; (Update 7) `alertFor` column field → `alertForName`; (Update 9) verified against FR-020, no change; (Update 10) no longer used by TemplateListPage.jsx (Table layout doesn't use DataGrid columns) — still used by TemplateListPageOld.jsx, kept unchanged; (Update 13) MODIFY — remove `vendorCode`/`vendorName` from `defaultColumnVisibility` and the `columns` array (kept in sync for the unrouted old page)
│               ├── useEutrTemplatesData.js       # NEW — list data hook; (Update 11) reused as-is by TemplateListPage.jsx — no hook change needed, `useFilterPayload` already title-cases `keyword` → `Keyword`
│               ├── useVendors.js                 # REMOVE (Update 5) — superseded by shared useReferenceObjects/ReferenceObjectAutocomplete
│               └── useStepTree.js                # MODIFY — fix flattenForSave ParentId + add editStep + isDirty tracking for Back warning; (Update 6) flattenForSave also emits stepName for every detail; (Update 10) now also consumed by TemplateBuilderPage.jsx (previously only EutrTemplatesAddEdit.jsx) — no hook change needed, already generic over any host component; **(Update 12) MODIFY** — add `addSteps(newSteps)` bulk-append function (sequential displayOrder per parentId, one isDirty flip), sibling to the unchanged `addStep`; **(Update 17) NO CHANGE** — `reorderSiblings` is already generic over the caller's trigger gesture (button click or drag drop), consumed as-is by the new drag-and-drop `handleDragEnd`
├── utils/
│   └── helpers.js                                 # MODIFY (Update 8) — add REQUIREMENT_TYPES, TAKE_FROM_OPTIONS, REQUIREMENT_LABELS, TAKE_FROM_LABELS exports (moved from StepTree.jsx); (Update 16) MODIFY — add TEMPLATE_STATUS = Object.freeze({ DRAFT: 0, APPROVED: 1 })
├── di/
│   └── repositories.js                           # MODIFY — add eutrTemplates repo; repositories.groupEmail EXISTS already (Update 7 reuses it); (Update 13) MODIFY — add `eutrTemplateReferences: new RestEutrTemplateReferencesRepository()`
└── app/
    └── routes/
        ├── RouteResolver.jsx                     # MODIFY — add codeToComponent entry; (Update 9) lazy import path → `.../eutr-templates/TemplateListPage`; (Update 10) unchanged — already correct; (Update 13) unchanged — ApplyCustomerPage is a MainRoutes.jsx route, not a menu-resolved page
        └── groups/
            └── MainRoutes.jsx                    # MODIFY — add add/edit routes; (Update 9) remove the `/eutr/templates/add` route entry (Create is now a dialog on the list page, not a routed page); (Update 10) unchanged — `/eutr/templates/edit/:id` already pointed at TemplateBuilderPage.jsx; (Update 13) MODIFY — add lazy `ApplyCustomerPage` import + `{ path: '/eutr/templates/apply/:id', element: <ApplyCustomerPage /> }` route entry, same pattern/array as `/eutr/templates/edit/:id`; (Update 14) unchanged — Import/Export are buttons inside the existing ApplyCustomerPage route, no new route
```

**Structure Decision**: Web application (backend + frontend). Backend follows existing EUTR feature pattern (`eutr-masters` as primary reference for CRUD + import/export). Frontend follows layered Clean Architecture with `eutr-steps` as structural reference. Edit uses a full page (not modal) following `compliance-master/:id` routing pattern; Create (Update 9) uses a lightweight in-page Dialog instead, per the design reference — narrower scope than the full Edit page. **(Update 10)**: the list and Edit pages are `TemplateListPage.jsx`/`TemplateBuilderPage.jsx` (their own Table+chip / tree-view+panel visual designs, already present as reference-design files), rewired to the real data/use-cases originally built for `TemplateListPageOld.jsx`/`EutrTemplatesAddEdit.jsx` — a data-layer swap, not a new UI build. **(Update 13)**: `eutr_template_references` gets its own full CRUD stack (all four backend layers + the full frontend layer set), modeled on the existing `EutrTemplates*` stack (Principle II) since there is no usable reference implementation for that table; `ApplyCustomerPage.jsx` is likewise a data-layer swap (mock Customer data → real Vendor/API data), not a new UI build, following the same precedent as Update 10's `TemplateListPage.jsx`/`TemplateBuilderPage.jsx` rewiring. **(Update 14)**: Import/Export for `eutr_template_references` follows the exact same backend Excel-service + controller-action pattern already proven by `EutrTemplatesImportService`/`EutrTemplatesExportService`/`EutrTemplatesController` — two new services + two new controller actions, no new table/route/policy family; the row-level "Add" reuses the existing `EutrTemplateReferencesService.AddAsync` instead of re-implementing validation. **(Update 15)**: no new backend stack — a bug fix (one new repository method, `CopyReferencesAsync`, called from the existing `UpdateAsync`'s ≥24h branch) and one new service method/endpoint (`CloneAsync`/`POST {id}/clone`) that reuses the existing detail-insert pipeline (`BuildDetailEntitiesAsync`/`BulkInsertDetailsAsync`) end to end; frontend adds one new dialog (`CloneTemplateDialog.jsx`, modeled on `CreateTemplateDialog.jsx`) wired to the Clone icon Update 10 already placed (disabled) on `TemplateListPage.jsx` — no new route.
**(Update 16)**: no new backend stack and a net simplification — the age-based branch is deleted
from `UpdateAsync` (one unconditional in-place-update path replaces two), and the version-bump
mechanism moves to two new thin endpoints (`Approve`, `RequestChange`) that reuse Update 15's own
Clone copy pipeline (`CopyDetailTreeAsync`/`CopyReferencesAsync`) rather than introducing a third
copy implementation; frontend adds one shared enum (`TEMPLATE_STATUS` in `helpers.js`), two toolbar
buttons reusing the existing bulk-delete checkbox selection and `ConfirmDialog`, and a read-only
gate on `TemplateBuilderPage.jsx` — no new route, no new dialog component, no new dependency.
**(Update 17)**: no backend change at all — a frontend-only addition to `TemplateBuilderPage.jsx`
using dependencies (`@dnd-kit/core`/`@dnd-kit/sortable`) already declared in `package.json` since
this feature's original plan but never previously imported, and reusing `useStepTree.js`'s existing
`reorderSiblings` function verbatim (no new tree-mutation logic). Corrects a stale claim in this
same table and in data-model.md that a working drag-and-drop pattern already existed elsewhere in
this feature (verified false — see research.md §34).
**(Update 18)**: one new single-purpose endpoint (`POST {id}/set-default`) and one new repository
method (`SetIsDefaultAsync`, mirroring `SetStatusAsync`'s single-column-update shape) — the smallest
possible backend surface for carving out one exception to Update 16's Approved-read-only rule;
frontend reuses the existing `ConfirmDialog` component, no new dialog.

### Key Differences from Reference Features

| Aspect           | eutr-steps/eutr-masters (reference)  | eutr-templates (this feature)  |
| ---------------- | ------------------------------------ | ------------------------------ |
| Create UI (Update 9) | Modal dialog                     | Modal dialog — **Name, Alert for, Set as default only** (no Vendor, no step tree) |
| Edit UI          | Modal dialog                         | Full page, **2-column layout** (only place with Vendor + step tree) |
| Add/Edit layout  | Single column form                   | Left: header, Right: step tree |
| Data structure   | Flat entity                          | Header + recursive detail tree |
| Edit behavior    | In-place update                      | **(Superseded by Update 16)** ~~Conditional: in-place if <24h since creation, else versioning (new row, hide old)~~ → Always in-place while Draft; versioning only via the explicit Request change action (Approved→Draft) |
| Delete behavior  | Hard delete (steps) / Soft (masters) | Soft delete (IsDeleted=1)      |
| Code field       | User-entered                         | System-generated (readonly)    |
| Step editing     | N/A                                  | Inline edit (toggle per row)   |
| Vendor combobox  | N/A                                  | Generic reference API (`POST /api/dynamics/reference`, refType=13) |
| Tree component   | None                                 | @mui/x-tree-view; @dnd-kit added Update 17 (listed as a dependency since this feature's original plan, but unused in code until then — see research.md §34) |
| D365 integration | None                                 | VendorsV3 via generic reference API (refType=13) |
| Back navigation  | Direct navigate                      | Dirty-check confirm dialog if unsaved step changes |
| Step combobox    | N/A                                   | Free-solo: pick existing step or type a new name; unrecognized names auto-create an `eutr_steps` row on template Save |
| Alert for combobox | N/A                                 | Select-only (no free-solo) combobox sourced from `compl_group_email` (`GET /api/group-email`), filtered to Alert-type active groups; stores the selected group's Id, displays its Name on the grid (Update 7) |
| List UI (Update 10) | DataGrid grid (Old) | Table + search box + chips (Version/Default) + Steps count, per-row checkbox for bulk delete; Clone/Apply-to-Customer icons present but disabled |
| List search (Update 11) | Per-column DataGrid filter | Single free-text box matching Code OR Name, server-side via a `Keyword` pseudo-filter column |
| Edit UI (Update 10) | N/A (was 2-column form/list) | Tree-view (left) + side panel (right) that shows header fields when no step is selected, step detail when one is — same data/logic as the 2-column form, different shell |
| Step reordering on Edit (Update 10) | **Corrected (Update 17)**: ~~`@dnd-kit` drag-and-drop (StepTree.jsx pattern)~~ — audited and confirmed this was never actually implemented anywhere in the codebase; the claim was aspirational | Move Up/Move Down toolbar buttons calling the same `reorderSiblings` function |
| Step reordering on Edit (Update 17) | N/A | Move Up/Move Down buttons AND real drag-and-drop (`@dnd-kit`), both calling the same `reorderSiblings` function; drag is restricted to same-`ParentId` siblings (no reparenting, FR-065) and disabled when Status=Approved (FR-067) |
| Steps count (Update 11) | N/A | Real per-template count via a correlated subquery, shown on the list |
| Add Root/Child Step (Update 12) | N/A | Bulk-select checkbox table (multiple master steps + one free-solo "Add new step" entry) added to the tree in a single Add click, instead of one step per dialog open |
| Vendor on template (Update 13) | N/A | REMOVED — `eutr_templates` no longer has a Vendor field at all; superseded by a separate time-bound mapping table |
| Default constraint scope (Update 13) | N/A | Changed from per-VendorCode to **global** (system-wide single default) since Vendor no longer lives on the template |
| Apply to Customer (Update 13) | N/A | New `ApplyCustomerPage.jsx` (route `/eutr/templates/apply/:id`) manages N:N Template↔Vendor mappings with FromDate/ToDate in `eutr_template_references` — new full-stack CRUD, hard delete (no soft-delete column) |
| Mapping Import/Export (Update 14) | Templates-level Import/Export (`eutr-templates/import`/`export`, 3-column Name/AlertFor/IsDefault layout) | Separate, per-template-scoped Import/Export on `eutr_template_references` (`eutr-template-references/import/{templateId}`/`export/{templateId}`, 4-column TemplateCode/VendorCode/FromDate/ToDate layout); Import validates TemplateCode against the currently-open template and reuses `EutrTemplateReferencesService.AddAsync` per row (no update-on-match) |
| Version-up mapping copy (Update 15) | N/A | The ≥24h version-up branch now also copies `eutr_template_references` to the new TemplateId (bug fix, FR-049) — previously only the step tree was copied |
| Clone (Update 15) | N/A | New `POST api/eutr-templates/{id}/clone` — duplicates a template's header (new Code, user-entered Name/AlertFor, VersionId=1, IsDefault=0), full step tree, and full vendor-mapping set into a brand-new, independent template; TemplateListPage's Clone icon (disabled since Update 10) becomes active |
| Status field (Update 16) | N/A | New `Status` column (`Draft`/`Approved`, enum in `helpers.js`), defaults to Draft on Create/Clone; shown as a Chip on the list |
| Versioning trigger (Update 16) | N/A | REPLACED — no more 24h age check; `UpdateAsync` always saves in-place while Draft (rejects if Approved); a version bump (new row, VersionId+1, old row hidden) now happens ONLY via `POST {id}/request-change`, reusing Clone's copy pipeline |
| Approve / Request change (Update 16) | N/A | New `POST {id}/approve` (Draft→Approved, same row) and `POST {id}/request-change` (Approved→Draft, new version row) — toolbar buttons on TemplateListPage, gated by the existing single-row checkbox selection, each behind a `ConfirmDialog` Yes/No |
| Edit read-only gate (Update 16) | N/A | TemplateBuilderPage becomes fully read-only (header + step tree) when the loaded template's Status is Approved; editing resumes only after Request change |
| Set as default while Approved (Update 18) | N/A | One exception to the Update 16 read-only gate — the Set-as-default checkbox stays enabled when Approved and persists immediately via a dedicated `POST {id}/set-default` endpoint (behind a Yes/No `ConfirmDialog`), independent of the (still hidden/disabled) Save button |

## Complexity Tracking

No constitution violations to justify. All principles pass cleanly. **(Update 16)** note: this
update is a net complexity *reduction* in `EutrTemplatesService.UpdateAsync` — the two-branch
age-based conditional is deleted and replaced by one unconditional path, with the version-bump
mechanism relocated to a dedicated, explicit action (`RequestChangeAsync`) that reuses existing
Clone-era copy helpers rather than adding new ones. **(Update 17)** note: purely additive frontend
complexity, scoped to one component (`TemplateBuilderPage.jsx`) and reusing an existing tree-mutation
function (`reorderSiblings`) and already-installed dependencies — no new backend surface, no new
dependency, no layer crossed. **(Update 18)** note: one new endpoint + one new single-column
repository method, deliberately scoped to carve out exactly one field (`IsDefault`) from the Update
16 read-only gate rather than loosening that gate generally — the smallest change that satisfies the
request without reopening Approved templates to broader edits.
