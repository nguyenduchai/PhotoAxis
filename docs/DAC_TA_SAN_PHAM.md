# PhotoAxis — định hướng sản phẩm ban đầu

Ngày cập nhật: 20/09/2026.

Tên đã chốt: **PhotoAxis**. Định dạng dự án hiện hành đề xuất: **PhotoAxis Document (`.paxis`)**, một file ZIP nhúng đầy đủ dữ liệu. Các đoạn mô tả package bên dưới thuộc định hướng ban đầu, được thay thế bởi mục 12.2 của bản V1.0 draft.2.

Cập nhật ngôn ngữ ở đặc tả V1.0 draft.3: giao diện **Tiếng Việt và English**, có lựa chọn trong Cài đặt; yêu cầu tiếng Việt đã được người dùng xác nhận.

> Bản định hướng ban đầu, giữ để tham khảo. Bản chi tiết [DAC_TA_V1.0.md](DAC_TA_V1.0.md), mã 1.0-draft.3, đã được người dùng duyệt. Các lựa chọn về phối cảnh nhiều layer, lưu/undo, giới hạn và phạm vi trong bản V1.0 thay thế đề xuất ở tài liệu này. Phát hành trực tiếp được bổ sung tại [PHAT_HANH_PUBLIC.md](PHAT_HANH_PUBLIC.md).

Trạng thái: đặc tả định hướng, chưa triển khai ứng dụng. Hai yêu cầu bắt buộc từ người dùng là bổ sung Perspective Crop và clone giao diện, thiết kế Photoshop. Những lựa chọn chi tiết dưới đây là phương án triển khai đề xuất.

## 1. Định hướng đã xác nhận

- Ứng dụng chỉnh sửa ảnh rút gọn, hoàn toàn native trên macOS.
- Giao diện và cách bố trí công cụ phải bám sát Photoshop.
- Có Cắt xén phối cảnh — Perspective Crop.

Đưa Perspective Crop vào phạm vi bản đầu tiên. Dùng Photoshop desktop giao diện tối làm mẫu mặc định; chưa có phiên bản hoặc ảnh tham chiếu cụ thể do người dùng chọn. Mức độ khớp từng chi tiết sẽ được đối chiếu với mẫu giao diện cụ thể khi dựng UI.

## 2. Thiết kế workspace

| Khu vực | Thiết kế đề xuất |
| --- | --- |
| Menu macOS | File, Edit, Image, Layer, Select, Filter, View, Window, Help; chỉ hiển thị lệnh đã hỗ trợ |
| Thanh tiêu đề | Tên tài liệu, trạng thái đã chỉnh sửa, nút cửa sổ macOS |
| Options Bar | Nằm trên vùng tài liệu; thay đổi theo công cụ đang chọn |
| Tools | Thanh dọc bên trái, icon nhỏ, trạng thái chọn rõ; hỗ trợ nhóm công cụ và flyout |
| Tab tài liệu | Tên file, mức zoom, dấu thay đổi chưa lưu, thao tác đóng tab |
| Canvas | Nền xám đậm trung tính, ảnh ở trung tâm, checkerboard cho vùng trong suốt |
| Panel bên phải | Color, Properties, Layers; bổ sung History khi hệ thống lịch sử hoàn chỉnh |
| Layers | Thumbnail, tên, biểu tượng hiển thị, khóa, opacity; kéo sắp xếp layer |
| Thanh trạng thái | Zoom, kích thước tài liệu, thông tin thao tác phù hợp |

Ngôn ngữ thị giác: nền xám tối nhiều cấp độ, đường phân cách mảnh, góc vuông hoặc bo rất ít, chữ và controls gọn, mật độ thông tin tương tự Photoshop. Kích thước, khoảng cách, icon và trạng thái hover/active/disabled phải được đối chiếu với mẫu Photoshop khi triển khai.

