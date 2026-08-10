# Data Model: Compliance Master Hierarchies

## Bảng mới: `compl_master_hierarchies`

| Cột | Kiểu | Ràng buộc | Ghi chú |
|---|---|---|---|
| `Id` | `bigint` | PK, `AUTO_INCREMENT` | Khoá thay thế (surrogate) — dùng để định danh 1 dòng cụ thể cho các thao tác move/delete. |
| `MasterCode` | `varchar(50)` | `NOT NULL` | Giá trị `Code` của Compliance Master (đúng như picker trả về — xem research.md mục 3). |
| `ParentCode` | `varchar(50)` | `NOT NULL DEFAULT ''` | `''` khi là Root; ngược lại là `MasterCode` của node cha. Dùng chuỗi rỗng (không dùng `NULL`) để ràng buộc UNIQUE hoạt động đúng trên MySQL. |
| `DisplayOrder` | `int` | `NOT NULL DEFAULT 0` | Thứ tự trong nhóm anh em (cùng `ParentCode`), bắt đầu từ 0. |
| `CreatedDate`/`CreatedBy`/`UpdatedDate`/`UpdatedBy` | theo `BaseEntity` | | Audit chuẩn, set server-side từ `HttpContext.Items["UserEmail"]`. |

```sql
CREATE TABLE IF NOT EXISTS `compl_master_hierarchies` (
  `Id` bigint NOT NULL AUTO_INCREMENT,
  `MasterCode` varchar(50) NOT NULL,
  `ParentCode` varchar(50) NOT NULL DEFAULT '',
  `DisplayOrder` int NOT NULL DEFAULT 0,
  `CreatedDate` datetime DEFAULT CURRENT_TIMESTAMP,
  `CreatedBy` varchar(50) DEFAULT NULL,
  `UpdatedDate` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `UpdatedBy` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `uq_compl_master_hierarchy` (`MasterCode`, `ParentCode`),
  KEY `idx_compl_master_hierarchy_parent` (`ParentCode`)
) ENGINE=InnoDB;
```

**Không có FK tới `compl_masters`**: `compl_masters.Code` không tự nó là UNIQUE (unique theo cặp
`Code`+`VersionNo`), nên không thể đặt FK trực tiếp trên `MasterCode`/`ParentCode` → `Code`. Đây là
cùng cách xử lý đã áp dụng cho `EutrTemplateReferences.VendorCode` (không FK tới D365) — chấp nhận
không ràng buộc FK ở DB, xác thực sự tồn tại của `MasterCode` (nếu cần) ở Application layer.

**Ràng buộc UNIQUE `(MasterCode, ParentCode)`** implement đồng thời 2 quy tắc nghiệp vụ đã chốt ở
Clarify:
- FR-011 — không trùng Root (2 dòng `(A, '')` là vi phạm UNIQUE).
- FR-013 — không trùng sibling (2 dòng cùng `MasterCode` + cùng `ParentCode` là vi phạm UNIQUE).

Service layer vẫn kiểm tra trước khi insert (qua `ExistsAsync`) để trả lỗi rõ ràng theo từng mã, thay
vì để lỗi UNIQUE constraint (MySQL 1062) rơi xuống tận DB rồi mới bắt exception.

## Domain Entity (backend): `ComplMasterHierarchy`

```csharp
[Table("compl_master_hierarchies")]
public class ComplMasterHierarchy : BaseEntity
{
    public long Id { get; set; }
    public string MasterCode { get; set; } = null!;
    public string ParentCode { get; set; } = string.Empty;
    public int DisplayOrder { get; set; }
}
```

## Response DTO: `ComplMasterHierarchyResponseDto`

```csharp
public class ComplMasterHierarchyResponseDto : ComplMasterHierarchy
{
    public long? MasterId { get; set; }      // JOIN compl_masters.Id (bản mới nhất theo Code) —
                                              // KHÁC với Id kế thừa (khoá của chính dòng hierarchy);
                                              // dùng để gọi GET /compliance-master/{id}/conditions
                                              // (xem "Sửa lỗi" bên dưới)
    public string? Name { get; set; }        // JOIN compl_masters (bản mới nhất theo Code)
    public string? Description { get; set; } // JOIN compl_masters (bản mới nhất theo Code)
}
```

