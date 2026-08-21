# Feature Specification: Compliance DB Migration Baseline

**Feature Branch**: `016-compl-db-migrations`

**Created**: 2026-08-21

**Status**: Draft

**Input**: User description: "áp dụng migration. trong link project Identity ở E:\Identity\Identity-api\src\Identity.Infrastructure\Persistence\Migrations đã gắn logic migration tự động embed view và stored, table. mang logic sang dự án compliance-sys-api. sau đó dựa vào file database đã export ở E:\Working\compliance_db kiểm tra với các file định nghĩa E:\Working\Eutr\compliance-sys-api\src\ComplianceSys.Domain\Entities xem table đủ và chính xác thực tế chưa, nếu chưa thì chỉnh lại. sau đó dựa vào file database trên, tạo Infrastructure\Persistence\Sql\Migrations\InitializeProject trong đó có Up, Down là trên của các store, view ở file database trên, ví dụ 001_compl_sp_export_master_template..."

## Clarifications

### Session 2026-08-21

- Q: The constitution's Technology & Structure Constraints state the backend uses Dapper-based data access, but FR-005 (from the initial spec draft) introduces a new EF Core `DbContext` to host the migration mechanism, matching Identity exactly. Keep EF Core, or reverse to a Dapper-only runner that avoids the conflict? → A: Keep EF Core (matches Identity's mechanism exactly). This is a deliberate deviation from the "Dapper-based data access" constraint and MUST be justified in the plan's Complexity/Tradeoffs notes per the constitution's Governance section; the plan should also note whether this warrants a constitution amendment (via `/speckit-constitution`) to formally recognize EF Core as an approved second data-access mechanism for schema/migration concerns.
- Q: Environments already provisioned by the old `DatabaseInitializer`/`Sqls/Procedures` flow already have these stored procedures/functions/views. Should `InitializeProject`'s "Up" scripts be skipped there (pre-baselined migration history), or should each script be idempotent (drop-if-exists then create) so it's safe to run everywhere? → A: Make every "Up" script idempotent — `DROP PROCEDURE/FUNCTION/VIEW IF EXISTS` followed by `CREATE`, so `InitializeProject` runs safely on both fresh and already-provisioned databases without environment-specific migration-history bookkeeping.
- Q: MySQL DDL statements each auto-commit, so a mid-migration failure (e.g., script 015 of 60) leaves scripts 001-014 already applied with no database-level rollback. What's the required recovery behavior? → A: Fix the failing script and re-run the whole "Up" set from script 001. Since every script is idempotent (FR-016), re-running already-applied scripts is safe and produces no duplicate or corrupted objects; no per-script resume/bookkeeping mechanism is required.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Repeatable, ordered migration mechanism for database objects (Priority: P1)

As a developer maintaining compliance-sys-api, when I add or change a stored procedure, function, view, or table, I want a single repeatable mechanism that applies my SQL changes to every environment in the same guaranteed order, the same way the Identity project already does it, so that every environment (developer machine, staging, production) ends up with an identical, predictable set of database objects instead of relying on manual script execution or first-run-only initialization.

**Why this priority**: Without this, every other part of the feature (baseline creation, future schema changes) has no reliable place to live or run. It is the foundation the other two stories depend on.

**Independent Test**: Can be fully tested by adding a small, throwaway named migration (e.g., a trivial view) using the new mechanism, applying it to a clean database, and confirming the object is created; then rolling it back and confirming the object is removed — without touching any other part of the codebase.

**Acceptance Scenarios**:

1. **Given** a clean/empty compliance database, **When** the migration mechanism is run, **Then** all database objects defined by applied migrations are created, in the exact file order declared within each migration.
2. **Given** a named migration folder containing an "Up" set and a "Down" set of SQL scripts, **When** that migration is rolled back, **Then** every object it created is removed and the database returns to its prior state.
3. **Given** two migrations where the second depends on an object created by the first (e.g., a stored procedure that calls a function), **When** both are applied in sequence, **Then** the dependent object is created only after its dependency exists (no "object does not exist" failures).
4. **Given** a developer who has already applied a migration, **When** they attempt to re-apply the same migration, **Then** the system does not silently corrupt or duplicate database objects.

---

### User Story 2 - Domain entities accurately reflect the real database schema (Priority: P2)

