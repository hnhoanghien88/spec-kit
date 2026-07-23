# Implementation Plan: EUTR Reference Types Management

**Branch**: `006-eutr-reference-types` | **Date**: 2026-07-23 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/006-eutr-reference-types/spec.md`

## Summary

Xây dựng màn hình CRUD **EUTR Reference Types** (xem/tìm kiếm/phân trang, tạo, sửa, xóa) trên bảng
`eutr_reference_types` đã có sẵn trên DB (`docs/design/eutr/eutr_db.sql`). Khác với
`001-eutr-steps`, **backend CHƯA tồn tại** cho feature này — phạm vi là **full-stack**: tạo mới
Domain entity + Application (DTO/validator/service) + Api (controller) ở `compliance-sys-api`, và
toàn bộ frontend CRUD screen ở `compliance-client`. Mẫu tham chiếu chính là **`EutrStep`**
(feature `001-eutr-steps`) vì cùng hình dạng bảng (chỉ `Name` + audit); riêng quy tắc xóa cần thêm
xử lý chặn khi bản ghi đang bị `eutr_references.RefType` tham chiếu (FR-009), vì `EutrStep` không
có ràng buộc FK tương tự trong phạm vi của nó.

## Technical Context

**Language/Version**: C# / .NET 8 (backend, `compliance-sys-api`); JavaScript (ES modules), React
18 + Vite (frontend, `compliance-client`)

**Primary Dependencies**: Backend — Dapper 2.1.66 + Dapper.SimpleCRUD, MySql.Data 9.4.0,
FluentValidation, AutoMapper, Serilog. Frontend — React, MUI (`@mui/material`,
`@mui/x-data-grid`, `@mui/icons-material`), axios.

**Storage**: MySQL qua Dapper (generic `IRepository<TEntity,TKey>`/`DapperRepository<,>`); bảng
`eutr_reference_types` (Id, Name, CreatedBy, CreatedDate, UpdatedBy, UpdatedDate) đã tồn tại, FK
`eutr_references.RefType → eutr_reference_types.Id`.

**Testing**: Kiểm thử thủ công theo `quickstart.md` (dự án chưa có test tự động cho các trang CRUD
tương tự); `dotnet build` + `npm run build`/`eslint` làm gate tối thiểu.

**Target Platform**: Web (SPA phục vụ qua nginx; API .NET 8)

**Project Type**: Web application (frontend + backend tách biệt trong monorepo)

**Performance Goals**: Tương đương các màn CRUD hiện có; phân trang server-side, mặc định 10
dòng/trang.

**Constraints**: Comment code tiếng Việt (Nguyên tắc IV); **toàn bộ văn bản hiển thị cho người
dùng bằng tiếng Anh** theo FR-012 (được phép theo Nguyên tắc IV bản 2.0.0). Chỉ CRUD — KHÔNG
import/export. Xóa phải tôn trọng ràng buộc khóa ngoại `eutr_references.RefType` (FR-009).

**Scale/Scope**: 1 màn hình. Backend: ~7 file mới + 2 file sửa (mapping profile, DI). Frontend:
~13 file mới + 3 file sửa (DI repositories, RouteResolver, menu-items). Không có màn hình phụ
(không có Add/Edit page riêng — dùng modal như `EutrStep`).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Nguyên tắc | Trạng thái | Ghi chú |
|-----------|-----------|---------|
| I. Layered Clean Architecture | ✅ PASS | Backend: Domain → Application → Api, Infrastructure không cần file riêng (dùng repository generic). Frontend: domain/ + infrastructure/ + application/usecases/ + presentation/ đúng cấu trúc. |
| II. Reference-Pattern Reuse | ✅ PASS | Clone `EutrStep` (backend, cùng hình dạng bảng) và `eutr-steps` (frontend) — mẫu sát nhất, thay vì `document-type` (có thêm cột không cần). |
| III. Reuse Existing Backend | ⚠️ N/A (có ghi chú) | Nguyên tắc chỉ áp dụng khi backend đã tồn tại. Đã xác minh (agent nghiên cứu) KHÔNG có `EutrReferenceTypes`/`api/eutr-reference-types` nào — bắt buộc tạo mới backend. Đây KHÔNG phải vi phạm, chỉ là nguyên tắc không áp dụng cho trường hợp greenfield. |
| IV. Vietnamese Comments; Localizable UI Labels | ✅ PASS | Comment code tiếng Việt; UI label/thông báo tiếng Anh theo FR-012, được cho phép bởi Nguyên tắc IV. |
| V. Routing & Menu Registration | ✅ PASS | Thêm `RouteResolver.jsx` componentMap `eutr-reference-types` + menu item; seed `userMenu`/quyền backend theo ADR 0002 (task riêng, xem Assumptions). |

Không có vi phạm thực sự (mục III chỉ là "không áp dụng", có giải thích) → không cần Complexity
Tracking bổ sung ngoài phần ghi chú dưới đây.

## Project Structure

### Documentation (this feature)

```text
specs/006-eutr-reference-types/
├── plan.md              # File này
├── spec.md              # Đặc tả
├── research.md           # Phase 0
├── data-model.md         # Phase 1
├── quickstart.md         # Phase 1
├── contracts/
│   └── eutr-reference-types-api.md   # Hợp đồng API cần triển khai (thiết kế, chưa tồn tại)
└── checklists/
    └── requirements.md
