# Research: EUTR Purchase Orders

## Decision 1 — Purchase Order source data: reuse `refType = 15` unchanged

**Decision**: Read Purch id, Vendor code, and Template directly from the existing
`POST /api/dynamics/reference` endpoint with `refType = 15`, no new endpoint.

**Rationale**: `ComplDynamicsService.EntityMappings[15]` already maps to `RSVNEutrPurchOrders`
(`compliance-sys-api/src/ComplianceSys.Application/Services/ComplDynamicsService.cs:43`), and its
`MapDynamicsResponse` `case 15` (same file, ~line 434) already projects `Id`/`Code` (= `PurchId`),
`Name`, **`EutrTemplate`**, and **`OrderAccount`** — the last two were added additively by
`011-eutr-synchronize-data` for its own Purchase-Order missing-documentation report, which already
uses this exact `refType` and already names its columns "Purch id / Vendor code / Vendor name /
Template" (`specs/011-eutr-synchronize-data/spec.md` Key Entities). This feature's list and detail
screens are simply a second, interactive consumer of the same fields.

**Alternatives considered**: A new dedicated backend DTO/endpoint — rejected, `EutrTemplate`/
`OrderAccount` are already exposed and Constitution Principle III requires reusing existing backend
surface over regenerating it.

## Decision 2 — Vendor name: secondary lookup via `refType = 14`, batched per page

