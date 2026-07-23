# Data Model: EUTR Templates Management

**Feature**: 003-eutr-templates | **Date**: 2026-07-03

**Update 13 (2026-07-13)**: `VendorCode` removed from `EutrTemplates` entirely (no migration of
existing values); `IsDefault` uniqueness becomes global instead of per-VendorCode; new
`EutrTemplateReferences` entity added (`eutr_template_references` table) for the Apply-to-Customer
feature — a separate time-bound Template↔Vendor mapping, replacing the old direct Vendor field on
the template itself.

**Update 15 (2026-07-15)**: (1) Bug fix — the version-up (≥24h) branch now also copies
`EutrTemplateReferences` rows to the new `TemplateId` (previously only `EutrTemplateDetails` was
copied, silently orphaning vendor mappings on the now-hidden old row). (2) New **Clone** operation —
duplicates a template's header (new Code, new Name/AlertFor from user input, VersionId=1,
IsDefault=0), full detail tree, and full reference-mapping set into a brand-new, fully independent
template row.

**Update 16 (2026-07-21)**: (1) New `Status` field (`0`=Draft/`1`=Approved, `TINYINT`, default `0`)
on `EutrTemplates`. **Implementation note**: the spec/plan originally called for a `VARCHAR(20)`
string column (`'Draft'`/`'Approved'`) — during `/speckit-implement`, the live dev DB was found to
already have an unused `Status TINYINT NULL DEFAULT 0` column (present in no design doc, migration,
or code) with `AlertFor` also still `tinyint` (migration 08 never applied there), confirming this
dev DB predates several documented migrations. The user decided to keep the existing column's type
rather than convert it, so `Status` is `TINYINT` (0=Draft, 1=Approved) backed by a
`TemplateStatusEnum : byte` in `ComplianceSys.Application.Constants`, mirrored on the frontend as a
numeric `TEMPLATE_STATUS` plus a `TEMPLATE_STATUS_LABELS` display map (the same
value/label-map split already used for `RequirementType`/`TakeFrom`). This section and the rest of
this doc describe the AS-BUILT numeric design. (2) The 24-hour age-based versioning branch is
REMOVED entirely — edit while `Status=0` (Draft) always updates in place, regardless of
`CreatedDate` age. (3) VersionId now only increments via the new explicit **Request change** action
(`Status: 1→0`, Approved→Draft), which reuses the same detail-tree/reference copy pipeline **Clone**
already established (Update 15) instead of the old age-based branch's payload-rebuild logic. (4) New
**Approve** action (`Status: 0→1`, Draft→Approved, same row, no version change). (5) A template with
`Status=1` (Approved) is read-only — `UpdateAsync` rejects direct edits server-side, not just via a
disabled frontend control.

## Entities

### 1. EutrTemplates

**Table**: `eutr_templates`

