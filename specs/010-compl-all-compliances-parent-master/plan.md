# Implementation Plan: All-Compliances Parent Master Coverage

**Branch**: `010-compl-all-compliances-parent-master` | **Date**: 2026-08-10 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/010-compl-all-compliances-parent-master/spec.md`

## Summary

Sửa `sp_load_compl_by_conditions` (stored procedure có sẵn, phục vụ endpoint có sẵn
`POST api/view-compliances/get-all` của chức năng All Compliances): thêm cột `ParentMaster` ngay
sau `MasterCode` trong `tmp_result`, và đổi STEP 20b (dòng 983) từ `DELETE` các dòng con bị "phủ"
bởi compliance của Master cha (Root) sang `UPDATE` — giữ lại dòng, gán `ParentMaster` = mã
`MasterCode` của Master cha (Root) đã dùng để so khớp, và `Status = 'UseParent'`. Điều kiện xác
định "bị phủ" giữ nguyên 100% logic hiện có (`tmp_hierarchy_root_matches` / `tmp_hierarchy_descendants`,
xem research.md R2) — chỉ đổi hành động cuối (UPDATE thay DELETE), không đổi tập dòng bị ảnh hưởng.
Vì Dapper map theo tên property (xem research.md R4), cần thêm property `ParentMaster` vào
`ViewCompliancesResponseDto` để giá trị thực sự đi tới client — nếu không, cột mới được SQL tính ra
nhưng bị Dapper âm thầm bỏ qua, vi phạm SC-002 của spec.

**Cập nhật (US2, 2026-08-10)**: Backend (US1) đã hoàn thành và đã trả về `parentMaster`/`status:
"UseParent"` qua endpoint có sẵn, nhưng tab "Compliances of Sales order" trong màn hình
`compliance-view-so` (`ref-type=11`) chưa hiển thị giá trị này. Sửa
`compliance-client/.../compliance-view-so/hooks/useComplianceColumns.jsx` (file đã tồn tại, KHÔNG
sửa component dùng chung `AlertProgressCell.jsx` vì nó được 8 nơi khác dùng lại, xem research.md
R8): (a) thêm 1 cột `parentMaster`/"Parent master" ngay sau cột `masterCode`/"Master code"; (b)
trong `renderCell` của cột `progress`/"Expiry warning", thêm 1 nhánh kiểm tra
`params.row.status === "UseParent"` → hiển thị text "Use parent" — đặt SAU nhánh
`replacedById !== null` hiện có (giữ nguyên độ ưu tiên "Already have new version" theo FR-011) và
TRƯỚC khi gọi `AlertProgressCell` (research.md R9). Vì thêm cột mới ở vị trí 1 (ngay sau
`masterCode` ở vị trí 0), phải dời chỉ số `columns.splice(2, 0, {field: "actions", ...})` (dòng 350
hiện tại) sang `columns.splice(3, 0, ...)` để cột `actions` vẫn giữ đúng vị trí tương đối hiện tại
(ngay sau `masterName`, xem data-model.md mục "Thứ tự cột") — không đổi, không thì cột `actions` sẽ
bị chèn lệch (giữa `parentMaster` và `masterName`).

## Technical Context

**Language/Version**: C# 12 / .NET 8 (`ComplianceSys.Infrastructure`, `ComplianceSys.Application`)
— MySQL stored procedure (SQL, không phải C#) cho phần backend (US1). **US2 (mới)**: React 18 +
Vite, JavaScript (JSX, không TypeScript) — `compliance-client/src/presentation/pages/compliance-view-so/`.

**Primary Dependencies**: Dapper (map kết quả `CALL sp_load_compl_by_conditions(...)` theo tên
property vào `ViewCompliancesResponseDto` — xem `ViewCompliancesRepository.GetViewCompliancesAsync`,
research.md R4). **US2**: MUI X DataGrid (cấu hình cột đã dùng sẵn trong `useComplianceColumns.jsx`),
MUI `Typography`/inline style (theo đúng pattern nhãn "Already have new version"/"Missing" đã có
trong cùng file). Không thêm dependency mới ở cả 2 phần.

**Storage**: MySQL — sửa 1 stored procedure có sẵn
(`ComplianceSys.Infrastructure/Sqls/Procedures/sp_load_compl_by_conditions.sql`). Không đổi schema
bảng nào (không có cột DB mới — `ParentMaster` chỉ là cột tính toán trong `tmp_result`/kết quả trả
về, không lưu trữ). Đọc (không sửa) bảng có sẵn `compl_master_hierarchies`. US2 không đụng DB — chỉ
đọc field đã có sẵn trong response JSON.

**Testing**: Không có test tự động cho stored procedure (US1) hay cho `compliance-client` (US2 —
không có test harness frontend nào cho `compliance-view-so` trong repo). Kiểm thử thủ công theo
`quickstart.md`: US1 qua `CALL` trực tiếp trên DB dev; US2 qua trình duyệt (mở tab Compliances of
Sales order với dữ liệu hierarchy đã seed cho US1) + `dotnet build`/`npm run build` (hoặc lint) làm
gate tối thiểu.

**Target Platform**: Backend API hiện có (US1) + Frontend Web hiện có (US2, cùng màn hình
`compliance-view-so` đã tồn tại) — không có platform mới.

**Project Type**: Sửa gap trong 1 endpoint + 1 màn hình đã tồn tại (Nguyên tắc III) — KHÔNG có
route/màn hình mới (Nguyên tắc V không áp dụng, xem Constitution Check).

**Performance Goals**: Không đổi so với hiện tại ở cả 2 phần — US1: STEP 20b vẫn dùng đúng 2 bảng
tạm đã được đánh index sẵn, chỉ đổi `DELETE` thành `UPDATE` cùng điều kiện JOIN. US2: chỉ thêm 1 cột
tĩnh và 1 nhánh `if` trong `renderCell` đã có — không thêm gọi API mới, không đổi số dòng render.

**Constraints**:
- Comment SQL/C# mới thêm PHẢI bằng tiếng Việt (Nguyên tắc IV).
- **US2**: Nhãn UI mới ("Parent master", "Use parent") viết bằng tiếng Anh — theo đúng ngôn ngữ các
  nhãn khác đã có sẵn trong chính cột/tab này ("Master code", "Missing", "Already have new
  version") — nhất quán với quy ước hiện tại của file này, không phải một ngoại lệ mới cần biện
  minh riêng (Nguyên tắc IV cho phép khi khớp quy ước đã có của phần UI đang sửa).
- KHÔNG sửa `sp_load_compl_by_conditions_count.sql` (proc đếm song song, vẫn `DELETE` như cũ) —
  ngoài phạm vi theo Assumptions của spec.md.
- KHÔNG sửa các nơi tiêu thụ `Status` hiện tại ngoài tab đang nhắm tới (`ComplianceMissingDrawer.jsx`,
  `useAllCompliancesColumnsSaleOrder.jsx`, `compl_so_missing`/feature 009, các hook cột khác như
  `useComplianceColumnsGroup.jsx`/`useMatComplianceColumnsGroup.jsx`/`useComplianceDetailColumns.jsx`)
  — xác minh không bị vỡ (xem research.md R6), không mở rộng hiển thị "UseParent" ra ngoài tab
  Compliances of Sales order trong phạm vi feature này.
- **US2**: KHÔNG sửa component dùng chung `AlertProgressCell.jsx` (dùng lại ở 8 nơi khác trong repo,
  xem research.md R8) — logic "Use parent" phải nằm ở `renderCell` của cột `progress` trong
  `useComplianceColumns.jsx`, đặt TRƯỚC lệnh gọi `AlertProgressCell`, không sửa bên trong component.
- Tập hợp dòng bị đổi từ "xóa" sang "giữ + gán nhãn" (US1) PHẢI giống chính xác tập hợp dòng mà logic
  `DELETE` hiện tại đang xóa — không mở rộng/thu hẹp điều kiện phủ (FR-005 của spec.md).

**Scale/Scope**: US1 — 2 file sửa (`sp_load_compl_by_conditions.sql`, `ViewCompliancesResponseDto.cs`),
đã hoàn thành (xem tasks.md T001-T008). US2 (mới) — 1 file sửa
(`compliance-client/src/presentation/pages/compliance-view-so/hooks/useComplianceColumns.jsx`,
~10-15 dòng: 1 cột mới + 1 nhánh `if` + dời 1 chỉ số `splice`). Không có file mới ở cả 2 phần.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Nguyên tắc | Trạng thái | Ghi chú |
|---|---|---|
| I. Layered Clean Architecture | ✅ PASS | US1: SQL thuộc `Infrastructure`, property DTO thuộc `Application`, Controller không đổi. US2: chỉ sửa `presentation/pages/compliance-view-so/hooks/useComplianceColumns.jsx` — đúng lớp `presentation`, không thêm logic vào `domain`/`infrastructure`/`application`, chỉ đọc field đã có sẵn trên response. |
| II. Reference-Pattern Reuse | N/A | US1: không phải feature CRUD mới. US2: không tạo màn hình/CRUD mới — chỉ sửa 1 cấu hình cột đã tồn tại trong đúng file/hook đang dùng, không cần "nhân bản" từ feature tham chiếu nào. |
| III. Reuse Existing Backend | ✅ PASS | US1: sửa trực tiếp SP + DTO đã có. US2: KHÔNG đổi/API mới — chỉ đọc 2 field (`parentMaster`, `status`) mà endpoint `POST api/view-compliances/get-all` đã trả về sẵn từ US1, đúng tinh thần "frontend bind vào endpoint đã có". |
| IV. Vietnamese Comments; Localizable UI Labels | ✅ PASS | US1: comment SQL mới viết tiếng Việt. US2: 2 nhãn UI mới ("Parent master", "Use parent") viết tiếng Anh, khớp ngôn ngữ các nhãn khác đã có sẵn trong đúng cột/tab đang sửa ("Master code", "Missing", "Already have new version") — nhất quán với quy ước hiện tại của phần UI này, không phải ngoại lệ mới. |
| V. Routing & Menu Registration | N/A | Không có route/màn hình/menu mới ở cả 2 phần — US2 chỉ thêm 1 cột vào tab đã tồn tại trên màn hình `compliance-view-so` đã được route/menu hóa từ trước. |

Không có vi phạm cần biện minh trong Complexity Tracking.

**Re-check sau Phase 1 design (US1)**: `data-model.md`/`contracts/`/`quickstart.md` xác nhận đúng
phạm vi 2 file sửa nêu ở Technical Context — không phát sinh entity/endpoint/route mới nào. Bảng
Constitution Check trên vẫn đúng, không cần cập nhật.

**Re-check sau Phase 1 design (US2, 2026-08-10)**: `data-model.md`/`quickstart.md` bổ sung mục US2
xác nhận đúng phạm vi 1 file sửa (`useComplianceColumns.jsx`) nêu ở Technical Context — không có
component/hook/file mới, không đổi `AlertProgressCell.jsx` dùng chung. Bảng Constitution Check trên
vẫn đúng, không cần cập nhật.

## Project Structure

### Documentation (this feature)

```text
specs/010-compl-all-compliances-parent-master/
├── plan.md              # File này
├── spec.md              # Đặc tả
├── research.md          # Phase 0
├── data-model.md         # Phase 1
├── quickstart.md         # Phase 1
├── contracts/
│   └── view-compliances-get-all.md
└── checklists/
    └── requirements.md
