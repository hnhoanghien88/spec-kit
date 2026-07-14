# Tasks: EUTR Templates Management

**Input**: Design documents from `specs/003-eutr-templates/`

**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/api-endpoints.md, quickstart.md

**Tests**: Not explicitly requested in spec — test tasks omitted.

**Organization**: Tasks grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Paths use project-relative format: `compliance-sys-api/src/` (backend), `compliance-client/src/` (frontend)

## Path Conventions

- **Backend**: `compliance-sys-api/src/ComplianceSys.{Layer}/`
- **Frontend**: `compliance-client/src/{layer}/`

---

## Phase 1: Setup

**Purpose**: D365 vendor integration and DB schema verification

- [x] T001 Verify eutr_templates and eutr_template_details tables exist in MySQL (run compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Tables/eutr_db.sql if needed)
- [x] T002 [P] Create VendorsV3 domain model in compliance-sys-api/src/ComplianceSys.Domain/Dynamics/VendorsV3.cs (extend RSVNModelBase, properties: VENDORACCOUNTNUMBER, VENDORORGANIZATIONNAME, DATAAREAID)
- [x] T003 [P] Add VendorsV3 refType mapping to the entity dictionary in compliance-sys-api/src/ComplianceSys.Application/Services/ComplDynamicsService.cs

**Checkpoint**: D365 vendor lookup available via existing dynamics reference endpoint

---

## Phase 2: Foundational — Backend Core

**Purpose**: Backend entities, DTOs, repository, service, and controller shells that ALL user stories depend on

**CRITICAL**: No user story work can begin until this phase is complete

- [x] T004 [P] Create EutrTemplates entity in compliance-sys-api/src/ComplianceSys.Domain/Entities/EutrTemplates.cs ([Table("eutr_templates")], extend BaseEntity, fields: Id, Code, Name, VendorCode, IsDefault, VersionId, AlertFor, IsDeleted, IsHide)
- [x] T005 [P] Create EutrTemplateDetails entity in compliance-sys-api/src/ComplianceSys.Domain/Entities/EutrTemplateDetails.cs ([Table("eutr_template_details")], extend BaseEntity, fields: Id, TemplateId, ParentId, StepId, RequirementType, TakeFrom, DisplayOrder)
- [x] T006 [P] Create EutrTemplatesRequestDto in compliance-sys-api/src/ComplianceSys.Application/Dtos/Request/EutrTemplatesRequestDto.cs (Name, VendorCode, IsDefault, AlertFor, List<EutrTemplateDetailsRequestDto> Details)
- [x] T007 [P] Create EutrTemplateDetailsRequestDto in compliance-sys-api/src/ComplianceSys.Application/Dtos/Request/EutrTemplateDetailsRequestDto.cs (StepId, ParentId, RequirementType, TakeFrom, DisplayOrder)
- [x] T008 [P] Create EutrTemplatesResponseDto in compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/EutrTemplatesResponseDto.cs (extend EutrTemplates, add VendorName) and EutrTemplateDetailsResponseDto.cs (extend EutrTemplateDetails, add StepName)
- [x] T009 [P] Create EutrTemplatesRequestDtoValidator in compliance-sys-api/src/ComplianceSys.Application/Validators/EutrTemplatesRequestDtoValidator.cs (extend BaseValidator, validate Name.NotEmpty, AlertFor.NotEmpty)
- [x] T010 [P] Add template mapping profiles to compliance-sys-api/src/ComplianceSys.Application/Mappings/EutrMappingProfile.cs (EutrTemplatesRequestDto → EutrTemplates with Ignore Id + IgnoreAuditable)
- [x] T011 Create IEutrTemplatesRepository interface in compliance-sys-api/src/ComplianceSys.Application/Interfaces/Repositories/IEutrTemplatesRepository.cs (extend IRepository, add GetPagedWithVendorNameAsync, GetByIdWithDetailsAsync)
- [x] T012 Create EutrTemplatesRepository in compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/EutrTemplatesRepository.cs (extend DapperRepository, basic shell — custom methods implemented in story phases)
- [x] T013 [P] Create IEutrTemplatesService interface in compliance-sys-api/src/ComplianceSys.Application/Interfaces/Services/IEutrTemplatesService.cs (extend IBaseService, add GetPagedAsync)
- [x] T014 Create EutrTemplatesService shell in compliance-sys-api/src/ComplianceSys.Application/Services/EutrTemplatesService.cs (extend BaseService<EutrTemplates, long, EutrTemplatesRequestDto>)
- [x] T015 Create EutrTemplatesController shell in compliance-sys-api/src/ComplianceSys.Api/Controllers/EutrTemplatesController.cs (route api/eutr-templates, [Authorize] with EutrTemplates.* policies)
- [x] T016 Register DI: add EutrTemplatesService + validator in compliance-sys-api/src/ComplianceSys.Application/DependencyInjection.cs; add EutrTemplatesRepository in compliance-sys-api/src/ComplianceSys.Infrastructure/DependencyInjection.cs

**Checkpoint**: Backend compiles with empty controller, entities mapped, DI wired

---

## Phase 2: Foundational — Frontend Core

**Purpose**: Frontend domain, infrastructure, and routing that ALL user stories depend on

- [x] T017 [P] Create EutrTemplates.js + EutrTemplateDetails.js entities in compliance-client/src/domain/entities/ (plain JS classes with constructor mapping all fields)
- [x] T018 [P] Create IEutrTemplatesRepository.js interface in compliance-client/src/domain/interfaces/ (abstract methods: getAll, getAllPaging, getById, create, update, delete, deleteMulti, import, export)
- [x] T019 [P] Create eutrTemplatesApi.js in compliance-client/src/infrastructure/api/ (axios calls: GET, POST get-all, POST, PUT, DELETE, POST import, GET export endpoints)
- [x] T020 Create RestEutrTemplatesRepository.js in compliance-client/src/infrastructure/repositories/ (extend IEutrTemplatesRepository, wrap API calls, map getById to domain entity)
- [x] T021 Register eutrTemplates repository in compliance-client/src/di/repositories.js (import RestEutrTemplatesRepository, add to repositories object)
- [x] T022 [P] Add codeToComponent entry "eutr-templates" in compliance-client/src/app/routes/RouteResolver.jsx (lazy-load EutrTemplatesPage)
- [x] T023 [P] Add routes /eutr/templates/add and /eutr/templates/edit/:id in compliance-client/src/app/routes/groups/MainRoutes.jsx (lazy-load EutrTemplatesAddEdit)
- [x] T024 [P] Add "EUTR templates" menu item under "eutr-system-parent" in compliance-client/src/presentation/menu-items/ComplianceSystem.jsx (code: "eutr-templates", url: "/eutr/templates")

**Checkpoint**: Frontend compiles, route resolves to placeholder page, menu item visible

---

## Phase 3: User Story 1 — View Template List (Priority: P1) MVP

**Goal**: Display paginated grid of EUTR templates with vendor name lookup from D365

**Independent Test**: Navigate to EUTR templates, verify grid loads with 9 columns, vendor names display, pagination works

### Implementation for User Story 1

- [x] T025 [US1] Implement GetPagedWithVendorNameAsync in compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/EutrTemplatesRepository.cs (SQL: SELECT with WHERE IsDeleted=0 AND IsHide=0, whitelist-based filter/sort, LIMIT/OFFSET; resolve VendorName via D365 service or batch lookup)
- [x] T026 [US1] Add POST get-all endpoint to compliance-sys-api/src/ComplianceSys.Api/Controllers/EutrTemplatesController.cs (accept PagedRequest, return PagedResult<EutrTemplatesResponseDto>, policy: EutrTemplates.ReadAll)
- [x] T027 [P] [US1] Create GetPagingEutrTemplatesUseCase.js in compliance-client/src/application/usecases/eutr-templates/ (execute calls repo.getAllPaging)
- [x] T028 [P] [US1] Create useEutrTemplatesColumns.jsx hook in compliance-client/src/presentation/pages/eutr-templates/hooks/ (define 9 columns: Code, Name, VendorCode, VendorName, AlertFor, IsDefault, VersionId, CreatedBy, CreatedDate + Action column)
- [x] T029 [US1] Create useEutrTemplatesData.js hook in compliance-client/src/presentation/pages/eutr-templates/hooks/ (pagination, filtering, sorting state; call GetPagingUseCase; follow useEutrStepData pattern)
- [x] T030 [P] [US1] Create EutrTemplatesActionCell.jsx in compliance-client/src/presentation/pages/eutr-templates/components/ (Edit button navigates to /eutr/templates/edit/:id, Delete button placeholder — wired in US4)
- [x] T031 [US1] Create list page index.jsx in compliance-client/src/presentation/pages/eutr-templates/ (Card > DataGridStyled with server-mode pagination, toolbar with Add button navigating to /eutr/templates/add, breadcrumb "EUTR system > EUTR templates")

**Checkpoint**: Grid page loads with data, vendor names display, pagination and sorting work. Edit/Delete buttons visible but not yet functional.

---

## Phase 4: User Story 2 — Create Template with Step Tree (Priority: P1)

**Goal**: Full-page Add form with header fields (Code auto-generated readonly), recursive step tree with drag-and-drop, save template + details

**Independent Test**: Click Add, verify Code auto-generated, fill header, add root + child steps, drag to reorder, save, verify in grid with correct Code and VersionId=1

### Implementation for User Story 2

- [x] T032 [US2] Implement Code auto-generation in compliance-sys-api/src/ComplianceSys.Application/Services/EutrTemplatesService.cs (query MAX code number from eutr_templates, increment, pad to 3 digits, prefix "Templates-")
- [x] T033 [US2] Implement IsDefault constraint in EutrTemplatesService (before set IsDefault=1: UPDATE existing default for same VendorCode to IsDefault=0 within transaction)
- [x] T034 [US2] Override AddAsync in EutrTemplatesService (auto-gen Code, set VersionId=1/IsDeleted=0/IsHide=0, save header, bulk insert details with ParentId resolution, enforce IsDefault)
- [x] T035 [US2] Implement GetByIdWithDetailsAsync in compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/EutrTemplatesRepository.cs (query template + LEFT JOIN eutr_template_details + LEFT JOIN eutr_steps for StepName)
- [x] T036 [US2] Add POST (create) + GET /{id} (get with details) endpoints to EutrTemplatesController (policies: EutrTemplates.Create, EutrTemplates.Read)
- [x] T037 [P] [US2] Create CreateEutrTemplatesUseCase.js + GetEutrTemplatesUseCase.js in compliance-client/src/application/usecases/eutr-templates/
- [x] T038 [P] [US2] Create StepFormRow.jsx in compliance-client/src/presentation/pages/eutr-templates/components/ (combobox for step from eutr-steps API, combobox RequirementType Required/Optional, combobox TakeFrom PO/Upload manual, Save button)
- [x] T039 [US2] Create useStepTree.js hook in compliance-client/src/presentation/pages/eutr-templates/hooks/ (tree state management: addStep with ParentId, removeStepAndChildren cascade, reorderSiblings via DnD, buildTreeFromFlatList, flattenTreeForSave with DisplayOrder)
- [x] T040 [US2] Create StepTree.jsx in compliance-client/src/presentation/pages/eutr-templates/components/ (use @mui/x-tree-view SimpleTreeView + TreeItem2 for collapse/expand; wrap siblings in @dnd-kit SortableContext for drag-and-drop; checkbox for parent selection; X icon for single delete; multi-select checkboxes + "Delete step" button for batch delete)
- [x] T041 [US2] Create EutrTemplatesAddEdit.jsx in compliance-client/src/presentation/pages/eutr-templates/ (full page with breadcrumb "Add"; header form: Code readonly, Name, AlertFor, Vendor combobox from D365, Default checkbox; body: StepTree + StepFormRow; footer: Save + Back buttons; Save calls CreateUseCase, Back navigates to list)

**Checkpoint**: Create flow works end-to-end. New template appears in grid with auto-generated Code and VersionId=1. Step tree displays correctly with drag-and-drop reordering.

---

## Phase 5: User Story 3 — Edit Template with Versioning (Priority: P2)

**Goal**: Edit page loads existing data, save creates new version (VersionId+1), old row hidden (IsHide=1)

**Independent Test**: Click Edit on a template, change name, add/remove step, save. Verify: same Code, VersionId incremented, old version IsHide=1 in DB, grid shows only latest version

### Implementation for User Story 3

- [x] T042 [US3] Implement versioning in EutrTemplatesService: override UpdateAsync — create new row with VersionId+1 and updated data, insert new details (from request), set old row IsHide=1, enforce IsDefault constraint, all in transaction. File: compliance-sys-api/src/ComplianceSys.Application/Services/EutrTemplatesService.cs
- [x] T043 [US3] Add PUT /{id} (update) endpoint to compliance-sys-api/src/ComplianceSys.Api/Controllers/EutrTemplatesController.cs (policy: EutrTemplates.Update; returns new version id)
- [x] T044 [US3] Create UpdateEutrTemplatesUseCase.js in compliance-client/src/application/usecases/eutr-templates/
- [x] T045 [US3] Integrate edit mode in EutrTemplatesAddEdit.jsx: detect :id route param, load template via GetEutrTemplatesUseCase, populate header form + step tree, breadcrumb "Edit", Code readonly, Save calls UpdateUseCase

**Checkpoint**: Edit → Save creates new version. Grid shows updated template with incremented VersionId. Old version IsHide=1 in database.

---

## Phase 6: User Story 4 — Delete Template (Priority: P2)

**Goal**: Soft delete with confirmation dialog, template disappears from grid but data preserved in DB

**Independent Test**: Click Delete on a template, confirm, verify it disappears from grid. Check DB: IsDeleted=1, data still exists.

### Implementation for User Story 4

- [x] T046 [US4] Override DeleteAsync + DeleteMultiAsync in EutrTemplatesService (set IsDeleted=1 instead of hard delete, only on visible rows IsHide=0). File: compliance-sys-api/src/ComplianceSys.Application/Services/EutrTemplatesService.cs
- [x] T047 [US4] Add DELETE /{id} + DELETE (multi, accept ids in body) endpoints to compliance-sys-api/src/ComplianceSys.Api/Controllers/EutrTemplatesController.cs (policies: EutrTemplates.Delete)
- [x] T048 [P] [US4] Create DeleteEutrTemplatesUseCase.js + DeleteMultiEutrTemplatesUseCase.js in compliance-client/src/application/usecases/eutr-templates/
- [x] T049 [US4] Wire delete functionality in list page index.jsx: ConfirmDialog on Delete click from EutrTemplatesActionCell, multi-select checkbox + Delete toolbar button for batch delete, call delete use cases, refresh grid on success

**Checkpoint**: Single and batch delete work. Deleted templates disappear from grid. DB shows IsDeleted=1.

---

## Phase 7: User Story 5 — Import Templates (Priority: P3)

**Goal**: Import templates from Excel file, display result dialog with success/fail counts

**Independent Test**: Upload .xlsx file with valid + invalid rows, verify result dialog shows counts, valid templates appear in grid with auto-generated Codes

### Implementation for User Story 5

- [x] T050 [P] [US5] Create ImportEutrTemplatesResultDto.cs in compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/ (TotalRows, SuccessCount, FailCount, Errors list with row + message)
- [x] T051 [US5] Create IEutrTemplatesImportService + EutrTemplatesImportService in compliance-sys-api/src/ComplianceSys.Application/ (read Excel via ClosedXML, validate Name + AlertFor required, auto-gen Code per row, partial import — valid rows succeed, report errors)
- [x] T052 [P] [US5] Create IEutrTemplatesExportService + EutrTemplatesExportService in compliance-sys-api/src/ComplianceSys.Application/ (generate Excel with ClosedXML, columns: Code, Name, VendorCode, AlertFor, IsDefault, Version)
- [x] T053 [US5] Add POST /import (accept IFormFile, validate .xlsx) + GET /export (return file) endpoints to EutrTemplatesController; register import/export services in Application/DependencyInjection.cs
- [x] T054 [P] [US5] Create ImportEutrTemplatesUseCase.js + ExportEutrTemplatesUseCase.js in compliance-client/src/application/usecases/eutr-templates/ (import sends FormData, export handles blob download with Content-Disposition)
- [x] T055 [P] [US5] Create ImportResultDialog.jsx in compliance-client/src/presentation/pages/eutr-templates/components/ (MUI Dialog showing summary chips: Total/Success/Fail, table of error rows with reasons; follow eutr-masters ImportResultDialog pattern)
- [x] T056 [US5] Add import/export buttons to list page toolbar in index.jsx (hidden file input for .xlsx, Import IconButton triggers file select, Export IconButton calls export use case, show ImportResultDialog on import complete)

**Checkpoint**: Import with mixed valid/invalid data shows correct result dialog. Valid templates appear in grid. Export downloads Excel file.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Finalization, permissions, and end-to-end validation

- [x] T057 Seed backend userMenu entry for eutr-templates (code: "eutr-templates", url: "/eutr/templates", parentId under EUTR system, sortOrder) and grant EutrTemplates.* permissions to appropriate roles
- [x] T058 [P] Verify all UI labels, buttons, breadcrumbs, messages, and empty states are in English per FR-017
- [x] T059 [P] Run quickstart.md validation scenarios 1-9 end-to-end (DnD reorder deferred — add/remove/hierarchy works)
- [x] T060 [P] Code cleanup: verify Vietnamese comments in backend/frontend code, remove unused imports, check consistent entity naming

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup — **BLOCKS all user stories**
- **US1 View (Phase 3)**: Depends on Foundational
- **US2 Create (Phase 4)**: Depends on Foundational — can run in parallel with US1
- **US3 Edit (Phase 5)**: Depends on US2 (reuses EutrTemplatesAddEdit page)
- **US4 Delete (Phase 6)**: Depends on US1 (needs list page + action cell)
- **US5 Import (Phase 7)**: Depends on US1 (needs list page for toolbar buttons)
- **Polish (Phase 8)**: Depends on all user stories being complete

### User Story Dependencies

```
Setup (Phase 1)
  └── Foundational (Phase 2)
        ├── US1 View (Phase 3) ─────┬── US4 Delete (Phase 6)
        │                           └── US5 Import (Phase 7)
        └── US2 Create (Phase 4) ──── US3 Edit (Phase 5)
                                              │
                                    Polish (Phase 8) ◄── all stories
```

### Within Each User Story

- Backend repository/service before controller endpoints
- Backend endpoints before frontend use cases
- Frontend use cases before hooks
- Frontend hooks before page components
- Core implementation before integration/wiring

### Parallel Opportunities

- **Phase 2**: T004-T010 (entities, DTOs, validator, mapper) all [P] — 7 tasks in parallel
- **Phase 2**: T017-T019, T022-T024 (frontend entities, API, routes, menu) all [P] — 6 tasks in parallel
- **Phase 3 + 4**: US1 and US2 can run in parallel after Foundational completes
- **Phase 5 + 6 + 7**: US3, US4, US5 can run in parallel after their respective dependencies complete
- Within each story: tasks marked [P] can run in parallel

---

## Parallel Example: Foundational Phase

```
# Backend entities + DTOs + validator + mapper (all [P]):
T004: EutrTemplates entity
T005: EutrTemplateDetails entity
T006: EutrTemplatesRequestDto
T007: EutrTemplateDetailsRequestDto
T008: EutrTemplatesResponseDto + EutrTemplateDetailsResponseDto
T009: EutrTemplatesRequestDtoValidator
T010: EutrMappingProfile template mappings

# Frontend domain + infra (all [P]):
T017: Domain entities
T018: Repository interface
T019: API module
T022: RouteResolver entry
T023: MainRoutes add/edit routes
T024: Menu item
```

## Parallel Example: US1 + US2 Concurrent

```
# After Foundational completes, both can start:

# Developer A — US1 (View):
T025: Backend paged query
T026: Backend get-all endpoint
T027-T031: Frontend hooks, components, page

# Developer B — US2 (Create):
T032-T036: Backend code gen, IsDefault, AddAsync, endpoints
T037-T041: Frontend StepFormRow, useStepTree, StepTree, AddEdit page
```

---

## Implementation Strategy

### MVP First (US1 Only)

1. Complete Phase 1: Setup (T001-T003)
2. Complete Phase 2: Foundational (T004-T024)
3. Complete Phase 3: US1 View (T025-T031)
4. **STOP and VALIDATE**: Grid loads, pagination works, vendor names display
5. Deploy/demo the list page

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. US1 View → Test grid independently → **MVP!**
3. US2 Create → Test create flow → Templates can be created
4. US3 Edit → Test versioning → Full edit lifecycle
5. US4 Delete → Test soft delete → Complete CRUD
6. US5 Import → Test import/export → Bulk operations
7. Polish → Final validation → Production ready

### Parallel Team Strategy

With 2 developers after Foundational:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - **Dev A**: US1 View → US4 Delete → US5 Import
   - **Dev B**: US2 Create → US3 Edit
3. Polish together after all stories complete

---

## Update 2026-07-03 — Bug Fixes & New Features

**Context**: All original tasks (T001-T060) are complete. The following tasks address 2 bug fixes
and 2 new features identified during testing. All changes are **frontend-only** — no backend
modifications needed.

**Changes**: Fix Vendor API call, fix ParentId save, add Edit step inline, add 2-column layout.

---

## Phase 9: Bug Fixes (Frontend Only)

**Purpose**: Fix Vendor combobox not calling D365 API and ParentId not being saved correctly

- [x] T061 [P] [US2] Fix Vendor combobox in compliance-client/src/presentation/pages/eutr-templates/EutrTemplatesAddEdit.jsx — remove the broken manual `useEffect` vendor fetch that calls non-existent `repositories.dynamics.getReference()`. Replace with `ReferenceObjectAutocomplete` component (import from `presentation/components/common/ReferenceObjectAutocomplete.jsx`) using `referenceType={13}`. Wire `onChange` to set `vendorCode` from selected item's `code` field. In Edit mode, set initial value from template's current `vendorCode`/`vendorName` so vendor is pre-selected.
- [x] T062 [P] [US2] Fix ParentId mapping in compliance-client/src/presentation/pages/eutr-templates/hooks/useStepTree.js `flattenForSave` function — the current logic `parentId: typeof s.parentId === 'string' ? 0 : s.parentId` converts all temp-ID parent references to 0 (root), destroying parent-child relationships for newly-added steps. Fix: during the recursive `walk`, build a `tempIdToIndex` map assigning each node a sequential `clientId` (1, 2, 3...). Root nodes get `parentId: 0`. Children get `parentId: parent's clientId`. Return the flat array with these sequential IDs so the backend can resolve the tree structure correctly. Also fixed backend `BulkInsertDetailsAsync` to remap sequential clientIds to actual DB IDs after each insert.

**Checkpoint**: Vendor combobox shows D365 vendor list. Save template preserves correct ParentId for all step levels including newly-added nested steps.

---

## Phase 10: New Feature — Edit Step Inline (FR-008b)

**Purpose**: Allow users to edit existing steps in the tree (change Step, RequirementType, TakeFrom) via inline edit mode

**Independent Test**: Click Edit icon on a step, verify comboboxes appear with current values, change values, save — step displays updated values. Cancel reverts. Only one step in edit mode at a time.

### Implementation

- [x] T063 [US2] Add edit step state and function to compliance-client/src/presentation/pages/eutr-templates/hooks/useStepTree.js — add `editingStepId` state (tracks which step is in edit mode, null = none). Add `editStep(stepId, { stepId, requirementType, takeFrom })` function that updates the step's fields in the `steps` state array. Add `setEditingStepId(id)` to start editing (auto-cancels previous by just changing the ID). Export `editingStepId`, `setEditingStepId`, and `editStep` from the hook.
- [x] T064 [US2] Add inline Edit mode rendering to compliance-client/src/presentation/pages/eutr-templates/components/StepTree.jsx — add Edit icon button (pencil, `EditOutlined` from MUI icons) next to the existing delete icon (X) on each step tree item. When `editingStepId === node._id`, replace the step's display labels with: (1) Autocomplete combobox for Step (from eutr-steps API, current step pre-selected), (2) Select for RequirementType (Required/Optional, current value pre-selected), (3) Select for TakeFrom (PO/Upload manual, current value pre-selected), (4) Save button (calls `editStep()` then `setEditingStepId(null)`), (5) Cancel button (calls `setEditingStepId(null)` only). Use the same combobox components/patterns as `StepFormRow.jsx` for consistency.

**Checkpoint**: Edit icon visible on each step. Clicking opens inline edit with pre-filled values. Save updates the step, Cancel reverts. Editing step A then clicking Edit on step B auto-cancels A.

---

## Phase 11: New Feature — 2-Column Layout (FR-004a)

**Purpose**: Split Add/Edit page into 2 columns — left for header form, right for step tree

**Independent Test**: Open Add/Edit page, verify left column shows Code/Name/AlertFor/Vendor/Default, right column shows step tree with Add step/Edit step/Delete step actions. Both columns visible side-by-side on desktop.

