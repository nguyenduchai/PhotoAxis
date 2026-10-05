# OCR tiếng Việt, bảng ảnh và làm mờ/che — build10

Theo yêu cầu mới của chủ dự án, giao diện chỉ giữ **OCR tiếng Việt** và **Bảng ảnh** từ gói điều tra. **Làm mờ/che** là chỉnh sửa ảnh thông thường. Các nút bên phải là **Chỉnh sửa / OCR tiếng Việt / Bảng ảnh / Làm mờ/che**; không cần tạo hồ sơ hay nhập người xử lý.

## OCR tiếng Việt

1. Mở ảnh hoặc dự án. Chốt hoặc hủy chỉnh sửa đang dở.
2. Chọn **OCR tiếng Việt** bên phải. Mặc định đọc toàn bộ canvas hiện tại, gồm các chỉnh sửa đã chốt.
3. Nếu chỉ cần một đoạn, chọn **Chọn vùng đọc chữ**, kéo hình chữ nhật trên ảnh. **Đọc toàn ảnh** bỏ vùng này.
4. Nhấn **Nhận dạng chữ**. Kết quả có thể sửa trực tiếp; kiểm tra dấu, số và xuống dòng trước khi dùng.
5. Dùng **Sao chép** hoặc **Lưu TXT…** để giữ kết quả. TXT là UTF-8, không kèm ảnh hoặc hồ sơ.

**Hủy nhận dạng** cho phép tiếp tục chỉnh sửa và bỏ kết quả muộn. macOS có thể còn dừng tác vụ Vision; khi đó nhận dạng mới báo bận. Đổi tab hoặc chỉnh sửa ảnh bỏ kết quả OCR cũ. OCR không sửa ảnh, không tạo History, không ghi nhật ký điều tra. Kết quả chỉ giữ trong phiên làm việc; hãy lưu TXT trước khi đổi ảnh/đóng app. Khả dụng và thời gian OCR tiếng Việt phụ thuộc runtime macOS; không thay bằng tiếng Anh hoặc dựng nội dung nếu engine không nhận được chữ.

## Lập bảng ảnh

1. Chọn **Bảng ảnh**. **Thêm ảnh đang mở** chụp kết quả canvas đã chốt, gồm vùng bảo mật đã áp dụng. **Thêm tệp ảnh…** cho chọn nhiều PNG/JPEG/HEIC/HEIF.
2. Chọn ảnh trong danh sách, nhập **Chú thích ảnh được chọn**. Dùng **Lên / Xuống / Bỏ ảnh** để sắp xếp; chú thích đi cùng đúng ảnh.
3. Nhập **Tiêu đề bảng ảnh** và **Ghi chú chung**. Chọn **1, 2, 4 hoặc 6 ảnh mỗi trang**; A4 **Dọc / Ngang**. Ảnh giữ đúng tỷ lệ, không bị cắt hoặc kéo méo.
4. Bản xem trước cập nhật tự động. Dùng **Trang xem trước** để xem các trang. Nếu bảng điều khiển dài hơn cửa sổ, cuộn xuống để thấy tùy chọn và nút xuất.
5. **Xuất toàn bộ PDF…** xuất tất cả trang A4; **Xuất trang này PNG…** xuất đúng trang đang xem. Cả hai dựng ở 300 PPI.

Tên tệp không được in mặc định. Chỉ bật **In tên tệp dưới ảnh** khi muốn công khai tên đó. Tiêu đề/chú thích quá dài sẽ báo lỗi thay vì âm thầm cắt mất chữ; rút gọn nội dung hoặc dùng ít ảnh mỗi trang.

