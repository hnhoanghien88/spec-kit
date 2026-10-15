# Research: EUTR Purchase Orders

## Decision 1 — Purchase Order source data: reuse `refType = 15` unchanged

**Decision**: Read Purch id, Vendor code, and Template directly from the existing
`POST /api/dynamics/reference` endpoint with `refType = 15`, no new endpoint.

**Rationale**: `ComplDynamicsService.EntityMappings[15]` already maps to `RSVNEutrPurchOrders`
(`compliance-sys-api/src/ComplianceSys.Application/Services/ComplDynamicsService.cs:43`), and its
`MapDynamicsResponse` `case 15` (same file, ~line 434) already projects `Id`/`Code` (= `PurchId`),
`Name`, **`EutrTemplate`**, and **`OrderAccount`** — the last two were added additively by
`011-eutr-synchronize-data` for its own Purchase-Order missing-documentation report, which already
uses this exact `refType` and already names its columns "Purch id / Vendor code / Vendor name /
Template" (`specs/011-eutr-synchronize-data/spec.md` Key Entities). This feature's list and detail
screens are simply a second, interactive consumer of the same fields.

**Alternatives considered**: A new dedicated backend DTO/endpoint — rejected, `EutrTemplate`/
`OrderAccount` are already exposed and Constitution Principle III requires reusing existing backend
surface over regenerating it.

## Decision 2 — Vendor name: secondary lookup via `refType = 14`, batched per page

