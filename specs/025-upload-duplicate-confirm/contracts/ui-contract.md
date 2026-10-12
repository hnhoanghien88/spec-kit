# UI / Interface Contract (delta over `021` ui-contract)

## Store API (`application/eutr-upload/eutrUploadQueueStore.js`)
- `startBatch({ files, rejected, uploadFile, existingNames?, onFinished })` — `existingNames`: Set of lower-cased file names flagged by the pre-check; matching files start as `awaiting`.
- `decideItem(key, 'upload' | 'skip')`, `decideAll('upload' | 'skip')` — only affect `awaiting` items; `upload` → `waiting` + `confirmed`, starts the runner if idle; `skip` → `skipped`.
- `getSummary(batch)` adds `skipped`, `awaiting`; `remaining` includes awaiting.
- Runner order: `waiting && !confirmed` first, then `waiting && confirmed`. Batch is finished only when nothing is waiting/uploading/awaiting.

## Progress dialog (`EutrUploadProgressHost`)
- Summary: `X done · Y failed · Z skipped · W remaining (N total)`.
- `awaiting` row: chip "Awaiting confirmation" (warning), text "File already exists on this PO", buttons **Upload** / **Skip**.
- Actions: **Upload all** / **Skip all** (visible while any `awaiting`), **Retry failed**, **Close**.
- Dialog closed while `pending`: floating chip "Confirm n file(s)" reopens it; snackbar/notification fires only on full finish.
- Status labels: Waiting / Uploading / Awaiting confirmation / Done / Failed / Skipped (same in 004, 005, 012).
