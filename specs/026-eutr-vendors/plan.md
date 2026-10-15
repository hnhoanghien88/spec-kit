# Implementation Plan: EUTR Vendors Management

**Branch**: `026-eutr-vendors` | **Date**: 2026-10-14 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/026-eutr-vendors/spec.md`

## Summary

CRUD cơ bản cho bảng `eutr_vendors` (Id, Code, Name, CreatedBy, CreatedDate), có tìm kiếm/phân trang, chống trùng Code (không phân biệt hoa/thường). Clone từ feature tham chiếu **006-eutr-reference-types** (backend: `EutrReferenceTypes*`; frontend: `eutr-reference-types`), cộng thêm kiểm tra trùng Code theo mẫu `EutrMastersService` (`ExistsPrefixAsync`). Backend chưa có → full-stack (không phải frontend-only).

## Technical Context

**Language/Version**: C# / .NET 8 (backend); JavaScript React + Vite (frontend)

**Primary Dependencies**: Dapper (Shared.Dapper `IRepository`/`BaseService`), AutoMapper, FluentValidation; MUI + MUI X DataGrid

**Storage**: MySQL — bảng mới `eutr_vendors` (migration số 42)

**Testing**: xUnit unit test cho service (`ComplianceSysApi.UnitTests`) + kiểm thử thủ công theo quickstart

**Target Platform**: Web (API + SPA)

**Project Type**: web-service + web-app (monorepo, hai repo con `compliance-sys-api`, `compliance-client`)

**Performance Goals**: tìm kiếm < 1 giây với 10.000 vendor (SC-002)

**Constraints**: Entity KHÔNG kế thừa `BaseEntity` vì bảng không có UpdatedBy/UpdatedDate; `BaseService.SetAuditFields` dùng reflection nên tự bỏ qua thuộc tính không tồn tại. Policy dạng `EutrVendors.*`. UI label tiếng Anh (khớp các màn EUTR khác), comment tiếng Việt.

**Scale/Scope**: 1 bảng, 1 controller, 1 màn hình danh sách + 1 modal

## Constitution Check

| Nguyên tắc | Đánh giá |
|---|---|
| I. Layered Clean Architecture | PASS — Domain entity → Application (DTO/validator/service/interface) → Infrastructure (repository) → Api controller mỏng; frontend chia domain/infrastructure/application/presentation |
| II. Reference-Pattern Reuse | PASS — clone `006-eutr-reference-types` |
| III. Reuse Existing Backend | PASS — chưa có backend cho vendors nên được thêm mới; không đụng backend hiện có (`VendorsV3` Dynamics là thứ khác) |
| IV. Vietnamese comments / UI labels | PASS — comment tiếng Việt; UI tiếng Anh như các màn EUTR hiện có, nêu rõ tại đây |
| V. Routing & Menu | PASS — thêm `'eutr-vendors'` vào `RouteResolver.jsx` và mục menu tĩnh trong `ComplianceSystem.jsx`; policy `EutrVendors.*` do menu trong DB (đã thêm) cấp |

Post-design: không phát sinh vi phạm.

## Project Structure

### Documentation (this feature)

```text
specs/026-eutr-vendors/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/eutr-vendors-api.md
└── tasks.md
```

### Source Code

```text
compliance-sys-api/src/
├── ComplianceSys.Domain/Entities/EutrVendors.cs                          (mới)
├── ComplianceSys.Application/
│   ├── Dtos/Request/EutrVendorsRequestDto.cs                             (mới)
│   ├── Dtos/Response/EutrVendorsResponseDto.cs                           (mới)
│   ├── Validators/EutrVendorsRequestDtoValidator.cs                      (mới)
│   ├── Interfaces/Repositories/IEutrVendorsRepository.cs                 (mới: ExistsCodeAsync)
│   ├── Interfaces/Services/IEutrVendorsService.cs                        (mới)
│   ├── Services/EutrVendorsService.cs                                    (mới)
│   ├── Mappings/EutrMappingProfile.cs                                    (sửa: thêm map)
│   └── DependencyInjection.cs                                            (sửa: đăng ký service + validator)
├── ComplianceSys.Infrastructure/
│   ├── Repositories/EutrVendorsRepository.cs                             (mới)
│   ├── DependencyInjection.cs                                            (sửa: đăng ký repository)
│   └── Sqls/Migration/42_create_eutr_vendors.sql                         (mới)
└── ComplianceSys.Api/Controllers/EutrVendorsController.cs                (mới)
docs/design/eutr/eutr_db.sql                                              (sửa: thêm định nghĩa bảng)

compliance-client/src/
├── domain/entities/EutrVendors.js, domain/interfaces/IEutrVendorsRepository.js
├── infrastructure/api/eutrVendorsApi.js, infrastructure/repositories/RestEutrVendorsRepository.js
├── application/usecases/eutr-vendors/{Create,Update,Delete,DeleteMulti,GetById,Get,GetPaging}EutrVendorsUseCase.js
├── presentation/pages/eutr-vendors/{index.jsx, components/*, hooks/*}
├── di/repositories.js, app/routes/RouteResolver.jsx, presentation/menu-items/ComplianceSystem.jsx   (sửa)
```

**Structure Decision**: Web application, clone theo feature 006; repository riêng cho vendors để có `ExistsCodeAsync` (theo `EutrMastersRepository`).

## Complexity Tracking

Không có vi phạm cần biện minh.
