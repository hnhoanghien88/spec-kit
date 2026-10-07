# Feature Specification: Compliance Missing Detail

**Feature Branch**: `020-compl-missing-detail`

**Created**: 2026-10-05

**Status**: Draft

**Input**: User description: "chức năng mới compliance-missing-detail, dùng menu link /compliance-missing. giao diện giống /compliance-missing-open-orders. nhưng không có cột Sales order. logic khác chút. màn hình compliance-missing-open-orders. đang lấy dữ liệu từ open order sau đó tìm ra các compliance missing, expriry. màn hình mới này sẽ không đi từ open order. mà đi từ compliance detail"

**Update (2026-10-05, data source = refresh trigger + compl_missing_detail table)**: "cập nhật lại spec, sẽ tạo 1 service [HttpGet("test-compliance-missing")] logic sẽ chạy hàm BuildCurrentSalesOrderAlertComplianceListAsync để lấy dữ liệu ghi vào bảng compl_so_missing, không gửi email, sau đó dữ liệu từ bảng compl_so_missing lưu vào bảng mới compl_missing_detail (bảng này các cột giống compl_so_missing nhưng không có salesId) dữ liệu sẽ group theo MasterCode,Code,MappedRefTypeCode,MappedInputValue. dùng dữ liệu bảng này compl_missing_detail để hiển thị ở màn hình mới" — this **replaces** the earlier idea of deriving Missing/Expired live from master/reference/compliance tables. The list is now a stored snapshot (`compl_missing_detail`) produced by a new manual refresh trigger named `test-compliance-missing`. That trigger re-runs the same evaluation the existing sales-order alert uses (writing the existing missing-compliance store `compl_so_missing`), sends **no** email or notification, then copies that store — grouped by Master code, Code, Type and Product, without Sales order — into the new store. The screen reads only the new store. User Story 1, FR-004 to FR-008, FR-013, the Key Entities and the Assumptions below were rewritten accordingly; the first clarification answer (live derivation from master/compliance tables) is superseded.

## Clarifications

### Session 2026-10-05

- Q: Quy tắc "Missing" trên compliance detail? → A: *(Superseded by Update 2026-10-05 above)* Missing/Expired are whatever the existing sales-order alert evaluation stores in `compl_so_missing`.
- Q: Một dòng ứng với đối tượng nào? → A: Một dòng = (Master code, Code, Type, Product); ghi chú follow-up gắn theo khóa này.
- Directive: Viết mới hoặc copy chức năng cũ rồi chỉnh sửa; không sửa các hàm cũ vì đang chạy.
- Q: Cột nào phụ thuộc Sales order? → A: Bỏ Sales order, ETD, Invoice date, Customer code, Customer name; giữ các cột còn lại.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Refresh the missing-compliance detail snapshot (Priority: P1)

A Compliance Admin (or support engineer) calls the manual trigger `test-compliance-missing`. The system re-evaluates every open sales order exactly as the existing sales-order alert does (refreshing the existing missing-compliance store `compl_so_missing`), but sends no email and no in-app notification. It then replaces the content of the new `compl_missing_detail` store with the result, grouped so that each combination of Master code, Code, Type and Product appears once and no Sales order is kept.

**Why this priority**: The new screen has no data without this snapshot; everything else depends on it.

**Independent Test**: Call the trigger, then inspect `compl_missing_detail`: it has the same columns as `compl_so_missing` except the Sales order column, contains exactly one row per distinct (Master code, Code, Type, Product) present in `compl_so_missing` after the run, and no email or notification was sent.

**Acceptance Scenarios**:

1. **Given** open sales orders exist, **When** the trigger is called, **Then** `compl_so_missing` is refreshed by the same evaluation the existing sales-order alert uses, and no email or notification is sent.
2. **Given** `compl_so_missing` holds several rows sharing the same Master code, Code, Type and Product (from different sales orders), **When** the snapshot is saved, **Then** `compl_missing_detail` holds exactly one row for that combination and no Sales order value.
3. **Given** `compl_missing_detail` already holds rows from an earlier run, **When** the trigger runs again, **Then** the earlier rows are fully replaced by the new result (no stale rows survive).
4. **Given** the evaluation finds nothing missing, **When** the trigger runs, **Then** `compl_missing_detail` ends up empty and the call still succeeds.
5. **Given** the evaluation fails part-way (before the snapshot is replaced), **When** the error occurs, **Then** the previous content of `compl_missing_detail` is left unchanged and the call reports the failure; a failure during the replace step itself may leave it empty or partial until the next run.
6. **Given** the trigger is called, **When** it finishes, **Then** the existing alert endpoints (`test-alert`, `test-sales-order-alert`, `test-sales-order-alert-without-salesId`) and their behaviour are unchanged.

---

### User Story 2 - View the missing and expired compliance list (Priority: P1)

