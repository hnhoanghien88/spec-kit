# Data Model: Compliance Job Run-Status Email Notifications

This feature adds no new database tables. It adds one seeded configuration row and two small in-process notification DTOs (not persisted).

## Entities

### ComplJobScheduleConfig (existing table, one new row)

Table: `compl_job_schedule_configs` (`compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Tables/compl_job_schedule_configs.sql`). No schema change — one new row is seeded (see `research.md` Decision 6) so `SendSalesOrderAlertAsync` becomes a recurring job like the other five:

| Column | New row value |
|---|---|
| `JobId` | `sent_alert_sales_order` |
| `JobName` | `Gửi alert sales order` |
| `Description` | `Gửi thông báo compliance thiếu theo sales order hàng ngày` |
| `ServiceType` | `ComplianceSys.Application.Interfaces.Services.IComplNotificationService` |
| `MethodName` | `SendSalesOrderAlertAsync` |
| `CronExpression` | `15 3 * * *` |
| `Timezone` | `SE Asia Standard Time` |
| `Queue` | `default` |
| `IsEnabled` | `1` |

### HangfireSuccessNotificationEvent (new, in-memory only)

Carries what a job run succeeded with, from a job method to `IHangfireSuccessEmailNotifier`. Not persisted — mirrors the shape of the existing `HangfireFailureNotificationEvent`.

| Field | Type | Meaning |
|---|---|---|
| `JobId` | `string` | Stable identifier for the job (matches the `JobId` values in `compl_job_schedule_configs`, e.g. `sent_alert_compliance`) |
| `JobName` | `string` | Human-readable job name for the email subject/body |
| `ServiceType` | `string` | Full type name of the service, for diagnostics (mirrors the failure event) |
| `MethodName` | `string` | Method name, for diagnostics |
| `OccurredAtUtc` | `DateTime` | When the run completed |
| `HadContent` | `bool` | Descriptive only (see `research.md` Decision 4, superseded): whether this run already sent its own business-content email. No longer used to suppress sending — kept for context in the summary. |
| `Summary` | `string` | One-line description of what happened this run (e.g. "12 compliances alerted", "No new compliances found", "1240 rows synced") |

`DashboardUrl` is not part of this event — `HangfireSuccessEmailNotifier` reads it directly from the shared `HangfireFailureNotificationOptions.DashboardUrl` instead, so job methods don't need to know about that configuration.

### HangfireFailureNotificationEvent (existing, reused as-is)

No change. Reused directly by the two blind-spot call sites (`GetAndSaveSummarySo`, `SendMailForProcessedMastersAsync`) to manually report a failure that the method itself has already caught, using `Kind = HangfireFailureNotificationKind.FinalFailure`.

## Configuration

### HangfireFailureNotificationOptions (existing, one new property)

`compliance-sys-api/src/ComplianceSys.Application/Services/Hangfire/HangfireFailureNotificationOptions.cs`, section `"HangfireFailureNotification"` (name unchanged — see `research.md` Decision 5):

| Property | Change |
|---|---|
| `NotifyOnSuccess` | **New**, `bool`, default `true`. Gates whether `HangfireSuccessEmailNotifier` sends anything. |
| `Enabled`, `Recipients`, `Cc`, `DashboardUrl`, `NotifyOnRetry`, `NotifyOnFinalFailure`, `RetryAttempts` | Unchanged; reused as-is for the success side. |

## Relationships / flow

```
Job method runs (one of the six)
  ├─ succeeds
  │    └─ calls IHangfireSuccessEmailNotifier.Notify(HangfireSuccessNotificationEvent)
  │          └─ always sends the generic success email (HadContent no longer suppresses it — reversed 2026-08-21 per user feedback)
  ├─ fails with an exception that propagates (4 of the 6 jobs, unchanged)
  │    └─ Hangfire → FailedState → existing global HangfireFailureNotificationFilter → IHangfireFailureEmailNotifier
  └─ fails internally and is caught before returning (2 known cases)
       └─ the catch block itself calls IHangfireFailureEmailNotifier.Notify(HangfireFailureNotificationEvent) directly
```

No new persisted "job run history" table is introduced — the notification email itself is the run-status record, per the spec's scope (Assumptions: only the six named methods, no new channel beyond the existing outbound mail mechanism).
