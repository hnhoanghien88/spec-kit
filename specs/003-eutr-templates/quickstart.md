# Quickstart Validation Guide: EUTR Templates Management

**Feature**: 003-eutr-templates | **Date**: 2026-07-03

## Prerequisites

- Backend (`compliance-sys-api`) running on configured port
- Frontend (`compliance-client`) dev server running (`npm run dev`)
- MySQL database with EUTR tables created (see [eutr_db.sql](../../docs/design/eutr/eutr_db.sql))
- D365 VendorsV3 API accessible via configured Dynamics service (exposed as `GET /api/dynamics/vendors`)
- EUTR Steps feature (001) deployed with at least 3 steps in `eutr_steps` table
- User account with `EutrTemplates.*` permissions seeded in backend menu/roles

## Validation Scenarios

### Scenario 1: View Template List (FR-001, FR-002, FR-003)

1. Navigate to **EUTR system > EUTR templates** in left menu
2. **Expected**: Breadcrumb shows "EUTR system > EUTR templates"
3. **Expected**: Grid displays columns: Code, Name, Vendor code, Vendor name, Alert for, Is default, Version, Created by, Created date, Action
4. **Expected**: Grid shows only active templates (IsDeleted=0, IsHide=0)
5. If templates have valid VendorCode: **Expected** Vendor name column shows vendor name from `GET /api/dynamics/vendors`
6. Click page 2: **Expected** next page of records loads

### Scenario 2: Create Template with Step Tree (FR-004, FR-004a, FR-005, FR-005b, FR-006 to FR-010, FR-009a)

1. Click **Add** on toolbar
2. **Expected**: Full page opens with breadcrumb "EUTR system > EUTR templates > Add"
3. **Expected**: Layout shows **2 columns** — left column (wider): header form (Code, Name, AlertFor, Vendor, Default, **Save button below Default**); right column (narrower): step tree + step actions
4. **Expected**: Title bar shows only the **Back** button — no Save button next to it
5. **Expected**: Code field shows auto-generated value (e.g., "Templates-001"), readonly
6. Fill in: Name = "Test Template", Alert for = "Import"
7. Open Vendor combobox: **Expected** `GET /api/dynamics/vendors` is called, list shows VendorAccountNumber + VendorOrganizationName
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
19. **Expected**: Redirects to list, new template visible with Code, VersionId=1
20. **Verify in DB**: eutr_template_details rows have correct ParentId (child step has ParentId = parent step's Id, root steps have ParentId = 0)

### Scenario 3: Edit Template with Conditional Versioning (FR-011, FR-012, FR-005b)

**3a. Edit within 24h of creation (in-place update)**

1. Click **Edit** on the template created in Scenario 2 (just created, well under 24h old)
2. **Expected**: Edit page loads with **2-column layout** (widened header, narrowed steps), all header fields and step tree populated
3. **Expected**: Code field is readonly
4. **Expected**: Vendor combobox calls `GET /api/dynamics/vendors`, current vendor is pre-selected
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

1. Click Add, leave Name empty, fill AlertFor, click Save
2. **Expected**: Validation error on Name
3. Clear AlertFor, fill Name, click Save
4. **Expected**: Validation error on AlertFor
5. Fill both, click Save
6. **Expected**: Saves successfully

### Scenario 10: Import Templates (FR-014)

1. Prepare Excel file with columns: Name, VendorCode, AlertFor, IsDefault
2. Add 3 rows: 2 valid, 1 missing Name
3. Click **Import**, select file
4. **Expected**: Result dialog shows: Total=3, Success=2, Fail=1
5. **Expected**: Error details show the failing row and reason
6. **Verify in grid**: 2 new templates with auto-generated Codes

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

### Scenario 13: Edge Cases

- Empty grid: **Expected** "No data" message, no errors
- Invalid VendorCode in template: **Expected** Vendor name column shows blank
- Deep nesting (3+ levels): **Expected** tree renders correctly with collapse/expand
- Back button on Add/Edit page with NO step changes: **Expected** returns to list immediately, no warning
- Back button on Add/Edit page WITH unsaved step add/edit: **Expected** shows confirmation dialog before leaving
- Edit step then Save template: **Expected** edited step values persist in DB
- Edit step then Cancel (inline): **Expected** step retains original values
- Two-column layout on wide screen: **Expected** wider header column on the left, narrower steps column on the right, side by side
- Edit a template exactly at the 24h boundary: **Expected** behavior follows `(now - CreatedDate) >= 24h` comparison consistently

## Post-Validation Checks

- [ ] All 9 grid columns render correctly
- [ ] Vendor lookup works via `GET /api/dynamics/vendors` in combobox (Add and Edit modes) and grid
- [ ] Vendor combobox calls dedicated vendors endpoint (not reference API)
- [ ] Vendor pre-selected correctly in Edit mode
- [ ] Vendor API response contains ONLY 3 fields (dataAreaId, VendorAccountNumber, VendorOrganizationName) — verify in DevTools Network tab that no extra VendorsV3 properties are returned
- [ ] Tree supports 3+ levels of nesting
- [ ] ParentId saved correctly for all levels (root=0, children=parent's Id)
- [ ] ParentId correct even for newly-added parent steps (temp ID mapping works)
- [ ] Drag-and-drop reorders steps and updates DisplayOrder
- [ ] Inline Edit step changes Step, RequirementType, TakeFrom correctly
- [ ] Only one step in edit mode at a time (auto-cancel previous)
- [ ] Two-column layout displays correctly with WIDER header column (left) and NARROWER steps column (right)
- [ ] Save button appears below the "Set as default template" checkbox in the left column, NOT in the title bar
- [ ] Title bar shows only the Back button
- [ ] Editing a template <24h old updates the row in place (same Id/VersionId/CreatedDate, no new row)
- [ ] Editing a template ≥24h old creates a new version (new row, VersionId+1, old row IsHide=1)
- [ ] Back button with no unsaved step changes navigates immediately, no warning
- [ ] Back button with unsaved step add/edit shows a confirmation dialog; confirming discards the changes
- [ ] Soft delete sets IsDeleted=1, data preserved in DB
- [ ] Import handles valid/invalid rows correctly
- [ ] All UI text is in English (per FR-017)
- [ ] Navigation menu entry visible and routable