**Sửa lỗi (2026-08-10, sau khi implement User Story 6)**: Bản đầu tiên của "View condition" trên
dòng cây (`ComplMasterHierarchiesPage.jsx`) dùng nhầm `node.id` (khoá của dòng
`compl_master_hierarchies`, dùng cho move/delete/reorder) làm tham số cho
`GET /compliance-master/{id}/conditions` — endpoint này cần `compl_masters.Id`, không phải khoá
hierarchy hay `MasterCode`. Hậu quả: luôn trả về rỗng/"No conditions defined" vì id truyền lên
không khớp Compliance Master nào (hoặc khớp nhầm 1 master khác). Đã sửa bằng cách thêm cột
`MasterId` (join `m.Id`) vào `ComplMasterHierarchyResponseDto`/SQL nguồn, và đổi frontend
(`handleViewCondition`) sang dùng `node.masterId` thay vì `node.id`. `MasterId` có thể `null` nếu
`MasterCode` không còn khớp bản ghi nào trong `compl_masters` (đã bị xoá) — trường hợp này UI hiện
empty state thay vì gọi API với id rỗng (đúng Edge Case đã ghi trong spec.md).

Truy vấn nguồn (`ComplMasterHierarchyRepository.GetAllWithMasterInfoAsync`, Dapper inline SQL, không
cần stored procedure — xem research.md mục 7):

```sql
SELECT h.Id, h.MasterCode, h.ParentCode, h.DisplayOrder,
       h.CreatedBy, h.CreatedDate, h.UpdatedBy, h.UpdatedDate,
       m.Id AS MasterId, m.Name, m.Description
FROM compl_master_hierarchies h
LEFT JOIN compl_masters m
    ON m.Code = h.MasterCode
   AND m.VersionNo = (SELECT MAX(m2.VersionNo) FROM compl_masters m2 WHERE m2.Code = h.MasterCode)
ORDER BY h.ParentCode, h.DisplayOrder;
```

Trả về **toàn bộ** hierarchy trong 1 lần gọi (không phân trang — cây quản trị dạng master data, quy
mô nhỏ, xem SC-003/Assumptions của spec). Client tự dựng cây từ danh sách phẳng này.

## Request DTOs

```csharp
public class AddRootsRequestDto
{
    public List<string> MasterCodes { get; set; } = new();
}

public class AddChildrenRequestDto
{
    public List<string> MasterCodes { get; set; } = new();
    // ParentCode đến từ route segment, không nằm trong body
}

public class MoveHierarchyRequestDto
{
    public string Direction { get; set; } = null!; // "up" | "down"
}

// User Story 5 (kéo-thả) — reorder trong cùng cha (KHÔNG có reparent — xem research.md mục 9,
// tính năng thả sang cha khác/về root đã bị bỏ theo phản hồi người dùng)
public class ReorderHierarchyRequestDto
{
    public int TargetIndex { get; set; } // vị trí 0-based mới trong nhóm anh em, sau khi loại bỏ chính node đang kéo
}
```

Validator (`FluentValidation`, kiểm tra hình dạng — không kiểm tra nghiệp vụ trùng lặp/vòng lặp, việc
đó thuộc Service):
- `AddRootsRequestDto`/`AddChildrenRequestDto`: `MasterCodes` không rỗng, mỗi phần tử không blank.
- `MoveHierarchyRequestDto`: `Direction` phải là `"up"` hoặc `"down"` (không phân biệt hoa/thường).
- `ReorderHierarchyRequestDto`: `TargetIndex >= 0`.

## Quy tắc nghiệp vụ (Application layer — `ComplMasterHierarchyService`)

1. **`GetTreeAsync()`** → `repository.GetAllWithMasterInfoAsync()`, trả nguyên danh sách phẳng; dựng
   cây là việc của frontend (xem Key Entities — cây thực chất là DAG theo khoá tự nhiên).
2. **`AddRootsAsync(masterCodes, userEmail)`**:
   - Với từng `code` (theo đúng thứ tự trong mảng đầu vào):
     - Nếu `ExistsAsync(code, "")` → thêm lỗi "`{code}` is already a root." vào danh sách lỗi, bỏ qua
       code này (không rollback các code khác đã hợp lệ — theo Edge Case đã ghi trong spec).
     - Ngược lại: `DisplayOrder = GetMaxDisplayOrderAsync("") + 1 + (số root đã thêm thành công trong
       cùng lượt gọi này)`, insert.
   - Trả về danh sách dòng đã tạo thành công + danh sách lỗi theo từng mã (nếu có) → controller trả
     `207`-kiểu-nội-dung qua `ApiResponse<T>` với cả `data` và `message` liệt kê mã bị từ chối (chi
     tiết response shape xem `contracts/`).
