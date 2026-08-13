# Contract: `POST /api/eutr-documents/download-zip` (NEW — Update 10; extended — Update 21)

> Covers spec FR-069..FR-076 (real Download on `ViewSalesOrderPage.jsx`) and FR-142..FR-151 (Update 21 —
> adds a nested **All** folder alongside the per-template folders). This is the one genuinely new
> endpoint this feature introduces — see `research.md` Decisions 36-40 for why its zip-building/naming
> mechanics are cloned from `AllCompliancesController`/`ComplianceDownloadService` rather than invented
> fresh, and why it carries zero EUTR-specific business logic (the client already computes the correct
> folder→file grouping). Update 21 (research.md Decisions 69-70) generalizes the one field that used to
> assume a folder is always exactly one segment deep (`FolderName` → `FolderPath`) so the same endpoint
> can also express nested step folders — no other part of the contract changes.

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
      "folderPath": ["Template A"],
      "files": [
        { "fileId": "01ABCXYZ...", "fileName": "Invoice_PO00014347.pdf" },
        { "fileId": "01ABCXYZ...", "fileName": "CARB_Certificate.pdf" }
      ]
    },
    {
      "folderPath": ["Template B"],
      "files": []
    },
    {
      "folderPath": ["All", "Forest"],
      "files": []
    },
    {
      "folderPath": ["All", "Forest", "Plantation forest location map"],
      "files": [
        { "fileId": "01ABCXYZ...", "fileName": "File A.pdf" }
      ]
    },
    {
      "folderPath": ["All", "Sawmill"],
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
| `folders[].folderPath` | string[] | **Renamed from `folderName` (string) in Update 21.** Ordered path segments from the zip root — a 1-element array for today's per-template folders (`["Template A"]`), 2+ elements for a nested All step folder (`["All", "Forest", "Plantation forest location map"]`). Each segment is sanitized **independently** server-side (research.md Decision 69) before being joined with `/` into the zip entry's directory prefix — a literal `/` inside one segment's own text is sanitized away like any other invalid filename character, it is never mistaken for a path separator. |
| `folders[].files[].fileId` | string | SharePoint file id, fetched via `ISharepointService.DownloadByFileId(fileId)` — the same value already present on every `realAvailableFiles`/`list-po-references` entry (Update 5). |
| `folders[].files[].fileName` | string | Used as-is for the zip entry's file name (after per-folder uniqueness disambiguation, research.md Decision 36/40) — no server-side SharePoint metadata re-lookup. Disambiguation is scoped to the exact same `folderPath` (a nested step folder's filenames never collide with a same-named file in a sibling/ancestor folder). |

The server performs **no** re-derivation of which documents are "Mapped", which PO belongs to which
template, or which step belongs to the All tree — it trusts the caller's `folders` grouping entirely
(research.md Decision 37), the same trust model already accepted for
`AllCompliancesController.DownloadMultipleFiles`'s client-supplied `FileIds` list. The client is expected
to always include an `All` entry (at minimum `{ "folderPath": ["All"], "files": [] }`) whenever at least
one folder is sent, per FR-147/FR-149 — the server does not special-case or require this, it just zips
whatever `folders` it receives.

## Response

### Success — `200 OK`

Binary stream:

```
Content-Type: application/zip
Content-Disposition: attachment; filename="SO006921-CUST01-Acme Furniture Co..zip"
```

- Root zip name = `{sanitize(salesId)}-{sanitize(customerCode)}-{sanitize(customerName)}.zip`
  (cloned from `AllCompliancesController.SanitizeFileNamePart`/`BuildSoZipFileName`).
- One zip entry per `folders[]` item, named after its `folderPath` segments joined with `/` (each segment
  sanitized independently, Decision 69) — a 1-element `folderPath` produces a top-level entry exactly as
  before Update 21; a multi-element `folderPath` (the new All step folders) produces a nested entry
  (e.g. `"All/Forest/Plantation forest location map/"`), with intermediate directories created implicitly
  by the zip format the same way `System.IO.Compression.ZipArchive` already handles any `/`-containing
  entry name. An entry with an empty `files[]` still produces an empty directory entry
  (`"{folderPath.join('/')}/"`) — spec FR-073/FR-146/FR-147.
- Within a folder, same-`fileName` collisions are disambiguated with a `_1`, `_2`, … suffix before the
  extension (cloned from `ComplianceDownloadService.GetUniqueEntryName`) — spec FR-075/FR-148. This is
  scoped to the exact `folderPath` — a step folder's dedup is independent from its parent/child step
  folders and from every template folder.

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
- No write of any kind to `eutr_documents`/`eutr_references`/`eutr_purchase_attachments`/`eutr_templates`
  (spec FR-076/FR-151).
- No new DTO/table/migration beyond the 3 small request DTOs listed in `data-model.md`'s Update 10
  section — Update 21 only reshapes one existing field (`FolderName` → `FolderPath`) on
  `EutrDownloadZipFolderDto`, it does not add a new DTO type.
- No new endpoint, controller, or policy for the All folder (Update 21) — the same `download-zip` action/
  policy/response shape handles both the per-template folders and the new nested All folder in one call.
