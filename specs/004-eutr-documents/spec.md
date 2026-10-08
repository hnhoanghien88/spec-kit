# Feature Specification: EUTR Documents Management

**Feature Branch**: `004-eutr-documents`

**Created**: 2026-07-07

**Status**: Draft

**Input**: User description: "chức năng mới eutr-documents tổng quan theo Eutr\docs\design\eutr\eutr_documents_overview.md"

## Clarifications

### Session 2026-10-08 (Update 32) — Type = "PO": chỉ khớp Step trong Template của PO; PO chưa gắn Template thì chặn Upload

- Input: "template có step là `APH Business License`, dữ liệu step có `APH Business License` và `APH Business License(AP)`. File úp là `APH Business License(AP).pdf` => phải gắn step `APH Business License` nhưng lại gắn vào step `…(AP)`. Phải dựa vào step của template mà gắn chứ không phải toàn bộ step trong dữ liệu"; "PO chưa gắn template thì nên chặn upload và báo lỗi"; "edit dialog và cập nhật spec luôn".
- Bối cảnh (rà soát mã): Update 29 khớp tên file trên TOÀN BỘ `eutr_steps`, Update 31 chọn Step có Name dài nhất → file khớp cả Step trong Template lẫn Step dài hơn nằm ngoài Template thì luôn bị gắn vào Step ngoài Template (file hiển thị "No map", Step của Template vẫn "Required - missing").
- Change: (1) `EutrUploadService.UploadMultipleToSharePointAndSaveDataAsync` MUST chỉ khớp tên file với các Step thuộc Template đã gắn cho PO (TemplateCode của PO lấy từ D365 — cùng nguồn màn hình 012/005: `RSVNEutrPurchOrders.EutrTemplate`, fallback `RSVNEutrSalesOrderPurchases.RSVNEutrTemplate`; KHÔNG dùng bảng `eutr_purchase_attachments` vì PO có Template ở D365 chưa chắc đã có dòng ở bảng này → `eutr_template_details.StepId`); quy tắc "Name dài nhất, hoà Id nhỏ nhất" (Update 31) giữ nguyên nhưng chỉ áp dụng trong tập Step này. (2) PO chưa gắn Template (hoặc Template không có Step) → MUST chặn Upload: mọi file trả `Success=false`, `ErrorMessage` = "PO has no template assigned. Please assign a template before uploading.", không tạo thư mục/không upload SharePoint, không ghi DB. (3) Popup Edit document Type "PO": combobox Step MUST chỉ liệt kê Step thuộc Template của PO (lấy qua endpoint mới `POST /api/eutr-documents/po-template-step-ids`) mà tên có trong tên file; Step hiện tại của document vẫn luôn có mặt (FR-045). Upload theo Type khác (`eutr-upload-multi-by-type`, Step do người dùng chọn) KHÔNG đổi. Dữ liệu cũ không tự đổi.

### Session 2026-10-08 (Update 31) — Type = "PO": 1 document chỉ thuộc 1 Step (đảo lại multi-match của Update 29)

- Input: "1 document chỉ cho 1 step, nếu ở nhiều step là sai" → chọn phương án: khi tên file khớp nhiều Step, chọn 1 Step.
- Bối cảnh (rà soát mã): `EutrUploadService.UploadMultipleToSharePointAndSaveDataAsync` ghi 1 dòng `eutr_references` cho MỖI Step khớp (multi-match, Update 29/Quyết định 79) → 1 document có nhiều Step; popup Edit chỉ thấy 1 Step và Save ghi đè mọi dòng về 1 Step.
- Change: Khi file khớp nhiều Step, hệ thống MUST chọn đúng 1 Step — Step có Name dài nhất (khớp cụ thể nhất); bằng độ dài thì Step có Id nhỏ nhất — và chỉ ghi dòng reference cho Step đó. Khớp 0 Step vẫn báo lỗi như cũ. Dữ liệu cũ không tự đổi.

### Session 2026-09-30 (Update 30) — Popup Add: ẩn Valid from/Valid to trừ khi Type = "Vendor"

- Input: "ẩn 2 thông tin valid from, to. mặc định là today > maxdate. Nếu type là vendor mới hiển thị"
  (kèm ảnh chụp popup "Add EUTR documents" với Type = "PO" đang hiển thị 2 trường Valid from/Valid to).
- Change: Ở popup Add (mode `add`), hai trường **Valid from** và **Valid to** MUST chỉ hiển thị khi
  Type đã chọn có `Name` = "Vendor" (không phân biệt hoa/thường) — mọi Type khác (bao gồm "PO",
  "Invoice", "Delivery note", "General agreement", và Type mới) MUST ẩn hoàn toàn 2 trường này.
- Change: Khi 2 trường bị ẩn, hệ thống MUST tiếp tục dùng đúng giá trị mặc định hiện có khi Upload —
  Valid from = ngày hiện tại tại thời điểm mở popup, Valid to = ngày tối đa `9999-12-31` — người dùng
  không có cách nào chỉnh sửa 2 giá trị này khi Type khác "Vendor" (phải đổi sang Type "Vendor" để hiển
  thị lại và sửa, hoặc dùng Edit sau khi document đã tạo — xem Q&A bên dưới).
- Change: Đổi Type từ "Vendor" sang Type khác (khi 2 trường đang hiển thị, đã có thể đã sửa giá trị)
  MUST reset lại Valid from/Valid to về đúng giá trị mặc định (ngày hiện tại/`9999-12-31`) trước khi ẩn
  đi — tránh gửi lên giá trị người dùng đã lỡ sửa khi trường đó không còn hiển thị để xác nhận lại.
- Q: Có ảnh hưởng gì tới popup Edit không? → A: **Không** — Edit (mode `edit`) tiếp tục hiển thị Valid
  from/Valid to cho **mọi** Type như hiện có (FR-030 không đổi), vì document đã tạo có thể đang giữ giá
  trị khác mặc định (do người dùng từng sửa khi Type là "Vendor", hoặc do Edit hiện tại vẫn cho sửa cả
  2 trường bất kể Type) — ẩn ở Edit sẽ khiến người dùng mất khả năng xem/sửa giá trị thật đang lưu, yêu
  cầu gốc cũng chỉ nêu ảnh chụp màn hình Add.
- Q: Validate "Valid from ≤ Valid to" (FR-016) có còn cần khi 2 trường bị ẩn không? → A: Về logic vẫn
  giữ nguyên nhưng luôn PASS khi ẩn — giá trị mặc định (hôm nay ≤ `9999-12-31`) luôn hợp lệ, không có
  cách nào người dùng tạo ra giá trị không hợp lệ khi trường bị ẩn (không có ô nhập nào để sửa sai).

### Session 2026-09-30 (Update 29) — Type = "PO": bỏ khớp Prefix qua `eutr_master_documents`, thay bằng so khớp tên Step (đã gán cho Type "PO") với tên file; bỏ đổi tên file khi Upload

- Input: "cập nhật 004-eutr-documents, 005-eutr-sales-orders, 012-eutr-purchase-orders khi upload
  file với type = PO, bỏ logic kiểm tra với eutr_master_documents. thay đổi thành so sánh tên step
  với tên file, nếu tên file chứa tên step sẽ gán file vào step đó, file không chứa thì báo lỗi up
  không thành công do tìm không được step tương ứng. Màn hình hiển thị template, khi file đã upload,
  phần tên step sẽ lấy tên file gắn vào để hiện thị (...) file chưa upload thì hiển thị tên step bình
  thường, bỏ logic đổi tên file theo tên step, tên file ntn giữ nguyên khi up và khi tải".
- Bối cảnh: Rà soát mã nguồn xác nhận nhánh Type = "PO" (`EutrUploadService.UploadMultipleToSharePointAndSaveDataAsync`)
  hiện gọi `EutrMastersRepository.GetMatchingPrefixesAsync` để so khớp tên file gốc với `Prefix` trong
  `eutr_master_documents` (`fileName.StartsWith(Prefix)`, không phân biệt hoa/thường — FR-020), rồi
  dùng bản ghi thắng cuộc (Prefix dài nhất, tie-break `Id` nhỏ nhất) để: (a) xác định (các) `StepId`
  ghi vào `eutr_references` (FR-023), và (b) tính File name mới = Step Name đã làm sạch (FR-062 đến
  FR-070, kể từ Update 26 không còn cộng Prefix). Cùng cơ chế `GetMatchingPrefixesAsync` cũng được
  `GetDistinctStepsAsync`/`GetMatchingStepsAsync` (`EutrMastersController.GetSteps`) dùng để nạp danh
  sách Step cho combobox Step khi Edit một document Type = "PO".
- Decision (xác nhận qua `AskUserQuestion`, **sau đó sửa lại** — xem "Sửa lại sau kiểm thử thật" bên
  dưới): Tập Step dùng để so khớp tên file khi Type = "PO" **ban đầu** chọn là các
  Step **đã được gán cho Type "PO"** qua tính năng Assign Steps (`eutr_reference_type_details`,
  `TypeId` = `Id` của Type "PO") — đúng cơ chế đã dùng cho mọi Type khác từ Update 20 (FR-020 cũ của
  Update 20). Kiểm thử thật sau khi triển khai cho thấy quyết định này **sai** — `eutr_reference_type_details`
  không hề liên quan tới cây Step hiển thị trên màn Map File/`PurchId/View` (nguồn hiển thị thật là
  `eutr_template_details`, một bảng khác hoàn toàn) nên gần như luôn RỖNG cho Type "PO", khiến MỌI file
  hợp lệ đều bị báo "không tìm được step tương ứng" dù Step đó rõ ràng hiển thị trên cây Template. Đã
  sửa lại: dùng **toàn bộ `eutr_steps`** (danh sách phẳng, không lọc theo Type) — đúng tính chất "phẳng,
  không giới hạn Type" mà `eutr_master_documents` vốn đã có trước đây (bảng đó cũng không có ràng buộc
  Type nào).
- Change: **Thay thế hoàn toàn** cơ chế xác định (các) `StepId` khớp khi Type = "PO" (thay FR-020):
  hệ thống KHÔNG còn tra `eutr_master_documents`/`Prefix`. Với mỗi file trong lượt Upload, hệ thống
  MUST so khớp tên
  file gốc (không phân biệt hoa/thường) có **CHỨA** `Name` của Step nào trong **toàn bộ `eutr_steps`**
  hay không (khác quy tắc cũ "bắt đầu bằng Prefix") — mọi Step có `Name` xuất hiện ở bất kỳ vị trí nào
  trong tên file đều được coi là khớp; một file vẫn có thể khớp nhiều Step cùng lúc (không giới hạn số
  lượng, kế thừa tinh thần khớp-nhiều-Prefix cũ).
- Change: File **không chứa** tên của bất kỳ Step nào trong `eutr_steps` MUST
  bị loại khỏi lượt upload kèm thông báo lỗi nêu rõ lý do "không tìm được step tương ứng" — không tạo
  document/`eutr_references` cho file đó; các file hợp lệ khác trong cùng lượt KHÔNG bị ảnh hưởng
  (giữ nguyên tinh thần FR-025).
- Change: Với mỗi Step khớp, hệ thống tiếp tục ghi một bản ghi `eutr_references` (cơ chế FR-023
  không đổi) — chỉ khác nguồn xác định "khớp" (tên Step thay vì Prefix).
- Change: **Bỏ hẳn** việc đổi tên file khi Upload cho nhánh Type = "PO" (vô hiệu phần Type = "PO" của
  FR-063/FR-068/FR-069 kể từ Update này) — sau khi xác định xong danh sách Step khớp, hệ thống KHÔNG
  còn chọn "Step thắng cuộc" và KHÔNG còn tính File name mới nào cho nhánh này nữa.
  `eutr_documents.Name` MUST lưu **đúng tên file gốc** người dùng đã chọn (giữ nguyên toàn bộ tên,
  bao gồm phần mở rộng) — y hệt hành vi trước khi có logic đổi tên (trước Update 25). Nhánh Type khác
  "PO" (FR-062/FR-064/FR-068, đổi tên = Step Name đã chọn) KHÔNG bị ảnh hưởng bởi Update này, giữ
  nguyên không đổi.
- Change: Cơ chế hậu tố ngẫu nhiên 6 ký tự chống trùng tên vật lý trên SharePoint (FR-065) tiếp tục áp
  dụng cho nhánh Type = "PO", nhưng nay dựa trên **tên file gốc** (vì không còn tên đã đổi).
- Change: Combobox Step ở popup Edit khi sửa document Type = "PO" (hiện nạp qua
  `GetDistinctStepsAsync`/`GetMatchingStepsAsync`, dựa trên `GetMatchingPrefixesAsync`) MUST đổi nguồn
  sang danh sách Step khớp theo tên trong **toàn bộ `eutr_steps`** (cùng quy tắc Change ở trên), tính
  trên tên file đã lưu của document đang sửa (`eutr_documents.Name`, nay là tên file gốc) — để nhất
  quán với logic Upload mới.
- Change: Bảng `eutr_master_documents` và toàn bộ CRUD/Import/Export của nó (`EutrMastersController`,
  thuộc feature `002-eutr-masters`) KHÔNG bị xóa hay thay đổi — chỉ không còn được luồng Upload/Edit
  Type = "PO" của feature này tham chiếu nữa.
