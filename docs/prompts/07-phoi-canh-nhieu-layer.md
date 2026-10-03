# P07 — Perspective Crop nhiều layer và chỉnh tiếp

Thực hiện P07 sau P06. Đọc `docs/prompts/BOI_CANH_CHUNG.md`, đặc tả mục 9.3–9.4 và 16, báo cáo P05/P06, hợp đồng ma trận/clip và checklist.

## Công việc

1. Nắn toàn tài liệu bằng cùng một homography H; ghép vào mapping của từng layer đã có, gồm layer ẩn/khóa. Cập nhật canvas/clip trong cùng transaction. Lock chỉ chặn sửa trực tiếp layer, không bỏ layer khỏi thao tác cấp tài liệu.
2. Renderer giữ image/text/shape là các loại nguồn sửa được; có thể tạo cache raster để render nhưng không thay nguồn/model bằng cache. Kiểm tra thứ tự nhân ma trận và chuyển hệ tọa độ, không sửa sai bằng offset riêng rải rác.
3. Giữ clip của nội dung đã crop qua transform/crop tiếp; phần nguồn cũ ngoài clip không tự hiện ra. Layer mới sau crop bắt đầu ở canvas mới, không nhận phép chiếu cũ.
4. Text có trước crop sửa trong Properties và giữ phép chiếu; text mới sau crop nằm thẳng. Move/Transform/hit-test tiếp tục đúng với mapping projective; shape giữ Fill/Stroke và chỉnh tiếp được.
5. Undo/Redo, crop lần hai rồi undo, layer ẩn bật lại và layer khóa mở khóa không làm mất loại/source/clip/kích thước trước đó. Một lần Apply vẫn một lịch sử.

## Hoàn thành khi

- A18–A19 và A21 đạt trên fixture nhiều layer ảnh/chữ/hình, có hidden/locked; so sánh model trước/sau và output render.
- Kiểm tra nhiều lần crop/transform cho tính ổn định và tài nguyên; không có đường code flatten dự án.
- Ghi contract cần serialize ở P09: nguồn, kiểu layer, matrix, clip, canvas, text/shape, thứ tự và thông số. A20 lưu/mở lại chưa tick trước P09/P10.

Ghi `docs/bao-cao/P07.md`, cập nhật kiến trúc/tiến độ/checklist và bàn giao theo bối cảnh chung.
