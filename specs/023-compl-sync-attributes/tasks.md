# Tasks: Compl Sync Attributes

**Input**: `specs/023-compl-sync-attributes/` (plan.md, spec.md, data-model.md, contracts/, research.md)
Đường dẫn gốc: `compliance-sys-api/` (viết tắt `API/` = `compliance-sys-api/src/`).

## Phase 1: Setup

- [X] T001 Tạo migration `API/ComplianceSys.Infrastructure/Sqls/Migration/38_create_compl_attributes_combine.sql` (CREATE TABLE IF NOT EXISTS, cột theo data-model.md, index trên ItemId, kèm comment tiếng Việt) và bản tham chiếu `API/ComplianceSys.Infrastructure/Sqls/Tables/compl_attributes_combine.sql`

## Phase 2: Foundational

- [X] T002 [P] Tạo entity `API/ComplianceSys.Domain/Entities/ComplAttributesCombine.cs` (`[Table("compl_attributes_combine")]`, theo mẫu ComplSyncVariantAttributes)
- [X] T003 [P] Tạo DTO `API/ComplianceSys.Application/Dtos/Response/ComplSyncAttributesSummaryDto.cs` (Fetched, Added, Skipped, Success, Message)
- [X] T004 [P] Tạo `API/ComplianceSys.Application/Interfaces/Repositories/IComplAttributesCombineRepository.cs` (DeleteAllAsync, InsertManyAsync)
- [X] T005 Tạo `API/ComplianceSys.Infrastructure/Repositories/ComplAttributesCombineRepository.cs` và đăng ký trong `API/ComplianceSys.Infrastructure/DependencyInjection.cs`
- [X] T006 [P] Tạo `API/ComplianceSys.Application/Interfaces/Services/IComplSyncAttributesService.cs` (`RunAsync(CancellationToken)`)

## Phase 3: User Story 1 - Đồng bộ tổ hợp thuộc tính (P1) 🎯 MVP

**Independent Test**: gọi endpoint với dữ liệu mẫu, bảng có đúng giá trị 6 thuộc tính.

- [X] T007 [US1] Tạo `API/ComplianceSys.Application/Services/ComplSyncAttributesService.cs`: đọc phân trang `RSVNAttributeRuleGroupCombines` (top 1000), parse AttributeKey (`&`→`;` lấy phần cuối→`:` lần đầu), map ItemRelation→ItemId, CreatedBy="compl-sync-attributes", CreatedDate=UtcNow, trả summary
- [X] T008 [US1] Đăng ký service trong `API/ComplianceSys.Application/DependencyInjection.cs`
- [X] T009 [US1] Thêm action `GET test-compl-sync-attributes` vào `API/ComplianceSys.Api/Controllers/ComplSynchronizeDataController.cs` (inject IComplSyncAttributesService, trả `ApiResponse<ComplSyncAttributesSummaryDto>`)
- [X] T010 [US1] Unit test parse hợp lệ + ánh xạ cột trong `compliance-sys-api/tests/ComplianceSysApi.UnitTests/Services/ComplSyncAttributesServiceTests.cs`

## Phase 4: User Story 2 - Chạy lại không trùng (P2)

**Independent Test**: chạy 2 lần cùng nguồn, số dòng bằng nhau.

- [X] T011 [US2] Trong service: chỉ sau khi fetch+parse thành công mới DeleteAll rồi insert; loại trùng theo (ItemId, Type, Name, Option) trước khi chèn
- [X] T012 [US2] Unit test: dữ liệu nguồn trùng chỉ tạo 1 dòng; lỗi fetch D365 không gọi DeleteAll

## Phase 5: User Story 3 - Bỏ qua dữ liệu sai (P3)

**Independent Test**: nguồn gồm 1 hợp lệ + 1 hỏng → lưu 1, skipped 1.

- [X] T013 [US3] Trong parser: bỏ qua + đếm khi ItemRelation rỗng/>50, AttributeKey rỗng, số phần ≠3, thiếu `:`, mã không phải số; cắt text về 100; lỗi insert từng dòng chỉ log và đếm skipped
- [X] T014 [US3] Unit test các trường hợp sai định dạng trong `ComplSyncAttributesServiceTests.cs`

