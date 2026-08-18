# Feature Specification: Compliance Master Hierarchies

**Feature Branch**: `008-compl-master-hierarchies`

**Created**: 2026-07-30

**Status**: Draft

**Input**: User description: "chức năng mới compl-master-hierarchies, thiết kế giống hình tham khảo chức năng eutr/templates/edit/{id}. Khi user nhấn vào nút Add root, hoặc Add child, sẽ mở màn hình popup, load hết dữ liệu master từ compliance-master?page=1&page-size=50 có phân trang, gồm 4 cột Code, Name, Description, Action chỉ cần nút View condition. User check chọn master rồi nhấn Add. Dữ liệu lưu vào bảng compl_master_hierarchies, với Root thì cột ParentCode là rỗng, với Chill thì lấy cột MasterCode của Root lưu làm ParentCode. Giới hạn khi add Root phải kiểm tra đệ quy toàn bộ Parent không có mã Code giống với Root, thứ tự sắp xếp tree dựa vào cột DisplayOrder, Add root trước là 0 rồi tăng dần, tương tự với Add child"

**Update input (2026-07-30)**: User description: "cập nhật 008-compl-master-hierarchies thêm drap and drop ở master tree" (add drag-and-drop support to the master tree)

**Update input (2026-07-30, follow-up)**: User description: "trong chức năng drap and drop bỏ phần Drop here to make root, chỉ drap drop ở cùng level" (remove the "drop to make root" behavior; drag-and-drop is restricted to reordering nodes within the same level/parent only — no re-parenting via drag-and-drop)

**Update input (2026-07-30, follow-up 2)**: User description: "cập nhật 008-compl-master-hierarchies, màn hình Add root hoặc Add child. Thêm 1 textbox cho search theo Code, Name" (add a single search textbox to the Add root / Add child picker popup, letting the user filter the Compliance Master list by Code or Name)