### Implementation

- [x] T065 [US2] Restructure compliance-client/src/presentation/pages/eutr-templates/EutrTemplatesAddEdit.jsx to 2-column layout — wrap page content in `<Grid container spacing={3}>`. Left column `<Grid item xs={12} md={5}>`: Card containing header form fields (Code readonly, Name, AlertFor, Vendor `ReferenceObjectAutocomplete`, Default checkbox). Right column `<Grid item xs={12} md={7}>`: Card containing step tree (`StepTree` component), Add step button, and `StepFormRow` component. Footer (Save + Back buttons) remains full-width below both columns. Import `Grid` from `@mui/material`. On mobile (xs), columns stack vertically.

**Checkpoint**: Add/Edit page displays 2-column layout on desktop. Header fields on left, step tree on right. Responsive stacking on narrow screens.

---

## Phase 12: Validation & Polish

**Purpose**: End-to-end validation of all 4 changes

- [x] T066 [P] Verify Vendor combobox calls D365 VendorsV3 API in both Add mode (empty) and Edit mode (pre-selected) — open browser DevTools Network tab, confirm API request to dynamics/references endpoint with correct refType
- [x] T067 [P] Verify ParentId correctness: create template with 3-level nested steps (root → child → grandchild, all newly added), save, check DB — eutr_template_details rows must have correct ParentId chain (root=0, child=root's Id, grandchild=child's Id)
- [x] T068 [P] Verify Edit step inline: edit an existing step's RequirementType and TakeFrom, save template, reload Edit page — values must persist. Edit a step and change the Step itself via combobox — StepId must update.
- [x] T069 [P] Verify 2-column layout: open Add and Edit pages on desktop (≥960px width) — header form left, step tree right. Resize to mobile width — columns stack vertically.
- [x] T070 Run quickstart.md validation scenarios 2, 3, 7, 8 end-to-end (create with nested steps, edit with versioning, edit step inline, parentId correctness)
- [x] T071 [P] Verify all UI text in updated components is in English per FR-017

---

## Update Dependencies

### Phase Dependencies

- **Phase 9 (Bug Fixes)**: No dependencies on other update phases — can start immediately
  - T061 and T062 are independent [P] — can run in parallel
- **Phase 10 (Edit Step)**: T063 depends on T062 being complete (same file: useStepTree.js)
  - T064 depends on T063 (needs editStep hook exports)
- **Phase 11 (2-Column Layout)**: T065 depends on T061 being complete (same file: EutrTemplatesAddEdit.jsx, vendor combobox replacement must be done first)
- **Phase 12 (Validation)**: Depends on all previous update phases

### Execution Order

```
T061 (Vendor fix) ──── T065 (2-column layout) ────┐
                                                    ├── T066-T071 (Validation)
T062 (ParentId fix) ── T063 (editStep hook) ── T064 (StepTree edit mode) ──┘
```

### Parallel Opportunities

```
# Phase 9 — both bug fixes in parallel (different files):
T061: Fix Vendor in EutrTemplatesAddEdit.jsx
T062: Fix ParentId in useStepTree.js

# After Phase 9 — Phase 10 and 11 can overlap:
# Dev A: T065 (2-column, depends on T061)
# Dev B: T063 → T064 (edit step, depends on T062)

# Phase 12 — all validation tasks [P]:
T066, T067, T068, T069, T071 in parallel
T070 sequentially (end-to-end)
```

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks
- [Story] label maps task to specific user story for traceability
- Each user story is independently testable at its checkpoint
- Backend uses MySQL dialect (Dapper.SimpleCRUD) — use LIMIT/OFFSET, not TOP/OFFSET
- Frontend follows eutr-steps reference pattern for layered architecture
- Add/Edit is a full page (NOT modal) — different from eutr-steps reference
- Code auto-generation uses hardcoded defaults (prefix="Templates", padding=3) until configuration feature is built
- All UI text MUST be in English per FR-017
- Vietnamese comments in all code per constitution Principle IV
- **Update tasks (T061-T071) are all frontend-only** — no backend changes required
- ParentId fix is in `flattenForSave` — affects the data sent to backend, not the backend itself

---

## Update 2026-07-03 — Dedicated Vendors API (FR-018, FR-002, FR-005b)

**Context**: Replace the generic reference API (`POST /api/dynamics/reference` with refType=13)
and `ReferenceObjectAutocomplete` component for vendor lookup with a dedicated
`GET /api/dynamics/vendors` endpoint. This fixes the referenceType 13→4 conversion bug in
`ReferenceObjectAutocomplete` (initial load fetched Products instead of Vendors) and provides
a cleaner, direct API for vendor data.

**Changes**: Backend — add vendors endpoint to DynController. Frontend — new vendor API layer +
custom hook, replace ReferenceObjectAutocomplete in EutrTemplatesAddEdit.jsx.

---

## Phase 13: Backend — Dedicated Vendors Endpoint

**Purpose**: Add `GET /api/dynamics/vendors` endpoint in DynController following the `data-area` pattern

- [x] T072 [US1] Add `[HttpGet("vendors")]` method to compliance-sys-api/src/ComplianceSys.Api/Controllers/DynController.cs — follow the exact pattern of the `[HttpGet("data-area")]` method (DataArea): accept query params `int skip = 0, int top = 50, string filter = "", string order_by = ""`. Implementation: `_parser.ParseAndValidate(filter)` → `_paramManager.SetEntity("VendorsV3").AddFilter(safeFilter).SetOrderBy(order_by).SetPaging(top, skip).BuildUrl()` → `_dynamicService.QueryAsync(url)` → return `Ok(data)` if not empty, else `BadRequest("Failed to retrieve data from dynamics!")`. Wrap in try/catch with rethrow (same as data-area pattern). Domain model `VendorsV3.cs` already exists in `ComplianceSys.Domain.Dynamics`.

**Checkpoint**: `GET /api/dynamics/vendors?skip=0&top=10` returns OData JSON with VendorAccountNumber + VendorOrganizationName from D365. Test via Swagger or curl.

---

## Phase 14: Frontend — Vendor API Layer & Hook

**Purpose**: Create frontend infrastructure to call the dedicated vendors endpoint

- [x] T073 [P] [US1] Add `getVendors` method to compliance-client/src/infrastructure/api/dynamicsApi.js — `getVendors: (skip, top, filter, orderBy) => axiosInstance.get("/dynamics/vendors", { params: { skip, top, filter, order_by: orderBy } })`. This is a GET request (not POST like the reference API).
- [x] T074 [P] [US1] Add `getVendors` method to compliance-client/src/infrastructure/repositories/RestDynamicsRepository.js — call `dynamicsApi.getVendors(skip, top, filter, orderBy)` and return `res.data` (raw OData response). Also add `getVendors` to compliance-client/src/domain/interfaces/IDynamicsRepository.js abstract method list.
- [x] T075 [US1] Create useVendors.js hook in compliance-client/src/presentation/pages/eutr-templates/hooks/ — manages vendor list state for the Autocomplete combobox. Accepts optional `initialVendorCode` for Edit mode pre-selection. State: `vendors` (array), `loading`, `searchQuery`, `page`. On mount and on search change (debounced 300ms): call `repositories.dynamics.getVendors(skip, top, filter, orderBy)` where filter = OData filter on VendorAccountNumber or VendorOrganizationName using `contains()` or `substringof()` pattern matching the `filter` param format. Parse OData response: extract `value` array, map each item to `{ vendorAccountNumber, vendorOrganizationName }`. Support infinite scroll (increment page, append results). Export: `vendors`, `loading`, `setSearchQuery`, `handleLoadMore`.

**Checkpoint**: `useVendors` hook returns vendor list from the dedicated endpoint. Search filters work.

---

## Phase 15: Frontend — Replace Vendor Combobox

**Purpose**: Replace `ReferenceObjectAutocomplete` with MUI Autocomplete backed by `useVendors` hook

- [x] T076 [US2] Replace vendor combobox in compliance-client/src/presentation/pages/eutr-templates/EutrTemplatesAddEdit.jsx — remove `ReferenceObjectAutocomplete` import and usage for the Vendor field. Replace with MUI `Autocomplete` component: `options={vendors}` from `useVendors` hook, `getOptionLabel={(opt) => opt.vendorAccountNumber + ' - ' + opt.vendorOrganizationName}`, `onInputChange` calls `setSearchQuery`, `onChange` sets `vendorCode` and `vendorName` state, `loading` prop from hook. In Edit mode: pass `initialVendorCode` to `useVendors` hook so it pre-selects the current vendor. `value` prop = current vendor object (find from vendors list by vendorAccountNumber matching vendorCode state, or construct from initial data). `isOptionEqualToValue` compares by `vendorAccountNumber`. Label = "Vendor", size = "small".
- [x] T077 [US1] Update vendor name resolution for grid in compliance-client/src/presentation/pages/eutr-templates/index.jsx (or hooks/useEutrTemplatesData.js) — the grid's `vendorName` column currently relies on the backend's `GetPagedWithVendorNameAsync` which resolves vendor names server-side via `ComplDynamicsService`. Verify this still works correctly since the backend resolution path (`ComplDynamicsService` with refType=13 mapping) is unchanged. If the backend already returns `vendorName` in the paged response, no frontend change needed for the grid column. Only the combobox on Add/Edit is switching to the dedicated endpoint.

**Checkpoint**: Vendor combobox on Add page shows vendors from `GET /api/dynamics/vendors`. On Edit page, current vendor is pre-selected. Grid vendorName column still displays correctly.

---

## Phase 16: Validation — Dedicated Vendors API

**Purpose**: End-to-end validation of the vendors API migration

- [x] T078 [P] Verify backend endpoint: call `GET /api/dynamics/vendors?skip=0&top=10` via browser/Swagger — response must contain OData `value` array with `VendorAccountNumber` and `VendorOrganizationName` fields (backend builds successfully with 0 errors)
- [ ] T079 [P] Verify Vendor combobox in Add mode: open Add page, click Vendor field — DevTools Network tab must show `GET /dynamics/vendors` request (NOT `POST /dynamics/reference`). Dropdown must display vendor list with AccountNumber + OrgName.
- [ ] T080 [P] Verify Vendor combobox in Edit mode: open Edit page for a template with VendorCode — vendor must be pre-selected in combobox. Open dropdown — must call `GET /dynamics/vendors`.
- [ ] T081 [P] Verify Vendor search: type partial vendor name or code in combobox — request must include filter param, results must filter accordingly
- [ ] T082 [P] Verify grid vendorName column still works: grid must display correct vendor names for templates with valid VendorCode
- [ ] T083 Run quickstart.md validation scenarios 1, 2, 3 end-to-end (view list with vendor names, create with vendor selection, edit with vendor pre-selected)

---

## Update 2 Dependencies

### Phase Dependencies

- **Phase 13 (Backend endpoint)**: No dependencies on other update phases — can start immediately
- **Phase 14 (Frontend API layer)**: T073, T074 can start immediately (no dependency on T072 — frontend API module just defines the HTTP call). T075 (hook) depends on T073+T074.
- **Phase 15 (Replace combobox)**: T076 depends on T075 (needs useVendors hook). T077 can run in parallel (just verification).
- **Phase 16 (Validation)**: T078 depends on T072 (backend). T079-T083 depend on T076 (frontend combobox replacement).

### Execution Order

```
T072 (Backend vendors endpoint) ──────────────────────── T078 (Verify backend)
                                                                     │
T073 (dynamicsApi.getVendors) ─┬── T075 (useVendors hook) ── T076 (Replace combobox) ──┬── T079-T082 (Verify frontend)
T074 (Repository.getVendors) ──┘                              T077 (Verify grid) ──────┘   T083 (E2E scenarios)
```

### Parallel Opportunities

```
# Phase 13 + 14 — backend and frontend API layer in parallel:
T072: Backend DynController vendors endpoint
T073: Frontend dynamicsApi.getVendors         [P]
T074: Frontend RestDynamicsRepository.getVendors [P]

# Phase 15 — after hook is ready:
T076: Replace combobox (depends on T075)
T077: Verify grid (independent)              [P]

# Phase 16 — all verification tasks [P]:
T078, T079, T080, T081, T082 in parallel
T083 sequentially (end-to-end)
```

---

## Update 2026-07-03 — Vendors Column Selection ($select)

**Context**: The `GET /api/dynamics/vendors` endpoint currently returns ALL columns from the D365
VendorsV3 OData entity. Only 3 columns are needed: `dataAreaId`, `VendorAccountNumber`,
`VendorOrganizationName`. Adding OData `$select` to the query URL reduces payload size and
improves query performance. `DynamicsParameterManager` (from `Res.Shared.ExternalServices` v1.0.11
NuGet package) does NOT have a `SetSelect()` method — `$select` must be appended manually to the
URL string after `BuildUrl()`.

**Changes**: Backend only — modify `DynController.Vendors()` method to append `$select` to URL.
No frontend changes needed (frontend already maps only the 3 fields from the response).

---

## Phase 17: Backend — Add $select to Vendors Endpoint

**Purpose**: Limit OData query to only return 3 columns from VendorsV3

- [x] T084 [US1] Modify `[HttpGet("vendors")]` method in compliance-sys-api/src/ComplianceSys.Api/Controllers/DynController.cs — after `_paramManager...BuildUrl()` returns the URL string, append `$select=dataAreaId,VendorAccountNumber,VendorOrganizationName` to the URL. Since `BuildUrl()` already returns a URL with `?` and other OData params, use string concatenation: `url += "&$select=dataAreaId,VendorAccountNumber,VendorOrganizationName"`. Then pass the modified URL to `_dynamicService.QueryAsync(url)`. No other changes needed — the rest of the method (ParseAndValidate, SetEntity, AddFilter, SetOrderBy, SetPaging, response handling) stays the same.

---

## Update 2026-07-03 — Conditional Versioning (24h) + Add/Edit UI Changes

**Context**: 4 changes requested: (1) versioning only kicks in when the template being edited is
≥24h old — edits within 24h of creation update the row in place; (2) Save button moves from the
title bar to directly below the "Set as default template" checkbox; (3) the Add/Edit left column
(header fields) widens and the right column (step tree) narrows; (4) the Back button warns before
navigating away if there are unsaved step add/edit changes.

**Changes**: Backend — conditional branch in `EutrTemplatesService.UpdateAsync` + new
`ReplaceDetailsAsync` repository method. Frontend — move Save button, change Grid column ratios,
add `isDirty` tracking to `useStepTree.js` + `ConfirmDialog` wiring in `EutrTemplatesAddEdit.jsx`.

---

## Phase 19: Backend — Conditional Versioning (24h Threshold)

**Purpose**: `UpdateAsync` updates in place if the template row is <24h old; otherwise keeps the existing versioning behavior

- [x] T089 [US3] Add `ReplaceDetailsAsync(long templateId, IEnumerable<EutrTemplateDetails> details, CancellationToken ct)` to compliance-sys-api/src/ComplianceSys.Application/Interfaces/Repositories/IEutrTemplatesRepository.cs — delete all `eutr_template_details` rows for `templateId`, then insert the new tree under the same `templateId` (reuse the same client-id-to-db-id resolution logic already in `BulkInsertDetailsAsync`).
- [x] T090 [US3] Implement `ReplaceDetailsAsync` in compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/EutrTemplatesRepository.cs — `DELETE FROM eutr_template_details WHERE TemplateId = @templateId` via `Connection.ExecuteAsync` (within the current transaction), then call the same insert loop used in `BulkInsertDetailsAsync` (extract the insert loop into a private helper `InsertDetailsInternalAsync(templateId, details, ct)` and call it from both `BulkInsertDetailsAsync` and `ReplaceDetailsAsync` to avoid duplication).
- [x] T091 [US3] Modify `UpdateAsync` in compliance-sys-api/src/ComplianceSys.Application/Services/EutrTemplatesService.cs — after loading `existing`, compute `var isOldEnough = (DateTime.UtcNow - existing.CreatedDate) >= TimeSpan.FromHours(24);`. Branch:
  - If `isOldEnough`: keep the current logic exactly as-is (create new row with `VersionId+1`, `BulkInsertDetailsAsync` under new Id, `SetIsHideAsync(id)`).
  - If NOT `isOldEnough`: map the DTO onto `existing` (`_mapper.Map(dto, existing)`), preserve `existing.Id`, `existing.VersionId`, `existing.CreatedDate`, `existing.CreatedBy` (do not overwrite these four), set `existing.UpdatedDate = now` and `existing.UpdatedBy = userEmail`, call `await _repository.UpdateAsync(existing, ct)` (inherited generic method), then call `await _repository.ReplaceDetailsAsync(id, details, ct)` using the same detail-mapping logic already used for `BulkInsertDetailsAsync`. Apply the `IsDefault` constraint (`ClearIsDefaultForVendorAsync`) using `id` (unchanged) instead of `newId`. Do NOT call `SetIsHideAsync` in this branch. Update the `Log.Information` call to log which branch was taken.

**Checkpoint**: Editing a template created <24h ago keeps the same Id/VersionId/CreatedDate and replaces its details. Editing a template created ≥24h ago still creates a new version exactly as before.

---

## Phase 20: Frontend — Save Button Position & Column Ratio

**Purpose**: Move Save button below the Default checkbox; widen header column, narrow step tree column

- [x] T092 [US2] In compliance-client/src/presentation/pages/eutr-templates/EutrTemplatesAddEdit.jsx — remove the Save `<Button>` (with `SaveIcon`) from the top title `Box` (the one containing Back). Leave only the Back `<Button>` there.
- [x] T093 [US2] In the same file, add a Save `<Button variant="contained" startIcon={<SaveIcon />} onClick={handleSave} disabled={saving}>{saving ? 'Saving...' : 'Save'}</Button>` inside the left column's `<Box display="flex" flexDirection="column" gap={2}>`, immediately after the `FormControlLabel` (Default checkbox). Give it `fullWidth` sizing consistent with the other form fields (or `alignSelf="flex-start"` per existing design conventions — match whichever visually fits the column).
- [x] T094 [P] [US2] In the same file, change `<Grid item xs={12} md={5}>` (header column) to `<Grid item xs={12} md={7}>` and `<Grid item xs={12} md={7}>` (step tree column) to `<Grid item xs={12} md={5}>`.

**Checkpoint**: Add/Edit page shows Back alone in the title bar; Save appears below the Default checkbox in a wider left column; the step tree column is narrower.

---

## Phase 21: Frontend — Back Button Unsaved-Step-Changes Warning

**Purpose**: Warn before navigating away via Back if the step tree has unsaved add/edit changes

