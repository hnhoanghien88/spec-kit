# Quickstart: Validating Compliance Job Run-Status Notifications

## Prerequisites

- `compliance-sys-api` running locally (`dotnet run` from `src/ComplianceSys.Api`) against `appsettings.Development.json`, which already has `HangfireFailureNotification:Enabled = true` and a recipient (`thiennh@response.com.vn`) — see `compliance-sys-api/src/ComplianceSys.Api/appsettings.Development.json:70-77`.
- The DB migration from `research.md` Decision 6 applied, so `compl_job_schedule_configs` contains the new `sent_alert_sales_order` row alongside the five existing rows (see `data-model.md`).
- A reachable SMTP config (or a local mail-catcher) so `MailAlert.SendMail` actually delivers/captures messages during manual verification.
- Hangfire dashboard reachable at the URL configured in `HangfireFailureNotification:DashboardUrl` (`https://localhost:7141/hangfire` in dev), to trigger jobs on demand via `ComplJobScheduleConfigController.TriggerJob(id)` instead of waiting for the cron schedule.

## Scenario 1 — Normal success sends a run-status email (FR-001, FR-007)

1. Trigger `MasterDefaultReferenceSync` (`IMasterDefaultRefSyncService.SyncAsync`) manually via `POST /api/compl-job-schedule-config/{id}/trigger` (or the Hangfire dashboard "Trigger now").
2. Confirm the run completes without error in the Hangfire dashboard.
3. Confirm a success email arrives at the configured recipients (`HangfireFailureNotification:Recipients`) identifying the job, its run time, and a success outcome.

**Expected**: exactly one email for this run.

## Scenario 2 — Content-bearing success sends both emails (FR-005, updated 2026-08-21)

1. Ensure there is at least one compliance alert-worthy record, then trigger `SendAlertAsync` (`sent_alert_compliance`).
2. Confirm the existing business alert email is received as before.
3. Confirm a *separate* `[Hangfire-...] [SUCCESS]` run-status email also arrives for the same run.

**Expected**: two emails for this run — the business alert and the generic success notification. (Originally this scenario expected the second email to be suppressed; that was reversed per user feedback after testing — see research.md Decision 4.)

## Scenario 3 — No-content success still notifies (FR-007, clarification: "send every run, always")

1. With no pending masters to email, trigger `SendMailForProcessedMastersAsync` (`master_default_send_mail`).
2. Confirm a generic "ran successfully, nothing to report" email is still received.

**Expected**: exactly one email, even though there was nothing to report.

## Scenario 4 — Previously-silent failures now notify (FR-003, FR-004 — User Story 2)

1. Force the `GetAndSaveSummarySo` timeout path (e.g. temporarily lower the internal timeout for a local test run, or exercise it via the existing unit test in `tests/ComplianceSysApi.UnitTests`), and confirm a failure email is sent describing the timeout — even though the job's own code still swallows the exception and the Hangfire dashboard shows the job as completed rather than failed.
2. Force `SendMailForProcessedMastersAsync`'s mail-send step to fail (e.g. point `MailAlert` at an invalid SMTP host for a local test run), then confirm:
   - a failure email is sent describing the mail-send error, and
   - the affected logs are **not** marked as sent (re-querying `GetSuccessLogsForMailAsync`-backed data still shows them pending), so the next run retries them.

**Expected**: both cases produce a failure notification even though Hangfire's dashboard does not show a `Failed` state for that run.

## Scenario 5 — Sales-order alert job is now scheduled and monitored (User Story 3, FR-006)

1. Confirm `GET /api/compl-job-schedule-config` (or the DB directly) lists `sent_alert_sales_order` with cron `15 3 * * *` and `IsEnabled = 1`.
2. Trigger it manually and confirm it produces the same success/failure notification behavior validated in Scenarios 1–3 above.

**Expected**: the sales-order alert job behaves identically to the other five for run-status visibility.

## Regression check

- Re-run the existing `tests/ComplianceSysApi.UnitTests/Services/Hangfire/HangfireFailureNotificationFilterTests.cs` suite — the existing global failure filter must remain unaffected by these changes (it is not modified by this feature; see `research.md` Decision 1).
