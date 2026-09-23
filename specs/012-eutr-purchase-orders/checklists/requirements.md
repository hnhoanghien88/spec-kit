# Specification Quality Checklist: EUTR Purchase Orders

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-08-14
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

- References to "reference type = 15", "003-eutr-templates", "004-eutr-documents", and
  "005-eutr-sales-orders" describe existing system data sources/behaviors the user explicitly named
  as the basis for this feature (an established EUTR-suite convention, matching how prior specs in
  this codebase — e.g. 005, 011 — reference sibling features), not a new implementation choice, so
  they are treated as domain terminology rather than an implementation detail.
- All items pass; no [NEEDS CLARIFICATION] markers were needed — the user's request plus the existing
  005/003/004/011 specs provided enough grounding for reasonable defaults, documented in the spec's
  Assumptions section.

### Update 1 (2026-09-07) — Tự điền Type/Value khi Upload ở PurchId/View

- Bổ sung FR-024/FR-025/FR-026 và 2 acceptance scenario (User Story 2, #10-11) cho việc tự điền
  Type = PO, Value = Purch Id đang xem khi nhấn Upload ở màn hình chi tiết. Không cần
  [NEEDS CLARIFICATION] — "tự điền mặc định nhưng không khóa" là suy luận hợp lý duy nhất từ yêu cầu
  gốc, đã ghi lại thành assumption trong spec.
- Re-validated toàn bộ checklist: tất cả mục vẫn PASS, không phát sinh chi tiết triển khai
  (implementation detail) hay yêu cầu không kiểm chứng được.

### Update 2 (2026-09-10) — Tự điền lại Value mỗi khi đổi Type ở popup Upload (PurchId/View)

- Bổ sung FR-027/FR-028/FR-029 và 3 acceptance scenario (User Story 2, #12-14): mở rộng tự điền của
  Update 1 (chỉ áp dụng lần mở popup đầu tiên) thành tự điền lại Value mỗi khi Type đổi, theo nhóm
  PO/Invoice/Delivery note → Purch Id, và Vendor → Vendor Code; các Type khác không bị ghi đè.
- "Dòng active" được làm rõ trong Assumptions là chính Purchase Order đang xem tại `PurchId/View`
  (không có khái niệm nhiều dòng/nhiều PO để chọn trong chính màn hình này) — không cần
  [NEEDS CLARIFICATION] vì đây là suy luận duy nhất hợp lý khớp với FR-024 gốc và cấu trúc màn hình
  hiện có (đã xác nhận qua code thực tế: `PurchaseOrderViewPage.jsx` là trang chi tiết 1 PO cố định).
- Re-validated toàn bộ checklist: tất cả mục vẫn PASS, không phát sinh chi tiết triển khai hay yêu cầu
  không kiểm chứng được.

### Update 3 (2026-09-18) — Kế thừa đổi tên file theo Step/Prefix master từ 004-eutr-documents Update 25

- Ghi lại (chỉ 1 Clarifications entry, không cần FR/Key Entity/Success Criteria mới) rằng nút
  Upload/Edit ở `PurchId/View` dùng chung đúng popup Add/Edit và luồng Upload với `004-eutr-documents`
  nên tự động kế thừa hành vi đổi tên file theo Step/Prefix master (Update 25, FR-062–FR-067 của đặc
  tả đó) mà không cần thay đổi gì ở đặc tả này.
- Không cần [NEEDS CLARIFICATION] — câu hỏi duy nhất đáng cân nhắc (Type tự điền sẵn = "PO" theo
  Update 1 có làm thay đổi cách áp dụng logic đổi tên không) được trả lời trực tiếp trong Clarifications
  entry: người dùng vẫn đổi được Type trước khi Upload, nên cả hai nhánh (PO/không PO) của Update 25 đều
  áp dụng đúng như đặc tả gốc, không cần quy tắc riêng.
- Re-validated toàn bộ checklist: tất cả mục vẫn PASS, không phát sinh chi tiết triển khai hay yêu cầu
  không kiểm chứng được.

### Update 4 (2026-09-22) — Ẩn nút Upload khi user không có quyền tạo tài liệu

- Bổ sung FR-030/FR-031/FR-032 và 2 acceptance scenario (User Story 2, #15-16): nút Upload ở
  `PurchId/View` chỉ hiển thị khi người dùng có quyền tạo tài liệu mới (cùng quyền đang kiểm soát
  Upload dùng chung với 004-eutr-documents); ẩn hoàn toàn (không disable) khi không có quyền; không
  ảnh hưởng tới nút Edit hay phần còn lại của màn hình.
- 1 [NEEDS CLARIFICATION] phát sinh khi soạn thảo: yêu cầu gốc nói "quyền Update" nhưng hành động
  Upload thực chất gọi luồng tạo tài liệu (Create), không phải luồng sửa (Update, vốn là của nút
  Edit) — cần xác nhận map "quyền Update" vào quyền thật nào. Đã hỏi người dùng qua câu hỏi lựa chọn;
  người dùng chọn: dùng đúng quyền thật đang bảo vệ hành động Upload (tạo tài liệu mới, dùng chung với
  004-eutr-documents) — "Update" trong yêu cầu được hiểu theo nghĩa nghiệp vụ chung, không phải tên
  quyền kỹ thuật. Đã ghi lại thành Decision trong Clarifications và FR-030.
- Assumptions bổ sung: giao diện hiện chưa có cơ chế lấy quyền theo từng hành động cụ thể (chỉ có
  quyền theo menu) — việc bổ sung cơ chế này để phục vụ FR-030 nằm trong phạm vi cập nhật này.
- Re-validated toàn bộ checklist: tất cả mục vẫn PASS sau khi giải quyết clarification, không phát
  sinh chi tiết triển khai hay yêu cầu không kiểm chứng được.
