# Feature Specification: Compliance Master Alert Type & Delete Fix

**Feature Branch**: `007-compl-master`

**Created**: 2026-07-30

**Updated**: 2026-09-08

**Status**: Draft

**Input**: Merged from four related requests:
1. "cập nhật tính năng compl-master, tính năng này đã xây dựng sẵn, hiện tại cần thêm 1 cột là AlertType (label: Alert type) cột này đã thêm ở bảng compl_masters. sẽ tạo 1 enum tên AlertTypeEnum (0 = All, 1 = Missing, 2 = Expired) trong helpers.js và ở Domain backend. cần chỉnh lại tính năng create ở link compliance-master/new và edit ở link compliance-master/(Id) cho hiển thị và edit thông tin AlertType, vị trí ở dưới text box Description, mặc định là 0 - All. Controller ở E:\\Working\\Eutr\\compliance-sys-api\\src\\ComplianceSys.Api\\Controllers\\ComplMasterController.cs."
2. "hiển thị thông tin Alert type ở index compliance-master, phía sau cột Status" (display Alert type information in the compliance-master index, after the Status column)
3. "cập nhật 007-compl-master, chức năng delete master ở compliance-master?page=1&page-size=50. bị lỗi với master MAS-01104" (the delete-master action on the Compliance Master list is broken; reported reproducing with master MAS-01104)
4. "cập nhật 007-compl-master, màn hình ở link compliance-master/1021. khúc Individual Rule Conditions (AND only). hiện tại muốn add thêm condition là Customer, nhưng chỉ chọn được Value, NOT IN. giờ thêm logic Table. khi user chọn sẽ tạo công thức ở MASTER PREVIEW là Customer in (A, B, C...) giống product type. và kiểm tra lại logic lấy compliance sp_load_compl_by_conditions, sp_load_compl_by_conditions_count" (on the Compliance Master detail screen, in the "Individual Rule Conditions (AND only)" section, the Customer condition currently only offers "Value" and "NOT IN" logic — add "Table" logic so it can be used the same way Product Type already uses it, producing a Master Preview formula for the selected Customer values, and re-verify that `sp_load_compl_by_conditions` / `sp_load_compl_by_conditions_count` correctly evaluate Customer conditions)

*(Originally specified as two separate features — `007-compl-master-alert-type` and `008-compl-master-alerttype-column` — merged into this single spec since they describe one coherent capability: the Compliance Master's Alert type, end to end. Request 3 was added later as a defect report against the same Compliance Master list/detail surface and folded into this spec at the requester's direction. Request 4 was added later still, against the same Compliance Master detail screen's condition-builder surface, and folded into this spec at the requester's direction.)*

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

### User Story 4 - Reliably delete a Compliance Master from the list (Priority: P1)

A Compliance Admin browsing the Compliance Master list (e.g. `compliance-master?page=1&page-size=50`) needs to delete a master the list presents as deletable and have that action actually succeed, instead of failing with no usable explanation. This was reported broken for master `MAS-01104`: the list allows the user to start the delete, but the action does not complete.

**Why this priority**: This is a defect that blocks a core management action (removing masters that are no longer needed) with no workaround and no clear reason given to the user — it needs to be fixed on its own, independent of the Alert type work.

**Independent Test**: Can be fully tested by opening the Compliance Master list, locating a master the list marks as deletable (such as `MAS-01104`), deleting it, and confirming it disappears from the list and does not reappear on reload — or, if deletion is genuinely not allowed for that record, confirming the user is told the specific reason at the moment they attempt it rather than after the fact.

**Acceptance Scenarios**:

1. **Given** a Compliance Admin with delete permission is viewing the Compliance Master list and the list presents a given master (e.g. `MAS-01104`) as eligible for deletion, **When** they delete it and confirm, **Then** the deletion completes successfully and the master no longer appears in the list on the next load.
2. **Given** a master that the list presents as eligible for deletion but that still has other compliance data linked to it, **When** the user deletes it, **Then** the system either completes the deletion cleanly (including any linked data that deletion is expected to remove) or refuses the action up front with a specific, understandable reason — it never lets the user start the action and then fail without explanation.
3. **Given** a delete attempt cannot succeed for a legitimate reason, **When** the failure occurs, **Then** the user sees a specific, actionable message describing why, distinct from a generic "delete failed" error, so they understand what to do next.
4. **Given** the same underlying condition that broke deletion for `MAS-01104`, **When** it occurs on any other Compliance Master (not just that one record), **Then** the fix applies consistently — the bug is resolved for the underlying condition, not patched only for that specific master.

