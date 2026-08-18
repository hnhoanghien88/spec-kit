# Implementation Plan: Compliance Master Hierarchies

**Branch**: `008-compl-master-hierarchies` | **Date**: 2026-07-30 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/008-compl-master-hierarchies/spec.md`

## Summary

Xây dựng màn hình quản lý **1 forest duy nhất toàn hệ thống** sắp xếp các Compliance Master
(`compl_masters`, đã có sẵn) thành cây cha-con, giao diện mô phỏng theo `eutr/templates/edit/{id}`
(`TemplateBuilderPage.jsx`). Backend **hoàn toàn mới** (bảng `compl_master_hierarchies` +
Domain/Application/Api) vì chưa có bất kỳ hỗ trợ nào tồn tại (đã xác nhận qua nghiên cứu — xem
research.md). Frontend: 1 trang mới với toolbar (Add root/Add child/move up/move down/delete/expand
all/collapse all/Back) + popup chọn master (tái sử dụng 100% API/use case/component xem-condition đã
có của `compliance-master`, chỉ viết mới UI bảng-chọn-checkbox). Không cần menu/route top-level mới —
route con tĩnh, truy cập qua 1 nút trên màn hình `compliance-master` hiện có (xem research.md mục 5).

**Update (2026-07-30 — User Story 5 / FR-022–024)**: Bổ sung kéo-thả (drag-and-drop) trực tiếp trên
cây để sắp xếp lại thứ tự anh em tới 1 vị trí bất kỳ trong 1 lần thả — tái sử dụng `@dnd-kit` (đã có
sẵn trong `package.json`, đã dùng ở `TemplateBuilderPage.jsx`) và **giữ nguyên** guard clause gốc của
`handleDragEnd` (bỏ qua/no-op nếu thả khác cha — pattern gốc của `TemplateBuilderPage.jsx`). Điểm
khác biệt duy nhất so với `TemplateBuilderPage.jsx`: **persist ngay lập tức mỗi lần thả** (khác với
`TemplateBuilderPage.jsx` chỉ lưu state cục bộ, chờ nút "Save" riêng — xem research.md mục 9). Cần 1
API mới: `PUT .../{id}/reorder` (sắp xếp lại trong cùng cha).

**Update (2026-07-30, follow-up)**: Đã BỎ tính năng "Drop here to make root"/reparent-qua-drag theo
phản hồi người dùng — kéo-thả CHỈ còn sắp xếp trong cùng cấp (cùng `ParentCode`); không còn endpoint
`/reparent`, không còn `RootDropZone.jsx`, không còn `ExistsExcludingIdAsync`. Di chuyển 1 node sang
nhánh khác/lên root vẫn phải dùng Add child/Add root + Delete như trước khi có kéo-thả.

**Update (2026-07-30, follow-up 2 — FR-025–027)**: Bổ sung 1 ô search (Code/Name) trong popup chọn
master (`MasterPickerDialog.jsx`), dùng cho cả Add root và Add child. **Không cần API/DTO/stored
procedure mới** — tái sử dụng nguyên vẹn tham số `payload` (mảng `FilterRequest{column,operator,value}`)
đã tồn tại sẵn trên API phân trang `POST /compliance-master/get-all`, gửi
`[{ column: "searchText", operator: "like", value: <text> }]` (đúng pattern đã dùng ở
`compliance-master/index.jsx`) — xem research.md mục 10.

**Update (2026-08-10 — User Story 6 / FR-028–030)**: Thêm nút "View condition" vào **mỗi dòng của
chính cây hierarchy** trên màn hình index (`ComplMasterHierarchiesPage.jsx`), không chỉ trong popup
Add root/Add child như User Story 4. **Chỉ sửa frontend, KHÔNG có API/DTO/backend mới**: tái sử dụng
nguyên vẹn `GetConditionsByMasterIdUseCase` + component `ConditionsView` đã dùng ở
`MasterPickerDialog.jsx` (US4), gắn thêm 1 `IconButton` vào `SortableMasterLabel` (component render
mỗi dòng cây), `onClick` gọi `event.stopPropagation()` trước khi mở dialog để không vô tình
select/deselect node (FR-029) — xem research.md mục 11.

**Update (2026-08-18 — bug fix, FR-011–013 mở rộng)**: 2 lỗi nghiêm trọng phát hiện khi test — (1)
`AddRootsAsync` chỉ kiểm tra trùng trong danh sách root hiện có (`ExistsAsync(code, "")`), không quét
toàn cây, nên 1 master đã là con ở nhánh nào đó vẫn được thêm làm root mới (dữ liệu trùng vị trí); (2)
`AddChildrenAsync` chỉ chặn được vòng lặp trực tiếp (ancestor-chain, FR-012) và trùng sibling
(FR-013 cũ), không chặn được trùng lặp ở 1 nhánh khác không liên quan. **Sửa**: đảo ngược thiết kế
"DAG chia sẻ nhánh" ban đầu (research.md mục 2 cũ) — áp dụng quy tắc 1 `MasterCode` chỉ tồn tại ĐÚNG 1
vị trí trong toàn bộ cây, kiểm tra 2 tầng: (a) Application layer — `AddRootsAsync`/`AddChildrenAsync`
nạp toàn bộ bảng 1 lần, so khớp với TOÀN BỘ `MasterCode` hiện có (không chỉ roots/ancestor-chain/direct
children), trả lỗi cụ thể theo từng lý do; (b) Database layer — đổi UNIQUE KEY từ ghép
`(MasterCode, ParentCode)` sang `(MasterCode)` (migration mới `21_unique_mastercode_compl_master_hierarchies.sql`),
làm chốt chặn cuối chống race-condition. Xoá `IComplMasterHierarchyRepository.ExistsAsync` (không còn
nơi nào gọi sau khi sửa `AddRootsAsync`) — xem research.md mục 12 cho quyết định đầy đủ.

**Update (2026-08-18, follow-up — sửa lại kết luận về delete confirmation)**: Lượt xử lý đầu tiên của
mục báo cáo thứ 3 (popup xác nhận xoá) kết luận SAI là "không phải bug". Người dùng xác nhận đây THỰC
SỰ là 1 gap: `handleDeleteClick` trong `ComplMasterHierarchiesPage.jsx` phải LUÔN mở `ConfirmDialog`
cho mọi lần xoá (kể cả node không có con) — trước đó code gọi `doDelete()` thẳng, bỏ qua popup, khi
`descendantCount === 0`. Đã sửa: bỏ nhánh điều kiện trong `handleDeleteClick`, luôn
`setDeleteConfirmOpen(true)`; `ConfirmDialog` render `title`/`content`/`labelConfirm` động theo
`descendantCount` — thông báo "sẽ xóa N node con" chỉ NỐI THÊM vào popup xác nhận sẵn có, không phải
điều kiện bật/tắt popup. Backend không đổi (xác nhận là hành vi UI thuần tuý). Xem research.md mục 13
cho quyết định đầy đủ và bài học rút ra.

## Technical Context

**Language/Version**: C# 12 / .NET 8 (`compliance-sys-api`); JavaScript (ES modules), React 18 + Vite
(`compliance-client`)

**Primary Dependencies**: Backend — Dapper 2.1.66 + `Res.Shared.Dapper` (generic
`IRepository<T,TKey>`/`DapperRepository<,>`/`BaseService<,,>`/`PagedResult`), MySql.Data, FluentValidation,
AutoMapper, Serilog. Frontend — React, MUI (`@mui/material`, `@mui/x-tree-view`), axios,
**`@dnd-kit/core` + `@dnd-kit/sortable` + `@dnd-kit/utilities`** (đã có sẵn trong `package.json`, đã
dùng ở `TemplateBuilderPage.jsx` — tái sử dụng, KHÔNG thêm dependency mới cho kéo-thả; xem research.md
mục 9 cho lý do mở rộng thay vì clone y nguyên). `react-beautiful-dnd` vẫn là dependency không dùng tới
(dead dependency có sẵn từ trước) — KHÔNG dùng cho feature này để tránh trộn 2 thư viện DnD.

**Storage**: MySQL qua Dapper. Bảng mới `compl_master_hierarchies` (Id, MasterCode, ParentCode,
DisplayOrder + audit) — xem `data-model.md`. Không có FK tới `compl_masters` (lý do: `Code` không tự
nó UNIQUE, xem data-model.md).

**Testing**: Kiểm thử thủ công theo `quickstart.md` (repo chưa có test tự động cho các trang CRUD
tương tự — đã xác minh không có `*.Tests.csproj` hay cấu hình Vitest/Jest); `dotnet build` +
`npm run build`/`eslint` làm gate tối thiểu.

**Target Platform**: Web (SPA qua nginx; API .NET 8)

**Project Type**: Web application (frontend + backend tách biệt trong monorepo)

**Performance Goals**: Tải toàn bộ cây trong 1 request (không phân trang cây — quy mô master data,
xem SC-003). Popup chọn master dùng lại phân trang server-side sẵn có (50 dòng/trang, FR-005/SC-006)
và ô search kèm nút Search/Clear + Enter-key (khớp `ComplianceFilterBar.jsx` đã có, xem cập nhật dưới
đây), luôn truy vấn lại trang 1 phía server (FR-025/SC-008, xem research.md
mục 10) — không lọc client-side trên trang đã tải.

**Constraints**:
- Comment code tiếng Việt (Nguyên tắc IV). **UI của riêng màn hình này bằng tiếng Anh** — spec đặt
  tên nhãn nút/cột trực tiếp bằng tiếng Anh theo đúng hình tham khảo (FR-002/FR-006), được phép theo
  Nguyên tắc IV bản 2.0.0 (xem research.md mục 8). Đây là ngoại lệ so với mặc định tiếng Việt, giống
  tiền lệ `006-eutr-reference-types` (FR-012).
- Không có phân quyền riêng cho tính năng này — mọi hành động (xem/add/reorder/delete) đều dùng
  chung policy `ComplianceMaster.ReadAll` (FR-020, xem research.md mục 4) — KHÔNG tạo policy
  `ComplMasterHierarchy.*` mới.
- Validate vòng lặp tổ tiên (FR-012) và trùng lặp (FR-011/FR-013) thực hiện ở Application layer
  (in-memory graph traversal trên toàn bộ bảng đã tải), không dùng recursive SQL CTE (xem
  research.md mục 1-2).
- **(2026-08-18)** Kiểm tra trùng lặp cho CẢ Add root LẪN Add child PHẢI quét toàn bộ
  `compl_master_hierarchies`, không chỉ danh sách root hiện có (Add root) hay ancestor-chain/con trực
  tiếp của parent (Add child) — 1 `MasterCode` chỉ được tồn tại đúng 1 vị trí trong toàn cây tại mọi
  thời điểm (đảo ngược quyết định "DAG chia sẻ nhánh" ban đầu). Backed bởi `UNIQUE KEY (MasterCode)`
  ở DB làm chốt chặn thứ 2 (xem research.md mục 12, data-model.md).
- Kéo-thả (FR-022–024) PHẢI persist ngay lập tức từng lần thả (giống mọi hành động khác của feature
  này — FR-017/024), KHÔNG dùng model "sửa state cục bộ + nút Save riêng" của `TemplateBuilderPage.jsx`
  — đây là điểm khác biệt duy nhất có chủ đích so với reference pattern gốc (xem research.md mục 9).
  `handleDragEnd` PHẢI GIỮ NGUYÊN guard clause gốc của `TemplateBuilderPage.jsx` (bỏ qua/no-op nếu
  thả khác cha, FR-023) — KHÔNG hỗ trợ reparent hay thả vào vùng root (đã bỏ theo phản hồi người
  dùng, xem research.md mục 9).
- Ô search trong popup (FR-025–027) PHẢI gửi filter qua tham số `payload` sẵn có của
  `GetPagingComplianceMasterUseCase`/`POST /compliance-master/get-all` (`{ column: "searchText",
  operator: "like", value }`) — KHÔNG thêm API/DTO/tham số stored-procedure mới, KHÔNG lọc
  client-side trên dữ liệu trang đã tải (xem research.md mục 10). Lựa chọn checkbox PHẢI được lưu ở
  1 state độc lập với dữ liệu trang hiện tại (ví dụ `Set<code>`) để không mất khi kết quả search làm
  ẩn dòng đã check (FR-026).

**Scale/Scope**: 1 màn hình + 1 popup dùng lại gần như toàn bộ hạ tầng có sẵn của `compliance-master`.
Backend: ~9 file mới (Domain/DTOs/Repository/Service/Controller/Validator, cộng 1 DTO + 1 Validator
mới cho kéo-thả: `ReorderHierarchyRequestDto`) + 2-3 file sửa (mapping profile, DI, có thể
`ValidationExceptionMiddleware` nếu chưa bắt `InvalidOperationException` → 409, cần verify tại
`/speckit-tasks` vì `006` đã từng thêm catch này — có thể đã tồn tại sẵn). Frontend: ~12 file mới
(domain/infra/usecases/presentation cho `compl-master-hierarchies`, cộng 1 use case mới
`ReorderComplMasterHierarchyUseCase.js`) + 2 file sửa (`di/repositories.js`, `MainRoutes.jsx`, và 1
nút mới trong `compliance-master/index.jsx`).

**Update (2026-08-10 — User Story 6)**: KHÔNG thêm file mới ở backend lẫn frontend cho phần domain
mới; chỉ **sửa 1 file đã có** — `ComplMasterHierarchiesPage.jsx` (cụ thể là `SortableMasterLabel`
bên trong, thêm 1 `IconButton` + import `GetConditionsByMasterIdUseCase`/`ConditionsView` đã có sẵn
từ `compliance-master`, tương tự cách `MasterPickerDialog.jsx` đã dùng cho US4).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Nguyên tắc | Trạng thái | Ghi chú |
|---|---|---|
| I. Layered Clean Architecture | ✅ PASS | Backend: `ComplMasterHierarchy` (Domain) → DTOs/Service (Application) → Controller (Api); Infrastructure = `ComplMasterHierarchyRepository : DapperRepository<,>` (generic, không cần stored procedure — xem research.md mục 7). Frontend đủ 4 lớp: `domain/` (entity + interface) → `infrastructure/` (api client + repository) → `application/usecases/` (1 file/thao tác) → `presentation/` (page + hooks + components). |
| II. Reference-Pattern Reuse | ✅ PASS | Backend clone `EutrReferenceTypeDetails` (`006`, bảng nhỏ + generic repo + vài method tuỳ biến) thay vì `ComplMaster` (proc phức tạp, không cùng hình dạng). Frontend UI clone `TemplateBuilderPage.jsx`; popup clone `BulkAddStepsDialog.jsx` nhưng nối vào API/use case/component đã có của `compliance-master` (xem research.md mục 1, 6). Ô search trong popup (FR-025-027) clone y nguyên pattern search đã có ở `compliance-master/index.jsx` (`handleSearch` → filter `{column:"searchText",operator:"like",value}`, xem research.md mục 10). Kéo-thả (User Story 5) clone gần như NGUYÊN VẸN hạ tầng `@dnd-kit` của `TemplateBuilderPage.jsx` (sensors, `SortableContext` theo từng nhóm anh em, VÀ giữ nguyên guard clause bỏ qua thả khác cha) — điểm khác biệt có chủ đích duy nhất là đổi từ "sửa state rồi Save" sang "persist ngay mỗi lần thả" cho khớp FR-017/024 (xem research.md mục 9). |
| III. Reuse Existing Backend | ⚠️ N/A (có ghi chú), một phần PASS | `compl_master_hierarchies` chưa tồn tại → bắt buộc tạo mới backend (greenfield, không vi phạm — nguyên tắc chỉ áp dụng khi backend đã tồn tại). Ngược lại, phần "chọn master"/"xem condition"/"search Code-Name" ĐÃ tồn tại và được tái sử dụng nguyên trạng 100% — không sửa `ComplMasterController`, không thêm API/tham số stored-procedure mới cho việc này (đúng tinh thần Nguyên tắc III, xem research.md mục 10). User Story 6 (2026-08-10) tiếp tục đúng tinh thần này: "View condition" trên dòng cây gọi lại y nguyên `GET /compliance-master/{id}/conditions` đã có — không thêm endpoint nào vào `ComplMasterHierarchyController` (xem research.md mục 11). |
| IV. Vietnamese Comments; Localizable UI Labels | ✅ PASS (có ngoại lệ UI) | Comment code tiếng Việt như thường lệ. UI riêng màn hình này bằng tiếng Anh, được cho phép vì spec đặt tên nhãn cụ thể theo hình tham khảo (xem Constraints ở trên). |
| V. Routing & Menu Registration | ✅ PASS (thiết kế thay thế, có ghi chú) | KHÔNG thêm menu top-level/route mới cần seed `userMenu` (ADR 0002) — vì đây là 1 forest toàn hệ thống, không phải danh sách nhiều bản ghi cha cần liệt kê ở menu. Thay bằng route con tĩnh `/compliance-master/hierarchies` trong `MainRoutes.jsx`, vào từ 1 nút trên `compliance-master/index.jsx`, tái sử dụng quyền `ComplianceMaster.ReadAll` của màn hình cha — đúng tiền lệ `ApplyCustomerPage.jsx`/`AssignStepsPage.jsx` (xem research.md mục 5). |

Không có vi phạm cần biện minh trong Complexity Tracking ngoài các ghi chú "N/A có giải thích" ở trên
(mục III) — đây là tình huống greenfield hợp lệ, không phải ngoại lệ kiến trúc.

## Project Structure

### Documentation (this feature)

```text
specs/008-compl-master-hierarchies/
├── plan.md              # File này
├── spec.md              # Đặc tả
├── research.md          # Phase 0
├── data-model.md         # Phase 1
├── quickstart.md         # Phase 1
├── contracts/
│   └── compl-master-hierarchies-api.md
└── checklists/
    └── requirements.md