As a developer relying on `ComplianceSys.Domain.Entities` to read and write data, I want every entity class to accurately mirror its real database table (same table name, same columns, same nullability, same data shape) as captured in the exported database snapshot, so that queries and mappings behave correctly and no entity silently reads or writes the wrong shape of data.

**Why this priority**: Incorrect entities cause silent data bugs (missing columns, wrong types, wrong nullability) that are hard to trace. This must be corrected before the baseline migration in Story 3 is authored, since the baseline should describe the real, verified schema.

**Independent Test**: Can be fully tested by comparing each entity class against its corresponding `CREATE TABLE` statement in the exported database file column-by-column, and producing a pass/fail list per entity — independent of any migration mechanism work.

**Acceptance Scenarios**:

1. **Given** the exported database file and the current entity classes, **When** each business table (`compl_*`, `eutr_*`) is compared against its entity, **Then** every column present in the real table has a corresponding property on the entity with a compatible type and nullability.
2. **Given** a table that exists in the exported database file, **When** no matching entity class exists, **Then** this gap is identified and reported.
3. **Given** an entity class that references a table not present in the exported database file, **When** the comparison is performed, **Then** this mismatch is identified and reported.
4. **Given** an entity found to be missing columns, using the wrong type, or pointing at the wrong table name, **When** the correction is made, **Then** the entity is updated to match the real table exactly, without changing unrelated entities.

---

### User Story 3 - Baseline "InitializeProject" migration for existing stored procedures, functions, and views (Priority: P3)

As a developer setting up a new environment, I want a single, numbered "InitializeProject" migration that captures every stored procedure, function, and view currently defined in the exported database snapshot as ordered, individually named SQL scripts (Up = create, Down = drop), so that a fresh environment can be brought to the current baseline through the same mechanism used for all future changes, instead of through the old ad-hoc script folders.

