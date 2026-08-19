# Data Model: Map for Product Test — Complete Record Visibility

No new tables, columns, entities, or DTOs are introduced by this feature. It corrects the
derivation of an existing computed value inside an existing stored procedure. This document
records the entities involved and the corrected derivation rule for reference during
implementation and review.

## Existing entities involved (unchanged shape)

- **`compl_masters`** (→ `ComplMasterResponse`) — one row per compliance master definition/version
  (`Id`, `Code`, `Name`, `Description`, `VersionNo`, `ReplacedById`, `IsIndividual`, ValidFrom/To,
  …). `IsIndividual` (0/1) is what the frontend filters on to distinguish the "Map general"
  (`IsIndividual = 0`) vs "Map for product test" (`IsIndividual = 1`) tabs.
- **`compl_master_conditions`** — per-master condition rows; a `ComplType = 1` row marks a master
  as requiring per-item/product-level conditions (distinct from `IsIndividual`).
- **`compl_references`** — link rows created when a compliance is mapped to a master
  (`MasterId`, `RefTypeId`, `RefTypeValue`, `ComplianceId`). **Not soft-deleted**: once a
  compliance is unmapped/deleted, its `compl_references` row is left behind (`ON DELETE RESTRICT`
  FK, no cascade, no status column of its own).
- **`compl_compliances`** — the actual compliance record a file mapping produces; carries the
  authoritative `IsDelete` (soft-delete) flag.

## Derived field: `compl_masters.Status` (computed, not stored)

Computed per-row inside `compl_sp_get_compl_master_paging` and
`compl_sp_get_compl_master_missing_for_alert` — not a persisted column.

| Rule | Before (buggy) | After (fixed) |
|---|---|---|
| A master is `'OK'` when | it has no `compl_master_conditions` row with `ComplType = 1`, **and** `EXISTS (SELECT 1 FROM compl_references cr WHERE cr.MasterId = cd.Id)` | it has no `compl_master_conditions` row with `ComplType = 1`, **and** `EXISTS (SELECT 1 FROM compl_references cr INNER JOIN compl_compliances cc ON cr.ComplianceId = cc.Id WHERE cr.MasterId = cd.Id AND cc.IsDelete = 0)` |
| Otherwise | `'Missing'` | `'Missing'` |

The fix adds the same `INNER JOIN compl_compliances cc ... AND cc.IsDelete = 0` guard that the
adjacent `TotalCompliances` column in the same procedure already uses correctly
(`compl_sp_get_compl_master_paging.sql:234-241`). This is a **behavior correction to an existing
derivation**, not a new business rule: a master reference pointing only at soft-deleted
compliances must count as "no active compliance", consistent with how `TotalCompliances` already
treats it.

### Validation rule affected

- **FR-001/FR-005** (spec.md): a compliance master with `Status = 'Missing'` and the requested
  `IsIndividual` value MUST appear in the corresponding tab's paged/searched results. The
  corrected `Status` derivation is what makes this rule hold for masters like `MAS-01104` whose
  only `compl_references` row points at a soft-deleted compliance.

## Data correction: `MAS-01104`'s missing `ComplType=1` condition (research.md R6)

Live-DB verification (research.md R6) showed the SQL fix above does **not** by itself resolve the
reported symptom for `MAS-01104`, because its exclusion is not caused by a stale reference — it has
one active (`IsDelete=0`) reference — but by its current version's `compl_master_conditions` rows
both being `ComplType=0`, where its own prior version (and sibling `MAS-01105`) have a `ComplType=1`
row on `RefTypeId=4`.

| Condition row | MasterId | RefTypeId | Operator | ComplType | Value |
|---|---|---|---|---|---|
| `Id=1600` (`MAS-01104` v1, superseded) | 1178 | 4 | `=` | **1** | `ALL` |
| `Id=1604` (`MAS-01104` v2, current) | 1179 | 4 | `=` | **0 ← wrong** | `ALL` |
| `Id=1605` (`MAS-01105`, sole version) | 1180 | 4 | `IN` | 1 | `ALL` |

Row `1604` is otherwise an exact match of row `1600` (same `RefTypeId`, same `Operator`, same
condition value `ALL`) — only `ComplType` differs (0 vs 1). This is precise enough evidence that
v2 was created by copying v1's condition row but failing to carry over `ComplType`, rather than a
manual/ad-hoc edit (which would be unlikely to reproduce every other field exactly). The
`MAS-01105` row's different `Operator` (`IN` vs `=`) is an unrelated, pre-existing difference
between the two masters' condition definitions, not part of the defect pattern.

**Corrective action** (data-only, no schema/derivation-logic change):
`UPDATE compl_master_conditions SET ComplType = 1 WHERE Id = 1604;` — restores the one changed
field on the existing row to match its own prior version, rather than inserting a new row. This is
scoped as a targeted data fix for this specific master, not a schema or application-code change —
see research.md R6 for why the underlying versioning-code root cause (likely: the master-version
copy/edit path not preserving `ComplType` when cloning a condition row) is left uninvestigated/out
of scope by explicit user decision, despite this stronger evidence pointing at it.

## Out of scope

- Why `MAS-01104`'s `ComplType=1` marker was lost when it was edited into v2 (server-side
  versioning bug vs. manual edit) — investigation explicitly deferred (research.md R6).

## Superseded: `compl_sp_get_compl_master_paging_count` parameter-count mismatch

research.md R5 originally found `compl_sp_get_compl_master_paging_count`'s repo-mirror `.sql` file
declares only 3 parameters while the C# caller passes 8, and guessed (R5/R6) this was purely a
stale-mirror documentation issue with the live proc already matching the 8-parameter caller. That
part was correct — but fetching the live definition during implementation (tasks.md T002/T015)
also revealed the live procedure has the **same missing `IsDelete` guard** as the other two fixed
procedures, in its own `Status` filter branches. This was **not** out of scope after all: it feeds
`TotalCount`, which the UI displays as the "mapped / total" badge (spec.md SC-003), so an
inconsistency here would surface as a real user-visible symptom. The same guard fix was applied to
this procedure too, in the same migration (see tasks.md T004a).
