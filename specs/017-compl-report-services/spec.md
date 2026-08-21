# Feature Specification: Compliance Job Run-Status Email Notifications

**Feature Branch**: `017-compl-report-services`

**Created**: 2026-08-21

**Status**: Draft

**Input**: User description: "compl-report-services. kiểm tra các services IComplNotificationService>SendAlertAsync, IViewCompliancesService>GetAndSaveSummarySo, IMasterDefaultRefSyncService>SyncAsync, IMasterDefaultService>ProcessAsync, IMasterDefaultService>SendMailForProcessedMastersAsync, IComplNotificationService>SendSalesOrderAlertAsync trong job-config chạy qua hangfire thì có sử dụng HangfireFailureNotification để gửi email không, cần cập nhật lại chạy thành công hay thất bại cũng gửi email để nắm rõ"

## Current-State Findings *(informational — from codebase investigation)*

These six scheduled-job methods were investigated for email-on-success and email-on-failure behavior:

| # | Method | Scheduled today? | Sends email on success? | Sends email on failure? |
|---|---|---|---|---|
| 1 | `IComplNotificationService.SendAlertAsync` | Yes (daily) | Only the business alert content, when there is something to alert on | Exception propagates → covered by the existing global Hangfire failure filter |
| 2 | `IViewCompliancesService.GetAndSaveSummarySo` | Yes (daily) | No | **Gap**: a timeout is caught internally and swallowed, so the global failure filter never fires for a timeout; other exceptions do propagate |
| 3 | `IMasterDefaultRefSyncService.SyncAsync` | Yes (~12x/day) | No | Exception propagates → covered by the existing global failure filter |
| 4 | `IMasterDefaultService.ProcessAsync` | Yes (~12x/day) | No | Exception propagates → covered by the existing global failure filter |
| 5 | `IMasterDefaultService.SendMailForProcessedMastersAsync` | Yes (~12x/day) | Only the business "masters created" content, when there is something pending | **Gap**: mail-send errors are caught internally and never rethrown, so the job always reports "succeeded" to Hangfire even when the notification email failed to send |
| 6 | `IComplNotificationService.SendSalesOrderAlertAsync` | **No** — exists only as a manually-triggered test endpoint, not wired into any recurring job schedule | Only the business alert content, when there is something to report | Not applicable today (not scheduled); if it were scheduled, exceptions would propagate the same way as #1 |

