# Quickstart: PO Upload Folder Grouping

## Prerequisites

- `compliance-sys-api` running locally (or against the Dev SharePoint site configured via
  `SharePointEutrPath` in `appsettings.Development.json`, e.g. `Dev/Eutr`).
- A valid auth token for a user allowed to call `SharePointController` endpoints.
- A PO code that does **not** yet have any uploaded documents, to observe folder creation from
  scratch (e.g. pick an unused code such as `PO999001`).

## Validate User Story 1 — new PO gets nested under "PO"

1. Upload a document for `PO999001` via either:
   - `POST /api/sharepoint/eutr-upload-multi` with `poCode=PO999001` and a valid file, or
   - the 004-eutr-documents Add/Edit popup in the UI with Type = "PO", PO code `PO999001`.
2. In SharePoint (or via `GET /api/sharepoint/get-folders?folderPath={SharePointEutrPath}`), confirm
   a folder named `PO` now exists directly under the configured root.
3. Via `GET /api/sharepoint/get-folders?folderPath={SharePointEutrPath}/PO`, confirm a folder named
   `PO999001` exists nested inside it, and that the uploaded file is inside
   `{SharePointEutrPath}/PO/PO999001`.
4. Confirm the response `ApiResponse<List<EutrUploadFileResultDto>>` still reports `success: true`
   for the uploaded file (contract unchanged — see `contracts/upload-endpoints.md`).

## Validate User Story 2 — repeat upload reuses the nested folder

1. Upload a second document for the same `PO999001` code.
2. Confirm no duplicate `PO` or `PO999001` folder is created — the file simply lands alongside the
   first one inside `{SharePointEutrPath}/PO/PO999001`.

## Validate User Story 3 — Sales Orders and Purchase Orders screens

1. From the Sales Orders overview screen (`005-eutr-sales-orders`), upload a Type = PO document for
   a PO code and confirm it appears in the document list and downloads successfully.
2. From the Purchase Orders screen (`012-eutr-purchase-orders`), do the same for a different PO
   code.
3. Both should resolve to `{SharePointEutrPath}/PO/{PoCode}` per Decision 1 in `research.md` — no
   screen-specific folder logic exists to verify separately.

## Validate the discovered dependency — missing-PO-folder alert stays accurate

1. Trigger `EutrSynchronizeDataService.SendPurchaseMissingAlertAsync` (feature
   `011-eutr-synchronize-data` / `018-compl-group-email-dk-alert`'s scheduled job, or its manual
   trigger endpoint if one exists) for a PO code that now has a nested `PO/{PoCode}` folder.
2. Confirm that PO is **not** flagged as "Have no PO folder" — i.e. the alert correctly reads
   `{SharePointEutrPath}/PO` rather than `{SharePointEutrPath}` when checking for an existing
   folder (see `data-model.md` "Read-side impact").

## Automated tests

- `compliance-sys-api/tests/ComplianceSysApi.UnitTests/Services/EutrUploadServiceTests.cs` (new):
  mock `ISharepointService.GetFolders`/`CreateFolder` and assert the two-step resolve/create
  sequence (`PO` group folder, then `{PoCode}` inside it) for both
  `UploadMultipleToSharePointAndSaveDataAsync` and the `"po"` branch of
  `UploadMultipleForReferenceTypeAsync`; assert non-PO Types are unaffected.
- `compliance-sys-api/tests/ComplianceSysApi.UnitTests/Services/EutrSynchronizeDataServiceTests.cs`
  (update existing `GetFolders` mocks/assert calls to target `{basePath}/PO`): re-run the existing
  "Have no PO folder" and "have folder" scenarios to confirm they still pass against the nested
  path.
- `dotnet test compliance-sys-api/tests/ComplianceSysApi.UnitTests` should pass with 0 regressions.
