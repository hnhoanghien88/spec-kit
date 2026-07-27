# Contract: `POST /api/eutr-documents/download-zip` (NEW — Update 10)

> Covers spec FR-069..FR-076 (real Download on `ViewSalesOrderPage.jsx`). This is the one genuinely
> new endpoint this feature introduces — see `research.md` Decisions 36-40 for why its zip-building/
> naming mechanics are cloned from `AllCompliancesController`/`ComplianceDownloadService` rather than
> invented fresh, and why it carries zero EUTR-specific business logic (the client already computes
> the correct folder→file grouping).

## Owner

`compliance-sys-api/src/ComplianceSys.Api/Controllers/EutrDocumentsController.cs` (existing controller,
owned by feature `004-eutr-documents`, edited additively — same file Update 5/6/9 of this feature
already touched/reused). No new controller.

## Authorization

`[Authorize(Policy = "EutrDocuments.ReadAll")]` — reused as-is (same policy already used by
`list-po-references`/`get-all`); no new policy code, no new DB-seeding step.

## Request

```
POST /api/eutr-documents/download-zip
Content-Type: application/json

{
  "salesId": "SO006921",
  "customerCode": "CUST01",
  "customerName": "Acme Furniture Co.",
  "folders": [
    {
      "folderName": "Template A",
      "files": [
        { "fileId": "01ABCXYZ...", "fileName": "Invoice_PO00014347.pdf" },
        { "fileId": "01ABCXYZ...", "fileName": "CARB_Certificate.pdf" }
      ]
    },
    {
      "folderName": "Template B",
      "files": []
    }
  ]
}
```

| Field | Type | Notes |
|---|---|---|
| `salesId` | string | Used only to build the root zip name — no re-lookup performed. |
| `customerCode` | string | Used only to build the root zip name. |
| `customerName` | string | Used only to build the root zip name. |
| `folders[].folderName` | string | Free text (a template's real display name) — sanitized server-side before use as a zip entry path segment (research.md Decision 38). |
| `folders[].files[].fileId` | string | SharePoint file id, fetched via `ISharepointService.DownloadByFileId(fileId)` — the same value already present on every `realAvailableFiles`/`list-po-references` entry (Update 5). |
| `folders[].files[].fileName` | string | Used as-is for the zip entry's file name (after per-folder uniqueness disambiguation, research.md Decision 36/40) — no server-side SharePoint metadata re-lookup. |

The server performs **no** re-derivation of which documents are "Mapped" or which PO belongs to which
template — it trusts the caller's `folders` grouping entirely (research.md Decision 37), the same trust
model already accepted for `AllCompliancesController.DownloadMultipleFiles`'s client-supplied
`FileIds` list.

## Response

### Success — `200 OK`

Binary stream:

```
Content-Type: application/zip
Content-Disposition: attachment; filename="SO006921-CUST01-Acme Furniture Co..zip"
```

- Root zip name = `{sanitize(salesId)}-{sanitize(customerCode)}-{sanitize(customerName)}.zip`
  (cloned from `AllCompliancesController.SanitizeFileNamePart`/`BuildSoZipFileName`).
- One top-level zip entry per `folders[]` item, named after its (sanitized) `folderName`; an entry with
  an empty `files[]` still produces an empty directory entry (`"{folderName}/"`) — spec FR-073.
- Within a folder, same-`fileName` collisions are disambiguated with a `_1`, `_2`, … suffix before the
  extension (cloned from `ComplianceDownloadService.GetUniqueEntryName`) — spec FR-075.

### Nothing to download — `400 Bad Request`

Returned when `folders` is empty, or every folder's `files` list is empty (spec FR-074):

```json
{ "message": "Không có tài liệu nào để tải." }
```

`ViewSalesOrderPage.jsx` is expected to check this condition client-side first (it already has the
exact Mapped-file counts in memory) and avoid calling the endpoint at all in this case — this response
is a defensive backstop for a direct API call, not the primary path (research.md Decision 39).

### Partial/total fetch failure

If one or more `fileId`s fail to download from SharePoint but at least one file across the whole
request succeeds, the zip is still returned with the successful files only (mirrors
`ComplianceDownloadService`'s own "at least one success → still produce output" behavior). If **every**
file fails to download, the endpoint returns `500 Internal Server Error` with a clear message — no
empty/corrupt zip is ever returned as a `200`.

## Non-goals

- No progress tracking, no SSE, no background job, no temp-file cache — fully synchronous,
  single-request/response (research.md Decision 36 — the async `download-so-zip` machinery solves a
  scale problem this endpoint's expected file volume doesn't have).
- No write of any kind to `eutr_documents`/`eutr_references`/`eutr_purchase_attachments` (spec FR-076).
- No new DTO/table/migration beyond the 3 small request DTOs listed in `data-model.md`'s Update 10
  section.
