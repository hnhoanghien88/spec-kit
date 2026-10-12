# Data Model: Duplicate File Confirmation on PO Upload

No database change (no new table/column/SP, no migration). Existing tables are only read:
`eutr_documents` (Name), `eutr_references` (DocumentId, RefType, RefValue), `eutr_steps` (Name).

## Client-side: Upload Item (extends `021`, in `eutrUploadQueueStore.js`)

| Field | Type | Notes |
|---|---|---|
| key, file, name, size | as `021` | |
| status | `waiting` \| `uploading` \| `done` \| `failed` \| **`awaiting`** \| **`skipped`** | exactly one state (FR-008) |
| exists | boolean | true when the pre-check flagged the file |
| confirmed | boolean | true after the user chose Upload; runner processes `waiting && !confirmed` first |
| error, retryable | as `021` | |

### State transitions
```
(not exists)  waiting ─► uploading ─► done | failed ─(retry)─► waiting
(exists)      awaiting ─Upload─► waiting(confirmed) ─► uploading ─► done | failed
              awaiting ─Skip──► skipped (terminal)
```
`failed` items never return to `awaiting` (retry does not re-prompt).

### Batch (extends `021`)
- `pending` (derived): any item `awaiting`.
- Finished ⇔ no `waiting`/`uploading` and not `pending`.
- Summary adds `skipped` and `awaiting` counts; `remaining` = waiting + uploading + awaiting.

## Server-side DTOs (transient, not persisted)

- **EutrDocumentsCheckExistingFilesRequestDto**: `TypeId` (long), `StepId` (long?, required for non-PO Types to compute the renamed name), `RefValues` (List<string>), `FileNames` (List<string>).
- **Response**: `List<string>` — the subset of `FileNames` (as sent, original casing) that already exist.
