# P09 — PhotoAxis Document `.paxis` và Save/Open an toàn

Thực hiện P09 sau P08. Đọc `docs/prompts/BOI_CANH_CHUNG.md`, đặc tả mục 12.1–12.2, toàn bộ contract nguồn/transform/clip và checklist. `.paxis` phải là một file ZIP, không phải thư mục package.

## Công việc

1. Viết đặc tả schema version 1: `document.json` với định danh `photoaxis.document`, `assets/` nguồn nhúng và `preview.png`. Serialize đủ canvas/PPI, layer IDs/order/type/name, text/font/shape, chỉnh màu, opacity/visibility/lock, transform/clip. Đơn vị/hệ tọa độ/ma trận có định nghĩa rõ.
2. Giữ nguồn ảnh không tái mã hóa mất dữ liệu khi đóng gói; nguồn dùng chung được deduplicate theo identity phù hợp. File không phụ thuộc URL ảnh nhập ban đầu hoặc cài đặt ngôn ngữ UI.
3. Open kiểm tra định danh/schema, số lượng/size, đường dẫn, tài nguyên tham chiếu, giá trị không hữu hạn và giới hạn giải nén. Từ chối path traversal, symlink thoát vùng làm việc, tên mục trùng/không hợp lệ và archive hỏng; không giải nén không giới hạn rồi mới kiểm tra.
4. Save/Save As với snapshot nhất quán, ghi tạm cùng vùng phù hợp rồi thay thế an toàn. Quản lý edit phát sinh trong lúc save: chỉ đặt saved marker của revision thực đã ghi, không xóa dấu sửa mới. Lỗi/quyền/hết dung lượng/hủy giữ bản lưu tốt trước đó.
5. Đăng ký document type/UTI phù hợp danh tính app, mở từ Finder; format version mới hơn có lỗi rõ và không bị ghi đè. Undo history không lưu qua phiên; trạng thái hình học/chỉnh tiếp phải lưu đầy đủ.
6. Tạo fixture `.paxis` và hướng dẫn schema độc lập với UI; kiểm tra đọc/lưu không thực thi nội dung từ file. Bản định dạng tài liệu phải có đủ thông tin cho round-trip và nâng version về sau.

## Hoàn thành khi

- A27–A28 đạt, gồm sao chép file và bỏ quyền nguồn ban đầu; thử lỗi ghi có kiểm soát trên fixture, không trên file người dùng.
- A20/A25 phần Save→Close→Open giữ model/render/chỉnh tiếp; A43 phần đổi ngôn ngữ không đổi nội dung đạt. Export cuối kiểm tra ở P10.
- Có so sánh model chuẩn hóa và render trong dung sai; không đòi ZIP phải giống từng byte vì metadata container có thể đổi.

Ghi `docs/DINH_DANG_PAXIS.md`, `docs/bao-cao/P09.md`, cập nhật tiến độ/checklist và bàn giao theo bối cảnh chung.
