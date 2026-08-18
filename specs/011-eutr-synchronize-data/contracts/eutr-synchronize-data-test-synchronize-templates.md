# Contract: `GET /api/eutr-synchronize-data/test-synchronize-templates`

New action on the **existing** `EutrSynchronizeDataController` (same controller as
`test-so-template-sync`/`test-purchase-missing`; see the sibling contract files) — same
`[Authorize]`/`[ApiController]` scope, same `ApiResponse<T>` response-wrapping convention. Unlike the
other two actions, this one **writes to the ERP (D365)**, not to a local table — direction is
local-to-ERP (spec User Story 3, added 2026-08-17).

## Request

```
GET /api/eutr-synchronize-data/test-synchronize-templates
Authorization: Bearer <token>
```

No query parameters, no body. Manually triggered (see spec Assumptions — User Story 3 is, like User
Story 1 and User Story 2, a "test" action, not a scheduled job).

## Behavior

1. Reads every local `eutr_templates` row matching `IsDeleted = 0 AND IsHide = 0 AND Status = 1`
   (research.md R18) — the eligible Template population (FR-024).
2. **Phase 1 (delete)**: for every eligible template, in order, sends
   `POST {Dynamics:ApiUrl}/data/RSVNEutrTemplates/Microsoft.Dynamics.DataEntities.deleteTemplate?cross-company=true`
   with a JSON body (`Content-Type: application/json`) `{ "code": "<template.Code>" }` (research.md
   R20). This phase completes for every eligible template before Phase 2 begins for any of them
   (FR-025).
3. Determines each eligible template's currently active Vendor mapping(s) — `eutr_template_references`
   rows where `FromDate <= today AND ToDate >= today` (research.md R19) — in one batched query across
   all eligible templates (FR-026).
4. **Phase 2 (create, left join — corrected 2026-08-17)**: for every eligible template, in order:
   - If it has one or more currently active Vendor mappings, sends one
     `POST {Dynamics:ApiUrl}/data/RSVNEutrTemplates?cross-company=true` per mapping, with a JSON body
     `{ "Code": "<template.Code>", "Name": "<template.Name>", "VendorCode": "<mapping.VendorCode>" }`
     (research.md R20/R24, FR-027).
   - If it has zero currently active Vendor mappings, sends exactly **one**
     `POST {Dynamics:ApiUrl}/data/RSVNEutrTemplates?cross-company=true` with `VendorCode` sent as an
     empty string: `{ "Code": "<template.Code>", "Name": "<template.Name>", "VendorCode": "" }`
     (research.md R24, FR-028) — every eligible template gets at least one Phase 2 call, never zero.
   `?cross-company=true` is appended to both URLs to match `DynamicsParameterManager.BuildUrl()`'s
   convention, used by every other Dynamics call in this codebase (research.md R20) — `RSVNEutrTemplates`
   has no `dataAreaId` field, so omitting it risks the write being scoped to one default company.
5. If any Phase 1 or Phase 2 call fails, the run stops immediately (no further templates/mappings are
   processed) and is reported as a failed run; calls already sent before the failure are not rolled
   back (research.md R21, consistent with User Story 1/2's own D365-error handling).

## Response

```json
{
  "success": true,
  "message": "Eligible 42, deleted 42, pushed 57",
  "data": {
    "templatesEligible": 42,
    "deleteCallsSent": 42,
    "pushCallsSent": 57,
    "success": true,
    "message": "Eligible 42, deleted 42, pushed 57"
  }
}
```

Wrapped in this codebase's standard `ApiResponse<EutrSynchronizeTemplatesSummaryDto>` envelope,
matching every action in this controller.

- Zero eligible templates found → `templatesEligible = 0`, `deleteCallsSent = 0`, `pushCallsSent = 0`,
  `success = true` (nothing to do is not an error, consistent with the other two actions' empty-source
  edge case).
- An eligible template with zero currently active Vendor mappings → counted in `templatesEligible`,
  `deleteCallsSent`, **and** contributes exactly 1 to `pushCallsSent` (a single push with
  `VendorCode = ""`) — corrected 2026-08-17; previously it contributed 0 to `pushCallsSent` and was
  left with no ERP-side record at all (spec Acceptance Scenario 6, research.md R24).
- D365 call fails partway through either phase → the run stops, `success = false`, `message`
  describes the failure and how many calls were sent before it (spec Edge Case, research.md R21); no
  automatic rollback of delete/push calls already sent.
- Re-running with unchanged local data reproduces the same `deleteCallsSent`/`pushCallsSent` counts and
  the same ERP end-state (spec Acceptance Scenario 8/SC-010) — the delete-then-push shape is
  idempotent by construction, not by a separate dedup step.

## Before this feature (current behavior)

No existing endpoint or service pushes local `eutr_templates`/`eutr_template_references` data to D365
— every existing D365 interaction in this codebase (`IComplDynamicsService`) is read-only
(`GetDynRefePagedAsync`). `RSVNEutrTemplates` (`ComplianceSys.Domain/Dynamics/RSVNEutrTemplates.cs`)
already exists as a domain model but is currently unused by any service (research.md R20) — this
action is its first real caller. This is the first outbound (POST/write) call to D365 in the
codebase.

## Backward compatibility

Net-new action, net-new DTO, net-new repository methods on existing repository interfaces
(`IEutrTemplatesRepository.GetEligibleForDynamicsSyncAsync`,
`IEutrTemplateReferencesRepository.GetActiveByTemplateIdsAsync`) — both additive, neither changes any
existing method's behavior. No existing controller action, service method, or `refType` mapping in
`ComplDynamicsService` is touched by this story.
