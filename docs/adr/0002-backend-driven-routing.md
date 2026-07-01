# ADR 0002 — Route & quyền truy cập do backend điều khiển

- **Trạng thái**: Accepted (mô tả hiện trạng)
- **Ngày**: 2026-06-30
- **Phạm vi**: compliance-client

## Bối cảnh

Menu và quyền truy cập màn hình thay đổi theo user/role và được quản lý phía backend. Frontend
không nên hard-code danh sách route/quyền.

## Quyết định

`RouteResolver` dựng route **động từ dữ liệu backend**, không từ file menu tĩnh:

1. Lấy `userMenu` từ API (`GetMenuOfUserUseCase`), cache ở `localStorage['userMenu']`.
2. Khớp `location.pathname` với `mi.url` trong `userMenu` → tìm `code`.
3. Render `codeToComponent[code]` (map tĩnh code → component trong `RouteResolver.jsx`).
4. `RouteGuard` chặn bằng `roleProfile.canAccessMenu(code)` = `isAdmin` hoặc `allowedMenus` chứa code.

`presentation/menu-items/*.jsx` chỉ phục vụ hiển thị sidebar, **không** quyết định route.

## Hệ quả

- Thêm 1 màn hình mới cần CẢ HAI phía:
  - **Frontend**: tạo page + thêm `codeToComponent[<code>]`.
  - **Backend/dữ liệu**: seed `userMenu` (`code` + `url`) và cấp quyền `canAccessMenu(<code>)` cho role
    (kèm policy `<Resource>.<Action>`).
- Đổi `url`/`code` phải xóa cache: `localStorage.removeItem('userMenu'); location.reload()`.
- (−) Dễ nhầm "code đã viết mà trang vẫn trắng" khi quên seed menu/quyền backend → đây là nguyên nhân
  số 1 khi màn mới ra NotFound.

## Ví dụ: feature 001-eutr-steps

`code = "eutr-steps"`, `url = "/eutr/steps"`, resource quyền `EutrSteps.*`. Đã thêm
`codeToComponent["eutr-steps"]`; cần seed menu + quyền backend để hiển thị.

## Liên quan

- `compliance-client/src/app/routes/RouteResolver.jsx`, `app/routes/guards/RouteGuard.jsx`
- `domain/entities/RoleProfile.js`
