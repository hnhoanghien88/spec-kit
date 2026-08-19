# Feature Specification: Compliance Synchronize Data (Sales Line + Variant Attributes)

**Feature Branch**: `013-compl-synchronize-data`

**Created**: 2026-08-19

**Status**: Draft

**Input**: User description: "chức năng mới compl-synchronize-data, giống EutrSynchronizeDataController, trong đó viết 1 controller test-compl-synchronize-data. chức năng gọi hết dữ liệu từ API [HttpGet(\"sales-line\")] (t1), sau đó loop lưu vào bảng compl_sync_sales_line mới tạo trong đó cột ProductCode = ItemId (t1), Salesid, SalesStatus, riêng Product name, description, type, range thì lấy dữ liệu ở API [HttpPost(\"reference\")] t2 với type = 6 theo điều kiện ProductCode(t2) = ItemId(t1), ConfigId(t2) = ConfigId(t1). Sau khi chạy xong, thì loop compl_sync_sales_line lấy Group ra 2 cột ProductCode, ConfigId, rồi kết nối API [HttpGet(\"product-variant-attributes\")] theo lọc Product, Config, rồi lưu dữ liệu API vào bảng mới tạo compl_sync_variant_attributes"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Populate Sales Line + Product master data from the ERP (Priority: P1)

A Data Administrator needs the compliance system to hold a local copy of the ERP's Sales Line records, each enriched with its Product's name, description, type, and range, so downstream compliance processes can work from local data instead of querying the ERP directly for this information every time. Today no such local copy exists. The administrator wants to trigger a synchronization action that pulls the full set of Sales Line records from the ERP, and for each one, looks up and attaches the matching Product's descriptive fields from the ERP's Product reference data.

**Why this priority**: This is the foundational data set the rest of the feature builds on — without it, there is no Sales Line data to derive the Product/Config combinations needed by User Story 2, and no synchronized Sales Line data exists at all.

**Independent Test**: Trigger the synchronization action against an ERP Sales Line dataset that includes records whose Item ID + Config ID have a matching Product reference record, and records that do not. Confirm that after the run, the local Sales Line store contains one record per retrieved Sales Line, with Product Code, Sales ID, and Sales Status copied from the source, and Name, Description, Type, and Range populated from the matching Product reference record where one exists (left blank where none exists).

**Acceptance Scenarios**:

1. **Given** the ERP Sales Line data spans more records than fit in a single page/batch of the underlying source, **When** the synchronization action runs, **Then** every Sales Line record across all pages is retrieved and evaluated before the run finishes.
2. **Given** a retrieved Sales Line record, **When** it is saved locally, **Then** the local record's Product Code, Sales ID, and Sales Status are set from that Sales Line record's Item ID, Sales ID, and Sales Status respectively.
3. **Given** a retrieved Sales Line record's Item ID and Config ID match a Product reference record's Product Code and Config ID (from the ERP's Product reference data, filtered to Product/Variant reference data), **When** the local Sales Line record is saved, **Then** its Name, Description, Type, and Range are populated from that matching Product reference record.
4. **Given** a retrieved Sales Line record's Item ID and Config ID have no matching Product reference record, **When** the local Sales Line record is saved, **Then** it is still saved, with Name, Description, Type, and Range left blank.
5. **Given** a retrieved Sales Line record is missing an Item ID or a Sales ID, **When** the synchronization action runs, **Then** that record is skipped — no local record is created for it.
6. **Given** the ERP Sales Line data is empty, **When** the synchronization action runs, **Then** this phase completes successfully having added zero records, and the second phase (User Story 2) proceeds with no Product/Config combinations to process.

---

### User Story 2 - Derive distinct Product/Config combinations and populate Variant Attribute data (Priority: P2)

Once the Sales Line data (User Story 1) has been synchronized, a Data Administrator needs the ERP's variant-level attribute details (the attributes specific to each Product + Config combination) captured locally as well, without looking them up once per Sales Line record — since many Sales Line records can share the same Product + Config combination. The administrator wants the same triggered run to continue automatically into a second phase: group the just-synchronized Sales Line data down to its distinct Product + Config combinations, and for each one, pull that combination's Variant Attribute data from the ERP and store it locally.

**Why this priority**: This phase depends entirely on User Story 1's output (there is nothing to group until Sales Line data exists), so it is the second, dependent slice of value — richer product-variant data available locally, built on top of the foundational sync.

**Independent Test**: With the local Sales Line store already populated (via User Story 1, or seeded directly with a mix of records that share the same Product + Config combination and records with distinct combinations), run this phase and confirm the local Variant Attribute store ends up with data for exactly one Variant Attribute lookup per distinct Product + Config combination present in the Sales Line store — never once per individual Sales Line record.

**Acceptance Scenarios**:

1. **Given** the local Sales Line store (from User Story 1's completed run) contains multiple records sharing the same Product Code + Config ID, **When** this phase runs, **Then** exactly one Variant Attribute lookup is performed for that Product + Config combination, not one per Sales Line record.
2. **Given** the local Sales Line store contains several distinct Product Code + Config ID combinations, **When** this phase runs, **Then** every distinct combination is looked up exactly once, filtered to that exact Product and Config.
3. **Given** a Variant Attribute lookup for a Product + Config combination returns data, **When** this phase runs, **Then** that data is saved to the local Variant Attribute store, associated with that Product Code and Config ID.
4. **Given** a Sales Line record in the local store has a blank Product Code or a blank Config ID, **When** the distinct combinations are derived, **Then** that record does not contribute a lookup (a combination cannot be looked up without both values).
5. **Given** a Variant Attribute lookup for a given combination returns no data, **When** this phase runs, **Then** no record is added for that combination — this is not treated as an error, and the run continues with the remaining combinations.
6. **Given** User Story 1's phase has not yet completed for the current run, **When** the triggered action executes, **Then** this phase does not begin until every Sales Line record for that run has been retrieved, evaluated, and saved.

---

### Edge Cases

- What happens when the ERP Sales Line source returns more than one record for the same Sales ID within a single run? Each occurrence is evaluated and saved independently — this phase does not de-duplicate by Sales ID.
- What happens when more than one Product reference record matches the same Item ID + Config ID? The first match encountered is used; the rest are not evaluated for that Sales Line record.
- What happens when the ERP Sales Line source or the Product reference source is temporarily unavailable or returns an error mid-run? The run stops and reports failure; local records already saved before the failure remain (no automatic rollback), and a subsequent run can be retried.
- What happens when the ERP Variant Attribute source is temporarily unavailable or returns an error while processing a Product/Config combination? Consistent with the Sales Line phase's failure handling, the run stops and reports failure; combinations already processed before the failure remain saved, and a subsequent run can be retried.
- What happens if the synchronization action is triggered again while a previous run is still in progress? Out of scope for this feature; concurrent runs are not guarded against, consistent with how the existing `eutr-synchronize-data` feature (011) treats this same scenario.
- What happens when a Sales Line record's Product reference match exists but has blank Name, Description, Type, or Range values in the ERP data itself? The local record stores whatever value the ERP source provides (blank where the source itself is blank) — this is not treated as a missing match.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a single manually triggerable synchronization action that, in one run, first synchronizes Sales Line + Product data (User Story 1) and then, after that phase fully completes, synchronizes Variant Attribute data (User Story 2).
- **FR-002**: The Sales Line phase MUST retrieve the full set of Sales Line records from the ERP's Sales Line data source, across all pages/batches of that source, before the phase finishes.
- **FR-003**: For each retrieved Sales Line record, System MUST derive a local Sales Line record's Product Code from that record's Item ID, and copy its Sales ID and Sales Status directly.
- **FR-004**: For each retrieved Sales Line record, System MUST look up a matching Product reference record from the ERP's Product reference data (Product/Variant reference data) whose Product Code equals the Sales Line record's Item ID and whose Config ID equals the Sales Line record's Config ID.
- **FR-005**: When a matching Product reference record (FR-004) is found, System MUST populate the local Sales Line record's Name, Description, Type, and Range from that Product reference record.
- **FR-006**: When no matching Product reference record is found for a Sales Line record, System MUST still create the local Sales Line record, leaving Name, Description, Type, and Range blank.
- **FR-007**: System MUST skip any retrieved Sales Line record that is missing an Item ID or a Sales ID, without creating a local record for it.
- **FR-008**: Before saving any Sales Line record for a run, System MUST clear every existing record in the local Sales Line store, so each run's local Sales Line data reflects only that run's results — no record from a previous run persists into the current one.
- **FR-009**: After the Sales Line phase (FR-002 through FR-008) has fully completed for a run, System MUST derive the distinct set of Product Code + Config ID combinations present across that run's local Sales Line records.
- **FR-010**: System MUST exclude from the distinct combinations (FR-009) any local Sales Line record with a blank Product Code or a blank Config ID.
- **FR-011**: For each distinct Product Code + Config ID combination (FR-009), System MUST retrieve that combination's Variant Attribute data from the ERP's Variant Attribute data source, filtered to that exact Product and Config — performing exactly one lookup per distinct combination, never one per Sales Line record.
- **FR-012**: Before saving any Variant Attribute data for a run, System MUST clear every existing record in the local Variant Attribute store, so each run's local Variant Attribute data reflects only that run's results — no record from a previous run persists into the current one.
- **FR-013**: For each distinct combination whose lookup (FR-011) returns data, System MUST save that data to the local Variant Attribute store, associated with that combination's Product Code and Config ID.
- **FR-014**: When a lookup (FR-011) for a given combination returns no data, System MUST NOT create a record for that combination, and MUST continue processing the remaining combinations without treating this as an error.
- **FR-015**: System MUST report the outcome of a run (at minimum: success/failure, and per-phase counts of records retrieved/added/skipped) back to the caller who triggered it.
- **FR-016**: System MUST restrict the synchronization action to authenticated/authorized callers, consistent with other administrative synchronization actions in the system (e.g., the existing `eutr-synchronize-data` feature, 011).
- **FR-017**: When the ERP source for either phase is temporarily unavailable or returns an error mid-run, System MUST stop the run and report failure; records already saved before the failure remain (no automatic rollback), and a subsequent run can be retried.

### Key Entities

- **Sales Line Reference (ERP source data)**: A record from the ERP's Sales Line data representing one sales line. Key attributes used by this feature: Item ID, Sales ID, Sales Status, Config ID.
- **Product Reference (ERP source data)**: A record from the ERP's Product/Variant reference data representing one product's descriptive attributes. Key attributes used by this feature: Product Code, Config ID, Name, Description, Type, Range.
- **Variant Attribute Reference (ERP source data)**: A record from the ERP's Variant Attribute data representing the attribute details specific to one Product + Config combination.
- **Sales Line Sync Record (local, persisted)**: The stored result of synchronizing one ERP Sales Line record — Product Code (from Item ID), Sales ID, Sales Status, and, when a matching Product Reference record exists, Name, Description, Type, and Range. Every run first clears every existing record in this store (FR-008), then inserts one record per retrieved Sales Line record that has both an Item ID and a Sales ID (FR-007) — the store always reflects only the most recent run's results.
- **Variant Attribute Sync Record (local, persisted)**: The stored result of one distinct Product Code + Config ID combination's Variant Attribute lookup. Every run first clears every existing record in this store (FR-012), then inserts one record per distinct combination whose lookup returned data (FR-013/FR-014) — the store always reflects only the most recent run's results.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A synchronization run evaluates 100% of the ERP Sales Line records available at run time, regardless of how many pages/batches the underlying source spans.
- **SC-002**: After a run, every locally saved Sales Line record whose Item ID + Config ID has a matching ERP Product reference record shows that record's Name, Description, Type, and Range — 0 unmatched-but-populated or matched-but-blank rows.
- **SC-003**: After the Sales Line phase completes, the number of Variant Attribute lookups performed equals the number of distinct Product Code + Config ID combinations present in that run's Sales Line data — never more (no duplicate lookups for the same combination) and never fewer (no combination skipped).
- **SC-004**: After a run, both local stores (Sales Line Sync and Variant Attribute Sync) contain only records produced by that run — 0 records carried over from any earlier run.
- **SC-005**: A Data Administrator can determine, from the synchronization action's response alone (without inspecting logs or the database), whether the run succeeded and how many records were processed in each phase.
- **SC-006**: Running the synchronization twice in succession with unchanged ERP source data produces the same two local stores' contents after the second run as after the first (no accumulation of duplicate or stale rows).

## Assumptions

- Like the existing `eutr-synchronize-data` feature (011), this synchronization is a manually-triggered, test-oriented action rather than a scheduled/automatic background job; adding scheduling is out of scope for this feature.
- The synchronization is one-directional: from the ERP into the two local stores. It does not update, delete, or reconcile ERP-side data.
- Both local stores follow the existing "clear entire store, then fully repopulate" pattern already used by comparable local sync/snapshot tables in this system, rather than an "insert if not already present" pattern — this was confirmed via `/speckit-specify` clarification (see below); every run's stored data reflects only that run's results.
- "Product reference data, type 6" is the same reference data source already exposed by the existing generic reference lookup used elsewhere in this system's ERP synchronization features, filtered to the Product/Variant reference type.
- When a Sales Line record's Item ID + Config ID matches more than one Product reference record, the first match encountered is used, consistent with the "first occurrence wins" convention already established elsewhere in this system's synchronization features.
- Errors from either ERP source during a run are surfaced as a failed run rather than being silently swallowed, since the administrator needs to know whether the full dataset was processed, consistent with the existing `eutr-synchronize-data` feature's failure handling.
- This feature introduces two new local tables (`compl_sync_sales_line` and `compl_sync_variant_attributes`) and does not modify any existing table from other features.

### `/speckit-specify` Clarification — Run Repeatability (2026-08-19)

**Question**: When the synchronization action is triggered again, should its two local stores (Sales Line Sync, Variant Attribute Sync) be cleared and fully rebuilt each run, skip records that already exist (like the existing `eutr_purchase_attachments` sync), or simply append every run's results on top of whatever is already stored?

**Answer**: Clear each store entirely at the start of its phase, then fully repopulate it from that run's data (FR-008, FR-012) — matching the pattern already used by this system's comparable local sync/snapshot tables. Reflected in FR-008, FR-012, the Key Entities, SC-004, and SC-006.
