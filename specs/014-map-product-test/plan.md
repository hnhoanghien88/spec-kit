# Implementation Plan: Map for Product Test — Complete Record Visibility

**Branch**: `014-map-product-test` | **Date**: 2026-08-19 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/014-map-product-test/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Two-part fix, per research.md R2/R3/R6 (both verified live against the dev DB, not just repo
files):

1. **Confirmed systemic SQL defect**: `compl_sp_get_compl_master_paging` and
   `compl_sp_get_compl_master_missing_for_alert` classify a master as `'OK'` (excluding it from
   `'Missing'`) whenever *any* `compl_references` row exists for it, even if that row's linked
   `compl_compliances` record was soft-deleted. Fixed by adding the same
   `INNER JOIN compl_compliances ... AND IsDelete = 0` guard already used correctly by the adjacent
   `TotalCompliances` subquery in the same procedure, via a new numbered migration, following this
   repo's existing "redefine from live `SHOW CREATE PROCEDURE`" convention (precedent: migration 15).
2. **`MAS-01104`'s specific reported symptom is a separate, data-level issue, not this SQL defect**:
   live verification showed `MAS-01104`'s only reference is active (not soft-deleted), so fix #1
   alone does not restore its visibility. Its current version's `compl_master_conditions` rows lost
   the `ComplType=1` marker (on `RefTypeId=4`) that its own prior version and sibling `MAS-01105`
   still have — that marker is what keeps a "product test" master always `'Missing'` until its
   per-item compliance is complete. Fixed by a direct, targeted data correction restoring that one
   condition row for `MAS-01104`'s current master version. *Why* the marker was lost is left
   uninvestigated/out of scope (research.md R6) — no application code is changed for this part.

Both fixes are scoped narrowly per Constitution Principle III (verified gaps only): fix #1 corrects
a defect confirmed present in the live, deployed procedure body; fix #2 corrects specific row data
without touching any unverified code path.

## Technical Context

**Language/Version**: MySQL stored procedures (existing `compliance-sys-api` DB layer); no
application-language change. Backend host is C# / .NET 8, but this fix does not touch C# code.

**Primary Dependencies**: Existing `ComplMasterController` → `ComplMasterQueryService` →
`ComplMasterRepository` → `compl_sp_get_compl_master_paging` / `compl_sp_get_compl_master_missing_for_alert`
call chain — reused as-is, no signature or DTO changes.

**Storage**: MySQL via Dapper (no EF Core/migrations framework), hand-written SQL under
`ComplianceSys.Infrastructure/Sqls/Migration/` (new numbered file) and `Sqls/Procedures/` (synced
copies), per this repo's established convention. Tables touched (read-only in the fixed query):
`compl_masters`, `compl_master_conditions`, `compl_references`, `compl_compliances`.

**Testing**: Primarily manual/SQL validation (see quickstart.md) — before/after query of the fixed
`Status` derivation for `MAS-01104`/`MAS-01105`, plus a UI regression pass on both dialog tabs. No
existing automated test suite covers this stored procedure directly (`ComplMasterQueryService`
tests, if any, mock the repository and would not catch a SQL-level defect); adding stored-procedure
level automated tests is out of scope, consistent with this repo's Dapper/SQL testing pattern
(none in place for other `compl_sp_*` procs).

**Target Platform**: Backend only (`compliance-sys-api`, MySQL) — no frontend/UI code change.
`MapDataDialog.jsx` and `useInfiniteComplianceMasterData.js` already call the endpoint correctly;
they need zero modification.

**Project Type**: Backend bug fix (single project: `compliance-sys-api/`, SQL-only change).

**Performance Goals**: N/A — same query shape/complexity, one additional `INNER JOIN` inside an
already-present `EXISTS` subquery pattern that mirrors an existing subquery in the same procedure.

