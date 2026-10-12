# Implementation Plan: Compl Detail Attribute Search

**Branch**: `024-compl-detail-attr-search` | **Date**: 2026-10-12 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/024-compl-detail-attr-search/spec.md`

## Summary

Màn hình Compliance detail (`POST /compliances/get-all`) hiện lọc `refTypeValue` bằng so khớp chính xác với condition/reference của master, nên thiếu compliance gián tiếp mà tab "Compliances of attribute" (023) hiển thị. Cách làm: khi `refTypeId` ∈ {7 Product attribute, 12 Attribute group} và có `refTypeValue`, service tính tập cặp (MasterId, ComplianceId) bằng **đúng logic 023** (`ViewCompliancesService`: gộp payload nhóm + `sp_load_compl_by_conditions` + khử trùng), rồi truyền danh sách cặp (JSON) vào hai stored procedure paging/count qua tham số mới `p_pair_filter` để SP phân trang, sắp xếp, lọc searchText/dueDays như cũ. Thêm cột **Attribute** (SP trả `AttributeConditionsJson` gồm các condition ref-type 7/12 của master; service đổi RecId → "Name1: Name2"). Frontend: rút gọn nhãn Reference Object ref-type 7 và thêm cột Attribute sau cột Name.

## Technical Context

**Language/Version**: Backend C# / .NET 8; Frontend React (Vite) JavaScript; DB MySQL (stored procedures)

**Primary Dependencies**: Dapper, AutoMapper, Serilog, MUI X DataGrid, D365 OData qua `ComplDynamicsService`

**Storage**: MySQL — `compl_master_conditions`, `compl_master_condition_values`, `compl_references`, `compl_attributes_combine`; SP `compl_sp_get_compl_compliances_paging` / `_paging_count` đổi chữ ký (migration 39)

**Testing**: xUnit + Moq (`compliance-sys-api/tests/ComplianceSysApi.UnitTests`); frontend không có test runner — kiểm thủ công theo quickstart

**Target Platform**: Web (SPA + REST API)

**Project Type**: web-application (compliance-client + compliance-sys-api, hai repo git lồng nhau)

**Performance Goals**: trang đầu ≤ 5 giây với 1.000 tổ hợp (SC-003)

**Constraints**: giữ nguyên hành vi khi Reference Object trống / ref-type khác (FR-006); D365 lỗi nhánh Group phải báo lỗi rõ ràng, lỗi nhánh tổ hợp không làm mất compliance gắn trực tiếp (FR-007); mọi thay đổi SP đi kèm file migration đánh số mới

**Scale/Scope**: 2 SP, 1 service, 1 DTO, 2 component autocomplete, 1 file cột; ~1.000 tổ hợp / thuộc tính

## Constitution Check

| Nguyên tắc | Đánh giá |
|---|---|
| I. Layered Clean Architecture | PASS — logic ở Application service, SQL ở Infrastructure, controller giữ mỏng; FE sửa ở presentation |
| II. Reference-Pattern Reuse | PASS — tái dùng luồng 023 và pattern cột DataGrid hiện có |
| III. Reuse Existing Backend | PASS — mở rộng service/SP hiện có tại khoảng trống đã xác minh (không viết lại); tái dùng `ViewCompliancesService` |
| IV. Vietnamese Comments | PASS — comment tiếng Việt, nhãn cột "Attribute" theo spec |
| V. Routing & Menu | N/A — không thêm màn hình mới |

Re-check sau thiết kế: không vi phạm. Complexity Tracking: không cần.

## Project Structure

### Documentation (this feature)

```text
specs/024-compl-detail-attr-search/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/get-all-compliances.md
└── tasks.md
```

### Source Code

```text
compliance-sys-api/
├── src/ComplianceSys.Application/
│   ├── Services/Compliances/ComplCompliancesQueryService.cs   # tính cặp 023 + làm giàu cột Attribute
│   ├── Services/ViewCompliancesService.cs                     # lộ hàm tính cặp (MasterId, ComplianceId)
│   ├── Interfaces/Services/IViewCompliancesService.cs
│   ├── Interfaces/Repositories/IComplCompliancesRepository.cs # thêm tham số pairFilterJson
│   ├── Services/ReferenceNameResolverService.cs               # ATTRIBUTE_GROUP => tên = giá trị
│   └── Dtos/Response/ComplCompliancesResponseDto.cs           # thêm Attribute
├── src/ComplianceSys.Infrastructure/
│   ├── Repositories/ComplCompliancesRepository.cs
│   └── Sqls/{Procedures/compl_sp_get_compl_compliances_paging*.sql, Migration/39_*.sql}
└── tests/ComplianceSysApi.UnitTests/Services/Compliances/ComplCompliancesQueryServiceTests.cs

compliance-client/src/presentation/
├── components/ReferenceObjectAutocomplete.jsx                 # nhãn ref-type 7
├── components/common/ReferenceObjectAutocomplete.jsx
└── pages/compliance-detail/hooks/useComplianceDetailColumns.jsx  # cột Attribute
```

**Structure Decision**: web-application; thay đổi nằm trong hai repo lồng nhau, cùng spec 024 ở repo gốc.
