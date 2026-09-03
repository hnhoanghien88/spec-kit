# Quickstart: Validate "DK Alert" Group Email Type

## Prerequisites

- Backend `compliance-sys-api` running locally (or against a dev environment) with the changes from this feature applied.
- Frontend `compliance-client` running (`npm run dev` or equivalent) against that backend.
- A user account with `GroupEmail.Create`, `GroupEmail.Update`, and `GroupEmail.ReadAll` permissions, logged in.

## Scenario 1 — Create a group with Type "DK Alert" (US1)

1. Navigate to the Group Email index screen (`/group-email`).
2. Click "Create" / the add-row action to open a new group row.
3. Enter a Name (e.g. `QA DK Alert Group`).
4. Open the Type dropdown.
   - **Expected**: three options are listed — "Responsible", "Alert", "DK Alert".
5. Select "DK Alert" and save the row.
   - **Expected**: the row saves without error and the index list shows the new group with Type "DK Alert" (not blank, not a number).

## Scenario 2 — Edit an existing group's Type to/from "DK Alert" (US2)

1. On the Group Email index screen, click Edit on an existing "Responsible" or "Alert" group.
2. Change its Type to "DK Alert" and save.
   - **Expected**: the list now shows that group with Type "DK Alert".
3. Edit the same group again and change its Type back to "Responsible" or "Alert", save.
   - **Expected**: the list reflects the reverted Type, confirming the field is freely editable both ways.

## Scenario 3 — Index display for "DK Alert" groups (US3)

1. With at least one group having Type "DK Alert" (from Scenario 1 or 2), reload the Group Email index screen.
   - **Expected**: every group with `groupType == 3` displays "DK Alert" in the Type column.

## Scenario 4 — Reject an invalid Type (edge case / FR-006)

1. Using the API client directly (e.g. curl/Postman) with a valid auth token, `POST api/group-email` with `"groupType": 9`.
   - **Expected**: the request is rejected with a validation error; no row is created.

## API-level check (optional, backs the contract in `contracts/group-email-type.md`)

```
POST /api/group-email
{
  "name": "QA DK Alert Group",
  "groupType": 3,
  "referenceType": 0,
  "isDefault": false
}
```
Expected: `200 OK` with a new `id`. Then:
```
POST /api/group-email/get-all
```
Expected: the created group's entry has `"groupType": 3` and `"groupTypeName": "DK Alert"`.
