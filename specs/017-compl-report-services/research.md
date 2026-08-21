# Research: Compliance Job Run-Status Email Notifications

## Context recap

Six job methods (5 already scheduled via `compl_job_schedule_configs` + Hangfire, 1 not yet scheduled) need to email an operator on every run — success or failure — including two cases where a failure is currently caught and silenced before the existing global Hangfire failure filter ever sees it.

## Decision 1: Where success/failure detection happens

**Decision**: Do NOT introduce a new Hangfire `SucceededState` global job filter. Instead, inject a new `IHangfireSuccessEmailNotifier` (success side) and reuse the existing `IHangfireFailureEmailNotifier` (failure side, for the two blind-spot cases) directly into the five owning services, and call them explicitly at the exact point in each method where the outcome is already known.

**Rationale**: A generic Hangfire state filter can only see the job's return value/exception, not *why* it succeeded (e.g., "sent a business alert" vs. "nothing to report" vs. "internally swallowed a failure"). Reconstructing that nuance from a boxed return value would require changing three method signatures to a shared outcome enum and reasoning about `SucceededState.Result`, which is fragile and indirect. Calling the notifier explicitly, right where each method already has the context, is simpler, requires **zero interface signature changes**, and keeps the existing global `HangfireFailureNotificationFilter` completely untouched — it continues to be the safety net for any *unhandled* exception in these (and other) jobs exactly as it does today.

**Alternatives considered**:
- A new global `IApplyStateFilter` on `SucceededState`, scoped to an allow-list of the six (ServiceType, MethodName) pairs — rejected because it can't distinguish "business email already sent this run" from "nothing to report" without changing three methods' return types to a shared enum, and still couldn't address the two blind-spot failure cases (those never reach Hangfire's state machine at all, by design, since the exception is caught before the job method returns).
- Wrapping the six methods' Hangfire invocation in a decorator inside `HangfireJobRegistrar.BuildJob` — rejected for the same reason: a wrapper only sees whether the awaited `Task` threw, not what happened inside it, so it cannot detect the two internally-swallowed cases either.

## Decision 2: Fixing the two blind-spot failures

**Decision**:
- `ViewCompliancesSummaryService.GetAndSaveSummarySo` (`compliance-sys-api/src/ComplianceSys.Application/Services/ViewCompliances/ViewCompliancesSummaryService.cs:119-123`): in the existing `catch (OperationCanceledException) when (timeoutCts.IsCancellationRequested)` block, add a call to `IHangfireFailureEmailNotifier.Notify(...)` (building a `HangfireFailureNotificationEvent` with `Kind = FinalFailure` and a message describing the 3-hour timeout) before the existing `return false;`. No signature or retry-behavior change — the method keeps swallowing the timeout as it does today; only a failure email is added.
- `MasterDefaultService.SendMailForProcessedMastersAsync` (`compliance-sys-api/src/ComplianceSys.Application/Services/MasterDefaultService.cs:277-305`): in the existing `catch (Exception ex)` around the mail-send call, add the same kind of explicit `IHangfireFailureEmailNotifier.Notify(...)` call, and — per spec FR-004 — return immediately after notifying, **skipping** `MarkLogsAsSentAsync` for this run so the affected logs remain pending and get retried on the job's next scheduled run instead of being falsely marked as sent.

**Rationale**: Both gaps exist because the method's own `catch` block prevents the exception from ever reaching Hangfire's `FailedState`, which is the only thing the existing global filter listens for. The fix has to happen inside the method, at the point where the exception is already caught — there is no way to observe it from the outside.

