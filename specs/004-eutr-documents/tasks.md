---
description: "Task list for EUTR Documents Management implementation"
---

# Tasks: EUTR Documents Management

**Input**: Design documents from `specs/004-eutr-documents/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/eutr-documents-api.md](./contracts/eutr-documents-api.md)

**Tests**: KHÔNG sinh task test tự động — dự án kiểm thử thủ công theo
[quickstart.md](./quickstart.md) (không có test tự động cho các trang CRUD).

**Organization**: Nhóm theo user story để triển khai & kiểm thử tăng dần. Vì đây là CRUD full-stack
clone (một controller, một service, một page), nhiều story **dùng chung file** → khuyến nghị làm
**tuần tự P1 → P2 → P3**; task `[P]` là các file độc lập có thể làm song song.

## Path Conventions

- Backend: `compliance-sys-api/src/...` (.NET 8, Clean Architecture, Dapper/MySQL)
- Frontend: `compliance-client/src/...` (React + Vite, layered)
- Mẫu tham chiếu: backend `EutrStep` (đơn giản nhất — không JOIN, không repository riêng); frontend
  list + popup Edit clone `eutr-masters`; routing trang Add riêng mượn wiring `eutr-templates`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Chuẩn bị migration DB và thư mục feature.

- [X] T001 [P] Tạo migration `compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Migration/09_migrate_eutr_documents_name.sql`: `ALTER TABLE eutr_documents MODIFY COLUMN Name VARCHAR(255) NULL;` (theo convention `NN_migrate_*.sql` đã dùng ở feature 003; research Quyết định 3).
- [X] T002 [P] Cập nhật `docs/design/eutr/eutr_db.sql` và `compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Tables/eutr_db.sql`: đổi cột `Name` của bảng `eutr_documents` từ `BIGINT NULL` sang `VARCHAR(255) NULL` để tài liệu thiết kế khớp với migration.
- [X] T003 [P] Tạo thư mục feature frontend: `compliance-client/src/presentation/pages/eutr-documents/` (kèm `components/`, `hooks/`) và `compliance-client/src/application/usecases/eutr-documents/`.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Bộ khung dùng chung mọi story (entity, DTO, service/controller skeleton, wiring FE).

**⚠️ CRITICAL**: Phải hoàn tất trước khi bắt đầu bất kỳ user story nào.

### Backend (clone mẫu EutrStep — không JOIN, không repository riêng)

- [X] T004 [P] Tạo entity `compliance-sys-api/src/ComplianceSys.Domain/Entities/EutrDocuments.cs` (kế thừa `BaseEntity`, `[Table("eutr_documents")]`, `Id: long`, `Name: string?`, `FileId: string?`, `ValidFrom: DateTime?`, `ValidTo: DateTime?`).
- [X] T005 [P] Tạo `compliance-sys-api/src/ComplianceSys.Application/Dtos/Request/EutrDocumentsRequestDto.cs` (`{ Name, ValidFrom, ValidTo }` — KHÔNG có `FileId`, chưa có upload file).
- [X] T006 [P] Tạo `compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/EutrDocumentsResponseDto.cs` (kế thừa entity, subclass trống — mẫu `EutrStepResponseDto`, không JOIN).
- [X] T007 [P] Tạo `compliance-sys-api/src/ComplianceSys.Application/Validators/EutrDocumentsRequestDtoValidator.cs` (`RuleFor(x => x.Name).NotEmpty()`, kế thừa `BaseValidator<EutrDocumentsRequestDto>`; `ValidFrom`/`ValidTo` không có rule — tùy chọn).
- [X] T008 Thêm AutoMapper map trong `compliance-sys-api/src/ComplianceSys.Application/Mappings/EutrMappingProfile.cs`: `CreateMap<EutrDocumentsRequestDto, EutrDocuments>().ForMember(dest => dest.Id, opt => opt.Ignore()).IgnoreAuditable();`, `CreateMap<EutrDocuments, EutrDocumentsRequestDto>();`, `CreateMap<EutrDocuments, EutrDocumentsResponseDto>();`.
- [X] T009 Tạo interface `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Services/IEutrDocumentsService.cs` (kế thừa `IBaseService<EutrDocuments,long,EutrDocumentsRequestDto>` + `Task<PagedResult<EutrDocumentsResponseDto>> GetPagedAsync(PagedRequest, CancellationToken)`).
- [X] T010 Tạo `compliance-sys-api/src/ComplianceSys.Application/Services/EutrDocumentsService.cs` kế thừa `BaseService<EutrDocuments,long,EutrDocumentsRequestDto>` (constructor DI: `IRepository<EutrDocuments,long>` generic — **KHÔNG tạo repository riêng**, `unitOfWork`, `mapper`, `validator`); `GetPagedAsync` gọi `base.GetPagedAsync` rồi `_mapper.Map<List<EutrDocumentsResponseDto>>(...)` (mẫu `EutrStepService`, KHÔNG override `AddAsync`/`UpdateAsync` — không có chống trùng, FR-007b).
- [X] T011 Tạo `compliance-sys-api/src/ComplianceSys.Api/Controllers/EutrDocumentsController.cs` skeleton: `[Authorize]`, `[Route("api/eutr-documents")]`, DI `IEutrDocumentsService` (chưa thêm action — thêm dần theo story).
- [X] T012 Đăng ký DI trong `compliance-sys-api/src/ComplianceSys.Application/DependencyInjection.cs`: `IEutrDocumentsService→EutrDocumentsService` và `IValidator<EutrDocumentsRequestDto>→EutrDocumentsRequestDtoValidator` (KHÔNG cần sửa Infrastructure DI — `IRepository<,>` đã đăng ký open-generic sẵn cho mọi entity).

### Frontend (clone mẫu eutr-masters cho list/Edit-popup + wiring routing eutr-templates cho Add)

- [X] T013 [P] Tạo `compliance-client/src/domain/entities/EutrDocuments.js` (`{ id, name, fileId, validFrom, validTo, createdBy, createdDate, updatedBy, updatedDate }`).
- [X] T014 [P] Tạo `compliance-client/src/domain/interfaces/IEutrDocumentsRepository.js` (khai báo `getAllPaging/getById/create/update/delete/deleteMulti`).
- [X] T015 [P] Tạo `compliance-client/src/infrastructure/api/eutrDocumentsApi.js` base `/eutr-documents` (`getAllPaging`, `getById`, `create`, `update`, `delete`, `deleteMulti` — mẫu `eutrMastersApi.js`, bỏ `import`/`export`).
- [X] T016 Tạo `compliance-client/src/infrastructure/repositories/RestEutrDocumentsRepository.js` (kế thừa interface, map response → `EutrDocuments`).
- [X] T017 Đăng ký `eutrDocuments: new RestEutrDocumentsRepository()` trong `compliance-client/src/di/repositories.js`.
- [X] T018 Thêm lazy import + `componentMap["eutr-documents"]` (trang list) trong `compliance-client/src/app/routes/RouteResolver.jsx`.
- [X] T019 Thêm route riêng `path: "/eutr/documents/add"` → `EutrDocumentsAdd` (lazy import) trong `compliance-client/src/app/routes/groups/MainRoutes.jsx` (mẫu wiring `/eutr/templates/add`; KHÔNG thêm route edit — Edit là popup).
- [X] T020 Thêm menu item (code `eutr-documents`, title "EUTR documents", url `/eutr/documents`) dưới `eutr-system-parent` trong `compliance-client/src/presentation/menu-items/ComplianceSystem.jsx`.
- [X] T021 Tạo page shell `compliance-client/src/presentation/pages/eutr-documents/index.jsx` (breadcrumb "EUTR > EUTR documents", container DataGrid + toolbar rỗng — nối logic theo story).

**Checkpoint**: App mở được `/eutr/documents` (grid rỗng), route + menu hoạt động.

---

## Phase 3: User Story 1 - Xem danh sách EUTR documents (Priority: P1) 🎯 MVP

**Goal**: Hiển thị bảng (File name, Valid from, Valid to, Created by, Created date + 3 cột **luôn
trống** Step name/Conditions/Type), phân trang server-side.

**Independent Test**: Mở `/eutr/documents` → thấy dữ liệu với File name/Valid from/Valid to/Created
by/Created date đúng; cột Step name/Conditions/Type luôn trống; đổi trang → đúng trang; danh sách
rỗng → "No data".

- [X] T022 [US1] Thêm action `POST /get-all` (`[Authorize(Policy="EutrDocuments.ReadAll")]`, query page/pageSize/sortColumn/sortOrder + body `List<FilterRequest>`, gọi `_eutrDocumentsService.GetPagedAsync`) và `GET /get-by-id/{id:long}` (`EutrDocuments.ReadOne`) trong `EutrDocumentsController.cs`.
- [X] T023 [P] [US1] Tạo `compliance-client/src/application/usecases/eutr-documents/GetPagingEutrDocumentsUseCase.js` (gọi `repository.getAllPaging`).
- [X] T024 [US1] Tạo hook `compliance-client/src/presentation/pages/eutr-documents/hooks/useEutrDocumentsData.js` (paginationModel/filterModel/sortModel + fetchData → GetPaging; đọc `items`/`totalCount`; mẫu `useEutrMastersData.js`).
- [X] T025 [US1] Tạo hook `compliance-client/src/presentation/pages/eutr-documents/hooks/useEutrDocumentsColumns.jsx`: cột `name` ("File name"), `stepName` ("Step name"), `conditions` ("Conditions"), `type` ("Type") — **3 cột sau KHÔNG gán field nào tồn tại trên entity** → MUI DataGrid tự hiển thị trống (FR-003, research Quyết định 5), `validFrom`/`validTo` (format ngày), `createdBy`, `createdDate`; chừa cột `actions`.
- [X] T026 [US1] Nối DataGrid server-mode vào `eutr-documents/index.jsx` (phân trang, sort) dùng `useEutrDocumentsData` + `useEutrDocumentsColumns`; breadcrumb "EUTR > EUTR documents"; trạng thái rỗng "No data" (tiếng Anh).

**Checkpoint**: US1 chạy độc lập — xem danh sách hoạt động (MVP).

---

## Phase 4: User Story 2 - Thêm document mới (Priority: P1)

**Goal**: Trang riêng `/eutr/documents/add` — File name (bắt buộc) + Valid from/Valid to (tùy
chọn) + nút Save + nút Back. **KHÔNG có control chọn/upload file** ở phạm vi này (FR-006).

**Independent Test**: Nhấn Add → điều hướng sang trang riêng (không popup, không ô chọn file) →
nhập File name + valid from/to → Save → quay về danh sách, dòng mới hiện đúng; để trống File name →
báo lỗi, không tạo; nhấn Back (chưa Save) → về danh sách ngay, không tạo bản ghi, không cảnh báo.

- [X] T027 [US2] Thêm action `POST /` create (`[Authorize(Policy="EutrDocuments.Create")]`, body `EutrDocumentsRequestDto`, lấy `userEmail` từ `HttpContext.Items["UserEmail"]`, gọi `_eutrDocumentsService.AddAsync`) trong `EutrDocumentsController.cs`.
- [X] T028 [P] [US2] Tạo `compliance-client/src/application/usecases/eutr-documents/CreateEutrDocumentsUseCase.js`.
- [X] T029 [US2] Tạo trang `compliance-client/src/presentation/pages/eutr-documents/EutrDocumentsAdd.jsx`: breadcrumb "EUTR > EUTR documents > Add"; `TextField` "File name" (bắt buộc, hiển thị lỗi khi trống), 2 `TextField type="date"` Valid from/Valid to (tùy chọn); nút **Save** (validate → gọi `CreateEutrDocumentsUseCase` → `navigate('/eutr/documents')`); nút **Back** (`navigate('/eutr/documents')` thẳng, **KHÔNG dirty-check/confirm dialog** — Edge Case đã chốt, form đơn giản) — mẫu wiring `EutrTemplatesAddEdit.jsx` (`useNavigate`, layout Card) đơn giản hoá tối đa, bỏ toàn bộ phần cây bước.
- [X] T030 [US2] Nối nút **Add** trên toolbar `eutr-documents/index.jsx` để `navigate('/eutr/documents/add')` (mẫu nút Add của `eutr-templates/index.jsx` — **KHÔNG** mở modal như `eutr-masters`).

**Checkpoint**: US1 + US2 chạy độc lập.

---

## Phase 5: User Story 3 - Sửa thông tin document (Priority: P2)

**Goal**: Edit qua **popup** (File name, Valid from, Valid to) — không đổi được file (chưa có file
thật để đổi).

**Independent Test**: Edit dòng → đổi File name và/hoặc Valid from/to → Save → cập nhật trong bảng;
để trống File name → báo lỗi, không lưu; nhấn Cancel → đóng popup, không đổi gì.

- [X] T031 [US3] Thêm action `PUT /{id:long}` update (`[Authorize(Policy="EutrDocuments.Update")]`, body `EutrDocumentsRequestDto`, gọi `_eutrDocumentsService.UpdateAsync`) trong `EutrDocumentsController.cs`.
- [X] T032 [P] [US3] Tạo `compliance-client/src/application/usecases/eutr-documents/UpdateEutrDocumentsUseCase.js`.
- [X] T033 [US3] Tạo `compliance-client/src/presentation/pages/eutr-documents/components/EutrDocumentsModal.jsx` (popup Edit, `Dialog maxWidth="xs" fullWidth`): `TextField` "File name" (bắt buộc) + 2 `TextField type="date"` Valid from/Valid to; nút Cancel + Save — mẫu `EutrMastersModal.jsx`, thay Autocomplete Step + TextField Prefix bằng 3 field này.
- [X] T034 [US3] Tạo `compliance-client/src/presentation/pages/eutr-documents/components/EutrDocumentsActionCell.jsx`: icon **Edit** + **Delete** theo quyền (mẫu `EutrMastersActionCell.jsx`) — icon **View** thêm ở US5.
- [X] T035 [US3] Nối luồng Edit (`EutrDocumentsActionCell` → mở `EutrDocumentsModal` với dữ liệu dòng → `UpdateEutrDocumentsUseCase` → refresh grid) trong `eutr-documents/index.jsx`.

**Checkpoint**: US1–US3 chạy độc lập.

---

## Phase 6: User Story 4 - Xóa document (Priority: P2)

**Goal**: Delete 1 dòng có xác nhận (hard delete — schema `eutr_documents` không có cờ soft-delete);
hỗ trợ xóa nhiều dòng đã chọn.

**Independent Test**: Delete 1 dòng → xác nhận → dòng biến mất; chọn nhiều dòng → xóa nhiều → tất cả
biến mất; hủy ở hộp xác nhận → không xóa dòng nào.

- [X] T036 [US4] Thêm action `DELETE /{id:long}` (`[Authorize(Policy="EutrDocuments.Delete")]`, gọi `_eutrDocumentsService.DeleteAsync`) và `POST /delete-multi` (`EutrDocuments.Delete`, body `IEnumerable<long> ids`, gọi `_eutrDocumentsService.DeleteMultiAsync`) trong `EutrDocumentsController.cs`.
- [X] T037 [P] [US4] Tạo `compliance-client/src/application/usecases/eutr-documents/DeleteEutrDocumentsUseCase.js`.
- [X] T038 [P] [US4] Tạo `compliance-client/src/application/usecases/eutr-documents/DeleteMultiEutrDocumentsUseCase.js`.
- [X] T039 [US4] Nối hộp thoại xác nhận xóa (Delete ở `EutrDocumentsActionCell`) + xóa nhiều theo checkbox selection (toolbar) + refresh grid trong `eutr-documents/index.jsx` (văn bản tiếng Anh, mẫu `eutr-masters/index.jsx`).

**Checkpoint**: US1–US4 chạy độc lập.

---

## Phase 7: User Story 5 - Icon View trên cột Action (placeholder, chưa xử lý) (Priority: P3)

**Goal**: Icon **View** trên cột Action, hiển thị **active bình thường** như Edit/Delete (không mờ/
disable), click **không kích hoạt hành động nào** (silent no-op).

**Independent Test**: Mở danh sách → thấy icon View cạnh Edit/Delete với giao diện active bình
thường; nhấn vào icon → không điều hướng, không mở popup, không có request nào gửi lên server
(kiểm tra tab Network).

- [X] T040 [US5] Thêm `IconButton` thứ 3 dùng `VisibilityIcon` (từ `@mui/icons-material`) vào `EutrDocumentsActionCell.jsx`, cùng `size="small"` như Edit/Delete, `onClick={() => {}}` (no-op tuyệt đối — không gọi callback, không điều hướng, không gọi API) (research Quyết định 6).

**Checkpoint**: Toàn bộ 5 user story hoạt động.

---

## Phase 8: Polish & Cross-Cutting Concerns

- [X] T041 [P] Rà soát **toàn bộ văn bản UI bằng tiếng Anh** (FR-015): nhãn cột, nút (Add, Edit,
  Delete, View, Save, Back, Cancel), breadcrumb, thông báo lỗi/thành công, trạng thái rỗng "No
  data", hộp thoại xác nhận xóa — trong `eutr-documents/index.jsx`, `EutrDocumentsAdd.jsx`,
  `EutrDocumentsModal.jsx`, `useEutrDocumentsColumns.jsx`.
- [X] T042 [P] Xử lý lỗi & trạng thái: empty state, lỗi mạng/máy chủ (không thay đổi dữ liệu sai
  lệch), loading indicator trên grid và trên nút Save.
- [X] T043 Gating quyền theo `permissionList` từ menu (code `eutr-documents`): ẩn/disable nút Add
  (toolbar), Edit/Delete (`EutrDocumentsActionCell`) khi thiếu quyền tương ứng, trong
  `eutr-documents/index.jsx` + `EutrDocumentsActionCell.jsx`.
- [ ] T044 Chạy kiểm thử theo [quickstart.md](./quickstart.md) (kịch bản 1-8) và sửa lỗi phát sinh.
  **Đã xác minh tĩnh**: `dotnet build ComplianceSys.sln` (0 lỗi), `npx eslint` trên toàn bộ file mới
  (0 lỗi), `npx vite build` (thành công, module `EutrDocumentsAdd` build đúng). **CHƯA chạy** 8 kịch
  bản thủ công trong trình duyệt — cần hoàn tất T045/T046 (migration DB + seed menu/quyền) trước.
  Kịch bản 9-11 (Type/List PO/Manual, thêm ở Update 3) được kiểm thử riêng ở T052.

### Tiền đề vận hành/DB (KHÔNG phải task code)

- [ ] T045 [Ops] Chạy migration `09_migrate_eutr_documents_name.sql` (T001) trên DB thật trước khi
  kiểm thử Create/Update (nếu không chạy, ghi `Name` dạng văn bản sẽ lỗi vì cột còn là BIGINT).
- [ ] T046 [Ops] Tạo động trong DB: menu code `eutr-documents` (url `/eutr/documents`, parent
  "EUTR" để breadcrumb hiển thị đúng "EUTR > EUTR documents" theo FR-002) + các quyền
  `EutrDocuments.ReadAll/ReadOne/Create/Update/Delete`, gán cho role/user để màn hình truy cập
  được (routing backend-driven — research Quyết định 7). Xóa cache `localStorage['userMenu']` sau
  khi cập nhật.

---

## Phase 9: Update 3 - Chỉnh giao diện trang Add theo thiết kế (Type/List PO/Upload manual, chỉ giao diện)

**Goal**: Bổ sung vào `EutrDocumentsAdd.jsx` (đã tồn tại từ Phase 4) trường **Type**
(`Autocomplete` tái sử dụng hằng số có sẵn `TAKE_FROM_OPTIONS` — "PO"/"Upload manual", mặc định
"PO") và 2 layout tĩnh theo `docs/design/eutr/eutr_documents_overview.md` (Screen1 khi Type=PO,
Screen2 khi Type=Upload manual), ở phạm vi **chỉ giao diện** — dữ liệu mẫu hard-code, mọi tương tác
mới (kéo-thả, Assign condition, View/Delete/checkbox demo) là **no-op** (spec FR-016 đến FR-020,
research Quyết định 8). File name/Valid from/Valid to/Save/Back hiện có **không đổi**.

**Independent Test**: Mở trang Add → thấy Type mặc định "PO"; Type=PO hiển thị bảng List PO
(8 dòng demo) + khu "Drag and drop files to upload"; đổi Type="Upload manual" → hiển thị khu upload
+ nút "Assign condition" + bảng file (8 dòng demo, có checkbox); kéo-thả file/nhấn Assign condition/
View/Delete/checkbox trong các khu này → không có request nào trong tab Network, không điều hướng/
popup nào mở ra; nhập File name + Save vẫn tạo document bình thường như trước (không phụ thuộc
Type). **Đã xác minh tĩnh** (T047-T051): `npx eslint` 0 lỗi, `npx vite build` thành công.

- [X] T047 [US2] Thêm state `takeFrom` (`useState(TAKE_FROM_OPTIONS[0].value)`) và `<Autocomplete>`
  MUI "Type" vào `compliance-client/src/presentation/pages/eutr-documents/EutrDocumentsAdd.jsx` —
  **tái sử dụng hằng số có sẵn `TAKE_FROM_OPTIONS`** từ `@utils/helpers`
  (`[{ value: 0, label: 'PO' }, { value: 1, label: 'Upload manual' }]`, đã dùng ở
  `eutr-templates/components/StepFormRow.jsx`/`StepTree.jsx`) thay vì hard-code "PO"/"Manual" —
  mẫu `Autocomplete disableClearable` giống hệt `StepFormRow.jsx` (KHÔNG dùng `Select` như dự kiến
  ban đầu ở research, vì đây khớp đúng Nguyên tắc II — phát hiện trong lúc implement rằng chuỗi
  "TAKE_FROM_OPTIONS" trong mockup tham chiếu chính xác hằng số này); trường này không gửi lên
  `CreateEutrDocumentsUseCase` (FR-016).
- [X] T048 [P] [US2] Khai báo 2 hằng số dữ liệu demo tĩnh trong `EutrDocumentsAdd.jsx`:
  `DEMO_PO_LIST` (8 phần tử `{ poName: "PO1".."PO8", fileName: "File PO1-1".."PO1-8" }`) và
  `DEMO_FILE_LIST` (8 phần tử `{ fileName: "File 1".."File 8" }`) — hằng số component, không qua
  use case/API (FR-017, FR-018).
- [X] T049 [US2] Render block Screen1 trong `EutrDocumentsAdd.jsx` khi `takeFrom === TAKE_FROM_OPTIONS[0].value`
  (PO): bảng **List PO** (cột "PO name", "File name", "Action" với icon View/Delete
  `onClick={() => {}}` no-op) dùng `DEMO_PO_LIST`, cùng khu vực **"Drag and drop files to upload"**
  (`Box` viền nét đứt `1px dashed #ccc` — mẫu style của `MapDataDialog.jsx`,
  `onDragOver={(e) => e.preventDefault()}`, `onDrop={(e) => e.preventDefault()}` — không đọc
  `dataTransfer`) (FR-017, FR-019).
- [X] T050 [US2] Render block Screen2 trong `EutrDocumentsAdd.jsx` khi `takeFrom` là giá trị còn lại
  (Manual/"Upload manual"): khu vực "Drag and drop files to upload" (cùng cặp handler no-op như
  T049) ở trên cùng, nút **"Assign condition"** (`onClick={() => {}}` no-op), và bảng file
  (`Checkbox` không kiểm soát state — chỉ toggle UI mặc định của trình duyệt, không lưu/gửi đi gì,
  cột "File name", "Action" với icon View/Delete no-op) dùng `DEMO_FILE_LIST` (FR-018, FR-019).
