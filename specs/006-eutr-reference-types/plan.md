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

### Update 2026-07-24 (Update 1) — Assign Steps

**Input**: "cập nhật 006-eutr-reference-types thêm tính năng assign steps giống với Apply to
customer trong 003-eutr-templates, nhưng hiển thị step ở eutr_steps, không cần tính năng Import,
Export. Khi Add chỉ cần chọn step, không cần thông tin From Date, To date, dữ liệu lưu vào bảng
eutr_reference_type_details."

Thêm một sub-feature mới: **Assign Steps**, gán nhiều step (`eutr_steps`) cho một reference type,
lưu vào bảng `eutr_reference_type_details` đã có sẵn trên DB (`docs/design/eutr/eutr_db.sql` dòng
152-164: `Id, StepId, TypeId, CreatedBy, CreatedDate, UpdatedBy, UpdatedDate`; FK `TypeId →
eutr_reference_types.Id`, `StepId → eutr_steps.Id`; KHÔNG có bảng nào khác tham chiếu ngược tới
`eutr_reference_type_details`, nên KHÔNG cần logic chặn xóa như FR-009). Mẫu tham chiếu chính:
**`EutrTemplateReferences`/`ApplyCustomerPage`** (`003-eutr-templates`, spec Update 13) — cùng hình
dạng "bảng chi tiết gán 1 thực thể phụ vào 1 bản ghi cha, truy cập qua icon trên danh sách cha, màn
hình con riêng với Add/Edit/Delete" — nhưng bỏ Vendor/From Date/To Date/Import/Export, thay bằng 1
trường Step duy nhất và kiểm tra trùng lặp thay vì chồng lấn ngày.

Không có backend/frontend nào hiện hữu cho `eutr_reference_type_details` (xác nhận qua agent nghiên
cứu: không có file `EutrReferenceTypeDetails*` nào) — phải tạo mới toàn bộ, tương tự cách
`EutrReferenceTypes` từng phải tạo mới ở lần đầu implement feature này.

#### New: `eutr_reference_type_details` backend CRUD (Assign Steps)

- **`ComplianceSys.Domain/Entities/EutrReferenceTypeDetails.cs`** NEW — kế thừa `BaseEntity`.
  Thuộc tính: `TypeId` (long), `StepId` (long?, nullable đúng theo DDL). Không có `IsDeleted`/
  `IsHide`.
- **`ComplianceSys.Application/Dtos/Request/EutrReferenceTypeDetailsRequestDto.cs`** NEW —
  `TypeId`, `StepId`.
- **`ComplianceSys.Application/Dtos/Response/EutrReferenceTypeDetailsResponseDto.cs`** NEW — kế
  thừa `EutrReferenceTypeDetails` + thêm `StepName` (string?, resolved bằng JOIN cục bộ tới
  `eutr_steps` — KHÔNG cần gọi D365 như `VendorName` bên `EutrTemplateReferencesResponseDto`, vì
  `eutr_steps` là bảng nội bộ, không phải dữ liệu ngoài hệ thống).
- **`ComplianceSys.Application/Interfaces/Repositories/IEutrReferenceTypeDetailsRepository.cs`**
  NEW — `GetByTypeIdAsync(typeId, ct)`, `HasStepAssignedAsync(typeId, stepId, excludeId, ct)` (kiểm
  tra trùng lặp theo FR-017, tương đương `HasOverlapAsync` bên `EutrTemplateReferences` nhưng đơn
  giản hơn — so sánh bằng, không so sánh khoảng ngày), cộng CRUD cơ bản qua
  `IRepository<EutrReferenceTypeDetails, long>`.
- **`ComplianceSys.Infrastructure/Repositories/EutrReferenceTypeDetailsRepository.cs`** NEW — kế
  thừa `DapperRepository<EutrReferenceTypeDetails, long>`. `GetByTypeIdAsync`: `SELECT d.*, s.Name AS
  StepName FROM eutr_reference_type_details d LEFT JOIN eutr_steps s ON s.Id = d.StepId WHERE
  d.TypeId = @typeId ORDER BY d.CreatedDate DESC`. `HasStepAssignedAsync`: `SELECT COUNT(1) FROM
  eutr_reference_type_details WHERE TypeId = @typeId AND StepId = @stepId` (+ `AND Id <>
  @excludeId` khi sửa).