## Phase 6: Polish

- [X] T015 `dotnet build` và `dotnet test --filter ComplSyncAttributes` cho compliance-sys-api; sửa lỗi nếu có

## Dependencies

T001 → độc lập; Phase 2 trước Phase 3; US2/US3 chỉnh sửa cùng service nên chạy sau US1. MVP = Phase 1–3.

## Update 1 — Product attribute: ẩn cột RecId + tab "Compliances detail - <Attribute name>"

Đường dẫn: `API` = `compliance-sys-api/src`, `CLI` = `compliance-client/src`. Tests chỉ cho logic dựng request (có sẵn xUnit trong dự án).

## Phase 7: User Story 4 - Ẩn cột RecId (P2)

**Goal**: lưới ref-type=7 không còn cột Attribute Value RecId. **Independent test**: mở `/compliance-view?ref-type=7`, không thấy cột; click dòng vẫn mở chi tiết.

- [X] T016 [P] [US4] Trong `CLI/presentation/pages/compliance-view/hooks/useAllCompliancesColumnsAttribute.jsx`: bỏ cột `attributeValueRecId` khỏi `columns` và `defaultColumnVisibility` (RecId vẫn lấy từ `row` khi điều hướng ở `index_new.jsx`; giữ `getRowUniqueId`)
- [X] T017 [US4] Trong `CLI/presentation/pages/compliance-view/index_new.jsx` (case 7, ~dòng 657): thêm `attr-type=<row.attributeTypeName>` vào URL chi tiết (mở rộng `buildComplianceDetailUrl` ~dòng 223); kiểm tra `handleSearch` ở `index.jsx` không còn phụ thuộc cột bị ẩn

## Phase 8: User Story 5 - Tab "Compliances detail - <Attribute name>" (P1)

**Goal**: tab mới hiển thị compliance theo các tổ hợp combine. **Independent test**: `POST /api/view-compliances/get-by-attribute-combine?attributeValueRecId=…` trả đúng danh sách; tab hiện cùng cột với tab 0.

- [X] T018 [P] [US5] `API/ComplianceSys.Application/Interfaces/Repositories/IComplAttributesCombineRepository.cs` + `API/ComplianceSys.Infrastructure/Repositories/ComplAttributesCombineRepository.cs`: thêm `GetByAttributeValueAsync(long recId)` (`WHERE UpholsteryType=@v OR UpholsteryName=@v OR UpholsteryOption=@v`)
- [X] T019 [US5] `API/ComplianceSys.Application/Interfaces/Services/IViewCompliancesService.cs` + `Services/ViewCompliancesService.cs`: thêm `GetViewCompliancesByAttributeCombineAsync(long recId, DateTime? checkDate)`: lấy combine (T018) → dựng `ViewCompliancesRequest` khử trùng (`Product=ItemId`, `Attribute=Type|Name|Option`) → gọi `GetViewCompliancesForSoDetailAsync` → `DistinctBy` theo compliance; rỗng → danh sách rỗng. Comment tiếng Việt; một hàm static nội bộ dựng request để test
- [X] T020 [US5] `API/ComplianceSys.Api/Controllers/ViewCompliancesController.cs`: thêm `POST get-by-attribute-combine` (`[Authorize(Policy="AllCompliance.ReadAll")]`, recId ≤ 0 → 400, lỗi → 500) theo contracts/get-by-attribute-combine.md
- [X] T021 [P] [US5] Unit test `API/../tests/ComplianceSysApi.UnitTests/Services/ViewCompliancesByAttributeCombineTests.cs`: OR giữa 4 giá trị, khử trùng, combine rỗng → rỗng, không gọi SP khi rỗng
- [X] T022 [P] [US5] Client 4 lớp: `CLI/infrastructure/api/allCompliancesApi.js` (`getViewCompliancesByAttributeCombine`), `CLI/infrastructure/repositories/RestAllCompliancesRepository.js`, `CLI/domain/interfaces/IAllCompliancesRepository.js`, `CLI/application/usecases/all-compliances/index.js` (`GetViewCompliancesByAttributeCombineUseCase`)
- [X] T023 [US5] Hook `CLI/presentation/pages/compliance-view-so/hooks/useAttributeCombineCompliancesData.js` (loading/error/data như `useViewCompliancesData`, chỉ gọi khi refType=7 và tab được mở)
- [X] T024 [US5] `CLI/presentation/pages/compliance-view-so/index.jsx`: khi `refType==="7"` thêm tab thứ 3 nhãn `Compliances detail - ${attr-type}` (dự phòng "Compliances detail"); tái dùng `columns`/DataGrid của tab 0 với dữ liệu T023; "No data" khi rỗng; không thêm tab cho ref-type khác (lưu ý chỉ số tab 2 đang dùng cho `SalesOrderInfoTab`)

