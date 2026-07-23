# Quickstart Validation Guide: EUTR Templates Management

**Feature**: 003-eutr-templates | **Date**: 2026-07-03

**Update 13 (2026-07-13) note**: `eutr_templates` no longer has a `VendorCode` field at all — every
scenario below that references a Vendor combobox on the Create dialog or TemplateBuilderPage is
superseded; Vendor now only appears on the new **ApplyCustomerPage** (Scenario 17). `IsDefault`'s
uniqueness constraint (Scenario 5) is now global, not per-VendorCode. See Scenario 16
(VendorCode-removal verification), Scenario 17 (Apply to Customer), and Scenario 18 (Steps-count
investigation) for the new/changed coverage.

**Update 16 (2026-07-21) note**: FR-012's 24-hour age-based versioning is removed entirely.
`eutr_templates` gains a `Status` column (`Draft`/`Approved`); editing is always in-place while
Draft, and a version bump now happens ONLY via the new explicit **Request change** action
(Approved → Draft). See Scenario 3' (replaces Scenario 3's superseded age-based flow).

**Update 17 (2026-07-22) note**: TemplateBuilderPage's step tree now ALSO supports drag-and-drop
reordering, additive to the existing Move Up/Move Down buttons — both produce the same
`DisplayOrder` result via the same `reorderSiblings` function. Drag is restricted to same-level
siblings only (no reparenting) and disabled when Status=Approved, same as Move Up/Move Down. See
**Scenario 2b''**.

**Update 18 (2026-07-23) note**: the Set-as-default checkbox on TemplateBuilderPage is no longer
locked when Status=Approved (the one exception to Scenario 3'b's read-only banner) — toggling it
opens a Yes/No confirm dialog and persists immediately via a new dedicated endpoint, independent of
the (still hidden/disabled) Save button. See **Scenario 21**.

## Prerequisites

- Backend (`compliance-sys-api`) running on configured port
- Frontend (`compliance-client`) dev server running (`npm run dev`)
- MySQL database with EUTR tables created (see [eutr_db.sql](../../docs/design/eutr/eutr_db.sql)),
  including the new `eutr_template_references` table (Update 13 — see
  `Sqls/Migration/11_create_eutr_template_references.sql`) and the `Status` column on
  `eutr_templates` (Update 16 — see `Sqls/Migration/13_add_status_to_eutr_templates.sql`)
- D365 VendorsV3 accessible via the generic reference API (`POST /api/dynamics/reference` with
  `refType = 13`) — **Update 13**: now used by ApplyCustomerPage's Vendor combobox, not by
  TemplateBuilderPage (Vendor field removed from the template itself)
- `compl_group_email` has at least 2 active Alert groups (`GroupType = 2`, `IsAddition = false`)
  seeded — e.g. via the Group Email admin screen or directly through `GET/POST /api/group-email`
  (Update 7)
- EUTR Steps feature (001) deployed with at least 3 steps in `eutr_steps` table
- User account with `EutrTemplates.*` permissions seeded in backend menu/roles; **Update 13**: also
  needs the new `EutrTemplateReferences.*` policies (verify wiring — see plan.md)

## Validation Scenarios

### Scenario 1: View Template List (superseded in part by Scenario 1' below — Update 10/11)

> **Update 10/11 note**: TemplateListPage no longer renders the 9-column DataGrid described below
> — see **Scenario 1'** for the current Table-layout behavior. This scenario is kept for reference
> against `TemplateListPageOld.jsx`, which still exists (unrouted) and still behaves exactly as
> described here.

1. Navigate to **EUTR system > EUTR templates** in left menu
2. **Expected**: Breadcrumb shows "EUTR system > EUTR templates"
3. **Expected**: Grid displays columns: Code, Name, Vendor code, Vendor name, Alert for, Is default, Version, Created by, Created date, Action
4. **Expected**: Grid shows only active templates (IsDeleted=0, IsHide=0)
5. If templates have valid VendorCode: **Expected** Vendor name column shows vendor name from
   `POST /api/dynamics/reference` (refType=13)
5a. If templates have a valid AlertFor Id: **Expected** Alert for column shows the group's Name
   (from `compl_group_email`), not the raw Id (Update 7)
6. Click page 2: **Expected** next page of records loads

### Scenario 1': View Template List — Table Layout, Search, Bulk Delete (FR-021, FR-021a, FR-021b, FR-021c, FR-022, FR-026)

1. Navigate to **EUTR system > EUTR templates** in left menu
2. **Expected**: TemplateListPage renders — a Table (not a multi-column DataGrid) with a search
   box above it, and no Import/Export buttons or column-visibility toggle
3. **Expected**: Each row's name cell shows two lines: the template's **Code** in bold on top, its
   **Name** as a smaller caption underneath (FR-021)
4. **Expected**: Each row shows a Version chip (e.g. "V1"), a Default chip only when
   `isDefault = 1`, and a Steps count reflecting the real number of steps in that template's tree
   (FR-021c) — not 0 for a template that actually has steps
5. **Expected**: Each row's Actions column shows 4 icons — Edit, Clone, Apply to Customer, Delete.
   Clone and Apply to Customer are visibly disabled (cannot be clicked) (FR-026)
6. Type a partial Code (e.g. the first few characters of an existing template's Code) into the
   search box
7. **Expected** (DevTools Network tab): a request to the list endpoint fires with a `filters`
   entry `{ field: "Keyword", ... }`, debounced (not one request per keystroke), and the visible
   page resets to the first page
8. **Expected**: only templates whose Code or Name contains the typed text (case-insensitive)
   appear, including templates that were on a different page before searching
9. Clear the search box: **Expected** the full list returns
10. Tick the checkbox on 2+ rows: **Expected** a bulk-delete button becomes enabled on the toolbar
    (previously disabled with none selected)
11. Click the bulk-delete button: **Expected** a confirmation dialog names the number of selected
    templates
12. Confirm: **Expected** all selected templates disappear from the list, selection clears, and a
    success snackbar appears
13. **Verify in DB**: all selected templates now have `IsDeleted = 1`
14. Click the Delete icon on a single row (not via checkbox): **Expected** behaves identically to
    `TemplateListPageOld.jsx`'s single-delete flow (confirmation naming that template's Name and
    Code, then soft delete + success snackbar) (FR-022)

### Scenario 2: Quick-Create Template via Dialog (FR-004, FR-005, FR-005c, FR-009, FR-010)

1. On **TemplateListPage**, click **Create Template** on toolbar
2. **Expected**: A dialog/modal opens (no page navigation) with ONLY 3 fields: Name, Alert for
   (combobox), Set as default (checkbox) — **no Vendor field, no step tree**
3. Try clicking Save with Name empty: **Expected** validation error, dialog stays open
4. Fill in: Name = "Test Template"
5. Open Alert for combobox: **Expected** `GET /api/group-email` is called, list shows only Alert
   groups (`GroupType=2`, `IsAddition=false`) by Name — no free-text typing allowed (Update 7)
6. Select an Alert group (e.g. "Compliance Alerts Group"), check Set as default
7. Click **Save** (dialog action)
8. **Expected**: Dialog closes, list refreshes automatically (no navigation), new template row
   appears with an auto-generated Code (e.g. "Templates-001"), Version=1, Alert for column showing
   the selected group's Name
9. **Verify in DB**: `eutr_templates` row created (**Update 13**: no `VendorCode` column exists on
   this table at all anymore); `eutr_template_details` has ZERO rows for this `TemplateId` (Update 9
   — step tree is no longer built at Create time)

### Scenario 2b: Build the Step Tree via Edit (superseded by Scenario 2b' — Update 10)

> **Update 10 note**: clicking Edit no longer opens the 2-column form/list layout described below
> — it opens **TemplateBuilderPage** (tree-view + side panel). See **Scenario 2b'**. This scenario
> is kept for reference against `EutrTemplatesAddEdit.jsx`, which still exists (unrouted) and still
> behaves exactly as described here if opened directly for manual comparison.

1. Click **Edit** on the template created in Scenario 2 (0 steps, no Vendor)
2. **Expected**: Full Edit page opens with breadcrumb "EUTR system > EUTR templates > Edit",
   **2-column layout** — left column (wider): header form (Code readonly, Name, AlertFor, Vendor,
   Default, **Save button below Default**); right column (narrower): step tree + step actions,
   currently showing an empty-tree state
3. **Expected**: Title bar shows only the **Back** button — no Save button next to it
4. Open Vendor combobox: **Expected** `POST /api/dynamics/reference` with `refType=13` is called,
   list shows VendorAccountNumber + VendorOrganizationName, nothing pre-selected (template has no
   Vendor yet); select a vendor
