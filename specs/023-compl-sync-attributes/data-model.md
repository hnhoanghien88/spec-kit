# Data Model: Compl Sync Attributes

## compl_attributes_combine (mới)

| Cột | Kiểu | Null | Nguồn |
|---|---|---|---|
| Id | bigint unsigned PK AUTO_INCREMENT | NO | tự sinh |
| ItemId | varchar(50) | NO | ItemRelation |
| UpholsteryType | bigint | NO | A1 → mã |
| UpholsteryName | bigint | NO | A2 → mã |
| UpholsteryOption | bigint | NO | A3 → mã |
| UpholsteryTypeText | varchar(100) | NO | A1 → text |
| UpholsteryNameText | varchar(100) | NO | A2 → text |
| UpholsteryOptionText | varchar(100) | NO | A3 → text |
| CreatedBy | varchar(100) | NO | "compl-sync-attributes" |
| CreatedDate | datetime | NO | UTC now |

Index: `ItemId`. Duy nhất logic: (ItemId, Type, Name, Option) — loại trùng ở tầng service.

## Quy tắc parse

`AttributeKey` → split `&` (đúng 3 phần) → mỗi phần: phần tử cuối sau `;` → split `:` lần đầu → (mã: long, text: trim ≤100).
Bỏ qua khi: ItemRelation rỗng/>50, AttributeKey rỗng, số phần ≠ 3, thiếu `:`, mã không phải số.

## Summary DTO

`Fetched`, `Added`, `Skipped`, `Success`, `Message`.

## Update 1

Không thêm bảng/cột. Chỉ **đọc** `compl_attributes_combine` (ItemId, UpholsteryType, UpholsteryName, UpholsteryOption) theo RecId. Có thể bổ sung chỉ mục `(UpholsteryType)`, `(UpholsteryName)`, `(UpholsteryOption)` nếu SC-007 không đạt (chỉ khi cần; sẽ là migration số mới).

**Request dựng từ combine** (`ViewCompliancesRequest`): `Product=ItemId` | `Attribute=Type|Name|Option` (mỗi request một trường, khử trùng). **Response**: `ViewCompliancesResponseDto` (không đổi).
