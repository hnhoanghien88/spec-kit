# Implementation Plan: PO Upload Folder Grouping

**Branch**: `master` (no dedicated feature branch created) | **Date**: 2026-09-22 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/019-po-upload-folder-grouping/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Change SharePoint folder resolution for Type = PO document uploads so that every PO-code folder
(`PO000123`, `PO000124`, ...) is nested under one shared parent folder named `PO` at the storage
root, instead of sitting flat at the root alongside every other folder. This is a **backend-only,
verified-gap fix** per Constitution Principle III: the actual folder-resolution logic lives in a
single service, `EutrUploadService` (owned by `004-eutr-documents`), which `005-eutr-sales-orders`
and `012-eutr-purchase-orders` both call into unchanged — so fixing it once in that service
satisfies the requirement for all three features. Research also surfaced one additional
already-existing consumer of the flat layout, `EutrSynchronizeDataService` (feature
`011-eutr-synchronize-data` / `018-compl-group-email-dk-alert`'s missing-PO-folder alert), which
lists folders directly under the storage root and must be updated in lockstep or it will silently
stop detecting existing PO folders once they move under `PO/`.

## Technical Context

**Language/Version**: C# / .NET 8 (existing `compliance-sys-api` solution)

**Primary Dependencies**: `ISharepointService` (`Shared.ExternalServices.Interfaces`) — no new
package dependencies

**Storage**: SharePoint folders (no MySQL schema change; no PO↔folder mapping table exists or is
added, consistent with `004-eutr-documents` research Quyết định 13)

**Testing**: xUnit + Moq, `compliance-sys-api/tests/ComplianceSysApi.UnitTests`

**Target Platform**: Existing ASP.NET Core Web API (`ComplianceSys.Api`)

**Project Type**: Backend-only change inside an existing web application (monorepo); no frontend
changes (frontend already passes `poCode`/`typeName`/`refValues` through as opaque strings and
contains no folder-path logic)

**Performance Goals**: No new performance requirement; adds at most one extra
`GetFolders`/`CreateFolder` round trip to SharePoint per PO-type upload batch and per sync run
(negligible next to existing per-PO `GetFolders` calls)

**Constraints**: MUST NOT alter folder structure for any non-PO Type; MUST NOT move/migrate
documents already stored in the old flat `<PoCode>` folders (spec Assumptions/FR-007)

**Scale/Scope**: Two backend service classes, their unit tests; no controllers, DTOs, or database
migrations change shape

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principle I (Layered Clean Architecture)**: PASS — change stays entirely inside
  `ComplianceSys.Application/Services/` (business rule for folder resolution); no controller logic
  changes beyond what already delegates to these services.
- **Principle II (Reference-Pattern Reuse)**: N/A — this is a targeted fix to existing logic, not a
  new CRUD feature; nothing to clone.
- **Principle III (Reuse Existing Backend)**: PASS (this is the controlling principle) — no
  controller, DTO, validator, or entity is regenerated. Only the folder-name resolution inside
  `EutrUploadService` and the folder-listing logic inside `EutrSynchronizeDataService` are edited,
  both verified gaps found by tracing the actual flat-folder behavior against the requested nested
  behavior.
- **Principle IV (Vietnamese Comments; Localizable UI Labels)**: PASS — no UI change; existing
  Vietnamese comment style in the touched files MUST be preserved/extended, not replaced.
- **Principle V (Routing & Menu Registration)**: N/A — no new screen or route.

No violations. Complexity Tracking table not needed.

## Project Structure

### Documentation (this feature)

```text
specs/019-po-upload-folder-grouping/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
compliance-sys-api/
├── src/
│   ├── ComplianceSys.Application/
│   │   └── Services/
│   │       ├── EutrUploadService.cs           # MODIFY: nest PO-code folder under "PO" parent
│   │       └── EutrSynchronizeDataService.cs  # MODIFY: look for PO-code folders inside "PO" parent
│   └── ComplianceSys.Api/
│       └── Controllers/
│           └── SharePointController.cs        # NO CHANGE (thin passthrough, verified in research)
└── tests/
    └── ComplianceSysApi.UnitTests/
        └── Services/
            ├── EutrUploadServiceTests.cs           # ADD/UPDATE cases for nested "PO/<PoCode>" path
            └── EutrSynchronizeDataServiceTests.cs  # UPDATE existing GetFolders mocks + add case

compliance-client/   # NO CHANGE — verified: no client-side folder-path logic exists; frontend only
                      # passes poCode/typeName/refValues through as opaque strings (004/005/012
                      # research already confirms this pass-through)
```

**Structure Decision**: Backend-only change confined to two existing `ComplianceSys.Application`
service classes and their existing test files. No new files, layers, endpoints, or frontend work.
This satisfies 004-eutr-documents, 005-eutr-sales-orders, and 012-eutr-purchase-orders simultaneously
because both 005 and 012 call into `EutrUploadService`/`EutrSynchronizeDataService` rather than
implementing their own folder logic (confirmed in research.md).

## Complexity Tracking

> Not applicable — no Constitution Check violations.
