Chức năng: EUTR templates

#Giao diện templates

#Toolbar
- Import
- Add

#Grid
- Code
- Name
- Vendor code
- Vendor name
- Alert for
- Is default
- Version
- Created by
- Created date

Actions
- Add
- Delete

Pages: 1,2,3 .. N

#Logic hiển thị
- Code, Name, Vendor code, Alert for, Version, Is default, Created by, Created date lấy từ bảng eutr_templates
- Vendor name lấy ở cột VENDORORGANIZATIONNAME từ API VendorsV3 trên D365 theo liên hệ VENDORACCOUNTNUMBER = VendorCode

#Logic add sẽ ra 1 màn hình mới, không mở popup, Breadcrumb là EUTR system > EUTR templates > Add

#Giao diện add

#Header

#Textbox: Code, Name, Alert for
#Combobox: Vendor => hiển thị list vendor từ API VendorsV3 gồm 2 cột VendorAccountNumber, VendorOrganizationName
#CheckBox: Defaut

#Action button: Back, Add step

#Body: hiển thị cây thư mục dạng đệ quy, có thể collapse và Hide, Ví dụ bên dưới

↓ [] Forest
    - [] Dinh vị khu rung              | Required  | PO
    ↓ [] chứng minh mua bán            | Required  | Upload manual
        - [] Biên bản giao nhận gỗ     | Required  | PO
        - [] bản kê khai thác          | Required  | PO

#Logic Add step

Khi nhấn vào nút Add step, sẽ hiển thị box add step ở #Body

[Combobox: hiển thị toàn bộ Step ở 001-eutr-steps]      [ combobox:  Required | Optional ]    [combobox:   PO | Upload manual ] [Save]

nếu check chọn step [x] Forest, sẽ hiển thị 1 form bên dưới step đó, step tạo ra sẽ là con của step đã chọn, sẽ lấy Id của Forest lưu vào ParentId của step vừa tạo
Ngược lại không chọn sẽ là step gốc ParentId = 0


#Logic Back: quay lại màn hình EUTR > templates

#Footer
[Save]

#Logic nút [Save]

bảng eutr_templates: lưu Code, Name, Vendor Code, IsDefault, VersionId, AlertFor => sinh ra Id là 
bảng eutr_template_details: lấy Id của bảng eutr_templates vừa tạo lưu vào cột TemplateId, lấy stepId, ParentId, RequirementType, TakeFrom đã tạo step trên giao diện lưu vào

#API VendorsV3
Định nghĩa giống Eutr\compliance-sys-api\src\ComplianceSys.Domain\Dynamics\RSVNDataAreas.cs
Nhưng chỉ cần hiển thị 2 cột: VendorAccountNumber, VendorOrganizationName

#Database
Dựa theo file Eutr\docs\design\eutr\eutr_db.sql với 2 table chính để lưu eutr_templates, eutr_template_details
và table eutr_steps để hiển thị step để hiển thị combobox khi add step

#Enum
- RequirementType [1: Required, 0: Optional]
- TakeFrom [0: PO, 1: Upload manual]















