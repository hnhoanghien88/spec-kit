# Implementation Plan: Merge Compliance Missing Screens by Type

**Branch**: n/a (no git branch) | **Date**: 2026-10-08 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/022-compl-missing-type-merge/spec.md`

## Summary

Chỉ làm ở client. Thêm 1 trang bọc mới `compliance-missing-type` chứa ô **Type** (Open orders | Compliance) và render lại hai trang hiện có (`compliance-missing`, `compliance-missing-detail`) mà không đổi logic. Hai trang chỉ nhận thêm prop tùy chọn `typeSelector` để chèn ô Type vào đầu header (trước tiêu đề). Hai code menu cùng trỏ vào trang bọc (code `compliance-missing` → mặc định Open orders, code `compliance-missing-detail`/link `/compliance-missing-bk` → mở sẵn Compliance). Backend, API, DB không đổi.

## Technical Context

**Language/Version**: JavaScript (React 18, Vite), MUI

**Primary Dependencies**: MUI TextField/MenuItem, MUI X DataGrid (đã dùng ở hai trang)

**Storage**: N/A (không lưu Type; grid preference của từng trang giữ nguyên key riêng)

**Testing**: eslint + kiểm tra thủ công theo [quickstart.md](quickstart.md) (repo client không có test tự động cho màn hình)

**Target Platform**: Web (SPA)

**Project Type**: web-application (chỉ `compliance-client`)

**Performance Goals**: Đổi Type tức thì với Type đã mở; lần đầu bằng thời gian tải của màn hình đó

**Constraints**: Không sửa logic hai trang cũ (chỉ thêm prop `typeSelector`); route theo code menu từ backend (`userMenu`)

**Scale/Scope**: 1 trang bọc mới, 1 component chọn Type, sửa nhỏ 2 trang + RouteResolver + menu tĩnh

## Constitution Check

| Nguyên tắc | Kết quả | Ghi chú |
|---|---|---|
| I. Layered Clean Architecture | PASS | Chỉ thêm presentation; không đụng domain/infrastructure |
| II. Reference-Pattern Reuse | PASS | Tái dùng nguyên hai trang hiện có |
| IV. Vietnamese comments | PASS | Comment code tiếng Việt, nhãn UI tiếng Anh theo spec |

Re-check sau thiết kế: vẫn PASS, không có vi phạm.

## Project Structure

```text
specs/022-compl-missing-type-merge/
├── plan.md  research.md  data-model.md  quickstart.md  tasks.md
└── contracts/ui-contract.md

compliance-client/src/
├── app/routes/RouteResolver.jsx                    # [sửa] 2 code → trang bọc
├── presentation/menu-items/ComplianceSystem.jsx    # [sửa] bỏ mục detail
└── presentation/pages/
    ├── compliance-missing-type/index.jsx           # [mới] trang bọc + ô Type
    ├── compliance-missing/index.jsx                # [sửa nhỏ] prop typeSelector
    └── compliance-missing-detail/index.jsx         # [sửa nhỏ] prop typeSelector
```

**Structure Decision**: Chỉ frontend, theo layout hiện có của `presentation/pages`.
