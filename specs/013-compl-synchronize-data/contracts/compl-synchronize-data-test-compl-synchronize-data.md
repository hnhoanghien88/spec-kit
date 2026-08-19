# Contract: `GET /api/compl-synchronize-data/test-compl-synchronize-data`

New endpoint, new controller `ComplSynchronizeDataController` (modeled directly on
`EutrSynchronizeDataController`'s attribute shape, route style, and response conventions —
feature 011-eutr-synchronize-data).

## Request

```
GET /api/compl-synchronize-data/test-compl-synchronize-data
Authorization: Bearer <token>
```

No query parameters, no body. Manually triggered (see spec Assumptions — a "test" action, not a
scheduled job, matching 011's own three "test-" actions).

## Behavior

Runs both phases in one call, Phase 2 starting only after Phase 1 fully completes (FR-001, FR-009):

1. **Phase 1 — Sales Line + Product enrichment**:
   - Clears `compl_sync_sales_line` entirely (FR-008).
   - Reads every page of D365 `RSVNSalesLineOpenInvoiceCogs` (`sales-line` endpoint's underlying
     entity).
   - Derives the distinct set of `(ItemId, ConfigId)` combinations across Sales Line records that have
     both an Item ID and a Sales ID, and looks up each one via the new `DynController`
     `[HttpGet("product-variant-info")]` action (`RSVNProductVariantAlls`, filtered
     `ProductCode eq '{code}' and ConfigId eq '{configId}'`) — one call per **distinct** combination,
     not per Sales Line record (research.md R10, supersedes the original R4 bulk-fetch-via-`refType=6`
     design).
   - For each record with both an Item ID and a Sales ID: inserts one `compl_sync_sales_line` row —
     `ProductCode` = Item ID, `SalesId`, `SalesStatus` copied as-is, `ConfigId` copied as-is, and
     `ProductName`/`ProductDescription`/`ProductType`/`ProductRange` populated from the matching
     `product-variant-info` result (blank if no match) (FR-003 through FR-007).
2. **Phase 2 — Variant Attributes**:
   - Derives the distinct set of `(ProductCode, ConfigId)` combinations from `compl_sync_sales_line`
     (excluding any row with a blank Product Code or Config ID) (FR-009/FR-010).
   - Clears `compl_sync_variant_attributes` entirely (FR-012).
   - For each distinct combination: queries D365 `ProductVariantAttributes`
     (`product-variant-attributes` endpoint's underlying entity), filtered to that exact Product and
     Config, and inserts every returned attribute row (FR-011/FR-013); a combination with no returned
     data contributes no rows and is not an error (FR-014).

## Response

```json
{
  "success": true,
  "message": "Sales line: fetched 5230, added 5104, skipped 126. Distinct product/config: 340. Variant attributes added: 892",
  "data": {
    "salesLineFetched": 5230,
    "salesLineAdded": 5104,
    "salesLineSkipped": 126,
    "distinctProductConfigCount": 340,
    "variantAttributeAdded": 892,
    "success": true,
    "message": "Sales line: fetched 5230, added 5104, skipped 126. Distinct product/config: 340. Variant attributes added: 892"
  }
}
```

Wrapped in this codebase's standard `ApiResponse<ComplSynchronizeDataSummaryDto>` envelope, matching
`EutrSynchronizeDataController`'s existing actions.

- Zero Sales Line records available → `salesLineFetched = 0`, `salesLineAdded = 0`,
  `distinctProductConfigCount = 0`, Phase 2 performs zero lookups, `variantAttributeAdded = 0`,
  `success = true` (spec Acceptance Scenario 6 — empty source is not an error).
- D365 fetch fails partway through either phase → the run stops, `success = false`, `message`
  describes the failure and the phase; rows already saved before the failure are **not** rolled back
  (spec FR-017).
- Running twice in a row with unchanged D365 data → both tables end up holding the same content after
  the second run as after the first — no duplicate accumulation, since both tables are cleared before
  being repopulated each run (spec SC-006).

## Before this feature (current behavior)

`RSVNSalesLineOpenInvoiceCogs` and `ProductVariantAttributes` are today only reachable via
`DynController`'s raw `sales-line`/`product-variant-attributes` GET actions (returning unprocessed
D365 JSON) — no existing feature pages through them fully or persists their data locally. This feature
adds a third such raw action, `[HttpGet("product-variant-info")]` (sourcing `RSVNProductVariantAlls`,
same shape as the other two), replacing an earlier design that would have used the generic
`[HttpPost("reference")]` (`refType = 6`) mechanism instead (research.md R10) — `refType = 6` remains
defined in `ComplDynamicsService.EntityMappings` but, as before this feature, has no caller anywhere in
this codebase.

## Backward compatibility

Net-new controller action (`product-variant-info`), net-new service controller/DTO, two net-new
tables. The `RSVNProductVariantAlls.Range` property addition (research.md R3) is additive — no
existing field is removed, renamed, or reinterpreted. Unlike an earlier version of this design, no
changes are made to `ComplDynReferenceResponseDto` or `ComplDynamicsService.MapDynamicsResponse`
(both were reverted per research.md R10) — this feature's Application-layer changes are now scoped
entirely to its own new files, with `RSVNProductVariantAlls.Range` as the only shared-file touch.