- **`ComplianceSys.Application/Interfaces/Services/IEutrReferenceTypeDetailsService.cs`** +
  **`.../Services/EutrReferenceTypeDetailsService.cs`** NEW — `BaseService<EutrReferenceTypeDetails,
  long, EutrReferenceTypeDetailsRequestDto>`; override `AddAsync`/`UpdateAsync` gọi
  `HasStepAssignedAsync` trước, ném lỗi validate rõ ràng ("This step is already assigned to this
  reference type.") nếu trùng (FR-017/SC-008); `DeleteAsync` KHÔNG cần override — hard delete mặc
  định của `BaseService` là đủ vì không có bảng nào tham chiếu ngược tới
  `eutr_reference_type_details` (khác với `EutrReferenceTypesService.DeleteAsync`, vốn phải bắt lỗi
  FK 1451 vì `eutr_references.RefType` trỏ tới `eutr_reference_types`).
- **`ComplianceSys.Application/Validators/EutrReferenceTypeDetailsRequestDtoValidator.cs`** NEW —
  `RuleFor(x => x.StepId).NotNull()`, `RuleFor(x => x.TypeId).GreaterThan(0)`.
- **`ComplianceSys.Api/Controllers/EutrReferenceTypeDetailsController.cs`** NEW —
  `[Route("api/eutr-reference-type-details")]`: `GET by-type/{typeId:long}` (policy
  `EutrReferenceTypes.ReadOne`, FR-014), `POST` (policy `EutrReferenceTypes.Update`, FR-015), `PUT
  {id:long}` (policy `EutrReferenceTypes.Update`, FR-016), `DELETE {id:long}` (policy
  `EutrReferenceTypes.Delete`, FR-018). **Tái sử dụng policy `EutrReferenceTypes.*` hiện có, KHÔNG
  tạo policy family riêng** (`EutrReferenceTypeDetails.*`) — đúng quyết định đã áp dụng cho
  `EutrTemplateReferencesController` (tái sử dụng `EutrTemplates.*`), vì Assign Steps là hành động
  phụ truy cập qua icon trên danh sách reference type, không phải màn hình có menu riêng.
- **Migration**: KHÔNG cần file migration mới — bảng `eutr_reference_type_details` đã tồn tại sẵn
  trên DB theo yêu cầu người dùng ("dữ liệu lưu vào bảng eutr_reference_type_details"), giống cách
  `eutr_reference_types` đã có sẵn khi bắt đầu feature này (chỉ cần bước xác minh, không tạo bảng).
- **DI registration** — `ComplianceSys.Application/DependencyInjection.cs` MODIFY: thêm
  `services.AddScoped<IEutrReferenceTypeDetailsService, EutrReferenceTypeDetailsService>();` +
  `services.AddScoped<IValidator<EutrReferenceTypeDetailsRequestDto>,
  EutrReferenceTypeDetailsRequestDtoValidator>();`. `ComplianceSys.Infrastructure/DependencyInjection.cs`
  MODIFY: thêm `services.AddScoped<IEutrReferenceTypeDetailsRepository,
  EutrReferenceTypeDetailsRepository>();`.
- **`ComplianceSys.Application/Mappings/EutrMappingProfile.cs`** MODIFY — thêm `CreateMap<
  EutrReferenceTypeDetailsRequestDto, EutrReferenceTypeDetails>()` (bỏ qua `Id`/audit fields) và
  `CreateMap<EutrReferenceTypeDetails, EutrReferenceTypeDetailsResponseDto>()`.

#### New: Assign Steps frontend

- **`domain/entities/EutrReferenceTypeDetails.js`** NEW — `{ id, typeId, stepId, stepName,
  createdBy, createdDate, updatedBy, updatedDate }`, clone kiểu constructor của
  `EutrReferenceTypes.js`.
- **`domain/interfaces/IEutrReferenceTypeDetailsRepository.js`** NEW — `getByTypeId`, `create`,
  `update`, `delete` (throw 'Not implemented').
- **`infrastructure/api/eutrReferenceTypeDetailsApi.js`** NEW — base `/eutr-reference-type-details`;
  `getByTypeId(typeId)` → `GET .../by-type/{typeId}`, `create` POST, `update` PUT `/{id}`, `delete`
  DELETE `/{id}`.
- **`infrastructure/repositories/RestEutrReferenceTypeDetailsRepository.js`** NEW — gọi
  `eutrReferenceTypeDetailsApi`, bọc kết quả bằng `EutrReferenceTypeDetails`.
- **`application/usecases/eutr-reference-type-details/`** NEW — 1 file/thao tác:
  `GetByTypeIdEutrReferenceTypeDetailsUseCase.js`, `CreateEutrReferenceTypeDetailsUseCase.js`,
  `UpdateEutrReferenceTypeDetailsUseCase.js`, `DeleteEutrReferenceTypeDetailsUseCase.js`.
- **`presentation/pages/eutr-reference-types/AssignStepsPage.jsx`** NEW — trang độc lập (không phải
  modal trong `index.jsx`), theo đúng cấu trúc `ApplyCustomerPage.jsx`: breadcrumb "EUTR > Reference
  Types > {Name} > Assign Steps"; tải reference type theo id (dùng `GetEutrReferenceTypesUseCase`/
  `getById` đã có) để lấy `Name` cho breadcrumb; tải danh sách step đã gán qua
  `GetByTypeIdEutrReferenceTypeDetailsUseCase`; tải TOÀN BỘ danh sách `eutr_steps` một lần qua
  `GetEutrStepsUseCase` (đã có sẵn từ `001-eutr-steps`, dùng chung `repositories.eutrStep`) để làm
  `options` cho combobox Step (Autocomplete, `getOptionLabel={opt => opt?.name || ''}`); dialog
  Add/Edit inline CHỈ có 1 field Autocomplete Step (bắt buộc); Save gọi
  Create/UpdateEutrReferenceTypeDetailsUseCase; Delete dùng `ConfirmDialog` (nêu tên step) rồi gọi
  `DeleteEutrReferenceTypeDetailsUseCase`; validate trùng step client-side trước khi gọi API (đối
  chiếu danh sách đã tải, tương tự `hasOverlap()` của `ApplyCustomerPage.jsx`) — server-side
  `HasStepAssignedAsync` vẫn là nguồn xác thực chính (FR-017).
