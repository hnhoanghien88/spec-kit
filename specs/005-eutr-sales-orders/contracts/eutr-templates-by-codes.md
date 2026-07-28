# Contract: `POST /api/eutr-templates/by-codes`

New endpoint (added to the already-existing `EutrTemplatesController`, owned by feature
`003-eutr-templates`, edited additively) — introduced by spec Update 12 (2026-07-27) to let
`SalesOrderOverviewPage.jsx` resolve the full step-detail tree for many distinct `TemplateCode`s in one
HTTP round trip, instead of the existing 2-calls-per-code loop (`get-all` filtered by `Code`, then
`GetById`) that `MapFilePage.jsx`/`ViewSalesOrderPage.jsx` already use for a single Sales Order. Also
reused by spec Update 13's per-row, on-demand Download pipeline (as a 1-row "batch" of that row's own
distinct codes). See `research.md` Decision 44.

## Request

```
POST /api/eutr-templates/by-codes
Authorization: Bearer <token>   // Policy: EutrTemplates.ReadAll (same "read many" policy already
                                //   guarding get-all — no new policy)
Body: string[]                  // e.g. ["TPL-001", "TPL-002"] — distinct codes only, deduped client-side
```

- Body is the set of **distinct** `TemplateCode`s referenced by `eutr_purchase_attachments` rows across
  every Sales ID being processed (the whole visible page, for Update 12's batch; or just one row's own
  codes, for Update 13's on-demand Download).
- An empty array MUST return an empty result, not an error.

## Response

```json
{
  "data": [
    {
      "id": 12,
      "code": "TPL-001",
      "name": "Template A - V1",
      "isDefault": false,
      "versionId": 1,
      "status": 2,
      "alertFor": null,
      "alertForName": null,
      "isHide": false,
      "stepsCount": 5,
      "details": [
        { "id": 101, "templateId": 12, "parentId": "0", "stepId": 3, "requirementType": "Required", "takeFrom": "PO", "displayOrder": 1, "stepName": "Invoice" }
      ]
    }
  ]
}
```

(Wrapped in the standard `ApiResponse<List<EutrTemplatesResponseDto>>` envelope — reuses the existing
`EutrTemplatesResponseDto`/`EutrTemplateDetailsResponseDto` classes as-is, the same shape `GetById`
already returns for one template.)

- One entry per requested `Code` that still exists and is not soft-deleted (`IsDeleted = 0`) —
  a requested code with no matching, non-deleted template is simply absent from the response (mirrors
  the existing `by-sales-ids`/Template-column convention of silently skipping orphaned codes rather than
  erroring).
- `details` is always populated (never `null`) for every returned template, same as `GetById`'s existing
  behavior — a template with zero detail rows returns `details: []`.

## Before this feature (current behavior)

No endpoint returns more than one template's full `Details` tree per call. Resolving N distinct
`TemplateCode`s today costs 2×N sequential HTTP calls (`get-all` Code→Id resolution, then `GetById`),
already the pattern both `MapFilePage.jsx` (Update 2) and `ViewSalesOrderPage.jsx` (Update 4) use per
Sales Order. This endpoint does the same 2-query work (header lookup, then detail lookup) but scoped to
however many codes are requested at once, in exactly 2 SQL round trips regardless of N (research.md
Decision 44).

## Backward compatibility

Net-new endpoint, reusing already-existing DTOs — no existing caller or contract is affected. `get-all`
and `GET /{id}` are unchanged.
