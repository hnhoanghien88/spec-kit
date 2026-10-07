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
| Customer | `CustAccount` | `CustAccount` (new) | string | Customer account/code — distinct from `Code`. **Update 27**: also used for search-by-Customer-ID filtering (`BuildFilterString`'s `"custaccount"` case, OR-joined with `Code`/`Name`), same role `CodeColumn`/`NameColumn` already play for the other two search columns. |
| Customer name | `CustName` | `Name` | string | Used as the `NameColumn` for search-by-name filtering. |
| Delivery date | `DeliveryDate` | `DeliveryDate` (new) | date/null | Nullable — grid MUST show a placeholder ("-") when absent (spec FR-006). |
| Sales status | `SalesStatus` | `SalesStatus` (existing, retro-documented Update 25) | string | D365 enum **label** (e.g. `"Backorder"`, `"Invoiced"`), not numeric (confirmed via `013-compl-synchronize-data` research). Frontend renders it verbatim, except `"Backorder"` (case-insensitive) which MUST render as **"Open order"** (spec FR-171). |

Not surfaced to the frontend for this feature (present on the D365 entity but out of scope):
`PurchId`, `RSVNSalesId`, `CustGroup`, `InvoiceDate`, `CustomerRef`,
`TotalCompliances`, `TotalMissing`, `TotalApplied`, `TotalOverdue`, `ResponsibleEmails`,
`AlertEmails`.

**Correction (Update 25)**: `SalesStatus` was listed above as "not surfaced" at this doc's original
writing (Update 1), but codebase research for Update 25 confirmed it was surfaced to the frontend at
some point after that without a corresponding data-model update — `ComplDynReferenceResponseDto`
already has a `SalesStatus` property, `ComplDynamicsService`'s `case 11:` already assigns it, and
`SalesOrderOverviewPage.jsx` already renders it as the **Sales status** column. See the `SalesStatus`
row now added to the table below and the "Response DTO change" section's retro-documentation.

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
SalesStatus   string?  // existing — populated only for refType=11; null for every other refType
                        // (retro-documented Update 25; no code change — this property already exists)
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
`DeliveryDate`, `SalesStatus` = `SalesStatus` (retro-documented Update 25 — this assignment already
exists in code).

## Frontend row shape (`SalesOrderOverviewPage.jsx`)

Each grid row, after fetching page(s) via `GetReferenceDataUseCase.execute(page, pageSize, "Code",
"asc", 11, filters)`:

| Grid column | Row field (from API item) | Fallback when empty |
|---|---|---|
| Sales ID | `item.code` (or `item.id`) | — (always present) |
| Customer | `item.custAccount` | "-" |
| Customer name | `item.name` | "-" |
| Delivery date | `item.deliveryDate` | "-" (spec FR-006 / Edge Cases) |
| Sales status | `item.salesStatus`, with `"Backorder"` (case-insensitive) rendered as `"Open order"` (spec FR-171, Update 25) | "-" |
| Template | list of template names for this row's Sales ID (see below) | "-" (no attachment record — FR-007b) |
| Progress | fixed demo constant (e.g. a static `%` + fixed bar value) | n/a — always the same value |

Search (spec FR-011) reuses the existing generic filter payload shape already sent by
`useReferenceObjects`/`GetReferenceDataUseCase` — one filter on the `Code` column and one on the
`Name` column (both `like`), which `BuildFilterString`/`EntityMappings` resolve to `SalesId`/
`CustName` respectively for `refType=11`. **Update 27** (spec FR-179..FR-181): a third filter on the
`CustAccount` column (also `like`) is added to the same array, OR-joined with `Code`/`Name` via a new
`"custaccount"` case in `BuildFilterString` guarded to `mapping.Entity ==
"RSVNSalesOrderOpenInvoiceCogs"` (cloning the shape of the existing `refType=15`/`"vendorcode"` case,
research.md Decision 79) — resolves to D365 `CustAccount`, the same field already returned as
`custAccount` above.

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

---

## Update 5 (2026-07-27): Template tree toolbar reload + AVAILABLE FILES dynamic badges

> Covers spec FR-047..FR-052. Widens the same `EutrDocumentsPoReferenceItemDto` documented above
> under "Reused entity: Reference" (additive fields only) and reuses the already-established
> `RefType`→`eutr_reference_types.Name` lookup pattern (`004-eutr-documents` Update 14) — no new
> entity, no new endpoint, no migration (research.md Decisions 23-25).

### Response DTO change: `EutrDocumentsPoReferenceItemDto` (additive)

```
EutrDocumentsPoReferenceDto
  poCode      string                    // unchanged — now also read as "PO value" (FR-051)
  documents   EutrDocumentsPoReferenceItemDto[]
    documentId   long                   // unchanged
    fileId       string?                // unchanged
    fileName     string?                // unchanged
    stepNames    string[]               // unchanged — still consumed as-is by ViewSalesOrderPage.jsx
    stepIds      long[]                 // NEW — raw eutr_references.StepId values, distinct, for
                                         //       this document within this poCode's context
    refType      byte?                  // NEW — first non-null eutr_references.RefType across this
                                         //       document's rows in this poCode's context
    typeName     string?                // NEW — eutr_reference_types.Name for refType (LEFT JOIN,
                                         //       null if refType has no matching row or is null)
```

Backend source: `EutrReferencesRepository.GetDocumentsByPoCodesAsync`'s existing SQL (`eutr_references
r LEFT JOIN eutr_documents d LEFT JOIN eutr_steps s WHERE r.RefValue IN @PoCodes`) gains `r.StepId`,
`r.RefType`, and a new `LEFT JOIN eutr_reference_types t ON t.Id = r.RefType` + `t.Name AS TypeName`
in the `SELECT` list; the `EutrReferencePoDocumentInfo` projection class gains matching
`StepId`/`RefType`/`TypeName` properties. `EutrDocumentsService.GetPoReferencesAsync`'s existing
per-`DocumentId` grouping gains `StepIds` (distinct, like `StepNames`) and `RefType`/`TypeName`
(first non-null, same aggregation shape as `AttachStepAndConditionInfoAsync`).

### Derived values (frontend, `MapFilePage.jsx`)

| Badge (spec) | Source | Rule |
|---|---|---|
| Map status (FR-049) | `file.stepIds` vs `allDetails[].stepId` (already captured by `normalizeTemplateDetail`, Decision 13) | "Mapped" if any `stepIds` entry matches any current tree node's `stepId`; else "No map" |
| File type (FR-050) | `file.typeName` | Display as-is; empty state if `null` (FR-052) |
| PO value (FR-051) | `file.poCode` (= the `poDoc.poCode` this entry was built under, already available, previously unused) | Display as-is |

**Field-availability note (unchanged from Update 2, restated)**: this endpoint still does not carry
`source`/`size`/`validFrom`/`expiredDate` — the three new/reused fields above are additive to the
existing `fileName`/`fileId`/`stepNames` shape, not a replacement of the Update 2 field-availability
constraint.

---

## Update 6 (2026-07-27): Step 2 Upload/Edit → `004-eutr-documents`' Add/Edit popup

> Covers spec FR-029/FR-030/FR-030a/FR-030b. No new entity, no new DTO — this update reuses
> `004-eutr-documents`' own `EutrDocumentsResponseDto` shape (its own data-model, unchanged) for the
> one new read `MapFilePage.jsx` needs (edit-detail hydration), and both `eutr_documents` and
> `eutr_references` (already described above as read sources) are now also **written** by this
> screen — through the exact same 004-owned write paths, not a new write path of this feature's own.

### `initialData` shape required by `EutrDocumentsFormDialog` (edit mode)

| Field | Source (`EutrDocumentsResponseDto`) | Notes |
|---|---|---|
| `id` | `Id` | document id |
| `name` | `Name` | file name |
| `refType` | `RefType` | numeric Type id — locks the Type dropdown in the popup |
| `stepId` | `StepId` | "smallest `Id`" convention already established by `004-eutr-documents` FR-032; preloads Step |
| `conditions` | `Conditions` | array of `RefValue` strings; preloads Value chips |
| `validFrom` / `validTo` | `ValidFrom` / `ValidTo` | preload the two date pickers |

Fetched via `GetPagingEutrDocumentsUseCase.execute(1, 1, 'Id', 'asc', [{ column: 'Id', operator:
'eq', value: documentId }])` → `POST /api/eutr-documents/get-all` — the same use case/endpoint
`004-eutr-documents`' own grid already calls for its listing, just filtered down to one row
(research.md Decision 27). `documentId` comes from the AVAILABLE FILES entry the user clicked Edit
on (already available on the flattened `list-po-references` row since Update 2, as `documentId`).

### Write paths reused as-is (no new backend)

| Action | Endpoint | Used for |
|---|---|---|
| Upload, Type = "PO" | `POST /api/sharepoint/eutr-upload-multi` | New `eutr_documents` row(s) + matching `eutr_references` row(s) via PO-prefix match (`004-eutr-documents` FR-020/FR-023) |
| Upload, Type ≠ "PO" | `POST /api/sharepoint/eutr-upload-multi-by-type` | New `eutr_documents` row(s) + one `eutr_references` row per Value chip (`004-eutr-documents` FR-022) |
| Edit → Save (document fields) | `PUT /api/eutr-documents/{id}` | Updates `Name`/`ValidFrom`/`ValidTo` on the existing `eutr_documents` row |
| Edit → Save (step/values) | `PUT /api/eutr-documents/{id}/step` | Updates `StepId` on existing `eutr_references` row(s); for Type ≠ "PO" also diffs Value chips → adds/removes `eutr_references` rows (`004-eutr-documents` FR-033/FR-052/FR-053) |

### Frontend row/dialog shapes (`MapFilePage.jsx`)

| UI area | Before (Update 2/5) | After (Update 6) |
|---|---|---|
| Upload button (Step 2) | Local `UploadDialog` → `handleUpload` → pushes a fake row into `newlyUploadedFiles` local state, no API call | `<EutrDocumentsFormDialog mode="add" initialData={null} onSubmitted={refreshAvailableFiles} />` — real SharePoint upload + `eutr_documents`/`eutr_references` writes |
| Edit action (per file) | Local `MapFileDialog` → `handleMapDialogConfirm` → mutates `stepFilePO`/`fileMappings` local state, no API call | Fetch full detail (`GetPagingEutrDocumentsUseCase` filtered by `Id`) → `<EutrDocumentsFormDialog mode="edit" initialData={fetchedDoc} onSubmitted={refreshAvailableFiles} />` — real `eutr_documents` update + `eutr_references` step/value sync |
| Post-write refresh | n/a (nothing to refresh — no write ever happened) | `onSubmitted` re-invokes `GetEutrDocumentsPoReferencesUseCase.execute(purchIds)` (same call as Decision 14) so AVAILABLE FILES/Map status show the new/edited document immediately (FR-030a) |

---

## Update 7 (2026-07-27): AVAILABLE FILES/Map status scoped by PO ↔ Template (frontend-only)

> Covers spec FR-053..FR-057. No new entity, no new DTO, no new endpoint — this update only reshapes
> `MapFilePage.jsx`'s own derived-state (`useMemo`) computations over data already delivered by Update
> 2 (`purchaseAttachments`) and Update 5 (`poCode` per AVAILABLE FILES entry). See research.md
> Decisions 29-30.

### New derived value: `purchIdToTemplateCode` (frontend-only, no new fetch)

```
purchIdToTemplateCode: Map<string /* PurchId */, string /* TemplateCode */>
```

Built once from `purchaseAttachments` (already fetched via `GET /api/eutr-purchase-attachments/
by-sales-id/{salesId}`, Update 2 Decision 12 — unchanged request/response shape): `new Map(
purchaseAttachments.map(pa => [pa.purchId, pa.templateCode]))`. This is the authoritative PO→Template
scoping key for everything below — each `PurchId` maps to exactly one `TemplateCode` (spec Assumption,
Update 7).

### Re-scoped derived values (replace the Update 2/5 global versions)

| Value (before, Update 2/5) | Shape before | Shape after (Update 7) |
|---|---|---|
| `allDetails = templatesData.flatMap(t => t.flatDetails)` (global, all templates combined) | flat array across every saved template | still computed where a Sales-Order-wide list is genuinely needed (none after this update — every consumer below becomes per-template), effectively superseded |
| `derivedFileMappings` (tree's "already mapped" indicator, matched by `stepName` against `allDetails`) | one global `{ [detailId]: fileId[] }` matched against every file regardless of PO/template | computed **per template** `t`: match `t.flatDetails` only against `filesForTemplate(t.templateCode) = realAvailableFiles.filter(f => purchIdToTemplateCode.get(f.poCode) === t.templateCode)` — cross-template matches are now structurally impossible (scope-then-match, not match-then-filter) |
| `isMappedByStepId` (AVAILABLE FILES Map-status badge, `file.stepIds` vs `allDetails[].stepId`) | compared against every template's steps combined | compared only against `selectedTemplateCode`'s own `flatDetails` — since the file being rendered is now already scoped (see next row), this comparison can never cross into another template's steps |
| AVAILABLE FILES rendered list (`allFiles`/`availableFiles`, unfiltered `realAvailableFiles`) | every selected PO's documents merged into one list, regardless of which template's tree is currently shown | `filesForTemplate(selectedTemplateCode)` — only documents whose PO belongs (per `purchIdToTemplateCode`) to the template currently selected in the toolbar; switching the toolbar selection re-derives this list immediately (already-reactive `useMemo`, no new fetch) |
| `progress = computeProgress(allDetails, effectiveFileMappings)` (single global call) | one pass over the combined step/file sets | `computeProgress(t.flatDetails, effectiveMappingsForT)` run once per template `t` (using that template's own scoped `derivedFileMappings`/merged local `fileMappings`), then `{ completed: sum, total: sum, pct: round(sum(completed)/sum(total)*100) }` summed across all `t` — same aggregate shape and scope (Sales-Order-wide) as before, corrected inputs |

### Non-goals confirmed (Update 7)

- No backend/table/DTO/endpoint change — `purchaseAttachments` and each file's `poCode` are already
  delivered by existing, unmodified endpoints (Update 2/5).
- `stepNames`/`stepIds`/`typeName`/`poCode` fields themselves (Update 5) are unchanged — only how the
  frontend groups/matches them before rendering changes.
- Header aggregate progress stays Sales-Order-wide (sum across all templates) — not narrowed to only
  the currently-viewed template (research.md Decision 30).

## Update 8 (2026-07-27): `ViewSalesOrderPage.jsx` — Template Tree Toolbar + PO/Template-scoped status (frontend-only)

> Covers spec FR-058..FR-063. No new entity, no new DTO, no new endpoint — this update gives
> `ViewSalesOrderPage.jsx` the same `selectedTemplateCode`/single-tree-render/PO-Template-scoping
> behavior `MapFilePage.jsx` already has (Update 2/5/7), reading one field (`poCode`) that
> `list-po-references` already returns (Update 5) but this page's own builder didn't yet copy. See
> research.md Decisions 31-34.

### New state: `selectedTemplateCode` (clone of `MapFilePage.jsx`)

```
selectedTemplateCode: string | null   // TemplateCode currently shown in the Template Checklist
```

Defaults to `templatesData[0].templateCode` once `templatesData` is non-empty (or stays in sync with
a still-valid prior selection); `null` when `templatesData` is empty (spec FR-060) — identical
default-first-template shape to `MapFilePage.jsx`'s own state (Update 2, re-confirmed in Update 5's
clarification of "mặc định là template đầu tiên").

### Additive field read: `poCode` on `realAvailableFiles` entries

| Field | Before (Update 4) | After (Update 8) |
|---|---|---|
| `poCode` | not read (object literal at `realAvailableFiles` omits it, even though `poDoc.poCode` is present on every element of the same `list-po-references` response this page already consumes) | `poCode: poDoc.poCode` — identical value/source `MapFilePage.jsx` has read since its own Update 5 |

No DTO change — `EutrDocumentsPoReferenceItemDto.poCode` already exists and is already returned by
this same endpoint call; this update only starts reading a field already in the response payload.

### New derived value: `purchIdToTemplateCode` (clone of Update 7's Decision 29)

```
purchIdToTemplateCode: Map<string /* PurchId */, string /* TemplateCode */>
```

Built from `purchaseAttachments` (already fetched via `GET /api/eutr-purchase-attachments/
by-sales-id/{salesId}`, Update 4 — unchanged request/response shape): `new Map(
purchaseAttachments.map(pa => [pa.purchId, pa.templateCode]))`.

### New derived value: `templateComputations` (clone of Update 7's Decision 29)

Per template `t` in `templatesData`: `filesForTemplate = realAvailableFiles.filter(f =>
purchIdToTemplateCode.get(f.poCode) === t.templateCode)`, then `derivedFileMappings` matching
`t.flatDetails` against `filesForTemplate` by `stepName` — same shape as `MapFilePage.jsx`'s own
`templateComputations`, minus the local-`fileMappings` merge step (this screen has no manual
map/unmap to merge in, per Update 4's Decision 21).

### Re-scoped derived values (replace the Update 4 global versions)

| Value (before, Update 4) | Shape before | Shape after (Update 8) |
|---|---|---|
| `allDetails = templatesData.flatMap(t => t.flatDetails)` | flat array across every saved template | superseded — the Template Checklist now renders only the selected template's own `t.flatDetails`; Validation Summary sums per-template results instead (see below) |
| `fileMappings` (matched by `stepName` against `allDetails`) | one global `{ [detailId]: fileId[] }` matched against every file regardless of PO/template | replaced by `templateComputations[i].derivedFileMappings`, computed and consumed **per template** — cross-template matches are now structurally impossible |
| Template Checklist render (`templatesData.map(t => <tree for t>)`, every template stacked) | every saved template's tree shown at once | single tree for `selectedTemplateComputation` only (`t = templatesData.find(templateCode === selectedTemplateCode) ?? templatesData[0]`), fed that template's own `derivedFileMappings`/`filesForTemplate` as `ViewNode`'s `fileMappings`/`files` props |
| `requiredDetails`/`mappedRequired`/`missingRequired`/`pct` (single pass over global `allDetails`/`fileMappings`) | one pass over the combined step/file sets | computed once per template `t` (using `t`'s own scoped `derivedFileMappings`), then summed `completed`/`total` across all templates and concatenated `missingRequired` names — same aggregate shape and scope (Sales-Order-wide) as before, corrected inputs (clone of Update 7's Decision 30) |

### Toolbar (`data-marker="template-tree-toolbar"`)

| Before (Update 4) | After (Update 8) |
|---|---|
| 3 hardcoded `Chip`s: `"template code1"`, `"template code2"` (outlined), `"All"` — no `onClick` | `templatesData.map(t => <Chip label={t.templateName} variant={selected ? 'filled' : 'outlined'} onClick={() => setSelectedTemplateCode(t.templateCode)} />)` — no refetch call (spec FR-063, unlike `MapFilePage.jsx`'s FR-048 reload-on-click) |

### Non-goals confirmed (Update 8)

- No backend/table/DTO/endpoint change — `purchaseAttachments` (Update 4) and `poCode` (Update 5) are
  already delivered by existing, unmodified endpoints; this update only starts reading a
  already-returned field and re-shapes frontend derived state.
- No refetch of `purchaseAttachments`/`poReferenceDocs`/`templatesData` on toolbar click — the screen
  stays read-only, using only data already loaded when the page opened (spec FR-063).
- Header/Validation Summary aggregate progress stays Sales-Order-wide (sum across all templates) —
  not narrowed to only the currently-viewed template (same rule as Update 7's Decision 30).

## Update 9 (2026-07-27): View button on AVAILABLE FILES (Map File) — reused component, no new entity/DTO

> Covers spec FR-064..FR-068. No new entity, no new DTO, no new endpoint — this update reuses
> `004-eutr-documents`'s own `EutrFileViewerDialog`/`FilePreviewer`/`GetEutrDocumentsFileByIdRefUseCase`
> verbatim, and reads a field (`fileId`) already present on `MapFilePage.jsx`'s AVAILABLE FILES file
> objects since Update 5. See research.md Decision 35.

### Reused endpoint/response shape (owned by `004-eutr-documents`, unchanged)

`GET /api/eutr-documents/get-file-by-idref?idRef={fileId}` →

```
{ content: string /* base64 */, contentType: string, fileName: string }
```

Called internally by `EutrFileViewerDialog`'s `fetchFile` prop, via `GetEutrDocumentsFileByIdRefUseCase`
— `MapFilePage.jsx` never calls this endpoint or use case directly.

### New state: `viewerFile` (frontend-only, `MapFilePage.jsx`)

```
viewerFile: { open: boolean, fileId: string | number | null, fileName: string }
```

Cloned from `004-eutr-documents/index.jsx`'s own `viewerFile` state shape. Set on the new View
button's `onClick`: `setViewerFile({ open: true, fileId: file.fileId, fileName: file.name })`; reset
via `EutrFileViewerDialog`'s `onClose`: `setViewerFile(prev => ({ ...prev, open: false }))`.

### Reused field: `fileId` on AVAILABLE FILES entries (already present since Update 5, now also consumed)

| Field | Source | Consumer (before Update 9) | Consumer (after Update 9) |
|---|---|---|---|
| `fileId` | `doc.fileId` from `list-po-references`, copied onto each `realAvailableFiles` entry since Update 5 | none (present but unused on this page) | `viewerFile.fileId`, passed to `EutrFileViewerDialog` |

No DTO/table change — `fileId` was already being copied onto each file object; this update is the
first consumer of it on this screen.

### View popup UI (reused component, no new component)

| Element | Component | Behavior |
|---|---|---|
| View button | new `IconButton` (MUI `Visibility` icon) in `MapFilePage.jsx`, next to the existing Edit `IconButton` | opens the popup for that row's file; independent of Edit (spec FR-067) |
| Popup | `EutrFileViewerDialog` (reused as-is from `004-eutr-documents`) | renders file content via `FilePreviewer` (PDF/DOCX/XLSX/image), has its own Download + Close controls, no editable field, no Save (spec FR-066) |
| Unsupported file type | `FilePreviewer`'s own existing fallback (already handles this for `004-eutr-documents`) | shows a clear "cannot preview" state (spec FR-068) — no new logic needed |

### Non-goals confirmed (Update 9)

- No backend/table/DTO/endpoint change — `get-file-by-idref` and `fileId` are already delivered by
  existing, unmodified sources (owned by `004-eutr-documents`/this feature's own Update 5).
- No new frontend component/use case/repository/domain interface — `EutrFileViewerDialog.jsx`,
  `FilePreviewer.jsx`, and `GetEutrDocumentsFileByIdRefUseCase` are reused verbatim.
- No change to the Edit button/popup, Map status/File type/PO value badges, Upload, or the toolbar —
  this update only adds one new button + one new popup render to AVAILABLE FILES' row markup.

## Update 10 (2026-07-27): Real Download on View Sales Order — zip organized by Template

> Covers spec FR-069..FR-076. New request DTOs only (no new entity, no new table, no migration) — the
> new `download-zip` action's naming/zip-building mechanics are cloned from `AllCompliancesController`/
> `ComplianceDownloadService` (research.md Decision 36), and it fetches file content through the
> already-DI-registered `ISharepointService.DownloadByFileId`, the same interface/package
> `EutrDocumentsController` already depends on since Update 9. See research.md Decisions 36-40.

### New request DTOs (`ComplianceSys.Application/Dtos/Request/`)

```
EutrDownloadZipRequestDto
  SalesId        string
  CustomerCode    string
  CustomerName    string
  Folders         EutrDownloadZipFolderDto[]

EutrDownloadZipFolderDto
  FolderName      string   // template display name (raw, sanitized server-side — Decision 38)
  Files           EutrDownloadZipFileDto[]   // empty array allowed — an empty template folder (FR-073)

EutrDownloadZipFileDto
  FileId          string   // SharePoint file id — same value already carried as `fileId` on each
                            //  realAvailableFiles/list-po-references entry since Update 5
  FileName        string   // client-supplied display file name — reused directly, no server-side
                            //  SharePoint metadata re-lookup
```

### Endpoint contract

`POST /api/eutr-documents/download-zip` (policy `EutrDocuments.ReadAll`, reused — see
`contracts/eutr-documents-download-zip.md` for the full contract), response: binary `.zip` stream
(`Content-Type: application/zip`, `Content-Disposition: attachment; filename="<sanitized root name>.zip"`)
or `400 BadRequest` with a clear message when `folders` is empty or every folder's `files` list is
empty (spec FR-074).

### Building the request: `ViewSalesOrderPage.jsx`

No new fetch — the entire request body is derived from data already loaded and already correctly
computed by this page for on-screen rendering (Update 4/7/8):

| Request field | Derived from | Notes |
|---|---|---|
| `salesId` | the existing header `so.code`/`salesId` (Update 4, Decision 9) | already displayed in the page header |
| `customerCode` / `customerName` | the existing header `so.custAccount`/`so.name` (Update 4, Decision 9) | same fields already rendered in the header |
| `folders[].folderName` | `templatesData[i].templateName` (Update 2/8) | one folder per template already shown in the toolbar |
| `folders[].files[].fileId` / `.fileName` | the subset of `templateComputations[i].filesForTemplate` (Update 8, Decision 33) whose `documentId`/id appears in any value array of that same template's `derivedFileMappings` — i.e. already-"Mapped" documents only (spec FR-072) | reuses fields (`fileId`, `name`/`fileName`) already present on every `realAvailableFiles` entry since Update 5/8 — no new field needed |

If every template's Mapped-file subset above is empty (including the case where `templatesData` itself
is empty — Sales Order never Save-PO-Mapping'd), the Download handler shows the
"không có tài liệu nào để tải" message and does not call the endpoint (spec FR-074, research.md
Decision 39) — a purely client-side check against data already in memory, no new derived state beyond
what Update 8 already computes.

### Frontend blob-download (`DownloadEutrSalesOrderZipUseCase`, new)

Clones the already-established EUTR-family export pattern (`ExportEutrTemplatesUseCase.js`/
`ExportEutrMastersUseCase.js`/`ExportEutrTemplateReferencesUseCase.js`): call the repository method with
`responseType: 'blob'` (`eutrDocumentsApi.js`, new `downloadZip` method — additive, same file Update 6/
9 already extend), then `window.URL.createObjectURL(new Blob([blob]))` + a programmatic `<a download>`
click + `revokeObjectURL`; the saved file's name is resolved from the response's `Content-Disposition`
header (server-computed, sanitized root name — Decision 38), with the same generated-timestamp
fallback shape `ExportEutrTemplatesUseCase.js` already uses if the header is somehow absent.

### Frontend row/button shapes (`ViewSalesOrderPage.jsx`)

| UI area | Before (Update 4) | After (Update 10) |
|---|---|---|
| Download button | visual-only, no handler (FR-044) | `onClick` builds the `folders` payload from `templateComputations` (Update 8); if every folder is empty, shows an error and skips the call; otherwise calls `DownloadEutrSalesOrderZipUseCase.execute(...)`, which downloads and saves the zip |

## Update 11 (2026-07-27): Progress-figure consistency fix (frontend-only, no new entity/DTO)

> Covers spec FR-077..FR-081. No new entity, no new DTO, no new endpoint — this update adds one
> boolean condition (`!AUTO_SOURCES.includes(d.takeFrom)`) to `MapFilePage.jsx`'s existing
> `computeProgress()` filter predicate, aligning it with the exclusion already applied by this same
> file's own `missingRequired` and by `ViewSalesOrderPage.jsx`'s `requiredDetails`/`mappedRequired`/
> `missingRequired`. The count stays Required-only (Optional steps remain excluded, unchanged from
> Update 7). See research.md Decision 41.

| Variable | File | Before (Update 7) | After (Update 11) |
|---|---|---|---|
| `progress.total`/`progress.completed` (`computeProgress()`) | `MapFilePage.jsx` | Required steps only, no `AUTO_SOURCES` exclusion | Required steps only, **excludes** `AUTO_SOURCES` (matches the other 3 variables below) |
| `missingRequired` | `MapFilePage.jsx` | Required steps only, excludes `AUTO_SOURCES` | Unchanged |
| `requiredDetails`/`mappedRequired`/`missingRequired` | `ViewSalesOrderPage.jsx` | Required steps only, excludes `AUTO_SOURCES` | Unchanged |

## Update 12 (2026-07-27): Real, batched Progress on Overview — 2 new batch read endpoints, 1 new shared frontend util

> Covers spec FR-082..FR-086. No new table, no migration. Two new **additive** batch read endpoints
> (both read-only, both cloning already-working SQL — see research.md Decisions 43-44); one new shared
> frontend util module (`utils/progressUtils.js`, Decision 42) that `MapFilePage.jsx`/
> `ViewSalesOrderPage.jsx` are refactored to consume instead of their own local copies, and that
> `SalesOrderOverviewPage.jsx` newly consumes as its 3rd call site.

### New endpoint 1 — raw purchase attachments for many Sales IDs

`POST /api/eutr-purchase-attachments/by-sales-ids-raw` (policy `EutrPurchaseAttachments.Read`, reused)

Request: `List<string>` (Sales IDs of every row on the current page — same shape as the existing
`by-sales-ids` action's request).

Response: `List<PurchaseAttachmentDto>` (existing class, unchanged — `{SalesId, PurchId, TemplateCode}`),
one row per `eutr_purchase_attachments` record whose `SalesId` is in the request list — **not**
deduplicated, **not** joined to `eutr_templates` (unlike the existing `by-sales-ids`, which is both).

```sql
SELECT SalesId, PurchId, TemplateCode
FROM eutr_purchase_attachments
WHERE SalesId IN @SalesIds;
```

### New endpoint 2 — full template details for many Template Codes in one round trip

`POST /api/eutr-templates/by-codes` (policy `EutrTemplates.ReadAll`, reused)

Request: `List<string>` (distinct `TemplateCode`s across every row's purchase attachments on the current
page — deduplicated client-side before calling, since many Sales Orders typically share templates).

Response: `List<EutrTemplatesResponseDto>` (existing class, unchanged — same shape `GetById`/`get-all`
already return, `Details` populated per template).

```sql
-- 1) header rows for every requested code
SELECT t.Id, t.Code, t.Name, t.IsDefault, t.VersionId, t.Status, t.AlertFor,
       g.Name AS AlertForName, t.IsDeleted, t.IsHide,
       t.CreatedBy, t.CreatedDate, t.UpdatedBy, t.UpdatedDate
