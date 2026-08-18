# Data Model: EUTR Synchronize Data (Sales Order Template Sync + Purchase-Order Missing-Documentation Alert)

No change to any existing table's schema, for either user story. User Story 1 reads an existing D365
reference entity and writes to an existing local table. User Story 2 (added 2026-08-13) reads several
existing D365/local entities; as of the 2026-08-14 update it also writes to **one new table**,
`eutr_purchase_missing` (created via `Sqls/Migration/19_create_eutr_purchase_missing.sql` +
`Sqls/Tables/eutr_purchase_missing.sql`, already applied to the local dev DB) — see "User Story 2 —
New persisted entity" below. Findings are no longer in-memory-only for this story.

## User Story 1 — Existing entities reused (no changes)

### `EutrPurchaseAttachments` (local, `eutr_purchase_attachments` table)

`ComplianceSys.Domain/Entities/EutrPurchaseAttachments.cs` — unchanged.

| Column | Type | Notes |
|---|---|---|
| `Id` | int, PK, identity | unchanged |
| `SalesId` | string, NOT NULL | populated from D365 `InterCompanyOriginalSalesId` |
| `PurchId` | string, NOT NULL | populated from D365 `RSVNRefPurchId` |
| `TemplateCode` | string, NOT NULL, FK → `eutr_templates.Code` | populated from D365 `RSVNEutrTemplate` |
| `CreatedBy` / `CreatedDate` / `UpdatedBy` / `UpdatedDate` | audit columns from `BaseEntity` | set by the sync run (see below) |

Existing uniqueness behavior relied on by this feature: **none is enforced by the schema** — the
"one row per new `SalesId`" guarantee comes entirely from this feature's own pre-insert check
(research.md R5), matching the spec's explicit "check before add" instruction. Rows already present
for a `SalesId` (however they got there — this sync or Map File) are left untouched.

### `RSVNEutrSalesOrderTemplates` (D365 reference entity, read-only)

`ComplianceSys.Domain/Dynamics/RSVNEutrSalesOrderTemplates.cs` — unchanged. `ModelType = 19`,
`EntityName = "RSVNEutrSalesOrderTemplates"`.

| Field | Maps to local field |
|---|---|
| `InterCompanyOriginalSalesId` | `EutrPurchaseAttachments.SalesId` |
| `RSVNRefPurchId` | `EutrPurchaseAttachments.PurchId` |
| `RSVNEutrTemplate` | `EutrPurchaseAttachments.TemplateCode` |

## User Story 1 — Changed (existing file, additive fix — research.md R2/R3)

### `ComplDynamicsService.EntityMappings` (dictionary literal, not a data model per se)

Add the missing entry so `refType = 19` stops short-circuiting to an empty result:

```csharp
{ 19, ("RSVNEutrSalesOrderTemplates", "InterCompanyOriginalSalesId", "RSVNEutrTemplate") }
```

### `ComplDynamicsService.MapDynamicsResponse`, `case 19`

Additionally populate the DTO's named fields (alongside the existing `Id`/`Code`/`Name`) so callers
don't have to remember the `Id`/`Code`/`Name` remapping:

```csharp
case 19:
    responseItems = items.ToObject<List<RSVNEutrSalesOrderTemplates>>()
        ?.Select(x => new ComplDynReferenceResponseDto
        {
            Id = x.InterCompanyOriginalSalesId,
            Code = x.RSVNEutrTemplate,
            Name = x.RSVNRefPurchId,
            InterCompanyOriginalSalesId = x.InterCompanyOriginalSalesId,
            EutrTemplate = x.RSVNEutrTemplate,
            RSVNRefPurchId = x.RSVNRefPurchId,
        })
        .ToList() ?? new();
    break;
```

(`ComplDynReferenceResponseDto` already declares `InterCompanyOriginalSalesId`, `EutrTemplate`, and
`RSVNRefPurchId` — used today by `case 16`/`case 20` — so no DTO change is needed.)

## User Story 1 — New DTO (response shape only, no persistence)

