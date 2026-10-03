# Brush, Clone Stamp và xem trực tiếp

Có trong PhotoAxis1.0.0(6), native trong workspace chung. [Phạm vi](DAC_TA_PAINT.md).

1. Mở ảnh hoặc project, chọn **Brush (B)** trên thanh công cụ. Chọn màu tiền cảnh, chỉnh **Cỡ / Cứng / Đậm** bằng thanh trượt hoặc ô số; cỡ tính theo pixel tài liệu. Phím `[`/`]` giảm/tăng cỡ. Kéo chuột trên ảnh; nét xuất hiện khi kéo. Thả chuột chốt một Undo; Escape hủy nét đang kéo.
2. Chọn **Clone Stamp (S)**. **Giữ Option và click** vào điểm nguồn, đợi trạng thái mẫu sẵn sàng. Có thể click điểm nguồn rồi **Option-Return**. Sau đó kéo ở vùng đích. Dấu cộng cam chỉ điểm mẫu, vòng tròn chỉ cỡ. Mẫu lấy từ toàn bộ composite đã chốt đang thấy và được giữ cố định; muốn cập nhật mẫu sau sửa ảnh, lấy mẫu lại.
3. Bật **Liên tục** (Aligned, giữ độ lệch nguồn/đích) để nhiều nét tiếp tục cùng độ lệch nguồn/đích. Tắt để mỗi nét bắt đầu lại từ điểm mẫu. Đổi lựa chọn sẽ reset độ lệch cho nét kế tiếp. Kích thước/hardness/opacity dùng chung hai công cụ và tự cập nhật, không cần Apply.
4. Nét nằm trên layer vẽ riêng. Chọn layer vẽ để thêm nét; chọn layer ảnh/chữ/hình tạo layer vẽ phía trên. Ẩn/khóa/opacity/duplicate/Move/Transform theo Layers. Paint layer khóa hoặc ẩn không nhận nét; chỉnh hình học toàn tài liệu rồi vẽ tiếp sẽ tạo layer trên canvas mới.
5. Save `.paxis` lưu nét và mẫu clone, Export PNG/JPEG xuất composite. Project paint **schema4 cần build6 trở lên**; không mở trên build cũ. Nguồn ảnh và mẫu clone còn nhúng, có thể chứa nội dung ngoài crop hoặc vùng đã phủ màu. Brush/Clone không phải công cụ xóa dữ liệu bí mật khỏi project. Dùng đầu ra đã rà soát/che của hồ sơ khi chia sẻ.

Scan tự cập nhật ảnh **Sau xử lý** khi kéo/nhập tham số; không còn nút Xem trước. Perspective Crop tự hiện ô **Xem trực tiếp** khi tứ giác hợp lệ; kéo góc vẫn thao tác trên ảnh gốc. Exposure/Brightness/Contrast/Saturation xem trước liên tục như trước. **Áp dụng/Return** chốt chỉnh sửa vào Undo; **Hủy/Escape** bỏ bản nháp. Lỗi tham số làm Apply bị khóa cho đến khi có preview hợp lệ mới.

Trong hồ sơ, nét Brush/Clone và Undo/Redo được ghi audit; intake gốc giữ nguyên. Chỉnh sửa làm review vùng che hoặc chuẩn đo cũ không còn khớp model. Mẫu clone được giữ trong case ngay khi chốt nét, kể cả trước Save; nguồn dẫn xuất có hash riêng. Hash không chứng nhận tính xác thực hoặc nguồn gốc ảnh.

Giới hạn hiện tại: chuột, không pressure/tablet/eraser/healing/texture/mask; một nét4096 điểm, một layer512 nét/32768 điểm, document262144 điểm và120MP tổng ROI mask. Quota source/canvas/layer/History hiện có vẫn áp dụng. Nếu thông báo giới hạn, thả chuột chốt đoạn hợp lệ hoặc Escape hủy, rồi giảm độ dài/cỡ hoặc tạo project khác. Chưa chứng nhận native60FPS/full quota trên mọi máy đích.

Kích thước ảnh và Kích thước canvas cũng tự preview khi nhập số hoặc chọn neo; tham số sai khóa Apply và phục hồi hình gốc. Cancel phục hồi cả viewport. Chỉ Apply/Return ghi một Undo; ảnh nguồn giữ nguyên.

Crop thường cũng hiện inset kết quả tự cập nhật khi kéo vùng hoặc chỉnh tỷ lệ/kích thước; Apply chỉ chốt Undo.