| Field | Type | Nullable | Default | Constraint | Description |
|-------|------|----------|---------|------------|-------------|
| Id | BIGINT UNSIGNED | NO | AUTO_INCREMENT | PK | Primary key |
| Code | VARCHAR(255) | NO | — | — | Auto-generated code (e.g., Templates-001). Readonly. |
| Name | VARCHAR(255) | YES | NULL | — | Template name. Required by validation. |
| ~~VendorCode~~ | ~~VARCHAR(50)~~ | — | — | — | **Removed (Update 13)**. Existing values discarded, no migration. Vendor↔Template linkage now lives in `EutrTemplateReferences` (time-bound, many-to-many) instead of a single field on the template. |
| IsDefault | TINYINT | YES | 0 | Max 1 **globally** among active records (Update 13 — was max 1 per VendorCode) | Default template flag. **(Update 18)**: editable via a dedicated `POST {id}/set-default` endpoint even when `Status=Approved` — the one field NOT subject to Update 16's Approved-rejects-edits rule (see State Transitions below). |
| VersionId | TINYINT | NO | 1 | — | Version counter. Starts at 1. **(Superseded by Update 16)** ~~increments on edit only if CreatedDate is >24h old~~ → increments ONLY when Request change transitions the row from Approved to Draft (see Status below and State Transitions). |
| Status | TINYINT | YES | 0 | Values: `0`=Draft, `1`=Approved (Update 16; `TemplateStatusEnum` backend, `TEMPLATE_STATUS`/`TEMPLATE_STATUS_LABELS` frontend `helpers.js`) | Approval lifecycle flag. Defaults to `0` (Draft) on Create and Clone. `1` (Approved) rows are read-only (server-enforced) until Request change moves them back to `0` (Draft) on a NEW version row. Column pre-existed on the dev DB (unused, no prior migration) — see Update 16 note above. |
| AlertFor | BIGINT UNSIGNED | YES | NULL | Logical ref → compl_group_email.Id (no DB FK — see Update 7) | Selected Alert group's Id. Required by validation (must be > 0). Was VARCHAR(50) free text before Update 7 (2026-07-07). |
| IsDeleted | TINYINT | YES | 0 | — | Soft delete flag (0=active, 1=deleted) |
| IsHide | TINYINT | YES | 0 | — | Version hide flag (0=current, 1=superseded) |
| CreatedBy | VARCHAR(50) | YES | NULL | — | Audit: creator email |
| CreatedDate | DATETIME | YES | NULL | — | Audit: creation timestamp |
| UpdatedBy | VARCHAR(50) | YES | NULL | — | Audit: last updater email |
| UpdatedDate | DATETIME | YES | NULL | — | Audit: last update timestamp |

**Grid filter**: `WHERE IsDeleted = 0 AND IsHide = 0`

**Response-only fields** (not DB columns, populated on read): ~~`VendorName`~~ (**removed, Update
13** — no longer meaningful without `VendorCode`), `AlertForName` (from `compl_group_email.Name`,
resolved via `LEFT JOIN` on `AlertFor` — Update 7), `StepsCount` (int — Update 11: correlated
subquery `SELECT COUNT(*) FROM eutr_template_details d WHERE d.TemplateId = t.Id`, shown on
TemplateListPage's Steps column; always the current row's real detail count, not a placeholder —
**Update 13**: this remains an open, user-reported defect per FR-042 despite the query/binding
being verified correct; see plan.md's Steps-Count Investigation section for the verify-first
approach).

**Business rules**:
- Code: auto-generated by backend (`{prefix}{separator}{paddedNumber}`, default: `Templates-001`)
- VersionId: set to 1 on create
- **Create payload shape (Update 9, 2026-07-13; Update 13)**: the frontend's Create Template dialog
  (`CreateTemplateDialog.jsx`) sends `details: []` — the step tree is not set at creation time, only
  Name/AlertFor/IsDefault. **Update 13**: `vendorCode: null` is no longer sent because `VendorCode`
  no longer exists on the entity/DTO at all. Vendor↔template linkage is set up later, separately,
  via the Apply-to-Customer screen (`eutr_template_references`) — not via a subsequent Edit anymore.
  **Update 16**: `Status` is never accepted from the client on Create — the backend always sets
  `Status = Draft` on the new row.
- **(Superseded by Update 16 — see below)** ~~On edit, versioning is conditional on
  `(now - CreatedDate)` of the row being edited:~~
  - ~~**≥ 24 hours**: new row created with `VersionId + 1`, details inserted under the new
    `TemplateId`, old row set `IsHide = 1`. (Update 15) `EutrTemplateReferences` rows belonging to
    the old `TemplateId` are ALSO copied to the new `TemplateId` (see Entity 6, FR-049).~~
  - ~~**< 24 hours**: existing row updated in place (same `Id`, same `VersionId`, `CreatedDate`
    unchanged) — header fields overwritten, `eutr_template_details` for this `TemplateId` replaced
    (delete + re-insert), `IsHide` untouched.~~
