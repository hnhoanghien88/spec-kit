# Quickstart: Compl Sync Attributes

1. Áp dụng migration `compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Migration/38_create_compl_attributes_combine.sql`.
2. Chạy unit test: `dotnet test compliance-sys-api/tests/ComplianceSysApi.UnitTests --filter ComplSyncAttributes`.
3. Chạy API, đăng nhập, gọi `GET /api/compl-synchronize-data/test-compl-sync-attributes` (xem [contract](contracts/test-compl-sync-attributes.md)).
4. Kiểm tra `SELECT * FROM compl_attributes_combine` đúng 6 giá trị thuộc tính; gọi lần 2, số dòng không đổi.

## Update 1 (2026-10-09) — Product attribute tab

1. Mở `/compliance-view?ref-type=7&page=1&page-size=50`: không có cột "Attribute Value RecId" (SC-005).
2. Click dòng "Leather": trang chi tiết có tab "Compliances of attribute …" và "Compliances detail - Leather" (FR-014).
3. Mở tab mới: danh sách có các cột như tab 0 và khớp kết quả tra thủ công theo (ItemId, Type, Name, Option), không lặp (SC-006); so sánh bằng `POST /api/view-compliances/get-by-attribute-combine?attributeValueRecId=5637881237` (xem contracts/get-by-attribute-combine.md).
4. RecId không có trong combine → "No data"; ref-type khác 7 → không có tab (FR-018).
5. Đo thời gian tải tab với RecId ~1.000 tổ hợp ≤ 5 s (SC-007). Yêu cầu môi trường có dữ liệu đã chạy `test-compl-sync-attributes`; nếu không có thì ghi "NOT run — requires live env".

## Update 2 — Accordion

1. Mở trang chi tiết Leather → tab "Compliances detail - Leather": thấy "Group: <GroupValue>" (nếu D365 có) rồi các nhóm "ItemId Type, Name, Option" đóng sẵn (FR-019/020/021).
2. Mở một nhóm → bảng compliance như tab 0; mạng chỉ gọi `get-for-so-detail` khi mở (FR-022).
3. Ngắt D365 → vẫn có các nhóm tổ hợp (FR-023). Đo SC-008. Cần môi trường thật → ghi "NOT run — requires live env" nếu không có.
