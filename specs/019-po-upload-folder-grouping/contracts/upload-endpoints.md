# Contracts: PO Upload Folder Grouping

No new endpoints. No request or response shape changes on any endpoint. This feature changes only
the **internal storage-path behavior** of two existing endpoints (both already documented in
`004-eutr-documents/contracts/eutr-documents-api.md`) and the **internal read behavior** of one
background job. All three keep their existing routes, policies, request bodies, and response
shapes verbatim.

## `POST /api/sharepoint/eutr-upload-multi`

`SharePointController.EutrUploadMultiToSharePointAndSaveData` →
`EutrUploadService.UploadMultipleToSharePointAndSaveDataAsync`

| Aspect | Before | After |
|---|---|---|
| Request shape | `EutrMultiUploadFileRequest` (unchanged) | unchanged |
| Response shape | `ApiResponse<List<EutrUploadFileResultDto>>` (unchanged) | unchanged |
| Storage path per PO code | `{SharePointEutrPath}/{PoCode}` | `{SharePointEutrPath}/PO/{PoCode}` |
| `eutr_documents`/`eutr_references` rows written | unchanged | unchanged |

## `POST /api/sharepoint/eutr-upload-multi-by-type` (Type = "PO" only)

`SharePointController.EutrUploadMultiByTypeToSharePointAndSaveData` →
`EutrUploadService.UploadMultipleForReferenceTypeAsync`

| Aspect | Before | After |
|---|---|---|
| Request shape | `EutrTypeMultiUploadFileRequest` (unchanged) | unchanged |
| Response shape | `ApiResponse<List<EutrUploadFileResultDto>>` (unchanged) | unchanged |
| Storage path when `TypeName` normalizes to `"po"` | `{SharePointEutrPath}/{RefValues[0]}` | `{SharePointEutrPath}/PO/{RefValues[0]}` |
| Storage path for every other `TypeName` (Vendor, Invoice, Delivery note, General agreement, other) | `{SharePointEutrPath}/{ResolveFolderName(...)}` | **unchanged** |

## Internal read: `EutrSynchronizeDataService.SendPurchaseMissingAlertAsync`

Not an HTTP contract change (no controller/route here) — internal SharePoint read used by feature
`018-compl-group-email-dk-alert`'s missing-PO-folder alert.

| Aspect | Before | After |
|---|---|---|
| Folders listed to detect "PO has a folder" | `GetFolders({SharePointEutrPath})`, matched by `folder.Name == PoCode` | `GetFolders({SharePointEutrPath}/PO)`, matched by `folder.Name == PoCode` |
| Alert output shape (`EutrPurchaseMissingSummaryDto`, `eutr_purchase_missing` rows) | unchanged | unchanged |

## Out of scope

- `GET /api/sharepoint/get-folders` and `POST /api/sharepoint/create-folder` (generic passthrough
  endpoints in `SharePointController`) are unaffected — they accept an explicit `folderPath`/
  `folder` from the caller and have no PO-specific behavior to change.
- Compl (non-EUTR) upload endpoints (`SharePointCompPath`-based) are unaffected — different config
  key, different service (`IComplUploadService`), out of scope per the user's request (only
  `004-eutr-documents`/`005-eutr-sales-orders`/`012-eutr-purchase-orders`, all of which route
  through `SharePointEutrPath`).
