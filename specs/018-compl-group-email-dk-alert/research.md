# Research: Group Email — Add "DK Alert" Type Option

## R1: Does the backend already support a 3rd `GroupType` value?

**Decision**: Yes — no backend enum or schema change is needed. `GroupEmailType` (`compliance-sys-api/src/ComplianceSys.Domain/Enums/GroupEmailType.cs`) already defines:
```csharp
public enum GroupEmailType : byte
{
    RespGroup = 1,
    AlertGroup = 2,
    ResponsibleForAddition = 3,
    AlertForAddition = 4
}
```
`ComplGroupEmail.GroupType` is a plain `int` column (`compl_group_email.GroupType`), already accepts any integer including 3 today — it is simply never selectable because the UI dropdowns only offer 1/2.

**Rationale**: Per Constitution Principle III (Reuse Existing Backend), the enum is treated as already covering this feature's value 3; the C# member name `ResponsibleForAddition` is an internal identifier only and is not surfaced to users (no `[Display]`/label decorates it). This feature reuses value 3 as-is and gives it the business-facing label "DK Alert" wherever the value is rendered. No `IsAddition`/`ReferenceType` semantics tied to that member name are exercised by this feature — they belong to a separate, already-existing "addition" concept on the same table that this feature does not touch.

**Alternatives considered**: Add a brand-new enum value (e.g. 5) to avoid any semantic overlap with `ResponsibleForAddition`. Rejected — the user explicitly requested value 3, the value is already valid at the data layer, and introducing a 5th value would fragment the type space without any observed conflict (see R3).

## R2: Where is a `GroupType` value turned into a display label today?

**Decision**: `CommonMappingProfile.cs` (`compliance-sys-api/src/ComplianceSys.Application/Mappings/CommonMappingProfile.cs:29-31`) is the single place that computes `ComplGroupEmailResponseDto.GroupTypeName`:
```csharp
CreateMap<ComplGroupEmail, ComplGroupEmailResponseDto>()
    .ForMember(dest => dest.GroupTypeName,
       opt => opt.MapFrom(src => src.GroupType == 1 ? "Responsible" : "Alert"));
```
This is a binary ternary: **any** `GroupType != 1` currently renders as "Alert" — including today's untested value 3. This is the one concrete backend change this feature requires: extend the mapping to a 3-way branch so `GroupType == 3` renders "DK Alert" instead of falling into the "Alert" bucket.

**Rationale**: This is the exact "verified gap" Constitution Principle III allows changing — it's a one-line expansion of existing mapping logic, not new surface.

## R3: Could any existing `compl_group_email` row already have `GroupType = 3` or `4` with a different intended meaning?

**Decision**: Treated as low/no risk, to be spot-checked (not blocking) during implementation. No `ALTER TABLE`/migration script in `ComplianceSys.Infrastructure/Sqls/Migration/` sets `GroupType` to anything but 1/2 for `compl_group_email` rows, and the only UI ever shipped for this table only ever wrote 1 or 2. `GroupEmailType.ResponsibleForAddition`/`AlertForAddition` (3/4) appear to be forward-declared for exactly this kind of future use.

**Rationale**: Since neither the current UI nor any found migration writes 3/4 into `compl_group_email.GroupType`, there is no reasonable path for existing production data to already mean something else there. A quick data check (`SELECT DISTINCT GroupType FROM compl_group_email`) is recommended as a sanity step before/at deployment, not as a spec-blocking dependency.

## R4: Is there a shared frontend constant for these type options, per Constitution Principle II (Reference-Pattern Reuse)?

**Decision**: No such constant exists yet for Group Email Type — options are hardcoded and duplicated identically in `GroupRow.jsx` (edit mode) and `NewGroupRow.jsx` (add mode). The established sibling pattern to follow is `ALERT_TYPE` / `ALERT_TYPE_OPTIONS` in `compliance-client/src/utils/helpers.js:194-206` (introduced by feature 007-compl-master for a very similar "byte-coded type with a labeled dropdown" need).

**Rationale**: Introduce `GROUP_EMAIL_TYPE` and `GROUP_EMAIL_TYPE_OPTIONS` in `helpers.js` following that exact style, and have both `GroupRow.jsx` and `NewGroupRow.jsx` map over the shared options array instead of hardcoding `<MenuItem>` lists. This directly fixes the pre-existing duplication while adding the third option in one place instead of two.

**Alternatives considered**: Just add a third hardcoded `<MenuItem value={3}>DK Alert</MenuItem>` in both files, leaving the duplication as-is. Rejected — Principle II calls for following the established reference-pattern (a shared constant), and touching both files anyway to add the option makes centralizing the list free.

## R5: Should `GroupType` be validated on Create/Update?

**Decision**: Yes, add a minimal check to `ComplGroupRequestDtoValidator.cs` (`compliance-sys-api/src/ComplianceSys.Application/Validators/`) restricting `GroupType` to `{1, 2, 3}` — the three values this feature's UI exposes. Today the validator only checks `Name` is non-empty; `GroupType` is unconstrained.

**Rationale**: The spec (FR-006) requires the system to reject a Type outside the three supported options. This is a single `RuleFor` addition, consistent with the existing validator's style, and closes a pre-existing gap that becomes more visible once a 3rd option exists. Value 4 (`AlertForAddition`) is intentionally excluded — it is not part of this feature's exposed option set and remains reserved for a future feature.

**Alternatives considered**: Use `.IsInEnum()` against `GroupEmailType` directly. Rejected — that would also accept 4, which this feature does not expose or intend to allow yet.

## R6: Existing automated test coverage for this slice

**Decision**: No existing automated test suite covers `ComplGroupService`, `CommonMappingProfile`'s group-email mapping, or the `group-email` frontend pages. Consistent with sibling feature 007-compl-master, this plan does not introduce new test infrastructure; verification is manual, per `quickstart.md`.
