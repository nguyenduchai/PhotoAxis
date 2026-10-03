# Mẫu đối chiếu cố định P01

Bộ tham chiếu được cố định ngày **20/09/2026**, trước khi đối chiếu UI P01. SHA-256 tham chiếu lịch sử trong [manifest.json](manifest.json); ảnh Adobe chỉ giữ URL/hash ở bản public. Đặc tả **1.0-draft.3**, mục 4.1–4.3, ưu tiên hơn mockup.

- Workspace Adobe (bản lưu nội bộ không phân phối trong repo public): ảnh 1600×1033 từ [Adobe Photoshop workspace overview](https://helpx.adobe.com/photoshop/desktop/get-started/learn-the-basics/workspace-overview.html), trang ghi cập nhật **05/06/2026**, đã đọc ngày 20/09/2026. [URL ảnh gốc](https://helpx-prod.scene7.com/is/image/HelpxProd/Photoshop-workspace-with-key-interface-elements-li?$pjpeg$=&jpegSize=300&wid=1600). Dùng tham khảo vị trí Tools, Options, tabs, canvas và các bảng; đây không phải số đo của Adobe hoặc ảnh PhotoAxis. Bản quyền ảnh thuộc Adobe/chủ sở hữu tương ứng; chỉ lưu trong hồ sơ đối chiếu nội bộ. Không đưa ảnh này vào target ứng dụng, bộ cài hoặc trang quảng bá.
- [Mockup workspace draft.2](mockup-workspace-draft2.png): bản mô phỏng PhotoAxis đã tạo ở giai đoạn định nghĩa sản phẩm, sao chép nguyên ảnh từ workspace thiết kế của chính task. Dùng đối chiếu màu/mật độ/thứ tự vùng, không dùng làm bằng chứng native. Một số icon trong mockup cũ không hiển thị đầy đủ; UI P01 dùng vector native tự vẽ theo loại công cụ.

## Cách đối chiếu

Kiểm tra app AppKit ở ba kích thước cửa sổ **1440×900, 1280×800, 1100×700 pt**, cả vi/en. Đo frame bằng AppKit; ảnh native content view được lấy từ test host ở Retina 2×. Chụp trực tiếp cửa sổ Release bổ sung cho menu, Settings và tương tác. Không suy ra point từ ảnh mà công cụ đã thu nhỏ.

Bám các vùng và thông số khởi điểm: Options 36 pt, Tools 44/72 pt, tabs 28 pt, status 24 pt, bảng phải 300 pt và giới hạn 260–420 pt. Giữ font controls 11–13 pt; nhãn dài có overflow, không thu nhỏ chữ để giấu lỗi.

Sai khác dự kiến ở P01: vùng tài liệu/layer đang rỗng; chưa có thumbnail, nội dung canvas hoặc phiên crop. Title bar, checkbox, popup, ô màu và segmented control dùng giao diện native của macOS đang chạy; không giống từng pixel với Adobe hoặc HTML mockup. Đánh giá từng sai khác trong [báo cáo P01](../../bao-cao/P01.md), không tự coi đó là nghiệm thu V1.0.
