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
6. Click **Upload**, add a new document for one of the missing steps using a valid file. Confirm:
   - the popup is the same Add-document dialog used in `004-eutr-documents`.
   - after saving, AVAILABLE FILES and that step's tree indicator update immediately, without a page
     reload.
7. Click **Edit** on an existing document, change a field, save. Confirm the update persists and is
   reflected immediately.
8. Navigate to `/eutr/purchase-orders/DOES-NOT-EXIST/view` (an invalid Purch id). Confirm a clear
   "Purchase Order không tồn tại" error state, with no step tree/AVAILABLE FILES rendered.
9. Navigate to the detail screen for the Prerequisite #3 Purchase Order (blank Template). Confirm a
   clear "no Template" state instead of an empty-looking (but technically loaded) step tree.

## Cross-check

- Compare the Progress figure on the Overview row (step 3 above) against the completed/missing step
  count visible on that same Purchase Order's detail screen (step 4 above) — they must match exactly
  at the same point in time (spec SC-002).
