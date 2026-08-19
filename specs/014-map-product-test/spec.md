# Feature Specification: Map for Product Test — Complete Record Visibility

**Feature Branch**: `014-map-product-test`

**Created**: 2026-08-19

**Status**: Draft

**Input**: User description: "cập nhật chức năng có sẵn compl-management, kiểm tra popup MapDataDialog.jsx, tab Map for product test chỉ hiển thị MAS-01105, nhưng không hiển thị MAS-01104."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See every eligible compliance master in the list (Priority: P1)

A compliance officer opens the "Map SharePoint Files to Compliance" dialog and switches to the **Map for product test** tab to map an uploaded file to a product-level compliance master record. They search for or scroll to a specific compliance master code (e.g. `MAS-01104`) expecting it to be listed alongside other eligible codes (e.g. `MAS-01105`), so they can drag a file onto it.

**Why this priority**: If eligible records silently fail to appear, the officer cannot complete the mapping for that product, has no indication anything is wrong, and may assume the record doesn't need mapping — leading to missed compliance documentation.

**Independent Test**: Open the dialog, go to the "Map for product test" tab, and search for `MAS-01104`. It must appear in the results with the same reliability as `MAS-01105`, either immediately or after scrolling/searching, whenever it meets the tab's eligibility criteria.

**Acceptance Scenarios**:

1. **Given** the "Map for product test" tab is open with no search text, **When** the compliance officer scrolls through the full list (triggering pagination as needed), **Then** every compliance master record eligible for that tab appears exactly once, including `MAS-01104` if it is eligible.
2. **Given** the "Map for product test" tab is open, **When** the compliance officer searches by the code `MAS-01104`, **Then** the record is returned in the search results if it is eligible for the tab.
3. **Given** two compliance master records share the same eligibility criteria (e.g. `MAS-01104` and `MAS-01105`), **When** either is loaded via the same list or search, **Then** both are treated consistently — one is not shown while the other is hidden for reasons unrelated to their eligibility status.

---

### User Story 2 - Understand why a record is not mapped (Priority: P2)

When a compliance master record does **not** appear in the "Map for product test" tab because it genuinely does not meet the tab's eligibility rules (e.g. it is not "Missing" status or not a product-test type), the compliance officer can distinguish that from a system defect, so they don't waste time troubleshooting a non-issue.

**Why this priority**: Prevents repeated support requests when the absence of a record is correct system behavior rather than a bug.

**Independent Test**: For a record confirmed to be out of scope for this tab (already mapped, or not a product-test type), verify the record correctly appears in the "Map general" tab or an already-mapped state instead, and does not appear in "Map for product test".

**Acceptance Scenarios**:

1. **Given** a compliance master record is already mapped or is not a product-test type, **When** the compliance officer looks in "Map for product test", **Then** the record correctly does not appear there.

---

### Edge Cases

- What happens when a record exists beyond the first loaded page (list is paginated 25 at a time, sorted by code) — does scrolling to the bottom reliably load it, or does it get lost partway through pagination?
- What happens when a record's code differs from other similar codes only by the last digit (e.g. `MAS-01104` vs `MAS-01105`) — does the search/filter/sort logic treat them identically?
- What happens when the compliance officer searches for a code that is on a page not yet loaded — does the search re-query the full eligible set, or only filter what's already loaded client-side?
- What happens when two tabs ("Map general" and "Map for product test") are switched back and forth — does the record count and list stay accurate for each tab independently?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST list, in the "Map for product test" tab, every compliance master record that meets the tab's eligibility criteria (product-test/individual type, currently missing a mapped file), without silently omitting any eligible record.
- **FR-002**: System MUST return an eligible compliance master record in "Map for product test" search results when searched for by its exact code, name, or description, consistent with how other eligible records are returned.
- **FR-003**: System MUST apply pagination/infinite-scroll in the "Map for product test" tab such that continuing to scroll eventually surfaces all eligible records, with no eligible record permanently unreachable regardless of its code value or sort position.
- **FR-004**: System MUST NOT show a compliance master record in "Map for product test" once it is no longer eligible (e.g. already mapped, or not a product-test type), keeping the displayed count and list consistent with the tab's eligibility criteria.
- **FR-005**: System MUST apply identical eligibility and retrieval logic to every compliance master record in "Map for product test", so that two records with the same status and type (e.g. `MAS-01104` and `MAS-01105`) are always both shown or both hidden together.

### Key Entities

- **Compliance Master Record**: A compliance requirement definition (e.g. `MAS-01104`, `MAS-01105`) with a code, name, description, status (e.g. "Missing"), and type flag distinguishing "general" vs "product test" (individual) records. Used as the target for mapping an uploaded file.
- **SharePoint File**: An uploaded/discovered file available to be dragged onto a compliance master record to satisfy its missing mapping.
- **Mapping**: The association created between a SharePoint file and a compliance master record (with validity dates and, for product test, an item code reference).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of compliance master records that meet the "Map for product test" eligibility criteria are visible in the tab (via scroll and/or search), with zero eligible records missing.
- **SC-002**: A compliance officer searching for a specific eligible code (e.g. `MAS-01104`) finds it in under 5 seconds, on the first attempt, every time.
- **SC-003**: The "mapped / total" count shown in the tab always matches the number of records actually retrievable through scrolling and search, with no discrepancy.

## Assumptions

- The fix applies generally to any compliance master record meeting the "Map for product test" eligibility criteria (Status = "Missing", type = product-test/individual), not solely to `MAS-01104`; `MAS-01104` and `MAS-01105` serve as the concrete example/test case for verifying the fix.
- "Map general" tab behavior and eligibility rules are out of scope for this feature unless the same defect is found to affect it.
- No change to what qualifies a record as "eligible" for the tab is intended — the fix is about ensuring all eligible records are reliably retrievable and displayed, not about changing eligibility rules themselves.
