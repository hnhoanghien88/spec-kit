# Phase 0 Research: All-Compliances Parent Master Coverage

Không có `[NEEDS CLARIFICATION]` nào còn lại trong spec.md. Các mục dưới đây ghi lại các quyết định
kỹ thuật cần chốt trước khi thiết kế Phase 1, cùng lý do và phương án khác đã xem xét.

## R1 — "Master cha" nghĩa là Root, không phải cha trực tiếp

**Decision**: `ParentMaster` được gán bằng `RootMasterCode` — đúng giá trị mà STEP 20b hiện tại đã
tính sẵn trong `tmp_hierarchy_root_matches.RootMasterCode` (Root = node có `ParentCode = ''` trong
`compl_master_hierarchies`), không phải cha 1 cấp trực tiếp theo `compl_master_hierarchies.ParentCode`
của riêng dòng đó.

**Rationale**: Comment gốc ngay tại STEP 20b (dòng 983-984 của file SQL hiện tại) đã viết: *"Loại
các dòng bị 'phủ' bởi compliance của Master cha (Root)..."* — tức codebase đã tự đồng nhất "Master
cha" với "Root" trong logic này. Toàn bộ cơ chế match hiện tại (`cte_hierarchy` trong
`tmp_hierarchy_descendants`) chỉ lan truyền "bị phủ" từ Root xuống mọi con/cháu — không có cơ chế
"cha 1 cấp phủ con" độc lập cho node giữa cây. Dùng lại `RootMasterCode` sẵn có nghĩa là
`ParentMaster` luôn đúng bằng master đã thực sự cung cấp compliance khiến dòng này bị coi là dư thừa.

**Alternatives considered**: Tính cha trực tiếp bằng 1 join phụ vào `compl_master_hierarchies`
(`h.ParentCode` với `h.MasterCode = tr.MasterCode`) — bị loại vì với hierarchy ≥ 3 cấp, cha trực
tiếp có thể khác Root đã thực sự khớp điều kiện, gây hiển thị sai lý do dòng bị đổi `Status`, và
đòi hỏi thêm 1 join không cần thiết khi giá trị đúng đã có sẵn.

## R2 — Đổi DELETE thành UPDATE, giữ nguyên điều kiện JOIN

**Decision**: Thay câu `DELETE tr FROM tmp_result tr INNER JOIN tmp_hierarchy_root_matches rm ...
INNER JOIN tmp_hierarchy_descendants hd ... WHERE tr.MasterCode <> rm.RootMasterCode;` (dòng
1042-1049 hiện tại) bằng:

```sql
UPDATE tmp_result tr
INNER JOIN tmp_hierarchy_root_matches rm
        ON rm.MappedInputValue = tr.MappedInputValue
INNER JOIN tmp_hierarchy_descendants hd
        ON hd.RootMasterCode       = rm.RootMasterCode
       AND hd.DescendantMasterCode = tr.MasterCode
SET tr.ParentMaster = rm.RootMasterCode,
    tr.Status       = CASE WHEN tr.Status = 'MISSING' THEN 'UseParent' ELSE tr.Status END
WHERE tr.MasterCode <> rm.RootMasterCode;
```

Giữ nguyên 100% 3 điều kiện JOIN/WHERE — chỉ đổi `DELETE` → `UPDATE ... SET`. **Cập nhật sau phản hồi
người dùng**: `tr.Status` ban đầu dùng literal `'UseParent'` trần cho mọi dòng bị phủ; đã đổi sang
`CASE WHEN tr.Status = 'MISSING' THEN 'UseParent' ELSE tr.Status END` — chỉ đổi Status thành
`'UseParent'` khi dòng con đang là `MISSING`; nếu dòng con đang `APPLIED` (đã có compliance riêng)
thì giữ nguyên `APPLIED`, không đổi. `tr.ParentMaster` vẫn được gán cho MỌI dòng bị phủ (không phân
biệt Status) — chỉ riêng `Status` là có điều kiện. Xem R2b bên dưới.

**Rationale**: Đảm bảo tập dòng bị ảnh hưởng (bị coi là "phủ") giống tuyệt đối với hành vi hiện tại
— không có rủi ro lệch logic nghiệp vụ, chỉ đổi hành động cuối. `tmp_hierarchy_root_matches` và
`tmp_hierarchy_descendants` vẫn được tạo/drop như cũ (không cần đổi 2 bảng tạm này).

