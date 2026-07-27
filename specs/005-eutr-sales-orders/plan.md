# Implementation Plan: EUTR Sales Orders Management

**Branch**: `005-eutr-sales-orders` | **Date**: 2026-07-14 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/005-eutr-sales-orders/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Wire the already-scaffolded `SalesOrderOverviewPage.jsx` (route `/eutr/sales-orders`, menu code
`eutr-sales-orders` — already registered and reachable) to real Sales Order data instead of its
current hardcoded mocks. The 4 real columns (Sales ID, Customer, Customer name, Delivery date) MUST
come from the existing shared D365 reference endpoint (`POST /api/dynamics/reference`) using
reference type **11**, which is the codebase's own pre-defined `ObjectType.SALE_ORDER = 11` — already
used elsewhere (`compliance-view-so`) but **not yet registered** in `ComplDynamicsService.EntityMappings`
(currently returns an empty list for `refType=11`). The Progress column stays a fixed demo/placeholder
value per row (no computation, no new entity/table). This is a small, additive backend change: one
new `EntityMappings` entry + one new mapping case + two new response fields.

**Update 1 (2026-07-16)**: The **Template** column is no longer a fixed demo value (spec supersedes
the old FR-007). It now MUST show real data joined from the existing MySQL table
`eutr_purchase_attachments` (by `SalesId`) and `eutr_templates` (by `TemplateCode` → `Name`), including
the case where one Sales ID has multiple templates (multiple `PurchId` rows with different
`TemplateCode`s). `eutr_purchase_attachments` has **zero existing backend surface** today (verified:
no entity/repository/service/controller references it anywhere), so this update adds one small, new,
read-only backend feature (new `EutrPurchaseAttachmentsController`/`Service`/`Repository`/`Entity`,
cloned from the existing `EutrTemplates` stack — see research.md Decisions 5-8) plus one new
frontend read path (new repository/use case layer, cloned from the existing `eutr-templates` frontend
layering) that the grid calls once per page of visible Sales IDs. No new page, route, or menu entry
is created; the only presentation-layer edit is inside the already-existing
`SalesOrderOverviewPage.jsx`.