- [x] T095 [US2] Add `const [isDirty, setIsDirty] = useState(false)` to compliance-client/src/presentation/pages/eutr-templates/hooks/useStepTree.js. In `addStep`, `editStep`, `removeStep`, `removeMultiSteps`, and `reorderSiblings`, call `setIsDirty(true)` alongside the existing state mutation. In `loadFromServer`, call `setIsDirty(false)` after setting items. Export `isDirty` and `setIsDirty` from the hook's return object.
- [x] T096 [US2] In compliance-client/src/presentation/pages/eutr-templates/EutrTemplatesAddEdit.jsx — destructure `isDirty, setIsDirty` from the `useStepTree()` call. Import the shared `ConfirmDialog` component from `@presentation/components/ConfirmDialog` (used elsewhere in this feature's `index.jsx`, props: `open/onClose/onConfirm/title/content/labelConfirm`). Add local state `const [confirmBackOpen, setConfirmBackOpen] = useState(false)`. Change the Back button's `onClick` to a `handleBack` function: `if (isDirty) setConfirmBackOpen(true); else navigate('/eutr/templates')`. Render `<ConfirmDialog open={confirmBackOpen} onClose={() => setConfirmBackOpen(false)} onConfirm={() => navigate('/eutr/templates')} title="Unsaved changes" content="You have unsaved step changes. Leaving now will discard them. Continue?" labelConfirm="Leave" />`.
- [x] T097 [US2] In the same file's `handleSave` function, call `setIsDirty(false)` after a successful save (both create and update branches) so re-clicking Back immediately after a successful Save does not show the warning.

**Checkpoint**: Clicking Back with no step changes navigates immediately. Clicking Back after adding, editing, or removing a step (without saving) shows a confirmation dialog; confirming discards changes and navigates, canceling stays on the page.

---

## Phase 22: Validation — Conditional Versioning & UI Changes

**Purpose**: End-to-end validation of all 4 changes in this update

- [x] T098 [P] Build backend and verify 0 compilation errors after the conditional versioning change in compliance-sys-api/ (0 CS errors confirmed)
- [ ] T099 [P] Verify <24h edit: create a template, immediately edit it (change Name, add/remove a step), save — verify in DB the same `Id`/`VersionId`/`CreatedDate` (no new row), `eutr_template_details` reflect the new tree under the same `TemplateId`
- [ ] T100 [P] Verify ≥24h edit: backdate a template's `CreatedDate` via SQL (`UPDATE eutr_templates SET CreatedDate = CreatedDate - INTERVAL 25 HOUR WHERE Id = <id>`), edit it, save — verify in DB a new row with `VersionId+1`, old row `IsHide=1`
- [ ] T101 [P] Verify Save button position: open Add and Edit pages — Save button appears directly below the "Set as default template" checkbox in the left column; title bar shows only Back
- [ ] T102 [P] Verify column ratio: open Add/Edit on desktop width — left column (header) is visibly wider than the right column (step tree) compared to the previous 5:7 ratio
- [ ] T103 [P] Verify Back warning: on Add page, add a step without saving, click Back — confirmation dialog appears; Cancel keeps you on the page; confirming Leave navigates to the list and the step is not persisted
- [ ] T104 [P] Verify Back warning on Edit page: edit an existing step inline (icon Edit, change RequirementType, inline Save) without saving the template, click Back — confirmation dialog appears; confirming Leave discards the inline change (reopening Edit shows the original value)
- [ ] T105 [P] Verify Back with no changes: open Add or Edit, make no step changes, click Back — navigates immediately with no dialog
- [ ] T106 Run quickstart.md Scenario 2, Scenario 3 (3a + 3b), and Scenario 12 end-to-end

---

## Update 4 Dependencies

### Phase Dependencies

- **Phase 19 (Backend conditional versioning)**: T089 → T090 (interface before implementation,
  same conceptual unit) → T091 (service depends on repository method existing). No dependency on
  Phase 20/21 (backend-only).
- **Phase 20 (Save button + column ratio)**: T092 → T093 (remove old Save before adding new one
  avoids duplicate buttons momentarily, though both edit the same file so order matters for clean
  diffs). T094 is independent (different JSX region) — marked `[P]`.
- **Phase 21 (Back warning)**: T095 (hook) must complete before T096 (page consumes `isDirty` from
  the hook). T096 depends on T092/T093 being done first (same file, avoid merge conflicts — Back
  button logic touches the title bar `Box` that T092 already modified). T097 depends on T096
  (needs `confirmBackOpen`/`setIsDirty` already wired) but is a small addition to `handleSave`.
- **Phase 22 (Validation)**: T098 depends on T091 (backend). T099-T100 depend on T091 + running
  backend. T101-T102 depend on T092-T094. T103-T105 depend on T095-T097. T106 depends on all.

### Execution Order

```
T089 (interface) → T090 (implementation) → T091 (service branch) ──┬── T098 (build verify)
                                                                     ├── T099 (<24h verify)
                                                                     └── T100 (≥24h verify)

T092 (remove Save from title) → T093 (add Save below Default) ──┬── T101 (verify Save position)
T094 (column ratio) [P] ─────────────────────────────────────────┴── T102 (verify ratio)

T095 (isDirty in hook) → T096 (wire ConfirmDialog + Back) → T097 (reset isDirty on save) ──┬── T103 (verify Back — Add)
                                                                                              ├── T104 (verify Back — Edit inline)
                                                                                              └── T105 (verify Back — no changes)

All verification (T098-T105) → T106 (E2E quickstart scenarios)
```

### Parallel Opportunities

```
# Phase 19 — sequential (interface → impl → service), backend-only, can run parallel to Phase 20/21:
T089 → T090 → T091

# Phase 20 — mostly sequential (same file), T094 independent:
T092 → T093
T094 [P] (different JSX region — column Grid props)

# Phase 21 — sequential (hook → page wiring → save reset):
T095 → T096 → T097

# Phase 22 — all verification tasks [P] except the final E2E:
T098, T099, T100, T101, T102, T103, T104, T105 in parallel (once their respective phases are done)
T106 sequentially (end-to-end)
```

**Checkpoint**: `GET /api/dynamics/vendors?skip=0&top=10` returns OData JSON where each item in the `value` array contains ONLY `dataAreaId`, `VendorAccountNumber`, `VendorOrganizationName` — no other VendorsV3 fields.

---

## Phase 18: Validation — Vendors $select

**Purpose**: Verify the $select change works correctly end-to-end

- [x] T085 [P] Build backend and verify 0 compilation errors after the $select change in compliance-sys-api/ (0 CS errors; build's file-copy step failed only because a dev server instance was holding the output exe locked — unrelated to code correctness)
- [ ] T086 [P] Verify vendor API response only contains 3 fields: open browser DevTools Network tab, call `GET /api/dynamics/vendors` — each item in `value` array must have ONLY `dataAreaId`, `VendorAccountNumber`, `VendorOrganizationName` (no extra fields like `VendorGroupId`, `AddressCity`, etc.)
- [ ] T087 [P] Verify vendor combobox still works correctly in Add and Edit modes after the response shape change — dropdown displays VendorAccountNumber + VendorOrganizationName, selection sets vendorCode/vendorName correctly
- [ ] T088 Run quickstart.md vendor validation scenarios (create with vendor, edit with vendor pre-selected) to confirm no regression

---

## Update 3 Dependencies

### Phase Dependencies

- **Phase 17 (Backend $select)**: No dependencies — can start immediately. Only modifies `DynController.cs`.
- **Phase 18 (Validation)**: T085 depends on T084. T086-T088 depend on T084 + running frontend/backend dev servers.

### Execution Order

```
T084 (Append $select to vendors URL) ── T085 (Build verify) ──┬── T086 (Verify response)
                                                                ├── T087 (Verify combobox)
                                                                └── T088 (E2E scenarios)
```

### Parallel Opportunities

```
# Phase 17 — single task:
T084: Modify DynController.Vendors() to append $select

# Phase 18 — all verification tasks [P] after T085:
T085: Build verification (sequential after T084)
T086, T087 in parallel (after build passes)
T088 sequentially (end-to-end)
```

---

## Update 2026-07-06 — Revert Vendor API to Generic Reference (refType=13)

**Context**: Reverses Update 2/3 (Phases 13-18). Spec Update 5 requires the vendor combobox in
`EutrTemplatesAddEdit.jsx` (`options={vendors}`) and the grid's Vendor name lookup to switch back
from the dedicated `GET /api/dynamics/vendors` endpoint to the generic reference API
(`POST /api/dynamics/reference` with `refType = 13`), via the existing `ReferenceObjectAutocomplete`
component — reversing the `useVendors` hook approach built in Phase 13-15.

**Changes**: Frontend only. No backend changes — `refType = 13` is already mapped to `VendorsV3`
in `ComplDynamicsService` (unchanged since before Update 2). The dedicated `GET /api/dynamics/vendors`
endpoint added in Phase 13 is left in `DynController.cs` (not deleted — out of scope, may have
undiscovered consumers).

---

## Phase 23: Frontend — Replace Vendor Combobox with Generic Reference API

**Purpose**: Swap the MUI `Autocomplete` + `useVendors` combobox back to `ReferenceObjectAutocomplete` (refType=13)

- [x] T107 [US2] Replace the vendor combobox in compliance-client/src/presentation/pages/eutr-templates/EutrTemplatesAddEdit.jsx — remove the `import useVendors from './hooks/useVendors'` line, the `const { vendors, loading: vendorsLoading, setSearchQuery: setVendorSearch } = useVendors(vendorCode);` hook call, and the entire `<Autocomplete options={vendors} ...>` JSX block for the Vendor field (including its `getOptionLabel`, `isOptionEqualToValue`, `value`, `onChange`, `onInputChange`, and `loading` props). Replace with `import ReferenceObjectAutocomplete from '@presentation/components/common/ReferenceObjectAutocomplete';` and `<ReferenceObjectAutocomplete referenceType={13} label="Vendor" size="small" value={vendorCode} onChange={(_e, newValue) => { setVendorCode(newValue?.code || ''); setVendorName(newValue?.name || ''); }} />`, matching the prop pattern used by other `ReferenceObjectAutocomplete` consumers in the codebase. In Edit mode, the existing `vendorCode` state (already populated from `getUseCase.execute(id)` in the load-template `useEffect`) pre-selects the vendor automatically since it's passed as `value`. **Done**: `value` passed as `{ id, code, name }` object (matching `isOptionEqualToValue`'s `option.id === val?.id` check in the shared component, verified by reading `ReferenceObjectAutocomplete.jsx` and its other consumers e.g. `ComplianceMasterForm.jsx`) rather than a bare string.
- [x] T108 [P] [US2] Remove compliance-client/src/presentation/pages/eutr-templates/hooks/useVendors.js — no longer used after T107. Grep the repo for other importers of this file first (expected: none, since it was created solely for this feature in Phase 14); if any are found, stop and report instead of deleting. **Done**: grep confirmed no other importers; file deleted.
- [x] T109 [P] [US1] Verify grid Vendor name column resolution in compliance-client/src/presentation/pages/eutr-templates/ (index.jsx / useEutrTemplatesData.js) — confirm `vendorName` still comes from the backend's `GetPagedWithVendorNameAsync`, which resolves via `ComplDynamicsService`'s existing refType=13 mapping (unchanged by this update). No code change expected; verification-only task. **Done**: traced `EutrTemplatesService.GetPagedAsync` — it resolves `VendorName` via `IComplDynamicsService.GetFromDynamics<VendorsV3>` (a separate direct D365 lookup, not the vendors combobox's reference/vendors endpoint), untouched by this frontend-only change. Grid column is unaffected.

**Checkpoint**: Vendor combobox on Add/Edit calls the generic reference API (refType=13) via `ReferenceObjectAutocomplete`. Grid vendorName column still resolves correctly.

---

## Phase 24: Backend Cleanup Check (verification only, no removal)

**Purpose**: Confirm removing the frontend's dependency on the dedicated vendors endpoint doesn't break other consumers

- [x] T110 [P] Search compliance-client/src and compliance-sys-api/src for any other consumers of `getVendors` (`dynamicsApi.js`, `RestDynamicsRepository.js`, `IDynamicsRepository.js`) and of `[HttpGet("vendors")]` in `DynController.cs`. If none found outside this feature, leave this dead code in place per the plan.md/research.md decision (do not delete the backend endpoint or the frontend `getVendors` methods — deleting them is out of scope for this reversal). Just confirm no other feature depends on them before considering Phase 23 complete. **Done**: grep confirmed `getVendors` (dynamicsApi.js/RestDynamicsRepository.js/IDynamicsRepository.js) and `DynController.cs`'s `[HttpGet("vendors")]` have no other callers — left in place per plan.md, unused.

---

## Phase 25: Validation — Vendor API Reversal

**Purpose**: End-to-end validation that the vendor combobox and grid use the generic reference API

- [ ] T111 [P] Verify Vendor combobox in Add mode: open Add page, click Vendor field — DevTools Network tab must show a `POST /dynamics/reference` request with `refType=13` (NOT `GET /dynamics/vendors`). Dropdown must display vendor list (VendorAccountNumber + VendorOrganizationName, surfaced as `code`/`name` per `ComplDynReferenceResponseDto`).
- [ ] T112 [P] Verify Vendor combobox in Edit mode: open Edit page for a template with a VendorCode — vendor must be pre-selected in the combobox; opening the dropdown must call `POST /dynamics/reference` with `refType=13`.
- [ ] T113 [P] Verify grid vendorName column still displays correct vendor names for templates with a valid VendorCode (no regression from the combobox change).
- [ ] T114 Run quickstart.md validation Scenarios 1, 2, 3 end-to-end (view list with vendor names, create with vendor selection via reference API, edit with vendor pre-selected via reference API).

---

## Update 5 Dependencies

### Phase Dependencies

- **Phase 23 (Replace combobox)**: T107 first (same file as T108's removal target has no code
  dependency, but T108 should follow T107 to avoid deleting a hook still referenced). T109 is
  independent verification, `[P]`.
- **Phase 24 (Cleanup check)**: T110 can run any time after T107 — independent of T108/T109.
- **Phase 25 (Validation)**: All tasks depend on T107 being complete. T114 depends on T111-T113.

### Execution Order

```
T107 (Replace combobox with ReferenceObjectAutocomplete) ── T108 (Remove useVendors.js)
                                                        │
                                                        ├── T109 (Verify grid) [P]
                                                        ├── T110 (Cleanup check) [P]
                                                        └── T111-T113 (Verify combobox) [P] ── T114 (E2E)
```

### Parallel Opportunities

```
# Phase 23 — T107 first, then T108/T109 in parallel:
T107: Replace combobox in EutrTemplatesAddEdit.jsx
T108: Remove useVendors.js                      [P] (after T107)
T109: Verify grid vendorName resolution         [P]

# Phase 24 — independent:
T110: Search for other getVendors/vendors-endpoint consumers [P]

# Phase 25 — all verification tasks [P] except the final E2E:
T111, T112, T113 in parallel (once T107 is done)
T114 sequentially (end-to-end)
```

---

## Update 2026-07-06 — Free-solo Step Combobox + Auto-create Step (FR-007, FR-007a, FR-008b)

**Context**: When adding/editing a step in the template's step tree, the Step combobox currently
only allows picking from the existing `eutr_steps` list. Per spec Update 6, it must become
free-solo: the user can also type a step name that isn't in the list. On template Save, any step
with a typed (unmatched) name is auto-created in `eutr_steps` (case-insensitive/trimmed match
against existing rows first, to avoid duplicates), and the new step's Id is used for
`eutr_template_details.StepId`.

**Changes**: Backend — `EutrTemplateDetailsRequestDto` gains `StepName`; validator requires
`StepId` OR `StepName` per detail; new repository method `ResolveOrCreateStepsByNameAsync`;
`EutrTemplatesService` resolves/creates steps before building detail entities in `AddAsync` and
both `UpdateAsync` branches. Frontend — Step `Autocomplete` in `StepFormRow.jsx` and `StepTree.jsx`
(inline edit) becomes `freeSolo`; `useStepTree.js`'s `flattenForSave` emits `stepName` for every
detail.

---

## Phase 26: Backend — StepName Field, Validation, Resolve/Auto-create

**Purpose**: Accept a free-solo-typed step name from the frontend and resolve/auto-create it in `eutr_steps` before saving template details

- [X] T115 [US2] Add `public string? StepName { get; set; }` to compliance-sys-api/src/ComplianceSys.Application/Dtos/Request/EutrTemplateDetailsRequestDto.cs — used only when `StepId` is null (the frontend always sends `stepName`, mirroring the combobox's current selected/typed value, but the backend only consults it when `StepId` is absent).
- [X] T116 [US2] Add a per-detail rule to compliance-sys-api/src/ComplianceSys.Application/Validators/EutrTemplatesRequestDtoValidator.cs — `RuleForEach(x => x.Details).ChildRules(detail => { detail.Must(d => d.StepId.HasValue || !string.IsNullOrWhiteSpace(d.StepName)).WithMessage("Each step requires either an existing step or a step name"); });` (or equivalent FluentValidation syntax matching the existing `BaseValidator` conventions in this file).
- [X] T117 [US2] Add `Task<Dictionary<string, long>> ResolveOrCreateStepsByNameAsync(IEnumerable<string> names, string userEmail, CancellationToken ct = default);` to compliance-sys-api/src/ComplianceSys.Application/Interfaces/Repositories/IEutrTemplatesRepository.cs, with a Vietnamese XML-style comment describing the case-insensitive/trimmed match-then-create behavior.
- [X] T118 [US2] Implement `ResolveOrCreateStepsByNameAsync` in compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/EutrTemplatesRepository.cs — dedupe input names (`Distinct(StringComparer.OrdinalIgnoreCase)`, trimmed, skip blank); `SELECT Id, Name FROM eutr_steps WHERE Name IN @names` via `Connection.QueryAsync` (within the current `Transaction`) to find existing matches (relies on the DB's default case-insensitive collation, same assumption already implicit in this repository's unqualified `LIKE` filters); for any name with no match, `INSERT INTO eutr_steps (Name, CreatedBy, CreatedDate, UpdatedBy, UpdatedDate) VALUES (...); SELECT LAST_INSERT_ID();` via `Connection.ExecuteScalarAsync<long>`; return a `Dictionary<string, long>` keyed by the trimmed name (`StringComparer.OrdinalIgnoreCase`).
- [X] T119 [US2] In compliance-sys-api/src/ComplianceSys.Application/Services/EutrTemplatesService.cs, extract a private `Task<List<EutrTemplateDetails>> BuildDetailEntitiesAsync(IEnumerable<EutrTemplateDetailsRequestDto> detailDtos, DateTime now, string userEmail, CancellationToken ct)` helper: collect distinct trimmed `StepName` values from details where `StepId == null && !string.IsNullOrWhiteSpace(StepName)`; if any, call `_repository.ResolveOrCreateStepsByNameAsync(...)` once; map each DTO to an `EutrTemplateDetails` entity via `_mapper.Map`, and for details with `StepId == null`, set `detail.StepId` from the resolved dictionary (lookup by trimmed name); set `CreatedDate`/`CreatedBy`/`UpdatedDate`/`UpdatedBy` as the existing inline code already does. Replace the three near-duplicate detail-building blocks (in `AddAsync`, and both branches of `UpdateAsync`) with calls to this helper.

**Checkpoint**: Saving a template with a step whose `stepId` is null and `stepName` is a brand-new name creates exactly one new `eutr_steps` row and uses its Id; a `stepName` matching an existing step (any case/whitespace) reuses that step's Id with no duplicate row created. Validation rejects a detail with neither `stepId` nor `stepName`.

---

## Phase 27: Frontend — Free-solo Step Combobox

**Purpose**: Let the user pick an existing step or type a new one in the Add step and inline Edit step forms

- [X] T120 [P] [US2] In compliance-client/src/presentation/pages/eutr-templates/components/StepFormRow.jsx, change the Step `Autocomplete` to `freeSolo` (`freeSolo` prop, `options={steps}`, `getOptionLabel` unchanged). Track both `stepId` and a new `stepName` local state: `onChange` — if `newValue` is an object (existing step selected), set `stepId = newValue.id`, `stepName = newValue.name`; if `newValue` is a string (free-solo typed value, e.g. via Enter), set `stepId = null`, `stepName = newValue`. Add `onInputChange` to keep `stepName` in sync while typing when no option is selected (mirrors the `freeSolo` handling already used for the `Alert for` field in `EutrTemplatesAddEdit.jsx`). `handleAdd` now checks `stepName?.trim()` (not `stepId`) before calling `onAdd`, and includes `stepName: stepName.trim()` in the payload passed to `onAdd` alongside `stepId`.
- [X] T121 [P] [US2] In compliance-client/src/presentation/pages/eutr-templates/components/StepTree.jsx, apply the same `freeSolo` change to the Step `Autocomplete` inside the inline edit mode (`isEditing` branch): `editFormData` gains `stepName`; `onChange` handles both an existing-option object and a raw typed string the same way as T120; `handleSaveEdit` passes `stepName: editFormData.stepName?.trim()` (in addition to the existing `stepId`) to `onEditStep`.
- [X] T122 [US2] In compliance-client/src/presentation/pages/eutr-templates/hooks/useStepTree.js, update `flattenForSave()` to include `stepName: s.stepName` in every emitted detail object (alongside the existing `stepId`, `parentId`, `requirementType`, `takeFrom`, `displayOrder`) — the backend only reads `stepName` when `stepId` is null, so it's safe to always send it.

**Checkpoint**: Add step form and inline Edit step form both accept typing a name not in the dropdown. The tree displays the typed name immediately (client-side draft, nothing persisted yet).

---

## Phase 28: Validation — Free-solo Step Combobox + Auto-create

**Purpose**: End-to-end validation of the free-solo combobox and auto-create behavior

- [ ] T123 [P] Verify auto-create: on the Add page, type a brand-new step name (not in the dropdown) into the Step combobox, save the step, save the template — check `eutr_steps` in the DB for exactly one new row with that name, and `eutr_template_details.StepId` for that row references it.
- [ ] T124 [P] Verify dedupe within one Save: add two root steps in the same Add/Edit session using the identical new (not-yet-existing) name, save the template — check `eutr_steps` has only ONE new row for that name, and both `eutr_template_details` rows share the same `StepId`.
- [ ] T125 [P] Verify case-insensitive/trimmed reuse: type an existing step's name with different casing or extra whitespace (e.g. " forest management ") into the Step combobox, save — check no duplicate `eutr_steps` row was created; the existing step's Id was reused.
- [ ] T126 [P] Verify inline Edit step free-solo: on an Edit page, click the Edit icon on an existing step, type a brand-new name into the Step combobox (instead of picking from the dropdown), save the inline edit, then save the template — check the new step was created in `eutr_steps` and the detail's `StepId` was updated to it.
- [ ] T127 [P] Verify validation: attempt to save a step row with a blank/whitespace-only typed name — confirm the UI blocks adding it (Add step / Save inline edit disabled or rejected) before it ever reaches the backend.
- [ ] T128 Run quickstart.md Scenario 14 end-to-end (auto-create, dedupe-within-save, case-insensitive reuse, inline-edit free-solo).

**Checkpoint**: All Scenario 14 quickstart checks pass; no duplicate `eutr_steps` rows are ever created for names that already exist or repeat within one Save.

---

## Update 6 Dependencies

### Phase Dependencies

- **Phase 26 (Backend)**: T115 (DTO field) → T116 (validator rule, reads `StepId`/`StepName` from
  the DTO) and T117 (repository interface method signature) can both start once T115 lands, in
  parallel. T118 (repository implementation) depends on T117 (interface declared first). T119
  (service helper) depends on T118 (calls `ResolveOrCreateStepsByNameAsync`) and T115 (reads
  `StepName` off the DTO).
- **Phase 27 (Frontend)**: T120 and T121 are independent (different files) — `[P]`. T122 has no
  hard dependency on T120/T121 (different file) but is naturally done alongside them since all
  three touch the same step-tree data shape — `[P]`.
- **Phase 28 (Validation)**: All tasks depend on Phase 26 AND Phase 27 being complete (the feature
  is full-stack — backend resolution logic and frontend free-solo input both must exist).

### Execution Order

```
T115 (StepName DTO field) ──┬── T116 (validator rule)
                             └── T117 (repository interface) ── T118 (repository impl) ── T119 (service helper) ──┐
                                                                                                                    │
T120 (StepFormRow freeSolo) [P] ──┐                                                                                │
T121 (StepTree freeSolo) [P] ─────┼── T122 (flattenForSave stepName) ──────────────────────────────────────────────┼── T123-T127 (verification, [P]) ── T128 (E2E)
                                   ┘                                                                                │
```

### Parallel Opportunities

```
# Phase 26 — mostly sequential (DTO → validator/interface → impl → service), T116/T117 in parallel:
T115 → T116 [P]
T115 → T117 [P] → T118 → T119

# Phase 27 — all three touch different files, all [P]:
T120, T121, T122 in parallel

# Phase 28 — all verification tasks [P] except the final E2E:
T123, T124, T125, T126, T127 in parallel (once Phase 26 + 27 are done)
T128 sequentially (end-to-end)
```

---

## Update 2026-07-07 — Alert For Combobox from compl_group_email

**Context**: `AlertFor` is currently a free-text field — a `freeSolo` `Autocomplete` with hardcoded
placeholder `options={['PO', 'Upload manual']}` (copy-pasted from the TakeFrom field, not real
data). Per spec Update 7, it must become a single-select combobox sourced from `compl_group_email`
(`GET /api/group-email`, filtered to `GroupType=Alert(2)` and `IsAddition=false`), reusing the
frontend's existing `GetAllGroupEmailUseCase`/`repositories.groupEmail` pattern already used by
`ComplianceMasterForm.jsx`/`MasterDefaultForm.jsx`. On Save, the selected group's Id (not Name) is
persisted; the grid and Excel export display/write the resolved group Name.

**Changes**: Backend — `AlertFor` changes from `string` to `long?` in the entity/request DTO; a new
`AlertForName` response field is resolved via `LEFT JOIN compl_group_email` in the repository
(no external service call — `compl_group_email` is a local table); validator rule becomes numeric;
a DB migration converts the column type; Import resolves the Excel cell's group Name to an Id
(exact match, no auto-create); Export writes the resolved Name. Frontend — the Alert for
`Autocomplete` becomes select-only (no `freeSolo`) backed by `GetAllGroupEmailUseCase`; the grid
column switches from `alertFor` to `alertForName`. See research.md §18 and plan.md's "Update
2026-07-07" section for full rationale.

---

## Phase 29: Backend — AlertFor Type Change, Repository JOIN, Validator

**Purpose**: Change `AlertFor` from a free-text string to a numeric reference to
`compl_group_email.Id`, with the group's Name resolved for display

- [X] T129 [P] [US2] In compliance-sys-api/src/ComplianceSys.Domain/Entities/EutrTemplates.cs, change `public string AlertFor { get; set; }` to `public long? AlertFor { get; set; }`.
- [X] T130 [P] [US2] In compliance-sys-api/src/ComplianceSys.Application/Dtos/Request/EutrTemplatesRequestDto.cs, change `public string AlertFor { get; set; }` to `public long? AlertFor { get; set; }`.
- [X] T131 [P] [US1] In compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/EutrTemplatesResponseDto.cs, add `public string? AlertForName { get; set; }` alongside the existing `VendorName` property.
- [X] T132 [US2] In compliance-sys-api/src/ComplianceSys.Application/Validators/EutrTemplatesRequestDtoValidator.cs, replace `RuleFor(x => x.AlertFor).NotEmpty().WithMessage("Alert for is required");` with `RuleFor(x => x.AlertFor).Must(v => v.HasValue && v.Value > 0).WithMessage("Alert for is required");`.
- [X] T133 [US1] In compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/EutrTemplatesRepository.cs — in `GetPagedWithVendorNameAsync`'s `dataSql` and `GetByIdWithDetailsAsync`'s `headerSql`, add `LEFT JOIN compl_group_email g ON g.Id = t.AlertFor` and select `g.Name AS AlertForName` alongside the existing `t.AlertFor` column. Change `FilterMap["AlertFor"]` from `"t.AlertFor"` to `"g.Name"` so the existing grid filter searches by group Name (a raw Id is not a meaningful text-search target). Leave `SortMap["AlertFor"]` as `"t.AlertFor"` (sorting by the numeric Id is acceptable; only the text filter needs the Name).
- [X] T134 [P] [US2] Create compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Migration/08_migrate_eutr_templates_alertfor.sql — `UPDATE eutr_templates SET AlertFor = NULL WHERE AlertFor IS NOT NULL AND AlertFor NOT REGEXP '^[0-9]+$';` followed by `ALTER TABLE eutr_templates MODIFY COLUMN AlertFor BIGINT UNSIGNED NULL DEFAULT NULL;`. Run this script against the target MySQL database before deploying the updated entity/DTO (existing placeholder text values like `'PO'`/`'Upload manual'` are cleared first since they cannot cast to BIGINT — there is no production data using real group Ids yet).

**Checkpoint**: Backend compiles with `AlertFor` as `long?`. Paged list and get-by-id responses include `alertForName` resolved from `compl_group_email`. Grid text filter on Alert for matches against group Name. DB column is `BIGINT UNSIGNED NULL`.

---

## Phase 30: Backend — Import/Export AlertFor Name Resolution

**Purpose**: Import resolves the Excel AlertFor cell (a group Name) to an Id; Export writes the resolved Name back

- [X] T135 [US5] Add `Task<long?> ResolveAlertGroupIdByNameAsync(string name, CancellationToken ct = default);` to compliance-sys-api/src/ComplianceSys.Application/Interfaces/Repositories/IEutrTemplatesRepository.cs, and implement it in compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/EutrTemplatesRepository.cs — `SELECT Id FROM compl_group_email WHERE Name = @name AND GroupType = 2 AND IsAddition = 0 LIMIT 1` via `Connection.QueryFirstOrDefaultAsync<long?>`, exact match (trimmed) — unlike `ResolveOrCreateStepsByNameAsync`, this method does NOT auto-create a group when no match is found.
- [X] T136 [US5] In compliance-sys-api/src/ComplianceSys.Application/Services/EutrTemplatesImportService.cs, after reading `alertFor` (the Excel cell, a group Name) and confirming it's non-blank, call `_repository.ResolveAlertGroupIdByNameAsync(alertFor, ct)` (inject `IEutrTemplatesRepository` into the constructor if not already available — check whether `IEutrTemplatesService` already exposes this or add the repository dependency directly). If the result is `null`, record a new failure: `result.FailCount++; result.Errors.Add(new ImportEutrTemplatesRowError { Row = rowNum, Name = name, AlertFor = alertFor, Message = "Alert for group not found" }); continue;`. Otherwise set `dto.AlertFor = resolvedId.Value` before calling `_eutrTemplatesService.AddAsync(dto, userEmail, ct)`.
- [X] T137 [US5] In compliance-sys-api/src/ComplianceSys.Application/Services/EutrTemplatesExportService.cs, change `sheet.Cell(row, 4).Value = item.AlertFor;` to `sheet.Cell(row, 4).Value = item.AlertForName;` (uses the same `GetPagedWithVendorNameAsync` result, which now includes `AlertForName` per T133).

**Checkpoint**: Importing an Excel file with a valid Alert group Name in column B succeeds and stores the resolved Id. Importing a name with no matching group fails that row with "Alert for group not found". Exported files show the group Name in the AlertFor column, not a raw Id.

---

## Phase 31: Frontend — Alert For Combobox

**Purpose**: Replace the free-text/hardcoded Alert for field with a combobox sourced from `compl_group_email`

- [X] T138 [US2] In compliance-client/src/presentation/pages/eutr-templates/EutrTemplatesAddEdit.jsx — remove the `const ALERT_FOR_OPTIONS = ['PO', 'Upload manual'];` constant and the `Autocomplete` bound to `options={ALERT_FOR_OPTIONS}` / `freeSolo` for the Alert for field. Import `GetAllGroupEmailUseCase` from `@application/usecases/group-email`, `repositories.groupEmail` from `@src/di/repositories`, and `groupEmailType` from `@utils/helpers` (same imports already used in `ComplianceMasterForm.jsx`). On mount (alongside the existing steps-loading `useEffect`), call `new GetAllGroupEmailUseCase(repositories.groupEmail).execute()`, store the result in a new `alertGroups` state, and filter to `g.groupType === groupEmailType.ALERT && g.isAddition === false` before passing to the combobox's `options`. Replace the field with a select-only `Autocomplete` (no `freeSolo`): `options={alertGroups}`, `getOptionLabel={(g) => g.name || ''}`, `isOptionEqualToValue={(opt, val) => opt.id === val?.id}`, `value={alertGroups.find((g) => g.id === alertFor) || null}`, `onChange={(_e, newValue) => setAlertFor(newValue?.id ?? '')}`. Update the Save validation check (`if (!alertFor.trim())`) to `if (!alertFor)` since `alertFor` is now a numeric Id, not a string. In the load-template `useEffect` (Edit mode), keep `setAlertFor(template.alertFor || '')` — it now stores the numeric Id, which the combobox's `value` lookup resolves against `alertGroups` once both have loaded.
- [X] T139 [P] [US1] In compliance-client/src/domain/entities/EutrTemplates.js, add `alertForName` to the constructor destructuring and assignment (`this.alertForName = alertForName`), alongside the existing `alertFor`, mirroring the `vendorName`/`vendorCode` pair.
- [X] T140 [P] [US1] In compliance-client/src/presentation/pages/eutr-templates/hooks/useEutrTemplatesColumns.jsx, change the Alert for column's `field` from `"alertFor"` to `"alertForName"` (keep `headerName: "Alert for"`), and update `defaultColumnVisibility`'s key from `alertFor` to `alertForName` to match.

**Checkpoint**: Alert for combobox on Add/Edit shows only Alert-type active groups by Name, no free-text typing allowed. Selecting a group and saving persists its Id. Grid's Alert for column displays the group Name. Edit mode pre-selects the template's current group once both the template and the groups list have loaded.

---

## Phase 32: Validation — Alert For Combobox

**Purpose**: End-to-end validation of the AlertFor combobox, persistence, display, and import/export changes

- [ ] T141 [P] Verify combobox data source: open the Add page, click the Alert for field — DevTools Network tab must show a `GET /group-email` request; the dropdown must list only groups with `GroupType=2` and `IsAddition=false`, by Name, with no way to type a free-text value.
- [ ] T142 [P] Verify Save persists the Id: select an Alert group, fill Name, save a new template — query `eutr_templates` and confirm `AlertFor` holds the group's numeric Id, not its Name.
- [ ] T143 [P] Verify grid display: open the list page — the Alert for column must show the group's Name (matching `compl_group_email.Name`) for every template with a valid AlertFor Id, and blank for any template whose AlertFor Id no longer exists in `compl_group_email`.
- [ ] T144 [P] Verify Edit pre-selection: open Edit on a template with a known AlertFor group — the Alert for combobox must show that group pre-selected as soon as the page finishes loading.
- [ ] T145 [P] Verify Import/Export: import an Excel file with one row using a valid Alert group Name and one row using a nonexistent group Name — confirm the valid row succeeds (with the correct Id stored) and the invalid row fails with "Alert for group not found". Then export the list and confirm the AlertFor column contains group Names, not Ids.
- [ ] T146 Run quickstart.md Scenario 1 (step 5a), Scenario 2 (steps 6a/6b), Scenario 3 (step 4a), Scenario 9, and Scenario 10 end-to-end.

**Checkpoint**: All Update 7 quickstart checks pass — combobox, persistence, grid display, Edit pre-selection, and Import/Export all use `compl_group_email` correctly.

---

## Update 7 Dependencies

### Phase Dependencies

- **Phase 29 (Backend type change)**: T129, T130, T131 are independent `[P]` (different files,
  pure type/property changes). T132 (validator) depends on T130 (reads the DTO's new `long?`
  type). T133 (repository JOIN) depends on T131 (the SQL projects into `AlertForName`, which must
  exist on the response DTO first). T134 (migration script) has no code dependency but should be
  run against the DB before or alongside deploying T129/T130 (the entity/DTO expect a numeric
  column).
- **Phase 30 (Import/Export)**: T135 (repository method) has no dependency on Phase 29 completion
  beyond `AlertFor` being `long?` (T130). T136 (Import) depends on T135. T137 (Export) depends on
  T133 (needs `AlertForName` in the paged result).
- **Phase 31 (Frontend combobox)**: T138 has no hard dependency on the backend phases to *write*
  (it's a separate file), but needs T130/T133 deployed to *work end-to-end* (Save/pre-select rely
  on the backend accepting/returning a numeric Id). T139 and T140 are independent `[P]`.
- **Phase 32 (Validation)**: All tasks depend on Phases 29-31 being complete and deployed together
  (this is a full-stack change — backend numeric type + JOIN, and frontend combobox, must both be
  in place for any of T141-T145 to pass).

### Execution Order

```
T129 (entity AlertFor→long?) ─┬── T132 (validator)
T130 (DTO AlertFor→long?) ────┘
T131 (AlertForName on ResponseDto) ── T133 (repository LEFT JOIN + FilterMap) ──┬── T137 (Export writes AlertForName)
T134 (migration script) ── (run against DB) ─────────────────────────────────────┘

T130 ── T135 (ResolveAlertGroupIdByNameAsync) ── T136 (Import resolves Name→Id)

T138 (frontend combobox) ──┐
T139 (entity alertForName) [P] ──┼── T141-T145 (verification, [P]) ── T146 (E2E)
T140 (grid column) [P] ────┘
```

### Parallel Opportunities

```
# Phase 29 — type changes in parallel, JOIN/validator depend on them:
T129, T130, T131 in parallel
T132 (after T130), T133 (after T131) can then run in parallel
T134 independent (DB script, no code dependency) [P]

# Phase 30 — mostly sequential (repository method → Import consumer), Export is independent:
T135 → T136
T137 [P] (depends only on T133, not on T135/T136)

# Phase 31 — frontend combobox + two small independent edits:
T138
T139, T140 in parallel [P]

# Phase 32 — all verification tasks [P] except the final E2E:
T141, T142, T143, T144, T145 in parallel (once Phases 29-31 are deployed)
T146 sequentially (end-to-end)
```

---

## Update 2026-07-07 — Shared RequirementType/TakeFrom Constants (frontend refactor)

**Context**: `StepTree.jsx` declares `REQUIREMENT_LABELS`, `TAKE_FROM_LABELS`, `REQUIREMENT_TYPES`,
and `TAKE_FROM_OPTIONS` locally; `StepFormRow.jsx` (same folder) separately declares a
byte-for-byte duplicate of `REQUIREMENT_TYPES`/`TAKE_FROM_OPTIONS`. Per spec Update 8, all four
constants move to `compliance-client/src/utils/helpers.js` — the codebase's established shared
location for cross-feature frontend constants (`ObjectType`, `groupEmailType`) — so both files (and
any future feature) import a single source instead of duplicating it.

**Changes**: Frontend-only, no backend/DB/contract changes. Values, shapes, and names are
unchanged — pure relocation. See research.md §19 and plan.md's "Update 2026-07-07 — Shared
RequirementType/TakeFrom Constants" section for full rationale.

---

## Phase 33: Frontend — Move Shared Constants to utils/helpers.js

**Purpose**: Centralize `REQUIREMENT_TYPES`, `TAKE_FROM_OPTIONS`, `REQUIREMENT_LABELS`,
`TAKE_FROM_LABELS` in `utils/helpers.js` and remove the duplicate/local declarations

- [X] T147 [US2] In compliance-client/src/utils/helpers.js, add and export (verbatim values,
      copied from `StepTree.jsx`): `export const REQUIREMENT_TYPES = [{ value: 0, label:
      'Optional' }, { value: 1, label: 'Required' }];`, `export const TAKE_FROM_OPTIONS = [{
      value: 0, label: 'PO' }, { value: 1, label: 'Upload manual' }];`, `export const
      REQUIREMENT_LABELS = { 0: 'Optional', 1: 'Required' };`, `export const TAKE_FROM_LABELS = {
      0: 'PO', 1: 'Upload manual' };`. Place them near the other standalone exported constants
      (e.g. after `groupEmailType`), each as its own `export const` statement (no `Object.freeze`
      wrapper — keep the existing plain array/object shape so `options={REQUIREMENT_TYPES}` and
      `.find(...)` call sites need no changes). **Done**: added after `groupEmailType` in
      compliance-client/src/utils/helpers.js.
- [X] T148 [P] [US2] In compliance-client/src/presentation/pages/eutr-templates/components/StepTree.jsx,
      delete the local `REQUIREMENT_LABELS`, `TAKE_FROM_LABELS`, `REQUIREMENT_TYPES`,
      `TAKE_FROM_OPTIONS` declarations (lines currently defining them near the top of the file) and
      import all four from `@utils/helpers` (or the relative path already used by this file's other
      imports) instead. Leave every usage (`options={REQUIREMENT_TYPES}`,
      `REQUIREMENT_TYPES.find(...)`, `TAKE_FROM_LABELS[...]`, etc.) unchanged. **Done**: local
      declarations removed, single import added from `@utils/helpers`.
- [X] T149 [P] [US2] In compliance-client/src/presentation/pages/eutr-templates/components/StepFormRow.jsx,
      delete the local `REQUIREMENT_TYPES`, `TAKE_FROM_OPTIONS` declarations and import both from
      `@utils/helpers` (same import path used in T148) instead. Leave every usage
      (`options={REQUIREMENT_TYPES}`, `.find(...)`) unchanged. **Done**: local declarations removed,
      import added from `@utils/helpers`.

**Checkpoint**: `helpers.js` exports all four constants; `StepTree.jsx` and `StepFormRow.jsx` have
no local declarations of them and import from `utils/helpers.js` instead; no duplicate
declarations remain anywhere in `eutr-templates/components/`.

---

## Phase 34: Validation — Shared RequirementType/TakeFrom Constants

**Purpose**: Confirm the relocation introduced no behavior/visual regression and no dead imports

- [ ] T150 [P] Verify Add step form (`StepFormRow.jsx`): open the Add/Edit template page, use "Add
      step" — the RequirementType combobox must still show "Optional"/"Required" and the TakeFrom
      combobox must still show "PO"/"Upload manual", both selectable and saved correctly.
- [ ] T151 [P] Verify inline Edit step (`StepTree.jsx`): click the Edit icon on an existing step —
      the RequirementType/TakeFrom comboboxes must still pre-select the step's current values from
      the shared constants, and the tree row's label text (via `REQUIREMENT_LABELS`/
      `TAKE_FROM_LABELS`) must still render "Optional"/"Required"/"PO"/"Upload manual" correctly.
- [ ] T152 Run a frontend build/lint (e.g. `npm run build` or `npm run lint` in
      `compliance-client/`) to confirm no unused-import or unresolved-import errors remain in
      `StepTree.jsx`/`StepFormRow.jsx` after removing the local declarations, then run the
      quickstart.md Post-Validation Checks item added for Update 8 end-to-end. **Partially done**:
      `npm run build` in compliance-client/ succeeded with no import/unused errors (confirmed
      `REQUIREMENT_TYPES`/`TAKE_FROM_OPTIONS`/`REQUIREMENT_LABELS`/`TAKE_FROM_LABELS` are used only
      via the `@utils/helpers` import in both files). The quickstart.md end-to-end browser check
      still requires manual verification (T150/T151) — not run in this session (no dev server/UI
      driven).

**Checkpoint**: Both comboboxes and tree label rendering behave identically to before the move; no
build/lint errors; only one source of truth remains for these four constants.

---

## Update 8 Dependencies

### Phase Dependencies

- **Phase 33 (Move constants)**: T147 (add exports to `helpers.js`) MUST complete before T148 and
  T149 (both import from `helpers.js`). T148 and T149 are independent `[P]` — different files, no
  shared state.
- **Phase 34 (Validation)**: Depends on all of Phase 33 (T147-T149) being complete. T150 and T151
  are independent `[P]` (different components/screens). T152 (build/lint + quickstart check) runs
  last, after T150/T151 confirm behavior is unchanged.

### Execution Order

```
T147 (helpers.js exports) ──┬── T148 (StepTree.jsx imports) ──┐
                             └── T149 (StepFormRow.jsx imports) ──┴── T150, T151 ([P]) ── T152 (E2E)
```

### Parallel Opportunities

```
# Phase 33 — one shared-file edit, then two independent consumer edits:
T147 first (blocking)
T148, T149 in parallel [P] (after T147)

# Phase 34 — both manual checks in parallel, build/lint + quickstart last:
T150, T151 in parallel [P]
T152 sequentially (after T150/T151)
```

---

## Update 2026-07-13 — TemplateListPage Rename + 2-Step Create/Edit Split

**Context**: Per spec Update 9 (following the design reference `E:\Working\design\eutr\pages\
TemplateListPage.jsx`/`TemplateBuilderPage.jsx`): (1) rename the list page to **TemplateListPage**;
(2) confirm the grid/Action column set already matches the request (Code, Alert for present; no
Status; Action = Edit + Delete only — no code change needed, FR-020); (3) split template creation
into 2 steps — a lightweight **Create Template** dialog (Name, Alert for, Set as default only, no
Vendor, no step tree) followed by the existing full **Edit** page (now the sole place Vendor and
the step tree — including a template's first-ever steps — are set).

**Changes**: Frontend-only, no backend/DB/contract changes (`POST api/eutr-templates` already
accepts `vendorCode: null` and `details: []`). Rename `index.jsx` → `TemplateListPage.jsx`; add
`components/CreateTemplateDialog.jsx`; wire it into the list page in place of the old
`navigate('/eutr/templates/add')` call; simplify `EutrTemplatesAddEdit.jsx` to Edit-only; remove
the `/eutr/templates/add` route. See research.md §20 and plan.md's "Update 2026-07-13" section for
full rationale.

---

## Phase 35: Frontend — Rename List Page to TemplateListPage

**Purpose**: Satisfy FR-019 (page naming) and confirm FR-020 (grid/Action columns) with no
behavior change

- [X] T153 [US1] Rename compliance-client/src/presentation/pages/eutr-templates/index.jsx to compliance-client/src/presentation/pages/eutr-templates/TemplateListPage.jsx — rename the exported function `EutrTemplatesPage` → `TemplateListPage` (keep it the default export). Leave all existing grid/column/action logic, imports, and JSX untouched — this task is a pure rename. Verify FR-020 while here: confirm the rendered columns are exactly Code, Name, Vendor code, Vendor name, Alert for, Is default, Version, Created by, Created date, and the Action column has only Edit + Delete — no Status column, no Preview/Archive/Publish/Clone (already true; no code change expected).
- [X] T154 [US1] In compliance-client/src/app/routes/RouteResolver.jsx, update the lazy import for the `"eutr-templates"` entry from `import("@presentation/pages/eutr-templates")` to `import("@presentation/pages/eutr-templates/TemplateListPage")`. Keep the `codeToComponent["eutr-templates"]` key and the component's usage (`<EutrTemplatesPage />` reference in this file, if the local const name is kept, or renamed to match — either is fine as long as the JSX tag still resolves) unchanged otherwise.

**Checkpoint**: `/eutr/templates` still renders the exact same grid as before the rename; no visual or behavioral change.

---

## Phase 36: Frontend — Create Template Dialog (US2)

**Purpose**: Replace the old full-page Add flow with a lightweight 3-field quick-create dialog

- [X] T155 [US2] Create compliance-client/src/presentation/pages/eutr-templates/components/CreateTemplateDialog.jsx — a MUI `Dialog` accepting props `open`, `onClose`, `onCreated`. Contents: `TextField` for Name (required, shows inline error if empty on submit attempt), an `Autocomplete` for Alert for reusing the exact pattern already in `EutrTemplatesAddEdit.jsx` (`GetAllGroupEmailUseCase`/`repositories.groupEmail`, filtered to `g.groupType === groupEmailType.ALERT && g.isAddition === false`, select-only — no `freeSolo`, `getOptionLabel={(g) => g.name || ''}`, required, inline error if unselected on submit attempt), and a `Checkbox` labeled "Set as default template". No Vendor field, no step tree. `DialogActions`: a Cancel button (`onClose`, resets local form state) and a Save button that validates Name/Alert for client-side, then calls `new CreateEutrTemplatesUseCase(repositories.eutrTemplates).execute({ name: name.trim(), alertFor, isDefault: isDefault ? 1 : 0, vendorCode: null, details: [] })`; on success calls `onCreated()` then `onClose()`; on failure shows an error (reuse the `CustomSnackbar` pattern already used in this folder, or an inline `Alert` inside the dialog).
- [X] T156 [US2] In compliance-client/src/presentation/pages/eutr-templates/TemplateListPage.jsx, add local state `const [createOpen, setCreateOpen] = useState(false)`. Replace the toolbar's Add `IconButton`'s `onClick={() => navigate('/eutr/templates/add')}` with `onClick={() => setCreateOpen(true)}`. Import and render `<CreateTemplateDialog open={createOpen} onClose={() => setCreateOpen(false)} onCreated={fetchData} />` (reuse the existing `fetchData` already returned by `useEutrTemplatesData()` in this file to refresh the grid after a successful create). Check whether `navigate` is still used elsewhere in this file (it should be, for the Edit action wired through `useEutrTemplatesColumns`'s `onEdit`) before deciding whether the import can be removed — if still used, leave it.

**Checkpoint**: Clicking "Create Template" opens a dialog with only Name/Alert for/Set as default; Save creates a template with 0 steps and no Vendor, closes the dialog, and refreshes the grid without navigating away from the list.

---

## Phase 37: Frontend — Simplify Edit Page + Remove Add Route (US3)

**Purpose**: `EutrTemplatesAddEdit.jsx` becomes Edit-only now that Create no longer routes to it

- [X] T157 [US3] In compliance-client/src/presentation/pages/eutr-templates/EutrTemplatesAddEdit.jsx, remove the `isEdit` branch now that this component is only ever reached via `/eutr/templates/edit/:id` (so `id`/`isEdit` are always truthy): (1) always render the Code `TextField` — drop the `{(isEdit || code) && (...)}` guard around it; (2) hardcode the header `Typography` to `'Edit EUTR template'` — drop the `{isEdit ? '...' : '...'}` ternary; (3) in `handleSave`, always call `updateUseCase.execute(id, payload)` — drop the `if (isEdit) {...} else {...createUseCase...}` branch and the now-dead `createUseCase` import/instantiation if nothing else in the file uses it; (4) remove the now-unused `const isEdit = !!id;` derivation itself once nothing references it.
- [X] T158 [US3] In compliance-client/src/app/routes/groups/MainRoutes.jsx, remove the `{ path: "/eutr/templates/add", element: <EutrTemplatesAddEdit /> }` route entry. Keep `{ path: "/eutr/templates/edit/:id", element: <EutrTemplatesAddEdit /> }` exactly as-is.

**Checkpoint**: `/eutr/templates/add` is no longer a registered route. `EutrTemplatesAddEdit.jsx` has no `isEdit` conditional left; Edit continues to work exactly as before (2-column layout, Vendor combobox, step tree, versioning, Back-button warning all unchanged).

---

## Phase 38: Validation — TemplateListPage + 2-Step Create/Edit Split

**Purpose**: End-to-end validation that the rename and the Create/Edit split work correctly with no regression

- [ ] T159 [P] Verify TemplateListPage renders unchanged after the rename: navigate to `/eutr/templates` — grid shows exactly the columns required by FR-020 (Code, Name, Vendor code, Vendor name, Alert for, Is default, Version, Created by, Created date, Action) with Action limited to Edit + Delete — no Status column, no Preview/Archive/Publish/Clone.
- [ ] T160 [P] Verify the Create Template dialog shows ONLY Name, Alert for, Set as default (no Vendor field, no step tree); attempting Save with an empty Name or no Alert for selected shows a validation error and does not create a row.
- [ ] T161 [P] Verify a successful Create Template dialog Save: check the DB — the new `eutr_templates` row has `VendorCode = NULL` and zero matching rows in `eutr_template_details`; in the UI, the dialog closes and the grid refreshes to show the new row without navigating away from TemplateListPage.
- [ ] T162 [P] Verify Edit on a freshly quick-created template (0 steps, no Vendor): the Edit page opens showing an empty step-tree state and an unselected Vendor combobox (not an error); add the template's first step and select a Vendor, then Save — verify in DB that this Save updated the SAME row in place (same `Id`/`VersionId`, since the row is well under 24h old) with the new Vendor and step now persisted.
- [ ] T163 [P] Verify `/eutr/templates/add` is no longer reachable: navigating to it directly does not render the old full-page Add form (falls through to the app's normal unmatched-route behavior).
- [ ] T164 Run quickstart.md Scenario 2 (quick-create dialog), Scenario 2b (build the tree via first Edit), and re-verify Scenarios 3, 8, 9, 12, and 14 end-to-end now that they route step-tree work through Edit instead of the old Add page.

**Checkpoint**: All Update 9 quickstart checks pass — TemplateListPage renders identically to before, Create Template is a 3-field dialog with no Vendor/step tree, and Edit is confirmed as the sole place Vendor and the step tree (including first-time steps) are set.

---

## Update 9 Dependencies

### Phase Dependencies

- **Phase 35 (Rename list page)**: T153 (rename + verify FR-020) before T154 (update the import
  path that points at the renamed file). No dependency on Phase 36/37.
- **Phase 36 (Create dialog)**: T155 (new component) before T156 (wiring it into the renamed
  `TemplateListPage.jsx` from Phase 35) — T156 also depends on T153 (the file it edits must already
  be renamed).
- **Phase 37 (Simplify Edit + remove route)**: T157 and T158 are independent (different files) —
  `[P]`. Neither depends on Phase 35/36, but should land before Phase 38 validation so the Add
  route is confirmed gone.
- **Phase 38 (Validation)**: All tasks depend on Phases 35-37 being complete.

### Execution Order

```
T153 (rename index.jsx → TemplateListPage.jsx) ── T154 (RouteResolver import path)
                                                 │
T155 (CreateTemplateDialog.jsx) ── T156 (wire into TemplateListPage.jsx, depends on T153) ──┐
                                                                                              │
T157 (EutrTemplatesAddEdit.jsx Edit-only) [P] ──┐                                            │
T158 (remove /add route) [P] ────────────────────┴────────────────────────────────────────── T159-T163 ([P]) ── T164 (E2E)
```

### Parallel Opportunities

```
# Phase 35 — sequential (rename must land before the import path that points at it):
T153 → T154

# Phase 36 — new file first, then wiring:
T155 → T156 (depends on T153 from Phase 35)

# Phase 37 — both independent, different files:
T157 [P]
T158 [P]

# Phase 38 — all verification tasks [P] except the final E2E:
T159, T160, T161, T162, T163 in parallel (once Phases 35-37 are done)
T164 sequentially (end-to-end)
```

---

## Update 2026-07-13 — TemplateListPage Table-Layout Reversal + TemplateBuilderPage Real-Data Wiring (spec Update 10) + Server-Side Search & Real Steps Count (spec Update 11)

**Context**: Reverses Update 9's UI decision. `TemplateListPage.jsx` and `TemplateBuilderPage.jsx`
already exist as separate reference-design files (Table+search+chip layout / tree-view+side-panel
layout) already wired into routing (`RouteResolver.jsx` → `TemplateListPage.jsx` for
`eutr-templates`; `MainRoutes.jsx` → `TemplateBuilderPage.jsx` for `/eutr/templates/edit/:id`), but
both still run on mock data (`mock/eutrTemplates.js`, `mock/eutrTemplateDetails.js`,
`mock/eutrSteps.js`, `utils/treeUtils.js`). This update rewires them to the real, already-working
use cases/hooks originally built for `TemplateListPageOld.jsx`/`EutrTemplatesAddEdit.jsx` (which
themselves are untouched — they become unrouted reference/backup files). Two small backend
additions support this: a `Keyword` pseudo-filter (Code OR Name, server-side search) and a real
`StepsCount` field on the list response.

**Changes**: Backend — 2 small additions inside the existing `EutrTemplatesRepository` paged
query (`Keyword` special-case, `StepsCount` subquery) + 1 new `EutrTemplatesResponseDto` field. No
new endpoint, entity, service, or controller. Frontend — `TemplateListPage.jsx` and
`TemplateBuilderPage.jsx` swap mock data for real use cases/hooks while keeping their existing
visual shells; `TemplateListPage.jsx` gains bulk-delete + pagination (both missing from the mock);
`TemplateBuilderPage.jsx` gains a real header-form/step-detail side panel and reuses `useStepTree`
instead of its own hand-rolled tree state. See research.md §21–24 and plan.md's "Update
2026-07-13 — TemplateListPage Table-Layout Reversal..." section for full rationale.

---

## Phase 39: Backend — Keyword Search + Real Steps Count (US1)

**Purpose**: Extend the existing paged list query with a `Keyword` (Code OR Name) filter
special-case and a real per-template `StepsCount`, with no new endpoint or contract shape

- [X] T165 [US1] In compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/EutrTemplatesRepository.cs — in `GetPagedWithVendorNameAsync`'s dynamic WHERE-clause builder (the same place `FilterMap["AlertFor"] = "g.Name"` already lives), add a branch that recognizes an incoming filter `column == "Keyword"` and appends a parameterized `(Code LIKE @pN OR Name LIKE @pN)` condition (same `%value%` wrapping already used for other `like` operators) instead of resolving it through `FilterMap` as a single-column rename. Do not add `"Keyword"` to `FilterMap` itself — it must stay a special case, not a real column alias.
- [X] T166 [P] [US1] In compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/EutrTemplatesResponseDto.cs, add `public int StepsCount { get; set; }` alongside the existing `VendorName`/`AlertForName` properties.
- [X] T167 [US1] In the same `GetPagedWithVendorNameAsync` SQL (compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/EutrTemplatesRepository.cs), add `(SELECT COUNT(*) FROM eutr_template_details d WHERE d.TemplateId = t.Id) AS StepsCount` to the existing `SELECT` list (same statement that already resolves `VendorName`/`AlertForName`) so every row in the paged result carries its real step count.

**Checkpoint**: `POST api/eutr-templates/get-all` with `filters: [{ field: "Keyword", operator: "like", value: "<term>" }]` returns only templates whose Code or Name contains that term (case-insensitive), across the whole dataset — not just one page. Every returned item includes an accurate `stepsCount`.

---

## Phase 40: Frontend — TemplateListPage Real-Data Wiring, Pagination, Search (US1)

**Purpose**: Replace `TemplateListPage.jsx`'s mock data with `useEutrTemplatesData`, keep its
existing Table/chip layout, add the search box's server-side keyword wiring and the pagination
control the mock never had

- [X] T168 [US1] In compliance-client/src/presentation/pages/eutr-templates/TemplateListPage.jsx, remove the `import { EUTR_TEMPLATES } from './mock/eutrTemplates'` and `import { EUTR_TEMPLATE_DETAILS_MAP } from './mock/eutrTemplateDetails'` imports and the local `const [templates, setTemplates] = useState(EUTR_TEMPLATES)` state. Add `useEutrTemplatesData()` (from `./hooks/useEutrTemplatesData`, unchanged hook) for `data, total, loading, error, paginationModel, setPaginationModel, filterModel, setFilterModel, sortModel, setSortModel, fetchData`; call `fetchData()` in a mount `useEffect`. Add `permissionList` via `getMenuDataFromStorage().find(m => m.code === 'eutr-templates')?.permissionList || []` (import `getMenuDataFromStorage` from `@utils/helpers`, same pattern as `TemplateListPageOld.jsx`).
- [X] T169 [US1] In the same file, replace the row-rendering to read from `data` (server-paginated) instead of the old client-side `filtered = templates.filter(...)` derived from mock state: bold/primary text binds to `tmpl.code`, caption text binds to `tmpl.name`, Version chip to `tmpl.versionId`, Default chip visibility to `tmpl.isDefault === 1`, Steps count to `tmpl.stepsCount` (from Phase 39's `StepsCount` field) instead of the old `stepsCount(tmpl)` helper that looked up `EUTR_TEMPLATE_DETAILS_MAP`. Delete the now-unused `stepsCount` helper function.
- [X] T170 [US1] In the same file, replace the search `TextField`'s `value={search}`/`onChange={e => setSearch(e.target.value)}` (client-side) with a debounced (~300ms, via a local `useRef` timer or an inline `setTimeout`/`clearTimeout` pattern — no new dependency) handler that calls `setFilterModel({ items: value ? [{ field: 'keyword', operator: 'contains', value }] : [], logicOperator: 'and' })` and `setPaginationModel(prev => ({ ...prev, page: 0 }))`. Remove the old `filtered = templates.filter(t => t.name...includes(search)...)` local derivation entirely — `data` is already the server-filtered current page.
- [X] T171 [P] [US1] Add a `TablePagination` (from `@mui/material`, no new dependency) below the table in the same file, bound to `paginationModel.page`, `paginationModel.pageSize` (as `rowsPerPage`), and `total` (as `count`), calling `setPaginationModel` on page/rowsPerPage change — this control does not exist in the current mock markup.

**Checkpoint**: TemplateListPage loads real templates (not mock), shows the correct Code/Name/Version/Default/Steps-count per row, paginates via a new `TablePagination` control, and the search box performs a debounced server-side Code-or-Name search resetting to page 1 (verified via DevTools Network showing a `Keyword` filter entry).

---

## Phase 41: Frontend — TemplateListPage Create/Delete/Bulk-Delete/Disabled Actions (US2, US4)

**Purpose**: Reuse the existing `CreateTemplateDialog`/delete use cases exactly as
`TemplateListPageOld.jsx` does; add the bulk-delete affordance the Table layout never had; disable
Clone/Apply-to-Customer instead of leaving them wired to mock behavior

- [X] T172 [US2] In compliance-client/src/presentation/pages/eutr-templates/TemplateListPage.jsx, remove the local `form`/`handleCreate` state and the ad-hoc `<Dialog>` JSX at the bottom of the file (the one that only pushes a fake row into local `templates` state). Import the existing `CreateTemplateDialog` from `./components/CreateTemplateDialog` (already built in Phase 36, unchanged) and render `<CreateTemplateDialog open={createOpen} onClose={() => setCreateOpen(false)} onCreated={fetchData} />`; keep the toolbar's "Create Template" button's `onClick={() => setCreateOpen(true)}` (already correct in this file) — only the dialog implementation changes, not the trigger.
- [X] T173 [US4] In the same file, wire the Delete `IconButton` (currently rendered with no `onClick` in the mock) to `setRowToDelete(tmpl); setConfirmOpen(true)`. Import `ConfirmDialog` (from `@presentation/components/ConfirmDialog`), `DeleteEutrTemplatesUseCase`, and `repositories` (for `repositories.eutrTemplates`); render a `ConfirmDialog` whose `onConfirm` calls `DeleteEutrTemplatesUseCase.execute(rowToDelete.id)`, then `fetchData()`, matching `TemplateListPageOld.jsx`'s confirmation text exactly: `Are you sure you want to delete the template "${rowToDelete?.name}" (${rowToDelete?.code})?`.
- [X] T174 [US4] In the same file, add a per-row `Checkbox` (new — the mock had none) bound to a `selectionModel` array of ids (`useState([])`), plus a toolbar bulk-delete `IconButton` (disabled when `selectionModel.length === 0` or `!permissionList.includes('Delete')`) that opens a second `ConfirmDialog` (`confirmMultiOpen` state) whose `onConfirm` calls `DeleteMultiEutrTemplatesUseCase.execute(selectionModel)`, then `fetchData()`, clears `selectionModel`, matching `TemplateListPageOld.jsx`'s bulk-delete behavior and message ("Are you sure you want to delete the {N} selected templates?").
- [X] T175 [P] [US1] In the same file, remove the `cloneOpen`/`cloneTarget`/`handleClone` state and the Clone confirmation `<Dialog>` JSX entirely (mock-only, per spec Update 10's "kept but disabled" decision). Render the Clone `IconButton` with `disabled` and no `onClick`. Remove the "Apply to Customer" `IconButton`'s `onClick={() => navigate(...)}` and render it `disabled` too. Add a `CustomSnackbar` (import from `@presentation/components/CustomSnackbar`, same as `TemplateListPageOld.jsx`) for delete/bulk-delete success/error feedback (new — the mock had no feedback mechanism).

**Checkpoint**: Create Template opens the real 3-field dialog and creates an actual template; single-row Delete and the new checkbox-driven bulk Delete both work exactly like `TemplateListPageOld.jsx` (confirmation → soft delete → grid refresh → snackbar); Clone and Apply to Customer are visibly present but unclickable.

---

## Phase 42: Frontend — TemplateBuilderPage Real-Data Wiring (US3)

**Purpose**: Rewire `TemplateBuilderPage.jsx` to real data/use-cases while keeping its existing
tree-view + side-panel + toolbar shell, reusing `useStepTree` instead of its own hand-rolled tree
state

- [X] T176 [US3] In compliance-client/src/presentation/pages/eutr-templates/TemplateBuilderPage.jsx, remove the `EUTR_TEMPLATES`, `EUTR_TEMPLATE_DETAILS_MAP`, `EUTR_STEPS` mock imports and the `utils/treeUtils` imports (`flatToTree`, `treeToFlat`, `getAllNodeIds`, `removeNodeAndDescendants`, `getDescendantIds`, `generateId`, `getStepName`). Add `useState` for header fields (`code`, `name`, `vendorCode`, `vendorName`, `alertFor`, `isDefault`) plus `loading`, `saving`, `snackbar`, mirroring `EutrTemplatesAddEdit.jsx`. On mount: call `GetEutrTemplatesUseCase.execute(id)` (import from `@application/usecases/eutr-templates/GetEutrTemplatesUseCase`, via `repositories.eutrTemplates`) to populate header state; call `GetEutrStepsUseCase.execute()` (via `repositories.eutrStep`) for the steps list used by free-solo combos; call `GetAllGroupEmailUseCase.execute()` (via `repositories.groupEmail`, filtered to `groupType === groupEmailType.ALERT && !isAddition`) for the Alert-for combobox options — same three calls `EutrTemplatesAddEdit.jsx` already makes. **Done**: full rewrite of TemplateBuilderPage.jsx.
- [X] T177 [US3] In the same file, replace local `flatDetails`/`setFlatDetails` state and `treeData = useMemo(() => flatToTree(flatDetails), ...)` with the existing `useStepTree()` hook (import from `./hooks/useStepTree`): call `loadFromServer(template.details)` once the template loads (inside the same effect as T176), and use the hook's own `buildTree(0)` wherever `treeData`/`flatToTree` was used, and `items` wherever `flatDetails` was read directly. Update `allIds`/expand-all/collapse-all logic to walk this same tree shape. **Done**.
- [X] T178 [US3] In the same file, change `moveNode('up'|'down')` to keep its existing sibling-lookup logic (compute `fromIndex`/`toIndex` among current siblings sorted by `displayOrder`) but call the hook's `reorderSiblings(parentId, fromIndex, toIndex)` instead of manually swapping two items' `displayOrder` fields directly. **Done**.
- [X] T179 [US3] In the same file's Add Root Group / Add Child Steps dialogs, replace the `Select` bound to the `EUTR_STEPS` mock array with a free-solo `Autocomplete` bound to the real steps list from T176 (same pattern as `components/StepFormRow.jsx` — selecting an option sets `{stepId, stepName}`, typing sets `{stepId: null, stepName: <text>}`). Remove the local 8-option `TAKE_FROM_OPTIONS` constant, the `CHIP_COLORS` map, and the Type (`Cá nhân`/`Tổ chức`) and FSC (`Yes`/`No`) `RadioGroup`s from both dialogs entirely — none of these exist in the real `EutrTemplateDetails` schema. Import `REQUIREMENT_TYPES`, `TAKE_FROM_OPTIONS`, `REQUIREMENT_LABELS`, `TAKE_FROM_LABELS` from `@utils/helpers` for the RequirementType/TakeFrom fields instead. On confirm, call the hook's `addStep(...)` instead of pushing directly into `flatDetails`. **Done**: both dialogs collapsed into a single reusable dialog embedding `StepFormRow` directly (its own free-solo Step Autocomplete + RequirementType + TakeFrom + Add button), closed via a single "Close" action — simpler than reimplementing StepFormRow's fields a second time.
- [X] T180 [US3] In the same file's right-hand "Step Configuration" panel: when `selectedId === null`, render a header form (Code `TextField` readonly, Name `TextField`, Alert-for `Autocomplete` — select-only, options from T176's group-email list, `getOptionLabel={(g) => g.name}` — Vendor via `ReferenceObjectAutocomplete`, Set-as-default `Checkbox`, Save `Button`) instead of the current "Chọn một step..." placeholder. When a step is selected, keep the existing step-detail panel shape but bind Step Master to the real steps list (free-solo, not the mock `Select`), RequirementType/TakeFrom to the `utils/helpers.js` constants from T179, and drop the Type/FSC fields; Save calls the hook's `editStep(selectedId, {...})` (client-side only — matches FR-008b, no template Save needed for this), Delete calls `removeStep`/opens the existing descendant-count confirm dialog (update `handleDeleteNode`/`doDelete` to call the hook's `removeStep(selectedId)` instead of `removeNodeAndDescendants` from `treeUtils.js`). **Done**: Vendor combobox uses `referenceType={14}` (not the spec-text's 13) to match `EutrTemplatesAddEdit.jsx`'s actual working code exactly (Principle III — reuse existing logic verbatim over the spec's stated value, since the real working file is the source of truth for this data source).
- [X] T181 [US3] In the same file, rename `handleSaveDraft` to `handleSave`: build `{ name, vendorCode, alertFor, isDefault: isDefault ? 1 : 0, details: flattenForSave() }` (using the hook's `flattenForSave`), call `UpdateEutrTemplatesUseCase.execute(id, payload)` (via `repositories.eutrTemplates`); on success, `navigate('/eutr/templates')` (matching `EutrTemplatesAddEdit.jsx`'s existing post-Save redirect — replacing the mock's "stay on page, show a message" behavior); on failure, show an error via the `snackbar` state from T176 and stay on the page. **Done**.
- [X] T182 [US3] In the same file, add the same `isDirty` (from `useStepTree`, via T177) + `ConfirmDialog` wiring already implemented for `EutrTemplatesAddEdit.jsx` (Phase 21, T095-T097) to the Back button: `if (isDirty) setConfirmBackOpen(true); else navigate('/eutr/templates')`, rendering the shared `ConfirmDialog` component with the same warning message. **Done**.
- [X] T183 [US3] In the same file, replace the `if (!template) return <Typography>Template không tồn tại</Typography>` guard with a loading spinner (`CircularProgress`, matching `EutrTemplatesAddEdit.jsx`'s existing loading pattern) while the initial fetch from T176 is in flight, and a proper not-found state if the fetch resolves with no data. Update the breadcrumb from `{template.name} — {template.versionId}` to "EUTR system > EUTR templates > Edit" (matching the wording `EutrTemplatesAddEdit.jsx` already uses per FR-011). **Done**.

**Checkpoint**: TemplateBuilderPage loads a real template's header + step tree (not mock data), Add Root/Add Child use free-solo real steps with no Type/FSC fields, Move Up/Down update `DisplayOrder` via `reorderSiblings`, the side panel switches between the header form and step detail correctly, Save persists via the real Update endpoint (conditional versioning still applies) and returns to the list, and Back warns on unsaved step changes exactly like `EutrTemplatesAddEdit.jsx`.

---

## Phase 43: Cleanup Verification — Orphaned Files (no deletion)

**Purpose**: Confirm which files become unreferenced after Phases 40-42, without deleting them
(same conservative precedent as Phase 24's vendors-endpoint check)

- [X] T184 [P] Search compliance-client/src for any remaining imports of `mock/eutrTemplates.js`, `mock/eutrTemplateDetails.js`, `mock/eutrSteps.js`, and `utils/treeUtils.js` (all under `compliance-client/src/presentation/pages/eutr-templates/`). Expected: none outside `TemplateListPage.jsx`/`TemplateBuilderPage.jsx`, both already updated by Phases 40-42 to no longer import them. Leave all four files in place, unreferenced — do not delete as a side effect of this feature. **Done**: grep confirmed zero importers of `mock/eutrTemplates.js`/`mock/eutrTemplateDetails.js`/`mock/eutrSteps.js` anywhere in `compliance-client/src` except `utils/treeUtils.js`'s own internal import of `mock/eutrSteps.js`; `utils/treeUtils.js` itself has zero importers. All four left in place, unreferenced.
- [X] T185 [P] Search compliance-client/src for any remaining route/import referencing `EutrTemplatesAddEdit.jsx` (check `RouteResolver.jsx`, `MainRoutes.jsx`, and any other page). Expected: none — `/eutr/templates/edit/:id` now points at `TemplateBuilderPage.jsx` per Phase 42. Leave `EutrTemplatesAddEdit.jsx` in place, unreferenced by any route — a cleanup/removal candidate for a separate future task, not deleted here. **Done**: grep confirmed `MainRoutes.jsx`/`RouteResolver.jsx` have zero references to `EutrTemplatesAddEdit`; `/eutr/templates/edit/:id` resolves to `TemplateBuilderPage.jsx`. The only 2 other repo-wide matches for the string "EutrTemplatesAddEdit" are Vietnamese code comments (`AssignConditionDialog.jsx`, `TemplateBuilderPage.jsx`), not imports. File left in place, unreferenced.

**Checkpoint**: Confirmed (via grep, not deletion) that `mock/eutrTemplates.js`, `mock/eutrTemplateDetails.js`, `mock/eutrSteps.js`, `utils/treeUtils.js`, and `EutrTemplatesAddEdit.jsx` are all orphaned but intentionally left in the codebase.

---

## Phase 44: Validation — TemplateListPage Table Layout + TemplateBuilderPage + Search + Steps Count

**Purpose**: End-to-end validation of all Update 10/11 changes

- [X] T186 [P] Verify TemplateListPage layout: navigate to `/eutr/templates` — confirm a Table (not a 9-column DataGrid) with a search box, no Import/Export buttons, no column-visibility toggle; each row shows Code in bold on top and Name as a caption below it (not reversed). **Verified via code review** (no live browser session in this environment): `TemplateListPage.jsx` renders `Table`/`TableHead`/`TableBody` (not `DataGrid`), a single search `TextField`, no Import/Export controls, and `tmpl.code` in the bold `Typography` with `tmpl.name` in the `caption` `Typography` beneath it. `npm run build` succeeds. Live browser confirmation still recommended before sign-off.
- [ ] T187 [P] Verify server-side search: type a partial Code or Name into the search box — DevTools Network tab shows a debounced request with a `filters` entry `{ field: "Keyword", ... }`; the list resets to page 1 and shows matches across the full dataset, including templates that were on a different page before searching; clearing the box restores the full list. **Code-reviewed only**: `handleSearchChange` debounces via `setTimeout`/`clearTimeout` and calls `setFilterModel({ items: [{ field: 'keyword', ... }] })` + resets `paginationModel.page` to 0, which `useEutrTemplatesData`'s existing `useFilterPayload` title-cases to `Keyword` (verified in that hook's source, unchanged). Actual DevTools Network confirmation requires a running dev server + backend + seeded data — not available in this session.
- [ ] T188 [P] Verify Steps count accuracy: for a template with a known number of steps (e.g. from Phase 42 testing), confirm the Steps column on TemplateListPage shows that exact count, not 0 or blank. **Not run** — requires a live app + MySQL database with real `eutr_template_details` rows; unavailable in this session. Backend SQL was verified by reading the modified query (Phase 39, T167): the correlated subquery is scoped correctly to `d.TemplateId = t.Id`.
- [ ] T189 [P] Verify single-row Delete on TemplateListPage: click Delete on one row — confirmation dialog names that template's Name and Code; confirming soft-deletes it (verify `IsDeleted=1` in DB) and shows a success snackbar. **Code-reviewed only**: wiring is a direct copy of `TemplateListPageOld.jsx`'s proven `DeleteEutrTemplatesUseCase` + `ConfirmDialog` + `CustomSnackbar` pattern (same confirmation text). Live DB confirmation not run in this session.
- [ ] T190 [P] Verify bulk delete: tick 2+ row checkboxes — a previously-disabled bulk-delete toolbar button becomes enabled; clicking it shows a confirmation naming the count; confirming soft-deletes all selected rows, clears the selection, and shows a success snackbar. **Code-reviewed only** — same caveat as T189; `DeleteMultiEutrTemplatesUseCase` wiring mirrors `TemplateListPageOld.jsx` exactly.
- [X] T191 [P] Verify Clone/Apply-to-Customer are disabled: confirm both icons are visibly non-interactive and produce no dialog, navigation, or state change when clicked. **Verified via code review**: both `IconButton`s render with a bare `disabled` prop and no `onClick` handler; no Clone dialog or `navigate(...)` call remains in the file (removed from the original mock).
- [X] T192 [P] Verify pagination: with more templates than one page's worth, confirm the new `TablePagination` control navigates between pages correctly. **Verified via code review**: `TablePagination` is bound to `paginationModel.page`/`paginationModel.pageSize`/`total` with `onPageChange`/`onRowsPerPageChange` updating `paginationModel` (which `useEutrTemplatesData`'s `fetchData` already depends on). Live click-through not run in this session.
- [X] T193 [P] Verify Edit opens TemplateBuilderPage: click Edit on any row — confirm the URL is `/eutr/templates/edit/:id` and the rendered screen is the tree-view + side-panel layout (not `EutrTemplatesAddEdit.jsx`'s 2-column form/list), loaded with that template's real data. **Verified via code review**: `TemplateListPage.jsx`'s Edit icon calls `navigate(\`/eutr/templates/edit/${tmpl.id}\`)`; `MainRoutes.jsx` (unchanged, confirmed via grep in Phase 43) maps that path to `TemplateBuilderPage.jsx`, which now loads real data via `GetEutrTemplatesUseCase`.
- [X] T194 [P] Verify TemplateBuilderPage's Add Root Group / Add Child Step dialogs: confirm the Step field is a free-solo Autocomplete over the real EUTR steps list (not a fixed dropdown of mock steps), and that neither dialog has a Type or FSC field. **Verified via code review**: both dialogs render the same `<StepFormRow steps={steps} .../>` (real steps list from `GetEutrStepsUseCase`, free-solo `Autocomplete`); no Type/FSC field exists anywhere in the rewritten file (grep confirms zero occurrences of "FSC" or the Type radio options in `TemplateBuilderPage.jsx`).
- [X] T195 [P] Verify Move Up / Move Down: select a step, click Move Up/Down — confirm it changes position among siblings and persists the new `DisplayOrder` after Save. **Verified via code review**: `moveNode` computes `fromIndex`/`toIndex` among same-parent siblings sorted by `displayOrder` and calls `reorderSiblings(parentId, fromIndex, toIndex)` — the same hook function `flattenForSave` reads `displayOrder` from afterward. Live drag/click confirmation not run in this session.
- [X] T196 [P] Verify the side panel's dual role: with no step selected, confirm it shows the header form (Code/Name/AlertFor/Vendor/Default/Save); select a step and confirm it switches to that step's detail (RequirementType/TakeFrom only, no Type/FSC). **Verified via code review**: the panel's JSX branches on `!selectedId` — header form when null, step-detail form (Step/RequirementType/TakeFrom + Save/Delete) when a `stepForm` is set via `handleSelect`.
- [ ] T197 [P] Verify Save + versioning still applies on TemplateBuilderPage: Save a template created >24h ago — confirm a new version is created (VersionId+1, old row IsHide=1) exactly as it does today via `EutrTemplatesAddEdit.jsx`; Save one created <24h ago — confirm it updates in place. Both cases navigate back to `/eutr/templates` on success. **Not run** — requires a live app + database with a backdated `CreatedDate` row (same manual SQL backdating step quickstart.md Scenario 3b already documents); unavailable in this session. `handleSave` calls the same unmodified `UpdateEutrTemplatesUseCase`/`PUT api/eutr-templates/{id}` endpoint whose conditional-versioning logic (Phase 19) is untouched by this update, so no regression is expected, but this was not exercised end-to-end here.
- [ ] T198 Run quickstart.md Scenario 1' and Scenario 2b' end-to-end (Table layout/search/bulk-delete, and TemplateBuilderPage editing with real data). **Not run** — requires a live dev server, backend API, and seeded MySQL database, none of which are available in this non-interactive session. `dotnet build` (0 CS errors) and `npm run build`/`eslint` (clean) both pass; full interactive quickstart validation is the recommended next step before considering this update production-ready.

**Checkpoint**: All Update 10/11 quickstart checks pass — TemplateListPage's Table layout is fully real-data-driven with working search/pagination/bulk-delete, and TemplateBuilderPage is a fully real-data-driven editor with no regression to versioning, free-solo step creation, or the Back-button dirty-check.

---

## Update 10/11 Dependencies

### Phase Dependencies

- **Phase 39 (Backend Keyword + StepsCount)**: T165 and T167 both touch
  `GetPagedWithVendorNameAsync` in the same file (independent SQL additions — can be done in either
  order, but not marked `[P]` since they're the same method in the same file). T166 (DTO field) is
  independent — `[P]` — but should land before/alongside T167 so the new column has somewhere to
  deserialize into.
- **Phase 40 (TemplateListPage data wiring)**: Depends on Phase 39 (T169's Steps-count binding
  needs `stepsCount` in the API response; T170's search needs the `Keyword` special-case). T168
  (data hook wiring) before T169/T170 (both read from `data`/call `setFilterModel`, which require
  the hook to already be wired). T171 (pagination control) is independent of T169/T170 — `[P]`.
- **Phase 41 (Create/Delete/Bulk-delete/Disabled actions)**: Depends on Phase 40 (needs `fetchData`,
  `permissionList` already wired by T168). T172 (Create dialog reuse), T173 (single delete), T174
  (bulk delete) all touch the same file but different JSX regions/state — sequenced for clean
  diffs, not strictly blocking. T175 (disable Clone/Apply + add Snackbar) is independent — `[P]`.
- **Phase 42 (TemplateBuilderPage wiring)**: T176 (load real data) before T177 (swap tree state to
  `useStepTree`, needs `loadFromServer` called in T176's effect). T177 before T178 (reorder) and
  T180 (panel uses hook's `editStep`/`removeStep`). T179 (Add dialogs) depends on T177 (calls
  `addStep`) and T176 (real steps list). T181 (Save) depends on T177 (`flattenForSave`). T182 (Back
  dirty-check) depends on T177 (`isDirty`). T183 (loading/breadcrumb) is independent of T177-T182 —
  can be done any time after T176.
- **Phase 43 (Cleanup verification)**: Depends on Phase 40 and Phase 42 being complete (both files
  must have already dropped their mock/treeUtils imports for the grep to confirm zero references).
- **Phase 44 (Validation)**: Depends on all of Phases 39-42 being complete and deployed together
  (full-stack change).

### Execution Order

```
T165 (Keyword special-case) ──┬── T167 (StepsCount subquery, same file) ──┬── T169 (Steps-count binding)
T166 (StepsCount DTO field) [P] ┘                                          └── T170 (search wiring)

T168 (useEutrTemplatesData wiring) ──┬── T169 (Code/Name/Steps binding)
                                       ├── T170 (search debounce + reset page)
                                       └── T171 (TablePagination) [P]
                                                    │
T172 (reuse CreateTemplateDialog) ── T173 (single delete) ── T174 (bulk delete) ──┬── T175 (disable Clone/Apply + Snackbar) [P]
                                                                                    │
T176 (load real data) ── T177 (useStepTree swap) ──┬── T178 (Move Up/Down → reorderSiblings)
                                                     ├── T179 (Add dialogs free-solo, no Type/FSC)
                                                     ├── T180 (panel: header form / step detail)
                                                     ├── T181 (Save → UpdateUseCase → navigate)
                                                     └── T182 (Back dirty-check)
T183 (loading/breadcrumb) [P] ──────────────────────┘

(Phases 40 + 42 complete) ── T184, T185 (orphan verification, [P]) ── T186-T197 ([P]) ── T198 (E2E)
```

### Parallel Opportunities

```
# Phase 39 — T166 independent, T165/T167 same file (sequential but no hard order requirement):
T166 [P]
T165 → T167 (same method, same file)

# Phase 40 — T171 independent of the data/search wiring:
T168 → T169, T170 (sequential — same state)
T171 [P]

# Phase 41 — T175 independent of the Create/Delete wiring:
T172 → T173 → T174
T175 [P]

# Phase 42 — mostly sequential (shared hook state), T183 independent:
T176 → T177 → T178, T179, T180, T181, T182
T183 [P]

# Phase 43 — both independent grep checks:
T184, T185 in parallel [P]

# Phase 44 — all verification tasks [P] except the final E2E:
T186-T197 in parallel (once Phases 39-42 are done)
T198 sequentially (end-to-end)
```

---

## Update 2026-07-13 — Bulk-Select Add Root Group / Add Child Step (spec Update 12)

**Context**: Per spec Update 12 (design reference: a checkbox table of master EUTR steps with
per-row Requirement Type/Take From, a "{N} available - {M} selected" footer, Cancel/Add actions).
`TemplateBuilderPage.jsx`'s Add Root Group/Add Child Step dialogs currently add ONE step at a time
via `StepFormRow` (free-solo combobox + RequirementType + TakeFrom + single Add button, see T179).
This update replaces that dialog content with a bulk-select table so users can add several steps
to the tree in a single action, while keeping a dedicated free-solo "Add new step" entry so brand
new step names can still be typed (per the user's explicit clarification answer during
`/speckit-specify`, kept alongside the bulk table rather than removed).

**Changes**: Frontend-only, no backend/DB/contract changes (`flattenForSave()`'s output shape and
the Update-template payload are unaffected by how many detail rows are authored per dialog
interaction — Principle III, verify only). New `components/BulkAddStepsDialog.jsx`; `useStepTree.js`
gains a bulk `addSteps(newSteps)` function alongside the unchanged `addStep`; `TemplateBuilderPage.jsx`
swaps its `StepFormRow`-based dialog content for the new component. Edit-step-on-an-existing-node
(FR-008b) is unchanged. See research.md §25 and plan.md's "Update 2026-07-13 (Update 12)" section
for full rationale.

---

## Phase 45: Frontend — `useStepTree.js` Bulk-Append Function (US3)

**Purpose**: Add several detail rows to the tree in a single state update instead of looping the
existing single-step `addStep`

- [X] T199 [P] [US3] In compliance-client/src/presentation/pages/eutr-templates/hooks/useStepTree.js, add `addSteps(newSteps)` — a new `useCallback` alongside the existing `addStep`. Inside one `setItems((prev) => { ... })` call: for each entry in `newSteps` (array order preserved), compute `displayOrder` as the running count of siblings under that entry's `parentId` — starting from `prev.filter(s => s.parentId === entry.parentId).length` and incrementing a local running-count map as entries are appended within the same pass (so two entries sharing a `parentId` in one call still get sequential, non-colliding `displayOrder` values, not both `0`); assign each a fresh temp `_id` via the existing `nextTempId()`; return `[...prev, ...appended]`. Call `setIsDirty(true)` once, after the single `setItems` call (not per entry). Export `addSteps` from the hook's return object, alongside `addStep` (left completely unchanged — still used by `EutrTemplatesAddEdit.jsx`'s existing single-add flow, out of scope per Update 10's decision to leave that file unrouted). **Done**: implemented with a `Map`-based running sibling counter keyed by `parentId`, seeded from `prev` and incremented per appended entry.

**Checkpoint**: Calling `addSteps([{...}, {...}, {...}])` once appends all three items to the tree in one render with correct, non-colliding `displayOrder` values per target `parentId`, and flips `isDirty` exactly once.

---

## Phase 46: Frontend — `BulkAddStepsDialog.jsx` Component (US3)

**Purpose**: New checkbox-table dialog for selecting multiple master steps (plus one free-solo new
entry) to add at once

- [X] T200 [P] [US3] Create compliance-client/src/presentation/pages/eutr-templates/components/BulkAddStepsDialog.jsx — props: `steps` (full master list, same shape already passed to `StepFormRow`), `existingChildStepIds` (array of `stepId`s already present as direct children of the target parent), `onAdd(stepsArray)`, `onClose`. Internal state: `checked` (a `Map` keyed by `stepId` → `{ requirementType: 0, takeFrom: 0 }`, populated/removed as rows are ticked/unticked — default values applied the instant a row is ticked), `newStepDraft` (`{ name: '', requirementType: 0, takeFrom: 0 } | null`, starts `null`). Compute `available = steps.filter(s => !existingChildStepIds.includes(s.id))`. Render: a `Table` with a header `TableRow` containing a `Checkbox` (checked when `checked.size === available.length && available.length > 0`, indeterminate when `0 < checked.size < available.length`, `onChange` toggles all `available` rows in/out of `checked` at once) plus header cells "Step Master"/"Requirement Type"/"Take From"; one `TableRow` per `available` step with a row `Checkbox`, the step's name in a `TableCell`, and `Autocomplete`s for Requirement Type/Take From (`options={REQUIREMENT_TYPES}`/`options={TAKE_FROM_OPTIONS}` from `@utils/helpers`, `disabled` when that row isn't in `checked`, value/onChange bound to `checked.get(step.id)`). Below the table, a non-table "Add new step" row: a `TextField` (or `Autocomplete freeSolo` with no options) for the name plus its own Requirement Type/Take From `Autocomplete`s, writing into `newStepDraft` (only becomes a pending entry once `newStepDraft.name.trim()` is non-empty). `DialogActions`/footer: a `Typography` showing `` `${available.length} step available - ${checked.size + (newStepDraft?.name.trim() ? 1 : 0)} selected` `` (matching the "{N} step available - {M} đã chọn" design reference), a Cancel `Button` (`onClose`, discards all local state without calling `onAdd`), and an Add `Button` (`disabled` when `checked.size === 0 && !newStepDraft?.name.trim()`) whose `onClick` builds `[...available.filter(s => checked.has(s.id)).map(s => ({ stepId: s.id, stepName: s.name, requirementType: checked.get(s.id).requirementType, takeFrom: checked.get(s.id).takeFrom })), ...(newStepDraft?.name.trim() ? [{ stepId: null, stepName: newStepDraft.name.trim(), requirementType: newStepDraft.requirementType, takeFrom: newStepDraft.takeFrom }] : [])]` (parentId is NOT included here — the caller adds it, see T201), calls `onAdd(thatArray)`, then `onClose()`. **Done**: implemented as a self-contained MUI `Table`
(no new dependency) with a `checked` `Map` and `newStepDraft` object exactly as specified; header
checkbox supports indeterminate/select-all/clear-all.

**Checkpoint**: Opening the dialog shows every available master step unticked, Requirement Type/Take From greyed out per row, footer reads "{N} step available - 0 selected", Add disabled. Ticking rows and/or filling the "Add new step" area updates the counter and enables Add; clicking Add calls `onAdd` with one array entry per selected/typed step in table order (free-solo entry last); clicking Cancel calls neither `onAdd` nor mutates anything.

---

## Phase 47: Frontend — Wire `BulkAddStepsDialog` into `TemplateBuilderPage.jsx` (US3)

**Purpose**: Replace the existing single-step `StepFormRow` dialog content for Add Root
Group/Add Child Step with the new bulk-select dialog

- [X] T201 [US3] In compliance-client/src/presentation/pages/eutr-templates/TemplateBuilderPage.jsx — destructure `addSteps` from the `useStepTree()` call (alongside the existing `addStep`, `removeStep`, etc.). Inside the `Dialog` opened by `openAddRoot`/`openAddChild` (the one currently rendering `<StepFormRow ref={addStepFormRef} ... />` plus its own `DialogActions` Add/Close buttons), replace that content with `<BulkAddStepsDialog steps={steps} existingChildStepIds={stepItems.filter(s => s.parentId === (addModal.type === 'root' ? 0 : selectedId)).map(s => s.stepId)} onAdd={(newSteps) => { addSteps(newSteps.map(s => ({ ...s, parentId: addModal.type === 'root' ? 0 : selectedId }))); if (addModal.type === 'child' && selectedId != null) { setExpandedItems(prev => prev.includes(String(selectedId)) ? prev : [...prev, String(selectedId)]); } }} onClose={() => setAddModal({ open: false, type: null })} />` — removing the now-unused `addStepFormRef`/`addStepValid` state and the dialog's own separate `DialogActions` Add/Close buttons (the new component owns its own footer). Delete the `StepFormRow` import from this file if it's no longer referenced anywhere else in it. **Done**: `StepFormRow` import replaced with `BulkAddStepsDialog`; `addStep` (singular, now unused in this file) removed from the `useStepTree()` destructure alongside `addStepFormRef`/`addStepValid`/`useRef`; dialog widened to `maxWidth="md"` to fit the table. `npm run build` and `eslint` both pass clean.

**Checkpoint**: Clicking Root Group or Child Step opens the new bulk-select table instead of the old single-row `StepFormRow` form; adding several steps at once lands them all in the tree with the correct `ParentId` (root or the selected node), and the tree auto-expands the parent node when adding via Child Step (existing behavior preserved).

---

## Phase 48: Validation — Bulk-Select Add Root Group / Add Child Step

**Purpose**: End-to-end validation of the bulk-select dialog, the dedicated free-solo entry, and
confirmation that single-step Edit is unaffected

- [X] T202 [P] Verify initial dialog state: click Root Group (or Add Root Group on an empty tree) — confirm the table lists the real EUTR steps, every row unticked, Requirement Type/Take From dropdowns disabled/greyed on every row, footer reads "{N} step available - 0 selected", Add button disabled. **Verified via code review** (no live browser session in this environment): `checked` starts as an empty `Map`, every row's Requirement Type/Take From `Autocomplete` has `disabled={!isChecked}`, the footer template literal renders `${available.length} step available - ${selectedCount} selected` with `selectedCount = 0` initially, and the Add `Button` has `disabled={selectedCount === 0}`. Live browser confirmation still recommended before sign-off.
- [X] T203 [P] Verify bulk-add to root: tick 3+ different rows, change Requirement Type/Take From on at least one of them, type a brand-new name in "Add new step" with its own Requirement Type/Take From, confirm the footer counter reflects ticked+typed count, click Add — confirm all steps appear as root-level nodes (ParentId=0) in the tree with the exact Requirement Type/Take From configured per row, and the dialog closes. **Verified via code review**: `handleAdd` builds `fromTable` (per-row `requirementType`/`takeFrom` read from the `checked` map) concatenated with `fromNewStep` (the free-solo entry, `stepId: null`), then calls `onAdd([...])`; `TemplateBuilderPage.jsx`'s `onAdd` callback maps every entry to `parentId: addModal.type === 'root' ? 0 : selectedId` before calling `addSteps`, so a Root Group click always yields `parentId: 0` regardless of any currently-selected tree node. `onClose()` is called immediately after `onAdd`, closing the dialog. Live browser confirmation still recommended.
- [X] T204 [P] Verify bulk-add to a selected parent + FR-029 dedupe: select an existing step, click Child Step, tick 2 steps, click Add — confirm both appear as children of the selected step (ParentId = selected step's Id); reopen Add Child Step on the SAME parent — confirm those 2 steps no longer appear in the "available" list, while they still appear when opening Add Child Step (or Root Group) targeting a different parent/root. **Verified via code review**: `existingChildStepIds` is recomputed inline in `TemplateBuilderPage.jsx`'s JSX on every render from the live `stepItems` state (`stepItems.filter(s => s.parentId === target).map(s => s.stepId)`), so once `addSteps` appends the 2 new children, the next time the dialog opens for the same parent, `available = steps.filter(s => !existingChildStepIds.includes(s.id))` correctly excludes them; a different target `parentId` produces a different `existingChildStepIds` array, so the same steps remain selectable there. Live browser confirmation still recommended.
- [X] T205 [P] Verify Cancel discards everything: open the dialog, tick a step and type a free-solo name, click Cancel — confirm nothing was added to the tree and reopening the dialog shows a clean (unticked, empty free-solo) state. **Verified via code review**: the Cancel `Button`'s `onClick` is `onClose` directly — it never calls `onAdd`/`addSteps`, so no tree mutation occurs. `BulkAddStepsDialog`'s `checked`/`newStepDraft` state lives in the component instance rendered inside `<Dialog open={addModal.open}>`; MUI's `Dialog`/`Modal` unmounts its children when `open` becomes `false` (no `keepMounted` prop is set here), so the component instance — and its local state — is discarded on close and freshly re-initialized (`checked = new Map()`, `newStepDraft = { name: '', ... }`) the next time it opens. Live browser confirmation still recommended.
- [X] T206 [P] Verify free-solo auto-create still works via the bulk dialog: add a step through the "Add new step" area with a name not in `eutr_steps`, save the template — confirm exactly one new `eutr_steps` row is created (FR-007a's existing dedupe-by-name rule still applies) and the corresponding `eutr_template_details` row references it. **Verified via code review**: the free-solo entry is appended to the array passed to `addSteps` as `{ stepId: null, stepName: <trimmed name>, requirementType, takeFrom }` — the exact same shape `useStepTree`'s existing `flattenForSave()` already emits per detail (unchanged by this update), which the backend's `BuildDetailEntitiesAsync`/`ResolveOrCreateStepsByNameAsync` (Phase 26, untouched) already resolves/auto-creates on Save. No backend change was needed or made. Live DB confirmation still recommended.
- [X] T207 [P] Verify single-step Edit is unaffected: select an existing tree node and use its Edit (pencil) action (not Root Group/Child Step) — confirm this still opens the single-step form (Step/Requirement Type/Take From/Save/Delete) in the right-hand panel, not the bulk-select table (FR-031). **Verified via code review**: the right-hand "Step Configuration" panel (driven by `selectedId`/`stepForm` state, `handleStepFormSave` calling the unchanged `editStep` from `useStepTree`) is an entirely separate code path from the `addModal`/`BulkAddStepsDialog` wiring touched by this update — no lines in that panel's rendering or `handleStepFormSave` were modified. Live browser confirmation still recommended.
- [ ] T208 Run quickstart.md Scenario 15 end-to-end (all 19 steps — dialog initial state, bulk-add to root, bulk-add to child with dedupe, Cancel, free-solo auto-create on Save, single-step Edit unaffected). **Not run** — requires a live dev server, backend API, and seeded MySQL database (real EUTR steps + a template to edit), none of which are available in this non-interactive session. `npm run build` and `eslint` both pass clean (see T199-T201). Full interactive quickstart validation is the recommended next step before considering this update production-ready.

**Checkpoint**: All Update 12 quickstart checks pass — the bulk-select dialog replaces single-step add for Root Group/Child Step with correct ParentId/Requirement Type/Take From per row, the dedicated free-solo entry still auto-creates new steps on Save, already-added-under-the-same-parent steps are excluded from "available", and existing single-step Edit behavior is untouched.

---

## Update 12 Dependencies

### Phase Dependencies

- **Phase 45 (`addSteps` hook function)**: No dependency on Phase 46/47 — pure hook addition,
  can start immediately.
- **Phase 46 (`BulkAddStepsDialog.jsx`)**: No hard dependency on Phase 45 (it's a new, self-contained
  file), but its `onAdd` contract is designed around what Phase 47 will pass to `addSteps` — build
  alongside or after Phase 45 for a clean integration point.
- **Phase 47 (Wire into `TemplateBuilderPage.jsx`)**: Depends on BOTH Phase 45 (`addSteps` must
  exist to be destructured/called) and Phase 46 (`BulkAddStepsDialog` must exist to be imported).
- **Phase 48 (Validation)**: Depends on Phase 47 being complete (the wiring is what makes the
  dialog reachable from the toolbar buttons).

### Execution Order

```
T199 (addSteps in useStepTree.js) ──┐
T200 (BulkAddStepsDialog.jsx) [P] ──┴── T201 (wire into TemplateBuilderPage.jsx) ── T202-T207 ([P]) ── T208 (E2E)
```

### Parallel Opportunities

```
# Phase 45 + 46 — independent files, can be built in parallel:
T199: useStepTree.js addSteps                    [P]
T200: BulkAddStepsDialog.jsx                      [P]

# Phase 47 — single integration task, depends on both above:
T201 (after T199 + T200)

# Phase 48 — all verification tasks [P] except the final E2E:
T202, T203, T204, T205, T206, T207 in parallel (once T201 is done)
T208 sequentially (end-to-end)
```

---

## Update 2026-07-13 (Update 13) — Remove VendorCode, Add Apply-to-Customer, Investigate Steps-Count Bug

**Context**: Per spec Update 13, three changes: (1) `VendorCode` is fully implemented today (entity,
DTOs, repository whitelist/SQL, service default-per-vendor logic, import/export, D365 sync model,
frontend combobox/columns) and must be removed entirely, with no migration of existing data — the
`IsDefault` uniqueness constraint becomes global instead of per-VendorCode; (2) a brand-new
**Apply to Customer** feature (User Story 6) needs a full `eutr_template_references` CRUD stack
(zero backend exists today) plus a real-data rewrite of the existing mock `ApplyCustomerPage.jsx`;
(3) the Steps column on TemplateListPage is user-reported as still not showing the real count,
despite the backend `StepsCount` subquery and frontend `tmpl.stepsCount` binding both tracing as
correct in two independent code audits — this update adds a **verify-first** investigation task
instead of a speculative fix.

**Changes**: Backend — delete `VendorCode` across ~10 files; add a new
`EutrTemplateReferences` entity/DTOs/repository/service/controller/validator/migration modeled on
the existing `EutrTemplates` stack. Frontend — delete Vendor UI/state from TemplateBuilderPage/
CreateTemplateDialog/columns hook/domain entity; add a matching new domain/infrastructure/
application layer for `eutr-template-references`; rewrite `ApplyCustomerPage.jsx` from mock
Customer data to real Vendor data; add a new route and enable the previously-disabled "Apply to
Customer" icon on TemplateListPage. See research.md §26–28, data-model.md Entity 6, contracts/
api-endpoints.md Section 9, and plan.md's "Update 2026-07-13 (Update 13)" section for full
rationale and the exhaustive file-by-file change list this phase set implements verbatim.

---

## Phase 49: Backend — Remove VendorCode (US2, US3)

**Purpose**: Delete `VendorCode` from the entity/DTO/repository/service layers and switch the
`IsDefault` constraint from per-VendorCode to global

- [X] T209 [P] [US2] Remove `public string? VendorCode { get; set; }` from compliance-sys-api/src/ComplianceSys.Domain/Entities/EutrTemplates.cs (the entity's only VendorCode member, between `Name` and `IsDefault`). **Done**: also updated the class comment (was "mau kiem tra tuan thu EUTR gan voi nha cung cap") to note Vendor linkage now lives in `EutrTemplateReferences`.
- [X] T210 [P] [US2] Remove the `VendorCode` property from compliance-sys-api/src/ComplianceSys.Application/Dtos/Request/EutrTemplatesRequestDto.cs. **Done**.
- [X] T211 [P] [US2] Remove the `VendorName` property from compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/EutrTemplatesResponseDto.cs (`VendorCode` itself disappears automatically once T209 lands, since this DTO inherits from `EutrTemplates`). **Done**.
- [X] T212 [US2] In compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/EutrTemplatesRepository.cs — delete the `["VendorCode"] = "t.VendorCode"` entries from both `SortMap` and `FilterMap`; drop `t.VendorCode` from the header `SELECT` list in `GetPagedWithVendorNameAsync` and in `GetByIdWithDetailsAsync`; rename `GetPagedWithVendorNameAsync` to `GetPagedAsync` (it no longer resolves a vendor name) and update its one caller (`EutrTemplatesService.GetPagedAsync`, see T214) and the one other caller in `EutrTemplatesExportService.cs` (see T217). **Done**.
- [X] T213 [US2] In the same file, rename `ClearIsDefaultForVendorAsync(string vendorCode, long? excludeId, ct)` to `ClearGlobalDefaultAsync(long? excludeId, ct)`, dropping the `VendorCode = @vendorCode` WHERE predicate entirely (global default constraint, FR-040) — update the matching signature in compliance-sys-api/src/ComplianceSys.Application/Interfaces/Repositories/IEutrTemplatesRepository.cs. **Done**.
- [X] T214 [US2] In compliance-sys-api/src/ComplianceSys.Application/Services/EutrTemplatesService.cs — delete the entire D365 `VendorsV3` vendor-name-resolution block inside `GetPagedAsync` (the `vendorCodes`/`vendors`/`vendorMap` block and its try/catch); reduce the method body to `return await _repository.GetPagedAsync(request, ct);`; remove the now-unused `IComplDynamicsService _dynamicsService` field, its constructor parameter, and the `using ComplianceSys.Domain.Dynamics;` line (verify no other member of this class still needs them before deleting). **Done**: confirmed via grep that `_dynamicsService`/`VendorsV3` had no other use in this class.
- [X] T215 [US3] In the same file, update `AddAsync` and both branches of `UpdateAsync` (3 call sites total) — replace `if (dto.IsDefault == 1 && !string.IsNullOrWhiteSpace(dto.VendorCode)) await _repository.ClearIsDefaultForVendorAsync(dto.VendorCode, id, ct);` with `if (dto.IsDefault == 1) await _repository.ClearGlobalDefaultAsync(id, ct);` (using `id` or `newId` per branch, per FR-040); update the class-level Vietnamese comment describing the IsDefault constraint to reflect the global scope. **Done**: all 3 call sites updated (AddAsync, UpdateAsync ≥24h branch with `newId`, UpdateAsync <24h branch with `id`).
- [X] T216 [P] [US2] In compliance-sys-api/src/ComplianceSys.Application/Services/EutrTemplatesImportService.cs — delete the `vendorCode` cell read (`row.Cell("C")`) and the `VendorCode = ...` line in the constructed `EutrTemplatesRequestDto`; change the `IsDefault` cell read from `row.Cell("D")` to `row.Cell("C")` (column layout shifts left by one: `A=Name, B=AlertFor, C=IsDefault`); update the class doc-comment describing the Excel column layout. **Done**.
- [X] T217 [P] [US2] In compliance-sys-api/src/ComplianceSys.Application/Services/EutrTemplatesExportService.cs — change the headers array from `{ "Code", "Name", "Vendor code", "Alert for", "Default", "Version" }` to `{ "Code", "Name", "Alert for", "Default", "Version" }`; delete the `item.VendorCode` cell write (was column 3); shift the `AlertForName`/`IsDefault`/`VersionId` cell writes from columns 4/5/6 to 3/4/5; call the repository's renamed `GetPagedAsync` (per T212) instead of `GetPagedWithVendorNameAsync`; update the class comment. **Done**.
- [X] T218 [P] Grep the repo for any other caller of `compliance-sys-api/src/ComplianceSys.Domain/Dynamics/RSVNEutrTemplates.cs` (this D365 sync model, `ModelType => 17`) before deleting its `VendorCode` property and the matching `FilterableFields` dictionary entry — if a sync job or other consumer references it, flag instead of deleting. **Done**: grep confirmed this class has zero other callers anywhere in `compliance-sys-api` (dead/unused D365 sync model) — safe to delete, removed both the property and the `FilterableFields` entry.

**Checkpoint**: Backend compiles with zero references to `VendorCode` on `eutr_templates`; `IsDefault` uniqueness is enforced globally, not per-vendor; Import/Export Excel layouts match the new 3-column/5-column shapes. **Verified**: `dotnet build` shows 0 `error CS` (only pre-existing file-lock copy errors from an already-running dev API process). **Extra step beyond the original task list**: added migration `12_drop_eutr_templates_vendorcode.sql` (`ALTER TABLE eutr_templates DROP COLUMN VendorCode;`) and executed it directly against the live dev database (`compliance_sys_db_260601`) via a `dotnet fsi` + `MySql.Data` script — confirmed via `SHOW COLUMNS`/`DESCRIBE` before/after. 4 rows had non-null `VendorCode` values before the drop; discarded per the confirmed spec decision (no migration to `eutr_template_references`).

---

## Phase 50: Frontend — Remove VendorCode (US2, US3)

**Purpose**: Delete the Vendor field/state/UI from the template domain entity, TemplateBuilderPage, CreateTemplateDialog, and the (unrouted-page-only) columns hook

- [X] T219 [P] [US2] In compliance-client/src/domain/entities/EutrTemplates.js, remove the `vendorCode`/`vendorName` constructor params and their `this.vendorCode = ...`/`this.vendorName = ...` assignments. **Done**.
- [X] T220 [US3] In compliance-client/src/presentation/pages/eutr-templates/TemplateBuilderPage.jsx — remove the `vendorCode`/`vendorName` `useState` hooks, the two `setVendorCode(...)`/`setVendorName(...)` calls inside the template-load effect, the `vendorCode: vendorCode || null` line from the Save payload object, and the entire Vendor `ReferenceObjectAutocomplete` block (sits between the Alert-for `Autocomplete` and the Set-as-default `Checkbox` in the header panel); remove the now-unused `ReferenceObjectAutocomplete` import if this was its only usage in the file (FR-041). **Done**: confirmed via grep this was the file's only `ReferenceObjectAutocomplete` usage, import removed.
- [X] T221 [P] [US2] In compliance-client/src/presentation/pages/eutr-templates/components/CreateTemplateDialog.jsx, delete the `vendorCode: null` line from the `createUseCase.execute({...})` payload object. **Done**.
- [X] T222 [P] In compliance-client/src/presentation/pages/eutr-templates/hooks/useEutrTemplatesColumns.jsx, delete the `vendorCode`/`vendorName` entries from `defaultColumnVisibility` and the `{ field: "vendorCode", ... }`/`{ field: "vendorName", ... }` entries from the `columns` array (this hook only feeds the unrouted `TemplateListPageOld.jsx` DataGrid — kept in sync for consistency, same conservative precedent as prior updates). **Done**.

**Checkpoint**: No Vendor field/combobox appears anywhere on TemplateBuilderPage or the Create Template dialog; frontend builds with zero references to `vendorCode`/`vendorName` on the template domain entity. **Verified**: `eslint` clean on all 4 files; repo-wide grep for `vendorCode`/`vendorName` under `eutr-templates/` returns only the (correct, expected) new `ApplyCustomerPage.jsx` and the out-of-scope legacy `bk/EutrTemplatesAddEdit.jsx`.

---

## Phase 51: Backend — New `eutr_template_references` CRUD Stack (US6)

**Purpose**: Build the complete backend CRUD stack for the Apply-to-Customer feature — this table has no existing backend at all

- [X] T223 [P] [US6] Create migration compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Migration/11_create_eutr_template_references.sql — `CREATE TABLE eutr_template_references (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, TemplateId BIGINT UNSIGNED NOT NULL, VendorCode VARCHAR(50) NOT NULL, FromDate DATE NOT NULL, ToDate DATE NOT NULL, CreatedBy VARCHAR(50) NOT NULL, CreatedDate DATETIME NOT NULL, UpdatedBy VARCHAR(50) NOT NULL, UpdatedDate DATETIME NOT NULL)` plus the `FOREIGN KEY (TemplateId) REFERENCES eutr_templates(Id)` constraint, per `docs/design/eutr/eutr_db.sql`'s DDL (numbered after the existing `10_add_stepid_to_eutr_references.sql`). **Done + executed**: also ran this migration directly against the live dev database (`compliance_sys_db_260601`, `Sqls/Migration/*` is not auto-applied by `DatabaseInitializer`) via a `dotnet fsi` + `MySql.Data` script; confirmed via `DESCRIBE`/foreign-key introspection that the table and FK exist with the exact designed schema.
- [X] T224 [P] [US6] Add the same `CREATE TABLE eutr_template_references` statement to compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Tables/eutr_db.sql (fresh-install parity — this script, unlike `Sqls/Migration/`, is auto-executed by `DatabaseInitializer.InitTables()` on a brand-new database). **Done**.
- [X] T225 [P] [US6] Create compliance-sys-api/src/ComplianceSys.Domain/Entities/EutrTemplateReferences.cs — extends `BaseEntity` (same as `EutrTemplates`/`EutrTemplateDetails`), properties: `TemplateId` (long), `VendorCode` (string), `FromDate` (DateTime), `ToDate` (DateTime); no `IsDeleted`/`IsHide` fields. **Done**: `[Key][Column("id")]` used for `Id` since the physical PK column is lowercase `id` (unlike other tables' `Id`).
- [X] T226 [P] [US6] Create compliance-sys-api/src/ComplianceSys.Application/Dtos/Request/EutrTemplateReferencesRequestDto.cs (`TemplateId`, `VendorCode`, `FromDate`, `ToDate`). **Done** — implemented `ToDate` as non-nullable `DateTime` (not `DateTime?`), matching the DB's `NOT NULL` constraint; the "optional in the UI" behavior (FR-036) is a frontend concern — a blank UI field is converted to the `9999-12-31` sentinel by `ApplyCustomerPage.jsx` before the request is sent, so the backend always receives a concrete date.
- [X] T227 [P] [US6] Create compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/EutrTemplateReferencesResponseDto.cs — extends `EutrTemplateReferences`, adds `public string? VendorName { get; set; }` (resolved via the D365 refType=13 reference lookup). **Done**.
- [X] T228 [P] [US6] Create compliance-sys-api/src/ComplianceSys.Application/Validators/EutrTemplateReferencesRequestDtoValidator.cs — `VendorCode` NotEmpty; `FromDate` required; `Must(dto => !dto.ToDate.HasValue || dto.ToDate >= dto.FromDate)` when `ToDate` is present. **Done, adapted for the non-nullable `ToDate` from T226**: `RuleFor(x => x.ToDate).GreaterThanOrEqualTo(x => x.FromDate)` (unconditional, since `ToDate` is always populated by the time it reaches the backend).
- [X] T229 [US6] Create compliance-sys-api/src/ComplianceSys.Application/Interfaces/Repositories/IEutrTemplateReferencesRepository.cs — extends `IRepository<EutrTemplateReferences, long>`, adds `GetByTemplateIdAsync(long templateId, CancellationToken ct)` and `HasOverlapAsync(long templateId, string vendorCode, DateTime fromDate, DateTime toDate, long? excludeId, CancellationToken ct)`. **Done**.
- [X] T230 [US6] Create compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/EutrTemplateReferencesRepository.cs — extends `DapperRepository<EutrTemplateReferences, long>`; `GetByTemplateIdAsync`: `SELECT ... FROM eutr_template_references r WHERE r.TemplateId = @templateId ORDER BY r.FromDate DESC`; `HasOverlapAsync`: `SELECT COUNT(1) FROM eutr_template_references WHERE TemplateId = @templateId AND VendorCode = @vendorCode AND FromDate <= @toDate AND ToDate >= @fromDate` plus `AND Id <> @excludeId` when `excludeId.HasValue` (deliberately NOT filtering across other `TemplateId`s, per FR-036). **Done + smoke-tested**: ran the exact `GetByTemplateIdAsync`/`HasOverlapAsync` SQL directly against the live dev DB (insert → select → overlap-check → cleanup) — all three queries executed correctly and returned expected results.
- [X] T231 [US6] Create compliance-sys-api/src/ComplianceSys.Application/Interfaces/Services/IEutrTemplateReferencesService.cs and compliance-sys-api/src/ComplianceSys.Application/Services/EutrTemplateReferencesService.cs — extends `BaseService<EutrTemplateReferences, long, EutrTemplateReferencesRequestDto>`; override `AddAsync`/`UpdateAsync` to call `HasOverlapAsync` first and throw a validation error when it returns true (FR-036); `DeleteAsync` calls the base `IRepository.DeleteAsync` directly (genuine hard delete, no soft-delete override, FR-037). Resolve `VendorName` for `GetByTemplateIdAsync`'s results via the same D365 refType=13 reference mechanism `EutrTemplatesService` previously used for `VendorName` (before Phase 49 removed it from that class). **Done**: confirmed via `EutrStepService`/`EutrStepsController` (a similarly plain CRUD entity in this codebase) that `BaseService<T,,>`'s default `DeleteAsync` is already a hard delete with no override needed — same pattern reused here.
- [X] T232 [US6] Create compliance-sys-api/src/ComplianceSys.Api/Controllers/EutrTemplateReferencesController.cs — `[Route("api/eutr-template-references")]`, mirrors `EutrTemplatesController.cs`'s shape: `GET by-template/{templateId:long}` (FR-033), `POST` (FR-034), `PUT {id:long}` (FR-035), `DELETE {id:long}` (FR-037); new `EutrTemplateReferences.ReadAll/.Create/.Update/.Delete` authorization policies (flag for verification during this update's validation phase — same open-dependency treatment as `GroupEmail.ReadAll` in an earlier update). **Deviated from the plan on purpose**: confirmed via `Program.cs` that authorization policies in this codebase are NOT statically registered (no `AddPolicy("EutrTemplates.ReadAll", ...)` calls found anywhere) — they're checked dynamically against seeded menu/role permissions in the database. Minting brand-new `EutrTemplateReferences.*` policy strings would require a DB seeding step outside this session's reach and outside pure code. Since Apply-to-Customer is a row-action on the existing `eutr-templates` screen (not a new menu item), the controller instead reuses the **existing** `EutrTemplates.Read`/`.Update`/`.Delete` policies — this works immediately with whatever roles already have EUTR Templates access, no new permission grant needed.
- [X] T233 [P] [US6] Add `CreateMap<EutrTemplateReferencesRequestDto, EutrTemplateReferences>()` (ignore `Id`/audit fields) to compliance-sys-api/src/ComplianceSys.Application/Mappings/EutrMappingProfile.cs. **Done**: also added the reverse map and `CreateMap<EutrTemplateReferences, EutrTemplateReferencesResponseDto>()`, matching the existing `EutrTemplates`/`EutrTemplateDetails` mapping triplet pattern.
- [X] T234 [US6] Register DI: add `services.AddScoped<IEutrTemplateReferencesService, EutrTemplateReferencesService>();` + `services.AddScoped<IValidator<EutrTemplateReferencesRequestDto>, EutrTemplateReferencesRequestDtoValidator>();` in compliance-sys-api/src/ComplianceSys.Application/DependencyInjection.cs; add `services.AddScoped<IEutrTemplateReferencesRepository, EutrTemplateReferencesRepository>();` in compliance-sys-api/src/ComplianceSys.Infrastructure/DependencyInjection.cs. **Done**.

**Checkpoint**: `POST api/eutr-template-references` creates a mapping, rejects same-template/same-vendor date overlaps, allows cross-template overlaps for the same vendor; `GET api/eutr-template-references/by-template/{id}` lists mappings with resolved `vendorName`; `DELETE` performs a genuine row removal (verify via direct DB query). **Verified**: `dotnet build` shows 0 `error CS`; the repository-level SQL smoke test (T230) round-tripped insert/select/overlap/cleanup successfully against the live dev DB. Full HTTP-level verification (through the controller, with auth) was not run in this session — the currently-running dev API process could not be restarted to serve the new binaries (DLL file-locked); see Phase 55 for the resulting scope of what could/couldn't be verified end-to-end.

---

## Phase 52: Frontend — Apply-to-Customer Domain/Infrastructure/Application Layers (US6)

**Purpose**: Build the frontend layers for `eutr-template-references`, mirroring the existing `eutr-templates` stack

- [X] T235 [P] [US6] Create compliance-client/src/domain/entities/EutrTemplateReferences.js — constructor-destructuring pattern mirroring `EutrTemplates.js`/`EutrTemplateDetails.js`: `id, templateId, vendorCode, vendorName, fromDate, toDate, createdBy, createdDate, updatedBy, updatedDate`. **Done**.
- [X] T236 [P] [US6] Create compliance-client/src/domain/interfaces/IEutrTemplateReferencesRepository.js — mirrors `IEutrTemplatesRepository.js`'s interface shape (`getByTemplateId`, `create`, `update`, `delete`). **Done**.
- [X] T237 [P] [US6] Create compliance-client/src/infrastructure/api/eutrTemplateReferencesApi.js — axios wrapper mirroring `eutrTemplatesApi.js` (GET by-template/{templateId}, POST, PUT {id}, DELETE {id}). **Done**.
- [X] T238 [US6] Create compliance-client/src/infrastructure/repositories/RestEutrTemplateReferencesRepository.js — implements `IEutrTemplateReferencesRepository`, methods `getByTemplateId(templateId)`, `create(payload)`, `update(id, payload)`, `delete(id)`, wrapping results in `EutrTemplateReferences`. **Done**.
- [X] T239 [US6] Register the new repository in compliance-client/src/di/repositories.js — import `RestEutrTemplateReferencesRepository`, add `eutrTemplateReferences: new RestEutrTemplateReferencesRepository()` alongside the existing `eutrTemplates` entry. **Done**.
- [X] T240 [P] [US6] Create compliance-client/src/application/usecases/eutr-template-references/GetByTemplateIdEutrTemplateReferencesUseCase.js and CreateEutrTemplateReferencesUseCase.js (one file per operation, matching this codebase's established convention). **Done**.
- [X] T241 [P] [US6] Create compliance-client/src/application/usecases/eutr-template-references/UpdateEutrTemplateReferencesUseCase.js and DeleteEutrTemplateReferencesUseCase.js. **Done**.

**Checkpoint**: All four `eutr-template-references` use cases execute against the new backend from Phase 51 (verify via a quick manual call from the browser console or a temporary test page before wiring the real UI in Phase 53). **Verified**: `eslint` clean on all 7 new files; `npm run build` succeeds. Live browser-console call not run in this session (no interactive browser available) — validated instead via the Phase 51 repository-level SQL smoke test, which exercises the exact same queries these use cases will hit through the controller.

---

## Phase 53: Frontend — ApplyCustomerPage Rewrite + TemplateListPage Wiring (US6)

**Purpose**: Rewire the existing mock `ApplyCustomerPage.jsx` to real Vendor/API data, add its route, and enable the previously-disabled Apply to Customer icon

- [X] T242 [US6] Rewrite compliance-client/src/presentation/pages/eutr-templates/ApplyCustomerPage.jsx — replace the `MOCK_CUSTOMERS`/`MOCK_TEMPLATE_CUSTOMERS` imports from `./mock/eutrTemplates` and all "Customer" naming with "Vendor": swap the `Select`/`MenuItem` Customer combobox for a Vendor `Autocomplete` backed by `ReferenceObjectAutocomplete`/`useReferenceObjects` (`referenceType={13}`, same generic reference mechanism already used elsewhere in this feature); load mappings via `GetByTemplateIdEutrTemplateReferencesUseCase.execute(id)` (route param) instead of `MOCK_TEMPLATE_CUSTOMERS[id]`; Save calls `CreateEutrTemplateReferencesUseCase`/`UpdateEutrTemplateReferencesUseCase` instead of local `setMappings` state; Delete calls `DeleteEutrTemplateReferencesUseCase` after the existing `ConfirmDialog` confirms; remove the `template.status !== 'Published'` gate and the `getStatus()`/`STATUS_COLORS` helpers entirely (no Status concept on real `EutrTemplate`); keep the existing `hasOverlap()` client-side pre-check function, rescoping its comparison from `m.customerId === form.customerId` to `m.vendorCode === form.vendorCode` (the server's `HasOverlapAsync` from Phase 51 remains the authoritative check — this is a fast-fail UX nicety only). **Done, with 2 deliberate deviations from the plan text**: (1) used `referenceType={14}`, NOT `13` — grepped the legacy `bk/EutrTemplatesAddEdit.jsx` (the last known-working Vendor combobox in this codebase) and confirmed it actually uses `referenceType={14}`, contradicting the spec/plan's stated `13` throughout; trusted the real working code over the spec text (Principle III). (2) Kept `getStatus()` (computes Active/Scheduled/Expired from the date range for the summary line) since it's pure date-math with no dependency on the removed `template.status` field — only `STATUS_COLORS` (genuinely unused dead code even in the original mock) and the `template.status !== 'Published'` gate were removed. Also translated all UI text to English (the pre-existing mock had Vietnamese strings, e.g. "Chỉnh sửa mapping", "Hủy", "Lưu") to comply with FR-017, which applies feature-wide. Template header (Code/VersionId) for the breadcrumb/title now loads via the existing `GetEutrTemplatesUseCase`, not a mock array lookup; added a loading spinner and a "Template not found" state (neither existed in the mock, since mock data was always synchronously available).
- [X] T243 [US6] Add a lazy `ApplyCustomerPage` import and a new route object `{ path: '/eutr/templates/apply/:id', element: <ApplyCustomerPage /> }` in compliance-client/src/app/routes/groups/MainRoutes.jsx, in the same `PrivateRoute`-guarded children array, right after the existing `/eutr/templates/edit/:id` entry — same `Loadable(lazy(...))` pattern as `TemplateBuilderPage`. **Done**.
- [X] T244 [US6] In compliance-client/src/presentation/pages/eutr-templates/TemplateListPage.jsx, remove the `disabled` prop from the "Apply to Customer" `IconButton` and wire `onClick={() => navigate(\`/eutr/templates/apply/${tmpl.id}\`)}`, gated by the same permission check already used by the Edit icon (`permissionList.includes('Update')` or equivalent — confirm which permission this action should require); leave the Clone icon disabled/unchanged. **Done**: gated by `permissionList.includes('Update')`, same as the Edit icon (consistent with T232's decision to reuse the `EutrTemplates.Update` policy on the backend for this action).

**Checkpoint**: Clicking Apply to Customer on any TemplateListPage row navigates to `/eutr/templates/apply/:id`, which loads/creates/edits/deletes real Vendor mappings against the Phase 51 backend, with no remaining references to the old mock Customer data or the fictional Published status gate. **Verified**: `eslint` clean; full `npm run build` succeeds (produces an `ApplyCustomerPage.[hash].js` chunk). Live click-through navigation not run in this session (no interactive browser available).

---

## Phase 54: Steps-Count Investigation (US1, FR-042 — verify-first, no speculative fix)

**Purpose**: Determine whether the user-reported "Steps column doesn't show count" bug reproduces against the current source before writing any fix

- [X] T245 [US1] Manually call `POST api/eutr-templates/get-all` (via DevTools Network tab, Swagger, or a REST client) for a template with a known number of active `eutr_template_details` rows, and separately for a template that has gone through a version bump (backdated `CreatedDate`, per quickstart.md Scenario 3b's technique) — compare the response's `stepsCount` value against a direct DB count (`SELECT COUNT(*) FROM eutr_template_details WHERE TemplateId = <id>`) for the CURRENTLY DISPLAYED row's Id in each case. Record the outcome directly in quickstart.md's Scenario 18 (already drafted during planning): if `stepsCount` is correct in the raw response, the discrepancy is a frontend rendering/stale-build issue — re-verify `TemplateListPage.jsx`'s `tmpl.stepsCount ?? 0` binding and whether the deployed frontend build is current; if `stepsCount` is already wrong in the raw response, escalate to checking whether the deployed backend build matches the current `EutrTemplatesRepository` source (most likely explanation, since the source was verified correct during planning). Only open a follow-up fix task if a concrete defect is found — do not modify any code as part of this task itself. **Done, adapted method**: could not obtain an authenticated HTTP session against the running dev API in this non-interactive session (no browser/login flow available), so executed the EXACT `GetPagedAsync` SQL directly against the live dev DB instead (equivalent verification — same query the controller/service call). Result: **confirmed working, not a defect** — `StepsCount` matched the real `eutr_template_details` count for every visible row, including a versioned template (see quickstart.md Scenario 18's recorded outcome table). No code change made.

**Checkpoint**: Scenario 18's outcome is recorded with evidence (either "confirmed working as of [date]" or "reproduced — root cause: [finding], tracked as task T2XX"). **Met** — see quickstart.md Scenario 18 "Outcome (2026-07-13, `/speckit-implement`)" section.

---

## Phase 55: Validation — Update 13 (VendorCode Removal + Apply to Customer + Steps-Count)

**Purpose**: End-to-end validation of all three Update 13 changes

- [X] T246 [P] Run quickstart.md Scenario 16 (VendorCode Removal Verification) end-to-end — confirm no Vendor field anywhere on TemplateBuilderPage/Create dialog, Export/Import column layouts match the new shapes, and `DESCRIBE eutr_templates;` shows no `VendorCode` column. **Verified statically + at the DB level** (no live browser session available in this non-interactive environment): repo-wide grep confirms zero `VendorCode`/`vendorCode`/`VendorName`/`vendorName` references remain in any `EutrTemplates*` file (backend or frontend) or in `TemplateBuilderPage.jsx`/`CreateTemplateDialog.jsx`; `DESCRIBE eutr_templates;` against the live dev DB confirms no `VendorCode` column (dropped via migration 12); Export/Import column layouts confirmed by direct code review of the updated `EutrTemplatesExportService.cs`/`EutrTemplatesImportService.cs`. Live browser click-through (opening the actual pages to visually confirm no field renders) not performed.
- [X] T247 [P] Run quickstart.md Scenario 5 (IsDefault Constraint, now global) end-to-end — confirm setting Default on any template clears Default on whichever OTHER template was previously default, system-wide, not scoped to any vendor. **Verified via code review only**: `ClearGlobalDefaultAsync` (T213) drops the `VendorCode` predicate entirely, and all 3 call sites in `EutrTemplatesService` (T215) now call it unconditionally on `dto.IsDefault == 1`. Not exercised via a live HTTP request/UI click-through — the running dev API process could not be restarted to serve the rebuilt binaries (DLL file-locked throughout this session).
- [X] T248 [P] Run quickstart.md Scenario 17 (Apply to Customer) end-to-end — Add/Edit/Delete mappings, same-template overlap rejected, cross-template overlap allowed, hard delete confirmed in DB. **Verified at the repository/SQL level, not through the full HTTP+UI stack**: the Phase 51 (T230) smoke test directly exercised `GetByTemplateIdAsync` and `HasOverlapAsync`'s exact SQL against the live DB (insert, select, overlap-count, cleanup) with correct results. The `EutrTemplateReferencesService`'s overlap-then-insert/update orchestration and the `ApplyCustomerPage.jsx` UI flow were verified by code review and successful compilation/build only — not run end-to-end via a live browser + running API, per the same environment limitation as T247.
- [X] T249 [P] Verify the new `EutrTemplateReferences.*` authorization policies are actually granted to the roles/users that have `EutrTemplates.*` policies (same verification class as the `GroupEmail.ReadAll` dependency flagged in an earlier update) — request a policy/role grant if missing. **Resolved by design, not by a permission grant**: per T232's decision, `EutrTemplateReferencesController` reuses the EXISTING `EutrTemplates.Read`/`.Update`/`.Delete` policies rather than minting new `EutrTemplateReferences.*` policies (confirmed via `Program.cs` that policies here are DB-seeded, not statically registered — creating new policy strings would need a DB seeding step outside this session's reach). Since no new policy was introduced, there is nothing new to grant — any role that can already reach EUTR Templates can immediately use Apply to Customer.
- [X] T250 [P] Verify all new/changed UI text (ApplyCustomerPage labels, buttons, validation messages, empty states) is in English per FR-017. **Done**: `ApplyCustomerPage.jsx` was fully rewritten in English (the pre-existing mock had Vietnamese strings — e.g. "Chỉnh sửa mapping", "Hủy", "Lưu" — all replaced); confirmed via re-reading the final file that no Vietnamese UI-facing string remains (comments remain Vietnamese per Principle IV).
- [X] T251 [P] Regression check: run quickstart.md Scenarios 2, 2b', 3a, 3b, 9, 10 (Create/Edit/Import) end-to-end to confirm no VendorCode-removal regression in the existing Create/Edit/Import flows (Import using the NEW 3-column Excel layout). **Verified via successful full builds, not live click-through**: `dotnet build` on the whole backend solution shows 0 `error CS`; `npm run build` on the whole frontend succeeds with no errors (only a pre-existing chunk-size warning unrelated to this change). This confirms no compile-time regression across every file touched by Phases 49-53, but does not substitute for exercising the actual Create/Edit/Import UI flows in a browser, which was not available in this session.
- [X] T252 Run quickstart.md Scenario 18's outcome review (from Phase 54/T245) as part of the same validation pass, and close out FR-042/SC-035 accordingly (either mark resolved with evidence, or file the root-cause fix as a new task). **Done — resolved**: see quickstart.md Scenario 18's recorded outcome (T245) — confirmed working against real data with no code change needed. FR-042/SC-035 closed out on this evidence.

**Checkpoint**: All Update 13 quickstart checks pass at the level achievable in this non-interactive session (static code review, full clean builds on both stacks, and direct-DB/SQL-level smoke tests standing in for HTTP-level checks where a live authenticated browser session wasn't available). **Recommended before sign-off**: restart the dev API process (currently running stale, pre-Update-13 binaries, file-locked throughout this implementation session) and the frontend dev server, then manually click through quickstart.md Scenarios 5, 16, and 17 in a real browser to close the gap between "verified by code/DB" and "verified end-to-end through the UI."

---

## Update 13 Dependencies

### Phase Dependencies

- **Phase 49 (Backend VendorCode removal)**: No dependency on other Update 13 phases — can start
  immediately. T212/T213 touch the same file (`EutrTemplatesRepository.cs`) sequentially; T214/T215
  touch `EutrTemplatesService.cs` sequentially (T214 first — the method body change — then T215's
  3 call-site updates elsewhere in the same file). T209-T211, T216-T218 are independent `[P]`.
- **Phase 50 (Frontend VendorCode removal)**: Independent of Phase 49 (frontend has no compile-time
  dependency on the backend during development, though full end-to-end testing needs both). All 4
  tasks touch different files — fully `[P]`.
- **Phase 51 (Backend eutr_template_references CRUD)**: No dependency on Phases 49/50. T223/T224
  (migration + fresh-install DDL) independent `[P]`. T225-T228 (entity/DTOs/validator) independent
  `[P]`. T229 (repository interface) before T230 (repository impl). T230 before T231 (service calls
  the repository). T231 before T232 (controller calls the service). T233 (AutoMapper) independent
  `[P]`. T234 (DI registration) depends on T230-T233 all existing (registers all of them).
- **Phase 52 (Frontend Apply-to-Customer layers)**: Depends on Phase 51 being deployable (use cases
  need a real endpoint to call, though the files themselves can be authored in parallel). T235-T237
  independent `[P]`. T238 (repository) depends on T235-T237. T239 (DI registration) depends on T238.
  T240/T241 (use cases) depend on T239.
- **Phase 53 (ApplyCustomerPage + TemplateListPage wiring)**: Depends on Phase 52 (T242 calls the
  Phase 52 use cases). T243 (route) independent of T242 — `[P]` candidate, but grouped here since
  both are needed before T244 is meaningfully testable. T244 (enable icon) depends on T243 (route
  must exist to navigate to).
- **Phase 54 (Steps-count investigation)**: Independent of all other Update 13 phases — can run at
  any time, including in parallel with Phases 49-53.
- **Phase 55 (Validation)**: Depends on Phases 49-54 all being complete.

### Execution Order

```
T209, T210, T211 [P] ──┐
T212 → T213 ────────────┼── T214 → T215 ── (Phase 49 done) ──┐
T216, T217, T218 [P] ───┘                                     │
                                                                ├── T246, T247, T251 ([P])
T219, T220, T221, T222 [P] ── (Phase 50 done) ─────────────────┘

T223, T224 [P] ──┐
T225-T228 [P] ────┼── T229 ── T230 ── T231 ── T232 ── T233 [P] ── T234 ── (Phase 51 done)
                  │                                                     │
                  └─────────────────────────────────────────────────────┼── T235-T237 [P] ── T238 ── T239 ── T240, T241 [P] ── (Phase 52 done)
                                                                          │                                                       │
                                                                          └───────────────────────────────────────────────────────┴── T242 ── T243 ── T244 ── (Phase 53 done) ──┬── T248, T249, T250 ([P])
                                                                                                                                                                                    │
T245 (Phase 54, independent) ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┴── T252 (E2E close-out)
```

### Parallel Opportunities

```
# Phase 49 — most tasks touch different files:
T209, T210, T211 [P]
T212 → T213 (same file, sequential)
T214 → T215 (same file, sequential — T215 depends on T214's ClearGlobalDefaultAsync existing)
T216, T217, T218 [P]

# Phase 50 — all 4 tasks touch different files:
T219, T220, T221, T222 [P]

# Phase 51 — mostly sequential within the new stack, entity/DTO/migration files parallel:
T223, T224, T225, T226, T227, T228, T233 [P]
T229 → T230 → T231 → T232 → T234

# Phase 52 — early layers parallel, then sequential:
T235, T236, T237 [P]
T238 → T239 → (T240, T241 [P])

# Phase 53 — sequential (each step needs the previous one wired):
T242 → T243 → T244

# Phase 54 — fully independent of 49-53:
T245 [P]

# Phase 55 — all verification tasks [P] except the final close-out:
T246, T247, T248, T249, T250, T251 in parallel (once Phases 49-54 are done)
T252 sequentially (final close-out, depends on T245's findings)
```

---

## Update 2026-07-14 (Update 14) — Import/Export Vendor Mapping on ApplyCustomerPage

**Context**: Per spec Update 14, add Import and Export buttons to the already-implemented
`ApplyCustomerPage.jsx` (Update 13). The Excel file format is 4 columns — TemplateCode, VendorCode,
FromDate, ToDate — scoped to the template currently open (`:id` route param). Export downloads the
current template's mappings in that format (a header-only file when empty, doubling as the Import
template). Import accepts `.xlsx` only, validates each row with the exact same logic as the manual
"Apply Vendor" dialog (reusing `EutrTemplateReferencesService.AddAsync` per row rather than
duplicating its validation/overlap-check), rejects rows whose TemplateCode doesn't match the
currently-open template, creates new mappings only (never updates an existing one), and reports a
per-row OK/error result after processing.

**Changes**: Backend — two new Excel services (`EutrTemplateReferencesImportService`/
`ExportService`) modeled 1:1 on the existing `EutrTemplatesImportService`/`ExportService`, plus two
new controller actions on the already-shipped `EutrTemplateReferencesController.cs`, reusing its
existing `EutrTemplates.Update`/`EutrTemplates.Read` policies (no new policy family). Frontend — two
new use cases, API/repository passthroughs, a new `ImportMappingResultDialog.jsx` (copy of
`ImportResultDialog.jsx` with different columns), and Import/Export buttons wired into
`ApplyCustomerPage.jsx`. See research.md §29, data-model.md's Entity 6 Import/Export note,
contracts/api-endpoints.md Sections 9.5–9.6, and plan.md's "Update 2026-07-14 (Update 14)" section
for the full rationale and file-by-file design this phase set implements.

---

## Phase 56: Backend — Import/Export Services + Controller Actions (US6)

**Purpose**: Add the Excel import/export services and the two new controller actions for `eutr_template_references`, scoped by `templateId`

- [X] T253 [P] [US6] Create compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/ImportEutrTemplateReferencesResultDto.cs — mirrors `ImportEutrTemplatesResultDto.cs`'s shape: `TotalRows`, `SuccessCount`, `FailCount`, `Errors` (list of `ImportEutrTemplateReferencesRowError { Row, TemplateCode, VendorCode, Message }`).
- [X] T254 [P] [US6] Create compliance-sys-api/src/ComplianceSys.Application/Interfaces/Services/IEutrTemplateReferencesImportService.cs + compliance-sys-api/src/ComplianceSys.Application/Services/EutrTemplateReferencesImportService.cs — `ImportFromExcelAsync(long templateId, Stream fileStream, string userEmail, CancellationToken ct)`: (1) call `IEutrTemplatesService.GetByIdWithDetailsAsync(templateId, ct)`, throw `KeyNotFoundException` if null; (2) open the workbook with ClosedXML (same pattern as `EutrTemplatesImportService`), verify the header row has exactly `TemplateCode`/`VendorCode`/`FromDate`/`ToDate` (case-insensitive, trimmed), throw `InvalidOperationException` on mismatch before processing any row; (3) for each data row (skip empty rows), increment `TotalRows`, then validate in order: `TemplateCode` (trimmed) must equal `template.Code` exactly (else row error "TemplateCode does not match the current template", `continue`); `VendorCode`/`FromDate` non-blank; blank `ToDate` → sentinel `9999-12-31`, else parsed; `ToDate >= FromDate`; (4) build `new EutrTemplateReferencesRequestDto { TemplateId = templateId, VendorCode, FromDate, ToDate }` and call `IEutrTemplateReferencesService.AddAsync(dto, userEmail, ct)` inside try/catch — `ValidationException`/`InvalidOperationException` → row error with `ex.Message`, `FailCount++`; other exception → log + generic "Failed to import row" error, `FailCount++`; else `SuccessCount++`. Do NOT re-implement `AddAsync`'s validation/overlap logic here — call the existing method.
- [X] T255 [P] [US6] Create compliance-sys-api/src/ComplianceSys.Application/Interfaces/Services/IEutrTemplateReferencesExportService.cs + compliance-sys-api/src/ComplianceSys.Application/Services/EutrTemplateReferencesExportService.cs — `ExportToExcelAsync(long templateId, CancellationToken ct)`: (1) call `IEutrTemplatesService.GetByIdWithDetailsAsync(templateId, ct)`, throw `KeyNotFoundException` if null; (2) call `IEutrTemplateReferencesService.GetByTemplateIdAsync(templateId, ct)` for the mapping rows (no D365 call needed — `VendorName` is not one of the 4 export columns); (3) build a ClosedXML workbook with headers `TemplateCode, VendorCode, FromDate, ToDate` (same `sheet.Cell(...).Value = ...` + `AdjustToContents()` pattern as `EutrTemplatesExportService`), one row per mapping (`TemplateCode` = `template.Code` repeated), `FromDate`/`ToDate` written as real Excel date values with a `"yyyy-mm-dd"` number format; zero mappings → header-only workbook.
- [X] T256 [US6] Add two actions to compliance-sys-api/src/ComplianceSys.Api/Controllers/EutrTemplateReferencesController.cs — `[Authorize(Policy = "EutrTemplates.Update")] [HttpPost("import/{templateId:long}")] Import(long templateId, IFormFile file, CancellationToken ct)`: validate `file` not null/empty and extension `.xlsx` (same check as `EutrTemplatesController.Import`) before calling `IEutrTemplateReferencesImportService.ImportFromExcelAsync`; catch `KeyNotFoundException` → `NotFound`, `InvalidOperationException` → `BadRequest`, else 500; return `ApiResponse<ImportEutrTemplateReferencesResultDto>` with message `"Import finished: {SuccessCount} success, {FailCount} errors."`. `[Authorize(Policy = "EutrTemplates.Read")] [HttpGet("export/{templateId:long}")] Export(long templateId, CancellationToken ct)`: call `IEutrTemplateReferencesExportService.ExportToExcelAsync`, catch `KeyNotFoundException` → `NotFound`, else follow `EutrTemplatesController.Export`'s try/catch shape; return the file as `eutr-template-references-{code}-{yyyyMMddHHmmss}.xlsx`.
- [X] T257 [US6] Register DI in compliance-sys-api/src/ComplianceSys.Application/DependencyInjection.cs — add `services.AddScoped<IEutrTemplateReferencesImportService, EutrTemplateReferencesImportService>();` and `services.AddScoped<IEutrTemplateReferencesExportService, EutrTemplateReferencesExportService>();` alongside the existing `EutrTemplateReferencesService` registration.

**Checkpoint**: `POST api/eutr-template-references/import/{templateId}` accepts a valid 4-column `.xlsx`, creates one mapping per valid row, rejects non-`.xlsx` files and rows with a mismatched TemplateCode; `GET api/eutr-template-references/export/{templateId}` downloads a 4-column `.xlsx` matching the template's current mappings (header-only when empty). **Verified**: `dotnet build` on `ComplianceSys.Application.csproj` shows 0 `error CS` (the `ComplianceSys.Api.csproj` build hits the same pre-existing DLL file-lock from a running dev API process documented in Update 13 — no `error CS` there either, only `MSB3027`/`MSB3021` copy-lock errors). Header-validation/date-parsing logic and the overlap-check SQL path were smoke-tested directly (see Phase 59/T264) rather than through a live HTTP call.

---

## Phase 57: Frontend — Import/Export API, Repository, Use Cases (US6)

**Purpose**: Add the frontend infrastructure/application layers for calling the two new backend endpoints

- [X] T258 [P] [US6] Add `importByTemplate(templateId, file)` and `exportByTemplate(templateId)` methods to compliance-client/src/infrastructure/api/eutrTemplateReferencesApi.js — `importByTemplate` builds a `FormData` with the file and POSTs (multipart) to `/eutr-template-references/import/${templateId}` (same `FormData` construction as `eutrTemplatesApi.js`'s `import`); `exportByTemplate` GETs `/eutr-template-references/export/${templateId}` with `responseType: 'blob'` (same as `eutrTemplatesApi.js`'s `export`).
- [X] T259 [US6] Add `importByTemplate(templateId, file)`/`exportByTemplate(templateId)` passthrough methods to compliance-client/src/infrastructure/repositories/RestEutrTemplateReferencesRepository.js, delegating to the T258 API methods (mirrors `RestEutrTemplatesRepository.js`'s `import`/`export` wrapper shape).
- [X] T260 [P] [US6] Create compliance-client/src/application/usecases/eutr-template-references/ImportEutrTemplateReferencesUseCase.js — `execute(templateId, file)` calls `repository.importByTemplate(templateId, file)` (mirrors `ImportEutrTemplatesUseCase.js` verbatim shape).
- [X] T261 [P] [US6] Create compliance-client/src/application/usecases/eutr-template-references/ExportEutrTemplateReferencesUseCase.js — `execute(templateId)` calls `repository.exportByTemplate(templateId)`, then builds a temporary `<a download>` link from the blob response and clicks it (mirrors `ExportEutrTemplatesUseCase.js`'s blob-download-trigger logic and its `_resolveFileName` Content-Disposition fallback, default filename `eutr-template-references-${templateId}-${timestamp}.xlsx`).

**Checkpoint**: `ImportEutrTemplateReferencesUseCase`/`ExportEutrTemplateReferencesUseCase` are ready to call from `ApplyCustomerPage.jsx` (verify via a quick manual call before wiring the UI in Phase 58). **Verified**: `eslint` clean on all 4 new/changed files; the API/repository method shapes mirror `eutrTemplatesApi.js`/`RestEutrTemplatesRepository.js`'s `import`/`export` exactly, which are already proven working in production. Live browser-console call not run (no interactive browser available).

---

## Phase 58: Frontend — ApplyCustomerPage Import/Export UI (US6)

**Purpose**: Add the Import/Export buttons, the result dialog, and the wiring on `ApplyCustomerPage.jsx`

- [X] T262 [US6] Create compliance-client/src/presentation/pages/eutr-templates/components/ImportMappingResultDialog.jsx — copy `ImportResultDialog.jsx`'s structure (Total/Success/Error `Chip`s + error table + Close button) verbatim, with the error table's columns changed to **Row, TemplateCode, VendorCode, Reason** to match `ImportEutrTemplateReferencesRowError`'s shape (`result.errors[].row/.templateCode/.vendorCode/.message`).
- [X] T263 [US6] Add Import/Export buttons and wiring to compliance-client/src/presentation/pages/eutr-templates/ApplyCustomerPage.jsx — add **Import**/**Export** `Button`s to the existing header `Stack` (next to Back/Apply Vendor); add a hidden `<input type="file" accept=".xlsx" hidden>` behind a `ref`, wired to an `onChange` handler that: (1) does a fast-fail client-side extension check (server is still authoritative), (2) calls `ImportEutrTemplateReferencesUseCase.execute(id, file)`, (3) opens `ImportMappingResultDialog` (T262) with the returned result, (4) calls the existing `fetchMappings()` to refresh the table, (5) resets the file `<input>`'s value so re-selecting the same filename re-fires `onChange`; the Export button's `onClick` calls `ExportEutrTemplateReferencesUseCase.execute(id)` directly (no dialog). Add `importing` state (disables both buttons while a request is in flight) and `importResult`/`importDialogOpen` state.

**Checkpoint**: Clicking Export on ApplyCustomerPage downloads a 4-column `.xlsx` of the current template's mappings; clicking Import, selecting a valid file, shows a per-row OK/error result dialog and refreshes the mapping table with newly-created mappings. **Verified**: `eslint` clean; full `npm run build` succeeds (produces an updated `ApplyCustomerPage.[hash].js` chunk, 10.29 kB). Live click-through navigation/file-picker interaction not run in this session (no interactive browser available) — see Phase 59/T264 for the fallback verification performed instead.

---

## Phase 59: Validation — Import/Export Vendor Mapping (Update 14)

**Purpose**: End-to-end validation of the Import/Export feature

- [X] T264 [P] Run quickstart.md Scenario 19 (Import/Export Vendor Mapping) end-to-end — Export with existing mappings and with zero mappings (header-only file), edit the exported file and Import it back with a mix of valid rows, a mismatched-TemplateCode row, and a missing-VendorCode row, confirm the per-row result and that only the valid row creates a mapping; Import a non-`.xlsx` file (rejected); Import a file with 2 in-file-overlapping rows for the same vendor (first succeeds, second fails); Import a header-only file (zero rows, no error). **Verified via 2 direct smoke tests, not through the full HTTP+UI stack** (no interactive browser session available in this non-interactive environment, same limitation as Update 13's Phase 55): (1) a ClosedXML in-process test built an in-memory workbook matching the Export layout and re-parsed it with a line-for-line copy of the service's `ValidateHeader`/`TryParseExcelDate` logic — confirmed valid-file parsing, header-only-file zero-data-rows behavior, malformed-header rejection, and string-date fallback parsing all work correctly; (2) a MySqlConnector test against the live dev DB (`compliance_sys_db_260601`) confirmed the exact overlap-check/insert SQL semantics `AddAsync`/`HasOverlapAsync` already implement (unchanged by this update): insert succeeds, same-vendor-same-template overlap is correctly flagged, same-vendor-different-template is correctly NOT flagged, test row cleaned up afterward (DB left unchanged). See quickstart.md Scenario 19's recorded outcome for full detail.
- [X] T265 [P] Verify the new Import/Export controller actions reuse the existing `EutrTemplates.Update`/`EutrTemplates.Read` policies (no new policy family introduced, consistent with how `EutrTemplateReferencesController`'s other actions already resolved this in Update 13). **Verified by code review**: `[Authorize(Policy = "EutrTemplates.Update")]` on `Import` and `[Authorize(Policy = "EutrTemplates.Read")]` on `Export` in `EutrTemplateReferencesController.cs` — identical policy strings already used by this controller's `Create`/`Update` and `GetByTemplateId` actions respectively; no new policy string introduced anywhere in this update.
- [X] T266 [P] Verify all new UI text (Import/Export button labels, `ImportMappingResultDialog` title/columns, file-format/validation error messages) is in English per FR-017. **Verified by code review**: `ApplyCustomerPage.jsx`'s new "Import"/"Export" buttons and all new snackbar messages ("Only .xlsx files are supported.", "Failed to import/export vendor mappings") are in English; `ImportMappingResultDialog.jsx`'s title ("Import result"), chips (Total/Success/Errors), table headers (Row/TemplateCode/VendorCode/Reason), and empty-state text ("All rows imported successfully.") are in English; backend row-error messages ("TemplateCode does not match the current template", "Vendor is required", "To date must be on or after From date", "Invalid To date") are in English.
- [X] T267 Record Scenario 19's verification outcome directly in quickstart.md (evidence of what was actually run — live UI click-through if a browser session was available, or the fallback verification method used, following the same recording convention as Scenario 18's outcome note). **Done** — see quickstart.md Scenario 19's "Outcome (2026-07-14, `/speckit-implement`)" section, recorded with the same structure/level of detail as Scenario 18's outcome note.

**Checkpoint**: All Update 14 quickstart checks pass at the level achievable in this non-interactive session (ClosedXML in-process parsing smoke test, direct-DB/SQL-level overlap-check smoke test, full clean builds on both stacks, and code review — standing in for HTTP+UI-level checks where a live authenticated browser session wasn't available). **Recommended before sign-off**: restart the dev API process (currently running stale, pre-Update-14 binaries, file-locked throughout this implementation session) and the frontend dev server, then manually click through quickstart.md Scenario 19 in a real browser to close the gap between "verified by code/DB/parsing-logic" and "verified end-to-end through the UI."

---

## Update 14 Dependencies

### Phase Dependencies

- **Phase 56 (Backend Import/Export services + controller actions)**: No dependency on Phases 49-55
  — builds on the already-shipped `EutrTemplateReferencesService`/`EutrTemplatesService` from Update
  13. T253 (result DTO), T254 (import service), T255 (export service) are independent `[P]` (different
  files). T256 (controller) depends on T253-T255 all existing (calls both new services, returns the
  new DTO). T257 (DI registration) depends on T254/T255 existing.
- **Phase 57 (Frontend API/repository/use cases)**: Depends on Phase 56 being callable (use cases
  need real endpoints, though files can be authored in parallel). T258 (API methods) independent.
  T259 (repository passthroughs) depends on T258. T260/T261 (use cases) depend on T259, independent
  of each other `[P]`.
- **Phase 58 (ApplyCustomerPage UI wiring)**: Depends on Phase 57 (T263 calls the Phase 57 use
  cases). T262 (result dialog component) independent of T257-T261 — `[P]` candidate, but grouped
  here since it's only meaningfully testable once T263 renders it.
- **Phase 59 (Validation)**: Depends on Phases 56-58 all being complete.

### Execution Order

```
T253, T254, T255 [P] ── T256 ── T257 ── (Phase 56 done)
                                    │
T258 ── T259 ── T260, T261 [P] ── (Phase 57 done)
                                    │
                    T262 [P] ──┬── T263 ── (Phase 58 done) ── T264, T265, T266 [P] ── T267
                                └──┘
```

### Parallel Opportunities

```
# Phase 56 — DTO + both services independent, controller/DI sequential after:
T253, T254, T255 [P]
T256 → T257

# Phase 57 — API layer then repository then use cases:
T258 ── T259 ── (T260, T261 [P])

# Phase 58 — result dialog can be authored while the use cases are still being wired:
T262 [P]
T263 (depends on Phase 57 use cases + T262)

# Phase 59 — all verification tasks [P] except the final recording step:
T264, T265, T266 in parallel (once Phases 56-58 are done)
T267 sequentially (records the findings from T264)
```
