# Quickstart Validation Guide: EUTR Templates Management

**Feature**: 003-eutr-templates | **Date**: 2026-07-03

## Prerequisites

- Backend (`compliance-sys-api`) running on configured port
- Frontend (`compliance-client`) dev server running (`npm run dev`)
- MySQL database with EUTR tables created (see [eutr_db.sql](../../docs/design/eutr/eutr_db.sql))
- D365 VendorsV3 accessible via the generic reference API (`POST /api/dynamics/reference` with
  `refType = 13`)
- `compl_group_email` has at least 2 active Alert groups (`GroupType = 2`, `IsAddition = false`)
  seeded — e.g. via the Group Email admin screen or directly through `GET/POST /api/group-email`
  (Update 7)
- EUTR Steps feature (001) deployed with at least 3 steps in `eutr_steps` table
- User account with `EutrTemplates.*` permissions seeded in backend menu/roles

## Validation Scenarios

### Scenario 1: View Template List (FR-001, FR-002, FR-003)

1. Navigate to **EUTR system > EUTR templates** in left menu
2. **Expected**: Breadcrumb shows "EUTR system > EUTR templates"
3. **Expected**: Grid displays columns: Code, Name, Vendor code, Vendor name, Alert for, Is default, Version, Created by, Created date, Action
4. **Expected**: Grid shows only active templates (IsDeleted=0, IsHide=0)
5. If templates have valid VendorCode: **Expected** Vendor name column shows vendor name from
   `POST /api/dynamics/reference` (refType=13)
5a. If templates have a valid AlertFor Id: **Expected** Alert for column shows the group's Name
   (from `compl_group_email`), not the raw Id (Update 7)
6. Click page 2: **Expected** next page of records loads

### Scenario 2: Create Template with Step Tree (FR-004, FR-004a, FR-005, FR-005b, FR-006 to FR-010, FR-009a)

1. Click **Add** on toolbar
2. **Expected**: Full page opens with breadcrumb "EUTR system > EUTR templates > Add"
3. **Expected**: Layout shows **2 columns** — left column (wider): header form (Code, Name, AlertFor, Vendor, Default, **Save button below Default**); right column (narrower): step tree + step actions
4. **Expected**: Title bar shows only the **Back** button — no Save button next to it
5. **Expected**: Code field shows auto-generated value (e.g., "Templates-001"), readonly
6. Fill in: Name = "Test Template"
6a. Open Alert for combobox: **Expected** `GET /api/group-email` is called, list shows only Alert
   groups (`GroupType=2`, `IsAddition=false`) by Name — no free-text typing allowed (Update 7)
6b. Select an Alert group (e.g. "Compliance Alerts Group")
7. Open Vendor combobox: **Expected** `POST /api/dynamics/reference` with `refType=13` is called,
   list shows VendorAccountNumber + VendorOrganizationName
8. Select a vendor, check Default
9. Click **Add step** (no parent selected)
10. Select a step from combobox, set Required, PO, click Save
11. **Expected**: Step appears at root level in tree
12. Check the root step, click **Add step** again
13. Select another step, set Optional, Upload manual, click Save
14. **Expected**: New step appears as child of the checked step
15. Add a third step at root level
16. Drag the third step above the first step
17. **Expected**: DisplayOrder updates, step moves visually
18. Click **Save** (below Default checkbox, left column)
19. **Expected**: Redirects to list, new template visible with Code, VersionId=1, Alert for column
    shows the selected group's Name
