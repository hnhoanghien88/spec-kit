# Feature Specification: EUTR Documents Management

**Feature Branch**: `004-eutr-documents`

**Created**: 2026-07-07

**Status**: Draft

**Input**: User description: "chức năng mới eutr-documents tổng quan theo Eutr\docs\design\eutr\eutr_documents_overview.md"

## Clarifications

### Session 2026-07-07

- Q: Cột `Name` trong bảng `eutr_documents` hiện là BIGINT nhưng grid cần hiển thị "File name" dạng
  văn bản. Xử lý thế nào? → A: Migrate cột `Name` sang VARCHAR(255) để lưu tên file hiển thị dạng
  văn bản (giống `eutr_steps.Name`).
- Q: Trang Upload nên chấp nhận định dạng và kích thước file nào? → A: Giới hạn cụ thể — PDF,
  DOC/DOCX, XLS/XLSX, JPG/PNG, tối đa 10MB mỗi file.
- Q: File name có cần là duy nhất giữa các document không? → A: Không ràng buộc duy nhất — cho
  phép nhiều document trùng File name.

### Session 2026-07-07 (Update)

- Change: Chức năng Add hiện tại KHÔNG có bước chọn/upload file — màn hình Add chỉ thu thập
  thông tin (File name nhập tay dạng văn bản, Valid from, Valid to). Việc chọn/tải file thật lên
  hệ thống chưa được triển khai và sẽ bổ sung ở một tính năng sau; theo đó, ràng buộc định dạng/
  kích thước file (PDF, DOC/DOCX, XLS/XLSX, JPG/PNG, tối đa 10MB) đã thống nhất ở phiên clarify
  trước bị **hoãn lại (deferred)** cho tới khi chức năng upload file thật được xây dựng.
- Change: Nút **View** trên cột Action hiện tại CHỈ là một icon hiển thị trên grid, CHƯA được gắn
  hành vi xử lý nào (không mở trang, không mở popup, không tải file). Đây là placeholder cho một
  tính năng sẽ hoàn thiện sau.

### Session 2026-07-07 (Update 2)

- Q: Vì trang Add không còn upload file thật, nút trên toolbar nên giữ tên "Upload" hay đổi tên
  khác? → A: Đổi tên nút thành **"Add"** để khớp đúng hành vi hiện tại (chỉ nhập thông tin, không
  có upload file thật).
- Q: Icon View (placeholder, chưa xử lý) nên hiển thị ở trạng thái nào? → A: Hiển thị bình thường,
  giống hệt Edit/Delete (KHÔNG làm mờ/disable); khi nhấn vào không có phản hồi nào (silent no-op).
- Q: Trang Add hiện chưa có cách rời trang mà không lưu. Có cần nút Back/Cancel không? → A: Có —
  thêm nút **Back** trên trang Add để quay lại danh sách mà không lưu, theo cùng mẫu đã dùng ở
  EUTR Templates.

### Session 2026-07-07 (Update 3) — Chỉnh giao diện trang Add theo thiết kế tổng quan

- Change: Trang Add được bổ sung giao diện theo `docs/design/eutr/eutr_documents_overview.md` ở
  **phạm vi chỉ giao diện** — chưa xây dựng chức năng thật (không có API/dữ liệu PO thật, không có
  upload file thật). Các trường và hành vi hiện có (File name, Valid from, Valid to, Save, Back)
  KHÔNG bị thay đổi và tiếp tục hoạt động như trước.
- Q: Thiết kế mới không hiển thị File name/Valid from/Valid to — nên giữ hay bỏ các trường này? →
  A: **Giữ song song** — các trường và nút Save/Back hiện có được giữ nguyên và tiếp tục lưu dữ
  liệu thật; phần giao diện mới theo thiết kế (Type, List PO, khu upload Manual) chỉ là phần bổ
  sung mang tính hiển thị, hiện MỚI không thực hiện chức năng nào.
- Q: Khu vực "List PO" (Screen1) hiển thị dữ liệu gì khi hệ thống chưa có nguồn dữ liệu PO thật? →
  A: Hiển thị **dữ liệu mẫu tĩnh (demo, hard-coded)** giống thiết kế (PO1-PO8, File PO1-1..PO1-8)
  chỉ để minh họa giao diện, không kết nối tới bất kỳ API/nguồn dữ liệu thật nào.
- Q: Các tương tác mới (kéo-thả file, nút Assign condition, icon View/Delete trong bảng demo,
  checkbox chọn dòng) nên xử lý thế nào? → A: **Silent no-op** — hiển thị bình thường nhưng không
  thực hiện hành động thật nào (không tải file, không gọi API, không điều hướng), theo cùng mẫu đã
  áp dụng cho icon View ở User Story 5.

### Session 2026-07-08 (Update 4) — Đăng ký 2 entity D365 vào API reference dùng chung

- Change: Backend MUST tích hợp 2 entity D365 mới (`RSVNEutrPurchOrders`, `RSVNEutrSalesOrderPurchases`)
  thông qua endpoint **dùng chung** đã có sẵn `POST /api/dynamics/reference` (action `ReferenceData`
  trong `DynController`), bằng cách đăng ký thêm 2 `refType` mới trong bảng ánh xạ (`EntityMappings`)
  của `ComplDynamicsService` — theo đúng cách các entity D365 khác đã được đăng ký (ví dụ VendorsV3 =
  refType 14, RSVNCustTableEntities = refType 2). KHÔNG tạo endpoint GET/POST riêng mới cho 2 entity
  này.
- Q: `refType` nào dùng cho từng entity? → A: `RSVNEutrPurchOrders` = **refType 15**;
  `RSVNEutrSalesOrderPurchases` = **refType 16**.
- Q: Bảng **List PO** (Screen1, khi Type = "PO") hiện đang hiển thị dữ liệu mẫu tĩnh (PO1-PO8) — có
  nối vào API thật không? → A: **Có, một phần** — cột **PO name** trong bảng List PO MUST lấy dữ
  liệu thật bằng cách gọi `POST /api/dynamics/reference` với `refType = 15` (`RSVNEutrPurchOrders`),
  thay cho dữ liệu mẫu tĩnh trước đây. Cột **File name** và các thao tác View/Delete trên mỗi dòng
  List PO vẫn giữ nguyên hành vi cũ (không có nguồn dữ liệu file thật, hiển thị trống, thao tác vẫn
  là silent no-op — theo cùng phạm vi "chưa có chức năng upload file thật" đã thống nhất ở Update 1).
  *(Superseded by Update 8: sau khi có dữ liệu upload thật (Update 6/7), cột File name — và thêm cột
  Step name mới — được nạp dữ liệu thật từ `eutr_references`, xem FR-037/FR-038; các thao tác View/
  Delete trên List PO vẫn giữ nguyên silent no-op, không đổi. Superseded further by Update 10: các
  thao tác View/Delete cấp-dòng này không còn là silent no-op — được thay bằng icon View/Delete
  theo từng file riêng lẻ, xem FR-043/FR-044.)*
- Q: `refType = 16` (`RSVNEutrSalesOrderPurchases`) dùng để làm gì trong feature này? → A: **Chỉ
  đăng ký ở backend, chưa dùng ở giao diện nào trong phạm vi feature này** — refType này dành cho
  một màn hình sẽ được phát triển ở một tính năng sau; feature `004-eutr-documents` chỉ yêu cầu
  refType tồn tại và trả về đúng dữ liệu khi gọi qua endpoint reference dùng chung, không có UI nào
  gọi tới nó.

### Session 2026-07-08 (Update 5) — Ô tìm kiếm PO lọc dữ liệu qua API thay vì lọc cục bộ

- Change: Trên trang Add, khi Type = "PO" (Screen1), bảng **List PO** có một ô tìm kiếm phía trên
  danh sách PO (bổ sung khi triển khai Update 4). Ô tìm kiếm này hiện đang lọc trên dữ liệu **đã
  tải sẵn ở client** (chỉ trang dữ liệu đầu tiên) — MUST đổi sang lọc bằng cách **gọi lại API
  reference** (`refType = 15`) với từ khóa người dùng nhập, để kết quả tìm kiếm bao phủ toàn bộ
  danh sách PO thật trên D365 (không chỉ giới hạn trong số PO đã tải về trước đó).
- Q: Khi người dùng xóa hết từ khóa tìm kiếm thì danh sách PO hiển thị gì? → A: Tải lại danh sách
  PO mặc định (không lọc) — giống trạng thái ban đầu khi mở Type = "PO".
- Q: Khi từ khóa tìm kiếm không khớp PO nào từ API, danh sách hiển thị gì? → A: Hiển thị trạng thái
  trống ("No data"), giống hành vi trống đã có ở Update 4 (không phải lỗi).
- Q: Ô tìm kiếm trước đây hỗ trợ nhập nhiều từ khóa cách nhau bằng dấu phẩy (lọc cục bộ) — có giữ
  lại khi chuyển sang gọi API không? → A: **Không giữ** — đơn giản hóa thành tìm kiếm một cụm từ tự
  do duy nhất mỗi lần (khớp theo kiểu "chứa" trên tên/mã PO ở phía server), theo đúng cách tìm kiếm
  chung đã dùng ở các ô tham chiếu khác trong hệ thống (vd. `ReferenceObjectAutocomplete.jsx`).

### Session 2026-07-08 (Update 6) — Khu vực "Drag and drop files to upload" ở Screen1 (Type = PO)
trở thành upload nhiều file thật lên SharePoint

- Change: Khu vực **"Drag and drop files to upload"** ở Screen1 (Type = "PO", xem FR-017) KHÔNG
  còn là kéo-thả silent no-op — được thay bằng một nút **Upload**. Người dùng chọn (click) đúng một
  dòng PO trong bảng List PO để kích hoạt nút Upload, nhấn Upload để mở hộp thoại chọn file của hệ
  điều hành (cho phép chọn **nhiều file cùng lúc**), hệ thống upload các file đó lên SharePoint, rồi
  với mỗi file upload thành công, tạo một bản ghi mới trong bảng `eutr_documents` với File name =
  tên file gốc, Valid from = ngày hiện tại, Valid to = ngày tối đa (sentinel "không giới hạn"),
  FileId = id trả về từ SharePoint. Khu vực "Drag and drop files to upload" ở **Screen2** (Type =
  "Upload manual") **KHÔNG thay đổi** — vẫn là silent no-op theo đúng phạm vi đã thống nhất ở
  Update 3.
- Change: Backend MUST bổ sung endpoint mới **`POST /api/sharepoint/eutr-upload-multi`** trong
  cùng `SharePointController` hiện có (tham khảo mẫu `POST /api/sharepoint/upload-multi`), dùng
  `_configuration["SharePointEutrPath"]` làm thư mục gốc SharePoint (KHÔNG dùng
  `SharePointCompPath`), và gọi một service **MỚI** `_eutrUploadService.UploadMultipleToSharePointAndSaveDataAsync`
  — KHÔNG dùng lại `_complUploadService` hiện có. Endpoint nhận thêm thông tin PO (mã PO đã chọn ở
  List PO) để xác định thư mục đích trên SharePoint.
- Q: PO được chọn ở List PO dùng để làm gì trong lượt upload — chỉ để xác định thư mục SharePoint,
  hay còn cần lưu liên kết PO vào bảng `eutr_documents`? → A: **Chỉ dùng để xác định thư mục
  SharePoint** — với PO đã chọn, hệ thống tìm thư mục con đã tồn tại ứng với PO đó dưới
  `SharePointEutrPath` (nếu có, upload tiếp vào thư mục cũ) hoặc tạo mới thư mục đó nếu chưa tồn
  tại, rồi upload file vào thư mục này. Bảng `eutr_documents` **KHÔNG có thêm cột** lưu liên kết PO
  ở phạm vi feature này — cột **File name** trong bảng List PO tiếp tục hiển thị trống, KHÔNG đổi so
  với hành vi đã có ở Update 4/5. *(Superseded by Update 8: liên kết PO vẫn không lưu trực tiếp trên
  `eutr_documents`, nhưng cột File name trong List PO giờ được nạp gián tiếp qua `eutr_references`
  — xem FR-037/FR-038.)*
- Q: Ràng buộc định dạng/kích thước file (PDF, DOC/DOCX, XLS/XLSX, JPG/PNG, tối đa 10MB/file) đã
  thống nhất ở phiên clarify đầu tiên nhưng bị hoãn lại ở Update 1 (vì chưa có upload file thật) —
  có áp dụng lại cho nút Upload mới này không? → A: **Áp dụng lại** — nút Upload chỉ chấp nhận PDF,
  DOC/DOCX, XLS/XLSX, JPG/PNG, tối đa 10MB mỗi file; file không hợp lệ (sai định dạng hoặc vượt kích
  thước) bị loại khỏi lượt upload kèm thông báo lỗi rõ ràng, không chặn các file hợp lệ khác trong
  cùng lượt chọn.

### Session 2026-07-08 (Update 7) — Thiết kế lại khu vực Upload theo hình + validate prefix file
theo `eutr_master_documents` + ghi liên kết vào `eutr_references`

- Change: Khu vực nút **Upload** ở Screen1 (Type = PO) được **thiết kế lại giao diện** theo mẫu
  hình đính kèm (`upload.png`): tiêu đề **"Upload File"**, một khung viền nét đứt lớn chứa icon đám
  mây (cloud-upload), dòng chữ chính **"Drop file here or click to browse"**, một dòng phụ liệt kê
  định dạng/kích thước chấp nhận, và một hàng "chip" nhỏ bên dưới khung liệt kê lại các định dạng và
  giới hạn kích thước (ví dụ "✓ PDF", "✓ DOCX", "✓ Max ..."). Khung này giờ hỗ trợ **cả kéo-thả file
  thật lẫn click để mở hộp thoại chọn file** (trước đây ở Update 6 chỉ có nút bấm, không có kéo-thả
  thật) — kéo-thả một file vào khung kích hoạt đúng luồng validate + upload như khi click chọn file.
- Q: Dòng chữ trong hình mẫu ghi "PDF, DOCX, XLSX — max 50 MB per file", khác với ràng buộc đã chốt
  ở Update 6 (PDF, DOC/DOCX, XLS/XLSX, JPG/PNG, tối đa 10MB/file). Áp dụng đúng theo hình (đổi ràng
  buộc) hay giữ nguyên ràng buộc cũ, chỉ lấy hình làm tham khảo layout? → A: **Giữ nguyên ràng buộc
  đã chốt ở Update 6** — vẫn chỉ chấp nhận PDF, DOC/DOCX, XLS/XLSX, JPG/PNG, tối đa 10MB/file (xem
  FR-026). Hình `upload.png` chỉ dùng để tham khảo **bố cục và phong cách hiển thị** (tiêu đề, khung
  kéo-thả, icon, hàng chip) — dòng chữ phụ và các chip MUST hiển thị đúng danh sách định dạng/giới
  hạn kích thước **thật** đang áp dụng (PDF, DOC/DOCX, XLS/XLSX, JPG/PNG, 10MB), không sao chép
  nguyên văn số liệu trong hình mẫu.
- Change: Bổ sung **validate tên file theo prefix** trước khi cho phép upload thật lên SharePoint:
  tên file phải bắt đầu bằng (case-insensitive) một giá trị `Prefix` đang tồn tại trong bảng
  `eutr_master_documents` (dữ liệu quản lý bởi feature `002-eutr-masters`). File không khớp bất kỳ
  Prefix nào bị loại khỏi lượt upload kèm cảnh báo rõ ràng, theo đúng mẫu xử lý per-file đã có ở
  Update 6 (FR-026/FR-030) — không chặn các file hợp lệ khác trong cùng lượt.
- Q: Cột `Prefix` trong `eutr_master_documents` chỉ duy nhất theo cặp (StepId, Prefix) — không duy
  nhất toàn cục, nên cùng một chuỗi Prefix (hoặc nhiều Prefix đều là tiền tố hợp lệ của cùng một tên
  file) có thể khớp nhiều bản ghi thuộc nhiều StepId khác nhau. Khi đó hệ thống xác định StepId nào
  để ghi liên kết? → A (sửa lại): **Ghi nhiều bản ghi `eutr_references`** — một bản ghi cho **mỗi**
  `StepId` khớp Prefix với tên file (khớp kiểu "tên file bắt đầu bằng Prefix", không phân biệt hoa/
  thường), tất cả các bản ghi này cùng dùng chung một `DocumentId` (của document vừa tạo cho file
  đó) nhưng khác `StepId`. Hệ thống KHÔNG chặn upload trong trường hợp này (khác với trường hợp
  không khớp Prefix nào, vốn bị chặn) và KHÔNG chỉ chọn một bản ghi duy nhất (khác quyết định ban
  đầu — xem Update 7 correction 2).
