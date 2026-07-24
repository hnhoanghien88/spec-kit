# Feature Specification: EUTR Documents Management

**Feature Branch**: `004-eutr-documents`

**Created**: 2026-07-07

**Status**: Draft

**Input**: User description: "chức năng mới eutr-documents tổng quan theo Eutr\docs\design\eutr\eutr_documents_overview.md"

## Clarifications

### Sessions 2026-07-07 → 2026-07-23 (Updates 1-18) — tóm tắt lịch sử

Feature này đã trải qua nhiều vòng cập nhật: từ một trang Add riêng (`eutr/documents/add`) với
form nhập tay File name/Valid from/Valid to, qua giao diện Screen1 (Type = "PO", bảng List PO +
nút Upload) và Screen2 (Type = "Upload manual", bảng file "chưa gán" + popup "Assign condition"
để gán Step/Conditions type/value vào `eutr_reference_details`), tới việc hợp nhất toàn bộ hành
động **Add** vào một **popup duy nhất** (Update 15-18: dropdown Type từ `eutr_reference_types`,
combobox Step, ô Value dạng chip, nút Upload). Các quyết định kỹ thuật nền tảng từ giai đoạn này —
cột `StepId` mới trên `eutr_references`, validate prefix theo `eutr_master_documents` khi Type =
"PO", D365 `refType = 15` (`RSVNEutrPurchOrders`)/`refType = 16` (`RSVNEutrSalesOrderPurchases`)/
`refType = 14` (`VendorsV3`), quy tắc đặt thư mục SharePoint theo Type, migrate cột `Name` sang
VARCHAR(255) — vẫn còn hiệu lực và được kế thừa nguyên vẹn ở bản cập nhật này.

### Session 2026-07-23 (Update 19) — Hợp nhất hoàn toàn Add/Edit vào một popup; đơn giản hóa cột Conditions

- Change: Toàn bộ luồng **Add cũ** (trang riêng `eutr/documents/add`, Screen1/List PO, Screen2,
  popup "Assign condition") và **Edit cũ** (popup đơn giản File name/Valid from/Valid to có thể
  kèm Step cho Type = "PO"; mở lại popup Assign condition ở chế độ sửa cho Type = "Upload manual")
  bị **loại bỏ hoàn toàn** khỏi phạm vi feature. Từ nay, **Add** và **Edit** MUST dùng chung đúng
  một popup ("Add EUTR documents" khi tạo mới, "Edit EUTR document" khi sửa) — không còn màn hình/
  popup nào khác cho hai hành động này.
- Change: Cột **Conditions** trên danh sách chính KHÔNG còn tra cứu `eutr_reference_details`/
  `ConditionType` — thay vào đó, MUST hiển thị trực tiếp mọi giá trị `RefValue` (khác null) của các
  bản ghi `eutr_references` thuộc document đó, mỗi giá trị là một chip. Điều này áp dụng cho **mọi**
  Type (kể cả Type = "PO", nơi trước đây cột này luôn trống) — không còn phân biệt theo Type.
- Change: Popup Add MUST bổ sung hai trường mới **Valid from** (mặc định = ngày hiện tại) và
  **Valid to** (mặc định = ngày tối đa `9999-12-31`), cả hai là ô chọn ngày cho phép người dùng sửa
  trước khi nhấn Upload; giá trị hiển thị tại thời điểm Upload được dùng làm Valid from/Valid to
  cho mọi document tạo ra từ lượt Upload đó.
- Change: Nhấn **Edit** MUST mở lại đúng popup Add nói trên ở **chế độ sửa**, nạp sẵn Type/Step/
  (các) chip Value/Valid from/Valid to hiện có của document đó — nhưng **Type MUST bị khóa** (không
  đổi được) và **(các) chip Value MUST ở dạng chỉ đọc** (không thêm/xóa/sửa được); người dùng CHỈ
  được phép đổi **Step** và **Valid from/Valid to**. Popup chế độ sửa không có control Upload/chọn
  file — thay bằng nút **Save**.
- Q: Cột `eutr_reference_details` (dùng bởi popup Assign condition cũ) có bị xóa/migrate dữ liệu
  không? → A: **Không** — bảng này được giữ nguyên trong schema (dữ liệu cũ không bị xóa), nhưng
  feature `004-eutr-documents` từ nay KHÔNG còn đọc/ghi bảng này ở bất kỳ luồng nào; document Type =
  "Upload manual" được tạo qua popup Assign condition cũ nay hiển thị cột Conditions dựa theo
  `RefValue` của `eutr_references` (thường là `null` cho luồng cũ đó) — có thể hiển thị trống, đây
  là hệ quả đã biết của việc đơn giản hóa nguồn dữ liệu, không phải lỗi.