A compliance user opens the new "Compliance missing detail" screen (menu link `/compliance-missing`) and sees the list stored in `compl_missing_detail`, with Status "Missing" or "Expired", in the same interface as "Compliance missing open orders" (`/compliance-missing-open-orders`) but without the sales-order-derived columns.

**Why this priority**: This is what users actually use; it is the visible value of the feature.

**Independent Test**: After a trigger run, open the screen: it shows exactly the rows of `compl_missing_detail`, one per Master code / Code / Type / Product combination, with no Sales order, ETD, Invoice date, Customer code or Customer name column.

**Acceptance Scenarios**:

1. **Given** `compl_missing_detail` has rows, **When** the screen loads, **Then** every row is listed once, with no sales-order-derived column.
2. **Given** a stored row with an empty Code, **When** the screen loads, **Then** its Status is "Missing"; **Given** a stored row with a Code whose Valid to is earlier than today, **Then** its Status is "Expired" and its Days remaining is shown as "-n days left" (blank when Valid to is empty). Status and Days remaining are computed at read time, not trusted from the stored value.
3. **Given** the trigger has never run, **When** the screen loads, **Then** it shows an empty list with a clear "no data" state, not an error.
4. **Given** the screen is open, **When** the grid renders, **Then** it has the same layout, column chooser, paging and export controls as the open-orders screen, but without the sales-order-derived columns and without the Year/Week (ETD) filter.

---

### User Story 3 - Filter and search the list (Priority: P2)

The user narrows the list using the same filtering behaviour as the open-orders screen (for example by master, status, code), and clears filters to return to the full list.

**Why this priority**: The list can be long; filtering makes it actionable, but the screen is already useful unfiltered.

**Independent Test**: Apply a filter (e.g. Status = Expired) and confirm only matching rows remain; clear it and confirm the full list returns.

**Acceptance Scenarios**:

1. **Given** the list is displayed, **When** the user filters by Status "Expired", **Then** only Expired rows are shown.
2. **Given** a filter is applied, **When** the user clears it, **Then** the full list is shown again.

---

### User Story 4 - Record follow-up and export (Priority: P3)

As on the open-orders screen, the user can enter a follow-up date and note per row and export the list (including those two values) to Excel. The export has none of the sales-order-derived columns.

**Why this priority**: Supports the follow-up workflow; secondary to seeing the list.

**Independent Test**: Enter a follow-up date and note on a row, run the trigger again, reload and confirm they persist; then export and confirm the file has the same columns as the grid with those values and no sales-order-derived column.

**Acceptance Scenarios**:

1. **Given** a row, **When** the user enters a follow-up date and note, **Then** they are saved and shown after reload.
2. **Given** notes exist and the snapshot is refreshed again, **When** the same Master code / Code / Type / Product still appears, **Then** its follow-up date and note are still shown (notes are kept outside the snapshot, which is fully replaced on each run).
3. **Given** the list is displayed, **When** the user exports, **Then** the Excel file contains the same columns and rows as the grid, including follow-up date and note, and excludes the sales-order-derived columns.
4. **Given** the same follow-up note was entered on the open-orders screen for the same compliance item, **When** the user views this screen, **Then** the notes of the two screens are kept independent.

---

### Edge Cases

