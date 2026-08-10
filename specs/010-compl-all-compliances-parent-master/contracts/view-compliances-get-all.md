# Contract Delta: `POST api/view-compliances/get-all`

Endpoint đã tồn tại (`ViewCompliancesController`, `[Route("api/view-compliances")]`,
`[HttpPost("get-all")]`, dòng 141 hiện tại). Feature này **không đổi** request shape, route, hay
policy/auth của endpoint — chỉ mở rộng **response body**, vì endpoint gọi
`GetViewCompliancesAsync` → `CALL sp_load_compl_by_conditions(...)` và trả `List<ViewCompliancesResponseDto>`.

## Request

Không đổi. Vẫn nhận `ViewCompliancesRequestDto` (payload JSON điều kiện lọc — không thuộc phạm vi
feature này).

## Response — trước (hiện tại)

Mỗi item trong danh sách trả về gồm (rút gọn, chỉ liệt kê field liên quan):

```json
{
  "masterId": 123,
  "masterCode": "MC-01",
  "masterName": "...",
  "status": "APPLIED",
  "code": "...",
  "mappedInputValue": "..."
}
```

Dòng nào bị "phủ" bởi Master cha (Root) thì **không xuất hiện** trong danh sách này (đã bị `DELETE`
khỏi kết quả trước khi trả về).

## Response — sau (feature này)

Thêm 1 field mới `parentMaster`, ngay sau `masterCode` (thứ tự JSON không mang tính hợp đồng bắt
buộc với JSON — chỉ có ý nghĩa khi xem SQL/DTO nguồn — nhưng field này luôn có mặt trên mọi item):

```json
{
  "masterId": 123,
  "masterCode": "MC-01",
  "parentMaster": "",
  "masterName": "...",
  "status": "APPLIED",
  "code": "...",
  "mappedInputValue": "..."
}
```

Dòng trước đây bị xóa nay **xuất hiện** trong danh sách, với:

```json
{
  "masterId": 456,
  "masterCode": "MC-02-CHILD",
  "parentMaster": "MC-01",
  "masterName": "...",
  "status": "UseParent",
  "code": "...",
  "mappedInputValue": "cùng giá trị với dòng MC-01 tương ứng"
}
```

## Breaking-change assessment

- **Field mới** (`parentMaster`): additive, không breaking cho client hiện có (JSON deserialization
  bỏ qua field lạ theo mặc định ở phía client hiện tại — cần xác nhận nếu có client strict-schema).
- **Giá trị `status` mới** (`"UseParent"`): additive về mặt kiểu dữ liệu (`status` vẫn là `string`),
  nhưng là thay đổi hành vi cho bất kỳ client nào coi `status` là enum đóng chỉ gồm 2 giá trị. Đã rà
  soát toàn bộ client nội bộ hiện có trong repo (xem research.md R6) — không có nơi nào crash; nơi
  nào lọc `=== 'MISSING'`/`=== 'APPLIED'` chỉ đơn giản không khớp dòng `UseParent`.
- **Số dòng trả về tăng** cho các input có hierarchy phủ nhau: client nào giả định tổng số dòng cố
  định (ví dụ so khớp với 1 API đếm riêng) cần biết rằng path đếm (`get-count`/proc
  `sp_load_compl_by_conditions_count`) KHÔNG đổi trong feature này — 2 số có thể lệch sau thay đổi
  này (đã ghi nhận, ngoài phạm vi — xem Assumptions của spec.md).

## Consumer mới (US2, 2026-08-10)

Tab "Compliances of Sales order" (`compliance-view-so`, `ref-type=11`,
`useComplianceColumns.jsx`) là consumer đầu tiên trong repo chủ động đọc `parentMaster` và giá trị
`status === "UseParent"` từ response này (trước đó cả 2 field bị bỏ qua ở mọi nơi tiêu thụ hiện có
— xem research.md R6). Không đổi request/response shape của endpoint — chỉ thêm 1 cột UI đọc field
đã có sẵn. Xem data-model.md mục "US2" và quickstart.md mục "US2" để biết chi tiết hiển thị.
