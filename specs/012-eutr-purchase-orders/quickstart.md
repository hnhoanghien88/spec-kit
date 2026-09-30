# Quickstart: EUTR Purchase Orders

Manual end-to-end validation guide (this codebase has no automated test suite for sibling EUTR
features either — `003`/`004`/`005` were all validated this way).

## Prerequisites

1. Backend (`compliance-sys-api`) and frontend (`compliance-client`) running against an environment
   with real D365 reference data reachable (`refType=15`/`14` return real rows — confirmed already
   populated per `011-eutr-synchronize-data`'s own "3,000+ rows" observation).
2. At least one Purchase Order in the ERP data with:
   - a non-blank `EutrTemplate` value that matches a real, existing Template in `003-eutr-templates`
     with at least one Required step, and at least one document already recorded against it in
     `004-eutr-documents` for some (but not all) of its Required steps — to exercise the partial-
     progress and "missing step" states.
   - a non-blank `OrderAccount` that resolves to a real Vendor in `refType=14`.
3. At least one Purchase Order with a **blank** `EutrTemplate` (to exercise the "no Template" state).
4. **Operational step, not code**: the `userMenu`/`canAccessMenu` DB rows for
   `code = 'eutr-purchase-orders'` must be seeded and granted to your test user's role (see
   `research.md` Decision 8) — otherwise the new menu entry/route will not resolve even though the
   code is deployed. If not yet seeded, navigate directly to `/eutr/purchase-orders` as a logged-in
   user with the eventual permission (or temporarily grant it) to validate the screen itself.

## Validate the Overview list screen (US1, US3)

1. Open **EUTR > EUTR Purchase Orders** (or navigate to `/eutr/purchase-orders`).
2. Confirm the table renders 6 columns: Purch id, Vendor code, Vendor name, Template, Progress,
   Action.
3. Locate the Purchase Order from Prerequisite #2. Confirm:
   - Vendor code/Vendor name show real values (cross-check against `refType=14` for that
     `OrderAccount`).
   - Template shows the real Template name/code.
   - Progress shows `completed/total (%)` matching the Required-step count you set up (cross-check
     against the same Purchase Order's document records in `004-eutr-documents`).
4. Locate the Purchase Order from Prerequisite #3 (blank Template). Confirm Template and Progress
   both show a clear empty/"no Template" state — not `0%`, not blank cells that look like a loading
   error.
5. In the search box, type the Prerequisite #2 Purchase Order's exact Purch id. Confirm the list
   narrows to just that row.
6. Clear the search box and type a substring of that same Purchase Order's Vendor code. Confirm it
   still matches (this exercises the Decision 6 backend filter change — if it does not match while a
   Purch-id search does, the filter-builder change has not been applied/deployed).
7. Type a keyword that matches no Purchase Order. Confirm a clear "No data" state, not an error.
8. If more Purchase Orders exist than one page, confirm pagination controls work.

## Validate the detail screen (US2)

1. From the Overview list, click **View** on the Prerequisite #2 Purchase Order's row.
2. Confirm the URL is `/eutr/purchase-orders/{purchId}/view` and the page header shows that
   Purchase Order's Purch id, Vendor code, and Vendor name — **not** a Sales ID/Customer header.
3. Confirm there is **no** "Step 1 — Choose Purchase Order" section and **no** "Selected POs" table
   anywhere on the page.
4. Confirm the step tree matches the Template's real step structure, and that the step(s) you left
   without a document show a clear "missing" indicator while the step(s) you attached a document to
   do not.
5. Confirm AVAILABLE FILES lists the real document(s) recorded for this Purchase Order, each showing
   its mapped step.
6. Click **Upload**. Confirm the popup opens with:
   - the popup is the same Add-document dialog used in `004-eutr-documents`.
   - Type already set to **PO** and Value already showing this same Purchase Order's Purch id as the
     pre-selected chip (spec Update 1, FR-024) — not empty as in `004-eutr-documents`'s standalone
     screen or `005-eutr-sales-orders`'s Map File.
   - Type and Value can still be changed to something else before saving (FR-025 — not locked); open
     the popup again afterward to confirm it still defaults to PO/this Purchase Order (the change
     was not "remembered", it always re-derives from the PO on screen).
   Add a new document for one of the missing steps using a valid file (leaving the defaults as-is, or
   after changing them per the check above). Confirm after saving, AVAILABLE FILES and that step's
   tree indicator update immediately, without a page reload.
6a. Open `/eutr/sales-orders/{SalesId}/map-file` (005) and click its own Upload button. Confirm Type
    and Value still open empty there — the Update 1 default applies only to `PurchId/View` (FR-026).
6b. With the same Upload popup open on `PurchId/View`, change Type from PO to **Invoice**. Confirm
    Value re-fills to this same Purchase Order's Purch id (spec Update 2, FR-027). Change Type to
    **Delivery note**; confirm Value re-fills to the same Purch id again.
6c. Change Type to **Vendor**. Confirm Value re-fills to this Purchase Order's Vendor code (not the
    Purch id) — FR-027(b). Manually remove that chip and type/select a different value, then change
    Type back to **PO**; confirm Value is overwritten again with the Purch id (not the value you just
    typed) — FR-028's "always overwrite on Type change" rule.
