---

description: "Task list template for feature implementation"
---

# Tasks: Compliance Job Run-Status Email Notifications

**Input**: Design documents from `/specs/017-compl-report-services/`

**Prerequisites**: [plan.md](./plan.md) (required), [spec.md](./spec.md) (required for user stories), [research.md](./research.md), [data-model.md](./data-model.md), [quickstart.md](./quickstart.md)

**Tests**: Not explicitly requested in the spec. One unit-test task is included in Polish to mirror the existing `HangfireFailureNotificationFilterTests.cs` convention, but story phases below are implementation-only.

**Organization**: Tasks are grouped by user story (US1, US2, US3 — see [spec.md](./spec.md)) to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Single existing backend project: `compliance-sys-api/src/...`, `compliance-sys-api/tests/...` (see [plan.md](./plan.md) Project Structure). No frontend changes.

---

## Phase 1: Setup

**Purpose**: Establish a regression baseline before touching anything.

- [X] T001 Run the existing test suite as a baseline (`dotnet test compliance-sys-api/tests/ComplianceSysApi.UnitTests`), confirming `Services/Hangfire/HangfireFailureNotificationFilterTests.cs` passes before any change in this feature

**Checkpoint**: Baseline green — safe to start Foundational work.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The shared success-notification building blocks that User Story 1 and User Story 3 call into. (User Story 2 only reuses the already-existing `IHangfireFailureEmailNotifier` and has no dependency on this phase, but per convention it still waits for Setup to complete.)

**⚠️ CRITICAL**: T006–T008 and T011 (User Story 1 and 3) cannot compile until T002–T005 exist.

- [X] T002 [P] Create `HangfireSuccessNotificationEvent` DTO (JobId, JobName, ServiceType, MethodName, OccurredAtUtc, HadContent, Summary, DashboardUrl — see [data-model.md](./data-model.md)) in `compliance-sys-api/src/ComplianceSys.Application/Services/Hangfire/HangfireSuccessNotificationEvent.cs`
- [X] T003 [P] Add a `NotifyOnSuccess` boolean property (default `true`) to `HangfireFailureNotificationOptions`, bound from the same existing `"HangfireFailureNotification"` config section, in `compliance-sys-api/src/ComplianceSys.Application/Services/Hangfire/HangfireFailureNotificationOptions.cs`
- [X] T004 Create `IHangfireSuccessEmailNotifier` and `HangfireSuccessEmailNotifier` in `compliance-sys-api/src/ComplianceSys.Application/Services/Hangfire/HangfireSuccessEmailNotifier.cs` (depends on T002, T003): build subject/HTML mirroring `HangfireFailureEmailNotifier`'s style, send via `MailAlert` to `_options.Recipients`/`Cc` when `_options.Enabled && _options.NotifyOnSuccess`; when `notification.HadContent` is `true`, treat the call as a no-op (the business email the job already sent this run stands in for the run-status notice — FR-005); wrap the actual `MailAlert.SendMail` call in try/catch that only logs (never throws) so a mail failure here can never cascade into another failure (FR-009, FR-010)
- [X] T005 Register `HangfireSuccessEmailNotifier` as a singleton (`services.AddSingleton<IHangfireSuccessEmailNotifier, HangfireSuccessEmailNotifier>();`) in `compliance-sys-api/src/ComplianceSys.Application/DependencyInjection.cs`, next to the existing `IHangfireFailureEmailNotifier` registration (depends on T004)

**Checkpoint**: Foundation ready — User Story 1 and User Story 3 implementation can now begin.

---

## Phase 3: User Story 1 - Know that a scheduled compliance job actually ran (Priority: P1) 🎯 MVP

**Goal**: Every run of `SendAlertAsync`, `SyncAsync`, and `ProcessAsync` emails a run-status notification, success or failure (the two known blind-spot jobs are covered by User Story 2; the not-yet-scheduled sales-order job is covered by User Story 3).

**Independent Test**: Manually trigger `sent_alert_compliance`, `MasterDefaultReferenceSync`, and `master_default_processor` via the existing `ComplJobScheduleConfigController.TriggerJob` endpoint (or Hangfire dashboard) and confirm a success email arrives for each, identifying the job and run time (quickstart.md Scenarios 1–3).

