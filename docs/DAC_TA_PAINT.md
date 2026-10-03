# Paint1 và xem trước trực tiếp — build 6

Phần mở rộng theo yêu cầu người dùng ngày 03/10/2026: chỉnh sửa cần xem trực tiếp không phải bấm nút, thêm Brush và Clone Stamp. Baseline `1.0-draft.3` giữ vai trò lịch sử; yêu cầu mới cho phép bổ sung hai công cụ vốn ngoài baseline.

- Brush B: màu tiền cảnh RGBA, cỡ 1–1000 pixel tài liệu, độ cứng và độ đậm 0–100%. Kéo chuột xem ngay trên canvas, thả chuột chốt một command/Undo; Escape hủy nét. Dấu chấm và nội suy khoảng cách đều được hỗ trợ; opacity áp dụng một lần cho hợp nét của từng stroke.
- Clone Stamp S: Option-click lấy mẫu từ composite hiển thị của model đã chốt, không lấy overlay. Mẫu PNG sRGB8-bit được đóng băng đến lần lấy mẫu kế tiếp. Chọn điểm bằng click rồi Option-Return là đường bàn phím tương đương. Aligned giữ độ lệch qua nhiều nét; tắt Aligned bắt đầu mỗi nét tại điểm mẫu. Phần mẫu ngoài canvas trong suốt. Nguồn mẫu nhúng tự chứa trong project.
- Nét lưu thành typed layer `paint`, hỗ trợ ẩn/khóa/opacity/duplicate/Move/Transform/Crop/Perspective theo các phép layer hiện có. Chọn layer ảnh/chữ/hình sẽ tạo paint layer phía trên; không ghi đè pixel nguồn. Chọn paint layer phù hợp canvas/identity thì thêm nét vào layer đó. Layer paint đã đổi hình học tạo layer mới trên canvas hiện tại.
- Phiên kéo chuột không vào Save/recovery; chỉ nét đã thả chuột được ghi. Mở lại giữ nét và nguồn nhưng History bắt đầu rỗng. Project có paint dùng schema4; đọc lại schema1/2/3. Build cũ phải từ chối schema4.
- Mỗi nét tối đa4096 điểm/65536 mẫu; mỗi layer512 nét/32768 điểm. Tổng document262144 điểm và120MP ROI mask; quota nguồn50ID/120MP cùng quota layer/canvas/container hiện có. Vượt quota từ chối tiếp nhận thay đổi, giữ trạng thái cuối hợp lệ; không làm giả thành công.
- Scan sliders/ô số tự preview với coalescing85ms, Apply chỉ bật sau kết quả mới hợp lệ. Perspective Crop có inset512px tự cập nhật với coalescing45ms trong khi góc gốc còn kéo được; full-preview tùy chọn vẫn dùng được. Apply/Return là chốt Undo, không phải điều kiện để thấy kết quả. Brightness/Exposure/Contrast/Saturation vốn continuous giữ nguyên.
- Hồ sơ điều tra giữ intake nguyên byte. Clone lưu asset vào `derived/<SHA256>` trước mutation model/audit; lỗi commit xóa file mới và giữ model/log cũ. Mở hồ sơ kiểm hash/decode mẫu dẫn xuất. Nét mới làm vùng che/chuẩn đo gắn model cũ stale như mọi chỉnh sửa khác.

Chưa có pressure/tablet, brush texture/custom preset, eraser, healing/content-aware clone, mask, blend mode khác Normal hoặc brush động theo góc. Không cam kết60FPS/full quota/mọi thiết bị từ oracle nhỏ.

Kích thước ảnh và Kích thước canvas cũng tự preview khi nhập số hoặc chọn neo; tham số sai khóa Apply và phục hồi hình gốc. Cancel phục hồi cả viewport. Chỉ Apply/Return ghi một Undo; ảnh nguồn giữ nguyên.

Crop thường cũng hiện inset kết quả tự cập nhật khi kéo vùng hoặc chỉnh tỷ lệ/kích thước; Apply chỉ chốt Undo.
