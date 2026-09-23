# Research: PO Upload Folder Grouping

## Context recap

Today, uploading a Type = PO document creates a SharePoint folder named exactly after the PO code
(e.g. `PO000123`) directly under the configured root (`SharePointEutrPath`, e.g. `Sandbox/Eutr`).
The requested change nests every PO-code folder one level deeper, under a shared `PO` folder:

```
Sandbox/Eutr/PO/PO000123/
Sandbox/Eutr/PO/PO000124/
```

instead of today's:

```
Sandbox/Eutr/PO000123/
Sandbox/Eutr/PO000124/
```

No other Type's folder placement changes.

## Decision 1 — Where the fix lives

**Decision**: Implement the nesting entirely inside `EutrUploadService`
(`compliance-sys-api/src/ComplianceSys.Application/Services/EutrUploadService.cs`), reusing its
existing `ResolveOrCreatePoFolderAsync(basePath, folderName)` helper (line 342) twice in sequence
for the PO case instead of once.

**Rationale**: This service is the single owner of PO-folder resolution for both of its public
upload methods:
- `UploadMultipleToSharePointAndSaveDataAsync` (line 60, backs `POST
  /api/sharepoint/eutr-upload-multi`) — always a PO upload; calls
  `ResolveOrCreatePoFolderAsync(basePath, request.PoCode)` at line 66.
- `UploadMultipleForReferenceTypeAsync` (line 197, backs `POST
  /api/sharepoint/eutr-upload-multi-by-type`) — generic Type upload used by the unified Add/Edit
  popup; calls `ResolveFolderName(request.TypeName, request.RefValues)` then
  `ResolveOrCreatePoFolderAsync(basePath, folderName)` at lines 203-204. `ResolveFolderName` (line
  323) returns `refValues[0]` (the PO code) specifically when `typeName` normalizes to `"po"`.

Both `005-eutr-sales-orders` and `012-eutr-purchase-orders` were traced (see their `data-model.md`)
and confirmed to have **no independent folder-resolution logic** — they call these same two
endpoints unchanged. Fixing `EutrUploadService` once therefore satisfies FR-004 (all three
screens) without touching 005 or 012's own code.

**Alternatives considered**:
- *Duplicate/override logic per calling feature* — rejected: 005 and 012 have no upload code of
  their own to change; there is nothing to duplicate into, and doing so would violate Constitution
  Principle III (Reuse Existing Backend).
- *Store a PO↔folder mapping in MySQL* — rejected: 004's own research (Quyết định 13) already
  decided against this ("Không có bảng MySQL nào lưu ánh xạ PO ↔ thư mục"); introducing one now
  would be a much larger, unrequested change and contradicts the existing decision this feature
  must stay consistent with.

## Decision 2 — How to nest without duplicating the resolve/create logic

**Decision**: Introduce one constant, `PoGroupFolderName = "PO"`, and change the PO branch to
resolve/create the group folder first, then resolve/create the PO-code folder inside it:

```csharp
var poGroupFolder = await ResolveOrCreatePoFolderAsync(basePath, PoGroupFolderName);
var targetFolder = await ResolveOrCreatePoFolderAsync(poGroupFolder, request.PoCode);
```

`ResolveOrCreatePoFolderAsync` already takes an arbitrary `basePath` + `folderName` pair and calls
`_sharepointService.GetFolders(basePath)` to check for an existing child — passing the just-resolved
`poGroupFolder` path as the new `basePath` on the second call reuses the exact same
existence-check/create semantics with no new SharePoint API surface.

For `UploadMultipleForReferenceTypeAsync`, only the `"po"` branch of `ResolveFolderName` needs this
two-step resolution; every other Type (Vendor, Invoice, DeliveryNote, GeneralAgreement, other
Types) keeps its single-step `ResolveOrCreatePoFolderAsync(basePath, folderName)` call unchanged,
per FR-005.

**Alternatives considered**:
- *Build the nested path in one string (`$"{basePath}/PO/{poCode}"`) and call
  `ResolveOrCreatePoFolderAsync` once* — rejected: the existing helper's existence check
  (`GetFolders(basePath)` then match on immediate child `Name`) only checks one level; it cannot
  tell whether both `PO` and `PO/<PoCode>` already exist from a single call, so the `PO` folder
  itself might never get created, or the code would need a second, ad-hoc branch anyway. Two
  sequential calls to the existing helper are simpler and reuse it exactly as designed.

## Decision 3 — `EutrSynchronizeDataService` must move in lockstep (discovered dependency)

**Decision**: Update `EutrSynchronizeDataService.SendPurchaseMissingAlertAsync`
(`compliance-sys-api/src/ComplianceSys.Application/Services/EutrSynchronizeDataService.cs`, line
233) to list existing PO folders from `{basePath}/PO` instead of `{basePath}` directly.

**Rationale**: This service (feature `011-eutr-synchronize-data`, consumed by the missing-PO-folder
alert in `018-compl-group-email-dk-alert`) independently calls
`_sharepointService.GetFolders(basePath)` and treats each returned folder's `Name` as a PO code
(`existingFolderNames.Contains(p.Code)`, line 263) to decide whether a PO "has no PO folder" yet.
It was NOT named in the user's request (which listed 004/005/012) but shares the exact same
`SharePointEutrPath` root and the exact same flat-folder assumption. If left unchanged, every PO
that gets its new nested `PO/<PoCode>` folder would look like it has **no folder at all** to this
alert (a full regression of feature 018's "Have no PO folder" detection), because
`GetFolders(basePath)` would only ever see the single new `PO` child, never the PO codes nested
inside it. This is a verified gap, not scope creep — Constitution Principle III explicitly scopes
backend changes to "verified gaps only," and shipping the folder-nesting change without this fix
would introduce a regression the same day it ships.

**Alternatives considered**:
- *Leave `EutrSynchronizeDataService` unchanged and accept the regression, filing it as a separate
  bug* — rejected: the regression is immediate and 100% reproducible for every future PO upload
  once this feature ships; there is no reason to ship a known break when the fix is a one-line
  change to which path is listed.
- *Make `EutrSynchronizeDataService` list both `{basePath}` and `{basePath}/PO`, merging results*
  — rejected: unnecessary complexity: after this feature ships, no *new* PO folder will ever be
  created flat again, and FR-007 already accepts that pre-existing flat folders for POs that
  already have documents are out of scope for migration (a PO that already has a flat folder
  already has documents, so this alert — which only fires on *missing* folders — has no
  behavior-visible reason to also scan the old flat location).

## Decision 4 — No frontend changes

**Decision**: No `compliance-client` changes.

**Rationale**: Confirmed by tracing `RestSharePointRepository.js`, `EutrDocumentsFormDialog.jsx`,
`MapFilePage.jsx`, and `PurchaseOrderViewPage.jsx` — all pass `poCode`/`typeName`/`refValues`
through to the backend as opaque strings with zero client-side path construction. The nested vs.
flat folder layout is entirely a server-side storage detail invisible to the UI (which lists/
downloads documents by `DocumentId`/`FileId`, not by folder path).

## Decision 5 — Historical (pre-change) PO folders are not migrated

**Decision**: Confirmed as an explicit assumption in spec.md — existing flat `<PoCode>` folders for
POs that already have uploaded documents are left in place, untouched. No migration script is part
of this feature.

**Rationale**: Matches FR-007 and keeps the change minimal and safe (no bulk SharePoint
move/rename operations, which carry real risk of broken links if anything external references the
old path). Consistent with Decision 3's scope boundary above.