**Decision**: `RSVNEutrPurchOrders` (refType=15) has no Vendor-name field. For each page of PO rows,
collect the distinct `OrderAccount` values present, call `POST /api/dynamics/reference` with
`refType = 14` (`VendorsV3`, already mapped: `Id`/`Code` = `VendorAccountNumber`, `Name` =
`VendorOrganizationName`) filtered by those codes in one batched call, and map the result back onto
each row by `OrderAccount`. Missing/unmatched vendor codes render Vendor name blank (spec FR-003,
matching `011-eutr-synchronize-data`'s own "blank where missing" edge case for the same fields).

**Rationale**: `011-eutr-synchronize-data` already resolves Vendor name the same way (refType=14
keyed by `OrderAccount`) for its own report — reusing the identical approach avoids inventing a new
resolution rule for the same two fields.

**Alternatives considered**: Extending `refType=15`'s backend mapping to embed Vendor name directly
(e.g. a SQL join inside `RSVNEutrPurchOrders`'s D365 view) — rejected as a much larger, unverified
ERP-side change; the batched client-side lookup achieves the same result using only already-shipped
endpoints, at the cost of one extra network call per page (acceptable — same page-batched shape as
Decision 4 below).

## Decision 3 — Template step tree: reuse `POST /api/eutr-templates/by-codes`, one Template per PO

**Decision**: For the list screen's Progress column, collect the distinct `EutrTemplate` codes
present on the current page and call the existing `POST /api/eutr-templates/by-codes` (added by
`005-eutr-sales-orders` Update 12, `EutrTemplatesController.cs:70`) once per page to get each
template's full step tree (`RequirementType`, `TakeFrom`, etc.). For the detail screen, the same
endpoint is called for the one Purchase Order's own `EutrTemplate` value (or `GET
/api/eutr-templates/{id}` if code-to-id resolution is simpler in context — both already exist).

**Rationale**: Unlike `005-eutr-sales-orders`, where a Sales Order can have several Purchase
Orders/Templates and the Template value must be joined through the local `eutr_purchase_attachments`
table, `RSVNEutrPurchOrders.EutrTemplate` already carries the Template directly on the Purchase
Order row itself — no local join table is needed to know "which Template applies to this PO." This
removes the entire Step-1/Save-PO-Mapping/Selected-POs concept `005`'s Map File needed, matching the
spec's explicit removal of those parts.

**Alternatives considered**: Reusing `eutr_purchase_attachments` (as `005` does) — rejected; that
table is keyed by `(SalesId, PurchId)` and exists to link a Sales Order to its PO(s)/Template(s), a
relationship this feature has no Sales Order context for and does not need.

## Decision 4 — Document/step-completion data: reuse `POST /api/eutr-documents/list-po-references`

**Decision**: Reuse `004-eutr-documents`'s existing `list-po-references` endpoint
(`EutrDocumentsController.cs:147`) unchanged — for the list screen, called once per page with the
page's union of Purch ids (same no-N+1 batching rule `005` Update 12/17 already established for its
own equivalent calls); for the detail screen, called with the single Purch id in the URL.

**Rationale**: This endpoint already returns, per document, the PO code and the `StepId`(s) it is
mapped to — exactly what's needed to determine, per template step, whether at least one document
exists for this Purchase Order. Zero backend change.

## Decision 5 — Progress computation: reuse `computeProgress()` from `eutr-sales-orders/utils/progressUtils.js`

**Decision**: Import `computeProgress` (and, where convenient, `normalizeTemplateDetail`) directly
from `compliance-client/src/presentation/pages/eutr-sales-orders/utils/progressUtils.js` rather than
re-implementing step/document matching. Call it with the single Template's `details` and this PO's
own file mappings — this feature never needs `buildTemplateComputations`'s multi-template
aggregation (that exists specifically for `005`'s one-Sales-Order-many-Templates case), only the
lower-level single-template `computeProgress` primitive.

**Rationale**: `005` Update 12 already extracted this util specifically to stop the Required-step/
`AUTO_SOURCES`-exclusion formula from silently drifting between independent consumers (Update 11 had
to fix exactly that kind of drift). Cloning the formula by hand a third time would reintroduce the
same risk Update 12 was written to prevent — importing the existing function keeps this feature
byte-for-byte consistent with `005`'s Map File/View screens.

**Alternatives considered**: Duplicating the formula inside the new `eutr-purchase-orders/` folder —
rejected per the rationale above; a straight cross-feature import is already an established pattern
in this codebase (`MapFilePage.jsx` itself imports `EutrDocumentsFormDialog`/`EutrFileViewerDialog`
from `004-eutr-documents`).

## Decision 6 — Search by Vendor code needs one small additive backend change

**Decision**: `ComplDynamicsService.BuildFilterString` (`ComplDynamicsService.cs:144`) currently
special-cases only two reserved OR-joined buckets, `code` (→ the entity's `CodeColumn`) and `name`
(→ `NameColumn`); any other filter column falls into an `other` bucket whose entries are AND-joined,
not OR-joined, with the code/name search group. Since Vendor code is `OrderAccount` — an *additive*
field on `refType=15`, not its `CodeColumn` (`PurchId`) — there is currently no way to OR a single
free-text keyword across Purch id **and** Vendor code in one call. Vendor name is one lookup further
removed (Decision 2) and is out of scope for server-side OR-filtering in this pass — search matches
Purch id or Vendor code; Vendor name search would additionally require pre-resolving matching Vendor
codes via `refType=14` before filtering `refType=15`, deferred as unnecessary complexity for a first
version (spec's Assumptions cover reasonable defaults; this is documented here as the resolved scope,
not a spec gap).

**Fix**: Add one more reserved bucket to `BuildFilterString`'s existing `GroupBy` switch, scoped to
`refType=15` (`RSVNEutrPurchOrders`) only — e.g. matching on `"ordaccount"`/`"vendorcode"` →
`"vendorcode"` group → column `OrderAccount` — folded into the same OR-joined `searchFilters` list
the `code`/`name` groups already build, so a single keyword search produces
`(PurchId like X or Name like X or OrderAccount like X)`. This is additive only: no other `refType`
is affected (the new bucket only ever resolves a column name for `RSVNEutrPurchOrders`), no
signature change to `GetDynRefePagedAsync`, no new endpoint/DTO/migration.

**Alternatives considered**: (a) Client-side filtering after fetching a large page — rejected, the
ERP source is 3,000+ rows (per `011-eutr-synchronize-data`) and server-side paging must stay
authoritative; (b) A brand-new endpoint dedicated to this feature — rejected, duplicates
`GetDynRefePagedAsync`'s paging/sorting/caching machinery for no reason when one filter-builder
branch suffices.

## Decision 7 — Reference feature to clone: `005-eutr-sales-orders`, not `document-type`

**Decision**: Model `PurchaseOrderOverviewPage.jsx` on `SalesOrderOverviewPage.jsx` (search/
pagination/page-scoped batching shape) and `PurchaseOrderViewPage.jsx` on `MapFilePage.jsx`'s Step 2
only (template tree + AVAILABLE FILES + Upload/Edit), per the spec's own explicit instruction to
mirror the Map File screen minus Step 1/Selected POs.

**Rationale**: Constitution Principle II names `document-type` as "the canonical reference," but its
own stated purpose is reuse of "an existing, working feature of **the same shape**." `005` is the
same shape (ERP-reference-data-driven list + Template + Document step-completion), `document-type`
is a plain local CRUD entity with no analogous concept — `005` itself already deviated from
`document-type` for the same reason (cloning `004-eutr-documents`'s dialogs instead), establishing
this as accepted precedent in this codebase, not a new exception.

## Decision 8 — Routing & menu registration follows `005`'s exact shape

**Decision**: Register the Overview screen as a new top-level menu code (`eutr-purchase-orders`,
url `/eutr/purchase-orders`) via `RouteResolver.jsx`'s `codeToComponent` map + a static
`menu-items/ComplianceSystem.jsx` entry (sibling to `eutr-sales-orders`'s own entry). Register the
detail screen as a static **nested** route in `MainRoutes.jsx`
(`/eutr/purchase-orders/:purchId/view`), mirroring the existing
`/eutr/sales-orders/:salesId/map-file` and `/eutr/sales-orders/:salesId/view` entries — reached by
row-level navigation (the View button), not a menu code, exactly like `MapFilePage`/
`ViewSalesOrderPage` today.

**Operational follow-up (not a code task)**: per this repo's established convention (routing is
driven by the backend `userMenu`/`canAccessMenu` data, not the static menu file — confirmed for
`001-eutr-steps` and unchanged since), the screen will not actually be reachable until an operator
also inserts the corresponding `userMenu` row and grants `canAccessMenu('eutr-purchase-orders')` to
the relevant role(s) in the database. This must be called out at implementation handoff so it is not
mistaken for a missed code change.

## Decision 9 — Upload default Type/Value (spec Update 1, FR-024/FR-025/FR-026): new optional props, not a shared-default change

**Decision**: Add two optional props to `EutrDocumentsFormDialog.jsx` — `addDefaultTypeName` (a
string, e.g. `"PO"`) and `addDefaultChips` (an array of chip objects) — consumed only inside the
`mode="add"` branch of its existing `useEffect(..., [open])` init effect: after `referenceTypes`
loads, if `addDefaultTypeName` is set, find the matching entry by name (same
case-insensitive-trim comparison `isPoTypeName` already uses) and `setType` to it instead of `null`;
if `addDefaultChips` is set, `setChips` to it instead of `[]`. `PurchaseOrderViewPage.jsx`'s Upload
dialog passes `addDefaultTypeName="PO"` and `addDefaultChips={po ? [po] : []}`, reusing the `po`
state object it already fetches for the page header (Decision 1's `refType=15` item — same
`{Id, Code, Name, ...}` shape `EutrAddValueAutocomplete`'s own PO suggestions use, per data-model.md
§1, so it slots into `chips` without transformation). Both props are left undefined by
`MapFilePage.jsx`'s call site, so its dialog keeps resetting to `type=null`/`chips=[]` exactly as
before — zero behavior change for `005`.

**Rationale**: The requested default only applies to one call site (`PurchId/View`'s Upload button).
Changing `EutrDocumentsFormDialog`'s own unconditional reset-to-empty logic (or its default prop
values) would silently alter `MapFilePage.jsx`'s dialog too, reversing `005-eutr-sales-orders`
Research Decision 26 ("full, unrestricted popup — no Type/Step/Value auto-lock") without that spec
asking for it. Threading the defaults through caller-supplied, opt-in props keeps the shared
component's default behavior untouched and makes the one differing call site self-documenting.
Reusing the already-loaded `po` object (rather than issuing a second `refType=15` lookup keyed by
the URL's `purchId`) avoids a redundant network call — the existence-check fetch (FR-013/FR-014)
already retrieves the exact record needed.

**Alternatives considered**: (a) Changing `EutrDocumentsFormDialog`'s own defaults so *every* `mode=
"add"` caller defaults Type to `"PO"` — rejected, this would regress `005`'s explicit "no auto-lock"
decision for the Map File screen, which was not asked to change. (b) A dedicated, PurchaseOrderView-
only fork of the dialog — rejected, duplicates the entire Add/Edit form for a two-field default,
against Constitution Principle II/III's reuse-over-duplication guidance. (c) Fetching a fresh
`refType=15` record specifically for the prefill instead of reusing `po` state — rejected as an
unnecessary extra network call when the exact same data is already in memory.

## Decision 10 — Re-fill Value on every Type change (spec Update 2, FR-027/FR-028/FR-029): replace the static `addDefaultChips` prop with a per-Type resolver function

**Decision**: Replace `EutrDocumentsFormDialog`'s `addDefaultChips` prop (Decision 9, a static array
used only at popup-open time) with a new optional function prop, `resolveAddDefaultChips(typeName)`,
called from **two** places instead of one: (a) inside the existing `mode="add"` init effect, once the
default Type (`addDefaultTypeName`) is applied, using `resolveAddDefaultChips(addDefaultTypeName)`;
and (b) inside the existing `handleTypeChange` handler, on every subsequent Type change, using
`resolveAddDefaultChips(newType?.name)` in place of the current unconditional `setChips([])`. When the
resolver returns a non-empty array, those become the new chips (overwriting whatever was there,
per spec Update 2's explicit "ghi đè" decision); when it returns `[]`/`undefined`/is not supplied, the
existing reset-to-empty behavior is preserved exactly — so `MapFilePage.jsx` (which passes no
resolver) is byte-for-byte unaffected, same as Decision 9.

`PurchaseOrderViewPage.jsx` supplies the resolver as a small pure function closing over the page's
already-loaded `po` (refType=15 item — `code`/`name` used directly as the PO/Invoice/Delivery note
chip, same shape as Decision 9) and a new `{ code: po.orderAccount, name: vendorName }` object built
from state the page already fetches for its header (`po.orderAccount`, and `vendorName` — the string
already resolved by the existing Vendor-name-lookup effect, FR-003/FR-015) for the Vendor chip:

```text
resolveAddDefaultChips(typeName):
  normalized = typeName.trim().toLowerCase()
  if normalized in {"po", "invoice", "delivery note"}: return po ? [po] : []
  if normalized == "vendor": return po?.orderAccount ? [{ code: po.orderAccount, name: vendorName }] : []
  else: return []   # any other Type (e.g. "General agreement") — no auto-fill, matches FR-028
```

**Rationale**: A single resolver function (keyed by Type name, called from both the initial-open path
and the change-handler path) is simpler than two separate mechanisms and guarantees the initial fill
(Update 1) and the reactive re-fill (Update 2) can never drift apart — both always resolve the same
way for the same Type name. Building the Vendor chip from state already on the page (no extra fetch)
follows the same no-redundant-network-call reasoning as Decision 9; `vendorName` is already fetched
by the existing FR-003/FR-015 effect regardless of whether the Upload dialog is open.

**Alternatives considered**: (a) Keep `addDefaultChips` as-is and add a second, separate prop just for
the per-Type map (e.g. `defaultChipsByTypeName`) — rejected as redundant: both the initial fill and
the reactive re-fill need the exact same Type→chips mapping, so one resolver function serves both
call sites and removes the risk of the two lists disagreeing. (b) Compute the Vendor chip via a fresh
`refType=14` lookup at the moment Type is changed to "Vendor" instead of reusing `vendorName` state —
rejected, `vendorName` is already resolved and kept in sync with `po` by the existing effect, so a
second lookup would be a redundant network call for data already in memory. (c) Hardcode the four
Type names (`PO`, `Vendor`, `Invoice`, `Delivery note`) as a shared constant imported from
`EutrAddValueAutocomplete.jsx`'s existing `PO_LIKE_TYPE_NAMES`/`VENDOR_TYPE_NAME` sets — considered,
but rejected to avoid coupling `PurchaseOrderViewPage.jsx` to that component's internal (non-exported)
constants; the resolver duplicates just the three literal strings needed, which is simpler than
exporting new internals from a component whose props contract is otherwise closed.

## Decision 11 — Hide Upload/Edit without permission (spec Update 4/Update 5, FR-030..FR-036): gate on `permissionList` of menu `eutr-documents`, not a live backend probe

**Problem**: `PurchaseOrderViewPage.jsx` needs to know whether the current user holds
`EutrDocuments.Create` (gates Upload) and `EutrDocuments.Update` (gates Edit) — the exact policies
already guarding `POST /api/eutr-documents`/`PUT /api/eutr-documents/{id}`.

**What was tried first, and why it was wrong**: The original Decision 11 (Update 4) reasoned that the
frontend "currently only has menu-level access data" (`permissionList` keyed by menu code) and that
action-level policies like `EutrDocuments.Create` were a separate domain unreachable without asking the
backend live — so it added a narrowly-scoped probe endpoint:

```csharp
[HttpGet("can-create")]
[Authorize(Policy = "EutrDocuments.Create")]
public IActionResult CanCreate() => Ok(ApiResponse<bool>.Ok(true));
```

`PurchaseOrderViewPage.jsx` called this once on mount and rendered Upload only on `200`. Update 5 first
extended this with a mirror `can-update` for Edit. The person requesting the feature tested this live
(`/eutr/purchase-orders/PO00000059/view`, revoking both permissions for a test role) and reported both
buttons still visible — a browser DevTools capture of
`GET .../menu-managements/permissions?appCode=ComplApi&email=...`'s response showed the menu record for
`eutr-documents` (id 242) already carries a `permissionList` array (in that capture:
`['Download', 'ReadAll', 'ReadOne', 'ViewMenu']`, missing `'Create'`/`'Update'` for the test role) — the
exact same shape `005-eutr-sales-orders` Update 28 already reads for menu `eutr-sales-orders`. This
directly falsified the original premise: `'Create'`/`'Update'` **are** valid `permissionList` entries
for `eutr-documents`, they just weren't granted to the test role.

**Decision (corrected)**: `PurchaseOrderViewPage.jsx` reads `permissionList` for menu code
`'eutr-documents'` via the exact `getMenuDataFromStorage()` mechanism Update 28 already established,
and derives `canUploadDocuments = permissionList.includes('Create')` /
`canEditDocuments = permissionList.includes('Update')` as plain `useMemo`-derived `const`s — no state,
no effect, no network call. Both `can-create` and `can-update` were deleted (no remaining callers
anywhere in the codebase, confirmed by grep) per the requester's explicit choice, consistent with this
repo's no-dead-code convention.

**Rationale**: `permissionList` is simpler (no new endpoint, no network round trip, no loading-state
window where the button is wrongly hidden/shown before the probe resolves) and confirmed correct by
direct observation. It also matches the one proven-working pattern already used for every other
menu-gated action in this codebase, rather than a second, parallel gating mechanism for one specific
document-action pair.

**Alternatives considered** (superseded, kept for context — these were the original Update 4 analysis
before the `permissionList` finding):
(a) A generic, cross-feature "check any policy by name" endpoint — rejected as unnecessarily broad.
(b) Extending the external AuthZ microservice's `menu/permissions` response to also carry resource-
action grants — moot once it was confirmed the response *already* carries `'Create'`/`'Update'` in
`permissionList` for this menu.
(c) Inferring "no permission" purely from a `403` on the real write endpoint (let the user click and
fail) — still rejected: the button must not be shown/clickable at all when the user lacks permission.
(d) A new dedicated permission resource just for the Purchase Order screen — still rejected, same
reasoning as before (reuse the real capability, don't invent a parallel one).
(e) *Keep both mechanisms (permissionList for instant UI gating, live probe as a secondary
confirmation)* — rejected: redundant network round trip for no additional correctness once
`permissionList` is confirmed to reflect the same underlying data; the requester explicitly asked to
remove the now-unused probe code.

## Update 10 — Explicit Search button reuses the `005-eutr-sales-orders` pattern verbatim; no URL sync, no debounce cancellation

- **Decision**: Copy `SalesOrderOverviewPage.jsx`'s `handleSearchClick` shape (reset page to 0, call
  the existing fetch function directly with the current `search` value) but WITHOUT the URL
  `searchParams` sync that version also does, and WITHOUT cancelling the pending debounced call.
- **Rationale**: URL sync exists on the Sales Orders screen to support a Back-button restore feature
  (spec Update 14 there) that `012-eutr-purchase-orders`'s Overview never had — building that
  infrastructure here would be new scope the request never asked for. Not cancelling the debounce
  matches the Sales Orders screen's own accepted behavior (its `handleSearchClick` doesn't call
  `debouncedFetch.cancel()` either) — a harmless possible duplicate fetch (same search value either
  way), not a new inconsistency introduced by this change.
- **Alternatives considered**: Add `debouncedFetch.cancel()` to `handleSearchClick` to avoid the
  possible duplicate call — considered but not applied, since it would make this screen's behavior
  diverge from the established `005-eutr-sales-orders` reference pattern for a cosmetic-only benefit
  (no incorrect data results either way).

## Update 12 — Remove AVAILABLE FILES pagination

- **Decision 1**: Render all files in one scrollable list; drop `filePage` state entirely. Rationale: data is already fully loaded client-side, pagination only sliced it; the container already scrolls. Alternatives: virtualization (rejected — overkill for tens/hundreds of rows); "show more" button (rejected — user asked to remove paging).
- **Decision 2**: Footer shows "N files" (count after tree-node filter). Alternative: remove footer (rejected — losing the count is a regression).
- **Decision 3**: Step-filter change no longer needs to reset the page; remove any `setFilePage(1)` calls.

## Update 13 — Assign template to Purchase Order (D365 `updateEutr`)

- **Decision 1**: "Active" templates = `IsDeleted=0 AND IsHide=0 AND Status=1 (PublicD365/Approved)`, via existing `GetEligibleForDynamicsSyncAsync`. Rationale: identical to the set already pushed to D365 `RSVNEutrTemplates`, so every selectable template is guaranteed to exist on D365. Alternative: reuse `eutr-templates/get-all` + Status filter — rejected (requires `EutrTemplates.ReadAll`, a different permission than the button's `Update` right; also returns paging/DTO overhead).
- **Decision 2**: New dedicated controller/service instead of extending `EutrSynchronizeDataService`. Rationale: that service is sync-specific; the new call is a single-record write with its own policy.
- **Decision 3**: Server re-validates templateId/versionId against the active set before calling D365. Rationale: stale popup (template re-versioned/hidden) must not push an obsolete pair.
- **Decision 4**: `templateId` = `Code`, `versionId` = `VersionId` as strings (spec Assumptions). Body field names `purchId`, `templateId`, `versionId` per the user's D365 contract (use a named class, not anonymous type, for `PostAsync<T>` — see note at `EutrSynchronizeDataService` ~line 628).
- **Decision 5**: Success refreshes the list from D365 rather than patching local row state — guarantees Template/Progress show what D365 actually holds.

## Update 15 — Assign template ghi lịch sử `eutr_history` (FR-049)

- **Decision 1**: Ghi lịch sử trong `EutrPurchaseOrdersService.AssignTemplateAsync` NGAY SAU `_dynamicService.PostAsync` thành công (nếu D365 ném lỗi thì không tới bước ghi → thỏa "thất bại không ghi"). Rationale: đây là điểm duy nhất biết chắc D365 đã nhận.
- **Decision 2**: Việc ghi bọc try/catch + log; lỗi DB không ném ra ngoài (D365 đã cập nhật, không thể rollback). Alternative: ghi trước rồi gọi D365 — loại vì tạo dòng lịch sử cho thao tác chưa xảy ra.
- **Decision 3**: Dòng ghi: Type=0, Value=PurchId, RefValue=TemplateId (Code), Version=int.Parse(VersionId) (VersionId đã được validate nằm trong tập active nên là số; nếu parse lỗi thì Version=null), CreatedBy=userEmail, CreatedDate=DateTime.UtcNow cắt còn 50 ký tự cho CreatedBy. Note=null.
- **Decision 4**: `AssignTemplateAsync` nhận thêm `userEmail` (controller lấy từ `HttpContext.Items["UserEmail"]`, mặc định "system" — giống `SavePoMapping`).
- **Decision 5**: Bảng/entity/migration dùng chung với 005 Update 51: Entity `EutrHistory` ([Table("eutr_history")], `long Id`, KHÔNG kế thừa `BaseEntity` vì bảng không có UpdatedBy/UpdatedDate — cùng kiểu `ComplMasterDefaultLog`), ghi qua `IRepository<EutrHistory, long>` generic (đã đăng ký open-generic ở `Infrastructure/DependencyInjection.cs`), không cần repository riêng. Migration: `Sqls/Migration/37_create_eutr_history.sql` (CREATE TABLE IF NOT EXISTS, giống hệt `Sqls/Tables/eutr_history.sql`); cột: `Id` BIGINT AUTO_INCREMENT PK, `Type` TINYINT NOT NULL, `Value` VARCHAR(50) NOT NULL, `RefValue` VARCHAR(50) NOT NULL, `Version` INT NULL, `Note` VARCHAR(50) NULL, `CreatedBy` VARCHAR(50) NOT NULL, `CreatedDate` DATETIME NOT NULL. Index gợi ý `(Type, Value)` để tra theo PO/SalesId.
- **Decision 6 (sửa sau khi chạy thật)**: `DapperRepository.AddAsync` ném "requires an active transaction" nếu gọi ngoài transaction → việc ghi `eutr_history` MUST bọc trong `BeginTransactionAsync`/`CommitAsync` riêng (rollback khi lỗi), sau transaction chính / sau khi D365 thành công.

## Update 53 — Dialog tiến trình khi Download file

- **Decision 3**: Dùng lại `ExportProgressDialog` + `useDownloadProgress` (xem `005-eutr-sales-orders` research Update 57); `TotalFiles = 1`, `0/1 → 1/1`, đóng trong `finally`. Không đổi backend.

## Update 54 — Trích Vendor từ tên file PO

- **Decision 1**: Hook vào `RecomputeForPurchOrderAsync` (không tạo hàm/job riêng) vì đây là hàm tính Progress duy nhất cho PO và đã được gọi từ View/Assign/Upload/đồng bộ 013. Rationale: yêu cầu "mỗi lần chạy kiểm tra". Alternative: job riêng — bị loại, dễ lệch dữ liệu.
- **Decision 2**: Nguồn tên file = `referenceRows` (`GetDocumentsByPoCodesAsync`: `FileName`, `StepName`) đã tải sẵn; chạy bước này ngay cả khi PO không có step Required, và chỉ dùng file khớp `PurchId` (`PoCode == purchId`), không dùng file Type Vendor (RefValue = OrderAccount). Cần tải lại tài liệu nếu nhánh Progress bỏ qua việc tải (total = 0).
- **Decision 3**: Cắt tên Step: bỏ đuôi mở rộng (`Path.GetFileNameWithoutExtension`), bỏ tiền tố bằng `StepName` (so sánh không phân biệt hoa/thường; nếu tên file không bắt đầu bằng StepName thì dùng toàn bộ tên). Phần còn lại tách bằng ký tự không phải chữ/số (`[^\p{L}\p{N}]+`) → token; token khớp `Code` Vendor (OrdinalIgnoreCase) là Vendor. Rationale: chịu được `(AP-PD)`, `(AP PD)`, `(AP,PD)`.
- **Decision 4**: Đồng bộ bằng `SyncAsync`: xóa `WHERE PurchId=@p AND Vendor NOT IN @vendors` (xóa hết theo PurchId nếu rỗng) rồi `INSERT IGNORE` các Vendor; idempotent nhờ UNIQUE (PurchId, Vendor). Lưu `Vendor` theo `Code` chuẩn của 026.
- **Decision 5**: Bọc try/catch riêng, chỉ log; không đổi `UpsertByPurchIdAsync`.

## Update 55 — Trader relationship giữa các Vendor của PO

- **Decision 1**: Bảng mới `eutr_trader_relationship` (PurchId, FromVendor, ToVendor) thay vì thêm cột vào `eutr_purchase_relationship`, vì quan hệ là cạnh có hướng nhiều-nhiều giữa các Vendor. Alternative: cột `ParentVendor` — loại vì không biểu diễn được A→C và B→C cùng lúc.
- **Decision 2**: Save = thay thế toàn bộ theo PurchId (DELETE + INSERT trong 1 transaction, dùng `BeginTransactionAsync`/`CommitAsync` như Update 15 Decision 6). Rationale: popup luôn gửi toàn bộ đồ thị; tránh diff phức tạp.
- **Decision 3**: Validate ở backend (tập Vendor hợp lệ, không tự nối, không trùng, không vòng — Kahn/DFS) và lặp lại ở frontend. Rationale: không tin client.
- **Decision 4**: Frontend dùng `@xyflow/react` (sẵn kéo handle→handle, xóa edge, layout node) thay vì tự vẽ SVG. Alternative: SVG tự viết — loại vì tốn công xử lý kéo/hit-test. Node tự xếp theo lớp topological; không lưu tọa độ.
- **Decision 5**: Dọn mũi tên mồ côi ngay trong `EutrPurchaseRelationshipRepository.SyncAsync` (Update 54) để một nơi duy nhất quyết định Vendor nào còn hiệu lực.
- **Decision 6**: Endpoint đặt dưới controller hiện có: `GET`/`PUT /api/eutr-purchase-orders/{purchId}/trader-relationship`.

## Update 56 — Cột Trader relationship ở index

- **Decision 1**: Endpoint theo lô `POST /api/eutr-purchase-orders/trader-relationships` (giống `eutr-progression/by-purch-ids`) thay vì nhét vào API reference D365 — dữ liệu nằm ở DB cục bộ. Alternative: gọi `GET .../{purchId}/trader-relationship` từng dòng — loại vì N request/trang và trả cả danh sách vendor không cần.
- **Decision 2**: Ghép Name bằng LEFT JOIN `eutr_vendors` hai lần (From/To) trong 1 câu SQL; `COALESCE(NULLIF(Name,''), Code)`. Dựng chuỗi `A > B` ở service.
- **Decision 3**: Policy `EutrPurchaseOrders.Read` (xem danh sách), khác với `.Update` của popup cấu hình.

## Update 58 — Gom nhóm file theo Trader relationship ở PurchId/View

- **Decision 1**: Gom nhóm hoàn toàn ở client (cây đã có `fileMappings` + tên file; dữ liệu relationship nhỏ), không đổi API cây/Progress. Alternative: backend trả cây đã gom — loại vì cây Template dựng ở client.
- **Decision 2**: Nhóm = Vendor hạng thấp nhất có mặt trong tên file (hạng = đường đi dài nhất từ nguồn). Ví dụ `(AP-PD)`→AP, `(PD)`→PD. Rationale: khớp mô tả "AP > ..., DS > ..., còn lại PD". Alternative: nhóm theo từng cặp mũi tên — loại vì tạo nhóm trùng file.
- **Decision 3**: `IsGroup` cấu hình ở `eutr_steps` (001 Update 3), không hardcode tên Step; đi kèm chi tiết Template qua JOIN sẵn có.
- **Decision 4**: Hạ policy GET trader-relationship xuống `.Read` vì màn View cần cho mọi người xem; ghi vẫn `.Update`.

## Update 59 — Tìm theo Vendor name (`eq '*ten*'`)

- **Decision 1**: Thực hiện Vendor name search bằng tra cứu 2 bước ở client (refType=14 `Name like` → `VendorOrganizationName eq '*ten*'`, rồi OR các `OrderAccount` khớp vào refType=15). Đảo lại việc hoãn ở Decision 6. Alternative: join phía backend/D365 — loại vì cần đổi API/entity.
- **Decision 2**: Giới hạn 100 Vendor khớp (page size 100) để bộ lọc OData không quá dài; lỗi tra cứu chỉ log.

## Update 60 — So khớp tên file với tên Step bỏ khoảng trắng + UPPERCASE (kế thừa 004 Update 35)

- **Decision 1**: Chuẩn hoá cả tên file lẫn `eutr_steps.Name` bằng "bỏ mọi ký tự khoảng trắng + đổi HOA" rồi mới `Contains` (ordinal). Backend: `EutrUploadService.NormalizeForStepMatch` (`char.IsWhiteSpace`, `ToUpperInvariant`); client: `loadMatchingStepsForPoByName` (regex khoảng trắng, `toUpperCase`) — hai nơi PHẢI cùng quy tắc để combobox Edit và kết quả Upload không lệch nhau.
- **Decision 2**: Chuẩn hoá chỉ để so sánh; tên file lưu/đặt lại và Step Name hiển thị giữ nguyên (không đổi dữ liệu, không cần migration).
- **Decision 3**: Tie-break FR-081 ("Name dài nhất, bằng nhau lấy Id nhỏ nhất") đo theo độ dài Name sau chuẩn hoá để nhất quán với phép so khớp.
- **Decision 4**: Không bỏ dấu câu/dấu tiếng Việt và không dùng so khớp mờ — chỉ khoảng trắng + hoa/thường theo đúng yêu cầu; Step Name rỗng/chỉ khoảng trắng bị bỏ qua để tránh khớp mọi file.
- **Rejected**: chỉ `Replace(" ", "")` (bỏ sót tab/NBSP); chuẩn hoá ở DB/cột tính sẵn (thừa, không cần đổi schema).
- **Phạm vi**: `progressUtils.js` (`stepNames.includes(detail.stepName)`) giữ nguyên — so khớp Step Name đã lưu trên document, không phải tên file.

## Update 61 — Chuẩn hoá HOA tên file và Code Vendor trước khi tạo relationship sau Upload (kế thừa Update 54/57, cùng tinh thần Update 60)

- **Decision 1**: Chuẩn hoá bằng bỏ toàn bộ khoảng trắng + `ToUpperInvariant` (cùng Update 60) ở cả ba chuỗi: tên file đã bỏ đuôi, tên Step, `Code` Vendor (từ `GetAllCodesAsync`), rồi mới so sánh ordinal. Khoá `codeMap` = Code đã chuẩn hoá, giá trị = Code gốc để ghi vào `eutr_purchase_relationship`/`eutr_trader_relationship` (giữ JOIN `eutr_vendors`).
- **Decision 2**: Bỏ khoảng trắng (thống nhất với Update 60, một hàm chuẩn hoá dùng chung). Dấu tách token là các ký tự không phải chữ/số còn lại (`-`, `(`, `)`…), nên `(AP-PD)` vẫn tách thành `AP`, `PD`. Đánh đổi: Vendor chỉ ngăn cách bằng khoảng trắng (`AP PD`) dính thành `APPD` và không khớp — chấp nhận, yêu cầu tên file dùng `-`.
- **Decision 3**: Cắt tên Step khỏi tên file làm trên chuỗi đã chuẩn hoá bằng bỏ tiền tố (ordinal `StartsWith`), không cần so khớp từng ký tự; phần còn lại giữ ký tự phân cách (không phải khoảng trắng) để tách token.
- **Decision 4**: `ExtractVendors` và `ExtractTraderEdges` dùng chung `BuildCodeMap`/`OrderedVendorsOfFile` nên một thay đổi phủ cả Vendor lẫn mũi tên; dedupe theo giá trị HOA.
- **Rejected**: lưu Code Vendor dạng HOA vào bảng relationship (phải sửa dữ liệu/JOIN `eutr_vendors`, đụng 026); UPDATE `eutr_vendors.Code` sang HOA (đổi dữ liệu nguồn); đổi collation DB (ngoài phạm vi, không kiểm soát được ở tầng service).
- **Phạm vi**: Không đổi `RecomputeForPurchOrderAsync` (công thức Progress), API, DB, client. 013 (đồng bộ dữ liệu) gọi cùng hàm nên được hưởng thay đổi.

## Update 62 — Upload Type "General": chỉ chọn Step, ẩn Value (FR-258)

- **Decision 1**: Nhận diện Type theo Name "General" (`trim` + lower-case) như `isPoTypeName`; không thêm cờ/cột DB.
- **Decision 2**: Vẫn ghi 1 dòng `eutr_references` với `RefValue = NULL` (thay vì không ghi dòng nào) vì Step của document chỉ lưu ở `eutr_references.StepId` — không ghi sẽ mất liên kết Step.
- **Decision 3**: Step lấy từ Assign Steps (`eutr_reference_type_details`) — cơ chế `loadFilteredSteps` sẵn có (FR-043) nên không đổi.
- **Decision 4**: Controller `eutr-upload-multi-by-type` bỏ ràng buộc "RefValues ≥ 1" chỉ cho "General"; Type khác vẫn trả 400.
- **Rejected**: gán RefValue giả (`"GENERAL"`) — sinh dòng rác khi JOIN theo PO/Vendor và `RecomputeForPurchIdAsync`; tạo luồng Upload riêng — trùng lặp với `UploadMultipleForReferenceTypeAsync`.
- **Phạm vi**: client `EutrDocumentsFormDialog.jsx` (`isGeneralTypeName`, `showValue`, `canSubmit`); backend `SharePointController`, `EutrUploadService`; không đổi schema.
- **Decision 5 (Update 62)**: Document General (`RefValue = NULL`) dùng chung mọi PO — nhân bản trong `GetDocumentsByPoCodesAsync` để mọi consumer (list-po-references, Progress, đồng bộ) nhận cùng dữ liệu, thay vì sửa từng nơi. Đánh đổi: bản nhân bản khớp cả PurchId và Vendor code nên client khử trùng theo id.
- **Decision 6 (Update 62)**: Khớp theo Type chỉ siết cho file General (General ↔ Step General); file Type khác giữ khớp theo tên để không đổi hành vi cũ.
- **Decision 7 (Update 62)**: Nhãn TakeFrom lấy từ `eutr_reference_types` qua `TakeFromName` vì TakeFrom là FK; bảng hằng số `TAKE_FROM_LABELS` chỉ còn là fallback.
- **Decision 8 (Update 62)**: Progress backend mã hoá Step General bằng tiền tố khoá thay vì đổi kiểu danh sách Step sang tuple (ít sửa ở 3 điểm so khớp).
- **Rejected**: gán RefValue = PurchId cho General (không còn "dùng chung"); enqueue Recompute mọi PO khi upload General (tốn kém).