**Alternatives considered**: Removing the internal `catch` and letting the exception propagate to Hangfire — rejected for `GetAndSaveSummarySo` because the timeout is intentionally absorbed to avoid an expensive ~3-hour job being retried by Hangfire's automatic-retry policy; rejected for `SendMailForProcessedMastersAsync` because a mail-server hiccup shouldn't fail the whole job when the real remediation is "leave the logs pending, try again next run" (already possible without touching Hangfire's retry system).

## Decision 3: Success notification design

**Decision**: New `HangfireSuccessNotificationEvent` DTO + `IHangfireSuccessEmailNotifier`/`HangfireSuccessEmailNotifier` under `compliance-sys-api/src/ComplianceSys.Application/Services/Hangfire/`, mirroring the shape of the existing `HangfireFailureNotificationEvent`/`IHangfireFailureEmailNotifier` (job name, service/method, occurred-at, dashboard URL) plus a `HadContent: bool` and `Summary: string` describing what the run did. Registered as a singleton in `DependencyInjection.cs` alongside the existing failure notifier, and injected into the five owning services. Each of the six job methods calls `NotifySuccess(...)` once, at its own success point:

| Method | Call site | `HadContent` |
|---|---|---|
| `SendAlertAsync` | end of try block, after existing alert logic | `true` if an alert email was sent this run, else `false` |
| `GetAndSaveSummarySo` | just before `return true;` | `false` (no business-content concept for this job) |
| `SyncAsync` | end of method, success path | `false` |
| `ProcessAsync` | after awaiting the repository call (method becomes an async body instead of an expression-bodied pass-through) | `false` |
| `SendMailForProcessedMastersAsync` | both the "nothing pending" early-return and the "mail sent + logs marked" path | `false` for nothing-pending, `true` for mail-sent |
| `SendSalesOrderAlertAsync` | end of try block, after existing alert logic | `true` if an alert email (with Excel attachment) was sent this run, else `false` |

**Rationale**: This gives every run — content-bearing or not — exactly one outcome signal, satisfying FR-001/FR-007, while `HadContent` lets the notifier fold "already covered by the business email" (FR-005) into a single deduplication rule (see Decision 4) instead of five bespoke ones.

## Decision 4 (superseded 2026-08-21): Avoiding duplicate "it worked" emails (FR-005)

**Original decision**: `HangfireSuccessEmailNotifier.Notify(...)` would skip sending its generic "job ran, here's the outcome" email when `HadContent == true` for the three jobs that already send their own business-content email (`SendAlertAsync`, `SendMailForProcessedMastersAsync`, `SendSalesOrderAlertAsync`), on the understanding that the business email already sent that run *is* the run-status confirmation.

**Why it was reversed**: after implementing and testing against a real running instance, the user repeatedly found it confusing not to receive a distinct `[Hangfire-...] [SUCCESS]` email for content-bearing runs — the business email doesn't read as "the job ran successfully" the way a dedicated run-status email does. Per explicit user feedback, `HangfireSuccessEmailNotifier.Notify(...)` now **always** sends the generic success email, regardless of `HadContent`. The `HadContent` field is kept on `HangfireSuccessNotificationEvent` purely as descriptive metadata (surfaced via `Summary`), no longer as a suppression gate. FR-005 and SC-003 in spec.md are marked superseded accordingly.

## Decision 5: Notification configuration — reuse existing recipients (resolves spec clarification)

**Decision**: Extend the existing `HangfireFailureNotificationOptions` class (`compliance-sys-api/src/ComplianceSys.Application/Services/Hangfire/HangfireFailureNotificationOptions.cs`) with one new property, `NotifyOnSuccess` (default `true`), bound from the **same** `"HangfireFailureNotification"` configuration section and reusing its existing `Recipients`/`Cc`/`Enabled`/`DashboardUrl`. No new configuration section is introduced.

**Rationale**: Directly implements the user's explicit choice ("reuse existing HangfireFailureNotification list") from spec clarification. The class/section name stays `...Failure...` for historical reasons even though it now also governs success notifications — this is a deliberate, minimal-diff choice (renaming would ripple through DI registration, `Program.cs`, and every environment's `appsettings.*.json` for no functional benefit) and is called out here so it isn't mistaken for an oversight.

**Alternatives considered**: A new `HangfireSuccessNotification` config section — rejected per the user's explicit answer to reuse the existing list.

## Decision 6: Scheduling `SendSalesOrderAlertAsync` (resolves spec clarification)

**Decision**: Add a new seeded row to `compl_job_schedule_configs` via a new numbered script, `compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Migration/27_seed_sales_order_alert_job.sql`, following the exact `INSERT ... ON DUPLICATE KEY UPDATE` shape already used in `Sqls/Tables/compl_job_schedule_configs.sql:32-76` and `Sqls/Migration/07_migration_add_group_value.sql:387-404`:

- `JobId`: `sent_alert_sales_order` (mirrors the existing `sent_alert_compliance` naming for `SendAlertAsync`)
- `ServiceType`: `ComplianceSys.Application.Interfaces.Services.IComplNotificationService`
- `MethodName`: `SendSalesOrderAlertAsync`
- `CronExpression`: `15 3 * * *` — daily, 15 minutes after `SendAlertAsync`'s `0 3 * * *`, per the clarification answer ("daily, same early-morning window"); offsetting avoids both jobs starting in the same instant on the shared `default` queue.
- `Timezone`: `SE Asia Standard Time` (matches all other seeded jobs)
- `Queue`: `default`, `IsEnabled`: `1`

**Rationale**: This is the only place recurring jobs are registered in this codebase (`HangfireJobRegistrar.ReloadAll`, loaded from this table at startup and on-demand reload) — no code change is needed to make a new row take effect, only a data seed, consistent with Constitution Principle III (reuse existing backend machinery).

## Decision 7: Database change mechanism

**Decision**: Use the existing ad-hoc numbered SQL script convention under `compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Migration/` (currently up to `26_fix_compl_master_delete_soft_delete.sql`), not an EF Core migration.

**Rationale**: The repository has no EF Core `DbContext` or `Migrations/` folder anywhere in `compliance-sys-api` today — a sibling spec (`specs/016-compl-db-migrations`) proposes moving to EF Core migrations, but nothing from that proposal is present in the actual codebase yet (no `DbContext`, no `Microsoft.EntityFrameworkCore` package reference, no generated migration classes). This feature must build against the codebase as it actually exists, not a not-yet-implemented future convention.
