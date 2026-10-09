# Implementation Plan: Compl Sync Attributes

**Branch**: `023-compl-sync-attributes` | **Date**: 2026-10-09 | **Spec**: [spec.md](spec.md)

## Summary

Thêm một service đồng bộ (`ComplSyncAttributesService`) trong nhóm ComplSynchronizeData, đọc toàn bộ `RSVNAttributeRuleGroupCombines` từ D365, tách `AttributeKey` (`&` → `;` → `:`) thành 3 cặp (mã, text) và lưu vào bảng mới `compl_attributes_combine`. Endpoint kiểm thử `GET api/compl-synchronize-data/test-compl-sync-attributes` trên `ComplSynchronizeDataController`. Theo mẫu feature 013 (`compl_sync_variant_attributes`).

## Technical Context

**Language/Version**: C# / .NET (compliance-sys-api)
**Primary Dependencies**: Dapper (qua `DapperRepository`), `IDynamicService` + `DynamicsParameterManager` (D365 OData), Newtonsoft.Json, Serilog
**Storage**: MySQL — bảng mới `compl_attributes_combine`
**Testing**: xUnit (`tests/ComplianceSysApi.UnitTests/Services`)
**Target Platform**: Linux server (web API)
**Project Type**: web-service (backend only)
**Performance Goals**: xử lý toàn bộ tập tổ hợp trong một lần gọi; phân trang D365 1000 bản ghi/trang
**Constraints**: lỗi lấy D365 không được làm mất dữ liệu cũ; bản ghi sai định dạng chỉ bị bỏ qua
**Scale/Scope**: 1 service, 1 repository, 1 entity, 1 DTO, 1 endpoint, 1 migration

## Constitution Check

- I. Layered Clean Architecture: Controller mỏng → Application service → Repository (Infrastructure). PASS.
- II. Reference-Pattern Reuse: sao chép cấu trúc feature 013. PASS.
- III. Reuse Existing Backend: thêm mới, không viết lại code cũ; chỉ thêm 1 action vào controller hiện có. PASS.
- IV. Comments tiếng Việt: áp dụng. PASS.
- V. Routing/Menu: không có màn hình client. N/A.

Re-check sau thiết kế: không vi phạm.

## Project Structure

```text
specs/023-compl-sync-attributes/
├── plan.md, research.md, data-model.md, quickstart.md, tasks.md
└── contracts/test-compl-sync-attributes.md

compliance-sys-api/src/
├── ComplianceSys.Api/Controllers/ComplSynchronizeDataController.cs        (thêm action)
├── ComplianceSys.Application/
│   ├── Dtos/Response/ComplSyncAttributesSummaryDto.cs                     (mới)
│   ├── Interfaces/Services/IComplSyncAttributesService.cs                 (mới)
│   ├── Interfaces/Repositories/IComplAttributesCombineRepository.cs       (mới)
│   ├── Services/ComplSyncAttributesService.cs                             (mới)
│   └── DependencyInjection.cs                                             (đăng ký service)
├── ComplianceSys.Domain/Entities/ComplAttributesCombine.cs                (mới)
└── ComplianceSys.Infrastructure/
    ├── Repositories/ComplAttributesCombineRepository.cs                   (mới)
    ├── DependencyInjection.cs                                             (đăng ký repo)
    └── Sqls/{Tables/compl_attributes_combine.sql, Migration/38_create_compl_attributes_combine.sql}
compliance-sys-api/tests/ComplianceSysApi.UnitTests/Services/ComplSyncAttributesServiceTests.cs
```

**Structure Decision**: backend-only theo layer hiện có; parse AttributeKey đặt ở hàm tĩnh nội bộ của service để unit test được.

## Update 1 — Product attribute: ẩn cột RecId + tab "Compliances detail - <Attribute name>"

**Summary**: (1) Ẩn cột `attributeValueRecId` ở lưới ref-type=7. (2) Backend thêm endpoint đọc `compl_attributes_combine` theo RecId (Type/Name/Option = RecId), dựng danh sách `ViewCompliancesRequest` từ (ItemId, Type, Name, Option) rồi gọi lại `IViewCompliancesService.GetViewCompliancesForSoDetailAsync` (cùng SP `sp_load_compl_by_conditions`, cùng DTO `ViewCompliancesResponseDto` với tab 0 → cùng bố cục cột). (3) Trang chi tiết `compliance-view-so` ref-type=7 thêm tab thứ 3 tái dùng lưới của tab 0.

