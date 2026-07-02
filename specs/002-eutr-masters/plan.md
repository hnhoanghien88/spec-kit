# Implementation Plan: EUTR Masters Management

**Branch**: `002-eutr-masters` | **Date**: 2026-07-02 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/002-eutr-masters/spec.md`

## Summary

Xây dựng màn hình **EUTR Masters** với CRUD + Import + Export Excel. Mỗi bản ghi gắn **một bước
(StepId → `eutr_steps`)** với một **Prefix**, lưu vào bảng `eutr_master_documents`. Grid hiển thị
**tên bước** (không phải mã). Khi Add/Update dùng **select box** chọn bước rồi nhập Prefix; **chặn
lưu** khi trùng cặp (StepId, Prefix). Import nhận file Excel 2 cột (step name, prefix), bỏ dòng tiêu
đề, **import một phần** và báo cáo dòng lỗi. **Export** tải về file Excel 2 cột (Step name, Prefix)
— luôn có dòng tiêu đề, có dữ liệu thì kèm dòng dữ liệu, rỗng thì chỉ tiêu đề; định dạng khớp import
để round-trip.

Khác với feature `001-eutr-steps` (frontend-only vì backend đã có), **backend cho EUTR Masters CHƯA
tồn tại** → phải **tạo mới cả backend lẫn frontend**. Backend clone mẫu **EutrStep** (Nguyên tắc II),
phần Import clone mẫu **ComplMasterImportService** (ClosedXML). Frontend clone mẫu **eutr-steps**, bổ
sung select box (dùng lại use case `GetEutrStepsUseCase` sẵn có) và nút/hộp thoại Import (mẫu
`compliance-master`).

## Technical Context

**Language/Version**: .NET 8 (backend); JavaScript (ES modules), React 18 + Vite (frontend)

**Primary Dependencies**: Backend — Dapper (`Res.Shared.Dapper`), FluentValidation, AutoMapper,
**ClosedXML 0.102.3** (đọc Excel), `Res.Shared.AuthN`/`AuthZ`. Frontend — React, MUI
(`@mui/material`, `@mui/x-data-grid`, `@mui/icons-material`), axios.

**Storage**: MySQL qua Dapper; bảng `eutr_master_documents` (đã định nghĩa trong
`docs/design/eutr/eutr_db.sql`), FK `StepId → eutr_steps(Id)`.

**Testing**: Kiểm thử thủ công theo `quickstart.md` (dự án chưa có test tự động cho các trang CRUD).

**Target Platform**: Web (SPA phục vụ qua nginx) + API .NET 8.

**Project Type**: Web application (frontend + backend tách biệt trong monorepo).

**Performance Goals**: Tương đương các màn CRUD hiện có; phân trang server-side, mặc định 10
dòng/trang; import ≥50 dòng trả kết quả < 30s (SC-006).

**Constraints**: Tuân thủ policy quyền `EutrMasters.*`; comment code **tiếng Việt**, nhưng **toàn bộ
văn bản UI hiển thị bằng tiếng Anh** (FR-017); ràng buộc duy nhất (StepId, Prefix).

**Scale/Scope**: 1 màn hình. Backend ~9 file mới + sửa DI/mapping. Frontend ~14 file mới + sửa 3 file
wiring.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Nguyên tắc | Trạng thái | Ghi chú |
|-----------|-----------|---------|
| I. Layered Clean Architecture | ✅ PASS | Backend Api→Application→Domain + Infrastructure; frontend domain/infrastructure/application/presentation + DI |
| II. Reference-Pattern Reuse | ✅ PASS | Backend clone `EutrStep`; Import clone `ComplMasterImportService`; frontend clone `eutr-steps` + mẫu import `compliance-master` |
| III. Reuse Existing Backend | ✅ PASS (không áp dụng) | Backend EUTR Masters **chưa tồn tại** → không có gì để tái sử dụng; tạo mới theo mẫu EutrStep. KHÔNG chạm backend `eutr-steps` hiện hữu (chỉ đọc để nạp select box) |
| IV. Vietnamese Comments; Localizable UI Labels | ✅ PASS | Comment code tiếng Việt; UI label/thông báo **tiếng Anh** theo FR-017 (được phép bởi Principle IV, constitution v2.0.0) |
| V. Routing & Menu Registration | ✅ PASS | Thêm componentMap `eutr-masters` trong `RouteResolver.jsx`, menu item code `eutr-masters`; mỗi thao tác gắn policy `EutrMasters.*`. **Menu + quyền được tạo động & phân quyền trong DB** (không seed bằng code) → là tiền đề vận hành/DB, không phải task code |

Không có vi phạm hiến pháp → không cần Complexity Tracking. Hai điểm **lệch so với BaseService thuần**
(paged query JOIN lấy StepName; override chống trùng) được ghi ở mục "Khác biệt" bên dưới — là chi
tiết triển khai, không phải vi phạm nguyên tắc.

## Project Structure

### Documentation (this feature)

```text
specs/002-eutr-masters/
├── plan.md              # File này
├── spec.md              # Đặc tả
├── research.md          # Phase 0
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1
├── contracts/
│   └── eutr-masters-api.md   # Hợp đồng API MỚI (cần tạo)
└── checklists/
    └── requirements.md
