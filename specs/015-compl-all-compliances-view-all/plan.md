# Implementation Plan: All Compliances Sales-Line Fallback for Missing BOM

**Branch**: `015-compl-all-compliances-view-all` | **Date**: 2026-08-19 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/015-compl-all-compliances-view-all/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

When `ViewCompliancesService.GetViewCompliancesAsync`'s sales-order branch (backing
`[HttpPost("get-all")]`) gets zero rows back from the BOM-based sales-line lookup
(`GetSalesLineOpenMaterialFromDynamics`) — because no BOM has been created yet for that sales
order — it currently returns an empty compliance result even though the order's lines already
exist elsewhere in Dynamics. This plan adds a fallback: when that lookup is empty, fetch the sales
order's lines from the `RSVNSalesLineOpenInvoiceCogs` entity (`sales-line`), map them into the same
`RSVNSalesLineOpenMaterialRvns` shape the BOM-based lookup produces (`InterSalesId = "cog" + SalesId`,
`ProductCode = ItemId`, same-named fields copied directly), enrich `ProductType`/`ProductRange` via
a `RSVNProductVariantAlls` (`product-variant-info`) lookup keyed on `ProductCode` + `ConfigId`, and
feed the result into the exact same downstream code the BOM-based path already uses. No HTTP
contract or frontend changes are involved — this is a backend-only extension of existing
Application-layer services.

**Update (2026-08-20, User Story 5)**: `ViewCompliancesSummaryService.GetAndSaveSummarySo` — one of
the two call sites that persist to `compl_summary_so` — now also records, on each saved row, whether
that sales order's summary was computed via the fallback above. This adds one nullable column,
`BomStatus`, to `compl_summary_so` (via a new hand-written SQL migration, this codebase's only
schema-change mechanism — see research.md R7) and a matching property on the `ComplSummarySo`
entity, set to the literal `"No BOM"` when the BOM-based lookup was empty for that sales order, and
left `null` otherwise, on both the insert and update-existing paths.

