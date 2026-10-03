# P04 — Crop thường, Image Size và Canvas Size

Thực hiện P04 sau P03. Đọc `docs/prompts/BOI_CANH_CHUNG.md`, đặc tả mục 8, hợp đồng geometry/clip và checklist.

## Công việc

1. Crop chữ nhật với góc/cạnh, rule of thirds, vùng tối ngoài crop, Free/Original/các tỷ lệ có sẵn/A4/Custom, Swap, Reset, Apply/Cancel. Khung nằm trong canvas; controls hoạt động ở zoom/pan khác nhau.
2. Phân biệt Ratio với W×H: Ratio lấy số pixel từ vùng cắt, W×H resample theo số nhập. Kiểm tra giới hạn và input nguyên trước cấp phát; kết quả pixel khớp nhãn.
3. Cắt toàn tài liệu bằng transform/clip có thể undo; giữ nguồn và layer ngoài khung, gồm layer ẩn/khóa. Không thêm tùy chọn xóa nguồn ngoài crop.
4. Image Size scale toàn bộ layer và canvas; Canvas Size theo anchor 3×3 không scale nội dung; rotate canvas 90°/180° và flip. PPI chỉ đổi metadata khi không có thay đổi kích thước pixel.
5. Một Apply là một command; tool session giữ theo tab. Save/Export/đổi tool/close khi phiên chưa chốt dùng Apply/Discard/Cancel ở các entry point hiện có; không tự commit khi chuyển tab.

## Hoàn thành khi

- A12–A13 có fixture và kiểm tra số pixel/tỷ lệ/anchor/orientation, undo/redo/Cancel, nhiều layer ẩn/khóa.
- Clip không tự lộ nguồn cũ qua crop/resize/rotate tiếp theo. So model geometry với hình render, không chỉ assert giá trị UI.
- Có hộp thoại và lỗi vi/en; overlay không nằm trong output renderer dùng cho export sau này.

Ghi `docs/bao-cao/P04.md`, cập nhật tiến độ/checklist và bàn giao theo bối cảnh chung.