- Q: So khớp tên file chứa tên Step có phân biệt hoa/thường không? → A: Không — kế thừa nguyên tắc so
  khớp không phân biệt hoa/thường đã dùng cho Prefix ở FR-020 cũ.
- Q: Nếu `eutr_steps` rỗng (chưa cấu hình Step nào trong toàn hệ thống)? → A: Mọi
  file upload với Type = "PO" đều bị loại kèm lỗi "không tìm được step tương ứng" — tương tự trường
  hợp `eutr_master_documents` rỗng trước đây; đây không phải lỗi hệ thống, cần tạo Step trước (màn
  `001-eutr-steps`).
- Q: **Sửa lại sau kiểm thử thật** — Vì sao quyết định ban đầu (Steps đã gán cho Type "PO" qua Assign
  Steps) sai? → A: Rà soát lại xác nhận `eutr_reference_type_details` (Assign Steps) là một cơ chế
  HOÀN TOÀN riêng biệt, không liên quan gì tới cây Step hiển thị trên màn Map File (`005-eutr-sales-orders`)/
  `PurchId/View` (`012-eutr-purchase-orders`) — cây đó lấy Step từ `eutr_template_details` (gắn theo
  Template, feature `003-eutr-templates`). Không có gì đảm bảo (và thực tế kiểm thử cho thấy không có)
  Step nào từng được gán cho Type "PO" qua màn Assign Steps, nên `assignedSteps` luôn rỗng và MỌI file
  hợp lệ đều bị báo lỗi sai — kể cả khi tên file chứa đúng tên một Step đang hiển thị rõ ràng trên cây
  Template. Sửa lại dùng toàn bộ `eutr_steps` giải quyết đúng vấn đề này, đồng thời khớp lại đúng tính
  chất "phẳng, không giới hạn theo Type" mà `eutr_master_documents` (cơ chế cũ) vốn đã có.
- Q: Document Type = "PO" tạo TRƯỚC bản cập nhật này (File name hiện đang là Step Name do bị đổi tên
  ở Update 25/26) có bị tính toán/hiển thị lại tên không? → A: Không — không migration/backfill dữ
  liệu cũ; document cũ giữ nguyên File name đã lưu; chỉ document Upload MỚI sau bản cập nhật này mới
  giữ tên file gốc.

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

### Session 2026-08-17 (Update 23) — Thêm trường Invoice number khi Type = "Invoice"

- Input: "cập nhật 004-eutr-documents chức năng Add EUTR documents, với type = Invoice thì hiển thị
  thêm 1 cột string để nhập số Invoice. sau đó lưu vào bảng eutr_references, cột Invoice mới thêm".
- Input (sửa lại): "cập nhật lại spec trên. không lưu Invoice vào bảng eutr_references, chuyển sang
  lưu vào bảng eutr_documents, cột Invoice" — đổi nơi lưu trữ từ `eutr_references` sang
  **`eutr_documents`** (cột mới **`Invoice`**, một giá trị duy nhất trên mỗi document, không phải một
  giá trị lặp lại trên nhiều bản ghi `eutr_references`).
- Change: Popup Add (và popup Edit ở chế độ sửa, khi Type hiện tại của document = "Invoice") bổ sung
  một trường nhập liệu mới **Invoice number** (ô nhập tự do, kiểu chuỗi) — MUST chỉ hiển thị khi Type
  đang chọn (Add) hoặc Type hiện tại đã khóa (Edit) có `Name` = "Invoice". Type khác "Invoice" MUST
  không hiển thị trường này.
- Change: Trường Invoice number MUST bắt buộc nhập (không rỗng/không chỉ khoảng trắng) khi Type =
  "Invoice" — nút Upload (Add) MUST tiếp tục ở trạng thái vô hiệu hóa cho tới khi trường này có giá
  trị, cạnh các điều kiện hiện có (FR-017); Save (Edit) MUST tương tự bị chặn nếu trường này rỗng.
- Change: Với mỗi file upload thành công trong một lượt Upload (Type = "Invoice"), hệ thống MUST ghi
  giá trị Invoice number đang hiển thị ở popup tại thời điểm Upload vào cột mới **`Invoice`** (chuỗi,
  nullable) trên chính bản ghi **`eutr_documents`** vừa tạo cho file đó — cùng document, KHÔNG ghi vào
  bảng `eutr_references`. Mỗi file trong cùng lượt Upload tạo một document riêng, nên mỗi document
  nhận đúng một giá trị Invoice number (giá trị nhập trong popup áp dụng cho mọi document tạo ra từ
  cùng lượt Upload đó, cùng cách Valid from/Valid to đã áp dụng — Update 19).
- Change: Ở popup Edit, khi Type hiện tại (đã khóa) của document = "Invoice", trường Invoice number
  MUST nạp sẵn giá trị `Invoice` hiện có của **chính document đang sửa** (không cần tra cứu qua
  `eutr_references`) và MUST cho phép sửa. Nhấn Save MUST cập nhật trực tiếp cột `Invoice` của
  `eutr_documents` cho document đó thành giá trị mới — cùng cách Save đã cập nhật `ValidFrom`/`ValidTo`
  (FR-033), không liên quan/không ảnh hưởng tới bất kỳ bản ghi `eutr_references` nào.
- Change: Với Type khác "Invoice" (bao gồm document Type trống), cột `Invoice` trên `eutr_documents`
  tiếp tục MUST là `null` — không luồng nào khác trong feature này ghi giá trị cho cột này.
- Q: Cột `Invoice` mới có ràng buộc duy nhất (unique) trên toàn hệ thống không? → A: **Không** — yêu
  cầu gốc chỉ nói "1 cột string để nhập số Invoice", không đề cập ràng buộc duy nhất; nhiều document
  được phép trùng giá trị Invoice number, tương tự cách File name không có ràng buộc duy nhất
  (FR-007b hiện có).
- Q: Cột Conditions trên bảng danh sách chính (FR-005, lấy từ `RefValue` của `eutr_references`) có
  hiển thị thêm giá trị Invoice number không? → A: **Không** — Conditions tiếp tục chỉ lấy từ
  `RefValue` như hiện tại; Invoice number là một cột riêng trên `eutr_documents`, không hiển thị lẫn
  vào cột Conditions ở phạm vi cập nhật này.
- Q: Search box (User Story 6, Update 21) có lọc theo Invoice number không? → A: **Không** — nằm
  ngoài phạm vi yêu cầu gốc của cập nhật này; ba điều kiện lọc hiện có (Type/Step name/Conditions)
  không đổi.
- Q: Vì sao đổi từ `eutr_references` sang `eutr_documents`? → A: `eutr_documents` là bảng 1-dòng-1-
  document sẵn có (giống `Name`/`ValidFrom`/`ValidTo`), nên lưu Invoice number trực tiếp trên đó tránh
  hẳn việc phải đồng bộ cùng một giá trị trên nhiều bản ghi `eutr_references` (vốn có thể nhiều dòng
  cho cùng document, ví dụ nhiều `StepId` khớp) — đơn giản hơn cả ở ghi (Upload) lẫn sửa (Edit/Save),
  không còn quy tắc "lấy theo bản ghi `Id` nhỏ nhất" như Step (FR-032) hay rủi ro các dòng
  `eutr_references` của cùng document lệch giá trị Invoice number với nhau.

### Session 2026-08-17 (Update 24) — Hiển thị cột Invoice trên màn hình danh sách (index), sau cột Step name

- Input: "cập nhật spec, hiển thị thêm cột Invoice ở màn hình index, sau cột Step name".
- Change: Bảng danh sách chính (User Story 1) bổ sung cột **Invoice**, đặt ngay sau cột **Step name**
  (thứ tự cột đầy đủ: File name, Step name, **Invoice**, Conditions, Type, Valid from, Valid to,
  Created by, Created date, Action).
- Change: Cột Invoice hiển thị trực tiếp giá trị `eutr_documents.Invoice` của chính document đó (cột
  đã có sẵn từ Update 23) — KHÔNG cần tra cứu qua `eutr_references` (khác Step name/Conditions/Type).
  Document có `Invoice = null` (Type khác "Invoice", hoặc document cũ trước Update 23) MUST hiển thị
  cột này ở trạng thái trống.
- Q: Cột Invoice hiển thị dạng gì — văn bản đơn thuần hay chip giống Conditions/Step name? → A: **Văn
  bản đơn thuần** (plain text) — mỗi document chỉ có đúng một giá trị `Invoice` (không phải danh sách
  nhiều giá trị như Step name/Conditions), nên không cần mẫu chip/"+N more".
- Q: Search box (User Story 6) có bổ sung điều kiện lọc theo Invoice không? → A: **Không** — nằm ngoài
  phạm vi yêu cầu gốc của cập nhật này; search box tiếp tục chỉ gồm Type/Step name/Conditions (Update
  21), không đổi.

### Session 2026-09-18 (Update 25) — Tự động đổi tên file theo Step (+ Prefix của master nếu có) khi Upload

- Input: "cập nhật 004-eutr-documents khi upload file, sẽ tự động đổi tên file theo step, nếu step có
  cấu hình trong master, thì lấy prefix gắn vào phía trước nữa (tên xóa đi những ký tự đặc biệt \ ..
  để khỏi lỗi)"; sau đó bổ sung "áp dụng logic này cho upload file ở màn hình 005-eutr-sales-orders,
  012-eutr-purchase-orders" (xem mục kế thừa ở cuối phần này).
- Change: Với **Type khác "PO"** (Step được chọn tường minh ở combobox Step trong popup Add, FR-010),
  mỗi file upload thành công trong lượt Upload đó KHÔNG còn giữ tên file gốc làm File name — hệ thống
  MUST tự động tính một **tên file mới**: (a) tra `eutr_master_documents` theo `StepId` của Step đã
  chọn; nếu có ít nhất một bản ghi (`Prefix` khác null/rỗng), lấy `Prefix` của bản ghi có `Id` nhỏ nhất
  trong số đó; nếu không có bản ghi nào (Step chưa được "cấu hình trong master"), không có Prefix; (b)
  tên file mới = (Prefix nếu có) + `Name` của Step đã chọn, nối trực tiếp không có ký tự phân cách, đã
  qua bước làm sạch (xem dưới); (c) giữ nguyên đuôi file gốc (phần mở rộng, ví dụ `.pdf`). `eutr_documents.Name`
  MUST lưu đúng tên mới này — tên file gốc người dùng chọn KHÔNG còn được lưu/hiển thị ở bất kỳ đâu sau
  khi upload thành công.
- Change: Với **Type = "PO"**, logic xác định (các) `StepId` khớp Prefix trong `eutr_master_documents`
  (so khớp phần đầu tên file gốc, có thể khớp nhiều `StepId`, FR-020) MUST giữ nguyên không đổi — vẫn
  tạo đủ một bản ghi `eutr_references` cho mỗi `StepId` khớp (FR-023 không đổi). Sau khi khớp xong, hệ
  thống MUST bổ sung thêm một bước đổi tên file: trong số các bản ghi `eutr_master_documents` đã khớp,
  chọn bản ghi có `Prefix` **dài nhất** (khớp cụ thể/đặc hiệu nhất với tên file gốc) — nếu nhiều bản ghi
  cùng độ dài Prefix dài nhất, chọn bản ghi có `Id` nhỏ nhất trong số đó; dùng đúng `Prefix` và `StepId`
  (→ `Name`) của bản ghi thắng cuộc này để tính tên file mới theo đúng công thức (Prefix + Step Name,
  làm sạch, giữ đuôi file) như Type khác "PO" ở trên. `eutr_documents.Name` MUST lưu tên mới này — tên
  file gốc không còn được giữ lại.
- Change: **Bước làm sạch tên** (áp dụng cho phần Prefix + Step Name trước khi nối vào nhau, cho cả hai
  luồng Type = "PO" và Type khác "PO"): hệ thống MUST loại bỏ mọi ký tự không hợp lệ làm tên file trên
  hệ điều hành/SharePoint (tối thiểu `\ / : * ? " < > |`) và loại bỏ mọi chuỗi hai dấu chấm liên tiếp
  (`..`) khỏi kết quả, để tránh lỗi khi tạo/tải file lên SharePoint. Nếu sau khi làm sạch, phần
  Prefix + Step Name trở thành rỗng (ví dụ Step Name chỉ chứa toàn ký tự bị loại bỏ, hoặc trống), hệ
  thống MUST dùng tên dự phòng `Step{StepId}` (ví dụ `Step12`) làm phần tên trước khi thêm đuôi file,
  để đảm bảo luôn có một tên file hợp lệ.
- Change: Tên dùng để tải file thật lên SharePoint (khác với `eutr_documents.Name`, vốn đã có cơ chế
  hậu tố ngẫu nhiên 6 ký tự để tránh trùng tên vật lý trên SharePoint) MUST tiếp tục áp dụng cùng cơ
  chế hậu tố ngẫu nhiên đó, nhưng dựa trên **tên file mới** (Prefix + Step Name đã làm sạch) thay vì tên
  file gốc.
