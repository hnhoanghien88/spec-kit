# Implementation Plan: Sales Order Missing-Compliance Alert

**Branch**: `009-compl-sales-order-missing` | **Date**: 2026-08-03 | **Updated**: 2026-08-04 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/009-compl-sales-order-missing/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Add a new backend-only alert job to the existing compliance-sys-api that, on demand, re-evaluates every open sales order's compliance status, persists a fresh "missing compliance" snapshot, and sends one consolidated email + in-app notification. The feature clones the existing `ComplNotificationController.TestAlert` / `ComplNotificationService.SendAlertAsync` pattern exactly (same controller, same service class), adding a new endpoint `GET api/notification/test-sales-order-alert` and a new method `SendSalesOrderAlertAsync`. It orchestrates two already-existing application services (`IComplDynamicsService.GetDynRefePagedAsync` for the open sales order list, `IViewCompliancesService.GetViewCompliancesAsync` for the per-sales-order compliance check) and a persistence path for `compl_so_missing` (table previously defined in SQL but with zero C# usage before this feature) plus a mail/notification method mirroring the existing `SendMailAndNotification` private helper.

**2026-08-04 update**: This feature was already implemented once (Phase 1–4 tasks in `tasks.md` are checked off) using a **per-`SalesId` delete-before-insert** pattern: `IComplSoMissingRepository.DeleteBySalesIdAsync(so.Code, ct)` was called inside the per-sales-order loop, immediately before that sales order's `InsertManyAsync`. The spec was revised to remove that logic entirely and replace it with a **single delete-all step run once, before the loop starts** (`spec.md` FR-006, Edge Cases). This plan update reflects that change: `DeleteBySalesIdAsync` is removed from the repository interface/implementation, a new `DeleteAllAsync()` method is added, and `RefreshSalesOrderMissingComplianceAsync` calls it exactly once before entering the open-sales-order loop instead of once per sales order inside the loop.

## Technical Context

**Language/Version**: C# / .NET 8 (matches all four existing projects: `ComplianceSys.Api`, `ComplianceSys.Application`, `ComplianceSys.Domain`, `ComplianceSys.Infrastructure`)

**Primary Dependencies**: ASP.NET Core Web API, Dapper via `Res.Shared.Dapper` (v1.0.5, provides `DapperRepository<TEntity,TKey>`, `IUnitOfWork`, `IRepository<,>`), AutoMapper, FluentValidation, Hangfire (background jobs, used elsewhere in this controller but not required for this feature), Serilog (static `Log`), Newtonsoft `JsonConvert` (JSON group-email parsing)

