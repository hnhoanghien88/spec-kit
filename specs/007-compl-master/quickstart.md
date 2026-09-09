# Quickstart: Validate Compliance Master Alert Type & Delete Fix

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

## Scenario 9 — Delete a master that previously failed (User Story 4)

Prerequisites: DB migration `26_fix_compl_master_delete_soft_delete.sql` applied; logged in as a user with `ComplianceMaster.Delete` permission.

1. Navigate to the Compliance Master list (e.g. `compliance-master?page=1&page-size=50`).
2. Find `MAS-01104` (or, if not available in this environment, any master with Status "Missing" that already has at least one linked/mapped compliance — see `research.md` R12 for how to identify one).
3. Trigger delete on that row and confirm.

**Expected**: The delete succeeds (success toast, no error). The master no longer appears in the list on reload (search/filter for its code to confirm). Repeat search after a hard refresh to confirm it doesn't reappear.

## Scenario 10 — Delete a master with no linked data still works

1. Find (or create and leave un-mapped) a Compliance Master with Status "Missing" and zero linked compliances.
2. Delete it and confirm.

**Expected**: Still succeeds, same as before this fix — this scenario guards against the fix accidentally breaking the already-working case.

## Scenario 11 — Bulk delete including a previously-failing master

1. In the list, multi-select several masters, including at least one in the state from Scenario 9 and at least one plain master.
2. Use the bulk-delete action and confirm.

**Expected**: All selected masters are deleted successfully; none remain in the list on reload.

## Scenario 12 — Deleting a non-existent master still 404s

1. Using an API client (or by deleting the same master id twice in quick succession / in two tabs), call `DELETE api/compliance-master/{id}` for an id that does not exist (or was already deleted).

**Expected**: `404 Not Found` with a clear message — unchanged from before this fix (see `contracts/compl-master-delete.md`).

## Regression check (User Story 4)

- A soft-deleted master is no longer returned by the paged list (`POST api/compliance-master/get-all`) or the list's `TotalCount`/badge.
- A soft-deleted master no longer triggers "missing compliance" alert notifications.
- `GET api/compliance-master/get-by-id/{id}` for a soft-deleted master's id still resolves (unchanged behavior, see `research.md` R14) — this is intentional, not a regression.
- Deleting/bulk-deleting masters that were already working before this fix (no linked data) continues to work exactly as before.
- No existing `compl_references`, `compl_master_conditions`, or `compl_master_group_email` rows are removed by a master delete — they simply become orphaned-but-inert once their parent master is soft-deleted, exactly as the equivalent `compl_compliances` soft-delete already behaves for its own linked data.

## Scenario 13 — Select Table logic for a Customer condition (User Story 5)

Prerequisites: logged in as a user with `ComplianceMaster.Update` permission; a master (e.g. `compliance-master/1021`, or any editable master) with at least one rule block under "Individual Rule Conditions (AND only)" or "CONDITIONS".

1. Open the master's detail screen and locate a rule block.
2. Add (or edit) a Customer condition in that block.
3. Open its Type selector.

**Expected**: "Table" is offered as an option, the same as it already is for Product Type.

## Scenario 14 — Table logic for Customer alongside another condition already using Table

1. In the same or another rule block, add a Product Type condition and set its Type to "Table"; select two or more product types.
2. In the same block, add (or edit) a Customer condition.
3. Open the Customer condition's Type selector.

**Expected**: "Table" is still offered for the Customer condition — it is not removed just because the Product Type condition in the same block already uses Table (this is the exact scenario the original request was blocked on).

4. Select "Table" for the Customer condition and pick 3+ customers (e.g. A, B, C).

**Expected**: No error; the selected customers accumulate in the condition's value list the same way Product Type's Table values do.

## Scenario 15 — Master Preview shows the Customer Table formula

1. With the Customer Table condition from Scenario 14 configured (customers A, B, C), view the "MASTER PREVIEW" panel on the same screen.

**Expected**: The Customer condition renders using the same presentation already used for the Product Type Table condition above it (or any existing Product Type Table condition elsewhere) — a header line (`Customer IN`) followed by one bulleted line per selected customer (`- code - name`). No different/new format appears for Customer specifically.

## Scenario 16 — Save and verify compliance evaluation reflects the Customer Table condition

1. Save the master from Scenario 14/15 (with both the Product Type Table condition and the Customer Table condition in the same AND block).
2. Reopen the master and confirm both conditions, their Type ("Table"), and their selected values persisted exactly as configured.
3. Using the app's normal compliance-loading flow for this master (the screen/report that lists applied/missing compliance records for a master, backed by `sp_load_compl_by_conditions`/`sp_load_compl_by_conditions_count`), confirm: only records whose Customer is one of the selected customers (A, B, C) **and** whose Product Type is one of the selected product types are matched by this block.
4. Pick a record with a Customer NOT in the selected list (but a matching Product Type) and confirm it is correctly excluded.

**Expected**: Matching results respect the Customer Table condition's selected values with the same accuracy already established for the Product Type Table condition — no unexplained inclusions/exclusions.

## Scenario 17 — Existing Value/NOT IN Customer conditions are unaffected

1. Open a master that already has a Customer condition saved as "Value" (single customer) or "NOT IN" (exclusion list) from before this change.

**Expected**: It still loads, displays, and evaluates exactly as before — its Type selector still offers Value/NOT IN (and now also Table, per Scenario 13), but its already-saved configuration and behavior are unchanged until a user deliberately edits it.

## Regression check (User Story 5)

- A rule block with only one Table-logic condition (any single reference type) continues to behave exactly as before — no change to the single-Table-condition case.
- Two conditions of the **same** reference type in one block still cannot both use Table simultaneously (unchanged edge case, see `research.md` R18) — only cross-type combinations are newly allowed.
- Individual mode's existing Type-selector restrictions (`isDisabledByIndividual`/`isRestrictedByIndividual`) behave exactly as before for every reference type, Customer included — this fix does not touch Individual-mode gating.
- Product Type's own Table behavior (selection, Master Preview rendering, save/reload, compliance matching) is completely unchanged.
- `ConditionsView.jsx` (the read-only "View Conditions" list dialog) renders a saved Customer Table condition without any code change, since it was already generic per reference type.
