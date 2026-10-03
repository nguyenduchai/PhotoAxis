# P16 — Bảo trì hoặc phát hành bản vá khi được yêu cầu

Thực hiện prompt này khi người dùng đã yêu cầu xử lý một lỗi/công việc bảo trì cụ thể sau public. Đọc `docs/prompts/BOI_CANH_CHUNG.md`, trạng thái release thực tế, manifest, runbook và báo cáo P15. Nếu chưa có lỗi/yêu cầu cụ thể, hỏi thông tin cần thiết; không tự phát hành một phiên bản mới.

## Công việc

1. Xác minh phiên bản/OS/kiến trúc, bước tái hiện và phạm vi ảnh hưởng; dùng log/fixture được phép truy cập, không yêu cầu gửi dự án cá nhân khi fixture tối giản đủ. Phân loại lỗi dữ liệu, ảnh xuất, crash, UI hoặc phân phối.
2. Tái hiện và tìm nguyên nhân, thêm regression phù hợp, sửa đúng phạm vi. Giữ tương thích `.paxis` và dữ liệu người dùng; thay schema phải có quyết định và phương án rõ, không âm thầm phá file cũ.
3. Chạy kiểm tra phần ảnh hưởng cùng luồng lưu/mở/xuất, ngôn ngữ và bản đóng gói. Nếu lỗi nghiêm trọng, thực hiện biện pháp ngừng giới thiệu/khôi phục link được runbook và yêu cầu người dùng cho phép; không xóa tag/binary để che lịch sử.
4. Khi yêu cầu bao gồm phát hành bản vá, tăng patch version/build, chốt source commit, cập nhật release notes và lặp các bước P13–P15 cho version mới. Không tái sử dụng checksum/notary kết luận của artifact cũ.
5. Tải lại bản public mới, xác minh checksum/Gatekeeper, thử lỗi đã sửa và xác nhận đường nâng cấp không làm mất dự án. Nếu chỉ được yêu cầu sửa local, bàn giao bản sửa/báo cáo và giữ publish ngoài phạm vi đó.

## Bàn giao

Ghi báo cáo theo version/lỗi, nguyên nhân, thay đổi, kiểm thử, ảnh hưởng dữ liệu, commit và link public nếu đã phát hành. Cập nhật tiến độ/manifest/known issues. Không tự tạo lịch monitor hoặc gửi thông báo cho người khác; cần yêu cầu riêng cho các hoạt động đó.