**Constraints**: Must not change which masters are classified `'OK'` for any master whose reference
points at a still-active (non-deleted) compliance — only the previously-mis-handled
stale/soft-deleted-reference case may change classification (Missing↔OK). Must re-derive all
procedures' `CREATE PROCEDURE` bodies from the live dev DB (`SHOW CREATE PROCEDURE ...`) rather than
from the possibly-stale `Sqls/Procedures/*.sql` copies, per research.md R4. `research.md` R5's
originally-flagged `compl_sp_get_compl_master_paging_count` parameter-count concern turned out to
be a stale-mirror-only non-issue, but fetching its live definition surfaced the *same* `IsDelete`
guard defect present in it too — since it drives the UI's `TotalCount`/badge (spec.md SC-003), it
is now in scope alongside the other two procedures, not excluded (see data-model.md "Superseded").

**Scale/Scope**: One new migration file redefining **three** existing stored procedures
(`compl_sp_get_compl_master_paging`, `compl_sp_get_compl_master_missing_for_alert`, and —
discovered during implementation — `compl_sp_get_compl_master_paging_count`; ~1-line predicate
change each, repeated at each `EXISTS` call site within each procedure) plus one `UPDATE`
statement for the `MAS-01104` data correction (revised from a planned `INSERT` once the exact
matching prior-version row was found), all in the same migration; update the three corresponding
`Sqls/Procedures/*.sql` mirror files to match. No C#/entity/DTO/controller/frontend changes.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Layered Clean Architecture** — PASS (N/A change surface). No layer is touched except the
  Infrastructure-level SQL migration/procedure files, which is where hand-written Dapper SQL
  already lives per this principle. No controller/service/domain code changes.
- **II. Reference-Pattern Reuse** — PASS. This is a bug fix, not a new CRUD feature, so the
  `document-type` CRUD reference does not apply; instead it follows the precedent already set by
  `15_add_alerttype_to_compl_masters_procs.sql` for how to safely redefine an existing stored
  procedure in this repo (derive from live `SHOW CREATE PROCEDURE`, change only the intended
  delta).
- **III. Reuse Existing Backend** — PASS, this principle is the core of the fix. No endpoint,
  controller, service, DTO, or entity is added/rewritten/duplicated. The change is strictly a
  verified-gap correction (research.md R2/R3) to an existing stored procedure's internal
  `Status`-derivation predicate; the public contract of `POST /compliance-master/get-all` (request
  and response shape) is unchanged.
- **IV. Vietnamese Comments; Localizable UI Labels** — PASS. No UI. The new migration file's
  header comment will be written in Vietnamese, matching the style of migration 15.
- **V. Routing & Menu Registration** — N/A. No frontend screen/route change; the dialog and tab
  already exist and are already reachable.

No violations. Complexity Tracking section is not needed.

## Project Structure

### Documentation (this feature)

```text
specs/014-map-product-test/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

No `contracts/` artifact: this feature does not add or change any API contract.
`POST /compliance-master/get-all`'s request/response shape is unchanged — only the internally
computed `Status` value returned within the existing response is corrected. See data-model.md for
the derivation-rule change instead.

### Source Code (repository root)

```text
compliance-sys-api/
└── src/
    └── ComplianceSys.Infrastructure/
        └── Sqls/
            ├── Migration/
            │   └── 24_fix_compl_master_missing_status_stale_references.sql   # NEW — SP fix + MAS-01104 data correction
            └── Procedures/
                ├── compl_sp_get_compl_master_paging.sql                       # MODIFIED (mirror update)
                ├── compl_sp_get_compl_master_missing_for_alert.sql            # MODIFIED (mirror update)
                └── compl_sp_get_compl_master_paging_count.sql                 # MODIFIED (same guard fix, discovered in-flight)
```

No other files in `compliance-sys-api/` or `compliance-client/` change. In particular,
`compliance-client/src/presentation/pages/compliance-management/components/MapDataDialog.jsx` and
`.../hooks/useInfiniteComplianceMasterData.js` are confirmed correct as-is (research.md R1) and are
NOT modified.

**Structure Decision**: Single existing backend project (`compliance-sys-api/`), SQL-only change
within the already-established `Sqls/Migration/` + `Sqls/Procedures/` convention (Infrastructure
layer, per Principle I). No frontend changes; no new project or directory structure introduced.

## Complexity Tracking

*Not applicable — no Constitution Check violations.*
