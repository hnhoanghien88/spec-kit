# Data Model: Compliance Master Alert Type

## Entity: ComplMaster (existing, gains one field)

Backend: `ComplianceSys.Domain.Entities.ComplMaster` (`compl_masters` table).

| Field       | Type  | Default | Notes                                                                 |
|-------------|-------|---------|------------------------------------------------------------------------|
| `AlertType` | `int` | `0`     | New. Stores one of the `AlertType` enum values. Column already existed on `compl_masters` in the DB as `TINYINT(1)` — **widened to plain `TINYINT`** as part of this feature's migration, because `TINYINT(1)` is coerced to a CLR `bool` by the `MySql.Data` driver, which silently collapses `AlertType = 2` (Expired) into `1` (Missing) on read. Verified and fixed live; see `research.md` R4b. See below for the read-path (stored procedure) gap that both the forms and the list column depend on. |

All other existing fields (`Id`, `Code`, `Name`, `ValidFrom`, `ValidTo`, `NumDayAlert`, `Description`, `IsDelete`, `VersionNo`, `ReplacedById`, `IsIndividual`, `DuplicateId`) are unchanged.

`ComplMasterRequest` (Create/Update DTO) gains the matching field:

| Field       | Type  | Required | Default (client-sent) |
|-------------|-------|----------|------------------------|
| `AlertType` | `int` | No       | `0` (All)              |

`ComplMasterResponse` needs no changes — it inherits from `ComplMaster`, so `AlertType` flows through automatically once present on the base entity and returned by the read query (used by both the Edit form's get-by-id call and the list's get-all/paging call).

## Enum: AlertType

New backend enum, `ComplianceSys.Domain.Enums.AlertType : byte`, one file `AlertType.cs`, matching the existing `ComplType`/`GroupEmailType` style:

| Value | Name    | Meaning (per spec)                          |
|-------|---------|----------------------------------------------|
| 0     | All     | Alert applies to all compliance events (default) |
| 1     | Missing | Alert applies only to missing compliances     |
| 2     | Expired | Alert applies only to expired compliances      |

Frontend mirrors in `compliance-client/src/utils/helpers.js`:
- `ALERT_TYPE` (value map) + `ALERT_TYPE_OPTIONS` (`{value, label}` array) — used by the Create/Edit form's dropdown (US1/US2, see `research.md` R2).
- `ALERT_TYPE_LABELS` (plain `{0: 'All', 1: 'Missing', 2: 'Expired'}` object) — used by the list column to render a label per row (US3, see `research.md` R9).

Values and order must stay in lockstep with the backend enum (0/1/2 fixed by spec) across all three lookups.

## Frontend form state: `masterInfo` (ComplianceMasterForm.jsx) — US1/US2

Gains one field:

| Field       | Type   | Default (create) | Populated on edit-load from |
|-------------|--------|-------------------|------------------------------|
| `alertType` | number | `0`               | `data.alertType` (fallback `0` if undefined, satisfying spec FR-007 for pre-existing records) |

Included in the save `payload` alongside the other scalar fields (`description`, `numDayAlert`, `isIndividual`, etc.): `alertType: masterInfo.alertType`.

No changes to `conditionBlocks`, `compliances`, or any other existing state shape.

## List column: `useComplianceMasterColumns.jsx` — US3

No new or changed entities — purely a display addition on top of data that already exists once the read-path fix (R4/R4b) lands.

| Property      | Value                                                        |
|---------------|---------------------------------------------------------------|
| `field`       | `"alertType"`                                                  |
| `headerName`  | `"Alert type"`                                                 |
| Position      | Immediately after the `status` column, before `description`  |
| Value display | `ALERT_TYPE_LABELS[row.alertType] ?? ALERT_TYPE_LABELS[0]` (falls back to "All" for `null`/`undefined`, satisfying spec FR-007) |

`defaultColumnVisibility` gains `alertType: true`.

## Read-path dependency (shared by US1/US2/US3, not a new entity)

For `AlertType` to actually appear when listing or viewing a master, the MySQL stored procedures backing `GetComplMasterAsync` (`compl_sp_get_compl_master_paging`, used by the list) and `GetMasterByIdAsync` (`compl_sp_get_compl_master_by_id`, used by the Edit form) must select the column into their result sets (aliased to `AlertType` so Dapper's by-name mapping onto `ComplMasterResponse` populates it). See `research.md` R4 for why the checked-in `.sql` files cannot be trusted as-is and must be reconciled with the live database procedure definitions first, and R4b for the column-width correctness fix both paths depend on.
