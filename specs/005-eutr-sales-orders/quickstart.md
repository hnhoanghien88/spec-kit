# Quickstart: Validate EUTR Sales Orders Management

## Prerequisites

- `compliance-sys-api` runnable locally with valid D365 connection settings (same environment used
  by other EUTR reference screens, e.g. `eutr-documents`' List PO).
- `compliance-client` runnable locally (`npm run dev` or the project's existing dev script) pointed
  at that API.
- A user account whose role already has the `eutr-sales-orders` menu + permission seeded in the DB
  (per Constitution Principle V / memory note — this is an ops step, not part of this feature).
  If missing, ask an operator to seed the menu entry (`code: eutr-sales-orders`, `url:
  /eutr/sales-orders`) and grant the resource permission, then clear the cached menu
  (`localStorage.removeItem('userMenu')` + reload) before testing.

## Backend verification

1. After implementing Decision 1/2 (`research.md`), call the endpoint directly to confirm the gap is
   closed:
   ```
   POST {api-base}/api/dynamics/reference?page=1&pageSize=10&refType=11
   Body: []
   ```
2. **Expected**: `totalCount > 0` (assuming D365 has open sales orders) and each item has non-empty
   `code`/`name`, plus the new `custAccount` field populated; `deliveryDate` populated or `null`.
3. Confirm no regression on a pre-existing `refType`, e.g. `refType=15` (`EUTR_PURCH_ORDER`) still
   returns its usual shape with `custAccount`/`deliveryDate` simply absent/`null`.

## Frontend verification (manual — no automated UI test harness in this repo for this page)

1. Sign in as a user with access to **EUTR > Sales orders** (menu title as currently configured).
2. Navigate to `/eutr/sales-orders`.
3. **Expected**: grid loads within a few seconds, showing rows with real Sales ID / Customer /
   Customer name / Delivery date (or "-" when a sales order has no delivery date), and every row
   showing the same fixed Template and Progress placeholder values (spec FR-007/FR-008).
4. Type a known Sales ID (or partial Customer name) into the search box.
   **Expected**: grid narrows to matching rows only; clearing the search restores the full list.
5. Type a nonsense search string.
   **Expected**: grid shows an empty ("No data") state, not an error.
6. If the D365 reference call fails (e.g. temporarily point at an invalid API base URL),
   **Expected**: grid shows a clear loading-failed state — not a silently-empty table that could be
   mistaken for "no sales orders" (Edge Cases in spec.md).
7. Confirm `MapFilePage.jsx` (`/eutr/sales-orders/:salesId/map-file`) and `ViewSalesOrderPage.jsx`
   (`/eutr/sales-orders/:salesId/view`) still load without errors (they remain on the old mock data
   for now — out of scope for this feature, just confirming no accidental breakage from shared mock
   file edits).

## Success criteria mapping

- SC-001 (load within ~3s) → step 3.
- SC-002 (100% rows show real Sales ID/Customer/Customer name; Delivery date value-or-placeholder) →
  step 3.
- SC-003 (find a sales order via search within 10s) → step 4.
- SC-004 (Template/Progress consistent demo values, no crash) → step 3.