- Q: Với document sửa qua Edit có nhiều bản ghi `eutr_references` (Type = "PO" khớp nhiều Step qua
  prefix, xem Update 7/17), Save chỉ chọn một Step duy nhất — áp dụng Step mới đó thế nào cho các bản
  ghi còn lại? → A: **Cập nhật trực tiếp `StepId` của MỌI bản ghi `eutr_references` hiện có của
  document đó** thành Step mới đã chọn (giữ nguyên `RefValue`/`RefType`/số lượng bản ghi của mỗi
  dòng) — không xóa/tạo lại bản ghi nào, áp dụng đồng nhất cho mọi Type (không còn cơ chế "thay thế
  bằng đúng một bản ghi" riêng cho Type = "PO" như Update 12/13).
- Q: Document không có bản ghi `eutr_references` nào (dữ liệu cũ từ trước Update 15, Type trống) thì
  Edit hiển thị thế nào? → A: Popup Edit hiển thị Type/chip Value ở trạng thái trống, **ẩn** trường
  Step (không có Type để xác định Step thuộc ngữ cảnh nào) — chỉ Valid from/Valid to khả dụng để sửa.

### Session 2026-07-24 (Update 20) — Lọc Step theo Assign Steps của Type; mặc định chọn 1 dòng

- Input: "cập nhật 004-eutr-documents, màn hình Add/Edit document, chỗ hiển thị danh sách Step với
  type không phải PO. Chỉ hiển thị những step có add trong bảng eutr_reference_type_details theo type
  user đã chọn, và value step set mặc định 1 dòng trong danh sách".
- Change: Với Type khác "PO" (combobox Step đang hiển thị, theo FR-010), danh sách Step nạp vào
  combobox MUST chỉ gồm các Step đã được gán (tính năng **Assign Steps**, feature
  `006-eutr-reference-types`) cho Type đang chọn — tức Step có ít nhất một bản ghi trong
  `eutr_reference_type_details` với `TypeId` = `Id` của Type đó (JOIN `StepId` → `eutr_steps.Name` làm
  nhãn hiển thị). Step KHÔNG có bản ghi gán cho Type đang chọn MUST không xuất hiện trong danh sách,
  dù vẫn tồn tại trong `eutr_steps`.
- Change: Ngay sau khi danh sách Step đã lọc theo Type được tải, combobox Step (ở popup Add) MUST tự
  động chọn sẵn dòng đầu tiên trong danh sách đó làm giá trị mặc định (thay vì để trống) — người dùng
  vẫn có thể đổi sang Step khác nếu danh sách có nhiều hơn 1 dòng.
- Change: Đổi Type sang một Type khác MUST tải lại danh sách Step lọc theo Type mới và áp dụng lại
  việc mặc định chọn dòng đầu tiên của danh sách mới.
- Q: Danh sách Step lọc theo Type rỗng (Type đang chọn chưa được gán Step nào ở màn Assign Steps) thì
  popup Add xử lý thế nào? → A: Combobox Step hiển thị trống, không có mặc định để chọn; nút Upload
  tiếp tục vô hiệu hóa (Step vẫn bắt buộc với Type khác "PO" theo FR-017) cho tới khi Type đó được gán
  ít nhất 1 Step ở màn Assign Steps (`006-eutr-reference-types`) — đây không phải lỗi hệ thống.
- Q: Áp dụng quy tắc lọc này thế nào ở popup Edit (Step vẫn khả dụng để sửa theo FR-029, Type bị khóa
  theo FR-027)? → A: Combobox Step ở Edit cũng lọc theo Type hiện tại của document (không đổi vì Type
  bị khóa), cùng nguồn `eutr_reference_type_details`. Giá trị Step hiện tại của document (xác định
  theo FR-032) MUST luôn hiển thị làm giá trị đã chọn nếu Step đó nằm trong danh sách đã lọc; nếu Step
  hiện tại KHÔNG còn nằm trong danh sách đã lọc (ví dụ đã bị gỡ khỏi Assign Steps sau khi document
  được tạo), popup MUST vẫn hiển thị đúng Step hiện tại đó như một lựa chọn hợp lệ (không tự động đổi
  sang mặc định khác, tránh mất dữ liệu hiện có của document).
- Q: Type = "PO" thì có bị ảnh hưởng không? → A: Không — combobox Step tiếp tục ẩn hoàn toàn khi Type
  = "PO" (FR-010 không đổi); quy tắc lọc/mặc định ở Update này chỉ áp dụng khi combobox Step đang
  hiển thị (Type khác "PO").

### Session 2026-07-24 (Update 21) — Thêm search box lọc danh sách theo Type/Step name/Conditions

- Input: "cập nhật 004-eutr-documents thêm box search ở màn hình index gồm các thông tin [Type]
  [Conditions] [step name] [Search]. User có thể chọn Type, step name, nhập condition, rồi bấm
  search ra dữ liệu cần tìm".
- Change: Màn hình danh sách chính (User Story 1) bổ sung một **search box** phía trên bảng, gồm ba
  control lọc và một nút:
  - **Type**: dropdown, dữ liệu từ toàn bộ `eutr_reference_types` (cùng nguồn với dropdown Type ở
    popup Add), có tùy chọn trống ("All") để bỏ qua điều kiện này.
  - **Step name**: dropdown, dữ liệu từ toàn bộ `eutr_steps` (KHÔNG lọc theo Type đang chọn trong
    cùng search box — khác với combobox Step trong popup Add/Edit ở Update 20, vốn lọc theo Assign
    Steps), có tùy chọn trống ("All").
  - **Conditions**: ô nhập tự do (text), khớp kiểu "chứa" (contains, không phân biệt hoa/thường) với
    `RefValue` của các bản ghi `eutr_references` thuộc document đó.
  - **Search**: nút bấm, áp dụng đồng thời mọi điều kiện đã chọn/nhập tại thời điểm bấm lên bảng
    chính (kết hợp AND), tải lại danh sách từ trang 1.
- Change: Một document được coi là khớp điều kiện lọc khi: (a) nếu Type được chọn — document có ít
  nhất một bản ghi `eutr_references` với `RefType` = Type đó; (b) nếu Step name được chọn — document
  có ít nhất một bản ghi `eutr_references` với `StepId` = Step đó; (c) nếu Conditions có giá trị —
  document có ít nhất một bản ghi `eutr_references` với `RefValue` chứa chuỗi đã nhập. Cả ba điều
  kiện (khi được cung cấp) phải cùng đúng trên **document** đó — không bắt buộc cùng một bản ghi
  `eutr_references`.
- Change: Không chọn/nhập bất kỳ điều kiện nào rồi bấm Search MUST hiển thị lại toàn bộ danh sách
  gốc, giống trạng thái ban đầu.
- Q: Ba điều kiện lọc có bắt buộc phải khớp trên CÙNG một bản ghi `eutr_references`, hay có thể khớp
  trên các bản ghi khác nhau của cùng document? → A: **Không bắt buộc cùng bản ghi** — mỗi điều kiện
  chỉ cần có ít nhất một bản ghi `eutr_references` của document đó thỏa mãn, độc lập với các điều
  kiện còn lại. Lý do: nhất quán với cách cột Step name/Type/Conditions trên bảng đã tổng hợp từ
  nhiều bản ghi (FR-004/FR-005), và yêu cầu gốc không nêu rõ ràng buộc "cùng bản ghi".
- Q: Search có tự động chạy khi người dùng thay đổi giá trị (live search) hay chỉ chạy khi bấm nút
  Search? → A: **Chỉ khi bấm nút Search** — đúng theo mô tả yêu cầu gốc ("bấm search ra dữ liệu"),
  không tự động lọc khi đang gõ/chọn giá trị.
- Q: Dropdown Step name trong search box có lọc theo Type đang chọn trong cùng search box không
  (giống cơ chế Assign Steps ở popup Add/Edit, Update 20)? → A: **Không** — search box là bộ lọc độc
  lập trên dữ liệu đã tồn tại (không phải nhập liệu tạo mới), nên dropdown Step name luôn liệt kê
  toàn bộ `eutr_steps`, không phụ thuộc Type đang chọn trong search box.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Xem danh sách EUTR documents (Priority: P1)

Người dùng vào mục **EUTR > EUTR documents** từ thanh điều hướng và thấy bảng liệt kê các document
EUTR đã thêm vào hệ thống, với các cột File name, Step name, Conditions, Type, Valid from, Valid
to, Created by, Created date và cột Action (Edit, Delete, View). Step name và Type được tra cứu từ
bảng `eutr_references` theo `DocumentId` (Step name JOIN `eutr_steps`, Type JOIN
`eutr_reference_types` theo `RefType`); document chưa có bản ghi `eutr_references` nào hiển thị hai
cột này ở trạng thái trống. Cột **Conditions** hiển thị mọi giá trị `RefValue` (khác null) của các
bản ghi `eutr_references` thuộc document đó, mỗi giá trị một chip — document không có `RefValue` nào
hiển thị cột này ở trạng thái trống. Người dùng có thể chuyển trang khi danh sách dài. Icon **View**
trên cột Action mở popup xem trước file thật (nếu document có `FileId`); document không có `FileId`
hiển thị icon View ở trạng thái vô hiệu hóa kèm tooltip "No file to view".

**Why this priority**: Đây là giá trị cốt lõi — xem danh sách document hiện có là thao tác đầu tiên
người dùng cần trước khi thêm mới, sửa, xóa hay xem chi tiết bất kỳ document nào.

**Independent Test**: Mở màn hình, xác nhận breadcrumb "EUTR > EUTR documents" và bảng hiển thị đúng
File name/Valid from/Valid to/Created by/Created date; với một document có nhiều bản ghi
`eutr_references` mang các `RefValue` khác nhau, xác nhận cột Conditions hiển thị đầy đủ từng giá
trị dưới dạng chip; với document không có bản ghi `eutr_references` nào, xác nhận Step name/
Conditions/Type đều trống; chuyển trang và thấy trang kế tiếp.

**Acceptance Scenarios**:

1. **Given** đang ở mục EUTR, **When** chọn "EUTR documents" ở thanh điều hướng, **Then** thấy
   breadcrumb "EUTR > EUTR documents" và bảng với các cột File name, Step name, Conditions, Type,
   Valid from, Valid to, Created by, Created date, Action.
2. **Given** một document không có bản ghi `eutr_references` nào, **When** bảng hiển thị dòng đó,
   **Then** cột File name/Valid from/Valid to/Created by/Created date hiển thị đúng dữ liệu đã lưu;
   cột Step name, Conditions, Type hiển thị trống.
3. **Given** một document có một bản ghi `eutr_references` (StepId, RefType, RefValue = "PO00001"),
   **When** bảng hiển thị dòng đó, **Then** Step name hiển thị đúng tên Step, Type hiển thị đúng
   `Name` của `eutr_reference_types` khớp `RefType`, và Conditions hiển thị đúng một chip
   "PO00001".
4. **Given** một document có nhiều bản ghi `eutr_references` với các `RefValue` phân biệt (ví dụ
   "PO00001", "PO00002"), **When** bảng hiển thị dòng đó, **Then** cột Conditions hiển thị đầy đủ
   từng giá trị dưới dạng chip riêng (dùng mẫu hiển thị nhiều giá trị "+N more" khi vượt quá số
   lượng hiển thị trực tiếp, giống cột Step name).
5. **Given** một document có bản ghi `eutr_references` nhưng `RefValue` là null (ví dụ tạo qua popup
   Assign condition cũ, xem Update 19), **When** bảng hiển thị dòng đó, **Then** cột Conditions hiển
   thị trống (không lỗi) dù Step name/Type vẫn hiển thị đúng.
6. **Given** danh sách vượt quá một trang, **When** chọn số trang khác, **Then** bảng hiển thị các
   bản ghi của trang đó.
7. **Given** danh sách document rỗng, **When** mở màn hình, **Then** bảng hiển thị trạng thái trống
   ("No data") thay vì lỗi.
8. **Given** một document có `FileId`, **When** nhấn icon View, **Then** hệ thống mở popup xem trước
   file (PDF/DOCX/XLSX/ảnh hiển thị trực tiếp, kèm nút Download), lấy dữ liệu qua
   `GET /api/eutr-documents/get-file-by-idref?idRef={FileId}`.
9. **Given** một document KHÔNG có `FileId`, **When** bảng hiển thị dòng đó, **Then** icon View hiển
   thị ở trạng thái vô hiệu hóa kèm tooltip "No file to view" — không thể nhấn.
10. **Given** popup xem trước file đang mở, **When** gọi `get-file-by-idref` thất bại hoặc file có
    định dạng không hỗ trợ xem trước, **Then** popup hiển thị thông báo lỗi/cảnh báo thân thiện thay
    vì treo giao diện, người dùng vẫn có thể đóng popup.

---

### User Story 2 - Thêm document mới qua popup Add (Type/Step/Value/Valid dates/Upload) (Priority: P1)

Người dùng nhấn nút **Add** trên thanh công cụ. Hệ thống mở popup **"Add EUTR documents"** gồm:
dropdown **Type** (dữ liệu từ `eutr_reference_types`), combobox **Step** (dữ liệu từ `eutr_steps`
nhưng đã lọc theo `eutr_reference_type_details` — chỉ hiển thị Step đã được gán, tính năng Assign
Steps, cho Type đang chọn, xem Update 20 — bắt buộc trừ khi Type đã chọn có `Name` = "PO" — khi đó
control này ẩn hẳn; khi hiển thị, combobox này mặc định chọn sẵn dòng đầu tiên của danh sách đã
lọc), ô **Value** (combobox
vừa gõ tự do vừa hiển thị gợi ý tùy Type, hỗ trợ dán nhiều giá trị), vùng chip hiển thị các giá trị
đã chọn, hai trường ngày mới **Valid from** (mặc định ngày hiện tại) và **Valid to** (mặc định ngày
tối đa `9999-12-31`) — cả hai đều có thể chỉnh sửa trước khi Upload, và nút **Upload**.

Chọn Type = "PO", "Invoice", hoặc "Delivery note" hiển thị gợi ý PO (API `refType = 15`); chọn Type
= "Vendor" hiển thị gợi ý Vendor (API `refType = 14`); Type khác không có gợi ý, ô Value là nhập tự
do. Với Type = "PO" hoặc "Vendor", vùng chọn chỉ nhận tối đa 1 chip; các Type khác nhận nhiều chip.
Đổi Type xóa toàn bộ chip hiện có.

Nút Upload chỉ khả dụng khi đã chọn Type, có ít nhất 1 chip, và — với Type khác "PO" — đã chọn Step.
Nhấn Upload mở hộp thoại chọn nhiều file; mỗi file hợp lệ (PDF/DOC/DOCX/XLS/XLSX/JPG/PNG, tối đa
10MB) được tải lên thư mục SharePoint xác định theo Type (PO/Vendor → thư mục theo chip đã chọn;
Invoice/Delivery note/General agreement → thư mục cố định theo tên Type; Type khác → thư mục cố
định theo `Name` của Type). Khi Type = "PO", tên file MUST khớp một `Prefix` trong
`eutr_master_documents` — file không khớp bị loại kèm cảnh báo.

Với mỗi file upload thành công, hệ thống tạo một document mới trong `eutr_documents` (File name =
tên file gốc, Valid from = giá trị đang hiển thị ở popup, Valid to = giá trị đang hiển thị ở popup,
FileId = id từ SharePoint). Với Type khác "PO", hệ thống ghi một bản ghi `eutr_references` cho mỗi
chip (DocumentId, StepId đã chọn, RefType = `Id` của Type đã chọn, RefValue = giá trị chip). Với
Type = "PO", hệ thống ghi một bản ghi `eutr_references` cho **mỗi** `StepId` khớp Prefix của file đó
(RefType = `Id` của Type "PO" đang chọn — gửi kèm dưới dạng `TypeId`, RefValue = giá trị chip PO đã
chọn). Sau khi lượt Upload hoàn tất (toàn bộ hoặc một phần thành công), popup MUST tự đóng lại.

**Why this priority**: Đây là cách duy nhất để tạo document mới — là nghiệp vụ chính của màn hình.

**Independent Test**: Nhấn Add, xác nhận popup "Add EUTR documents" mở ra với Valid from = hôm nay
và Valid to = ngày tối đa hiển thị sẵn (có thể sửa); chọn Type = "PO", xác nhận combobox Step không
hiển thị; gõ/chọn một PO hợp lệ, xác nhận chip xuất hiện, ô Value trở về trống; đổi Valid from/Valid
to sang giá trị khác; nhấn Upload, chọn file có tên khớp prefix hợp lệ; xác nhận document mới xuất
hiện trên danh sách với đúng Valid from/Valid to đã chỉnh sửa (không phải mặc định) và đúng
`eutr_references` (StepId khớp prefix, RefValue = mã PO); riêng biệt xác nhận không sửa Valid
from/Valid to thì document tạo ra có Valid from = hôm nay, Valid to = ngày tối đa.

**Acceptance Scenarios**:

1. **Given** đang ở danh sách EUTR documents, **When** nhấn nút Add trên toolbar, **Then** hệ thống
   mở popup "Add EUTR documents".
2. **Given** popup Add vừa mở, **Then** trường Valid from hiển thị sẵn giá trị = ngày hiện tại và
   Valid to hiển thị sẵn giá trị = ngày tối đa (`9999-12-31`), cả hai đều là ô chọn ngày cho phép
   sửa.
3. **Given** popup Add đang mở, **When** người dùng đổi Valid from và/hoặc Valid to sang giá trị
   khác trước khi nhấn Upload, **Then** giá trị mới được giữ lại cho tới khi Upload hoặc đóng popup.
4. **Given** popup Add đang mở, **When** chọn Type có `Name` = "PO", "Invoice", hoặc "Delivery
   note", **Then** ô Value hiển thị danh sách gợi ý tải từ `POST /api/dynamics/reference`
   (`refType = 15`).
5. **Given** popup Add đang mở, **When** chọn Type có `Name` = "Vendor", **Then** ô Value hiển thị
   danh sách gợi ý tải từ `POST /api/dynamics/reference` (`refType = 14`).
6. **Given** popup Add đang mở, **When** chọn Type khác 4 tên trên, **Then** ô Value là ô nhập tự
   do, không có danh sách gợi ý.
7. **Given** Type đã chọn có `Name` = "PO" hoặc "Vendor" và vùng chọn đã có 1 chip, **When** người
   dùng cố thêm giá trị khác, **Then** hệ thống chặn thao tác, yêu cầu xóa chip hiện có trước.
8. **Given** vùng chọn đang có sẵn chip, **When** đổi giá trị dropdown Type, **Then** toàn bộ chip
   hiện có bị xóa.
9. **Given** popup Add chưa chọn đủ Type/Step (khi cần)/ít nhất 1 chip, **Then** nút Upload ở trạng
   thái vô hiệu hóa.
10. **Given** đã chọn Type = "PO" với 1 chip mã PO (không cần Step), **When** upload file có tên
    khớp Prefix của một hoặc nhiều `StepId` trong `eutr_master_documents`, **Then** hệ thống tạo
    document mới và ghi một bản ghi `eutr_references` cho mỗi `StepId` khớp (RefValue = mã PO đã
    chọn, RefType = `Id` của Type "PO").
11. **Given** đã chọn Type = "PO" và file upload có tên KHÔNG khớp bất kỳ Prefix nào, **Then** file
    đó bị loại khỏi lượt upload kèm cảnh báo rõ ràng, không tạo document/`eutr_references` cho file
    này; các file khác trong cùng lượt không bị ảnh hưởng.
12. **Given** đã chọn Type khác "PO" (ví dụ "Invoice") với Step đã chọn và ít nhất 1 chip, **When**
    upload file hợp lệ, **Then** file được tải lên thư mục cố định tương ứng, tạo document mới, và
    ghi một bản ghi `eutr_references` cho mỗi chip đang có (RefType = `Id` của Type đã chọn).
13. **Given** một file upload thành công, **Then** document mới tạo ra có Valid from/Valid to đúng
    bằng giá trị đang hiển thị ở popup tại thời điểm nhấn Upload (mặc định hoặc đã chỉnh sửa).
14. **Given** một hoặc nhiều file trong lượt chọn sai định dạng hoặc vượt quá 10MB, **Then** hệ
    thống loại các file đó kèm thông báo lỗi rõ ràng, vẫn upload và tạo document cho các file hợp lệ
    còn lại trong cùng lượt.
15. **Given** một lượt Upload vừa hoàn tất (toàn bộ hoặc một phần thành công), **Then** popup MUST
    tự đóng lại ngay lập tức.
16. **Given** một document vừa tạo qua popup Add, **When** quay lại danh sách EUTR documents, **Then**
    document đó hiển thị đúng File name, Valid from, Valid to, Created by/date, Step name, Type, và
    Conditions (mỗi RefValue vừa ghi hiển thị dưới dạng chip).
17. **Given** popup Add đang mở và Type đã chọn khác "PO", **When** combobox Step tải dữ liệu, **Then**
    danh sách chỉ gồm các Step có bản ghi gán (Assign Steps) cho Type đó trong
    `eutr_reference_type_details` — Step chưa được gán cho Type này (dù tồn tại trong `eutr_steps`)
    không xuất hiện.
18. **Given** danh sách Step đã lọc theo Type có ít nhất 1 dòng, **When** combobox Step tải xong,
    **Then** dòng đầu tiên trong danh sách được chọn sẵn làm giá trị mặc định, không để trống.
19. **Given** popup Add đang mở với Type A đã chọn Step mặc định, **When** người dùng đổi sang Type B,
    **Then** combobox Step tải lại danh sách lọc theo Type B và chọn sẵn dòng đầu tiên của danh sách
    mới.
20. **Given** Type đã chọn chưa được gán Step nào ở màn Assign Steps (danh sách lọc rỗng), **Then**
    combobox Step hiển thị trống và nút Upload vẫn vô hiệu hóa cho tới khi có Step để chọn.

---

### Session 2026-07-24 (Update 22) — Cho phép thêm/xóa chip Value trong Edit với Type khác "PO"

- Input: "cập nhật 004-eutr-documents chức năng Edit, cho chỉnh thêm xóa condition (value) với type
  không phải là PO".
- Change: Ở popup Edit (User Story 3), khi Type hiện tại của document (đã khóa) **khác "PO"**, vùng
  chip Value KHÔNG còn ở dạng chỉ đọc hoàn toàn — MUST hiển thị lại ô Value (combobox, cùng nguồn gợi
  ý theo Type như popup Add, FR-011/FR-012) để thêm chip mới, và mỗi chip hiện có MUST có nút xóa.
  Với Type = **"PO"**, vùng chip Value MUST tiếp tục ở dạng chỉ đọc như trước (không đổi, kế thừa
  FR-028).
- Change: Quy tắc giới hạn số chip theo Type (FR-013) tiếp tục áp dụng trong Edit: Type = "Vendor"
  vẫn giới hạn tối đa 1 chip — thêm chip mới khi đã có 1 chip MUST bị chặn kèm thông báo (giống Add),
  phải xóa chip hiện có trước khi thêm chip khác; các Type khác (không phải PO/Vendor) cho phép nhiều
  chip.
- Change: Nhấn Save ở chế độ sửa với Type khác "PO" MUST đồng bộ bản ghi `eutr_references` của
  document theo đúng tập chip đang hiển thị tại thời điểm Save: (a) tạo mới một bản ghi (DocumentId,
  StepId đã chọn, RefType = `Id` của Type hiện tại, RefValue = giá trị chip) cho mỗi chip mới thêm
  (chưa có bản ghi `RefValue` tương ứng trước đó); (b) xóa bản ghi `eutr_references` có `RefValue`
  khớp cho mỗi chip đã bị xóa khỏi vùng chip; (c) cập nhật `StepId` của mọi bản ghi còn lại (không bị
  xóa ở bước b, kể cả bản ghi vừa tạo ở bước a) thành Step đang chọn — kế thừa FR-033. Type = "PO"
  tiếp tục KHÔNG áp dụng đồng bộ này (chỉ cập nhật `StepId`, không thêm/xóa bản ghi nào, như trước).
- Change: Vùng chip Value ở Edit (Type khác "PO") MUST còn lại ít nhất 1 chip tại thời điểm Save — xóa
  hết chip mà không thêm lại chip nào khác MUST chặn Save kèm thông báo lỗi rõ ràng (tương tự yêu cầu
  tối thiểu 1 chip khi Add, FR-017).
- Q: Type = "Vendor" (cũng giới hạn 1 chip theo FR-013) có được thêm/xóa chip trong Edit giống các
  Type khác không, hay vẫn bị khóa như "PO"? → A: **Được** — yêu cầu gốc nói "type không phải là PO",
  nên Vendor thuộc nhóm được phép sửa chip, chỉ vẫn giữ giới hạn tối đa 1 chip (thêm mới phải xóa chip
  cũ trước).
- Q: Chip mới thêm vào Edit dùng nguồn gợi ý/validate giá trị nào? → A: Dùng đúng quy tắc gợi ý theo
  Type đã áp dụng ở popup Add (FR-011/FR-012) — Type "Invoice"/"Delivery note" gợi ý PO (refType=15),
  Type "Vendor" gợi ý Vendor (refType=14) nhưng giới hạn 1 chip, Type khác là nhập tự do; hỗ trợ dán
  nhiều giá trị cùng lúc như Add.
- Q: Thao tác thêm/xóa chip trong Edit có gọi API ngay lập tức hay chỉ áp dụng khi nhấn Save? → A:
  **Chỉ áp dụng khi nhấn Save** — nhất quán với cách Edit hiện tại chỉ ghi thay đổi Step/Valid dates
  khi Save (FR-033), tránh trạng thái nửa vời nếu người dùng đóng popup mà không Save.

---

### User Story 3 - Sửa document qua cùng popup Add, khóa Type (Priority: P2)

Người dùng nhấn **Edit** trên một dòng trong bảng. Hệ thống mở lại **đúng popup Add** (cùng tiêu đề
đổi thành **"Edit EUTR document"**) ở **chế độ sửa**, nạp sẵn: Type hiện tại của document (JOIN
`RefType`), Step hiện tại (nếu document có nhiều bản ghi `eutr_references` với nhiều `StepId` phân
biệt, hiển thị Step ứng với bản ghi có `Id` nhỏ nhất), (các) chip Value hiện có (từ `RefValue` của
các bản ghi `eutr_references`), và Valid from/Valid to hiện tại của document.

Ở chế độ sửa: **Type MUST bị khóa** (dropdown vô hiệu hóa, không đổi được); **Step MUST vẫn khả dụng
để sửa** (dropdown, cùng nguồn dữ liệu đã lọc theo Type với Add — xem Update 20; Step hiện tại của
document luôn được đảm bảo xuất hiện trong danh sách kể cả khi đã bị gỡ khỏi Assign Steps); **Valid
from/Valid to MUST vẫn khả dụng để sửa**. Popup KHÔNG hiển thị control Upload/chọn file — thay bằng
nút **Save**.

Vùng **chip Value** cư xử khác nhau theo Type hiện tại của document (xem Update 22):
- **Type = "PO"**: chip Value MUST tiếp tục ở dạng **chỉ đọc** (không có nút xóa, không có ô Value để
  thêm mới) — không đổi so với hành vi trước Update 22.
- **Type khác "PO"** (bao gồm "Vendor"): chip Value MUST **có thể chỉnh sửa** — hiển thị lại ô Value
  (combobox gợi ý theo Type, cùng quy tắc với Add ở FR-011/FR-012) để thêm chip mới, và mỗi chip hiện
  có MUST có nút xóa. Quy tắc giới hạn số chip theo Type (FR-013) tiếp tục áp dụng — Type = "Vendor"
  giới hạn tối đa 1 chip, các Type khác cho phép nhiều chip. Vùng chip MUST còn lại ít nhất 1 chip tại
  thời điểm Save.

Nhấn Save cập nhật trực tiếp `ValidFrom`/`ValidTo` của document. Với Type = "PO", Save cập nhật
`StepId` của **mọi** bản ghi `eutr_references` hiện có của document đó thành Step mới đã chọn (giữ
nguyên `RefValue`/`RefType`, không thêm/xóa bản ghi nào — như trước Update 22). Với Type khác "PO",
Save đồng bộ bản ghi `eutr_references` theo đúng tập chip đang hiển thị: tạo bản ghi mới cho mỗi chip
mới thêm, xóa bản ghi có `RefValue` khớp cho mỗi chip đã xóa, và cập nhật `StepId` của mọi bản ghi còn
lại (kể cả bản ghi vừa tạo) thành Step đang chọn. Document không có bản ghi `eutr_references` nào
(Type trống) hiển thị Type/chip Value trống, **ẩn** trường Step — chỉ Valid from/Valid to khả dụng để
sửa.

**Why this priority**: Sửa Step, hiệu lực, hoặc điều chỉnh (các) giá trị Condition của document hiện
có là nhu cầu thường gặp nhưng đứng sau xem và thêm mới.

**Independent Test**: (1) Với document Type = "PO" có Step/chip hiện có: nhấn Edit, xác nhận popup
nạp đúng Type (khóa), Step, chip (chỉ đọc, không sửa được); đổi Step và Valid from/to rồi Save; xác
nhận bảng chính cập nhật đúng Step name mới và Valid from/to mới, Conditions/Type không đổi. (2) Với
document Type khác "PO" (ví dụ "Invoice") có chip hiện có: nhấn Edit, xác nhận chip có nút xóa và có ô
Value để thêm mới; xóa một chip, thêm một chip mới, đổi Step, rồi Save; xác nhận bảng chính hiển thị
đúng tập Conditions mới (đã xóa/thêm) và Step name mới. (3) Với document Type trống: nhấn Edit, xác
nhận Type/chip trống, không có trường Step, chỉ sửa được Valid from/to.

**Acceptance Scenarios**:

1. **Given** một document có Type/Step/(các) chip Value hiện có, **When** nhấn Edit, **Then** popup
   "Edit EUTR document" mở ra, nạp đúng Type (dropdown vô hiệu hóa), Step hiện tại, (các) chip Value
   hiện có, Valid from/Valid to hiện tại; KHÔNG có control Upload/chọn file.
2. **Given** popup Edit đang mở, **When** người dùng cố tương tác với dropdown Type, **Then** dropdown
   ở trạng thái vô hiệu hóa, không đổi được giá trị.
3. **Given** popup Edit đang mở với document có Type = "PO", **When** người dùng cố xóa hoặc thêm một
   chip Value, **Then** vùng chip không có control nào để thực hiện thao tác đó (chỉ đọc).
4. **Given** popup Edit đang mở, **When** đổi Step sang một giá trị khác rồi nhấn Save, **Then** hệ
   thống cập nhật `StepId` của mọi bản ghi `eutr_references` hiện có của document đó thành Step mới,
   giữ nguyên `RefValue`/`RefType`/số lượng bản ghi; bảng chính hiển thị đúng Step name mới.
5. **Given** một document có nhiều bản ghi `eutr_references` cùng `DocumentId` nhưng nhiều `StepId`
   phân biệt (ví dụ Type = "PO" khớp nhiều prefix), **When** mở popup Edit, **Then** Step hiển thị
   đúng là Step ứng với bản ghi có `Id` nhỏ nhất trong số đó.
6. **Given** popup Edit đang mở, **When** đổi Valid from và/hoặc Valid to rồi nhấn Save, **Then**
   bảng chính hiển thị đúng giá trị Valid from/Valid to mới.
7. **Given** popup Edit đang mở, **When** nhấn Save mà không đổi gì, **Then** hệ thống lưu lại đúng
   giá trị hiện tại (không lỗi, không thay đổi quan sát được).
8. **Given** popup Edit đang mở, **When** đóng popup mà không nhấn Save, **Then** popup đóng lại và
   KHÔNG có thay đổi nào được lưu.
9. **Given** một document KHÔNG có bản ghi `eutr_references` nào (Type trống), **When** nhấn Edit,
   **Then** popup mở ra với Type/chip Value ở trạng thái trống và trường Step MUST ẩn — chỉ Valid
   from/Valid to khả dụng để sửa.
10. **Given** một document đã bị xóa được truy cập lại qua Edit (ví dụ dữ liệu cũ trên trình duyệt),
    **Then** hệ thống báo not-found rõ ràng thay vì lỗi hệ thống.
11. **Given** popup Edit đang mở, **When** combobox Step tải dữ liệu, **Then** danh sách chỉ gồm Step
    đã gán (Assign Steps) cho Type hiện tại của document (`eutr_reference_type_details` lọc theo
    `TypeId` = Type hiện tại), cùng quy tắc lọc với popup Add.
12. **Given** Step hiện tại của document (nạp sẵn khi mở Edit) đã bị gỡ khỏi Assign Steps của Type đó
    (không còn nằm trong danh sách đã lọc), **When** popup Edit mở, **Then** combobox Step vẫn hiển
    thị đúng Step hiện tại đó như một lựa chọn hợp lệ (không tự động đổi sang Step khác), cho phép
    người dùng giữ nguyên hoặc đổi sang Step khác trong danh sách.
13. **Given** popup Edit đang mở với document có Type khác "PO" (ví dụ "Invoice"), **Then** vùng chip
    Value hiển thị ô Value (combobox gợi ý theo Type, giống Add) và mỗi chip hiện có có nút xóa.
14. **Given** popup Edit đang mở với Type khác "PO", **When** nhấn nút xóa trên một chip hiện có,
    **Then** chip đó biến mất khỏi vùng chip ngay lập tức (chưa gọi API); nếu sau đó nhấn Save, **Then**
    hệ thống xóa bản ghi `eutr_references` có `RefValue` khớp chip đó, giữ nguyên các bản ghi khác.
15. **Given** popup Edit đang mở với Type khác "PO", **When** thêm một giá trị mới vào ô Value (gõ tay
    hoặc chọn gợi ý) rồi nhấn Save, **Then** hệ thống tạo một bản ghi `eutr_references` mới (StepId =
    Step đang chọn, RefType = `Id` của Type hiện tại, RefValue = giá trị mới) mà không ảnh hưởng các
    bản ghi hiện có khác (ngoài việc cập nhật `StepId` chung theo FR-033).
16. **Given** popup Edit đang mở với Type = "Vendor" (giới hạn 1 chip) và đã có sẵn 1 chip, **When**
    người dùng cố thêm một giá trị khác mà chưa xóa chip hiện có, **Then** hệ thống chặn thao tác, yêu
    cầu xóa chip hiện có trước — giống hành vi ở Add (FR-013).
17. **Given** popup Edit đang mở với Type khác "PO", **When** người dùng xóa hết mọi chip mà không thêm
    lại chip nào, **Then** nút Save ở trạng thái vô hiệu hóa hoặc nhấn Save bị chặn kèm thông báo lỗi
    yêu cầu còn lại ít nhất 1 chip.
18. **Given** popup Edit đang mở với Type khác "PO", **When** đóng popup mà không nhấn Save sau khi đã
    thêm/xóa chip trên giao diện, **Then** không có bản ghi `eutr_references` nào bị tạo/xóa trong hệ
    thống — mọi thay đổi trên giao diện bị hủy bỏ.

---

### User Story 4 - Xóa document (Priority: P2)

Người dùng nhấn **Delete** trên một dòng, xác nhận, và document bị loại khỏi danh sách. Hệ thống
cũng hỗ trợ xóa nhiều document cùng lúc. Khi xóa một document, hệ thống MUST xóa kèm toàn bộ bản ghi
`eutr_references` có `DocumentId` trỏ tới document đó, để không còn bản ghi tham chiếu mồ côi. Việc
xóa document và xóa các bản ghi `eutr_references` liên quan được coi là một giao dịch — nếu bước xóa
`eutr_references` thất bại, document đó không bị xóa.

**Why this priority**: Dọn dẹp các document không còn dùng là cần thiết nhưng ít rủi ro nếu triển
khai sau xem, thêm mới và sửa.

**Independent Test**: Tạo một document có ít nhất một bản ghi `eutr_references` liên kết, nhấn
Delete trên dòng đó, xác nhận, và kiểm tra: (a) dòng đó biến mất khỏi bảng, (b) document không còn
tồn tại trong `eutr_documents`, (c) không còn bản ghi nào trong `eutr_references` có `DocumentId` =
Id của document đã xóa.

**Acceptance Scenarios**:

1. **Given** một document tồn tại, **When** nhấn Delete và xác nhận, **Then** bản ghi biến mất khỏi
   bảng.
2. **Given** đã chọn nhiều document, **When** thực hiện xóa nhiều, **Then** tất cả document đã chọn
   biến mất khỏi bảng.
3. **Given** hộp thoại xác nhận xóa hiện ra, **When** người dùng hủy, **Then** không có document nào
   bị xóa.
4. **Given** một document có một hoặc nhiều bản ghi `eutr_references` liên kết, **When** nhấn Delete
   và xác nhận, **Then** document bị xóa khỏi `eutr_documents` VÀ toàn bộ bản ghi `eutr_references`
   tương ứng cũng bị xóa.
5. **Given** đã chọn nhiều document để xóa cùng lúc (một số có `eutr_references`, một số không),
   **When** thực hiện xóa nhiều, **Then** mọi document đã chọn đều bị xóa cùng toàn bộ
   `eutr_references` liên quan (nếu có).
6. **Given** một document có bản ghi `eutr_references` liên kết, **When** bước xóa `eutr_references`
   thất bại, **Then** document đó KHÔNG bị xóa (rollback), hệ thống báo lỗi rõ ràng; lỗi này không
   chặn việc xóa các document khác trong cùng lượt xóa nhiều.

---

### User Story 5 - Xem file thật qua icon View (Priority: P2)

Cột Action trên mỗi dòng hiển thị icon **View** cùng Edit và Delete. Với document có file thật
(`FileId` khác null), nhấn View MUST mở một popup xem trước file (inline preview cho PDF/DOCX/XLSX/
ảnh, kèm nút Download) — tham khảo mẫu giao diện/luồng đã dùng ở
`compliance-client/src/presentation/pages/compliance-detail` (`FilePreviewer.jsx`/
`DialogFilePreviewer.jsx`) và endpoint `ComplCompliancesController.GetFileByIds`
(`[HttpGet("get-file-by-idref")]`). Với document KHÔNG có file thật (`FileId = null`), icon View MUST
hiển thị ở trạng thái vô hiệu hóa kèm tooltip "No file to view".

**Why this priority**: Xem lại file đã upload là nhu cầu thực tế nhưng đứng sau các nghiệp vụ CRUD
chính (xem danh sách, thêm, sửa, xóa).

**Independent Test**: Tạo một document có file thật qua popup Add, mở danh sách, nhấn icon View trên
dòng đó và xác nhận popup xem trước hiển thị đúng nội dung file (hoặc thông báo lỗi thân thiện nếu
không xem trước được); riêng biệt, xác nhận document không có file thật hiển thị icon View ở trạng
thái vô hiệu hóa.

**Acceptance Scenarios**:

1. **Given** một document có `FileId`, **When** bảng hiển thị dòng đó, **Then** cột Action hiển thị
   icon View ở trạng thái active bình thường bên cạnh Edit và Delete.
2. **Given** một document có `FileId`, **When** nhấn vào icon View, **Then** hệ thống mở popup xem
   trước file thật, gọi `GET /api/eutr-documents/get-file-by-idref?idRef={FileId}`.
3. **Given** một document KHÔNG có `FileId`, **When** bảng hiển thị dòng đó, **Then** icon View hiển
   thị ở trạng thái vô hiệu hóa kèm tooltip "No file to view" và không thể nhấn.

---

### User Story 6 - Tìm kiếm/lọc danh sách qua Search box (Priority: P2)

Phía trên bảng danh sách (User Story 1), người dùng thấy một search box gồm dropdown **Type**,
dropdown **Step name**, ô nhập **Conditions**, và nút **Search**. Người dùng chọn Type và/hoặc Step
name, và/hoặc nhập một phần giá trị Conditions, rồi bấm Search — bảng chỉ hiển thị các document thỏa
mãn đồng thời mọi điều kiện đã cung cấp (document có ít nhất một bản ghi `eutr_references` khớp từng
điều kiện, không nhất thiết cùng bản ghi). Không chọn/nhập gì rồi bấm Search hiển thị lại toàn bộ
danh sách.

**Why this priority**: Giúp người dùng tìm nhanh document cần thiết khi danh sách lớn, nhưng không
phải điều kiện tiên quyết để xem/thêm/sửa/xóa document (đã có ở User Story 1-4).

**Independent Test**: Mở màn hình danh sách, xác nhận search box hiển thị đủ Type/Step name/
Conditions/Search; chọn một Type có ít nhất 1 document, bấm Search, xác nhận bảng chỉ còn các
document có bản ghi `eutr_references` khớp Type đó; xóa lựa chọn Type, chọn một Step name, bấm
Search, xác nhận kết quả đổi theo Step; nhập một phần giá trị Conditions đã biết trước (ví dụ
"PO0001"), bấm Search, xác nhận chỉ document có `RefValue` chứa chuỗi đó xuất hiện; xóa hết điều
kiện, bấm Search, xác nhận danh sách đầy đủ hiển thị lại.

**Acceptance Scenarios**:

1. **Given** đang ở danh sách EUTR documents, **Then** phía trên bảng hiển thị search box gồm
   dropdown Type, dropdown Step name, ô nhập Conditions, và nút Search.
2. **Given** search box đang trống, **When** chọn một Type rồi bấm Search, **Then** bảng chỉ hiển thị
   các document có ít nhất một bản ghi `eutr_references` với `RefType` = Type đã chọn.
3. **Given** search box đang trống, **When** chọn một Step name rồi bấm Search, **Then** bảng chỉ
   hiển thị các document có ít nhất một bản ghi `eutr_references` với `StepId` = Step đã chọn.
4. **Given** search box đang trống, **When** nhập một chuỗi vào Conditions rồi bấm Search, **Then**
   bảng chỉ hiển thị các document có ít nhất một bản ghi `eutr_references` với `RefValue` chứa chuỗi
   đó (không phân biệt hoa/thường).
5. **Given** đã chọn cả Type, Step name và nhập Conditions, **When** bấm Search, **Then** bảng chỉ
   hiển thị các document thỏa mãn đồng thời cả ba điều kiện (mỗi điều kiện có thể khớp bản ghi
   `eutr_references` khác nhau của cùng document).
6. **Given** không có document nào khớp điều kiện đã chọn, **When** bấm Search, **Then** bảng hiển
   thị trạng thái trống ("No data") thay vì lỗi.
7. **Given** đã bấm Search với một số điều kiện, **When** xóa hết điều kiện (Type/Step name về "All",
   Conditions về trống) rồi bấm Search lại, **Then** bảng hiển thị lại toàn bộ danh sách gốc.
8. **Given** kết quả tìm kiếm vượt quá một trang, **When** chuyển trang, **Then** bảng hiển thị đúng
   các bản ghi khớp điều kiện của trang đó (phân trang áp dụng trên tập kết quả đã lọc).

---

### Edge Cases

- Khi danh sách rỗng, bảng hiển thị trạng thái trống thân thiện thay vì lỗi.
- Khi tra cứu `eutr_references`/`eutr_steps`/`eutr_reference_types` cho Step name/Conditions/Type
  thất bại (lỗi mạng/máy chủ/DB), hệ thống hiển thị các cột liên quan ở trạng thái lỗi thân thiện
  (hoặc trống) thay vì lỗi hệ thống, không chặn các cột/thao tác khác của bảng.
- Khi một document có bản ghi `eutr_references` với `RefValue = null` (ví dụ dữ liệu tạo qua popup
  Assign condition cũ trước Update 19), cột Conditions hiển thị trống cho document đó — không phải
  lỗi, là hệ quả đã biết của việc đổi nguồn dữ liệu cột này.
- Khi thêm/sửa một File name đã trùng với document khác, hệ thống vẫn cho phép lưu bình thường
  (không có ràng buộc duy nhất trên File name).
- Khi bảng `eutr_reference_types` chưa có bản ghi nào (bảng rỗng), dropdown Type trong popup Add
  hiển thị trạng thái trống, nút Upload MUST tiếp tục vô hiệu hóa (không phải lỗi hệ thống).
- Khi gọi API gợi ý (`refType = 15` hoặc `refType = 14`) cho ô Value thất bại, ô Value hiển thị
  thông báo lỗi thân thiện; các phần khác của popup (Type, Step, Valid from/to) không bị ảnh hưởng.
- Khi người dùng dán một chuỗi rỗng hoặc chỉ chứa khoảng trắng/dấu phẩy/xuống dòng vào ô Value, hệ
  thống MUST không tạo chip nào, không báo lỗi.
- Khi người dùng đóng popup Add/Edit mà chưa nhấn Upload/Save, hệ thống MUST không tạo/sửa bất kỳ
  document hay bản ghi `eutr_references` nào.
- Khi tất cả file trong một lượt chọn đều không hợp lệ (sai định dạng/kích thước, hoặc — với Type =
  "PO" — không khớp Prefix nào), hệ thống MUST không tạo document nào, chỉ hiển thị thông báo lỗi.
- Khi `eutr_master_documents` hiện không có bản ghi nào hoặc API tra cứu prefix thất bại trong khi
  Type = "PO", mọi file trong lượt upload đều bị coi là "không khớp prefix" và bị loại kèm cảnh báo.
- Khi người dùng đặt Valid from muộn hơn Valid to trong popup Add/Edit, hệ thống MUST báo lỗi rõ
  ràng và chặn Upload/Save cho tới khi giá trị hợp lệ (Valid from ≤ Valid to).
- Khi mở popup Edit cho document có nhiều bản ghi `eutr_references` cùng `RefValue` nhưng khác
  `StepId` (nhiều Step khớp cùng một PO), Save MUST cập nhật `StepId` của toàn bộ các bản ghi đó
  thành cùng một Step mới đã chọn — không tạo thêm/bớt bản ghi.
- Khi Edit một document đã bị xóa trước đó (ví dụ do vừa xóa từ một tab khác), hệ thống MUST báo
  not-found rõ ràng khi mở popup hoặc khi Save, thay vì lỗi hệ thống.
- Khi người dùng không có quyền với một thao tác, nút tương ứng không khả dụng hoặc thao tác bị từ
  chối với thông báo rõ ràng.
- Khi lưu/xóa thất bại do lỗi mạng hoặc máy chủ, người dùng nhận thông báo lỗi và dữ liệu không bị
  thay đổi sai lệch.
- Việc xóa một document qua Delete (User Story 4) hoặc qua Edit KHÔNG gọi API xóa file thật trên
  SharePoint — file vẫn còn tồn tại trên SharePoint, chỉ không còn bản ghi nào trong hệ thống trỏ
  tới nó.
- Khi Type đã chọn (khác "PO") chưa được gán Step nào ở màn Assign Steps (`eutr_reference_type_details`
  rỗng cho `TypeId` đó), combobox Step trong popup Add/Edit hiển thị trống — nút Upload (Add) tiếp tục
  vô hiệu hóa cho tới khi có Step khả dụng.
- Khi Step hiện tại của một document (mở qua Edit) không còn nằm trong danh sách Step đã lọc theo
  Type (đã bị gỡ khỏi Assign Steps sau khi document được tạo), popup Edit vẫn hiển thị đúng Step đó
  như một lựa chọn hợp lệ, không tự động thay thế bằng Step khác hay để trống.
- Khi search box không có Type hoặc Step name nào để chọn (bảng `eutr_reference_types`/`eutr_steps`
  rỗng), dropdown tương ứng hiển thị trạng thái trống nhưng KHÔNG chặn việc dùng các điều kiện lọc
  còn lại hay nhấn nút Search.
- Khi gọi API lọc theo search box thất bại (lỗi mạng/máy chủ), hệ thống hiển thị thông báo lỗi thân
  thiện và giữ nguyên danh sách đang hiển thị trước đó thay vì xóa trắng bảng.
- **(Update 22)** Khi popup Edit đang mở với Type khác "PO" và người dùng cố thêm một giá trị đã tồn
  tại sẵn dưới dạng chip khác (trùng `RefValue`), hệ thống MUST chặn thêm chip trùng, giống quy tắc
  chống trùng chip đã áp dụng ở Add.
- **(Update 22)** Khi popup Edit đang mở với Type = "Vendor" (giới hạn 1 chip) và người dùng xóa chip
  duy nhất đang có mà chưa thêm chip mới, nút Save MUST vô hiệu hóa hoặc bị chặn kèm thông báo lỗi cho
  tới khi có lại đúng 1 chip — không cho phép Save với 0 chip.
- **(Update 22)** Khi gọi API gợi ý giá trị (`refType = 15`/`14`) cho ô Value trong popup Edit (Type
  khác "PO") thất bại, ô Value hiển thị thông báo lỗi thân thiện; các chip hiện có và các trường khác
  của popup (Step, Valid from/to) không bị ảnh hưởng, người dùng vẫn có thể xóa chip hiện có hoặc Save
  mà không thêm chip mới.
- **(Update 22)** Việc thêm/xóa chip trong popup Edit chỉ là thay đổi tạm thời trên giao diện — đóng
  popup mà không nhấn Save MUST không tạo/xóa bất kỳ bản ghi `eutr_references` nào (kế thừa quy tắc
  chung đã có cho Add/Edit).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Hệ thống MUST hiển thị danh sách các EUTR document dạng bảng với các cột: File name,
  Step name, Conditions, Type, Valid from, Valid to, Created by, Created date và cột Action (Edit,
  Delete, View).
- **FR-002**: Hệ thống MUST hiển thị màn hình trong mục điều hướng "EUTR documents" với breadcrumb
  "EUTR > EUTR documents".
- **FR-003**: Người dùng MUST có thể phân trang danh sách khi số bản ghi vượt một trang và chuyển
  trang; danh sách rỗng MUST hiển thị trạng thái trống thay vì lỗi.
- **FR-004**: Hệ thống MUST tính **Step name** và **Type** cho mỗi document bằng cách tra cứu các
  bản ghi `eutr_references` có `DocumentId` = `Id` của document đó: Type = `Name` của bản ghi
  `eutr_reference_types` khớp `RefType`; Step name = tên (các) Step (JOIN `StepId` với
  `eutr_steps.Name`). Document không có bản ghi `eutr_references` nào MUST hiển thị hai cột này ở
  trạng thái trống.
- **FR-005**: Hệ thống MUST tính cột **Conditions** cho mỗi document bằng cách lấy mọi giá trị
  `RefValue` khác null từ các bản ghi `eutr_references` có `DocumentId` = `Id` của document đó, hiển
  thị mỗi giá trị dưới dạng một chip. Document không có `RefValue` nào (không có bản ghi, hoặc mọi
  bản ghi có `RefValue = null`) MUST hiển thị cột này ở trạng thái trống.
- **FR-006**: Khi một document có nhiều giá trị Step name hoặc Conditions, giao diện MAY giới hạn số
  lượng hiển thị trực tiếp và gộp phần còn lại vào chỉ báo "+N more" kèm tooltip liệt kê đầy đủ,
  theo mẫu cột "Country Codes" (`useCountryGroupColumns.jsx`).
- **FR-007**: Icon **View** trên cột Action MUST mở popup xem trước file thật khi document có
  `FileId` (gọi `GET /api/eutr-documents/get-file-by-idref?idRef={FileId}`), hoặc hiển thị ở trạng
  thái vô hiệu hóa kèm tooltip "No file to view" khi document không có `FileId`.
- **FR-008**: Nút **Add** trên toolbar MUST mở một popup (modal) tiêu đề "Add EUTR documents".
- **FR-009**: Popup Add MUST có trường **Type** dạng dropdown, dữ liệu tải từ toàn bộ bản ghi bảng
  `eutr_reference_types` (`Name` làm nhãn hiển thị, `Id` dùng làm `RefType` khi ghi dữ liệu). Mọi
  logic rẽ nhánh theo Type (nguồn gợi ý Value, thư mục SharePoint, validate prefix) MUST so khớp
  theo `Name` (chính xác, không phân biệt hoa/thường).
- **FR-010**: Popup Add MUST có một combobox **Step** (single-select, dữ liệu từ `eutr_steps`). Step
  là bắt buộc trừ khi Type đã chọn có `Name` = "PO" — khi đó combobox Step MUST ẩn hẳn và không bắt
  buộc.
- **FR-011**: Ô **Value** trong popup Add MUST là một combobox: nếu Type đã chọn có `Name` là "PO",
  "Invoice", hoặc "Delivery note", ô Value MUST hiển thị gợi ý PO tải từ
  `POST /api/dynamics/reference` (`refType = 15`); nếu `Name` là "Vendor", MUST hiển thị gợi ý Vendor
  tải với `refType = 14`; Type khác MUST là ô nhập tự do không có gợi ý.
- **FR-012**: Chọn một mục gợi ý, hoặc gõ tay một giá trị (khớp dữ liệu tham chiếu nếu Type có nguồn
  gợi ý; tự do nếu không) rồi xác nhận, MUST thêm giá trị đó thành một chip vào vùng chọn và MUST
  làm ô Value trở về trống ngay lập tức. Giá trị gõ tay KHÔNG khớp dữ liệu tham chiếu (khi Type có
  nguồn gợi ý) MUST bị từ chối, không tạo chip, kèm thông báo lỗi. Ô Value MUST hỗ trợ dán nhiều giá
  trị cùng lúc (phân tách bằng dấu phẩy và/hoặc xuống dòng), tách và so khớp từng giá trị theo cùng
  quy tắc trên.
- **FR-013**: Khi Type đã chọn có `Name` là "PO" hoặc "Vendor", vùng chọn MUST chỉ cho phép tối đa 1
  chip — thêm chip mới khi đã có 1 chip MUST bị chặn kèm thông báo. Với Type khác, vùng chọn MUST
  cho phép nhiều chip. Đổi giá trị dropdown Type MUST xóa toàn bộ chip hiện có.
- **FR-014**: Popup Add MUST có trường **Valid from** (ô chọn ngày), mặc định hiển thị giá trị = ngày
  hiện tại tại thời điểm mở popup, cho phép người dùng sửa trước khi Upload.
- **FR-015**: Popup Add MUST có trường **Valid to** (ô chọn ngày), mặc định hiển thị giá trị = ngày
  tối đa `9999-12-31`, cho phép người dùng sửa trước khi Upload.
- **FR-016**: Popup Add MUST validate Valid from ≤ Valid to; nếu Valid from muộn hơn Valid to, hệ
  thống MUST báo lỗi và chặn Upload cho tới khi giá trị hợp lệ.
- **FR-017**: Nút **Upload** trong popup Add MUST ở trạng thái vô hiệu hóa cho tới khi: với Type khác
  "PO" — đã chọn Type, đã chọn Step, và vùng chọn có ít nhất 1 chip; với Type = "PO" — đã chọn Type
  và vùng chọn có ít nhất 1 chip (không cần Step). Khi khả dụng và được nhấn, MUST mở hộp thoại chọn
  file của hệ điều hành cho phép chọn nhiều file cùng lúc.
- **FR-018**: Hệ thống MUST chỉ chấp nhận file có định dạng PDF, DOC/DOCX, XLS/XLSX, JPG/PNG với
  kích thước tối đa 10MB mỗi file. File không thỏa điều kiện MUST bị loại khỏi lượt upload kèm thông
  báo lỗi liệt kê tên file và lý do; các file hợp lệ còn lại trong cùng lượt MUST vẫn được upload.
- **FR-019**: Với mỗi file hợp lệ, hệ thống MUST xác định thư mục SharePoint đích theo `Name` của
  Type đã chọn: "PO"/"Vendor" → thư mục đặt tên theo chip đã chọn (tìm thư mục cũ hoặc tạo mới dưới
  `SharePointEutrPath`); "Invoice" → `{SharePointEutrPath}/Invoice`; "Delivery note" →
  `{SharePointEutrPath}/DeliveryNote`; "General agreement" → `{SharePointEutrPath}/GeneralAgreement`;
  Type khác → thư mục cố định đặt tên theo `Name` của Type đó.
- **FR-020**: Khi Type = "PO", trước khi upload lên SharePoint, hệ thống MUST validate tên file bắt
  đầu bằng (không phân biệt hoa/thường) một `Prefix` đang tồn tại trong `eutr_master_documents`; file
  không khớp bất kỳ Prefix nào MUST bị loại khỏi lượt upload kèm cảnh báo rõ ràng, không chặn các
  file hợp lệ khác trong cùng lượt.
- **FR-021**: Với mỗi file upload thành công lên SharePoint, hệ thống MUST tạo một bản ghi mới trong
  `eutr_documents`: File name = tên file gốc, Valid from = giá trị đang hiển thị ở trường Valid from
  của popup tại thời điểm Upload, Valid to = giá trị đang hiển thị ở trường Valid to, FileId = id trả
  về từ SharePoint; ghi nhận người tạo/ngày tạo tự động.
- **FR-022**: Với Type khác "PO", với mỗi file upload thành công, hệ thống MUST ghi thêm một bản ghi
  `eutr_references` cho **mỗi** chip đang có trong vùng chọn tại thời điểm Upload: `DocumentId` = Id
  document vừa tạo, `StepId` = Step đã chọn, `RefType` = `Id` của Type đã chọn, `RefValue` = giá trị
  chip đó.
- **FR-023**: Với Type = "PO", với mỗi file upload thành công, hệ thống MUST ghi một bản ghi
  `eutr_references` cho **mỗi** `StepId` khớp Prefix của file đó (FR-020): `DocumentId` = Id document
  vừa tạo, `StepId` = từng `StepId` khớp, `RefType` = `Id` của Type "PO" đang chọn (gửi kèm dưới dạng
  `TypeId` từ frontend), `RefValue` = giá trị chip PO đã chọn.
- **FR-024**: Popup Add MUST tự đóng lại ngay sau khi một lượt Upload hoàn tất (dù toàn bộ hay một
  phần file thành công) — mỗi lần mở popup chỉ thực hiện đúng một lượt Upload.
- **FR-025**: Nếu một hoặc nhiều file trong cùng lượt upload thất bại (sai định dạng/kích thước,
  không khớp prefix khi Type = "PO", hoặc lỗi mạng/máy chủ khi upload lên SharePoint) trong khi các
  file khác thành công, hệ thống MUST vẫn tạo document cho các file thành công và hiển thị thông báo
  lỗi liệt kê rõ các file thất bại — không rollback các file đã thành công.
- **FR-026**: Nút **Edit** trên một dòng MUST mở lại đúng popup dùng ở Add (tiêu đề đổi thành "Edit
  EUTR document"), ở **chế độ sửa**, nạp sẵn Type hiện tại, Step hiện tại, (các) chip Value hiện có
  (từ `RefValue` của các bản ghi `eutr_references`), và Valid from/Valid to hiện tại của document.
- **FR-027**: Ở chế độ sửa, dropdown **Type** MUST bị khóa (vô hiệu hóa) — không đổi được.
- **FR-028**: Ở chế độ sửa, khi Type hiện tại của document = "PO", vùng chip **Value** MUST hiển thị ở
  dạng chỉ đọc — không có ô Value để thêm giá trị mới, không có nút xóa trên các chip hiện có. Khi
  Type hiện tại khác "PO", vùng chip Value áp dụng quy tắc chỉnh sửa được ở FR-051.
- **FR-029**: Ở chế độ sửa, combobox **Step** MUST vẫn khả dụng để sửa, dùng cùng nguồn dữ liệu với
  Add.
- **FR-030**: Ở chế độ sửa, trường **Valid from** và **Valid to** MUST vẫn khả dụng để sửa, nạp sẵn
  giá trị hiện tại của document (KHÔNG reset về mặc định ngày hiện tại/ngày tối đa).
- **FR-031**: Ở chế độ sửa, popup MUST KHÔNG hiển thị control Upload/chọn file — thay bằng nút
  **Save**.
- **FR-032**: Khi document đang sửa có nhiều bản ghi `eutr_references` với nhiều `StepId` phân biệt,
  giá trị Step hiển thị ban đầu trong popup Edit MUST là Step ứng với bản ghi có `Id` nhỏ nhất trong
  số đó (deterministic).
- **FR-033**: Khi nhấn Save ở chế độ sửa với document có Type = "PO" (hoặc không có Type), hệ thống
  MUST: (a) cập nhật `ValidFrom`/`ValidTo` của `eutr_documents` thành giá trị mới đang hiển thị; (b)
  cập nhật `StepId` của **mọi** bản ghi `eutr_references` có `DocumentId` = document đang sửa thành
  Step mới đã chọn — giữ nguyên `RefValue`/`RefType` của từng bản ghi, không thêm/xóa bản ghi nào. Với
  document có Type khác "PO", Save áp dụng thêm quy tắc đồng bộ chip Value ở FR-052.
- **FR-034**: Document không có bản ghi `eutr_references` nào (Type trống), khi mở Edit, MUST hiển
  thị Type/chip Value ở trạng thái trống và MUST ẩn trường Step — chỉ Valid from/Valid to khả dụng
  để sửa.
- **FR-035**: Người dùng MUST có thể xóa một document, có bước xác nhận trước khi xóa; việc xóa MUST
  bao gồm xóa toàn bộ bản ghi `eutr_references` có `DocumentId` tương ứng, trong cùng một giao dịch
  (nếu bước xóa `eutr_references` thất bại, document đó KHÔNG bị xóa).
- **FR-036**: Hệ thống MUST hỗ trợ xóa nhiều document cùng lúc; mỗi document trong lượt xóa nhiều
  MUST được xử lý độc lập theo FR-035 — lỗi ở một document không chặn việc xóa các document khác
  trong cùng lượt.
- **FR-037**: Hệ thống MUST tôn trọng quyền truy cập đã định nghĩa cho từng thao tác (xem, thêm mới,
  sửa, xóa); thao tác không được phép phải bị ngăn chặn.
- **FR-038**: Toàn bộ văn bản hiển thị cho người dùng trên front-end MUST bằng tiếng Anh, bao gồm:
  nhãn cột, nhãn trường (Type, Step, Value, Valid from, Valid to), nút (Add, Edit, Delete, View,
  Upload, Save, Cancel, Download), breadcrumb, thông báo kiểm tra/lỗi, thông báo thành công, trạng
  thái rỗng ("No data"), tooltip "No file to view", và hộp thoại xác nhận xóa.
- **FR-039**: Backend MUST duy trì việc đăng ký D365 entity `RSVNEutrPurchOrders` với
  **`refType = 15`** trong bảng ánh xạ entity dùng bởi `POST /api/dynamics/reference`, dùng làm
  nguồn gợi ý PO ở ô Value (FR-011) và nguồn dữ liệu định danh thư mục SharePoint (FR-019).
- **FR-040**: Backend MUST duy trì việc đăng ký D365 entity `RSVNEutrSalesOrderPurchases` với
  **`refType = 16`** trong cùng bảng ánh xạ — refType này KHÔNG được gọi bởi bất kỳ màn hình nào
  trong phạm vi feature `004-eutr-documents`.
- **FR-041**: Backend MUST duy trì việc đăng ký D365 entity `VendorsV3` với **`refType = 14`**, dùng
  làm nguồn gợi ý Vendor ở ô Value (FR-011) khi Type = "Vendor".
- **FR-042**: Backend MUST cung cấp endpoint **`GET /api/eutr-documents/get-file-by-idref`** (nhận
  `idRef` = `FileId`), read-only, trả về nội dung file dạng base64 kèm content type/file name, dùng
  cho popup xem trước file (FR-007), tham khảo mẫu `ComplCompliancesController.GetFileByIds`.
- **FR-043 (Update 20)**: Khi Type đã chọn khác "PO" (combobox Step đang hiển thị theo FR-010), hệ
  thống MUST lọc danh sách Step nạp vào combobox Step chỉ còn các Step có ít nhất một bản ghi trong
  `eutr_reference_type_details` với `TypeId` = `Id` của Type đang chọn (JOIN `StepId` với
  `eutr_steps.Name` làm nhãn hiển thị) — Step không có bản ghi gán cho Type đó MUST không xuất hiện
  trong danh sách dù vẫn tồn tại trong `eutr_steps`.
- **FR-044 (Update 20)**: Ngay sau khi danh sách Step đã lọc theo FR-043 được tải trong popup Add,
  combobox Step MUST tự động chọn sẵn dòng đầu tiên của danh sách đó làm giá trị mặc định; đổi Type
  MUST tải lại danh sách theo Type mới và áp dụng lại việc chọn mặc định dòng đầu tiên.
- **FR-045 (Update 20)**: Trong popup Edit, combobox Step MUST áp dụng cùng quy tắc lọc FR-043 theo
  Type hiện tại (đã khóa) của document đang sửa; giá trị Step hiện tại của document (xác định theo
  FR-032) MUST luôn được đảm bảo hiển thị làm lựa chọn hợp lệ trong combobox kể cả khi Step đó không
  còn nằm trong danh sách đã lọc (ví dụ đã bị gỡ khỏi Assign Steps sau khi document được tạo) — không
  tự động thay thế bằng Step khác.
- **FR-046 (Update 21)**: Màn hình danh sách chính MUST hiển thị một search box phía trên bảng, gồm:
  dropdown **Type** (dữ liệu từ toàn bộ `eutr_reference_types`, có tùy chọn trống "All"), dropdown
  **Step name** (dữ liệu từ toàn bộ `eutr_steps`, có tùy chọn trống "All", KHÔNG lọc theo Type đang
  chọn trong cùng search box), ô nhập tự do **Conditions**, và nút **Search**.
- **FR-047 (Update 21)**: Nhấn nút Search MUST lọc bảng danh sách chính theo mọi điều kiện đã cung
  cấp tại thời điểm bấm (Type/Step name/Conditions), kết hợp AND, và tải lại danh sách từ trang 1;
  KHÔNG tự động lọc khi người dùng đang thay đổi giá trị các control mà chưa bấm Search. Không cung
  cấp điều kiện nào rồi bấm Search MUST hiển thị lại toàn bộ danh sách gốc.
- **FR-048 (Update 21)**: Một document MUST được coi là khớp điều kiện lọc khi: (a) nếu Type được
  chọn — document có ít nhất một bản ghi `eutr_references` với `RefType` = Type đó; (b) nếu Step name
  được chọn — document có ít nhất một bản ghi `eutr_references` với `StepId` = Step đó; (c) nếu
  Conditions có giá trị — document có ít nhất một bản ghi `eutr_references` với `RefValue` chứa
  (không phân biệt hoa/thường) chuỗi đã nhập. Ba điều kiện (khi được cung cấp) KHÔNG bắt buộc khớp
  trên cùng một bản ghi `eutr_references` của document đó.
- **FR-049 (Update 21)**: Tập kết quả đã lọc MUST hỗ trợ phân trang theo cùng cơ chế với danh sách
  gốc (FR-003); chuyển trang sau khi Search MUST áp dụng trên tập kết quả đã lọc, không phải toàn bộ
  danh sách gốc.
- **FR-050 (Update 21)**: Toàn bộ nhãn/placeholder của search box (Type, Step name, Conditions,
  Search, "All") MUST bằng tiếng Anh, theo cùng quy tắc với FR-038.
- **FR-051 (Update 22)**: Ở chế độ sửa, khi Type hiện tại của document (đã khóa) **khác "PO"** (bao
  gồm "Vendor"), vùng chip **Value** MUST cho phép chỉnh sửa: hiển thị ô Value dạng combobox cùng
  nguồn gợi ý theo Type như FR-011/FR-012 (bao gồm hỗ trợ dán nhiều giá trị và từ chối giá trị không
  khớp dữ liệu tham chiếu khi Type có nguồn gợi ý) để thêm chip mới, và mỗi chip hiện có MUST có nút
  xóa. Quy tắc giới hạn số chip theo Type ở FR-013 (tối đa 1 chip khi Type = "Vendor") tiếp tục áp
  dụng trong chế độ sửa. Vùng chip MUST yêu cầu còn lại ít nhất 1 chip tại thời điểm Save — nút Save
  MUST vô hiệu hóa hoặc Save bị chặn kèm thông báo lỗi nếu vùng chip trống.
- **FR-052 (Update 22)**: Khi nhấn Save ở chế độ sửa với document có Type khác "PO", hệ thống MUST
  đồng bộ bản ghi `eutr_references` của document theo đúng tập chip Value đang hiển thị tại thời điểm
  Save: (a) tạo một bản ghi mới (`DocumentId` = document đang sửa, `StepId` = Step đang chọn, `RefType`
  = `Id` của Type hiện tại, `RefValue` = giá trị chip) cho mỗi chip mới thêm (chip chưa có bản ghi
  `RefValue` khớp trước đó); (b) xóa bản ghi `eutr_references` có `RefValue` khớp cho mỗi chip đã bị
  xóa khỏi vùng chip so với trạng thái nạp ban đầu; (c) cập nhật `StepId` của mọi bản ghi còn lại của
  document đó (không bị xóa ở bước (b), kể cả bản ghi vừa tạo ở bước (a)) thành Step đang chọn.
- **FR-053 (Update 22)**: Thao tác thêm/xóa chip Value trong popup Edit (Type khác "PO") MUST chỉ là
  thay đổi tạm thời trên giao diện — KHÔNG gọi API tạo/xóa `eutr_references` ngay lập tức; mọi thay
  đổi chỉ được áp dụng khi nhấn Save (FR-052). Đóng popup mà không nhấn Save MUST không tạo/xóa bất kỳ
  bản ghi `eutr_references` nào, dù đã thêm/xóa chip trên giao diện.
- **FR-054 (Update 22)**: Vùng chip Value trong popup Edit (Type khác "PO") MUST chặn thêm một giá trị
  đã tồn tại sẵn dưới dạng chip khác (trùng `RefValue`), cùng quy tắc chống trùng đã áp dụng ở Add.
- **FR-055 (Update 22)**: Ở chế độ sửa, khi Type hiện tại của document = "PO", vùng chip Value tiếp
  tục MUST ở dạng chỉ đọc theo FR-028 — FR-051 đến FR-054 KHÔNG áp dụng cho Type = "PO".

## Key Entities *(include if feature involves data)*

- **EUTR Document**: Đại diện cho một document EUTR. Thuộc tính: định danh, File name (văn bản,
  không duy nhất giữa các document, VARCHAR(255)), Valid from, Valid to, FileId, người tạo, ngày
  tạo, người cập nhật, ngày cập nhật. Lưu vào bảng `eutr_documents`. Mọi document mới MUST được tạo
  thông qua một lượt Upload thành công trong popup Add (không còn cách tạo document nào khác) — Valid
  from/Valid to lấy từ giá trị đang hiển thị ở popup tại thời điểm Upload (mặc định ngày hiện tại/
  ngày tối đa, có thể chỉnh sửa). `FileId` dùng làm khóa để đọc lại nội dung file thật từ SharePoint
  khi nhấn icon View; document có `FileId = null` (dữ liệu cũ) không có nội dung để xem trước. Edit
  MUST có thể cập nhật trực tiếp `ValidFrom`/`ValidTo` của document mà không tạo bản ghi mới.
- **EUTR Reference (liên kết Document ↔ Step/Type/Value)**: Bảng `eutr_references` (Id, RefId,
  DocumentId, StepId, RefType, RefValue). Mỗi file upload thành công qua popup Add tạo một hoặc
  nhiều bản ghi: với Type khác "PO", một bản ghi cho mỗi chip Value đã chọn (`RefValue` = giá trị
  chip); với Type = "PO", một bản ghi cho mỗi `StepId` khớp Prefix (`RefValue` = mã PO đã chọn,
  giống nhau trên các bản ghi). `RefType` = `Id` của bản ghi `eutr_reference_types` đã chọn ở Type.
  Cột `RefId` hiện có KHÔNG được ghi bởi feature này (giữ nguyên mục đích thiết kế cũ, trỏ tới
  `eutr_template_details`). Bảng này là nguồn dữ liệu duy nhất cho cột Step name/Type/Conditions
  trên danh sách chính (JOIN `eutr_steps`/`eutr_reference_types`; `RefValue` hiển thị trực tiếp làm
  chip Conditions). Edit (User Story 3) với Type = "PO" MUST cập nhật trực tiếp `StepId` của mọi bản
  ghi thuộc một document khi Save — không xóa/tạo lại bản ghi nào. Edit với Type khác "PO" (Update 22)
  MUST đồng bộ cả tập bản ghi theo tập chip Value đang hiển thị khi Save — tạo bản ghi mới cho chip
  mới thêm, xóa bản ghi cho chip đã xóa, và cập nhật `StepId` của mọi bản ghi còn lại (xem FR-052).
  Xóa document (User Story 4) MUST xóa toàn bộ bản ghi có `DocumentId` tương ứng, cùng giao dịch.
- **EUTR Reference Type — KHÔNG thuộc phạm vi CRUD feature này**: Bảng `eutr_reference_types` (Id,
  Name, ...), quản lý CRUD bởi feature `006-eutr-reference-types`. Feature này **đọc (read-only)**
  bảng này để: (a) làm nguồn dữ liệu dropdown Type trong popup Add/Edit; (b) JOIN `RefType` với `Id`
  để lấy `Name` làm nhãn cột Type trên danh sách chính.
- **EUTR Reference Type Detail (Assign Steps, đọc bởi feature này từ Update 20) — KHÔNG thuộc phạm vi
  CRUD feature này**: Bảng `eutr_reference_type_details` (Id, StepId, TypeId, CreatedBy, CreatedDate,
  UpdatedBy, UpdatedDate), quản lý CRUD (Add/Edit/Delete) bởi feature `006-eutr-reference-types` (màn
  "Assign Steps"). Feature này **đọc (read-only)** bảng này để lọc danh sách Step hiển thị trong
  combobox Step của popup Add/Edit theo Type đang chọn (FR-043/FR-044/FR-045) — một Step chỉ xuất
  hiện trong combobox nếu có bản ghi `TypeId` khớp Type đó.
- **EUTR Master Document (Prefix/Step) — nguồn tham chiếu, KHÔNG thuộc phạm vi CRUD feature này**:
  Bảng `eutr_master_documents` (Id, StepId, Prefix), quản lý bởi feature `002-eutr-masters`. Feature
  này đọc (read-only) bảng này để validate tên file khi Type = "PO" — `Prefix` chỉ duy nhất theo cặp
  (`StepId`, `Prefix`), một chuỗi Prefix có thể khớp nhiều `StepId`, khi đó mỗi `StepId` khớp tạo một
  bản ghi `eutr_references` riêng.
- **D365 RSVNEutrPurchOrders / RSVNEutrSalesOrderPurchases / VendorsV3 (external, read-only)**: Dữ
  liệu tham chiếu D365 lấy qua `POST /api/dynamics/reference` với `refType = 15`/`16`/`14` tương
  ứng — không có bảng lưu trữ cục bộ.
- **SharePoint Folder theo Type**: Thư mục con trên SharePoint dưới `SharePointEutrPath`, xác định
  theo `Name` của Type đã chọn (xem FR-019) — không có bảng lưu trữ cục bộ ánh xạ Type ↔ thư mục.
- **SharePoint File Content (xem trước)**: Nội dung file thật (base64) kèm content type/file name,
  đọc trực tiếp từ SharePoint qua `FileId` mỗi khi nhấn icon View — dữ liệu tạm thời, không lưu trữ
  ngoài phạm vi hiển thị popup xem trước.
- **EUTR Reference Detail (`eutr_reference_details`) — KHÔNG còn thuộc phạm vi feature này**: Bảng
  từng được ghi/đọc bởi popup Assign condition cũ (Update 11-13). Kể từ Update 19, feature này KHÔNG
  còn đọc/ghi bảng này ở bất kỳ luồng nào — dữ liệu cũ (nếu có) được giữ nguyên trong schema nhưng
  không còn được hiển thị hay chỉnh sửa qua màn hình này.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Người dùng tìm thấy và mở màn hình EUTR documents trong vòng 10 giây kể từ khi vào hệ
  thống mà không cần hướng dẫn.
- **SC-002**: 100% document có ít nhất một bản ghi `eutr_references` với `RefValue` khác null hiển
  thị đúng và đầy đủ các chip Conditions tương ứng trên danh sách chính; document không có `RefValue`
  nào hiển thị cột này ở trạng thái trống — không phân biệt theo Type.
- **SC-003**: 100% lượt Upload thành công trong popup Add tạo document với Valid from/Valid to đúng
  bằng giá trị đang hiển thị ở popup tại thời điểm Upload (mặc định ngày hiện tại/ngày tối đa nếu
  người dùng không chỉnh sửa).
- **SC-004**: 100% lượt nhấn Edit mở đúng popup Add ở chế độ sửa với Type bị khóa — không có trường
  hợp Type bị thay đổi qua Edit; với Type = "PO", (các) chip Value luôn ở dạng chỉ đọc.
- **SC-005**: 100% lượt Save trong popup Edit với document Type = "PO" chỉ làm thay đổi Step (StepId
  của mọi bản ghi `eutr_references` của document đó) và/hoặc Valid from/Valid to của document — không
  có bản ghi `eutr_references` nào bị thêm/xóa, `RefValue`/`RefType` không đổi.
- **SC-012 (Update 22)**: 100% lượt Save trong popup Edit với document Type khác "PO" tạo ra đúng tập
  bản ghi `eutr_references` khớp chính xác tập chip Value đang hiển thị tại thời điểm Save (không thừa/
  thiếu bản ghi so với các chip), với `StepId` của mọi bản ghi còn lại đúng bằng Step đã chọn.
- **SC-006**: 100% document Type = "PO" mới tạo qua popup Add có đúng N bản ghi `eutr_references`
  tương ứng (N = số `StepId` khớp Prefix của file đó), mỗi bản ghi có `RefValue` = mã PO đã chọn.
- **SC-007**: 100% document bị xóa (đơn hoặc nhiều) không còn để lại bản ghi `eutr_references` nào
  có `DocumentId` trỏ tới document đó.
- **SC-008**: 100% lượt nhấn icon View trên một document có `FileId` mở đúng popup xem trước file
  thật; 100% document không có `FileId` hiển thị icon View ở trạng thái vô hiệu hóa.
- **SC-009**: 100% lượt đặt Valid from muộn hơn Valid to trong popup Add/Edit bị chặn kèm thông báo
  lỗi rõ ràng, không tạo/sửa document nào cho tới khi giá trị hợp lệ.
- **SC-010 (Update 20)**: 100% lượt hiển thị combobox Step (Type khác "PO") trong popup Add/Edit chỉ
  liệt kê các Step đã được gán (Assign Steps) cho Type đang chọn trong `eutr_reference_type_details`;
  100% lượt mở popup Add với danh sách Step lọc không rỗng có sẵn dòng đầu tiên được chọn làm mặc
  định.
- **SC-011 (Update 21)**: 100% lượt bấm Search với ít nhất một điều kiện (Type/Step name/Conditions)
  trả về đúng và đầy đủ tập document thỏa FR-048; 100% lượt bấm Search khi search box trống trả về
  đầy đủ danh sách gốc (không thiếu/thừa bản ghi).

## Assumptions

- Popup Add và popup Edit dùng chung một component giao diện, chuyển đổi qua một cờ "chế độ" (Add
  vs Edit) để bật/tắt: control Upload/chọn file (chỉ Add), khóa dropdown Type (chỉ Edit), hiển thị nút
  Upload (Add) hoặc Save (Edit). Chip Value chỉ đọc khi ở chế độ Edit VÀ Type = "PO" (Update 22); các
  trường hợp Edit khác (Type khác "PO") hiển thị lại ô Value/nút xóa chip giống Add.
- Trường Valid from/Valid to là ô chọn ngày (date picker) tiêu chuẩn; giá trị sentinel "không giới
  hạn" cho Valid to tiếp tục dùng `9999-12-31` (giá trị lớn nhất hợp lệ cho kiểu cột `DATE` trong
  MySQL), không cần thêm cột/flag "no expiry" riêng.
- Bảng `eutr_reference_details` KHÔNG bị xóa hay migrate — chỉ không còn được feature này đọc/ghi.
  Document Type = "Upload manual" được tạo qua popup Assign condition cũ (trước Update 19) hiển thị
  Conditions trống nếu bản ghi `eutr_references` tương ứng có `RefValue = null` — đây là hệ quả đã
  biết, không cần xử lý bù trừ/migration dữ liệu trong phạm vi feature này.
- Cột `StepId` trên `eutr_references` (bổ sung từ Update 7), validate prefix theo
  `eutr_master_documents` (Update 7/17), quy tắc đặt thư mục SharePoint theo Type (Update 15), và
  việc đăng ký các entity D365 (`refType = 14`/`15`/`16`) tiếp tục được kế thừa nguyên vẹn, không
  yêu cầu migration DB mới nào thêm ở bản cập nhật này.
- Xóa là xóa thật (hard delete) — bảng `eutr_documents` không có cờ soft-delete.
- Khóa ngoại `eutr_references_documentid_foreign` hiện KHÔNG có `ON DELETE CASCADE` — việc dọn
  `eutr_references` khi xóa document MUST tiếp tục được xử lý ở tầng ứng dụng (application-level),
  trong cùng transaction với xóa `eutr_documents`.
- Người tạo/ngày tạo do hệ thống ghi tự động dựa trên người dùng đăng nhập; người dùng không nhập
  tay các giá trị này.
- Quyền truy cập từng thao tác được định nghĩa theo policy của API theo cùng mẫu EUTR Masters
  (ReadAll, ReadOne, Create, Update, Delete), được tái sử dụng.
- Combobox Step (Add/Edit) và dropdown Type dùng lại đúng nguồn dữ liệu Step/Reference Type hiện có
  trong hệ thống — không tạo API lấy danh sách mới.
- **(Update 20)** Tính năng lọc Step theo `eutr_reference_type_details` phụ thuộc vào dữ liệu đã được
  cấu hình qua màn "Assign Steps" của feature `006-eutr-reference-types`; nếu Type nào chưa được gán
  Step nào ở đó, popup Add/Edit của feature này sẽ không có Step để chọn (Upload bị chặn ở Add) — đây
  là hành vi mong đợi, không cần xử lý bù trừ trong phạm vi feature `004-eutr-documents`.
- **(Update 20)** "Dòng đầu tiên" của danh sách Step đã lọc được hiểu theo thứ tự trả về từ API lọc
  (ví dụ theo `Id` tăng dần của `eutr_reference_type_details` hoặc tên Step A-Z) — thứ tự cụ thể do
  backend quyết định, không có yêu cầu nghiệp vụ nào bắt buộc một thứ tự sắp xếp cụ thể.
- **(Update 21)** Search box là bộ lọc gửi điều kiện lên API danh sách hiện có (mở rộng tham số truy
  vấn), không tạo màn hình hay endpoint tìm kiếm riêng biệt.
- **(Update 21)** Dropdown Step name trong search box hiển thị toàn bộ `eutr_steps`, không lọc theo
  Type đang chọn trong cùng search box — khác cơ chế lọc Step theo Assign Steps ở popup Add/Edit
  (Update 20), vì đây là bộ lọc độc lập trên dữ liệu đã có, không phải nhập liệu tạo mới.
- **(Update 21)** Điều kiện Conditions dùng khớp "chứa" (contains), không phân biệt hoa/thường — phù
  hợp hành vi tìm kiếm thông thường, không yêu cầu khớp chính xác tuyệt đối theo yêu cầu gốc.
- **(Update 22)** "Type không phải là PO" trong yêu cầu gốc được hiểu bao gồm cả "Vendor" — Vendor vẫn
  giữ giới hạn tối đa 1 chip (FR-013) nhưng được phép thêm/xóa (thay thế) chip đó trong Edit, giống
  các Type khác ngoài PO; chỉ riêng Type = "PO" tiếp tục khóa hoàn toàn vùng chip Value.
- **(Update 22)** Thêm/xóa chip trong Edit không có API riêng — Save tiếp tục dùng cùng endpoint cập
  nhật document/Step hiện có (FR-033), backend tính toán phần chênh lệch (tạo/xóa `eutr_references`)
  dựa trên tập `RefValue` gửi lên so với tập hiện có trong DB tại thời điểm Save.
