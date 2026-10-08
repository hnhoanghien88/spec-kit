# Feature Specification: EUTR Purchase Orders

**Feature Branch**: `012-eutr-purchase-orders`

**Created**: 2026-08-14

**Status**: Draft

**Input**: User description: "chức năng mới eutr-purchase-orders. màn hình hiển thị dữ liệu từ API reference với type = 15, các cột hiển thị. Purch id, Vendor code, Vendor name, Template, Progress, Action [View]. Progress dựa vào Template (003-eutr-templates) để lấy ra các step rồi kiểm tra với 004-eutr-documents để biết step nào có tài liệu, missing. Bấm vào View thì vào màn hình PurchId/View. màn hình giống link eutr/sales-orders/SO004813/map-file ở 005-eutr-sales-orders. nhưng bỏ phần Step 1 choose Purchase order, rồi chỗ hiển thị thông tin Sales ID, Customer thì đổi thành thông tin Purch id, bỏ thông tin seelcted POs"

## Clarifications

### Session 2026-10-08 (Update 45) — Upload file ở PurchId/View: chỉ khớp Step của Template của PO; PO chưa gắn Template thì chặn Upload (kế thừa `004-eutr-documents` Update 32)

- Input: "kiểm tra lại logic upload file ở 004-eutr-documents, 005-eutr-sales-orders, 012-eutr-purchase-orders … phải dựa vào step của template mà gắn chứ không phải toàn bộ step trong dữ liệu"; "PO chưa gắn template thì nên chặn upload và báo lỗi".
- Change: Upload ở màn hình View dùng chung `POST /api/sharepoint/eutr-upload-multi` → MUST chỉ khớp tên file với Step thuộc Template của PO đang xem; PO chưa gắn Template → Upload bị chặn với lỗi "PO has no template assigned. Please assign a template before uploading.". Chi tiết: `004-eutr-documents` FR-082, research Quyết định 83. Không đổi cây Template hay endpoint của feature này.

### Session 2026-10-07 (Update 14) — Chiều cao khung AVAILABLE FILES bằng chiều cao khung Template

- Input: "màn hình AVAILABLE FILES (19), khi nhiều file hiển thị thanh scroll, chiều cao chỉnh cho bằng với cột template".
- Change (FR-048): Khung AVAILABLE FILES MUST có chiều cao đúng bằng khung cây Template bên trái (không dài hơn
  theo số file); khi nhiều file, danh sách cuộn bên trong khung. Chỉ đổi giao diện (`PurchaseOrderViewPage.jsx`).

### Session 2026-10-07 (Update 13) — Nút "Assign template" ở cột Action của danh sách Purchase Orders: chọn 1 template active và đẩy lên D365

- Input: "cập nhật 012-eutr-purchase-orders, thêm nút Asign template ở cột Action, kế nút View. Khi bấm
  vào hiển thị popup list template active. User chỉ dc chọn 1. sau đó nhấn OK, dữ liệu sẽ đẩy lên D365
  (`updateEutr` của `RSVNPurchTables`, cross-company) với 3 biến string: purchId, templateId, versionId".
- Bối cảnh: Hiện cột Template của danh sách chỉ hiển thị Template đang gắn trên Purchase Order (đọc từ
  D365); chưa có cách gán/đổi Template cho Purchase Order ngay từ màn hình này.
- Change: Cột **Action** của danh sách Purchase Orders MUST có thêm nút **Assign template** đặt ngay
  bên phải nút **View** ở mỗi dòng. Nhấn nút MUST mở popup liệt kê các template đang **active**; người
  dùng chỉ được chọn **đúng 1** template; nhấn **OK** MUST đẩy lựa chọn lên D365 cho đúng Purchase Order
  của dòng đó, gồm 3 giá trị chuỗi: `purchId` (Purch id của dòng), `templateId` (mã template được
  chọn), `versionId` (version của template được chọn).
- Quyết định (mặc định hợp lý, ghi ở Assumptions): "active" = template chưa bị xóa và là phiên bản hiện
  hành (không phải dòng cũ đã ẩn do lên version) và đã Approved; `templateId` = mã (Code) của template, `versionId` =
  VersionId của chính dòng template được chọn (cả hai gửi dạng chuỗi).
- Không đổi: các cột hiện có, nút View, tìm kiếm/phân trang, màn hình `PurchId/View`.
- Q: Popup Assign template có hiển thị template Draft không? → A: Không — chỉ template chưa xóa, là
  phiên bản hiện hành và đã Approved.
- Q: Popup xử lý template hiện tại của Purchase Order thế nào? → A: Chọn sẵn và đánh dấu "Current"; OK
  chỉ bật khi chọn template khác template hiện tại.
- Q: Có lọc template theo Vendor của Purchase Order không? → A: Không — hiển thị mọi template active
  (Approved), không xét Vendor.
- Q: Ai được thấy nút Assign template? → A: Chỉ người có quyền Update của menu EUTR Purchase Orders; nút
  ẩn với người còn lại.

### Session 2026-10-05 (Update 12) — Bỏ phân trang ở khu vực AVAILABLE FILES — hiển thị toàn bộ file trong một danh sách cuộn

- Input: "cập nhật 005-eutr-sales-orders, màn hình map file, bỏ phân trang ở Available files và
  012-eutr-purchase-orders cũng bỏ phân trang ở Available files".
- Bối cảnh (rà soát mã nguồn): Khu vực AVAILABLE FILES của `PurchId/View` (`PurchaseOrderViewPage.jsx`, clone của Map File Step 2) đang chia danh sách file thành từng trang 10 file
  (hằng `FILES_PER_PAGE = 10`) kèm thanh phân trang và dòng đếm "x–y / N files" ở chân khung.
- Change: Khu vực **AVAILABLE FILES** MUST hiển thị TOÀN BỘ file (sau khi áp dụng bộ lọc theo Step khi
  click node cây, nếu có) trong một danh sách duy nhất, người dùng cuộn dọc trong khung để xem — KHÔNG
  còn thanh phân trang. Chân khung (footer) hiển thị tổng số file ("N files") thay cho dải
  "x–y / N files".
- Không đổi: nguồn dữ liệu, bộ lọc theo Step, các nút View/Edit/Download trên từng dòng, thứ tự sắp xếp,
  trạng thái rỗng/đang tải. Phân trang của danh sách Overview KHÔNG bị ảnh hưởng.
- Kế thừa: Áp dụng nguyên vẹn quyết định đã chốt ở `005-eutr-sales-orders` Update 44 (FR-236) vào màn hình này.

### Session 2026-09-30 (Update 11) — Kế thừa `004-eutr-documents` Update 29 (matching Type = "PO" theo tên Step, bỏ đổi tên khi Upload); cây Template hiển thị tên file thay tên Step khi đã upload; bỏ đổi tên file khi Download cho document Type = "PO"

- Input: "cập nhật 004-eutr-documents, 005-eutr-sales-orders, 012-eutr-purchase-orders khi upload
  file với type = PO, bỏ logic kiểm tra với eutr_master_documents. thay đổi thành so sánh tên step
  với tên file... Màn hình hiển thị template, khi file đã upload, phần tên step sẽ lấy tên file gắn
  vào để hiện thị (...) file chưa upload thì hiển thị tên step bình thường, bỏ logic đổi tên file
  theo tên step, tên file ntn giữ nguyên khi up và khi tải".