The system already has a generic failure-notification mechanism (a global Hangfire job filter that emails an operations address when a scheduled job's exception exhausts its retries), but it has two gaps (#2, #5 above) where an internal `catch` block prevents that mechanism from ever seeing the failure. There is no equivalent mechanism today for confirming that a job **succeeded** — only some jobs incidentally send a business-content email when they find something to report, and several send no email at all even on a clean run.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Know that a scheduled compliance job actually ran (Priority: P1)

As the person responsible for the compliance batch jobs, I want to receive a clear notification every time one of the six monitored jobs finishes running — whether it succeeded or failed — so that I always know the job executed and what happened, instead of having to check server logs to find out.

**Why this priority**: This is the core ask — visibility into run outcomes is currently inconsistent (some jobs are silent on success, and two jobs can fail without any failure notice at all). Without this, operational issues can go unnoticed for days.

**Independent Test**: Trigger each of the six jobs manually (or wait for its schedule) and confirm a run-status email arrives describing the outcome, without needing any of the other user stories implemented.

**Acceptance Scenarios**:

1. **Given** a scheduled job completes without error, **When** the run finishes, **Then** a notification is sent (or an existing business email is extended) that clearly identifies the job and states it succeeded.
2. **Given** a scheduled job throws an unhandled exception, **When** the run fails, **Then** a failure notification is sent identifying the job, the failure time, and a summary of the error.
3. **Given** a job run produced no business content to report (e.g., no new compliances found), **When** the run finishes, **Then** the operator can still tell from the notification history that the job ran and completed successfully.

---

### User Story 2 - Surface failures that are currently hidden (Priority: P1)

As the person responsible for these jobs, I want to be notified even when a failure is currently caught and silenced inside the job's own code (the timeout case in `GetAndSaveSummarySo` and the swallowed mail-send error in `SendMailForProcessedMastersAsync`), so that these two known blind spots stop hiding real problems.

**Why this priority**: These are the two concrete gaps found during investigation where a job can fail today and nobody is told — closing them is the most impactful part of this feature.

**Independent Test**: Force each of the two known internal-catch scenarios (a summary-sync timeout, and a masters-created mail-send failure) and confirm a failure notification is still sent even though the job itself does not propagate the exception to Hangfire.

**Acceptance Scenarios**:

1. **Given** the compliance summary sync job exceeds its internal timeout, **When** the internal timeout handler catches the condition, **Then** a failure notification is still sent describing the timeout.
2. **Given** the masters-processed mail step fails to send its business email, **When** the internal error handler catches the send failure, **Then** a failure notification is still sent describing the mail-send failure, and the affected records are not marked as successfully notified.

---

### User Story 3 - Bring the sales-order alert job into the same monitoring (Priority: P3)

As the person responsible for these jobs, I want the sales-order alert job to be scheduled and monitored the same way as the other five, so run-status visibility is consistent across all six services named in this request rather than five out of six.

**Why this priority**: Lower priority because this job is not currently scheduled at all — bringing it under monitoring first requires making it a recurring job, which is a separate decision from the notification behavior itself.

**Independent Test**: Confirm the sales-order alert job appears in the job schedule configuration and that a run of it produces the same success/failure notification behavior as the other five jobs.

**Acceptance Scenarios**:

1. **Given** the sales-order alert job is added to the recurring job schedule, **When** it runs on its schedule, **Then** it produces a success or failure run-status notification consistent with the other five jobs.

---

### Edge Cases

- What happens when the job ran successfully but found nothing to report (no compliances, no masters, no sales-order mismatches)? The operator must still be able to distinguish "ran, nothing to do" from "did not run at all."
- What happens if the email/mail server itself is unavailable when the run-status notification is being sent? This must not crash the job or be mistaken for the job itself having failed.
- What happens when a job that already sends a business-content email on success also needs a run-status notification — the operator should not receive two separate, redundant "it worked" emails for the same run.
- Every run of every monitored job sends a notification regardless of frequency or outcome (per FR-007); high-frequency jobs (e.g., the ~12x/day reference-sync and processor jobs) will therefore generate a correspondingly higher volume of routine emails — this is an accepted tradeoff in favor of full visibility.
- What happens the first time the sales-order alert job is scheduled, given it has never run on an automated schedule before — its first scheduled run should be monitored the same as any other job's run.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST send a notification email at the end of every run of each of the six named job methods, indicating whether that run succeeded or failed.
- **FR-002**: Each notification MUST identify which job ran, when it ran, and the outcome (success or failure); a failure notification MUST additionally include a summary of the error that caused the failure.
- **FR-003**: The system MUST send a failure notification for the `GetAndSaveSummarySo` internal timeout case even though that case is currently caught and swallowed before it would reach the existing Hangfire failure mechanism.
- **FR-004**: The system MUST send a failure notification for the `SendMailForProcessedMastersAsync` mail-send failure case even though that case is currently caught and swallowed before it would reach the existing Hangfire failure mechanism; affected records MUST NOT be marked as successfully sent when the send failed.
- **FR-005**: ~~For jobs that already send a business-content email...~~ **Superseded 2026-08-21**: the generic run-status success email MUST always be sent for every successful run, even when the job already sent its own business-content email for that run (`SendAlertAsync`, `SendMailForProcessedMastersAsync`, `SendSalesOrderAlertAsync`). Confirmed via user feedback after testing: relying on the business email alone to double as run-status confirmation was confusing in practice, since it wasn't visually distinguishable as "the job ran/succeeded" from an ordinary business notification.
- **FR-006**: The system MUST add `SendSalesOrderAlertAsync` to the recurring job schedule (it is not currently scheduled), running once daily in the same early-morning time window as `SendAlertAsync`, so that it becomes subject to the same run-status monitoring as the other five jobs.
- **FR-007**: For every job run — whether it succeeds with content to report, succeeds with nothing to report, or fails — the system MUST send a run-status notification every time, with no suppression of routine "ran fine, nothing to report" runs.
- **FR-008**: The system MUST send these run-status notifications to the same recipient/distribution list already configured for the existing Hangfire failure-notification mechanism, rather than a new separate list.
- **FR-009**: The system MUST continue to record each run's outcome even if the notification email itself fails to send, so a mail-delivery problem never silently erases the record that a job ran and what happened.
- **FR-010**: The failure-notification mechanism MUST NOT itself be capable of causing a further failure loop (e.g., a failure while trying to send a failure notification must not be reported as another job failure needing its own notification).

### Key Entities

- **Job Run**: A single execution of one of the six monitored job methods; has a job identifier, a start/end time, an outcome (succeeded/failed), and — for failures — an error summary.
- **Run-Status Notification**: An email describing the outcome of one Job Run, sent to the configured recipients.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For all six monitored jobs, 100% of failed runs result in a failure notification being sent, including the two previously-silent failure cases identified in this investigation.
- **SC-002**: An operator can determine, from email alone and without checking server logs, whether each monitored job ran and what its outcome was for any given day.
- **SC-003**: ~~No job run produces more than one "run succeeded" notification...~~ **Superseded 2026-08-21**: every successful run always produces its own distinct, clearly-labeled run-status success email, in addition to any business-content email the job also sends.
- **SC-004**: The sales-order alert job appears in the job schedule and produces the same run-status visibility as the other five jobs within one release cycle of this feature shipping.

## Assumptions

- The existing global Hangfire failure-notification mechanism (job filter + email sender + configurable recipients) remains the foundation to build on; this feature extends and closes its gaps rather than replacing it.
- "Email" here means the same outbound mail mechanism already used elsewhere in this system (`MailAlert`), not a new notification channel (e.g., Slack, SMS, in-app).
- ~~Business-content emails... considered part of "notifying on success"...~~ **Superseded 2026-08-21** (see FR-005): the generic run-status success email is now always sent alongside any business-content email, rather than being deduplicated against it.
- This feature only covers the six job methods explicitly named in the request; other Hangfire jobs in the system are out of scope unless a future request extends this pattern to them.