- Change: Vì tên file mới chỉ phụ thuộc Type/Step (và Prefix của master, nếu có) — không còn phụ thuộc
  tên file gốc — nhiều file khác nhau được upload cùng một lượt (hoặc nhiều lượt khác nhau) với cùng
  Type/Step (hoặc, với PO, cùng bản ghi master thắng cuộc) MUST tạo ra các document có File name **giống
  hệt nhau** (ví dụ nhiều file PDF upload cho cùng Step "Invoice" có Prefix "INV" đều có File name =
  "INVInvoice.pdf") — đây là hành vi được chấp nhận, kế thừa nguyên tắc File name không có ràng buộc
  duy nhất đã có (xem Edge Cases hiện có).
- Change: Chế độ sửa (Edit, User Story 3) KHÔNG bị ảnh hưởng — Edit không upload lại file, không tính
  toán lại tên file; File name của document hiện có giữ nguyên (kể cả khi người dùng đổi Step trong
  Edit, theo FR-029/FR-033 hiện có) — logic đổi tên ở Update này CHỈ áp dụng tại thời điểm Upload (Add),
  không áp dụng khi Save (Edit).
- Kế thừa sang các màn hình dùng chung popup Add/Edit: `005-eutr-sales-orders` (nút Upload/Edit ở Step 2
  Map File, Update 6 của đặc tả đó) và `012-eutr-purchase-orders` (nút Upload/Edit ở `PurchId/View`,
  FR-021/FR-022 của đặc tả đó) đều gọi đúng popup Add/Edit và luồng Upload dùng chung này, KHÔNG có logic
  đặt tên file riêng — do đó tự động kế thừa nguyên vẹn toàn bộ hành vi đổi tên ở Update này mà không cần
  thay đổi gì thêm ở hai đặc tả đó, kể cả khi `012-eutr-purchase-orders` tự điền sẵn Type = "PO" (FR-024
  của đặc tả đó): vẫn áp dụng đúng nhánh Type = "PO" ở trên nếu người dùng giữ nguyên Type đó lúc Upload.
- Q: Có nên áp dụng đổi tên cho cả Type = "PO", nơi Step hiện được suy ra từ việc khớp Prefix (không
  phải do người dùng chọn), thay vì chỉ Type khác "PO" (Step chọn tường minh)? → A: **Có, áp dụng cho
  mọi Type kể cả PO** — nhưng logic tìm StepId khớp Prefix qua tên file gốc (FR-020) giữ nguyên không
  đổi; bước đổi tên chỉ là một bước **bổ sung** chạy sau khi đã xác định xong (các) StepId khớp, không
  thay thế cơ chế validate/khớp hiện có.
- Q: Tên file mới có giữ lại tên file gốc (ví dụ làm hậu tố) để người dùng còn nhận diện được file đã
  upload không, hay thay thế hoàn toàn? → A: **Thay thế hoàn toàn** — tên file mới chỉ gồm Prefix (nếu
  có) + Step Name + đuôi file gốc; tên file gốc không được lưu/hiển thị ở bất kỳ đâu trong hệ thống sau
  khi upload thành công (thông báo lỗi cho file bị từ chối TRƯỚC khi tạo document, ví dụ sai định
  dạng/kích thước/không khớp prefix, vẫn tiếp tục hiển thị tên file gốc vì lỗi đó xảy ra trước bước đổi
  tên).
- Q: Với Type = "PO", khi tên file gốc khớp Prefix của nhiều Step khác nhau cùng lúc, nên dùng
  Step/Prefix nào trong số đó để đổi tên (vì chỉ có đúng 1 file vật lý/1 tên hiển thị, trong khi mọi
  StepId khớp đều vẫn được ghi bản ghi `eutr_references` riêng)? → A: **Dùng bản ghi có Prefix khớp dài
  nhất** (khớp cụ thể/đặc hiệu nhất với tên file gốc) — nếu nhiều bản ghi cùng độ dài Prefix dài nhất,
  ưu tiên bản ghi có `Id` nhỏ nhất (tie-break, cùng nguyên tắc "Id nhỏ nhất" đã dùng ở FR-032 cho tình
  huống tương tự).
- Q: Ký tự nào bị coi là "đặc biệt" cần loại bỏ khỏi tên mới? → A: Tối thiểu phải loại bỏ dấu gạch chéo
  ngược (`\`) và chuỗi hai dấu chấm liên tiếp (`..`) như yêu cầu gốc nêu rõ; hệ thống MUST áp dụng rộng
  hơn — loại bỏ toàn bộ tập ký tự không hợp lệ làm tên file trên hệ điều hành/SharePoint
  (`\ / : * ? " < > |`) để phòng lỗi tương tự với các ký tự khác cùng nhóm, không chỉ giới hạn đúng 2 ký
  tự nêu trong yêu cầu gốc.

### Session 2026-09-24 (Update 26) — Bỏ Prefix khỏi công thức File name tự động khi Upload (chỉ giữ Step Name)

- Input: "cập nhật 004-eutr-documents, 005-eutr-sales-orders, 012-eutr-purchase-orders khi upload
  file, file sẽ đổi tên theo tên step đã tìm được, hoặc đã chọn". Xác nhận với người yêu cầu: logic
  đổi tên theo Step đã có sẵn từ Update 25 (công thức Prefix + Step Name); yêu cầu thực tế của bản cập
  nhật này là **bỏ phần Prefix**, chỉ đổi tên file theo đúng Step Name (đã tìm được qua khớp Prefix ở
  Type = "PO", hoặc đã chọn tường minh ở Type khác "PO") — nếu công thức hiện có gắn Prefix vào thì bỏ
  đi.
- Change: Công thức tính File name mới ở Update 25 (FR-062/FR-063) MUST bỏ phần nối Prefix ở đầu — File
  name mới cho **cả hai nhánh** (Type khác "PO" và Type = "PO") nay CHỈ gồm: `Name` của Step (đã chọn,
  hoặc Step của bản ghi `eutr_master_documents` thắng cuộc theo tie-break Prefix dài nhất ở Type = "PO")
  đã qua bước làm sạch (FR-064, không đổi), giữ nguyên đuôi file gốc — KHÔNG còn nối thêm Prefix vào
  trước Step Name.
- Change: Toàn bộ phần còn lại của Update 25 tiếp tục giữ nguyên không đổi: (a) logic xác định `StepId`
  khớp Prefix ở Type = "PO" (FR-020, không đổi) và việc ghi bản ghi `eutr_references` tương ứng (không
  đổi bởi Update này — giữ nguyên logic hiện có, không thuộc phạm vi thay đổi của Update 26); (b) bước
  chọn bản ghi `eutr_master_documents` có Prefix dài nhất trong số các bản ghi khớp, dùng
  để xác định **Step thắng cuộc** — nay CHỈ dùng Prefix để tie-break chọn Step khi khớp nhiều Step, KHÔNG
  còn dùng giá trị Prefix để ghép vào tên file; (c) bước làm sạch ký tự đặc biệt và tên dự phòng
  `Step{StepId}` khi rỗng (FR-064, không đổi, nay áp dụng cho riêng Step Name); (d) cơ chế hậu tố ngẫu
  nhiên chống trùng tên vật lý SharePoint (FR-065, không đổi); (e) đổi tên chỉ áp dụng tại thời điểm
  Upload, Edit không tính lại (FR-066, không đổi); (f) cho phép nhiều document có File name trùng nhau
  (FR-067, không đổi — nay càng dễ trùng hơn vì không còn Prefix phân biệt).
- Change: Kế thừa sang `005-eutr-sales-orders` và `012-eutr-purchase-orders` (đã kế thừa Update 25 ở
  Update 23/Update 3 của hai đặc tả đó) tiếp tục nguyên vẹn — cả hai gọi đúng popup Add/Edit và luồng
  Upload dùng chung với `004-eutr-documents`, không có logic đặt tên riêng, nên tự động kế thừa việc bỏ
  Prefix này mà không cần thay đổi gì thêm ở hai đặc tả đó (xem mục kế thừa tương ứng trong spec của
  từng đặc tả).
- Q: Có cần xóa method `GetPrefixByStepIdAsync` (thêm ở Update 25, chỉ dùng để lấy Prefix cho nhánh Type
  khác "PO") vì nay không còn dùng Prefix để đặt tên ở nhánh này? → A: **Có** — method này (và lời gọi
  nó trong `UploadMultipleForReferenceTypeAsync`) chỉ được thêm riêng cho mục đích lấy Prefix để ghép
  tên ở Update 25; nay không còn công dụng nào khác trong toàn bộ codebase nên MUST được xóa cùng bản
  cập nhật này, tránh code chết. Nhánh Type = "PO" (`UploadMultipleToSharePointAndSaveDataAsync`) tiếp
  tục dùng `Prefix` của bản ghi thắng cuộc — nhưng CHỈ để tie-break chọn Step, không lấy giá trị `Prefix`
  đưa vào chuỗi tên nữa.
- Q: Việc bỏ Prefix có ảnh hưởng gì tới các document ĐÃ được tạo trước bản cập nhật này (File name đã
  lưu theo công thức Prefix + Step Name của Update 25) không? → A: **Không** — bản cập nhật này KHÔNG
  migration/backfill dữ liệu cũ; document tạo trước Update 26 giữ nguyên File name đã lưu (có thể vẫn
  còn Prefix ở đầu); chỉ document tạo MỚI qua Upload sau bản cập nhật này mới áp dụng công thức chỉ-Step-
  Name.

### Session 2026-09-24 (Update 27) — Mở rộng định dạng file được phép upload: thêm .xml/.json/.geojson (cho phép nhiều file khác đuôi cùng chung 1 Step)

- Input: "cập nhật 004-eutr-documents, 005-eutr-sales-orders, 012-eutr-purchase-orders. hiện tại 1 file
  ứng với 1 step. giờ cho phép 1 step có thể chứa nhiều file nếu khác đuôi ví dụ đuôi pdf và xml có thể
  chung step, nếu prefix giống nhau. khi hiển thị ở view cũng hiển thị rõ 2 file thuộc step đó". Rà soát
  mã nguồn thực tế trước khi soạn thảo cho thấy: (a) backend KHÔNG có ràng buộc unique/dedupe nào chặn
  nhiều `eutr_documents`/`eutr_references` cùng trỏ về 1 `StepId` — nhiều file khớp cùng Prefix/Step đã
  luôn tạo được nhiều bản ghi độc lập từ trước; (b) giao diện cây Step (Map File Step 2 của
  `005-eutr-sales-orders`, và `PurchId/View` của `012-eutr-purchase-orders` — clone cùng logic) đã hiển
  thị sẵn nhiều file/1 node Step dạng tên file đầu tiên + badge "(+N)" + tooltip liệt kê đủ tên mọi file
  khớp step đó khi có nhiều hơn 1 file. Gap thực sự duy nhất: danh sách định dạng file được phép upload
  (`FR-018`) hiện KHÔNG có `.xml` — nên kịch bản "1 file .pdf + 1 file .xml cùng Prefix/Step" bị chặn
  ngay từ bước validate định dạng, chưa từng tới được logic khớp Step/hiển thị nói trên. Đã xác nhận
  phạm vi thực tế với người yêu cầu qua `AskUserQuestion`: chỉ cần bổ sung định dạng được phép (`.xml`,
  `.json`, `.geojson`) — không cần thay đổi gì thêm ở logic khớp Step, ghi `eutr_references`, hay hiển
  thị cây Step (đã hoạt động đúng từ trước).
- Change: `FR-018` (danh sách định dạng file được phép) MUST mở rộng thêm 3 định dạng mới: XML
  (`.xml`), JSON (`.json`), GeoJSON (`.geojson`) — bên cạnh PDF/DOC/DOCX/XLS/XLSX/JPG/PNG hiện có. Giới
  hạn kích thước 10MB/file và toàn bộ hành vi loại file không hợp lệ (liệt kê tên file + lý do, không
  chặn các file hợp lệ khác trong cùng lượt) giữ nguyên không đổi.
- Change: Không có thay đổi nào ở logic khớp Prefix/Step (FR-020, FR-032), ghi `eutr_references`, đổi
  tên file (FR-062 đến FR-070), hay hiển thị cây Step ở `005-eutr-sales-orders`/`012-eutr-purchase-orders`
  — toàn bộ cơ chế "nhiều file khác đuôi cùng 1 Step nếu cùng khớp Prefix" đã hoạt động đúng từ trước
  Update này; việc mở rộng định dạng chỉ gỡ bỏ rào cản duy nhất (validate định dạng) khiến kịch bản đó
  chưa từng kiểm thử được với file `.xml`/`.json`/`.geojson`.
- Q: `.xml`/`.json`/`.geojson` có cần xử lý xem trước (preview qua icon View) khác với các định dạng
  hiện có không? → A: **Không** — phạm vi yêu cầu chỉ là cho phép upload; xem trước file thật (icon
  View, đọc nội dung base64 từ SharePoint) áp dụng đồng nhất cho mọi định dạng đã upload thành công,
  không có xử lý riêng theo từng loại định dạng trong feature này (nằm ngoài phạm vi yêu cầu, không
  thay đổi).

### Session 2026-09-24 (Update 28) — Mở giới hạn kích thước file upload lên 20MB

- Input: "mở giới hạn file upload lên 20MB".
- Change: `FR-018` (giới hạn kích thước file) MUST tăng từ 10MB lên **20MB** mỗi file. Toàn bộ hành vi
  còn lại (loại file vượt quá kèm thông báo lỗi liệt kê tên file + lý do, không chặn các file hợp lệ
  khác trong cùng lượt; danh sách định dạng được phép ở FR-018/FR-071) giữ nguyên không đổi.
- Change: Giới hạn kích thước file MUST áp dụng đồng nhất cho mọi định dạng được phép (PDF, DOC/DOCX,
  XLS/XLSX, JPG/PNG, XML, JSON, GeoJSON) — không có giới hạn riêng theo từng định dạng.
- Q: Giới hạn 20MB có áp dụng cho `005-eutr-sales-orders`/`012-eutr-purchase-orders` không? → A: **Có,
  tự động** — cả hai gọi chung popup Add/Edit và 2 endpoint Upload dùng chung với `004-eutr-documents`,
  không có validate kích thước riêng ở tầng feature của chúng.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Xem danh sách EUTR documents (Priority: P1)

Người dùng vào mục **EUTR > EUTR documents** từ thanh điều hướng và thấy bảng liệt kê các document
EUTR đã thêm vào hệ thống, với các cột File name, Step name, **Invoice**, Conditions, Type, Valid
from, Valid to, Created by, Created date và cột Action (Edit, Delete, View). Step name và Type được
tra cứu từ bảng `eutr_references` theo `DocumentId` (Step name JOIN `eutr_steps`, Type JOIN
`eutr_reference_types` theo `RefType`); document chưa có bản ghi `eutr_references` nào hiển thị hai
cột này ở trạng thái trống. Cột **Conditions** hiển thị mọi giá trị `RefValue` (khác null) của các
bản ghi `eutr_references` thuộc document đó, mỗi giá trị một chip — document không có `RefValue` nào
hiển thị cột này ở trạng thái trống. **(Update 24)** Cột **Invoice** hiển thị trực tiếp giá trị
`eutr_documents.Invoice` của document đó dưới dạng văn bản đơn thuần (không phải chip) — document có
`Invoice = null` (Type khác "Invoice") hiển thị cột này ở trạng thái trống. Người dùng có thể chuyển
trang khi danh sách dài. Icon **View** trên cột Action mở popup xem trước file thật (nếu document có
`FileId`); document không có `FileId` hiển thị icon View ở trạng thái vô hiệu hóa kèm tooltip "No file
to view".

**Why this priority**: Đây là giá trị cốt lõi — xem danh sách document hiện có là thao tác đầu tiên
người dùng cần trước khi thêm mới, sửa, xóa hay xem chi tiết bất kỳ document nào.

**Independent Test**: Mở màn hình, xác nhận breadcrumb "EUTR > EUTR documents" và bảng hiển thị đúng
File name/Valid from/Valid to/Created by/Created date; với một document có nhiều bản ghi
`eutr_references` mang các `RefValue` khác nhau, xác nhận cột Conditions hiển thị đầy đủ từng giá
trị dưới dạng chip; với document không có bản ghi `eutr_references` nào, xác nhận Step name/
Conditions/Type đều trống; với một document Type = "Invoice" có `Invoice` đã lưu, xác nhận cột
**Invoice** hiển thị ngay sau cột Step name đúng giá trị đó; với document `Invoice = null`, xác nhận
cột này trống; chuyển trang và thấy trang kế tiếp.

**Acceptance Scenarios**:

1. **Given** đang ở mục EUTR, **When** chọn "EUTR documents" ở thanh điều hướng, **Then** thấy
   breadcrumb "EUTR > EUTR documents" và bảng với các cột File name, Step name, **Invoice**,
   Conditions, Type, Valid from, Valid to, Created by, Created date, Action — theo đúng thứ tự đó
   (Invoice ngay sau Step name).
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
11. **(Update 24)** **Given** một document Type = "Invoice" có `eutr_documents.Invoice` đã lưu (ví dụ
    "INV-2026-001"), **When** bảng hiển thị dòng đó, **Then** cột Invoice (ngay sau cột Step name)
    hiển thị đúng giá trị đó dưới dạng văn bản đơn thuần.
12. **(Update 24)** **Given** một document có `eutr_documents.Invoice = null` (Type khác "Invoice",
    hoặc document cũ trước Update 23), **When** bảng hiển thị dòng đó, **Then** cột Invoice hiển thị
    trống, không lỗi.

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
tối đa `9999-12-31`) — cả hai đều có thể chỉnh sửa trước khi Upload — **(Update 30)** CHỈ hiển thị khi
Type đã chọn = "Vendor", Type khác ẩn hoàn toàn 2 trường này nhưng vẫn dùng đúng giá trị mặc định khi
Upload — và nút **Upload**.

