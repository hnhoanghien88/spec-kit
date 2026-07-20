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
4. **(New, Update 1)** Seed at least one row in `eutr_purchase_attachments` for a known Sales ID
   returned by step 1 (`SalesId`, some `PurchId`, a `TemplateCode` that exists in `eutr_templates`),
   plus a second row for the *same* `SalesId` with a *different* `TemplateCode`, then call:
   ```
   POST {api-base}/api/eutr-purchase-attachments/by-sales-ids
   Body: ["<that SalesId>"]
   ```
   **Expected**: response contains exactly 2 items for that `SalesId`, one per distinct
   `TemplateCode`, each with a non-null `templateName` (per contracts/eutr-purchase-attachments.md).
5. **(New, Update 1)** Add a third row for the same `SalesId` reusing one of the two `TemplateCode`s
   already seeded (simulating two `PurchId`s sharing one template).
   **Expected**: re-calling step 4's request still returns exactly 2 items (no duplicate) — verifies
   the `DISTINCT` dedup in research.md Decision 6.
6. **(New, Update 1)** Add a fourth row for the same `SalesId` with a `TemplateCode` that does **not**
   exist in `eutr_templates` (orphaned FK).
   **Expected**: re-calling step 4's request still returns exactly 2 items — the orphaned row is
   silently skipped, not surfaced as an error (Edge Cases in spec.md).
7. **(New, Update 1)** Call step 4's request with a `SalesId` that has no rows in
   `eutr_purchase_attachments` at all.
   **Expected**: response contains an empty list for that `SalesId`, not an error.

## Frontend verification (manual — no automated UI test harness in this repo for this page)

1. Sign in as a user with access to **EUTR > Sales orders** (menu title as currently configured).
2. Navigate to `/eutr/sales-orders`.
3. **Expected**: grid loads within a few seconds, showing rows with real Sales ID / Customer /
   Customer name / Delivery date (or "-" when a sales order has no delivery date); Progress still
   shows the same fixed demo placeholder on every row (spec FR-008).
4. **(Updated, Update 1)** For the Sales ID seeded with 2 distinct templates (backend step 4),
   **Expected**: that row's Template cell shows both template names (e.g. two chips), not just one.
5. **(New, Update 1)** For a Sales ID with no `eutr_purchase_attachments` rows,
   **Expected**: that row's Template cell shows a clear empty state ("-"), not blank/undefined text
   and not the old fixed demo label.
6. Type a known Sales ID (or partial Customer name) into the search box.
   **Expected**: grid narrows to matching rows only; clearing the search restores the full list.
7. Type a nonsense search string.
   **Expected**: grid shows an empty ("No data") state, not an error.
8. If the D365 reference call fails (e.g. temporarily point at an invalid API base URL),
   **Expected**: grid shows a clear loading-failed state — not a silently-empty table that could be
   mistaken for "no sales orders" (Edge Cases in spec.md).
9. Confirm `MapFilePage.jsx` (`/eutr/sales-orders/:salesId/map-file`) and `ViewSalesOrderPage.jsx`
   (`/eutr/sales-orders/:salesId/view`) still load without errors (they remain on the old mock data
   for now — out of scope for this feature, just confirming no accidental breakage from shared mock
   file edits).

## Success criteria mapping

- SC-001 (load within ~3s) → step 3.
- SC-002 (100% rows show real Sales ID/Customer/Customer name; Delivery date value-or-placeholder) →
  step 3.
- SC-003 (find a sales order via search within 10s) → step 6.
- SC-004 (Template shows correct real data incl. multi-template and empty rows; Progress stays
  consistent demo) → steps 3-5.

---

## Update 2 (2026-07-16) — `MapFilePage.jsx` verification

### Backend verification

1. Pick a Sales ID confirmed to exist via `refType=11` (backend step 1/4 above). Confirm D365 has at
   least one PO with `InterCompanyOriginalSalesId` equal to that Sales ID (ask an operator/DBA if
   unsure which Sales IDs currently have linked POs in the `RSVNEutrSalesOrderPurchases` view).
2. Call the existing reference endpoint directly with the new filter this update relies on:
   ```
   POST {api-base}/api/dynamics/reference?page=1&pageSize=50&refType=16
   Body: [{ "column": "InterCompanyOriginalSalesId", "operator": "eq", "value": "<that SalesId>" }]
   ```
   **Expected**: only POs for that Sales Order come back, each item has `code`, `name`,
   `orderAccount`, `qty`, and `eutrTemplate` populated (no backend change was made — this MUST already
   work; if it returns everything unfiltered, stop and re-check research.md Decision 10 before
   proceeding).
