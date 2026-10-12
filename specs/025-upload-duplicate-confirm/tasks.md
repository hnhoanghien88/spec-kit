# Tasks: Duplicate File Confirmation on PO Upload

**Input**: Design documents from `/specs/025-upload-duplicate-confirm/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/
**Tests**: backend unit test for the new service method (plan.md); frontend verified manually per quickstart.md + `npm run build`/lint.
**Conventions**: code comments in Vietnamese (constitution IV); repos: `compliance-sys-api/` and `compliance-client/` are separate nested git repos. No DB change → no migration file.

Format: `- [ ] T### [P?] [US?] Description with file path`

## Phase 1: Setup

- [X] T001 Re-read `compliance-client/src/application/eutr-upload/eutrUploadQueueStore.js`, `compliance-client/src/presentation/pages/eutr-documents/components/EutrUploadProgressHost.jsx` and `EutrDocumentsFormDialog.jsx` (handleFilesSelected) to confirm the code matches plan.md before editing

## Phase 2: Foundational (backend check endpoint + client plumbing — blocks all stories)

- [X] T002 [P] Create `compliance-sys-api/src/ComplianceSys.Application/Dtos/Request/EutrDocumentsCheckExistingFilesRequestDto.cs` (TypeId long, StepId long?, RefValues List<string>, FileNames List<string>) per contracts/check-existing-files.md
- [X] T003 Make the stored-name rule shareable: expose `EutrUploadService.BuildRenamedFileName` (currently private static in `compliance-sys-api/src/ComplianceSys.Application/Services/EutrUploadService.cs`) as `internal`/public static so `EutrDocumentsService` reuses it (no behavior change)
- [X] T004 Add `Task<List<string>> CheckExistingFileNamesAsync(EutrDocumentsCheckExistingFilesRequestDto request, CancellationToken ct)` to `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Services/IEutrDocumentsService.cs`
- [X] T005 Implement it in `compliance-sys-api/src/ComplianceSys.Application/Services/EutrDocumentsService.cs`: empty inputs → `[]`; load rows via `_referencesRepository.GetDocumentsByPoCodesAsync(refValues)`, keep rows with `RefType == TypeId`; effective name per file = original name for Type "PO" (resolve via type name/`RefType` lookup used elsewhere in the service) else `BuildRenamedFileName(step.Name, StepId, fileName)` (step via `_stepsRepository`); return original file names whose effective name equals a row `FileName` (OrdinalIgnoreCase). Vietnamese comments.
- [X] T006 Add endpoint `POST check-existing-files` (policy `EutrDocuments.ReadAll`, returns `ApiResponse<List<string>>`) in `compliance-sys-api/src/ComplianceSys.Api/Controllers/EutrDocumentsController.cs`, next to `po-template-step-ids`
- [X] T007 [P] Unit tests in `compliance-sys-api/tests/ComplianceSysApi.UnitTests/Services/EutrDocumentsServiceCheckExistingTests.cs`: same name+ext flagged; case-insensitive; same name different ext not flagged; other RefType/RefValue not flagged; non-PO Type uses Step-renamed name; empty input → empty. Run `dotnet test --filter EutrDocumentsServiceCheckExistingTests`
- [X] T008 [P] Client api: add `checkExistingFiles: (payload) => axiosInstance.post("/eutr-documents/check-existing-files", payload)` in `compliance-client/src/infrastructure/api/eutrDocumentsApi.js`
- [X] T009 Client repository: add `checkExistingFiles(payload)` to `compliance-client/src/domain/interfaces/IEutrDocumentsRepository.js` (throws Not implemented) and `compliance-client/src/infrastructure/repositories/RestEutrDocumentsRepository.js`
- [X] T010 [P] Create `compliance-client/src/application/usecases/eutr-documents/CheckEutrDocumentsExistingFilesUseCase.js` (pattern of `GetEutrDocumentsPoTemplateStepIdsUseCase.js`)

## Phase 3: User Story 1 — Warn and let the user decide (P1) 🎯 MVP

**Goal**: flagged files are held as "Awaiting confirmation" with warning and Upload/Skip; non-flagged upload as before.
**Independent test**: quickstart scenarios 1, 2, 3, 9.