### `EutrSynchronizeSummaryDto` (new — `ComplianceSys.Application/Dtos/Response/`)

Returned by the sync endpoint so the caller can tell what happened without checking logs or the
database directly (spec FR-007 / SC-004).

| Field | Type | Meaning |
|---|---|---|
| `TotalFetched` | int | Total D365 reference records read across all pages |
| `Added` | int | New `eutr_purchase_attachments` rows created this run |
| `Skipped` | int | Records not added (already existed, or missing a required field) |
| `Success` | bool | `false` if the run stopped early due to a source-fetch error |
| `Message` | string | Human-readable summary (e.g. counts, or the error that stopped the run) |

## User Story 1 — Sequence (for reference — implementation detail, not a new persisted entity)

```
EutrSynchronizeDataController.TestSoTemplateSync (GET test-so-template-sync)
  -> IEutrSynchronizeDataService.SyncSalesOrderTemplatesAsync(ct)
       -> IEutrPurchaseAttachmentsRepository.GetSalesIdsWithTemplateAsync(ct)   // preload existing SalesIds (R5)
       -> loop pages: IComplDynamicsService.GetDynRefePagedAsync(19, ..., ct)   // R1, R2, R4
            -> for each record: skip if SalesId/PurchId/TemplateCode missing (FR-006)
            -> skip if SalesId already in the in-memory set (FR-003/FR-004)
            -> else: IRepository<EutrPurchaseAttachments,int>.AddAsync(...) and add SalesId to the set (FR-005, R6)
       -> return EutrSynchronizeSummaryDto
```

## User Story 2 — Existing entities reused, read-only (no changes)

### `RSVNEutrPurchOrders` (D365 reference entity, read-only, refType 15)

`ComplianceSys.Domain/Dynamics/RSVNEutrPurchOrders.cs` — unchanged. `ModelType = 15`. Fields used by
this story: `PurchId` (report's "Purch id"), `OrderAccount` (report's "Vendor code" — see
research.md R9), `EutrTemplate` (matched against `eutr_templates.Code`).

### `VendorsV3` (D365 reference entity, read-only, refType 14)

`ComplianceSys.Domain/Dynamics/VendorsV3.cs` — unchanged, already registered. Fields used: bulk-fetch
once, `VendorAccountNumber` → `VendorOrganizationName` dictionary, keyed by the purchase order's
`OrderAccount` to resolve the report's "Vendor name" (research.md R9).

### `EutrTemplates` / `EutrTemplateDetails` / `EutrStep` (existing — feature 003-eutr-templates)

