# Contract Delta: Rule condition Table logic for Customer — no API/DB contract change

This is a **frontend-only** fix (see `research.md` R17-R18, `plan.md` User Story 5). It intentionally has **no delta** to document against the existing `ComplMasterController` endpoints, request/response DTOs, or the `sp_load_compl_by_conditions`/`sp_load_compl_by_conditions_count` stored procedures — this file exists to record that fact as a verified finding (spec FR-019), not to describe a change.

## POST `api/compliance-master` (Create) / PUT `api/compliance-master/{id}` (Update)

Request body shape is **unchanged**: `ComplMasterRequest.Conditions[].DisplayType` already accepts `1` (Table) for any `RefTypeId`, including Customer's — confirmed no `[Range]`/per-`RefTypeId` validation exists in `ComplMasterConditionDto.cs` or `ComplMasterDtoValidator.cs` today. A Customer condition saved with `DisplayType = 1` and multiple `ConditionValues` rows persists and round-trips exactly like a Product Type condition configured the same way — this was already true before this fix; the fix only changes which options the *frontend* offers in the Type selector.

## GET `api/compliance-master/get-by-id/{id}` / POST `api/compliance-master/get-all`

Response shape is **unchanged**: `Conditions[].DisplayType`/`ConditionValues` are returned identically regardless of `RefTypeId`; the frontend's Master Preview and `ConditionsView.jsx` already render any `displayType = 1` condition generically by object type name (see `research.md` R19).

## Compliance evaluation (`sp_load_compl_by_conditions`, `sp_load_compl_by_conditions_count`)

Not modified. Verified (`research.md` R19) that both procedures already match a Table-logic condition (`DisplayType = 1`, N rows in `compl_master_condition_values`) identically to how they match a Value condition (1 row) — the matching join (STEP 3) has no branch keyed on `DisplayType` or on `RefTypeCode` other than the pre-existing `COUNTRY` group-match case, which does not apply to `CUSTOMER`. A master with a Customer Table condition (e.g. matching customers A, B, C) is evaluated by the same generic `INNER JOIN … compl_master_condition_values` path already proven correct for Product Type Table conditions.

## Not changed

- `GET api/common/object-types` — unaffected; still returns the same `compl_reference_types` rows (Customer, Product Type, …) used to populate the Type-selector's underlying reference-type list.
- `GET /dynamics/reference-data` (customer/product-type value lookup for the Autocomplete) — unaffected; already used identically by Customer's existing Value/NOT IN options.
- Everything documented in `compliance-master-alerttype.md` and `compl-master-delete.md` — unaffected by this change.
