# Contract: `POST /api/dynamics/reference` — consumed for Purchase Orders (`refType=15`) and Vendor lookup (`refType=14`)

**Status**: Existing endpoint, reused unchanged for `refType=15`/`14` themselves. One additive
change to its filter-building logic is proposed (see "Proposed change" below) — everything else in
this contract already exists and already behaves as documented.

**Owner**: `compliance-sys-api` — `DynController` (`POST /api/dynamics/reference`) →
`ComplDynamicsService.GetDynRefePagedAsync`.

## Request (unchanged shape)

```jsonc
{
  "page": 1,
  "pageSize": 20,
  "sortColumn": "Code",        // or "Name"
  "sortOrder": "asc",
  "refType": 15,                 // 15 = Purchase Order, 14 = Vendor
  "filters": [
    { "column": "Code", "operator": "like", "value": "PO001" }
  ]
}
```

## Response (existing shape, `ComplDynReferenceResponseDto`, additive fields already present)

For `refType = 15` (`RSVNEutrPurchOrders`):

```jsonc
{
  "items": [
    {
      "id": "PO0001234",
      "code": "PO0001234",       // = PurchId
      "name": "Some PO name",
      "eutrTemplate": "TPL-A",   // blank/null when no Template assigned
      "orderAccount": "V-00042"  // Vendor code
    }
  ],
  "totalCount": 3241
}
```

For `refType = 14` (`VendorsV3`), used for the batched Vendor-name lookup (research.md Decision 2):

```jsonc
{
  "items": [
    { "id": "V-00042", "code": "V-00042", "name": "Acme Vendor Co." }
  ],
  "totalCount": 1
}
```

Batched call shape: one `refType=14` request per visible page, with one `{ column: "Code",
operator: "eq", value: <orderAccount> }` filter entry per distinct `OrderAccount` on that page — the
same repeated-same-column-OR-filter technique `005-eutr-sales-orders` Update 16 already uses for its
own Sales-ID whitelist (`ComplDynamicsService.BuildFilterString` OR-joins same-bucket entries).

## Proposed additive change: Vendor-code OR-search for `refType = 15`

**Today**: a `filters` entry with `column: "Code"` or `"Name"` is OR-joined into the free-text
search group; any other `column` value (e.g. `"OrderAccount"`) is AND-joined separately, so a single
keyword cannot match Purch id **or** Vendor code in one call.

**Change**: `ComplDynamicsService.BuildFilterString`'s column-bucketing switch gains one more
reserved bucket, scoped so it only resolves for `RSVNEutrPurchOrders`:

```csharp
var filtersByType = validFilters.GroupBy(f => f.Column.ToLower() switch
{
    "code" or "id" => "code",
    "name" => "name",
    "vendorcode" when mapping.Entity == "RSVNEutrPurchOrders" => "vendorcode",
    _ => "other"
});
// ...
var columnName = group.Key switch
{
    "code" => mapping.CodeColumn,
    "name" => mapping.NameColumn,
    "vendorcode" => "OrderAccount",
    _ => filter.Column
};
// vendorcode joins the same OR-joined searchFilters list as code/name:
if (group.Key is "code" or "name" or "vendorcode")
    searchFilters.Add(filterStr);
```

**Caller-side request** (frontend search box, one keyword → OR across 2 columns):

```jsonc
{
  "refType": 15,
  "filters": [
    { "column": "Code", "operator": "like", "value": "<keyword>" },
    { "column": "VendorCode", "operator": "like", "value": "<keyword>" }
  ]
}
```

**Compatibility**: No other `refType` is affected (the new bucket only resolves for
`RSVNEutrPurchOrders`; every other entity's `"vendorcode"`-labelled filter, if ever sent, falls
through to the unchanged `"other"`/AND-joined behavior it has today). No response shape change, no
new endpoint, no migration.
