# Phase 1 Data Model: EUTR Sales Orders Management

No new database table/migration is introduced by this feature. Data flows entirely through the
existing shared D365 reference lookup; the only "model" change is additive fields on an existing
response DTO.

## Entity: Sales Order (reference data, read-only)

Source: D365 entity `RSVNSalesOrderOpenInvoiceCogs` (`compliance-sys-api/src/ComplianceSys.Domain/
Dynamics/RSVNSalesOrderOpenInvoiceCogs.cs`), surfaced through
`POST /api/dynamics/reference?refType=11`.

| Field (spec column) | Source property (D365 entity) | Response DTO property | Type | Notes |
|---|---|---|---|---|
| Sales ID | `SalesId` | `Code` (and `Id`) | string | Also used as the `CodeColumn` for search-by-code filtering (`BuildFilterString`). |
| Customer | `CustAccount` | `CustAccount` (new) | string | Customer account/code — distinct from `Code`. |
| Customer name | `CustName` | `Name` | string | Used as the `NameColumn` for search-by-name filtering. |
| Delivery date | `DeliveryDate` | `DeliveryDate` (new) | date/null | Nullable — grid MUST show a placeholder ("-") when absent (spec FR-006). |

Not surfaced to the frontend for this feature (present on the D365 entity but out of scope):
`PurchId`, `RSVNSalesId`, `CustGroup`, `SalesStatus`, `InvoiceDate`, `CustomerRef`,
`TotalCompliances`, `TotalMissing`, `TotalApplied`, `TotalOverdue`, `ResponsibleEmails`,
`AlertEmails`.

Read-only: this entity is never created/updated/deleted by this system; it is queried live from
D365 on every request (subject to the same paging/filter/sort mechanics as every other `refType`).

## Response DTO change: `ComplDynReferenceResponseDto`

`compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/ComplDynReferenceResponseDto.cs`

```
Id            string   // existing — SalesId for refType=11
Code          string   // existing — SalesId for refType=11 (CodeColumn)
Name          string   // existing — CustName for refType=11 (NameColumn)
CustAccount   string?  // NEW — populated only for refType=11; null for every other refType
DeliveryDate  DateTime? // NEW — populated only for refType=11; null for every other refType
```

Additive-only change: existing consumers of other `refType`s are unaffected (fields default to
`null`/absent in JSON if unset).

## Mapping registration: `ComplDynamicsService`

`EntityMappings` (compile-time dictionary keyed by raw `refType` int):

```
{ (int)ObjectType.SALE_ORDER /* = 11 */, ("RSVNSalesOrderOpenInvoiceCogs", "SalesId", "CustName") }
```

`MapDynamicsResponse` switch: new `case 11:` branch deserializes items as
`List<RSVNSalesOrderOpenInvoiceCogs>` and projects each into `ComplDynReferenceResponseDto` with
`Id`/`Code` = `SalesId`, `Name` = `CustName`, `CustAccount` = `CustAccount`, `DeliveryDate` =
`DeliveryDate`.

## Frontend row shape (`SalesOrderOverviewPage.jsx`)

Each grid row, after fetching page(s) via `GetReferenceDataUseCase.execute(page, pageSize, "Code",
"asc", 11, filters)`:

| Grid column | Row field (from API item) | Fallback when empty |
|---|---|---|
| Sales ID | `item.code` (or `item.id`) | — (always present) |
| Customer | `item.custAccount` | "-" |
| Customer name | `item.name` | "-" |
| Delivery date | `item.deliveryDate` | "-" (spec FR-006 / Edge Cases) |
| Template | fixed demo constant (e.g. `"Template A"`) | n/a — always the same value |
| Progress | fixed demo constant (e.g. a static `%` + fixed bar value) | n/a — always the same value |

Search (spec FR-011) reuses the existing generic filter payload shape already sent by
`useReferenceObjects`/`GetReferenceDataUseCase` — one filter on the `Code` column and one on the
`Name` column (both `like`), which `BuildFilterString`/`EntityMappings` resolve to `SalesId`/
`CustName` respectively for `refType=11`.

Pagination (spec FR-010): standard `page`/`pageSize` request params already supported by
`GetReferenceDataUseCase`/`dynamicsApi.getReferenceData`; page size chosen at implementation time
(e.g. reuse the grid component's existing page-size convention).