- Change: Với mỗi file upload thành công (đã qua validate định dạng/kích thước ở FR-026 VÀ validate
  prefix ở trên), ngoài việc tạo document mới trong `eutr_documents` (như Update 6), hệ thống MUST
  ghi thêm **một bản ghi mới vào bảng `eutr_references`** để liên kết document đó với Purchase Step
  tương ứng: `DocumentId` = `Id` của document `eutr_documents` vừa tạo; **`StepId`** (cột **mới**,
  cần bổ sung vào bảng `eutr_references`) = `StepId` của bản ghi `eutr_master_documents` đã khớp
  Prefix (xem quy tắc chọn ở trên) — **KHÔNG ghi vào cột `RefId` hiện có** (cột này giữ nguyên mục
  đích thiết kế cũ, trỏ tới `eutr_template_details`, không liên quan tới luồng này); `RefType` =
  giá trị "PO" trong hằng số `TAKE_FROM_OPTIONS` (= `0`); `RefValue` = mã PO đang được chọn ở List
  PO (cùng giá trị dùng để xác định thư mục SharePoint, xem Update 6 FR-027/FR-028). Việc ghi
  `eutr_references` này là bước **bổ sung**, không thay thế bước tạo `eutr_documents` — nếu bước tạo
  `eutr_documents` thành công nhưng ghi `eutr_references` thất bại, coi như file đó upload thất bại
  theo đúng ngữ nghĩa per-file đã có (không rollback các file khác đã thành công trọn vẹn cả hai
  bước).

### Session 2026-07-09 (Update 8) — Nạp dữ liệu thật cho Step name/Type ở danh sách và File name/
Step name ở List PO (Screen1)

- Change: Cột **Step name** và **Type** trong danh sách EUTR documents (User Story 1) KHÔNG còn
  luôn hiển thị trống. Với mỗi document, hệ thống tra cứu các bản ghi `eutr_references` có
  `DocumentId` = `Id` của document đó: **Step name** = tên Step (JOIN `StepId` với
  `eutr_steps.Name`) của mọi `StepId` phân biệt tìm được; nếu có nhiều bản ghi `eutr_references`
  (nhiều `StepId` khác nhau) cho cùng một document, cột Step name hiển thị **nhiều** Step name
  tương ứng. **Type** = nhãn (`label`) của hằng số `TAKE_FROM_OPTIONS` ứng với `RefType` của các bản
  ghi đó (`0` = "PO", `1` = "Upload manual"). Document không có bản ghi `eutr_references` nào tương
  ứng (ví dụ document tạo qua form Save nhập tay, không qua khu vực Upload) tiếp tục hiển thị Step
  name và Type ở trạng thái trống — không đổi so với trước Update 8. Cột **Conditions** KHÔNG thuộc
  phạm vi thay đổi này — tiếp tục hiển thị trống trên mọi dòng (không có nguồn dữ liệu nào được yêu
  cầu bổ sung cho cột này).
- Change: Trên trang Add (Screen1, Type = "PO"), cột **File name** và **Step name** trong bảng
  **List PO** KHÔNG còn luôn hiển thị trống. Với mỗi dòng PO, hệ thống tra cứu các bản ghi
  `eutr_references` có `RefType = 0` ("PO") và `RefValue` = mã PO của dòng đó: **File name** =
  `Name` của (các) document `eutr_documents` có `Id` trùng `DocumentId` của các bản ghi khớp (JOIN
  theo `DocumentId`); **Step name** = tên Step (JOIN `StepId` với `eutr_steps.Name`) của các bản ghi
  khớp đó, lấy theo đúng cách đã mô tả ở thay đổi trên. Một PO có thể có nhiều document/Step liên
  kết (mỗi lượt upload file thành công qua khu vực Upload tạo thêm một bộ liên kết mới, xem Update
  6/7) — khi đó cột File name và Step name hiển thị **đầy đủ nhiều giá trị** tương ứng. Dòng PO chưa
  từng có file nào được upload (chưa có bản ghi `eutr_references` khớp `RefType=0`/`RefValue`) tiếp
  tục hiển thị File name và Step name ở trạng thái trống — không đổi so với trước Update 8.
- Q: Khi một dòng (document ở danh sách, hoặc PO ở List PO) có nhiều Step name/File name, hiển thị
  toàn bộ hay giới hạn số lượng? → A: Áp dụng đúng mẫu hiển thị nhiều giá trị đã có sẵn trong hệ
  thống (cột "Country Codes" ở màn Country Groups — `useCountryGroupColumns.jsx`): hiển thị một số
  giá trị đầu dưới dạng chip, phần còn lại gộp vào một chip "+N more" kèm tooltip liệt kê đầy đủ khi
  hover — không cắt bớt dữ liệu, chỉ giới hạn cách trình bày trực quan.
- Q: Việc bổ sung tra cứu này có cần thêm cột/bảng dữ liệu mới, hay migration DB nào không? → A:
  Không — toàn bộ dữ liệu cần (`DocumentId`, `StepId`, `RefType`, `RefValue` trên `eutr_references`,
  `Name` trên `eutr_steps`/`eutr_documents`) đã có sẵn từ Update 7; Update 8 chỉ bổ sung logic đọc
  (JOIN/tra cứu), không cần migration DB mới.
- Q: Nếu (trường hợp ngoại lệ) một document có nhiều bản ghi `eutr_references` với `RefType` khác
  nhau, cột Type hiển thị gì? → A: Không xảy ra trong luồng nghiệp vụ hiện tại của hệ thống — mọi
  bản ghi `eutr_references` của cùng một `DocumentId` luôn được ghi trong cùng một lượt với cùng
  `RefType` (theo FR-033/Update 7). Nếu dữ liệu ngoại lệ này tồn tại, hệ thống hiển thị nhãn của
  `RefType` của bản ghi `eutr_references` đầu tiên tìm được cho document đó, không coi là lỗi.

### Session 2026-07-09 (Update 9) — Xóa document (Delete) MUST xóa kèm mọi bản ghi `eutr_references` liên quan

- Change: Chức năng **Delete** (User Story 4, đơn hoặc nhiều document) hiện tại chỉ xóa bản ghi
  trong `eutr_documents`, để lại các bản ghi `eutr_references` mồ côi (orphan) trỏ tới
  `DocumentId` đã bị xóa (các bản ghi này được ghi bởi luồng Upload ở Screen1, xem Update 7/FR-033).
  Backend MUST bổ sung bước xóa toàn bộ bản ghi `eutr_references` có `DocumentId` = `Id` của mỗi
  document bị xóa, thực hiện **cùng lúc** với việc xóa document đó (không chỉ xóa document rồi để
  lại references cũ). Áp dụng cho cả xóa một document (FR-011) và xóa nhiều document cùng lúc
  (FR-012) — với xóa nhiều, mỗi document trong lượt xóa đều được dọn `eutr_references` tương ứng
  theo đúng `DocumentId` của nó.
- Q: Nếu việc xóa `eutr_references` thất bại (lỗi DB) trong khi document vẫn có thể xóa được, hệ
  thống xử lý thế nào? → A: **Coi là một giao dịch (transaction) duy nhất theo từng document** —
  nếu xóa `eutr_references` của một document thất bại thì document đó **KHÔNG** bị xóa (rollback),
  hệ thống báo lỗi rõ ràng cho document đó; với xóa nhiều document, lỗi ở một document **KHÔNG**
  chặn việc xóa các document khác trong cùng lượt (theo đúng ngữ nghĩa per-item đã dùng ở nơi khác
  trong feature này, ví dụ FR-030 khi upload nhiều file).
- Q: Document không có bản ghi `eutr_references` nào (tạo qua form Save nhập tay, chưa từng qua
  Upload) khi bị xóa có cần xử lý gì khác không? → A: **Không** — bước xóa `eutr_references` theo
  `DocumentId` chạy bình thường và không xóa gì (0 bản ghi bị ảnh hưởng), document vẫn bị xóa như
  hành vi hiện tại; đây không phải lỗi.

### Session 2026-07-09 (Update 10) — Icon View mở xem file thật (tham khảo `ComplCompliancesController.GetFileByIds`/`compliance-detail`) + Delete từng file trong List PO

- Change: Icon **View** trên cột Action của danh sách EUTR documents (User Story 1, trước đây là
  placeholder silent no-op theo FR-013) MUST trở thành chức năng thật: nhấn vào mở một **popup xem
  trước file** (inline preview) cho document đó, theo đúng mẫu giao diện/luồng đã có ở
  `compliance-client/src/presentation/pages/compliance-detail` (`FilePreviewer.jsx` +
  `DialogFilePreviewer.jsx` — hiển thị PDF/DOCX/XLSX/ảnh trực tiếp trong popup kèm nút Download).
  Backend MUST bổ sung endpoint **`GET /api/eutr-documents/get-file-by-idref`** trong
  `EutrDocumentsController` hiện có, nhận `idRef` = `FileId` của document (query string), tham khảo
  đúng mẫu hàm `[HttpGet("get-file-by-idref")] GetFileByIds` trong
  `ComplCompliancesController.cs` — cùng gọi `_sharepointService.ReadFileWithMetaAsync(idRef)` và
  trả về nội dung file dạng base64 kèm content type, file name (`SharepointFileContent`) — KHÔNG tạo
  service đọc file mới.
- Change: Với document KHÔNG có file thật (`FileId = null`, tạo qua form Save nhập tay ở trang Add,
  chưa từng qua khu vực Upload), icon View trên danh sách chính MUST hiển thị ở trạng thái **vô hiệu
  hóa (disabled)** kèm tooltip **"No file to view"** — khác với hành vi active-nhưng-no-op trước đây
  (FR-013 cũ).
- Change: Trên trang Add (Screen1, Type = PO), mỗi **file riêng lẻ** hiển thị trong cột File name/
  Step name của bảng List PO (mỗi chip tương ứng một document/Step đã liên kết với PO đó, xem Update
  8/FR-037/FR-038) MUST có icon **View** và icon **Delete** riêng — KHÔNG dùng chung một icon View/
  Delete cho cả dòng PO, vì một dòng PO có thể liên kết nhiều file khác nhau. Icon View trên mỗi file
  mở đúng popup xem trước file đó (theo cùng cơ chế ở trên, dùng `FileId` của document ứng với file
  đó). Icon **Delete** trên mỗi file, sau khi xác nhận, MUST xóa bản ghi `eutr_documents` và toàn bộ
  bản ghi `eutr_references` liên quan tới document đó (cùng giao dịch, cùng ngữ nghĩa với
  FR-039/FR-040) — dùng lại nguyên vẹn API xóa document đơn đã có (`DELETE /api/eutr-documents/{id}`,
  FR-011), KHÔNG cần endpoint xóa mới. Việc xóa này KHÔNG xóa file thật trên SharePoint (file vẫn còn
  trên SharePoint, chỉ không còn bản ghi nào trong hệ thống trỏ tới nó). Sau khi xóa, file đó biến
  mất khỏi cả List PO (trang Add) và danh sách EUTR documents chính (User Story 1), vì cùng là một
  document.
- Change: Icon View/Delete cấp-dòng trước đây trên cột Action của bảng List PO (silent no-op, theo
  FR-017/FR-019 cũ) bị **thay thế hoàn toàn** bởi các icon View/Delete theo từng file ở trên — cột
  Action cấp-dòng của List PO không còn icon View/Delete riêng biệt nữa. Dòng PO chưa có file nào
  liên kết tiếp tục hiển thị File name/Step name trống và không có icon nào để xem/xóa (không có gì
  để thao tác).
- Q: Một dòng PO có thể liên kết nhiều file (nhiều chip) — chức năng View/Delete mới nên gắn ở đâu?
  → A: **Theo từng file** — mỗi chip (mỗi file/Step liên kết) có icon View và Delete riêng, thay cho
  một icon View/Delete chung áp dụng mơ hồ cho cả dòng có nhiều file.
- Q: Khi document không có `FileId` (tạo tay qua Save, không qua Upload), nhấn View trên danh sách
  chính xử lý thế nào? → A: **Vô hiệu hóa icon View** (mờ đi, không click được) kèm tooltip "No file
  to view" — không hiển thị thông báo lỗi khi nhấn vì nút đã bị disable.
- Q: Xóa một file ở khu vực này nên xóa gì? → A: **Chỉ xóa bản ghi trong `eutr_documents` và
  `eutr_references`** liên quan — KHÔNG gọi thêm API xóa file thật trên SharePoint (file vẫn còn tồn
  tại trên SharePoint, chỉ không còn được hệ thống tham chiếu tới nữa).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Xem danh sách EUTR documents (Priority: P1)

Người dùng vào mục **EUTR > EUTR documents** từ thanh điều hướng và thấy bảng liệt kê các
document EUTR đã được thêm vào hệ thống. Bảng hiển thị File name, Step name, Conditions, Type, Valid from, Valid
to, Created by, Created date và cột Action (Edit, Delete, View). Bảng `eutr_documents` chỉ lưu File
name (Name), Valid from, Valid to, Created by, Created date; cột **Conditions** vẫn chưa có nguồn
dữ liệu nên luôn hiển thị trống. **Kể từ Update 8**, cột **Step name** và **Type** KHÔNG còn luôn
trống — hệ thống tra cứu bảng `eutr_references` theo `DocumentId` của mỗi document (JOIN `StepId`
với `eutr_steps.Name` để lấy Step name; lấy nhãn `TAKE_FROM_OPTIONS` ứng với `RefType` để hiển thị
Type); document chưa có bản ghi `eutr_references` nào (chưa từng upload file) vẫn hiển thị hai cột
này ở trạng thái trống. Người dùng có thể chuyển trang khi danh sách dài. **Kể từ Update 10**, icon
**View** trên cột Action không còn là placeholder — nhấn vào mở popup xem trước file thật của
document đó (nếu document có `FileId`); document không có `FileId` (tạo tay qua Save, chưa qua
Upload) hiển thị icon View ở trạng thái vô hiệu hóa kèm tooltip "No file to view".

**Why this priority**: Đây là giá trị cốt lõi — xem danh sách document hiện có là thao tác đầu
tiên người dùng cần trước khi thêm mới, sửa, xóa hay xem chi tiết bất kỳ document nào.

**Independent Test**: Mở màn hình, xác nhận breadcrumb "EUTR > EUTR documents" và bảng hiển thị
đúng dữ liệu (File name, Valid from, Valid to, Created by, Created date) từ các document đã có,
cột Conditions hiển thị trống, cột Step name/Type hiển thị đúng dữ liệu tra cứu từ `eutr_references`
(hoặc trống nếu document chưa có liên kết nào), chuyển trang và thấy trang kế tiếp.

**Acceptance Scenarios**:

1. **Given** đang ở mục EUTR, **When** chọn "EUTR documents" ở thanh điều hướng, **Then** thấy
   breadcrumb "EUTR > EUTR documents" và bảng với các cột File name, Step name, Conditions, Type,
   Valid from, Valid to, Created by, Created date, Action.
2. **Given** một document đã tồn tại trong bảng `eutr_documents` và KHÔNG có bản ghi `eutr_references`
   nào liên kết, **When** bảng hiển thị dòng đó, **Then** cột File name, Valid from, Valid to,
   Created by, Created date hiển thị đúng dữ liệu đã lưu; cột Step name, Conditions, Type hiển thị
   trống.
2a. **Given** một document có đúng một bản ghi `eutr_references` liên kết (một `StepId`, một
   `RefType`), **When** bảng hiển thị dòng đó, **Then** cột Step name hiển thị đúng tên Step (JOIN
   `eutr_steps.Name` theo `StepId`) và cột Type hiển thị đúng nhãn `TAKE_FROM_OPTIONS` ứng với
   `RefType` của bản ghi đó ("PO" hoặc "Upload manual").
2b. **Given** một document có nhiều bản ghi `eutr_references` liên kết với nhiều `StepId` phân
   biệt (cùng `DocumentId`, cùng `RefType`), **When** bảng hiển thị dòng đó, **Then** cột Step name
   hiển thị đầy đủ tất cả Step name tương ứng (không chỉ một) và cột Type vẫn hiển thị đúng một nhãn
   duy nhất (vì mọi bản ghi cùng `RefType`).
3. **Given** danh sách vượt quá một trang, **When** chọn số trang khác, **Then** bảng hiển thị các
   bản ghi của trang đó.
4. **Given** danh sách document rỗng, **When** mở màn hình, **Then** bảng hiển thị trạng thái
   trống ("No data") thay vì lỗi.
5. **(Update 10) Given** một document có `FileId` (đã upload file thật qua Screen1, xem Update 6/7),
   **When** nhấn icon View trên dòng đó, **Then** hệ thống mở popup xem trước file (PDF/DOCX/XLSX/
   ảnh hiển thị trực tiếp trong popup, kèm nút Download), lấy dữ liệu qua
   `GET /api/eutr-documents/get-file-by-idref?idRef={FileId}`.
6. **(Update 10) Given** một document KHÔNG có `FileId` (tạo qua form Save nhập tay, chưa từng qua
   Upload), **When** bảng hiển thị dòng đó, **Then** icon View hiển thị ở trạng thái vô hiệu hóa kèm
   tooltip "No file to view" — không thể nhấn.
7. **(Update 10) Given** popup xem trước file đang mở, **When** gọi
   `get-file-by-idref` thất bại (lỗi mạng/máy chủ) hoặc file có định dạng không hỗ trợ xem trước,
   **Then** popup hiển thị thông báo lỗi/cảnh báo thân thiện thay vì treo giao diện, người dùng vẫn
   có thể đóng popup.

---

### User Story 2 - Thêm document mới (nhập thông tin, chưa upload file) (Priority: P1)

