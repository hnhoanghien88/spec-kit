# Phase 1 Data Model: EUTR Sales Orders Management

> **Update 1 (2026-07-16)**: The Template column now reads real data from the existing MySQL table
> `eutr_purchase_attachments` (joined with `eutr_templates`), instead of a fixed demo value. No new
> database table/migration is introduced — both tables already exist per `docs/design/eutr/eutr_db.sql`.
> The 4 D365-sourced columns (Sales ID/Customer/Customer name/Delivery date) are unaffected by this
> update; see the original sections below for those. New sections for the Template data source
> follow the original ones.

Data for Sales ID/Customer/Customer name/Delivery date flows entirely through the existing shared
D365 reference lookup; the only "model" change there is additive fields on an existing response DTO
(unchanged by Update 1). Data for the Template column flows through a **new** read-only path over
two existing MySQL tables (see "Entity: Purchase Attachment" below).

## Entity: Sales Order (reference data, read-only)

Source: D365 entity `RSVNSalesOrderOpenInvoiceCogs` (`compliance-sys-api/src/ComplianceSys.Domain/
Dynamics/RSVNSalesOrderOpenInvoiceCogs.cs`), surfaced through
`POST /api/dynamics/reference?refType=11`.

| Field (spec column) | Source property (D365 entity) | Response DTO property | Type | Notes |
|---|---|---|---|---|
| Sales ID | `SalesId` | `Code` (and `Id`) | string | Also used as the `CodeColumn` for search-by-code filtering (`BuildFilterString`). |
| Customer | `CustAccount` | `CustAccount` (new) | string | Customer account/code — distinct from `Code`. |
| Customer name | `CustName` | `Name` | string | Used as the `NameColumn` for search-by-name filtering. |
| Delivery date | `DeliveryDate` | `DeliveryDate` (new) | date/null | Nullable — grid MUST show a placeholder ("-") when absent (spec FR-006). |

Not surfaced to the frontend for this feature (present on the D365 entity but out of scope):
`PurchId`, `RSVNSalesId`, `CustGroup`, `SalesStatus`, `InvoiceDate`, `CustomerRef`,
`TotalCompliances`, `TotalMissing`, `TotalApplied`, `TotalOverdue`, `ResponsibleEmails`,
`AlertEmails`.

Read-only: this entity is never created/updated/deleted by this system; it is queried live from
D365 on every request (subject to the same paging/filter/sort mechanics as every other `refType`).

## Response DTO change: `ComplDynReferenceResponseDto`

`compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/ComplDynReferenceResponseDto.cs`

```
Id            string   // existing — SalesId for refType=11
Code          string   // existing — SalesId for refType=11 (CodeColumn)
Name          string   // existing — CustName for refType=11 (NameColumn)
CustAccount   string?  // NEW — populated only for refType=11; null for every other refType
DeliveryDate  DateTime? // NEW — populated only for refType=11; null for every other refType
```

Additive-only change: existing consumers of other `refType`s are unaffected (fields default to
`null`/absent in JSON if unset).

## Mapping registration: `ComplDynamicsService`

`EntityMappings` (compile-time dictionary keyed by raw `refType` int):

```
{ (int)ObjectType.SALE_ORDER /* = 11 */, ("RSVNSalesOrderOpenInvoiceCogs", "SalesId", "CustName") }
```

`MapDynamicsResponse` switch: new `case 11:` branch deserializes items as
`List<RSVNSalesOrderOpenInvoiceCogs>` and projects each into `ComplDynReferenceResponseDto` with
`Id`/`Code` = `SalesId`, `Name` = `CustName`, `CustAccount` = `CustAccount`, `DeliveryDate` =
`DeliveryDate`.

## Frontend row shape (`SalesOrderOverviewPage.jsx`)

Each grid row, after fetching page(s) via `GetReferenceDataUseCase.execute(page, pageSize, "Code",
"asc", 11, filters)`:

| Grid column | Row field (from API item) | Fallback when empty |
|---|---|---|
| Sales ID | `item.code` (or `item.id`) | — (always present) |
| Customer | `item.custAccount` | "-" |
| Customer name | `item.name` | "-" |
| Delivery date | `item.deliveryDate` | "-" (spec FR-006 / Edge Cases) |
| Template | list of template names for this row's Sales ID (see below) | "-" (no attachment record — FR-007b) |
| Progress | fixed demo constant (e.g. a static `%` + fixed bar value) | n/a — always the same value |

