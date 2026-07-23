# Quickstart / Validation: EUTR Documents

Hướng dẫn chạy và kiểm thử thủ công feature EUTR Documents end-to-end.

## Tiền đề

- Bảng `eutr_documents` tồn tại trong DB (theo `docs/design/eutr/eutr_db.sql`); migration
  `09_migrate_eutr_documents_name.sql` đã chạy để cột `Name` là `VARCHAR(255)` (không còn
  `BIGINT`).
- Backend đã build được với controller mới `api/eutr-documents` (CRUD, không có import/export).
- **Menu + quyền được tạo động & phân quyền trong DB** (không seed bằng code): tạo menu code
  `eutr-documents` (url `/eutr/documents`) và các quyền `EutrDocuments.ReadAll / ReadOne / Create
  / Update / Delete`, rồi gán cho role/user đăng nhập (routing backend-driven — nếu thiếu
  menu/quyền trong DB, màn hình sẽ không truy cập được).
- **(Update 6)** Cấu hình `SharePointEutrPath` đã được thêm vào `appsettings.json`/
  `appsettings.Development.json` (khóa mới, cạnh `SharePointCompPath`); nếu thiếu, endpoint
  `POST /api/sharepoint/eutr-upload-multi` sẽ báo lỗi cấu hình khi gọi. Backend đã có quyền truy cập
  SharePoint hợp lệ (cùng cấu hình Graph API dùng chung cho các endpoint `api/sharepoint/*` khác).
- **(Update 7)** Migration `10_add_stepid_to_eutr_references.sql` đã chạy để bảng `eutr_references`
  có cột `StepId` (BIGINT UNSIGNED NULL, FK tới `eutr_steps.Id`). Có ít nhất vài bản ghi trong
  `eutr_master_documents` (feature `002-eutr-masters`) với `Prefix` đã biết trước (ví dụ `Prefix =
  "INV"` gắn `StepId = 5`) để dùng làm tên file test (vd. `INV_test.pdf`) khớp đúng prefix.
- **(Update 8)** Không cần thêm tiền đề DB/cấu hình nào — chỉ cần đã có ít nhất 1 document được tạo
  qua nút Upload (kèm bản ghi `eutr_references` tương ứng, xem tiền đề Update 7) để quan sát được
  Step name/Type (danh sách) và File name/Step name (List PO) hiển thị dữ liệu thật thay vì trống.
- **(Update 10)** Không cần thêm tiền đề DB/cấu hình nào — chỉ cần backend có quyền truy cập
  SharePoint hợp lệ (đã có sẵn từ Update 6/7) để đọc lại nội dung file qua `FileId`. Cần ít nhất 1
  document có `FileId` (tạo qua nút Upload, xem tiền đề Update 7) để kiểm thử icon View mở được
  popup xem trước; và ít nhất 1 document KHÔNG có `FileId` (tạo qua form Save nhập tay) để kiểm thử
  icon View bị vô hiệu hóa.
- **(Update 11)** Bảng `eutr_reference_details` đã tồn tại sẵn trong DB (không cần migration —
  xem `data-model.md`). Cần ít nhất vài bản ghi `eutr_steps` (feature `001-eutr-steps`) để chọn
  trong dropdown Step ở popup Assign condition. Cấu hình `SharePointEutrPath` (đã có từ Update 6)
  tiếp tục dùng cho thư mục cố định `UploadManual` — không cần khóa cấu hình mới.
- **(Update 12/13)** Không cần thêm tiền đề DB/cấu hình nào — chỉ cần đã có sẵn ít nhất 1 document
  Type="PO" (từ Update 6/7) và ít nhất 1 document Type="Upload manual" (từ Update 11) để kiểm thử
  Edit rẽ nhánh theo Type.

## Chạy

```bash
# Backend
cd compliance-sys-api
dotnet run --project src/ComplianceSys.Api

# Frontend
cd compliance-client
npm install   # nếu chưa cài
npm run dev
```

Mở SPA, đăng nhập, vào menu **EUTR documents** (đường dẫn `/eutr/documents`).

## Kịch bản kiểm thử (ánh xạ Acceptance Scenarios trong spec)

1. **Xem danh sách (US1)**: Mở `/eutr/documents` → thấy breadcrumb "EUTR > EUTR documents" và
   bảng với cột File name, Step name, Conditions, Type, Valid from, Valid to, Created by, Created
   date, Action. Cột **Conditions luôn trống** cho mọi dòng (không có liên kết "[View detail]"
   nào — không đổi). Dữ liệu tải từ `POST /eutr-documents/get-all`. Danh sách rỗng → hiển thị
   "No data".
1a. **Step name/Type nạp dữ liệu thật (US1, Update 8, FR-034/FR-035)**: Với một document được tạo
   qua nút Upload (có bản ghi `eutr_references` liên kết, xem tiền đề Update 7) → cột **Step name**
   hiển thị đúng tên Step tương ứng (không trống) và cột **Type** hiển thị đúng nhãn "PO" (khớp
   `RefType = 0`, vì khu Upload chỉ tồn tại ở Screen1/Type=PO). Với một document tạo qua form Save
   nhập tay (không qua Upload, không có `eutr_references` nào) → cột Step name/Type vẫn hiển thị
   trống như trước Update 8. Nếu file đã upload khớp Prefix của nhiều `StepId` (xem kịch bản 9n) →
   cột Step name của document đó hiển thị **nhiều** Step name (dạng chip, có "+N more"/tooltip khi
   vượt quá số lượng hiển thị trực tiếp).
2. **Thêm mới (US2)**: Nhấn nút **Add** trên toolbar → điều hướng sang **trang riêng**
   `/eutr/documents/add` (không phải popup, không có control chọn/upload file). Nhập File name,
   Valid from/to (tùy chọn) → Save → quay về danh sách, dòng mới xuất hiện đúng thông tin, Created
   by/date có giá trị. Để trống File name → bị chặn, hiện lỗi, không tạo bản ghi.
3. **Back trên trang Add (US2/FR-006a)**: Đang ở trang Add, nhập một số thông tin nhưng CHƯA Save
   → nhấn **Back** → điều hướng thẳng về danh sách, KHÔNG tạo bản ghi, KHÔNG hiện cảnh báo xác
   nhận.
