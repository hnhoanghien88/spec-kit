# Feature Specification: Group Email — Add "DK Alert" Type Option

**Feature Branch**: `018-compl-group-email-dk-alert`

**Created**: 2026-09-03

**Status**: Draft

**Input**: User description: "tính năng compl-group-email màn index, chức năng Add/Edit. cột Type hiện tại có 2 type 1 = Responsible, 2 = Alert. Giờ thêm 3 = DK alert." (Group Email feature, index screen and Add/Edit function. The Type column currently offers 2 types — 1 = Responsible, 2 = Alert. Add a third type, 3 = DK Alert.)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Select "DK Alert" when creating a new Group Email (Priority: P1)

A Compliance Admin creating a new email group needs to classify it as "DK Alert" (in addition to the existing "Responsible" and "Alert" classifications) so the group's purpose is correctly recorded from the moment it is created.

**Why this priority**: This is the core of the request — without it, there is no way to create a group with the new classification at all.

**Independent Test**: Can be fully tested by opening the Group Email index screen, starting to add a new group, opening the Type dropdown, confirming "DK Alert" is listed alongside "Responsible" and "Alert", selecting it, saving the new group, and confirming it is persisted and displayed with Type "DK Alert".

**Acceptance Scenarios**:

1. **Given** a user opens the "add new group" row on the Group Email index screen, **When** they open the Type dropdown, **Then** three options are available: "Responsible", "Alert", and "DK Alert".
2. **Given** a user is filling out a new group email, **When** they select "DK Alert" as the Type, **Then** the selection is reflected in the form before saving.
3. **Given** a user has selected "DK Alert" and provided the other required fields (e.g. Name), **When** they save the new group, **Then** the group is created with Type "DK Alert" and appears in the index list with that Type.

---

### User Story 2 - Change an existing Group Email's Type to or from "DK Alert" (Priority: P2)

A Compliance Admin editing an existing email group on the index screen needs to see and change its Type, including switching it to or away from "DK Alert", using the same inline edit behavior already used for "Responsible" and "Alert".

**Why this priority**: Existing groups need the same access to the new classification as newly created ones, but this depends on User Story 1 establishing the option first.

**Independent Test**: Can be fully tested by opening an existing group row in edit mode, changing its Type to "DK Alert" (or from "DK Alert" to another type), saving, and confirming the change is persisted and reflected in the index list.

**Acceptance Scenarios**:

1. **Given** a user opens an existing group email row in edit mode, **When** the Type dropdown is displayed, **Then** it offers the same three options ("Responsible", "Alert", "DK Alert") and shows the group's current value selected.
2. **Given** a user changes an existing group's Type to "DK Alert", **When** they save the change, **Then** the updated Type is persisted and the index list reflects "DK Alert" for that group.
3. **Given** a group currently has Type "DK Alert", **When** a user edits it and selects a different Type, **Then** the change is saved and the group no longer shows as "DK Alert".

---

### User Story 3 - View "DK Alert" groups on the index screen (Priority: P3)

A Compliance Admin browsing the Group Email index screen needs to clearly see which groups are classified as "DK Alert" alongside the existing "Responsible" and "Alert" groups, so they can find and audit them.

**Why this priority**: Read/visibility is lower risk than the create/edit capability but is necessary for the new classification to be usable in practice.

**Independent Test**: Can be fully tested by viewing the index screen after at least one group has Type "DK Alert" and confirming the value is displayed clearly (not blank or a raw code) in the list.

**Acceptance Scenarios**:

1. **Given** one or more groups have Type "DK Alert", **When** a user views the Group Email index screen, **Then** each such group displays "DK Alert" as its Type label, not a numeric code or blank value.

---

### Edge Cases

- What happens if a user attempts to save a new or edited group without selecting any Type? (Current behavior for "Responsible"/"Alert" applies unchanged — no new constraint is introduced by this feature beyond what already exists today.)
- What happens if a group email record already has a Type value that does not correspond to any of the three labeled options (e.g. legacy/unmapped data)? The index and edit screens must not error or crash; they should degrade gracefully (e.g., show it as blank/unrecognized) exactly as today's behavior does for values outside the current 2 options.
- Does adding "DK Alert" affect any other screen or process that reads a group email's Type (e.g. downstream alert routing, reports)? Out of scope for this feature unless such usage is discovered during planning — this spec only covers the Type field's selectable options and its display on the Group Email index/Add/Edit surfaces.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The Group Email Type selector (used in both the Add and Edit flows on the index screen) MUST offer exactly three options: "Responsible", "Alert", and "DK Alert".
- **FR-002**: Users MUST be able to select "DK Alert" as the Type when creating a new group email.
- **FR-003**: Users MUST be able to change an existing group email's Type to or from "DK Alert" when editing.
- **FR-004**: The system MUST persist the "DK Alert" classification distinctly from "Responsible" and "Alert" so it can be reliably saved, retrieved, and displayed.
- **FR-005**: The Group Email index screen MUST display "DK Alert" as a human-readable label (not a raw numeric value) for groups with that Type.
- **FR-006**: The system MUST reject (or otherwise prevent persisting) a Type value that is not one of the three supported options when creating or editing a group email.

### Key Entities *(include if feature involves data)*

- **Group Email**: An email group used by the compliance system, classified by a Type (previously "Responsible" or "Alert", now also "DK Alert"). Each group has a Name and a Type, and is shown as a row on the index screen with inline Add/Edit.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A Compliance Admin can create a new group email with Type "DK Alert" in under 1 minute using the existing Add flow.
- **SC-002**: 100% of group email rows with Type "DK Alert" display that label correctly (not blank or numeric) on the index screen.
- **SC-003**: Existing groups with Type "Responsible" or "Alert" are unaffected — their values and behavior remain unchanged after this feature ships.

## Assumptions

- "DK Alert" is used here as the literal, final label text to display in the Type dropdown and index list, as given in the request; no translation or alternate wording is assumed.
- The three Type options are mutually exclusive and single-select, consistent with the existing "Responsible"/"Alert" selector behavior.
- No existing group email records currently rely on a third/fourth Type value in a way that conflicts with introducing "DK Alert" as the next selectable option; this should be verified against production data during planning before implementation.
- This feature covers only the Group Email index screen's Type field (Add/Edit/Display). Changes to downstream consumers of a group's Type (e.g., alert-routing logic, reports, exports) are out of scope unless discovered as required during planning.
- No new permission/role is introduced — the same users who can already create/edit "Responsible" and "Alert" groups can also create/edit "DK Alert" groups.
