# P05 — Perspective Crop trên một ảnh

Thực hiện P05 sau P04. Đọc `docs/prompts/BOI_CANH_CHUNG.md`, toàn bộ mục 9 của đặc tả, kiến trúc geometry/renderer và checklist. Đây là mốc kỹ thuật ảnh đơn; chưa được tuyên bố F08 hoàn tất trước P07/P09/P10.

## Công việc

1. Công cụ trong flyout Crop, Shift+C, kéo tạo khung ban đầu, kéo bốn góc độc lập và kéo giữa để dịch tứ giác trong canvas. Zoom/pan/Space hoạt động; handles giữ kích thước trên màn hình.
2. Tính homography với quy ước TL/TR/BR/BL rõ, ma trận hữu hạn/khả nghịch; không cắt qua singularity. Chặn góc trùng/lõm/tự cắt/gần thẳng/diện tích nhỏ; tắt Apply và giải thích lỗi.
3. Grid phản ánh phép chiếu. Auto = trung bình cặp cạnh đối diện; Ratio dựa gần Auto và ép tỷ lệ; W×H dùng pixel nhập. Swap không tráo góc nguồn; Clear về Auto giữ khung; Reset về canvas giữ mode; Preview bật/tắt không thêm lịch sử.
4. Preview/Apply và renderer xuất dùng cùng mapping nguồn/đích, orientation, clip/alpha/sRGB. Preview có thể giảm lấy mẫu, Apply giữ nguồn và mô hình transform cho nhiều layer về sau; không thay nguồn bằng bitmap đã flatten.
5. Apply tạo một undo; Cancel trả cả canvas/model về trước phiên. Giữ session theo tab, dữ liệu kiểm tra trước allocation, bỏ render result cũ khi người dùng tiếp tục kéo.

## Hoàn thành khi

- A14–A17 đạt trên ảnh đơn; A21 phần undo/crop lặp lại có kết quả. Dùng lưới có bốn góc khác màu, EXIF rotation và alpha để phát hiện tráo/lật góc.
- Có test geometry số học, hình render tham chiếu dung sai hợp lý và thao tác native tại nhiều zoom/backing scale; không chỉ kiểm tra ảnh “trông thẳng”.
- Lưu ảnh trước/sau và thông số góc/kích thước trong báo cáo; ghi rõ phạm vi multilayer/save/export còn phụ thuộc chặng sau.

Ghi `docs/bao-cao/P05.md`, cập nhật tiến độ/checklist và bàn giao theo bối cảnh chung.