3. **`AddChildrenAsync(parentCode, masterCodes, userEmail)`**:
   - Nạp toàn bộ bảng 1 lần (`GetAllWithMasterInfoAsync`), dựng `Dictionary<string, HashSet<string>>`
     (`code → tập parentCode của mọi dòng có MasterCode = code`).
   - Tính `ancestors(parentCode)` bằng BFS/DFS trên đồ thị trên (xem research.md mục 2).
   - Với từng `code` cần thêm:
     - Nếu `code == parentCode` hoặc `code ∈ ancestors(parentCode) ∪ {parentCode}` → lỗi "Adding
       `{code}` here would create a circular relationship." (FR-012).
     - Nếu đã tồn tại dòng `(code, parentCode)` → lỗi "`{code}` is already a child of `{parentCode}`."
       (FR-013).
     - Ngược lại: `DisplayOrder` kế tiếp trong nhóm `ParentCode = parentCode`, insert.
4. **`MoveAsync(id, direction, userEmail)`**: lấy dòng theo `id`, lấy toàn bộ sibling (cùng
   `ParentCode`) sắp theo `DisplayOrder`, tìm sibling liền kề theo hướng, hoán đổi `DisplayOrder` của
   2 dòng (update cả 2). Không làm gì nếu đã ở đầu/cuối.
5. **`DeleteWithDescendantsAsync(id, userEmail)`**: lấy dòng theo `id` → `MasterCode` của nó → tính
   tập descendant codes bằng BFS xuôi trên quan hệ `ParentCode = code cha` (đệ quy) → xoá dòng gốc +
   toàn bộ dòng có `MasterCode` thuộc tập descendant (bulk, trong 1 transaction qua `IUnitOfWork`).
   Trả về số lượng dòng đã xoá (để frontend đối chiếu, dù frontend đã tự đếm trước khi hiện confirm
   dialog — xem Edge Cases/User Story 3).
6. **`ReorderAsync(id, targetIndex, userEmail)`** (User Story 5 / FR-022, kéo-thả trong cùng cha —
   đây là TOÀN BỘ logic nghiệp vụ của kéo-thả; không có `ReparentAsync` — xem research.md mục 9):
   - Lấy dòng theo `id` → `ParentCode` hiện tại.
   - Lấy toàn bộ sibling cùng `ParentCode`, sắp theo `DisplayOrder`, loại bỏ dòng đang kéo khỏi danh
     sách này.
   - Chèn dòng đang kéo vào vị trí `targetIndex` (clamp về `[0, count]`) trong danh sách đã loại bỏ.
   - Gán lại `DisplayOrder = 0..n-1` tuần tự cho TOÀN BỘ danh sách sibling (kể cả dòng vừa chèn), cập
     nhật hàng loạt trong 1 transaction. Trả về danh sách đầy đủ các dòng sibling đã cập nhật (khác
     `MoveAsync` — vốn chỉ trả 2 dòng vừa hoán đổi vì chỉ hỗ trợ bước nhảy 1 vị trí).
   - Không cần kiểm tra vòng lặp/trùng lặp (không đổi `ParentCode`, không đổi bộ sibling) — kéo-thả
     KHÔNG BAO GIỜ thay đổi Parent Code của một node (FR-023).

## Frontend — cấu trúc cây từ danh sách phẳng (DAG, không phải cây thuần)

`buildTree(rows)`: nhóm `rows` theo `parentCode`; với mỗi `row`, con của nó = `rows.filter(r =>
r.parentCode === row.masterCode)` (tra theo **`masterCode` của row cha**, KHÔNG theo `row.id`) — thể
hiện đúng ngữ nghĩa "con được chia sẻ giữa mọi lần xuất hiện của cùng 1 mã" (xem research.md mục 2).
Root nodes = `rows.filter(r => r.parentCode === '')`.

`getDescendantIds(rows, rowId)`: tìm `row` theo `rowId` → lấy `masterCode` → BFS xuôi theo
`parentCode === masterCode đó` (đệ quy qua các tầng) → trả về tập `id` của mọi dòng descendant, dùng
để hiện số lượng trong confirm dialog trước khi gọi API xoá (client-side preview, khớp với API xoá
thật ở Application layer).
