# Phase 1 Data Model: All-Compliances Parent Master Coverage

Không có bảng DB mới, không có entity Domain mới. Thay đổi duy nhất là mở rộng **hình dạng kết quả**
của 1 stored procedure có sẵn (`sp_load_compl_by_conditions`) và DTO tương ứng đọc kết quả đó
(`ViewCompliancesResponseDto`).

## Entity (đọc, không sửa): `ComplMasterHierarchy` (`compl_master_hierarchies`)

Đã tồn tại từ feature `008-compl-master-hierarchies`, dùng nguyên trạng làm nguồn xác định quan hệ
cha/con:

| Column | Type | Ghi chú |
|---|---|---|
| `MasterCode` | `varchar(50)` | Khóa tự nhiên — mã của `compl_masters.Code`. |
| `ParentCode` | `varchar(50) NOT NULL DEFAULT ''` | `''` = node Root (không có cha). |

Feature này không đọc `ParentCode` trực tiếp theo dòng — nó tiêu thụ **kết quả đã tính sẵn** của
STEP 20b: `tmp_hierarchy_descendants` (map mọi `DescendantMasterCode` về đúng 1 `RootMasterCode` của
nó) và `tmp_hierarchy_root_matches` (Root nào thực sự có 1 dòng compliance khớp trong `tmp_result`
cho 1 `MappedInputValue` cụ thể) — xem research.md R1/R2.

## Kết quả trả về: `tmp_result` (SQL) / `ViewCompliancesResponseDto` (C#) — thay đổi

