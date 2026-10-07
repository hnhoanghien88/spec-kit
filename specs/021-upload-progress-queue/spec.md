# Feature Specification: Multi-File Upload Progress Queue

**Feature Branch**: `021-upload-progress-queue`

**Created**: 2026-10-07

**Status**: Draft

**Input**: User description: "cập nhật chức năng upload file trong 005-eutr-sales-orders, 004-eutr-documents, 012-eutr-purchase-orders. Khi up 1 lần 20 file, cần hiển thị màn hình hoặc popup 20 file, và file nào đang up, up xong, up lỗi, khi có 1 file lỗi thì bỏ qua, tiếp tục úp file khác."

**Applies to**: the document Upload flows of `004-eutr-documents`, `005-eutr-sales-orders` and `012-eutr-purchase-orders`. This spec defines one shared behavior for all three; existing rules of those features (file types, size limit, Step matching, folder grouping, document creation) are unchanged.

## Clarifications

### Session 2026-10-07

- Q: What happens to remaining files when the user closes the popup mid-upload? → A: The upload continues in the background; the popup can be reopened while running and the user is notified when the batch finishes.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See every selected file and its live upload status (Priority: P1)

A compliance staff member selects up to 20 files at once and presses Upload. Instead of waiting with no feedback, a progress popup opens listing every selected file (name, size) with a status per file: **Waiting**, **Uploading**, **Done** or **Failed**. The status of each file changes live as the upload proceeds, and a summary line shows how many files are done / failed / remaining.

**Why this priority**: This is the core request. Without per-file visibility the user cannot tell whether a 20-file batch is progressing, stuck, or partly failed.

**Independent Test**: In any of the three Upload screens, select 20 valid files and press Upload. Verify the popup lists all 20 files immediately, the file(s) currently being sent show "Uploading", finished ones switch to "Done", and the summary counts match the list.

**Acceptance Scenarios**:

1. **Given** the user selected 20 files, **When** they press Upload, **Then** a popup opens listing all 20 files, each initially "Waiting" except those already being processed which show "Uploading".
2. **Given** the batch is in progress, **When** a file finishes successfully, **Then** its row changes to "Done" and the summary counters update without closing or reopening the popup.
3. **Given** the batch is in progress, **When** the user looks at the popup, **Then** at any moment every file is in exactly one state: Waiting, Uploading, Done or Failed.
4. **Given** all files have finished, **When** the last file completes, **Then** the popup shows the final summary (e.g., "18 done, 2 failed") and offers a Close action.

---

### User Story 2 - One failed file does not stop the rest (Priority: P1)

When a single file fails to upload (e.g., no matching Step, storage error, rejected file), the system marks that file "Failed" with a short reason, skips it, and continues uploading the remaining files. Files that succeeded are saved normally, even if others in the same batch failed.

**Why this priority**: Equal to Story 1 — today one bad file can make the user redo the whole batch. Isolating failures is the second half of the request.

**Independent Test**: Select 20 files where 1–2 are known to fail (e.g., a name that matches no Step for Type = PO). Upload. Verify the failing files show "Failed" with a reason and all other files end "Done" and exist as documents afterwards.

**Acceptance Scenarios**:

1. **Given** file #5 of 20 will fail, **When** the batch runs, **Then** file #5 shows "Failed" with a reason and files #6–#20 are still uploaded.
2. **Given** several files fail, **When** the batch ends, **Then** every successful file has been saved, and each failed file lists its own reason.
3. **Given** every file fails, **When** the batch ends, **Then** the popup shows all files as "Failed" and no document is created.

---

### User Story 3 - Retry only the failed files (Priority: P2)

After a batch ends with failures, the user can retry just the failed files from the popup, without re-selecting files or re-uploading the successful ones.

**Why this priority**: Convenient follow-up that avoids duplicate documents and rework, but the core value is delivered without it.

**Independent Test**: Finish a batch with 2 failures, fix the cause, press "Retry failed". Verify only the 2 failed files are re-sent and the 18 successful ones are not duplicated.

**Acceptance Scenarios**:

1. **Given** a finished batch with failed files, **When** the user presses "Retry failed", **Then** only failed files return to "Waiting" and are processed again; "Done" files are untouched.
2. **Given** a finished batch with no failures, **When** the popup is shown, **Then** no Retry action is offered.

---

### Edge Cases