---

### User Story 5 - Use Table logic for the Customer condition in Individual Rule Conditions (Priority: P1)

A Compliance Admin building or editing a master's rule conditions (e.g. at `compliance-master/1021`, in the "Individual Rule Conditions (AND only)" section) needs to add a Customer condition and select multiple customers at once — the same "Table" logic already available for Product Type — instead of being limited to a single Value or a NOT IN exclusion list. Once selected, the Master Preview must show the resulting formula (e.g. "Customer IN" followed by the chosen customers), and the underlying compliance-matching logic must evaluate that condition correctly.

**Why this priority**: This unblocks a condition type (Customer) from a capability (Table/multi-value matching) that already exists and works for other condition types (e.g. Product Type) today — without it, users cannot build rules that match against a list of specific customers in one condition, and are forced into workarounds (e.g. one condition per customer, or an over-broad NOT IN list).

**Independent Test**: Can be fully tested by opening `compliance-master/1021` (or any master with rule conditions), adding a Customer condition inside a rule block — including a block that already has another condition using Table logic — confirming "Table" is selectable for Customer, selecting several customers, confirming the Master Preview shows the correct formula for that condition, saving, and confirming the master's compliance matching (applied/missing results) correctly reflects only the selected customers.

**Acceptance Scenarios**:

1. **Given** a user is editing a rule block's conditions and adds or edits a Customer condition, **When** they open the Type/logic selector for that condition, **Then** "Table" is offered as an option, the same way it already is for Product Type.
2. **Given** a rule block already contains another condition (e.g. Product Type) using Table logic, **When** the user adds or edits a Customer condition in that same block, **Then** "Table" is still available for the Customer condition — it is not hidden or blocked just because another condition in the block already uses Table.
3. **Given** a user selects "Table" for a Customer condition and picks multiple customers (A, B, C), **When** they view the Master Preview, **Then** the condition's formula is shown using the same presentation already used for a Product Type Table condition (the condition's operator followed by the list of selected customers) — no new or different preview format is introduced.
4. **Given** a master saved with a Customer Table condition (e.g. matching customers A, B, C), **When** compliance records are loaded or counted for that master (via the logic backing `sp_load_compl_by_conditions` and `sp_load_compl_by_conditions_count`), **Then** only records whose Customer is one of the selected values are matched by that condition, consistent with how a Product Type Table condition is already evaluated.
5. **Given** a rule block containing both a Product Type Table condition and a Customer Table condition (AND), **When** the master is evaluated, **Then** both conditions are enforced together and only records satisfying both are matched.
6. **Given** a master created before this change with a Customer condition already saved as "Value" or "NOT IN", **When** it is opened or evaluated, **Then** it continues to load, display, and match exactly as before — no migration or reinterpretation of existing data is required.

---

### Edge Cases

