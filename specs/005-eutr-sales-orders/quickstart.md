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

## Update 5 (2026-07-27) — Template tree toolbar reload + AVAILABLE FILES dynamic badges verification

### Backend verification

1. Confirm at least one row exists in `eutr_references` for a PO used below, with a non-null
   `RefType` (pointing at a real row in `eutr_reference_types`) and a `StepId` matching one of the
   current template's `eutr_template_details` rows — plus, for contrast, at least one other
   `eutr_references` row (same or another document) whose `StepId` does **not** match any node in
   the tree (e.g. `NULL` or a stale/removed step).
2. Call `POST /api/eutr-documents/list-po-references` with that PO's code in `poCodes`.
   **Expected**: each item in `documents[]` now includes `stepIds` (array), `refType`, and
   `typeName` alongside the existing `documentId`/`fileId`/`fileName`/`stepNames` — `typeName`
   matches the `eutr_reference_types.Name` for that `refType`, and `stepIds` includes the raw
   `StepId` value(s) from `eutr_references` for that document/PO.
3. **Expected**: a document whose `eutr_references` row has `RefType`/`StepId` both `NULL` returns
   `refType: null`, `typeName: null`, `stepIds: []` — no error, no crash.

### Frontend verification (manual)

1. Open Map File for a Sales Order with at least one saved PO and a template tree with both a
   mapped and an unmapped Required step (same fixture used in Update 2's frontend step 7).
2. In Step 2's template-tree toolbar, confirm the chip(s) shown match the templates in
   `templatesData` (unchanged from Update 2's rendering).
3. Click on one of the template chips in the toolbar.
   **Expected**: the tree area briefly reloads (loading indicator or equivalent) and re-renders with
   the same data — confirms `templatesData` was refetched, not just redrawn from stale state
   (FR-048/SC-017). Check the browser Network tab: a fresh call to `get-all`/`GetById` fires for each
   distinct `TemplateCode`.
4. In AVAILABLE FILES, find a file whose underlying `eutr_references` row's `StepId` matches a node
   in the currently-displayed tree (from backend step 1).
   **Expected**: its Map status badge reads **"Mapped"** (FR-049).
5. Find a file whose `StepId` does not match any current tree node.
   **Expected**: its Map status badge reads **"No map"** (FR-049).
6. **Expected**: every file's File type badge shows the real type name (e.g. "Invoice", "Packing
   list" — whatever `eutr_reference_types.Name` holds for its `RefType`), not the literal placeholder
   text "File type" (FR-050/SC-016).
7. **Expected**: every file's PO value badge shows the actual PO code it belongs to (e.g.
   `PO00014347`), not the literal placeholder text "PO value" (FR-051/SC-016).
8. For a file whose reference row has a `NULL` `RefType`/`RefValue` (backend step 3's fixture, if
   reachable in this UI), confirm the corresponding badge shows a clear empty state, not an error or
   the old static label (FR-052).

### Success criteria mapping (Update 5)

- SC-016 (Map status/File type/PO value reflect real data, no static placeholders remain) →
  frontend steps 4-7.
- SC-017 (clicking a template reloads `templatesData` from real data) → frontend step 3.

## Update 6 (2026-07-27) — Step 2 Upload/Edit real-write verification

No new backend steps — this update calls only already-existing, already-verified endpoints owned by
`004-eutr-documents` (its own SharePoint upload/update/reference-step actions, plus its own paging
endpoint filtered by `Id`, per research.md Decisions 26-28).

### Frontend verification (manual)

1. Open Map File for a Sales Order with at least one saved PO and an existing template tree (reuse a
   fixture from Update 2/5 testing).
2. Click **Upload** (UploadIcon) in Step 2.
   **Expected**: the popup that opens is titled "Add EUTR documents" (the same popup
   `004-eutr-documents`' own Add flow uses) — Type/Step/Value/Valid from/Valid to fields plus a real
   file picker, not the old bare filename-only local dialog.
3. Choose Type = "PO", enter/select a PO Value matching one of the currently-selected POs of this
   Sales Order, pick a Step, leave Valid from/to at their defaults, and select one valid file
   (correct format/size).
   **Expected**: after Upload completes, the popup closes on its own; without a page reload, the new
   file appears in AVAILABLE FILES, and the corresponding node in Step 2's tree shows the new
   document as "Mapped" — confirms a real write plus FR-030a's automatic refresh.
4. Repeat step 3 but include one invalid file (wrong extension) alongside a valid one in the same
   file-picker selection.
   **Expected**: the invalid file is rejected with an error message; the valid file still uploads and
   appears in AVAILABLE FILES (per `004-eutr-documents` FR-025, reused as-is).
5. Confirm (via the EUTR Documents screen itself, or a DB check) that a real `eutr_documents` row
   (and matching `eutr_references` row) now exists for the file uploaded in step 3 — not merely a
   client-side-only entry.
6. On an existing AVAILABLE FILES row, click **Edit**.
   **Expected**: the popup that opens is titled "Edit EUTR document" — Type is disabled/locked
   showing the document's real existing Type; Step/Value chips/Valid dates are pre-filled with the
   document's real current values (not blank, not the old local-only mock defaults).
7. Change the Step to a different valid step (still under the same Type's Assign Steps list) and
   click **Save**.
   **Expected**: popup closes; without a page reload, the file's position in the tree/Map status
   updates to reflect the new Step — confirms a real `eutr_references` update, not a local-only
   state change.
8. Reload the whole page and re-open Map File for the same Sales Order.
   **Expected**: the Upload from step 3 and the Edit from step 7 both persisted — same file/Step
   still shown, proving neither was client-state-only (the key regression check against the old
   FR-029/FR-030 no-op behavior).
9. Open the popup from step 2 or step 6, make a change, then close it via the Close/X control
   **without** clicking Upload/Save.
   **Expected**: no data changes — reopening confirms nothing was written (FR-030b's
   discard-on-close guarantee).

### Success criteria mapping (Update 6)

- SC-018 (Upload creates a real document that appears in AVAILABLE FILES/Map status) → frontend
  steps 2-3, 5, 8.
- SC-019 (Edit persists real changes, Type stays locked) → frontend steps 6-8.

## Update 7 (2026-07-27) — Map status/AVAILABLE FILES scoped by PO ↔ Template verification

No new backend steps — this update is frontend-only (research.md Decisions 29-30). Verification
requires a fixture with **two different templates that share a step name/`StepId`**, so a false-match
would be observable if the fix were not applied.

### Fixture setup

1. Pick (or seed) two distinct templates, Template X and Template Y (different `TemplateCode`s in
   `eutr_templates`), where at least one step in each tree shares the same step name (ideally also the
   same `StepId` if `eutr_steps` allows reuse across templates — e.g. both include an "Invoice" step).
2. Seed `eutr_purchase_attachments` for one Sales Order with two POs: PO-A → Template X, PO-B →
   Template Y (two rows, same `SalesId`, different `PurchId`/`TemplateCode`).
3. Seed `eutr_references`/`eutr_documents` so that PO-B has a real document attached to its shared
   "Invoice" step — but PO-A has **no** document for its own "Invoice" step.

### Frontend verification (manual)

1. Open Map File for that Sales Order; Save PO Mapping with both PO-A and PO-B selected if not already
   saved (Step 1).
2. In Step 2's toolbar, select **Template X**.
   **Expected**: AVAILABLE FILES shows only documents belonging to PO-A — PO-B's "Invoice" document
   does **not** appear in this list (FR-053, SC-020).
3. Still viewing Template X, look at the "Invoice" node in the tree.
   **Expected**: it shows as **missing/unmapped** (Required-missing icon, or "No map" if also shown as
   a file row) — it must NOT be marked "already has a file" using PO-B's document, even though both
   templates' "Invoice" steps share the same name/`StepId` (FR-055/FR-056, SC-022).
4. Click the toolbar to switch to **Template Y**.
   **Expected**: AVAILABLE FILES immediately updates to show PO-B's documents (including its "Invoice"
   document) and no longer shows PO-A's documents — the switch requires no page reload (FR-054,
   SC-021).
5. Still viewing Template Y, look at the "Invoice" node/file.
   **Expected**: it shows as **Mapped** — correctly attributed to PO-B's own document (FR-055).
6. Check the header card's aggregate progress (Required/completed, %).
   **Expected**: the count reflects **both** templates' Required steps combined (Template X's missing
   "Invoice" step counts as not-completed; Template Y's "Invoice" step counts as completed) — the
   number does NOT change when switching the toolbar between Template X and Template Y, and it does
   NOT show a false "completed" count inflated by the cross-template mismatch that existed before this
   fix (FR-057, SC-022).

### Success criteria mapping (Update 7)

- SC-020 (AVAILABLE FILES only shows the currently-viewed template's own PO documents) → frontend
  step 2.
- SC-021 (switching template in the toolbar updates AVAILABLE FILES immediately) → frontend step 4.
- SC-022 (no cross-template Mapped false-positive; aggregate progress computed correctly per template
  then summed) → frontend steps 3, 5-6.

## Update 8 (2026-07-27) — View Sales Order: Template Tree Toolbar + PO/Template-scoped status verification

No new backend steps — this update is frontend-only (research.md Decisions 31-34), and reuses the
exact same fixture shape already used to verify Update 7 for Map File (two templates sharing a step
name/`StepId`), this time exercised against `ViewSalesOrderPage.jsx`.

### Fixture setup

Reuse Update 7's fixture as-is (same Sales Order, same Template X/Template Y, same shared "Invoice"
step, same PO-A→X/PO-B→Y attachments, same PO-B-only "Invoice" document) — if Update 7's fixture is
still in place, no new seeding is needed; this update verifies the same underlying data through
`ViewSalesOrderPage.jsx` instead of `MapFilePage.jsx`.

### Frontend verification (manual)

1. From `/eutr/sales-orders`, click **View** on the same Sales Order used for Update 7's fixture (or
   navigate directly to `/eutr/sales-orders/<SalesId>/view`).
