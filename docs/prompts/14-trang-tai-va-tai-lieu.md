# P14 — Trang tải, hướng dẫn và hồ sơ public

Thực hiện P14 dựa trên app đã nghiệm thu và artifact P13. Đọc `docs/prompts/BOI_CANH_CHUNG.md`, `docs/PHAT_HANH_PUBLIC.md`, release manifest, known issues và báo cáo native. Có thể chuẩn bị nội dung độc lập nếu P13 đang chờ quyền ký; không đánh dấu sẵn sàng public khi artifact chưa đạt.

## Công việc

1. Xác định từ cấu hình/người dùng GitHub owner/repo, nguồn public/private, repo phân phối nếu tách, trang HTTPS, chủ thể và liên hệ hỗ trợ. Không tự đổi visibility hoặc công khai source. GitHub Pages là phương án đơn giản khi phù hợp tài khoản/repo; tái sử dụng hosting đã chọn nếu có.
2. Dựng trang giới thiệu/tải nhỏ gọn có Việt/Anh, responsive: PhotoAxis, macOS 14+/Apple Silicon, chức năng thực đã đạt, `.paxis`/PNG/JPEG, offline, ảnh giao diện thật, nút tải kèm version/architecture và link release/checksum. Không thêm dịch vụ tài khoản/backend nếu không cần.
3. Dùng ảnh native thật từ P11/P12, gồm Perspective Crop trước/sau và UI tiếng Việt. Không dùng mockup mô phỏng làm bằng chứng tính năng đã phát hành; không đưa logo/tài nguyên thương hiệu khác vào bộ cài/trang tải.
4. Viết hướng dẫn cài/mở, ngôn ngữ, import/layer/crop/perspective/text/Save/Export/recovery; phân biệt Save `.paxis` với export ảnh. Mô tả giới hạn thật, font thiếu, undo chỉ trong phiên, chưa có PSD/AI/Brush.
5. Chuẩn bị release notes vi/en, thông tin riêng tư đúng hành vi app/website, support, third-party notices và điều kiện sử dụng do chủ dự án chọn. Nếu chưa chốt license/giá/chủ thể, hỏi đúng phần thiếu, không tự cấp phép source hoặc tạo cam kết thương mại.
6. Chuẩn bị cấu hình deploy và nội dung release ở local; URL tải dự kiến phải trỏ tới release/asset cụ thể đã lên kế hoạch. Kiểm tra trang ở desktop/mobile, keyboard, link nội bộ và metadata; link chưa public ghi rõ chưa kiểm chứng.
7. Viết runbook ngừng giới thiệu bản lỗi, khôi phục link bản tốt nếu có và phát hành patch version mới. Với release đầu tiên, không bịa bản rollback.

## Hoàn thành khi

- Website preview và tài liệu đầy đủ, không còn nội dung mẫu trong phần sẽ public; R09 và phần chuẩn bị R12 có bằng chứng.
- Có release notes và `docs/KE_HOACH_PUBLIC.md` ghi target repo/tag/source SHA/assets/checksum/website, trạng thái quyền và các bước P15. Manifest app và website tách rõ.
- Nếu thông tin chủ thể/đích public chưa có, phần chuẩn bị vẫn được lưu; blocker cần bổ sung được nêu cụ thể. Không deploy hoặc publish ở P14.

Ghi `docs/bao-cao/P14.md`, cập nhật tiến độ/checklist public và bàn giao theo bối cảnh chung.
