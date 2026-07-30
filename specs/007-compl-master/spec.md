# Feature Specification: Compliance Master Alert Type

**Feature Branch**: `007-compl-master`

**Created**: 2026-07-30

**Status**: Draft

**Input**: Merged from two related requests:
1. "cập nhật tính năng compl-master, tính năng này đã xây dựng sẵn, hiện tại cần thêm 1 cột là AlertType (label: Alert type) cột này đã thêm ở bảng compl_masters. sẽ tạo 1 enum tên AlertTypeEnum (0 = All, 1 = Missing, 2 = Expired) trong helpers.js và ở Domain backend. cần chỉnh lại tính năng create ở link compliance-master/new và edit ở link compliance-master/(Id) cho hiển thị và edit thông tin AlertType, vị trí ở dưới text box Description, mặc định là 0 - All. Controller ở E:\\Working\\Eutr\\compliance-sys-api\\src\\ComplianceSys.Api\\Controllers\\ComplMasterController.cs."
2. "hiển thị thông tin Alert type ở index compliance-master, phía sau cột Status" (display Alert type information in the compliance-master index, after the Status column)

*(Originally specified as two separate features — `007-compl-master-alert-type` and `008-compl-master-alerttype-column` — merged into this single spec since they describe one coherent capability: the Compliance Master's Alert type, end to end.)*

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Choose Alert Type when creating a Compliance Master (Priority: P1)

A Compliance Admin creating a new Compliance Master needs to specify which alert condition applies to it — whether it should alert for all compliance events, only missing compliances, or only expired compliances — so the notification/alerting behavior for that master is correctly scoped from the moment it is created.

**Why this priority**: This is the core of the feature request — without it, newly created masters have no way to record their alert condition, and the field cannot be captured at all.

**Independent Test**: Can be fully tested by opening `compliance-master/new`, confirming the "Alert type" field appears below Description pre-set to "All", changing it to "Missing" or "Expired", saving the master, and confirming the chosen value is persisted.

**Acceptance Scenarios**:

1. **Given** a user opens the Create Compliance Master form, **When** the form loads, **Then** an "Alert type" field is visible directly below the Description field, defaulted to "All".
2. **Given** a user is filling out the Create form, **When** they select "Missing" or "Expired" from the Alert type field, **Then** the selection is reflected in the form state.
3. **Given** a user has selected an Alert type and completes all other required fields, **When** they save the new Compliance Master, **Then** the record is created with the chosen Alert type value.

---

### User Story 2 - View and change Alert Type when editing an existing Compliance Master (Priority: P2)

A Compliance Admin opening an existing Compliance Master needs to see its current Alert type and be able to change it, using the same rules that already govern whether the rest of the form is editable or read-only.

**Why this priority**: Existing masters need the same visibility/editability as new ones, but this depends on User Story 1 establishing the field and its default first.

**Independent Test**: Can be fully tested by opening `compliance-master/{id}` for an existing master, confirming the Alert type field shows the saved value below Description, changing it (when the form is editable), saving, and reloading to confirm the new value persisted.

**Acceptance Scenarios**:

1. **Given** a user opens an existing Compliance Master for edit, **When** the detail loads, **Then** the Alert type field shows the value currently saved for that master, positioned directly below Description.
2. **Given** a user has permission to edit the master and it is in an editable state, **When** they change the Alert type and save, **Then** the updated value is persisted and shown on subsequent loads.
3. **Given** a user only has view access, or the master is in a state that disables editing (e.g., replaced by a newer version, no Update permission), **When** they view the form, **Then** the Alert type field is visible but not editable, consistent with how other fields on the form behave in that state.

---

### User Story 3 - See each master's Alert type in the list (Priority: P3)

A user browsing the Compliance Master list needs to know, at a glance, what kind of alert each master is configured for (All, Missing, or Expired) without opening every record's detail page, so they can quickly scan and understand the masters they're responsible for.

**Why this priority**: Builds directly on User Story 1's data — the list simply surfaces a value that already exists once a master has been created or edited with an Alert type.

**Independent Test**: Open the Compliance Master list (index), confirm a column labeled "Alert type" appears directly after the "Status" column, and confirm it shows the correct value ("All", "Missing", or "Expired") for a range of existing masters.

**Acceptance Scenarios**:

1. **Given** a user opens the Compliance Master list, **When** the list loads, **Then** a column labeled "Alert type" is visible immediately after the "Status" column.
2. **Given** a master whose Alert type is "Missing" or "Expired", **When** it appears in the list, **Then** its Alert type column shows that same label.
3. **Given** a master created before the Alert type field existed (or otherwise without a stored value), **When** it appears in the list, **Then** its Alert type column shows "All".

---

### Edge Cases

- What happens when an existing Compliance Master record has no Alert type stored (e.g., data created before this feature)? It must display and be treated as "All" (value 0), everywhere it's shown (Create/Edit form and list).
- What happens if a user leaves the Alert type field untouched on Create? It must still submit with its current value (default "All") — the field is never blank/unset.
- What happens on Renew/Copy/Duplicate flows for a Compliance Master? The Alert type of the source master should carry over the same way other master-level fields do, unless the user changes it.
- What happens when the list is filtered, sorted, or paged? The Alert type column continues to show the correct value for whichever masters are currently displayed.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The Create Compliance Master form (`compliance-master/new`) MUST display an "Alert type" field positioned directly below the Description field.
- **FR-002**: The Edit Compliance Master form (`compliance-master/{id}`) MUST display the same "Alert type" field in the same position, showing the master's currently saved value.
- **FR-003**: The Alert type field MUST offer exactly three options: "All", "Missing", and "Expired".
- **FR-004**: When creating a new Compliance Master, the Alert type field MUST default to "All".
- **FR-005**: The system MUST persist the selected Alert type value as part of saving (create or update) a Compliance Master.
- **FR-006**: The Alert type field's editability MUST follow the same view/edit/disabled rules already applied to the rest of the master form (e.g., disabled for view-only permission or when the master has been replaced by a newer version).
- **FR-007**: Compliance Master records that predate this field MUST be treated as Alert type "All" wherever displayed (form and list alike).
- **FR-008**: The Compliance Master list MUST display an "Alert type" column positioned immediately after the "Status" column.
- **FR-009**: The Alert type column in the list MUST show the same three human-readable labels ("All" / "Missing" / "Expired") used on the Create/Edit form, matching each master's stored Alert type.
- **FR-010**: The Alert type column MUST be visible by default when the list loads (not hidden behind a column-visibility toggle).

### Key Entities

- **Compliance Master**: The existing record type managed by the compliance-master feature; gains one new attribute, Alert type, describing which alert condition (All, Missing, Expired) the master applies to. Shown on the Create form, the Edit form, and the list.
- **Alert Type**: A fixed classification with three values — All, Missing, Expired — representing the alert condition scope of a Compliance Master.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can set the Alert type while creating a new Compliance Master with no extra steps beyond the existing save flow.
- **SC-002**: 100% of Compliance Masters (new and existing) show a defined Alert type value ("All", "Missing", or "Expired") — never blank — wherever they are viewed (Create/Edit form or list).
- **SC-003**: Editing an existing Compliance Master's Alert type and saving results in the new value being visible on the very next load of that master, 100% of the time.
- **SC-004**: Users can determine the Alert type of any listed Compliance Master directly from the list, for 100% of rows, without opening the record.
- **SC-005**: The Alert type column appears in the same position (directly after Status) for every row and every page of the list.

## Assumptions

- The `AlertType` column already exists on the `compl_masters` table (per the original request), so no new database migration is required to introduce the column itself.
- Alert type values are fixed as: 0 = All, 1 = Missing, 2 = Expired; no additional values are in scope.
- Alert type is presented as a single-select field (dropdown) on the Create/Edit form, matching the style of similar single-choice fields already on the form.
- No new permission policy is required; access to view/edit the Alert type field follows the Compliance Master form's existing Create/Update permission checks.
- The field is always populated (defaults to "All"), so no "required field" validation error state is needed for it.
- Sorting and filtering the list by Alert type are out of scope for this request; only display is required in the list. This can be requested as a separate enhancement later.
