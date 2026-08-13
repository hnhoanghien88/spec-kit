# Tasks: EUTR Steps Management

**Feature**: `001-eutr-steps` | **Plan**: [plan.md](./plan.md) | **Spec**: [spec.md](./spec.md)

**Phạm vi**: Frontend-only (`compliance-client`) cho CRUD gốc — Backend đã tồn tại → chỉ verify.
**Mẫu tham chiếu**: feature `document-type` (clone qua mọi tầng, đổi tên `eutr-step`/`EutrStep`/`eutr-steps`).

> **Cập nhật (2026-08-11, FR-005a — chống trùng Step name)**: Phase 8 dưới đây bổ sung một
> **backend gap đã xác minh** (chưa có kiểm tra trùng tên) + sửa frontend, xem
> [plan.md](./plan.md) mục "Cập nhật (2026-08-11, theo spec FR-005a)" và
> [research.md](./research.md) Quyết định 6. Mẫu tham chiếu cho phần backend: `EutrMastersService`
> + `IEutrMastersRepository.ExistsStepPrefixAsync`.

Quy ước: `[P]` = có thể chạy song song (khác file, không phụ thuộc task chưa xong).
Đường dẫn gốc frontend: `compliance-client/src/`.

> **Lưu ý ngôn ngữ (FR-011)**: Comment trong code giữ tiếng Việt, nhưng **toàn bộ văn bản hiển thị
> cho người dùng (label cột, nút, breadcrumb, ô Search, thông báo lỗi/thành công, trạng thái rỗng,
> hộp thoại xác nhận) phải bằng tiếng Anh**. Không có cột/chức năng Prefix.

---

## Phase 1: Setup & Verify

- [X] T001 Verify backend hợp đồng `api/eutr-steps` khớp [contracts/eutr-steps-api.md](./contracts/eutr-steps-api.md): mở `compliance-sys-api/src/ComplianceSys.Api/Controllers/EutrStepsController.cs` xác nhận 7 endpoint + policy `EutrSteps.*`. KHÔNG sửa backend.
- [X] T002 [P] Đọc lại mẫu `document-type` để nắm convention: `compliance-client/src/presentation/pages/document-type/` + `application/usecases/document-type/` + `infrastructure/{api,repositories}` + `domain/{entities,interfaces}`.
- [X] T003 Xác nhận menu có (hoặc cần thêm) mục code `eutr-steps` và quyền tương ứng cho user test.

---

## Phase 2: Foundational (tầng dữ liệu dùng chung — BLOCKING cho mọi user story)

- [X] T004 [P] Tạo domain entity `domain/entities/EutrStep.js` — class `EutrStep` với `{ id, name, createdBy, createdDate, updatedBy, updatedDate }` (constructor nhận object).
- [X] T005 [P] Tạo interface `domain/interfaces/IEutrStepRepository.js` — các method: `getAll`, `getAllPaging`, `getById`, `create`, `update`, `delete`, `deleteMulti` (throw 'Not implemented').
- [X] T006 [P] Tạo `infrastructure/api/eutrStepApi.js` — base `/eutr-steps`; map đúng path: `getById` → `GET /eutr-steps/get-by-id/{id}`, `getAllPaging` → `POST /eutr-steps/get-all` (query page/pageSize/sortColumn/sortOrder + body filters), `create` POST, `update` PUT `/{id}`, `delete` DELETE `/{id}`, `deleteMulti` POST `/delete-multi`.
- [X] T007 Tạo `infrastructure/repositories/RestEutrStepRepository.js` — extends `IEutrStepRepository`, gọi `eutrStepApi` (phụ thuộc T005, T006).
- [X] T008 Đăng ký DI trong `di/repositories.js` — import `RestEutrStepRepository` và thêm `eutrStep: new RestEutrStepRepository()` (phụ thuộc T007).
- [X] T009 [P] Tạo 6 use case trong `application/usecases/eutr-step/`: `CreateEutrStepUseCase.js`, `UpdateEutrStepUseCase.js`, `DeleteEutrStepUseCase.js`, `DeleteMultiEutrStepUseCase.js`, `GetEutrStepsUseCase.js`, `GetPagingEutrStepsUseCase.js` (mỗi class nhận repo qua constructor, `execute(...)` gọi method tương ứng) (phụ thuộc T005).