FROM eutr_templates t
LEFT JOIN compl_group_email g ON g.Id = t.AlertFor
WHERE t.Code IN @Codes AND t.IsDeleted = 0;

-- 2) detail rows for every template found above, grouped back onto each header row by TemplateId
SELECT d.Id, d.TemplateId, d.ParentId, d.StepId, d.RequirementType, d.TakeFrom, d.DisplayOrder,
       d.CreatedBy, d.CreatedDate, d.UpdatedBy, d.UpdatedDate,
       s.Name AS StepName
FROM eutr_template_details d
LEFT JOIN eutr_steps s ON s.Id = d.StepId
WHERE d.TemplateId IN @Ids
ORDER BY d.DisplayOrder;
```

### Reused unchanged — `list-po-references`

`POST /api/eutr-documents/list-po-references` (policy `EutrDocuments.ReadAll`) — zero change. Called
once per Overview page load with the **union** of every `PurchId` from endpoint 1's response across all
visible rows (confirmed generic/SalesId-agnostic already — see research.md Decision 45).

### Frontend: shared `progressUtils.js` (new file, colocated per the existing `utils/` convention)

`compliance-client/src/presentation/pages/eutr-sales-orders/utils/progressUtils.js`

```
AUTO_SOURCES                                                   // moved verbatim from MapFilePage.jsx
computeProgress(details, fileMappings)                          // moved verbatim from MapFilePage.jsx
buildTemplateComputations(templatesData, filesByPurchId,
                           purchIdToTemplateCode)                // generalized from MapFilePage.jsx's
                                                                  //   (Update 7) / ViewSalesOrderPage.jsx's
                                                                  //   (Update 8) own templateComputations