- **On edit (Update 16)**: allowed ONLY when `Status = Draft` (the backend rejects an edit attempt
  on an `Approved` row with a validation error, per FR-061 — this is enforced server-side, not just
  a disabled frontend button). When allowed, the existing row is ALWAYS updated in place (same `Id`,
  same `VersionId`, `CreatedDate` unchanged) — header fields overwritten, `eutr_template_details`
  for this `TemplateId` replaced (delete + re-insert), `IsHide` untouched, regardless of how long ago
  the row was created. No new row is ever created by a normal edit/Save.
- **Approve (new, Update 16)**: `Status: Draft → Approved` on the SAME row — `Id`/`VersionId`/
  `CreatedDate`/`eutr_template_details`/`eutr_template_references` all unchanged, only `Status` (+
  `UpdatedBy`/`UpdatedDate`) is written.
- **Request change (new, Update 16)**: `Status: Approved → Draft`, and THIS is now the only trigger
  for a version bump: a new row is created with `VersionId + 1`, `Status = Draft`, and the SAME
  `Name`/`AlertFor`/`IsDefault` as the row it supersedes (copied verbatim — Request change carries no
  payload, unlike a normal edit); `eutr_template_details` and `eutr_template_references` are copied to
  the new `TemplateId` using the exact same copy pipeline Clone (Update 15) already uses, NOT the old
  age-based branch's rebuild-from-submitted-payload logic (see research.md §32); the old row is set
  `IsHide = 1` and otherwise left untouched — an immutable historical snapshot of what was Approved.
- **Clone (new, Update 15)**: creates an entirely new, independent row — new auto-generated `Code`,
  `Name`/`AlertFor` from the Clone dialog's input, `VersionId = 1`, `IsDefault = 0` (always, never
  inherited from the source), `Status = Draft` (Update 16, always, regardless of the source's
  Status), `IsDeleted = 0`, `IsHide = 0`, `CreatedBy`/`CreatedDate` = current user/now. The full
  detail tree and full reference-mapping set of the source template are copied to the new
  `TemplateId` (see Entity 2/Entity 6). The new template has no relationship back to its source after
  creation — editing, deleting, approving, or versioning either one does not affect the other.
- On delete: set `IsDeleted = 1` on the visible row only
- **IsDefault constraint (Update 13 — changed from per-VendorCode to global)**: max 1 template
  `IsDefault = 1` **across the entire table** (among active records: `IsDeleted=0, IsHide=0`);
  auto-toggle off the previous global default when a new one is set.
- **AlertFor (Update 7, 2026-07-07)**: stores the `Id` of a row in `compl_group_email` (selected via
  a combobox showing that group's `Name`, filtered to `GroupType = 2` (Alert) and
  `IsAddition = false`). Not validated for existence server-side (same treatment as `VendorCode`).
  Display resolves `Id → Name` via `LEFT JOIN compl_group_email` in the read queries (see
  `AlertForName` below) rather than a separate lookup service, since `compl_group_email` is a local
  table (unlike D365 VendorsV3).
- **Keyword search (Update 11, 2026-07-13)**: the paged list query accepts an optional `Keyword`
  pseudo-filter (not a real column) that expands to `(Code LIKE @value OR Name LIKE @value)` —
  special-cased in the repository's WHERE-clause builder the same way `AlertFor → g.Name` is,
  instead of a straight single-column mapping. Powers TemplateListPage's search box (server-side,
  matches across the full dataset, not just the loaded page).

### 2. EutrTemplateDetails

**Table**: `eutr_template_details`

