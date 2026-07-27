# Feature Specification: EUTR Sales Orders Management

**Feature Branch**: `005-eutr-sales-orders`

**Created**: 2026-07-14

**Status**: Draft

**Input**: User description: "chức năng mới eutr-sales-orders. giao diện front end trong eutr-sales-orders. đổ dữ liệu từ ComplianceSys.Api.Controllers, [HttpPost("reference")] với reftype = 11, các cột sales id, customer, customer name. delivery date. cột tempate, progess để cố định dữ liệu demo"

## Clarifications

### Session 2026-07-27 (Update 11) — Số liệu progress/mappedRequired/missingRequired chỉ tính step Required, cộng dồn trên toàn bộ template, nhất quán giữa Map File và View

- Bối cảnh: Đọc lại toàn bộ các biến đang đếm số lượng step "đã map"/"còn thiếu" ở cả hai màn hình:
  - **Map File** (`MapFilePage.jsx`): `progress.total`/`progress.completed` (dùng cho thanh tiến độ ở
    `data-marker="progress-bar"`, chip "Mapped: x/y", và dòng "Required: x/y" ở footer Step 2) được tính
    qua `computeProgress()` — chỉ đếm step có `requirementType` = **Required**, cộng dồn qua toàn bộ
    template đã lưu (đúng theo FR-057), nhưng KHÔNG loại trừ các step có `takeFrom` thuộc nhóm nguồn tự
    động cũ (`AUTO_SOURCES`). Biến `missingRequired` (dòng "Still missing X file" cùng footer) cũng chỉ
    đếm step Required, cộng dồn qua toàn bộ template, nhưng CÓ loại trừ `AUTO_SOURCES`.
  - **View Sales Order** (`ViewSalesOrderPage.jsx`): `requiredDetails`/`mappedRequired`/`missingRequired`
    (dùng cho thanh tiến độ ở header và Validation Summary) chỉ đếm step Required, cộng dồn qua toàn bộ
    template đã lưu (đúng theo FR-062), và CÓ loại trừ `AUTO_SOURCES` — cùng logic với `missingRequired`
    của Map File.
  - Vì `progress.total`/`progress.completed` của Map File không loại trừ `AUTO_SOURCES` trong khi
    `missingRequired` (cùng màn hình Map File) và mọi biến tương ứng của View đều loại trừ, nếu sau này
    phát sinh step Required có `takeFrom` thuộc `AUTO_SOURCES` và chưa có tài liệu, `progress.total -
    progress.completed` ở Map File sẽ không còn khớp với số của `missingRequired` trên cùng màn hình,
    cũng như không còn khớp với số tương ứng bên View — một sự thiếu nhất quán giữa các biến, dù hiện
    tại chưa quan sát được khác biệt bằng mắt vì dữ liệu thật (`eutr_template_details`) chỉ có `takeFrom`
    là "PO"/"Upload manual", chưa từng có giá trị thuộc `AUTO_SOURCES`.
  - **Xác nhận lại phạm vi đúng của yêu cầu ban đầu** (thay thế cách hiểu đã ghi ở bản nháp trước của
    Update 11): số liệu tiến độ ở `data-marker="progress-bar"` MUST tiếp tục **chỉ đếm step Required**
    (KHÔNG mở rộng sang step Optional) — "tổng"/"toàn bộ" trong yêu cầu nghĩa là cộng dồn đúng trên
    **toàn bộ (các) template đã lưu của Sales Order** (điều này đã đúng sẵn từ Update 7), không phải mở
    rộng loại step được tính.
- Change: `progress.total` và `progress.completed` (Map File, `data-marker="progress-bar"`) MUST tiếp
  tục chỉ đếm step có `requirementType` = Required, cộng dồn đúng trên toàn bộ (các) template đã lưu của
  Sales Order này (giữ nguyên đúng phạm vi/quy tắc PO-Template hiện có của FR-057) — KHÔNG bao gồm step
  Optional.
- Change: `progress.total` và `progress.completed` (Map File) MUST áp dụng thêm đúng quy tắc loại trừ
  `AUTO_SOURCES` đã có sẵn ở `missingRequired` (Map File) và ở mọi biến tương ứng của View — để
  `progress.total - progress.completed` luôn khớp với số của `missingRequired` trên cùng màn hình Map
  File, và để số liệu tiến độ của Map File luôn khớp 1-1 với số liệu tương ứng của View cho cùng một
  Sales Order (khôi phục đúng kỳ vọng khớp nhau của SC-026).
- Change: Đã rà soát và xác nhận `requiredDetails`/`mappedRequired`/`missingRequired`/`pct` ở màn hình
  View (FR-062) hiện đã đúng: chỉ đếm step Required, loại trừ `AUTO_SOURCES`, áp dụng đúng quy tắc
  PO/Template (FR-061) trước khi cộng dồn qua toàn bộ template đã lưu — KHÔNG cần thay đổi các biến này;
  Update này chỉ sửa phía Map File (`progress.total`/`progress.completed`) để khớp đúng logic đã đúng sẵn
  ở View.
- Change: Nhãn hiển thị hiện có ("required steps" ở chú thích progress-bar header card, "Required:
  {completed}/{total}" ở footer Step 2) giữ nguyên không đổi — vì số liệu vẫn chỉ tính riêng step
  Required như trước, không cần đổi chữ.

### Session 2026-07-27 (Update 10) — Nút Download ở màn hình View Sales Order tải xuống file zip thật theo template

- Bối cảnh: Nút **Download** ở màn hình **View Sales Order** (`ViewSalesOrderPage`) hiện chỉ hiển thị
  nhưng **không xử lý tải file thật** (FR-044/Update 4) — hành vi demo/no-op, việc xử lý thật được để
  lại cho một cập nhật sau. Update này bổ sung xử lý thật cho nút Download: tải xuống một file nén
  (zip) đại diện cho một cấu trúc thư mục, tên thư mục gốc đặt động theo dữ liệu Sales Order
  (`SalesId`-`CustomerCode`-`CustomerName`), bên trong chia theo từng template đã lưu của Sales Order
  đó (mỗi template một thư mục con), mỗi thư mục con chứa các file tài liệu thật thuộc đúng template
  đó.
- Change: Nút Download MUST tải xuống một file nén (zip) chứa cấu trúc thư mục — thay thế hoàn toàn
  hành vi demo/no-op hiện tại (FR-044).
- Change: Tên file zip và tên thư mục gốc bên trong file zip MUST được đặt động theo định dạng
  `{SalesId}-{CustomerCode}-{CustomerName}` của Sales Order đang xem (`CustomerCode` = mã khách hàng ở
  cột Customer, `CustomerName` = tên khách hàng ở cột Customer name) — nếu `CustomerCode`/
  `CustomerName` chứa ký tự không hợp lệ cho tên file/thư mục (khoảng trắng, ký tự đặc biệt), hệ thống
  MUST làm sạch (sanitize) các ký tự đó để đảm bảo tên file/thư mục hợp lệ, không gây lỗi khi tải
  xuống hoặc giải nén.
- Change: Bên trong thư mục gốc, hệ thống MUST tạo một thư mục con riêng cho mỗi template đã lưu
  (`TemplateCode` trong `eutr_purchase_attachments`) của Sales Order này — đúng tập template đang hiển
  thị ở toolbar cây template (`templatesData`). Tên mỗi thư mục con MUST là **tên thật** của template
  đó (tra `eutr_templates.Name` theo `TemplateCode`), không dùng mã template thô hay nhãn thứ tự cố
  định ("Template 01"/"Template 02"...).
- Change: Mỗi thư mục con template MUST chỉ chứa các file tài liệu thật có trạng thái **Map status =
  "Mapped"** cho đúng template đó — áp dụng đúng quy tắc xác định Map status theo cặp (PO, Template)
  đã có ở FR-055/FR-056 (PO của tài liệu thuộc đúng template đang xét, và `StepId` của tài liệu khớp
  một node trong chính cây của template đó). Tài liệu ở trạng thái **"No map"** (dù thuộc đúng PO của
  template đó) KHÔNG được đưa vào file zip.
- Change: Nếu một template không có tài liệu "Mapped" nào, thư mục con của template đó vẫn được tạo
  trong file zip nhưng ở trạng thái rỗng (không có file bên trong) — không bỏ qua thư mục đó.
- Change: Nếu toàn bộ Sales Order không có bất kỳ tài liệu "Mapped" nào ở mọi template (bao gồm cả
  trường hợp Sales Order chưa Save PO Mapping/chưa có template nào), nút Download MUST vẫn ở trạng
  thái có thể bấm được (không disable); khi người dùng nhấn, hệ thống MUST hiển thị thông báo rõ ràng
  cho biết không có tài liệu nào để tải, và KHÔNG tải xuống một file zip rỗng.
- Change: Nếu trong cùng một thư mục con template có từ 2 file tài liệu trở lên trùng tên file gốc,
  hệ thống MUST tự động phân biệt tên file (ví dụ thêm hậu tố số thứ tự) khi đóng gói vào zip, để
  tránh file này ghi đè file kia khi người dùng giải nén.
- Change: Thao tác Download KHÔNG được ghi/sửa/xóa bất kỳ bản ghi tài liệu/tham chiếu nào — giữ đúng
  nguyên tắc chỉ đọc (read-only) của toàn bộ màn hình View đã có (FR-042).

### Session 2026-07-27 (Update 9) — Nút Xem (View) tài liệu ở AVAILABLE FILES (Map File)

- Bối cảnh: Mỗi tài liệu ở khu vực **AVAILABLE FILES** (Step 2, Map File) hiện chỉ có nút **Edit**
  (mở popup Edit tài liệu đầy đủ đã dùng lại từ 004-eutr-documents, Update 6) — người dùng muốn xem
  nhanh **nội dung** file (PDF/Word/Excel/ảnh...) ngay tại đây mà không cần mở popup Edit (vốn tập
  trung vào chỉnh sửa Type/Step/Value/Valid dates, không hiển thị nội dung file) hay tải file xuống.
  Màn hình **EUTR Documents** (004-eutr-documents) đã có sẵn đúng popup xem trước nội dung file này
  cho nút View trên lưới tài liệu của màn hình đó (chỉ đọc, hiển thị nội dung file ngay trong popup).
- Change: Mỗi dòng tài liệu ở AVAILABLE FILES MUST hiển thị thêm một nút **View** đặt **kế** (liền
  cạnh) nút Edit hiện có. Khi người dùng nhấn nút View, hệ thống MUST mở đúng popup xem trước nội
  dung file đã có sẵn ở màn hình EUTR Documents cho đúng tài liệu đó — hiển thị nội dung file ngay
  trong popup, không tự động tải xuống, không điều hướng người dùng khỏi Map File.
- Change: Popup View MUST ở chế độ **chỉ đọc hoàn toàn** đối với dữ liệu tài liệu — không hiển thị
  bất kỳ trường Type/Step/Value/Valid dates nào để chỉnh sửa, không có nút Save nào trong popup này;
  chỉ hiển thị nội dung file (và nút Download riêng của popup xem trước đó, nếu popup gốc đã có sẵn
  nút này) cùng nút đóng popup.
- Change: Nút View hoạt động **độc lập** với nút Edit — người dùng có thể mở/đóng View và Edit theo
  bất kỳ thứ tự nào trên cùng một tài liệu hoặc các tài liệu khác nhau; đóng popup View (nút Close
  hoặc click ra ngoài) KHÔNG được ghi/sửa/xóa bất kỳ dữ liệu tài liệu nào, giữ đúng nguyên tắc chỉ đọc
  của thao tác xem.
- Change: Nếu loại file của tài liệu đó không được popup xem trước hỗ trợ hiển thị nội dung (theo
  đúng giới hạn hỗ trợ hiện có của popup này ở 004-eutr-documents), popup MUST hiển thị trạng thái rõ
  ràng cho biết không xem trước được, không gây lỗi trang hay crash màn hình Map File.

### Session 2026-07-27 (Update 7) — Map status/AVAILABLE FILES ở Step 2 phải phân biệt đúng PO và đúng Template

- Bối cảnh: Ở Step 2, mỗi lần chỉ hiển thị cây của **một** template tại một thời điểm (người dùng chọn
  qua toolbar `template-tree-toolbar`, mặc định là template đầu tiên). Tuy nhiên khu vực **AVAILABLE
  FILES** hiện đang gộp chung tài liệu của **toàn bộ** PO đã chọn/lưu ở Step 1 (không lọc theo template
  đang xem), và trạng thái **Map status** cũng như chỉ báo "đã có tài liệu" trên từng node cây hiện
  đang so khớp `StepId` của tài liệu với **toàn bộ** step gộp lại từ **tất cả** template đã lưu (không
  chỉ template đang xem) — trong khi mối liên kết PO ↔ Template đã có sẵn và xác định rõ ràng qua
  `eutr_purchase_attachments` (mỗi `PurchId` gắn đúng 1 `TemplateCode`). Vì các template khác nhau có
  thể dùng chung `StepId`/tên Step (cùng lấy từ bảng `eutr_steps`, ví dụ nhiều template cùng có bước
  "Invoice"), cách so khớp hiện tại có thể đánh dấu **sai**: một tài liệu thuộc PO của template A bị
  hiển thị nhầm là "Mapped" vào step của template B (hoặc ngược lại) dù hai PO/template đó không liên
  quan tới nhau, và một node cây của template A có thể hiển thị "đã có tài liệu" bằng một tài liệu thực
  ra thuộc về PO của template B.
- Change: Khu vực **AVAILABLE FILES** MUST chỉ hiển thị (các) tài liệu thuộc về (các) PO có
  `TemplateCode` (tra theo `eutr_purchase_attachments`, khớp `PurchId` = giá trị PO/`RefValue` của tài
  liệu đó) trùng đúng với **template đang được chọn xem** ở toolbar cây (`selectedTemplateCode`) —
  không còn gộp chung tài liệu của toàn bộ PO đã chọn ở Step 1 bất kể tài liệu đó thuộc template nào.
  Khi người dùng click chọn xem một template khác ở toolbar (hành vi tải lại `templatesData` của
  FR-047/FR-048 vẫn giữ nguyên), danh sách AVAILABLE FILES MUST cập nhật lại ngay để chỉ còn hiển thị
  đúng tài liệu của (các) PO thuộc template mới được chọn.
- Change: Trạng thái **Map status** ("Mapped"/"No map") của mỗi tài liệu ở AVAILABLE FILES, và chỉ báo
  "đã có tài liệu" trên từng node của cây template, MUST được xác định dựa trên **cả hai** điều kiện
  đồng thời — không chỉ riêng khớp Step như hiện tại:
  1. PO của tài liệu đó (`RefValue`/`poCode`) phải thuộc về đúng template đang xét (tra theo
     `eutr_purchase_attachments`: `PurchId` của PO đó gắn với `TemplateCode` của template này).
  2. `StepId` của bản ghi `eutr_references` gắn với tài liệu đó phải khớp với `StepId` của một node
     **trong chính cây của template đang xét** (không tính node thuộc cây của các template khác, kể cả
     khi `StepId`/tên Step trùng nhau giữa các template).
  - Nếu tài liệu không thỏa điều kiện (1) — PO của tài liệu thuộc một template khác — tài liệu đó MUST
    hiển thị **"No map"** trong ngữ cảnh template đang xét (bất kể `StepId` của nó có trùng với một
    node nào đó của template này hay không), và KHÔNG được tính vào chỉ báo "đã có tài liệu" hay vào
    tiến độ (progress) của node cây đó.
- Change: Số liệu tiến độ (**Required/completed**, tỷ lệ %, danh sách step còn thiếu) hiển thị ở Step 2
  và ở header card vẫn tiếp tục là tổng hợp trên **toàn bộ** template đã lưu của Sales Order (giữ
  nguyên phạm vi tổng hợp hiện có, không thu hẹp lại chỉ còn template đang xem) — nhưng với mỗi template
  trong phép tổng hợp đó, việc xác định "step này đã có tài liệu hay chưa" MUST áp dụng đúng quy tắc
  phân biệt PO/Template ở trên (chỉ tính tài liệu thuộc đúng PO của template đó), rồi mới cộng dồn kết
  quả của từng template lại thành tổng chung — không còn dùng chung một tập hợp "mọi tài liệu khớp mọi
  step của mọi template" như cách tính hiện tại.
- Change: Việc này không thay đổi cơ chế tải lại `templatesData` khi click chọn template ở toolbar
  (FR-047/FR-048 giữ nguyên) — chỉ bổ sung thêm hành vi lọc AVAILABLE FILES và tính lại Map status/tiến
  độ đúng theo PO/Template khi người dùng chuyển qua xem một template khác.

### Session 2026-07-27 (Update 8) — Màn hình View Sales Order: Toolbar Template Tree chọn xem 1 template (giống Map File) + Map status theo đúng PO/Template

- Bối cảnh: Toolbar cây template (`data-marker="template-tree-toolbar"`) ở màn hình **View Sales
  Order** (`ViewSalesOrderPage`) hiện đang hiển thị các chip **tĩnh/demo** ("template code1",
  "template code2", "All" — không lấy từ `templatesData`) và **không gắn bất kỳ xử lý click nào**.
  Bên dưới, **Template Checklist** hiện hiển thị nối tiếp **toàn bộ** cây của **mọi** template đã lưu
  cùng một lúc, không có cơ chế chọn xem riêng từng template. Trạng thái "đã có tài liệu"/"còn thiếu"
  của mỗi step hiện được xác định bằng cách so khớp **tên Step** của tài liệu với mọi node của **mọi**
  template gộp chung (không phân biệt tài liệu đó thuộc PO của template nào) — đây chính là kiểu lỗi
  đã được phát hiện và sửa cho Map File ở Update 7 (một tài liệu thuộc template A có thể bị tính nhầm
  là "đã có tài liệu" cho node của template B nếu hai template dùng chung tên Step/StepId). Ở màn hình
  **Map File**, từ Update 7, Step 2 chỉ hiển thị **đúng 1 cây tại 1 thời điểm** — cây của template đang
  được chọn xem qua toolbar, mặc định là template đầu tiên khi mở trang — và việc xác định "đã có tài
  liệu" luôn xét đúng theo cặp (PO, Template) của chính tài liệu đó. Update này áp dụng lại đúng hai
  hành vi này cho màn hình View.
- Change: Toolbar `data-marker="template-tree-toolbar"` ở màn hình View MUST hiển thị đầy đủ (các)
  template đã lưu của Sales Order này, mỗi template một chip riêng biệt lấy từ `templatesData` (nhãn
  hiển thị = tên template) — thay thế hoàn toàn các chip tĩnh/demo hiện có, theo đúng cách hiển thị đã
  áp dụng ở toolbar Map File.
- Change: Khi người dùng **click vào một chip template** ở toolbar này, **Template Checklist** MUST
  chuyển sang chỉ hiển thị **đúng cây của template đó** — không còn hiển thị nối tiếp cây của mọi
  template cùng lúc như hiện tại. Chip của template đang được chọn xem MUST có trạng thái hiển thị
  khác biệt (được chọn) so với các chip còn lại, theo đúng kiểu hiển thị đã dùng ở toolbar Map File.
- Change: Khi mở màn hình lần đầu, hoặc khi lựa chọn template hiện tại không còn tồn tại trong
  `templatesData` (ví dụ sau khi tải lại trang), Template Checklist MUST tự động hiển thị **đúng cây
  của template đầu tiên** trong `templatesData` — theo đúng cơ chế mặc định đã áp dụng ở Map File
  Step 2.
- Change: Trạng thái "đã có tài liệu"/"còn thiếu" của mỗi step trong Template Checklist (và các số
  liệu Validation Summary liên quan) MUST được xác định dựa trên **cả hai** điều kiện đồng thời — theo
  đúng quy tắc PO/Template đã áp dụng cho Map status ở Map File Step 2 (Update 7) — thay thế hoàn toàn
  cách so khớp hiện tại (chỉ so tên Step, gộp chung tài liệu của mọi PO/mọi template):
  1. PO của tài liệu đó (tra theo `eutr_purchase_attachments`: `PurchId` gắn với `TemplateCode`) phải
     thuộc về đúng template đang xét.
  2. Step của tài liệu đó khớp với một node **trong chính cây của template đang xét** (không tính
     node thuộc cây của các template khác, kể cả khi tên Step/`StepId` trùng nhau giữa các template).
  - Nếu tài liệu không thỏa điều kiện (1), step đang xét trong template hiện tại KHÔNG được tính là
    "đã có tài liệu" nhờ tài liệu đó, bất kể tên Step/`StepId` có trùng hay không.
- Change: Số liệu tiến độ tổng hợp (Required/completed, tỷ lệ %, danh sách step còn thiếu) hiển thị ở
  header và ở **Validation Summary** vẫn tiếp tục cộng dồn trên **toàn bộ** template đã lưu của Sales
  Order (giữ nguyên phạm vi tổng hợp hiện có, không thu hẹp chỉ còn template đang xem) — nhưng với mỗi
  template trong phép cộng dồn đó, việc xác định "step này đã có tài liệu hay chưa" MUST áp dụng đúng
  quy tắc PO/Template ở trên trước khi cộng dồn kết quả của từng template lại thành tổng chung — không
  còn dùng chung một tập hợp "mọi tài liệu khớp mọi step của mọi template" như cách tính hiện tại.
- Change: Vì màn hình View vẫn ở chế độ chỉ đọc (FR-042), việc click chọn xem một template khác ở
  toolbar chỉ thay đổi template nào đang được hiển thị trên giao diện — KHÔNG phát sinh việc ghi/sửa
  bất kỳ bản ghi nào, và KHÔNG bắt buộc phải tải lại (refetch) dữ liệu tài liệu/PO từ nguồn thật mỗi
  lần click (khác với Map File, nơi việc tải lại khi click nhằm mục đích làm mới trạng thái map trong
  lúc người dùng có thể đang chỉnh sửa dữ liệu ở nơi khác) — dữ liệu đã tải khi mở màn hình là đủ để
  chuyển đổi hiển thị giữa các template.

### Session 2026-07-27 (Update 6) — Nút Upload và Edit ở Step 2 (AVAILABLE FILES) dùng lại chức năng Add/Edit của 004-eutr-documents

- Change: Nút **Upload** (biểu tượng UploadIcon) ở Step 2 của Map File hiện chỉ tạo một bản ghi
  tài liệu **giả cục bộ** trên giao diện (không gọi API, không lưu file thật — FR-029 phiên bản cũ).
  Update này thay thế hoàn toàn hành vi đó: khi nhấn Upload, hệ thống MUST mở **đúng popup Add tài
  liệu** đã có sẵn ở màn hình **EUTR Documents** (004-eutr-documents, User Story 2/FR-008 đến
  FR-025 của đặc tả đó) — đầy đủ các trường Type, Step, Value, Valid from/Valid to và luồng chọn/tải
  file thật, áp dụng đúng các quy tắc đã định nghĩa ở 004 (định dạng/kích thước file, số lượng chip
  theo Type, khớp Prefix cho Type "PO", ghi bản ghi `eutr_documents`/`eutr_references` thật khi tải
  lên thành công). Đây là popup Add tài liệu **đầy đủ, không giới hạn** Type/Value theo PO hay Step
  đang chọn trong cây template của Map File — người dùng tự chọn Type/Step/Value như khi thao tác từ
  màn hình EUTR Documents gốc.
- Change: Nút **Edit** trên từng tài liệu ở khu vực **AVAILABLE FILES** hiện đang mở một dialog map
  cục bộ riêng của Map File (gán Source/PO/Valid dates cho tài liệu đó, chỉ cập nhật state trên giao
  diện — FR-030 phiên bản cũ, không gọi API). Update này thay thế **hoàn toàn** dialog đó bằng
  **đúng popup Edit tài liệu** đã có sẵn ở 004-eutr-documents (User Story 3/FR-026 đến FR-034 và
  Update 22/FR-051 đến FR-055 của đặc tả đó): Type bị khóa (không sửa được), Step vẫn chỉnh sửa được
  (lọc theo Assign Steps của Type đó), Value hiển thị dạng chip — chip chỉ đọc nếu Type = "PO", chip
  chỉnh sửa được (thêm/xóa) nếu Type khác "PO", Valid from/Valid to vẫn chỉnh sửa được. Nhấn **Save**
  trên popup này MUST gọi đúng luồng cập nhật thật đã áp dụng ở 004 (cập nhật `eutr_documents` và
  đồng bộ bản ghi `eutr_references` theo Step/Value chip hiện tại) — không còn cơ chế gán Source/PO
  cục bộ nào khác cho tài liệu.
- Change: Sau khi Upload hoặc Save (Edit) thành công, khu vực **AVAILABLE FILES** và trạng thái **Map
  status** của (các) tài liệu liên quan trong cây template hiện tại MUST được cập nhật lại đúng theo
  dữ liệu thật mới nhất (tài liệu vừa tải lên/vừa sửa xuất hiện/đổi trạng thái ngay, không cần tải lại
  toàn bộ trang) — theo đúng nguyên tắc phản ánh dữ liệu thật đã áp dụng cho Map status/File type/PO
  value ở Update 5 (FR-049 đến FR-051).
- Change: Vì cả Upload và Edit ở Step 2 nay đều ghi dữ liệu thật, hai dòng giả định/khẳng định "Upload
  và Save ở Step 2 tiếp tục demo/no-op" ở các bản cập nhật trước (nhắc tới trong Update 2 và phần
  Assumptions) không còn áp dụng — được thay thế bởi Update 6 này.