**Update (2026-08-20, second writer found — FR-016)**: verifying every fallback-carrying function
for whether it also persists to `compl_summary_so` (user request: "kiểm tra... có lưu bảng
compl_summary_so thì đều add logic cập nhật BomStatus vào") surfaced a second, independent writer:
`ViewCompliancesService.GetViewCompliancesAsync` (the "get-all" lookup itself, User Story 1) enqueues
a Hangfire background job calling `ComplSummarySoService.SaveSummarySo`, which does its own separate
insert/update into `compl_summary_so` — distinct from `GetAndSaveSummarySo`'s — and had no `BomStatus`
logic. `IComplSummarySoService.SaveSummarySo` gained an optional `string? bomStatus = null` parameter;
`GetViewCompliancesAsync` computes it the same way as `GetAndSaveSummarySo` (from its own primary
BOM-based lookup, before the fallback runs) and passes it through the background-job enqueue call.
`TransformSoAsync`, `GetViewCompliancesForDownloadAsync`, and `GetViewCompliancesForSendAlertAsync`
were confirmed to not persist to `compl_summary_so` at all, so they need no such change.

**Update (2026-08-20, User Story 6 — BOM column on the list screen)**: the saved `BomStatus`
(User Story 5) becomes visible on the All Compliances Sale Order list screen
(`compliance-view?ref-type=11&page=1&page-size=50`, routed to `compliance-view/index_new.jsx`), as a
new "BOM" column between "Invoice date" and "Status". This is the first frontend-visible change in
this feature (User Stories 1–5 were backend-only). Backend: `RSVNSalesOrderOpenInvoiceCogs` (the DTO
`Get365` returns for this screen) gains a `BomStatus` property, and `ViewCompliancesController.Get365`'s
existing per-row enrichment loop (already copying `TotalCompliances`/`TotalMissing`/etc. from
`compl_summary_so` onto each row) copies `BomStatus` the same way. Frontend:
`useAllCompliancesColumnsSaleOrder.jsx` (the column-definition hook `useAllCompliancesColumnsByType`
selects for `ref-type=11`) gains one new `GridColDef` reading `row.bomStatus` (camelCase — this
codebase's API already serializes PascalCase C# properties to camelCase JSON, confirmed by every
sibling field on this same row shape), displaying `"Missing"` when it equals `"No BOM"`, blank
otherwise.

## Technical Context

**Language/Version**: C# / .NET 8 (ASP.NET Core Web API) — `compliance-sys-api`.

**Primary Dependencies**: Existing `IDynamicService` / `DynamicsParameterManager` / `Helper.ParseDynamicsResponse`
(Dynamics 365 F&O OData proxy) and `ICacheHelper` (existing cache abstraction) — the same
dependencies `DynamicsDataService` already uses for every sibling entity fetch. No new package.

**Storage**: For the sales-line fallback itself (User Stories 1–4): N/A — data is read live from
Dynamics 365 F&O via OData (`RSVNSalesLineOpenInvoiceCogs`, `RSVNProductVariantAlls`), optionally
cached through the existing `ICacheHelper`, same as every other `DynamicsDataService` method.
**Update (2026-08-20, User Story 5)**: the persisted MySQL table `compl_summary_so` (Dapper-accessed,
no EF Core) gains one new nullable `VARCHAR` column, `BomStatus`, applied through this codebase's
existing hand-written-migration convention (`Sqls/Migration/NN_*.sql`, `ALTER TABLE ... ADD COLUMN`)
— see research.md R7. No other table changes.

**Testing**: xUnit + Moq, matching `ComplianceSysApi.UnitTests/Services/ViewCompliances/DynamicsDataServiceTests.cs`
and `ViewCompliancesTransformServiceTests.cs` conventions (mock `IDynamicService`/`ICacheHelper` or
`IDynamicsDataService`, assert on the built OData filter and the mapped output). No existing test
file covers `ViewCompliancesSummaryService` (confirmed absent under
`tests/ComplianceSysApi.UnitTests/`); User Story 5's `BomStatus`-setting logic there has no existing
test scaffold to extend and is validated per quickstart.md's manual DB-query steps instead, consistent
with how User Story 3's original wiring into this same method was handled (tasks.md T013).
`ComplSummarySoService.SaveSummarySo` also has no existing test file for the same reason.

**Target Platform**: Existing ASP.NET Core Web API service (`ComplianceSys.Api`) — same deployment
target as today, no new platform. **Update (2026-08-20, User Story 6)**: also the existing React
frontend (`compliance-client`), same deployment target, no new platform there either.

**Project Type**: Backend-only extension to a single existing web-service project for User Stories
1–5; no frontend project or new project is created there. **Update (2026-08-20, User Story 6)**:
User Story 6 adds a small, existing-screen frontend change in `compliance-client` (one new grid
column) alongside a small backend DTO/controller change — still no new project.

**Performance Goals**: No new explicit target. The fallback must add zero extra Dynamics calls or
latency to the (majority) case where BOM data already exists — FR-003 requires the fallback to be
skipped entirely whenever the primary lookup returns data.

**Constraints**: Must not change the `[HttpPost("get-all")]` request/response contract (see
[contracts/sales-line-fallback.md](contracts/sales-line-fallback.md)); must not change behavior for
sales orders that already have BOM data (SC-002); must reuse the existing Dynamics OData client and
caching abstractions rather than introducing a new external client (Constitution Principle III).

**Scale/Scope**: One new fallback branch inside `ViewCompliancesService.GetViewCompliancesAsync`'s
existing sales-order case, two new data-fetch methods on `IDynamicsDataService`/`DynamicsDataService`,
one new composition method on `IViewCompliancesTransformService`/`ViewCompliancesTransformService`,
reused unchanged at four further call sites (User Stories 2–4). No new controller routes; the two
Dynamics Domain models involved (`RSVNSalesLineOpenInvoiceCogs`, `RSVNProductVariantAlls`) already
exist and need no changes. **Update (2026-08-20)**: one new persisted field (`ComplSummarySo.BomStatus`),
one new migration file, and edits to both writers of `compl_summary_so` —
`ViewCompliancesSummaryService.GetAndSaveSummarySo` and (found via verification, FR-016)
`ComplSummarySoService.SaveSummarySo` / its caller `ViewCompliancesService.GetViewCompliancesAsync` —
to set it. One interface signature gained an optional parameter (`IComplSummarySoService.SaveSummarySo`).
**Update (2026-08-20, User Story 6)**: one new property on the `Get365` response DTO
(`RSVNSalesOrderOpenInvoiceCogs.BomStatus`), one line added to `Get365`'s existing enrichment loop,
and one new column in one existing frontend column-definition file. No new controller route, no new
frontend page/component, no new DTO type.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Layered Clean Architecture** — PASS. New fetch methods stay in `DynamicsDataService`
  (Application layer, one entity per method, no business rules); the new field-mapping/composition
  method stays in `ViewCompliancesTransformService` (Application layer, already responsible for
  composing multiple Dynamics entities into one shape); `ViewCompliancesController` is untouched
  (still thin). No Infrastructure/Dapper layer involvement — this is pure Dynamics OData read
  composition, same as the code it extends. **Update (2026-08-20)**: the `BomStatus` write happens
  inside `ViewCompliancesSummaryService` and (found via verification, FR-016) `ComplSummarySoService`
  — both Application layer, both already existing owners of the `compl_summary_so` write path via
  `IComplSummarySoService`/`ComplSummarySo`; the schema change itself is a SQL migration file under
  `ComplianceSys.Infrastructure/Sqls/Migration/`, matching this codebase's existing layer for schema
  artifacts — still PASS.
- **II. Reference-Pattern Reuse** — PASS. `GetSalesLineOpenInvoiceCogsFromDynamics` clones
  `GetSalesLineOpenMaterialFromDynamics`'s structure; `GetRSVNProductVariantAllsByProductConfigFromDynamics`
  clones `GetRSVNProductVariantMaterialsFromDynamics`'s OR-of-ANDs filter pattern (see research.md
  R2–R3). No invented shape. **Update (2026-08-20)**: the new migration file clones the exact
  `ALTER TABLE ... ADD COLUMN` + Vietnamese-comment-header shape of every prior single-column
  migration in that folder (research.md R7) — still PASS.