```

### Source Code (repository root)

**Backend — TẤT CẢ FILE MỚI** (trừ 2 file MODIFY cuối):

```text
compliance-sys-api/src/
├── ComplianceSys.Domain/Entities/ComplMasterHierarchy.cs                # NEW
│   # [Table("compl_master_hierarchies")] : BaseEntity
│   # Id (long), MasterCode (string), ParentCode (string, default ""), DisplayOrder (int)
├── ComplianceSys.Application/
│   ├── Dtos/Response/ComplMasterHierarchyResponseDto.cs                 # NEW : ComplMasterHierarchy + Name, Description
│   ├── Dtos/Request/AddRootsRequestDto.cs                               # NEW { List<string> MasterCodes }
│   ├── Dtos/Request/AddChildrenRequestDto.cs                            # NEW { List<string> MasterCodes }
│   ├── Dtos/Request/MoveHierarchyRequestDto.cs                          # NEW { string Direction }
│   ├── Dtos/Request/ReorderHierarchyRequestDto.cs                       # NEW { int TargetIndex } — kéo-thả trong cùng cha (User Story 5)
│   ├── Dtos/Response/AddHierarchyResultDto.cs                           # NEW { List<ComplMasterHierarchyResponseDto> Added, List<RejectedHierarchyItemDto> Rejected }
│   ├── Interfaces/Repositories/IComplMasterHierarchyRepository.cs       # NEW GetAllWithMasterInfoAsync/ExistsAsync/GetMaxDisplayOrderAsync/GetSiblingsAsync/GetByIdAsync
│   ├── Interfaces/Services/IComplMasterHierarchyService.cs              # NEW GetTreeAsync/AddRootsAsync/AddChildrenAsync/MoveAsync/ReorderAsync/DeleteWithDescendantsAsync (KHÔNG có ReparentAsync — bỏ theo phản hồi người dùng)
│   ├── Services/ComplMasterHierarchyService.cs                          # NEW — chứa toàn bộ business rule (xem data-model.md "Quy tắc nghiệp vụ"), gồm ReorderAsync cho kéo-thả
│   ├── Validators/AddRootsRequestDtoValidator.cs                        # NEW
│   ├── Validators/AddChildrenRequestDtoValidator.cs                     # NEW
│   ├── Validators/MoveHierarchyRequestDtoValidator.cs                   # NEW
│   ├── Validators/ReorderHierarchyRequestDtoValidator.cs                # NEW — TargetIndex >= 0
│   ├── Mappings/CommonMappingProfile.cs                                 # MODIFY — thêm CreateMap<ComplMasterHierarchy, ComplMasterHierarchyResponseDto>() (verify tên file profile đúng tại /speckit-tasks — có thể là ComplMappingProfile.cs riêng)
│   └── DependencyInjection.cs                                           # MODIFY — đăng ký IComplMasterHierarchyService + 3 IValidator<...>
├── ComplianceSys.Infrastructure/
│   ├── Repositories/ComplMasterHierarchyRepository.cs                  # NEW : DapperRepository<ComplMasterHierarchy, long> + method tuỳ biến (Dapper inline SQL, không cần .sql riêng)
│   └── DependencyInjection.cs                                           # MODIFY — đăng ký IComplMasterHierarchyRepository
├── ComplianceSys.Api/
│   └── Controllers/ComplMasterHierarchyController.cs                    # NEW [Route("api/compl-master-hierarchies")], mọi action Policy="ComplianceMaster.ReadAll" — gồm PUT {id}/reorder cho kéo-thả (KHÔNG có /reparent)
├── ComplianceSys.Infrastructure/Sqls/Tables/compl_master_hierarchies.sql          # MODIFY (2026-08-18) — UNIQUE KEY đổi từ (MasterCode, ParentCode) sang (MasterCode)
├── ComplianceSys.Infrastructure/Sqls/Migration/16_create_compl_master_hierarchies.sql  # NEW (áp dụng thủ công cho DB đã tồn tại)
└── ComplianceSys.Infrastructure/Sqls/Migration/21_unique_mastercode_compl_master_hierarchies.sql  # NEW (2026-08-18, bug fix) — DROP INDEX uq_compl_master_hierarchy cũ, ADD UNIQUE KEY mới chỉ trên MasterCode
```

**Update (2026-08-18 — bug fix)**: `IComplMasterHierarchyRepository`/`ComplMasterHierarchyRepository`
**MODIFY** — xoá method `ExistsAsync(masterCode, parentCode)` (không còn nơi nào gọi sau khi
`AddRootsAsync` chuyển sang kiểm tra in-memory trên toàn bộ bảng, giống `AddChildrenAsync`).
`ComplMasterHierarchyService.cs` **MODIFY** — mở rộng `AddRootsAsync`/`AddChildrenAsync` theo
data-model.md mục "Quy tắc nghiệp vụ" #2-3 (bản cập nhật). Không có DTO/Controller/route mới.

**Frontend — CÁC FILE MỚI**:

```text
compliance-client/src/
├── domain/
│   ├── entities/ComplMasterHierarchyNode.js                             # NEW { id, masterCode, parentCode, displayOrder, name, description, createdBy, createdDate, updatedBy, updatedDate }
│   └── interfaces/IComplMasterHierarchyRepository.js                    # NEW getTree/addRoots/addChildren/move/remove
├── infrastructure/
│   ├── api/complMasterHierarchyApi.js                                   # NEW base "/compl-master-hierarchies": getTree (GET), addRoots (POST /roots), addChildren (POST /{parentCode}/children), move (PUT /{id}/move), remove (DELETE /{id})
│   └── repositories/RestComplMasterHierarchyRepository.js                # NEW
├── application/usecases/compl-master-hierarchies/
│   ├── GetTreeComplMasterHierarchyUseCase.js                            # NEW
│   ├── AddRootsComplMasterHierarchyUseCase.js                           # NEW
│   ├── AddChildrenComplMasterHierarchyUseCase.js                        # NEW
│   ├── MoveComplMasterHierarchyUseCase.js                                # NEW
│   ├── ReorderComplMasterHierarchyUseCase.js                             # NEW — kéo-thả trong cùng cha (User Story 5 / FR-022)
│   └── DeleteComplMasterHierarchyUseCase.js                              # NEW
├── presentation/pages/compl-master-hierarchies/
│   ├── ComplMasterHierarchiesPage.jsx                                    # NEW, rồi MODIFY (2026-08-10, User Story 6) — mẫu TemplateBuilderPage.jsx: toolbar (Add root/Add child/↑/↓/Delete/Expand all/Collapse all/Back) + @mui/x-tree-view + kéo-thả (@dnd-kit, clone gần như nguyên vẹn TemplateBuilderPage.jsx kể cả guard-clause bỏ qua thả khác cha; chỉ khác ở persist ngay mỗi lần thả — xem research.md mục 9). US6: thêm IconButton "View condition" vào `SortableMasterLabel` (mỗi dòng cây), `onClick` gọi `event.stopPropagation()` rồi mở lại `GetConditionsByMasterIdUseCase` + `ConditionsView` đã dùng ở `MasterPickerDialog.jsx` (KHÔNG file mới, KHÔNG API mới — xem research.md mục 11)
│   ├── hooks/useComplMasterHierarchyTree.js                              # NEW — mẫu useStepTree.js: loadFromServer/addRoots/addChildren/moveNode/reorderNode/removeNode, dựng cây theo masterCode (xem data-model.md "Frontend — cấu trúc cây"); reorderNode gọi use case tương ứng NGAY khi thả (không có state "dirty chờ Save")
│   ├── components/MasterPickerDialog.jsx                                 # NEW — mẫu BulkAddStepsDialog.jsx: bảng checkbox Code/Name/Description/View condition, phân trang, ô search Code/Name (nút Search/Clear + Enter-key, giống hệt `ComplianceFilterBar.jsx`/`compliance-master/index.jsx` thay vì debounce-khi-gõ — xem research.md mục 10, cập nhật khi implement), luôn reset về trang 1 khi search (FR-025-027), giữ lựa chọn qua nhiều trang/nhiều lần search (state riêng, `Map<code, master>` đã có sẵn từ US1); gọi lại NGUYÊN VẸN GetPagingComplianceMasterUseCase (với payload filter searchText)/GetConditionsByMasterIdUseCase + component ConditionsView đã có (KHÔNG tạo API/use case mới cho phần này, kể cả cho search)
│   └── utils/masterHierarchyTreeUtils.js                                 # NEW — buildTree/getDescendantIds theo khoá tự nhiên (masterCode), mẫu utils/treeUtils.js nhưng thay parentId số bằng parentCode chuỗi
├── di/repositories.js                                                    # MODIFY — thêm complMasterHierarchy: new RestComplMasterHierarchyRepository()
├── app/routes/groups/MainRoutes.jsx                                      # MODIFY — thêm lazy import ComplMasterHierarchiesPage + route { path: '/compliance-master/hierarchies', element: <ComplMasterHierarchiesPage /> } trong mảng con PrivateRoute
└── presentation/pages/compliance-master/index.jsx                        # MODIFY — thêm 1 nút (vd. "Master hierarchies") điều hướng navigate('/compliance-master/hierarchies')
```

Không cần sửa `RouteResolver.jsx`/`presentation/menu-items/ComplianceSystem.jsx`, không cần seed
`userMenu`/quyền mới trên DB (xem research.md mục 5 — Constitution Check mục V).

**Structure Decision**: Web application. Backend **full-stack mới** (greenfield cho
`compl_master_hierarchies`, không có gì để "reuse-as-is"). Frontend là 1 trang mới + 1 popup mới,
nhưng **toàn bộ phần chọn master/xem condition tái sử dụng nguyên trạng hạ tầng `compliance-master`
đã có** (không thêm API/use case nào cho việc load danh sách master hay xem condition — xem
research.md mục 6). Route con tĩnh, không menu top-level mới.

## Complexity Tracking

> Không có vi phạm hiến pháp cần biện minh (mục III Constitution Check chỉ là "không áp dụng, có giải
> thích" cho phần bảng mới — tình huống greenfield hợp lệ).
>
> **Ghi chú thứ hai**: kéo-thả (User Story 5) tái sử dụng `@dnd-kit` sẵn có và giữ nguyên guard clause
> gốc của `TemplateBuilderPage.jsx` (bỏ qua/no-op nếu thả khác cha, FR-023 — đã bỏ tính năng
> reparent-qua-drag/"Drop here to make root" theo phản hồi người dùng ngày 2026-07-30). Điểm khác
> biệt CÓ CHỦ ĐÍCH duy nhất so với `TemplateBuilderPage.jsx`: persist ngay mỗi lần thả thay vì chờ nút
> Save, để khớp FR-017/024 (xem research.md mục 9). Chỉ cần 1 API mới (`/reorder`) — KHÔNG có
> `/reparent`, KHÔNG cần tái dùng logic vòng lặp/trùng lặp cho kéo-thả (reorder trong cùng cha không
> đổi `ParentCode` nên không có rủi ro đó).
>
> **Ghi chú duy nhất đáng lưu ý**: mọi hành động ghi (add/move/delete) dùng chung policy
> `ComplianceMaster.ReadAll` thay vì tách `.Create/.Update/.Delete` như quy ước thông thường của các
> controller khác trong repo (`ComplMasterController`, `EutrTemplatesController`, ...). Đây KHÔNG
> phải sơ suất — là hệ quả trực tiếp, có chủ đích của FR-020 (đã chốt ở `/speckit-clarify`: "No
> restriction — any user who can view the Compliance Master list can also edit the hierarchy").
> `/speckit-tasks`/`/speckit-implement` KHÔNG cần thêm policy `.Create`/`.Update`/`.Delete` cho
> feature này trừ khi có yêu cầu thay đổi spec sau này.
>
> **Ghi chú thứ ba (2026-08-10, User Story 6)**: Không có vi phạm hiến pháp nào phát sinh — đây là
> thay đổi UI thuần tuý (thêm 1 icon action vào component render dòng cây đã có), tái sử dụng 100%
> use case/component đọc-condition đã tồn tại từ US4, không thêm file/endpoint/bảng mới (xem
> research.md mục 11).
>
> **Ghi chú thứ tư (2026-08-18, bug fix)**: Không có vi phạm hiến pháp nào phát sinh. Đây là sửa lỗi
> nghiệp vụ (kiểm tra trùng lặp thiếu phạm vi) trong `ComplMasterHierarchyService` đã có — không thêm
> bảng/endpoint/DTO mới, chỉ mở rộng logic 2 method hiện có (`AddRootsAsync`/`AddChildrenAsync`) và 1
> migration ALTER cho UNIQUE KEY hiện có (xem research.md mục 12). Quyết định "1 MasterCode chỉ 1 vị
> trí trong cây" đảo ngược 1 giả định trước đó (research.md mục 2 — "DAG chia sẻ nhánh") nhưng KHÔNG
> phải vi phạm hiến pháp — là sửa lỗi theo báo cáo test thực tế, đã ghi rõ trong spec.md (Clarifications
> session 2026-08-18) để tránh nhầm với 1 thay đổi scope tự phát.
>
> **Ghi chú thứ năm (2026-08-18, follow-up)**: Không có vi phạm hiến pháp nào phát sinh. Sửa lại 1 kết
> luận sai của chính phiên làm việc trước đó trong session này — mục báo cáo thứ 3 (popup xác nhận
> xoá) ban đầu bị đọc nhầm thành "không phải bug"; người dùng xác nhận đây là 1 gap thật, cần luôn hiện
> `ConfirmDialog` cho mọi lần xoá. Chỉ sửa 1 file frontend (`ComplMasterHierarchiesPage.jsx`), không
> đổi backend/API/DTO/bảng nào (xem research.md mục 13).
