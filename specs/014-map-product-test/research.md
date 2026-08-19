# Research: Map for Product Test — Complete Record Visibility

## R1: Where does the "Missing" eligibility filter actually live?

**Decision**: The bug is in the backend, not the frontend. `MapDataDialog.jsx` builds filters
`{Status: "Missing"}` + `{IsIndividual: 1}` correctly and calls the existing
`GetPagingComplianceMasterUseCase` → `RestComplianceMasterRepository.getAllPaging` →
`POST /compliance-master/get-all` → `ComplMasterController.GetPaged` →
`ComplMasterQueryService.GetComplMasterPagedAsync` → `ComplMasterRepository.GetComplMasterAsync`
→ stored procedure `compl_sp_get_compl_master_paging`. No frontend change is needed; the request
shape and response consumption are already correct.

**Rationale**: Traced the full call chain from the dialog's `buildFilters()`
(MapDataDialog.jsx:217-226) through to the stored procedure and confirmed the filters are passed
through unmodified at every layer.

**Alternatives considered**: Pagination/infinite-scroll bug on the frontend (`hasMore` calculation
in `useInfiniteComplianceMasterData.js`) — ruled out; the loop is a standard offset/limit pattern
with no code-path that could skip a page or an item within a returned page.

## R2: Why is a record excluded from the "Missing" filter even though it should qualify?

**Decision**: `compl_sp_get_compl_master_paging.sql` computes `Status` (and re-applies the same
logic as the `p_status = 'MISSING'` WHERE clause) using:

```sql
NOT EXISTS (SELECT 1 FROM compl_master_conditions mc_check
            WHERE mc_check.MasterId = cd.Id AND mc_check.ComplType = 1)
AND EXISTS (SELECT 1 FROM compl_references cr WHERE cr.MasterId = cd.Id)
→ Status = 'OK'  (else 'Missing')
```

The `EXISTS (... compl_references cr WHERE cr.MasterId = cd.Id)` check does **not** verify the
referenced compliance is still active. `compl_references` rows are never cleaned up when the
linked `compl_compliances` row is soft-deleted (`IsDelete = 1`) — the FK is `ON DELETE RESTRICT`
and there is no soft-delete cascade. So a master whose only reference points at a since-deleted
compliance is wrongly classified `'OK'` and silently excluded from the `Status = 'Missing'`
filter, even though it has zero active compliances — identical to how a master with no reference
row at all correctly stays `'Missing'`.

The same file already contains the **correct** pattern a few lines below, for the `TotalCompliances`
column (compl_sp_get_compl_master_paging.sql:234-241):

```sql
SELECT COUNT(DISTINCT cr.MasterId, cr.RefTypeId, cr.RefTypeValue)
FROM compl_references cr
INNER JOIN compl_compliances cc ON cr.ComplianceId = cc.Id
WHERE cr.MasterId = md.Id AND cc.IsDelete = 0
```

**Rationale**: This directly explains the reported symptom — `MAS-01104` most likely had a
compliance mapped and later removed (soft-deleted), leaving a stale `compl_references` row that
flips it to `'OK'`; `MAS-01105` never had a reference row, so it correctly stays `'Missing'` and
is visible. Both records are equally eligible by business intent (no active compliance mapped),
so the bug is the missing `IsDelete` guard, not a data problem to fix by hand.

**Alternatives considered**:
- *Master versioning (`LatestVersions` CTE / `ReplacedById`)* — possible if `MAS-01104` was
  superseded by a newer version row with different `Status`/`IsIndividual`. Cannot be ruled out
  from source alone; flagged as a verification step in quickstart.md rather than assumed.
- *Different `compl_master_conditions` data (ComplType flag) between the two codes* — same:
  plausible, not certain from source; verification step added.
- *Pagination cutoff (page size 25)* — unlikely given the reported symptom is total absence
  (including via search, which re-queries the backend), not "needs scrolling", but the fix
  doesn't depend on ruling this out.

## R3: Is this bug isolated to the paging endpoint, or duplicated elsewhere?

**Decision**: The identical buggy pattern (`EXISTS (compl_references cr WHERE cr.MasterId = cd.Id)`
with no `IsDelete` guard) is duplicated verbatim in
`compl_sp_get_compl_master_missing_for_alert.sql:37-51`, which drives the "Missing" alert
notification logic (`compl_sp_get_compl_master_missing`/alert flow), not just the mapping dialog.

