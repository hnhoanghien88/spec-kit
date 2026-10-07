# UI / Interface Contract

## Backend (unchanged, reused)
- `POST /api/sharepoint/eutr-upload-multi` (Type = PO) and `POST /api/sharepoint/eutr-upload-multi-by-type` — called with **exactly one file** per request. Response `data` = array with one `{ fileName, success, errorMessage }`. A thrown/HTTP error is treated as the file's failure (reason = server message or "Failed to upload files").

## Store API (`application/eutr-upload/eutrUploadQueueStore.js`)
- `startBatch({ files, rejected, uploadParams, onFinished })` → creates batch, opens popup, starts sequential runner.
- `retryFailed()`; `setPopupOpen(bool)`; `dismissNotification()`; `getSnapshot()`; `subscribe(fn)`.
- Only one batch runs at a time; `startBatch` while running is refused (FR-010).

## Host component
`<EutrUploadProgressHost onBatchFinished={() => refresh()} />` — renders:
- Progress dialog: title "Upload files", summary "X done · Y failed · Z remaining", list rows (name, size, status chip, error text), actions: **Retry failed** (only if retryable failures and not running), **Close**.
- While running and dialog closed: chip "Uploading n/m" that reopens the dialog.
- After finish with dialog closed: snackbar "X done, Y failed" with **View** action.

## Status labels
Waiting / Uploading / Done / Failed (same in all 3 screens).
