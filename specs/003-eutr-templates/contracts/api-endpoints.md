# API Contracts: EUTR Templates Management

**Feature**: 003-eutr-templates | **Date**: 2026-07-03
**Base URL**: `api/eutr-templates`
**Auth**: Policy-based (`EutrTemplates.{Action}`)

**Update 13 (2026-07-13)**: `vendorCode`/`vendorName` removed from every `api/eutr-templates`
request/response shape below (no migration of existing values); the `IsDefault` constraint changes
from per-`VendorCode` to global; Import/Export Excel column layouts shift left by one column. A new
`api/eutr-template-references` contract (Section 9) is added for the Apply-to-Customer feature.

---

## 1. Get Paged List

```
POST api/eutr-templates/get-all
```

**Request Body** (PagedRequest):
```json
{
  "page": 1,
  "pageSize": 25,
  "sortColumn": "CreatedDate",
  "sortOrder": "DESC",
  "filters": [
    { "field": "Name", "operator": "like", "value": "test" }
  ]
}
```
*(Update 13: the `VendorCode` filter example above is removed — that column no longer exists on
`eutr_templates`.)*

**Request Body — TemplateListPage search box (Update 11, 2026-07-13)**:
```json
{
  "page": 1,
  "pageSize": 100,
  "sortColumn": "Id",
  "sortOrder": "asc",
  "filters": [
    { "field": "Keyword", "operator": "like", "value": "temp" }
  ]
}
```
A `Keyword` filter entry expands server-side to `(Code LIKE @value OR Name LIKE @value)` instead of
being mapped to a single SQL column — see Notes below. Sent by `TemplateListPage.jsx`'s search box,
debounced, replacing (not combined with) any other filter entries; the frontend resets `page` to 1
whenever the keyword changes.

