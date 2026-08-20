# Feature Specification: All Compliances Sales-Line Fallback for Missing BOM

**Feature Branch**: `015-compl-all-compliances-view-all`

**Created**: 2026-08-19

**Status**: Draft

**Input**: User description: "cập nhật compl-all-compliances chức năng [HttpPost("get-all")] trong ViewCompliancesService phía dưới dòng
salesLineOpenMaterials = await _dynamicsDataService.GetSalesLineOpenMaterialFromDynamics(so.ReferenceValue);
khi salesLineOpenMaterials không có dữ liệu, do API ở GetSalesLineOpenMaterialFromDynamics không có data (chưa tạo BOM) thì vào [HttpGet("sales-line")] (t2) lấy dữ liệu theo điều kiện filter = "SalesId eq 'so'" sau đó map vào salesLineOpenMaterials (t1) với t1.InterSalesId = 'cog' + t2.salesId, t1.ProductCode = t2.ItemId, các cột giống tên thì tự map vào, riêng 2 cột ProductType, ProductRange thì lấy ở [HttpGet("product-variant-info")] theo ProductCode eq t2.ItemId and ConfigId eq t2.ConfigId"

**Update (2026-08-19)**: "dữ liệu sales order SO007370 đã hiển thị, tab Sales order compliance detail chưa hiển thị, xem có liên quan logic trên không? có thì cập nhật lại để hiển thị dữ liệu" — the "Sales order compliance detail" tab (`compliance-view-so`, tab 2) is built from a second, separate method, `ViewCompliancesService.TransformSoAsync` (behind `GET transform-so/{salesId}`), which also calls `GetSalesLineOpenMaterialFromDynamics` directly and returned an empty result under the same "no BOM yet" condition — it was intentionally left out of the original scope (see the Assumptions note below, now superseded). This update extends the same fallback to that method: when its BOM-based lookup is empty, it now reuses the same `BuildSalesLineOpenMaterialFallbackAsync` fallback (same fallback source, same field mapping, no new logic) so the detail tab also shows data for a sales order with no BOM yet, consistent with the main compliance list.

