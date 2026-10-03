# P11 — Recovery, vòng đời tài liệu và hoàn thiện UI Việt/Anh

Thực hiện P11 sau P10. Đọc `docs/prompts/BOI_CANH_CHUNG.md`, đặc tả mục 4.3, 5.3, 12.3, 14–15 và checklist.

## Công việc

1. Recovery riêng sau thay đổi đã commit, tối đa 30 giây giữa hai bản hoàn tất khi hệ thống hoạt động bình thường. Viết snapshot an toàn, có revision; không ghi đè file dự án, không đổi saved marker và không chứa phiên công cụ/text chưa commit.
2. Khởi động sau sự cố có danh sách tên/thời gian và Open Recovered/Discard. Mở recovery tạo tài liệu chưa lưu cần Save As. Dọn đúng revision sau Save; thay đổi mới trong lúc Save vẫn cần recovery. Don't Save dọn recovery tương ứng.
3. Lỗi recovery báo một lần với trạng thái rõ; lỗi một file không gây vòng lặp alert/không mở được app. Thử crash bằng tiến trình/fixture có kiểm soát, không kill phiên làm việc cá nhân.
4. Hoàn thiện close-tab/quit nhiều tài liệu, Save/Don't Save/Cancel, các phiên crop/transform/text chưa chốt, tác vụ nền đang ghi/xuất và đổi tab. Cancel không mất dữ liệu, mở lại không phục hồi thứ đã chủ động bỏ.
5. Rà tất cả keyboard/focus/IME, menu validation/accessibility. Đủ vi/en cho mọi chức năng đã có, kể cả lỗi sâu, History và progress. Settings giữ lựa chọn sau restart; không đổi nội dung `.paxis`.
6. Kiểm tra locale số/ngày, overflow nhãn Việt ở kích thước tối thiểu, tài liệu hỗ trợ font và hình học. Loại nút giả và placeholder không thuộc bản phát hành.

## Hoàn thành khi

- A08, A29–A30, A34 và A40–A42 đạt với bằng chứng native/khởi động lại/lỗi được mô phỏng có kiểm soát.
- Luồng save đang chạy + edit mới + đóng/crash có trạng thái đúng; phiên crop chưa commit không được quảng bá là có recovery.
- Có ảnh chụp UI vi/en đủ các màn hình thực tế, ghi nhận khác biệt hợp lý so mockup trong báo cáo.

Ghi `docs/bao-cao/P11.md`, cập nhật tiến độ/checklist và bàn giao theo bối cảnh chung.