Search (spec FR-011) reuses the existing generic filter payload shape already sent by
`useReferenceObjects`/`GetReferenceDataUseCase` — one filter on the `Code` column and one on the
`Name` column (both `like`), which `BuildFilterString`/`EntityMappings` resolve to `SalesId`/
`CustName` respectively for `refType=11`.

Pagination (spec FR-010): standard `page`/`pageSize` request params already supported by
`GetReferenceDataUseCase`/`dynamicsApi.getReferenceData`; page size chosen at implementation time
(e.g. reuse the grid component's existing page-size convention).

## Entity: Purchase Attachment (`eutr_purchase_attachments`, real data source for Template)

Existing MySQL table (no migration needed), per `docs/design/eutr/eutr_db.sql`:

| Column | Type | Notes |
|---|---|---|
| `Id` | `INT UNSIGNED` (PK) | — |
| `SalesId` | `VARCHAR(50)` | Joins to the Sales Order row's `code`/D365 `SalesId`. Not unique — a Sales ID can have many rows. |
| `PurchId` | `VARCHAR(50)` | Purchase line identifier; the reason one `SalesId` can map to multiple `TemplateCode`s. Not surfaced to the frontend. |
| `TemplateCode` | `VARCHAR(50)` | FK → `eutr_templates.Code`. |
| audit fields | — | `CreatedBy/CreatedDate/UpdatedBy/UpdatedDate` — not surfaced to the frontend for this feature. |

Read-only for this feature: no Create/Update/Delete UI or endpoint is introduced for this table.

## Response DTO (new): `SalesOrderTemplateDto`

`compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/SalesOrderTemplateDto.cs` (new file):

```
SalesId       string  // eutr_purchase_attachments.SalesId
TemplateCode  string  // eutr_purchase_attachments.TemplateCode
TemplateName  string  // eutr_templates.Name, joined by TemplateCode = Code
```

One row per distinct `(SalesId, TemplateCode)` pair — see Decision 6 (research.md) for the
`SELECT DISTINCT ... INNER JOIN` query that produces this shape directly (dedup and orphan-skip both
handled in SQL, not in application code).

## Repository contract: `IEutrPurchaseAttachmentsRepository`

`compliance-sys-api/src/ComplianceSys.Application/Interfaces/Repositories/IEutrPurchaseAttachmentsRepository.cs`
(new file, standalone interface — does not extend generic `IRepository<,>`, matching the
`IEutrReferencesRepository` precedent):

```
Task<List<SalesOrderTemplateDto>> GetTemplatesBySalesIdsAsync(
    IEnumerable<string> salesIds, CancellationToken ct = default);
```

Implemented by `EutrPurchaseAttachmentsRepository` (new file, `compliance-sys-api/src/
ComplianceSys.Infrastructure/Repositories/`) per research.md Decision 6.

## Endpoint contract summary

See `contracts/eutr-purchase-attachments.md` for the full request/response contract of the new
`POST /api/eutr-purchase-attachments/by-sales-ids` endpoint.

## Frontend: grouping the Template response into rows

`GetTemplatesBySalesIdsUseCase.execute(salesIds)` (new use case) returns the flat
`SalesOrderTemplateDto[]`-shaped list above. `SalesOrderOverviewPage.jsx` groups it client-side into
`{ [salesId]: string[] }` (array of `templateName`, already deduped by the backend query) and looks
up each row's Sales ID in that map when rendering the Template cell — no grouping key collisions are
possible since the map key (`SalesId`) exactly matches the grid row's `code`/`id` field (same D365
`SalesId` value on both sides).

---

## Update 2 (2026-07-16): `MapFilePage.jsx` data model

> Covers spec User Story 4 / FR-014..FR-030. Per `research.md` Decisions 9-15, almost every data
> source needed already exists; this update adds only one new read action and one new write action,
> both on the already-existing `EutrPurchaseAttachmentsController`.

### Entity: Purchase Order (reference data, refType = 16, read-only)

Source: D365 entity `RSVNEutrSalesOrderPurchases` (`compliance-sys-api/src/ComplianceSys.Domain/
Dynamics/RSVNEutrSalesOrderPurchases.cs`), already fully surfaced through
`POST /api/dynamics/reference?refType=16` (no backend change — see research.md Decision 10).