Các panel có thể đổi kích thước và thu gọn. Dock/undock tự do và lưu nhiều workspace là phần mở rộng, chưa thuộc phạm vi ban đầu. Không thêm công cụ chỉ để trang trí: mỗi công cụ xuất hiện phải có hành vi thực tế hoặc trạng thái chưa khả dụng rõ ràng.

## 3. Perspective Crop

### Luồng thao tác

1. Chọn Perspective Crop trong nhóm Crop bằng nhấn giữ hoặc menu chuột phải.
2. Kéo tạo vùng ban đầu trên ảnh.
3. Kéo độc lập bốn góc để khớp bốn góc của mặt phẳng cần nắn, chẳng hạn tờ giấy, biển hiệu hoặc mặt tranh.
4. Hiển thị lưới phối cảnh bên trong tứ giác và làm tối vùng bên ngoài. Cho phép zoom/pan trong lúc điều chỉnh.
5. Tùy chọn tỷ lệ hoặc kích thước đầu ra trong Options Bar. Tỷ lệ đầu ra phải được xác định rõ, vì bốn góc ảnh không tự cung cấp tỷ lệ vật lý chính xác của vật thể.
6. Return hoặc nút Apply để cắt và nắn vùng đã chọn thành hình chữ nhật; Escape hoặc Cancel để hủy phiên thao tác.
7. Undo khôi phục tài liệu trước thao tác; Redo áp dụng lại đúng kết quả.

Options Bar đề xuất: Width, Height, đơn vị px, đổi chỗ Width/Height, Clear, Show Grid, Reset, Cancel, Apply. Các trường kích thước áp dụng cho ảnh kết quả, không ép tứ giác nguồn thành hình chữ nhật.

Phím tắt đề xuất: C chọn công cụ đang nhớ trong nhóm Crop; Shift+C chuyển giữa Crop và Perspective Crop; Space kéo vùng nhìn khi đang điều chỉnh. Các phím tắt công cụ phải nhường cho trường nhập liệu đang có focus.

### Phạm vi và bảo toàn dữ liệu

- Mặc định là thao tác cấp tài liệu, tương ứng cách người dùng hiểu một công cụ Crop; không tự chuyển sang chỉ tác động layer đang chọn.
- Lưu ảnh nguồn, dữ liệu layer và tham số phối cảnh trong dự án. Xuất PNG/JPEG tạo ảnh tổng hợp kết quả.
- Đề xuất lưu phép phối cảnh ở cấp tài liệu và áp dụng sau bước tổng hợp layer. Chỉnh sửa tiếp sau crop cần ánh xạ tọa độ và vùng tương tác nhất quán; phải chứng minh luồng này trước khi tuyên bố hỗ trợ tài liệu nhiều layer hoàn chỉnh.
- Mẫu kỹ thuật đầu tiên kiểm chứng trên tài liệu một ảnh; bản phát hành có layer phải kiểm chứng hiệu ứng trên toàn tài liệu, giữ khả năng mở lại và chỉnh tiếp. Không tự gộp layer làm mất dữ liệu.
- Một phiên Apply là một mục Undo/History; thao tác kéo từng góc không tạo hàng trăm mục lịch sử tài liệu.
- Khả năng mở lại khung bốn góc để sửa tiếp là phần bổ sung đề xuất, không mặc định coi đó là hành vi giống hệt Photoshop.

### Xử lý và kiểm chứng

- Dùng Core Image `CIPerspectiveCorrection` với bốn điểm nguồn; xử lý kích thước đầu ra riêng theo lựa chọn của người dùng.
- Chuẩn hóa orientation ảnh khi nhập; chuyển đúng giữa tọa độ view, zoom/pan, tọa độ tài liệu và tọa độ Core Image.
- Không chấp nhận tứ giác tự giao nhau, lõm hoặc gần suy biến. Hiển thị trạng thái khung không hợp lệ và vô hiệu hóa Apply.
- Preview và export dùng cùng định nghĩa phép biến đổi; preview có thể giảm độ phân giải, export dùng dữ liệu đầy đủ.
- Kiểm tra bằng ảnh có bốn góc đánh dấu khác nhau và lưới để phát hiện đảo góc, lật ảnh, lệch tọa độ; kiểm tra ở nhiều mức zoom/pan và ảnh có EXIF orientation.
- Kiểm tra tỷ lệ đầu ra, alpha, màu sắc, undo/redo, cancel, lưu/mở lại dự án và xuất ảnh.