**Technical Context (Update 1)**: Backend C#/.NET, Dapper, MySQL (đọc `compl_attributes_combine`; không đổi schema, không cần migration). Frontend React/Vite + MUI DataGrid, theo 4 lớp domain/infrastructure/application/presentation. Performance: SC-007 ≤ 5 s với 1.000 tổ hợp → khử trùng giá trị đầu vào trước khi gọi SP, một lần gọi SP duy nhất. Scale: 1 repo method, 1 service method, 1 endpoint, ~5 file client.

**Constitution Check (Update 1)**: I (layered): controller mỏng → service → repository; client đủ 4 lớp — PASS. II/III (reuse): tái dùng SP, DTO, service method và lưới của tab 0, chỉ thêm phần thiếu — PASS. IV: comment tiếng Việt, nhãn UI tiếng Anh theo yêu cầu "Compliances detail - …" (đã nêu trong spec) — PASS. V: không thêm route/menu mới (tab nằm trong trang đã đăng ký) — PASS. Re-check sau thiết kế: không vi phạm.

**Files (Update 1)**:
```text
compliance-sys-api/src/
├── ComplianceSys.Api/Controllers/ViewCompliancesController.cs          (thêm POST get-by-attribute-combine, policy AllCompliance.ReadAll)
├── ComplianceSys.Application/Interfaces/Services/IViewCompliancesService.cs + Services/ViewCompliancesService.cs  (thêm GetViewCompliancesByAttributeCombineAsync)
├── ComplianceSys.Application/Interfaces/Repositories/IComplAttributesCombineRepository.cs  (thêm GetByAttributeValueAsync)
└── ComplianceSys.Infrastructure/Repositories/ComplAttributesCombineRepository.cs
compliance-sys-api/tests/.../Services/ViewCompliancesByAttributeCombineTests.cs   (dựng request: OR, khử trùng, rỗng)
compliance-client/src/
├── presentation/pages/compliance-view/hooks/useAllCompliancesColumnsAttribute.jsx  (ẩn cột RecId)
├── presentation/pages/compliance-view-so/index.jsx                      (tab "Compliances detail - <Attribute name>" khi refType=7)
├── presentation/pages/compliance-view-so/hooks/useViewCompliancesData.js hoặc hook mới useAttributeCombineCompliancesData.js
├── infrastructure/api/allCompliancesApi.js, infrastructure/repositories/RestAllCompliancesRepository.js, domain/interfaces/IAllCompliancesRepository.js
└── application/usecases/all-compliances/index.js                        (GetViewCompliancesByAttributeCombineUseCase)
```
`<Attribute name>`: URL chi tiết hiện chỉ mang `obj-display=<RecId>-<Value name>`; cần thêm tham số `attr-type` (Attribute Value Name) khi điều hướng ở `compliance-view/index_new.jsx` case 7.

## Update 2 — Accordion theo tổ hợp + nhóm Group

**Summary**: Endpoint `get-by-attribute-combine` (Update 1, danh sách phẳng) được THAY bằng `POST api/view-compliances/get-attribute-combine-groups?attributeValueRecId=` trả danh sách nhóm nhẹ `{kind, title, itemId, typeText, nameText, optionText, groupValue, payload:[ViewCompliancesRequest]}` (không có compliance). Client dùng accordion; mở nhóm → gọi lại `get-for-so-detail` với `payload` của nhóm (cùng cơ chế `ProductRowCompliances`, thêm prop `payload` dựng sẵn). Nhóm Group: `IComplDynamicsService.GetFromDynamics<RSVNAttributeTypeValueAlls>` (AttributeValueRecId) → GroupValue → payload `{AttributeGroup=GroupValue}`. Nhóm tổ hợp: payload `{Product=ItemId}`, `{Attribute=Type|Name|Option}` (đơn trường, OR). Không đổi DB.
**Constitution Check (Update 2)**: I (controller→service→repo; client 4 lớp), II/III (tái dùng SP, service method, ProductRowCompliances), IV (comment tiếng Việt), V (không route mới) — PASS.
**Files**: API: `ViewCompliancesController.cs`, `IViewCompliancesService.cs`/`ViewCompliancesService.cs` (thay `GetViewCompliancesByAttributeCombineAsync` bằng `GetAttributeCombineGroupsAsync`), `Dtos/Response/AttributeCombineGroupDto.cs` (mới), test. Client: `ProductRowCompliances.jsx` (prop `payload`, `downloadName`), `components/AttributeCombineGroupsTab.jsx` (mới), hook/usecase/api/repo đổi sang `getAttributeCombineGroups`, `compliance-view-so/index.jsx` (tab 2 render accordion thay grid).