Chọn Type = "PO", "Invoice", hoặc "Delivery note" hiển thị gợi ý PO (API `refType = 15`); chọn Type
= "Vendor" hiển thị gợi ý Vendor (API `refType = 14`); Type khác không có gợi ý, ô Value là nhập tự
do. Với Type = "PO" hoặc "Vendor", vùng chọn chỉ nhận tối đa 1 chip; các Type khác nhận nhiều chip.
Đổi Type xóa toàn bộ chip hiện có.

**(Update 23)** Riêng khi Type đã chọn có `Name` = "Invoice", popup MUST hiển thị thêm một trường
nhập liệu **Invoice number** (ô nhập tự do, kiểu chuỗi, bắt buộc) — Type khác "Invoice" MUST không
hiển thị trường này. Nút Upload MUST vô hiệu hóa thêm cho tới khi trường này có giá trị.

Nút Upload chỉ khả dụng khi đã chọn Type, có ít nhất 1 chip, và — với Type khác "PO" — đã chọn Step.
Nhấn Upload mở hộp thoại chọn nhiều file; mỗi file hợp lệ (PDF/DOC/DOCX/XLS/XLSX/JPG/PNG/XML/JSON/
GeoJSON — Update 27, tối đa **20MB** — Update 28, sửa 10MB cũ) được tải lên thư mục SharePoint xác
định theo Type (PO/Vendor → thư mục theo chip đã chọn;
Invoice/Delivery note/General agreement → thư mục cố định theo tên Type; Type khác → thư mục cố
định theo `Name` của Type). **(Update 29, thay Update 19 gốc; sửa lại sau kiểm thử thật)** Khi Type =
"PO", tên file MUST **chứa** `Name` của ít nhất một Step trong **toàn bộ `eutr_steps`** — KHÔNG còn
khớp `Prefix` trong `eutr_master_documents` (quyết định ban đầu chỉ dùng Step đã gán cho Type "PO" qua
Assign Steps đã bị loại bỏ, xem Update 29 ở mục Clarifications); file không chứa tên Step nào bị loại
kèm cảnh báo "không tìm được step tương ứng".

Với mỗi file upload thành công, hệ thống tạo một document mới trong `eutr_documents` — File name: với
Type khác "PO", **(Update 26, sửa Update 25)** KHÔNG còn là tên file gốc mà được hệ thống tự động
tính lại theo Step đã chọn: `Name` của Step đó, đã làm sạch ký tự đặc biệt (loại bỏ `\ / : * ? " < > |`
và mọi chuỗi `..`), giữ nguyên đuôi file gốc; với Type = "PO", **(Update 29, thay Update 25/26)**
**giữ nguyên tên file gốc** — hệ thống KHÔNG còn đổi tên file cho nhánh này nữa (xem Update 29 ở mục
Clarifications để biết đầy đủ lý do và các trường hợp biên) — cùng Valid from = giá trị đang hiển
thị ở popup, Valid to = giá trị đang hiển thị ở popup, FileId = id từ SharePoint. Với Type khác "PO",
hệ thống ghi một bản ghi `eutr_references` cho mỗi
chip (DocumentId, StepId đã chọn, RefType = `Id` của Type đã chọn, RefValue = giá trị chip). Với
Type = "PO", hệ thống ghi một bản ghi `eutr_references` cho **mỗi** `StepId` khớp (Update 29: khớp theo
tên Step chứa trong tên file, không còn khớp Prefix) của file đó
(RefType = `Id` của Type "PO" đang chọn — gửi kèm dưới dạng `TypeId`, RefValue = giá trị chip PO đã
chọn). **(Update 23)** Với Type =
"Invoice", bản ghi `eutr_documents` vừa tạo cho file đó MUST được
ghi thêm giá trị Invoice number đang hiển thị ở popup vào cột `Invoice` (không ghi vào
`eutr_references`). Sau khi lượt Upload hoàn tất (toàn bộ hoặc một phần thành công), popup MUST tự
đóng lại.

**Why this priority**: Đây là cách duy nhất để tạo document mới — là nghiệp vụ chính của màn hình.

**Independent Test**: Nhấn Add, xác nhận popup "Add EUTR documents" mở ra với Valid from = hôm nay
và Valid to = ngày tối đa hiển thị sẵn (có thể sửa); chọn Type = "PO", xác nhận combobox Step không
hiển thị; gõ/chọn một PO hợp lệ, xác nhận chip xuất hiện, ô Value trở về trống; đổi Valid from/Valid
to sang giá trị khác; nhấn Upload, chọn file có tên chứa tên một Step đã gán cho Type "PO" (Update
29); xác nhận document mới xuất hiện trên danh sách với đúng Valid from/Valid to đã chỉnh sửa (không
phải mặc định) và đúng `eutr_references` (StepId khớp theo tên, RefValue = mã PO); riêng biệt xác
nhận không sửa Valid from/Valid to thì document tạo ra có Valid from = hôm nay, Valid to = ngày tối
đa. **(Update 26, sửa Update 25)** Riêng biệt: chọn Type khác "PO" (ví dụ "Invoice") có Step "A" (không
có cấu hình trong `eutr_master_documents`) và Step "B" (có cấu hình Prefix = "INV"); upload một file bất
kỳ (ví dụ
`baocao.pdf`) với Step "A" đã chọn, xác nhận File name trên danh sách = "A.pdf" (không phải
`baocao.pdf`); lặp lại với Step "B", xác nhận File name = "B.pdf" (KHÔNG phải "INVB.pdf" — Prefix "INV"
của Step "B" KHÔNG còn được ghép vào tên kể từ Update 26); upload thêm một file khác cũng với Step "B",
xác nhận document mới cũng có File name = "B.pdf" (trùng với document trước, được hệ thống chấp nhận
bình thường). **(Update 29)** Riêng biệt cho Type = "PO": upload một file tên `1.Invoice AP-PD.pdf`
khi có Step "1.Invoice" đã gán cho Type "PO", xác nhận: (a) document mới tạo ra có File name **đúng
bằng** `1.Invoice AP-PD.pdf` (tên file gốc, không đổi thành "1.Invoice.pdf"); (b) `eutr_references`
được ghi với `StepId` của Step "1.Invoice"; upload thêm một file tên `baocao.pdf` (không chứa tên Step
nào đã gán cho Type "PO"), xác nhận file này bị loại khỏi lượt upload kèm lỗi "không tìm được step
tương ứng", không tạo document nào cho file đó.

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
14. **(Update 28, sửa giới hạn 10MB cũ)** **Given** một hoặc nhiều file trong lượt chọn sai định dạng
    hoặc vượt quá **20MB**, **Then** hệ thống loại các file đó kèm thông báo lỗi rõ ràng, vẫn upload
    và tạo document cho các file hợp lệ còn lại trong cùng lượt.
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
21. **(Update 23)** **Given** popup Add đang mở, **When** chọn Type có `Name` = "Invoice", **Then**
    popup hiển thị thêm trường **Invoice number** (ô nhập tự do); chọn Type khác "Invoice" MUST
    không hiển thị trường này (nếu đang hiển thị từ lượt chọn Type = "Invoice" trước đó, MUST ẩn đi).
22. **(Update 23)** **Given** Type đã chọn = "Invoice" và mọi điều kiện khác đã đủ (Type/Step/ít nhất
    1 chip), **When** trường Invoice number đang trống, **Then** nút Upload vẫn ở trạng thái vô hiệu
    hóa; nhập giá trị vào Invoice number MUST làm nút Upload khả dụng (nếu các điều kiện khác đã đủ).
23. **(Update 23)** **Given** Type đã chọn = "Invoice", đã nhập Invoice number, và upload file hợp lệ
    thành công, **Then** bản ghi `eutr_documents` tạo ra cho file đó có cột `Invoice` = giá trị đang
    hiển thị ở popup tại thời điểm Upload; các bản ghi `eutr_references` tạo cùng lượt Upload đó KHÔNG
    có cột/giá trị Invoice nào (dữ liệu chỉ nằm trên `eutr_documents`).
24. **(Update 26, sửa Update 25)** **Given** Type đã chọn khác "PO" với Step "Invoice" (Step này có bản
    ghi `eutr_master_documents` với `Prefix = "INV"`), **When** upload thành công một file tên bất kỳ
    (ví dụ `scan001.pdf`), **Then** `eutr_documents.Name` của document tạo ra = "Invoice.pdf" (chỉ Step
    Name + đuôi file gốc — KHÔNG còn Prefix "INV" ở đầu) — không phải `scan001.pdf` và không phải
    "INVInvoice.pdf".