6d. Change Type to any value outside PO/Vendor/Invoice/Delivery note (e.g. **General agreement**, if
    configured). Confirm Value is simply cleared/left for manual entry — not auto-filled — FR-028.
6e. Repeat 6a on `005-eutr-sales-orders`'s Map File Upload popup: change its Type field between PO,
    Vendor, Invoice, Delivery note. Confirm Value is cleared on every Type change there (existing
    behavior), never auto-filled — confirms FR-029's scope limit to `PurchId/View` only.
7. Click **Edit** on an existing document, change a field, save. Confirm the update persists and is
   reflected immediately.
8. Navigate to `/eutr/purchase-orders/DOES-NOT-EXIST/view` (an invalid Purch id). Confirm a clear
   "Purchase Order không tồn tại" error state, with no step tree/AVAILABLE FILES rendered.
9. Navigate to the detail screen for the Prerequisite #3 Purchase Order (blank Template). Confirm a
   clear "no Template" state instead of an empty-looking (but technically loaded) step tree.

## Validate Upload/Edit button visibility by `permissionList` of menu `eutr-documents` (spec Update 4/Update 5, FR-030..FR-036)

**Correction note**: Update 4 originally gated Upload via a live backend probe
(`GET /api/eutr-documents/can-create`); an early draft of Update 5 added a mirror `can-update` for
Edit. Live testing showed both probes were unnecessary — the menu `eutr-documents`'s `permissionList`
(same mechanism `005-eutr-sales-orders` Update 28 uses for menu `eutr-sales-orders`) already carries
`'Create'`/`'Update'`. Both probes were removed; the steps below verify the corrected,
`permissionList`-based mechanism. This session's sibling update to `005-eutr-sales-orders` (that spec's
own Update 29) applies the identical correction to Map File Step 2's Upload/Edit buttons — see that
feature's own quickstart.md "Update 29" section.

