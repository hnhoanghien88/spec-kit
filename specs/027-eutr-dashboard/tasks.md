# Tasks: EUTR Dashboard

**Input**: Design documents from `/specs/027-eutr-dashboard/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/eutr-dashboard-api.md
**Tests**: Không yêu cầu test tự động; kiểm tra thủ công theo quickstart.md.

Đường dẫn: `API` = `compliance-sys-api/src`, `WEB` = `compliance-client/src`. Comment code tiếng Việt, UI tiếng Anh.

## Phase 1: Setup

- [X] T001 Xác nhận tên policy Read thực tế của module Documents/Sales Orders/Purchase Orders trong `API/ComplianceSys.Api/Controllers/` (EutrDocuments*, EutrSalesOrders*/ViewCompliances*, EutrPurchaseOrders*) và ghi lại vào `specs/027-eutr-dashboard/contracts/eutr-dashboard-api.md`
- [X] T002 [P] Xác nhận schema thật của `eutr_progression`, `compl_sync_sales_line`, `eutr_purchase_attachments`, `eutr_documents`, `eutr_references`, `eutr_reference_types` trong `compliance_all.sql` (tên cột CreatedDate, Type…) để viết SQL đúng

## Phase 2: Foundational (chặn mọi user story)

- [X] T003 Tạo `API/ComplianceSys.Application/Interfaces/Repositories/IEutrDashboardRepository.cs` và `API/ComplianceSys.Application/Interfaces/Services/IEutrDashboardService.cs` (3 phương thức: PoSummary, SoSummary, DocumentSummary(dueDays))
- [X] T004 [P] Tạo các DTO trong `API/ComplianceSys.Application/Dtos/Response/`: `EutrDashboardPoSummaryDto.cs`, `EutrDashboardSoSummaryDto.cs`, `EutrDashboardDocumentSummaryDto.cs` (theo data-model.md, kèm `AsOf`)
- [X] T005 Tạo `API/ComplianceSys.Infrastructure/Repositories/EutrDashboardRepository.cs` (Dapper, kế thừa như `ComplDashboardRepository`) với khung 3 phương thức, đăng ký trong `API/ComplianceSys.Infrastructure/DependencyInjection.cs`
- [X] T006 Tạo `API/ComplianceSys.Application/Services/EutrDashboardService.cs` (chuyển tiếp repository, chuẩn hoá dueDays 0–365 mặc định 30), đăng ký trong `API/ComplianceSys.Application/DependencyInjection.cs`
- [X] T007 Tạo `API/ComplianceSys.Api/Controllers/EutrDashboardController.cs` route `api/eutr-dashboard` với 3 GET (`po-summary`, `so-summary`, `document-summary`), policy theo T001, try/catch + Serilog + `ApiResponse` như `ComplDashboardController`
- [X] T008 [P] Thêm 3 phương thức vào `WEB/domain/interfaces/IDashboardRepository.js`, `WEB/infrastructure/api/dashboardApi.js`, `WEB/infrastructure/repositories/RestDashboardRepository.js`
- [X] T009 [P] Thêm 3 usecase (`GetEutrPoSummaryUseCase`, `GetEutrSoSummaryUseCase`, `GetEutrDocumentSummaryUseCase`) vào `WEB/application/usecases/dashboard/index.js`
- [X] T010 Tạo khung `WEB/presentation/pages/dashboard/eutr/EutrDashboardSection.jsx`: tiêu đề "EUTR", ghi chú "Open orders only", nút Refresh + thời điểm cập nhật, ẩn toàn khu vực khi user không có quyền đọc ở cả 3 menu (eutr-documents, eutr-sales-orders, eutr-purchase-orders theo permissionList), mỗi khối bọc component dùng chung loading/empty/error + Retry (`EutrBlock.jsx`); chèn `<EutrDashboardSection />` cuối `WEB/presentation/pages/dashboard/index.jsx`

**Checkpoint**: API trả 3 endpoint rỗng/khung, khu vực EUTR hiện và ẩn đúng theo quyền.

## Phase 3: User Story 1 — Purchase Order (P1) 🎯 MVP

**Goal**: KPI + phân loại Progress + top 10 PO thấp nhất + cảnh báo Trader relationship.
**Independent Test**: Số PO trên dashboard khớp màn hình Purchase Orders (012).

- [X] T011 [US1] Cài SQL `GetPoSummaryAsync` trong `EutrDashboardRepository.cs`: phạm vi PO = PurchId trong `eutr_purchase_attachments` của SalesId có `compl_sync_sales_line.SalesStatus='Backorder'`; phân loại No template / No required step / Completed / In progress / chưa tính theo research R3; top 10 thấp nhất; đếm Trader relationship (FR-010..014)
- [X] T012 [US1] Ráp `EutrDashboardService.GetPoSummaryAsync` (tính completedPercent loại No template/No required step khỏi mẫu số, FR-012) và nối vào controller `po-summary`
- [X] T013 [P] [US1] Tạo `WEB/presentation/pages/dashboard/eutr/EutrPoBlock.jsx`: thẻ Total/Completed/In progress/No template/No required step, % Completed, biểu đồ tròn (gom phần <3% thành Other), bảng top 10 (nhấn Purch Id → màn View PO), cảnh báo Trader relationship; nhấn thẻ → danh sách Purchase Orders (FR-004)
- [X] T014 [US1] Gắn `EutrPoBlock` vào `EutrDashboardSection.jsx` (chỉ khi có quyền menu eutr-purchase-orders)

## Phase 4: User Story 2 — Sales Order (P1)

**Goal**: Tổng Sales Order mở, phân bố Progress, Mapped/Missing, top 10 thấp nhất, sắp đến hạn ETD.
**Independent Test**: Số liệu khớp màn hình Sales Orders (005) với đơn Open order.

- [X] T015 [US2] Cài SQL `GetSoSummaryAsync` trong `EutrDashboardRepository.cs`: SO mở từ `compl_sync_sales_line` (Backorder, DISTINCT SalesId) join `eutr_progression` Type 0; phân loại Completed/In progress/No template; tổng Finished vs Missing; top 10 (FR-020..023)
- [X] T016 [US2] Ráp `EutrDashboardService.GetSoSummaryAsync` (mappedPercent) và nối controller `so-summary`
- [X] T017 [P] [US2] Tạo `WEB/presentation/pages/dashboard/eutr/EutrSoBlock.jsx`: thẻ Total open, phân bố Progress, Mapped vs Missing + %, bảng top 10 (nhấn Sales ID → View summary), nhấn thẻ → danh sách Sales Orders
- [ ] T018 [US2] Thêm thẻ "Due soon (ETD)" (FR-024) trong `EutrSoBlock.jsx`: gọi endpoint tham chiếu sales-order hiện có (reference type 11, `RsVnETD` trong [hôm nay, hôm nay+dueDays], Open order, chưa Completed) — lỗi chỉ làm thẻ này báo lỗi; thiếu ETD không tính (research R4)
  - **HOÃN**: ETD chỉ có ở D365 và filter `inweeks` tối đa 5 tuần, lại cần giao với progression cục bộ để loại đơn Completed — chưa triển khai, cần quyết định (đồng bộ ETD về DB hoặc bỏ FR-024).
- [X] T019 [US2] Gắn `EutrSoBlock` vào `EutrDashboardSection.jsx` (quyền menu eutr-sales-orders)

## Phase 5: User Story 3 — Documents (P2)

**Goal**: Tổng tài liệu, theo Type, Expiring soon/Expired, danh sách sắp hết hạn.
**Independent Test**: Số Expiring/Expired khớp danh sách Documents (004) lọc Valid to.

- [X] T020 [US3] Cài SQL `GetDocumentSummaryAsync(dueDays)` trong `EutrDashboardRepository.cs`: tổng, upload 7/30 ngày, theo Type (join `eutr_references`/`eutr_reference_types`, đếm document duy nhất), Expiring/Expired chỉ với `ValidTo IS NOT NULL`, top 10 sắp hết hạn gần nhất kèm Type/Step (FR-030..033)
- [X] T021 [US3] Ráp service + nối controller `document-summary` (tham số dueDays)
- [X] T022 [P] [US3] Tạo `WEB/presentation/pages/dashboard/eutr/EutrDocumentBlock.jsx`: thẻ Total/Uploaded 7d/30d, biểu đồ theo Type, thẻ Expiring soon/Expired, bảng 10 tài liệu sắp hết hạn; nhấn thẻ → danh sách Documents
- [X] T023 [US3] Gắn `EutrDocumentBlock` vào `EutrDashboardSection.jsx` (quyền menu eutr-documents)

## Phase 6: User Story 4 — Ngưỡng ngày (P3)

**Goal**: User đổi ngưỡng "sắp hết hạn/sắp đến hạn" (mặc định 30).
**Independent Test**: Đổi 30 → 60, thẻ Expiring soon và Due soon tính lại.

- [X] T024 (ĐÃ BỎ: ngưỡng cố định 30 ngày) [US4] Thêm state `dueDays` (mặc định 30; lựa chọn 30/60/90) vào `EutrDashboardSection.jsx`, truyền xuống `EutrDocumentBlock` và `EutrSoBlock`, gọi lại API khi đổi (FR-051)

## Phase 7: Polish & Cross-Cutting

- [X] T025 Rà soát trạng thái loading/empty/error từng khối và Edge Cases trong spec (ERP lỗi, không quyền, dữ liệu rỗng, biểu đồ nhãn nhỏ)
- [X] T026 Build backend (`dotnet build compliance-sys-api/ComplianceSys.sln`) và frontend (`npm run build` trong `compliance-client`), sửa lỗi
- [ ] T027 Chạy các kịch bản trong `specs/027-eutr-dashboard/quickstart.md` nếu có môi trường; ghi rõ mục không kiểm tra được
  - Chưa chạy: cần DB + API đang chạy; backend/frontend mới chỉ build thành công.
- [X] T028 Xác nhận phần Compliance hiện có không đổi hành vi (SC-006) (phần Compliance không bị sửa; chỉ thêm section ở cuối trang)

## Dependencies & Order

- Phase 1 → Phase 2 (chặn) → US1, US2, US3 (độc lập nhau, có thể song song) → US4 (cần US2 + US3) → Polish.
- Trong mỗi story: SQL repository → service/controller → block frontend → gắn vào section.
- Song song: T002, T004, T008, T009; T013/T017/T022 (file khác nhau).

## Implementation Strategy

- **MVP**: Phase 1–2 + US1 (PO). Sau đó US2, US3, US4 tăng dần.