Read-only via `IEutrTemplatesRepository.GetManyByCodesWithDetailsAsync(codes, ct)` (research.md
R10), batched once for every distinct non-blank `EutrTemplate` code fetched from D365. Fields used
per template: `Name` (report's "{Template name}"), `AlertFor` (Alert-group Id used for per-group
email routing, research.md R13), and `.Details` (the step tree: `Id`/`ParentId`/`DisplayOrder`/
`StepId`, flattened per research.md R11 for the report's "step {n}" numbering).

### `eutr_references` / `eutr_documents` (existing — feature 004-eutr-documents)

Read-only via `IEutrReferencesRepository.GetDocumentsByPoCodesAsync(purchIds, ct)` (research.md
R13), batched once for every purchase order that reaches the step-check stage. Rows are filtered
in-memory to `RefType == 15` ("PO" condition type) and reduced to a `(PoCode, StepId)` coverage set —
a template step with no matching pair in that set is "Missing" for that purchase order.

### `compl_group_email` / `compl_group_email_detail` (existing — group-email feature)

Read-only via `IGroupDetailRepository.GetEmailsByGroupIdsAsync(groupIds, ct)` (research.md R13),
called once per distinct `AlertFor` Id present among this run's flagged purchase orders — not once
per purchase order.

## User Story 2 — New persisted entity (added 2026-08-14 — research.md R17)

### `EutrPurchaseMissing` (local, `eutr_purchase_missing` table)

`ComplianceSys.Domain/Entities/EutrPurchaseMissing.cs` — new, no `BaseEntity` audit columns (mirrors
`ComplSoMissing`'s no-audit shape; this table's data is fully replaced every run).

| Column | Type | Notes |
|---|---|---|
| `Id` | int unsigned, PK, AUTO_INCREMENT | not referenced by any other table; exists only because every table in this solution has a PK |
| `PurchId` | varchar(50), NOT NULL | the flagged purchase order's ID |
| `VendorCode` | varchar(50), NULL | blank when the ERP data has no `OrderAccount` for this purchase order |
| `VendorName` | varchar(255), NULL | blank when the vendor lookup (refType 14) has no match for `VendorCode` |
| `TemplateId` | varchar(50), NULL | the ERP `EutrTemplate` value; NULL for a "Missing template id" record |
| `Note` | text, NOT NULL | exactly one of `"Missing template id"`, `"No PO folder"`, or one-or-more `"{n} - {step name} - Missing"` lines joined by newline (`n` sequential among that purchase order's own missing steps; step name from Step Management, 001-eutr-steps — corrected 2026-08-14, see research.md R11) |
| `AlertForGroupId` | bigint unsigned, NULL | the resolved template's `AlertFor`; NULL for a "Missing template id" record (no template, so no group) |

**Business rules**: The table is fully cleared (`DELETE FROM eutr_purchase_missing`, no `WHERE`) at
the very start of every run (FR-020), before any purchase order is evaluated. Only purchase orders
that end up flagged (non-blank `Note`) are ever inserted (FR-021) — one row per flagged purchase
order, inserted as soon as that purchase order's evaluation completes (not batched at the end).
After every purchase order has been evaluated, the complete table is read back once
(`SELECT * FROM eutr_purchase_missing`) to build the per-group emails/Excel attachments (FR-022) —
grouped by `AlertForGroupId`, with `NULL`-group rows (`"Missing template id"`) joined into every
group's set per the 2026-08-13 clarification (unchanged by this update). No `UPDATE` is ever issued
against this table — every run is a full delete-then-insert, never a partial reconciliation.

## User Story 2 — New DTO (response shape only, no new table beyond the one above)

### `EutrPurchaseMissingSummaryDto` (new — `ComplianceSys.Application/Dtos/Response/`)

Returned by the check endpoint so the caller can tell what happened without checking logs or a
mailbox directly (spec FR-019 parity with FR-007 / SC-004-style self-describing response).

| Field | Type | Meaning |
|---|---|---|
| `TotalFetched` | int | Total D365 `refType = 15` purchase-order records read across all pages |
| `FlaggedCount` | int | Purchase orders with a non-blank Note (FR-014) |
| `GroupsNotified` | int | Distinct Alert groups an email was actually sent to this run (excludes any group skipped for having no resolvable recipient emails, spec Acceptance Scenario 10) |
| `Success` | bool | `false` if the run stopped early due to a source-fetch error (ERP or SharePoint) |
| `Message` | string | Human-readable summary (e.g. counts, or the error that stopped the run) |

## User Story 2 — In-run finding shape (transient, maps 1:1 onto `EutrPurchaseMissing` rows)

### `PurchaseMissingFinding` (private to the new service — implementation detail, listed here for traceability to spec's "Purchase-Order Missing-Documentation Record" Key Entity)

| Field | Source |
|---|---|
| `PurchId` | D365 `refType=15` `PurchId` |
| `VendorCode` | D365 `refType=15` `OrderAccount` (R9) |
| `VendorName` | `refType=14` vendor dictionary lookup by `VendorCode` (R9) |
| `TemplateId` | D365 `refType=15` `EutrTemplate` (report column header says "Template id"; value is the same Template **Code** identifier User Story 1 calls `TemplateCode` — spec Assumptions) |
| `Note` | Computed per FR-010/FR-011/FR-013 — blank, `"Missing template id"`, `"No PO folder"`, or one-or-more `"{n} - {step name} - Missing"` lines |
| `AlertForGroupId` | Resolved template's `AlertFor` (null when `Note = "Missing template id"` — no template to resolve from) |

Only findings with a non-blank `Note` are kept past the evaluation loop (FR-014). As of the
2026-08-14 update, each kept finding is immediately mapped 1:1 onto an `EutrPurchaseMissing` row and
inserted (FR-021) — this struct is no longer the final resting place of a finding, only the shape
used to build one row before `InsertManyAsync`.

## User Story 2 — Sequence (updated 2026-08-14 — research.md R17)

```
EutrSynchronizeDataController.TestPurchaseMissing (GET test-purchase-missing)
  -> IEutrSynchronizeDataService.SendPurchaseMissingAlertAsync(ct)
       -> IEutrPurchaseMissingRepository.DeleteAllAsync(ct)                        // FR-020, R17 — once, before anything else
       -> loop pages: IComplDynamicsService.GetDynRefePagedAsync(15, ..., ct)     // R15 (paging shape of R4)
       -> loop pages: IComplDynamicsService.GetDynRefePagedAsync(14, ..., ct)     // R9, R15 — build VendorCode->VendorName dict
       -> ISharepointService.GetFolders(basePath)                                 // R12 — build folder-name HashSet, once
       -> IEutrTemplatesRepository.GetManyByCodesWithDetailsAsync(distinct codes) // R10 — build TemplateCode->Template dict, once
       -> for each purchase order:
            -> blank/unmatched EutrTemplate -> Note = "Missing template id" (FR-010)
            -> else folder missing (HashSet lookup) -> Note = "No PO folder" (FR-011)
            -> else flatten template steps (R11) and check each against the (PoCode,StepId) coverage
               set built from IEutrReferencesRepository.GetDocumentsByPoCodesAsync(all PurchIds, ct)
               (no RefType filter — R13 correction) -> any step missing -> Note = "{n} - {step name} -
               Missing" lines, n among that PO's own missing steps (FR-013)
               -> no step missing -> not flagged, discarded (FR-014)
            -> if flagged: IEutrPurchaseMissingRepository.InsertManyAsync([row], ct)                  // FR-021, R17
       -> IEutrPurchaseMissingRepository.GetAllAsync(ct)                           // FR-022, R17 — read back once, after the loop
       -> group the read-back rows by AlertForGroupId; NULL-group rows ("Missing template id") join every group
       -> for each distinct group: IGroupDetailRepository.GetEmailsByGroupIdsAsync([groupId], ct)      // R13
            -> build Excel attachment (R14) + send email (MailAlert/AttachmentInfo, FR-016/FR-017)
            -> skip (log) if the group has no resolvable recipient emails
       -> return EutrPurchaseMissingSummaryDto
```

## User Story 3 — Existing entities reused, read-only (added 2026-08-17 — research.md R18/R19)

### `EutrTemplates` (local, `eutr_templates` table — existing, feature 003-eutr-templates)

Read-only via the new `IEutrTemplatesRepository.GetEligibleForDynamicsSyncAsync(ct)` (research.md
R18) — `WHERE IsDeleted = 0 AND IsHide = 0 AND Status = 1`. Fields used: `Id` (to join
`eutr_template_references.TemplateId`), `Code` (ERP push `Code`, and the identifier the delete action
targets), `Name` (ERP push `Name`).

### `EutrTemplateReferences` (local, `eutr_template_references` table — existing, feature
003-eutr-templates "Apply to Customer/Vendor")

Read-only via the new `IEutrTemplateReferencesRepository.GetActiveByTemplateIdsAsync(templateIds,
asOfDate, ct)` (research.md R19) — `WHERE TemplateId IN @templateIds AND FromDate <= @asOfDate AND
ToDate >= @asOfDate`, one call for all eligible templates' `Id`s at once. Fields used: `TemplateId`
(join key back to the eligible-templates list), `VendorCode` (ERP push `VendorCode`). This query's
own SQL/return type are unaffected by the 2026-08-17 left-join correction — the left join itself is
performed in the service, in C#, against this method's unchanged (inner-join-shaped) result (research.md
R24).

