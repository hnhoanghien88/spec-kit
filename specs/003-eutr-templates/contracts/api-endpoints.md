# API Contracts: EUTR Templates Management

**Feature**: 003-eutr-templates | **Date**: 2026-07-03
**Base URL**: `api/eutr-templates`
**Auth**: Policy-based (`EutrTemplates.{Action}`)

**Update 13 (2026-07-13)**: `vendorCode`/`vendorName` removed from every `api/eutr-templates`
request/response shape below (no migration of existing values); the `IsDefault` constraint changes
from per-`VendorCode` to global; Import/Export Excel column layouts shift left by one column. A new
`api/eutr-template-references` contract (Section 9) is added for the Apply-to-Customer feature.

**Update 15 (2026-07-15)**: Update Template (Section 4)'s ≥24h branch now also copies
`eutr_template_references` to the new TemplateId (bug fix, FR-049). A new Clone endpoint (Section 10)
is added: `POST api/eutr-templates/{id}/clone` duplicates a template's header, full detail tree, and
full mapping set into a brand-new template.

**Update 16 (2026-07-21)**: New `status` field (`0` (Draft)/`1` (Approved)) on every `eutr_templates`
response shape (Sections 1, 2, 3). Update Template (Section 4) DROPS the 24h-based conditional
versioning entirely — it now REJECTS the request if the template is `Approved`, and otherwise always
updates in place (no more ≥24h new-row branch). Two new no-body endpoints replace that removed
versioning trigger: `POST api/eutr-templates/{id}/approve` and
`POST api/eutr-templates/{id}/request-change` (Section 11) — Request change is what now creates a new
version row, reusing Clone's copy pipeline.