**Checkpoint**: Tầng domain/infrastructure/application sẵn sàng; UI có thể build trên đó.

---

## Phase 3: User Story 1 — Xem & tìm kiếm danh sách (P1) 🎯 MVP

**Mục tiêu**: Bảng EUTR Steps tải dữ liệu, tìm kiếm theo tên, phân trang server-side; màn hình truy cập được.
**Independent test**: Mở `/eutr-steps`, thấy bảng đúng cột (không có Prefix), lọc theo Name, đổi trang; mọi văn bản UI bằng tiếng Anh.

- [X] T010 [P] [US1] Tạo hook dữ liệu `presentation/pages/eutr-steps/hooks/useEutrStepData.js` — clone `useDocumentTypeData`, dùng `repositories.eutrStep` + `GetPagingEutrStepsUseCase`, đọc `response.data.items/totalCount`, sort mặc định `id asc` (phụ thuộc T008, T009).
- [X] T011 [P] [US1] Tạo `presentation/pages/eutr-steps/hooks/useEutrStepColumns.jsx` — cột `name` (header "Step name"), `createdBy` (header "Created by"), `createdDate` (header "Created date", `formatDateTime`), cột `actions` (header "Action"); **không tạo cột prefix**; default visibility ẩn `id/updated*`.
- [X] T012 [US1] Tạo trang `presentation/pages/eutr-steps/index.jsx` — clone `document-type/index.jsx`: DataGrid server mode, tiêu đề + breadcrumb "EUTR > Steps", ô tìm kiếm ("Search"), phân trang, trạng thái rỗng "No data"; toàn bộ label/tiêu đề bằng tiếng Anh; lấy `permissionList` từ menu code `eutr-steps` (phụ thuộc T010, T011).
- [X] T013 [US1] Thêm route: trong `app/routes/RouteResolver.jsx` thêm `const EutrStepsPage = Loadable(lazy(() => import("@presentation/pages/eutr-steps")))` và `componentMap["eutr-steps"]: <EutrStepsPage />`.
- [X] T014 [US1] Thêm menu item trong `presentation/menu-items/ComplianceSystem.jsx` — code `eutr-steps`, title "EUTR steps", url `/eutr-steps`, breadcrumbs true.

**Checkpoint**: US1 chạy độc lập — đã có MVP xem + tìm kiếm + phân trang, UI tiếng Anh.

---

## Phase 4: User Story 2 — Thêm bước mới (P1)

**Mục tiêu**: Nút Add mở modal nhập tên, lưu tạo bước mới.
**Independent test**: Add → nhập tên hợp lệ → lưu → dòng mới xuất hiện; tên trống → bị chặn với thông báo lỗi tiếng Anh.

- [X] T015 [P] [US2] Tạo `presentation/pages/eutr-steps/components/EutrStepModal.jsx` — clone `DocumentTypeModal` nhưng CHỈ field `name` (label "Step name"); chặn submit khi `name` trống, hiển thị lỗi tiếng Anh (ví dụ "Step name is required"); tiêu đề modal "Add step"/"Edit step", nút "Save"/"Cancel".
- [X] T016 [US2] Nối Create vào `index.jsx`: nút "Add" mở modal, `onSubmit` gọi `CreateEutrStepUseCase` khi không có `modalData`, hiển thị snackbar thành công tiếng Anh (ví dụ "Step created successfully"), `fetchData()` (phụ thuộc T012, T015).

**Checkpoint**: Tạo mới hoạt động end-to-end.

---

## Phase 5: User Story 3 — Sửa bước (P2)

**Mục tiêu**: Edit một dòng, cập nhật tên.
**Independent test**: Chọn dòng → Edit → đổi tên → lưu → bảng cập nhật; thông báo tiếng Anh.

- [X] T017 [US3] Nối Edit vào `index.jsx`: nút "Edit"/chọn 1 dòng mở modal với `modalData`, `onSubmit` gọi `UpdateEutrStepUseCase` khi có `modalData` (gửi kèm `id`), snackbar thành công tiếng Anh (ví dụ "Step updated successfully") (phụ thuộc T016).

**Checkpoint**: Sửa hoạt động; tái dùng cùng modal với US2.

---

## Phase 6: User Story 4 — Xóa & xóa nhiều (P2)

