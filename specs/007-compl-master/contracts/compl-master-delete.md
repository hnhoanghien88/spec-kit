# Contract Delta: `api/compliance-master` — Delete / bulk-delete behavior fix

Existing endpoints on `ComplMasterController` (`E:\Working\Eutr\compliance-sys-api\src\ComplianceSys.Api\Controllers\ComplMasterController.cs`) are reused as-is: **no route, HTTP method, request/response shape, or `[Authorize]` policy changes**. Only the internal implementation behind these endpoints changes (generic hard-delete → soft-delete), so the previously-failing case now succeeds instead of erroring. This is what powers User Story 4.

## DELETE `api/compliance-master/{id}`

Policy: `ComplianceMaster.Delete` (unchanged).

| Response | Before this fix | After this fix |
|----------|------------------|------------------|
| `200 OK` — `ApiResponse<string>.Ok("", "Compliance master deleted successfully")` | Only when the master had **no** linked `compl_references` rows. | Always, for any master that exists and the caller is authorized to delete — including masters with linked `compl_references` rows (e.g. `MAS-01104`). The master is soft-deleted (`IsDelete = 1`); it is not physically removed. |
| `404 Not Found` — `ApiResponse<string>.Fail(...)` | Master id doesn't exist. | Unchanged. |
| `500 Internal Server Error` — `ApiResponse<string>.Fail("Failed to delete Compliance master.")` | **Occurred** whenever the master had linked `compl_references` rows (FK `ON DELETE RESTRICT` violation surfaced as a generic exception) — this was the reported defect. | No longer occurs for this reason. A `500` here would now indicate a genuinely unexpected failure, not the linked-data case. |

Body shape (`ApiResponse<string>`) is unchanged in all cases.

## POST `api/compliance-master/bulk-delete`

Policy: `ComplianceMaster.Delete` (unchanged). Request body (`IEnumerable<long>` of ids) and response shape (`ApiResponse<string>`) unchanged.

Same before/after semantics as single delete, applied per id in the batch, in one transaction — see `data-model.md` (User Story 4 section) and `research.md` R15.

## Not changed

- `POST api/compliance-master` (Create), `PUT api/compliance-master/{id}` (Update), `GET api/compliance-master/get-by-id/{id}`, `POST api/compliance-master/get-all` — unaffected by this fix (see `compliance-master-alerttype.md` for their contract).
- `GET api/compliance-master/export-master-missing`, `GET api/compliance-master/export-master`, `GET api/compliance-master/{masterId}/conditions`, `POST api/compliance-master/import` — unaffected.
- A soft-deleted master (`IsDelete = 1`) is still resolvable via `GET api/compliance-master/get-by-id/{id}` (unchanged, see `research.md` R14) but no longer appears in `POST api/compliance-master/get-all` (paged list) or the "missing" alert-notification query.
