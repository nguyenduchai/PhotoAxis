# P08 — Điều chỉnh ảnh theo layer

Thực hiện P08 sau P07. Đọc `docs/prompts/BOI_CANH_CHUNG.md`, đặc tả mục 11, renderer/color contract và checklist.

## Công việc

1. Exposure −4…+4 EV, Brightness/Contrast/Saturation −100…+100, giá trị trung tính 0; Saturation −100 cho ảnh xám. Document rõ mapping sang filter thực dùng, không cam kết số giống Photoshop.
2. Thứ tự cố định Exposure → Brightness/Contrast → Saturation, trước transform hình học và composite. Chỉ layer ảnh đang chọn nhận thay đổi; khóa layer chặn sửa.
3. Properties có slider, ô nhập số, giá trị/đơn vị, Enable/Reset. Kéo liên tục chỉ tạo một undo, Cancel/Undo đưa đúng trạng thái; tên command và lỗi vi/en.
4. Tối ưu preview cập nhật, bỏ frame cũ khi kéo nhanh/chuyển tab; không decode nguồn mới mỗi tick. Không thay nguồn hoặc thay đổi màu các layer khác.
5. Đặt tham số vào model có thể serialize; render cache invalidation đúng sau opacity, visibility, perspective và undo.

## Hoàn thành khi

- A25 phần điều chỉnh/Enable/Reset/Undo đạt; phần save/reopen hoàn tất ở P09.
- Có fixture trung tính, giá trị cực trị, alpha edge, hai layer khác màu và layer đã phối cảnh. Trung tính không làm lệch ảnh ngoài dung sai pipeline đã định nghĩa.
- Đo ngắn độ đáp ứng để phát hiện vấn đề; báo số thực đo, chưa suy ra đạt toàn bộ benchmark P12.

Ghi `docs/bao-cao/P08.md`, cập nhật tiến độ/checklist và bàn giao theo bối cảnh chung.