5. Click **Add step** (no parent selected)
6. Select a step from combobox, set Required, PO, click Save
7. **Expected**: Step appears at root level in tree (this is the template's FIRST step)
8. Check the root step, click **Add step** again
9. Select another step, set Optional, Upload manual, click Save
10. **Expected**: New step appears as child of the checked step
11. Add a third step at root level
12. Drag the third step above the first step
13. **Expected**: DisplayOrder updates, step moves visually
14. Click **Save** (below Default checkbox, left column)
15. **Expected**: Redirects to list; since this template was created moments ago (well under 24h),
    this Save updates the SAME row in place — Version stays 1, Vendor code/name now populated
16. **Verify in DB**: `eutr_templates.VendorCode` now set; `eutr_template_details` rows have
    correct ParentId (child step has ParentId = parent step's Id, root steps have ParentId = 0);
    the row's `Id`/`VersionId`/`CreatedDate` are unchanged from Scenario 2 (in-place update, not a
    new version)

### Scenario 2b': Build the Step Tree via Edit — TemplateBuilderPage (FR-023, FR-024, FR-025, FR-006 to FR-011)

> **Update 13 note**: steps 4 and 15 below (Vendor combobox on this screen) are **removed** — the
> Vendor field no longer exists on `eutr_templates`/TemplateBuilderPage at all (FR-041). Vendor is
> now set up separately via ApplyCustomerPage (Scenario 17). The rest of this scenario (step tree
> building) is unaffected.

1. Click **Edit** on the template created in Scenario 2 (0 steps)
2. **Expected**: browser navigates to `/eutr/templates/edit/:id`, which renders
   **TemplateBuilderPage** — a tree-view panel (left) + "Step Configuration" panel (right) +
   toolbar (Add Root Group / Add Child Step / Move Up / Move Down / Delete / Expand / Collapse),
   with real data loaded (not the mock `EUTR_TEMPLATES`/`EUTR_TEMPLATE_DETAILS_MAP`)
3. **Expected**: tree shows an empty-tree state (this template has 0 steps); right panel — since no
   step is selected — shows the **header form**: Code (readonly), Name, Alert for combobox,
   Set-as-default checkbox, Save button (FR-024) — **Update 13: no Vendor combobox here anymore**
4. Click **Add Root Group**: **Expected** a dialog opens with a free-solo Step Autocomplete (not a
   fixed dropdown of mock steps), RequirementType, TakeFrom — no Type or FSC fields (FR-025)
5. Pick an existing step, set Required, PO, confirm
6. **Expected**: Step appears at root level in the tree (this is the template's FIRST step)
7. Select the root step, click **Add Child Step**, pick another step, set Optional, Upload manual,
   confirm
8. **Expected**: New step appears as a child of the selected step
9. Add a third root-level step
10. Select the third step, click **Move Up** twice
11. **Expected**: the step moves above the first step in the tree, `DisplayOrder` updates
    accordingly (via `reorderSiblings`) (FR-006) — **Update 17**: this screen now ALSO supports a
    drag gesture for the same result, see **Scenario 2b''**
12. Click **Save** (in the header form panel)
13. **Expected**: navigates back to `/eutr/templates`; since this template was created moments ago
    (well under 24h), this Save updates the SAME row in place — Version stays 1
14. **Verify in DB**: `eutr_template_details` rows have correct ParentId; the row's
    `Id`/`VersionId`/`CreatedDate` are unchanged from Scenario 2 (in-place update, not a new version)
15. Re-open Edit on the same template, select the middle step in the tree: **Expected** the right
    panel switches to that step's detail (Step Master via free-solo, RequirementType, TakeFrom —
    no Type/FSC fields), with Save/Delete actions

### Scenario 2b'': Drag-and-Drop Step Reorder (FR-064 to FR-067, Update 17)

> Uses the same template from Scenario 2b' (Draft, 3 root-level steps A/B/C after the Move Up steps
> above, plus at least one child step under one of them). Verifies the drag gesture is equivalent to
> Move Up/Move Down, is scoped to same-level siblings only, and is disabled when Approved.

1. On the tree, drag the third root-level step and drop it between the first and second root-level
   steps
2. **Expected**: the step reorders immediately in the UI to the dropped position; the screen is
   marked dirty (same indicator/behavior as after a Move Up/Down click or any other unsaved tree
   edit) — nothing is persisted yet
3. Click **Save**, then re-open Edit on the same template
4. **Expected**: the new order persisted — matches exactly what Move Up/Move Down would have
   produced to reach the same position (FR-064, FR-066); **Verify in DB**:
   `eutr_template_details.DisplayOrder` for the affected root-level rows is 0/1/2 in the new order
5. Attempt to drag a root-level step and drop it onto a step that is a **child** of a different
   root step (i.e. a different `ParentId` branch)
6. **Expected**: no-op — the dragged step's `ParentId` is unchanged, no reorder happens, no error
   shown (FR-065 — this feature does not support reparenting via drag)
7. Navigate to TemplateListPage, select this template's row, click **Approve**, confirm Yes
8. Re-open Edit on the now-**Approved** template
9. **Expected**: the read-only banner is shown (per Scenario 3'a's Approved behavior) and attempting
   to drag any step produces no reorder — the drag handle MUST be disabled/inert, exactly like Move
   Up/Move Down are disabled in this state (FR-067)
10. Use **Request change** (TemplateListPage) to return the template to Draft, confirm the drag
    gesture works again on re-opening Edit

### Scenario 3: Edit Template with Conditional Versioning (superseded by Scenario 3' — Update 16) (FR-011, FR-012, FR-005b)

> **Superseded (Update 16)**: FR-012's 24-hour age-based versioning branch has been removed
> entirely. This scenario is kept for historical reference (including its real
> `/speckit-implement` verification evidence below) but no longer reflects current behavior — see
> **Scenario 3'** for the Status-driven replacement (always in-place while Draft; versioning only
> via the explicit Request change action).

**3a. Edit within 24h of creation (in-place update)**

1. Click **Edit** on the template from Scenario 2b' (now has steps, still under 24h old)
2. **Expected**: Edit page loads with all header fields and step tree populated
3. **Expected**: Code field is readonly
4a. **Expected**: Alert for combobox calls `GET /api/group-email`, current Alert group is
   pre-selected (matched by the Id stored in AlertFor). **Update 13**: there is no Vendor combobox
   on this screen anymore — see Scenario 17 for Vendor-related coverage.
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
9. **(Update 15, FR-049)** Before backdating, apply at least 1 vendor mapping to this template via
   ApplyCustomerPage (Scenario 17). After the version-up Save in step 4 above, **verify in DB**:
   `SELECT * FROM eutr_template_references WHERE TemplateId = <new Id>` returns the same mapping(s)
   (same VendorCode/FromDate/ToDate/CreatedBy/CreatedDate as the original), AND the original row
   under the OLD `TemplateId` is still present unchanged (not moved, not deleted) — open
   `/eutr/templates/apply/<new Id>` in the browser and confirm the mapping is visible there.

**Outcome (2026-07-15, `/speckit-implement`, step 9 only)**: **Verified via a direct SQL smoke test
against the live dev DB** (`compliance_sys_db_260601`), not through the full HTTP+UI stack (no
interactive browser session available in this non-interactive environment, same limitation as
Update 13/14). A throwaway source template ("SMOKE-TEST-001") was created with 2 vendor mappings
(distinct VendorCode, non-overlapping dates), and a throwaway destination template
("SMOKE-TEST-002") was created to act as the "new version" TemplateId. Running the exact
`CopyReferencesAsync` SQL (`INSERT INTO eutr_template_references (...) SELECT ... FROM
eutr_template_references WHERE TemplateId = @sourceTemplateId`) copied both rows to the
destination with byte-for-byte identical VendorCode/FromDate/ToDate/CreatedBy/CreatedDate; a
follow-up query confirmed the source template's 2 mappings were still present and unmodified. All
test data (4 mapping rows, 2 template rows) was deleted immediately after, leaving the dev DB
unchanged. This is the exact SQL statement `EutrTemplatesService.UpdateAsync`'s ≥24h branch now
calls (via `_templateReferencesRepository.CopyReferencesAsync(id, newId, ct)`) right after copying
the step tree — the C# wiring around it (constructor injection, call placement inside the existing
transaction) was verified by code review and a clean `dotnet build` (0 `error CS`).

### Scenario 3': Status-Driven Editing — Draft Always In-Place, Approve, Request Change (FR-055 to FR-062, Update 16)

**3'a. Draft edits always save in-place, regardless of age**

1. Create a new template via Scenario 2 (quick-create) — **Verify in DB**: `Status = 0` (Draft)
2. Backdate its `CreatedDate` far in the past (reusing Scenario 3's backdate technique — this used
   to force the ≥24h branch; Update 16 removes that branch, so this step now exists purely to prove
   age no longer matters): `UPDATE eutr_templates SET CreatedDate = CreatedDate - INTERVAL 100 HOUR
   WHERE Id = <id>;`
3. Click **Edit**, change Name to "Test Template v2", add/remove a step, click **Save**
4. **Expected**: Redirects to list; grid shows the SAME Code and VersionId (not incremented)
5. **Verify in DB**: Same `Id`, same `VersionId`, `CreatedDate` still shows the backdated value
   (untouched by Save), `Status` still `0` (Draft), `eutr_template_details` reflect the edit — no new
   row was created despite the row being far older than the old 24h threshold

**3'b. Approve — Draft to Approved, same row**

1. On `TemplateListPage`, tick the checkbox for a Draft template; **Expected**: the **Approve**
   button on the toolbar becomes enabled, **Request change** stays disabled
2. Click **Approve**; **Expected**: a Yes/No confirmation dialog appears
3. Click **No**; **Expected**: dialog closes, **verify in DB** the row's `Status` is still `0` (Draft)
4. Click **Approve** again, then **Yes**; **Expected**: list refreshes, the row's Status Chip now
   shows "Approved"
