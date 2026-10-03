# P06 — Type, Shape và Color

Thực hiện P06 sau P05. Đọc `docs/prompts/BOI_CANH_CHUNG.md`, đặc tả mục 7, 9.3, 10, 14 và checklist.

## Công việc

1. Layer text có nội dung Unicode nhiều dòng, font family/style, cỡ 1–1000 px, màu, căn lề, line spacing; một kiểu định dạng toàn layer. Giữ dữ liệu text có cấu trúc, không rasterize thành layer ảnh.
2. Point text chỉnh trực tiếp trên canvas khi chưa bị phối cảnh, dùng hệ nhập native hỗ trợ marked text/composition. Return xuống dòng, Cmd+Return commit, Escape cancel. V/T/C/Space và phím tắt không nuốt chữ khi nhập Telex/VNI.
3. Chuẩn bị trình sửa Properties cho text có biến dạng phối cảnh; double-click layer đưa focus đúng nơi. Hành vi này được kiểm tra tích hợp đầy đủ ở P07.
4. Font thiếu: giữ tên font gốc, thông báo/fallback để xem và lựa chọn thay thế có undo. Không âm thầm sửa model font khi chỉ dùng fallback render.
5. Rectangle/Ellipse/Line với Fill/None/Stroke, kéo tạo, Shift ràng buộc đúng; model shape chỉnh lại được. Color có HEX/RGB, foreground/background, X/D đúng ngữ cảnh.
6. Eyedropper lấy composite ảnh tại document pixel theo sRGB, bỏ overlays/grid/handles. Layer text/shape tham gia selection, lock, opacity, transform, undo như layer ảnh.

## Hoàn thành khi

- A22–A24 đạt với kiểm tra native IME, font thiếu, alpha, sample màu không chứa overlay; mở rộng A10–A11 cho text/shape.
- Các thao tác text/shape tạo transaction undo phù hợp, Cancel không để lại layer rác hoặc thay đổi đã hủy.
- Tên công cụ/panel/lỗi và accessibility có cả vi/en; có ảnh chụp ví dụ chữ tiếng Việt.

Ghi `docs/bao-cao/P06.md`, cập nhật tiến độ/checklist và bàn giao theo bối cảnh chung.