- [X] T051 [P] [US2] Rà soát **toàn bộ văn bản mới bằng tiếng Anh** (FR-015): "Type", "PO",
  "Upload manual", "PO name", "List PO", "Drag and drop files to upload", "Assign condition", "File
  name", "Action" — trong `EutrDocumentsAdd.jsx`. **Đã xác minh**: `npx eslint` (0 lỗi), `npx vite
  build` (thành công, chunk `EutrDocumentsAdd` build đúng).
- [ ] T052 [US2] Kiểm thử thủ công theo [quickstart.md](./quickstart.md) kịch bản 9-11 (Type mặc
  định "PO", chuyển đổi Type hiển thị đúng layout/dữ liệu demo, mọi tương tác trong khu vực mới
  không phát sinh request nào trong tab Network DevTools, Save vẫn hoạt động bình thường không phụ
  thuộc Type) trong `compliance-client/src/presentation/pages/eutr-documents/EutrDocumentsAdd.jsx`.
  **CHƯA chạy trong trình duyệt** — cần backend + DB (T045/T046) sẵn sàng, cùng điều kiện với T044.

**Checkpoint**: Trang Add hiển thị đúng giao diện theo thiết kế; hành vi CRUD hiện có (US1-US5)
không bị ảnh hưởng.

---

## Phase 10: Update 4 - List PO nối dữ liệu PO thật qua API reference dùng chung (refType 15/16)

**Goal**: Cột **PO name** trong bảng List PO (Screen1, `EutrDocumentsAdd.jsx`, Type = PO) lấy dữ
liệu thật từ D365 `RSVNEutrPurchOrders` bằng cách đăng ký `refType = 15` vào endpoint **dùng chung
đã có sẵn** `POST /api/dynamics/reference` (KHÔNG tạo endpoint mới). `RSVNEutrSalesOrderPurchases`
(`refType = 16`) cũng được đăng ký ở backend cho một tính năng sau nhưng KHÔNG có UI nào gọi tới
trong feature này (spec FR-021/FR-022, research Quyết định 9). Domain model D365 của cả 2 entity
**đã tồn tại sẵn trong repo** (`RSVNEutrPurchOrders.cs` = `ModelType 15`,
`RSVNEutrSalesOrderPurchases.cs` = `ModelType 16`) — không cần tạo file domain model mới.

**Independent Test**: Mở trang Add, chọn Type = "PO" → tab Network có request
`POST /api/dynamics/reference?...&refType=15` → cột **PO name** trong List PO hiển thị đúng dữ liệu
trả về (không còn `DEMO_PO_LIST`); cột File name vẫn trống, Action View/Delete vẫn no-op. Khi API
trả rỗng → bảng hiển thị "No data"; khi API lỗi → hiển thị thông báo lỗi, các trường/nút khác trên
trang Add vẫn hoạt động. Gọi trực tiếp `POST /api/dynamics/reference` với `refType = 16` (Postman/
DevTools) → trả về đúng dữ liệu `RSVNEutrSalesOrderPurchases`; xác nhận không có request nào với
`refType=16` phát sinh khi thao tác toàn bộ trang Add.

### Backend (`ComplDynamicsService.cs` — mở rộng bảng ánh xạ có sẵn, không route/DTO/entity mới)

- [X] T053 [US2] Thêm 2 dòng vào `EntityMappings` trong
  `compliance-sys-api/src/ComplianceSys.Application/Services/ComplDynamicsService.cs`:
  `{ 15, ("RSVNEutrPurchOrders", "PurchId", "Name") }` và
  `{ 16, ("RSVNEutrSalesOrderPurchases", "RSVNRefPurchId", "Name") }` (theo đúng mẫu dòng `{ 14,
  ("VendorsV3", "VendorAccountNumber", "VendorOrganizationName") }` đã có).
- [X] T054 [US2] Thêm `case 15` vào `MapDynamicsResponse` trong cùng file
  `ComplDynamicsService.cs`: `items.ToObject<List<RSVNEutrPurchOrders>>()?.Select(x => new
  ComplDynReferenceResponseDto { Id = x.PurchId, Code = x.PurchId, Name = x.Name }).ToList() ??
  new();` (mẫu `case 14`/VendorsV3; phải sau T053 vì cùng file).
- [X] T055 [US2] Thêm `case 16` vào `MapDynamicsResponse` trong cùng file `ComplDynamicsService.cs`:
  `items.ToObject<List<RSVNEutrSalesOrderPurchases>>()?.Select(x => new ComplDynReferenceResponseDto
  { Id = x.RSVNRefPurchId, Code = x.RSVNRefPurchId, Name = x.Name }).ToList() ?? new();` (cùng file,
  sau T054).
- [X] T056 [P] [US2] (Khuyến nghị, không bắt buộc) Thêm 2 giá trị vào enum `ObjectType` trong
  `compliance-sys-api/src/ComplianceSys.Application/Constants/ComplEnum.cs`:
  `[Description("Eutr Purch Order")] EUTR_PURCH_ORDER = 15,` và `[Description("Eutr Sales Order
  Purchase")] EUTR_SALES_ORDER_PURCHASE = 16,` (theo mẫu các giá trị khác trong enum — không cần
  nhánh xử lý riêng như `CUSTOMER`/`VENDOR`, chỉ để đọc code rõ ràng hơn; khác file với T053-T055
  nên có thể làm song song).

### Frontend (`EutrDocumentsAdd.jsx` — tái dùng hook generic có sẵn, không tạo hook/component mới)

- [X] T057 [US2] Trong `compliance-client/src/presentation/pages/eutr-documents/EutrDocumentsAdd.jsx`,
  thay nguồn dữ liệu cột **PO name** của bảng List PO: import và gọi
  `useReferenceObjects()` (từ `@presentation/hooks/useReferenceObjects`, đã dùng ở
  `ReferenceObjectAutocomplete.jsx`) với `fetchReferenceObjects(15)` khi Type = PO được chọn/khi
  trang mount ở Type mặc định "PO"; render danh sách `referenceObjects` (`{ id, code, name }`) vào
  cột "PO name" bằng `name` — **xoá** hằng số `DEMO_PO_LIST` khỏi cột này. Cột **File name** trên
  mỗi dòng vẫn hiển thị trống (không đổi), Action View/Delete trên mỗi dòng vẫn `onClick={() =>
  {}}` no-op (không đổi) (FR-017, FR-021; phải sau T049/T050 vì cùng file, và sau T053-T055 vì cần
  backend trả đúng dữ liệu refType 15 để kiểm thử).
- [X] T058 [US2] Trong cùng file `EutrDocumentsAdd.jsx`, dùng `loading`/`error`/độ dài rỗng của
  `useReferenceObjects()` (từ T057) để hiển thị: trạng thái "No data" khi `referenceObjects.length
  === 0` sau khi tải xong, và thông báo lỗi thân thiện khi `error` có giá trị — không chặn các
  trường/nút khác trên trang Add (File name, Valid from, Valid to, Save, Back) (FR-017, SC-010; sau
  T057, cùng file).
- [ ] T059 [P] [US2] Kiểm thử thủ công theo [quickstart.md](./quickstart.md) kịch bản 9, 9a, 9b
  (List PO nối API thật `refType=15`, trạng thái rỗng/lỗi, và xác nhận `refType=16` chỉ tồn tại ở
  backend — không có request nào từ UI) trên
  `compliance-client/src/presentation/pages/eutr-documents/EutrDocumentsAdd.jsx`. Cần backend build
  lại (T053-T056) và chạy cùng D365/mock endpoint sẵn sàng. **Đã xác minh tĩnh** (T053-T058):
  `dotnet build ComplianceSys.sln` (0 lỗi), `npx eslint EutrDocumentsAdd.jsx` (0 lỗi), `npx vite
  build` (thành công, chunk `EutrDocumentsAdd` build đúng). **CHƯA chạy trong trình duyệt với D365
  thật** — cần môi trường chạy (backend + kết nối D365) để xác nhận request `refType=15` trả đúng
  dữ liệu, cùng điều kiện với T044/T052.

**Checkpoint**: Cột PO name trong List PO hiển thị dữ liệu D365 thật; toàn bộ hành vi CRUD (US1-US5)
và các phần chỉ-giao-diện khác của Update 3 (Screen2, File name/Action trong List PO) không đổi.

---

## Phase 11: Update 5 - Ô tìm kiếm PO lọc dữ liệu qua API (refType 15), không sửa backend

**Goal**: Ô tìm kiếm phía trên bảng List PO (Screen1, `EutrDocumentsAdd.jsx`, Type = PO) MUST lọc
bằng cách gọi lại API tham chiếu dùng chung (`refType = 15`) với từ khóa người dùng nhập, thay vì
chỉ lọc trên `poList` đã tải sẵn ở client (spec FR-023, research Quyết định 10). **Không cần sửa
backend** — `ComplDynamicsService.BuildFilterString` đã tự ánh xạ filter generic "Code"/"Name"
sang đúng cột thật (`PurchId`/`Name`) qua `EntityMappings` đã đăng ký ở Phase 10 (T053). Chỉ sửa 1
file frontend hiện có, tái dùng `lodash.debounce` đã có sẵn trong `package.json` (đã dùng ở
`ReferenceObjectAutocomplete.jsx`).

**Independent Test**: Mở trang Add, Type = "PO", gõ một từ khóa khớp tên/mã một PO thật vào ô tìm
kiếm → sau ~500ms debounce, tab Network hiện thêm 1 request `POST /api/dynamics/reference?...
&refType=15` kèm body filter `Name`/`Code` chứa từ khóa; danh sách PO cập nhật đúng theo kết quả
server (không giới hạn trong số PO đã tải trước đó). Xóa hết từ khóa → danh sách tải lại đầy đủ.
Từ khóa không khớp PO nào → hiển thị "No data" (không phải lỗi).

### Frontend (`EutrDocumentsAdd.jsx` — sửa 1 file, không đổi backend/contract)

- [X] T060 [US2] Trong `compliance-client/src/presentation/pages/eutr-documents/EutrDocumentsAdd.jsx`,
  xoá state/biến lọc cục bộ `filteredPoList` và `poSearchTerms` (tách theo dấu phẩy) — danh sách
  hiển thị trong `<List>` giờ dùng trực tiếp `poList` trả về từ hook `useReferenceObjects()` (kết
  quả đã được server lọc đúng theo từ khóa hiện tại), theo đúng quyết định "không giữ tìm kiếm đa
  từ khóa" ở spec Update 5 (FR-023; phải sau T057/T058 vì cùng file).
- [X] T061 [US2] Trong cùng file `EutrDocumentsAdd.jsx`, thêm `debouncedFetchPoList` bằng
  `useMemo(() => debounce((query) => fetchPoList(EUTR_PURCH_ORDER_REF_TYPE, query), 500),
  [fetchPoList])` (import `debounce` từ `lodash`, đúng mẫu `ReferenceObjectAutocomplete.jsx`); gọi
  hàm này trong `onChange` của ô tìm kiếm PO thay vì chỉ `setPoSearch`. Khi từ khóa bị xóa hết
  (chuỗi rỗng), vẫn gọi qua debounce với `query = ''` để khôi phục danh sách mặc định (FR-023; sau
  T060, cùng file).
- [ ] T062 [P] [US2] Kiểm thử thủ công theo [quickstart.md](./quickstart.md) kịch bản 9c, 9d (ô tìm
  kiếm PO gọi lại API theo từ khóa có debounce, trạng thái rỗng/lỗi khi tìm kiếm) trên
  `compliance-client/src/presentation/pages/eutr-documents/EutrDocumentsAdd.jsx`. Cần backend +
  D365/mock endpoint sẵn sàng (không cần thay đổi backend nào cho Update 5, chỉ cần Phase 10 đã
  chạy được). **Đã xác minh tĩnh** (T060-T061): `npx eslint EutrDocumentsAdd.jsx` (0 lỗi), `npx
  vite build` (thành công, chunk `EutrDocumentsAdd` build đúng). **CHƯA chạy trong trình duyệt với
  D365 thật** — cần môi trường chạy (backend + kết nối D365) để xác nhận debounce/kết quả tìm kiếm
  đúng, cùng điều kiện với T044/T052/T059.

**Checkpoint**: Ô tìm kiếm PO trả về đúng kết quả từ D365 theo từ khóa nhập vào; các hành vi khác
của List PO (cột File name trống, Action no-op) và toàn bộ CRUD US1-US5 không đổi.

---

## Phase 12: Update 6 - Nút Upload thật lên SharePoint ở Screen1 (thay khu kéo-thả)

**Goal**: Khu "Drag and drop files to upload" ở Screen1 (`EutrDocumentsAdd.jsx`, Type = PO) trở
thành nút **Upload** thật: người dùng click chọn 1 dòng PO trong List PO, nhấn Upload, chọn nhiều
file, hệ thống upload lên SharePoint (endpoint mới `POST /api/sharepoint/eutr-upload-multi`, service
mới `EutrUploadService` — KHÔNG dùng lại `ComplUploadService`) và tạo 1 document trong
`eutr_documents` cho mỗi file thành công (File name = tên file gốc, Valid from = hôm nay, Valid to =
`9999-12-31`, FileId = id SharePoint). PO chỉ dùng để suy ra thư mục SharePoint đích (tìm thư mục cũ
hoặc tạo mới) — KHÔNG lưu liên kết PO vào `eutr_documents` (spec FR-024 đến FR-030, research Quyết
định 11-15). Screen2 (Manual) không đổi. **Không có migration DB mới**.

**Independent Test**: Mở trang Add, Type = "PO" → nút Upload disabled khi chưa chọn PO; click 1
dòng PO → dòng được tô nổi bật, nút Upload khả dụng; nhấn Upload, chọn nhiều file hợp lệ → tab
Network có request `POST /api/sharepoint/eutr-upload-multi`; mở lại danh sách EUTR documents → thấy
đúng số document mới với File name/Valid from (hôm nay)/Valid to (`9999-12-31`) đúng. Chọn kèm 1
file sai định dạng/quá 10MB → file đó bị loại kèm lỗi rõ ràng, các file hợp lệ khác vẫn upload/tạo
document bình thường. Cột File name trong List PO vẫn hiển thị trống sau upload (không đổi).

### Backend (`SharePointController.cs` + service mới `EutrUploadService` — KHÔNG đụng `EutrDocumentsController`/`EutrDocumentsService`/`ComplUploadService`)

- [X] T063 [P] [US2] Tạo `compliance-sys-api/src/ComplianceSys.Application/Dtos/Request/EutrMultiUploadFileRequest.cs`: `{ List<IFormFile> Files, string PoCode }` (`[Required]` trên cả hai, mẫu `MultiUploadFileRequest` nhưng `PoCode` thay cho `FolderPath`).
- [X] T064 [P] [US2] Tạo `compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/EutrUploadFileResultDto.cs`: `{ string FileName, bool Success, string? ErrorMessage, long? DocumentId, string? FileId }`.
- [X] T065 [P] [US2] Tạo interface `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Services/IEutrUploadService.cs`: `Task<List<EutrUploadFileResultDto>> UploadMultipleToSharePointAndSaveDataAsync(EutrMultiUploadFileRequest request, string email, CancellationToken ct)`.
- [X] T066 [US2] Tạo `compliance-sys-api/src/ComplianceSys.Application/Services/EutrUploadService.cs` (constructor DI: `ISharepointService`, `IRepository<EutrDocuments,long>`, `IUnitOfWork`, `IConfiguration` — KHÔNG DI `IComplUploadService`/`IEutrDocumentsService`): đọc `configuration["SharePointEutrPath"]` (throw nếu thiếu, mẫu `SharePointCompPath`); suy ra/tạo thư mục con theo `request.PoCode` (`ISharepointService.GetFolders(basePath)` → nếu chưa có tên khớp thì `CreateFolder($"{basePath}/{PoCode}")`, research Quyết định 13); với mỗi file: validate đuôi (`.pdf,.doc,.docx,.xls,.xlsx,.jpg,.jpeg,.png`, không phân biệt hoa/thường) + kích thước (≤10MB) — file không hợp lệ thêm vào kết quả `Success=false` kèm `ErrorMessage`, bỏ qua; file hợp lệ: sinh tên file duy nhất trên SharePoint (hậu tố 6 ký tự, mẫu `GetUniqueFileName` của `ComplUploadService`) rồi `UploadFile(targetFolder, uniqueName, stream)`, mở transaction riêng (`IUnitOfWork.BeginTransactionAsync`/`CommitAsync`) ghi 1 dòng `EutrDocuments` (`Name` = tên file **gốc**, `FileId` = id SharePoint, `ValidFrom` = `DateTime.Today`, `ValidTo` = `new DateTime(9999,12,31)`, `CreatedBy` = email, `CreatedDate` = `DateTime.UtcNow`) qua `_repository.AddAsync`; bọc try/catch quanh từng file để lỗi 1 file không rollback các file đã commit trước đó (research Quyết định 14, FR-029/FR-030); trả về `List<EutrUploadFileResultDto>` đủ cho mọi file trong request (phải sau T063-T065).
- [X] T067 [US2] Sửa `compliance-sys-api/src/ComplianceSys.Api/Controllers/SharepointController.cs`: thêm constructor param `IEutrUploadService _eutrUploadService`; thêm action `[HttpPost("eutr-upload-multi")] [Consumes("multipart/form-data")]` nhận `[FromForm] EutrMultiUploadFileRequest request` — `400` nếu `Files` rỗng hoặc `PoCode` rỗng (mẫu validate của `UploadMultiToSharePointAndSaveData` hiện có); lấy `userEmail` từ `HttpContext.Items["UserEmail"]`; gọi `_eutrUploadService.UploadMultipleToSharePointAndSaveDataAsync(request, userEmail, ct)`; trả `Ok(ApiResponse<List<EutrUploadFileResultDto>>.Ok(result, "Upload files successfully"))` (phải sau T066).
- [X] T068 [US2] Đăng ký DI trong `compliance-sys-api/src/ComplianceSys.Application/DependencyInjection.cs`: `services.AddScoped<IEutrUploadService, EutrUploadService>();` cạnh dòng `IComplUploadService` hiện có (phải sau T066).
- [X] T069 [P] [US2] Thêm khóa cấu hình mới `"SharePointEutrPath"` vào `compliance-sys-api/src/ComplianceSys.Api/appsettings.json` (cạnh `SharePointCompPath` hiện có, vd. `"Sandbox/Eutr"`).
- [X] T070 [P] [US2] Thêm khóa cấu hình mới `"SharePointEutrPath"` vào `compliance-sys-api/src/ComplianceSys.Api/appsettings.Development.json` (vd. `"Dev/Eutr"`). **Đã có sẵn** trong file (thêm ngoài phiên làm việc này, giá trị `"Dev/Eutr"`) — xác nhận khớp đúng key mong đợi, không cần sửa thêm.

### Frontend (mở rộng `ISharePointRepository`/`RestSharePointRepository`/`UploadToSharePointUseCase` có sẵn — KHÔNG tạo domain/infrastructure/application mới)

- [X] T071 [P] [US2] Thêm khai báo `async uploadEutrFilesMulti(_files, _poCode) { throw new Error('Method not implemented'); }` vào `compliance-client/src/domain/interfaces/ISharePointRepository.js` (cạnh `uploadFileMulti` hiện có).
- [X] T072 [US2] Thêm implementation `uploadEutrFilesMulti(files, poCode)` vào `compliance-client/src/infrastructure/repositories/RestSharePointRepository.js`: dựng `FormData` (`files.forEach(f => formData.append('files', f))`, `formData.append('poCode', poCode)`) rồi `axiosInstance.post('/sharepoint/eutr-upload-multi', formData, { headers: { 'Content-Type': 'multipart/form-data' } })`, trả `response.data.data` — mẫu `uploadFileMulti` hiện có nhưng field `poCode` thay `folderPath` (phải sau T071).
- [X] T073 [US2] Thêm `async executeEutrMulti(files, poCode) { return await this.sharePointRepository.uploadEutrFilesMulti(files, poCode); }` vào `compliance-client/src/application/usecases/sharepoint/UploadToSharePointUseCase.js` (phải sau T072).
- [X] T074 [US2] Trong `compliance-client/src/presentation/pages/eutr-documents/EutrDocumentsAdd.jsx`, dùng đúng cơ chế chọn PO đơn **đã có sẵn** trong Screen1 (state `selectedPoId` + `ListItemButton onClick={() => setSelectedPoId(row.id)}` trên `List` PO — KHÔNG phải `DataGrid`, khác giả định ban đầu ở plan) làm căn cứ cho nút Upload; tính `selectedPo = poList.find((row) => row.id === selectedPoId)` để lấy `selectedPo.code` (PurchId) truyền cho API. **Bỏ** effect tự chọn PO đầu tiên khi danh sách vừa tải xong (hành vi cũ từ Update 4) — nút Upload MUST vô hiệu hóa cho tới khi người dùng chủ động click 1 dòng PO (FR-024).
- [X] T075 [US2] Trong cùng file `EutrDocumentsAdd.jsx`, thay khu "Drag and drop files to upload" ở Screen1 bằng `<Button>` "Upload"/"Uploading..." (`disabled={!selectedPo || uploading}`) + `<input type="file" multiple hidden ref={fileInputRef}>` trigger qua `fileInputRef.current.click()`; khai báo hằng số `ALLOWED_EUTR_UPLOAD_EXTENSIONS` và `MAX_EUTR_UPLOAD_SIZE_BYTES = 10 * 1024 * 1024` cùng helper `getFileExtension`; khi `onChange` của input file, lọc trước danh sách file theo đuôi/kích thước này (client-side pre-check, FR-026) — file không hợp lệ đưa vào danh sách `rejectedFiles`, không gửi lên server nếu không còn file hợp lệ nào (phải sau T074, cùng file).
- [X] T076 [US2] Trong cùng file `EutrDocumentsAdd.jsx`, nối handler `handleUploadFilesSelected`: nếu còn ít nhất 1 file hợp lệ sau lọc client (T075), gọi `uploadToSharePointUseCase.executeEutrMulti(validFiles, selectedPo.code)`; nhận mảng kết quả trả về, hiển thị `CustomSnackbar` tổng hợp (số file thành công + liệt kê `fileName`/`errorMessage` cho file thất bại, gộp cả file bị loại phía client); nếu không còn file hợp lệ nào sau lọc client, KHÔNG gọi API, chỉ hiển thị lỗi liệt kê file bị loại (FR-030, Edge Case Update 6; phải sau T073 và T075, cùng file).
- [X] T077 [P] [US2] Rà soát toàn bộ văn bản mới bằng tiếng Anh (FR-015): "Upload"/"Uploading...", thông báo kết quả/lỗi upload ("invalid file type", "exceeds 10MB limit", "No valid file to upload", "file(s) uploaded successfully") trong `EutrDocumentsAdd.jsx`. **Đã xác minh tĩnh**: `npx eslint` (0 lỗi) trên 4 file frontend đã sửa, `npx vite build` (thành công, chunk `EutrDocumentsAdd` build đúng); backend `dotnet build ComplianceSys.sln` (0 lỗi).
- [ ] T078 [US2] Kiểm thử thủ công theo [quickstart.md](./quickstart.md) kịch bản 9e-9j (nút Upload disabled/khả dụng theo lựa chọn PO, upload nhiều file thành công tạo đúng document, file sai định dạng/quá 10MB bị loại không chặn file khác, lỗi một phần batch không mất file đã thành công, thư mục PO được tái sử dụng ở lần upload sau) trên `compliance-client/src/presentation/pages/eutr-documents/EutrDocumentsAdd.jsx`. Cần backend build lại (đã build thành công cục bộ) và cấu hình `SharePointEutrPath` + quyền truy cập SharePoint hợp lệ. **CHƯA chạy trong trình duyệt với SharePoint thật** — cùng điều kiện với T044/T052/T059/T062 (cần môi trường chạy đầy đủ: backend + DB + SharePoint).

**Checkpoint**: Nút Upload ở Screen1 hoạt động end-to-end (upload thật lên SharePoint, tạo document
thật); toàn bộ CRUD US1-US5 và các phần khác của trang Add (Screen2, cột PO name/File name List PO,
ô tìm kiếm PO) không đổi.

---

## Phase 13: Update 7 - Thiết kế lại khu Upload theo hình + validate prefix + ghi `eutr_references`

**Goal**: Khu Upload ở Screen1 được thiết kế lại theo mẫu `upload.png` (tiêu đề "Upload File", khung
kéo-thả lớn với icon đám mây, dòng chữ "Drop file here or click to browse", hàng chip định dạng/
kích thước **thật** — không đổi so với Update 6) và **thêm kéo-thả file thật** (ngoài click chọn file
đã có). Trước khi upload lên SharePoint, mỗi file MUST qua thêm validate **prefix tên file** so với
`eutr_master_documents.Prefix` (feature `002-eutr-masters`, chỉ đọc) — file không khớp bị loại. File
khớp N `StepId` phân biệt thì sau khi upload SharePoint + tạo document thành công sẽ ghi thêm N dòng
`eutr_references` (cùng `DocumentId`, khác `StepId`, `RefType = 0`, `RefValue = poCode`) trong
**một transaction chung** với `eutr_documents` của file đó — lỗi ở bất kỳ bước ghi nào rollback toàn
bộ (không để lại document mồ côi). **Migration DB mới**: thêm cột `StepId` vào `eutr_references`
(KHÔNG đụng cột/FK `RefId` hiện có).

**Independent Test**: Với một PO đã chọn, khu Upload hiển thị đúng theo mẫu `upload.png` với nội
dung định dạng/kích thước thật; kéo-thả một file hợp lệ (đúng định dạng/kích thước, tên có prefix
khớp `eutr_master_documents`) vào khung → xử lý giống hệt click chọn file → document mới + đúng số
dòng `eutr_references` tương ứng được tạo. Chọn/thả một file tên không khớp prefix nào → bị loại
kèm cảnh báo rõ ràng, không tạo document/eutr_references. Chuẩn bị 2 bản ghi `eutr_master_documents`
cùng khớp prefix một tên file nhưng khác `StepId` → upload file đó tạo đúng 2 dòng `eutr_references`
cùng `DocumentId`.

### Backend (entity mới `EutrReferences` + mở rộng `IEutrMastersRepository` có sẵn — KHÔNG tạo repository riêng cho `eutr_references`, KHÔNG đổi contract endpoint `eutr-upload-multi`)

- [X] T079 [P] [US2] Tạo `compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Migration/10_add_stepid_to_eutr_references.sql`: `ALTER TABLE eutr_references ADD COLUMN StepId BIGINT UNSIGNED NULL AFTER RefId;` + `ALTER TABLE eutr_references ADD CONSTRAINT eutr_references_stepid_foreign FOREIGN KEY (StepId) REFERENCES eutr_steps(Id);` (theo convention `NN_migrate_*.sql`/`Migration/` đã dùng — KHÔNG sửa/xóa cột `RefId` hay FK `eutr_references_refid_foreign` hiện có, research Quyết định 16).
- [X] T080 [P] [US2] Cập nhật `docs/design/eutr/eutr_db.sql` và `compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Tables/eutr_db.sql`: thêm cột `StepId BIGINT UNSIGNED NULL` (sau `RefId`) và FK `eutr_references_stepid_foreign` vào định nghĩa bảng `eutr_references`, để tài liệu thiết kế khớp với migration T079. **Ghi chú**: `docs/design/eutr/eutr_db.sql` đã có sẵn cột `StepId` (thêm ngoài phiên làm việc này) nhưng thiếu dòng `ALTER TABLE` FK — đã bổ sung FK còn thiếu vào cả 2 file.
- [X] T081 [P] [US2] Tạo `compliance-sys-api/src/ComplianceSys.Domain/Entities/EutrReferences.cs` (`[Table("eutr_references")]`, kế thừa `BaseEntity`): `Id (long)`, `RefId (long?)` (không dùng bởi feature này), `DocumentId (long?)`, `StepId (long?)`, `RefType (byte?)`, `RefValue (string?)` — dùng thẳng `IRepository<EutrReferences,long>` generic (đã đăng ký open-generic sẵn), KHÔNG tạo repository riêng (research Quyết định 16).
- [X] T082 [US2] Sửa `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Repositories/IEutrMastersRepository.cs`: thêm `Task<List<EutrMastersDocument>> GetMatchingPrefixesAsync(string fileName, CancellationToken ct = default);`.
- [X] T083 [US2] Sửa `compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/EutrMastersRepository.cs`: implement `GetMatchingPrefixesAsync` bằng SQL "đảo chiều LIKE" — `SELECT Id, StepId, Prefix FROM eutr_master_documents WHERE Prefix IS NOT NULL AND Prefix <> '' AND @fileName LIKE CONCAT(REPLACE(REPLACE(REPLACE(Prefix, '\\', '\\\\'), '%', '\\%'), '_', '\\_'), '%')`, trả về danh sách bản ghi khớp (0, 1, hoặc nhiều) (research Quyết định 17; phải sau T082, cùng cặp interface/impl).
- [X] T084 [US2] Sửa `compliance-sys-api/src/ComplianceSys.Application/Services/EutrUploadService.cs`: thêm constructor param `IEutrMastersRepository` + `IRepository<EutrReferences,long>`; trước khi upload SharePoint cho mỗi file (sau validate định dạng/kích thước FR-026), gọi `GetMatchingPrefixesAsync(file.FileName, ct)` — nếu rỗng, thêm kết quả `{ Success = false, ErrorMessage = "No matching prefix found in EUTR masters" }` và bỏ qua file (không upload SharePoint); nếu có kết quả, lấy tập `StepId` phân biệt (`Distinct`, loại `null`) để dùng ở T085 (phải sau T081-T083).
- [X] T085 [US2] Trong cùng file `EutrUploadService.cs`, mở rộng khối ghi DB per-file (đã có từ Update 6, T066) để trong **cùng 1 transaction**: `AddAsync` document `EutrDocuments` như cũ, sau đó với mỗi `StepId` phân biệt (từ T084) `AddAsync` một `EutrReferences { DocumentId = documentId, StepId = stepId, RefType = 0, RefValue = request.PoCode }`; nếu bất kỳ bước nào (document hoặc bất kỳ reference nào) throw → rollback toàn bộ nhóm này (document + mọi reference đã insert của file đó), file được báo `Success = false` (research Quyết định 18, FR-033; phải sau T084, cùng file, cùng khối try/catch per-file). **Đã xác minh tĩnh**: `dotnet build` trên từng project `ComplianceSys.Domain`/`ComplianceSys.Application`/`ComplianceSys.Infrastructure` (0 lỗi mỗi project) — build toàn `ComplianceSys.sln` bị khóa file do tiến trình `ComplianceSys.Api` đang chạy sẵn trên máy (không phải lỗi biên dịch), chưa build lại solution đầy đủ.

### Frontend (thiết kế lại card Upload + gộp logic click/kéo-thả — sửa 1 file)

- [X] T086 [US2] Trong `compliance-client/src/presentation/pages/eutr-documents/EutrDocumentsAdd.jsx`, tách phần xử lý danh sách file (`File[]`) ra khỏi `handleUploadFilesSelected` hiện có (Update 6) thành một hàm dùng chung nhận `File[]` làm tham số (validate đuôi/kích thước client-side, gọi `executeEutrMulti`, hiển thị snackbar) — cả `onChange` của `<input type="file">` (đọc `e.target.files`) lẫn `onDrop` mới (đọc `e.dataTransfer.files`) đều gọi hàm dùng chung này (research Quyết định 19; phải sau T076, cùng file).
- [X] T087 [US2] Trong cùng file `EutrDocumentsAdd.jsx`, thay khối UI nút "Upload" đơn giản (Update 6) bằng card theo mẫu `upload.png`: `Typography` "Upload File" (đậm) phía trên; `Box` viền nét đứt lớn (`border: '2px dashed'`) chứa `CloudUploadIcon` (import từ `@mui/icons-material`) + `Typography` "Drop file here or click to browse" (`onClick` mở `fileInputRef`, `onDragOver={(e) => e.preventDefault()}`, `onDrop` đọc `e.dataTransfer.files` rồi gọi hàm dùng chung từ T086); một dòng phụ (`Typography variant="caption"`) liệt kê đúng định dạng/kích thước **thật** ("PDF, DOC/DOCX, XLS/XLSX, JPG/PNG — max 10MB per file"); một hàng `Chip` nhỏ bên dưới (`size="small"` `variant="outlined"`: "PDF", "DOC/DOCX", "XLS/XLSX", "JPG/PNG", "Max 10MB") — toàn bộ card bị làm mờ (`sx={{ opacity: 0.5, pointerEvents: 'none' }}` khi điều kiện `!selectedPo`) thay cho `disabled` của nút cũ (phải sau T086, cùng file).
- [X] T088 [P] [US2] Rà soát toàn bộ văn bản mới bằng tiếng Anh (FR-015): "Upload File", "Drop file here or click to browse", nhãn chip ("PDF", "DOC/DOCX", "XLS/XLSX", "JPG/PNG", "Max 10MB"), thông báo lỗi mới liên quan prefix ("No matching prefix found in EUTR masters" hoặc tương đương) trong `EutrDocumentsAdd.jsx`. **Đã xác minh tĩnh**: `npx eslint` (0 lỗi), `npx vite build` (thành công, chunk `EutrDocumentsAdd` build đúng).
- [ ] T089 [US2] Kiểm thử thủ công theo [quickstart.md](./quickstart.md) kịch bản 9k-9o (giao diện đúng theo `upload.png`, kéo-thả file thật hoạt động giống click, file không khớp prefix bị chặn, prefix khớp nhiều Step tạo nhiều dòng `eutr_references`, ghi `eutr_references` thất bại rollback cả document) trên `compliance-client/src/presentation/pages/eutr-documents/EutrDocumentsAdd.jsx`. Cần backend build lại (T079-T085), migration T079 đã chạy, và có sẵn dữ liệu test trong `eutr_master_documents` (ít nhất 1 Prefix đã biết trước). **CHƯA chạy trong trình duyệt với backend/DB/SharePoint thật** — cùng điều kiện với T044/T052/T059/T062/T078 (cần môi trường chạy đầy đủ; đồng thời tiến trình `ComplianceSys.Api` đang chạy sẵn cần được khởi động lại để nạp code mới trước khi kiểm thử).

**Checkpoint**: Khu Upload ở Screen1 hiển thị đúng theo mẫu `upload.png`, hỗ trợ kéo-thả thật, chỉ
cho upload file có prefix hợp lệ, và ghi đúng liên kết `eutr_references`; toàn bộ hành vi Update 6
(upload SharePoint, tạo `eutr_documents`, best-effort per-file) và CRUD US1-US5 không đổi.

---

## Phase 14: Update 8 - Nạp Step name/Type ở danh sách + File name/Step name ở List PO qua `eutr_references`

**Goal**: Cột **Step name**/**Type** trong danh sách EUTR documents (US1) và cột **File
name**/**Step name** trong bảng chi tiết List PO trên trang Add (US2, Screen1) KHÔNG còn luôn trống
— cả hai nạp bằng cách **đọc** (read-only) bảng `eutr_references` đã có từ Update 7 (JOIN
`eutr_steps`/`eutr_documents`), theo mã PO/DocumentId tương ứng (spec FR-034 đến FR-038, research
Quyết định 20-23). **Không có migration DB mới**. Cột **Conditions** không đổi (vẫn luôn trống).

**Independent Test**: Với một document được tạo qua nút Upload (đã có bản ghi `eutr_references`
liên kết, xem tiền đề Update 7) → cột Step name/Type trong danh sách EUTR documents hiển thị đúng
dữ liệu thật (không trống); document tạo qua form Save nhập tay (không có `eutr_references` nào)
→ vẫn hiển thị trống. Trên trang Add, click chọn lại PO đã từng được upload file → bảng chi tiết
List PO hiển thị đúng File name + Step name của (các) file đã upload cho PO đó (tab Network có
request `POST /api/eutr-documents/list-po-references`); chọn PO chưa từng upload file nào → bảng
chi tiết hiển thị "No data". File khớp Prefix của nhiều `StepId` (kịch bản 9n) → cả 2 nơi cùng hiển
thị đúng nhiều Step name (chip + "+N more"/tooltip).

### Backend (repository mới `EutrReferencesRepository`, endpoint mới trong `EutrDocumentsController` — KHÔNG migration DB mới)

- [X] T090 [P] [US1] Tạo `compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/EutrReferenceStepInfo.cs`: projection phẳng `{ long DocumentId, string? StepName, byte? RefType }` — kết quả thô của truy vấn JOIN `eutr_references`+`eutr_steps` theo `DocumentId` (research Quyết định 20).
- [X] T091 [P] [US2] Tạo `compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/EutrReferencePoDocumentInfo.cs`: projection phẳng `{ string PoCode, long DocumentId, string? FileName, string? StepName }` — kết quả thô của truy vấn JOIN `eutr_references`+`eutr_documents`+`eutr_steps` theo `RefType`/`RefValue` (research Quyết định 21).
- [X] T092 [P] [US2] Tạo `compliance-sys-api/src/ComplianceSys.Application/Dtos/Request/EutrDocumentsListPoReferencesRequestDto.cs`: `{ List<string> PoCodes }`.
- [X] T093 [P] [US2] Tạo `compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/EutrDocumentsPoReferenceItemDto.cs`: `{ long DocumentId, string? FileName, List<string> StepNames }`.
- [X] T094 [P] [US2] Tạo `compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/EutrDocumentsPoReferenceDto.cs`: `{ string PoCode, List<EutrDocumentsPoReferenceItemDto> Documents }` (tham chiếu type ở T093, không cần T093 hoàn tất trước để bắt đầu viết — chỉ cần cả hai tồn tại trước khi build).
- [X] T095 [US1] Tạo interface `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Repositories/IEutrReferencesRepository.cs`: `Task<List<EutrReferenceStepInfo>> GetStepInfoByDocumentIdsAsync(IEnumerable<long> documentIds, CancellationToken ct = default);` + `Task<List<EutrReferencePoDocumentInfo>> GetDocumentsByPoCodesAsync(IEnumerable<string> poCodes, CancellationToken ct = default);` (phải sau T090/T091 để có type tham chiếu).
- [X] T096 [US1] Tạo `compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/EutrReferencesRepository.cs` (`DapperRepository<EutrReferences,long>, IEutrReferencesRepository` — clone mẫu `EutrMastersRepository`, chỉ nhận `IUnitOfWork` qua constructor): implement `GetStepInfoByDocumentIdsAsync` — `SELECT r.DocumentId, s.Name AS StepName, r.RefType FROM eutr_references r LEFT JOIN eutr_steps s ON s.Id = r.StepId WHERE r.DocumentId IN @DocumentIds;` qua `Connection.QueryAsync<EutrReferenceStepInfo>(new CommandDefinition(sql, parameters, transaction: Transaction, cancellationToken: ct))` (phải sau T095).
- [X] T097 [US2] Trong cùng file `EutrReferencesRepository.cs`, implement `GetDocumentsByPoCodesAsync` — `SELECT r.RefValue AS PoCode, r.DocumentId, d.Name AS FileName, s.Name AS StepName FROM eutr_references r LEFT JOIN eutr_documents d ON d.Id = r.DocumentId LEFT JOIN eutr_steps s ON s.Id = r.StepId WHERE r.RefType = 0 AND r.RefValue IN @PoCodes;` qua `Connection.QueryAsync<EutrReferencePoDocumentInfo>(...)` (phải sau T096, cùng file).
- [X] T098 [US1] Đăng ký DI trong `compliance-sys-api/src/ComplianceSys.Infrastructure/DependencyInjection.cs`: `services.AddScoped<IEutrReferencesRepository, EutrReferencesRepository>();` cạnh dòng `IEutrMastersRepository` đã có (phải sau T096/T097).
- [X] T099 [US1] Sửa `compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/EutrDocumentsResponseDto.cs`: thêm `public List<string> StepNames { get; set; } = [];` và `public byte? RefType { get; set; }`.
- [X] T100 [US1] Sửa `compliance-sys-api/src/ComplianceSys.Application/Services/EutrDocumentsService.cs`: thêm constructor param `IEutrReferencesRepository`; trong `GetPagedAsync`, sau khi có trang `EutrDocumentsResponseDto` (từ `base.GetPagedAsync` + map), gọi `GetStepInfoByDocumentIdsAsync` với danh sách `Id` của trang đó, `GroupBy(x => x.DocumentId)` rồi gán `dto.StepNames` (distinct `StepName`, loại `null`) và `dto.RefType` (giá trị đầu tiên tìm được trong nhóm) cho từng dto tương ứng — document không có nhóm nào giữ `StepNames = []`/`RefType = null` (clone mẫu `ComplCountryGroupService.AttachMembersAsync`, research Quyết định 20; phải sau T096, T098, T099).
- [X] T101 [US2] Sửa `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Services/IEutrDocumentsService.cs`: thêm `Task<List<EutrDocumentsPoReferenceDto>> GetPoReferencesAsync(List<string> poCodes, CancellationToken ct = default);`.
- [X] T102 [US2] Trong cùng file `EutrDocumentsService.cs`, implement `GetPoReferencesAsync`: gọi `GetDocumentsByPoCodesAsync(poCodes, ct)`, `GroupBy(x => x.PoCode)` rồi trong mỗi nhóm `GroupBy(x => x.DocumentId)` để dựng `List<EutrDocumentsPoReferenceItemDto>` (`FileName` lấy từ bản ghi đầu, `StepNames` = distinct `StepName` trong nhóm con), trả về `List<EutrDocumentsPoReferenceDto>` — `PoCode` không có bản ghi nào vẫn trả về `{ PoCode, Documents: [] }` (research Quyết định 21; phải sau T097, T101, T093, T094).
- [X] T103 [US2] Sửa `compliance-sys-api/src/ComplianceSys.Api/Controllers/EutrDocumentsController.cs`: thêm action `[HttpPost("list-po-references")] [Authorize(Policy = "EutrDocuments.ReadAll")]` nhận `[FromBody] EutrDocumentsListPoReferencesRequestDto request`, gọi `_eutrDocumentsService.GetPoReferencesAsync(request.PoCodes, ct)`, trả `Ok(ApiResponse<List<EutrDocumentsPoReferenceDto>>.Ok(result))` (phải sau T102).

### Frontend (component dùng chung `MultiValueChips`, use case mới, sửa 4 file hiện có)

- [X] T104 [P] [US1] Tạo `compliance-client/src/presentation/components/common/MultiValueChips.jsx`: `props { values: string[], previewLimit = 2 }` — clone logic chip + "+N more" + `Tooltip` đang inline ở cột "Country Codes" của `useCountryGroupColumns.jsx` (research Quyết định 23); trả về `null`/không render gì khi `values` rỗng.
- [X] T105 [US1] Sửa `compliance-client/src/presentation/pages/eutr-documents/hooks/useEutrDocumentsColumns.jsx`: cột `stepName` đổi sang `renderCell: (params) => <MultiValueChips values={params.row.stepNames} />`; cột `type` đổi sang `renderCell`/`valueGetter` map `params.row.refType` qua hằng số có sẵn `TAKE_FROM_OPTIONS` (import từ `@utils/helpers`) lấy `label` tương ứng (`null`/`undefined` → hiển thị trống); xóa comment cũ "Step name/Conditions/Type KHÔNG có nguồn dữ liệu... luôn hiển thị trống" (chỉ còn đúng với Conditions) (phải sau T104).
- [X] T106 [US1] Sửa `compliance-client/src/domain/entities/EutrDocuments.js`: thêm field `stepNames: []`, `refType: null` vào entity.
- [X] T107 [US1] Sửa `compliance-client/src/infrastructure/repositories/RestEutrDocumentsRepository.js`: đảm bảo hàm map response → `EutrDocuments` trong `getAllPaging` truyền qua `stepNames`/`refType` từ item API trả về (phải sau T106). **Xác minh, không cần sửa file**: `getAllPaging` trả thẳng `res.data` (không dựng object `EutrDocuments`), và `useEutrDocumentsData.js` đọc trực tiếp `result.items` từ JSON — `stepNames`/`refType` do backend trả về (camelCase mặc định của ASP.NET Core) đã tự động có mặt trên mỗi item mà không cần thêm code mapping nào (khác dự kiến ban đầu ở tasks.md; đã kiểm tra kỹ luồng dữ liệu, không phải bỏ sót).
- [X] T108 [P] [US2] Tạo `compliance-client/src/application/usecases/eutr-documents/GetEutrDocumentsPoReferencesUseCase.js`: `execute(poCodes) { return this.repository.getPoReferences(poCodes); }` (constructor nhận `repository`, mẫu các use case hiện có của feature).
- [X] T109 [P] [US2] Thêm khai báo `async getPoReferences(_poCodes) { throw new Error('Method not implemented'); }` vào `compliance-client/src/domain/interfaces/IEutrDocumentsRepository.js`.
- [X] T110 [P] [US2] Thêm hàm `listPoReferences(payload)` vào `compliance-client/src/infrastructure/api/eutrDocumentsApi.js`: `POST /eutr-documents/list-po-references` với body `payload` (`{ poCodes }`).
- [X] T111 [US2] Implement `getPoReferences(poCodes)` trong `compliance-client/src/infrastructure/repositories/RestEutrDocumentsRepository.js`: gọi `eutrDocumentsApi.listPoReferences({ poCodes })`, trả thẳng `response.data.data` (đã đúng hình dạng `{ poCode, documents }`, không cần map entity riêng) (phải sau T109, T110).
- [X] T112 [US2] Trong `compliance-client/src/presentation/pages/eutr-documents/EutrDocumentsAdd.jsx`, thêm state `poReferenceDocuments` (mảng, mặc định `[]`) + `useEffect` theo dõi `selectedPoId`: khi có `selectedPo`, gọi `getEutrDocumentsPoReferencesUseCase.execute([selectedPo.code])` (dùng `repositories.eutrDocuments`, mẫu khởi tạo use case đã có ở đầu file), lấy `result[0]?.documents ?? []` gán vào state; khi `selectedPoId` là `null`, reset `poReferenceDocuments = []` (research Quyết định 22 — chỉ tra cứu PO đang chọn, không phải toàn trang; phải sau T108, T111).
- [X] T113 [US2] Trong cùng file `EutrDocumentsAdd.jsx`, thay `TableBody` của bảng chi tiết List PO (Grid size=5, hiện chỉ render 1 `TableRow` placeholder tĩnh khi có `selectedPo`) bằng `.map()` qua `poReferenceDocuments` (mỗi `doc`: `TableCell` File name = `doc.fileName`, `TableCell` Step name = `<MultiValueChips values={doc.stepNames} />`); hiển thị 1 dòng "No data" (`colSpan` đủ rộng) khi `selectedPo` tồn tại nhưng `poReferenceDocuments.length === 0` (phải sau T112, T104, cùng file).
- [X] T114 [P] [US1] Rà soát văn bản mới bằng tiếng Anh (FR-015): cột "Step name"/"Type" không phát sinh chuỗi mới ngoài nhãn `TAKE_FROM_OPTIONS` đã có ("PO"/"Upload manual") — xác nhận `MultiValueChips`/tooltip không hard-code chuỗi tiếng Việt. **Đã xác minh tĩnh**: `npx eslint` trên `MultiValueChips.jsx`/`useEutrDocumentsColumns.jsx` (0 lỗi), `npx vite build` (thành công, chunk `MultiValueChips` build đúng).
- [X] T115 [P] [US2] Rà soát văn bản mới bằng tiếng Anh (FR-015): dòng "No data" mới trong bảng chi tiết List PO khớp đúng chuỗi "No data" đã dùng ở các trạng thái rỗng khác của trang Add (không tạo chuỗi rỗng khác biệt). **Đã xác minh tĩnh**: `npx eslint EutrDocumentsAdd.jsx` (0 lỗi), `npx vite build` (thành công, chunk `EutrDocumentsAdd` build đúng); backend `dotnet build ComplianceSys.sln` (0 lỗi, chỉ warning CS1591 có sẵn từ trước).
- [ ] T116 [US1] Kiểm thử thủ công theo [quickstart.md](./quickstart.md) kịch bản 1a (Step name/Type nạp dữ liệu thật cho document đã upload, vẫn trống cho document tạo qua Save) trên `/eutr/documents`. Cần backend build lại (T090-T103) và có sẵn ít nhất 1 document tạo qua nút Upload (Phase 12/13) kèm `eutr_references` liên kết. **Đã xác minh tĩnh** (T090-T103): `dotnet build ComplianceSys.sln` (0 lỗi). **CHƯA chạy trong trình duyệt** — cần môi trường chạy đầy đủ (backend + DB + dữ liệu test), cùng điều kiện với T044/T052/T059/T062/T078/T089.
- [ ] T117 [US2] Kiểm thử thủ công theo [quickstart.md](./quickstart.md) kịch bản 9p, 9q (File name/Step name nạp dữ liệu thật ở bảng chi tiết List PO, gồm trường hợp nhiều Step name cho 1 file) trên `compliance-client/src/presentation/pages/eutr-documents/EutrDocumentsAdd.jsx`. Cần backend build lại (T090-T103), frontend build lại (T104-T113), và dữ liệu test giống T116 (đồng thời trường hợp 1 file khớp prefix nhiều `StepId`, xem Phase 13/T089). **Đã xác minh tĩnh** (T104-T113): `npx eslint` (0 lỗi), `npx vite build` (thành công). **CHƯA chạy trong trình duyệt** — cùng điều kiện với T116.

**Checkpoint**: Step name/Type (danh sách) và File name/Step name (List PO) hiển thị đúng dữ liệu
thật khi có liên kết `eutr_references`, và hiển thị trống (không lỗi) khi không có; toàn bộ CRUD
US1-US5 và các phần khác của trang Add (Update 3-7) không đổi.

---

## Phase 15: Update 9 - Xóa document (Delete) MUST xóa kèm mọi bản ghi `eutr_references` liên quan

**Goal**: Chức năng Delete (US4, đơn hoặc nhiều document) hiện chỉ xóa `eutr_documents`, để lại các
dòng `eutr_references` mồ côi (ghi bởi luồng Upload ở Screen1, Update 7). Backend MUST xóa toàn bộ
dòng `eutr_references` có `DocumentId` = document bị xóa, cùng transaction với việc xóa
`eutr_documents` — nếu bước xóa `eutr_references` thất bại, document đó KHÔNG bị xóa (rollback);
với xóa nhiều document, lỗi ở 1 document KHÔNG chặn việc xóa các document khác trong cùng lượt (spec
FR-039/FR-040, research Quyết định 24). **Không migration DB mới, không đổi route/DTO/controller.**

**Independent Test**: Tạo 1 document có ít nhất 1 bản ghi `eutr_references` liên kết (upload qua
Screen1) → Delete document đó → xác nhận document không còn trong `eutr_documents` VÀ không còn
dòng `eutr_references` nào có `DocumentId` tương ứng. Chọn xóa nhiều document (một số có, một số
không có `eutr_references`) → tất cả bị xóa đúng, mọi `eutr_references` liên quan cũng bị xóa hết.

### Backend (thêm method mới vào `IEutrReferencesRepository`/`EutrReferencesRepository` đã có từ Update 8; override Delete/DeleteMulti trong `EutrDocumentsService` — KHÔNG sửa `IBaseService`/`IEutrDocumentsService`)

- [X] T118 [US4] Sửa `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Repositories/IEutrReferencesRepository.cs`: thêm `Task DeleteByDocumentIdAsync(long documentId, CancellationToken ct = default);` (cạnh 2 method đọc hiện có).
- [X] T119 [US4] Sửa `compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/EutrReferencesRepository.cs`: implement `DeleteByDocumentIdAsync` bằng raw SQL `DELETE FROM eutr_references WHERE DocumentId = @DocumentId;` qua `Connection.ExecuteAsync(new CommandDefinition(sql, new { DocumentId = documentId }, transaction: Transaction, cancellationToken: ct))` — cùng style `CommandDefinition` đã dùng ở 2 method đọc hiện có (phải sau T118).
- [X] T120 [US4] Sửa `compliance-sys-api/src/ComplianceSys.Application/Services/EutrDocumentsService.cs`: thêm field riêng `private readonly IUnitOfWork _unitOfWork;` (gán từ tham số `unitOfWork` của constructor — trước đây chỉ truyền cho `base(...)`, không giữ lại); thêm `public override async Task DeleteAsync(long id, string userEmail, CancellationToken ct = default)`: kiểm tra tồn tại qua `_repository.GetByIdAsync(id, ct)` (throw `KeyNotFoundException` nếu `null`), sau đó trong khối `try { BeginTransactionAsync(IsolationLevel.ReadCommitted); await _referencesRepository.DeleteByDocumentIdAsync(id, ct); await _repository.DeleteAsync(id, ct); await _unitOfWork.CommitAsync(); } catch { await _unitOfWork.RollbackAsync(); throw; }` — mẫu override `ComplJobScheduleConfigService.DeleteAsync` (research Quyết định 24, FR-039; phải sau T119).
- [X] T121 [US4] Trong cùng file `EutrDocumentsService.cs`, thêm `public override async Task DeleteMultiAsync(IEnumerable<long> ids, CancellationToken ct = default)`: **KHÔNG gọi `base.DeleteMultiAsync`** (dùng 1 transaction chung cho cả batch, all-or-nothing) — thay bằng vòng lặp `foreach (var id in ids)`, mỗi lần lặp mở 1 transaction riêng (`BeginTransactionAsync`/`_referencesRepository.DeleteByDocumentIdAsync(id, ct)`/`_repository.DeleteAsync(id, ct)`/`CommitAsync`), lỗi của từng id được `catch` riêng (`RollbackAsync` rồi gom vào `List<string> failures`, KHÔNG rethrow ngay — tiếp tục vòng lặp với id kế tiếp); sau vòng lặp, nếu `failures.Count > 0` thì `throw new InvalidOperationException(...)` liệt kê id/lý do của mọi id lỗi (các id đã xóa thành công trước đó vẫn giữ trạng thái đã xóa vì transaction của chúng đã `CommitAsync` độc lập) — mẫu per-item try/catch của `EutrUploadService.UploadMultipleToSharePointAndSaveDataAsync` (research Quyết định 14/18/24, FR-040; phải sau T120, cùng file). **Đã xác minh tĩnh**: `dotnet build` trên từng project `ComplianceSys.Domain`/`ComplianceSys.Application`/`ComplianceSys.Infrastructure` (0 lỗi mỗi project) — build toàn `ComplianceSys.sln` bị khóa file do tiến trình `ComplianceSys.Api` đang chạy sẵn trên máy (không phải lỗi biên dịch, cùng tình trạng đã ghi ở T085).

### Kiểm thử

- [ ] T122 [US4] Kiểm thử thủ công theo [quickstart.md](./quickstart.md) kịch bản 5a-5c (xóa 1
  document kèm dọn `eutr_references`, xóa nhiều document hỗn hợp có/không có `eutr_references`,
  rollback khi bước xóa `eutr_references` thất bại — có thể bỏ qua nếu không dựng được lỗi DB tạm
  thời) trên `/eutr/documents`. Cần backend build lại (T118-T121) và có sẵn ít nhất 1 document tạo
  qua nút Upload (Phase 12/13) kèm `eutr_references` liên kết, giống dữ liệu test đã dùng ở T116.
  **CHƯA chạy trong trình duyệt** — cần môi trường chạy đầy đủ (backend + DB), cùng điều kiện với
  T044/T052/T059/T062/T078/T089/T116/T117.

**Checkpoint**: Xóa 1 hoặc nhiều document không còn để lại bản ghi `eutr_references` mồ côi nào;
lỗi ở bước dọn `eutr_references` khiến document đó không bị xóa (rollback) và không chặn việc xóa
các document khác trong cùng lượt xóa nhiều; toàn bộ CRUD US1-US3, US5 và các phần khác của trang
Add (Update 3-8) không đổi.

---

## Phase 16: Update 10 - Icon View mở xem file thật + Delete từng file ở List PO

**Goal**: Icon **View** trên cột Action của danh sách chính (trước đây placeholder silent no-op,
US5) và trên mỗi dòng của bảng chi tiết List PO (trang Add, US2) nay mở một **popup xem trước file
thật** — tham khảo đúng hàm `[HttpGet("get-file-by-idref")] GetFileByIds` trong
`ComplCompliancesController.cs` và giao diện `compliance-detail`
(`FilePreviewer.jsx`/`DialogFilePreviewer.jsx`). Document không có `FileId` → icon View bị vô hiệu
hóa (tooltip "No file to view"). Mỗi file riêng lẻ trên bảng chi tiết List PO (đã có sẵn cấu trúc
"1 dòng = 1 document" từ Update 8) có icon **Delete** riêng — xóa qua API xóa đơn hiện có (`DELETE
/api/eutr-documents/{id}`, đã dọn `eutr_references` từ Update 9), KHÔNG gọi API xóa file
SharePoint nào (spec FR-041 đến FR-045, research Quyết định 25-28). **Không migration DB mới.**

**Independent Test**: Trên danh sách chính, dòng của document có `FileId` → icon View active, nhấn
vào mở popup xem trước đúng nội dung file (tab Network có request
`GET /api/eutr-documents/get-file-by-idref?idRef=<fileId>`), có nút Download/Close hoạt động; dòng
của document không có `FileId` → icon View vô hiệu hóa kèm tooltip. Trên trang Add, chọn lại 1 PO
đã upload nhiều file → mỗi dòng trong bảng chi tiết có icon View riêng (mở đúng file của dòng đó) và
icon Delete riêng (xác nhận rồi xóa đúng và chỉ đúng document đó — dòng biến mất khỏi List PO VÀ
khỏi danh sách chính, các dòng/file khác của cùng PO không bị ảnh hưởng, file vẫn còn trên
SharePoint sau khi xóa).

### Backend (endpoint mới trong `EutrDocumentsController` hiện có, thêm `FileId` vào 1 truy vấn JOIN đã có — KHÔNG migration DB mới, KHÔNG endpoint xóa mới)

- [X] T123 [P] [US5] Sửa `compliance-sys-api/src/ComplianceSys.Api/Controllers/EutrDocumentsController.cs`: thêm `using Shared.ExternalServices.Interfaces;` + `using Shared.ExternalServices.Models.Sharepoint;`; thêm constructor param `ISharepointService sharepointService` (giữ field `_sharepointService`, KHÔNG đăng ký DI mới — interface đã đăng ký sẵn, dùng chung với `ComplCompliancesController`/`SharePointController`); thêm action `[Authorize(Policy = "EutrDocuments.ReadOne")] [HttpGet("get-file-by-idref")] GetFileByIdRef([FromQuery] string idRef, CancellationToken ct = default)` — clone nguyên vẹn logic của `ComplCompliancesController.GetFileByIds` (`BadRequest` nếu `idRef` rỗng; gọi `_sharepointService.ReadFileWithMetaAsync(idRef)`; retry 1 lần khi gặp `HttpRequestException` với `StatusCode == HttpStatusCode.ServiceUnavailable`; `catch` khác trả `StatusCode(500, ApiResponse<string>.Fail(...))`; hết retry trả `StatusCode(503, ...)`), trả `Ok(ApiResponse<SharepointFileContent>.Ok(files, "Get file detail successfully"))` khi thành công (research Quyết định 25, FR-041).
- [X] T124 [P] [US2] Sửa `compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/EutrReferencePoDocumentInfo.cs`: thêm `public string? FileId { get; set; }`.
- [X] T125 [P] [US2] Sửa `compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/EutrDocumentsPoReferenceItemDto.cs`: thêm `public string? FileId { get; set; }`.
- [X] T126 [US2] Sửa `compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/EutrReferencesRepository.cs`: trong `GetDocumentsByPoCodesAsync`, thêm `d.FileId AS FileId` vào `SELECT` (cạnh `d.Name AS FileName` hiện có) — phải sau T124 (cần field `FileId` tồn tại trên `EutrReferencePoDocumentInfo` để Dapper map đúng).
- [X] T127 [US2] Sửa `compliance-sys-api/src/ComplianceSys.Application/Services/EutrDocumentsService.cs`: trong `GetPoReferencesAsync`, khi dựng từng `EutrDocumentsPoReferenceItemDto`, gán thêm `FileId = g.First().FileId` (cạnh `DocumentId`/`FileName`/`StepNames` hiện có) — phải sau T125, T126.

### Frontend (tổng quát hoá `FilePreviewer.jsx` bằng 2 prop tùy chọn — KHÔNG nhân bản logic render; component mới scoped riêng cho `eutr-documents`)

- [X] T128 [P] [US5] Sửa `compliance-client/src/presentation/components/FilePreviewer.jsx`: đổi signature thành `({ idFile, fetchFile = (idRef) => getFileByIdRefUseCase.execute(idRef), onLoaded = () => {} })` (2 prop tùy chọn mới, giá trị mặc định giữ đúng hành vi hiện tại cho `compliance-detail`); trong `loadFileData`, đổi `const response = await getFileByIdRefUseCase.execute(idFile);` thành `const response = await fetchFile(idFile);`; ngay sau `setFileData({ content, contentType, fileName })`, gọi thêm `onLoaded({ content, contentType, fileName })` — KHÔNG đổi bất kỳ logic render PDF/DOCX/XLSX/ảnh nào (research Quyết định 26).
- [X] T129 [P] [US5] Thêm hàm `getFileByIdRef: (fileId) => axiosInstance.get('/eutr-documents/get-file-by-idref', { params: { idRef: fileId } })` vào `compliance-client/src/infrastructure/api/eutrDocumentsApi.js`.
- [X] T130 [P] [US5] Thêm khai báo `async getFileByIdRef(_fileId) { throw new Error('Not implemented') }` vào `compliance-client/src/domain/interfaces/IEutrDocumentsRepository.js`.
- [X] T131 [US5] Implement `async getFileByIdRef(fileId) { const res = await eutrDocumentsApi.getFileByIdRef(fileId); return res.data; }` trong `compliance-client/src/infrastructure/repositories/RestEutrDocumentsRepository.js` (phải sau T129, T130).
- [X] T132 [P] [US5] Tạo `compliance-client/src/application/usecases/eutr-documents/GetEutrDocumentsFileByIdRefUseCase.js`: `execute(fileId) { return this.repository.getFileByIdRef(fileId); }` (mẫu `GetFileByIdRefUseCase` của compliances).
- [X] T133 [US5] Tạo `compliance-client/src/presentation/pages/eutr-documents/components/EutrFileViewerDialog.jsx`: `Dialog` MUI (`maxWidth="lg" fullWidth`, tiêu đề = prop `fileName`, nút Close) bọc `<FilePreviewer idFile={fileId} fetchFile={getEutrDocumentsFileByIdRefUseCase.execute} onLoaded={setLoadedFile} />`; nút **Download** (`disabled={!loadedFile}`) decode `loadedFile.content` (base64 → `Uint8Array`, cùng cách `FilePreviewer.renderPdf` đã làm) → `new Blob([...], { type: loadedFile.contentType })` → `URL.createObjectURL` → click 1 `<a download={loadedFile.fileName}>` tạm → `URL.revokeObjectURL` — KHÔNG gọi thêm API nào, KHÔNG tái dùng `DialogFilePreviewer.jsx`/`DownloadCompliancesUseCase` (research Quyết định 27; phải sau T128, T131, T132).
- [X] T134 [P] [US5] Sửa `compliance-client/src/presentation/pages/eutr-documents/components/EutrDocumentsActionCell.jsx`: icon View đổi từ `onClick={() => {}}` (silent no-op) thành nhận thêm prop `onView`, `onClick={() => onView(row)}`, `disabled={!row.fileId}`, `title={row.fileId ? 'View' : 'No file to view'}` (FR-042).
- [X] T135 [US5] Sửa `compliance-client/src/presentation/pages/eutr-documents/hooks/useEutrDocumentsColumns.jsx`: nhận thêm prop `onView` ở tham số hook, truyền xuống `<EutrDocumentsActionCell onView={onView} ... />` (phải sau T134).
- [X] T136 [US5] Sửa `compliance-client/src/presentation/pages/eutr-documents/index.jsx`: thêm state `viewerFile` (`{ open: false, fileId: null, fileName: '' }`); truyền `onView: (row) => setViewerFile({ open: true, fileId: row.fileId, fileName: row.name })` vào `useEutrDocumentsColumns`; render `<EutrFileViewerDialog open={viewerFile.open} fileId={viewerFile.fileId} fileName={viewerFile.fileName} onClose={() => setViewerFile((prev) => ({ ...prev, open: false }))} />` (phải sau T133, T135).
- [X] T137 [US2] Sửa `compliance-client/src/presentation/pages/eutr-documents/EutrDocumentsAdd.jsx`: thêm state `viewerFile` (giống T136); icon View trên mỗi dòng của bảng chi tiết List PO đổi từ `onClick={() => {}}` thành `onClick={() => setViewerFile({ open: true, fileId: doc.fileId, fileName: doc.fileName })}`; render `<EutrFileViewerDialog ... />` cạnh `CustomSnackbar` hiện có (phải sau T133, T127 — cần `doc.fileId` có giá trị thật từ backend).
- [X] T138 [US2] Trong cùng file `EutrDocumentsAdd.jsx`, thêm state `confirmDeleteDoc`/`confirmDeleteOpen`; icon Delete trên mỗi dòng của bảng chi tiết List PO đổi từ `onClick={() => {}}` thành mở `ConfirmDialog` xác nhận xóa (`content` nêu rõ tên file `doc.fileName`); khi xác nhận, gọi `deleteEutrDocumentsUseCase.execute(doc.documentId)` (dùng lại `DeleteEutrDocumentsUseCase`, khởi tạo cạnh các use case khác ở đầu file — KHÔNG tạo use case mới), sau đó refetch `poReferenceDocuments` của `selectedPo` hiện tại (gọi lại đúng logic đã có trong `useEffect` theo `selectedPoId`, ví dụ tách thành hàm `refreshPoReferenceDocuments` dùng lại ở cả hai nơi) — KHÔNG gọi bất kỳ API xóa file SharePoint nào (research Quyết định 28, FR-044; phải sau T137, cùng file).
- [X] T139 [P] [US5] Rà soát toàn bộ văn bản mới bằng tiếng Anh (FR-015): tooltip "No file to view", tiêu đề popup/nút "Download"/"Close" trong `EutrFileViewerDialog.jsx`, nội dung `ConfirmDialog` xóa file mới ở `EutrDocumentsAdd.jsx`. **Đã xác minh tĩnh**: `dotnet build` trên từng project `ComplianceSys.Domain`/`ComplianceSys.Application`/`ComplianceSys.Infrastructure` (0 lỗi mỗi project — build toàn `ComplianceSys.sln` bị khóa file do tiến trình `ComplianceSys.Api` đang chạy sẵn trên máy, không phải lỗi biên dịch, cùng tình trạng đã ghi ở T085/T121); `npx eslint` trên toàn bộ file mới/đã sửa (0 lỗi mới — 2 lỗi `no-unused-vars` còn lại trong `FilePreviewer.jsx` đã tồn tại từ trước, thuộc đoạn code Excel không liên quan tới thay đổi của Update 10); `npx vite build` (thành công, chunk `EutrDocumentsAdd` build đúng).
- [ ] T140 [US5] Kiểm thử thủ công theo [quickstart.md](./quickstart.md) kịch bản 6, 6a (icon View mở popup xem trước file thật khi có `FileId`, vô hiệu hóa khi không có `FileId`, popup xử lý lỗi thân thiện) trên `/eutr/documents`. Cần backend build lại (T123) và có sẵn ít nhất 1 document có `FileId` (Phase 12/13) lẫn 1 document không có `FileId` (tạo qua Save). **CHƯA chạy trong trình duyệt** — cần môi trường chạy đầy đủ (backend + DB + SharePoint), cùng điều kiện với T044/T052/T059/T062/T078/T089/T116/T117/T122.
- [ ] T141 [US2] Kiểm thử thủ công theo [quickstart.md](./quickstart.md) kịch bản 9r, 9s (View/Delete theo từng file trên bảng chi tiết List PO; xác nhận file KHÔNG bị xóa khỏi SharePoint sau Delete) trên `compliance-client/src/presentation/pages/eutr-documents/EutrDocumentsAdd.jsx`. Cần backend build lại (T123-T127), frontend build lại (T128-T138), và dữ liệu test giống T117 (PO có ≥ 2 file đã upload). **CHƯA chạy trong trình duyệt** — cùng điều kiện với T140.

**Checkpoint**: Icon View trên danh sách chính và trên bảng chi tiết List PO mở đúng popup xem
trước file thật (hoặc vô hiệu hóa khi không có file); Delete từng file trên List PO xóa đúng document
(kèm `eutr_references`) mà không xóa file thật trên SharePoint; toàn bộ CRUD US1-US4 và các phần
khác của trang Add (Update 3-9) không đổi.

---

## Phase 17: Update 11 - Screen2 "Upload manual" trở thành upload file thật + popup "Assign condition" gán Step/Conditions (User Story 6)

**Goal**: Khu "Drag and drop files to upload" ở Screen2 (silent no-op từ Update 3) trở thành khu
**Upload File** thật (luôn khả dụng, không cần chọn gì trước) — upload lên thư mục **cố định**
`{SharePointEutrPath}/UploadManual`, KHÔNG validate prefix, KHÔNG ghi `eutr_references`. Bảng danh
sách file bên dưới đổi từ dữ liệu mẫu sang danh sách **"chưa gán"** thật (mọi `eutr_documents`
KHÔNG có `eutr_references` nào — SQL `NOT EXISTS` tùy biến). Nút "Assign condition" mở popup mới
**`AssignConditionDialog.jsx`**: dòng "Step" cố định (bắt buộc) + các dòng "Conditions type" (PO/
Vendor, thêm qua "Add condition") với "Condition value" multi-select. Save ghi 1 dòng
`eutr_references` (`RefType=1`) + N dòng `eutr_reference_details` **cho mỗi** document đã chọn
(bảng `eutr_reference_details` **đã tồn tại sẵn** trong `eutr_db.sql` — KHÔNG migration DB mới).
Cột **Conditions** trên danh sách chính hiển thị dữ liệu thật cho Type="Upload manual" (spec
FR-046 đến FR-054, research Quyết định 29-40).

**Independent Test**: Xem [quickstart.md](./quickstart.md) kịch bản 10, 10a, 11, 11a, 11b.

### Backend — bảng con `eutr_reference_details` (đã tồn tại sẵn trong DDL, KHÔNG migration mới)

- [X] T142 [P] [US6] Tạo entity `compliance-sys-api/src/ComplianceSys.Domain/Entities/EutrReferenceDetails.cs` (`[Table("eutr_reference_details")]`, kế thừa `BaseEntity`: `Id: long`, `RefId: long?`, `ConditionType: byte?`, `ConditionValue: string?` — clone hình dạng `EutrReferences.cs`, research Quyết định 29).
- [X] T143 [P] [US6] Tạo `compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/EutrConditionGroupRow.cs` (projection phẳng `{ long DocumentId, byte ConditionType, string ConditionValue }` — kết quả thô của truy vấn JOIN `eutr_reference_details`+`eutr_references`).
- [X] T144 [P] [US6] Tạo `compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/ConditionGroupDto.cs` (`{ byte ConditionType, List<string> Values }` — dùng trong `EutrDocumentsResponseDto.Conditions`).
- [X] T145 [US6] Tạo interface `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Repositories/IEutrReferenceDetailsRepository.cs`: `Task<List<EutrConditionGroupRow>> GetGroupedConditionsByDocumentIdsAsync(IEnumerable<long> documentIds, CancellationToken ct = default);` + `Task DeleteByRefIdAsync(long refId, CancellationToken ct = default);` (phải sau T143, cần type `EutrConditionGroupRow`).
- [X] T146 [US6] Tạo `compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/EutrReferenceDetailsRepository.cs` (`DapperRepository<EutrReferenceDetails,long>`, implement `IEutrReferenceDetailsRepository` — SQL JOIN `eutr_reference_details d ON d.RefId = r.Id ... WHERE r.DocumentId IN @DocumentIds` cho method 1; `DELETE FROM eutr_reference_details WHERE RefId = @RefId` cho method 2, cùng style `Connection.ExecuteAsync`/`QueryAsync` + `CommandDefinition` của `EutrReferencesRepository`) (phải sau T142, T145).
- [X] T147 [US6] Đăng ký DI `services.AddScoped<IEutrReferenceDetailsRepository, EutrReferenceDetailsRepository>();` trong `compliance-sys-api/src/ComplianceSys.Infrastructure/DependencyInjection.cs` (phải sau T146).

### Backend — critical fix: dọn `eutr_reference_details` khi xóa document (tránh vi phạm khóa ngoại)

- [X] T148 [US6] Sửa SQL trong `compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/EutrReferencesRepository.cs`, method `DeleteByDocumentIdAsync` — đổi thành 2 câu lệnh trong cùng `CommandDefinition`/transaction: `DELETE FROM eutr_reference_details WHERE RefId IN (SELECT Id FROM eutr_references WHERE DocumentId = @DocumentId); DELETE FROM eutr_references WHERE DocumentId = @DocumentId;` — chữ ký method KHÔNG đổi (research Quyết định 30; phải làm **trước khi** `eutr_reference_details` có dữ liệu thật, tức trước T157).

### Backend — Upload File thật cho Screen2 (thư mục cố định, KHÔNG prefix, KHÔNG ghi `eutr_references`)

- [X] T149 [P] [US6] Tạo `compliance-sys-api/src/ComplianceSys.Application/Dtos/Request/EutrManualMultiUploadFileRequest.cs` (`{ List<IFormFile> Files }` — KHÔNG có `PoCode`, khác `EutrMultiUploadFileRequest`).
- [X] T150 [US6] Sửa `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Services/IEutrUploadService.cs`: + `Task<List<EutrUploadFileResultDto>> UploadManualMultipleToSharePointAndSaveDataAsync(EutrManualMultiUploadFileRequest request, string email, CancellationToken ct);` (phải sau T149).
- [X] T151 [US6] Sửa `compliance-sys-api/src/ComplianceSys.Application/Services/EutrUploadService.cs`: implement method trên — gọi `ResolveOrCreatePoFolderAsync(basePath, "UploadManual")` (tên hàm giữ nguyên, đổi tham số thành hằng chuỗi cố định), validate file qua `ValidateFile` hiện có (KHÔNG gọi `GetMatchingPrefixesAsync`), mỗi file thành công chỉ `_repository.AddAsync` 1 dòng `EutrDocuments` (`Name`, `FileId`, `ValidFrom`=hôm nay, `ValidTo`=`9999-12-31`) — KHÔNG mở transaction/ghi `EutrReferences` nào (research Quyết định 31; phải sau T150).
- [X] T152 [US6] Sửa `compliance-sys-api/src/ComplianceSys.Api/Controllers/SharepointController.cs`: thêm action `[HttpPost("eutr-upload-manual-multi")] [Consumes("multipart/form-data")]` nhận `[FromForm] EutrManualMultiUploadFileRequest request`, gọi `_eutrUploadService.UploadManualMultipleToSharePointAndSaveDataAsync(request, email, ct)` (dùng chung `[Authorize]` cấp controller, research Quyết định 32; phải sau T151).

### Backend — danh sách "chưa gán" (SQL `NOT EXISTS` tùy biến)

- [X] T153 [US6] Sửa `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Repositories/IEutrReferencesRepository.cs`: + `Task<PagedResult<EutrDocuments>> GetUnassignedDocumentsPagedAsync(PagedRequest request, CancellationToken ct = default);`.
- [X] T154 [US6] Sửa `compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/EutrReferencesRepository.cs`: implement method trên — clone khung paging tùy biến của `EutrMastersRepository.GetPagedWithStepNameAsync`/`EutrTemplatesRepository.GetPagedWithVendorNameAsync` (`SortMap`/`FilterMap` whitelist theo cột của `eutr_documents`, `LIMIT`/`OFFSET` + `COUNT` riêng), với `WHERE NOT EXISTS (SELECT 1 FROM eutr_references r WHERE r.DocumentId = d.Id)` **luôn áp dụng** (không thuộc filter người dùng) (research Quyết định 33; phải sau T153, độc lập với T148 dù cùng file — khác method, không conflict logic).
- [X] T155 [US6] Sửa `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Services/IEutrDocumentsService.cs`: + `Task<PagedResult<EutrDocumentsResponseDto>> GetUnassignedPagedAsync(PagedRequest request, CancellationToken ct = default);`.
- [X] T156 [US6] Sửa `compliance-sys-api/src/ComplianceSys.Application/Services/EutrDocumentsService.cs`: implement `GetUnassignedPagedAsync` — gọi `_referencesRepository.GetUnassignedDocumentsPagedAsync`, map sang `List<EutrDocumentsResponseDto>` qua `_mapper` (các field Step/Type/Conditions giữ giá trị mặc định rỗng/`null`) (phải sau T154, T155).

### Backend — cột Conditions trên danh sách chính (`EutrDocumentsResponseDto.Conditions`)

- [X] T157 [US6] Sửa `compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/EutrDocumentsResponseDto.cs`: + `public List<ConditionGroupDto> Conditions { get; set; } = [];` (phải sau T144).
- [X] T158 [US6] Sửa `compliance-sys-api/src/ComplianceSys.Application/Services/EutrDocumentsService.cs`: đổi tên `AttachStepInfoAsync` thành `AttachStepAndConditionInfoAsync`, thêm bước gọi `_referenceDetailsRepository.GetGroupedConditionsByDocumentIdsAsync(ids)` (cần inject thêm `IEutrReferenceDetailsRepository _referenceDetailsRepository` qua constructor), gộp theo `DocumentId` rồi theo `ConditionType` thành `List<ConditionGroupDto>`, gán vào `item.Conditions` — cập nhật cả lời gọi trong `GetPagedAsync` sang tên method mới (research Quyết định 39; phải sau T146, T147, T157, và sau T156 vì cùng file).

### Backend — popup Assign condition, chế độ tạo mới (`POST /assign-conditions`)

- [X] T159 [P] [US6] Tạo `compliance-sys-api/src/ComplianceSys.Application/Dtos/Request/EutrConditionRowDto.cs` (`{ byte ConditionType, List<string> Values }`).
- [X] T160 [US6] Tạo `compliance-sys-api/src/ComplianceSys.Application/Dtos/Request/EutrAssignConditionsRequestDto.cs` (`{ List<long> DocumentIds, long StepId, List<EutrConditionRowDto> Conditions }`) (phải sau T159).
- [X] T161 [US6] Tạo `compliance-sys-api/src/ComplianceSys.Application/Validators/EutrAssignConditionsRequestDtoValidator.cs` (`BaseValidator<EutrAssignConditionsRequestDto>`: `DocumentIds` NotEmpty; `StepId` GreaterThan(0); `Conditions` NotEmpty + mỗi dòng `Values` NotEmpty — FR-052) (phải sau T160).
- [X] T162 [US6] Tạo interface `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Services/IEutrConditionAssignmentService.cs`: `Task AssignConditionsAsync(EutrAssignConditionsRequestDto request, string email, CancellationToken ct = default);` (phải sau T160).
- [X] T163 [US6] Tạo `compliance-sys-api/src/ComplianceSys.Application/Services/EutrConditionAssignmentService.cs` (constructor DI: `IRepository<EutrReferences,long>`, `IRepository<EutrReferenceDetails,long>`, `IUnitOfWork`) — implement `AssignConditionsAsync`: với mỗi `DocumentId`, 1 transaction riêng (mẫu per-item Quyết định 24/34) — insert 1 `EutrReferences` (`DocumentId`, `StepId`, `RefType=1`, `RefValue=null`), rồi với mỗi `Conditions[].Values`, insert 1 `EutrReferenceDetails` (`RefId`=Id vừa tạo, `ConditionType`, `ConditionValue`); gom lỗi per-document, không chặn document khác (research Quyết định 34; phải sau T142, T162).
- [X] T164 [US6] Đăng ký DI trong `compliance-sys-api/src/ComplianceSys.Application/DependencyInjection.cs`: `services.AddScoped<IEutrConditionAssignmentService, EutrConditionAssignmentService>();` + `services.AddScoped<IValidator<EutrAssignConditionsRequestDto>, EutrAssignConditionsRequestDtoValidator>();` (phải sau T161, T163).
- [X] T165 [US6] Sửa `compliance-sys-api/src/ComplianceSys.Api/Controllers/EutrDocumentsController.cs`: thêm constructor param `IEutrConditionAssignmentService _conditionAssignmentService`; thêm action `[Authorize(Policy = "EutrDocuments.ReadAll")] [HttpPost("get-unassigned")] GetUnassigned(page, pageSize, sortColumn, sortOrder, [FromBody] List<FilterRequest>? filters, ct)` (gọi `_eutrDocumentsService.GetUnassignedPagedAsync`, clone action `GetPaged` hiện có) + action `[Authorize(Policy = "EutrDocuments.Update")] [HttpPost("assign-conditions")] AssignConditions([FromBody] EutrAssignConditionsRequestDto dto, ct)` (gọi `_conditionAssignmentService.AssignConditionsAsync`) (phải sau T156, T164).

### Frontend — hằng số + hạ tầng SharePoint/repository

- [X] T166 [P] [US6] Sửa `compliance-client/src/utils/helpers.js`: + `export const CONDITION_TYPE_OPTIONS = [{ value: 15, label: 'PO' }, { value: 14, label: 'Vendor' }];` (cạnh `TAKE_FROM_OPTIONS`).
- [X] T167 [P] [US6] Sửa `compliance-client/src/domain/interfaces/ISharePointRepository.js`: + `uploadEutrManualFilesMulti(_files) { throw new Error('Method not implemented'); }`.
- [X] T168 [US6] Sửa `compliance-client/src/infrastructure/repositories/RestSharePointRepository.js`: implement `uploadEutrManualFilesMulti(files)` — `FormData` chỉ field `files[]` (không `poCode`) → `POST /sharepoint/eutr-upload-manual-multi` (phải sau T167).
- [X] T169 [US6] Sửa `compliance-client/src/application/usecases/sharepoint/UploadToSharePointUseCase.js`: + `executeManualMulti(files) { return this.sharePointRepository.uploadEutrManualFilesMulti(files); }` (phải sau T168).
- [X] T170 [P] [US6] Sửa `compliance-client/src/domain/interfaces/IEutrDocumentsRepository.js`: + `getUnassigned(_page,_pageSize,_sortColumn,_sortOrder,_payload)`, `assignConditions(_payload) { throw new Error('Method not implemented'); }`.
- [X] T171 [P] [US6] Sửa `compliance-client/src/infrastructure/api/eutrDocumentsApi.js`: + `getUnassigned(page,pageSize,sortColumn,sortOrder,payload) -> POST /eutr-documents/get-unassigned`; + `assignConditions(payload) -> POST /eutr-documents/assign-conditions`.
- [X] T172 [US6] Sửa `compliance-client/src/infrastructure/repositories/RestEutrDocumentsRepository.js`: implement 2 method trên (phải sau T170, T171).
- [X] T173 [P] [US6] Tạo `compliance-client/src/application/usecases/eutr-documents/GetEutrDocumentsUnassignedUseCase.js` (`execute(page,pageSize,sortColumn,sortOrder,payload) { return this.repository.getUnassigned(...); }`) (phải sau T172).
- [X] T174 [P] [US6] Tạo `compliance-client/src/application/usecases/eutr-documents/AssignEutrConditionsUseCase.js` (`execute(payload) { return this.repository.assignConditions(payload); }`) (phải sau T172).

### Frontend — popup `AssignConditionDialog` (chế độ tạo mới) + Screen2 thật

- [X] T175 [US6] Tạo `compliance-client/src/presentation/pages/eutr-documents/components/AssignConditionDialog.jsx`: props `{ open, mode: 'create', documents, onClose, onSaved }`; state `stepId`, `conditionRows` (mảng `{ rowId, conditionType, values }`); dòng "Step" cố định ở đầu (dropdown từ `GetEutrStepsUseCase`, gọi 1 lần khi `open`); nút "Add condition" (`handleAddConditionRow`, clone state machine `ComplianceMasterForm.jsx`) thêm dòng mới; mỗi dòng: `<Select>` "Conditions type" (options `CONDITION_TYPE_OPTIONS`) + `<ReferenceObjectMultiAutocomplete referenceType={row.conditionType} value={row.values} onChange={...} />` cho "Condition value"; icon Delete xóa dòng (không áp dụng dòng Step); Save validate Step đã chọn + ≥1 dòng Conditions type có ≥1 giá trị (chặn kèm lỗi nếu thiếu — FR-052/Update 13), gọi `assignEutrConditionsUseCase.execute({ documentIds: documents.map(d => d.id), stepId, conditions: conditionRows.map(r => ({ conditionType: r.conditionType, values: r.values.map(v => v.code ?? v.id) })) })`, `onSaved()` + `onClose()` khi thành công (research Quyết định 36/37; phải sau T166, T174).
- [X] T176 [US6] Sửa `compliance-client/src/presentation/pages/eutr-documents/hooks/useEutrDocumentsColumns.jsx`: cột `"conditions"` đổi từ khai báo trống sang `renderCell` — `.map()` qua `row.conditions`, mỗi nhóm hiển thị `"{label}: {values.join(', ')}"` (label tra `CONDITION_TYPE_OPTIONS` theo `conditionType`) (research Quyết định 39; phải sau T166).
- [X] T177 [US6] Sửa `compliance-client/src/presentation/pages/eutr-documents/EutrDocumentsAdd.jsx` (Screen2, nhánh `takeFrom === TAKE_FROM_OPTIONS[1].value`): bỏ `DEMO_FILE_LIST` + handler no-op; thêm state `unassignedFiles`/`selectedUnassignedIds`; `useEffect` gọi `getEutrDocumentsUnassignedUseCase.execute()` khi `takeFrom` đổi sang "Upload manual" (mẫu effect đã có cho `fetchPoList` ở Screen1); clone khối JSX khu "Upload File" của Screen1 nhưng **bỏ** điều kiện `opacity`/`pointerEvents` theo PO (luôn khả dụng), đổi hàm xử lý file sang gọi `uploadToSharePointUseCase.executeManualMulti(files)` (research Quyết định 40; phải sau T169, T173, cùng file với T112/T113/T137/T138).
- [X] T178 [US6] Trong cùng file `EutrDocumentsAdd.jsx`, bảng danh sách file Screen2: `.map()` qua `unassignedFiles` (checkbox `selectedUnassignedIds`), icon View/Delete mỗi dòng dùng lại đúng cơ chế đã có ở List PO (`EutrFileViewerDialog`/`ConfirmDialog`/`deleteEutrDocumentsUseCase`, refetch `unassignedFiles` sau khi xóa); nút "Assign condition" `disabled={selectedUnassignedIds.length === 0}`, `onClick` mở `AssignConditionDialog` `mode="create"` với `documents = unassignedFiles.filter(f => selectedUnassignedIds.includes(f.id))`; `onSaved` gọi lại `getEutrDocumentsUnassignedUseCase.execute()` để refetch (phải sau T175, T177, cùng file).
- [X] T179 [P] [US6] Rà soát toàn bộ văn bản mới bằng tiếng Anh (FR-015): "Upload File", "Add condition", "Conditions type", "Condition value", "Step" trong `AssignConditionDialog.jsx`/`EutrDocumentsAdd.jsx`.
- [ ] T180 [US6] Kiểm thử thủ công theo [quickstart.md](./quickstart.md) kịch bản 10, 10a, 11, 11a, 11b trên `/eutr/documents` (Type = "Upload manual"). Cần backend build lại (T142-T165) và DB có sẵn dữ liệu `eutr_steps`. **CHƯA chạy trong trình duyệt** — cùng điều kiện với các kịch bản trước.

**Checkpoint**: Screen2 upload file thật, danh sách "chưa gán" tải đúng, popup Assign condition tạo
mới hoạt động end-to-end (Step + Conditions bắt buộc), cột Conditions trên danh sách chính hiển thị
đúng; toàn bộ CRUD US1-US5 và Update 3-10 không đổi.

---

## Phase 18: Update 12 - Edit (User Story 3) rẽ nhánh theo Type: PO thêm sửa Step, Upload manual mở lại popup Assign condition để sửa

**Goal**: Edit trên danh sách chính rẽ nhánh theo `refType`: Type="PO" giữ popup đơn giản + thêm
trường Step (single-select, thay thế toàn bộ tập `eutr_references` cũ); Type="Upload manual" mở lại
**chính** `AssignConditionDialog.jsx` (Phase 17) ở chế độ sửa (cập nhật `StepId` trực tiếp + replace
toàn bộ `eutr_reference_details`); Type trống không đổi (spec FR-055 đến FR-058, research Quyết
định 34/38).

**Independent Test**: Xem [quickstart.md](./quickstart.md) kịch bản 12, 13.

### Backend

- [X] T181 [P] [US3] Tạo `compliance-sys-api/src/ComplianceSys.Application/Dtos/Request/EutrUpdateConditionAssignmentRequestDto.cs` (`{ long StepId, List<EutrConditionRowDto> Conditions }`).
- [X] T182 [P] [US3] Tạo `compliance-sys-api/src/ComplianceSys.Application/Dtos/Request/EutrUpdatePoStepRequestDto.cs` (`{ long StepId }`).
- [X] T183 [P] [US3] Tạo `compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/EutrDocumentConditionAssignmentDto.cs` (`{ long? StepId, List<EutrConditionRowDto> Conditions }`).
- [X] T184 [US3] Tạo `compliance-sys-api/src/ComplianceSys.Application/Validators/EutrUpdateConditionAssignmentRequestDtoValidator.cs` (cùng rule `EutrAssignConditionsRequestDtoValidator`: `StepId` GreaterThan(0), `Conditions` NotEmpty + mỗi dòng `Values` NotEmpty) (phải sau T181).
- [X] T185 [US3] Sửa `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Services/IEutrConditionAssignmentService.cs`: + `Task<EutrDocumentConditionAssignmentDto> GetConditionAssignmentAsync(long documentId, CancellationToken ct = default);` + `Task UpdateConditionAssignmentAsync(long documentId, EutrUpdateConditionAssignmentRequestDto request, string email, CancellationToken ct = default);` + `Task UpdatePoStepAsync(long documentId, long stepId, string email, CancellationToken ct = default);` (phải sau T181, T183).
- [X] T186 [US3] Sửa `compliance-sys-api/src/ComplianceSys.Application/Services/EutrConditionAssignmentService.cs`: implement `GetConditionAssignmentAsync` (đọc 1 `EutrReferences` `RefType=1` của document + `GetGroupedConditionsByDocumentIdsAsync([documentId])`, nhóm thành `Conditions`); `UpdateConditionAssignmentAsync` (1 transaction: `UpdateAsync` đổi `StepId` của `EutrReferences` hiện có, `DeleteByRefIdAsync(refId)` rồi insert lại từ đầu `EutrReferenceDetails` mới — replace toàn bộ, research Quyết định 34); `UpdatePoStepAsync` (1 transaction: lấy `RefValue` từ dòng `RefType=0` có `Id` nhỏ nhất, xóa toàn bộ dòng `RefType=0` của document, insert đúng 1 dòng mới với `StepId` mới + `RefValue` giữ nguyên) (phải sau T185, T146 (repo details), T148 (SQL cascade đã sửa)).
- [X] T187 [US3] Sửa `compliance-sys-api/src/ComplianceSys.Api/Controllers/EutrDocumentsController.cs`: + `[Authorize(Policy = "EutrDocuments.ReadOne")] [HttpGet("{id:long}/condition-assignment")] GetConditionAssignment(long id, ct)`; + `[Authorize(Policy = "EutrDocuments.Update")] [HttpPut("{id:long}/condition-assignment")] UpdateConditionAssignment(long id, [FromBody] EutrUpdateConditionAssignmentRequestDto dto, ct)`; + `[Authorize(Policy = "EutrDocuments.Update")] [HttpPut("{id:long}/step")] UpdatePoStep(long id, [FromBody] EutrUpdatePoStepRequestDto dto, ct)` (phải sau T182, T184, T186).
- [X] T188 [US3] Đăng ký DI validator mới trong `compliance-sys-api/src/ComplianceSys.Application/DependencyInjection.cs`: `services.AddScoped<IValidator<EutrUpdateConditionAssignmentRequestDto>, EutrUpdateConditionAssignmentRequestDtoValidator>();` (phải sau T184).

### Frontend

- [X] T189 [P] [US3] Sửa `compliance-client/src/domain/interfaces/IEutrDocumentsRepository.js`: + `getConditionAssignment(_id)`, `updateConditionAssignment(_id,_payload)`, `updatePoStep(_id,_stepId) { throw new Error('Method not implemented'); }`.
- [X] T190 [P] [US3] Sửa `compliance-client/src/infrastructure/api/eutrDocumentsApi.js`: + `getConditionAssignment(id) -> GET /eutr-documents/{id}/condition-assignment`; + `updateConditionAssignment(id,payload) -> PUT .../condition-assignment`; + `updatePoStep(id,stepId) -> PUT /eutr-documents/{id}/step`.
- [X] T191 [US3] Sửa `compliance-client/src/infrastructure/repositories/RestEutrDocumentsRepository.js`: implement 3 method trên (phải sau T189, T190).
- [X] T192 [P] [US3] Tạo `compliance-client/src/application/usecases/eutr-documents/GetEutrDocumentConditionAssignmentUseCase.js` (phải sau T191).
- [X] T193 [P] [US3] Tạo `compliance-client/src/application/usecases/eutr-documents/UpdateEutrConditionAssignmentUseCase.js` (phải sau T191).
- [X] T194 [P] [US3] Tạo `compliance-client/src/application/usecases/eutr-documents/UpdateEutrDocumentPoStepUseCase.js` (phải sau T191).
- [X] T195 [US3] Sửa `compliance-client/src/presentation/pages/eutr-documents/components/AssignConditionDialog.jsx`: hỗ trợ thêm `mode="edit"` — nhận thêm prop `documentId`, `initialStepId`, `initialConditions` (nạp sẵn `stepId`/`conditionRows` khi `open` ở mode này); phần danh sách file trên cùng hiển thị đúng 1 file (`documents` có 1 phần tử, read-only, không checkbox — không đổi so với create); Save gọi `updateEutrConditionAssignmentUseCase.execute(documentId, { stepId, conditions })` thay vì `assignEutrConditionsUseCase` khi `mode === 'edit'` (phải sau T175 (Phase 17), T193).
- [X] T196 [US3] Sửa `compliance-client/src/presentation/pages/eutr-documents/components/EutrDocumentsModal.jsx`: khi `open` và `initialData?.refType === TAKE_FROM_OPTIONS[0].value` (PO), render thêm 1 `<Autocomplete>`/`<Select>` "Step" (options từ `GetEutrStepsUseCase`, gọi 1 lần khi mount, `value` = Step khớp `initialData.stepId`); Save: sau khi `onSubmit` (File name/Valid from/Valid to) thành công, gọi thêm `updateEutrDocumentPoStepUseCase.execute(initialData.id, stepId)` (2 lời gọi độc lập cho 1 lượt Save) (phải sau T194).
- [X] T197 [US3] Sửa `compliance-client/src/presentation/pages/eutr-documents/index.jsx`: `onEdit` rẽ nhánh theo `row.refType` — `0` (PO): giữ `setModalData(row); setModalOpen(true)` (không đổi, popup nay có Step nhờ T196); `1` (Upload manual): gọi `getEutrDocumentConditionAssignmentUseCase.execute(row.id)` rồi mở `AssignConditionDialog` `mode="edit"` với `documentId=row.id`, `documents=[{id: row.id, fileName: row.name}]`, `initialStepId`/`initialConditions` từ kết quả; `null`/`undefined`: không đổi (phải sau T192, T195).
- [X] T198 [P] [US3] Rà soát toàn bộ văn bản mới bằng tiếng Anh (FR-015): trường "Step" trong `EutrDocumentsModal.jsx`, chế độ sửa của `AssignConditionDialog.jsx`.
- [ ] T199 [US3] Kiểm thử thủ công theo [quickstart.md](./quickstart.md) kịch bản 12, 13 trên `/eutr/documents`. Cần backend build lại (T181-T188) và ít nhất 1 document Type="PO" + 1 document Type="Upload manual" (từ Phase 17). **CHƯA chạy trong trình duyệt** — cùng điều kiện với các kịch bản trước.

**Checkpoint**: Edit mở đúng UI theo Type của document; sửa Step (PO) và sửa Step/Conditions (Upload
manual) hoạt động end-to-end, phản ánh đúng trên cột Step name/Conditions của danh sách chính; Type
trống không đổi; toàn bộ US1-US6 và Update 3-11 không đổi.

---

## Phase 19: Update 13 - `/speckit-clarify` (quy tắc xác định Step hiện tại + chặn trùng Conditions type)

**Goal**: (1) Dropdown Step ở popup Edit (Type="PO") hiển thị đúng Step ứng với bản ghi
`eutr_references` có `Id` **nhỏ nhất** khi document liên kết nhiều Step (deterministic). (2) Popup
Assign condition (cả 2 chế độ) KHÔNG cho phép 2 dòng cùng Conditions type — dropdown tự loại bỏ
type đã dùng ở dòng khác + validator backend chặn trùng lặp trong 1 request (spec FR-051/FR-055).

**Independent Test**: Xem [quickstart.md](./quickstart.md) kịch bản 11b (đoạn kiểm tra dropdown
disable trùng type) và 12 (đoạn kiểm tra Step hiển thị đúng khi có nhiều Step).

### Backend

- [X] T200 [US3] Sửa `compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/EutrReferenceStepInfo.cs`: + `public long ReferenceId { get; set; }` (= `eutr_references.Id`, dùng để suy `StepId` hiện tại theo `Id` nhỏ nhất).
- [X] T201 [US3] Sửa `compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/EutrReferencesRepository.cs`: trong `GetStepInfoByDocumentIdsAsync`, thêm `r.Id AS ReferenceId` vào `SELECT` (phải sau T200).
- [X] T202 [US3] Sửa `compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/EutrDocumentsResponseDto.cs`: + `public long? StepId { get; set; }`.
- [X] T203 [US3] Sửa `compliance-sys-api/src/ComplianceSys.Application/Services/EutrDocumentsService.cs`: trong `AttachStepAndConditionInfoAsync`, gán thêm `item.StepId = info.OrderBy(x => x.ReferenceId).FirstOrDefault()?.StepId` (theo nhóm `DocumentId`, giữ nguyên `StepNames`/`RefType`/`Conditions` đã tính) (phải sau T201, T202, T158).
- [X] T204 [P] [US3] Sửa `compliance-sys-api/src/ComplianceSys.Application/Validators/EutrAssignConditionsRequestDtoValidator.cs`: + `RuleFor(x => x.Conditions).Must(c => c.Select(x => x.ConditionType).Distinct().Count() == c.Count).WithMessage("Duplicate Conditions type is not allowed");` (FR-051).
- [X] T205 [P] [US3] Sửa `compliance-sys-api/src/ComplianceSys.Application/Validators/EutrUpdateConditionAssignmentRequestDtoValidator.cs`: + cùng rule trên.

### Frontend

- [X] T206 [US3] Sửa `compliance-client/src/presentation/pages/eutr-documents/components/AssignConditionDialog.jsx`: mỗi `<MenuItem>` của dropdown "Conditions type" — + `disabled={conditionRows.some(r => r.rowId !== row.rowId && r.conditionType === option.value)}` (clone `ComplianceMasterForm.jsx`) (phải sau T175, T195).
- [X] T207 [P] [US3] Rà soát văn bản lỗi mới bằng tiếng Anh: "Duplicate Conditions type is not allowed" (hoặc thông báo tương đương hiển thị trên UI khi validator backend trả lỗi).
- [ ] T208 [US3] Kiểm thử thủ công theo [quickstart.md](./quickstart.md) kịch bản 11b (dropdown Conditions type disable đúng type đã dùng) và 12 (dropdown Step hiển thị đúng Step khi có nhiều Step liên kết). **CHƯA chạy trong trình duyệt** — cùng điều kiện với các kịch bản trước.

**Checkpoint**: Dropdown Step ở Edit (PO) luôn hiển thị đúng 1 giá trị xác định; popup Assign
condition không cho tạo 2 dòng cùng Conditions type (cả UI và validator backend); toàn bộ US1-US6
và Update 3-12 không đổi.

---

## Phase 20: Update 14 - Cột Type trên danh sách lấy nhãn thật từ bảng `eutr_reference_types`

**Goal**: Cột **Type** trên danh sách EUTR documents chính (User Story 1) hiển thị nhãn lấy từ bảng
`eutr_reference_types` (JOIN `RefType` với `Id`, trả `Name`) thay vì tra hằng số front-end
`TAKE_FROM_OPTIONS` (spec FR-034, Update 14). Seed đúng 2 dòng cố định `Id=0`→"PO"/`Id=1`→"Upload
manual" để khớp `RefType` đã ghi sẵn từ Update 7/11, không làm mất nhãn dữ liệu hiện có. Dropdown
Type ở trang Add (FR-016) và rẽ nhánh Edit theo `refType` (FR-055/FR-056) KHÔNG đổi.

**Independent Test**: Xem [quickstart.md](./quickstart.md) kịch bản 14 (response `get-all` có
`typeName`; cột Type trên grid hiển thị đúng "PO"/"Upload manual"/trống theo dữ liệu thật; dropdown
Type ở trang Add không đổi hành vi).

### Backend

- [X] T209 [US1] Tạo migration mới `compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Migration/14_seed_eutr_reference_types.sql`: `CREATE TABLE IF NOT EXISTS eutr_reference_types` (khớp đúng định nghĩa trong `docs/design/eutr/eutr_db.sql` — phòng vệ trường hợp bảng chưa được tạo ở môi trường đích, xem research Quyết định 41); bật tạm `SET SESSION SQL_MODE = CONCAT(@@SQL_MODE, ',NO_AUTO_VALUE_ON_ZERO')`, `INSERT INTO eutr_reference_types (Id, Name, CreatedBy, CreatedDate) VALUES (0, 'PO', 'system', NOW()) ON DUPLICATE KEY UPDATE Name = VALUES(Name);` và cùng câu cho `(1, 'Upload manual', ...)`, rồi khôi phục `sql_mode` cũ — KHÔNG tự thêm FK `eutr_references_reftype_foreign` (giả định đã có từ rollout feature `006-eutr-reference-types`).
- [X] T210 [P] [US1] Sửa `compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/EutrReferenceStepInfo.cs`: + `public string? TypeName { get; set; }` (nhãn Type nạp qua JOIN `eutr_reference_types.Name` theo `RefType`).
- [X] T211 [US1] Sửa `compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/EutrReferencesRepository.cs`: trong `GetStepInfoByDocumentIdsAsync`, thêm `LEFT JOIN eutr_reference_types t ON t.Id = r.RefType` và `t.Name AS TypeName` vào `SELECT` hiện có (phải sau T210).
- [X] T212 [P] [US1] Sửa `compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/EutrDocumentsResponseDto.cs`: + `public string? TypeName { get; set; }`.
- [X] T213 [US1] Sửa `compliance-sys-api/src/ComplianceSys.Application/Services/EutrDocumentsService.cs`: trong `AttachStepAndConditionInfoAsync`, mở rộng tuple group-theo-`DocumentId` hiện có để lấy thêm `TypeName: x.Select(y => y.TypeName).FirstOrDefault()` và gán `item.TypeName = info.TypeName;` (giữ nguyên `StepNames`/`RefType`/`StepId`/`Conditions` đã tính) (phải sau T211, T212).

### Frontend

- [X] T214 [US1] Sửa `compliance-client/src/presentation/pages/eutr-documents/hooks/useEutrDocumentsColumns.jsx`: cột `type` — đổi `valueGetter` từ `TAKE_FROM_OPTIONS.find((opt) => opt.value === row.refType)?.label || ""` sang `row.typeName || ""`; xóa import `TAKE_FROM_OPTIONS` khỏi file này nếu không còn dùng ở cột nào khác (phải sau T213 để có dữ liệu thật trả về từ backend). **Đã xác minh tĩnh**: `npx eslint` (0 lỗi), `npx vite build` (thành công).
- [ ] T215 [US1] Kiểm thử thủ công theo [quickstart.md](./quickstart.md) kịch bản 14 trên `/eutr/documents`. Cần chạy migration T209, backend build lại (T209-T213), frontend build lại (T214), và có sẵn ít nhất 1 document Type="PO" (Phase 12/13) và 1 document Type="Upload manual" (Phase 17). **Đã xác minh tĩnh** (T209-T214): `dotnet build` trên từng project `ComplianceSys.Domain`/`ComplianceSys.Application`/`ComplianceSys.Infrastructure` (0 lỗi mỗi project); `npx eslint` (0 lỗi); `npx vite build` (thành công). **CHƯA chạy trong trình duyệt** — cần môi trường chạy đầy đủ (backend + DB + dữ liệu test, migration T209 đã áp dụng), cùng điều kiện với T044/T052/T059/T062/T078/T089/T116/T117/T122/T140/T141/T180/T199/T208.

**Checkpoint**: Cột Type trên danh sách EUTR documents hiển thị đúng nhãn thật từ
`eutr_reference_types` cho mọi document có `eutr_references` liên kết; document không có liên kết
tiếp tục hiển thị trống; dropdown Type ở trang Add và Edit rẽ nhánh theo Type không đổi; toàn bộ
US1-US6 và Update 3-13 không đổi.

---

## Phase 21: Update 15/16 - Popup Add hợp nhất Type/Step/Value/Upload thay cho trang Add cũ (User Story 7)

**Goal**: Nút **Add** mở một **popup** ("Add EUTR documents") thay cho điều hướng sang trang riêng
`/eutr/documents/add` — Type lấy TOÀN BỘ bản ghi từ `eutr_reference_types` (không giới hạn 2 lựa
chọn hard-coded); Step bắt buộc; Value hiển thị gợi ý PO (`refType=15`) khi Type khớp "PO"/
"Invoice"/"Delivery note", gợi ý Vendor (`refType=14`) khi Type = "Vendor", nhập tự do cho Type khác;
hỗ trợ chọn từ gợi ý/gõ tay/dán nhiều giá trị (tách theo dấu phẩy/xuống dòng) thành chip, giới hạn
đúng 1 chip cho Type="PO"/"Vendor"; nút Upload (khả dụng khi đủ Type+Step+≥1 chip) upload nhiều file
vào thư mục SharePoint suy theo Type, tạo 1 `eutr_documents` + N `eutr_references` (N=số chip) mỗi
file, rồi popup tự đóng. `EutrDocumentsAdd.jsx`/route `/eutr/documents/add` giữ nguyên, không xóa,
không còn liên kết từ toolbar; Edit (US3) không đổi (spec FR-059 đến FR-070).

**Independent Test**: Xem [quickstart.md](./quickstart.md) kịch bản 15 (+ 15a-15e) — nhấn Add mở
popup (không điều hướng trang); Type="PO" giới hạn 1 chip + gợi ý `refType=15`; Type="Invoice"/
"Delivery note" nhiều chip cùng nguồn gợi ý PO; Type="Vendor" 1 chip + gợi ý `refType=14`; Type khác
(vd. "General agreement") nhập tự do không gọi API; dán "PO1, PO2\nPO3" chỉ nhận giá trị khớp dữ
liệu thật; Upload tạo đúng document + N `eutr_references` theo đúng `RefType`=`Id` của Type đã chọn
và đúng thư mục SharePoint; popup tự đóng sau Upload; Edit không đổi hành vi.

### Backend (mở rộng `EutrUploadService`/`SharepointController` đã có — KHÔNG migration DB mới, KHÔNG entity/repository mới)

- [X] T216 [P] [US7] Tạo `compliance-sys-api/src/ComplianceSys.Application/Dtos/Request/EutrTypeMultiUploadFileRequest.cs`: `{ List<IFormFile> Files, long TypeId, string TypeName, long StepId, List<string> RefValues }` — `[FromForm]`, `[Required]` trên `Files`/`TypeName`/`RefValues` (mẫu `EutrMultiUploadFileRequest`).
- [X] T217 [US7] Sửa `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Services/IEutrUploadService.cs`: + `Task<List<EutrUploadFileResultDto>> UploadMultipleForReferenceTypeAsync(EutrTypeMultiUploadFileRequest request, string email, CancellationToken ct);` (phải sau T216, và sau T150 vì cùng file).
- [X] T218 [US7] Sửa `compliance-sys-api/src/ComplianceSys.Application/Services/EutrUploadService.cs`: implement `UploadMultipleForReferenceTypeAsync` — thêm hàm private `ResolveFolderName(string typeName, List<string> refValues)` (so khớp `typeName` không phân biệt hoa/thường: "po"/"vendor" → `refValues[0]`; "invoice" → "Invoice"; "delivery note" → "DeliveryNote"; "general agreement" → "GeneralAgreement"; else → `typeName.Replace(" ", "")`), gọi `ResolveOrCreatePoFolderAsync(basePath, folderName)` đã có (research Quyết định 43); với mỗi file hợp lệ (`ValidateFile` đã có, KHÔNG gọi `GetMatchingPrefixesAsync`): 1 transaction ghi 1 `EutrDocuments` (giống `UploadMultipleToSharePointAndSaveDataAsync`) rồi với mỗi giá trị trong `request.RefValues`, `AddAsync` 1 `EutrReferences { DocumentId = documentId, StepId = request.StepId, RefType = (byte)request.TypeId, RefValue = value }` — rollback cả nhóm nếu bất kỳ bước nào lỗi (research Quyết định 42, FR-068; phải sau T217, T151 vì cùng file).
- [X] T219 [US7] Sửa `compliance-sys-api/src/ComplianceSys.Api/Controllers/SharepointController.cs`: thêm action `[HttpPost("eutr-upload-multi-by-type")] [Consumes("multipart/form-data")]` nhận `[FromForm] EutrTypeMultiUploadFileRequest request`, lấy `userEmail` từ `HttpContext.Items["UserEmail"]`, gọi `_eutrUploadService.UploadMultipleForReferenceTypeAsync(request, userEmail, ct)`, trả `Ok(ApiResponse<List<EutrUploadFileResultDto>>.Ok(result, "Upload files successfully"))` — dùng chung `[Authorize]` cấp controller, không policy riêng (research Quyết định 44; phải sau T218, T152 vì cùng file).

### Frontend (component mới cho popup Add — KHÔNG sửa `ReferenceObjectMultiAutocomplete.jsx`/`AssignConditionDialog.jsx` dùng chung)

- [X] T220 [P] [US7] Sửa `compliance-client/src/domain/interfaces/ISharePointRepository.js`: + `async uploadEutrFilesMultiByType(_files, _typeId, _typeName, _stepId, _refValues) { throw new Error('Method not implemented'); }`.
- [X] T221 [US7] Sửa `compliance-client/src/infrastructure/repositories/RestSharePointRepository.js`: implement `uploadEutrFilesMultiByType(files, typeId, typeName, stepId, refValues)` — dựng `FormData` (`files[]`, `typeId`, `typeName`, `stepId`, `refValues[]`) rồi `axiosInstance.post('/sharepoint/eutr-upload-multi-by-type', formData, { headers: { 'Content-Type': 'multipart/form-data' } })`, trả `response.data.data` (phải sau T220, T169 vì cùng file).
- [X] T222 [US7] Sửa `compliance-client/src/application/usecases/sharepoint/UploadToSharePointUseCase.js`: + `async executeEutrMultiByType(files, typeId, typeName, stepId, refValues) { return await this.sharePointRepository.uploadEutrFilesMultiByType(files, typeId, typeName, stepId, refValues); }` (phải sau T221, T169 vì cùng file).
- [X] T223 [P] [US7] Tạo `compliance-client/src/presentation/pages/eutr-documents/components/EutrAddValueAutocomplete.jsx`: props `{ type, value, onChange }` — nếu `type?.name` (lowercase, trim) thuộc `{"po","invoice","delivery note"}` dùng `useReferenceObjects()` với `referenceType=15`; thuộc `{"vendor"}` dùng `referenceType=14`; else `Autocomplete multiple freeSolo` thuần không gọi API. `onPaste`: `event.preventDefault()`, đọc `event.clipboardData.getData('text')`, tách theo `/[\n,]+/` rồi `.map(s => s.trim()).filter(Boolean)`; với Type có nguồn gợi ý, `await fetchReferenceObjects(refType, token)` cho từng token rồi giữ token khớp `code` chính xác (không phân biệt hoa/thường, research Quyết định 46); với Type không có nguồn, thêm thẳng token làm chip (không khử trùng lặp). Khi `type?.name` (lowercase) thuộc `{"po","vendor"}` và `value.length >= 1`: chặn mọi thao tác thêm giá trị mới (chọn gợi ý/gõ tay/dán), hiển thị `helperText` yêu cầu xóa chip hiện có trước (research Quyết định 47/48, FR-062 đến FR-065).
- [X] T224 [US7] Tạo `compliance-client/src/presentation/pages/eutr-documents/components/EutrDocumentsAddDialog.jsx`: `Dialog` tiêu đề "Add EUTR documents" — `Autocomplete` đơn **Type** (`GetEutrReferenceTypesUseCase.execute()`, `GET /api/eutr-reference-types`); `Autocomplete` đơn **Step** (`GetEutrStepsUseCase.execute()`, `GET /api/eutr-steps`); `<EutrAddValueAutocomplete type={type} value={chips} onChange={setChips} />` (T223); đổi `type` → `setChips([])` (reset); nút **Upload** disabled khi thiếu `type`/`step`/`chips.length===0`, mở `<input type="file" multiple hidden>`, validate đuôi/kích thước phía client (copy logic đã có ở `EutrDocumentsAdd.jsx`/T063-T066, không refactor dùng chung); `onChange` của input file gọi `uploadToSharePointUseCase.executeEutrMultiByType(files, type.id, type.name, step.id, chips.map(c => typeof c === 'string' ? c : c.code))` (T222), hiển thị snackbar kết quả rồi gọi `props.onUploaded()` để đóng dialog + báo danh sách chính tải lại (research Quyết định 49, FR-070) (phải sau T216-T223).
- [X] T225 [US7] Sửa `compliance-client/src/presentation/pages/eutr-documents/index.jsx`: nút **Add** trên toolbar — bỏ `navigate('/eutr/documents/add')`, thêm state `addDialogOpen`, `onClick={() => setAddDialogOpen(true)}`; render `<EutrDocumentsAddDialog open={addDialogOpen} onClose={() => setAddDialogOpen(false)} onUploaded={(result) => { setAddDialogOpen(false); fetchData(); setSnackbar({ open: true, message: result.message, severity: result.severity }); }} />` (T224) (phải sau T224, và sau T197 vì cùng file — đã sửa nhiều lần ở Phase 3/4/5/6/16/18). **Đã xác minh tĩnh**: `npx eslint` (0 lỗi), `npx vite build` (thành công).
- [ ] T226 [US7] Kiểm thử thủ công theo [quickstart.md](./quickstart.md) kịch bản 15 (+ 15a-15e) trên `/eutr/documents`. Cần backend build lại (T216-T219), frontend build lại (T220-T225), và có sẵn dữ liệu `eutr_reference_types` với ít nhất các `Name` "PO"/"Invoice"/"Delivery note"/"Vendor"/1 tên khác (feature `006-eutr-reference-types`) cùng ít nhất 1 `eutr_steps`. **Đã xác minh tĩnh** (T216-T225): `dotnet build` trên `ComplianceSys.Application` (0 lỗi); `ComplianceSys.Api` biên dịch không lỗi CS (chỉ lỗi khóa file DLL do tiến trình `ComplianceSys.Api` đang chạy sẵn trên máy, không phải lỗi biên dịch); `npx eslint` trên toàn `presentation/pages/eutr-documents` (0 lỗi); `npx vite build` (thành công). **CHƯA chạy trong trình duyệt** — cần môi trường chạy đầy đủ (backend + DB + dữ liệu test `eutr_reference_types`/`eutr_steps`), cùng điều kiện với T044/T052/T059/T062/T078/T089/T116/T117/T122/T140/T141/T180/T199/T208/T215.

**Checkpoint**: Nút Add mở popup (không điều hướng trang); Type/Step/Value/chip hoạt động đúng theo
từng nhánh Type; Upload tạo đúng document + `eutr_references` với `RefType` bất kỳ (không còn giới
hạn `0`/`1`) và đúng thư mục SharePoint; popup tự đóng sau Upload; `EutrDocumentsAdd.jsx`/route cũ
giữ nguyên không xóa; Edit (US3, Update 12/13) không đổi hành vi; toàn bộ US1-US6 và Update 3-14
không đổi.

---

## Phase 22: Update 17 - Ô Value tự xóa sau khi thêm chip; Type = "PO" trong popup Add bỏ chọn Step thủ công (User Story 7)

**Goal**: Hai tinh chỉnh trên popup Add (Update 15/16), **KHÔNG cần sửa backend nào** (research
Quyết định 50/51). (1) Ô **Value** trở về trống ngay sau khi thêm 1 chip (mọi đường: chọn gợi ý/gõ
tay xác nhận/dán). (2) Khi Type đã chọn có `Name` = "PO": ẩn hẳn combobox **Step** (không bắt buộc),
nút Upload chỉ cần Type + ≥1 chip, và khi nhấn Upload gọi lại **nguyên vẹn** use case đã có từ Update
6 (`executeEutrMulti`, → `POST /api/sharepoint/eutr-upload-multi`) thay vì `executeEutrMultiByType`
(Update 15/16) — vì endpoint PO gốc đã tự validate prefix `eutr_master_documents` và tự ghi
`eutr_references` theo từng `StepId` khớp Prefix (Update 6/7), không cần Step chọn thủ công. Với mọi
Type khác "PO", toàn bộ hành vi Update 15/16 giữ nguyên không đổi (spec FR-071 đến FR-075).

**Independent Test**: Xem [quickstart.md](./quickstart.md) kịch bản 16 (+ 16a-16b) — chọn Type =
"PO", xác nhận combobox Step không hiển thị; thêm 1 chip PO, xác nhận ô Value trở về trống ngay lập
tức và Upload khả dụng dù chưa chọn Step; upload file khớp prefix của 2 `StepId` khác nhau, kiểm tra
Network xác nhận request gọi `eutr-upload-multi` (không phải `eutr-upload-multi-by-type`) và kiểm
tra DB xác nhận `eutr_references.StepId` đúng theo Prefix; upload file không khớp prefix nào bị loại
kèm cảnh báo; lặp lại với Type = "Vendor"/"Invoice" xác nhận Step vẫn bắt buộc và request vẫn gọi
`eutr-upload-multi-by-type` như cũ.

### Frontend (sửa 2 file hiện có, tạo ở Phase 21 — KHÔNG file backend nào thay đổi)

- [X] T227 [P] [US7] Sửa `compliance-client/src/presentation/pages/eutr-documents/components/EutrAddValueAutocomplete.jsx`: sau khi thêm 1 chip thành công (chọn gợi ý, gõ tay xác nhận, hoặc mỗi token hợp lệ khi xử lý dán — cả 2 đường đã có ở T223), gọi ngay hàm reset input text của `Autocomplete` (`setInputValue('')`, hoặc tương đương) trước khi xử lý token tiếp theo trong cùng lượt dán — FR-071 (research Quyết định 50; phải sau T223, cùng file).
- [X] T228 [US7] Sửa `compliance-client/src/presentation/pages/eutr-documents/components/EutrDocumentsAddDialog.jsx`: thêm biến `isPoType = (type?.name ?? '').trim().toLowerCase() === 'po'`; khi `isPoType`, KHÔNG render/gọi `GetEutrStepsUseCase` cho control Step, và điều kiện `disabled` của nút Upload đổi thành `!(type && chips.length > 0)` (bỏ điều kiện `step`); `onChange` của input file rẽ nhánh: nếu `isPoType` gọi `uploadToSharePointUseCase.executeEutrMulti(files, chips[0])` (use case đã có từ Update 6/T073, `POST /api/sharepoint/eutr-upload-multi`) thay vì `executeEutrMultiByType`; nếu không, giữ nguyên `executeEutrMultiByType(files, type.id, type.name, step.id, chips.map(...))` như Update 15/16 — FR-072 đến FR-075 (research Quyết định 51; phải sau T224, cùng file). **Đã xác minh tĩnh**: `npx eslint` (0 lỗi), `npx vite build` (thành công).
- [ ] T229 [US7] Kiểm thử thủ công theo [quickstart.md](./quickstart.md) kịch bản 16 (+ 16a-16b) trên `/eutr/documents`. Cần frontend build lại (T227-T228) và dữ liệu test trong `eutr_master_documents` (feature `002-eutr-masters`) với ít nhất 2 `Prefix` gắn 2 `StepId` khác nhau để kiểm tra file khớp nhiều Step. Không cần thay đổi backend/DB nào (Quyết định 51). **CHƯA chạy trong trình duyệt** — cần môi trường chạy đầy đủ (backend + DB + dữ liệu test `eutr_master_documents`), cùng điều kiện với T044/T052/T059/T062/T078/T089/T116/T117/T122/T140/T141/T180/T199/T208/T215/T226.

**Checkpoint**: Ô Value trở về trống ngay sau mỗi lần thêm chip trong popup Add (mọi Type). Type =
"PO" trong popup Add không hiển thị/yêu cầu Step, Upload gọi lại đúng endpoint gốc `eutr-upload-multi`
(Update 6/7) — file không khớp prefix bị loại, `eutr_references.StepId` đúng theo Prefix khớp tên
file (có thể nhiều dòng/file). Type khác "PO" không đổi hành vi so với Update 15/16; toàn bộ US1-US6
và Update 3-16 không đổi.

---

## Phase 23: Update 18 - Popup Add gửi kèm `TypeId` khi Type = "PO"; ghi đúng `RefType` vào `eutr_references` (User Story 7)

**Goal**: Đóng khoảng trống giữa ý định đã nêu ở FR-075 (Update 17: `RefType` phải là `Id` thật của
Type "PO") và luồng ghi thực tế hiện đang dùng hằng số cố định (`EutrUploadService.PoRefType = 0`),
không phụ thuộc `Id` thật đang được chọn ở dropdown Type. Thêm field nullable `TypeId` vào
`EutrMultiUploadFileRequest` (endpoint `eutr-upload-multi`, Update 6); popup Add (nhánh `isPoType`,
Update 17) MUST gửi kèm `type.id` khi Upload; `EutrUploadService` MUST dùng giá trị này (nếu có) làm
`RefType`, thay cho hằng số cũ — khi KHÔNG có (caller cũ `EutrDocumentsAdd.jsx`), giữ nguyên hằng số
cũ (research Quyết định 52, FR-076/FR-077). **KHÔNG migration DB mới, KHÔNG entity/repository/
endpoint mới.**

**Independent Test**: Xem [quickstart.md](./quickstart.md) kịch bản 17 (+ 17a) — xác nhận `Id` thật
của Type "PO" trong `eutr_reference_types` (feature `006-eutr-reference-types`); chọn Type = "PO"
trong popup Add, thêm 1 chip PO, upload 1 file khớp prefix → kiểm tra Network xác nhận request
`POST /api/sharepoint/eutr-upload-multi` có field `typeId` = đúng `Id` đó; kiểm tra DB xác nhận
`eutr_references.RefType` = đúng giá trị `typeId`; quay lại danh sách chính xác nhận nhãn Type "PO"
hiển thị đúng. Lặp lại nhanh với Type = "Vendor"/"Invoice" xác nhận không hồi quy (vẫn gọi
`eutr-upload-multi-by-type` như cũ).

### Backend (1 field DTO nullable + 1 dòng gán giá trị trong service đã có — KHÔNG entity/repository/endpoint/migration mới)

- [X] T230 [P] [US7] Sửa `compliance-sys-api/src/ComplianceSys.Application/Dtos/Request/EutrMultiUploadFileRequest.cs`: thêm `public long? TypeId { get; set; }` (nullable, KHÔNG `[Required]` — không phá vỡ caller cũ `EutrDocumentsAdd.jsx` chưa gửi field này) (research Quyết định 52; độc lập, không phụ thuộc task nào khác).
- [X] T231 [US7] Sửa `compliance-sys-api/src/ComplianceSys.Application/Services/EutrUploadService.cs`: trong `UploadMultipleToSharePointAndSaveDataAsync`, đổi dòng gán `RefType = PoRefType` thành `RefType = request.TypeId.HasValue ? (byte)request.TypeId.Value : PoRefType` — giữ nguyên toàn bộ logic validate prefix/transaction per-file hiện có (research Quyết định 52, FR-077; phải sau T230, và sau T218 vì cùng file). **Đã xác minh tĩnh**: `dotnet build` trên `ComplianceSys.Application` (0 lỗi).

### Frontend (truyền thêm `type.id` qua 3 file hiện có — KHÔNG component/use case mới)

- [X] T232 [P] [US7] Sửa `compliance-client/src/infrastructure/repositories/RestSharePointRepository.js`: đổi chữ ký `uploadEutrFilesMulti(files, poCode, typeId)` — thêm `if (typeId !== undefined && typeId !== null) formData.append('typeId', typeId)` trước khi gọi `axiosInstance.post('/sharepoint/eutr-upload-multi', ...)` (độc lập, không phụ thuộc T230/T231 — chỉ cần build cùng lúc với backend để test end-to-end).
- [X] T233 [US7] Sửa `compliance-client/src/application/usecases/sharepoint/UploadToSharePointUseCase.js`: đổi `executeEutrMulti(files, poCode, typeId) { return this.sharePointRepository.uploadEutrFilesMulti(files, poCode, typeId); }` (phải sau T232, cùng chuỗi tham số).
- [X] T234 [US7] Sửa `compliance-client/src/presentation/pages/eutr-documents/components/EutrDocumentsAddDialog.jsx`: trong nhánh `isPoType` (Update 17, T228), đổi lời gọi thành `uploadToSharePointUseCase.executeEutrMulti(files, chips[0], type.id)` — truyền thêm `type.id` (Id thật của Type "PO" đang chọn ở dropdown) (research Quyết định 52, FR-076; phải sau T233, và sau T228 vì cùng file). **Đã xác minh tĩnh**: `npx eslint` (0 lỗi), `npx vite build` (thành công).
- [ ] T235 [US7] Kiểm thử thủ công theo [quickstart.md](./quickstart.md) kịch bản 17 (+ 17a) trên `/eutr/documents`. Cần backend build lại (T230-T231), frontend build lại (T232-T234), và biết trước `Id` thật của bản ghi `eutr_reference_types` có `Name` = "PO" (feature `006-eutr-reference-types`) để đối chiếu. **CHƯA chạy trong trình duyệt** — cần môi trường chạy đầy đủ (backend + DB + dữ liệu test `eutr_master_documents`/`eutr_reference_types`), cùng điều kiện với T044/T052/T059/T062/T078/T089/T116/T117/T122/T140/T141/T180/T199/T208/T215/T226/T229.

**Checkpoint**: Khi Type = "PO" trong popup Add, request Upload gửi kèm `typeId` = đúng `Id` thật của
Type "PO" đang chọn; mỗi `eutr_references` ghi cho document tạo qua luồng này có `RefType` khớp đúng
giá trị đó — cột Type trên danh sách chính hiển thị đúng nhãn "PO", không còn phụ thuộc giả định
"PO luôn có Id = 0". Type khác "PO" và trang Add cũ độc lập (`EutrDocumentsAdd.jsx`) không đổi hành
vi; toàn bộ US1-US7 và Update 3-17 không đổi.

---

## Phase 24: Update 19 - Hợp nhất hoàn toàn Add/Edit vào một popup; đơn giản hóa cột Conditions; xóa hoàn toàn trang Add cũ + popup Assign condition (User Story 1/2/3)

**Goal**: Add và Edit (User Story 2/3 trong spec hiện tại) dùng chung **đúng một** popup
(`EutrDocumentsFormDialog.jsx`, đổi tên từ `EutrDocumentsAddDialog.jsx`) qua prop `mode`. Popup Add
thêm 2 trường **Valid from**/**Valid to** (mặc định hôm nay/`9999-12-31`, editable, validate
`validFrom ≤ validTo`). Popup Edit khóa Type, chip Value chỉ đọc, Step khả dụng để sửa cho **mọi**
Type kể cả PO (khác Add, nơi PO ẩn Step), Save cập nhật `StepId` của **mọi** bản ghi `eutr_references`
hiện có (giữ nguyên `RefValue`/`RefType`/số lượng) và/hoặc Valid from/to — không tạo/xóa bản ghi nào.
Cột **Conditions** (User Story 1) đổi nguồn sang `RefValue` phẳng, distinct, của `eutr_references` —
bỏ hẳn `eutr_reference_details`. **Xóa hoàn toàn** (không giữ dead code, khác quyết định ở Phase 21):
trang Add cũ (`EutrDocumentsAdd.jsx` + route `/eutr/documents/add`), `EutrDocumentsModal.jsx`,
`AssignConditionDialog.jsx`, service `IEutrConditionAssignmentService`, entity/repository
`EutrReferenceDetails`, 5 endpoint (`get-unassigned`, `assign-conditions`, `condition-assignment`
GET/PUT, `list-po-references`) + `eutr-upload-manual-multi`, cùng mọi DTO/use case chỉ phục vụ các
luồng đó. **Không migration DB mới** (xem research Quyết định 53-60, plan.md Update 19).

**Independent Test**: Xem [quickstart.md](./quickstart.md) kịch bản 18 đến 18i — `/eutr/documents/add`
không còn route khớp; popup Add có Valid from/Valid to editable, document tạo ra dùng đúng giá trị
hiển thị tại thời điểm Upload, chặn khi Valid from > Valid to; Edit mở đúng popup ở chế độ sửa (Type
khóa, chip chỉ đọc, không control Upload), Step hiển thị/sửa được cho mọi Type kể cả PO, Save chỉ đổi
Step (kiểm tra DB: mọi dòng `eutr_references` của document cùng đổi `StepId`, giữ nguyên
`RefValue`/`RefType`/số lượng) và/hoặc Valid from/to; document Type trống ẩn Step, chỉ sửa Valid
from/to; cột Conditions hiển thị đúng `RefValue` phẳng, dedupe khi Type="PO" khớp nhiều Step cùng 1
mã PO; đóng popup không Save thì không có thay đổi nào được lưu.

### Backend — Conditions phẳng + repurpose `{id}/step` (User Story 1/3)

- [X] T236 [P] [US1] Sửa `compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/EutrReferenceStepInfo.cs`: thêm `public string? RefValue { get; set; }` (dùng dựng Conditions phẳng, research Quyết định 54).
- [X] T237 [US1] Sửa `compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/EutrReferencesRepository.cs`: `GetStepInfoByDocumentIdsAsync` — thêm `r.RefValue` vào `SELECT` (sau T236, cùng file với T096/T097/T118/T126/T148/T154/T201/T211 — tuần tự).
- [X] T238 [P] [US1] Sửa `compliance-sys-api/src/ComplianceSys.Application/Dtos/Response/EutrDocumentsResponseDto.cs`: đổi `Conditions` từ `List<ConditionGroupDto>` sang `List<string>` (research Quyết định 54).
- [X] T239 [US1] Sửa `compliance-sys-api/src/ComplianceSys.Application/Services/EutrDocumentsService.cs`: `AttachStepAndConditionInfoAsync` — tính `Conditions` = `Distinct()` các `RefValue` khác null/rỗng theo `DocumentId`, bỏ lời gọi `IEutrReferenceDetailsRepository.GetGroupedConditionsByDocumentIdsAsync` (sau T237, T238; cùng file với T010/T100/T120/T121/T127/T156/T158/T203/T213 — tuần tự).
- [X] T240 [P] [US3] Thêm khai báo `Task UpdateStepIdByDocumentIdAsync(long documentId, long stepId, string updatedBy, CancellationToken ct = default)` vào `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Repositories/IEutrReferencesRepository.cs`.
- [X] T241 [US3] Implement `UpdateStepIdByDocumentIdAsync` trong `EutrReferencesRepository.cs` (raw SQL `UPDATE eutr_references SET StepId=@StepId, UpdatedBy=@UpdatedBy, UpdatedDate=@UpdatedDate WHERE DocumentId=@DocumentId`) (sau T240; cùng file với T237 — tuần tự).
- [X] T242 [P] [US3] Đổi tên `compliance-sys-api/src/ComplianceSys.Application/Dtos/Request/EutrUpdatePoStepRequestDto.cs` → `EutrUpdateReferenceStepRequestDto.cs` (giữ nguyên shape `{ long StepId }`, research Quyết định 56).
- [X] T243 [US3] Thêm khai báo `Task UpdateReferenceStepAsync(long documentId, long stepId, string userEmail, CancellationToken ct = default)` vào `IEutrDocumentsService.cs` (sau T242).
- [X] T244 [US3] Implement `EutrDocumentsService.UpdateReferenceStepAsync` (gọi `_referencesRepository.UpdateStepIdByDocumentIdAsync`) (sau T241, T243; cùng file với T239 — tuần tự).
- [X] T245 [US3] Sửa `compliance-sys-api/src/ComplianceSys.Api/Controllers/EutrDocumentsController.cs`: action `PUT {id:long}/step` gọi `_eutrDocumentsService.UpdateReferenceStepAsync(...)` với `EutrUpdateReferenceStepRequestDto` thay vì `_conditionAssignmentService.UpdatePoStepAsync`; xóa constructor param `IEutrConditionAssignmentService`; xóa 4 action `get-unassigned`/`assign-conditions`/`GET`+`PUT condition-assignment` (sau T244; cùng file với T011/T022/T027/T031/T036/T103/T123/T165/T187 — tuần tự). **Điều chỉnh khi implement**: action `list-po-references` KHÔNG bị xóa — khảo sát lại phát hiện `GetEutrDocumentsPoReferencesUseCase.js` (frontend) vẫn được gọi bởi feature khác `eutr-sales-orders` (`ViewSalesOrderPage.jsx`, Template Checklist) để suy diễn trạng thái "đã map", ngoài phạm vi giả định ban đầu của research/plan Update 19 — giữ nguyên endpoint + `GetPoReferencesAsync`/`GetDocumentsByPoCodesAsync` (xem T246/T247/T251/T270/T271).
- [X] T246 [US3] Sửa `EutrDocumentsService.cs`/`IEutrDocumentsService.cs`: xóa `GetUnassignedPagedAsync` (implementation + khai báo) (sau T245; cùng file với T239/T244 — tuần tự). **Điều chỉnh khi implement**: `GetPoReferencesAsync` được GIỮ LẠI (không xóa) — xem ghi chú T245.
- [X] T247 [US3] Sửa `IEutrReferencesRepository.cs`/`EutrReferencesRepository.cs`: xóa `GetUnassignedDocumentsPagedAsync` (interface + implementation) (sau T246; cùng file với T237/T241 — tuần tự). **Điều chỉnh khi implement**: `GetDocumentsByPoCodesAsync` được GIỮ LẠI (không xóa) — xem ghi chú T245.
- [X] T248 [P] [US3] Xóa `IEutrConditionAssignmentService.cs` + `EutrConditionAssignmentService.cs` (sau T245 — controller không còn constructor dependency).
- [X] T249 [P] [US3] Xóa entity `EutrReferenceDetails.cs` + `IEutrReferenceDetailsRepository.cs`/`EutrReferenceDetailsRepository.cs` (sau T248 — service từng gọi vào đã bị xóa).
- [X] T250 [P] [US3] Xóa DTO Assign condition: `EutrManualMultiUploadFileRequest.cs`, `EutrAssignConditionsRequestDto.cs` (+ validator), `EutrConditionRowDto.cs`, `EutrUpdateConditionAssignmentRequestDto.cs` (+ validator), `EutrDocumentConditionAssignmentDto.cs`, `ConditionGroupDto.cs`, `EutrConditionGroupRow.cs` (sau T248 — không còn tham chiếu).
- [X] T251 [P] [US3] ~~Xóa DTO List PO~~ **Điều chỉnh khi implement — KHÔNG xóa**: `EutrDocumentsListPoReferencesRequestDto.cs`, `EutrDocumentsPoReferenceDto.cs`, `EutrDocumentsPoReferenceItemDto.cs`, `EutrReferencePoDocumentInfo.cs` vẫn còn dùng bởi endpoint `list-po-references` (giữ lại, xem ghi chú T245) — feature `eutr-sales-orders` phụ thuộc chuỗi này qua `GetEutrDocumentsPoReferencesUseCase.js`. Xác nhận qua build (`dotnet build` 0 lỗi) sau khi khôi phục.
- [X] T252 [US3] Sửa `compliance-sys-api/src/ComplianceSys.Api/Controllers/SharepointController.cs`: xóa action `[HttpPost("eutr-upload-manual-multi")]` (cùng file với T067/T152 — tuần tự).
- [X] T253 [US3] Sửa `IEutrUploadService.cs`/`EutrUploadService.cs`: xóa `UploadManualMultipleToSharePointAndSaveDataAsync` (sau T252; cùng file với T065/T066/T084/T085/T150/T151/T217/T218 — tuần tự).
- [X] T254 [US3] Sửa `ComplianceSys.Application/DependencyInjection.cs` + `ComplianceSys.Infrastructure/DependencyInjection.cs`: xóa đăng ký `IEutrConditionAssignmentService` + validator `EutrAssignConditionsRequestDtoValidator`/`EutrUpdateConditionAssignmentRequestDtoValidator`; xóa đăng ký `IEutrReferenceDetailsRepository` (sau T248, T249, T250).

### Backend — Valid from/Valid to cho popup Add (User Story 2)

- [X] T255 [P] [US2] Sửa `compliance-sys-api/src/ComplianceSys.Application/Dtos/Request/EutrMultiUploadFileRequest.cs`: thêm `public DateTime? ValidFrom { get; set; }`, `public DateTime? ValidTo { get; set; }` (research Quyết định 55).
- [X] T256 [P] [US2] Sửa `compliance-sys-api/src/ComplianceSys.Application/Dtos/Request/EutrTypeMultiUploadFileRequest.cs`: thêm cùng 2 field trên.
- [X] T257 [US2] Sửa `EutrUploadService.cs`: trong cả `UploadMultipleToSharePointAndSaveDataAsync` VÀ `UploadMultipleForReferenceTypeAsync`, đổi `ValidFrom = DateTime.Today`/`ValidTo = MaxValidTo` thành `request.ValidFrom ?? DateTime.Today`/`request.ValidTo ?? MaxValidTo` (sau T255, T256, T253 — cùng file, tuần tự).

### Frontend — Conditions phẳng (User Story 1)

- [X] T258 [P] [US1] Sửa `compliance-client/src/presentation/pages/eutr-documents/hooks/useEutrDocumentsColumns.jsx`: cột "conditions" — `renderCell` dùng `<MultiValueChips values={row.conditions} />` (flat array), bỏ nhóm theo `CONDITION_TYPE_OPTIONS` (sau T239 để backend trả đúng shape khi test end-to-end; cùng file với T025/T105/T135/T176/T214 — tuần tự).

### Frontend — Popup Add: Valid from/Valid to (User Story 2)

- [X] T259 [US2] Đổi tên `compliance-client/src/presentation/pages/eutr-documents/components/EutrDocumentsAddDialog.jsx` → `EutrDocumentsFormDialog.jsx`; thêm prop `mode = 'add'` (mặc định) + `initialData` (chưa dùng ở bước này) — giữ nguyên toàn bộ hành vi Update 15-18 khi `mode='add'` (cùng file với T224/T228/T234 — tuần tự).
- [X] T260 [US2] Thêm 2 `TextField type="date"` **Valid from** (mặc định hôm nay) và **Valid to** (mặc định `9999-12-31`) vào `EutrDocumentsFormDialog.jsx` — cùng mẫu ô ngày đã dùng ở `EutrDocumentsModal.jsx` cũ (Update 3), editable; validate `validFrom ≤ validTo` — chặn Upload/Save + hiển thị lỗi inline khi vi phạm (sau T259).
- [X] T261 [P] [US2] Sửa `compliance-client/src/infrastructure/repositories/RestSharePointRepository.js`: `uploadEutrFilesMulti(files, poCode, typeId, validFrom, validTo)`/`uploadEutrFilesMultiByType(..., validFrom, validTo)` — thêm 2 field vào `FormData`; xóa `uploadEutrManualFilesMulti` (cùng file với T072/T168/T221/T232 — tuần tự).
- [X] T262 [US2] Sửa `compliance-client/src/application/usecases/sharepoint/UploadToSharePointUseCase.js`: `executeEutrMulti(files, poCode, typeId, validFrom, validTo)`/`executeEutrMultiByType(..., validFrom, validTo)`; xóa `executeManualMulti` (sau T261; cùng file với T073/T169/T222/T233 — tuần tự).
- [X] T263 [P] [US2] Sửa `compliance-client/src/domain/interfaces/ISharePointRepository.js`: xóa khai báo `uploadEutrManualFilesMulti(_files)`.
- [X] T264 [US2] Sửa `EutrDocumentsFormDialog.jsx`: `onUpload` truyền `validFrom`/`validTo` đang hiển thị vào `executeEutrMulti`/`executeEutrMultiByType` (sau T260, T262).

### Frontend — Edit hợp nhất; xóa trang Add cũ + popup Assign condition (User Story 3)

- [X] T265 [P] [US3] Đổi tên `compliance-client/src/application/usecases/eutr-documents/UpdateEutrDocumentPoStepUseCase.js` → `UpdateEutrDocumentReferenceStepUseCase.js` (cùng shape `execute(id, stepId)`).
- [X] T266 [US3] Mở rộng `EutrDocumentsFormDialog.jsx` cho `mode='edit'`: Type Autocomplete `disabled` (giá trị = phần tử `referenceTypes` khớp `id === initialData.refType`); chip Value **chỉ đọc** (ẩn `EutrAddValueAutocomplete`, không nút xóa); combobox Step hiển thị theo quy tắc **khác** mode `add` — `showStep = initialData.refType != null` (hiện cho MỌI Type kể cả PO, research Quyết định 60), preselect theo `initialData.stepId`; Valid from/Valid to nạp `initialData.validFrom`/`validTo` (KHÔNG reset về mặc định); nút **Save** thay Upload (không control file); `onSave` gọi tuần tự `UpdateEutrDocumentsUseCase.execute({id, name: initialData.name, validFrom, validTo})` rồi — nếu Step đang hiển thị — `UpdateEutrDocumentReferenceStepUseCase.execute(id, stepId)` (sau T264, T265, và sau T245 backend đã sẵn sàng).
- [X] T267 [US3] Sửa `compliance-client/src/presentation/pages/eutr-documents/index.jsx`: `onEdit` KHÔNG còn rẽ nhánh theo `refType` — luôn mở `EutrDocumentsFormDialog` với `mode="edit"` `initialData={row}`; xóa state `modalOpen`/`modalData`, `assignDialogOpen`/`assignDialogData`; xóa import `EutrDocumentsModal`/`AssignConditionDialog` (sau T266; cùng file với T021/T026/T030/T035/T039/T136/T197/T225 — tuần tự).
- [X] T268 [P] [US3] Xóa `EutrDocumentsModal.jsx`, `AssignConditionDialog.jsx` (sau T267 — không còn caller).
- [X] T269 [P] [US3] Xóa `EutrDocumentsAdd.jsx`; xóa route `path: "/eutr/documents/add"` khỏi `compliance-client/src/app/routes/groups/MainRoutes.jsx`; xóa entry menu tương ứng trong `compliance-client/src/presentation/menu-items/ComplianceSystem.jsx` nếu có (sau T267 — bảng List PO/"chưa gán" trên trang này không còn cần cho popup hợp nhất).
- [X] T270 [US3] Sửa `IEutrDocumentsRepository.js`/`infrastructure/api/eutrDocumentsApi.js`/`infrastructure/repositories/RestEutrDocumentsRepository.js`: xóa `getUnassigned`/`assignConditions`/`getConditionAssignment`/`updateConditionAssignment` (sau T245 — backend đã xóa endpoint tương ứng). **Điều chỉnh khi implement**: `getPoReferences`/`listPoReferences` được GIỮ LẠI (không xóa) — xem ghi chú T245.
- [X] T271 [P] [US3] Xóa use case: `AssignEutrConditionsUseCase.js`, `GetEutrDocumentConditionAssignmentUseCase.js`, `UpdateEutrConditionAssignmentUseCase.js`, `GetEutrDocumentsUnassignedUseCase.js` (sau T270 — không còn caller). **Điều chỉnh khi implement**: `GetEutrDocumentsPoReferencesUseCase.js` được GIỮ LẠI (không xóa) — vẫn dùng bởi `ViewSalesOrderPage.jsx` (feature `eutr-sales-orders`), xem ghi chú T245. Phát hiện qua `npx vite build` thất bại (`ENOENT ... GetEutrDocumentsPoReferencesUseCase`) khi thử xóa lần đầu — đã khôi phục nguyên vẹn (`git show HEAD:...`) và xác nhận lại `npx vite build` thành công, `npx eslint` 0 lỗi mới.
- [X] T272 [US3] Xác nhận `CONDITION_TYPE_OPTIONS` (`compliance-client/src/utils/helpers.js`) không còn dùng ở bất kỳ nơi nào khác trong repo (grep toàn repo); xóa nếu đúng (sau T268).

### Kiểm thử thủ công

- [ ] T273 [US1] Kiểm thử thủ công theo [quickstart.md](./quickstart.md) kịch bản 18h — cột Conditions hiển thị đúng `RefValue` phẳng, dedupe khi Type="PO" khớp nhiều Step cùng 1 mã PO. **CHƯA chạy trong trình duyệt** — cần môi trường chạy đầy đủ (backend + DB), cùng điều kiện với các task kiểm thử thủ công trước đó (T044, T235, ...).
- [ ] T274 [US2] Kiểm thử thủ công theo quickstart.md kịch bản 18a-18c — Valid from/Valid to trong popup Add (mặc định, chỉnh sửa, validate `validFrom ≤ validTo`). **CHƯA chạy trong trình duyệt**.
- [ ] T275 [US3] Kiểm thử thủ công theo quickstart.md kịch bản 18, 18d-18g, 18i — route cũ đã gỡ, Edit mở đúng popup hợp nhất (Type khóa, chip chỉ đọc, Step khả dụng cho mọi Type), Save chỉ đổi Step/Valid from/to, document Type trống ẩn Step, đóng popup không Save thì không lưu. **CHƯA chạy trong trình duyệt**.

**Checkpoint**: Add và Edit dùng chung đúng 1 popup; `/eutr/documents/add` không còn tồn tại; popup
Assign condition và 5 endpoint liên quan đã bị xóa hoàn toàn khỏi codebase; cột Conditions hiển thị
đúng `RefValue` phẳng cho mọi Type; Save trong popup Edit chỉ đổi Step (mọi bản ghi `eutr_references`)
và/hoặc Valid from/to, không thêm/xóa bản ghi nào.

---

## Phase 25: Update 20 - Combobox Step lọc theo Assign Steps của Type; mặc định chọn dòng đầu (User Story 2/3)

**Goal**: Combobox **Step** trong `EutrDocumentsFormDialog.jsx` (cả mode Add và Edit, khi Type khác
"PO") chỉ hiển thị các Step đã được gán (tính năng **Assign Steps**, feature
`006-eutr-reference-types`) cho Type đang chọn — tức có bản ghi trong `eutr_reference_type_details`
với `TypeId` khớp. Mode Add mặc định chọn sẵn dòng đầu tiên của danh sách đã lọc ngay sau khi tải
xong; đổi Type tải lại danh sách và mặc định lại. Mode Edit đảm bảo Step hiện tại của document luôn
hiển thị được (không bị loại khỏi combobox) dù đã bị gỡ khỏi Assign Steps sau khi document được tạo —
không tự động thay bằng Step khác. Type = "PO" không đổi (Step tiếp tục ẩn hoàn toàn). **0 thay đổi
backend** — toàn bộ hạ tầng đọc (entity `EutrReferenceTypeDetails`, repository
`EutrReferenceTypeDetailsRepository.GetByTypeIdAsync`, endpoint
`GET /api/eutr-reference-type-details/by-type/{typeId}`, policy `EutrReferenceTypes.ReadOne`) đã được
xây dựng đầy đủ bởi feature `006-eutr-reference-types`; frontend cũng đã có sẵn use case
`GetByTypeIdEutrReferenceTypeDetailsUseCase`/repository `repositories.eutrReferenceTypeDetails` — chỉ
cần wiring vào 1 file hiện có (xem research Quyết định 61, plan.md Update 20).

**Independent Test**: Xem [quickstart.md](./quickstart.md) kịch bản 19 (19a/19b) — Type chưa gán Step
nào ở Assign Steps hiển thị combobox Step trống + Upload vô hiệu hóa; Type đã gán ≥2 Step hiển thị
đúng danh sách lọc + mặc định dòng đầu; đổi Type tải lại đúng danh sách/mặc định; Edit một document có
Step đã bị gỡ khỏi Assign Steps sau khi tạo vẫn hiển thị/giữ đúng Step hiện tại; Type = "PO" không đổi.

### Frontend — Lọc Step theo Assign Steps của Type (User Story 2/3, sửa đúng 1 file, KHÔNG thêm use case/repository/domain nào mới)

- [X] T276 [US2] Sửa `compliance-client/src/presentation/pages/eutr-documents/components/EutrDocumentsFormDialog.jsx`: import `GetByTypeIdEutrReferenceTypeDetailsUseCase` (đã có sẵn từ feature `006`, `application/usecases/eutr-reference-type-details/`), instantiate ở module scope với `repositories.eutrReferenceTypeDetails` (đã đăng ký sẵn trong `di/repositories.js`) — theo đúng mẫu instantiate `getEutrReferenceTypesUseCase`/`getEutrStepsUseCase` đã có trong file; KHÔNG tạo use case/repository/domain mới nào (cùng file với T259/T260/T264/T266 — tuần tự).
- [X] T277 [US2] Thêm hàm `loadFilteredSteps(typeId)` trong `EutrDocumentsFormDialog.jsx`: gọi `getByTypeIdEutrReferenceTypeDetailsUseCase.execute(typeId)`, map mỗi item (`stepId`/`stepName`) sang `{ id, name }` — ưu tiên đối chiếu `stepId` với mảng `steps` đầy đủ đã tải sẵn bởi `getEutrStepsUseCase` (giữ đúng object reference cho `isOptionEqualToValue`), fallback dùng thẳng `stepName` của response nếu không khớp (research Quyết định 61) (sau T276; cùng file — tuần tự). **Điều chỉnh khi implement**: hàm được định nghĩa ở module scope (nhận thêm tham số `fullSteps` thay vì đọc trực tiếp state `steps`, tránh stale-closure khi gọi ngay sau `setSteps`/`setSubmitting` bất đồng bộ trong cùng effect) — hành vi/kết quả không đổi so với mô tả.
- [X] T278 [US2] Sửa nhánh mode `add` trong `EutrDocumentsFormDialog.jsx`: gọi `loadFilteredSteps(type.id)` mỗi khi `type` đổi (thay thế việc dùng thẳng toàn bộ `steps` không lọc cho combobox Step); ngay sau khi danh sách lọc tải xong, `setStep(filteredSteps[0] ?? null)` làm mặc định (FR-044); Type = "PO" (`isPoType`) không đổi — không gọi hàm này khi Step đang ẩn (sau T277; cùng file — tuần tự). **Điều chỉnh khi implement**: khi Type đổi sang rỗng/"PO", combobox Step đặt về `[]` (trước đó không lọc gì); trước khi chọn Type lần đầu ở mode Add, danh sách Step cũng khởi tạo rỗng (không còn hiển thị toàn bộ `eutr_steps` không lọc) — nhất quán với FR-043 (không có Type thì không có gì để lọc theo).
- [X] T279 [US3] Sửa nhánh mode `edit` trong `EutrDocumentsFormDialog.jsx`: gọi `loadFilteredSteps(initialData.refType)` một lần khi mở popup (Type đã khóa, không đổi trong vòng đời popup); nếu Step hiện tại của document (từ `initialData.stepId`, xác định theo bản ghi `Id` nhỏ nhất — Quyết định 59) không có mặt trong danh sách đã lọc, chèn thêm chính Step đó vào đầu mảng hiển thị thay vì loại bỏ — KHÔNG đổi giá trị `step` đang chọn sang mặc định khác (FR-045) (sau T277; cùng file — tuần tự, độc lập với T278 vì khác nhánh mode). **Đã xác minh tĩnh** (T276-T279): `npx eslint` (0 lỗi), `npx vite build` (thành công).
- [ ] T280 [US2] Kiểm thử thủ công theo [quickstart.md](./quickstart.md) kịch bản 19, 19b — Type chưa gán Step nào hiển thị combobox trống + Upload vô hiệu hóa; Type đã gán ≥2 Step hiển thị đúng danh sách lọc + mặc định dòng đầu; đổi Type tải lại đúng; Type = "PO" không đổi. **CHƯA chạy trong trình duyệt** — cần môi trường chạy đầy đủ (backend + DB), cùng điều kiện với các task kiểm thử thủ công trước đó (T044, T235, T273-T275, ...) (sau T278).
- [ ] T281 [US3] Kiểm thử thủ công theo quickstart.md kịch bản 19a — Edit một document có Step đã bị gỡ khỏi Assign Steps (feature `006`) sau khi document được tạo, xác nhận Step hiện tại vẫn hiển thị và được chọn (không bị thay bằng mặc định khác); vẫn Save bình thường sau đó. **CHƯA chạy trong trình duyệt** (sau T279).

**Checkpoint**: Combobox Step (Type khác "PO") trong popup Add/Edit chỉ hiển thị Step đã gán qua
Assign Steps cho Type đang chọn; Add mặc định chọn sẵn dòng đầu; Edit đảm bảo Step hiện tại của
document luôn hiển thị được dù đã bị gỡ khỏi Assign Steps.

---

## Phase 26: Update 21 - Search box lọc danh sách theo Type/Step name/Conditions (User Story 6)

**Goal**: Bổ sung **search box** phía trên bảng danh sách chính (`eutr-documents/index.jsx`): dropdown
**Type**, dropdown **Step name**, ô nhập **Conditions**, nút **Search**. Nhấn Search lọc bảng theo mọi
điều kiện đã cung cấp (kết hợp AND), mỗi điều kiện chỉ cần khớp một bản ghi `eutr_references` bất kỳ
của document đó — không bắt buộc cùng một bản ghi. Không endpoint mới — mở rộng hành vi nội bộ của
`EutrDocumentsService.GetPagedAsync` (endpoint `get-all` hiện có) để tiêu thụ 3 "cột lọc ảo"
`TypeId`/`StepId`/`Conditions` trong `request.Filters`, tính trước danh sách `DocumentId` khớp (SQL
`EXISTS` độc lập trên `eutr_references`) rồi tái dùng `Operator = "in"` sẵn có trên cột `Id` để lọc
tiếp `base.GetPagedAsync` — không migration DB mới, không entity/DTO mới (spec FR-046 đến FR-050,
research Quyết định 62/63/64).

**Independent Test**: Xem [quickstart.md](./quickstart.md) kịch bản 20 (20a/20b) — search box hiển thị
đủ Type/Step name/Conditions/Search; chọn từng điều kiện riêng lẻ rồi Search lọc đúng bảng; kết hợp cả
3 điều kiện (kể cả khi mỗi điều kiện khớp bản ghi `eutr_references` khác nhau của cùng document) vẫn
lọc đúng; xóa hết điều kiện rồi Search lại hiển thị đầy đủ danh sách gốc; tổ hợp không khớp document
nào hiển thị "No data" thay vì lỗi.

### Backend (mở rộng `IEutrReferencesRepository`/`EutrReferencesRepository` đã có từ Phase 14, sửa `EutrDocumentsService.cs` — không endpoint/DTO/migration mới)

- [X] T282 [P] [US6] Thêm method mới vào interface `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Repositories/IEutrReferencesRepository.cs`: `Task<List<long>> GetMatchingDocumentIdsAsync(long? typeId, long? stepId, string? conditionsQuery, CancellationToken ct = default);` (cạnh 4 method hiện có).
- [X] T283 [US6] Implement `GetMatchingDocumentIdsAsync` trong `compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/EutrReferencesRepository.cs`: SQL `SELECT d.Id FROM eutr_documents d WHERE (@typeId IS NULL OR EXISTS (SELECT 1 FROM eutr_references r WHERE r.DocumentId = d.Id AND r.RefType = @typeId)) AND (@stepId IS NULL OR EXISTS (SELECT 1 FROM eutr_references r WHERE r.DocumentId = d.Id AND r.StepId = @stepId)) AND (@conditionsQuery IS NULL OR EXISTS (SELECT 1 FROM eutr_references r WHERE r.DocumentId = d.Id AND r.RefValue LIKE CONCAT('%', @conditionsQuery, '%')));` — mỗi điều kiện độc lập, không bắt buộc khớp cùng một bản ghi `eutr_references` (research Quyết định 63, cùng style `Connection.QueryAsync` đã dùng ở 4 method hiện có của file này) (sau T282 — cùng interface).
- [X] T284 [US6] Sửa `GetPagedAsync` trong `compliance-sys-api/src/ComplianceSys.Application/Services/EutrDocumentsService.cs`: trước khi gọi `base.GetPagedAsync`, rút các phần tử `request.Filters` có `Column` (không phân biệt hoa/thường) ∈ `{"TypeId","StepId","Conditions"}` ra khỏi danh sách, đọc `typeId`/`stepId`/`conditionsQuery` từ `Value` của chúng; nếu có ≥1 giá trị, gọi `_referencesRepository.GetMatchingDocumentIdsAsync(typeId, stepId, conditionsQuery, ct)` — rỗng thì trả `PagedResult<EutrDocumentsResponseDto> { Items = [], TotalCount = 0 }` ngay (không gọi `base.GetPagedAsync`); ngược lại thêm `new FilterRequest { Column = "Id", Operator = "in", Value = string.Join(",", matchingIds) }` vào phần filter còn lại rồi tiếp tục luồng hiện có (`base.GetPagedAsync` → `AttachStepAndConditionInfoAsync`) không đổi (research Quyết định 62; sau T283, cùng service đã có sẵn từ Phase 3/14/15).

### Frontend (1 component mới nhỏ + sửa 2 file hiện có — clone `ComplianceFilterBar.jsx`/wiring `compliance-master`, tái dùng use case Type/Step đã có)

- [X] T285 [P] [US6] Tạo `compliance-client/src/presentation/pages/eutr-documents/components/EutrDocumentsFilterBar.jsx`: clone cấu trúc `presentation/components/ComplianceFilterBar.jsx` (`Box` hàng ngang) nhưng chỉ 3 control — `Autocomplete` **Type** (dữ liệu `getEutrReferenceTypesUseCase`, đã dùng ở popup Add từ Phase 21), `Autocomplete` **Step name** (dữ liệu `getEutrStepsUseCase`, TOÀN BỘ `eutr_steps`, KHÔNG lọc theo Type đang chọn trong search box — khác Assign Steps của Phase 25), `TextField` **Conditions** (free text), và `Button` **Search** (`variant="contained"`, `startIcon={<SearchIcon/>}`, mẫu `ComplianceFilterBar.jsx`) — không có nút Clear (spec chỉ yêu cầu đúng 4 control); nhận props `type,onTypeChange,step,onStepChange,conditions,onConditionsChange,onSearch`.
- [X] T286 [US6] Sửa `compliance-client/src/presentation/pages/eutr-documents/hooks/useEutrDocumentsData.js`: đổi chữ ký thành `useEutrDocumentsData(defaultFilters = [])` (mẫu `useComplianceMasterData(defaultFilters = [])`), gộp `defaultFilters` vào `filterPayload` hiện có trước khi gọi `getPagingEutrDocumentsUseCase.execute(...)` — không đổi hành vi khi `defaultFilters` rỗng (mặc định) (sau T024, cùng file).
- [X] T287 [US6] Sửa `compliance-client/src/presentation/pages/eutr-documents/index.jsx`: thêm state `typeFilter`/`stepFilter`/`conditionsFilter`/`searchFilters` (mảng, mặc định `[]`); hàm `handleSearch()` build `filters` từ 3 giá trị đang chọn (`{column:"TypeId",operator:"=",value:typeFilter.id}`/`{column:"StepId",operator:"=",value:stepFilter.id}`/`{column:"Conditions",operator:"like",value:conditionsFilter.trim()}` — chỉ thêm phần tử có giá trị), `setSearchFilters(filters)`, reset `paginationModel` về `page: 0` (mẫu `handleSearch` của `compliance-master/index.jsx`); gọi `useEutrDocumentsData(searchFilters)` (thay vì không tham số, sau T286); render `<EutrDocumentsFilterBar ... onSearch={handleSearch} />` ngay phía trên `DataGrid` (sau Phase 24, cùng file `index.jsx` đã có sẵn state dialog/selection).
- [ ] T288 [US6] Kiểm thử thủ công theo [quickstart.md](./quickstart.md) kịch bản 20 (20a/20b) — search box hiển thị đủ 4 control; lọc đúng theo từng điều kiện riêng lẻ và kết hợp cả 3 (kể cả khi mỗi điều kiện khớp bản ghi `eutr_references` khác nhau của cùng document); xóa hết điều kiện rồi Search lại hiển thị đầy đủ danh sách gốc; tổ hợp không khớp hiển thị "No data" (không lỗi). **Đã xác minh tĩnh** (T282-T287): `dotnet build` trên `ComplianceSys.Application`/`ComplianceSys.Infrastructure` (0 lỗi — build toàn `ComplianceSys.sln` bị chặn bởi file DLL đang bị khóa do `ComplianceSys.Api` đang chạy sẵn, không liên quan tới code mới), `npx eslint` trên 3 file đã sửa/tạo (0 lỗi, 1 warning không mới — `filterModel` dependency thừa trong `useCallback`, không phải regression), `npx vite build` (thành công). **CHƯA chạy trong trình duyệt** — cần môi trường chạy đầy đủ (backend + DB), cùng điều kiện với T044 (sau T284, T287).

**Checkpoint**: Search box lọc đúng danh sách chính theo Type/Step name/Conditions (độc lập hoặc kết
hợp), không cung cấp điều kiện nào hiển thị lại đầy đủ danh sách gốc; endpoint `get-all` không đổi
path/policy/request-response shape công khai cho mọi caller khác.

---

## Phase 27: Update 22 - Edit cho phép thêm/xóa chip Value khi Type khác "PO" (User Story 3)

**Goal**: Trong popup Edit (`EutrDocumentsFormDialog.jsx`, mode `edit`), vùng chip **Value** chỉ còn
**chỉ đọc** khi document có Type = "PO" — Type khác "PO" (kể cả "Vendor") hiển thị lại ô Value
(combobox gợi ý theo Type, tái dùng nguyên vẹn `EutrAddValueAutocomplete.jsx`) và nút xóa trên mỗi
chip, cho phép thêm/xóa trước khi Save. Nhấn Save đối chiếu (diff) tập chip đang hiển thị với
`eutr_references` hiện có của document: `INSERT` chip mới, `DELETE` chip đã xóa, `UPDATE StepId` của
mọi bản ghi còn lại — không endpoint mới, mở rộng đúng `PUT /api/eutr-documents/{id}/step` (Phase 24)
bằng 1 field nullable `refValues` (spec FR-051 đến FR-055, research Quyết định 65-67).

**Independent Test**: Xem [quickstart.md](./quickstart.md) kịch bản 21 (21a-21d) — Type khác "PO" cho
phép xóa/thêm chip rồi Save phản ánh đúng trên cột Conditions và trong `eutr_references`; Type = "PO"
không đổi (vẫn chỉ đọc); Type = "Vendor" vẫn giới hạn 1 chip; xóa hết chip mà không thêm lại chặn
Save; đóng popup không Save không để lại thay đổi nào.

### Backend (mở rộng đúng 1 DTO + 1 method service + 2 method repository của `PUT {id}/step` đã có từ Phase 24 — không endpoint/entity/migration mới)

- [X] T289 [P] [US3] Sửa `compliance-sys-api/src/ComplianceSys.Application/Dtos/Request/EutrUpdateReferenceStepRequestDto.cs`: thêm `public List<string>? RefValues { get; set; }` (cạnh `StepId` hiện có) — `null` giữ nguyên hành vi cũ (Phase 24, chỉ update StepId).
- [X] T290 [P] [US3] Thêm 2 khai báo method mới vào `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Repositories/IEutrReferencesRepository.cs`: `Task DeleteByDocumentIdAndRefValuesAsync(long documentId, IEnumerable<string> refValues, CancellationToken ct = default);` và `Task AddReferencesAsync(long documentId, long stepId, byte refType, IEnumerable<string> refValues, string createdBy, CancellationToken ct = default);` (cạnh 5 method hiện có).
- [X] T291 [US3] Implement 2 method trên trong `compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/EutrReferencesRepository.cs`: `DeleteByDocumentIdAndRefValuesAsync` — raw SQL 2 bước (dọn `eutr_reference_details` mồ côi trước theo `RefId IN (SELECT Id FROM eutr_references WHERE DocumentId = @DocumentId AND RefValue IN @RefValues)`, rồi `DELETE FROM eutr_references WHERE DocumentId = @DocumentId AND RefValue IN @RefValues`, cùng mẫu phòng thủ của `DeleteByDocumentIdAsync`); `AddReferencesAsync` — raw SQL `INSERT INTO eutr_references (DocumentId, StepId, RefType, RefValue, CreatedBy, CreatedDate, UpdatedBy, UpdatedDate) VALUES (...)` thực thi 1 lần cho cả tập `refValues` (Dapper multi-exec), cả hai dùng `transaction: Transaction` cùng style `Connection.ExecuteAsync` đã có (sau T290 — cùng interface).
- [X] T292 [US3] Sửa `UpdateReferenceStepAsync` trong `compliance-sys-api/src/ComplianceSys.Application/Services/EutrDocumentsService.cs`: mở rộng chữ ký thành `(long documentId, long stepId, List<string>? refValues, string userEmail, CancellationToken ct = default)` — `refValues == null` giữ nguyên hành vi cũ (gọi thẳng `UpdateStepIdByDocumentIdAsync`, không transaction); khác `null` → mở transaction mới (`_unitOfWork.BeginTransactionAsync(IsolationLevel.ReadCommitted, ct)`, cùng mẫu `DeleteAsync`/`DeleteMultiAsync` của Phase 15), đọc `RefValue`/`RefType` hiện có qua `GetStepInfoByDocumentIdsAsync([documentId], ct)` (đã có sẵn, không method đọc mới), tính `toAdd`/`toRemove` bằng `Except` (`StringComparer.OrdinalIgnoreCase`), gọi `DeleteByDocumentIdAndRefValuesAsync`/`AddReferencesAsync` (nếu tương ứng có phần tử) rồi `UpdateStepIdByDocumentIdAsync` như cũ, `CommitAsync`/`RollbackAsync` trong try/catch (sau T289, T291).
- [X] T293 [US3] Sửa action `UpdateReferenceStep` trong `compliance-sys-api/src/ComplianceSys.Api/Controllers/EutrDocumentsController.cs`: truyền thêm `dto.RefValues` vào lời gọi `_eutrDocumentsService.UpdateReferenceStepAsync(id, dto.StepId, dto.RefValues, userEmail, ct)` — không đổi route/policy (sau T292).

### Frontend (sửa 5 file hiện có — không component mới, tái dùng nguyên vẹn `EutrAddValueAutocomplete.jsx` đã có từ Phase 21)

- [X] T294 [P] [US3] Sửa `compliance-client/src/infrastructure/api/eutrDocumentsApi.js`: đổi `updateReferenceStep(id, stepId)` thành `updateReferenceStep(id, stepId, refValues) => axiosInstance.put(`/eutr-documents/${id}/step`, { stepId, refValues })`.
- [X] T295 [P] [US3] Sửa `compliance-client/src/domain/interfaces/IEutrDocumentsRepository.js`: đổi chữ ký `updateReferenceStep(_id, _stepId, _refValues)`.
- [X] T296 [US3] Sửa `compliance-client/src/infrastructure/repositories/RestEutrDocumentsRepository.js`: đổi `updateReferenceStep(id, stepId, refValues)`, truyền `refValues` qua `eutrDocumentsApi.updateReferenceStep(id, stepId, refValues)` (sau T294, T295).
- [X] T297 [US3] Sửa `compliance-client/src/application/usecases/eutr-documents/UpdateEutrDocumentReferenceStepUseCase.js`: đổi `execute(id, stepId, refValues)`, truyền `refValues` qua repository (sau T296).
- [X] T298 [US3] Sửa `compliance-client/src/presentation/pages/eutr-documents/components/EutrDocumentsFormDialog.jsx`: thêm `showEditableChips = isEdit && initialData?.refType != null && !isPoType` (cùng cách tính với `showStep` đã có); đổi điều kiện render `EutrAddValueAutocomplete` và `onDelete` của `Chip` từ `!isEdit` sang `(!isEdit || showEditableChips)`; `canSubmit` (mode edit) thêm điều kiện `(!showEditableChips || chips.length > 0)`; `handleSave` build `refValues = showEditableChips ? chips.map(toRefValue) : undefined` và truyền vào `updateEutrDocumentReferenceStepUseCase.execute(initialData.id, step.id, refValues)` (sau T297 — và sau Phase 25 T279, cùng file).
- [ ] T299 [US3] Kiểm thử thủ công theo [quickstart.md](./quickstart.md) kịch bản 21 (21a-21d) trên `/eutr/documents`. Cần ít nhất 1 document Type khác "PO"/"Vendor" có ≥2 chip (Phase 21), 1 document Type = "PO" (Phase 13/17), và 1 document Type = "Vendor" (Phase 21) đã tồn tại. **Đã xác minh tĩnh** (T289-T298): `dotnet build` trên `ComplianceSys.Application`/`ComplianceSys.Infrastructure` (0 lỗi — build toàn `ComplianceSys.sln`/`ComplianceSys.Api` bị chặn bởi file DLL đang bị khóa do `ComplianceSys.Api` đang chạy sẵn, không liên quan tới code mới), `npx eslint` trên 5 file đã sửa (0 lỗi/cảnh báo), `npx vite build` (thành công). **CHƯA chạy trong trình duyệt** — cùng điều kiện với các kịch bản trước (sau T293, T298).

**Checkpoint**: Edit với Type khác "PO" (kể cả Vendor) cho phép thêm/xóa chip Value, Save đối chiếu
đúng `eutr_references` (chỉ thêm/xóa đúng phần chênh lệch, giữ `Id`/audit của bản ghi không đổi); Type
= "PO" không đổi hành vi (chỉ đọc); endpoint `PUT {id}/step` không đổi route/policy cho caller khác.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: bắt đầu ngay.
- **Foundational (Phase 2)**: sau Setup — **BLOCK toàn bộ user story**.
- **US1 (Phase 3)**: sau Foundational — MVP.
- **US2–US5 (Phase 4–7)**: sau Foundational; nên làm tuần tự sau US1 vì **chia sẻ file**
  `EutrDocumentsController.cs`, `eutr-documents/index.jsx`, `EutrDocumentsActionCell.jsx` (chỉnh
  sửa chồng lấn nếu làm song song).
- **Polish (Phase 8)**: sau khi các story mong muốn hoàn tất.
- **Update 3 (Phase 9)**: sau US2 (Phase 4) — chỉ cần `EutrDocumentsAdd.jsx` đã tồn tại (T029);
  **độc lập** với Phase 5-8 (US3/US4/US5/Polish không đụng `EutrDocumentsAdd.jsx`), có thể làm bất
  kỳ lúc nào sau Phase 4, kể cả song song với Phase 5-7.
- **Update 4 (Phase 10)**: backend (T053-T056) **độc lập**, có thể làm bất kỳ lúc nào (chỉ sửa
  `ComplDynamicsService.cs`/`ComplEnum.cs`, không đụng gì của `eutr-documents`). Frontend (T057-
  T058) yêu cầu Screen1 đã tồn tại trong `EutrDocumentsAdd.jsx` (sau T049, Phase 9) **và** backend
  T053-T055 đã xong (để có dữ liệu thật kiểm thử); độc lập với Phase 5-8 (US3/US4/US5/Polish).
- **Update 5 (Phase 11)**: sau Phase 10 (T057-T058 phải xong — ô tìm kiếm PO cần `poList`/
  `fetchPoList` từ `useReferenceObjects()` đã có trong `EutrDocumentsAdd.jsx`). **Không phụ thuộc
  backend** — Phase 10 chỉ cần `EntityMappings` (T053) đã đăng ký, không cần chờ T054-T056; độc lập
  với Phase 5-8.
- **Update 6 (Phase 12)**: Backend (T063-T070) **độc lập hoàn toàn** với mọi phase khác — không đụng
  `EutrDocumentsController`/`EutrDocumentsService`/`ComplUploadService`/`ComplDynamicsService.cs`,
  chỉ thêm file mới + 1 action mới trong `SharePointController.cs`, có thể làm bất kỳ lúc nào song
  song với Phase 5-11. Frontend (T071-T077) yêu cầu List PO (Screen1) đã tồn tại và có cột `code`
  thật từ `useReferenceObjects()` (sau T057, Phase 10) để `selectedPoCode` có giá trị hợp lệ khi
  test — **không phụ thuộc** Phase 11 (Update 5, ô tìm kiếm PO) vì sửa vùng khác của cùng file. T078
  (kiểm thử) cần cả backend (T063-T070) lẫn frontend (T071-T076) hoàn tất.
- **Update 7 (Phase 13)**: Backend — T079/T080 (migration + DDL) **độc lập hoàn toàn**, có thể làm
  bất kỳ lúc nào. T081 (entity `EutrReferences`) độc lập. T082 → T083 (mở rộng
  `IEutrMastersRepository`/`EutrMastersRepository`, tuần tự vì cùng cặp interface/impl) độc lập với
  mọi phase khác (feature `002-eutr-masters` không bị sửa hành vi cũ, chỉ thêm method mới). T084 →
  T085 (sửa `EutrUploadService.cs`) **phải sau** Phase 12 hoàn tất (T066, vì sửa cùng file) **và**
  sau T081/T083 (cần entity `EutrReferences` + method `GetMatchingPrefixesAsync` tồn tại) **và** sau
  T079 (migration đã chạy, để `StepId` tồn tại trên DB khi test). Frontend — T086 → T087 (sửa
  `EutrDocumentsAdd.jsx`, tuần tự vì cùng file) **phải sau** Phase 12 hoàn tất (T076, vì sửa cùng
  khối code Upload) — độc lập với Phase 5-11. T089 (kiểm thử) cần cả backend (T079-T085) lẫn
  frontend (T086-T088) hoàn tất, cùng dữ liệu test trong `eutr_master_documents`.
- **Update 8 (Phase 14)**: Backend — T090-T094 (projection DTO/request/response, file khác nhau)
  **độc lập hoàn toàn**, có thể làm ngay từ đầu (không phụ thuộc phase nào). T095 (interface) sau
  T090/T091 (cần type tham chiếu). T096 → T097 (tạo `EutrReferencesRepository.cs`, tuần tự vì cùng
  file/class) sau T095; **độc lập** với Phase 5-13 (không đụng `EutrUploadService`/entity ghi của
  Update 7). T098 (DI) sau T096/T097. T099 (sửa `EutrDocumentsResponseDto.cs`) độc lập. T100 (sửa
  `EutrDocumentsService.GetPagedAsync`) sau T096, T098, T099 — **và** sau Phase 2 (T010, vì sửa file
  đã tạo ở Foundational). T101 → T102 (thêm method `GetPoReferencesAsync`, cùng file
  `EutrDocumentsService.cs`, có thể làm song song với dòng T099→T100 nếu khác đoạn code, nhưng nên
  tuần tự vì cùng file) sau T097, T093, T094. T103 (action mới `EutrDocumentsController.cs`) sau
  T102 — **và** sau Phase 2 (T011, controller đã tồn tại). Frontend — T104 (`MultiValueChips.jsx`)
  độc lập, có thể làm ngay từ đầu. T105 (sửa `useEutrDocumentsColumns.jsx`) sau T104 — **và** sau
  Phase 3 (T025, file đã tồn tại). T106 → T107 (sửa entity/repository FE, tuần tự) độc lập với
  Phase 3-13. T108, T109, T110 (use case/interface/api, file khác nhau) độc lập, có thể làm song
  song. T111 (implement repository FE) sau T109, T110. T112 → T113 (sửa `EutrDocumentsAdd.jsx`,
  tuần tự vì cùng file) sau T108, T111, T104 — **và** sau Phase 12 (T074, cần `selectedPoId`/
  `selectedPo` đã có) và Phase 6-7 nếu tính theo lịch sử file (thực tế chỉ cần T029/T047-T050/T074
  đã tồn tại). T116/T117 (kiểm thử) cần toàn bộ Backend + Frontend của Phase 14 hoàn tất, cùng dữ
  liệu test đã dùng ở Phase 12/13 (T078/T089).
- **Update 9 (Phase 15)**: T118 (thêm khai báo vào `IEutrReferencesRepository.cs`) → T119 (implement
  trong `EutrReferencesRepository.cs`), tuần tự vì là cặp interface/impl của cùng method mới — sau
  Phase 14 (T095/T096, file đã tồn tại), độc lập với mọi phase khác. T120 (override `DeleteAsync` +
  thêm field `_unitOfWork`) → T121 (override `DeleteMultiAsync`), tuần tự vì cùng file
  `EutrDocumentsService.cs` — sau T119 (cần `DeleteByDocumentIdAsync` tồn tại) **và** sau Phase 2
  (T010, service đã tồn tại) **và** sau Phase 14 (T100/T102, cùng file — tránh conflict khi chỉnh
  song song, không có phụ thuộc logic thật giữa các method). T122 (kiểm thử) cần T118-T121 hoàn tất
  và dữ liệu test giống T116/T117 (document có `eutr_references` từ Phase 12/13).
- **Update 10 (Phase 16)**: T123 (endpoint mới `EutrDocumentsController.cs`) **độc lập** với mọi
  phase khác (chỉ thêm constructor param + 1 action mới, không đụng 7 action hiện có) — có thể làm
  bất kỳ lúc nào sau Phase 2 (T011, controller đã tồn tại). T124 → T125 (thêm field `FileId` vào 2
  DTO khác file, có thể song song với nhau) → T126 (sửa SQL, sau T124 để field tồn tại) → T127 (gán
  field, sau T125/T126) — cả 4 task này sửa các file đã tạo ở Phase 14 (Update 8), độc lập với
  Phase 5-13/15. T128 (tổng quát hoá `FilePreviewer.jsx`) **độc lập hoàn toàn** — file này không
  thuộc feature `004-eutr-documents`, có thể làm bất kỳ lúc nào (chỉ cần không phá vỡ
  `compliance-detail`, không phụ thuộc phase nào của feature này). T129/T130 (API/interface, file
  khác nhau) song song, độc lập. T131 (implement repository) sau T129/T130. T132 (use case) độc lập,
  có thể làm sớm. T133 (`EutrFileViewerDialog.jsx`) sau T128, T131, T132. T134 (sửa
  `EutrDocumentsActionCell.jsx`) sau Phase 7 (T040, file đã tồn tại). T135 (sửa
  `useEutrDocumentsColumns.jsx`) sau T134 — và sau Phase 3 (T025, file đã tồn tại). T136 (sửa
  `index.jsx`) sau T133, T135 — và sau Phase 3/6 (T026/T039, file đã tồn tại). T137 → T138 (sửa
  `EutrDocumentsAdd.jsx`, tuần tự vì cùng file) sau T133 (dialog tồn tại), T127 (cần `doc.fileId`
  thật), và sau Phase 14 (T112/T113, bảng chi tiết List PO đã tồn tại) — T138 còn cần Phase 6 (T037,
  `DeleteEutrDocumentsUseCase` đã tồn tại). T139 (rà soát text) sau T133, T138. T140/T141 (kiểm thử)
  cần toàn bộ Backend + Frontend của Phase 16 hoàn tất, cùng dữ liệu test đã dùng ở Phase 12/13/14.
- **Update 11 (Phase 17)**: T142/T143/T144 (entity + 2 DTO, file khác nhau) song song, có thể làm
  ngay từ đầu. T145 (interface) sau T143. T146 (implement repository) sau T142, T145. T147 (DI) sau
  T146. **T148 (sửa SQL `DeleteByDocumentIdAsync`) độc lập hoàn toàn, có thể làm bất kỳ lúc nào —
  nhưng BẮT BUỘC hoàn tất trước T163 (lần đầu ghi dữ liệu thật vào `eutr_reference_details`), tránh
  vi phạm khóa ngoại khi Delete document sau này**. T149 (DTO) độc lập. T150 (interface) sau T149.
  T151 (implement) sau T150 — và sau Phase 12 (T066, cùng file `EutrUploadService.cs`). T152 (action
  controller) sau T151 — và sau Phase 12 (T067, cùng file `SharepointController.cs`). T153
  (interface) độc lập. T154 (implement, cùng file `EutrReferencesRepository.cs` với T148 nhưng khác
  method) sau T153. T155 (interface service) độc lập. T156 (implement) sau T154, T155. T157 (DTO
  field) sau T144. T158 (mở rộng `AttachStepAndConditionInfoAsync`, cùng file với T156) sau T146,
  T147, T157, T156. T159 (DTO) độc lập, có thể làm sớm. T160 (DTO) sau T159. T161 (validator) sau
  T160. T162 (interface service) sau T160. T163 (implement, sau T148 — xem lưu ý trên) sau T142,
  T162. T164 (DI) sau T161, T163. T165 (action controller, cùng file `EutrDocumentsController.cs`
  với Phase 2/10/14/16 nhưng thêm mới) sau T156, T164. Frontend: T166/T167/T170/T171 (file khác
  nhau) song song, có thể làm sớm. T168 sau T167. T169 sau T168. T172 sau T170, T171. T173/T174 song
  song, sau T172. T175 (`AssignConditionDialog.jsx` mới) sau T166, T174. T176 (cột Conditions) sau
  T166 — và sau Phase 14 (T105, cùng file `useEutrDocumentsColumns.jsx`). T177 (Screen2, cùng file
  `EutrDocumentsAdd.jsx` với chuỗi Update 3-10 đã có) sau T169, T173 — và sau Phase 16 (T138, dòng
  cuối cùng đã sửa file này). T178 (cùng file) sau T175, T177. T179/T180 sau cùng.
- **Update 12 (Phase 18)**: T181/T182/T183 (3 DTO, file khác nhau) song song. T184 (validator) sau
  T181. T185 (mở rộng interface) sau T181, T183. T186 (implement, cùng file
  `EutrConditionAssignmentService.cs` với T163 nhưng thêm method mới) sau T185, T146, T148 (**bắt
  buộc SQL cascade đã sửa trước khi có luồng sửa Step nào chạy trên dữ liệu thật**). T187 (action
  controller, cùng file với T165) sau T182, T184, T186. T188 (DI) sau T184. Frontend:
  T189/T190 (file khác nhau) song song. T191 sau T189, T190. T192/T193/T194 song song, sau T191.
  T195 (mở rộng `AssignConditionDialog.jsx`, cùng file với T175/T176/T206) sau T175 (Phase 17), T193.
  T196 (`EutrDocumentsModal.jsx`, cùng file với Phase 5 T033) sau T194. T197 (`index.jsx`, cùng file
  với chuỗi Phase 3/6/16 T026/T039/T136) sau T192, T195. T198/T199 sau cùng.
- **Update 13 (Phase 19)**: T200 (DTO field) độc lập. T201 (SQL, cùng file `EutrReferencesRepository.cs`
  với T148/T154 nhưng khác method) sau T200. T202 (DTO field) độc lập. T203 (cùng file
  `EutrDocumentsService.cs` với T158) sau T201, T202, T158. T204/T205 (2 validator khác file) song
  song, độc lập — có thể làm bất kỳ lúc nào sau Phase 17/18 (T161/T184 đã tạo file). Frontend: T206
  (cùng file `AssignConditionDialog.jsx`) sau T175, T195. T207/T208 sau cùng.
- **Update 14 (Phase 20)**: T209 (migration mới, file độc lập) không phụ thuộc task nào khác — có
  thể chạy bất kỳ lúc nào. T210 (DTO field `TypeName` trên `EutrReferenceStepInfo.cs`) độc lập. T211
  (SQL, cùng file `EutrReferencesRepository.cs` với T148/T154/T201 nhưng khác cột `SELECT`, cùng
  method `GetStepInfoByDocumentIdsAsync` với T201) sau T210. T212 (DTO field `TypeName` trên
  `EutrDocumentsResponseDto.cs`) độc lập. T213 (cùng file `EutrDocumentsService.cs` với T158/T203)
  sau T211, T212. Frontend: T214 (cùng file `useEutrDocumentsColumns.jsx` với T025/T105/T135/T176)
  sau T213. T215 sau cùng.
- **Update 15/16 (Phase 21)**: T216 (DTO mới, file độc lập) không phụ thuộc task nào khác. T217 (cùng
  file `IEutrUploadService.cs` với T065/T150) sau T216, T150. T218 (cùng file `EutrUploadService.cs`
  với T066/T084-T085/T151) sau T217, T151. T219 (cùng file `SharepointController.cs` với T067/T152)
  sau T218, T152. Frontend: T220 (cùng file `ISharePointRepository.js` với T071/T167) độc lập với
  T217-T219 (khác file), có thể làm song song với backend. T221 (cùng file
  `RestSharePointRepository.js` với T072/T168) sau T220, T167. T222 (cùng file
  `UploadToSharePointUseCase.js` với T073/T169) sau T221, T169. T223 (component mới, file độc lập)
  không phụ thuộc task nào khác — có thể làm song song với T216-T222. T224 (component mới, file độc
  lập) sau T216-T223 (cần API T219/T222 và component Value T223 sẵn sàng để wiring). T225 (cùng file
  `index.jsx` với T021/T026/T030/T035/T039/T136/T197) sau T224, T197. T226 sau cùng.
- **Update 17 (Phase 22)**: T227 (cùng file `EutrAddValueAutocomplete.jsx` với T223) sau T223 — **độc
  lập hoàn toàn với T228** (khác file, có thể làm song song). T228 (cùng file
  `EutrDocumentsAddDialog.jsx` với T224) sau T224 — cần `executeEutrMulti` (T073, Update 6) đã tồn
  tại trên `UploadToSharePointUseCase`. **KHÔNG có task backend nào trong phase này** (research
  Quyết định 51). T229 (kiểm thử) sau T227, T228.
- **Update 18 (Phase 23)**: T230 (DTO field, file độc lập) không phụ thuộc task nào khác. T231 (cùng
  file `EutrUploadService.cs` với T066/T084-T085/T151/T218) sau T230, T218. T232 (cùng file
  `RestSharePointRepository.js` với T072/T168/T221) độc lập với T230/T231 (khác file), có thể làm
  song song với backend. T233 (cùng file `UploadToSharePointUseCase.js` với T073/T169/T222) sau
  T232. T234 (cùng file `EutrDocumentsAddDialog.jsx` với T224/T228) sau T233, T228. T235 (kiểm thử)
  sau T230-T234.
- **Update 19 (Phase 24)**: Backend — T236 (DTO field độc lập) → T237 (cùng file
  `EutrReferencesRepository.cs` với T096/T097/T118/T126/T148/T154/T201/T211) sau T236. T238 (DTO,
  file độc lập) không phụ thuộc task nào. T239 (cùng file `EutrDocumentsService.cs` với
  T010/T100/T120-T121/T127/T156/T158/T203/T213) sau T237, T238. T240 (interface, file độc lập) không
  phụ thuộc task nào. T241 (cùng file `EutrReferencesRepository.cs` với T237) sau T240. T242 (đổi tên
  DTO, file độc lập) không phụ thuộc task nào. T243 (interface service) sau T242. T244 (cùng file
  `EutrDocumentsService.cs` với T239) sau T241, T243. T245 (cùng file `EutrDocumentsController.cs`
  với T011/T022/T027/T031/T036/T103/T123/T165/T187) sau T244 — **điểm chốt quan trọng**: mọi task
  xóa backend phía sau (T248-T251) đều phụ thuộc T245 đã xóa hết tham chiếu tới
  `IEutrConditionAssignmentService`/các action cũ. T246 (cùng file `EutrDocumentsService.cs`) sau
  T245. T247 (cùng file `EutrReferencesRepository.cs`) sau T246. T248/T249/T250/T251 (xóa file, độc
  lập với nhau) đều sau T245 (T249 còn cần sau T248; T251 cần sau T246/T247). T252 (cùng file
  `SharepointController.cs` với T067/T152) độc lập với T236-T251 (khác file). T253 (cùng file
  `EutrUploadService.cs` với T065-T066/T084-T085/T150-T151/T217-T218/T231) sau T252. T254 (DI, sau
  T248, T249, T250) độc lập với T252/T253. T255/T256 (2 DTO field, file khác nhau) song song, độc
  lập với T236-T254. T257 (cùng file `EutrUploadService.cs` với T253) sau T255, T256, T253. Frontend
  — T258 (cùng file `useEutrDocumentsColumns.jsx` với T025/T105/T135/T176/T214) sau T239 (cần shape
  `conditions` mới để test end-to-end, không phải phụ thuộc biên dịch). T259 (cùng file
  `EutrDocumentsAddDialog.jsx`/`EutrDocumentsFormDialog.jsx` với T224/T228/T234) độc lập với backend,
  có thể làm song song. T260 sau T259. T261/T263 (2 file khác nhau) song song. T262 (cùng file
  `UploadToSharePointUseCase.js` với T073/T169/T222/T233) sau T261. T264 sau T260, T262. T265 (đổi
  tên use case, file độc lập) không phụ thuộc task nào. T266 (cùng file `EutrDocumentsFormDialog.jsx`)
  sau T264, T265, T245. T267 (cùng file `index.jsx` với T021/T026/T030/T035/T039/T136/T197/T225) sau
  T266. T268/T269 (xóa file, độc lập với nhau) sau T267. T270 (repository/api FE) sau T245. T271
  (xóa use case, sau T270). T272 (sau T268). T273/T274/T275 (kiểm thử) sau toàn bộ Backend + Frontend
  tương ứng của Phase 24 hoàn tất.
- **Update 22 (Phase 27)**: Backend — T289 (DTO field, độc lập) → T290 (2 khai báo interface, độc
  lập với T289) → T291 (implement, sau T290) → T292 (service, sau T289, T291) → T293 (controller, sau
  T292). Frontend — T294/T295 (api client + interface, file khác nhau) song song → T296 (repository,
  sau cả hai) → T297 (use case, sau T296) → T298 (`EutrDocumentsFormDialog.jsx`, sau T297 **và** sau
  Phase 25 T279, cùng file) → T299 (kiểm thử, sau T293 **và** T298). Toàn bộ Phase 27 phụ thuộc Phase
  24 (T244/T245, cùng `EutrUpdateReferenceStepRequestDto.cs`/`EutrDocumentsService.cs`/
  `EutrDocumentsController.cs`) và Phase 25 (T279, cùng `EutrDocumentsFormDialog.jsx`) — độc lập với
  Phase 3-23, 26 (không đụng US1/US2/US4-US6, Update 3-18/21).
- **Update 20 (Phase 25)**: **Không có task backend nào** — chỉ 1 file frontend, sửa tuần tự vì cùng
  file: T276 (import + instantiate use case đã có sẵn) → T277 (hàm `loadFilteredSteps` dùng chung cho
  cả 2 mode) → T278 (mode add: gọi khi Type đổi + mặc định dòng đầu) và T279 (mode edit: gọi 1 lần khi
  mở popup + đảm bảo Step hiện tại luôn hiển thị) đều sau T277, độc lập với nhau (khác nhánh
  `mode==='add'`/`mode==='edit'` trong cùng component, có thể chỉnh song song nếu tách rõ đoạn code
  nhưng khuyến nghị làm tuần tự vì cùng file). T280 (kiểm thử US2) sau T278; T281 (kiểm thử US3) sau
  T279. Toàn bộ Phase 25 sau Phase 24 (T266, cần `EutrDocumentsFormDialog.jsx` đã có prop `mode`/
  `initialData` và logic Step hiện có của Update 19) — độc lập với mọi phase khác (không đụng file
  backend/frontend nào khác ngoài `EutrDocumentsFormDialog.jsx`).

### Điểm chia sẻ file (tránh sửa song song)

- `EutrDocumentsController.cs`: T011 (skeleton) → T022 (US1: get-all/get-by-id) → T027 (US2:
  create) → T031 (US3: update) → T036 (US4: delete/delete-multi). US5 không đụng file này ở lần đầu
  — **Update 10 (Phase 16)**: T123 (thêm constructor param `ISharepointService` + action mới
  `get-file-by-idref`), sau T036 (không đụng lại 7 action hiện có) → **Update 11 (Phase 17)**: T165
  (thêm constructor param `IEutrConditionAssignmentService` + action `get-unassigned`/
  `assign-conditions`), sau T123 → **Update 12 (Phase 18)**: T187 (thêm action
  `condition-assignment` GET/PUT + `step` PUT), sau T165.
- `eutr-documents/index.jsx`: T021 (shell) → T026 (US1: grid) → T030 (US2: nút Add navigate) →
  T035 (US3: wiring Edit) → T039 (US4: wiring Delete) → **Update 10 (Phase 16)**: T136 (state +
  wiring popup xem trước file, sau T039) → **Update 12 (Phase 18)**: T197 (`onEdit` rẽ nhánh theo
  `refType`, sau T136) → **Update 15/16 (Phase 21)**: T225 (nút Add đổi từ `navigate(...)` sang mở
  `EutrDocumentsAddDialog`, sau T197 — không đụng `onEdit` đã rẽ nhánh).
- `EutrDocumentsActionCell.jsx`: T034 (US3: Edit/Delete) → T040 (US5: thêm icon View) →
  **Update 10 (Phase 16)**: T134 (đổi icon View từ silent no-op sang control thật, sau T040).
- `useEutrDocumentsColumns.jsx`: T025 (US1: khai báo cột) → T105 (Update 8: renderCell Step
  name/Type) → **Update 10 (Phase 16)**: T135 (thêm prop `onView`, sau T105 và sau T134) →
  **Update 11 (Phase 17)**: T176 (renderCell cột Conditions, sau T135) → **Update 14 (Phase 20)**:
  T214 (cột Type đổi `valueGetter` sang `row.typeName`, bỏ tra `TAKE_FROM_OPTIONS`, sau T176).
- `EutrDocumentsService.cs`: tạo ở T010 (Foundational) — không override ở US1-US5/Update 3-8 (khác
  `eutr-masters` phải override `AddAsync`/`UpdateAsync` để chống trùng); **Update 9 (Phase 15)**:
  T120 (override `DeleteAsync` + field `_unitOfWork`) → T121 (override `DeleteMultiAsync`), tuần tự
  vì cùng file, sau T119; **Update 10 (Phase 16)**: T127 (gán thêm `FileId` trong
  `GetPoReferencesAsync`), sau T121 (khác đoạn code với Update 9, không phụ thuộc logic) →
  **Update 11 (Phase 17)**: T156 (implement `GetUnassignedPagedAsync`) → T158 (đổi tên
  `AttachStepInfoAsync`→`AttachStepAndConditionInfoAsync`, gán thêm `Conditions`), tuần tự vì cùng
  file, sau T127 → **Update 13 (Phase 19)**: T203 (gán thêm `StepId` theo `ReferenceId` nhỏ nhất
  trong cùng method đã đổi tên ở T158), sau T158 → **Update 14 (Phase 20)**: T213 (gán thêm
  `TypeName` trong cùng method), sau T203, T211, T212.
- `EutrDocumentsAdd.jsx`: T029 (US2: tạo trang) → T047 → T049 → T050 (Update 3: Type + Screen1 +
  Screen2, tuần tự vì cùng file); T048 (hằng số demo) có thể làm song song với T047 trước khi T049/
  T050 cần dùng tới, T051 (rà soát text) làm sau T050 → T057 → T058 (Update 4: List PO nối API
  thật, tuần tự sau T049/T050 vì cùng file) → T060 → T061 (Update 5: ô tìm kiếm gọi API, tuần tự
  sau T057/T058 vì cùng file và cần `poList`/`fetchPoList` đã có) → T074 → T075 → T076 (Update 6:
  chọn PO đơn + nút Upload thay khu kéo-thả, tuần tự vì cùng file, sau T057 để có cột `code` thật)
  → T086 → T087 (Update 7: gộp logic click/kéo-thả + thiết kế lại card Upload, tuần tự vì cùng
  file, sau T076) → T112 → T113 (Update 8: state + effect tra cứu reference, đổi bảng chi tiết
  sang dữ liệu thật, tuần tự vì cùng file, sau T074 để có `selectedPoId`/`selectedPo`) → T137 →
  T138 (Update 10: gắn View/Delete thật cho mỗi dòng bảng chi tiết List PO, tuần tự vì cùng file,
  sau T113) → **Update 11 (Phase 17)**: T177 → T178 (Screen2 thật: khu Upload File + bảng "chưa
  gán" + nút Assign condition, tuần tự vì cùng file, sau T138).
- `EutrDocumentsService.cs` (Update 8): T100 (mở rộng `GetPagedAsync` cho Step name/Type) và
  T101→T102 (thêm `GetPoReferencesAsync`) đều sửa cùng file đã tạo ở T010 (Foundational) — làm tuần
  tự với nhau nếu cùng người/agent chỉnh sửa (khác đoạn code, không bắt buộc thứ tự giữa 2 nhóm này
  nhưng tránh conflict khi chỉnh song song).
- `EutrDocumentsResponseDto.cs`/`IEutrDocumentsService.cs`/`EutrDocumentsController.cs` (Update 8):
  chỉ 1 task sửa mỗi file (T099, T101, T103) — không đụng lại các action/field đã có từ Phase 2-13.
- `EutrReferencePoDocumentInfo.cs`/`EutrDocumentsPoReferenceItemDto.cs` (Update 8 → 10): T091/T093
  (tạo, Update 8) → T124/T125 (thêm field `FileId`, Update 10), mỗi file 1 task nối tiếp — 2 file
  khác nhau, có thể làm song song với nhau ở Update 10.
- `EutrReferencesRepository.cs` (Update 8 → 9 → 10 → 11 → 13 → 14, file tạo ở Update 8): T096 (tạo file +
  method 1) → T097 (thêm method 2, Update 8) → T119 (thêm method 3 `DeleteByDocumentIdAsync`,
  Update 9) → T126 (thêm `FileId` vào `SELECT` của method 2, Update 10) → **Update 11 (Phase 17)**:
  T148 (sửa SQL `DeleteByDocumentIdAsync` — dọn `eutr_reference_details` trước, **BẮT BUỘC** trước
  T163) → T154 (thêm method 4 `GetUnassignedDocumentsPagedAsync`) → **Update 13 (Phase 19)**: T201
  (thêm `ReferenceId` vào `SELECT` của method 1) → **Update 14 (Phase 20)**: T211 (thêm
  `LEFT JOIN eutr_reference_types` + `TypeName` vào `SELECT` của method 1, cùng method với T201) —
  toàn bộ tuần tự vì cùng file, độc lập hoàn toàn với `EutrUploadService.cs` (Update 6/7/11, chỉ ghi
  qua `IRepository<EutrReferences,long>` generic, không dùng repository này).
- `IEutrReferencesRepository.cs` (Update 8 → 9 → 11): T095 (tạo, 2 method đọc) → T118 (thêm method
  `DeleteByDocumentIdAsync`, Update 9) → **Update 11 (Phase 17)**: T153 (thêm method
  `GetUnassignedDocumentsPagedAsync`), tuần tự vì cùng file. Update 10/13 không sửa file này (chỉ
  đổi field trên DTO/SQL, không thêm method mới).
- `ComplDynamicsService.cs` (Update 4): T053 (EntityMappings) → T054 (case 15) → T055 (case 16),
  tuần tự vì cùng file (không đụng gì của Phase 1-9).
- `SharePointController.cs` (Update 6 → 11): T067 (action `eutr-upload-multi`, sau T066) →
  **Update 11 (Phase 17)**: T152 (thêm action `eutr-upload-manual-multi`), sau T067 — không đụng
  các action hiện có. Update 7/10/12/13 KHÔNG sửa file này.
- `EutrUploadService.cs` (Update 6 → 7 → 11 → 15/16 → 18): T066 (tạo mới, Update 6) → T084 → T085
  (mở rộng validate prefix + ghi `eutr_references`, Update 7, tuần tự vì cùng file, sau T066) →
  **Update 11 (Phase 17)**: T151 (thêm method `UploadManualMultipleToSharePointAndSaveDataAsync`),
  sau T085 — khác method, không phụ thuộc logic → **Update 15/16 (Phase 21)**: T218 (thêm method
  `UploadMultipleForReferenceTypeAsync` + hàm private `ResolveFolderName`, tái dùng
  `ResolveOrCreatePoFolderAsync` đã có), sau T151 — khác method, không phụ thuộc logic →
  **Update 18 (Phase 23)**: T231 (đổi dòng gán `RefType` trong `UploadMultipleToSharePointAndSaveDataAsync`
  thành ternary theo `request.TypeId`), sau T218 — cùng method với T085, khác method với T218, cần
  `EutrMultiUploadFileRequest.TypeId` (T230) đã tồn tại để tham chiếu. `IEutrUploadService.cs`
  cùng chuỗi: T065 (Update 6) → T150 (Update 11) → T217 (Update 15/16) — **KHÔNG đổi ở Update 18**
  (chữ ký `UploadMultipleToSharePointAndSaveDataAsync` không đổi, chỉ nội dung implement). `SharepointController.cs`
  cùng chuỗi: T067 (Update 6) → T152 (Update 11) → T219 (Update 15/16, action
  `eutr-upload-multi-by-type`) — **KHÔNG đổi ở Update 18** (action `eutr-upload-multi` không đổi chữ
  ký, chỉ DTO body nhận thêm field). Update 10/12/13 không sửa 3 file này.
- `EutrMultiUploadFileRequest.cs` (Update 6 → 18): T063 (tạo mới, `{ Files, PoCode }`, Update 6) →
  **Update 18 (Phase 23)**: T230 (thêm field nullable `TypeId`), tuần tự vì cùng file — độc lập với
  mọi phase khác.
- `IEutrMastersRepository.cs`/`EutrMastersRepository.cs` (Update 7): T082 (thêm khai báo interface)
  → T083 (implement), tuần tự vì là cặp interface/impl của cùng method mới — không đụng các method
  hiện có của feature `002-eutr-masters` (`GetPagedWithStepNameAsync`, `ExistsStepPrefixAsync`).
- `FilePreviewer.jsx` (Update 10, file KHÔNG thuộc feature `004-eutr-documents` — dùng chung với
  `compliance-detail`): chỉ 1 task sửa file này (T128) — thêm 2 prop tùy chọn, KHÔNG đổi logic
  render hiện có, không ảnh hưởng caller `compliance-detail`.
- `IEutrConditionAssignmentService.cs`/`EutrConditionAssignmentService.cs` (Update 11 → 12, file tạo
  ở Update 11): T162 → T163 (tạo, `AssignConditionsAsync`) → **Update 12 (Phase 18)**: T185 (thêm 3
  khai báo `GetConditionAssignmentAsync`/`UpdateConditionAssignmentAsync`/`UpdatePoStepAsync`) →
  T186 (implement 3 method trên), tuần tự vì cùng cặp file — `UpdatePoStepAsync`/
  `UpdateConditionAssignmentAsync` (T186) phải sau T148 (SQL cascade đã sửa ở Phase 17).
- `AssignConditionDialog.jsx` (Update 11 → 12 → 13, file tạo ở Update 11): T175 (tạo, `mode="create"`)
  → **Update 12 (Phase 18)**: T195 (thêm `mode="edit"`) → **Update 13 (Phase 19)**: T206 (disable
  Conditions type đã dùng ở dòng khác trong dropdown), tuần tự vì cùng file.
- `EutrAddValueAutocomplete.jsx` (Update 15/16 → 17, file tạo ở Phase 21): T223 (tạo) → **Update 17
  (Phase 22)**: T227 (reset input về rỗng ngay sau khi thêm chip), tuần tự vì cùng file — độc lập với
  mọi phase khác.
- `EutrDocumentsAddDialog.jsx` (Update 15/16 → 17 → 18, file tạo ở Phase 21): T224 (tạo) → **Update 17
  (Phase 22)**: T228 (rẽ nhánh `isPoType`: ẩn Step + gọi lại `executeEutrMulti` thay vì
  `executeEutrMultiByType`), tuần tự vì cùng file — cần `executeEutrMulti` (T073, Update 6) đã tồn
  tại, độc lập với Phase 3-20 → **Update 18 (Phase 23)**: T234 (nhánh `isPoType` truyền thêm `type.id`
  vào `executeEutrMulti`), tuần tự vì cùng file — cần `executeEutrMulti(files, poCode, typeId)` (T233)
  đã đổi chữ ký.
- `RestSharePointRepository.js` (Update 6 → 11 → 15/16 → 18): T072 (`uploadEutrFilesMulti`, Update 6)
  → **Update 11 (Phase 17)**: T168 (`uploadEutrManualFilesMulti`, khác method) → **Update 15/16
  (Phase 21)**: T221 (`uploadEutrFilesMultiByType`, khác method) → **Update 18 (Phase 23)**: T232
  (đổi chữ ký `uploadEutrFilesMulti` để nhận thêm `typeId`, cùng method với T072), tuần tự vì cùng
  file — độc lập với T230/T231 (backend, khác file).
- `UploadToSharePointUseCase.js` (Update 6 → 11 → 15/16 → 18): T073 (`executeEutrMulti`, Update 6) →
  **Update 11 (Phase 17)**: T169 (`executeManualMulti`, khác method) → **Update 15/16 (Phase 21)**:
  T222 (`executeEutrMultiByType`, khác method) → **Update 18 (Phase 23)**: T233 (đổi chữ ký
  `executeEutrMulti` để nhận thêm `typeId`, cùng method với T073), tuần tự vì cùng file — sau T232
  (cần `uploadEutrFilesMulti` đã đổi chữ ký).
- `EutrDocumentsModal.jsx` (Update 3 → 12, file tạo ở Phase 5): T033 (tạo, File name/Valid from/
  Valid to) → **Update 12 (Phase 18)**: T196 (thêm trường Step có điều kiện khi Type="PO"), tuần tự
  vì cùng file — độc lập với Phase 9-17 (không phần nào khác sửa lại file này).
- `EutrDocumentsResponseDto.cs` (Update 8 → 11 → 13 → 14): T099 (tạo, `StepNames`/`RefType`, Update 8) →
  **Update 11 (Phase 17)**: T157 (thêm `Conditions`) → **Update 13 (Phase 19)**: T202 (thêm
  `StepId`) → **Update 14 (Phase 20)**: T212 (thêm `TypeName`), tuần tự vì cùng file (T212 độc lập
  về nội dung, chỉ tuần tự do cùng file).
- `ComplianceSys.Application/DependencyInjection.cs` (Update 11 → 12): T164 (đăng ký
  `IEutrConditionAssignmentService` + validator `EutrAssignConditionsRequestDtoValidator`) →
  **Update 12 (Phase 18)**: T188 (đăng ký thêm validator
  `EutrUpdateConditionAssignmentRequestDtoValidator`), tuần tự vì cùng file — độc lập với các dòng
  đăng ký DI khác đã có từ Phase 2/12 (Foundational/Update 6, khác đoạn code).
- **Update 19 (Phase 24) — tiếp nối/kết thúc các chuỗi file ở trên**:
  `EutrReferencesRepository.cs`/`IEutrReferencesRepository.cs` (chuỗi Update 8→9→10→11→13→14 ở
  trên) → **Update 19**: T237 (+`RefValue` vào `SELECT` của `GetStepInfoByDocumentIdsAsync`) → T241
  (+`UpdateStepIdByDocumentIdAsync`, method mới) → T247 (XÓA `GetDocumentsByPoCodesAsync`/
  `GetUnassignedDocumentsPagedAsync`), tuần tự vì cùng cặp file.
  `EutrDocumentsService.cs`/`IEutrDocumentsService.cs` (chuỗi Foundational→9→10→11→13→14 ở trên) →
  **Update 19**: T239 (Conditions phẳng) → T244 (+`UpdateReferenceStepAsync`) → T246 (XÓA
  `GetUnassignedPagedAsync`/`GetPoReferencesAsync`), tuần tự vì cùng cặp file.
  `EutrDocumentsController.cs` (chuỗi Foundational→10→11→12 ở trên) → **Update 19**: T245 (repurpose
  action `{id}/step`, XÓA 5 action `get-unassigned`/`assign-conditions`/`condition-assignment`
  GET+PUT/`list-po-references`, XÓA constructor param `IEutrConditionAssignmentService`) — **đây là
  task chốt** khiến `IEutrConditionAssignmentService.cs`/`EutrConditionAssignmentService.cs` (T248),
  `EutrReferenceDetails.cs`/`IEutrReferenceDetailsRepository.cs`/`EutrReferenceDetailsRepository.cs`
  (T249), và mọi DTO List-PO/Assign-condition (T250, T251) trở nên an toàn để **XÓA HẲN**.
  `EutrUploadService.cs`/`IEutrUploadService.cs` (chuỗi Update 6→7→11→15/16→18 ở trên) → **Update
  19**: T253 (XÓA `UploadManualMultipleToSharePointAndSaveDataAsync`) → T257 (2 method upload còn
  lại dùng `request.ValidFrom`/`ValidTo` thay hằng số cố định), tuần tự vì cùng file.
  `SharepointController.cs` (chuỗi Update 6→11 ở trên) → **Update 19**: T252 (XÓA action
  `eutr-upload-manual-multi`), tuần tự vì cùng file.
  `EutrMultiUploadFileRequest.cs` (chuỗi Update 6→18 ở trên) → **Update 19**: T255 (+`ValidFrom`/
  `ValidTo`), tuần tự vì cùng file — độc lập với `EutrTypeMultiUploadFileRequest.cs` (T256, file
  khác, tạo ở Phase 21).
  `EutrDocumentsAddDialog.jsx` (chuỗi Update 15/16→17→18 ở trên, file tạo ở Phase 21) → **Update 19**:
  ĐỔI TÊN → `EutrDocumentsFormDialog.jsx` (T259) → T260 (+Valid from/to) → T264 (truyền
  validFrom/validTo khi Upload) → T266 (+mode edit), tuần tự vì cùng file (tên file đổi nhưng lịch sử
  chỉnh sửa tiếp nối trực tiếp từ T224/T228/T234) → **Update 20 (Phase 25)**: T276 (import + instantiate
  `GetByTypeIdEutrReferenceTypeDetailsUseCase`) → T277 (hàm `loadFilteredSteps`) → T278 (mode add:
  lọc + mặc định dòng đầu) / T279 (mode edit: đảm bảo Step hiện tại luôn hiển thị), tuần tự vì cùng
  file — đây là file duy nhất bị sửa ở Phase 25.
  `RestSharePointRepository.js`/`UploadToSharePointUseCase.js` (2 chuỗi Update 6→11→15/16→18 ở trên)
  → **Update 19**: T261/T262 (+`validFrom`/`validTo`, XÓA `uploadEutrManualFilesMulti`/
  `executeManualMulti`), tuần tự vì cùng cặp file.
  `ISharePointRepository.js` (chuỗi Update 6→11→15/16 — chỉ thêm method qua các Update, chưa từng có
  bảng riêng ở trên) → **Update 19**: T263 (XÓA khai báo `uploadEutrManualFilesMulti`).
  `useEutrDocumentsColumns.jsx` (chuỗi Update 8→10→11→14 ở trên) → **Update 19**: T258 (renderCell
  Conditions đổi sang flat `MultiValueChips`, bỏ `CONDITION_TYPE_OPTIONS`), tuần tự vì cùng file.
  `index.jsx` (chuỗi Foundational→...→15/16 ở trên) → **Update 19**: T267 (`onEdit` không còn rẽ
  nhánh, luôn mở `EutrDocumentsFormDialog` mode="edit"), tuần tự vì cùng file — task cuối cùng trong
  chuỗi này (không có Update nào sau sửa lại file).
  `EutrDocumentsModal.jsx` (chuỗi Update 3→12 ở trên) → **Update 19**: T268 **XÓA HẲN** (sau T267).
  `AssignConditionDialog.jsx` (chuỗi Update 11→12→13 ở trên) → **Update 19**: T268 **XÓA HẲN** (cùng
  task với `EutrDocumentsModal.jsx`, 2 file khác nhau xóa cùng lúc).
  `EutrDocumentsAdd.jsx` (chuỗi US2→Update 3→4→5→6→7→8→10→11 ở trên, file dài nhất lịch sử feature) →
  **Update 19**: T269 **XÓA HẲN** (cùng route `/eutr/documents/add` trong `MainRoutes.jsx`).
  `UpdateEutrDocumentPoStepUseCase.js` (tạo ở Update 12) → **Update 19**: ĐỔI TÊN →
  `UpdateEutrDocumentReferenceStepUseCase.js` (T265).
- **Update 22 (Phase 27) — tiếp nối các chuỗi file ở trên**:
  `EutrUpdateReferenceStepRequestDto.cs` (đổi tên ở Update 19, T242) → **Update 22**: T289 (+
  `RefValues`), tuần tự vì cùng file.
  `EutrReferencesRepository.cs`/`IEutrReferencesRepository.cs` (chuỗi Update 8→9→10→11→13→14→19→21 ở
  trên) → **Update 22**: T290 (+2 khai báo `DeleteByDocumentIdAndRefValuesAsync`/`AddReferencesAsync`)
  → T291 (implement), tuần tự vì cùng cặp file.
  `EutrDocumentsService.cs`/`IEutrDocumentsService.cs` (chuỗi Foundational→9→10→11→13→14→19 ở trên) →
  **Update 22**: T292 (mở rộng `UpdateReferenceStepAsync` — thêm tham số `refValues` + nhánh
  reconcile), tuần tự vì cùng file.
  `EutrDocumentsController.cs` (chuỗi Foundational→10→11→12→19 ở trên) → **Update 22**: T293 (truyền
  `dto.RefValues` vào action `{id}/step`), tuần tự vì cùng file — action không đổi route/policy.
  `eutrDocumentsApi.js`/`IEutrDocumentsRepository.js`/`RestEutrDocumentsRepository.js`/
  `UpdateEutrDocumentReferenceStepUseCase.js` (chuỗi tạo/đổi tên ở Foundational/Update 12/19 ở trên) →
  **Update 22**: T294/T295 (thêm tham số `refValues`, song song vì khác file) → T296 (truyền qua
  repository) → T297 (truyền qua use case), tuần tự sau T294/T295.
  `EutrDocumentsFormDialog.jsx` (chuỗi Update 15/16→17→18→19→20 ở trên, file đổi tên ở Update 19) →
  **Update 22**: T298 (`showEditableChips`, render `EutrAddValueAutocomplete`/`Chip.onDelete` có điều
  kiện, `canSubmit` + `handleSave` gửi `refValues`), tuần tự vì cùng file — sau Phase 25 (T279, dòng
  cuối cùng đã sửa file này).

### Parallel Opportunities

- Setup: T001, T002, T003 song song (file khác nhau).
- Foundational backend `[P]`: T004, T005, T006, T007 song song; frontend `[P]`: T013, T014, T015
  song song (T016 sau T013/T014; T017 sau T016).
- Use case `[P]` mỗi story: T023 (US1), T028 (US2), T032 (US3), T037 + T038 (US4) có thể làm song
  song với phần còn lại của story đó (không phụ thuộc file UI).
- Update 3 (Phase 9): T048 (hằng số demo, khác đoạn code) có thể làm song song với T047 (Select
  Type); T051 (rà soát text, không riêng file) có thể làm song song với T052 (kiểm thử) sau khi
  T049/T050 xong.
- Update 4 (Phase 10): T056 (enum `ObjectType`, file `ComplEnum.cs`) có thể làm song song với
  T053-T055 (file `ComplDynamicsService.cs`); T059 (kiểm thử) có thể làm song song với các task
  khác không đụng `EutrDocumentsAdd.jsx` sau khi T057/T058 xong.
- Update 5 (Phase 11): T062 (kiểm thử) có thể làm song song với các task khác không đụng
  `EutrDocumentsAdd.jsx` sau khi T060/T061 xong; không có backend task nào ở phase này.
- Update 6 (Phase 12): T063, T064, T065 (DTO/interface, file khác nhau) song song; T069, T070
  (appsettings 2 file khác nhau) song song với nhau và với mọi task backend khác; T071 (interface
  frontend) độc lập, có thể làm sớm; T077 (rà soát text) có thể làm song song với T078 (kiểm thử)
  sau khi T076 xong. Toàn bộ backend (T063-T070) có thể làm song song với Phase 5-11 (không đụng
  file chung nào).
- Update 7 (Phase 13): T079, T080, T081 (migration/DDL/entity, file khác nhau) song song; T088 (rà
  soát text) có thể làm song song với T089 (kiểm thử) sau khi T087 xong. Backend (T079-T083) có thể
  làm song song với Phase 5-12 (không đụng file chung nào) — chỉ T084/T085 phải chờ Phase 12
  (T066) hoàn tất vì sửa cùng `EutrUploadService.cs`.
- Update 8 (Phase 14): T090, T091, T092, T093, T094 (projection/request/response DTO, file khác
  nhau) song song; T104, T108, T109, T110 (component FE + use case + interface + api, file khác
  nhau) song song, có thể làm ngay từ đầu phase; T106→T107 (entity/repository FE) có thể làm song
  song với dòng T090-T103 (backend) vì không phụ thuộc nhau cho tới T112 (cần cả hai phía sẵn sàng);
  T114/T115 (rà soát text) có thể làm song song với T116/T117 (kiểm thử) sau khi T105/T113 xong.
  Toàn bộ backend (T090-T103) có thể làm song song với phần lớn frontend (T104, T106-T110) — chỉ
  T112/T113 cần chờ cả T108/T111 (frontend) lẫn T103 (backend, để endpoint hoạt động khi test).
- Update 9 (Phase 15): Không có task `[P]` — chỉ 3 file, mỗi file 1-2 task tuần tự (T118→T119,
  T120→T121); T122 (kiểm thử) làm sau cùng. Toàn bộ Phase 15 chỉ đụng
  `IEutrReferencesRepository.cs`/`EutrReferencesRepository.cs`/`EutrDocumentsService.cs` — độc lập
  hoàn toàn với Phase 3, 5, 7-13 (không đụng US1/US3/US5/Update 3-7); chỉ dùng chung file với Phase
  6 (US4, không sửa lại) và Phase 14 (Update 8, cùng `EutrDocumentsService.cs`/
  `EutrReferencesRepository.cs` nhưng khác method).
- Update 10 (Phase 16): T124, T125 (thêm field `FileId` vào 2 DTO khác file) song song; T129, T130
  (api/interface frontend, file khác nhau) song song; T132 (use case mới) độc lập, có thể làm sớm;
  T139 (rà soát text) có thể làm song song với T140/T141 (kiểm thử) sau khi T133/T138 xong. T123
  (endpoint backend) và T128 (tổng quát hoá `FilePreviewer.jsx`) **hoàn toàn độc lập** với nhau và
  với mọi phase khác — có thể làm song song với Phase 5-15 ngay từ đầu (không đụng file chung nào
  ngoài `EutrDocumentsController.cs`/`FilePreviewer.jsx`, cả hai chưa từng bị Update nào khác sửa
  cho mục đích tương tự).
- Update 11 (Phase 17): T142/T143/T144 (entity + 2 DTO, file khác nhau) song song; T149 (DTO upload
  manual), T153 (interface `IEutrReferencesRepository.cs`), T159 (DTO `EutrConditionRowDto`) đều
  **độc lập hoàn toàn** với nhau và với chuỗi T142-T148, có thể làm ngay từ đầu phase. T166/T167/
  T170/T171 (frontend, file khác nhau) song song, có thể làm sớm; T173/T174 (2 use case, file khác
  nhau) song song sau T172; T179 (rà soát text) có thể làm song song với T180 (kiểm thử) sau khi
  T178 xong. **T148 (sửa SQL cascade delete) nên làm SỚM NHẤT trong phase này** — độc lập, không
  chờ task nào, nhưng là điều kiện bắt buộc trước T163 (tránh vi phạm khóa ngoại khi có dữ liệu
  `eutr_reference_details` thật).
- Update 12 (Phase 18): T181/T182/T183 (3 DTO, file khác nhau) song song; T189/T190 (frontend,
  file khác nhau) song song; T192/T193/T194 (3 use case, file khác nhau) song song sau T191; T198
  (rà soát text) có thể làm song song với T199 (kiểm thử) sau khi T197 xong. Toàn bộ Phase 18 phụ
  thuộc Phase 17 (dùng lại `AssignConditionDialog.jsx`/`IEutrConditionAssignmentService`/
  `EutrConditionAssignmentService.cs`), độc lập với Phase 3-16 (không đụng US1/US2/US4/US5/
  Update 3-10).
- Update 13 (Phase 19): T200/T202 (2 DTO field, file khác nhau) song song; T204/T205 (2 validator,
  file khác nhau) song song, độc lập với chuỗi T200-T203; T207 (rà soát text) có thể làm song song
  với T208 (kiểm thử) sau khi T206 xong. Toàn bộ Phase 19 là các sửa nhỏ trên file đã có từ Phase
  14/17/18 — không thêm file mới nào ngoài việc sửa các file hiện có.
- Update 14 (Phase 20): T209 (migration mới) độc lập, có thể chạy song song với mọi task backend
  khác. T210/T212 (2 DTO field, file khác nhau) song song. T215 (kiểm thử) sau T214. Toàn bộ Phase 20
  là các sửa nhỏ trên file đã có từ Phase 14/19 (`EutrReferenceStepInfo.cs`,
  `EutrReferencesRepository.cs`, `EutrDocumentsResponseDto.cs`, `EutrDocumentsService.cs`,
  `useEutrDocumentsColumns.jsx`) + 1 migration mới — không thêm entity/repository/endpoint nào.
- Update 19 (Phase 24): T236/T238 (2 DTO field, file khác nhau) song song; T240/T242 (interface +
  đổi tên DTO, file khác nhau) song song, độc lập với T236-T239; T248/T249/T250/T251 (xóa file, 4
  nhóm độc lập với nhau) đều có thể làm song song ngay sau T245/T246/T247 tương ứng đã xong; T255/
  T256 (2 DTO field, file khác nhau) song song, độc lập hoàn toàn với T236-T254 (nhánh Valid from/to
  không phụ thuộc nhánh Conditions/step). T261/T263 (2 file frontend khác nhau) song song; T268/T269
  (xóa file, độc lập với nhau) song song ngay sau T267; T271 (xóa 5 use case, có thể tách thành 5
  task `[P]` con nếu nhiều người làm cùng lúc — mỗi file độc lập). T273/T274/T275 (3 kiểm thử theo
  story khác nhau) có thể làm song song nếu backend/frontend tương ứng của mỗi story đã xong. Toàn bộ
  Phase 24 phụ thuộc mọi phase trước (Foundational, Update 6-18) vì đây là bước **kết thúc/dọn dẹp**
  cuối cùng của các chuỗi file đã mở ra từ các phase đó (xem "Điểm chia sẻ file").
- Update 20 (Phase 25): **Không có task `[P]` nào** — chỉ 1 file (`EutrDocumentsFormDialog.jsx`), mọi
  task sửa tuần tự (T276→T277→T278/T279); T280/T281 (2 kiểm thử theo story khác nhau) có thể làm song
  song nếu T278/T279 đều đã xong. Toàn bộ Phase 25 phụ thuộc Phase 24 (T266, cùng file) — không có
  task nào phụ thuộc backend vì **0 thay đổi backend** ở Update 20 (research Quyết định 61).
- Update 22 (Phase 27): T289 (DTO field) và T290 (2 khai báo interface) song song (khác file); T294/
  T295 (api client + interface FE, file khác nhau) song song. Backend (T289-T293) hoàn toàn độc lập
  với Phase 25/26 (không đụng `EutrDocumentsFormDialog.jsx`/`EutrDocumentsFilterBar.jsx`), có thể làm
  song song với Phase 26 (Update 21, không đụng file chung nào). T298 (`EutrDocumentsFormDialog.jsx`)
  là task duy nhất phải chờ CẢ backend (T293, để endpoint hoạt động khi test) LẪN chuỗi frontend
  T294→T297 LẪN Phase 25 (T279, cùng file) — không thể làm song song với các task khác trong phase
  này. T299 (kiểm thử) sau cùng.

---

## Parallel Example: Foundational

```bash
# Backend DTO/entity/validator (khác file, không phụ thuộc):
Task: "T004 Entity EutrDocuments.cs"
Task: "T005 EutrDocumentsRequestDto.cs"
Task: "T006 EutrDocumentsResponseDto.cs"
Task: "T007 EutrDocumentsRequestDtoValidator.cs"

# Frontend domain/api (khác file):
Task: "T013 domain/entities/EutrDocuments.js"
Task: "T014 domain/interfaces/IEutrDocumentsRepository.js"
Task: "T015 infrastructure/api/eutrDocumentsApi.js"
```

---

## Implementation Strategy

### MVP First (US1)

1. Phase 1 Setup → 2. Phase 2 Foundational → 3. Phase 3 US1 → **STOP & VALIDATE** (xem danh sách) →
   demo.

### Incremental Delivery

Foundational → US1 (MVP: xem danh sách) → US2 (thêm mới, trang riêng) → US3 (sửa, popup) → US4
(xóa/xóa nhiều) → US5 (icon View placeholder) → Polish → **Update 3** (Type/List PO/Manual, chỉ
giao diện, có thể làm bất kỳ lúc nào sau US2) → **Update 4** (List PO nối API thật `refType 15/16`,
backend độc lập ngay từ đầu, frontend cần sau Update 3/Phase 9) → **Update 5** (ô tìm kiếm PO gọi
API, chỉ frontend, cần sau Update 4/Phase 10) → **Update 6** (nút Upload thật lên SharePoint ở
Screen1; backend hoàn toàn độc lập, có thể làm song song với bất kỳ phase nào; frontend cần sau
Update 4/Phase 10 để có cột `code` PO thật) → **Update 7** (thiết kế lại khu Upload theo hình +
validate prefix + ghi `eutr_references`; migration/entity/repository độc lập ngay từ đầu, phần sửa
`EutrUploadService.cs`/`EutrDocumentsAdd.jsx` cần sau Update 6/Phase 12 vì sửa cùng file) →
**Update 8** (nạp Step name/Type ở danh sách + File name/Step name ở List PO qua `eutr_references`
read-only; repository mới + DTO mới độc lập ngay từ đầu, phần sửa `EutrDocumentsService.cs`/
`EutrDocumentsController.cs`/`EutrDocumentsAdd.jsx` cần Foundational (Phase 2) và Update 6/Phase 12
(T074, cho `selectedPoId`) đã xong; không migration DB mới) → **Update 9** (Delete/DeleteMulti MUST
xóa kèm `eutr_references` liên quan qua `DocumentId`, mỗi document 1 transaction độc lập; chỉ backend
— thêm 1 method vào `IEutrReferencesRepository`/`EutrReferencesRepository` đã có từ Update 8, override
`DeleteAsync`/`DeleteMultiAsync` trong `EutrDocumentsService.cs`; không migration DB mới, không đổi
route/DTO/controller; cần Update 8/Phase 14 đã tồn tại vì cùng 2 file backend) → **Update 10** (icon
View mở popup xem file thật trên danh sách chính (US5) và trên bảng chi tiết List PO (US2); endpoint
mới `get-file-by-idref` clone `ComplCompliancesController.GetFileByIds`, tổng quát hoá
`FilePreviewer.jsx` bằng 2 prop tùy chọn; Delete từng file ở List PO dùng lại API xóa đơn hiện có
(không endpoint mới, không migration DB mới); cần Phase 7 (US5, icon View đã tồn tại), Phase 14
(Update 8, bảng chi tiết List PO đã tồn tại) và Phase 6 (US4, `DeleteEutrDocumentsUseCase` đã tồn
tại)) → **Update 11 / US6** (Screen2 "Upload manual" trở thành upload thật + popup Assign
condition tạo mới; entity/repository mới cho `eutr_reference_details` **đã tồn tại sẵn** trong DDL
— không migration mới; **quan trọng**: sửa SQL cascade delete (T148) trước khi ghi dữ liệu thật
(T163); cần Phase 16/Update 10 đã tồn tại vì cùng file `EutrDocumentsAdd.jsx`) → **Update 12**
(Edit rẽ nhánh theo Type — PO thêm trường Step, Upload manual mở lại `AssignConditionDialog` ở chế
độ sửa; cần Phase 17/Update 11 đã tồn tại vì tái dùng service/component) → **Update 13**
(`/speckit-clarify`: dropdown Step hiển thị đúng khi có nhiều Step, chặn trùng Conditions type; cần
Phase 17/18 đã tồn tại) → **Update 14** (cột Type trên danh sách lấy nhãn thật từ
`eutr_reference_types` thay vì hằng số `TAKE_FROM_OPTIONS`; mở rộng JOIN đã có từ Update 8/13 trong
`EutrReferencesRepository.cs`/`EutrDocumentsService.cs`, 1 migration mới seed 2 dòng cố định; không
entity/repository/endpoint mới; cần Phase 14/19 đã tồn tại vì sửa cùng các file backend/frontend) →
**Update 15/16 / US7** (nút Add mở popup "Add EUTR documents" thay cho điều hướng trang — Type lấy
toàn bộ `eutr_reference_types`, Step bắt buộc, Value hiển thị gợi ý PO/Vendor hoặc nhập tự do tùy
Type, chip giới hạn 1 cho Type="PO"/"Vendor", Upload tạo `eutr_documents`+N `eutr_references` theo
`RefType`=`Id` của Type đã chọn và thư mục SharePoint theo Type; method mới trên `EutrUploadService`
tái dùng `ResolveOrCreatePoFolderAsync` đã có, 1 endpoint mới trong `SharepointController`; không
migration DB mới, không entity/repository mới; `EutrDocumentsAdd.jsx`/route cũ giữ nguyên không xóa;
cần Phase 17 (T151/T152/T169, cùng file `EutrUploadService.cs`/`SharepointController.cs`/
`UploadToSharePointUseCase.js`) và Phase 18 (T197, cùng file `index.jsx`) đã tồn tại) →
**Update 17 / US7** (ô Value tự xóa trống sau khi thêm chip; Type = "PO" trong popup Add bỏ chọn Step
thủ công — gọi lại **nguyên vẹn** `executeEutrMulti`/`eutr-upload-multi` (Update 6/7) thay vì
`executeEutrMultiByType`; **KHÔNG có task backend nào** — chỉ sửa 2 file frontend đã tạo ở Phase 21
(`EutrAddValueAutocomplete.jsx`, `EutrDocumentsAddDialog.jsx`); cần Phase 21 (T223/T224) đã tồn tại) →
**Update 18 / US7** (popup Add gửi kèm `TypeId` khi Type = "PO" — đóng gap giữa ý định đã nêu ở FR-075
(Update 17) và luồng ghi thực tế đang dùng hằng số cố định `PoRefType`; thêm 1 field nullable `TypeId`
vào `EutrMultiUploadFileRequest` (Update 6) và 1 dòng ternary trong `EutrUploadService.
UploadMultipleToSharePointAndSaveDataAsync` để dùng `TypeId` nhận được làm `RefType` khi có, giữ
nguyên hằng số cũ khi không có (không phá vỡ trang Add cũ độc lập `EutrDocumentsAdd.jsx`); truyền
thêm `type.id` qua 3 file frontend hiện có (`RestSharePointRepository.js`,
`UploadToSharePointUseCase.js`, `EutrDocumentsAddDialog.jsx`); **không migration DB/entity/repository/
endpoint mới**; cần Phase 21/22 (T218, T221, T222, T224, T228 — cùng các file backend/frontend) đã
tồn tại) → **Update 19** (hợp nhất hoàn toàn Add/Edit vào một popup `EutrDocumentsFormDialog.jsx`
qua prop `mode`; popup Add thêm Valid from/Valid to editable; popup Edit khóa Type, chip chỉ đọc,
Step khả dụng cho MỌI Type kể cả PO — khác Add; Save chỉ `UPDATE StepId` tại chỗ cho mọi
`eutr_references` của document và/hoặc Valid from/to, không tạo/xóa bản ghi nào; cột Conditions đổi
sang `RefValue` phẳng distinct, bỏ hẳn `eutr_reference_details`; **xóa hoàn toàn** trang Add cũ, popup
Edit cũ, popup Assign condition, cùng 5 endpoint + `IEutrConditionAssignmentService` +
`EutrReferenceDetails` — đảo ngược có chủ đích quyết định "giữ dead code" của Update 15/16; không
migration DB mới; cần MỌI phase trước đã tồn tại vì đây là bước kết thúc/dọn dẹp các chuỗi file đã mở
từ Foundational đến Update 18) → **Update 20** (combobox Step trong `EutrDocumentsFormDialog.jsx`
lọc theo Assign Steps của Type đang chọn qua bảng `eutr_reference_type_details` — tái sử dụng nguyên
vẹn entity/repository/endpoint/policy đã xây dựng đầy đủ bởi feature `006-eutr-reference-types`
(`GetByTypeIdAsync`/`by-type/{typeId}`) và use case frontend đã có sẵn
(`GetByTypeIdEutrReferenceTypeDetailsUseCase`); mode Add mặc định chọn dòng đầu của danh sách lọc,
mode Edit đảm bảo Step hiện tại của document luôn hiển thị được dù đã bị gỡ khỏi Assign Steps; **0
thay đổi backend**, chỉ sửa đúng 1 file frontend hiện có; cần Phase 24 (T266) đã tồn tại vì cùng
file) → **Update 21 / US6** (search box Type/Step name/Conditions/Search phía trên bảng danh sách
  chính; không endpoint/DTO/entity/migration mới — 1 method mới trên `IEutrReferencesRepository`/
  `EutrReferencesRepository` (SQL 3 `EXISTS` độc lập) + mở rộng nội bộ
  `EutrDocumentsService.GetPagedAsync` để diễn giải 3 cột lọc ảo rồi tái dùng `Operator="in"` sẵn có;
  frontend 1 component mới nhỏ clone `ComplianceFilterBar.jsx` + wiring `handleSearch`/`searchFilters`
  clone `compliance-master/index.jsx`; cần Phase 14 (repository/service đã tồn tại) và Phase 24
  (`index.jsx`/`useEutrDocumentsData.js` đã tồn tại)) → **Update 22** (popup Edit cho phép thêm/xóa
  chip Value khi Type khác "PO" — mở rộng đúng `PUT {id}/step` (Phase 24) bằng 1 field nullable
  `refValues`; backend đối chiếu (diff) INSERT/DELETE theo `RefValue` rồi UPDATE `StepId` như cũ,
  không endpoint/entity/migration mới; frontend tái dùng nguyên vẹn `EutrAddValueAutocomplete.jsx`
  (Phase 21) trong mode Edit khi Type khác "PO", Vendor vẫn giới hạn 1 chip; cần Phase 24 (T244/T245)
  và Phase 25 (T279, cùng file `EutrDocumentsFormDialog.jsx`) đã tồn tại). Mỗi story test độc lập
  theo quickstart trước khi sang story kế.

### Lưu ý

- `[P]` = khác file, không phụ thuộc; các task cùng file phải làm tuần tự (xem "Điểm chia sẻ
  file").
- Không sinh test tự động (kiểm thử thủ công theo quickstart).
- Comment code **tiếng Việt**; văn bản UI **tiếng Anh** (Constitution IV + FR-015).
- T045, T046 là bước cấu hình DB/vận hành, không phải lập trình.
- Phase 9 (T047-T052) là phần bổ sung cho spec Session Update 3 — chỉ giao diện (Type + layout
  List PO/Manual), không thêm entity/DTO/API/migration nào; độc lập với Phase 5-8.
- Phase 10 (T053-T059) là phần bổ sung cho spec Session Update 4 — đăng ký `RSVNEutrPurchOrders`
  (`refType 15`) và `RSVNEutrSalesOrderPurchases` (`refType 16`) vào endpoint `POST
  /api/dynamics/reference` **đã có sẵn** (KHÔNG tạo endpoint/controller/route mới, KHÔNG tạo domain
  model mới — đã tồn tại sẵn trong repo); frontend chỉ đổi nguồn dữ liệu cột PO name trong List PO
  (Screen1) sang gọi hook `useReferenceObjects` có sẵn; độc lập với Phase 5-8, phụ thuộc Phase 9 ở
  phần frontend (T057-T058 cần Screen1 đã tồn tại).
- Phase 11 (T060-T062) là phần bổ sung cho spec Session Update 5 — đổi ô tìm kiếm PO từ lọc cục bộ
  sang gọi lại API tham chiếu (`refType = 15` kèm từ khóa, debounce 500ms bằng `lodash.debounce`
  có sẵn); **không có task backend nào** vì filter Code/Name generic đã hoạt động sẵn từ Phase 10
  (T053); chỉ sửa `EutrDocumentsAdd.jsx`, phụ thuộc Phase 10 đã hoàn tất (T057-T058), độc lập với
  Phase 5-8.
- Phase 12 (T063-T078) là phần bổ sung cho spec Session Update 6 — khu "Drag and drop files to
  upload" ở Screen1 trở thành nút Upload thật lên SharePoint. Backend **tạo mới** `EutrUploadService`
  (KHÔNG dùng lại `ComplUploadService`), endpoint mới `POST /api/sharepoint/eutr-upload-multi`
  trong `SharePointController.cs` hiện có, **không migration DB mới** (cột `FileId`/`Name`/
  `ValidFrom`/`ValidTo` đã có sẵn từ Phase 1/Update 3); PO chỉ dùng để suy ra thư mục SharePoint,
  KHÔNG thêm cột lưu PO vào `eutr_documents`. Frontend mở rộng `ISharePointRepository`/
  `RestSharePointRepository`/`UploadToSharePointUseCase` có sẵn (không tạo domain/infrastructure/
  application mới). Backend độc lập hoàn toàn với mọi phase khác; frontend phụ thuộc Phase 10
  (T057, cần cột `code` PO thật) nhưng độc lập với Phase 5-9/11.
- Phase 13 (T079-T089) là phần bổ sung cho spec Session Update 7 — thiết kế lại khu Upload theo
  hình `upload.png` (thêm kéo-thả file thật, giữ nguyên định dạng/kích thước 10MB của Update 6) và
  bổ sung validate prefix tên file theo `eutr_master_documents` (feature `002-eutr-masters`, chỉ
  đọc) trước khi cho upload. **Migration DB mới**: thêm cột `StepId` vào `eutr_references` (bảng
  trước đó chưa có entity backend nào) — KHÔNG đụng cột/FK `RefId` hiện có của bảng này. Entity mới
  `EutrReferences.cs` dùng thẳng `IRepository<,>` generic (không tạo repository riêng); tra cứu
  prefix mở rộng `IEutrMastersRepository` đã có sẵn (không tạo repository mới). Mỗi file khớp N
  `StepId` phân biệt ghi N dòng `eutr_references` cùng `DocumentId`, gộp chung 1 transaction với
  `eutr_documents` của file đó (rollback toàn bộ nếu bất kỳ bước nào lỗi — không để lại document mồ
  côi). Backend: migration/DDL/entity/repository (T079-T083) độc lập hoàn toàn; phần sửa
  `EutrUploadService.cs` (T084-T085) phụ thuộc Phase 12 (T066) đã xong. Frontend: sửa
  `EutrDocumentsAdd.jsx` (T086-T087) phụ thuộc Phase 12 (T076) đã xong; độc lập với Phase 5-11.
- Phase 14 (T090-T117) là phần bổ sung cho spec Session Update 8 — cột Step name/Type (danh sách,
  US1) và File name/Step name (List PO trên trang Add, US2) không còn luôn trống, nạp bằng cách
  **đọc** (read-only) bảng `eutr_references` đã có từ Update 7 (KHÔNG migration DB mới). Backend:
  repository mới `EutrReferencesRepository`/`IEutrReferencesRepository` (2 method JOIN, clone mẫu
  `EutrMastersRepository`) + 4 DTO mới (2 projection nội bộ, 1 request, 2 response cho endpoint mới
  `POST /api/eutr-documents/list-po-references`) + mở rộng `EutrDocumentsService.GetPagedAsync`
  (clone mẫu `ComplCountryGroupService.AttachMembersAsync`). Frontend: component dùng chung mới
  `MultiValueChips.jsx` (chip + "+N more" + tooltip, clone logic của cột "Country Codes" ở
  `useCountryGroupColumns.jsx`) dùng ở cả cột Step name (danh sách) và bảng chi tiết List PO; 1 use
  case mới tra cứu theo PO đang chọn (không tải trước cho toàn trang, xem research Quyết định 22).
  Cột Conditions không đổi (vẫn luôn trống). Backend/Frontend phần lớn độc lập với nhau và với
  Phase 5-11; chỉ phần sửa `EutrDocumentsAdd.jsx` (T112-T113) cần Phase 12 (T074) đã xong.
- Phase 15 (T118-T122) là phần bổ sung cho spec Session Update 9 — Delete (US4, đơn hoặc nhiều) MUST
  xóa kèm toàn bộ `eutr_references` có `DocumentId` tương ứng, cùng transaction với việc xóa
  `eutr_documents`; lỗi ở bước dọn `eutr_references` khiến document đó không bị xóa (rollback),
  nhưng KHÔNG chặn việc xóa các document khác trong cùng lượt xóa nhiều (khác hẳn
  `BaseService.DeleteMultiAsync` hiện tại — dùng 1 transaction chung cho cả batch). **Chỉ backend,
  không migration DB mới, không đổi route/DTO/controller**: thêm 1 method
  `DeleteByDocumentIdAsync` vào `IEutrReferencesRepository`/`EutrReferencesRepository` (đã tồn tại
  từ Phase 14), và override `DeleteAsync`/`DeleteMultiAsync` trực tiếp trong `EutrDocumentsService.cs`
  — KHÔNG sửa `IBaseService`/`BaseService`/`IEutrDocumentsService` (dùng chung cho mọi feature CRUD
  khác, research Quyết định 24). Độc lập với Phase 3, 5, 7-13 (không đụng US1/US3/US5/Update 3-7).
- Phase 16 (T123-T141) là phần bổ sung cho spec Session Update 10 — icon View trên danh sách chính
  (US5) và trên bảng chi tiết List PO (US2) không còn là placeholder/silent no-op — mở popup xem
  trước file thật qua endpoint mới `GET /api/eutr-documents/get-file-by-idref` (clone nguyên vẹn
  `ComplCompliancesController.GetFileByIds`, controller inject thẳng `ISharepointService`, cùng
  tiền lệ `SharePointController`). Frontend tổng quát hoá `FilePreviewer.jsx` (component dùng chung
  của `compliance-detail`) bằng 2 prop tùy chọn `fetchFile`/`onLoaded` — KHÔNG nhân bản logic render
  PDF/DOCX/XLSX/ảnh, không ảnh hưởng caller hiện có; component mới `EutrFileViewerDialog.jsx` (scoped
  riêng `eutr-documents`) bọc `FilePreviewer` + nút Download dựng Blob từ dữ liệu đã tải (không tái
  dùng luồng zip/progress-dialog của `DialogFilePreviewer.jsx`). Bảng chi tiết List PO (đã có sẵn
  cấu trúc "1 dòng = 1 document" từ Phase 14/Update 8) chỉ cần nạp thêm field `FileId` (không
  migration DB mới) và gắn hành vi thật cho 2 icon View/Delete đã có sẵn — Delete dùng lại nguyên
  vẹn API xóa đơn hiện có (`DELETE /api/eutr-documents/{id}`, đã dọn `eutr_references` từ Phase 15/
  Update 9), KHÔNG gọi API xóa file SharePoint nào. Độc lập với Phase 3-6, 9-13 (không đụng US1-US4/
  Update 3-7); phụ thuộc Phase 7 (US5), Phase 14 (Update 8) và Phase 15 (Update 9, gián tiếp qua
  hành vi Delete đã đúng sẵn).
- Phase 17 (T142-T180) là phần bổ sung cho spec Session Update 11 (User Story 6) — Screen2 "Upload
  manual" trở thành upload file thật (thư mục cố định `UploadManual`, KHÔNG validate prefix, KHÔNG
  ghi `eutr_references` ở bước upload) + bảng danh sách "chưa gán" (SQL `NOT EXISTS` tùy biến, vì
  repository generic không hỗ trợ JOIN/NOT EXISTS) + popup mới `AssignConditionDialog.jsx` (Step
  bắt buộc + ≥1 Conditions type/value bắt buộc — chặn Save nếu thiếu) ghi `eutr_references`
  (`RefType=1`) + `eutr_reference_details` (bảng **đã tồn tại sẵn** trong `eutr_db.sql`, không
  migration DB mới). **Phát hiện kỹ thuật quan trọng**: T148 sửa SQL `DeleteByDocumentIdAsync` để
  dọn kèm `eutr_reference_details` trước khi xóa `eutr_references` — bắt buộc phải hoàn tất trước
  T163 (lần đầu ghi dữ liệu thật vào bảng con), nếu không Delete document sẽ lỗi vi phạm khóa ngoại
  ngay khi có dữ liệu Assign condition thật. Backend service mới `IEutrConditionAssignmentService`
  clone mẫu `ComplMasterConditionPersistenceService.AddAsync` đã có sẵn trong hệ thống (compliance-
  master), KHÔNG mẫu `ComplMasterDuplicateConditionService` (bài toán khác). Frontend tái dùng
  nguyên vẹn `ReferenceObjectMultiAutocomplete.jsx`/`GetEutrStepsUseCase.js` đã có sẵn — không thêm
  dependency mới. Phụ thuộc Phase 16 (Update 10, cùng file `EutrDocumentsAdd.jsx`/
  `EutrDocumentsController.cs`), Phase 12 (Update 6, cùng file `EutrUploadService.cs`/
  `SharepointController.cs`), Phase 14 (Update 8, cùng file `EutrReferencesRepository.cs`/
  `EutrDocumentsService.cs`); độc lập với Phase 3-11, 13, 15 (không đụng US1-US4, Update 3-5/7/9).
- Phase 18 (T181-T199) là phần bổ sung cho spec Session Update 12 — Edit (User Story 3) rẽ nhánh
  theo `refType`: Type="PO" thêm trường Step (single-select) vào popup đơn giản hiện có, Save thay
  thế toàn bộ tập `eutr_references` cũ bằng 1 dòng mới (`PUT /eutr-documents/{id}/step`); Type=
  "Upload manual" mở lại **chính** `AssignConditionDialog.jsx` (Phase 17) ở chế độ sửa — cập nhật
  `StepId` trực tiếp (không tạo/xóa dòng `eutr_references`) và **replace toàn bộ**
  `eutr_reference_details` (xóa hết rồi ghi lại, không diff/merge — quyết định đã chốt ở clarify).
  Không migration DB mới. Phụ thuộc hoàn toàn vào Phase 17 (mở rộng cùng service/interface/component
  đã tạo ở đó — `IEutrConditionAssignmentService`, `EutrConditionAssignmentService.cs`,
  `AssignConditionDialog.jsx`); độc lập với Phase 3-16 (không đụng US1/US2/US4/US5, Update 3-10).
- Phase 19 (T200-T208) là phần bổ sung cho `/speckit-clarify` (spec Session Update 13) — 2 sửa nhỏ,
  không thêm file mới: (1) dropdown Step ở Edit (Type="PO") hiển thị đúng Step ứng với bản ghi
  `eutr_references` có `Id` **nhỏ nhất** khi document liên kết nhiều Step (deterministic, thêm field
  `ReferenceId`/`StepId` vào 2 DTO đã có); (2) popup Assign condition (cả 2 chế độ) KHÔNG cho phép 2
  dòng cùng Conditions type — dropdown tự disable type đã dùng (frontend, clone
  `ComplianceMasterForm.jsx`) + validator backend chặn trùng lặp bằng `Distinct().Count()` đơn giản
  (KHÔNG clone `ComplMasterDuplicateConditionService`'s full-table scan — bài toán khác). Phụ thuộc
  Phase 17 (T158, T161, T175) và Phase 18 (T184, T195); độc lập với Phase 3-16.
- Phase 20 (T209-T215) là phần bổ sung cho spec Session Update 14 — cột **Type** trên danh sách EUTR
  documents chính (User Story 1) đổi nguồn nhãn hiển thị: JOIN thật `eutr_references.RefType` với
  `eutr_reference_types.Id` (bảng CRUD bởi feature `006-eutr-reference-types`), trả `Name`, thay cho
  nhãn hằng số front-end `TAKE_FROM_OPTIONS` (vốn có `value` `1..5`, không khớp `RefType` thật `0`/`1`
  — xem research Quyết định 41 để biết chi tiết lỗi nền mà Update 14 sửa). Không entity/repository/
  endpoint mới — chỉ mở rộng câu SQL đã có từ Update 8 (`GetStepInfoByDocumentIdsAsync`) và 1
  migration mới seed 2 dòng cố định `Id=0`→"PO"/`Id=1`→"Upload manual" (cần bật tạm
  `NO_AUTO_VALUE_ON_ZERO` để giữ đúng `Id=0`). Dropdown Type ở trang Add (FR-016) và rẽ nhánh Edit
  theo `refType` (FR-055/FR-056, Phase 18) KHÔNG đổi. Phụ thuộc Phase 14 (T090, T096, T099, T158) và
  Phase 19 (T200, T201, T202, T203 — cùng file, cùng method); độc lập với Phase 3-13, 15-18 (không
  đụng US2-US6).
- Phase 21 (T216-T226) là phần bổ sung cho spec Session Update 15/16 (User Story 7 mới trong spec) —
  nút **Add** trên toolbar KHÔNG còn điều hướng sang trang riêng `/eutr/documents/add` mà mở một
  **popup** "Add EUTR documents": **Type** lấy TOÀN BỘ bản ghi `eutr_reference_types` (khác dropdown
  Type cũ ở FR-016, vẫn giữ nguyên 2 lựa chọn hard-coded cho `EutrDocumentsAdd.jsx`); **Step** bắt
  buộc; **Value** hiển thị gợi ý PO (`refType=15`) khi `Type.Name` khớp "PO"/"Invoice"/"Delivery
  note", gợi ý Vendor (`refType=14`) khi khớp "Vendor", nhập tự do cho Type khác — hỗ trợ chọn từ gợi
  ý/gõ tay/dán nhiều giá trị (tách dấu phẩy/xuống dòng) thành chip, giới hạn đúng 1 chip cho Type=
  "PO"/"Vendor"; **Upload** (khả dụng khi đủ Type+Step+≥1 chip) gọi endpoint mới
  `eutr-upload-multi-by-type`, ghi 1 `eutr_documents` + N `eutr_references` (N=số chip, `RefType`=
  `Id` của Type đã chọn — không còn giới hạn `0`/`1`) mỗi file, thư mục SharePoint suy theo `Name`
  của Type (tái dùng `ResolveOrCreatePoFolderAsync` đã có); popup **tự đóng** sau Upload. Không
  migration DB mới, không entity/repository mới. `EutrDocumentsAdd.jsx`/route `/eutr/documents/add`
  và luồng Edit (Phase 18/19) **giữ nguyên, không đổi** — quyết định có chủ đích, xem research Quyết
  định 45. Phụ thuộc Phase 17 (T150-T152, T167-T169 — cùng file `IEutrUploadService.cs`/
  `EutrUploadService.cs`/`SharepointController.cs`/`ISharePointRepository.js`/
  `RestSharePointRepository.js`/`UploadToSharePointUseCase.js`) và Phase 18 (T197 — cùng file
  `index.jsx`); độc lập với Phase 3-16, 19-20 (không đụng US1/US3-US6, Update 5/13/14).
- Phase 22 (T227-T229) là phần bổ sung cho spec Session Update 17 (vẫn thuộc User Story 7) — hai tinh
  chỉnh trên popup Add (Phase 21): (1) ô **Value** trở về trống ngay sau khi thêm 1 chip (làm rõ tường
  minh, xem research Quyết định 50); (2) khi Type đã chọn có `Name` = "PO", popup **ẩn hẳn** combobox
  **Step** và **KHÔNG bắt buộc** chọn Step — nút Upload chỉ cần Type + ≥1 chip, và khi nhấn Upload gọi
  lại **nguyên vẹn** use case đã có từ Update 6 (`executeEutrMulti` → `POST
  /api/sharepoint/eutr-upload-multi`) thay vì `executeEutrMultiByType` (Phase 21) — vì endpoint PO gốc
  đã tự validate prefix `eutr_master_documents` và tự ghi `eutr_references` theo từng `StepId` khớp
  Prefix (Update 6/7, xem research Quyết định 51). **KHÔNG có task backend nào** trong phase này — 0
  entity/repository/DTO/endpoint/migration mới, chỉ sửa 2 file frontend đã tạo ở Phase 21
  (`EutrAddValueAutocomplete.jsx`, `EutrDocumentsAddDialog.jsx`). Với Type khác "PO", toàn bộ hành vi
  Phase 21 giữ nguyên không đổi. Phụ thuộc Phase 21 (T223, T224 — cùng file) và gián tiếp Phase 12
  (T073, cần `executeEutrMulti` đã tồn tại trên `UploadToSharePointUseCase.js`); độc lập với Phase
  3-20 (không đụng US1-US6, Update 3-14).
- Phase 23 (T230-T235) là phần bổ sung cho spec Session Update 18 (vẫn thuộc User Story 7) — đóng
  khoảng trống giữa ý định đã nêu ở FR-075 (Update 17: `RefType` phải là `Id` thật của bản ghi
  `eutr_reference_types` có `Name` = "PO") và luồng ghi thực tế hiện tại, vốn ghi cứng hằng số
  `EutrUploadService.PoRefType = 0` bất kể `Id` thật của "PO" là bao nhiêu (giả định "PO luôn có
  Id = 0" chỉ đúng nhờ seed cưỡng bức ở Update 14 — research Quyết định 41 — và không còn đảm bảo từ
  khi feature `006-eutr-reference-types` cho phép CRUD tự do trên bảng đó). Backend: thêm field
  nullable `TypeId` vào `EutrMultiUploadFileRequest` (KHÔNG `[Required]`, để không phá vỡ trang Add
  cũ độc lập `EutrDocumentsAdd.jsx` — vốn không có control Type nên không gửi field này); đổi dòng
  gán `RefType` trong `EutrUploadService.UploadMultipleToSharePointAndSaveDataAsync` thành ternary
  theo `request.TypeId` (research Quyết định 52). Frontend: truyền thêm `type.id` qua 3 file hiện có
  (`RestSharePointRepository.js`, `UploadToSharePointUseCase.js`, `EutrDocumentsAddDialog.jsx` — nhánh
  `isPoType` từ Update 17). **KHÔNG migration DB/entity/repository/endpoint mới** — chỉ 1 field DTO
  nullable + 1 dòng gán giá trị + truyền thêm 1 tham số. Phụ thuộc Phase 21 (T218, T221, T222, T224)
  và Phase 22 (T228 — cùng file `EutrDocumentsAddDialog.jsx`); độc lập với Phase 3-20 (không đụng
  US1-US6, Update 3-14).
- Phase 24 (T236-T275) là phần bổ sung cho spec Session Update 19 (User Story 1/2/3 trong spec hiện
  tại — spec.md đã được viết lại hoàn toàn ở Update 19, chỉ còn 5 user story: US1 Xem danh sách, US2
  Thêm mới qua popup, US3 Sửa qua cùng popup, US4 Xóa, US5 Xem file) — **thay đổi phạm vi lớn nhất kể
  từ khi feature được tạo**, đảo ngược có chủ đích quyết định "giữ dead code" của Phase 21 (research
  Quyết định 45/53). Add VÀ Edit (US2/US3) hợp nhất vào **đúng 1** popup
  `EutrDocumentsFormDialog.jsx` (đổi tên từ `EutrDocumentsAddDialog.jsx`) qua prop `mode`; popup Add
  thêm Valid from/Valid to editable (mặc định hôm nay/`9999-12-31`, validate `validFrom ≤ validTo`);
  popup Edit khóa Type, chip chỉ đọc, Step khả dụng cho MỌI Type kể cả PO (khác quy tắc ẩn Step của
  Add — research Quyết định 60), Save chỉ `UPDATE StepId` tại chỗ cho mọi `eutr_references` của
  document (giữ nguyên `RefValue`/`RefType`/số lượng, KHÔNG xóa/tạo lại — khác hẳn cơ chế
  xóa-tạo-lại của Phase 18) và/hoặc Valid from/to. Cột **Conditions** (US1) đổi nguồn hoàn toàn từ
  nhóm `eutr_reference_details` theo `ConditionType` (Phase 17) sang **flat, distinct `RefValue`**
  của `eutr_references` — mở rộng SQL đã có từ Phase 14/20 (`GetStepInfoByDocumentIdsAsync`), áp dụng
  cho **mọi** Type (không còn phân biệt PO/Upload manual/khác). **Xóa hoàn toàn** (không giữ dead
  code): trang Add cũ + route `/eutr/documents/add` (Phase 4/9-11/13-14/16-17, "file dài nhất lịch sử
  feature"), `EutrDocumentsModal.jsx` (Phase 5/18), `AssignConditionDialog.jsx` (Phase 17/18/19),
  service `IEutrConditionAssignmentService` (Phase 17/18), entity/repository `EutrReferenceDetails`
  (Phase 17), 5 endpoint (`get-unassigned`/`assign-conditions`/`condition-assignment` GET+PUT/
  `list-po-references`) + `eutr-upload-manual-multi` (Phase 17), cùng mọi DTO/use case chỉ phục vụ
  các luồng đó. **Ngoại lệ giữ nguyên**: SQL 2 bước của `DeleteByDocumentIdAsync` (Phase 17, T148) —
  dữ liệu lịch sử trong `eutr_reference_details` (bảng KHÔNG bị xóa/migrate) vẫn có thể vi phạm khóa
  ngoại nếu bỏ bước dọn đó (research Quyết định 58). **Không migration DB mới** — mọi cột cần
  (`RefValue`, `StepId`, `RefType`, `ValidFrom`/`ValidTo`) đã tồn tại từ Phase 13/20. Phụ thuộc **mọi**
  phase trước (Foundational, Phase 3-23) vì đây là bước kết thúc/dọn dẹp cuối cùng của hầu hết các
  chuỗi file đã mở từ đầu dự án — không thể làm song song với bất kỳ phase nào khác, phải làm **sau
  cùng**.
- Phase 25 (T276-T281) là phần bổ sung cho spec Session Update 20 (User Story 2/3) — combobox **Step**
  trong `EutrDocumentsFormDialog.jsx` (cả mode Add và Edit, Type khác "PO") không còn nạp toàn bộ
  `eutr_steps` mà lọc theo bảng `eutr_reference_type_details` (tính năng **Assign Steps**, feature
  `006-eutr-reference-types`) — chỉ Step có bản ghi `TypeId` khớp Type đang chọn mới hiển thị. Mode Add
  mặc định chọn sẵn dòng đầu tiên của danh sách đã lọc; mode Edit đảm bảo Step hiện tại của document
  luôn hiển thị được (chèn thêm vào đầu danh sách nếu đã bị gỡ khỏi Assign Steps) — không tự động thay
  bằng Step khác. **Không có task backend nào** — toàn bộ hạ tầng đọc (entity `EutrReferenceTypeDetails`,
  repository `EutrReferenceTypeDetailsRepository.GetByTypeIdAsync`, endpoint
  `GET /api/eutr-reference-type-details/by-type/{typeId}`, policy `EutrReferenceTypes.ReadOne`) đã
  được xây dựng đầy đủ bởi feature `006-eutr-reference-types`; frontend cũng đã có sẵn use case
  `GetByTypeIdEutrReferenceTypeDetailsUseCase`/`repositories.eutrReferenceTypeDetails` — Phase 25 chỉ
  wiring lại use case này vào đúng 1 file hiện có (research Quyết định 61). Phụ thuộc Phase 24 (T266,
  cùng file `EutrDocumentsFormDialog.jsx`) — độc lập với mọi phase khác.
- Phase 26 (T282-T288) là phần bổ sung cho spec Session Update 21 (User Story 6 mới trong spec) — thêm
  search box (Type/Step name/Conditions/Search) phía trên bảng danh sách chính. **Không endpoint/DTO/
  entity/migration mới** — chỉ 1 method mới trên `IEutrReferencesRepository`/`EutrReferencesRepository`
  (đã tồn tại từ Phase 14) và mở rộng nội bộ `EutrDocumentsService.GetPagedAsync` (đã tồn tại từ Phase
  3, mở rộng thêm ở Phase 14/15) để diễn giải 3 "cột lọc ảo" `TypeId`/`StepId`/`Conditions` rồi tái
  dùng `Operator="in"` sẵn có của repository generic (research Quyết định 62/63). Frontend: 1 component
  mới nhỏ `EutrDocumentsFilterBar.jsx` (clone `ComplianceFilterBar.jsx`) + sửa `useEutrDocumentsData.js`
  (thêm tham số `defaultFilters`, mẫu `useComplianceMasterData`) + sửa `index.jsx` (thêm state search +
  `handleSearch`, mẫu `compliance-master/index.jsx`, research Quyết định 64) — tái dùng
  `getEutrReferenceTypesUseCase`/`getEutrStepsUseCase` đã có sẵn từ Phase 21, không use case/API mới.
  Phụ thuộc Phase 14 (T090-T096, cùng file `IEutrReferencesRepository.cs`/
  `EutrReferencesRepository.cs`/`EutrDocumentsService.cs`) và Phase 24 (T236 trở đi, cùng file
  `index.jsx`/`useEutrDocumentsData.js`); độc lập với Phase 3-13, 16-23, 25 (không đụng US1-US5/US7,
  Update 3-18/20).
- Phase 27 (T289-T299) là phần bổ sung cho spec Session Update 22 (User Story 3) — popup Edit
  (`EutrDocumentsFormDialog.jsx`) không còn khóa chip Value ở dạng chỉ đọc cho **mọi** Type — chỉ Type
  = "PO" giữ hành vi cũ; Type khác "PO" (kể cả "Vendor", vẫn giới hạn 1 chip theo FR-013) hiển thị lại
  ô Value + nút xóa (tái dùng nguyên vẹn `EutrAddValueAutocomplete.jsx`, Phase 21 — không sửa bên
  trong component này). **Không endpoint/entity/migration mới** — mở rộng đúng 1 DTO
  (`EutrUpdateReferenceStepRequestDto` + field `RefValues`) và 1 method service
  (`UpdateReferenceStepAsync`, Phase 24) với nhánh đối chiếu (diff `Except` 2 chiều dựa trên
  `GetStepInfoByDocumentIdsAsync` đã có từ Phase 14, không thêm method đọc mới) + 2 method ghi mới
  trên `IEutrReferencesRepository`/`EutrReferencesRepository` (Phase 14). Cân nhắc và loại bỏ cách
  "xóa toàn bộ rồi tạo lại toàn bộ" (mẫu `ComplMasterConditionPersistenceService.ReplaceAsync`, Phase
  17) vì làm mất `Id`/audit gốc của chip không đổi — xem research Quyết định 65-67. Phụ thuộc Phase 24
  (T244, T245 — cùng `EutrDocumentsService.cs`/`EutrDocumentsController.cs`/
  `EutrUpdateReferenceStepRequestDto.cs`) và Phase 25 (T279, cùng file
  `EutrDocumentsFormDialog.jsx`); độc lập với Phase 3-23, 26 (không đụng US1/US2/US4-US6, Update
  3-18/21).
