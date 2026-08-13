# Implementation Plan: EUTR Steps Management

**Branch**: `001-eutr-steps` | **Date**: 2026-06-30 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/001-eutr-steps/spec.md`

## Summary

Xây dựng màn hình CRUD **EUTR Steps** ở frontend (`compliance-client`), bám đúng phân tầng Clean
Architecture và **clone nguyên mẫu feature `document-type`**. Backend (`compliance-sys-api`) đã có
sẵn đầy đủ endpoint tại `api/eutr-steps` nên KHÔNG triển khai lại — chỉ verify hợp đồng API. Phạm
vi ban đầu: **frontend-only**.

**Cập nhật (2026-08-11, theo spec FR-005a)**: Bổ sung ràng buộc không cho phép tên bước trùng khi
tạo/sửa. Backend hiện chưa có kiểm tra này (đã xác minh: `EutrStepRequestDtoValidator` chỉ có
`NotEmpty`, `EutrStepService` dùng `IRepository<EutrStep, long>` generic, không có method kiểm tra
trùng tên). Đây là **gap đã xác minh** (verified gap) theo Nguyên tắc III → cho phép sửa backend ở
mức tối thiểu, tái sử dụng đúng khuôn mẫu chống trùng đã có ở `EutrMastersService` +
`IEutrMastersRepository.ExistsStepPrefixAsync` (Nguyên tắc II). Từ bản cập nhật này, phạm vi feature
là **frontend + backend gap nhỏ** (không còn frontend-only tuyệt đối).

## Technical Context

**Language/Version**: JavaScript (ES modules), React 18 + Vite (frontend); .NET 8 (backend, đã có)

**Primary Dependencies**: React, MUI (`@mui/material`, `@mui/x-data-grid`, `@mui/icons-material`),
axios; backend dùng Dapper + FluentValidation + AutoMapper (đã có)

**Storage**: SQL Server qua Dapper (backend hiện hữu; bảng `eutr_steps`)

**Testing**: Kiểm thử thủ công theo `quickstart.md` (dự án chưa có test tự động cho các trang CRUD)

**Target Platform**: Web (SPA phục vụ qua nginx)

**Project Type**: Web application (frontend + backend tách biệt trong monorepo)

**Performance Goals**: Tương đương các màn CRUD hiện có; phân trang server-side, mặc định 10
dòng/trang

**Constraints**: Phải tái sử dụng backend hiện hữu; tuân thủ policy quyền `EutrSteps.*`; comment
code tiếng Việt, nhưng **toàn bộ văn bản hiển thị cho người dùng (UI label, thông báo) bằng tiếng
Anh** (FR-011)

**Scale/Scope**: 1 màn hình, ~13 file frontend mới (đã triển khai); cập nhật 2026-08-11 (FR-005a)
thêm 2 file backend mới + sửa 2 file backend + sửa 1 file frontend (`index.jsx`)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Nguyên tắc | Trạng thái | Ghi chú |
|-----------|-----------|---------|
| I. Layered Clean Architecture | ✅ PASS | Các file phân bổ đúng domain/infrastructure/application/presentation + đăng ký DI |
| II. Reference-Pattern Reuse | ✅ PASS | Clone trực tiếp feature `document-type` |
| III. Reuse Existing Backend | ✅ PASS | Backend đã đủ cho CRUD gốc; FR-005a là **gap đã xác minh** (chưa có kiểm tra trùng tên) → sửa backend ở mức tối thiểu (repository + service override), không viết lại controller/DTO/validator hiện có |
| IV. Vietnamese Comments; Localizable UI Labels | ✅ PASS | Comment code giữ tiếng Việt; UI label/thông báo dùng **tiếng Anh** theo FR-011 — được cho phép bởi Principle IV (constitution v2.0.0, 2026-07-01: UI labels có thể localize khi spec yêu cầu) |
| V. Routing & Menu Registration | ✅ PASS | Thêm vào `RouteResolver.jsx` componentMap + menu item code `eutr-steps` |

Không có vi phạm → không cần Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/001-eutr-steps/
├── plan.md              # File này
├── spec.md              # Đặc tả
├── research.md          # Phase 0
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1
├── contracts/
│   └── eutr-steps-api.md # Hợp đồng API hiện hữu (đối chiếu)
└── checklists/
    └── requirements.md
```

### Source Code (repository root)

Backend — ĐÃ TỒN TẠI, chỉ verify, không tạo mới:

```text
compliance-sys-api/src/
├── ComplianceSys.Api/Controllers/EutrStepsController.cs        # CRUD + get-all + delete-multi
├── ComplianceSys.Application/Dtos/Request/EutrStepRequestDto.cs
├── ComplianceSys.Application/Dtos/Response/EutrStepResponseDto.cs
├── ComplianceSys.Application/Mappings/EutrMappingProfile.cs
└── ComplianceSys.Domain/Entities/EutrStep.cs
```

Backend — GAP MỚI cho FR-005a (thêm/sửa tối thiểu, clone khuôn mẫu `EutrMastersRepository`/
`EutrMastersService`):