20. **Verify in DB**: eutr_template_details rows have correct ParentId (child step has ParentId = parent step's Id, root steps have ParentId = 0). `eutr_templates.AlertFor` stores the group's numeric Id (not its Name).

### Scenario 3: Edit Template with Conditional Versioning (FR-011, FR-012, FR-005b)

**3a. Edit within 24h of creation (in-place update)**

1. Click **Edit** on the template created in Scenario 2 (just created, well under 24h old)
2. **Expected**: Edit page loads with **2-column layout** (widened header, narrowed steps), all header fields and step tree populated
3. **Expected**: Code field is readonly
4. **Expected**: Vendor combobox calls `POST /api/dynamics/reference` with `refType=13`, current
   vendor is pre-selected
4a. **Expected**: Alert for combobox calls `GET /api/group-email`, current Alert group is
   pre-selected (matched by the Id stored in AlertFor)
5. **Note the current** `Id` and `VersionId` (e.g., via grid or DB query) before saving
6. Change Name to "Test Template v2"
7. Delete a child step via the X icon
8. **Expected**: Step and its children removed from tree
9. Click **Save**
10. **Expected**: Redirects to list
11. **Verify in grid**: Same Code, same `VersionId` as before (NOT incremented)
12. **Verify in DB**: The row's `Id` is unchanged, `CreatedDate` is unchanged, `IsHide` is still 0 — no new row was created. `eutr_template_details` for this `TemplateId` reflect the deleted step (removed) and updated Name.

**3b. Edit after 24h of creation (versioning)**

> To validate this branch without waiting 24h, manually backdate the test row's `CreatedDate` in
> MySQL: `UPDATE eutr_templates SET CreatedDate = CreatedDate - INTERVAL 25 HOUR WHERE Id = <id>;`

1. Backdate a template's `CreatedDate` to >24h ago as shown above
2. Click **Edit** on that template
3. Change Name to "Test Template v3", delete a step
4. Click **Save**
5. **Expected**: Redirects to list
6. **Verify in grid**: Same Code, `VersionId` incremented by 1
7. **Verify in DB**: Old row has `IsHide=1` (unchanged `CreatedDate`), new row has `IsHide=0`, new `VersionId`, new `CreatedDate` (now), and a new `Id`
8. **Verify in DB**: Template details saved to the new `TemplateId` with correct ParentId values

### Scenario 4: Delete Template - Soft Delete (FR-013)

1. Click **Delete** on a template row
2. **Expected**: Confirmation dialog appears
3. Click Cancel: **Expected** nothing changes
4. Click **Delete** again, confirm
5. **Expected**: Template disappears from grid
6. **Verify in DB**: Row has IsDeleted=1, not physically deleted

### Scenario 5: IsDefault Constraint (FR-005a)

1. Create Template A with VendorCode="V001", IsDefault=checked
2. Create Template B with VendorCode="V001", IsDefault=checked
3. **Expected**: Template B is now default, Template A's IsDefault is automatically cleared
4. **Verify in grid**: Only Template B shows IsDefault=true for V001

### Scenario 6: Step Deletion Methods (FR-008a)

1. Edit a template with multiple steps
2. Click X icon on a parent step
3. **Expected**: Parent and all children removed from tree
4. Add steps back, check 2 steps via checkboxes
5. Click **Delete step** button
6. **Expected**: Both checked steps (and their children) removed

### Scenario 7: Edit Step Inline (FR-008b)

1. Create or edit a template with at least 2 steps
2. Click the **Edit icon** (pencil) on a root step
3. **Expected**: Step row switches to edit mode with comboboxes for Step, RequirementType, TakeFrom — all pre-filled with current values. Save and Cancel buttons appear.
4. Change RequirementType from Required to Optional
5. Change TakeFrom from PO to Upload manual
6. Click **Save** on the inline edit
7. **Expected**: Step displays updated values (Optional, Upload manual)
8. Click Edit icon on the same step again, change the Step to a different one via combobox
9. Click **Save**
10. **Expected**: Step name updates to the newly selected step
11. Click Edit icon on another step, then click **Cancel**
12. **Expected**: Step retains original values, exits edit mode
13. Click Edit icon on step A, then click Edit icon on step B (without saving A)
14. **Expected**: Step A auto-cancels (reverts), step B enters edit mode
15. Click **Save** (template footer) to persist all changes
16. **Verify in DB**: eutr_template_details rows reflect the updated StepId, RequirementType, TakeFrom

### Scenario 8: ParentId Correctness for New Steps (FR-009, FR-008)

1. Click **Add** to create a new template
2. Add step "Forest" at root level (no parent selected)
3. Check "Forest", click **Add step**, add "Certification" as child
4. Check "Certification", click **Add step**, add "Document" as grandchild (3 levels deep)
5. Click **Save**
6. **Verify in DB**: "Forest" has ParentId = 0, "Certification" has ParentId = Forest's Id, "Document" has ParentId = Certification's Id
7. Edit the template, add a new child step under "Forest"
8. Click **Save**
9. **Verify in DB**: New child has ParentId = Forest's server Id (not 0)

### Scenario 9: Validation (FR-010)

1. Click Add, leave Name empty, select an Alert for group, click Save
2. **Expected**: Validation error on Name
3. Fill Name, leave Alert for unselected, click Save
4. **Expected**: Validation error on Alert for ("Alert for is required")
5. Fill Name and select an Alert for group, click Save
6. **Expected**: Saves successfully

### Scenario 10: Import Templates (FR-014)

1. Prepare Excel file with columns: Name, VendorCode, AlertFor, IsDefault — AlertFor column MUST
   contain an existing Alert group's **Name** (e.g. "Compliance Alerts Group"), matching a
   `compl_group_email` row with `GroupType=2` (Update 7)
2. Add 4 rows: 2 valid, 1 missing Name, 1 with an AlertFor Name that doesn't match any group
   (e.g. "Nonexistent Group")
3. Click **Import**, select file
4. **Expected**: Result dialog shows: Total=4, Success=2, Fail=2
5. **Expected**: Error details show the failing rows and reasons — the missing-Name row shows
   "Name is required", the unmatched-group row shows "Alert for group not found"
6. **Verify in grid**: 2 new templates with auto-generated Codes, Alert for column shows the
   correct group Name for each

### Scenario 12: Back Button — Unsaved Step Changes Warning (FR-015)

1. Click **Add** to create a new template
2. Fill in Name/AlertFor only, do NOT add any steps, click **Back**
3. **Expected**: Navigates directly to the list, no warning dialog (no step changes made)
4. Click **Add** again, click **Add step**, save a step into the tree, then click **Back** (without saving the template)
5. **Expected**: A confirmation dialog appears warning about unsaved changes
6. Click **Cancel** on the dialog: **Expected** stays on the Add page, step still in tree
7. Click **Back** again, then confirm/**Leave** on the dialog: **Expected** navigates to the list; the step that was added is NOT persisted (verify it doesn't appear if you check the template — it was never saved)
8. Repeat with **Edit** mode: open Edit on an existing template, click the Edit icon on a step and change its RequirementType (inline edit save, not template Save), then click **Back**
9. **Expected**: Confirmation dialog appears (inline step edit counts as unsaved step change)
10. Confirm leaving: **Expected** navigates to list; reopening Edit shows the ORIGINAL RequirementType (change was discarded)

### Scenario 14: Free-solo Step Combobox — Auto-create New Step (FR-007, FR-007a, FR-008b)

1. Note the current row count in the **EUTR Steps** (001-eutr-steps) grid
2. Click **Add** to create a new template, fill Name/AlertFor
3. In the Step combobox (Add step form), type a name that does NOT exist in the EUTR Steps list
   (e.g., "Brand New Step XYZ") instead of picking an option
4. Set Required, PO, click **Save** on the step row
5. **Expected**: The typed step appears in the tree immediately (client-side, not yet persisted)
6. Add a second root step, typing the SAME new name ("Brand New Step XYZ") again
7. Click template **Save**
8. **Expected**: Template saves successfully
9. **Verify in DB**: `eutr_steps` has exactly ONE new row named "Brand New Step XYZ" (no
   duplicates), and both `eutr_template_details` rows reference that same new `StepId`
10. **Verify in UI**: Open the EUTR Steps screen — the new step count increased by 1 and "Brand
    New Step XYZ" is listed
11. Edit the template again, click the Edit icon on one of the steps, type an existing step's name
    (e.g., "Forest Management") into the Step combobox instead of selecting it from the dropdown,
    save the inline edit, then Save the template
12. **Verify in DB**: No duplicate `eutr_steps` row was created for "Forest Management" — the
    existing StepId was reused

### Scenario 13: Edge Cases

- Empty grid: **Expected** "No data" message, no errors
- Invalid VendorCode in template: **Expected** Vendor name column shows blank
- AlertFor Id no longer found in `compl_group_email` (group deleted after template was saved):
  **Expected** Alert for column shows blank, no error for the rest of the grid (Update 7)
- `compl_group_email` has zero Alert groups (`GroupType=2`): **Expected** Alert for combobox shows
  no options and Save is blocked until at least one Alert group exists (Update 7)
- Deep nesting (3+ levels): **Expected** tree renders correctly with collapse/expand
- Back button on Add/Edit page with NO step changes: **Expected** returns to list immediately, no warning
- Back button on Add/Edit page WITH unsaved step add/edit: **Expected** shows confirmation dialog before leaving
- Edit step then Save template: **Expected** edited step values persist in DB
- Edit step then Cancel (inline): **Expected** step retains original values
- Two-column layout on wide screen: **Expected** wider header column on the left, narrower steps column on the right, side by side
- Edit a template exactly at the 24h boundary: **Expected** behavior follows `(now - CreatedDate) >= 24h` comparison consistently
- Empty EUTR Steps list: **Expected** Step combobox still accepts free-solo typed input (no longer requires creating a step first)
- Step combobox typed name matches an existing step differing only by case/whitespace: **Expected** the existing StepId is reused, no duplicate created
- Step combobox left blank/whitespace-only when saving a step row: **Expected** validation blocks adding the empty step

## Post-Validation Checks

- [ ] All 9 grid columns render correctly
- [ ] Alert for combobox loads only Alert groups (`GroupType=2`, `IsAddition=false`) via
      `GET /api/group-email`, no free-text typing allowed (Update 7)
- [ ] Alert for pre-selected correctly in Edit mode (Update 7)
- [ ] Grid's Alert for column shows the group Name, not the raw Id; saved `AlertFor` in DB is the
      numeric Id (Update 7)
- [ ] Vendor lookup works via `POST /api/dynamics/reference` (refType=13) in combobox (Add and
      Edit modes) and grid
- [ ] Vendor combobox calls the generic reference endpoint (NOT the dedicated
      `GET /api/dynamics/vendors` endpoint from Update 2/3)
- [ ] Vendor pre-selected correctly in Edit mode
- [ ] Vendor reference response items expose `id`/`code` = VendorAccountNumber and
      `name` = VendorOrganizationName — verify in DevTools Network tab
- [ ] Tree supports 3+ levels of nesting
- [ ] ParentId saved correctly for all levels (root=0, children=parent's Id)
- [ ] ParentId correct even for newly-added parent steps (temp ID mapping works)
- [ ] Drag-and-drop reorders steps and updates DisplayOrder
- [ ] Inline Edit step changes Step, RequirementType, TakeFrom correctly
- [ ] Only one step in edit mode at a time (auto-cancel previous)
- [ ] Two-column layout displays correctly with WIDER header column (left) and NARROWER steps column (right)
- [ ] Save button appears below the "Set as default template" checkbox in the left column, NOT in the title bar
- [ ] Title bar shows only the Back button
- [ ] Step combobox (Add step and inline Edit step) accepts both selecting an existing option and typing a free-solo name
- [ ] Typing a new step name and saving the template auto-creates it in `eutr_steps`, visible immediately in the EUTR Steps screen
- [ ] Multiple steps with the same new typed name in one Save create only ONE `eutr_steps` row (no duplicates)
- [ ] Typing a name matching an existing step (case-insensitive/trimmed) reuses that step's Id, no duplicate created
- [ ] Editing a template <24h old updates the row in place (same Id/VersionId/CreatedDate, no new row)
- [ ] Editing a template ≥24h old creates a new version (new row, VersionId+1, old row IsHide=1)
- [ ] Back button with no unsaved step changes navigates immediately, no warning
- [ ] Back button with unsaved step add/edit shows a confirmation dialog; confirming discards the changes
- [ ] Soft delete sets IsDeleted=1, data preserved in DB
- [ ] Import handles valid/invalid rows correctly
- [ ] All UI text is in English (per FR-017)
- [ ] Navigation menu entry visible and routable
