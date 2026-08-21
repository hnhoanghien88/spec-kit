# Implementation Plan: Compliance Job Run-Status Email Notifications

**Branch**: `017-compl-report-services` | **Date**: 2026-08-21 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/017-compl-report-services/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Six Hangfire-driven compliance job methods must email an operator on every run, success or failure, closing two known gaps where a failure is currently caught and silenced before it ever reaches the existing global Hangfire failure filter, and bringing a sixth, currently-unscheduled method under the same monitoring. The approach (see `research.md`) is additive and low-risk: inject a new `IHangfireSuccessEmailNotifier` (mirroring the existing `IHangfireFailureEmailNotifier`) into the five owning services and call it explicitly at each method's own success point; reuse the existing failure notifier directly inside the two blind-spot `catch` blocks; extend the existing `HangfireFailureNotificationOptions` with one new flag instead of adding a new config section; and seed one new `compl_job_schedule_configs` row so `SendSalesOrderAlertAsync` becomes a recurring job. No new Hangfire global state filter, no interface signature changes, and the existing failure filter is untouched.

## Technical Context

**Language/Version**: C# / .NET 8 (existing `compliance-sys-api` solution)

**Primary Dependencies**: Hangfire (recurring jobs + `JobFilterAttribute`/`IApplyStateFilter`), Dapper (data access, unchanged), `System.Net.Mail` via the existing `MailAlert` helper, Serilog (`Log.Error`/`Log.Information`, existing convention)

**Storage**: MySQL 5.7+/8.0 — one new seeded row in the existing `compl_job_schedule_configs` table; no schema change

**Testing**: xUnit under `compliance-sys-api/tests/ComplianceSysApi.UnitTests` (existing `Services/Hangfire/HangfireFailureNotificationFilterTests.cs` is the closest reference pattern for the new notifier tests)

**Target Platform**: Existing ASP.NET Core backend (`ComplianceSys.Api`), Windows/Linux server, Hangfire in-process recurring job scheduler

**Project Type**: Backend-only change to the existing web-service project (`compliance-sys-api`); no frontend involved — no `compliance-client` changes, no new routes/menu entries

**Performance Goals**: N/A — batch/notification jobs run on existing cron schedules (daily to ~every 2 hours); no new latency-sensitive path

**Constraints**: Must not change existing retry/dashboard semantics for the four jobs that already propagate exceptions correctly; must not mark `SendMailForProcessedMastersAsync` logs as sent when the mail send fails (FR-004); must not duplicate "it worked" emails when a business-content email was already sent this run (FR-005)

**Scale/Scope**: 6 job methods across 4 existing services (`ComplNotificationService`, `ViewCompliancesSummaryService`, `MasterDefaultRefSyncService`, `MasterDefaultService`); 1 new DTO, 1 new notifier interface + implementation, 1 new options property, 1 new seeded config row, 2 methods with a bug-fix-shaped code change

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Layered Clean Architecture (NON-NEGOTIABLE)** — PASS. All new code (`HangfireSuccessNotificationEvent`, `IHangfireSuccessEmailNotifier`/`HangfireSuccessEmailNotifier`) lives in `ComplianceSys.Application/Services/Hangfire/`, the same layer as the existing failure-notification family it mirrors. No controller changes. Injected into existing `Application`-layer services only.
- **II. Reference-Pattern Reuse** — PASS. This is not a CRUD feature, so the `document-type` reference doesn't directly apply; instead, the concrete reference pattern is the existing `HangfireFailureNotificationEvent`/`IHangfireFailureEmailNotifier`/`HangfireFailureNotificationOptions` trio, which the new success-side classes clone in shape (see `research.md` Decision 3).
- **III. Reuse Existing Backend** — PASS. No existing controller, DTO, validator, or endpoint is regenerated or duplicated. `SendSalesOrderAlertAsync` scheduling reuses the existing `compl_job_schedule_configs` + `HangfireJobRegistrar` mechanism via a data seed only (Decision 6) — no new registration code path.
- **IV. Vietnamese Comments; Localizable UI Labels** — PASS (with note). New C# code comments must be written in Vietnamese per this principle, consistent with the surrounding code (e.g. `HangfireJobRegistrar`'s existing Vietnamese comments). This feature has no user-facing UI, so the "Localizable UI Labels" half does not apply.
- **V. Routing & Menu Registration** — N/A. No new frontend screen; nothing to route or add to a menu.

