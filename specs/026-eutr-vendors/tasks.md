# Tasks: EUTR Vendors Management

**Input**: Design documents from `/specs/026-eutr-vendors/` (plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md)
**Reference feature**: `006-eutr-reference-types` (backend `EutrReferenceTypes*`, frontend `eutr-reference-types`); duplicate check pattern from `EutrMastersService`/`EutrMastersRepository`.
**Tests**: Chỉ thêm unit test service cho quy tắc trùng Code (T031); không TDD.
**Path prefixes**: `API` = `compliance-sys-api/src`, `WEB` = `compliance-client/src`.
Comment code bằng tiếng Việt; UI label tiếng Anh.

## Phase 1: Setup

- [x] T001 Tạo migration `API/ComplianceSys.Infrastructure/Sqls/Migration/42_create_eutr_vendors.sql`: `CREATE TABLE IF NOT EXISTS eutr_vendors (Id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, Code VARCHAR(50) NOT NULL, Name VARCHAR(255) NOT NULL, CreatedBy VARCHAR(50) NULL, CreatedDate DATETIME NULL, UNIQUE KEY eutr_vendors_code_unique (Code))` (theo data-model.md; comment tiếng Việt không dấu như các migration khác)
- [x] T002 [P] Thêm định nghĩa bảng `eutr_vendors` vào `docs/design/eutr/eutr_db.sql` (khớp T001)

---

## Phase 2: Foundational (backend + khung frontend, chặn mọi user story)

- [x] T003 [P] Tạo entity `API/ComplianceSys.Domain/Entities/EutrVendors.cs`: `[Table("eutr_vendors")]`, KHÔNG kế thừa BaseEntity; thuộc tính `[Key] long Id`, `string? Code`, `string? Name`, `string? CreatedBy`, `DateTime CreatedDate`
- [x] T004 [P] Tạo `API/ComplianceSys.Application/Dtos/Request/EutrVendorsRequestDto.cs` (Code, Name) và `Dtos/Response/EutrVendorsResponseDto.cs` (kế thừa EutrVendors) — mẫu EutrReferenceTypes
- [x] T005 [P] Tạo `API/ComplianceSys.Application/Validators/EutrVendorsRequestDtoValidator.cs` (BaseValidator): Code và Name `NotEmpty`, Code `MaximumLength(50)`, Name `MaximumLength(255)`
- [x] T006 [P] Tạo `API/ComplianceSys.Application/Interfaces/Repositories/IEutrVendorsRepository.cs`: `IRepository<EutrVendors,long>` + `Task<bool> ExistsCodeAsync(string code, long? excludeId, CancellationToken ct = default)`
- [x] T007 Tạo `API/ComplianceSys.Infrastructure/Repositories/EutrVendorsRepository.cs` theo mẫu `EutrMastersRepository` (cùng base/constructor); `ExistsCodeAsync` dùng `SELECT COUNT(1) FROM eutr_vendors WHERE LOWER(Code) = LOWER(@code) [AND Id <> @excludeId]` (phụ thuộc T006)
- [x] T008 [P] Tạo `API/ComplianceSys.Application/Interfaces/Services/IEutrVendorsService.cs`: `IBaseService<EutrVendors,long,EutrVendorsRequestDto>` + `GetPagedAsync(PagedRequest, ct)` trả `PagedResult<EutrVendorsResponseDto>`
- [x] T009 Tạo `API/ComplianceSys.Application/Services/EutrVendorsService.cs` (kế thừa BaseService, dùng IEutrVendorsRepository; GetPagedAsync map sang ResponseDto như EutrReferenceTypesService); override `AddAsync`/`UpdateAsync`: trim Code/Name, gọi `ExistsCodeAsync`, trùng thì ném `InvalidOperationException("A vendor with the same code already exists.")` (phụ thuộc T003–T008)
- [x] T010 Thêm map vào `API/ComplianceSys.Application/Mappings/EutrMappingProfile.cs`: `EutrVendorsRequestDto→EutrVendors` (bỏ Id, `IgnoreAuditable`), `EutrVendors→EutrVendorsRequestDto`, `EutrVendors→EutrVendorsResponseDto`
- [x] T011 Đăng ký DI: `IEutrVendorsService`/`EutrVendorsService` và `IValidator<EutrVendorsRequestDto>` trong `API/ComplianceSys.Application/DependencyInjection.cs`; `IEutrVendorsRepository`/`EutrVendorsRepository` trong `API/ComplianceSys.Infrastructure/DependencyInjection.cs`
- [x] T012 Tạo `API/ComplianceSys.Api/Controllers/EutrVendorsController.cs` clone `EutrReferenceTypesController` (route `api/eutr-vendors`, policy `EutrVendors.ReadOne/ReadAll/Create/Update/Delete`, endpoints get-by-id, GET all, POST get-all, POST, PUT, DELETE, delete-multi) theo contracts/eutr-vendors-api.md
- [x] T013 Chạy `dotnet build` trong `compliance-sys-api` và sửa lỗi biên dịch
- [x] T014 [P] Tạo `WEB/domain/entities/EutrVendors.js` (id, code, name, createdBy, createdDate) và `WEB/domain/interfaces/IEutrVendorsRepository.js`
- [x] T015 [P] Tạo `WEB/infrastructure/api/eutrVendorsApi.js` (base `/eutr-vendors`) và `WEB/infrastructure/repositories/RestEutrVendorsRepository.js`; đăng ký `eutrVendors: new RestEutrVendorsRepository()` trong `WEB/di/repositories.js`
- [x] T016 [P] Tạo 7 use case trong `WEB/application/usecases/eutr-vendors/`: `Create/Update/Delete/DeleteMulti/GetById/Get/GetPaging` (tên file `<Tên>EutrVendorsUseCase.js`)
- [x] T017 Đăng ký route `'eutr-vendors'` trong `WEB/app/routes/RouteResolver.jsx` (menu tĩnh `ComplianceSystem.jsx` không cần sửa: routing theo `userMenu` từ backend, menu đã có trong data)