| Field (frontend use) | Source property (D365 entity) | Response DTO property (`ComplDynReferenceResponseDto`) | Type |
|---|---|---|---|
| PO (row identity) | `RSVNRefPurchId` | `Code` (and `Id`) | string |
| Name | `Name` | `Name` | string |
| Order account | `OrderAccount` | `OrderAccount` | string |
| Qty | `Qty` | `Qty` | long |
| Template (drives Save PO Mapping, not necessarily its own visible column) | `RSVNEutrTemplate` | `EutrTemplate` | string |
| Sales Order link (filter key, not rendered) | `InterCompanyOriginalSalesId` | `InterCompanyOriginalSalesId` | string |

Filtered per Sales Order via `[{ column: 'InterCompanyOriginalSalesId', operator: 'eq', value:
salesId }]` — already routed correctly by `ComplDynamicsService.BuildFilterString`'s generic
"other column" branch (not `Code`/`Name`), since `InterCompanyOriginalSalesId` is one of
`RSVNEutrSalesOrderPurchases.FilterableFields`. Zero backend change.

**Column mapping consequence**: Step 1's table no longer has real `Vendor`/`Vendor Name`/`Rate`/
`Material` data (none of these exist on this D365 entity or anywhere else in scope) — those mock
columns are replaced by **PO**, **Name**, **Order account**, **Qty** above.

### Entity: Purchase Attachment (`eutr_purchase_attachments`) — Update 2 adds read-by-SalesId and write

Table unchanged (still the one from Update 1's data-model — `SalesId`, `PurchId`, `TemplateCode` +
audit). Update 2 adds two new repository methods / controller actions (no schema/migration change):

**New read** — `IEutrPurchaseAttachmentsRepository.GetBySalesIdAsync(string salesId, ct)`:
```sql
SELECT PurchId, TemplateCode FROM eutr_purchase_attachments WHERE SalesId = @SalesId;
```
Exposed as `GET /api/eutr-purchase-attachments/by-sales-id/{salesId}` (policy
`EutrPurchaseAttachments.Read`, reused), returning `ApiResponse<List<PurchaseAttachmentDto>>` where:

```
PurchaseAttachmentDto
  SalesId       string
  PurchId       string
  TemplateCode  string
```

Used for **both**: (a) Step 1's `selectedPOs` initial state (`PurchId` values → default-checked, FR-
019), and (b) Step 2's distinct `TemplateCode`s (FR-023/FR-024) — one call serves both (research.md
Decision 12).

**New write** — `IEutrPurchaseAttachmentsRepository.DeleteBySalesIdAsync(string salesId, ct)` (raw
`DELETE ... WHERE SalesId = @SalesId`) + `EutrPurchaseAttachmentsService.SavePoMappingAsync(salesId,
items, userEmail, ct)` (transactional delete-then-reinsert loop, research.md Decision 11). Exposed as
`POST /api/eutr-purchase-attachments/save-po-mapping` (new policy `EutrPurchaseAttachments.Update`):

Request `SavePoMappingRequestDto`:
```
SalesId   string
Items     List<PurchaseAttachmentItemDto>   // PurchaseAttachmentItemDto { PurchId, TemplateCode }
```

`TemplateCode` per item comes from that PO's own `EutrTemplate` field (Step 1's D365 row, see
Purchase Order entity above) — the user never types/picks a template directly (spec Assumption,
FR-020). Response: `ApiResponse<string>` (simple ack; no content needed since the caller already
knows what it sent).

Full contract: see `contracts/eutr-purchase-attachments-map-file.md`.

### Reused entity: Reference (`eutr_references`) — AVAILABLE FILES, zero new backend

`POST /api/eutr-documents/list-po-references` (feature `004-eutr-documents`, already exists — see
research.md Decision 14) called with the `PurchId`s from `selectedPOs`. Response per PO:

```
EutrDocumentsPoReferenceDto
  poCode      string
  documents   EutrDocumentsPoReferenceItemDto[]
    documentId   long
    fileId       string?
    fileName     string?
    stepNames    string[]
```

