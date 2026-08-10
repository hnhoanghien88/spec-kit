# Quickstart: Compliance Master Hierarchies

## Chuẩn bị

1. Áp dụng migration `compliance-sys-api/src/ComplianceSys.Infrastructure/Sqls/Migration/16_create_compl_master_hierarchies.sql`
   lên database dev (tạo bảng `compl_master_hierarchies`).
2. Đảm bảo `compl_masters` đã có ít nhất 3-4 bản ghi (dùng màn `compliance-master` hiện có để tạo
   nếu cần) — cần đa dạng Code để test root/child/reject.
3. Chạy backend (`dotnet run` trong `ComplianceSys.Api`) và frontend (`npm run dev` trong
   `compliance-client`), đăng nhập một tài khoản có quyền `ComplianceMaster.ReadAll` (xem
   research.md mục 4 — không cần quyền nào khác cho feature này).

## Kịch bản xác thực (khớp User Stories trong spec.md)

### 1. Add root (User Story 1)

- Vào `compliance-master` (danh sách), bấm nút mở màn hình hierarchy (route
  `/compliance-master/hierarchies`).
- Bấm **Add root** → popup mở, hiển thị 50 master/trang (Code/Name/Description/View condition).
- Check 2 master ở trang 1, sang trang 2 check thêm 1 master, bấm **Add**.
- **Kỳ vọng**: cả 3 master xuất hiện làm root, đúng thứ tự đã chọn, `DisplayOrder` 0/1/2 (hoặc tiếp
  nối nếu đã có root trước đó).
- Thử **Add root** lại với 1 master đã là root → popup vẫn cho check, nhưng sau khi bấm Add, hệ
  thống báo lỗi rõ ràng cho đúng mã đó, không thêm trùng (FR-011/SC-002).

### 1b. Search theo Code/Name trong popup (FR-025-027)

- Mở popup **Add root** (hoặc Add child), gõ 1 phần Code hoặc Name của 1 master đã biết vào ô search
  → **Kỳ vọng**: danh sách tự tải lại, chỉ còn các master khớp Code HOẶC Name, phân trang quay về
  trang 1 (FR-025/SC-008).
- Gõ 1 giá trị search không khớp bất kỳ master nào → **Kỳ vọng**: popup hiện empty state, không phải
  bảng trống.
- Check 1-2 master trong kết quả đã lọc, xoá hết ô search → **Kỳ vọng**: danh sách đầy đủ (không lọc)
  hiện lại từ trang 1, các master đã check trước đó vẫn giữ trạng thái checked dù không còn hiển thị
  trên trang hiện tại (kiểm tra bằng cách search lại đúng mã đó, hoặc bấm Add và xác nhận nó có trong
  kết quả) (FR-026/FR-027).

### 2. Add child + chặn vòng lặp (User Story 2)

- Chọn (click) 1 node root trên cây → **Add child** bật lên (không disabled nữa).
- Chọn 1-2 master trong popup, bấm **Add** → các master xuất hiện lồng dưới node cha đã chọn,
  `DisplayOrder` bắt đầu từ 0 trong nhóm con này.
- Chọn tiếp 1 trong các con vừa thêm, bấm **Add child**, cố tình check lại chính master cha (hoặc
  ông/bà — tổ tiên xa hơn) → sau khi bấm Add, hệ thống từ chối kèm thông báo vòng lặp (FR-012).
- Cố tình check lại 1 master đã là con trực tiếp của node cha đang chọn → bị từ chối trùng sibling
  (FR-013).

### 3. Reorder & Delete (User Story 3)

- Chọn 1 node có ít nhất 1 anh/em, bấm mũi tên lên/xuống → thứ tự trên cây đổi ngay, không cần tải
  lại trang (SC-004).
- Chọn node đầu/cuối trong nhóm anh em, bấm mũi tên hướng ra ngoài → không có gì thay đổi (no-op).
- Chọn 1 node có con, bấm xoá → hộp thoại xác nhận hiện đúng số lượng descendant sẽ bị xoá cùng →
  xác nhận → node + toàn bộ descendant biến mất khỏi cây (SC-005).
- Bấm **expand all**/**collapse all** → toàn bộ cây mở/đóng đồng loạt.

### 4. View condition (User Story 4)

- Mở popup Add root/Add child, bấm **View condition** trên 1 dòng bất kỳ → dialog `ConditionsView`
  hiện điều kiện (đọc-only) của master đó, không đóng popup, không mất các checkbox đã chọn hay
  trang hiện tại.

### 5. Kéo-thả (User Story 5) — CHỈ sắp xếp trong cùng cấp, không reparent

- Kéo 1 node có ít nhất 1 anh/em tới 1 vị trí khác trong cùng nhóm anh em (không phải liền kề, ví dụ
  từ vị trí đầu xuống cuối) rồi thả → **Kỳ vọng**: cây cập nhật ngay thứ tự mới, không cần tải lại
  trang, không mở popup nào (SC-007).
- Kéo 1 node và thả lên 1 node KHÔNG cùng `ParentCode` (khác nhánh) → **Kỳ vọng**: không có gì xảy
  ra, cây giữ nguyên hoàn toàn (FR-023 — kéo-thả không hỗ trợ đổi cha/lên root; dùng Add child/Add
  root + Delete nếu cần di chuyển node sang nhánh khác).
- Bắt đầu kéo 1 node rồi thả ra ngoài mọi vùng thả hợp lệ (ví dụ ra ngoài khung cây) → **Kỳ vọng**:
  thao tác kéo bị huỷ, cây không đổi gì.

### 6. View condition trực tiếp trên dòng cây (User Story 6)

- Trên cây (không mở popup Add root/Add child), bấm **View condition** ngay trên 1 dòng bất kỳ đã có
  sẵn trong cây → **Kỳ vọng**: dialog `ConditionsView` hiện điều kiện (đọc-only) của đúng master đó,
  không cần chọn (select) node trước, không mở popup nào khác (FR-028/FR-029/SC-009).
- Đóng dialog vừa mở → **Kỳ vọng**: trạng thái expand/collapse của cây và node đang được chọn
  (`selectedId`, nếu có) giữ nguyên như trước khi mở (FR-029).
- Bấm **View condition** trên 1 dòng khác trong khi dialog đang mở cho dòng trước → **Kỳ vọng**: nội
  dung dialog cập nhật sang điều kiện của dòng mới bấm, vẫn chỉ 1 dialog hiển thị tại một thời điểm.
- Bấm **View condition** trên 1 node đang là node được chọn (highlight) sẵn → **Kỳ vọng**: node vẫn
  giữ trạng thái được chọn sau khi đóng dialog (click vào icon không đổi/xoá lựa chọn hiện tại).

## Kiểm thử thủ công tối thiểu (không có test tự động cho các trang CRUD tương tự trong repo)

- `dotnet build` (backend) không lỗi.
- `npm run build`/`eslint` (frontend) không lỗi.
- Gọi trực tiếp `POST api/compl-master-hierarchies/roots` với 1 mã hợp lệ qua REST client/DevTools
  Network tab, xác nhận response khớp `contracts/compl-master-hierarchies-api.md`.