**Update 2 (2026-07-16)**: Wire `MapFilePage.jsx` (route `/eutr/sales-orders/:salesId/map-file`,
already registered — unchanged) off its current 100%-mock data to real sources for the existence
check/header, Step 1 (PO list + Save PO Mapping), and Step 2 (template tree + AVAILABLE FILES); Step
2's Upload/Save stay display-only per spec (no backend call for either). Investigation
(`research.md` Decisions 9-14) found almost everything already exists on the backend:
`refType=16` (`RSVNEutrSalesOrderPurchases`) is already fully registered in `ComplDynamicsService`,
including every field Step 1 needs, and is already filterable by `InterCompanyOriginalSalesId`
through the existing generic filter mechanism (zero backend change for Step 1's PO list);
`POST /api/eutr-documents/list-po-references` (feature `004-eutr-documents`) already returns exactly
the document↔PO↔step data Step 2's AVAILABLE FILES needs (zero backend change); `POST /api/eutr-
templates/get-all` + `GET /api/eutr-templates/{id}` (feature `003-eutr-templates`) already expose a
template's full step tree by `Code`/`Id` (zero backend change for Step 2's tree). The only new
backend work: `eutr_purchase_attachments` (read-only since Update 1) gets one new read action
(`GetBySalesIdAsync` — raw `PurchId`+`TemplateCode` rows for one Sales ID, backing both Step 1's
pre-checked state and Step 2's template list) and one new write action (`SavePoMappingAsync` —
transactional delete-then-reinsert for "Save PO Mapping"), both added to the already-existing
`EutrPurchaseAttachmentsController`. No new controller, no migration.

**Update 3 (2026-07-20)**: Two spec changes (FR-031/FR-032/FR-033). Investigation confirmed
`MapFilePage.jsx`'s existing Step 1 checkbox-disable logic (`disabled = !po.eutrTemplate`, added under
Update 2) **already** matches FR-031/FR-032 exactly: it disables a PO only when D365 itself has no
template value, never because the PO lacks a prior `eutr_purchase_attachments` row — so any not-yet-
saved PO with a real `eutrTemplate` is already selectable today, and Save PO Mapping's existing
delete-then-reinsert (research.md Decision 11) already persists whatever is checked at Save time,
newly-checked or previously-saved alike. **No code change is required for FR-031/FR-032** — they are
already satisfied by the Update 2 implementation; this update only re-confirms and documents that
behavior. The one genuine gap is **FR-033**: the Back button (`MapFilePage.jsx`) currently renders
with no `onClick` at all (verified — it is fully inert today), so it gets one small, additive fix:
wire it to the same `navigate('/eutr/sales-orders')` call the page's existing breadcrumb link already
uses. No new file, no backend change, no new route (the target route already exists and is already
registered).

**Update 4 (2026-07-20)**: Wire `ViewSalesOrderPage.jsx` (route `/eutr/sales-orders/:salesId/view`,
already registered — unchanged) off its current 100%-mock data (`MOCK_SALES_ORDERS`, `MOCK_SO_POS`,
`MOCK_SO_PO_MAPPINGS`, `MOCK_AVAILABLE_FILES`, `MOCK_FILE_MAPPINGS`, `EUTR_TEMPLATE_DETAILS_MAP`,
`EUTR_TEMPLATES`) to the **exact same real data sources** `MapFilePage.jsx` already reads (Update 2/3
Decisions 9-14), but rendered strictly **read-only** — no PO tick/Save, no file map/unmap/upload
(spec FR-034..FR-046). Investigation confirms **zero new backend endpoints** are needed: every read
this screen requires (existence/header via `refType=11`, saved-PO list via
`GetBySalesIdAsync`/`by-sales-id/{salesId}` + `refType=16` for display fields, Template Checklist tree
via `EutrTemplates` get-all/GetById, per-step map/missing status via `list-po-references`) already
exists and is already frontend-wired (Decisions 9/10/13/14, reused here verbatim, minus the write-only
pieces — no `SavePoMappingUseCase` call, no `selectedPOs` mutation). The only genuinely new work is
the page component itself (loading/error state, read-only tree render reusing the page's own existing
`ViewNode` component, PO table columns matching Step 1's real fields, Validation Summary recomputed
from real step data) plus **deleting** the now-fully-unused `eutr-sales-orders/mock/*` fixtures —
verified by full-repo search that after this edit no file imports `eutrSalesOrders.js`,
`eutrTemplateDetails.js`, `eutrTemplates.js`, or `eutrSteps.js` anymore (they were already dropped by
`MapFilePage.jsx` in Update 2; `ViewSalesOrderPage.jsx` was the last remaining importer).

**Update 5 (2026-07-27)**: Two spec changes to `MapFilePage.jsx`'s Step 2 (FR-047..FR-052). (a) The
template-tree toolbar (`data-marker="template-tree-toolbar"`) gains a click-to-reload interaction:
clicking a template chip refetches `templatesData` fresh, by extracting Update 2's existing
build-the-tree effect body into a callable `loadTemplatesData` function (research.md Decision 23) —
same in-file pattern already used for `loadPurchaseAttachments` (Decision 12). (b) AVAILABLE FILES'
three currently-static labels ("Map status", "File type", "PO value") become dynamic, sourced from
`eutr_references`: Map status compares the file's `StepId`(s) against the current template tree's
node `stepId`s; File type shows the `RefType`'s name (joined from `eutr_reference_types`); PO value
shows `RefValue` (already returned as `poCode`, previously unused by the frontend). The only backend
change is additive: `POST /api/eutr-documents/list-po-references`'s response DTO
(`EutrDocumentsPoReferenceItemDto`, owned by `004-eutr-documents`) gains `stepIds`/`refType`/
`typeName` fields, sourced by widening its existing SQL (already filters `eutr_references` by
`RefValue IN @PoCodes`) with the columns it was not yet selecting, plus one new `LEFT JOIN
eutr_reference_types` — the exact same enrichment pattern `004-eutr-documents` already uses elsewhere
for its own Type column (research.md Decisions 24-25). No new endpoint, no new DTO class, no
migration, no new frontend file.

**Update 6 (2026-07-27)**: Replaces FR-029/FR-030 (previously demo/no-op) and adds FR-030a/FR-030b:
`MapFilePage.jsx`'s Step 2 Upload button (UploadIcon) and each file's Edit action now perform real
writes by reusing the already-built Add/Edit document popup from `004-eutr-documents`
(`EutrDocumentsFormDialog.jsx`) in place of the page's own two fully-local dialogs (`UploadDialog`,
`MapFileDialog`) and their local-state-only handlers. Investigation (research.md Decisions 26-28)
confirms this is a pure frontend reuse: the popup already performs every real write this update
needs (SharePoint upload via `POST /api/sharepoint/eutr-upload-multi[-by-type]`; `eutr_documents`/
`eutr_references` updates via `PUT /api/eutr-documents/{id}` and `PUT /api/eutr-documents/{id}/step`)
through use cases already registered in DI. The one new question — how to source enough real data to
open the popup in **edit** mode — is answered by reusing `004-eutr-documents`' own paging endpoint
(`POST /api/eutr-documents/get-all`, via `GetPagingEutrDocumentsUseCase`) filtered to a single `Id`,
which is already proven to support `Id`-based filtering server-side (verified in-code: the same
service already injects a `Column="Id"` filter internally for its own search-box rewrite). Zero new
backend endpoint, zero new DTO, zero migration — the entire update is confined to `MapFilePage.jsx`.

**Update 7 (2026-07-27)**: Fixes FR-053..FR-057 — Step 2's AVAILABLE FILES list and its Map status
badges/tree "already mapped" indicators currently match/merge across **all** saved templates' steps
and **all** selected POs' documents, without checking that a document's own PO actually belongs (via
`eutr_purchase_attachments`) to the template being evaluated; since different templates can reuse the
same `StepId` from the shared `eutr_steps` table, this can mark a document "Mapped" against an
unrelated template's node. Investigation confirms this is a **100% frontend-only fix, zero backend
change**: `MapFilePage.jsx` already loads `purchaseAttachments` (`{purchId, templateCode}[]`, from
Update 2's `GetBySalesIdAsync`/`by-sales-id/{salesId}`) and each AVAILABLE FILES entry already carries
its own `poCode` (Update 5); the PO→Template link this fix needs is already sitting in state, just not
used for scoping today. The fix (research.md Decisions 29-30) builds a `purchId → templateCode` lookup
from the already-loaded `purchaseAttachments`, filters AVAILABLE FILES/its derived Map-status
computations to only the currently-viewed template's own PO(s), and recomputes the header's aggregate
progress as a **sum of per-template, correctly-scoped completions** rather than one globally-flattened
match. No new file, no new endpoint, no new use case — confined to `MapFilePage.jsx`'s existing
`useMemo` derivations.

**Update 8 (2026-07-27)**: Extends `ViewSalesOrderPage.jsx`'s Template Checklist toolbar
(`data-marker="template-tree-toolbar"`) to match `MapFilePage.jsx`'s already-shipped Step 2 behavior
(Update 5/Update 7) — spec FR-058..FR-063. Investigation of the shipped `ViewSalesOrderPage.jsx`
confirms its toolbar (lines 815-825) renders three **hardcoded** `Chip`s ("template code1"/"template
code2"/"All", not sourced from `templatesData`) with no `onClick`, and its Template Checklist (lines
872-899) stacks **every** saved template's tree in sequence via `templatesData.map(...)`, with the
per-step "has document" status (`fileMappings`, lines 535-545) matched by `stepName` against
`allDetails = templatesData.flatMap(t => t.flatDetails)` — every saved template's steps flattened
together, with no check that a candidate document's own PO belongs (via `eutr_purchase_attachments`)
to the template the step came from. This is the exact class of cross-template mismatch already found
and fixed for `MapFilePage.jsx` in Update 7. This update is **100% frontend-only, zero backend
change**: `ViewSalesOrderPage.jsx` already loads `purchaseAttachments` (`{purchId, templateCode}[]`,
Update 4's `GetPurchaseAttachmentsBySalesIdUseCase`/`GET /api/eutr-purchase-attachments/by-sales-id/
{salesId}`), and the underlying `list-po-references` response already carries `poCode` per document
(added additively for `004-eutr-documents`/`MapFilePage.jsx` by this feature's own Update 5) —
`ViewSalesOrderPage.jsx`'s own `realAvailableFiles` builder (lines 512-527) simply never copies that
already-present field onto its file objects, unlike `MapFilePage.jsx`'s equivalent builder (which has
carried `poCode` since Update 5). The fix clones, verbatim, `MapFilePage.jsx`'s own
`selectedTemplateCode` state (line 360) + default-first-template effect (lines 500-509) + toolbar chip
markup/`onClick` (lines 1145-1187) + single-tree render (lines 1226-1231), and Update 7's
`purchIdToTemplateCode`/`templateComputations`/summed-progress scoping pattern (Decisions 29-30) —
applied to `ViewSalesOrderPage.jsx`'s own state/derived-state, minus the write-only
reload-on-click-refetch piece (`loadTemplatesData` re-invocation), since this screen stays read-only
(spec FR-063).

**Update 9 (2026-07-27)**: Adds a **View** button next to the existing Edit button on each document
in `MapFilePage.jsx`'s Step 2 AVAILABLE FILES list, opening a read-only file-content preview popup —
spec FR-064..FR-068. Investigation confirms this is a **100% frontend reuse, zero backend change,
zero new component**: `004-eutr-documents`'s own document grid already has a working "View" popup,
`EutrFileViewerDialog.jsx` (`presentation/pages/eutr-documents/components/EutrFileViewerDialog.jsx`),
already wrapping the shared `presentation/components/FilePreviewer.jsx` (renders PDF/DOCX/XLSX/images
inline from base64 content) and already backed by an existing endpoint
(`GET /api/eutr-documents/get-file-by-idref?idRef={fileId}` via `GetEutrDocumentsFileByIdRefUseCase`).
`MapFilePage.jsx`'s own AVAILABLE FILES file objects already carry the `fileId` field this dialog
needs (`realAvailableFiles`, built since Update 5) — nothing new needs to be built to fetch or render
file content. The fix imports `EutrFileViewerDialog` as-is (same cross-feature presentation-to-
presentation import pattern already established for `EutrDocumentsFormDialog` in Update 6), adds one
new small `viewerFile` state (cloned from `004-eutr-documents/index.jsx`'s own `viewerFile` state),
and adds one new `IconButton` (using MUI's `Visibility` icon, matching `004-eutr-documents`'s own View
action in `EutrDocumentsActionCell.jsx`) next to the existing Edit `IconButton` at
`MapFilePage.jsx` lines 1434-1450.

**Update 10 (2026-07-27)**: Replaces `ViewSalesOrderPage.jsx`'s Download button no-op (FR-044/Update 4)
with a real zip download — spec FR-069..FR-076. Investigation found a directly-reusable precedent
already shipped in this exact codebase: `AllCompliancesController`/`ComplianceDownloadService` already
implement "download a Sales Order's files as a folder-organized zip" for the unrelated `AllCompliances`
feature (`POST /api/all-compliances/download-so-zip`), including the **exact** root-zip-name format
this spec's Update 10 clarification requires — `BuildSoZipFileName`/`SanitizeFileNamePart` already
produce `{SalesId}-{CustomerCode}-{CustomerName}.zip` with invalid-filename-character sanitization
(`compliance-sys-api/src/ComplianceSys.Api/Controllers/AllCompliancesController.cs`), and
`ComplianceDownloadService.BuildSoZipWithProgressAsync`/`BuildFolderName`/`GetUniqueEntryName` already
implement folder-organized `ZipArchive` writing (folder = Product there, Template here) with
same-folder filename-collision disambiguation via `ISharepointService.DownloadByFileId` — precisely
the mechanics FR-070/FR-071/FR-075 require. Given this feature's expected file volume (only
**"Mapped"** EUTR documents for one Sales Order's handful of saved templates) is far smaller than
`AllCompliances`' potentially-large multi-product SO export, this update clones the **simpler,
synchronous** sibling pattern already in the same controller (`DownloadMultipleFiles`'s in-memory
`ZipArchive` + direct `File(...)` response) rather than the heavier async/SSE/temp-file-cache
`download-so-zip` machinery — that machinery solves a scale problem this update doesn't have.

The new backend action, `POST /api/eutr-documents/download-zip`, is added to the already-`ISharepointService`-
injected `EutrDocumentsController` (the same direct-controller-injection "thin SharePoint proxy, no
business logic" precedent Update 9/`research.md` Decision 25 already established for
`get-file-by-idref`) — reusing the existing `EutrDocuments.ReadAll` policy (same as `list-po-references`),
zero new policy. Critically, the new endpoint carries **zero EUTR-specific business logic**: it does not
re-derive which documents are "Mapped" or which PO belongs to which template (FR-055/FR-056) — those
rules already live correctly in `ViewSalesOrderPage.jsx`'s own `templateComputations`/`derivedFileMappings`
(Update 7/8, Decisions 29/33). The frontend computes the folder→file grouping from data it already has
loaded and already renders correctly, and the backend's only job is to fetch each `fileId` via the
already-injected `ISharepointService.DownloadByFileId` (same interface/method
`ComplianceDownloadService` already uses — EUTR documents' `FileId` is the same kind of SharePoint
identifier) and zip it into the requested folder path — the same "client supplies exactly what to
download, server just fetches+zips, no server-side re-validation of business rules" shape already
accepted for `AllCompliancesController.DownloadMultipleFiles`'s client-supplied `FileIds` list. See
research.md Decisions 36-40.

**Update 11 (2026-07-27)**: Fixes FR-077..FR-081 — a variable-consistency correction to the Required-step
progress figures, **not** a scope change (an earlier same-session draft of this update mistakenly
broadened `progress.total`/`progress.completed` to also count Optional steps; the requester corrected
this immediately — the count stays Required-only, "toàn bộ template" only ever meant the existing
cross-template aggregation, already true since Update 7). Reviewing every variable in both
`MapFilePage.jsx` and `ViewSalesOrderPage.jsx` that counts mapped/missing step status (as the requester
explicitly asked) surfaced one real inconsistency: `computeProgress()` — the function behind Map File's
`progress.total`/`progress.completed` (`data-marker="progress-bar"`, the "Mapped" chip, and the footer's
"Required: x/y" line) — filters to `requirementType === 'Required'` but never excludes the legacy
`AUTO_SOURCES` `takeFrom` values, while the same screen's own `missingRequired` (footer's "Still missing
X file") **does** exclude them, as do all of `ViewSalesOrderPage.jsx`'s own `requiredDetails`/
`mappedRequired`/`missingRequired`/`pct`. This is a **100% frontend-only, zero-backend-change** fix,
confined to one filter predicate inside `computeProgress()` (`MapFilePage.jsx`): add
`&& !AUTO_SOURCES.includes(d.takeFrom)` to the same `required = details.filter(...)` line that already
checks `requirementType === 'Required'`, so `progress.total - progress.completed` always equals
`missingRequired` on this screen, and Map File's progress figures always match View's for the same Sales
Order (restoring SC-026's matching expectation). `ViewSalesOrderPage.jsx` needs **no** code change — its
four equivalent variables were confirmed already correct by this review. Per the spec's own Assumption,
this has no observable effect on today's real data (`eutr_template_details.takeFrom` is only ever "PO"/
"Upload manual", never an `AUTO_SOURCES` value) — it is a forward-consistency fix, not a behavior change.

## Technical Context

**Language/Version**: .NET 8 (backend, `ComplianceSys.Api`/`Application`/`Domain`/`Infrastructure`); React 18 + Vite (frontend, `compliance-client`) — existing stack, unchanged.

**Primary Dependencies**: ASP.NET Core Web API + Dapper (backend, existing); MUI (Material UI), React Router, existing DI container (`di/repositories.js`) (frontend, existing). No new dependency introduced.

**Storage**: Sales ID/Customer/Customer name/Delivery date are read live from D365 via the existing OData-backed reference lookup (`IDynamicService`/`DynamicsParameterManager`) — unaffected by Update 1. Progress remains a fixed demo constant with no persisted table. **Update 1**: Template is now read from the existing MySQL tables `eutr_purchase_attachments` (join key) and `eutr_templates` (name lookup), via Dapper (`IUnitOfWork`) — the same local-DB access path already used by every other `Eutr*Repository` in this codebase; no migration needed, both tables already exist. **Update 2**: `eutr_purchase_attachments` gains a write path (delete-then-reinsert per Sales ID, same Dapper/`IUnitOfWork` access); Step 1's PO list is read live from D365 (`refType=16`, already-registered `RSVNEutrSalesOrderPurchases`); Step 2's tree/files are read from the already-existing `eutr_template_details`/`eutr_steps` (via `EutrTemplatesController`) and `eutr_references`/`eutr_documents` (via `EutrDocumentsController`'s `list-po-references`) — no new tables, no migration. **Update 4**: no storage change of any kind — `ViewSalesOrderPage.jsx` reads the exact same tables/D365 entities as Update 2/3 through the exact same already-registered endpoints, strictly the read side (no `DeleteBySalesIdAsync`/`SavePoMappingAsync` call from this screen). **Update 5**: no new table, no migration — `eutr_references.StepId`/`RefType` and `eutr_reference_types.Name` already exist and are already reachable from `GetDocumentsByPoCodesAsync`'s existing `WHERE r.RefValue IN @PoCodes` query; the query's `SELECT` list and one new `LEFT JOIN eutr_reference_types` are widened to surface columns it already had access to but wasn't yet projecting. **Update 6**: no new table, no migration — Step 2's Upload/Edit now write to the exact same `eutr_documents`/`eutr_references` tables via the exact SharePoint-upload and update use cases `004-eutr-documents` already calls from its own screen; the one new read (edit-detail hydration) reuses `eutr_documents`'s existing paging query filtered by `Id`. **Update 7**: zero storage change of any kind — no new table, no migration, no new read. The PO↔Template link this fix needs (`eutr_purchase_attachments.PurchId`→`TemplateCode`) is already fetched by the existing `GetBySalesIdAsync`/`by-sales-id/{salesId}` call (Update 2, Decision 12) and already sits in `MapFilePage.jsx`'s `purchaseAttachments` state; this update only changes how that already-fetched data is used client-side to scope AVAILABLE FILES/Map status derivations (research.md Decisions 29-30). **Update 8**: zero storage change of any kind — no new table, no migration, no new read, no DTO change. The same `purchaseAttachments` state `ViewSalesOrderPage.jsx` already loads (Update 4) supplies the PO→Template link, and `list-po-references`'s response already carries `poCode` per document (added additively by this feature's own Update 5, already consumed by `MapFilePage.jsx`) — `ViewSalesOrderPage.jsx` only needs to start reading a field its own already-fetched response already contains (research.md Decisions 31-34). **Update 9**: zero storage change of any kind — no new table, no migration, no new read, no DTO change. The file-content retrieval this update needs already exists end to end (`eutr_documents`'s existing file-content-by-id read path, already exposed via `GET /api/eutr-documents/get-file-by-idref` for `004-eutr-documents`'s own View action) — `MapFilePage.jsx` only needs to call it with a `fileId` it already has on each AVAILABLE FILES entry (present since Update 5). **Update 10**: zero new table, no migration — the new `download-zip` action reads no new data at all; every `fileId`/`fileName`/template-grouping value it receives is already computed client-side from data `ViewSalesOrderPage.jsx` already loaded (Update 4/7/8). The only "storage" touched is the SharePoint-backed file content itself, fetched via the same `ISharepointService.DownloadByFileId(fileId)` method `ComplianceDownloadService` already uses for the unrelated `AllCompliances` zip export — same interface, same underlying SharePoint storage, new caller. **Update 11**: zero storage change of any kind — no new table, no migration, no new read, no DTO change. `AUTO_SOURCES` is a client-side constant already defined in `MapFilePage.jsx`; the fix only changes which already-in-memory `flatDetails` rows a `useMemo` predicate counts, nothing server-side.

**Testing**: Existing backend unit test project `ComplianceSysApi.UnitTests` (add/extend a test for the new `EntityMappings[11]` + mapping case if a suitable existing test class covers `ComplDynamicsService`; **Update 1**: add a test class for `EutrPurchaseAttachmentsRepository`/`Service` if the project has an equivalent existing test for `EutrTemplatesRepository`/`Service` to model it on); frontend has no dedicated automated test harness for this page — verify manually per `quickstart.md`, consistent with how prior EUTR features in this repo were validated. **Update 2**: extend the same `EutrPurchaseAttachmentsRepository`/`Service` test class (if added) with cases for `GetBySalesIdAsync`/`SavePoMappingAsync`; `MapFilePage.jsx` remains manually verified per `quickstart.md` (no automated UI harness in this repo). **Update 4**: zero backend test impact (no backend change); `ViewSalesOrderPage.jsx` is manually verified per `quickstart.md`, same as `MapFilePage.jsx`. **Update 5**: if `004-eutr-documents` has an existing `EutrReferencesRepository`/`EutrDocumentsService.GetPoReferencesAsync` test class, extend it with a case asserting `stepIds`/`refType`/`typeName` are populated correctly for a multi-row document; `MapFilePage.jsx`'s toolbar-reload and dynamic badges are manually verified per `quickstart.md` (Update 5 section), same as every prior frontend-only update in this feature. **Update 6**: zero backend test impact (no backend change) — `MapFilePage.jsx`'s Upload/Edit wiring is manually verified per `quickstart.md` (Update 6 section); if `004-eutr-documents` already has a test class covering `EutrDocumentsService.GetPagedAsync`'s `Id`-filter path, no new test case is needed there either since this update is a new caller of an already-tested behavior, not a new behavior. **Update 7**: zero backend test impact (no backend change) — verified manually per `quickstart.md` (Update 7 section), specifically constructing a fixture with 2 templates sharing a `StepId`/step name to prove no cross-template contamination survives (no automated UI harness in this repo, consistent with every prior frontend-only update in this feature). **Update 8**: zero backend test impact (no backend change) — verified manually per `quickstart.md` (Update 8 section), reusing the same 2-templates-sharing-a-step-name fixture shape already used to verify Update 7, this time exercised against `ViewSalesOrderPage.jsx`'s toolbar/Template Checklist/Validation Summary instead of `MapFilePage.jsx`'s Step 2. **Update 9**: zero backend test impact (no backend change) — if `004-eutr-documents` has an existing test covering `EutrDocumentsService`'s file-content-by-id read path, no new backend test case is needed since this update is a new caller of an already-tested endpoint, not a new behavior; `MapFilePage.jsx`'s new View button is manually verified per `quickstart.md` (Update 9 section), same as every prior frontend-only update in this feature. **Update 10**: no existing test class covers `AllCompliancesController`/`ComplianceDownloadService` (the pattern this update clones) at the unit level in this repo today, so no analogous existing test class exists to extend for the new `EutrDocumentsController.DownloadZip` action either — verified manually per `quickstart.md` (Update 10 section), consistent with how every other backend addition in this feature without a pre-existing test class precedent has been handled; `ViewSalesOrderPage.jsx`'s Download button wiring is manually verified the same way. **Update 11**: zero backend test impact (no backend change) — verified manually per `quickstart.md` (Update 11 section), specifically constructing a fixture with a Required step whose `takeFrom` is one of `AUTO_SOURCES` and no mapped file, then confirming `progress.total - progress.completed` equals `missingRequired` on Map File and matches the equivalent Required/completed/missing numbers on View for the same Sales Order (no automated UI harness in this repo, consistent with every prior frontend-only update in this feature).

**Performance Goals**: Matches spec SC-001 — list loads within ~3s under normal network/load, consistent with other EUTR reference grids (e.g. List PO in `eutr-documents`, refType=15). **Update 1**: the new Template lookup is batched once per visible page of Sales IDs (research.md Decision 7), not per row, to stay within this same budget. **Update 2**: `MapFilePage.jsx` loads one Sales Order at a time (not a paged grid), so its handful of sequential calls (refType=11 → refType=16 → `GetBySalesIdAsync` → per-distinct-`TemplateCode` tree lookup → `list-po-references`) stay well within SC-005's per-screen load budget without needing batching across rows. **Update 4**: `ViewSalesOrderPage.jsx` issues the identical sequential-call shape as `MapFilePage.jsx` (one Sales Order at a time), minus the write call — same budget, no new performance concern. **Update 5**: the toolbar-reload interaction re-issues the same handful of already-cheap `templatesData` calls (Update 2's budget) on click, not on every render — no polling, no new recurring cost; the widened `list-po-references` `SELECT`/`JOIN` adds negligible cost to a query already scanning the same rows. **Update 6**: opening the Edit popup adds exactly one small, `pageSize=1` paging call before the popup renders — negligible added latency, no new recurring cost; Upload/Save inside the reused popup run at whatever cost `004-eutr-documents`' own screen already incurs for the same actions, unchanged by this update. **Update 7**: zero new network calls of any kind — the fix re-shapes `useMemo` derivations over data already in memory (`purchaseAttachments`, `realAvailableFiles`, `templatesData`); computing a `Map` lookup and filtering/grouping per template over a handful of templates/files is negligible client-side work, well within the existing per-screen load budget. **Update 8**: zero new network calls of any kind, same reasoning as Update 7 — the fix re-shapes `ViewSalesOrderPage.jsx`'s own `useMemo` derivations over data already in memory (`purchaseAttachments`, `poReferenceDocs`, `templatesData`), plus copying one already-returned field (`poCode`) onto each file object; negligible added client-side cost, no new recurring cost, no refetch on toolbar click (spec FR-063). **Update 9**: adds exactly one new network call, and only when the user actively opens the popup (not on every render/page load) — `EutrFileViewerDialog`'s own internal `fetchFile` call to `GET /api/eutr-documents/get-file-by-idref`, the same single-file base64 fetch `004-eutr-documents`'s own screen already performs for its View action; no polling, no new recurring cost, no change to Step 2's existing load budget. **Update 10**: adds exactly one new network call, fired only when the user clicks Download (not on page load) — the new `POST /api/eutr-documents/download-zip` request, sized to only the already-loaded, already-"Mapped" documents for this one Sales Order (a small, bounded set, not the potentially-large multi-product volume `AllCompliances`' own SO export handles) — synchronous request/response is acceptable at this scale, consistent with why this update deliberately clones the simpler `DownloadMultipleFiles` shape instead of the async/SSE `download-so-zip` shape (Summary, above); no polling, no background job, no new recurring cost. **Update 11**: zero new network calls of any kind — the fix adds one boolean check (`!AUTO_SOURCES.includes(d.takeFrom)`) inside an already-existing `useMemo` filter predicate; negligible added client-side cost, no change to Step 2's existing load budget.

**Constraints**: MUST reuse the existing shared reference endpoint and `ComplDynReferenceResponseDto` shape (Principle III) for the 4 D365-sourced columns; MUST NOT create a new dedicated endpoint or duplicate `DynController`/`ComplDynamicsService` logic for those; the DTO extension MUST be additive (new nullable fields) so existing consumers of other `refType`s are unaffected. **Update 1**: the new `eutr_purchase_attachments` read path MUST follow the existing 4-layer `Eutr*` backend convention (Principle I/II) since no reusable backend exists for it yet (Principle III only mandates reuse of what already exists); the query MUST dedupe repeated templates per Sales ID and silently skip orphaned `TemplateCode`s (spec FR-007a/Edge Cases) rather than erroring. **Update 2**: MUST NOT add a new `BuildFilterString` special case for `InterCompanyOriginalSalesId` (the existing generic "other column" branch already handles it — Principle III); MUST NOT duplicate `list-po-references` or the `EutrTemplates` get-all/`GetById` endpoints; the new `save-po-mapping` write MUST run delete+reinsert inside one transaction (spec FR-021's "replace, don't diff" semantics) and MUST reject an item with an empty `TemplateCode` (spec FR-022, `NOT NULL` column). **Update 3**: MUST NOT touch the checkbox-disable condition or the `save-po-mapping` delete-then-reinsert logic — both already satisfy FR-031/FR-032 as-is (Principle III: don't re-implement a verified-working behavior); the Back button fix MUST reuse the exact `navigate('/eutr/sales-orders')` call already used by the breadcrumb link, not introduce a second way of expressing the same navigation target. **Update 4**: MUST NOT call `SavePoMappingUseCase`/`save-po-mapping` or mutate any tick/map/unmap/upload state from `ViewSalesOrderPage.jsx` (spec FR-042 — read-only); MUST NOT add any new backend endpoint or duplicate an existing one (Principle III — everything needed is already exposed); MUST delete (not merely stop importing) the now-fully-unused `eutr-sales-orders/mock/*` fixtures once this page no longer references them, consistent with this repo's no-dead-code convention. **Update 5**: MUST widen `EutrDocumentsPoReferenceItemDto`/`GetDocumentsByPoCodesAsync` additively only (new nullable/array fields) so `ViewSalesOrderPage.jsx`'s existing `stepNames`-based consumption of the same endpoint is unaffected (Principle III — don't break an existing consumer of a shared endpoint); MUST NOT introduce a second endpoint or duplicate the `RefType`→`eutr_reference_types.Name` lookup already established by `004-eutr-documents`'s `AttachStepAndConditionInfoAsync` (Principle II — clone that pattern); the toolbar's click-to-reload MUST reuse the exact same `templatesData`-building logic already used on mount (Decision 23), not a second, divergent code path. **Update 6**: MUST reuse `004-eutr-documents`' `EutrDocumentsFormDialog.jsx` component as-is (Principle II/III) — MUST NOT fork/duplicate its JSX or its internal use-case calls into a second, `005`-owned copy; MUST NOT add a new backend endpoint for edit-detail hydration — the existing `POST /api/eutr-documents/get-all` paging endpoint, filtered by `Id`, MUST be reused instead (research.md Decision 27); the old local `UploadDialog`/`MapFileDialog` components and their local-state-only handlers MUST be removed, not kept running in parallel alongside the reused dialog (per the requester's confirmed scope). **Update 7**: MUST NOT add any new fetch/use case/endpoint to obtain the PO→Template link — MUST reuse the already-loaded `purchaseAttachments` state as the single source of truth for it (Principle III — nothing new to reuse or duplicate since the data is already client-side); the header's aggregate progress MUST stay Sales-Order-wide (sum across all templates), not narrowed to only the currently-viewed template, per the spec's explicit Update 7 clarification. **Update 8**: MUST NOT add any new fetch/use case/endpoint for the PO→Template link — MUST reuse the already-loaded `purchaseAttachments` state, same as Update 7 (Principle III); MUST NOT introduce a second, divergent toolbar/single-tree-selection implementation — MUST clone `MapFilePage.jsx`'s own `selectedTemplateCode` state/default-first-template effect/toolbar markup/single-tree render pattern (Principle II); the toolbar's click-to-select-template interaction on this screen MUST NOT call `SavePoMappingUseCase`/`save-po-mapping`, mutate any tick/map/unmap/upload state, or trigger a refetch of PO/document data from the real source (spec FR-063 — unlike Map File's FR-048 reload-on-click, View's already-loaded data is sufficient since it is read-only and no concurrent edit happens on this screen); Validation Summary's aggregate MUST stay Sales-Order-wide (sum across all templates, each scoped correctly before summing), not narrowed to only the currently-viewed template — same reasoning as Update 7 (spec FR-062). **Update 9**: MUST reuse `004-eutr-documents`'s `EutrFileViewerDialog.jsx` component as-is (Principle II/III) — MUST NOT fork/duplicate its JSX, its internal `FilePreviewer` usage, or its internal `GetEutrDocumentsFileByIdRefUseCase` call into a second, `005`-owned copy; MUST NOT add a new backend endpoint or duplicate the existing file-content-by-id read path; the View popup MUST stay strictly read-only (spec FR-066/FR-067) — MUST NOT add any Type/Step/Value/Valid-dates field or Save action to it, which would blur it with the already-existing Edit popup (FR-030). **Update 10**: the new `download-zip` action MUST NOT re-derive Map status/PO↔Template scoping server-side (that logic already lives correctly in `ViewSalesOrderPage.jsx`'s `templateComputations`, Update 7/8) — it MUST accept the already-computed folder→file grouping from the client and only fetch+zip, mirroring `AllCompliancesController.DownloadMultipleFiles`'s existing client-supplied-`FileIds` contract; MUST sanitize `SalesId`/`CustomerCode`/`CustomerName` and each folder name server-side (cloning `SanitizeFileNamePart`/`BuildFolderName`) rather than trusting client-side sanitization, since a malformed/unsanitized name would otherwise reach the filesystem/zip-entry layer; MUST NOT write to `eutr_documents`/`eutr_references`/`eutr_purchase_attachments` (spec FR-076 — read-only, same as every other View-screen action). **Update 11**: `progress.total`/`progress.completed` MUST NOT be broadened to include Optional steps (spec FR-077/FR-078 — Required-only, matching the pre-existing Update 7/FR-057 scope); MUST add the same `AUTO_SOURCES` exclusion `missingRequired` (Map File) and every equivalent View-screen variable already apply (spec FR-079), not a divergent exclusion rule; MUST NOT change `missingRequired`'s own calculation (spec FR-080) or any of `ViewSalesOrderPage.jsx`'s `requiredDetails`/`mappedRequired`/`missingRequired`/`pct` (spec FR-081) — those are confirmed already correct by this review.

**Scale/Scope**: One backend mapping entry + DTO extension for the 4 D365 columns; one existing frontend page updated to swap its data source for those columns and for Progress's already-decided fixed value. **Update 1** adds: 1 new backend entity + repository interface/impl + service interface/impl + controller (5 new backend files) for `eutr_purchase_attachments`; 1 new DTO file; 4 new frontend files (domain interface, api client, REST repository, use case) plus edits to `di/repositories.js` and `SalesOrderOverviewPage.jsx`. Still no new page, route, or menu entry. **Update 2** adds: 2 new controller actions + 2 new repository methods + 2 new service methods (all on already-existing `EutrPurchaseAttachmentsController`/`Service`/`IEutrPurchaseAttachmentsRepository`) + 3 new small DTOs (`PurchaseAttachmentDto`, `SavePoMappingRequestDto`, `PurchaseAttachmentItemDto`); frontend adds 2 new use cases (`GetPurchaseAttachmentsBySalesIdUseCase`, `SavePoMappingUseCase`) + 2 new methods each on the existing `eutrPurchaseAttachmentsApi.js`/`IEutrPurchaseAttachmentsRepository.js`/`RestEutrPurchaseAttachmentsRepository.js` (no new files there, just new methods) plus a substantial rewrite of `MapFilePage.jsx`'s data-loading logic (still no new page/route/menu entry). No new backend files (entity/repository/service/controller classes) are created — Update 2 only adds methods to files Update 1 already created. **Update 3** adds: zero new backend files/methods, zero new frontend files — a single small edit inside `MapFilePage.jsx` (one `onClick` handler on the existing Back `<Button>`, calling the page's already-imported `navigate`). **Update 4** adds: zero new backend files/methods/endpoints, zero new frontend infrastructure files (reuses every use case/repository/api client `MapFilePage.jsx` already established) — a substantial rewrite of `ViewSalesOrderPage.jsx`'s data-loading logic (mock → real, same shape as `MapFilePage.jsx` minus the write path) plus deletion of 4 now-dead mock files (`eutrSalesOrders.js`, `eutrTemplateDetails.js`, `eutrTemplates.js`, `eutrSteps.js`). **Update 5** adds: zero new backend files/endpoints — 3 new properties each on 2 already-existing backend classes (`EutrReferencePoDocumentInfo`, `EutrDocumentsPoReferenceItemDto`, both owned by `004-eutr-documents`) + edits to `EutrReferencesRepository.GetDocumentsByPoCodesAsync`'s SQL and `EutrDocumentsService.GetPoReferencesAsync`'s grouping logic (both also owned by `004-eutr-documents`); zero new frontend files — edits confined to `MapFilePage.jsx` (extract `loadTemplatesData`, wire toolbar `onClick`, carry `poCode`/`stepIds`/`typeName` onto each built file object, replace 3 static Chip labels with computed values). **Update 6** adds: zero new backend files/endpoints — zero new frontend infrastructure files either (reuses `EutrDocumentsFormDialog.jsx` and every use case it internally calls, all already owned by `004-eutr-documents`) — edits confined to `MapFilePage.jsx`: remove the local `UploadDialog`/`MapFileDialog` components and their `handleUpload`/`handleMapDialogConfirm`/`newlyUploadedFiles`/`stepFilePO` local-state logic; import and render `EutrDocumentsFormDialog` twice (Add/Edit); add one new small `loadDocumentForEdit(documentId)` callback (`GetPagingEutrDocumentsUseCase` filtered by `Id`); add one `onSubmitted` callback re-invoking the already-established `GetEutrDocumentsPoReferencesUseCase` call to refresh AVAILABLE FILES/Map status. **Update 7** adds: zero new backend files/endpoints, zero new frontend files — edits confined to `MapFilePage.jsx`'s existing `useMemo` derivations: one new small `purchIdToTemplateCode` lookup built from already-loaded `purchaseAttachments`; `derivedFileMappings`/`isMappedByStepId`/AVAILABLE FILES' file list recomputed per-template (scoped to the currently-viewed `selectedTemplateCode`'s own PO(s)) instead of globally flattened across all templates; `progress` recomputed as a sum of each template's own correctly-scoped completion count instead of one global match. **Update 8** adds: zero new backend files/endpoints, zero new frontend files — edits confined to `ViewSalesOrderPage.jsx`: one new `selectedTemplateCode` state + one new default-first-template `useEffect` (cloned from `MapFilePage.jsx` lines 360/500-509); one added `poCode: poDoc.poCode` field on each `realAvailableFiles` entry (line ~512-527, mirroring `MapFilePage.jsx`'s own builder since its Update 5); one new `purchIdToTemplateCode` `useMemo` + one new `templateComputations` `useMemo` (cloned from Update 7's Decision 29); the toolbar's 3 hardcoded `Chip`s (lines 822-824) replaced with a `templatesData.map(...)` of real chips + `onClick={() => setSelectedTemplateCode(t.templateCode)}` (no refetch, per FR-063); the Template Checklist's `templatesData.map(...)` stacked-tree render (lines 872-899) replaced with a single selected-template tree render (cloned from `MapFilePage.jsx` lines 1226-1231), fed that template's own scoped `derivedFileMappings`/`filesForTemplate` instead of the global `fileMappings`/`realAvailableFiles`; Validation Summary's `requiredDetails`/`mappedRequired`/`missingRequired`/`pct` (lines 580-588) recomputed as a sum of each template's own correctly-scoped completion count (cloned from Update 7's Decision 30), replacing the current single pass over globally-flattened `allDetails`. **Update 9** adds: zero new backend files/endpoints, zero new frontend infrastructure files (reuses `EutrFileViewerDialog.jsx` and every use case it internally calls, already owned by `004-eutr-documents`) — edits confined to `MapFilePage.jsx`: one new `viewerFile` state (cloned from `004-eutr-documents/index.jsx`'s own `viewerFile` state), one new `IconButton` (MUI `Visibility` icon) next to the existing Edit `IconButton` (lines 1434-1450) wired to open it, and one new `<EutrFileViewerDialog />` render call. **Update 10** adds: 1 new controller action (`EutrDocumentsController.DownloadZip`) + 3 new small request DTOs (`EutrDownloadZipRequestDto`/`EutrDownloadZipFolderDto`/`EutrDownloadZipFileDto`) — no new controller, no new Application service, no new repository/entity, no migration, no new policy; frontend adds 1 new use case (`DownloadEutrSalesOrderZipUseCase`) + additive methods on the already-existing `eutrDocumentsApi.js`/`IEutrDocumentsRepository.js`/`RestEutrDocumentsRepository.js` — edits confined to `ViewSalesOrderPage.jsx`: wire the existing Download button's `onClick` to build the `folders` payload from `templateComputations` (Update 8) and trigger the blob-download. **Update 11** adds: zero new backend files/endpoints, zero new frontend files — a single-line edit inside `MapFilePage.jsx`'s existing `computeProgress()` function (add `&& !AUTO_SOURCES.includes(d.takeFrom)` to its `required` filter predicate); no change to `ViewSalesOrderPage.jsx`.

**Target Platform**: Web (existing `compliance-client` SPA consumed via browser, calling existing `compliance-sys-api` Web API).

**Project Type**: Web application (monorepo: frontend + backend), per Constitution "Technology & Structure Constraints".

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Layered Clean Architecture** — PASS. Backend change stays in `ComplianceSys.Application`
  (`ComplDynamicsService` + its response DTO); `ComplianceSys.Api`'s `DynController` is unchanged
  (it already delegates to the service and takes `refType` as a plain parameter). Frontend change
  stays within `presentation/pages/eutr-sales-orders/SalesOrderOverviewPage.jsx`, consuming the
  existing `application/usecases/dynamics/GetReferenceDataUseCase` through the existing
  `domain/interfaces/IDynamicsRepository` → `infrastructure/repositories/RestDynamicsRepository`
  chain — no layer is bypassed. **Update 1**: the new `eutr_purchase_attachments` read path adds its
  own full stack on both sides — backend `Api → Application → Domain`/`Infrastructure`
  (`EutrPurchaseAttachmentsController` → `IEutrPurchaseAttachmentsService`/`EutrPurchaseAttachmentsService`
  → `IEutrPurchaseAttachmentsRepository`/`EutrPurchaseAttachmentsRepository`); frontend
  `domain/interfaces/IEutrPurchaseAttachmentsRepository.js` → `infrastructure/api/eutrPurchaseAttachmentsApi.js` +
  `infrastructure/repositories/RestEutrPurchaseAttachmentsRepository.js` → `application/usecases/
  eutr-purchase-attachments/GetTemplatesBySalesIdsUseCase.js` → `presentation/pages/eutr-sales-orders/
  SalesOrderOverviewPage.jsx`. No layer is skipped on either side. **Update 3**: no backend layer is
  touched at all; the only change is a presentation-layer wiring fix inside `MapFilePage.jsx` (an
  `onClick` calling `useNavigate()`'s `navigate`, already imported/used by this same page's breadcrumb
  link) — no new layer, no layer bypassed.
  **Update 4**: no backend layer is touched at all. `ViewSalesOrderPage.jsx` consumes the same already-
  layered chains `MapFilePage.jsx` uses — `GetReferenceDataUseCase` → `IDynamicsRepository` →
  `RestDynamicsRepository` (refType=11/16), `GetPurchaseAttachmentsBySalesIdUseCase` →
  `IEutrPurchaseAttachmentsRepository` → `RestEutrPurchaseAttachmentsRepository`,
  `GetPagingEutrTemplatesUseCase`/`GetEutrTemplatesUseCase` → their existing `eutr-templates`
  domain/infrastructure chain, `GetEutrDocumentsPoReferencesUseCase` → its existing `eutr-documents`
  chain — no new interface/repository/use-case file, no layer skipped, no layer bypassed. The
  `SavePoMappingUseCase` is deliberately **not** imported by this page (read-only, spec FR-042).
  **Update 5**: backend change stays inside `004-eutr-documents`'s own already-existing
  `Application`/`Infrastructure` files (`EutrDocumentsService.GetPoReferencesAsync`,
  `EutrReferencesRepository.GetDocumentsByPoCodesAsync`, and the two DTO/projection classes they
  already use) — no new layer, no new class, `EutrDocumentsController`'s `list-po-references` action
  is unchanged (still just calls the service). Frontend change stays inside
  `MapFilePage.jsx`, consuming the exact same `GetEutrDocumentsPoReferencesUseCase` →
  `IEutrDocumentsRepository` → `RestEutrDocumentsRepository` chain already wired since Update 2 — no
  new interface/repository/use-case file, no layer skipped.
  **Update 6**: no backend layer is touched at all. Frontend: `MapFilePage.jsx` (presentation) now
  imports `EutrDocumentsFormDialog` — also a presentation-layer component, owned by a different
  feature folder (`presentation/pages/eutr-documents/components/`) — a cross-feature
  presentation-to-presentation import, not a layering violation; the dialog itself already correctly
  delegates every write to `application/usecases/` → `domain/interfaces` → `infrastructure/
  repositories` (its own established chain, unchanged), so `MapFilePage.jsx` never reaches around it
  to call a use case directly for Add/Edit. The one direct new call `MapFilePage.jsx` itself makes
  (edit-detail hydration) reuses the already-layered `GetPagingEutrDocumentsUseCase` →
  `IEutrDocumentsRepository` → `RestEutrDocumentsRepository` chain (same chain Update 5 already wired
  in) — no new interface/repository/use-case file, no layer skipped.
  **Update 7**: no backend layer is touched at all, and no new frontend layer is introduced either —
  the fix lives entirely inside `MapFilePage.jsx`'s own presentation-layer derived-state
  (`useMemo`/`useCallback`), consuming data already delivered through the existing, already-layered
  chains (`GetPurchaseAttachmentsBySalesIdUseCase` for `purchaseAttachments`,
  `GetEutrDocumentsPoReferencesUseCase` for `poCode`-carrying files) — no new interface, repository, or
  use-case file, no layer skipped or bypassed.
  **Update 8**: no backend layer is touched at all, and no new frontend layer is introduced either —
  the fix lives entirely inside `ViewSalesOrderPage.jsx`'s own presentation-layer state/derived-state
  (`useState`/`useEffect`/`useMemo`), consuming data already delivered through the exact same
  already-layered chains Update 4 wired (`GetPurchaseAttachmentsBySalesIdUseCase` for
  `purchaseAttachments`, `GetEutrDocumentsPoReferencesUseCase` for `poCode`-carrying documents) — no
  new interface, repository, or use-case file, no layer skipped or bypassed.
  **Update 9**: no backend layer is touched at all. Frontend: `MapFilePage.jsx` (presentation) now
  imports `EutrFileViewerDialog` — also a presentation-layer component, owned by a different feature
  folder (`presentation/pages/eutr-documents/components/`) — a cross-feature presentation-to-
  presentation import, the same pattern already established for `EutrDocumentsFormDialog` in Update 6,
  not a layering violation; the dialog itself already correctly delegates its one read
  (`GetEutrDocumentsFileByIdRefUseCase`) through `application/usecases/` → `domain/interfaces` →
  `infrastructure/repositories` (its own established chain, unchanged) — `MapFilePage.jsx` never
  reaches around it to call a use case directly for View. No new interface, repository, or use-case
  file, no layer skipped.
  **Update 10**: backend change stays inside `ComplianceSys.Api`'s `EutrDocumentsController` (a thin
  action calling the already-injected `ISharepointService` directly, zero Application/Domain/
  Infrastructure layer touched) — the same "thin SharePoint proxy, no business logic" shape already
  established for `get-file-by-idref` (Update 9/research.md Decision 25), not a new layering pattern.
  Frontend stays inside `ViewSalesOrderPage.jsx` (presentation), consuming a new
  `DownloadEutrSalesOrderZipUseCase` → the existing `domain/interfaces/IEutrDocumentsRepository` →
  `infrastructure/repositories/RestEutrDocumentsRepository` chain (additive methods on already-existing
  files, same chain Update 6/9 already extended) — no layer skipped, no layer bypassed. Critically, no
  Map-status/PO↔Template business logic crosses into the backend at all — that logic stays exactly
  where it already correctly lives (`ViewSalesOrderPage.jsx`'s own `templateComputations`, Update 7/8),
  so this update introduces no duplicate business-rule implementation on the backend side.
  **Update 11**: no backend layer is touched at all, and no new frontend layer is introduced — the fix
  lives entirely inside `MapFilePage.jsx`'s own presentation-layer derived-state (`computeProgress()`,
  called from the existing `progress` `useMemo`), adding one boolean condition to a filter predicate
  over data already delivered through the same already-layered chains Update 7 established; no new
  interface, repository, or use-case file, no layer skipped or bypassed. `ViewSalesOrderPage.jsx` is
  untouched — its equivalent variables were confirmed already correct, not edited.
- **II. Reference-Pattern Reuse** — PASS. The concrete reference for "register a new refType end to
  end" is how `EUTR_PURCH_ORDER` (`refType=15`) and `EUTR_SALES_ORDER_PURCHASE` (`refType=16`) were
  added for feature `004-eutr-documents` (see that spec's Update 4): an `EntityMappings` entry in
  `ComplDynamicsService`, a `case` in `MapDynamicsResponse`, and frontend consumption via
  `GetReferenceDataUseCase`/`useReferenceObjects` (see `EutrDocumentsAdd.jsx`'s
  `EUTR_PURCH_ORDER_REF_TYPE = 15` constant and its `fetchPoList` calls). This feature clones that
  exact pattern for `refType=11`. **Update 1**: the new `eutr_purchase_attachments` backend stack
  clones `EutrTemplates` end to end (closest same-shape existing table-backed feature — entity,
  repository, service, controller, all under the `Eutr*` naming/layering convention), and the new
  frontend files clone the `eutr-templates` feature's frontend layering (`domain/entities`,
  `domain/interfaces`, `infrastructure/api`, `infrastructure/repositories`,
  `application/usecases/eutr-templates/Get*UseCase.js`) — see research.md Decisions 5 and 7.
  **Update 2**: the two new `EutrPurchaseAttachmentsController` actions clone
  `EutrDocumentsService.DeleteAsync`'s Update 9 transaction shape (delete-then-reinsert under one
  `IUnitOfWork`) and `EutrUploadService`'s Update 7 per-row `AddAsync`-with-manual-audit-fields loop;
  everything else in Update 2 (refType=16 filter, `list-po-references`, `EutrTemplates` get-all/
  GetById) is pure reuse of already-working endpoints, not a clone of a pattern — see research.md
  Decisions 9-14.
  **Update 4**: the concrete reference for "read-only sibling of an already-real screen" is
  `MapFilePage.jsx` itself (Update 2/3) — every data-loading `useEffect` in `ViewSalesOrderPage.jsx` is
  a direct clone of `MapFilePage.jsx`'s corresponding effect, with the write-only pieces (Save PO
  Mapping button/handler, tick/map/unmap/upload handlers) omitted rather than reinvented; the read-only
  tree render reuses this same page's own pre-existing `ViewNode` component (already read-only by
  construction, just fed mock data before) instead of `MapFilePage.jsx`'s interactive `TreeNode` — see
  research.md Update 4 Decisions.
  **Update 5**: the concrete reference for "widen an existing DTO additively for a `RefType`→name
  lookup" is `004-eutr-documents`'s own `AttachStepAndConditionInfoAsync` (Update 13/14 of that spec)
  — `GetPoReferencesAsync`'s new `StepIds`/`RefType`/`TypeName` grouping clones that same
  first-non-null/distinct-list aggregation shape rather than inventing a new one; the toolbar
  click-to-reload clones this same file's own `loadPurchaseAttachments` extraction (Decision 12) —
  see research.md Decisions 23-25.
  **Update 6**: the concrete reference for "reuse an existing screen's Add/Edit dialog from a
  different feature's screen" is `004-eutr-documents`'s own `EutrDocumentsFormDialog.jsx` itself —
  reused verbatim (same component, same `open`/`mode`/`initialData`/`onClose`/`onSubmitted` props
  contract), not cloned/forked into a second copy. The edit-detail fetch clones
  `004-eutr-documents`'s own grid data source (`GetPagingEutrDocumentsUseCase`, filtered to one row)
  rather than inventing a new fetch shape — see research.md Decisions 26-28.
  **Update 7**: the concrete reference for "extract a derived computation into its own scoped
  `useMemo`" is this same file's own established `loadPurchaseAttachments`/`loadTemplatesData`
  extraction pattern (Decisions 12/23) — the per-template scoping fix follows that same in-file
  precedent (compute once, reuse at each call site) rather than inventing a new state-management
  approach; see research.md Decisions 29-30.
  **Update 8**: the concrete reference for "give the View screen the same template-tree-toolbar
  behavior as its Map File sibling" is `MapFilePage.jsx` itself — `selectedTemplateCode` state,
  default-first-template effect, toolbar chip markup/`onClick`, single-tree render, and the
  `purchIdToTemplateCode`/`templateComputations`/summed-progress scoping pattern (Update 7, Decisions
  29-30) are all cloned verbatim into `ViewSalesOrderPage.jsx`, consistent with Update 4's own
  precedent of treating `MapFilePage.jsx` as this screen's direct model; the write-only
  reload-on-click refetch (Update 5's `loadTemplatesData` re-invocation) is deliberately omitted, not
  reinvented, since this screen stays read-only (spec FR-063) — see research.md Decisions 31-34.
  **Update 9**: the concrete reference for "reuse an existing screen's file-preview popup from a
  different feature's screen" is `004-eutr-documents`'s own `EutrFileViewerDialog.jsx` itself —
  reused verbatim (same component, same `open`/`fileId`/`fileName`/`onClose` props contract), not
  cloned/forked into a second copy — the exact same reuse pattern Update 6 already established for
  `EutrDocumentsFormDialog.jsx`. The new `viewerFile` state clones `004-eutr-documents/index.jsx`'s
  own `viewerFile` state shape (`{ open, fileId, fileName }`) rather than inventing a new one.
  **Update 10**: the concrete reference for "download a Sales Order's files as a folder-organized zip"
  is `AllCompliancesController`/`ComplianceDownloadService`'s own already-shipped `download-so-zip`/
  `download-all` actions (a different, unrelated feature) — `BuildSoZipFileName`/`SanitizeFileNamePart`
  (root zip name = `{SalesId}-{CustomerCode}-{CustomerName}.zip`, sanitized) and
  `BuildFolderName`/`GetUniqueEntryName` (folder-organized `ZipArchive` entries with per-folder
  filename-collision disambiguation) are cloned directly into the new `EutrDocumentsController` action
  rather than invented fresh, and `ISharepointService.DownloadByFileId` is reused verbatim (same
  interface `ComplianceDownloadService` already calls). The simpler, synchronous `DownloadMultipleFiles`
  shape (in-memory `ZipArchive` + direct `File(...)` response) is cloned instead of the heavier async/
  SSE/temp-file-cache `download-so-zip` shape, since this update's expected file volume doesn't need
  that machinery (see Summary, above) — Principle II favors cloning the shape that actually matches
  this update's scale, not the most feature-rich sibling regardless of fit.
  **Update 11**: the concrete reference for the `AUTO_SOURCES` exclusion is this feature's own
  `missingRequired` (Map File) and `ViewSalesOrderPage.jsx`'s own `requiredDetails`/`mappedRequired`/
  `missingRequired` — the exact same condition already applied in 3 places is cloned into the 4th
  (`computeProgress()`), not invented fresh.
- **III. Reuse Existing Backend** — PASS, with a verified, scoped gap. `POST /api/dynamics/reference`
  already exists and MUST be reused as-is (no new controller action). The only backend change for
  the 4 D365 columns is filling a verified gap: `refType=11` (`ObjectType.SALE_ORDER`, already
  defined in `ComplEnum.cs` and already treated as "Sales order" elsewhere, e.g.
  `compliance-view-so/index.jsx`'s `isSalesOrderRefType = refType === "11"`) has **no**
  `EntityMappings` entry today, so it currently returns an empty list. The underlying D365 entity
  (`RSVNSalesOrderOpenInvoiceCogs`, `ModelType = 11`) already has every field needed (`SalesId`,
  `CustAccount`, `CustName`, `DeliveryDate`) — it is just registered under the unrelated raw key `0`
  in `EntityMappings`, not under `11`. No new D365 entity class is created. **Update 1**: verified by
  full-repo search that `eutr_purchase_attachments` has **zero** existing backend code referencing it
  — there is nothing to reuse for the Template column, so Principle III does not apply to block a new
  read path here; it only requires that no *already-existing* backend for this table be duplicated
  (none exists) and that the D365 reference endpoint stay untouched by this addition (confirmed — the
  new controller/service/repository are entirely separate files).
  **Update 2**: verified `refType=16`'s `EntityMappings` entry, `InterCompanyOriginalSalesId` filter
  support, `POST /api/eutr-documents/list-po-references`, and `EutrTemplatesController`'s
  `get-all`/`GetById` actions **all already exist and already return every field needed** (research.md
  Decisions 10/13/14) — Principle III requires reusing them as-is, which is exactly what
  `MapFilePage.jsx`'s rewrite does; zero new backend code for any of the three. The only verified gap
  is `eutr_purchase_attachments`'s write side (never existed, Update 1 only added a read) — Principle
  III doesn't block filling a genuine gap, and the two new actions are added to the controller Update 1
  already created (no new controller/service/repository/entity class, just new methods on them).
  **Update 4**: verified every read `ViewSalesOrderPage.jsx` needs (refType=11, `by-sales-id/{salesId}`,
  refType=16, `EutrTemplates` get-all/GetById, `list-po-references`) is already exposed and already
  frontend-wired from Update 1/2 — zero new backend code. Principle III is satisfied in its purest
  form here: no gap exists to fill, this update is 100% reuse of already-working endpoints.
  **Update 5**: verified `list-po-references`' underlying query already scans the exact rows needed
  (`eutr_references` filtered by `RefValue IN @PoCodes`) — the gap is narrowly scoped to 3 unselected
  columns (`StepId`, `RefType`, plus a join for its name), not a missing query or endpoint. Reused
  as-is: `poCode`/`RefValue` for PO value (zero change), the whole `EutrTemplates`
  get-all/GetById chain for the toolbar reload (same calls Update 2 already makes, just re-invoked on
  click). No new endpoint is introduced; the one DTO widened is owned by another feature
  (`004-eutr-documents`) and is edited in place, additively, rather than forked or duplicated for this
  feature's own use.
  **Update 6**: verified `004-eutr-documents` already exposes every write this update needs —
  `POST /api/sharepoint/eutr-upload-multi[-by-type]` (real Upload), `PUT /api/eutr-documents/{id}` +
  `PUT /api/eutr-documents/{id}/step` (real Edit/Save) — all already implemented and already
  DI-wired, reused as-is through the reused `EutrDocumentsFormDialog.jsx` component; zero new backend
  code. The one read this update newly needs (edit-detail hydration) is served by
  `POST /api/eutr-documents/get-all` (already-existing paging endpoint), filtered to a single `Id` — a
  filter shape already proven server-side-supported (verified in-code: `EutrDocumentsService`'s own
  `ApplySearchBoxFiltersAsync` already injects a `Column="Id"` filter into this same pipeline) rather
  than a new "get by id" action; Principle III is satisfied in its purest form here too — no gap
  exists to fill, this update is 100% reuse of already-working endpoints.
  **Update 7**: verified the PO→Template link needed for correct scoping (`eutr_purchase_attachments`'s
  `PurchId`↔`TemplateCode`) is already fully available client-side via `purchaseAttachments` (fetched
  by Update 2's `GetBySalesIdAsync`/`by-sales-id/{salesId}` call, already present in
  `MapFilePage.jsx`'s state) — no new endpoint, no new DTO field, no new query is needed to close this
  gap; it is purely a client-side under-use of data already delivered. Principle III is satisfied in
  its purest form: zero new backend code, 100% reuse of an already-fetched response.
  **Update 8**: verified both facts this fix needs are already available with zero backend change:
  `purchaseAttachments` (fetched by `ViewSalesOrderPage.jsx` itself since Update 4, same call/response
  shape Update 7 already relies on for `MapFilePage.jsx`) and `poCode` per document (already returned
  by `list-po-references` since this feature's own Update 5 — `ViewSalesOrderPage.jsx`'s own
  `realAvailableFiles` builder simply never read it). Principle III is satisfied in its purest form:
  zero new backend code, 100% reuse of already-fetched/already-returned data.
  **Update 9**: verified `004-eutr-documents` already exposes the exact read this update needs —
  `GET /api/eutr-documents/get-file-by-idref` (file content by id, already implemented and already
  DI-wired) — reused as-is through the reused `EutrFileViewerDialog.jsx` component; zero new backend
  code. `MapFilePage.jsx`'s own AVAILABLE FILES entries already carry `fileId` (present since Update
  5) — no new field, no new query. Principle III is satisfied in its purest form here too — no gap
  exists to fill, this update is 100% reuse of an already-working endpoint and an already-available
  field.
  **Update 10**: verified `ISharepointService.DownloadByFileId`/`GetFileNamesInBatch` already exist and
  are already DI-wired (reused by `ComplianceDownloadService`, a different feature) — no new SharePoint
  integration code. The one genuinely new piece is the folder-organized `ZipArchive`-writing action
  itself, since no existing endpoint returns a client-supplied, folder-grouped zip for arbitrary
  `fileId`s today (`download-so-zip`/`download-all` both derive their own file list server-side from
  Compliance-specific data, not from a client-supplied grouping) — this is the verified, scoped gap
  Principle III allows filling: a new, small, generic (non-EUTR-specific) zip-assembly action, modeled
  on the existing zip-writing mechanics rather than duplicating any *working* endpoint.
  **Update 11**: no backend endpoint of any kind is touched — Principle III is not implicated;
  this is a pure frontend derived-state consistency fix.
- **IV. Vietnamese Comments; Localizable UI Labels** — PASS. New/changed backend code comments are
  Vietnamese. The frontend page's existing column headers ("Sales ID", "Customer", "Customer Name",
  "Template", "Delivery Date", "Progress") were already shipped in English by a prior iteration of
  this scaffold; this feature does not introduce new English labels, it only rewires data — so it is
  not a new deviation requiring a spec-level justification. Search placeholder and empty-state text
  remain Vietnamese as already implemented. **Update 1**: all new backend files
  (`EutrPurchaseAttachmentsController`/`Service`/`Repository`/`Entity`) MUST carry Vietnamese
  comments, matching the unaccented-ASCII Vietnamese comment style already used in
  `EutrTemplatesRepository.cs`/`IEutrTemplatesRepository.cs`; the Template cell's rendered content is
  data (template names), not a new UI label, so no localization decision is introduced.
  **Update 2**: the two new methods/actions on `EutrPurchaseAttachmentsController`/`Service`/
  `Repository` MUST carry Vietnamese comments matching that same file's existing style (Update 1); no
  new UI label is introduced in `MapFilePage.jsx` — its existing Vietnamese/English labels (Step 1/2
  headers, buttons) are unchanged, only the data feeding them changes. `TAKE_FROM_LABELS`/
  `REQUIREMENT_LABELS` (`utils/helpers.js`, already English: "PO"/"Upload manual"/"Optional"/
  "Required") are already the codebase's own precedent for these two enums (used by
  `003-eutr-templates`'s own screens) — reused as-is, not a new localization decision for this feature.
  **Update 4**: new/changed data-loading code in `ViewSalesOrderPage.jsx` MUST carry Vietnamese
  comments matching `MapFilePage.jsx`'s own style (it is the direct model per Principle II above); no
  new UI label is introduced — the screen keeps its existing labels ("Purchase Orders đã chọn",
  "Template Checklist", "Validation Summary", "Edit / Map File", "Download") verbatim, only the data
  feeding them changes from mock to real.
  **Update 5**: new/changed backend code (the widened SQL/DTO properties in `004-eutr-documents`'s
  files) MUST carry Vietnamese comments matching that file's own existing unaccented-ASCII style
  (already the convention in `EutrReferencesRepository.cs`, see its existing comments). The two new
  labels this update replaces ("Map status"/"File type"/"PO value" were already English placeholders
  in `MapFilePage.jsx`) render **values**, not new labels — "Mapped"/"No map" are the only new
  user-facing strings introduced, kept in English to match this same row's existing English chip
  labels (e.g. "R" for Required, `node.takeFrom` values) rather than mixing languages within one row.
  **Update 6**: no new backend code (no new comments needed there). `MapFilePage.jsx`'s own edits
  (removing `UploadDialog`/`MapFileDialog`, wiring the two `EutrDocumentsFormDialog` instances) MUST
  carry Vietnamese comments matching this file's own existing comment style (already Vietnamese, e.g.
  the FR-029/FR-030 references left by Update 2/5's own edits). No new user-facing label is
  introduced by `MapFilePage.jsx` itself — the reused popup's own labels ("Add EUTR documents"/"Edit
  EUTR document", already English per `004-eutr-documents`'s existing implementation) are unchanged,
  just now rendered from within a second screen.
  **Update 7**: no new backend code (no new comments needed there). `MapFilePage.jsx`'s edited
  `useMemo` derivations MUST carry Vietnamese comments matching this file's own existing style
  (e.g. the FR-049 comment already left by Update 5's edit, being replaced/updated here to reference
  FR-055/FR-056). No new user-facing label is introduced — "Mapped"/"No map" (Update 5) remain the
  only badge text, now computed with corrected scoping rather than a new string.
  **Update 8**: no new backend code (no comments needed there). `ViewSalesOrderPage.jsx`'s new/edited
  state and derived-state MUST carry Vietnamese comments matching `MapFilePage.jsx`'s own comment
  style for the exact same logic (e.g. its Update 7 comments on `purchIdToTemplateCode`/
  `templateComputations`, lines 568-581, are the direct model to clone), consistent with Update 4's
  own precedent of modeling this file's comments on `MapFilePage.jsx`. No new user-facing label is
  introduced — toolbar chip labels become dynamic template names (data, not a new UI string); the
  existing "Mapped"/"Missing" legend text (already shipped) is unchanged.
  **Update 9**: no new backend code (no comments needed there). `MapFilePage.jsx`'s own edits (the new
  `viewerFile` state, the new View `IconButton`, the new `<EutrFileViewerDialog />` render call) MUST
  carry Vietnamese comments matching this file's own existing style (already Vietnamese, e.g. the
  FR-029/FR-030 references left by Update 2/5/6's own edits). No new user-facing label is introduced
  by `MapFilePage.jsx` itself — the reused popup's own labels/tooltips ("File Preview"/"Download"/
  "Close", already English per `004-eutr-documents`'s existing implementation) are unchanged, just now
  rendered from within a second screen; the new View `IconButton`'s own tooltip text ("View document"
  or equivalent) follows this file's existing English tooltip convention for its sibling Edit/Upload
  icon buttons ("Edit document").
  **Update 10**: the new `EutrDocumentsController.DownloadZip` action MUST carry Vietnamese comments,
  matching this same file's existing comment style (e.g. the Update 9 comment left above
  `GetFileByIdRef`, line 154-156). No new user-facing label is introduced — the Download button
  (`ViewSalesOrderPage.jsx`) keeps its existing label/icon; the one new user-facing string this update
  adds (the "không có tài liệu nào để tải" empty-state message, FR-074) is written in Vietnamese,
  matching this page's own existing Vietnamese error/empty-state copy (e.g. "Sales Order không tồn
  tại", "Chưa chọn PO nào").
  **Update 11**: the one-line edit inside `computeProgress()` MUST carry a Vietnamese comment matching
  `MapFilePage.jsx`'s own existing comment style (e.g. its Update 7 comment on `missingRequired`, which
  already documents the `AUTO_SOURCES`-equivalent exclusion this fix now mirrors). No user-facing label
  changes — per spec FR-077 (revised), the "required steps"/"Required" wording stays exactly as-is,
  since the count remains Required-only.
- **V. Routing & Menu Registration** — PASS, already satisfied. Route (`/eutr/sales-orders` →
  `MainRoutes.jsx`'s implicit resolver path) and menu (`code: 'eutr-sales-orders'`, `url:
  '/eutr/sales-orders'`, title "Sales orders" in `ComplianceSystem.jsx`) and `RouteResolver.jsx`'s
  `codeToComponent['eutr-sales-orders'] = <SalesOrderOverviewPage />` all already exist. Per
  memory/prior findings, actual reachability additionally requires the backend-seeded `userMenu` +
  `canAccessMenu('eutr-sales-orders')` permission for the user's role — this is a DB/ops step
  outside this feature's code, consistent with every other EUTR screen; no action item here beyond
  noting the dependency. **Update 1**: the new endpoint's authorization policy
  (`EutrPurchaseAttachments.Read`, research.md Decision 8) is a second, analogous DB-seeding
  dependency — no new route/page/menu entry, just one more permission code an operator must seed
  before the Template column can return data for a given role (same category of ops dependency
  already noted above for `eutr-sales-orders` itself).
  **Update 2**: the new `EutrPurchaseAttachments.Update` policy (research.md Decision 15) is a third
  such DB-seeded dependency, additive to `EutrPurchaseAttachments.Read` (Update 1) — no new route,
  page, or menu entry; `MapFilePage.jsx`'s route (`/eutr/sales-orders/:salesId/map-file`) already
  exists and is unaffected.
  **Update 3**: the Back button's target (`/eutr/sales-orders`) is the same already-registered
  Overview route used everywhere else in this feature (Decision 3/`ComplianceSystem.jsx` menu entry)
  — no new route, page, or menu entry; this update only makes an existing, currently-inert button
  invoke `navigate()` on that already-correct target.
  **Update 4**: no policy/route/menu change at all — `ViewSalesOrderPage.jsx`'s own route
  (`/eutr/sales-orders/:salesId/view`) already exists and is unaffected; it reuses the two already-
  DB-seeded read policies (`EutrPurchaseAttachments.Read` + whatever the D365/`EutrTemplates`/
  `EutrDocuments` endpoints already require) with no new policy code — this update is 100% additive
  reuse of already-granted read access, nothing new for an operator to seed.
  **Update 5**: no policy/route/menu change at all — `list-po-references` keeps whatever
  authorization policy it already carries (owned by `004-eutr-documents`); no new action, no new
  route, no new menu entry; the toolbar/badges are new interactions inside `MapFilePage.jsx`'s
  already-reachable Step 2, not a new screen.
  **Update 6**: no policy/route/menu change at all — every endpoint the reused dialog/edit-detail
  fetch calls (SharePoint upload, document update, reference-step update, paging) keeps whatever
  authorization policy it already carries under `004-eutr-documents`; no new action, no new route, no
  new menu entry; Upload/Edit remain interactions inside Step 2 of the already-reachable Map File
  screen.
  **Update 7**: no policy/route/menu change at all — no new endpoint is called, so no new
  authorization policy is needed; the fix is a display-logic correction inside Step 2 of the
  already-reachable Map File screen.
  **Update 8**: no policy/route/menu change at all — `ViewSalesOrderPage.jsx`'s own route
  (`/eutr/sales-orders/:salesId/view`) already exists and is unaffected; no new endpoint is called
  (same data sources as Update 4, just one more field read), so no new authorization policy is
  needed; the fix is a display-logic addition inside the already-reachable View screen.
  **Update 9**: no policy/route/menu change at all — `MapFilePage.jsx`'s own route
  (`/eutr/sales-orders/:salesId/map-file`) already exists and is unaffected; the one endpoint the
  new View button calls (`get-file-by-idref`) keeps whatever authorization policy it already carries
  under `004-eutr-documents`; no new action, no new route, no new menu entry — View is a new
  interaction inside the already-reachable Step 2, not a new screen.
  **Update 10**: no route/menu change at all — `ViewSalesOrderPage.jsx`'s own route
  (`/eutr/sales-orders/:salesId/view`) already exists and is unaffected. The new `download-zip` action
  reuses the already-DB-seeded `EutrDocuments.ReadAll` policy (same policy `list-po-references` already
  uses) — no new policy code, no new ops-seeding step; Download is a new interaction inside the
  already-reachable View screen, not a new screen.
  **Update 11**: no route/menu/policy change at all — no new endpoint is called, so no new
  authorization policy is needed; the fix is a display-value correction inside the already-reachable
  Map File screen's existing progress-bar area.

No violations to record in Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/005-eutr-sales-orders/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
│   ├── dynamics-reference-refType-11.md
│   ├── eutr-purchase-attachments.md   # NEW (Update 1)
│   ├── eutr-purchase-attachments-map-file.md   # NEW (Update 2)
│   ├── map-file-reused-endpoints.md            # NEW (Update 2) - traceability only, no new contract
│   │                                            # EDIT (Update 5): documents the additive DTO widening
│   │                                            #       of list-po-references (stepIds/refType/typeName)
│   │                                            # EDIT (Update 6): documents the 4 reused
│   │                                            #       004-eutr-documents write/read endpoints now
│   │                                            #       consumed by MapFilePage.jsx's Upload/Edit
│   │                                            # EDIT (Update 9): documents the reused
│   │                                            #       get-file-by-idref read now consumed by
│   │                                            #       MapFilePage.jsx's new View button
│   ├── view-sales-order-reused-endpoints.md    # NEW (Update 4) - traceability only, no new contract
│   │                                            # EDIT (Update 8): notes that list-po-references'
│   │                                            #       poCode field (Update 5, already consumed by
│   │                                            #       MapFilePage.jsx) is now also read by
│   │                                            #       ViewSalesOrderPage.jsx - zero contract change
│   └── eutr-documents-download-zip.md          # NEW (Update 10) - the one genuinely new endpoint
│                                                #       contract this feature introduces
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

**Structure Decision**: Existing monorepo, web application layout (backend + frontend), per
Constitution "Technology & Structure Constraints". No new top-level structure — only edits inside
the two existing projects.

```text
compliance-sys-api/
└── src/
    ├── ComplianceSys.Application/
    │   ├── Services/ComplDynamicsService.cs        # EDIT: EntityMappings[11] + MapDynamicsResponse case 11
    │   ├── Dtos/Response/ComplDynReferenceResponseDto.cs  # EDIT: add CustAccount, DeliveryDate (nullable)
    │   ├── Dtos/Response/SalesOrderTemplateDto.cs         # NEW (Update 1)
    │   ├── Interfaces/Repositories/IEutrPurchaseAttachmentsRepository.cs  # NEW (Update 1)
    │   │                                            # EDIT (Update 2): + GetBySalesIdAsync, DeleteBySalesIdAsync
    │   ├── Interfaces/Services/IEutrPurchaseAttachmentsService.cs         # NEW (Update 1)
    │   │                                            # EDIT (Update 2): + SavePoMappingAsync (calls the new
    │   │                                            #       repository methods + IRepository<EutrPurchaseAttachments,int>)
    │   ├── Services/EutrPurchaseAttachmentsService.cs                    # NEW (Update 1)
    │   │                                            # EDIT (Update 2): implement SavePoMappingAsync (Decision 11)
    │   ├── Dtos/Response/PurchaseAttachmentDto.cs           # NEW (Update 2) - {SalesId,PurchId,TemplateCode}
    │   ├── Dtos/Request/SavePoMappingRequestDto.cs          # NEW (Update 2) - {SalesId, Items[]}
    │   ├── Dtos/Request/PurchaseAttachmentItemDto.cs        # NEW (Update 2) - {PurchId,TemplateCode}
    │   └── DependencyInjection.cs                  # EDIT (Update 1): register the two new interfaces
    ├── ComplianceSys.Domain/
    │   └── Entities/EutrPurchaseAttachments.cs     # NEW (Update 1) - unchanged in Update 2
    ├── ComplianceSys.Infrastructure/
    │   ├── Repositories/EutrPurchaseAttachmentsRepository.cs  # NEW (Update 1)
    │   │                                            # EDIT (Update 2): + GetBySalesIdAsync, DeleteBySalesIdAsync
    │   └── DependencyInjection.cs                  # EDIT (Update 1): register the new repository
    └── ComplianceSys.Api/
        └── Controllers/EutrPurchaseAttachmentsController.cs  # NEW (Update 1)
                                                      # EDIT (Update 2): + GET by-sales-id/{salesId},
                                                      #       + POST save-po-mapping (policy
                                                      #       EutrPurchaseAttachments.Update, NEW policy code)

# Update 5 (2026-07-27) — files below are owned by feature 004-eutr-documents, edited additively
# (no new file, no new endpoint; widened response of the already-existing list-po-references action):
compliance-sys-api/
└── src/
    └── ComplianceSys.Application/
        ├── Dtos/Response/EutrDocumentsPoReferenceItemDto.cs   # EDIT (Update 5): + StepIds (long[]),
        │                                                       #       RefType (byte?), TypeName (string?)
        ├── Dtos/Response/EutrReferencePoDocumentInfo.cs        # EDIT (Update 5): + StepId (long?),
        │                                                       #       RefType (byte?), TypeName (string?)
        │                                                       #       (Dapper projection, not the API DTO)
        └── Services/EutrDocumentsService.cs                    # EDIT (Update 5): GetPoReferencesAsync's
                                                                  #       per-document grouping populates
                                                                  #       the 3 new fields (Decision 25)
    └── ComplianceSys.Infrastructure/
        └── Repositories/EutrReferencesRepository.cs            # EDIT (Update 5): GetDocumentsByPoCodesAsync's
                                                                  #       SQL selects r.StepId/r.RefType +
                                                                  #       LEFT JOIN eutr_reference_types

# Update 10 (2026-07-27) — download-zip: new action on the existing, already-ISharepointService-
# injected EutrDocumentsController.cs (owned by feature 004-eutr-documents, edited additively);
# zero new controller/service/repository/entity, zero migration, zero new policy.
compliance-sys-api/
└── src/
    ├── ComplianceSys.Api/
    │   └── Controllers/EutrDocumentsController.cs   # EDIT (Update 10): + POST download-zip (policy
    │                                                  #       EutrDocuments.ReadAll, reused) — builds a
    │                                                  #       folder-organized ZipArchive in memory from
    │                                                  #       the request's client-supplied folders/files,
    │                                                  #       fetching each via the already-injected
    │                                                  #       _sharepointService.DownloadByFileId(fileId)
    │                                                  #       (cloned pattern: AllCompliancesController.
    │                                                  #       DownloadMultipleFiles + ComplianceDownloadService.
    │                                                  #       BuildFolderName/GetUniqueEntryName), returns
    │                                                  #       File(memoryStream, "application/zip", zipFileName)
    └── ComplianceSys.Application/
        └── Dtos/Request/
            ├── EutrDownloadZipRequestDto.cs   # NEW (Update 10) - {SalesId,CustomerCode,CustomerName,Folders[]}
            ├── EutrDownloadZipFolderDto.cs    # NEW (Update 10) - {FolderName, Files[]}
            └── EutrDownloadZipFileDto.cs      # NEW (Update 10) - {FileId, FileName}

compliance-client/
└── src/
    ├── domain/interfaces/IEutrPurchaseAttachmentsRepository.js       # NEW (Update 1)
    │                                                # EDIT (Update 2): + getBySalesId, savePoMapping
    ├── infrastructure/api/eutrPurchaseAttachmentsApi.js              # NEW (Update 1)
    │                                                # EDIT (Update 2): + getBySalesId, savePoMapping
    ├── infrastructure/repositories/RestEutrPurchaseAttachmentsRepository.js  # NEW (Update 1)
    │                                                # EDIT (Update 2): implement the 2 new methods
    ├── application/usecases/eutr-purchase-attachments/
    │   ├── GetTemplatesBySalesIdsUseCase.js        # NEW (Update 1) - unchanged in Update 2
    │   ├── GetPurchaseAttachmentsBySalesIdUseCase.js  # NEW (Update 2)
    │   └── SavePoMappingUseCase.js                    # NEW (Update 2)
    ├── di/repositories.js                           # EDIT (Update 1): register eutrPurchaseAttachments
    └── presentation/pages/eutr-sales-orders/
        ├── SalesOrderOverviewPage.jsx               # EDIT: real data for 4 D365 columns, fixed demo
        │                                             #       for Progress; EDIT (Update 1): real,
        │                                             #       possibly multi-value Template column
        ├── MapFilePage.jsx                          # EDIT (Update 2): real data for `if (!so)`/header
                                                       #       (refType=11), Step 1 PO list (refType=16)
                                                       #       + Save PO Mapping (new write endpoint),
                                                       #       Step 2 tree (EutrTemplates get-all/GetById)
                                                       #       + AVAILABLE FILES (list-po-references);
                                                       #       Upload/Save on Step 2 stay no-op (unchanged)
                                                       # EDIT (Update 3): Back button gets an `onClick`
                                                       #       (navigate('/eutr/sales-orders'), same
                                                       #       target as the existing breadcrumb link);
                                                       #       checkbox-disable + Save PO Mapping logic
                                                       #       are unchanged (already correct, see
                                                       #       research.md Decision 16)
                                                       # EDIT (Update 5): extract loadTemplatesData
                                                       #       callback (Decision 23), wire onClick on
                                                       #       each toolbar template Chip; carry
                                                       #       poCode/stepIds/typeName onto each built
                                                       #       AVAILABLE FILES entry; replace the 3
                                                       #       static "Map status"/"File type"/"PO
                                                       #       value" Chip labels with computed values
                                                       #       (Decisions 24-25)
                                                       # EDIT (Update 6): remove the local UploadDialog/
                                                       #       MapFileDialog components + their
                                                       #       handleUpload/handleMapDialogConfirm/
                                                       #       newlyUploadedFiles/stepFilePO local-state
                                                       #       logic; import EutrDocumentsFormDialog
                                                       #       (from ../eutr-documents/components/) and
                                                       #       render it twice - mode="add" wired to the
                                                       #       Upload button, mode="edit" wired to each
                                                       #       file's Edit icon; add loadDocumentForEdit
                                                       #       (GetPagingEutrDocumentsUseCase filtered
                                                       #       Column=Id) to build initialData before
                                                       #       opening Edit; onSubmitted on both re-calls
                                                       #       GetEutrDocumentsPoReferencesUseCase to
                                                       #       refresh AVAILABLE FILES/Map status
                                                       #       (Decisions 26-28)
                                                       # EDIT (Update 7): add purchIdToTemplateCode
                                                       #       useMemo built from already-loaded
                                                       #       purchaseAttachments (no new fetch);
                                                       #       recompute derivedFileMappings/
                                                       #       isMappedByStepId/AVAILABLE FILES' file
                                                       #       list per-template (scoped to
                                                       #       selectedTemplateCode's own PO(s) via
                                                       #       file.poCode -> purchIdToTemplateCode),
                                                       #       instead of matching against
                                                       #       templatesData.flatMap(...) combined
                                                       #       across all templates; recompute the
                                                       #       header's aggregate progress as the sum
                                                       #       of each template's own correctly-scoped
                                                       #       completion count (Decisions 29-30)
                                                       # EDIT (Update 9): import EutrFileViewerDialog
                                                       #       (from ../eutr-documents/components/);
                                                       #       add viewerFile state ({open, fileId,
                                                       #       fileName}, cloned from 004-eutr-documents
                                                       #       index.jsx); add a View IconButton next to
                                                       #       the existing Edit IconButton (each file
                                                       #       object already has fileId since Update 5);
                                                       #       render <EutrFileViewerDialog /> wired to
                                                       #       viewerFile
                                                       # EDIT (Update 11): computeProgress()'s `required`
                                                       #       filter predicate gains
                                                       #       `&& !AUTO_SOURCES.includes(d.takeFrom)`,
                                                       #       matching missingRequired's existing
                                                       #       exclusion below - one line, no other
                                                       #       change to the function or its callers
        └── ViewSalesOrderPage.jsx                   # EDIT (Update 4): real data for existence/header
                                                       #       (refType=11), Purchase Orders đã chọn
                                                       #       (GetBySalesIdAsync + refType=16 for
                                                       #       display fields), Template Checklist tree
                                                       #       (EutrTemplates get-all/GetById), per-step
                                                       #       mapped/missing status (list-po-references);
                                                       #       read-only — no PO tick/Save, no file
                                                       #       map/unmap/upload; Edit/Map File and
                                                       #       Download buttons unchanged (already
                                                       #       navigate/no-op respectively); Validation
                                                       #       Summary recomputed from real step data
                                                       # EDIT (Update 8): add selectedTemplateCode
                                                       #       state + default-first-template
                                                       #       useEffect (cloned from MapFilePage.jsx);
                                                       #       add poCode: poDoc.poCode onto each
                                                       #       realAvailableFiles entry; add
                                                       #       purchIdToTemplateCode + templateComputations
                                                       #       useMemos (cloned from Update 7 Decision 29);
                                                       #       replace the 3 hardcoded toolbar Chips with
                                                       #       real per-template chips + onClick
                                                       #       (setSelectedTemplateCode only, no refetch
                                                       #       per FR-063); replace the
                                                       #       templatesData.map(...) stacked-tree render
                                                       #       with a single selected-template tree,
                                                       #       fed that template's own scoped
                                                       #       derivedFileMappings/filesForTemplate;
                                                       #       recompute Validation Summary
                                                       #       (requiredDetails/mappedRequired/
                                                       #       missingRequired/pct) as a sum of each
                                                       #       template's own correctly-scoped
                                                       #       completion count (cloned from Update 7
                                                       #       Decision 30)
                                                       # EDIT (Update 10): wire the existing Download
                                                       #       button's onClick — build a `folders`
                                                       #       payload from templateComputations (one
                                                       #       entry per template, files = the union of
                                                       #       fileIds already present in that
                                                       #       template's own derivedFileMappings values,
                                                       #       i.e. already-"Mapped" documents only); if
                                                       #       every folder's files list is empty, show
                                                       #       an error and skip the network call
                                                       #       (FR-074); otherwise call
                                                       #       DownloadEutrSalesOrderZipUseCase.execute(...)
                                                       #       and let it trigger the blob-download
                                                       #       (cloned from ExportEutrTemplatesUseCase.js)
                                                       # NO CHANGE (Update 11): requiredDetails/
                                                       #       mappedRequired/missingRequired/pct
                                                       #       (lines 649-673) reviewed and confirmed
                                                       #       already correct - Required-only,
                                                       #       AUTO_SOURCES-excluded, PO/Template-scoped
                                                       #       (FR-061), aggregated across all saved
                                                       #       templates; nothing to edit here

# Update 10 (2026-07-27) — download-zip: files below are owned by feature 004-eutr-documents,
# edited additively (new methods on already-existing files, no new file there):
compliance-client/
└── src/
    ├── domain/interfaces/IEutrDocumentsRepository.js         # EDIT (Update 10): + downloadZip
    ├── infrastructure/api/eutrDocumentsApi.js                 # EDIT (Update 10): + downloadZip
    │                                                           #       (axiosInstance.post(..., {
    │                                                           #       responseType: 'blob' }), same
    │                                                           #       convention as eutrTemplatesApi.js's
    │                                                           #       existing `export` method)
    ├── infrastructure/repositories/RestEutrDocumentsRepository.js  # EDIT (Update 10): implement downloadZip
    └── application/usecases/eutr-documents/
        └── DownloadEutrSalesOrderZipUseCase.js   # NEW (Update 10) - clones ExportEutrTemplatesUseCase.js's
                                                     #       blob → createObjectURL → <a download> → click →
                                                     #       revokeObjectURL pattern; filename resolved from
                                                     #       the response's Content-Disposition header

compliance-client/src/presentation/pages/eutr-sales-orders/mock/
├── eutrSalesOrders.js       # DELETE (Update 4) - last importer (ViewSalesOrderPage.jsx) removed above
├── eutrTemplateDetails.js   # DELETE (Update 4) - last importer (ViewSalesOrderPage.jsx) removed above
└── eutrTemplates.js         # DELETE (Update 4) - last importer (ViewSalesOrderPage.jsx) removed above
```

`mock/eutrSteps.js` is **NOT** deleted in Update 4 — `utils/treeUtils.js`'s `getStepName()` still
imports `EUTR_STEPS` from it directly (as a fallback for `flatToTree()` when an item has no
`stepName`), and `treeUtils.js` is shared by both `MapFilePage.jsx` and `ViewSalesOrderPage.jsx`.
Real `eutr_template_details` rows always carry `stepName` already (Decision 13), so this fallback path
is unreachable with real data, but removing the mock file would still break the import unless
`treeUtils.js` itself is also edited to drop the fallback — that is a shared-util cleanup outside this
update's scope (touches `MapFilePage.jsx`'s behavior too, not just `ViewSalesOrderPage.jsx`) and is
called out here as a candidate for a future small cleanup, not part of Update 4.

Unchanged (verified reusable as-is, no edits needed):
- `compliance-sys-api/src/ComplianceSys.Api/Controllers/DynController.cs` (generic `reference` action)
- `compliance-client/src/infrastructure/api/dynamicsApi.js`, `RestDynamicsRepository.js`
- `compliance-client/src/application/usecases/dynamics/index.js` (`GetReferenceDataUseCase`)
- `compliance-client/src/presentation/hooks/useReferenceObjects.js`
- `compliance-client/src/di/repositories.js`'s existing `dynamics: new RestDynamicsRepository()` entry
  (Update 1 only adds a new sibling entry, doesn't touch this one)
- `compliance-client/src/app/routes/groups/MainRoutes.jsx`, `RouteResolver.jsx`,
  `presentation/menu-items/ComplianceSystem.jsx` (route/menu already wired; `MapFilePage.jsx`'s own
  route was already registered before this feature and needs no change in Update 2 either)
- **Superseded by Update 4**: `ViewSalesOrderPage.jsx` is no longer out of scope (see the Project
  Structure edit above) and `mock/eutrSalesOrders.js`/`eutrTemplateDetails.js`/`eutrTemplates.js` are
  deleted, not kept, once it stops importing them — this bullet's original claim ("MUST NOT be
  deleted, still imported elsewhere") held only through Update 3, when `ViewSalesOrderPage.jsx` was
  genuinely the last importer; `mock/eutrSteps.js` alone is still kept (see the note above the
  Project Structure code block).
- `eutr_templates`/`EutrTemplatesController` and its full stack — Update 1 only *reads* `eutr_templates`
  (join for `TemplateName`) via the new `EutrPurchaseAttachmentsRepository`; **Update 2** additionally
  *reads* `EutrTemplatesController`'s existing `get-all`/`GetById` actions from `MapFilePage.jsx` — no
  existing `EutrTemplates*` file (controller, service, repository, DTOs) is modified by either update.
- `EutrDocumentsController`'s `list-po-references` action, and the frontend
  `GetEutrDocumentsPoReferencesUseCase`/`RestEutrDocumentsRepository.getPoReferences` chain (all from
  feature `004-eutr-documents`) — **Update 2** calls this existing, already-frontend-wired chain
  as-is from `MapFilePage.jsx` for AVAILABLE FILES; none of these files are modified by Update 2.
  **Superseded by Update 5**: `EutrDocumentsService.GetPoReferencesAsync` and
  `EutrReferencesRepository.GetDocumentsByPoCodesAsync` (also listed in the Project Structure edit
  above) are no longer unmodified — Update 5 widens their response additively (`StepIds`/`RefType`/
  `TypeName`); the controller action, request DTO, and route/policy stay unchanged, only the response
  DTO/SQL/service mapping are edited.
- `ComplDynamicsService.cs`'s `EntityMappings[16]`/`case 16` and `RSVNEutrSalesOrderPurchases.cs` —
  **Update 2** is the first caller to filter `refType=16` by `InterCompanyOriginalSalesId`, but no
  code change is needed there (research.md Decision 10); file listed here only for traceability.
- `presentation/pages/eutr-documents/components/EutrDocumentsFormDialog.jsx` and every use case it
  internally calls (`GetEutrReferenceTypesUseCase`, `GetEutrStepsUseCase`,
  `GetByTypeIdEutrReferenceTypeDetailsUseCase`, `UploadToSharePointUseCase.executeEutrMulti`/
  `executeEutrMultiByType`, `UpdateEutrDocumentsUseCase`, `UpdateEutrDocumentReferenceStepUseCase`,
  all owned by `004-eutr-documents`) — **Update 6** imports and renders this component as-is from
  `MapFilePage.jsx`; none of these files are modified.
- `POST /api/sharepoint/eutr-upload-multi`, `POST /api/sharepoint/eutr-upload-multi-by-type`,
  `PUT /api/eutr-documents/{id}`, `PUT /api/eutr-documents/{id}/step`, and
  `POST /api/eutr-documents/get-all` (owned by `004-eutr-documents`) — **Update 6** is a new caller of
  all five, unmodified; no new endpoint, no new policy, no DTO change.
- `presentation/pages/eutr-documents/components/EutrFileViewerDialog.jsx`,
  `presentation/components/FilePreviewer.jsx`, and `GetEutrDocumentsFileByIdRefUseCase` (→
  `GET /api/eutr-documents/get-file-by-idref`, all owned by `004-eutr-documents`) — **Update 9**
  imports and renders `EutrFileViewerDialog` as-is from `MapFilePage.jsx`; none of these files/
  endpoints are modified.
- `AllCompliancesController.cs`, `ComplianceDownloadService.cs`, and every type/helper they own
  (`SanitizeFileNamePart`, `BuildSoZipFileName`, `BuildFolderName`, `GetUniqueEntryName`,
  `DownloadProgress`/`IDownloadProgressService`, the `download-so-zip`/`downloads/*`/`download-all`
  actions) — **Update 10** reads these as a design reference only (research.md Decisions 36-40); none
  of these files are imported, called, or modified. The new `EutrDocumentsController.DownloadZip`
  action clones the *shape* of `SanitizeFileNamePart`/`BuildFolderName`/`GetUniqueEntryName` as new,
  independent private methods scoped to `EutrDocumentsController` — it does not extract a shared util
  or take a dependency on `AllCompliancesController`'s file, consistent with this codebase's own
  precedent of copying a small helper on its second use rather than introducing a shared module for it
  (see spec/plan Update 5's `AttachStepAndConditionInfoAsync` cloning note, and 004-eutr-documents'
  research.md Decision on copying `ComplUploadService`'s unique-filename helper for the same reason).
- `ISharepointService`/`GetFileNamesInBatch`/`DownloadByFileId` (package `Shared.ExternalServices`,
  already DI-registered and already injected into `EutrDocumentsController`'s constructor since Update
  9/`004-eutr-documents`'s own get-file-by-idref addition) — **Update 10** is a new caller of
  `DownloadByFileId` only (via the constructor-injected `_sharepointService` already present on this
  controller); the interface/package itself is unmodified.

## Complexity Tracking

*No entries — Constitution Check passed without violations.*
