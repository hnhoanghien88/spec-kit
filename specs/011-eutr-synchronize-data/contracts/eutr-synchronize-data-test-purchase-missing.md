# Contract: `GET /api/eutr-synchronize-data/test-purchase-missing`

New action on the **existing** `EutrSynchronizeDataController` (same controller as
`test-so-template-sync`; see `eutr-synchronize-data-test-so-template-sync.md`) — same
`[Authorize]`/`[ApiController]` scope, same `ApiResponse<T>` response-wrapping convention.

## Request

```
GET /api/eutr-synchronize-data/test-purchase-missing
Authorization: Bearer <token>
```

No query parameters, no body. Manually triggered (see spec Assumptions — User Story 2 is, like User
Story 1, a "test" action, not a scheduled job).

## Behavior

**Updated 2026-08-14**: findings are now persisted to a dedicated table (`eutr_purchase_missing`)
instead of staying in memory only — see steps 0 and 5a-5b below (research.md R17).

0. Deletes every existing row in `eutr_purchase_missing` (FR-020) — before anything else, including
   before the D365 fetch in step 1.
1. Reads every page of D365 reference type 15 (`RSVNEutrPurchOrders`, "Purchase Orders") via the
   existing internal reference pipeline (`IComplDynamicsService.GetDynRefePagedAsync`) — research.md
   R15 (same paging shape as User Story 1's R4).
2. Reads every page of D365 reference type 14 (`VendorsV3`, "Vendors") once, building a
   `VendorAccountNumber -> VendorOrganizationName` lookup used to fill the report's "Vendor name"
   column from each purchase order's `OrderAccount` ("Vendor code") — research.md R9.
3. Reads the current SharePoint folder listing under `_configuration["SharePointEutrPath"]` once —
   research.md R12.
4. Reads, once, the full template + step-tree data for every distinct non-blank `EutrTemplate` value
   present in the fetched purchase orders — research.md R10.
5. For each fetched purchase order, computes a Note:
   - Blank/unmatched `EutrTemplate` → `"Missing template id"`.
   - Non-blank, matched `EutrTemplate`, but no SharePoint folder named exactly `{PurchId}` → `"No PO
     folder"`.
   - Non-blank, matched `EutrTemplate`, folder exists → for every step configured on that template
     (flattened per research.md R11), one line `"{n} - {step name} - Missing"` per step with no
     recorded document for that purchase order (research.md R13, no `RefType` filter), step name from
     Step Management (001-eutr-steps) and `n` sequential among that purchase order's own missing
     steps; blank Note if every step already has a document.
5a. Purchase orders with a blank Note are discarded — never inserted, never reported, never emailed
    (FR-014).
5b. Purchase orders with a non-blank Note are immediately inserted into `eutr_purchase_missing`
    (FR-021) — one row per flagged purchase order, as evaluation proceeds (not batched at the end).
6. After every purchase order has been evaluated, `eutr_purchase_missing` is read back in full
   (FR-022) and its rows are grouped by their `AlertForGroupId` column; rows with no group
   (`"Missing template id"`) are added to every group's set for this run.
7. One email is sent per distinct Alert group that has at least one resolvable recipient email,
   each with its own Excel attachment (columns: `Purch id`, `Vendor code`, `Vendor name`, `Template
   id`, `Note`) containing only that group's rows — built from the table read in step 6, not from
   data held only in memory during evaluation.
8. If zero purchase orders are flagged after evaluation, `eutr_purchase_missing` ends up empty, no
   email is sent, and no attachment is produced (FR-018).

## Response

```json
{
  "success": true,
  "message": "Fetched 3241, flagged 57, notified 3 group(s)",
  "data": {
    "totalFetched": 3241,
    "flaggedCount": 57,
    "groupsNotified": 3,
    "success": true,
    "message": "Fetched 3241, flagged 57, notified 3 group(s)"
  }
}
```

Wrapped in this codebase's standard `ApiResponse<EutrPurchaseMissingSummaryDto>` envelope, matching
every action in `ComplNotificationController`/this controller's existing `test-so-template-sync`
action.

- Zero purchase orders available from D365 → `totalFetched = 0`, `flaggedCount = 0`,
  `groupsNotified = 0`, `success = true` (empty source is not an error, consistent with User Story
  1's equivalent edge case).
- Every purchase order fully compliant (template assigned, folder present, every step covered) →
  `flaggedCount = 0`, `groupsNotified = 0`, no email sent, `success = true`.
- D365/SharePoint fetch fails partway through → the run stops, `success = false`, `message`
  describes the failure; no partial/misleading report is emailed (spec Edge Case, mirrors User
  Story 1's research.md R7 failure handling). Unlike User Story 1, this action does write to a table
  (`eutr_purchase_missing`) — a failure after step 0's delete but before any row is (re)inserted
  leaves the table empty until the next successful run; this is treated the same as
  `compl_so_missing`'s own precedent (no automatic rollback of the delete) rather than as a gap to
  close (research.md R17).
- A resolved Alert group has no recipient emails configured → that group is skipped (not counted in
  `groupsNotified`), the run continues with the remaining groups (spec Acceptance Scenario 10).
- Every flagged purchase order in a run happens to be `"Missing template id"` (no group at all to
  attach them to) → no email is sent, `groupsNotified = 0`, even though `flaggedCount > 0` (spec
  Assumptions — accepted known gap, not a fallback-recipient feature).

## Before this feature (current behavior)

`refType = 15` already returns data today (feature 004-eutr-documents registered it for the Assign-
condition "PO" autocomplete) — unlike User Story 1's `refType = 19` gap, there is no dead reference
type to fix here. The only backend gap this story fixes is enriching `case 15`'s existing mapping
with one more field (`OrderAccount`, research.md R9) so this report's "Vendor code" column has a
source; every other `refType = 15` consumer (the Assign-condition autocomplete) is unaffected since
it never reads `OrderAccount`. No endpoint today cross-references D365 purchase orders against
SharePoint folders, Template Management steps, and Document Management records in one pass — this
action is entirely new read/aggregate/notify logic. As of the 2026-08-14 update it also writes to one
new table, `eutr_purchase_missing` (created by this update, research.md R17) — no other existing
table is written to.

## Backward compatibility

Net-new action and net-new DTO on an existing controller. The `case 15` change to
`ComplDynamicsService` (research.md R9) is additive (one more populated field on an existing DTO) and
does not change any existing `refType = 15` consumer's behavior — no other `refType` or caller is
affected.