```

`MapFilePage.jsx` and `ViewSalesOrderPage.jsx` are refactored (behavior-preserving) to import these
instead of keeping their own local copies — see research.md Decision 42.

### Overview per-row Progress cell — data flow

| Step | Data source | Notes |
|---|---|---|
| 1 | `by-sales-ids-raw` (new) | Raw `{salesId, purchId, templateCode}` for every visible row, in one call |
| 2 | `by-codes` (new), given the distinct `templateCode`s from step 1 | Full step-detail tree per distinct template, in one call |
| 3 | `list-po-references` (unchanged), given the union of `purchId`s from step 1 | Mapped documents per PO, in one call |
| 4 | client-side, per row: `buildTemplateComputations` (shared util) + `computeProgress` (shared util), summed across that row's own templates | Same formula Map File uses for its own `progress` (FR-082) |

### Overview Progress cell — 4 discriminated states (FR-083/FR-084)

| State | Condition | Rendered as |
|---|---|---|
| `empty` | No `by-sales-ids-raw` rows for this `salesId` (never Save-PO-Mapping'd) | Same blank placeholder as the Template column's own empty state (FR-007b) |
| `no-required` | Has purchase-attachment rows, but 0 Required/non-`AUTO_SOURCES` steps across all matched templates | Distinct caption (e.g. "Không có step bắt buộc") — never `0/0`/`0%` |
| `ok` | Normal case | `{completed}/{total} steps`, `{pct}%`, progress bar — same rendering `DEMO_PROGRESS` used, now real values |
| `error` | Any of the 3 batch calls failed | Distinct error indicator scoped to the Progress cell only (FR-085) — other columns/rows unaffected |

### Non-goals confirmed (Update 12)

- No server-side Progress computation — formula stays client-side, single source of truth
  (`progressUtils.js`).
- No change to the existing `by-sales-ids`/Template column behavior.
- No per-row network call — all 3 calls are batched once per page load (FR-085).
- No new table, no migration.

## Update 13 (2026-07-27): Real, per-row, on-demand Download on Overview (zero backend change)

> Covers spec FR-087..FR-092. No new entity, no new DTO, no new endpoint, no migration — reuses
> `download-zip` byte-for-byte from Update 10 (see research.md Decision 49). The only new frontend
> piece is an on-demand (click-time, not batched) data pipeline per row, reusing `by-codes` (Update 12,
> Decision 44) as a single-row batch of that row's own distinct template codes.

### Per-row Download click — data flow (on-demand, only for the clicked row)

| Step | Data source | Notes |
|---|---|---|
| 1 | `GetPurchaseAttachmentsBySalesIdUseCase` (existing, unchanged — singular `by-sales-id/{salesId}`) | This row's own raw `{purchId, templateCode}` pairs |
| 2 | `by-codes` (Update 12's new endpoint), given this row's own distinct `templateCode`s | Reused as a 1-row "batch of N templates", not a 3rd inline 2-call-per-template loop |
| 3 | `GetEutrDocumentsPoReferencesUseCase` (existing, unchanged), given this row's own `purchId`s | Mapped documents for this row's own POs only |
| 4 | client-side: `buildTemplateComputations` (shared util, Update 12) → `folders` payload (`{folderName: templateName, files: [{fileId, fileName}]}[]`), same shape as `ViewSalesOrderPage.jsx`'s `buildDownloadFolders` | |
| 5 | `DownloadEutrSalesOrderZipUseCase` (existing, unchanged) → `POST /api/eutr-documents/download-zip` | Same request/response contract as Update 10 |

### Overview Download button — per-row state (FR-089/FR-090/FR-091)

| State | Trigger | Behavior |
|---|---|---|
| idle | default | `DownloadIcon`, clickable, never pre-disabled (FR-089) |
| in-flight | row's `salesId` is in the new `downloadingSalesIds` `Set` state | That row's icon swaps to a small `CircularProgress`; all other rows/search/pagination remain fully interactive (FR-090) |
| no-mapped-files | steps 1-4 complete but every folder's `files` is empty | Row-scoped message, same copy as View's FR-074; `download-zip` is never called (FR-089) |
| error | any of steps 1-5 throws | Row-scoped error message (FR-091); other rows unaffected |

### Non-goals confirmed (Update 13)

- No new backend endpoint/DTO/migration/policy — `download-zip` reused exactly as Update 10 shipped it.
- No batching of Download's own data fetch across rows (FR-088 — on-demand, single-row, opposite of
  Update 12's Progress batching).
- No write of any kind to `eutr_documents`/`eutr_references`/`eutr_purchase_attachments` (FR-092).
- No change to `ViewSalesOrderPage.jsx`'s own Download behavior — only its internal implementation now
  routes through the shared `buildTemplateComputations` util (Update 12) instead of its own inline copy.

## Update 14 (2026-07-28): Preserve Overview's search/page across Back navigation (frontend-only, no new entity/DTO)

> Covers spec FR-093..FR-099. No new table, no new entity, no new DTO, no new endpoint, no migration —
> this update is 100% client-side routing/state, the same category as Update 11. The only "data model"
> involved is client-side: the browser's own URL query-string on Overview's route, and a one-shot
> `location.state` flag passed at navigation time. See research.md Decisions 53-56.

### New client-side state: Overview's URL query parameters

| Param | Type | Default when absent | Set by |
|---|---|---|---|
| `search` | string | `''` | `SalesOrderOverviewPage.jsx`'s debounced search callback |
| `page` | number (0-based) | `0` | `SalesOrderOverviewPage.jsx`'s page-change handler |
| `page-size` | number | `DEFAULT_PAGE_SIZE` (100) | `SalesOrderOverviewPage.jsx`'s page-size-change handler |

`page`/`page-size` reuse the exact key names already established by `compliance-master/index.jsx`
(Decision 53); `search` is new, specific to this screen. All three are written with
`setSearchParams(next, { replace: true })` — updating the current history entry in place, not pushing
a new one per change.

### New client-side state: `location.state.fromOverview`

| Field | Type | Set by | Read by |
|---|---|---|---|
| `fromOverview` | `true` (one-shot flag; absent otherwise) | `SalesOrderOverviewPage.jsx`'s two `navigate()` calls to Map File/View | `MapFilePage.jsx`/`ViewSalesOrderPage.jsx`'s `handleBack` |

Not persisted anywhere — this is React Router's own `location.state`, scoped to the single navigation
entry it was set on; it does not survive a hard page reload (by design — see research.md Decision 54's
Rationale for why the fallback path is exactly right for that case).

### Back-button behavior (FR-094..FR-099)

| Condition | `handleBack` action | Result |
|---|---|---|
| `location.state?.fromOverview === true` | `navigate(-1)` | Pops to the exact prior Overview URL — `search`/`page`/`page-size` intact (FR-094/FR-095/FR-097) |
| `location.state?.fromOverview` absent (deep link, hard reload, or the flag didn't survive) | `navigate('/eutr/sales-orders')` (unchanged from Update 3) | Default, unfiltered, page-one list — same as menu/breadcrumb entry (FR-098) |

Every restore re-fetches live data through the exact same `fetchSalesOrders`/`fetchTemplatesForRows`/
`fetchProgressForRows` chain already used today — no snapshot/cache of the previous fetch is
introduced (FR-096, research.md Decision 55).

### Non-goals confirmed (Update 14)

- No new backend endpoint/DTO/migration/policy — 100% frontend.
- No new shared util/hook file (research.md Decision 56) — the fix stays inline in the 3 files it
  touches.
- No caching of Overview's previous fetch results — every restore is a fresh, live fetch (FR-096).
- No change to the menu/breadcrumb entry path — it keeps showing the default list (FR-098).

## Update 15 (2026-07-28): AVAILABLE FILES panel on View, filtered by step (frontend-only, no new entity/DTO)

> Covers spec FR-100..FR-106. No new table, no new entity, no new DTO, no new endpoint, no migration —
> this update renders already-computed client-side data (`buildTemplateComputations`'s
> `filesForTemplate`/`derivedFileMappings`, Update 12) as a new file-list panel, plus one additive
> field (`typeName`) copied from an already-fetched response. See research.md Decisions 57-59.

### New client-side state: `ViewSalesOrderPage.jsx`

| State | Type | Default | Set by | Cleared by |
|---|---|---|---|---|
| `selectedStepId` | tree node `id` \| `null` | `null` (no filter) | Clicking a row in the `ViewNode` tree (new `onSelect` prop) | Clicking any chip in `template-tree-toolbar` (`setSelectedStepId(null)` added to the existing `onClick`) |
| `viewerFile` | `{ open, fileId, fileName }` | `{ open: false, fileId: null, fileName: '' }` | Clicking a file row's new View `IconButton` | Closing `EutrFileViewerDialog` |

### `realAvailableFiles` — one additive field

| Field | Type | Source | Notes |
|---|---|---|---|
| `typeName` | string \| null | `list-po-references` response, `doc.typeName` (already returned since Update 5) | Same class of "already-fetched, never read" gap Update 8 fixed for `poCode` — no new query, no new endpoint. |

### AVAILABLE FILES panel — content resolution (FR-101/FR-102/FR-104)

| `selectedStepId` | Panel shows | Formula |
|---|---|---|
| `null` (default / just switched template) | Every document belonging to the active template's own PO(s) | `selectedTemplateComputation.filesForTemplate` (unfiltered) |
| set to a leaf step's `id` | That step's own Mapped document(s) | `derivedFileMappings[selectedStepId]`, mapped to file objects |
| set to a parent/category step's `id` | The union of Mapped documents across that step and all of its descendant steps | For every node id in `{selectedStepId} ∪ descendantIds(selectedStepId)`: union `derivedFileMappings[id]`, de-duplicated by file `id` |

Each row renders the same shape `MapFilePage.jsx`'s AVAILABLE FILES already renders — file name, **Map
status** (Mapped if the file's `id` appears in any `derivedFileMappings` value for the active template,
else "No map"), **File type** (`typeName`, this update's new field), **PO value** (`poCode`, already
present since Update 8), and **Step name** chip(s) (`stepNames`, already present since Update 4) — minus
the Edit/Upload controls (View stays read-only, FR-042/FR-100).

### Non-goals confirmed (Update 15)

- No new backend endpoint/DTO/migration/policy — `get-file-by-idref` (via `EutrFileViewerDialog`) is
  reused unmodified, exactly as already shipped for `MapFilePage.jsx` (Update 9).
- No new shared util/hook file — `selectedStepId`/`viewerFile`/the panel's `useMemo` live inline in
  `ViewSalesOrderPage.jsx` (research.md Decision 58's rationale, same restraint as Update 14/Decision 56).
- No refetch of PO/document data on step click or template click — both only change what is rendered
  from data already loaded when the screen opened (FR-063's existing no-refetch precedent, Update 8).
- No change to `MapFilePage.jsx` — this update touches only `ViewSalesOrderPage.jsx`.

## Update 16 (2026-07-28): Overview's default row set scoped to Sales IDs with Template (1 new read, no new entity/migration)

> Covers spec FR-107..FR-112. One new backend read (`GET /api/eutr-purchase-attachments/
> sales-ids-with-template`, a bare `string[]`, no new DTO/entity/migration/policy) plus frontend
> orchestration that reuses the existing `refType=11` reference call's already-existing `FilterRequest[]`
> same-bucket-OR behavior. See research.md Decisions 60-62.

### New read: distinct Sales IDs with a saved Template

| Field | Type | Source | Notes |
|---|---|---|---|
| (response) | `string[]` | `SELECT DISTINCT SalesId FROM eutr_purchase_attachments WHERE TemplateCode IS NOT NULL;` | No new DTO class; `TemplateCode IS NOT NULL` is always true today (column is `NOT NULL`, FR-022) but kept explicit for forward-consistency. |

### New client-side state: `SalesOrderOverviewPage.jsx`

| State | Type | Set when | Cleared/refreshed when |
|---|---|---|---|
| `salesIdsWithTemplate` | `string[] \| null` | Search box transitions to empty (mount, search cleared, or an empty keyword restored per Update 14/FR-110) — fetched via the new endpoint | Re-fetched on the next such transition; not read/used at all while a search keyword is non-empty |

### `refType = 11` request body — two mutually-exclusive shapes (FR-107/FR-109)

| Search box state | `FilterRequest[]` sent to `POST /api/dynamics/reference?refType=11` | Effect |
|---|---|---|
| Empty, `salesIdsWithTemplate` has ≥1 entry | `salesIdsWithTemplate.map(id => ({ column: "Code", operator: "eq", value: id }))` | D365 returns only the whitelisted Sales IDs, correctly paginated (`BuildFilterString`'s existing same-bucket `or`-join, unmodified) |
| Empty, `salesIdsWithTemplate` is `[]` | *(no call made)* | Table renders "No data" directly (FR-112) — an empty filter array would otherwise mean "no filter" |
| Non-empty (a search keyword) | Exactly the existing FR-011 Code/Name filter, unchanged | Every matching Sales ID is returned regardless of Template data (FR-109), same as before this update |

### Non-goals confirmed (Update 16)

- No new entity, DTO class (beyond a bare `string[]` response), migration, or policy — reuses
  `EutrPurchaseAttachments.Read`.
- No change to `ComplDynamicsService.cs`/`DynController.cs`/`ODataOperatorConverter.cs` — the same-bucket
  OR-join behavior this update depends on already exists, unmodified.
- No change to search behavior (FR-011/FR-109) — a non-empty keyword bypasses the whitelist path
  entirely.
- No per-row or per-page network calls — exactly one new call (the whitelist fetch), fired once per
  empty-search entry, reused across page/page-size changes within that same session.

## Update 17 (2026-08-11): Variants/Materials columns on Map File's Step 1 PO table (1 registration fix, no new entity/DTO/migration)

> Covers spec FR-113..FR-120. One backend fix — a single missing `ComplDynamicsService.EntityMappings`
> dictionary entry for `refType = 20` — makes an already-fully-implemented D365 entity/response-mapping/
> DTO path reachable for the first time; no new entity class, DTO field, controller action, or migration.
> Frontend adds one new batched fetch to `MapFilePage.jsx`, grouped client-side by PO. See research.md
> Decisions 63-65.

### Entity: Purchase Order Line (reference data, `refType = 20`, read-only — newly reachable)

> **Superseded from Update 34/35** — see that section below. This entity became the sole data source for
> both tables (not just the Variants/Materials columns), and gained 2 new fields (`QtyPercent`, `Unit`).
> Kept here for history; the field table immediately below reflects the pre-Update-34 shape.

Source: D365 entity `RSVNEutrSalesOrderPurchLines` (`compliance-sys-api/src/ComplianceSys.Domain/
Dynamics/RSVNEutrSalesOrderPurchLines.cs`, `ModelType = 20`) — the class, its `FilterableFields`, the
`MapDynamicsResponse` `case 20:`, and every `ComplDynReferenceResponseDto` field it assigns already exist
in code today; only the `EntityMappings[20]` registration was missing (research.md Decision 63).

| Field (frontend use) | Source property (D365 entity) | Response DTO property (`ComplDynReferenceResponseDto`) | Type |
|---|---|---|---|
| Material (`Materials` column) | `ItemId` | `Code` | string |
| Variant (`Variants` column) | `ProductVariant` | `ProductVariant` | string |
| PO link (filter/group key, not rendered) | `RSVNRefPurchId` | `RSVNRefPurchId` | string |
| Sales Order link (filter key, not rendered) | `InterCompanyOriginalSalesId` | `InterCompanyOriginalSalesId` | string |

Filtered per Sales Order via `[{ column: 'InterCompanyOriginalSalesId', operator: 'eq', value: salesId
}]` only (not per-PO) — the same `BuildFilterString` generic "other column" branch `refType=16`'s own
`InterCompanyOriginalSalesId` filter already relies on since Update 2 (research.md Decision 10). Grouping
by PO (`RSVNRefPurchId`) happens client-side, not via a second server-side filter (research.md Decision
64) — one Sales Order's Step 1 table needs every PO's lines in one call, not one call per PO.

**Backend fix — the only code change**: `ComplDynamicsService.EntityMappings` (Application layer) gains
one entry: `{ 20, ("RSVNEutrSalesOrderPurchLines", "InterCompanyOriginalSalesId", "ProductVariant") },`
— `CodeColumn`/`NameColumn` chosen to match `MapSortColumn`'s already-existing assumption for this entity
(unrelated to this feature's own two filter columns, which land in the generic "other column" bucket).
Not touched: the entity class, `MapDynamicsResponse`'s `case 20:`, `ComplDynReferenceResponseDto`,
`DynController.ReferenceData` — all four already compile and already behave correctly, gated only by this
one dictionary lookup.

### New client-side state: `MapFilePage.jsx`

| State | Type | Set when | Cleared/refreshed when |
|---|---|---|---|
| `poLinesByPurchId` | `Map<string, { materials: string[], variants: string[] }>` | The new `refType=20` fetch resolves — grouped by each item's `rsvnRefPurchId`, appending deduped `code` (Material)/`productVariant` (Variant) values in first-seen order | Re-fetched whenever `salesId` changes (new `useEffect`, same dependency as the existing `refType=16` PO-list effect) |
| `poLinesLoading` / `poLinesError` | `boolean` | Mirrors the existing `poListLoading` pattern for the `refType=16` effect | Same lifecycle as the fetch above |

### Step 1 PO table — Variants/Materials cell resolution (FR-116/FR-118/FR-119)

| `poLinesByPurchId.get(po.purchId)` | Cell content |
|---|---|
| Entry with ≥1 `materials`/`variants` value | `materials.join(', ')` / `variants.join(', ')` (e.g. "M01, M02") |
| No entry for this `purchId` | "—" (clear empty state, not an error, not "undefined") |
| Fetch failed (`poLinesError`) | Error/failed-to-load indicator on both cells, independent of the PO/Name/Order account/Qty columns which keep rendering from the unaffected `refType=16` data |

### Non-goals confirmed (Update 17)

- No new entity class, `MapDynamicsResponse` case, DTO field, or controller action — all four already
  exist for `refType=20`; the only backend edit is the one missing `EntityMappings` dictionary entry.
- No migration, no new policy — reuses whatever authorization the existing `/api/dynamics/reference`
  endpoint already requires (`[Authorize]`, no per-`refType` policy).
- No new frontend use case/repository/API client file — reuses `GetReferenceDataUseCase` →
  `IDynamicsRepository` → `RestDynamicsRepository`, the same chain the existing `refType=16` call uses.
- No per-PO network call — one batched call per Sales ID, grouped client-side by `RSVNRefPurchId`
  (FR-117).
- No change to Step 1's tick/checkbox/Save PO Mapping data or logic (FR-120).

## Update 18 (2026-08-12): Variants/Materials columns on View's Selected Purchase Orders table (0 backend files, pure reuse of Update 17)

> Covers spec FR-121..FR-128. Reuses the **Purchase Order Line** entity/`refType = 20` path above
> unchanged (already reachable since Update 17 — no backend edit at all this time) and clones its
> client-side fetch/grouping/rendering logic from `MapFilePage.jsx` into `ViewSalesOrderPage.jsx`,
> replacing that screen's hardcoded literal `"Variants"`/`"Materials"` cell text. See research.md
> Decision 66.

### New client-side state: `ViewSalesOrderPage.jsx`

Identical shape to `MapFilePage.jsx`'s own Update 17 state (above), scoped to this screen's already-
loaded `salesId`/`poList`:

| State | Type | Set when | Cleared/refreshed when |
|---|---|---|---|
| `poLinesByPurchId` | `Map<string, { materials: string[], variants: string[] }>` | The same `refType=20` fetch (filtered by `InterCompanyOriginalSalesId` only) resolves — grouped by `rsvnRefPurchId`, deduping `code` (Material)/`productVariant` (Variant) in first-seen order | Re-fetched whenever `salesId` changes (new `useEffect`, same dependency as this screen's own existing `refType=16` PO-list effect) |
| `poLinesLoading` / `poLinesError` | `boolean` | Mirrors `MapFilePage.jsx`'s own `poLinesLoading`/`poLinesError` pattern | Same lifecycle as the fetch above |

### Selected Purchase Orders table — Variants/Materials cell resolution (FR-124/FR-126/FR-127)

Identical resolution table to Map File's Update 17 (above) — same inputs, same outputs, same "—"/error
states — applied to `ViewSalesOrderPage.jsx`'s own `poLinesByPurchId` instead of `MapFilePage.jsx`'s.

### Non-goals confirmed (Update 18)

- No backend change of any kind — `EntityMappings[20]` is already registered by Update 17; this update
  is a new frontend caller only.
- No new entity class, DTO field, controller action, migration, or policy.
- No new frontend use case/repository/API client file — reuses the exact same
  `GetReferenceDataUseCase` → `IDynamicsRepository` → `RestDynamicsRepository` chain Update 17 already
  wired for Map File.
- No per-PO network call — one batched call per Sales ID, grouped client-side by `RSVNRefPurchId`
  (FR-125), same rule as FR-117.
- No change to View's read-only guarantee (FR-042), Edit/Map File, Download, Back, Template Checklist,
  Validation Summary, or AVAILABLE FILES (FR-128).

## Update 19 (2026-08-12): Real logic for the View toolbar's All chip — default-template lookup + tree filter/reparent (0 backend files)

> Covers spec FR-129..FR-140. No new entity, no new DTO, no new endpoint — reuses
> `GetPagingEutrTemplatesUseCase`/`GetEutrTemplatesUseCase` (Update 4) a second way (filtered by
> `IsDefault` instead of `Code`), and adds one new pure client-side function plus new derived state to
> `ViewSalesOrderPage.jsx`. See research.md Decisions 67-68.

### New entity read: **Template mặc định** (`eutr_templates`, `IsDefault = 1`/`IsHide = 0`/`IsDeleted = 0`)

Not a new table or column — `IsDefault`/`IsHide`/`IsDeleted` already exist on `eutr_templates` (used
since `003-eutr-templates`). What's new here is *this screen* querying by `IsDefault` instead of `Code`:
`GetPagedAsync`'s existing `FilterMap` already whitelists `IsDefault`, and its `WHERE` already forces
`IsDeleted = 0 AND IsHide = 0` unconditionally — so `{ column: 'IsDefault', operator: 'eq', value: 1 }`
against the exact same `get-all` endpoint returns 0 or 1 row (0 or 1 by construction, since
`003-eutr-templates`'s `ClearGlobalDefaultAsync` enforces at most one global default at a time).

### New client-side state: `ViewSalesOrderPage.jsx`

| State | Type | Set when | Cleared/refreshed when |
|---|---|---|---|
| `defaultTemplate` | `{ templateCode, templateName, flatDetails } \| null` | User clicks the All chip — `getPagingEutrTemplatesUseCase.execute(1, 1, 'Code', 'asc', [{ column: 'IsDefault', operator: 'eq', value: 1 }])` resolves to 0 or 1 row; if 1, `getEutrTemplatesUseCase.execute(id)` hydrates its `flatDetails` (same `normalizeTemplateDetail` mapping every other template already uses) | Re-fetched fresh on every All click (no caching); `null` while loading or when no row is found |
| `defaultTemplateLoading` / `defaultTemplateError` | `boolean` | Mirrors this screen's existing `templatesLoading`/error-state pattern, scoped to the default-template fetch only | Same lifecycle as the fetch above |

### New derived value: All tree (filter-and-reparent)

```
soStepIds = new Set(templatesData.flatMap(t => t.flatDetails).map(d => d.stepId))
allFlatDetails = filterFlatListByStepIds(defaultTemplate.flatDetails, soStepIds)   // new util, utils/treeUtils.js
allTree = flatToTree(allFlatDetails)                                              // existing util, unchanged
```

`filterFlatListByStepIds` (new function) keeps only items whose `stepId ∈ soStepIds`; for a kept item
whose `parentId` referenced a *removed* item, it rewrites `parentId` to that removed item's nearest
surviving ancestor (or `'0'`) — so `flatToTree` (unchanged) still builds a valid tree with no orphaned
`parentId` references (spec FR-132/FR-133). If `defaultTemplate` is `null` (FR-131) or `allFlatDetails`
ends up empty (FR-134), the Template Checklist renders the corresponding distinct empty state instead of
a tree.

### New derived value: All "has document" lookup and AVAILABLE FILES file set

```
allTemplatesFiles = dedupeById(templateComputations.flatMap(c => c.filesForTemplate))   // FR-136
allMappedStepIds = new Set(
  templateComputations.flatMap(c =>
    c.flatDetails.filter(d => (c.derivedFileMappings[d.id] || []).length > 0).map(d => d.stepId)
  )
)   // FR-135 — OR across every saved template's own, already-correctly-scoped mapping
```

Both derive entirely from `templateComputations` (Update 7/8/12, unchanged) — no new fetch, no new
per-template computation, no re-implementation of the PO/Template scoping rule.

### Toolbar (`data-marker="template-tree-toolbar"`) — All chip behavior

| Before (Update 8, pre-Update-19) | After (Update 19) |
|---|---|
| `templateCode: null` chip present; `onClick` sets `selectedTemplateCode = null`, but every downstream read (`selectedTemplateComputation`, rendered tree) falls back to `templateComputations[0]`/`templatesData[0]` — indistinguishable from re-selecting the first template | `onClick` additionally triggers the `defaultTemplate` fetch (above); when `selectedTemplateCode === null`, the Template Checklist renders `allTree` (with each node's mapped/missing status from `allMappedStepIds`) instead of falling back to the first template, and AVAILABLE FILES renders `allTemplatesFiles` instead of `selectedTemplateComputation.filesForTemplate` |

FR-060's existing default-first-template selection on page load (`selectedTemplateCode` seeded from
`templatesData[0].templateCode`) is unchanged — All is never auto-selected, only reachable by explicit
click (FR-138).

### Non-goals confirmed (Update 19)

- No backend change of any kind — the default-template fetch reuses `GetPagedAsync`'s already-
  whitelisted `IsDefault` filter and already-unconditional `IsHide`/`IsDeleted` clauses; zero new
  endpoint, DTO, entity, repository method, migration, or policy.
- No new frontend use case/repository/API client file — reuses
  `GetPagingEutrTemplatesUseCase`/`GetEutrTemplatesUseCase` exactly as already wired since Update 4.
- No refetch of `purchaseAttachments`/`poReferenceDocs`/`templatesData` on All click — only the new,
  genuinely-not-yet-loaded default template is fetched (screen stays read-only, spec FR-042).
- Header/Validation Summary aggregate progress (FR-062) and the Download zip mechanism (Update 10) stay
  Sales-Order-wide, unaffected by whether All is active (FR-139).
- No change to FR-060's page-load default (first real template) — All only activates on explicit click
  (FR-138).

## Update 21 (2026-08-12): Download zip gains an All folder — one existing DTO field reshaped, no new entity/endpoint

> Covers spec FR-142..FR-151. No new entity, no new table, no migration, no new endpoint. Reshapes the
> one existing `EutrDownloadZipFolderDto.FolderName` field into an ordered `FolderPath`, and reuses
> Update 19/20's already-computed All-tree state (`allChipTree`/`allChipDerivedFileMappings`/
> `allChipFiles`) plus the same default-template fetch (Update 19) for Overview's on-demand Download. See
> research.md Decisions 69-70.

### Request DTO change (`ComplianceSys.Application/Dtos/Request/`)

```
EutrDownloadZipFolderDto
  FolderPath      string[]   // was FolderName (string) — ordered path segments from the zip root,
                              //  e.g. ["Template A"] (unchanged per-template folders) or
                              //  ["All", "Forest", "Plantation forest location map"] (new nested All
                              //  step folders); each segment sanitized independently server-side
                              //  (research.md Decision 69), then joined with "/"
  Files           EutrDownloadZipFileDto[]   // unchanged — empty array allowed (FR-146/FR-073)