**Mục tiêu**: Xóa 1 dòng (có xác nhận) và xóa nhiều dòng đã chọn.
**Independent test**: Delete 1 dòng → xác nhận → biến mất; chọn nhiều → xóa nhiều → biến mất; Cancel → không xóa; mọi văn bản tiếng Anh.

- [X] T018 [P] [US4] Tạo `presentation/pages/eutr-steps/components/EutrStepActionCell.jsx` — clone `DocumentTypeActionCell` (nút Edit/Delete theo quyền), tooltip/label tiếng Anh.
- [X] T019 [US4] Nối Delete + DeleteMulti vào `index.jsx`: `ConfirmDialog` cho xóa đơn (gọi `DeleteEutrStepUseCase`) và xóa nhiều theo `selectionModel` (gọi `DeleteMultiEutrStepUseCase`); nội dung xác nhận + nút ("Delete"/"Cancel") + snackbar bằng tiếng Anh (ví dụ "Are you sure you want to delete this step?") (phụ thuộc T012, T018; T011 dùng ActionCell).

**Checkpoint**: Toàn bộ CRUD hoàn chỉnh.

---

## Phase 7: Polish & Cross-cutting

- [X] T020 [P] Rà soát: **toàn bộ văn bản hiển thị cho người dùng bằng tiếng Anh** (label cột, nút, breadcrumb, Search, thông báo, trạng thái rỗng, hộp thoại xác nhận) — không còn chuỗi tiếng Việt lọt ra UI (FR-011). Comment code có thể giữ tiếng Việt.
- [X] T021 [P] Kiểm tra quyền: nút Create/Update/Delete ẩn/disable đúng theo `permissionList`.
- [X] T022 Chạy `npm run lint` trong `compliance-client` và sửa cảnh báo của file mới.
- [ ] T023 Kiểm thử thủ công theo [quickstart.md](./quickstart.md) — 6 kịch bản. (CHƯA CHẠY — cần backend chạy + đăng nhập user có quyền `EutrSteps.*`; thực hiện thủ công trên trình duyệt.)

---

## Phase 8: Chống trùng Step name (FR-005a) — bổ sung 2026-08-11

**Mục tiêu**: Không cho tạo mới hoặc sửa một bước thành tên trùng (không phân biệt hoa/thường, đã
trim) với một bước khác đã tồn tại; bản ghi đang sửa không tự so trùng với chính nó.
**Independent test**: Add tên đã tồn tại (kể cả khác hoa/thường hoặc có khoảng trắng đầu/cuối) →
bị chặn với thông báo tiếng Anh, không tạo bản ghi. Edit một bước sang tên đã tồn tại ở bước khác →
bị chặn, không lưu. Edit một bước và giữ nguyên tên hiện tại của chính nó → lưu thành công.

Backend — GAP đã xác minh (chưa có kiểm tra trùng tên); clone khuôn mẫu `EutrMastersRepository`/`EutrMastersService`:

- [X] T024 [P] Thêm method `ExistsNameAsync(string name, long? excludeId, CancellationToken ct = default)` vào interface mới `compliance-sys-api/src/ComplianceSys.Application/Interfaces/Repositories/IEutrStepRepository.cs` — kế thừa `IRepository<EutrStep, long>` (clone `IEutrMastersRepository.cs`).
- [X] T025 Tạo `compliance-sys-api/src/ComplianceSys.Infrastructure/Repositories/EutrStepRepository.cs` — kế thừa `DapperRepository<EutrStep, long>`, implement `IEutrStepRepository`; `ExistsNameAsync` dùng SQL `SELECT COUNT(1) FROM eutr_steps WHERE LOWER(TRIM(Name)) = LOWER(TRIM(@name))` + `AND Id <> @excludeId` khi `excludeId.HasValue` (clone `EutrMastersRepository.ExistsStepPrefixAsync`) (phụ thuộc T024).
- [X] T026 Đăng ký DI trong `compliance-sys-api/src/ComplianceSys.Infrastructure/DependencyInjection.cs`: thêm `services.AddScoped<IEutrStepRepository, EutrStepRepository>();` cạnh dòng đăng ký `IEutrMastersRepository` (phụ thuộc T025).
- [X] T027 Sửa `compliance-sys-api/src/ComplianceSys.Application/Services/EutrStepService.cs`: đổi field/constructor từ `IRepository<EutrStep, long>` sang `IEutrStepRepository`; override `AddAsync(EutrStepRequestDto dto, string userEmail, CancellationToken ct)` gọi `ExistsNameAsync(dto.Name, null, ct)` và override `UpdateAsync(long id, EutrStepRequestDto dto, string userEmail, CancellationToken ct)` gọi `ExistsNameAsync(dto.Name, id, ct)`; nếu trùng, `throw new InvalidOperationException("A step with this name already exists.")` trước khi gọi `base.AddAsync`/`base.UpdateAsync` (clone `EutrMastersService.AddAsync/UpdateAsync`) (phụ thuộc T026).

