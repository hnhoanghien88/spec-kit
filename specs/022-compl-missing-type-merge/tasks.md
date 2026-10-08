# Tasks: Merge Compliance Missing Screens by Type

**Input**: `/specs/022-compl-missing-type-merge/` (plan.md, spec.md, research.md, data-model.md, contracts/ui-contract.md, quickstart.md)

**Quy ước**: `WEB` = `compliance-client/src`. Chỉ frontend; comment code tiếng Việt; nhãn UI tiếng Anh. Không có test tự động (không yêu cầu) — kiểm tra bằng eslint + quickstart.

## Phase 1: Foundational

- [x] T001 Thêm prop tùy chọn `typeSelector` vào `ComplianceMissingPage` trong `WEB/presentation/pages/compliance-missing/index.jsx`, render ngay trước `<Typography variant="h5">Compliance missing</Typography>` (trong Box header, cùng hàng); không đổi logic khác
- [x] T002 [P] Thêm prop tùy chọn `typeSelector` vào `ComplianceMissingDetailPage` trong `WEB/presentation/pages/compliance-missing-detail/index.jsx`, render ngay trước tiêu đề "Compliance missing detail"; không đổi logic khác

## Phase 2: User Story 1 + 2 — Ô Type và chuyển đổi (P1)

**Goal**: Vào `/compliance-missing` thấy Type = Open orders; đổi sang Compliance thấy màn detail và ngược lại, mỗi Type giữ state riêng.
**Independent Test**: quickstart bước 1–4.

- [x] T003 [US1] Tạo `WEB/presentation/pages/compliance-missing-type/index.jsx`: component `ComplianceMissingTypePage({ initialType })`; state `type` (mặc định `open-orders`); ô Type = MUI `TextField select size="small" label="Type"` rộng ~150, options "Open orders"/"Compliance"; mount từng trang lần đầu được chọn và giữ mounted, ẩn trang không active bằng `display: none`; truyền ô Type qua prop `typeSelector` cho cả hai trang
- [x] T004 [US2] Trong `WEB/app/routes/RouteResolver.jsx`: lazy import trang bọc và đổi `codeToComponent` — `'compliance-missing'` → `<ComplianceMissingTypePage initialType="open-orders" />`, `'compliance-missing-detail'` → `<ComplianceMissingTypePage initialType="compliance" />`

## Phase 3: User Story 3 — Quyền và menu (P2)

**Goal**: Type khả dụng theo quyền hiện có; một mục menu duy nhất.
**Independent Test**: quickstart bước 5–7.

- [x] T005 [US3] Trong `WEB/presentation/pages/compliance-missing-type/index.jsx`: đọc `getMenuDataFromStorage()` (`@presentation/...` cùng helper hai trang đang dùng); Type khả dụng = code `compliance-missing` / `compliance-missing-detail` có trong menu; chỉ ẩn option không khả dụng; còn một option thì tự chọn; `initialType` không khả dụng thì rơi về option còn lại
- [x] T006 [US3] Trong `WEB/presentation/menu-items/ComplianceSystem.jsx`: xóa mục `compliance-missing-detail` (id 30), giữ mục `compliance-missing` url `/compliance-missing`

## Phase 4: Polish

- [x] T007 Chạy `npx eslint` trên các file đã sửa/tạo trong `compliance-client` và sửa lỗi phát sinh
- [x] T008 Cập nhật `specs/022-compl-missing-type-merge/tasks.md` đánh dấu hoàn thành; ghi rõ phần chưa chạy trên môi trường thật (quickstart bước 1–7 cần chạy tay; menu backend `url` cần app khác đồng bộ)

## Dependencies

T001, T002 → T003 → T004; T003 → T005; T006 độc lập; T007 sau cùng.

## Parallel

T001 ∥ T002; T006 ∥ T003.

## Strategy

MVP = Phase 1–2 (switch hoạt động); sau đó Phase 3 và Polish.

## Phase 5: Update 1 — Export Excel (Type = Compliance)

- [x] T009 [US4] `compliance-missing-detail/index.jsx`: tách cờ `SHOW_EXPORT = true` (nút Export Excel kế nút Get from D365, đã có sẵn disable khi rỗng/đang xuất và điều kiện quyền Download) và `SHOW_IMPORT = false`
- [x] T010 [US4] `ComplMissingDetailExportService.cs`: thêm `IncludeNoteColumns = false` để file không có cột Follow up date/Note (khớp lưới); header, tô vàng dòng Expired giữ nguyên. `dotnet build` Application thành công; eslint sạch
- [ ] T011 [US4] Chạy tay: Type = Compliance → Export Excel (có/không filter), so cột/giá trị/màu dòng với màn hình; chưa chạy trên môi trường thật

## Phase 6: Update 2 — Đổi thứ tự cột + View condition

- [x] T012 [US2] `useComplMissingDetailColumns.jsx`: chuyển Type/Product/Product name ngay sau Name; thêm cột `viewCondition` (icon, không sort/filter) sau Master name, chỉ khi `canViewCondition`
- [x] T013 [US2] `compliance-missing-detail/index.jsx`: `handleViewCondition` (GetConditionsByMasterIdUseCase + `ConditionsView`), quyền `ReadOne` của menu `compliance-master`. eslint sạch
- [ ] T014 Chạy tay: Type = Compliance → thứ tự cột mới; bấm View Conditions ở một dòng, so với dialog ở màn compliance-master; chưa chạy trên môi trường thật

## Phase 7: Update 3 — Mở rộng toán tử filter cột (Type = Compliance)

- [x] T015 [US2] `useComplMissingDetailData.js`: thay `SUPPORTED_OPERATORS` bằng `OPERATOR_MAP` (contains, doesNotContain→notcontains, equals, doesNotEqual→notequals, startsWith, endsWith, isEmpty, isNotEmpty); isEmpty/isNotEmpty không cần value. Backend đã hỗ trợ sẵn, không đổi
- [ ] T016 Chạy tay: Type = Compliance → filter cột Name với "does not contain", "starts with", "is empty"... kiểm tra kết quả
