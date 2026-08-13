# Feature Specification: EUTR Synchronize Data (Sales Order Template Sync)

**Feature Branch**: `011-eutr-synchronize-data`

**Created**: 2026-08-11

**Status**: Draft

**Input**: User description: "chức năng mới eutr-synchronize-data, viết chức năng EutrSynchronizeDataController tham khảo ComplNotificationController. trong đó có mở cỗng [HttpGet("test-so-template-sync")]. sẽ gọi service lấy toàn bộ dữ liệu từ API DynController> [HttpPost("reference")] với type = 19 sau đó insert vào bảng eutr_purchase_attachments. với SalesId = InterCompanyOriginalSalesId, PurchId = RSVNRefPurchId, TemplateCode = RSVNEutrTemplate, trước khi add, kiểm tra SalesId đã tồn tại trong bảng eutr_purchase_attachments chưa, nếu đã tồn tại thì bỏ qua, không add."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Populate purchase attachment records from the ERP's Sales Order Template data (Priority: P1)

A Data Administrator needs the compliance system's Sales Order ↔ Purchase Order ↔ Template mapping records to reflect what is recorded in the company's ERP system. Today, this mapping (used elsewhere to show which template applies to a sales order) has to be created by hand. The administrator wants to trigger a synchronization action that pulls the full set of Sales Order Template records from the ERP reference data and creates the corresponding local mapping records automatically, without creating duplicate entries for sales orders that already have a mapping.

**Why this priority**: This is the entire scope of the requested change — a one-shot data sync action. Without it, the feature delivers no value.

**Independent Test**: Trigger the synchronization action against an ERP reference dataset that contains a mix of sales orders with no existing local mapping and sales orders that already have one. Confirm that after the run, every previously-unmapped sales order now has exactly one mapping record with the correct Purchase Order and Template values, and that sales orders which already had a mapping are left unchanged (no new or duplicate record created for them).

**Acceptance Scenarios**:

1. **Given** the ERP reference data contains a Sales Order Template record for a sales order that has no existing mapping record, **When** the synchronization action runs, **Then** a new mapping record is created with Sales Order ID, Purchase Order ID, and Template Code taken from that reference record.
2. **Given** the ERP reference data contains a Sales Order Template record for a sales order that already has a mapping record, **When** the synchronization action runs, **Then** no new record is created and the existing mapping record is left unchanged.
3. **Given** the ERP reference data spans more records than fit in a single page/batch of the underlying reference lookup, **When** the synchronization action runs, **Then** every record across all pages is evaluated (not just the first page).
4. **Given** the synchronization action has already been run once with no changes to the ERP reference data since, **When** it is run again, **Then** no additional mapping records are created (the second run is a no-op).

---

### Edge Cases

- What happens when the ERP reference data contains multiple records for the same sales order (e.g., two different purchase orders under the same sales order) within a single run? Only the first one encountered is added; subsequent records for that same sales order are treated as already existing and skipped, since the "already exists" check runs against the same table being written to.
- What happens when a reference record is missing a sales order ID, purchase order ID, or template code? That record is skipped — it cannot form a valid mapping record.
- What happens when the ERP reference data is empty? The synchronization completes successfully having added zero records.
- What happens when the ERP source is temporarily unavailable or returns an error mid-run? The run stops and reports failure; records already added before the failure remain (no automatic rollback), and a subsequent run can be attempted, skipping the sales orders already synced.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a manually triggerable synchronization action that retrieves the full set of Sales Order Template reference records from the ERP reference data source (reference type: Sales Order Templates), across all pages of that source.
- **FR-002**: For each retrieved reference record, system MUST derive a candidate mapping record's Sales Order ID, Purchase Order ID, and Template Code from that record's Sales Order, Purchase Order, and Template values respectively.
- **FR-003**: Before creating a mapping record, system MUST check whether a mapping record already exists for that Sales Order ID.
- **FR-004**: System MUST skip creating a mapping record (no insert, no update) whenever a mapping record already exists for that Sales Order ID.
- **FR-005**: System MUST create a new mapping record only when no mapping record currently exists for that Sales Order ID.
- **FR-006**: System MUST skip any retrieved reference record that is missing a Sales Order ID, Purchase Order ID, or Template Code, without creating a mapping record for it.
- **FR-007**: System MUST report the outcome of a synchronization run (at minimum: success/failure, and counts of records added vs. skipped) back to the caller who triggered it.
- **FR-008**: System MUST restrict the synchronization action to authenticated/authorized callers, consistent with other administrative actions in the system.

### Key Entities

- **Sales Order Template Reference (ERP source data)**: A record from the ERP reference data representing a link between a sales order, a purchase order, and a compliance template. Key attributes: Sales Order ID, Purchase Order ID, Template Code.
- **Purchase Attachment Mapping (local record)**: The local record that associates a Sales Order ID with a Purchase Order ID and a Template Code, used elsewhere in the system to determine which compliance template applies to a sales order. Uniqueness is keyed on Sales Order ID for the purposes of this synchronization (one mapping record is created per distinct new Sales Order ID per run).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: After a synchronization run, every sales order present in the ERP reference data that had no prior mapping record now has exactly one mapping record with the correct Purchase Order and Template values.
- **SC-002**: Running the synchronization twice in succession with unchanged ERP reference data produces zero additional mapping records on the second run (fully idempotent, no duplicates ever created).
- **SC-003**: A synchronization run evaluates 100% of the ERP reference records available at run time, regardless of how many pages/batches the underlying source data spans.
- **SC-004**: A Data Administrator can determine, from the synchronization action's response alone (without inspecting logs or the database), whether the run succeeded and how many records were added versus skipped.

## Assumptions

- This synchronization is a manually-triggered, test-oriented action (reflected by the endpoint's "test" naming) rather than a scheduled/automatic background job; adding scheduling is out of scope for this feature.
- The synchronization is one-directional: from the ERP reference data into the local mapping table. It does not update, delete, or reconcile local mapping records that no longer match the ERP source.
- "Already exists" is evaluated strictly by Sales Order ID — if a mapping record already exists for a Sales Order ID with a different Purchase Order or Template than the current ERP source data, it is left as-is (no update), matching the explicit "skip if exists" instruction.
- The ERP reference data source used for reference type 19 already returns the Sales Order ID, Purchase Order ID, and Template Code fields needed; no changes to that source are required by this feature.
- Errors from the ERP reference data source during a run are surfaced as a failed run rather than being silently swallowed, since the administrator needs to know whether the full dataset was processed.
