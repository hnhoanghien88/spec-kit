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

**Update 12 (2026-07-27)**: Replaces `SalesOrderOverviewPage.jsx`'s fixed `DEMO_PROGRESS` constant with
real, per-row Progress, computed with the exact same formula `MapFilePage.jsx` uses for its own
`progress` (Required-only, `AUTO_SOURCES`-excluded, PO/Template-scoped — FR-082), but **batched** across
every Sales ID visible on the current page rather than one call per row (FR-085). Investigation found the
existing Template-column batch endpoint (`by-sales-ids`) unsuitable to reuse as-is — it returns
pre-aggregated, deduplicated `{SalesId, TemplateCode, TemplateName}` with `PurchId` dropped, while
`computeProgress`'s per-template scoping needs the raw `PurchId → TemplateCode` link. This update adds
two small, additive batch read endpoints — `POST /api/eutr-purchase-attachments/by-sales-ids-raw`
(raw, non-deduplicated `{SalesId, PurchId, TemplateCode}` for many Sales IDs, reusing the existing
`PurchaseAttachmentDto`) and `POST /api/eutr-templates/by-codes` (full step-detail trees for many
`TemplateCode`s in one round trip, reusing the existing `EutrTemplatesResponseDto`) — and reuses
`list-po-references` completely unchanged (confirmed already SalesId-agnostic; called once with the
page-wide union of PO codes). It also extracts `AUTO_SOURCES`/`computeProgress`/the per-template
file-scoping logic (previously duplicated between `MapFilePage.jsx` and `ViewSalesOrderPage.jsx`) into a
new shared frontend util (`utils/progressUtils.js`), so `SalesOrderOverviewPage.jsx` becomes a 3rd
consumer of one implementation rather than a 3rd hand-copied one — directly guarding against the exact
kind of silent drift Update 11 already had to fix once. See research.md Decisions 42-48.

**Update 13 (2026-07-27)**: Replaces the Overview grid's Download `IconButton` — today the only action
button on this row with no `onClick` at all — with the same real zip-download behavior already shipped
for `ViewSalesOrderPage.jsx` (Update 10), scoped to the clicked row's own Sales Order. Zero backend
change: `POST /api/eutr-documents/download-zip` is already fully generic (client-supplied
folder/file grouping) and is reused byte-for-byte. Unlike Update 12, this is deliberately **not**
batched (FR-088) — clicking a row's Download fetches that one row's own raw purchase attachments
(existing singular `GetPurchaseAttachmentsBySalesIdUseCase`), that row's own distinct templates' details
(Update 12's new `by-codes` endpoint, reused here as a single-row call rather than a 3rd inline
2-call-per-template loop), and that row's own PO documents (existing `list-po-references`, unchanged),
then builds the same `folders` payload `ViewSalesOrderPage.jsx` already builds and calls the existing
`DownloadEutrSalesOrderZipUseCase` unchanged. Per-row loading state uses a `Set` of in-flight Sales IDs
(not a single boolean) so one row's in-flight Download never blocks another row's click, search, or
pagination (FR-090). See research.md Decisions 49-52.

