<!--
SYNC IMPACT REPORT
==================
Version change: 1.1.0 → 2.0.0
Bump rationale: Redefined Principle IV — user-facing UI labels are no longer required to be
  Vietnamese; they default to Vietnamese but a feature MAY use English (or another language) when
  its spec explicitly requires it. Code comments remain Vietnamese. Principle redefinition → MAJOR.
Modified principles:
  - IV. Vietnamese Comments & UI Labels → IV. Vietnamese Comments; Localizable UI Labels
Added sections: none
Removed sections: none
Templates requiring updates:
  - .specify/templates/plan-template.md ✅ reviewed (no change needed)
  - .specify/templates/spec-template.md ✅ reviewed (no change needed)
  - .specify/templates/tasks-template.md ✅ reviewed (no change needed)
Deferred TODOs: none

--- history ---
2.0.0 (2026-07-01): Redefined Principle IV to allow spec-driven UI label localization
  (feature 001-eutr-steps requires English UI text per FR-011).
1.1.0 (2026-06-30): Added Reference Documentation section (docs/ architecture, database, ADR).
1.0.0 (2026-06-30): Initial ratification. Core Principles I–V, Technology & Structure
  Constraints, Development Workflow, Governance.
-->

# Eutr Compliance System Constitution

## Core Principles

### I. Layered Clean Architecture (NON-NEGOTIABLE)
Every feature MUST respect the established layer boundaries of each project, and dependencies
MUST point inward only.

- Backend (`compliance-sys-api/`): `Api` → `Application` → `Domain`, with `Infrastructure`
  implementing `Application`/`Domain` abstractions. Controllers MUST stay thin and delegate to
  Application services; business rules MUST NOT live in controllers.
- Frontend (`compliance-client/src/`): a CRUD feature MUST be split across
  `domain/` (entity + repository interface), `infrastructure/` (`api/` client + `repositories/`
  REST implementation), `application/usecases/` (one use case per operation), and
  `presentation/` (page + components + hooks). The repository implementation MUST be registered
  in `di/repositories.js`.

Rationale: The codebase is already organized this way; mixing layers erodes testability and
makes features inconsistent across the team.

### II. Reference-Pattern Reuse
New CRUD features MUST be modeled on an existing, working feature of the same shape rather than
invented from scratch. The canonical reference is the `document-type` feature, which spans every
layer. A new feature clones this structure and renames consistently.

Rationale: A living reference guarantees the generated code matches real conventions (file
naming, hook shape, DI wiring) instead of a plausible-but-divergent guess.

### III. Reuse Existing Backend
When a backend API already exists for a feature, it MUST be reused as-is. Do NOT regenerate,
duplicate, or rewrite controllers, services, DTOs, validators, mappings, or entities that are
already present. Frontend work MUST bind to the existing endpoints; backend changes are limited
to verified gaps only.

Rationale: Regenerating working backend code risks divergence from the database schema, auth
policies, and contracts already in production.

### IV. Vietnamese Comments; Localizable UI Labels
Code comments MUST be written in Vietnamese, consistent with the existing codebase. Identifiers
(variables, types, files) remain in English. User-facing UI labels **default to Vietnamese**, but
a feature MAY render its UI text in English (or another language) when its specification explicitly
requires it (e.g. a functional requirement mandating the UI language); such a deviation MUST be
stated in the feature spec and reflected in the plan.

Rationale: The product audience and existing code use Vietnamese, so it remains the default; but
some features legitimately require a different UI language, and forcing Vietnamese there would
contradict the spec. Comments stay Vietnamese for team consistency regardless of UI language.

### V. Routing & Menu Registration
A new frontend screen is not "done" until it is reachable. Routes MUST be registered in
`app/routes/RouteResolver.jsx` and navigation entries in `presentation/menu-items/`. Each
operation MUST honor the backend authorization policy already defined for the endpoint.

Rationale: Unwired screens are dead code; auth policies exist on the API and must be respected.

## Technology & Structure Constraints

- Monorepo with two independent projects:
  - Backend: .NET 8, Clean Architecture (`ComplianceSys.Api`, `ComplianceSys.Application`,
    `ComplianceSys.Domain`, `ComplianceSys.Infrastructure`), Dapper-based data access.
  - Frontend: React + Vite, layered as described in Principle I.
- API base routing convention is kebab-case (e.g. `api/eutr-steps`); paged listing uses a
  `POST get-all` endpoint with filter/sort/pagination request bodies.
- Frontend feature folders are kebab-case; entities/types are PascalCase; use cases are one file
  per operation (`Create…`, `Update…`, `Delete…`, `DeleteMulti…`, `GetPaging…`, `Get…`).

## Development Workflow

- Spec-driven flow per feature: `/speckit-specify` (what & why) → `/speckit-plan` (how, bound to
  the existing structure) → `/speckit-tasks` → `/speckit-implement`.
- The plan MUST explicitly name the reference feature it clones and list the concrete files to
  add per layer before implementation begins.
- Backend-already-exists features MUST be marked frontend-only in the plan, with backend reduced
  to a verification step.

## Reference Documentation

Constitution chứa **nguyên tắc** (ngắn gọn, được mọi lệnh `/speckit-*` đọc vào). Tài liệu **chi tiết
xuyên suốt** nằm trong `docs/` và là nguồn tham chiếu chuẩn:

- `docs/architecture/overview.md` — kiến trúc tổng thể monorepo (client + api), ranh giới & luồng.
- `docs/database/erd.md` & `docs/database/conventions.md` — ERD tổng, quy ước đặt tên bảng/cột,
  trường audit, truy cập dữ liệu (Dapper), validation, mapping.
- `docs/adr/` — Architecture Decision Records (đánh số 0001, 0002, …) cho quyết định toàn cục.

Quy tắc:
- Quyết định **toàn cục** → ghi vào `docs/adr/`. Quyết định **trong phạm vi 1 feature** → ghi vào
  `specs/NNN-*/research.md`.
- AI/agent KHÔNG tự nạp `docs/` như nạp constitution; khi một feature đụng tới DB hoặc kiến trúc,
  plan/prompt PHẢI trỏ tới file `docs/` liên quan.
- Khi thêm/đổi quyết định kiến trúc lớn, thêm một ADR mới và (nếu thành nguyên tắc) cập nhật
  constitution kèm bump version.

## Governance

This constitution supersedes ad-hoc practices for features in this repository. Amendments MUST be
recorded by updating this file, bumping the version per semantic versioning (MAJOR: principle
removal/redefinition; MINOR: new principle/section; PATCH: clarifications), and updating the
Last Amended date. Plans and implementations MUST verify compliance with these principles;
deviations MUST be justified in the plan's Complexity/Tradeoffs notes.

**Version**: 2.0.0 | **Ratified**: 2026-06-30 | **Last Amended**: 2026-07-01