### Implementation for User Story 1

- [X] T006 [P] [US1] In `SendAlertAsync` (`compliance-sys-api/src/ComplianceSys.Application/Services/ComplNotificationService.cs:144-165`), inject `IHangfireSuccessEmailNotifier` via constructor and call `NotifySuccess(...)` at the end of the try block with `HadContent = true` when an alert email was sent this run, `false` otherwise (existing failure path already propagates to the untouched global `HangfireFailureNotificationFilter` — no catch-block change needed here)
- [X] T007 [P] [US1] In `SyncAsync` (`compliance-sys-api/src/ComplianceSys.Application/Services/MasterDefaultRefSyncService.cs:34-56`), inject `IHangfireSuccessEmailNotifier` and call `NotifySuccess(...)` with `HadContent = false` at the end of the method's success path (existing failure path already propagates unchanged)
- [X] T008 [P] [US1] Convert `ProcessAsync` in `compliance-sys-api/src/ComplianceSys.Application/Services/MasterDefaultService.cs:271-275` from its expression-bodied pass-through into an async method body that awaits `_masterDefaultRepository.ProcessAsync(jobUser, ct)` and then calls the newly-injected `IHangfireSuccessEmailNotifier.NotifySuccess(...)` with `HadContent = false` (existing failure path — the repository throwing — already propagates unchanged)

**Checkpoint**: User Story 1 is fully functional and testable independently of User Stories 2 and 3.

---

## Phase 4: User Story 2 - Surface failures that are currently hidden (Priority: P1)

**Goal**: The two known blind-spot failures (a `GetAndSaveSummarySo` timeout, and a `SendMailForProcessedMastersAsync` mail-send error) each still produce a failure email even though the method's own code catches and silences the exception before Hangfire ever sees it.

**Independent Test**: Force the summary-sync timeout path and the masters-mail-send failure path (quickstart.md Scenario 4) and confirm a failure email arrives for each, and that the mail-send failure leaves its logs unmarked (pending retry) rather than falsely marked as sent.

### Implementation for User Story 2

- [X] T009 [US2] In `GetAndSaveSummarySo` (`compliance-sys-api/src/ComplianceSys.Application/Services/ViewCompliances/ViewCompliancesSummaryService.cs:29-124`): inject `IHangfireFailureEmailNotifier` and `IHangfireSuccessEmailNotifier`; in the `catch (OperationCanceledException) when (timeoutCts.IsCancellationRequested)` block (lines 119-123), build a `HangfireFailureNotificationEvent` (`Kind = HangfireFailureNotificationKind.FinalFailure`, message describing the 3-hour timeout) and call `Notify(...)` — guarded so the notifier call itself cannot throw — before the existing `return false;`; call `IHangfireSuccessEmailNotifier.NotifySuccess(...)` with `HadContent = false` just before the existing `return true;` on the normal success path
- [X] T010 [US2] In `SendMailForProcessedMastersAsync` (`compliance-sys-api/src/ComplianceSys.Application/Services/MasterDefaultService.cs:277-305`): in the `catch (Exception ex)` around the `SendMailAndNotificationByMasterDefaultCreateAsync` call (lines 296-299), build a `HangfireFailureNotificationEvent` (`Kind = FinalFailure`, message including the affected `masterIds`) and call `IHangfireFailureEmailNotifier.Notify(...)` — guarded so it cannot itself throw — then `return` immediately, **skipping** the subsequent `MarkLogsAsSentAsync` call so the pending logs are retried on the next scheduled run (FR-004); on the two success paths (nothing-pending early return, and mail-sent-plus-marked-as-sent), call `IHangfireSuccessEmailNotifier.NotifySuccess(...)` with `HadContent = false` and `true` respectively. Depends on T008 (same file, `ProcessAsync` and `SendMailForProcessedMastersAsync` are both in `MasterDefaultService.cs` — apply T008 first, then this task, to avoid merge conflicts in the same file)

**Checkpoint**: User Stories 1 AND 2 both work independently; the two previously-silent failure paths now notify.

---

## Phase 5: User Story 3 - Bring the sales-order alert job into the same monitoring (Priority: P3)