**Checkpoint**: backend build thành công, khung frontend sẵn sàng.

---

## Phase 3: User Story 1 - Xem và tìm kiếm danh sách vendor (P1) 🎯 MVP

**Goal**: Màn hình Vendors hiển thị bảng Code/Name/Created by/Created date, tìm kiếm, phân trang.
**Independent Test**: Mở `/eutr/vendors`, thấy dữ liệu, lọc theo Code/Name, chuyển trang, trạng thái rỗng không lỗi.

- [x] T018 [P] [US1] Tạo hook dữ liệu `WEB/presentation/pages/eutr-vendors/hooks/useEutrVendorsData.js` (clone `useEutrReferenceTypesData`, sort mặc định theo `id`)
- [x] T019 [P] [US1] Tạo `WEB/presentation/pages/eutr-vendors/hooks/useEutrVendorsColumns.jsx` (cột id ẩn, code, name, createdBy, createdDate, actions theo quyền Update/Delete; key lưu cột `eutr-vendors-column-visibility`)
- [x] T020 [P] [US1] Tạo `WEB/presentation/pages/eutr-vendors/components/EutrVendorsActionCell.jsx` (nút Edit/Delete theo quyền, không có Assign Steps)
- [x] T021 [US1] Tạo `WEB/presentation/pages/eutr-vendors/index.jsx` clone `eutr-reference-types/index.jsx`: DataGrid server-side paging/sort/filter, lấy `permissionList` của menu `eutr-vendors`, tiêu đề "EUTR vendors", `noRowsLabel: 'No data'` (chưa nối modal/xóa ở bước này)

**Checkpoint**: US1 chạy độc lập.

---

## Phase 4: User Story 2 - Tạo vendor mới (P1)

**Goal**: Add vendor với Code + Name, chặn trống/trùng.
**Independent Test**: Add `V001`/`Vendor A` thành công; Add `v001` báo trùng; trống báo bắt buộc.

- [x] T022 [US2] Tạo `WEB/presentation/pages/eutr-vendors/components/EutrVendorsModal.jsx` (clone `EutrReferenceTypesModal`, 2 trường Code + Name, trim, báo bắt buộc, maxLength 50/255, tiêu đề Add/Edit vendor)
- [x] T023 [US2] Nối nút Add + modal + `CreateEutrVendorsUseCase` + snackbar (thành công/lỗi từ `e.response.data.message`) trong `WEB/presentation/pages/eutr-vendors/index.jsx`

---

## Phase 5: User Story 3 - Sửa vendor (P2)

**Goal**: Sửa Code/Name, giữ CreatedBy/CreatedDate, chặn trùng Code với bản ghi khác.
**Independent Test**: Đổi Name lưu được; đổi Code trùng bị chặn.

- [x] T024 [US3] Nối Edit (nút hàng + nút toolbar chọn 1 dòng) với `UpdateEutrVendorsUseCase` trong `WEB/presentation/pages/eutr-vendors/index.jsx`; khi sửa gửi kèm `id`
- [x] T025 [US3] Rà soát `EutrVendorsService.UpdateAsync` (`API/.../Services/EutrVendorsService.cs`) và `BaseService` để chắc chắn update không ghi đè CreatedBy/CreatedDate (nếu base update toàn bộ entity, lấy bản ghi hiện có rồi chỉ gán Code/Name)

---

## Phase 6: User Story 4 - Xóa vendor (P2)

**Goal**: Xóa một hoặc nhiều vendor sau xác nhận.
**Independent Test**: Xóa → biến mất; hủy → giữ nguyên.

- [x] T026 [US4] Thêm `ConfirmDialog` xóa một dòng + xóa nhiều dòng (checkbox selection, `DeleteEutrVendorsUseCase`/`DeleteMultiEutrVendorsUseCase`), snackbar kết quả trong `WEB/presentation/pages/eutr-vendors/index.jsx`

---

## Phase 7: Polish & Validation

- [x] T027 [P] Thêm unit test `compliance-sys-api/tests/ComplianceSysApi.UnitTests/Services/EutrVendorsServiceTests.cs`: AddAsync/UpdateAsync ném `InvalidOperationException` khi `ExistsCodeAsync` = true; thành công khi false (theo mẫu test service hiện có, mock repository)
- [x] T028 Chạy `dotnet build` + `dotnet test --filter EutrVendors` trong `compliance-sys-api`; chạy `npm run build` (hoặc `npm run lint`) trong `compliance-client`; sửa lỗi
- [x] T029 Đối chiếu quickstart với code (không chạy DB thật; chưa chạy migration 42 trên DB)

## Dependencies & Execution Order

- Phase 1 → Phase 2 → US1 → US2 → US3 → US4 → Polish. US2–US4 cùng sửa `index.jsx` nên làm tuần tự; US1 là MVP.
- Trong Phase 2: T003–T006, T008, T014–T016 song song; T007 sau T006; T009 sau T003–T008; T010–T012 sau T009; T013 sau T012; T017 sau T015.
- Phase 3: T018–T020 song song, T021 sau đó.

## Implementation Strategy

MVP = Phase 1–3 (xem/tìm danh sách); sau đó thêm lần lượt Add → Edit → Delete.
