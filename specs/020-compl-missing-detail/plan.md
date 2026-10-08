# Implementation Plan: Compliance Missing Detail

**Branch**: `020-compl-missing-detail` | **Date**: 2026-10-05 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/020-compl-missing-detail/spec.md` (gồm Update 2026-10-05: nguồn dữ liệu = trigger `test-compliance-missing` + bảng `compl_missing_detail`)

## Summary

Màn "Compliance missing detail" (`/compliance-missing`) hiển thị snapshot lưu trong bảng mới `compl_missing_detail`. Snapshot do một trigger mới `GET api/compl-missing-detail/test-compliance-missing` sinh ra: chạy một **bản copy** của `BuildCurrentSalesOrderAlertComplianceListAsync` (làm mới `compl_so_missing` bằng cách duyệt open sales order, rồi đọc lại và group theo Master code / Code / Type / Product), **không gửi email/notification**, sau đó thay toàn bộ `compl_missing_detail` (bỏ SalesId) trong một transaction.

Giao diện = clone màn `compliance-missing` bỏ 5 cột gắn với Sales order, bỏ bộ lọc Year/Week và nút Refresh-from-D365. Ghi chú follow-up lưu bảng riêng khóa theo 4 cột. Toàn bộ là code mới/copy (FR-015); code cũ chỉ bị **thêm dòng đăng ký** ở các điểm DI/route/menu.

## Technical Context

**Language/Version**: C# / .NET 8 (backend); JavaScript React 18 + Vite + MUI DataGrid (frontend)

**Primary Dependencies**: Dapper + MySql.Data, ClosedXML (export), FluentValidation, Serilog, `IComplDynamicsService` + `IViewCompliancesService` (dùng nguyên trạng); MUI X DataGrid (frontend)

**Storage**: MySQL DB compliance — bảng mới `compl_missing_detail`, `compl_missing_detail_note`; bảng cũ `compl_so_missing` dùng làm vùng trung gian (qua `IComplSoMissingRepository` nguyên trạng). Menu/quyền ở `res_auth_db`.

**Testing**: Kiểm tra thủ công theo [quickstart.md](quickstart.md) và đối chiếu SQL (repo chưa có test tự động cho nhóm màn này).

**Target Platform**: Web (React SPA + ASP.NET Core API)

**Project Type**: web-application (monorepo hai git repo lồng nhau: `compliance-client`, `compliance-sys-api`)

**Performance Goals**: màn hình hiện trang đầu < 5 giây (đọc từ bảng snapshot). Trigger chạy dài (duyệt toàn bộ open SO) — chấp nhận, không có mục tiêu thời gian.

**Constraints**: Không sửa hàm/bảng/job/endpoint đang chạy (FR-015). Trigger không gửi mail. Thay snapshot KHÔNG dùng transaction (FR-008). UI label tiếng Anh giống màn tham chiếu; comment tiếng Việt.

**Scale/Scope**: số dòng snapshot bằng số tổ hợp (Master, Code, Type, Product) đang thiếu — vài nghìn; phân trang server-side 50/trang.

## Constitution Check

| Principle | Đánh giá | Ghi chú |
|-----------|----------|---------|
| I. Layered Clean Architecture | PASS | Controller mỏng → Application service → Infrastructure repository; FE domain/infrastructure/application/presentation, đăng ký `di/repositories.js`. |
| II. Reference-Pattern Reuse | PASS | Reference = feature `compliance-missing` (báo cáo + ghi chú + export), clone & đổi tên nhất quán. |
| III. Reuse Existing Backend | PASS có justify | Tái dùng nguyên trạng `IComplDynamicsService`, `IViewCompliancesService`, `IComplSoMissingRepository`. Endpoint/repo/note cũ khóa theo SalesId/ETD và bị cấm sửa → viết mới (Complexity Tracking). |
| IV. Vietnamese Comments; Localizable UI | PASS | Comment tiếng Việt; label tiếng Anh như màn tham chiếu. |
| V. Routing & Menu Registration | PASS | `RouteResolver.jsx` + `menu-items/ComplianceSystem.jsx` + seed menu DB; mỗi endpoint có policy `ComplianceMissingDetail.*`. |

Re-check sau thiết kế: không có vi phạm mới; rủi ro đồng thời ghi ở research R3.

## Project Structure

### Documentation (this feature)

```text
specs/020-compl-missing-detail/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/compl-missing-detail-api.md
├── checklists/requirements.md
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

