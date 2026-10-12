# Contract: POST /compliances/get-all

Không đổi request. Filter vẫn là `refTypeId` (7 hoặc 12) và `refTypeValue` (RecId của thuộc tính, hoặc GroupValue).

## Response item (thêm trường)
| Trường | Kiểu | Mô tả |
|---|---|---|
| `attribute` | string | Danh sách tên thuộc tính/nhóm từ condition master, ví dụ `"Leather, Upholstery name"`; `""` nếu không có |

## Hành vi
- refTypeId ∈ {7,12} + refTypeValue ⇒ tập kết quả = tập cặp (master, compliance) của logic 023; `totalCount` đếm theo cùng tập.
- Các trường hợp khác ⇒ như cũ.
- ref-type 12 gặp lỗi D365 ⇒ trả lỗi (ApiResponse thất bại), không trả danh sách thiếu.

## SP (nội bộ)
`compl_sp_get_compl_compliances_paging` và `_paging_count` thêm tham số cuối `p_pair_filter LONGTEXT` (NULL = bỏ qua).
