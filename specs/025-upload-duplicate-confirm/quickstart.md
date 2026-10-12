# Quickstart: validating Duplicate File Confirmation

Prerequisites: API + client running; a PO (e.g. `PO-0001`) with Template assigned and an existing uploaded file `A.pdf` whose name matches a Step of the Template. Repeat every scenario on the three screens: `eutr-documents` (Add), Sales Order Map File, Purchase Order View.

Automated: `dotnet test --filter EutrDocumentsServiceCheckExistingTests` (backend); `npm run build` + lint in `compliance-client`.

| # | Scenario | Expected | Success criteria |
|---|---|---|---|
| 1 | Upload `A.pdf` + `B.pdf` (B new) | B uploads immediately; A shows "Awaiting confirmation" + warning + Upload/Skip | SC-001, SC-002 |
| 2 | Upload `A.xml` / `a.PDF` | `A.xml` no warning; `a.PDF` is flagged (case-insensitive) | FR-001 |
| 3 | While B is uploading, press Skip on A | A → Skipped; existing A untouched; batch finishes with summary incl. "1 skipped" | SC-003 |
| 4 | Press Upload on A while other files still run | A runs only after all non-flagged files finish | SC-003, FR-006 |
| 5 | Press Upload on A after all others finished | A runs immediately | FR-006 |
| 6 | 5 flagged files: "Skip all" / "Upload all" | all undecided skipped / confirmed; individually decided ones unchanged | SC-004 |
| 7 | Close popup with awaiting items | batch stays; chip "Confirm n file(s)"; no auto-decision; reload warns | FR-010, FR-011 |
| 8 | Confirmed A fails (e.g. no Step match) then "Retry failed" | no second prompt | edge case |
| 9 | Make check endpoint fail (stop API route) | upload behaves as `021`, no prompts | research D3 |
| 10 | Non-PO Type (Vendor) same Step uploaded twice | second upload flagged (renamed name equal) | D2 |
| 11 | Compare 004 / 005 / 012 | identical states and wording | SC-006 |