**Response** (PagedResult):
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": 1,
        "code": "Templates-001",
        "name": "Template A",
        "alertFor": 3,
        "alertForName": "Compliance Alerts Group",
        "isDefault": 1,
        "versionId": 2,
        "stepsCount": 4,
        "createdBy": "user@email.com",
        "createdDate": "2026-07-03T10:00:00"
      }
    ],
    "totalCount": 50,
    "page": 1,
    "pageSize": 25
  }
}
```
*(Update 13: `vendorCode`/`vendorName` fields removed from this response — no longer applicable.)*

**Notes**:
- Filters implicitly include `WHERE IsDeleted = 0 AND IsHide = 0`
- **Update 7 (2026-07-07)**: `alertFor` is now the numeric Id of a row in `compl_group_email`
  (was a free-text string). `alertForName` (new field) is resolved via `LEFT JOIN compl_group_email`
  on `alertFor` and is what the grid displays.
- **Update 11 (2026-07-13)**: `stepsCount` (new field) is a real per-template count —
  `SELECT COUNT(*) FROM eutr_template_details d WHERE d.TemplateId = t.Id` — used by
  TemplateListPage's Steps column. `Keyword` is a special-cased filter field (see request example
  above) expanding to an OR condition across `Code` and `Name`; it is not a real column and has no
  entry in the sortable-columns list below. **Update 13**: FR-042 flags this field as a
  user-reported display bug despite the query/response being verified correct end-to-end — see
  plan.md's Steps-Count Investigation section; no contract change results from that item unless a
  concrete defect is found during verification.
- Sortable columns: Code, Name, AlertFor, IsDefault, VersionId, CreatedBy, CreatedDate *(Update 13:
  `VendorCode` removed from this list)*
- Filterable columns: Code, Name, AlertFor (Update 7: the `AlertFor` filter now matches against the
  joined `compl_group_email.Name`, not the raw Id, since a numeric Id isn't a meaningful text-search
  target), Keyword (Update 11: pseudo-column, OR across Code and Name — see above; used only by
  TemplateListPage's search box, not exposed as a sortable/visible column) *(Update 13: `VendorCode`
  removed from this list)*

---

## 2. Get By ID (with Details)

```
GET api/eutr-templates/{id}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "id": 1,
    "code": "Templates-001",
    "name": "Template A",
    "alertFor": 3,
    "alertForName": "Compliance Alerts Group",
    "isDefault": 1,
    "versionId": 2,
    "createdBy": "user@email.com",
    "createdDate": "2026-07-03T10:00:00",
    "details": [
      {
        "id": 10,
        "templateId": 1,
        "parentId": 0,
        "stepId": 5,
        "stepName": "Forest Management",
        "requirementType": 1,
        "takeFrom": 0,
        "displayOrder": 0
      },
      {
        "id": 11,
        "templateId": 1,
        "parentId": 10,
        "stepId": 8,
        "stepName": "Certification Check",
        "requirementType": 0,
        "takeFrom": 1,
        "displayOrder": 0
      }
    ]
  }
}
```

**Notes**:
- Details include `stepName` from JOIN with `eutr_steps`
- Tree structure is flat (parent-child via `parentId`); frontend builds the tree
- **Update 10 (2026-07-13)**: this endpoint is called by `TemplateBuilderPage.jsx` (via the
  existing `GetEutrTemplatesUseCase`) instead of `EutrTemplatesAddEdit.jsx` — no contract change,
  same response shape consumed the same way (header fields + `details` fed into `useStepTree`'s
  `loadFromServer`)
- No `stepsCount` field on this single-record response (it's a list-only convenience field —
  see Section 1); the Edit screen already has the full `details` array to derive a count from if
  ever needed

---

## 3. Create Template

```
POST api/eutr-templates
```

**Request Body** (full shape — Update 13: `vendorCode` field removed from the payload entirely):
```json
{
  "name": "Template A",
  "alertFor": 3,
  "isDefault": 1,
  "details": [
    {
      "parentId": 0,
      "stepId": 5,
      "stepName": "Forest Management",
      "requirementType": 1,
      "takeFrom": 0,
      "displayOrder": 0
    },
    {
      "parentId": 0,
      "stepId": null,
      "stepName": "New Custom Step",
      "requirementType": 0,
      "takeFrom": 1,
      "displayOrder": 1
    }
  ]
}
```

**Frontend usage (Update 9, 2026-07-13)**: the `CreateTemplateDialog.jsx` quick-create dialog
(Name, Alert for, Set as default only — no Vendor field, no step tree) always sends the minimal
form of this same payload:
```json
{
  "name": "Template A",
  "alertFor": 3,
  "isDefault": 1,
  "details": []
}
```
`details` was already allowed to be an empty array — no change there. **Update 13**: the dialog no
longer sends `vendorCode: null` (that field no longer exists on the DTO at all). The first steps
are added afterwards via `PUT api/eutr-templates/{id}` (Section 4) from the Edit screen; Vendor is
no longer set on the template at all — it's applied separately via `api/eutr-template-references`
(Section 9).

**Response**:
```json
{
  "success": true,
  "data": { "id": 1, "code": "Templates-001" },
  "message": "Template created successfully."
}
```

**Behavior**:
- `Code` auto-generated by backend (not accepted from client)
- `VersionId` set to 1
- `IsDeleted = 0`, `IsHide = 0`
- If `IsDefault = 1`: clears existing default **globally** across all templates (Update 13 — was
  "for same VendorCode" before VendorCode was removed)
- `parentId` in details: 0 = root; for child steps, use a temporary client-side ID scheme — backend resolves parent references after inserting root steps first
- Validation: Name required; AlertFor required (must be a positive Id — **Update 7**: no longer a
  free-text string, not validated for existence in `compl_group_email`); each detail requires
  `stepId` OR a non-blank `stepName`
- **Free-solo step resolution (Update 6)**: `stepName` is always sent by the frontend (mirrors the
  selected/typed Step combobox value); the backend only consults it when `stepId` is `null`. For
  such details, the backend matches `stepName` (trimmed, case-insensitive) against `eutr_steps`;
  if found, that step's Id is used; if not found, a new `eutr_steps` row is created and its Id is
  used. Multiple unresolved details sharing the same new name in one request resolve to a single
  created row (no duplicates). The newly-created step is immediately visible in the
  001-eutr-steps screen.

---

## 4. Update Template (Conditional Versioning)

```
PUT api/eutr-templates/{id}
```

**Request Body**: Same structure as Create.

**Response** (row is ≥24h old — new version created):
```json
{
  "success": true,
  "data": { "id": 2, "code": "Templates-001", "versionId": 3 },
  "message": "Template updated successfully."
}
```

**Response** (row is <24h old — updated in place):
```json
{
  "success": true,
  "data": { "id": 1, "code": "Templates-001", "versionId": 1 },
  "message": "Template updated successfully."
}
```
Note: `id` and `versionId` are unchanged from before the update in this case.

**Behavior**:
- Backend computes `(DateTime.UtcNow - existing.CreatedDate)` for the row being updated:
  - **≥ 24 hours**: creates a NEW row with `VersionId = old + 1`, same `Code`; old row set
    `IsHide = 1`; details inserted fresh under the new template ID; returns the new row's ID
    and version.
  - **< 24 hours**: updates the EXISTING row in place — same `Id`, same `VersionId`,
    `CreatedDate` unchanged; details for the current template ID are replaced (deleted and
    re-inserted); returns the same ID and version.
- If `IsDefault = 1`: clears existing default **globally** across all templates (Update 13; applies
  in both branches, using the current effective ID)
- Free-solo step resolution (see Create Template, Update 6) applies identically in both branches
- **Update 10 (2026-07-13)**: this endpoint is now called by `TemplateBuilderPage.jsx`'s Save
  button (via the existing `UpdateEutrTemplatesUseCase`) instead of `EutrTemplatesAddEdit.jsx` — no
  contract change, same request/response shape; on success the frontend navigates back to
  `/eutr/templates` (unchanged existing behavior)
- **Update 12 (2026-07-13)**: `TemplateBuilderPage.jsx`'s Add Root Group / Add Child Step dialogs
  now let the user tick multiple master steps (plus optionally type one new free-solo step name)
  and add them all to the tree in a single UI action instead of one at a time — this only changes
  how many `details[]` entries `flattenForSave()` produces per user interaction before the existing
  Save click; the request body shape, per-detail fields (`stepId`/`stepName`/`parentId`/
  `requirementType`/`takeFrom`/`displayOrder`), and free-solo step auto-create resolution (Update 6)
  are all unchanged. No contract change.

---

## 5. Delete Template (Soft)

```
DELETE api/eutr-templates/{id}
```

**Response**:
```json
{
  "success": true,
  "message": "Template deleted successfully."
}
```

**Behavior**:
- Sets `IsDeleted = 1` on the visible row (IsHide=0) only
- Old hidden versions (IsHide=1) are not affected
- **Update 10 (2026-07-13)**: called by `TemplateListPage.jsx`'s per-row Delete icon (via the
  existing `DeleteEutrTemplatesUseCase`) — no contract change

---

## 6. Delete Multiple Templates (Soft)

```
DELETE api/eutr-templates
```

**Request Body**:
```json
{
  "ids": [1, 3, 5]
}
```

**Response**:
```json
{
  "success": true,
  "message": "Templates deleted successfully."
}
```

**Update 10 (2026-07-13)**: called by `TemplateListPage.jsx`'s new bulk-delete toolbar button (via
the existing `DeleteMultiEutrTemplatesUseCase`) — the Table layout previously had no per-row
checkbox/bulk-select affordance; no contract change.

---

## 7. Import Templates

```
POST api/eutr-templates/import
Content-Type: multipart/form-data
```

**Request**: Form field `file` with `.xlsx` file.

**Expected Excel columns** (row 1 = header, data from row 2) — **Update 13: layout shifts left by
one column, `VendorCode` column removed**:

| A | B | C |
|---|---|---|
| Name | AlertFor | IsDefault |

*(Corrected/previously: `A=Name, B=AlertFor, C=VendorCode, D=IsDefault` before Update 13 — this
table had drifted from the actual `EutrTemplatesImportService.cs` cell-read order, which reads
`B=AlertFor` before `C=VendorCode`; fixed while updating for Update 13.)*

**Update 7 (2026-07-07)**: Column B (AlertFor) expects the Alert group's **Name** (text, matched
against `compl_group_email` where `GroupType = 2`) instead of arbitrary free text.

**Response**:
```json
{
  "success": true,
  "data": {
    "totalRows": 10,
    "successCount": 8,
    "failCount": 2,
    "errors": [
      { "row": 3, "message": "Name is required." },
      { "row": 7, "message": "Alert for is required." },
      { "row": 9, "message": "Alert for group not found." }
    ]
  }
}
```

**Behavior**:
- Code auto-generated per row
- VersionId = 1 for all imported records
- Validation: Name required; AlertFor required and MUST match an existing Alert group's Name
  (exact match against `compl_group_email.Name` where `GroupType = 2`) — unlike the free-solo Step
  combobox, unmatched names are NOT auto-created; the row fails with "Alert for group not found."
- Partial import: valid rows succeed, invalid rows reported

---

## 8. Export Templates

```
GET api/eutr-templates/export
```

**Response**: Binary file download (`application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`)

**Excel columns**: Code, Name, AlertFor, IsDefault, Version *(Update 13: `VendorCode` column
removed — was `Code, Name, VendorCode, AlertFor, IsDefault, Version` before Update 13; remaining
columns shift left by one)*

**Update 7 (2026-07-07)**: The "AlertFor" column now writes the resolved group **Name**
(`AlertForName`, via the same `LEFT JOIN compl_group_email` used by the list endpoint) instead of
the raw Id, so a re-imported export file continues to match Import's expected Name format.

---

## D365 Vendor Lookup

**Update 5 (2026-07-06)**: Vendor lookup MUST use the generic reference endpoint below with
`refType = 13`. The dedicated `GET api/dynamics/vendors` endpoint from Update 2/3 still exists in
`DynController` but is superseded for this feature — see the "Superseded" subsection at the end
for historical reference.

**Update 13 (2026-07-13)**: This lookup is no longer used by `api/eutr-templates` at all (the
Vendor field was removed from that entity). It is now used exclusively by the new
`api/eutr-template-references` endpoints (Section 9) — same contract, same `refType=13`, just a
different consumer entity.

```
POST api/dynamics/reference?page=1&pageSize=50&sortColumn=&sortOrder=asc&refType=13
Content-Type: application/json