5. **Verify in DB**: same `Id`, same `VersionId`, same `eutr_template_details`/
   `eutr_template_references` as before — only `Status` (+ `UpdatedBy`/`UpdatedDate`) changed
6. Click **Edit** on this now-Approved template; **Expected**: `TemplateBuilderPage` shows a warning
   banner; every header field, the Save button, Root Group/Child Step buttons, and each step row's
   Edit/Delete icons are disabled
7. **API check**: call `PUT api/eutr-templates/{id}` directly (e.g. via the browser network tab or a
   REST client) with a valid payload for this Approved template; **Expected**: HTTP 400,
   `"Template is Approved — use Request change before editing."` — confirms the backend rejects the
   edit even if the disabled frontend button were somehow bypassed

**3'c. Request change — Approved to Draft, new version row, old row preserved**

1. Note the Approved template's current `Id`, `Code`, and `VersionId` from Scenario 3'b
2. **(FR-049/FR-060 continuity check)** Before requesting change, apply at least 1 vendor mapping to
   this template via ApplyCustomerPage (Scenario 17)
3. On `TemplateListPage`, tick the checkbox for this Approved template; **Expected**: **Request
   change** becomes enabled, **Approve** stays disabled
4. Click **Request change**; **Expected**: a Yes/No confirmation dialog appears
5. Click **No**; **Expected**: dialog closes, **verify in DB** no new row was created, the original
   row is still `Status=1 (Approved)`, same `VersionId`
6. Click **Request change** again, then **Yes**; **Expected**: list refreshes, showing a row with the
   SAME Code, a new `VersionId` (old + 1), and Status Chip "Draft"
7. **Verify in DB**: a NEW row exists with `VersionId = <old + 1>`, `Status = 0` (Draft), `IsHide = 0`,
   same `Name`/`AlertFor`/`IsDefault` as the old row; the OLD row now has `IsHide = 1` but is
   otherwise completely unchanged (`Status` still `1` (Approved), not deleted)
8. **Verify in DB**: `eutr_template_details` for the NEW `TemplateId` match the old `TemplateId`'s
   tree exactly (same StepId/RequirementType/TakeFrom/DisplayOrder/ParentId structure)
9. **Verify in DB**: `eutr_template_references` for the NEW `TemplateId` match the old `TemplateId`'s
   mapping(s) from step 2 exactly (same VendorCode/FromDate/ToDate) — open
   `/eutr/templates/apply/<new Id>` in the browser and confirm the mapping is visible there, AND the
   old `TemplateId`'s mapping is still present unchanged at `/eutr/templates/apply/<old Id>`
10. Click **Edit** on the new Draft row; **Expected**: `TemplateBuilderPage` opens in normal editing
    mode (no read-only banner), and Save works exactly as in Scenario 3'a

**3'd. Toolbar button gating**

1. With 0 rows selected: **Expected** both Approve and Request change are disabled
2. With 2+ rows selected (any Status mix): **Expected** both are disabled
3. With exactly 1 Draft row selected: **Expected** only Approve is enabled
4. With exactly 1 Approved row selected: **Expected** only Request change is enabled