```text
compliance-sys-api/src/
├── ComplianceSys.Application/Interfaces/Repositories/IEutrStepRepository.cs   # MỚI — kế thừa IRepository<EutrStep, long> + ExistsNameAsync(name, excludeId, ct)
├── ComplianceSys.Infrastructure/Repositories/EutrStepRepository.cs            # MỚI — implement ExistsNameAsync bằng Dapper (LOWER(TRIM(Name)))
├── ComplianceSys.Application/Services/EutrStepService.cs                     # SỬA — đổi field/constructor sang IEutrStepRepository; override AddAsync/UpdateAsync gọi ExistsNameAsync, throw InvalidOperationException("A step with this name already exists.") khi trùng
└── ComplianceSys.Infrastructure/DependencyInjection.cs                       # SỬA — thêm services.AddScoped<IEutrStepRepository, EutrStepRepository>() (như dòng đăng ký IEutrMastersRepository)
```

Frontend — CÁC FILE MỚI (clone từ `document-type`, đổi tên `eutr-step` / `EutrStep` / `eutr-steps`):

```text
compliance-client/src/
├── domain/
│   ├── entities/EutrStep.js                         # { id, name }  (+ trường audit khi đọc)
│   └── interfaces/IEutrStepRepository.js            # getAll/getAllPaging/getById/create/update/delete/deleteMulti
├── infrastructure/
│   ├── api/eutrStepApi.js                           # base "/eutr-steps"
│   └── repositories/RestEutrStepRepository.js
├── application/usecases/eutr-step/
│   ├── CreateEutrStepUseCase.js
│   ├── UpdateEutrStepUseCase.js
│   ├── DeleteEutrStepUseCase.js
│   ├── DeleteMultiEutrStepUseCase.js
│   ├── GetEutrStepsUseCase.js
│   └── GetPagingEutrStepsUseCase.js
├── presentation/pages/eutr-steps/
│   ├── index.jsx
│   ├── components/EutrStepModal.jsx                 # chỉ field "name"
│   ├── components/EutrStepActionCell.jsx
│   ├── hooks/useEutrStepColumns.jsx                 # cột: name, createdBy, createdDate, actions
│   └── hooks/useEutrStepData.js
└── (sửa) di/repositories.js                         # đăng ký eutrStep: new RestEutrStepRepository()
└── (sửa) app/routes/RouteResolver.jsx               # lazy import + componentMap["eutr-steps"]
└── (sửa) presentation/menu-items/ComplianceSystem.jsx # menu item code "eutr-steps" url "/eutr-steps"
```

Frontend — SỬA cho FR-005a (các file trên đã tồn tại từ lần triển khai trước, chỉ cần sửa cách xử
lý lỗi khi submit, KHÔNG thêm field mới):

```text
compliance-client/src/presentation/pages/eutr-steps/
└── index.jsx   # SỬA catch block của Create/Update: bắt lỗi 409, hiển thị
                # err?.response?.data?.message || err?.message qua CustomSnackbar (severity error) —
                # clone đúng cách eutr-masters/index.jsx đang làm, KHÔNG tạo inline field error mới.
```

**Structure Decision**: Web application (Option 2). Frontend là phần triển khai duy nhất; mỗi
thao tác CRUD ánh xạ 1-1 sang endpoint backend hiện hữu. Mẫu tham chiếu chuẩn là `document-type`,
khác biệt chính: thực thể chỉ có **một trường nhập là `name`** (không có cột/chức năng Prefix), và
toàn bộ văn bản UI dùng **tiếng Anh** (FR-011).

## Khác biệt so với mẫu document-type (lưu ý khi implement)

1. **Modal** chỉ có 1 ô nhập `name` (bỏ `location`).
2. **Columns**: `name` (Step name), `createdBy` (Created by), `createdDate` (Created date), cột
   `actions`; **không có cột Prefix**; có thể ẩn `id/updated*` mặc định như mẫu.
3. **API base path**: `/eutr-steps` (số nhiều, kebab-case) khớp `[Route("api/eutr-steps")]`.
4. **Menu code/permission**: dùng code `eutr-steps`; permissionList lấy từ menu, ánh xạ policy
   `EutrSteps.Create/Update/Delete/ReadAll`.
5. **Validation**: chặn submit khi `name` rỗng (khớp `RuleFor(x => x.Name).NotEmpty()` ở backend).
6. **Ngôn ngữ UI**: mọi label, nút, breadcrumb, thông báo lỗi/thành công, trạng thái rỗng, hộp
   thoại xác nhận đều bằng **tiếng Anh** (FR-011).
7. **Chống trùng tên (FR-005a)**: khác với `document-type` (không có ràng buộc này), EUTR Steps
   chặn tên trùng (không phân biệt hoa/thường, đã trim) khi Create/Update. Nguồn sự thật là
   backend (`EutrStepService` override `AddAsync`/`UpdateAsync` → `InvalidOperationException` →
   HTTP 409 qua `ValidationExceptionMiddleware` sẵn có); frontend không tự kiểm tra trùng ở client
   (danh sách hiển thị có phân trang, không đảm bảo có đủ dữ liệu để so khớp chính xác) mà chỉ bắt
   lỗi 409 và hiển thị message trả về qua snackbar — clone đúng cách `eutr-masters/index.jsx` đang
   xử lý lỗi trùng (StepId, Prefix).

## Complexity Tracking

> Không có vi phạm hiến pháp → bảng này để trống.
