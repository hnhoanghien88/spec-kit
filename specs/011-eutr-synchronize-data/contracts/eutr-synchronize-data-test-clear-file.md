# Contract: `GET /api/eutr-synchronize-data/test-clear-file`

New action on the existing `EutrSynchronizeDataController` (same `[Authorize]`, same `ApiResponse<T>`
wrapping). Destructive on SharePoint only (spec User Story 4, Update 1).

## Request
```
GET /api/eutr-synchronize-data/test-clear-file
Authorization: Bearer <token>
```
No parameters.

## Behavior
1. List all files (any depth) under configuration `SharePointEutrPath` (research R25).
2. Read all non-blank `eutr_documents.FileId` values (R26).
3. Delete each SharePoint file whose id is not in that set; keep the rest. Folders untouched.
4. Any failure in steps 1–2 → `success=false`, nothing deleted. Per-file delete failure → counted, continue.

## Response (200)
```json
{ "success": true, "message": "...", "data": {
  "filesExamined": 10, "filesKept": 7, "filesDeleted": 3, "filesFailed": 0,
  "success": true, "message": "..." } }
```