**Outcome (2026-07-21, `/speckit-implement`)**: **Verified via a direct SQL smoke test against the
live dev DB** (`compliance_sys_db_260601`), not through the full HTTP+UI stack — no interactive
browser session available, and the dev API's `[Authorize]` requires a JWT (validated against
`keys/public.pem`, no matching private key present) plus an `XApiKey` header whose configured value
is a key-vault placeholder in this environment (same class of limitation as Update 13/14/15). Before
any code changes, `DESCRIBE eutr_templates` revealed the dev DB already had an unused
`Status TINYINT NULL DEFAULT 0` column (no matching migration/design-doc/code anywhere), and
`AlertFor` still `tinyint` (migration 08 never applied there) — confirming this dev DB predates
several documented migrations. Per the user's decision, `Status` was implemented as `TINYINT`
(`TemplateStatusEnum : byte { Draft = 0, Approved = 1 }`) instead of the originally-planned
`VARCHAR(20)` string — see research.md §33 for the full account. A throwaway template
("SMOKE16-001") with 2 steps (root + child) and 1 vendor mapping was created as Draft, then the
exact SQL each service method runs was executed by hand: (1) Approve's `UPDATE ... SET Status=1`
left `Id`/`VersionId`/both detail rows/the mapping row completely unchanged; (2) Request change's
sequence (insert new row with `VersionId+1`/`Status=0`, copy the 2 detail rows with correct
`ParentId` re-parenting, copy the 1 mapping row via the existing `CopyReferencesAsync` SQL, then
`UPDATE` the old row to `IsHide=1`) produced a new row with the copied tree/mapping intact and left
the old row's `Status=1`/2 details/1 mapping fully preserved (not deleted, not moved). All throwaway
rows (2 templates, 4 details, 2 mappings total across both) were deleted afterward; a follow-up
count query confirmed 0 rows remaining, leaving the dev DB unchanged. Toolbar gating (3'd) and the
read-only banner (3'b step 6)
were verified by code review of `TemplateListPage.jsx`/`TemplateBuilderPage.jsx` rather than live
clicking. **Recommended before sign-off**: obtain a working `XApiKey`/JWT (or run this in an
environment with real auth configured) and manually click through 3'a–3'd in a browser.

### Scenario 4: Delete Template - Soft Delete (FR-013)

1. Click **Delete** on a template row
2. **Expected**: Confirmation dialog appears
3. Click Cancel: **Expected** nothing changes
4. Click **Delete** again, confirm
5. **Expected**: Template disappears from grid
6. **Verify in DB**: Row has IsDeleted=1, not physically deleted

### Scenario 5: IsDefault Constraint (FR-040, Update 13 — now global, was per-VendorCode/FR-005a)

1. Create Template A (via the Create Template dialog), IsDefault=checked
2. Create Template B (a completely separate template — **Update 13**: no longer needs to share a
   VendorCode with A, since Vendor no longer exists on templates at all), IsDefault=checked
3. **Expected**: Template B is now default, Template A's IsDefault is automatically cleared
4. **Verify in grid**: Only Template B shows IsDefault=true, across the ENTIRE list (not scoped to
   any vendor)

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

1. Click **Create Template**, fill Name + Alert for, Save (dialog) to create a bare template
2. Click **Edit** on that template
3. Add step "Forest" at root level (no parent selected)
4. Check "Forest", click **Add step**, add "Certification" as child
5. Check "Certification", click **Add step**, add "Document" as grandchild (3 levels deep)
6. Click **Save**
7. **Verify in DB**: "Forest" has ParentId = 0, "Certification" has ParentId = Forest's Id, "Document" has ParentId = Certification's Id
8. Edit the template again, add a new child step under "Forest"
9. Click **Save**
10. **Verify in DB**: New child has ParentId = Forest's server Id (not 0)

### Scenario 9: Validation (FR-010)

1. Click **Create Template**, leave Name empty, select an Alert for group, click Save (dialog)
2. **Expected**: Validation error on Name, dialog stays open
3. Fill Name, leave Alert for unselected, click Save
4. **Expected**: Validation error on Alert for ("Alert for is required"), dialog stays open
5. Fill Name and select an Alert for group, click Save
6. **Expected**: Saves successfully, dialog closes, list refreshes

### Scenario 10: Import Templates (FR-014)

1. Prepare Excel file with columns: Name, AlertFor, IsDefault (**Update 13**: `VendorCode` column
   removed — was `Name, AlertFor, VendorCode, IsDefault` before Update 13) — AlertFor column MUST
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

1. Click **Create Template**, fill Name/AlertFor, Save (dialog) — **Expected**: no Back button, no
   warning applies to the dialog itself (only 3 simple fields, no step tree at this stage)
2. Click **Edit** on that template, do NOT add any steps, click **Back**
3. **Expected**: Navigates directly to the list, no warning dialog (no step changes made)
4. Click **Edit** again, click **Add step**, save a step into the tree, then click **Back** (without saving the template)
5. **Expected**: A confirmation dialog appears warning about unsaved changes
6. Click **Cancel** on the dialog: **Expected** stays on the Edit page, step still in tree
7. Click **Back** again, then confirm/**Leave** on the dialog: **Expected** navigates to the list; the step that was added is NOT persisted (verify it doesn't appear if you check the template — it was never saved)
8. Repeat on a template that already has steps: open Edit, click the Edit icon on a step and change its RequirementType (inline edit save, not template Save), then click **Back**
9. **Expected**: Confirmation dialog appears (inline step edit counts as unsaved step change)
10. Confirm leaving: **Expected** navigates to list; reopening Edit shows the ORIGINAL RequirementType (change was discarded)

### Scenario 14: Free-solo Step Combobox — Auto-create New Step (FR-007, FR-007a, FR-008b)

1. Note the current row count in the **EUTR Steps** (001-eutr-steps) grid
2. Click **Create Template**, fill Name/AlertFor, Save (dialog) to create a bare template, then
   click **Edit** on it
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

### Scenario 15: Bulk-Select Add Root Group / Add Child Step (FR-027 to FR-031)

1. Click **Edit** on a template with an empty (or non-empty) step tree
2. Click **Root Group** (or **Add Root Group** if the tree is empty)
3. **Expected**: a dialog opens showing a checkbox table listing the available EUTR steps (from
   the real `eutr_steps` list), each row with a Requirement Type and Take From dropdown that are
   both disabled/greyed out; a footer reads "{N} step available - 0 selected"; the **Add** button
   is disabled (FR-027)
4. Tick 3 different step rows: **Expected** each ticked row's Requirement Type/Take From dropdowns
   become editable (default Optional/PO), the footer counter updates to "... - 3 selected", and
   **Add** becomes enabled
5. Change Requirement Type to Required and Take From to Upload manual on one of the 3 ticked rows
6. In the separate **"Add new step"** area, type a brand-new name not present in the steps list,
   and set its Requirement Type/Take From
7. **Expected**: the footer counter increases to "... - 4 selected" (3 ticked + 1 free-solo)
8. Click **Add**
9. **Expected**: all 4 steps appear immediately as **root-level** nodes in the tree (ParentId = 0),
   each showing the Requirement Type/Take From configured per row in step 5-6; the dialog closes
10. Select one of the newly added root steps, click **Child Step**
11. **Expected**: the bulk-select dialog reopens; the step just used as the parent's own master
    entry (if it was one of the ticked master rows) still appears in the list (it's now a sibling,
    not a child, of the target parent) — but any step that is ALREADY a direct child of this
    selected parent does NOT appear in the list (FR-029)
12. Tick 2 steps, click **Add**
13. **Expected**: both appear as children of the selected step (ParentId = selected step's Id)
14. Reopen **Add Child Step** on the SAME parent again: **Expected** the 2 steps just added in step
    12 are now excluded from the "available" list (already direct children of this parent)
15. Open the bulk-select dialog again, tick a step and type a free-solo name, then click **Cancel**
    (not Add)
16. **Expected**: dialog closes, nothing was added to the tree — reopening the dialog shows the
    previously-ticked step unticked and the free-solo entry area empty again
17. Click template **Save**
18. **Verify in DB**: the free-solo step name typed in step 6 was auto-created in `eutr_steps`
    (FR-030/FR-007a — same mechanism as Scenario 14), and all bulk-added `eutr_template_details`
    rows have the correct `ParentId`/`RequirementType`/`TakeFrom` per row
19. Select an existing step, click the **Edit** icon (pencil) on it (not Root Group/Child Step):
    **Expected** this still opens the single-step edit form in the right-hand panel (Step,
    Requirement Type, Take From, Save/Delete) — unchanged single-step behavior, not the bulk table
    (FR-031)

### Scenario 16: VendorCode Removal Verification (FR-039, Update 13)

1. Open TemplateBuilderPage (Edit) on any template: **Expected** no Vendor field/combobox appears
   anywhere on the page (header panel only shows Code, Name, Alert for, Set as default, Save)
2. Open the Create Template dialog: **Expected** no Vendor field (unchanged from Update 9 — this
   confirms nothing regressed by adding one)
3. Export templates to Excel (`GET api/eutr-templates/export`): **Expected** columns are exactly
   Code, Name, Alert for, IsDefault, Version — no "Vendor code" column
4. Import a template file using the OLD 4-column layout (Name, VendorCode, AlertFor, IsDefault):
   **Expected** the import either fails clearly or silently ignores the extra column depending on
   how `/speckit-tasks` implements column-count handling — verify actual behavior here and record it
5. **Verify in DB**: `DESCRIBE eutr_templates;` shows no `VendorCode` column
6. **Verify in DB**: existing rows that had a non-null `VendorCode` before this update's migration
   was applied have that data gone (no migration was performed, per the confirmed decision) — this
   is expected, not a bug

### Scenario 17: Apply to Customer (FR-032 to FR-038, Update 13)

1. On TemplateListPage, click the **Apply to Customer** icon on a template row (no longer disabled)
2. **Expected**: navigates to `/eutr/templates/apply/:id`, rendering **ApplyCustomerPage** with a
   breadcrumb showing the template's Code, and a table of existing Vendor mappings (empty state if
   none exist yet)
3. Click **Apply Vendor**: **Expected** a popup dialog opens with a Vendor combobox (calls
   `POST /api/dynamics/reference` with `refType=13`), From date (required), To date (optional)
4. Try Save with Vendor or From date empty: **Expected** validation error, dialog stays open
5. Select a Vendor, set From date = today, leave To date blank, Save
6. **Expected**: dialog closes, new mapping row appears in the table with the Vendor's name, From
   date, and To date shown as unlimited/blank
7. **Verify in DB**: `eutr_template_references` has a new row with the correct `TemplateId`,
   `VendorCode`, `FromDate`
8. Click **Apply Vendor** again, select the SAME Vendor with a From/To date range that overlaps the
   mapping from step 5-7
9. **Expected**: Save is rejected with an overlap error message
10. Apply the SAME Vendor to a DIFFERENT template with an overlapping date range
11. **Expected**: Save succeeds (overlap is only blocked within the same template, per FR-036)
12. Click the **Edit** icon on the mapping from step 5-7, change the To date, Save
13. **Expected**: the row updates in place (same mapping Id); **Verify in DB**: same `id`, updated
    `ToDate`, `UpdatedBy`/`UpdatedDate` changed
14. Click the **Delete** icon on a mapping row: **Expected** a confirmation dialog appears; confirm
15. **Expected**: the row disappears from the table; **Verify in DB**: the row is genuinely GONE
    from `eutr_template_references` (hard delete — no `IsDeleted` flag exists on this table)

### Scenario 18: Steps-Count Investigation (FR-042, Update 13 — verify-first)

1. Open DevTools Network tab, navigate to TemplateListPage
2. Find the `POST api/eutr-templates/get-all` request/response in the Network tab
3. **Expected/Check**: the raw JSON response includes a `stepsCount` field per item; compare its
   value against the actual number of `eutr_template_details` rows for that `TemplateId` (query the
   DB directly to confirm)
4. Repeat for a template that has gone through a version bump (Scenario 3b) — confirm the CURRENTLY
   DISPLAYED row's `stepsCount` reflects the steps copied to its (new) `TemplateId`, not the old
   hidden version's count
5. **If `stepsCount` is correct in the raw response but the UI shows 0/blank**: the bug is in
   `TemplateListPage.jsx`'s rendering — re-check the exact JSX binding (`tmpl.stepsCount ?? 0`) and
   whether the deployed frontend build is stale
6. **If `stepsCount` is already wrong/missing in the raw response**: the bug is server-side —
   escalate to checking whether the deployed backend build matches `EutrTemplatesRepository`'s
   current source (stale deploy is the most likely explanation, since the source code was verified
   correct during planning)
7. **Record the outcome here** (update this file) once verified: either "confirmed working as of
   [date]" with evidence, or "reproduced — root cause: [finding]" with the fix tracked as a task

**Outcome (2026-07-13, `/speckit-implement`)**: **Confirmed working — not a code defect.** Executed
the exact `GetPagedAsync` SQL (the query behind `POST api/eutr-templates/get-all`) directly against
the live dev database (`compliance_sys_db_260601`) and compared it to a ground-truth
`COUNT(*) FROM eutr_template_details` per template:

| Id | Code | VersionId | IsHide | Real detail count | `StepsCount` from the query |
|----|------|-----------|--------|--------------------|------------------------------|
| 7  | Templates-001 | 1 | 1 (hidden, old version) | 7  | — (not in grid result, IsHide=1) |
| 8  | Templates-002 | 1 | 1 (hidden, old version) | 26 | — (not in grid result, IsHide=1) |
| 9  | Templates-003 | 1 | 0 | 3  | 3  ✅ |
| 10 | Templates-001 | 2 | 0 (current version) | 7  | 7  ✅ |
| 11 | Templates-002 | 2 | 0 (current version) | 26 | 26 ✅ |

Every currently-visible row (`IsHide=0, IsDeleted=0`) returns a `StepsCount` that exactly matches
its real detail count — including two templates that had gone through a version bump (Id 10/11,
copied from the hidden Id 7/8), ruling out the "stale count carried over from the old version"
hypothesis too. Combined with the earlier static trace (repository SQL → DTO → JSON camelCase →
`TemplateListPage.jsx`'s `tmpl.stepsCount ?? 0` binding, all verified correct), there is no
reproducible defect in the current source against real data. **If the original bug report still
reproduces in the running application, the most likely explanation is a stale deployed
frontend/backend build** (the currently-running dev API process, PID-locked during this session,
could not be rebuilt/restarted to serve the latest binaries) — recommend restarting both the API
and frontend dev servers with a fresh build and re-checking before investigating further. FR-042/
SC-035 are marked resolved on this evidence; no code change was made for this item.

### Scenario 19: Import/Export Vendor Mapping on ApplyCustomerPage (FR-043 to FR-048, Update 14)

1. Open ApplyCustomerPage for a template that already has 2 existing mappings (from Scenario 17)
2. Click **Export**
3. **Expected**: downloads an `.xlsx` file with exactly 4 columns — `TemplateCode`, `VendorCode`,
   `FromDate`, `ToDate` — with 2 data rows matching the 2 existing mappings, `TemplateCode` equal to
   this template's Code on every row
4. Open ApplyCustomerPage for a DIFFERENT template that has zero mappings, click **Export**
5. **Expected**: downloads an `.xlsx` file with only the header row (no data rows) — this file is
   the "file template" referred to in the request; usable directly as an Import starting point
6. Edit the exported file from step 5, add 3 data rows: (a) `TemplateCode` = this template's Code,
   valid `VendorCode`, valid non-overlapping `FromDate`, blank `ToDate`; (b) `TemplateCode` =
   SOME OTHER template's Code, otherwise valid; (c) `TemplateCode` = this template's Code, blank
   `VendorCode`
7. Click **Import**, select the edited file
8. **Expected**: result shows `totalRows=3`, `successCount=1`, `failCount=2`; row (a) succeeds and
   appears in the mapping table (ToDate shown as "∞"/unlimited); row (b) fails with a
   "TemplateCode does not match the current template" error and does NOT create a mapping on the
   other template either; row (c) fails with a "Vendor is required" (or equivalent) error
9. **Verify in DB**: `eutr_template_references` has exactly 1 new row (from row (a)) tied to THIS
   template's `TemplateId`; no new row exists for the other template referenced in row (b)
10. Try clicking **Import** and selecting a non-`.xlsx` file (e.g. rename a `.csv` to have a `.xlsx`
    extension is not required for this check — pick any genuinely non-Excel file)
11. **Expected**: rejected immediately with a file-format error; no rows processed, mapping table
    unchanged
12. Prepare a file with 2 rows for the SAME VendorCode with overlapping `FromDate`/`ToDate` ranges
    (both rows valid TemplateCode, no pre-existing conflicting mapping), Import
13. **Expected**: the first row succeeds; the second row fails with an overlap error (same message
    as the manual Apply Vendor overlap case, Scenario 17 step 9) — only 1 new mapping is created
14. Prepare and Import a file that has only the header row (no data rows)
15. **Expected**: result shows `totalRows=0`, no error dialog, no mapping created — a
    "nothing to import" outcome, not a failure

**Outcome (2026-07-14, `/speckit-implement`)**: **Verified at the SQL/ClosedXML level, not through
the full HTTP+UI stack** — same environment limitation as Scenario 17/18 (no interactive browser
session available; the dev API process could not be restarted to serve the newly-built binaries).
Two direct smoke tests were run instead, exercising the exact logic the new code relies on:

1. **Excel parsing smoke test** (ClosedXML, in-process, no DB): built an in-memory workbook using
   the exact same header/cell layout as `EutrTemplateReferencesExportService`, then re-parsed it
   with a line-for-line copy of `EutrTemplateReferencesImportService`'s `ValidateHeader`/
   `TryParseExcelDate` logic. Results: a valid 4-column file parses correctly (TemplateCode/
   VendorCode read as strings, FromDate/ToDate round-trip through the native Excel date cell type);
   a header-only file (0 mapping rows) validates as a well-formed header with `LastRowUsed()` giving
   zero data rows to iterate — confirms the "Export doubles as the Import template" claim (FR-044)
   and the "header-only file → `totalRows=0`, not an error" claim (step 15) at the parsing level; a
   renamed/malformed header column (e.g. "Template Code" instead of "TemplateCode") is correctly
   rejected by the same header-validation check the service throws `InvalidOperationException` from;
   a hand-typed string date (`"2026-03-15"`, not a native Excel date cell) parses correctly via the
   string-format fallback path (reused verbatim from the existing `ComplMasterImportService`
   pattern, per Principle II).
2. **Database smoke test** (MySqlConnector, direct against the live dev DB
   `compliance_sys_db_260601`): confirmed the exact SQL semantics `AddAsync`/`HasOverlapAsync`
   already implement (unchanged by this update — the new Import service calls them, it does not
   reimplement them): inserting a fresh test mapping succeeds and is visible immediately
   (`eutr_template_references` row count +1); a second overlapping range for the SAME vendor in the
   SAME template is correctly flagged by the overlap-count query (COUNT=1, meaning the real
   `AddAsync` would reject it with the standard overlap error — this is what step 13's "second row
   fails" behavior rests on); the SAME vendor/date-range applied to a DIFFERENT template is
   correctly NOT flagged (COUNT=0 — confirms step 11 of Scenario 17 / FR-036's cross-template
   allowance still holds for Import-created rows, since Import uses the identical check); test row
   cleaned up afterward, dev DB left unchanged (final count verified back to the original value).

Both the backend (`dotnet build` on `ComplianceSys.Application.csproj`) and frontend
(`npm run build`) compile/build with 0 errors; `eslint` is clean on all 7 new/changed frontend files
(`ApplyCustomerPage.jsx`, `ImportMappingResultDialog.jsx`, the 2 new use cases, the API/repository/
domain-interface additions). The TemplateCode-mismatch check (FR-046/FR-048 — row (b) in step 6-9)
and the per-row OK/error result reporting (step 8) were verified by direct code review of
`EutrTemplateReferencesImportService.ImportFromExcelAsync` (a straightforward
`string.Equals(..., OrdinalIgnoreCase)` comparison against the template fetched via the existing
`IEutrTemplatesService.GetByIdWithDetailsAsync`, and a `result.Errors.Add(...)` per failed row) rather
than exercised end-to-end. **Recommended before sign-off**: restart the dev API process and frontend
dev server (both currently serving stale, pre-Update-14 binaries/bundles), then manually click
through Scenario 19 steps 1-15 in a real browser to close the gap between "verified by code/DB/
parsing-logic smoke test" and "verified end-to-end through the UI."

### Scenario 20: Clone Template (FR-050 to FR-054, Update 15)

1. Pick an existing template with at least 3 steps (2+ nesting levels) and 2 vendor mappings
   (from Scenario 17) as the source; note its Code, step count, and mapping count
2. On TemplateListPage, click the **Clone** icon on that row
3. **Expected**: a popup opens showing the source template's identifier (read-only), an empty **New
   template name** field, and an empty **Alert for** combobox
4. Leave **New template name** blank, click the Clone/Confirm button
5. **Expected**: validation error shown, no confirmation dialog appears, no new template created
6. Enter a name (e.g. "Cloned Template Test"), leave **Alert for** unselected, click Clone/Confirm
7. **Expected**: validation error shown, no confirmation dialog appears, no new template created
8. Enter a name and select an Alert for group, click Clone/Confirm
9. **Expected**: a confirmation warning dialog appears describing the copy about to happen
10. Click Cancel on the confirmation dialog
11. **Expected**: no new template created, dialog either stays open with the entered values or closes
    without side effects — either way, no DB change
12. Repeat steps 2, 3, 8, 9 and this time confirm
13. **Expected**: popup closes, list refreshes, a NEW row appears with a new auto-generated Code, the
    entered Name/Alert for, `versionId=1`, and no Default chip (not marked default)
14. **Verify in DB**: the new template's `eutr_template_details` has the same number of rows as the
    source, same `StepId`/`RequirementType`/`TakeFrom` per corresponding step, and the same
    parent-child structure (open the new template's Edit screen and visually confirm the tree matches
    the source's shape)
15. **Verify in DB**: `SELECT * FROM eutr_template_references WHERE TemplateId = <new Id>` returns the
    same number of rows as the source template's mappings, with matching VendorCode/FromDate/ToDate —
    open `/eutr/templates/apply/<new Id>` and confirm the mappings are visible there too
16. Edit the newly-cloned template (change Name, add/remove a step) and Save
17. **Expected**: only the cloned template changes; re-check the SOURCE template — unaffected
18. Clone the SAME source template a second time with a different Name
19. **Expected**: a second, independent new template is created (different Code from step 13's clone)
20. Clone a template that has 0 steps and 0 vendor mappings
21. **Expected**: the new template is created successfully with an empty step tree and no mappings —
    not treated as an error

**Outcome (2026-07-15, `/speckit-implement`)**: **Verified by code review + the SQL-level smoke test
above (Scenario 3b step 9's outcome), not through the full HTTP+UI stack** — same environment
limitation as every prior update in this session (no interactive browser available). Backend
(`dotnet build` on `ComplianceSys.Application.csproj`/`ComplianceSys.Infrastructure.csproj`) and
frontend (`npm run build`) both compile/build with 0 errors; `eslint` is clean on all 6 new/changed
frontend files (`CloneTemplateDialog.jsx`, `TemplateListPage.jsx`, `CloneEutrTemplatesUseCase.js`,
`eutrTemplatesApi.js`, `RestEutrTemplatesRepository.js`, `IEutrTemplatesRepository.js`). Verified by
direct code trace (not live click-through): (1) validation — `CloneTemplateDialog.jsx`'s
`handleValidateAndConfirm` sets per-field errors and returns early (never opening the confirmation
`ConfirmDialog`) when Name is blank or Alert for is unselected, matching steps 4-7; (2) cancel —
`ConfirmDialog`'s Cancel button calls `onClose` only, never `onConfirm`/`handleClone`, so nothing is
created, matching steps 10-11; (3) copy correctness — `CloneAsync`'s step-tree re-indexing was
traced against `EutrTemplatesRepository.InsertDetailsInternalAsync`'s existing client-index-to-real-Id
remap logic: ordering source details by real DB `Id` ascending guarantees every row's recorded
sequential position (`oldIdToSequentialIndex[d.Id] = i + 1`) is set before any LATER row could
reference it as a parent, satisfying the exact invariant that existing method already relies on for
every other Save path — no new tree-insert SQL was written; the vendor-mapping copy reuses the SAME
`CopyReferencesAsync` SQL verified end-to-end in Scenario 3b step 9's smoke test; (4) `IsDefault`
— `CloneAsync` constructs the new `EutrTemplates` entity with `IsDefault = 0` as a hardcoded literal
(never read from the source), so it structurally cannot inherit the source's flag, matching step 8;
(5) independence — `CloneAsync` always generates a fresh Code via `GenerateNextCodeAsync` (re-queries
`MAX` per call) and commits an independent transaction, so repeated clones (step 18-19) and clones of
an empty source (step 20-21, guarded by `sourceDetails.Count > 0` for the detail copy, and a
naturally-zero-row `INSERT ... SELECT` for the mapping copy) all follow the same unconditional code
path with no special-casing that could fail. **Recommended before sign-off**: restart the dev API
process (file-locked by a running instance throughout this session, same condition as Update 13/14)
and the frontend dev server, then manually click through Scenario 20 in a real browser to close the
gap between "verified by code/SQL-level smoke test" and "verified end-to-end through the UI."

### Scenario 21: Set as Default While Approved (FR-068, Update 18)

1. Approve a Draft template that is currently NOT the global default (via Scenario 3'b); note its Id
2. Note whichever OTHER template currently holds `IsDefault=1` (if any) from Scenario 5's setup
3. Click **Edit** on the Approved template; **Expected**: `TemplateBuilderPage` shows the read-only
   banner, Name/Alert for/Save/step-tree actions all disabled — EXCEPT the **Set as default**
   checkbox, which remains enabled
4. Tick the **Set as default** checkbox
5. **Expected**: a Yes/No confirmation dialog appears (same style as Approve/Request change);
   **verify in DB** `IsDefault` has NOT changed yet on either template
6. Click **No**
7. **Expected**: dialog closes, checkbox returns to unchecked, **verify in DB** no `IsDefault` value
   changed on any template
8. Tick the checkbox again, click **Yes**
9. **Expected**: success snackbar shown, checkbox stays checked, no navigation/redirect (Save button
   is still hidden/disabled — this did not go through the normal Save flow)
10. **Verify in DB**: this template's `IsDefault = 1`; the previously-default template from step 2
    (if any) now has `IsDefault = 0`; `Status`, `VersionId`, `Name`, `AlertFor`,
    `eutr_template_details`, and `eutr_template_references` for THIS template are all unchanged from
    before step 4
11. Refresh `TemplateListPage`; **Expected**: this row's Default chip is now shown, and it is still
    also shown as Status="Approved" (unaffected by the default change)
12. Reopen `TemplateBuilderPage` for this same template; **Expected**: still read-only (banner still
    shown, Name/Alert for/Save/step-tree still disabled), Set as default checkbox still checked and
    still enabled
13. Untick the **Set as default** checkbox, confirm **Yes**
14. **Expected**: success snackbar shown, checkbox now unchecked; **verify in DB** `IsDefault = 0` on
    this template, and NO other template was automatically re-promoted to default (global default may
    now be temporarily unset — this is expected, matching Scenario 5's existing "no default template"
    edge case)
15. **API check**: call `POST api/eutr-templates/{id}/set-default` directly with `{ "isDefault": 1 }`
    (byte 0/1, matching `EutrTemplatesRequestDto.IsDefault`'s existing type — not a JSON boolean)
    against a Draft template; **Expected**: succeeds identically (no `Status` precondition on this
    endpoint at all) — confirms the bypass is endpoint-wide, not conditioned on the template actually
    being Approved

**Outcome (2026-07-23, `/speckit-implement`)**: **Verified by code review, `dotnet build`, and
`npm run build`/`eslint`, not through the full HTTP+UI stack** — same environment limitation as every
prior update in this session (no interactive browser/seeded DB available). One deviation from the
original plan surfaced during implementation: `SetDefaultEutrTemplatesRequestDto.IsDefault` (and the
matching repository/service parameters) were implemented as `byte` (0/1), not `bool` — an audit of
`EutrTemplatesRequestDto.IsDefault` (already `byte`) and the `eutr_templates.IsDefault` column
(`TINYINT`) showed every existing IsDefault-related field in this feature uses the numeric
convention, so the new endpoint was made consistent with that rather than introducing the first
`bool`-typed field on this entity; the frontend's `eutrTemplatesApi.setDefault` converts its boolean
argument to `0`/`1` before sending, so step 15's request body above is `{ "isDefault": 1 }`, not
`{ "isDefault": true }`. Backend (`dotnet build src/ComplianceSys.Api/ComplianceSys.Api.csproj`) → 0
errors. Frontend (`npm run build`) → succeeded in 44.37s, `TemplateBuilderPage.[hash].js` chunk built
at 104.38 kB with no new errors; `eslint` clean on all 5 new/changed frontend files
(`TemplateBuilderPage.jsx`, `eutrTemplatesApi.js`, `RestEutrTemplatesRepository.js`,
`IEutrTemplatesRepository.js`, `SetDefaultEutrTemplatesUseCase.js`). Verified by direct code trace
(not live click-through): (1) Status-agnostic endpoint — `SetDefaultAsync` never reads
`existing.Status`, unlike `UpdateAsync`/`ApproveAsync`/`RequestChangeAsync`, matching step 15; (2)
scope — `SetDefaultAsync` calls only `ClearGlobalDefaultAsync`/`SetIsDefaultAsync`, touching no other
column/table, matching steps 9-10; (3) confirm gating — `handleToggleSetDefault` never calls the use
case directly, only `handleConfirmSetDefault` (wired to the dialog's `onConfirm`) does, matching steps
5-8; (4) Draft unaffected — the checkbox's Draft-path `onChange` branch is untouched from before this
update, matching step 12's implicit "no regression" expectation for the sibling Draft flow.
**Recommended before sign-off**: restart the dev API process (file-locked by a running instance
throughout this session, same condition as every prior update) and the frontend dev server, then
manually click through Scenario 21 in a real browser against a seeded DB (an Approved template plus
another template currently holding `IsDefault=1`) to close the gap between "verified by code/build
review" and "verified end-to-end through the UI."

### Scenario 13: Edge Cases

- Empty grid: **Expected** "No data" message, no errors
- ~~Invalid VendorCode in template: Expected Vendor name column shows blank~~ — **removed (Update
  13)**: no Vendor field exists on templates anymore, nothing to validate here
- AlertFor Id no longer found in `compl_group_email` (group deleted after template was saved):
  **Expected** Alert for column shows blank, no error for the rest of the grid (Update 7)
- `compl_group_email` has zero Alert groups (`GroupType=2`): **Expected** Alert for combobox shows
  no options and Save is blocked until at least one Alert group exists (Update 7)
- Deep nesting (3+ levels): **Expected** tree renders correctly with collapse/expand
- Back button on Edit page with NO step changes: **Expected** returns to list immediately, no warning
- Back button on Edit page WITH unsaved step add/edit: **Expected** shows confirmation dialog before leaving
- Edit step then Save template: **Expected** edited step values persist in DB
- Edit step then Cancel (inline): **Expected** step retains original values
- Two-column layout on wide screen (Edit page only): **Expected** wider header column on the left, narrower steps column on the right, side by side
- Edit a template exactly at the 24h boundary: **Expected** behavior follows `(now - CreatedDate) >= 24h` comparison consistently
- Empty EUTR Steps list: **Expected** Step combobox still accepts free-solo typed input (no longer requires creating a step first)
- Step combobox typed name matches an existing step differing only by case/whitespace: **Expected** the existing StepId is reused, no duplicate created
- Step combobox left blank/whitespace-only when saving a step row: **Expected** validation blocks adding the empty step
- Closing the Create Template dialog without clicking Save (Update 9): **Expected** no
  `eutr_templates` row created, list unchanged
- Opening Edit on a template that was just quick-created (0 steps, no Vendor) (Update 9):
  **Expected** step tree shows an empty state (not an error), Vendor combobox shows unselected
- After the Create Template dialog's Save succeeds (Update 9): **Expected** the app stays on
  TemplateListPage — it does NOT auto-navigate to the Edit screen
- Bulk-select dialog (Update 12) with all master steps already used as direct children of the
  target parent: **Expected** the table shows an empty "available" list, but the "Add new step"
  area remains usable
- Tick-all via the header checkbox then untick one row (Update 12): **Expected** the "selected"
  counter decreases by exactly 1, matching the remaining ticked rows
- Free-solo name typed in "Add new step" matches (case-insensitive, trimmed) a step already ticked
  from the master table, or another free-solo entry from a prior Add in the same session (Update
  12): **Expected** the existing dedupe-by-name rule (FR-007a) applies on Save — only one
  `eutr_steps` row is created/reused, no duplicates
- Clicking **Root Group** while a tree node is currently selected (Update 12): **Expected** the
  bulk-added steps still land at the tree **root** (ParentId=0) — the current selection only
  affects the **Child Step** button, not Root Group
- (Update 13) Opening ApplyCustomerPage for a template with zero mappings: **Expected** an empty
  table state, but "Apply Vendor" remains clickable
- (Update 13) Leaving To date blank when applying a Vendor: **Expected** treated as unlimited
  validity (no end date), shown as "∞"/blank in the mapping table
- (Update 13) Editing a mapping and NOT changing the Vendor/dates, just clicking Save: **Expected**
  the overlap check excludes the record being edited from comparison — Save succeeds
- (Update 13) Deleting a mapping: **Expected** a real DB row removal, not a flag update — confirmed
  by querying `eutr_template_references` directly after delete
- (Update 14) Importing a file missing/renaming one of the 4 required header columns: **Expected**
  the whole file is rejected before any row is read (no partial processing)
- (Update 14) Importing a row with `ToDate` earlier than `FromDate`: **Expected** that row fails
  validation, other valid rows in the same file are unaffected
- (Update 14) Importing a row that exactly duplicates an existing mapping's Vendor/FromDate/ToDate:
  **Expected** treated as an overlap error (Import never updates an existing mapping)
- (Update 14) Clicking Import/Export while a previous Import request is still in flight: **Expected**
  both buttons are disabled until the in-flight request resolves (no double-submit)
- (Update 15) Closing the Clone popup, or canceling its confirmation dialog, without confirming:
  **Expected** no new template is created, no data copied
- (Update 15) Cloning a template with 0 steps and 0 vendor mappings: **Expected** succeeds with an
  empty tree/mapping set on the new template — not an error
- (Update 15) Cloning a template that is currently marked Default: **Expected** the new template is
  NOT marked Default (`IsDefault=0`); the source template's Default flag is unaffected
- (Update 15) Cloning the same source template multiple times: **Expected** each Clone produces an
  independent new template with its own Code — no limit on repeat clones from one source
- (Update 15) A step in the source template's tree already has a real `StepId` (not a free-solo
  name): **Expected** Clone reuses that same `StepId` on the copied row — no new `eutr_steps` row is
  created during Clone
- (Update 15) After a version-up (≥24h Edit) on a template with existing vendor mappings:
  **Expected** the mappings are visible on `ApplyCustomerPage` for the NEW (now-current) TemplateId;
  the old (now-hidden) TemplateId's mapping rows remain in the DB, untouched
- (Update 16) Selecting 2+ rows (any Status mix), or 0 rows: **Expected** both Approve and Request
  change stay disabled — neither action supports bulk/no-selection
- (Update 16) Requesting change on an Approved template that has 0 steps and 0 vendor mappings
  (e.g. Approved immediately after Create, before adding anything): **Expected** succeeds normally,
  producing a new Draft row with an empty tree/mapping set — not an error
- (Update 16) Clicking Approve or Request change, then clicking No in the confirmation dialog:
  **Expected** no HTTP request is sent at all (verify via DevTools Network tab), and the row's
  Status/Chip is unchanged
- (Update 16) A template goes through Approve → Request change → Approve → Request change multiple
  times in a row: **Expected** `VersionId` increments by exactly 1 on each Request change (never on
  Approve), and every previous Approved row remains in the DB with `IsHide=1`, forming a complete,
  unbroken version history
- (Update 16) Calling `POST api/eutr-templates/{id}/approve` on a template that is already Approved,
  or `POST .../request-change` on one that is still Draft: **Expected** HTTP 400 with a clear message,
  no data changed
- (Update 18) Toggling Set as default on an Approved template that is currently the ONLY template
  (no other default to clear): **Expected** succeeds normally — `ClearGlobalDefaultAsync` is a no-op
  when no other row has `IsDefault=1`, not an error
- (Update 18) Unchecking Set as default on the Approved template that currently IS the global
  default, with no other template promoted to replace it: **Expected** succeeds — the system may end
  up with zero default templates, which is an accepted state (same as the existing Scenario 5
  behavior for Draft templates)
- (Update 18) Clicking the Set-as-default checkbox rapidly twice before the first confirm dialog is
  dismissed: **Expected** the second click either has no effect until the first dialog is resolved,
  or opens a second dialog reflecting the latest intended value — no duplicate/conflicting requests
  fire concurrently

## Post-Validation Checks

- [ ] TemplateListPage renders the Table + search-box layout (not a 9-column DataGrid) — see
      Scenario 1' (Update 10). (`TemplateListPageOld.jsx`'s 9-column DataGrid is checked separately,
      only if manually opened for reference — it is not part of the routed app)
- [ ] Alert for combobox loads only Alert groups (`GroupType=2`, `IsAddition=false`) via
      `GET /api/group-email`, no free-text typing allowed (Update 7)
- [ ] Alert for pre-selected correctly in Edit mode (Update 7)
- [ ] Grid's Alert for column shows the group Name, not the raw Id; saved `AlertFor` in DB is the
      numeric Id (Update 7)
- [ ] (Update 13 — supersedes the 4 checks below for TemplateBuilderPage) No Vendor field/combobox
      appears anywhere on TemplateBuilderPage or the Create Template dialog — Vendor no longer
      exists on `eutr_templates` at all
- [ ] ~~Vendor lookup works via `POST /api/dynamics/reference` (refType=13) in combobox (Edit mode
      only — no Vendor field on Create, Update 9) and grid~~ — moved to ApplyCustomerPage (Update 13)
- [ ] ~~Vendor combobox calls the generic reference endpoint (NOT the dedicated
      `GET /api/dynamics/vendors` endpoint from Update 2/3)~~ — now applies to ApplyCustomerPage
      (Update 13), see below
- [ ] ~~Vendor pre-selected correctly in Edit mode~~ — no longer applicable (Update 13)
- [ ] ApplyCustomerPage's Vendor combobox calls `POST /api/dynamics/reference` (refType=13), NOT the
      dedicated `GET /api/dynamics/vendors` endpoint (Update 13)
- [ ] Vendor reference response items expose `id`/`code` = VendorAccountNumber and
      `name` = VendorOrganizationName — verify in DevTools Network tab (now checked against
      ApplyCustomerPage, Update 13)
- [ ] Tree supports 3+ levels of nesting
- [ ] ParentId saved correctly for all levels (root=0, children=parent's Id)
- [ ] ParentId correct even for newly-added parent steps (temp ID mapping works)
- [ ] ~~Drag-and-drop reorders steps and updates DisplayOrder~~ — this item predates any real
      drag-and-drop implementation in this feature (see Update 17 items below for the actual,
      verifiable checks)
- [ ] Inline Edit step changes Step, RequirementType, TakeFrom correctly
- [ ] Only one step in edit mode at a time (auto-cancel previous)
- [ ] Two-column layout displays correctly with WIDER header column (left) and NARROWER steps column (right) — Edit page only
- [ ] Save button appears below the "Set as default template" checkbox in the left column, NOT in the title bar (Edit page)
- [ ] Title bar shows only the Back button (Edit page)
- [ ] Create Template dialog shows ONLY Name, Alert for, Set as default — no Vendor field, no step tree (Update 9)
- [ ] Create Template dialog's Save creates a template with 0 steps and `VendorCode = NULL`; dialog closes and the list refreshes without navigating to Edit (Update 9)
- [ ] Editing a freshly quick-created template (0 steps) lets the user add the first step and select a Vendor without errors (Update 9)
- [ ] The `/eutr/templates/add` route no longer exists / is no longer reachable from the list's Create button (Update 9)
- [ ] Step combobox (Add step and inline Edit step) accepts both selecting an existing option and typing a free-solo name
- [ ] Typing a new step name and saving the template auto-creates it in `eutr_steps`, visible immediately in the EUTR Steps screen
- [ ] Multiple steps with the same new typed name in one Save create only ONE `eutr_steps` row (no duplicates)
- [ ] Typing a name matching an existing step (case-insensitive/trimmed) reuses that step's Id, no duplicate created
- [ ] ~~Editing a template <24h old updates the row in place (same Id/VersionId/CreatedDate, no new
      row)~~ / ~~Editing a template ≥24h old creates a new version (new row, VersionId+1, old row
      IsHide=1)~~ — **superseded (Update 16)**: age no longer matters at all; see the two new checks
      below
- [ ] Back button with no unsaved step changes navigates immediately, no warning
- [ ] Back button with unsaved step add/edit shows a confirmation dialog; confirming discards the changes
- [ ] Soft delete sets IsDeleted=1, data preserved in DB
- [ ] Import handles valid/invalid rows correctly
- [ ] All UI text is in English (per FR-017)
- [ ] Navigation menu entry visible and routable
- [ ] After moving REQUIREMENT_TYPES/TAKE_FROM_OPTIONS/REQUIREMENT_LABELS/TAKE_FROM_LABELS to
      `utils/helpers.js`: RequirementType and TakeFrom comboboxes (Add step, inline Edit step, in
      both `StepFormRow.jsx` and `StepTree.jsx`) still show the same "Optional"/"Required" and
      "PO"/"Upload manual" options and render the same label text on the tree — no visual/behavior
      change (Update 8)
- [ ] TemplateListPage's Code/Name mapping is correct for every row: Code bold on top, Name as
      caption below (Update 10)
- [ ] TemplateListPage's Steps count matches the real number of steps in each template's tree, not
      a placeholder 0 (Update 11)
- [ ] TemplateListPage search box queries the server (visible in DevTools Network as a `Keyword`
      filter entry), debounced, resets to page 1, and matches across the full dataset — not just
      the currently loaded page (Update 11)
- [ ] TemplateListPage has a working pagination control (new — the prior mock had none) (Update 10)
- [ ] TemplateListPage's per-row checkbox + bulk-delete toolbar button work identically to
      `TemplateListPageOld.jsx`'s bulk delete (confirmation naming the count, soft delete, success
      snackbar) (Update 10)
- [ ] TemplateListPage's Clone and Apply-to-Customer icons are visibly disabled and unclickable —
      no mock Clone dialog, no navigation to a customers route (Update 10)
- [ ] Clicking Edit navigates to TemplateBuilderPage (not `EutrTemplatesAddEdit.jsx`'s 2-column
      layout) with real data loaded for that template (Update 10)
- [ ] TemplateBuilderPage's Add Root Group / Add Child Step dialogs use a free-solo Autocomplete
      over the real EUTR steps list (not the mock `Select`), and have no Type or FSC fields
      (Update 10)
- [ ] TemplateBuilderPage's Move Up / Move Down buttons correctly update DisplayOrder via
      `reorderSiblings` (Update 10)
- [ ] TemplateBuilderPage's right-hand panel shows the header form (Code/Name/AlertFor/Vendor/
      Default/Save) when no step is selected, and step detail (real RequirementType/TakeFrom, no
      Type/FSC) when a step is selected (Update 10)
- [ ] TemplateBuilderPage's Save persists via the real Update endpoint (conditional versioning
      still applies) and navigates back to the list on success (Update 10)
- [ ] TemplateBuilderPage's Back button shows the same unsaved-changes confirmation as
      `EutrTemplatesAddEdit.jsx` when step changes are unsaved (Update 10)
- [ ] `EutrTemplatesAddEdit.jsx` is no longer reachable via any route in the app (Update 10)
- [ ] Add Root Group / Add Child Step dialogs show a checkbox table of available master steps with
      "{N} step available - {M} selected" counter and disabled Add button at 0 selected (Update 12)
- [ ] Ticking multiple master steps + optionally typing one free-solo new name, then clicking Add,
      inserts all of them into the tree in a single action with the correct ParentId (root or
      selected parent) and per-row Requirement Type/Take From (Update 12)
- [ ] A master step already a direct child of the target parent is excluded from that dialog's
      "available" list, but reappears when adding to a different parent (Update 12)
- [ ] Canceling the bulk-select dialog discards all ticked rows and any typed free-solo entry —
      nothing is added to the tree (Update 12)
- [ ] Free-solo names typed via the bulk-select dialog's "Add new step" area are auto-created in
      `eutr_steps` on template Save, same as the existing single-add free-solo mechanism (Update 12)
- [ ] Edit (pencil icon) on an existing tree node still opens the single-step edit form — unaffected
      by the bulk-select dialog (Update 12, FR-031)
- [ ] `DESCRIBE eutr_templates;` confirms no `VendorCode` column exists (Update 13, FR-039)
- [ ] Export/Import Excel column layouts match the new 5-column/3-column shapes with no "Vendor
      code" column (Update 13)
- [ ] IsDefault uniqueness is verified GLOBAL (not per-vendor) — Scenario 5 (Update 13, FR-040)
- [ ] TemplateListPage's Apply to Customer icon is enabled and navigates to
      `/eutr/templates/apply/:id` (Update 13, FR-032)
- [ ] ApplyCustomerPage's Add/Edit dialog validates Vendor + From date required, To date ≥ From
      date when present, and blocks same-template/same-vendor date overlaps while allowing overlaps
      across different templates (Update 13, FR-036)
- [ ] ApplyCustomerPage's Delete performs a genuine hard delete on `eutr_template_references`
      (Update 13, FR-037)
- [ ] Steps-count investigation (Scenario 18) outcome recorded — either confirmed working with
      evidence, or a root cause identified and tracked as a follow-up task (Update 13, FR-042)
- [ ] ApplyCustomerPage shows Import and Export buttons in its toolbar (Update 14, FR-043)
- [ ] Export produces a 4-column (TemplateCode, VendorCode, FromDate, ToDate) `.xlsx`, including a
      header-only file when the mapping list is empty (Update 14, FR-044)
- [ ] Import rejects any non-`.xlsx` file with no rows processed (Update 14, FR-045)
- [ ] Import validates each row the same way the manual Apply Vendor dialog does (required
      Vendor/FromDate, ToDate ≥ FromDate, same-template/same-vendor overlap including against
      earlier valid rows in the same file) and rejects rows whose TemplateCode doesn't match the
      currently-open template, without creating a mapping on any other template (Update 14, FR-046,
      FR-048)
- [ ] Import shows a per-row OK/error result after processing, and the mapping table refreshes to
      show newly-created mappings (Update 14, FR-047)
- [ ] (Update 15) Version-up (≥24h Edit) on a template with existing vendor mappings copies those
      mappings to the new TemplateId; the old TemplateId's mapping rows remain untouched (FR-049)
- [ ] (Update 15) TemplateListPage's Clone icon is enabled (no longer disabled) and opens the Clone
      popup (FR-050)
- [ ] (Update 15) Clone popup requires both New template name and Alert for before allowing
      confirmation; shows a warning confirmation dialog before actually copying data (FR-051, FR-052,
      FR-054)
- [ ] (Update 15) A completed Clone produces a new template with its own Code, VersionId=1,
      IsDefault=0, and an exact copy of the source's step tree and vendor mappings (FR-053)
- [ ] Import never updates an existing mapping — a row matching existing data is rejected as an
      overlap, not silently merged (Update 14)
- [ ] `DESCRIBE eutr_templates;` shows a `Status` column, `TINYINT NULL DEFAULT 0`
      (Update 16, FR-055)
- [ ] A newly-created template (Create Template dialog) and a newly-Cloned template both have
      `Status = 0` (Draft) (Update 16, FR-056)
- [ ] Editing a Draft template ALWAYS updates the row in place (same Id/VersionId/CreatedDate),
      even when backdated far beyond the old 24h threshold — no age check remains (Update 16, FR-057)
- [ ] TemplateListPage shows a Status Chip per row (Draft/Approved) (Update 16, FR-062)
- [ ] Approve/Request change toolbar buttons are enabled ONLY when exactly 1 row is selected and its
      Status matches (Draft for Approve, Approved for Request change); disabled for 0 rows, 2+ rows,
      or a Status mismatch (Update 16, FR-058)
- [ ] Approve shows a Yes/No confirmation; Yes flips Status to Approved on the same row (no new
      row, no VersionId change); No leaves Status unchanged (Update 16, FR-059)
- [ ] Request change shows a Yes/No confirmation; Yes creates a new Draft row (VersionId+1) copying
      the full step tree and vendor mappings from the Approved row, and hides (IsHide=1, not
      deletes) the old Approved row; No leaves everything unchanged (Update 16, FR-060)
- [ ] Opening TemplateBuilderPage for an Approved template shows a read-only banner and disables
      every header field, Save, Root Group/Child Step, and each step row's Edit/Delete icons
      (Update 16, FR-061)
- [ ] Calling `PUT api/eutr-templates/{id}` directly against an Approved template returns HTTP 400
      (server-side rejection, not just a disabled frontend button) (Update 16, FR-057)
- [ ] Dragging a step to a new position among its same-level siblings on TemplateBuilderPage
      reorders it immediately in the UI and marks the screen dirty; the reordered `DisplayOrder`
      values persist correctly on Save, matching what Move Up/Move Down would produce for the same
      target position (Update 17, FR-064, FR-066)
- [ ] Move Up/Move Down buttons still work unchanged after this update — drag-and-drop is additive,
      not a replacement (Update 17, FR-064)
- [ ] Dragging a step and dropping it onto a step under a different parent does NOT change its
      `ParentId` — no reorder happens, no error shown (Update 17, FR-065)
- [ ] Drag-and-drop is disabled (no reorder possible) when the template's Status is Approved, same
      as Move Up/Move Down in that state; dragging works again after Request change returns the
      template to Draft (Update 17, FR-067)
- [ ] On an Approved template's TemplateBuilderPage, the Set-as-default checkbox is the ONLY enabled
      header field/control — Name, Alert for, Save, and all step-tree actions stay disabled
      (Update 18, FR-061/FR-068)
- [ ] Toggling Set as default while Approved shows a Yes/No `ConfirmDialog` before any request is
      sent; clicking No sends no HTTP request and leaves the checkbox at its prior value
      (Update 18, FR-068)
- [ ] Confirming Yes on that dialog calls `POST api/eutr-templates/{id}/set-default` and updates only
      `IsDefault` — Name/AlertFor/Status/VersionId/step tree/vendor mappings are unchanged afterward
      (Update 18, FR-068)
- [ ] Setting an Approved template as default correctly clears `IsDefault` on whichever other
      template previously held it (same global-uniqueness rule as FR-040), verified in DB
      (Update 18, FR-068)
- [ ] `POST api/eutr-templates/{id}/set-default` succeeds against a Draft template too — this
      endpoint has no `Status` precondition at all, unlike every other mutating endpoint on this
      controller (Update 18, FR-068)
