# Data Model: PO Upload Folder Grouping

No MySQL schema changes. This feature only changes the SharePoint *storage path* used for Type = PO
uploads — there is still no PO↔folder mapping table (unchanged from `004-eutr-documents` research
Quyết định 13; see [research.md Decision 1](./research.md#decision-1--where-the-fix-lives)).

## Key Entity: PO Document Folder

Conceptual entity, not a database table — a SharePoint folder path derived at request time.

| Field | Before this feature | After this feature |
|---|---|---|
| Path pattern | `{SharePointEutrPath}/{PoCode}` | `{SharePointEutrPath}/PO/{PoCode}` |
| Example | `Sandbox/Eutr/PO000123` | `Sandbox/Eutr/PO/PO000123` |
| Created by | `EutrUploadService.ResolveOrCreatePoFolderAsync(basePath, folderName)` (1 call) | Same helper, called twice: once to resolve/create the shared `PO` group folder under `basePath`, once to resolve/create `{PoCode}` under the group folder |
| Applies to | `UploadMultipleToSharePointAndSaveDataAsync` (PO screen) and the `"po"` branch of `UploadMultipleForReferenceTypeAsync`'s `ResolveFolderName` (unified Add/Edit popup) | Same two call sites |
| Read by | `EutrSynchronizeDataService.SendPurchaseMissingAlertAsync` via `GetFolders(basePath)` matching `folder.Name == PoCode` | `GetFolders($"{basePath}/PO")` matching `folder.Name == PoCode` |

## Derivation algorithm (updated from 004's Quyết định 13)

1. `basePath = configuration["SharePointEutrPath"]`.
2. `poGroupFolder = ResolveOrCreatePoFolderAsync(basePath, "PO")` — resolves or creates the shared
   `PO` folder directly under `basePath`.
3. `targetFolder = ResolveOrCreatePoFolderAsync(poGroupFolder, poCode)` — resolves or creates the
   PO-code folder nested inside the `PO` folder.
4. Upload each valid file into `targetFolder`, exactly as before (unique-name suffixing unchanged).
5. Still no MySQL table maps PO ↔ folder; resolution happens live against SharePoint on every call,
   for both the group folder and the PO-code folder.

This algorithm applies identically whether the upload arrived through
`POST /api/sharepoint/eutr-upload-multi` (`request.PoCode`) or through
`POST /api/sharepoint/eutr-upload-multi-by-type` with `TypeName` normalizing to `"po"`
(`RefValues[0]`) — both funnel through the same two-step resolution.

## Non-PO Types (unchanged)

Vendor, Invoice, Delivery note, General agreement, and any other reference Type keep the original
single-step derivation — `ResolveOrCreatePoFolderAsync(basePath, folderName)` — with no `PO` group
folder involved, per FR-005.

## Read-side impact: existing-folder detection

`EutrSynchronizeDataService.SendPurchaseMissingAlertAsync` (feature `011-eutr-synchronize-data`,
consumed by `018-compl-group-email-dk-alert`) builds `existingFolderNames` from
`GetFolders(basePath)` to decide whether a given PO already has a folder. This MUST read from
`GetFolders($"{basePath}/PO")` instead, so PO codes nested under the new `PO` group folder are still
recognized as "has a folder" (see [research.md Decision 3](./research.md#decision-3--eutrsynchronizedataservice-must-move-in-lockstep-discovered-dependency)).
Pre-existing flat folders (created before this feature ships) are intentionally NOT covered by this
lookup going forward — acceptable per FR-007/Assumptions, since a PO with an old flat folder already
has documents and this alert only flags *missing* folders.

## Non-goals

- No migration of documents already sitting in old flat `<PoCode>` folders (FR-007).
- No change to non-PO Type folder structure (FR-005).
- No new database table, column, or migration file (no entry needed under `Sqls/Migration/`).