### `RSVNEutrTemplates` (D365 entity model, outbound — existing, currently unused elsewhere)

`ComplianceSys.Domain/Dynamics/RSVNEutrTemplates.cs` — unchanged, `ModelType = 17`,
`EntityName = "RSVNEutrTemplates"`. Used as the outbound POST payload for Phase 2 (research.md R20):
`new RSVNEutrTemplates { Code = template.Code, Name = template.Name, VendorCode = mapping.VendorCode
}` for a template with an active mapping, or `VendorCode = string.Empty` for a template with none
(research.md R24, corrected 2026-08-17) — `Note`/`IsDefault` left `null`, and the type's `ModelType`/
`EntityName`/`FilterableFields` metadata members are already `[JsonIgnore]`d, so serializing the
object directly produces exactly the requested `{Code, Name, VendorCode}` shape (plus two harmless
`null` fields).

## User Story 3 — Outbound-only external record (not read back, not stored locally)

### ERP `RSVNEutrTemplates` record (D365-side, write-only from this feature's perspective)

Identified in D365 by `Code`. Phase 1 removes it (if present) via the `deleteTemplate` bound action;
Phase 2 recreates it — one record per currently active Vendor mapping, or exactly one record with a
blank Vendor Code when the template has no currently active mapping (left join, research.md R24,
corrected 2026-08-17) — via a plain POST to the `RSVNEutrTemplates` entity. This feature never reads
it back; there is no local representation of its post-push state beyond the call counts in the
response DTO.

