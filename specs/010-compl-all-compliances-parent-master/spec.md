
# Feature Specification: All-Compliances Parent Master Coverage

**Feature Branch**: `010-compl-all-compliances-parent-master`

**Created**: 2026-08-10

**Status**: Draft

**Input**: User description: "cập nhật chức năng có sẵn all-compliances. chỉnh lại stored procedures sp_load_compl_by_conditions, ở link E:\Working\Eutr\compliance-sys-api\src\ComplianceSys.Infrastructure\Sqls\Procedures\sp_load_compl_by_conditions.sql. Hiện tại store này trả về list danh sách gồm nhiều cột MasterId, MasterCode, MasterName.., giờ thêm cột ParentMaster sau MasterCode. Chỉnh lại logic -- STEP 20b từ dòng 983, logic trước là xóa, giờ không xóa chỉ cập nhật lại ParentMaster đúng với mã MasterCode của master cha, và cột Status cập nhật thành UseParent"

**Update (2026-08-10)**: "cập nhật 010-compl-all-compliances-parent-master, màn hình compliance-view-so?ref-type=11&codes=....... tab Compliances of sales order .... hiển thị thêm cột Parent master kế master code, và chỉnh lại logic cột Expiry warning theo cải thiện parentcode, hiện tại master con vẫn hiển thị missing, đúng logic phải hiển thị Use parent" — this update adds User Story 2 below: the backend data (User Story 1) is implemented, but the Sales Order Compliance tab UI does not yet surface it.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See compliance items that are covered by a parent master, instead of losing them (Priority: P1)

A Compliance Reviewer looks at the All Compliances results for a set of products/customers/etc. Today, when a child master's compliance requirement is already satisfied through its top-level parent master's own compliance, that child's rows are silently removed from the results. The reviewer wants those rows to remain visible — clearly marked as covered by the parent master — so nothing appears to be "missing" from the list unexpectedly and the reviewer can see exactly which parent master is providing the coverage.

**Why this priority**: This is the entire scope of the requested change. Without it, the feature delivers no value — it is not an incremental improvement to a larger flow, it is the flow.

**Independent Test**: Set up a compliance master hierarchy where a descendant master's compliance requirement for a given mapped input value is already covered by its top-level parent (root) master's own compliance requirement for that same value. Run the All Compliances lookup. Confirm the descendant's row is present in the results (not removed), its Parent Master field contains the parent (root) master's code, and its Status reads "UseParent" if — and only if — that row's own Status was "Missing"; if the row's own Status was already "Applied", confirm it stays "Applied".

**Acceptance Scenarios**:

1. **Given** a top-level parent master A has a matched compliance row for a mapped input value, and a descendant master B (a child or further-removed descendant of A in the hierarchy) has a **Missing** row for that same mapped input value, **When** the All Compliances results are generated, **Then** master B's row for that value is kept in the results with Status = "UseParent" and Parent Master = master A's code, and master A's own row is kept unchanged (its Status is not changed to "UseParent").
1b. **Given** the same setup as Scenario 1, but master B's row for that mapped input value is already **Applied** (it has its own matched compliance), **When** the All Compliances results are generated, **Then** master B's row is kept with Status still = "Applied" (NOT changed to "UseParent") and Parent Master = master A's code (still populated, so the coverage relationship remains visible even though the status itself doesn't change).
2. **Given** a master has no parent in the hierarchy (it is a root, or not part of any hierarchy at all), **When** the All Compliances results are generated, **Then** its Parent Master field is empty and its Status is whatever it was already determined to be (Applied or Missing), unaffected by this change.
3. **Given** a descendant master's row for a mapped input value has no corresponding parent-master row that actually resolves the requirement for that value (i.e., the parent has no matched compliance for that value), **When** the All Compliances results are generated, **Then** the descendant's row is kept with its original Status (not changed to "UseParent") and its Parent Master field remains empty.
4. **Given** two unrelated compliance master hierarchies each cover different descendant masters, **When** the All Compliances results are generated, **Then** each descendant row's Parent Master reflects only its own hierarchy's parent master, with no mixing between the two hierarchies.

---

### User Story 2 - See "Use parent" instead of "Missing" in the Sales Order Compliance tab (Priority: P1)

A Compliance Reviewer opens a sales order's compliance page (the screen reached with a sales-order reference, e.g. `compliance-view-so?ref-type=11&codes=...`) and looks at the "Compliances of Sales order ..." tab. Today, this tab's "Expiry warning" column shows "Missing" for a child master's row whenever that row has no expiry date of its own — even when User Story 1's backend change has already determined that child master is fully covered by its parent master's own compliance (Status = "UseParent"). The reviewer also has no way to see, on the row itself, which parent master is providing that coverage. The reviewer wants the grid to show "Use parent" instead of "Missing" for these covered rows, and to see the covering parent master's code next to the row's own Master code.