- A file is rejected before sending (unsupported type or larger than the existing 20MB limit): it appears in the list as "Failed" with the reason and does not block the others.
- The user selects only 1 file: the same popup appears with a single row (consistent behavior).
- The user closes the popup while files are still uploading: the upload continues in the background, the popup can be reopened to see live status, and files already "Done" are never rolled back.
- The user navigates away from the screen (leaves the page) while files are still uploading: the system warns that uploading is in progress and requires confirmation; confirming does not roll back files already "Done".
- Network drops mid-batch: the file in progress is marked "Failed" (reason: connection) and remaining files continue or fail individually; already "Done" files stay saved.
- The same file name appears twice in the batch: both rows are shown separately with independent statuses.
- After the batch ends, the underlying list screen (documents / sales order / purchase order) refreshes so newly saved documents are visible, even when some files failed.
- More than 20 files selected: handled by the existing selection limit of each screen; this feature does not change that limit.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: On pressing Upload with one or more files, the system MUST open a progress popup listing every selected file (name and size) before upload processing completes.
- **FR-002**: The popup MUST show, for each file, exactly one status: Waiting, Uploading, Done or Failed, and MUST update it live as processing progresses.
- **FR-003**: The popup MUST show a summary of total, done, failed and remaining file counts, kept in sync with the per-file statuses.
- **FR-004**: When a file fails, the system MUST mark it Failed with a human-readable reason, skip it, and MUST continue processing all remaining files.
- **FR-005**: Files that succeeded MUST be saved as documents regardless of other files failing in the same batch (no all-or-nothing behavior).
- **FR-006**: A failure of one file MUST NOT create, modify or delete the document of any other file in the batch.
- **FR-007**: Files rejected by existing validation (type, size, Step matching, etc.) MUST appear in the same list as Failed with the existing validation message as the reason.
- **FR-008**: The popup MUST remain open after completion, showing the final result, until the user closes it.
- **FR-009**: The system MUST offer a "Retry failed" action when at least one file failed, which re-processes only failed files and leaves Done files untouched.
- **FR-010**: Closing the popup while files are still uploading MUST NOT cancel the batch: processing continues in the background, a visible indicator on the screen shows the batch is running, and the user can reopen the popup to see live status. Leaving the screen while a batch is running MUST require explicit user confirmation. The Upload action MUST NOT be triggerable again for the same selection while a batch is running.
- **FR-010a**: When a batch finishes while its popup is closed, the system MUST notify the user of the result summary (done / failed counts) and offer to reopen the popup, so failed files and Retry remain reachable.
- **FR-011**: After the batch ends (fully or partially successful), the originating screen MUST refresh its data to reflect the saved documents.
- **FR-012**: The behavior in FR-001–FR-011 MUST be identical in the Upload flows of 004-eutr-documents, 005-eutr-sales-orders and 012-eutr-purchase-orders (same states, wording and layout).
- **FR-013**: Existing Upload business rules (allowed file types, 20MB limit, Type-specific Step matching, folder grouping, validity dates, Invoice number, etc.) MUST remain unchanged.

### Key Entities

- **Upload Batch**: One Upload action by a user; contains the ordered list of selected files and an overall summary (total, done, failed, remaining).
- **Upload Item**: One file within a batch; has name, size, status (Waiting / Uploading / Done / Failed) and, when Failed, a failure reason.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For a 20-file batch, 100% of the files are visible in the popup within 1 second of pressing Upload.
- **SC-002**: At any moment during a batch, the user can identify which files are uploading, done and failed, with the per-file statuses and the summary counts always agreeing.
- **SC-003**: In a 20-file batch containing 1–3 failing files, 100% of the valid files are saved and the number of Failed rows equals the number of failing files.
- **SC-004**: Users no longer need to re-select and re-upload an entire batch because of a single failure; recovering from failures requires only one "Retry failed" action.
- **SC-005**: The same popup behavior is verified in all three screens (004, 005, 012) with no differences in states or wording.

## Assumptions

- The maximum batch is 20 files, matching the user's example; the per-file 20MB limit and allowed types of the existing features still apply.
- Files are processed per file (not as one atomic request), so each file has its own outcome; whether they run sequentially or a few at a time is an implementation choice, provided statuses stay accurate.
- A per-file percentage progress bar is not required; status labels (Waiting / Uploading / Done / Failed) are sufficient.
- Failed files are not persisted beyond the current page session: Retry is available while the popup (or its reopen indicator) is available; leaving the screen discards failed files and they must be selected again.
- Popup text follows the existing language and style of the application's Upload screens.
- No change to permissions, data model or the stored document structure is intended.
