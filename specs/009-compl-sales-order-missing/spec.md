# Feature Specification: Sales Order Missing-Compliance Alert

**Feature Branch**: `009-compl-sales-order-missing`

**Created**: 2026-08-03

**Status**: Draft

**Input**: User description: "chức năng mới cho backend tên compl-sales-order-missing. Viết 1 chức năng gửi email giống [HttpGet("test-alert")] ở controller ComplNotificationController, controller đặt tên test-sales-order-alert, services đặt tên là SendSalesOrderAlertAsync, logic biến alertCompliances sẽ khác. Đầu tiên chạy [HttpPost("reference")] với reftype = 18 ở DynController, ta được danh sách SalesOrder, sau đó loop danh sách đó đến hết, lấy dữ liệu gửi vào ViewCompliancesController ở [HttpPost("get-all")] với referenceType = 11 và referenceValue = SalesOrder.Code, deliveryDate = SalesOrder.deliveryDate, cusCode = SalesOrder.custAccount, sẽ trả về dữ liệu, sau đó lọc lấy dữ liệu với Status = MISSING, insert dữ liệu vào bảng compl_so_missing với SalesId = SalesOrder.Code, các cột còn lại là dữ liệu từ [HttpPost("get-all")]. Trước khi insert dữ liệu vào bảng compl_so_missing thì chạy lệnh xóa dữ liệu với điều kiện SalesId = SalesOrder.Code. Khi loop xong dữ liệu, thì select toàn bộ dữ liệu bảng compl_so_missing trả về biến alertCompliances, rồi SendMailAndNotification"

**Update (2026-08-04)**: "cập nhật 009-compl-sales-order-missing. bỏ logic DeleteBySalesIdAsync, và chuyển thành delete toàn bộ dữ liệu compl_so_missing trước khi chạy" — remove the per-sales-order delete-before-insert step entirely; instead, delete all rows in the missing-compliance store once, before the evaluation loop begins.

**Update (2026-08-10)**: "cập nhật 009-compl-sales-order-missing email gồm các cột { SalesId: Sales order, MasterCode: Master code, MasterName: Master name, Status, Code, Name, ValidFrom: Valid from, ValidTo: Valid to, DaysRemaining: Days remaining, ResponsibleEmails: Responsible emails, Description, MappedRefTypeCode: Type, MappedInputValue: Product, MappedRefTypeName: Product name }, trong đó logic Status sẽ tính dựa vào cột Code, ValidTo. Nếu Code = '' thì là Missing, nếu Code tồn tại thì kiểm tra cột ValidTo, nếu today > ValidTo => Expired. Cột DaysRemaining sẽ tính nếu ValidTo = '' thì để trống, ngược lại là today - ValidTo, hiển thị text '-n days left', n là số ngày vừa tính" — finalize the exact set of columns shown in the consolidated alert (email and in-app notification), and specify that the Status and Days Remaining columns are recomputed at send time from each record's current Code and Valid To values (not simply copied from whatever was stored), so the alert always reflects each item's freshest status as of the moment the alert goes out.

**Update (2026-08-10, Excel attachment)**: "cập nhật 009-compl-sales-order-missing, thêm đính kèm file excel các cột, dữ liệu giống nội dung email vào khi gửi email. File tên compl-sales-order-missing-[yyyyMMddhhmmss]" — whenever the consolidated alert email is sent, attach an Excel file containing the same columns and the same data as the email body (the 14 columns and computed Status/Days remaining values from the prior update), named `compl-sales-order-missing-<yyyyMMddHHmmss>` using the timestamp the alert was generated.

