# Data Model: EUTR Purchase Orders

This feature introduces **no new database table and no migration**. Every entity below is either
existing ERP reference data (read-only, via the existing `POST /api/dynamics/reference` proxy) or an
existing local entity already owned by a sibling feature (003/004), read through their existing
endpoints. See `research.md` Decisions 1-5 for why each is reused unchanged.

## 1. Purchase Order (ERP reference data, `refType = 15` → `RSVNEutrPurchOrders`)

Source of the list/detail screens' Purch id / Vendor code / Template columns.

| Field (as returned by `ComplDynReferenceResponseDto`) | Source column | Used for |
|---|---|---|
| `Id` / `Code` | `PurchId` | Purch id column; URL param on the detail route (`:purchId`) |
| `Name` | `Name` | PO name (not directly shown as a spec column, but available) |
| `EutrTemplate` | `EutrTemplate` | Template column value; drives the step tree (Decision 3) |
| `OrderAccount` | `OrderAccount` | Vendor code column; key for the Vendor-name lookup (below) |

**Existence check** (detail screen, FR-013/FR-014): a Purch id with no matching row for `refType=15`
(`Code eq {purchId}`) is treated as "Purchase Order không tồn tại."

**No Template** (FR-004/FR-006/FR-019): `EutrTemplate` blank/null, or non-blank but not matching any
row in `003-eutr-templates`, is treated identically — no step tree, no Progress computation
(mirrors `011-eutr-synchronize-data`'s own "Missing template id" treatment of the same condition).

## 2. Vendor (ERP reference data, `refType = 14` → `VendorsV3`)

| Field | Source column | Used for |
|---|---|---|
| `Id` / `Code` | `VendorAccountNumber` | Join key against Purchase Order's `OrderAccount` |
| `Name` | `VendorOrganizationName` | Vendor name column |

Looked up in a batch per visible page (Decision 2), keyed by the distinct `OrderAccount` values on
that page. A Purchase Order whose `OrderAccount` has no matching Vendor row renders Vendor name blank
(FR-003).

## 3. Compliance Template & Step (existing — `003-eutr-templates`, read-only)

Read via the existing `POST /api/eutr-templates/by-codes` (batched by the page's distinct
`EutrTemplate` values) or `GET /api/eutr-templates/{id}`. Fields used, per step
(`eutr_template_details`, unchanged from `003`):

- `StepId` / step name (from `001-eutr-steps`)
- `RequirementType` (Required vs Optional — only Required steps count toward Progress)
- `TakeFrom` (excluded from Progress when it matches the existing `AUTO_SOURCES` set — same rule
  `005`'s `computeProgress` already applies)
- Parent/child structure, for the detail screen's step tree

## 4. Recorded Compliance Document (existing — `004-eutr-documents`, read via `list-po-references`; write via existing Add/Edit dialogs)

| Field | Used for |
|---|---|
| `poCode` (PO value the document is recorded against) | Scoping to the current Purchase Order |
| `stepIds` | Matching against the Template's step tree to compute "has document"/"missing" |
| `typeName`, `fileId`, etc. (existing fields) | AVAILABLE FILES row rendering, File Viewer popup |

Writes (Upload/Edit) go through the existing `EutrDocumentsFormDialog.jsx` popup unchanged — this
feature adds no new write path, no new validation rule beyond what `004-eutr-documents` already
enforces.

## Derived/computed values (not persisted)

- **Progress** (`completed`/`total`/`%`, list + detail screens): `computeProgress(templateDetails,
  fileMappingsForThisPO)` — reused unchanged from `eutr-sales-orders/utils/progressUtils.js`
  (Decision 5). Required steps only, `AUTO_SOURCES` excluded. Special states: "no Template" (no
  computation attempted) and "Template has zero Required steps" (computed but rendered distinctly
  from 0%), per spec FR-006/FR-007.
- **Step "missing" status** (detail screen tree): a step is missing when no document in this PO's
  `list-po-references` result carries that step's `StepId`.

## Entity Relationship (conceptual, no new persisted relationships)

```text
Purchase Order (refType=15)  --OrderAccount-->  Vendor (refType=14)
Purchase Order (refType=15)  --EutrTemplate  -->  Compliance Template (003, by Code)
Compliance Template          --StepId (1..*)  -->  Step (001-eutr-steps)
Recorded Document (004)      --poCode + StepId-->  (Purchase Order, Step) — used to derive Progress
```
