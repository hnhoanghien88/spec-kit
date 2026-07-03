# Implementation Plan: EUTR Templates Management

**Branch**: `003-eutr-templates` | **Date**: 2026-07-03 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/003-eutr-templates/spec.md`

## Summary

Full-stack CRUD feature for managing EUTR compliance templates with recursive step trees.
Backend: .NET 8 API with Dapper/MySQL — template versioning (new row on edit, VersionId+1),
soft delete (IsDeleted=1), auto-generated sequential Code, D365 VendorsV3 integration via
dedicated `GET /api/dynamics/vendors` endpoint, and Excel import/export. Frontend: React/MUI
SPA — paginated grid, full-page Add/Edit form with **2-column layout** (header left, step tree
right), `@mui/x-tree-view` step tree with **inline Edit step** capability, `@dnd-kit`
drag-and-drop reordering, and vendor combobox calling dedicated vendors endpoint.

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
| III. Reuse Existing Backend                    | PASS   | Backend CRUD already built. One backend addition: `GET /api/dynamics/vendors` in existing `DynController` (follows `data-area` pattern, uses existing `VendorsV3.cs` model). Frontend: fix vendor API call to use new endpoint, fix ParentId mapping, add Edit step inline, restructure layout to 2 columns. |
| IV. Vietnamese Comments; Localizable UI Labels | PASS   | Code comments in Vietnamese. UI text in English per FR-017 (spec explicitly requires it).                                                                                     |
| V. Routing & Menu Registration                 | PASS   | Route registered in`RouteResolver.jsx` codeToComponent. Backend menu entry seeded with code + url + permissions. Add/Edit sub-routes in MainRoutes.jsx.                     |

**Post-design re-check (2026-07-03 update 3)**: All principles still PASS. Vendor endpoint `$select` addition is a minor change within the existing `DynController.Vendors()` method (Principle III — reuse existing backend, minimal modification). Appending `$select` to URL after `BuildUrl()` stays within the controller layer (Principle I — thin controller logic). No new dependencies or layer violations.

**Post-design re-check (2026-07-03 update 4)**: All principles still PASS. Conditional versioning stays inside `EutrTemplatesService.UpdateAsync` (Application layer — Principle I); one new repository method (`ReplaceDetailsAsync`) follows the existing `BulkInsertDetailsAsync` pattern (Principle II). Save button relocation, column ratio change, and Back dirty-check are frontend-only, presentation-layer changes reusing the existing `ConfirmDialog` component (Principle II — reference-pattern reuse) instead of introducing a new dialog. No new dependencies or layer violations.

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
│   │   ├── EutrTemplates.cs              # NEW — template entity
│   │   └── EutrTemplateDetails.cs       # NEW — template detail entity
│   └── Dynamics/
│       └── VendorsV3.cs                 # EXISTS — D365 vendor model
├── ComplianceSys.Application/
│   ├── Dtos/
│   │   ├── Request/
│   │   │   ├── EutrTemplatesRequestDto.cs        # NEW
│   │   │   └── EutrTemplateDetailsRequestDto.cs # NEW
│   │   └── Response/
│   │       ├── EutrTemplatesResponseDto.cs       # NEW
│   │       ├── EutrTemplateDetailsResponseDto.cs # NEW
│   │       └── ImportEutrTemplatesResultDto.cs  # NEW
│   ├── Validators/
│   │   └── EutrTemplatesRequestDtoValidator.cs  # NEW
│   ├── Interfaces/
│   │   ├── Services/
│   │   │   ├── IEutrTemplatesService.cs          # NEW
│   │   │   ├── IEutrTemplatesImportService.cs    # NEW
│   │   │   └── IEutrTemplatesExportService.cs    # NEW
│   │   └── Repositories/
│   │       └── IEutrTemplatesRepository.cs       # MODIFY — add ReplaceDetailsAsync for in-place update
│   ├── Services/
│   │   ├── EutrTemplatesService.cs               # MODIFY — conditional versioning (24h threshold) in UpdateAsync
│   │   ├── EutrTemplatesImportService.cs         # NEW — Excel import
│   │   ├── EutrTemplatesExportService.cs         # NEW — Excel export
│   │   └── ComplDynamicsService.cs              # EXISTS — VendorsV3 refType already mapped
│   ├── Mappings/
│   │   └── EutrMappingProfile.cs                # MODIFY — add template mappings
│   └── DependencyInjection.cs                   # MODIFY — register services + validator
├── ComplianceSys.Infrastructure/
│   ├── Repositories/
│   │   └── EutrTemplatesRepository.cs            # MODIFY — add ReplaceDetailsAsync (delete+insert details for in-place update)
│   └── DependencyInjection.cs                   # MODIFY — register repository
└── ComplianceSys.Api/
    └── Controllers/
        ├── EutrTemplatesController.cs           # NEW — REST endpoints
        └── DynController.cs                     # MODIFY — add GET vendors endpoint

compliance-client/src/
├── domain/
│   ├── entities/
│   │   ├── EutrTemplates.js                      # NEW
│   │   └── EutrTemplateDetails.js               # NEW
│   └── interfaces/
│       └── IEutrTemplatesRepository.js          # NEW
├── infrastructure/
│   ├── api/
│   │   ├── eutrTemplatesApi.js                  # NEW
│   │   └── dynamicsApi.js                       # MODIFY — add getVendors method
│   └── repositories/
│       ├── RestEutrTemplatesRepository.js       # NEW
│       └── RestDynamicsRepository.js            # MODIFY — add getVendors method
├── application/
│   └── usecases/
│       └── eutr-templates/
│           ├── CreateEutrTemplatesUseCase.js      # NEW
│           ├── UpdateEutrTemplatesUseCase.js      # NEW
│           ├── DeleteEutrTemplatesUseCase.js      # NEW
│           ├── DeleteMultiEutrTemplatesUseCase.js # NEW
│           ├── GetEutrTemplatesUseCase.js         # NEW
│           ├── GetPagingEutrTemplatesUseCase.js  # NEW
│           ├── ImportEutrTemplatesUseCase.js     # NEW
│           └── ExportEutrTemplatesUseCase.js     # NEW
├── presentation/
│   └── pages/
│       └── eutr-templates/
│           ├── index.jsx                         # NEW — list page (grid)
│           ├── EutrTemplatesAddEdit.jsx          # MODIFY — 2-column layout (widened header/narrowed steps), vendor via GET /api/dynamics/vendors, Save button moved below Default checkbox, Back dirty-check confirm dialog
│           ├── components/
│           │   ├── EutrTemplatesActionCell.jsx   # NEW — row action buttons
│           │   ├── StepTree.jsx                  # MODIFY — add inline Edit step mode
│           │   ├── StepFormRow.jsx               # NEW — add step form
│           │   └── ImportResultDialog.jsx        # NEW — import result display
│           └── hooks/
│               ├── useEutrTemplatesColumns.jsx   # NEW — grid column definitions
│               ├── useEutrTemplatesData.js       # NEW — list data hook
│               ├── useVendors.js                 # NEW — vendor lookup hook (GET /api/dynamics/vendors)
│               └── useStepTree.js                # MODIFY — fix flattenForSave ParentId + add editStep + isDirty tracking for Back warning
├── di/
│   └── repositories.js                           # MODIFY — add eutrTemplates repo
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
| Vendor combobox  | N/A                                  | Dedicated GET /api/dynamics/vendors |
| Tree component   | None                                 | @mui/x-tree-view + @dnd-kit    |
| D365 integration | None                                 | VendorsV3 via dedicated endpoint |
| Back navigation  | Direct navigate                      | Dirty-check confirm dialog if unsaved step changes |

## Complexity Tracking

No constitution violations to justify. All principles pass cleanly.
