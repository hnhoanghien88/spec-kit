# Research: Duplicate File Confirmation on PO Upload

## D1 — Where to detect duplicates
- **Decision**: New read-only endpoint `POST /api/eutr-documents/check-existing-files`; the client calls it once per batch before enqueueing.
- **Rationale**: Existing upload endpoints always create a new document (`GetUniqueFileName` only avoids a SharePoint name clash) and return no "exists" signal. `list-po-references` returns names but without Type filtering/renaming rules, and returning every document of a PO to compare client-side is heavier and duplicates the renaming rule.
- **Alternatives**: (a) client-side compare against the AVAILABLE FILES list — rejected, the 004 screen has no per-PO list and the list may be stale; (b) add a "skip if exists" flag to the upload endpoints — rejected, the decision must be interactive and per file.

## D2 — What "same file" means (effective stored name)
- **Decision**: Compare case-insensitively against `eutr_documents.Name` of documents that have an `eutr_references` row with the same `RefValue` (in the batch's reference values) and the same `RefType` (Type of the batch). For Type = "PO" the candidate name is the original file name (Update 29: no rename); for other Types it is `BuildRenamedFileName(stepName, stepId, fileName)` = `{sanitized Step name}{ext}`.
- **Rationale**: This is exactly the name the upload would store, so "duplicate" means "would create a document that looks identical in the list". Extension is part of the name, so `A.pdf` ≠ `A.xml` (spec edge case).
- **Alternatives**: compare only the base name — rejected (spec requires same extension too).
- **Note**: for non-PO Types every re-upload to the same Step produces the same renamed name, so the warning also protects against repeated uploads there; this is consistent with the spec rule and FR-013.

## D3 — When to run the check and what happens on failure
- **Decision**: Run in `handleFilesSelected` after client-side validation, `await` the single request (small payload), then call `startBatch` with `existingNames`. If the request fails, **fail open**: treat no file as flagged and show nothing extra — the batch behaves as `021` today.
- **Rationale**: Blocking uploads because a pre-check failed would be worse than the original behavior; the check is advisory.
- **Alternatives**: fail closed — rejected.

## D4 — Meaning of confirmed Upload
- **Decision**: Keep both: a confirmed file goes through the unchanged upload endpoints and creates a **new** document; the old document is not deleted or replaced.
- **Rationale**: Replacing would require deleting/updating a document + SharePoint file and its references/progression (data-loss risk, new permissions). Keep-both reuses existing behavior, is reversible by the user (delete a document), and satisfies "xác nhận Upload". Recorded in spec Assumptions (resolved).
- **Alternatives**: replace in place — deferred; can be a follow-up feature.

## D5 — Queue ordering for confirmed files
- **Decision**: Store items get statuses `awaiting` and `skipped`. The runner picks `waiting` items first; items confirmed by the user are set to `confirmed-waiting` (`status: waiting`, `confirmed: true`) and the runner always prefers `waiting && !confirmed` before `waiting && confirmed`. The runner stays alive (does not finish the batch) while any item is `awaiting`; a decision made while the runner is idle starts it again.
- **Rationale**: Gives FR-005/FR-006/FR-007 with minimal change to the working sequential runner (concurrency 1 stays).
- **Alternatives**: second independent queue — rejected, duplicates retry/notification logic.

## D6 — Batch completion, notification, leaving
- **Decision**: `running` stays true while there are `waiting`/`uploading` items; a new derived `pending` flag = any `awaiting` item. "Finished" (refresh via `onFinished`, snackbar summary) fires only when neither is true. While `pending` and not running: keep the floating chip (label "Confirm n file(s)") and the `beforeunload` guard; leaving discards unanswered files (treated as skipped by simply dropping the batch).
- **Rationale**: FR-007, FR-010, FR-011.

## D7 — UI
- **Decision**: In the progress popup, an `awaiting` row shows a warning text "File already exists on this PO" with buttons **Upload** and **Skip**; the dialog actions show **Upload all** / **Skip all** while any `awaiting` item exists; status chips add "Awaiting confirmation" (warning color) and "Skipped" (default). Summary line adds `· N skipped · M awaiting`.
- **Rationale**: Same dialog for all three screens (FR-013).

## D8 — Retry interaction
- **Decision**: "Retry failed" re-queues failed items as `waiting` without re-checking duplicates (spec edge case). Skipped items are not retryable.