**Update (2026-08-19, GetAndSaveSummarySo)**: "trong ViewCompliancesService hàm GetAndSaveSummarySo cũng bị vấn đề salesLineOpenMaterials không có dữ liệu, add logic trên vào" — `ViewCompliancesService.GetAndSaveSummarySo` delegates to `ViewCompliancesSummaryService.GetAndSaveSummarySo` (the Hangfire job `daily_update_count_all_compliances`, which recomputes and persists each sales order's compliance counts to `ComplSummarySo`). It has the identical gap: its own `GetSalesLineOpenMaterialFromDynamics` call, per sales order in its loop, returned nothing for a no-BOM sales order, so that sales order's saved summary counts were all zero instead of reflecting its actual compliance status. This update wires in the same fallback there too (FR-011). Two further call sites with the same pattern were found and flagged to the user — confirmed in the next update.

**Update (2026-08-19, Download & Alert flows)**: user confirmed applying the same fallback to both remaining call sites found above: `ViewCompliancesDownloadService.GetViewCompliancesForDownloadAsync` (the sales-order file-download/zip flow, behind the existing `GetViewCompliancesForDownloadAsync` endpoint) and `ViewCompliancesAlertService.GetViewCompliancesForSendAlertAsync` (the missing-compliance alert flow feeding `GetViewCompliancesForSendAlertAsync`). Both had the identical `GetSalesLineOpenMaterialFromDynamics`-with-no-fallback gap; both now use the same fallback (FR-012). This closes out every user-reachable/scheduled-job consumer of the BOM-based sales-line lookup except the diagnostic-only `ViewCompliancesService.Test` method (no known consumer).

**Update (2026-08-20, BomStatus saved on the summary)**: "trong ViewCompliancesSummaryService có lưu dữ liệu vào bảng compl_summary_so, giờ thêm cột string BomStatus. nếu salesLineOpenMaterials không có giá trị phải áp dụng logic mới, thì note là No BOM" — the saved compliance summary (`compl_summary_so`, written by `ViewCompliancesSummaryService.GetAndSaveSummarySo`, User Story 3) gains a new saved field, BOM status, recording whether that sales order's summary was computed from real BOM data or from the no-BOM fallback introduced above. When the sales order's own BOM-based sales-line lookup (the same check as FR-002/FR-011) returns zero records — i.e., the fallback in FR-002/FR-011 had to be used to compute this summary — the saved BOM status is set to the literal text "No BOM". This makes the fallback's use visible on the saved record itself, not just in its counts.

**Update (2026-08-20, second BomStatus writer found)**: user asked to verify ("kiểm tra") every function carrying the no-BOM fallback logic to confirm all of them that save to `compl_summary_so` also set BOM status. That check found a second, previously-missed writer: `ViewCompliancesService.GetViewCompliancesAsync` (the User Story 1 "get-all" lookup itself, not just the nightly job) also persists to `compl_summary_so` — via a fire-and-forget background job (`ComplSummarySoService.SaveSummarySo`) it enqueues after computing results, so that repeated on-demand lookups don't force the caller to wait for the count recompute. That background save had no BOM status logic at all. User confirmed extending the same BOM status rule there too (FR-016, SC-009, Acceptance Scenario 4 below).

**Update (2026-08-20, BOM column on the All Compliances list screen)**: "cập nhật 015-compl-all-compliances-view-all, màn hình index, hiển thị thêm cột BOM sau cột Invoice date, cột BOM lấy từ BomStatus trong compl_summary_so, theo SalesId = SalesOrder nếu No BOM hiển thị Missing, ngược lại trống" (screen: `compliance-view?ref-type=11&page=1&page-size=50`, the Sale Order All Compliances list) — the saved BOM status from User Story 5 becomes visible directly in this list screen. A new "BOM" column is added immediately after the existing "Invoice date" column, sourced from each listed sales order's saved BOM status (matched by sales order id, the same match this screen already performs to show its other saved summary counts): "Missing" when that value is "No BOM", blank otherwise. See User Story 6, FR-017–FR-020, SC-010.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See compliance results for a sales order that has no BOM yet (Priority: P1)

A Compliance Reviewer opens the All Compliances lookup for a sales order (the "get-all" lookup, keyed by the sales order's reference value) whose lines have not yet had a Bill of Materials (BOM) created for them in Dynamics. Today, because the BOM-based sales-line lookup finds nothing, the reviewer sees no compliance results at all for that sales order, even though the order lines themselves (product, configuration, area, country, status) already exist and could still be checked for compliance. The reviewer wants to see compliance results derived from the order's existing lines in this case, instead of an empty result.

**Why this priority**: This is the entire scope of the requested change. Without it, sales orders without a BOM yet are invisible to compliance checking, which is exactly the gap being closed.

**Independent Test**: Pick a sales order whose BOM-based sales-line lookup currently returns no records but which has one or more order lines in the sales-order-line reference data. Run the All Compliances "get-all" lookup for that sales order. Confirm the response is no longer empty solely because of the missing BOM: it reflects compliance results computed from that sales order's lines (product code, configuration, area, country, status), the same way results would be computed today if BOM data existed for those same fields.

**Acceptance Scenarios**:

1. **Given** a sales order whose BOM-based sales-line lookup returns zero records, and that sales order has one or more lines in the sales-order-line reference data, **When** the All Compliances "get-all" lookup runs for that sales order, **Then** the system retrieves that sales order's lines from the sales-order-line reference data (filtered to that sales order's code) and uses them, mapped into the same shape the BOM-based lookup would have produced, as the basis for the compliance results instead of returning an empty result.
2. **Given** a sales order whose BOM-based sales-line lookup returns one or more records, **When** the All Compliances "get-all" lookup runs for that sales order, **Then** the fallback lookup is not used at all and results are computed exactly as they are today, from the BOM-based records only.
3. **Given** a fallback-derived line for a sales order, **When** it is built from the matching sales-order-line record, **Then** its Sales order code, Configuration id, Area id, Country/region id, and Sales status are copied directly from that sales-order-line record's identically-named fields, its Product code is copied from that record's Item, and its Inter-sales id is the literal text "cog" immediately followed by that record's Sales order code.
4. **Given** a fallback-derived line with a known Product code and Configuration id, **When** the system looks up Product type and Product range for that line, **Then** it retrieves them from the product-variant reference data source by matching both the Product code and the Configuration id together, and fills the fallback-derived line's Product type and Product range with the matched values.
5. **Given** a fallback-derived line whose Product code and Configuration id have no matching record in the product-variant reference data source, **When** the lookup in Scenario 4 runs, **Then** that line's Product type and Product range are left blank, and the line is still included in the results.
6. **Given** a sales order whose BOM-based sales-line lookup returns zero records, and whose sales-order-line reference data also returns zero records for that sales order, **When** the All Compliances "get-all" lookup runs for that sales order, **Then** the system behaves exactly as it does today for a sales order with no data at all (empty compliance results).

---

### User Story 2 - See the same fallback data in the Sales order compliance detail tab (Priority: P1)

A Compliance Reviewer opens the "Sales order compliance detail" tab for a sales order that has no BOM yet. This tab is built from a second, separate lookup (`TransformSoAsync`) that also depends on the BOM-based sales-line data and, before this update, returned nothing whenever that data was missing — even after User Story 1 already made the same sales order's compliance results visible in the main list. The reviewer wants this tab to show the same order-line-derived detail (product, configuration, materials placeholder, attributes) instead of appearing empty.

**Why this priority**: Without this, User Story 1's fix is inconsistent within the same screen — the main tab shows results for a no-BOM sales order while the detail tab right next to it still appears broken, which is confusing and was the actual symptom reported.

**Independent Test**: Open the "Sales order compliance detail" tab (`compliance-view-so?ref-type=11&codes=<sales order with no BOM but with order lines>`). Confirm it now shows the sales order's product/configuration rows (sourced from the same fallback as User Story 1) instead of an empty tab, while a sales order that already has BOM data shows this tab unchanged from today.

**Acceptance Scenarios**:

1. **Given** a sales order whose BOM-based sales-line lookup returns zero records, and that sales order has one or more lines in the sales-order-line reference data, **When** the Sales order compliance detail lookup runs for that sales order, **Then** it uses the same fallback-derived lines as User Story 1 (same source, same field mapping) as the basis for its result, instead of returning an empty result.
2. **Given** a sales order whose BOM-based sales-line lookup returns one or more records, **When** the Sales order compliance detail lookup runs for that sales order, **Then** the fallback is not used and the result is computed exactly as it is today.
3. **Given** a sales order whose BOM-based sales-line lookup returns zero records and whose sales-order-line reference data also returns zero records, **When** the Sales order compliance detail lookup runs for that sales order, **Then** it behaves exactly as it does today for a sales order with no data at all (empty result).

---

### User Story 3 - Correct saved compliance summary counts for a sales order with no BOM yet (Priority: P1)

The daily compliance-summary job (and its on-demand trigger) recomputes and saves each sales order's compliance counts (total/missing/applied/overdue) so other screens can read them without recomputing on every request. For a sales order with no BOM yet, this job's own BOM-based sales-line lookup also returned nothing, so the saved summary was stuck at all-zero counts even though User Story 1/2 show real compliance results for the same sales order elsewhere.

**Why this priority**: A stale, always-zero summary for these sales orders is misleading to anything that reads it (dashboards, counts shown elsewhere) and is the same underlying defect as User Story 1/2, just surfacing in the saved-summary path instead of a live lookup.

**Independent Test**: Trigger the summary job for a sales order that has no BOM yet but has order lines. Confirm the saved summary counts for that sales order now reflect its actual compliance results (matching what User Story 1's "get-all" lookup reports), instead of all zeros.

**Acceptance Scenarios**:

1. **Given** a sales order whose BOM-based sales-line lookup returns zero records, and that sales order has one or more lines in the sales-order-line reference data, **When** the summary job processes that sales order, **Then** it uses the same fallback-derived lines as User Story 1 to compute and save that sales order's summary counts, instead of saving all-zero counts.
2. **Given** a sales order whose BOM-based sales-line lookup returns one or more records, **When** the summary job processes that sales order, **Then** the fallback is not used and its summary is computed exactly as it is today.

---

### User Story 4 - Correct file downloads and missing-compliance alerts for a sales order with no BOM yet (Priority: P2)

Two more flows depend on the same BOM-based sales-line lookup for a single sales order: downloading that sales order's applied compliance files as a zip, and generating the list of currently-missing compliance items to feed a missing-compliance alert. Both had the same gap — for a sales order with no BOM yet, both returned nothing (an empty download, an empty alert list) even when User Story 1 shows the same sales order does have compliance results.

**Why this priority**: Same underlying defect as User Story 1–3, on two further consumers; ranked P2 because these are triggered on-demand/less frequently than the main list and detail tab, not because the impact is smaller once triggered.

**Independent Test**: For a sales order with no BOM yet but with order lines: (a) trigger its file download and confirm it now considers the fallback-derived compliance results instead of returning no files; (b) trigger its missing-compliance alert generation and confirm it now considers the same fallback-derived results instead of returning an empty missing list.

**Acceptance Scenarios**:

1. **Given** a sales order whose BOM-based sales-line lookup returns zero records, and that sales order has one or more lines in the sales-order-line reference data, **When** its compliance file download is requested, **Then** it uses the same fallback-derived lines as User Story 1 to determine applied files, instead of an empty result.
2. **Given** the same setup, **When** its missing-compliance alert list is generated, **Then** it uses the same fallback-derived lines to determine currently-missing items, instead of an empty result.
3. **Given** a sales order whose BOM-based sales-line lookup returns one or more records, **When** either flow runs for that sales order, **Then** the fallback is not used and each flow behaves exactly as it does today.

---

### User Story 5 - Know from the saved summary alone whether a sales order has no BOM yet (Priority: P2)

Someone reading the saved compliance summary for a sales order (for example, from a dashboard or report built on `compl_summary_so`) wants to know, without cross-checking anywhere else, whether that sales order's counts were computed from its real BOM data or from the no-BOM fallback (User Story 3). Today the saved summary's counts look the same either way, so there is no way to tell a "genuinely has zero compliance items" sales order apart from a "has no BOM yet, counts are fallback-derived" sales order just by reading the saved record.

**Why this priority**: This does not change any computed count — it only records, on the already-fixed summary (User Story 3), which computation path produced it. Ranked P2 because it is a visibility/traceability addition on top of an already-correct fix, not a correctness gap on its own.

**Independent Test**: Trigger the summary job for (a) a sales order with no BOM yet but with order lines, and (b) a sales order that already has BOM data. Read both saved summary records afterward. Confirm (a)'s saved record is marked "No BOM" and (b)'s is not.

**Acceptance Scenarios**:

1. **Given** a sales order whose BOM-based sales-line lookup returns zero records for the summary job, **When** the job saves that sales order's summary (whether creating a new saved record or updating an existing one), **Then** the saved record's BOM status is set to the literal text "No BOM".
2. **Given** a sales order whose BOM-based sales-line lookup returns one or more records for the summary job, **When** the job saves that sales order's summary, **Then** the saved record's BOM status is not set to "No BOM" (left blank/unset), consistent with the fallback not being used for that sales order.
3. **Given** a sales order previously saved with BOM status "No BOM" (because it had no BOM at the time), **When** the summary job later reprocesses that same sales order and its BOM-based sales-line lookup now returns records (its BOM has since been created), **Then** the existing saved record's BOM status is updated to no longer read "No BOM".
4. **Given** a sales order whose BOM-based sales-line lookup returns zero records, **When** someone runs the All Compliances "get-all" lookup for that sales order (User Story 1) — which also saves that sales order's summary in the background, independently of the nightly summary job — **Then** that background save also sets the saved record's BOM status to "No BOM", the same as if the nightly job had processed it.

---

### User Story 6 - See BOM status at a glance on the All Compliances list (Priority: P2)

A Compliance Reviewer browsing the All Compliances list for sales orders
(`compliance-view?ref-type=11&page=1&page-size=50`) wants to quickly spot which listed sales orders
are missing a BOM, without opening each one individually. Today the list shows Sales id, Customer
code, Customer name, Sales status, Delivery date, Invoice date, and Status, but nothing about BOM —
a reviewer has to open each sales order's detail to find out.

**Why this priority**: P2 — this is a visibility convenience layered on top of the already-saved BOM
status (User Story 5); it does not change any compliance computation or saved data, only surfaces
existing saved data in the list screen.

**Independent Test**: Open the All Compliances list for Sale Order
(`compliance-view?ref-type=11&page=1&page-size=50`). Confirm a "BOM" column appears immediately after
"Invoice date" and before "Status". For a listed sales order whose saved BOM status is "No BOM",
confirm the column shows "Missing". For a listed sales order with real BOM data (or with no saved
summary yet), confirm the column is blank.

**Acceptance Scenarios**:

1. **Given** the All Compliances list screen for Sale Order, **When** it renders its columns, **Then** a "BOM" column appears immediately after "Invoice date" and before "Status".
2. **Given** a listed sales order whose saved BOM status is "No BOM", **When** the list renders that row, **Then** its BOM column shows "Missing".
3. **Given** a listed sales order whose saved BOM status is not "No BOM" — either blank/unset, or that sales order has no saved summary record at all yet — **When** the list renders that row, **Then** its BOM column is blank.

---

### Edge Cases

- What happens to material-level fields (Material code, Material name, Material type, Cost group id, Product group) on a fallback-derived line? They are left blank, since this data only exists once a BOM has been created for the order line; the fallback intentionally does not fabricate BOM data that does not yet exist.
- What happens when several sales-order-line records for the same sales order share the same Product code and Configuration id? Each still produces its own fallback-derived line; the Product type/Product range lookup for that Product code + Configuration id combination applies consistently to all of them.
- What happens if the BOM-based sales-line lookup fails with an error rather than returning zero records? Out of scope for this change — the fallback is triggered only by a successful lookup that returns no records, not by a failure; existing error handling for that lookup is unchanged.
- What happens to fields that exist on the sales-order-line reference data but have no counterpart on a sales-line-open-material record (for example, customer name/account or the sales responsible/taker workers)? They are not carried over, since the fallback-derived line only populates the fields that exist on a sales-line-open-material record.
- What happens downstream, after fallback-derived lines are produced? They feed into the same compliance-mapping and lookup steps that BOM-based lines normally feed into, unchanged from today's behavior.
- What is saved as BOM status when the sales order has no BOM-based lines and its sales-order-line fallback also returns zero records (Edge Case in User Story 1/3, FR-009)? The summary job still processes it as today (no fallback data available), and since the trigger condition for "No BOM" is the BOM-based lookup returning zero records, the saved BOM status is still set to "No BOM" — the fallback lookup finding nothing further does not change that.
- What happens when the nightly summary job (User Story 3) and the "get-all" lookup's own background save (User Story 1, FR-016) both save the same sales order around the same time, and one sees BOM data while the other does not (e.g. a BOM gets created in the window between the two)? Each writer independently overwrites the saved record's BOM status (and counts) with its own lookup's result — whichever save completes last determines the value left in `compl_summary_so`. This is the same last-write-wins behavior the two writers already had for the other saved fields (counts, emails, etc.) before this update; BOM status is not treated any differently.
- What does the new BOM column show for a sales order listed on the All Compliances screen that has never been saved by either writer yet (no `compl_summary_so` record exists for it at all)? Blank — same as a sales order whose saved BOM status is simply not "No BOM" (User Story 6, Acceptance Scenario 3). The list screen does not trigger either writer or the BOM-based lookup itself; it only reads whatever is already saved.
- Does opening the All Compliances list screen (User Story 6) itself trigger the no-BOM fallback logic (User Stories 1–5) for the listed sales orders? No — the list screen only reads each sales order's already-saved BOM status; it does not call the BOM-based sales-line lookup or the fallback for the sales orders it lists, so listing them causes no new writes to `compl_summary_so`.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: In the All Compliances "get-all" lookup for a sales order, System MUST continue to first retrieve that sales order's lines from the existing BOM-based sales-line-open-material lookup, exactly as it does today.
- **FR-002**: When the BOM-based lookup in FR-001 returns zero records for the sales order, System MUST retrieve that sales order's lines from the sales-order-line reference data source, filtered to that sales order's code, as a fallback.
- **FR-003**: When the BOM-based lookup in FR-001 returns one or more records, System MUST NOT invoke the fallback lookup, and MUST compute results exactly as it does today.
- **FR-004**: For each sales-order-line record retrieved by the fallback in FR-002, System MUST construct a fallback-derived line with: Sales order code, Configuration id, Area id, Country/region id, and Sales status copied directly from that record's identically-named fields; Product code copied from that record's Item; and Inter-sales id set to the literal text "cog" immediately followed by that record's Sales order code.
- **FR-005**: For each fallback-derived line, System MUST look up Product type and Product range from the product-variant reference data source, matched by that line's Product code together with its Configuration id, and populate the fallback-derived line's Product type and Product range with the matched values when a match is found.
- **FR-006**: When no matching product-variant record is found for a fallback-derived line's Product code and Configuration id, System MUST leave that line's Product type and Product range blank and still include the line in the results.
- **FR-007**: For each fallback-derived line, System MUST leave Material code, Material name, Material type, Cost group id, and Product group blank.
- **FR-008**: System MUST feed the fallback-derived lines produced in FR-004–FR-007 into the same downstream compliance-mapping and lookup steps that BOM-based lines are fed into today, without any other change to those steps.
- **FR-009**: When the fallback lookup in FR-002 also returns zero records for the sales order, System MUST leave the sales-line list empty and proceed exactly as today's existing "no data" behavior for that sales order.
- **FR-010**: The Sales order compliance detail lookup (`TransformSoAsync`) MUST apply the same fallback as FR-002–FR-009 (same trigger condition, same source, same field mapping) when its own BOM-based sales-line lookup returns zero records for the sales order, so the detail tab reflects the same fallback-derived lines as the main "get-all" lookup instead of returning an empty result.
- **FR-011**: The compliance-summary job (`GetAndSaveSummarySo`, per sales order in its processing loop) MUST apply the same fallback as FR-002–FR-009 when its own BOM-based sales-line lookup returns zero records for that sales order, so the saved summary counts for that sales order reflect its actual compliance results instead of all-zero counts.
- **FR-012**: The compliance file-download flow (`GetViewCompliancesForDownloadAsync`) and the missing-compliance alert flow (`GetViewCompliancesForSendAlertAsync`) MUST each apply the same fallback as FR-002–FR-009 when their own BOM-based sales-line lookup returns zero records for the sales order, so both reflect the same fallback-derived lines instead of an empty result.
- **FR-013**: The saved compliance summary record (`compl_summary_so`) MUST record a BOM status value that indicates whether that sales order's summary was computed using the no-BOM fallback (FR-002/FR-011).
- **FR-014**: When the compliance-summary job's BOM-based sales-line lookup returns zero records for a sales order (the same condition that triggers the fallback in FR-011), System MUST set that sales order's saved BOM status to the literal text "No BOM", whether the saved record is newly created or an existing one being updated.
- **FR-015**: When the compliance-summary job's BOM-based sales-line lookup returns one or more records for a sales order, System MUST NOT set that sales order's saved BOM status to "No BOM"; an existing saved record previously marked "No BOM" for that sales order MUST be updated so it no longer reads "No BOM" once its BOM-based lookup returns data.
- **FR-016**: The All Compliances "get-all" lookup's own background save of a sales order's summary (triggered from User Story 1's lookup, independent of the nightly compliance-summary job) MUST apply the same BOM status rule as FR-014–FR-015: set to "No BOM" when that same lookup's own BOM-based sales-line lookup returned zero records for the sales order, left unset otherwise.
- **FR-017**: The All Compliances list screen for the Sale Order reference type MUST display a new "BOM" column, positioned immediately after the "Invoice date" column and before the "Status" column.
- **FR-018**: For each sales order row on that list screen, System MUST populate the BOM column from that sales order's saved BOM status, matched by sales order id — the same match this screen already performs against the saved compliance-summary data to populate its other summary-derived columns.
- **FR-019**: When a row's matched BOM status is the literal text "No BOM", System MUST display "Missing" in that row's BOM column.
- **FR-020**: When a row's matched BOM status is not "No BOM" — including when it is blank/unset, or when the sales order has no saved compliance-summary record at all — System MUST display that row's BOM column as blank.

### Key Entities

- **Sales-Line Open Material (t1)**: The existing BOM-derived record that feeds the All Compliances "get-all" lookup for a sales order. Key attributes: Sales order code, Inter-sales id, Product code, Configuration id, Material code, Country/region id, Product type, Material type, Cost group id, Area id, Material name, Product group, Sales status, Product range. This update adds a fallback path that constructs records in this same shape when the normal BOM-based source has none.
- **Sales Order Line (t2, fallback source)**: A sales order's line record sourced from the sales-order-line reference data, filtered by sales order code. Key attributes used by this feature: Sales order code, Item, Configuration id, Area id, Country/region id, Sales status. Other attributes it carries (e.g., customer name/account, sales responsible/taker) are not used by this feature.
- **Product Variant Info (fallback enrichment source)**: Reference data queried by Product code + Configuration id together, used only to supply the Product type and Product range values on fallback-derived lines.
- **Compliance Summary (compl_summary_so)**: The saved per-sales-order compliance summary. Written by two independent paths that both save to the same table: the nightly/on-demand summary job (User Story 3, `GetAndSaveSummarySo`) and a background save triggered every time the "get-all" lookup runs for a sales order (User Story 1, `GetViewCompliancesAsync` → its own background save). This update adds a BOM status attribute to this record, set to "No BOM" by *either* writer when that writer's own BOM-based sales-line lookup returned zero records for the sales order, and left blank/unset otherwise — each writer computes it independently from its own lookup, not from the other writer's saved value. This attribute is also read (not written) by the All Compliances list screen (User Story 6) to populate its new "BOM" column, matched to each listed sales order by sales order id.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For sales orders that have order lines but no BOM created yet, the All Compliances "get-all" lookup returns non-empty, line-derived results instead of an empty result — 0 such sales orders show an empty result solely because their BOM has not been created.
- **SC-002**: For sales orders that already have BOM-based sales-line data, lookup results are unchanged from today's behavior — 0 observable difference in results, and the fallback lookup is never invoked, when the BOM-based lookup already returns data.
- **SC-003**: Every fallback-derived line's Sales order code, Product code, Configuration id, Area id, Country/region id, and Sales status match their source sales-order-line record field-for-field — 100% match, verified across sampled sales orders exercising the fallback.
- **SC-004**: Every fallback-derived line whose Product code + Configuration id has a matching product-variant record shows the matched Product type and Product range — 0 such lines left blank when a match exists.
- **SC-005**: For a sales order with no BOM yet but with order lines, the "Sales order compliance detail" tab shows fallback-derived rows consistent with the main "get-all" results for the same sales order — 0 such sales orders where the main list shows data but the detail tab remains empty.
- **SC-006**: For a sales order with no BOM yet but with order lines, its saved compliance summary (total/missing/applied/overdue) after the summary job runs reflects its actual fallback-derived compliance results — 0 such sales orders left with a stale all-zero saved summary.
- **SC-007**: For a sales order with no BOM yet but with order lines, both the file-download flow and the missing-compliance alert flow reflect its fallback-derived compliance results — 0 such sales orders left with an empty download or an empty alert list solely because of the missing BOM.
- **SC-008**: For every sales order processed by the compliance-summary job, its saved BOM status correctly identifies whether the fallback was used — 100% agreement between "saved BOM status reads No BOM" and "that sales order's BOM-based sales-line lookup returned zero records", verified across sampled runs including a sales order whose BOM was created between two job runs.
- **SC-009**: For every sales order whose summary is saved via the "get-all" lookup's own background save (User Story 1), its saved BOM status correctly reflects that lookup's own BOM-based sales-line result — 0 such sales orders left with an incorrect or stale BOM status solely because they were only ever touched through this path and not the nightly job.
- **SC-010**: On the All Compliances list screen for Sale Order, a reviewer can identify which listed sales orders are missing a BOM without opening any of them individually — 100% of listed rows whose saved BOM status is "No BOM" show "Missing" in the BOM column, and 0 rows show "Missing" when their saved BOM status is not "No BOM", verified across a sampled page of results.

## Assumptions

- The literal Inter-sales id prefix is the fixed string "cog" (lowercase, no separator character), concatenated directly in front of the sales order code exactly as given in the request (e.g., sales order `SO58611` → `cogSO58611`).
- "No data" that triggers the fallback means the BOM-based lookup completes successfully and returns a zero-length list, matching its current empty-result behavior; a thrown error/exception from that lookup is a separate, out-of-scope case and keeps its existing handling.
- This change originally scoped the fallback to only the All Compliances "get-all" lookup's sales-order branch in `ViewCompliancesService` (the call quoted in the request); four further 2026-08-19 updates extended the same fallback to every other consumer with the identical gap once each was found: `TransformSoAsync` (User Story 2, the "Sales order compliance detail" tab), `ViewCompliancesSummaryService.GetAndSaveSummarySo` (User Story 3, the compliance-summary job), and `ViewCompliancesDownloadService`/`ViewCompliancesAlertService` (User Story 4, file download and missing-compliance alert) — the last two were found proactively while fixing User Story 3 and confirmed explicitly by the user before being changed.
- `ViewCompliancesService.Test` (a diagnostic-only method, not reachable from any UI or scheduled job) is the one remaining caller of `GetSalesLineOpenMaterialFromDynamics` left unchanged: it has no known consumer, so there's no symptom to fix.
- Leaving Material code, Material name, Material type, Cost group id, and Product group blank on fallback-derived lines is intentional and correct, since that data only exists once a BOM has been created; the fallback does not attempt to substitute or infer BOM-level detail from any other source.
- Product type and Product range lookups against the product-variant reference data source may be resolved per distinct Product code + Configuration id combination (reused across fallback-derived lines that share the same combination) consistent with how other reference-data lookups already behave in this area; no specific batching or caching behavior was requested beyond correct matching.
- Fields present on the sales-order-line reference data but absent from the sales-line-open-material shape (e.g., customer name/account, sales responsible/taker) are simply not carried over — there is no equivalent field to map them into.
- The BOM status value is only specified for the no-BOM case ("No BOM"); when the sales order does have BOM-based sales-line data, no specific value was requested, so the saved BOM status is left blank/unset (not given an alternate label like "Has BOM") — it exists solely to flag the fallback case.
- The BOM status trigger condition is the same one already used for the fallback itself (the sales order's BOM-based sales-line lookup returning zero records), not a separate check — so a sales order that hits the "no BOM and no order lines either" edge case (FR-009) is still marked "No BOM", since its BOM-based lookup still returned zero records.
- Because the summary job re-evaluates and re-saves every sales order's summary each time it runs (either creating or updating the existing saved record), the saved BOM status is expected to self-correct on the next run after a sales order's BOM is created — no separate reconciliation step is needed.
- `compl_summary_so` has exactly two writers, both now covered: `ViewCompliancesSummaryService.GetAndSaveSummarySo` (User Story 3) and `ViewCompliancesService.GetViewCompliancesAsync`'s background save via `ComplSummarySoService.SaveSummarySo` (User Story 1, FR-016). This was confirmed by checking every function in this feature that carries the no-BOM fallback logic for whether it also persists to `compl_summary_so` — `TransformSoAsync`, `GetViewCompliancesForDownloadAsync`, and `GetViewCompliancesForSendAlertAsync` do not persist anything, so they need no BOM status logic.
- The BOM column (User Story 6) is scoped to the Sale Order reference type (`ref-type=11`) list only — the All Compliances list screen supports other reference types (e.g. Customer, Product type), but BOM status is only ever saved per sales order, so those other reference types have no equivalent value to show and are out of scope for this column.
- The BOM column only ever reads the already-saved BOM status; it never triggers the BOM-based sales-line lookup or the fallback itself for the sales orders it lists (Edge Cases). A sales order can therefore show blank in this column even though it genuinely has no BOM, until one of the two writers (User Story 3 or User Story 1) has processed it at least once — this is the same "not yet saved" gap the rest of this screen's saved-summary columns (total/missing/applied/overdue) already have today, and this feature does not change that.
- "Missing" is the literal display text requested for the "No BOM" case; no other saved BOM status value maps to any display text other than blank, since none was requested.