- Kế thừa (không cần thay đổi riêng): Nút **Upload**/**Edit** ở `PurchId/View` (FR-021/FR-022) tiếp
  tục gọi đúng popup Add/Edit dùng chung với `004-eutr-documents` — nên tự động kế thừa nguyên vẹn
  thay đổi matching/bỏ đổi tên khi Upload cho Type = "PO" đã đặc tả ở `004-eutr-documents` Update 29
  (FR-020, FR-074 đến FR-079); riêng ở màn hình này, popup Upload còn tự điền sẵn Type = "PO" (Update
  1, FR-024) — nếu người dùng giữ nguyên Type đó, vẫn áp dụng đúng nhánh Type = "PO" mới.
- Bối cảnh (rà soát mã nguồn): Cây Step ở `PurchId/View` (clone cùng cấu trúc `TreeNode` với Map File
  Step 2 của `005-eutr-sales-orders`) hiện LUÔN hiển thị `node.stepName` làm nhãn — chưa có logic thay
  nhãn theo tên file đã upload. Nút Download ở AVAILABLE FILES (Update 9, FR-037/FR-038) hiện luôn
  tính lại tên file khi tải về = `Name` của Step cho **mọi** document, bất kể Type.
- Change (MỚI — cây Template): Áp dụng nguyên vẹn quyết định đã chốt ở `005-eutr-sales-orders` Update
  37 (xem FR-216 và Clarifications Update 37 của đặc tả đó để biết đầy đủ rationale) vào `PurchId/View`:
  mỗi node Step trong cây đang có ít nhất một tài liệu khớp (missing = false) MUST hiển thị nhãn = tên
  file (bỏ đuôi) của tài liệu khớp **đầu tiên**, thay cho `Name` của Step; node CHƯA có tài liệu nào
  khớp (còn "missing") MUST tiếp tục hiển thị `Name` của Step. Áp dụng cho mọi Type tài liệu.
- Change (Download, Type = "PO"): Áp dụng nguyên vẹn quyết định đã chốt ở `005-eutr-sales-orders`
  FR-217 vào `PurchId/View`: với document Type = "PO", tên file khi tải về (nút Download ở dòng
  AVAILABLE FILES lẫn nút Download trong popup View, FR-037/FR-038) KHÔNG còn tính lại = Step Name —
  MUST dùng đúng `eutr_documents.Name` đã lưu (từ `004-eutr-documents` Update 29 trở đi là tên file
  gốc) + đuôi file gốc. Document Type khác "PO" (nếu có, qua việc người dùng tự đổi Type ở popup Add)
  tiếp tục tính lại tên = Step Name (FR-038) như hiện có.

### Session 2026-09-24 (Update 10) — Thêm nút Search rõ ràng kế bên ô tìm kiếm ở danh sách Purchase Orders

- Input: "Thêm nút search kế bên text search để user có thể click rồi danh sách hiển thị theo điều
  kiện nhập vào ở 012-eutr-purchase-orders" (kèm ảnh chụp màn hình Overview với ô tìm kiếm đã nhập
  "CC01226", danh sách đã lọc đúng theo Vendor code đó).
- Bối cảnh: Ô tìm kiếm hiện có ở `PurchaseOrderOverviewPage.jsx` đã hoạt động (tìm theo Purch id/Vendor
  code, khớp "chứa", User Story 3 hiện có) nhưng chỉ có cơ chế tự động lọc lại sau 500ms kể từ lần gõ
  cuối (debounce) — chưa có nút bấm rõ ràng nào để chủ động áp dụng ngay điều kiện đang nhập. Đã tìm
  thấy đúng mẫu (nút **Search** cạnh ô tìm kiếm) đã có sẵn ở `005-eutr-sales-orders` Overview
  (`SalesOrderOverviewPage.jsx`, Update 24) — tái sử dụng cùng cách bố trí/hành vi cho nhất quán.
- Change: Thêm nút **Search** (kiểu `variant="contained"`) ngay bên phải ô tìm kiếm hiện có ở màn hình
  danh sách Purchase Orders — nhấn nút MUST áp dụng ngay từ khóa đang nhập trong ô tìm kiếm, về lại
  trang đầu, không cần đợi debounce 500ms.
- Change: Cơ chế tự động lọc sau debounce (gõ xong đợi 500ms) hiện có MUST giữ nguyên không đổi, hoạt
  động song song với nút Search mới — nút Search chỉ bổ sung một cách áp dụng "ngay lập tức", không
  thay thế hành vi tự động hiện có.
- Q: Nút Search mới có cần đồng bộ điều kiện tìm kiếm lên URL (query params, để khôi phục khi Back)
  như `005-eutr-sales-orders` đã làm ở Update 24 không? → A: **Không** — màn hình Overview của
  `012-eutr-purchase-orders` hiện chưa có cơ chế khôi phục từ khóa/trang qua URL nào (không giống
  `005-eutr-sales-orders`), yêu cầu gốc chỉ đề cập thêm nút bấm; xây thêm hạ tầng URL sync nằm ngoài
  phạm vi yêu cầu này.

### Session 2026-09-24 (Update 9) — Thêm nút Download riêng cho từng dòng AVAILABLE FILES; tải file với tên = Step Name

- Input: "thêm nút download kế nút edit ở màn hình available file. Khi downfile về hiện tại có chỉnh
  tên file = step name + prefix, đổi lại chỉ cần đổi tên file thành step name là dc". Yêu cầu này áp
  dụng chung cho cả `005-eutr-sales-orders` (Map File Step 2) lẫn `012-eutr-purchase-orders`
  (`PurchId/View`) — `PurchaseOrderViewPage.jsx` là bản clone cùng cấu trúc AVAILABLE FILES với
  `MapFilePage.jsx` (`005-eutr-sales-orders`), nhưng là code riêng của đặc tả này (không gọi qua
  component dùng chung) nên cần khai báo FR/task riêng ở đây, không chỉ ghi chú kế thừa.
- Change: Áp dụng nguyên vẹn quyết định đã chốt ở `005-eutr-sales-orders` Update 33 (xem FR-194 đến
  FR-197 và research Quyết định 82/83 của đặc tả đó để biết đầy đủ rationale) vào `PurchId/View`: thêm
  nút Download sau nút Edit trên mỗi dòng AVAILABLE FILES; tên file tải về (cả nút Download mới lẫn nút
  Download có sẵn trong popup View, dùng chung component `EutrFileViewerDialog`) tính lại = Step Name
  (Step đầu tiên nếu khớp nhiều Step), không đọc thẳng `eutr_documents.Name` đã lưu — áp dụng cho mọi
  document kể cả document cũ tạo trước `004-eutr-documents` Update 26.
- Change: Không ghi đè/backfill `eutr_documents.Name` trong DB, không ảnh hưởng cột File name hiển thị
  trên AVAILABLE FILES hay bất kỳ màn hình nào khác — giống hệt phạm vi đã xác định ở
  `005-eutr-sales-orders` Update 33.

### Session 2026-09-24 (Update 8) — Kế thừa: Tăng giới hạn kích thước file lên 20MB khi Upload (004-eutr-documents Update 28)

- Input: "mở giới hạn file upload lên 20MB" được gửi cho `004-eutr-documents`, áp dụng chung cho
  `005-eutr-sales-orders`/`012-eutr-purchase-orders` qua popup Add/Edit dùng chung.
- Change: Popup Add/Edit ở `PurchId/View` (FR-021/FR-022) tiếp tục dùng chung với `004-eutr-documents`
  — không có validate kích thước riêng ở đặc tả này — nên tự động kế thừa giới hạn kích thước mới
  (20MB, `004-eutr-documents` Update 28, FR-073) mà không cần thay đổi gì thêm.
- Change: Không có thay đổi nào cần thực hiện riêng ở `012-eutr-purchase-orders`.

### Session 2026-09-24 (Update 7) — Kế thừa: Mở rộng whitelist định dạng file (.xml/.json/.geojson) khi Upload (004-eutr-documents Update 27)

- Input: yêu cầu cho phép 1 Step chứa nhiều file khác đuôi (ví dụ `.pdf` và `.xml`) nếu cùng Prefix,
  hiển thị rõ trên view, được gửi cho `004-eutr-documents`, kèm chỉ định "cập nhật 004-eutr-documents,
  005-eutr-sales-orders, 012-eutr-purchase-orders". Rà soát mã nguồn xác nhận: cây Step ở `PurchId/View`
  (clone cùng logic `TreeNode` với Map File Step 2 của `005-eutr-sales-orders`) **đã hiển thị sẵn**
  nhiều file/1 node Step qua badge "(+N)" và tooltip liệt kê đủ tên mọi file khớp step đó — không phải
  UI mới; gap thực sự duy nhất (whitelist định dạng chặn `.xml`) thuộc phạm vi `004-eutr-documents`
  (Update 27, FR-018/FR-071).
- Change: Popup Add/Edit ở `PurchId/View` (FR-021/FR-022) tiếp tục dùng chung với `004-eutr-documents`
  — không có whitelist định dạng riêng ở đặc tả này — nên tự động kế thừa việc mở rộng định dạng được
  phép upload (`.xml`/`.json`/`.geojson`, `004-eutr-documents` Update 27, FR-071) mà không cần thay đổi
  gì thêm.
- Change: Không có thay đổi nào cần thực hiện riêng ở `012-eutr-purchase-orders` cho việc "nhiều file
  khác đuôi cùng 1 Step" — cơ chế hiển thị badge "(+N)"/tooltip trên cây Step (`TreeNode`, kế thừa từ
  Map File Step 2) đã hoạt động đúng với bất kỳ số lượng file nào khớp 1 Step từ trước; việc mở rộng
  định dạng ở `004-eutr-documents` chỉ khiến kịch bản `.pdf` + `.xml` (trước đây bị chặn ở bước validate
  định dạng) nay có thể chạm tới được logic hiển thị đã có sẵn này.
- Q: Việc Upload ở `PurchId/View` tự điền sẵn Type = "PO" (Update 1) có ảnh hưởng gì tới việc nhiều file
  khác đuôi cùng khớp 1 Prefix/Step không? → A: **Không** — mỗi file trong 1 lượt Upload (hoặc các lượt
  khác nhau) độc lập khớp Prefix/Step riêng của nó qua `GetMatchingPrefixesAsync`, không có giới hạn nào
  về số file/StepId; hành vi này áp dụng đồng nhất bất kể Type = "PO" tự điền sẵn hay được đổi thủ công.

### Session 2026-09-24 (Update 6) — Kế thừa: Bỏ Prefix khỏi File name tự động khi Upload (004-eutr-documents Update 26)

- Input: yêu cầu bỏ Prefix khỏi công thức đổi tên file khi Upload được gửi cho `004-eutr-documents`,
  kèm chỉ định "cập nhật 004-eutr-documents, 005-eutr-sales-orders, 012-eutr-purchase-orders".
- Change: Nút **Upload** và **Edit** ở màn hình `PurchId/View` (FR-021/FR-022) tiếp tục mở đúng popup
  Add/Edit dùng chung với `004-eutr-documents` và gọi đúng luồng Upload chung — không có logic đặt tên
  file riêng ở đặc tả này — do đó **tự động kế thừa nguyên vẹn** việc bỏ Prefix khỏi công thức đổi tên
  đã đặc tả ở `004-eutr-documents` Update 26 (FR-068 đến FR-070 của đặc tả đó, sửa lại FR-062/FR-063
  của Update 25 mà `012-eutr-purchase-orders` Update 3 đã kế thừa): File name của mỗi document tạo qua
  Upload ở đây nay chỉ gồm Step Name đã làm sạch + đuôi file gốc (Step đã chọn tường minh, hoặc — khi
  Type vẫn là "PO" tự điền sẵn theo Update 1 — Step ứng với Prefix khớp dài nhất, Prefix nay chỉ dùng để
  chọn Step, không còn ghép vào tên) — KHÔNG còn ghép thêm Prefix của `eutr_master_documents` như trước.
- Change: Không có thay đổi nào cần thực hiện riêng ở `012-eutr-purchase-orders` (không có FR/Key
  Entity nào của đặc tả này cần cập nhật) — khu vực AVAILABLE FILES ở `PurchId/View` tiếp tục hiển thị
  đúng giá trị `eutr_documents.Name` hiện có trong DB tại thời điểm đọc, tự động phản ánh công thức tên
  mới. Document tạo trước Update này giữ nguyên File name cũ (có thể vẫn còn Prefix) — không migration/
  backfill nào chạm dữ liệu cũ (kế thừa từ `004-eutr-documents` Update 26).
- Q: Việc Upload ở `PurchId/View` tự điền sẵn Type = "PO" (Update 1), khiến hầu hết lượt Upload rơi vào
  nhánh Type = "PO" (Step suy ra từ khớp Prefix), có ảnh hưởng gì tới đặc tả này khi Prefix không còn
  được ghép vào tên không? → A: **Không** — nhánh Type = "PO" vẫn dùng Prefix để chọn Step thắng cuộc
  (tie-break không đổi từ `004-eutr-documents` Update 25/FR-063), chỉ không còn đọc giá trị `Prefix` khi
  ghép chuỗi tên; hành vi này áp dụng đồng nhất cho mọi Type, không cần quy tắc riêng ở đặc tả này.

### Session 2026-09-23 (Update 5) — Ẩn nút Upload/Edit theo permissionList của menu eutr-documents (sửa lại cả cơ chế Upload của Update 4)

- Input: Cập nhật 005-eutr-sales-orders, 012-eutr-purchase-orders màn hình view, map file: nếu không
  có quyền `EutrDocuments.Create` sẽ không hiển thị nút attach file (Upload), không có quyền
  `EutrDocuments.Update` sẽ không hiển thị nút Edit file.
- Bối cảnh: Update 4 (phiên trước) đã ẩn nút **Upload** ở `PurchId/View` theo đúng quyền tạo tài liệu
  mới, nhưng dùng cơ chế dò quyền qua endpoint mới `GET /api/eutr-documents/can-create` — phần Edit
  chưa được xử lý (Update 4 cố ý để ngoài phạm vi: "nút Edit ... tiếp tục hiển thị và hoạt động bình
  thường, không bị ảnh hưởng"). Bản đầu của Update 5 định giải quyết phần Edit bằng cách thêm endpoint
  `can-update` mới (mô phỏng `can-create`), tái sử dụng từ `005-eutr-sales-orders` Update 29 (cùng
  phiên).
- **Sửa lại sau kiểm thử thực tế (cùng phiên)**: người yêu cầu tính năng kiểm thử trực tiếp trên trình
  duyệt (`/eutr/purchase-orders/PO00000059/view`), thu hồi quyền `EutrDocuments.Create`/
  `EutrDocuments.Update` cho user test, nhưng nút Upload lẫn Edit đều vẫn hiển thị. Chụp màn hình
  DevTools Network xác nhận: response của `GET .../menu-managements/permissions?appCode=ComplApi&...`
  cho menu `eutr-documents` (id 242) đã có sẵn field `permissionList` — cùng cơ chế
  `permissionList`/`getMenuDataFromStorage` đã dùng ở `005-eutr-sales-orders` Update 28 (menu
  `eutr-sales-orders`) — và `'Create'`/`'Update'` là 2 phần tử hợp lệ trong `permissionList` đó (user
  test lúc chụp chỉ có `['Download', 'ReadAll', 'ReadOne', 'ViewMenu']`, thiếu cả hai). Vì vậy cả cơ chế
  dò quyền qua `can-create` (Update 4) lẫn `can-update` (bản đầu của Update 5) đều bị thay thế —
  `permissionList` của menu `eutr-documents` đã đủ dữ liệu, không cần endpoint dò quyền nào.
- Quyết định (đã sửa lại): (1) `PurchaseOrderViewPage.jsx` đọc `permissionList` của menu
  `eutr-documents` qua đúng `getMenuDataFromStorage()` đã dùng ở Update 28 của 005. (2) Nút **Upload**
  chỉ hiển thị khi `permissionList.includes('Create')` — thay thế hoàn toàn cơ chế `can-create` của
  Update 4 (không phải giữ song song). (3) Nút **Edit** trên mỗi dòng AVAILABLE FILES chỉ hiển thị khi
  `permissionList.includes('Update')` — độc lập với Upload, đúng tinh thần FR-034 (2 quyền độc lập). (4)
  Nút **View** (xem trước nội dung file) không bị ảnh hưởng. (5) Backend không đổi gì —
  `EutrDocuments.Create`/`EutrDocuments.Update` vẫn là 2 policy thật bảo vệ đúng
  `POST /api/eutr-documents`/`PUT /api/eutr-documents/{id}`; 2 endpoint dò quyền `can-create`/
  `can-update` bị xoá hẳn (không còn nơi nào gọi, theo đúng lựa chọn của người yêu cầu tính năng —
  không giữ lại dead code).

### Session 2026-09-07 (Update 1)

- Input: Cập nhật 012-eutr-purchase-orders. Trong màn hình chi tiết (`PurchId/View`), khi người dùng
  nhấn nút Upload, popup Add tài liệu (dùng chung với 004-eutr-documents) hiện đang mở với trường
  **Type** trống (`null`) và trường **Value** trống (`[]`) — giống hệt cách popup mở ở màn hình Map
  File của 005-eutr-sales-orders (không tự điền, theo đúng quyết định Decision 26 của spec đó).
- Change: Riêng ở màn hình `PurchId/View` của 012-eutr-purchase-orders, khi nhấn Upload, popup Add
  tài liệu MUST tự điền sẵn: trường **Type** = `PO`, trường **Value** = chính Purch Id đang xem
  (dòng Purchase Order tương ứng lấy từ nguồn tham chiếu type = 15). Người dùng vẫn có thể đổi Type
  và/hoặc Value sang giá trị khác sau khi popup mở (không khóa/disable hai trường này) — tự điền chỉ
  nhằm giảm thao tác lặp lại cho tình huống phổ biến nhất (đính tài liệu cho đúng PO đang xem).
- Change: Việc tự điền chỉ áp dụng khi nhấn Upload từ màn hình `PurchId/View` (012-eutr-purchase-orders).
  Hành vi Upload ở màn hình Map File (005-eutr-sales-orders) giữ nguyên như cũ — KHÔNG tự điền Type/Value
  — vì Decision 26 của 005-eutr-sales-orders coi đây là quyết định riêng của luồng đó, không bị thay đổi
  bởi cập nhật này.

### Session 2026-09-10 (Update 2)

- Input: Cập nhật 012-eutr-purchase-orders. Ở màn hình chi tiết (`PurchId/View`), khi úp tài liệu, popup
  Add tài liệu có trường **Type** gồm các giá trị **PO**, **Vendor**, **Invoice**, **Delivery note** (các
  loại tham chiếu đã có sẵn trong hệ thống, dùng chung với 004-eutr-documents). Khi người dùng đổi giá
  trị Type, hệ thống MUST tự động điền lại dữ liệu vào trường **Value**: nếu Type là **PO**, **Invoice**,
  hoặc **Delivery note** thì Value tự điền Purch Id của Purchase Order đang xem (dòng đang active trên
  màn hình); nếu Type là **Vendor** thì Value tự điền Vendor Code của Purchase Order đang xem.
- Change: Mở rộng hành vi tự điền của Update 1 (FR-024/025/026, vốn chỉ tự điền một lần khi popup mở với
  Type mặc định = PO) thành tự điền lại Value **mỗi khi Type thay đổi** trong lúc popup đang mở, không
  chỉ ở lần mở đầu tiên — xem FR-027/028/029 mới bổ sung bên dưới.
- Decision: "Purch Id của dòng active" được hiểu là Purch Id của chính Purchase Order đang xem trên màn
  hình `PurchId/View` (đã cố định theo `PurchId` trên URL — màn hình này không có bảng nhiều dòng/nhiều
  Purchase Order để chọn "dòng active" khác, xem Assumptions), thống nhất với cách FR-024 đã dùng "Purch
  Id đang xem" ở Update 1. Tương tự, "Vendor Code" là Vendor code của chính Purchase Order đang xem.
- Decision: Nếu người dùng chọn một Type khác ngoài 4 giá trị trên (ví dụ "General agreement"), Value
  KHÔNG bị tự điền/ghi đè — giữ nguyên hành vi nhập tay hiện có của popup dùng chung (004-eutr-documents)
  cho các Type không thuộc nhóm PO-like/Vendor.
- Decision: Việc tự điền lại Value theo Type mới sẽ **ghi đè** giá trị Value hiện tại (kể cả khi người
  dùng đã tự nhập/đổi Value trước đó) — vì mục tiêu là luôn khớp đúng Type vừa chọn, tránh trường hợp
  Value cũ (thuộc Type trước) bị hiểu nhầm là hợp lệ với Type mới. Value sau khi tự điền lại vẫn KHÔNG bị
  khóa, người dùng vẫn có thể sửa tiếp trước khi lưu (giữ nguyên nguyên tắc "không khóa trường" của
  FR-025).
- Change: Phạm vi áp dụng vẫn giữ nguyên như Update 1 — CHỈ áp dụng cho popup Add tài liệu mở từ nút
  Upload tại `PurchId/View` (012-eutr-purchase-orders). Màn hình Map File (005-eutr-sales-orders) không
  bị ảnh hưởng bởi thay đổi này.

### Session 2026-09-18 (Update 3) — Kế thừa: File name tự động đổi theo Step/Prefix master khi Upload (004-eutr-documents Update 25)

- Input: yêu cầu đổi tên file theo Step/Prefix master được gửi cho `004-eutr-documents`, kèm chỉ định
  "áp dụng logic này cho upload file ở màn hình 005-eutr-sales-orders, 012-eutr-purchase-orders".
- Change: Nút **Upload** và **Edit** ở màn hình `PurchId/View` (FR-021/FR-022) mở đúng popup Add/Edit
  dùng chung với `004-eutr-documents` và gọi đúng luồng Upload chung — không có logic đặt tên file
  riêng ở đặc tả này — do đó **tự động kế thừa nguyên vẹn** hành vi đổi tên file theo Step (+ Prefix
  của `eutr_master_documents`, nếu Step có cấu hình) đã đặc tả ở `004-eutr-documents` Update 25
  (FR-062–FR-067 của đặc tả đó): File name của mỗi document tạo qua Upload ở đây KHÔNG còn là tên file
  gốc, mà là Prefix (nếu có) + Step Name đã chọn (hoặc, khi Type vẫn là "PO" tự điền sẵn theo Update 1,
  Step ứng với Prefix khớp dài nhất), đã làm sạch ký tự đặc biệt, giữ đuôi file gốc.
- Change: Không có thay đổi nào cần thực hiện riêng ở `012-eutr-purchase-orders` (không có FR/Key
  Entity nào của đặc tả này cần cập nhật) — khu vực AVAILABLE FILES ở `PurchId/View` tiếp tục hiển thị
  đúng giá trị `eutr_documents.Name` hiện có trong DB tại thời điểm đọc, tự động phản ánh tên đã đổi.
- Q: Việc Upload ở `PurchId/View` tự điền sẵn Type = "PO" (Update 1) có nghĩa là hầu hết lượt Upload ở
  đây rơi vào nhánh Type = "PO" của Update 25 (Step suy ra từ khớp Prefix, không chọn tường minh) —
  điều này có ảnh hưởng gì tới đặc tả này không? → A: **Không** — Type = "PO" tự điền sẵn nhưng người
  dùng vẫn có thể đổi sang Type khác trước khi Upload (Update 1/2, không khóa trường); dù giữ nguyên
  Type = "PO" hay đổi Type khác, logic đổi tên đều áp dụng đúng theo nhánh tương ứng đã đặc tả ở
  `004-eutr-documents` Update 25 — không cần thêm quy tắc riêng nào ở đặc tả này.

### Session 2026-09-22 (Update 4) — Ẩn nút Upload khi user không có quyền

- Input: Cập nhật 012-eutr-purchase-orders, nếu user không có quyền Update, thì ẩn nút Upload trong
  màn hình view.
- Q: Nút Upload ở `PurchId/View` thực chất mở popup Add tài liệu dùng chung với 004-eutr-documents,
  và hành động Upload gọi đúng luồng tạo tài liệu mới (Create) của đặc tả đó — không phải luồng sửa
  (Update, vốn là hành động của nút Edit). "Quyền Update" mà người dùng nhắc tới nên map vào quyền
  nào để quyết định ẩn/hiện nút Upload? → A: Dùng đúng quyền thật đang bảo vệ hành động Upload (tạo
  tài liệu mới, dùng chung với 004-eutr-documents) — "Update" trong yêu cầu được hiểu theo nghĩa
  nghiệp vụ chung ("người dùng có thể thay đổi/bổ sung dữ liệu hay không"), không phải tên quyền kỹ
  thuật theo đúng nghĩa đen.
- Decision: Nút Upload ở `PurchId/View` MUST chỉ hiển thị khi người dùng hiện tại có quyền thực hiện
  hành động tạo tài liệu mới (Upload/Add) — cùng quyền đang kiểm soát hành động Upload dùng chung với
  004-eutr-documents. Nếu người dùng không có quyền này, nút Upload MUST bị ẩn hoàn toàn (không hiển
  thị dạng vô hiệu hóa/disable).
- Decision: Việc ẩn nút Upload theo Update này CHỈ áp dụng cho chính nút Upload — nút Edit và toàn bộ
  phần còn lại của màn hình (cây thư mục theo Template, khu vực AVAILABLE FILES, thông tin Purch
  id/Vendor code/Vendor name) tiếp tục hiển thị và hoạt động bình thường, không bị ảnh hưởng.
- Decision: Đây là điều kiện hiển thị bổ sung cho nút Upload đã có (FR-021/024/027) — không thay đổi
  bất kỳ hành vi nào khác của nút Upload khi nút đó vẫn hiển thị (vẫn tự điền Type/Value theo Update
  1/2, vẫn dùng chung popup và luồng Upload của 004-eutr-documents).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Xem danh sách EUTR Purchase Orders (Priority: P1)

Người dùng vào mục **EUTR > EUTR Purchase Orders** từ thanh điều hướng và thấy một bảng liệt kê các
purchase order lấy từ hệ thống ERP (D365) thông qua nguồn dữ liệu tham chiếu dùng chung đã có sẵn
trong hệ thống (reference type = 15 — cùng nguồn dữ liệu Purchase Order đã dùng ở 004-eutr-documents
và 011-eutr-synchronize-data). Bảng hiển thị các cột: **Purch id**, **Vendor code**, **Vendor name**,
**Template**, **Progress**, và cột **Action** với nút **View**. Cột Template hiển thị đúng template
compliance thật đang gắn với chính Purchase Order đó. Cột Progress hiển thị tiến độ tài liệu thật của
Purchase Order đó — số step bắt buộc (Required) đã có tài liệu/tổng số step bắt buộc của Template đó
và tỷ lệ %, tính bằng cách lấy danh sách step của Template (003-eutr-templates) rồi đối chiếu với tài
liệu đã ghi nhận cho Purchase Order đó (004-eutr-documents) để xác định step nào đã có tài liệu, step
nào còn thiếu (missing).

**Why this priority**: Đây là giá trị cốt lõi và duy nhất của tính năng ở giai đoạn xem danh sách —
cho phép người dùng thấy ngay tình trạng tài liệu compliance của toàn bộ purchase order mà không phải
mở từng đơn một.

**Independent Test**: Mở màn hình EUTR Purchase Orders, xác nhận bảng hiển thị đúng 6 cột (Purch id,
Vendor code, Vendor name, Template, Progress, Action); với một Purchase Order có Template gắn sẵn và
một số step Required đã có tài liệu trong khi số khác thì chưa, cột Progress hiển thị đúng số liệu
completed/total/% khớp với dữ liệu Template thật (003-eutr-templates) và tài liệu thật
(004-eutr-documents) của đúng Purchase Order đó.

**Acceptance Scenarios**:

1. **Given** đang ở thanh điều hướng, **When** chọn "EUTR Purchase Orders", **Then** thấy bảng liệt
   kê purchase order với đầy đủ 6 cột (Purch id, Vendor code, Vendor name, Template, Progress,
   Action).
2. **Given** một purchase order có Vendor code và Vendor name lấy được từ nguồn dữ liệu, **When**
   bảng hiển thị dòng đó, **Then** cột Vendor code và Vendor name hiển thị đúng giá trị thật.
3. **Given** một purchase order không có Vendor name khả dụng từ nguồn dữ liệu, **When** bảng hiển
   thị dòng đó, **Then** cột Vendor name hiển thị trạng thái trống rõ ràng, không lỗi, không chặn
   hiển thị các cột còn lại của dòng đó.
4. **Given** một purchase order đã có Template gắn sẵn, **When** bảng hiển thị dòng đó, **Then** cột
   Template hiển thị đúng tên/mã template đó.
5. **Given** một purchase order chưa có Template nào gắn, **When** bảng hiển thị dòng đó, **Then**
   cột Template hiển thị trạng thái trống rõ ràng và cột Progress hiển thị trạng thái riêng cho biết
   chưa có Template (không suy diễn thành 0%).
6. **Given** một purchase order có Template với một số step Required chưa có tài liệu, **When** bảng
   hiển thị dòng đó, **Then** cột Progress hiển thị đúng `completed`/`total`/`%` tính theo step
   Required của Template đó, đối chiếu đúng tài liệu thật đã ghi nhận cho Purchase Order đó.
7. **Given** một purchase order có Template nhưng Template đó không có step Required nào, **When**
   bảng hiển thị dòng đó, **Then** cột Progress hiển thị trạng thái riêng cho biết không có step bắt
   buộc, không suy diễn thành 0% "chưa hoàn thành".
8. **Given** một purchase order có Template và mọi step Required của Template đó đã có tài liệu,
   **When** bảng hiển thị dòng đó, **Then** cột Progress hiển thị 100% hoàn thành.
9. **Given** danh sách Purchase Orders đang hiển thị, **When** nhìn cột Action, **Then** mỗi dòng có nút
   Assign template ngay bên phải nút View (Update 13).
10. **Given** nhấn Assign template ở một dòng, **When** popup mở, **Then** thấy danh sách template
    active; template hiện tại của PO (nếu có) được chọn sẵn và đánh dấu "Current", nút OK đang vô hiệu
    (Update 13).
11. **Given** popup đang mở và đã chọn template A, **When** chọn template B, **Then** chỉ B được chọn
    (A bỏ chọn) — luôn tối đa 1 template được chọn (Update 13).
12. **Given** đã chọn 1 template, **When** nhấn OK và D365 xử lý thành công, **Then** purchId của dòng,
    templateId và versionId của template đã chọn được gửi lên D365, popup đóng, báo thành công, và cột
    Template/Progress của dòng cập nhật theo template mới (Update 13).
13. **Given** đã chọn 1 template, **When** nhấn OK nhưng D365 trả lỗi/không phản hồi, **Then** popup vẫn
    mở, hiển thị lỗi rõ ràng và dữ liệu danh sách không đổi (Update 13).
14. **Given** popup đang mở, **When** nhấn Cancel/đóng, **Then** không gửi gì lên D365 (Update 13).

---

### User Story 2 - Xem và quản lý tài liệu compliance của một Purchase Order (Priority: P1)

Từ bảng danh sách, người dùng nhấn nút **View** trên một dòng để điều hướng sang màn hình chi tiết
của đúng Purchase Order đó (`PurchId/View`). Màn hình này có bố cục và hành vi giống màn hình **Map
File** của 005-eutr-sales-orders (`eutr/sales-orders/{SalesId}/map-file`), nhưng:

- **Không có** phần "Step 1 — Choose Purchase Order" (không có bước chọn/tick Purchase Order nào cả,
  vì Purchase Order đang xem đã cố định theo `PurchId` trên URL).
- **Không có** bảng "Selected POs" (không còn khái niệm chọn nhiều PO để tổng hợp).
- Phần thông tin đầu trang (trước đây là Sales ID/Customer/Customer name) được thay bằng thông tin
  của chính Purchase Order đang xem: **Purch id**, **Vendor code**, **Vendor name**.
- Phần còn lại — cây thư mục theo step của Template đã gắn cho Purchase Order này, khu vực
  **AVAILABLE FILES** liệt kê tài liệu thật đã ghi nhận cho Purchase Order này (kèm trạng thái đã có
  tài liệu/còn thiếu cho từng step), và các thao tác **Upload** (thêm tài liệu mới) và **Edit** (sửa
  tài liệu đã có) — giữ nguyên hành vi như Step 2 của màn hình Map File, tái sử dụng đúng các popup
  Add/Edit tài liệu đã có ở 004-eutr-documents. **(Update 11)** Node Step trong cây đã có ít nhất một
  tài liệu khớp MUST hiển thị nhãn = tên file (bỏ đuôi) của tài liệu khớp đầu tiên, thay cho tên Step;
  node còn "missing" tiếp tục hiển thị đúng tên Step. Với Type = "PO" (tự điền sẵn, xem Update 1), tên
  file MUST được xác định bằng cách so khớp tên file với tên (các) Step đã gán cho Type "PO" (không
  còn qua `eutr_master_documents`) và MUST giữ nguyên tên file gốc, không đổi tên (kế thừa
  `004-eutr-documents` Update 29).

**Why this priority**: Đây là hành động chính người dùng thực hiện sau khi phát hiện một Purchase
Order còn thiếu tài liệu ở danh sách — không có giá trị nào nếu người dùng không thể mở và bổ sung
tài liệu cho đúng Purchase Order đó.

**Independent Test**: Từ danh sách, nhấn View trên một Purchase Order đã có Template; xác nhận màn
hình chi tiết mở ra hiển thị đúng thông tin Purch id/Vendor code/Vendor name ở đầu trang (không phải
Sales ID/Customer), không có phần chọn Purchase Order và không có bảng Selected POs, có cây thư mục
theo đúng step của Template đó và khu vực AVAILABLE FILES hiển thị tài liệu thật; nhấn Upload thêm
một tài liệu mới cho một step còn thiếu, xác nhận sau khi lưu thành công, khu vực AVAILABLE FILES và
trạng thái của step đó trong cây được cập nhật ngay mà không cần tải lại trang.

**Acceptance Scenarios**:

1. **Given** đang ở danh sách Purchase Orders, **When** nhấn nút View trên một dòng, **Then** hệ
   thống điều hướng sang màn hình chi tiết của đúng Purchase Order đó theo địa chỉ dạng
   `.../purchase-orders/{PurchId}/view`.
2. **Given** đã mở màn hình chi tiết của một Purchase Order tồn tại, **When** trang tải xong, **Then**
   phần đầu trang hiển thị đúng Purch id, Vendor code, Vendor name của Purchase Order đó — không hiển
   thị Sales ID/Customer.
3. **Given** đã mở màn hình chi tiết, **When** người dùng quan sát bố cục màn hình, **Then** không có
   phần "Step 1 — Choose Purchase Order" và không có bảng "Selected POs" ở bất kỳ đâu trên màn hình.
4. **Given** Purchase Order đang xem có Template gắn sẵn, **When** trang tải xong, **Then** cây thư
   mục hiển thị đúng các step của Template đó, và khu vực AVAILABLE FILES hiển thị đúng tài liệu thật
   đã ghi nhận cho Purchase Order này, mỗi tài liệu gắn đúng step tương ứng.
5. **Given** một step trong cây chưa có tài liệu nào, **When** trang tải xong, **Then** step đó hiển
   thị trạng thái "còn thiếu" (missing) rõ ràng.
6. **Given** đang ở màn hình chi tiết, **When** nhấn Upload và tải lên một tài liệu hợp lệ cho một
   step, **Then** tài liệu mới được lưu thật, khu vực AVAILABLE FILES và trạng thái step đó trong cây
   được làm mới ngay, không cần tải lại toàn bộ trang.
7. **Given** đang ở màn hình chi tiết, **When** nhấn Edit trên một tài liệu đã có, **Then** popup Edit
   tài liệu (tái sử dụng từ 004-eutr-documents) mở ra cho đúng tài liệu đó và lưu thành công sẽ cập
   nhật đúng dữ liệu thật.
8. **Given** Purchase Order được truy cập qua `PurchId` trên URL không tồn tại trong nguồn dữ liệu
   tham chiếu, **When** mở màn hình chi tiết, **Then** hệ thống hiển thị thông báo lỗi rõ ràng
   ("Purchase Order không tồn tại") và không hiển thị phần còn lại của màn hình.
9. **Given** Purchase Order đang xem chưa có Template nào gắn, **When** mở màn hình chi tiết, **Then**
   hệ thống hiển thị trạng thái rõ ràng cho biết chưa có Template (không hiển thị cây thư mục rỗng gây
   hiểu nhầm là đã đầy đủ).
10. **Given** đang ở màn hình chi tiết của một Purchase Order (`PurchId/View`), **When** nhấn nút
    **Upload**, **Then** popup Add tài liệu mở ra với trường Type đã tự điền sẵn giá trị **PO** và
    trường Value đã tự điền sẵn chính Purch Id đang xem — người dùng không cần tự chọn lại hai trường
    này để đính tài liệu cho đúng PO đang xem.
11. **Given** popup Add tài liệu đã mở với Type = PO và Value = Purch Id đang xem (đã tự điền), **When**
    người dùng đổi Type và/hoặc Value sang giá trị khác trước khi lưu, **Then** hệ thống chấp nhận giá
    trị mới do người dùng chọn (hai trường không bị khóa).
12. **Given** popup Add tài liệu đang mở tại `PurchId/View`, **When** người dùng đổi Type sang **Invoice**
    hoặc **Delivery note**, **Then** trường Value tự động điền lại thành Purch Id của Purchase Order
    đang xem.
13. **Given** popup Add tài liệu đang mở tại `PurchId/View`, **When** người dùng đổi Type sang **Vendor**,
    **Then** trường Value tự động điền lại thành Vendor Code của Purchase Order đang xem.
14. **Given** popup Add tài liệu đang mở tại `PurchId/View` với Value đã tự điền theo một Type trước đó,
    **When** người dùng tiếp tục đổi sang một Type khác trong nhóm PO/Vendor/Invoice/Delivery note,
    **Then** Value được ghi đè bằng giá trị mặc định tương ứng Type mới (không giữ lại Value cũ), và
    người dùng vẫn có thể sửa tiếp Value sau khi tự điền lại.
15. **Given** người dùng hiện tại KHÔNG có quyền thực hiện hành động tạo tài liệu mới (Upload/Add, dùng
    chung với 004-eutr-documents), **When** mở màn hình chi tiết `PurchId/View`, **Then** nút Upload
    KHÔNG hiển thị trên màn hình (không phải ở trạng thái disable); các phần còn lại của màn hình (cây
    thư mục, AVAILABLE FILES, nút Edit — nếu user có quyền `EutrDocuments.Update` theo kịch bản 17/18)
    vẫn hiển thị và hoạt động bình thường.
16. **Given** người dùng hiện tại CÓ quyền thực hiện hành động tạo tài liệu mới, **When** mở màn hình
    chi tiết `PurchId/View`, **Then** nút Upload hiển thị bình thường như các Update trước đó đã mô tả.
17. **Given** `permissionList` của menu `eutr-documents` KHÔNG chứa `'Update'` (Update 5), **When** xem
    AVAILABLE FILES ở màn hình chi tiết `PurchId/View`, **Then** nút Edit trên MỌI dòng tài liệu đều
    KHÔNG hiển thị (không phải disable) — nút Upload (nếu `permissionList` có `'Create'`) và toàn bộ
    phần còn lại của màn hình không bị ảnh hưởng.
18. **Given** `permissionList` của menu `eutr-documents` chứa `'Update'` (Update 5), **When** xem
    AVAILABLE FILES, **Then** nút Edit hiển thị trên mọi dòng và hoạt động đúng như hành vi đã có trước
    Update 5.
19. **Given** người dùng hiện tại có quyền `EutrDocuments.Update` nhưng không có quyền
    `EutrDocuments.Create` (hoặc ngược lại), **When** mở màn hình chi tiết, **Then** đúng một trong hai
    nút Upload/Edit hiển thị theo đúng quyền tương ứng của nó, nút còn lại bị ẩn — không có trường hợp
    ẩn cả hai chỉ vì thiếu một quyền.
20. **(Update 11, FR-040)** **Given** Step "1.Invoice" trong cây template của Purchase Order đang có 1
    tài liệu khớp với `eutr_documents.Name` = `"1.Invoice AP-PD.pdf"`, **When** xem cây thư mục,
    **Then** node của Step đó hiển thị nhãn = `"1.Invoice AP-PD"` (bỏ đuôi `.pdf`) thay cho
    `"1.Invoice"`; upload file tên `baocao.pdf` (không chứa tên Step nào đã gán cho Type "PO") với
    Type = "PO" MUST bị loại kèm lỗi "không tìm được step tương ứng" (kế thừa
    `004-eutr-documents` FR-076).
21. **(Update 11, FR-041)** **Given** một document Type = "PO" đã ghi nhận cho Purchase Order này, tạo
    MỚI sau `004-eutr-documents` Update 29 (File name = tên file gốc, không bị đổi tên), **When** nhấn
    nút Download (dòng AVAILABLE FILES hoặc trong popup View), **Then** tên file tải về **đúng bằng**
    `eutr_documents.Name` đã lưu — KHÔNG còn tính lại thành Step Name.

---

### User Story 3 - Tìm kiếm Purchase Order theo Purch Id hoặc Vendor (Priority: P2)

Người dùng dùng ô tìm kiếm ở màn hình danh sách để lọc nhanh theo **Purch id**, **Vendor code**, hoặc
**Vendor name**, theo kiểu khớp "chứa" (không phân biệt hoa/thường) — theo đúng mẫu tìm kiếm tham
chiếu đã có trong các màn hình danh sách EUTR khác.

**Why this priority**: Hữu ích khi danh sách có số lượng lớn (dữ liệu Purchase Order thực tế có thể
lên tới hàng nghìn dòng), nhưng không phải điều kiện tiên quyết để tính năng có giá trị — người dùng
vẫn có thể phân trang thủ công để tìm nếu chưa có tìm kiếm.

**Independent Test**: Nhập một Purch Id hoặc một phần Vendor code/Vendor name đã biết vào ô tìm kiếm,
xác nhận danh sách kết quả chỉ còn các dòng khớp từ khóa đó.

**Acceptance Scenarios**:

1. **Given** đang ở danh sách Purchase Orders, **When** nhập một Purch Id hợp lệ vào ô tìm kiếm,
   **Then** danh sách chỉ hiển thị đúng Purchase Order khớp Purch Id đó.
2. **Given** đang ở danh sách Purchase Orders, **When** nhập một phần Vendor code hoặc Vendor name
   vào ô tìm kiếm, **Then** danh sách hiển thị mọi Purchase Order có Vendor code/Vendor name chứa từ
   khóa đó.
3. **Given** từ khóa tìm kiếm không khớp Purchase Order nào, **When** kết quả trả về rỗng, **Then**
   hệ thống hiển thị trạng thái trống ("No data"), không phải lỗi.
4. **(Update 10, FR-039)** **Given** đã nhập một từ khóa vào ô tìm kiếm, **When** nhấn nút **Search**
   ngay (không đợi 500ms debounce), **Then** danh sách được lọc lại ngay lập tức theo đúng từ khóa
   đang nhập, về lại trang đầu — không cần chờ.

### Edge Cases

- Khi tổng số Purchase Order vượt quá một trang, người dùng MUST có thể chuyển trang.
- Khi nguồn dữ liệu tham chiếu type = 15 tạm thời không phản hồi (lỗi mạng/ERP), danh sách MUST hiển
  thị thông báo lỗi rõ ràng, không làm trắng trang hay crash.
- Khi một Purchase Order có Template nhưng mã Template đó không khớp với template nào đang cấu hình
  trong hệ thống, Purchase Order đó được xử lý như trường hợp chưa có Template hợp lệ (Progress hiển
  thị trạng thái chưa có Template, không tính toán step).
- (Update 10) Người dùng gõ từ khóa mới rồi nhấn Search ngay trước khi debounce 500ms của lần gõ
  trước kịp kích hoạt: nút Search gọi API ngay với từ khóa hiện tại; lượt debounce đang chờ (nếu có)
  vẫn có thể kích hoạt thêm sau đó — cùng một hành vi đã có ở `005-eutr-sales-orders` (nút Search không
  hủy lượt debounce đang chờ). Vì cả hai lượt đều dùng cùng giá trị ô tìm kiếm tại thời điểm đó, kết
  quả hiển thị không bị sai lệch — chỉ là có thể có 1 lượt gọi API dư (không gây lỗi/nhấp nháy dữ liệu
  sai).
- Khi việc tải danh sách step của Template hoặc tài liệu của Purchase Order (để tính Progress) bị lỗi
  cho một dòng cụ thể, dòng đó hiển thị trạng thái lỗi riêng cho cột Progress, không chặn các dòng
  khác trong bảng hiển thị bình thường.
- Khi màn hình chi tiết (`PurchId/View`) đang tải cây thư mục/tài liệu mà việc tải bị lỗi, hệ thống
  hiển thị thông báo lỗi rõ ràng thay vì cây rỗng gây hiểu nhầm.
- (Update 5, sửa lại) `permissionList` của menu `eutr-documents` rỗng/không tải được (ví dụ lỗi tạm
  thời khi lấy menu từ storage): hệ thống coi như user không có quyền Create/Update nào (mặc định ẩn cả
  Upload và Edit), theo đúng cách xử lý mặc định-an-toàn (fail-closed) đã áp dụng cho `permissionList`
  của menu `eutr-sales-orders` ở `005-eutr-sales-orders` Update 28.
- (Update 5) User không có cả hai quyền `'Create'`/`'Update'` trong `permissionList` của menu
  `eutr-documents`: màn hình `PurchId/View` chỉ còn hiển thị cây thư mục/AVAILABLE FILES ở chế độ gần
  như chỉ đọc (không còn nút Upload lẫn Edit) — không phải trạng thái lỗi.

- (Update 12) Số file rất lớn (hàng trăm): danh sách vẫn hiển thị đầy đủ trong khung cuộn cố định chiều
  cao, chân khung luôn thấy được; khi lọc theo Step chỉ còn ít file, chân khung hiển thị đúng tổng số
  file sau lọc. Danh sách rỗng giữ nguyên thông báo hiện có.
- (Update 13) Không có template active (Approved) nào: popup hiển thị trạng thái rỗng rõ ràng, OK luôn vô hiệu.
  Purchase Order đã có template: nếu template hiện tại nằm trong danh sách thì được chọn sẵn và đánh
  dấu "Current", OK vô hiệu cho tới khi chọn template khác; nếu không nằm trong danh sách (Draft/đã ẩn/đã xóa)
  thì không chọn sẵn mục nào. Nhấn OK nhiều lần liên tiếp chỉ
  gửi 1 yêu cầu. Template bị xóa/ẩn giữa lúc popup đang mở mà D365 từ chối: xử lý như lỗi (FR-046).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Hệ thống MUST hiển thị màn hình danh sách "EUTR Purchase Orders" dạng bảng với đúng 6
  cột: Purch id, Vendor code, Vendor name, Template, Progress, Action.
- **FR-002**: Dữ liệu Purch id, Vendor code, Template (nếu có) của mỗi dòng MUST lấy từ nguồn dữ liệu
  tham chiếu dùng chung đã có sẵn trong hệ thống, reference type = 15 — cùng nguồn dữ liệu Purchase
  Order đã dùng ở 004-eutr-documents (danh sách PO) và 011-eutr-synchronize-data (báo cáo thiếu tài
  liệu), không dùng dữ liệu mock.
- **FR-003**: Khi nguồn dữ liệu type = 15 không có sẵn giá trị Vendor name trực tiếp, hệ thống MUST
  tra cứu bổ sung Vendor name qua nguồn dữ liệu Vendor tương ứng (theo Vendor code), theo đúng cách
  011-eutr-synchronize-data đang tra cứu Vendor name cho báo cáo của nó; nếu vẫn không tìm thấy, cột
  Vendor name hiển thị trạng thái trống rõ ràng.
- **FR-004**: Cột Template MUST hiển thị đúng giá trị template compliance đang gắn trực tiếp trên
  chính Purchase Order đó (lấy từ nguồn type = 15); nếu Purchase Order chưa có Template, cột Template
  hiển thị trạng thái trống rõ ràng.
- **FR-005**: Cột Progress MUST tính bằng cách: (a) lấy danh sách step của Template đang gắn cho
  Purchase Order đó từ 003-eutr-templates, (b) đối chiếu với tài liệu đã ghi nhận cho Purchase Order
  đó từ 004-eutr-documents để xác định step nào đã có tài liệu, step nào còn thiếu (missing), (c) chỉ
  đếm các step Required (bắt buộc), (d) hiển thị dạng `completed`/`total` và tỷ lệ %.
- **FR-006**: Nếu Purchase Order chưa có Template, cột Progress MUST hiển thị trạng thái riêng cho
  biết chưa có Template, không suy diễn thành 0%.
- **FR-007**: Nếu Template của Purchase Order không có step Required nào, cột Progress MUST hiển thị
  trạng thái riêng cho biết không có step bắt buộc, không suy diễn thành 0% "chưa hoàn thành".
- **FR-008**: Users MUST có thể chuyển trang khi tổng số Purchase Order vượt quá một trang.
- **FR-009**: Users MUST có thể tìm kiếm/lọc danh sách theo Purch Id, Vendor code, hoặc Vendor name
  (khớp kiểu "chứa", không phân biệt hoa/thường).
- **FR-010**: Khi từ khóa tìm kiếm không khớp Purchase Order nào, hệ thống MUST hiển thị trạng thái
  trống ("No data"), không phải lỗi.
- **FR-011**: Màn hình danh sách là **read-only** trong phạm vi tính năng — KHÔNG cung cấp chức năng
  thêm mới (Create), sửa (Edit) hay xóa (Delete) Purchase Order.
- **FR-012**: Mỗi dòng trong bảng MUST có nút **View**; nhấn nút này MUST điều hướng sang màn hình
  chi tiết của đúng Purchase Order đó theo địa chỉ dạng `.../purchase-orders/{PurchId}/view`.
- **FR-013**: Màn hình chi tiết (`PurchId/View`) MUST kiểm tra Purchase Order có tồn tại hay không
  bằng cách tra cứu cùng nguồn tham chiếu type = 15 theo Purch Id trên URL.
- **FR-014**: Nếu Purch Id trên URL không tồn tại ở nguồn tham chiếu type = 15, màn hình chi tiết MUST
  hiển thị thông báo lỗi rõ ràng ("Purchase Order không tồn tại") và không hiển thị phần còn lại của
  màn hình.
- **FR-015**: Phần thông tin đầu trang của màn hình chi tiết MUST hiển thị Purch id, Vendor code,
  Vendor name của Purchase Order đang xem — thay thế hoàn toàn phần Sales ID/Customer/Customer name
  của màn hình Map File gốc (005-eutr-sales-orders).
- **FR-016**: Màn hình chi tiết MUST KHÔNG có phần "Step 1 — Choose Purchase Order" (không có bước
  chọn/tick Purchase Order) — Purchase Order đang xem đã cố định theo Purch Id trên URL.
- **FR-017**: Màn hình chi tiết MUST KHÔNG có bảng "Selected POs" (bỏ hoàn toàn khái niệm chọn nhiều
  Purchase Order để tổng hợp, vốn chỉ áp dụng cho luồng Sales Order gốc).
- **FR-018**: Màn hình chi tiết MUST hiển thị cây thư mục theo các step của Template thật đang gắn
  cho Purchase Order này, tải dữ liệu step từ 003-eutr-templates — theo đúng cách Step 2 của Map File
  (005-eutr-sales-orders) xây dựng cây thư mục theo Template.
- **FR-019**: Nếu Purchase Order chưa có Template, màn hình chi tiết MUST hiển thị trạng thái rõ ràng
  cho biết chưa có Template, không hiển thị cây thư mục rỗng gây hiểu nhầm.
- **FR-020**: Khu vực **AVAILABLE FILES** của màn hình chi tiết MUST hiển thị tài liệu thật đã ghi
  nhận cho Purchase Order này lấy từ 004-eutr-documents, mỗi tài liệu hiển thị đúng step mà nó đã
  được gắn trong cây.
- **FR-021**: Nút **Upload** ở màn hình chi tiết MUST mở đúng popup Add tài liệu đã có sẵn ở
  004-eutr-documents, áp dụng đúng toàn bộ quy tắc trường dữ liệu và luồng tải file thật đã định
  nghĩa ở đặc tả đó — theo đúng cách Upload hoạt động ở Step 2 của Map File.
- **FR-022**: Nút **Edit** trên từng tài liệu ở AVAILABLE FILES MUST mở đúng popup Edit tài liệu đã có
  sẵn ở 004-eutr-documents cho đúng tài liệu đó, áp dụng đúng toàn bộ quy tắc đã định nghĩa ở đặc tả
  đó — theo đúng cách Edit hoạt động ở Step 2 của Map File.
- **FR-023**: Sau khi Upload hoặc Edit thành công, khu vực AVAILABLE FILES và trạng thái của (các)
  step liên quan trong cây template MUST được làm mới (refetch) ngay theo dữ liệu thật mới nhất,
  không yêu cầu người dùng tải lại toàn bộ trang.
- **FR-024**: Riêng tại màn hình chi tiết (`PurchId/View`), khi nhấn nút **Upload**, popup Add tài
  liệu MUST tự điền sẵn trường **Type** = `PO` và trường **Value** = chính Purch Id đang xem (không
  mở trống như mặc định gốc của popup dùng chung ở 004-eutr-documents).
- **FR-025**: Trường Type và Value đã tự điền theo FR-024 MUST vẫn cho phép người dùng chỉnh sửa/đổi
  giá trị khác trước khi lưu — không khóa (disable) hai trường này.
- **FR-026**: Việc tự điền theo FR-024/FR-025 CHỈ áp dụng cho nút Upload ở màn hình `PurchId/View`
  của 012-eutr-purchase-orders; hành vi Upload ở màn hình Map File (005-eutr-sales-orders) MUST giữ
  nguyên như hiện tại (không tự điền Type/Value).
- **FR-027**: Trong popup Add tài liệu mở từ nút Upload ở màn hình `PurchId/View`, trường Type MUST cho
  chọn (tối thiểu) các giá trị đã có sẵn trong hệ thống: **PO**, **Vendor**, **Invoice**, **Delivery
  note** (cùng danh mục type tham chiếu dùng chung với 004-eutr-documents); mỗi khi người dùng đổi giá
  trị Type sang một trong các giá trị này, hệ thống MUST tự động điền lại trường Value như sau: (a) Type
  = PO, Invoice, hoặc Delivery note → Value = Purch Id của Purchase Order đang xem; (b) Type = Vendor →
  Value = Vendor Code của Purchase Order đang xem.
- **FR-028**: Việc tự điền lại Value theo FR-027 MUST thực hiện lại mỗi lần Type thay đổi (không chỉ ở
  lần mở popup đầu tiên), và MUST ghi đè giá trị Value hiện tại (nếu có) bằng giá trị mặc định tương ứng
  Type mới; Value sau khi tự điền lại vẫn KHÔNG bị khóa (disable) — người dùng vẫn có thể chỉnh sửa/xóa/
  đổi sang giá trị khác trước khi lưu, giữ nguyên nguyên tắc không khóa trường như FR-025. Nếu người
  dùng đổi Type sang một giá trị khác ngoài PO/Vendor/Invoice/Delivery note (ví dụ General agreement),
  hệ thống KHÔNG tự điền/ghi đè Value — giữ nguyên hành vi nhập tay hiện có của popup dùng chung.
- **FR-029**: Hành vi tự điền lại Value theo Type (FR-027/FR-028) CHỈ áp dụng cho popup Add tài liệu mở
  từ nút Upload tại màn hình `PurchId/View` của 012-eutr-purchase-orders; hành vi Upload ở màn hình Map
  File (005-eutr-sales-orders) MUST giữ nguyên như hiện tại (không tự điền lại Value khi đổi Type),
  theo đúng phạm vi đã giới hạn ở FR-026.
- **FR-030**: Nút **Upload** ở màn hình chi tiết (`PurchId/View`) MUST chỉ hiển thị khi người dùng
  hiện tại có quyền thực hiện hành động tạo tài liệu mới (Upload/Add) — cùng quyền đang kiểm soát hành
  động Upload dùng chung với 004-eutr-documents. Nếu người dùng không có quyền này, nút Upload MUST bị
  ẩn hoàn toàn khỏi màn hình, không hiển thị ở trạng thái vô hiệu hóa (disable). **Sửa lại ở Update 5**:
  cơ chế xác định "có quyền hay không" đổi từ dò qua endpoint `can-create` (như Update 4 ban đầu) sang
  đọc `permissionList.includes('Create')` của menu `eutr-documents` (xem FR-033) — kết quả yêu cầu
  không đổi, chỉ đổi cách lấy dữ liệu.
- **FR-031**: Việc ẩn nút Upload theo FR-030 MUST KHÔNG ảnh hưởng tới nút Edit hay bất kỳ phần nào
  khác của màn hình `PurchId/View` (cây thư mục theo Template, khu vực AVAILABLE FILES, thông tin
  Purch id/Vendor code/Vendor name) — các phần này tiếp tục hiển thị và hoạt động bình thường, không
  phụ thuộc vào quyền tạo tài liệu mới.
- **FR-032**: Khi nút Upload hiển thị theo FR-030 (người dùng có quyền), toàn bộ hành vi đã đặc tả cho
  nút Upload ở các Update trước đó (tự điền Type/Value — FR-024 đến FR-029) MUST giữ nguyên không đổi.
- **FR-033** (Update 5, sửa lại): `PurchaseOrderViewPage.jsx` MUST đọc `permissionList` của menu
  `eutr-documents` (qua `getMenuDataFromStorage()`, cùng cơ chế `005-eutr-sales-orders` Update 28 đã
  dùng cho menu `eutr-sales-orders`). Nút **Upload** (FR-030) chỉ hiển thị khi `permissionList` chứa
  `'Create'`; nút **Edit** trên mỗi dòng tài liệu ở AVAILABLE FILES chỉ hiển thị khi `permissionList`
  chứa `'Update'`. Nếu thiếu quyền tương ứng, nút đó MUST bị ẩn hoàn toàn, không hiển thị ở trạng thái
  vô hiệu hóa (disable).
- **FR-034** (Update 5): Quyền Create và quyền Update ở FR-033 là 2 điều kiện độc lập — nút Upload chỉ
  phụ thuộc `permissionList.includes('Create')`, nút Edit chỉ phụ thuộc `permissionList.includes('Update')`;
  một user có thể có cả hai, chỉ một, hoặc không có quyền nào trong hai quyền này.
- **FR-035** (Update 5): Việc ẩn nút Edit theo FR-033 MUST KHÔNG ảnh hưởng tới nút Upload (FR-030) hay
  bất kỳ phần nào khác của màn hình `PurchId/View` (cây thư mục theo Template, khu vực AVAILABLE FILES,
  thông tin Purch id/Vendor code/Vendor name) — các phần này tiếp tục hiển thị và hoạt động bình
  thường, không phụ thuộc vào quyền `EutrDocuments.Update`.
- **FR-036** (Update 5): Khi nút Edit hiển thị theo FR-033 (người dùng có quyền), toàn bộ hành vi đã
  đặc tả cho nút Edit ở các Update trước đó MUST giữ nguyên không đổi — Update này chỉ thêm điều kiện
  hiển thị, không đổi luồng nghiệp vụ khi nút đã hiển thị.
- **FR-037 (Update 9)**: Mỗi dòng tài liệu ở AVAILABLE FILES MUST hiển thị thêm nút **Download**, đặt
  ngay sau nút Edit — hiển thị cho mọi document có `FileId` (cùng điều kiện với nút View hiện có,
  không phụ thuộc quyền Edit ở FR-033). Nhấn nút MUST tải trực tiếp nội dung file thật qua `FileId`
  (dùng chung endpoint `get-file-by-idref` đã có), KHÔNG mở popup View.
- **FR-038 (Update 9; Type = "PO" sửa đổi ở Update 11, xem FR-041)**: Tên file khi tải về (cả nút
  Download mới ở FR-037 lẫn nút Download có sẵn
  trong popup View) MUST được tính lại tại thời điểm tải = `Name` của Step (Step đầu tiên nếu 1 file
  khớp nhiều Step) + đuôi file gốc — không đọc thẳng `eutr_documents.Name` đã lưu, áp dụng cho document
  Type khác "PO" (mọi document, kể cả document tạo trước `004-eutr-documents` Update 26); với Type =
  "PO", xem FR-041 (Update 11) — không còn tính lại. Việc này CHỈ ảnh hưởng tên file lưu
  về máy — KHÔNG ghi đè `eutr_documents.Name`, KHÔNG ảnh hưởng File name hiển thị ở màn hình này hay
  bất kỳ màn hình nào khác. Chi tiết đầy đủ (bao gồm fallback khi không có Step nào khớp) xem
  `005-eutr-sales-orders` FR-194 đến FR-197, áp dụng nguyên vẹn cho `PurchId/View`.
- **FR-039 (Update 10)**: Màn hình danh sách Purchase Orders MUST hiển thị thêm nút **Search** ngay
  bên phải ô tìm kiếm hiện có (FR-009) — nhấn nút MUST áp dụng ngay từ khóa đang nhập vào danh sách
  (về lại trang đầu), không cần đợi cơ chế tự động lọc sau debounce (500ms kể từ lần gõ cuối, hành vi
  hiện có ở FR-009) kích hoạt. Cơ chế tự động lọc sau debounce MUST tiếp tục hoạt động song song,
  không bị thay thế bởi nút Search mới.
- **FR-040 (Update 11)**: Trên cây thư mục ở `PurchId/View` (cùng cấu trúc `TreeNode` với Map File
  Step 2 của `005-eutr-sales-orders`), mỗi node Step đang có ít nhất một tài liệu khớp (không còn
  "missing") MUST hiển thị nhãn = tên file (bỏ phần mở rộng) của tài liệu khớp **đầu tiên**, thay cho
  `Name` của Step. Node Step còn "missing" MUST tiếp tục hiển thị `Name` của Step. Áp dụng nguyên vẹn
  quyết định đã chốt ở `005-eutr-sales-orders` FR-216 vào màn hình này.
- **FR-041 (Update 11)**: Với document có Type = "PO", tên file khi tải về (cả nút Download mới ở
  FR-037 lẫn nút Download có sẵn trong popup View) KHÔNG còn được tính lại theo FR-038 — MUST dùng
  đúng `eutr_documents.Name` đã lưu (từ `004-eutr-documents` Update 29 trở đi là tên file gốc đã
  upload) + đuôi file gốc, không đổi. Áp dụng nguyên vẹn quyết định đã chốt ở `005-eutr-sales-orders`
  FR-217 vào màn hình này.

- **FR-042 (Update 12)**: Khu vực AVAILABLE FILES MUST hiển thị toàn bộ file đang áp dụng (sau lọc
  theo Step nếu có) trong một danh sách cuộn, KHÔNG có thanh phân trang/chọn trang; chân khung MUST hiển
  thị tổng số file.
- **FR-043 (Update 13)**: Mỗi dòng ở cột Action của danh sách Purchase Orders MUST có nút **Assign
  template** ngay bên phải nút View.
- **FR-044 (Update 13)**: Nhấn Assign template MUST mở popup liệt kê các template **active** (chưa bị
  xóa, là phiên bản hiện hành và đã Approved — template Draft KHÔNG hiển thị); mỗi mục hiển thị tối thiểu mã (Code), tên và version. Popup MUST chỉ cho
  chọn **đúng 1** template (chọn mục khác thay cho mục đang chọn; không chọn nhiều). Template đang gắn
  trên Purchase Order (nếu có trong danh sách) MUST được chọn sẵn và đánh dấu "Current"; nút **OK** MUST
  bị vô hiệu cho tới khi đã chọn 1 template khác template hiện tại; có nút Cancel/đóng để thoát mà không gửi gì.
- **FR-045 (Update 13)**: Nhấn **OK** MUST gửi lên D365 (hành động `updateEutr` trên `RSVNPurchTables`,
  cross-company) đúng 3 giá trị chuỗi: `purchId` (Purch id của dòng), `templateId` (Code của template
  đã chọn), `versionId` (VersionId của template đã chọn). Chỉ gửi cho Purchase Order của dòng đang thao tác.
- **FR-046 (Update 13)**: Trong lúc gửi, popup MUST hiển thị trạng thái đang xử lý và chặn nhấn OK lặp.
  Thành công → đóng popup, hiển thị thông báo thành công và làm mới danh sách để cột Template/Progress
  của dòng phản ánh template mới. Thất bại → giữ popup mở, hiển thị thông báo lỗi rõ ràng, không làm
  thay đổi dữ liệu hiển thị.
- **FR-047 (Update 13)**: Nút Assign template MUST chỉ hiển thị cho người dùng có quyền **Update** của
  menu EUTR Purchase Orders (theo `permissionList` của menu, cùng cơ chế FR-033); người dùng không có
  quyền này không thấy nút, nút View không bị ảnh hưởng.

### Key Entities *(include if feature involves data)*

- **Purchase Order (ERP reference data, type = 15)**: Một đơn mua hàng lấy từ ERP qua nguồn tham
  chiếu dùng chung. Thuộc tính chính dùng ở tính năng này: Purch id, Vendor code, Template (nếu đã
  gắn).
- **Vendor (ERP reference data)**: Nhà cung cấp tương ứng với Vendor code của một Purchase Order.
  Thuộc tính chính: Vendor code, Vendor name — dùng để bổ sung Vendor name khi không có sẵn trực tiếp
  trên dữ liệu Purchase Order.
- **Compliance Template & Step (existing — 003-eutr-templates, chỉ đọc)**: Template compliance đang
  gắn cho một Purchase Order, cùng danh sách step (bắt buộc/không bắt buộc) của template đó — dùng để
  xây cây thư mục và tính Progress.
- **Recorded Compliance Document (existing — 004-eutr-documents, chỉ đọc/ghi qua popup Add/Edit)**:
  Tài liệu đã tải lên và gắn với một Purchase Order và một step cụ thể của Template — dùng để xác
  định step nào đã có tài liệu, step nào còn thiếu, và hiển thị ở khu vực AVAILABLE FILES.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Người dùng có thể xem toàn bộ danh sách Purchase Order kèm Vendor, Template, Progress
  thật ngay khi mở màn hình, không cần mở từng đơn để kiểm tra.
- **SC-002**: 100% giá trị Progress hiển thị trên danh sách khớp đúng với số step Required đã có tài
  liệu thật của Purchase Order đó tại cùng một thời điểm dữ liệu.
- **SC-003**: Người dùng có thể mở màn hình chi tiết của một Purchase Order bất kỳ trong tối đa 2 lượt
  nhấn (Search hoặc chuyển trang, rồi View).
- **SC-004**: Người dùng có thể bổ sung một tài liệu còn thiếu cho một step và thấy trạng thái step đó
  cập nhật ngay trên cùng màn hình, không cần tải lại trang.
- **SC-005**: 0% màn hình danh sách hoặc màn hình chi tiết hiển thị dữ liệu Template/Progress/tài
  liệu giả (demo/mock) sau khi tính năng hoàn thành.
- **SC-006**: 100% người dùng không có quyền tạo tài liệu mới không nhìn thấy nút Upload trên màn hình
  chi tiết Purchase Order, loại bỏ hoàn toàn khả năng họ nhấn vào một chức năng mà họ không được phép
  thực hiện.
- **SC-007** (Update 5): 100% người dùng không có quyền `EutrDocuments.Update` không nhìn thấy nút
  Edit trên bất kỳ dòng AVAILABLE FILES nào của màn hình chi tiết Purchase Order — trong khi người
  dùng có đủ quyền tiếp tục thấy và dùng được nút này đúng như hành vi trước Update 5.
- **SC-008 (Update 9; Type = "PO" sửa đổi ở Update 11, xem SC-011)**: 100% lượt nhấn nút Download mới
  ở AVAILABLE FILES (hoặc nút Download có sẵn
  trong popup View) trên document Type khác "PO" tải về đúng nội dung file thật, với tên file lưu về máy = đúng `Name` của Step
  (Step đầu tiên nếu khớp nhiều Step) + đuôi file gốc — kể cả với document tạo trước
  `004-eutr-documents` Update 26 (còn giữ tên cũ dạng Prefix + Step Name trong `eutr_documents.Name`).
- **SC-009 (Update 10)**: 100% lượt nhấn nút Search mới áp dụng ngay từ khóa đang nhập vào danh sách
  (không cần đợi 500ms debounce) — người dùng có cách chủ động "tìm ngay" bên cạnh cơ chế tự động lọc
  hiện có.
- **SC-010 (Update 11)**: 100% node Step trong cây thư mục có ít nhất một tài liệu khớp hiển thị nhãn =
  tên file (bỏ đuôi) của tài liệu khớp đầu tiên thay cho tên Step; 100% node Step còn "missing" tiếp
  tục hiển thị đúng tên Step.
- **SC-011 (Update 11)**: 100% lượt Download trên document Type = "PO" tải về file với tên đúng bằng
  `eutr_documents.Name` đã lưu (không còn tính lại thành Step Name); document Type khác "PO" tiếp tục
  theo SC-008 như hiện có.

- **SC-012 (Update 12)**: Với danh sách AVAILABLE FILES có hơn 10 file, 100% file hiển thị trong cùng
  một danh sách cuộn mà người dùng không cần chuyển trang; không còn điều khiển phân trang nào ở khu vực này.
- **SC-013 (Update 13)**: 100% dòng trong danh sách có nút Assign template cạnh nút View; sau khi chọn
  1 template và nhấn OK thành công, Purchase Order đó được cập nhật Template trên D365 và cột
  Template/Progress của dòng phản ánh template mới mà không cần tải lại trang thủ công; không có
  trường hợp nào gửi được nhiều hơn 1 template trong một lần nhấn OK.

## Assumptions

- Nguồn dữ liệu Purchase Order (reference type = 15, entity `RSVNEutrPurchOrders`) đã có sẵn trong hệ
  thống (đã dùng ở 004-eutr-documents và 011-eutr-synchronize-data) và trả về đủ Purch id, Vendor
  code, và giá trị Template gắn trực tiếp trên Purchase Order — tính năng này chỉ tiêu thụ lại nguồn
  dữ liệu đó, không cần đăng ký thêm reference type mới.
- Vendor name không có sẵn trực tiếp trên nguồn dữ liệu Purchase Order nên được tra cứu bổ sung qua
  nguồn dữ liệu Vendor theo Vendor code, theo đúng cách 011-eutr-synchronize-data đã làm cho báo cáo
  của nó.
- Khác với 005-eutr-sales-orders (nơi Template của một Sales Order phải tra qua bảng liên kết
  `eutr_purchase_attachments` vì một Sales Order có thể gắn nhiều Purchase Order/Template), mỗi
  Purchase Order ở tính năng này chỉ có đúng một Template gắn trực tiếp trên chính nó — không cần cơ
  chế chọn/lưu nhiều template như Step 1 của Map File.
- Công thức tính Progress (completed/total step Required, loại trừ các step tự động lấy từ nguồn
  D365) tái sử dụng đúng công thức đã dùng ở màn hình Map File của 005-eutr-sales-orders.
- Mặc định, danh sách hiển thị mọi Purchase Order trả về từ nguồn tham chiếu type = 15, kể cả những
  Purchase Order chưa có Template (hiển thị trạng thái trống ở cột Template/Progress) — không lọc bớt
  theo điều kiện đã có Template.
- Màn hình chi tiết (`PurchId/View`) giữ nguyên đầy đủ khả năng tương tác Upload/Edit tài liệu như
  Step 2 của Map File (không phải chế độ chỉ xem thuần túy như màn hình View riêng của
  005-eutr-sales-orders); tên gọi "View" chỉ phản ánh cách gọi hành động ở cột Action của danh sách.
- Tính năng này KHÔNG bao gồm chức năng tải xuống (Download) file zip tài liệu — nếu cần, sẽ là một
  cập nhật riêng sau này.
- Phân quyền truy cập màn hình này tuân theo đúng cơ chế phân quyền chung đã áp dụng cho các màn hình
  EUTR khác trong hệ thống, không yêu cầu quyền mới.
- "Tự điền mặc định" (FR-024) được hiểu là chỉ đặt giá trị khởi tạo ban đầu cho Type/Value khi popup
  Add mở ra từ nút Upload của `PurchId/View`, không phải khóa cứng giá trị — người dùng vẫn có toàn
  quyền đổi sang Type/Value khác trước khi lưu, giữ đúng nguyên tắc "popup đầy đủ, không giới hạn"
  mà 005-eutr-sales-orders (Decision 26) đã chọn cho chính popup dùng chung này.
- "Dòng active" nhắc tới ở yêu cầu tự điền lại Value theo Type (FR-027/028) là chính Purchase Order
  đang được xem tại màn hình `PurchId/View` (đã cố định theo `PurchId` trên URL) — màn hình này không
  có bảng nhiều dòng/nhiều Purchase Order để chọn "active" khác (khác với màn hình danh sách Overview,
  nơi mỗi dòng có nút View riêng để điều hướng sang đúng `PurchId/View` tương ứng). Vì vậy "PO của dòng
  active" và "Vendor Code của dòng active" đều quy về cùng một Purchase Order đang mở trên trang, nhất
  quán với cách FR-024 đã dùng cụm "Purch Id đang xem".
- Type = PO, Vendor, Invoice, Delivery note là các giá trị type tham chiếu đã tồn tại sẵn trong hệ
  thống (dùng chung với 004-eutr-documents); tính năng này không yêu cầu tạo mới type nào, chỉ bổ sung
  hành vi tự điền Value theo các type đã có.
- "Quyền tạo tài liệu mới" (FR-030) là quyền đã tồn tại sẵn trong hệ thống, cùng quyền đang kiểm soát
  việc gọi thành công hành động Upload/Add tài liệu dùng chung với 004-eutr-documents — tính năng này
  không tạo ra một loại quyền mới riêng cho màn hình Purchase Order, chỉ bổ sung điều kiện hiển thị
  (ẩn/hiện) nút Upload dựa trên quyền đã có đó. **Sửa lại ở Update 5**: thông tin quyền theo hành động
  cụ thể (`'Create'`/`'Update'`) hoá ra đã có sẵn trong `permissionList` của menu `eutr-documents` (xác
  nhận qua kiểm thử thực tế) — không cần xây cơ chế "lấy thông tin quyền theo hành động cụ thể" riêng
  như giả định ban đầu của Update 4.
- (Update 5, sửa lại) `EutrDocuments.Update` (FR-033) là quyền đã tồn tại sẵn ở backend, cùng policy
  đang kiểm soát việc gọi thành công `PUT /api/eutr-documents/{id}` (hành động Save của popup Edit tài
  liệu dùng chung với 004-eutr-documents) — không phải quyền mới. Giao diện xác định quyền này qua
  `permissionList` của menu `eutr-documents` (cùng cơ chế FR-033/Update 28) — không qua endpoint dò
  quyền nào; endpoint `can-update` từng được thêm trong bản đầu của Update này đã bị xoá.
- (Update 11) Việc kế thừa matching/bỏ đổi tên khi Upload cho Type = "PO" (`004-eutr-documents` Update
  29) không cần thay đổi backend riêng ở màn hình này — Upload/Edit ở `PurchId/View` gọi đúng
  popup/luồng dùng chung, không có logic đặt tên/matching độc lập.
- (Update 11) Nhãn cây theo tên file (FR-040) và bỏ đổi tên khi Download cho Type = "PO" (FR-041) áp
  dụng NGUYÊN VẸN quyết định đã chốt ở `005-eutr-sales-orders` Update 37 (FR-216/FR-217) — không phát
  sinh quyết định thiết kế riêng nào khác cho `012-eutr-purchase-orders`, vì cả hai màn hình dùng chung
  cấu trúc `TreeNode`/luồng Download.
- (Update 12) Bỏ phân trang là thay đổi thuần giao diện phía client; không thêm/đổi API, entity, DTO
  hay route. Dữ liệu AVAILABLE FILES vốn đã tải đầy đủ một lần rồi mới chia trang ở client.
- (Update 13) "Template active" được hiểu là template chưa bị xóa (IsDeleted ≠ 1) và là phiên bản hiện
  hành (IsHide ≠ 1) và đã Approved (Status = 1) của 003-eutr-templates; `templateId` gửi D365 = Code của template, `versionId` =
  VersionId của chính dòng được chọn, cả hai dạng chuỗi — khớp với cách đồng bộ template hiện có
  (011/003) đang dùng Code làm khóa với D365. Việc gán template chỉ ghi lên D365 (nguồn dữ liệu của cột
  Template), không ghi bảng cục bộ. Đã chốt ở bước clarify: chỉ template Approved mới được gán.
- (Update 13) Danh sách popup Assign template KHÔNG lọc theo Vendor của Purchase Order (đã chốt ở clarify);
  mọi template active (Approved) đều hiển thị cho mọi Purchase Order.
