# Data Model: Compl Detail Attribute Search

Không thêm bảng/cột DB. Dữ liệu đọc từ bảng sẵn có:

| Nguồn | Vai trò |
|---|---|
| `compl_master_conditions` (RefTypeId 7/12) + `compl_master_condition_values` (RefTypeValue = RecId hoặc GroupValue) | Nguồn cột **Attribute** |
| `compl_attributes_combine` | Tổ hợp (023) dùng để tính tập cặp |
| D365 `RSVNAttributeTypeValueAlls` | Tên "Type: Value" của RecId; thành viên Group |

## Cấu trúc tạm
- **PairFilter** (tham số SP, JSON): `[{"m": <MasterId>, "c": <ComplianceId>}]`; chỉ có khi ref-type 7/12 có Reference Object.
- **AttributeConditionsJson** (cột SP, JSON): `[{"refTypeId": 7|12, "value": "<RecId|GroupValue>"}]`, theo thứ tự condition → value.

## ComplCompliancesResponseDto (thêm)
- `AttributeConditionsJson` (`[JsonIgnore]`, chỉ nội bộ)
- `Attribute` (string): tên đã resolve, khử trùng, nối ", "; rỗng nếu không có.

## Quy tắc
- Cặp trùng (MasterId, ComplianceId) chỉ tính một lần (khử trùng ở service).
- Không có Reference Object ⇒ `PairFilter = null` ⇒ SP chạy như cũ.