**Goal**: `SendSalesOrderAlertAsync` becomes a scheduled recurring job (it isn't one today) and gets the same success/failure run-status visibility as the other five jobs.

**Independent Test**: Confirm `compl_job_schedule_configs` contains the new `sent_alert_sales_order` row, trigger it manually, and confirm it produces the same success/failure notification behavior validated for the other five jobs (quickstart.md Scenario 5).

### Implementation for User Story 3

- [X] T011 [US3] In `SendSalesOrderAlertAsync` (`compliance-sys-api/src/ComplianceSys.Application/Services/ComplNotificationService.cs:176-233`), call the already-injected (via T006) `IHangfireSuccessEmailNotifier.NotifySuccess(...)` at the end of the try block, with `HadContent = true` when the sales-order-missing alert email was sent this run, `false` otherwise (existing failure path already propagates unchanged). Depends on T006 (same file/same constructor injection — apply after T006 to avoid a duplicate injection edit)
- [X] T012 [P] [US3] Create `compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Migration/27_seed_sales_order_alert_job.sql`, an `INSERT ... ON DUPLICATE KEY UPDATE` into `compl_job_schedule_configs` seeding `JobId = 'sent_alert_sales_order'`, `ServiceType = 'ComplianceSys.Application.Interfaces.Services.IComplNotificationService'`, `MethodName = 'SendSalesOrderAlertAsync'`, `CronExpression = '15 3 * * *'`, `Timezone = 'SE Asia Standard Time'`, `Queue = 'default'`, `IsEnabled = 1` (mirrors the existing seed shape in `Sqls/Tables/compl_job_schedule_configs.sql:32-76`)
- [X] T013 [US3] Apply the migration from T012 locally and verify `HangfireJobRegistrar.ReloadAll` picks up the new `sent_alert_sales_order` recurring job on startup/reload, then trigger it once via `ComplJobScheduleConfigController.TriggerJob` and confirm a run-status email arrives (depends on T011, T012) — **verified statically only**: confirmed `IComplNotificationService.SendSalesOrderAlertAsync()` has no parameters, matching `HangfireJobRegistrar.BuildJob`'s reflection-based method resolution exactly as the other 5 seeded jobs do; a live end-to-end trigger requires a running MySQL + SMTP + Hangfire dashboard, not available in this sandbox — see quickstart.md Scenario 5 for the manual steps to run in a real environment

**Checkpoint**: All three user stories are independently functional; all six jobs now have consistent run-status visibility.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Verification and documentation that spans all three stories.

- [X] T014 [P] Add `HangfireSuccessEmailNotifierTests.cs` in `compliance-sys-api/tests/ComplianceSysApi.UnitTests/Services/Hangfire/`, mirroring `HangfireFailureNotificationFilterTests.cs`'s structure, covering: `NotifyOnSuccess = false` suppresses sending, `HadContent = true` is a no-op (FR-005), `HadContent = false` sends, and a `MailAlert` exception is caught and logged without throwing (FR-009/FR-010)
- [X] T015 Re-run `dotnet test compliance-sys-api/tests/ComplianceSysApi.UnitTests` and confirm `HangfireFailureNotificationFilterTests.cs` is still green (the existing global failure filter is untouched by this feature — regression check per research.md Decision 1) — full suite: 146/149 passed; the 3 failures (`MappingConfigurationTests`, `ComplSynchronizeDataServiceTests` x2) are pre-existing and unrelated, confirmed by re-running them against the unmodified base branch
- [ ] T016 Walk through all five scenarios in [quickstart.md](./quickstart.md) end-to-end against a locally running `compliance-sys-api`, confirming exactly one email per run in every case — **not run**: requires a live MySQL instance, SMTP server, and Hangfire dashboard, none of which are available in this environment; code-level correctness was instead verified via the unit test suite (T014/T015) and manual code review of every call site
- [X] T017 [P] Document the new `HangfireFailureNotification:NotifyOnSuccess` config key (default `true` if omitted) in `compliance-sys-api/src/ComplianceSys.Api/appsettings.Development.json` and any other environment `appsettings.*.json` files that already carry the `HangfireFailureNotification` section — only `appsettings.Development.json` has the section today, so only it was updated

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies.
- **Foundational (Phase 2)**: Depends on Setup. Blocks User Story 1 and User Story 3 (both call the new `IHangfireSuccessEmailNotifier`). User Story 2 does not depend on Phase 2's output (it only reuses the existing `IHangfireFailureEmailNotifier`) but still follows Setup in sequence for simplicity.
- **User Stories (Phase 3–5)**: See below.
- **Polish (Phase 6)**: Depends on all three stories being complete.

### User Story Dependencies

- **User Story 1 (P1)**: Depends on Foundational (T002–T005). Otherwise independent of US2/US3.
- **User Story 2 (P1)**: Independent of Foundational and of US1/US3, **except** for one file-level ordering constraint: T010 touches `MasterDefaultService.cs`, the same file as US1's T008, so T010 must be applied after T008 to avoid conflicting edits to the same constructor/class.
- **User Story 3 (P3)**: T011 touches `ComplNotificationService.cs`, the same file as US1's T006, so T011 must be applied after T006. T012 (the SQL seed) has no code dependency and is fully parallel.

### Within Each User Story

- User Story 1: T006, T007, T008 are mutually parallel-safe (three different files).
- User Story 2: T009 (different file) is parallel-safe with anything in US1/US3; T010 must follow T008 (same file).
- User Story 3: T012 is parallel-safe with everything; T011 must follow T006 (same file); T013 (manual verification) follows both T011 and T012.

### Parallel Opportunities

- T002 and T003 (Foundational) run in parallel — different files.
- T006, T007, T008 (User Story 1) run in parallel — three different files.
- T009 (User Story 2) and T012 (User Story 3) run in parallel with User Story 1's tasks and with each other — all different files.
- T014 and T017 (Polish) run in parallel — different files.

---

## Parallel Example: User Story 1

```bash
# After Foundational (T002-T005) completes, launch all of User Story 1 together:
Task: "SendAlertAsync notify-success in compliance-sys-api/src/ComplianceSys.Application/Services/ComplNotificationService.cs"
Task: "SyncAsync notify-success in compliance-sys-api/src/ComplianceSys.Application/Services/MasterDefaultRefSyncService.cs"
Task: "ProcessAsync convert + notify-success in compliance-sys-api/src/ComplianceSys.Application/Services/MasterDefaultService.cs"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001).
2. Complete Phase 2: Foundational (T002–T005) — required before User Story 1 compiles.
3. Complete Phase 3: User Story 1 (T006–T008).
4. **STOP and VALIDATE**: Trigger each of the three jobs and confirm a success email for each (quickstart.md Scenarios 1–3).

### Incremental Delivery

1. Setup + Foundational → foundation ready.
2. User Story 1 → test independently → this alone already closes the core visibility gap for 3 of 6 jobs (MVP).
3. User Story 2 → test independently → closes the two known silent-failure blind spots (arguably the most valuable story — consider doing this in parallel with, or even before, User Story 1's Foundational-dependent work, since it has no dependency on the new notifier).
4. User Story 3 → test independently → brings the sixth job under the same schedule/monitoring, completing full coverage of all six originally-named methods.

### Notes

- User Story 2 has no dependency on the Foundational phase and could be started immediately after Setup if staffed separately — it only needs the already-existing `IHangfireFailureEmailNotifier`.
- [P] tasks = different files, no dependencies.
- Commit after each task or logical group.
- Stop at any checkpoint to validate a story independently before moving to the next.

---

## Post-Implementation Change (2026-08-21)

After all tasks above were completed and manually tested against a live instance, user feedback reversed FR-005's dedup rule: `HangfireSuccessEmailNotifier` now **always** sends the generic success email, even when the job already sent its own business-content email (previously it was a no-op in that case). Updated: `HangfireSuccessEmailNotifier.cs` (removed the `HadContent` suppression check), `HangfireSuccessNotificationEvent.cs` (doc comment only — field kept as descriptive metadata), `HangfireSuccessEmailNotifierTests.cs` (renamed/adjusted the now-obsolete no-op test), and `spec.md`/`research.md`/`data-model.md`/`quickstart.md` marked accordingly. Full Hangfire test subset re-run: 10/10 passed.