## 4. Kiến trúc native đề xuất

| Thành phần | Công nghệ và trách nhiệm |
| --- | --- |
| Workspace và tương tác | AppKit làm nền tảng cho cửa sổ, menu, canvas, chuột, bàn phím và controls tùy biến sát Photoshop |
| Các panel phù hợp | SwiftUI qua hosting view khi vẫn đáp ứng thiết kế, focus và hiệu năng |
| Hiển thị | MetalKit/MTKView |
| Xử lý ảnh | Core Image; Metal riêng khi nhu cầu thực tế đòi hỏi |
| Nhập/xuất | Image I/O, quản lý orientation, color profile và metadata có chủ đích |
| Tài liệu | NSDocument và UndoManager; triển khai đầy đủ dữ liệu đọc/ghi và đăng ký undo |
| Dự án | File package chứa metadata có phiên bản, nguồn ảnh, layer, tham số chỉnh sửa và thumbnail |

Mô hình tài liệu, pipeline xử lý ảnh và giao diện phải tách rời. Bộ nhớ ảnh, cache preview và lịch sử cần có giới hạn; tránh sao chép toàn bộ ảnh cho mỗi lần kéo control.

## 5. Phạm vi bản đầu tiên đề xuất

- Workspace theo Photoshop: Tools, Options Bar, tab tài liệu, canvas và panel bên phải.
- Mở ảnh, tạo tài liệu, lưu/mở lại dự án, xuất PNG/JPEG.
- Zoom/pan; Move/Transform; Crop và Perspective Crop.
- Layer ảnh, chữ, hình cơ bản; thứ tự, hiển thị, khóa và opacity.
- Điều chỉnh sáng, tương phản và độ bão hòa cơ bản.
- Undo/redo, cảnh báo dữ liệu chưa lưu và xử lý lỗi nhập/xuất.

Vùng chọn nâng cao, mask/brush, blend mode mở rộng, tách nền, dock panel tự do và tương thích PSD nhiều lớp thuộc các mốc tiếp theo.

## 6. Mốc nghiệm thu đầu tiên

Mở ảnh chụp nghiêng một tờ giấy → chọn Perspective Crop trong nhóm Crop → chỉnh bốn góc khi đang zoom → nhập kích thước kết quả → Apply → Undo/Redo → lưu dự án → đóng/mở lại → xuất PNG. Ảnh xuất phải khớp canvas về nội dung, hướng và kích thước; dự án giữ dữ liệu nguồn.

Song song, đối chiếu workspace với mẫu Photoshop đã chọn về vị trí các vùng, tỷ lệ kích thước, mật độ controls, nhóm công cụ và trạng thái tương tác. Chưa đặt cam kết hiệu năng trước khi đo trên cấu hình Mac và tập ảnh thử xác định.

## 7. Tài liệu tham chiếu

- Adobe: [Workspace overview](https://helpx.adobe.com/photoshop/desktop/get-started/learn-the-basics/workspace-overview.html).
- Adobe: [Transform perspective while cropping](https://helpx.adobe.com/photoshop/desktop/crop-resize-transform/crop-straighten/transform-perspective-while-cropping.html).
- Apple: [Perspective correction](https://developer.apple.com/documentation/coreimage/cifilter-swift.class/perspectivecorrection()).
- Apple: [Core Image](https://developer.apple.com/documentation/coreimage).
- Apple: [NSDocument](https://developer.apple.com/documentation/appkit/nsdocument).
