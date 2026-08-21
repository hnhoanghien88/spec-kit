# Implementation Plan: Compliance DB Migration Baseline

**Branch**: `016-compl-db-migrations` | **Date**: 2026-08-21 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/016-compl-db-migrations/spec.md`

## Summary

Port Identity's proven embedded-SQL EF Core migration mechanism (`EmbeddedSql` + a custom
`IMigrationsCodeGenerator` that wires each named migration's ordered `Up`/`Down` script folders
into the generated migration) into compliance-sys-api, add a schema-only `ComplianceDbContext`
to host it, retire the legacy `DatabaseInitializer`/`Sqls/Tables`/`Sqls/Procedures`/`Sqls/Migration`
flow, reconcile every `ComplianceSys.Domain.Entities` class against the real schema captured in
`E:\Working\compliance_db.sql`, and author a baseline `InitializeProject` migration whose
idempotent Up scripts recreate all 33 stored procedures and 1 function from that export (Down
scripts drop them), dependency-ordered so callees are created before callers.

## Technical Context

**Language/Version**: C# / .NET 8 (all `compliance-sys-api/src/*` projects target `net8.0`)

**Primary Dependencies**: Existing — Dapper 2.1.66, Dapper.SimpleCRUD, MySql.Data 9.4.0,
Res.Shared.Dapper (unchanged, still the runtime data-access path — `MySql.Data` stays pinned at
`9.4.0`). New — Oracle `MySql.EntityFrameworkCore` **8.0.17** (the specific build whose `MySql.Data`
dependency floor equals `9.4.0`, avoiding any connector version change — research.md §1) and
`Microsoft.EntityFrameworkCore.Design` `8.0.17`, added to `ComplianceSys.Infrastructure` and
`ComplianceSys.Api` respectively, for migration tooling only.

**Storage**: MySQL 8 (unchanged) — schema and stored procedures/functions/views are the subject
of this feature; EF Core also creates its own `__EFMigrationsHistory` tracking table.

**Testing**: xUnit + Moq (`tests/ComplianceSysApi.UnitTests`, existing project) for the ported
`EmbeddedSql`/`EmbeddedSqlMigrationsGenerator` helper logic; `dotnet ef database update` against
a real MySQL instance for migration-apply/rollback validation (quickstart.md) — this feature has
no meaningful unit-testable business logic beyond the embedding/generator helpers themselves.

**Target Platform**: Linux/Windows server (ASP.NET Core, unchanged); developer workstations
running `dotnet ef` CLI against local/dev MySQL.

**Project Type**: Backend-only change to the existing `compliance-sys-api` Clean Architecture
solution (no frontend involvement — `compliance-client` is untouched).

**Performance Goals**: N/A (build-time/deploy-time tooling, not a runtime request path).

**Constraints**: `InitializeProject` Up scripts MUST be idempotent (FR-016); no per-script resume
mechanism (FR-017); Down scripts MUST reverse-order dependencies (FR-014); DELIMITER wrapping
from the exported dump MUST be stripped before use as a migration script body (research.md §4).

**Scale/Scope**: 47 business tables to reconcile (Story 2); 81 database objects total to capture
in `InitializeProject` (Story 3, expanded post-implementation) — 47 tables + 33 procedures + 1
function (0 views); one new EF Core `DbContext` with zero mapped entities (Story 1).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle / Constraint | Assessment |
|---|---|
| I. Layered Clean Architecture (NON-NEGOTIABLE) | **Pass.** `ComplianceDbContext` and the migration generator live in `ComplianceSys.Infrastructure/Persistence/`; `DesignTimeServices` lives in `ComplianceSys.Api` (the startup project) — mirrors Identity's layering exactly, no controller/business-rule leakage. |
| II. Reference-Pattern Reuse | **Pass.** The canonical reference for this feature is Identity's own `Persistence/Migrations/{EmbeddedSql,EmbeddedSqlMigrationsGenerator}.cs` + `Identity.Api/DesignTimeServices.cs` + `Persistence/Sql/Migrations/<Name>/{Up,Down}` convention — cloned and renamed into the `ComplianceSys.*` namespace, not invented from scratch. |
| III. Reuse Existing Backend | **N/A for this feature** — there is no pre-existing migration mechanism or `InitializeProject` baseline to reuse; this feature *creates* that capability. Existing Dapper repositories, controllers, and DTOs are untouched. |
| IV. Vietnamese Comments; Localizable UI Labels | **Pass / N/A.** No UI surface. New C# code comments (where a WHY-comment is warranted, e.g. explaining the DELIMITER-stripping rationale) follow the existing Vietnamese-comment convention seen in `ComplianceSys.Domain.Entities` files. |
| V. Routing & Menu Registration | **N/A.** No new frontend screen. |
| Technology & Structure Constraints — "Dapper-based data access" | **Deviation, justified below (Complexity Tracking).** Confirmed at `/speckit-clarify`: EF Core is added narrowly as a migration-hosting mechanism (`ComplianceDbContext` has zero mapped entities); all runtime reads/writes remain on Dapper, unchanged. |

Constitution version checked: 2.0.0 (2026-07-01).

## Project Structure

### Documentation (this feature)

```text
specs/016-compl-db-migrations/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output
├── data-model.md         # Phase 1 output
├── quickstart.md         # Phase 1 output
└── tasks.md              # Phase 2 output (/speckit-tasks command — not created here)
```

No `contracts/` directory: this feature adds no public API endpoints, CLI commands, or other
externally-consumed interface — it is internal schema/migration tooling. `dotnet ef` itself is
the only "interface," and it's a standard EF Core CLI contract, not a project-specific one worth
documenting as a contract artifact.

### Source Code (repository root)

```text
compliance-sys-api/
├── src/
│   ├── ComplianceSys.Api/
│   │   └── DesignTimeServices.cs                         # NEW — registers EmbeddedSqlMigrationsGenerator (mirrors Identity.Api)
│   ├── ComplianceSys.Domain/
│   │   └── Entities/
│   │       ├── EutrReferenceDetails.cs                    # NEW — closes the FR-009 gap found in data-model.md §3
│   │       └── ComplCodeSequence.cs                        # MODIFIED — add [Table], fix CreatedBy/UpdatedBy mismatch
│   │       └── ... (any other entity found to drift during the full FR-007 audit)
│   └── ComplianceSys.Infrastructure/
│       ├── ComplianceSys.Infrastructure.csproj             # MODIFIED — add MySql.EntityFrameworkCore, EF.Design; remove Sqls/Tables+Sqls/Procedures EmbeddedResource/Content entries
│       ├── DependencyInjection.cs                          # MODIFIED — register ComplianceDbContext; remove DatabaseInitializer registration
│       ├── DatabaseInit/
│       │   └── DatabaseInitializer.cs                      # REMOVED (FR-006)
│       ├── Sqls/
│       │   ├── Tables/                                      # REMOVED (FR-006) — content superseded by verified entities + InitializeProject
│       │   ├── Procedures/                                  # REMOVED (FR-006) — content superseded by InitializeProject
│       │   └── Migration/                                   # REMOVED (FR-006) — ad-hoc numbered scripts superseded by the export-derived baseline
│       ├── Migrations/                                       # NEW — EF Core's default output dir (project root, NOT under Persistence/); mirrors where Identity's own generated migration classes actually live
│       │   ├── <timestamp>_InitializeProject.cs               # NEW — EF-generated migration class
│       │   ├── <timestamp>_InitializeProject.Designer.cs      # NEW — EF-generated
│       │   └── ComplianceDbContextModelSnapshot.cs            # NEW — EF-generated (schema-only snapshot, no entities)
│       └── Persistence/                                      # NEW tree, mirrors Identity.Infrastructure/Persistence
│           ├── ComplianceDbContext.cs                        # NEW — no DbSet<T> members (research.md §2)
│           ├── Migrations/
│           │   ├── EmbeddedSql.cs                            # NEW — ported verbatim from Identity, namespace renamed
│           │   └── EmbeddedSqlMigrationsGenerator.cs         # NEW — ported verbatim, namespace renamed
│           └── Sql/
│               └── Migrations/
│                   └── InitializeProject/
│                       ├── Up/001_..sql … 034_..sql          # NEW — one file per procedure/function, dependency-ordered (data-model.md §2)
│                       └── Down/001_..sql … 034_..sql         # NEW — reverse dependency order
└── tests/
    └── ComplianceSysApi.UnitTests/
        └── Persistence/Migrations/
            ├── EmbeddedSqlTests.cs                           # NEW — resource-loading/ordering behavior
            └── EmbeddedSqlMigrationsGeneratorTests.cs        # NEW — Up/Down folder wiring behavior
```

**Structure Decision**: Single-project change within the existing `compliance-sys-api` Clean
Architecture solution — no new project is created. `Persistence/` is added under
`ComplianceSys.Infrastructure` (the layer that already owns `DatabaseInit/`, `Sqls/`, and
`Repositories/`), exactly mirroring where Identity keeps its own `Persistence/` tree, satisfying
Principle I and Principle II simultaneously.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|---------------------------------------|
| Adding EF Core (`MySql.EntityFrameworkCore` + `Microsoft.EntityFrameworkCore.Design`) alongside the constitution's stated "Dapper-based data access" | The user explicitly asked to port Identity's *EF Core-based* embedded-SQL migration mechanism, and `/speckit-clarify` reconfirmed keeping EF Core after this conflict was surfaced — Identity already validates the same hybrid Dapper (runtime) + EF Core (migrations-only) pattern in production, and no equivalent battle-tested Dapper-only ordered-migration mechanism exists in either codebase to clone from (Principle II, Reference-Pattern Reuse, favors cloning Identity's real mechanism over inventing a new one) | A hand-rolled Dapper-only folder runner (the spec's originally-offered Option B) was considered and rejected at `/speckit-clarify`: it would be a *novel* mechanism with no reference implementation to clone, working against Principle II, and would still need to solve ordering/idempotency/history-tracking problems EF Core's migration history table already solves for free |

Recommended follow-up (not part of this feature's implementation): run `/speckit-constitution`
to amend the Technology & Structure Constraints section, formally recognizing EF Core as an
approved migration-hosting mechanism (schema-only, no mapped entities) alongside Dapper for
runtime data access — so future features don't re-surface this same conflict.
