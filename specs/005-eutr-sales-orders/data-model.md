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
