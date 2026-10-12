# Contract: `GET /api/eutr-synchronize-data/test-so-progression` (Update 3, 2026-10-12)

Manually triggered test action in `EutrSynchronizeDataController` (same shape as `test-clear-file`).

## Behavior

1. Reads every page (1000/page) of D365 reference type 11 (`RSVNSalesOrderOpenInvoiceCogs`) via
   `IComplDynamicsService.GetDynRefePagedAsync`, sorted by `Code` (= `SalesId`) asc.
2. Takes the distinct, non-blank `SalesId` values.
3. For each `SalesId` runs `IEutrProgressionService.RecomputeAsync(salesId, "system")` sequentially
   (writes/deletes the `eutr_progression` row; per-SalesId errors are swallowed and logged by
   `RecomputeAsync` itself, so one failure does not stop the run).
4. Reads the results back in batches of 1000 via `IEutrProgressionService.GetBySalesIdsAsync` — the
   same function behind `POST /api/eutr-progression/by-sales-ids`.

## Response

`ApiResponse<EutrSoProgressionSummaryDto>`:
`{ totalFetched, distinctSalesIds, withProgression, withoutProgression, success, message }`.
`withoutProgression` = SalesIds with no `eutr_progression` row (no template/attachment yet → "empty").
A D365 fetch failure stops the run: `success = false`, counts reflect progress so far.

## Update 3a — Hangfire execution (2026-10-12)

The endpoint no longer runs the work inline (an HTTP request is cancelled by the client/proxy after ~2 minutes,
which aborted the run before late SalesIds were reached). It enqueues `RunSoProgressionAsync` through Hangfire
and returns immediately:

```json
{ "success": true, "message": "so-progression job enqueued", "data": "<hangfire job id>" }
```

The `EutrSoProgressionSummaryDto` is no longer returned to the caller; it is logged on completion
(`RunSoProgressionAsync - Hoan tat: Fetched …, distinct SalesIds …, with progression …, without …`). Progress can
also be followed in the Hangfire dashboard or in `eutr_progression`. Job-level cancellation (server shutdown)
still stops the run.

## Update 3b — source of SalesIds (2026-10-12)

Behavior step 1-2 above are superseded: SalesIds are read with `SELECT DISTINCT SalesId FROM
eutr_purchase_attachments WHERE TemplateCode IS NOT NULL` (`GetSalesIdsWithTemplateAsync`), blank values dropped,
de-duplicated case-insensitively. D365 refType 11 is no longer queried; D365 is still called inside
`RecomputeAsync` (refType 16, OrderAccount per PO). `totalFetched` equals `distinctSalesIds`.