Flattened across selected POs to populate AVAILABLE FILES (replacing `MOCK_AVAILABLE_FILES`). A
document's `stepNames` are matched by string against each tree node's `stepName` (below) to mark it
"already mapped" to that node (FR-027) — no `StepId` is returned by this endpoint, so matching is by
name (research.md Decision 14 Alternatives).

**Field-availability note**: this endpoint does not carry `source`/`size`/`validFrom`/`expiredDate`
(the mock's extra display fields) — only `fileName` (+ `fileId` for a future download/view action,
out of scope here). Step 2's AVAILABLE FILES list renders `fileName` and the matched step(s); the
mock's Source chip/Size/Valid-From-To fields are simply omitted for real rows (no fabricated data),
consistent with spec FR-026's "hiển thị các tài liệu thật" (show what's real, not more).

### Reused entity: Template tree (`eutr_template_details`, via `EutrTemplatesController`) — zero new backend

For each distinct `TemplateCode` from the Purchase Attachment read above:
1. `POST /api/eutr-templates/get-all` filtered `Code = templateCode`, `pageSize=1` → resolve `Id`.
2. `GET /api/eutr-templates/{id}` → `EutrTemplatesResponseDto.Details: EutrTemplateDetailsResponseDto[]`:

```
EutrTemplateDetailsResponseDto (extends EutrTemplateDetails)
  Id               long
  ParentId         long   // 0 = root
  StepId           long?
  StepName         string?   // JOIN eutr_steps
  RequirementType  byte?     // 0 = Optional, 1 = Required (frontend REQUIREMENT_LABELS)
  TakeFrom         byte      // 0 = PO, 1 = Upload manual (frontend TAKE_FROM_LABELS)
  DisplayOrder     int?
```

Fed through the existing `flatToTree()` util (unchanged, keyed by `ParentId`) to render one tree per
distinct `TemplateCode` (FR-024). Replaces `EUTR_TEMPLATE_DETAILS_MAP[so.templateId]`.

**Vocabulary narrowing (accepted, not a gap)**: real `TakeFrom` only has 2 values (PO / Upload
manual) — the mock's richer set (`Vendor`, `D365-Invoice`, `D365-PackingList`, `Company`, `D365`) and
the `AUTO_SOURCES`-driven "auto-detect" icon have no real equivalent; `isAuto` simply evaluates to
`false` for every real node (graceful degradation, not an error state).

### Frontend row/tree shapes (`MapFilePage.jsx`)

| UI area | Before (mock) | After (Update 2) |
|---|---|---|
| `if (!so)` / Header card | `MOCK_SALES_ORDERS.find(...)` | Single-row `refType=11` fetch (Decision 9) |
| Step 1 PO table | `MOCK_SO_POS[salesId]` (Vendor/Vendor Name/Rate/Material) | `refType=16` filtered fetch (Decision 10) — columns PO/Name/Order account/Qty |
| Step 1 checkbox default state | `MOCK_SO_PO_MAPPINGS[salesId]` | `GetBySalesIdAsync`'s `PurchId`s (Decision 12) |
| Save PO Mapping | no-op (`setPoSaved(true)` only) | `POST .../save-po-mapping` (Decision 11) |
| Step 2 tree | `EUTR_TEMPLATE_DETAILS_MAP[so.templateId]` | Per-`TemplateCode` `get-all`+`GetById` (Decision 13) |
| Step 2 AVAILABLE FILES | `MOCK_AVAILABLE_FILES` / `MOCK_FILE_MAPPINGS` | `list-po-references` flattened (Decision 14) |
| Step 2 Upload / Save (footer) | no-op (adds to local `newlyUploadedFiles` state / no-op) | **unchanged** — still local-state-only, no API call (spec FR-029/FR-030) |

---

## Update 4 (2026-07-20): `ViewSalesOrderPage.jsx` data model (read-only)

> Covers spec User Story 5 / FR-034..FR-046. Reuses every entity/DTO/endpoint already documented above
> for `MapFilePage.jsx` (Update 2) — no new entity, no new DTO, no new endpoint. This section only maps
> those same sources onto `ViewSalesOrderPage.jsx`'s read-only UI.

### Purchase Orders "đã chọn" (read-only subset of Step 1's PO entity)

Two calls, joined client-side (research.md Decision 19):