```

### Source Code (repository root)

Backend — **TẠO MỚI** (clone mẫu `EutrStep`; đặt tên `EutrMasters` / `eutr-masters`):

```text
compliance-sys-api/src/
├── ComplianceSys.Domain/Entities/
│   └── EutrMastersDocument.cs                        # Table("eutr_master_documents"): Id, StepId, Prefix (+ BaseEntity audit)
├── ComplianceSys.Application/
│   ├── Dtos/Request/EutrMastersRequestDto.cs         # { StepId, Prefix }
│   ├── Dtos/Response/EutrMastersResponseDto.cs       # entity + StepName (tên bước)
│   ├── Dtos/Response/ImportEutrMastersResultDto.cs   # TotalRows, SuccessCount, FailCount, DuplicateCount, Errors[], Duplicates[]
│   ├── Interfaces/Services/IEutrMastersService.cs
│   ├── Interfaces/Services/IEutrMastersImportService.cs
│   ├── Interfaces/Services/IEutrMastersExportService.cs      # (MỚI cho Export) trả byte[] Excel
│   ├── Services/EutrMastersService.cs                # BaseService + GetPagedAsync(JOIN eutr_steps) + override chống trùng
│   ├── Services/EutrMastersImportService.cs          # ClosedXML: đọc từ dòng 2, map step name→StepId, chống trùng, import một phần
│   ├── Services/EutrMastersExportService.cs          # (MỚI) ClosedXML: header Step name/Prefix + dòng dữ liệu (tên bước, prefix)
│   ├── Validators/EutrMastersRequestDtoValidator.cs  # StepId > 0; Prefix NotEmpty
│   └── Mappings/EutrMappingProfile.cs               # (SỬA) thêm map EutrMastersRequestDto↔EutrMastersDocument, →EutrMastersResponseDto
├── ComplianceSys.Api/Controllers/
│   └── EutrMastersController.cs                      # Route "api/eutr-masters": CRUD + get-all + delete-multi + import + export
└── (SỬA) ComplianceSys.Application/DependencyInjection.cs  # đăng ký IEutrMastersService, IEutrMastersImportService, IEutrMastersExportService, validator
```

Frontend — **CÁC FILE MỚI** (clone `eutr-steps`; đặt tên `EutrMasters` / `eutr-masters`):

```text
compliance-client/src/
├── domain/
│   ├── entities/EutrMasters.js                       # { id, stepId, stepName, prefix, createdBy, createdDate, updatedBy, updatedDate }
│   └── interfaces/IEutrMastersRepository.js          # getAllPaging/getById/create/update/delete/deleteMulti/import
├── infrastructure/
│   ├── api/eutrMastersApi.js                         # base "/eutr-masters" + import(file) multipart + export() responseType blob
│   └── repositories/RestEutrMastersRepository.js
├── application/usecases/eutr-masters/
│   ├── CreateEutrMastersUseCase.js
│   ├── UpdateEutrMastersUseCase.js
│   ├── DeleteEutrMastersUseCase.js
│   ├── DeleteMultiEutrMastersUseCase.js
│   ├── GetPagingEutrMastersUseCase.js
│   ├── ImportEutrMastersUseCase.js
│   └── ExportEutrMastersUseCase.js                 # (MỚI) tải blob + kích hoạt download
├── presentation/pages/eutr-masters/
│   ├── index.jsx                                    # DataGrid + toolbar (Import, Add) + modal + confirm + import-result dialog
│   ├── components/EutrMastersModal.jsx              # Select "Step name" (nạp từ GetEutrStepsUseCase) + TextField "Prefix"
│   ├── components/EutrMastersActionCell.jsx         # Edit / Delete
│   ├── components/ImportResultDialog.jsx            # bảng dòng lỗi/trùng bị bỏ qua
│   │                                                 # (Export: chỉ thêm nút Export vào toolbar index.jsx, không cần component mới)
│   ├── hooks/useEutrMastersColumns.jsx             # cột: stepName, prefix, createdBy, createdDate, actions
│   └── hooks/useEutrMastersData.js
├── (SỬA) di/repositories.js                         # eutrMasters: new RestEutrMastersRepository()
├── (SỬA) app/routes/RouteResolver.jsx              # lazy import + componentMap["eutr-masters"]
└── (SỬA) presentation/menu-items/ComplianceSystem.jsx  # menu item code "eutr-masters", url "/eutr/masters"
```

Backend hiện hữu **CHỈ ĐỌC** (không sửa): `api/eutr-steps` (nạp select box qua GET `/eutr-steps`).

**Structure Decision**: Web application. Feature triển khai **cả backend lẫn frontend**. Mẫu tham
chiếu chuẩn: **EutrStep** (CRUD) + **ComplMasterImportService** (import) + **compliance-master** (UI
import) + **eutr-steps** (UI CRUD).

## Khác biệt so với mẫu (lưu ý khi implement)

### Backend
1. **Entity**: `EutrMastersDocument` có `StepId (long?)` + `Prefix (string?)` thay vì `Name`. Ánh xạ
   bảng `eutr_master_documents` qua `[Table("eutr_master_documents")]`.
2. **Grid cần tên bước + tìm theo tên bước** → `EutrMastersService.GetPagedAsync` KHÔNG dùng paged
   query generic thuần mà **override bằng Dapper SQL JOIN `eutr_steps`** để trả `StepName` và cho
   lọc theo `s.Name LIKE`. (Xem research Quyết định 2.)
3. **Chống trùng (StepId, Prefix)** → **override `AddAsync`/`UpdateAsync`** trong `EutrMastersService`:
   trước khi lưu, truy vấn tồn tại cặp (StepId, Prefix) (loại trừ chính bản ghi khi update); nếu
   trùng → ném lỗi nghiệp vụ (ValidationException/ArgumentException) trả message tiếng Anh. (research
   Quyết định 3.)
4. **Import** (`EutrMastersImportService`, mẫu `ComplMasterImportService`): mở `XLWorkbook`, đọc từ
   **dòng 2** (dòng 1 là tiêu đề), cột A = step name, cột B = prefix; map step name→StepId theo
   `eutr_steps.Name` (khớp không phân biệt hoa/thường); áp dụng chống trùng với DB **và** trong nội
   bộ file; **import một phần**; trả `ImportEutrMastersResultDto` (Errors[], Duplicates[]). (research
   Quyết định 4.)
5. **Controller** `EutrMastersController` route `api/eutr-masters`, thêm action `POST import`
   (`IFormFile file`) như `ComplMasterController.Import`; policy `EutrMasters.*`.
6. **DI**: đăng ký `IEutrMastersService`, `IEutrMastersImportService`, `IEutrMastersExportService`,
   `IValidator<EutrMastersRequestDto>` trong `ComplianceSys.Application/DependencyInjection.cs`.
   Repository generic `IRepository<EutrMastersDocument,long>` tự phân giải (đã đăng ký open-generic).
7. **Export** (`EutrMastersExportService`, mẫu `ComplMasterExportService`): trả `byte[]`. Dùng
   ClosedXML tạo workbook MỚI (không cần template): ghi dòng 1 tiêu đề `Step name`, `Prefix`; lấy
   toàn bộ master qua `IEutrMastersRepository.GetPagedWithStepNameAsync` (pageSize lớn để lấy hết,
   hoặc thêm một hàm lấy-tất-cả) và ghi mỗi bản ghi 1 dòng (StepName, Prefix) từ dòng 2. Rỗng →
   chỉ có dòng tiêu đề. Controller thêm action `GET export` với `[Authorize(Policy =
   "EutrMasters.Download")]`, trả `File(bytes, "...spreadsheetml.sheet", fileName)` như
   `ComplMasterController.ExportMasterMissing` (research Quyết định 7). **Tên file export**:
   `eutr-master-{yyyyMMddHHmmss}.xlsx` (ví dụ `eutr-master-20260702153000.xlsx`).

### Frontend
1. **Modal** có **2 trường**: `stepName` là **Select/Autocomplete** nạp options từ
   `GetEutrStepsUseCase` (dùng lại repo `eutrStep` sẵn có — id làm value, name làm label) + `prefix`
   là TextField. Validate: bắt buộc chọn step **và** nhập prefix.
2. **Columns**: `stepName` (Step name, filterable → server lọc theo tên bước), `prefix` (Prefix),
   `createdBy`, `createdDate`, `actions`; ẩn `id/stepId/updated*` mặc định.
3. **Toolbar** có **Import** (input file ẩn + `ImportEutrMastersUseCase`, hiện `ImportResultDialog`
   với success/fail/duplicate + danh sách lỗi) và **Add** — mẫu `compliance-master/index.jsx`.
4. **API base** `/eutr-masters`; `getById: GET /eutr-masters/get-by-id/{id}`; `import`: POST
   `/eutr-masters/import` multipart/form-data (field `file`).
5. **Menu/permission**: code `eutr-masters`; `permissionList` lấy từ menu; ánh xạ policy
   `EutrMasters.ReadAll/ReadOne/Create/Update/Delete/Download`. **Routing backend-driven**; menu + quyền
   **tạo động & phân quyền trong DB** (không code seed) → là bước cấu hình DB, không phải task code
   (xem research Quyết định 5).
6. **Export**: thêm nút **Export** vào toolbar `index.jsx`; `eutrMastersApi.export()` gọi
   `GET /eutr-masters/export` với `responseType: "blob"` (mẫu `complianceMasterApi.exportMaster`);
   `ExportEutrMastersUseCase` nhận blob và kích hoạt tải file (tạo object URL + thẻ `<a download>`).
   Không cần component/dialog mới. Nút Export hiển thị theo quyền `EutrMasters.Download`
   (`permissionList.includes("Download")`).
7. **Ngôn ngữ UI**: mọi label/nút/breadcrumb/thông báo (gồm nút Export, cảnh báo trùng, báo cáo
   import) bằng **tiếng Anh** (FR-017).

## Complexity Tracking

> Không có vi phạm hiến pháp → bảng này để trống.
