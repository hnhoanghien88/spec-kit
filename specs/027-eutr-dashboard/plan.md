# Implementation Plan: EUTR Dashboard

**Branch**: `027-eutr-dashboard` | **Date**: 2026-10-15 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/027-eutr-dashboard/spec.md`

## Summary

Thêm khu vực **EUTR** vào cuối trang `/dashboard` (dưới phần Compliance hiện có). Số liệu tổng hợp ở backend bằng truy vấn chỉ-đọc trên các bảng cục bộ đã có (`eutr_progression`, `compl_sync_sales_line`, `eutr_purchase_attachments`, `eutr_documents`, `eutr_references`) nên không cần gọi ERP khi mở dashboard và không cần migration. Ba endpoint tổng hợp độc lập (PO / Sales Order / Documents) → ba khối frontend tải độc lập, ẩn theo quyền menu. Chỉ số ETD (FR-024) chỉ có ở ERP nên lấy qua endpoint tham chiếu D365 hiện có.

## Technical Context

**Language/Version**: Backend C# / .NET (ASP.NET Core); Frontend React (JSX) + MUI + recharts

**Primary Dependencies**: Dapper (qua `Shared.Dapper`), Serilog, MUI, recharts (đã dùng ở dashboard hiện tại)

**Storage**: MySQL (đọc `eutr_progression`, `compl_sync_sales_line`, `eutr_purchase_attachments`, `eutr_documents`, `eutr_references`, `eutr_reference_types`) — KHÔNG thêm/đổi bảng

**Testing**: Kiểm thử thủ công theo [quickstart.md](quickstart.md) (đối chiếu số liệu với màn hình 004/005/012); unit test service nếu dự án đã có test project cho service tương tự

**Target Platform**: Web (SPA + REST API)

**Project Type**: web-service + SPA (`compliance-sys-api/`, `compliance-client/`)

**Performance Goals**: Mỗi endpoint trả ≤ 2 giây với dữ liệu vận hành hiện tại (SC-003: toàn khu vực ≤ 5 giây)

**Constraints**: Chỉ đọc; không gọi D365 trong 3 endpoint tổng hợp; lỗi một khối không ảnh hưởng khối khác; nhãn UI tiếng Anh (spec yêu cầu, như dashboard hiện tại — Constitution IV cho phép khi spec nêu rõ), comment code tiếng Việt

**Scale/Scope**: Hàng nghìn Sales Order/PO, vài chục nghìn tài liệu

## Constitution Check

| Nguyên tắc | Đánh giá |
|---|---|
| I. Layered Clean Architecture | PASS — Controller mỏng → `IEutrDashboardService` (Application) → `IEutrDashboardRepository` (Infrastructure, Dapper). Frontend: domain interface + infrastructure api/repo + usecases + presentation, đăng ký DI. |
| II. Reference-Pattern Reuse | PASS — nhân bản cấu trúc dashboard hiện có (`ComplDashboard*`, `dashboardApi`, `RestDashboardRepository`, usecases/dashboard). |
| III. Reuse Existing Backend | PASS — chỉ thêm endpoint tổng hợp mới (khoảng trống đã xác minh: chưa có endpoint tổng hợp EUTR); tái dùng công thức Progress đã lưu ở `eutr_progression`, không viết lại tính Progress. |
| IV. Vietnamese Comments; Localizable UI | PASS — comment tiếng Việt, UI tiếng Anh theo spec/Assumptions. |
| V. Routing & Menu | PASS — dùng route `/dashboard` sẵn có, không thêm route/menu; tôn trọng policy từng endpoint. |

Re-check sau thiết kế: không vi phạm.

## Project Structure

### Documentation (this feature)

```text
specs/027-eutr-dashboard/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/eutr-dashboard-api.md
└── tasks.md          # do /speckit-tasks tạo
```

### Source Code

```text
compliance-sys-api/src/
├── ComplianceSys.Api/Controllers/EutrDashboardController.cs        # mới: api/eutr-dashboard/*
├── ComplianceSys.Application/
│   ├── Dtos/Response/EutrDashboard*Dto.cs                          # mới
│   ├── Interfaces/Repositories/IEutrDashboardRepository.cs         # mới
│   ├── Interfaces/Services/IEutrDashboardService.cs                # mới
│   ├── Services/EutrDashboardService.cs                            # mới
│   └── DependencyInjection.cs                                      # đăng ký service
└── ComplianceSys.Infrastructure/
    ├── Repositories/EutrDashboardRepository.cs                     # mới (Dapper, SQL chỉ đọc)
    └── DependencyInjection.cs                                      # đăng ký repository

compliance-client/src/
├── domain/interfaces/IDashboardRepository.js                       # thêm 3 phương thức EUTR
├── infrastructure/api/dashboardApi.js                              # thêm 3 lời gọi
├── infrastructure/repositories/RestDashboardRepository.js          # thêm 3 phương thức
├── application/usecases/dashboard/                                 # thêm 3 usecase
└── presentation/pages/dashboard/
    ├── index.jsx                                                   # chèn <EutrDashboardSection/> cuối trang
    └── eutr/                                                       # mới: EutrDashboardSection + PoBlock, SoBlock, DocumentBlock
```

**Structure Decision**: Web application hai dự án (API + client) như hiện trạng; thêm tính năng theo đúng lớp của dashboard compliance.

## Complexity Tracking

Không có vi phạm Constitution cần biện minh.