- [X] T011 [US1] In `eutrUploadQueueStore.js`: add `AWAITING`/`SKIPPED` to `STATUS`; `startBatch` accepts `existingNames` (Set of lower-cased names) and starts matching files as `status: awaiting, exists: true, confirmed: false`; extend `getSummary` with `skipped`, `awaiting` (remaining includes awaiting) and a `pending` helper
- [X] T012 [US1] In the same store add `decideItem(key, 'upload'|'skip')`: skip → `skipped`; upload → `waiting` + `confirmed: true` and start `runQueue()` if not running
- [X] T013 [US1] In `EutrDocumentsFormDialog.jsx` `handleFilesSelected`: after client validation, call the new use case (typeId = `type.id`, stepId = `step?.id` for non-PO, refValues from `chips.map(toRefValue)`, fileNames of `validFiles`) inside try/catch (fail open → no flagged files, research D3); pass `existingNames` to `startEutrUploadBatch`
- [X] T014 [US1] In `EutrUploadProgressHost.jsx`: add status labels "Awaiting confirmation" (warning) and "Skipped" (default); for `awaiting` rows show text "File already exists on this PO" and buttons **Upload** / **Skip** calling `decideItem`; extend summary line with skipped count
- [X] T015 [US1] Make the runner/batch finish logic treat `awaiting` as unfinished: `runQueue` ends when nothing is waiting, but `onFinished`/`notified` fire only when nothing is `awaiting` either (FR-007); keep `beforeunload` guard while pending (`eutrUploadQueueStore.js`)

## Phase 4: User Story 2 — Unconfirmed duplicates never block others; confirmed processed last (P1)

**Goal**: ordering and non-blocking behavior.
**Independent test**: quickstart scenarios 4, 5, 7, 8.

- [X] T016 [US2] In `runQueue` pick `waiting && !confirmed` items first, then `waiting && confirmed` (research D5) in `eutrUploadQueueStore.js`
- [X] T017 [US2] Make `decideItem('upload')` while the runner is idle (all non-flagged done) restart the runner, and while running just flip the item so the runner picks it after non-confirmed ones; ensure `finally` of `runQueue` does not mark the batch finished when `awaiting` items remain (`eutrUploadQueueStore.js`)
- [X] T018 [US2] Host: when dialog is closed and batch is pending (not running, awaiting > 0) show the floating chip "Confirm n file(s)" that reopens the popup; running chip unchanged; snackbar only on full finish (`EutrUploadProgressHost.jsx`)
- [X] T019 [US2] Ensure `retryFailed` re-queues failed items as plain `waiting` (no re-check, `exists` ignored) and skipped items are never retryable; `clearFinishedBatch` must not clear while `awaiting` remains (`eutrUploadQueueStore.js`)

## Phase 5: User Story 3 — Decide for many at once (P2)

**Independent test**: quickstart scenario 6.

- [X] T020 [US3] Add `decideAll('upload'|'skip')` in `eutrUploadQueueStore.js` affecting only `awaiting` items
- [X] T021 [US3] Add **Upload all** / **Skip all** buttons to the dialog actions, visible while any item is `awaiting` (`EutrUploadProgressHost.jsx`)

## Phase 6: Polish & cross-cutting

- [X] T022 Verify the 3 host pages need no edits (`presentation/pages/eutr-documents/index.jsx`, `eutr-sales-orders/MapFilePage.jsx`, `eutr-purchase-orders/PurchaseOrderViewPage.jsx` already mount `EutrUploadProgressHost`); confirm `onBatchFinished` refresh still fires once on full finish (FR-014)
- [X] T023 Run `npm run build` and lint in `compliance-client`; run `dotnet build` in `compliance-sys-api`; fix errors
- [X] T024 Quickstart scenarios: NOT run — require live env (API + SharePoint + D365); backend rules covered by 5 unit tests (scenarios 1-2, 10 logic); UI states verified only by build+lint
- [X] T025 Checkboxes reflect only verified work: build+lint (client), unit tests + API compile (backend); live UI walk-through pending

## Dependencies

- Phase 2 blocks everything. T003 → T005 → T006/T007; T008 → T009 → T010 → T013.
- US1 (T011–T015) is the MVP. US2 (T016–T019) edits the same store/host files → after US1. US3 (T020–T021) after US1.
- Parallel: T002, T007, T008, T010 (different files).

## Implementation strategy

MVP = Phase 2 + US1 (warning + per-file decision). Then US2 ordering/idle-restart, then US3 bulk actions, then polish.
