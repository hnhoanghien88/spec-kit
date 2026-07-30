# Contract Delta: `api/compliance-master` — AlertType field

Existing endpoints on `ComplMasterController` (`E:\Working\Eutr\compliance-sys-api\src\ComplianceSys.Api\Controllers\ComplMasterController.cs`) are reused as-is; only their request/response payload shape gains one field. No new routes, no route/method/policy changes. This same field/payload delta is what powers all three user stories: US1 (Create) and US2 (Edit) via the request/response bodies below, and US3 (list column) via the `POST api/compliance-master/get-all` response — no separate contract is needed for the list (see `research.md` R11).

## POST `api/compliance-master` (Create) and PUT `api/compliance-master/{id}` (Update)

Request body (`ComplMasterRequest`) gains:

```json
{
  "...": "existing fields unchanged (code, name, description, validFrom, validTo, numDayAlert, isIndividual, conditions, groupEmails, duplicateId)",
  "alertType": 0
}
```

- `alertType`: integer, one of `0` (All), `1` (Missing), `2` (Expired). Optional in the request; server treats a missing value as `0`.
- Existing `[Authorize(Policy = "ComplianceMaster.Create" | "ComplianceMaster.Update")]` policies are unchanged — no new authorization surface.

## GET `api/compliance-master/get-by-id/{id}` and POST `api/compliance-master/get-all`

Response body (`ComplMasterResponse`, wrapped in the standard `ApiResponse<T>`) gains:

```json
{
  "...": "existing fields unchanged",
  "alertType": 0
}
```

- `alertType` is always present and numeric (never null) — defaults to `0` for any master persisted before this field existed, per spec FR-007.
- `POST api/compliance-master/get-all` is the paged list endpoint the Compliance Master index (US3) uses — its `items[].alertType` is exactly this same field, requiring no separate contract.

## Not changed

- `DELETE api/compliance-master/{id}`, `POST api/compliance-master/bulk-delete`, `POST api/compliance-master/import`, `GET api/compliance-master/export-master-missing`, `GET api/compliance-master/export-master`, `GET api/compliance-master/{masterId}/conditions` — no payload changes (import/export template changes are out of scope, see `research.md` R7).