- What happens when a rule block already has a Table-logic condition (of any type) and the user adds a second Table-logic condition (Customer or otherwise) to the same block? Both must be usable together — Table logic is no longer limited to at most one condition per block.
- What happens when a Customer Table condition has only one selected value? It behaves the same as the existing single-value case already handled for other Table conditions (e.g. Product Type) — no special-casing needed.
- What happens for a master in "Individual" mode, where some condition types are restricted to a narrower set of logic options? The Customer condition's availability of Table logic in Individual mode follows the same per-reference-type rule already governing every other condition type in that mode — Customer is not special-cased.
- What happens when `sp_load_compl_by_conditions` / `sp_load_compl_by_conditions_count` are reviewed per this request and no defect is found? The review is a verification step; it does not by itself authorize changing the stored procedures — any actual defect found must be confirmed with the requester before a fix is made.
- What happens when an existing Compliance Master record has no Alert type stored (e.g., data created before this feature)? It must display and be treated as "All" (value 0), everywhere it's shown (Create/Edit form and list).
- What happens if a user leaves the Alert type field untouched on Create? It must still submit with its current value (default "All") — the field is never blank/unset.
- What happens on Renew/Copy/Duplicate flows for a Compliance Master? The Alert type of the source master should carry over the same way other master-level fields do, unless the user changes it.
- What happens when the list is filtered, sorted, or paged? The Alert type column continues to show the correct value for whichever masters are currently displayed.
- What happens when a Compliance Master that the list marks as deletable already has some linked compliance/reference data attached to it (the state `MAS-01104` was in)? Deletion must not silently fail; see User Story 4.
- What happens when a Compliance Master has multiple versions (it was renewed/replaced)? Deleting one version must not corrupt the version history of the others or leave the record set in an inconsistent state.
- What happens if a delete is attempted on a master that another user already deleted moments earlier? The user should get a clear "no longer exists" outcome, not a generic failure.
- What happens with the bulk-delete action when it is used on a mix of masters, one of which is in the broken state? The same reliability expectations apply — no unexplained partial or silent failures.

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
- **FR-011**: When a user with Delete permission deletes a Compliance Master that the list/detail UI presents as eligible for deletion, the deletion MUST complete successfully, including master `MAS-01104` and any other master in the same underlying state.
- **FR-012**: If a Compliance Master cannot be deleted for a legitimate reason, the system MUST communicate the specific reason to the user at the time of the attempt — it MUST NOT present the delete action as available and then fail with a generic or unexplained error.
- **FR-013**: The fix to the delete action MUST address the underlying condition that caused the failure, not just the specific `MAS-01104` record, so the same failure does not recur for other Compliance Masters in that state.
- **FR-014**: Deleting a Compliance Master MUST NOT corrupt or orphan related data (e.g., other versions of the same master, its linked compliance/reference data) — related data is either cleanly removed as part of the deletion or the deletion is blocked, never left partially applied.
- **FR-015**: The bulk-delete action MUST meet the same reliability and error-communication expectations as the single-record delete action (FR-011 through FR-012) for every master included in the batch.
- **FR-016**: The Customer condition, wherever a rule condition's Type/logic can be selected (including the "Individual Rule Conditions (AND only)" section), MUST offer "Table" (multi-value) logic as an option, on the same basis Product Type already offers it.
- **FR-017**: A rule block MUST allow more than one condition to use Table logic at the same time (e.g. a Product Type condition and a Customer condition both using Table in the same AND block) — the system MUST NOT restrict Table logic to at most one condition per block.
- **FR-018**: When a Customer condition uses Table logic with multiple selected values, the Master Preview MUST render that condition's formula using the same presentation already used today for a Product Type Table condition — no new preview format is introduced by this change.
- **FR-019**: The compliance-matching logic underlying `sp_load_compl_by_conditions` and `sp_load_compl_by_conditions_count` MUST be reviewed to confirm it evaluates a Customer condition using Table logic (multiple selected values) correctly and consistently with how it already evaluates a Product Type Table condition. This is a verification requirement: if the review confirms correct behavior, no stored-procedure change is required; if the review surfaces an actual defect, the defect MUST be reported and confirmed with the requester before any fix is implemented.
- **FR-020**: Existing Compliance Masters with a Customer condition already saved as "Value" or "NOT IN" MUST continue to load, display, and evaluate exactly as before this change — enabling Table logic for Customer MUST NOT alter the meaning or evaluation of previously saved Value/NOT IN Customer conditions.

### Key Entities