**Alternatives considered**: Viết lại toàn bộ `tmp_result` bằng 1 `CASE`/`LEFT JOIN` ngay trong SELECT
gốc dựng STEP 20 (trước khi `tmp_result` tồn tại) — bị loại vì phức tạp hơn, phải nhân bản logic
CTE đệ quy vào giữa khối SELECT UNION ALL 3 stream, rủi ro cao hơn so với việc tái dùng 2 bảng tạm
đã có sẵn ngay sau khi `tmp_result` được tạo.

## R2b — Chỉ đổi Status thành 'UseParent' nếu dòng con đang MISSING (cập nhật theo phản hồi người dùng)

**Decision**: Trong `UPDATE` ở R2, `tr.Status` chỉ đổi thành `'UseParent'` khi giá trị Status hiện
tại của dòng con là `'MISSING'`. Nếu dòng con đang `'APPLIED'` (đã có compliance riêng, độc lập với
Master cha), Status được giữ nguyên `'APPLIED'` — KHÔNG đổi thành `'UseParent'`. `tr.ParentMaster`
vẫn được gán cho mọi dòng bị phủ dù Status là gì, để người dùng vẫn thấy được quan hệ cha/con dù
Status không đổi.

**Rationale**: Yêu cầu ban đầu (turn trước) đổi Status thành `'UseParent'` cho mọi dòng bị phủ, bất
kể APPLIED hay MISSING — đúng với yêu cầu gốc của người dùng lúc đó ("bất kể dòng con là APPLIED hay
MISSING"). Người dùng sau đó phản hồi thu hẹp lại: chỉ dòng MISSING mới cần đổi thành UseParent, còn
lại (APPLIED) không cần đổi Status. Về nghiệp vụ, điều này hợp lý hơn: 1 dòng đã APPLIED nghĩa là
Master con đã tự có compliance riêng đáp ứng yêu cầu, không cần "dùng" tới compliance của Master
cha — Status APPLIED (tự thân) mang nhiều thông tin hơn UseParent (mượn từ cha) cho trường hợp này.
Chỉ dòng MISSING (Master con chưa tự có compliance) mới thực sự "được cứu" nhờ Master cha, nên mới
đáng đổi Status để phản ánh điều đó.

**Alternatives considered**: Không gán `ParentMaster` cho dòng APPLIED bị phủ (chỉ gán khi Status đổi
thành UseParent) — không chọn vì người dùng chỉ nói "không cần đổi Status", không nói gì về
`ParentMaster`; giữ `ParentMaster` luôn được gán cho mọi dòng bị phủ (kể cả APPLIED) vẫn hữu ích để
hiển thị quan hệ cha/con, và không mâu thuẫn với yêu cầu mới. Nếu sau này người dùng muốn
`ParentMaster` cũng chỉ gán khi Status đổi, đó là 1 thay đổi tách biệt, dễ áp dụng (thêm cùng điều
kiện `CASE`/`WHERE` vào `ParentMaster`).

## R3 — Vị trí và giá trị mặc định của cột `ParentMaster`

**Decision**: Thêm `CAST('' AS CHAR(50)) AS ParentMaster` vào **outer SELECT** đang dựng
`tmp_result` (ngay sau `MasterCode,` ở dòng 844 hiện tại) — không cần sửa 3 stream UNION ALL bên
trong (`APPLIED`/`MISSING` individual/`MISSING` master-level), vì outer SELECT đã liệt kê cột rõ
ràng, độc lập với các stream con. Giá trị mặc định là chuỗi rỗng `''`, chỉ được STEP 20b (R2) ghi đè
cho các dòng bị phủ. Độ dài `CHAR(50)` khớp với `compl_masters.Code`/`compl_master_hierarchies.MasterCode`
(cả 2 đều `varchar(50)`) — chính là nguồn giá trị thực sự sẽ được gán vào cột này (`rm.RootMasterCode`).

**Rationale**: Ít điểm sửa nhất (1 chỗ, không phải 3), khớp đúng yêu cầu "thêm cột ParentMaster sau
MasterCode" của người dùng, và không ảnh hưởng ORDER BY/ALTER TABLE INDEX hiện có trên `tmp_result`
(`idx_mastercode`, `idx_code_mappedval` không tham chiếu `ParentMaster`, không cần đổi).

**Sự cố phát hiện khi chạy thử (đã sửa)**: Ban đầu dùng literal trần `'' AS ParentMaster` (không
`CAST`). Vì `tmp_result` được tạo bằng `CREATE TEMPORARY TABLE ... AS SELECT`, MySQL suy ra kiểu/độ
rộng cột `ParentMaster` trực tiếp từ literal `''` (độ dài 0) — kết quả là cột được tạo với độ rộng
gần như 0 ký tự. STEP 20b sau đó `UPDATE ... SET tr.ParentMaster = rm.RootMasterCode` với giá trị
là 1 mã Master thật (dài hơn 0 ký tự) → lỗi `Data too long for column 'ParentMaster' at row 1`. Sửa
bằng cách bọc `CAST('' AS CHAR(50))` để ép MySQL tạo cột với độ rộng `CHAR(50)` ngay từ đầu, đủ chứa
mọi mã Master hợp lệ.

**Alternatives considered**: Trả `NULL` thay vì `''` khi không bị phủ — không chọn để giữ nhất quán
với các cột `COALESCE(..., '')` khác đã có sẵn trong `tmp_result` (ví dụ `Code`, `Name`, `FileId`,
`Description`), tránh DTO phải xử lý `null` lẫn `""`.

## R4 — Cần thêm property `ParentMaster` vào DTO để giá trị thực sự tới client

**Decision**: Thêm `public string? ParentMaster { get; set; }` vào
`ViewCompliancesResponseDto.cs`, ngay sau `MasterCode` (dòng 31 hiện tại).

**Rationale**: `ViewCompliancesRepository.GetViewCompliancesAsync` gọi
`Connection.QueryAsync<ViewCompliancesResponseDto>("CALL sp_load_compl_by_conditions(...)")` —
Dapper map kết quả theo **tên property**, không theo thứ tự cột. Một cột SQL không có property
tương ứng trên DTO sẽ bị Dapper âm thầm bỏ qua (không lỗi, không cảnh báo) — nếu không thêm
property này, `ParentMaster` được MySQL tính ra nhưng không bao giờ tới được API/client, khiến
SC-002 của spec ("covering parent master's code is visible directly on that same row") không đạt
được trong thực tế dù SQL đã đúng.

**Alternatives considered**: Chỉ sửa SQL, để việc thêm DTO cho `/speckit-tasks`/lần dùng sau — bị
loại vì spec yêu cầu rõ ràng dữ liệu phải hiển thị được (SC-002), và đây là 1 dòng thay đổi cực nhỏ,
không có lý do trì hoãn hay tách feature riêng.

## R5 — Giá trị literal `'UseParent'` và tác động lên `ORDER BY Status DESC`

**Decision**: Dùng đúng chuỗi `'UseParent'` (đúng casing người dùng yêu cầu) làm giá trị `Status`
mới, chỉ gán qua UPDATE ở STEP 20b. Không đổi `ORDER BY MasterCode, Status DESC` ở STEP 21 (dòng
1059-1061 hiện tại).

**Rationale**: Theo Assumptions của spec.md, thứ tự sắp xếp không bắt buộc phải đổi trong phạm vi
này. Ghi nhận tác dụng phụ đã biết: so sánh chuỗi alphabet `APPLIED` < `MISSING` < `UseParent`, nên
`ORDER BY Status DESC` sẽ xếp các dòng `UseParent` lên trước `MISSING` (nhưng sau không dòng nào —
`UseParent` là giá trị "lớn nhất" theo alphabet trong 3 giá trị). Đây là hệ quả tất định của quy tắc
sort hiện có, không phải lỗi — nếu sau này cần thứ tự khác (ví dụ đẩy `UseParent` xuống cuối), đó là
1 yêu cầu mới, ngoài phạm vi spec này.

**Alternatives considered**: Đổi `ORDER BY` thành 1 `CASE WHEN Status = 'MISSING' THEN 0 WHEN
Status = 'APPLIED' THEN 1 ELSE 2 END` để chủ động kiểm soát vị trí — không chọn vì spec không yêu
cầu và đây sẽ là 1 thay đổi hành vi UI không được đặc tả, cần xác nhận thêm nếu muốn làm.

**Sự cố phát hiện khi chạy thử (đã sửa)**: Cùng nguyên nhân với sự cố ở R3 — cột `Status` trong
`tmp_result` cũng được `CREATE TEMPORARY TABLE ... AS SELECT` suy ra độ rộng từ 3 literal
`'APPLIED'`/`'MISSING'` (đều 7 ký tự) ở 3 stream UNION ALL bên trong, KHÔNG phải từ giá trị dài nhất
có thể xảy ra sau này. Khi STEP 20b `UPDATE ... SET tr.Status = 'UseParent'` (9 ký tự, dài hơn 7) →
lỗi `Data too long for column 'Status' at row 1`. Sửa bằng cách bọc outer SELECT:
`CAST(Status AS CHAR(20)) AS Status` (dòng ~852) — ép cột `Status` của `tmp_result` có độ rộng
`CHAR(20)` ngay từ đầu, đủ dư cho `'UseParent'` và các giá trị Status khác có thể phát sinh sau này.

## R6 — Rà soát các nơi tiêu thụ `Status`/cột kết quả của SP này để xác nhận không bị vỡ

Đã rà soát toàn bộ nơi tham chiếu tới output của `sp_load_compl_by_conditions` /
`ViewCompliancesResponseDto.Status` trong repo:

| Nơi tiêu thụ | Cách dùng hiện tại | Ảnh hưởng khi có `UseParent` |
|---|---|---|
| `sp_load_compl_by_conditions_count.sql` (proc song song, đếm) | Vẫn `DELETE` các dòng bị phủ để tính count | Không đổi — proc này KHÔNG thuộc phạm vi feature này (Assumptions của spec.md); số lượng đếm và số dòng list có thể lệch nhau sau thay đổi này (list tăng, count không đổi) — đã ghi nhận là chấp nhận được, ngoài phạm vi. |
| `compliance-client/.../ComplianceMissingDrawer.jsx:93` | `dataCompliances.filter(item => item.status === 'MISSING')` | Không vỡ — so sánh chuỗi chính xác, dòng `UseParent` chỉ đơn giản không xuất hiện trong drawer này, giống hành vi hôm nay khi dòng đó còn bị xóa hẳn. |
| `compliance-client/.../useAllCompliancesColumnsSaleOrder.jsx` (cột `statusForUi`) | Tính từ `CountSoCompliancesDto` (đếm riêng: `TotalMissing/TotalApplied/TotalOverdue`), không đọc `Status` từng dòng | Không ảnh hưởng — nguồn dữ liệu khác hẳn, không đi qua `sp_load_compl_by_conditions`. |
| `compl_so_missing` / feature `009-compl-sales-order-missing` (`SendSalesOrderAlertAsync`) | Chỉ insert dòng có `Status == "MISSING"` (so sánh chính xác) | Không vỡ — dòng `UseParent` bị loại giống dòng `APPLIED`, không được insert vào `compl_so_missing`, không gửi alert cho dòng đã được Master cha xử lý. |
| `compliance-master/index.jsx` / `useComplianceMasterColumns.jsx` | Badge status riêng của feature `compliance-management` (`row.status === "Missing"`) | Không liên quan — feature khác, không tiêu thụ output của SP này. |

**Kết luận**: Không có nơi nào crash hoặc hiển thị sai khi thêm giá trị `Status = 'UseParent'`; các
nơi lọc theo `=== 'MISSING'` chỉ đơn giản không thấy các dòng này (đúng như kỳ vọng — chúng không
còn "missing độc lập" nữa). Việc chủ động hiển thị/lọc theo `UseParent` ở UI là việc làm sau, ngoài
phạm vi (xem Assumptions của spec.md).

## R7 — `DatabaseInitializer.InitProcedures` KHÔNG tự áp dụng lại procedure trên DB đã tồn tại

**Finding**: `DatabaseInitializer.InitializeAsync` (`Sqls`/`DatabaseInit/DatabaseInitializer.cs`,
dòng 35-49) chỉ chạy `InitTables`/`InitProcedures` khi database **chưa tồn tại**
(`DatabaseExistsAsync()` trả `false`) — nếu database đã tồn tại, hàm `return` sớm và bỏ qua toàn bộ
init, kể cả `InitProcedures`. Nghĩa là chỉ khởi động lại API **không** áp dụng lại nội dung mới của
`sp_load_compl_by_conditions.sql` lên 1 database dev/staging/production đã tồn tại từ trước.

**Impact**: Khi kiểm thử hoặc triển khai thay đổi này lên 1 DB đã có sẵn, phải chạy trực tiếp file
`.sql` đã sửa lên DB đó (`SOURCE .../sp_load_compl_by_conditions.sql;` hoặc tương đương) — xem
quickstart.md. Đây không phải hành vi mới do feature này gây ra — là cách vận hành đã có sẵn của
`Procedures` (không giống `Migration/*.sql`, thư mục `Procedures` không có cơ chế "chạy 1 lần rồi
đánh dấu đã chạy" — nó luôn `CREATE PROCEDURE` không kèm `DROP ... IF EXISTS`, nên trên DB đã tồn tại
phải tự chạy lại thủ công dù có hay không có feature này).

## R8 — US2: Không sửa `AlertProgressCell.jsx` dùng chung, chỉ sửa `renderCell` của cột `progress`

**Decision**: Logic hiển thị "Use parent" cho US2 (FR-009/FR-010/FR-011) đặt trong `renderCell` của
cột `progress` ("Expiry warning") trong `useComplianceColumns.jsx` (dòng 308-316 hiện tại) — nơi
đã có sẵn 1 nhánh `if (params.row.replacedById === null)` để quyết định gọi `<AlertProgressCell />`
hay hiển thị "Already have new version". KHÔNG thêm prop `status` vào `AlertProgressCell.jsx` và
KHÔNG sửa logic bên trong component đó.

**Rationale**: `AlertProgressCell.jsx` là component dùng chung, được import ở 7 file khác ngoài
`useComplianceColumns.jsx` (`useComplianceMasterColumns.jsx` ở 2 nơi khác nhau,
`RelatedCompliancesGrid.jsx`, `useComplianceColumnsGroup.jsx`, `useMatComplianceColumnsGroup.jsx`,
`useComplianceDetailColumns.jsx`) — những nơi này không nhất thiết có field `status = "UseParent"`
trên row của chúng (một số không xuất phát từ `sp_load_compl_by_conditions`), và spec (FR-008 đến
FR-011) chỉ yêu cầu thay đổi tab "Compliances of Sales order". Sửa trong component dùng chung sẽ
mở rộng phạm vi thay đổi ra 7 nơi không được yêu cầu, vi phạm nguyên tắc "chỉ sửa gap đã xác minh"
(Nguyên tắc III). Giữ logic ở đúng `renderCell` của tab đang nhắm tới là cách sửa hẹp nhất, khớp
đúng phạm vi US2.

**Alternatives considered**: Thêm prop `status` vào `AlertProgressCell` và kiểm tra bên trong nó —
bị loại vì buộc phải rà soát lại toàn bộ 7 nơi gọi khác để đảm bảo không có row nào vô tình có
`status === "UseParent"` (dù không liên quan tới hierarchy coverage) và bị đổi hành vi hiển thị
ngoài ý muốn; rủi ro cao hơn hẳn so với lợi ích (component dùng chung chỉ nhận 2 prop `validTo`/
`numDayAlert`, đổi shape prop của nó là 1 thay đổi rộng hơn cần thiết).

## R9 — US2: Thứ tự ưu tiên giữa "Already have new version" và "Use parent"

**Decision**: Trong `renderCell` của cột `progress`, thứ tự kiểm tra là: (1) nếu
`params.row.replacedById !== null` → "Already have new version" (giữ nguyên, không đổi); (2) else
if `params.row.status === "UseParent"` → "Use parent" (MỚI); (3) else → `<AlertProgressCell />`
(giữ nguyên).

**Rationale**: Khớp đúng FR-011/Assumptions của spec.md — "Already have new version" phản ánh 1 sự
thật độc lập, cụ thể hơn về chính bản ghi Master của dòng đó (đã bị thay thế bởi phiên bản mới), nên
giữ độ ưu tiên cao nhất, không đổi bởi thay đổi này. `status === "UseParent"` chỉ có thể xảy ra khi
dòng đó đang `MISSING` trước khi bị "phủ" (research.md R2b) — tức không xung đột dữ liệu với nhánh
`AlertProgressCell` (dòng không rơi vào (1) hay (2) luôn có `validTo`/`numDayAlert` được đọc đúng
như hôm nay).

**Alternatives considered**: Đặt kiểm tra `status === "UseParent"` trước `replacedById !== null` —
bị loại vì đảo ngược độ ưu tiên spec đã chốt ở FR-011 (Acceptance Scenario 4 của User Story 2).
