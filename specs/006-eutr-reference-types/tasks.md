# Tasks: EUTR Reference Types Management

**Feature**: `006-eutr-reference-types` | **Plan**: [plan.md](./plan.md) | **Spec**: [spec.md](./spec.md)

**Phạm vi**: **Full-stack** (`compliance-sys-api` + `compliance-client`). Khác với `001-eutr-steps`,
backend CHƯA tồn tại — phải tạo mới Domain/Application/Api. Mẫu tham chiếu: entity/service/controller
`EutrStep` (backend) + toàn bộ feature `eutr-steps` (frontend). Xem [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/eutr-reference-types-api.md](./contracts/eutr-reference-types-api.md).

Quy ước: `[P]` = có thể chạy song song (khác file, không phụ thuộc task chưa xong).
Đường dẫn gốc backend: `compliance-sys-api/src/`. Đường dẫn gốc frontend: `compliance-client/src/`.

> **Lưu ý ngôn ngữ (FR-012)**: Comment trong code giữ tiếng Việt, nhưng **toàn bộ văn bản hiển thị
> cho người dùng (label cột, nút, breadcrumb, ô Search, thông báo lỗi/thành công — kể cả thông báo
> "đang được sử dụng", trạng thái rỗng, hộp thoại xác nhận) phải bằng tiếng Anh**. Chỉ CRUD — KHÔNG
> Import/Export. Không có cột/chức năng Prefix.

---

## Phase 1: Setup

- [X] T001 Xác nhận bảng `eutr_reference_types` trên DB khớp thiết kế: đối chiếu
  `docs/design/eutr/eutr_db.sql` dòng 141-150 (cột `Id, Name, CreatedBy, CreatedDate, UpdatedBy,
  UpdatedDate` + FK `eutr_references_reftype_foreign` từ `eutr_references.RefType`). KHÔNG sửa
  schema.
- [X] T002 [P] Đọc mẫu backend tham chiếu để nắm convention: `compliance-sys-api/src/ComplianceSys.Domain/Entities/EutrStep.cs`,
  `ComplianceSys.Application/{Dtos/Request/EutrStepRequestDto.cs, Dtos/Response/EutrStepResponseDto.cs,
  Interfaces/Services/IEutrStepService.cs, Services/EutrStepService.cs, Validators/EutrStepRequestDtoValidator.cs}`,
  `ComplianceSys.Api/Controllers/EutrStepsController.cs`.
- [X] T003 [P] Đọc mẫu frontend tham chiếu: `compliance-client/src/domain/entities/EutrStep.js`,
  `domain/interfaces/IEutrStepRepository.js`, `infrastructure/{api/eutrStepApi.js,
  repositories/RestEutrStepRepository.js}`, `application/usecases/eutr-step/`,
  `presentation/pages/eutr-steps/` (toàn bộ file).
- [X] T004 [P] Đọc `compliance-sys-api/src/ComplianceSys.Api/Middleware/ValidationExceptionMiddleware.cs`
  và `ComplianceSys.Application/Services/BaseService.cs` để xác nhận điểm mở rộng cho quy tắc chặn
  xóa FR-009 (xem research.md Quyết định 4) trước khi implement Phase 6.

---

## Phase 2: Foundational (nền tảng backend + frontend dùng chung — BLOCKING cho mọi user story)

**⚠️ CRITICAL**: Không user story nào bắt đầu được trước khi phase này xong.

### Backend — tạo mới toàn bộ (không có sẵn để tái sử dụng)

- [X] T005 [P] Tạo Domain entity `compliance-sys-api/src/ComplianceSys.Domain/Entities/EutrReferenceTypes.cs`
  — `[Table("eutr_reference_types")]`, kế thừa `BaseEntity`, `[Key][Column("Id")] public long Id`,
  `public string? Name`. Clone 1-1 từ `EutrStep.cs`, chỉ đổi tên class/table.
- [X] T006 [P] Tạo `compliance-sys-api/src/ComplianceSys.Application/Dtos/Request/EutrReferenceTypesRequestDto.cs`
  — class với 1 property `public string Name`.
- [X] T007 [P] Tạo `compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/EutrReferenceTypesResponseDto.cs`
  — class rỗng `: EutrReferenceTypes`.
- [X] T008 [P] Tạo `compliance-sys-api/src/ComplianceSys.Application/Validators/EutrReferenceTypesRequestDtoValidator.cs`
  — `: BaseValidator<EutrReferenceTypesRequestDto>`, `RuleFor(x => x.Name).NotEmpty()`.
- [X] T009 Tạo `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Services/IEutrReferenceTypesService.cs`
  — `: IBaseService<EutrReferenceTypes, long, EutrReferenceTypesRequestDto>`, thêm
  `Task<PagedResult<EutrReferenceTypesResponseDto>> GetPagedAsync(PagedRequest request, CancellationToken ct = default)`
  (phụ thuộc T005, T006).
- [X] T010 Tạo `compliance-sys-api/src/ComplianceSys.Application/Services/EutrReferenceTypesService.cs`
  — `: BaseService<EutrReferenceTypes, long, EutrReferenceTypesRequestDto>, IEutrReferenceTypesService`;
  override `GetPagedAsync` map sang `EutrReferenceTypesResponseDto` (clone 1-1 logic
  `EutrStepService.GetPagedAsync`). **CHƯA** override `DeleteAsync`/`DeleteMultiAsync` ở bước này —
  để nguyên hành vi xóa mặc định của `BaseService`; việc chặn xóa khi đang dùng (FR-009) sẽ thêm ở
  Phase 6 (US4) (phụ thuộc T009).