### Session 2026-07-27 (Update 5) — Toolbar Template Tree (làm mới template) và AVAILABLE FILES (Map status/File type/PO value động)

- Change: Khu vực toolbar cây template ở Step 2 của Map File (`data-marker="template-tree-toolbar"`)
  MUST tiếp tục hiển thị đầy đủ (các) template đã chọn/lưu cho Sales Order này (dùng lại danh sách
  `templatesData` hiện có, mỗi template một chip riêng biệt) — hành vi hiển thị hiện tại được giữ
  nguyên, không thay đổi.
- Change: Bổ sung tương tác mới ở toolbar này — khi người dùng **click vào một template**, hệ thống
  MUST tải lại (refetch) toàn bộ danh sách `templatesData` (cây thư mục và chi tiết của mọi template
  đang gắn với Sales Order này) từ nguồn dữ liệu thật, theo đúng cơ chế xây dựng `templatesData` đã
  có (FR-023/FR-024) — không chỉ hiển thị lại dữ liệu đang có sẵn trên UI một cách tĩnh. Đây là cách
  để người dùng chủ động làm mới trạng thái map mà không cần tải lại (refresh) cả trang. Vì Step 2
  luôn hiển thị đồng thời tất cả các cây template của Sales Order đó, hành vi tải lại áp dụng chung
  cho toàn bộ `templatesData` bất kể người dùng click vào chip template cụ thể nào.
