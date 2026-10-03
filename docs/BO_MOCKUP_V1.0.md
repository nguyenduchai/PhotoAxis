# PhotoAxis — Bộ mockup giao diện V1.0

**Ngày:** 20/09/2026 · **Tham chiếu hiện hành:** [đặc tả 1.0-draft.3](DAC_TA_V1.0.md). Mockup đã dựng theo draft.2.

Tên **PhotoAxis** và đặc tả **1.0-draft.3 đã được người dùng chốt**. Bộ mockup là tài liệu tham chiếu thiết kế và luồng sử dụng; các chi tiết chưa thể hiện, đặc biệt giao diện tiếng Việt, phải bám đặc tả khi triển khai. Không coi mọi giới hạn mô phỏng hoặc ký hiệu logo tạm là yêu cầu của ứng dụng thật.

## Hướng thiết kế

- Workspace tối theo Photoshop desktop: menu macOS, thanh tùy chọn phía trên, Tools bên trái, tab tài liệu, canvas với thước, Properties/History và Layers bên phải.
- Controls gọn, panel sát nhau, tông xám trung tính; màu xanh dành cho lựa chọn và điểm điều khiển.
- Mockup hiện tại có tên lệnh bằng tiếng Anh và ví dụ nội dung tiếng Việt đầy đủ dấu. Đặc tả draft.3 yêu cầu giao diện Tiếng Việt và English; bộ mockup cần bổ sung bản tiếng Việt và màn hình Cài đặt ngôn ngữ ở lần cập nhật thiết kế tiếp theo. Các phần này chưa được dựng trong bản xem trước hiện tại.
- Tên sản phẩm **PhotoAxis**; dự án **PhotoAxis Document (`.paxis`)**; xuất ảnh PNG/JPEG.
- Chữ `Pa` là ký hiệu tạm để thể hiện vị trí biểu tượng ứng dụng, chưa phải logo đã chốt.
- Thanh chọn “Màn hình” nằm ngoài cửa sổ ứng dụng, chỉ dùng duyệt mockup; không thuộc UI sản phẩm.
- Khung xem nhỏ tự sắp xếp lại để đọc được trong cuộc trò chuyện. Ứng dụng macOS thật tuân theo kích thước cửa sổ tối thiểu trong đặc tả, không phải ứng dụng mobile.

## Danh mục 17 màn hình

| Mã | Màn hình | Nội dung cần duyệt | Chức năng liên quan |
| --- | --- | --- | --- |
| UI01 | Welcome / Recent documents | Nhận diện PhotoAxis, tạo/mở tài liệu, danh sách gần đây | F02, F03 |
| UI02 | Workspace | Bố cục tổng thể, tab, Tools, rulers, Properties, Layers, màu | F01, F03–F05 |
| UI03 | Perspective Crop | Bốn góc độc lập, grid, kích thước đầu ra, Preview, Apply/Cancel | F08 |
| UI04 | Perspective Crop result | Hình đã nắn, kích thước mới, Layers và History còn trong workspace | F08, F12 |
| UI05 | Typography | Chữ tiếng Việt, font, cỡ, màu, nội dung và vị trí | F09 |
| UI06 | Adjustments | Exposure, Brightness, Contrast, Saturation, Enable/Reset | F11 |
| UI07 | New Document | Preset, tên, Width/Height, resolution, nền | F02 |
| UI08 | Image Size | Kích thước pixel, resolution, giữ tỷ lệ | F07 |
| UI09 | Save As | PhotoAxis Document, tên `.paxis`, vị trí và thông tin layer/nguồn nhúng | F13 |
| UI10 | Export As | Preview, PNG/JPEG, kích thước, transparency, quality, màu nền JPEG | F14 |
| UI11 | Document Recovery | Danh sách tài liệu phục hồi, thời điểm, Open Recovered/Discard | F13 |
| UI12 | Unsaved Changes | Save, Don't Save, Cancel | F03, F13 |
| UI13 | Free Transform | Khung điều khiển, vị trí, tỷ lệ, góc xoay, Apply/Cancel | F06 |
| UI14 | Crop | Khung chữ nhật, kích thước/tỷ lệ, grid, Preview/Apply | F07 |
| UI15 | Shape | Rectangle, Fill/Stroke, Properties của layer hình | F10 |
| UI16 | Canvas Size | Kích thước canvas, anchor và vùng mở rộng trong suốt | F07 |
| UI17 | Save Error | Lỗi thiếu dung lượng, bảo toàn bản lưu cũ, chọn Save As | F13, F15 |