**Update 14 (2026-07-28)**: Fixes a reported UX bug (spec FR-093..FR-099): searching Overview for
"SO004957", opening Map File or View, then pressing Back returns to Overview with the search box
empty and the full unfiltered list. Investigation confirms the root cause end to end:
`SalesOrderOverviewPage.jsx` keeps `search`/`page`/`pageSize` as local `useState` with no persistence
(lines 86/89-90), its mount effect unconditionally calls `fetchSalesOrders(0, pageSize, '')` (lines
386-390), and both `MapFilePage.jsx:900` and `ViewSalesOrderPage.jsx:816`'s Back buttons hard-navigate
to the fixed route `navigate('/eutr/sales-orders')` rather than popping browser history — so Overview
always remounts from a blank slate regardless of which Back button (in-app or the browser's own) sent
the user there. This is a **100% frontend-only, zero-backend-change** fix. It has two parts: (1)
`SalesOrderOverviewPage.jsx` starts reading/writing its own `search`/`page`/`page-size` to its URL via
`useSearchParams`, cloning the exact `page`/`page-size` query-param convention (including the
`{ replace: true }` call so typing/paginating doesn't spam browser history) already established by
`compliance-master/index.jsx` and its siblings — extended with one new `search` key unique to this
screen — so its mount effect seeds from the URL instead of hardcoded `0`/`''` (research.md Decision
53); (2) Map File's and View's Back buttons become "smart back": Overview's two existing
`navigate('/eutr/sales-orders/${row.code}/map-file'|'/view')` calls (lines 569/591) additionally pass
`{ state: { fromOverview: true } }`, and each Back button (`handleBack`, replacing the current inline
`onClick`) calls `navigate(-1)` when `location.state?.fromOverview` is true — popping back to the exact
prior Overview URL, search/page intact — and falls back to the already-shipped
`navigate('/eutr/sales-orders')` fresh-list call otherwise (deep link, hard reload, or a menu/breadcrumb
entry — matching FR-098's "no restore" default) (research.md Decision 54). Because the in-app Back
button now literally invokes the same history-pop mechanism the browser's own Back button already
performs, FR-097 (identical behavior for both) holds by construction, with no separate state-matching
code needed. See research.md Decisions 53-56.

**Update 15 (2026-07-28)**: Adds a new **AVAILABLE FILES** section to `ViewSalesOrderPage.jsx`'s
right-hand sidebar (below the existing "Steps missing files:" list) — spec FR-100..FR-106.
Investigation confirms this is **100% frontend-only, zero backend change**: the data this panel needs
is already computed by `templateComputations`/`selectedTemplateComputation` (Update 7/8/12,
`buildTemplateComputations` in the shared `utils/progressUtils.js`) — `filesForTemplate` (all documents
of the currently-viewed template's own PO(s)) and `derivedFileMappings` (step-id → matched-file-ids)
are already sitting in this page's state, just not yet rendered as a file list. The only genuinely new
pieces are: (1) one new small `selectedStepId` state, set when the user clicks a row in the existing
read-only `ViewNode` tree (today `ViewNode` only wires a click handler to its collapse/expand arrow,
never to the row itself) and cleared whenever a template chip is clicked in `template-tree-toolbar`
(the same `onClick` that already calls `setSelectedTemplateCode`); (2) one new `useMemo` that resolves
to `filesForTemplate` when `selectedStepId` is `null` (FR-101) or to the subset of `filesForTemplate`
reachable via `derivedFileMappings` for the clicked node **and all of its descendant nodes** when a
step is selected (FR-102) — reusing this feature's own precedent (Update 7/8, Decisions 29/30) of
building a lookup once and filtering-before-matching, not a new algorithm; (3) reusing
`EutrFileViewerDialog` (`004-eutr-documents`, already imported verbatim into `MapFilePage.jsx` by
Update 9) as-is for the new View button — the same cross-feature presentation-to-presentation import
pattern already established twice (Update 6/9), not a new component. One small, additive data-mapping
fix is needed alongside this: `ViewSalesOrderPage.jsx`'s own `realAvailableFiles` builder does not yet
copy the `typeName` field onto each file object, even though `list-po-references`'s response has
carried it since this feature's own Update 5 (the same class of "already-returned field this screen
simply never reads yet" gap Update 8 found and fixed for `poCode`) — needed so the new panel's File
type chip shows real data, matching `MapFilePage.jsx`'s own AVAILABLE FILES row shape exactly. No new
endpoint, no new DTO, no migration, no new policy — the entire update is confined to
`ViewSalesOrderPage.jsx`.

**Update 16 (2026-07-28)**: Changes `SalesOrderOverviewPage.jsx`'s **default** (empty-search) row set to
only include Sales IDs that already have a saved Template — spec FR-107..FR-112. Investigation confirmed
the existing generic reference endpoint's filter mechanism, unmodified, already supports this: same-
"code"-bucket `FilterRequest` entries already OR-join (`ComplDynamicsService.BuildFilterString`, lines
189-190), so a whitelist of Sales IDs can be expressed as N `{column:"Code", operator:"eq", value:
salesId}` entries against the already-existing `POST /api/dynamics/reference?refType=11` call, with
D365's own `$skip`/`$top`/`$count` pagination applying correctly over the filtered set — **zero change**
to `ComplDynamicsService`/`DynController`/`ODataOperatorConverter`. The one genuinely new piece is the
whitelist itself: a small, additive read on the already-existing `EutrPurchaseAttachmentsController`/
`Service`/`Repository` stack (`GET /api/eutr-purchase-attachments/sales-ids-with-template`, `SELECT
DISTINCT SalesId FROM eutr_purchase_attachments`, cloned in shape from Update 1's
`GetTemplatesBySalesIdsAsync` minus its input-list/name-join). `SalesOrderOverviewPage.jsx` fetches this
whitelist once whenever the search box transitions to empty (mount, clearing search, or an empty keyword
restored via Update 14's Back-navigation), builds the OR-filter from it, and — critically — skips the
`refType=11` call entirely and renders "No data" directly when the whitelist is empty (an empty filter
array would otherwise mean "no filter," the opposite of intended). A non-empty search keyword bypasses
this whole path, unchanged from today's FR-011 behavior. See research.md Decisions 60-62.

**Update 17 (2026-08-11)**: Adds two dynamic columns, **Variants** and **Materials**, to
`MapFilePage.jsx`'s Step 1 PO table — spec FR-113..FR-120. Investigation of `ComplDynamicsService.cs`
found something unusual: the D365 entity this needs (`RSVNEutrSalesOrderPurchLines`, `refType = 20`),
its full `MapDynamicsResponse` case, its `MapSortColumn` entry, and every `ComplDynReferenceResponseDto`
field it assigns **already exist in code** — but `EntityMappings` (the dictionary
`GetDynRefePagedAsync` checks before running any query) has no entry for key `20`, so the endpoint has
been silently returning an empty list all along. This is the exact same "entity/case shipped,
registration missing" bug this same dictionary's own comments already document being found and fixed
twice before, for `refType=18` and `refType=19` — `refType=20` is a third, not-yet-caught instance of
it. The fix is one dictionary entry (`{ 20, ("RSVNEutrSalesOrderPurchLines",
"InterCompanyOriginalSalesId", "ProductVariant") }`); no entity, DTO, or controller change. Frontend adds
one new batched `refType=20` fetch to `MapFilePage.jsx` (filtered only by `InterCompanyOriginalSalesId`,
matching FR-117's no-N+1 rule), grouped client-side by `RSVNRefPurchId` into deduped Material (`ItemId`)/
Variant (`ProductVariant`) lists per PO, replacing the two static "Variants"/"Materials" `Typography`
placeholders already present in the Step 1 table's JSX. See research.md Decisions 63-65.

**Update 18 (2026-08-12)**: Replaces `ViewSalesOrderPage.jsx`'s own hardcoded literal
`"Variants"`/`"Materials"` cell text in its Selected Purchase Orders table
(`data-marker="selected-po-table"`, same marker name as `MapFilePage.jsx`'s Step 1 table) with real
per-PO data — spec FR-121..FR-128. Investigation confirmed this table already has the Variants/
Materials column headers but the table body never reads any data for them; everything Update 17 needed
to make this real already exists and is unchanged by this update: `EntityMappings[20]` is already
registered (Update 17), and `ViewSalesOrderPage.jsx` already loads its own `poList` from the same
`refType=16` PO source `MapFilePage.jsx` uses. The fix clones `MapFilePage.jsx`'s Update 17
`refType=20` fetch/grouping logic (`EUTR_SALES_ORDER_PURCH_LINE_REF_TYPE = 20` constant,
`poLinesByPurchId`/`poLinesLoading`/`poLinesError` state, one batched-per-`salesId` effect) into
`ViewSalesOrderPage.jsx` verbatim, and swaps the two hardcoded `<Typography>Variants</Typography>`/
`Materials` cells for the same computed-cell/loading/error rendering `MapFilePage.jsx` already uses. No
backend change, no new entity/DTO/endpoint — a pure client-side reuse of an already-specified mechanism
(Constitution Principle III). See research.md Decision 66.

**Update 19 (2026-08-12)**: Gives `ViewSalesOrderPage.jsx`'s existing-but-inert **All** toolbar chip
(`data-marker="template-tree-toolbar"`, `templateCode: null`) real behavior — spec FR-129..FR-140.
Investigation confirmed the chip already renders (ahead of the real template chips) but every
downstream computation that reads `selectedTemplateCode` falls back to `templateComputations[0]`/
`templatesData[0]` whenever it is `null`, so clicking All today is indistinguishable from re-selecting
the first template. The fix has three parts, all confined to `ViewSalesOrderPage.jsx`: (1) on click,
fetch the one `eutr_templates` record matching `IsDefault = 1` — zero backend change, since
`EutrTemplatesRepository.GetPagedAsync` already unconditionally applies `IsHide = 0`/`IsDeleted = 0` and
already whitelists `IsDefault` as a filter column (`FilterMap["IsDefault"]`), so this is the exact same
paged-then-`GetById` call this screen already makes per real template chip (Update 4), just with a
different filter value; (2) filter that default template's flat step list down to steps whose `StepId`
also appears in the union of every saved template's own steps (`templatesData.flatMap(t =>
t.flatDetails)`), re-parenting any surviving descendant of a removed step onto its nearest surviving
ancestor rather than dropping it — one genuinely new pure function, colocated in the existing
`utils/treeUtils.js` alongside `flatToTree`/`removeNodeAndDescendants`, since no existing utility in
this codebase performs this shape of filter-and-reparent operation; (3) while All is active, union every
saved template's own `filesForTemplate` (already computed per-template by `buildTemplateComputations`,
Update 7/8/12) for the AVAILABLE FILES panel instead of showing only one template's set. No new
endpoint, no new DTO, no migration, no change to FR-060's existing first-template default on page load.
See research.md Decisions 67-68.

**Update 21 (2026-08-12)**: Adds a nested **All** folder to the Download zip (View's Download, Update 10;
Overview's per-row Download, Update 13) — spec FR-142..FR-151. Mirrors, inside the zip, exactly the same
default-template step tree the toolbar's All chip already renders on screen (Update 19/20:
`allChipTree`/`allChipDerivedFileMappings`/`allChipFiles`, already kept fresh by the mount-time
`loadDefaultTemplate` effect `ViewSalesOrderPage.jsx` added for Update 20 — no new fetch needed on View's
Download click). The only backend change is reshaping the existing `EutrDownloadZipFolderDto.FolderName`
(a single string, sanitized as one unit) into `FolderPath` (an ordered list of segments, each sanitized
independently then joined with `/`) — the exact same `DownloadZip` action, policy, response shape, empty-
folder rule (FR-073/FR-146), and per-folder filename-dedup rule (FR-075/FR-148) apply unchanged, since
both already treat their folder name as a `/`-delimited path string. On the frontend, one new pure
function (`flattenTreeToFolderEntries`, colocated in the existing `utils/treeUtils.js`) walks a tree and
emits one `{folderPath, files}` entry per node, prefixed with `['All']` — reusing Update 19's already-
correct tree/file-union computations rather than re-deriving them. `ViewSalesOrderPage.jsx`'s
`buildDownloadFolders` appends these entries (falling back to a single empty `{folderPath: ['All'],
files: []}` entry per FR-147 when the All tree itself is empty/unavailable) to the unchanged per-template
entries. `SalesOrderOverviewPage.jsx`'s per-row Download handler — which has no pre-loaded All-tree state
of its own, since Overview renders no Template Checklist — gains one new on-demand call to the exact same
2-call default-template fetch `loadDefaultTemplate` already uses (Update 19, Decision 67), added to its
existing `Promise.all` (Update 13) and caught independently so its failure degrades to an empty All
folder rather than breaking the row's existing per-template Download. No new endpoint, no new entity/
table/migration/policy, no change to the per-template folders' own content or naming. See research.md
Decisions 69-70.

## Technical Context

**Language/Version**: .NET 8 (backend, `ComplianceSys.Api`/`Application`/`Domain`/`Infrastructure`); React 18 + Vite (frontend, `compliance-client`) — existing stack, unchanged.

**Primary Dependencies**: ASP.NET Core Web API + Dapper (backend, existing); MUI (Material UI), React Router, existing DI container (`di/repositories.js`) (frontend, existing). No new dependency introduced.

**Storage**: Sales ID/Customer/Customer name/Delivery date are read live from D365 via the existing OData-backed reference lookup (`IDynamicService`/`DynamicsParameterManager`) — unaffected by Update 1. Progress remains a fixed demo constant with no persisted table. **Update 1**: Template is now read from the existing MySQL tables `eutr_purchase_attachments` (join key) and `eutr_templates` (name lookup), via Dapper (`IUnitOfWork`) — the same local-DB access path already used by every other `Eutr*Repository` in this codebase; no migration needed, both tables already exist. **Update 2**: `eutr_purchase_attachments` gains a write path (delete-then-reinsert per Sales ID, same Dapper/`IUnitOfWork` access); Step 1's PO list is read live from D365 (`refType=16`, already-registered `RSVNEutrSalesOrderPurchases`); Step 2's tree/files are read from the already-existing `eutr_template_details`/`eutr_steps` (via `EutrTemplatesController`) and `eutr_references`/`eutr_documents` (via `EutrDocumentsController`'s `list-po-references`) — no new tables, no migration. **Update 4**: no storage change of any kind — `ViewSalesOrderPage.jsx` reads the exact same tables/D365 entities as Update 2/3 through the exact same already-registered endpoints, strictly the read side (no `DeleteBySalesIdAsync`/`SavePoMappingAsync` call from this screen). **Update 5**: no new table, no migration — `eutr_references.StepId`/`RefType` and `eutr_reference_types.Name` already exist and are already reachable from `GetDocumentsByPoCodesAsync`'s existing `WHERE r.RefValue IN @PoCodes` query; the query's `SELECT` list and one new `LEFT JOIN eutr_reference_types` are widened to surface columns it already had access to but wasn't yet projecting. **Update 6**: no new table, no migration — Step 2's Upload/Edit now write to the exact same `eutr_documents`/`eutr_references` tables via the exact SharePoint-upload and update use cases `004-eutr-documents` already calls from its own screen; the one new read (edit-detail hydration) reuses `eutr_documents`'s existing paging query filtered by `Id`. **Update 7**: zero storage change of any kind — no new table, no migration, no new read. The PO↔Template link this fix needs (`eutr_purchase_attachments.PurchId`→`TemplateCode`) is already fetched by the existing `GetBySalesIdAsync`/`by-sales-id/{salesId}` call (Update 2, Decision 12) and already sits in `MapFilePage.jsx`'s `purchaseAttachments` state; this update only changes how that already-fetched data is used client-side to scope AVAILABLE FILES/Map status derivations (research.md Decisions 29-30). **Update 8**: zero storage change of any kind — no new table, no migration, no new read, no DTO change. The same `purchaseAttachments` state `ViewSalesOrderPage.jsx` already loads (Update 4) supplies the PO→Template link, and `list-po-references`'s response already carries `poCode` per document (added additively by this feature's own Update 5, already consumed by `MapFilePage.jsx`) — `ViewSalesOrderPage.jsx` only needs to start reading a field its own already-fetched response already contains (research.md Decisions 31-34). **Update 9**: zero storage change of any kind — no new table, no migration, no new read, no DTO change. The file-content retrieval this update needs already exists end to end (`eutr_documents`'s existing file-content-by-id read path, already exposed via `GET /api/eutr-documents/get-file-by-idref` for `004-eutr-documents`'s own View action) — `MapFilePage.jsx` only needs to call it with a `fileId` it already has on each AVAILABLE FILES entry (present since Update 5). **Update 10**: zero new table, no migration — the new `download-zip` action reads no new data at all; every `fileId`/`fileName`/template-grouping value it receives is already computed client-side from data `ViewSalesOrderPage.jsx` already loaded (Update 4/7/8). The only "storage" touched is the SharePoint-backed file content itself, fetched via the same `ISharepointService.DownloadByFileId(fileId)` method `ComplianceDownloadService` already uses for the unrelated `AllCompliances` zip export — same interface, same underlying SharePoint storage, new caller. **Update 11**: zero storage change of any kind — no new table, no migration, no new read, no DTO change. `AUTO_SOURCES` is a client-side constant already defined in `MapFilePage.jsx`; the fix only changes which already-in-memory `flatDetails` rows a `useMemo` predicate counts, nothing server-side. **Update 12**: no new table, no migration — the two new batch endpoints (`by-sales-ids-raw`, `by-codes`) read the exact same tables Update 1/2/5 already read (`eutr_purchase_attachments`, `eutr_templates`, `eutr_template_details`, `eutr_steps`), just parameterized over a list of Sales IDs/Template Codes instead of one at a time; `list-po-references` is called unchanged against `eutr_references`/`eutr_documents`/`eutr_reference_types`, same tables Update 5 already widened. **Update 13**: zero storage change of any kind — reuses `download-zip`'s existing SharePoint-backed file read (`ISharepointService.DownloadByFileId`, unchanged since Update 10) and the same MySQL tables Update 12 reads, just scoped to one Sales ID's own rows per on-demand click instead of a page-wide batch. **Update 14**: zero storage change of any kind — no new table, no migration, no new read/write anywhere. The only state involved is client-side: React Router's own URL query-string (`search`/`page`/`page-size` on `SalesOrderOverviewPage.jsx`'s own route) and `location.state` (a one-shot `{fromOverview: true}` flag passed at navigation time, not persisted to any storage). **Update 15**: zero storage change of any kind — no new table, no migration, no new read/write anywhere. The new AVAILABLE FILES panel and its step-filtering are pure client-side re-renders of `templateComputations`/`selectedTemplateComputation` (already fetched by Update 4/7/8/12's existing calls); the one small data-mapping fix (copying `typeName` onto each `realAvailableFiles` entry) reads a field already present in the already-fetched `list-po-references` response, not a new column/query. **Update 16**: no new table, no migration — the new `sales-ids-with-template` read is a `SELECT DISTINCT SalesId` against the exact same `eutr_purchase_attachments` table every prior update in this feature already reads from; no new column, no new DTO class (returns a bare `string[]`). No storage-layer change of any kind on the D365 side — `refType=11`'s existing OData query/`EntityMappings`/response mapping are all unmodified; only the `FilterRequest[]` values `SalesOrderOverviewPage.jsx` sends to the already-existing endpoint change. **Update 17**: no new table, no migration — `refType=20` reads live from the same D365-backed OData path every other `refType` already uses, via the D365 entity `RSVNEutrSalesOrderPurchLines` which already exists (`ModelType = 20`); the one change is a single `EntityMappings` dictionary entry in `ComplDynamicsService.cs` that makes that already-implemented entity/mapping reachable for the first time — no new column, no new query shape, no MySQL table touched at all. **Update 18**: no storage change of any kind - reads the exact same already-registered `refType=20` D365 path Update 17 made reachable, this time called from `ViewSalesOrderPage.jsx` instead of `MapFilePage.jsx`; no new column, no new query shape, no MySQL table touched. **Update 19**: no new table, no migration, no new column — the default-template lookup reads the exact same `eutr_templates`/`eutr_template_details` tables every prior update already reads, filtered by the already-existing `IsDefault`/`IsHide`/`IsDeleted` columns (the same columns `003-eutr-templates`'s own `SetIsDefaultAsync`/`ClearGlobalDefaultAsync` already maintain); the tree-filter-with-reparenting and cross-template file-mapping lookup operate entirely on data already fetched into React state (`templatesData`, `templateComputations`) — no new read, no new write, no MySQL table touched beyond what Update 2/4/7/8 already read.

**Testing**: Existing backend unit test project `ComplianceSysApi.UnitTests` (add/extend a test for the new `EntityMappings[11]` + mapping case if a suitable existing test class covers `ComplDynamicsService`; **Update 1**: add a test class for `EutrPurchaseAttachmentsRepository`/`Service` if the project has an equivalent existing test for `EutrTemplatesRepository`/`Service` to model it on); frontend has no dedicated automated test harness for this page — verify manually per `quickstart.md`, consistent with how prior EUTR features in this repo were validated. **Update 2**: extend the same `EutrPurchaseAttachmentsRepository`/`Service` test class (if added) with cases for `GetBySalesIdAsync`/`SavePoMappingAsync`; `MapFilePage.jsx` remains manually verified per `quickstart.md` (no automated UI harness in this repo). **Update 4**: zero backend test impact (no backend change); `ViewSalesOrderPage.jsx` is manually verified per `quickstart.md`, same as `MapFilePage.jsx`. **Update 5**: if `004-eutr-documents` has an existing `EutrReferencesRepository`/`EutrDocumentsService.GetPoReferencesAsync` test class, extend it with a case asserting `stepIds`/`refType`/`typeName` are populated correctly for a multi-row document; `MapFilePage.jsx`'s toolbar-reload and dynamic badges are manually verified per `quickstart.md` (Update 5 section), same as every prior frontend-only update in this feature. **Update 6**: zero backend test impact (no backend change) — `MapFilePage.jsx`'s Upload/Edit wiring is manually verified per `quickstart.md` (Update 6 section); if `004-eutr-documents` already has a test class covering `EutrDocumentsService.GetPagedAsync`'s `Id`-filter path, no new test case is needed there either since this update is a new caller of an already-tested behavior, not a new behavior. **Update 7**: zero backend test impact (no backend change) — verified manually per `quickstart.md` (Update 7 section), specifically constructing a fixture with 2 templates sharing a `StepId`/step name to prove no cross-template contamination survives (no automated UI harness in this repo, consistent with every prior frontend-only update in this feature). **Update 8**: zero backend test impact (no backend change) — verified manually per `quickstart.md` (Update 8 section), reusing the same 2-templates-sharing-a-step-name fixture shape already used to verify Update 7, this time exercised against `ViewSalesOrderPage.jsx`'s toolbar/Template Checklist/Validation Summary instead of `MapFilePage.jsx`'s Step 2. **Update 9**: zero backend test impact (no backend change) — if `004-eutr-documents` has an existing test covering `EutrDocumentsService`'s file-content-by-id read path, no new backend test case is needed since this update is a new caller of an already-tested endpoint, not a new behavior; `MapFilePage.jsx`'s new View button is manually verified per `quickstart.md` (Update 9 section), same as every prior frontend-only update in this feature. **Update 10**: no existing test class covers `AllCompliancesController`/`ComplianceDownloadService` (the pattern this update clones) at the unit level in this repo today, so no analogous existing test class exists to extend for the new `EutrDocumentsController.DownloadZip` action either — verified manually per `quickstart.md` (Update 10 section), consistent with how every other backend addition in this feature without a pre-existing test class precedent has been handled; `ViewSalesOrderPage.jsx`'s Download button wiring is manually verified the same way. **Update 11**: zero backend test impact (no backend change) — verified manually per `quickstart.md` (Update 11 section), specifically constructing a fixture with a Required step whose `takeFrom` is one of `AUTO_SOURCES` and no mapped file, then confirming `progress.total - progress.completed` equals `missingRequired` on Map File and matches the equivalent Required/completed/missing numbers on View for the same Sales Order (no automated UI harness in this repo, consistent with every prior frontend-only update in this feature). **Update 12**: the two new batch endpoints (`by-sales-ids-raw`, `by-codes`) are new, small, additive actions with no existing test class precedent in this repo for their owning controllers' batch-shaped reads — if a suitable existing test class exists for `EutrPurchaseAttachmentsRepository`/`EutrTemplatesRepository`, extend it with one case each; otherwise verified manually per `quickstart.md` (Update 12 section), consistent with how every other backend addition without a pre-existing test precedent has been handled in this feature. The frontend batching/3-state Progress cell is manually verified per `quickstart.md`, specifically constructing the empty/no-required/error fixtures FR-083/FR-084/FR-085 call for (no automated UI harness in this repo). **Update 13**: zero backend test impact (no backend change) — `download-zip` is reused unchanged; `SalesOrderOverviewPage.jsx`'s new per-row on-demand Download wiring is manually verified per `quickstart.md` (Update 13 section), specifically confirming its zip output matches `ViewSalesOrderPage.jsx`'s own Download output for the same Sales Order (SC-040). **Update 14**: zero backend test impact (no backend change). Verified manually per `quickstart.md` (Update 14 section): search Overview for a known Sales ID, open Map File then View, click each screen's Back button, and confirm the search box/page/filtered rows are restored exactly; separately confirm the browser's own Back button produces the identical result, and that navigating to Overview via the nav menu/breadcrumb (not via Back) shows the default unfiltered list — no automated UI harness in this repo, consistent with every prior frontend-only update in this feature. **Update 15**: zero backend test impact (no backend change) — verified manually per `quickstart.md` (Update 15 section): open View for a Sales Order with 2+ templates where at least one step is Mapped and at least one is missing, confirm the new AVAILABLE FILES panel shows the full file set of the active template by default, confirm clicking a leaf step narrows it to that step's own Mapped file(s), confirm clicking a parent step narrows it to the union of its descendants' Mapped files, confirm clicking any template chip (including the currently-active one) clears the filter back to the full set, and confirm the View button opens the same read-only preview popup already shipped for Map File (Update 9) — no automated UI harness in this repo, consistent with every prior frontend-only update in this feature. **Update 16**: the one new backend read (`GET /api/eutr-purchase-attachments/sales-ids-with-template`) has no existing test class precedent for an unscoped "every distinct value" query on this repository — if a suitable existing test class exists for `EutrPurchaseAttachmentsRepository`, extend it with one case (empty table → `[]`; multiple Sales IDs, some sharing a `TemplateCode` → each Sales ID appears exactly once); otherwise verified manually per `quickstart.md` (Update 16 section), consistent with how every other backend addition without a pre-existing test precedent has been handled in this feature. `SalesOrderOverviewPage.jsx`'s default-view/search-toggle behavior is manually verified per `quickstart.md`, specifically confirming the empty-search list excludes a Sales ID with no saved Template, a non-empty search still finds it, and clearing search restores the filtered default (no automated UI harness in this repo). **Update 17**: the one backend change (adding `EntityMappings[20]`) has no existing test class precedent covering `ComplDynamicsService.GetDynRefePagedAsync` at the unit level in this repo today (same situation Update 1/12/16 already noted for their own backend additions) — verified manually per `quickstart.md` (Update 17 section): confirm `refType=20` returns `[]` before the fix and real rows after it, for a Sales Order with known purchase-line fixtures. `MapFilePage.jsx`'s new Variants/Materials columns are manually verified per `quickstart.md`, specifically the combine/dedupe behavior for a PO with 2+ lines and the empty-state for a PO with none (no automated UI harness in this repo, consistent with every prior frontend-only update in this feature). **Update 18**: the one backend change (Update 17's `EntityMappings[20]` entry) needs no further test impact - reused unchanged; `ViewSalesOrderPage.jsx`'s Selected Purchase Orders table is manually verified per `quickstart.md` (Update 18 section), specifically confirming its Variants/Materials cells match `MapFilePage.jsx`'s own cells for the same Sales Order/PO (no automated UI harness in this repo, consistent with every prior frontend-only update in this feature). **Update 19**: zero backend test impact (no backend change) — verified manually per `quickstart.md` (Update 19 section): construct a Sales Order with 2 saved templates that only partially overlap the current default template's steps (some default steps missing from both, some present in only one, one default parent step missing while a child of it is present in one saved template), click All, and confirm the resulting tree shows exactly the overlapping steps (no more, no less), confirms the orphaned-but-present child step is still visible, and confirms AVAILABLE FILES lists the union of both templates' Mapped documents; separately confirm the "no default template configured" and "no steps match" empty states each render distinctly, and that switching from All to a specific template chip and back clears/restores the AVAILABLE FILES step filter correctly (no automated UI harness in this repo, consistent with every prior frontend-only update in this feature).

**Performance Goals**: Matches spec SC-001 — list loads within ~3s under normal network/load, consistent with other EUTR reference grids (e.g. List PO in `eutr-documents`, refType=15). **Update 1**: the new Template lookup is batched once per visible page of Sales IDs (research.md Decision 7), not per row, to stay within this same budget. **Update 2**: `MapFilePage.jsx` loads one Sales Order at a time (not a paged grid), so its handful of sequential calls (refType=11 → refType=16 → `GetBySalesIdAsync` → per-distinct-`TemplateCode` tree lookup → `list-po-references`) stay well within SC-005's per-screen load budget without needing batching across rows. **Update 4**: `ViewSalesOrderPage.jsx` issues the identical sequential-call shape as `MapFilePage.jsx` (one Sales Order at a time), minus the write call — same budget, no new performance concern. **Update 5**: the toolbar-reload interaction re-issues the same handful of already-cheap `templatesData` calls (Update 2's budget) on click, not on every render — no polling, no new recurring cost; the widened `list-po-references` `SELECT`/`JOIN` adds negligible cost to a query already scanning the same rows. **Update 6**: opening the Edit popup adds exactly one small, `pageSize=1` paging call before the popup renders — negligible added latency, no new recurring cost; Upload/Save inside the reused popup run at whatever cost `004-eutr-documents`' own screen already incurs for the same actions, unchanged by this update. **Update 7**: zero new network calls of any kind — the fix re-shapes `useMemo` derivations over data already in memory (`purchaseAttachments`, `realAvailableFiles`, `templatesData`); computing a `Map` lookup and filtering/grouping per template over a handful of templates/files is negligible client-side work, well within the existing per-screen load budget. **Update 8**: zero new network calls of any kind, same reasoning as Update 7 — the fix re-shapes `ViewSalesOrderPage.jsx`'s own `useMemo` derivations over data already in memory (`purchaseAttachments`, `poReferenceDocs`, `templatesData`), plus copying one already-returned field (`poCode`) onto each file object; negligible added client-side cost, no new recurring cost, no refetch on toolbar click (spec FR-063). **Update 9**: adds exactly one new network call, and only when the user actively opens the popup (not on every render/page load) — `EutrFileViewerDialog`'s own internal `fetchFile` call to `GET /api/eutr-documents/get-file-by-idref`, the same single-file base64 fetch `004-eutr-documents`'s own screen already performs for its View action; no polling, no new recurring cost, no change to Step 2's existing load budget. **Update 10**: adds exactly one new network call, fired only when the user clicks Download (not on page load) — the new `POST /api/eutr-documents/download-zip` request, sized to only the already-loaded, already-"Mapped" documents for this one Sales Order (a small, bounded set, not the potentially-large multi-product volume `AllCompliances`' own SO export handles) — synchronous request/response is acceptable at this scale, consistent with why this update deliberately clones the simpler `DownloadMultipleFiles` shape instead of the async/SSE `download-so-zip` shape (Summary, above); no polling, no background job, no new recurring cost. **Update 11**: zero new network calls of any kind — the fix adds one boolean check (`!AUTO_SOURCES.includes(d.takeFrom)`) inside an already-existing `useMemo` filter predicate; negligible added client-side cost, no change to Step 2's existing load budget. **Update 12**: adds exactly 3 new/reused batch network calls per Overview page load (`by-sales-ids-raw`, `by-codes`, `list-po-references`), fired once per page/search/pagination change — not per row — and 2 of the 3 (`by-codes`/`list-po-references`) run in parallel off the first one's result, keeping added latency to roughly "1 round trip, then 2 in parallel" regardless of page size (up to the existing `pageSize` default of 100); stays within SC-001's existing ~3s budget for the whole screen, the same reasoning already applied to the Template column's own batching (Update 1). **Update 13**: adds exactly 3 new network calls (`by-sales-id/{salesId}`, `by-codes`, `list-po-references`) plus the `download-zip` call itself, fired only when a row's Download button is clicked (not on page load, not batched) — sized to only that one Sales Order's own templates/PO codes, a small, bounded set; no polling, no new recurring cost, consistent with why Update 10 deliberately chose the simpler synchronous `download-zip` shape over an async/SSE one. **Update 14**: zero new network calls of any kind beyond what Overview's mount effect already issues (Update 1/12) — reading `search`/`page`/`page-size` from the URL on mount only changes what arguments that already-existing fetch is called with, not how many times it's called; `setSearchParams(..., { replace: true })` is a client-side history-entry update, not a network call. **Update 15**: zero new network calls of any kind, on page load or on any interaction — the new panel and its step-filtering re-render already-in-memory `useMemo` derivations (`selectedTemplateComputation.filesForTemplate`/`derivedFileMappings`); the one new network call this update can trigger — `EutrFileViewerDialog`'s own internal `fetchFile` request — only fires when the user actively clicks View (same as Update 9's existing behavior on Map File, not a new recurring cost). **Update 16**: adds exactly one new network call (the whitelist fetch) per entry into the empty-search state (mount, clearing search, or an empty-keyword Back-navigation restore) — not per page, not per row; page/page-size changes within that same empty-search view reuse the already-fetched whitelist, issuing zero additional whitelist calls. The existing `refType=11` call itself is unaffected in cost — it already runs once per page/search/pagination change (Update 14); this update only changes the `FilterRequest[]` values sent, not how many times the call fires. When the whitelist is empty, the `refType=11` call is skipped entirely for that load, saving a network round trip rather than adding one. **Update 17**: adds exactly one new network call per Step 1 load (`refType=20`, filtered only by `InterCompanyOriginalSalesId`) — fired once per `salesId` change, in parallel with the existing `refType=16` PO-list call, not once per PO row (FR-117); grouping the response by `RSVNRefPurchId` is a single client-side pass over a small, bounded array (one Sales Order's own purchase lines), negligible added cost, no new recurring cost, no polling. **Update 18**: adds exactly one new network call per View page load (`refType=20`, filtered only by `InterCompanyOriginalSalesId`), fired once per `salesId` change in parallel with View's existing `refType=16` PO-list call, not once per PO row - the identical shape/cost Update 17 already established for Map File's Step 1, just a second caller of the same already-cheap call. **Update 19**: adds exactly 2 new network calls (the paged lookup + `GetById` detail fetch, the same 2-call shape already used per real template chip since Update 4), fired only when the user clicks the All chip — not on page load, not repeated while All stays active, and re-fired fresh on each click (no caching), matching this screen's existing no-refetch-on-click-but-do-fetch-what's-genuinely-new pattern (FR-063 exempts re-fetching already-loaded PO/document data, not this newly-needed template lookup). The tree-filter-with-reparenting and cross-template file union are single client-side passes over already-in-memory, small, bounded arrays (one Sales Order's own saved templates plus one default template) — negligible added cost, no polling, no new recurring cost.

**Constraints**: MUST reuse the existing shared reference endpoint and `ComplDynReferenceResponseDto` shape (Principle III) for the 4 D365-sourced columns; MUST NOT create a new dedicated endpoint or duplicate `DynController`/`ComplDynamicsService` logic for those; the DTO extension MUST be additive (new nullable fields) so existing consumers of other `refType`s are unaffected. **Update 1**: the new `eutr_purchase_attachments` read path MUST follow the existing 4-layer `Eutr*` backend convention (Principle I/II) since no reusable backend exists for it yet (Principle III only mandates reuse of what already exists); the query MUST dedupe repeated templates per Sales ID and silently skip orphaned `TemplateCode`s (spec FR-007a/Edge Cases) rather than erroring. **Update 2**: MUST NOT add a new `BuildFilterString` special case for `InterCompanyOriginalSalesId` (the existing generic "other column" branch already handles it — Principle III); MUST NOT duplicate `list-po-references` or the `EutrTemplates` get-all/`GetById` endpoints; the new `save-po-mapping` write MUST run delete+reinsert inside one transaction (spec FR-021's "replace, don't diff" semantics) and MUST reject an item with an empty `TemplateCode` (spec FR-022, `NOT NULL` column). **Update 3**: MUST NOT touch the checkbox-disable condition or the `save-po-mapping` delete-then-reinsert logic — both already satisfy FR-031/FR-032 as-is (Principle III: don't re-implement a verified-working behavior); the Back button fix MUST reuse the exact `navigate('/eutr/sales-orders')` call already used by the breadcrumb link, not introduce a second way of expressing the same navigation target. **Update 4**: MUST NOT call `SavePoMappingUseCase`/`save-po-mapping` or mutate any tick/map/unmap/upload state from `ViewSalesOrderPage.jsx` (spec FR-042 — read-only); MUST NOT add any new backend endpoint or duplicate an existing one (Principle III — everything needed is already exposed); MUST delete (not merely stop importing) the now-fully-unused `eutr-sales-orders/mock/*` fixtures once this page no longer references them, consistent with this repo's no-dead-code convention. **Update 5**: MUST widen `EutrDocumentsPoReferenceItemDto`/`GetDocumentsByPoCodesAsync` additively only (new nullable/array fields) so `ViewSalesOrderPage.jsx`'s existing `stepNames`-based consumption of the same endpoint is unaffected (Principle III — don't break an existing consumer of a shared endpoint); MUST NOT introduce a second endpoint or duplicate the `RefType`→`eutr_reference_types.Name` lookup already established by `004-eutr-documents`'s `AttachStepAndConditionInfoAsync` (Principle II — clone that pattern); the toolbar's click-to-reload MUST reuse the exact same `templatesData`-building logic already used on mount (Decision 23), not a second, divergent code path. **Update 6**: MUST reuse `004-eutr-documents`' `EutrDocumentsFormDialog.jsx` component as-is (Principle II/III) — MUST NOT fork/duplicate its JSX or its internal use-case calls into a second, `005`-owned copy; MUST NOT add a new backend endpoint for edit-detail hydration — the existing `POST /api/eutr-documents/get-all` paging endpoint, filtered by `Id`, MUST be reused instead (research.md Decision 27); the old local `UploadDialog`/`MapFileDialog` components and their local-state-only handlers MUST be removed, not kept running in parallel alongside the reused dialog (per the requester's confirmed scope). **Update 7**: MUST NOT add any new fetch/use case/endpoint to obtain the PO→Template link — MUST reuse the already-loaded `purchaseAttachments` state as the single source of truth for it (Principle III — nothing new to reuse or duplicate since the data is already client-side); the header's aggregate progress MUST stay Sales-Order-wide (sum across all templates), not narrowed to only the currently-viewed template, per the spec's explicit Update 7 clarification. **Update 8**: MUST NOT add any new fetch/use case/endpoint for the PO→Template link — MUST reuse the already-loaded `purchaseAttachments` state, same as Update 7 (Principle III); MUST NOT introduce a second, divergent toolbar/single-tree-selection implementation — MUST clone `MapFilePage.jsx`'s own `selectedTemplateCode` state/default-first-template effect/toolbar markup/single-tree render pattern (Principle II); the toolbar's click-to-select-template interaction on this screen MUST NOT call `SavePoMappingUseCase`/`save-po-mapping`, mutate any tick/map/unmap/upload state, or trigger a refetch of PO/document data from the real source (spec FR-063 — unlike Map File's FR-048 reload-on-click, View's already-loaded data is sufficient since it is read-only and no concurrent edit happens on this screen); Validation Summary's aggregate MUST stay Sales-Order-wide (sum across all templates, each scoped correctly before summing), not narrowed to only the currently-viewed template — same reasoning as Update 7 (spec FR-062). **Update 9**: MUST reuse `004-eutr-documents`'s `EutrFileViewerDialog.jsx` component as-is (Principle II/III) — MUST NOT fork/duplicate its JSX, its internal `FilePreviewer` usage, or its internal `GetEutrDocumentsFileByIdRefUseCase` call into a second, `005`-owned copy; MUST NOT add a new backend endpoint or duplicate the existing file-content-by-id read path; the View popup MUST stay strictly read-only (spec FR-066/FR-067) — MUST NOT add any Type/Step/Value/Valid-dates field or Save action to it, which would blur it with the already-existing Edit popup (FR-030). **Update 10**: the new `download-zip` action MUST NOT re-derive Map status/PO↔Template scoping server-side (that logic already lives correctly in `ViewSalesOrderPage.jsx`'s `templateComputations`, Update 7/8) — it MUST accept the already-computed folder→file grouping from the client and only fetch+zip, mirroring `AllCompliancesController.DownloadMultipleFiles`'s existing client-supplied-`FileIds` contract; MUST sanitize `SalesId`/`CustomerCode`/`CustomerName` and each folder name server-side (cloning `SanitizeFileNamePart`/`BuildFolderName`) rather than trusting client-side sanitization, since a malformed/unsanitized name would otherwise reach the filesystem/zip-entry layer; MUST NOT write to `eutr_documents`/`eutr_references`/`eutr_purchase_attachments` (spec FR-076 — read-only, same as every other View-screen action). **Update 11**: `progress.total`/`progress.completed` MUST NOT be broadened to include Optional steps (spec FR-077/FR-078 — Required-only, matching the pre-existing Update 7/FR-057 scope); MUST add the same `AUTO_SOURCES` exclusion `missingRequired` (Map File) and every equivalent View-screen variable already apply (spec FR-079), not a divergent exclusion rule; MUST NOT change `missingRequired`'s own calculation (spec FR-080) or any of `ViewSalesOrderPage.jsx`'s `requiredDetails`/`mappedRequired`/`missingRequired`/`pct` (spec FR-081) — those are confirmed already correct by this review. **Update 12**: Overview's Progress computation MUST reuse `computeProgress()`'s exact formula (spec FR-082) — enforced structurally via the new shared `progressUtils.js` (research.md Decision 42), not a second hand-written copy; MUST NOT issue a per-row network call for Progress (spec FR-085 — batched only); the new `by-sales-ids-raw`/`by-codes` endpoints MUST be additive (new actions on already-existing controllers, reusing already-existing DTOs) — MUST NOT change the existing `by-sales-ids` action's response shape (would break its own existing Template-column consumer, Principle III); the empty (FR-083) and no-Required-steps (FR-084) states MUST render as two visibly distinct placeholders, neither as `0/0`/`0%`. **Update 13**: MUST NOT batch Download's data fetch across rows (spec FR-088 — on-demand, single-row only, the opposite of Update 12); MUST NOT introduce any new backend endpoint/DTO for Download — `download-zip` MUST be reused exactly as Update 10 shipped it (Principle III); one row's in-flight Download MUST NOT disable or block any other row's Download, search, or pagination (spec FR-090); the Download button MUST stay clickable at all times, never pre-disabled based on data-emptiness (spec FR-089, same rule already applied to View's own Download since Update 10); Download MUST NOT write to `eutr_documents`/`eutr_references`/`eutr_purchase_attachments` (spec FR-092). **Update 14**: MUST NOT introduce a second, divergent query-param naming convention for pagination — MUST reuse the exact same key names (`page`, `page-size`) `compliance-master/index.jsx` (and its siblings) already established, adding only the new `search` key this screen alone needs; MUST use `{ replace: true }` when syncing state to the URL (not a plain push) so every keystroke/page-size change doesn't spam a new browser-history entry, cloning the existing precedent exactly (spec FR-094/FR-095); the Back button's fallback path (no `fromOverview` flag on `location.state`) MUST stay the exact `navigate('/eutr/sales-orders')` call already shipped by Update 3 (FR-033) — MUST NOT be replaced outright by an unconditional `navigate(-1)`, since that would risk navigating outside the app entirely for a user who deep-links or hard-reloads directly into Map File/View with no Overview entry in history to pop back to (spec FR-098). **Update 15**: MUST reuse `EutrFileViewerDialog` as-is (Principle II/III, same as Update 9) — MUST NOT fork/duplicate it into a second `005`-owned copy; the new panel's file rows MUST NOT include an Edit button or an Upload action of any kind (spec FR-100 — View stays read-only, FR-042); clicking a step in the tree MUST NOT trigger any map/unmap/tick/write behavior or change the tree's own expand/collapse state (spec FR-103); MUST reuse `buildTemplateComputations`'s already-computed `filesForTemplate`/`derivedFileMappings` as the sole source of truth for this panel — MUST NOT introduce a second, parallel computation of which files belong to a template/step (Principle III — nothing new to reuse or duplicate since the data is already client-side). **Update 16**: MUST NOT modify `ComplDynamicsService.cs`, `DynController.cs`, or `ODataOperatorConverter.cs` — the same-bucket OR-join behavior this update relies on already exists and already serves the search box's own Code/Name filter (Principle III — nothing to add, only a new caller of an existing mechanism); MUST NOT send an empty `FilterRequest[]` to `refType=11` when the whitelist is empty, since that already means "no filter" today — the empty-whitelist case MUST skip the network call and render "No data" directly (spec FR-112); a non-empty search keyword MUST bypass the whitelist path entirely, continuing to use the exact, unmodified FR-011 filter construction (spec FR-109); the new `sales-ids-with-template` read MUST NOT take or require an input list (spec's own framing is "every Sales ID with a Template," not scoped to a caller-supplied set) — MUST NOT be merged into `by-sales-ids-raw`'s existing contract, which would change that action's behavior for its already-shipped Progress-column consumer (Update 12). **Update 17**: MUST NOT touch the `RSVNEutrSalesOrderPurchLines` entity class, `MapDynamicsResponse`'s `case 20:`, `ComplDynReferenceResponseDto`, or `DynController.ReferenceData` — all four already exist and already compile correctly (Principle III in its most literal form); the fix MUST be limited to the one missing `EntityMappings[20]` dictionary entry. The new `refType=20` fetch MUST filter only by `InterCompanyOriginalSalesId` (never per-`RSVNRefPurchId`) and MUST group results client-side (spec FR-117 — no N+1); Variants/Materials MUST NOT alter Step 1's checkbox-disable condition (FR-022) or Save PO Mapping's replace semantics (FR-021) — display-only additions (spec FR-120). **Update 18**: MUST NOT re-derive a second, divergent formula for Variants/Materials on the View screen - MUST clone Update 17's exact `refType=20` query/grouping/dedupe/join logic from `MapFilePage.jsx` (Principle II/III); MUST NOT alter View's read-only guarantee (FR-042) or any other existing behavior of the Selected Purchase Orders table (PO/Template/Order account/Vendor Name/Percentage used columns, Edit/Map File, Download, Back, Template Checklist, Validation Summary, AVAILABLE FILES) - display-only additions (spec FR-128). **Update 19**: MUST NOT add any new backend endpoint/DTO for the default-template lookup — MUST reuse `GetPagingEutrTemplatesUseCase`/`GetEutrTemplatesUseCase` exactly as already wired for real template chips, only with an `IsDefault` filter instead of `Code` (Principle III); MUST NOT change FR-060's existing first-template default selection on page load (All only activates on explicit click, spec FR-138); MUST NOT drop a surviving descendant step just because its ancestor in the default template was removed (spec FR-133 — re-parent instead of hiding); MUST NOT scope All's AVAILABLE FILES to a single template (spec FR-136 — union of every saved template's files); MUST NOT write to `eutr_templates`, `eutr_template_details`, or any other table from this screen (View stays read-only, FR-042).

**Scale/Scope**: One backend mapping entry + DTO extension for the 4 D365 columns; one existing frontend page updated to swap its data source for those columns and for Progress's already-decided fixed value. **Update 1** adds: 1 new backend entity + repository interface/impl + service interface/impl + controller (5 new backend files) for `eutr_purchase_attachments`; 1 new DTO file; 4 new frontend files (domain interface, api client, REST repository, use case) plus edits to `di/repositories.js` and `SalesOrderOverviewPage.jsx`. Still no new page, route, or menu entry. **Update 2** adds: 2 new controller actions + 2 new repository methods + 2 new service methods (all on already-existing `EutrPurchaseAttachmentsController`/`Service`/`IEutrPurchaseAttachmentsRepository`) + 3 new small DTOs (`PurchaseAttachmentDto`, `SavePoMappingRequestDto`, `PurchaseAttachmentItemDto`); frontend adds 2 new use cases (`GetPurchaseAttachmentsBySalesIdUseCase`, `SavePoMappingUseCase`) + 2 new methods each on the existing `eutrPurchaseAttachmentsApi.js`/`IEutrPurchaseAttachmentsRepository.js`/`RestEutrPurchaseAttachmentsRepository.js` (no new files there, just new methods) plus a substantial rewrite of `MapFilePage.jsx`'s data-loading logic (still no new page/route/menu entry). No new backend files (entity/repository/service/controller classes) are created — Update 2 only adds methods to files Update 1 already created. **Update 3** adds: zero new backend files/methods, zero new frontend files — a single small edit inside `MapFilePage.jsx` (one `onClick` handler on the existing Back `<Button>`, calling the page's already-imported `navigate`). **Update 4** adds: zero new backend files/methods/endpoints, zero new frontend infrastructure files (reuses every use case/repository/api client `MapFilePage.jsx` already established) — a substantial rewrite of `ViewSalesOrderPage.jsx`'s data-loading logic (mock → real, same shape as `MapFilePage.jsx` minus the write path) plus deletion of 4 now-dead mock files (`eutrSalesOrders.js`, `eutrTemplateDetails.js`, `eutrTemplates.js`, `eutrSteps.js`). **Update 5** adds: zero new backend files/endpoints — 3 new properties each on 2 already-existing backend classes (`EutrReferencePoDocumentInfo`, `EutrDocumentsPoReferenceItemDto`, both owned by `004-eutr-documents`) + edits to `EutrReferencesRepository.GetDocumentsByPoCodesAsync`'s SQL and `EutrDocumentsService.GetPoReferencesAsync`'s grouping logic (both also owned by `004-eutr-documents`); zero new frontend files — edits confined to `MapFilePage.jsx` (extract `loadTemplatesData`, wire toolbar `onClick`, carry `poCode`/`stepIds`/`typeName` onto each built file object, replace 3 static Chip labels with computed values). **Update 6** adds: zero new backend files/endpoints — zero new frontend infrastructure files either (reuses `EutrDocumentsFormDialog.jsx` and every use case it internally calls, all already owned by `004-eutr-documents`) — edits confined to `MapFilePage.jsx`: remove the local `UploadDialog`/`MapFileDialog` components and their `handleUpload`/`handleMapDialogConfirm`/`newlyUploadedFiles`/`stepFilePO` local-state logic; import and render `EutrDocumentsFormDialog` twice (Add/Edit); add one new small `loadDocumentForEdit(documentId)` callback (`GetPagingEutrDocumentsUseCase` filtered by `Id`); add one `onSubmitted` callback re-invoking the already-established `GetEutrDocumentsPoReferencesUseCase` call to refresh AVAILABLE FILES/Map status. **Update 7** adds: zero new backend files/endpoints, zero new frontend files — edits confined to `MapFilePage.jsx`'s existing `useMemo` derivations: one new small `purchIdToTemplateCode` lookup built from already-loaded `purchaseAttachments`; `derivedFileMappings`/`isMappedByStepId`/AVAILABLE FILES' file list recomputed per-template (scoped to the currently-viewed `selectedTemplateCode`'s own PO(s)) instead of globally flattened across all templates; `progress` recomputed as a sum of each template's own correctly-scoped completion count instead of one global match. **Update 8** adds: zero new backend files/endpoints, zero new frontend files — edits confined to `ViewSalesOrderPage.jsx`: one new `selectedTemplateCode` state + one new default-first-template `useEffect` (cloned from `MapFilePage.jsx` lines 360/500-509); one added `poCode: poDoc.poCode` field on each `realAvailableFiles` entry (line ~512-527, mirroring `MapFilePage.jsx`'s own builder since its Update 5); one new `purchIdToTemplateCode` `useMemo` + one new `templateComputations` `useMemo` (cloned from Update 7's Decision 29); the toolbar's 3 hardcoded `Chip`s (lines 822-824) replaced with a `templatesData.map(...)` of real chips + `onClick={() => setSelectedTemplateCode(t.templateCode)}` (no refetch, per FR-063); the Template Checklist's `templatesData.map(...)` stacked-tree render (lines 872-899) replaced with a single selected-template tree render (cloned from `MapFilePage.jsx` lines 1226-1231), fed that template's own scoped `derivedFileMappings`/`filesForTemplate` instead of the global `fileMappings`/`realAvailableFiles`; Validation Summary's `requiredDetails`/`mappedRequired`/`missingRequired`/`pct` (lines 580-588) recomputed as a sum of each template's own correctly-scoped completion count (cloned from Update 7's Decision 30), replacing the current single pass over globally-flattened `allDetails`. **Update 9** adds: zero new backend files/endpoints, zero new frontend infrastructure files (reuses `EutrFileViewerDialog.jsx` and every use case it internally calls, already owned by `004-eutr-documents`) — edits confined to `MapFilePage.jsx`: one new `viewerFile` state (cloned from `004-eutr-documents/index.jsx`'s own `viewerFile` state), one new `IconButton` (MUI `Visibility` icon) next to the existing Edit `IconButton` (lines 1434-1450) wired to open it, and one new `<EutrFileViewerDialog />` render call. **Update 10** adds: 1 new controller action (`EutrDocumentsController.DownloadZip`) + 3 new small request DTOs (`EutrDownloadZipRequestDto`/`EutrDownloadZipFolderDto`/`EutrDownloadZipFileDto`) — no new controller, no new Application service, no new repository/entity, no migration, no new policy; frontend adds 1 new use case (`DownloadEutrSalesOrderZipUseCase`) + additive methods on the already-existing `eutrDocumentsApi.js`/`IEutrDocumentsRepository.js`/`RestEutrDocumentsRepository.js` — edits confined to `ViewSalesOrderPage.jsx`: wire the existing Download button's `onClick` to build the `folders` payload from `templateComputations` (Update 8) and trigger the blob-download. **Update 11** adds: zero new backend files/endpoints, zero new frontend files — a single-line edit inside `MapFilePage.jsx`'s existing `computeProgress()` function (add `&& !AUTO_SOURCES.includes(d.takeFrom)` to its `required` filter predicate); no change to `ViewSalesOrderPage.jsx`. **Update 12** adds: 2 new controller actions (`EutrPurchaseAttachmentsController.GetTemplatesBySalesIdsRaw`/`by-sales-ids-raw`, `EutrTemplatesController.GetManyByCodes`/`by-codes`) + 1 new service method each + 1 new repository method each (all on already-existing files, no new controller/service/repository/entity class); zero new DTOs (both reuse `PurchaseAttachmentDto`/`EutrTemplatesResponseDto` as-is); 1 new frontend util file (`utils/progressUtils.js`) + 2 new use cases (`GetPurchaseAttachmentsBySalesIdsRawUseCase`, `GetEutrTemplatesByCodesUseCase`) + additive methods on the already-existing `eutrPurchaseAttachmentsApi.js`/`IEutrPurchaseAttachmentsRepository.js`/`RestEutrPurchaseAttachmentsRepository.js` and `eutrTemplatesApi.js`/`IEutrTemplatesRepository.js`/`RestEutrTemplatesRepository.js`; edits to `MapFilePage.jsx`/`ViewSalesOrderPage.jsx` (refactor local `AUTO_SOURCES`/`computeProgress`/`templateComputations` to import from the new shared util, behavior-preserving) and a substantial edit to `SalesOrderOverviewPage.jsx` (new `fetchProgressForRows`, remove `DEMO_PROGRESS`, render the 4-state Progress cell). **Update 13** adds: zero new backend files/endpoints/DTOs/policies (100% reuse of `download-zip` and Update 12's new `by-codes` endpoint); zero new frontend infrastructure files (reuses `GetPurchaseAttachmentsBySalesIdUseCase`, `GetEutrDocumentsPoReferencesUseCase`, `DownloadEutrSalesOrderZipUseCase`, and Update 12's `GetEutrTemplatesByCodesUseCase`, all unchanged) — edits confined to `SalesOrderOverviewPage.jsx`: wire the existing Download `IconButton`'s `onClick` to a new per-row `handleDownload(salesId)` (on-demand pipeline + `buildTemplateComputations` from the shared util → `folders` payload), add a new `downloadingSalesIds` `Set` state for per-row in-flight/spinner state. **Update 14** adds: zero new backend files, zero new frontend infrastructure files — edits confined to 3 already-existing frontend files: `SalesOrderOverviewPage.jsx` (add `useSearchParams`, seed `search`/`page`/`pageSize` from the URL on mount instead of hardcoded defaults, sync state → URL on change via `{ replace: true }`, pass `{ state: { fromOverview: true } }` on the two existing Map File/View `navigate()` calls), `MapFilePage.jsx` and `ViewSalesOrderPage.jsx` (each: add `useLocation`, replace the Back button's inline `onClick` with a small `handleBack` that calls `navigate(-1)` when `location.state?.fromOverview` is true, else falls back to the already-shipped `navigate('/eutr/sales-orders')`). **Update 15** adds: zero new backend files/endpoints/DTOs/policies, zero new frontend infrastructure files (reuses `EutrFileViewerDialog` unchanged, same as Update 9) — edits confined to `ViewSalesOrderPage.jsx`: one new `selectedStepId` state, one new `viewerFile` state (cloned from `MapFilePage.jsx`'s own Update 9 state), one new `useMemo` resolving the panel's file list (full `filesForTemplate` vs. step-scoped subset of `derivedFileMappings`), a small `onSelect` wiring added to the existing `ViewNode` tree (row click → `setSelectedStepId`, collapse arrow click unchanged), one new small `typeName: doc.typeName` field added to the existing `realAvailableFiles` builder, one new `IconButton` (View) per file row, and the new AVAILABLE FILES `Box` itself rendered below the existing "Steps missing files" list. **Update 16** adds: 1 new repository method (`GetSalesIdsWithTemplateAsync`) + 1 new service method + 1 new controller action (`GET by-sales-ids-with-template`/`sales-ids-with-template`, on the already-existing `EutrPurchaseAttachmentsController`/`Service`/`IEutrPurchaseAttachmentsRepository` — no new controller/service/repository/entity class, no new DTO); frontend adds 1 new use case (`GetSalesIdsWithTemplateUseCase.js`) + 1 additive method each on the already-existing `eutrPurchaseAttachmentsApi.js`/`IEutrPurchaseAttachmentsRepository.js`/`RestEutrPurchaseAttachmentsRepository.js`, plus edits to `SalesOrderOverviewPage.jsx`'s existing fetch logic (new `salesIdsWithTemplate` state, branch on search-empty to build the whitelist `FilterRequest[]` or skip the call when empty, unchanged path when searching). **Update 17** adds: 1 backend edit — a single new entry in `ComplDynamicsService.EntityMappings` (no new file, no new class, no new DTO, no migration); frontend adds zero new files — edits confined to `MapFilePage.jsx`: 1 new `EUTR_SALES_ORDER_PURCH_LINE_REF_TYPE = 20` constant, 1 new `useEffect` (mirroring the existing `refType=16` PO-list effect) + 1 new `poLinesByPurchId`/`poLinesLoading`/`poLinesError` state group, and the two static "Variants"/"Materials" `Typography` placeholders in the Step 1 `TableContainer` replaced with computed cell content read from that new state. **Update 18** adds: zero new backend files/endpoints/DTOs/migrations (reuses Update 17's `EntityMappings[20]` registration unchanged) - frontend adds zero new files either, edits confined to `ViewSalesOrderPage.jsx`: the same `EUTR_SALES_ORDER_PURCH_LINE_REF_TYPE = 20` constant + `poLinesByPurchId`/`poLinesLoading`/`poLinesError` state group + batched `useEffect` cloned from `MapFilePage.jsx`'s Update 17 addition, and the two hardcoded `Variants`/`Materials` `Typography` cells in the Selected Purchase Orders table replaced with the same computed-cell/loading/error rendering `MapFilePage.jsx` already uses. **Update 19** adds: zero new backend files/endpoints/DTOs/migrations (reuses `GetPagingEutrTemplatesUseCase`/`GetEutrTemplatesUseCase` unchanged, same as every real template chip since Update 4); frontend adds one new pure function to the already-existing `utils/treeUtils.js` (filter-a-flat-list-by-a-keep-set-and-reparent-orphaned-descendants, colocated with `flatToTree`/`removeNodeAndDescendants`) — no new file. Edits confined to `ViewSalesOrderPage.jsx`: one new `defaultTemplate`/`defaultTemplateLoading`/`defaultTemplateError` state group, one new click handler branch on the All chip (fetch-on-click, mirroring the existing per-chip fetch shape), one new `useMemo` building the filtered/reparented All tree (via the new util function) plus a second `useMemo` unioning every template's `filesForTemplate` for AVAILABLE FILES when All is active, and the existing tree/AVAILABLE FILES render branches extended with an `All`-active case alongside the existing single-template case. **Update 20** adds: zero new backend/frontend files — a small edit to `ViewSalesOrderPage.jsx`'s `selectedTemplateCode` initial-selection logic (defaults to `null`/All instead of the first real template) plus one new `useEffect` calling Update 19's own `loadDefaultTemplate` automatically once `templatesData` first becomes non-empty, instead of waiting for an explicit All-chip click. **Update 21** adds: zero new backend controller/service/repository/entity classes, zero new DTO types, zero migration, zero new policy — one existing request DTO field reshaped (`EutrDownloadZipFolderDto.FolderName` (string) → `FolderPath` (`List<string>`)) and a small, localized edit to `EutrDocumentsController.DownloadZip`'s per-folder name derivation (join sanitized path segments with `/` instead of sanitizing one string); frontend adds one new pure function to the already-existing `utils/treeUtils.js` (`flattenTreeToFolderEntries`, flattens a tree into one `{folderPath, files}` entry per node) — no new file. Edits confined to `ViewSalesOrderPage.jsx` (reshape each per-template `folders` entry to `folderPath: [templateName]`, append the new All-folder entries built from Update 19's already-loaded `allChipTree`/`allChipDerivedFileMappings`/`allChipFiles` — no new fetch) and `SalesOrderOverviewPage.jsx` (same per-template reshape, plus one new on-demand default-template fetch reusing Update 19's exact 2-call chain, added to the existing `Promise.all`).

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
  **Update 12**: backend changes stay inside already-existing `Application`/`Infrastructure` files on
  two already-existing controllers (`EutrPurchaseAttachmentsController`/`EutrTemplatesController`) — new
  actions delegate to new service methods delegate to new repository methods, the same
  `Api → Application → Domain`/`Infrastructure` shape every prior update in this feature follows; no
  controller contains business logic beyond delegation. Frontend: the new
  `presentation/pages/eutr-sales-orders/utils/progressUtils.js` is a plain util module (not a new
  layer) consumed by `presentation/` components only, exactly like the existing `utils/treeUtils.js`;
  `SalesOrderOverviewPage.jsx` consumes the two new use cases through the existing
  `domain/interfaces` → `infrastructure/repositories` chain (additive methods on already-registered
  repositories) — no layer skipped or bypassed.
  **Update 13**: no backend layer is touched at all (100% reuse of Update 10's `download-zip` and
  Update 12's `by-codes`). Frontend: `SalesOrderOverviewPage.jsx` consumes the same already-layered
  chains Update 12 established (`GetEutrTemplatesByCodesUseCase`) plus two already-existing chains
  (`GetPurchaseAttachmentsBySalesIdUseCase`, `GetEutrDocumentsPoReferencesUseCase`,
  `DownloadEutrSalesOrderZipUseCase`) — no new interface, repository, or use-case file, no layer
  skipped or bypassed.
  **Update 14**: no backend layer is touched at all, and no new frontend layer is introduced — every
  change lives entirely inside 3 already-existing presentation-layer files' own routing/state handling
  (`useSearchParams`/`useLocation`/`useState`, all from the already-used `react-router-dom` package),
  consuming the exact same already-layered `GetReferenceDataUseCase` chain Overview's mount effect
  already used (Update 1/12) — only the arguments passed to it change, not the chain itself. No new
  interface, repository, or use-case file, no layer skipped or bypassed.
  **Update 15**: no backend layer is touched at all. Frontend: `ViewSalesOrderPage.jsx` (presentation)
  imports `EutrFileViewerDialog` — the same cross-feature presentation-to-presentation import already
  established for it in Update 9 (there for `MapFilePage.jsx`, here for its sibling screen); the dialog
  itself already correctly delegates its one read (`GetEutrDocumentsFileByIdRefUseCase`) through
  `application/usecases/` → `domain/interfaces` → `infrastructure/repositories` (unchanged) —
  `ViewSalesOrderPage.jsx` never reaches around it to call a use case directly for View. The new
  step-filtering panel itself is pure presentation-layer derived state (`useState`/`useMemo`) over data
  already delivered through this page's existing layered chains (Update 4/7/8/12) — no new interface,
  repository, or use-case file, no layer skipped or bypassed.
  **Update 16**: backend change adds one new method to each of the already-existing
  `Api → Application → Domain`/`Infrastructure` layers on `EutrPurchaseAttachmentsController` →
  `IEutrPurchaseAttachmentsService`/`EutrPurchaseAttachmentsService` →
  `IEutrPurchaseAttachmentsRepository`/`EutrPurchaseAttachmentsRepository` (Update 1's own stack) — no
  layer skipped, no new layer introduced. Frontend: `domain/interfaces/
  IEutrPurchaseAttachmentsRepository.js` → `infrastructure/api/eutrPurchaseAttachmentsApi.js` +
  `infrastructure/repositories/RestEutrPurchaseAttachmentsRepository.js` → `application/usecases/
  eutr-purchase-attachments/GetSalesIdsWithTemplateUseCase.js` (new) → `SalesOrderOverviewPage.jsx` —
  the same already-established chain shape, one new use case at the end of it, no layer bypassed. The
  existing `GetReferenceDataUseCase` → `IDynamicsRepository` → `RestDynamicsRepository` chain (refType
  = 11) is unchanged — this update only changes the `FilterRequest[]` argument value passed into it.
  **Update 17**: backend change is a single dictionary entry inside `ComplDynamicsService.cs`
  (`ComplianceSys.Application`) — no layer added, skipped, or bypassed; `DynController` (`Api` layer)
  is unchanged, it already delegates to the service and takes `refType` as a plain parameter, the exact
  same shape every other `refType` already uses. Frontend: `MapFilePage.jsx` (presentation) consumes the
  new fetch through the existing `GetReferenceDataUseCase` → `domain/interfaces/IDynamicsRepository` →
  `infrastructure/repositories/RestDynamicsRepository` chain — the same chain, same instance, already
  wired for `refType=16`'s PO-list call since Update 2, just invoked a second time with `refType=20` —
  no new interface, repository, or use-case file, no layer skipped or bypassed.
  **Update 19**: no backend layer is touched at all. Frontend: `ViewSalesOrderPage.jsx` (presentation)
  fetches the default template through the exact same `GetPagingEutrTemplatesUseCase`/
  `GetEutrTemplatesUseCase` → `domain/interfaces/IEutrTemplatesRepository` →
  `infrastructure/repositories/RestEutrTemplatesRepository` chain already wired since Update 4 for each
  real template chip — invoked a second time with an `IsDefault = 1` filter instead of a `Code` filter,
  same instances, no new interface/repository/use-case file. The new tree-filter-with-reparenting and
  cross-template "has document" lookup are pure presentation-layer derived state
  (`useMemo`, plus one new colocated pure function in the existing `utils/treeUtils.js`) — no new
  layer, no layer skipped or bypassed.
  **Update 21**: backend change stays entirely inside `EutrDocumentsController.DownloadZip` (`Api`
  layer, already the owner of this action since Update 10) and its own request DTO
  (`EutrDownloadZipFolderDto`, `Application` layer) — no `Domain`/`Infrastructure` file is touched, no
  new layer added. Frontend: both `ViewSalesOrderPage.jsx` and `SalesOrderOverviewPage.jsx`
  (presentation) build the extra `folders` entries from data already delivered through existing,
  already-layered chains (View: Update 19's `defaultTemplate`/`allChipTree` derived state, itself fed by
  the already-layered `GetPagingEutrTemplatesUseCase`/`GetEutrTemplatesUseCase` chain; Overview: the same
  chain invoked directly, mirroring Update 13's own on-demand pattern) and pass the result through the
  already-layered `DownloadEutrSalesOrderZipUseCase` → `IEutrDocumentsRepository` →
  `RestEutrDocumentsRepository` chain (Update 10), unchanged — no new interface/repository/use-case
  file, no layer skipped or bypassed.
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
  **Update 12**: the concrete reference for "add a batch variant of an existing single-item read" is
  this feature's own Update 1 (`GetTemplatesBySalesIdsAsync`, cloned in shape by the new
  `GetBySalesIdsAsync`/`by-sales-ids-raw`) and `GetByIdWithDetailsAsync` (cloned in shape, widened from
  one `Id` to `Code IN @Codes`, by the new `GetManyByCodesWithDetailsAsync`/`by-codes`) — both new
  endpoints reuse already-working SQL/DTO shapes rather than inventing new ones (research.md Decisions
  43-44). The extraction of `AUTO_SOURCES`/`computeProgress`/per-template file-scoping into a shared
  `progressUtils.js` (Decision 42) directly closes the "reasonable future cleanup if a third consumer
  appears" gap Decision 40/41 explicitly flagged and deferred — this update is that third consumer.
  **Update 13**: the concrete reference for "reuse an already-shipped screen's action from a new
  screen" is `ViewSalesOrderPage.jsx`'s own Update 10 Download wiring (`buildDownloadFolders`/
  `handleDownload`) — cloned into `SalesOrderOverviewPage.jsx` as a per-row, on-demand variant, reusing
  the same shared `buildTemplateComputations` util (Decision 42) rather than a 3rd inline copy of that
  grouping logic.
  **Update 14**: the concrete reference for "persist list state across navigation via the URL" is this
  codebase's own `compliance-master/index.jsx` (and its siblings `compliance-management/index.jsx`,
  `compliance-detail/index.jsx`) — their existing `page`/`page-size` `useSearchParams` +
  `{ replace: true }`-on-change pattern is cloned into `SalesOrderOverviewPage.jsx` verbatim, extended
  with one new `search` key this screen alone needs; the alternative `sessionStorage`-based pattern
  already used by `dashboard/index.jsx`/`search-result/index.jsx` was evaluated and not chosen
  (research.md Decision 53) because it does not make the in-app Back button and the browser's own Back
  button behave identically (FR-097) as naturally as the URL-based pattern does.
  **Update 15**: the concrete reference for "reuse an existing screen's file-preview popup from a
  different feature's screen" is, again, `004-eutr-documents`'s own `EutrFileViewerDialog.jsx` —
  reused verbatim, the exact same instance/props contract Update 9 already established for
  `MapFilePage.jsx`, not a second, `View`-owned copy. The concrete reference for "filter a derived file
  list by a clicked tree node, including its descendants" is this feature's own
  `buildTemplateComputations`/`derivedFileMappings` (Update 7/8/12, shared `progressUtils.js`) — the new
  panel walks the already-built tree/`derivedFileMappings` it already has, rather than introducing a
  second per-step file-matching algorithm; clearing the filter on template-chip click reuses the exact
  `onClick` handler this screen's toolbar already has (Update 8) by simply adding one more state reset
  to it, not a new click-handling mechanism.
- **Update 16**: the concrete reference for "add an unscoped batch/list read to an already-existing
  repository" is this feature's own Update 1 `GetTemplatesBySalesIdsAsync` (`SELECT DISTINCT ... INNER
  JOIN eutr_templates ... WHERE SalesId IN @SalesIds`) — the new `GetSalesIdsWithTemplateAsync` clones
  its `SELECT DISTINCT` shape, dropping the input-list predicate and the `eutr_templates` join (research.md
  Decision 60). The concrete reference for "express a whitelist filter without any new backend code" is
  this codebase's own already-existing, already-exercised same-bucket OR-join in
  `ComplDynamicsService.BuildFilterString` — the same mechanism the search box's own Code/Name filter
  already depends on — reused as a new pattern of *usage* (many `eq` entries instead of one `like`
  entry), not a new mechanism (research.md Decision 61).
- **Update 17**: the concrete reference for "fix a missing `EntityMappings` registration" is this same
  dictionary's own prior fixes for `refType=18` (`009-compl-sales-order-missing`) and `refType=19`
  (`011-eutr-synchronize-data`) — both documented in-place by comments already in `ComplDynamicsService.cs`
  — cloned as a third instance of the exact same one-line pattern (research.md Decision 63), not a new
  kind of fix invented for this feature. The `CodeColumn`/`NameColumn` chosen for the new entry clone
  `MapSortColumn`'s own already-existing assumption for this entity, rather than inventing a different
  pairing. The frontend fetch/group-by-PO shape clones this feature's own established "batch once per
  Sales ID, not once per row" precedent (Update 1/12's `fetchTemplatesForRows`/`fetchProgressForRows`,
  research.md Decision 64) and its own established "build a lookup once, reuse at each call site" shape
  (`purchIdToTemplateCode`, Update 7 Decision 29) — not a new state-management approach.
- **Update 19**: the concrete reference for "fetch one template by a filter other than `Code`" is this
  screen's own existing per-chip fetch (`getPagingEutrTemplatesUseCase.execute(1, 1, 'Code', 'asc',
  [{ column: 'Code', operator: 'eq', value: templateCode }])`, lines 553-558) — cloned with the filter
  swapped to `{ column: 'IsDefault', operator: 'eq', value: 1 }` (already a whitelisted filter column on
  `EutrTemplatesRepository.GetPagedAsync`, confirmed in `research.md` Decision 67), not a new query
  mechanism. Tree-filter-with-reparenting is the one genuinely new algorithm this update introduces —
  no existing precedent in this codebase performs this shape of operation, so it is implemented as one
  new pure function colocated with (and following the same input/output shape as) the existing
  `flatToTree`/`removeNodeAndDescendants` functions in `utils/treeUtils.js`, not a divergent one-off
  inline in `ViewSalesOrderPage.jsx` (research.md Decision 68).
- **Update 21**: the concrete reference for "flatten a tree into per-node entries" is this same file's
  own `flatToTree`/`filterFlatListByStepIds` (Update 19) — the new `flattenTreeToFolderEntries` is
  colocated with them, takes/returns the same node shape (`{id, stepName, children}`), and reuses
  Update 19's already-computed `allChipTree`/`allChipDerivedFileMappings`/`allChipFiles` rather than
  re-deriving the All tree or its file mapping a second way. The one existing request-DTO field
  (`FolderName` → `FolderPath`) is reshaped, not replaced with a second, parallel payload shape — the
  same `folders[]` envelope, empty-folder rule, and per-folder filename-dedup rule from Update 10 apply
  unchanged (research.md Decision 69). Overview's new on-demand default-template fetch clones Update 19's
  exact 2-call chain rather than inventing a second way to resolve the default template.
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
  **Update 12**: verified the existing `by-sales-ids` action's aggregated response cannot serve this
  update's need without breaking its own existing Template-column consumer — Principle III's "additive,
  don't break an existing consumer" rule (already applied identically to `list-po-references` in Update
  5) is satisfied by adding a new, small, sibling action (`by-sales-ids-raw`) instead of changing
  `by-sales-ids`' shape. Verified `list-po-references` needs zero change (already SalesId-agnostic,
  research.md Decision 45) — reused as-is, sending a larger `PoCodes` array than any prior caller. The
  one genuine gap (no batch "many templates' full details in one call" endpoint exists) is filled by a
  new, small, additive `by-codes` action, modeled on `GetByIdWithDetailsAsync`'s already-working SQL.
  **Update 13**: no gap exists — `download-zip` (Update 10) is already fully generic and reused
  unmodified; the one new endpoint this whole pair of updates introduces (`by-codes`, Update 12) is
  reused here too, not duplicated a second time for Overview's on-demand case.
  **Update 14**: no backend endpoint of any kind is touched — Principle III is not implicated; this is
  a pure frontend routing/state fix, the same category as Update 11.
  **Update 15**: verified `GET /api/eutr-documents/get-file-by-idref` (the only endpoint this update's
  new View button reaches, indirectly through `EutrFileViewerDialog`) is already reused unmodified by
  `MapFilePage.jsx` since Update 9 — no new backend code, no new endpoint, no new field. The one
  data-mapping fix this update needs (`typeName` onto each `realAvailableFiles` entry) reads a field
  `list-po-references`'s response has already returned since this feature's own Update 5 — the exact
  same "already-returned field this screen simply never read" class of gap Update 8 already found and
  fixed for `poCode`, not a new gap requiring new backend work. Principle III is satisfied in its purest
  form: zero new backend code, 100% reuse of already-fetched/already-returned data.
  **Update 16**: verified `ComplDynamicsService`/`DynController`'s existing `FilterRequest[]` handling
  already OR-joins same-bucket entries (`BuildFilterString`, unmodified) — Principle III is satisfied in
  its purest form for the whole D365-filtering half of this update: zero new backend code, reusing the
  existing generic reference endpoint exactly as every other caller of it already does, just with a
  differently-shaped filter array. The one verified gap is the whitelist source itself — no existing
  action on `EutrPurchaseAttachmentsController` already returns "every Sales ID with a saved row,
  unscoped to an input list" (every existing action requires an input Sales ID/list) — filled by one new,
  small, additive action on the controller/service/repository Update 1 already created, not a new
  controller/service/repository/entity class.
  **Update 17**: verified — by reading, not assuming — that `RSVNEutrSalesOrderPurchLines`'s entity class,
  `MapDynamicsResponse`'s `case 20:`, `MapSortColumn`'s entries for this entity, and every
  `ComplDynReferenceResponseDto` field `case 20` assigns **all already exist and already compile**;
  `POST /api/dynamics/reference` (`DynController.ReferenceData`) already exists and MUST be reused as-is
  (no new controller action, no per-`refType` route). The one verified, scoped gap is narrower than any
  prior update in this feature has found: not a missing endpoint, not a missing DTO field, not a missing
  response-mapping case — a single missing dictionary entry (`EntityMappings[20]`) that gates all of the
  above from ever running. Filling exactly that one entry, and nothing else, is what Principle III
  requires here — touching the entity/case/DTO/controller would edit already-correct code for no reason.
  **Update 19**: verified — by reading `EutrTemplatesRepository.GetPagedAsync` — that `IsDefault` is
  already a whitelisted filter column (`FilterMap["IsDefault"] = "t.IsDefault"`) and that
  `IsDeleted = 0`/`IsHide = 0` are already unconditional `WHERE` clauses on every call to this method, so
  fetching "the template with `IsDefault = 1`/`IsHide = 0`/`IsDeleted = 0`" needs **zero backend change**
  of any kind — it is the exact same paged-then-`GetById` call this screen already makes per real
  template chip (Update 4), with one filter value swapped. Principle III is satisfied in its purest
  form here too: zero new backend code, zero new endpoint, 100% reuse of an existing, already-tested
  query path. Also verified — by reading `EutrTemplatesRepository.cs`'s `ClearGlobalDefaultAsync`/
  `SetIsDefaultAsync` (003-eutr-templates) — that the system already enforces at most one global default
  template at a time, so this query is expected to return 0 or 1 row in normal operation; no new
  uniqueness constraint or validation is added by this update, it only reads an invariant another
  feature already maintains.
  **Update 21**: verified — by reading `EutrDocumentsController.DownloadZip` — that its zip-writing code
  (`archive.CreateEntry($"{folderName}/")`, `GetUniqueZipEntryName`'s `Path.GetDirectoryName`-based
  disambiguation) already treats `folderName` as an arbitrary `/`-delimited path string, not one that is
  assumed to be exactly one segment deep; the only line that assumes single-segment input is
  `SanitizeZipNamePart(folder.FolderName, "template")`, called once per folder. Reshaping `FolderName`
  into `FolderPath` and sanitizing each segment before joining is the smallest change that lets the
  already-existing zip-writing code handle nested folders correctly — no new endpoint, no new
  service/repository, no migration; the "client supplies the folder→file grouping, server just
  fetches+zips" trust model from Update 10 (research.md Decision 37) is unchanged. Also verified — by
  reading `ViewSalesOrderPage.jsx`'s Update 19/20 code — that `allChipTree`/`allChipDerivedFileMappings`/
  `allChipFiles` already correctly implement the tree-filter/reparent and cross-template file-union rules
  this folder needs; Download reuses them exactly rather than recomputing the same rules a second way.
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
  **Update 12**: new backend code (the 2 new controller actions/service methods/repository methods)
  MUST carry Vietnamese comments matching this codebase's existing unaccented-ASCII style (e.g.
  `EutrPurchaseAttachmentsRepository.cs`'s existing comments). The new `progressUtils.js` util and the
  edits inside `MapFilePage.jsx`/`ViewSalesOrderPage.jsx`/`SalesOrderOverviewPage.jsx` MUST carry
  Vietnamese comments matching each file's own existing style. The two new Progress-cell placeholder
  strings this update introduces (FR-083's blank state, FR-084's "no Required steps" caption) render in
  the same language `SalesOrderOverviewPage.jsx`'s existing empty-state/search copy already uses
  (Vietnamese) — no new English label is introduced; the removed `DEMO_PROGRESS` was itself just a
  numeric placeholder, not a label.
  **Update 13**: no new backend code (no comments needed there — zero backend change). The new
  `handleDownload(salesId)`/`downloadingSalesIds` logic in `SalesOrderOverviewPage.jsx` MUST carry
  Vietnamese comments matching this file's own existing style. The one new user-facing string this
  update needs (the "không có tài liệu nào để tải" empty-state message, FR-089) reuses the exact same
  Vietnamese copy already shipped for View's Download (FR-074/Update 10) — not a new translation
  decision.
  **Update 14**: no new backend code (no comments needed there — zero backend change). The new
  `useSearchParams`/`useLocation` wiring in `SalesOrderOverviewPage.jsx`/`MapFilePage.jsx`/
  `ViewSalesOrderPage.jsx` MUST carry Vietnamese comments matching each file's own existing style. No
  new user-facing label is introduced — the search box's existing placeholder, the Back button's
  existing label/icon, and the table's existing empty-state text are all unchanged; only their
  underlying state-restoration mechanics change.
  **Update 15**: no new backend code (no comments needed there — zero backend change). The new
  `selectedStepId`/`viewerFile` state, the new file-list `useMemo`, the `ViewNode` row-click wiring, and
  the `typeName` data-mapping fix in `ViewSalesOrderPage.jsx` MUST carry Vietnamese comments matching
  this file's own existing style (e.g. its Update 8 comments on `purchIdToTemplateCode`/
  `templateComputations` are the direct model). The one new user-facing label this update introduces —
  the section header **"AVAILABLE FILES"** — is kept in English, matching the exact label/casing already
  shipped for the same section on `MapFilePage.jsx` (Update 2), not a new translation decision; the
  empty-state strings ("No files available"/"No files for this step") follow this same English
  precedent, matching `MapFilePage.jsx`'s own English empty-state text for the same section ("No files
  found"). The reused popup's own labels/tooltips (already English, per `004-eutr-documents`) are
  unchanged, just rendered from within a second screen (same as Update 9).
- **Update 16**: the new `EutrPurchaseAttachmentsController`/`Service`/`Repository` method MUST carry
  Vietnamese comments matching this same file's own existing style (Update 1/2/12). No new user-facing
  label is introduced — the default/search-toggle behavior changes which rows appear, not any button/
  header/placeholder text on `SalesOrderOverviewPage.jsx`; the existing "No data" empty state (FR-012)
  is reused verbatim for the empty-whitelist case (FR-112), not a new string.
- **Update 17**: the one new `EntityMappings` dictionary line in `ComplDynamicsService.cs` MUST carry a
  Vietnamese comment explaining the fix (matching this same dictionary's own existing Vietnamese comments
  for the `refType=18`/`refType=19` fixes it documents, e.g. lines 45-51). `MapFilePage.jsx`'s new
  `useEffect`/state/render edits MUST carry Vietnamese comments matching this file's own existing style
  (e.g. its Update 2 comment on the `refType=16` PO-list effect, the direct model for the new one). No
  new English UI label is introduced — **"Variants"** and **"Materials"** are pre-existing column headers
  already shipped in the Step 1 table's JSX (currently rendering static placeholder text); this update
  only makes their cell content dynamic, it does not add or rename any header/button/placeholder text.
  The new empty-state value ("—" or equivalent) follows this same row's existing convention for other
  blank/unavailable cells in this table, not a new translation decision.
- **Update 19**: all new `ViewSalesOrderPage.jsx` code (the default-template fetch, the tree-filter-
  with-reparenting logic, the cross-template file-mapping lookup) MUST carry Vietnamese comments
  matching this file's own existing style (e.g. its Update 8 comments on `selectedTemplateCode`/
  `templateComputations`, the direct model for this update's new derived state); the new pure function
  added to `utils/treeUtils.js` MUST carry a Vietnamese comment following that file's own existing
  comment style for `flatToTree`/`removeNodeAndDescendants`. No new English UI label is introduced —
  the **All** chip's label text already exists (currently a static, non-functional chip per FR-058's
  "before" state); this update only changes its behavior, not its text. New empty-state strings ("no
  default template configured", "no steps match") follow this screen's own existing English precedent
  for other empty states in this same Template Checklist/AVAILABLE FILES area (Update 4/15).
- **Update 21**: all new/edited code (`EutrDocumentsController.DownloadZip`'s per-folder name
  derivation, the reshaped `EutrDownloadZipFolderDto`, the new `flattenTreeToFolderEntries` in
  `utils/treeUtils.js`, and the `buildDownloadFolders`/per-row Download edits in
  `ViewSalesOrderPage.jsx`/`SalesOrderOverviewPage.jsx`) MUST carry Vietnamese comments matching each
  file's own existing style. No new UI label is introduced at all — the All folder's names inside the
  downloaded zip come from `eutr_steps` business data (the same `stepName` field the Template Checklist
  tree already renders on screen), not from a code-owned UI string; the existing "no documents to
  download"/error snackbar text (FR-074/FR-089, unchanged) is not touched by this update.
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
  **Update 12**: no route/menu change at all — `SalesOrderOverviewPage.jsx`'s own route
  (`/eutr/sales-orders`) already exists and is unaffected. The two new endpoints reuse already-DB-seeded
  read policies (`EutrPurchaseAttachments.Read` — same policy as `by-sales-ids`/`by-sales-id/{salesId}`;
  `EutrTemplates.ReadAll` — same policy as `get-all`) — no new policy code, no new ops-seeding step;
  Progress is a new computed cell inside the already-reachable Overview grid, not a new screen.
  **Update 13**: no route/menu/policy change at all — reuses `EutrDocuments.ReadAll` (already seeded
  for `download-zip` since Update 10) and the two read policies above; Download is a new interaction
  inside the already-reachable Overview grid, not a new screen.
  **Update 14**: no route/menu/policy change at all — `SalesOrderOverviewPage.jsx`'s,
  `MapFilePage.jsx`'s, and `ViewSalesOrderPage.jsx`'s own routes are unaffected; adding query
  parameters to an already-registered route's URL and a one-shot `location.state` flag on an
  already-registered `navigate()` call introduce no new route, no new menu entry, no new
  authorization policy.
  **Update 15**: no route/menu/policy change at all — `ViewSalesOrderPage.jsx`'s own route
  (`/eutr/sales-orders/:salesId/view`) already exists and is unaffected; the one endpoint the new View
  button reaches (`get-file-by-idref`) keeps whatever authorization policy it already carries under
  `004-eutr-documents` (same policy already exercised by `MapFilePage.jsx` since Update 9) — no new
  action, no new route, no new menu entry; AVAILABLE FILES is a new panel inside the already-reachable
  View screen, not a new screen.
  **Update 16**: no route/menu/policy change at all — `SalesOrderOverviewPage.jsx`'s own route
  (`/eutr/sales-orders`) already exists and is unaffected. The new `sales-ids-with-template` action
  reuses the already-DB-seeded `EutrPurchaseAttachments.Read` policy (same policy as `by-sales-ids`/
  `by-sales-id/{salesId}`/`by-sales-ids-raw`) — no new policy code, no new ops-seeding step; the
  existing `refType=11` call's own authorization is untouched. This is a new default-filtering behavior
  inside the already-reachable Overview grid, not a new screen.
  **Update 17**: no route/menu/policy change at all — `MapFilePage.jsx`'s own route
  (`/eutr/sales-orders/:salesId/map-file`) already exists and is unaffected. The new `refType=20` call
  reuses whatever authorization `POST /api/dynamics/reference` already requires ( `[Authorize]`, no
  per-`refType` policy — the same, unmodified authorization every other `refType` on this endpoint,
  including `refType=16`, already relies on) — no new policy code, no new ops-seeding step; Variants/
  Materials are two new display columns inside the already-reachable Step 1 table, not a new screen.
  **Update 19**: no route/menu/policy change at all — `ViewSalesOrderPage.jsx`'s own route already
  exists and is unaffected. The default-template fetch reuses the already-DB-seeded
  `EutrTemplates.ReadAll` policy every real template chip already relies on since Update 4 (same
  `GetPagingEutrTemplatesUseCase`/`GetEutrTemplatesUseCase` calls, no new action, no new policy code, no
  new ops-seeding step); All is a new behavior for an already-present toolbar chip inside the
  already-reachable View screen, not a new screen or a new route.
  **Update 21**: no route/menu/policy change at all — both Download buttons' own routes/screens already
  exist and are unaffected. `DownloadZip` keeps its existing `EutrDocuments.ReadAll` policy unchanged
  (same policy Update 10 already wired); the reused default-template fetch (for Overview) keeps the
  same `EutrTemplates.ReadAll` policy Update 19 already relies on — no new action, no new policy code, no
  new ops-seeding step. The All folder is additional content inside an already-reachable Download
  action, not a new screen, route, or menu entry.

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
│   │                                            # EDIT (Update 17): documents the new refType=20 call
│   │                                            #       (Step 1 Variants/Materials) + the one-line
│   │                                            #       EntityMappings[20] backend fix that makes it
│   │                                            #       reachable - zero new controller action/DTO
│   ├── view-sales-order-reused-endpoints.md    # NEW (Update 4) - traceability only, no new contract
│   │                                            # EDIT (Update 8): notes that list-po-references'
│   │                                            #       poCode field (Update 5, already consumed by
│   │                                            #       MapFilePage.jsx) is now also read by
│   │                                            #       ViewSalesOrderPage.jsx - zero contract change
│   │                                            # EDIT (Update 15): notes get-file-by-idref (already
│   │                                            #       reused by MapFilePage.jsx since Update 9) is
│   │                                            #       now also reached, indirectly via
│   │                                            #       EutrFileViewerDialog, from this screen's new
│   │                                            #       View button - zero contract change; also notes
│   │                                            #       list-po-references' typeName field (Update 5)
│   │                                            #       is now also read by this screen
│   ├── eutr-documents-download-zip.md          # NEW (Update 10) - the one genuinely new endpoint
│   │                                            #       contract this feature introduces
│   ├── eutr-purchase-attachments-by-sales-ids-raw.md  # NEW (Update 12) - batch raw purchase
│   │                                            #       attachments for many Sales IDs (Progress column)
│   ├── eutr-templates-by-codes.md              # NEW (Update 12) - batch full template details for
│   │                                            #       many Template Codes in one round trip
│   ├── eutr-purchase-attachments-sales-ids-with-template.md  # NEW (Update 16) - the one genuinely
│   │                                            #       new endpoint this update introduces: every
│   │                                            #       distinct Sales ID with a saved Template
│   └── sales-order-overview-reused-endpoints.md  # NEW (Update 12/13) - traceability only; documents
│                                                #       Overview's reuse of list-po-references
│                                                #       (Update 12, batched) and download-zip/
│                                                #       by-sales-id/{salesId}/by-codes (Update 13,
│                                                #       on-demand per row)
│                                                # Update 14: no contract file added/edited — this
│                                                #       update is a pure frontend routing/URL-state
│                                                #       fix with zero backend endpoint involved
│                                                # EDIT (Update 16): documents the existing refType=11
│                                                #       call now receiving a computed whitelist
│                                                #       FilterRequest[] when the search box is empty
│                                                #       (zero contract change to refType=11 itself)
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
                                                       # EDIT (Update 15): import EutrFileViewerDialog
                                                       #       (from @presentation/pages/eutr-documents/
                                                       #       components/, same alias-import path
                                                       #       MapFilePage.jsx already uses); add
                                                       #       viewerFile state ({open, fileId, fileName},
                                                       #       cloned from MapFilePage.jsx's own Update 9
                                                       #       state); add typeName: doc.typeName onto
                                                       #       each realAvailableFiles entry (field
                                                       #       already returned by list-po-references
                                                       #       since Update 5, simply not yet read here -
                                                       #       same class of gap Update 8 fixed for
                                                       #       poCode); add selectedStepId state (null =
                                                       #       no filter); add onSelect prop to ViewNode -
                                                       #       clicking a row (not the collapse arrow)
                                                       #       calls setSelectedStepId(node.id); add
                                                       #       setSelectedStepId(null) to the toolbar
                                                       #       template Chip's existing onClick (fires on
                                                       #       every click, including the
                                                       #       already-selected chip); add one new
                                                       #       availableFilesForPanel useMemo - when
                                                       #       selectedStepId is null, returns
                                                       #       selectedTemplateComputation.filesForTemplate
                                                       #       unfiltered (FR-101); otherwise walks the
                                                       #       clicked node's own subtree (self + all
                                                       #       descendants, via the tree already built by
                                                       #       flatToTree) and returns the de-duplicated
                                                       #       union of selectedTemplateComputation.
                                                       #       derivedFileMappings[id] for every id in
                                                       #       that subtree (FR-102); render a new
                                                       #       AVAILABLE FILES Box (file name + Map
                                                       #       status/File type/PO value/Step name Chips,
                                                       #       cloned visually from MapFilePage.jsx's own
                                                       #       AVAILABLE FILES row, minus Edit/Upload) in
                                                       #       the right sidebar Card, directly below the
                                                       #       existing "Steps missing files" Box; each
                                                       #       row's new View IconButton sets viewerFile
                                                       #       and opens the reused
                                                       #       <EutrFileViewerDialog />

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
  endpoints are modified. **Update 15** imports and renders the same component as-is a second time,
  from `ViewSalesOrderPage.jsx` — still none of these files/endpoints are modified.
- `presentation/pages/eutr-sales-orders/utils/progressUtils.js`'s `buildTemplateComputations` (Update
  12) — **Update 15** is a new consumer of its already-returned `filesForTemplate`/
  `derivedFileMappings` shape (via the already-existing `selectedTemplateComputation`,
  `ViewSalesOrderPage.jsx`, Update 8/12); the util itself is unmodified.
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
- `compliance-master/index.jsx` (and its siblings `compliance-management/index.jsx`,
  `compliance-detail/index.jsx`) — **Update 14** reads their existing `page`/`page-size`
  `useSearchParams` + `{ replace: true }` pattern as a design reference only (research.md Decision
  53); none of these files are imported, called, or modified. Every backend file in this entire
  feature is also unchanged by Update 14 — it is 100% frontend, confined to the 3 files listed above.

```text
# Update 12 (2026-07-27) — Progress column on Overview: 2 new batch read actions (each on an
# already-existing controller, no new controller/service/repository/entity class, no migration):
compliance-sys-api/
└── src/
    ├── ComplianceSys.Application/
    │   ├── Interfaces/Repositories/IEutrPurchaseAttachmentsRepository.cs  # EDIT: + GetBySalesIdsAsync
    │   ├── Interfaces/Services/IEutrPurchaseAttachmentsService.cs         # EDIT: + GetRawBySalesIdsAsync
    │   ├── Interfaces/Repositories/IEutrTemplatesRepository.cs           # EDIT: + GetManyByCodesWithDetailsAsync
    │   └── Interfaces/Services/IEutrTemplatesService.cs                  # EDIT: + GetManyByCodesWithDetailsAsync
    ├── ComplianceSys.Infrastructure/
    │   ├── Repositories/EutrPurchaseAttachmentsRepository.cs  # EDIT: + GetBySalesIdsAsync (clones
    │   │                                                        #       GetBySalesIdAsync's SQL,
    │   │                                                        #       widened to `WHERE SalesId IN
    │   │                                                        #       @SalesIds`, no JOIN, no DISTINCT)
    │   └── Repositories/EutrTemplatesRepository.cs             # EDIT: + GetManyByCodesWithDetailsAsync
    │                                                            #       (clones GetByIdWithDetailsAsync's
    │                                                            #       2-query shape, widened from
    │                                                            #       `Id = @id` to `Code IN @Codes`
    │                                                            #       for the header query, then
    │                                                            #       `TemplateId IN @Ids` for the
    │                                                            #       details query; details grouped
    │                                                            #       back onto each header row by
    │                                                            #       TemplateId)
    ├── ComplianceSys.Application/Services/
    │   ├── EutrPurchaseAttachmentsService.cs   # EDIT: + GetRawBySalesIdsAsync (thin pass-through,
    │   │                                        #       mirrors GetTemplatesBySalesIdsAsync's shape)
    │   └── EutrTemplatesService.cs             # EDIT: + GetManyByCodesWithDetailsAsync (thin
    │                                            #       pass-through, mirrors GetByIdWithDetailsAsync's
    │                                            #       shape)
    └── ComplianceSys.Api/
        └── Controllers/
            ├── EutrPurchaseAttachmentsController.cs  # EDIT: + POST by-sales-ids-raw (policy
            │                                          #       EutrPurchaseAttachments.Read, reused)
            └── EutrTemplatesController.cs             # EDIT: + POST by-codes (policy
                                                         #       EutrTemplates.ReadAll, reused)

compliance-client/
└── src/
    ├── presentation/pages/eutr-sales-orders/utils/
    │   └── progressUtils.js   # NEW (Update 12) - AUTO_SOURCES + computeProgress(), moved verbatim
    │                            #       from MapFilePage.jsx; + new buildTemplateComputations(),
    │                            #       generalized from MapFilePage.jsx (Update 7)/
    │                            #       ViewSalesOrderPage.jsx's (Update 8) own duplicated
    │                            #       templateComputations bodies (research.md Decision 42)
    ├── domain/interfaces/IEutrPurchaseAttachmentsRepository.js   # EDIT: + getBySalesIdsRaw
    ├── domain/interfaces/IEutrTemplatesRepository.js             # EDIT: + getManyByCodes
    ├── infrastructure/api/eutrPurchaseAttachmentsApi.js           # EDIT: + getBySalesIdsRaw
    ├── infrastructure/api/eutrTemplatesApi.js                     # EDIT: + getManyByCodes
    ├── infrastructure/repositories/RestEutrPurchaseAttachmentsRepository.js  # EDIT: implement getBySalesIdsRaw
    ├── infrastructure/repositories/RestEutrTemplatesRepository.js            # EDIT: implement getManyByCodes
    ├── application/usecases/eutr-purchase-attachments/
    │   └── GetPurchaseAttachmentsBySalesIdsRawUseCase.js   # NEW (Update 12)
    ├── application/usecases/eutr-templates/
    │   └── GetEutrTemplatesByCodesUseCase.js               # NEW (Update 12) - reused as-is by Update 13
    └── presentation/pages/eutr-sales-orders/
        ├── MapFilePage.jsx        # EDIT (Update 12): remove local AUTO_SOURCES/computeProgress/inline
        │                           #       templateComputations body; import all three from the new
        │                           #       utils/progressUtils.js instead (behavior-preserving refactor,
        │                           #       research.md Decision 42)
        │                           # EDIT (Update 14): add `useLocation` import; replace the Back
        │                           #       button's inline `onClick={() => navigate('/eutr/sales-
        │                           #       orders')}` (line 900) with a new `handleBack` — calls
        │                           #       `navigate(-1)` when `location.state?.fromOverview` is
        │                           #       true, else falls back to the existing
        │                           #       `navigate('/eutr/sales-orders')` (research.md Decision 54)
        ├── ViewSalesOrderPage.jsx  # EDIT (Update 12): same refactor as MapFilePage.jsx above — import
        │                           #       AUTO_SOURCES/computeProgress/buildTemplateComputations from
        │                           #       the shared util instead of this file's own Update 8 clone
        │                           # EDIT (Update 14): add `useLocation` import; replace the Back
        │                           #       button's inline `onClick={() => navigate('/eutr/sales-
        │                           #       orders')}` (line 816) with the same `handleBack` pattern
        │                           #       as MapFilePage.jsx above (research.md Decision 54)
        └── SalesOrderOverviewPage.jsx  # EDIT (Update 12): remove DEMO_PROGRESS; add
                                         #       fetchProgressForRows(items) (parallel to the existing
                                         #       fetchTemplatesForRows) calling getBySalesIdsRaw →
                                         #       {getManyByCodes, getPoReferences} in parallel → per-row
                                         #       buildTemplateComputations + computeProgress (shared
                                         #       util), keyed by salesId into state as one of 4
                                         #       discriminated states (empty/no-required/ok/error,
                                         #       research.md Decision 47); render the Progress cell from
                                         #       that state instead of the removed DEMO_PROGRESS constant
                                         # EDIT (Update 13): wire the existing Download IconButton's
                                         #       onClick to a new handleDownload(salesId) — on-demand,
                                         #       per row: GetPurchaseAttachmentsBySalesIdUseCase (existing,
                                         #       singular) → GetEutrTemplatesByCodesUseCase (Update 12,
                                         #       reused) + GetEutrDocumentsPoReferencesUseCase (existing,
                                         #       reused) in parallel → buildTemplateComputations (shared
                                         #       util) → folders payload → DownloadEutrSalesOrderZipUseCase
                                         #       (existing, unchanged); add downloadingSalesIds (Set)
                                         #       state for per-row spinner/in-flight tracking (research.md
                                         #       Decision 51); empty-Mapped-files/error handling scoped to
                                         #       the clicked row only (research.md Decision 52)
                                         # EDIT (Update 14): add `useSearchParams` import; read initial
                                         #       `search`/`page`/`page-size` from the URL on mount
                                         #       instead of hardcoded `''`/`0`/`DEFAULT_PAGE_SIZE`; sync
                                         #       state → URL via `setSearchParams(..., { replace: true
                                         #       })` inside the existing debounced search callback and
                                         #       the existing page/page-size change handlers; pass
                                         #       `{ state: { fromOverview: true } }` as the 2nd arg on
                                         #       the two existing Map File/View `navigate()` calls
                                         #       (lines 569/591) (research.md Decisions 53-54)
```

Unchanged (verified reusable as-is, no edits needed) for Update 12/13:
- `EutrPurchaseAttachmentsController`'s existing `by-sales-ids`/`by-sales-id/{salesId}`/
  `save-po-mapping` actions, and `EutrTemplatesController`'s existing `get-all`/`GetById` actions — the
  two new batch actions are additive siblings, not replacements.
- `POST /api/eutr-documents/list-po-references` (owned by `004-eutr-documents`) — reused unchanged by
  Update 12 with a larger `PoCodes` array; confirmed already SalesId-agnostic (research.md Decision 45).
- `POST /api/eutr-documents/download-zip`, `DownloadEutrSalesOrderZipUseCase.js`,
  `GetPurchaseAttachmentsBySalesIdUseCase.js`, `GetEutrDocumentsPoReferencesUseCase.js` — all reused
  unchanged by Update 13's per-row on-demand pipeline.
- `presentation/pages/eutr-sales-orders/utils/treeUtils.js` — untouched; `progressUtils.js` (Update 12)
  is a new sibling file in the same `utils/` folder, not an edit to this one.

```text
# Update 16 (2026-07-28) — Overview's default row set scoped to Sales IDs with Template: 1 new read
# on the already-existing EutrPurchaseAttachmentsController (no new controller/service/repository/
# entity class, no new DTO, no migration, no new policy):
compliance-sys-api/
└── src/
    ├── ComplianceSys.Application/
    │   ├── Interfaces/Repositories/IEutrPurchaseAttachmentsRepository.cs  # EDIT: + GetSalesIdsWithTemplateAsync
    │   └── Interfaces/Services/IEutrPurchaseAttachmentsService.cs         # EDIT: + GetSalesIdsWithTemplateAsync
    ├── ComplianceSys.Infrastructure/
    │   └── Repositories/EutrPurchaseAttachmentsRepository.cs  # EDIT: + GetSalesIdsWithTemplateAsync
    │                                                            #       (`SELECT DISTINCT SalesId FROM
    │                                                            #       eutr_purchase_attachments WHERE
    │                                                            #       TemplateCode IS NOT NULL;` —
    │                                                            #       clones GetTemplatesBySalesIdsAsync's
    │                                                            #       SELECT DISTINCT shape, no input
    │                                                            #       list, no eutr_templates join)
    ├── ComplianceSys.Application/Services/
    │   └── EutrPurchaseAttachmentsService.cs   # EDIT: + GetSalesIdsWithTemplateAsync (thin pass-through)
    └── ComplianceSys.Api/
        └── Controllers/EutrPurchaseAttachmentsController.cs  # EDIT: + GET sales-ids-with-template
                                                                 #       (policy EutrPurchaseAttachments.
                                                                 #       Read, reused) → returns bare
                                                                 #       List<string>, no new DTO

compliance-client/
└── src/
    ├── domain/interfaces/IEutrPurchaseAttachmentsRepository.js   # EDIT: + getSalesIdsWithTemplate
    ├── infrastructure/api/eutrPurchaseAttachmentsApi.js           # EDIT: + getSalesIdsWithTemplate
    ├── infrastructure/repositories/RestEutrPurchaseAttachmentsRepository.js  # EDIT: implement getSalesIdsWithTemplate
    ├── application/usecases/eutr-purchase-attachments/
    │   └── GetSalesIdsWithTemplateUseCase.js   # NEW (Update 16)
    └── presentation/pages/eutr-sales-orders/
        └── SalesOrderOverviewPage.jsx  # EDIT (Update 16): add `salesIdsWithTemplate` state (string[] |
                                          #       null); when the URL's `search` param (Update 14) is
                                          #       empty on mount, on clearing the search box, or on an
                                          #       empty-keyword Back-navigation restore, call
                                          #       GetSalesIdsWithTemplateUseCase once; if the result is
                                          #       `[]`, skip the GetReferenceDataUseCase (refType=11)
                                          #       call entirely and render the existing "No data" empty
                                          #       state (FR-112); otherwise build
                                          #       `salesIdsWithTemplate.map(id => ({ column: "Code",
                                          #       operator: "eq", value: id }))` and pass it as the
                                          #       existing call's filter argument instead of `[]`; when
                                          #       `search` is non-empty, this whole branch is skipped and
                                          #       the existing FR-011 Code/Name filter construction is
                                          #       used unchanged
```

Unchanged (verified reusable as-is, no edits needed) for Update 16:
- `ComplDynamicsService.cs`, `DynController.cs`, `ODataOperatorConverter.cs` — the existing same-bucket
  OR-join behavior (`BuildFilterString`) this update depends on already exists; zero change of any kind.
- `EutrPurchaseAttachmentsController`'s existing `by-sales-ids`/`by-sales-id/{salesId}`/
  `by-sales-ids-raw`/`save-po-mapping` actions — the new action is an additive sibling, not a
  replacement or a widened variant of any of them.
- `presentation/pages/eutr-sales-orders/utils/progressUtils.js` — untouched; the whitelist this update
  fetches is unrelated to Progress's own `computeProgress`/`buildTemplateComputations`.
- `MapFilePage.jsx`, `ViewSalesOrderPage.jsx` — this update touches only `SalesOrderOverviewPage.jsx`'s
  default row set; neither sibling screen lists multiple Sales Orders, so neither is affected.

```text
# Update 17 (2026-08-11) — Variants/Materials on Step 1: 1 backend dictionary-entry fix (no new
# controller/service/repository/entity/DTO/migration/policy); frontend edits confined to
# MapFilePage.jsx (no new file):
compliance-sys-api/
└── src/
    └── ComplianceSys.Application/
        └── Services/ComplDynamicsService.cs   # EDIT: + one EntityMappings[20] entry —
                                                  #       `{ 20, ("RSVNEutrSalesOrderPurchLines",
                                                  #       "InterCompanyOriginalSalesId", "ProductVariant") },`
                                                  #       Not touched: the entity class, `MapDynamicsResponse`'s
                                                  #       `case 20:`, `MapSortColumn`, `ComplDynReferenceResponseDto`,
                                                  #       `DynController` — all four already exist/compile.

compliance-client/
└── src/
    └── presentation/pages/eutr-sales-orders/
        └── MapFilePage.jsx  # EDIT (Update 17): + `EUTR_SALES_ORDER_PURCH_LINE_REF_TYPE = 20` constant
                              #       (alongside the existing `EUTR_SALES_ORDER_PURCHASE_REF_TYPE = 16`);
                              #       + one new `useEffect` (mirrors the existing refType=16 PO-list
                              #       effect, same `[salesId]` dependency) calling
                              #       `getReferenceDataUseCase.execute(1, 500, 'Code', 'asc', 20,
                              #       [{ column: 'InterCompanyOriginalSalesId', operator: 'eq', value:
                              #       salesId }])`; + `poLinesByPurchId` (Map<purchId,
                              #       {materials, variants}>) / `poLinesLoading` / `poLinesError` state,
                              #       built by grouping the response by `rsvnRefPurchId`, deduping
                              #       `code` (Material)/`productVariant` (Variant) per PO in first-seen
                              #       order (research.md Decision 64); replace the two static
                              #       `<Typography variant="body2">Variants</Typography>` /
                              #       `Materials` placeholders in the Step 1 `TableContainer` (currently
                              #       hardcoded literal text, not data-bound) with
                              #       `(poLinesByPurchId.get(po.purchId)?.variants ?? []).join(', ') ||
                              #       '—'` / the `materials` equivalent, plus a loading/error indicator
                              #       sourced from `poLinesLoading`/`poLinesError`. Step 1's
                              #       tick/checkbox/Save PO Mapping logic (`handleTogglePO`,
                              #       `disabled = !po.eutrTemplate`, `savePoMappingUseCase`) is
                              #       untouched (spec FR-120).
```

Unchanged (verified reusable as-is, no edits needed) for Update 17:
- `DynController.cs`, `ODataOperatorConverter.cs` — no controller/route/operator change of any kind;
  `POST /api/dynamics/reference` already accepts any `refType` as a plain, unrestricted query parameter.
- `ComplDynamicsService.cs`'s `MapDynamicsResponse` `case 20:`, `MapSortColumn`'s
  `RSVNEutrSalesOrderPurchLines` entries, and `ComplDynReferenceResponseDto` — all three already exist
  and already compile correctly; only the `EntityMappings` dictionary gains the one new entry.
- `GetReferenceDataUseCase.js`, `IDynamicsRepository.js`, `RestDynamicsRepository.js`,
  `dynamicsApi.js` — reused unchanged, the same generic, `refType`-parameterized chain the existing
  `refType=16` PO-list call already uses; zero new frontend infrastructure file.
- `SalesOrderOverviewPage.jsx`, `ViewSalesOrderPage.jsx` — this update touches only `MapFilePage.jsx`'s
  Step 1 table; neither sibling screen renders that table.

```text
# Update 18 (2026-08-12) — Variants/Materials on View's Selected Purchase Orders table: 0 backend
# files (reuses Update 17's EntityMappings[20] registration unchanged); frontend edits confined to
# ViewSalesOrderPage.jsx (no new file):
compliance-client/
└── src/
    └── presentation/pages/eutr-sales-orders/
        └── ViewSalesOrderPage.jsx  # EDIT (Update 18): + `EUTR_SALES_ORDER_PURCH_LINE_REF_TYPE = 20`
                                      #       constant (cloned from MapFilePage.jsx's Update 17
                                      #       addition); + one new `useEffect` (same shape as
                                      #       MapFilePage.jsx's — mirrors this screen's own existing
                                      #       refType=16 PO-list effect, same `[salesId]` dependency)
                                      #       calling `getReferenceDataUseCase.execute(1, 500, 'Code',
                                      #       'asc', 20, [{ column: 'InterCompanyOriginalSalesId',
                                      #       operator: 'eq', value: salesId }])`; + `poLinesByPurchId`
                                      #       (Map<purchId, {materials, variants}>) / `poLinesLoading`
                                      #       / `poLinesError` state, grouped by `rsvnRefPurchId`,
                                      #       deduping `code` (Material)/`productVariant` (Variant) per
                                      #       PO in first-seen order — identical logic to
                                      #       MapFilePage.jsx's Update 17 effect, not a rewritten
                                      #       formula; replace the two hardcoded
                                      #       `<Typography variant="body2">Variants</Typography>` /
                                      #       `Materials` cells (currently literal text, not
                                      #       data-bound) in the Selected Purchase Orders
                                      #       `TableContainer` with
                                      #       `(poLinesByPurchId.get(po.purchId)?.variants ?? []).join(', ') ||
                                      #       '—'` / the `materials` equivalent, plus a loading/error
                                      #       indicator sourced from `poLinesLoading`/`poLinesError`.
                                      #       Read-only guarantee (FR-042), Edit/Map File, Download,
                                      #       Back, Template Checklist, Validation Summary, and
                                      #       AVAILABLE FILES are untouched (spec FR-128).
```

Unchanged (verified reusable as-is, no edits needed) for Update 18:
- `ComplDynamicsService.cs`, `DynController.cs`, `ODataOperatorConverter.cs` — `EntityMappings[20]`
  (Update 17) already makes `refType=20` reachable for any caller; zero backend change of any kind.
- `GetReferenceDataUseCase.js`, `IDynamicsRepository.js`, `RestDynamicsRepository.js`,
  `dynamicsApi.js` — reused unchanged, the same generic, `refType`-parameterized chain
  `ViewSalesOrderPage.jsx`'s own existing `refType=16` PO-list call already uses.
- `MapFilePage.jsx` — this update only clones its Update 17 logic into `ViewSalesOrderPage.jsx`; Map
  File's own Step 1 table is not touched.
- `SalesOrderOverviewPage.jsx` — this update touches only `ViewSalesOrderPage.jsx`'s Selected Purchase
  Orders table; Overview renders no such table.

```text
# Update 19 (2026-08-12) — Real logic for View's All toolbar chip: 0 backend files (reuses
# GetPagingEutrTemplatesUseCase/GetEutrTemplatesUseCase unchanged); frontend edits confined to
# ViewSalesOrderPage.jsx + one new function in the already-existing utils/treeUtils.js (no new file):
compliance-client/
└── src/
    └── presentation/pages/eutr-sales-orders/
        ├── ViewSalesOrderPage.jsx  # EDIT (Update 19): + `defaultTemplate`/`defaultTemplateLoading`/
        │                             #       `defaultTemplateError` state, fetched on All-chip click via
        │                             #       the same `getPagingEutrTemplatesUseCase.execute(1, 1,
        │                             #       'Code', 'asc', [{ column: 'IsDefault', operator: 'eq',
        │                             #       value: 1 }])` → `getEutrTemplatesUseCase.execute(id)` shape
        │                             #       already used per real template chip since Update 4, filter
        │                             #       value only; + one new `useMemo` building the All tree via
        │                             #       `filterFlatListByStepIds` (below) + the existing
        │                             #       `flatToTree`; + one new `useMemo` unioning every template's
        │                             #       `filesForTemplate` (from `templateComputations`, Update
        │                             #       7/8/12) for AVAILABLE FILES when `selectedTemplateCode ===
        │                             #       null`; + one new `useMemo` computing per-`stepId`
        │                             #       "has document" across every saved template
        │                             #       (`derivedFileMappings`, OR'd across `templateComputations`);
        │                             #       the Template Checklist/AVAILABLE FILES render branches
        │                             #       extended with an All-active case. Read-only guarantee
        │                             #       (FR-042), FR-060's page-load default, header/Validation
        │                             #       Summary aggregate progress (FR-062), and Download are
        │                             #       untouched (spec FR-138/FR-139).
        └── utils/treeUtils.js      # EDIT (Update 19): + `filterFlatListByStepIds(flatList,
                                      #       keepStepIds)` — new pure function, colocated with
                                      #       `flatToTree`/`treeToFlat`/`removeNodeAndDescendants`;
                                      #       filters a flat template-detail list down to items whose
                                      #       `stepId ∈ keepStepIds`, re-pointing any surviving item's
                                      #       `parentId` to its nearest surviving ancestor (or `'0'`) when
                                      #       its original parent was removed, so the existing
                                      #       `flatToTree` still builds a valid tree with no orphaned
                                      #       `parentId` references (spec FR-132/FR-133).
```

Unchanged (verified reusable as-is, no edits needed) for Update 19:
- `EutrTemplatesController.cs`/`Service.cs`/`Repository.cs` — `GetPagedAsync`'s existing `IsDefault`
  filter whitelist and unconditional `IsHide = 0`/`IsDeleted = 0` clauses already satisfy FR-130 with
  zero backend change of any kind.
- `GetPagingEutrTemplatesUseCase.js`, `GetEutrTemplatesUseCase.js`, `IEutrTemplatesRepository.js`,
  `RestEutrTemplatesRepository.js`, `eutrTemplatesApi.js` — reused unchanged, the exact same chain
  every real template chip already calls since Update 4.
- `MapFilePage.jsx` — the All chip and its new logic are scoped to `ViewSalesOrderPage.jsx`'s own
  toolbar; Map File's own toolbar/Step 2 behavior is untouched.
- `SalesOrderOverviewPage.jsx` — this update touches only `ViewSalesOrderPage.jsx`'s Template
  Checklist/AVAILABLE FILES; Overview has no template-tree toolbar.

# Update 21 (2026-08-12) — Download zip gains a nested All folder: 1 existing DTO field reshaped
# (FolderName -> FolderPath) on the already-existing EutrDocumentsController.cs/download-zip action
# (no new controller/service/repository/entity class, no migration, no new policy, no new endpoint);
# frontend edits confined to ViewSalesOrderPage.jsx + SalesOrderOverviewPage.jsx + one new function in
# the already-existing utils/treeUtils.js (no new file):
```
compliance-sys-api/
└── src/
    ├── ComplianceSys.Api/
    │   └── Controllers/EutrDocumentsController.cs   # EDIT (Update 21): DownloadZip's per-folder
    │                                                  #       `folderName` derivation changes from
    │                                                  #       `SanitizeZipNamePart(folder.FolderName,
    │                                                  #       "template")` to `string.Join("/",
    │                                                  #       folder.FolderPath.Select(s =>
    │                                                  #       SanitizeZipNamePart(s, "step")))` — every
    │                                                  #       other line (empty-folder entry, per-file
    │                                                  #       fetch/zip loop, GetUniqueZipEntryName
    │                                                  #       disambiguation, 400/500 responses)
    │                                                  #       unchanged (research.md Decision 69)
    └── ComplianceSys.Application/
        └── Dtos/Request/
            └── EutrDownloadZipFolderDto.cs   # EDIT (Update 21): `FolderName` (string) -> `FolderPath`
                                                #       (List<string>) — ordered path segments from the
                                                #       zip root; EutrDownloadZipRequestDto.cs and
                                                #       EutrDownloadZipFileDto.cs unchanged

compliance-client/
└── src/
    └── presentation/pages/eutr-sales-orders/
        ├── ViewSalesOrderPage.jsx      # EDIT (Update 21): `buildDownloadFolders` changes each
        │                                 #       per-template entry from `{ folderName: t.templateName,
        │                                 #       files }` to `{ folderPath: [t.templateName], files }`
        │                                 #       (1-element array, same value), and appends the result
        │                                 #       of the new `flattenTreeToFolderEntries(allChipTree,
        │                                 #       allChipDerivedFileMappings, filesById, ['All'])` call
        │                                 #       (`filesById` a new small `useMemo`, `Map` built from
        │                                 #       the already-existing `allChipFiles`, Update 19) —
        │                                 #       falling back to a single `{ folderPath: ['All'],
        │                                 #       files: [] }` entry when that call returns empty
        │                                 #       (FR-147); no new fetch — `allChipTree`/
        │                                 #       `allChipDerivedFileMappings`/`allChipFiles` are already
        │                                 #       populated by Update 20's mount-time
        │                                 #       `loadDefaultTemplate` effect by the time Download is
        │                                 #       clickable
        ├── SalesOrderOverviewPage.jsx  # EDIT (Update 21): per-row Download handler's inline `folders`
        │                                 #       builder changes each per-template entry the same way
        │                                 #       (`folderName` -> `folderPath: [t.templateName]`); adds
        │                                 #       one new on-demand call (same 2-call `IsDefault`-filtered
        │                                 #       chain as `ViewSalesOrderPage.jsx`'s
        │                                 #       `loadDefaultTemplate`, Update 19) to the existing
        │                                 #       `Promise.all` (Update 13), wrapped in its own
        │                                 #       `.catch(() => null)` so a failure of only this call
        │                                 #       degrades to the FR-147 empty-All fallback rather than
        │                                 #       failing the row's Download as a whole; builds the same
        │                                 #       All entries via `flattenTreeToFolderEntries` +
        │                                 #       `filterFlatListByStepIds`/`flatToTree` (all reused,
        │                                 #       Update 19) as plain local variables inside the handler
        │                                 #       (this page has no Template Checklist/`useMemo` chain to
        │                                 #       host them in)
        └── utils/treeUtils.js          # EDIT (Update 21): + `flattenTreeToFolderEntries(tree,
                                          #       derivedFileMappings, filesById, parentPath)` — new pure
                                          #       function, colocated with `flatToTree`/
                                          #       `filterFlatListByStepIds`; walks a tree, emitting one
                                          #       `{ folderPath: [...parentPath, node.stepName], files }`
                                          #       entry per node (files resolved from
                                          #       `derivedFileMappings[node.id]` against `filesById`),
                                          #       recursing into `node.children` with the extended path
                                          #       (spec FR-142..FR-146)
```

Unchanged (verified reusable as-is, no edits needed) for Update 21:
- `EutrDownloadZipRequestDto.cs`, `EutrDownloadZipFileDto.cs` — only `EutrDownloadZipFolderDto.cs`'s
  single field is reshaped; the request envelope and per-file shape are untouched.
- `DownloadEutrSalesOrderZipUseCase.js`, `eutrDocumentsApi.js`'s `downloadZip`,
  `IEutrDocumentsRepository.js`, `RestEutrDocumentsRepository.js` — all forward the `folders` payload
  opaquely (blob download, HTTP POST body, interface passthrough); none reference `folderName`/
  `folderPath` by name, so none need editing.
- `flatToTree`, `filterFlatListByStepIds` (Update 19) — reused unchanged as inputs to the new
  `flattenTreeToFolderEntries`; no change to how the All tree itself is built/filtered.
- `MapFilePage.jsx` — has no Download button; untouched.
- `ComplianceDownloadService`/`AllCompliancesController` — the unrelated feature this endpoint's
  mechanics were originally cloned from (Update 10, Decision 36); not touched by this update.

## Complexity Tracking

*No entries — Constitution Check passed without violations.*