## Phase 9: Polish Update 1

- [X] T025 `dotnet test --filter "ViewCompliancesByAttributeCombine|ComplSyncAttributes"` pass (14/14); client `eslint` 0 errors + `vite build` OK. **NOT run — requires live env**: kiểm tra thủ công quickstart Update 1 và SC-006/SC-007 (cần DB có dữ liệu combine + D365); rủi ro R8 (master chỉ có điều kiện Attribute khớp request đơn trường) chưa kiểm với SP thật

**Dependencies (Update 1)**: T016,T017 độc lập với Phase 8; T018 → T019 → T020; T021 sau T019; T022 → T023 → T024 (T024 cần T020 để chạy thật). MVP = Phase 8; US4 nhỏ, làm song song.

## Update 2 — Accordion theo tổ hợp + Group

## Phase 10: User Story 6 (P1)

- [X] T026 [US6] `API/ComplianceSys.Application/Dtos/Response/AttributeCombineGroupDto.cs` (mới); trong `IViewCompliancesService.cs` + `ViewCompliancesService.cs` thay `GetViewCompliancesByAttributeCombineAsync` bằng `GetAttributeCombineGroupsAsync(long recId)`: nhóm Group từ `RSVNAttributeTypeValueAlls` (D365 lỗi → bỏ qua + log) rồi nhóm tổ hợp từ combine (payload đơn trường)
- [X] T027 [US6] `ViewCompliancesController.cs`: thay endpoint `get-by-attribute-combine` bằng `get-attribute-combine-groups`
- [X] T028 [P] [US6] Cập nhật `ViewCompliancesByAttributeCombineTests.cs` cho dựng payload nhóm (tổ hợp + Group, khử trùng, GroupValue rỗng)
- [X] T029 [US6] Client: đổi `getViewCompliancesByAttributeCombine` → `getAttributeCombineGroups` (api, repository, interface, usecase, hook `useAttributeCombineCompliancesData.js`)
- [X] T030 [US6] `ProductRowCompliances.jsx`: prop tùy chọn `payload` + `downloadName`; mới `AttributeCombineGroupsTab.jsx` (accordion lazy, "Group: …" trước); `compliance-view-so/index.jsx` tab 2 render accordion thay grid, gỡ phần gridRows Update 1
- [X] T031 `dotnet test` (ViewCompliancesByAttributeCombine + ComplSyncAttributes) 15/15 pass; client `eslint` (các file đã sửa) 0 errors + `vite build` OK. **NOT run — requires live env**: kiểm tra thủ công quickstart Update 2 (nhóm "Group: …" từ D365, mở nhóm, SC-008/SC-009) và rủi ro R8 (SP khớp request đơn trường) / payload `{AttributeGroup}` với SP thật

## Update 3 — Tab chính ref-type 7 cùng nguồn với tab detail