```

### Source Code (repository root)

**Backend (US1) — CHỈ SỬA FILE ĐÃ TỒN TẠI, không có file mới**:

```text
compliance-sys-api/src/
├── ComplianceSys.Infrastructure/Sqls/Procedures/sp_load_compl_by_conditions.sql   # MODIFY
│   # STEP 20 (khối SELECT tạo tmp_result, quanh dòng 843-868): thêm '' AS ParentMaster
│   #   ngay sau MasterCode trong danh sách cột outer SELECT.
│   # STEP 20b (từ dòng 983): đổi câu DELETE (dòng 1042-1049) thành UPDATE cùng điều kiện
│   #   JOIN, SET ParentMaster = rm.RootMasterCode, Status = 'UseParent'.
└── ComplianceSys.Application/Dtos/Response/ViewCompliancesResponseDto.cs          # MODIFY
    # Thêm `public string? ParentMaster { get; set; }` ngay sau property `MasterCode`
    #   (dòng 31) để Dapper map cột mới từ kết quả CALL sp_load_compl_by_conditions.
```

**Frontend (US2, mới) — CHỈ SỬA FILE ĐÃ TỒN TẠI, không có file mới**:

```text
compliance-client/src/presentation/pages/compliance-view-so/hooks/
└── useComplianceColumns.jsx                                                       # MODIFY
    # 1. Thêm cột mới ngay sau cột "masterCode" (dòng 44-88 hiện tại):
    #    { field: "parentMaster", headerName: "Parent master", width: 118 }
    #    và thêm `parentMaster: true` vào defaultColumnVisibility (dòng 24-40).
    # 2. Cột "progress"/"Expiry warning" (dòng 301-319 hiện tại): thêm nhánh
    #    `params.row.status === "UseParent"` → render "Use parent", đặt SAU nhánh
    #    `replacedById !== null` hiện có (giữ độ ưu tiên "Already have new version") và
    #    TRƯỚC lệnh gọi <AlertProgressCell />. KHÔNG sửa AlertProgressCell.jsx (dùng
    #    chung ở 7 nơi khác — xem research.md R8).
    # 3. Dời chỉ số `columns.splice(2, 0, {field: "actions", ...})` (dòng 350 hiện tại)
    #    sang `columns.splice(3, 0, ...)` — vì cột mới ở bước 1 chèn vào vị trí 1, đẩy
    #    "masterName" từ vị trí 1 sang 2; giữ splice ở 2 sẽ làm "actions" lọt vào GIỮA
    #    "parentMaster" và "masterName" thay vì đúng vị trí hiện tại (ngay sau
    #    "masterName") — xem data-model.md mục "Thứ tự cột (US2)".
```

Không có thay đổi ở `ComplianceSys.Domain`, `ComplianceSys.Api`, hay các layer
`domain/infrastructure/application` của `compliance-client` — US2 chỉ đọc field đã có sẵn trên
response JSON, không cần route/DI/use case mới (Nguyên tắc III, V).

**Structure Decision**: Sửa gap trên 1 endpoint đã tồn tại (US1, backend-only, đã hoàn thành) +
sửa gap trên 1 tab UI đã tồn tại (US2, frontend-only, 1 file). Không áp dụng cấu trúc "web
application frontend+backend" hay bất kỳ Option nào trong khung mẫu — cả 2 story chỉ mở rộng
dữ liệu/hiển thị của 1 endpoint/1 tab có sẵn, không thêm layer/module/route mới.

## Complexity Tracking

Không có vi phạm hiến pháp cần biện minh.
