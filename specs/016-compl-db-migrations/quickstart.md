# Quickstart: Validating the Compliance DB Migration Baseline

## Prerequisites

- .NET 8 SDK installed, `dotnet ef` tool available (`dotnet tool install --global dotnet-ef` if missing, matching the version used by `Microsoft.EntityFrameworkCore.Design` in `ComplianceSys.Infrastructure.csproj`).
- A MySQL 8 server reachable via the `DefaultConnection` string in `compliance-sys-api/src/ComplianceSys.Api/appsettings.Development.json` (or an equivalent local override), pointing at an **empty** database for the "fresh environment" scenario.
- A second MySQL database already provisioned by the legacy `DatabaseInitializer`/`Sqls/Procedures` flow (or a snapshot restored from `E:\Working\compliance_db.sql`) for the "already-provisioned environment" scenario.

## Scenario 1 — Story 1: mechanism works end-to-end (throwaway migration)

1. From `compliance-sys-api/src/ComplianceSys.Infrastructure`, add a trivial named migration:
   `dotnet ef migrations add QuickstartCheck --project . --startup-project ../ComplianceSys.Api --context ComplianceDbContext`
2. Put a single test view script in `Persistence/Sql/Migrations/QuickstartCheck/Up/001_quickstart_view.sql` (e.g. `CREATE OR REPLACE VIEW v_quickstart_check AS SELECT 1 AS ok;`) and the matching drop in `Down/001_quickstart_view.sql`.
3. Apply: `dotnet ef database update --project . --startup-project ../ComplianceSys.Api --context ComplianceDbContext`.
   **Expected**: `v_quickstart_check` exists in the target database (`SELECT * FROM v_quickstart_check;` returns `ok = 1`).
4. Roll back: `dotnet ef database update <PreviousMigrationName> --project . --startup-project ../ComplianceSys.Api --context ComplianceDbContext`.
   **Expected**: `v_quickstart_check` no longer exists.
5. Delete the `QuickstartCheck` migration files (`dotnet ef migrations remove` if never applied elsewhere) — this is a throwaway validation migration, not a real change.

## Scenario 2 — Story 3: `InitializeProject` on a fresh database

1. Point `DefaultConnection` at an empty database.
2. Run `dotnet ef database update --project src/ComplianceSys.Infrastructure --startup-project src/ComplianceSys.Api --context ComplianceDbContext` (applies `InitializeProject` plus any later migrations).
3. **Expected** (SC-001, SC-005): all 47 business tables, 33 stored procedures, and 1 function from `E:\Working\compliance_db.sql` exist; `information_schema.TABLES` count for the schema is 48 (47 + `__EFMigrationsHistory`), `information_schema.ROUTINES` count matches 34; no error was raised during apply (confirms FK-order table creation and procedure Up-script ordering, FR-013/FR-020).
4. Insert a row into any table (e.g. `compl_code_sequences`), then re-run step 2's command after clearing `__EFMigrationsHistory` (simulating re-apply against an already-provisioned schema).
   **Expected** (SC-006): zero errors; the inserted row is still present — `CREATE TABLE IF NOT EXISTS` never touches a table that already exists.
5. Roll back to before `InitializeProject`: `dotnet ef database update 0 --project src/ComplianceSys.Infrastructure --startup-project src/ComplianceSys.Api --context ComplianceDbContext`.
   **Expected** (SC-003): `information_schema.ROUTINES` count for the schema is 0, and `information_schema.TABLES` count is 1 (only `__EFMigrationsHistory` remains) — every object `InitializeProject` created is gone.

## Scenario 3 — Story 3 edge case: `InitializeProject` on an already-provisioned database

1. Point `DefaultConnection` at the database already seeded by the legacy `DatabaseInitializer`/`Sqls/Procedures` flow (objects already exist).
2. Run the same `dotnet ef database update` command as Scenario 2, step 2.
   **Expected** (FR-016): apply succeeds with no "already exists" errors, because every Up script drops-if-exists before creating.
3. Re-run the same command a second time with no schema changes in between.
   **Expected**: EF Core reports "no migrations to apply" (already at the latest migration) — this is the "fix a failing script and re-run from 001" recovery path (FR-017) exercised in its simplest form (nothing to fix, re-run is a no-op).

## Scenario 4 — Story 2: entity accuracy spot check

1. Open `data-model.md` §3 for the two known findings (`eutr_reference_details` missing entity; `ComplCodeSequence` missing `[Table]` attribute and carrying non-existent `CreatedBy`/`UpdatedBy` columns).
2. After implementation fixes are applied, re-run the same name/shape diff used to produce that table (compare every `[Table("...")]` entity against `E:\Working\compliance_db.sql`'s `CREATE TABLE` statements) and confirm both findings no longer reproduce, and no new mismatch was introduced.
   **Expected** (SC-002): 100% of the 47 business tables have a matching entity with matching columns/nullability/type.

## Scenario 5 — legacy flow retirement

1. Search the solution for remaining references to `DatabaseInitializer`, `Sqls/Tables`, `Sqls/Procedures`, `Sqls/Migration`.
   **Expected** (FR-006): no references remain in `ComplianceSys.Infrastructure`/`ComplianceSys.Api` startup code; the folders are removed from the repository.
2. Start the API against a completely empty, unmigrated database with no `DatabaseInitializer` call present (migrations are applied as an explicit `dotnet ef database update` deployment step, not automatically at startup — research.md §7, matching Identity's pattern).
   **Expected**: the application starts without attempting any schema provisioning of its own; API calls that hit missing tables/procedures fail with ordinary "table/procedure doesn't exist" database errors until `dotnet ef database update` is run — there is no dependency on the removed `Sqls/*` folders anywhere in the startup path.