**Why this priority**: User Story 1's backend change already computes and returns this information, but delivers no visible value to the reviewer until the tab that reviewers actually use to check sales-order compliance displays it. Without this story, reviewers keep seeing "Missing" for rows that are, in fact, covered.

**Independent Test**: Open the Compliances of Sales order tab for a sales order whose product/customer/etc. maps to a compliance hierarchy where a child master is covered by its parent master. Confirm the row for the child master shows the parent master's code in a "Parent master" column (next to "Master code"), and its "Expiry warning" column reads "Use parent" rather than "Missing". Confirm a row that is genuinely uncovered still reads "Missing", and a row with its own valid compliance still shows its normal expiry state.

**Acceptance Scenarios**:

1. **Given** a row in the Compliances of Sales order tab whose backend Status is "UseParent", **When** the tab is displayed, **Then** the "Parent master" column (positioned immediately after "Master code") shows the covering parent master's code, and the "Expiry warning" column shows "Use parent" instead of "Missing".
2. **Given** a row whose backend Status is "MISSING" (no coverage from any parent), **When** the tab is displayed, **Then** the "Parent master" column is empty and the "Expiry warning" column continues to show "Missing" exactly as it does today.
3. **Given** a row whose backend Status is "APPLIED" and also carries a Parent master value (an Applied row that happens to sit under a covering parent, per User Story 1), **When** the tab is displayed, **Then** the "Parent master" column shows the parent's code, but the "Expiry warning" column shows the row's own expiry state exactly as it does today — Status = "APPLIED" never triggers "Use parent" text.
4. **Given** a row that is both marked "Already have new version" (its own master data has been superseded) and Status = "UseParent", **When** the tab is displayed, **Then** the "Expiry warning" column shows "Already have new version" (this pre-existing rule keeps priority, since it reflects the row's own master record being superseded — an independent concern from parent coverage) — but the "Parent master" column still shows the covering parent's code.

---

### Edge Cases

- What happens when a descendant is several levels removed from its top-level parent (grandparent, great-grandparent, etc.)? The Parent Master shown is the top-level parent (root) master of that hierarchy, not an intermediate ancestor.
- What happens when the same descendant master would be covered for one mapped input value but not another (e.g., covered for "Country = X" but not for "Country = Y")? Coverage and Parent Master are evaluated per row/mapped-input-value — only the rows that are actually covered for that specific value get a Parent Master; the Status change additionally only applies to those covered rows whose own Status is "Missing".
- What happens to the parent (root) master's own row when it is the one providing coverage? It is always kept with its original Status; a row is never marked as covering itself.
- What happens to a covered row whose own Status is already "Applied"? Its Status is left unchanged (never becomes "UseParent") — only its Parent Master field is populated, so the reviewer can still see it sits under a covering parent even though it didn't need the parent's coverage to be satisfied.
- What happens to rows that were already going to be removed for reasons unrelated to hierarchy coverage? Unaffected — this change only alters the hierarchy-coverage removal step; every other rule that produces the All Compliances results stays the same.
- (US2) What happens in the Compliances of Sales order tab when a row's Parent master is populated but its Status is "APPLIED", not "UseParent"? The Expiry warning column is unaffected — it only changes to "Use parent" for rows whose Status is "UseParent"; an Applied row's own expiry state (or lack of one) still governs its Expiry warning text.
- (US2) What happens to other tabs/screens in `compliance-view-so`, or to other consumers of the same All Compliances data (e.g. the missing-compliance drawer, which filters on Status = "MISSING")? Unaffected — those consumers already ignore "UseParent" rows the same way they ignore "Applied" rows today; this update only changes the Compliances of Sales order tab's own column set and Expiry warning rendering.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The All Compliances results MUST include a Parent Master field, positioned immediately after the Master Code field, on every returned row.
- **FR-002**: The Parent Master field MUST be empty for any row that is not covered by a parent master's compliance under FR-004.
- **FR-003**: When a descendant master's row for a given mapped input value is already covered by its top-level parent (root) master's own matched compliance row for that same value, the system MUST keep that descendant's row in the results rather than removing it, as it does today.
- **FR-004**: For each row kept under FR-003, the system MUST set its Parent Master field to the code of the covering top-level parent (root) master, regardless of that row's own Status.
- **FR-004a**: Of the rows covered under FR-003, the system MUST change Status to "UseParent" only for those whose Status was "Missing" at the time of coverage. A covered row whose Status was already "Applied" MUST keep Status = "Applied" (Parent Master is still populated per FR-004, but the Status itself is left unchanged).
- **FR-005**: The rule used to decide which rows are covered (same mapped input value, descendant relationship within the hierarchy, parent row has an actual matched compliance) MUST remain exactly the rule used today to decide removal — only the outcome changes, from "remove the row" to "keep the row and mark it".
- **FR-006**: A row belonging to the parent (root) master that is itself providing the coverage MUST NOT have its own Status changed to "UseParent".
- **FR-007**: All other fields already present in the All Compliances results, and all rows not affected by FR-003, MUST retain the same values and behavior they have today.
- **FR-008** *(US2)*: The Compliances of Sales order tab MUST display a "Parent master" column, positioned immediately after the "Master code" column, showing the Parent Master value already returned by the All Compliances results for that row (empty when the row has none).
- **FR-009** *(US2)*: In the Compliances of Sales order tab, the Expiry warning column MUST show "Use parent" for any row whose Status is "UseParent", instead of the "Missing" text that rule would otherwise produce.
- **FR-010** *(US2)*: In the Compliances of Sales order tab, for any row whose Status is not "UseParent" (e.g. "MISSING", "APPLIED"), the Expiry warning column MUST keep computing and displaying its value exactly as it does today — unaffected by this change.
- **FR-011** *(US2)*: For a row that is already flagged as superseded by a newer version of its own master data, the Expiry warning column MUST keep showing that superseded indicator instead of "Use parent" — this pre-existing rule takes precedence — while the Parent master column still shows the covering parent's code if the row also has one.

### Key Entities

- **Compliance Master**: A compliance requirement definition (identified by its code) that products, customers, or other conditions can be matched against; may participate in a parent/child hierarchy with other Compliance Masters.
- **Compliance Master Hierarchy**: The parent/child structure between Compliance Masters; a master with no parent is the top of its hierarchy (its own coverage-providing parent).
- **All Compliances Result Row**: One entry in the All Compliances results, representing a specific master and compliance requirement matched against a mapped input value; now additionally carries a Parent Master reference and can carry the status "UseParent" in addition to the existing statuses.
- **Compliances of Sales Order Tab** *(US2)*: The grid within the sales order compliance screen that lists All Compliances Result Rows scoped to a given sales order; now additionally shows each row's Parent Master and reflects "UseParent" rows as "Use parent" in its Expiry warning column.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Reviewers can see every compliance requirement that applies to a hierarchy in the All Compliances results — including ones already covered by a parent master — without needing to separately inspect the hierarchy configuration to know it exists.
- **SC-002**: For 100% of rows covered by a parent master, the covering parent master's code is visible directly on that same row.
- **SC-003**: Rows that used to disappear because of parent-master coverage no longer disappear — the total row count for a given input either stays the same or increases compared to today, and never decreases, after this change.
- **SC-004**: For every row not affected by parent-master coverage, its values are identical before and after this change (verified by comparing results for the same input before and after).
- **SC-005** *(US2)*: Reviewers looking at the Compliances of Sales order tab can identify, for every row, whether it is covered by a parent master and which one, without leaving the tab or consulting the hierarchy configuration separately.
- **SC-006** *(US2)*: 100% of rows shown in the Compliances of Sales order tab whose Status is "UseParent" display "Use parent" in the Expiry warning column, where previously 100% of them displayed "Missing".

## Assumptions

- "Parent master" refers to the top-level ancestor (root) master in the compliance master hierarchy that actually supplies the matched compliance used to determine coverage — not necessarily the immediate one level up when a hierarchy has more than two levels. This matches how "parent" is already used in the current coverage-removal logic being modified.
- No new coverage rule is introduced: a row only gets a Parent Master / potential "UseParent" status when it would previously have been removed by the existing hierarchy-coverage rule. Within that set, only rows whose own Status was "Missing" actually change Status to "UseParent" — a covered row already "Applied" keeps its own Status, since it already has independent proof of compliance and doesn't need to fall back on the parent's.
- The row ordering already used for the All Compliances results is not required to change as part of this update.
- *(US2)* Other downstream consumers of the All Compliances results (e.g. screens/filters that only ever check for "MISSING" or "APPLIED") are unaffected and out of scope — they already treat any other Status value, including "UseParent", the same way they already treat "APPLIED": simply not matching their "MISSING" filter. Only the Compliances of Sales order tab's own column set and Expiry warning rendering are in scope for this update.
- *(US2)* When a row is both superseded by a newer version of its own master data and Status = "UseParent", the existing "superseded" indicator in the Expiry warning column takes precedence over "Use parent" — chosen because it reflects an independent, more specific fact about the row's own master record, and changing that precedence was not requested.
- *(US2)* "Parent master" is a plain code value shown next to "Master code" with no additional interaction (e.g. no drill-through/navigation to the parent's own row) — no such interaction was requested.
