# Research: Compliance DB Migration Baseline

## 1. EF Core provider/version for MySQL on .NET 8

**Decision**: Use Oracle's official `MySql.EntityFrameworkCore` provider (the same family Identity uses via `options.UseMySQL(connectionString)`), pinned to **`8.0.17`** specifically (not the latest `8.x`), plus `Microsoft.EntityFrameworkCore.Design` `8.0.17`. Do not add `MySqlConnector` as a new direct dependency — the Oracle provider carries its own ADO.NET client, and Dapper access continues unchanged on `MySql.Data`.

**Version pin detail (discovered during implementation)**: Oracle's `MySql.EntityFrameworkCore` package versions each pin an exact `MySql.Data` dependency floor that tracks the connector's own (differently-numbered) release train — e.g. `8.0.28` requires `MySql.Data >= 26.7.0`, a connector major-version jump far ahead of the `9.4.0` already pinned by `ComplianceSys.Infrastructure.csproj` for Dapper. `dotnet build` surfaced this immediately as an `NU1605` package-downgrade error. Checking each `8.0.x` provider build's `MySql.Data` floor (`8.0.11→9.2.0`, `8.0.14→9.3.0`, `8.0.17→9.4.0`, `8.0.20→9.5.0`, `8.0.22→9.6.0`, `8.0.28→26.7.0`) found `8.0.17` is the exact build whose `MySql.Data` floor equals the project's already-pinned `9.4.0` — so this version is used specifically to guarantee **zero change** to the `MySql.Data` version the existing Dapper repositories run on, rather than the newest `8.x` build.

**Rationale**: compliance-sys-api targets `net8.0` (all four `src` projects), while Identity targets `net10.0` and uses `MySql.EntityFrameworkCore 10.0.7`. Oracle's connector/provider releases track the EF Core major version, so the `8.x` line is the net8-compatible equivalent of what Identity uses on net10 — same provider family, same `UseMySQL` API shape, so `EmbeddedSql`/`EmbeddedSqlMigrationsGenerator` port with no API changes. Reusing the same provider family (rather than switching to Pomelo) minimizes behavioral drift from the proven Identity mechanism this feature is explicitly copying.

**Alternatives considered**:
- *Pomelo.EntityFrameworkCore.MySql*: a popular community EF Core MySQL provider. Rejected — it's a different provider (`UseMySql`, lowercase `l`, different migrations SQL generator internals) than what Identity validated; switching providers reintroduces exactly the kind of divergence Reference-Pattern Reuse (constitution Principle II) warns against.
- *MySqlConnector as a new direct Dapper dependency, replacing `MySql.Data`*: out of scope. compliance-sys-api's existing Dapper stack (`MySql.Data`, `Res.Shared.Dapper`) is untouched by this feature; only a new, additive EF Core registration is introduced for the migration mechanism.

## 2. Hosting the EF Core `DbContext` and design-time migration generator

**Decision**: Add a minimal `ComplianceDbContext` in `ComplianceSys.Infrastructure/Persistence/` with no entity `DbSet`s (it exists solely to host migrations — Dapper remains the runtime read/write path for all application data). Register it in `ComplianceSys.Infrastructure/DependencyInjection.cs` via `services.AddDbContext<ComplianceDbContext>(o => o.UseMySQL(connectionString))`, reusing the same `DefaultConnection` connection string the Dapper factory already uses. Add `ComplianceSys.Api/DesignTimeServices.cs` implementing `IDesignTimeServices`, replacing `IMigrationsCodeGenerator` with the ported `EmbeddedSqlMigrationsGenerator`, mirroring `Identity.Api/DesignTimeServices.cs` exactly.

**Rationale**: Identity's mechanism requires an EF Core migrations pipeline to exist (a `DbContext` + `dotnet ef` project pair) purely as the *host* for the embedded-SQL convention — EF's own change-tracking/entity-mapping features aren't used here. Keeping the `DbContext` schema-empty avoids any EF ↔ Dapper mapping conflicts (no entity is EF-mapped and Dapper-mapped at once) and keeps the constitution deviation as narrow as possible: EF Core is added only as a migration-runner, not as a second general-purpose ORM. `ComplianceSys.Api` is already the ASP.NET Core "Sdk.Web" startup project (same shape as `Identity.Api`), so it's the natural home for `DesignTimeServices`, matching Identity's project layout.