25. **(Update 25)** **Given** Type đã chọn khác "PO" với một Step KHÔNG có bản ghi nào trong
    `eutr_master_documents`, **When** upload thành công, **Then** `eutr_documents.Name` = đúng `Name`
    của Step đó (đã làm sạch) + đuôi file gốc — không có Prefix ở đầu.
26. **(Update 26, sửa Update 25)** **Given** Type = "PO", tên file gốc khớp Prefix của hai bản ghi
    `eutr_master_documents` khác nhau (ví dụ `Prefix = "INV"` ứng Step A và `Prefix = "INV2026"` ứng
    Step B), **When** upload thành công, **Then** việc ghi `eutr_references` tiếp tục theo đúng logic
    hiện có (không đổi bởi Update 26); Prefix dài hơn ("INV2026") vẫn dùng để **chọn Step B** làm Step
    thắng cuộc (tie-break không đổi), nhưng `eutr_documents.Name` = đúng `Name` của Step B (đã làm
    sạch) + đuôi file gốc — KHÔNG còn ghép Prefix "INV2026" vào tên.
27. **(Update 26, sửa Update 25)** **Given** Step Name đang cấu hình chứa ký tự `\` hoặc chuỗi `..`
    (dữ liệu do người dùng nhập tự do ở `001-eutr-steps`), **When** upload thành công dùng Step đó,
    **Then** `eutr_documents.Name` của document tạo ra KHÔNG chứa ký tự `\` hoặc chuỗi `..` nào — các
    ký tự/chuỗi đó bị loại bỏ khỏi tên trước khi lưu, không gây lỗi khi tải file lên SharePoint (kể từ
    Update 26, bước làm sạch chỉ áp dụng cho Step Name vì Prefix không còn là một phần của tên).
28. **(Update 25)** **Given** hai file khác nhau (tên gốc khác nhau) được upload trong cùng một lượt
    Upload với cùng Type/Step (hoặc, với Type = "PO", cùng bản ghi master thắng cuộc), **Then** cả hai
    document tạo ra đều có `eutr_documents.Name` **giống hệt nhau** — hệ thống lưu bình thường, không
    báo lỗi trùng tên.
29. **(Update 25)** **Given** một file trong lượt Upload bị loại vì sai định dạng/kích thước hoặc (Type
    = "PO") không khớp Prefix nào, **Then** thông báo lỗi liệt kê đúng **tên file gốc** của file đó
    (không phải tên đã đổi, vì file này không tạo được document nên không có tên mới).
30. **(Update 27)** **Given** Type = "PO" với 1 bản ghi `eutr_master_documents` (`Prefix = "INV"`,
    `StepId` của Step "Invoice"), **When** upload file `INV_scan.pdf` ở một lượt, rồi upload tiếp file
    `INV_scan.xml` (cùng khớp Prefix "INV") ở một lượt khác, **Then** cả 2 file đều được chấp nhận
    (không bị loại vì định dạng), mỗi file tạo một `eutr_documents`/`eutr_references` độc lập cùng
    `StepId` của Step "Invoice"; trên cây Step ở `005-eutr-sales-orders`/`012-eutr-purchase-orders`,
    node Step "Invoice" hiển thị badge "+1" và tooltip liệt kê đủ tên cả 2 file.
31. **(Update 27)** **Given** popup Add, **When** chọn upload 1 file `.json` hoặc `.geojson` hợp lệ
    (≤10MB), **Then** file được chấp nhận và tạo document thành công — không còn bị từ chối với lý do
    "Invalid file type" như trước Update 27.
32. **(Update 28, FR-018/FR-073)** **Given** popup Add, **When** chọn upload 1 file hợp lệ có kích
    thước trong khoảng **10MB–20MB** (ví dụ 15MB, định dạng bất kỳ được phép), **Then** file được chấp
    nhận và tạo document thành công — không bị từ chối như trước Update 28 (khi giới hạn còn 10MB).
    Upload tiếp 1 file **> 20MB** → xác nhận vẫn bị loại kèm thông báo lỗi rõ ràng, các file hợp lệ
    khác trong cùng lượt không bị ảnh hưởng.
33. **(Update 29, FR-020/FR-074/FR-075, sửa lại sau kiểm thử thật)** **Given** đã chọn Type = "PO" với
    1 chip mã PO, có Step "1.Invoice" và Step "2.Packing list" tồn tại trong `eutr_steps` (không cần
    Assign Steps cho Type "PO"), **When** upload file tên
    `1.Invoice AP-PD.pdf`, **Then** hệ thống tạo document mới với `eutr_documents.Name` =
    `1.Invoice AP-PD.pdf` (giữ nguyên tên file gốc, KHÔNG đổi tên) và ghi một bản ghi
    `eutr_references` với `StepId` của Step "1.Invoice" (RefValue = mã PO đã chọn) — KHÔNG tra
    `eutr_master_documents`.
34. **(Update 29, FR-076)** **Given** đã chọn Type = "PO", `eutr_steps` gồm
    "1.Invoice" và "2.Packing list" (cùng các Step khác), **When** upload file tên `baocao.pdf` (không
    chứa tên Step nào), **Then** file đó bị loại khỏi lượt upload kèm thông báo lỗi nêu rõ "không tìm
    được step tương ứng" — không tạo document/`eutr_references` cho file này; các file khác trong cùng
    lượt (nếu có, khớp Step hợp lệ) không bị ảnh hưởng.
35. **(Update 29, FR-075)** **Given** đã chọn Type = "PO", tên file upload chứa tên của **cả hai** Step
    "1.Invoice" và "Invoice" (ví dụ tên Step "Invoice" là một chuỗi con của "1.Invoice"), **When**
    upload thành công, **Then** hệ thống ghi đủ hai bản ghi `eutr_references` — một cho mỗi `StepId`
    khớp — không giới hạn chỉ chọn một Step "thắng cuộc" (khác cơ chế tie-break Prefix cũ, nay không
    còn áp dụng vì không còn đổi tên file).
36. **(Update 29, FR-074, sửa lại sau kiểm thử thật)** **Given** `eutr_steps` hiện KHÔNG có bản ghi nào
    (toàn hệ thống chưa tạo Step nào), **When** upload bất kỳ file nào
    với Type = "PO", **Then** mọi file trong lượt đó đều bị loại kèm lỗi "không tìm được step tương
    ứng" — không phải lỗi hệ thống, cần tạo Step trước (màn `001-eutr-steps`).
37. **(Update 30, FR-080)** **Given** popup Add đang mở, **When** chọn Type = "PO" (hoặc bất kỳ Type
    nào khác "Vendor"), **Then** hai trường Valid from/Valid to KHÔNG hiển thị trên popup; upload file
    hợp lệ thành công vẫn tạo document với Valid from = ngày hiện tại, Valid to = `9999-12-31` (giá trị
    mặc định, không có ô nào để sửa).
38. **(Update 30, FR-080)** **Given** popup Add đang mở, **When** chọn Type = "Vendor", **Then** hai
    trường Valid from/Valid to hiển thị lại như trước Update 30, cho phép sửa trước khi Upload.
39. **(Update 30, FR-080)** **Given** popup Add đang mở với Type = "Vendor" và người dùng đã sửa Valid
    from/Valid to sang giá trị khác mặc định, **When** đổi Type sang "PO" (hoặc Type khác "Vendor"),
    **Then** hai trường ẩn đi VÀ giá trị được reset lại về mặc định (ngày hiện tại/`9999-12-31`) — nếu
    người dùng đổi lại Type = "Vendor" ngay sau đó, hai trường hiển thị lại với giá trị mặc định (không
    còn giữ giá trị đã sửa trước đó).
40. **(Update 30, FR-080)** **Given** popup Edit đang mở cho một document bất kỳ Type nào, **When** xem
    popup, **Then** Valid from/Valid to tiếp tục hiển thị như hành vi hiện có (FR-030) — không bị ẩn dù
    Type của document đó không phải "Vendor".

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

**(Update 23)** Riêng khi Type hiện tại (đã khóa) của document = "Invoice", popup Edit MUST hiển thị
thêm trường **Invoice number**, nạp sẵn giá trị `Invoice` hiện có trên chính document đang sửa (cột
`eutr_documents.Invoice`, không tra cứu qua `eutr_references`), và MUST cho phép sửa (bắt buộc có giá
trị, không được để trống trước khi Save). Nhấn Save với Type = "Invoice" MUST cập nhật trực tiếp cột
`Invoice` của `eutr_documents` cho document đó thành giá trị mới — cùng cách Save cập nhật
`ValidFrom`/`ValidTo`, hoàn toàn độc lập với việc đồng bộ chip Value/`eutr_references` ở trên.

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
19. **(Update 23)** **Given** một document có Type hiện tại = "Invoice", **When** nhấn Edit, **Then**
    popup hiển thị thêm trường Invoice number, nạp sẵn đúng giá trị `Invoice` hiện có của chính
    document đó (`eutr_documents.Invoice`) và cho phép sửa.
20. **(Update 23)** **Given** popup Edit đang mở với Type = "Invoice", **When** đổi Invoice number
    sang giá trị khác rồi nhấn Save, **Then** cột `Invoice` của bản ghi `eutr_documents` đó được cập
    nhật thành giá trị mới; không có bản ghi `eutr_references` nào bị ảnh hưởng bởi thay đổi này.
21. **(Update 23)** **Given** popup Edit đang mở với Type = "Invoice", **When** xóa trắng trường
    Invoice number rồi cố nhấn Save, **Then** hệ thống chặn Save kèm thông báo lỗi yêu cầu nhập Invoice
    number, giống quy tắc bắt buộc ở Add.
22. **(Update 23)** **Given** popup Edit đang mở với Type khác "Invoice" (bao gồm Type trống), **Then**
    trường Invoice number MUST không hiển thị.

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
- **(Update 23)** Khi người dùng đổi Type từ "Invoice" sang Type khác trong popup Add trước khi Upload,
  trường Invoice number MUST bị ẩn đi và giá trị đã nhập MUST không được gửi lên khi Upload (đổi Type
  ngược lại "Invoice" sau đó MUST hiển thị lại trường ở trạng thái trống, không khôi phục giá trị cũ).
- **(Update 23)** Vì Invoice number lưu trực tiếp trên `eutr_documents` (1 giá trị/1 document, không
  phải trên `eutr_references`), không có kịch bản nhiều bản ghi cùng document mang giá trị Invoice
  khác nhau cần hòa giải — mỗi document luôn có đúng một giá trị `Invoice` (hoặc `null`).
- **(Update 23)** Đóng popup Add/Edit mà không Upload/Save khi Type = "Invoice" MUST không ghi bất kỳ
  giá trị Invoice number nào vào `eutr_documents` — kế thừa quy tắc chung đã có.
- **(Update 24)** Khi giá trị `eutr_documents.Invoice` dài, cột Invoice trên bảng danh sách chính tuân
  theo cùng cơ chế hiển thị/cắt ngắn văn bản (nếu có) như các cột văn bản đơn khác của bảng (ví dụ File
  name) — không có yêu cầu riêng biệt nào về giới hạn độ dài hiển thị cho cột này.
- **(Update 26, sửa Update 25)** Khi Step Name sau khi làm sạch ký tự đặc biệt trở thành chuỗi rỗng (ví
  dụ Step Name chỉ toàn ký tự bị loại bỏ, hoặc để trống trong `eutr_steps`), hệ thống MUST dùng tên dự
  phòng `Step{StepId}` làm phần tên trước khi thêm đuôi file, đảm bảo không bao giờ tạo ra
  `eutr_documents.Name` rỗng.
- **(Update 26, thay thế Update 25)** Trường hợp một Step có nhiều hơn một bản ghi `eutr_master_documents`
  cùng `StepId` (nhiều Prefix khác nhau trỏ về cùng một Step) không còn ảnh hưởng tới việc đổi tên —
  từ Update 26, tên file chỉ dùng `Name` của Step, không dùng `Prefix` của bất kỳ bản ghi nào, nên số
  lượng bản ghi `eutr_master_documents` trùng `StepId` không còn tác động tới File name.
- **(Update 25)** File bị loại khỏi lượt upload (sai định dạng/kích thước, hoặc — Type = "PO" — không
  khớp Prefix nào) KHÔNG tạo document nên không có tên mới; thông báo lỗi tương ứng MUST tiếp tục nêu
  đúng **tên file gốc** người dùng đã chọn, không phải tên đã đổi theo Step.
- **(Update 25)** Việc đổi tên theo Step/Prefix CHỈ xảy ra ở thời điểm Upload (Add) — mở lại popup Edit
  cho một document đã tạo KHÔNG tính toán lại hay hiển thị "tên gợi ý mới" nào; File name hiện có của
  document chỉ đổi khi có một luồng nghiệp vụ khác ghi đè trực tiếp (hiện tại không có luồng nào như
  vậy trong phạm vi feature này).
- **(Update 25)** Nhiều document khác nhau (tạo từ các file gốc khác nhau, cùng Type/Step hoặc — với
  PO — cùng bản ghi master thắng cuộc) có `eutr_documents.Name` trùng nhau sau khi đổi tên KHÔNG phải
  lỗi hệ thống — kế thừa nguyên tắc File name không có ràng buộc duy nhất đã nêu ở trên; người dùng
  phân biệt các document trùng tên qua Valid from/Valid to/Created date/icon View (xem nội dung file
  thật) khi cần.
- **(Update 27)** Nhiều file khác đuôi (ví dụ `.pdf` và `.xml`) cùng khớp 1 Prefix/Step KHÔNG bị chặn
  hay gộp lại thành 1 document — mỗi file hợp lệ vẫn tạo `eutr_documents`/`eutr_references` riêng của
  nó (không có ràng buộc unique theo `StepId`, hành vi đã có từ trước Update 27); trên cây Step, các
  file này xuất hiện dưới cùng 1 node Step qua badge "+N"/tooltip đã có sẵn (không phải logic mới).
- **(Update 29)** Kể từ Update 29, việc `eutr_master_documents` hiện không có bản ghi nào (hoặc API
  tra cứu Prefix thất bại) KHÔNG còn ảnh hưởng tới Type = "PO" — dòng edge case cũ ở trên ("Khi
  `eutr_master_documents` hiện không có bản ghi nào...") chỉ còn đúng cho lịch sử trước Update 29;
  edge case tương đương hiện tại là danh sách Step đã gán cho Type "PO" (`eutr_reference_type_details`)
  rỗng (xem FR-074, FR-036 ở Acceptance Scenarios).
- **(Update 29)** File bị loại khỏi lượt upload vì "không tìm được step tương ứng" (Type = "PO") KHÔNG
  tạo document nên không ảnh hưởng tên hiển thị; thông báo lỗi tương ứng MUST nêu đúng tên file gốc
  người dùng đã chọn (cùng nguyên tắc đã áp dụng cho file bị loại vì sai định dạng/kích thước).
- **(Update 29)** Vì Type = "PO" không còn đổi tên file khi Upload, nhiều document Type = "PO" khác
  nhau (tạo từ các file gốc khác nhau) sẽ hầu như luôn có `eutr_documents.Name` khác nhau (đúng bằng
  tên file gốc tương ứng) — khác với trước Update 29, khi nhiều file khớp cùng Step/Prefix luôn tạo ra
  File name trùng nhau; hệ thống vẫn tiếp tục KHÔNG có ràng buộc duy nhất nào trên File name (không
  phải lỗi nếu trùng tên gốc do trùng tên file thật).
- **(Update 29)** Document Type = "PO" tạo TRƯỚC Update 29 giữ nguyên File name cũ (tên đã đổi theo
  Step ở Update 25/26) — không có migration/backfill nào chạm dữ liệu cũ; chỉ document Upload MỚI sau
  Update 29 mới giữ tên file gốc.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Hệ thống MUST hiển thị danh sách các EUTR document dạng bảng với các cột theo đúng thứ
  tự: File name, Step name, **Invoice** *(Update 24)*, Conditions, Type, Valid from, Valid to, Created
  by, Created date và cột Action (Edit, Delete, View).
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
  hiện tại tại thời điểm mở popup, cho phép người dùng sửa trước khi Upload — **(Update 30)** CHỈ hiển
  thị khi Type đã chọn = "Vendor" (xem FR-080); Type khác vẫn dùng giá trị mặc định này, chỉ không hiển
  thị/không sửa được.
- **FR-015**: Popup Add MUST có trường **Valid to** (ô chọn ngày), mặc định hiển thị giá trị = ngày
  tối đa `9999-12-31`, cho phép người dùng sửa trước khi Upload — **(Update 30)** CHỈ hiển thị khi Type
  đã chọn = "Vendor" (xem FR-080), cùng quy tắc với FR-014.
- **FR-016**: Popup Add MUST validate Valid from ≤ Valid to; nếu Valid from muộn hơn Valid to, hệ
  thống MUST báo lỗi và chặn Upload cho tới khi giá trị hợp lệ.
- **FR-017**: Nút **Upload** trong popup Add MUST ở trạng thái vô hiệu hóa cho tới khi: với Type khác
  "PO" — đã chọn Type, đã chọn Step, và vùng chọn có ít nhất 1 chip; với Type = "PO" — đã chọn Type
  và vùng chọn có ít nhất 1 chip (không cần Step). Khi khả dụng và được nhấn, MUST mở hộp thoại chọn
  file của hệ điều hành cho phép chọn nhiều file cùng lúc.
- **FR-018 (mở rộng ở Update 27/28, xem FR-071/FR-073)**: Hệ thống MUST chỉ chấp nhận file có định
  dạng PDF, DOC/DOCX, XLS/XLSX, JPG/PNG với kích thước tối đa **20MB** mỗi file. File không thỏa điều
  kiện MUST bị loại khỏi lượt upload kèm thông báo lỗi liệt kê tên file và lý do; các file hợp lệ còn
  lại trong cùng lượt MUST vẫn được upload.
- **FR-019**: Với mỗi file hợp lệ, hệ thống MUST xác định thư mục SharePoint đích theo `Name` của
  Type đã chọn: "PO"/"Vendor" → thư mục đặt tên theo chip đã chọn (tìm thư mục cũ hoặc tạo mới dưới
  `SharePointEutrPath`); "Invoice" → `{SharePointEutrPath}/Invoice`; "Delivery note" →
  `{SharePointEutrPath}/DeliveryNote`; "General agreement" → `{SharePointEutrPath}/GeneralAgreement`;
  Type khác → thư mục cố định đặt tên theo `Name` của Type đó.
- **FR-020**: **(Update 29, thay thế toàn bộ cơ chế trước đó)** Khi Type = "PO", trước khi upload lên
  SharePoint, hệ thống MUST xác định (các) Step khớp bằng cách so khớp tên file gốc (không phân biệt
  hoa/thường) có **chứa** `Name` của Step nào trong danh sách Step đã gán cho Type "PO"
  (`eutr_reference_type_details`) hay không — KHÔNG còn tra `eutr_master_documents`/`Prefix`; file
  không chứa tên của bất kỳ Step nào trong danh sách đó MUST bị loại khỏi lượt upload kèm thông báo
  lỗi nêu rõ "không tìm được step tương ứng", không chặn các file hợp lệ khác trong cùng lượt. Xem
  FR-074 đến FR-079 (Update 29) để biết đầy đủ công thức, edge case, và các thay đổi liên quan (bỏ
  đổi tên file, nguồn dữ liệu combobox Step ở Edit).
- **FR-021**: Với mỗi file upload thành công lên SharePoint, hệ thống MUST tạo một bản ghi mới trong
  `eutr_documents`: File name = với Type khác "PO", **(Update 26, sửa Update 25)** tên file hệ thống
  tự tính theo Step (KHÔNG còn là tên file gốc, KHÔNG còn gồm Prefix của master — xem
  FR-062/FR-063/FR-064/FR-068); với Type = "PO", **(Update 29, thay Update 25/26)** tên file gốc
  người dùng đã chọn, KHÔNG đổi tên (xem FR-077). Valid
  from = giá trị đang hiển thị ở trường
  Valid from của popup tại thời điểm Upload, Valid to = giá trị đang hiển thị ở trường Valid to,
  FileId = id trả về từ SharePoint; ghi nhận người tạo/ngày tạo tự động.
- **FR-022**: Với Type khác "PO", với mỗi file upload thành công, hệ thống MUST ghi thêm một bản ghi
  `eutr_references` cho **mỗi** chip đang có trong vùng chọn tại thời điểm Upload: `DocumentId` = Id
  document vừa tạo, `StepId` = Step đã chọn, `RefType` = `Id` của Type đã chọn, `RefValue` = giá trị
  chip đó.
- **FR-023**: Với Type = "PO", với mỗi file upload thành công, hệ thống MUST ghi một bản ghi
  `eutr_references` cho **mỗi** `StepId` khớp của file đó (FR-020 — **Update 29**: khớp theo tên Step
  chứa trong tên file, không còn khớp Prefix): `DocumentId` = Id document
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
- **FR-056 (Update 23)**: Popup Add MUST hiển thị thêm trường **Invoice number** (ô nhập tự do, kiểu
  chuỗi, bắt buộc) khi Type đang chọn có `Name` = "Invoice"; Type khác "Invoice" MUST không hiển thị
  trường này. Nút Upload MUST tiếp tục vô hiệu hóa (cạnh các điều kiện ở FR-017) cho tới khi trường
  này có giá trị, khi Type = "Invoice".
- **FR-057 (Update 23)**: Với mỗi file upload thành công khi Type = "Invoice", hệ thống MUST ghi giá
  trị Invoice number đang hiển thị ở popup tại thời điểm Upload vào cột mới **`Invoice`** trên bản ghi
  **`eutr_documents`** vừa tạo cho file đó — KHÔNG ghi giá trị này vào bất kỳ bản ghi `eutr_references`
  nào.
- **FR-058 (Update 23)**: Ở chế độ sửa, khi Type hiện tại (đã khóa) của document = "Invoice", popup
  Edit MUST hiển thị trường Invoice number, nạp sẵn giá trị `Invoice` hiện có trên chính document đang
  sửa (`eutr_documents.Invoice`), và MUST cho phép sửa (bắt buộc có giá trị trước khi Save).
- **FR-059 (Update 23)**: Khi nhấn Save ở chế độ sửa với document có Type = "Invoice", hệ thống MUST
  cập nhật trực tiếp cột `Invoice` trên bản ghi `eutr_documents` của document đó thành giá trị Invoice
  number mới — không ảnh hưởng tới bất kỳ bản ghi `eutr_references` nào (độc lập với việc đồng bộ chip
  Value ở FR-052).
- **FR-060 (Update 23)**: Với Type khác "Invoice" (bao gồm Type trống), cột `Invoice` trên
  `eutr_documents` được ghi bởi feature này MUST tiếp tục là `null`.
- **FR-061 (Update 24)**: Bảng danh sách chính MUST hiển thị cột **Invoice** ngay sau cột Step name,
  lấy trực tiếp giá trị `eutr_documents.Invoice` của mỗi document (không qua `eutr_references`), hiển
  thị dạng văn bản đơn thuần; document có `Invoice = null` MUST hiển thị cột này ở trạng thái trống.
- **FR-062 (Update 25)**: Với Type khác "PO", với mỗi file upload thành công, hệ thống MUST tính File
  name mới theo công thức: (Prefix từ `eutr_master_documents` có `StepId` = Step đã chọn, nếu tồn tại
  ít nhất một bản ghi — lấy `Prefix` của bản ghi `Id` nhỏ nhất khi có nhiều bản ghi cùng `StepId`) +
  `Name` của Step đã chọn, nối trực tiếp không có ký tự phân cách, đã làm sạch theo FR-064, giữ nguyên
  đuôi file gốc. `eutr_documents.Name` MUST lưu đúng tên mới này thay cho tên file gốc.
- **FR-063 (Update 25)**: Với Type = "PO", sau khi xác định xong (các) `StepId` khớp Prefix theo
  FR-020 (không đổi, vẫn tạo đủ bản ghi `eutr_references` cho mỗi `StepId` khớp theo FR-023), hệ thống
  MUST chọn bản ghi `eutr_master_documents` có `Prefix` **dài nhất** trong số các bản ghi đã khớp
  (tie-break: `Id` nhỏ nhất nếu nhiều bản ghi cùng độ dài Prefix dài nhất) để tính File name mới theo
  đúng công thức ở FR-062 (Prefix + Step Name của bản ghi thắng cuộc, làm sạch theo FR-064, giữ đuôi
  file gốc). Việc chọn bản ghi thắng cuộc để đặt tên KHÔNG ảnh hưởng số lượng/nội dung các bản ghi
  `eutr_references` được tạo.
- **FR-064 (Update 25)**: Bước làm sạch tên (áp dụng cho phần Prefix + Step Name trước khi ghép, dùng
  chung cho FR-062 và FR-063) MUST loại bỏ mọi ký tự không hợp lệ làm tên file trên hệ điều hành/
  SharePoint (tối thiểu `\ / : * ? " < > |`) và loại bỏ mọi chuỗi hai dấu chấm liên tiếp (`..`) khỏi
  kết quả. Nếu kết quả rỗng sau khi làm sạch, hệ thống MUST dùng tên dự phòng `Step{StepId}` thay thế.
