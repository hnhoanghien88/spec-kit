# Quy ước Database

Suy ra từ code hiện hữu (`ComplianceSys.Domain.Entities`). Áp dụng cho bảng/entity mới.

## Đặt tên

- **Tên bảng**: `snake_case`, số nhiều, qua `[Table("...")]` trên entity. Vd: `eutr_steps`.
- **Khóa chính**: cột `Id` (kiểu `long`/bigint), khai báo `[Key]` + `[Column("Id")]`.
- **Tên cột**: PascalCase phía entity C# (ánh xạ qua Dapper); dùng `[Column("...")]` khi tên DB khác.

## Trường audit (bắt buộc cho entity nghiệp vụ)

Kế thừa `BaseEntity` để có sẵn 4 trường, **không** đưa vào lịch sử thay đổi (`[IgnoreHistory]`):

```csharp
public abstract class BaseEntity {
    [IgnoreHistory] public DateTime CreatedDate { get; set; }
    [IgnoreHistory] public string? CreatedBy { get; set; }
    [IgnoreHistory] public DateTime UpdatedDate { get; set; }
    [IgnoreHistory] public string? UpdatedBy { get; set; }
}
```

- `CreatedBy`/`UpdatedBy`: ghi tự động từ user đăng nhập (lấy `HttpContext.Items["UserEmail"]`),
  **không** cho client gửi tay.
- `CreatedDate`/`UpdatedDate`: hệ thống set, không nhận từ client.

## Truy cập dữ liệu

- **Dapper** (không EF). SQL nằm ở tầng `Infrastructure/Repositories` (và `Infrastructure/Sqls`).
- Phân trang/lọc/sắp xếp **server-side**: endpoint `POST .../get-all` nhận
  `page/pageSize/sortColumn/sortOrder` + danh sách `FilterRequest` (`like/between/in/>=/…`).

## Validation

- Dùng **FluentValidation** (`BaseValidator<T>`) ở tầng Application. Vd `Name` bắt buộc:
  `RuleFor(x => x.Name).NotEmpty();`. UI phải chặn tương ứng để khớp backend.

## Mapping

- **AutoMapper** Profile ở `Application/Mappings`. Khi map Request→Entity: `Ignore()` `Id` và
  `IgnoreAuditable()` để không cho ghi đè khóa/trường audit.
