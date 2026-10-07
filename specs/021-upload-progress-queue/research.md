# Research: Multi-File Upload Progress Queue

## Decision 1 — Where to implement: shared dialog, frontend only
- **Finding**: All three features open `EutrDocumentsFormDialog` (`presentation/pages/eutr-documents/components/`); its `handleFilesSelected` sends all files in one multipart request to `/sharepoint/eutr-upload-multi` (Type = PO) or `/sharepoint/eutr-upload-multi-by-type`, and the response already carries per-file `{fileName, success, errorMessage}`.
- **Decision**: change only the client. Reuse backend as-is (Constitution III).
- **Alternatives**: SignalR/streaming progress from the backend (rejected: backend change, large effort); new batch endpoint (rejected: unnecessary).

## Decision 2 — One request per file, sequential
- **Rationale**: only per-file requests give real live per-file status; sequential avoids concurrent creation of the same SharePoint folder for the same PO/Type and keeps statuses simple.
- **Alternatives**: parallel pool of 3 (faster but folder-creation race risk); single request then reveal results (no live status).
- **Note**: a Type = PO batch is resolved per file by the backend (Step matched from file name), so splitting per file does not change results.

## Decision 3 — Queue state in a module-level store
- **Rationale**: FR-010 requires the batch to keep running after the form popup closes and the popup to be reopenable; the form dialog component closes/resets, so state cannot live there. A tiny store with `subscribe` (used via `useSyncExternalStore`) is enough; no new dependency.
- **Alternatives**: React context at app root (broader change); component state in each page (duplicated 3 times).

## Decision 4 — Host component mounted in each of 3 pages
- `EutrUploadProgressHost` renders the progress dialog, a small "Uploading n/m" chip while running with the popup closed, and a finish notification (done/failed counts) with a "View" action (FR-010a). Each page passes `onBatchFinished` to refresh its data (FR-011).

## Decision 5 — Client-side rejected files
- Files failing the existing extension/20MB check are added to the batch as Failed rows (reason from existing message) and are not sent (FR-007). Retry skips these (they cannot succeed without re-selecting).

## Decision 6 — Retry
- "Retry failed" re-queues items that failed **after being sent**; items stay in the same batch. Data lost on page leave (spec Assumptions).

## Decision 7 — Leave-page warning
- While a batch runs, register a `beforeunload` handler (browser-level warning). In-app route changes are not blocked beyond this (acceptable; documented limitation).
