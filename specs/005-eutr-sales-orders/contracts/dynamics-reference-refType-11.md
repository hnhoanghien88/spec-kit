# Contract: `POST /api/dynamics/reference` with `refType = 11` (Sales Orders)

This is an extension of an existing shared endpoint (`DynController.ReferenceData`,
`ComplianceSys.Api/Controllers/DynController.cs`) — no new route is introduced. This document
scopes the contract to the new behavior for `refType = 11` only; all other `refType` values are
unaffected.

## Request

```
POST /api/dynamics/reference?page={page}&pageSize={pageSize}&sortColumn={col}&sortOrder=asc|desc&refType=11
Body: FilterRequest[]   // existing shape, e.g. [{ column: "Code", operator: "like", value: "SO007" }]
```

- `sortColumn` MUST be one of the columns exposed below (`Code`/`Id`, `Name`, or the raw D365 column
  names already supported generically by `BuildFilterString`).
- Filters on `column: "Code"` resolve to D365 `SalesId`; filters on `column: "Name"` resolve to
  D365 `CustName` — same generic resolution every other `refType` already uses via
  `EntityMappings[refType].CodeColumn/NameColumn`.
- **Update 27**: filters on `column: "CustAccount"` resolve to D365 `CustAccount` (the same field
  already returned as `custAccount` in the response below) and OR-join with `Code`/`Name` filters in
  the same search bucket — the same shape `refType = 15` (Purchase Orders) already uses for its own
  `VendorCode` OR-search extension. This resolution is scoped to `refType = 11` only (guarded by
  `mapping.Entity == "RSVNSalesOrderOpenInvoiceCogs"`), the same entity-scoping already applied to the
  `VendorCode` case — sending `column: "CustAccount"` for any other `refType` is a no-op (falls through
  to the generic "other column" AND bucket), not an error.

## Response (`PagedResult<ComplDynReferenceResponseDto>`)

```json
{
  "items": [
    {
      "id": "SO007071",
      "code": "SO007071",
      "name": "HOLA",
      "custAccount": "10611",
      "deliveryDate": "2026-11-15T00:00:00",
      "rsVnETD": "2026-11-10T00:00:00",
      "salesStatus": "Backorder"
    }
  ],
  "totalCount": 1
}
```

- `custAccount` and `deliveryDate` are **new** fields on the shared DTO — `null`/absent for every
  `refType` other than `11`.
- `deliveryDate` MAY be `null` for a given Sales Order — the frontend MUST render a placeholder
  ("-") in that case (spec FR-006), not treat it as an error.
- `rsVnETD` (**new in Update 24**) is likewise `null`/absent for every `refType` other than `11`, MAY be
  `null` for a given Sales Order (spec FR-161 — render a placeholder, not an error), and is sourced from
  the same `RSVNSalesOrderOpenInvoiceCogs.RsVnETD` field already present on this entity (research.md
  Decision 74) — no new D365 field, no migration.
- `salesStatus` (**retro-documented in Update 25** — this field already existed in the DTO/response
  before Update 25, just never listed in this contract) is `null`/absent for every `refType` other than
  `11`, and carries the raw D365 `SalesStatus` enum **label** (e.g. `"Backorder"`, `"Invoiced"`)
  unmodified. The frontend maps the label `"Backorder"` (case-insensitive) to the display text
  **"Open order"** (spec FR-171); this is a presentation-layer rendering rule only — the API contract
  itself is unchanged by Update 25, and every other raw value passes through as-is.

## Filtering by ETD Year/Week (Update 24, `refType = 11` only)

In addition to the generic `{ column, operator, value }` filters this endpoint already accepts, `refType =
11` now also recognizes two special filter entries on column `RsVnETD`, with the **exact same shape**
`compliance-view`'s own Year/ETD Week dropdowns already send to a different backend service:

```json
[
  { "column": "RsVnETD", "operator": "inyear", "value": "2026" },
  { "column": "RsVnETD", "operator": "inweeks", "value": "2026:3,5,9" }
]
```

- Send **either** `inyear` (whole calendar year, no week selected) **or** `inweeks` (one or more ISO
  weeks of that year) — never both for the same request; `buildEtdWeekFilters(year, weeks)` in
  `compliance-view/utils/isoWeek.js` already produces at most one of these two entries and is reused
  verbatim by `SalesOrderOverviewPage.jsx` (research.md Decision 75).
- These two operators are intercepted and resolved via `EtdWeekFilterBuilder`/`IsoWeekRange` (unchanged,
  already used by `AllCompliancesService` for `compliance-view`) **before** reaching the generic
  `eq`/`ne`/`gt`/`ge`/`lt`/`le` operator set `ODataOperatorConverter` already supports — sending `inyear`/
  `inweeks` for any other `refType`, or on any column other than `RsVnETD`, is a no-op (ignored), not an
  error.
- Combines via AND with the existing Sales ID/Customer/Customer ID search filter (`column: "Code"`/
  `"Name"`/`"CustAccount"`, Update 27) and with the Update 16 Template-whitelist filter, when either is
  also present in the same request.

## Sorting (Update 24: new default, no contract change)

`sortColumn = "DeliveryDate"`/`sortOrder = "desc"` already works today via this endpoint's existing
default-passthrough behavior in `MapSortColumn` — Overview's own default fetch call now sends these
literal values instead of `"Code"`/`"asc"`. No new `sortColumn` value is introduced by this endpoint;
this section only documents that the frontend's own default choice changed.

## Before this feature (current behavior)

`refType = 11` has no `EntityMappings` entry → `GetDynRefePagedAsync` returns
`{ "items": [], "totalCount": 0 }` unconditionally, regardless of filters. This is the "verified
gap" this feature closes.

## Backward compatibility

No existing caller passes `refType = 11` today (confirmed empty result is the current, unused
behavior) except `compliance-view-so`'s already-existing assumption that `11` means "Sale order"
(used for a different purpose — compliance drill-down labeling, not this reference lookup) — this
change does not alter that unrelated usage. All other `refType` values keep their existing
`EntityMappings` entry and mapping `case` untouched; the two new DTO fields are additive and
`null`/omitted for them.
