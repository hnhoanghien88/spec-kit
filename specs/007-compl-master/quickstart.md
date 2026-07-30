# Quickstart: Validate Compliance Master Alert Type

## Prerequisites

- Backend (`compliance-sys-api`) running locally against a MySQL DB where `compl_masters.AlertType` column already exists.
- The DB's live `compl_sp_get_compl_master_paging` and `compl_sp_get_compl_master_by_id` stored procedures have been updated to select `AlertType`, as a plain `TINYINT` (see `data-model.md` / `research.md` R4/R4b) — otherwise Alert type will always read back as blank/0 (or worse, silently wrong for "Expired") regardless of what was saved.
- Frontend (`compliance-client`) running (`npm run dev` or project's usual dev script) pointed at that backend, logged in as a user with `ComplianceMaster.Create` and `ComplianceMaster.Update` permissions.
- For the list scenarios (6-8): at least a few Compliance Masters exist with different Alert type values (All / Missing / Expired), and at least one predating the Alert type feature (or with no explicit value set), to check the fallback.

## Scenario 1 — Create with default Alert type

1. Navigate to `compliance-master/new`.
2. Confirm an "Alert type" field is visible directly below the "Description" field, showing "All" by default.
3. Fill in the other required fields (Master Name, Valid From/To, Responsible for, Alert for, Description, at least one condition) and Save.
4. Reopen the created master at `compliance-master/{id}` and confirm "Alert type" still shows "All".

**Expected**: New master persists with Alert type = All (0) without the user touching the field.

## Scenario 2 — Create with a non-default Alert type

1. Navigate to `compliance-master/new`.
2. Change "Alert type" to "Missing" (or "Expired").
3. Fill in the other required fields and Save.
4. Reopen the created master and confirm "Alert type" shows the chosen value.

**Expected**: Selected value round-trips through create → reload exactly.

## Scenario 3 — Edit an existing master's Alert type

1. Open an existing, editable Compliance Master at `compliance-master/{id}`.
2. Confirm "Alert type" shows its currently saved value, below Description.
3. Change it to a different option and Save.
4. Reload the same master.

**Expected**: New value is shown; matches what was saved.

## Scenario 4 — View-only / disabled state

1. Open a Compliance Master that is either replaced by a newer version, or view it as a user without Update permission.
2. Confirm "Alert type" is visible but not editable (same disabled treatment as the rest of the form's fields, e.g. Description).

**Expected**: Field is read-only, consistent with the rest of the form.

## Scenario 5 — Pre-existing record without a stored value (form)

1. Using a master created/persisted before this feature shipped (or a row where `AlertType` is NULL/unset at the DB level), open it for view/edit.

**Expected**: "Alert type" displays "All", never blank.

## Scenario 6 — List column appears in the right place

1. Navigate to the Compliance Master list.
2. Confirm a column labeled "Alert type" appears directly after the "Status" column.

**Expected**: Column is visible without needing to open the column-visibility picker.

## Scenario 7 — List shows the correct label per row

1. In the list, locate masters known to have Alert type "Missing" and "Expired" (e.g. ones set via Scenario 2/3 above).
2. Confirm their "Alert type" cell shows "Missing" / "Expired" respectively.
3. Locate a master with Alert type "All" (the default).
4. Confirm its cell shows "All".

**Expected**: Label matches the value set on each master, using exactly the words "All", "Missing", "Expired" — never a raw number.

## Scenario 8 — List: pre-existing record without a stored value

1. Find (or simulate) a master row where `alertType` is `null`/`undefined`.
2. Confirm its "Alert type" cell shows "All" rather than blank.

**Expected**: No blank cells in this column, ever.

## Regression check

- Existing paged list (`compliance-master` grid) and detail view still load without error for masters saved before this change.
- Save flow for a master with no changes to Alert type (i.e., user never touches it) still submits `alertType` and does not regress any existing required-field validation (Master Name, Valid From/To, Responsible for, Alert for, Description, at least one condition).
- Sorting, filtering, and paging the list still work as before for all other columns.
- The "Status" column's own appearance/behavior is unchanged.
