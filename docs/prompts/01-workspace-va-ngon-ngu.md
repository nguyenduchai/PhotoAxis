# P01 — Workspace native và khung Việt/Anh

Thực hiện P01 sau khi xác minh P00. Đọc `docs/prompts/BOI_CANH_CHUNG.md`, đặc tả 1.0-draft.3, `docs/BO_MOCKUP_V1.0.md` và tiến độ. Giao diện chạy thật bằng AppKit; mockup chỉ để đối chiếu bố cục.

## Công việc

1. Dựng menu macOS, title bar, Options Bar, Tools một/hai cột, tab tài liệu, khu canvas/rulers/status, Color, Properties/History và Layers theo mục 4.1–4.2. Dùng controls native hoặc custom native phù hợp mật độ Photoshop, không dùng webview.
2. Hỗ trợ resize/thu gọn panel, lưu bố cục, Reset Workspace, trạng thái focus/hover/active/disabled và flyout. Phím Tab không ẩn panel khi đang nhập chữ. Chức năng chưa được làm ở chặng sau phải disabled, không tạo kết quả giả.
3. Tạo nguồn chuỗi vi/en và thuật ngữ thống nhất theo mục 4.3. Settings có Theo hệ thống/Tiếng Việt/English, ghi nhớ, áp dụng lần mở sau, thông báo rõ và không tự đóng app. Ngôn ngữ tài liệu và ngôn ngữ UI độc lập.
4. Welcome/New/Save/Export/Recovery ở chặng này chỉ dựng phần cấu trúc UI cần thiết; chỉ đánh dấu chức năng thật khi backend đã có. Hoàn thiện nhận diện PhotoAxis cho tên cửa sổ/menu; logo tạm phải được phân biệt với icon phát hành.
5. Đối chiếu visual ở 1440×900, 1280×800 và tối thiểu 1100×700 pt; cả vi/en. Giữ Apply/Cancel truy cập được khi Options Bar chật; không sửa phông quá nhỏ để nhét nhãn tiếng Việt.

## Hoàn thành khi

- Shell native vận hành, bố cục được lưu/khôi phục; Settings ngôn ngữ hoạt động và chuỗi đã triển khai có cả hai bản dịch.
- Có ảnh chụp native vi/en, mô tả sai khác và cách xử lý; icon/controls có accessibility labels.
- Đánh giá A01–A03 và phần hiện có của A40–A42; các ca phụ thuộc UI tương lai vẫn ghi chưa hoàn tất.

Ghi `docs/bao-cao/P01.md`, cập nhật tiến độ/checklist theo bằng chứng và bàn giao theo bối cảnh chung. Không coi một shell đẹp là ứng dụng V1.0 hoàn thành.