**Rationale**: Same root cause, same incorrect eligibility outcome — a master with a stale
reference to a soft-deleted compliance would also be wrongly excluded from missing-document alert
emails. Leaving it unfixed there would perpetuate the same defect outside the scope the user
directly observed.

**Decision on scope**: Fix both procedures in the same migration, using the same corrected
`EXISTS (... INNER JOIN compl_compliances cc ON cr.ComplianceId = cc.Id WHERE cr.MasterId = cd.Id
AND cc.IsDelete = 0)` predicate already proven correct by the `TotalCompliances` subquery.

## R4: How should the fix be delivered, given this repo's stored-procedure convention?

**Decision**: Author a new numbered migration file (`Sqls/Migration/24_...sql`) that does
`DROP PROCEDURE IF EXISTS` + full `CREATE PROCEDURE` redefinition for both affected procedures,
changing only the `compl_references` EXISTS predicate (adding the `INNER JOIN compl_compliances`
+ `IsDelete = 0` guard) — no other logic altered. This mirrors the existing convention set by
`15_add_alerttype_to_compl_masters_procs.sql`.

**Rationale**: Migration 15's own header comment records that the `.sql` files under
`Sqls/Procedures/` can drift out of sync with what's actually deployed on the dev DB ("Cac ban sao
.sql cu duoi Sqls/Procedures/ da khong con khop voi definition dang chay tren DB"), and that the
established practice is to re-derive the migration's `CREATE PROCEDURE` body from
`SHOW CREATE PROCEDURE <name>` against the live dev DB before editing, then apply only the
intended delta. **Implementation-time requirement**: before writing the migration, run
`SHOW CREATE PROCEDURE compl_sp_get_compl_master_paging` and
`SHOW CREATE PROCEDURE compl_sp_get_compl_master_missing_for_alert` against the dev DB and base
the new `CREATE PROCEDURE` bodies on that live output (not blindly on the `Sqls/Procedures/*.sql`
copies read during this research), applying only the `IsDelete` guard fix. The `Sqls/Procedures/`
copies should also be updated to match, per repo convention of keeping them as an (eventually
synced) readable mirror.

**Alternatives considered**: Fixing at the Application/C# layer (e.g. re-deriving `Status` in
`ComplMasterQueryService` from `TotalCompliances` instead of trusting the SQL-computed `Status`
column) — rejected: `Status` is also used as a filter predicate inside the same SQL query (`WHERE`
clause, not just a returned column), so a C#-side patch could not fix which rows are even
returned/paginated in the first place; the fix must be in the SQL.

## R5: Secondary finding — `compl_sp_get_compl_master_paging_count` signature mismatch

**Observation**: `ComplMasterRepository.CountGetComplMasterAsync` (Repositories/ComplMasterRepository.cs:48-69)
calls `compl_sp_get_compl_master_paging_count` with 8 parameters (including `p_status` and
`p_is_individual`), but the procedure body under `Sqls/Procedures/compl_sp_get_compl_master_paging_count.sql`
only declares 3 parameters and applies none of the `Status`/`IsIndividual`/`ref_type` filters.

