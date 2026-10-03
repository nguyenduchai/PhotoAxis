# PhotoAxis — Đặc tả sản phẩm phiên bản 1.0

**Bản đặc tả:** 1.0-draft.3 · **Ngày:** 20/09/2026 · **Trạng thái:** ĐÃ ĐƯỢC NGƯỜI DÙNG XÁC NHẬN LÀM CƠ SỞ TRIỂN KHAI.

Người dùng đã xác nhận: “Tôi chốt đặc tả sản phẩm 1.0-draft.3”. Giữ nguyên mã phiên bản để truy vết bản đã duyệt. Các con số về giới hạn và hiệu năng là yêu cầu/mục tiêu thiết kế đã duyệt, chưa phải kết quả đo. Tài liệu này thay thế các lựa chọn còn mở trong `DAC_TA_SAN_PHAM.md`.

Yêu cầu tiếp theo “xây dựng sản phẩm đến khi public” được bổ sung bằng [kế hoạch phát hành trực tiếp](PHAT_HANH_PUBLIC.md), không âm thầm thêm chức năng vào bản đặc tả đã duyệt. Kênh đã chọn: website/GitHub Releases.

## 1. Mục đích và yêu cầu bắt buộc

Xây dựng một ứng dụng chỉnh sửa ảnh rút gọn, hoàn toàn native trên macOS, clone giao diện và cách bố trí công cụ Photoshop trong phạm vi tính năng V1.0. Perspective Crop là tính năng bắt buộc của bản phát hành đầu tiên.

Ba công việc chính:

1. Mở ảnh, crop hoặc nắn phối cảnh, chỉnh màu và xuất ảnh.
2. Ghép nhiều ảnh, thêm chữ tiếng Việt và hình cơ bản.
3. Lưu dự án, đóng ứng dụng, mở lại và tiếp tục chỉnh sửa từng layer.

Một bản chỉ có giao diện hoặc chỉ chỉnh được ảnh đơn chưa đáp ứng V1.0.

## 2. Các lựa chọn đã duyệt

| Mã | Hạng mục | Phương án V1.0 |
| --- | --- | --- |
| D01 | Nền tảng | macOS 14 trở lên, Apple Silicon; cấu hình tối thiểu đề xuất 8 GB RAM, khuyến nghị 16 GB |
| D02 | Phong cách giao diện | Photoshop desktop giao diện tối; bố cục và hành vi được mô tả ở mục 4 |
| D03 | Ngôn ngữ | Giao diện **Tiếng Việt và English** trong V1.0; chọn Theo hệ thống/Tiếng Việt/English trong Cài đặt; tài liệu sử dụng tiếng Việt; nhập chữ tiếng Việt đầy đủ; chi tiết ở mục 4.3 |
| D04 | Hoạt động | Offline, dữ liệu trên máy, sử dụng được ngay không cần tài khoản |
| D05 | Tên và định dạng | Tên chính thức **PhotoAxis**; loại tài liệu **PhotoAxis Document**, đuôi **`.paxis`**; một file ZIP chứa đầy đủ dự án |
| D06 | Màu sắc | Quy trình SDR sRGB; xuất ảnh 8 bit/kênh; chưa có chế độ HDR, CMYK hoặc quản lý in chuyên nghiệp |
| D07 | Phạm vi clone | Clone workspace, controls và thao tác của công cụ đã hỗ trợ; không suy ra có toàn bộ chức năng Photoshop |
| D08 | Bàn giao | Mã nguồn, dự án Xcode, bản `.app` chạy trên máy đích, hướng dẫn và báo cáo nghiệm thu; phần public qua website/GitHub Releases được bổ sung riêng trong `PHAT_HANH_PUBLIC.md`; App Store chưa thuộc phạm vi |

Hỗ trợ Intel chưa nằm trong V1.0 đề xuất. Giao diện tiếng Việt và tiếng Anh đều nằm trong phạm vi V1.0. Lựa chọn nền tảng là đề xuất phạm vi của ứng dụng, không phải giới hạn bắt buộc của công nghệ Apple.

## 3. Danh sách chức năng

| Mã | Chức năng bắt buộc V1.0 | Điều kiện hoàn thành chính |
| --- | --- | --- |
| F01 | Workspace theo Photoshop, giao diện Việt/Anh | Đúng bố cục, kích thước tương đối, trạng thái, hành vi và chuyển ngôn ngữ ở mục 4 |
| F02 | Tạo/mở/nhập tài liệu | Tạo canvas; mở JPEG/PNG/HEIC; thêm ảnh vào tài liệu |
| F03 | Nhiều tài liệu | Tối đa 5 tab, trạng thái chỉnh sửa và undo độc lập |
| F04 | Canvas, Hand, Zoom | Zoom/pan chính xác; hình và điểm điều khiển không lệch |
| F05 | Layer | Ảnh, chữ, hình; chọn, đổi tên, thứ tự, ẩn, khóa, opacity, nhân bản, xóa |
| F06 | Move và Transform | Di chuyển, scale, rotate, flip, nhập giá trị, Apply/Cancel |
| F07 | Crop | Cắt chữ nhật, tỷ lệ có sẵn/tùy chỉnh, giữ dữ liệu nguồn |
| F08 | Perspective Crop | Bốn góc độc lập; nắn toàn tài liệu; giữ layer; có undo và lưu/mở lại |
| F09 | Type | Chữ nhiều dòng, font, cỡ, màu, căn lề; sửa lại được |
| F10 | Shape và màu | Rectangle/Ellipse/Line; fill/stroke; Eyedropper |
| F11 | Điều chỉnh ảnh | Exposure, Brightness, Contrast, Saturation theo layer ảnh |
| F12 | Undo/Redo và History | Một thao tác liên tục = một mục; quay lại trạng thái được |
| F13 | Lưu dự án và phục hồi | Save/Save As, dữ liệu nguồn trong dự án, bản phục hồi định kỳ |
| F14 | Export | PNG/JPEG, kích thước chính xác, alpha hoặc màu nền, sRGB |
| F15 | Ổn định và bàn giao | Kiểm tra lỗi, giới hạn tài nguyên, keyboard/focus, bộ nghiệm thu |