3. **(New)** Call the new read action with a Sales ID that has never had a PO mapping saved:
   ```
   GET {api-base}/api/eutr-purchase-attachments/by-sales-id/<SalesId>
   ```
   **Expected**: `{ "data": [] }`.
4. **(New)** Call the new write action to save a mapping:
   ```
   POST {api-base}/api/eutr-purchase-attachments/save-po-mapping
   Body: { "salesId": "<SalesId>", "items": [{ "purchId": "<PurchId from step 2>", "templateCode": "<its eutrTemplate value>" }] }
   ```
   **Expected**: success response. Re-run step 3's `GET` — now returns exactly the one saved row.
5. **(New)** Call save-po-mapping again for the same Sales ID with a **different** single PO in
   `items` (simulating the user changing their Step 1 selection and re-saving).
   **Expected**: the follow-up `GET` (step 3) now returns only the new PO — the previous row is gone
   (verifies FR-021's replace-not-diff semantics, research.md Decision 11).
6. **(New)** Call save-po-mapping with an item whose `templateCode` is empty/null.
   **Expected**: `400 Bad Request` — the row is rejected, not silently saved with a blank
   `TemplateCode` (spec FR-022; `eutr_purchase_attachments.TemplateCode` is `NOT NULL`).
7. Confirm no regression on the Update 1 endpoint: re-run Update 1's backend step 4
   (`POST /api/eutr-purchase-attachments/by-sales-ids`, plural) for the same Sales ID — still returns
   the deduped `{salesId, templateCode, templateName}` shape, unaffected by the two new actions.

### Frontend verification (manual)

1. From `/eutr/sales-orders`, click "Map File" on the row used in backend steps 1-6 above (or
   navigate directly to `/eutr/sales-orders/<SalesId>/map-file`).
2. **Expected**: header card shows the same Sales ID/Customer/Customer name seen on the Overview grid
   for this row — not a mock value (spec FR-016/SC-005).
3. **Expected**: Step 1's PO table shows the real PO(s) from backend step 2, with columns PO / Name /
   Order account / Qty (no Vendor/Vendor Name/Rate/Material — those don't exist in real data, spec
   Assumptions/research.md Decision 10). The PO saved in backend step 4/5 shows its checkbox
   pre-checked; any other PO is unchecked (FR-018/FR-019/SC-006).
4. Change the checkbox selection and click **Save PO Mapping**.
   **Expected**: no error; reloading the page shows the new selection still checked (FR-020/FR-021/
   SC-007) — confirms the button now persists instead of only setting local `poSaved` state.
5. **Expected**: Step 2's template tree matches the `TemplateCode` of the currently-saved PO(s) (not a
   fixed mock template) — reflects the `EutrTemplate` value from the D365 PO row just saved
   (FR-023/FR-024).
6. If a PO with no eutr_references-linked documents is selected, **Expected**: AVAILABLE FILES shows
   an empty state, not mock files (FR-028).