Người dùng nhấn nút **Add** trên thanh công cụ. Hệ thống chuyển sang một **trang mới** (không
phải popup) tại đường dẫn `eutr/documents/add`. Trên trang này, người dùng nhập File name (văn
bản), thiết lập Valid from và Valid to, rồi nhấn Save. Document mới xuất hiện trong danh sách với
người tạo và ngày tạo được ghi nhận tự động. **Ở phạm vi hiện tại, trang này KHÔNG có bước chọn/
upload file thật** — chức năng chọn và tải file thật lên hệ thống sẽ được bổ sung sau. Trang Add
cũng có nút **Back** để quay lại danh sách mà không lưu.

Ngoài các trường trên, trang Add còn hiển thị thêm phần giao diện theo thiết kế tổng quan
(`docs/design/eutr/eutr_documents_overview.md`), **ở phạm vi chỉ giao diện — chưa có chức năng
thật**: một trường **Type** dạng dropdown với 2 lựa chọn **"PO"** và **"Upload manual"** (tái sử
dụng hằng số `TAKE_FROM_OPTIONS` có sẵn trong codebase — xem Assumptions).

- Khi chọn Type = **"PO"**: hiển thị layout Screen1 — một bảng **List PO** (cột PO name, File
  name, Step name) cùng một khu vực upload. Kể từ Update 4,
  cột **PO name** MUST lấy dữ liệu thật bằng cách gọi API tham chiếu dùng chung
  `POST /api/dynamics/reference` với `refType = 15` (D365 entity `RSVNEutrPurchOrders`, xem
  FR-021), thay cho dữ liệu mẫu tĩnh trước đây. **Kể từ Update 8**, cột **File name** và **Step
  name** KHÔNG còn luôn hiển thị trống — với mỗi dòng PO, hệ thống tra cứu bảng `eutr_references`
  theo `RefType = 0` ("PO") và `RefValue` = mã PO của dòng đó, rồi hiển thị File name (JOIN
  `DocumentId` với `eutr_documents.Name`) và Step name (JOIN `StepId` với `eutr_steps.Name`) của
  các bản ghi khớp; một PO có thể liên kết nhiều document/Step (mỗi lượt upload thành công tạo
  thêm một bộ liên kết mới, xem Update 6/7) nên hai cột này có thể hiển thị nhiều giá trị. Dòng PO
  chưa từng có file nào được upload tiếp tục hiển thị hai cột này ở trạng thái trống. **Kể từ Update
  10**, cột Action cấp-dòng với icon View/Delete silent no-op (áp dụng từ Update 4 đến trước Update
  10) bị **thay thế hoàn toàn** — mỗi **file riêng lẻ** hiển thị trong cột File name (mỗi chip ứng
  với một document/Step liên kết, xem Update 8) MUST có icon **View** và icon **Delete** riêng: View
  mở popup xem trước file thật đó (cùng cơ chế ở User Story 1/FR-042, dùng `FileId` của document
  tương ứng); Delete (sau khi xác nhận) xóa document đó khỏi `eutr_documents` cùng toàn bộ bản ghi
  `eutr_references` liên quan (cùng giao dịch, cùng ngữ nghĩa với FR-039/FR-040), KHÔNG xóa file
  thật trên SharePoint — file đó biến mất khỏi cả List PO và danh sách EUTR documents chính (User
  Story 1). Dòng PO chưa có file nào liên kết tiếp tục không có icon View/Delete nào để thao tác.
  Phía trên danh sách PO có một **ô tìm kiếm PO** — kể từ Update 5, ô này MUST lọc bằng cách gọi lại API
  tham chiếu (`refType = 15`)
  với từ khóa người dùng nhập (khớp theo tên/mã PO), thay vì chỉ lọc trên dữ liệu đã tải sẵn ở
  client (xem FR-023). Kể từ Update 6, khu vực upload KHÔNG còn là "Drag and drop files to upload"
  silent no-op — thay bằng một khu vực **Upload File** thật: người dùng chọn (click) đúng một dòng
  PO trong List PO để kích hoạt khu vực Upload (vô hiệu hóa khi chưa chọn PO nào). Kể từ Update 7,
  khu vực này được thiết kế lại theo mẫu hình `upload.png` — tiêu đề "Upload File", khung viền nét
  đứt lớn chứa icon đám mây và dòng chữ "Drop file here or click to browse", một dòng phụ và hàng
  chip nhỏ liệt kê định dạng/kích thước chấp nhận **thật** (PDF, DOC/DOCX, XLS/XLSX, JPG/PNG, tối đa
  10MB/file — ràng buộc không đổi so với Update 6, xem FR-026); khung này chấp nhận **cả kéo-thả
  file thật lẫn click để mở hộp thoại chọn nhiều file**. Với mỗi file được chọn/thả vào: hệ thống
  validate định dạng/kích thước (FR-026), sau đó (Update 7) validate tên file phải bắt đầu bằng một
  `Prefix` đang tồn tại trong bảng `eutr_master_documents` (feature `002-eutr-masters`) — file không
  khớp Prefix nào bị loại kèm cảnh báo, không được upload (FR-031/FR-032). File hợp lệ (qua cả hai
  bước validate) được upload lên SharePoint vào thư mục ứng với PO đã chọn (tìm thư mục cũ hoặc tạo
  mới dưới `SharePointEutrPath`), tạo một document mới trong `eutr_documents` (File name = tên file,
  Valid from = ngày hiện tại, Valid to = ngày tối đa, FileId = id từ SharePoint), và (Update 7) ghi
  thêm một bản ghi vào `eutr_references` cho **mỗi** Step ứng với Prefix đã khớp (một file thường
  khớp 1 Step, nhưng có thể khớp nhiều Step nếu Prefix trùng giữa nhiều Step — khi đó ghi nhiều bản
  ghi, cùng `DocumentId`, khác `StepId`) và với PO đang chọn — xem FR-024 đến FR-033.
- Khi chọn Type = **"Upload manual"**: hiển thị layout Screen2 — một khu vực **"Drag and drop files to
  upload"** ở trên cùng, nút **"Assign condition"**, và bên dưới là bảng danh sách file (checkbox
  chọn dòng, File name, Action: View/Delete) hiển thị **dữ liệu mẫu tĩnh (demo)** giống thiết kế
  (File 1..File 8).
- Mọi tương tác trong các khu vực mới này — **NGOẠI TRỪ nút Upload thật ở Screen1 (Type = PO, xem
  Update 6) và icon View/Delete theo từng file trong cột File name của List PO (Update 10, xem
  trên)** — (kéo-thả file ở Screen2, nhấn Assign condition, nhấn View/Delete/checkbox trong bảng
  demo) **KHÔNG thực hiện hành động thật nào** (không tải file, không gọi API, không điều hướng) —
  silent no-op, cùng mẫu với icon View ở User Story 5 (trước Update 10).
- Trường Type và khu vực List PO (cột PO name/File name, ô tìm kiếm PO) và Manual upload **KHÔNG
  được lưu vào bảng `eutr_documents`** (bảng không có cột lưu Type hay liên kết PO ở phạm vi này) —
  việc Save trên form chính vẫn hoạt động như hiện tại, chỉ lưu một document duy nhất dựa trên File
  name, Valid from, Valid to đã nhập tay. Riêng nút **Upload** ở Screen1 (Update 6) tạo document
  **độc lập với nút Save** — mỗi file upload thành công tạo một document mới (File name, Valid
  from, Valid to, FileId được hệ thống tự tính, không qua form Save).

**Why this priority**: Thêm document mới là nghiệp vụ chính của màn hình — không có khả năng thêm
mới, danh sách chỉ có giá trị tra cứu tĩnh.