**Update (2026-08-18, deduplicate and drop Sales order column)**: "cập nhật 009-compl-sales-order-missing. sau khi lưu dữ liệu vào bảng compl_so_missing, phần select data để gửi email thì distinct theo MasterCode, Code, MappedRefTypeCode, MappedInputValue, loại bỏ cột SalesId trên dữ liệu nội dung email và nội dung file đính kèm" — when reading back the missing-compliance records to build the alert, deduplicate them by the combination of Master code, Code, Type, and Product (previously the same combination could appear once per sales order that shared it), and remove the Sales order column entirely from both the email body and the Excel attachment. The `compl_so_missing` store itself and how it is populated per sales order are unchanged; only the read used to build the alert and the columns shown in the alert are affected.

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
4. **Given** the alert is being composed from the current set of missing-compliance records, **When** the alert content is generated, **Then** it presents, for every record, exactly these columns in this order: Master code, Master name, Status, Code, Name, Valid from, Valid to, Days remaining, Responsible emails, Description, Type, Product, Product name — the Sales order column is not shown.
5. **Given** a record in the current set has no Code recorded, **When** the alert content is generated, **Then** that record's Status column shows "Missing".
6. **Given** a record in the current set has a Code recorded and its Valid To date is earlier than the date the alert is generated, **When** the alert content is generated, **Then** that record's Status column shows "Expired".
7. **Given** a record in the current set has a Code recorded and either has no Valid To date or has a Valid To date that is not earlier than the date the alert is generated, **When** the alert content is generated, **Then** that record's Status column shows "Valid".
8. **Given** a record in the current set has no Valid To date, **When** the alert content is generated, **Then** that record's Days remaining column is left blank.
9. **Given** a record in the current set has a Valid To date that is 10 days after the date the alert is generated, **When** the alert content is generated, **Then** that record's Days remaining column reads "10 days left".
10. **Given** a record in the current set has a Valid To date that is 5 days before the date the alert is generated, **When** the alert content is generated, **Then** that record's Days remaining column reads "-5 days left".
11. **Given** the alert email is about to be sent, **When** it is sent, **Then** it includes exactly one Excel file attachment containing the same columns, in the same order, and the same row data (including the computed Status and Days remaining values) as the email body.
12. **Given** the alert email is generated at a specific moment in time, **When** the Excel attachment is named, **Then** its file name follows the pattern `compl-sales-order-missing-<yyyyMMddHHmmss>`, where the timestamp reflects the moment the alert was generated.
13. **Given** the missing-compliance store is empty after a refresh and no alert email is sent (Acceptance Scenario 2), **When** the notification step runs, **Then** no Excel attachment is produced either.
14. **Given** the missing-compliance store contains two or more records that share the same Master code, Code, Type, and Product but were captured against different sales orders, **When** the current set of records is read to build the alert, **Then** those records are collapsed into a single row in both the email body and the Excel attachment, so each distinct Master code/Code/Type/Product combination appears exactly once.

---

### Edge Cases

