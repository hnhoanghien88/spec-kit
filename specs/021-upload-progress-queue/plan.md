# Implementation Plan: Multi-File Upload Progress Queue

**Branch**: `021-upload-progress-queue` (no git branch created) | **Date**: 2026-10-07 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/021-upload-progress-queue/spec.md`

## Summary

Add a per-file upload queue with a live progress popup to the Upload flow of the shared popup `EutrDocumentsFormDialog`, which is the single entry point used by `004-eutr-documents`, `005-eutr-sales-orders` (`MapFilePage`) and `012-eutr-purchase-orders` (`PurchaseOrderViewPage`). Approach: **frontend-only**. Instead of sending all selected files in one multipart request, the client sends files **one request per file** (sequentially) to the existing endpoints `eutr-upload-multi` / `eutr-upload-multi-by-type` (each already returns a per-file result array and isolates per-file errors). A small module-level queue store holds batch state so it survives the form popup closing; a new progress dialog + running indicator render from that store and are mounted once in each of the 3 pages.

## Technical Context

**Language/Version**: JavaScript (React 18 + Vite, MUI) in `compliance-client/`.

**Primary Dependencies**: existing `@mui/material`, `UploadToSharePointUseCase`, `RestSharePointRepository` (axios). No new packages.

**Storage**: N/A on client (state in memory only, lost on page leave — per spec Assumptions). No backend/DB/SQL change, so no migration file is needed.

**Testing**: Manual verification per [quickstart.md](quickstart.md) plus `npm run build`/lint in `compliance-client`; the repo has no client unit-test setup for these pages.

**Target Platform**: Web (desktop browsers).

**Project Type**: web-app (React frontend over existing .NET API; API untouched).

**Performance Goals**: Popup lists all files within 1s of pressing Upload (rows are created synchronously from the selected files before any request).

**Constraints**: Files processed **sequentially (concurrency 1)** to avoid races when the backend creates the same SharePoint folder (e.g., `PO/<PoCode>`) for several files of one batch; the existing 20MB / extension validation stays client-side and now yields "Failed" rows instead of a single snackbar; backend request size limits per file are smaller than before, so no new limit.

**Scale/Scope**: ≤ 20 files per batch; 1 new store, 1 new dialog component, 1 new hook, edits to `EutrDocumentsFormDialog` and the 3 host pages.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- I. Layered architecture — PASS: queue logic in `application/` (store/use case), UI in `presentation/`; the existing use case/repository are reused, no layer inversion.
- II. Reference-pattern reuse — PASS (N/A): not a new CRUD feature; extends an existing shared dialog.
- III. Reuse existing backend — PASS: no backend change; existing endpoints reused as-is (single-file calls).
- IV. Vietnamese comments; labels — PASS: code comments in Vietnamese; UI text in English to match the existing Upload popup text ("Uploading...", "Failed to upload files"), consistent with the current dialog. Stated here per principle.
- V. Routing/menu — PASS (N/A): no new screen/route.

Post-design re-check: unchanged, all PASS.

## Project Structure

### Documentation (this feature)

```text
specs/021-upload-progress-queue/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/ui-contract.md
└── tasks.md
```

### Source Code

```text
compliance-client/src/
├── application/
│   └── eutr-upload/
│       └── eutrUploadQueueStore.js        # NEW: batch/item state, sequential runner, retry, subscribe
└── presentation/pages/
    ├── eutr-documents/components/
    │   ├── EutrDocumentsFormDialog.jsx    # EDIT: validate -> enqueue batch, close popup
    │   └── EutrUploadProgressHost.jsx     # NEW: progress dialog + "running" indicator/notification
    ├── eutr-documents/index.jsx           # EDIT: mount host, refresh on batch done
    ├── eutr-sales-orders/MapFilePage.jsx  # EDIT: mount host, refresh on batch done
    └── eutr-purchase-orders/PurchaseOrderViewPage.jsx  # EDIT: same
```

**Structure Decision**: Frontend-only change in `compliance-client` (separate nested git repo). A module-level store (not React state in the form dialog) is required so the batch continues after the form popup closes (spec FR-010).

## Complexity Tracking

No constitution violations.
