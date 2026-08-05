# Feature Specification: Sales Order Missing-Compliance Alert

**Feature Branch**: `009-compl-sales-order-missing`

**Created**: 2026-08-03

**Status**: Draft

**Input**: User description: "chức năng mới cho backend tên compl-sales-order-missing. Viết 1 chức năng gửi email giống [HttpGet("test-alert")] ở controller ComplNotificationController, controller đặt tên test-sales-order-alert, services đặt tên là SendSalesOrderAlertAsync, logic biến alertCompliances sẽ khác. Đầu tiên chạy [HttpPost("reference")] với reftype = 18 ở DynController, ta được danh sách SalesOrder, sau đó loop danh sách đó đến hết, lấy dữ liệu gửi vào ViewCompliancesController ở [HttpPost("get-all")] với referenceType = 11 và referenceValue = SalesOrder.Code, deliveryDate = SalesOrder.deliveryDate, cusCode = SalesOrder.custAccount, sẽ trả về dữ liệu, sau đó lọc lấy dữ liệu với Status = MISSING, insert dữ liệu vào bảng compl_so_missing với SalesId = SalesOrder.Code, các cột còn lại là dữ liệu từ [HttpPost("get-all")]. Trước khi insert dữ liệu vào bảng compl_so_missing thì chạy lệnh xóa dữ liệu với điều kiện SalesId = SalesOrder.Code. Khi loop xong dữ liệu, thì select toàn bộ dữ liệu bảng compl_so_missing trả về biến alertCompliances, rồi SendMailAndNotification"

**Update (2026-08-04)**: "cập nhật 009-compl-sales-order-missing. bỏ logic DeleteBySalesIdAsync, và chuyển thành delete toàn bộ dữ liệu compl_so_missing trước khi chạy" — remove the per-sales-order delete-before-insert step entirely; instead, delete all rows in the missing-compliance store once, before the evaluation loop begins.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Refresh the missing-compliance snapshot for every open sales order (Priority: P1)

A Compliance Admin (or a support engineer testing the alert pipeline) triggers a check that first clears the entire missing-compliance store, then walks every currently open sales order, re-evaluates its compliance status, and repopulates the store with exactly the compliance items still missing for each sales order evaluated in that run.

**Why this priority**: This is the data foundation the alert depends on. Without an accurate, current snapshot of what is missing per sales order, no meaningful alert can be sent — this must exist and be correct before notification is worth building.

**Independent Test**: Can be fully tested by triggering the check and then inspecting the missing-compliance store: the store contains no records left over from before the run started, every currently open sales order has been evaluated, and for each one the stored missing items match exactly what its compliance lookup reported as MISSING during this run (no sales order skipped).

**Acceptance Scenarios**:

1. **Given** a set of open sales orders exists, **When** the check is triggered, **Then** the system first deletes every existing record in the missing-compliance store, then retrieves the full list of open sales orders and evaluates every one of them before finishing.
2. **Given** an open sales order currently has one or more compliance items with status MISSING, **When** that sales order is evaluated, **Then** those MISSING items (and only those) are stored against that sales order's code in the missing-compliance store.
3. **Given** an open sales order previously had missing items recorded from an earlier run, **When** the current run's initial clear step runs and it is then re-evaluated and found fully compliant (no items with status MISSING), **Then** none of its old missing-compliance records survive the clear step and no new ones are added for it.
4. **Given** an open sales order previously had missing items recorded, **When** the current run's initial clear step removes all prior records and it is then re-evaluated and still has some (possibly different) items missing, **Then** only the current set of MISSING items is stored for that sales order — no rows from the previous run remain.
5. **Given** the list of open sales orders is empty, **When** the check is triggered, **Then** the system still deletes every existing record in the missing-compliance store, no sales order is evaluated, and the store ends up empty.

---

### User Story 2 - Notify responsible stakeholders after the snapshot is refreshed (Priority: P2)

After the missing-compliance snapshot has been refreshed for all open sales orders, the system sends a single consolidated alert (email plus in-app notification) summarizing every sales order that currently has missing compliance items, so responsible stakeholders know what needs attention.

**Why this priority**: Notification is the payoff of the check — it depends on User Story 1 having produced an accurate snapshot, but is a distinct, separately verifiable step (the alert content and delivery can be checked against the stored snapshot independently of how that snapshot was produced).

**Independent Test**: Can be fully tested by ensuring the missing-compliance store already contains known records, triggering (or resuming) the notification step, and confirming exactly one alert is sent whose content matches every current record in the store.

**Acceptance Scenarios**:

1. **Given** the missing-compliance store contains one or more records after a refresh, **When** the notification step runs, **Then** exactly one alert (email plus in-app notification) is sent that lists every current record, addressed to the same responsible/alert recipients used by other compliance alerts in the system.
2. **Given** the missing-compliance store is empty after a refresh (no sales order currently has missing items), **When** the notification step runs, **Then** no alert is sent.
3. **Given** a manual/test trigger for this feature (mirroring the existing manual compliance-alert test trigger), **When** an administrator or tester invokes it, **Then** the full refresh-then-notify process described in User Story 1 and this story runs end-to-end on demand.

---

### Edge Cases

