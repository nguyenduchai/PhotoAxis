# Xử lý bản scan tài liệu

Có từ bản phát triển PhotoAxis1.0.0(4). [Đặc tả/phạm vi](DAC_TA_SCAN.md), [báo cáo kiểm chứng](bao-cao/SCAN_2026-10-03.md). Ứng dụng giữ nguồn nhúng; kết quả làm đẹp là tham số và hình học của bản làm việc.

## Một trang

1. Mở ảnh, chọn layer ảnh không khóa; vào **Ảnh → Xử lý bản scan…** (English: **Image → Document Scan…**).
2. **Phát hiện trang** tìm bốn góc, viền cam biểu diễn vùng giữ. Rà soát trước Apply. Nếu biên sai, xóa vùng hoặc Cancel, dùng Perspective Crop đặt góc thủ công rồi mở Scan lại.
3. **Căn thẳng chữ** tìm hướng dòng; có thể nhập góc±15°. Ảnh trắng/thiếu dòng sẽ báo không tìm thấy. Sau nắn phối cảnh thường không cần thêm góc.
4. Chọn **Màu / Thang xám / Đen trắng**. Tăng làm trắng giấy để giảm bóng và ám màu; giảm nhiễu và độ nét dùng vừa phải. Với đen trắng, tăng ngưỡng giữ nhiều nét mực hơn; thay vùng nền cục bộ rồi kiểm chữ mảnh/chữ ký/con dấu.
5. Chỉnh **Cong ngang / Cong dọc** bằng mắt để căn dòng cong của trang sách. Mô hình này sửa dạng bow theo hai trục, chưa tự sửa mọi trang sách3D/nếp gấp. Kiểm chú thích trên layer khác sau chỉnh cong.
6. Chọn Original/A4dọc/A4ngang/Letter hoặc pixel tự nhập, PPI36–1200. Nội dung được fit giữ tỷ lệ và căn giữa; viền trống trong project là alpha. Khi Export PNG cần giấy trắng, tắt transparency; JPEG có nền trắng mặc định. Kích thước/PPI không bổ sung chi tiết đã thiếu từ ảnh chụp.
7. Chọn **Xem trước** sau thay đổi; **Áp dụng** chỉ bật khi candidate hợp lệ. Một Apply tạo một bước Undo/Redo; Cancel bỏ bản nháp. Save `.paxis` giữ nguồn và tham số để mở/chỉnh tiếp trên build4 trở lên.

## Nhiều trang

Vào **Ảnh → Xử lý scan hàng loạt…** (English: **Image → Batch Document Scan…**), chọn1–50ảnh PNG/JPEG/HEIC/HEIF. Hộp Scan ghi tên **Trang mẫu**; preview chỉ minh họa trang này. Danh sách trang có nút lên/xuống để quyết định thứ tự PNG/project/PDF. Các checkbox phát hiện trang/căn thẳng chữ áp dụng riêng cho từng trang, không sao chép góc phát hiện từ trang mẫu.

Đặt tham số chung, chọn Xem trước rồi **Chạy hàng loạt**, chọn thư mục cha. App tạo thư mục mới `PhotoAxis-Scan-UUID`; không ghi đè input. Controls khóa khi xử lý. Cancel được kiểm giữa các tác vụ framework; một thao tác Vision/GPU/Image I/O đang chạy có thể cần kết thúc trước khi nhận hủy.

```text
PhotoAxis-Scan-UUID/
  pages/0001.png …        ảnh sRGB đục, kích thước/PPI đã chọn
  projects/0001.paxis …   project riêng, chứa byte nguồn và tham số
  pages.pdf              một trang/ảnh theo pixel ÷ PPI × 72 point
  manifest.json          tham số, thứ tự, góc, cảnh báo và SHA-256
```

Rà soát **mọi trang** trước sử dụng. Manifest ghi `requiresReview=true` kể cả khi Vision có confidence cao. Cảnh báo không tìm thấy trang/góc cần kiểm crop/góc và kết quả bằng mắt. Lỗi hoặc Cancel không công bố lô dở dang; crash/mất điện có thể để lại `.PhotoAxis-Scan-UUID` ẩn chưa hoàn tất, không xem là đầu ra thành công.

## Bảo toàn và chia sẻ

`.paxis` giữ byte nguồn, có thể chứa GPS và pixel đã crop. Crop/làm trắng không xóa dữ liệu nguồn nhúng. PNG/PDF batch là bản raster làm việc; chưa phải bản hồ sơ đã che/rà soát. Không chia sẻ project hoặc manifest như bản đã loại dữ liệu riêng tư.

Trong hồ sơ `.paxcase`, Scan trên ảnh working được ghi command/model vào nhật ký; sửa model làm rà soát và chuẩn đo trước đó không còn phù hợp. Dùng luồng **bản chia sẻ PNG/PDF A4 đã rà soát** của gói điều tra khi cần che dữ liệu. Batch ngoài hồ sơ không thay intake/chain-of-custody. [Hướng dẫn điều tra](HUONG_DAN_DIEU_TRA.md).

File không Scan vẫn schema1/2; file có Scan là schema3. Build3 trở về trước từ chối schema3 để tránh mất hiệu ứng khi mở/lưu. Undo History không lưu qua lần mở lại; metadata Scan vẫn được giữ.