**Independent Test**: Nhấn Add, xác nhận điều hướng sang trang riêng `eutr/documents/add` (không
phải popup), nhập File name và valid from/to, lưu, và xác nhận document mới xuất hiện trong bảng
với đúng file name, valid from, valid to, người tạo và ngày tạo; riêng biệt, xác nhận nhấn Back
quay về danh sách mà không tạo bản ghi. Đồng thời, xác nhận trường Type hiển thị với 2 lựa chọn
PO/Manual, chuyển đổi đúng giữa layout Screen1/Screen2 theo thiết kế, hiển thị dữ liệu mẫu tương
ứng, và mọi tương tác trong khu vực Screen2 (Manual) không gây ra hành động thật nào. Riêng cột PO
name (Type = PO), xác nhận danh sách tải từ API thật và ô tìm kiếm PO gọi lại API với từ khóa nhập
vào (kiểm tra tab Network — có request `refType=15` mới phát sinh khi gõ từ khóa), không chỉ lọc
trên dữ liệu đã tải. Riêng khu vực Upload ở Screen1 (Update 6/7): xác nhận khu vực bị vô hiệu hóa khi chưa
chọn PO, chọn một PO rồi xác nhận giao diện hiển thị đúng theo mẫu `upload.png` (tiêu đề "Upload
File", khung kéo-thả, icon, hàng chip định dạng/kích thước thật), click hoặc kéo-thả để chọn nhiều
file, chọn các file hợp lệ (đúng định dạng/kích thước VÀ tên file có prefix khớp
`eutr_master_documents`) và xác nhận (kiểm tra tab Network) có request
`POST /api/sharepoint/eutr-upload-multi` phát sinh, sau đó xác nhận các document mới (đúng số lượng
file upload thành công) xuất hiện trong danh sách EUTR documents với File name, Valid from (hôm
nay), Valid to (ngày tối đa) đúng, đồng thời có bản ghi `eutr_references` tương ứng
(DocumentId/StepId/RefType/RefValue đúng, cột `RefId` không bị ghi); đồng thời thử chọn kèm một file sai định dạng/quá 10MB và
một file tên không có prefix hợp lệ, xác nhận cả hai bị loại kèm thông báo lỗi riêng biệt trong khi
các file hợp lệ khác vẫn được upload.

**Acceptance Scenarios**:

1. **Given** đang ở danh sách EUTR documents, **When** nhấn nút Add trên toolbar, **Then** hệ
   thống điều hướng sang trang riêng tại `eutr/documents/add` (không mở popup).
2. **Given** đang ở trang Add, **When** trang hiển thị form, **Then** phần thông tin chính gồm các
   trường File name, Valid from, Valid to, nút Save và nút Back; ngoài ra trang còn hiển thị thêm
   trường Type và khu vực List PO/Manual upload theo thiết kế (xem các Acceptance Scenario 7-10) —
   các khu vực này KHÔNG phải control chọn/upload file thật, chỉ mang tính hiển thị.
3. **Given** đang ở trang Add, **When** nhập File name hợp lệ, thiết lập Valid from/Valid to rồi
   nhấn Save, **Then** hệ thống tạo document mới, lưu vào bảng `eutr_documents` và quay về danh
   sách với bản ghi mới hiển thị đúng thông tin.
4. **Given** đang ở trang Add, **When** để trống File name rồi nhấn Save, **Then** hệ thống báo
   lỗi yêu cầu nhập File name và không tạo bản ghi.
5. **Given** đang ở trang Add, **When** nhấn Save mà không thiết lập Valid from/Valid to,
   **Then** hệ thống vẫn cho phép lưu (Valid from/to là tùy chọn) — bản ghi được tạo với các giá
   trị đó để trống.
6. **Given** đang ở trang Add và đã nhập một số thông tin, **When** nhấn nút Back, **Then** hệ
   thống điều hướng về danh sách document và KHÔNG tạo bản ghi nào.
7. **Given** đang ở trang Add, **When** trang hiển thị, **Then** thấy thêm trường Type dạng
   dropdown với 2 lựa chọn "PO" và "Upload manual".
8. **Given** đang ở trang Add, **When** chọn Type = "PO", **Then** hệ thống hiển thị bảng List PO
   (cột PO name, File name, Step name) — cột PO name lấy dữ liệu thật bằng cách
   gọi `POST /api/dynamics/reference` với `refType = 15`; cột File name và Step name lấy dữ liệu
   bằng cách tra cứu `eutr_references` theo `RefType = 0`/`RefValue` = mã PO của dòng đó (Update 8,
   xem FR-037/FR-038), hiển thị trống nếu dòng PO chưa có bản ghi khớp — cùng khu vực
   **Upload File** theo mẫu `upload.png` (thay cho khu vực kéo-thả trước đây, xem FR-024 đến
   FR-033), khu vực này ở trạng thái vô hiệu hóa khi chưa chọn dòng PO nào.
8r. **Given** đang ở trang Add với Type = "PO", **When** một dòng PO có một hoặc nhiều document đã
   được upload thành công (có bản ghi `eutr_references` với `RefType = 0` và `RefValue` = mã PO đó),
   **Then** cột File name hiển thị đúng tên (các) file đã upload cho PO này (mỗi file kèm icon View
   và Delete riêng, Update 10) và cột Step name hiển thị đúng tên (các) Step tương ứng — nếu có
   nhiều document/Step liên kết, hiển thị đầy đủ nhiều giá trị (Update 8).
8s. **(Update 10) Given** một dòng PO có ít nhất một file liên kết trong cột File name, **When**
   nhấn icon View trên một file cụ thể, **Then** hệ thống mở popup xem trước đúng file đó (dùng
   `FileId` của document tương ứng), theo cùng cơ chế đã dùng ở User Story 1 (FR-042).
8t. **(Update 10) Given** một dòng PO có nhiều file liên kết, **When** nhấn icon Delete trên một
   file cụ thể và xác nhận, **Then** hệ thống xóa đúng document đó khỏi `eutr_documents` cùng toàn
   bộ bản ghi `eutr_references` liên quan (cùng giao dịch, FR-039/FR-040), KHÔNG xóa file thật trên
   SharePoint, và chỉ file đó biến mất khỏi cột File name/Step name của dòng PO — các file khác của
   cùng dòng PO (nếu có) không bị ảnh hưởng.
8u. **(Update 10) Given** một file vừa bị xóa qua icon Delete ở List PO, **When** người dùng quay
   lại danh sách EUTR documents chính (User Story 1), **Then** document tương ứng KHÔNG còn xuất
   hiện trong danh sách đó (vì cùng là một bản ghi `eutr_documents`).
8v. **(Update 10) Given** một dòng PO chưa có file nào liên kết (File name/Step name trống), **Then**
   không có icon View/Delete nào hiển thị trên dòng đó (không có gì để xem/xóa).
8a. **Given** đang ở trang Add với Type = "PO", **When** API reference (`refType = 15`) trả về
   danh sách rỗng, **Then** bảng List PO hiển thị trạng thái trống ("No data") thay vì lỗi.
8b. **Given** đang ở trang Add với Type = "PO", **When** gọi API reference (`refType = 15`) thất
   bại (lỗi mạng/máy chủ), **Then** bảng List PO hiển thị thông báo lỗi thân thiện, các trường File
   name/Valid from/Valid to và nút Save/Back vẫn hoạt động bình thường.
8c. **Given** đang ở trang Add với Type = "PO", **When** nhập từ khóa vào ô tìm kiếm PO phía trên
   danh sách, **Then** hệ thống gọi lại API reference (`refType = 15`) kèm từ khóa đó và danh sách
   PO cập nhật theo kết quả trả về từ server (khớp theo tên/mã PO), không chỉ lọc trên dữ liệu đã
   tải trước đó (Update 5, FR-023).
8d. **Given** ô tìm kiếm PO đang có từ khóa và danh sách đã lọc theo kết quả server, **When** người
   dùng xóa hết từ khóa, **Then** danh sách PO tải lại đầy đủ (không lọc), giống trạng thái ban đầu
   khi mở Type = "PO".
8e. **Given** đang ở trang Add với Type = "PO", **When** từ khóa tìm kiếm không khớp PO nào từ API,
   **Then** danh sách PO hiển thị trạng thái trống ("No data"), không phải lỗi.
8f. **Given** đang ở trang Add với Type = "PO" và chưa chọn dòng PO nào trong List PO, **Then** nút
   Upload ở trạng thái vô hiệu hóa (không thể nhấn).
8g. **Given** đang ở trang Add với Type = "PO", **When** người dùng click chọn một dòng PO trong
   List PO, **Then** dòng đó được đánh dấu đang chọn và nút Upload chuyển sang trạng thái khả dụng.
8h. **Given** đã chọn một dòng PO và nút Upload khả dụng, **When** nhấn Upload, **Then** hộp thoại
   chọn file của hệ điều hành mở ra và cho phép chọn nhiều file cùng lúc.
8i. **Given** đã chọn nhiều file hợp lệ (đúng định dạng PDF/DOC/DOCX/XLS/XLSX/JPG/PNG, mỗi file
   tối đa 10MB, VÀ tên file có prefix khớp một bản ghi trong `eutr_master_documents`) cho một PO,
   **When** xác nhận chọn file, **Then** hệ thống gọi `POST /api/sharepoint/eutr-upload-multi` để
   upload các file lên SharePoint vào thư mục ứng với PO đã chọn (thư mục cũ nếu đã tồn tại dưới
   `SharePointEutrPath`, hoặc thư mục mới nếu chưa có), và với mỗi file upload thành công: (a) tạo
   một document mới trong `eutr_documents` (File name = tên file, Valid from = ngày hiện tại, Valid
   to = ngày tối đa, FileId = id trả về từ SharePoint), (b) ghi thêm một bản ghi mới trong
   `eutr_references` (DocumentId = Id document vừa tạo, StepId = StepId của bản ghi
   `eutr_master_documents` đã khớp prefix — cột `RefId` KHÔNG bị ghi, RefType = giá trị "PO" của
   `TAKE_FROM_OPTIONS`, RefValue = mã PO đã chọn) — xem FR-031 đến FR-033 (Update 7). Sau đó hiển thị
   thông báo kết quả (số file upload thành công).
8j. **Given** người dùng chọn một hoặc nhiều file không hợp lệ (sai định dạng hoặc vượt quá 10MB)
   lẫn cùng các file hợp lệ, **When** xác nhận chọn file, **Then** hệ thống loại các file không hợp
   lệ khỏi lượt upload kèm thông báo lỗi rõ ràng liệt kê các file bị loại và lý do, đồng thời vẫn
   upload và tạo document cho các file hợp lệ còn lại.
8k. **Given** đang trong lượt upload nhiều file, **When** một hoặc nhiều file upload lên SharePoint
   thất bại (lỗi mạng/máy chủ) trong khi các file khác thành công, **Then** hệ thống vẫn tạo document
   cho các file thành công, hiển thị thông báo lỗi liệt kê các file thất bại, và không chặn các thao
   tác khác trên trang Add.
8l. **Given** một document vừa được tạo qua khu vực Upload, **When** người dùng quay lại danh sách
   EUTR documents (User Story 1), **Then** document đó xuất hiện trong bảng với đúng File name, Valid
   from (ngày hiện tại), Valid to (ngày tối đa), Created by, Created date, và (Update 8) đúng Step
   name/Type tra cứu từ bản ghi `eutr_references` vừa ghi cho document này; đồng thời cột **File
   name** và **Step name** trên dòng PO tương ứng trong List PO (Screen1) MUST hiển thị đúng file
   vừa upload và Step tương ứng (Update 8 — thay cho hành vi "luôn trống" trước đây ở Update 6).
8m. **Given** đang ở trang Add với Type = "PO" và đã chọn một PO, **When** khu vực Upload hiển thị,
   **Then** giao diện đúng theo mẫu `upload.png`: tiêu đề "Upload File", khung viền nét đứt chứa
   icon đám mây và dòng chữ "Drop file here or click to browse", một dòng phụ và hàng chip nhỏ liệt
   kê đúng định dạng/kích thước thật đang áp dụng (PDF, DOC/DOCX, XLS/XLSX, JPG/PNG, tối đa 10MB) —
   KHÔNG phải số liệu "50 MB"/chỉ 3 định dạng trong hình mẫu gốc (Update 7).
8n. **Given** khu vực Upload đang hiển thị và đã chọn một PO, **When** người dùng kéo-thả một file
   hợp lệ vào khung thay vì click chọn, **Then** hệ thống xử lý giống hệt như khi click chọn file
   (validate định dạng/kích thước, validate prefix, upload lên SharePoint, tạo document và bản ghi
   `eutr_references` nếu hợp lệ) — kéo-thả là một cách kích hoạt tương đương click (Update 7).
8o. **Given** đã chọn một PO và chọn/thả một file có tên KHÔNG bắt đầu bằng bất kỳ `Prefix` nào tồn
   tại trong `eutr_master_documents`, **When** xác nhận chọn file, **Then** hệ thống loại file đó
   khỏi lượt upload, hiển thị cảnh báo rõ ràng ("no matching prefix" hoặc tương đương) liệt kê tên
   file, KHÔNG tạo document và KHÔNG ghi `eutr_references` cho file này; các file khác trong cùng
   lượt (nếu có prefix hợp lệ) vẫn được upload bình thường (Update 7, FR-031/FR-032).
8p. **Given** tên file khớp prefix của nhiều bản ghi `eutr_master_documents` thuộc các StepId khác
   nhau (ví dụ 2 bản ghi có `StepId` = 5 và 7 cùng khớp prefix), **When** file được upload thành
   công, **Then** hệ thống KHÔNG chặn upload — ghi **nhiều bản ghi `eutr_references`** cho file đó,
   mỗi bản ghi ứng với một `StepId` khớp (2 bản ghi trong ví dụ trên: một với `StepId = 5`, một với
   `StepId = 7`), tất cả cùng dùng chung `DocumentId` của document vừa tạo cho file này (Update 7,
   FR-032/FR-033).
8q. **Given** một file đã upload thành công lên SharePoint và tạo document trong `eutr_documents`
   nhưng bước ghi `eutr_references` thất bại (lỗi hệ thống/DB), **When** hệ thống trả kết quả,
   **Then** file đó MUST được báo là thất bại trong thông báo kết quả (không tính là thành công dù
   đã có document), theo đúng ngữ nghĩa per-file đã có ở Update 6 (Update 7, FR-033).
9. **Given** đang ở trang Add, **When** chọn Type = "Upload manual", **Then** hệ thống hiển thị khu vực
   "Drag and drop files to upload" ở trên cùng, nút "Assign condition", và bảng danh sách file
   (checkbox, File name, Action: View/Delete) với dữ liệu mẫu tĩnh giống thiết kế.
10. **Given** đang ở layout Screen2 (Manual), **When** người dùng kéo-thả file vào khu upload, nhấn
    Assign condition, hoặc nhấn View/Delete/checkbox trong bảng demo, **Then** hệ thống KHÔNG thực
    hiện hành động thật nào (không tải file, không gọi API, không điều hướng); Save trên form chính
    vẫn chỉ lưu File name, Valid from, Valid to như hiện tại.

---

### User Story 3 - Sửa thông tin document (Priority: P2)

Người dùng nhấn **Edit** trên một dòng trong bảng. Hệ thống mở một **popup** cho phép chỉnh sửa
File name, Valid from và Valid to. Sau khi lưu, thay đổi được phản ánh ngay trong bảng.

**Why this priority**: Sửa tên hiển thị hoặc hiệu lực của document là nhu cầu thường gặp nhưng
đứng sau xem và thêm mới.

**Independent Test**: Nhấn Edit trên một dòng, đổi File name và/hoặc Valid from/to trong popup,
lưu, và xác nhận giá trị mới hiển thị trong bảng.

**Acceptance Scenarios**:

1. **Given** một document tồn tại, **When** nhấn Edit, **Then** một popup mở ra cho phép chỉnh sửa
   File name, Valid from, Valid to.
2. **Given** popup Edit đang mở, **When** đổi File name và/hoặc Valid from/to rồi lưu, **Then**
   bảng hiển thị giá trị đã cập nhật và popup đóng lại.
3. **Given** popup Edit đang mở, **When** để trống File name rồi lưu, **Then** hệ thống báo lỗi và
   không lưu.
4. **Given** popup Edit đang mở, **When** nhấn Cancel, **Then** popup đóng lại và không có thay
   đổi nào được lưu.

---

### User Story 4 - Xóa document (Priority: P2)

Người dùng nhấn **Delete** trên một dòng, xác nhận, và document bị loại khỏi danh sách. Hệ thống
cũng hỗ trợ xóa nhiều document cùng lúc. **Kể từ Update 9**, khi xóa một document, hệ thống MUST
xóa kèm toàn bộ bản ghi `eutr_references` có `DocumentId` trỏ tới document đó (các bản ghi này
được ghi khi upload file qua Screen1, xem Update 7), để không còn bản ghi tham chiếu mồ côi sau khi
document bị xóa. Việc xóa document và xóa các bản ghi `eutr_references` liên quan được coi là một
giao dịch — nếu bước xóa `eutr_references` thất bại, document đó không bị xóa.

**Why this priority**: Dọn dẹp các document không còn dùng là cần thiết nhưng ít rủi ro nếu triển
khai sau xem, thêm mới và sửa.

**Independent Test**: Tạo một document có ít nhất một bản ghi `eutr_references` liên kết (qua
Upload ở Screen1), nhấn Delete trên dòng đó, xác nhận, và kiểm tra: (a) dòng đó biến mất khỏi bảng,
(b) document không còn tồn tại trong `eutr_documents`, (c) không còn bản ghi nào trong
`eutr_references` có `DocumentId` = Id của document đã xóa.

**Acceptance Scenarios**:

1. **Given** một document tồn tại, **When** nhấn Delete và xác nhận, **Then** bản ghi biến mất
   khỏi bảng.
2. **Given** đã chọn nhiều document, **When** thực hiện xóa nhiều, **Then** tất cả document đã
   chọn biến mất khỏi bảng.
3. **Given** hộp thoại xác nhận xóa hiện ra, **When** người dùng hủy, **Then** không có document
   nào bị xóa.
4. **Given** một document có một hoặc nhiều bản ghi `eutr_references` liên kết (`DocumentId` trỏ
   tới document đó), **When** nhấn Delete trên document đó và xác nhận, **Then** document bị xóa
   khỏi `eutr_documents` VÀ toàn bộ bản ghi `eutr_references` có `DocumentId` tương ứng cũng bị xóa
   (không còn bản ghi mồ côi nào tham chiếu tới document đã xóa).
5. **Given** đã chọn nhiều document để xóa cùng lúc, trong đó có document có bản ghi
   `eutr_references` liên kết và document không có, **When** thực hiện xóa nhiều, **Then** mọi
   document đã chọn đều bị xóa và toàn bộ bản ghi `eutr_references` (nếu có) ứng với `DocumentId`
   của từng document đó cũng bị xóa hết — document không có `eutr_references` nào vẫn bị xóa bình
   thường (không có gì để xóa thêm).
6. **Given** một document có bản ghi `eutr_references` liên kết, **When** nhấn Delete nhưng bước
   xóa `eutr_references` thất bại (lỗi hệ thống/DB), **Then** document đó KHÔNG bị xóa (rollback),
   hệ thống báo lỗi rõ ràng; nếu đang xóa nhiều document cùng lúc, lỗi này không chặn việc xóa các
   document khác trong cùng lượt.

---

### User Story 5 - Xem file thật qua icon View (Update 10 — thay thế placeholder) (Priority: P2)

Cột Action trên mỗi dòng hiển thị một icon **View** cùng với Edit và Delete. **Kể từ Update 10**,
icon này không còn là placeholder: với document có file thật (`FileId` khác null, được upload qua
khu vực Upload ở Screen1, xem Update 6/7), nhấn View MUST mở một popup xem trước file (inline
preview cho PDF/DOCX/XLSX/ảnh, kèm nút Download) — tham khảo đúng mẫu giao diện/luồng đã dùng ở
`compliance-client/src/presentation/pages/compliance-detail` (`FilePreviewer.jsx`/
`DialogFilePreviewer.jsx`) và endpoint backend đã dùng ở đó
(`ComplCompliancesController.GetFileByIds`, `[HttpGet("get-file-by-idref")]`). Với document KHÔNG có
file thật (`FileId = null`, tạo qua form Save nhập tay), icon View MUST hiển thị ở trạng thái vô
hiệu hóa kèm tooltip "No file to view" — không còn hiển thị active-nhưng-no-op như trước.

**Why this priority**: Xem lại file đã upload là nhu cầu thực tế phát sinh ngay sau khi chức năng
Upload (Update 6/7) đưa file thật vào hệ thống — ưu tiên cao hơn giai đoạn placeholder trước đây
nhưng vẫn đứng sau các nghiệp vụ CRUD chính (xem danh sách, thêm, sửa, xóa).

**Independent Test**: Tạo một document có file thật qua khu vực Upload, mở danh sách, nhấn icon
View trên dòng đó và xác nhận popup xem trước hiển thị đúng nội dung file (hoặc thông báo lỗi thân
thiện nếu không xem trước được); riêng biệt, xác nhận một document không có file thật (tạo qua Save)
hiển thị icon View ở trạng thái vô hiệu hóa.

**Acceptance Scenarios**:

1. **Given** một document có `FileId`, **When** bảng hiển thị dòng đó, **Then** cột Action hiển thị
   icon View ở trạng thái active bình thường bên cạnh Edit và Delete.
2. **Given** một document có `FileId`, **When** nhấn vào icon View, **Then** hệ thống mở popup xem
   trước file thật của document đó (gọi `GET /api/eutr-documents/get-file-by-idref?idRef={FileId}`).
3. **Given** một document KHÔNG có `FileId`, **When** bảng hiển thị dòng đó, **Then** icon View
   hiển thị ở trạng thái vô hiệu hóa kèm tooltip "No file to view" và không thể nhấn.

---

### Edge Cases

- Khi danh sách rỗng, bảng hiển thị trạng thái trống thân thiện thay vì lỗi.
- Vì cột Conditions không có trong bảng `eutr_documents` hay `eutr_references`, cột này luôn hiển
  thị trống cho mọi dòng (không có liên kết "[View detail]" nào được hiển thị trong feature này).
- **(Update 9)** Khi xóa một document không có bản ghi `eutr_references` nào liên kết (tạo qua form
  Save nhập tay, chưa từng upload file), bước xóa `eutr_references` theo `DocumentId` chạy bình
  thường và không xóa gì (0 bản ghi bị ảnh hưởng) — không phải lỗi, document vẫn bị xóa như hành vi
  hiện tại.
- **(Update 9)** Khi xóa một document có nhiều bản ghi `eutr_references` liên kết (nhiều `StepId`
  khác nhau từ nhiều lượt upload, xem Update 7/FR-032/FR-033), toàn bộ các bản ghi đó đều bị xóa
  cùng lúc với document, không chỉ bản ghi đầu tiên tìm được.
- **(Update 9)** Khi xóa nhiều document cùng lúc, việc xóa `eutr_references` được xử lý theo từng
  document độc lập (theo `DocumentId` riêng của mỗi document) — lỗi khi xóa `eutr_references` của
  một document không chặn việc xóa document khác trong cùng lượt.
- **(Update 8)** Cột Step name và Type không còn luôn trống — chúng được tra cứu từ bảng
  `eutr_references` theo `DocumentId`. Document chưa từng có bản ghi `eutr_references` nào (tạo qua
  form Save nhập tay, chưa từng upload file) tiếp tục hiển thị hai cột này ở trạng thái trống, không
  phải lỗi.
- **(Update 8)** Khi một document có nhiều bản ghi `eutr_references` trỏ tới nhiều `StepId` khác
  nhau, cột Step name hiển thị đầy đủ tất cả Step name tương ứng (dùng chip + "+N more" + tooltip
  khi vượt quá số lượng hiển thị trực tiếp, theo mẫu cột "Country Codes" ở Country Groups) — không
  cắt bớt dữ liệu.
- **(Update 8)** Khi việc tra cứu `eutr_references`/`eutr_steps` cho Step name/Type (danh sách) hoặc
  File name/Step name (List PO) thất bại (lỗi mạng/máy chủ/DB), hệ thống hiển thị các cột liên quan
  ở trạng thái lỗi thân thiện (hoặc trống) thay vì lỗi hệ thống, và KHÔNG chặn các cột/thao tác khác
  của bảng.
- Khi thêm/sửa một File name đã trùng với document khác, hệ thống vẫn cho phép lưu bình thường
  (không có ràng buộc duy nhất trên File name).
- Khi người dùng nhấn Edit nhưng không thay đổi gì rồi lưu, hệ thống lưu lại nguyên giá trị hiện
  tại mà không báo lỗi.
- Khi một document đã bị xóa được truy cập lại qua Edit (ví dụ do dữ liệu cũ trên trình duyệt),
  hệ thống báo not-found rõ ràng thay vì lỗi hệ thống.
- Khi người dùng nhấn icon View, không có trang/popup nào mở ra và không có yêu cầu nào được gửi
  tới server — đây là hành vi đúng theo phạm vi hiện tại (placeholder chưa xử lý); icon vẫn hiển
  thị active bình thường, không bị làm mờ/disable.
- Khi người dùng nhấn Back trên trang Add mà chưa nhấn Save, hệ thống điều hướng thẳng về danh
  sách mà KHÔNG tạo bản ghi và KHÔNG cảnh báo xác nhận (form chỉ có 3 trường đơn giản, không cần
  cảnh báo mất dữ liệu).
- Khi người dùng không có quyền với một thao tác (theo policy của API), nút tương ứng không khả
  dụng hoặc thao tác bị từ chối với thông báo rõ ràng.
- Khi lưu/xóa thất bại do lỗi mạng hoặc máy chủ, người dùng nhận thông báo lỗi và dữ liệu không bị
  thay đổi sai lệch.
- Khi chuyển đổi qua lại giữa Type = "PO" và "Upload manual" trên trang Add, giao diện chuyển đúng layout
  tương ứng; dữ liệu mẫu tĩnh hiển thị lại đúng như ban đầu (không có trạng thái lưu tạm giữa hai
  lần chuyển).
- Khi rời trang Add (Back hoặc điều hướng khác) rồi quay lại, Type được đặt lại về giá trị mặc định
  ban đầu (không nhớ lựa chọn trước đó).
- Khi người dùng tương tác với khu vực Manual upload ở Screen2 (kéo-thả, Assign condition, View/
  Delete, checkbox), không có yêu cầu nào được gửi tới server và Save vẫn chỉ tạo bản ghi dựa trên
  File name, Valid from, Valid to — đây là hành vi đúng theo phạm vi hiện tại (chỉ giao diện, chưa
  có chức năng), ngoại trừ việc tải danh sách PO name và nút Upload thật ở Screen1 (xem bên dưới,
  Update 6).
- Khi API reference (`refType = 15`, `RSVNEutrPurchOrders`) trả về danh sách rỗng, bảng List PO
  hiển thị trạng thái trống thân thiện thay vì lỗi.
- Khi gọi API reference (`refType = 15`) thất bại (lỗi mạng/máy chủ), bảng List PO hiển thị thông
  báo lỗi và không chặn các trường/thao tác khác trên trang Add (File name, Valid from, Valid to,
  Save, Back) hoạt động bình thường.
- `refType = 16` (`RSVNEutrSalesOrderPurchases`) không có giao diện nào gọi tới trong phạm vi
  feature này; việc refType tồn tại và trả về dữ liệu đúng được xác minh trực tiếp (gọi API
  reference với `refType = 16`, không qua UI).
- Khi người dùng nhập từ khóa vào ô tìm kiếm PO rồi xóa hết ngay sau đó (trước khi kết quả tìm kiếm
  trả về), hệ thống hiển thị đúng danh sách tương ứng với trạng thái ô tìm kiếm hiện tại (rỗng →
  danh sách mặc định), không hiển thị nhầm kết quả của một lượt gọi API cũ đã lỗi thời (Update 5).
- Khi từ khóa tìm kiếm PO không khớp bản ghi nào từ API, danh sách hiển thị trạng thái trống
  ("No data") — không phải lỗi (Update 5, FR-023).
- Khi gọi API tìm kiếm PO (`refType = 15` kèm từ khóa) thất bại, ô tìm kiếm và danh sách hiển thị
  thông báo lỗi thân thiện theo cùng cách xử lý lỗi đã có ở Update 4 (FR-017), không chặn phần còn
  lại của trang Add.
- Khi chưa chọn dòng PO nào trong List PO (Screen1), nút Upload MUST ở trạng thái vô hiệu hóa —
  người dùng không thể mở hộp thoại chọn file (Update 6).
- Khi người dùng chọn file có định dạng không nằm trong PDF/DOC/DOCX/XLS/XLSX/JPG/PNG hoặc vượt quá
  10MB, hệ thống MUST loại file đó khỏi lượt upload, hiển thị thông báo lỗi liệt kê tên file và lý
  do, và vẫn tiếp tục upload các file hợp lệ còn lại trong cùng lượt chọn (Update 6).
- Khi tất cả file trong một lượt chọn đều không hợp lệ (sai định dạng/quá kích thước), hệ thống MUST
  không gọi API upload, chỉ hiển thị thông báo lỗi, không tạo document nào.
- Khi gọi `POST /api/sharepoint/eutr-upload-multi` thất bại toàn bộ (lỗi mạng/máy chủ trước khi kịp
  upload file nào), hệ thống MUST hiển thị thông báo lỗi thân thiện và không tạo document nào; các
  trường/thao tác khác trên trang Add vẫn hoạt động bình thường.
- Khi một số file trong lượt upload thành công và một số thất bại (lỗi phía SharePoint), hệ thống
  MUST vẫn tạo document cho các file thành công và báo lỗi rõ ràng cho các file thất bại (không
  rollback các file đã thành công).
- PO đã chọn chỉ dùng để xác định thư mục SharePoint (tìm thư mục cũ hoặc tạo mới) — bảng
  `eutr_documents` KHÔNG lưu liên kết PO trực tiếp (không đổi so với Update 6). **Kể từ Update 8**,
  liên kết PO ↔ document/Step vẫn được suy ra gián tiếp qua `eutr_references` (`RefType=0`,
  `RefValue`=mã PO) — nên sau khi upload thành công, cột File name/Step name trên dòng PO tương ứng
  trong List PO MUST hiển thị đúng file/Step vừa liên kết (thay cho hành vi "luôn trống" đã áp dụng
  từ Update 4 đến trước Update 8).
- Khi người dùng chọn một PO khác (đổi lựa chọn) trước khi nhấn Upload, thư mục SharePoint đích của
  lượt upload tiếp theo MUST tương ứng với PO mới đang được chọn tại thời điểm nhấn Upload.
- Khi tên file KHÔNG bắt đầu bằng bất kỳ `Prefix` nào tồn tại trong `eutr_master_documents`, hệ
  thống MUST loại file đó khỏi lượt upload, hiển thị cảnh báo rõ ràng, KHÔNG tạo document và KHÔNG
  ghi `eutr_references` cho file này — theo cùng cơ chế per-file đã có ở Update 6 (không chặn các
  file khác trong cùng lượt) (Update 7).
- Khi tên file khớp prefix của nhiều bản ghi `eutr_master_documents` (nhiều `StepId` khác nhau), hệ
  thống KHÔNG chặn upload — ghi nhiều bản ghi `eutr_references` cho cùng file đó (một bản ghi cho
  mỗi `StepId` khớp), tất cả cùng `DocumentId` của document vừa tạo cho file này (Update 7, sửa lại
  từ quyết định "chọn `Id` nhỏ nhất" ban đầu).
- Khi `eutr_master_documents` hiện không có bản ghi nào (bảng rỗng) hoặc API tra cứu prefix thất bại
  (lỗi mạng/DB), mọi file trong lượt upload đều bị coi là "không khớp prefix" và bị loại kèm cảnh
  báo — hệ thống KHÔNG cho phép bỏ qua bước validate này (Update 7).
- Khi một file đã upload thành công lên SharePoint và tạo được document trong `eutr_documents`,
  nhưng bước ghi `eutr_references` sau đó thất bại, hệ thống MUST báo file đó là thất bại trong kết
  quả trả về cho người dùng (không tính là thành công dù đã có document được tạo) — đây là ngoại lệ
  duy nhất trong đó việc "tạo document thành công" không đồng nghĩa "file thành công" (Update 7,
  khác với FR-030 nơi document luôn được coi là thành công một khi đã tạo).
- So với Update 6, khu vực Upload giờ hỗ trợ kéo-thả file thật (ngoài click chọn file) — kéo một
  file không hợp lệ (sai định dạng/kích thước hoặc sai prefix) vào khung vẫn bị validate và loại bỏ
  giống hệt khi chọn qua hộp thoại file, không có ngoại lệ nào cho luồng kéo-thả (Update 7).
- **(Update 10)** Khi gọi `get-file-by-idref` thất bại (lỗi mạng/máy chủ) hoặc file có định dạng
  không được popup xem trước hỗ trợ (khác PDF/DOCX/XLSX/ảnh), popup MUST hiển thị thông báo lỗi/
  cảnh báo thân thiện thay vì treo giao diện; người dùng vẫn đóng được popup và các thao tác khác
  trên trang không bị ảnh hưởng.
- **(Update 10)** Icon View trên một document không có `FileId` luôn ở trạng thái vô hiệu hóa —
  không có trường hợp nào nhấn được vào icon này để kích hoạt gọi API hoặc mở popup rỗng.
- **(Update 10)** Khi xóa file cuối cùng còn liên kết với một PO trong List PO, cột File name/Step
  name của dòng PO đó trở về trạng thái trống (giống dòng PO chưa từng có file nào được upload),
  không hiển thị lỗi.
- **(Update 10)** Khi người dùng nhấn Delete trên một file trong List PO nhưng document đó đã bị
  xóa trước đó (ví dụ do vừa xóa từ danh sách EUTR documents chính ở một tab khác), hệ thống MUST
  báo not-found rõ ràng thay vì lỗi hệ thống, theo cùng mẫu xử lý đã có ở nơi khác trong feature này
  (ví dụ Edit một document đã bị xóa).
- **(Update 10)** Việc xóa một file trong List PO KHÔNG gọi API xóa file thật trên SharePoint — file
  đó vẫn còn tồn tại trên SharePoint sau khi xóa, chỉ không còn bản ghi nào trong `eutr_documents`/
  `eutr_references` trỏ tới nó nữa; đây là hành vi có chủ đích, không phải lỗi hay thiếu sót.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Hệ thống MUST hiển thị danh sách các EUTR document dạng bảng với các cột: File name,
  Step name, Conditions, Type, Valid from, Valid to, Created by, Created date và cột Action (Edit,
  Delete, View).
- **FR-002**: Hệ thống MUST hiển thị màn hình trong mục điều hướng "EUTR documents" với breadcrumb
  "EUTR > EUTR documents".
- **FR-003**: Vì bảng `eutr_documents` không lưu Conditions, hệ thống MUST hiển thị cột Conditions
  luôn ở trạng thái trống cho mọi dòng trong phạm vi feature này. Cột Step name và Type KHÔNG còn
  thuộc phạm vi FR này kể từ Update 8 — xem FR-034/FR-035/FR-036.
- **FR-004**: Người dùng MUST có thể phân trang danh sách khi số bản ghi vượt một trang và chuyển
  trang.
- **FR-005**: Người dùng MUST có thể nhấn nút **Add** trên toolbar để điều hướng sang một trang
  riêng (`eutr/documents/add`), KHÔNG phải popup, nhằm tạo document mới.
- **FR-006**: Trên trang Add, người dùng MUST có thể nhập File name và thiết lập Valid from, Valid
  to. Bản thân 3 trường này và nút Save MUST KHÔNG có control chọn/upload file thật gắn kèm. Khu
  vực upload thật duy nhất trên trang Add là nút **Upload** ở Screen1 (Type = PO, xem FR-024 đến
  FR-030, Update 6); khu vực "Drag and drop files to upload" ở Screen2 (Type = Upload manual, mô tả
  ở FR-018) tiếp tục chỉ mang tính hiển thị (silent no-op, không xử lý file thả vào) — chức năng
  upload thật cho Screen2 sẽ được bổ sung ở một tính năng sau (xem Clarifications).
- **FR-006a**: Trang Add MUST có nút **Back** để điều hướng về danh sách document mà KHÔNG tạo bản
  ghi; nhấn Back không yêu cầu xác nhận (không cảnh báo mất dữ liệu).
- **FR-007**: Hệ thống MUST yêu cầu nhập File name (không được để trống) khi tạo mới; Valid from
  và Valid to là tùy chọn.
- **FR-007b**: Hệ thống MUST KHÔNG áp dụng ràng buộc duy nhất trên File name — nhiều document được
  phép có cùng File name.
- **FR-008**: Khi Save trên trang Add thành công, hệ thống MUST lưu document vào bảng
  `eutr_documents` (File name, Valid from, Valid to) và ghi nhận người tạo, ngày tạo tự động, sau
  đó điều hướng về danh sách.
- **FR-009**: Người dùng MUST có thể nhấn **Edit** trên một dòng để mở popup chỉnh sửa File name,
  Valid from, Valid to của document đó.
- **FR-010**: Hệ thống MUST yêu cầu File name không được để trống khi sửa.
- **FR-011**: Người dùng MUST có thể xóa một document, có bước xác nhận trước khi xóa. Kể từ
  Update 9, việc xóa này MUST bao gồm cả bước xóa `eutr_references` liên quan — xem FR-039/FR-040.
- **FR-012**: Hệ thống MUST hỗ trợ xóa nhiều document cùng lúc. Kể từ Update 9, mỗi document trong
  lượt xóa nhiều MUST được dọn `eutr_references` liên quan theo đúng `DocumentId` của nó — xem
  FR-039/FR-040.
- **FR-013**: Cột Action MUST hiển thị một icon **View** bên cạnh Edit và Delete trên mỗi dòng.
  *(Superseded by Update 10 — xem FR-042)*: khi document có `FileId`, icon View MUST active và mở
  popup xem trước file thật; khi document KHÔNG có `FileId`, icon View MUST hiển thị ở trạng thái
  vô hiệu hóa kèm tooltip "No file to view" — không còn là placeholder silent no-op như trước Update
  10.
- **FR-014**: Hệ thống MUST tôn trọng quyền truy cập đã định nghĩa cho từng thao tác (xem, thêm
  mới, sửa, xóa); thao tác không được phép phải bị ngăn chặn.
- **FR-015**: Toàn bộ văn bản hiển thị cho người dùng trên front-end MUST bằng tiếng Anh, bao gồm:
  nhãn cột (File name, Step name, Conditions, Type, Valid from, Valid to, Created by, Created
  date, Action), nút (Add, Edit, Delete, View, Save, Back, Cancel, Assign condition, Download —
  Update 10), breadcrumb (EUTR > EUTR documents), thông báo kiểm tra/lỗi, thông báo thành công,
  trạng thái rỗng ("No data"), tooltip "No file to view" (Update 10), và hộp thoại xác nhận xóa.
- **FR-016**: Trang Add MUST hiển thị thêm trường **Type** dạng dropdown với 2 lựa chọn "PO" và
  "Upload manual" (tái sử dụng hằng số `TAKE_FROM_OPTIONS` có sẵn trong codebase), đặt cùng các
  trường hiện có (File name, Valid from, Valid to). Trường này KHÔNG được lưu vào bảng
  `eutr_documents` ở phạm vi hiện tại (bảng không có cột lưu Type).
- **FR-017**: Khi Type = "PO", trang Add MUST hiển thị: (a) bảng **List PO** với các cột PO name,
  File name, Step name; (b) nút **Upload** (thay cho khu vực "Drag and drop
  files to upload" trước đây — xem FR-024 đến FR-030, Update 6). Cột **PO name** MUST lấy dữ liệu
  thật bằng cách gọi API tham chiếu dùng chung `POST /api/dynamics/reference` với `refType = 15`
  (xem FR-021); cột **File name** và **Step name** MUST được tính theo FR-037/FR-038 (Update 8 —
  thay thế quy tắc "luôn trống" áp dụng từ Update 4 đến trước Update 8). Khi API trả về rỗng hoặc
  lỗi, bảng MUST hiển thị trạng thái trống/lỗi tương ứng thay vì chặn các phần khác của trang.
  *(Superseded by Update 10: cột Action cấp-dòng với View/Delete không còn tồn tại — mỗi file riêng
  lẻ trong cột File name có icon View/Delete thật riêng, xem FR-043/FR-044.)*
- **FR-018**: Khi Type = "Upload manual", trang Add MUST hiển thị: (a) khu vực "Drag and drop files to
  upload" ở trên cùng; (b) nút "Assign condition"; (c) bảng danh sách file với checkbox chọn dòng,
  cột File name, Action (View, Delete). Bảng này MUST hiển thị dữ liệu mẫu tĩnh (hard-coded, giống
  thiết kế: File 1..File 8). *(Không thuộc phạm vi Update 10 — bảng demo Screen2 tiếp tục silent
  no-op, không đổi.)*
- **FR-019**: Mọi tương tác trong các khu vực Type/Manual upload (kéo-thả file vào khu upload ở
  Screen2, nhấn "Assign condition", nhấn View/Delete hoặc checkbox trong bảng demo) MUST KHÔNG thực
  hiện bất kỳ hành động thật nào (không tải file lên, không gọi API, không điều hướng) — silent
  no-op, cùng mẫu với FR-013 trước Update 10. Nút **Upload** ở Screen1 (FR-024 đến FR-030) và các
  icon View/Delete theo từng file trong cột File name của List PO (Update 10, FR-043/FR-044) là các
  ngoại lệ duy nhất — đây là các control thật, có gọi API và thay đổi dữ liệu.
- **FR-020**: Việc bổ sung Type/List PO/Manual layout MUST KHÔNG làm thay đổi hành vi hiện có của
  File name, Valid from, Valid to, Save, Back (FR-006 đến FR-008, FR-006a) — Save vẫn tạo (chỉ) một
  document mới dựa trên 3 trường này. Việc nút Upload (FR-024 đến FR-030) tạo thêm document khác
  MUST độc lập với và không ảnh hưởng tới hành vi của Save.
- **FR-021**: Backend MUST đăng ký D365 entity `RSVNEutrPurchOrders` với **`refType = 15`** trong
  bảng ánh xạ entity (`EntityMappings`) dùng bởi endpoint tham chiếu dùng chung
  `POST /api/dynamics/reference` (action `ReferenceData` trong `DynController`) — KHÔNG tạo endpoint
  GET/POST riêng mới. Gọi `POST /api/dynamics/reference` với `refType = 15` là nguồn dữ liệu cho cột
  PO name của bảng List PO (FR-017).
- **FR-022**: Backend MUST đăng ký thêm D365 entity `RSVNEutrSalesOrderPurchases` với
  **`refType = 16`** trong cùng bảng ánh xạ entity của endpoint `POST /api/dynamics/reference` —
  KHÔNG tạo endpoint riêng mới. `refType = 16` KHÔNG được gọi bởi bất kỳ màn hình nào trong phạm vi
  feature `004-eutr-documents` — được chuẩn bị sẵn cho một tính năng phát triển sau.
- **FR-023**: Ô tìm kiếm PO phía trên bảng List PO (Type = PO) MUST lọc bằng cách gọi lại
  `POST /api/dynamics/reference` với `refType = 15` kèm từ khóa người dùng nhập làm điều kiện lọc
  (khớp theo tên/mã PO), thay vì chỉ lọc trên tập dữ liệu PO đã tải sẵn ở client. Xóa hết từ khóa
  MUST tải lại danh sách PO mặc định (không lọc). Khi từ khóa không khớp PO nào, danh sách MUST
  hiển thị trạng thái trống ("No data") theo cùng hành vi rỗng đã định nghĩa ở FR-017.
- **FR-024** *(Update 6)*: Bảng List PO (Screen1, Type = PO) MUST cho phép người dùng chọn (click)
  đúng một dòng PO tại một thời điểm; nút **Upload** MUST ở trạng thái vô hiệu hóa khi chưa có dòng
  PO nào được chọn, và chuyển sang khả dụng ngay khi một dòng PO được chọn.
- **FR-025** *(Update 6)*: Khi nút Upload khả dụng và được nhấn, hệ thống MUST mở hộp thoại chọn
  file của hệ điều hành cho phép chọn **nhiều file cùng lúc**.
- **FR-026** *(Update 6)*: Hệ thống MUST chỉ chấp nhận file có định dạng PDF, DOC/DOCX, XLS/XLSX,
  JPG/PNG với kích thước tối đa 10MB mỗi file (tái áp dụng ràng buộc đã thống nhất ở clarify đầu
  tiên, trước đây bị hoãn ở Update 1). File không thỏa điều kiện MUST bị loại khỏi lượt upload kèm
  thông báo lỗi liệt kê tên file và lý do; các file hợp lệ còn lại trong cùng lượt chọn MUST vẫn
  được upload bình thường.
- **FR-027** *(Update 6)*: Sau khi người dùng xác nhận chọn file hợp lệ, front-end MUST gọi API mới
  **`POST /api/sharepoint/eutr-upload-multi`**, gửi kèm các file đã chọn và thông tin PO đang được
  chọn ở List PO (mã PO).
- **FR-028** *(Update 6)*: Backend MUST bổ sung endpoint **`POST /api/sharepoint/eutr-upload-multi`**
  trong `SharePointController` hiện có (`Consumes("multipart/form-data")`, theo cùng mẫu với
  endpoint có sẵn `POST /api/sharepoint/upload-multi`). Endpoint này MUST dùng
  `_configuration["SharePointEutrPath"]` làm thư mục gốc SharePoint (KHÔNG dùng
  `SharePointCompPath`) và MUST gọi một service **mới** `_eutrUploadService.UploadMultipleToSharePointAndSaveDataAsync`
  — KHÔNG dùng lại `_complUploadService` hiện có. Với mã PO nhận được, backend MUST xác định thư
  mục con tương ứng dưới thư mục gốc: dùng thư mục đã tồn tại nếu có, hoặc tạo mới thư mục đó nếu
  chưa có, rồi upload các file vào thư mục này.
- **FR-029** *(Update 6)*: Với mỗi file upload thành công lên SharePoint, backend MUST tạo một bản
  ghi mới trong bảng `eutr_documents` với: File name (`Name`) = tên file gốc, Valid from
  (`ValidFrom`) = ngày hiện tại (ngày hệ thống tại thời điểm upload), Valid to (`ValidTo`) = ngày
  tối đa (sentinel "không giới hạn", xem Assumptions), FileId (`FileId`) = id file trả về từ
  SharePoint; đồng thời ghi nhận người tạo, ngày tạo tự động theo cùng cách các document khác được
  tạo (FR-008). Bản ghi `eutr_documents` này MUST **KHÔNG** có thêm cột lưu liên kết PO (bảng
  `eutr_documents` không có cột lưu PO ở phạm vi feature này) — liên kết PO/Step của document (kể
  từ Update 7) được ghi ở bảng riêng `eutr_references`, xem FR-032.
- **FR-030** *(Update 6)*: Nếu một hoặc nhiều file trong cùng lượt upload thất bại (lỗi mạng/máy
  chủ khi upload lên SharePoint) trong khi các file khác thành công, hệ thống MUST vẫn tạo document
  cho các file thành công (FR-029) và hiển thị thông báo lỗi liệt kê rõ các file thất bại — không
  rollback các file đã upload/lưu thành công. Nếu toàn bộ lượt gọi API thất bại trước khi upload
  được file nào, hệ thống MUST không tạo document nào và hiển thị thông báo lỗi thân thiện; các
  trường/thao tác khác trên trang Add (File name, Valid from, Valid to, Save, Back, List PO) MUST
  tiếp tục hoạt động bình thường.
- **FR-031** *(Update 7)*: Khu vực Upload ở Screen1 MUST được thiết kế lại theo mẫu hình
  `upload.png`: tiêu đề "Upload File", một khung viền nét đứt chứa icon đám mây và dòng chữ "Drop
  file here or click to browse", một dòng phụ và hàng chip nhỏ liệt kê định dạng/kích thước chấp
  nhận. Khung MUST hiển thị đúng danh sách định dạng/kích thước **thật** đang áp dụng (PDF,
  DOC/DOCX, XLS/XLSX, JPG/PNG, tối đa 10MB/file — KHÔNG đổi so với FR-026, KHÔNG sao chép số liệu
  "50MB"/3 định dạng trong hình mẫu). Khung MUST chấp nhận **cả kéo-thả file thật lẫn click để mở
  hộp thoại chọn file** — kéo-thả một file vào khung MUST kích hoạt đúng luồng validate (FR-026,
  FR-032) và upload (FR-027 đến FR-030) như khi chọn file qua hộp thoại.
- **FR-032** *(Update 7)*: Trước khi upload lên SharePoint, với mỗi file đã qua validate định dạng/
  kích thước (FR-026), hệ thống MUST validate thêm: tên file phải bắt đầu bằng (không phân biệt hoa/
  thường) giá trị `Prefix` của ít nhất một bản ghi đang tồn tại trong bảng `eutr_master_documents`
  (dữ liệu thuộc feature `002-eutr-masters`). File không khớp bất kỳ `Prefix` nào MUST bị loại khỏi
  lượt upload kèm cảnh báo rõ ràng liệt kê tên file, theo cùng cơ chế per-file đã có ở FR-026 (không
  chặn các file hợp lệ khác trong cùng lượt). Khi tên file khớp `Prefix` của **nhiều** bản ghi
  `eutr_master_documents` (nhiều `StepId` khác nhau), hệ thống MUST KHÔNG chặn upload — tập hợp
  **toàn bộ** các `StepId` khớp (không chỉ chọn một bản ghi duy nhất) để dùng ở FR-033.
- **FR-033** *(Update 7)*: Với mỗi file upload thành công lên SharePoint và đã tạo document ở
  FR-029, backend MUST ghi thêm **một bản ghi `eutr_references` cho mỗi `StepId`** đã khớp prefix ở
  FR-032 (một file khớp N bản ghi `eutr_master_documents` distinct theo `StepId` thì MUST tạo N bản
  ghi `eutr_references`): `DocumentId` = `Id` của document `eutr_documents` vừa tạo cho file đó
  (**giống nhau** trên tất cả N bản ghi); **`StepId`** (cột **mới**, MUST được bổ sung vào bảng
  `eutr_references` — xem Key Entities và Assumptions) = từng `StepId` khớp (khác nhau giữa các bản
  ghi); `RefType` = giá trị "PO" trong hằng số `TAKE_FROM_OPTIONS` (`= 0`, giống nhau trên tất cả N
  bản ghi); `RefValue` = mã PO đang được chọn ở List PO (cùng giá trị dùng ở FR-027/FR-028, giống
  nhau trên tất cả N bản ghi). Các bản ghi này MUST **KHÔNG** ghi giá trị vào cột `RefId` hiện có của
  `eutr_references` (cột đó giữ nguyên mục đích thiết kế cũ — trỏ tới `eutr_template_details`,
  không liên quan tới luồng Upload). Nếu một trong các bước ghi `eutr_references` này thất bại sau
  khi document đã tạo thành công (dù các bản ghi khác của cùng file đã ghi được), hệ thống MUST báo
  file đó là thất bại trong kết quả trả về (không tính là thành công) — đây là điều kiện bổ sung cho
  "thành công" của một file so với FR-029/FR-030 (chỉ áp dụng từ Update 7).
- **FR-034** *(Update 8)*: Hệ thống MUST tính **Step name** và **Type** cho mỗi document trong danh
  sách EUTR documents (User Story 1) bằng cách tra cứu các bản ghi `eutr_references` có
  `DocumentId` = `Id` của document đó: **Type** = nhãn `TAKE_FROM_OPTIONS` ứng với `RefType` của các
  bản ghi này (giống nhau trên mọi bản ghi cùng `DocumentId`); **Step name** = tên Step (JOIN
  `StepId` với `eutr_steps.Name`) của mọi `StepId` phân biệt trong các bản ghi đó. Document không
  có bản ghi `eutr_references` nào tương ứng MUST tiếp tục hiển thị Step name và Type ở trạng thái
  trống (không lỗi).
- **FR-035** *(Update 8)*: Khi một document có nhiều bản ghi `eutr_references` với nhiều `StepId`
  phân biệt, cột Step name MUST hiển thị đầy đủ tất cả Step name tương ứng (không chỉ một); giao
  diện MAY giới hạn số lượng hiển thị trực tiếp và gộp phần còn lại vào một chỉ báo dạng "+N more"
  kèm tooltip liệt kê đầy đủ, theo đúng mẫu hiển thị nhiều giá trị đã áp dụng ở cột "Country Codes"
  (màn Country Groups, `useCountryGroupColumns.jsx`).
- **FR-036** *(Update 8)*: Cột **Conditions** MUST tiếp tục hiển thị trống trên mọi dòng trong phạm
  vi feature này — không nằm trong yêu cầu Update 8, không đổi so với FR-003.
- **FR-037** *(Update 8)*: Trên trang Add (Screen1, Type = "PO"), với mỗi dòng PO trong bảng List
  PO, hệ thống MUST tính **File name** và **Step name** bằng cách tra cứu các bản ghi
  `eutr_references` có `RefType = 0` ("PO") và `RefValue` = mã PO của dòng đó: **File name** =
  `Name` của (các) document `eutr_documents` có `Id` trùng `DocumentId` của các bản ghi khớp (JOIN
  theo `DocumentId`); **Step name** = tên Step (JOIN `StepId` với `eutr_steps.Name`) của các bản ghi
  khớp đó, tính theo đúng cách ở FR-034. Dòng PO chưa có bản ghi `eutr_references` nào khớp
  (`RefType=0`, `RefValue`=mã PO đó) MUST tiếp tục hiển thị File name và Step name ở trạng thái
  trống.
- **FR-038** *(Update 8)*: Khi một dòng PO có nhiều document/Step liên kết (nhiều bản ghi
  `eutr_references` khớp `RefType=0`/`RefValue`), cột File name và Step name trong List PO MUST
  hiển thị đầy đủ tất cả giá trị tương ứng, áp dụng cùng cách hiển thị nhiều giá trị đã mô tả ở
  FR-035.
- **FR-039** *(Update 9)*: Khi xóa một document (FR-011) hoặc xóa nhiều document (FR-012), với mỗi
  document bị xóa, backend MUST xóa toàn bộ bản ghi `eutr_references` có `DocumentId` = `Id` của
  document đó — không phân biệt số lượng bản ghi khớp (0, 1, hoặc nhiều bản ghi ứng với nhiều
  `StepId` khác nhau từ nhiều lượt upload, xem Update 7/FR-032/FR-033) và không phân biệt `RefType`.
  Việc xóa `eutr_references` MUST hoàn tất trước khi (hoặc trong cùng một đơn vị làm việc với) việc
  xóa bản ghi `eutr_documents` tương ứng — không để lại bản ghi `eutr_references` mồ côi trỏ tới
  `DocumentId` đã bị xóa.
- **FR-040** *(Update 9)*: Việc xóa `eutr_references` và xóa `eutr_documents` của cùng một document
  MUST được xử lý như một giao dịch (transaction) duy nhất theo từng document: nếu bước xóa
  `eutr_references` thất bại, document đó KHÔNG bị xóa (rollback) và hệ thống MUST báo lỗi rõ ràng
  cho document đó. Khi xóa nhiều document cùng lúc (FR-012), lỗi xảy ra ở một document KHÔNG được
  chặn việc xử lý xóa các document khác trong cùng lượt (per-item, cùng ngữ nghĩa với FR-030).
- **FR-041** *(Update 10)*: Backend MUST bổ sung endpoint **`GET /api/eutr-documents/get-file-by-idref`**
  trong `EutrDocumentsController` hiện có, nhận `idRef` (query string) = `FileId` của một
  `eutr_documents`, tham khảo đúng mẫu hàm `[HttpGet("get-file-by-idref")] GetFileByIds` trong
  `ComplCompliancesController.cs` — cùng gọi service SharePoint đọc file kèm metadata hiện có
  (`ReadFileWithMetaAsync`) và trả về nội dung file dạng base64 kèm content type, file name. Endpoint
  này KHÔNG tạo service đọc file mới, KHÔNG thay đổi dữ liệu (read-only).
- **FR-042** *(Update 10)*: Icon **View** trên cột Action của danh sách EUTR documents (User Story 1)
  MUST thay thế hành vi placeholder của FR-013: khi document có `FileId`, nhấn View MUST mở popup
  xem trước file (inline preview PDF/DOCX/XLSX/ảnh kèm nút Download, theo đúng mẫu giao diện của
  `compliance-detail`'s `FilePreviewer.jsx`/`DialogFilePreviewer.jsx`), lấy dữ liệu qua FR-041; khi
  document KHÔNG có `FileId`, icon View MUST hiển thị ở trạng thái vô hiệu hóa kèm tooltip "No file
  to view".
- **FR-043** *(Update 10)*: Trên trang Add (Screen1, Type = PO), mỗi file riêng lẻ hiển thị trong cột
  File name của bảng List PO (mỗi giá trị/chip tương ứng một document liên kết với PO đó, tính theo
  FR-037/FR-038) MUST có icon **View** riêng; nhấn vào MUST mở popup xem trước đúng file đó, dùng
  cùng cơ chế ở FR-042 (FR-041) với `FileId` của document tương ứng.
- **FR-044** *(Update 10)*: Mỗi file riêng lẻ hiển thị trong cột File name của bảng List PO (cùng
  phạm vi với FR-043) MUST có icon **Delete** riêng; sau khi người dùng xác nhận, hệ thống MUST xóa
  document đó khỏi `eutr_documents` và toàn bộ bản ghi `eutr_references` có `DocumentId` tương ứng
  (dùng lại API xóa document đơn hiện có, `DELETE /api/eutr-documents/{id}`, cùng giao dịch và ngữ
  nghĩa với FR-039/FR-040) — KHÔNG gọi thêm bất kỳ API xóa file thật trên SharePoint (file vẫn còn
  tồn tại trên SharePoint sau khi xóa). Sau khi xóa, file đó MUST biến mất khỏi cả cột File name/Step
  name của dòng PO tương ứng trong List PO VÀ khỏi danh sách EUTR documents chính (User Story 1), vì
  cùng là một bản ghi `eutr_documents`.
- **FR-045** *(Update 10)*: Icon View/Delete cấp-dòng trước đây trên cột Action của bảng List PO
  (silent no-op theo FR-017/FR-019 trước Update 10) MUST được gỡ bỏ hoàn toàn, thay thế bằng các icon
  View/Delete theo từng file ở FR-043/FR-044. Dòng PO chưa có file nào liên kết (File name/Step name
  trống) MUST tiếp tục không hiển thị icon View/Delete nào (không có gì để thao tác).

### Key Entities *(include if feature involves data)*

- **EUTR Document**: Đại diện cho một document EUTR. Thuộc tính: định danh, File name (văn bản,
  không duy nhất giữa các document), Valid from, Valid to, người tạo, ngày tạo, người cập nhật,
  ngày cập nhật. Lưu vào bảng `eutr_documents` theo `docs/design/eutr/eutr_db.sql`; cột `Name` MUST
  được migrate sang VARCHAR(255) để lưu File name dạng văn bản (hiện đang là BIGINT trong schema).
  Document được tạo theo 2 con đường độc lập: (a) qua form Save trên trang Add — File name nhập
  tay, `FileId` luôn `null`; (b) qua khu vực **Upload** ở Screen1 (Update 6/7, FR-024 đến FR-033) —
  mỗi file upload thành công lên SharePoint tạo một document với File name = tên file, Valid from =
  ngày hiện tại, Valid to = ngày tối đa, `FileId` = id file trả về từ SharePoint. Bảng
  `eutr_documents` **KHÔNG có cột lưu liên kết PO** — nhưng kể từ Update 7, mỗi document tạo qua
  khu vực Upload có thêm một bản ghi `eutr_references` tương ứng (xem entity **EUTR Reference (liên
  kết Document ↔ Step/PO)** bên dưới) cho phép truy vấn ngược lại Step và PO đã dùng để upload nó.
  **Kể từ Update 10**, `FileId` còn dùng làm khóa để đọc lại nội dung file thật từ SharePoint (xem
  entity **SharePoint File Content (xem trước, Update 10)** bên dưới) khi người dùng nhấn icon View;
  document có `FileId = null` không có nội dung nào để xem trước (icon View bị vô hiệu hóa).
  `eutr_documents` bị xóa qua icon Delete theo từng file ở List PO (FR-044) dùng đúng API xóa đơn đã
  có (FR-011) — không có luồng xóa mới nào được thêm vào entity này.
- **EUTR Master Document (Prefix/Step) — nguồn tham chiếu, KHÔNG thuộc phạm vi CRUD feature này**:
  Bảng `eutr_master_documents` (Id, StepId, Prefix), quản lý bởi feature `002-eutr-masters`. Kể từ
  Update 7, feature `004-eutr-documents` **đọc (read-only)** bảng này để validate tên file khi
  upload: tên file phải bắt đầu bằng một `Prefix` đang tồn tại thì mới được upload (FR-032); `Prefix`
  chỉ duy nhất theo cặp (`StepId`, `Prefix`) — không duy nhất toàn cục, nên một chuỗi Prefix có thể
  gắn với nhiều `StepId` khác nhau; khi đó TẤT CẢ các `StepId` khớp đều được dùng, mỗi `StepId` tạo
  một bản ghi `eutr_references` riêng (xem FR-032/FR-033). Feature này KHÔNG tạo/sửa/xóa bản ghi nào
  trong `eutr_master_documents`.
- **EUTR Reference (liên kết Document ↔ Step/PO, Update 7)**: Bảng `eutr_references` hiện có (Id,
  RefId, DocumentId, RefType, RefValue) — feature này yêu cầu bổ sung **cột mới `StepId`**
  (BIGINT UNSIGNED NULL, tham chiếu `eutr_steps.Id`) vào bảng, tách biệt hoàn toàn với cột `RefId`
  hiện có. Mỗi file upload thành công qua khu vực Upload (Screen1) tạo **một hoặc nhiều** bản ghi —
  **một bản ghi cho mỗi `StepId`** mà tên file khớp Prefix trong `eutr_master_documents` (thường là
  1, nhưng có thể nhiều hơn nếu prefix khớp nhiều Step khác nhau): `DocumentId` trỏ tới cùng một
  document `eutr_documents` vừa tạo cho file đó trên **mọi** bản ghi liên quan, **`StepId`** khác
  nhau giữa các bản ghi (mỗi `StepId` khớp một bản ghi), `RefType` = giá trị "PO" của
  `TAKE_FROM_OPTIONS` (`0`), `RefValue` = mã PO đã chọn — hai giá trị này giống nhau trên mọi bản
  ghi của cùng file (FR-033). Cột `RefId` hiện có **KHÔNG được ghi** bởi luồng này — giữ nguyên mục
  đích thiết kế cũ (trỏ tới `eutr_template_details`), tránh xung đột với ràng buộc khóa ngoại đã có
  trên cột đó. Đây là (những) bản ghi **duy nhất** được feature này **ghi** vào `eutr_references` —
  không có luồng nào khác trong feature ghi vào bảng này. **Kể từ Update 8**, feature này cũng
  **đọc** bảng `eutr_references` (JOIN với `eutr_steps`/`eutr_documents`) để hiển thị Step name/Type
  trên danh sách EUTR documents (User Story 1, FR-034/FR-035) và File name/Step name trên bảng List
  PO ở trang Add (User Story 2, FR-037/FR-038) — đây là các luồng đọc (read-only) bổ sung, không làm
  thay đổi cách bảng này được ghi (vẫn theo đúng FR-033). **Kể từ Update 9**, đây cũng là luồng
  **xóa (delete)** duy nhất của feature này trên bảng `eutr_references` — khi một document
  `eutr_documents` bị xóa (User Story 4, FR-011/FR-012), toàn bộ bản ghi `eutr_references` có
  `DocumentId` trỏ tới document đó bị xóa theo, trong cùng một giao dịch với việc xóa document
  (FR-039/FR-040), không phân biệt số lượng bản ghi hay `RefType`.
- **Type (PO/Manual), danh sách file demo (Screen2)**: Chỉ là trạng thái/nội dung hiển thị trên
  giao diện trang Add ở phạm vi feature này — KHÔNG có entity hay cột dữ liệu tương ứng trên bảng
  `eutr_documents`. Danh sách file demo (File 1-8) trên Screen2 là dữ liệu mẫu tĩnh, hard-coded
  trong giao diện, không phản ánh dữ liệu thật của hệ thống.
- **D365 RSVNEutrPurchOrders (external, read-only reference)**: Danh sách Purchase Order liên quan
  EUTR, lấy từ D365 qua API tham chiếu dùng chung `POST /api/dynamics/reference` với
  `refType = 15` (FR-021). Dùng để hiển thị cột PO name trong bảng List PO trên trang Add (Screen1,
  Type = PO), và (kể từ Update 6) để người dùng chọn PO làm căn cứ xác định thư mục SharePoint đích
  khi nhấn Upload (FR-024, FR-027, FR-028). Không có bảng lưu trữ cục bộ — dữ liệu chỉ đọc, truy
  vấn trực tiếp mỗi lần hiển thị.
- **D365 RSVNEutrSalesOrderPurchases (external, read-only reference, chưa dùng ở giao diện)**: Lấy
  từ D365 qua cùng API tham chiếu dùng chung `POST /api/dynamics/reference` với `refType = 16`
  (FR-022). RefType tồn tại và sẵn sàng sử dụng nhưng KHÔNG có màn hình nào trong feature này gọi
  tới — dự phòng cho một tính năng sau.
- **SharePoint Folder cho PO (Update 6)**: Thư mục con trên SharePoint, nằm dưới thư mục gốc cấu
  hình bởi `SharePointEutrPath`, đặt tên/xác định theo PO đã chọn. Khi nhấn Upload, backend tìm thư
  mục đã tồn tại ứng với PO đó để upload tiếp, hoặc tạo mới thư mục này nếu chưa có (FR-028). Không
  có bảng lưu trữ cục bộ ánh xạ PO ↔ thư mục — việc tìm/tạo thư mục thực hiện trực tiếp trên
  SharePoint mỗi lượt upload.
- **SharePoint File Content (xem trước, Update 10)**: Nội dung file thật (base64) kèm content type,
  file name, đọc trực tiếp từ SharePoint qua `FileId` của một `eutr_documents` mỗi khi người dùng
  nhấn icon View (FR-041/FR-042/FR-043) — tương đương DTO `SharepointFileContent` đã dùng bởi
  `ComplCompliancesController.GetFileByIds`. Đây là dữ liệu **tạm thời, không lưu trữ** ở phía
  backend hay frontend ngoài phạm vi hiển thị popup xem trước — không có bảng hay cache cục bộ nào
  lưu lại nội dung này.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Người dùng tìm thấy và mở màn hình EUTR documents trong vòng 10 giây kể từ khi vào
  hệ thống mà không cần hướng dẫn.
- **SC-002**: Người dùng thêm một document mới hoàn chỉnh (nhập File name + Valid from/to) trong
  dưới 1 phút.
- **SC-003**: 100% thao tác Add thiếu File name bị chặn và hiển thị thông báo lỗi rõ ràng.
- **SC-004**: Mọi thao tác xóa đều yêu cầu xác nhận, không có trường hợp xóa nhầm do một cú nhấp.
- **SC-005**: Người dùng sửa File name hoặc Valid from/to của một document hiện có trong dưới 20
  giây thông qua popup Edit.
- **SC-006** *(revised by Update 10)*: 100% lượt nhấn icon View trên một document có `FileId` mở
  đúng popup xem trước file thật của document đó; 100% document không có `FileId` hiển thị icon
  View ở trạng thái vô hiệu hóa (không thể nhấn) kèm tooltip "No file to view" — không còn là
  placeholder silent no-op như trước Update 10.
- **SC-007**: 100% lượt nhấn Back trên trang Add điều hướng ngay về danh sách mà không tạo bản ghi
  và không cần xác nhận thêm.
- **SC-008**: 100% lượt chuyển đổi Type giữa "PO" và "Upload manual" trên trang Add hiển thị đúng layout
  và dữ liệu mẫu tương ứng ngay lập tức (không cần tải lại trang).
- **SC-009** *(revised by Update 10 — bỏ phần List PO)*: 100% lượt tương tác với khu vực Manual
  upload demo ở Screen2 (kéo-thả, Assign condition, View/Delete, checkbox) không kích hoạt bất kỳ
  lời gọi API, điều hướng hay thay đổi dữ liệu nào, đúng theo phạm vi chỉ giao diện hiện tại. Thao
  tác View/Delete theo từng file trên List PO KHÔNG còn thuộc phạm vi tiêu chí này kể từ Update 10 —
  xem SC-023/SC-024 (đây MUST là các thao tác thật, có gọi API và thay đổi dữ liệu).
- **SC-010**: 100% lượt chọn Type = "PO" tải đúng danh sách PO name thật từ API reference
  (`refType = 15`); khi API trả về rỗng hoặc lỗi, bảng List PO hiển thị đúng trạng thái tương ứng
  (trống/lỗi) thay vì treo giao diện hoặc hiển thị dữ liệu sai.
- **SC-011**: 100% lượt nhập từ khóa vào ô tìm kiếm PO trả về danh sách PO khớp đúng từ API (không
  bị giới hạn trong số PO đã tải trước đó); xóa hết từ khóa khôi phục đúng danh sách mặc định; từ
  khóa không khớp hiển thị đúng trạng thái trống thay vì lỗi hoặc dữ liệu cũ.
- **SC-012** *(Update 6)*: Nút Upload ở Screen1 chỉ khả dụng khi đã chọn đúng một PO; 100% lượt
  nhấn Upload khi chưa chọn PO đều bị chặn (nút vô hiệu hóa), không có trường hợp upload được thực
  hiện mà thiếu PO.
- **SC-013** *(Update 6)*: 100% file hợp lệ (đúng định dạng, ≤ 10MB) trong một lượt chọn được upload
  lên đúng thư mục SharePoint ứng với PO đã chọn và tạo đúng một document tương ứng trong
  `eutr_documents` (File name, Valid from = ngày hiện tại, Valid to = ngày tối đa, FileId đúng với
  SharePoint) trong vòng thời gian hợp lý (không treo giao diện).
- **SC-014** *(Update 6)*: 100% file không hợp lệ (sai định dạng hoặc > 10MB) trong một lượt chọn bị
  loại khỏi upload kèm thông báo lỗi rõ ràng, không tạo document nào cho các file này, và không
  chặn việc upload các file hợp lệ còn lại trong cùng lượt.
- **SC-015** *(Update 6)*: Khi một phần file trong lượt upload thất bại do lỗi mạng/máy chủ, 100%
  file đã upload thành công vẫn có document tương ứng trong `eutr_documents`; không có trường hợp
  toàn bộ lượt bị hủy chỉ vì một file lỗi.
- **SC-016** *(Update 7)*: Khu vực Upload hiển thị đúng 100% theo mẫu `upload.png` (tiêu đề, khung
  kéo-thả, icon, hàng chip) với nội dung định dạng/kích thước **thật** (PDF, DOC/DOCX, XLS/XLSX,
  JPG/PNG, 10MB) — không có sai lệch giữa nội dung hiển thị và ràng buộc thực tế đang áp dụng.
- **SC-017** *(Update 7)*: 100% file có tên KHÔNG khớp bất kỳ `Prefix` nào trong
  `eutr_master_documents` bị chặn upload kèm cảnh báo rõ ràng; không có trường hợp file không khớp
  prefix vẫn được tạo document hoặc bản ghi `eutr_references`.
- **SC-018** *(Update 7)*: 100% file upload thành công (qua đủ validate định dạng/kích thước và
  prefix) có đúng **N** bản ghi `eutr_references` tương ứng, với N = số `StepId` phân biệt khớp
  prefix của tên file (thường N = 1); mọi bản ghi đều có `DocumentId`/`RefType`/`RefValue` chính
  xác và giống nhau, chỉ khác `StepId`; cột `RefId` không bị ghi. Không có trường hợp thiếu bản ghi
  cho một `StepId` đã khớp, và không có kết quả khác nhau giữa các lần upload cùng một file/PO.
- **SC-019** *(Update 8)*: 100% document có ít nhất một bản ghi `eutr_references` liên kết hiển thị
  đúng đầy đủ Step name (JOIN `eutr_steps.Name`) và đúng Type (nhãn `TAKE_FROM_OPTIONS` ứng
  `RefType`) trong danh sách EUTR documents; document không có liên kết nào hiển thị hai cột này ở
  trạng thái trống, không phải lỗi.
- **SC-020** *(Update 8)*: 100% dòng PO trong bảng List PO có ít nhất một document liên kết (qua
  `eutr_references` với `RefType=0`/`RefValue`=mã PO) hiển thị đúng đầy đủ File name và Step name
  tương ứng; dòng PO chưa từng có file nào được upload hiển thị hai cột này ở trạng thái trống.
- **SC-021** *(Update 9)*: 100% document bị xóa (đơn hoặc nhiều) không còn để lại bản ghi
  `eutr_references` nào có `DocumentId` trỏ tới document đó — kiểm tra ngay sau khi xóa, số bản ghi
  `eutr_references` khớp `DocumentId` đã xóa luôn bằng 0, không phân biệt document có 0, 1 hay
  nhiều bản ghi liên kết trước khi xóa.
- **SC-022** *(Update 9)*: Khi bước xóa `eutr_references` của một document thất bại, 100% trường
  hợp document đó vẫn còn tồn tại trong `eutr_documents` (không có document nào bị xóa mà
  `eutr_references` liên quan còn sót lại một phần); trong lượt xóa nhiều, lỗi ở một document không
  làm giảm tỷ lệ xóa thành công của các document khác trong cùng lượt.
- **SC-023** *(Update 10)*: 100% lượt nhấn icon View trên một file cụ thể (danh sách chính hoặc
  List PO) mở đúng nội dung file đó trong popup xem trước, hoặc hiển thị lỗi/cảnh báo thân thiện
  thay vì treo giao diện khi không xem trước được (lỗi mạng, định dạng không hỗ trợ).
- **SC-024** *(Update 10)*: 100% lượt xóa một file trong List PO xóa đúng và chỉ đúng document đó
  khỏi `eutr_documents` và mọi `eutr_references` liên quan (không ảnh hưởng các file khác của cùng
  PO), file đó biến mất đồng thời khỏi List PO và danh sách EUTR documents chính, và file thật trên
  SharePoint vẫn còn tồn tại sau khi xóa.

## Assumptions

- Backend và front-end được xây dựng theo cùng mẫu của **EUTR Masters** (spec `002-eutr-masters`):
  API dạng `api/eutr-documents` với các thao tác GET danh sách, POST `get-all` phân trang/lọc,
  POST tạo, PUT sửa, DELETE xóa, POST `delete-multi`. Riêng chức năng upload file thật (Update 6)
  KHÔNG đi qua API `api/eutr-documents` — được xử lý bởi endpoint mới
  `POST /api/sharepoint/eutr-upload-multi` trong `SharePointController` (xem FR-024 đến FR-030),
  nơi backend vừa upload file lên SharePoint vừa ghi trực tiếp bản ghi mới vào `eutr_documents`.
- Dữ liệu được lưu vào bảng `eutr_documents` (Id, Name, FileId, ValidFrom, ValidTo, CreatedBy,
  CreatedDate, UpdatedBy, UpdatedDate) theo `docs/design/eutr/eutr_db.sql`. Cột `Name` lưu File
  name hiển thị dạng văn bản; MUST migrate kiểu dữ liệu cột này từ BIGINT sang VARCHAR(255) (xem
  Clarifications).
- Xóa là xóa thật (hard delete) — bảng `eutr_documents` không có cờ soft-delete, khác với
  `eutr_templates` (spec `003-eutr-templates`); theo cùng mẫu xóa của `eutr_master_documents`.
- **(Update 9)** Khóa ngoại `eutr_references_documentid_foreign` (`eutr_references.DocumentId` →
  `eutr_documents.Id`, xem `docs/design/eutr/eutr_db.sql`) hiện KHÔNG có `ON DELETE CASCADE` — vì
  vậy việc dọn `eutr_references` khi xóa document (FR-039/FR-040) MUST được xử lý ở tầng ứng dụng
  (application-level, ví dụ xóa `eutr_references` trước rồi xóa `eutr_documents` trong cùng một
  transaction), không phụ thuộc vào cascade delete của database. Feature này KHÔNG yêu cầu đổi
  định nghĩa khóa ngoại trong `eutr_db.sql`.
- Cột Conditions trên grid (tham chiếu tới `eutr_template_details` qua cột `TakeFrom`) KHÔNG được
  nạp dữ liệu trong feature này — không có nguồn dữ liệu nào được yêu cầu bổ sung cho cột này; việc
  liên kết dữ liệu này (nếu cần) thuộc phạm vi một feature khác trong tương lai. **Kể từ Update 8**,
  cột Step name và Type KHÔNG còn thuộc quy tắc "luôn để trống" này — chúng được nạp dữ liệu thật từ
  `eutr_references`/`eutr_steps` (xem FR-034/FR-035).
- Nút toolbar cho hành động thêm mới được đặt tên **"Add"** (đổi từ "Upload" trong thiết kế gốc)
  để khớp đúng với hành vi hiện tại — chỉ nhập thông tin, không có upload file thật. Nút này điều
  hướng sang trang riêng `eutr/documents/add` (không phải popup), khác với Edit (mở popup).
- Trang Add (`eutr/documents/add`) có các trường nhập thông tin: File name (văn bản), Valid from,
  Valid to, cùng nút Save và nút Back (quay lại danh sách, không lưu, không cảnh báo xác nhận) —
  các trường/nút này KHÔNG có upload file thật gắn kèm. Ràng buộc định dạng/kích thước file (PDF,
  DOC/DOCX, XLS/XLSX, JPG/PNG, tối đa 10MB) đã thống nhất ở clarify đầu tiên, bị hoãn ở Update 1, và
  **được áp dụng lại kể từ Update 6** cho riêng nút Upload thật ở Screen1 (Type = PO, xem FR-026).
  Nút Upload thật cho Screen2 (Type = Upload manual) vẫn chưa được xây dựng — sẽ bổ sung ở một tính
  năng sau.
- *(Superseded by Update 10)* Icon View trên cột Action từng là placeholder không gắn hành vi xử lý
  nào; kể từ Update 10, icon này mở popup xem trước file thật (khi có `FileId`) hoặc hiển thị vô
  hiệu hóa kèm tooltip "No file to view" (khi không có `FileId`) — xem FR-042.
- **(Update 10)** Front-end tái sử dụng đúng mẫu component/luồng xem trước file đã có ở
  `compliance-client/src/presentation/pages/compliance-detail` — `FilePreviewer.jsx` (render PDF qua
  `<object>`, DOCX qua `docx-preview`, XLSX qua LuckyExcel/SheetJS fallback, ảnh qua `<img>`) và
  `DialogFilePreviewer.jsx` (popup bọc ngoài, kèm nút Download) — KHÔNG xây dựng component xem trước
  mới từ đầu. Đây là chi tiết tham chiếu mẫu giao diện được người dùng chỉ định trực tiếp trong yêu
  cầu (tương tự cách các entity D365/route SharePoint được tham chiếu ở Update 4/6/7), không phải vi
  phạm nguyên tắc spec không chứa chi tiết triển khai.
- **(Update 10)** Endpoint mới `GET /api/eutr-documents/get-file-by-idref` là read-only, chỉ đọc lại
  nội dung file qua `FileId` đã lưu sẵn trên `eutr_documents` — KHÔNG cần thêm cột/bảng dữ liệu mới,
  không cần migration DB.
- **(Update 10)** Việc xóa một file ở List PO (FR-044) chỉ xóa bản ghi trong `eutr_documents`/
  `eutr_references` (dùng lại API xóa đơn hiện có, FR-011) — KHÔNG gọi endpoint xóa file thật trên
  SharePoint (endpoint `POST /api/sharepoint/delete-file` đã tồn tại nhưng KHÔNG được dùng ở luồng
  này); file thật trên SharePoint được giữ lại, chỉ không còn bản ghi nào trong hệ thống trỏ tới nó.
- Người tạo/ngày tạo do hệ thống ghi tự động dựa trên người dùng đăng nhập; người dùng không nhập
  tay các giá trị này.
- Quyền truy cập từng thao tác được định nghĩa theo policy của API theo cùng mẫu EUTR Masters
  (ReadAll, ReadOne, Create, Update, Delete), được tái sử dụng.
- Màn hình tuân theo cùng mẫu trải nghiệm của các màn CRUD hiện có trong hệ thống (đặc biệt là
  EUTR Masters).
- Phần giao diện Type/List PO/Upload manual trên trang Add được xây dựng theo đúng bố cục mô tả
  trong `docs/design/eutr/eutr_documents_overview.md` (Screen1 khi Type = PO, Screen2 khi Type =
  Upload manual), ở phạm vi **chỉ giao diện**, TRỪ cột **PO name** trong List PO (Screen1) kể từ
  Update 4 — cột này lấy dữ liệu thật từ API `RSVNEutrPurchOrders` (xem FR-021). Các phần còn lại
  (cột File name, xử lý upload file thật, toàn bộ Screen2, cột lưu Type trên bảng `eutr_documents`)
  vẫn giữ nguyên phạm vi chỉ giao diện như trước. Chuỗi placeholder "TAKE_FROM_OPTIONS - PO/Manual"
  trong thiết kế gốc **tham chiếu chính xác** tới hằng số `TAKE_FROM_OPTIONS` đã có sẵn trong
  codebase (`compliance-client/src/utils/helpers.js`:
  `[{ value: 0, label: 'PO' }, { value: 1, label: 'Upload manual' }]`, đã dùng cho cột "Take from"
  ở `eutr-templates`) — nhãn hiển thị của 2 lựa chọn Type MUST lấy đúng từ hằng số này ("PO" và
  "Upload manual", không phải "Manual"). Type mặc định chọn "PO" khi mở trang Add (theo đúng thứ
  tự Screen1 xuất hiện trước trong thiết kế) và không được ghi nhớ giữa các lần mở trang.
  Chức năng thật còn lại cho các khu vực này (File name trong List PO, upload file thật, Assign
  condition, lưu Type) sẽ được xây dựng ở một tính năng sau.
- Hai entity D365 mới (`RSVNEutrPurchOrders`, `RSVNEutrSalesOrderPurchases`) MUST có domain model
  tương ứng trong `ComplianceSys.Domain.Dynamics` (theo mẫu `VendorsV3.cs`) và MUST được đăng ký
  trong bảng ánh xạ (`EntityMappings`) của `ComplDynamicsService` với `refType = 15` và
  `refType = 16` tương ứng, để có thể gọi qua endpoint tham chiếu dùng chung sẵn có
  `POST /api/dynamics/reference` (action `ReferenceData` trong `DynController`) — theo đúng cách
  các entity D365 khác (VendorsV3 = refType 14, RSVNCustTableEntities = refType 2, v.v.) đã được
  đăng ký. KHÔNG tạo endpoint GET/POST riêng mới cho 2 entity này. Bảng List PO hiển thị toàn bộ
  PO name trả về từ API reference (không có control phân trang riêng trong bảng ở phạm vi hiện
  tại).
- `refType = 16` (`RSVNEutrSalesOrderPurchases`) được đăng ký hoàn chỉnh ở backend (hoạt động đúng
  theo pattern chung) nhưng KHÔNG có bất kỳ màn hình/luồng nghiệp vụ nào trong feature
  `004-eutr-documents` gọi tới — mục đích, tham số lọc và màn hình sử dụng cụ thể sẽ được xác định ở
  một tính năng sau.
- Ô tìm kiếm PO (Update 5) gọi lại API reference (`refType = 15`) theo từng lượt nhập của người
  dùng; hệ thống MAY áp dụng debounce (trì hoãn một khoảng ngắn trước khi gọi API) để tránh gọi API
  liên tục theo từng phím gõ — chi tiết khoảng thời gian debounce là quyết định triển khai, không
  ảnh hưởng tới hành vi quan sát được (kết quả tìm kiếm vẫn phải khớp đúng từ khóa cuối cùng người
  dùng nhập). Tìm kiếm khớp theo kiểu "chứa" (contains) trên tên/mã PO ở phía server, theo đúng
  cách các ô tìm kiếm tham chiếu khác trong hệ thống đã làm (ví dụ `ReferenceObjectAutocomplete.jsx`)
  — không còn hỗ trợ nhập nhiều từ khóa cách nhau bằng dấu phẩy như bản lọc cục bộ trước Update 5.
  Việc chọn một PO trong danh sách kết quả tìm kiếm hoạt động giống hệt khi chọn từ danh sách mặc
  định (cột File name/Step name nạp theo đúng quy tắc chung ở FR-037/FR-038 — Update 8, Action vẫn
  no-op — không đổi so với Update 4).
- **(Update 6)** Việc chọn PO trước khi Upload là chọn **đúng một** dòng trong List PO (click chọn,
  giống lựa chọn kiểu radio — chọn dòng khác sẽ bỏ chọn dòng trước đó); không hỗ trợ chọn nhiều PO
  cùng lúc cho một lượt Upload. Đây là cách diễn giải trực tiếp yêu cầu "PO sẽ dựa vào User click
  chọn ở list PO" — không có checkbox chọn nhiều trên bảng List PO ở phạm vi feature này.
- **(Update 6)** Giá trị "Valid to = ngày tối đa" dùng sentinel **`9999-12-31`** (giá trị lớn nhất
  hợp lệ cho kiểu cột `DATE` trong MySQL) để biểu thị "không giới hạn hiệu lực" cho các document tạo
  qua nút Upload — không cần thêm cột/flag "no expiry" riêng.
- **(Update 6)** "Mã PO" gửi lên API `eutr-upload-multi` là giá trị định danh của PO đã chọn từ kết
  quả API tham chiếu `refType = 15` (trường `Code`/`Id` trong `ComplDynReferenceResponseDto`, tương
  ứng cột `PurchId` của `RSVNEutrPurchOrders`) — dùng làm tên/định danh thư mục con trên SharePoint
  dưới `SharePointEutrPath` (ví dụ `{SharePointEutrPath}/{PurchId}`), theo đúng tinh thần "PO dùng để
  chọn thư mục cũ hoặc tạo mới trên SharePoint" đã xác nhận. Cấu trúc thư mục con cụ thể (có thêm
  cấp thư mục theo user/timestamp hay không) là chi tiết triển khai, không ảnh hưởng hành vi quan
  sát được (file vẫn được upload và document vẫn được tạo đúng).
- **(Update 6)** Endpoint mới `POST /api/sharepoint/eutr-upload-multi` được thêm vào cùng
  `SharePointController` hiện có (không tạo controller riêng), theo đúng cách tham chiếu của yêu
  cầu ("tham khảo chức năng ... SharepointController.cs, `[HttpPost("upload-multi")]`"). Service mới
  `_eutrUploadService` (interface, ví dụ `IEutrUploadService`) được inject riêng vào controller này,
  độc lập với `_complUploadService` hiện có — không sửa đổi hành vi của `_complUploadService` hay
  endpoint `upload-multi` hiện tại.
- **(Update 6)** Cấu hình `SharePointEutrPath` là một khóa cấu hình mới (tương tự
  `SharePointCompPath` hiện có), cần được bổ sung vào cấu hình ứng dụng (appsettings) trước khi
  endpoint `eutr-upload-multi` hoạt động; giá trị cụ thể của đường dẫn này không thuộc phạm vi spec.
- **(Update 6)** Vì bảng `eutr_documents` không lưu liên kết PO trực tiếp, danh sách document tạo
  qua nút Upload có thể xem lại qua danh sách chung "EUTR documents" (User Story 1) bằng File
  name/Valid from/Valid to/Created date. **(Update 7)** Việc "xem document theo Step/PO" thực hiện
  gián tiếp qua bảng `eutr_references` (JOIN `DocumentId`). **(Update 8 — thay thế quyết định
  trước)** Feature này giờ CÓ xây dựng 2 luồng đọc cụ thể dùng chính liên kết `eutr_references` này:
  (a) Step name/Type trên danh sách EUTR documents (JOIN theo `DocumentId`, FR-034/FR-035), và (b)
  File name/Step name trên bảng List PO ở trang Add (JOIN theo `RefType=0`/`RefValue`=mã PO,
  FR-037/FR-038). Feature vẫn KHÔNG xây dựng một màn hình/API "lọc xem tất cả document theo PO X"
  độc lập nào khác ngoài 2 luồng hiển thị này.
- **(Update 7)** Hình `upload.png` là tài liệu tham khảo **giao diện** (bố cục, icon, wording chung)
  cho khu vực Upload — không phải đặc tả ràng buộc nghiệp vụ. Số liệu định dạng/kích thước hiển thị
  trong hình ("PDF, DOCX, XLSX — max 50 MB per file") KHÔNG được áp dụng; ràng buộc thật vẫn là
  PDF/DOC/DOCX/XLS/XLSX/JPG/PNG, tối đa 10MB/file đã chốt ở Update 6 (xác nhận qua clarify Update 7).
- **(Update 7)** Quy tắc "tên file có prefix hợp lệ" được diễn giải là **"tên file bắt đầu bằng
  (StartsWith) chuỗi Prefix, không phân biệt hoa/thường"** — đây là cách diễn giải hợp lý nhất của
  từ "prefix" (tiền tố) khi không có mô tả quy ước đặt tên file nào khác trong tài liệu
  `002-eutr-masters` hiện có (nghiên cứu xác nhận cột `Prefix` ở đó chỉ là một giá trị cấu hình gắn
  với Step, chưa từng được mô tả gắn với quy ước đặt tên file thật trước Update 7). Việc so khớp
  không yêu cầu file có phần mở rộng nằm ngay sau prefix hay có ký tự phân tách cụ thể (vd. dấu `_`
  hay `-`) — chỉ cần chuỗi ký tự đầu tên file (không tính đường dẫn) trùng khớp chuỗi Prefix.
- **(Update 7 — sửa lại lần 2)** Vì `Prefix` trong `eutr_master_documents` chỉ duy nhất theo cặp
  (`StepId`, `Prefix`) — không duy nhất toàn cục — nên khi tên file khớp Prefix của nhiều bản ghi
  (nhiều `StepId` khác nhau, hoặc nhiều Prefix khác nhau đều là tiền tố hợp lệ của cùng tên file),
  hệ thống **KHÔNG** chỉ chọn một bản ghi duy nhất (khác quyết định ban đầu — "chọn `Id` nhỏ nhất")
  — thay vào đó, **ghi một bản ghi `eutr_references` cho MỖI `StepId` khớp**, tất cả cùng chung
  `DocumentId` của document vừa tạo cho file đó (xem FR-032/FR-033, Key Entity `EUTR Reference`).
  Hệ thống vẫn KHÔNG chặn upload trong trường hợp khớp nhiều bản ghi — chỉ chặn khi hoàn toàn không
  có bản ghi `eutr_master_documents` nào khớp prefix.
- **(Update 7 — sửa lại)** Bảng `eutr_references` hiện có ràng buộc khóa ngoại
  `eutr_references_refid_foreign` trỏ `RefId` tới `eutr_template_details(Id)` (theo
  `docs/design/eutr/eutr_db.sql`), vốn xung đột nếu ghi thẳng `StepId` vào cột `RefId` này (như bản
  nháp Update 7 ban đầu). Quyết định cuối cùng: **KHÔNG ghi vào cột `RefId` hiện có** — thay vào đó,
  bảng `eutr_references` MUST được bổ sung **một cột mới `StepId`** (BIGINT UNSIGNED NULL, khuyến
  nghị thêm khóa ngoại riêng trỏ tới `eutr_steps(Id)`) để lưu giá trị này, hoàn toàn tách biệt với
  cột `RefId` sẵn có. Cách này tránh xung đột với ràng buộc khóa ngoại hiện tại của `RefId` mà không
  cần nới lỏng/xóa ràng buộc đó — `RefId`/`eutr_template_details` tiếp tục giữ nguyên vai trò thiết
  kế cũ, không bị ảnh hưởng bởi feature này. Migration cụ thể (thêm cột `StepId`, có FK hay không)
  là **quyết định kỹ thuật** sẽ được ghi chi tiết trong `research.md`/`data-model.md` ở bước lập kế
  hoạch (`/speckit-plan`), không phải quyết định nghiệp vụ nên không đưa vào clarify của spec này.
- **(Update 7)** `RefType = 0` ("PO") lấy từ hằng số `TAKE_FROM_OPTIONS` đã dùng xuyên suốt feature
  này (`[{ value: 0, label: 'PO' }, { value: 1, label: 'Upload manual' }]`, xem Update 3) — vì khu
  vực Upload thật (Update 6/7) chỉ tồn tại ở Screen1 (Type = PO), giá trị `RefType` ghi vào
  `eutr_references` luôn là `0`, không có nhánh nào ghi `RefType = 1` trong phạm vi feature này.
- **(Update 7)** "Kéo-thả file thật" bổ sung cho khu vực Upload chỉ áp dụng cho **Screen1** (Type =
  PO) — khu vực "Drag and drop files to upload" ở Screen2 (Type = Upload manual) vẫn là silent no-op
  không đổi (ngoài phạm vi Update 7, xem FR-006/FR-018/FR-019).
- **(Update 8)** Việc tra cứu Step name/Type (danh sách) và File name/Step name (List PO) không đòi
  hỏi migration DB mới — toàn bộ dữ liệu cần thiết (`DocumentId`, `StepId`, `RefType`, `RefValue`
  trên `eutr_references`; `Name` trên `eutr_steps`/`eutr_documents`) đã tồn tại từ Update 7. Cột Step
  name/Type/File name khi hiển thị nhiều giá trị được coi là **trường tính toán (computed/derived)**
  — không có yêu cầu hỗ trợ sort/filter trực tiếp trên các cột này ở phạm vi feature này (giống cách
  các cột "Step name"/"Type"/"Conditions" chưa từng hỗ trợ sort/filter trước Update 8).
- **(Update 8)** Cách hiển thị nhiều giá trị trong một cell (Step name ở danh sách; File name/Step
  name ở List PO) áp dụng đúng mẫu đã có sẵn trong hệ thống ở cột "Country Codes" (màn Country
  Groups, `useCountryGroupColumns.jsx`): hiển thị một số giá trị đầu dưới dạng chip, phần còn lại gộp
  vào chip "+N more" kèm tooltip liệt kê đầy đủ. Số lượng chip hiển thị trực tiếp (`PREVIEW_LIMIT`)
  là chi tiết triển khai, không ảnh hưởng hành vi quan sát được (dữ liệu đầy đủ luôn xem được qua
  tooltip).
- **(Update 8)** Vì mọi bản ghi `eutr_references` của cùng một `DocumentId` luôn được ghi trong cùng
  một transaction với cùng `RefType` (FR-033/Update 7), cột Type trên danh sách EUTR documents luôn
  hiển thị đúng **một** nhãn duy nhất cho mỗi document — không có trường hợp một document hiển thị
  nhiều Type khác nhau trong phạm vi dữ liệu hợp lệ của hệ thống hiện tại.
