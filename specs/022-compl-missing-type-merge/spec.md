# Feature Specification: Merge Compliance Missing Screens by Type

**Feature Branch**: `022-compl-missing-type-merge`

**Created**: 2026-10-08

**Status**: Draft

**Input**: User description: "gộp 020-compl-missing-detail vào màn hình Compliance missing ở link /compliance-missing. giữ nguyên logic 2 màn hình. nhưng thêm 1 type ở màn hình. Nếu type = Open orders thì hiển thị bảng, dữ liệu, chức năng, các nút của màn hình compliance-missing, còn type = compliance thì hiển thị bảng, dữ liệu, chức năng, các nút của màn hình compliance-missing-bk. Khi vào mặc định type = Open orders"

## Clarifications
### Session 2026-10-08 (Update 3) — Toán tử filter cột (Type = Compliance)

- Lỗi: filter "does not contain" không có tác dụng vì client chỉ gửi contains/equals. Quyết định: ánh xạ thêm doesNotContain→notcontains, doesNotEqual→notequals, startsWith, endsWith, isEmpty, isNotEmpty (backend `ComplMissingDetailRepository` đã hỗ trợ). Code: `compliance-missing-detail/hooks/useComplMissingDetailData.js`.


### Session 2026-10-08 (Update 2) — Đổi vị trí cột + nút View condition (Type = Compliance)

- Yêu cầu: ở Type = Compliance, di chuyển 3 cột **Type, Product, Product name** lên ngay sau cột **Name**; thêm nút **View condition** kế cột **Master name**, logic giống nút View Conditions ở màn hình `compliance-master`.
- Quyết định: nút là cột icon (PreviewOutlined, tooltip "View Conditions") sau Master name, gọi `GetConditionsByMasterIdUseCase` với `masterId` của dòng rồi mở `ConditionsView` (title "Conditions"); chỉ hiện khi user có quyền `ReadOne` của menu `compliance-master` (đúng điều kiện ở màn compliance-master). Thứ tự cột mới: Master code, Master name, [View condition], Status, Code, Name, Type, Product, Product name, Valid from, Valid to, Days remaining, Responsible emails, Description. File Excel export giữ nguyên thứ tự cột hiện tại (không đổi backend). Code: `compliance-missing-detail/index.jsx`, `hooks/useComplMissingDetailColumns.jsx`.

### Session 2026-10-08 (Update 1) — Export Excel cho Type = Compliance

- Yêu cầu: ở Type = Compliance thêm nút **Export Excel** kế nút **Get from D365**; khi nhấn, xuất tất cả dữ liệu ra file Excel với các cột, dữ liệu và màu dòng giống màn hình đang hiển thị.
- Quyết định: nút chỉ thuộc Type = Compliance (Open orders giữ nguyên nút của nó). "Tất cả dữ liệu" = mọi dòng khớp bộ lọc/sắp xếp hiện tại, không giới hạn trang đang xem. Cột trong file = đúng các cột đang hiển thị trên lưới (cột Follow up date/Note đang ẩn theo Update 3 của spec 020 thì không có trong file); dòng Expired tô cùng màu như trên lưới. Thay cho cờ ẩn Export/Import của spec 020 (Update 3): nút Export hiện lại, Import vẫn ẩn.

## Context

Today two separate menu screens exist:

- **Compliance missing** (`/compliance-missing`): missing/expired compliance derived from open sales orders (Sales order, ETD, Invoice date and customer columns; Year / ETD Week filters; "Get from D365" refresh).
- **Compliance missing detail** (`/compliance-missing-bk`, feature 020): missing/expired compliance derived from compliance detail, one row per (Master code, Code, Type, Product), without sales-order columns.

This feature presents both as one screen at `/compliance-missing`, switched by a **Type** selector. Neither screen's own logic, data, columns, filters, permissions or buttons change; they are only hosted under one selector.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Open the screen and see Open orders by default (Priority: P1)

A compliance user opens `/compliance-missing`. A **Type** dropdown is shown at the top-left with **Open orders** selected, and the screen looks and behaves exactly as the current "Compliance missing" screen (title with missing-count badge, Year and ETD Week filters, the open-orders grid, and all its buttons).

**Why this priority**: Preserves existing behaviour for current users; it is the entry point of the merged screen.

**Independent Test**: Open `/compliance-missing`; confirm Type = Open orders and the grid, data, filters and buttons are identical to the current Compliance missing screen.

**Acceptance Scenarios**:

1. **Given** a user with access to the screen, **When** they open `/compliance-missing`, **Then** Type shows "Open orders" and the open-orders table, data, filters and buttons are displayed.
2. **Given** the screen is open on Open orders, **When** the user sorts, filters, pages, edits follow-up date/note, exports, imports or refreshes from D365, **Then** each works exactly as on the current Compliance missing screen.

---

### User Story 2 - Switch Type to Compliance (Priority: P1)

The user changes Type to **Compliance**. The screen then shows the table, data, functions and buttons of the current "Compliance missing detail" screen (no sales-order columns, no Year/ETD Week filters, "Get from D365" trigger, etc.), with the behaviour defined in feature 020.

**Why this priority**: This is the point of the merge — the second screen must stay reachable and complete.

**Independent Test**: On `/compliance-missing`, set Type = Compliance; confirm content matches the current Compliance missing detail screen in grid, columns, data, filters and buttons.

**Acceptance Scenarios**:

1. **Given** Type = Open orders, **When** the user selects Compliance, **Then** the compliance-detail grid, data, filters and buttons are shown and open-orders-only controls (Year, ETD Week, sales-order columns) are not shown.
2. **Given** Type = Compliance, **When** the user selects Open orders, **Then** the open-orders content is shown again.
3. **Given** Type = Compliance, **When** the user uses sort/filter/paging, export/import/notes (where enabled in feature 020) and Get from D365, **Then** they behave exactly as on the current Compliance missing detail screen.

---

### User Story 3 - Permissions and menu follow the merge (Priority: P2)

Users only see and use what their existing permissions allow for each Type. The separate "Compliance missing detail" menu entry is retired in favour of the single "Compliance missing" entry.

**Why this priority**: Prevents access leaks and duplicate navigation, but secondary to the core switching.

**Independent Test**: Log in as users holding only one of the two permission sets and check which Type options are available; check the menu has one entry for both.

**Acceptance Scenarios**:

1. **Given** a user with permission for both screens, **When** they open the screen, **Then** both Types are selectable.
2. **Given** a user with permission for only one screen, **When** they open the screen, **Then** only that Type is available and it is selected automatically.
3. **Given** a user with permission for neither, **When** they try to open the screen or load its data, **Then** access is denied as today.
4. **Given** the merge is live, **When** the user looks at the menu, **Then** there is one "Compliance missing" entry at `/compliance-missing`.

---

---

### User Story 4 - Export the Compliance list to Excel (Priority: P2) *(Update 1)*

With Type = Compliance, the user clicks **Export Excel** (next to **Get from D365**) and receives an Excel file with all rows of the list, with the same columns, data and row colouring as the screen.

**Why this priority**: Users need to take the full list offline/share it; secondary to viewing and switching.

**Independent Test**: Set Type = Compliance, optionally apply a filter and sort, click Export Excel, open the file and compare it with the screen.

**Acceptance Scenarios**:

1. **Given** Type = Compliance with data, **When** the user clicks Export Excel, **Then** an `.xlsx` file downloads containing every row matching the current filters/sort (not just the current page).
2. **Given** the file is open, **When** compared with the screen, **Then** the columns (same set, same order, same headings) and cell values match what the screen shows, and rows highlighted on screen (e.g., Expired) are highlighted the same way.
3. **Given** the list is empty, **When** the user looks at the button, **Then** Export Excel is disabled.
4. **Given** an export is running, **When** the user looks at the button, **Then** it shows a busy state and cannot be clicked again; on failure an error message is shown.
5. **Given** Type = Open orders, **When** the user looks at the header, **Then** its buttons are unchanged and no new Export button is added by this feature.
6. **Given** the user lacks the Download permission of the screen, **When** the screen loads, **Then** Export Excel is not shown.

---

### Edge Cases

- Export with filters applied exports the filtered set; with none, the whole list.
- Very large lists must still export fully without the user having to page through.