- What happens when the open sales order list contains the same sales order code more than once? Because the store is cleared once up front rather than per sales order code, each occurrence in the list is evaluated and inserted independently; if the same code appears more than once, its MISSING items from every occurrence accumulate in the store for that run rather than the later occurrence replacing the earlier one.
- What happens if the compliance lookup for one specific sales order fails or returns an error? Because the entire store was already cleared before evaluation began, that sales order simply has no missing-compliance records for this run (there is nothing left over to fall back to); it will be represented again only once its lookup succeeds in a later run. The system continues evaluating the remaining sales orders rather than aborting the whole run.
- What happens if a sales order in the open list is missing an expected field (e.g., no delivery date or customer account)? The system still runs the compliance lookup with whatever values are available, since the lookup already tolerates optional filters.
- What happens if the check is triggered again while a previous run is still in progress? Out of scope for this feature; concurrent runs are not guarded against.
- What happens when no sales orders currently have any MISSING compliance items, even though open sales orders exist? The store was already cleared at the start of the run, every sales order is still evaluated, and since none of them contributes any MISSING item, the store ends up empty and no alert is sent.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a manually-triggerable entry point (mirroring the existing manual compliance-alert test trigger) that runs the full sales-order missing-compliance refresh-and-notify process on demand.
- **FR-002**: System MUST retrieve the current list of open sales orders from the existing open-sales-order reference data source, with at minimum each sales order's code, delivery date, and customer account.
- **FR-003**: System MUST evaluate every open sales order retrieved in FR-002, one at a time, until the entire list has been processed.
- **FR-004**: For each open sales order, System MUST look up its compliance status through the existing per-reference compliance lookup, keyed by that sales order's code, delivery date, and customer account.
- **FR-005**: From each sales order's compliance lookup result, System MUST identify only the entries whose status is MISSING.
- **FR-006**: Before evaluating any open sales order, System MUST delete every existing record in the missing-compliance store, so no entries from a previous run persist into the current one.
- **FR-007**: System MUST store each identified MISSING entry against its owning sales order's code, carrying over all other compliance detail fields returned by the lookup for that entry.
- **FR-008**: After every open sales order has been processed, System MUST read back the complete, current set of missing-compliance records as the basis for the alert.
- **FR-009**: System MUST send exactly one consolidated alert (email plus in-app notification) summarizing the complete set of current missing-compliance records read in FR-008, using the same alert delivery mechanism (recipient resolution, formatting, notification persistence) as other existing compliance alerts.
- **FR-010**: System MUST NOT send an alert when the current set of missing-compliance records is empty (no open sales order that failed the lookup, or none reporting MISSING items, after processing).
- **FR-011**: A failure evaluating one open sales order's compliance lookup MUST NOT stop the system from evaluating the remaining open sales orders in the same run.

### Key Entities

- **Open Sales Order**: A sales order currently in "open" status, sourced from existing reference data. Key attributes used by this feature: code, delivery date, customer account.
- **Missing Compliance Record**: One entry representing a compliance item found to be MISSING for a specific open sales order at the time of the last refresh. Key attributes: the owning sales order's code, plus the full compliance detail (compliance master identifiers/names, validity window, description, responsible/alert recipient groups, and related reference-type mapping) as returned by the per-reference compliance lookup. Every refresh clears the entire store before repopulating it, so the stored records always reflect only the current run's evaluation, never a mix of runs.
- **Compliance Alert Notification**: The single consolidated email and in-app notification sent after a refresh, summarizing all current Missing Compliance Records, consistent in shape and recipients with other existing compliance alerts in the system.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Every open sales order returned at the start of a run is evaluated exactly once by the end of that run — 0 sales orders skipped, absent a lookup failure (see FR-011).
- **SC-002**: After a run completes, the missing-compliance store contains only records produced during that run — none carried over from any earlier run — and reflects exactly the compliance items actually missing for every successfully-evaluated sales order.
- **SC-003**: Responsible stakeholders receive exactly one alert per triggered run that has at least one current missing-compliance record — never zero when records exist, and never more than one.
- **SC-004**: An administrator or tester can trigger a full refresh-and-notify run on demand and observe the missing-compliance store fully refreshed without any manual follow-up step.

## Assumptions

- This feature reuses three existing capabilities as-is and does not change their behavior: the open-sales-order reference data lookup, the per-reference compliance lookup (the one that reports item status including MISSING), and the existing compliance alert delivery mechanism (email plus in-app notification, including recipient resolution).
- The manual trigger described in User Story 2, Acceptance Scenario 3 is a diagnostic/testing entry point only, mirroring the existing manual compliance-alert test trigger; scheduling or automating recurring runs is out of scope for this feature.
- The missing-compliance store is a single, durable table that is fully cleared once at the start of every run, before any sales order is evaluated, and then repopulated with that run's results; it holds only the latest run's results, not history across runs, and is never cleared or filtered on a per-sales-order-code basis.
- "Open" sales orders are determined entirely by the existing open-sales-order reference data source; this feature does not add its own open/closed logic.
- Recipients for the consolidated alert are resolved the same way as other existing compliance alerts (per-record responsible/alert groups), with no sales-order-specific recipient list.
- Because the store is cleared entirely before evaluation begins, no previously stored record can survive into a new run on its own; a sales order that is no longer open, or whose lookup fails during the run, simply has no records afterward unless it is itself evaluated and found to have MISSING items in that same run.
