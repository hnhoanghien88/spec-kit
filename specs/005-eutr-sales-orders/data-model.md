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