Tối đa 100 ảnh, 16 MiB mỗi bản sao và 128 MiB tổng dữ liệu; bản sao được giới hạn 4 MP mỗi ảnh. Tệp gốc không bị thay đổi. Bảng ảnh giữ một bản chụp tại lúc thêm: chỉnh sửa ảnh ở tab sau đó không tự cập nhật ảnh đã thêm; bỏ ảnh cũ và thêm lại nếu cần. Bản nháp bảng ảnh **chỉ tồn tại trong phiên làm việc**, chưa có lưu/mở bản nháp. PDF gồm bitmap toàn trang, bao gồm chữ; không có chữ OCR chọn/copy, không nhúng tệp ảnh gốc, GPS/EXIF hoặc layer ẩn. Tiêu đề PDF và những chữ người dùng chọn in vẫn công khai.

## Làm mờ/che gương mặt hoặc nội dung tài liệu

1. Mở ảnh, chốt các chỉnh sửa đang dở, chọn **Làm mờ/che**.
2. Kéo trên ảnh để thêm từng vùng hình chữ nhật. Có thể chọn tối đa 20 vùng mỗi lần chốt.
3. Chọn **Che đen**, **Làm mờ** hoặc **Khảm ô vuông**. Với làm mờ/khảm, kéo thanh mức độ; kết quả cập nhật trực tiếp. **Che đen** phù hợp cho nội dung chữ cần giữ kín.
4. **Gợi ý vùng gương mặt** dùng Vision trên thiết bị để đề xuất khung; cần kiểm tra khung, bổ sung hoặc bỏ vùng thủ công. Đây không phải nhận dạng danh tính hoặc bảo đảm tìm thấy mọi gương mặt.
5. **Bỏ vùng cuối / Bỏ tất cả vùng / Hủy vùng đang chọn** chỉ thay bản nháp, chưa sửa ảnh.
6. **Chốt làm mờ/che** thêm các lớp bảo mật khóa phía trên nội dung, gộp thành một bước **Hoàn tác**. Sau khi chốt, về trang Chỉnh sửa để tiếp tục; Hoàn tác/Thực hiện lại dùng như chỉnh sửa khác.
7. Khi cần chia sẻ, xuất PNG/JPEG bằng **Tệp → Xuất…**, hoặc thêm canvas đã chốt vào Bảng ảnh rồi xuất PDF/PNG. Kiểm tra chính tệp xuất trước khi gửi.

Vùng làm mờ/khảm sau khi chốt là bản chụp raster, chưa phải bộ lọc tham số có thể chỉnh lại. Muốn đổi mức độ, hoàn tác rồi làm lại. Các lớp bảo mật tuân theo Crop/Perspective/Image Size; nhưng nếu di chuyển hoặc sửa nội dung bên dưới, phải kiểm tra lại độ che phủ. Không được coi blur/khảm nhẹ là chắc chắn không thể nhận ra thông tin. Các patch blur/khảm được dựng đục để alpha không làm lộ lớp dưới.

**Không gửi `.paxis` như bản đã bảo mật:** dự án vẫn giữ nguồn ảnh và các lớp để chỉnh sửa. Bản xuất PNG/JPEG/PDF được gộp; tệp gốc và byte nguồn trong dự án vẫn nguyên vẹn. Nếu chọn trực tiếp một tệp gốc chưa che bằng “Thêm tệp ảnh”, bảng ảnh sẽ sử dụng tệp đó; chức năng không tự che mọi ảnh thêm vào.

## Hồ sơ cũ

Các tính năng quản lý hồ sơ, tiếp nhận/bàn giao, hash/audit, đo/hiệu chuẩn, video, so sánh, rà soát và JSON điều tra đã bỏ khỏi giao diện sản phẩm. File `.paxcase` cũ không bị xóa hoặc ghi lại. Mở `.paxcase` hiển thị hướng dẫn, không kích hoạt các trang cũ. Có thể mở `.paxis` bên trong bằng Tệp → Mở: bản làm việc được tách thành **bản sao chưa lưu**, giữ nguồn/layer nhưng bỏ ràng buộc hồ sơ. Lưu sang thư mục khác; app từ chối ghi vào `.paxcase`, kể cả qua liên kết thư mục. Bản sao không mang ý nghĩa nhật ký điều tra được nối tiếp.

Các tài liệu gói điều tra cũ là lịch sử triển khai, không mô tả chức năng hiện hành build10.
