# Data Model: Compliance Missing Detail

## Bảng mới: `compl_missing_detail` (snapshot)

Cột giống `compl_so_missing` **trừ `SalesId`**, thêm khóa thay thế và mốc thời gian.

| Cột | Kiểu | Ghi chú |
|-----|------|---------|
| DetailId | bigint PK AUTO_INCREMENT | phân trang/sort ổn định |
| MasterId | bigint NOT NULL DEFAULT 0 | |
| MasterCode | varchar(50) NOT NULL DEFAULT '' | **khóa** (chuẩn hóa null→'') |
| MasterName | varchar(255) | |
| MasterValidFrom, MasterValidTo | datetime | |
| MasterNumDayAlert | int | |
| MasterDescription | varchar(500) | |
| MasterVersionNo | int | |
| Status | varchar(7) NOT NULL DEFAULT '' | giá trị lưu từ lần đánh giá; **không dùng để hiển thị** (FR-013 tính lúc đọc) |
| Id | bigint NOT NULL DEFAULT 0 | ComplianceId (giữ tên như `compl_so_missing`) |
| Code | varchar(100) NOT NULL DEFAULT '' | **khóa** |
| Name | varchar(511) NOT NULL DEFAULT '' | |
| FileId | varchar(255) NOT NULL DEFAULT '' | |
| ValidFrom, ValidTo | datetime | |
| NumDayAlert, VersionNo | int | |
| ReplacedById | bigint | |
| Description | longtext NOT NULL | |
| AlertGroupsJson, ResponsibleGroupsJson, ConditionsJson | json | |
| MappedRefTypeId | bigint unsigned | |
| MappedRefTypeCode | varchar(150) NOT NULL DEFAULT '' | **khóa** (cột "Type") |
| MappedRefTypeName | varchar(300) | cột "Product name" |
| MappedInputValue | varchar(255) NOT NULL DEFAULT '' | **khóa** (cột "Product") |
| CreatedDate | datetime NOT NULL DEFAULT CURRENT_TIMESTAMP | thời điểm snapshot ghi |

- `UNIQUE KEY ux_missing_detail_key (MasterCode, Code, MappedRefTypeCode, MappedInputValue)`.
- Vòng đời: mỗi lần trigger chạy **xóa toàn bộ rồi chèn lại** KHÔNG dùng transaction (R5); không lưu lịch sử.

## Bảng mới: `compl_missing_detail_note`

| Cột | Kiểu | Ghi chú |
|-----|------|---------|
| Id | bigint PK AUTO_INCREMENT | |
| MasterCode | varchar(50) NOT NULL DEFAULT '' | khóa |
| Code | varchar(100) NOT NULL DEFAULT '' | khóa |
| MappedRefTypeCode | varchar(150) NOT NULL DEFAULT '' | khóa |
| MappedInputValue | varchar(255) NOT NULL DEFAULT '' | khóa |
| FollowUpDate | date NULL | |
| Note | text NULL | |
| CreatedDate/CreatedBy/UpdatedDate/UpdatedBy | audit | như bảng note cũ |

- `UNIQUE (MasterCode, Code, MappedRefTypeCode, MappedInputValue)` cho `INSERT … ON DUPLICATE KEY UPDATE`; Application chuẩn hóa `null → ''` và `Trim()`.
- FollowUpDate và Note cùng rỗng = xóa ghi chú.
- Không bị ảnh hưởng khi snapshot bị thay (SC-007).

## Bảng dùng nguyên trạng

- `compl_so_missing` (có `SalesId`): vùng trung gian, ghi bởi bản copy refresh; **không đổi schema**.

## DTO đọc: `MissingDetailRowDto`

Như `SoMissingRowDto` nhưng **không có** `SalesId`, `CustAccount`, `CustName`, `Etd`, `InvoiceDate`:
`MasterId, MasterCode, MasterName, Status (tính lúc đọc), Id, Code, Name, FileId, ValidFrom, ValidTo, DaysRemaining (tính lúc đọc), ResponsibleEmails, Description, MappedRefTypeCode, MappedInputValue, MappedRefTypeName, FollowUpDate, Note`.

## Menu / quyền (`res_auth_db`)

- resources: `ComplianceMissingDetail`
- permissions: `ComplianceMissingDetail.{ViewMenu,ReadAll,Download,Update}`
- menus: code `compliance-missing-detail`, name "Compliance missing detail", url `/compliance-missing`, parent `compliance-new`.
