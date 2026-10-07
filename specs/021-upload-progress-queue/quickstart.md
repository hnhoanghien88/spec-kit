# Quickstart: Manual Verification

Prerequisites: API + client running; a user with Create permission on EUTR documents. Repeat on all three screens: Eutr Documents list, Sales Order map-file page, Purchase Order view page.

1. **20 files, all valid** (SC-001/002): open the Add popup, choose Type/Step/Value, press Upload, select 20 valid files. Expect the progress popup immediately with 20 rows; statuses move Waiting → Uploading → Done; summary counts always equal row counts. Refresh happens at the end.
2. **Failures skipped** (SC-003): include 1 `.exe`/`.txt` file, 1 file > 20MB, and (Type = PO) a file whose name matches no Step. Expect those rows Failed with reasons, all others Done and present in the list.
3. **All fail**: select only invalid files — all rows Failed, no document created.
4. **Retry** (SC-004): after step 2 fix the cause, press "Retry failed" — only retryable failed rows re-run; Done rows untouched, no duplicates. Rejected (client-side) rows are not retried.
5. **Close mid-upload** (FR-010/010a): close the popup while running — chip "Uploading n/m" appears, upload continues; on finish a snackbar shows counts with "View".
6. **Leave page mid-upload**: browser shows the leave warning.
7. **Single file**: same popup with 1 row.
8. **Consistency** (SC-005): same wording/states on the three screens.
9. `npm run build` in `compliance-client` passes.