**Why this priority**: This is the concrete deliverable the user asked for by example (`001_compl_sp_export_master_template...`), but it depends on Story 1 (the mechanism must exist first) and benefits from Story 2 (schema accuracy should be settled first so the baseline isn't built on incorrect assumptions).

**Independent Test**: Can be fully tested by applying only the "InitializeProject" migration to an empty database and confirming every stored procedure, function, and view from the exported database file now exists with an identical definition; then rolling it back and confirming all of them are removed.

**Acceptance Scenarios**:

1. **Given** the exported database file, **When** the "InitializeProject" migration's "Up" scripts are all applied in order, **Then** every stored procedure, function, and view from the exported file exists in the target database with a matching definition.
2. **Given** the "InitializeProject" migration has been applied, **When** its "Down" scripts are all applied in order, **Then** every stored procedure, function, and view it created is removed, and no other object is affected.
3. **Given** an object in the exported database file that depends on another object in the same file (e.g., a procedure calling a function), **When** the "Up" scripts run in numeric filename order, **Then** the dependency is created before the object that depends on it.
4. **Given** the "Down" scripts, **When** they run in numeric filename order, **Then** dependent objects are dropped before the objects they depend on (reverse of creation order).

---

### Edge Cases

- If a stored procedure/function/view already exists in the target database when the "InitializeProject" migration's "Up" scripts run (e.g., an environment previously initialized by the old ad-hoc `Sqls/Procedures` + `DatabaseInitializer` flow), each script drops the existing object first (`IF EXISTS`) before creating it, so the migration succeeds without a manual pre-check (see FR-016).
- How does the migration mechanism handle SQL objects whose definitions use `DELIMITER` statements (required for stored procedures/functions with embedded `;` in their body), since the exported file relies on `DELIMITER` blocks that a plain statement-by-statement executor cannot run as-is?
- What happens when an entity's real table has no primary key or no audit columns (e.g., `compl_so_missing`, which is a full-replace snapshot table) — does the verification in Story 2 still apply, and how are these correctly represented?
- How should the comparison in Story 2 treat infrastructure-owned tables that are not part of the application domain (e.g., the `hf_*` Hangfire job-scheduler tables), which have no corresponding entity by design?
- What happens if two objects in the exported database file have a circular or unclear dependency (e.g., mutual references) that cannot be resolved by simple ordering?
- If one of "InitializeProject"'s "Up" scripts fails partway through (e.g., script 015 of 60 errors), the migration is left partially applied (MySQL DDL auto-commits per statement, so there is no database-level rollback of scripts already run). Recovery is to fix the failing script and re-run the entire "Up" set from script 001; since every script is idempotent (FR-016), re-running already-applied scripts is safe (see FR-017).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST provide a mechanism to apply database object changes (tables, views, stored procedures, functions) to compliance-sys-api's database in a well-defined, deterministic order, following the same folder/ordering convention already proven in the Identity project (one named migration per change set, containing an ordered "Up" script set and an ordered "Down" script set).
- **FR-002**: The migration mechanism MUST execute the SQL scripts belonging to a migration's "Up" set in ascending filename order, and the scripts belonging to its "Down" set in ascending filename order.
- **FR-003**: Once a migration has been applied to an environment, its "Up" and "Down" scripts MUST be treated as immutable; any further change is expressed as a new, separate named migration rather than editing an already-applied one.
- **FR-004**: The mechanism MUST support SQL objects whose creation statements require `DELIMITER`-style multi-statement bodies (stored procedures and functions), executing each object's full definition as a single unit rather than splitting on every `;`.
- **FR-005**: compliance-sys-api MUST adopt an EF Core-based `DbContext` and EF Core migration tooling as the host for this mechanism, reproducing Identity's approach (an embedded-SQL helper plus a custom migrations code generator that wires each named migration's "Up"/"Down" folders into the generated migration) rather than a Dapper-only convention.
- **FR-006**: The existing `Sqls/Tables`, `Sqls/Procedures`, and `Sqls/Migration` folders and `DatabaseInitializer.cs` MUST be retired once the new EF Core migration mechanism (including the "InitializeProject" baseline) covers their content; new and existing environments provision and evolve the database solely through the new mechanism going forward, and the old ad-hoc folders/initializer are removed.
- **FR-007**: Domain entity classes in `ComplianceSys.Domain.Entities` MUST be verified, one by one, against the corresponding table definitions in the exported database snapshot (`compliance_db.sql`), covering: table name, presence of every real column, property nullability matching column nullability, and a compatible data type per column.
- **FR-008**: Any entity found to be missing columns, carrying columns that don't exist in the real table, mapped to the wrong table name, or using an incompatible type/nullability MUST be corrected to match the real table exactly.
- **FR-009**: Any real business table (`compl_*`, `eutr_*`) found to have no corresponding entity class MUST be reported as a gap.
- **FR-010**: Infrastructure-owned tables outside the application's business domain (the `hf_*` Hangfire scheduler tables) are out of scope for entity verification, since they are not, and are not expected to be, represented as domain entities.
- **FR-011**: The system MUST provide a single baseline migration named "InitializeProject" whose "Up" set creates every stored procedure, function, and view currently present in the exported database snapshot, and whose "Down" set drops every one of them.
- **FR-012**: Each object in the "InitializeProject" migration MUST live in its own individually numbered, descriptively named script (e.g., `001_compl_sp_export_master_template.sql`), mirroring the naming pattern already used in the Identity project's migrations.
- **FR-013**: The "Up" scripts of "InitializeProject" MUST be ordered so that any object depended on by another object (e.g., a function called from within a procedure) is created before the object that depends on it.
- **FR-014**: The "Down" scripts of "InitializeProject" MUST be ordered so that dependent objects are dropped before the objects they depend on — the reverse of the creation order.
- **FR-015**: *(superseded by FR-018–FR-020, below — table DDL was originally out of scope for "InitializeProject", relying solely on Story 2's entity verification; that left a real gap: a genuinely empty database could never be brought to a working schema through the migration mechanism alone. Scope was expanded post-implementation once this gap was raised.)*
- **FR-016**: Every "Up" script in the "InitializeProject" migration that creates a stored procedure, function, or view MUST be idempotent by dropping the object first if it already exists (`DROP ... IF EXISTS` then `CREATE`) — safe because these objects are stateless. Table-creating Up scripts follow a different, data-safe idempotency rule; see FR-019.
- **FR-017**: The migration mechanism MUST NOT require a per-script resume/bookkeeping capability for recovering from a mid-migration failure; the documented recovery path is to fix the failing script and re-apply the entire migration's "Up" set from the beginning, relying on script idempotency (FR-016, FR-019) to make that safe.
- **FR-018**: The "InitializeProject" migration's "Up" set MUST also create every business table (`compl_*`/`eutr_*`) present in the exported database snapshot, so that applying this single migration to a genuinely empty database is sufficient to reach a fully working schema (tables, procedures, and functions) — table DDL is no longer a separate, unaddressed concern left to Story 2 alone. `hf_*` (Hangfire-owned) tables remain excluded, consistent with FR-010 — Hangfire provisions its own schema automatically at application startup.
- **FR-019**: Table-creating "Up" scripts MUST use `CREATE TABLE IF NOT EXISTS` rather than the drop-and-recreate pattern used for procedures/functions (FR-016) — a table may already hold real data, and this migration MUST NEVER cause data loss on an environment where the table already exists. A pre-existing table's structure is left untouched by a no-op "Up" script rather than being altered to match.
- **FR-020**: Table "Up" scripts MUST be ordered so that a table referenced by another table's foreign key is created first (FR-013's ordering principle, applied to `FOREIGN KEY ... REFERENCES` relationships instead of procedure/function call sites); table "Down" scripts (`DROP TABLE IF EXISTS`) MUST run in the reverse order, so a dependent table is dropped before the table it references, avoiding foreign-key drop failures. Table scripts are numbered ahead of procedure/function scripts within "InitializeProject" (schema before code), per FR-012's single-numbered-script-per-object convention.

