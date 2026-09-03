# Data Model: Group Email — Add "DK Alert" Type Option

No schema change. This feature adds a display label and a validation rule for a value the data layer already accepts.

## Entity: Group Email (`ComplGroupEmail` / table `compl_group_email`)

| Field       | Type          | Notes                                                                 |
|-------------|---------------|------------------------------------------------------------------------|
| `Id`        | `long`        | Primary key. Unchanged.                                                |
| `Name`      | `string`      | Unchanged.                                                              |
| `GroupType` | `int`         | Already unconstrained at the DB/entity level. This feature adds application-level validation restricting Create/Update to `{1, 2, 3}` and a display-label mapping for `3`. |
| `IsDefault` | `bool`        | Unchanged.                                                              |
| `IsAddition`| `bool`        | Unchanged; unrelated to this feature (belongs to a separate existing concept on the same table). |

### `GroupType` value → label (business-facing)

| Value | Backend enum member (`GroupEmailType`) | Display label (`GroupTypeName`) | Selectable in Add/Edit before this feature? | Selectable after this feature? |
|-------|------------------------------------------|----------------------------------|:---:|:---:|
| 1     | `RespGroup`                | "Responsible" | Yes | Yes |
| 2     | `AlertGroup`                | "Alert"       | Yes | Yes |
| 3     | `ResponsibleForAddition`   | **"DK Alert"** (new) | No  | **Yes (new)** |
| 4     | `AlertForAddition`          | n/a — out of scope | No | No (unchanged; not exposed by this feature) |

**Validation rule (new)**: On Create and Update, `GroupType` MUST be one of `{1, 2, 3}`; any other value is rejected with a validation error, matching the existing validator's style (`ComplGroupRequestDtoValidator`).

**State transitions**: None beyond the existing free-form single-select Type field — a group's `GroupType` can be changed to any of the three values at any time via Edit, with no ordering/workflow constraints, consistent with today's "Responsible" ↔ "Alert" behavior.

No other entity (`ComplGroupEmailDetail`, `ComplMasterGroupEmail`, `ComplComplianceGroupEmail`, etc.) is affected by this feature.