**Update 17 (2026-07-22)**: No contract change. Drag-and-drop step reordering on TemplateBuilderPage
(spec FR-064 to FR-067) is a frontend-only interaction addition — a reordered tree is still submitted
through the exact same Update Template request body (Section 4) as Move Up/Move Down already
produces (each detail row's `displayOrder` recalculated client-side, same field, same shape); no new
endpoint, request field, or response field is introduced by this update.

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
        "status": 0,
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
*(Update 16: `status` — new field, `0` (Draft) or `1` (Approved) — drives the Status Chip and the
Approve/Request change toolbar buttons' enabled state on `TemplateListPage.jsx`.)*

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
    "status": 0,
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
- **Update 16**: `status` (new field) drives `TemplateBuilderPage.jsx`'s read-only gate — when
  `1` (Approved), the page renders a warning banner and disables the header fields, Save, and every
  step-tree action; when `0` (Draft), the page behaves exactly as before this update.

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
  "data": { "id": 1, "code": "Templates-001", "status": 0 },
  "message": "Template created successfully."
}
```
*(Update 16: `status` — new field, always `0` (Draft) for a newly-created template.)*

**Behavior**:
- `Code` auto-generated by backend (not accepted from client)
- `VersionId` set to 1
- **(Update 16)** `Status` set to `0` (Draft) unconditionally — never accepted from the client, even
  if present in the request body
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

## 4. Update Template

**(Renamed in Update 16 — was "Update Template (Conditional Versioning)"; the age-based conditional
described below no longer exists. See Section 11 for where versioning moved to.)**

```
PUT api/eutr-templates/{id}
```

**Request Body**: Same structure as Create.

**Response** (Update 16 — the only success case now: Status was Draft, updated in place):
```json
{
  "success": true,
  "data": { "id": 1, "code": "Templates-001", "versionId": 1, "status": 0 },
  "message": "Template updated successfully."
}
```
Note: `id`, `versionId`, and `status` are unchanged from before the update — this endpoint never
creates a new row or changes `Status` anymore.

**Response** (Update 16 — rejected, Status is Approved):
```json
{
  "success": false,
  "message": "Template is Approved — use Request change before editing."
}
```
HTTP 400, same `ValidationException` → 400 mapping this controller already uses elsewhere.

**Behavior**:
- **(Superseded by Update 16)** ~~Backend computes `(DateTime.UtcNow - existing.CreatedDate)` for the
  row being updated: **≥ 24 hours** → creates a NEW row with `VersionId = old + 1`, old row
  `IsHide = 1`, details inserted under the new template ID; **< 24 hours** → updates the EXISTING row
  in place.~~
- **(Update 16)** First checks `existing.Status`: if `1` (Approved), rejects with a validation error
  (400) — no data is changed. If `0` (Draft), ALWAYS updates the EXISTING row in place — same `Id`,
  same `VersionId`, same `Status`, `CreatedDate` unchanged; details for the current template ID are
  replaced (deleted and re-inserted); returns the same `id`/`versionId`. No age check of any kind.
  This endpoint never creates a new row anymore — that behavior moved to `POST {id}/request-change`
  (Section 11).
- If `IsDefault = 1`: clears existing default **globally** across all templates (Update 13)
- Free-solo step resolution (see Create Template, Update 6) applies as before
- **Update 10 (2026-07-13)**: this endpoint is now called by `TemplateBuilderPage.jsx`'s Save
  button (via the existing `UpdateEutrTemplatesUseCase`) instead of `EutrTemplatesAddEdit.jsx` — no
  contract change, same request/response shape; on success the frontend navigates back to
  `/eutr/templates` (unchanged existing behavior). **(Update 16)**: the Save button itself is now
  disabled/hidden by the frontend whenever `status === 1` (Approved) (see Section 2's note) — this
  server-side rejection is a defense-in-depth backstop, not the primary UX gate.
- **Update 12 (2026-07-13)**: `TemplateBuilderPage.jsx`'s Add Root Group / Add Child Step dialogs
  now let the user tick multiple master steps (plus optionally type one new free-solo step name)
  and add them all to the tree in a single UI action instead of one at a time — this only changes
  how many `details[]` entries `flattenForSave()` produces per user interaction before the existing
  Save click; the request body shape, per-detail fields (`stepId`/`stepName`/`parentId`/
  `requirementType`/`takeFrom`/`displayOrder`), and free-solo step auto-create resolution (Update 6)
  are all unchanged. No contract change.
- **(Superseded by Update 16)** ~~Update 15 (2026-07-15, bug fix — FR-049): in the ≥24h branch, the
  backend now ALSO copies every `eutr_template_references` row of the old `TemplateId` to the new
  `TemplateId`.~~ This copy behavior still exists, but it moved with the version-bump trigger to
  `POST {id}/request-change` (Section 11) — this `PUT` endpoint no longer creates a new `TemplateId`
  at all, so it has nothing to copy references to.

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
**Auth**: Policy-based. **Confirmed as shipped (Update 14 planning pass)**: the controller does NOT
use a new `EutrTemplateReferences.*` policy family — it reuses `EutrTemplates.Read` (GetByTemplateId,
Export), `EutrTemplates.Update` (Create, Update, Import), and `EutrTemplates.Delete` (Delete)
directly. This resolves the open "verify wiring" item this section originally flagged at Update 13
plan time.

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

### 9.5 Import Mappings (new, Update 14)

```
POST api/eutr-template-references/import/{templateId}
Content-Type: multipart/form-data
```

**Auth**: `EutrTemplates.Update` (same policy as Create/Update on this controller).

**Request**: Form field `file` with a `.xlsx` file. Path param `templateId` — the mapping is always
scoped to this template (see Behavior below); no other template's mappings can be created or
modified through this endpoint.

**Expected Excel columns** (row 1 = header, data from row 2):

| A | B | C | D |
|---|---|---|---|
| TemplateCode | VendorCode | FromDate | ToDate |

**Response**:
```json
{
  "success": true,
  "data": {
    "totalRows": 5,
    "successCount": 3,
    "failCount": 2,
    "errors": [
      { "row": 4, "templateCode": "Templates-002", "vendorCode": "V003", "message": "TemplateCode does not match the current template" },
      { "row": 6, "templateCode": "Templates-001", "vendorCode": "", "message": "Vendor is required" }
    ]
  }
}
```

**Response — template not found** (404):
```json
{ "success": false, "message": "Template with id {templateId} not found." }
```

**Response — invalid file** (400, non-`.xlsx` or missing/renamed required columns):
```json
{ "success": false, "message": "Only .xlsx files are supported." }
```

**Behavior**:
- Each valid row is submitted to the SAME `EutrTemplateReferencesService.AddAsync` the manual
  "Apply Vendor" dialog (Section 9.2) calls — same validation (`VendorCode`/`FromDate` required,
  `ToDate >= FromDate`), same `HasOverlapAsync` overlap check (Section 9.2's Behavior notes), scoped
  to `(templateId, VendorCode)`. This is a literal code-reuse of Section 9.2's Add logic, not a
  parallel re-implementation.
- `TemplateCode` (trimmed) must exactly match the `templateId`'s Code; a mismatched row fails with
  `"TemplateCode does not match the current template"` and is skipped — it is never applied to any
  other template, regardless of what Code it names (FR-046, FR-048).
- Blank `ToDate` is treated as unlimited (`9999-12-31`), same convention as Section 9.2.
- Because rows are processed in file order and each successful row commits immediately, a later row
  that overlaps an earlier row's just-created mapping (same file, same vendor) is correctly rejected
  as an overlap — no separate in-file duplicate-tracking needed.
- Import is **Add-only** — it never updates an existing mapping, even if a row's data exactly matches
  one already in the table (treated as an overlap error like any other overlapping range).
- Partial import: valid rows succeed, invalid rows reported per-row (`row`, `templateCode`,
  `vendorCode`, `message`); if the file has zero data rows, `totalRows`/`successCount`/`failCount`
  are all `0` (not an error).

### 9.6 Export Mappings (new, Update 14)

```
GET api/eutr-template-references/export/{templateId}
```

**Auth**: `EutrTemplates.Read` (same policy as GetByTemplateId, Section 9.1).

**Response**: Binary file download
(`application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`), filename
`eutr-template-references-{code}-{yyyyMMddHHmmss}.xlsx`.

**Response — template not found** (404): same shape as Section 9.5.

**Excel columns**: `TemplateCode`, `VendorCode`, `FromDate`, `ToDate` — deliberately excludes
`VendorName` (unlike the Get-by-template response, Section 9.1) so the exported file's column set
exactly matches what Import (Section 9.5) expects, letting Export double as the "file template" for
Import with zero extra columns to strip. When the template has zero mappings, the response is a
valid `.xlsx` with only the header row — usable directly as a blank import template.

---

## 10. Clone Template (new, Update 15)

```
POST api/eutr-templates/{id}/clone
```

**Auth**: `EutrTemplates.Create` (Clone creates a new template — same policy as Section 3, no new
policy family).

**Request Body**:
```json
{
  "name": "Template A (Copy)",
  "alertFor": 3
}
```
Only `name` and `alertFor` are accepted — no `details[]`, no `isDefault`. `{id}` in the path identifies
the **source** template being cloned from.

**Response**:
```json
{
  "success": true,
  "data": { "id": 42, "code": "Templates-015", "versionId": 1, "status": 0 },
  "message": "Template cloned successfully."
}
```
*(Update 16: `status` — new field, always `0` (Draft) for a cloned template, regardless of the
source's Status.)*

**Response — source template not found** (404):
```json
{ "success": false, "message": "Template with id {id} not found." }
```

**Response — validation error** (400, `name` blank or `alertFor` missing/not positive):
```json
{ "success": false, "message": "Name is required." }
```

**Behavior**:
- Loads the source template (via the existing `GetByIdWithDetailsAsync`) including its full detail
  tree; 404 if the source doesn't exist or is soft-deleted/hidden.
- Creates a brand-new `eutr_templates` row: new auto-generated `Code` (same generation logic as
  Section 3), `Name`/`AlertFor` from the request body, `VersionId = 1`, `IsDefault = 0` (always,
  regardless of the source's `IsDefault` — FR-053), `Status = 0` (Draft) (Update 16, always, regardless
  of the source's Status), `IsDeleted = 0`, `IsHide = 0`.
- Copies the ENTIRE detail tree (`eutr_template_details`) from the source template to the new
  template's Id — same `StepId`, `RequirementType`, `TakeFrom`, `DisplayOrder` per row, and the same
  parent-child (`ParentId`) structure, reusing the existing detail-insert pipeline (see research.md
  Section 31). No `eutr_steps` writes occur (every copied `StepId` is already resolved).
- Copies the ENTIRE mapping set (`eutr_template_references`) from the source template to the new
  template's Id via the same `CopyReferencesAsync` method used by Section 4's version-up fix (research
  .md Section 30) — same `VendorCode`/`FromDate`/`ToDate`/audit fields, no overlap re-check (the
  destination starts empty and the source rows are already mutually non-overlapping).
- The whole operation is one transaction — a failure partway through leaves no new template behind.
- The new template has no ongoing relationship to its source — subsequent Edit/Delete/version-up on
  either template does not affect the other.
- Frontend calling convention: `CloneTemplateDialog.jsx` (new, on `TemplateListPage.jsx`) collects
  `name`/`alertFor`, shows a `ConfirmDialog`-style warning, then on confirm calls this endpoint via a
  new `CloneEutrTemplatesUseCase`; on success the dialog closes and the list refetches (same
  refresh convention as `CreateTemplateDialog.jsx`, Section 3).

---

## 11. Approve / Request Change (new, Update 16)

Both endpoints take **no request body** — they are pure state-transition actions on the template
identified by `{id}`. Both reuse the `EutrTemplates.Update` policy (no new policy family) and the
same try/catch → 404/400 mapping already used by every other `{id}`-scoped action on this
controller.

### 11.1 Approve

```
POST api/eutr-templates/{id}/approve
```

**Response** (Status was Draft):
```json
{
  "success": true,
  "data": { "id": 1, "code": "Templates-001", "versionId": 1, "status": 1 },
  "message": "Template approved successfully."
}
```
`id`/`versionId`/`code` are unchanged — this is a same-row update, no new template is created.

**Response — rejected** (400, Status was already Approved):
```json
{ "success": false, "message": "Only a Draft template can be Approved." }
```

**Response — not found** (404): same shape as Section 10.

**Behavior**:
- Loads the template; if `Status != 0` (Draft), rejects with a validation error (400) — no data
  changes.
- Otherwise, updates ONLY `Status = 1` (Approved) (+ `UpdatedBy`/`UpdatedDate`) on the same row via
  `SetStatusAsync` — `Id`, `VersionId`, `CreatedDate`, `eutr_template_details`, and
  `eutr_template_references` are all left untouched.
- Frontend calling convention: the **Approve** button on `TemplateListPage.jsx`'s toolbar (enabled
  only when exactly 1 row is selected via the existing bulk-delete checkbox state and that row's
  `status` is `0` (Draft)) opens a `ConfirmDialog` Yes/No; **Yes** calls this endpoint via a new
  `ApproveEutrTemplatesUseCase`, then clears the selection and refetches the list; **No** closes the
  dialog with no request sent.

### 11.2 Request Change

```
POST api/eutr-templates/{id}/request-change
```

**Response** (Status was Approved — new version row created):
```json
{
  "success": true,
  "data": { "id": 2, "code": "Templates-001", "versionId": 2, "status": 0 },
  "message": "Change requested successfully."
}
```
Note: `id` and `versionId` refer to the NEW row — same shape as Section 4's old ≥24h response before
Update 16 removed it, and the same `{ id, code, versionId }` shape as Clone (Section 10).

**Response — rejected** (400, Status was already Draft):
```json
{ "success": false, "message": "Only an Approved template can request change." }
```

**Response — not found** (404): same shape as Section 10.

**Behavior**:
- Loads the template; if `Status != 1` (Approved), rejects with a validation error (400) — no data
  changes.
- Otherwise, in one transaction:
  1. Inserts a new `eutr_templates` row: same `Code`/`Name`/`AlertFor`/`IsDefault` as the existing
     row (copied verbatim — this action takes no payload), `VersionId = existing.VersionId + 1`,
     `Status = 0` (Draft), `IsHide = 0`, `IsDeleted = 0`.
  2. Copies the entire detail tree (`eutr_template_details`) from the old `TemplateId` to the new one
     via `CopyDetailTreeAsync` — the SAME re-index-and-copy pipeline Clone (Section 10) uses, NOT the
     old (now-removed) age-based branch's rebuild-from-submitted-payload logic (see research.md §32).
  3. Copies the entire mapping set (`eutr_template_references`) via the SAME `CopyReferencesAsync`
     method used by Clone and the old version-up fix (research.md §30).
  4. Updates the OLD row: `IsHide = 1` — otherwise left completely untouched (an immutable historical
     snapshot of what was Approved; NOT deleted).
- Frontend calling convention: the **Request change** button on `TemplateListPage.jsx`'s toolbar
  (enabled only when exactly 1 row is selected and that row's `status` is `1` (Approved)) opens a
  `ConfirmDialog` Yes/No; **Yes** calls this endpoint via a new `RequestChangeEutrTemplatesUseCase`,
  then clears the selection and refetches the list (the new Draft row now appears, replacing the
  Approved one); **No** closes the dialog with no request sent.