**Update input (2026-08-10)**: User description: "cập nhật 008-compl-master-hierarchies, thêm nút View condition ở mỗi dòng master tree trong màn hình index" (add a "View condition" button to each row of the master hierarchy tree on the index screen itself — not just the Add root/Add child picker popup — so an admin can inspect a node's conditions directly from the built tree)

**Update input (2026-08-18, bug fix)**: User-reported test findings requiring a fix:
- CRITICAL BUG: tree data became duplicated (one master appearing at 2 positions in the tree). The duplicate was deleted to restore clean data for further testing. The system MUST block this at the backend by checking whether a master already exists anywhere in the tree before allowing it to be added as a root.
- CRITICAL BUG (same class as the root bug above): Add Child does not check for duplicates across the whole tree — it only blocks a direct cycle (master already in the target parent's ancestor chain), not a duplicate placement in an unrelated branch elsewhere in the tree. The duplicate was deleted to restore clean data.
- Delete confirmation gap: deleting a node did not show any confirmation popup at all — the system deleted immediately without asking. Confirmation was expected on every delete, with the existing descendant-count warning still appended when the node has descendants.

**Update input (2026-08-18, follow-up — delete confirmation correction)**: Clarified that the delete confirmation finding above IS a real gap (the earlier read of it as "not a bug" was wrong): the confirmation popup MUST appear for every delete action, regardless of whether the node has descendants; when it does have descendants, the popup additionally states how many will also be removed.

## Clarifications

### Session 2026-07-30

- Q: Who should be allowed to add, reorder, or delete nodes in the Compliance Master Hierarchies tree? → A: No restriction — any user who can view the Compliance Master list can also edit the hierarchy.
- Q: Is the Compliance Master Hierarchy a single global tree/forest shared by the whole system, or scoped per some other grouping/owner (e.g. category, template, business unit)? → A: Single global forest — one shared tree of Compliance Masters, no owning/grouping entity.
- Q: Can the exact same Compliance Master be added twice as a child under the same parent (identical Master Code + Parent Code)? → A: No — block it; a master cannot be added under a parent it is already a direct child of.

### Session 2026-08-18 (bug fix)

- Q: Can the same Compliance Master occupy more than one position in the tree, e.g. as root and also somewhere else, or as a child under two unrelated parents in different branches? → A: No — this was found to be a data-integrity bug in production testing. A Compliance Master MUST occupy at most one position in the entire hierarchy at any time. Both "Add root" and "Add child" MUST check the whole tree (every branch, every depth) for an existing occurrence of the master, not just the current list of roots (for Add root) or the target parent's ancestor chain and direct children (for Add child). This supersedes the earlier assumption that a master could appear in multiple unrelated branches.
- Q: Should every delete action show a confirmation popup? → A: **Yes** (corrected 2026-08-18 follow-up) — every delete, whether the node has descendants or not, MUST show a confirmation popup before the node is removed. When the node has one or more descendants, the popup additionally states how many descendant nodes will also be removed (the message already specified for the has-descendants case is APPENDED to, not a replacement for, the base confirmation). An earlier pass at this clarification incorrectly concluded no popup was needed for leaf-node deletes; that conclusion is superseded by this entry.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Build the top level of a hierarchy with Add root (Priority: P1)

A Compliance Admin wants to start organizing existing Compliance Masters into a tree structure. They open the Compliance Master Hierarchies screen, click "Add root", pick one or more Compliance Masters from a searchable, paginated list, and add them as new top-level (root) entries in the tree.

**Why this priority**: Without the ability to create root nodes, no hierarchy can exist at all — this is the foundational capability the rest of the feature builds on.

**Independent Test**: Can be fully tested by opening the Compliance Master Hierarchies screen, clicking "Add root", selecting one or more masters from the picker, clicking "Add", and confirming the selected masters now appear as top-level nodes in the tree, ordered by the sequence in which they were added.

**Acceptance Scenarios**:

1. **Given** the Compliance Master Hierarchies screen with an empty or existing tree, **When** the user clicks "Add root", **Then** a popup opens showing a paginated list of Compliance Masters (Code, Name, Description, and a "View condition" action) with 50 records per page.
2. **Given** the Add root popup is open, **When** the user checks one or more masters and clicks "Add", **Then** each checked master is added as a new root node in the tree, with an empty Parent Code and the next available Display Order value (0 for the first root ever added, then 1, 2, ... for each subsequent root).
3. **Given** the popup list has more than 50 Compliance Masters, **When** the user navigates to another page, **Then** the additional masters load and remain selectable/checkable the same way as the first page.
4. **Given** a master already exists anywhere in the tree — whether as a root, or as a child at any depth under any parent — **When** the user tries to add that same master as a root, **Then** the system rejects the addition and explains that the master already exists in the hierarchy (not only checking the current list of roots).
5. **Given** the Add root popup is open, **When** the user types a value into the search textbox, **Then** the list refreshes to show only Compliance Masters whose Code or Name contains that value, the pagination resets to the first page of matching results, and any masters already checked (on any page) remain checked even if they no longer match the search.
6. **Given** the user has typed a search value with no matching Compliance Masters, **When** the search runs, **Then** the popup shows an empty state instead of an empty table.
7. **Given** the user has typed a search value, **When** they clear the search textbox, **Then** the popup reloads the full, unfiltered, paginated list starting from the first page.

---

### User Story 2 - Nest masters under a parent with Add child (Priority: P2)

A Compliance Admin has already created one or more root nodes and now wants to build out the hierarchy by attaching related Compliance Masters underneath a selected node.

**Why this priority**: Nesting is what turns a flat list of roots into an actual hierarchy; it depends on User Story 1 having created at least one node to attach children to.

**Independent Test**: Can be fully tested by selecting an existing node in the tree, clicking "Add child", picking one or more masters from the same popup, clicking "Add", and confirming the selected masters appear nested directly under the selected node.

**Acceptance Scenarios**:

1. **Given** no node is currently selected in the tree, **When** the user looks at the toolbar, **Then** "Add child" is disabled or otherwise indicates a node must be selected first.
2. **Given** the user has selected a node in the tree, **When** they click "Add child", **Then** the same picker popup opens (Code, Name, Description, View condition, pagination, and the Code/Name search textbox) as for Add root.
3. **Given** the Add child popup is open for a selected parent node, **When** the user checks one or more masters and clicks "Add", **Then** each checked master is added as a new child of the selected node, its Parent Code set to the selected node's master code, and its Display Order set to the next available value among that parent's existing children (0 for the first child, then 1, 2, ...).
4. **Given** a master exists anywhere in the ancestor chain above the selected parent node (i.e., the selected parent, its parent, and so on up to the root), **When** the user tries to add that same master as a child under that parent, **Then** the system rejects the addition and explains that doing so would create a circular relationship.
5. **Given** a master is already a direct child of the selected parent node, **When** the user tries to add that same master under that same parent again, **Then** the system rejects the addition and explains that it is already a child of that parent.
6. **Given** a master already exists somewhere else in the tree — under a different, unrelated parent that is not in the selected parent's ancestor chain and not the selected parent itself — **When** the user tries to add that same master as a child under the selected parent, **Then** the system rejects the addition and explains that the master already exists elsewhere in the hierarchy (the check covers the whole tree, not only the ancestor chain and the direct children of the target parent).

---

### User Story 3 - Reorder and remove nodes to maintain the tree (Priority: P3)

A Compliance Admin needs to fix the order of nodes or remove ones that no longer belong, keeping the hierarchy accurate over time.

**Why this priority**: Once nodes exist (from User Stories 1 and 2), admins need ongoing tools to correct mistakes and keep the tree tidy; this is maintenance on top of the core build capability.

**Independent Test**: Can be fully tested by selecting a node with at least one sibling, using the up/down actions to change its position, confirming the on-screen order updates immediately, then selecting a node and deleting it, confirming it (and any descendants) are removed after confirmation.

**Acceptance Scenarios**:

1. **Given** a selected node has at least one sibling above or below it, **When** the user clicks the up or down action, **Then** the node swaps position with the adjacent sibling and the Display Order values are updated to reflect the new order.
2. **Given** a selected node is already first (or last) among its siblings, **When** the user clicks up (or down), **Then** the action has no effect or is disabled.
3. **Given** a selected node has no descendants, **When** the user clicks delete, **Then** a confirmation popup appears asking the user to confirm the deletion; upon confirmation, the node is removed from the tree.
4. **Given** a selected node has one or more descendants, **When** the user clicks delete, **Then** a confirmation popup appears that additionally warns how many descendant nodes will also be removed; upon confirmation, the node and all its descendants are removed together.
5. **Given** a large tree with multiple levels, **When** the user clicks "expand all" or "collapse all", **Then** every node in the tree opens or closes accordingly.

---

### User Story 4 - Review a master's conditions before adding it (Priority: P4)

While browsing the picker popup (opened from either Add root or Add child), a Compliance Admin wants to check what conditions a candidate Compliance Master already has before deciding whether to add it to the hierarchy.

**Why this priority**: This is a helpful lookup that supports better decisions in User Stories 1 and 2, but the picker and Add flow remain usable without it.

**Independent Test**: Can be fully tested by opening the picker popup and clicking "View condition" on any row, confirming that master's conditions are shown without closing the popup or losing the current selection/page.

**Acceptance Scenarios**:

1. **Given** the picker popup is open, **When** the user clicks "View condition" on a row, **Then** that master's existing compliance conditions are shown in a read-only view.
2. **Given** the user has already checked some masters and viewed a condition, **When** they close the condition view, **Then** their prior checkbox selections and current page remain unchanged.

---

### User Story 5 - Reorder siblings by dragging and dropping nodes (Priority: P3)

A Compliance Admin wants a faster, more visual way to reorder nodes: instead of using the up/down actions one step at a time, they click and drag a node directly to a new position among its current siblings (nodes sharing the same Parent Code) and drop it there. Drag-and-drop is intentionally limited to reordering within the same level — moving a node to a different parent, or promoting it to root, still requires the existing Add child / delete / move up-down actions.

**Why this priority**: Drag and drop is an alternative, more efficient interaction for the same same-level reordering job already covered by User Story 3; it depends on nodes already existing in the tree (User Stories 1 and 2) and does not unlock any data capability beyond what a sequence of move up/down actions could already achieve.

**Independent Test**: Can be fully tested by dragging a node onto a new position among its current siblings and confirming Display Order updates to match, then attempting to drag a node onto a node under a different parent and confirming the drop has no effect.

**Acceptance Scenarios**:

1. **Given** a node with at least one sibling, **When** the user drags it to a new position among its current siblings and drops it there, **Then** the node's Display Order and its former neighbors' Display Order values update immediately to reflect the new sequence, matching what a sequence of up/down actions would have produced.
2. **Given** a node, **When** the user drags it and drops it onto a node that does not share the same Parent Code, **Then** the drop has no effect and the tree remains exactly as it was — drag-and-drop only reorders within the same level.
3. **Given** the user starts dragging a node, **When** they drop it outside any valid target, **Then** the drag is cancelled and the tree remains exactly as it was.

---

### User Story 6 - Review a master's conditions directly from the tree (Priority: P4)

While browsing the built Compliance Master Hierarchies tree on the index screen (not the Add root/Add child picker popup), a Compliance Admin wants to check what conditions a node already has without removing it, re-adding it through the picker, or otherwise leaving the tree.

**Why this priority**: Like User Story 4, this is a convenience lookup that supports better decisions when maintaining an existing tree, but the tree remains fully usable (browse, add, reorder, delete) without it.

**Independent Test**: Can be fully tested by opening the Compliance Master Hierarchies screen with at least one existing node, clicking "View condition" on that node's row in the tree, and confirming that master's conditions are shown in a read-only view without changing the tree's expand/collapse state or the currently selected node.

**Acceptance Scenarios**:

1. **Given** the tree has at least one node, **When** the user clicks "View condition" on that node's row, **Then** that node's underlying Compliance Master's existing compliance conditions are shown in a read-only view.
2. **Given** the "View condition" read-only view is open, **When** the user closes it, **Then** the tree's expand/collapse state and currently selected node remain exactly as they were before it was opened.
3. **Given** a node whose underlying Compliance Master has no conditions defined, **When** the user clicks "View condition" on that row, **Then** the read-only view shows an empty state rather than an empty list.
4. **Given** the tree has multiple nodes at different depths, **When** the user clicks "View condition" on any one of them, **Then** only that node's conditions are shown, regardless of the node's depth or whether it is currently selected.

---

### Edge Cases

- What happens if the user selects masters on page 1, navigates to page 2, and selects more before clicking "Add"? Selections made across pages must be preserved and all of them added together.
- What happens if the user closes the popup without clicking "Add"? No changes are saved; the tree remains exactly as it was before opening the popup.
- What happens if two masters checked in the same "Add" action would individually pass validation, but adding both together would create a duplicate or a cycle (e.g., the same master checked twice is not possible via checkboxes, but two masters where one is an ancestor of the position and also checked as a sibling)? The system validates each selected master against the current tree state (including nodes already added earlier in the same action) and rejects only the ones that fail, explaining which failed and why, while still adding the ones that pass.
- What happens when the picker list has zero Compliance Masters, or the current page has none? The popup shows an empty state instead of an empty table.
- What happens when a Compliance Master used somewhere in the hierarchy is later deleted or deactivated in the Compliance Master feature? The existing hierarchy node keeps showing the last known Code/Name/Description; this is out of scope for this feature to reconcile.
- What happens if the same master code is added as a child under two different parents that are not in each other's ancestor chain? This is NOT allowed — a Compliance Master may occupy only one position in the entire hierarchy at a time. The system checks the whole tree (every branch, every depth), not only the ancestor chain and the target parent's direct children, and rejects the addition if the master already exists anywhere else.
- What happens if the user deletes a node with no descendants? A confirmation popup still appears (the same base "are you sure you want to delete this node?" confirmation shown for every delete); it just does not include the descendant-count warning, since there are none (see FR-015).
- What happens if a user without any special hierarchy-specific permission opens the screen? They can use it the same as any other user — access follows only the existing permission to view the Compliance Master list; there is no separate hierarchy permission to check.
- What happens if the user drags a node and drops it back onto its exact original position? No change is made; Display Order values remain as they were.
- What happens if the user drags a node and drops it onto a node under a different Parent Code (or onto empty space outside the tree)? Nothing happens — cross-level drag-and-drop is not supported; the tree remains unchanged and the user must use Add child / delete / move up-down to relocate a node instead.
- What happens if the user searches while some masters are already checked on the current or another page? Checked masters stay checked and are still included when "Add" is clicked, even if they are filtered out of view by the current search text.
- What happens if the user searches, selects some masters, then closes the popup without clicking "Add"? Same as the general close-without-Add case — no changes are saved and the search text is discarded along with the selections when the popup is reopened.
- What happens if the search text matches a Code on one master and a Name on a different master? Both masters are included in the filtered results — the search checks Code and Name independently, not as a combined field.
- What happens if the user clicks "View condition" on a tree row while that same row is currently selected (highlighted for Add child/move/delete)? The selection is unaffected; viewing conditions is a read-only lookup and never changes which node is selected.
- What happens if the user clicks "View condition" on one tree row while another row's condition view is already open? The newly clicked row's conditions replace the previously shown ones in the same read-only view; only one condition view is open at a time.
- What happens if the underlying Compliance Master for a tree node was deleted or deactivated since it was added to the hierarchy? "View condition" still attempts to load that master's conditions; if none can be found, the read-only view shows an empty state rather than an error that blocks the tree.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST provide a Compliance Master Hierarchies screen showing all existing hierarchy nodes as a tree, ordered by Display Order within each level and indented to reflect parent-child depth.
- **FR-002**: The screen MUST provide "Add root", "Add child", move up, move down, delete, expand-all, collapse-all, and "Back" actions, mirroring the layout and behavior of the existing template hierarchy editor, plus the ability to drag and drop any node to reorder it among its current siblings.
- **FR-003**: The system MUST provide an "Add root" action that opens a popup for selecting one or more Compliance Masters to add as new top-level nodes.
- **FR-004**: The system MUST provide an "Add child" action that is only usable when a tree node is currently selected, and opens the same popup for selecting one or more Compliance Masters to add as children of the selected node.
- **FR-005**: The popup MUST load Compliance Masters from the existing Compliance Master list, 50 records per page, with controls to navigate additional pages.
- **FR-006**: The popup MUST display, for each Compliance Master row, its Code, Name, Description, and a "View condition" action; no other columns are required.
- **FR-007**: The popup MUST let the user check (select) one or more Compliance Masters, preserving selections made across different pages, and confirm the selection with an "Add" action.
- **FR-008**: The "View condition" action MUST show the selected master's existing compliance conditions in a read-only view without closing the popup or discarding the current checkbox selections or page.
- **FR-009**: When a Compliance Master is added via "Add root", the system MUST create a hierarchy record with an empty Parent Code and a Display Order equal to one more than the highest Display Order currently used among existing root nodes (starting at 0 for the first root).
- **FR-010**: When a Compliance Master is added via "Add child" under a selected node, the system MUST create a hierarchy record whose Parent Code equals the selected node's master code, and a Display Order equal to one more than the highest Display Order currently used among that parent's existing children (starting at 0 for the first child).
- **FR-011**: Before adding a Compliance Master as a root, the system MUST check the entire hierarchy tree — not only the current list of root nodes — and reject the addition if that same master code already exists anywhere in the tree, whether as a root or as a child at any depth under any parent.
- **FR-012**: Before adding a Compliance Master as a child, the system MUST check the entire hierarchy tree — not only the target parent's ancestor chain — and reject the addition if that same master code already exists anywhere else in the tree, including: anywhere in the target parent's ancestor chain (which would create a circular relationship), as a root, as a direct child of the same target parent, or as a child under any other, unrelated parent in a different branch.
- **FR-013**: When rejecting an Add root or Add child action under FR-011 or FR-012, the system MUST explain the specific reason (e.g., master is already a root, already a direct child of this parent, already present in the ancestor chain and would create a cycle, or already present elsewhere in a different branch) so the user understands why the action failed.
- **FR-014**: The system MUST let the user reorder a selected node up or down among its siblings (nodes sharing the same Parent Code), updating the affected nodes' Display Order values to reflect the new sequence.
- **FR-015**: The system MUST let the user delete a selected node, and MUST always show a confirmation popup before removing it, regardless of whether it has descendants. If that node has descendants, the confirmation popup MUST additionally warn the user how many descendant nodes will also be removed; upon confirmation, the node and all its descendants are removed together. If the node has no descendants, the confirmation popup shows the base "are you sure?" message only (no descendant-count warning), and upon confirmation only that node is removed.
- **FR-016**: The system MUST let the user expand or collapse individual nodes, as well as expand or collapse the entire tree at once.
- **FR-017**: The system MUST persist each Add, reorder, and delete action immediately; there is no separate save step for hierarchy changes.
- **FR-018**: Each tree node MUST display at least its Compliance Master's Code and Name.
- **FR-019**: The "Back" action MUST return the user to the screen they came from.
- **FR-020**: Viewing and editing the Compliance Master Hierarchies screen (Add root, Add child, reorder, delete) MUST be available to any user who already has access to view the Compliance Master list; no additional or narrower permission is required.
- **FR-021**: The system MUST maintain exactly one Compliance Master Hierarchy (a single forest of root trees, all sharing the same `compl_master_hierarchies` data) shared across the whole system; hierarchy nodes are not grouped or scoped by category, template, business unit, or any other owning entity.
- **FR-022**: The system MUST let the user drag a node and drop it onto a new position among nodes sharing the same Parent Code, reordering it and updating the affected Display Order values the same way as the existing move up/down actions.
- **FR-023**: The system MUST restrict drag-and-drop moves to nodes sharing the same Parent Code as the dragged node; dropping onto a node under a different Parent Code, or onto any area outside the tree, MUST have no effect and MUST NOT re-parent the node or promote it to root.
- **FR-024**: A drag-and-drop reorder MUST persist immediately upon a valid drop, consistent with FR-017 (no separate save step).
- **FR-025**: The picker popup (opened from both "Add root" and "Add child") MUST provide a single search textbox that filters the Compliance Master list by Code or Name, matching either field, and MUST re-run the search as a new, paginated first-page query rather than filtering only the currently loaded page.
- **FR-026**: Searching in the picker popup MUST NOT clear or discard masters already checked on any page; previously checked masters remain checked, and remain part of the eventual "Add" action, even while filtered out of the current search results.
- **FR-027**: Clearing the search textbox MUST restore the full, unfiltered, paginated Compliance Master list starting from the first page.
- **FR-028**: Each node row in the Compliance Master Hierarchies tree (the index screen, distinct from the Add root/Add child picker) MUST include a "View condition" action, alongside the node's Code and Name (per FR-018), that shows that node's underlying Compliance Master's existing compliance conditions in a read-only view.
- **FR-029**: Opening "View condition" from a tree row MUST NOT change the tree's expand/collapse state or the currently selected node, and MUST NOT require a node to be selected first (it acts on the row that was clicked, independent of the selection used by Add child/move/delete).
- **FR-030**: Opening "View condition" from a tree row MUST show the same kind of read-only condition view already used by the Add root/Add child picker's "View condition" action (FR-008), for a consistent experience across both places it appears.

### Key Entities

- **Compliance Master Hierarchy Node**: Represents one placement of a Compliance Master within the single, system-wide hierarchy tree/forest. Key attributes: the Master Code it represents, its Parent Code (empty when the node is a root; otherwise the Master Code of its parent node), and its Display Order (its position among sibling nodes, starting at 0). A single Compliance Master may occupy only one node position across the entire tree at any time — this is enforced by checking the whole tree, not only the direct children of a given parent or the ancestor chain. There is exactly one such hierarchy in the system — nodes are not grouped or owned by any other entity.
- **Compliance Master**: The existing reference record (Code, Name, Description, and its own compliance conditions) that a hierarchy node points to. Selected via the picker popup; not modified by this feature.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A Compliance Admin can add a new root-level node to the hierarchy, from clicking "Add root" to seeing it appear in the tree, in under 30 seconds.
- **SC-002**: 100% of attempts to create a duplicate placement of a master anywhere in the tree (as a duplicate root, a duplicate sibling, a circular ancestor relationship, or a duplicate in an unrelated branch elsewhere in the tree) are blocked before any hierarchy data is saved, with a clear explanation shown to the user.
- **SC-003**: A Compliance Admin can build a hierarchy at least 3 levels deep (root, child, grandchild) without leaving the Compliance Master Hierarchies screen.
- **SC-004**: Reordering a node updates its displayed position within the same interaction, 100% of the time, with no page reload required.
- **SC-005**: Deleting a node with descendants requires exactly one confirmation step and removes 100% of its descendants together with it.
- **SC-006**: A Compliance Admin can find and select any Compliance Master out of 50+ existing records using the popup's pagination, without needing to already know its Code.
- **SC-007**: A Compliance Admin can move a node to a new position among its current siblings via drag and drop, from starting the drag to seeing the updated tree, in under 10 seconds and without opening any popup.
- **SC-008**: A Compliance Admin can locate a specific Compliance Master in the picker popup by typing part of its Code or Name, without paging through results manually, in under 10 seconds.
- **SC-009**: A Compliance Admin can check any existing tree node's compliance conditions directly from the Compliance Master Hierarchies index screen, without opening the Add root/Add child picker, in under 10 seconds.

## Assumptions

- The Compliance Master Hierarchies screen is visually and behaviorally modeled on the existing template hierarchy editor (`eutr/templates/edit/{id}`): a toolbar with Add root / Add child / move up / move down / delete / expand-all / collapse-all / Back, and a tree view below it.
- Every Add, reorder, and delete action is persisted immediately, matching the reference screen's design (no visible "Save" step) — there is no draft/unsaved state to manage.
- The picker popup reuses the existing Compliance Master list data (Code, Name, Description) and the existing "view condition" capability already available elsewhere in the Compliance Master feature; it does not introduce new condition-editing behavior.
- The picker popup supports selecting multiple Compliance Masters at once (via checkboxes) and adding them all in a single "Add" action, consistent with the checkbox-driven selection described in the request.
- A given Compliance Master's code can occupy exactly one position anywhere in the entire hierarchy tree at any time — either as a root, or as a child under exactly one parent. This is checked against the whole tree (every branch, every depth), not only against the current list of roots, the immediate ancestor chain, or the direct children of the target parent. (Revised 2026-08-18: this replaces the earlier assumption that a master could appear as a child under multiple unrelated parents — that behavior was found to cause duplicated tree data in testing.)
- Deleting a hierarchy node also deletes all of its descendant nodes; there is no option to delete a single node while re-parenting its children.
- Concurrent editing of the same hierarchy by multiple users at the same time is out of scope; the last action saved wins, consistent with how similar master-data screens in this system behave today.
- This feature only manages the hierarchy relationships between existing Compliance Masters; creating, editing, or deleting Compliance Master records themselves is out of scope (handled by the existing Compliance Master feature).
- Drag and drop is an additional interaction for the same same-level reorder job already described in User Story 3 (move up/down); it does not introduce a new kind of relationship and does not re-parent nodes. Moving a node to a different parent, or promoting it to root, remains exclusively a delete + Add child / Add root operation — there is no drag-based path to change a node's Parent Code.
- The picker popup's search textbox is a single input that matches against both Code and Name (an "OR" match on either field), not two separate search fields; this mirrors how similar master-data list searches behave elsewhere in the system.
- Searching re-queries the Compliance Master list server-side (same source as the existing paginated load) rather than filtering only the masters already fetched into the current page, so search results are accurate even when a match exists on a page the user has not yet visited.
- "View condition" on a tree row and "View condition" in the picker popup both read the same underlying Compliance Master conditions and present them the same way; the tree row action is an additional entry point to the same read-only lookup already specified for the picker (User Story 4 / FR-008), not a new kind of condition data or editing capability.
- Clicking "View condition" on a tree row is independent of node selection: it does not select the node, and it works the same whether or not that row (or any row) is currently selected for Add child/move/delete.
