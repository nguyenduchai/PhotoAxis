# P03 — Layer, Undo/History và Move/Transform

Thực hiện P03 sau P02. Đọc `docs/prompts/BOI_CANH_CHUNG.md`, đặc tả mục 6–7, 12.1, 14–16 và checklist.

## Công việc

1. Layers có thumbnail, type, selection, rename, reorder, visibility, lock, opacity, duplicate/delete. Chọn một layer; Auto-Select bỏ qua layer ẩn/khóa. Khóa chặn thao tác trực tiếp đúng phạm vi, vẫn cho ẩn/hiện/chọn để mở khóa.
2. Renderer composite theo thứ tự layer, Normal/opacity/alpha; duplicate dùng chung nguồn immutable nhưng tham số riêng. Dùng mã định danh ổn định, không lấy index UI làm identity.
3. Commands/UndoManager với transaction cho gesture: một lần kéo/nhập rồi commit = một bước. Hủy phiên không làm thay đổi trạng thái đã commit. Saved marker, nhánh redo và History đúng; giới hạn 100 bước/128 MiB mà không sao chép toàn ảnh mỗi lần.
4. Move/arrow/Shift-arrow và Free Transform scale/rotate/flip/X/Y/W/H, liên kết tỷ lệ, các modifier và Apply/Cancel theo đặc tả. Dựng nền affine/projective dùng chung để P07 không phải viết lại engine.
5. Hit-test và handles dùng tọa độ đúng khi zoom/pan/Retina. Control gọn, nhập số theo locale; phím tắt không nuốt văn bản/IME. Chuỗi tên command hiển thị theo ngôn ngữ nhưng command ID không phụ thuộc bản dịch.

## Hoàn thành khi

- A10–A11 đạt trên layer ảnh; phần dành cho text/shape bổ sung P06/P07. Kiểm tra undo reorder/delete/duplicate/lock và transform nhiều lần.
- A26 kiểm tra lịch sử, redo bị cắt khi tạo nhánh mới, saved marker với model hiện có; hoàn thiện saved marker với Save thật ở P09.
- Có ảnh/video ngắn hoặc chuỗi ảnh thể hiện transform thật; test model/geometry cho lock, nguồn dùng chung và transaction rollback.

Ghi `docs/bao-cao/P03.md`, cập nhật tiến độ và checklist theo phạm vi bằng chứng, bàn giao theo bối cảnh chung.
