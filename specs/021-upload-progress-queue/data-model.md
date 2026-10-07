# Data Model: Multi-File Upload Progress Queue

In-memory only (client). No database or API schema change.

## UploadBatch
| Field | Type | Notes |
|---|---|---|
| id | string | unique per Upload action |
| items | UploadItem[] | in selection order |
| uploadParams | object | snapshot of Type/Step/Value/ValidFrom/ValidTo/Invoice at press time (`isPoType`, `typeId`, `typeName`, `stepId`, `refValues`, `validFrom`, `validTo`, `invoice`) |
| running | boolean | true while the runner is processing |
| popupOpen | boolean | progress popup visibility (independent of `running`) |
| notified | boolean | finish notification shown/dismissed |
| onFinished | function? | page callback to refresh data (FR-011) |

Derived summary: `total`, `done`, `failed`, `remaining` (= waiting + uploading); always computed from items (FR-003).

## UploadItem
| Field | Type | Notes |
|---|---|---|
| key | string | `${index}-${file.name}` (duplicates allowed) |
| file | File | kept for retry |
| name, size | string, number | display |
| status | `waiting` \| `uploading` \| `done` \| `failed` | exactly one at a time |
| error | string? | failure reason |
| retryable | boolean | false for client-side rejected files |

## State transitions
`waiting → uploading → done | failed`; `failed (retryable) → waiting` on Retry. Rejected files are created directly as `failed`, `retryable = false`.