- [X] T011 [P] Thêm 3 dòng `CreateMap` cho `EutrReferenceTypes` vào
  `compliance-sys-api/src/ComplianceSys.Application/Mappings/EutrMappingProfile.cs` (file đã có,
  chỉ thêm block mới): `CreateMap<EutrReferenceTypesRequestDto, EutrReferenceTypes>().ForMember(dest
  => dest.Id, opt => opt.Ignore()).IgnoreAuditable()`, `CreateMap<EutrReferenceTypes,
  EutrReferenceTypesRequestDto>()`, `CreateMap<EutrReferenceTypes, EutrReferenceTypesResponseDto>()`
  (phụ thuộc T005, T006, T007).
- [X] T012 Đăng ký DI trong `compliance-sys-api/src/ComplianceSys.Application/DependencyInjection.cs`
  (file đã có, chỉ thêm 2 dòng): `services.AddScoped<IEutrReferenceTypesService,
  EutrReferenceTypesService>();` và `services.AddScoped<IValidator<EutrReferenceTypesRequestDto>,
  EutrReferenceTypesRequestDtoValidator>();` (phụ thuộc T008, T010).
- [X] T013 Tạo `compliance-sys-api/src/ComplianceSys.Api/Controllers/EutrReferenceTypesController.cs`
  — `[Authorize][ApiController][Route("api/eutr-reference-types")]`; clone 1-1
  `EutrStepsController` với 7 endpoint theo [contracts/eutr-reference-types-api.md](./contracts/eutr-reference-types-api.md):
  `GET get-by-id/{id:long}` (policy `EutrReferenceTypes.ReadOne`), `GET` (policy
  `EutrReferenceTypes.ReadAll`), `POST get-all` (policy `EutrReferenceTypes.ReadAll`), `POST`
  (policy `EutrReferenceTypes.Create`), `PUT {id:int}` (policy `EutrReferenceTypes.Update`),
  `DELETE {id:int}` (policy `EutrReferenceTypes.Delete`), `POST delete-multi` (policy
  `EutrReferenceTypes.Delete`) (phụ thuộc T010, T012).

**Checkpoint backend**: `dotnet build` thành công; có thể gọi thử 7 endpoint qua Postman/Swagger
(với user có quyền phù hợp hoặc tài khoản admin) trước khi làm frontend.

### Frontend — tạo mới toàn bộ (clone `eutr-step`/`eutr-steps`)

- [X] T014 [P] Tạo `compliance-client/src/domain/entities/EutrReferenceTypes.js` — class
  `EutrReferenceTypes` với `{ id, name, createdBy, createdDate, updatedBy, updatedDate }`
  (constructor nhận object), clone `EutrStep.js`.