**Decision**: Treat as a **separate, out-of-scope** finding for this feature, not part of the fix.
Given R4's finding that `Sqls/Procedures/*.sql` copies are known to drift from the live DB
definition, this file is most likely just another stale copy (the deployed proc almost certainly
already has 8 params, matching migration 15's precedent), rather than a live production defect —
if it were truly a 3-vs-8 argument mismatch in production, every paged compliance-master list
would already be throwing on every request, which is not the reported symptom (the list loads and
shows counts, just an incomplete count/set). No spec requirement in `014-map-product-test`
depends on resolving this.

**Recommendation**: Flag for a follow-up: run `SHOW CREATE PROCEDURE
compl_sp_get_compl_master_paging_count` and reconcile the `Sqls/Procedures/` copy with reality in
a separate, dedicated change — do not bundle an unverified guess into this bug fix's migration.

## R6: Live-DB verification — confirmed vs. refuted, and revised scope

**Verified against the live dev DB** (`compliance_sys_db_260601` on localhost, via
`SHOW CREATE PROCEDURE` and direct table queries — not just the repo `.sql` copies):

- **Confirmed**: `compl_sp_get_compl_master_paging` and `compl_sp_get_compl_master_missing_for_alert`
  on the server are byte-for-byte identical to the `Sqls/Procedures/*.sql` copies analyzed in R2/R3.
  The missing-`IsDelete`-guard defect in the `compl_references` `EXISTS` check is real and deployed,
  not a stale-file artifact. R4's "don't trust the repo copy" caution turned out to be unnecessary
  for these two procedures (still worth keeping as a general implementation-time check).
- **Confirmed, and reversed**: `compl_sp_get_compl_master_paging_count` on the live server already
  has the full 8-parameter signature matching `ComplMasterRepository.CountGetComplMasterAsync`
  (`p_search_text, p_due_days, p_user_email, p_ref_type_id, p_ref_type_value, p_status,
  p_created_by, p_is_individual`), with complete filtering logic. The 3-parameter version in
  `Sqls/Procedures/compl_sp_get_compl_master_paging_count.sql` is a **stale repo mirror**, not a
  live bug — confirms R5's "likely stale copy" guess and closes it: no code/DB change needed, only
  an optional documentation-sync of the mirror file (not required for this fix).
- **Refuted for the reported case**: querying `MAS-01104` and `MAS-01105` directly showed the
  R2 "stale soft-deleted reference" hypothesis does **not** explain why `MAS-01104` is excluded.
  `MAS-01104`'s current version (`compl_masters.Id=1179`, `VersionNo=2`, superseding `Id=1178`)
  has exactly one `compl_references` row, and it points at an **active** (`IsDelete=0`) compliance
  (`COM-01668`). Applying the R2 fix (adding the `IsDelete=0` join) to this data changes nothing —
  `MAS-01104` v2 still computes `Status='OK'`.
  - The actual reason: `MAS-01104` v1 (`Id=1178`) had a `compl_master_conditions` row with
    `ComplType=1` on `RefTypeId=4` (item/product-code reference type) — the marker that, per the
    SP's logic, keeps a master `'Missing'` regardless of references (this is how "product test"
    masters needing ongoing per-item tracking are meant to behave; `MAS-01105`, which still has a
    `ComplType=1` condition, correctly always shows `'Missing'`). `MAS-01104`'s v2 conditions are
    both `ComplType=0` — the marker was lost when the master was edited/re-versioned, so v2 now
    evaluates under the simpler "OK once any reference exists" branch instead.
  - **Investigation into *why* v2 lost that marker (server-side versioning bug vs. one-off manual
    edit) was started but explicitly stopped by the user before a conclusion was reached.** The
    responsible, constitution-compliant choice (Principle III: backend changes limited to
    *verified* gaps) is to **not** guess at and modify the master-versioning/condition-save code
    path without a confirmed defect there. That investigation is out of scope for this feature and
    left as a follow-up if it recurs for other masters.

**Revised fix scope** (supersedes R2's original single-fix framing):

1. **Confirmed SQL defect (systemic, safe to fix)**: apply the `IsDelete=0` guard from R2/R3 to both
   `compl_sp_get_compl_master_paging` and `compl_sp_get_compl_master_missing_for_alert`. This is
   still correct and worth fixing — it prevents a real class of masters (ones whose only reference
   points at a soft-deleted compliance) from being wrongly hidden — even though it turned out not to
   be `MAS-01104`'s specific problem.
2. **Direct data correction for `MAS-01104`** (not a code change): restore its intended
   `compl_master_conditions` row with `ComplType=1` on `RefTypeId=4` for `MasterId=1179` (v2),
   mirroring the row its own v1 (`MasterId=1178`) and sibling `MAS-01105` (`MasterId=1180`,
   `RefTypeId=4`, `ComplType=1`) already have. This directly resolves the reported symptom
   (`MAS-01104` becomes visible in "Map for product test" again) without touching application code
   whose defect status is unconfirmed.
3. Root-causing *why* the marker was lost remains explicitly **out of scope** for this feature.

## Constitution alignment

Per Principle III (Reuse Existing Backend), this feature's backend changes are strictly a
**verified-gap fix** to an existing, already-deployed stored procedure — no controller, service,
DTO, entity, or endpoint contract is added, removed, or rewritten. The request/response shape of
`POST /compliance-master/get-all` is unchanged; only the internally computed `Status` value (and
therefore which rows satisfy `Status = 'Missing'`) is corrected.