1. `GET /api/eutr-purchase-attachments/by-sales-id/{salesId}` → `PurchaseAttachmentDto[]`
   (`SalesId`, `PurchId`, `TemplateCode`) — same contract as Update 2's `MapFilePage.jsx` Step 1
   default-checked state; here it defines the **entire** displayed set (no toggling).
2. `POST /api/dynamics/reference?refType=16` filtered by `InterCompanyOriginalSalesId = salesId` (same
   as Update 2's Step 1 PO table) → `ComplDynReferenceResponseDto[]` with `code`, `name`,
   `orderAccount`, `qty`.

Displayed rows = (2) filtered to only `code` values present in (1)'s `PurchId` set. Columns: **PO**
(`code`), **Name** (`name`), **Order account** (`orderAccount`), **Qty** (`qty`) — identical column set
to Step 1 of Map File (no Vendor/Vendor Name/Rate/Material, per Update 2's Decision 10).

### Template Checklist (read-only render of Step 2's tree entity)

Identical source and shape to Update 2's "Reused entity: Template tree" section above: distinct
`TemplateCode`s from (1) above → `EutrTemplates` `get-all` (resolve `Id` by `Code`) → `GetById` →
`EutrTemplateDetailsResponseDto[]` → `flatToTree()`. Rendered via this page's own pre-existing
`ViewNode` component (non-interactive by construction — research.md Decision 21), not `MapFilePage.jsx`'s
interactive `TreeNode`.

### Per-step mapped/missing status (read-only render of AVAILABLE FILES' derivation)

Identical source to Update 2's "Reused entity: Reference" section: `POST /api/eutr-documents/
list-po-references` called with the `PurchId`s from the Purchase Orders table above. Each document's
`stepNames` matched against tree node `stepName` (same string-match derivation `MapFilePage.jsx`'s
`derivedFileMappings` already computes) to mark a node "đã có tài liệu"; a `Required` node with no
match is "còn thiếu" (FR-041).

### Validation Summary (derived, no new entity)

Computed locally from the data above (research.md Decision 20) — no new DTO/entity:

| Check | Source | Pass condition |
|---|---|---|
| Đã chọn ít nhất 1 PO | `PurchaseAttachmentDto[]` from (1) above | `length > 0` |
| Required steps đủ file | `computeProgress(allDetails, effectiveFileMappings)` (ported from `MapFilePage.jsx`) | `completed === total` |
| (list) Steps còn thiếu | `allDetails` filtered `requirementType === 'Required'` AND no mapped file | rendered as a list, not pass/fail |

"File không hết hạn" (the mock version's third check) is **not** ported — real documents from
`list-po-references` carry no expiry field (research.md Decision 20).

### Navigation (no data, UI-only)

- **Edit / Map File** button → `navigate(`/eutr/sales-orders/${salesId}/map-file`)` — same target
  `SalesOrderOverviewPage.jsx`'s row action and this page's own pre-existing button already use;
  unchanged by this update.
- **Download** button → no handler added; stays a visual-only button (spec FR-044).

### Frontend row/tree shapes (`ViewSalesOrderPage.jsx`)

| UI area | Before (mock) | After (Update 4) |
|---|---|---|
| `if (!so)` / Header card | `MOCK_SALES_ORDERS.find(...)` | Single-row `refType=11` fetch (same as `MapFilePage.jsx` Decision 9) |
| Purchase Orders đã chọn | `MOCK_SO_POS[salesId]` filtered by `MOCK_SO_PO_MAPPINGS[salesId]` (Vendor/Vendor Name/Rate/Material) | `by-sales-id/{salesId}` ∩ `refType=16` (Decision 19) — columns PO/Name/Order account/Qty |
| Template Checklist tree | `EUTR_TEMPLATE_DETAILS_MAP[so.templateId]` | Per-`TemplateCode` `get-all`+`GetById` (same as Decision 13) |
| Step mapped/missing status | `MOCK_FILE_MAPPINGS[salesId]` | `list-po-references` flattened + step-name match (same as Decision 14) |
| Validation Summary | 3 checks incl. "File không hết hạn" (always computable against mock dates) | 2 checks + missing-steps list (Decision 20) — expiry check dropped |
| Edit / Map File button | `navigate` to Map File (already real) | unchanged |
| Download button | visual-only | unchanged (still visual-only, spec FR-044) |
