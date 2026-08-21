# Data Model: Compliance DB Migration Baseline

This feature is tooling/schema-reconciliation work, not a new business-domain feature, so
"data model" here covers (1) the migration mechanism's own conceptual shape and (2) the
reconciliation worklist between real tables and `ComplianceSys.Domain.Entities` classes.

## 1. Migration mechanism (conceptual)

| Concept | Shape | Notes |
|---|---|---|
| **Migration** | An EF Core migration class (`<timestamp>_<Name>.cs`) plus a matching folder `Persistence/Sql/Migrations/<Name>/{Up,Down}/*.sql` | Identified by name; immutable once applied (FR-003) |
| **Up script** | One `.sql` file per database object, `NNN_<object-name>.sql` | Executed in ascending filename order (FR-002); idempotent — `DROP ... IF EXISTS` then `CREATE` (FR-016) |
| **Down script** | One `.sql` file per database object, `NNN_<object-name>.sql` | Executed in ascending filename order; drops the object |
| **`ComplianceDbContext`** | EF Core `DbContext`, no `DbSet<T>` members | Hosts the MySQL connection + migration history table only; not used for runtime reads/writes (research.md §2) |
| **`__EFMigrationsHistory` table** | EF Core's built-in migration-tracking table | New to compliance-sys-api's database; created automatically on first `dotnet ef database update` |

## 2. `InitializeProject` object inventory

Counted directly from the exported snapshot `E:\Working\compliance_db.sql`:

| Object type | Count | In scope for `InitializeProject`? |
|---|---|---|
| Business tables (`compl_*`/`eutr_*`) | 47 | Yes (FR-018, added post-implementation — see below) |
| Stored procedures | 33 | Yes (FR-011) |
| Functions | 1 (`compl_fn_get_rule_count`) | Yes (FR-011) |
| Views | 0 | Yes by rule, empty in practice (Assumptions) |
| `hf_*` tables | 12 | No — Hangfire-owned, provisions its own schema at startup (FR-010, FR-018) |

**81 total Up/Down script pairs** (47 tables + 34 procedures/functions). Tables are numbered
`001`–`047` (FK-dependency order — a table is created only after every table its foreign keys
reference), procedures/functions `048`–`081` (their original independent-object order from
research.md §5, shifted by 47). Down scripts mirror the exact reverse: `001`–`034` drop
procedures/functions (unchanged from the original 34-object design), `035`–`081` drop tables in
reverse FK order (a table with a dependent must be dropped before the table it's referenced by
— actually, before the *dependent* table, so `DROP TABLE` never fails on an active foreign key).

**Table idempotency differs fundamentally from procedure idempotency** (FR-019): procedures/
functions use `DROP ... IF EXISTS` + `CREATE` because they're stateless — safe to destroy and
rebuild. Tables use `CREATE TABLE IF NOT EXISTS` — a table that already exists (and may hold
real rows) is left completely untouched, never dropped, never altered. This was verified live:
inserting a row, then re-running the full migration, left the row intact (SC-006).

## 3. Entity reconciliation worklist (Story 2)

47 real business tables (`compl_*`, `eutr_*`) were diffed by name against every
`[Table("...")]` attribute in `ComplianceSys.Domain.Entities/*.cs`. This is a **planning-time
spot check**, not the exhaustive column-by-column audit FR-007 requires — that full audit is
implementation work. Two concrete gaps already surfaced and should seed the task list:

| Finding | Detail |
|---|---|
| **Missing entity** | Table `eutr_reference_details` (FK → `eutr_references.Id`; columns `Id`, `RefId`, `ConditionType`, `ConditionValue`, `CreatedBy`, `CreatedDate`, `UpdatedBy`, `UpdatedDate`) has no corresponding class under `ComplianceSys.Domain.Entities` (FR-009 gap). |
| **Missing `[Table]` attribute + column mismatch** | `ComplCodeSequence.cs` has no `[Table(...)]` attribute at all (table name resolution is implicit/undocumented), and it inherits `BaseEntity`'s `CreatedBy`/`UpdatedBy` properties, but the real `compl_code_sequences` table has only `CreatedDate`/`UpdatedDate` — no `CreatedBy`/`UpdatedBy` columns. This is exactly the kind of drift FR-008 requires correcting. |

**Update (post-implementation)**: The full FR-007 column-by-column audit was completed during
`/speckit-implement`. Of 47 business tables, 28 matched their entity exactly; 19 had real
mismatches (nullable columns mapped to non-nullable properties with no safe default, a few
narrow-type FK columns like `byte`/`byte?` used for `bigint` foreign keys, two soft-delete flags
typed `byte`/`int` instead of `bool` for `tinyint(1)` columns, and four case-mismatched
`[Column]` names on `ComplSharepointFile`). All 19 were corrected; see `tasks.md` T016 for the
full per-entity list. `hf_*` tables remain out of scope per FR-010.

`hf_*` tables (12, Hangfire-owned) are out of scope per FR-010 and excluded from this worklist.

## 4. Validation rules carried into implementation

- A table counts as "matched" only when: entity `[Table]` name equals the real table name, every
  real column has a same-named property with compatible .NET type, and property nullability
  matches column nullability (`NOT NULL` ⇒ non-nullable property or a documented default).
- A stored procedure/function counts as "captured" in `InitializeProject` only when its Up script
  reproduces the exported `CREATE PROCEDURE|FUNCTION` body verbatim (minus the `DELIMITER`
  wrapping, which is a `mysql`-CLI artifact — research.md §4) and its Down script drops it.