- **III. Reuse Existing Backend** — PASS. This is explicitly a verified gap in existing backend
  behavior (empty result when BOM is missing) — the fix reuses the existing Dynamics OData client,
  cache abstraction, and transform-service composition role rather than introducing new
  infrastructure. No existing working endpoint, DTO, or entity is regenerated or duplicated.
  **Update (2026-08-20)**: `BomStatus` is set through the existing `ComplSummarySo` entity, via
  `ComplSummarySoService.AddAsync`/`UpdateAsync` (`IComplSummarySoService`, already injected into
  `ViewCompliancesSummaryService`) and via `ComplSummarySoService.SaveSummarySo` itself (already
  the existing method `GetViewCompliancesAsync`'s background job calls) — no new repository, service,
  or migration mechanism is introduced; the one new column is additive only; the one interface change
  (`SaveSummarySo`'s new optional parameter) is additive/non-breaking to its one existing caller —
  still PASS.
- **IV. Vietnamese Comments; Localizable UI Labels** — PASS (comments only). New code comments
  follow the existing Vietnamese-comment convention in this file (e.g. the "Lấy sale line..." style
  already present), and the new migration file's header comment follows the same Vietnamese
  convention as its siblings (research.md R7). No UI labels are involved — this feature has no
  frontend surface.
- **V. Routing & Menu Registration** — N/A. No new frontend screen or route; the existing
  `[HttpPost("get-all")]` route and its existing consumers are unchanged. `compl_summary_so` has no
  direct CRUD screen/route of its own being added by this feature. **Update (2026-08-20, User Story
  6)**: still N/A — the `compliance-view` route already exists and is unchanged; confirmed via
  `RouteResolver.jsx` that it renders `compliance-view/index_new.jsx` (not the sibling, unrouted
  `index.jsx` in the same folder — a naming trap worth flagging so the column change lands in the
  file that's actually live), which already calls the column hook this feature modifies.

Additional note for User Story 6 (frontend, Principle I/IV): this is not a new CRUD feature, so
Principle I's domain/infrastructure/application/presentation split for *new* frontend features does
not apply — it is a one-column addition to an existing, already-built list screen's existing
column-definition hook (Principle II: mirrors the existing `salesStatus`/`invoiceDate` column
patterns in the same file). This screen's UI labels ("Sales id", "Invoice date", "Status", "Missing"
in its tooltip) are already English today, pre-dating this feature — the new "BOM"/"Missing" column
follows that screen's existing (not newly introduced) language, not a fresh Principle IV deviation.

No violations — Complexity Tracking is not needed.

## Project Structure

### Documentation (this feature)

```text
specs/015-compl-all-compliances-view-all/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md         # Phase 1 output (/speckit-plan command)
├── quickstart.md         # Phase 1 output (/speckit-plan command)
├── contracts/
│   └── sales-line-fallback.md
└── tasks.md              # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
compliance-sys-api/
├── src/
│   ├── ComplianceSys.Api/
│   │   └── Controllers/
│   │       └── ViewCompliancesController.cs        # unchanged (existing get-all route); MODIFY (2026-08-20, US6): Get365's enrichment loop also copies BomStatus
│   ├── ComplianceSys.Application/
│   │   ├── Interfaces/
│   │   │   └── Services/
│   │   │       └── IComplSummarySoService.cs        # MODIFY (2026-08-20): SaveSummarySo gains optional bomStatus param (2nd writer, FR-016)
│   │   └── Services/
│   │       ├── ViewCompliancesService.cs            # MODIFY: call fallback when so-branch lookup is empty; MODIFY (2026-08-20): compute bomStatus, pass to background SaveSummarySo call
│   │       ├── ComplSummarySoService.cs              # MODIFY (2026-08-20): set BomStatus in SaveSummarySo (2nd writer, FR-016)
│   │       └── ViewCompliances/
│   │           ├── IDynamicsDataService.cs           # MODIFY: add 2 method signatures
│   │           ├── DynamicsDataService.cs             # MODIFY: implement the 2 new fetch methods
│   │           ├── IViewCompliancesTransformService.cs # MODIFY: add fallback-build method signature
│   │           ├── ViewCompliancesTransformService.cs  # MODIFY: implement fallback mapping
│   │           └── ViewCompliancesSummaryService.cs     # MODIFY (2026-08-20): set BomStatus on save
│   ├── ComplianceSys.Domain/
│   │   ├── Dynamics/
│   │   │   ├── RSVNSalesLineOpenMaterialRvns.cs      # unchanged (target/t1 shape, existing)
│   │   │   ├── RSVNSalesLineOpenInvoiceCogs.cs        # unchanged (t2 shape, existing, newly consumed)
│   │   │   ├── RSVNProductVariantAlls.cs              # unchanged (t3 shape, existing, newly queried by Product+Config)
│   │   │   └── RSVNSalesOrderOpenInvoiceCogs.cs        # MODIFY (2026-08-20, US6): add BomStatus property (Get365's response DTO)
│   │   └── Entities/
│   │       └── ComplSummarySo.cs                      # MODIFY (2026-08-20): add BomStatus property
│   └── ComplianceSys.Infrastructure/
│       └── Sqls/
│           └── Migration/
│               └── 25_add_bomstatus_to_compl_summary_so.sql  # NEW (2026-08-20): ALTER TABLE ADD COLUMN
└── tests/
    └── ComplianceSysApi.UnitTests/
        └── Services/
            └── ViewCompliances/
                ├── DynamicsDataServiceTests.cs             # ADD cases for the 2 new fetch methods
                └── ViewCompliancesTransformServiceTests.cs # ADD cases for BuildSalesLineOpenMaterialFallbackAsync
```

### Source Code — frontend (2026-08-20, User Story 6)

```text
compliance-client/
└── src/
    └── presentation/
        └── pages/
            └── compliance-view/
                ├── index_new.jsx                              # unchanged — confirmed via RouteResolver.jsx this is the routed component (NOT the unrouted sibling index.jsx)
                └── hooks/
                    └── useAllCompliancesColumnsSaleOrder.jsx   # MODIFY: add "BOM" GridColDef between invoiceDate and statusForUi; add bomStatus to defaultColumnVisibility
```

**Structure Decision**: Backend-only change within the existing `compliance-sys-api` Clean
Architecture layout (`Api` → `Application` → `Domain`, Principle I). No frontend
(`compliance-client/`) files are touched — the spec identifies no UI-visible change, only a data
source substitution behind an existing endpoint. No new project or directory is created; all
changes land in files that already exist in the `ViewCompliances` service group. **Update
(2026-08-20)**: User Story 5 adds exactly one new file (a numbered SQL migration under the existing
`ComplianceSys.Infrastructure/Sqls/Migration/` folder) and one new property on an existing entity
(`ComplSummarySo.BomStatus`) — still no new project, layer, or frontend file. **Update (2026-08-20,
second writer)**: two further existing files gained the same field-setting logic
(`ComplSummarySoService.cs`, `IComplSummarySoService.cs`) plus a small addition to
`ViewCompliancesService.GetViewCompliancesAsync` (compute + pass `bomStatus`) — still no new file
beyond the migration. **Update (2026-08-20, User Story 6)**: this feature's first frontend touch —
one existing frontend file (`useAllCompliancesColumnsSaleOrder.jsx`) gains one column, and two
existing backend files (`RSVNSalesOrderOpenInvoiceCogs.cs`, `ViewCompliancesController.cs`) carry the
new field out to that column. Still no new file on either side, and no new project/layer.

## Complexity Tracking

*No Constitution Check violations — this section is intentionally empty.*
