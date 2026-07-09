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
│   │   ├── EutrTemplates.cs              # NEW — template entity; MODIFY (Update 7) — AlertFor: string → long?
│   │   ├── EutrTemplateDetails.cs       # NEW — template detail entity
│   │   └── ComplGroupEmail.cs           # EXISTS — group-email entity, read via LEFT JOIN (Update 7)
│   └── Dynamics/
│       └── VendorsV3.cs                 # EXISTS — D365 vendor model
├── ComplianceSys.Application/
│   ├── Dtos/
│   │   ├── Request/
│   │   │   ├── EutrTemplatesRequestDto.cs        # NEW; MODIFY (Update 7) — AlertFor: string → long?
│   │   │   └── EutrTemplateDetailsRequestDto.cs # MODIFY — add StepName (used when StepId is null)
│   │   └── Response/
│   │       ├── EutrTemplatesResponseDto.cs       # NEW; MODIFY (Update 7) — add AlertForName (string?)
│   │       ├── EutrTemplateDetailsResponseDto.cs # NEW
│   │       └── ImportEutrTemplatesResultDto.cs  # NEW
│   ├── Validators/
│   │   └── EutrTemplatesRequestDtoValidator.cs  # MODIFY — each detail requires StepId OR non-blank StepName; (Update 7) AlertFor rule: NotEmpty(string) → Must(v => v.HasValue && v.Value > 0)
│   ├── Interfaces/
│   │   ├── Services/
│   │   │   ├── IEutrTemplatesService.cs          # NEW
│   │   │   ├── IEutrTemplatesImportService.cs    # NEW
│   │   │   └── IEutrTemplatesExportService.cs    # NEW
│   │   └── Repositories/
│   │       └── IEutrTemplatesRepository.cs       # MODIFY — add ReplaceDetailsAsync (in-place update) + ResolveOrCreateStepsByNameAsync (free-solo step auto-create); (Update 7) add ResolveAlertGroupIdByNameAsync (Import lookup, exact match, no auto-create)
│   ├── Services/
│   │   ├── EutrTemplatesService.cs               # MODIFY — conditional versioning (24h threshold) in UpdateAsync; resolve/auto-create free-solo step names before saving details (AddAsync + both UpdateAsync branches)
│   │   ├── EutrTemplatesImportService.cs         # NEW — Excel import; MODIFY (Update 7) — resolve AlertFor Excel cell (group Name) to Id via ResolveAlertGroupIdByNameAsync, new "Alert for group not found" error case
│   │   ├── EutrTemplatesExportService.cs         # NEW — Excel export; MODIFY (Update 7) — write AlertForName instead of raw AlertFor Id
│   │   └── ComplDynamicsService.cs              # EXISTS — VendorsV3 refType already mapped
│   ├── Mappings/
│   │   └── EutrMappingProfile.cs                # MODIFY — add template mappings (AutoMapper copies AlertFor by name/type automatically — no profile change needed for the long? switch itself)
│   └── DependencyInjection.cs                   # MODIFY — register services + validator
├── ComplianceSys.Infrastructure/
│   ├── Repositories/
│   │   └── EutrTemplatesRepository.cs            # MODIFY — add ReplaceDetailsAsync (delete+insert details for in-place update) + ResolveOrCreateStepsByNameAsync (match/insert into eutr_steps); (Update 7) add `LEFT JOIN compl_group_email g ON g.Id = t.AlertFor` + `g.Name AS AlertForName` to GetPagedWithVendorNameAsync/GetByIdWithDetailsAsync; FilterMap["AlertFor"] → "g.Name"; add ResolveAlertGroupIdByNameAsync
│   ├── Sqls/
│   │   └── Migration/
│   │       └── 08_migrate_eutr_templates_alertfor.sql  # NEW (Update 7) — clear non-numeric AlertFor placeholders, then MODIFY COLUMN AlertFor to BIGINT UNSIGNED NULL (see research.md §18 step 4). Prior eutr_templates column additions (Code/AlertFor/IsDeleted/IsHide) were applied out-of-band, not as numbered migration files — this one follows the numbered convention for traceability going forward.
│   └── DependencyInjection.cs                   # MODIFY — register repository
└── ComplianceSys.Api/
    └── Controllers/
        ├── EutrTemplatesController.cs           # NEW — REST endpoints
        ├── ComplGroupEmailController.cs          # UNCHANGED (Update 7) — GET /api/group-email reused as-is by the frontend combobox
        └── DynController.cs                     # UNCHANGED (Update 5) — GET vendors endpoint from Update 2/3 kept but no longer called by this feature

