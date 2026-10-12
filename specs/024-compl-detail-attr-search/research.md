# Research: Compl Detail Attribute Search

## R1 — Cách lấy tập compliance cho ref-type 7/12
- **Decision**: Tái dùng logic 023 (`ViewCompliancesService`: `GetAttributeCombineGroupsAsync`/`GetAttributeGroupGroupsAsync` → `MergeGroupPayloads` → `sp_load_compl_by_conditions` → `DistinctComplianceRows`) để lấy tập cặp (MasterId, ComplianceId); truyền vào SP paging qua tham số JSON `p_pair_filter`.
- **Rationale**: Đảm bảo trùng 100% với tab 023 (FR-003) mà không nhân đôi logic khớp điều kiện; SP vẫn lo phân trang/sort/searchText/dueDays.
- **Alternatives**: (a) viết lại logic khớp trong SQL — lệch 023, rủi ro cao; (b) phân trang trong bộ nhớ — không đúng sort/count của SP; (c) gọi SP 023 trực tiếp có phân trang — khác DTO/shape.

## R2 — Truyền tập cặp xuống SQL
- **Decision**: JSON text `[{"m":MasterId,"c":ComplianceId}, …]`, SP dùng `JSON_TABLE` để lọc `(cm.Id, cd.Id)`; `NULL` = không lọc kiểu này. Khi rỗng truyền `[]` → trả 0 dòng.
- **Rationale**: SP 023 đã dùng JSON; một tham số, không cần bảng tạm; không giới hạn độ dài như CSV id.
- **Alternatives**: bảng tạm theo session (khó với Dapper connection pool); danh sách `IN` (giới hạn kích thước).

## R3 — Điều kiện nhánh lỗi
- **Decision**: giữ nguyên hành vi 023: ref-type 7 nuốt lỗi D365 phần Group (log warning); ref-type 12 để lỗi D365 lan ra → API trả lỗi rõ ràng (FR-007).
- **Rationale**: Tái dùng nguyên hàm 023 nên hành vi giống nhau.

## R4 — Cột Attribute
- **Decision**: SP trả `AttributeConditionsJson` = mảng `{refTypeId, value}` cho condition ref-type 7/12 của master (theo `cmc.Id`, `cmcv.Id`); service gom RecId ref-type 7 → resolve "AttributeTypeName: AttributeValueName" bằng `ReferenceNameResolverService`, ref-type 12 → tên = GroupValue; khử trùng, nối ", " → `Attribute`. Khi D365 lỗi dùng mã làm dự phòng.
- **Rationale**: Tên không lưu trong DB; resolver sẵn có; SP không thể gọi D365.
- **Alternatives**: join D365 từ FE — thêm N request.

## R5 — Nhãn Reference Object ref-type 7
- **Decision**: ở `getOptionLabel` của hai component autocomplete, khi `refType === 7` chỉ trả `name`; `isOptionEqualToValue` vẫn so theo `id`, giá trị lọc vẫn là `code`.
- **Rationale**: Backend đã trả `Name = "Type: Value"`; không cần đổi API.

## R6 — Migration
- **Decision**: file mới `Migration/39_alter_compl_compliances_paging_attr_filter.sql` chứa `DROP PROCEDURE IF EXISTS` + `CREATE` cho cả hai SP; cập nhật `Sqls/Procedures/*.sql`. Hai file SQL tham chiếu ở thư mục gốc không sửa trực tiếp.
- **Rationale**: Quy ước repo: mọi thay đổi SP đi kèm file migration đánh số.

## R7 — Không sắp xếp theo cột Attribute
- **Decision**: cột `sortable: false`, không thêm vào whitelist order-by (giá trị tên chỉ có sau khi resolve D365).