## Cách duyệt

1. Bắt đầu ở UI02 để đánh giá tỷ lệ canvas/panel và mật độ controls.
2. Chọn UI03, kéo bốn góc theo cạnh poster; bật/tắt Grid, chọn Preview, rồi Apply. Có thể Undo thao tác crop trong phiên mô phỏng này.
3. Mở File → Export As từ kết quả để xem cùng hình trong hộp thoại xuất; thử chuyển PNG/JPEG.
4. Chọn UI05, sửa chữ tiếng Việt tại Properties, thay font/cỡ/màu hoặc kéo vị trí chữ trên canvas.
5. Chọn UI06, kéo các slider và dùng Enable/Reset để xem khác biệt; thử chọn/ẩn layer và opacity của layer ảnh hoặc tiêu đề.
6. Duyệt các hộp thoại còn lại bằng danh sách “Màn hình”. Thử Tools một/hai cột, Hand/Zoom, Properties/History và ẩn/hiện panel.

Các tùy chọn thiết kế cho bản xem trước gồm mật độ panel Compact/Comfortable, nền canvas Graphite/Charcoal và Tools một/hai cột.

## Phạm vi tương tác của mockup

Các thao tác có phản hồi trực quan gồm chuyển màn hình/menu, chọn tool/layer, ẩn layer, opacity của ảnh/tiêu đề/hình nền, kéo bốn góc, nắn phối cảnh preview, Apply/Undo crop trong phiên, sửa và di chuyển tiêu đề, chỉnh màu, pan/zoom, tạo canvas mẫu và chuyển định dạng xuất. Mô phỏng chỉ sử dụng poster mẫu được dựng cho bộ thiết kế.

Free Transform, stroke/loại shape, anchor Canvas Size, các đường dẫn lưu, khôi phục file, toàn bộ lịch sử, quản lý font và tài liệu nhiều tab hiện minh họa bố cục/luồng. Chúng chưa có đủ hành vi của ứng dụng thực tế. Nhân bản layer minh họa danh sách; preview không phải bộ compositing nhiều layer hoàn chỉnh. Image Size minh họa trường nhập và giá trị kích thước, chưa kiểm chứng resampling.

Save và Export chỉ hiện phản hồi mô phỏng, không tạo `.paxis` hoặc ảnh thật và không truy cập file cá nhân. Preview phối cảnh dùng nội dung mẫu ở độ phân giải thấp; không dùng để đánh giá chất lượng render, giữ layer, màu ICC hoặc hiệu năng của ứng dụng native.

## Quan hệ với đặc tả và nghiệm thu

Bộ mockup không thay thế yêu cầu xử lý dữ liệu và ngôn ngữ trong đặc tả. Bản triển khai vẫn dùng Swift/AppKit và pipeline đồ họa native theo phạm vi được duyệt. 43 ca trong [checklist nghiệm thu](CHECKLIST_NGHIEM_THU_V1.0.md) chưa chạy trên ứng dụng.

Các điểm cần phản hồi khi duyệt thiết kế: mức độ giống Photoshop, tỷ lệ canvas/panel, độ lớn chữ và controls, vị trí tùy chọn Perspective Crop, cấu trúc hộp thoại Save/Export. Có thể chỉ rõ mã UI01–UI17 để yêu cầu sửa một màn hình.

## Kiểm tra bản xem trước

Đã mở 17 màn hình bằng trình duyệt Chromium cục bộ và không ghi nhận lỗi JavaScript. Đã thử kéo góc làm thay đổi preview, Apply rồi mở Export giữ kích thước 1200 × 1600, và nhập chữ tiếng Việt làm cập nhật canvas. Đã xem ảnh chụp bố cục Workspace/Perspective Crop; lượt kiểm tra chiều rộng 320 px không ghi nhận tràn ngang trang. Đây là kiểm tra mockup, không phải nghiệm thu ứng dụng native hoặc xác nhận độ giống Photoshop ở cấp pixel.