- Switching Type must not carry over filters, sorting, selection, pending edits or column settings from the other Type; each Type keeps its own state and saved grid preferences.
- Switching Type while the previous Type's data is still loading must not show that data under the new Type.
- A refresh job started under one Type must not change what the other Type displays until that Type is reloaded.
- A user with permission for only one Type sees that Type, not an empty or forbidden state.
- Existing bookmarks to `/compliance-missing-bk` should still land on the merged screen with Type = Compliance.
- The header missing-count badge reflects the currently selected Type's data.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The screen at `/compliance-missing` MUST show a **Type** selector (top-left, before the title) with options **Open orders** and **Compliance**.
- **FR-002**: On entering the screen, Type MUST default to **Open orders**.
- **FR-003**: With Type = Open orders, the screen MUST display the table, data, functions and buttons of the current Compliance missing screen, unchanged.
- **FR-004**: With Type = Compliance, the screen MUST display the table, data, functions and buttons of the current Compliance missing detail screen (feature 020), unchanged.
- **FR-005**: Controls belonging to only one Type (e.g., Year and ETD Week for Open orders) MUST be shown only for that Type.
- **FR-006**: Each Type MUST keep its own data, filters, sorting, paging, column visibility and saved grid preferences, independent of the other Type.
- **FR-007**: The business logic, data sources, refresh jobs, notes and permissions of both screens MUST remain unchanged; the merge only changes where they are presented.
- **FR-008**: A Type option MUST be available only if the user holds the corresponding existing permission; if only one is permitted it is selected automatically; if none, access is denied as today.
- **FR-009**: The "Compliance missing detail" menu entry MUST be removed from navigation, leaving a single "Compliance missing" entry at `/compliance-missing`.
- **FR-010**: Opening `/compliance-missing-bk` MUST land on the merged screen with Type = Compliance.
- **FR-011**: The header missing-count badge MUST reflect the selected Type's data.
- **FR-012** *(Update 1)*: With Type = Compliance, the screen MUST show an **Export Excel** button immediately after **Get from D365**; it MUST NOT appear for Type = Open orders.
- **FR-013** *(Update 1)*: Clicking Export Excel MUST produce an Excel file containing all rows matching the current filters and sorting (not limited to the visible page).
- **FR-014** *(Update 1)*: The exported file MUST have the same columns (set, order, headings), the same cell values and the same row highlighting as the screen; columns hidden on screen MUST NOT be exported.
- **FR-015** *(Update 1)*: Export Excel MUST be disabled when the list is empty or while an export is running, MUST show a success or error message, and MUST be shown only to users holding the screen's Download permission.
- **FR-016** *(Update 2)*: With Type = Compliance, the columns Type, Product and Product name MUST appear immediately after Name.
- **FR-017** *(Update 2)*: With Type = Compliance, a **View condition** button MUST appear in its own column right after Master name and MUST open the conditions dialog of the row's master with the same logic as the compliance-master screen; it is shown only to users holding that screen's ReadOne permission.

### Key Entities

- **Type**: A screen-level selector value (Open orders | Compliance) deciding which of the two existing views is shown. Not stored on any data row.
- **Open-orders missing item**: Existing record set behind the current Compliance missing screen (per sales order).
- **Compliance-detail missing item**: Existing record set behind the Compliance missing detail screen (per Master code, Code, Type, Product).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of the grids, columns, filters and buttons on the two current screens are available on the merged screen under the matching Type, with no behavioural difference.
- **SC-002**: Opening `/compliance-missing` always shows Open orders first.
- **SC-003**: A user can switch between the two Types in one action and see the new Type's content within the same time each screen takes to load on its own today.
- **SC-004**: Users with a single permission set see exactly one Type; users with none are denied, in 100% of tested cases.
- **SC-005**: After the merge, navigation contains one Compliance missing entry instead of two.
- **SC-006** *(Update 1)*: In 100% of tested exports, the file's row count equals the screen's total for the same filters, and columns, values and row colours match the screen.

## Assumptions

- "Type = compliance" refers to the screen currently named Compliance missing detail (feature 020, now at `/compliance-missing-bk`); its Type label is "Compliance".
- The Type selector is a labelled dropdown at the top-left, as in the provided mockup, with the title/badge to its right and Year / ETD Week filters on the right for Open orders.
- Type is not persisted across visits; each entry starts at Open orders. Within a visit, each Type keeps its own state.
- Existing permissions are reused; no new permissions are introduced. Menu/permission records are managed outside this repository, so aligning them is a deployment step.
- Feature 020's behaviours (including the temporarily hidden Export/Import and follow-up columns from its Update 3) are carried over as they are at merge time.
- Backend endpoints for both screens are unchanged.
- *(Update 1)* Export reuses the existing Compliance-detail export capability and its permission; the Export button returns on screen while Import and the Follow up date/Note columns stay hidden (feature 020 Update 3).
- *(Update 1)* "All data" means all rows matching the current filters, as it is the same list the user is looking at.
