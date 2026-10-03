# PhotoAxis Scan 1 — phần mở rộng bản scan

Người dùng giao bổ sung chức năng còn thiếu ngày 03/10/2026. Phần mở rộng thuộc bản phát triển **1.0.0 (4)**, tách khỏi baseline 1.0-draft.3. Native AppKit/Core Image/Metal/Vision, xử lý offline, không tái tạo nội dung bằng dịch vụ AI. [Hướng dẫn](HUONG_DAN_SCAN.md), [kết quả kiểm chứng](bao-cao/SCAN_2026-10-03.md).

| ID | Chức năng đã triển khai | Hợp đồng và giới hạn |
| --- | --- | --- |
| S01 | Phát hiện bốn góc trang và Perspective Crop | Vision rectangles revision1; phân tích preview tối đa1600px, confidence≥0,6, vùng bao≥20% ảnh; dùng tứ giác hợp lệ lớn nhất theo area×confidence. Giao diện vẽ viền cam để rà soát, không Apply khi không tìm thấy trang hợp lệ. |
| S02 | Căn thẳng dòng chữ và góc thủ công | Vision text rectangles cần ít nhất3dòng rộng hơn10% ảnh, đồng thuận quanh median trong2°; giới hạn±15°. Batch chỉ fallback text-angle khi không có quad và không có góc thủ công. |
| S03 | Làm sạch nền giấy | Color/Gray/BlackWhite, làm trắng và giảm bóng/ám màu bằng chuẩn hóa nền cục bộ linear-sRGB; giảm nhiễu, unsharp và ngưỡng đen trắng thích nghi. Giữ alpha. Tắt nhóm bypass render, vẫn giữ tham số. |
| S04 | Nắn cong trang theo hai trục | Người dùng chỉnh curveX/curveY trong−1…1; warp giữ biên bằng mô hình bow hữu hạn. Đây là chỉnh cong thủ công, chưa tự dựng bề mặt3D sách, sửa mọi nếp gấp hoặc phục hồi chữ khuất. |
| S05 | Chuẩn hóa kích thước/PPI | Original/A4dọc/A4ngang/Letter/custompixel, PPI36…1200; fit giữ tỷ lệ và căn giữa. Giới hạn8000px/cạnh và40MP. Viền project trong suốt; batch xuất nền trắng. PPI không tạo thêm chi tiết nguồn. |
| S06 | Preview, Apply/Cancel và dữ liệu editable | Trước/sau; thay tham số bắt buộc preview lại; một Apply tạo một bước Undo. Scan chỉ trên image không khóa. Hình học toàn tài liệu vẫn giữ loại layer/chữ/hình; nguồn nhúng không đổi. Duplicate sao chép Scan metadata. |
| S07 | Xử lý nhiều trang | 1–50ảnh PNG/JPEG/HEIC/HEIF, thứ tự có thể đổi; mỗi trang phân tích riêng, dùng chung tham số. Preview chỉ là trang mẫu. Xử lý tuần tự, nhả cache giữa trang; input quá quota bị từ chối, không tự giảm chất lượng. Chưa nhập PDF/TIFF hoặc OCR hàng loạt. |
| S08 | Đầu ra một lô | Thư mục mới chứa PNG sRGB nền trắng, project nguồn riêng từng trang, PDF một ảnh/trang và manifest. Ghi settings/OS/build/góc/kích thước/confidence/warnings/source-outputSHA; mọi trang requiresReview=true. Chỉ công bố thư mục sau tất cả đầu ra thành công. Lỗi/Cancel dọn staging; mất điện/crash có thể để lại staging ẩn. |
| S09 | Tích hợp hồ sơ và schema | Scan là command bền vững trong hồ sơ, làm rà soát cũ mất hiệu lực khi model đổi. `.paxis` có Scan dùng schema3; không Scan giữ1thường/2working. Reader mới đọc1/2/3; reader cũ phải từ chối3. Batch độc lập không thay quy trình bảo quản hồ sơ. |

Pipeline: nguồn chuẩn hóa → điều chỉnh ảnh có sẵn → clip local → Scan cleanup/bow → clip lại → transform/opacity/composite. Clip lại ngăn warp hồi sinh pixel đã loại. Text/shape vẫn editable; chú thích trên layer khác không tự uốn theo bow của image, cần rà vị trí sau sửa.

Phạm vi DONE local chỉ áp dụng fixture và máy đã thử. Bộ ảnh chụp giấy/sách thực, chữ ký/mực mảnh/nền thấp tương phản, đủ50trang ở quota tối đa, thời gian/nativeFPS và máy macOS14/M1-16GB chưa được nghiệm thu. Không tự nâng các ca A01–A43 hoặc gate phát hành thành PASS từ phần mở rộng này.