```

`EutrDownloadZipRequestDto`/`EutrDownloadZipFileDto` are unchanged. `EutrDocumentsController.DownloadZip`
changes only how `folderName` (the local variable feeding `CreateEntry`/`GetUniqueZipEntryName`) is
derived — from `SanitizeZipNamePart(folder.FolderName, "template")` to
`string.Join("/", folder.FolderPath.Select(s => SanitizeZipNamePart(s, "step")))` — every other line of
`DownloadZip` (empty-folder entry creation, per-file fetch/zip, filename disambiguation, `400`/`500`
responses) is untouched.

### New client-side derived value: All-folder entries (`ViewSalesOrderPage.jsx`)

```
filesById = new Map(allChipFiles.map(f => [f.id, f]))                      // new, O(1) lookup
allFolderEntries = flattenTreeToFolderEntries(allChipTree, allChipDerivedFileMappings, filesById, ['All'])
                                                                             // new util, utils/treeUtils.js
if (allFolderEntries.length === 0) allFolderEntries = [{ folderPath: ['All'], files: [] }]  // FR-147
```

`flattenTreeToFolderEntries` (new pure function, colocated with `flatToTree`/`filterFlatListByStepIds` in
`utils/treeUtils.js`) walks a tree and emits one `{ folderPath, files }` entry per node — `folderPath` is
the accumulated `[...parentPath, node.stepName]`, `files` is `(derivedFileMappings[node.id] ||
[]).map(id => filesById.get(id)).filter(Boolean).map(f => ({ fileId: f.fileId, fileName: f.name }))` —
then recurses into `node.children` with the extended path. `allChipTree`/`allChipDerivedFileMappings`/
`allChipFiles` are the exact, unchanged values Update 19 already computes (no new fetch, no re-derivation
of Map status/PO↔Template).

### Updated request: `ViewSalesOrderPage.jsx`'s `buildDownloadFolders`

| Request field | Before (Update 10) | After (Update 21) |
|---|---|---|
| `folders[].folderPath` (was `folderName`) | `[t.templateName]` implicitly (single string) | Unchanged value, now an explicit 1-element array, **plus** one additional entry per node from `allFolderEntries` above |
| `folders[].files` | Same per-template Mapped-file subset as Update 10 | Unchanged for per-template entries; each All entry's files come from `allFolderEntries` (per-`StepId`, merged across every saved template, FR-145) |

If `templatesData`/every template's Mapped-file subset is empty (FR-074, unchanged), the Download handler
still shows the "không có tài liệu nào để tải" message and skips the call entirely — this check runs
**before** the All entries are appended, so a Sales Order with zero Mapped documents never downloads a
zip containing only an empty All folder (FR-150).

### Updated request: `SalesOrderOverviewPage.jsx`'s per-row Download handler

Adds one new on-demand call, alongside the existing `Promise.all` (Update 13):

```
[templatesResponse, poReferencesResponse, defaultTemplateResult] = await Promise.all([
  ...,                                                            // unchanged (Update 13)
  loadDefaultTemplateForRow().catch(() => null)                   // new — same 2-call chain as
])                                                                 //  ViewSalesOrderPage.jsx's
                                                                    //  loadDefaultTemplate (Update 19)
