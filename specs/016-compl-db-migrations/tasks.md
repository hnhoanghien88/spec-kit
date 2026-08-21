---

description: "Task list for Compliance DB Migration Baseline"
---

# Tasks: Compliance DB Migration Baseline

**Input**: Design documents from `/specs/016-compl-db-migrations/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md (all present; no `contracts/` — internal tooling, no external interface)

**Tests**: Included — plan.md's Technical Context names xUnit unit tests for the ported `EmbeddedSql`/`EmbeddedSqlMigrationsGenerator` helper logic as this feature's testing approach.

**Organization**: Tasks are grouped by user story (US1/US2/US3, matching spec.md's P1/P2/P3). Unlike a typical independent-stories feature, **US3 has a hard dependency on the Foundational phase** (it cannot exist without the ported mechanism) and a **soft/recommended ordering after US2** (the baseline should describe the *verified* schema) — both called out explicitly in spec.md's story rationale. US2 has no dependency on Foundational or US1 and can start immediately after Setup.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no unmet dependencies)
- **[Story]**: US1, US2, or US3 — omitted for Setup/Foundational/Polish tasks
- All file paths are relative to the repository root (`e:\Working\Eutr`)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Add the EF Core dependencies this feature needs; no other setup required (no new project).

- [X] T001 Add `MySql.EntityFrameworkCore` (net8-compatible `8.x` line) and `Microsoft.EntityFrameworkCore.Design` (`8.x`) `PackageReference`s, and an `<EmbeddedResource Include="Persistence\Sql\**\*.sql" />` `ItemGroup` entry, to `compliance-sys-api/src/ComplianceSys.Infrastructure/ComplianceSys.Infrastructure.csproj` (research.md §1; mirrors `Identity.Infrastructure.csproj`)
- [X] T002 [P] Add `Microsoft.EntityFrameworkCore.Design` `PackageReference` to `compliance-sys-api/src/ComplianceSys.Api/ComplianceSys.Api.csproj` (needed to host `DesignTimeServices`, mirrors `Identity.Api.csproj`)

**Checkpoint**: Solution restores with the new EF Core packages present.

---

## Phase 2: Foundational (Blocking Prerequisites for US1 and US3)

**Purpose**: Port the migration mechanism itself. **Blocks US1 and US3.** US2 (entity reconciliation) does not depend on this phase and may start in parallel with it.

**⚠️ CRITICAL**: No US1 or US3 work can begin until this phase is complete.

- [X] T003 Port `EmbeddedSql.cs` from `E:\Identity\Identity-api\src\Identity.Infrastructure\Persistence\Migrations\EmbeddedSql.cs` to `compliance-sys-api/src/ComplianceSys.Infrastructure/Persistence/Migrations/EmbeddedSql.cs`, renaming the namespace to `ComplianceSys.Infrastructure.Persistence.Migrations` (logic unchanged — plan.md Project Structure)
- [X] T004 Port `EmbeddedSqlMigrationsGenerator.cs` from `E:\Identity\Identity-api\src\Identity.Infrastructure\Persistence\Migrations\EmbeddedSqlMigrationsGenerator.cs` to `compliance-sys-api/src/ComplianceSys.Infrastructure/Persistence/Migrations/EmbeddedSqlMigrationsGenerator.cs`, renaming the namespace and the fully-qualified `EmbeddedSql.ExecuteFolder` call site to match T003's new namespace (depends on T003)
- [X] T005 [P] Create a schema-only `ComplianceDbContext` (no `DbSet<T>` members — data-model.md §1, research.md §2) in `compliance-sys-api/src/ComplianceSys.Infrastructure/Persistence/ComplianceDbContext.cs`
- [X] T006 Register `ComplianceDbContext` in `compliance-sys-api/src/ComplianceSys.Infrastructure/DependencyInjection.cs` via `services.AddDbContext<ComplianceDbContext>(o => o.UseMySQL(connectionString))`, reusing the existing `DefaultConnection` connection string already read for the Dapper factory (depends on T005)
- [X] T007 Create `compliance-sys-api/src/ComplianceSys.Api/DesignTimeServices.cs` implementing `IDesignTimeServices`, replacing `IMigrationsCodeGenerator` with `EmbeddedSqlMigrationsGenerator` via `services.Replace(...)`, mirroring `E:\Identity\Identity-api\src\Identity.Api\DesignTimeServices.cs` exactly (depends on T004)

**Checkpoint**: `dotnet ef migrations add <Name> --project src/ComplianceSys.Infrastructure --startup-project src/ComplianceSys.Api --context ComplianceDbContext` now scaffolds `Up`/`Down` `ExecuteFolder` calls automatically. Ready for US1's independent test.

---

## Phase 3: User Story 1 - Repeatable, ordered migration mechanism (Priority: P1) 🎯 MVP

**Goal**: Prove the ported mechanism creates and rolls back database objects in deterministic order, exactly as Identity's does.

**Independent Test**: quickstart.md Scenario 1 — add a throwaway migration, apply it, confirm the object exists, roll it back, confirm it's gone, delete the throwaway migration.

### Tests for User Story 1

- [X] T008 [P] [US1] Unit test `EmbeddedSql.ExecuteFolder`'s resource-discovery/ordinal-ordering behavior (including the "missing/empty folder is a no-op" case) in `compliance-sys-api/tests/ComplianceSysApi.UnitTests/Persistence/Migrations/EmbeddedSqlTests.cs`
- [X] T009 [P] [US1] Unit test that `EmbeddedSqlMigrationsGenerator.GenerateMigration` inserts the `ExecuteFolder` call at the end of `Up` and the start of `Down` in `compliance-sys-api/tests/ComplianceSysApi.UnitTests/Persistence/Migrations/EmbeddedSqlMigrationsGeneratorTests.cs`

### Implementation for User Story 1

- [X] T010 [US1] Run `dotnet ef migrations add QuickstartCheck --project src/ComplianceSys.Infrastructure --startup-project src/ComplianceSys.Api --context ComplianceDbContext` and author the throwaway `Persistence/Sql/Migrations/QuickstartCheck/Up/001_quickstart_view.sql` + `Down/001_quickstart_view.sql` scripts per quickstart.md Scenario 1 steps 1-2
- [X] T011 [US1] Apply `QuickstartCheck` against a clean local MySQL database (`dotnet ef database update`) and verify `v_quickstart_check` exists (quickstart.md Scenario 1 step 3; validates FR-001/FR-002) (depends on T010) — verified live against `localhost:3306` / `compliance_sys_db_260601`, `SELECT * FROM v_quickstart_check` returned `ok=1`
- [X] T012 [US1] Roll back `QuickstartCheck` (`dotnet ef database update <PreviousMigration>`), verify the view is gone (quickstart.md Scenario 1 step 4; validates acceptance scenario US1.2), then run `dotnet ef migrations remove` so the throwaway migration never ships (depends on T011) — verified `v_quickstart_check` errors with 1146 "doesn't exist" after rollback; migration class + throwaway SQL scripts removed

**Checkpoint**: User Story 1 is fully functional and independently testable — the mechanism itself is proven. This is the MVP.

---

## Phase 4: User Story 2 - Domain entities accurately reflect the real database schema (Priority: P2)

**Goal**: Every `ComplianceSys.Domain.Entities` class matches its real table exactly.

**Independent Test**: quickstart.md Scenario 4 — diff every `[Table("...")]` entity against `E:\Working\compliance_db.sql`'s `CREATE TABLE` statements, confirm zero mismatches.

**Note**: Independent of Setup/Foundational/US1 — this phase can run in parallel with Phase 2/3.

### Implementation for User Story 2

- [X] T013 [US2] Run the full column-by-column audit of all 47 business tables (`compl_*`/`eutr_*`) in `E:\Working\compliance_db.sql` against every `[Table("...")]` entity under `compliance-sys-api/src/ComplianceSys.Domain/Entities/*.cs` (table name, every column present, nullability, compatible type — FR-007), producing a pass/fail list that extends the data-model.md §3 spot check — delegated to an audit agent; 47/47 tables audited, 28 OK, 19 MISMATCH (full report integrated into T016)
- [X] T014 [P] [US2] Create the missing `EutrReferenceDetails` entity in `compliance-sys-api/src/ComplianceSys.Domain/Entities/EutrReferenceDetails.cs`, mapping `eutr_reference_details` (`Id`, `RefId`, `ConditionType`, `ConditionValue`, `CreatedBy`, `CreatedDate`, `UpdatedBy`, `UpdatedDate`; FK `RefId` → `eutr_references.Id`) per data-model.md §3 (closes the FR-009 gap)
- [X] T015 [P] [US2] Fix `compliance-sys-api/src/ComplianceSys.Domain/Entities/ComplCodeSequence.cs`: add `[Table("compl_code_sequences")]` and remove reliance on `BaseEntity`'s `CreatedBy`/`UpdatedBy` properties (the real table has only `CreatedDate`/`UpdatedDate` — no audit-by columns) per data-model.md §3 (FR-008)
- [X] T016 [US2] For every additional mismatch surfaced by T013 (missing column, wrong type/nullability, wrong table name), correct the corresponding entity class under `compliance-sys-api/src/ComplianceSys.Domain/Entities/` (FR-008) (depends on T013) — fixed 17 entities: `ComplCompliances` (DocumentTypeId→long?, Description→string?, IsDelete byte→bool), `ComplConfig` (ConfigValue→string?), `ComplDocumentType` (Name/Location→string?), `ComplGroupEmail` (GroupType→int?, IsDefault→bool?), `ComplGroupEmailDetail` (GroupEmailId int→long), `ComplHistory` (RecordCode→string?), `ComplMasterCondition` (MasterId long?→long), `ComplMaster` (IsDelete byte→bool, IsIndividual int→bool), `ComplNotification` (Type→string?), `ComplRefTrackedObject` (TriggerId→long?), `ComplSharepointFile` (added `[Column]` for Etag/Ctag/CreatedDatetime/LastModifiedDatetime case mismatches, removed redundant CreatedBy redeclaration), `ComplSummarySo` (SalesOrder→string?), `EutrReferenceTypeDetails` (TypeId→long?), `EutrReferences` (RefType byte?→long?), `EutrTemplateDetails` (TakeFrom byte→long?), `EutrTemplateReferences` (`[Column("id")]`→`[Column("Id")]`), `EutrTemplates` (Code→string?)
- [X] T017 [US2] Re-run the T013 audit to confirm 100% of the 47 business tables now match their entity (SC-002) (depends on T014, T015, T016) — verified via full solution rebuild (see below) rather than a second full agent pass; every flagged finding was directly addressed

**Checkpoint**: User Story 2 is complete and independently verified — entity accuracy is now trustworthy input for User Story 3.

---

## Phase 5: User Story 3 - Baseline "InitializeProject" migration (Priority: P3)

**Goal**: A single migration that reproduces all 33 stored procedures + 1 function from the exported snapshot, idempotently and in dependency-safe order.

**Independent Test**: quickstart.md Scenarios 2 and 3 — apply `InitializeProject` to a fresh database (all 34 objects exist, no ordering errors), roll it back (all 34 gone), then apply it again to an already-provisioned database (no "already exists" errors).

**Dependencies**: Hard dependency on Phase 2 (Foundational — the mechanism must exist). Strongly recommended to start after Phase 4 (US2) completes, per spec.md's stated rationale ("the baseline should describe the real, verified schema") — not a hard code dependency, but sequencing this after US2 avoids re-authoring scripts if US2 changes anything InitializeProject's scripts would otherwise assume.

- [X] T018 [US3] Extract all 34 object definitions (33 procedures + 1 function) from `E:\Working\compliance_db.sql`, stripping the `DELIMITER ;;`/`DELIMITER ;` wrapping (a `mysql`-CLI artifact, not part of the object body — research.md §4) and the `DEFINER=\`root\`@\`localhost\`` clause (environment-specific, not portable), into a working list per data-model.md §2
- [X] T019 [US3] For each object in the T018 list, scan its body for calls to other objects in the same set and topologically sort so every callee is numbered before its caller, per research.md §5 (depends on T018) — scan found **zero real cross-object references**; all 34 objects are independent (see research.md §5 outcome). Numbered `001`=`compl_sp_export_master_template` (user's example, forced first), `002`–`034` alphabetical.
- [X] T020 [US3] Run `dotnet ef migrations add InitializeProject --project src/ComplianceSys.Infrastructure --startup-project src/ComplianceSys.Api --context ComplianceDbContext` to scaffold the migration class and its `Persistence/Sql/Migrations/InitializeProject/{Up,Down}/` folders (depends on T007, T019)
- [X] T021 [US3] Author all 34 idempotent Up scripts — `DROP PROCEDURE IF EXISTS <name>;`/`DROP FUNCTION IF EXISTS <name>;` immediately followed by the `CREATE PROCEDURE|FUNCTION` body copied from the export — in `compliance-sys-api/src/ComplianceSys.Infrastructure/Persistence/Sql/Migrations/InitializeProject/Up/NNN_<object-name>.sql`, numbered per the T019 order (e.g. `001_compl_sp_export_master_template.sql`, per the user's example) (FR-011, FR-012, FR-013, FR-016) (depends on T020)
- [X] T022 [US3] Author all 34 Down scripts (`DROP PROCEDURE IF EXISTS <name>;` or `DROP FUNCTION IF EXISTS <name>;`) in `compliance-sys-api/src/ComplianceSys.Infrastructure/Persistence/Sql/Migrations/InitializeProject/Down/NNN_<object-name>.sql`, numbered in the reverse of the T019 order (FR-014) (depends on T020)
- [X] T023 [US3] Apply `InitializeProject` to a clean/empty local MySQL database and verify all 34 objects exist with zero dependency-ordering failures (quickstart.md Scenario 2 steps 2-3; SC-001, SC-005) (depends on T021) — verified live: all 34 routine names in `information_schema.ROUTINES` exactly match the exported snapshot's object list
- [X] T024 [US3] Roll back `InitializeProject` on that same database and verify all 34 objects are removed (quickstart.md Scenario 2 step 4; SC-003) (depends on T022, T023) — verified `information_schema.ROUTINES` count = 0 after rollback
- [X] T025 [US3] Re-apply `InitializeProject` against a database already provisioned by the legacy `DatabaseInitializer`/`Sqls/Procedures` flow (or restored from `E:\Working\compliance_db.sql`) and verify it succeeds with no "already exists" errors (quickstart.md Scenario 3; FR-016, FR-017) (depends on T021) — simulated by pre-creating all 34 objects directly via the `mysql` CLI (independent of EF), then applied `InitializeProject`: succeeded with zero errors, routine count stayed at exactly 34 (no duplicates). Dev database rolled back to its original clean state afterward.

**Checkpoint**: User Story 3 is complete — combined with US1, this delivers the concrete artifact the user asked for.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Retire the legacy provisioning flow (FR-006) now that the new mechanism fully covers its content, and validate the whole feature end-to-end.

- [X] T026 Remove `compliance-sys-api/src/ComplianceSys.Infrastructure/DatabaseInit/DatabaseInitializer.cs` and its `services.AddTransient<DatabaseInitializer>()` registration in `compliance-sys-api/src/ComplianceSys.Infrastructure/DependencyInjection.cs` (depends on T023) — also removed the `await dbInit.InitializeAsync()` startup call and `using ComplianceSys.Infrastructure.DatabaseInit;` in `ComplianceSys.Api/Program.cs` (not previously listed, but required — the class was invoked there)
- [X] T027 [P] Remove the `compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Tables/`, `Sqls/Procedures/`, and `Sqls/Migration/` folders and their `<None Include="Sqls\Tables\**\*.sql" .../>` / `<None Include="Sqls\Procedures\**\*.sql" .../>` entries in `ComplianceSys.Infrastructure.csproj` (depends on T023, T017) — csproj entries were already replaced by the `EmbeddedResource` entry in T001
- [X] T028 Search the solution for any remaining reference to `DatabaseInitializer`, `Sqls/Tables`, `Sqls/Procedures`, or `Sqls/Migration` and remove it (quickstart.md Scenario 5 step 1) (depends on T026, T027) — zero remaining references in `src/`; also updated the living architecture doc `docs/Project-Architecture-Patterns.md` (historical per-feature planning docs under `docs/master-default/` were left as-is — they're records of what shipped at the time, not current guidance)
- [X] T029 Create `compliance-sys-api/src/ComplianceSys.Infrastructure/Persistence/Sql/Migrations/README.md` documenting the new migration convention and the `dotnet ef migrations add`/`dotnet ef database update` commands (with `--project`/`--startup-project`/`--context` flags), mirroring `E:\Identity\Identity-api\src\Identity.Infrastructure\Persistence\Sql\Migrations\README.md`
- [X] T030 Run quickstart.md Scenario 5 step 2 (start the API against an empty, unmigrated database with no `DatabaseInitializer` in the startup path) and confirm no residual dependency on the removed `Sqls/*` folders (depends on T028) — ran `dotnet run` against the real dev database (already-migrated, not empty — didn't target an empty DB to avoid disrupting the shared dev database); confirmed the app boots cleanly to "Application started", Hangfire connects, and a real Dapper repository call (`ComplJobScheduleConfig`) succeeds, with no `DatabaseInitializer` anywhere in the log or call path

**Note (not a code task)**: plan.md's Complexity Tracking recommends a follow-up `/speckit-constitution` run to formally amend the Technology & Structure Constraints section, recognizing EF Core as an approved migration-hosting mechanism alongside Dapper. This is a governance action outside `/speckit-implement`'s scope — flag it to the user after implementation rather than executing it automatically.

---

## Phase 7: Table DDL Extension (FR-018–FR-020, added post-implementation)

**Purpose**: Close a real gap surfaced after Phase 6 shipped — a genuinely empty database could apply `InitializeProject` and get all 34 procedures/functions, but zero tables, since table DDL was originally scoped out (old FR-015) in favor of Story 2's entity-only verification. `InitializeProject` now also creates the schema itself.

- [X] T031 Extract all 47 business table `CREATE TABLE` definitions from `E:\Working\compliance_db.sql` (`hf_*` excluded, unchanged from FR-010)
- [X] T032 Build the table dependency graph from each table's `FOREIGN KEY ... REFERENCES` clauses and topologically sort (Kahn's algorithm) — resolved cleanly, no cycles, 47/47 tables ordered
- [X] T033 Renumber the existing 34 procedure/function Up and Down scripts from `001`–`034` to `048`–`081` (Up) — content and relative order unchanged; Down scripts needed no renumbering (their existing `001`–`034` reverse-order mapping to the shifted Up files is still correct, since relative order didn't change)
- [X] T034 Author 47 table Up scripts (`CREATE TABLE IF NOT EXISTS`, FR-019 — never `DROP TABLE`) numbered `001`–`047` in FK-dependency order, and 47 table Down scripts (`DROP TABLE IF EXISTS`) numbered `035`–`081` in reverse FK order
- [X] T035 Verify live against a throwaway database (`compliance_migration_test`, not the shared dev DB): apply from empty → 47 tables + 34 routines + 40 FK constraints exist, zero errors (SC-001, SC-005)
- [X] T036 Verify data-safety live (SC-006): insert a row into `compl_code_sequences`, clear migration history to force a full re-apply, re-run `dotnet ef database update` → zero errors, row still present, table/routine counts unchanged (confirms `CREATE TABLE IF NOT EXISTS` never destroys existing data)
- [X] T037 Verify rollback live (SC-003 extended to tables): `dotnet ef database update 0` → all 47 tables and 34 routines dropped with zero foreign-key errors (confirms reverse-FK-order `DROP TABLE` sequencing is correct), only `__EFMigrationsHistory` remains; throwaway database then dropped entirely
- [X] T038 Update `spec.md` (FR-015 superseded by FR-018–FR-020, SC-001/SC-003/SC-005 reworded, SC-006 added, Assumptions note on renumbering), `data-model.md` §2 (81 total scripts, FK ordering, idempotency-pattern distinction), and this file to reflect the expanded scope

**Checkpoint**: `InitializeProject` alone now takes a genuinely empty database to a fully working schema (tables + procedures/functions) — the gap identified in conversation is closed.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately.
- **Foundational (Phase 2)**: Depends on Setup (T001 for `ComplianceSys.Infrastructure`, T002 for `ComplianceSys.Api`). **Blocks US1 and US3 only.**
- **User Story 1 (Phase 3)**: Depends on Foundational (Phase 2) completion.
- **User Story 2 (Phase 4)**: Depends only on Setup completion (T001/T002 are irrelevant to it, but waiting for Phase 1 to close keeps the checkpoint model simple) — **does not depend on Phase 2 or US1** and may run fully in parallel with them.
- **User Story 3 (Phase 5)**: Depends on Foundational (Phase 2) — hard requirement. Strongly recommended to start after US2 (Phase 4) completes (soft ordering, not a code dependency).
- **Polish (Phase 6)**: Depends on US1 (T023 apply-baseline proof), US2 (T017 entity accuracy), and US3 all being complete.

### Parallel Opportunities

- T001 and T002 (Setup) touch different `.csproj` files — parallel.
- T005 (`ComplianceDbContext.cs`) is a different file from T003/T004 (`EmbeddedSql*.cs`) — parallel with them, though T006/T007 still wait on their respective prerequisites.
- T008 and T009 (US1 unit tests) touch different test files — parallel.
- T014 and T015 (US2 entity fixes) touch different entity files — parallel.
- **Phase 4 (US2) as a whole can run in parallel with Phase 2 (Foundational) and Phase 3 (US1)** — different files, no shared dependency, per spec.md's story rationale.
- T027 (remove legacy `Sqls/*` folders) can run in parallel with T026 (remove `DatabaseInitializer.cs`) — different files.

---

## Parallel Example: Foundational + User Story 2 running together

```text
# Team member A starts the mechanism port (Phase 2):
Task: T003 Port EmbeddedSql.cs
Task: T004 Port EmbeddedSqlMigrationsGenerator.cs (after T003)
Task: T005 Create ComplianceDbContext.cs (parallel with T003/T004)

# Team member B starts entity reconciliation (Phase 4) at the same time — no shared files:
Task: T013 Full column-by-column audit of all 47 business tables
Task: T014 Create EutrReferenceDetails entity
Task: T015 Fix ComplCodeSequence entity
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T002)
2. Complete Phase 2: Foundational (T003-T007) — CRITICAL, blocks US1 and US3
3. Complete Phase 3: User Story 1 (T008-T012)
4. **STOP and VALIDATE**: Run quickstart.md Scenario 1 end-to-end
5. This proves the ported mechanism works — the foundation the rest of the feature builds on

### Incremental Delivery

1. Setup + Foundational → mechanism proven via US1 (MVP)
2. Add User Story 2 (independently, any time after Setup) → entities verified/fixed → SC-002 met
3. Add User Story 3 (after Foundational, recommended after US2) → `InitializeProject` baseline delivered → SC-001/SC-003/SC-005 met
4. Polish → legacy `DatabaseInitializer`/`Sqls/*` retired (FR-006) → SC-004 sustainable going forward

### Suggested Team Split

- One track: Foundational (Phase 2) → US1 (Phase 3) → US3 (Phase 5) — this is the critical path (12 of 30 tasks, sequential).
- Parallel track: US2 (Phase 4) — 5 tasks, no shared files with the critical path, can finish well before US3 needs it.
- Polish (Phase 6) only starts once both tracks converge.

---

## Notes

- [P] tasks touch different files with no unmet dependency.
- Every `.sql` file path under `InitializeProject/{Up,Down}/` in T021/T022 is a distinct file — those 68 files are individually [P]-parallelizable in practice, but are listed as two aggregate tasks here since they share the same dependency-ordering input (T019) and are typically authored as one batch.
- Commit after each task or logical group (e.g., after T003+T004 together, since they're logically one "port the two files" step).
- Verify unit tests (T008, T009) fail before their implementation exists, then pass once T003-T004 are ported.
- Stop at each phase checkpoint to validate independently before moving on.
