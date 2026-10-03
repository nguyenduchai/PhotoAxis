# P15 — Phát hành PhotoAxis 1.0.0 và kiểm tra public

Thực hiện phát hành PhotoAxis 1.0.0 qua website/GitHub Releases đã chọn. Việc tôi gửi prompt này là yêu cầu thực hiện public bản đã chuẩn bị khi các điều kiện dưới đây đạt; không cần hỏi lại kênh hoặc đặc tả đã duyệt.

Đọc `docs/prompts/BOI_CANH_CHUNG.md`, `docs/PHAT_HANH_PUBLIC.md`, `docs/KE_HOACH_PUBLIC.md`, release manifest, báo cáo P12–P14 và tiến độ. Kiểm tra tài liệu GitHub/Apple chính thức hiện hành khi dùng công cụ phát hành.

## Trước khi public

1. Xác minh R01–R09, kế hoạch xử lý sự cố R12 và target repo/website thực tế. R10–R11 sẽ kiểm tra sau publish. Không công khai source private hoặc thay visibility để “sửa nhanh” quyền tải.
2. Xác minh commit/tag/version/build và artifact/hash; checkout dùng build không còn thay đổi source/config chưa commit. Không rebuild hoặc sửa bộ cài đã ký mà vẫn dùng checksum cũ; nếu artifact/code đổi, quay về phần nghiệm thu/ký liên quan. Source repo và distribution repo nếu tách phải được ghi quan hệ trong manifest.
3. Kiểm tra quyền đăng nhập hiện có. Nếu thiếu thông tin hoặc quyền cản bước cụ thể, yêu cầu phần cần thiết, hoàn thành các bước độc lập và không báo đã public.

## Thực hiện

1. Push commit/tag cần thiết tới đúng repo đã xác định sau khi kiểm tra không lẫn secret/file cá nhân. Không force-push hoặc dời tag đã public. Kiểm tra CI của commit phát hành nếu repo có CI và xử lý lỗi trước publish. Tạo draft release `v1.0.0` tại đúng target, gắn DMG, `SHA256SUMS.txt`, release notes và file người dùng cần.
2. Đối chiếu asset draft với manifest và chữ ký/notarization trước publish. Nếu release đã tồn tại, đọc trạng thái/asset trước để tiếp tục idempotently; không tạo trùng hay ghi đè binary dưới tag cũ.
3. Publish release và deploy trang tải bằng cấu hình đã chuẩn bị. Gắn URL asset versioned, hiển thị đúng yêu cầu hệ thống/version, cập nhật latest khi phù hợp. Không gửi email/tin nhắn quảng bá hoặc đăng mạng xã hội ngoài yêu cầu này.

## Hậu kiểm bắt buộc

- Truy cập trang và tải asset bằng phiên ẩn danh, kiểm tra HTTPS/redirect/404; file không yêu cầu tài khoản người dùng.
- Tải lại DMG từ URL public, so SHA-256, ký/staple và version; cài/mở bản tải này theo luồng Gatekeeper bình thường. Không lấy bản local thay cho bản public để kết luận.
- Kiểm tra tối thiểu `.paxis` mở/lưu lại, phối cảnh, chữ Việt, PNG/JPEG và offline; đối chiếu source SHA/tag/manifest/website/release.
- Nếu lỗi, sửa cấu hình/link trong phạm vi hoặc ngừng giới thiệu bản lỗi theo runbook; không tiếp tục báo thành công khi download/hành vi chính thất bại. Binary cần thay thì dùng version mới với luồng ký/kiểm tra mới.

## Hoàn thành khi

R01–R12 có bằng chứng và PhotoAxis tải/cài/dùng được theo phạm vi đã kiểm chứng. Ghi `docs/bao-cao/P15.md`, URL website/release/asset, SHA-256, version/build, các commit liên quan, kết quả hậu kiểm và hạn chế thực tế. Cập nhật tiến độ DONE chỉ khi đã đạt; không hứa đã kiểm tra trên máy/OS không có. Bàn giao link sử dụng được cho người dùng.
