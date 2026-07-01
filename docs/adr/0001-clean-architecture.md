# ADR 0001 — Clean Architecture cho cả frontend và backend

- **Trạng thái**: Accepted
- **Ngày**: 2026-06-30
- **Phạm vi**: Toàn dự án (compliance-client, compliance-sys-api)

## Bối cảnh

Dự án có 2 ứng dụng (SPA React + API .NET). Cần một cách tổ chức nhất quán để: tách nghiệp vụ
khỏi hạ tầng, dễ kiểm thử, và để nhiều người/feature thêm vào mà không lệch chuẩn.

## Quyết định

Cả hai ứng dụng tuân theo **Clean Architecture**, dependency hướng vào trong:

- Backend: `Api → Application → Domain`, `Infrastructure` hiện thực abstraction. Controller mỏng.
- Frontend: `presentation → application(usecases) → domain`, `infrastructure` hiện thực interface
  repository; UI lấy repo qua `di/repositories.js`, **không** import trực tiếp `@infrastructure/...`.

Feature CRUD mới được **clone từ feature mẫu** (`document-type` ở frontend) để bám đúng convention.

## Hệ quả

- (+) Nhất quán, dễ kiểm thử, ranh giới rõ ràng; thay hạ tầng (API/DB) ít ảnh hưởng nghiệp vụ.
- (+) Có khuôn mẫu → AI/người mới sinh code đúng cấu trúc.
- (−) Một thao tác CRUD tạo ra nhiều file nhỏ (entity/interface/api/repo/usecases/page) — chấp nhận
  được để đổi lấy tính nhất quán.

## Liên quan

- [docs/architecture/overview.md](../architecture/overview.md)
- `.specify/memory/constitution.md` (Nguyên tắc I, II)