## 4. Đặc tả giao diện clone Photoshop

### 4.1. Mẫu tham chiếu và cách đối chiếu

Mẫu bố cục là workspace Photoshop desktop tối được minh họa trong [tài liệu workspace của Adobe](https://helpx.adobe.com/photoshop/desktop/get-started/learn-the-basics/workspace-overview.html), phiên bản trang cập nhật 05/06/2026. Đây là ngày của tài liệu tham chiếu, không phải số phiên bản Photoshop.

Vị trí Tools, Options Bar, document tabs và các panel phải bám mẫu. Các thông số dưới đây là kích thước khởi điểm do dự án đề xuất, không phải số đo của Adobe. Khi dựng UI phải đối chiếu trực quan và điều chỉnh chúng cho khớp. Bộ ảnh tham chiếu dùng đối chiếu phải được ghi nguồn và cố định trước khi nghiệm thu UI, tránh thay đổi mẫu giữa quá trình thực hiện.

| Khu vực | Bố trí và hành vi |
| --- | --- |
| Menu macOS | Menu của ứng dụng; File, Edit, Image, Layer, Type, View, Window, Help với các lệnh V1.0; bản tiếng Việt dùng Tệp, Chỉnh sửa, Ảnh, Lớp, Văn bản, Xem, Cửa sổ, Trợ giúp |
| Thanh tiêu đề | Nút cửa sổ macOS, tên tài liệu, trạng thái chưa lưu; hỗ trợ maximize/full screen |
| Options Bar | Ngay trên tài liệu, cao khởi điểm 36 pt; thay đổi theo công cụ đang chọn |
| Tools | Trái, rộng khởi điểm 44 pt một cột hoặc 72 pt hai cột; nhóm công cụ có flyout |
| Tab tài liệu | Cao khởi điểm 28 pt; tên, zoom, dấu chưa lưu, nút đóng; cuộn khi thiếu chỗ |
| Canvas | Ở giữa; nền trung tính, checkerboard, overlay công cụ; nội dung nằm dưới overlay |
| Panel phải | Rộng khởi điểm 300 pt, kéo từ 260–420 pt; Color trên, Properties/History giữa, Layers dưới |
| Status Bar | Cao khởi điểm 24 pt; zoom và kích thước ảnh |

Màu khởi điểm: canvas `#1E1E1E`, nền panel `#2B2B2B`, thanh công cụ `#323232`, control `#3C3C3C`, chữ `#D9D9D9`, đường chia `#454545`. Chữ hệ thống cỡ 11–13 pt; controls gọn, bo ít; icon công cụ vẽ đúng hình và tỷ lệ của mẫu tham chiếu.

Yêu cầu tương tác:

- Có trạng thái normal, hover, pressed, active, disabled và keyboard focus.
- Nhấn giữ hoặc chuột phải mở flyout Crop/Perspective Crop và nhóm Shape; tooltip nêu tên/phím tắt.
- Thu gọn panel phải; Tab ẩn/hiện Tools và panel khi không nhập văn bản. Window > Reset Workspace khôi phục bố cục.
- Ghi nhớ kích thước panel và cách hiển thị Tools giữa các lần mở ứng dụng.
- Chưa hỗ trợ kéo panel thành cửa sổ nổi, tùy biến workspace tự do hoặc giao diện sáng.
- Mỗi icon/menu xuất hiện phải có chức năng thật hoặc disabled vì ngữ cảnh hiện tại. Công cụ chưa phát triển được bỏ khỏi V1.0.
- Trường số hỗ trợ gõ, chọn, tăng/giảm bằng phím; không mất focus khi panel cập nhật.
- Kiểm tra ở cửa sổ 1440×900 và 1280×800 pt; kích thước cửa sổ tối thiểu đề xuất 1100×700 pt. Khi chật, Options Bar dùng overflow; Apply/Cancel luôn truy cập được.
- Controls có nhãn accessibility, focus nhận biết được và dùng bàn phím được; icon sắc nét trên màn hình Retina.

### 4.2. Công cụ có trên toolbar

Theo thứ tự tương đối: Move (V), Crop/Perspective Crop (C), Eyedropper (I), Type (T), Rectangle/Ellipse/Line (U), Hand (H), Zoom (Z), ô màu foreground/background. Những vị trí của công cụ đã hỗ trợ giữ cùng logic nhóm với Photoshop.

Không có nút Brush, Eraser, Lasso, Magic Wand, Pen, Healing hoặc AI hoạt động giả trong bản đầu tiên.

### 4.3. Ngôn ngữ giao diện

**Ngôn ngữ hỗ trợ:** Tiếng Việt (`vi`) và English (`en`). Đây là yêu cầu giao diện đầy đủ trong V1.0, bao gồm:

- Menu, tên công cụ, Options Bar, panel, tooltip, nhãn accessibility và tên thao tác trong History.
- Welcome, tạo tài liệu, Image Size/Canvas Size, Save/Export, recovery, xác nhận đóng, thông báo lỗi, tiến trình và hướng dẫn ngắn do PhotoAxis cung cấp.
- Các phần nội dung hệ thống trong hộp thoại native theo cơ chế ngôn ngữ của macOS; không tự viết lại hộp thoại hệ thống chỉ để dịch. Nội dung do PhotoAxis thêm vào phải theo ngôn ngữ đã chọn.

**Chọn và ghi nhớ ngôn ngữ:**

1. Vào **PhotoAxis → Cài đặt… → Ngôn ngữ giao diện** / **PhotoAxis → Settings… → Interface Language**; mở Cài đặt bằng `Cmd+,`.
2. Ba lựa chọn: **Theo hệ thống / System Default**, **Tiếng Việt**, **English**. Mặc định Theo hệ thống: chọn ngôn ngữ đầu tiên được hỗ trợ trong danh sách ưu tiên của macOS; dùng English nếu không có ngôn ngữ phù hợp. Nhãn “Tiếng Việt” và “English” luôn giữ cách viết này để dễ chuyển lại.
3. Ghi nhớ lựa chọn trên máy, áp dụng ở lần khởi động ứng dụng tiếp theo; hiển thị thông báo cần mở lại ứng dụng. Không tự thoát. Nếu người dùng thoát khi đang có thay đổi chưa lưu, áp dụng đầy đủ luồng Save/Don't Save/Cancel.
4. Đây là cài đặt của ứng dụng, không lưu vào `.paxis`. Đổi ngôn ngữ không dịch chữ trên canvas, tên file, tên layer do người dùng đặt hoặc làm thay đổi nội dung tài liệu.

**Quy tắc hiển thị và thuật ngữ:**

- Tiếng Việt tự nhiên, đầy đủ dấu, thống nhất thuật ngữ trong toàn bộ ứng dụng. Giữ bố cục Photoshop ở cả hai ngôn ngữ; cho controls rộng hơn hoặc đưa vào overflow khi nhãn dài, không làm mất lệnh Apply/Cancel.
- Phím tắt giữ nguyên giữa hai ngôn ngữ, kể cả V/C/T/I/U/H/Z. Tooltip hiển thị tên công cụ đã dịch và phím tắt; IME và nhập tiếng Việt tiếp tục được ưu tiên khi focus ở trường văn bản.
- Giữ nguyên tên PhotoAxis, phần mở rộng `.paxis`, PNG/JPEG/HEIC, tên font và mã profile màu. Tên lệnh tiếng Anh còn được dùng trong tài liệu kỹ thuật để đối chiếu Photoshop; giao diện tiếng Việt dùng bản dịch đã thống nhất.
- Định dạng số/ngày hiển thị theo thiết lập vùng của macOS; parse số nhất quán với cách hiển thị. Schema, định danh thao tác và dữ liệu số trong file dự án độc lập với ngôn ngữ giao diện.
- Không hiện khóa dịch hoặc placeholder kỹ thuật. Có bản tiếng Anh dự phòng khi thiếu chuỗi, nhưng bản bàn giao phải hoàn tất cả hai bộ dịch cho phạm vi V1.0.

| English | Tiếng Việt |
| --- | --- |
| Settings / Interface Language | Cài đặt / Ngôn ngữ giao diện |
| Move / Crop / Perspective Crop | Di chuyển / Cắt xén / Cắt xén phối cảnh |
| Type / Shape / Eyedropper | Văn bản / Hình dạng / Lấy mẫu màu |
| Layers / Properties / History | Lớp / Thuộc tính / Lịch sử |
| Opacity / Exposure | Độ mờ / Phơi sáng |
| Brightness / Contrast / Saturation | Độ sáng / Độ tương phản / Độ bão hòa |
| New Document / Image Size / Canvas Size | Tạo tài liệu / Kích thước ảnh / Kích thước vùng vẽ |
| Preview / Apply / Cancel | Xem trước / Áp dụng / Hủy |
| Save / Save As / Don't Save | Lưu / Lưu thành / Không lưu |
| Export As / Recover Documents | Xuất ảnh / Khôi phục tài liệu |

## 5. Tài liệu, nhập ảnh và nhiều tab

### 5.1. Tạo tài liệu

- Nhập Width/Height bằng pixel, PPI, tên và nền Transparent/White/Black. PPI chỉ là metadata in/xuất, thay PPI đơn thuần không đổi số pixel.
- Preset: 1080×1080, 1920×1080, 1080×1920, A4 2480×3508 tại 300 PPI; có đảo chiều.
- Nền trắng/đen là layer hình chữ nhật ở dưới cùng, khóa mặc định; cho phép mở khóa.
- Hộp thoại nêu lỗi ngay tại trường kích thước không hợp lệ.

### 5.2. Mở và thêm ảnh

- File > Open mở JPEG, PNG, HEIC/HEIF tĩnh hoặc `.paxis`; mỗi file mở thành tài liệu.
- Ảnh mới mở có một layer ảnh, kích thước canvas theo ảnh sau khi xử lý orientation.
- File > Place Embedded, kéo vào canvas đang mở hoặc dán ảnh từ clipboard thêm một layer trên layer đang chọn.
- Ảnh đặt vào giữ tỷ lệ, thu nhỏ vừa canvas nếu cần và căn giữa; ảnh nhỏ không tự phóng lớn. Nguồn đầy đủ được giữ trong giới hạn nhập.
- Thả ảnh vào vùng trống khi chưa có tài liệu hoặc thanh tab mở thành tài liệu mới. Thả vào canvas có tài liệu là thêm layer.
- Thêm nhiều file kiểm tra từng file; file lỗi có lý do riêng; các file đã nhập thành công không bị mất.
- Tên file Unicode, dấu tiếng Việt và khoảng trắng phải hoạt động.
- Ảnh có profile màu được chuyển đúng sang sRGB. Ảnh không profile mặc định sRGB. Nhập nội dung HDR/độ sâu cao có thông báo chuyển sang SDR sRGB; ảnh gốc ngoài ứng dụng giữ nguyên.
- Định dạng không hỗ trợ được báo rõ; V1.0 không nhập PDF, SVG, RAW, PSD hoặc nội dung động/nhiều trang.

### 5.3. Tab và đóng tài liệu

- Mỗi tab giữ layer đang chọn, zoom/pan, phiên công cụ đang sửa, lịch sử và trạng thái chưa lưu riêng.
- Khi đổi tab, phiên crop/transform được giữ ở tab cũ, không tự áp dụng.
- Đóng tài liệu đã thay đổi có Save / Don't Save / Cancel. Cancel giữ cửa sổ và dữ liệu.
- Save dự án không ghi đè ảnh JPEG/PNG/HEIC nguồn; lần Save đầu tiên của ảnh nhập yêu cầu vị trí `.paxis`.
- Nếu có phiên crop/transform chưa Apply, Save/Export/đổi công cụ/đóng tài liệu yêu cầu giải quyết Apply / Discard / Cancel trước. Discard chỉ hủy phiên công cụ hiện tại. Apply bị vô hiệu khi hình học không hợp lệ.
- Text đang nhập chốt hoặc hủy theo mục 10 trước khi xử lý lệnh cấp tài liệu.

## 6. Canvas, điều hướng và chọn layer

- Zoom 5%–1600%, Fit on Screen, 100%; zoom quanh con trỏ hoặc tâm viewport với lệnh menu.
- 100% nghĩa là một pixel ảnh khớp một pixel thiết bị; xử lý backing scale khi đổi màn hình Retina/non-Retina.
- Pinch zoom, cuộn hai ngón để pan; Space tạm dùng Hand, thả Space quay về công cụ trước.
- Chuột chọn layer trên cùng có nội dung tại điểm bấm khi Auto-Select bật; bỏ qua layer ẩn/khóa. Có thể chọn layer khóa từ Layers để mở khóa.
- V1.0 chỉ chọn/chỉnh một layer mỗi lần; chưa có vùng chọn pixel hoặc multi-select layer.
- Ô zoom trên status bar cho nhập trực tiếp; pan/zoom không làm tài liệu thành chưa lưu và không vào undo.
- Rulers bật/tắt theo pixel. Chưa có guide tùy ý hoặc Smart Guides; Move có căn giữa canvas từ Options Bar.

## 7. Layer và Transform

### 7.1. Layer

- Ba loại: image, text, shape. Layers hiển thị thumbnail, tên, loại, visibility, lock.
- Thêm/nhân bản/xóa/đổi tên/kéo đổi thứ tự; layer mới nằm trên layer đang chọn. Duplicate giữ nguồn tham chiếu dùng chung nhưng tham số chỉnh sửa độc lập.
- Opacity 0–100%, blend mode Normal. V1.0 chưa có group, clipping mask, layer mask, adjustment layer hoặc hiệu ứng layer.
- Lock bảo vệ thao tác trực tiếp lên layer: nội dung, transform, điều chỉnh, opacity, xóa và thứ tự. Vẫn được chọn, ẩn/hiện và mở khóa. Các thao tác hình học cấp tài liệu vẫn tác động cả layer khóa.
- Click layer chọn, double-click tên đổi tên; Delete xóa layer đang chọn nếu không khóa và không focus vào trường nhập.
- Ẩn/hiện, khóa, đổi tên, thứ tự và opacity đều undo được.

### 7.2. Move và Free Transform

- Move kéo đối tượng; phím mũi tên dịch 1 pixel tài liệu, Shift+mũi tên dịch 10 pixel.
- Cmd+T mở Free Transform: scale, rotate, flip ngang/dọc; Options Bar có X/Y, W/H, liên kết tỷ lệ và angle.
- Giữ tỷ lệ bật mặc định; cho tắt. Shift tạm đảo chế độ giữ tỷ lệ khi kéo. Quay có bước bắt 15° khi giữ Shift.
- Return Apply, Escape Cancel; một phiên transform là một mục undo.
- X/Y và W/H mô tả bounding box trong canvas hiện tại. Với layer đã bị nắn phối cảnh, scale/rotate/move tiếp tục tác động trong tọa độ canvas kết quả; không xóa biến dạng trước đó.
- Không có công cụ Warp, Skew hoặc kéo phối cảnh tự do riêng cho một layer trong V1.0.

## 8. Crop thông thường

- Crop tác động lên canvas và toàn bộ layer; khung cắt chữ nhật có bốn góc và bốn cạnh điều chỉnh.
- Tỷ lệ: Free, Original, 1:1, 4:3, 3:2, 16:9, A4 và Custom; đổi ngang/dọc.
- Trong chế độ Ratio, đầu ra lấy số pixel từ vùng cắt; trong chế độ W×H, resample theo kích thước nhập sau khi crop.
- Có lưới rule of thirds, vùng ngoài làm tối, Reset/Cancel/Apply. Khung nằm trong canvas; mở rộng canvas dùng Canvas Size.
- Giữ dữ liệu nguồn và layer ngoài khung; không có tùy chọn xóa pixel ngoài crop trong V1.0.
- Một Apply = một mục History. Crop mới dựa trên canvas hiện tại.
- Image Size thay kích thước canvas và scale toàn bộ layer theo tỷ lệ; Canvas Size thay vùng hiển thị bằng anchor 3×3, không scale nội dung. Có Rotate Canvas 90°/180° và Flip Canvas.

## 9. Perspective Crop — yêu cầu trọng tâm

### 9.1. Hành vi người dùng

Luồng công cụ theo [hướng dẫn Adobe](https://helpx.adobe.com/photoshop/desktop/crop-resize-transform/crop-straighten/transform-perspective-while-cropping.html): chọn trong nhóm Crop, tạo vùng, chỉnh góc và xác nhận bằng Return. Phần bảo toàn layer và lưu dữ liệu dưới đây là thiết kế của ứng dụng này.

1. Chọn Perspective Crop bằng flyout hoặc Shift+C.
2. Kéo một hình chữ nhật ban đầu; bốn đỉnh được đánh dấu rõ.
3. Kéo độc lập từng đỉnh để tạo tứ giác khớp vật thể. Đỉnh bị giới hạn trong canvas hiện tại; kéo phần giữa dịch cả tứ giác trong giới hạn.
4. Lưới bên trong phản ánh phép chiếu phối cảnh, không chỉ là lưới chữ nhật phủ lên màn hình. Overlay không đi vào ảnh xuất.
5. Zoom/pan vẫn hoạt động; tay nắm giữ kích thước hiển thị dễ chọn, không phóng to theo mức zoom.
6. Chọn chế độ kích thước đầu ra, xem Width/Height kết quả; có nút Preview để xem ảnh đã nắn và quay lại chỉnh góc.
7. Apply/Return chốt một thao tác; Cancel/Escape trả về trạng thái trước phiên, gồm cả kích thước canvas.

### 9.2. Options Bar và kích thước

| Điều khiển | Hành vi |
| --- | --- |
| Mode: Auto | Ước lượng kích thước theo độ dài các cặp cạnh đối diện, hiển thị số pixel trước khi Apply |
| Mode: Ratio | Preset hoặc tỷ lệ W:H tùy chỉnh; lấy quy mô gần kết quả Auto, ép đúng tỷ lệ |
| Mode: W×H | Nhập chính xác Width/Height nguyên theo pixel; bắt buộc đủ hai trường |
| Swap | Đảo tỷ lệ/kích thước đầu ra; không thay đổi nhận dạng bốn góc nguồn |
| Clear | Xóa ràng buộc kích thước và trở về Auto, giữ tứ giác đang chọn |
| Show Grid | Bật/tắt lưới, không thay đổi ảnh |
| Reset | Đưa khung về bốn góc canvas, giữ chế độ kích thước đang chọn |
| Preview | Bật/tắt xem kết quả nắn trước khi Apply; không tạo mục undo |
| Cancel / Apply | Hủy hoặc chốt phiên |

Auto đề xuất: chiều rộng = trung bình độ dài cạnh trên/dưới; chiều cao = trung bình độ dài cạnh trái/phải, làm tròn pixel. Bốn góc ảnh không xác định duy nhất tỷ lệ vật lý của vật thể; nếu cần đúng A4 hoặc kích thước khác, người dùng chọn Ratio/W×H. Không hứa tự suy ra kích thước vật lý.

### 9.3. Tài liệu nhiều layer và chỉnh tiếp

- Apply cùng một phép chiếu cho tất cả layer hiện có, gồm layer ẩn và khóa, rồi thay kích thước canvas theo đầu ra.
- Ảnh, chữ và hình đã có phải giữ vị trí tương đối; không flatten dự án để thực hiện crop.
- Text vẫn là text, shape vẫn có thuộc tính hình; pixel nguồn ảnh không bị ghi đè qua mỗi lần biến đổi.
- Layer thêm sau crop dùng tọa độ canvas mới. Ví dụ: nắn ảnh tờ giấy xong, thêm tiêu đề mới thì tiêu đề nằm thẳng trên ảnh kết quả.
- Chữ đã có trước crop mang biến dạng tương ứng; đổi nội dung vẫn giữ phép biến dạng. Việc sửa chữ đã bị phối cảnh dùng trình soạn thảo trong Properties như mục 10.
- Sau Save/Close/Open, kết quả, loại layer, nội dung và khả năng chỉnh tiếp phải được giữ.
- Undo/History trong phiên cho phép quay trước crop; mở lại dự án không phục hồi lịch sử undo cũ.
- V1.0 không có nút mở lại bốn điểm của một lần crop cũ sau các thao tác khác hoặc sau khi đóng dự án. Giữ nguồn và ma trận biến đổi không đồng nghĩa có trình sửa lịch sử crop.

### 9.4. Tính hợp lệ và chất lượng

- Khung phải lồi, bốn góc phân biệt, cạnh không giao nhau, diện tích đủ lớn; ma trận phải hữu hạn, khả nghịch và không đi qua đường kỳ dị trên vùng xuất.
- Với khung không hợp lệ: hiển thị viền lỗi, giải thích ngắn; Apply tắt; không đảo tên các góc hoặc tạo ảnh lỗi âm thầm.
- Trường kích thước sai hoặc vượt giới hạn được báo trước khi cấp phát ảnh.
- Giữ đúng orientation, alpha và color space. Các góc TL/TR/BR/BL không bị tráo khi ảnh có EXIF hoặc khi dùng màn hình khác scale.
- Preview và export dùng cùng hình học; chỉ mức lấy mẫu preview được giảm để tương tác mượt. Apply/export sử dụng dữ liệu nguồn và tham số đầy đủ.

## 10. Chữ, hình và màu

### 10.1. Type

- Click tạo point text; nhập nhiều dòng bằng Return; kết thúc bằng Cmd+Return hoặc nút Apply; Escape hủy phiên nhập.
- Font lấy từ font đã cài trên máy; có family/style, cỡ chữ 1–1000 px, màu, căn trái/giữa/phải và line spacing.
- Một kiểu định dạng cho toàn layer; chưa có rich text nhiều kiểu trong một layer, text theo path hoặc paragraph box tự xuống dòng.
- Hỗ trợ tiếng Việt Unicode, Telex/VNI qua bộ gõ macOS; không mất dấu do phím tắt V/T/C/Space hay khi đang composition.
- Chữ không có biến dạng phối cảnh chỉnh trực tiếp trên canvas. Chữ đã nắn phối cảnh chỉnh nội dung trong Properties, xem kết quả cập nhật trên canvas; nhấn đúp layer đưa focus đến đúng trình sửa.
- Thiếu font: giữ tên font gốc, thông báo và cho chọn thay thế. Dùng font dự phòng để xem, không âm thầm coi là hiển thị khớp hoàn toàn. Thay font là một thao tác undo được.

### 10.2. Shape và Color

- Rectangle, Ellipse, Line; kéo tạo hình, Shift tạo vuông/tròn hoặc đường theo góc chuẩn.
- Fill màu đặc hoặc None; Stroke màu, độ dày; chưa có gradient, boolean path hoặc vector node editor.
- Color panel nhập HEX/RGB và chọn màu; foreground/background mặc định đen/trắng, X đổi chỗ, D đặt lại khi không nhập text.
- Eyedropper lấy màu tổng hợp nhìn thấy tại điểm ảnh trên canvas, ở hệ màu sRGB; không lấy màu của overlay/grid.

## 11. Điều chỉnh ảnh

- Trong Properties của layer ảnh: Exposure −4 đến +4 EV, Brightness −100 đến +100, Contrast −100 đến +100, Saturation −100 đến +100.
- Trung tính là 0; −100 Saturation tạo ảnh xám. Giá trị UI phải được ánh xạ nhất quán sang bộ lọc; không tuyên bố kết quả số giống thuật toán Photoshop.
- Thứ tự cố định: Exposure → Brightness/Contrast → Saturation, trước biến đổi hình học và ghép layer.
- Có bật/tắt toàn nhóm để so sánh trước/sau và Reset về trung tính; không tự thay đổi layer khác.
- Một lần kéo slider là một mục undo; gõ giá trị rồi commit là một mục. Thông số được lưu trong dự án, không phá nguồn.

## 12. Undo, History, lưu và phục hồi

### 12.1. Undo/History

- Cmd+Z / Shift+Cmd+Z; History hiển thị tên thao tác và trạng thái hiện tại.
- Tối đa 100 bước mỗi tài liệu, ngân sách dữ liệu lịch sử đề xuất 128 MiB/tài liệu. Khi vượt, loại mục cũ nhất; không giữ bản sao toàn ảnh cho mỗi thay đổi tham số.
- Quay về một bước rồi chỉnh mới sẽ loại nhánh redo. Lịch sử không được lưu qua việc đóng/mở dự án.
- Save/Export/zoom/pan/chọn layer không tạo bước lịch sử. Save đặt mốc đã lưu; undo về đúng mốc đó phải cập nhật trạng thái tài liệu tương ứng.

### 12.2. PhotoAxis Document — `.paxis`

- Là một file thông thường chứa ZIP, đăng ký kiểu tài liệu riêng để mở bằng PhotoAxis. Người dùng mở/lưu `.paxis` trực tiếp. Phương án này thay thế file package macOS của bản draft.1 để thuận tiện khi sao chép và gửi file.
- Cấu trúc V1: `document.json` (format identifier `photoaxis.document`, format version 1, canvas/layer/tham số), `assets/` (nguồn ảnh nhúng), `preview.png` (bản xem trước). Tên tài nguyên dùng ID ổn định; dữ liệu text/shape lưu có cấu trúc.
- Đóng gói/nén không tái mã hóa nguồn ảnh bằng thuật toán mất dữ liệu. Lưu ảnh đã nén nguyên byte khi phù hợp; không hứa ZIP làm mọi ảnh nhỏ hơn đáng kể.
- Đọc file kiểm tra định danh/version, giới hạn giải nén và đường dẫn; tài nguyên không được thoát ra ngoài vùng làm việc. Không suy ra file là hợp lệ chỉ từ phần mở rộng.
- Save an toàn có thể phải ghi lại container; cache/recovery nội bộ lưu riêng để tránh đóng gói toàn bộ sau mỗi thao tác. Chỉ thay bản lưu cũ sau khi bản tạm hoàn tất.
- Save và Save As lưu toàn bộ nguồn ảnh cần thiết, cấu trúc layer, thông số ảnh, text/font, shape, transform, canvas và thumbnail; không phụ thuộc đường dẫn ảnh nhập ban đầu.
- Định dạng có schema version; bản mới hơn chưa hỗ trợ được báo rõ và không ghi đè file.
- Lưu bằng bản tạm rồi thay thế an toàn; lỗi hết dung lượng/quyền truy cập không làm hỏng bản lưu tốt trước đó.
- Chỉ báo Saved khi ghi hoàn tất. Có progress và khả năng hủy tác vụ dài tại điểm an toàn.
- V1.0 không tự ghi các thay đổi chưa xác nhận vào bản dự án người dùng đã Save; thay vào đó có recovery riêng.

### 12.3. Phục hồi

- Sau khi có thay đổi đã commit, tạo/cập nhật recovery ở vùng dữ liệu ứng dụng, tối đa 30 giây giữa hai bản recovery hoàn tất khi hệ thống hoạt động bình thường.
- Recovery không đổi dấu chưa lưu, không ghi đè ảnh gốc và không thay thế Save. Phiên crop/transform/text chưa commit không nằm trong recovery.
- Sau sự cố, lần mở app sau hiển thị danh sách recovery với tên/thời gian, cho mở lại hoặc bỏ. Mở recovery tạo tài liệu chưa lưu để người dùng Save As.
- Save thành công hoặc đóng với Don't Save phải dọn recovery tương ứng; không khôi phục lại tài liệu đã chủ động bỏ.
- Nếu recovery lỗi, thông báo một lần với trạng thái rõ ràng; không lặp hộp thoại theo chu kỳ.

## 13. Export và màu sắc

- PNG: sRGB 8 bit/kênh, giữ alpha; tùy chọn nền đặc nếu muốn.
- JPEG: sRGB 8 bit/kênh, Quality 1–100; nền trắng mặc định cho vùng trong suốt, có chọn màu nền trước khi xuất.
- Width/Height giữ tỷ lệ canvas, có khóa tỷ lệ mặc định; chỉ thay kích thước file xuất, không đổi tài liệu.
- Xuất tổng hợp layer đang hiển thị; bỏ overlay, selection handles và lưới. File đúng kích thước đã nhập.
- Có preview, vị trí lưu và cảnh báo ghi đè của hộp thoại hệ thống. Hủy hoặc lỗi xuất không để lại file đích dở dang.
- Gắn ICC sRGB và PPI; metadata GPS và metadata nguồn không cần thiết không được sao chép vào ảnh xuất. Đây là mặc định định dạng xuất của V1.0.
- Export không đánh dấu dự án là đã Save. Xuất ảnh nén không tạo lịch sử hay làm giảm chất lượng nguồn trong dự án.

## 14. Phím tắt

| Thao tác | Phím |
| --- | --- |
| New / Open / Save / Save As | Cmd+N / Cmd+O / Cmd+S / Shift+Cmd+S |
| Settings / Cài đặt | Cmd+, |
| Export | Option+Shift+Cmd+S |
| Đóng tab | Cmd+W |
| Undo / Redo | Cmd+Z / Shift+Cmd+Z |
| Duplicate Layer | Cmd+J |
| Free Transform | Cmd+T |
| Move / Type / Eyedropper | V / T / I |
| Nhóm Crop / chuyển công cụ Crop | C / Shift+C |
| Nhóm Shape / chuyển Shape | U / Shift+U |
| Hand / Zoom / Hand tạm | H / Z / Space |
| Fit / 100% / Zoom in-out | Cmd+0 / Cmd+1 / Cmd+Plus-Minus |
| Bật/tắt Rulers | Cmd+R |
| Ẩn/hiện Tools và panels | Tab |
| Apply / Cancel hình học | Return / Escape |
| Kết thúc nhập text | Cmd+Return |
| Dán ảnh | Cmd+V khi canvas có focus |
| Di chuyển layer | Arrow 1 px / Shift+Arrow 10 px |

Đây là mapping V1.0 đề xuất, không cam kết trùng mọi tùy biến phím của Photoshop. Khi focus ở text/numeric field, lệnh gõ, chọn, copy/paste và IME được ưu tiên. Trên canvas chưa hỗ trợ Copy/Cut vùng pixel; không được diễn giải Cmd+X thành xóa ảnh.

## 15. Giới hạn và hiệu năng đề xuất

### 15.1. Giới hạn phạm vi

| Tài nguyên | Giới hạn V1.0 đề xuất |
| --- | --- |
| Canvas và mỗi ảnh nguồn | Mỗi chiều 1–8000 px; tổng diện tích không quá 40 megapixel |
| Perspective Crop output | Mỗi chiều tối thiểu 2 px, cùng giới hạn cạnh/diện tích ở trên |
| Layer | Tối đa 50/tài liệu, gồm tất cả loại |
| Tổng ảnh nguồn duy nhất | Không quá 120 megapixel/tài liệu; nguồn nhân bản dùng chung không tính hai lần |
| Tài liệu | Tối đa 5 tab; tài liệu nền có thể giải phóng cache để ưu tiên tab đang dùng |
| Lịch sử | Tối đa 100 bước và 128 MiB/tài liệu |

Giới hạn pixel/layer không phải cam kết mọi tổ hợp đạt cùng tốc độ. Nếu file vượt giới hạn, cho chọn tạo bản thu nhỏ đáp ứng giới hạn hoặc Cancel; không tự giảm chất lượng mà không thông báo. Khi thiếu tài nguyên, từ chối tác vụ mới có lý do và giữ nguyên tài liệu đang làm.

### 15.2. Mục tiêu đo

Máy chuẩn đề xuất: Apple Silicon M1, RAM 16 GB, SSD nội bộ, màn hình 1440×900 hoặc tương đương. Báo cáo phải ghi cấu hình thực dùng; nếu không có máy này thì dùng máy đã thống nhất và không suy diễn số đo cho M1.

Tập cơ bản: JPEG sRGB 6000×4000, sau đó tài liệu 10 layer gồm ảnh nền 24 MP, một ảnh phủ tối đa 4 MP, bốn text và bốn shape. Tập giới hạn: canvas 40 MP, 50 layer, tổng nguồn trong hạn; tập giới hạn đánh giá ổn định, không áp dụng cùng mục tiêu tương tác.

- Mở JPEG 24 MP từ SSD và hiện bản xem trước dùng được: mục tiêu ≤3 giây sau khi chọn file, loại thời gian hộp thoại và lần chạy đầu hệ điều hành.
- Pan/zoom/kéo góc/slider trên tập cơ bản: preview đạt ít nhất 30 fps trong phần lớn thao tác; độ trễ cập nhật p95 ≤100 ms.
- Kết quả preview rõ hơn sau khi ngừng kéo: mục tiêu ≤500 ms.
- Xuất PNG 24 MP một layer: mục tiêu ≤10 giây; tác vụ dài có progress, không khóa UI.
- Mỗi chỉ tiêu đo tối thiểu 5 lượt với file cố định, báo trung vị và giá trị lớn nhất; độ trễ tương tác dùng mẫu frame/input trong phiên đo.
- Nếu không đạt: tối ưu hoặc đề xuất thay đổi có số đo để người dùng duyệt; không ghi “đã đạt” bằng cảm nhận.

## 16. Kiến trúc thực hiện

| Lớp | Lựa chọn |
| --- | --- |
| Ngôn ngữ và build | Swift, dự án Xcode macOS |
| Workspace | AppKit cho cửa sổ, menu, controls, panels, focus và tương tác chính |
| UI bổ trợ | SwiftUI qua hosting view khi đáp ứng thiết kế và hành vi |
| Bản địa hóa | String Catalog/tài nguyên dịch `vi` và `en`, khóa ngữ nghĩa ổn định, tham số hóa chuỗi; lưu lựa chọn ngôn ngữ ở cài đặt ứng dụng; không ghép câu dịch từ các mảnh văn bản |
| Canvas | MetalKit/MTKView và overlay native |
| Xử lý ảnh | Core Image; kernel Metal riêng chỉ khi cần |
| Text/shape | TextKit/Core Text và Core Graphics, giữ mô hình có thể sửa |
| File | Image I/O, NSDocument, container ZIP `.paxis` có schema và tài nguyên nhúng; cache/recovery nội bộ riêng |
| Thao tác | Commands/UndoManager; tách trạng thái phiên công cụ khỏi tài liệu đã commit |

Apple cung cấp [perspective correction](https://developer.apple.com/documentation/coreimage/cifilter-swift.class/perspectivecorrection%28%29) và [perspective transform](https://developer.apple.com/documentation/coreimage/ciperspectivetransformwithextent) để xử lý hình học. Việc tổ chức layer và duy trì khả năng chỉnh sửa là trách nhiệm của ứng dụng.

Mỗi layer giữ nguồn và ánh xạ từ tọa độ nội bộ sang canvas. Khi crop phối cảnh, tính phép chiếu chung H từ tứ giác nguồn sang hình chữ nhật đích, ghép H vào ánh xạ từng layer đang có, cập nhật canvas và vùng clip. Layer mới bắt đầu trong canvas mới. Renderer dùng cùng ánh xạ cho preview, hit-testing và export.

Đây là quyết định làm rõ/thay thế ý tưởng trước đó “chỉ đặt một filter sau bước ghép toàn tài liệu”. Cần kiểm chứng tính ổn định của phép chiếu, vùng clip và tính nhất quán compositing bằng mẫu kỹ thuật; không được âm thầm flatten layer để vượt qua khó khăn kỹ thuật.

Sau crop, phần nguồn ngoài vùng được chọn được giữ trong dự án nhưng bị clip khỏi kết quả. Clip của nội dung đã crop phải tiếp tục được lưu và biến đổi đúng qua những thao tác sau, tránh nội dung cũ bất ngờ hiện trở lại khi thêm layer hoặc crop tiếp.

Đọc file, decode, render export và ghi recovery chạy ngoài luồng UI; kết quả preview cũ phải bị bỏ nếu đã có thao tác mới. Nội dung dự án được kiểm tra schema, kích thước và đường dẫn tài nguyên trước khi sử dụng; không thực thi nội dung từ file dự án.

## 17. Ngoài phạm vi V1.0

- Đọc/ghi PSD/PSB, RAW, PDF, SVG, ảnh động, video.
- Brush/Eraser, lựa chọn pixel, Lasso/Magic Wand, mask, Pen/path nâng cao.
- Blend mode ngoài Normal, group, adjustment layer, clipping mask, smart object, layer effects.
- Healing, Clone Stamp, Liquify, Content-Aware Fill, AI, OCR hoặc tự nhận diện bốn góc.
- HDR, CMYK, 16/32 bit output, soft proofing hoặc quản lý in chuyên nghiệp.
- Layer multi-select, dock/undock tự do, nhiều workspace, plugin, action/batch.
- Đồng bộ cloud, tài khoản, cộng tác, subscription và cập nhật qua máy chủ riêng.
- Intel, iPad/iPhone/Windows và Mac App Store. Phân phối công khai qua website/GitHub Releases là phần công việc bổ sung đã yêu cầu trong `PHAT_HANH_PUBLIC.md`.
- Ngôn ngữ giao diện ngoài Tiếng Việt và English.

Việc bổ sung các mục này sau khi duyệt cần cập nhật phạm vi, tiêu chí nghiệm thu và ảnh hưởng tiến độ.

## 18. Kế hoạch triển khai và điều kiện kết thúc

| Mốc | Kết quả cần có |
| --- | --- |
| M1 | Workspace native theo mẫu; mở ảnh, tab, canvas, zoom/pan; bộ ảnh chụp UI để đối chiếu |
| M2 | Crop và Perspective Crop đầy đủ trên một ảnh; hình học, preview, export, undo đạt kiểm tra |
| M3 | Layer ảnh/chữ/hình, transform, chỉnh màu; Perspective Crop nhiều layer và thêm/sửa nội dung sau crop |
| M4 | Lưu/mở dự án, recovery, export, focus/phím tắt, lỗi/tài nguyên, bản dịch Việt/Anh và chuyển ngôn ngữ; hoàn tất bảng nghiệm thu |

Đây là thứ tự triển khai, không phải cam kết số tuần khi chưa có mẫu kỹ thuật và số đo. M2 là bản kỹ thuật trung gian, không thay thế bản V1.0 đủ phạm vi.

Bàn giao cuối gồm mã nguồn + hướng dẫn build, `.app` kiểm tra trên máy đích, hướng dẫn sử dụng tiếng Việt, dữ liệu thử không nhạy cảm và kết quả từng ca trong [CHECKLIST_NGHIEM_THU_V1.0.md](CHECKLIST_NGHIEM_THU_V1.0.md). Mọi ca bắt buộc phải pass hoặc có thay đổi phạm vi được người dùng xác nhận trước.

## 19. Ghi nhận xác nhận phạm vi

D01–D08, F01–F15, các giới hạn và tiêu chí nghiệm thu của bản **1.0-draft.3 đã được người dùng xác nhận**. Không yêu cầu xác nhận lại các nội dung này ở từng chặng. Thay đổi phạm vi sau đây phải được ghi nhận riêng; việc nghiệm thu đạt vẫn cần bằng chứng thực tế.

Các lựa chọn chính đã được duyệt:

1. macOS 14+, Apple Silicon; giao diện Tiếng Việt và English, bố cục theo Photoshop; có lựa chọn ngôn ngữ trong Cài đặt.
2. Perspective Crop toàn tài liệu, giữ layer, thêm chữ sau crop bình thường; chưa sửa lại một crop cũ sau khi đóng/mở.
3. PNG/JPEG/HEIC đầu vào, PNG/JPEG đầu ra và `.paxis` để chỉnh tiếp; chưa có PSD.
4. Có text/shape/layer nhưng chưa có Brush/Eraser/vùng chọn pixel/mask/AI.
5. Offline, không tài khoản; giao diện tối; giới hạn 40 MP, 50 layer, 5 tab và các giới hạn kết hợp ở mục 15.

Phần phát hành công khai được người dùng yêu cầu bổ sung sau khi chốt đặc tả; xem [PHAT_HANH_PUBLIC.md](PHAT_HANH_PUBLIC.md). Việc duyệt đặc tả không đồng nghĩa ứng dụng đã được xây dựng hoặc vượt qua nghiệm thu.

## 20. Bộ mockup giao diện

Bộ mockup tương tác **PhotoAxis V1.0** gồm 17 màn hình UI01–UI17, từ Welcome/Workspace, Perspective Crop trước/sau, Type/Adjustments/Transform/Shape đến các hộp thoại tạo tài liệu, kích thước, lưu, xuất, recovery và lỗi lưu. Xem danh mục, cách duyệt và phạm vi tương tác trong [BO_MOCKUP_V1.0.md](BO_MOCKUP_V1.0.md).

Đây là bản xem trước thiết kế, không phải ứng dụng macOS đã build. Dữ liệu, lưu/xuất và recovery trong mockup là mô phỏng; checklist nghiệm thu ứng dụng vẫn chưa chạy. Thanh chuyển màn hình dùng để duyệt thiết kế, không thuộc giao diện sản phẩm. Ký hiệu `Pa` trong mockup là vị trí biểu tượng tạm, chưa phải logo đã duyệt.

Mockup hiện tại minh họa giao diện tiếng Anh của draft.2. Yêu cầu giao diện tiếng Việt và Cài đặt ngôn ngữ được bổ sung ở draft.3, chưa được dựng vào mockup hiện tại; bản thiết kế cập nhật cần thể hiện cả hai ngôn ngữ theo mục 4.3.