| Field | Type (C#) | Trạng thái | Nguồn giá trị |
|---|---|---|---|
| `MasterCode` | `string` | Không đổi | Như hiện tại. |
| **`ParentMaster`** | **`string?` (MỚI)** | **Thêm mới, ngay sau `MasterCode`** | Mặc định `''` (cột SQL khai báo `CAST('' AS CHAR(50))` — không dùng literal trần, xem research.md R3 để biết lý do). Khi dòng bị "phủ" bởi Master cha (Root) — xem quy tắc dưới — bằng chính mã `MasterCode` của Root đó (`rm.RootMasterCode`). |
| `Status` | `string?` | Mở rộng tập giá trị | `'APPLIED'` \| `'MISSING'` (không đổi, do 3 stream UNION ALL gán) hoặc **`'UseParent'` (MỚI)** — chỉ do STEP 20b gán, ghi đè giá trị `APPLIED`/`MISSING` đã có của dòng đó. Cột SQL của `tmp_result` khai báo `CAST(Status AS CHAR(20))` ở outer SELECT (không phải cột literal trần) — cần thiết vì độ rộng suy ra từ 2 literal 7 ký tự (`APPLIED`/`MISSING`) không đủ chứa `'UseParent'` (9 ký tự), xem research.md R5. |
| *(mọi field khác)* | — | Không đổi | Như hiện tại — xem `ViewCompliancesResponseDto.cs`. |

### Quy tắc xác định "bị phủ bởi Master cha" (không đổi so với hiện tại — chỉ đổi hành động)

Một dòng `tr` trong `tmp_result` được coi là bị phủ (và do đó nhận `ParentMaster`) khi **tất cả**
đúng:

1. Tồn tại ít nhất 1 dòng khác `root_row` trong `tmp_result` với `root_row.Code <> ''` (có compliance
   thực sự khớp) và `root_row.MasterCode` là 1 Root thực sự trong `compl_master_hierarchies`
   (`ParentCode = ''`).
2. `tr.MasterCode` là con/cháu (bất kỳ cấp) của `root_row.MasterCode` theo cây phân cấp.
3. `tr.MappedInputValue = root_row.MappedInputValue` (cùng giá trị input được ánh xạ).
4. `tr.MasterCode <> root_row.MasterCode` (không tự áp dụng cho chính dòng Root).

Khi đúng cả 4 điều kiện: `tr.ParentMaster = root_row.MasterCode` — LUÔN gán, bất kể `tr.Status` hiện
tại là gì. Riêng `tr.Status` thì có thêm 1 điều kiện phụ (cập nhật theo phản hồi người dùng, xem
research.md R2b):

- Nếu `tr.Status` hiện tại (trước khi UPDATE) là `'MISSING'` → đổi thành `'UseParent'`.
- Nếu `tr.Status` hiện tại là `'APPLIED'` → GIỮ NGUYÊN `'APPLIED'`, không đổi.

Dòng không thỏa 4 điều kiện trên: giữ nguyên `ParentMaster = ''` và `Status` như 3 stream đã gán ban
đầu.

## State/behavior transition

```
Trước (hành vi cũ)                     Sau (hành vi mới)
──────────────────────                 ──────────────────────
Dòng con bị phủ, đang MISSING  →       Dòng con bị phủ, đang MISSING  →  UPDATE tại chỗ:
DELETE khỏi tmp_result (biến mất)         ParentMaster = <mã Root>
                                           Status        = 'UseParent'
                                           (dòng vẫn còn trong kết quả trả về)

Dòng con bị phủ, đang APPLIED  →       Dòng con bị phủ, đang APPLIED  →  UPDATE tại chỗ:
DELETE khỏi tmp_result (biến mất)         ParentMaster = <mã Root>
                                           Status        = 'APPLIED' (KHÔNG đổi)
                                           (dòng vẫn còn trong kết quả trả về)

Dòng không bị phủ  →  không đổi        Dòng không bị phủ  →  không đổi,
                                           chỉ thêm ParentMaster = '' (mặc định)
```

## Validation rules

- `ParentMaster` không bao giờ `NULL` ở tầng SQL (mặc định `''`, giống pattern `COALESCE(..., '')`
  các cột khác của `tmp_result`) — DTO property vẫn khai báo `string?` để khớp convention chung của
  các property nullable khác trên `ViewCompliancesResponseDto` (ví dụ `MappedInputValue`), nhưng giá
  trị thực tế nhận được luôn là chuỗi (rỗng hoặc mã Master).
- Một dòng Root (được dùng làm `root_row` để phủ dòng khác) không bao giờ tự nhận `Status =
  'UseParent'` từ chính lượt match đó (điều kiện 4 ở trên) — nhưng vẫn CÓ THỂ nhận `Status =
  'UseParent'` nếu chính nó lại là con/cháu của 1 Root khác cao hơn với cùng `MappedInputValue` VÀ
  Status hiện tại của nó là `MISSING` (trường hợp hợp lệ, không phải bug — hệ quả tự nhiên của cây
  nhiều cấp kết hợp với quy tắc R2b).
- Một dòng bị phủ đang `APPLIED` luôn nhận `ParentMaster` (không rỗng) nhưng KHÔNG bao giờ có
  `Status = 'UseParent'` — đây là điểm khác biệt duy nhất giữa 2 nhánh Status khi cùng bị phủ.

## US2 (mới): Tab "Compliances of Sales order" (`compliance-view-so`, `ref-type=11`)

Không có entity mới — tab này chỉ hiển thị lại đúng các field ở trên (`parentMaster`, `status`, đã
tới client từ US1) trong 1 grid đã tồn tại
(`compliance-client/.../compliance-view-so/hooks/useComplianceColumns.jsx`).

### Cột mới: "Parent master"

| Field | Vị trí | Giá trị hiển thị |
|---|---|---|
| `parentMaster` | Ngay sau cột `masterCode` ("Master code") | Y hệt `row.parentMaster` từ response — rỗng khi dòng không bị phủ, mã Master cha (Root) khi bị phủ (theo đúng quy tắc US1 ở trên). Không có logic biến đổi thêm ở tầng UI. |

### Thứ tự cột (US2) — trước và sau

```
Trước (hiện tại)                          Sau (US2)
─────────────────                          ─────────
0 masterCode   "Master code"               0 masterCode    "Master code"
1 masterName   "Master name"               1 parentMaster  "Parent master"   ← MỚI
2 (actions nếu có quyền, splice(2,0,…))    2 masterName    "Master name"
3 code         "Code"                      3 (actions nếu có quyền, splice(3,0,…))  ← chỉ số dời
...                                        4 code          "Code"
                                           ...
```

`actions` phải dời từ `splice(2, 0, …)` sang `splice(3, 0, …)` để vẫn nằm đúng vị trí tương đối
hiện tại (ngay sau `masterName`) — nếu không dời, `actions` sẽ chèn vào giữa `parentMaster` và
`masterName`, sai vị trí so với hành vi hôm nay (research.md, plan.md Summary).

### Cột "Expiry warning" (field `progress`) — mở rộng logic `renderCell`

| Điều kiện (theo thứ tự kiểm tra) | Hiển thị |
|---|---|
| 1. `row.replacedById !== null` | "Already have new version" (không đổi, giữ độ ưu tiên cao nhất — research.md R9) |
| 2. else `row.status === "UseParent"` | **"Use parent" (MỚI)** — thay cho "Missing" mà `<AlertProgressCell />` lẽ ra sẽ hiển thị (vì dòng `UseParent` luôn thiếu `validTo`/`numDayAlert` hợp lệ của riêng nó, theo US1: chỉ dòng đang `MISSING` mới đổi thành `UseParent`) |
| 3. else | `<AlertProgressCell validTo={row.validTo} numDayAlert={row.numDayAlert} />` (không đổi — Missing/Applied/còn hạn/hết hạn tính như hôm nay) |

Không sửa `AlertProgressCell.jsx` (component dùng chung — research.md R8); toàn bộ logic mới nằm
trong `renderCell` của `useComplianceColumns.jsx`.

### Validation rules (US2)

- Cột "Parent master" không có `valueGetter`/biến đổi riêng — hiển thị trực tiếp giá trị field, vì
  `parentMaster` đã luôn là chuỗi (rỗng hoặc mã Master, không `null`) theo US1.
- Nhánh "Use parent" chỉ có thể xảy ra khi `row.status === "UseParent"` — theo US1, giá trị này chỉ
  được gán cho dòng vốn đang `MISSING`; do đó nhánh 2 và nhánh 3 (Applied/Missing thật/còn hạn) loại
  trừ lẫn nhau, không có dòng nào vừa hiển thị "Use parent" vừa có 1 giá trị `validTo` hợp lệ bị bỏ
  qua.