**Decision**: `RSVNEutrPurchOrders` (refType=15) has no Vendor-name field. For each page of PO rows,
collect the distinct `OrderAccount` values present, call `POST /api/dynamics/reference` with
`refType = 14` (`VendorsV3`, already mapped: `Id`/`Code` = `VendorAccountNumber`, `Name` =
`VendorOrganizationName`) filtered by those codes in one batched call, and map the result back onto
each row by `OrderAccount`. Missing/unmatched vendor codes render Vendor name blank (spec FR-003,
matching `011-eutr-synchronize-data`'s own "blank where missing" edge case for the same fields).

**Rationale**: `011-eutr-synchronize-data` already resolves Vendor name the same way (refType=14
keyed by `OrderAccount`) for its own report — reusing the identical approach avoids inventing a new
resolution rule for the same two fields.

**Alternatives considered**: Extending `refType=15`'s backend mapping to embed Vendor name directly
(e.g. a SQL join inside `RSVNEutrPurchOrders`'s D365 view) — rejected as a much larger, unverified
ERP-side change; the batched client-side lookup achieves the same result using only already-shipped
endpoints, at the cost of one extra network call per page (acceptable — same page-batched shape as
Decision 4 below).

## Decision 3 — Template step tree: reuse `POST /api/eutr-templates/by-codes`, one Template per PO

**Decision**: For the list screen's Progress column, collect the distinct `EutrTemplate` codes
present on the current page and call the existing `POST /api/eutr-templates/by-codes` (added by
`005-eutr-sales-orders` Update 12, `EutrTemplatesController.cs:70`) once per page to get each
template's full step tree (`RequirementType`, `TakeFrom`, etc.). For the detail screen, the same
endpoint is called for the one Purchase Order's own `EutrTemplate` value (or `GET
/api/eutr-templates/{id}` if code-to-id resolution is simpler in context — both already exist).

**Rationale**: Unlike `005-eutr-sales-orders`, where a Sales Order can have several Purchase
Orders/Templates and the Template value must be joined through the local `eutr_purchase_attachments`
table, `RSVNEutrPurchOrders.EutrTemplate` already carries the Template directly on the Purchase
Order row itself — no local join table is needed to know "which Template applies to this PO." This
removes the entire Step-1/Save-PO-Mapping/Selected-POs concept `005`'s Map File needed, matching the
spec's explicit removal of those parts.

**Alternatives considered**: Reusing `eutr_purchase_attachments` (as `005` does) — rejected; that
table is keyed by `(SalesId, PurchId)` and exists to link a Sales Order to its PO(s)/Template(s), a
relationship this feature has no Sales Order context for and does not need.

## Decision 4 — Document/step-completion data: reuse `POST /api/eutr-documents/list-po-references`

**Decision**: Reuse `004-eutr-documents`'s existing `list-po-references` endpoint
(`EutrDocumentsController.cs:147`) unchanged — for the list screen, called once per page with the
page's union of Purch ids (same no-N+1 batching rule `005` Update 12/17 already established for its
own equivalent calls); for the detail screen, called with the single Purch id in the URL.

**Rationale**: This endpoint already returns, per document, the PO code and the `StepId`(s) it is
mapped to — exactly what's needed to determine, per template step, whether at least one document
exists for this Purchase Order. Zero backend change.

## Decision 5 — Progress computation: reuse `computeProgress()` from `eutr-sales-orders/utils/progressUtils.js`

**Decision**: Import `computeProgress` (and, where convenient, `normalizeTemplateDetail`) directly
from `compliance-client/src/presentation/pages/eutr-sales-orders/utils/progressUtils.js` rather than
re-implementing step/document matching. Call it with the single Template's `details` and this PO's
own file mappings — this feature never needs `buildTemplateComputations`'s multi-template
aggregation (that exists specifically for `005`'s one-Sales-Order-many-Templates case), only the
lower-level single-template `computeProgress` primitive.

**Rationale**: `005` Update 12 already extracted this util specifically to stop the Required-step/
`AUTO_SOURCES`-exclusion formula from silently drifting between independent consumers (Update 11 had
to fix exactly that kind of drift). Cloning the formula by hand a third time would reintroduce the
same risk Update 12 was written to prevent — importing the existing function keeps this feature
byte-for-byte consistent with `005`'s Map File/View screens.

**Alternatives considered**: Duplicating the formula inside the new `eutr-purchase-orders/` folder —
rejected per the rationale above; a straight cross-feature import is already an established pattern
in this codebase (`MapFilePage.jsx` itself imports `EutrDocumentsFormDialog`/`EutrFileViewerDialog`
from `004-eutr-documents`).

## Decision 6 — Search by Vendor code needs one small additive backend change

**Decision**: `ComplDynamicsService.BuildFilterString` (`ComplDynamicsService.cs:144`) currently
special-cases only two reserved OR-joined buckets, `code` (→ the entity's `CodeColumn`) and `name`
(→ `NameColumn`); any other filter column falls into an `other` bucket whose entries are AND-joined,
not OR-joined, with the code/name search group. Since Vendor code is `OrderAccount` — an *additive*
field on `refType=15`, not its `CodeColumn` (`PurchId`) — there is currently no way to OR a single
free-text keyword across Purch id **and** Vendor code in one call. Vendor name is one lookup further
removed (Decision 2) and is out of scope for server-side OR-filtering in this pass — search matches
Purch id or Vendor code; Vendor name search would additionally require pre-resolving matching Vendor
codes via `refType=14` before filtering `refType=15`, deferred as unnecessary complexity for a first
version (spec's Assumptions cover reasonable defaults; this is documented here as the resolved scope,
not a spec gap).

**Fix**: Add one more reserved bucket to `BuildFilterString`'s existing `GroupBy` switch, scoped to
`refType=15` (`RSVNEutrPurchOrders`) only — e.g. matching on `"ordaccount"`/`"vendorcode"` →
`"vendorcode"` group → column `OrderAccount` — folded into the same OR-joined `searchFilters` list
the `code`/`name` groups already build, so a single keyword search produces
`(PurchId like X or Name like X or OrderAccount like X)`. This is additive only: no other `refType`
is affected (the new bucket only ever resolves a column name for `RSVNEutrPurchOrders`), no
signature change to `GetDynRefePagedAsync`, no new endpoint/DTO/migration.

**Alternatives considered**: (a) Client-side filtering after fetching a large page — rejected, the
ERP source is 3,000+ rows (per `011-eutr-synchronize-data`) and server-side paging must stay
authoritative; (b) A brand-new endpoint dedicated to this feature — rejected, duplicates
`GetDynRefePagedAsync`'s paging/sorting/caching machinery for no reason when one filter-builder
branch suffices.

## Decision 7 — Reference feature to clone: `005-eutr-sales-orders`, not `document-type`

**Decision**: Model `PurchaseOrderOverviewPage.jsx` on `SalesOrderOverviewPage.jsx` (search/
pagination/page-scoped batching shape) and `PurchaseOrderViewPage.jsx` on `MapFilePage.jsx`'s Step 2
only (template tree + AVAILABLE FILES + Upload/Edit), per the spec's own explicit instruction to
mirror the Map File screen minus Step 1/Selected POs.

**Rationale**: Constitution Principle II names `document-type` as "the canonical reference," but its
own stated purpose is reuse of "an existing, working feature of **the same shape**." `005` is the
same shape (ERP-reference-data-driven list + Template + Document step-completion), `document-type`
is a plain local CRUD entity with no analogous concept — `005` itself already deviated from
`document-type` for the same reason (cloning `004-eutr-documents`'s dialogs instead), establishing
this as accepted precedent in this codebase, not a new exception.

## Decision 8 — Routing & menu registration follows `005`'s exact shape

**Decision**: Register the Overview screen as a new top-level menu code (`eutr-purchase-orders`,
url `/eutr/purchase-orders`) via `RouteResolver.jsx`'s `codeToComponent` map + a static
`menu-items/ComplianceSystem.jsx` entry (sibling to `eutr-sales-orders`'s own entry). Register the
detail screen as a static **nested** route in `MainRoutes.jsx`
(`/eutr/purchase-orders/:purchId/view`), mirroring the existing
`/eutr/sales-orders/:salesId/map-file` and `/eutr/sales-orders/:salesId/view` entries — reached by
row-level navigation (the View button), not a menu code, exactly like `MapFilePage`/
`ViewSalesOrderPage` today.

**Operational follow-up (not a code task)**: per this repo's established convention (routing is
driven by the backend `userMenu`/`canAccessMenu` data, not the static menu file — confirmed for
`001-eutr-steps` and unchanged since), the screen will not actually be reachable until an operator
also inserts the corresponding `userMenu` row and grants `canAccessMenu('eutr-purchase-orders')` to
the relevant role(s) in the database. This must be called out at implementation handoff so it is not
mistaken for a missed code change.
