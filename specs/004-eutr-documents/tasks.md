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
  `refType`, sau T136).
- `EutrDocumentsActionCell.jsx`: T034 (US3: Edit/Delete) → T040 (US5: thêm icon View) →
  **Update 10 (Phase 16)**: T134 (đổi icon View từ silent no-op sang control thật, sau T040).
- `useEutrDocumentsColumns.jsx`: T025 (US1: khai báo cột) → T105 (Update 8: renderCell Step
  name/Type) → **Update 10 (Phase 16)**: T135 (thêm prop `onView`, sau T105 và sau T134) →
  **Update 11 (Phase 17)**: T176 (renderCell cột Conditions, sau T135).
- `EutrDocumentsService.cs`: tạo ở T010 (Foundational) — không override ở US1-US5/Update 3-8 (khác
  `eutr-masters` phải override `AddAsync`/`UpdateAsync` để chống trùng); **Update 9 (Phase 15)**:
  T120 (override `DeleteAsync` + field `_unitOfWork`) → T121 (override `DeleteMultiAsync`), tuần tự
  vì cùng file, sau T119; **Update 10 (Phase 16)**: T127 (gán thêm `FileId` trong
  `GetPoReferencesAsync`), sau T121 (khác đoạn code với Update 9, không phụ thuộc logic) →
  **Update 11 (Phase 17)**: T156 (implement `GetUnassignedPagedAsync`) → T158 (đổi tên
  `AttachStepInfoAsync`→`AttachStepAndConditionInfoAsync`, gán thêm `Conditions`), tuần tự vì cùng
  file, sau T127 → **Update 13 (Phase 19)**: T203 (gán thêm `StepId` theo `ReferenceId` nhỏ nhất
  trong cùng method đã đổi tên ở T158), sau T158.
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
- `EutrReferencesRepository.cs` (Update 8 → 9 → 10 → 11 → 13, file tạo ở Update 8): T096 (tạo file +
  method 1) → T097 (thêm method 2, Update 8) → T119 (thêm method 3 `DeleteByDocumentIdAsync`,
  Update 9) → T126 (thêm `FileId` vào `SELECT` của method 2, Update 10) → **Update 11 (Phase 17)**:
  T148 (sửa SQL `DeleteByDocumentIdAsync` — dọn `eutr_reference_details` trước, **BẮT BUỘC** trước
  T163) → T154 (thêm method 4 `GetUnassignedDocumentsPagedAsync`) → **Update 13 (Phase 19)**: T201
  (thêm `ReferenceId` vào `SELECT` của method 1) — toàn bộ tuần tự vì cùng file, độc lập hoàn toàn
  với `EutrUploadService.cs` (Update 6/7/11, chỉ ghi qua `IRepository<EutrReferences,long>` generic,
  không dùng repository này).
- `IEutrReferencesRepository.cs` (Update 8 → 9 → 11): T095 (tạo, 2 method đọc) → T118 (thêm method
  `DeleteByDocumentIdAsync`, Update 9) → **Update 11 (Phase 17)**: T153 (thêm method
  `GetUnassignedDocumentsPagedAsync`), tuần tự vì cùng file. Update 10/13 không sửa file này (chỉ
  đổi field trên DTO/SQL, không thêm method mới).
- `ComplDynamicsService.cs` (Update 4): T053 (EntityMappings) → T054 (case 15) → T055 (case 16),
  tuần tự vì cùng file (không đụng gì của Phase 1-9).
- `SharePointController.cs` (Update 6 → 11): T067 (action `eutr-upload-multi`, sau T066) →
  **Update 11 (Phase 17)**: T152 (thêm action `eutr-upload-manual-multi`), sau T067 — không đụng
  các action hiện có. Update 7/10/12/13 KHÔNG sửa file này.
- `EutrUploadService.cs` (Update 6 → 7 → 11): T066 (tạo mới, Update 6) → T084 → T085 (mở rộng
  validate prefix + ghi `eutr_references`, Update 7, tuần tự vì cùng file, sau T066) →
  **Update 11 (Phase 17)**: T151 (thêm method `UploadManualMultipleToSharePointAndSaveDataAsync`),
  sau T085 — khác method, không phụ thuộc logic. Update 10/12/13 không sửa file này.
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
- `EutrDocumentsModal.jsx` (Update 3 → 12, file tạo ở Phase 5): T033 (tạo, File name/Valid from/
  Valid to) → **Update 12 (Phase 18)**: T196 (thêm trường Step có điều kiện khi Type="PO"), tuần tự
  vì cùng file — độc lập với Phase 9-17 (không phần nào khác sửa lại file này).
- `EutrDocumentsResponseDto.cs` (Update 8 → 11 → 13): T099 (tạo, `StepNames`/`RefType`, Update 8) →
  **Update 11 (Phase 17)**: T157 (thêm `Conditions`) → **Update 13 (Phase 19)**: T202 (thêm
  `StepId`), tuần tự vì cùng file.
- `ComplianceSys.Application/DependencyInjection.cs` (Update 11 → 12): T164 (đăng ký
  `IEutrConditionAssignmentService` + validator `EutrAssignConditionsRequestDtoValidator`) →
  **Update 12 (Phase 18)**: T188 (đăng ký thêm validator
  `EutrUpdateConditionAssignmentRequestDtoValidator`), tuần tự vì cùng file — độc lập với các dòng
  đăng ký DI khác đã có từ Phase 2/12 (Foundational/Update 6, khác đoạn code).

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
Phase 17/18 đã tồn tại). Mỗi story test độc lập theo quickstart trước khi sang story kế.

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
