# Kiến trúc tổng thể

Monorepo gồm **2 ứng dụng độc lập**, đều theo **Clean Architecture** (phụ thuộc hướng vào trong).

```
Eutr/
├── compliance-client/   # Frontend SPA — React + Vite
└── compliance-sys-api/  # Backend API — .NET 8
```

## Backend — `compliance-sys-api`

```
ComplianceSys.Api            # Controllers, Middleware (mỏng, chỉ điều phối)
   └─▶ ComplianceSys.Application   # Services, DTOs, Interfaces, Validators, Mappings
          └─▶ ComplianceSys.Domain # Entities, Enums (lõi nghiệp vụ, không phụ thuộc ai)
ComplianceSys.Infrastructure # Repositories (Dapper), DatabaseInit — hiện thực abstraction của Application/Domain
```

- Truy cập dữ liệu: **Dapper** (SQL Server). Validation: **FluentValidation**. Map: **AutoMapper**.
- AuthN/AuthZ: `Shared.AuthN`; policy động dạng `{Resource}.{Action}` (vd `EutrSteps.ReadAll`).
- Chi tiết pattern: xem `compliance-sys-api/docs/Project-Architecture-Patterns.md`.

## Frontend — `compliance-client`

```
domain/          # entities + interfaces (repository contracts)
application/      # usecases (1 file / 1 thao tác)
infrastructure/   # api (axios) + repositories (REST impl của interface)
presentation/     # pages + components + hooks (UI)
di/repositories.js # DI container — UI chỉ lấy repo qua đây
app/routes/        # RouteResolver + guards
```

- Mẫu CRUD chuẩn để clone: **`document-type`** (trải đủ mọi tầng).
- UI: MUI + `@mui/x-data-grid` (server mode: phân trang/lọc/sắp xếp ở backend).

## Ranh giới & luồng

```
Người dùng → Presentation (page/hook)
           → Application (usecase)
           → Infrastructure (repository → api → HTTP)
           → [compliance-sys-api] Controller → Service → Repository(Dapper) → SQL Server
```

## Điểm cần nhớ (gotcha)

- **Route do backend điều khiển**: `RouteResolver` khớp `location.pathname` với `userMenu` (từ API,
  cache ở `localStorage['userMenu']`) và render `codeToComponent[code]`; `RouteGuard` chặn bằng
  `roleProfile.canAccessMenu(code)`. Menu tĩnh trong `presentation/menu-items/` **không** quyết định
  route. → xem [adr/0002-backend-driven-routing.md](../adr/0002-backend-driven-routing.md).
- Khi backend đã có API cho một feature → **tái sử dụng**, không viết lại (xem constitution).