- [X] T015 [P] Tạo `compliance-client/src/domain/interfaces/IEutrReferenceTypesRepository.js` — method
  `getAll`, `getAllPaging`, `getById`, `create`, `update`, `delete`, `deleteMulti` (throw 'Not
  implemented'), clone `IEutrStepRepository.js`.
- [X] T016 [P] Tạo `compliance-client/src/infrastructure/api/eutrReferenceTypesApi.js` — base
  `/eutr-reference-types`; `getById` → `GET /eutr-reference-types/get-by-id/{id}`, `getAllPaging` →
  `POST /eutr-reference-types/get-all` (query page/pageSize/sortColumn/sortOrder + body filters),
  `create` POST, `update` PUT `/{id}`, `delete` DELETE `/{id}`, `deleteMulti` POST `/delete-multi`.
  Clone `eutrStepApi.js`.
- [X] T017 Tạo `compliance-client/src/infrastructure/repositories/RestEutrReferenceTypesRepository.js`
  — extends `IEutrReferenceTypesRepository`, gọi `eutrReferenceTypesApi` (phụ thuộc T015, T016).
- [X] T018 Đăng ký DI trong `compliance-client/src/di/repositories.js` (file đã có, chỉ thêm import +
  1 dòng): import `RestEutrReferenceTypesRepository`, thêm `eutrReferenceTypes: new
  RestEutrReferenceTypesRepository()` (phụ thuộc T017).
- [X] T019 [P] Tạo 6 use case trong `compliance-client/src/application/usecases/eutr-reference-types/`:
  `CreateEutrReferenceTypesUseCase.js`, `UpdateEutrReferenceTypesUseCase.js`,
  `DeleteEutrReferenceTypesUseCase.js`, `DeleteMultiEutrReferenceTypesUseCase.js`,
  `GetEutrReferenceTypesUseCase.js`, `GetPagingEutrReferenceTypesUseCase.js` (mỗi class nhận repo
  qua constructor, `execute(...)` gọi method tương ứng), clone `application/usecases/eutr-step/`
  (phụ thuộc T015).

### Vận hành/DB — reachability (ADR 0002)

- [X] T020 [P] Tạo file seed mẫu `docs/design/eutr/seed_eutr_reference_types_menu.sql` (dạng
  comment-out, theo mẫu `docs/design/eutr/seed_eutr_templates_menu.sql`): `code =
  "eutr-reference-types"`, `url = "/eutr/reference-types"`, permission `ReadAll, ReadOne, Create,
  Update, Delete`. KHÔNG chạy tự động — chỉ cung cấp mẫu cho người vận hành DB.
- [ ] T021 Seed thực tế trên DB Authorization (môi trường test/dev): thêm `userMenu` code
  `eutr-reference-types` + url `/eutr/reference-types`, cấp quyền `EutrReferenceTypes.ReadAll/
  ReadOne/Create/Update/Delete` cho role dùng để kiểm thử (theo mẫu T020). **Không chặn việc viết
  code** ở các phase sau, nhưng BẮT BUỘC trước khi chạy `quickstart.md` qua trình duyệt (thiếu bước
  này màn hình sẽ NotFound dù code đã đúng — ADR 0002) (phụ thuộc T020). **CHƯA CHẠY** — cần quyền
  truy cập trực tiếp DB Authorization của môi trường test/dev, không có sẵn trong phiên làm việc
  này; thực hiện thủ công theo mẫu T020 trước khi kiểm thử qua trình duyệt.

**Checkpoint**: Toàn bộ tầng domain/infrastructure/application (backend + frontend) sẵn sàng; API
hoạt động được; UI có thể build trên đó.

---

## Phase 3: User Story 1 — Xem & tìm kiếm danh sách reference type (P1) 🎯 MVP

**Mục tiêu**: Bảng EUTR Reference Types tải dữ liệu, tìm kiếm theo tên, phân trang server-side; màn
hình truy cập được qua menu.
**Independent test**: Mở `/eutr/reference-types`, thấy bảng đúng cột (Name, Created by, Created
date, Action), lọc theo Name, đổi trang; mọi văn bản UI bằng tiếng Anh.

- [X] T022 [P] [US1] Tạo hook dữ liệu
  `compliance-client/src/presentation/pages/eutr-reference-types/hooks/useEutrReferenceTypesData.js`
  — clone `useEutrStepData.js`, dùng `repositories.eutrReferenceTypes` +
  `GetPagingEutrReferenceTypesUseCase`, đọc `response.data.items/totalCount`, sort mặc định `id
  asc` (phụ thuộc T018, T019).
- [X] T023 [P] [US1] Tạo
  `compliance-client/src/presentation/pages/eutr-reference-types/hooks/useEutrReferenceTypesColumns.jsx`
  — cột `name` (header "Name"), `createdBy` (header "Created by"), `createdDate` (header "Created
  date", `formatDateTime`), cột `actions` (header "Action"); default visibility ẩn `id/updated*`.
  Clone `useEutrStepColumns.jsx`.
- [X] T024 [US1] Tạo trang `compliance-client/src/presentation/pages/eutr-reference-types/index.jsx`
  — clone `presentation/pages/eutr-steps/index.jsx`: DataGrid server mode, tiêu đề + breadcrumb
  "EUTR > Reference Types", ô tìm kiếm ("Search"), phân trang, trạng thái rỗng "No data"; toàn bộ
  label/tiêu đề bằng tiếng Anh; lấy `permissionList` từ menu code `eutr-reference-types` (phụ thuộc
  T022, T023).
- [X] T025 [US1] Thêm route trong `compliance-client/src/app/routes/RouteResolver.jsx`: `const
  EutrReferenceTypesPage = Loadable(lazy(() =>
  import("@presentation/pages/eutr-reference-types")))` và `componentMap["eutr-reference-types"]:
  <EutrReferenceTypesPage />` (phụ thuộc T024).
- [X] T026 [US1] Thêm menu item trong
  `compliance-client/src/presentation/menu-items/ComplianceSystem.jsx` — code
  `eutr-reference-types`, title "Reference types", url `/eutr/reference-types`, breadcrumbs true.

**Checkpoint**: US1 chạy độc lập — đã có MVP xem + tìm kiếm + phân trang qua backend thật, UI tiếng
Anh, màn hình truy cập được qua menu (sau khi seed T021).

---

## Phase 4: User Story 2 — Thêm reference type mới (P1)

**Mục tiêu**: Nút Add mở modal nhập tên, lưu tạo bản ghi mới.
**Independent test**: Add → nhập tên hợp lệ → lưu → dòng mới xuất hiện; tên trống → bị chặn với
thông báo lỗi tiếng Anh (khớp validator backend).

- [X] T027 [P] [US2] Tạo
  `compliance-client/src/presentation/pages/eutr-reference-types/components/EutrReferenceTypesModal.jsx`
  — clone `EutrStepModal.jsx`, CHỈ field `name` (label "Name"); chặn submit khi `name` trống, hiển
  thị lỗi tiếng Anh (ví dụ "Name is required"); tiêu đề modal "Add reference type"/"Edit reference
  type", nút "Save"/"Cancel".
- [X] T028 [US2] Nối Create vào `index.jsx`: nút "Add" mở modal, `onSubmit` gọi
  `CreateEutrReferenceTypesUseCase` khi không có `modalData`, hiển thị snackbar thành công tiếng Anh
  (ví dụ "Reference type created successfully"), `fetchData()` (phụ thuộc T024, T027).

**Checkpoint**: Tạo mới hoạt động end-to-end (frontend ↔ backend thật).

---

## Phase 5: User Story 3 — Sửa reference type (P2)

**Mục tiêu**: Edit một dòng, cập nhật tên.
**Independent test**: Chọn dòng → Edit → đổi tên → lưu → bảng cập nhật; tên trống → bị chặn; thông
báo tiếng Anh.

- [X] T029 [US3] Nối Edit vào `index.jsx`: nút "Edit"/chọn 1 dòng mở modal với `modalData`,
  `onSubmit` gọi `UpdateEutrReferenceTypesUseCase` khi có `modalData` (gửi kèm `id`), snackbar
  thành công tiếng Anh (ví dụ "Reference type updated successfully") (phụ thuộc T028).

**Checkpoint**: Sửa hoạt động; tái dùng cùng modal với US2.

---

## Phase 6: User Story 4 — Xóa & xóa nhiều, kèm chặn xóa khi đang dùng (P2)

**Mục tiêu**: Xóa 1 dòng (có xác nhận) và xóa nhiều dòng đã chọn; xóa bị từ chối rõ ràng khi bản ghi
đang được `eutr_references.RefType` tham chiếu (FR-009/SC-006).
**Independent test**: Delete 1 dòng không đang dùng → xác nhận → biến mất; chọn nhiều → xóa nhiều →
biến mất; Cancel → không xóa. Delete 1 dòng ĐANG được `eutr_references` tham chiếu → nhận lỗi rõ
ràng ("... currently in use ..."), dòng KHÔNG biến mất; mọi văn bản tiếng Anh.

### Backend — chặn xóa khi đang dùng (FR-009)

- [X] T030 [US4] Override `DeleteAsync(long id, string userEmail, CancellationToken ct = default)`
  trong `compliance-sys-api/src/ComplianceSys.Application/Services/EutrReferenceTypesService.cs`:
  bọc phần gọi repository xóa (trong transaction, theo mẫu `BaseService.DeleteAsync`) bằng
  try/catch bắt `MySql.Data.MySqlClient.MySqlException` có `Number == 1451`, ném lại
  `InvalidOperationException("This reference type is currently in use and cannot be deleted.")`
  (phụ thuộc T010).
- [X] T031 [US4] Override `DeleteMultiAsync(IEnumerable<long> ids, CancellationToken ct = default)`
  trong `EutrReferenceTypesService.cs`: lặp gọi `DeleteAsync` (override ở T030) cho từng id thay vì
  dựa vào `DeleteManyAsync` hàng loạt của repository generic, đảm bảo mỗi id trong batch đều được
  kiểm tra FK riêng — nếu bất kỳ id nào bị chặn, dừng và ném lại lỗi tương ứng (không xóa một phần)
  (phụ thuộc T030).
- [X] T032 [US4] Mở rộng
  `compliance-sys-api/src/ComplianceSys.Api/Middleware/ValidationExceptionMiddleware.cs` thêm nhánh
  `catch (InvalidOperationException ex)` → `StatusCode = 409`, trả `ApiResponse<string>.Fail(ex.Message)`.
  Đặt SAU nhánh `KeyNotFoundException` hiện có. Rà soát không có controller nào khác đang cố ý dựa
  vào `InvalidOperationException` → lỗi 500 mặc định trước khi thêm (phụ thuộc T004 — đã đọc file ở
  Setup).

### Frontend — xóa đơn/nhiều + xử lý lỗi 409

- [X] T033 [P] [US4] Tạo
  `compliance-client/src/presentation/pages/eutr-reference-types/components/EutrReferenceTypesActionCell.jsx`
  — clone `EutrStepActionCell.jsx` (nút Edit/Delete theo quyền), tooltip/label tiếng Anh.
- [X] T034 [US4] Nối Delete + DeleteMulti vào `index.jsx`: `ConfirmDialog` cho xóa đơn (gọi
  `DeleteEutrReferenceTypesUseCase`) và xóa nhiều theo `selectionModel` (gọi
  `DeleteMultiEutrReferenceTypesUseCase`); nội dung xác nhận + nút ("Delete"/"Cancel") bằng tiếng
  Anh (ví dụ "Are you sure you want to delete this reference type?") (phụ thuộc T024, T033; T023
  dùng ActionCell).
- [X] T035 [US4] Xử lý lỗi 409 từ `DeleteEutrReferenceTypesUseCase`/
  `DeleteMultiEutrReferenceTypesUseCase` trong `index.jsx`: bắt lỗi response (message từ
  `ApiResponse.Fail`), hiển thị qua `CustomSnackbar` dạng lỗi, KHÔNG xóa dòng khỏi state UI, KHÔNG
  đóng `ConfirmDialog` một cách im lặng (phụ thuộc T032, T034).

**Checkpoint**: Toàn bộ CRUD hoàn chỉnh, bao gồm quy tắc chặn xóa khi đang được tham chiếu.

---

## Phase 7: Polish & Cross-cutting

- [X] T036 [P] Rà soát: **toàn bộ văn bản hiển thị cho người dùng bằng tiếng Anh** (label cột, nút,
  breadcrumb, Search, mọi thông báo bao gồm thông báo "đang được sử dụng", trạng thái rỗng, hộp
  thoại xác nhận) — không còn chuỗi tiếng Việt lọt ra UI (FR-012). Comment code có thể giữ tiếng
  Việt.
- [X] T037 [P] Kiểm tra quyền: nút Create/Update/Delete ẩn/disable đúng theo `permissionList` (dựa
  trên quyền `EutrReferenceTypes.*` đã seed ở T021).
- [X] T038 Chạy `dotnet build` trong `compliance-sys-api` — 0 lỗi biên dịch cho các file mới/sửa.
- [X] T039 Chạy `npm run lint`/`npm run build` trong `compliance-client` và sửa cảnh báo của file
  mới.
- [ ] T040 Kiểm thử thủ công theo [quickstart.md](./quickstart.md) — 7 kịch bản, bao gồm kịch bản 6
  (xóa bị chặn do đang được `eutr_references` tham chiếu). Yêu cầu backend chạy thật + DB đã seed
  (T021) + user có quyền `EutrReferenceTypes.*`. **CHƯA CHẠY** — không có dev server/backend
  đang chạy + DB đã seed trong phiên làm việc này (không tương tác/không có trình duyệt); `dotnet
  build` (T038) và `npm run build`/lint (T039) đều pass sạch. Khuyến nghị chạy thủ công 7 kịch bản
  trên trình duyệt thật trước khi coi feature là sẵn sàng production.

---

## Dependencies & thứ tự

- **Phase 1** (Setup) → **Phase 2** (Foundational) là điều kiện tiên quyết của mọi user story.
- Trong Phase 2 (backend): T005/T006/T007/T008 song song; T009 cần T005+T006; T010 cần T009; T011
  cần T005+T006+T007; T012 cần T008+T010; T013 cần T010+T012.
- Trong Phase 2 (frontend): T014/T015/T016 song song; T017 cần T015+T016; T018 cần T017; T019 cần
  T015.
- T020 (seed mẫu) song song với mọi task khác; T021 (seed thật) cần T020, không chặn code nhưng
  chặn kiểm thử qua trình duyệt (T040).
- **US1 (Phase 3)** dựng MVP, cần Phase 2 xong hoàn toàn (backend + frontend foundational). US2/US3
  đều bổ sung vào `index.jsx` nên T028 → T029 thực thi tuần tự (cùng file). **US4 (Phase 6)** vừa
  sửa backend (T030→T031→T032, tuần tự cùng mối quan tâm) vừa sửa frontend (T033 song song, T034→
  T035 tuần tự); T035 cần T032 (backend đã trả 409) VÀ T034 (đã nối Delete).
- **Phase 7** sau khi các user story mong muốn đã xong.

## Cơ hội song song

- Phase 1: `[P]` T002, T003, T004 cùng lúc (T001 độc lập).
- Phase 2 backend: `[P]` T005, T006, T007, T008 cùng lúc; sau đó T011 có thể song song với T009/T010
  (khác file).
- Phase 2 frontend: `[P]` T014, T015, T016 cùng lúc; T019 song song với T017/T018 (khác file, chỉ
  cần T015).
- Phase 2 ops: T020 `[P]` với mọi task code.
- Phase 3: `[P]` T022, T023 cùng lúc (trước T024).
- Phase 6: T033 (ActionCell) làm song song với T030/T031/T032 (backend, khác file).

## MVP

US1 (Phase 3) — xem + tìm kiếm + phân trang trên backend thật — là lát cắt tối thiểu khả dụng, có
thể demo độc lập sau khi Phase 1+2 hoàn tất (kể cả seed T021 để truy cập được qua menu).

## Tổng quan

- Tổng task: **40**.
- Theo story: US1 = 5 (T022–T026), US2 = 2 (T027–T028), US3 = 1 (T029), US4 = 6 (T030–T035).
- Setup = 4 (T001–T004), Foundational = 17 (T005–T021: 9 backend, 6 frontend, 2 ops), Polish = 5
  (T036–T040).

---

## Update 2026-07-24 (Update 1) — Assign Steps

**Input**: "cập nhật 006-eutr-reference-types thêm tính năng assign steps giống với Apply to
customer trong 003-eutr-templates, nhưng hiển thị step ở eutr_steps, không cần tính năng Import,
Export. Khi Add chỉ cần chọn step, không cần thông tin From Date, To date, dữ liệu lưu vào bảng
eutr_reference_type_details."

**Phạm vi**: **Full-stack**, bảng `eutr_reference_type_details` đã có sẵn trên DB
(`docs/design/eutr/eutr_db.sql` dòng 152-164) nhưng CHƯA có backend/frontend nào — tạo mới toàn bộ.
Mẫu tham chiếu: `EutrTemplateReferences`/`ApplyCustomerPage` (`003-eutr-templates`, Apply to
Customer), KHÔNG phải `EutrStep`/`EutrReferenceTypes` (khác hình dạng quan hệ — đây là bảng chi
tiết gán theo 1 bản ghi cha, không phải bảng lookup độc lập). Xem
[plan.md](./plan.md#update-2026-07-24-update-1--assign-steps),
[research.md](./research.md) Quyết định 9-11, [data-model.md](./data-model.md) mục
`EutrReferenceTypeDetails`, [contracts/eutr-reference-types-api.md](./contracts/eutr-reference-types-api.md)
mục "Assign Steps".

> **Lưu ý ngôn ngữ (FR-020)**: UI của Assign Steps bằng tiếng Anh, comment code tiếng Việt. KHÔNG
> Import/Export (FR-019). KHÔNG có From Date/To Date — chỉ 1 trường Step (FR-015). Chặn gán trùng
> step cho cùng reference type (FR-017/SC-008) thay cho kiểm tra chồng lấn ngày.

---

### Phase 8: Setup (Update 1)

- [X] T041 Xác nhận bảng `eutr_reference_type_details` trên DB khớp thiết kế: đối chiếu
  `docs/design/eutr/eutr_db.sql` dòng 152-164 (cột `Id, StepId, TypeId, CreatedBy, CreatedDate,
  UpdatedBy, UpdatedDate` + FK `eutr_reference_type_details_typeid_foreign` từ `TypeId →
  eutr_reference_types.Id`, FK `eutr_reference_type_details_stepid_foreign` từ `StepId →
  eutr_steps.Id`). KHÔNG sửa schema.
- [X] T042 [P] Đọc mẫu backend tham chiếu để nắm convention (`003-eutr-templates`):
  `compliance-sys-api/src/ComplianceSys.Domain/Entities/EutrTemplateReferences.cs`,
  `ComplianceSys.Application/{Dtos/Request/EutrTemplateReferencesRequestDto.cs,
  Dtos/Response/EutrTemplateReferencesResponseDto.cs,
  Interfaces/Repositories/IEutrTemplateReferencesRepository.cs,
  Interfaces/Services/IEutrTemplateReferencesService.cs,
  Services/EutrTemplateReferencesService.cs,
  Validators/EutrTemplateReferencesRequestDtoValidator.cs}`,
  `ComplianceSys.Infrastructure/Repositories/EutrTemplateReferencesRepository.cs`,
  `ComplianceSys.Api/Controllers/EutrTemplateReferencesController.cs`.
- [X] T043 [P] Đọc mẫu frontend tham chiếu:
  `compliance-client/src/presentation/pages/eutr-templates/ApplyCustomerPage.jsx`,
  `application/usecases/eutr-template-references/`,
  `infrastructure/{api/eutrTemplateReferencesApi.js, repositories/RestEutrTemplateReferencesRepository.js}`,
  `app/routes/groups/MainRoutes.jsx` (route `/eutr/templates/apply/:id`); và mẫu tái sử dụng
  `application/usecases/eutr-step/GetEutrStepsUseCase.js` +
  `infrastructure/repositories/RestEutrStepRepository.js` (`repositories.eutrStep`, feature
  `001-eutr-steps`) cho combobox chọn Step.

---

### Phase 9: Foundational (Update 1 — nền tảng backend + frontend dùng chung cho US5)

**⚠️ CRITICAL**: US5 (Phase 10) không bắt đầu được trước khi phase này xong.

#### Backend — tạo mới toàn bộ

- [X] T044 [P] Tạo Domain entity
  `compliance-sys-api/src/ComplianceSys.Domain/Entities/EutrReferenceTypeDetails.cs` —
  `[Table("eutr_reference_type_details")]`, kế thừa `BaseEntity`, `[Key][Column("Id")] public long
  Id`, `public long TypeId`, `public long? StepId`. Clone cấu trúc từ `EutrTemplateReferences.cs`
  (bỏ `VendorCode/FromDate/ToDate`, đổi `TemplateId` → `TypeId`, thêm `StepId`).
- [X] T045 [P] Tạo
  `compliance-sys-api/src/ComplianceSys.Application/Dtos/Request/EutrReferenceTypeDetailsRequestDto.cs`
  — `public long TypeId`, `public long? StepId`.
- [X] T046 [P] Tạo
  `compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/EutrReferenceTypeDetailsResponseDto.cs`
  — `: EutrReferenceTypeDetails`, thêm `public string? StepName` (resolve bằng JOIN cục bộ tới
  `eutr_steps`, không qua D365).
- [X] T047 [P] Tạo
  `compliance-sys-api/src/ComplianceSys.Application/Validators/EutrReferenceTypeDetailsRequestDtoValidator.cs`
  — `: BaseValidator<EutrReferenceTypeDetailsRequestDto>`, `RuleFor(x => x.StepId).NotNull()`,
  `RuleFor(x => x.TypeId).GreaterThan(0)`.
- [X] T048 Tạo
  `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Repositories/IEutrReferenceTypeDetailsRepository.cs`
  — `: IRepository<EutrReferenceTypeDetails, long>`, thêm
  `Task<IEnumerable<EutrReferenceTypeDetailsResponseDto>> GetByTypeIdAsync(long typeId,
  CancellationToken ct = default)` và `Task<bool> HasStepAssignedAsync(long typeId, long stepId,
  long? excludeId, CancellationToken ct = default)` (phụ thuộc T044).
- [X] T049 Tạo
  `compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/EutrReferenceTypeDetailsRepository.cs`
  — `: DapperRepository<EutrReferenceTypeDetails, long>, IEutrReferenceTypeDetailsRepository`.
  `GetByTypeIdAsync`: `SELECT d.*, s.Name AS StepName FROM eutr_reference_type_details d LEFT JOIN
  eutr_steps s ON s.Id = d.StepId WHERE d.TypeId = @typeId ORDER BY d.CreatedDate DESC`.
  `HasStepAssignedAsync`: `SELECT COUNT(1) FROM eutr_reference_type_details WHERE TypeId = @typeId
  AND StepId = @stepId` (+ `AND Id <> @excludeId` khi có `excludeId`) (phụ thuộc T048).
- [X] T050 Tạo
  `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Services/IEutrReferenceTypeDetailsService.cs`
  — `: IBaseService<EutrReferenceTypeDetails, long, EutrReferenceTypeDetailsRequestDto>`, thêm
  `Task<IEnumerable<EutrReferenceTypeDetailsResponseDto>> GetByTypeIdAsync(long typeId,
  CancellationToken ct = default)` (phụ thuộc T044, T045, T046).
- [X] T051 Tạo
  `compliance-sys-api/src/ComplianceSys.Application/Services/EutrReferenceTypeDetailsService.cs` —
  `: BaseService<EutrReferenceTypeDetails, long, EutrReferenceTypeDetailsRequestDto>,
  IEutrReferenceTypeDetailsService`; override `AddAsync`/`UpdateAsync` gọi
  `_repository.HasStepAssignedAsync(...)` trước, ném `ValidationException("This step is already
  assigned to this reference type.")` nếu trùng (FR-017/SC-008); implement `GetByTypeIdAsync` gọi
  thẳng `_repository.GetByTypeIdAsync`. KHÔNG override `DeleteAsync` — hard delete mặc định của
  `BaseService` là đủ (không có bảng nào tham chiếu ngược tới `eutr_reference_type_details`) (phụ
  thuộc T049, T050).
- [X] T052 [P] Thêm 2 dòng `CreateMap` cho `EutrReferenceTypeDetails` vào
  `compliance-sys-api/src/ComplianceSys.Application/Mappings/EutrMappingProfile.cs` (file đã có,
  chỉ thêm block mới): `CreateMap<EutrReferenceTypeDetailsRequestDto,
  EutrReferenceTypeDetails>().ForMember(dest => dest.Id, opt => opt.Ignore()).IgnoreAuditable()`,
  `CreateMap<EutrReferenceTypeDetails, EutrReferenceTypeDetailsResponseDto>()` (phụ thuộc T044,
  T045, T046).
- [X] T053 Đăng ký DI: `compliance-sys-api/src/ComplianceSys.Application/DependencyInjection.cs`
  (SỬA, thêm 2 dòng) `services.AddScoped<IEutrReferenceTypeDetailsService,
  EutrReferenceTypeDetailsService>();`, `services.AddScoped<IValidator<EutrReferenceTypeDetailsRequestDto>,
  EutrReferenceTypeDetailsRequestDtoValidator>();`; và
  `compliance-sys-api/src/ComplianceSys.Infrastructure/DependencyInjection.cs` (SỬA, thêm 1 dòng)
  `services.AddScoped<IEutrReferenceTypeDetailsRepository, EutrReferenceTypeDetailsRepository>();`
  (phụ thuộc T047, T049, T051).
- [X] T054 Tạo
  `compliance-sys-api/src/ComplianceSys.Api/Controllers/EutrReferenceTypeDetailsController.cs` —
  `[Authorize][ApiController][Route("api/eutr-reference-type-details")]`; clone cấu trúc mỏng của
  `EutrTemplateReferencesController`, TÁI SỬ DỤNG policy `EutrReferenceTypes.*` (không tạo policy
  family riêng): `GET by-type/{typeId:long}` (policy `EutrReferenceTypes.ReadOne`), `POST` (policy
  `EutrReferenceTypes.Update`), `PUT {id:long}` (policy `EutrReferenceTypes.Update`), `DELETE
  {id:long}` (policy `EutrReferenceTypes.Delete`) (phụ thuộc T051, T053).

**Checkpoint backend**: `dotnet build` thành công; có thể gọi thử 4 endpoint qua Postman/Swagger
trước khi làm frontend.

#### Frontend — tạo mới toàn bộ

- [X] T055 [P] Tạo `compliance-client/src/domain/entities/EutrReferenceTypeDetails.js` — class
  `EutrReferenceTypeDetails` với `{ id, typeId, stepId, stepName, createdBy, createdDate, updatedBy,
  updatedDate }` (constructor nhận object).
- [X] T056 [P] Tạo
  `compliance-client/src/domain/interfaces/IEutrReferenceTypeDetailsRepository.js` — method
  `getByTypeId`, `create`, `update`, `delete` (throw 'Not implemented').
- [X] T057 [P] Tạo `compliance-client/src/infrastructure/api/eutrReferenceTypeDetailsApi.js` — base
  `/eutr-reference-type-details`; `getByTypeId(typeId)` → `GET
  /eutr-reference-type-details/by-type/{typeId}`, `create` POST, `update` PUT `/{id}`, `delete`
  DELETE `/{id}`.
- [X] T058 Tạo
  `compliance-client/src/infrastructure/repositories/RestEutrReferenceTypeDetailsRepository.js` —
  extends `IEutrReferenceTypeDetailsRepository`, gọi `eutrReferenceTypeDetailsApi`, bọc kết quả
  bằng `EutrReferenceTypeDetails` (phụ thuộc T056, T057).
- [X] T059 Đăng ký DI trong `compliance-client/src/di/repositories.js` (file đã có, chỉ thêm import
  + 1 dòng): import `RestEutrReferenceTypeDetailsRepository`, thêm `eutrReferenceTypeDetails: new
  RestEutrReferenceTypeDetailsRepository()` (phụ thuộc T058).
- [X] T060 [P] Tạo 4 use case trong
  `compliance-client/src/application/usecases/eutr-reference-type-details/`:
  `GetByTypeIdEutrReferenceTypeDetailsUseCase.js`, `CreateEutrReferenceTypeDetailsUseCase.js`,
  `UpdateEutrReferenceTypeDetailsUseCase.js`, `DeleteEutrReferenceTypeDetailsUseCase.js` (mỗi class
  nhận repo qua constructor, `execute(...)` gọi method tương ứng) (phụ thuộc T056).

**Checkpoint**: Toàn bộ tầng domain/infrastructure/application (backend + frontend) cho Assign Steps
sẵn sàng; API hoạt động được; UI có thể build trên đó.

---

### Phase 10: User Story 5 — Gán các bước (step) cho reference type (Priority: P2) 🎯

**Mục tiêu**: Icon Assign Steps trên danh sách reference type mở trang riêng quản lý các step đã
gán (Add/Edit/Delete), chặn gán trùng, không có Import/Export.
**Independent test**: Mở `/eutr/reference-types/assign-steps/:id`, Add 1 step → xuất hiện trong
bảng; Add lại đúng step đó → bị chặn trùng; Edit đổi sang step khác → cập nhật đúng; Delete → xác
nhận rồi biến mất; không thấy nút Import/Export trên toolbar.

- [X] T061 [US5] Tạo trang
  `compliance-client/src/presentation/pages/eutr-reference-types/AssignStepsPage.jsx` — trang độc
  lập (không phải modal trong `index.jsx`), theo cấu trúc `ApplyCustomerPage.jsx`: tải reference
  type theo `:id` (route param) qua `GetEutrReferenceTypesUseCase`/`getById` để lấy `Name` cho
  breadcrumb "EUTR > Reference Types > {Name} > Assign Steps"; tải danh sách step đã gán qua
  `GetByTypeIdEutrReferenceTypeDetailsUseCase`, hiển thị bảng cột **Step** (`stepName`) + **Action**
  (Edit, Delete); tải TOÀN BỘ danh sách `eutr_steps` một lần qua `GetEutrStepsUseCase`
  (`repositories.eutrStep`) làm `options` cho `Autocomplete` chọn Step; dialog Add/Edit inline CHỈ
  có 1 field Autocomplete Step (bắt buộc, `getOptionLabel={opt => opt?.name || ''}`); nút Save gọi
  `Create`/`UpdateEutrReferenceTypeDetailsUseCase` (kèm `typeId` từ route); validate trùng step
  client-side trước khi gọi API (đối chiếu danh sách đã tải, tương tự `hasOverlap()` của
  `ApplyCustomerPage.jsx`) hiển thị lỗi tại field Step; nút Delete dùng `ConfirmDialog` (nêu tên
  step) rồi gọi `DeleteEutrReferenceTypeDetailsUseCase`; toolbar KHÔNG có nút Import/Export; toàn
  bộ text tiếng Anh (breadcrumb, nút Add/Edit/Delete/Save/Cancel, tiêu đề dialog, label Step, thông
  báo lỗi/thành công, "No data", `ConfirmDialog`) (phụ thuộc T054, T059, T060). **Ghi chú
  implement**: `GetEutrReferenceTypesUseCase` hiện tại chỉ gọi `getAll()`, không có sẵn use case
  bọc `getById`; đã bổ sung thêm 1 file nhỏ
  `application/usecases/eutr-reference-types/GetByIdEutrReferenceTypesUseCase.js` (cùng thư mục,
  cùng convention 1-use-case-1-thao-tác) để tải reference type theo id cho breadcrumb, thay vì gọi
  thẳng `repositories.eutrReferenceTypes.getById()` từ trang (giữ đúng Nguyên tắc I — Presentation
  chỉ qua use case).
- [X] T062 [US5] Thêm route trong `compliance-client/src/app/routes/groups/MainRoutes.jsx`: lazy
  import `const AssignStepsPage = Loadable(lazy(() =>
  import('@presentation/pages/eutr-reference-types/AssignStepsPage')))` và route object `{ path:
  '/eutr/reference-types/assign-steps/:id', element: <AssignStepsPage /> }` trong mảng con đã bọc
  `PrivateRoute`. KHÔNG cần sửa `RouteResolver.jsx`/menu-items/seed menu mới (route con tĩnh, tái
  sử dụng quyền/menu cha `eutr-reference-types`) (phụ thuộc T061).
- [X] T063 [US5] Thêm icon **Assign Steps** vào
  `compliance-client/src/presentation/pages/eutr-reference-types/components/EutrReferenceTypesActionCell.jsx`
  (cạnh Edit/Delete hiện có), `onClick` điều hướng `navigate(\`/eutr/reference-types/assign-steps/${row.id}\`)`,
  gated theo cùng điều kiện quyền của Edit (`canEdit`) vì tái sử dụng policy
  `EutrReferenceTypes.Update` (phụ thuộc T062).

**Checkpoint**: US5 hoạt động end-to-end (Add/Edit/Delete step, chặn gán trùng, không
Import/Export, quyền đúng).

---

### Phase 11: Polish & Cross-cutting (Update 1)

- [X] T064 [P] Rà soát: toàn bộ văn bản hiển thị trên `AssignStepsPage` bằng tiếng Anh (breadcrumb,
  nút, tiêu đề dialog, label combobox Step, thông báo lỗi/thành công — kể cả thông báo "đã được
  gán", trạng thái rỗng "No data", `ConfirmDialog`) — FR-020. Comment code có thể giữ tiếng Việt.
- [X] T065 [P] Kiểm tra quyền: icon Assign Steps trên danh sách `index.jsx` và nút
  Add/Edit/Delete trên `AssignStepsPage` ẩn/disable đúng theo `permissionList` (dựa trên quyền
  `EutrReferenceTypes.Update/Delete/ReadOne` đã seed ở T021 — không cần seed quyền mới, FR-021).
- [X] T066 Chạy `dotnet build` trong `compliance-sys-api` — 0 lỗi biên dịch cho các file mới/sửa
  của Update 1.
- [X] T067 Chạy `npm run lint`/`npm run build` trong `compliance-client` và sửa cảnh báo của file
  mới.
- [ ] T068 Kiểm thử thủ công theo [quickstart.md](./quickstart.md) mục "Update 1 — Assign Steps" —
  7 kịch bản (8-14): mở màn hình, gán step mới, chặn gán trùng, sửa, xóa, xác nhận không có
  Import/Export, kiểm tra quyền. Yêu cầu backend chạy thật + có ít nhất 1-2 bản ghi `eutr_steps`.
  **CHƯA CHẠY** — không có dev server/backend đang chạy + DB seed trong phiên làm việc này (không
  tương tác/không có trình duyệt); `dotnet build` (T066) và `npm run lint`/`build` (T067) đều pass
  sạch. Khuyến nghị chạy thủ công 7 kịch bản trên trình duyệt thật trước khi coi feature này sẵn
  sàng production.

---

## Update 1 Dependencies & thứ tự

- **Phase 8** (Setup) → **Phase 9** (Foundational) là điều kiện tiên quyết của **Phase 10** (US5).
- Trong Phase 9 (backend): T044/T045/T046/T047 song song; T048 cần T044; T049 cần T048; T050 cần
  T044+T045; T051 cần T049+T050; T052 cần T044+T045+T046 (song song với T048-T051, khác file); T053
  cần T047+T049+T051; T054 cần T051+T053.
- Trong Phase 9 (frontend): T055/T056/T057 song song; T058 cần T056+T057; T059 cần T058; T060 cần
  T056 (song song với T058/T059, khác file).
- **Phase 10** (US5): T061 cần T054+T059+T060 (Foundational xong hoàn toàn); T062 cần T061; T063
  cần T062 (cùng liên quan routing/permission nên tuần tự).
- **Phase 11** (Polish) sau khi Phase 10 xong.

### Cơ hội song song (Update 1)

- Phase 8: `[P]` T042, T043 cùng lúc (T041 độc lập).
- Phase 9 backend: `[P]` T044, T045, T046, T047 cùng lúc; T052 có thể song song với T048-T051 (khác
  file).
- Phase 9 frontend: `[P]` T055, T056, T057 cùng lúc; T060 song song với T058/T059 (khác file, chỉ
  cần T056).
- Phase 11: `[P]` T064, T065 cùng lúc.

## Tổng quan (Update 1)

- Tổng task mới: **28** (T041–T068).
- Theo story: US5 = 3 (T061–T063).
- Setup = 3 (T041–T043), Foundational = 17 (T044–T060: 11 backend, 6 frontend), Polish = 5
  (T064–T068).
- Tổng cộng toàn bộ feature (gốc + Update 1): **68 task** (T001–T068).