```

`loadDefaultTemplateForRow` is the same `getPagingEutrTemplatesUseCase` (filtered `IsDefault = 1`) →
`getEutrTemplatesUseCase` chain, called inline rather than through component state (Overview has no
Template Checklist to render it into). Its failure is caught locally and treated as "no default
template" (`allFolderEntries` degrades to the FR-147 empty-All fallback) — it MUST NOT reject the
row's Download as a whole; the existing per-template folders are built and downloaded exactly as before
regardless of this call's outcome.

### Non-goals confirmed (Update 21)

- No new backend endpoint/policy/entity/table/migration — `POST /api/eutr-documents/download-zip` is
  reused as-is; only `EutrDownloadZipFolderDto.FolderName` is reshaped into `FolderPath`.
- No new frontend use case/repository/API client method — `DownloadEutrSalesOrderZipUseCase`,
  `eutrDocumentsApi.js`'s `downloadZip`, and `IEutrDocumentsRepository.js` are unchanged (all forward the
  `folders` payload opaquely; none reference `folderName`/`folderPath` by name).
- No new fetch added to View's Download click — reuses `allChipTree`/`allChipDerivedFileMappings`/
  `allChipFiles`, already populated by Update 20's mount-time auto-load.
- No change to per-template folder naming, Mapped-file scoping, empty-folder, or filename-dedup rules
  (FR-071..FR-075) — the All folder is purely additive alongside them.

## Update 22 (2026-09-07): Download shows a choice popup — `folders` becomes format-gated, no entity/DTO change

> Covers spec FR-152..FR-160. No new entity, no new table, no migration, no new endpoint, no request DTO
> change at all — `EutrDownloadZipRequestDto`/`EutrDownloadZipFolderDto`/`EutrDownloadZipFileDto` (Update
> 21) are reused byte-for-byte. This update is entirely a client-side change to which subset of the
> already-modeled `folders` entries gets assembled and sent. See research.md Decisions 71-73.

### New client-side state: `DownloadFormatDialog.jsx` (shared, `ViewSalesOrderPage.jsx`/`SalesOrderOverviewPage.jsx`)

```
format: 'combined' | 'byTemplate' | null      // local to the dialog, useState(null) — no pre-selection
```

`ViewSalesOrderPage.jsx` adds `downloadDialogOpen: boolean` (`useState(false)`).
`SalesOrderOverviewPage.jsx` adds `downloadDialogRow: { salesId, customerCode, customerName } | null`
(`useState(null)`) — a single value, not a per-row `Set`/`Map`, since only one modal can be
meaningfully open/interacted with at a time; independent of the existing `downloadingSalesIds` `Set`
(Update 13, per-row in-flight spinner state, unchanged).

### Updated request: `folders` becomes format-gated (both screens)

| Chosen format | `folders` payload sent |
|---|---|
| `'byTemplate'` | `templateFolders` only (Update 10/13 — one entry per saved template) — **no** entries from `allFolderEntries` |
| `'combined'` | `allFolderEntries` only (Update 21 — one entry per All-tree node, or the single `{ folderPath: ['All'], files: [] }` fallback per FR-147) — **no** `templateFolders` entries |

The request envelope (`EutrDownloadZipRequestDto`) and per-folder/per-file shape
(`EutrDownloadZipFolderDto`/`EutrDownloadZipFileDto`) are unchanged from Update 21 — only which array of
already-modeled entries populates `Folders` differs per format. The "no Mapped documents anywhere for
this format → show a message, skip the call" check (FR-074/FR-089, now format-scoped per FR-158) still
runs before `Folders` is assembled, same as Update 10/21.

### `SalesOrderOverviewPage.jsx` — conditional default-template fetch (new optimization)

```
if (format === 'combined') {
  [templatesResponse, poReferencesResponse, defaultTemplateResult] = await Promise.all([...])  // Update 21 shape, unchanged
} else {
  [templatesResponse, poReferencesResponse] = await Promise.all([...])   // format === 'byTemplate':
}                                                                          //  loadDefaultTemplateForRow
                                                                           //  is not called at all
