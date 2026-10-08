# Quickstart (kiểm tra thủ công)

Điều kiện: đăng nhập user có `userMenu` chứa code `compliance-missing` và/hoặc `compliance-missing-detail`; chạy `npm run dev` trong `compliance-client`.

1. Mở `/compliance-missing` → Type = Open orders, giao diện như màn cũ (SC-002, US1).
2. Đổi Type = Compliance → bảng/nút của màn detail; không còn Year/ETD Week (US2, FR-005).
3. Đặt filter ở Compliance, về Open orders rồi quay lại → filter giữ nguyên (FR-006).
4. Badge "missing" đổi theo Type (FR-011).
5. User chỉ có một code menu → chỉ một option, tự chọn (FR-008).
6. Mở `/compliance-missing-bk` → vào trang gộp với Type = Compliance (FR-010).
7. Menu tĩnh chỉ còn một mục Compliance missing (FR-009/SC-005).
8. `npx eslint` trên các file đã sửa sạch lỗi.