- **`presentation/pages/eutr-reference-types/components/EutrReferenceTypesActionCell.jsx`**
  MODIFY — thêm 1 `IconButton` **Assign Steps** (icon dạng danh sách/step, ví dụ
  `AssignmentTurnedInIcon` hoặc tương đương đã dùng trong hệ thống), `onClick` điều hướng
  `navigate(\`/eutr/reference-types/assign-steps/${row.id}\`)`, gated theo cùng điều kiện quyền của
  Edit (`canEdit`/`permissionList.includes('Update')`) — vì tái sử dụng policy
  `EutrReferenceTypes.Update` (FR-021).
- **`di/repositories.js`** MODIFY — thêm import `RestEutrReferenceTypeDetailsRepository` và
  `eutrReferenceTypeDetails: new RestEutrReferenceTypeDetailsRepository()`.
- **`app/routes/groups/MainRoutes.jsx`** MODIFY — thêm lazy import `AssignStepsPage` (mẫu
  `Loadable(lazy(() => import('@presentation/pages/eutr-reference-types/AssignStepsPage')))`) và
  route `{ path: '/eutr/reference-types/assign-steps/:id', element: <AssignStepsPage /> }` trong
  cùng mảng con được bọc `PrivateRoute`, cạnh các route con khác của `eutr-templates`/
  `eutr-reference-types`. Route này KHÔNG cần seed `userMenu` mới (khác route gốc
  `/eutr/reference-types` — xem Quyết định 7/ADR 0002) vì đây là route con tĩnh khai báo thẳng
  trong `MainRoutes.jsx`, cùng cơ chế với `/eutr/templates/apply/:id`, quyền kiểm tra qua
  `permissionList` đã tải từ menu cha.

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

### Re-check sau Phase 1 design (Update 1 — Assign Steps)

| Nguyên tắc | Trạng thái | Ghi chú |
|-----------|-----------|---------|
| I. Layered Clean Architecture | ✅ PASS | `EutrReferenceTypeDetails` theo đúng Domain → Application → Api ở backend; frontend theo đúng domain/infrastructure/application/presentation. |
| II. Reference-Pattern Reuse | ✅ PASS | Clone `EutrTemplateReferences`/`ApplyCustomerPage` (`003-eutr-templates`) — mẫu sát nhất cho quan hệ "bảng chi tiết gán entity phụ cho 1 bản ghi cha", thay vì clone lại `EutrStep`/`EutrReferenceTypes` (không có khái niệm gán theo cha). |
| III. Reuse Existing Backend | ⚠️ N/A (có ghi chú) | Xác nhận qua agent nghiên cứu: KHÔNG có `EutrReferenceTypeDetails`/`api/eutr-reference-type-details` nào — bắt buộc tạo mới, greenfield giống `EutrReferenceTypes` ở lần đầu. |
| IV. Vietnamese Comments; Localizable UI Labels | ✅ PASS | Giữ nguyên: comment tiếng Việt, UI tiếng Anh (FR-020). |
| V. Routing & Menu Registration | ✅ PASS | Route con tĩnh `/eutr/reference-types/assign-steps/:id` trong `MainRoutes.jsx`, KHÔNG cần seed menu mới (tái sử dụng quyền/menu cha `eutr-reference-types`) — đúng tiền lệ `ApplyCustomerPage`. |

Không có vi phạm mới; không cần bổ sung Complexity Tracking ngoài ghi chú đã có.

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

### Bổ sung Update 1 — Assign Steps (`eutr_reference_type_details`)

