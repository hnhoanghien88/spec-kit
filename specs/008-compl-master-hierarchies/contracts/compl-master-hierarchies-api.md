# API Contract: Compliance Master Hierarchies

Base route: `api/compl-master-hierarchies`. Mọi endpoint yêu cầu `[Authorize]` +
`Policy = "ComplianceMaster.ReadAll"` (xem research.md mục 4 — quyết định có chủ đích theo FR-020,
không tách policy Create/Update/Delete riêng).

## `GET api/compl-master-hierarchies`

Trả toàn bộ hierarchy (không phân trang).

**Response** `ApiResponse<List<ComplMasterHierarchyResponseDto>>`:

```json
{
  "success": true,
  "data": [
    { "id": 1, "masterCode": "MAS-00034", "parentCode": "", "displayOrder": 0,
      "masterId": 1034, "name": "Name 1", "description": "..." },
    { "id": 2, "masterCode": "MAS-00003", "parentCode": "", "displayOrder": 1,
      "masterId": 1003, "name": "Name 2", "description": "..." },
    { "id": 3, "masterCode": "MAS-0003",  "parentCode": "MAS-00003", "displayOrder": 0,
      "masterId": 1005, "name": "Name 3", "description": "..." }
  ],
  "message": "Get compliance master hierarchies successfully"
}
```

## `POST api/compl-master-hierarchies/roots`

**Request**:

```json
{ "masterCodes": ["MAS-00034", "MAS-00003"] }
```

**Response** `ApiResponse<AddHierarchyResultDto>` — `201` nếu ít nhất 1 mã được thêm, `422` nếu
TẤT CẢ mã đều bị từ chối:

```json
{
  "success": true,
  "data": {
    "added": [ { "id": 10, "masterCode": "MAS-00034", "parentCode": "", "displayOrder": 2, "name": "...", "description": "..." } ],
    "rejected": [ { "masterCode": "MAS-00003", "reason": "MAS-00003 is already a root." } ]
  },
  "message": "1 of 2 masters added as root"
}
```

**Cập nhật 2026-08-18 (bug fix, xem research.md mục 12)**: kiểm tra trùng lặp cho "Add root" giờ quét
TOÀN BỘ cây, không chỉ danh sách root hiện có. Nếu mã đã tồn tại làm CON ở một nhánh nào đó, lỗi trả
về là:

```json
{ "masterCode": "MAS-0003", "reason": "MAS-0003 already exists elsewhere in the hierarchy." }
```

## `POST api/compl-master-hierarchies/{parentCode}/children`

`{parentCode}` là `MasterCode` của node cha đang chọn trên cây (URL-encode nếu có ký tự đặc biệt).

**Request**:

```json
{ "masterCodes": ["MAS-0003", "MAS-0004"] }
```

**Response**: cùng shape `AddHierarchyResultDto` như trên, ví dụ lỗi vòng lặp/trùng sibling:

```json
{
  "success": true,
  "data": {
    "added": [ { "id": 11, "masterCode": "MAS-0004", "parentCode": "MAS-00003", "displayOrder": 1, "name": "...", "description": "..." } ],
    "rejected": [
      { "masterCode": "MAS-00034", "reason": "Adding MAS-00034 here would create a circular relationship." },
      { "masterCode": "MAS-0003",  "reason": "MAS-0003 is already a child of MAS-00003." }
    ]
  },
  "message": "1 of 3 masters added as child"
}
```

**Cập nhật 2026-08-18 (bug fix, xem research.md mục 12)**: kiểm tra trùng lặp cho "Add child" giờ
cũng quét TOÀN BỘ cây (không chỉ ancestor-chain + con trực tiếp của parent). Nếu mã đã tồn tại ở một
nhánh KHÁC — không phải ancestor, không phải con hiện tại của parent này — lỗi trả về là:

```json
{ "masterCode": "MAS-0009", "reason": "MAS-0009 already exists elsewhere in the hierarchy." }
```

## `PUT api/compl-master-hierarchies/{id}/move`

**Request**:

```json
{ "direction": "up" }
```

**Response** `ApiResponse<List<ComplMasterHierarchyResponseDto>>` — chỉ trả 2 dòng vừa hoán đổi
`DisplayOrder` (dòng được move + sibling liền kề); mảng rỗng nếu đã ở đầu/cuối (no-op, vẫn `200`).

## `PUT api/compl-master-hierarchies/{id}/reorder`

Kéo-thả (User Story 5 / FR-022) — sắp xếp lại node trong cùng nhóm anh em (cùng `ParentCode`) tới 1
vị trí bất kỳ trong 1 lần thả (khác `/move` — chỉ hoán đổi với sibling liền kề).

**Request**:

```json
{ "targetIndex": 2 }
```

**Response** `ApiResponse<List<ComplMasterHierarchyResponseDto>>` — trả về TOÀN BỘ danh sách sibling
(cùng `ParentCode`) sau khi đã gán lại `DisplayOrder` tuần tự 0..n-1:

```json
{
  "success": true,
  "data": [
    { "id": 3, "masterCode": "MAS-0003", "parentCode": "MAS-00003", "displayOrder": 0, "name": "...", "description": "..." },
    { "id": 11, "masterCode": "MAS-0004", "parentCode": "MAS-00003", "displayOrder": 1, "name": "...", "description": "..." }
  ],
  "message": "Reordered successfully"
}
```

Không có endpoint `/reparent` — kéo-thả bị giới hạn CHỈ sắp xếp lại trong cùng cha (FR-023); di
chuyển 1 node sang cha khác hoặc lên root vẫn phải dùng Add child/Add root + Delete như trước (xem
research.md mục 9 cho lý do bỏ tính năng reparent-qua-drag).

## `DELETE api/compl-master-hierarchies/{id}`

Xoá node + toàn bộ descendants (xem data-model.md mục "Quy tắc nghiệp vụ" #5).

**Response** `ApiResponse<int>` — số dòng đã xoá (bao gồm chính node đó):

```json
{ "success": true, "data": 4, "message": "Deleted 4 hierarchy node(s)" }
```

## Lỗi dùng chung

- `masterCodes` rỗng hoặc thiếu → `400 Bad Request` (FluentValidation).
- Tất cả mã trong 1 lượt Add đều bị từ chối → `422 Unprocessable Entity`,
  `ApiResponse<AddHierarchyResultDto>.Fail(...)` với `data.rejected` đầy đủ lý do (để frontend hiện
  từng lỗi mà không cần gọi lại API).
- `id` không tồn tại (move/delete) → `404 Not Found`.

## Không có endpoint mới cho "View condition" trên dòng cây (User Story 6 / FR-028-030)

"View condition" trên mỗi dòng của cây gọi lại nguyên vẹn `GET /compliance-master/{id}/conditions`
(thuộc `ComplMasterController`, đã tồn tại và đã được `MasterPickerDialog.jsx`/User Story 4 sử dụng)
— KHÔNG thêm route nào vào `api/compl-master-hierarchies` cho việc này (xem research.md mục 11).

**Lưu ý quan trọng**: `{id}` trong route trên PHẢI là giá trị field `masterId` của mỗi dòng hierarchy
(xem field mới ở ví dụ response phía trên) — KHÔNG phải field `id` (khoá của chính dòng
`compl_master_hierarchies`, dùng cho `/move`/`/reorder`/`DELETE`). Nhầm lẫn 2 field này ở lần
implement đầu tiên gây ra lỗi "No conditions defined" hiển thị sai cho mọi node (đã sửa — xem
data-model.md mục "Sửa lỗi").