## User Story 3 — New DTO (response shape only, no new table)

### `EutrSynchronizeTemplatesSummaryDto` (new — `ComplianceSys.Application/Dtos/Response/`)

Returned by the sync endpoint so the caller can tell what happened without checking logs or the ERP
directly (spec FR-029 / SC-012).

| Field | Type | Meaning |
|---|---|---|
| `TemplatesEligible` | int | Count of local templates matching IsDeleted=0/IsHide=0/Status=1 this run |
| `DeleteCallsSent` | int | Phase 1 `deleteTemplate` calls successfully sent (one per eligible template, until any failure stops the run) |
| `PushCallsSent` | int | Phase 2 create calls successfully sent — one per eligible template's currently active Vendor mapping, plus one per eligible template with zero active mappings (blank Vendor Code, left join — research.md R24, corrected 2026-08-17) — until any failure stops the run |
| `Success` | bool | `false` if the run stopped early due to a D365 call failure in either phase |
| `Message` | string | Human-readable summary (e.g. counts, or the error that stopped the run) |

## User Story 3 — Sequence (updated 2026-08-17 — research.md R18–R24)

```
EutrSynchronizeDataController.TestSynchronizeTemplates (GET test-synchronize-templates)
  -> IEutrSynchronizeDataService.SyncTemplatesToDynamicsAsync(ct)
       -> IEutrTemplatesRepository.GetEligibleForDynamicsSyncAsync(ct)               // FR-024, R18
       -> Phase 1 — for each eligible template (in order, all of them before Phase 2 starts):
            -> IDynamicService.PostAsync(deleteTemplate URL, { code }, ct)           // FR-025, R20
            -> any failure -> stop run, Success=false, return summary                // R21
       -> IEutrTemplateReferencesRepository.GetActiveByTemplateIdsAsync(eligible Ids, today, ct)  // FR-026, R19
       -> build Lookup<TemplateId, mapping> from the result (unchanged, inner-join shaped)         // R24
       -> Phase 2 — for each eligible template (left join, R24):
            -> has 1+ active mapping(s) -> for each: IDynamicService.PostAsync(RSVNEutrTemplates URL, { Code, Name, VendorCode }, ct)   // FR-027, R20
            -> has 0 active mappings -> IDynamicService.PostAsync(RSVNEutrTemplates URL, { Code, Name, VendorCode="" }, ct)             // FR-028, R24
            -> any failure -> stop run, Success=false, return summary                // R21
       -> return EutrSynchronizeTemplatesSummaryDto
```
