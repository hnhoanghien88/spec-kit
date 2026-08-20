# Quickstart: Validate Compliance Synchronize Data (Sales Line + Variant Attributes)

## Prerequisites

- `compliance-sys-api` running locally (or against the target environment) with a valid D365
  connection configured (same connection `DynController`/`ComplDynamicsService` already use — no
  new configuration is introduced by this feature).
- A bearer token for an authenticated user (same auth used for any other `Eutr*`/`Compl*` endpoint).
- D365 test data containing:
  - At least one Sales Line whose Item ID + Config ID has a matching `RSVNProductVariantAlls` record
    (to exercise Acceptance Scenario 3).
  - At least one Sales Line whose Item ID + Config ID has **no** matching `RSVNProductVariantAlls`
    record (to exercise Acceptance Scenario 4).
  - At least two Sales Lines sharing the same Item ID + Config ID (to exercise User Story 2's
    "one lookup per distinct combination, not per row" behavior — the same behavior now also applies
    to Phase 1's Product-reference lookup, research.md R10).
- MySQL access to inspect `compl_sync_sales_line` and `compl_sync_variant_attributes` directly.

## 1. Confirm the new `product-variant-info` endpoint (research.md R10)

```
GET /api/dynamics/product-variant-info?filter=ProductCode eq 'QO01500' and ConfigId eq '31631'&top=5
Authorization: Bearer <token>
```

(Use a real Product Code/Config ID pair from your D365 test data.) Expected: raw D365 JSON with a
non-empty `value` array; each item's `ProductCode`, `ConfigId`, `ProductName`, `ProductDescription`,
`ProductVariantType` are populated. `Range` may be blank if the live D365 `RSVNProductVariantAlls`
entity does not actually expose a `Range` field — see research.md R3; if every returned item has a
blank `Range`, verify against D365 metadata directly whether the field exists before treating this as
a bug.

## 2. Note the "before" state of both new tables

```sql
SELECT COUNT(*) AS before_sales_line FROM compl_sync_sales_line;
SELECT COUNT(*) AS before_variant_attrs FROM compl_sync_variant_attributes;
```

## 3. Trigger the sync

```
GET /api/compl-synchronize-data/test-compl-synchronize-data
Authorization: Bearer <token>
```

Expected: `200 OK`, `data.success = true`, `data.salesLineAdded + data.salesLineSkipped ==
data.salesLineFetched`.

## 4. Confirm Phase 1 results (User Story 1, Acceptance Scenarios 1-4)

```sql
SELECT COUNT(*) AS after_sales_line FROM compl_sync_sales_line;
-- after_sales_line should equal data.salesLineAdded from step 3 (table is cleared first — FR-008)

SELECT ProductCode, ConfigId, SalesId, SalesStatus, Name, Description, Type, Range
FROM compl_sync_sales_line
LIMIT 20;
```

- Every row's `ProductCode`/`SalesId`/`SalesStatus` should match its source Sales Line's `ItemId`/
  `SalesId`/`SalesStatus`.
- For the Sales Line prepared with a matching reference type 6 record (Prerequisites): confirm
  `Name`/`Description`/`Type`/`Range` are populated from that reference record.
- For the Sales Line prepared with no matching reference type 6 record: confirm the row was still
  saved, with `Name`/`Description`/`Type`/`Range` blank.

## 5. Confirm full-dataset coverage (Acceptance Scenario 1 / SC-001)

If the D365 Sales Line dataset spans more than one page (more than the sync's internal page size),
confirm `data.salesLineFetched` from step 3 matches the count obtained by manually paging through
`GET /api/dynamics/sales-line` with `skip=0,50,100,...` until an empty/short page is returned — i.e.,
the sync did not stop at the first page.

## 6. Confirm distinct Product/Config grouping (User Story 2, Acceptance Scenarios 1 & 2)

```sql
SELECT ProductCode, ConfigId, COUNT(*) AS row_count
FROM compl_sync_sales_line
WHERE ProductCode IS NOT NULL AND ConfigId IS NOT NULL
GROUP BY ProductCode, ConfigId;
```

`data.distinctProductConfigCount` from step 3 should equal the number of rows this query returns.
For the combination prepared with multiple Sales Lines sharing the same Item ID + Config ID
(Prerequisites), confirm it appears as exactly **one** row here (`row_count > 1`), and that Phase 2
performed exactly one lookup for it — not `row_count` lookups (verify by comparing
`data.distinctProductConfigCount` to the number of distinct combinations, not the raw Sales Line
count).

## 7. Confirm Phase 2 results (Acceptance Scenarios 3 & 5)

```sql
SELECT COUNT(*) AS after_variant_attrs FROM compl_sync_variant_attributes;

SELECT ProductCode, ConfigId, AttributeTypeName, AttributeValueName, GroupValue
FROM compl_sync_variant_attributes
LIMIT 20;
```

For each distinct combination noted in step 6 that has real Variant Attribute data in D365, confirm
its rows appear here with matching `ProductCode`/`ConfigId`. A combination with no Variant Attribute
data in D365 should contribute zero rows here (not an error — `data.success` remains `true`).

## 8. Confirm phase ordering (Acceptance Scenario 6)

This cannot be observed mid-run via a single synchronous call, but can be confirmed indirectly: if
`compl_sync_sales_line` were somehow left empty before step 3 (e.g., truncated manually) and the D365
Sales Line source were also temporarily empty, `data.distinctProductConfigCount` and
`data.variantAttributeAdded` should both be `0` — Phase 2 never runs against stale or partial Phase 1
data, since it always re-derives its input from the table Phase 1 just fully repopulated.

## 9. Confirm idempotency (SC-006)

Re-run step 3 immediately with no changes to D365 data in between. Expected: `compl_sync_sales_line`
ends up with the same row count and content as after the first run — not doubled — since it is cleared
before being repopulated each run (FR-008). `compl_sync_variant_attributes` should likewise show the
same content for every combination processed this run — not doubled — since each combination's rows
are deleted immediately before that combination's fresh rows are inserted (FR-012, scoped per
`ProductCode`+`ConfigId` rather than a whole-table clear as of the 2026-08-20 update; see spec.md).

## 10. Confirm failure handling (Edge Cases)

If reachable in a test environment (e.g. by temporarily forcing a D365 call to fail mid-run), confirm
the run stops at the first failure, `data.success = false`, and `data.message` reports which phase was
in progress and the counts completed before the failure — with no automatic rollback of rows already
saved.