4. **Sửa (US3)**: Trên 1 dòng, nhấn **Edit** → mở **popup** (không phải trang riêng) cho phép sửa
   File name, Valid from, Valid to → Save → giá trị cập nhật trong bảng. Để trống File name → bị
   chặn, không lưu. Nhấn Cancel → đóng popup, không thay đổi gì.
5. **Xóa (US4)**: Delete trên 1 dòng → xác nhận → dòng biến mất (hard delete). Chọn nhiều dòng →
   xóa nhiều → tất cả biến mất. Hủy ở hộp xác nhận → không xóa dòng nào.
5a. **Xóa document kèm dọn `eutr_references` (US4, Update 9, FR-039)**: Chuẩn bị 1 document có ít
   nhất 1 bản ghi `eutr_references` liên kết (upload 1 file qua Screen1 — xem kịch bản 9g, kiểm tra
   DB có dòng `eutr_references` với `DocumentId` = id document đó). Trên danh sách EUTR documents,
   nhấn Delete trên đúng document đó → xác nhận → dòng biến mất khỏi bảng. Kiểm tra trực tiếp DB:
   (a) document đó không còn trong `eutr_documents`; (b) **không còn dòng nào** trong
   `eutr_references` có `DocumentId` = id đã xóa (kể cả khi document có nhiều dòng `eutr_references`
   do khớp nhiều `StepId` — xem kịch bản 9n).
5b. **Xóa nhiều document, một số có `eutr_references`, một số không (US4, Update 9, FR-040)**:
   Chọn nhiều document để xóa cùng lúc, trong đó ít nhất 1 document có `eutr_references` liên kết và
   1 document không có (tạo qua form Save nhập tay) → xác nhận xóa nhiều → tất cả document đã chọn
   biến mất khỏi bảng. Kiểm tra DB: mọi document đã chọn không còn trong `eutr_documents`, và không
   còn dòng `eutr_references` nào trỏ tới bất kỳ `DocumentId` đã xóa. Document không có
   `eutr_references` nào bị xóa bình thường (không lỗi, không có gì để dọn thêm).
5c. **Rollback khi dọn `eutr_references` thất bại (US4, Update 9, FR-040)**: (Khó mô phỏng thủ
   công — có thể bỏ qua nếu không dựng được lỗi DB tạm thời, ví dụ tạm khóa quyền DELETE trên bảng
   `eutr_references` hoặc ngắt kết nối DB giữa 2 bước xóa) Nếu bước xóa `eutr_references` thất bại
   trong khi xóa 1 document, xác nhận: document đó **KHÔNG** bị xóa (vẫn còn trong `eutr_documents`
   và vẫn hiển thị trong danh sách), hệ thống báo lỗi rõ ràng (không phải xóa "âm thầm" thất bại).
   Nếu lỗi này xảy ra trong lượt xóa nhiều document, xác nhận các document khác trong cùng lượt
   (không gặp lỗi) vẫn bị xóa thành công — không bị rollback theo document lỗi.
6. **Icon View mở xem file thật (US5, Update 10, FR-042)**: Trên dòng của một document **có**
   `FileId` (tạo qua nút Upload — xem tiền đề Update 7), cột Action hiển thị icon **View** ở trạng
   thái active; nhấn vào → mở popup xem trước file (kiểm tra tab Network: có request
   `GET /api/eutr-documents/get-file-by-idref?idRef=<fileId>`), nội dung file hiển thị đúng theo
   loại file (PDF/DOCX/XLSX/ảnh), có nút Download hoạt động (file tải xuống đúng tên/nội dung) và
   nút Close đóng popup. Trên dòng của một document **KHÔNG có** `FileId` (tạo qua form Save nhập
   tay) → icon View hiển thị ở trạng thái vô hiệu hóa (mờ, không click được) kèm tooltip "No file
   to view" khi hover.
6a. **Popup xem trước lỗi/không hỗ trợ (Update 10, FR-041)**: (Khó mô phỏng thủ công — có thể bỏ
   qua nếu không dựng được lỗi mạng/máy chủ tạm thời cho SharePoint) Nếu request
   `get-file-by-idref` thất bại, popup hiển thị thông báo lỗi thân thiện thay vì treo giao diện;
   người dùng vẫn đóng được popup bằng nút Close.
7. **Trùng File name (Edge Case)**: Tạo hoặc sửa một document thành File name trùng với document
   khác đã có → hệ thống **vẫn cho phép lưu bình thường** (không cảnh báo trùng).
