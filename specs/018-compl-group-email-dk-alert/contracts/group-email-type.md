# Contract Delta: `api/group-email` — "DK Alert" Type option

Existing endpoints on `ComplGroupEmailController` (`compliance-sys-api/src/ComplianceSys.Api/Controllers/ComplGroupEmailController.cs`) are reused as-is; only the accepted/returned range of an existing field changes. No new routes, no route/method/policy changes.

## POST `api/group-email` (Create) and PUT `api/group-email/{id}` (Update)

Request body (`ComplGroupEmailRequestDto`) — `groupType` now accepts a third value:

```json
{
  "name": "string",
  "groupType": 3,
  "referenceType": 0,
  "isDefault": false
}
```

- `groupType`: integer, one of `1` (Responsible), `2` (Alert), or `3` (DK Alert, new). A value outside this set is rejected with a validation error (new — see `data-model.md`).
- Existing `[Authorize(Policy = "GroupEmail.Create" | "GroupEmail.Update")]` policies are unchanged — no new authorization surface.

## POST `api/group-email/get-all` (paged list — used by the index screen)

Response body (`ComplGroupEmailResponseDto`, wrapped in the standard `ApiResponse<PagedResult<T>>`) — `groupTypeName` now has a third possible value:

```json
{
  "...": "existing fields unchanged (id, name, groupType, isDefault, isAddition, createdDate, createdBy, ...)",
  "groupType": 3,
  "groupTypeName": "DK Alert"
}
```

- `groupTypeName` is server-computed from `groupType` (see `research.md` R2); for `groupType == 3` it is now `"DK Alert"` instead of falling back to `"Alert"`.

## GET `api/group-email/get-by-id/{id}`

Returns the raw `ComplGroupEmail` entity (not the `...ResponseDto`) — unchanged shape; `groupType` may now be `3`. The Group Email index screen's inline edit reads the group's current value from the already-loaded list data (which does carry `groupTypeName`), not from this endpoint — no client behavior depends on `get-by-id` gaining a label field.

## Not changed

- `GET api/group-email` (unfiltered list), `DELETE api/group-email/{id}`, `POST api/group-email/delete-multi` — no payload changes.
- `api/group-email-detail/*` (group member endpoints) — untouched; members have no Type field.