[]
```

**Query Parameters**:

| Param      | Type   | Default | Description                                   |
|------------|--------|---------|------------------------------------------------|
| page       | int    | 1       | 1-based page number                            |
| pageSize   | int    | 10      | Records per page                               |
| sortColumn | string | null    | Column to sort by                              |
| sortOrder  | string | "asc"   | `asc` or `desc`                                |
| refType    | int    | 1       | Reference type — `13` = D365 VendorsV3         |

**Body**: `List<FilterRequest>` (search filters, e.g. by vendor code/name) — may be an empty array.

**Response** (`ComplDynReferenceResponseDto`, mapped from D365 `VendorsV3` when `refType=13`):
```json
{
  "success": true,
  "message": "Retrieved page 1 of categories successfully. Total records: 2",
  "data": {
    "items": [
      { "id": "V001", "code": "V001", "name": "Vendor Corp" },
      { "id": "V002", "code": "V002", "name": "Supplier Inc" }
    ],
    "totalCount": 2
  }
}
```

**Notes**:
- `Id` and `Code` are both `VendorAccountNumber`; `Name` is `VendorOrganizationName`
  (`ComplDynamicsService`, `case 13` mapping — already implemented, no backend change needed).
- Frontend consumes this via `ReferenceObjectAutocomplete` (`referenceType={13}`) or the
  underlying `useReferenceObjects` hook — the same components used by other reference fields in
  the codebase.

## Alert For Group Lookup (Update 7, 2026-07-07)

The Alert for combobox on Add/Edit and the grid's `alertForName` column are backed by the existing
group-email feature — no new backend endpoint is introduced.

```
GET api/group-email
```

**Response** (`ComplGroupEmail[]`, from `ComplGroupEmailController.GetAll`):
```json
{
  "success": true,
  "message": "Get all groups successfully",
  "data": [
    { "id": 3, "name": "Compliance Alerts Group", "groupType": 2, "isDefault": false, "isAddition": false },
    { "id": 5, "name": "Responsible Team", "groupType": 1, "isDefault": true, "isAddition": false },
    { "id": 7, "name": "Extra Alert Addresses", "groupType": 2, "isDefault": false, "isAddition": true }
  ]
}
```

**Notes**:
- The frontend calls this once (via `GetAllGroupEmailUseCase.execute()` /
  `repositories.groupEmail`, already used by `ComplianceMasterForm.jsx` / `MasterDefaultForm.jsx`)
  and filters client-side to `groupType === 2` (Alert) and `isAddition === false` — same convention
  those forms already use. In the example above, only `{ id: 3, name: "Compliance Alerts Group" }`
  would appear in the combobox.
- On Save, the frontend submits the selected group's `id` as `alertFor`.
- The grid's `alertForName` column is resolved server-side via
  `LEFT JOIN compl_group_email g ON g.Id = t.AlertFor` in `EutrTemplatesRepository` — the frontend
  does not need to re-fetch group-email data to render the grid.
- No new backend endpoint, controller, or policy is added; `GET /api/group-email` already exists
  and is authorized under the `GroupEmail.ReadAll` policy — a **different** policy family than
  `EutrTemplates.*`. **Open dependency to verify during implementation**: users who have
  `EutrTemplates.Create`/`Update` but not `GroupEmail.ReadAll` would get a 403 when the Add/Edit
  screen tries to load the Alert for combobox. `ComplianceMasterForm`/`MasterDefaultForm` already
  call this same endpoint successfully, but their user base may not be identical to EUTR Templates
  users — confirm `GroupEmail.ReadAll` is included in the roles that get `EutrTemplates.*` policies
  (same menu/role-seeding step called out in plan.md Principle V), or request a policy grant if not.

### Superseded: Dedicated Vendors Endpoint (Update 2/3, no longer used)

Historical contract, kept for reference only. Still present in `DynController` but not called by
this feature after Update 5:

```
GET api/dynamics/vendors?skip=0&top=50&filter=&order_by=
```

Returned raw OData from D365 VendorsV3 with `$select=dataAreaId,VendorAccountNumber,VendorOrganizationName`
applied (3 columns only): `{ "value": [{ "dataAreaId", "VendorAccountNumber", "VendorOrganizationName" }] }`.

---

## 9. Apply to Customer — EutrTemplateReferences (new, Update 13)

**Base URL**: `api/eutr-template-references`
**Auth**: Policy-based (`EutrTemplateReferences.{Action}` — new policies, verify wiring during
`/speckit-implement`, same open-dependency treatment as `GroupEmail.ReadAll` in Update 7)

### 9.1 Get Mappings by Template

```
GET api/eutr-template-references/by-template/{templateId}
```

**Response**:
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "templateId": 5,
      "vendorCode": "V001",
      "vendorName": "Vendor Corp",
      "fromDate": "2026-01-01",
      "toDate": "2026-06-30",
      "createdBy": "user@email.com",
      "createdDate": "2026-01-01T09:00:00",
      "updatedBy": "user@email.com",
      "updatedDate": "2026-01-01T09:00:00"
    }
  ]
}
```

