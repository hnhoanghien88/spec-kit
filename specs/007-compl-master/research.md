# Research: Compliance Master Alert Type

## R1. Where AlertType lives today

**Decision**: `AlertType` already exists as a column on the `compl_masters` MySQL table (per the original request), but is not yet exposed anywhere in the application: not on the `ComplMaster` domain entity, not on `ComplMasterRequest`/`ComplMasterResponse`, not selected by any read stored procedure, and not present in the frontend form/payload/list. This feature closes that gap end-to-end (entity → DTOs → stored procedures → frontend form/payload → list column), per Constitution Principle III (Reuse Existing Backend: extend a verified gap, don't rewrite).

**Rationale**: Confirmed by reading `src/ComplianceSys.Domain/Entities/ComplMaster.cs`, `ComplMasterRequest.cs`, `ComplMasterResponse.cs`, `ComplianceMasterForm.jsx`, and `useComplianceMasterColumns.jsx` — none reference `AlertType`/`alertType` today.

**Alternatives considered**: None — this is a factual gap, not a design choice.

## R2. Enum representation and naming

**Decision**: Add a new backend enum `ComplianceSys.Domain.Enums.AlertType : byte { All = 0, Missing = 1, Expired = 2 }` in its own file `AlertType.cs`, mirroring the existing `ComplType.cs` / `GroupEmailType.cs` style exactly (byte-backed, one enum per file, no `[Description]` attributes). On the frontend, add a matching frozen object `ALERT_TYPE` to `helpers.js`, mirroring the existing `groupEmailType`/`TEMPLATE_STATUS` pattern (`Object.freeze({...})` for a code→value map, plus a `{value, label}` array for building the Create/Edit form's dropdown, matching `REQUIREMENT_TYPES`/`TAKE_FROM_OPTIONS`).

**Rationale**: `helpers.js` already has two established patterns for small fixed enums — a `Object.freeze` value map (`groupEmailType`, `TEMPLATE_STATUS`) and a `{value, label}` options array consumed directly by a `<Select>` (`REQUIREMENT_TYPES`, `TAKE_FROM_OPTIONS`). The Alert type dropdown needs both: a value map for reading/comparing, and an options array for rendering `MenuItem`s — following `TEMPLATE_STATUS`'s already-similar 3-way-enum shape most closely.

**Alternatives considered**: Naming the backend enum type identically to the entity property (`AlertType AlertType { get; set; }`) is valid C# (different namespaces) but the codebase's existing convention (`ComplType` entity property is typed `byte`, not the `ComplType` enum) favors storing the property as a plain numeric type and using the enum only for readability/lookup in code that branches on it. Decision: store `ComplMaster.AlertType` as `int` (matching sibling numeric flags `IsIndividual`, `VersionNo` on the same entity) rather than as the enum type, consistent with existing entity style; the enum still exists in `Domain/Enums` for anyone who needs named constants.

There's an unrelated existing `SendAlertType` enum in `ComplianceSys.Application.Constants.ComplEnum.cs` (`AutoSendAlert`, `Review`, `ManualSendAlert`) used for notification dispatch — different concept, no naming collision with the new `AlertType`, but worth flagging so implementers don't confuse the two.

## R3. Persisting AlertType through Create/Update

**Decision**: No AutoMapper `.ForMember` changes are needed. `ComplMasterMappingProfile.cs`'s `CreateMap<ComplMasterRequest, ComplMaster>()` and `CreateMap<ComplMaster, ComplMasterResponse>()` map by property name automatically; since `ComplMasterResponse : ComplMaster`, adding `AlertType` to the entity makes it flow through to the response with zero extra mapping code. `ComplMasterCommandService.AddAsync`/`UpdateReturnIdAsync`/`UpdateNoVersionReturnIdAsync` all go through this AutoMapper profile plus a generic Dapper repository (`IRepository<ComplMaster, long>` from the external `Shared.Dapper` package) — no manual SQL column list exists in this repo for INSERT/UPDATE, so adding the property to the entity + request DTO is sufficient for writes.

**Rationale**: Confirmed by reading `ComplMasterMappingProfile.cs` and `ComplMasterCommandService.cs` — both branches (version-changed insert, in-place update) route through `_mapper.Map(...)` + the generic repository, never building a manual SQL statement.

**Alternatives considered**: None needed; this is the existing, already-working mechanism.

## R4. Persisting/reading AlertType through read paths (paging + get-by-id)

**Decision**: `GetComplMasterAsync`/`GetMasterByIdAsync` in `ComplMasterRepository.cs` call MySQL stored procedures (`CALL compl_sp_get_compl_master_paging(...)`, `CALL compl_sp_get_compl_master_by_id(...)`) and Dapper maps the result set columns onto `ComplMasterResponse` by name. **The checked-in `.sql` source files for these procedures under `Sqls/Procedures/` are stale relative to what's actually deployed** — e.g. `compl_sp_get_compl_master_by_id.sql` selects non-existent columns (`cm.MasterCode`, `cm.MasterName`) instead of the real `Code`/`Name`, and the paging procs' checked-in parameter counts (7/3) don't match the number of arguments the C# repository actually passes (12/8). This means the live, deployed procedures already diverged from these files at some point, and the same must be assumed for `AlertType`: simply editing the checked-in `.sql` files is *not* sufficient — the actual database procedure objects must be altered.

Plan: follow this repo's established DB-change convention — a new numbered file in `Sqls/Migration/` (next number after `14_seed_eutr_reference_types.sql`, i.e. `15_...sql`), which redefines the two read procedures (`DROP PROCEDURE IF EXISTS` + `CREATE PROCEDURE`) adding `AlertType` to their `SELECT` column lists, **based on the live procedure definition pulled directly from the target database (e.g. via `SHOW CREATE PROCEDURE compl_sp_get_compl_master_by_id`)**, not from the stale checked-in file. The checked-in `Sqls/Procedures/*.sql` reference copies should also be refreshed alongside, for documentation, but only after confirming the live definition. This is also what makes the User Story 3 list column possible with zero backend work of its own — once the paging procedure returns `AlertType`, the list gets it for free.

**Rationale**: Editing a stale checked-in `.sql` file and assuming it matches production would silently fail to add the column to the real stored procedure, so the DB-column addition would be invisible in every read (list, detail) even though writes succeed — a create/edit round-trip would appear to silently drop the value.

**Alternatives considered**: Switching the read paths off stored procedures entirely (e.g. to Dapper `SELECT * FROM compl_masters` style queries) — rejected as far out of scope; Principle III requires reusing the existing backend structure, not restructuring its data-access approach.

## R4b. Critical: the pre-existing `AlertType` column's declared width silently corrupts values 1/2 — found and fixed during implementation

**Decision**: The `AlertType` column, as originally added, was declared `TINYINT(1)`. Verified live against the dev DB (`compliance_sys_db_260601`) that `MySql.Data` (the driver this repo uses, `MySql.Data` v9.4.0) treats any `TINYINT(1)` column as a CLR `bool` by default (`TreatTinyAsBoolean`) — a probe insert of `AlertType = 2` read back as `Boolean: True`, and `Convert.ToInt32(true)` is `1`, indistinguishable from `Missing`. This would have silently corrupted every "Expired" (2) selection into "Missing" (1) the moment it was read back through the stored procedures, with no exception or visible error — affecting the Create/Edit forms (US1/US2) *and* the list column (US3) identically, since both read through the same procedures. Fixed by widening the column: `ALTER TABLE compl_masters MODIFY COLUMN AlertType TINYINT NOT NULL DEFAULT 0;` (folded into the same migration as R4, since both must land before the procedures select the column). Re-verified after the fix: the same probe now reads back as CLR `SByte: 2`. Confirmed on the live dev DB, both via a direct probe and via actually calling the redeployed `compl_sp_get_compl_master_paging`/`compl_sp_get_compl_master_by_id` procedures.

**Rationale**: This schema's own convention already distinguishes the two cases — real booleans (`IsIndividual`, `IsDelete`) are `TINYINT(1)`, while existing multi-value numeric enums in the same schema (`compl_master_conditions.ComplType`, `compl_master_group_email.GroupType`) are plain `TINYINT` (no `(1)` width). The column as originally added didn't follow that convention; this is a pre-existing data-modeling gap, not a decision made by this feature, but it had to be corrected here since it would otherwise make the entire feature silently wrong for the "Expired" option specifically, everywhere it's shown.

**Alternatives considered**: Disabling `TreatTinyAsBoolean` at the connection-string level — rejected: it's a global switch affecting every `TINYINT(1)` column the whole application reads (including genuine booleans elsewhere), a much larger blast radius than widening one column. Keeping the column as `TINYINT(1)` and instead adding conversion logic in C# — rejected: the corruption happens at the ADO.NET driver layer before any C# code (Dapper, AutoMapper) ever sees the value; there is nothing to convert once `2` has already become `true`.

## R5. Frontend field wiring (Create/Edit form)

**Decision**: Since compliance-master has no domain entity (`ComplianceMaster.js` was never created — the repository/use-case layer is a pure pass-through), the `alertType` field is added directly where the rest of the form's fields already live: the `masterInfo` state in `ComplianceMasterForm.jsx` (default `0`), the `setMasterInfo` population on edit-load (from `data.alertType`), and the `payload` object built in `handleSave` (`alertType: masterInfo.alertType`). This matches how every other scalar field (`description`, `numDayAlert`, `isIndividual`, etc.) is already wired — no new entity/mapper file is introduced, consistent with the feature's existing (if not textbook Principle-I-perfect) shape.

**Rationale**: Confirmed via the frontend research pass — `RestComplianceMasterRepository.js` and the use cases in `application/usecases/compliance-master/index.js` are thin pass-throughs with no field-level shaping; the only place fields are enumerated is the form component itself.

**Alternatives considered**: Introducing a proper `ComplianceMaster` domain entity now to fully match Principle I — rejected as out of scope creep; this feature's job is to add one field consistently with the feature's current (already-shipped) structure, not to retrofit its architecture.

## R6. UI placement and options (Create/Edit form)

**Decision**: A single-select `FormControl`/`Select` (matching the existing MUI form controls in the same panel) is inserted directly after the Description `TextField` block in `ComplianceMasterForm.jsx`, inside the same "MASTER INFO" `Paper`. Options: "All" (0), "Missing" (1), "Expired" (2); default `0`. The same field/position is shown in edit mode (same component), with its editable/disabled state driven by the same `isDisabled`/`isRenew` logic already gating the rest of the form (per spec FR-006).

**Rationale**: Directly satisfies spec FR-001/FR-002 ("directly below the Description field") and reuses the exact editability rules already computed for the form (`isDisabled`, `masterInfo.isActive && !isRenew`), so no new permission/visibility logic is needed.

**Alternatives considered**: A separate `ComplianceMasterDetail.jsx` (read-only detail view) also displays Description — since the spec's user stories only require the Create/Edit *form* and the list, and `ComplianceMasterDetail.jsx` is a distinct read-only summary component, adding Alert type there is left optional/out of scope unless explicitly requested later.

## R7. Import/Export and other entry points

**Decision**: Out of scope. `ComplMasterImportService`/`ComplMasterExportService` build `ComplMasterRequest` field-by-field from Excel rows; the feature spec only calls for the Create/Edit screens and the list. Imported/legacy masters will land with `AlertType = 0` (All) by the entity's default, matching spec FR-007 (pre-existing records treated as "All").

**Rationale**: Matches the spec's stated scope; extending Excel import/export templates is a separate, unrequested surface.

**Alternatives considered**: Adding an `AlertType` column to the Excel import template now — deferred; not mentioned in the spec, and speculative scope expansion is explicitly discouraged.

## R8. List data already flows to the grid unchanged (User Story 3)

**Decision**: No new data plumbing is needed for the list column. `useComplianceMasterData.js`'s `fetchData` sets `data` directly from `response.data.items` (the raw `ComplMasterResponse` array from `POST api/compliance-master/get-all`), with no field remapping. Once R4/R4b land (`AlertType` selected by the paging stored procedure, correctly typed), every row object the grid receives already has a correct `alertType` property — User Story 3 needs zero backend work of its own.

**Rationale**: Confirmed by reading `useComplianceMasterData.js` — `setData(response.data.items || [])`, no `.map()`/transform step.

**Alternatives considered**: None — this is a factual confirmation, not a design choice.

## R9. Column placement and rendering approach (list)

**Decision**: Insert a new column object in the `columns` array in `useComplianceMasterColumns.jsx` immediately after the existing `status` column definition (and before `description`), matching array-order-equals-visual-order behavior already relied on for every other column in this grid (confirmed: no column-order persistence/`apiRef` state exists for this specific grid, unlike some other screens in this codebase that use `compl_user_grid_preference` — this grid's column order is driven purely by array order). Label rendering: add `ALERT_TYPE_LABELS = { 0: 'All', 1: 'Missing', 2: 'Expired' }` to `helpers.js`, following the exact convention already used for `TEMPLATE_STATUS_LABELS`/`REQUIREMENT_LABELS`/`TAKE_FROM_LABELS`, and use it via a `valueGetter`/`renderCell` on the new column (mirroring how `masterDefault` already uses a `valueGetter` for a derived display string).

**Rationale**: Reusing the same lookup-map convention keeps this consistent with the rest of `helpers.js` rather than introducing a new pattern; placing the column definition in array order directly after `status` is the simplest way to satisfy the "immediately after Status" requirement given this grid has no separate column-order override.

**Alternatives considered**: Reusing the `ALERT_TYPE_OPTIONS` array (from R2, for the form's dropdown) with a `.find()` lookup at render time — rejected in favor of a plain object map (`ALERT_TYPE_LABELS`) since a per-row `.find()` over a 3-item array is unnecessary overhead compared to an O(1) object lookup, and a map form is what every sibling label lookup in this file already is.

## R10. Default visibility (list column)

**Decision**: Add `alertType: true` to `defaultColumnVisibility` in the same hook, alongside `status`'s (implicit, since `status` isn't listed in `defaultColumnVisibility` and therefore defaults to visible under MUI Data Grid's own default) — to be explicit and safe, `alertType` will be explicitly set `true` there.

**Rationale**: Spec FR-010 requires the column visible by default; being explicit avoids relying on an implicit default that could change if the visibility model's defaulting behavior changes.

**Alternatives considered**: Leaving it unlisted (implicit default visible) — rejected as less explicit/robust than adding it directly, for negligible extra effort.

## R11. No additional contract needed for the list column

**Decision**: `contracts/compliance-master-alerttype.md` (documenting the `alertType` field added to `ComplMasterRequest`/`ComplMasterResponse`, including the `POST api/compliance-master/get-all` response used by the list) already covers everything User Story 3 depends on. No separate contract file or addendum is needed for the list column itself, since it introduces no new field, endpoint, or payload shape — only a new rendering of an already-documented one.

**Rationale**: Avoids duplicating the same contract information across two documents within one merged spec.

**Alternatives considered**: A separate contracts file for the list — rejected as redundant.
