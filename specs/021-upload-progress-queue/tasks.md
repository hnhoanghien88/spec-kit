# Tasks: Multi-File Upload Progress Queue

**Input**: `/specs/021-upload-progress-queue/` (plan.md, spec.md, research.md, data-model.md, contracts/ui-contract.md)
All paths are under `compliance-client/src/`. Tests: none requested (manual per quickstart.md).

## Phase 1: Foundation (blocks all stories)

- [X] T001 Create `application/eutr-upload/eutrUploadQueueStore.js`: module-level store (state per data-model.md, `subscribe`/`getSnapshot`, `startBatch`, sequential runner calling `uploadToSharePointUseCase.executeEutrMulti` / `executeEutrMultiByType` with ONE file per call, mapping result `{success, errorMessage}` or thrown error to done/failed, `onFinished` callback, one running batch at a time, `beforeunload` guard while running)

## Phase 2: User Story 1 + 2 — live status, failures skipped (P1) 🎯 MVP

- [X] T002 [US1] Create `presentation/pages/eutr-documents/components/EutrUploadProgressHost.jsx`: progress dialog (rows with name/size/status chip/error, summary counts, Close), running chip that reopens the dialog, finish snackbar with "View" (FR-010a); uses `useSyncExternalStore`; prop `onBatchFinished`
- [X] T003 [US1,US2] Edit `EutrDocumentsFormDialog.jsx` `handleFilesSelected`: keep extension/20MB validation but pass rejected files to `startBatch` as failed rows (non-retryable); build `uploadParams` snapshot; call `startBatch`, then `onClose`; remove the single multipart call and aggregate snackbar message; refuse when a batch is already running
- [X] T004 [P] [US1] Mount `<EutrUploadProgressHost onBatchFinished={fetchData} />` in `eutr-documents/index.jsx`
- [X] T005 [P] [US1] Mount host in `eutr-sales-orders/MapFilePage.jsx` with that page's existing refresh function
- [X] T006 [P] [US1] Mount host in `eutr-purchase-orders/PurchaseOrderViewPage.jsx` with that page's existing refresh function

## Phase 3: User Story 3 — Retry failed (P2)

- [X] T007 [US3] Add `retryFailed()` to the store (only retryable failed items → waiting, restart runner) and a "Retry failed" button in the host dialog (hidden when none/while running)

## Phase 4: Polish

- [X] T008 Run `npm run build` (and lint if configured) in `compliance-client`; fix errors
- [X] T009 Build passes (`npm run build`). Manual quickstart scenarios NOT run — require live env (API + SharePoint).
