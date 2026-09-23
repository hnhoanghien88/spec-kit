# Feature Specification: PO Upload Folder Grouping

**Feature Branch**: `019-po-upload-folder-grouping`

**Created**: 2026-09-22

**Status**: Draft

**Input**: User description: "cập nhật lại logic upload file cho type = PO ở 004-eutr-documents, 005-eutr-sales-orders, 012-eutr-purchase-orders sẽ nhóm các folder PO vào trong thư mục tên PO như PO / -- PO1 / -- PO2"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Upload a document for a PO whose folder does not exist yet (Priority: P1)

A compliance staff member uploads a document (Type = PO) for a Purchase Order that has never had a document uploaded before. Today the system creates a new top-level folder named after the PO code directly under the EUTR storage root. Going forward, the system must first ensure a shared parent folder named "PO" exists at the storage root, then create the PO-code folder nested inside that "PO" folder, and store the file there.

**Why this priority**: This is the core behavior change requested — without it, no PO folder is ever grouped correctly, so nothing else in this feature has value until this works.

**Independent Test**: Upload a document with Type = PO for a brand-new PO code that has no existing SharePoint folder. Verify the resulting storage path is `.../PO/<PoCode>/<file>` (not `.../<PoCode>/<file>`), and that the file is retrievable from that nested location.

**Acceptance Scenarios**:

1. **Given** the storage root has no "PO" folder yet, **When** a user uploads a document with Type = PO for PO code "PO000123", **Then** the system creates a "PO" folder under the storage root, creates a "PO000123" folder nested inside "PO", and stores the file there.
2. **Given** the "PO" folder already exists but "PO000124" does not exist inside it, **When** a user uploads a document with Type = PO for PO code "PO000124", **Then** the system reuses the existing "PO" folder and creates only the missing "PO000124" folder nested inside it.

---

### User Story 2 - Upload additional documents for a PO that already has a nested folder (Priority: P2)

A user uploads a second or later document for a PO code that already has its nested folder (e.g., `PO/PO000123/`). The system must recognize the existing nested folder and reuse it rather than creating a duplicate or a flat sibling folder.

**Why this priority**: Ensures the fix is idempotent and doesn't create duplicate/conflicting folders on repeat uploads, which is essential for correctness but depends on User Story 1 already being implemented.

**Independent Test**: Upload two documents in sequence for the same PO code and verify both land in the same nested folder path with no duplicate folders created.

**Acceptance Scenarios**:

1. **Given** folder "PO/PO000123" already exists with one file in it, **When** a user uploads another document with Type = PO for PO code "PO000123", **Then** the file is added to the existing "PO/PO000123" folder and no new folder is created.

---

### User Story 3 - View/download PO documents uploaded via Sales Orders and Purchase Orders screens (Priority: P2)

Users viewing or downloading PO-type documents from the Sales Orders overview screen or the Purchase Orders screen (both of which reuse the shared document upload/download logic) see and retrieve files from the new nested "PO/<PoCode>" location, with no broken links or missing files for documents uploaded after this change.

**Why this priority**: These two screens do not implement their own folder logic but depend on the shared upload/list/download behavior, so they must keep working once the underlying path changes.

**Independent Test**: From the Sales Orders overview screen and from the Purchase Orders screen, upload a PO-type document, then list/view/download it from the same screen and confirm it resolves correctly to the nested folder path.

**Acceptance Scenarios**:

1. **Given** a document was uploaded with Type = PO from the Sales Orders overview screen, **When** the user opens the document list or downloads the file, **Then** the file is found and downloaded successfully from the nested "PO/<PoCode>" folder.
2. **Given** a document was uploaded with Type = PO from the Purchase Orders screen, **When** the user opens the document list or downloads the file, **Then** the file is found and downloaded successfully from the nested "PO/<PoCode>" folder.

---

### Edge Cases

- What happens to documents that were already uploaded before this change, sitting in the old flat `<PoCode>` folder location? They are NOT moved automatically; existing files remain in their current flat folders and continue to be accessible from there (no migration of historical files is in scope — see Assumptions).
- What happens if the PO code itself is literally "PO" (unlikely per PO code format, but should not collide with the new grouping folder name)? The system must treat the grouping folder and a PO-code folder as distinct path segments, so a PO code equal to "PO" would nest as `PO/PO/`, which is acceptable and non-breaking.
- What happens if folder creation for the "PO" parent folder fails (e.g., storage/network error) partway through? The upload must fail with a clear error and must not create a partial/orphaned PO-code folder outside of the "PO" parent.
- What happens for other document Types (Vendor, Invoice, Delivery note, General agreement, etc.)? Their folder structure is unchanged by this feature — only Type = PO folders are nested under a new "PO" parent folder.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST, when uploading a document with Type = PO, resolve or create a folder named "PO" directly under the existing EUTR storage root before resolving or creating the PO-code folder.
- **FR-002**: System MUST resolve or create the PO-code folder (e.g., "PO000123") nested inside the "PO" parent folder, instead of directly under the storage root.
- **FR-003**: System MUST reuse an existing "PO" parent folder and an existing PO-code folder when they already exist, without creating duplicates.
- **FR-004**: System MUST apply this nested folder resolution consistently across every upload entry point that handles Type = PO documents, including the entry points used by 004-eutr-documents (Add/Edit document popup), 005-eutr-sales-orders (Sales Orders overview upload), and 012-eutr-purchase-orders (Purchase Orders upload).
- **FR-005**: System MUST leave the folder structure for all non-PO document Types unchanged.
- **FR-006**: System MUST allow listing and downloading of PO-type documents uploaded after this change from their new nested "PO/<PoCode>" location.
- **FR-007**: System MUST NOT move, rename, or otherwise alter documents already stored in the old flat "<PoCode>" folder location as part of this change.
- **FR-008**: System MUST fail the upload with a clear error and MUST NOT leave a partially created folder structure if the "PO" parent folder cannot be created.

### Key Entities

- **PO Document Folder**: The storage location for a Purchase Order's uploaded documents. Previously a single-level folder named after the PO code, directly under the storage root. Now a two-level structure: a shared "PO" parent folder under the storage root, containing one subfolder per PO code.
- **Document Type**: Classifies an uploaded document (e.g., PO, Vendor, Invoice, Delivery note, General agreement). Only the Type = PO case is affected by this feature.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of new document uploads with Type = PO, across the Documents, Sales Orders, and Purchase Orders screens, are stored under a nested "PO/<PoCode>" path rather than a flat "<PoCode>" path.
- **SC-002**: Repeated uploads for the same PO code never create more than one "PO" parent folder or more than one folder per PO code.
- **SC-003**: 100% of PO-type documents uploaded after this change can be listed and downloaded successfully from all three affected screens.
- **SC-004**: Existing documents uploaded before this change remain accessible with zero data loss (no automatic migration required).

## Assumptions

- Only newly uploaded PO-type documents are grouped under the new "PO" parent folder; documents uploaded before this change stay in their current flat folder location and are not migrated as part of this feature. Migrating historical folders can be a separate follow-up if needed.
- The name of the shared parent folder is exactly "PO" (matching the Type value), placed directly under the same storage root currently used for flat PO folders.
- 005-eutr-sales-orders and 012-eutr-purchase-orders do not implement independent folder-resolution logic; they call into the same shared upload logic owned by 004-eutr-documents, so this feature's functional requirements are satisfied by changing that shared logic once and verifying it end-to-end from all three screens.
- No change is required to the folder structure or naming for any Document Type other than PO.