```

When the user picks **By Template**, `loadDefaultTemplateForRow` (Update 21's on-demand 2-call default-
template chain) is skipped entirely rather than fetched-and-discarded — its only consumer
(`allFolderEntries`) will not be sent. `ViewSalesOrderPage.jsx` has no equivalent conditional fetch: its
default-template data (`allChipTree`/`allChipDerivedFileMappings`/`allChipFiles`) is already loaded on
mount (Update 20) for the always-visible All chip/Template Checklist, independent of Download.

### Non-goals confirmed (Update 22)

- No new backend endpoint/policy/entity/table/migration/DTO field — `download-zip` and every request DTO
  (Update 21) are reused exactly as-is.
- No change to per-template or All-folder naming, Mapped-file scoping, empty-folder, or filename-dedup
  rules (FR-071..FR-075, FR-142..FR-148) — only which already-correct set is included per download.
- No persisted "last chosen format" — `format` resets to `null` every time the dialog reopens.
- No change to `downloadingSalesIds` (Update 13) or to View's mount-time default-template auto-load
  (Update 20) — both are unaffected by this update.

## Update 24 (2026-09-18): Overview gains an ETD column + Year/ETD Week filter, brown View/Download buttons, Delivery-date-descending default sort

### Field addition: `ComplDynReferenceResponseDto.RsVnETD` (refType = 11 only)

| Field | Type | Source | Notes |
|---|---|---|---|
| `rsVnETD` (camelCase on the wire) | `DateTime?` | `RSVNSalesOrderOpenInvoiceCogs.RsVnETD` (already exists, `Domain/Dynamics/RSVNSalesOrderOpenInvoiceCogs.cs:37`) | New nullable property on `ComplDynReferenceResponseDto`, assigned in `MapDynamicsResponse`'s `case 11:` alongside the existing `DeliveryDate` assignment (research.md Decision 74). `null`/absent for every `refType` other than 11, same convention as `custAccount`/`deliveryDate` (Update 1/9 of this doc). |

No new entity, no new table, no migration — this is a projection of a field the entity has always had.

### Filter addition: ETD Year/Week on `RsVnETD` (refType = 11 only)

| Filter shape (unchanged from `compliance-view`) | Resolved by |
|---|---|
| `{ column: "RsVnETD", operator: "inyear", value: "2026" }` | `EtdWeekFilterBuilder.BuildYear` (unchanged, `Utils/EtdWeekFilterBuilder.cs`) — new call site inside `ComplDynamicsService.GetDynRefePagedAsync` (research.md Decision 75) |
| `{ column: "RsVnETD", operator: "inweeks", value: "2026:3,5,9" }` | `EtdWeekFilterBuilder.Build` (unchanged) — same new call site |

Both filter entries are intercepted **before** `BuildFilterString`/`ODataOperatorConverter.ToODataOperator`
ever sees them (which would otherwise throw on the unrecognized `inyear`/`inweeks` operator strings), then
AND-ed onto whatever condition `BuildFilterString` produces for the remaining ("other"-bucket) filters —
mirroring `AllCompliancesService.GetDataAsync`'s existing extract-then-AND shape exactly. No new
`FilterRequest` shape, no new response field for this part (the filter narrows `items`, it does not add a
column).

### Sort addition: `sortColumn = "DeliveryDate"`, `sortOrder = "desc"` (new default, refType = 11 only)

No DTO/entity change — `MapSortColumn`'s existing default arm (`_ => sortColumn`) already passes this
literal D365 field name straight through to `SetOrderBy` for `RSVNSalesOrderOpenInvoiceCogs`; only the
frontend's hardcoded call-site literals change (`'Code'`/`'asc'` → `'DeliveryDate'`/`'desc'`).

### Non-goals confirmed (Update 24)

- No new backend endpoint, controller, entity, table, or migration.
- No new `ComplDynReferenceResponseDto` field beyond `rsVnETD` — Progress/Template columns (Update 1/12)
  and every other existing field are unaffected.
- No change to `ODataOperatorConverter`'s recognized operators, and no change to any `refType` other than
  11's filter/sort/response behavior.
- No persisted UI-side "last chosen Year/Week" — each Overview page load/Clear resets to no filter, per
  spec FR-166.

## Update 25 (2026-09-18): Sales status column — "Backorder" → "Open order" display-label mapping (frontend-only, no entity/DTO change)

### Retro-documentation: `SalesStatus` (refType = 11, existing field)

`SalesStatus` was omitted from this doc's original (Update 1) field table and never added despite
already existing in code — see the correction and the new `SalesStatus` row added to the "Entity: Sales
Order" and "Response DTO change" sections above, and the new row added to "Frontend row shape" above.
No code changes accompany the retro-documentation itself.

### Display-label mapping (new behavior, Update 25)

| Raw `SalesStatus` value (case-insensitive) | Rendered label |
|---|---|
| `"Backorder"` | **"Open order"** |
| any other value (including empty/`null`) | unchanged — raw value verbatim, or `"-"` if empty/`null` |

Implementation is a single client-side comparison inside `SalesOrderOverviewPage.jsx`'s existing Sales
status cell render — no new component, util file, or shared mapping table. This is intentionally a
single label substitution (spec FR-171/FR-172, Assumption), not a general `SalesStatus` → display-label
lookup table; extending it to other values is out of scope for this update.

### Non-goals confirmed (Update 25)

- No new backend endpoint, controller, entity, table, migration, or DTO field — `SalesStatus` is already
  fully delivered by the existing `refType=11` response.
- No change to `ComplDynamicsService`, `DynController`, `ODataOperatorConverter`, `EntityMappings`, or
  `MapSortColumn`.
- No change to any other Overview column/control (Sales ID, Customer, Customer name, Delivery date, ETD,
  Template, Progress, search, Year/ETD Week filter, sort, pagination, Back-navigation restore, View/
  Download/Map File actions).

## Update 27 (2026-09-22): Overview search box OR-matches Customer ID (`CustAccount`), in addition to Sales ID/Customer name (frontend one-line addition + backend one guarded switch-case, no entity/DTO change)

### Search filter addition (refType = 11 only)

| Filter entry | Resolves to (D365) | Join with other search entries |
|---|---|---|
| `{ column: "Code", operator: "like", value }` (existing) | `SalesId` | OR |
| `{ column: "Name", operator: "like", value }` (existing) | `CustName` | OR |
| `{ column: "CustAccount", operator: "like", value }` (**new, Update 27**) | `CustAccount` | OR |

All three entries are sent together by `SalesOrderOverviewPage.jsx`'s `buildSearchFilters(search)`
whenever the search box is non-empty, and are OR-joined by `BuildFilterString` into the same search
bucket the first two already use — a single keyword now matches if it is a "contains" substring
(case-insensitive) of Sales ID, Customer (`CustAccount`), or Customer name (`CustName`), on any one of
the three, not requiring all three (spec FR-179).

`CustAccount` requires no new D365 field, no new `ComplDynReferenceResponseDto` property, and no new
`EntityMappings[11]` entry — it has been read and returned as `custAccount` since this feature's own
Update 1 (Customer column, FR-004); the only change is registering it as a **searchable** column, via a
new `"custaccount"` case in `BuildFilterString`'s column-grouping switch, guarded to
`mapping.Entity == "RSVNSalesOrderOpenInvoiceCogs"` — the same entity-guarded-case shape `refType = 15`
(Purchase Orders) already established for its own `VendorCode` OR-search extension (research.md
Decision 79).

### Non-goals confirmed (Update 27)

- No new backend endpoint, controller, entity, table, migration, or DTO field — `CustAccount` is already
  fully delivered by the existing `refType=11` response since Update 1.
- No change to `EntityMappings[11]`'s `(CodeColumn, NameColumn)` tuple or `MapDynamicsResponse`'s
  `case 11:` — Sales ID/Customer name filtering and mapping are unchanged (spec FR-180).
- No change to any other `refType`'s filtering behavior — the new `"custaccount"` case is guarded to
  `RSVNSalesOrderOpenInvoiceCogs` only (spec FR-181).
- No change to how the search keyword combines with Year/ETD Week (Update 24, AND) or with the
  Template-whitelist default-view filter (Update 16) — only the set of columns one existing keyword is
  OR-matched against widens.
- No change to any other Overview column/control (Sales ID, Customer name, Delivery date, ETD, Sales
  status, Template, Progress, sort, pagination, Back-navigation restore, View/Download/Map File actions).

## Update 28 (2026-09-22): Map File/Edit/Download icon visibility gated by `permissionList` ('Update'/'Download') on menu `eutr-sales-orders` (frontend-only, no entity/DTO/API change)

### No new entity or field — this update introduces zero data-model surface

`permissionList` is not a new entity/field owned by this feature: it is an existing array of permission-
name strings already attached to each menu record delivered by the external menu/auth service and
already cached client-side in `localStorage['userMenu']`. This feature does not define, store, or
transport `permissionList` itself — it only reads the already-existing value for its own menu record
(`code === 'eutr-sales-orders'`).

| Icon/button | Screen | Gating condition (Update 28) |
|---|---|---|
| Map File | Overview (per row) | `permissionList.includes('Update')` |
| Edit / Map File | View | `permissionList.includes('Update')` |
| Download | Overview (per row) | `permissionList.includes('Download')` |
| Download | View | `permissionList.includes('Download')` |
| View summary | Overview (per row) | none (unchanged) |
| Back | View | none (unchanged) |

### Non-goals confirmed (Update 28)

- No new backend endpoint, controller, entity, table, migration, DTO, or authorization policy —
  `permissionList` is already delivered end to end by the existing external menu/auth service; this
  update makes zero backend calls.
- No new frontend domain entity/model — `permissionList` stays a plain array of strings, read via the
  already-existing `getMenuDataFromStorage()` util, exactly as every other EUTR screen already consumes
  it for its own menu.
- No change to any existing entity/DTO field used elsewhere in this feature (Sales ID, Customer,
  Customer name, Delivery date, ETD, Sales status, Template, Progress, `eutr_purchase_attachments`,
  `eutr_references`, `eutr_documents`, `eutr_templates`, etc.).
- No change to the View summary icon (Overview) or Back button (View) — both remain unconditional
  (spec FR-187).

## Update 29 (2026-09-23): Map File Step 2 Upload/Edit buttons gated by `permissionList` of menu `eutr-documents` (frontend-only, no entity/DTO/API change)

### No new entity or field — same mechanism as Update 28, new menu code

Like Update 28, `permissionList` is not a new entity/field owned by this feature: it is the existing
array of permission-name strings already attached to each menu record delivered by the external
menu/auth service (`GET .../menu-managements/permissions`) and already cached client-side in
`localStorage['userMenu']`. This update reads that already-available array for the menu record whose
`code === 'eutr-documents'` (not `'eutr-sales-orders'`, since Upload/Edit here are actions on
`EutrDocuments`, not on the Sales Order itself) — confirmed via live testing that this menu's
`permissionList` already carries `'Create'`/`'Update'` as valid entries.

An earlier draft of this update instead added a new backend endpoint (`GET /api/eutr-documents/can-update`,
mirroring the pre-existing `can-create`) and had both `MapFilePage.jsx` and `PurchaseOrderViewPage.jsx`
(`012-eutr-purchase-orders`) call it live on mount. Both that endpoint and the pre-existing `can-create`
were removed after confirming `permissionList` already answers the same question with data already in
memory — see `research.md` Decision 81 for the full before/after.

| Button | Screen | Gating condition (Update 29) |
|---|---|---|
| Upload | Map File Step 2 | `permissionList.includes('Create')` (menu `eutr-documents`) |
| Edit (per row) | Map File Step 2, AVAILABLE FILES | `permissionList.includes('Update')` (menu `eutr-documents`) |
| View (per row) | Map File Step 2, AVAILABLE FILES | none (unchanged) |

### Non-goals confirmed (Update 29)

- No new backend endpoint, controller, entity, table, migration, DTO, or authorization policy —
  `permissionList` is already delivered end to end by the existing external menu/auth service; this
  update makes zero backend calls (a net decrease from the earlier draft's 2 new calls per page load).
- No new frontend domain entity/model — `permissionList` stays a plain array of strings, read via the
  already-existing `getMenuDataFromStorage()` util.
- No change to any existing entity/DTO used elsewhere in this feature (`eutr_purchase_attachments`,
  `eutr_references`, `eutr_documents`, `eutr_templates`, etc.) or to Update 28's `permissionList` gating
  of menu `eutr-sales-orders` (independent menu code, independent of this update).
- No change to the View button (read-only preview) or Step 1 (PO selection/Save PO Mapping) — both
  remain unconditional.

## Update 33 (2026-09-24): New per-row Download button on AVAILABLE FILES + download-time file-name recompute (frontend-only, no entity/DTO/API change)

### No new entity, field, or endpoint

Reuses the existing `GET /eutr-documents/get-file-by-idref?idRef=...` endpoint (already used by the
View popup) verbatim — same request shape, same response shape (`{ content, contentType, fileName }`).
No new backend file, entity, DTO, migration, or route.

### Client-side "download file name" computation (not a DB field)

The downloaded file's local name is now computed at download time, not read from any stored field:

```
downloadFileName = sanitizeFolderName(stepNames[0]) + extensionOf(storedName)   // stepNames non-empty
downloadFileName = storedName                                                   // stepNames empty (fallback)
```

- `stepNames` — the same per-document array already returned by `list-po-references`
  (`doc.stepNames`), already used to render the Step chips on each AVAILABLE FILES row. No new API
  field.
- `extensionOf(storedName)` — parsed client-side from whatever is already in `eutr_documents.Name`
  (via `get-file-by-idref`'s `fileName` field) — the extension itself is unaffected by this update
  (unchanged since `004-eutr-documents` Update 25/26, which already preserve the original extension).
- `sanitizeFolderName` — reused from `@utils/helpers` (already used elsewhere in this codebase for
  folder-name sanitization), not a new utility.

This computed name is used ONLY for the browser download link's `download` attribute — `eutr_documents.Name`
in the DB is never read for comparison/written to, and no other UI (File name column, tooltips, etc.)
changes.

### Non-goals confirmed (Update 33)

- No new backend endpoint, controller, entity, table, migration, DTO, or authorization policy.
- No change to `eutr_documents.Name`/`eutr_references` — this update is purely about what file name the
  browser saves the downloaded file as, computed fresh on each download.
- No change to Upload/Edit/View button gating (Update 29/30) — the new Download button is ungated,
  matching the existing View button's visibility rule.
- Applies identically to `012-eutr-purchase-orders` (`PurchaseOrderViewPage.jsx`), tracked in that
  feature's own data-model.md/plan.md since it owns a separate copy of this row wiring.

## Update 34/35 (2026-09-29/30): Purchase Order Line (`refType = 20`) becomes the sole row source for both tables; adds `QtyPercent`/`Unit`

> Covers spec FR-198..FR-210. Additive backend change (2 new domain-model properties + 2 new DTO
> properties + 2 new assignment lines in an already-existing `case 20:` block — no new entity class,
> endpoint, or migration). Frontend edits confined to `MapFilePage.jsx`/`ViewSalesOrderPage.jsx` (no new
> file). See research.md Decisions 84-87.

### Entity: Purchase Order Line (reference data, `refType = 20`) — now the ONLY source for Step 1/Selected Purchase Orders

| Field (frontend use) | Source property (D365 entity, `RSVNEutrSalesOrderPurchLines`) | Response DTO property (`ComplDynReferenceResponseDto`) | JSON key (camelCase) | Type |
|---|---|---|---|---|
| PO | `RSVNRefPurchId` | `RSVNRefPurchId` | `rsvnRefPurchId` | string |
| Template | `RSVNEutrTemplate` | `EutrTemplate` | `eutrTemplate` | string |
| Order account | `OrderAccount` | `CustAccount` (pre-existing rename, kept as-is — research.md Decision 87) | `custAccount` | string |
| Vendor name | `Name` | `Name` | `name` | string |
| Variant | `ProductVariant` | `ProductVariant` | `productVariant` | string |
| Material | `ItemId` | `Code` | `code` | string |
| Qty | `Qty` | `Qty` (parsed via `long.TryParse`, defaults to `0`) | `qty` | long |
| Unit **(new, Update 35)** | `Unit` **(new domain-model property)** | `Unit` **(new DTO property)** | `unit` | string |
| Percentage used | `QtyPercent` **(new domain-model property, Update 34)** | `QtyPercent` **(new DTO property, Update 34)** | `qtyPercent` | string |
| Sales Order link (filter key, not rendered) | `InterCompanyOriginalSalesId` | `InterCompanyOriginalSalesId` | `interCompanyOriginalSalesId` | string |

Filtered per Sales Order via `[{ column: 'InterCompanyOriginalSalesId', operator: 'eq', value: salesId }]`
only — unchanged from Update 17 (research.md Decision 64); still one batched call per Sales ID, no
per-PO/per-line call.

**Backend change — 3 files, additive only**:
1. `RSVNEutrSalesOrderPurchLines.cs` (domain model) — `+ public string QtyPercent { get; set; }`,
   `+ public string Unit { get; set; }`. `FilterableFields` unchanged (research.md Decision 86 — that
   dictionary only feeds `ODataFilterBuilder`/`EtdWeekFilterBuilder`'s WHERE/`$orderby` validation, not
   response shape).
2. `ComplDynReferenceResponseDto.cs` — `+ public string QtyPercent { get; set; }`,
   `+ public string Unit { get; set; }`.
3. `ComplDynamicsService.cs`, `MapDynamicsResponse`'s `case 20:` — `+ QtyPercent = x.QtyPercent`,
   `+ Unit = x.Unit`. Every other assignment in this `case` block (`Code = x.ItemId`, `CustAccount =
   x.OrderAccount`, `Qty = long.TryParse(...)`, `ProductVariant`, `EutrTemplate`, `RSVNRefPurchId`) is
   untouched.

### Row grain change: 1 row per record, not 1 row per PO (FR-198)

Before Update 34, both tables rendered 1 row per PO (sourced from `refType=16`), with a *separate*
grouped fetch of `refType=20` joining every matching record's `ItemId`/`ProductVariant` into one
comma-separated cell per PO. From Update 34, both tables render `refType=20`'s raw array directly — 1
API record = 1 table row. A PO with N line records now produces N table rows, each with that record's
own Variant/Material/Qty/Unit/Percentage-used values (no join, no grouping, no dedupe across records).

| Screen | Row-source state | Table-body list | Still-deduped-by-PO list (unchanged consumers) |
|---|---|---|---|
| Map File (`MapFilePage.jsx`) | `poLines` (raw `refType=20` array) | `poLines` (mapped 1:1) | `poList` (`useMemo`, dedupe `poLines` by `purchId`) — feeds Save PO Mapping, `buildReferenceCodes`, `buildPurchIdToTemplateCodeMap` |
| View (`ViewSalesOrderPage.jsx`) | `poLines` (raw `refType=20` array) | `poRows` (`useMemo` — 1 row per `poLines` record matching a saved `purchId`; 1 blank fallback row for a saved `purchId` with zero matching records) | `poList` (`useMemo`, dedupe via new `poInfoByPurchId` map) — feeds header PO chips + "Selected Purchase Orders (N)" count; `purchIdToTemplateCode`/`buildReferenceCodes` now read `poInfoByPurchId` instead of the removed `allPos` |

### Select/disable/Save PO Mapping — unaffected (FR-203)

`selectedPOs` (`Set<purchId>`) and `handleTogglePO(purchId)` in `MapFilePage.jsx` are unchanged — keyed
by PO identity already, not row index, so a PO occupying multiple rows keeps every one of its rows'
checkboxes in sync automatically. The disable condition (`!line.eutrTemplate`) now reads each row's own
`eutrTemplate` field (from `refType=20` directly) instead of the old `refType=16`-sourced `po.eutrTemplate`
— same value in practice, since `RSVNEutrTemplate` is a per-PO D365 attribute replicated onto every line.
`handleSavePOMapping` is unchanged, still building its payload from `poList` (deduped).

### Removed: refType=16 fetch and the grouped-Map state (both screens)

- `EUTR_SALES_ORDER_PURCHASE_REF_TYPE = 16` constant and its `useEffect` — removed from both
  `MapFilePage.jsx` and `ViewSalesOrderPage.jsx` (View's version also removed the `allPos` state it fed).
- `poLinesByPurchId` (`Map<purchId, {materials: string[], variants: string[]}>`) — removed from both
  screens; superseded by the raw `poLines` array.

### Non-goals confirmed (Update 34/35)

- No new entity class, DTO class, controller action, or migration — 2 new properties on 2 already-existing
  backend classes, 2 new assignment lines in an already-existing `case` block.
- No change to `SalesOrderOverviewPage.jsx`'s own, independent `refType=16` usage.
- No change to Step 2, Template Checklist, AVAILABLE FILES, Download, Back, Validation Summary, or any
  permission gating (Update 28/29) on either screen.
- No change to the existing batch-loading mechanism (1 call per Sales ID, no N+1) established by
  Update 17/125 — reused unchanged.
- No change to `case 20:`'s pre-existing `OrderAccount`→`CustAccount` rename (research.md Decision 87) —
  frontend reads `item.custAccount` for this refType's Order account, not `item.orderAccount`.

## Update 37 (2026-09-30): Template tree label shows the mapped file's name once uploaded; download for Type = "PO" documents no longer recomputes the file name as Step Name (frontend-only, no entity/DTO/API change)

### No new entity, field, endpoint, or migration

Both changes are purely client-side rendering/computation decisions over data already available on the
`realAvailableFiles` item shape (`typeName`, `stepNames`, `name`) — no new backend file, DTO, or route.

### Client-side "tree node label" computation (not a DB field)

```
nodeLabel = stripFileExtension(mappedFiles[0].name)   // node has >= 1 mapped file
nodeLabel = node.stepName                             // node has 0 mapped files (unchanged)
```

- `mappedFiles` — already computed per node (`fileMappings[node.id]` resolved against the `files` array
  passed to `TreeNode`), unchanged from before this update.
- `stripFileExtension` — new exported helper in `progressUtils.js`, same regex
  `buildStepOnlyFileName.js` already uses (`name.replace(/\.[^/.]+$/, '')`).
- The existing secondary caption (`mappedFiles[0].name` + `(+N)` badge) and the status-icon tooltip
  (`Đã map: ...`, full names) are unchanged — still show the full stored name including extension.

### Client-side "download file name" computation — now Type-conditional (extends Update 33)

```
downloadFileName = loadedFile.fileName || storedName                          // typeName === 'PO'
downloadFileName = sanitizeFolderName(stepNames[0]) + extensionOf(storedName) // typeName !== 'PO', stepNames non-empty
downloadFileName = storedName                                                 // typeName !== 'PO', stepNames empty
```

- `typeName` — already present on `realAvailableFiles` items (`doc.typeName ?? null`, populated from
  `list-po-references`, added for Update 5) and passed through to `EutrFileViewerDialog` as a new prop
  alongside the existing `stepNames` prop — no new API field.
- For Type = "PO" documents, `storedName`/`loadedFile.fileName` already equals the original uploaded file
  name for any document created after `004-eutr-documents` Update 29 (no rename at Upload time) — the
  Update 33 recompute becomes unnecessary and is skipped for this Type specifically.

### Non-goals confirmed (Update 37)

- No new backend endpoint, controller, entity, table, migration, DTO, or authorization policy.
- No change to `eutr_documents.Name`/`eutr_references` — both changes affect only what's rendered in the
  tree and what file name the browser saves a Type = "PO" download as.
- No change to Type ≠ "PO" download behavior — continues to recompute the file name as Step Name exactly
  as Update 33 left it.
- No change to the "(+N)" badge, the status-icon tooltip, Map status computation, or Upload/Edit/View
  button gating (Update 28/29/30) on either screen.
- Applies identically to `012-eutr-purchase-orders` (`PurchaseOrderViewPage.jsx`), tracked in that
  feature's own data-model.md/plan.md since it owns a separate copy of this row/tree wiring.

## Update 40 (2026-09-30): Template tree toolbar groups by PurchId instead of TemplateCode (frontend-only, no entity/DTO/API change)

### No new entity, field, endpoint, or migration

Purely a client-side regrouping of data already fetched by existing calls (`eutr_purchase_attachments`
via `GetPurchaseAttachmentsBySalesIdUseCase`, template detail trees via `GetPagingEutrTemplatesUseCase`/
`GetEutrTemplatesUseCase`, documents via `GetEutrDocumentsPoReferencesUseCase`) — no new backend file,
DTO, or route.

### Client-side "per-PO template entry" shape (not a DB table — derived in-memory)

```
poTemplates: [{
  purchId,            // from eutr_purchase_attachments (deduped — 1 entry per unique PurchId)
  templateCode,        // that PO's own TemplateCode (eutr_purchase_attachments.TemplateCode)
  templateName,         // looked up from templatesData (already fetched, deduped by templateCode)
  orderAccount,          // that PO's own Vendor code (from poList/poInfoByPurchId), or null
  flatDetails,             // that template's step list — same object as templatesData's entry (shared
                            //   reference across every PO using the same template; not duplicated data)
  tree,                     // flatToTree(flatDetails) — same sharing as flatDetails
}]
```

- 1 element per unique `purchId` — NOT deduped by `templateCode`. 2 POs sharing 1 template produce 2
  separate `poTemplates` entries, each with its own `purchId`/`orderAccount` but pointing at the SAME
  `flatDetails`/`tree` object reference (no extra template-detail fetch or duplication — `templatesData`
  is still fetched once per unique `templateCode`).
- `buildPoTemplateComputations(poTemplates, files)` (new, `progressUtils.js`) computes 1
  Mapped/Missing/file-list result per `poTemplates` entry, filtering `files` to `f.poCode === purchId ||
  f.poCode === orderAccount` — that PO's own documents only, never another PO's, even when both PO's
  documents would otherwise match the same shared `flatDetails`/step names.

### Non-goals confirmed (Update 40)

- No new backend endpoint, controller, entity, table, migration, DTO, or authorization policy.
- No change to `eutr_purchase_attachments`, `eutr_documents`, or `eutr_references` — this is a display/
  computation regrouping only.
- No change to `SalesOrderOverviewPage.jsx`/`PurchaseOrderOverviewPage.jsx`'s Progress column (still uses
  the unchanged, per-row `buildTemplateComputations`) or `012-eutr-purchase-orders`'s `PurchId/View`
  (single-PO page, no grouping concept applies).
- No change to the Download button's "Combined All" zip format (still built from the unchanged
  `defaultTemplate`/`allChipTree`/`allChipDerivedFileMappings`/`allChipFiles` computation stack,
  independent of the toolbar's tab selection) — only the "By Template" format's folder grouping changes
  (1 folder per PO instead of 1 per TemplateCode, to avoid dropping a second PO's files when 2 POs share
  a template — see research.md Decision 93).

## Update 42 (2026-09-30): New table `eutr_progression` (precomputed Total/Missing/Finished); Overview's Progress column reads it via JOIN instead of the dynamic 3-4-call/client-loop computation; `test-so-template-sync` also persists `ProductVariant`/`ItemId`

### New entity: Progression (`eutr_progression`) — precomputed cache, not a source of truth

```sql
CREATE TABLE eutr_progression (
    Id        INT IDENTITY(1,1) PRIMARY KEY,
    SalesId   VARCHAR(50) NOT NULL,
    Total     INT NOT NULL,
    Missing   INT NOT NULL,
    Finished  INT NOT NULL,
    CreatedBy    VARCHAR(100) NULL,
    CreatedDate  DATETIME NULL,
    UpdatedBy    VARCHAR(100) NULL,
    UpdatedDate  DATETIME NULL
);
CREATE UNIQUE INDEX IX_eutr_progression_SalesId ON eutr_progression (SalesId);
```

- 1 row per `SalesId` that has ever been recomputed (upsert — delete/replace the existing row's
  `Total`/`Missing`/`Finished`, not an append-only history table). `SalesId` with no row = "never
  recomputed yet" (Overview shows the empty state, FR-228), distinct from a row that exists with
  `Total = 0` ("no required steps", FR-084/FR-228 unchanged).
- `Total`/`Missing`/`Finished` MUST be computed with the exact same formula `computeProgress()`/
  `buildTemplateComputations()` already use (`progressUtils.js:37-84`, FR-077 to FR-079): `Total` = the
  count of steps across every `(PurchId, TemplateCode)` pair in `eutr_purchase_attachments` for that
  `SalesId` where `requirementType = Required` and `takeFrom` is not in `AUTO_SOURCES`; `Finished` = of
  those, the count with ≥1 matched document (same PO/Template-scoped matching rule as FR-055/FR-056);
  `Missing = Total - Finished`.
- Entity class: `ComplianceSys.Domain.Entities.EutrProgression` — mirrors `EutrPurchaseAttachments.cs`'s
  shape (`Id`, plus `BaseEntity`'s `CreatedBy`/`CreatedDate`/`UpdatedBy`/`UpdatedDate`).
- Migration file: next sequential number after `32_add_productvariant_itemid_to_eutr_purchase_attachments.sql`
  in `compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Migration/` (i.e. `33_...`), per this
  repo's convention that every schema change ships as a new numbered migration file (not an edit to an
  existing one).

### Recompute: 1 service method, 4 call sites (no new dynamic-calc logic — reuses the existing formula)

A single `IEutrProgressionService.RecomputeAsync(string salesId, ct)` (exact naming a plan-time
decision) re-reads `eutr_purchase_attachments` + matched documents for that one `SalesId`, recomputes
`Total`/`Missing`/`Finished` with the unchanged formula, and upserts the `eutr_progression` row. Called
from exactly 4 places (FR-225):

1. **View screen load** — `GET /eutr/sales-orders/:salesId/view` data-fetch path (the existing
   `useEffect` keyed on `salesId` in `ViewSalesOrderPage.jsx` that already calls
   `GET /api/eutr-purchase-attachments/by-sales-id/{salesId}`) — recompute happens server-side as part
   of (or immediately after) that same request, scoped to the 1 `salesId` in the URL.
2. **Save PO Mapping** — `EutrPurchaseAttachmentsService.SavePoMappingAsync` (called from
   `POST /api/eutr-purchase-attachments/save-po-mapping`), after the existing delete-then-reinsert
   transaction commits — recompute uses the NEW PO list just saved, not the list before the delete.
3. **`test-so-template-sync`** — `EutrSynchronizeDataService.SyncSalesOrderTemplatesAsync`, after the
   existing per-row add/skip loop finishes — recompute runs once per `SalesId` the run ADDED
   (`summary.Added`) only. **Revised during implementation** (research.md Decision 99): the original
   design recomputed for skipped-as-already-existing `SalesId`s too, but this job has processed
   thousands of rows per run on real data — recomputing every one (each a `IEutrTemplatesService` call +
   1 D365 refType=16 round trip + `IEutrDocumentsService` call) would turn the sync job itself into a
   new performance bottleneck, defeating this Update's purpose. Skipped `SalesId`s stay correct via
   trigger 4 (their documents changing already recomputes them directly) and the one-time backfill.
4. **Upload/Delete a document of Type = "PO" in Map File Step 2** (feature `004-eutr-documents`'s
   `EutrUploadService.UploadMultipleToSharePointAndSaveDataAsync`/`UploadMultipleForReferenceTypeAsync`
   and `EutrDocumentsService.DeleteAsync`/`DeleteMultiAsync`) — recompute the `SalesId`(s) whose
   `eutr_purchase_attachments.PurchId` matches the document's `RefValue`, after the upload/delete
   succeeds. **Known gap**: documents of Type = "Vendor" (`RefValue` = Order account, matching every PO
   of that vendor) do not trigger recompute — would need an extra D365 refType=16 lookup by Order
   account to resolve back to PurchIds, not implemented in this Update.

### `eutr_purchase_attachments` write path — `test-so-template-sync` now also sets `ProductVariant`/`ItemId`

`EutrSynchronizeDataService.SyncSalesOrderTemplatesAsync` (`EutrSynchronizeDataService.cs:143-152`),
insert branch, changes from:

```csharp
await _genericRepository.AddAsync(new EutrPurchaseAttachments
{
    SalesId = salesId,
    PurchId = purchId,
    TemplateCode = templateCode,
    CreatedBy = "system", CreatedDate = now, UpdatedBy = "system", UpdatedDate = now
}, ct);
```

to additionally set `ProductVariant = item.ProductVariant` (field already exists on
`ComplDynReferenceResponseDto`, currently only populated for refType=15) and `ItemId = item.ItemId`
(new field — needs adding to `ComplDynReferenceResponseDto` and to the refType=19 mapping in
`ComplDynamicsService`, if D365's refType=19 payload carries an equivalent source field). The existing
dedupe (`existingSalesIds.Add(salesId)` — skip the entire `SalesId` if it already has any row) is
unchanged; rows inserted before this Update keep `ProductVariant`/`ItemId = NULL` (not backfilled
retroactively by this job).

### Overview's Progress column — read path changes from 4 dynamic calls to 1 JOIN

`SalesOrderOverviewPage.jsx`'s `fetchProgressForRows` (previously: `by-sales-ids-raw` +
`by-codes` + `refType=16` + `list-po-references`, then client-side `buildTemplateComputations`/
`computeProgress` loop, `progressUtils.js:37-84`) is replaced by a single batched read keyed on the
visible page's `SalesId`s:

```sql
SELECT SalesId, Total, Missing, Finished FROM eutr_progression WHERE SalesId IN (@salesIds);
```

exposed as a new endpoint (naming a plan-time decision, e.g.
`POST /api/eutr-progression/by-sales-ids`) returning `ProgressionDto { SalesId, Total, Missing,
Finished }[]`. Client maps this to the same `{ status: 'empty' | 'no-required' | 'ok', completed,
total, pct }` shape `fetchProgressForRows` already produces (`completed` = `Finished`, `pct =
round(Finished/Total*100)`), preserving the existing empty/no-required/ok/error states (FR-228) — a
`SalesId` missing from the response = `empty`; present with `Total = 0` = `no-required`; present with
`Total > 0` = `ok`.

### Non-goals confirmed (Update 42)

- `ViewSalesOrderPage.jsx`/`MapFilePage.jsx` keep their existing per-step dynamic computation
  (`requiredDetails`/`mappedRequired`/`missingRequired`, FR-062/FR-077 to FR-081) unchanged — they need
  step-level detail `eutr_progression`'s 3 counters cannot provide (FR-229). `eutr_progression` is read
  ONLY by Overview's Progress column.
- No change to `012-eutr-purchase-orders`'s own Progress column/computation — out of scope (that feature
  has its own equivalent, not covered by this Update; see spec Clarifications for the explicit scoping
  precedent set in Update 41).
- `test-so-template-sync`'s existing dedupe-by-`SalesId` behavior is unchanged — this Update does not
  add a path to retroactively backfill `ProductVariant`/`ItemId` on rows the job already inserted before
  this Update, nor does it change which rows the job inserts vs. skips.
- One-time historical backfill of `eutr_progression` for every `SalesId` already in
  `eutr_purchase_attachments` before this Update ships (FR-230) is a rollout/operational step (e.g. a
  one-off script or admin endpoint run once at deploy time), not a new recurring trigger — a plan-time
  decision on exact mechanism.

## Update 43 (2026-09-30): New refType=21 (`RSVNSalesLineOpenInvoiceCogs`) for ItemId/ConfigId search; new AND-search bucket for a derived SalesId list

### D365 entity registration: `RSVNSalesLineOpenInvoiceCogs` → refType 21

The domain class already exists (`ComplianceSys.Domain/Dynamics/RSVNSalesLineOpenInvoiceCogs.cs`) with
`SalesId`, `ItemId`, `ConfigId` properties, but does not extend `RSVNModelBase` — used today only via
direct `_paramManager`/`_dynamicService` calls in `ComplSynchronizeDataService`/`DynamicsDataService`
(unrelated features). Update 43 adds:

```csharp
public class RSVNSalesLineOpenInvoiceCogs : RSVNModelBase
{
    public override int ModelType => 21;
    public override string EntityName => "RSVNSalesLineOpenInvoiceCogs";
    public override Dictionary<string, string> FilterableFields => new()
    {
        { "ItemId", "ItemId" },
        { "ConfigId", "ConfigId" },
        { "SalesId", "SalesId" },
    };
    // existing properties (SalesId, SalesStatus, ItemId, InventDimId, ConfigId, AreaId, ...) unchanged
}
```

`ComplDynamicsService.cs`'s `EntityMappings` dictionary gets a new entry:
`{ 21, ("RSVNSalesLineOpenInvoiceCogs", "SalesId", "ItemId") }` (CodeColumn/NameColumn follow the
existing convention even though this refType is queried by `ItemId`/`ConfigId`, not `Code`/`Name` —
those two columns are never used for this refType's own filters, only `MapDynamicsResponse`'s new
`case 21` needs them for the response DTO shape).

`MapDynamicsResponse`'s new `case 21`:
```csharp
case 21:
    responseItems = items.ToObject<List<RSVNSalesLineOpenInvoiceCogs>>()
        ?.Select(x => new ComplDynReferenceResponseDto
        {
            Id = x.SalesId,
            Code = x.SalesId,
            ItemId = x.ItemId,
        })
        .ToList() ?? new();
    break;