**Notes**:
- `vendorName` is a response-only field, resolved via the generic reference API (`refType=13`) —
  same mechanism previously used for `EutrTemplates.VendorName` (Section "D365 Vendor Lookup"
  above), now relocated here.
- No pagination — a single template is expected to have a small number of vendor mappings; ordered
  by `FromDate DESC`.
- Called by `ApplyCustomerPage.jsx` on mount, keyed by the `:id` route param (`/eutr/templates/apply/:id`).

### 9.2 Create Mapping (Apply Vendor)

```
POST api/eutr-template-references
```

**Request Body**:
```json
{
  "templateId": 5,
  "vendorCode": "V001",
  "fromDate": "2026-01-01",
  "toDate": "2026-06-30"
}
```
`toDate` may be omitted/null in the UI (interpreted as unlimited/9999-12-31 before persisting — the
exact persisted sentinel value is a `/speckit-tasks` implementation detail).

**Response**:
```json
{
  "success": true,
  "data": { "id": 1 },
  "message": "Vendor applied successfully."
}
```

**Response — overlap rejected** (FR-036):
```json
{
  "success": false,
  "message": "This vendor already has an overlapping mapping for this template."
}
```

**Behavior**:
- Validation: `vendorCode` required; `fromDate` required; `toDate` (if present) must be ≥ `fromDate`.
- Overlap check: rejects if an existing mapping for the **same `templateId` AND same `vendorCode`**
  has an overlapping `[fromDate, toDate]` range. Overlap for the same vendor across **different**
  templates is explicitly allowed (confirmed decision, FR-036).
- No `Code`/`VersionId` auto-generation — this table has neither.

### 9.3 Update Mapping (Edit)

```
PUT api/eutr-template-references/{id}
```

**Request Body**: Same shape as Create (Section 9.2).

**Response**:
```json
{
  "success": true,
  "message": "Vendor mapping updated successfully."
}
```

**Behavior**: Updates the row in place (no versioning — this table has no `VersionId`). The overlap
check (FR-036) excludes the record being edited (`id`) from the comparison set.

### 9.4 Delete Mapping (Hard Delete)

```
DELETE api/eutr-template-references/{id}
```

**Response**:
```json
{
  "success": true,
  "message": "Vendor mapping removed successfully."
}
```

**Behavior**: Real `DELETE FROM eutr_template_references WHERE id = @id` — this table has no
`IsDeleted`/`IsHide` column, so there is no soft-delete branch (FR-037). Confirmed via
`ConfirmDialog` on the frontend before this call is made.
