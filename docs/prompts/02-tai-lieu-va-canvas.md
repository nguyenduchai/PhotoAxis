# P02 — Tài liệu, nhập ảnh, canvas và điều hướng

Thực hiện P02 sau P01. Đọc `docs/prompts/BOI_CANH_CHUNG.md`, đặc tả mục 5–6, 13, 15–16, checklist và trạng thái repo.

## Công việc

1. Xây model tài liệu có ID ổn định, canvas/PPI, layer ảnh nguồn, transform/clip, trạng thái sửa và trạng thái viewport riêng; chuẩn bị layer text/shape mà không flatten mô hình.
2. Tạo tài liệu theo preset/tùy chỉnh, nền trong suốt/trắng/đen. Mở PNG/JPEG/HEIC tĩnh bằng Image I/O; sửa orientation EXIF, quản lý alpha và chuyển sang quy trình sRGB theo đặc tả. Lỗi/định dạng không hỗ trợ có thông báo vi/en.
3. Place Embedded, kéo/thả và dán ảnh theo đúng vị trí/ngữ cảnh; nhiều file có lỗi riêng không làm mất phần đã nhập. Kiểm tra kích thước/nguồn trước decode lớn và trước cấp phát; không ghi đè file gốc.
4. Tối đa 5 tab có model/zoom/pan/selection/tool session/undo riêng. Document coordinator và NSDocument phải có một nguồn quyết định save/close, tránh hai hệ vòng đời xung đột. Hoàn thiện phần save/close phụ thuộc P09/P11 sau, không giả báo Saved.
5. Dựng renderer MetalKit/Core Image, checkerboard, zoom 5–1600%, Fit/100%, nhập zoom, Hand/Space/pinch/pan, rulers. Xử lý document/view/device/backing scale và zoom quanh con trỏ đúng; 100% theo pixel thiết bị.
6. Decode/render nặng ngoài UI, hủy/bỏ kết quả cũ khi thay ảnh/tab; thu hồi cache có kiểm soát. Thêm chuỗi vi/en cho mọi UI mới.

## Hoàn thành khi

- A04–A07 và A09 có bằng chứng phần đã hỗ trợ; nhập file Unicode/EXIF/alpha và trường hợp lỗi được kiểm tra.
- A33/A35 phần nhập có kiểm tra; phần export và stress cuối chưa được tick sớm.
- Có kiểm tra tọa độ/các backing scale và bằng chứng native pan/zoom không lệch overlay. Thiết bị không có phải ghi chưa kiểm chứng.

Ghi `docs/bao-cao/P02.md`, cập nhật tiến độ/checklist và bàn giao theo bối cảnh chung.
