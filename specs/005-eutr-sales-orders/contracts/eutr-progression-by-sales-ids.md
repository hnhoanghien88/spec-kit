# Contract: `POST /api/eutr-progression/by-sales-ids`

New endpoint on a new controller (`EutrProgressionController`) — introduced by spec Update 42
(2026-09-30) to back the **Progress** column on `SalesOrderOverviewPage.jsx` with a single batched read
of precomputed `Total`/`Missing`/`Finished` counters, replacing the Update 12 dynamic computation (4
calls: `by-sales-ids-raw` + `by-codes` + `refType=16` + `list-po-references`, then a client-side
`computeProgress()`/`buildTemplateComputations()` loop). See `research.md` Decision 96 for why a
precomputed table was chosen over further optimizing the dynamic path.

## Request

```
POST /api/eutr-progression/by-sales-ids
Authorization: Bearer <token>   // Policy: a new EutrProgression.Read policy, following the same
                                 //   per-controller policy convention every Eutr*Controller in this
                                 //   codebase already uses (see plan.md Constitution Check, Principle V)
Body: string[]                  // e.g. ["SO007071", "SO007080"]
```

- Body is the list of Sales IDs currently visible on the grid's current page — same sourcing pattern as
  `EutrPurchaseAttachmentsController`'s existing `by-sales-ids`/`by-sales-ids-raw` actions.
- An empty array MUST return an empty result, not an error (same convention as the existing
  `eutr-purchase-attachments` batch actions).

## Response

```json
{
  "data": [
    { "salesId": "SO007071", "total": 6, "missing": 2, "finished": 4 },
    { "salesId": "SO007080", "total": 3, "missing": 0, "finished": 3 }
  ]
}
```

(Wrapped in the standard `ApiResponse<List<ProgressionDto>>` envelope.)

- One row per `SalesId` that has a record in `eutr_progression` (i.e. has gone through ≥1 of the 4
  recompute triggers — spec FR-225) among the requested Sales IDs — **not** one row per every requested
  `SalesId` unconditionally.
- A requested `SalesId` absent from `eutr_purchase_attachments`, or present there but never yet
  recomputed, is simply absent from the response — the frontend maps this to the Progress column's
  `empty` state (FR-228), same condition the pre-Update-42 Progress column already used (FR-083).
- A `SalesId` present in the response with `total = 0` maps to the Progress column's `no-required` state
  (FR-228, unchanged from FR-084).
- `pct` is **not** returned by this endpoint — the frontend computes it client-side as
  `round(finished / total * 100)`, same as it already does today with the dynamic computation's
  `completed`/`total` pair.

## Before this feature (current behavior)

No `eutr_progression` table or endpoint exists today. The Progress column is computed entirely on
demand, per page load/search/paginate, via 3-4 separate calls plus a client-side reduction (Update 12) —
see `research.md` Decision 96 for the full before/after comparison.

## Backward compatibility

Net-new endpoint and net-new DTO (`ProgressionDto`) — no existing caller or contract is affected. The
`by-sales-ids-raw`/`by-codes`/`list-po-references` endpoints this replaces as the Progress column's data
source remain unchanged and still exist for their other existing callers (Template column, Map File,
View, Download's zip-building — none of which read Progress data through them).
