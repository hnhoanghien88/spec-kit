# Contract: `POST /api/dynamics/reference` with `refType = 21` (Sales Lines — ItemId/ConfigId lookup)

New `refType` registration on the already-existing shared endpoint (`DynController.ReferenceData`,
`ComplianceSys.Api/Controllers/DynController.cs`) — no new route is introduced. Introduced by spec
Update 43 (2026-09-30) to back the Overview screen's new **ItemId**/**ConfigId** search inputs. The
underlying D365 entity `RSVNSalesLineOpenInvoiceCogs` already exists in this codebase and is already
queried successfully by two unrelated services via direct D365 calls (`ComplSynchronizeDataService.
FetchAllSalesLinesAsync`, `DynamicsDataService.GetSalesLineOpenInvoiceCogsFromDynamics`) — this contract
only concerns the NEW path of reaching it through the generic `EntityMappings`/`GetDynRefePagedAsync`
mechanism.

## Request

```
POST /api/dynamics/reference?page=1&pageSize=500&sortColumn=Code&sortOrder=asc&refType=21
Body: FilterRequest[]   // e.g. [{ column: "ItemId", operator: "eq", value: "ITM-001" },
                         //       { column: "ConfigId", operator: "eq", value: "CFG-01" }]
```

- `column: "ItemId"` and `column: "ConfigId"` both resolve generically (the "other" AND bucket of
  `BuildFilterString` — no entity-scoped special case needed, since these columns don't collide with
  any other entity's reserved bucket names) to D365 `ItemId`/`ConfigId` on `RSVNSalesLineOpenInvoiceCogs`.
- Sending both in the same request combines them via AND (must match a line with both values) — the
  existing generic "other" bucket behavior, not a new mechanism.
- Sending only one of the two filters is valid; the other is simply omitted from the request body.
- `column: "Code"`/`"Id"` resolve to D365 `SalesId` (per `EntityMappings[21].CodeColumn = "SalesId"`)
  — usable for other callers, though the Overview screen's own usage (spec Update 43) never filters by
  it, only reads it from the response.

## Response (`PagedResult<ComplDynReferenceResponseDto>`)

```json
{
  "items": [
    { "id": "SO007071", "code": "SO007071", "itemId": "ITM-001" },
    { "id": "SO007080", "code": "SO007080", "itemId": "ITM-001" }
  ],
  "totalCount": 2
}
```

- One row per matching `RSVNSalesLineOpenInvoiceCogs` record (i.e. per sales line, not deduplicated by
  `SalesId` — a Sales Order with 2 lines both matching the filter produces 2 rows with the same `code`).
  Callers needing a distinct `SalesId` list (e.g. the Overview ItemId/ConfigId search) MUST dedupe
  client-side (`[...new Set(items.map(i => i.code))]`), same as every other batch-read pattern in this
  codebase.
- `id`/`code` both = `SalesId` (mirrors every other `refType`'s convention of `Code` being the primary
  identifying column).
- `itemId` = the line's `ItemId` (useful for debugging/display; not required for the SalesId-extraction
  use case). `configId`/`name` are not populated by this `refType`'s mapping — only `id`/`code`/`itemId`.

## Before this feature (current behavior)

`refType = 21` does not exist — `RSVNSalesLineOpenInvoiceCogs.cs` has no `RSVNModelBase` base class, no
`EntityMappings` entry, and no `MapDynamicsResponse` case, so it cannot be reached through this generic
endpoint at all today (a request with `refType=21` would fail entity-mapping lookup before reaching
D365).

## Backward compatibility

Net-new `refType` registration — no existing caller sends `refType = 21` today (there is nothing to
conflict with). The 2 existing direct callers of `RSVNSalesLineOpenInvoiceCogs` (`ComplSynchronizeDataService`,
`DynamicsDataService`) do not go through this endpoint/`EntityMappings` and are unaffected by this
registration existing alongside their own direct usage of the same domain class.

## Update 45 — added response fields

`refType=21`, filter `SalesId eq '<id>'` (existing `filter` mechanism) now also returns `productName` and `productDescription` per row (one row per sales line). `id`/`code`/`itemId`/`configId` unchanged. Used by Step 1 (Map File) and Selected Purchase Orders (View) to build line groups; callers dedupe by (itemId, configId). Backward compatible (additive fields).

Caller note: filter `SalesId eq '<id>'`; group key = `itemId-configId` matched to refType=20 `productVariant`.

**(Update 45 — chỉnh lần cuối)**: Update 45 KHÔNG còn dùng refType=21; `productName`/`productDescription` nay do refType=20 trả về (xem `map-file-reused-endpoints.md`). Mục "added response fields" ở trên không còn hiệu lực.