8. **Quyền**: Đăng nhập user thiếu quyền Create/Update/Delete → nút tương ứng ẩn/disable.
9. **Type = PO trên trang Add — PO name nối API thật (US2, Update 4)**: Trên trang Add, thấy thêm
   trường **Type** (mặc định "PO"). Với Type = "PO" → hiển thị bảng **List PO** (cột PO name, File
   name, Step name) và nút **Upload** (thay khu "Drag and drop files to upload" từ Update 6). Kiểm
   tra tab Network của DevTools: có 1 request `POST /api/dynamics/reference?...&refType=15` khi
   bảng render — cột **PO name** hiển thị đúng danh sách trả về từ D365 entity
   `RSVNEutrPurchOrders`. Cột **File name**/**Step name** hiển thị theo PO đang được chọn — xem kịch
   bản 9p (Update 8); trước khi chọn dòng PO nào, bảng chi tiết này trống. **(Update 10)** Mỗi dòng
   trong bảng chi tiết này (= 1 file đã upload cho PO đang chọn) có icon View/Delete riêng — xem
   kịch bản 9r/9s.
9a. **List PO rỗng/lỗi (Update 4, FR-017, SC-010)**: Nếu D365 trả về danh sách rỗng cho `refType =
    15`, bảng List PO hiển thị trạng thái trống ("No data") thay vì lỗi. Nếu request `refType = 15`
    thất bại (ví dụ ngắt kết nối D365), bảng List PO hiển thị thông báo lỗi thân thiện; các trường
    File name/Valid from/Valid to và nút Save/Back trên trang Add vẫn hoạt động bình thường (không
    bị khoá bởi lỗi này).
9b. **refType = 16 chỉ tồn tại ở backend (Update 4, FR-022)**: Gọi trực tiếp
    `POST /api/dynamics/reference` với `refType = 16` (qua Postman/DevTools, không qua UI) → xác
    nhận trả về đúng dữ liệu `RSVNEutrSalesOrderPurchases` theo `ComplDynReferenceResponseDto`.
    Xác nhận không có màn hình nào trong `EutrDocumentsAdd.jsx` gọi refType này (kiểm tra tab
    Network khi thao tác toàn bộ trang Add — không thấy request nào với `refType=16`).
9c. **Ô tìm kiếm PO lọc qua API (US2, Update 5, FR-023)**: Với Type = "PO", gõ một từ khóa khớp
    tên/mã một PO thật vào ô tìm kiếm phía trên List PO → sau khoảng debounce ngắn (~500ms), tab
    Network hiện thêm 1 request `POST /api/dynamics/reference?...&refType=15` kèm body filter
    `Name`/`Code` chứa từ khóa đó; danh sách PO cập nhật đúng theo kết quả trả về từ server (không
    chỉ số PO đã tải trước đó). Xóa hết từ khóa → danh sách tải lại đầy đủ (request `refType=15`
    không kèm filter).
9d. **Tìm kiếm PO không khớp / lỗi (Update 5, FR-023)**: Nhập từ khóa không khớp PO nào → danh sách
    hiển thị "No data" (không phải lỗi). Nếu request tìm kiếm thất bại (lỗi mạng/máy chủ) → hiển
    thị thông báo lỗi thân thiện, các trường/nút khác trên trang Add vẫn hoạt động bình thường.
9e. **Nút Upload vô hiệu hóa khi chưa chọn PO (Update 6, FR-024)**: Mở trang Add với Type = "PO",
    chưa click dòng PO nào → nút **Upload** ở trạng thái disabled (không thể nhấn).
9f. **Chọn PO kích hoạt Upload (Update 6, FR-024)**: Click một dòng bất kỳ trong List PO → dòng đó
    được tô nổi bật (đang chọn) và nút Upload chuyển sang trạng thái khả dụng. Click dòng PO khác →
    lựa chọn chuyển sang dòng mới (chỉ 1 dòng được chọn tại một thời điểm).
9g. **Upload nhiều file hợp lệ thành công (Update 6, FR-025/FR-027/FR-028/FR-029; Update 7,
    FR-032/FR-033)**: Với một PO đã chọn, nhấn Upload → hộp thoại chọn file mở ra, chọn 2-3 file
    hợp lệ (PDF/DOC/DOCX/XLS/XLSX/JPG/PNG, mỗi file < 10MB, VÀ tên file có prefix khớp một bản ghi
    trong `eutr_master_documents`, vd. `INV_test.pdf` nếu `Prefix = "INV"` đã tồn tại) → xác nhận.
    Kiểm tra tab Network: có 1 request `POST /api/sharepoint/eutr-upload-multi` (multipart, field
    `files` + `poCode`). Sau khi hoàn tất, mở lại danh sách EUTR documents (`/eutr/documents`) →
    xác nhận có thêm đúng số document mới tương ứng, mỗi document có File name = tên file đã chọn,
    Valid from = ngày hôm nay, Valid to = ngày rất xa trong tương lai (`9999-12-31`), Created
    by/date có giá trị. Snackbar hiển thị kết quả thành công. Kiểm tra trực tiếp DB: bảng
    `eutr_references` có đúng 1 dòng mới cho mỗi file (`DocumentId` = id document vừa tạo, `StepId`
    = StepId của bản ghi `eutr_master_documents` đã khớp, `RefType = 0`, `RefValue` = mã PO đã
    chọn).
9h. **File sai định dạng/quá 10MB bị loại (Update 6, FR-026, FR-030)**: Nhấn Upload, chọn kèm 1 file
    sai định dạng (vd. `.zip`) hoặc 1 file > 10MB lẫn cùng các file hợp lệ khác → xác nhận: file
    không hợp lệ bị loại kèm thông báo lỗi rõ ràng (liệt kê tên file + lý do), các file hợp lệ còn
    lại vẫn được upload và tạo document bình thường (kiểm tra danh sách EUTR documents).
9i. **Lỗi một phần trong batch không làm mất các file thành công (Update 6, FR-030)**: (Kiểm thử
    thủ công/khó mô phỏng lỗi mạng giữa chừng — có thể bỏ qua nếu không dựng được môi trường lỗi
    SharePoint tạm thời) Nếu một file trong batch thất bại do lỗi SharePoint trong khi các file khác
    thành công, xác nhận các document của file thành công vẫn xuất hiện trong danh sách, và response/
    snackbar liệt kê rõ file nào lỗi.
9j. **Thư mục SharePoint theo PO được tái sử dụng (Update 6, FR-028)**: Upload file cho cùng một PO
    lần thứ hai (PO đã có thư mục từ lần upload trước ở 9g) → xác nhận request vẫn thành công (không
    lỗi do trùng thư mục), file mới được thêm vào cùng thư mục PO đó trên SharePoint (kiểm tra qua
    Graph Explorer/SharePoint UI nếu có quyền truy cập, hoặc qua log backend).
9k. **Giao diện khu Upload theo mẫu `upload.png` (Update 7, FR-031)**: Với một PO đã chọn, quan sát
    khu Upload — thấy tiêu đề "Upload File", khung viền nét đứt lớn với icon đám mây và chữ "Drop
    file here or click to browse", một dòng phụ và hàng chip nhỏ bên dưới liệt kê đúng định dạng/
    kích thước **thật** đang áp dụng (PDF, DOC/DOCX, XLS/XLSX, JPG/PNG, Max 10MB) — KHÔNG phải "PDF,
    DOCX, XLSX, max 50MB" như trong ảnh mẫu gốc. Khi chưa chọn PO, toàn bộ khu vực này hiển thị mờ
    (disabled) và không phản hồi click/thả file.
9l. **Kéo-thả file thật hoạt động giống click (Update 7, FR-031)**: Với một PO đã chọn, kéo 1 file
    hợp lệ (đúng định dạng/kích thước và có prefix khớp) từ File Explorer/Finder và thả vào khung
    Upload (không click) → xác nhận hệ thống xử lý y hệt như khi click chọn file qua hộp thoại: có
    request `POST /api/sharepoint/eutr-upload-multi`, document mới xuất hiện đúng trong danh sách,
    kèm bản ghi `eutr_references` tương ứng.
9m. **File không khớp prefix nào bị chặn (Update 7, FR-032)**: Chọn/thả một file có tên KHÔNG bắt
    đầu bằng bất kỳ `Prefix` nào tồn tại trong `eutr_master_documents` (vd. `random-name.pdf`) →
    xác nhận: file đó bị loại, thông báo lỗi liệt kê rõ tên file (vd. "No matching prefix found"),
    KHÔNG có file mới nào xuất hiện trên SharePoint (không gọi upload), KHÔNG có document/eutr_references
    nào được tạo cho file này.
9n. **Prefix khớp nhiều Step → nhiều dòng `eutr_references` (Update 7, FR-032/FR-033)**: Chuẩn bị
    (qua DB hoặc màn `002-eutr-masters`) 2 bản ghi `eutr_master_documents` có `Prefix` đều là tiền
    tố hợp lệ của cùng một tên file test nhưng khác `StepId` (vd. `Prefix = "INV"` → `StepId = 5` và
    `Prefix = "INV2026"` → `StepId = 7`, file test tên `INV2026_report.pdf`) → upload file đó →
    xác nhận upload thành công (không bị chặn), document được tạo bình thường, và bảng
    `eutr_references` có **2 dòng mới** cùng `DocumentId` nhưng khác `StepId` (5 và 7), cùng
    `RefType = 0` và cùng `RefValue` (mã PO đã chọn).
9o. **Ghi `eutr_references` thất bại → rollback cả document (Update 7, FR-033)**: (Khó mô phỏng thủ
    công — có thể bỏ qua nếu không dựng được lỗi DB tạm thời khi ghi `eutr_references`, ví dụ tạm
    thời xóa cột `StepId` hoặc ngắt kết nối DB giữa 2 bước ghi) Nếu bước ghi `eutr_references` thất
    bại ngay sau khi bước ghi `eutr_documents` (trong cùng transaction) thành công, xác nhận: file
    đó được báo `success: false` trong response, và **không có** document mồ côi nào xuất hiện
    trong danh sách EUTR documents cho file này (transaction đã rollback toàn bộ, không chỉ phần
    `eutr_references`).
9p. **File name/Step name ở List PO nạp dữ liệu thật (US2, Update 8, FR-037/FR-038)**: Sau khi
    upload thành công cho một PO (kịch bản 9g), click chọn lại đúng PO đó trong List PO → kiểm tra
    tab Network: có 1 request `POST /api/eutr-documents/list-po-references` (body
    `{ "poCodes": ["<mã PO đó>"] }`) → bảng chi tiết (cạnh danh sách PO) hiển thị đúng 1 dòng cho
    mỗi file đã upload cho PO này, với **File name** = tên file gốc và **Step name** = tên Step đã
    khớp Prefix (không còn placeholder tĩnh "File name"/"Step Name" như trước Update 8). Click chọn
    một PO khác **chưa từng** được upload file nào → bảng chi tiết hiển thị "No data" (không phải
    lỗi, không còn 1 dòng placeholder tĩnh).
9q. **Nhiều Step name cho một file (US1 + US2, Update 8)**: Với file test đã tạo ở kịch bản 9n
    (khớp Prefix của 2 `StepId` khác nhau) → cả 2 nơi cùng hiển thị đúng: (a) trong bảng chi tiết
    List PO (trang Add, PO tương ứng đang chọn), dòng của file đó hiển thị **2** Step name; (b)
    trong danh sách EUTR documents (`/eutr/documents`), dòng của document đó cũng hiển thị đúng
    **2** Step name — cả hai nơi dùng cùng cách hiển thị nhiều giá trị (chip + "+N more"/tooltip khi
    vượt quá số lượng hiển thị trực tiếp).
9r. **View từng file ở List PO (US2, Update 10, FR-043)**: Click chọn lại đúng PO đã upload file ở
   kịch bản 9g → bảng chi tiết hiển thị 1 dòng cho mỗi file đã upload. Nhấn icon **View** trên một
   dòng bất kỳ → mở popup xem trước đúng file đó (kiểm tra tab Network: request
   `GET /api/eutr-documents/get-file-by-idref?idRef=<fileId của document đó>`), nội dung hiển thị
   đúng, có nút Download/Close hoạt động — giống hành vi ở kịch bản 6.
9s. **Delete từng file ở List PO (US2, Update 10, FR-044/FR-045)**: Trên cùng bảng chi tiết (PO có
   ≥ 2 file đã upload), nhấn icon **Delete** trên một dòng cụ thể → hộp thoại xác nhận hiện ra →
   xác nhận → kiểm tra: (a) dòng đó biến mất khỏi bảng chi tiết List PO ngay lập tức, các dòng khác
   (file khác của cùng PO) KHÔNG bị ảnh hưởng; (b) mở lại danh sách EUTR documents chính
   (`/eutr/documents`) → document tương ứng KHÔNG còn xuất hiện; (c) kiểm tra trực tiếp DB: document
   đó không còn trong `eutr_documents`, không còn dòng nào trong `eutr_references` có `DocumentId`
   tương ứng (giống hành vi Delete đã kiểm ở kịch bản 5a); (d) file đó **vẫn còn tồn tại** trên
   SharePoint (kiểm tra qua Graph Explorer/SharePoint UI hoặc log backend nếu có quyền truy cập) —
   xác nhận không có request nào xóa file SharePoint được gọi (tab Network không có request tới
   `POST /api/sharepoint/delete-file` hay tương đương).

10. **Type = Upload manual — khu Upload File thật (US6, Update 11, FR-046/FR-047)**: Chuyển Type
    sang "Upload manual" → layout đổi ngay sang khu **Upload File** (giống mẫu Screen1) LUÔN khả
    dụng (không cần chọn gì trước, khác Screen1) + nút "Assign condition" + bảng danh sách file
    thật. Click hoặc kéo-thả 1-2 file hợp lệ (PDF/DOC/DOCX/XLS/XLSX/JPG/PNG, ≤10MB) → kiểm tra tab
    Network: có request `POST /api/sharepoint/eutr-upload-manual-multi` (multipart, chỉ field
    `files`, KHÔNG có `poCode`). Sau khi hoàn tất, các file vừa upload xuất hiện ngay trong bảng
    danh sách bên dưới (không cần tải lại trang). Kiểm tra DB: mỗi file tạo đúng 1 dòng
    `eutr_documents` (FileId từ SharePoint, ValidFrom=hôm nay, ValidTo=`9999-12-31`) và **KHÔNG có**
    dòng `eutr_references` nào cho các document này.
10a. **File sai định dạng/quá 10MB ở Screen2 (Update 11, FR-046)**: Chọn kèm 1 file sai định dạng
    hoặc quá 10MB lẫn file hợp lệ ở khu Upload File Screen2 → file không hợp lệ bị loại kèm thông
    báo lỗi, file hợp lệ vẫn được upload — giống hành vi FR-026 ở Screen1 (không cần prefix khớp).
11. **Danh sách "chưa gán" (US6, Update 11, FR-048)**: Quan sát bảng danh sách file ở Screen2 → xác
    nhận hiển thị mọi document trong `eutr_documents` **chưa có** `eutr_references` nào (bao gồm cả
    document tạo qua form Save nhập tay lẫn qua khu Upload File Screen2), KHÔNG bao gồm document
    Type="PO" (đã có `eutr_references` ngay khi upload). Kiểm tra tab Network: request
    `POST /api/eutr-documents/get-unassigned`.
11a. **View/Delete trên bảng "chưa gán" (US6, Update 11, FR-049)**: Nhấn icon View trên 1 dòng → mở
    popup xem trước file thật (giống kịch bản 6). Nhấn icon Delete trên 1 dòng, xác nhận → document
    đó biến mất khỏi bảng và khỏi `eutr_documents`; file thật trên SharePoint vẫn còn (giống kịch
    bản 9s).
11b. **Assign condition — chọn nhiều file, gán Step/Conditions (US6, Update 11/13, FR-050 đến
    FR-054)**: Tick chọn 2 file trong bảng "chưa gán" → nút "Assign condition" chuyển khả dụng →
    nhấn vào → popup mở, hiển thị đúng 2 file đã chọn (read-only, không checkbox). Dòng đầu "Step"
    hiển thị dropdown — thử nhấn Save ngay (chưa chọn Step) → bị chặn kèm lỗi (FR-052). Chọn 1 Step
    → nhấn Save lần nữa (vẫn chưa có dòng Conditions type) → **vẫn bị chặn** kèm lỗi yêu cầu thêm
    Conditions type (Update 13 correction). Nhấn "Add condition" → thêm 1 dòng, chọn Conditions
    type = "PO" → ô Condition value tải dữ liệu qua `POST /api/dynamics/reference?refType=15`,
    chọn 2 giá trị PO. Nhấn "Add condition" lần 2 → xác nhận dropdown Conditions type của dòng mới
    **disable** sẵn "PO" (đã dùng ở dòng trên), chỉ "Vendor" chọn được (Update 13, FR-051) — chọn
    "Vendor" (`refType=14`), chọn 1 giá trị. Nhấn Save → kiểm tra tab Network: request
    `POST /api/eutr-documents/assign-conditions`. Sau khi lưu: popup đóng, 2 file vừa gán biến mất
    khỏi bảng "chưa gán"; mở danh sách EUTR documents chính → cả 2 document hiển thị Type="Upload
    manual", Step name đúng, và cột **Conditions** hiển thị "PO: <giá trị 1>, <giá trị 2>" và
    "Vendor: <giá trị>" (theo mẫu `view.png`). Kiểm tra DB: mỗi document có đúng 1 dòng
    `eutr_references` (RefType=1, RefValue=null) và đúng 3 dòng `eutr_reference_details` (2 PO + 1
    Vendor).
12. **Edit — Type="PO" thêm sửa Step (US3, Update 12/13, FR-055)**: Trên danh sách chính, tìm 1
    document Type="PO" → nhấn Edit → popup đơn giản mở ra với File name/Valid from/Valid to **và
    thêm trường Step** hiển thị đúng Step hiện tại (nếu document có nhiều Step liên kết do khớp
    nhiều prefix — Update 7 — dropdown hiển thị Step ứng với `eutr_references.Id` nhỏ nhất, Update
    13). Đổi sang Step khác → Save → kiểm tra tab Network có thêm request
    `PUT /eutr-documents/{id}/step`; cột Step name trên danh sách chính cập nhật đúng thành **chỉ**
    Step mới (không còn Step cũ nếu trước đó có nhiều).
13. **Edit — Type="Upload manual" mở popup Assign condition để sửa (US3, Update 12, FR-056 đến
    FR-058)**: Tìm 1 document Type="Upload manual" (đã gán ở kịch bản 11b) → nhấn Edit → xác nhận
    **KHÔNG** mở popup đơn giản, mà mở popup Assign condition ở chế độ sửa (kiểm tra tab Network:
    request `GET /eutr-documents/{id}/condition-assignment`), nạp sẵn đúng Step và các dòng
    Conditions type/value hiện có. Đổi Step, xóa dòng "Vendor", thêm 1 giá trị PO mới vào dòng "PO"
    → Save → kiểm tra tab Network: request `PUT /eutr-documents/{id}/condition-assignment`. Sau khi
    lưu: cột Step name/Conditions trên danh sách chính cập nhật đúng theo thay đổi (dòng "Vendor" đã
    biến mất khỏi Conditions). Thử Save khi bỏ hết dòng Conditions type (chỉ còn Step) → bị chặn
    kèm lỗi, dữ liệu cũ giữ nguyên (không mất Step/Conditions đã có).
14. **Cột Type lấy nhãn thật từ `eutr_reference_types` (Update 14, FR-034)**: Trước tiên, xác nhận
    bảng `eutr_reference_types` đã có đúng 2 dòng `Id=0` → "PO" và `Id=1` → "Upload manual" (chạy
    migration `14_seed_eutr_reference_types.sql`, hoặc kiểm tra qua màn hình CRUD của feature
    `006-eutr-reference-types` tại `/eutr/reference-types`). Mở danh sách EUTR documents chính →
    kiểm tra tab Network: request `POST /api/eutr-documents/get-all`, xác nhận mỗi item response có
    thêm field `typeName`. Với 1 document Type="PO" (tạo qua nút Upload ở Screen1, kịch bản 8) →
    cột Type trên grid hiển thị đúng "PO" (lấy từ `typeName`, không còn tra `TAKE_FROM_OPTIONS` ở
    client). Với 1 document Type="Upload manual" (kịch bản 11b) → cột Type hiển thị đúng "Upload
    manual". Với 1 document tạo qua form Save nhập tay (chưa từng qua Upload/Assign condition) → cột
    Type tiếp tục hiển thị trống (`typeName = null`), không lỗi. Xác nhận trang Add — dropdown
    **Type** (chọn PO/Upload manual để quyết định layout Screen1/Screen2) **không đổi hành vi** —
    vẫn đúng 2 lựa chọn hard-code như trước Update 14 (ngoài phạm vi thay đổi này, xem FR-016).
15. **Popup Add hợp nhất Type/Step/Value/Upload (Update 15/16, FR-059 đến FR-070)** — *(nhánh Type =
    "PO" ở kịch bản này bị **thay thế bởi kịch bản 16, Update 17** — xem bên dưới; giữ nguyên phần
    còn lại của kịch bản 15/15a-15e cho các Type khác)*: Trên danh sách chính, nhấn nút **Add** → xác
    nhận mở **popup** "Add EUTR documents" (KHÔNG điều hướng sang `/eutr/documents/add`). Kiểm tra tab
    Network: dropdown **Type** gọi `GET /api/eutr-reference-types` (trả toàn bộ bản ghi, không chỉ 2
    lựa chọn PO/Upload manual). Chọn Type = "Invoice" → ô Value hiển thị gợi ý qua
    `POST /api/dynamics/reference?refType=15`; gõ hoặc chọn 1 mã PO → 1 chip xuất hiện. Chọn combobox
    **Step** (gọi `GET /api/eutr-steps`). Nhấn Upload trong khi thiếu Step → nút vẫn vô hiệu hóa; chọn
    Step xong, Upload khả dụng → chọn 2 file hợp lệ → xác nhận request
    `POST /api/sharepoint/eutr-upload-multi-by-type` (kiểm tra body có `typeId`/`typeName`/`stepId`/
    `refValues`) → popup **tự đóng** ngay sau khi có kết quả (FR-070); danh sách chính hiển thị 2
    document mới, kiểm tra DB: mỗi document có đúng 1 dòng `eutr_references` (`RefType` = `Id` thật
    của Type "Invoice" đã chọn — KHÔNG cứng `0`/`1`), thư mục SharePoint = `Invoice` (cố định).
15a. **Type = "Invoice"/"Delivery note" — nhiều chip, thư mục cố định**: Mở lại popup Add, chọn Type =
    "Invoice" → ô Value vẫn gọi `refType=15` (PO). Dán chuỗi `"PO1, PO2\nPO3"` trong đó PO1/PO2 khớp
    dữ liệu thật còn PO3 không khớp → xác nhận đúng 2 chip (PO1, PO2) được thêm, cảnh báo hiển thị cho
    PO3, và KHÔNG bị giới hạn 1 chip (khác Type="PO"). Upload 1 file hợp lệ → kiểm tra file được lưu
    vào thư mục cố định `{SharePointEutrPath}/Invoice` (không theo giá trị chip); document mới có
    đúng 2 dòng `eutr_references` (1 dòng/chip, cùng `DocumentId`/`StepId`/`RefType`, khác `RefValue`).
    Lặp lại nhanh với Type = "Delivery note" → xác nhận thư mục `DeliveryNote`.
15b. **Type = "Vendor" — 1 chip, thư mục theo giá trị**: Chọn Type = "Vendor" → ô Value gọi
    `POST /api/dynamics/reference?refType=14`; chọn 1 Vendor → Upload → xác nhận thư mục SharePoint
    đặt tên theo mã Vendor đã chọn (giống cách PO), và bị giới hạn đúng 1 chip như Type="PO".
15c. **Type không có nguồn gợi ý (vd. "General agreement")**: Chọn Type này → ô Value là ô nhập tự do,
    KHÔNG có request nào tới `POST /api/dynamics/reference`; gõ 2 giá trị tùy ý (không cần khớp dữ
    liệu nào) → cả 2 đều thành chip; Upload → thư mục SharePoint = `GeneralAgreement` (cố định).
15d. **Đổi Type reset chip**: Sau khi đã có sẵn ít nhất 1 chip, đổi dropdown Type sang giá trị khác →
    xác nhận vùng chọn trở về rỗng ngay lập tức.
15e. **Edit không đổi (Update 16, Q1)**: Trên danh sách chính, nhấn Edit trên 1 document Type="PO" và
    1 document Type="Upload manual" (bất kỳ, kể cả tạo qua popup Add mới) → xác nhận hành vi Edit vẫn
    đúng như kịch bản 12/13 (không có thay đổi nào do popup Add mới).
16. **Type = "PO" trong popup Add: bỏ Step thủ công, xác định tự động theo prefix file (Update 17,
    FR-071 đến FR-075)**: Mở popup Add, chọn Type = "PO" → xác nhận combobox **Step KHÔNG hiển thị**
    trong popup (khác kịch bản 15, nơi Type="Invoice" vẫn có Step). Gõ hoặc chọn 1 mã PO ở ô Value →
    chip xuất hiện ngay và ô Value trở về trống (FR-071); thử thêm 1 giá trị nữa → vẫn bị chặn (giới
    hạn 1 chip, không đổi so với Update 15/FR-064). Nút Upload khả dụng ngay khi có 1 chip (không cần
    Step). Chọn 2 file có tên khớp `Prefix` của 2 `StepId` khác nhau trong `eutr_master_documents`
    (dữ liệu do feature `002-eutr-masters` quản lý) → nhấn Upload → kiểm tra tab Network xác nhận
    request gọi **`POST /api/sharepoint/eutr-upload-multi`** (endpoint gốc từ Update 6/7 — KHÔNG phải
    `eutr-upload-multi-by-type`), body chỉ có `Files`/`PoCode` (không có `stepId`); popup tự đóng
    (FR-070 không đổi). Kiểm tra DB: mỗi document mới có bản ghi `eutr_references` với `StepId` đúng
    theo Prefix khớp tên file đó (không phải Step chọn thủ công, vì không có control này), `RefType =
    0` (khớp `eutr_reference_types.Id=0`/`Name="PO"` đã seed từ Update 14).
16a. **File không khớp prefix nào (Update 17)**: Vẫn ở Type = "PO", chọn 1 file có tên KHÔNG khớp bất
    kỳ `Prefix` nào trong `eutr_master_documents` → Upload → xác nhận file đó bị loại kèm cảnh báo rõ
    ràng, KHÔNG tạo document/`eutr_references` nào cho file này (không chặn các file hợp lệ khác nếu
    upload cùng lượt) — giống hành vi đã có ở Update 7 trước khi có popup Add hợp nhất.
16b. **Type khác "PO" không đổi (Update 17)**: Lặp lại nhanh với Type = "Vendor" (hoặc "Invoice") →
    xác nhận combobox Step vẫn hiển thị và bắt buộc chọn như kịch bản 15/15a/15b, và request Upload
    vẫn gọi `POST /api/sharepoint/eutr-upload-multi-by-type` (không đổi).
17. **`RefType` ghi đúng theo `TypeId` khi Type = "PO" (Update 18, FR-076/FR-077)**: Trước tiên, mở
    màn hình quản lý reference type (feature `006-eutr-reference-types`) và ghi lại `Id` thật của bản
    ghi có `Name` = "PO" (ví dụ `Id = 3`). Quay lại `/eutr/documents`, mở popup Add, chọn Type = "PO",
    thêm 1 chip mã PO, chọn 1 file có tên khớp `Prefix` trong `eutr_master_documents`, nhấn Upload →
    mở tab Network, xác nhận request `POST /api/sharepoint/eutr-upload-multi` có field `typeId` =
    đúng `Id` đã ghi lại ở trên (ví dụ `3`) — không phải rỗng/`0` cố định. Kiểm tra trực tiếp DB (bảng
    `eutr_references`): bản ghi mới tạo cho document này có `RefType` = đúng giá trị `typeId` đó. Quay
    lại danh sách EUTR documents chính, xác nhận document vừa tạo hiển thị đúng nhãn **"PO"** ở cột
    Type (JOIN `RefType`↔`eutr_reference_types.Id`, Update 14) — không hiển thị trống hay sai nhãn.
17a. **Không hồi quy Type khác "PO" (Update 18)**: Lặp lại nhanh với Type = "Vendor" (hoặc "Invoice")
    → xác nhận request Upload vẫn gọi `POST /api/sharepoint/eutr-upload-multi-by-type` với `typeId`
    như Update 15/16 (không đổi), không liên quan tới thay đổi ở kịch bản 17.

## Tiêu chí đạt

- Tất cả 17 kịch bản trên (cùng các kịch bản phụ 9a-9s, 10a, 11a-11b, 15a-15e, 16a-16b, 17a, 1a,
  5a-5c, 6a) hoạt động đúng.
- **(Update 18)** Khi Type = "PO" trong popup Add, request Upload gửi kèm `typeId` = `Id` thật của
  Type "PO" đang chọn ở dropdown (không phải giá trị rỗng/cố định); mỗi `eutr_references` ghi cho
  document tạo qua luồng này có `RefType` khớp đúng `typeId` đó — xem SC-044. Trang Add cũ độc lập
  (`EutrDocumentsAdd.jsx`) và luồng Upload của Type khác "PO" không đổi hành vi.
- **(Update 17)** Ô Value trong popup Add trở về trống ngay sau khi thêm 1 chip (mọi đường: gợi ý/gõ
  tay/dán) — xem SC-043. Type = "PO" trong popup Add KHÔNG hiển thị/yêu cầu combobox Step — xem
  FR-072/FR-074/SC-043; Upload gọi lại đúng endpoint gốc `eutr-upload-multi` (Update 6/7), file không
  khớp `Prefix` trong `eutr_master_documents` bị loại kèm cảnh báo, không tạo document — xem
  FR-073/SC-043; mỗi document Type="PO" tạo qua popup Add có `StepId` đúng theo Prefix khớp tên file
  (không phải Step chọn thủ công) — xem FR-075/SC-040. Type khác "PO" không đổi hành vi so với Update
  15/16.
- **(Update 15/16)** Nút Add mở popup "Add EUTR documents", KHÔNG điều hướng trang — xem SC-036.
  Nút Upload chỉ khả dụng khi đủ Type+Step+≥1 chip (Type khác "PO"; xem ngoại lệ Update 17 ở trên) —
  xem SC-037. Mọi chip được thêm (qua gợi ý, gõ tay, hoặc dán) khớp đúng dữ liệu tham chiếu khi Type
  có nguồn gợi ý — xem SC-038; Type="PO"/"Vendor" không bao giờ có quá 1 chip — xem SC-039. Mỗi lượt
  Upload lưu đúng thư mục SharePoint theo Type và tạo đúng N `eutr_references` cho mỗi document (N=số
  chip cho Type khác "PO"; N=số `StepId` khớp Prefix cho Type="PO", xem Update 17) — xem SC-040; Step
  name/Type trên danh sách chính hiển thị đúng ngay cả cho Type mới (ngoài PO/Upload manual) — xem
  SC-041. Popup luôn tự đóng ngay sau khi Upload hoàn tất — xem SC-042. Trang `/eutr/documents/add` cũ
  và luồng Edit (Update 12/13) không đổi hành vi.
- **(Update 14)** Cột Type trên danh sách EUTR documents hiển thị đúng `typeName` trả về từ
  `POST /api/eutr-documents/get-all` (JOIN `eutr_reference_types`), không còn tra
  `TAKE_FROM_OPTIONS` ở client cho cột này — xem SC-035. Sau khi seed đúng `Id=0`/`Id=1`, mọi
  document hiện có tiếp tục hiển thị đúng nhãn Type như trước Update 14 (không bị "mất nhãn"). Trang
  Add — dropdown Type (FR-016) không đổi.
- **(Update 11)** Khu Upload File ở Screen2 luôn khả dụng (không cần chọn gì trước), upload đúng
  vào thư mục cố định `UploadManual`, không validate prefix — xem SC-025. Danh sách "chưa gán" chỉ
  hiển thị document không có `eutr_references` — xem SC-026. Save trong popup Assign condition bị
  chặn khi thiếu Step HOẶC thiếu Conditions type/value (Update 13 correction) — xem SC-027, tạo
  đúng số bản ghi `eutr_references`/`eutr_reference_details` khi hợp lệ — xem SC-028/SC-029/SC-034
  (không cho phép 2 dòng cùng Conditions type).
- **(Update 12)** Edit rẽ nhánh đúng theo Type của document (PO/Upload manual/trống) — xem SC-030;
  sửa Step cho Type="PO" thay thế đúng toàn bộ tập Step cũ bằng Step mới — xem SC-031; popup Assign
  condition ở chế độ sửa nạp đúng dữ liệu hiện có — xem SC-032; Save chế độ sửa tuân thủ cùng quy
  tắc bắt buộc như chế độ tạo mới, không làm mất dữ liệu cũ khi bị chặn — xem SC-033.
- **(Update 9)** Sau khi xóa 1 hoặc nhiều document (đơn hoặc bulk), không còn dòng `eutr_references`
  nào có `DocumentId` trỏ tới document đã xóa — xem SC-021. Nếu bước dọn `eutr_references` thất bại,
  document đó không bị xóa; lỗi ở 1 document không chặn việc xóa các document khác trong cùng lượt
  xóa nhiều — xem SC-022.
- Không có lỗi console; gọi đúng các endpoint trong
  [contracts/eutr-documents-api.md](./contracts/eutr-documents-api.md).
- Add luôn là trang riêng (`/eutr/documents/add`); Edit luôn là popup — không lẫn lộn hai luồng.
- Cột Conditions luôn trống, không gây lỗi hiển thị hay lỗi console (không đổi bởi Update 8).
- **(Update 8)** Cột Step name/Type (danh sách) và File name/Step name (List PO) hiển thị đúng dữ
  liệu thật khi có bản ghi `eutr_references` liên kết, và hiển thị trống (không lỗi) khi không có —
  xem SC-019/SC-020.
- **(Update 10)** Icon View trên danh sách chính và trên mỗi dòng của List PO mở đúng popup xem
  trước file thật khi document có `FileId` (gọi `GET /eutr-documents/get-file-by-idref`); hiển thị
  vô hiệu hóa kèm tooltip "No file to view" khi không có `FileId` — không còn là placeholder
  silent no-op như trước Update 10 — xem SC-006/SC-023. Icon Delete trên mỗi dòng của List PO xóa
  đúng và chỉ đúng document đó (kèm `eutr_references` liên quan) mà KHÔNG xóa file thật trên
  SharePoint — xem SC-024.
- Trường Type + layout List PO (Screen1)/Upload manual (Screen2) trên trang Add hiển thị đúng theo
  `docs/design/eutr/eutr_documents_overview.md`. **Kể từ Update 11**, Screen2 KHÔNG còn dùng dữ
  liệu mẫu tĩnh/no-op — khu Upload File, bảng danh sách "chưa gán", checkbox, và Assign condition
  đều là hành vi thật (xem kịch bản 10-11b); Save trên form chính vẫn hoạt động độc lập như cũ (chỉ
  File name, Valid from, Valid to).
- Cột **PO name** trong List PO (Screen1) tải đúng dữ liệu thật từ `POST /api/dynamics/reference`
  (`refType = 15`); trạng thái trống/lỗi của bảng này hiển thị đúng khi API trả về rỗng/thất bại
  (Update 4).
- **(Update 6)** Nút Upload ở Screen1 chỉ khả dụng khi đã chọn 1 PO; upload file hợp lệ tạo đúng
  document trong `eutr_documents` (File name, Valid from = hôm nay, Valid to = `9999-12-31`, FileId
  từ SharePoint); file sai định dạng/quá 10MB bị loại kèm lỗi rõ ràng mà không chặn các file hợp lệ
  khác; lỗi một phần batch không làm mất các file đã upload/lưu thành công; List PO's File name vẫn
  hiển thị trống sau upload (không lưu liên kết PO trong DB, theo clarify Update 6).
- `refType = 16` trả về đúng dữ liệu khi gọi trực tiếp nhưng không có UI nào trong feature này gọi
  tới (Update 4).
- Ô tìm kiếm PO gọi lại API (`refType = 15` kèm từ khóa) thay vì chỉ lọc dữ liệu đã tải; xóa từ
  khóa khôi phục danh sách mặc định; từ khóa không khớp hiển thị "No data" (Update 5).
- Toàn bộ văn bản hiển thị (label cột, nút Add/Edit/Delete/View/Save/Back/Cancel, breadcrumb,
  thông báo lỗi/thành công, trạng thái rỗng "No data", hộp thoại xác nhận xóa) đều bằng **tiếng
  Anh** (FR-015).
- **(Update 7)** Khu Upload hiển thị đúng theo mẫu `upload.png` (tiêu đề, khung kéo-thả, icon, hàng
  chip) với nội dung định dạng/kích thước **thật** (không theo số liệu trong ảnh mẫu); hỗ trợ cả
  kéo-thả thật lẫn click. File không khớp prefix nào trong `eutr_master_documents` bị chặn upload
  kèm cảnh báo rõ ràng. File khớp nhiều `StepId` tạo đúng nhiều dòng `eutr_references` (cùng
  `DocumentId`, khác `StepId`). Không có document "mồ côi" nào (document tồn tại mà không có
  `eutr_references` tương ứng) xuất hiện trong danh sách EUTR documents sau bất kỳ lượt upload nào.