```

`ComplDynReferenceResponseDto` gets a new `ConfigId` field (mirrors the `ItemId` field already added in
Update 42) if the caller needs it echoed back — not required for the SalesId-extraction use case itself
(only `Code`/`Id` = `SalesId` matters), but kept for forward-consistency/debuggability alongside `ItemId`.

### New `BuildFilterString` bucket: `"salesidin"` (AND-search, entity-scoped)

```csharp
// inside the existing switch (ComplDynamicsService.cs:196-203)
"salesidin" when mapping.Entity == "RSVNSalesOrderOpenInvoiceCogs" => "salesidin",
```

Unlike `"custaccount"`/`"vendorcode"` (which push into the shared `searchFilters` OR-group, merged with
the main keyword search), `"salesidin"` entries are collected into their **own** list
(`salesIdInFilters`), OR-joined into their own `(SalesId eq 'A' or SalesId eq 'B' or ...)` clause, and
that clause is added directly to `filterParts` (AND-combined with everything else) — see research.md
Decision 103 for why merging into `searchFilters` would be wrong here (opposite narrowing semantics).

### Frontend: 2-sequential-call flow (no new backend endpoint)

`SalesOrderOverviewPage.jsx`'s `fetchSalesOrders`/`handleSearchClick`: when `itemId`/`configId` state
has a value, first call `getReferenceDataUseCase.execute(1, 500, 'Code', 'asc', 21, [
  ...(itemId ? [{column:'ItemId', operator:'eq', value:itemId}] : []),
  ...(configId ? [{column:'ConfigId', operator:'eq', value:configId}] : []),
])`, extract distinct `Code` values (= `SalesId`s) from the response; if empty, short-circuit to the
existing empty-state render (FR-234) without calling refType=11 at all. Otherwise, add
`salesIds.map(id => ({column:'SalesIdIn', operator:'eq', value:id}))` to the existing
`[...buildSearchFilters(searchValue), ...etdFiltersRef.current]` array before calling
`getReferenceDataUseCase.execute(..., EUTR_SALES_ORDER_REF_TYPE, combinedFilters)` — same call site as
today (`fetchSalesOrders`, no new use case needed beyond the existing `GetReferenceDataUseCase`).

### Non-goals confirmed (Update 43)

- No new local MySQL table, no migration — this Update is entirely a D365/OData query extension plus a
  backend filter-string helper, consistent with how Update 24/27's Year/ETD Week/CustAccount search were
  implemented (pure `ComplDynamicsService`/frontend changes, no local storage).
- No new backend endpoint/controller — reuses `POST /api/dynamics/reference` (generic) for both the new
  refType=21 lookup and the existing refType=11 query.
- `eutr_progression`/`EutrProgressionService` (Update 42) is untouched — ItemId/ConfigId search is a
  purely orthogonal filter on which Sales Orders the Overview list itself shows; it does not change how
  Progress is computed or read for whichever rows end up displayed.

## Update 44 (2026-10-05): Remove AVAILABLE FILES pagination (FR-236, no entity/DTO/API change)

No data-model change. Client-only view state `filePage` is removed; the file list model is unchanged.

## Update 45 (2026-10-05): sales-line grouping for Step 1 / View (no DB change)

- `RSVNSalesLineOpenInvoiceCogs` (D365, domain): + `ProductName: string`, + `ProductDescription: string`.
- `ComplDynReferenceResponseDto`: + `ProductName`, + `ProductDescription` (null for every refType except 21).
- Client view-model `SalesLineGroup { key = `itemId-configId` (or `itemId`), compared to PO `variant` (ProductVariant), itemId, configId, productName, productDescription, pos: PoLine[] }` plus a synthetic `others` group; `PoLine` is the existing `poLines` item (purchId, name, orderAccount, eutrTemplate, variant, material, qty, unit, qtyPercent). Validation: key normalized trim+lowercase; PO assigned to exactly one group.
- State: `expandedGroups: Set<key>` (UI only, default empty = all collapsed). View derives `savedLineKeys` from `purchaseAttachments` for the locked Select column. No change to `eutr_purchase_attachments` or `selectedPOs`.

**(Update 45 — chỉnh lần cuối)**: Thay thế các mục trên — `RSVNEutrSalesOrderPurchLines` (D365): + `ProductName`, + `ProductDescription`; `ComplDynReferenceResponseDto.ProductName/ProductDescription` nay gán ở refType=20. `RSVNSalesLineOpenInvoiceCogs` KHÔNG đổi. View-model `{ key = variant chuẩn hóa, variant, productName, productDescription, pos[] }`; không còn nhóm "Other purchase orders".


## Update 46 (2026-10-07): groups from `RSVNEutrOpenSalesLines` (no DB change)

- `RSVNEutrOpenSalesLines` (D365, domain, refType 22): `SalesId`, `ItemId`, `configId`, `Name`, `Description` — đã có.
- `ComplDynReferenceResponseDto`: refType=22 gán `Id/Code = SalesId`, `ItemId`, `ConfigId = configId`, `Name`, `Description` (+ trường `Description` nếu chưa có).
- Client view-model `SalesLineGroup { key = itemId-configId (hoặc itemId), itemId, configId, name, description, pos: PoLine[] }` + nhóm cuối "—" cho PO không khớp. `PoLine` giữ nguyên. `expandedGroups: Set<key>` chỉ là state UI (mặc định rỗng = thu gọn). Không đổi `eutr_purchase_attachments`/`selectedPOs`.