- What happens when the open sales order list contains the same sales order code more than once? Because the store is cleared once up front rather than per sales order code, each occurrence in the list is evaluated and inserted independently; if the same code appears more than once, its MISSING items from every occurrence accumulate in the store for that run rather than the later occurrence replacing the earlier one.
- What happens if the compliance lookup for one specific sales order fails or returns an error? Because the entire store was already cleared before evaluation began, that sales order simply has no missing-compliance records for this run (there is nothing left over to fall back to); it will be represented again only once its lookup succeeds in a later run. The system continues evaluating the remaining sales orders rather than aborting the whole run.
- What happens if a sales order in the open list is missing an expected field (e.g., no delivery date or customer account)? The system still runs the compliance lookup with whatever values are available, since the lookup already tolerates optional filters.
- What happens if the check is triggered again while a previous run is still in progress? Out of scope for this feature; concurrent runs are not guarded against.
- What happens when no sales orders currently have any MISSING compliance items, even though open sales orders exist? The store was already cleared at the start of the run, every sales order is still evaluated, and since none of them contributes any MISSING item, the store ends up empty and no alert is sent.
- What happens if a record's Valid To date is exactly the current date when the alert is generated? It is not earlier than the current date, so the record is treated as not yet expired (Status = "Valid", Days remaining = "0 days left").
- What happens if a record has a Code and a Valid To date that has already passed, given the store only holds records whose lookup reported MISSING (FR-005)? Its Status still displays as "Expired" rather than "Missing" for the alert, since FR-013 recomputes Status independently of the "MISSING" label the record was originally stored under — the two are different signals (why it was captured vs. its current state at send time).
- What happens if two alert runs are triggered within the same second? Their Excel attachments could share the same file name under the second-level timestamp pattern; this is treated as an acceptable, low-probability collision for a diagnostic/manual-trigger feature (see Assumptions) rather than a case this feature guards against.
- What happens if building the Excel attachment fails for some reason while the email and in-app notification would otherwise succeed? Out of scope for this feature to define custom recovery; the existing alert-sending error handling (FR-011's outer try/catch, per research.md R6) applies uniformly to the whole notification step, including attachment generation.
- What happens when multiple open sales orders share the same Master code, Code, Type, and Product and each was individually stored as MISSING (per FR-007)? Because the alert no longer shows the Sales order column, and the alert-building read now deduplicates by that four-column combination, these records collapse into one row instead of appearing once per sales order; the Sales order affiliation of each underlying stored record is not reflected in the alert (it remains visible only in the `compl_so_missing` store itself).
- What happens if two records sharing the same Master code, Code, Type, and Product combination somehow differ in another column (e.g. Description or Responsible emails) because of stale or inconsistent data? This is not expected to occur, since those four fields fully identify the same compliance master/reference-type mapping and the remaining columns are derived from that same master lookup; this feature does not define tie-breaking behavior for that case (see Assumptions).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a manually-triggerable entry point (mirroring the existing manual compliance-alert test trigger) that runs the full sales-order missing-compliance refresh-and-notify process on demand.
- **FR-002**: System MUST retrieve the current list of open sales orders from the existing open-sales-order reference data source, with at minimum each sales order's code, delivery date, and customer account.
- **FR-003**: System MUST evaluate every open sales order retrieved in FR-002, one at a time, until the entire list has been processed.
- **FR-004**: For each open sales order, System MUST look up its compliance status through the existing per-reference compliance lookup, keyed by that sales order's code, delivery date, and customer account.
- **FR-005**: From each sales order's compliance lookup result, System MUST identify only the entries whose status is MISSING.
- **FR-006**: Before evaluating any open sales order, System MUST delete every existing record in the missing-compliance store, so no entries from a previous run persist into the current one.
- **FR-007**: System MUST store each identified MISSING entry against its owning sales order's code, carrying over all other compliance detail fields returned by the lookup for that entry.
- **FR-008**: After every open sales order has been processed, System MUST read back the current set of missing-compliance records as the basis for the alert, deduplicated by the combination of Master code, Code, Type, and Product, so that each distinct combination contributes exactly one record to the alert regardless of how many sales orders in the store share it.
- **FR-009**: System MUST send exactly one consolidated alert (email plus in-app notification) summarizing the complete set of current missing-compliance records read in FR-008, using the same alert delivery mechanism (recipient resolution, formatting, notification persistence) as other existing compliance alerts.
- **FR-010**: System MUST NOT send an alert when the current set of missing-compliance records is empty (no open sales order that failed the lookup, or none reporting MISSING items, after processing).
- **FR-011**: A failure evaluating one open sales order's compliance lookup MUST NOT stop the system from evaluating the remaining open sales orders in the same run.
- **FR-012**: The alert generated in FR-009 MUST present, for every current missing-compliance record, exactly the following columns in this order: Master code, Master name, Status, Code, Name, Valid from, Valid to, Days remaining, Responsible emails, Description, Type, Product, Product name. The Sales order column MUST NOT be included.
- **FR-013**: System MUST compute each record's Status column at the moment the alert is generated (not reuse any previously stored status value), using that record's Code and Valid To values: "Missing" when Code is empty; "Expired" when Code is present and Valid To is earlier than the current date; "Valid" when Code is present and Valid To is either absent or not earlier than the current date.
- **FR-014**: System MUST compute each record's Days remaining column at the moment the alert is generated: left blank when Valid To is absent; otherwise shown as the number of days between the current date and Valid To, formatted as "N days left" where N is positive when Valid To is in the future (time remaining before expiry) and negative, shown with a leading minus sign (e.g. "-5 days left"), when Valid To has already passed (time since expiry).
- **FR-015**: Whenever the alert email is sent (FR-009), System MUST attach to that email an Excel file containing the same columns, in the same order, and the same computed values (including Status and Days remaining) as the email body (FR-012–FR-014).
- **FR-016**: The Excel attachment's file name MUST follow the pattern `compl-sales-order-missing-<yyyyMMddHHmmss>`, where the timestamp is the moment the alert was generated.
- **FR-017**: System MUST NOT produce an Excel attachment when no alert email is sent (FR-010).

### Key Entities

- **Open Sales Order**: A sales order currently in "open" status, sourced from existing reference data. Key attributes used by this feature: code, delivery date, customer account.
- **Missing Compliance Record**: One entry representing a compliance item found to be MISSING for a specific open sales order at the time of the last refresh. Key attributes: the owning sales order's code, plus the full compliance detail (compliance master identifiers/names, validity window, description, responsible/alert recipient groups, and related reference-type mapping) as returned by the per-reference compliance lookup. Every refresh clears the entire store before repopulating it, so the stored records always reflect only the current run's evaluation, never a mix of runs. The stored record still keeps the owning sales order's code (unchanged by this update); only the read used to build the alert deduplicates by Master code, Code, Type, and Product and omits the sales order code from what is shown.
- **Compliance Alert Notification**: The single consolidated email and in-app notification sent after a refresh, summarizing all current Missing Compliance Records read back deduplicated by Master code, Code, Type, and Product, consistent in shape and recipients with other existing compliance alerts in the system. Presents a fixed set of 13 columns per record (Master code, Master name, Status, Code, Name, Valid from, Valid to, Days remaining, Responsible emails, Description, Type, Product, Product name — no Sales order column), where Status and Days remaining are recalculated at generation time from each record's Code and Valid To rather than carried over unchanged from storage. When sent, it also carries one Excel file attachment mirroring the same columns and data, named `compl-sales-order-missing-<yyyyMMddHHmmss>` after the alert's generation timestamp.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Every open sales order returned at the start of a run is evaluated exactly once by the end of that run — 0 sales orders skipped, absent a lookup failure (see FR-011).
- **SC-002**: After a run completes, the missing-compliance store contains only records produced during that run — none carried over from any earlier run — and reflects exactly the compliance items actually missing for every successfully-evaluated sales order.
- **SC-003**: Responsible stakeholders receive exactly one alert per triggered run that has at least one current missing-compliance record — never zero when records exist, and never more than one.
- **SC-004**: An administrator or tester can trigger a full refresh-and-notify run on demand and observe the missing-compliance store fully refreshed without any manual follow-up step.
- **SC-005**: For every record shown in a sent alert, its Status and Days remaining values are consistent with that record's Code and Valid To values as of the moment the alert was generated — 0 records showing a stale or mismatched Status or Days remaining value.
- **SC-006**: Every alert email that is sent includes exactly one Excel attachment whose columns and data match the email body record-for-record, and whose file name follows the `compl-sales-order-missing-<yyyyMMddHHmmss>` pattern — 0 sent alerts missing the attachment or carrying mismatched data.
- **SC-007**: In every sent alert (email and Excel attachment), each distinct Master code/Code/Type/Product combination appears exactly once, and no Sales order column is present — 0 duplicate rows for the same combination and 0 occurrences of a Sales order column.

## Assumptions

- This feature reuses three existing capabilities as-is and does not change their behavior: the open-sales-order reference data lookup, the per-reference compliance lookup (the one that reports item status including MISSING), and the existing compliance alert delivery mechanism (email plus in-app notification, including recipient resolution).
- The manual trigger described in User Story 2, Acceptance Scenario 3 is a diagnostic/testing entry point only, mirroring the existing manual compliance-alert test trigger; scheduling or automating recurring runs is out of scope for this feature.
- The missing-compliance store is a single, durable table that is fully cleared once at the start of every run, before any sales order is evaluated, and then repopulated with that run's results; it holds only the latest run's results, not history across runs, and is never cleared or filtered on a per-sales-order-code basis.
- "Open" sales orders are determined entirely by the existing open-sales-order reference data source; this feature does not add its own open/closed logic.
- Recipients for the consolidated alert are resolved the same way as other existing compliance alerts (per-record responsible/alert groups), with no sales-order-specific recipient list.
- Because the store is cleared entirely before evaluation begins, no previously stored record can survive into a new run on its own; a sales order that is no longer open, or whose lookup fails during the run, simply has no records afterward unless it is itself evaluated and found to have MISSING items in that same run.
- "Valid" is the reasonable default Status label for a record whose Code is present and whose Valid To is either absent or not yet passed; the user's request only specified the "Missing" and "Expired" cases explicitly.
- Days remaining is expressed relative to the current date at the moment the alert is generated, not the date the record was originally stored — a positive count means the item is still within its valid window, a negative count (shown with a leading minus sign) means it has already expired.
- The Responsible emails column reflects the same recipient-group resolution the system already uses for other compliance alerts; this feature does not introduce a new way of deriving responsible emails.
- The Excel attachment's file name pattern (`compl-sales-order-missing-<yyyyMMddHHmmss>`) is understood to need a standard spreadsheet file extension (e.g. `.xlsx`) appended, since the user's requested pattern specifies only the base name and timestamp format.
- The Excel attachment is a new, always-produced summary of the whole run, distinct from any existing per-record file attachment behavior (e.g. attaching a record's own uploaded compliance document) elsewhere in the alert system; this feature does not change or gate that separate, existing behavior.
- Because the file name's timestamp has one-second resolution, two alert runs triggered within the same second could produce identically-named attachments; this is accepted as a low-probability edge case for a manually/diagnostically triggered feature rather than something requiring a uniqueness guarantee.
- Deduplicating by Master code, Code, Type, and Product is safe because those four fields together identify the same compliance master/reference-type mapping regardless of which sales order surfaced it; the remaining columns (Master name, Name, Valid from/to, Description, Responsible emails) are expected to be identical across records sharing that combination, so collapsing them loses no distinct information relevant to the alert.
- Dropping the Sales order column from the alert is scoped to what is displayed and read back for the email and Excel attachment; the `compl_so_missing` store continues to record and key on the owning sales order's code exactly as before (FR-006, FR-007), and no other feature or screen that reads that store directly is affected by this update.