- Two runs of the trigger overlap, or the trigger runs while the existing sales-order alert is running: both refresh the shared `compl_so_missing` store; the outcome of the later one wins, and the screen must still see a complete (never partial) list.
- The trigger is called by a user without permission: the call is rejected and nothing changes.
- A stored row's Valid to equals today: not expired.
- A group's rows in `compl_so_missing` differ in non-key columns (for example name or valid dates): the first row of the group is kept, as the existing alert's grouping does.
- A user without permission to the screen: cannot see the menu entry or open the link.
- Existing bookmarks to the old `/compliance-missing` address now open this new screen; the open-orders screen is reachable only at `/compliance-missing-open-orders`.
- The same compliance item is listed here and on the open-orders screen: each screen is independent and neither affects the other's notes.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a new screen "Compliance missing detail" reachable through a menu entry whose link is `/compliance-missing`.
- **FR-002**: The screen MUST present the same interface as "Compliance missing open orders": same grid behaviour, column visibility control, paging and export action; the Year/Week (ETD) filter is not applicable and MUST NOT appear.
- **FR-003**: The screen MUST NOT display the sales-order-derived columns "Sales order", "ETD", "Invoice date", "Customer code" and "Customer name", in the grid, in filters, or in the export. All other columns of the open-orders screen (master, status, code, name, valid from/to, days remaining, responsible emails, type, product, description, follow-up date, note) are kept.
- **FR-004**: The screen MUST read its list only from the new store `compl_missing_detail`; it MUST NOT call the sales-order evaluation when the user opens or filters the screen.
- **FR-005**: System MUST provide a new manual trigger named `test-compliance-missing` (HTTP GET) that refreshes the snapshot.
- **FR-006**: The trigger MUST obtain its data by running the same sales-order evaluation as the existing alert's `BuildCurrentSalesOrderAlertComplianceListAsync` (refresh `compl_so_missing`, read it back, group by Master code, Code, Type, Product), implemented as a new copy so that the existing function is not modified (FR-015); it MUST NOT send any email or in-app notification.
- **FR-007**: After the evaluation, the trigger MUST replace the whole content of `compl_missing_detail` with the grouped result. The new store has the same columns as `compl_so_missing` except `SalesId`, and holds exactly one row per (Master code, Code, Type, Product).
- **FR-008**: The replacement is NOT wrapped in a transaction (decision 2026-10-05, so progress of the run can be watched in the working store `compl_so_missing`): the snapshot is deleted and rewritten in sequence. If the run fails after the delete and before the rewrite completes, `compl_missing_detail` may be empty or partial until the next successful run. A failure during the evaluation step (before the delete) leaves the previous snapshot untouched.
- **FR-009**: Users MUST be able to enter a follow-up date and a note per row; these MUST persist across snapshot refreshes and MUST be independent from those of the open-orders screen.
- **FR-010**: Users MUST be able to export the displayed list to Excel with the same columns as the grid (including follow-up date and note) and the same Expired-row highlighting as the open-orders export.
- **FR-011**: Access MUST be governed by its own screen permission (view, download, update), granted to the same roles that currently manage the open-orders screen; the trigger MUST be protected so only authorized users can run it.
- **FR-012**: The existing open-orders screen, the existing alert triggers and their data (`compl_so_missing` semantics, notes, jobs) MUST remain unchanged in behaviour; the open-orders screen is reachable at `/compliance-missing-open-orders`.
- **FR-013**: Status and Days remaining MUST be computed from the current date at read time from each row's Code and Valid to: empty Code = Missing; Code present and today later than Valid to = Expired; Days remaining blank when Valid to is empty, otherwise "-n days left" as on the open-orders screen. Rows that are neither Missing nor Expired by this rule are not listed.
- **FR-014**: Each row MUST be uniquely identified by the combination of Master code, Code, Type and Product; follow-up date/note MUST be attached to that combination.
- **FR-015**: The feature MUST be built as new, separate functionality (new or copied-then-adapted screen, logic, endpoints, data stores). Existing functions, screens, endpoints, jobs and tables used by "Compliance missing open orders" and the existing alerts are in production use and MUST NOT be modified; reuse is limited to calling them unchanged.

### Key Entities

- **Missing-compliance store (`compl_so_missing`, existing)**: Working store of the sales-order evaluation, one row per sales order and missing item. Rewritten by the trigger as an intermediate step; not read by the new screen.
- **Missing-compliance detail store (`compl_missing_detail`, new)**: The snapshot shown on the new screen. Same columns as `compl_so_missing` without Sales order; one row per (Master code, Code, Type, Product); fully replaced on each trigger run.
- **Follow-up note**: A follow-up date and free-text note attached to a row (keyed by Master code, Code, Type, Product), stored separately from the snapshot and from the open-orders notes.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: After a trigger run, 100% of the distinct (Master code, Code, Type, Product) combinations in `compl_so_missing` appear exactly once in `compl_missing_detail` and on the screen, and 0 sales-order values appear.
- **SC-002**: The screen shows its first page in under 5 seconds, because it reads only the stored snapshot.
- **SC-003**: A user familiar with the open-orders screen can use this screen without additional training (same controls and layout, differing only by the removed sales-order-derived columns and filter).
- **SC-004**: Exported files match the on-screen columns and rows in 100% of exports, with no sales-order-derived column.
- **SC-005**: Opening `/compliance-missing` always lands on this screen and `/compliance-missing-open-orders` always lands on the open-orders screen.
- **SC-006**: A trigger run sends 0 emails and 0 notifications, and leaves the existing alert endpoints' behaviour unchanged.
- **SC-007**: Follow-up notes entered before a trigger run are still shown after it for every combination that remains in the list.

## Assumptions

- The trigger is run manually (or later scheduled); automatic scheduling is out of scope for this spec.
- "Missing" and "Expired" follow the existing sales-order alert's rule (empty Code = Missing; today after Valid to = Expired), so the list reflects what open sales orders currently lack, with the sales order itself removed.
- The new screen shows the snapshot as of the last trigger run; it does not show data newer than that.
- The trigger endpoint belongs to the new feature (new service/endpoint, not a change to the existing notification controller's methods) and shares the existing `compl_so_missing` store as an intermediate working area; concurrent runs with the existing alert are an accepted risk noted in Edge Cases.
- The new screen gets its own menu entry and permission; role grants copy those of the open-orders screen. The existing menu code `compliance-missing` stays with the open-orders screen's permissions; the new screen uses a new code, and the `/compliance-missing` link is reassigned to it.
- Follow-up notes use a new store keyed by Master code, Code, Type and Product, independent of the open-orders notes.