2. **Expected**: the toolbar (`data-marker="template-tree-toolbar"`) shows one chip per real saved
   template (Template X, Template Y) — not the old hardcoded "template code1"/"template code2"/"All"
   labels (FR-058, SC-023).
3. **Expected**: the Template Checklist below defaults to showing **only Template X's** tree (the
   first template in the list) — Template Y's tree is not shown at the same time (FR-059/FR-060,
   SC-023).
4. Still viewing Template X, look at the shared "Invoice" node.
   **Expected**: it shows as **missing/thiếu** — it must NOT be marked "đã có tài liệu" using PO-B's
   document, even though both templates' "Invoice" steps share the same name/`StepId` (FR-061,
   SC-025).
5. Click the toolbar chip for **Template Y**.
   **Expected**: the Template Checklist immediately switches to show only Template Y's tree — Template
   X's tree is no longer shown (FR-059, SC-024). No page reload, no network call fires for
   PO/document/template data (check browser dev tools Network tab) — confirms FR-063 (no refetch on
   click, unlike Map File's toolbar).
6. Still viewing Template Y, look at the "Invoice" node.
   **Expected**: it shows as **đã có tài liệu** — correctly attributed to PO-B's own document
   (FR-061).
7. Check the **Validation Summary** panel's "Required steps đủ file" count and missing-steps list.
   **Expected**: the count reflects **both** templates' Required steps combined (Template X's missing
   "Invoice" step counts as not-completed; Template Y's "Invoice" step counts as completed) — the
   number does NOT change when switching the toolbar between Template X and Template Y, and does NOT
   show a false "completed" count inflated by cross-template mismatch (FR-062, SC-025/SC-026).
8. Open View for a Sales Order that has only 1 saved template.
   **Expected**: the toolbar shows exactly 1 chip (always shown as selected); the Template Checklist
   always shows that template's tree — clicking the single chip has no observable effect (Edge Cases).
9. Open View for a Sales Order that has never had a PO mapping saved (no rows in
   `eutr_purchase_attachments`).
   **Expected**: the toolbar shows no chips at all; Template Checklist still shows "chưa có cây
   template" (unchanged from Update 4, FR-040) — no default template to select.

### Success criteria mapping (Update 8)

- SC-023 (toolbar shows real chips; defaults to the first template) → frontend steps 2-3.
- SC-024 (clicking a template chip switches the displayed tree immediately) → frontend step 5.
- SC-025 (no cross-template "đã có tài liệu" false-positive) → frontend steps 4, 6.
- SC-026 (aggregate Required/completed stays Sales-Order-wide and matches Map File's own numbers for
  the same Sales Order) → frontend step 7.

## Update 9 (2026-07-27) — View button on AVAILABLE FILES (Map File) verification

No new backend steps — this update reuses an already-working endpoint/component end to end
(research.md Decision 35). Verification just needs one document each of a supported and (if
available) an unsupported preview type.

### Frontend verification (manual)

1. Open Map File for a Sales Order that has at least one real document in AVAILABLE FILES (e.g. the
   Sales Order used for Update 6/7's testing).
2. **Expected**: each document row shows a **View** button/icon next to the existing Edit button
   (FR-064, SC-027).
3. Click **View** on a document with a supported file type (PDF, Word, Excel, or an image).
   **Expected**: a popup opens showing that document's own file content rendered inline — not a blank
   popup, not the Edit popup's Type/Step/Value/Valid-dates form (FR-065/FR-066, SC-028).
4. While the popup is open, confirm there is no Save button and no editable field anywhere in it —
   only the file content, a Download control, and a Close control (FR-066).
5. Close the popup (Close button or click outside).
   **Expected**: popup closes; re-open Map File (or refetch AVAILABLE FILES) and confirm the
   document's data (Type/Step/Value/Valid dates, Map status) is unchanged — nothing was written by
   opening/closing View (FR-067, SC-029).
6. Click **View** on a *different* document in the same list.
   **Expected**: the popup shows that second document's own content — not a stale/incorrect leftover
   of the first document's content (Edge Cases).
7. If a document with an unsupported file type is available, click **View** on it.
   **Expected**: the popup shows a clear "cannot preview" state instead of a blank area or a crash
   (FR-068).
8. Click **Edit** on a document, close the Edit popup, then click **View** on the same document (and
   vice versa: View then Edit).
   **Expected**: both popups work correctly regardless of order — View and Edit are independent of
   each other (FR-067).

### Success criteria mapping (Update 9)

- SC-027 (View button present next to Edit on every document) → frontend step 2.
- SC-028 (View opens the correct document's content, no cross-document mixup) → frontend steps 3, 6.
- SC-029 (View never writes/changes document data) → frontend step 5.

## Update 10 (2026-07-27) — Real Download on View Sales Order verification

This update introduces one new endpoint (`POST /api/eutr-documents/download-zip`, research.md
Decisions 36-40) — verify it directly first, then verify the full button flow through the UI.

### Fixture setup

Reuse Update 7/8's two-template fixture (Template X/Template Y, PO-A→X/PO-B→Y, PO-B has a document on
its shared "Invoice" step, PO-A does not) if still in place; it already gives one template with a
Mapped document and one without, which is exactly what's needed to verify FR-073.

### Backend verification

1. Call the new endpoint directly with one non-empty folder and one empty folder:
   ```
   POST {api-base}/api/eutr-documents/download-zip
   Body: {
     "salesId": "<SalesId>", "customerCode": "<code>", "customerName": "<name>",
     "folders": [
       { "folderName": "Template Y", "files": [{ "fileId": "<a real fileId>", "fileName": "test.pdf" }] },
       { "folderName": "Template X", "files": [] }
     ]
   }
   ```
   **Expected**: `200 OK`, `Content-Type: application/zip`, `Content-Disposition` header names the
   file `<SalesId>-<customerCode>-<customerName>.zip` (sanitized). Unzip the response: confirm a
   `Template Y/test.pdf` entry with real, non-empty content, and a `Template X/` empty directory entry
   (FR-071/FR-073).
2. Call again with two files in the same folder sharing the same `fileName`.
   **Expected**: both files appear in the zip under that folder, with the second one's name
   disambiguated (e.g. `test_1.pdf`) — neither file is dropped or overwritten (FR-075).
3. Call again with `customerName` containing a character invalid in file names (e.g. `Acme/Co`).
   **Expected**: still `200 OK`; the `Content-Disposition` filename has the invalid character replaced,
   not rejected or truncated to an error (FR-070).
4. Call again with `folders: []`.
   **Expected**: `400 Bad Request` with a clear message — no zip body returned (FR-074).
5. Call again with one folder whose `files` list is empty and no other folders.
   **Expected**: also `400 Bad Request` — "every folder empty" counts as nothing to download (FR-074).

### Frontend verification (manual)

1. Open View for the Sales Order used in Update 7/8's fixture (Template X has no Mapped document,
   Template Y has one).
2. Click **Download**.
   **Expected**: a `.zip` file downloads (browser's normal download UI), named
   `<SalesId>-<CustomerCode>-<CustomerName>.zip` matching the header's own Sales ID/Customer/Customer
   name (SC-030).
3. Open the downloaded zip.
   **Expected**: one subfolder per saved template, named with each template's real display name (not a
   code or "Template 01"/"02") — a "Template X" folder (empty) and a "Template Y" folder containing
   exactly PO-B's Mapped "Invoice" document (SC-030/SC-031).
4. Confirm no document belonging to PO-A (Template X's own PO) appears inside the "Template Y" folder,
   and vice versa — even though both templates share an "Invoice" step (SC-031, same cross-template
   guarantee already verified for Map status in Update 7/8).
5. Open View for a Sales Order that has never had a PO mapping saved (no `templatesData`) and click
   **Download**.
   **Expected**: the button is still clickable (not disabled); a clear "không có tài liệu nào để tải"
   message appears; no file is downloaded (SC-032).
6. Open View for a Sales Order that has saved templates but zero Mapped documents in any of them and
   click **Download**.
   **Expected**: same as step 5 — clear message, no download (SC-032).
7. Before and after clicking Download (step 2), check `eutr_documents`/`eutr_references`/
   `eutr_purchase_attachments` for the Sales Order used — confirm no row changed (SC-033).
8. Repeat step 2 for a Sales Order whose Customer name contains a space or special character.
   **Expected**: the download still succeeds with a valid, sanitized file name — no browser error, no
   truncated/garbled name (SC-034).

### Success criteria mapping (Update 10)

- SC-030 (Download produces a correctly-named zip with one subfolder per saved template) → frontend
  steps 2-3.
- SC-031 (every file in a subfolder is Mapped for that template; no cross-template leakage) → frontend
  steps 3-4.
- SC-032 (nothing-to-download shows a clear message, no empty zip) → frontend steps 5-6.
- SC-033 (Download never writes any document/reference/attachment data) → frontend step 7.
- SC-034 (special characters in Customer name don't break the download) → frontend step 8.

## Update 11 (2026-07-27) — Progress-figure consistency verification (Required-only, `AUTO_SOURCES`-excluded, Map File ↔ View)

This update is a single filter-predicate fix inside `MapFilePage.jsx`'s `computeProgress()` (research.md
Decision 41) — no backend change, no new endpoint. Verify that Map File's progress figures stay
Required-only and now stay internally consistent and consistent with View's own figures.

### Fixture setup

Reuse (or construct) a Sales Order with one saved template containing at least:
- 1 Required step with `takeFrom` = "PO" or "Upload manual", not yet mapped to any file.
- 1 Required step whose backing `eutr_template_details` row has `takeFrom` set to one of
  `AUTO_SOURCES` (`"D365-Invoice"`, `"D365-PackingList"`, or `"D365"`) — this requires a test row crafted
  directly in `eutr_template_details`, since real screens never produce this value today (research.md
  Decision 41) — also not yet mapped to any file.
- 1 Optional step (any `takeFrom`), not yet mapped to any file.

### Frontend verification (manual)

1. Open Map File for this Sales Order.
   **Expected**: `progress.total` (the caption above the progress bar, `data-marker="progress-bar"`)
   counts only the Required steps (2 in the fixture above) — the Optional step is excluded (FR-077,
   confirms the count did NOT broaden to Optional).
2. Note the values shown for `progress.total`, `progress.completed` (both in the "Mapped: x/y" chip and
   the footer's "Required: x/y" line) and the footer's "Still missing X file" count.
   **Expected**: `progress.total - progress.completed` equals exactly the "Still missing X file" count —
   both the ordinary unmapped Required step and the `AUTO_SOURCES` unmapped Required step are excluded
   from `progress.total`/`progress.completed` alike, so the two numbers stay in sync (FR-078/FR-079; before
   this fix, the `AUTO_SOURCES` step would have inflated `progress.total`/deflated `progress.completed`'s
   gap relative to "Still missing X file").
3. Open View for the same Sales Order.
   **Expected**: the header's Required/completed figures and Validation Summary's missing-steps count
   match exactly what Map File showed in steps 1-2 for the same Sales Order (FR-081, SC-026) —
   confirming `ViewSalesOrderPage.jsx`'s own `requiredDetails`/`mappedRequired`/`missingRequired` needed
   no change and already agree with Map File's corrected figures.
4. Map a file to the `AUTO_SOURCES` Required step and refresh Map File.
   **Expected**: `progress.completed` increments by 1 and "Still missing X file" decrements by 1 in
   lockstep — `progress.total - progress.completed` still equals the missing count.

### Success criteria mapping (Update 11)

- SC-035 (`progress.total - progress.completed` matches `missingRequired` on Map File, and matches
  View's equivalent figures, for a Sales Order with an `AUTO_SOURCES` Required step) → frontend steps
  1-4.
- SC-026 (Map File and View progress figures match 1-1 for the same Sales Order) → frontend step 3.

## Update 12 (2026-07-27) — Real, batched Progress column on Overview

This update introduces two new endpoints (`POST /api/eutr-purchase-attachments/by-sales-ids-raw`,
`POST /api/eutr-templates/by-codes` — research.md Decisions 43-44) — verify each directly first, then
verify the Overview grid's Progress column end to end.

### Fixture setup

Reuse the Update 7/8 two-template fixture (Template X/Template Y, PO-A→X/PO-B→Y, PO-B has a document on
its shared "Invoice" step, PO-A does not) for one Sales Order (`SO-A`) — this gives a row with partial
progress. In addition, prepare:
- One Sales Order (`SO-B`) with **no** `eutr_purchase_attachments` rows at all (never Save PO Mapping'd).
- One Sales Order (`SO-C`) with a saved template whose every step is Optional or has `takeFrom` in
  `AUTO_SOURCES` (0 countable Required steps).

### Backend verification

1. Call the new raw batch endpoint with `["SO-A", "SO-B", "SO-C"]`.
   **Expected**: `200 OK`; rows returned for `SO-A`/`SO-C` (their own `purchId`/`templateCode` pairs),
   and **no** row at all for `SO-B` (FR-083's empty condition).
2. Call the new template-by-codes endpoint with the distinct `templateCode`s from step 1's response.
   **Expected**: `200 OK`; one entry per code, each with `details` fully populated (matching what
   `GetById` would return for that same code individually) — confirm this in one call instead of one
   `get-all`+`GetById` pair per code.
3. Call `list-po-references` with the union of every `purchId` from step 1.
   **Expected**: unchanged response shape (already generic per Decision 45) — documents grouped purely
   by `PoCode`, including PO-B's Mapped "Invoice" document.

### Frontend verification (manual)

1. Open **EUTR Sales Orders** (Overview) with a page that includes `SO-A`, `SO-B`, and `SO-C`.
   **Expected**: `DEMO_PROGRESS`'s fixed `3/5 steps, 60%` no longer appears on any row (FR-082).
2. Check `SO-A`'s Progress cell.
   **Expected**: shows the same `completed`/`total`/`pct` as Map File/View show for `SO-A` when opened
   separately (FR-086/SC-036) — PO-A's own Required steps count as unmapped (its document belongs to a
   different PO/template, per the same PO↔Template scoping already verified in Update 7/8), PO-B's
   mapped "Invoice" step counts as completed.
3. Check `SO-B`'s Progress cell.
   **Expected**: a clear blank/empty placeholder (not `0/0`, not `0%`, not the old demo value) — FR-083/
   SC-037.
4. Check `SO-C`'s Progress cell.
   **Expected**: a distinct "no Required steps" indicator (e.g. "Không có step bắt buộc") — visibly
   different from `SO-B`'s empty state, and not `0%`/"chưa hoàn thành" — FR-084.
5. Open the browser's network tab, reload the page.
   **Expected**: exactly one call each to `by-sales-ids-raw`, `by-codes`, and `list-po-references` for
   this page load — no per-row repetition of any of the three (FR-085/SC-038).
6. Temporarily block/fail one of the three calls (e.g. via devtools request blocking) and reload.
   **Expected**: every visible row's Progress cell shows a clear error state; Sales ID/Customer/
   Customer name/Template columns and the Download button remain fully functional on every row
   (FR-085/SC-039) — the failure does not crash or blank the rest of the table.
7. Change page/search so a different set of Sales IDs is visible, then navigate back to the original
   page.
   **Expected**: Progress recomputes correctly for whichever rows are now visible — no stale values
   from a previous page carried over.

### Success criteria mapping (Update 12)

- SC-036 (Overview Progress matches Map File's own computation for the same Sales Order) → frontend
  step 2.
- SC-037 (no purchase attachments → clear blank state, never `0/0`/`0%`/demo) → frontend step 3.
- SC-038 (no N+1 — Progress data loads in a fixed, small number of batch calls per page) → frontend
  step 5.
- SC-039 (a failed Progress data load shows a per-row error, doesn't block the rest of the table) →
  frontend step 6.

## Update 13 (2026-07-27) — Real, per-row, on-demand Download on Overview

This update introduces **no new endpoint** — it reuses `download-zip` (Update 10) and the new
`by-codes` endpoint (Update 12) on demand, per row. Verify the Overview grid's Download button end to
end; no new backend verification is needed beyond what Update 10/12 already covered directly.

### Fixture setup

Reuse Update 12's fixture (`SO-A` with partial Mapped/unmapped progress across Template X/Template Y,
`SO-B` with no saved templates at all).

### Frontend verification (manual)

1. Open Overview, locate `SO-A`'s row, click its **Download** button.
   **Expected**: a `.zip` downloads named `SO-A-<CustomerCode>-<CustomerName>.zip`; unzipping shows one
   subfolder per saved template (a "Template X" folder, empty, and a "Template Y" folder containing
   exactly PO-B's Mapped "Invoice" document) — byte-for-byte the same structure `ViewSalesOrderPage.jsx`
   already produces for the same Sales Order (FR-087/SC-040).
2. While `SO-A`'s Download is still in flight (simulate with a throttled network), click `SO-B`'s
   Download button and use the search box.
   **Expected**: `SO-B`'s Download proceeds independently (its own spinner, own result) and the search
   box remains responsive — `SO-A`'s in-flight state does not block or freeze anything else on the page
   (FR-090/SC-042).
3. Click Download on `SO-B` (no saved templates at all).
   **Expected**: the button is clickable (not pre-disabled); a clear "không có tài liệu nào để tải"
   message appears scoped to that row; no zip downloads (FR-089/SC-041).
4. Click Download on a Sales Order that has saved templates but zero Mapped documents in any of them.
   **Expected**: same as step 3 — clear message, no download (FR-089/SC-041).
5. Temporarily fail one of the on-demand fetch calls (e.g. block `by-codes` in devtools) for one row and
   click that row's Download.
   **Expected**: a clear error message scoped to that row only; other rows/search/pagination remain
   unaffected (FR-091).
6. Before and after step 1's download, check `eutr_documents`/`eutr_references`/
   `eutr_purchase_attachments` for `SO-A` — confirm no row changed (FR-092/SC-043).
7. Compare the zip downloaded in step 1 against the zip `ViewSalesOrderPage.jsx`'s own Download button
   produces for `SO-A` (opened via the View screen).
   **Expected**: identical folder names, identical files per folder (SC-040).

### Success criteria mapping (Update 13)

- SC-040 (Overview Download matches View's Download output for the same Sales Order) → frontend steps
  1, 7.
- SC-041 (no-Mapped-documents shows a clear message, no empty zip) → frontend steps 3-4.
- SC-042 (one row's in-flight Download doesn't block search/pagination/other rows) → frontend step 2.

## Update 14 (2026-07-28) — Preserve Overview's search/page when Back-navigating from Map File or View

This update introduces **no new endpoint** — it is a pure frontend routing/state fix (Overview's own
URL query params + a `location.state` flag). No new backend verification is needed; verify end to end
in the browser.

### Fixture setup

Any Sales Order visible on Overview's first page works; for the page-restoration step, at least 2
pages of results are needed (set page size to 10 via the pagination control, or use a dataset with
more than `DEFAULT_PAGE_SIZE` rows).

### Frontend verification (manual)

1. Open Overview, type a Sales ID that matches exactly one row (e.g. `SO004957`) into the search box,
   wait for the debounced fetch to settle.
   **Expected**: the table shows only the matching row(s); the URL now includes `?search=SO004957`
   (or similar) — check the address bar.
2. Click that row's **Map File** button, then click **Back** on the Map File screen.
   **Expected**: back on Overview, the search box still shows `SO004957` and the table still shows
   only the matching row(s) — not the full unfiltered list (FR-094/SC-044).
3. Repeat step 2, but click **View summary** instead of Map File, then click **Back** on the View
   screen.
   **Expected**: same result as step 2 (FR-093/FR-094).
4. Clear the search box, change the page size so there are multiple pages, navigate to page 2, then
   click Map File or View on a row on page 2, then click Back.
   **Expected**: Overview shows page 2 again, not page 1 (FR-095/SC-045).
5. Repeat step 2, but instead of clicking the in-app **Back** button, use the browser/device's own
   Back button (or Alt+Left / swipe-back).
   **Expected**: identical result to step 2 — search and page restored the same way (FR-097/SC-048).
6. From Overview's default (unfiltered) view, open Map File for any row, then in a new tab (or after
   closing and reopening the tab) paste the Map File URL directly and click its Back button.
   **Expected**: Overview shows the default, unfiltered, page-one list — not an error, not a blank
   search box that "should have" restored something (FR-098).
7. From any other screen (not Map File/View for this feature), navigate to Overview via the left-nav
   menu item "EUTR Sales Orders" while Overview previously had a search term active in the same tab.
   **Expected**: Overview shows the default, unfiltered, page-one list — the previous search term is
   not carried over into this fresh visit (FR-098/SC-047).
8. While on Map File for a Sales Order matching a restored search term, use Save PO Mapping to change
   that Sales Order's saved templates, then click Back.
   **Expected**: Overview shows the restored search/page and this row's Template/Progress cells reflect
   the just-saved change — not stale data from before the visit (FR-096/SC-046).
9. Search for a term, then (in another tab or via direct DB edit) make that term match zero rows before
   clicking Back from Map File/View.
   **Expected**: Overview shows the "No data" empty state with the search box still showing the
   restored term — not an error (FR-099).

### Success criteria mapping (Update 14)

- SC-044 (search restored after Back from Map File/View) → frontend steps 2, 3.
- SC-045 (page restored after Back) → frontend step 4.
- SC-046 (restored view shows live, not stale, Template/Progress data) → frontend step 8.
- SC-047 (menu/breadcrumb entry shows the default list, not a stale search) → frontend step 7.
- SC-048 (in-app Back and the browser's own Back behave identically) → frontend step 5.
- SC-043 (Download never writes any document/reference/attachment data) → frontend step 6.

## Update 15 (2026-07-28) — AVAILABLE FILES panel on View, filtered by the selected step

This update introduces **no new endpoint** — it renders already-fetched, already-computed data
(`selectedTemplateComputation.filesForTemplate`/`derivedFileMappings`) as a new panel and reuses
`EutrFileViewerDialog` (already shipped for Map File, Update 9). No new backend verification is needed;
verify end to end in the browser.

### Fixture setup

Open View (`/eutr/sales-orders/:salesId/view`) for a Sales Order with:
- At least 2 saved templates (so the toolbar has more than one chip to switch between).
- At least one template whose tree has a **parent** step with 2+ children, where at least one child has
  a Mapped document and at least one child (or the parent itself) has none — this exercises the
  subtree-aggregation behavior (FR-102) as well as the "no files for this step" empty state (FR-106).
- At least one document whose `RefType` differs from another document's, so the File type chip has
  more than one distinct value to visually confirm against `MapFilePage.jsx`'s own AVAILABLE FILES for
  the same Sales Order.

### Frontend verification (manual)

1. Open View for the fixture Sales Order. **Expected**: below the existing "Steps missing files" list
   in the right-hand box, a new **"AVAILABLE FILES (N)"** section appears, listing every document that
   belongs to the currently-active template (same set `MapFilePage.jsx`'s own AVAILABLE FILES shows for
   that template) — each row showing file name plus Map status/File type/PO value/Step name chips and a
   View button, with no Edit button and no Upload button anywhere in this section (FR-100/FR-101).
2. Click a **leaf** step in the Template Checklist tree that has a Mapped document.
   **Expected**: AVAILABLE FILES narrows to show only that step's own document(s) — the count in the
   section header drops accordingly (FR-102).
3. Click a **parent** step in the tree whose children include at least one Mapped document.
   **Expected**: AVAILABLE FILES shows the union of all of that parent's descendant steps' Mapped
   documents — not empty, and not limited to only a document mapped directly to the parent node itself
   (FR-102).
4. Click a leaf step that has no Mapped document at all.
   **Expected**: AVAILABLE FILES shows a clear empty state (e.g. "No files for this step") — not a blank
   panel with no explanation, and not a leftover list from the previously-selected step (FR-106).
5. After step 2 or 3 (a step filter is active), click the currently-active template's own chip in
   `template-tree-toolbar` (the same chip already selected, not a different one).
   **Expected**: AVAILABLE FILES clears the step filter and returns to showing the full file set of that
   template, same as step 1 (FR-104).
6. After a step filter is active, click a **different** template's chip in the toolbar.
   **Expected**: the step filter clears (same as step 5) and AVAILABLE FILES shows the full file set of
   the newly-selected template, not the previous template's filtered or unfiltered set (FR-104).
7. Click the View button on any row in the new AVAILABLE FILES section.
   **Expected**: the same read-only file-content preview popup already shipped for Map File's own View
   button (Update 9) opens, showing the file's content — no Save button, no editable field anywhere in
   the popup (FR-105).
8. Confirm no network request fires for the AVAILABLE FILES panel itself when performing steps 2-6 (only
   step 7's View click should trigger one new request, the file-content fetch) — check the browser's
   Network tab.
   **Expected**: zero new requests from step-click/template-click; exactly one new request (file
   content by id) when View is clicked in step 7.

### Success criteria mapping (Update 15)

- SC-049 (default view shows the full file set of the active template) → frontend step 1.
- SC-050 (step click narrows to that step's — and its descendants' — Mapped files only) → frontend
  steps 2, 3, 4.
- SC-051 (template-chip click clears the step filter, including re-clicking the active template) →
  frontend steps 5, 6.
- SC-052 (View button opens the read-only preview popup; no document data is modified) → frontend
  step 7.
- SC-053 (no Edit/Upload control appears in the new panel) → frontend step 1.