- Change: Ba nhãn hiện đang hiển thị **tĩnh** (giá trị chữ cố định "Map status"/"File type"/"PO
  value", không đổi theo dữ liệu) ở mỗi dòng tài liệu trong khu vực **AVAILABLE FILES** MUST được
  thay bằng giá trị **động**, dựa trên bảng `eutr_references`:
  - **Map status**: so sánh `StepId` của bản ghi `eutr_references` gắn với tài liệu đó (trong ngữ
    cảnh PO đang xét) với `StepId` của các node trong (các) cây template hiện tại
    (`templatesData`). Nếu khớp một node bất kỳ, hiển thị **"Mapped"**; nếu không khớp node nào,
    hiển thị **"No map"**.
  - **File type**: lấy từ cột `RefType` của bản ghi `eutr_references` đó — hiển thị **tên loại**
    (tra cứu qua bảng `eutr_reference_types` theo `RefType`), theo đúng mẫu hiển thị tên thay vì mã/id
    thô đã áp dụng cho các cột loại tham chiếu khác trong hệ thống.
  - **PO value**: lấy trực tiếp từ cột `RefValue` của bản ghi `eutr_references` đó (ví dụ
    `PO00014347`), hiển thị nguyên văn giá trị này.
- Change: Nếu bản ghi `eutr_references` của một tài liệu không có giá trị `RefType` hoặc `RefValue`
  (null), nhãn File type/PO value tương ứng MUST hiển thị trạng thái trống rõ ràng, không lỗi.

### Session 2026-07-20 (Update 4) — Màn hình View Sales Order (ViewSalesOrderPage) lấy dữ liệu thật, chỉ đọc

- Change: Màn hình **View Sales Order** (`ViewSalesOrderPage`, mở từ nút "View" ở Overview, route
  `/eutr/sales-orders/:salesId/view`) hiện đang dùng toàn bộ dữ liệu mock (`MOCK_SALES_ORDERS`,
  `MOCK_SO_POS`, `MOCK_SO_PO_MAPPINGS`, `MOCK_AVAILABLE_FILES`, `MOCK_FILE_MAPPINGS`,
  `EUTR_TEMPLATE_DETAILS_MAP`, `EUTR_TEMPLATES`). Update này chuyển màn hình sang dữ liệu thật, dùng
  lại đúng các nguồn dữ liệu/cơ chế đã áp dụng cho `MapFilePage` ở Update 2/3, nhưng ở chế độ **chỉ
  xem (read-only)** — không có bất kỳ chỉnh sửa nào:
  - Kiểm tra Sales Order có tồn tại hay không (`if (!so)`) MUST dùng cùng nguồn tham chiếu dùng chung
    reference type = 11 theo Sales ID trên URL (giống Map File FR-014), không dùng `MOCK_SALES_ORDERS`.
  - Header (Sales ID, Customer, Customer name) MUST lấy dữ liệu thật từ cùng bản ghi reference type =
    11 vừa tra được.
  - Danh sách **Purchase Orders đã chọn** MUST lấy từ các bản ghi đã lưu trong
    `eutr_purchase_attachments` của Sales ID này (không phải toàn bộ PO khả dụng như Step 1 Map File,
    chỉ những PO đã Save), tra cứu thêm thông tin hiển thị (tên, order account, số lượng...) từ nguồn
    tham chiếu dùng chung reference type = 16 — không dùng `MOCK_SO_POS`/`MOCK_SO_PO_MAPPINGS`. Các
    cột demo cũ (Vendor/Vendor Name/Rate/Material) không còn nguồn dữ liệu thật tương ứng nên được
    thay bằng các trường thật sẵn có (PO, Name, Order account, Qty) — đúng bộ cột đã dùng ở Step 1
    Map File.
  - **Template Checklist** MUST được xây dựng dựa trên (các) `TemplateCode` lấy từ các bản ghi
    `eutr_purchase_attachments` của Sales ID này, theo đúng cơ chế xây cây đã dùng ở Step 2 Map File
    (FR-023/FR-024) — không dùng `EUTR_TEMPLATE_DETAILS_MAP`/`so.templateId` mock.
  - Trạng thái từng step trong Template Checklist (đã có tài liệu / còn thiếu) MUST dựa trên tài liệu
    thật lấy từ `eutr_references` cho (các) PO đã lưu của Sales Order này, theo đúng cơ chế đã dùng ở
    Map File Step 2 (FR-026/FR-027) — không dùng `MOCK_AVAILABLE_FILES`/`MOCK_FILE_MAPPINGS`.
  - Toàn bộ màn hình View MUST ở chế độ **chỉ đọc**: không có chức năng tick chọn PO, map/unmap tài
    liệu, hay upload tài liệu mới (khác với Map File). Người dùng chỉ có thể mở rộng/thu gọn cây để
    xem, không thay đổi dữ liệu.
  - Nút **Edit / Map File** MUST điều hướng người dùng sang màn hình **Map File**
    (`/eutr/sales-orders/:salesId/map-file`) của đúng Sales Order đang xem — đây là nơi duy nhất để
    chỉnh sửa PO/mapping tài liệu.
  - Nút **Download** tiếp tục hiển thị nhưng **tạm thời KHÔNG xử lý tải file thật** — giữ hành vi
    demo/no-op, việc xử lý thật để lại cho một cập nhật sau (ngoài phạm vi Update 4).
  - Phần **Validation Summary** MUST tính toán dựa trên dữ liệu step thật: liệt kê (các) Purchase
    Order đã chọn (từ `eutr_purchase_attachments`), số step Required đã đủ tài liệu, và số/step
    Required còn thiếu tài liệu (kèm tên step thiếu) — không dùng dữ liệu demo. Điều kiện "File không
    hết hạn" ở bản mock trước đây tạm thời không áp dụng được vì dữ liệu tài liệu thật hiện chưa có
    thông tin ngày hết hạn.

### Session 2026-07-16 (Update 1) — Cột Template lấy dữ liệu thật

- Change: Cột **Template** trên màn hình **EUTR Sales Orders** (SalesOrderOverviewPage) KHÔNG còn
  hiển thị giá trị demo cố định (bỏ FR-007 phiên bản cũ). Cột này MUST lấy dữ liệu thật từ bảng
  `eutr_purchase_attachments`, tra cứu các bản ghi có `SalesId` khớp với Sales ID của dòng đang
  hiển thị, sau đó hiển thị tên template tương ứng (tra cứu qua `TemplateCode` → bảng `eutr_templates`).
- Change: Một Sales ID có thể gắn với nhiều bản ghi trong `eutr_purchase_attachments` (mỗi bản ghi
  ứng với một `PurchId`/dòng mua hàng khác nhau), và các bản ghi đó có thể tham chiếu tới các
  `TemplateCode` khác nhau. Khi đó, cột Template MUST hiển thị **đầy đủ tất cả** các template gắn
  với Sales ID đó (mỗi template duy nhất chỉ hiển thị 1 lần, không lặp lại dù có nhiều `PurchId`
  cùng dùng chung 1 template).
- Cột **Progress** không thuộc phạm vi thay đổi này — vẫn tiếp tục hiển thị giá trị demo cố định
  như hiện tại (FR-008 giữ nguyên).

### Session 2026-07-20 (Update 3) — Step 1: cho phép chọn thêm PO chưa gắn Template; nút Back về Sales Orders

- Change: Ở **Step 1** của Map File, các PO **chưa có bản ghi nào trong `eutr_purchase_attachments`**
  (chưa từng được Save PO Mapping trước đó cho Sales Order này) vẫn PHẢI hiển thị checkbox ở trạng
  thái **có thể tick chọn** (không bị vô hiệu hóa), miễn là PO đó có sẵn giá trị template từ D365
  (trường `eutrTemplate` trả về từ nguồn tham chiếu reference type = 16 dùng để hiển thị danh sách PO
  ở Step 1) — nghĩa là người dùng có thể tick chọn **thêm** các PO này bên cạnh các PO đã được tick
  sẵn từ lần Save trước, không bị giới hạn chỉ được chọn lại đúng các PO cũ.
  - PO chỉ thực sự bị vô hiệu hóa (không cho tick) khi bản thân D365 không trả về giá trị template
    nào cho PO đó (`eutrTemplate` rỗng) — trường hợp này giữ nguyên theo FR-022 hiện có, vì
    `TemplateCode` là trường bắt buộc (`NOT NULL`) của `eutr_purchase_attachments`.
  - Khi nhấn **Save PO Mapping**, các PO mới được tick chọn thêm (trước đó chưa có bản ghi) MUST được
    lưu (ghi thêm bản ghi mới) vào `eutr_purchase_attachments` cùng với các PO đã chọn từ trước, với
    `TemplateCode` lấy đúng từ giá trị `eutrTemplate` trả về bởi nguồn dữ liệu PO ở Step 1 (reference
    type = 16) — người dùng không tự nhập/chọn Template thủ công cho các PO này, giữ đúng cơ chế lấy
    TemplateCode đã áp dụng từ Update 2 (FR-020).
  - Hành vi lưu này vẫn tuân theo nguyên tắc "đồng bộ đúng lựa chọn hiện tại trên UI" đã có ở FR-021:
    sau khi Save, tập bản ghi trong `eutr_purchase_attachments` của Sales ID này phải khớp chính xác
    với toàn bộ các PO đang được tick (bao gồm cả PO cũ đã chọn từ trước và PO mới chọn thêm ở lần
    này); PO nào đang tick nhưng bị bỏ tick thì bản ghi tương ứng bị xóa.
- Change: Nút **Back** ở đầu màn hình Map File hiện chưa có hành vi (không gắn xử lý khi nhấn). Update
  này bổ sung: nhấn nút Back MUST điều hướng người dùng quay lại màn hình **EUTR Sales Orders**
  (Overview, route `/eutr/sales-orders`) — cùng đích đến với liên kết breadcrumb đã có sẵn trên màn
  hình này.

### Session 2026-07-16 (Update 2) — Màn hình Map File (MapFilePage) lấy dữ liệu thật

- Change: Màn hình **Map File** (`MapFilePage`, mở từ nút "Map File" ở Overview) hiện đang dùng toàn
  bộ dữ liệu mock (`MOCK_SALES_ORDERS`, `MOCK_SO_POS`, `MOCK_SO_PO_MAPPINGS`, `MOCK_AVAILABLE_FILES`,
  `MOCK_FILE_MAPPINGS`, `EUTR_TEMPLATE_DETAILS_MAP`). Update này chuyển các phần sau sang dữ liệu
  thật, các phần còn lại (Upload file mới, Save mapping file ở Step 2) tạm thời vẫn chỉ hiển thị,
  chưa xử lý:
  - Kiểm tra Sales Order có tồn tại hay không (`if (!so)`) và thông tin ở **Header card** (Sales ID,
    Customer, Customer name) MUST lấy từ cùng nguồn tham chiếu dùng chung mà **SalesOrderOverviewPage**
    (Overview) đang dùng (reference type = 11) — tra theo Sales ID trên URL, không dùng mảng mock
    `MOCK_SALES_ORDERS` nữa.
  - Danh sách PO ở **Step 1** MUST lấy từ nguồn tham chiếu dùng chung với reference type = 16, lọc
    theo điều kiện `InterCompanyOriginalSalesId` = Sales ID hiện tại — không dùng `MOCK_SO_POS`.
  - Việc chọn PO ở Step 1 ("PO mapping") do người dùng quyết định (tick chọn PO nào áp dụng), khi
    nhấn **Save PO Mapping** MUST lưu (ghi mới/cập nhật) vào bảng `eutr_purchase_attachments`
    (`SalesId`, `PurchId`, `TemplateCode`) — đây là hành động **ghi** đầu tiên vào bảng này; trước
    Update 2, bảng `eutr_purchase_attachments` chỉ được đọc (xem Update 1), chưa có luồng ghi nào.
  - Nếu Sales ID đã có sẵn bản ghi trong `eutr_purchase_attachments` (đã Save PO Mapping từ trước),
    Step 1 MUST tự động tick chọn sẵn (default-checked) đúng các PO đó khi mở lại màn hình — không
    dùng `MOCK_SO_PO_MAPPINGS`.
  - Cây thư mục ở **Step 2** MUST được xây dựng dựa trên (các) `TemplateCode` lấy ra từ
    `eutr_purchase_attachments` của Sales ID này (sau khi đã Save ở Step 1) — không dùng
    `so.templateId`/`EUTR_TEMPLATE_DETAILS_MAP` cố định theo Sales Order mock.
  - Danh sách **AVAILABLE FILES** ở Step 2 MUST lấy dữ liệu tài liệu thật từ bảng `eutr_references`
    (lọc theo PO mà người dùng đã chọn/lưu ở Step 1), hiển thị đúng Step mà tài liệu đó đã được gắn
    trong cây — không dùng `MOCK_AVAILABLE_FILES`/`MOCK_FILE_MAPPINGS`.
  - Chức năng **Upload** (upload file mới) và **Save** (lưu mapping file↔step) ở Step 2 tạm thời
    KHÔNG xử lý — vẫn giữ nguyên giao diện hiển thị hiện tại (demo/no-op), việc xử lý thật để lại cho
    một cập nhật sau.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Xem danh sách EUTR Sales Orders (Priority: P1)

Người dùng vào mục **EUTR > EUTR Sales Orders** từ thanh điều hướng và thấy một bảng liệt kê các
sales order lấy từ hệ thống ERP (D365) thông qua nguồn dữ liệu tham chiếu dùng chung đã có sẵn
trong hệ thống (reference type 11). Bảng hiển thị các cột: **Sales ID**, **Customer**, **Customer
name**, **Delivery date**, cột **Template** hiển thị (các) template thật gắn với Sales ID đó (tra
cứu từ bảng `eutr_purchase_attachments`), và cột **Progress** vẫn hiển thị giá trị mẫu cố định
(demo, chưa gắn dữ liệu/logic thật) cho mọi dòng.

**Why this priority**: Đây là giá trị cốt lõi và duy nhất của tính năng ở giai đoạn này — cho phép
người dùng xem được danh sách sales order ngay khi mở màn hình; không có giá trị nào khác nếu thiếu
bước này.

**Independent Test**: Mở màn hình EUTR Sales Orders, xác nhận bảng hiển thị đúng các cột Sales ID,
Customer, Customer name, Delivery date với dữ liệu thật lấy từ nguồn tham chiếu reftype = 11; cột
Template hiển thị đúng (các) template thật tra cứu từ `eutr_purchase_attachments` theo Sales ID
(bao gồm trường hợp một Sales ID có nhiều template); cột Progress vẫn hiển thị giá trị demo cố định
giống nhau ở mọi dòng.

**Acceptance Scenarios**:

1. **Given** đang ở thanh điều hướng, **When** chọn "EUTR Sales Orders", **Then** thấy bảng liệt kê
   sales order với đầy đủ 6 cột (Sales ID, Customer, Customer name, Delivery date, Template,
   Progress).
2. **Given** một sales order có đầy đủ dữ liệu Delivery date từ nguồn tham chiếu, **When** bảng
   hiển thị dòng đó, **Then** cột Delivery date hiển thị đúng ngày giao hàng.
3. **Given** một sales order không có Delivery date, **When** bảng hiển thị dòng đó, **Then** cột
   Delivery date hiển thị trạng thái trống rõ ràng (không lỗi, không để trắng gây hiểu nhầm).
4. **Given** hệ thống chưa từng đăng ký reftype = 11 trong nguồn tham chiếu, **When** Feature này
   được triển khai, **Then** nguồn tham chiếu MUST trả về đúng dữ liệu Sales ID/Customer/Customer
   name/Delivery date cho reftype = 11 (không còn trả về rỗng như trước).
5. **Given** một Sales ID chỉ có đúng 1 bản ghi trong `eutr_purchase_attachments`, **When** bảng
   hiển thị dòng đó, **Then** cột Template hiển thị đúng 1 tên template tương ứng.
6. **Given** một Sales ID có nhiều bản ghi trong `eutr_purchase_attachments` với nhiều `TemplateCode`
   khác nhau (nhiều `PurchId` khác nhau), **When** bảng hiển thị dòng đó, **Then** cột Template
   MUST hiển thị đầy đủ tất cả các template khác nhau đó cho cùng 1 dòng (không chỉ 1 giá trị).
7. **Given** một Sales ID chưa có bản ghi nào trong `eutr_purchase_attachments`, **When** bảng hiển
   thị dòng đó, **Then** cột Template hiển thị trạng thái trống rõ ràng (không lỗi, không hiển thị
   dữ liệu demo/giả).

---

### User Story 2 - Tìm kiếm sales order theo Sales ID hoặc Customer (Priority: P2)

Người dùng nhập từ khóa vào ô tìm kiếm phía trên bảng để lọc nhanh sales order theo Sales ID hoặc
theo Customer, theo đúng kiểu tìm kiếm ("chứa") đã dùng ở các ô tìm kiếm tham chiếu khác trong hệ
thống.

**Why this priority**: Giá trị bổ sung — giúp người dùng tìm nhanh một sales order cụ thể khi danh
sách dài, nhưng không phải điều kiện tối thiểu để tính năng có giá trị (User Story 1 vẫn dùng được
độc lập nếu thiếu tìm kiếm).

**Independent Test**: Nhập một Sales ID hoặc mã/tên Customer đã biết vào ô tìm kiếm, xác nhận bảng
chỉ còn hiển thị các dòng khớp; xóa từ khóa, xác nhận bảng quay lại hiển thị toàn bộ danh sách mặc
định.

**Acceptance Scenarios**:

1. **Given** danh sách đang hiển thị đầy đủ, **When** nhập một Sales ID hợp lệ vào ô tìm kiếm,
   **Then** bảng chỉ hiển thị (các) dòng có Sales ID khớp.
2. **Given** từ khóa tìm kiếm không khớp sales order nào, **When** tìm kiếm, **Then** bảng hiển thị
   trạng thái trống ("No data"), không phải lỗi.
3. **Given** đã nhập từ khóa tìm kiếm, **When** xóa hết từ khóa, **Then** bảng tải lại danh sách mặc
   định (không lọc).

---

### User Story 3 - Chuyển trang khi danh sách dài (Priority: P3)

Người dùng chuyển qua các trang khi tổng số sales order vượt quá số dòng hiển thị trên một trang.

**Why this priority**: Cải thiện khả năng sử dụng cho danh sách lớn nhưng không ảnh hưởng tới giá
trị cốt lõi của việc xem/tìm sales order.

**Independent Test**: Với danh sách có nhiều hơn một trang dữ liệu, nhấn chuyển trang và xác nhận
bảng hiển thị đúng nhóm dữ liệu tiếp theo.

**Acceptance Scenarios**:

1. **Given** tổng số sales order vượt quá kích thước một trang, **When** người dùng chuyển sang
   trang kế tiếp, **Then** bảng hiển thị đúng các dòng của trang đó.

---

### User Story 4 - Chọn Purchase Order và xem hồ sơ tài liệu cho Sales Order (Map File) (Priority: P2)

Từ màn hình EUTR Sales Orders, người dùng nhấn "Map File" trên một dòng để mở màn hình Map File của
Sales Order đó. Màn hình hiển thị đúng thông tin Sales Order (Sales ID, Customer, Customer name)
khớp với dữ liệu đã thấy ở Overview. Ở **Step 1**, người dùng thấy danh sách Purchase Order (PO)
thật liên quan tới Sales Order đó (lấy từ D365 theo điều kiện PO có `InterCompanyOriginalSalesId`
khớp Sales ID này), tick chọn (các) PO áp dụng cho hồ sơ EUTR rồi nhấn **Save PO Mapping** để lưu lại
lựa chọn; nếu Sales Order đã từng được lưu PO trước đó, các PO đó tự động được tick sẵn khi mở lại, và
người dùng vẫn có thể tick chọn thêm các PO khác chưa từng được lưu (miễn PO đó có sẵn template từ
D365) trước khi Save lại. Người dùng cũng có thể nhấn nút **Back** để quay lại màn hình EUTR Sales
Orders bất cứ lúc nào. Ở
**Step 2**, người dùng thấy cây thư mục của (các) template gắn với PO đã lưu, cùng danh sách tài
liệu (AVAILABLE FILES) đã có sẵn cho các PO đó, mỗi tài liệu hiển thị đúng vị trí (step) trong cây mà
nó thuộc về. Nút **Upload** (UploadIcon) mở đúng popup Add tài liệu đã dùng ở màn hình EUTR Documents
(004-eutr-documents), cho phép người dùng chọn Type/Step/Value và tải file thật lên, ghi bản ghi tài
liệu/tham chiếu thật; nút **Edit** trên từng tài liệu mở đúng popup Edit tài liệu của 004-eutr-documents
cho tài liệu đó (Type khóa, Step/Value chip/Valid dates chỉnh sửa theo đúng quy tắc của 004), Save trên
popup này cập nhật dữ liệu thật. Sau khi Upload hoặc Save thành công, AVAILABLE FILES và Map status của
cây template MUST cập nhật ngay theo dữ liệu mới. Toolbar cây template hiển thị đầy đủ các template đã
chọn; click vào một template sẽ tải lại danh sách template mới nhất từ dữ liệu thật, đồng thời chuyển
khu vực AVAILABLE FILES sang chỉ hiển thị (các) tài liệu của (các) PO thuộc đúng template vừa chọn (tra
theo `eutr_purchase_attachments`), không còn gộp chung tài liệu của mọi PO đã chọn bất kể template. Mỗi
tài liệu ở AVAILABLE FILES hiển thị Map status ("Mapped"/"No map"), File type và PO value lấy động từ
bảng `eutr_references`; Map status MUST xác nhận đúng cả hai điều kiện — PO của tài liệu thuộc về đúng
template đang xem, và `StepId` của tài liệu khớp một node trong chính cây của template đó — để không
còn nhầm lẫn với step của một template khác dùng chung `StepId`/tên Step. Bên cạnh nút Edit, mỗi tài
liệu còn có nút **View** để mở đúng popup xem trước nội dung file đã có sẵn ở màn hình EUTR Documents
(004-eutr-documents) cho tài liệu đó — chỉ đọc, hiển thị nội dung file (PDF/Word/Excel/ảnh...) ngay
trong popup, không tải xuống tự động, không điều hướng khỏi Map File, và không ảnh hưởng gì tới nút
Edit hay dữ liệu tài liệu.

**Why this priority**: Đây là hành động nghiệp vụ tiếp theo, ngay sau khi xem được danh sách sales
order (User Story 1) — cho phép người dùng thực sự gắn PO và xem hồ sơ tài liệu áp dụng cho từng
Sales Order; phụ thuộc vào việc điều hướng từ Overview (User Story 1) nên xếp ưu tiên ngay sau đó,
trước các cải tiến khả dụng như tìm kiếm/phân trang (User Story 2/3).

**Independent Test**: Mở Map File cho một Sales Order hợp lệ đã có sẵn PO/template trong
`eutr_purchase_attachments`, xác nhận header hiển thị đúng dữ liệu thật, Step 1 hiển thị đúng các PO
lấy từ D365 với (các) PO đã lưu trước được tick sẵn, Step 2 hiển thị đúng cây theo `TemplateCode` đã
lưu và danh sách tài liệu thật lấy từ `eutr_references` cho các PO đó, đúng vị trí step. Sau đó tick
chọn thêm một PO khác chưa từng được lưu (còn có template từ D365) và Save, xác nhận
`eutr_purchase_attachments` được cập nhật để bao gồm cả PO mới chọn thêm lẫn các PO đã chọn trước đó,
và khi tải lại trang, toàn bộ lựa chọn mới vẫn được giữ. Ở Step 2, nhấn nút Upload, hoàn tất popup Add
tài liệu với một file hợp lệ, xác nhận tài liệu mới được lưu thật và xuất hiện trong AVAILABLE FILES;
sau đó nhấn Edit trên một tài liệu bất kỳ, đổi Step/Value/Valid dates và Save, xác nhận thay đổi được
lưu thật và phản ánh đúng ngay trên giao diện. Cuối cùng nhấn nút Back, xác nhận điều hướng về đúng
màn hình EUTR Sales Orders.

**Acceptance Scenarios**:

1. **Given** Sales ID hợp lệ tồn tại ở nguồn tham chiếu type = 11, **When** mở Map File, **Then**
   header hiển thị đúng Sales ID/Customer/Customer name khớp với dữ liệu ở Overview.
2. **Given** Sales ID không tồn tại ở nguồn tham chiếu type = 11, **When** mở Map File, **Then**
   màn hình hiển thị lỗi "Sales Order không tồn tại", không hiển thị Step 1/Step 2.
3. **Given** Sales Order có PO liên kết qua `InterCompanyOriginalSalesId` ở nguồn tham chiếu type =
   16, **When** mở Step 1, **Then** bảng PO hiển thị đúng các PO đó lấy từ D365 (không phải PO mock).
4. **Given** Sales Order đã có bản ghi trong `eutr_purchase_attachments` cho một số PurchId, **When**
   mở Step 1, **Then** đúng các PO đó được tick chọn sẵn theo mặc định.
5. **Given** người dùng thay đổi lựa chọn PO và nhấn Save PO Mapping, **When** lưu thành công,
   **Then** bảng `eutr_purchase_attachments` phản ánh đúng lựa chọn mới nhất cho Sales ID này (PO bị
   bỏ chọn không còn bản ghi, PO mới chọn có bản ghi mới).
6. **Given** (các) PO đã lưu gắn với một `TemplateCode` cụ thể, **When** mở Step 2, **Then** cây
   thư mục hiển thị đúng theo `TemplateCode` đó (không dùng template mock cố định theo Sales Order).
7. **Given** (các) PO đã chọn có tài liệu trong `eutr_references`, **When** xem AVAILABLE FILES,
   **Then** danh sách tài liệu hiển thị đúng file thật, mỗi file gắn đúng step tương ứng trong cây.
8. **Given** người dùng nhấn nút Upload (UploadIcon) ở Step 2, **When** popup Add tài liệu mở ra,
   chọn Type/Step/Value hợp lệ và chọn file hợp lệ để tải lên, **Then** hệ thống lưu bản ghi tài liệu
   thật (`eutr_documents`/`eutr_references`) và popup tự đóng sau khi tải xong; tài liệu mới xuất hiện
   ngay trong AVAILABLE FILES/Map status tương ứng nếu khớp ngữ cảnh PO/step đang xem, không cần tải
   lại trang.
9. **Given** người dùng nhấn nút Edit trên một tài liệu ở AVAILABLE FILES, **When** popup Edit tài
   liệu mở ra (Type khóa, Step/Value chip/Valid dates theo đúng quy tắc của 004-eutr-documents), thay
   đổi Step hoặc Value chip hoặc Valid dates rồi nhấn Save, **Then** hệ thống cập nhật đúng
   `eutr_documents`/`eutr_references` của tài liệu đó, popup đóng, và Map status/thông tin tài liệu ở
   AVAILABLE FILES phản ánh đúng thay đổi ngay lập tức.
10. **Given** Sales Order đã có sẵn một số PO được tick từ lần Save trước, và còn (các) PO khác chưa
    từng được lưu nhưng có sẵn template từ D365, **When** người dùng mở Step 1, **Then** các PO chưa
    lưu đó vẫn hiển thị checkbox ở trạng thái có thể tick (không bị vô hiệu hóa), cho phép chọn thêm
    bên cạnh các PO đã tick sẵn.
11. **Given** người dùng tick chọn thêm một PO chưa từng được lưu (có template từ D365) bên cạnh các
    PO đã tick sẵn, rồi nhấn Save PO Mapping, **When** lưu thành công, **Then**
    `eutr_purchase_attachments` MUST có thêm bản ghi mới cho PO vừa chọn thêm, với `TemplateCode` lấy
    đúng từ giá trị template của PO đó trả về ở Step 1 (không yêu cầu người dùng chọn Template thủ
    công), đồng thời vẫn giữ nguyên các bản ghi của các PO đã chọn từ trước đó chưa bị bỏ tick.
12. **Given** đang ở màn hình Map File (Step 1 hoặc Step 2), **When** người dùng nhấn nút **Back**,
    **Then** hệ thống điều hướng về màn hình **EUTR Sales Orders** (Overview).
13. **Given** Step 2 đang hiển thị (các) template ở toolbar cây template, **When** người dùng click
    vào một template, **Then** hệ thống tải lại đúng danh sách `templatesData` mới nhất từ dữ liệu
    thật (không hiển thị lại dữ liệu cũ một cách tĩnh).
14. **Given** một tài liệu ở AVAILABLE FILES có bản ghi `eutr_references` với `StepId` khớp một node
    bất kỳ trong cây template hiện tại, **When** xem danh sách, **Then** tài liệu đó hiển thị Map
    status **"Mapped"**.
15. **Given** một tài liệu ở AVAILABLE FILES có bản ghi `eutr_references` với `StepId` không khớp
    node nào trong cây template hiện tại, **When** xem danh sách, **Then** tài liệu đó hiển thị Map
    status **"No map"**.
16. **Given** một tài liệu ở AVAILABLE FILES có bản ghi `eutr_references` xác định `RefType`/
    `RefValue`, **When** xem danh sách, **Then** tài liệu đó hiển thị đúng **File type** (tên loại
    tra cứu từ `eutr_reference_types`) và **PO value** (giá trị `RefValue`, ví dụ `PO00014347`).
17. **Given** Sales Order có nhiều PO đã lưu gắn với nhiều `TemplateCode` khác nhau (ví dụ PO-A →
    Template X, PO-B → Template Y), **When** người dùng đang xem cây của Template X ở toolbar, **Then**
    khu vực AVAILABLE FILES chỉ hiển thị (các) tài liệu của PO-A (thuộc Template X) — không hiển thị
    tài liệu của PO-B (thuộc Template Y).
18. **Given** đang xem cây của Template X, **When** người dùng click chọn xem Template Y ở toolbar,
    **Then** khu vực AVAILABLE FILES cập nhật lại ngay để chỉ còn hiển thị đúng tài liệu của (các) PO
    thuộc Template Y.
19. **Given** một tài liệu thuộc PO-B (gắn với Template Y) có `StepId` trùng với `StepId` của một node
    trong cây Template X (hai template dùng chung một Step từ `eutr_steps`), **When** xem tài liệu đó
    trong ngữ cảnh Template X, **Then** tài liệu đó KHÔNG được hiển thị/tính là "Mapped" cho node của
    Template X (Map status của nó chỉ đúng khi xét trong ngữ cảnh Template Y — đúng PO/đúng template
    của chính nó), và node tương ứng của Template X KHÔNG được tính là "đã có tài liệu" nhờ tài liệu
    này.
20. **Given** Sales Order có nhiều template đã lưu, **When** xem số liệu tiến độ tổng hợp (Required/
    completed) ở header card, **Then** số liệu này MUST được tính bằng cách cộng dồn kết quả đã xác
    định đúng theo PO/Template của từng template riêng biệt (theo quy tắc ở kịch bản 19), không phải
    bằng cách so khớp mọi tài liệu với mọi step của mọi template gộp chung một tập.
21. **Given** đang xem AVAILABLE FILES ở Step 2, **When** nhìn vào một dòng tài liệu, **Then** thấy
    nút **View** đặt kế nút Edit hiện có trên dòng đó.
22. **Given** người dùng nhấn nút View trên một tài liệu, **When** popup mở ra, **Then** popup hiển
    thị đúng nội dung file của chính tài liệu đó (không phải nội dung của tài liệu khác), ở chế độ
    chỉ đọc — không có trường Type/Step/Value/Valid dates nào để chỉnh sửa, không có nút Save.
23. **Given** popup View đang mở, **When** người dùng đóng popup (nút Close hoặc click ra ngoài),
    **Then** popup đóng và không có bất kỳ bản ghi tài liệu/tham chiếu nào bị ghi/sửa/xóa.
24. **Given** tài liệu đó thuộc loại file không được popup xem trước hỗ trợ hiển thị nội dung,
    **When** nhấn nút View, **Then** popup hiển thị trạng thái rõ ràng cho biết không xem trước
    được, không gây lỗi hay crash màn hình Map File.

---

### User Story 5 - Xem tổng quan hồ sơ EUTR của Sales Order, chỉ đọc (View Sales Order) (Priority: P2)

Từ màn hình EUTR Sales Orders, người dùng nhấn nút "View" trên một dòng để mở màn hình **View Sales
Order** của Sales Order đó. Màn hình kiểm tra Sales Order có tồn tại hay không (cùng nguồn tham chiếu
dùng chung với Overview/Map File), hiển thị đúng thông tin Sales ID/Customer/Customer name ở header,
danh sách các **Purchase Order đã chọn** (lấy từ `eutr_purchase_attachments`, tra cứu thêm thông tin
PO thật từ D365), và **Template Checklist** — cây các bước của (các) template gắn với Sales Order đó.
Toolbar cây template (`data-marker="template-tree-toolbar"`) hiển thị một chip cho mỗi template đã
lưu; Template Checklist chỉ hiển thị đúng cây của **một** template tại một thời điểm — cây của
template đang được chọn ở toolbar, mặc định là template đầu tiên khi mở màn hình. Click vào một
template khác ở toolbar sẽ chuyển sang hiển thị đúng cây của template đó. Mỗi bước trong cây hiển thị
đúng trạng thái đã có tài liệu hay còn thiếu, xác định dựa trên tài liệu thật (`eutr_references`)
thuộc **đúng PO của chính template đang xem** (tra theo `eutr_purchase_attachments`) — không nhầm lẫn
với tài liệu thuộc PO của một template khác dù hai template dùng chung tên Step. Toàn bộ màn hình chỉ
ở chế độ xem — không có thao tác tick chọn PO, map/unmap tài liệu hay upload nào. Muốn thay đổi, người
dùng nhấn nút **Edit / Map File** để chuyển sang màn hình Map File. Nút **Download** tải xuống một file
zip có tên động `{SalesId}-{CustomerCode}-{CustomerName}`, bên trong chia theo thư mục con cho từng
template đã lưu (tên thư mục = tên thật của template), mỗi thư mục con chỉ chứa các tài liệu đã
"Mapped" đúng cho template đó; nếu không có tài liệu Mapped nào, hệ thống hiển thị thông báo rõ ràng
thay vì tải file zip rỗng. Phần **Validation Summary** tổng hợp từ dữ liệu step thật trên toàn bộ
template đã lưu (áp dụng đúng quy tắc PO/Template cho từng template trước khi cộng dồn): liệt kê (các)
PO đã chọn, số step đã đủ tài liệu, số step còn thiếu tài liệu.

**Why this priority**: Đây là góc nhìn tổng quan (read-only) song song với Map File — giúp người dùng
kiểm tra nhanh tình trạng hồ sơ EUTR của một Sales Order mà không rủi ro làm thay đổi dữ liệu; phụ
thuộc vào cùng dữ liệu thật đã có ở Map File (User Story 4) nên xếp cùng mức ưu tiên, sau khi xem được
danh sách (User Story 1).

**Independent Test**: Mở View cho một Sales Order đã Save PO Mapping với một số step đã có tài liệu
và một số step còn thiếu, xác nhận header/danh sách PO/Template Checklist/Validation Summary hiển thị
đúng dữ liệu thật, không có control chỉnh sửa nào hoạt động; nhấn Edit/Map File xác nhận điều hướng
đúng sang Map File của Sales Order đó; nhấn Download xác nhận tải xuống đúng 1 file zip có tên
`{SalesId}-{CustomerCode}-{CustomerName}`, chứa đúng thư mục con cho mỗi template đã lưu (tên thư mục
= tên thật của template) và mỗi thư mục con chỉ chứa đúng các tài liệu đã "Mapped" cho template đó.

**Acceptance Scenarios**:

1. **Given** Sales ID hợp lệ tồn tại ở nguồn tham chiếu type = 11, **When** mở View, **Then** header
   hiển thị đúng Sales ID/Customer/Customer name khớp với dữ liệu ở Overview/Map File.
2. **Given** Sales ID không tồn tại ở nguồn tham chiếu type = 11, **When** mở View, **Then** màn hình
   hiển thị lỗi "Sales Order không tồn tại", không hiển thị danh sách PO/Template Checklist/Validation
   Summary.
3. **Given** Sales Order đã Save PO Mapping với một số PurchId, **When** mở View, **Then** danh sách
   "Purchase Orders đã chọn" hiển thị đúng các PO đó với thông tin thật (PO, Name, Order account, Qty)
   tra cứu từ D365 — không hiển thị các cột demo Vendor/Vendor Name/Rate/Material.
4. **Given** Sales Order chưa Save PO Mapping nào (chưa có bản ghi trong `eutr_purchase_attachments`),
   **When** mở View, **Then** danh sách PO hiển thị trạng thái trống rõ ràng ("Chưa chọn PO nào") và
   Template Checklist hiển thị trạng thái "chưa có cây template".
5. **Given** (các) PO đã lưu gắn với một hoặc nhiều `TemplateCode`, **When** xem Template Checklist,
   **Then** cây hiển thị đúng theo (các) `TemplateCode` đó, mỗi template hiển thị một lần duy nhất.
6. **Given** một step trong cây có tài liệu thật trong `eutr_references`, **When** xem Template
   Checklist, **Then** step đó hiển thị trạng thái "đã map"; step Required chưa có tài liệu hiển thị
   trạng thái "thiếu".
7. **Given** đang ở màn hình View, **When** người dùng click vào node cây hoặc vào file, **Then**
   không có hành vi tick chọn PO/map/unmap/upload nào xảy ra (chỉ cho phép expand/collapse cây để
   xem).
8. **Given** đang ở màn hình View, **When** nhấn nút Edit / Map File, **Then** hệ thống điều hướng
   sang màn hình Map File (route `/eutr/sales-orders/:salesId/map-file`) của đúng Sales Order đang
   xem.
9. **Given** Sales Order đang xem có ít nhất 1 tài liệu "Mapped" ở một template bất kỳ, **When** nhấn
   nút Download, **Then** hệ thống tải xuống đúng 1 file zip có tên
   `{SalesId}-{CustomerCode}-{CustomerName}`, bên trong có một thư mục con cho mỗi template đã lưu
   (tên thư mục = tên thật của template), mỗi thư mục con chỉ chứa các tài liệu "Mapped" đúng cho
   template đó.
9a. **Given** Sales Order có 2 template đã lưu trở lên, mỗi template có ít nhất 1 tài liệu "Mapped"
   riêng, **When** nhấn Download, **Then** file zip có đủ số thư mục con tương ứng số template, mỗi
   thư mục con chỉ chứa tài liệu thuộc đúng PO/template của chính nó — không lẫn tài liệu của template
   khác.
9b. **Given** một template đã lưu của Sales Order không có tài liệu "Mapped" nào (dù có thể có tài
   liệu "No map"), **When** nhấn Download, **Then** thư mục con của template đó vẫn xuất hiện trong
   file zip nhưng không có file nào bên trong.
9c. **Given** Sales Order chưa Save PO Mapping nào (chưa có template) hoặc không có tài liệu "Mapped"
   nào ở bất kỳ template nào, **When** nhấn nút Download, **Then** nút Download vẫn ở trạng thái bấm
   được, hệ thống hiển thị thông báo rõ ràng cho biết không có tài liệu nào để tải, và không có file
   zip nào được tải xuống.
9d. **Given** CustomerCode hoặc CustomerName của Sales Order chứa ký tự đặc biệt/khoảng trắng, **When**
   nhấn Download, **Then** tên file zip/thư mục gốc vẫn là một tên hợp lệ (đã sanitize), không gây lỗi
   tải xuống hay giải nén.
10. **Given** Validation Summary đang hiển thị, **When** xem, **Then** thông tin hiển thị đúng: (các)
    PO đã chọn, số step Required đã đủ tài liệu, số step Required còn thiếu tài liệu kèm tên các step
    thiếu.
11. **Given** Sales Order có 2 template đã lưu trở lên, **When** mở màn hình View, **Then** toolbar
    cây template hiển thị đúng một chip cho mỗi template thật lấy từ `templatesData` (không phải nhãn
    tĩnh demo), và Template Checklist mặc định hiển thị đúng cây của template **đầu tiên** trong danh
    sách.
12. **Given** đang xem cây của Template A ở toolbar, **When** người dùng click vào chip Template B,
    **Then** Template Checklist chuyển sang chỉ hiển thị đúng cây của Template B — không còn hiển thị
    cây của Template A hay của bất kỳ template khác.
13. **Given** một tài liệu thuộc PO của Template A có Step trùng tên/`StepId` với một node của
    Template B (hai template dùng chung một Step từ `eutr_steps`), **When** người dùng đang xem cây
    Template B, **Then** node đó của Template B KHÔNG được tính "đã có tài liệu" nhờ tài liệu thuộc
    Template A.
14. **Given** Sales Order có nhiều template đã lưu, **When** xem số liệu Required/completed ở header
    hoặc Validation Summary, **Then** số liệu này vẫn tổng hợp trên toàn bộ template (không chỉ
    template đang xem ở toolbar), nhưng mỗi template được tính đúng theo quy tắc PO/Template ở kịch
    bản 13 trước khi cộng dồn.
15. **Given** người dùng click liên tiếp nhiều lần vào các chip template khác nhau ở toolbar,
    **When** chuyển đổi qua lại, **Then** mỗi lượt chuyển chỉ đổi template đang hiển thị trên giao
    diện, không gọi API ghi nào và không làm thay đổi bất kỳ dữ liệu nào.

---

### Edge Cases

- Nguồn dữ liệu tham chiếu (reftype = 11) tạm thời không phản hồi hoặc trả lỗi: bảng hiển thị trạng
  thái lỗi/tải thất bại rõ ràng, không hiển thị dữ liệu demo Template/Progress đè lên một bảng rỗng
  gây hiểu nhầm là có dữ liệu thật.
- Không có sales order nào trong nguồn dữ liệu: bảng hiển thị trạng thái trống ("No data").
- Customer name quá dài: hiển thị rút gọn (ellipsis/tooltip) theo cùng mẫu đã dùng ở các cột tên dài
  khác trong hệ thống, không làm vỡ bố cục bảng.
- Nhiều sales order có cùng Customer: mỗi sales order vẫn hiển thị là một dòng riêng biệt.
- Một Sales ID có nhiều bản ghi trong `eutr_purchase_attachments` cùng trỏ tới **cùng một**
  `TemplateCode` (nhiều `PurchId` dùng chung 1 template): cột Template chỉ hiển thị template đó
  **một lần duy nhất**, không lặp lại theo số lượng `PurchId`.
- `TemplateCode` trong `eutr_purchase_attachments` không còn khớp với bản ghi nào trong
  `eutr_templates` (template đã bị xóa/đổi code): dòng đó bỏ qua template không tra cứu được, không
  làm lỗi toàn bộ dòng hiển thị.
- Sales ID hợp lệ (tồn tại ở reference type = 11) nhưng D365 chưa có PO nào có
  `InterCompanyOriginalSalesId` khớp Sales ID đó (reference type = 16 trả về rỗng): Step 1 của Map
  File hiển thị trạng thái trống ("Không có PO nào"), không phải lỗi, không hiển thị PO mock.
- Một PO ở reference type = 16 không có template gắn kèm (giá trị template rỗng trên D365): PO đó
  KHÔNG lưu được vào `eutr_purchase_attachments` (cột `TemplateCode` là bắt buộc, `NOT NULL`) — Map
  File MUST cho biết rõ PO đó thiếu template (ví dụ vô hiệu hóa checkbox hoặc cảnh báo), không được
  lưu một bản ghi thiếu `TemplateCode`.
- Nhiều PO đã lưu của cùng Sales ID trỏ tới cùng một `TemplateCode`: Step 2 chỉ hiển thị một cây thư
  mục duy nhất cho template đó (không lặp lại theo số PO), theo đúng nguyên tắc dedup đã áp dụng cho
  cột Template ở Overview.
- Sales Order chưa từng Save PO Mapping ở Step 1 (chưa có bản ghi nào trong `eutr_purchase_attachments`
  cho Sales ID này): Step 2 hiển thị trạng thái "chưa có cây template" rõ ràng, không hiển thị cây
  mock/demo đè lên.
- Một bản ghi `eutr_references` của tài liệu thuộc PO đã chọn có `StepId` không khớp bất kỳ node nào
  trong cây template hiện tại (ví dụ tài liệu được gắn từ một luồng/step khác): AVAILABLE FILES vẫn
  hiển thị tài liệu đó trong danh sách, nhưng không gán nhãn "đã map" cho một node cây không tồn tại
  — không gây lỗi hiển thị.
- Một PO đã chọn ở Step 1 chưa có bản ghi nào trong `eutr_references`: AVAILABLE FILES hiển thị trạng
  thái trống rõ ràng cho phần tài liệu của PO đó, không hiển thị file mock.
- PO chưa có bản ghi trong `eutr_purchase_attachments` nhưng có sẵn giá trị template từ D365
  (`eutrTemplate` không rỗng): checkbox của PO đó ở Step 1 vẫn ở trạng thái có thể tick chọn (không bị
  vô hiệu hóa) — không được coi là "chưa gắn Template" theo nghĩa bị chặn chọn của FR-022, vì FR-022
  chỉ áp dụng cho trường hợp D365 hoàn toàn không có giá trị template cho PO đó.
- Người dùng bỏ tick một PO đã lưu trước đó và đồng thời tick thêm một PO mới chưa từng lưu, rồi nhấn
  Save PO Mapping một lần: kết quả sau khi lưu MUST khớp chính xác với toàn bộ tập PO đang được tick
  tại thời điểm nhấn Save (PO bị bỏ tick bị xóa bản ghi, PO mới tick có bản ghi mới) — không phân biệt
  xử lý theo thứ tự tick chọn trước/sau.
- Người dùng nhấn nút Back khi đang có thay đổi lựa chọn PO ở Step 1 nhưng **chưa** nhấn Save PO
  Mapping: hệ thống vẫn điều hướng về EUTR Sales Orders ngay khi nhấn Back — không tự động lưu, cũng
  không cần xác nhận rời trang (đúng hành vi read/act đơn giản đã áp dụng cho các thao tác điều hướng
  khác trong hệ thống).
- Sales Order tồn tại (ref type = 11) nhưng chưa từng Save PO Mapping: màn hình View hiển thị danh
  sách Purchase Orders đã chọn ở trạng thái trống, Template Checklist hiển thị "chưa có cây template",
  Validation Summary hiển thị điều kiện "đã chọn PO" ở trạng thái chưa đạt — không hiển thị dữ liệu
  mock đè lên.
- Một PurchId đã lưu trong `eutr_purchase_attachments` nhưng D365 (reference type = 16) không còn trả
  về bản ghi khớp tại thời điểm xem (ví dụ PO đã bị hủy/thay đổi bên D365): màn hình View vẫn hiển thị
  PurchId đó, các trường thông tin bổ sung (tên, order account, qty) hiển thị trống nếu không tra cứu
  được — không gây lỗi toàn màn hình.
- Nhiều PO đã lưu của cùng Sales Order trỏ tới cùng một `TemplateCode`: Template Checklist ở màn hình
  View chỉ hiển thị một cây duy nhất cho template đó, theo đúng nguyên tắc dedup đã áp dụng ở Overview
  và Step 2 Map File.
- Người dùng thử tương tác (click) vào node cây hoặc file ở màn hình View: hệ thống chỉ cho phép
  expand/collapse để xem, không phát sinh bất kỳ thay đổi dữ liệu nào (không có API ghi nào được gọi
  từ màn hình này).
- Một tài liệu ở AVAILABLE FILES có nhiều bản ghi `eutr_references` khác nhau trong cùng ngữ cảnh PO
  (ví dụ gắn nhiều Step khác nhau cho cùng một PO): Map status hiển thị "Mapped" nếu **ít nhất một**
  bản ghi khớp `StepId` với cây template hiện tại; File type/PO value hiển thị theo bản ghi đầu tiên
  tìm được cho tài liệu đó trong ngữ cảnh PO này — không hiển thị nhiều giá trị mâu thuẫn nhau trên
  cùng một dòng.
- `RefType` trên bản ghi `eutr_references` của một tài liệu không còn khớp bản ghi nào trong
  `eutr_reference_types` (loại đã bị xóa/đổi code): File type hiển thị trạng thái trống rõ ràng, không
  làm lỗi toàn dòng hiển thị của tài liệu đó.
- Người dùng click liên tiếp nhiều lần vào (các) template ở toolbar cây template: mỗi lần tải lại
  `templatesData` là một lượt độc lập, không tích lũy gọi API chồng chéo, không tạo node lặp lại
  trong cây hiển thị sau khi tải lại.
- Sales Order chưa có `templatesData` nào (chưa Save PO Mapping lần nào): toolbar cây template không
  hiển thị chip template nào, do đó không có hành vi click nào để tải lại — giữ đúng trạng thái "chưa
  có cây template" theo FR-025.
- Người dùng nhấn Upload ở Step 2, chọn Type/Step/Value và file hợp lệ nhưng file đó (theo Value/PO
  đã chọn trong popup) không liên quan tới PO/template nào đang hiển thị của Sales Order đang xem: hệ
  thống vẫn lưu bản ghi tài liệu thật (theo đúng lựa chọn của người dùng trong popup Add), nhưng tài
  liệu đó KHÔNG xuất hiện trong AVAILABLE FILES của Sales Order đang xem vì không khớp điều kiện lọc
  theo PO/template hiện tại — không phải lỗi.
- Người dùng chọn file không hợp lệ (sai định dạng hoặc vượt kích thước) khi Upload ở Step 2: file đó
  bị từ chối kèm thông báo lỗi rõ ràng, các file hợp lệ khác trong cùng lượt chọn (nếu có) vẫn được
  tải lên và lưu bình thường — theo đúng hành vi đã áp dụng ở 004-eutr-documents (FR-025).
- Người dùng mở popup Edit trên một tài liệu có Type = "PO": Value chip hiển thị chỉ đọc (không thêm/
  xóa được), chỉ Step và Valid from/Valid to có thể chỉnh sửa — theo đúng quy tắc của 004-eutr-documents.
- Người dùng mở popup Edit trên một tài liệu có Type khác "PO" (ví dụ Vendor, Invoice): Value chip có
  thể thêm/xóa, nhưng phải còn lại ít nhất 1 chip tại thời điểm Save, nếu không hệ thống MUST chặn Save
  và báo lỗi rõ ràng — theo đúng quy tắc của 004-eutr-documents.
- Người dùng đóng popup Add hoặc Edit (nút Close/click ra ngoài) mà chưa nhấn Upload/Save: mọi thay đổi
  đang nhập trong popup bị hủy bỏ, không có bản ghi nào được tạo/sửa, AVAILABLE FILES và Map status giữ
  nguyên trạng thái trước đó.
- Lệnh Upload hoặc Save (Edit) thất bại do lỗi hệ thống/API: popup hiển thị thông báo lỗi, không đóng
  popup, không thay đổi dữ liệu AVAILABLE FILES/Map status hiện có cho tới khi người dùng thử lại thành
  công hoặc tự đóng popup.
- Hai template khác nhau (đã lưu cho cùng Sales Order) có node dùng chung `StepId` (do cùng tham chiếu
  một bước trong bảng `eutr_steps`, ví dụ cả hai đều có bước "Invoice"): một tài liệu thuộc PO của
  template này KHÔNG được coi là "đã map" vào node cùng tên/cùng `StepId` của template kia — Map status
  và chỉ báo "đã có tài liệu" luôn xét theo đúng cặp (PO, Template) của chính tài liệu đó.
- Một PO đã lưu chưa từng có bản ghi nào trong `eutr_references` (chưa có tài liệu nào), và Sales Order
  cũng có (các) PO khác của template khác đã có tài liệu: khi xem template của PO chưa có tài liệu,
  AVAILABLE FILES hiển thị trạng thái trống rõ ràng cho đúng phạm vi template đang xem (không "mượn"
  hiển thị nhầm tài liệu của PO/template khác để lấp khoảng trống).
- Sales Order chỉ có đúng 1 template đã lưu (chỉ 1 `TemplateCode` duy nhất trong
  `eutr_purchase_attachments`): việc lọc AVAILABLE FILES theo template đang xem không làm thay đổi gì so
  với hành vi hiện có (mọi PO đã chọn đều thuộc cùng 1 template nên tập tài liệu hiển thị là như nhau) —
  chỉ có tác động khi Sales Order có từ 2 template khác nhau trở lên.
- Màn hình View chưa Save PO Mapping nào (chưa có `templatesData`): toolbar cây template không hiển
  thị chip nào (giống Map File), Template Checklist hiển thị trạng thái "chưa có cây template" theo
  đúng FR-040 — không có template nào để mặc định chọn hiển thị.
- Màn hình View chỉ có đúng 1 template đã lưu: toolbar chỉ hiển thị 1 chip (luôn ở trạng thái được
  chọn), Template Checklist luôn hiển thị đúng cây của template đó — hành vi click chọn template không
  có tác động quan sát được vì không có template thứ hai để chuyển sang.
- Sales Order có nhiều template đã lưu nhưng một trong số đó chưa có tài liệu nào trong
  `eutr_references` cho (các) PO của nó: khi xem cây của template đó, mọi step Required hiển thị
  trạng thái "còn thiếu" (không "mượn" tài liệu của PO/template khác để lấp khoảng trống), theo đúng
  nguyên tắc đã áp dụng ở Map File Step 2 (Update 7).
- Tài liệu có file lớn/tải chậm khi mở popup View: popup hiển thị trạng thái đang tải trong khi lấy
  nội dung file, theo đúng hành vi hiện có của popup xem trước ở 004-eutr-documents — không hiển thị
  nội dung trống gây hiểu nhầm là file rỗng.
- Người dùng nhấn View liên tiếp trên nhiều tài liệu khác nhau (mở tài liệu này, đóng, mở tài liệu
  khác): mỗi lượt mở popup MUST hiển thị đúng nội dung của tài liệu vừa chọn, không hiển thị nhầm nội
  dung còn sót lại của tài liệu đã xem trước đó.
- Lệnh tải nội dung file cho popup View thất bại (lỗi hệ thống/API): popup hiển thị thông báo lỗi rõ
  ràng, không làm crash hay treo màn hình Map File, người dùng vẫn đóng được popup bình thường.
- Sales Order có nhiều template đã lưu, trong đó một template có tài liệu "Mapped" còn (các) template
  khác thì không: khi nhấn Download, file zip vẫn có đủ thư mục con cho mọi template, chỉ riêng thư
  mục của template không có tài liệu "Mapped" là rỗng — không báo lỗi toàn bộ, không bỏ sót thư mục.
- Sales Order chưa Save PO Mapping nào (chưa có `templatesData`) và người dùng nhấn Download: hệ thống
  hiển thị thông báo rõ ràng không có tài liệu để tải, không tạo file zip chỉ có thư mục gốc rỗng.
- Hai tài liệu "Mapped" khác nhau trong cùng một thư mục con template có cùng tên file gốc (ví dụ cùng
  tải lên một file tên "invoice.pdf" ở hai lần khác nhau): hệ thống tự động phân biệt tên file khi đóng
  gói (ví dụ thêm hậu tố) để cả hai file đều xuất hiện đầy đủ trong zip, không file nào bị ghi đè/mất.
- `CustomerCode`/`CustomerName` của Sales Order rỗng hoặc chứa ký tự không hợp lệ cho tên file/thư mục
  (dấu `/`, khoảng trắng, ký tự đặc biệt, chữ có dấu tiếng Việt): tên file zip/thư mục gốc vẫn được tạo
  hợp lệ sau khi sanitize, không gây lỗi tải xuống hay giải nén, không làm mất khả năng nhận diện Sales
  Order (vẫn giữ được `SalesId` trong tên).
- Người dùng nhấn Download nhiều lần liên tiếp trên cùng một Sales Order: mỗi lần nhấn tạo và tải
  xuống một file zip độc lập phản ánh đúng dữ liệu tài liệu "Mapped" tại thời điểm nhấn, không tích lũy
  hay trùng lặp file giữa các lượt tải.
- Thao tác tạo/tải file zip thất bại (lỗi hệ thống/API khi lấy nội dung file thật để đóng gói): hệ
  thống hiển thị thông báo lỗi rõ ràng, không tải xuống một file zip thiếu/hỏng, không làm crash màn
  hình View.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST cung cấp một màn hình mới **EUTR Sales Orders**, truy cập được từ mục
  điều hướng EUTR.
- **FR-002**: Màn hình MUST hiển thị dữ liệu sales order dưới dạng bảng/grid, lấy dữ liệu qua nguồn
  tham chiếu dùng chung hiện có của hệ thống (endpoint reference, reference type = 11) — không xây
  dựng một nguồn dữ liệu/API riêng mới cho tính năng này.
- **FR-003**: Bảng MUST hiển thị cột **Sales ID** — mã định danh của sales order.
- **FR-004**: Bảng MUST hiển thị cột **Customer** — mã/tài khoản khách hàng gắn với sales order đó.
- **FR-005**: Bảng MUST hiển thị cột **Customer name** — tên hiển thị của khách hàng đó.
- **FR-006**: Bảng MUST hiển thị cột **Delivery date** — ngày giao hàng của sales order; nếu sales
  order không có ngày giao hàng, cột MUST hiển thị trạng thái trống rõ ràng (không phải lỗi).
- **FR-007**: Bảng MUST hiển thị cột **Template** với dữ liệu thật, tra cứu từ bảng
  `eutr_purchase_attachments` theo `SalesId` khớp với Sales ID của dòng đó, hiển thị tên template
  (tra cứu qua `TemplateCode` → bảng `eutr_templates`) gắn với sales order đó.
- **FR-007a**: Nếu một Sales ID có nhiều bản ghi trong `eutr_purchase_attachments` (nhiều `PurchId`
  khác nhau) tham chiếu tới nhiều `TemplateCode` khác nhau, cột Template MUST hiển thị đầy đủ tất cả
  các template khác nhau đó cho dòng sales order tương ứng (mỗi template duy nhất chỉ hiển thị một
  lần, không lặp lại theo số `PurchId`).
- **FR-007b**: Nếu một Sales ID chưa có bản ghi nào trong `eutr_purchase_attachments`, cột Template
  MUST hiển thị trạng thái trống rõ ràng (không lỗi, không hiển thị dữ liệu demo/giả).
- **FR-008**: Bảng MUST hiển thị cột **Progress** với một giá trị demo cố định (dữ liệu mẫu, không
  lấy từ nguồn dữ liệu thật) — hiển thị giống nhau ở mọi dòng, dành cho chức năng sẽ hoàn thiện ở
  một tính năng sau.
- **FR-009**: Nguồn tham chiếu dùng chung (reference type = 11) MUST trả về đủ 4 trường Sales ID,
  Customer, Customer name, Delivery date cho mỗi sales order — hiện tại reference type = 11 chưa
  được đăng ký trong nguồn tham chiếu này (luôn trả về danh sách rỗng) nên đây là điều kiện bắt buộc
  để tính năng có dữ liệu thật.
- **FR-010**: Users MUST có thể chuyển trang khi tổng số sales order vượt quá một trang.
- **FR-011**: Users MUST có thể tìm kiếm/lọc danh sách theo Sales ID hoặc Customer (khớp kiểu
  "chứa", không phân biệt hoa/thường), theo đúng mẫu tìm kiếm tham chiếu đã có trong hệ thống.
- **FR-012**: Khi từ khóa tìm kiếm không khớp sales order nào, hệ thống MUST hiển thị trạng thái
  trống ("No data"), không phải lỗi.
- **FR-013**: Màn hình này là **read-only** trong phạm vi tính năng — KHÔNG cung cấp chức năng thêm
  mới (Create), sửa (Edit) hay xóa (Delete) sales order.
- **FR-014**: Màn hình **Map File** MUST kiểm tra Sales Order có tồn tại hay không bằng cách tra cứu
  cùng nguồn tham chiếu dùng chung reference type = 11 (giống Overview) theo Sales ID trên URL —
  không dùng dữ liệu mock riêng cho màn hình này.
- **FR-015**: Nếu Sales ID không tồn tại ở nguồn tham chiếu type = 11, Map File MUST hiển thị thông
  báo lỗi rõ ràng ("Sales Order không tồn tại") và không hiển thị Step 1/Step 2.
- **FR-016**: Header card của Map File (Sales ID, Customer, Customer name) MUST lấy dữ liệu thật từ
  cùng bản ghi reference type = 11 đã tra được ở FR-014 — không dùng dữ liệu mock.
- **FR-017**: Step 1 ("Chọn Purchase Order") MUST hiển thị danh sách PO lấy từ nguồn tham chiếu dùng
  chung reference type = 16, lọc theo điều kiện `InterCompanyOriginalSalesId` = Sales ID hiện tại —
  không dùng danh sách PO mock.
- **FR-018**: Nếu Sales ID chưa có bản ghi nào trong `eutr_purchase_attachments`, mọi PO ở Step 1
  MUST hiển thị checkbox ở trạng thái chưa chọn theo mặc định.
- **FR-019**: Nếu Sales ID đã có bản ghi trong `eutr_purchase_attachments` (một hoặc nhiều `PurchId`),
  Step 1 MUST tự động tick chọn sẵn (default-checked) đúng các PO tương ứng khi tải trang.
- **FR-020**: Khi người dùng nhấn **Save PO Mapping** ở Step 1, hệ thống MUST lưu các PO đang được
  chọn vào bảng `eutr_purchase_attachments` (`SalesId`, `PurchId`, và `TemplateCode` lấy từ template
  đã gắn sẵn trên từng PO ở D365) — người dùng chọn PO nào áp dụng, không tự chọn template thủ công.
- **FR-021**: Khi Save PO Mapping, hệ thống MUST cập nhật `eutr_purchase_attachments` để khớp đúng
  với lựa chọn hiện tại trên UI — bản ghi của PO đã bị bỏ chọn MUST không còn tồn tại sau khi lưu, PO
  mới được chọn MUST có bản ghi mới; không tích lũy bản ghi của các lần Save trước đó.
- **FR-022**: Nếu một PO ở Step 1 không có template gắn kèm từ D365, hệ thống MUST không cho lưu PO
  đó vào `eutr_purchase_attachments` (do `TemplateCode` là trường bắt buộc) và MUST cho người dùng
  biết rõ lý do (ví dụ vô hiệu hóa lựa chọn hoặc hiển thị cảnh báo).
- **FR-023**: Cây thư mục ở Step 2 ("Map Files vào Template") MUST được xây dựng dựa trên (các)
  `TemplateCode` lấy ra từ các bản ghi `eutr_purchase_attachments` của Sales ID này — không dùng
  template cố định gắn theo Sales Order mock.
- **FR-024**: Nếu các PO đã lưu của Sales ID gắn với nhiều `TemplateCode` khác nhau, Step 2 MUST
  hiển thị đầy đủ cây thư mục cho từng `TemplateCode` khác nhau đó (mỗi template hiển thị một lần
  duy nhất, không lặp lại theo số PO).
- **FR-025**: Nếu Sales ID chưa Save PO Mapping nào (chưa có bản ghi trong `eutr_purchase_attachments`),
  Step 2 MUST hiển thị trạng thái "chưa có cây template" rõ ràng, không hiển thị cây mock.
- **FR-026**: Khu vực **AVAILABLE FILES** ở Step 2 MUST hiển thị các tài liệu thật lấy từ bảng
  `eutr_references` (điều kiện tương ứng loại tham chiếu PO, giá trị tham chiếu = `PurchId`) theo
  (các) PO mà người dùng đã chọn/lưu ở Step 1 — không dùng danh sách file mock.
- **FR-027**: Mỗi tài liệu hiển thị ở AVAILABLE FILES MUST hiển thị đúng Step trong cây template mà
  nó đã được gắn (tra theo `StepId` trên bản ghi `eutr_references` tương ứng), dùng để phản ánh đúng
  trạng thái "đã map" cho đúng node trong cây ở Step 2.
- **FR-028**: Nếu một PO đã chọn ở Step 1 chưa có bản ghi nào trong `eutr_references`, AVAILABLE
  FILES MUST hiển thị trạng thái trống rõ ràng cho phần tài liệu của PO đó, không lỗi, không hiển thị
  file mock.
- **FR-029**: Nút **Upload** (UploadIcon) ở Step 2 MUST mở đúng popup **Add tài liệu** đã có sẵn ở màn
  hình EUTR Documents (004-eutr-documents) — đầy đủ các trường Type, Step, Value, Valid from/Valid to
  và luồng chọn/tải file thật, áp dụng đúng toàn bộ quy tắc trường dữ liệu và xử lý tải file đã định
  nghĩa ở đặc tả đó (FR-008 đến FR-025 của 004-eutr-documents) — không còn tạo bản ghi tài liệu giả
  chỉ tồn tại cục bộ trên giao diện như trước. Popup này là popup Add **đầy đủ, không giới hạn**: Type/
  Step/Value do người dùng tự chọn, không tự động khóa hay điền sẵn theo PO/Step đang chọn trong cây
  template của Map File.
- **FR-030**: Nút **Edit** trên từng tài liệu ở AVAILABLE FILES MUST mở đúng popup **Edit tài liệu** đã
  có sẵn ở màn hình EUTR Documents (004-eutr-documents) cho đúng tài liệu đó — Type bị khóa, Step vẫn
  chỉnh sửa được (lọc theo Assign Steps của Type), Value hiển thị dạng chip (chỉ đọc nếu Type = "PO",
  chỉnh sửa được nếu Type khác "PO"), Valid from/Valid to vẫn chỉnh sửa được, áp dụng đúng toàn bộ quy
  tắc đã định nghĩa ở đặc tả đó (FR-026 đến FR-034 và FR-051 đến FR-055 của 004-eutr-documents). Nhấn
  **Save** trên popup MUST gọi luồng cập nhật thật (cập nhật `eutr_documents` và đồng bộ bản ghi
  `eutr_references` theo Step/Value chip hiện tại) — thay thế hoàn toàn dialog map Source/PO/Valid
  dates cục bộ trước đây; không còn cơ chế gán mapping cục bộ nào khác cho tài liệu ở màn hình này.
- **FR-030a**: Sau khi Upload (FR-029) hoặc Save Edit (FR-030) thành công, khu vực AVAILABLE FILES và
  trạng thái Map status của (các) tài liệu liên quan trong cây template hiện tại MUST được làm mới
  (refetch) theo dữ liệu thật mới nhất — tài liệu vừa tải lên/vừa sửa phải xuất hiện/đổi trạng thái
  đúng ngay lập tức, không yêu cầu người dùng tải lại toàn bộ trang.
- **FR-030b**: Popup Upload (FR-029) tiếp tục áp dụng đúng hành vi tải nhiều file của 004-eutr-documents
  (FR-025): file không hợp lệ (sai định dạng/vượt kích thước) bị từ chối kèm thông báo lỗi, các file
  hợp lệ khác trong cùng lượt chọn vẫn được tải lên và ghi bản ghi thật; popup tự đóng sau khi lượt tải
  hoàn tất (toàn bộ hoặc một phần). Popup Edit (FR-030) là thao tác Save đơn (một tài liệu): nếu lệnh
  cập nhật thất bại (lỗi validate, lỗi gọi API), popup MUST hiển thị thông báo lỗi rõ ràng và giữ
  nguyên trạng thái đang nhập, không đóng popup, không cập nhật một phần dữ liệu của tài liệu đó.
- **FR-031**: Tại Step 1, các PO chưa có bản ghi nào trong `eutr_purchase_attachments` (chưa từng
  được Save PO Mapping) MUST tiếp tục hiển thị checkbox ở trạng thái có thể tick chọn (không bị vô
  hiệu hóa), miễn là D365 có trả về giá trị template cho PO đó — cho phép người dùng chọn thêm các PO
  này bên cạnh các PO đã tick sẵn từ lần Save trước, không chỉ giới hạn tick lại đúng các PO cũ. Điều
  kiện vô hiệu hóa checkbox theo FR-022 (PO không có template từ D365) vẫn được giữ nguyên.
- **FR-032**: Khi Save PO Mapping với (các) PO mới được tick chọn thêm ở FR-031, hệ thống MUST lưu
  thêm bản ghi mới vào `eutr_purchase_attachments` cho các PO đó với `TemplateCode` lấy từ giá trị
  template (`eutrTemplate`) do nguồn dữ liệu PO ở Step 1 (reference type = 16) trả về — không yêu cầu
  người dùng tự chọn Template thủ công; hành vi đồng bộ toàn bộ tập bản ghi theo đúng lựa chọn hiện
  tại trên UI (FR-021) vẫn áp dụng cho các PO mới chọn thêm này.
- **FR-033**: Nút **Back** trên màn hình Map File MUST điều hướng người dùng quay lại màn hình **EUTR
  Sales Orders** (Overview, route `/eutr/sales-orders`) khi được nhấn — không để trống không phản
  hồi như hiện tại.
- **FR-034**: Màn hình **View Sales Order** (`ViewSalesOrderPage`) MUST kiểm tra Sales Order có tồn
  tại hay không bằng cách tra cứu cùng nguồn tham chiếu dùng chung reference type = 11 (giống Map File
  FR-014) theo Sales ID trên URL — không dùng dữ liệu mock (`MOCK_SALES_ORDERS`).
- **FR-035**: Nếu Sales ID không tồn tại ở nguồn tham chiếu type = 11, màn hình View MUST hiển thị
  thông báo lỗi rõ ràng ("Sales Order không tồn tại") và không hiển thị danh sách Purchase Orders,
  Template Checklist, hay Validation Summary.
- **FR-036**: Header của màn hình View (Sales ID, Customer, Customer name) MUST lấy dữ liệu thật từ
  cùng bản ghi reference type = 11 đã tra được ở FR-034 — không dùng dữ liệu mock.
- **FR-037**: Danh sách **Purchase Orders đã chọn** ở màn hình View MUST lấy từ các bản ghi đã lưu
  trong `eutr_purchase_attachments` của Sales ID này, tra cứu thêm thông tin hiển thị (tên, order
  account, số lượng) từ nguồn tham chiếu dùng chung reference type = 16 — không dùng
  `MOCK_SO_POS`/`MOCK_SO_PO_MAPPINGS` và không hiển thị các cột demo cũ (Vendor/Vendor Name/Rate/
  Material) không có nguồn dữ liệu thật tương ứng.
- **FR-038**: Nếu Sales ID chưa có bản ghi nào trong `eutr_purchase_attachments`, danh sách Purchase
  Orders đã chọn ở màn hình View MUST hiển thị trạng thái trống rõ ràng ("Chưa chọn PO nào").
- **FR-039**: **Template Checklist** ở màn hình View MUST được xây dựng dựa trên (các) `TemplateCode`
  lấy từ các bản ghi `eutr_purchase_attachments` của Sales ID này, theo đúng cơ chế xây cây đã áp dụng
  ở Step 2 Map File (FR-023/FR-024) — không dùng `EUTR_TEMPLATE_DETAILS_MAP`/`so.templateId` mock.
- **FR-040**: Nếu Sales ID chưa Save PO Mapping nào (chưa có bản ghi trong `eutr_purchase_attachments`),
  Template Checklist ở màn hình View MUST hiển thị trạng thái "chưa có cây template" rõ ràng (giống
  Map File FR-025), không hiển thị cây mock.
- **FR-041**: Mỗi step trong Template Checklist ở màn hình View MUST hiển thị đúng trạng thái "đã có
  tài liệu"/"còn thiếu" dựa trên tài liệu thật lấy từ `eutr_references` cho (các) PO đã lưu của Sales
  Order này, theo đúng cơ chế đã dùng ở Map File Step 2 (FR-026/FR-027) — không dùng
  `MOCK_AVAILABLE_FILES`/`MOCK_FILE_MAPPINGS`.
- **FR-042**: Toàn bộ màn hình View MUST ở chế độ **chỉ đọc** — không cung cấp chức năng tick chọn PO,
  map/unmap tài liệu, hay upload tài liệu mới; chỉ cho phép mở rộng/thu gọn (expand/collapse) cây để
  xem, không làm thay đổi dữ liệu.
- **FR-043**: Nút **Edit / Map File** trên màn hình View MUST điều hướng người dùng sang màn hình
  **Map File** (route `/eutr/sales-orders/:salesId/map-file`) của đúng Sales Order đang xem.
- **FR-044**: Nút **Download** trên màn hình View MUST tiếp tục hiển thị nhưng KHÔNG xử lý tải file
  thật — giữ hành vi demo/no-op tạm thời, việc xử lý thật để lại cho một cập nhật sau.
- **FR-045**: Phần **Validation Summary** ở màn hình View MUST được tính toán từ dữ liệu step thật
  (không dùng dữ liệu mock): liệt kê (các) Purchase Order đã chọn (từ `eutr_purchase_attachments`), số
  step Required đã có tài liệu (đủ file), và số step Required còn thiếu tài liệu (kèm tên các step
  thiếu).
- **FR-046**: Validation Summary ở màn hình View MUST hiển thị trạng thái "chưa đạt" khi Sales Order
  chưa chọn PO nào hoặc còn ít nhất 1 step Required thiếu tài liệu — theo đúng nguyên tắc điều kiện đã
  áp dụng ở phiên bản mock trước đây, nay dựa trên dữ liệu thật; điều kiện "File không hết hạn" của
  bản mock trước đây tạm thời không áp dụng vì dữ liệu tài liệu thật hiện chưa có thông tin ngày hết
  hạn.
- **FR-047**: Khu vực toolbar cây template ở Step 2 của Map File (`data-marker=
  "template-tree-toolbar"`) MUST hiển thị đầy đủ (các) template đã chọn/lưu của Sales Order này (một
  chip riêng biệt cho mỗi template trong `templatesData`) — giữ nguyên cơ chế hiển thị hiện có.
- **FR-048**: Khi người dùng click vào một template ở toolbar này, hệ thống MUST tải lại (refetch)
  toàn bộ danh sách `templatesData` (cây thư mục và chi tiết của mọi template đang gắn với Sales
  Order này) từ nguồn dữ liệu thật, theo đúng cơ chế xây dựng đã áp dụng ở FR-023/FR-024 — không hiển
  thị lại dữ liệu cache cũ một cách tĩnh.
- **FR-049**: Mỗi tài liệu hiển thị ở AVAILABLE FILES MUST hiển thị trạng thái **Map status** động:
  "Mapped" nếu `StepId` của bản ghi `eutr_references` gắn với tài liệu đó (trong ngữ cảnh PO đang xét)
  khớp với `StepId` của một node bất kỳ trong (các) cây template hiện tại; "No map" nếu không khớp
  node nào — thay thế nhãn tĩnh "Map status" hiện có.
- **FR-050**: Mỗi tài liệu hiển thị ở AVAILABLE FILES MUST hiển thị **File type** lấy từ cột `RefType`
  của bản ghi `eutr_references` tương ứng, hiển thị tên loại tra cứu qua bảng `eutr_reference_types`
  (không hiển thị mã số thô) — thay thế nhãn tĩnh "File type" hiện có.
- **FR-051**: Mỗi tài liệu hiển thị ở AVAILABLE FILES MUST hiển thị **PO value** lấy từ cột `RefValue`
  của bản ghi `eutr_references` tương ứng (ví dụ `PO00014347`) — thay thế nhãn tĩnh "PO value" hiện
  có.
- **FR-052**: Nếu bản ghi `eutr_references` của một tài liệu không có giá trị `RefType` hoặc
  `RefValue` (null), hệ thống MUST hiển thị trạng thái trống rõ ràng cho nhãn tương ứng (File
  type/PO value), không lỗi, không hiển thị lại nhãn tĩnh cũ.
- **FR-053**: Khu vực AVAILABLE FILES ở Step 2 MUST lọc danh sách tài liệu chỉ còn (các) tài liệu thuộc
  về (các) PO có `TemplateCode` (tra theo `eutr_purchase_attachments`, khớp `PurchId` = giá trị PO/
  `RefValue` của tài liệu đó) trùng đúng với template đang được chọn xem ở toolbar cây
  (`selectedTemplateCode`) — thay thế hành vi gộp chung tài liệu của toàn bộ PO đã chọn ở Step 1 bất kể
  template mà FR-026 mô tả trước đây.
- **FR-054**: Khi người dùng click chọn xem một template khác ở toolbar cây (cùng thao tác kích hoạt
  FR-048), khu vực AVAILABLE FILES MUST cập nhật lại ngay theo phạm vi lọc của FR-053 cho đúng template
  mới được chọn.
- **FR-055**: Trạng thái **Map status** ("Mapped"/"No map") của một tài liệu, và chỉ báo "đã có tài
  liệu" trên một node cây template, MUST chỉ được xác định là đúng ("Mapped"/"đã có tài liệu") khi thỏa
  đồng thời cả hai điều kiện sau — thay thế hoàn toàn cách so khớp chỉ dựa vào `StepId` gộp chung mọi
  template của FR-049:
  1. PO của tài liệu đó thuộc về đúng template đang xét (tra theo `eutr_purchase_attachments`: `PurchId`
     của PO đó gắn với `TemplateCode` của template này).
  2. `StepId` của bản ghi `eutr_references` gắn với tài liệu đó khớp với `StepId` của một node trong
     chính cây của template đang xét (không tính node của các template khác, kể cả khi trùng `StepId`).
- **FR-056**: Nếu một tài liệu không thỏa điều kiện (1) của FR-055 (PO của tài liệu thuộc một template
  khác với template đang xét), hệ thống MUST hiển thị "No map" cho tài liệu đó trong ngữ cảnh template
  đang xét, và KHÔNG được tính tài liệu đó vào chỉ báo "đã có tài liệu" hay vào tiến độ (progress) của
  bất kỳ node nào thuộc template đang xét — bất kể `StepId` của tài liệu có trùng với node đó hay không.
- **FR-057**: Số liệu tiến độ tổng hợp (Required/completed, tỷ lệ %, danh sách step còn thiếu) hiển thị
  ở header card và Step 2 MUST tiếp tục cộng dồn trên toàn bộ template đã lưu của Sales Order (không thu
  hẹp phạm vi chỉ còn template đang xem), nhưng với mỗi template trong phép cộng dồn đó, việc xác định
  "step này đã có tài liệu hay chưa" MUST áp dụng đúng quy tắc FR-055/FR-056 (chỉ tính tài liệu thuộc
  đúng PO của template đó) trước khi cộng dồn — không dùng chung một tập hợp "mọi tài liệu khớp mọi step
  của mọi template" như trước.
- **FR-058**: Toolbar cây template ở màn hình View (`data-marker="template-tree-toolbar"`) MUST hiển
  thị một chip riêng biệt cho mỗi template trong `templatesData` của Sales Order này (nhãn hiển thị =
  tên template) — thay thế hoàn toàn các chip tĩnh/demo hiện có ("template code1"/"template code2"/
  "All"), theo đúng cách hiển thị đã áp dụng ở toolbar Map File (FR-047).
- **FR-059**: Khi người dùng click vào một chip template ở toolbar này, **Template Checklist** ở màn
  hình View MUST chỉ hiển thị đúng cây của template được chọn (`selectedTemplateCode`) — không còn
  hiển thị nối tiếp cây của mọi template cùng lúc như hiện tại. Chip của template đang được chọn xem
  MUST có trạng thái hiển thị khác biệt so với các chip còn lại.
- **FR-060**: Khi mở màn hình View lần đầu, hoặc khi lựa chọn template hiện tại không còn tồn tại
  trong `templatesData` (ví dụ sau khi tải lại trang), hệ thống MUST tự động chọn và hiển thị đúng cây
  của template **đầu tiên** trong `templatesData` — theo đúng cơ chế mặc định đã áp dụng ở Map File
  Step 2.
- **FR-061**: Trạng thái "đã có tài liệu"/"còn thiếu" của một step trong Template Checklist ở màn hình
  View MUST chỉ đúng ("đã có tài liệu") khi thỏa đồng thời cả hai điều kiện sau — thay thế cách so
  khớp hiện tại (chỉ so tên Step, gộp chung tài liệu của mọi PO/mọi template):
  1. PO của tài liệu đó thuộc về đúng template đang xét (tra theo `eutr_purchase_attachments`:
     `PurchId` của PO đó gắn với `TemplateCode` của template này).
  2. Step của tài liệu đó khớp với một node trong chính cây của template đang xét (không tính node
     thuộc cây của các template khác, kể cả khi trùng tên Step/`StepId`).
- **FR-062**: Số liệu tiến độ tổng hợp (Required/completed, tỷ lệ %, danh sách step còn thiếu) hiển
  thị ở header và Validation Summary của màn hình View MUST tiếp tục cộng dồn trên toàn bộ template đã
  lưu của Sales Order (không thu hẹp chỉ còn template đang xem ở toolbar), nhưng với mỗi template
  trong phép cộng dồn đó, việc xác định "step này đã có tài liệu hay chưa" MUST áp dụng đúng quy tắc
  FR-061 trước khi cộng dồn kết quả của từng template lại thành tổng chung.
- **FR-063**: Việc click chọn xem một template khác ở toolbar của màn hình View KHÔNG MUST gọi bất kỳ
  API ghi nào và KHÔNG bắt buộc phải tải lại (refetch) dữ liệu PO/tài liệu từ nguồn thật — đây chỉ là
  thay đổi hiển thị trên giao diện dựa trên dữ liệu đã tải sẵn khi mở màn hình, giữ đúng nguyên tắc
  chỉ đọc (read-only) của FR-042.
- **FR-064**: Mỗi tài liệu ở khu vực AVAILABLE FILES (Step 2, Map File) MUST hiển thị thêm một nút
  **View**, đặt kế (liền cạnh) nút Edit hiện có trên dòng tài liệu đó.
- **FR-065**: Khi người dùng nhấn nút View trên một tài liệu, hệ thống MUST mở đúng popup xem trước
  nội dung file đã có sẵn ở màn hình EUTR Documents (004-eutr-documents) cho đúng tài liệu đó, hiển
  thị nội dung file ngay trong popup — không tự động tải xuống, không điều hướng người dùng khỏi Map
  File.
- **FR-066**: Popup View MUST ở chế độ chỉ đọc hoàn toàn đối với dữ liệu tài liệu — không hiển thị
  bất kỳ trường Type/Step/Value/Valid dates nào để chỉnh sửa, và không có nút Save nào trong popup
  này.
- **FR-067**: Đóng popup View (nút Close hoặc click ra ngoài popup) MUST không ghi/sửa/xóa bất kỳ
  bản ghi tài liệu/tham chiếu nào — nút View hoạt động độc lập với nút Edit, không ảnh hưởng tới dữ
  liệu hay trạng thái Map status của tài liệu đó.
- **FR-068**: Nếu loại file của tài liệu không được popup xem trước hỗ trợ hiển thị nội dung, popup
  MUST hiển thị trạng thái rõ ràng cho biết không xem trước được, không gây lỗi trang hay crash màn
  hình Map File.
- **FR-069**: Nút **Download** trên màn hình View MUST tải xuống một file nén (zip) chứa cấu trúc thư
  mục của tài liệu EUTR thuộc Sales Order đang xem — thay thế hoàn toàn hành vi demo/no-op hiện có
  của FR-044.
- **FR-070**: Tên file zip và tên thư mục gốc bên trong file zip MUST theo định dạng động
  `{SalesId}-{CustomerCode}-{CustomerName}` của Sales Order đang xem (`SalesId`/`CustomerCode`/
  `CustomerName` lấy từ cùng dữ liệu header đã tra ở FR-036); nếu `CustomerCode`/`CustomerName` chứa
  ký tự không hợp lệ cho tên file/thư mục, hệ thống MUST sanitize các ký tự đó trước khi đặt tên.
- **FR-071**: Bên trong thư mục gốc, hệ thống MUST tạo một thư mục con riêng cho mỗi template đã lưu
  (`TemplateCode` trong `eutr_purchase_attachments`) của Sales Order này — đúng tập template đang có
  trong `templatesData`. Tên mỗi thư mục con MUST là tên thật của template (tra `eutr_templates.Name`
  theo `TemplateCode`), không dùng mã template thô hay nhãn thứ tự cố định.
- **FR-072**: Mỗi thư mục con template MUST chỉ chứa các file tài liệu thật (`eutr_documents`) có
  trạng thái Map status = "Mapped" cho đúng template đó, xác định theo đúng quy tắc PO/Template đã áp
  dụng ở FR-055/FR-056 — tài liệu "No map" (dù thuộc đúng PO của template đó) KHÔNG được đưa vào.
- **FR-073**: Nếu một template không có tài liệu "Mapped" nào, hệ thống MUST vẫn tạo thư mục con của
  template đó trong file zip, ở trạng thái rỗng (không có file bên trong).
- **FR-074**: Nếu toàn bộ Sales Order không có bất kỳ tài liệu "Mapped" nào ở mọi template (kể cả
  trường hợp chưa Save PO Mapping/chưa có template nào), nút Download MUST vẫn ở trạng thái có thể bấm
  được; khi nhấn, hệ thống MUST hiển thị thông báo rõ ràng cho biết không có tài liệu nào để tải và
  KHÔNG tải xuống file zip rỗng.
- **FR-075**: Nếu từ 2 tài liệu "Mapped" trở lên trong cùng một thư mục con template có cùng tên file
  gốc, hệ thống MUST tự động phân biệt tên file (ví dụ thêm hậu tố số thứ tự) khi đóng gói vào zip để
  tránh ghi đè lẫn nhau khi giải nén.
- **FR-076**: Thao tác Download KHÔNG MUST ghi/sửa/xóa bất kỳ bản ghi tài liệu/tham chiếu nào — giữ
  đúng nguyên tắc chỉ đọc (read-only) của màn hình View đã có (FR-042).
- **FR-077**: Số liệu `progress.total` dùng cho khu vực tiến độ `data-marker="progress-bar"`, chip
  "Mapped" và dòng số liệu ở footer Step 2 của Map File MUST tiếp tục chỉ đếm step có `requirementType`
  = **Required** (KHÔNG bao gồm step Optional) — cộng dồn qua toàn bộ (các) template đã lưu của Sales
  Order này, theo đúng phạm vi tổng hợp hiện có (FR-057, không thu hẹp lại chỉ còn template đang xem).
- **FR-078**: Số liệu `progress.completed` tương ứng MUST là số step Required (trong tổng số ở FR-077)
  đã có tối thiểu 1 tài liệu "đã map" — áp dụng đúng quy tắc xác định "đã có tài liệu"/Map status theo
  cặp PO/Template đã có ở FR-055/FR-056.
- **FR-079**: `progress.total` và `progress.completed` (FR-077/FR-078) MUST loại trừ (các) step Required
  có `takeFrom` thuộc nhóm nguồn tự động cũ (`AUTO_SOURCES`), theo đúng quy tắc loại trừ đã áp dụng sẵn
  ở biến `missingRequired` (Map File, FR-080) và ở `requiredDetails`/`mappedRequired`/`missingRequired`
  của màn hình View (FR-062) — để `progress.total - progress.completed` luôn khớp đúng với số của
  `missingRequired` trên cùng màn hình Map File.
- **FR-080**: Chỉ báo "Still missing X file" ở footer Step 2 (biến `missingRequired`, đếm riêng số step
  Required còn thiếu tài liệu, loại trừ `AUTO_SOURCES`) KHÔNG MUST thay đổi bởi Update này — giữ nguyên
  cách tính hiện có.
- **FR-081**: Số liệu `requiredDetails`/`mappedRequired`/`missingRequired`/`pct` ở màn hình View (FR-062)
  MUST tiếp tục chỉ đếm step Required, loại trừ `AUTO_SOURCES`, áp dụng đúng quy tắc PO/Template (FR-061)
  trước khi cộng dồn qua toàn bộ template đã lưu — không thay đổi so với hiện tại; sau khi FR-079 được áp
  dụng cho Map File, số liệu tiến độ của hai màn hình Map File và View MUST khớp nhau cho cùng một Sales
  Order (SC-026).

### Key Entities *(include if feature involves data)*

- **Sales Order** (dữ liệu tham chiếu từ ERP/D365, chỉ đọc): Sales ID, Customer (mã khách hàng),
  Customer name (tên khách hàng), Delivery date (ngày giao hàng). Dữ liệu này KHÔNG được tạo/sửa/xóa
  từ hệ thống này, chỉ được hiển thị.
- **Purchase Attachment** (bảng `eutr_purchase_attachments`, nguồn dữ liệu thật cho cột Template):
  mỗi bản ghi gắn một `SalesId` với một `PurchId` và một `TemplateCode`. Một `SalesId` có thể có
  nhiều bản ghi (nhiều `PurchId`), do đó có thể gắn với nhiều template khác nhau. Màn hình này chỉ
  đọc dữ liệu từ bảng này để hiển thị cột Template, không tạo/sửa/xóa bản ghi.
- **Template** (bảng `eutr_templates`, tra cứu theo `TemplateCode`): cung cấp tên hiển thị cho mỗi
  template được hiển thị ở cột Template.
- **Progress** (thuộc tính demo hiển thị trên mỗi dòng): giá trị mẫu cố định, hiện chưa gắn với
  entity hay logic nghiệp vụ thật nào — chỗ dành sẵn (placeholder) cho một tính năng sau.
- **Purchase Order** (dữ liệu tham chiếu từ D365, reference type = 16, chỉ đọc): PO thuộc về một
  Sales Order xác định qua trường `InterCompanyOriginalSalesId` = Sales ID; mỗi PO có sẵn (các)
  thông tin định danh và một template gắn kèm từ D365. Dữ liệu này KHÔNG được tạo/sửa/xóa từ hệ
  thống này, chỉ được hiển thị và dùng làm nguồn để người dùng chọn lưu vào `eutr_purchase_attachments`.
- **Purchase Attachment** (bảng `eutr_purchase_attachments`) — **cập nhật từ Update 2**: ngoài vai
  trò nguồn đọc cho cột Template ở Overview (Update 1), bảng này nay còn là nơi Map File **ghi**
  lựa chọn PO của người dùng ở Step 1 (`SalesId`, `PurchId`, `TemplateCode`); Save PO Mapping thay
  thế toàn bộ tập bản ghi hiện có của Sales ID đó theo đúng lựa chọn mới nhất trên UI.
- **Reference** (bảng `eutr_references`, nguồn dữ liệu thật cho AVAILABLE FILES ở Step 2): mỗi bản ghi
  gắn một tài liệu (`DocumentId`) với một PO (giá trị tham chiếu = `PurchId`) và một Step (`StepId`)
  trong cây template. Dùng để xác định tài liệu nào đã có sẵn cho (các) PO đã chọn ở Step 1, và tài
  liệu đó thuộc step nào trong cây ở Step 2. **Cập nhật từ Update 5**: mỗi bản ghi còn có `RefType`
  (loại tài liệu, tra cứu tên qua `eutr_reference_types`) và `RefValue` (giá trị tham chiếu, ví dụ mã
  PO) — hai cột này nay được dùng để hiển thị động File type/PO value ở AVAILABLE FILES; `StepId` nay
  còn được dùng để so sánh trực tiếp xác định Map status (Mapped/No map) của từng tài liệu. **Cập nhật
  từ Update 6**: bảng này không còn chỉ đọc ở màn hình Map File — nút Upload/Edit ở Step 2 nay ghi và
  cập nhật bản ghi thật vào bảng này, theo đúng cơ chế ghi đã áp dụng ở màn hình EUTR Documents
  (004-eutr-documents). **Cập nhật từ Update 7**: việc so sánh `StepId` để xác định Map status/chỉ báo
  "đã có tài liệu" nay MUST tra cứu thêm bảng `eutr_purchase_attachments` để xác định `TemplateCode` của
  PO gắn với tài liệu đó (qua `RefValue`/`PurchId`), rồi mới so khớp `StepId` trong đúng phạm vi cây của
  chính template đó — không còn so khớp `StepId` độc lập, gộp chung mọi template như trước (FR-055/
  FR-056).
- **Purchase Attachment** (bảng `eutr_purchase_attachments`) — **cập nhật từ Update 7**: ngoài vai trò
  đã mô tả ở các Update trước (nguồn Template ở Overview, ghi/đọc lựa chọn PO ở Map File Step 1, nguồn
  `TemplateCode` xây cây ở Step 2), bảng này nay còn được dùng làm **khóa phân biệt PO ↔ Template** để
  lọc AVAILABLE FILES (FR-053/FR-054) và xác định đúng Map status/tiến độ theo từng template (FR-055
  đến FR-057) — mỗi `PurchId` chỉ gắn đúng 1 `TemplateCode` trong bảng này, đây là cơ sở duy nhất để suy
  ra tài liệu của một PO thuộc về template nào.
- **Document** (bảng `eutr_documents`, tham chiếu qua `eutr_references.DocumentId`) — **cập nhật từ
  Update 6**: trước đây chỉ đọc để hiển thị tên file ở AVAILABLE FILES; nay màn hình Map File cũng tạo
  bản ghi mới (qua Upload) và cập nhật bản ghi hiện có (qua Edit/Save) trong bảng này, dùng lại đúng
  luồng/quy tắc dữ liệu đã áp dụng ở 004-eutr-documents. **Cập nhật từ Update 9**: nút View mới trên
  mỗi tài liệu ở AVAILABLE FILES chỉ **đọc thêm** nội dung file thật (không phải metadata) của đúng
  bản ghi này — dùng lại đúng cơ chế lấy nội dung file đã có sẵn cho popup xem trước ở
  004-eutr-documents, không tạo/sửa/xóa bản ghi nào trong bảng này hay bảng liên quan.
- **Reference Type** (bảng `eutr_reference_types`, tra cứu theo `RefType` — mới từ Update 5): cung
  cấp tên hiển thị cho nhãn **File type** ở AVAILABLE FILES, theo đúng mẫu tra cứu tên từ mã/id đã
  dùng ở các cột loại khác trong hệ thống.
- **View Sales Order** (màn hình `ViewSalesOrderPage`) — **cập nhật từ Update 4**: dùng lại đúng các
  entity đã mô tả ở trên (Sales Order, Purchase Attachment, Purchase Order, Template, Reference,
  Document) theo chế độ **chỉ đọc** — màn hình này không ghi/sửa/xóa bất kỳ bản ghi nào ở
  `eutr_purchase_attachments`, `eutr_references`, hay các bảng liên quan; mọi thao tác ghi được
  chuyển hướng sang màn hình Map File qua nút Edit / Map File. **Cập nhật từ Update 8**: màn hình này
  nay cũng dùng `eutr_purchase_attachments` làm khóa phân biệt PO ↔ Template (giống Map File Update 7)
  để xác định đúng trạng thái "đã có tài liệu" của mỗi step trong Template Checklist theo đúng phạm vi
  template đang được chọn xem ở toolbar cây template, thay cho cách so khớp tên Step gộp chung mọi
  template trước đây. **Cập nhật từ Update 10**: nút Download của màn hình này nay đọc thêm (không
  ghi) nội dung file thật của (các) `Document` có Map status = "Mapped" (theo đúng khóa phân biệt
  PO ↔ Template ở trên) để đóng gói thành một file zip có cấu trúc thư mục: thư mục gốc đặt tên theo
  `SalesId`-`CustomerCode`-`CustomerName`, thư mục con theo tên thật của từng template, chứa đúng các
  file tài liệu "Mapped" của template đó — không tạo/sửa/xóa bất kỳ bản ghi nào ở `eutr_documents`,
  `eutr_references`, hay `eutr_purchase_attachments`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Người dùng mở màn hình EUTR Sales Orders và thấy danh sách hiển thị trong vòng 3
  giây trong điều kiện mạng/tải thông thường.
- **SC-002**: 100% số dòng hiển thị đầy đủ Sales ID, Customer, Customer name lấy từ dữ liệu thật;
  Delivery date hiển thị đúng giá trị hoặc trạng thái trống rõ ràng khi không có dữ liệu — không có
  dòng nào hiển thị lỗi hoặc dữ liệu sai lệch.
- **SC-003**: Người dùng tìm được một sales order cụ thể bằng ô tìm kiếm trong vòng 10 giây với danh
  sách có hàng trăm bản ghi.
- **SC-004**: 100% số dòng hiển thị đúng (các) template thật gắn với Sales ID đó (tra cứu từ
  `eutr_purchase_attachments`), bao gồm đúng các trường hợp có nhiều template trên cùng 1 dòng và
  trường hợp chưa có template nào; cột Progress vẫn hiển thị nhất quán giá trị demo trên 100% số
  dòng — không có dòng nào gây lỗi hiển thị hay crash màn hình.
- **SC-005**: 100% Sales ID hợp lệ mở màn hình Map File đều thấy đúng header thật (Sales ID/Customer/
  Customer name) khớp với dữ liệu đã thấy ở Overview — không có trường hợp hiển thị dữ liệu mock.
- **SC-006**: 100% PO hiển thị ở Step 1 đến từ D365 (reference type = 16, lọc theo
  `InterCompanyOriginalSalesId`), và các PO đã có sẵn trong `eutr_purchase_attachments` được tick
  chọn đúng ngay khi mở trang — không có PO nào bị thiếu hoặc tick nhầm.
- **SC-007**: Sau khi nhấn Save PO Mapping, lựa chọn PO của Sales ID đó được lưu lại và hiển thị
  đúng (tick sẵn) khi người dùng quay lại màn hình này ở một lần mở khác — không mất lựa chọn.
- **SC-008**: 100% tài liệu hiển thị ở AVAILABLE FILES gắn đúng Step trong cây template, dựa trên dữ
  liệu thật ở `eutr_references` cho (các) PO đã chọn — không có tài liệu nào gắn sai step hoặc bị
  bỏ sót.
- **SC-009**: 100% PO có sẵn template từ D365 hiển thị ở Step 1 đều có thể tick chọn được, bất kể PO
  đó đã có bản ghi trong `eutr_purchase_attachments` hay chưa; sau khi Save PO Mapping, tập bản ghi
  trong `eutr_purchase_attachments` luôn khớp chính xác với toàn bộ PO đang được tick tại thời điểm
  Save (không thiếu, không thừa).
- **SC-010**: 100% lượt nhấn nút Back trên màn hình Map File điều hướng đúng về màn hình EUTR Sales
  Orders, không có trường hợp không phản hồi.
- **SC-011**: 100% Sales ID hợp lệ mở màn hình View đều thấy đúng header thật (Sales ID/Customer/
  Customer name) khớp với dữ liệu đã thấy ở Overview/Map File — không có trường hợp hiển thị dữ liệu
  mock.
- **SC-012**: 100% Purchase Order hiển thị ở danh sách "đã chọn" trên màn hình View khớp chính xác với
  các bản ghi đang có trong `eutr_purchase_attachments` tại thời điểm xem — không thiếu, không thừa.
- **SC-013**: 100% step trong Template Checklist ở màn hình View phản ánh đúng trạng thái đã có tài
  liệu/còn thiếu dựa theo tài liệu thật ở `eutr_references` — khớp với trạng thái tương ứng ở Step 2
  Map File của cùng Sales Order.
- **SC-014**: 100% lượt nhấn Edit / Map File từ màn hình View điều hướng đúng sang Map File của đúng
  Sales Order đang xem.
- **SC-015**: 0% thao tác click/tương tác trên màn hình View (ngoài expand/collapse cây) gây ra thay
  đổi dữ liệu (không có bản ghi nào bị ghi/sửa/xóa từ màn hình này trong 100% các phép thử).
- **SC-016**: 100% tài liệu hiển thị ở AVAILABLE FILES (Step 2 Map File) có Map status/File type/PO
  value phản ánh đúng dữ liệu thật từ `eutr_references` — không còn dòng nào hiển thị nhãn tĩnh cố
  định "Map status"/"File type"/"PO value" như trước.
- **SC-017**: 100% lượt click vào một template ở toolbar cây template (Step 2) tải lại đúng dữ liệu
  `templatesData` mới nhất từ nguồn dữ liệu thật.
- **SC-018**: 100% lượt Upload thành công ở Step 2 (file hợp lệ, đủ Type/Step/Value bắt buộc) tạo đúng
  bản ghi tài liệu thật, và tài liệu đó xuất hiện đúng trong AVAILABLE FILES/Map status của Sales Order
  đang xem trong vòng một lần làm mới dữ liệu (không cần tải lại trang) nếu khớp ngữ cảnh PO/template
  hiện tại.
- **SC-019**: 100% lượt Save (Edit) thành công trên một tài liệu ở AVAILABLE FILES cập nhật đúng dữ
  liệu thật (Step/Value chip/Valid dates theo đúng quy tắc của 004-eutr-documents) và phản ánh đúng
  ngay trên Map status/thông tin hiển thị của tài liệu đó, không có trường hợp Type bị thay đổi ngoài ý
  muốn (Type luôn khóa trong popup Edit).
- **SC-020**: 100% tài liệu hiển thị ở AVAILABLE FILES khi đang xem một template cụ thể đều thuộc về
  (các) PO có `TemplateCode` khớp đúng template đó — 0% tài liệu của PO thuộc template khác bị lẫn vào
  danh sách đang hiển thị.
- **SC-021**: 100% lượt click chuyển sang xem một template khác ở toolbar cây cập nhật đúng ngay danh
  sách AVAILABLE FILES theo phạm vi PO/Template mới, không còn hiển thị lại dữ liệu của template trước
  đó.
- **SC-022**: 0% trường hợp một tài liệu được đánh dấu "Mapped" cho một node thuộc template khác với
  template của chính PO tài liệu đó, kể cả khi hai template dùng chung `StepId`/tên Step — kiểm chứng
  bằng việc dựng dữ liệu thử với 2 template có chung tên Step và xác nhận Map status/chỉ báo "đã có tài
  liệu" chỉ đúng cho template thực sự khớp PO.
- **SC-023**: 100% lượt mở màn hình View cho Sales Order có từ 1 template đã lưu trở lên hiển thị đúng
  toolbar với chip thật lấy từ `templatesData` (không còn nhãn tĩnh demo) và Template Checklist mặc
  định hiển thị đúng cây của template đầu tiên trong danh sách.
- **SC-024**: 100% lượt click chọn một template khác ở toolbar của màn hình View chuyển đúng ngay
  sang hiển thị cây của template đó, không còn hiển thị cây của template trước hoặc của bất kỳ
  template khác.
- **SC-025**: 0% trường hợp một step trong Template Checklist của màn hình View được tính "đã có tài
  liệu" nhờ một tài liệu thuộc PO của một template khác — kiểm chứng bằng việc dựng dữ liệu thử với 2
  template dùng chung tên Step và xác nhận trạng thái mỗi step chỉ đúng theo tài liệu thuộc đúng PO
  của chính template đang xem.
- **SC-026**: 100% số liệu Required/completed hiển thị ở header và Validation Summary của màn hình
  View tiếp tục phản ánh đúng tổng số trên toàn bộ template đã lưu (không bị thu hẹp theo template
  đang xem ở toolbar), đồng thời khớp đúng 1-1 với số liệu `progress.total`/`progress.completed` tương
  ứng ở Step 2 Map File của cùng Sales Order (cả hai đều chỉ tính step Required, loại trừ
  `AUTO_SOURCES`, theo đúng FR-077..FR-081) — không còn lệch nhau vì một bên tính thêm step Optional.
- **SC-027**: 100% tài liệu hiển thị ở AVAILABLE FILES (Step 2 Map File) có đúng nút View đặt kế nút
  Edit hiện có.
- **SC-028**: 100% lượt nhấn nút View mở đúng popup hiển thị nội dung của chính tài liệu vừa chọn
  (không nhầm sang nội dung của tài liệu khác) trong vòng thời gian tải thông thường của popup xem
  trước đã có ở 004-eutr-documents.
- **SC-029**: 0% lượt mở hoặc đóng popup View gây ra bất kỳ thay đổi dữ liệu tài liệu/tham chiếu nào —
  kiểm chứng bằng việc xác nhận `eutr_documents`/`eutr_references` của tài liệu đó không đổi trước và
  sau khi dùng nút View.
- **SC-030**: 100% lượt nhấn Download trên Sales Order có ít nhất 1 tài liệu "Mapped" tải xuống đúng 1
  file zip có tên `{SalesId}-{CustomerCode}-{CustomerName}`, chứa đúng một thư mục con (tên = tên thật
  template) cho mỗi template đã lưu của Sales Order đó.
- **SC-031**: 100% file nằm trong một thư mục con template là tài liệu có Map status "Mapped" đúng cho
  template đó — 0% tài liệu "No map" hoặc tài liệu thuộc PO của một template khác lọt vào nhầm thư mục.
- **SC-032**: 100% lượt nhấn Download khi Sales Order không có tài liệu "Mapped" nào (ở bất kỳ template
  nào, kể cả khi chưa có template nào) hiển thị thông báo rõ ràng, không tải xuống file zip rỗng.
- **SC-033**: 0% lượt tải xuống qua nút Download làm thay đổi bất kỳ bản ghi nào ở `eutr_documents`,
  `eutr_references`, hay `eutr_purchase_attachments` — kiểm chứng bằng việc xác nhận dữ liệu các bảng
  này không đổi trước và sau khi dùng nút Download.
- **SC-034**: 100% trường hợp `CustomerCode`/`CustomerName` chứa ký tự đặc biệt/khoảng trắng vẫn tạo
  được tên file zip/thư mục hợp lệ (đã sanitize) khi tải xuống, không gây lỗi tải xuống hay giải nén.
- **SC-035**: 100% Sales Order có ít nhất 1 template chứa step Required với `takeFrom` thuộc
  `AUTO_SOURCES` và chưa có tài liệu map hiển thị đúng `progress.total - progress.completed` (progress-
  bar, chip Mapped, footer Step 2 của Map File) bằng đúng số của `missingRequired` trên cùng màn hình,
  và bằng đúng số liệu Required/completed/missing tương ứng ở header/Validation Summary của màn hình
  View cho cùng Sales Order — kiểm chứng bằng dữ liệu thử dựng step Required loại `AUTO_SOURCES`.

## Assumptions

- Màn hình mới được thêm vào mục điều hướng EUTR hiện có (ví dụ "EUTR > EUTR Sales Orders"), theo
  đúng mô hình phân quyền/menu điều khiển từ backend đã áp dụng cho các màn hình EUTR khác (menu và
  quyền truy cập được tạo/cấp trực tiếp trong DB ở bước vận hành, không phải tạo cứng trong code của
  tính năng này).
- Màn hình chỉ ở chế độ xem (view-only) trong phạm vi tính năng này — không có Add/Edit/Delete cho
  sales order.
- "Customer" và "Customer name" là hai cột riêng biệt: Customer = mã/tài khoản khách hàng, Customer
  name = tên hiển thị của khách hàng — đúng theo cách người dùng liệt kê hai cột tách biệt.
- Progress vẫn là cột hiển thị dữ liệu demo cố định theo đúng yêu cầu ban đầu, không kết nối tới bất
  kỳ nguồn dữ liệu hay logic nghiệp vụ thật nào ở phạm vi tính năng này.
- Cột Template hiển thị **tên** template (tra cứu qua `eutr_templates.Name` theo `TemplateCode`),
  không hiển thị `TemplateCode` thô — theo đúng mẫu tra cứu tên hiển thị từ mã/id đã dùng ở các cột
  khác trong hệ thống (ví dụ cột Alert for của 003-eutr-templates).
- Khi một Sales ID có nhiều template, các template được hiển thị dưới dạng danh sách trong cùng một
  ô của cột Template (ví dụ nhiều chip/tag trong cùng ô), theo đúng kiểu hiển thị chip đã dùng cho
  cột Template hiện tại — không cần thêm dòng phụ hay mở rộng chiều cao hàng một cách không kiểm
  soát.
- Reference type 11 hiện chưa được đăng ký trong nguồn tham chiếu dùng chung của hệ thống (trả về
  rỗng) và định dạng phản hồi hiện tại của nguồn này chỉ có 3 trường chung (Id/Code/Name); việc bổ
  sung Reference type 11 để trả đủ 4 trường (Sales ID, Customer, Customer name, Delivery date) là mở
  rộng trên đúng cơ chế tham chiếu dùng chung đã có, không xây dựng endpoint/nguồn dữ liệu mới.
- Kích thước trang mặc định và cách sắp xếp mặc định (ví dụ theo Sales ID) áp dụng theo đúng chuẩn
  đã dùng ở các bảng tham chiếu EUTR khác trong hệ thống.
- Việc lọc PO theo `InterCompanyOriginalSalesId` ở reference type = 16 sẽ được bổ sung theo đúng cơ
  chế filter dùng chung hiện có (tương tự cách reference type = 11 đã được mở rộng ở Update 1) —
  không xây dựng endpoint tham chiếu riêng cho Map File.
- Các cột cụ thể hiển thị ở bảng PO Step 1 (hiện đang là Vendor/Vendor Name/Rate/Material dạng demo)
  có thể cần điều chỉnh lại để khớp với các trường thật có sẵn từ D365 ở reference type = 16 — việc
  ánh xạ cột cụ thể (giữ, đổi tên, hoặc bỏ cột nào) sẽ được quyết định ở giai đoạn thiết kế kỹ thuật
  (data-model/plan), không thuộc phạm vi đặc tả nghiệp vụ ở đây.
- `TemplateCode` dùng để lưu vào `eutr_purchase_attachments` khi Save PO Mapping lấy từ giá trị
  template đã gắn sẵn trên từng PO ở D365 (reference type = 16) — người dùng KHÔNG tự chọn template
  thủ công ở Step 1, chỉ chọn PO nào áp dụng cho hồ sơ EUTR.
- "Save PO Mapping" ghi đè toàn bộ tập `PurchId` hiện có của Sales ID đó trong
  `eutr_purchase_attachments` theo đúng lựa chọn hiện tại trên UI (PO bị bỏ chọn bị xóa khỏi bảng,
  PO mới chọn được thêm mới) — không tích lũy lịch sử các lần Save trước đó.
- Nút Upload và Edit ở Step 2 (Map Files vào Template) nay dùng lại **nguyên trạng** popup Add/Edit
  tài liệu của 004-eutr-documents (từ Update 6) — mọi quy tắc trường dữ liệu, validate file, và luồng
  ghi dữ liệu (tạo/cập nhật `eutr_documents`/`eutr_references`) áp dụng đúng như đặc tả gốc của
  004-eutr-documents, không định nghĩa lại hay rút gọn quy tắc riêng cho Map File. Popup Add mở ở Step
  2 là popup đầy đủ (không khóa/tự điền Type/Step/Value theo PO hay node cây đang chọn) — người dùng tự
  chọn như khi thao tác trực tiếp từ màn hình EUTR Documents.
- "PO chưa gắn vào Template" trong yêu cầu Update 3 được hiểu là PO **chưa có bản ghi** trong
  `eutr_purchase_attachments` (chưa từng được Save PO Mapping cho Sales Order này) — khác với trường
  hợp PO hoàn toàn không có giá trị template từ D365 (trường hợp này vẫn bị chặn chọn theo FR-022).
  Miễn PO có sẵn template từ D365, PO đó luôn có thể được tick chọn dù đã lưu hay chưa.
- TemplateCode lưu cho các PO mới chọn thêm vẫn lấy từ cột `eutrTemplate` của nguồn dữ liệu PO ở
  Step 1 (reference type = 16) — theo đúng xác nhận của người yêu cầu tính năng, không có cơ chế nhập
  Template thủ công nào được bổ sung ở Update 3.
- Nút Back điều hướng thẳng về màn hình EUTR Sales Orders, tương đương hành vi đã có sẵn của liên kết
  breadcrumb trên cùng màn hình Map File — không cần xác nhận rời trang dù có thay đổi chưa lưu.
- Màn hình View chỉ hiển thị các Purchase Order **đã lưu** (đã Save PO Mapping) cho Sales Order đó —
  khác với Step 1 Map File vốn hiển thị toàn bộ PO khả dụng từ D365 để người dùng chọn; View không
  cần hiển thị các PO chưa được chọn/lưu vì đây là màn hình xem tổng quan hồ sơ đã hoàn thiện, không
  phải màn hình chọn PO.
- Các cột hiển thị cho Purchase Orders đã chọn ở màn hình View (PO, Name, Order account, Qty) dùng lại
  đúng bộ trường thật đã có sẵn từ nguồn tham chiếu reference type = 16 (giống Step 1 Map File) — các
  cột demo cũ (Vendor/Vendor Name/Rate/Material) không còn nguồn dữ liệu thật tương ứng nên được thay
  thế, việc ánh xạ cột cụ thể (giữ/đổi tên) là quyết định kỹ thuật ở giai đoạn plan, không thuộc phạm
  vi đặc tả nghiệp vụ ở đây.
- Do dữ liệu tài liệu thật hiện lấy từ `eutr_references`/`eutr_documents` chưa có thông tin ngày hết
  hạn (validFrom/expiredDate), điều kiện "File không hết hạn" trong Validation Summary phiên bản mock
  trước đây tạm thời không áp dụng được với dữ liệu thật; Validation Summary màn hình View chỉ còn 2
  điều kiện chính: đã chọn ít nhất 1 PO, và Required steps đủ file — cho tới khi có nguồn dữ liệu hạn
  sử dụng tài liệu thật ở một cập nhật sau.
- Nút Submit EUTR (nếu còn giữ trên giao diện màn hình View) không thuộc phạm vi Update 4 — tiếp tục ở
  trạng thái demo/disabled, tính theo 2 điều kiện Validation Summary nêu trên; xử lý submit thật để
  lại cho một tính năng sau.
- Việc mở rộng/thu gọn (expand/collapse) node cây ở Template Checklist của màn hình View không được
  coi là hành vi chỉnh sửa dữ liệu — chỉ là tương tác hiển thị cục bộ trên UI, không gọi API ghi nào.
- Hành vi click vào một template ở toolbar cây template (`data-marker="template-tree-toolbar"`) áp
  dụng chung cho toàn bộ `templatesData` — bất kể người dùng click vào chip template nào, hệ thống
  đều tải lại toàn bộ danh sách template đang gắn với Sales Order này (không tải lại riêng lẻ từng
  template), vì Step 2 luôn hiển thị đồng thời tất cả các cây template của Sales Order đó.
- Nếu một tài liệu có nhiều bản ghi `eutr_references` khác nhau trong cùng ngữ cảnh PO (nhiều Step
  gắn cùng lúc cho cùng một tài liệu/PO), File type/PO value hiển thị theo bản ghi đầu tiên tìm được
  cho tài liệu đó — trong nghiệp vụ hiện tại, `RefType`/`RefValue` thực tế nhất quán theo từng cặp
  (tài liệu, PO), nên trường hợp giá trị khác nhau giữa các bản ghi của cùng một tài liệu/PO là hiếm.
- Tên hiển thị cho File type tra cứu qua `eutr_reference_types` theo `RefType`, theo đúng mẫu tra cứu
  tên từ mã/id đã dùng ở các cột khác trong hệ thống (ví dụ cột Type ở `004-eutr-documents`), không
  hiển thị mã số `RefType` thô.
- Mỗi `PurchId` trong `eutr_purchase_attachments` chỉ gắn với đúng 1 `TemplateCode` (đúng ràng buộc dữ
  liệu hiện có của bảng này) — đây là cơ sở duy nhất và đủ để xác định một tài liệu (qua PO/`RefValue`
  của nó) thuộc về template nào, phục vụ việc lọc AVAILABLE FILES và xác định Map status theo đúng
  PO/Template (Update 7, FR-053 đến FR-057); không có trường hợp một PO cùng lúc gắn nhiều template
  khác nhau cần xử lý.
- Việc lọc AVAILABLE FILES theo template đang xem (Update 7) áp dụng cho cả khu vực hiển thị danh sách
  tài liệu lẫn các phép tính phái sinh dùng chung tập tài liệu đó (tìm kiếm, phân trang) — tìm kiếm/
  phân trang ở AVAILABLE FILES (đã có sẵn) tiếp tục hoạt động trên đúng tập tài liệu đã được lọc theo
  template, không cần thay đổi cơ chế tìm kiếm/phân trang hiện có.
- Khác với Map File (nơi click chọn template ở toolbar còn kích hoạt tải lại `templatesData` để làm
  mới trạng thái map — FR-048), màn hình View là chỉ đọc và không có luồng chỉnh sửa nào diễn ra ngay
  trên chính màn hình này; do đó việc click chọn template ở toolbar của View (Update 8) chỉ cần đổi
  template nào đang hiển thị dựa trên dữ liệu đã tải khi mở trang, không bắt buộc phải tải lại dữ liệu
  từ nguồn thật ở mỗi lượt click. Nếu về sau phát sinh yêu cầu làm mới dữ liệu chủ động trên màn hình
  View, đó sẽ là phạm vi của một cập nhật khác.
- Cơ chế chọn xem 1 template tại 1 thời điểm ở toolbar cây template của màn hình View (Update 8) dùng
  lại đúng cách xác định "template đầu tiên" (mặc định) và cách xác định PO ↔ Template (qua
  `eutr_purchase_attachments`) đã áp dụng cho Map File Step 2 (Update 5/Update 7) — không định nghĩa
  quy tắc thứ tự hay khóa phân biệt riêng cho màn hình View.
- Popup View (Update 9) dùng lại **nguyên trạng** popup xem trước nội dung file đã có sẵn ở màn hình
  EUTR Documents (004-eutr-documents) — cùng cơ chế lấy nội dung file thật (theo `fileId` của tài
  liệu), cùng danh sách loại file được hỗ trợ hiển thị (PDF/Word/Excel/ảnh...) và cùng trạng thái
  "không xem trước được" cho loại file ngoài danh sách đó — không định nghĩa lại hay mở rộng thêm quy
  tắc hiển thị nội dung file riêng cho Map File.
- Vị trí cụ thể "kế" nút Edit (bên trái hay bên phải) và biểu tượng chính xác cho nút View là quyết
  định thiết kế giao diện ở giai đoạn kỹ thuật (plan), không thuộc phạm vi đặc tả nghiệp vụ ở đây —
  yêu cầu duy nhất là nút View đặt liền kề, cùng nhóm control với nút Edit trên mỗi dòng tài liệu.
- (Update 10) Theo xác nhận của người yêu cầu tính năng, mỗi thư mục con template trong file zip
  Download **chỉ** chứa tài liệu có Map status = "Mapped" cho đúng template đó (áp dụng đúng quy tắc
  PO/Template ở FR-055/FR-056) — tài liệu "No map" bị loại khỏi phạm vi tải xuống, kể cả khi tài liệu
  đó thuộc đúng PO của template đang xét nhưng không khớp node nào trong cây.
- (Update 10) Tên thư mục con cho mỗi template trong file zip dùng **tên thật** của template (tra
  `eutr_templates.Name`), không dùng nhãn thứ tự cố định ("Template 01"/"Template 02"...) — nhất quán
  với cách hệ thống luôn hiển thị tên thay vì mã/thứ tự ở các nơi khác (toolbar cây template, cột
  Template ở Overview).
- (Update 10) Khi không có tài liệu "Mapped" nào để tải (chưa có template nào, hoặc có template nhưng
  không template nào có tài liệu Mapped), nút Download vẫn luôn ở trạng thái bấm được (không disable);
  hệ thống chỉ hiển thị thông báo lỗi/thông tin cho biết không có gì để tải khi người dùng thực sự nhấn
  nút — không cần kiểm tra trước để disable nút một cách chủ động.
- (Update 10) Định dạng nén cụ thể (zip), thư viện/cơ chế tạo file nén (tạo ở phía server hay phía
  client), và cách tải nội dung file thật để đóng gói (tái sử dụng cơ chế lấy nội dung file đã có ở
  popup View/004-eutr-documents hay xây luồng riêng) là quyết định kỹ thuật ở giai đoạn plan, không
  thuộc phạm vi đặc tả nghiệp vụ ở đây — yêu cầu duy nhất là kết quả tải xuống là một file nén có đúng
  cấu trúc thư mục gốc/thư mục con/file đã mô tả ở Update 10.
- (Update 10) Việc phân biệt tên file khi trùng tên gốc trong cùng một thư mục con (FR-075) chỉ cần áp
  dụng trong phạm vi từng thư mục con template — hai file trùng tên ở hai thư mục con khác nhau (thuộc
  hai template khác nhau) không cần phân biệt gì thêm vì đã nằm ở hai thư mục riêng biệt.
- (Update 11) `AUTO_SOURCES` (`['D365-Invoice', 'D365-PackingList', 'D365']`) là danh sách `takeFrom`
  cũ dành cho khái niệm "tự động phát hiện từ D365" của bản mock trước đây; với dữ liệu thật hiện tại
  (`eutr_template_details`), `takeFrom` chỉ nhận giá trị "PO" hoặc "Upload manual", không bao giờ khớp
  `AUTO_SOURCES` — vì vậy việc bổ sung loại trừ này vào `progress.total`/`progress.completed` (FR-079)
  hiện chưa tạo ra khác biệt quan sát được trên số liệu thật, đây là một sửa lỗi nhất quán giữa các biến
  để đề phòng trường hợp `AUTO_SOURCES` được dùng lại trong tương lai, không phải một thay đổi hành vi
  cấp thiết với dữ liệu hiện có.
- (Update 11) "Đã có tài liệu"/"đã map" cho một step Required tiếp tục dùng đúng định nghĩa hiện có (một
  step được tính là "đã map" khi có tối thiểu 1 tài liệu thỏa quy tắc PO/Template ở FR-055/FR-056) —
  Update 11 không thay đổi cách xác định một step cụ thể đã "đã map" hay chưa, chỉ thêm điều kiện loại
  trừ `AUTO_SOURCES` khi đếm vào `progress.total`/`progress.completed` cho nhất quán với `missingRequired`.
- (Update 11) Biến `missingRequired` (phục vụ chỉ báo "Still missing X file" ở footer Step 2 của Map
  File) và biến `progress.total`/`progress.completed` vẫn là hai biến độc lập trong cùng màn hình —
  Update 11 chỉ thêm quy tắc loại trừ `AUTO_SOURCES` vào cách tính của `progress.total`/
  `progress.completed` để hai biến này nhất quán với nhau (`total - completed` = `missingRequired`),
  không gộp chung hay thay thế biến nào.
