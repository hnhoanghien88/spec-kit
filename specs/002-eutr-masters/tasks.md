---
description: "Task list for EUTR Masters Management implementation"
---

# Tasks: EUTR Masters Management

**Input**: Design documents from `specs/002-eutr-masters/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/eutr-masters-api.md](./contracts/eutr-masters-api.md)

**Tests**: KHÔNG sinh task test tự động — dự án kiểm thử thủ công theo
[quickstart.md](./quickstart.md) (không có test tự động cho các trang CRUD).

**Organization**: Nhóm theo user story để triển khai & kiểm thử tăng dần. Vì đây là CRUD full-stack
clone (một controller, một service, một page), nhiều story **dùng chung file** → khuyến nghị làm
**tuần tự P1 → P2**; task `[P]` là các file độc lập có thể làm song song.

## Path Conventions

- Backend: `compliance-sys-api/src/...` (.NET 8, Clean Architecture, Dapper/MySQL)
- Frontend: `compliance-client/src/...` (React + Vite, layered)
- Mẫu tham chiếu: backend `EutrStep`; import `ComplMasterImportService`; frontend `eutr-steps` +
  UI import `compliance-master`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Chuẩn bị tiền đề dữ liệu và thư mục feature.

- [ ] T001 [P] Xác nhận bảng `eutr_master_documents` tồn tại trong DB theo `docs/design/eutr/eutr_db.sql` (cột Id, StepId, Prefix + audit; FK StepId→eutr_steps.Id); nếu chưa có thì tạo.
- [X] T002 [P] Tạo thư mục feature frontend: `compliance-client/src/presentation/pages/eutr-masters/` (kèm `components/`, `hooks/`) và `compliance-client/src/application/usecases/eutr-masters/`.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Bộ khung dùng chung mọi story (entity, DTO, service/controller skeleton, wiring FE).

**⚠️ CRITICAL**: Phải hoàn tất trước khi bắt đầu bất kỳ user story nào.

### Backend (clone mẫu EutrStep)

- [X] T003 [P] Tạo entity `compliance-sys-api/src/ComplianceSys.Domain/Entities/EutrMastersDocument.cs` (kế thừa `BaseEntity`, `[Table("eutr_master_documents")]`, `Id: long`, `StepId: long?`, `Prefix: string?`).
- [X] T004 [P] Tạo `compliance-sys-api/src/ComplianceSys.Application/Dtos/Request/EutrMastersRequestDto.cs` (`StepId`, `Prefix`).
- [X] T005 [P] Tạo `compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/EutrMastersResponseDto.cs` (kế thừa entity + `StepName: string`).
- [X] T006 [P] Tạo `compliance-sys-api/src/ComplianceSys.Application/Validators/EutrMastersRequestDtoValidator.cs` (`RuleFor(StepId).GreaterThan(0)`, `RuleFor(Prefix).NotEmpty()`), kế thừa `BaseValidator`.
- [X] T007 Thêm AutoMapper map trong `compliance-sys-api/src/ComplianceSys.Application/Mappings/EutrMappingProfile.cs`: `EutrMastersRequestDto→EutrMastersDocument` (Ignore Id, IgnoreAuditable), `EutrMastersDocument→EutrMastersResponseDto`.
- [X] T008 Tạo interface `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Services/IEutrMastersService.cs` (kế thừa `IBaseService<EutrMastersDocument,long,EutrMastersRequestDto>` + `Task<PagedResult<EutrMastersResponseDto>> GetPagedAsync(PagedRequest, CancellationToken)`).
- [X] T009 Tạo `compliance-sys-api/src/ComplianceSys.Application/Services/EutrMastersService.cs` kế thừa `BaseService<...>` (constructor DI: repository, unitOfWork, mapper, validator) — CRUD dùng base; để trống chỗ override GetPaged/Add/Update (bổ sung ở US1/US2/US3).
- [X] T010 Tạo `compliance-sys-api/src/ComplianceSys.Api/Controllers/EutrMastersController.cs` skeleton: `[Authorize]`, `[Route("api/eutr-masters")]`, DI `IEutrMastersService` (chưa thêm action — thêm dần theo story).
- [X] T011 Đăng ký DI trong `compliance-sys-api/src/ComplianceSys.Application/DependencyInjection.cs`: `IEutrMastersService→EutrMastersService` và `IValidator<EutrMastersRequestDto>→EutrMastersRequestDtoValidator`.

### Frontend (clone mẫu eutr-steps)

- [X] T012 [P] Tạo `compliance-client/src/domain/entities/EutrMasters.js` (`{ id, stepId, stepName, prefix, createdBy, createdDate, updatedBy, updatedDate }`).
- [X] T013 [P] Tạo `compliance-client/src/domain/interfaces/IEutrMastersRepository.js` (khai báo `getAllPaging/getById/create/update/delete/deleteMulti/import`).
- [X] T014 [P] Tạo `compliance-client/src/infrastructure/api/eutrMastersApi.js` base `/eutr-masters` (`getAllPaging`, `getById`, `create`, `update`, `delete`, `deleteMulti`; `import` thêm ở US5).
- [X] T015 Tạo `compliance-client/src/infrastructure/repositories/RestEutrMastersRepository.js` (kế thừa interface, map response → `EutrMasters`).
- [X] T016 Đăng ký `eutrMasters: new RestEutrMastersRepository()` trong `compliance-client/src/di/repositories.js`.
- [X] T017 Thêm lazy import + `componentMap["eutr-masters"]` trong `compliance-client/src/app/routes/RouteResolver.jsx`.
- [X] T018 Thêm menu item (code `eutr-masters`, title "EUTR masters", url `/eutr/masters`) dưới `eutr-system-parent` trong `compliance-client/src/presentation/menu-items/ComplianceSystem.jsx`.
- [X] T019 Tạo page shell `compliance-client/src/presentation/pages/eutr-masters/index.jsx` (breadcrumb "EUTR > Masters", container DataGrid + toolbar rỗng — nối logic theo story).

**Checkpoint**: App mở được `/eutr/masters` (grid rỗng), route + menu hoạt động.

---

## Phase 3: User Story 1 - Xem và tìm kiếm danh sách (Priority: P1) 🎯 MVP

**Goal**: Hiển thị bảng master (cột Step name = TÊN bước, Prefix, Created by/date), tìm theo tên
bước, phân trang server-side.

**Independent Test**: Mở `/eutr/masters` → thấy dữ liệu với cột Step name là tên bước; gõ tìm kiếm
→ lọc đúng; đổi trang → đúng trang.

- [X] T020 [US1] Override `GetPagedAsync` trong `compliance-sys-api/src/ComplianceSys.Application/Services/EutrMastersService.cs`: Dapper SQL JOIN `eutr_master_documents m LEFT JOIN eutr_steps s ON s.Id=m.StepId`, SELECT thêm `s.Name AS StepName`, hỗ trợ lọc `s.Name LIKE` (cột logic `StepName`), trả `PagedResult<EutrMastersResponseDto>` (research Quyết định 2).
- [X] T021 [US1] Thêm action `POST /get-all` (`[Authorize(Policy="EutrMasters.ReadAll")]`, query page/pageSize/sortColumn/sortOrder + body `List<FilterRequest>`) và `GET /get-by-id/{id}` (`EutrMasters.ReadOne`) trong `EutrMastersController.cs`.
- [X] T022 [P] [US1] Tạo `compliance-client/src/application/usecases/eutr-masters/GetPagingEutrMastersUseCase.js` (gọi `repository.getAllPaging`).
- [X] T023 [US1] Tạo hook `compliance-client/src/presentation/pages/eutr-masters/hooks/useEutrMastersData.js` (paginationModel/filterModel/sortModel + fetchData → GetPaging; đọc `items`/`totalCount`).
- [X] T024 [US1] Tạo hook `compliance-client/src/presentation/pages/eutr-masters/hooks/useEutrMastersColumns.jsx` (cột `stepName` "Step name" filterable, `prefix` "Prefix", `createdBy`, `createdDate`; ẩn id/stepId/updated*; chừa cột actions).
- [X] T025 [US1] Nối DataGrid server-mode vào `eutr-masters/index.jsx` (search theo Step name, phân trang, sort) dùng `useEutrMastersData` + `useEutrMastersColumns`; trạng thái rỗng "No data" (tiếng Anh).

**Checkpoint**: US1 chạy độc lập — xem + tìm kiếm + phân trang hoạt động (MVP).

---

## Phase 4: User Story 2 - Thêm master mới (Priority: P1)

**Goal**: Add qua modal: Select "Step name" (nạp từ danh mục bước) + nhập Prefix; chặn lưu khi
trùng cặp (StepId, Prefix).

**Independent Test**: Add → chọn bước + nhập prefix → Save → dòng mới hiện đúng tên bước; bỏ trống
step/prefix → báo lỗi; tạo trùng step+prefix → cảnh báo, không tạo.

- [X] T026 [US2] Override `AddAsync` trong `EutrMastersService.cs`: trước khi lưu, kiểm tra tồn tại cặp (StepId, Prefix); nếu trùng → ném lỗi nghiệp vụ message tiếng Anh ("A master with the same step and prefix already exists.") (research Quyết định 3).
- [X] T027 [US2] Thêm action `POST /` create (`[Authorize(Policy="EutrMasters.Create")]`, body `EutrMastersRequestDto`, lấy userEmail từ `HttpContext.Items["UserEmail"]`) trong `EutrMastersController.cs`.
- [X] T028 [P] [US2] Tạo `compliance-client/src/application/usecases/eutr-masters/CreateEutrMastersUseCase.js`.
- [X] T029 [US2] Tạo `compliance-client/src/presentation/pages/eutr-masters/components/EutrMastersModal.jsx`: **Select/Autocomplete "Step name"** nạp options từ `GetEutrStepsUseCase` (dùng lại repo `eutrStep` sẵn có; value=id, label=name) + TextField "Prefix"; validate bắt buộc chọn step + nhập prefix (thông báo tiếng Anh).
- [X] T030 [US2] Nối nút **Add** + mở modal + gọi Create + refresh grid + hiển thị **cảnh báo trùng** từ lỗi backend trong `eutr-masters/index.jsx`.

**Checkpoint**: US1 + US2 chạy độc lập.

---

## Phase 5: User Story 3 - Sửa master (Priority: P2)

**Goal**: Edit bước/prefix qua modal (prefill); chặn lưu khi trùng với bản ghi KHÁC.

**Independent Test**: Edit dòng → đổi step/prefix → Save → cập nhật; sửa thành trùng bản ghi khác →
cảnh báo, không lưu.

- [X] T031 [US3] Override `UpdateAsync` trong `EutrMastersService.cs`: kiểm tra trùng cặp (StepId, Prefix) **loại trừ chính Id đang sửa**; trùng → ném lỗi nghiệp vụ tiếng Anh (research Quyết định 3).
- [X] T032 [US3] Thêm action `PUT /{id}` update (`[Authorize(Policy="EutrMasters.Update")]`, body `EutrMastersRequestDto`) trong `EutrMastersController.cs`.
- [X] T033 [P] [US3] Tạo `compliance-client/src/application/usecases/eutr-masters/UpdateEutrMastersUseCase.js`.
- [X] T034 [US3] Tạo `compliance-client/src/presentation/pages/eutr-masters/components/EutrMastersActionCell.jsx` (nút Edit/Delete theo quyền).
- [X] T035 [US3] Mở rộng `EutrMastersModal.jsx` cho chế độ edit (prefill step+prefix qua getById) và nối luồng Edit (ActionCell → modal → Update → refresh + cảnh báo trùng) trong `eutr-masters/index.jsx`.

**Checkpoint**: US1–US3 chạy độc lập.

---

## Phase 6: User Story 4 - Xóa master + xóa nhiều (Priority: P2)

**Goal**: Xóa 1 dòng có xác nhận; xóa nhiều dòng đã chọn.

**Independent Test**: Delete 1 dòng → xác nhận → biến mất; chọn nhiều → xóa nhiều → biến mất; hủy
xác nhận → không xóa.

- [X] T036 [US4] Thêm action `DELETE /{id}` (`EutrMasters.Delete`) và `POST /delete-multi` (`EutrMasters.Delete`, body `IEnumerable<long> ids`) trong `EutrMastersController.cs`.
- [X] T037 [P] [US4] Tạo `compliance-client/src/application/usecases/eutr-masters/DeleteEutrMastersUseCase.js`.
- [X] T038 [P] [US4] Tạo `compliance-client/src/application/usecases/eutr-masters/DeleteMultiEutrMastersUseCase.js`.
- [X] T039 [US4] Nối hộp thoại xác nhận xóa (Delete ở ActionCell) + xóa nhiều theo checkbox selection + refresh grid trong `eutr-masters/index.jsx` (văn bản tiếng Anh).

**Checkpoint**: US1–US4 chạy độc lập.

---

## Phase 7: User Story 5 - Import từ Excel (Priority: P2)

**Goal**: Import file .xlsx 2 cột (Step name, Prefix), bỏ dòng tiêu đề, map tên bước→StepId, chống
trùng (DB + trong file), import một phần, báo cáo dòng lỗi.

**Independent Test**: Import file hợp lệ → tạo bản ghi đúng; dòng step không khớp → "Step not found";
dòng trùng → "Duplicate"; file sai định dạng → báo lỗi; dialog báo cáo success/fail/duplicate.

### Backend (clone mẫu ComplMasterImportService)

- [X] T040 [P] [US5] Tạo `compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/ImportEutrMastersResultDto.cs` (`TotalRows, SuccessCount, FailCount, DuplicateCount, Errors[], Duplicates[]` với item `{ RowNumber, StepName, Prefix, Reason }`).
- [X] T041 [P] [US5] Tạo interface `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Services/IEutrMastersImportService.cs` (`Task<ImportEutrMastersResultDto> ImportFromExcelAsync(Stream, string userEmail, CancellationToken)`).
- [X] T042 [US5] Tạo `compliance-sys-api/src/ComplianceSys.Application/Services/EutrMastersImportService.cs`: dùng ClosedXML mở `XLWorkbook`, đọc từ **dòng 2** (cột A=step name, B=prefix), map step name→StepId theo `eutr_steps.Name` (không phân biệt hoa/thường, trim), chống trùng (DB + nội bộ file), **import một phần**, trả `ImportEutrMastersResultDto` (research Quyết định 4).
- [X] T043 [US5] Đăng ký `IEutrMastersImportService→EutrMastersImportService` trong `compliance-sys-api/src/ComplianceSys.Application/DependencyInjection.cs`.
- [X] T044 [US5] Thêm action `POST /import` (`[Authorize(Policy="EutrMasters.Create")]`, tham số `IFormFile file`, validate đuôi .xlsx, lấy userEmail) trả `ApiResponse<ImportEutrMastersResultDto>` trong `EutrMastersController.cs`.

### Frontend (clone UI import compliance-master)

- [X] T045 [P] [US5] Tạo `compliance-client/src/application/usecases/eutr-masters/ImportEutrMastersUseCase.js`.
- [X] T046 [US5] Thêm `import(file)` (FormData multipart, field `file`, POST `/eutr-masters/import`) vào `eutrMastersApi.js`, `RestEutrMastersRepository.js` và khai báo ở `IEutrMastersRepository.js`.
- [X] T047 [P] [US5] Tạo `compliance-client/src/presentation/pages/eutr-masters/components/ImportResultDialog.jsx` (bảng success/fail/duplicate + danh sách dòng bị bỏ qua kèm lý do).
- [X] T048 [US5] Nối nút **Import** (input file ẩn) + gọi `ImportEutrMastersUseCase` + mở `ImportResultDialog` + refresh grid trong `eutr-masters/index.jsx`.

**Checkpoint**: Toàn bộ 5 user story hoạt động.

---

## Phase 8: User Story 6 - Export ra Excel (Priority: P2)

**Goal**: Nút Export tải về file .xlsx 2 cột (Step name, Prefix): luôn có dòng tiêu đề, có dữ liệu
thì kèm dòng dữ liệu, rỗng thì chỉ tiêu đề; định dạng khớp import (round-trip). Quyền riêng
`EutrMasters.Download`.

**Independent Test**: Nhấn Export → tải file có tiêu đề "Step name"/"Prefix" + dòng dữ liệu đúng;
danh sách rỗng → chỉ tiêu đề; dùng lại file để Import → xử lý được.

### Backend (clone mẫu ComplMasterExportService)

- [X] T054 [P] [US6] Tạo interface `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Services/IEutrMastersExportService.cs` (`Task<byte[]> ExportToExcelAsync(CancellationToken ct = default)`).
- [X] T055 [US6] Tạo `compliance-sys-api/src/ComplianceSys.Application/Services/EutrMastersExportService.cs`: dùng ClosedXML tạo workbook MỚI, ghi dòng 1 tiêu đề `Step name` (A), `Prefix` (B); lấy toàn bộ master qua `IEutrMastersRepository` (GetPagedWithStepNameAsync với pageSize lớn/lấy tất cả), ghi mỗi bản ghi 1 dòng (StepName, Prefix) từ dòng 2; rỗng → chỉ tiêu đề; trả `byte[]` (research Quyết định 7).
- [X] T056 [US6] Đăng ký `IEutrMastersExportService→EutrMastersExportService` trong `compliance-sys-api/src/ComplianceSys.Application/DependencyInjection.cs`.
- [X] T057 [US6] Thêm action `GET /export` (`[Authorize(Policy="EutrMasters.Download")]`) trả `File(bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "eutr-master-{yyyyMMddHHmmss}.xlsx")` trong `EutrMastersController.cs` (mẫu `ComplMasterController.ExportMasterMissing`).

### Frontend (clone UI export compliance-master)

- [X] T058 [P] [US6] Tạo `compliance-client/src/application/usecases/eutr-masters/ExportEutrMastersUseCase.js` (nhận blob → tạo object URL + thẻ `<a download>` kích hoạt tải; tên file lấy từ header `Content-Disposition` của server, fallback `eutr-master-{yyyyMMddHHmmss}.xlsx`).
- [X] T059 [US6] Thêm `export()` (GET `/eutr-masters/export`, `responseType: "blob"`) vào `eutrMastersApi.js`, `RestEutrMastersRepository.js` và khai báo ở `IEutrMastersRepository.js` (mẫu `complianceMasterApi.exportMaster`).
- [X] T060 [US6] Thêm nút **Export** vào toolbar `eutr-masters/index.jsx` (hiện theo `permissionList.includes("Download")`), gọi `ExportEutrMastersUseCase`, báo lỗi qua snackbar nếu thất bại.

**Checkpoint**: Toàn bộ 6 user story hoạt động.

---

## Phase 9: Polish & Cross-Cutting Concerns

- [X] T049 [P] Rà soát **toàn bộ văn bản UI bằng tiếng Anh** (FR-017): nhãn cột, nút (Import/Add/Edit/Delete/Save/Cancel), breadcrumb, Search, nhãn form, thông báo lỗi/thành công/cảnh báo trùng, báo cáo import, "No data", hộp xác nhận — trong `eutr-masters/index.jsx`, `EutrMastersModal.jsx`, `ImportResultDialog.jsx`, `useEutrMastersColumns.jsx`.
- [X] T050 [P] Xử lý lỗi & trạng thái: empty state, lỗi mạng/máy chủ (không thay đổi dữ liệu sai lệch), loading; step đã bị xóa → cột Step name hiển thị giá trị dự phòng.
- [X] T051 Gating quyền theo `permissionList` từ menu (code `eutr-masters`): ẩn/disable Add/Edit/Delete/Import khi thiếu quyền, trong `eutr-masters/index.jsx` + `EutrMastersActionCell.jsx`.
- [ ] T052 Chạy kiểm thử theo [quickstart.md](./quickstart.md) (9 kịch bản, gồm Export) và sửa lỗi phát sinh.

### Tiền đề vận hành/DB (KHÔNG phải task code)

- [ ] T053 [Ops] Tạo động trong DB: menu code `eutr-masters` (url `/eutr/masters`) + các quyền `EutrMasters.ReadAll/ReadOne/Create/Update/Delete/Download` (Download dùng cho Export) và gán cho role/user để màn hình truy cập được (routing backend-driven — research Quyết định 5). Xóa cache `localStorage['userMenu']` sau khi cập nhật.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (P1)**: bắt đầu ngay.
- **Foundational (P2)**: sau Setup — **BLOCK toàn bộ user story**.
- **US1 (P3)**: sau Foundational — MVP.
- **US2–US6**: sau Foundational; nên làm tuần tự sau US1 vì **chia sẻ file** `EutrMastersService.cs`,
  `EutrMastersController.cs`, `eutr-masters/index.jsx` (chỉnh sửa chồng lấn). US6 (Export) độc lập với
  US1–US5 về logic nhưng vẫn đụng `EutrMastersController.cs`, `index.jsx`, `DependencyInjection.cs`.
- **Polish (P9)**: sau khi các story mong muốn hoàn tất.

### Điểm chia sẻ file (tránh sửa song song)

- `EutrMastersService.cs`: T009 → T020 (US1) → T026 (US2) → T031 (US3).
- `EutrMastersController.cs`: T010 → T021 (US1) → T027 (US2) → T032 (US3) → T036 (US4) → T044 (US5) → T057 (US6).
- `eutr-masters/index.jsx`: T019 → T025 (US1) → T030 (US2) → T035 (US3) → T039 (US4) → T048 (US5) → T060 (US6).
- `DependencyInjection.cs`: T011 (Foundational) → T043 (US5) → T056 (US6).
- `eutrMastersApi.js` / `RestEutrMastersRepository.js` / `IEutrMastersRepository.js`: T014/T015/T013 (Foundational) → T046 (US5) → T059 (US6).

### Parallel Opportunities

- Setup: T001, T002 song song.
- Foundational backend `[P]`: T003, T004, T005, T006 song song; frontend `[P]`: T012, T013, T014 song song (T015 sau T013/T014; T016 sau T015).
- Use case `[P]` mỗi story (T022, T028, T033, T037, T038, T045) và DTO/interface import `[P]` (T040, T041), dialog `[P]` (T047) có thể làm song song với phần còn lại của story.

---

## Parallel Example: Foundational

```bash
# Backend DTO/entity/validator (khác file, không phụ thuộc):
Task: "T003 Entity EutrMastersDocument.cs"
Task: "T004 EutrMastersRequestDto.cs"
Task: "T005 EutrMastersResponseDto.cs"
Task: "T006 EutrMastersRequestDtoValidator.cs"

# Frontend domain/api (khác file):
Task: "T012 domain/entities/EutrMasters.js"
Task: "T013 domain/interfaces/IEutrMastersRepository.js"
Task: "T014 infrastructure/api/eutrMastersApi.js"
```

---

## Implementation Strategy

### MVP First (US1)

1. Phase 1 Setup → 2. Phase 2 Foundational → 3. Phase 3 US1 → **STOP & VALIDATE** (xem + tìm kiếm) →
demo.

### Incremental Delivery

Foundational → US1 (MVP: xem/tìm) → US2 (thêm + chống trùng) → US3 (sửa) → US4 (xóa/xóa nhiều) →
US5 (import) → Polish. Mỗi story test độc lập theo quickstart trước khi sang story kế.

### Lưu ý

- `[P]` = khác file, không phụ thuộc; các task cùng file phải tuần tự (xem "Điểm chia sẻ file").
- Không sinh test tự động (kiểm thử thủ công theo quickstart).
- Comment code **tiếng Việt**; văn bản UI **tiếng Anh** (Constitution IV + FR-017).
- T053 là bước cấu hình DB/vận hành, không phải lập trình.
