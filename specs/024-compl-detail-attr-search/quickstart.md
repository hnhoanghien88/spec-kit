# Quickstart: Compl Detail Attribute Search

## Chuẩn bị
- Áp dụng `Migration/39_alter_compl_compliances_paging_attr_filter.sql` lên DB.
- `dotnet build` API; chạy API + client (`npm run dev`).
- Có dữ liệu `compl_attributes_combine` (đồng bộ 023) và master có condition Product attribute / Attribute group.

## Kịch bản
1. **Nhãn (US4, SC-006)**: vào `compliance-detail?page=1&page-size=50`, chọn Reference Type = Product attribute, mở Reference Object → nhãn dạng "Marble: Yellow Travertine Marble", không có mã.
2. **Product attribute (US1, SC-001)**: chọn "Leather", Search; đối chiếu với tab "Compliances of attribute - Leather" ở `compliance-view-so?ref-type=7…` → cùng tập, không trùng.
3. **Attribute group (US2, SC-002)**: chọn một Group, Search; đối chiếu tab Attribute group. Tắt D365 → có thông báo lỗi.
4. **Cột Attribute (US5, SC-007)**: cột sau "Name" hiển thị "Leather, …"; master không có condition ⇒ trống.
5. **Không hồi quy (US3, SC-005)**: ref-type khác / Reference Object trống / Search text / Expiry days cho kết quả như trước.

## Kiểm thử tự động
`dotnet test compliance-sys-api/tests/ComplianceSysApi.UnitTests --filter ComplCompliancesQueryServiceTests`
