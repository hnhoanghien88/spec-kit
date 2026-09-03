# Implementation Plan: Group Email — Add "DK Alert" Type Option

**Branch**: `018-compl-group-email-dk-alert` | **Date**: 2026-09-03 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/018-compl-group-email-dk-alert/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Add a third selectable Type option, "DK Alert" (value `3`), to the existing Group Email index/Add/Edit feature, which today only offers "Responsible" (`1`) and "Alert" (`2`). The backend enum (`GroupEmailType`) and the `compl_group_email.GroupType` column already accept value `3` — no schema or enum change is needed. The work is: (1) fix `CommonMappingProfile`'s binary Responsible/Alert ternary so `GroupType == 3` maps to display label "DK Alert" instead of falling into "Alert" (US1–US3), (2) add minimal validation so Create/Update reject any `GroupType` outside `{1, 2, 3}` (edge case / FR-006), and (3) add the third `<MenuItem>` to both the edit-mode (`GroupRow.jsx`) and add-mode (`NewGroupRow.jsx`) Type dropdowns, sourced from a new shared `GROUP_EMAIL_TYPE_OPTIONS` constant in `helpers.js` (following the `ALERT_TYPE_OPTIONS` precedent from feature 007-compl-master) instead of the two files' current hardcoded, duplicated lists. No new screens, routes, or endpoints — this extends the existing `ComplGroupEmailController` payload's accepted/returned range only, per Constitution Principle III.

## Technical Context

**Language/Version**: Backend: C# / .NET 8. Frontend: JavaScript (React 18 / Vite), MUI.

**Primary Dependencies**: Backend: AutoMapper, Dapper (`Shared.Dapper`), FluentValidation, Serilog. Frontend: MUI (`@mui/material`), React.

**Storage**: MySQL (`compl_group_email` table — `GroupType` is an existing unconstrained `int`/`GroupType` column already populated with values `1`/`2` today; no migration needed since value `3` is already valid at the data layer, see `research.md` R1/R3).

**Testing**: No existing automated test suite covers this feature slice (`ComplGroupService`, `CommonMappingProfile`'s group-email mapping, or the `group-email` frontend pages); manual verification via `quickstart.md`, consistent with sibling feature 007-compl-master.

**Target Platform**: Web application (ASP.NET Core Web API backend + React SPA frontend).

**Project Type**: Web application (existing monorepo: `compliance-sys-api` + `compliance-client`).

**Performance Goals**: N/A — a label-mapping branch, a validator rule, and a dropdown option; no new performance-sensitive paths.

**Constraints**: Must not change the behavior of the existing "Responsible"/"Alert" values or any other Group Email field (`Name`, `IsDefault`, `IsAddition`, member/detail rows). Must not expose or validate-in `GroupType == 4` (`AlertForAddition`) — that value stays reserved/out of scope for this feature. Must not change routes, controller signatures, or authorization policies.

**Scale/Scope**: 1 mapping-profile branch expansion, 1 validator rule, 2 shared frontend constants, 2 frontend components updated (both already-existing Type dropdowns) — no new files outside `helpers.js` additions, no schema/migration changes.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Layered Clean Architecture** — PASS. Backend changes stay within `Application` (`CommonMappingProfile.cs`, `ComplGroupRequestDtoValidator.cs`); `ComplGroupEmailController.cs` needs no changes (already thin, delegates to `IComplGroupService`). Frontend changes stay within the existing `presentation/pages/group-email` feature folder (`GroupRow.jsx`, `NewGroupRow.jsx`) plus the shared `utils/helpers.js` — no new layer-crossing introduced.
- **II. Reference-Pattern Reuse** — PASS. The new `GROUP_EMAIL_TYPE`/`GROUP_EMAIL_TYPE_OPTIONS` frontend constants directly clone the style of `ALERT_TYPE`/`ALERT_TYPE_OPTIONS` in `helpers.js` (introduced by feature 007-compl-master for the same kind of byte-coded type + labeled dropdown). The backend mapping/validator changes extend existing, already-working patterns (`CommonMappingProfile`'s `ForMember(...MapFrom(...))`, `BaseValidator<T>`-style `RuleFor`) rather than inventing new ones.
- **III. Reuse Existing Backend** — PASS. `ComplGroupEmailController.cs`, its routes, and its authorization policies (`GroupEmail.Create/Update/ReadAll/...`) are reused unchanged. The `GroupEmailType` enum and the `GroupType` column already support value `3`; the only backend additions are the verified gaps: the label-mapping ternary that currently mislabels any non-1 value as "Alert", and the missing range validation on `GroupType`. No entity, DTO, controller, or endpoint is regenerated or duplicated.
- **IV. Vietnamese Comments; Localizable UI Labels** — PASS. The Group Email screen's existing UI labels ("Responsible", "Alert", column headers, etc.) are already in English, so "DK Alert" matches the feature's own established UI language, consistent with the literal label given in the spec's Assumptions. New backend/frontend code comments (if any) follow the existing Vietnamese-comment style (matching `helpers.js`'s `ALERT_TYPE` comment block and `CommonMappingProfile.cs`'s file-level Vietnamese doc comment).
- **V. Routing & Menu Registration** — PASS / N/A. No new routes or menu entries — `/group-email` is already registered and reachable; this feature only changes what one existing field's dropdown/label can show.

No violations; Complexity Tracking section is empty.

## Project Structure

### Documentation (this feature)

```text
specs/018-compl-group-email-dk-alert/
├── plan.md                              # This file
├── research.md                          # Phase 0 output
├── data-model.md                        # Phase 1 output
├── quickstart.md                        # Phase 1 output
├── contracts/
│   └── group-email-type.md              # Phase 1 output (payload delta: groupType/groupTypeName)
└── tasks.md                             # Phase 2 output (/speckit-tasks)
```

### Source Code (repository root)

```text
compliance-sys-api/
└── src/
    └── ComplianceSys.Application/
        ├── Mappings/
        │   └── CommonMappingProfile.cs               # GroupTypeName mapping: 1→"Responsible",
        │                                              # 2→"Alert", 3→"DK Alert" (was binary ternary)
        └── Validators/
            └── ComplGroupRequestDtoValidator.cs       # + RuleFor(x => x.GroupType) restricted to {1,2,3}
        # ComplGroupEmailController.cs, ComplGroupService.cs, GroupEmailType.cs,
        # ComplGroupEmailRequestDto.cs, ComplGroupEmailResponseDto.cs, compl_group_email table: NO CHANGE

compliance-client/
└── src/
    ├── utils/
    │   └── helpers.js                                # + GROUP_EMAIL_TYPE, GROUP_EMAIL_TYPE_OPTIONS
    └── presentation/
        └── pages/
            └── group-email/
                └── components/
                    ├── GroupRow.jsx                   # edit-mode Type Select: map over
                    │                                  # GROUP_EMAIL_TYPE_OPTIONS instead of hardcoded MenuItems
                    └── NewGroupRow.jsx                # add-mode Type Select: same change
                # IndexEmailGroup.jsx, GroupsTable.jsx, MembersTable.jsx/*: NO CHANGE
```

**Structure Decision**: Existing web-application layout (`compliance-sys-api` + `compliance-client`) is reused unchanged. All backend changes stay within `Application` (no `Domain`, `Infrastructure`, or `Api` changes needed — the enum and column already support value 3). All frontend changes stay within the existing `presentation/pages/group-email/components` feature folder plus the shared `utils/helpers.js`. No new files, no new routes, no new menu entries.

## Complexity Tracking

*No Constitution Check violations — this section is intentionally empty.*