- [X] T032 `API/ComplianceSys.Application/Services/ViewCompliancesService.cs`: nhánh ATTRIBUTE của `GetViewCompliancesAsync` dùng `GetAttributeCombineGroupsAsync` → `MergeGroupPayloads` → một lần gọi SP → `DistinctComplianceRows`; test trong `ViewCompliancesByAttributeCombineTests.cs`
- [X] T033 `CLI/presentation/pages/compliance-view-so/index.jsx`: nhãn tab đầu "Compliances of attribute - <Name> (N)" cho ref-type 7
- [X] T034 `dotnet test` 17/17 pass; client eslint 0 errors + `vite build` OK. **NOT run — requires live env**: đối chiếu thực tế SC-010 (tab đầu = hợp các nhóm của tab detail)

## Update 4 — Tab Attribute group (ref-type 12)

- [X] T035 `API/ComplianceSys.Application/Services/ViewCompliancesService.cs`: nhánh ATTRIBUTE_GROUP của `GetViewCompliancesAsync` → `GetFromDynamics<RSVNAttributeTypeValueAlls>` (GroupValue) → `BuildRequestsFromAttributeGroup` ({Attribute=recId} + {AttributeGroup}) → một lần gọi SP → `DistinctComplianceRows`; 2 test mới
- [X] T036 `dotnet test` 19/19 pass. **NOT run — requires live env**: thử thực tế `compliance-view?ref-type=12` (double click Group, đối chiếu thành viên D365 và compliance); không đổi client

## Update 5 — Tab Attribute group + tab detail

- [X] T037 `API`: repo `GetByAttributeTypesAsync` (UpholsteryType IN recIds); service `GetAttributeGroupGroupsAsync` (nhóm "Group: …" + nhóm theo dòng combine), nhánh ref-type 12 của `GetViewCompliancesAsync` dùng chung nguồn (gộp phẳng); endpoint `POST get-attribute-group-groups`; test dịch vụ + builder
- [X] T038 `CLI`: api/repository/interface/usecase `getAttributeGroupGroups`, hook `useAttributeCombineCompliancesData(recId, groupValue)`, `compliance-view-so/index.jsx` thêm tab "Compliances detail - <Group name>" cho ref-type 12 (tái dùng `AttributeCombineGroupsTab`)
- [X] T039 `dotnet test` 20/20 pass; client eslint 0 errors + `vite build` OK. **NOT run — requires live env**: thử `compliance-view?ref-type=12` thực tế (double click Group, tab detail, đối chiếu SC-012)

## Update 6 — Tự đồng bộ khi mở tab

- [X] T040 `API`: repo `GetAnyCreatedDateAsync` (1 dòng, LIMIT 1); `IComplSyncAttributesService`/`ComplSyncAttributesService`: `EvaluateFreshness` (ngưỡng 6h), `EnqueueIfStaleAsync` (Hangfire, chặn enqueue lặp), `RunInBackgroundAsync` (DisableConcurrentExecution, AutomaticRetry=0); endpoint `POST api/compl-synchronize-data/ensure-compl-attributes-combine`; test (ngưỡng, fresh không kích hoạt)
- [X] T041 `CLI`: api/repository/interface/usecase `ensureComplAttributesCombine`; `compliance-view/index_new.jsx` effect theo `referenceTypeFilter` ∈ {7, 12} gọi một lần (fire-and-forget, bỏ qua lỗi)
- [X] T042 `dotnet test` 25/25 pass; client eslint 0 errors + `vite build` OK. **NOT run — requires live env**: nhánh "stale/empty" thật sự enqueue Hangfire và job chạy xong (cần Hangfire + D365); test chỉ phủ phần đánh giá độ mới và nhánh "fresh"

## Update 7 — Xóa trước khi đồng bộ

- [X] T043 `API/ComplianceSys.Application/Services/ComplSyncAttributesService.cs`: `RunAsync` gọi `DeleteAllAsync` ngay đầu (trước khi đọc D365), bỏ lệnh xóa sau parse; test `RunAsync_DeletesAllExistingDataBeforeFetching` thay test cũ `FetchFails_DoesNotDeleteExistingData`
- [X] T044 `dotnet test` pass. **NOT run — requires live env**: đồng bộ thật với D365
