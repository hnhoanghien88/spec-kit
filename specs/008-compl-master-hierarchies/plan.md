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

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Nguyên tắc | Trạng thái | Ghi chú |
|---|---|---|
| I. Layered Clean Architecture | ✅ PASS | Backend: `ComplMasterHierarchy` (Domain) → DTOs/Service (Application) → Controller (Api); Infrastructure = `ComplMasterHierarchyRepository : DapperRepository<,>` (generic, không cần stored procedure — xem research.md mục 7). Frontend đủ 4 lớp: `domain/` (entity + interface) → `infrastructure/` (api client + repository) → `application/usecases/` (1 file/thao tác) → `presentation/` (page + hooks + components). |
| II. Reference-Pattern Reuse | ✅ PASS | Backend clone `EutrReferenceTypeDetails` (`006`, bảng nhỏ + generic repo + vài method tuỳ biến) thay vì `ComplMaster` (proc phức tạp, không cùng hình dạng). Frontend UI clone `TemplateBuilderPage.jsx`; popup clone `BulkAddStepsDialog.jsx` nhưng nối vào API/use case/component đã có của `compliance-master` (xem research.md mục 1, 6). Ô search trong popup (FR-025-027) clone y nguyên pattern search đã có ở `compliance-master/index.jsx` (`handleSearch` → filter `{column:"searchText",operator:"like",value}`, xem research.md mục 10). Kéo-thả (User Story 5) clone gần như NGUYÊN VẸN hạ tầng `@dnd-kit` của `TemplateBuilderPage.jsx` (sensors, `SortableContext` theo từng nhóm anh em, VÀ giữ nguyên guard clause bỏ qua thả khác cha) — điểm khác biệt có chủ đích duy nhất là đổi từ "sửa state rồi Save" sang "persist ngay mỗi lần thả" cho khớp FR-017/024 (xem research.md mục 9). |
| III. Reuse Existing Backend | ⚠️ N/A (có ghi chú), một phần PASS | `compl_master_hierarchies` chưa tồn tại → bắt buộc tạo mới backend (greenfield, không vi phạm — nguyên tắc chỉ áp dụng khi backend đã tồn tại). Ngược lại, phần "chọn master"/"xem condition"/"search Code-Name" ĐÃ tồn tại và được tái sử dụng nguyên trạng 100% — không sửa `ComplMasterController`, không thêm API/tham số stored-procedure mới cho việc này (đúng tinh thần Nguyên tắc III, xem research.md mục 10). |
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
├── ComplianceSys.Infrastructure/Sqls/Tables/compl_master_hierarchies.sql          # NEW (auto-load cho fresh install)
└── ComplianceSys.Infrastructure/Sqls/Migration/16_create_compl_master_hierarchies.sql  # NEW (áp dụng thủ công cho DB đã tồn tại)
```

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
│   ├── ComplMasterHierarchiesPage.jsx                                    # NEW — mẫu TemplateBuilderPage.jsx: toolbar (Add root/Add child/↑/↓/Delete/Expand all/Collapse all/Back) + @mui/x-tree-view + kéo-thả (@dnd-kit, clone gần như nguyên vẹn TemplateBuilderPage.jsx kể cả guard-clause bỏ qua thả khác cha; chỉ khác ở persist ngay mỗi lần thả — xem research.md mục 9)
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