Frontend — SỬA cách xử lý lỗi khi submit (file đã tồn tại, không thêm field mới):

- [X] T028 [US2] Sửa catch block của thao tác Create trong `compliance-client/src/presentation/pages/eutr-steps/index.jsx`: khi API trả lỗi (409 trùng tên), lấy `err?.response?.data?.message || err?.message` và hiển thị qua `CustomSnackbar` với `severity: "error"` (clone cách `eutr-masters/index.jsx` xử lý lỗi trùng StepId/Prefix) (phụ thuộc T027).
- [X] T029 [US3] Sửa catch block của thao tác Update trong cùng file `index.jsx` theo đúng cách T028 (phụ thuộc T028, cùng file nên chạy tuần tự). (Create/Update dùng chung 1 modal `onSubmit` → cùng 1 catch block, đã sửa trong T028.)

Kiểm thử:

- [ ] T030 Kiểm thử thủ công kịch bản 7 & 8 trong [quickstart.md](./quickstart.md): Add tên trùng (kể cả khác hoa/thường, khoảng trắng đầu/cuối) bị chặn; Edit sang tên trùng bị chặn; Edit giữ nguyên tên chính nó lưu thành công (phụ thuộc T029). (CHƯA CHẠY — cần backend chạy + đăng nhập user có quyền `EutrSteps.*`; thực hiện thủ công trên trình duyệt, giống T023.)

**Checkpoint**: FR-005a hoạt động end-to-end, không phá vỡ US1–US4 đã có.

---

## Dependencies & thứ tự

- **Phase 1** (Setup) → **Phase 2** (Foundational) là điều kiện tiên quyết của mọi user story.
- Trong Phase 2: T004/T005/T006/T009 song song; T007 cần T005+T006; T008 cần T007.
- **US1 (Phase 3)** dựng MVP. **US2/US3/US4** đều bổ sung vào `index.jsx` nên T016 → T017 → T019
  thực thi tuần tự (cùng file); các file component/hook mới (T015, T018, T011, T010) song song được.
- **Phase 7** sau khi các user story xong.
- **Phase 8** (FR-005a) độc lập với Phase 7, nhưng cần US2+US3 (Phase 4, 5) đã xong vì sửa cùng
  `index.jsx`. Trong Phase 8: T024 không phụ thuộc gì (chạy song song với Phase 7 nếu muốn);
  T025 cần T024; T026 cần T025; T027 cần T026; T028 cần T027; T029 cần T028 (cùng file); T030 cần
  T029.

## Cơ hội song song

- Phase 2: `[P]` T004, T005, T006, T009 cùng lúc.
- Phase 3: `[P]` T010, T011 cùng lúc (trước T012).
- Component độc lập: T015 (modal), T018 (action cell) có thể làm sớm song song.
- Phase 8: T024 `[P]` có thể làm sớm, song song với Phase 7 (Polish) vì khác file hoàn toàn.

## MVP

US1 (Phase 3) — xem + tìm kiếm + phân trang — là lát cắt tối thiểu khả dụng, có thể demo độc lập.

## Tổng quan

- Tổng task: **30**
- Theo story: US1 = 5 (T010–T014), US2 = 3 (T015–T016, T028), US3 = 2 (T017, T029), US4 = 2
  (T018–T019).
- Foundational = 6 (T004–T009), Setup = 3, Polish = 4.
- Phase 8 (FR-005a, 2026-08-11) = 7 (T024–T030): backend gap = 4 (T024–T027), frontend = 2
  (T028–T029), kiểm thử = 1 (T030).
