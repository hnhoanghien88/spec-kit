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

## Response (`PagedResult<ComplDynReferenceResponseDto>`)

```json
{
  "items": [
    {
      "id": "SO007071",
      "code": "SO007071",
      "name": "HOLA",
      "custAccount": "10611",
      "deliveryDate": "2026-11-15T00:00:00"
    }
  ],
  "totalCount": 1
}
```

- `custAccount` and `deliveryDate` are **new** fields on the shared DTO — `null`/absent for every
  `refType` other than `11`.
- `deliveryDate` MAY be `null` for a given Sales Order — the frontend MUST render a placeholder
  ("-") in that case (spec FR-006), not treat it as an error.

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
