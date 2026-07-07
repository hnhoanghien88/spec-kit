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
