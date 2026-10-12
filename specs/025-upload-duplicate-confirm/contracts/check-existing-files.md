# Contract: Check existing files

## `POST /api/eutr-documents/check-existing-files`

Authorization: policy `EutrDocuments.ReadAll` (same as `list-po-references` / `po-template-step-ids`).

### Request body
```json
{
  "typeId": 1,
  "isPoType": true,
  "stepId": null,
  "stepName": null,
  "refValues": ["PO-0001"],
  "fileNames": ["A.pdf", "B.xml"]
}
```
- `typeId`: reference-type id of the batch (Type = "PO" resolves to the PO type).
- `isPoType`: true when Type = "PO" (stored name = original name).
- `stepId` + `stepName`: required when Type ≠ "PO" (used to compute the Step-based stored file name); ignored for "PO".
- `refValues`: PO codes / chip values the upload targets (documents referencing ANY of them count).
- `fileNames`: original selected file names (≤ 20).

### Response `200`
```json
{ "success": true, "message": "...", "data": ["A.pdf"] }
```
`data` = the subset of `fileNames` (original casing) whose effective stored name (case-insensitive, extension included) equals the `Name` of an existing document that has an `eutr_references` row with `RefType = typeId` and `RefValue ∈ refValues`.

### Rules
- Empty `fileNames` or `refValues` → `data: []`.
- Read-only; no side effects.
- Errors → standard `ApiResponse.Fail`; the client fails open (treats as no duplicates).