```text
compliance-sys-api/src/
├── ComplianceSys.Domain/Entities/EutrReferenceTypeDetails.cs                      # NEW
├── ComplianceSys.Application/
│   ├── Dtos/Request/EutrReferenceTypeDetailsRequestDto.cs                        # NEW { typeId, stepId }
│   ├── Dtos/Response/EutrReferenceTypeDetailsResponseDto.cs                      # NEW + stepName
│   ├── Interfaces/Repositories/IEutrReferenceTypeDetailsRepository.cs            # NEW GetByTypeIdAsync/HasStepAssignedAsync
│   ├── Interfaces/Services/IEutrReferenceTypeDetailsService.cs                   # NEW
│   ├── Services/EutrReferenceTypeDetailsService.cs                               # NEW (duplicate-check trên Add/Update)
│   ├── Validators/EutrReferenceTypeDetailsRequestDtoValidator.cs                 # NEW RuleFor(StepId).NotNull()
│   └── Mappings/EutrMappingProfile.cs                                            # (SỬA) thêm CreateMap cho EutrReferenceTypeDetails
│   └── DependencyInjection.cs                                                     # (SỬA) đăng ký service + validator
├── ComplianceSys.Infrastructure/
│   ├── Repositories/EutrReferenceTypeDetailsRepository.cs                        # NEW (JOIN eutr_steps cho StepName)
│   └── DependencyInjection.cs                                                     # (SỬA) đăng ký repository
├── ComplianceSys.Api/
│   └── Controllers/EutrReferenceTypeDetailsController.cs                         # NEW [Route("api/eutr-reference-type-details")]

compliance-client/src/
├── domain/
│   ├── entities/EutrReferenceTypeDetails.js                                      # NEW
│   └── interfaces/IEutrReferenceTypeDetailsRepository.js                         # NEW
├── infrastructure/
│   ├── api/eutrReferenceTypeDetailsApi.js                                        # NEW base "/eutr-reference-type-details"
│   └── repositories/RestEutrReferenceTypeDetailsRepository.js                    # NEW
├── application/usecases/eutr-reference-type-details/
│   ├── GetByTypeIdEutrReferenceTypeDetailsUseCase.js                             # NEW
│   ├── CreateEutrReferenceTypeDetailsUseCase.js                                  # NEW
│   ├── UpdateEutrReferenceTypeDetailsUseCase.js                                  # NEW
│   └── DeleteEutrReferenceTypeDetailsUseCase.js                                  # NEW
├── presentation/pages/eutr-reference-types/
│   ├── AssignStepsPage.jsx                                                       # NEW (trang độc lập, mẫu ApplyCustomerPage.jsx)
│   └── components/EutrReferenceTypesActionCell.jsx                               # (SỬA) thêm icon Assign Steps
├── (sửa) di/repositories.js                # đăng ký eutrReferenceTypeDetails: new RestEutrReferenceTypeDetailsRepository()
└── (sửa) app/routes/groups/MainRoutes.jsx  # thêm route "/eutr/reference-types/assign-steps/:id" → AssignStepsPage
```

KHÔNG cần sửa `RouteResolver.jsx`/`menu-items/ComplianceSystem.jsx`/seed menu mới cho phần này —
route con tĩnh trong `MainRoutes.jsx`, tái sử dụng quyền/menu cha `eutr-reference-types` (xem
Quyết định 10/11 trong `research.md`).

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
9. **(Update 1) Assign Steps là sub-feature riêng, KHÔNG clone lại `EutrStep`/`EutrReferenceTypes`
   dù cùng đụng tới `eutr_steps`**: mẫu tham chiếu đúng cho `eutr_reference_type_details` là
   `EutrTemplateReferences`/`ApplyCustomerPage` (`003-eutr-templates`), vì đây là bảng chi tiết gán
   theo 1 record cha (`TypeId`), không phải bảng lookup độc lập như `eutr_steps`/
   `eutr_reference_types`. Xem mục "Update 2026-07-24 (Update 1)" ở đầu file này cho danh sách file
   đầy đủ.

## Complexity Tracking

> Không có vi phạm hiến pháp cần biện minh. Ghi chú duy nhất: mở rộng
> `ValidationExceptionMiddleware` (dùng chung toàn hệ thống) thêm 1 catch clause — đây là thay đổi
> tối thiểu, tái sử dụng exception có sẵn của .NET (`InvalidOperationException`) thay vì tạo loại
> exception mới, nên không vi phạm Nguyên tắc I/III; chỉ cần task implement rà soát không phá vỡ
> hành vi hiện tại của middleware.
>
> **(Update 1)** Không có vi phạm mới. `EutrReferenceTypeDetailsService` KHÔNG cần override
> `DeleteAsync` để bắt lỗi FK (khác `EutrReferenceTypesService`) vì không có bảng nào tham chiếu
> ngược tới `eutr_reference_type_details` — xác nhận qua rà soát `docs/design/eutr/eutr_db.sql`
> (chỉ 2 FK đi RA, không có FK đi VÀO).