```

### Source Code (repository root)

Backend — **TẤT CẢ FILE MỚI** (clone từ `EutrStep`, đổi tên `EutrReferenceTypes` /
`eutr-reference-types`):

```text
compliance-sys-api/src/
├── ComplianceSys.Domain/Entities/EutrReferenceTypes.cs
│                                     # [Table("eutr_reference_types")], kế thừa BaseEntity
│                                     # Id (long), Name (string?)
├── ComplianceSys.Application/
│   ├── Dtos/Request/EutrReferenceTypesRequestDto.cs        # { string Name }
│   ├── Dtos/Response/EutrReferenceTypesResponseDto.cs      # : EutrReferenceTypes (rỗng)
│   ├── Interfaces/Services/IEutrReferenceTypesService.cs   # : IBaseService<EutrReferenceTypes,long,EutrReferenceTypesRequestDto> + GetPagedAsync
│   ├── Services/EutrReferenceTypesService.cs               # : BaseService<...>; override GetPagedAsync (map response dto)
│   │                                                       #   + override DeleteAsync/DeleteMultiAsync (bắt MySqlException 1451 → InvalidOperationException, FR-009)
│   ├── Validators/EutrReferenceTypesRequestDtoValidator.cs  # RuleFor(x => x.Name).NotEmpty()
│   └── Mappings/EutrMappingProfile.cs                     # (SỬA) thêm 3 CreateMap cho EutrReferenceTypes
│   └── DependencyInjection.cs                              # (SỬA) đăng ký IEutrReferenceTypesService + IValidator<EutrReferenceTypesRequestDto>
├── ComplianceSys.Api/
│   ├── Controllers/EutrReferenceTypesController.cs        # [Route("api/eutr-reference-types")], mẫu EutrStepsController
│   └── Middleware/ValidationExceptionMiddleware.cs         # (SỬA) thêm catch (InvalidOperationException) → 409
```

Infrastructure: KHÔNG cần file mới — dùng `IRepository<EutrReferenceTypes, long>` generic
(`DapperRepository<,>`) đã đăng ký sẵn trong `ComplianceSys.Infrastructure/DependencyInjection.cs`.

Frontend — **CÁC FILE MỚI** (clone từ `eutr-step`/`eutr-steps`, đổi tên
`eutr-reference-types`/`EutrReferenceTypes`/`eutr-reference-types`):

```text
compliance-client/src/
├── domain/
│   ├── entities/EutrReferenceTypes.js                       # { id, name, createdBy, createdDate, updatedBy, updatedDate }
│   └── interfaces/IEutrReferenceTypesRepository.js          # getAll/getAllPaging/getById/create/update/delete/deleteMulti
├── infrastructure/
│   ├── api/eutrReferenceTypesApi.js                         # base "/eutr-reference-types", getById dùng "get-by-id/{id}"
│   └── repositories/RestEutrReferenceTypesRepository.js
├── application/usecases/eutr-reference-types/
│   ├── CreateEutrReferenceTypesUseCase.js
│   ├── UpdateEutrReferenceTypesUseCase.js
│   ├── DeleteEutrReferenceTypesUseCase.js
│   ├── DeleteMultiEutrReferenceTypesUseCase.js
│   ├── GetEutrReferenceTypesUseCase.js
│   └── GetPagingEutrReferenceTypesUseCase.js
├── presentation/pages/eutr-reference-types/
│   ├── index.jsx                                            # DataGrid + toolbar Add/Delete-multi, permission theo menu code "eutr-reference-types"
│   ├── components/EutrReferenceTypesModal.jsx                 # chỉ field "name"
│   ├── components/EutrReferenceTypesActionCell.jsx
│   ├── hooks/useEutrReferenceTypesColumns.jsx                 # cột: name, createdBy, createdDate, actions
│   └── hooks/useEutrReferenceTypesData.js
└── (sửa) di/repositories.js                # đăng ký eutrReferenceTypes: new RestEutrReferenceTypesRepository()
└── (sửa) app/routes/RouteResolver.jsx      # lazy import + codeToComponent["eutr-reference-types"]
└── (sửa) presentation/menu-items/ComplianceSystem.jsx  # menu item code "eutr-reference-types" url "/eutr/reference-types"
```

Vận hành/DB (không phải code sinh tự động — task riêng ở `/speckit-tasks`, theo ADR 0002):

```text
docs/design/eutr/seed_eutr_reference_types_menu.sql   # mẫu seed userMenu + permission (comment-out, theo mẫu seed_eutr_templates_menu.sql)
```

**Structure Decision**: Web application (Option 2). Đây là feature **full-stack** (khác
`001-eutr-steps` là frontend-only) vì backend chưa tồn tại cho `eutr_reference_types`. Mẫu tham
chiếu chuẩn: `EutrStep` (mọi tầng backend) + `eutr-steps` (mọi tầng frontend). Khác biệt chính so
với mẫu: (1) cần thêm logic chặn xóa khi đang bị `eutr_references.RefType` tham chiếu (FR-009),
việc `EutrStep` không cần xử lý; (2) cần seed menu/quyền mới trên DB vì đây là route hoàn toàn mới.

## Khác biệt so với mẫu `EutrStep`/`eutr-steps` (lưu ý khi implement)

1. **Domain/Application/Api**: sao chép gần như nguyên văn `EutrStep` → `EutrReferenceTypes`,
   `EutrSteps` → `EutrReferenceTypes` (policy, route). Route: `api/eutr-reference-types` (số nhiều,
   kebab-case).
2. **Chặn xóa khi đang dùng (FR-009/SC-006)** — khác biệt cốt lõi so với `EutrStep`:
   - Override `DeleteAsync(long id, ...)` trong `EutrReferenceTypesService`: bọc lệnh gọi
     `base.DeleteAsync` (hoặc gọi `_repository.DeleteAsync` trực tiếp trong transaction như
     `BaseService`) trong try/catch bắt `MySql.Data.MySqlClient.MySqlException` có
     `Number == 1451`, ném lại `InvalidOperationException("This reference type is currently in use and cannot be deleted.")`.
   - Override `DeleteMultiAsync` để lặp gọi `DeleteAsync` từng id (đảm bảo mỗi id được kiểm tra FK
     riêng) thay vì dựa vào `DeleteManyAsync` hàng loạt của repository generic (xem data-model.md
     phần giả định).
   - Mở rộng `ValidationExceptionMiddleware` thêm `catch (InvalidOperationException ex)` → `409
     Conflict` + `ApiResponse<string>.Fail(ex.Message)`. Đây là thay đổi DÙNG CHUNG (áp dụng cho mọi
     controller khác dùng middleware này) — cần rà soát không có nơi nào khác đang dựa vào hành vi
     "InvalidOperationException = lỗi 500 mặc định" trước khi thêm.
   - Frontend: bắt lỗi 409 từ `DeleteEutrReferenceTypesUseCase`/`DeleteMultiEutrReferenceTypesUseCase`,
     hiển thị message lỗi qua `CustomSnackbar`, KHÔNG xóa dòng khỏi state UI khi thất bại.
3. **Modal**: chỉ có 1 ô nhập `name` (giống `EutrStep`, không có Prefix).
4. **Columns**: `name` (Name), `createdBy` (Created by), `createdDate` (Created date), cột
   `actions`; ẩn `id/updated*` mặc định như mẫu `eutr-steps`.
5. **Menu code/permission**: dùng code `eutr-reference-types`, url `/eutr/reference-types`;
   permissionList lấy từ menu, ánh xạ policy `EutrReferenceTypes.Create/Update/Delete/ReadAll`.
   PHẢI seed `userMenu` + quyền trên DB Authorization (task riêng) — thiếu bước này màn hình mới sẽ
   NotFound dù code đã đúng (ADR 0002).
6. **Validation**: chặn submit khi `name` rỗng (khớp `RuleFor(x => x.Name).NotEmpty()` backend).
7. **Ngôn ngữ UI**: mọi label, nút, breadcrumb, thông báo lỗi/thành công (kể cả thông báo "đang
   được sử dụng"), trạng thái rỗng, hộp thoại xác nhận đều bằng **tiếng Anh** (FR-012).
8. **Không Import/Export**: khác `002-eutr-masters`, feature này không có nút Import/Export trên
   toolbar.

## Complexity Tracking

> Không có vi phạm hiến pháp cần biện minh. Ghi chú duy nhất: mở rộng
> `ValidationExceptionMiddleware` (dùng chung toàn hệ thống) thêm 1 catch clause — đây là thay đổi
> tối thiểu, tái sử dụng exception có sẵn của .NET (`InvalidOperationException`) thay vì tạo loại
> exception mới, nên không vi phạm Nguyên tắc I/III; chỉ cần task implement rà soát không phá vỡ
> hành vi hiện tại của middleware.