| Field | Type | Nullable | Default | Constraint | Description |
|-------|------|----------|---------|------------|-------------|
| Id | BIGINT UNSIGNED | NO | AUTO_INCREMENT | PK | Primary key |
| TemplateId | BIGINT UNSIGNED | YES | NULL | FK → eutr_templates.Id | Parent template |
| ParentId | BIGINT | NO | — | — | Parent step Id (0 = root level) |
| StepId | BIGINT UNSIGNED | YES | NULL | FK → eutr_steps.Id | Reference to EUTR step |
| RequirementType | TINYINT | YES | 0 | — | 0=Optional, 1=Required |
| TakeFrom | TINYINT | NO | — | — | 0=PO, 1=Upload manual |
| DisplayOrder | INT | YES | 0 | — | Sort order within same parent level |
| CreatedBy | VARCHAR(50) | YES | NULL | — | Audit: creator email |
| CreatedDate | DATETIME | YES | NULL | — | Audit: creation timestamp |
| UpdatedBy | VARCHAR(50) | YES | NULL | — | Audit: last updater email |
| UpdatedDate | DATETIME | YES | NULL | — | Audit: last update timestamp |

**Business rules**:
- ParentId = 0 means root-level step
- ParentId > 0 references another EutrTemplateDetail.Id within the same template
- DisplayOrder is auto-set from the reordering interaction (0-based within siblings), always via the
  same `reorderSiblings` function on `TemplateBuilderPage.jsx` — either Move Up/Down toolbar buttons
  (Update 10) or **(Update 17)** real drag-and-drop on the same tree, restricted to reordering among
  siblings sharing the same `ParentId` (dropping onto a different branch is a no-op, FR-065); both
  gestures write the field the same way, only the trigger differs. **Correction**: an earlier version
  of this note claimed drag-and-drop already existed on `StepTree.jsx`/`EutrTemplatesAddEdit.jsx` —
  verified false during Update 17's code audit (`@dnd-kit` was installed but imported nowhere in this
  feature); Update 17 is the first real drag-and-drop implementation for this feature, not a reuse of
  a pre-existing pattern.
- No `Type`/`FSC` columns exist on this table — `TemplateBuilderPage.jsx`'s mock-only Type
  (Cá nhân/Tổ chức) and FSC (Yes/No) fields have no backend counterpart and are removed when the
  screen is wired to real data (Update 10)
- **(Superseded by Update 16)** ~~On template edit: if the template row is ≥24h old, all details are
  copied to the new template version (new TemplateId); if <24h old, existing details for the current
  TemplateId are replaced (delete + re-insert) in place~~ → On template edit (only allowed while
  Status=Draft), existing details for the current TemplateId are ALWAYS replaced (delete +
  re-insert) in place — no age check. Details are copied to a NEW TemplateId only via **Request
  change** (Status: Approved → Draft), reusing the same copy pipeline as Clone (see Entity 1,
  research.md §32).
- Cascade deletion: removing a parent step removes all descendants (client-side, before save)
- **StepId resolution (Update 6)**: the request DTO also accepts a request-only `StepName` field
  (not a DB column) used only when `StepId` is null — the Step combobox is free-solo, so a step
  typed as free text arrives with `StepId = null` and `StepName = <typed text>`. Before insert,
  the backend matches `StepName` (trimmed, case-insensitive) against `eutr_steps`; on no match it
  inserts a new `eutr_steps` row and uses the new Id. Duplicate new names within one Save resolve
  to a single created row.
- **Bulk add in the UI (Update 12)**: `TemplateBuilderPage.jsx`'s Add Root Group/Add Child Step
  dialogs can append several detail rows to the client-side tree in one user action (ticking
  multiple master steps, optionally plus one free-solo new name) instead of one row per dialog
  open. This is purely a client-side authoring convenience — no schema or DTO change. The one rule
  this adds: a master step already present as a **direct child of the same target ParentId** is
  excluded from the dialog's selectable list, to avoid two `eutr_template_details` rows with the
  same `(ParentId, StepId)` pair; a step remains selectable again under a different ParentId.
