# Cài đặt PhotoAxis — build 9

Mở **PhotoAxis → Cài đặt…** bằng **Cmd+,**. Danh mục nằm bên trái, các nhóm tùy chọn bên phải. Giá trị hợp lệ tự lưu; **Đóng** chỉ đóng cửa sổ. **Đặt lại nhóm hiện tại** chỉ khôi phục nhóm đang xem.

| Danh mục | Tùy chọn và tác dụng |
|---|---|
| Chung | Ngôn ngữ Theo hệ thống / Tiếng Việt / English; cần khởi động lại. Hiện version/build và phím tắt. |
| Giao diện | **Theo hệ thống / Tối / Sáng**, áp dụng ngay cho cửa sổ, bảng, thanh công cụ và hộp thoại. Theo hệ thống bỏ appearance override để AppKit tự theo macOS. |
| Workspace | Độ rộng bảng 260–420 pt, thanh công cụ một/hai cột, hiện bảng phải, bật thước, đơn vị px/mm/cm/in theo PPI của tài liệu. |
| Canvas | Nền vùng làm việc tối/vừa/sáng, hiện lưới trong suốt, cỡ ô nhỏ/vừa/lớn. Nền này độc lập với màu giao diện. |
| Cọ mặc định | Cỡ 1–1000 px, độ cứng/đậm 0–100%, Clone Stamp giữ độ lệch; áp dụng khi tạo/mở tài liệu tiếp theo. Vòng kích thước cọ có thể ẩn/hiện ngay trên tab hiện tại; icon từng công cụ được giữ. |
| Lưu và xuất tệp | Bản khôi phục mỗi 10/30/60 giây; định dạng PNG/JPEG, chất lượng JPEG 1–100 và khóa tỉ lệ mặc định cho hộp thoại Xuất mở tiếp theo. |

Cài đặt hiển thị không thay đổi model, nguồn ảnh, lịch sử hay pixel xuất. Đơn vị mm/cm/in trên thước biểu thị kích thước in theo PPI; để đo vật trong ảnh, dùng **Phân tích → Hiệu chuẩn đo**.

Bảo vệ khôi phục luôn bật. Chu kỳ mới bắt đầu từ lượt chờ tiếp theo, không xóa bản khôi phục đang có. Bản khôi phục chứa chỉnh sửa đã chốt; bản nháp đang kéo/nhập chưa phải điểm khôi phục. **Lưu** vẫn là cách lưu dự án chính thức.

Mặc định xuất chỉ điền hộp thoại **Tệp → Xuất ảnh…** (Cmd+Option+Shift+S), bạn vẫn đổi được cho từng lần xuất. PNG hỗ trợ alpha; JPEG có nền đục. Xuất bản chia sẻ điều tra giữ quy trình rà soát riêng. Giá trị JPEG chưa hợp lệ không được lưu; các lựa chọn hợp lệ khác vẫn có hiệu lực độc lập.

Trong **Phân tích**, sau khi chốt vùng OCR, dùng **Hủy nhận dạng chữ** nếu muốn dừng. Hủy trả lại các thao tác chỉnh sửa/phân tích và bỏ kết quả đến muộn. Nếu worker macOS chưa dừng xong, yêu cầu OCR mới báo rõ lý do; không tạo nhiều worker cùng lúc. Không có kết quả OCR chưa hoàn tất trong nhật ký. Hủy không xác nhận rằng tốc độ cold/warm của Vision đã đạt nghiệm thu trên mọi máy.

[Báo cáo kiểm thử và bản giao build 9](bao-cao/CAI_DAT_KIEM_THU_2026-10-04.md).
