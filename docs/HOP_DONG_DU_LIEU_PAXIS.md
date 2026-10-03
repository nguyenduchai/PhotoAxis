# Hợp đồng dữ liệu editable bàn giao P09

Chốt từ model và kiểm thử P07 theo đặc tả 1.0-draft.3. Đây là hợp đồng bảo toàn dữ liệu khi triển khai `.paxis` schema 1; P09 đã triển khai Save/Open, định nghĩa field/reader ở [DINH_DANG_PAXIS](DINH_DANG_PAXIS.md); nghiệm thu A20 còn Export P10. Tên trường JSON cụ thể và reader/writer được triển khai ở P09; không suy diễn có thể mở file chỉ từ tài liệu này.

## Dữ liệu phải giữ

| Đối tượng | Nội dung bắt buộc |
| --- | --- |
| Tài liệu | ID, tên Unicode, canvas width/height pixel nguyên, PPI, schema version; danh sách layer theo thứ tự từ dưới lên |
| Source registry | ID SHA-256 của byte nhúng, kích thước sau chuẩn hóa orientation; tham chiếu entry trong `assets/`, bytes đúng với ID; các bản sao layer cùng nguồn dùng chung ID |
| Mỗi layer | UUID, tên Unicode, discriminant image/text/shape, payload đúng loại, visibility, lock, opacity, matrix và clip |
| Image | Source ID, thông số điều chỉnh ảnh của P08; không thay asset bằng ảnh composite/crop/cache |
| Text | Unicode nhiều dòng, PostScript font name gốc, family/style, font size px, màu sRGB RGBA, alignment, line spacing, local layout width/height |
| Shape | Rectangle/Ellipse/Line, local width/height, fill RGBA (alpha 0 là None), stroke RGBA/width, lineStart/lineEnd chuẩn hóa trong 0…1 |
| Preview | `preview.png` chỉ là ảnh xem nhanh; không dùng làm nguồn thay các layer editable |

Font binary không được nhúng tự động. Thiếu font giữ tên gốc và local extent đã lưu, dùng fallback để xem với cảnh báo; chỉ lựa chọn thay font rõ ràng mới thay payload và layout. UI language, FG/BG, zoom/pan, selection, tool session và Undo cũ không phải nội dung dự án. P09/P11 quản lý riêng các trạng thái giao diện/recovery nếu cần.

## Matrix và clip

- Matrix có 9 số Double hữu hạn, row-major, column vector: `p_canvas ~ M × [x_local, y_local, 1]`. Cả hai hệ gốc trái trên, y hướng xuống; tọa độ là biên pixel. Không ghi ma trận đã đổi sang hệ Core Image y-up.
- Crop toàn tài liệu ghép `M_new = H × M_old`, gồm cả layer ẩn/khóa, trong cùng transaction thay canvas/clip. Nhận biết affine phải bất biến khi nhân toàn bộ matrix với cùng hệ số khác 0. Không lấy ngưỡng tuyệt đối của m6/m7 để chọn trình sửa chữ.
- Clip là giao các đa giác lồi theo tọa độ local. `[]` nghĩa là không có clip bổ sung; **`[[]]` nghĩa là đã bị loại hoàn toàn**. Reader/writer không được bỏ polygon rỗng, thay null, hoặc đồng nhất hai trường hợp này.
- Crop giao support nguồn đang giữ với quad trong canvas rồi đưa về local. Polygon đã ghi có thể gồm hơn 4 đỉnh và có hướng winding khác nhau sau Flip. Giữ các giá trị và thứ tự đủ chính xác; không làm tròn xuống số nguyên hoặc Float32.
- Move/Transform và sửa chữ/shape giữ clip local. Sửa nội dung/kích thước không tự xóa hay nới clip cũ; nội dung chỉ hiện trong miền local đã giữ. Canvas Size mở rộng cũng không khôi phục phần đã loại. Muốn quay về trước crop dùng Undo trong phiên.
- Miền giữ lại phải hữu hạn và không qua pole của phép chiếu. Pole ngoài clip được phép; renderer có đường lấy mẫu ngược với output extent hữu hạn. Không từ chối file hợp lệ chỉ vì toàn bitmap gốc đi qua pole ở phần đã loại.
- Layer mới sau crop dùng canvas mới và clip `[]`: text/shape bắt đầu bằng translation tại điểm tạo; Place Image có scale/translation vừa canvas mới. Chúng không kế thừa H hay clip cũ.

## Kiểm tra reader/writer và round-trip bắt buộc ở P09

Áp dụng quota trước cấp phát, schema/type/array lengths/finite numbers, source existence/hash/dimensions, UUID/reference/order, tài nguyên ZIP/path/size an toàn. Tham số P08 được chốt dưới đây. Lưu atomic và saved-state marker theo snapshot đã ghi thành công; không serialize Undo như dữ liệu dự án.

Round-trip phải dùng fixture ảnh/chữ/hình, hidden/locked, hai crop, Move/Transform, sửa chữ cũ, thêm chữ mới, clip rỗng hoàn toàn, font thiếu và layer chia sẻ nguồn. So sánh source bytes/hash, typed payload, matrix/clip, canvas/PPI/order/flags/params và pixel render trước–sau; đóng/mở rồi sửa tiếp bằng cả VI/EN. Bốn điểm phiên crop cũ không cần được mở lại; không phục hồi lịch sử Undo cũ. A20/A39/A43 giữ chưa đạt cho đến khi reader/writer và luồng native tương ứng được nghiệm thu.

## Tham số điều chỉnh ảnh P08

Mỗi layer image giữ `ImageAdjustments` riêng: `enabled` Boolean, `exposure` Double −4…+4 EV, `brightness`, `contrast`, `saturation` Double −100…+100 theo đơn vị UI. Trung tính bốn số 0, enabled mặc định true. Ghi giá trị UI, không ghi hệ số Core Image đã ánh xạ; giữ Double hữu hạn, không làm tròn theo chuỗi đang hiển thị hoặc locale. Validation áp dụng cả khi enabled=false; tắt nhóm chỉ bypass render, không xóa giá trị. Reader phải kiểm tra đủ trường/type/range trước tạo model. Layer text/shape không có nhóm điều chỉnh ảnh trong schema.

Thứ tự trong working space linear-sRGB: Exposure → Brightness/Contrast → Saturation → local clip → transform → opacity → composite. Mapping của bản 1.0: EV giữ nguyên cho CIExposureAdjust; Brightness `b/100`, Contrast `1+c/100` trong CIColorControls với Saturation=1; bước Saturation dùng `1+s/100`, Brightness=0 và Contrast=1. Neutral/bypass không thêm filter. Không cam kết kết quả số như Photoshop. Chi tiết và nguồn Apple ở ADR-020.

Duplicate sao chép tham số nhưng tiếp tục chia sẻ cùng asset ID; chỉnh một bản không sửa bản khác. Hidden/locked và các phép hình học/clip không xóa tham số. Reset đặt lại bốn số 0 và enabled=true, có Undo; nguồn nhúng không đổi. P09 phải round-trip cả giá trị cực trị, giá trị phân số, enabled=false với giá trị khác 0, layer duplicate/shared source và hai crop. So sánh pixel preview/thumbnail/render sau mở lại và kiểm tra chỉnh tiếp. Phần Save/Open của A25 còn chưa nghiệm thu ở P08.