7. For a PO known to have `eutr_references` rows (e.g. one already used in feature
   `004-eutr-documents`'s own testing), **Expected**: AVAILABLE FILES lists those real documents, and
   the tree shows them mapped under the correct step (matched by step name) — not the mock
   `MOCK_FILE_MAPPINGS` associations (FR-026/FR-027/SC-008).
8. Click **Upload** and **Save** (Step 2 footer).
   **Expected**: UI responds exactly as before (local-only, dialog/no-op) — no network call is made
   for either (check browser dev tools Network tab shows no new request), confirming FR-029/FR-030.
9. Confirm `ViewSalesOrderPage.jsx` (`/eutr/sales-orders/:salesId/view`) still loads without errors
   and is unaffected (it remains on mock data — out of scope for this update).

### Success criteria mapping (Update 2)

- SC-005 (header matches Overview data) → frontend step 2.
- SC-006 (PO list real + correctly pre-checked) → frontend step 3.
- SC-007 (Save PO Mapping persists across reloads) → frontend step 4.
- SC-008 (AVAILABLE FILES documents correctly step-mapped) → frontend step 7.

---

## Update 3 (2026-07-20) — Select-more-POs + Back button verification

No backend steps — this update is frontend-only (research.md Decision 16/17).

### Frontend verification (manual)

1. Open Map File for a Sales ID that already has **one** PO saved from a previous Save PO Mapping
   (e.g. reuse Update 2's frontend step 4 result), and confirm D365 has at least a **second** PO for
   the same Sales ID that has never been saved but does have a non-empty `eutrTemplate` value.
2. **Expected**: the previously-saved PO's checkbox is pre-checked; the second, never-saved PO's
   checkbox is **unchecked but not disabled** — it can be ticked (FR-031).
3. Tick the second PO (in addition to the already-checked one) and click **Save PO Mapping**.
   **Expected**: no error; reload the page — both POs now show pre-checked (FR-032/SC-009). Call
   `GET /api/eutr-purchase-attachments/by-sales-id/<SalesId>` (or re-check via the UI) to confirm both
   `PurchId`s are present with `TemplateCode` equal to each PO's own `eutrTemplate` value from Step 1.
4. If any PO in Step 1 has a genuinely empty `eutrTemplate` from D365, confirm its checkbox is still
   disabled with the existing tooltip — unchanged behavior (FR-022, not affected by this update).
5. Click the **Back** button (top of the Map File screen, not the breadcrumb link).
   **Expected**: navigates to `/eutr/sales-orders` (SC-010) — same destination as clicking the
   breadcrumb link.
6. Repeat step 5 after making an unsaved checkbox change in Step 1 (do not click Save PO Mapping
   first). **Expected**: Back still navigates immediately to `/eutr/sales-orders`, with no save
   prompt/confirmation dialog (per spec Update 3's Edge Cases — no auto-save, no confirmation gate).

### Success criteria mapping (Update 3)

- SC-009 (not-yet-saved POs with a real template stay selectable; Save reconciles the full set) →
  frontend steps 2-3.
- SC-010 (Back always returns to EUTR Sales Orders) → frontend steps 5-6.

---

## Update 4 (2026-07-20) — `ViewSalesOrderPage.jsx` real data, read-only verification

No new backend steps — every endpoint this update touches was already verified working in Update 2's
backend steps 1-7. This is a frontend-only rewrite (research.md Update 4 Decisions).

### Frontend verification (manual)

1. Pick the same Sales ID used in Update 2/3's frontend testing — one that has at least 2 saved POs
   (from Update 3's frontend step 3) where at least one Required step already has a matching document
   (Update 2's frontend step 7) and at least one Required step still has none.
2. From `/eutr/sales-orders`, click "View" on that row (or navigate directly to
   `/eutr/sales-orders/<SalesId>/view`).
3. **Expected**: header shows the same Sales ID/Customer/Customer name as Overview/Map File for this
   row — not a mock value (FR-034/FR-036/SC-011).
4. **Expected**: "Purchase Orders đã chọn" table lists exactly the PO(s) saved in
   `eutr_purchase_attachments` for this Sales ID (same set Map File's Step 1 shows pre-checked), with
   columns PO / Name / Order account / Qty — no Vendor/Vendor Name/Rate/Material (FR-037/SC-012).
5. **Expected**: Template Checklist shows the same tree(s)/`TemplateCode`(s) as Map File's Step 2 for
   this Sales ID (FR-039).
6. **Expected**: the Required step known to have a matching document (from step 1 above) shows as
   "đã map"; the Required step known to have none shows as "thiếu" — matching Map File's Step 2 status
   for the same Sales Order exactly (FR-041/SC-013).
7. Click on a tree node, then click on a listed file (if any interactive-looking element exists).
   **Expected**: nothing happens — no checkbox, no Map/Unmap button, no Save button anywhere on this
   screen; only expand/collapse of tree nodes responds (FR-042/SC-015).
8. Click **Edit / Map File**.
   **Expected**: navigates to `/eutr/sales-orders/<SalesId>/map-file` for the same Sales ID (FR-043/
   SC-014).
9. Go back to View, click **Download**.
   **Expected**: nothing is downloaded, no network call fires (check browser dev tools Network tab) —
   confirms FR-044.
10. Check the **Validation Summary** panel.
    **Expected**: shows "Đã chọn N PO" (N = the count from step 4), "Required steps đủ file"
    (completed/total matching step 6's tally), and a list of the specific missing step names — no
    "File không hết hạn" row (FR-045/FR-046).
11. Open View for a Sales ID that has **never** had a PO mapping saved (no rows in
    `eutr_purchase_attachments`).
    **Expected**: header still shows correctly (Sales Order exists at refType=11), "Purchase Orders đã
    chọn" shows an empty state ("Chưa chọn PO nào"), Template Checklist shows "chưa có cây template",
    and Validation Summary shows "đã chọn PO" as not-yet-met (FR-038/FR-040).
12. Open View for a Sales ID that does not exist at all (invalid `salesId` in the URL).
    **Expected**: shows the "Sales Order không tồn tại" error, no Purchase Orders/Template Checklist/
    Validation Summary rendered (FR-035).

### Success criteria mapping (Update 4)

- SC-011 (header matches real data) → frontend step 3.
- SC-012 (PO list matches saved records exactly) → frontend step 4.
- SC-013 (step status matches Map File's own tree) → frontend step 6.
- SC-014 (Edit/Map File navigates correctly) → frontend step 8.
- SC-015 (no write operation possible from this screen) → frontend step 7.
