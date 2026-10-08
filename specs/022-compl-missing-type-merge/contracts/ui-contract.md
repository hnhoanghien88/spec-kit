# UI Contract

- `ComplianceMissingTypePage({ initialType })` — trang bọc; `initialType` ∈ {`open-orders`,`compliance`}.
- `ComplianceMissingPage({ typeSelector })` và `ComplianceMissingDetailPage({ typeSelector })` — `typeSelector` là ReactNode tùy chọn, render đầu header; vắng mặt thì giao diện như cũ.
- Route: code `compliance-missing` → `<ComplianceMissingTypePage initialType="open-orders" />`; code `compliance-missing-detail` → `initialType="compliance"`.
- Ô Type: label "Type", options "Open orders", "Compliance"; ẩn option không khả dụng.
- API backend: không đổi.