### Key Entities *(include if feature involves data)*

- **Migration (named change set)**: A single, immutable, ordered pair of script folders ("Up" and "Down") representing one database change. Identified by name; applied and rolled back as a unit.
- **InitializeProject migration**: The specific baseline migration that reproduces every stored procedure, function, and view from the exported database snapshot as of this feature's creation.
- **Domain Entity**: A C# class under `ComplianceSys.Domain.Entities` representing one real database table; must stay in sync with that table's actual column set.
- **Exported database snapshot (`compliance_db.sql`)**: The source of truth used both to verify entities (Story 2) and to author the baseline migration's script contents (Story 3).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can provision a brand-new, empty compliance-sys-api database and, using only the new migration mechanism, end up with every business table, stored procedure, function, and view that exists in the exported database snapshot — with zero manual SQL steps.
- **SC-002**: 100% of business (`compl_*`, `eutr_*`) domain entity classes accurately match their real table's column set (name, nullability, type) after this feature is complete, with any previously-found mismatches corrected.
- **SC-003**: Rolling back the "InitializeProject" migration removes 100% of the tables, stored procedures, functions, and views it created, leaving no orphaned objects behind.
- **SC-004**: A future schema change (new procedure, view, or table) can be introduced as one new named migration without editing any previously-applied migration's scripts.
- **SC-005**: Applying the "InitializeProject" migration's "Up" scripts in order produces zero dependency-ordering failures (e.g., no "procedure/function does not exist" or foreign-key errors) on a clean database.
- **SC-006**: Re-applying the "InitializeProject" migration's table-creating "Up" scripts against a database where those tables already contain data causes zero data loss — every pre-existing row remains intact.

## Assumptions

- The exported database file at `E:\Working\compliance_db.sql` is an accurate, current snapshot of the real compliance database's tables, views, functions, and stored procedures as of the date it was captured, and is the source of truth for both entity verification (Story 2) and the "InitializeProject" migration content (Story 3).
- "Table" comparison in Story 2 covers structural shape (name, columns, nullability, type) as needed for correct application-level data access; it does not require replicating storage-engine-level details like index names, collations, or auto-increment start values inside the C# entity classes.
- The `hf_*` tables belong to the Hangfire job-scheduling library and are managed by that library's own schema/storage provider, not by application-level domain entities or this feature's migrations.
- "View" objects are in scope for the "InitializeProject" migration per the user's request, even though the current exported snapshot happens to contain zero `CREATE VIEW` statements; if none exist at implementation time, the "views" portion of the baseline is simply empty.
- Numbering within "InitializeProject" (e.g., `001_...`, `002_...`) is per-object, following the exact example given by the user (`001_compl_sp_export_master_template`), rather than grouped by object type. Once table scripts were added (FR-018), tables occupy the lowest numbers (schema before code, `001`–`047`) and the 34 procedure/function scripts were renumbered to `048`–`081`, preserving their original relative order — the user's exact example is no longer the first script, but the "one script per object, numbered" convention itself is unchanged.
- Introducing an EF Core `DbContext` alongside the existing Dapper-based data access is a recognized deviation from the constitution's stated Technology & Structure Constraints; per Governance, this deviation is documented and justified in the plan rather than blocking this feature, and the plan should flag whether the constitution itself should be amended to reflect it.