No violations — Complexity Tracking table is not needed.

## Post-Design Constitution Re-Check

*Re-evaluated after Phase 1 (research.md, data-model.md, quickstart.md above).*

Unchanged from the initial gate: all new types stay within `ComplianceSys.Application/Services/Hangfire/`, no new external interface/contract is introduced (the one DB change is a data seed to an existing table, not a schema or endpoint change), and the design keeps the existing failure filter and its tests untouched. Still PASS on all applicable principles.

## Project Structure

### Documentation (this feature)

```text
specs/017-compl-report-services/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

No `contracts/` directory — this feature adds no new external interface (no new HTTP endpoint; the one DB change is a data seed to an already-existing, already-exposed `compl_job_schedule_configs` table via the existing `ComplJobScheduleConfigController`).

### Source Code (repository root)

```text
compliance-sys-api/
├── src/
│   ├── ComplianceSys.Application/
│   │   ├── Services/
│   │   │   ├── Hangfire/
│   │   │   │   ├── HangfireFailureNotificationEvent.cs        # existing, unchanged
│   │   │   │   ├── HangfireFailureNotificationFilter.cs       # existing, unchanged
│   │   │   │   ├── HangfireFailureNotificationOptions.cs      # MODIFIED — add NotifyOnSuccess
│   │   │   │   ├── HangfireFailureEmailNotifier.cs            # existing, unchanged (IHangfireFailureEmailNotifier)
│   │   │   │   ├── HangfireSuccessNotificationEvent.cs        # NEW
│   │   │   │   └── HangfireSuccessEmailNotifier.cs            # NEW (IHangfireSuccessEmailNotifier)
│   │   │   ├── ComplNotificationService.cs                    # MODIFIED — SendAlertAsync, SendSalesOrderAlertAsync add NotifySuccess call
│   │   │   ├── MasterDefaultService.cs                        # MODIFIED — ProcessAsync, SendMailForProcessedMastersAsync
│   │   │   ├── MasterDefaultRefSyncService.cs                 # MODIFIED — SyncAsync add NotifySuccess call
│   │   │   └── ViewCompliances/
│   │   │       └── ViewCompliancesSummaryService.cs           # MODIFIED — GetAndSaveSummarySo
│   │   └── DependencyInjection.cs                             # MODIFIED — register HangfireSuccessEmailNotifier
│   ├── ComplianceSys.Api/
│   │   └── appsettings.Development.json                       # optionally document NotifyOnSuccess (defaults true if absent)
│   └── ComplianceSys.Infrastructure/
│       └── Sqls/Migration/
│           └── 27_seed_sales_order_alert_job.sql               # NEW — seeds sent_alert_sales_order job config row
└── tests/
    └── ComplianceSysApi.UnitTests/
        └── Services/
            └── Hangfire/
                ├── HangfireFailureNotificationFilterTests.cs   # existing, must stay green (regression check)
                └── HangfireSuccessEmailNotifierTests.cs         # NEW
```

**Structure Decision**: Single existing project, backend-only (`compliance-sys-api`), following its established Clean Architecture layering. No `compliance-client` changes — this feature has no user-facing UI. New code is confined to the `ComplianceSys.Application/Services/Hangfire/` folder that already houses the pattern it extends, plus small, explicit call-site additions inside the four existing services that own the six job methods, plus one new SQL seed script in the existing `Sqls/Migration/` folder.

## Complexity Tracking

*No entries — Constitution Check above has no unjustified violations.*