- **Compliance Master**: The existing record type managed by the compliance-master feature; gains one new attribute, Alert type, describing which alert condition (All, Missing, Expired) the master applies to. Shown on the Create form, the Edit form, and the list. Also the subject of the list's delete and bulk-delete actions.
- **Alert Type**: A fixed classification with three values — All, Missing, Expired — representing the alert condition scope of a Compliance Master.
- **Rule Condition**: A single clause within a master's rule block (e.g. Country, Customer, Product Type), consisting of a reference type, a Type/logic (All, Table, Value, or NOT IN), and, for Table/Value/NOT IN, one or more selected values. Conditions within a block combine with AND; blocks combine with OR.
- **Condition Logic Type**: The classification of how a Rule Condition's selected values are matched — "All" (matches everything), "Table" (matches any of several selected values), "Value" (matches a single selected value), or "NOT IN" (excludes several selected values). Table and Value share the same underlying match behavior and differ only in how many values are selected.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can set the Alert type while creating a new Compliance Master with no extra steps beyond the existing save flow.
- **SC-002**: 100% of Compliance Masters (new and existing) show a defined Alert type value ("All", "Missing", or "Expired") — never blank — wherever they are viewed (Create/Edit form or list).
- **SC-003**: Editing an existing Compliance Master's Alert type and saving results in the new value being visible on the very next load of that master, 100% of the time.
- **SC-004**: Users can determine the Alert type of any listed Compliance Master directly from the list, for 100% of rows, without opening the record.
- **SC-005**: The Alert type column appears in the same position (directly after Status) for every row and every page of the list.
- **SC-006**: Deleting Compliance Master `MAS-01104` from the list completes successfully every time it is attempted by a user with Delete permission.
- **SC-007**: Any other Compliance Master in the same underlying state that previously broke deletion for `MAS-01104` can also be deleted successfully — the fix is not a one-record patch.
- **SC-008**: When a delete attempt is genuinely disallowed, 100% of the time the user is shown a specific reason at the moment of the attempt, never a generic or unexplained failure.
- **SC-009**: Users configuring a Customer condition can select "Table" logic and choose multiple customers, 100% of the time, regardless of whether another condition in the same rule block already uses Table logic.
- **SC-010**: For every Customer Table condition, the Master Preview formula matches the exact set of selected customers, using the same presentation already proven correct for Product Type Table conditions.
- **SC-011**: Compliance evaluation results (applied/missing) for a master using a Customer Table condition are verified to match the selected customer list with the same accuracy already established for Product Type Table conditions — the verification finding (change needed or not) is documented as part of this work.

## Assumptions

- The `AlertType` column already exists on the `compl_masters` table (per the original request), so no new database migration is required to introduce the column itself.
- Alert type values are fixed as: 0 = All, 1 = Missing, 2 = Expired; no additional values are in scope.
- Alert type is presented as a single-select field (dropdown) on the Create/Edit form, matching the style of similar single-choice fields already on the form.
- No new permission policy is required; access to view/edit the Alert type field follows the Compliance Master form's existing Create/Update permission checks.
- The field is always populated (defaults to "All"), so no "required field" validation error state is needed for it.
- Sorting and filtering the list by Alert type are out of scope for this request; only display is required in the list. This can be requested as a separate enhancement later.
- The delete failure is reproducible via master `MAS-01104` while viewing the list at `compliance-master?page=1&page-size=50`, but the page number and page size are just where it was noticed, not the cause — the underlying condition lives on the master record itself (it already has some compliance/reference data linked to it, even though the list currently presents it as eligible for deletion), so the fix must generalize to any master in that same state.
- "Delete" in User Story 4 refers to the existing single-record delete action already available from the Compliance Master list/detail screens, and equally to the existing bulk-delete action; no new delete entry point is being introduced.
- Whether a master with linked compliance data should delete-and-clean-up versus be blocked up front is an implementation decision to be resolved during planning; either satisfies this spec as long as the user is never left with an unexplained failure (FR-011, FR-012).
- The current "one Table-logic condition per rule block" restriction that blocks Customer from using Table today when another condition in the block already uses it is treated as a restriction to remove generally (FR-017), not a Customer-specific carve-out — the same relaxation applies to any combination of reference types sharing a block.
- Per explicit confirmation from the requester, the Master Preview formula for a Customer Table condition MUST reuse the existing presentation already used for a Product Type Table condition (operator followed by the selected values); no new inline "X in (A, B, C)" single-line format is being introduced by this change, for Customer or any other type.
- "Kiểm tra lại logic" (re-check the logic) for `sp_load_compl_by_conditions` / `sp_load_compl_by_conditions_count` is a verification task, not a standing authorization to modify these stored procedures — see FR-019.
- Whether the Customer reference type is eligible for Table logic while a master is in "Individual" mode is governed by the same existing per-reference-type configuration (e.g. an "allow individual" setting) that already governs every other condition type in that mode; this spec does not change that mechanism, only ensures Customer is not excluded from Table logic by any Customer-specific rule outside of it.
