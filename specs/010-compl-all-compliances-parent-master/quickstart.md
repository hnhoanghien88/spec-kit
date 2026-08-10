# Quickstart: Validating All-Compliances Parent Master Coverage

## Prerequisites

- `compliance-sys-api` running against a MySQL database that already has `compl_masters`,
  `compl_compliances`, `compl_master_hierarchies` populated with at least one hierarchy of depth ≥ 2
  (a Root master with a child, ideally a grandchild too, to exercise multi-level coverage per
  Acceptance Scenario 1).
- **The updated procedure must actually be applied to that database.** `DatabaseInitializer.InitProcedures`
  only runs on a brand-new database (`InitializeAsync` returns early if the database already exists
  — see research.md). On an existing dev database, apply the updated procedure manually before
  testing:
  ```sql
  SOURCE compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Procedures/sp_load_compl_by_conditions.sql;
  ```
- A compliance/master setup where:
  - A Root master `A` has a matched compliance for some mapped input value (e.g. a Country value),
    so it produces a row with `Code <> ''` for that value.
  - A descendant master `B` (child or grandchild of `A` in `compl_master_hierarchies`) also has a
    row for the **same** mapped input value.
  - Optionally, a second, unrelated master `C` with no parent, to confirm it is unaffected
    (Acceptance Scenario 2).

## Steps

1. **Confirm the procedure change is applied** — inspect the routine definition and confirm it
   contains the new `UPDATE ... SET ParentMaster = ..., Status = 'UseParent'` block instead of the
   old `DELETE`:
   ```sql
   SHOW CREATE PROCEDURE sp_load_compl_by_conditions;
   ```

2. **Call the procedure directly** with a JSON payload matching master `B`'s conditions (same shape
   `p_json_data` already accepts today — see the procedure's `STEP 1` `JSON_TABLE` columns):
   ```sql
   CALL sp_load_compl_by_conditions('[{"Country": "<value used by A and B>"}]', CURDATE());
   ```
   Expected: the result set includes a `ParentMaster` column, positioned right after `MasterCode`.

3. **Verify master `B`'s row is retained and marked** (Acceptance Scenario 1, `B` starting out
   `MISSING` for the shared value): in the result set, find the row where `MasterCode = 'B'` for the
   shared mapped input value. Expected:
   - The row is present (not missing from the result set).
   - `Status = 'UseParent'`.
   - `ParentMaster = 'A'` (the Root master's code).
   - Master `A`'s own row is also present, unchanged, with its original `Status` (`APPLIED` or
     `MISSING`) — not `UseParent`.

3b. **Verify a covered row that was already `APPLIED` keeps its own Status** (Acceptance Scenario
   1b): repeat with a descendant master `B2` that already has its own matched compliance
   (`Status = 'APPLIED'`) for the same shared mapped input value as root `A`. Expected:
   - The row is present, `Status` is still `'APPLIED'` (NOT changed to `'UseParent'`).
   - `ParentMaster = 'A'` is still populated — only the `Status` change is skipped, not the
     `ParentMaster` assignment.

4. **Verify an unrelated/root master is unaffected** (Acceptance Scenario 2): find the row for
   master `C` (no parent). Expected: `ParentMaster = ''` and `Status` unchanged from before this
   feature.

5. **Verify a descendant with no actual parent coverage is unaffected** (Acceptance Scenario 3):
   pick a descendant master whose Root has no matched compliance (`Code = ''`) for the mapped input
   value in question. Expected: that descendant's row keeps its original `Status`
   (`APPLIED`/`MISSING`), not `UseParent`, and `ParentMaster = ''`.

6. **Verify through the existing API endpoint** (confirms the DTO change, not just the SQL):
   ```http
   POST /api/view-compliances/get-all
   Content-Type: application/json

   { ... same request body already used to test this endpoint today, targeting the product/customer/etc. combination that resolves to master B ... }
   ```
   Expected: the JSON response for master `B`'s item includes `"parentMaster": "A"` and
   `"status": "UseParent"` — confirming the value survives the Dapper mapping through
   `ViewCompliancesResponseDto` (research.md R4), not just visible in raw SQL.

7. **Spot-check unaffected downstream consumers** (research.md R6, no code change expected here):
   confirm `ComplianceMissingDrawer`'s MISSING-only filter and the sales-order missing-compliance
   alert (`compl_so_missing`) simply exclude the `UseParent` row from master `B` — same as they
   already exclude `APPLIED` rows today — with no error.

## Expected outcomes (ties back to spec.md Success Criteria)

- SC-001/SC-003: step 3 shows master `B`'s row present (not dropped), where previously it would have
  been absent from the result set entirely.
- SC-002: step 3/6 show the covering parent's code (`A`) directly on `B`'s row.
- SC-004: steps 4–5 show that rows unrelated to hierarchy coverage are byte-for-byte the same as
  before this change (aside from the new, empty `ParentMaster` field).

---

## US2: Compliances of Sales order tab (`compliance-view-so`, `ref-type=11`)

**Prerequisites**: Same hierarchy setup as above (masters `A`/`B`/`B2`/`C`), plus a sales order
whose product/customer/etc. conditions resolve to master `B` (and ideally `B2` and `C` too) via
the existing matching logic. Backend must already be serving `parentMaster`/`status = "UseParent"`
(steps 1-6 above passing is a prerequisite for this section).

8. **Open the tab**: navigate to `compliance-view-so?ref-type=11&codes=<sales order code>` and
   select the "Compliances of Sales order <code>" tab (the first tab).
9. **Verify the new "Parent master" column** (FR-008): confirm a column named "Parent master"
   appears immediately after "Master code". For master `B`'s row, confirm it shows `A`'s code; for
   master `C`'s row (no parent), confirm it is empty.
10. **Verify "Use parent" replaces "Missing"** (FR-009, Acceptance Scenario 1): for master `B`'s row
    (`status = "UseParent"`), confirm the "Expiry warning" column shows "Use parent" — not "Missing".
11. **Verify unaffected rows** (FR-010, Acceptance Scenario 2/3): confirm a genuinely missing row
    (no parent coverage) still shows "Missing", and master `B2`'s row (`status = "APPLIED"`,
    covered by a parent) shows its normal own expiry state in "Expiry warning" while still showing
    `A`'s code in "Parent master".
12. **Verify "Already have new version" precedence** (FR-011, Acceptance Scenario 4, optional —
    only if a row with `replacedById` set and `status = "UseParent"` can be set up): confirm
    "Expiry warning" still shows "Already have new version", not "Use parent", while "Parent
    master" still shows the covering parent's code.

### Expected outcomes (US2)

- SC-005: step 9 shows the covering parent's code directly in the tab, without needing to leave it.
- SC-006: step 10 shows "Use parent" where the tab previously showed "Missing" for the same row.