**Storage**: MySQL (existing `compl_so_missing` table already defined in `compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Tables/compl_so_missing.sql`, currently unused by any C# code)

**Testing**: xUnit 2.9.2 + Moq 4.20.72, in `compliance-sys-api/tests/ComplianceSysApi.UnitTests`

**Target Platform**: ASP.NET Core Web API (existing `ComplianceSys.Api` host), Windows/Linux server

**Project Type**: Backend-only addition to an existing Clean Architecture web service (no frontend work; this is an internal/testing-triggered alert job, not a user-facing screen)

**Performance Goals**: No new hard target beyond the existing alert flow's expectations; the job runs on demand (manual trigger), so it is not on a user-facing request path. Each sales order is checked sequentially, matching the existing per-master loop style in `SendMailAndNotificationByMasterDefaultCreateAsync`.

**Constraints**: Must reuse `IComplDynamicsService` and `IViewCompliancesService` exactly as they exist today (Constitution Principle III); must not duplicate their query logic. Must not break the existing `test-alert` / `SendAlertAsync` flow.

**Scale/Scope**: Bounded by the number of currently open sales orders returned by the Dynamics reference lookup (paged; expected low hundreds based on existing "Open order" sales order volumes in this system).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Layered Clean Architecture (NON-NEGOTIABLE)** — PASS. New code stays within existing layer boundaries: `ComplNotificationController` (Api, thin, delegates only) → `ComplNotificationService` (Application, holds the new orchestration logic) → new `ComplSoMissing` entity (Domain) → new `ComplSoMissingRepository` (Infrastructure, implements a new `IComplSoMissingRepository` Application-layer interface). No business logic added to the controller.
- **II. Reference-Pattern Reuse** — PASS (feature-appropriate reference). This is not a CRUD screen, so the canonical `document-type` CRUD reference does not apply; the feature spec itself names its own reference (`ComplNotificationController.TestAlert` / `ComplNotificationService.SendAlertAsync`), and this plan clones that pattern file-for-file (same controller class, same service class, same try/catch/Log.Error/return-early-if-empty shape).
- **III. Reuse Existing Backend** — PASS, with one required fix flagged in `research.md` R2: `refType = 18` (`ObjectType.SALE_ORDER_OPEN`) is not currently wired into `ComplDynamicsService.EntityMappings`, so it returns an empty result as of today. This plan treats that as a small, scoped bug fix to the *existing* service (adding one dictionary entry, reusing the "Open order" filter branch that already exists in the same method) rather than a new parallel implementation — no controller/service/DTO is duplicated. (This fix was already applied in the initial implementation and is unaffected by the 2026-08-04 delete-all update.)
- **IV. Vietnamese Comments; Localizable UI Labels** — PASS. This feature has no UI; code comments added to new/changed C# files will be in Vietnamese, consistent with the rest of the codebase (e.g. existing `// ánh xạ trực tiếp từ SQL` style comments).
- **V. Routing & Menu Registration** — N/A. No frontend route or menu entry; this is a backend-only, manually-triggered diagnostic endpoint (mirroring `test-alert`, which also has no frontend entry point).

No violations requiring Complexity Tracking justification.

## Project Structure

### Documentation (this feature)

```text
specs/009-compl-sales-order-missing/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md         # Phase 1 output (/speckit-plan command)
├── quickstart.md         # Phase 1 output (/speckit-plan command)
├── contracts/            # Phase 1 output (/speckit-plan command)
│   └── test-sales-order-alert.md
└── tasks.md              # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
compliance-sys-api/
├── src/
│   ├── ComplianceSys.Api/
│   │   └── Controllers/
│   │       └── ComplNotificationController.cs        # DONE (initial impl): [HttpGet("test-sales-order-alert")] added; unaffected by 2026-08-04 update
│   ├── ComplianceSys.Application/
│   │   ├── Interfaces/Services/
│   │   │   └── IComplNotificationService.cs           # DONE (initial impl): SendSalesOrderAlertAsync() added; unaffected by 2026-08-04 update
│   │   ├── Interfaces/Repositories/
│   │   │   └── IComplSoMissingRepository.cs            # MODIFY (2026-08-04): remove `DeleteBySalesIdAsync(string salesId, ...)`, add `DeleteAllAsync(CancellationToken ct = default)`
│   │   ├── Dtos/Response/
│   │   │   └── ComplSoMissingResponseDto.cs            # DONE (initial impl): unaffected by 2026-08-04 update
│   │   ├── Services/
│   │   │   ├── ComplNotificationService.cs             # MODIFY (2026-08-04): in RefreshSalesOrderMissingComplianceAsync, remove the per-sales-order `_complSoMissingRepository.DeleteBySalesIdAsync(so.Code, ct)` call inside the loop; call `_complSoMissingRepository.DeleteAllAsync(ct)` exactly once before the open-sales-order paging loop begins
│   │   │   └── ComplDynamicsService.cs                  # DONE (initial impl): EntityMappings[18] entry already added (research.md R2); unaffected by 2026-08-04 update
│   │   └── DependencyInjection.cs                      # DONE (initial impl); no change needed
│   ├── ComplianceSys.Domain/
│   │   └── Entities/
│   │       └── ComplSoMissing.cs                       # DONE (initial impl): 1:1 with compl_so_missing table columns; unaffected by 2026-08-04 update
│   └── ComplianceSys.Infrastructure/
│       ├── Repositories/
│       │   └── ComplSoMissingRepository.cs             # MODIFY (2026-08-04): remove `DeleteBySalesIdAsync`, add `DeleteAllAsync` (`DELETE FROM compl_so_missing` with no WHERE clause); `InsertManyAsync`/`GetAllAsync` unchanged
│       ├── DependencyInjection.cs                       # DONE (initial impl): IComplSoMissingRepository already registered; unaffected
│       └── Sqls/Migration/
│           └── 17_create_compl_so_missing.sql           # DONE (initial impl): schema unchanged by this update, no new migration needed
└── tests/
    └── ComplianceSysApi.UnitTests/
        └── (no dedicated tests existed before this update either; still optional, out of scope per tasks.md's Tests note)
```

**Structure Decision**: Pure extension of the existing single-project Clean Architecture backend (`compliance-sys-api/`). No new project, no frontend changes, no schema change for this update (the `compl_so_missing` table's columns are unaffected — only which SQL statement clears it, and when, changes). The 2026-08-04 update touches exactly two existing files (`IComplSoMissingRepository.cs`, `ComplSoMissingRepository.cs`) plus the call site in `ComplNotificationService.cs`; every other file from the initial implementation is unaffected.

## Complexity Tracking

> No Constitution Check violations require justification — table omitted.
