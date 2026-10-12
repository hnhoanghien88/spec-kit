# Tasks: Compl Detail Attribute Search

**Input**: `specs/024-compl-detail-attr-search/` (plan.md, spec.md, research.md, data-model.md, contracts/)
**Paths**: `API` = `compliance-sys-api/src`, `FE` = `compliance-client/src`

## Phase 1: Setup

- [X] T001 Xác nhận số migration tiếp theo là 39 trong `API/ComplianceSys.Infrastructure/Sqls/Migration/` và đọc `Sqls/Procedures/compl_sp_get_compl_compliances_paging.sql` + `_paging_count.sql`

## Phase 2: Foundational (chặn các story)

- [X] T002 Thêm tham số `p_pair_filter LONGTEXT` (cuối danh sách) và điều kiện lọc cặp `(cm.Id, cd.Id)` bằng `JSON_TABLE` (NULL = bỏ qua) vào `Sqls/Procedures/compl_sp_get_compl_compliances_paging.sql` và `compl_sp_get_compl_compliances_paging_count.sql`
- [X] T003 Trong SP paging thêm cột `AttributeConditionsJson` (JSON_ARRAYAGG `{refTypeId,value}` của condition ref-type 7/12 theo master) trong `Sqls/Procedures/compl_sp_get_compl_compliances_paging.sql`
- [X] T004 Tạo `Sqls/Migration/39_alter_compl_compliances_paging_attr_filter.sql` (DROP + CREATE cả hai SP, nội dung khớp T002/T003)
- [X] T005 [P] Thêm tham số `pairFilterJson` vào `GetComplDetails`/`CountGetComplDetails` trong `API/ComplianceSys.Application/Interfaces/Repositories/IComplCompliancesRepository.cs` và `API/ComplianceSys.Infrastructure/Repositories/ComplCompliancesRepository.cs` (truyền `p_pair_filter`)
- [X] T006 [P] Thêm `AttributeConditionsJson` (`[JsonIgnore]`) và `Attribute` vào `API/ComplianceSys.Application/Dtos/Response/ComplCompliancesResponseDto.cs`

## Phase 3: US1 + US2 — Tìm theo Product attribute / Attribute group (P1)

**Test độc lập**: cùng thuộc tính/Group, kết quả Compliance detail trùng tab 023.

- [X] T007 [US1] Thêm vào `IViewCompliancesService`/`ViewCompliancesService` hàm trả tập cặp `(MasterId, ComplianceId)` đã khử trùng cho (refTypeId 7|12, value), tái dùng nhánh L129-148 hiện có (không đổi hành vi `GetViewCompliancesAsync`) — `API/ComplianceSys.Application/Interfaces/Services/IViewCompliancesService.cs`, `Services/ViewCompliancesService.cs`
- [X] T008 [US1] [US2] Trong `API/ComplianceSys.Application/Services/Compliances/ComplCompliancesQueryService.cs` `GetPagedFromSpAsync`: khi refTypeId ∈ {7,12} và refTypeValue không rỗng, gọi T007, serialize cặp thành JSON và truyền `pairFilterJson` cho cả GetComplDetails và CountGetComplDetails; trường hợp khác truyền null; lỗi D365 nhánh 12 để lan ra
- [X] T009 [US1] [US2] Test xUnit trong `tests/ComplianceSysApi.UnitTests/Services/Compliances/ComplCompliancesQueryServiceTests.cs`: ref-type 7/12 truyền pairFilter đúng; ref-type khác / thiếu value truyền null; danh sách cặp rỗng → `[]`

## Phase 4: US5 — Cột Attribute (P1)

**Test độc lập**: dòng có master với condition attribute/group hiển thị "A, B"; không có thì trống.

- [X] T010 [US5] Thêm `ATTRIBUTE_GROUP` (tên = giá trị) vào `API/ComplianceSys.Application/Services/ReferenceNameResolverService.cs` nếu chưa có, hoặc dùng trực tiếp GroupValue khi làm giàu
- [X] T011 [US5] Trong `ComplCompliancesQueryService.cs` làm giàu `Attribute` cho trang kết quả: parse `AttributeConditionsJson`, resolve RecId ref-type 7 thành "Type: Value" (một lần cho cả trang), ref-type 12 dùng GroupValue, khử trùng, nối ", "; D365 lỗi → dùng mã
- [X] T012 [US5] Test xUnit cho T011 (khử trùng, thứ tự, rỗng, nhóm) trong `ComplCompliancesQueryServiceTests.cs`
- [X] T013 [P] [US5] Thêm cột `attribute` (headerName "Attribute", `sortable:false`, hiện mặc định) sau cột `name` và khóa trong `defaultColumnVisibility` ở `FE/presentation/pages/compliance-detail/hooks/useComplianceDetailColumns.jsx`

## Phase 5: US4 — Nhãn Reference Object (P2)

**Test độc lập**: ref-type 7 không còn mã trong nhãn; Search vẫn đúng.

- [X] T014 [P] [US4] Sửa `getOptionLabel` cho ref-type 7 chỉ trả `name` trong `FE/presentation/components/ReferenceObjectAutocomplete.jsx`
- [X] T015 [P] [US4] Tương tự trong `FE/presentation/components/common/ReferenceObjectAutocomplete.jsx`

## Phase 6: US3 + Polish

- [X] T016 [US3] `dotnet build` và `dotnet test` (lọc `ComplCompliancesQueryServiceTests`) cho `compliance-sys-api`; `npm run build`/lint cho `compliance-client`
- [ ] T017 Đối chiếu `quickstart.md` — NOT run: cần DB MySQL (áp migration 39) + D365 thật; chưa kiểm chứng end-to-end

## Dependencies

T001 → T002 → T003 → T004; T005, T006 sau T002; T007 độc lập; T008 sau T005+T007; T011 sau T003+T006+T010; T013, T014, T015 độc lập. MVP = Phase 2 + 3 (US1/US2), sau đó US5, US4.