- **Clone (new, Update 15)**: the backend re-indexes the source template's DB-Id-based detail tree
  (as returned by `GetByIdWithDetailsAsync`) into the same 1-based sequential-position `ParentId`
  convention the frontend already sends on every normal Save, then reuses the existing
  insert-and-remap pipeline (`BuildDetailEntitiesAsync` + `BulkInsertDetailsAsync`) to write the
  copied rows under the new `TemplateId` — no new tree-insert SQL. Every copied row keeps its source
  `StepId` (never re-resolved by name, since Clone never carries a free-solo `StepName`), its
  `RequirementType`/`TakeFrom`/`DisplayOrder`, and gets fresh `CreatedBy`/`CreatedDate` (current
  user/now — this IS a new row, unlike the reference-mapping copy in Entity 6 which preserves
  original audit fields).

### 3. EutrStep (existing — feature 001-eutr-steps; read + write from this feature)

**Table**: `eutr_steps`

| Field | Type | Description |
|-------|------|-------------|
| Id | BIGINT UNSIGNED | PK |
| Name | VARCHAR(255) | Step name (displayed in combobox) |

Used as lookup data for the free-solo step combobox when adding/editing steps on a template.
**Update 6**: this feature also **writes** to `eutr_steps` — when a step is entered as free text
and doesn't match (trimmed, case-insensitive) an existing row, template Save auto-creates a new
`eutr_steps` row (`CreatedBy`/`CreatedDate` set the same way the 001-eutr-steps create flow sets
them) and uses its Id. The new row is immediately visible in the 001-eutr-steps grid.

### 4. D365 VendorsV3 (external — read-only reference)

**Source**: D365 Finance & Operations OData entity `VendorsV3`

| Field | Type | Description |
|-------|------|-------------|
| VENDORACCOUNTNUMBER | string | Vendor code (**Update 13**: maps to `EutrTemplateReferences.VendorCode`, not `EutrTemplate.VendorCode` — that field no longer exists) |
| VENDORORGANIZATIONNAME | string | Vendor display name (shown in the Apply-to-Customer combobox/list) |
| DATAAREAID | string | Legal entity filter |

