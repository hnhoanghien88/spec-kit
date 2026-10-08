# Research: Merge Compliance Missing Screens by Type

## R1 — Cách gộp
- **Decision**: Trang bọc render hai trang cũ, không copy/gộp code.
- **Rationale**: Yêu cầu "giữ nguyên logic 2 màn hình"; tránh hồi quy.
- **Alternatives**: Gộp một component lớn (rủi ro cao, ~970 dòng); dùng tab MUI (user yêu cầu dropdown Type).

## R2 — Vị trí ô Type
- **Decision**: Mỗi trang cũ nhận prop tùy chọn `typeSelector` và render nó ngay trước tiêu đề.
- **Rationale**: Ô Type phải nằm cùng hàng header, trước tiêu đề (mockup); header nằm trong từng trang.
- **Alternatives**: Đặt ô Type phía trên Card (khác mockup).

## R3 — Giữ state mỗi Type
- **Decision**: Mount trang lúc Type được chọn lần đầu và giữ mounted, ẩn bằng `display: none`.
- **Rationale**: Đáp ứng FR-006 / edge case (không tải lẫn dữ liệu, giữ filter khi quay lại).
- **Alternatives**: Remount theo `key` (mất filter khi đổi qua lại).

## R4 — Routing và quyền
- **Decision**: `compliance-missing` và `compliance-missing-detail` cùng map vào trang bọc với `initialType` khác nhau. Type khả dụng = code menu đó có trong `userMenu`; chỉ còn một thì tự chọn; mặc định Open orders.
- **Rationale**: Route do backend `userMenu` quyết định; giữ quyền hiện có, bookmark `/compliance-missing-bk` vẫn vào đúng Type.
- **Alternatives**: Thêm quyền mới (spec loại trừ).

## R5 — Menu tĩnh
- **Decision**: Xóa mục `compliance-missing-detail` khỏi `ComplianceSystem.jsx`; mục `compliance-missing` giữ `/compliance-missing`.
- **Rationale**: FR-009. Menu backend (app khác) cần đồng bộ, ngoài phạm vi repo.
