# Tài liệu xuyên suốt dự án (cross-cutting docs)

Thư mục này chứa tài liệu **dùng chung cho toàn dự án**, bổ trợ cho Spec Kit (không thay thế).

## Quan hệ với Spec Kit

| Nơi | Vai trò |
|-----|---------|
| `.specify/memory/constitution.md` | **Nguyên tắc/luật** tổng thể — ngắn gọn, declarative; được mọi lệnh `/speckit-*` đọc vào |
| `specs/NNN-feature/` | Spec **theo từng feature** (spec, plan, data-model, contracts, research) |
| `docs/` (thư mục này) | **Chi tiết tham chiếu** xuyên suốt: kiến trúc tổng thể, ERD/quy ước DB, ADR |

Quy tắc tránh trùng lặp:
- Constitution = "luật" → `docs/` = "chi tiết". Constitution **trỏ tới** `docs/`.
- ADR ghi quyết định **toàn cục**; `specs/NNN/research.md` ghi quyết định **trong phạm vi 1 feature**.
- ⚠️ AI **không tự đọc** `docs/` như đọc constitution. Khi prompt feature đụng DB/kiến trúc, hãy
  trỏ tới file cụ thể (vd: "theo `docs/database/conventions.md`").

## Mục lục

- [architecture/overview.md](architecture/overview.md) — kiến trúc tổng thể monorepo (client + api)
- [database/erd.md](database/erd.md) — ERD tổng & nguồn ERD chi tiết
- [database/conventions.md](database/conventions.md) — quy ước đặt tên bảng/cột, audit fields
- [adr/](adr/) — Architecture Decision Records (đánh số 0001, 0002, …)

## Tài liệu liên quan đã có sẵn

- `compliance-sys-api/docs/Project-Architecture-Patterns.md` — pattern kiến trúc backend
- `compliance-client/docs/new-page-from-document-type-prompt.md` — hướng dẫn tạo trang mới từ mẫu document-type
- `compliance-client/ERD.md` — ERD chi tiết phía nghiệp vụ Compliance
- `design/` — tài liệu thiết kế nghiệp vụ EUTR (workflow, steps)
