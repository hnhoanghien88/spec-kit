# Data Model: Merge Compliance Missing Screens by Type

Không đổi bảng, API hay migration.

## Type (state phía client)
- Giá trị: `open-orders` | `compliance`. Mặc định `open-orders` (hoặc `compliance` khi vào bằng code `compliance-missing-detail`).
- Chỉ nằm trong state của trang bọc; không lưu DB/localStorage.
- Khả dụng: `open-orders` nếu `userMenu` có code `compliance-missing`; `compliance` nếu có `compliance-missing-detail`.