Reference clone: `ComplSoMissing*` (backend), `compl-so-missing` + `pages/compliance-missing` (frontend). Chỉ các dòng đánh dấu `[+dòng]` chạm file cũ và chỉ thêm dòng.

```text
compliance-sys-api/src/
├── ComplianceSys.Api/Controllers/
│   └── ComplMissingDetailController.cs        # api/compl-missing-detail: GET test-compliance-missing; POST search, export, note, note/import
├── ComplianceSys.Application/
│   ├── Dtos/Request/MissingDetailSearchRequestDto.cs
│   ├── Dtos/Response/MissingDetailRowDto.cs, MissingDetailRefreshResultDto.cs
│   ├── Interfaces/Repositories/IComplMissingDetailRepository.cs, IComplMissingDetailNoteRepository.cs
│   ├── Interfaces/Services/IComplMissingDetailRefreshService.cs, IComplMissingDetailSearchService.cs,
│   │                        IComplMissingDetailExportService.cs, IComplMissingDetailNoteService.cs
│   ├── Services/ComplMissingDetailRefreshService.cs   # copy BuildCurrent…/RefreshSalesOrderMissing… + replace snapshot
│   ├── Services/ComplMissingDetailSearchService.cs, ComplMissingDetailExportService.cs, ComplMissingDetailNoteService.cs
│   └── DependencyInjection.cs                  # [+dòng] đăng ký service
├── ComplianceSys.Domain/Entities/ComplMissingDetail.cs, ComplMissingDetailNote.cs
└── ComplianceSys.Infrastructure/
    ├── Repositories/ComplMissingDetailRepository.cs, ComplMissingDetailNoteRepository.cs
    ├── DependencyInjection.cs                  # [+dòng] đăng ký repository
    └── Sqls/
        ├── Tables/compl_missing_detail.sql, compl_missing_detail_note.sql   # bản tham chiếu
        └── Migration/
            ├── 35_create_compl_missing_detail.sql
            ├── 36_create_compl_missing_detail_note.sql

compliance-client/src/
├── domain/interfaces/IComplMissingDetailRepository.js
├── infrastructure/api/complMissingDetailApi.js
├── infrastructure/repositories/RestComplMissingDetailRepository.js
├── application/usecases/compl-missing-detail/{Search,Export,SaveNote,ImportNotes}ComplMissingDetailUseCase.js
├── di/repositories.js                          # [+dòng]
├── app/routes/RouteResolver.jsx                # [+dòng] lazy import + codeToComponent
├── presentation/menu-items/ComplianceSystem.jsx # [+mục] url '/compliance-missing-bk' (Update 4)
└── presentation/pages/compliance-missing-detail/
    ├── index.jsx
    └── hooks/{useComplMissingDetailData,useComplMissingDetailColumns,useComplMissingDetailNote}.js(x)
```

**Structure Decision**: web application, hai project độc lập; mọi file mới, chỉ thêm dòng ở 5 điểm đăng ký (DI ×2, `repositories.js`, `RouteResolver.jsx`, `ComplianceSystem.jsx`).

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Bản copy logic refresh + group thay vì gọi `BuildCurrentSalesOrderAlertComplianceListAsync` | Hàm cũ là `private` trong `ComplNotificationService` và FR-015 cấm sửa | Đổi sang `public`/tách helper dùng chung phải chạm code đang chạy |
| Bảng note riêng (khóa 4 cột) | Khóa note cũ có SalesId; FR-009/FR-014 | Đổi khóa bảng cũ sửa thứ đang chạy |
| Code clone màn hình/hook/usecase | FR-015 | Refactor dùng chung phải chạm màn cũ |
