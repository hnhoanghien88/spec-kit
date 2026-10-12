# Feature Specification: Duplicate File Confirmation on PO Upload

**Feature Branch**: `025-upload-duplicate-confirm`

**Created**: 2026-10-12

**Status**: Draft

**Input**: User description: "cập nhật 004-eutr-documents, 005-eutr-sales-orders, 012-eutr-purchase-orders. Trường hợp file trên PO đã tồn tại (giống tên, giống đuôi file như .xml, .pdf), user không nhớ úp thêm 1 lần nữa, hiển thị cảnh báo file tồn tại và hiển thị xác nhận Upload hoặc bỏ qua. User chưa xác nhận thì xử lý file khác, khi user xác nhận thì xử lý xong file khác quay lại xử lý các file user đã xác nhận"

**Applies to**: the document Upload flows of `004-eutr-documents`, `005-eutr-sales-orders` and `012-eutr-purchase-orders`. It extends the multi-file progress queue of `021-upload-progress-queue`; all existing Upload rules (file types, 20MB limit, Template-based Step matching, folder grouping) are unchanged.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Warn when a file already exists on the PO and let the user decide (Priority: P1)

A compliance staff member uploads a batch of files for a PO. Some of them may already have been uploaded before (same file name and same extension, e.g. `Invoice.pdf` already exists on that PO) because the user forgot. For each such file the system shows a warning that the file already exists and asks the user to choose **Upload** (upload it again) or **Skip**. Nothing is overwritten or duplicated without the user's explicit choice.

**Why this priority**: This is the core request. Today a forgotten re-upload is processed silently; the user needs an explicit, informed decision per file.

**Independent Test**: On a PO that already has `A.pdf`, upload `A.pdf` and `B.pdf`. Verify `B.pdf` is uploaded normally, while `A.pdf` shows an "already exists" warning with Upload and Skip choices and is not processed until a choice is made.

**Acceptance Scenarios**:

1. **Given** the PO already has `A.pdf`, **When** the user uploads a file named `A.pdf`, **Then** the system flags it as "already exists" and asks for Upload or Skip.
2. **Given** the PO already has `A.pdf`, **When** the user uploads `A.xml` or `A_v2.pdf`, **Then** no warning is shown (name and extension must both match) and the file is processed normally.
3. **Given** a file is flagged as existing, **When** the user chooses Skip, **Then** the file is not uploaded, the existing file is untouched, and the file is shown as Skipped.
4. **Given** a file is flagged as existing, **When** the user chooses Upload, **Then** the file is uploaded as the user's confirmed action.
5. **Given** a batch with no existing files, **When** the user uploads, **Then** behavior is exactly as today with no extra prompts.

---

### User Story 2 - Unconfirmed duplicates never block the other files (Priority: P1)

While a flagged file waits for the user's decision, all other (non-duplicate) files in the batch continue to be processed. Files the user has confirmed are processed only after the non-duplicate files have finished; then the system returns to the confirmed files and uploads them.

**Why this priority**: Equal to Story 1 — the user explicitly asked that waiting for an answer must not stall the batch.

**Independent Test**: Upload 10 files where 3 already exist. Verify the 7 new files proceed immediately without waiting; the 3 flagged files stay "Awaiting confirmation". Confirm 2 of them (Upload) and skip 1 while the 7 are still running; verify the 2 confirmed files start only after the 7 have finished, and the skipped one never does.

**Acceptance Scenarios**:

1. **Given** a batch containing flagged and non-flagged files, **When** the batch starts, **Then** non-flagged files are processed immediately and flagged files wait for a decision.
2. **Given** the user has not answered yet, **When** the non-flagged files finish, **Then** the flagged files remain "Awaiting confirmation" (the batch is not reported as fully finished) and the user can still answer.
3. **Given** the user confirms Upload for some flagged files while other files are still processing, **Then** the confirmed files are queued and processed only after all non-flagged files have finished.
4. **Given** the user confirms Upload after all non-flagged files have already finished, **Then** the confirmed files are processed right away.
5. **Given** the user confirms several files, **Then** all of them are processed (one failing does not stop the rest, per `021-upload-progress-queue`).

---

### User Story 3 - Decide for many duplicates quickly (Priority: P2)

When several files in the same batch are flagged, the user can answer them one by one or apply one choice to all flagged files at once ("Upload all" / "Skip all").

**Why this priority**: Convenience for large batches; the feature works without it.

**Independent Test**: Upload a batch with 5 existing files; press "Skip all" and verify all 5 become Skipped; repeat with "Upload all" and verify all 5 are queued for upload.

**Acceptance Scenarios**:

1. **Given** several flagged files, **When** the user presses "Upload all", **Then** every still-undecided flagged file is confirmed.
2. **Given** several flagged files, **When** the user presses "Skip all", **Then** every still-undecided flagged file is skipped.
3. **Given** the user already decided some files individually, **When** "Upload all"/"Skip all" is pressed, **Then** only the undecided ones are affected.

---

### Edge Cases

