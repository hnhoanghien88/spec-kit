# Implementation Plan: Duplicate File Confirmation on PO Upload

**Branch**: `025-upload-duplicate-confirm` (no git branch created) | **Date**: 2026-10-12 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/025-upload-duplicate-confirm/spec.md`

## Summary

Extend the upload queue of `021-upload-progress-queue` so that a file whose name + extension already exists on the target PO is held in a new **Awaiting confirmation** state until the user picks **Upload** or **Skip**, while all other files keep uploading; confirmed files are processed after the non-duplicate files. Approach: (1) one small **read-only backend endpoint** `POST /api/eutr-documents/check-existing-files` that returns which of the given file names already exist for the given reference values; (2) the client calls it once per batch (in `EutrDocumentsFormDialog.handleFilesSelected`, before `startBatch`) and passes the flagged files to the queue store; (3) the store gets two new statuses (`awaiting`, `skipped`), a confirm/skip API and a second-pass runner; (4) `EutrUploadProgressHost` shows the warning + per-file Upload/Skip buttons + "Upload all"/"Skip all". Because the three screens share `EutrDocumentsFormDialog` and `EutrUploadProgressHost`, one change covers 004, 005 and 012 (FR-013).

## Technical Context

**Language/Version**: JavaScript (React 18 + Vite, MUI) in `compliance-client/`; C# / .NET 8 in `compliance-sys-api/`.

**Primary Dependencies**: existing `@mui/material`, `UploadToSharePointUseCase`, `eutrDocumentsApi`; backend `EutrDocumentsService`, `IEutrReferencesRepository`. No new packages.

**Storage**: No schema change, no new table, no SP change → no migration file. The check reads existing `eutr_documents` (Name) joined through `eutr_references` (RefValue, RefType) via the already existing `GetDocumentsByPoCodesAsync`.

**Testing**: Backend: xUnit unit test for the new service method (`ComplianceSysApi.UnitTests`). Frontend: manual verification per [quickstart.md](quickstart.md) plus `npm run build`/lint (no client unit-test setup for these pages).

**Target Platform**: Web (desktop browsers) + REST API.

**Project Type**: web-app (React frontend over .NET API).

**Performance Goals**: duplicate check is one request per batch (≤ 20 names); popup still lists all files within 1s (rows are created before/while the check runs; the check must not delay non-flagged uploads noticeably — see research D3).

**Constraints**: Upload of a single file keeps using the unchanged endpoints `eutr-upload-multi` / `eutr-upload-multi-by-type` (sequential, one file per request). Duplicate comparison must use the **effective stored file name**: for Type = "PO" the original file name; for other Types the Step-based renamed name (`{StepName}{ext}`), mirroring `EutrUploadService.BuildRenamedFileName`.

**Scale/Scope**: ≤ 20 files per batch; 1 backend endpoint + service method + DTOs + unit test; edits to 1 store, 1 host component, `EutrDocumentsFormDialog`, `eutrDocumentsApi`, and a use case/repository method for the check. The 3 host pages need no change (they already mount `EutrUploadProgressHost`).

## Constitution Check

- I. Layered architecture — PASS: endpoint in Api → service in Application → existing repository in Infrastructure; client: api client → repository → use case → presentation; queue logic stays in `application/eutr-upload`.
- II. Reference-pattern reuse — PASS (N/A): not a new CRUD feature.
- III. Reuse existing backend — PASS with a verified gap: no existing endpoint can tell, per file name, whether it already exists for a reference (research D1); only one read-only endpoint is added, existing upload endpoints and rules are untouched.
- IV. Vietnamese comments; labels — PASS: code comments in Vietnamese; UI text in English to match the existing Upload popup ("Waiting", "Uploading", "Done", "Failed"), stated here per principle.
- V. Routing/menu — PASS (N/A): no new screen/route.

Post-design re-check: unchanged, all PASS.

## Project Structure

### Documentation (this feature)

```text
specs/025-upload-duplicate-confirm/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── check-existing-files.md
│   └── ui-contract.md
└── tasks.md
```

### Source Code

```text
compliance-sys-api/src/
├── ComplianceSys.Api/Controllers/EutrDocumentsController.cs            # EDIT: POST check-existing-files
├── ComplianceSys.Application/
│   ├── Dtos/Request/EutrDocumentsCheckExistingFilesRequestDto.cs       # NEW
│   ├── Interfaces/Services/IEutrDocumentsService.cs                    # EDIT: CheckExistingFileNamesAsync
│   └── Services/EutrDocumentsService.cs                                # EDIT: implement (+ shared file-name rule)
└── (tests) ComplianceSysApi.UnitTests/Services/EutrDocumentsServiceCheckExistingTests.cs  # NEW

compliance-client/src/
├── infrastructure/api/eutrDocumentsApi.js                              # EDIT: checkExistingFiles
├── infrastructure/repositories/ + domain/ + application/usecases/      # EDIT/NEW: CheckExistingEutrFilesUseCase
├── application/eutr-upload/eutrUploadQueueStore.js                     # EDIT: awaiting/skipped, decide, 2nd pass
└── presentation/pages/eutr-documents/components/
    ├── EutrDocumentsFormDialog.jsx                                     # EDIT: call check, pass flagged names
    └── EutrUploadProgressHost.jsx                                      # EDIT: warning + Upload/Skip UI
```

**Structure Decision**: Backend gets a single read-only query; all flow logic (hold, confirm, second pass) lives in the existing module-level queue store so it survives popup close (FR-010).

## Complexity Tracking

No constitution violations.