- **FR-065 (Update 25)**: Tên dùng để tải file thật lên SharePoint MUST tiếp tục áp dụng cơ chế hậu tố
  ngẫu nhiên chống trùng tên vật lý hiện có, nhưng dựa trên File name mới đã tính theo FR-062/FR-063
  thay vì tên file gốc.
- **FR-066 (Update 25)**: Logic đổi tên (FR-062 đến FR-065) MUST chỉ áp dụng tại thời điểm Upload
  (Add). Popup Edit (Save) MUST KHÔNG tính toán lại hay thay đổi File name của document hiện có, kể cả
  khi Step bị đổi ở Edit (không ảnh hưởng FR-029/FR-033 hiện có).
- **FR-067 (Update 25)**: Hệ thống MUST cho phép nhiều document có File name trùng nhau sau khi áp
  dụng FR-062/FR-063 (không báo lỗi), kế thừa nguyên tắc File name không có ràng buộc duy nhất đã có.
- **FR-068 (Update 26)**: File name mới tính ở FR-062 (Type khác "PO") và FR-063 (Type = "PO") MUST
  KHÔNG còn nối Prefix vào trước Step Name — công thức thu gọn thành: `Name` của Step (đã chọn ở
  FR-062, hoặc Step ứng với bản ghi `eutr_master_documents` thắng cuộc theo tie-break Prefix dài nhất ở
  FR-063) đã làm sạch theo FR-064, giữ nguyên đuôi file gốc. Phần còn lại của FR-062/FR-063 (cách xác
  định Step đã chọn/Step thắng cuộc) MUST giữ nguyên không đổi.