1. Grant the test role both `'Create'` and `'Update'` on menu `eutr-documents` (via the same menu-admin
   mechanism used for menu `eutr-sales-orders` in `005`'s Update 28). Open any Purchase Order's
   `PurchId/View`. Confirm both the **Upload** button and every AVAILABLE FILES row's **Edit** button
   are visible and behave exactly as validated in the previous section (US2 step 6).
2. Revoke `'Create'` only (keep `'Update'`), reload. Confirm:
   - The **Upload** button does not appear anywhere on the page (not present, not merely
     disabled/greyed-out).
   - The **Edit** button on existing documents, the step tree, and AVAILABLE FILES all still render
     and behave normally (FR-031) — only Upload is affected.
3. Restore `'Create'`, revoke `'Update'` only, reload. Confirm:
   - The **Edit** button does not appear on any AVAILABLE FILES row (not present, not disabled).
   - The **Upload** button (per its own, independent `'Create'` gate), the step tree, and AVAILABLE
     FILES itself all still render and behave normally (FR-035) — only Edit is affected.
4. Revoke both `'Create'` and `'Update'`, reload. Confirm both Upload and Edit are hidden
   simultaneously, while the step tree/AVAILABLE FILES/PO info remain visible.
5. Restore both, reload. Confirm the Upload and Edit buttons reappear immediately on every row (no
   stale cached "hidden" state).
6. Confirm the browser makes no `can-create`/`can-update` network call when opening `PurchId/View`
   (DevTools Network tab) — the visibility check reads `localStorage` only, no round trip.

## Cross-check

- Compare the Progress figure on the Overview row (step 3 above) against the completed/missing step
  count visible on that same Purchase Order's detail screen (step 4 above) — they must match exactly
  at the same point in time (spec SC-002).

## Update 9 (2026-09-24) — New per-row Download button on AVAILABLE FILES; download file name = Step Name

100% frontend, zero backend change — reuses the existing `get-file-by-idref` endpoint. Same behavior
as `005-eutr-sales-orders` Update 33 (see that feature's quickstart.md for the full fixture/steps),
applied to `PurchId/View`'s own copy of the AVAILABLE FILES UI.

### Frontend verification (manual)

1. Open `PurchId/View` for a Purchase Order whose AVAILABLE FILES includes a document created BEFORE
   `004-eutr-documents` Update 26 (legacy `Prefix + Step Name` file name still in `eutr_documents.Name`).
   **Expected**: each row now shows 3 action buttons — View, Edit (if permitted), **Download** (new).
2. Click Download on that legacy document. **Expected**: file downloads immediately (no popup); saved
   file name = the Step's `Name` only — NOT the legacy stored name; the row's File name column is
   unchanged.
3. Open View for the same document, click Download inside the popup. **Expected**: same corrected
   Step-Name-only file name — the popup's own Download button is fixed too, not just the new row-level
   one.
4. Find a row with more than one Step chip (if available) and click Download. **Expected**: downloaded
   file name uses the first Step chip's name.

### Success criteria mapping (Update 9)

- SC-008 (Download produces correct content with Step-Name file name, including legacy documents, via
  both entry points) → frontend steps 2-3.
- FR-037 (new Download button, positioned after Edit, visible whenever `FileId` exists) → frontend
  step 1.
- FR-038 (name recomputed at download time; multi-Step uses first Step name) → frontend steps 2-4.

## Update 10 (2026-09-24) — Explicit Search button next to the search box on the Purchase Orders list

### Frontend verification (manual)

1. Open the Purchase Orders Overview list. Type a known Vendor code (e.g. `"CC01226"`) into the search
   box. **Expected**: a `Search` button now appears immediately to the right of the search field.
2. Before the 500ms auto-filter kicks in, click **Search**. **Expected**: the list filters immediately
   to matching rows (same result the debounce would have produced), page resets to 1.
3. Clear the search box, type a keyword that matches nothing, click **Search**. **Expected**: "No
   data" state, not an error.
4. Confirm the existing auto-filter-after-typing behavior (no click needed) still works unchanged.

## Update 11 (2026-09-30) — Template tree label shows the mapped file's name once uploaded; download for Type = "PO" documents no longer recomputes the file name as Step Name

100% frontend, zero backend change — the Upload-time matching/no-rename change for Type = "PO" lives in
`004-eutr-documents` Update 29 and is inherited automatically via the shared Add/Edit popup. Same
behavior as `005-eutr-sales-orders` Update 37 (see that feature's quickstart.md for the full
fixture/rationale), applied to `PurchId/View`'s own copy of the tree/AVAILABLE FILES UI.

### Frontend verification (manual)

1. Open `PurchId/View` for a Purchase Order whose Template has a Step assigned to Type "PO" (Assign
   Steps, `006-eutr-reference-types`) — e.g. Step "1.Invoice". Upload a file named `1.Invoice AP-PD.pdf`
   with Type = "PO" via the Upload button. **Expected**: upload succeeds; `eutr_documents.Name` for the
   new document equals `1.Invoice AP-PD.pdf` (no rename) — confirms `004-eutr-documents` Update 29
   end-to-end as a prerequisite.
2. Look at the tree. **Expected**: the node for Step "1.Invoice" now shows the label
   **"1.Invoice AP-PD"** (no `.pdf`) instead of "1.Invoice" — the secondary caption below it still shows
   the full `"1.Invoice AP-PD.pdf"`, unchanged.
3. Look at a Step node with no uploaded document. **Expected**: label still shows the plain Step name.
4. Click the row-level Download button (or popup View's Download) for the document from step 1.
   **Expected**: downloaded file is named exactly `"1.Invoice AP-PD.pdf"` — NOT recomputed to
   `"1.Invoice.pdf"`.
5. Click Download for a document whose Type is NOT "PO" (if any exist on this PO). **Expected**: download
   name is still recomputed as that document's Step Name + original extension, unchanged from Update 9.

### Success criteria mapping (Update 11)

- SC-010 (tree node label shows the mapped file's name minus extension; unmapped nodes show the Step
  name) → frontend steps 2-3.
- SC-011 (Type = "PO" downloads use the stored name as-is; Type ≠ "PO" downloads unaffected) → frontend
  steps 4-5.

### Success criteria mapping (Update 10)

- SC-009 (Search button applies immediately) → frontend steps 1-2.
- FR-039 (button present, immediate apply, auto-filter still works) → frontend steps 1, 2, 4.