Queried via the generic reference API `POST /api/dynamics/reference` with `refType = 13`
(**Update 5, 2026-07-06** — reverted from the dedicated `GET /api/dynamics/vendors` endpoint
added in Update 2/3; that endpoint still exists in `DynController` but is no longer this
feature's data source). `refType = 13` is already mapped to `VendorsV3` in
`ComplDynamicsService`. Domain model: `ComplianceSys.Domain.Dynamics.VendorsV3` (already exists).
**Update 13**: the Vendor combobox/lookup relocates from `EutrTemplates` (TemplateBuilderPage,
removed) to `EutrTemplateReferences` (ApplyCustomerPage, new) — same API, same refType, different
entity it resolves against.

### 5. Compl Group Email (existing — group-email feature; read-only from this feature) — Update 7

**Table**: `compl_group_email`

| Field | Type | Description |
|-------|------|--------------|
| Id | BIGINT | PK. Referenced by `EutrTemplates.AlertFor` (logical reference, no DB FK). |
| Name | VARCHAR(255) | Group display name — shown in the Alert for combobox and grid. |
| GroupType | TINYINT | 1=Responsible, 2=Alert. Alert for combobox only loads `GroupType = 2`. |
| IsAddition | TINYINT(1) | Groups with `IsAddition = true` are excluded from the Alert for combobox. |

Queried by this feature via `GET /api/group-email` (`ComplGroupEmailController.GetAll`, already
exists — no backend change needed for the combobox data source) for the Add/Edit combobox, and via
a `LEFT JOIN compl_group_email` in `EutrTemplatesRepository` for grid/detail `AlertForName`
resolution. Domain model: `ComplianceSys.Domain.Entities.ComplGroupEmail` (already exists).

### 6. EutrTemplateReferences (new — Update 13, Apply to Customer)

**Table**: `eutr_template_references`

| Field | Type | Nullable | Default | Constraint | Description |
|-------|------|----------|---------|------------|-------------|
| id | INT UNSIGNED | NO | AUTO_INCREMENT | PK | Primary key (lowercase `id`, unlike other tables' `Id` — per `docs/design/eutr/eutr_db.sql`) |
| TemplateId | BIGINT UNSIGNED | NO | — | FK → eutr_templates.Id | Template being applied |
| VendorCode | VARCHAR(50) | NO | — | — | Vendor the template is applied to; name resolved via D365 VendorsV3 (refType=13) |
| FromDate | DATE | NO | — | — | Mapping validity start date |
| ToDate | DATE | NO | — | — | Mapping validity end date. UI treats a blank/omitted To date as unlimited (9999-12-31) before persisting |
| CreatedBy | VARCHAR(50) | NO | — | — | Audit: creator email (NOT NULL, unlike other audit columns in this feature) |
| CreatedDate | DATETIME | NO | — | — | Audit: creation timestamp (NOT NULL) |
| UpdatedBy | VARCHAR(50) | NO | — | — | Audit: last updater email (NOT NULL) |
| UpdatedDate | DATETIME | NO | — | — | Audit: last update timestamp (NOT NULL) |

**No `IsDeleted`/`IsHide` columns** — this table has no soft-delete flag by design (per
`docs/design/eutr/eutr_db.sql`); removing a mapping is a real `DELETE` (FR-037).

**Business rules**:
- A Template may have many mappings (many Vendors); a Vendor may be mapped to many Templates.
- **Overlap validation (FR-036)**: before Create/Update, the backend MUST reject a mapping whose
  `[FromDate, ToDate]` range overlaps an existing mapping for the **same `TemplateId` AND same
  `VendorCode`** (excluding the record being edited). Overlap across **different** Templates for the
  same Vendor is explicitly allowed — confirmed via clarification during `/speckit-specify`.
- Delete is a hard delete (no flag to set) — confirmed via `ConfirmDialog` on the frontend (FR-037).
- VendorName is a response-only field (not a DB column), resolved the same way the old
  `EutrTemplates.VendorName` was — via the generic reference API (`refType=13`).
- **Bulk Import/Export (Update 14)**: mappings for one template can be exported to / imported from
  an Excel (.xlsx) file with exactly 4 columns — `TemplateCode`, `VendorCode`, `FromDate`, `ToDate`
  — scoped to a single `TemplateId` (the currently-open ApplyCustomerPage). Export includes
  `TemplateCode` purely for round-trip readability/verification (every row repeats the same Code);
  Import uses it to cross-check each row belongs to the template being imported into — a mismatch
  fails that row, it does NOT route the row to a different template. Import always creates a NEW row
  per valid line (reuses `AddAsync`'s existing validation + overlap-check) — it never updates an
  existing mapping, even on an exact data match (FR-043 to FR-048).
- **Copy-to-new-TemplateId (new, Update 15)**: a new repository method,
  `CopyReferencesAsync(sourceTemplateId, newTemplateId, ct)`, duplicates every mapping row of a source
  `TemplateId` under a new `TemplateId` via a single set-based `INSERT ... SELECT` — preserving
  `VendorCode`/`FromDate`/`ToDate` AND the original `CreatedBy`/`CreatedDate`/`UpdatedBy`/`UpdatedDate`
  (unlike the detail-tree copy, which stamps fresh audit fields — see Entity 2). No overlap
  re-validation is performed for this copy: the source rows are already mutually non-overlapping
  (they passed `HasOverlapAsync` when originally created) and the destination `TemplateId` always
  starts with zero mappings, so an overlap can never occur. Used by two call sites: (1)
  `EutrTemplatesService.UpdateAsync`'s ≥24h version-up branch (FR-049), and (2) the new
  `EutrTemplatesService.CloneAsync` (FR-053) — same method, no duplicated copy logic.

## Relationships

```
EutrTemplates (1) ──── (*) EutrTemplateDetails
                               │
EutrStep (1) ─────────── (*) ──┘ (via StepId FK)

EutrTemplates (1) ──── (*) EutrTemplateReferences (via TemplateId FK — Update 13)

D365 VendorsV3 ──lookup── EutrTemplateReferences (via VendorCode — Update 13; was EutrTemplates.VendorCode before removal)

compl_group_email ──lookup── EutrTemplates (via AlertFor → Id, no DB FK — Update 7)

EutrTemplateDetails ──self-ref── EutrTemplateDetails (via ParentId → Id, recursive tree)
```

## State Transitions

### Template Lifecycle

**(Superseded by Update 16 — see the Status-driven diagram below)** ~~the age-based (24h) versioning
diagram that previously lived here is removed; Edit/Save no longer branches on CreatedDate age at
all.~~

```
[Create — quick-create dialog, Update 9] ──→ Active, Status=Draft (IsDeleted=0, IsHide=0,
                                               VersionId=1, CreatedDate=now, 0 details)
                │
[Clone — Update 15, from any existing template] ──→ Active, Status=Draft (Update 16) (IsDeleted=0,
                                               IsHide=0, VersionId=1, IsDefault=0, CreatedDate=now,
                                               details + references copied from source; no link
                                               back to source)
                │
                ├──[Edit/Save, Status=Draft]──→ Same row updated in place, ALWAYS (Update 16 — no
                │                                 age check). Id, VersionId, CreatedDate unchanged;
                │                                 header + details overwritten.
                │
                ├──[Approve, Status=Draft]──→ Same row, Status=Approved (Update 16). Id, VersionId,
                │                                 CreatedDate, details, references all unchanged —
                │                                 only Status (+ UpdatedBy/UpdatedDate) changes.
                │                                 Edit/Save is now rejected server-side until
                │                                 Request change runs.
                │
                ├──[Request change, Status=Approved]──→ New Version, Status=Draft (Update 16)
                │                                 (IsDeleted=0, IsHide=0, VersionId=N+1, same Code/
                │                                 Name/AlertFor/IsDefault copied verbatim from the
                │                                 old row; details + references copied via the same
                │                                 pipeline Clone uses — see research.md §32).
                │                                 Old version (Status=Approved) → IsHide=1, otherwise
                │                                 untouched — an immutable historical snapshot.
                │
                └──[Delete]──→ Soft Deleted (IsDeleted=1)
```

### IsDefault Toggle (Update 13 — global scope, was per-VendorCode)

```
[Set Default on Template A]
  1. Find the current global default (IsDeleted=0, IsHide=0, IsDefault=1), any template
  2. If found: set IsDefault=0 on that template
  3. Set IsDefault=1 on Template A
```

**(Update 18)** This toggle now runs through TWO entry points, both reaching the SAME global-default
logic above:
- **Status=Draft**: unchanged — part of the header form, only persisted when the user clicks Save
  on `TemplateBuilderPage` (via `PUT {id}`, which rejects entirely if `Status` has since become
  Approved).
- **Status=Approved**: NEW — the Set-as-default checkbox stays enabled (the only header field that
  does); toggling it opens a Yes/No `ConfirmDialog`, and on **Yes** calls the dedicated
  `POST {id}/set-default` endpoint, which runs the same 3-step logic above immediately, independent
  of Save (which remains hidden/disabled for this row) and with NO `Status` precondition — this is
  the one endpoint on this entity that intentionally does not check `Status` before writing.

### EutrTemplateReferences Lifecycle (new — Update 13)

```
[Apply Vendor — ApplyCustomerPage "Apply Vendor" dialog] ──→ Row created
[Import — ApplyCustomerPage "Import" button, Update 14]  ──┘ (TemplateId, VendorCode, FromDate, ToDate)
                │                                             one row created per valid Excel row
                │                                             (same AddAsync path as manual Apply)
[Version-up copy — Update 15, FR-049] ──→ Row duplicated under the new TemplateId when the source
                │                          template versions up (≥24h branch); original row untouched
[Clone copy — Update 15, FR-053]      ──→ Row duplicated under the newly-cloned template's TemplateId
                │                          (both via the same CopyReferencesAsync method)
                ├──[Edit]──→ Same row updated in place (no versioning — this table has no VersionId)
                │
                └──[Delete]──→ Row hard-deleted (no IsDeleted flag on this table)
```

## Validation Rules

| Entity | Field | Rule |
|--------|-------|------|
| EutrTemplates | Name | Required, not empty |
| EutrTemplates | AlertFor | Required — must be a positive Id (Update 7: numeric, was "not empty string" pre-Update 7). Not validated for existence in `compl_group_email` server-side. |
| ~~EutrTemplates~~ | ~~VendorCode~~ | **Removed (Update 13)** — field no longer exists on this entity |
| EutrTemplates | Code | System-generated, not user-editable |
| EutrTemplates | Status | System-controlled, not user-editable via Create/Update — only changes via the dedicated Approve (Draft→Approved) and Request change (Approved→Draft) actions (Update 16) |
| EutrTemplates Update (Update 16) | Status | Backend rejects the request with a validation error if `existing.Status == Approved` — edits are only accepted while Draft |
| Approve request (Update 16) | Status | Backend rejects with a validation error if `existing.Status != Draft` |
| Request change request (Update 16) | Status | Backend rejects with a validation error if `existing.Status != Approved` |
| Set Default request (Update 18) | Status | NO precondition — unlike every other mutating action on this entity, `POST {id}/set-default` succeeds regardless of `Status` (Draft or Approved); this is the deliberate, sole exception to the Update 16 Approved-rejects-edits rule (FR-068) |
| EutrTemplateDetails | StepId or StepName | Must provide `StepId` (existing eutr_steps record) OR a non-blank `StepName` (Update 6 — resolved to an existing or newly-created eutr_steps record on Save) |
| EutrTemplateDetails | RequirementType | Must be 0 (Optional) or 1 (Required) |
| EutrTemplateDetails | TakeFrom | Must be 0 (PO) or 1 (Upload manual) |
| EutrTemplateReferences (Update 13) | VendorCode | Required, not empty |
| EutrTemplateReferences (Update 13) | FromDate | Required |
| EutrTemplateReferences (Update 13) | ToDate | Optional in the UI (blank = unlimited/9999-12-31); when provided, must be ≥ FromDate |
| EutrTemplateReferences (Update 13) | (TemplateId, VendorCode, FromDate/ToDate range) | Must not overlap an existing mapping for the same TemplateId + VendorCode (FR-036) |
| EutrTemplateReferences Import (Update 14) | File format | Must be `.xlsx` with header columns exactly `TemplateCode`, `VendorCode`, `FromDate`, `ToDate`; any other extension or missing/renamed column rejects the whole file before any row is processed |
| EutrTemplateReferences Import (Update 14) | Row: TemplateCode | Must equal the Code of the template currently open (route `:id`) — mismatch fails only that row (FR-046, FR-048) |
| EutrTemplateReferences Import (Update 14) | Row: VendorCode/FromDate/ToDate | Same rules as FR-036/the validator above, enforced by re-using `AddAsync` per row — not duplicated |
| Clone request (Update 15) | Name | Required, not empty (same rule as EutrTemplates.Name) |
| Clone request (Update 15) | AlertFor | Required — must be a positive Id (same rule as EutrTemplates.AlertFor); not validated for existence in `compl_group_email`, same treatment as the main entity |

## Enums

| Enum | Value | Label |
|------|-------|-------|
| RequirementType | 0 | Optional |
| RequirementType | 1 | Required |
| TakeFrom | 0 | PO |
| TakeFrom | 1 | Upload manual |
| Status (Update 16) | 0 | Draft |
| Status (Update 16) | 1 | Approved |