- **FR-069 (Update 26)**: Ở nhánh Type = "PO" (FR-063), giá trị `Prefix` của bản ghi
  `eutr_master_documents` thắng cuộc tiếp tục MUST được dùng để xác định bản ghi đó (tie-break "Prefix
  dài nhất" không đổi) — nhưng CHỈ nhằm chọn ra Step thắng cuộc, KHÔNG được đưa vào chuỗi File name
  (xem FR-068).
- **FR-070 (Update 26)**: Hệ thống MUST xóa method `GetPrefixByStepIdAsync` trên
  `IEutrMastersRepository`/`EutrMastersRepository` và lời gọi tương ứng trong `EutrUploadService` (thêm
  riêng ở Update 25 cho nhánh Type khác "PO" để lấy Prefix ghép tên) — không còn công dụng nào khác sau
  khi FR-068 có hiệu lực.
- **FR-071 (Update 27)**: Danh sách định dạng file được phép ở FR-018 MUST mở rộng thêm XML (`.xml`),
  JSON (`.json`), GeoJSON (`.geojson`) — validate định dạng/kích thước (10MB/file) và hành vi loại file
  không hợp lệ (thông báo lỗi kèm tên file + lý do, không chặn các file hợp lệ khác trong cùng lượt)
  MUST áp dụng đồng nhất cho 3 định dạng mới này như mọi định dạng hiện có.
- **FR-072 (Update 27)**: Hệ thống MUST tiếp tục cho phép nhiều file (khác đuôi hoặc cùng đuôi) cùng
  khớp một `eutr_master_documents.Prefix`/Step — mỗi file hợp lệ upload thành công MUST tạo một bản ghi
  `eutr_documents`/`eutr_references` độc lập của riêng nó (không có ràng buộc unique/dedupe nào theo
  `StepId`), để 1 Step có thể chứa nhiều file (ví dụ 1 file `.pdf` và 1 file `.xml` cùng Prefix) — hành
  vi này không mới ở Update 27, chỉ được xác nhận rõ ràng thành yêu cầu vì trước đây không thể kiểm thử
  được với định dạng `.xml`/`.json`/`.geojson` (bị chặn ở FR-018 cũ).
- **FR-073 (Update 28)**: Giới hạn kích thước file ở FR-018 MUST tăng từ 10MB lên **20MB mỗi file**,
  áp dụng đồng nhất cho mọi định dạng được phép (PDF, DOC/DOCX, XLS/XLSX, JPG/PNG, XML, JSON, GeoJSON).
  Hành vi loại file vượt quá (thông báo lỗi kèm tên file + lý do, không chặn các file hợp lệ khác trong
  cùng lượt) giữ nguyên không đổi.
- **FR-074 (Update 29, sửa lại sau kiểm thử thật)**: Khi Type = "PO", danh sách Step dùng để so khớp
  tên file (FR-020) MUST là **toàn bộ `eutr_steps`** (danh sách phẳng, không lọc theo Type) — quyết
  định ban đầu (chỉ dùng Step đã gán cho Type "PO" qua Assign Steps, `eutr_reference_type_details`) đã
  bị loại bỏ vì bảng đó không liên quan tới cây Step của Template và luôn rỗng cho Type "PO" trong thực
  tế, khiến mọi file bị báo lỗi sai (xem Q&A "Sửa lại sau kiểm thử thật" ở mục Clarifications).
- **FR-075 (Update 29)**: Với mỗi file trong lượt Upload (Type = "PO"), hệ thống MUST so khớp tên file
  gốc (không phân biệt hoa/thường) với `Name` của từng Step trong danh sách ở FR-074 bằng phép kiểm
  tra "tên file **chứa** tên Step" (`fileName` chứa `step.Name`, không còn là "bắt đầu bằng Prefix") —
  mọi Step thỏa điều kiện này đều được coi là khớp; một file có thể khớp 0, 1, hoặc nhiều Step.
- **FR-076 (Update 29)**: File không khớp bất kỳ Step nào ở FR-075 MUST bị loại khỏi lượt upload kèm
  thông báo lỗi nêu rõ lý do (không tìm được step tương ứng cho file đó); không tạo `eutr_documents`/
  `eutr_references` nào cho file này; các file hợp lệ khác trong cùng lượt KHÔNG bị ảnh hưởng (cùng
  tinh thần FR-025).
- **FR-077 (Update 29, thay thế nhánh Type = "PO" của FR-063/FR-068/FR-069)**: Sau khi xác định xong
  danh sách Step khớp ở FR-075, hệ thống KHÔNG còn đổi tên file cho nhánh Type = "PO" — không còn khái
  niệm "Step thắng cuộc" để đặt tên. `eutr_documents.Name` MUST lưu đúng **tên file gốc** người dùng
  đã chọn (giữ nguyên toàn bộ tên, kể cả phần mở rộng). Nhánh Type khác "PO" (FR-062/FR-064/FR-068)
  KHÔNG bị ảnh hưởng, tiếp tục đổi tên theo Step Name như hiện có.
- **FR-078 (Update 29)**: Cơ chế hậu tố ngẫu nhiên 6 ký tự chống trùng tên vật lý trên SharePoint
  (FR-065) tiếp tục áp dụng cho nhánh Type = "PO", nhưng nay MUST dựa trên **tên file gốc** (thay vì
  tên đã đổi, vì FR-077 đã bỏ việc đổi tên).
- **FR-079 (Update 29, sửa lại sau kiểm thử thật)**: Combobox Step ở popup Edit khi sửa một document
  có Type = "PO" (nguồn dữ liệu hiện dựa trên `GetDistinctStepsAsync`/`GetMatchingStepsAsync`, vốn dùng
  chung cơ chế Prefix ở FR-020 cũ) MUST đổi nguồn sang danh sách Step khớp theo tên trong **toàn bộ
  `eutr_steps`** (cùng quy tắc FR-074/FR-075), tính trên tên file đã lưu của document đang sửa
  (`eutr_documents.Name`, từ Update 29 trở đi chính là tên file gốc) — để nhất quán với logic Upload
  mới.
- **FR-080 (Update 30)**: Ở popup Add (mode `add`), hai trường Valid from (FR-014)/Valid to (FR-015)
  MUST chỉ hiển thị khi Type đã chọn có `Name` = "Vendor" (không phân biệt hoa/thường); mọi Type khác
  MUST ẩn hoàn toàn 2 trường này. Khi ẩn, hệ thống vẫn MUST dùng đúng giá trị mặc định (ngày hiện tại/
  `9999-12-31`) khi Upload, và MUST reset lại 2 giá trị này về mặc định ngay khi Type đổi từ "Vendor"
  sang Type khác (trước khi ẩn). Popup Edit (mode `edit`) KHÔNG bị ảnh hưởng — tiếp tục hiển thị 2
  trường này cho mọi Type như FR-030 hiện có.
- **FR-081 (Update 31)**: Khi Upload Type "PO", một file MUST tạo document gắn với đúng 1 Step; nếu tên file khớp nhiều Step thì chọn Step có Name dài nhất, hoà thì Id nhỏ nhất. Thay thế phần multi-match của FR-023/FR-074/FR-075.
- **FR-082 (Update 32)**: Khi Upload Type "PO", tập Step dùng để khớp tên file MUST là các Step thuộc Template đã gắn cho PO (không phải toàn bộ `eutr_steps`); thay thế nguồn "toàn bộ `eutr_steps`" của Update 29/FR-074/FR-075 (quy tắc chọn 1 Step của FR-081 giữ nguyên, áp dụng trong tập này). PO chưa gắn Template (hoặc Template không có Step) MUST bị chặn Upload với thông báo lỗi trên từng file, không có tác dụng phụ (SharePoint/DB). Combobox Step của popup Edit document Type "PO" MUST dùng cùng tập Step này.

## Key Entities *(include if feature involves data)*

- **EUTR Document**: Đại diện cho một document EUTR. Thuộc tính: định danh, File name (văn bản,
  không duy nhất giữa các document, VARCHAR(255)), Valid from, Valid to, FileId, **`Invoice`** (chuỗi,
  nullable — cột mới, Update 23), người tạo, ngày tạo, người cập nhật, ngày cập nhật. Lưu vào bảng
  `eutr_documents`. Mọi document mới MUST được tạo thông qua một lượt Upload thành công trong popup Add
  (không còn cách tạo document nào khác) — Valid from/Valid to lấy từ giá trị đang hiển thị ở popup tại
  thời điểm Upload (mặc định ngày hiện tại/ngày tối đa, có thể chỉnh sửa). `FileId` dùng làm khóa để
  đọc lại nội dung file thật từ SharePoint khi nhấn icon View; document có `FileId = null` (dữ liệu cũ)
  không có nội dung để xem trước. **(Update 23)** `Invoice` chỉ được ghi giá trị khi Type đã chọn/hiện
  tại của document = "Invoice" (nhập ở popup Add/Edit); mọi Type khác giữ `null`. Edit MUST có thể cập
  nhật trực tiếp `ValidFrom`/`ValidTo`/`Invoice` của document mà không tạo bản ghi mới. **(Update 24)**
  `Invoice` MUST hiển thị trên bảng danh sách chính (cột riêng, ngay sau Step name) — xem FR-061.
  **(Update 25)** File name KHÔNG còn là tên file gốc người dùng chọn — MUST là giá trị hệ thống tự
  tính từ Step tại thời điểm Upload; không duy nhất giữa các document vẫn đúng như trước, nay càng rõ
  hơn vì nhiều file khác nhau upload cùng Type/Step MUST tạo File name giống hệt nhau (xem FR-067).
  **(Update 26)** Công thức tính File name KHÔNG còn cộng thêm Prefix của `eutr_master_documents` —
  MUST chỉ gồm `Name` của Step đã làm sạch + đuôi file gốc, xem FR-062/FR-063/FR-064/FR-068. Document
  tạo trước Update 26 giữ nguyên File name cũ (có thể vẫn còn Prefix) — không có migration/backfill nào
  chạm dữ liệu cũ.
- **EUTR Reference (liên kết Document ↔ Step/Type/Value)**: Bảng `eutr_references` (Id, RefId,
  DocumentId, StepId, RefType, RefValue). Mỗi file upload thành công qua popup Add tạo một hoặc nhiều
  bản ghi: với Type khác "PO", một bản ghi cho mỗi chip Value đã chọn (`RefValue` = giá trị chip); với
  Type = "PO", một bản ghi cho mỗi `StepId` khớp Prefix (`RefValue` = mã PO đã chọn, giống nhau trên
  các bản ghi). `RefType` = `Id` của bản ghi `eutr_reference_types` đã chọn ở Type. Cột `RefId` hiện
  có KHÔNG được ghi bởi feature này (giữ nguyên mục đích thiết kế cũ, trỏ tới `eutr_template_details`).
  **(Update 23)** Bảng này KHÔNG liên quan tới Invoice number — giá trị đó lưu trên `eutr_documents`
  (xem entity trên), không thêm cột nào ở đây. Bảng này là nguồn dữ liệu duy nhất cho cột Step
  name/Type/Conditions trên danh sách chính (JOIN `eutr_steps`/`eutr_reference_types`; `RefValue`
  hiển thị trực tiếp làm chip Conditions). Edit (User Story 3) với Type = "PO" MUST cập nhật trực tiếp
  `StepId` của mọi bản ghi thuộc một document khi Save — không xóa/tạo lại bản ghi nào. Edit với Type
  khác "PO" (Update 22) MUST đồng bộ cả tập bản ghi theo tập chip Value đang hiển thị khi Save — tạo
  bản ghi mới cho chip mới thêm, xóa bản ghi cho chip đã xóa, và cập nhật `StepId` của mọi bản ghi còn
  lại (xem FR-052). Xóa document (User Story 4) MUST xóa toàn bộ bản ghi có `DocumentId` tương ứng,
  cùng giao dịch.
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
  Bảng `eutr_master_documents` (Id, StepId, Prefix), quản lý bởi feature `002-eutr-masters`. **(Update
  29)** Kể từ Update 29, feature này KHÔNG còn đọc bảng này ở bất kỳ luồng nào (Upload, Edit) — mô tả
  (a)/(b) dưới đây chỉ còn đúng cho lịch sử TRƯỚC Update 29, giữ lại để tham chiếu: (a) validate tên
  file khi Type = "PO" — `Prefix` chỉ duy nhất theo cặp (`StepId`, `Prefix`), một chuỗi Prefix có thể
  khớp nhiều `StepId`, khi đó mỗi `StepId` khớp tạo một bản ghi `eutr_references` riêng; (b) (Update 26,
  sửa Update 25) chọn Step dùng để đặt tên file khi Upload — với Type khác "PO", Step đã chọn tường
  minh dùng trực tiếp; với Type = "PO", trong số các bản ghi đã khớp ở (a), chọn bản ghi có `Prefix`
  **dài nhất** để xác định Step thắng cuộc (tie-break không đổi từ Update 25) — nhưng kể từ Update 26,
  giá trị `Prefix` CHỈ dùng để tie-break, KHÔNG còn được đọc/ghép vào File name. Từ Update 29, Type =
  "PO" xác định (các) Step khớp bằng cách so tên file với `Name` của các Step đã gán cho Type "PO" qua
  `eutr_reference_type_details` (xem FR-074/FR-075), và KHÔNG còn đổi tên file (xem FR-077) — bảng
  `eutr_master_documents` vẫn tồn tại, vẫn được CRUD bởi `002-eutr-masters`, chỉ không còn ai đọc nó từ
  feature này.
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
- **SC-013 (Update 23)**: 100% lượt Upload thành công với Type = "Invoice" tạo ra bản ghi
  `eutr_documents` có cột `Invoice` đúng bằng giá trị Invoice number đã nhập ở popup tại thời điểm
  Upload; 100% document Type khác "Invoice" giữ cột `Invoice` = `null`; không bản ghi `eutr_references`
  nào (của bất kỳ Type nào) có giá trị Invoice number ghi vào.
- **SC-014 (Update 23)**: 100% lượt Save trong popup Edit với document Type = "Invoice" cập nhật đúng
  cột `Invoice` trên bản ghi `eutr_documents` của document đó thành giá trị mới.
- **SC-015 (Update 24)**: 100% document có `eutr_documents.Invoice` khác `null` hiển thị đúng giá trị
  đó ở cột Invoice (ngay sau cột Step name) trên bảng danh sách chính; 100% document `Invoice = null`
  hiển thị cột này ở trạng thái trống.
- **SC-016 (Update 25, công thức đã sửa ở SC-017/Update 26)**: 100% lượt Upload thành công (Type khác
  "PO" và Type = "PO") tạo `eutr_documents.Name` không chứa ký tự `\` hay chuỗi `..`; 0% document tạo
  mới sau Update này còn giữ nguyên tên file gốc làm File name.
- **SC-017 (Update 26)**: 100% lượt Upload thành công (Type khác "PO" và Type = "PO") sau Update 26 tạo
  `eutr_documents.Name` đúng theo công thức Step Name (đã làm sạch) + đuôi file gốc — KHÔNG chứa Prefix
  của `eutr_master_documents` ở đầu tên, dù Step đó có cấu hình Prefix hay không.
- **SC-018 (Update 27)**: 100% lượt Upload file `.xml`/`.json`/`.geojson` hợp lệ (≤10MB) được chấp
  nhận (không còn bị loại vì "Invalid file type"); 100% trường hợp 2 file khác đuôi (ví dụ `.pdf` và
  `.xml`) cùng khớp Prefix/Step trong cùng lượt hoặc các lượt Upload khác nhau đều xuất hiện đầy đủ
  trên cây Step ở `005-eutr-sales-orders`/`012-eutr-purchase-orders` (badge "+N" và tooltip liệt kê đủ
  tên cả 2 file).
- **SC-019 (Update 28)**: 100% lượt Upload file hợp lệ có kích thước trong khoảng 10MB–20MB được chấp
  nhận (không còn bị loại vì kích thước, khác với trước Update 28); 100% file > 20MB tiếp tục bị loại
  kèm thông báo lỗi rõ ràng.
- **SC-020 (Update 29)**: 100% lượt Upload thành công với Type = "PO" sau Update 29 tạo
  `eutr_documents.Name` đúng bằng tên file gốc người dùng đã chọn (không đổi tên) và ghi đủ
  `eutr_references` cho mọi Step (đã gán cho Type "PO") mà tên file gốc có chứa; 0% lượt Upload Type =
  "PO" còn tra cứu `eutr_master_documents`/`Prefix`.
- **SC-021 (Update 29, sửa lại sau kiểm thử thật)**: 100% file upload với Type = "PO" mà tên KHÔNG
  chứa tên bất kỳ Step nào trong `eutr_steps` bị loại khỏi lượt upload kèm thông báo lỗi rõ ràng nêu lý
  do "không tìm được step tương ứng"; 0% document/`eutr_references` được tạo cho các file này.
- **SC-022 (Update 30)**: 100% lượt mở popup Add với Type khác "Vendor" (hoặc chưa chọn Type) không
  hiển thị Valid from/Valid to; 100% document tạo qua các lượt đó có Valid from/Valid to đúng bằng giá
  trị mặc định (ngày hiện tại/`9999-12-31`) dù người dùng không thấy/không sửa được 2 trường này. 100%
  lượt chọn Type = "Vendor" hiển thị lại đúng 2 trường, cho phép sửa như trước Update 30.

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
- **(Update 23)** Cột `Invoice` mới trên `eutr_documents` (không phải `eutr_references`) không có ràng
  buộc duy nhất (unique) và không được dùng để tính cột Conditions/tiêu chí lọc ở search box — phạm vi
  cập nhật này chỉ dừng ở việc thu thập và lưu trữ giá trị, hiển thị/lọc thêm theo cột này (nếu cần)
  thuộc phạm vi một cập nhật sau.
- **(Update 23)** Giá trị Invoice number áp dụng đồng nhất cho mọi document tạo ra trong cùng một lượt
  Upload (khi chọn nhiều file cùng lúc, mỗi file → một document → một giá trị `eutr_documents.Invoice`)
  — cùng cách Valid from/Valid to đã áp dụng từ Update 19; không có input Invoice number riêng theo
  từng file.
- **(Update 23)** Trường Invoice number là bắt buộc khi Type = "Invoice" ở cả Add và Edit (đã xác nhận
  qua clarify) — không có giá trị mặc định, người dùng phải nhập trước khi Upload/Save.
- **(Update 23)** Lưu trên `eutr_documents` (1 dòng/1 document) thay vì `eutr_references` (có thể
  nhiều dòng/1 document, ví dụ nhiều `StepId` khớp Prefix) loại bỏ hoàn toàn nhu cầu đồng bộ/hòa giải
  giá trị Invoice number giữa nhiều bản ghi — không cần migration nào trên `eutr_references` cho tính
  năng này (chỉ `eutr_documents` cần cột mới).
- **(Update 26, thay thế Update 25)** Prefix KHÔNG còn được nối vào File name — công thức Update 25
  ("Prefix + Step Name, nối trực tiếp không có ký tự phân cách") bị thay thế hoàn toàn; File name kể từ
  Update 26 chỉ gồm Step Name đã làm sạch + đuôi file gốc (xem FR-068, SC-017).
- **(Update 26)** Document tạo trước Update 26 (File name có thể vẫn còn Prefix ở đầu, theo công thức
  Update 25) KHÔNG được migration/backfill lại theo công thức mới — chỉ document tạo mới qua Upload sau
  Update 26 áp dụng công thức chỉ-Step-Name.
- **(Update 27)** SharePoint (`ISharepointService.UploadFile`) chấp nhận lưu trữ file `.xml`/`.json`/
  `.geojson` không khác gì các định dạng hiện có — không có xử lý/ánh xạ Content-Type đặc thù nào theo
  từng định dạng trong phạm vi feature này; icon View xem trước file thật dùng chung 1 cơ chế đọc
  base64 từ SharePoint cho mọi định dạng, không có trình xem/preview chuyên biệt cho XML/JSON/GeoJSON.
- **(Update 28)** Giới hạn 20MB/file là giới hạn duy nhất, áp dụng đồng nhất cho mọi định dạng — không
  có giới hạn tổng dung lượng cho cả lượt Upload nhiều file, không có giới hạn riêng biệt theo Type
  (PO/Vendor/Invoice/...). SharePoint/`ISharepointService.UploadFile` và cấu hình server (kích thước
  request tối đa của API) được giả định đã hỗ trợ file tới 20MB — không có thay đổi hạ tầng nào khác
  trong phạm vi feature này ngoài hằng số giới hạn ở tầng validate.
- **(Update 25)** Đuôi file gốc (phần mở rộng) được giữ nguyên y hệt (kể cả hoa/thường) khi ghép vào tên
  mới — không thuộc phạm vi làm sạch/đổi tên, vì đuôi file đã được validate thuộc danh sách định dạng
  cho phép ở FR-018 trước khi tới bước đổi tên.
- **(Update 25)** Popup Add KHÔNG hiển thị bản xem trước/gợi ý tên file mới trước khi Upload (giao diện
  hiện tại không hiển thị tên file đã chọn ở bất kỳ đâu trước khi Upload) — người dùng chỉ thấy File
  name đã đổi sau khi quay lại danh sách chính (User Story 1); phạm vi cập nhật này không yêu cầu thêm
  UI xem trước tên mới trong popup.
- **(Update 25)** Thông báo lỗi cho file bị từ chối trước khi tạo document (sai định dạng/kích thước,
  không khớp Prefix khi Type = "PO") tiếp tục dùng tên file gốc để liệt kê — hành vi hiện có của
  `EutrUploadService` không đổi, vì bước đổi tên chỉ chạy cho các file ĐÃ upload thành công.
- **(Update 25)** Việc kế thừa hành vi đổi tên sang `005-eutr-sales-orders` và `012-eutr-purchase-orders`
  không cần thay đổi backend/frontend riêng ở hai feature đó — cả hai đều gọi đúng cùng endpoint/luồng
  Upload dùng chung với `004-eutr-documents`, không có logic đặt tên file độc lập nào ở tầng feature của
  chúng; xem ghi chú kế thừa trong Update 25 ở mục Clarifications.
- **(Update 29, sửa lại sau kiểm thử thật)** Tập Step dùng để so khớp tên file khi Type = "PO" **ban
  đầu** chọn là Step đã được gán cho Type "PO" qua tính năng Assign Steps (`eutr_reference_type_details`,
  cùng cơ chế Update 20 dùng cho mọi Type khác) — xác nhận qua `AskUserQuestion` khi viết bản cập nhật
  này. Kiểm thử thật ngay sau khi triển khai cho thấy quyết định này sai: `eutr_reference_type_details`
  không liên quan gì tới cây Step của Template (nguồn hiển thị thật là `eutr_template_details`), nên
  hầu như luôn rỗng cho Type "PO" — mọi file hợp lệ đều bị báo lỗi sai dù tên file khớp rõ ràng một Step
  đang hiển thị trên cây. Đã sửa lại: dùng **toàn bộ `eutr_steps`** (không lọc theo Type) — khớp đúng
  tính chất "phẳng, không giới hạn Type" mà `eutr_master_documents` (cơ chế cũ) vốn đã có. Nếu về sau
  phát sinh nhu cầu so khớp trên một tập Step hẹp hơn (ví dụ theo Template cụ thể của PO đang upload),
  đó là một quyết định phạm vi mới, cần yêu cầu tường minh, không tự suy diễn từ Update này.
- **(Update 29)** Việc bỏ đổi tên file cho Type = "PO" KHÔNG kèm migration/backfill nào cho document đã
  tạo trước Update 29 — các document đó giữ nguyên File name cũ (đã đổi theo Step Name ở Update 25/26);
  chỉ document Upload MỚI sau Update 29 mới có File name = tên file gốc.
- **(Update 29)** Việc kế thừa các thay đổi ở Update này sang `005-eutr-sales-orders` và
  `012-eutr-purchase-orders` (matching + bỏ đổi tên khi Upload) không cần thay đổi backend riêng ở hai
  feature đó với vai trò popup Add/Edit dùng chung — nhưng RIÊNG phần hiển thị tên file trên cây
  Template (Step 2 Map File / `PurchId/View`) và phần đổi tên file khi Download (đã có nhánh riêng ở
  frontend hai feature đó) đòi hỏi thay đổi cụ thể riêng — xem Update tương ứng trong spec của
  `005-eutr-sales-orders`/`012-eutr-purchase-orders`.
- **(Update 30)** Phạm vi ẩn Valid from/Valid to CHỈ áp dụng cho popup Add (mode `add`) theo đúng ảnh
  chụp màn hình kèm yêu cầu gốc — không tự suy rộng sang popup Edit (mode `edit`), vì Edit có thể đang
  hiển thị giá trị THẬT khác mặc định của một document đã tồn tại (kể cả document Type khác "Vendor" đã
  từng có Valid from/Valid to khác mặc định, do được tạo từ trước Update 30, hoặc do luồng khác ghi
  đè) — ẩn ở Edit sẽ khiến người dùng mất khả năng xem/sửa giá trị thật đang lưu trên document đó. Nếu
  về sau có yêu cầu tường minh mở rộng ẩn sang cả Edit, đó là quyết định phạm vi mới, không suy diễn từ
  Update này.
- **(Update 30)** Việc kế thừa sang `005-eutr-sales-orders`/`012-eutr-purchase-orders` không cần thay
  đổi gì thêm — cả hai đều mở đúng popup Add/Edit dùng chung (`EutrDocumentsFormDialog.jsx`) qua nút
  Upload ở Step 2 Map File/`PurchId/View`, không có logic hiển thị Valid from/Valid to riêng nào ở tầng
  feature của chúng.
