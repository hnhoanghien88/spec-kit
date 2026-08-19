# Quickstart: Validate the Map for Product Test Visibility Fix

## Prerequisites

- Access to the dev MySQL database used by `compliance-sys-api` (to inspect/apply the stored
  procedure migration and query underlying tables).
- `compliance-sys-api` running locally against that DB.
- `compliance-client` running locally, logged in as a user who can open the compliance-management
  screen's "Map SharePoint Files to Compliance" dialog.

## 1. Confirm the root cause before fixing (data verification)

Find `MAS-01104`'s and `MAS-01105`'s master `Id`s, then compare:

```sql
SELECT Id, Code, VersionNo, ReplacedById, IsIndividual
FROM compl_masters WHERE Code IN ('MAS-01104', 'MAS-01105');

-- For each Id above:
SELECT cr.Id, cr.MasterId, cr.ComplianceId, cc.IsDelete
FROM compl_references cr
LEFT JOIN compl_compliances cc ON cr.ComplianceId = cc.Id
WHERE cr.MasterId = <id>;

SELECT * FROM compl_master_conditions WHERE MasterId = <id>;
```

**Expected finding**: `MAS-01104` has a `compl_references` row whose `compl_compliances.IsDelete = 1`
(or the compliance row is otherwise gone), while `MAS-01105` has none — confirming research.md R2.
If instead the two differ by `compl_master_conditions.ComplType = 1` or by version/`ReplacedById`,
re-open research.md R2's alternatives before proceeding with the fix below.

## 2. Apply the migration

1. Get the live procedure definitions (already confirmed identical to the repo copies as of
   research.md R6 — re-verify if time has passed):
   ```sql
   SHOW CREATE PROCEDURE compl_sp_get_compl_master_paging;
   SHOW CREATE PROCEDURE compl_sp_get_compl_master_missing_for_alert;
   ```
2. Run the new migration (`Sqls/Migration/24_...sql`, added by this feature) against the dev DB —
   it (a) redefines both procedures with the `IsDelete` guard added to the `compl_references`
   EXISTS check, and (b) inserts the missing `compl_master_conditions` row
   (`MasterId = 1179, ComplType = 1, RefTypeId = 4`) that restores `MAS-01104`'s current version to
   the same shape as its own prior version and sibling `MAS-01105`. Nothing else changes.
3. Re-run the data-verification query from Step 1 for `MAS-01104` — its computed `Status` (query
   `compl_sp_get_compl_master_paging` directly with `p_status = 'MISSING'`, `p_is_individual = 1`)
   should now include it, because of the restored `ComplType = 1` condition (not because of the
   `IsDelete` guard — confirm both changes landed, but expect the `ComplType` row to be what
   actually flips `MAS-01104` back to `'Missing'`, per research.md R6).

## 3. Validate end-to-end in the UI

1. Open the compliance-management screen → "Map SharePoint Files to Compliance" dialog.
2. Switch to the **Map for product test** tab.
3. Scroll (or search `MAS-01104` in the compliance search box) — the record must now appear,
   consistent with `MAS-01105`.
4. Confirm the `mapped / total` badge and footer progress count reflect the newly-visible record.
5. Regression check: switch to **Map general** and confirm no previously-visible master
   disappeared (the fix only affects records with stale references to soft-deleted compliances —
   it must not hide anything that was correctly `'OK'` before).
6. Regression check: for a master that has a real, active (non-deleted) mapped compliance, confirm
   it still correctly shows as `'OK'`/mapped and does **not** appear in "Map for product test" as
   "Missing".

## 4. Alert-flow regression (research.md R3)

If time/scope allows, spot-check `compl_sp_get_compl_master_missing_for_alert` output before/after
for a master with a stale reference — it should move from absent to present in the missing-alert
candidate set, matching the paging fix.