- The same name and extension appear twice inside one batch while the PO has no such file: both are treated as new files (existing behavior of `021`); the warning only concerns files that already exist on the PO.
- Name comparison ignores letter case (`A.PDF` vs `a.pdf` are the same file); extension must be equal to count as a match.
- Same name but different extension (`A.pdf` vs `A.xml`) is NOT a duplicate.
- The user closes the progress popup while files are awaiting confirmation: the batch stays open in the background with its awaiting indicator; the user is reminded that decisions are pending and can reopen the popup to answer.
- The user leaves the screen while files are awaiting confirmation or confirmed-but-not-yet-processed: the existing leave-confirmation of `021` also applies; unanswered files are discarded (treated as Skipped) and nothing is uploaded for them.
- "Retry failed" (from `021`) on a confirmed duplicate that failed does not ask for confirmation again.
- A file rejected by existing validation (type, size, no matching Step, PO has no Template) is shown as Failed as before; it is not offered Upload/Skip.
- The existing file on the PO is removed or changed by someone else while the user is deciding: the confirmed file is processed according to the state at processing time (if it no longer exists, it is simply uploaded as new).
- Existence is judged on the PO the user is uploading to; a same-named file on another PO is not a duplicate.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Before processing a batch, the system MUST check each selected file against the files already attached to the target PO, and flag a file as "already exists" when its name (case-insensitive) and extension both equal those of an existing PO file.
- **FR-002**: A flagged file MUST NOT be processed until the user explicitly chooses **Upload** or **Skip**; it MUST be shown in the progress popup with a status "Awaiting confirmation" and a visible warning that the file already exists.
- **FR-003**: Choosing **Skip** MUST leave the existing file and all data unchanged and mark the file "Skipped"; a Skipped file is not counted as Failed.
- **FR-004**: Choosing **Upload** MUST mark the file as confirmed and queue it for processing.
- **FR-005**: Non-flagged files MUST be processed immediately and MUST NOT wait for any decision on flagged files.
- **FR-006**: Confirmed files MUST be processed only after all non-flagged files of the batch have finished; when the user confirms after that point, they are processed immediately.
- **FR-007**: The batch MUST NOT be reported as finished while any file is still "Awaiting confirmation" or confirmed-but-unprocessed; the final summary appears only when every file is Done, Failed or Skipped.
- **FR-008**: The progress summary of `021` MUST be extended with skipped and awaiting-confirmation counts, kept in sync with per-file statuses; every file is in exactly one state: Waiting, Uploading, Awaiting confirmation, Done, Failed or Skipped.
- **FR-009**: The popup MUST offer "Upload all" and "Skip all" actions that apply only to still-undecided flagged files.
- **FR-010**: Closing the popup MUST NOT cancel or auto-decide pending confirmations; the on-screen batch indicator MUST show that confirmations are pending and let the user reopen the popup.
- **FR-011**: Leaving the screen while confirmations are pending or confirmed files are unprocessed MUST require the existing leave confirmation; unanswered flagged files are discarded and nothing is uploaded for them.
- **FR-012**: Files that fail existing validation MUST be shown as Failed with their existing message and MUST NOT be offered Upload/Skip.
- **FR-013**: The behavior in FR-001–FR-012 MUST be identical in the Upload flows of 004-eutr-documents, 005-eutr-sales-orders and 012-eutr-purchase-orders (same states, wording and layout).
- **FR-014**: After the batch ends, the originating screen MUST refresh to reflect saved documents, as in `021`.
- **FR-015**: All existing Upload business rules (allowed types, 20MB limit, Template-based Step matching, folder grouping, validity dates, Invoice number) MUST remain unchanged.

### Key Entities

- **Upload Item** (extended from `021`): adds statuses *Awaiting confirmation* and *Skipped*, a flag "already exists on PO", and the user's decision (undecided / Upload / Skip).
- **Existing PO File**: a file already attached to the target PO, identified for comparison by its name and extension.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In 100% of uploads where a file's name and extension match an existing PO file, the user sees the warning and no data is changed before they choose.
- **SC-002**: In a batch mixing new and existing files, 100% of new files are processed without waiting for any user decision on the existing ones.
- **SC-003**: 100% of files the user confirms are processed after the non-flagged files finish, and 0% of skipped files are processed.
- **SC-004**: The user can resolve a batch of 20 flagged files with a single action ("Upload all" or "Skip all").
- **SC-005**: Accidental duplicate uploads caused by forgetting an earlier upload drop to zero for users who choose Skip.
- **SC-006**: The same behavior and wording is verified in all three screens (004, 005, 012).

## Assumptions

- "File already exists" is judged by file name (case-insensitive) plus extension among the files currently attached to the target PO; file content is not compared.
- Choosing Upload on a flagged file uploads it again as the user's confirmed action. The new file is kept alongside the previous one (a new document is created; nothing is deleted or replaced) — decided at planning (research D4).
- A single decision per file per batch is enough; the system does not remember an "always upload / always skip" preference.
- The 20-file batch limit, 20MB limit and allowed types of the existing features still apply.
- Pending decisions are not persisted beyond the current page session.
- Popup text follows the existing language and style of the application's Upload screens.
- No change to permissions is intended.