compliance-client/src/
├── domain/
│   ├── entities/
│   │   ├── EutrTemplates.js                      # NEW; MODIFY (Update 7) — add alertForName alongside alertFor (mirrors vendorName/vendorCode)
│   │   └── EutrTemplateDetails.js               # NEW
│   └── interfaces/
│       └── IEutrTemplatesRepository.js          # NEW
├── infrastructure/
│   ├── api/
│   │   ├── eutrTemplatesApi.js                  # NEW
│   │   ├── groupEmailApi.js                     # EXISTS (Update 7) — GET /group-email reused as-is via GetAllGroupEmailUseCase, no change needed
│   │   └── dynamicsApi.js                       # UNCHANGED (Update 5) — getVendors kept but unused by this feature; reference API client already exists
│   └── repositories/
│       ├── RestEutrTemplatesRepository.js       # NEW
│       └── RestDynamicsRepository.js            # UNCHANGED (Update 5) — getVendors kept but unused by this feature
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
│       │   └── ExportEutrTemplatesUseCase.js     # NEW
│       └── group-email/
│           └── GetAllGroupEmailUseCase.js         # EXISTS (Update 7) — reused as-is from ComplianceMasterForm/MasterDefaultForm, no change needed
├── presentation/
│   └── pages/
│       └── eutr-templates/
│           ├── index.jsx                         # NEW — list page (grid)
│           ├── EutrTemplatesAddEdit.jsx          # MODIFY — 2-column layout (widened header/narrowed steps), vendor via ReferenceObjectAutocomplete (refType=13) (Update 5), Save button moved below Default checkbox, Back dirty-check confirm dialog; (Update 7) Alert for `Autocomplete` switches from `freeSolo`/hardcoded `ALERT_FOR_OPTIONS` to `GetAllGroupEmailUseCase`-backed, select-only, filtered to `groupType===2 && isAddition===false`, storing the selected group's `id`
│           ├── components/
│           │   ├── EutrTemplatesActionCell.jsx   # NEW — row action buttons
│           │   ├── StepTree.jsx                  # MODIFY — add inline Edit step mode; (Update 6) inline-edit Step combobox becomes freeSolo; (Update 8) delete local REQUIREMENT_TYPES/TAKE_FROM_OPTIONS/REQUIREMENT_LABELS/TAKE_FROM_LABELS, import from utils/helpers.js
│           │   ├── StepFormRow.jsx               # NEW — add step form; (Update 6) Step combobox becomes freeSolo (pick existing or type new name); (Update 8) delete local REQUIREMENT_TYPES/TAKE_FROM_OPTIONS duplicate, import from utils/helpers.js
│           │   └── ImportResultDialog.jsx        # NEW — import result display
│           └── hooks/
│               ├── useEutrTemplatesColumns.jsx   # NEW — grid column definitions; (Update 7) `alertFor` column field → `alertForName`
│               ├── useEutrTemplatesData.js       # NEW — list data hook
│               ├── useVendors.js                 # REMOVE (Update 5) — superseded by shared useReferenceObjects/ReferenceObjectAutocomplete
│               └── useStepTree.js                # MODIFY — fix flattenForSave ParentId + add editStep + isDirty tracking for Back warning; (Update 6) flattenForSave also emits stepName for every detail
├── utils/
│   └── helpers.js                                 # MODIFY (Update 8) — add REQUIREMENT_TYPES, TAKE_FROM_OPTIONS, REQUIREMENT_LABELS, TAKE_FROM_LABELS exports (moved from StepTree.jsx)
├── di/
│   └── repositories.js                           # MODIFY — add eutrTemplates repo; repositories.groupEmail EXISTS already (Update 7 reuses it)
└── app/
    └── routes/
        ├── RouteResolver.jsx                     # MODIFY — add codeToComponent entry
        └── groups/
            └── MainRoutes.jsx                    # MODIFY — add add/edit routes
```

**Structure Decision**: Web application (backend + frontend). Backend follows existing EUTR feature pattern (`eutr-masters` as primary reference for CRUD + import/export). Frontend follows layered Clean Architecture with `eutr-steps` as structural reference. Add/Edit uses full page (not modal) following `compliance-master/:id` routing pattern.

### Key Differences from Reference Features

| Aspect           | eutr-steps/eutr-masters (reference)  | eutr-templates (this feature)  |
| ---------------- | ------------------------------------ | ------------------------------ |
| Add/Edit UI      | Modal dialog                         | Full page, **2-column layout** |
| Add/Edit layout  | Single column form                   | Left: header, Right: step tree |
| Data structure   | Flat entity                          | Header + recursive detail tree |
| Edit behavior    | In-place update                      | Conditional: in-place if <24h since creation, else versioning (new row, hide old) |
| Delete behavior  | Hard delete (steps) / Soft (masters) | Soft delete (IsDeleted=1)      |
| Code field       | User-entered                         | System-generated (readonly)    |
| Step editing     | N/A                                  | Inline edit (toggle per row)   |
| Vendor combobox  | N/A                                  | Generic reference API (`POST /api/dynamics/reference`, refType=13) |
| Tree component   | None                                 | @mui/x-tree-view + @dnd-kit    |
| D365 integration | None                                 | VendorsV3 via generic reference API (refType=13) |
| Back navigation  | Direct navigate                      | Dirty-check confirm dialog if unsaved step changes |
| Step combobox    | N/A                                   | Free-solo: pick existing step or type a new name; unrecognized names auto-create an `eutr_steps` row on template Save |
| Alert for combobox | N/A                                 | Select-only (no free-solo) combobox sourced from `compl_group_email` (`GET /api/group-email`), filtered to Alert-type active groups; stores the selected group's Id, displays its Name on the grid (Update 7) |

## Complexity Tracking

No constitution violations to justify. All principles pass cleanly.
