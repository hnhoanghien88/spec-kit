# Contract: `GET /api/eutr-synchronize-data/test-so-template-sync`

New endpoint, new controller `EutrSynchronizeDataController` (modeled on
`ComplNotificationController`'s attribute shape and response conventions).

## Request

```
GET /api/eutr-synchronize-data/test-so-template-sync
Authorization: Bearer <token>
```

No query parameters, no body. Manually triggered (see spec Assumptions — this is a "test" action,
not a scheduled job).

## Behavior

1. Reads every page of D365 reference type 19 (`RSVNEutrSalesOrderTemplates`, "Sales Order
   Templates") via the existing internal reference pipeline (`IComplDynamicsService.GetDynRefePagedAsync`),
   not a second HTTP call to `DynController` (research.md R1).
2. For each record: derives `SalesId` / `PurchId` / `TemplateCode` from
   `InterCompanyOriginalSalesId` / `RSVNRefPurchId` / `RSVNEutrTemplate`.
3. Skips (does not add) a record if any of the three derived values is missing, or if a
   `eutr_purchase_attachments` row already exists for that `SalesId` (from a prior run, or from any
   other feature such as Map File).
4. Adds a new `eutr_purchase_attachments` row for every other record.

## Response

```json
{
  "success": true,
  "message": "Fetched 1240, added 812, skipped 428",
  "data": {
    "totalFetched": 1240,
    "added": 812,
    "skipped": 428,
    "success": true,
    "message": "Fetched 1240, added 812, skipped 428"
  }
}
```

Wrapped in this codebase's standard `ApiResponse<EutrSynchronizeSummaryDto>` envelope, matching
every action in `ComplNotificationController` (e.g. `TestAlert`, `TestSalesOrderAlert`).

- Zero records available from D365 → `totalFetched = 0`, `added = 0`, `skipped = 0`, `success = true`
  (spec Edge Case: empty source is not an error).
- D365 fetch fails partway through (any page) → the run stops, `success = false`, `message`
  describes the failure; counts reflect progress made before the failure. Records already inserted
  before the failure are **not** rolled back (spec Edge Case; research.md R7).
- Running twice in a row with unchanged D365 data → second run returns `added = 0`,
  `skipped = totalFetched` (spec SC-002).

## Before this feature (current behavior)

`refType = 19` currently returns an empty result from `GetDynRefePagedAsync` regardless of what
data exists in D365, because of the `EntityMappings` gap described in research.md R2 — there is no
existing caller depending on that empty-result behavior (verified: no repo reference to
`RSVNEutrSalesOrderTemplates` outside `ComplDynamicsService.cs` itself before this feature). No
endpoint reads or writes `eutr_purchase_attachments` from D365 today; the only existing writer is
`EutrPurchaseAttachmentsService.SavePoMappingAsync` (manual Map File save, unrelated to D365 sync).

## Backward compatibility

Net-new endpoint and net-new DTO. The `EntityMappings`/`MapDynamicsResponse` changes to
`ComplDynamicsService` (research.md R2/R3) are additive and affect only `refType = 19`, which has no
existing consumers — no other `refType` or caller is affected.