**Alternatives considered**:
- *Map all Domain entities onto the `DbContext` (full EF model)*: rejected — turns this feature into a second full data-access layer, far exceeding its scope (a migration mechanism) and maximizing the constitution deviation instead of minimizing it.
- *Put the `DbContext` in `ComplianceSys.Api` instead of `Infrastructure`*: rejected — violates constitution Principle I (Layered Clean Architecture); persistence concerns belong in `Infrastructure`, matching Identity's layout (`Identity.Infrastructure/Persistence/IdentityDbContext.cs`).

## 3. Constitution deviation

**Decision**: Record the EF Core addition as a documented, justified deviation from the constitution's "Dapper-based data access" Technology & Structure Constraint (see Complexity Tracking below), scoped narrowly to schema/migration tooling. Recommend a follow-up `/speckit-constitution` amendment (out of scope for this feature's implementation) to formally note that EF Core is an approved migration-hosting mechanism alongside Dapper for runtime data access.

**Rationale**: The `/speckit-clarify` session for this feature explicitly resolved to keep EF Core (matching Identity's mechanism) after this conflict was surfaced, on the basis that the deviation is narrow (migrations only, no runtime EF usage) and that Identity already validates the same hybrid Dapper+EF-for-migrations pattern in production. Per the constitution's Governance section, deviations are permitted when justified in the plan rather than requiring a pre-emptive amendment.

**Alternatives considered**: Reversing to a Dapper-only runner (spec's originally-offered Option B) — rejected at the `/speckit-clarify` stage in favor of exact parity with Identity's proven mechanism.

## 4. Idempotent DDL for stored procedures/functions/views (MySQL)

**Decision**: Every "Up" script in `InitializeProject` follows the pattern `DROP PROCEDURE IF EXISTS <name>;` / `DROP FUNCTION IF EXISTS <name>;` / `DROP VIEW IF EXISTS <name>;` immediately followed by the `CREATE PROCEDURE|FUNCTION|VIEW` statement copied from `compliance_db.sql`. Each script is executed as a single batch (no `DELIMITER` markers needed) since `EmbeddedSql.ExecuteFolder` runs each `.sql` file's full text as one `migrationBuilder.Sql(...)` call, and MySQL's ADO.NET providers execute a single multi-statement command without requiring the `mysql` CLI's `DELIMITER` convention (`DELIMITER` is a client-side directive for the `mysql` CLI, not SQL — it must be stripped when porting each object out of the exported dump).

**Rationale**: Satisfies FR-016 (idempotent Up scripts, safe on already-provisioned environments) and resolves the `DELIMITER` edge case identified in `/speckit-clarify`/`/speckit-specify` — the exported file's `DELIMITER ;;` / `DELIMITER ;` wrapping is a `mysqldump`/`mysql`-CLI artifact and is not part of the object's real definition; the runtime executor (`MySqlConnector`/`MySql.Data`-family ADO.NET) sends the `CREATE PROCEDURE ... END` body as one command with no delimiter reassignment needed. This is exactly what Identity's `DemoObjects` example (`CREATE OR REPLACE VIEW ...` / `CREATE PROCEDURE ...`) already demonstrates working without `DELIMITER`.

**Alternatives considered**: `CREATE OR REPLACE PROCEDURE`/`FUNCTION` — rejected, MySQL does not support `OR REPLACE` for procedures/functions (only for `VIEW`); `DROP ... IF EXISTS` + `CREATE` is required for those two object types, so the same pattern is used uniformly across all three object types for consistency.

## 5. Dependency ordering for `InitializeProject`

**Decision**: Determine the Up-script order by static text search — for each procedure/function, scan its body for calls to other procedures/functions defined in the same export (`CALL <name>` / `<name>(`), and topologically sort so a callee's script number is lower than its caller's. Number files sequentially in that resolved order (`001_...`, `002_...`, ...). Down scripts reuse the same numbering but are invoked by `EmbeddedSql.ExecuteFolder` in ascending filename order per FR-002/FR-014, so the `Down` folder's files are named/ordered as the reverse dependency chain.

**Outcome (discovered during implementation)**: A precise scan (`grep`-based, excluding comment lines) of all 34 object bodies for `CALL <name>` statements and `<name>(` function-invocation syntax found **zero real cross-object references** among the 33 procedures and 1 function — every hit that looked like a dependency turned out to be a Vietnamese comment mentioning a sibling procedure's name in prose (e.g. `-- của sp_load_compl_by_conditions (SP chính)`), not an actual `CALL`. `compl_fn_get_rule_count` (the one function) is never invoked by any of the 33 procedures either. So the topological sort is vacuously satisfied by any order — the 34 objects are fully independent. The Up numbering used is: `001` = `compl_sp_export_master_template` (the user's explicit example, forced first), then the remaining 33 objects in alphabetical order (`002`–`034`). Down numbering is the exact reverse (`Down/001` drops the object created at `Up/034`, ... `Down/034` drops `Up/001`), preserving genuine reverse-order semantics per FR-014 even though it's not load-bearing today — if a future migration reintroduces a real dependency between these objects, the existing reverse-Down convention is already correct and doesn't need retrofitting.

**Rationale**: Satisfies FR-013/FR-014. Static call-site scanning (rather than trusting the export's alphabetical order) is the right check regardless of outcome — it's what actually rules out the failure mode FR-013 exists to prevent, rather than assuming independence.

**Alternatives considered**: Preserve the exported file's original top-to-bottom order — rejected as a *process*, even though the result (alphabetical-ish) turned out equivalent, because trusting dump order without verification is exactly the unverified assumption FR-013 guards against.

## 6. Retiring the legacy `DatabaseInitializer`/`Sqls/*` flow

**Decision**: `DatabaseInitializer.InitializeAsync()` and its `InitTables`/`InitProcedures` steps, plus the `Sqls/Tables`, `Sqls/Procedures`, and `Sqls/Migration` folders, are removed and replaced by `dotnet ef database update` (or the equivalent programmatic `dbContext.Database.Migrate()` call at startup) applying all EF Core migrations, starting with `InitializeProject`. The `Sqls/Migration` folder's numbered one-off scripts (01 through 26) are not replayed verbatim; their net effect on schema is what Story 2 (entity reconciliation) already captures as the *current, real* table shape, and their net effect on procedures/views is what `InitializeProject`'s Up scripts capture directly from the already-migrated `compliance_db.sql` export — so no separate migration is needed to "replay history."

**Rationale**: Matches the `/speckit-specify`-stage decision (FR-006, retire and replace) and keeps the baseline honest: `InitializeProject` reflects the database *as it exists today* (per the export), not a replay of every historical change, which is exactly what a "baseline" migration means in EF Core (the norm when adopting migrations on a pre-existing database).

**Alternatives considered**: Keep `DatabaseInitializer` as a fallback for a transition period — rejected per the explicit FR-006 decision; running two independent schema-provisioning code paths against the same database is itself a source of the "InitializeProject" idempotency edge case this feature is designed to close.

## 7. Migration application strategy (manual vs. auto-migrate at startup)

**Decision**: Migrations are applied as an explicit deployment step (`dotnet ef database update`), not automatically on API startup. `ComplianceSys.Api/Program.cs` gets no `dbContext.Database.Migrate()` call.

**Rationale**: Matches Identity exactly — `Identity.Api/Program.cs` has no auto-migrate call either; Identity's migrations are applied manually/via deployment tooling. Consistency with the reference pattern (constitution Principle II) outweighs the convenience of auto-migrate, and avoids a multi-instance API deployment racing to apply the same migration concurrently on startup.

**Alternatives considered**: `Database.Migrate()` in `Program.cs` — rejected, diverges from Identity's proven pattern and introduces startup-time migration risk (long-running DDL blocking app boot, concurrent-instance races) that a controlled deploy step avoids.
