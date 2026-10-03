# P10 — Export PNG/JPEG và tính nhất quán màu

Thực hiện P10 sau P09. Đọc `docs/prompts/BOI_CANH_CHUNG.md`, đặc tả mục 13, hợp đồng renderer/persistence và checklist.

## Công việc

1. Hộp thoại Export native: preview, PNG/JPEG, Width/Height, giữ tỷ lệ mặc định, PPI, PNG transparency/nền đặc, JPEG Quality 1–100 và matte mặc định trắng có chọn màu.
2. Render từ snapshot model/source đầy đủ, đúng transform/projective clip/adjustments và thứ tự các layer đang hiển thị. Không dùng bitmap độ phân giải preview, không xuất overlay/selection/grid.
3. Xuất sRGB 8 bit/kênh bằng Image I/O, ICC/PPI đúng, alpha PNG đúng và JPEG flatten lên matte đúng. Loại GPS/metadata nguồn không cần thiết; xử lý premultiplied alpha tránh viền sai.
4. Xuất nền, có progress/cancel ở điểm an toàn; ghi tạm/thay đích an toàn, native overwrite confirmation. Không để file đích dở dang khi hủy/lỗi và không đánh dấu dự án đã Save sau Export.
5. Kích thước xuất khác kích thước canvas chỉ ảnh hưởng ảnh đầu ra. Input sai/vượt giới hạn chặn trước cấp phát. Giải quyết phiên crop/transform/text chưa commit theo đặc tả trước khi chụp snapshot.

## Hoàn thành khi

- A31–A33 đạt với inspect metadata, pixel/dimensions, ICC/alpha/matte, orientation và GPS fixture; có kiểm tra reference render với dung sai đã giải thích.
- Hoàn tất A20 và A43 với chuỗi crop nhiều layer → Save/Close/Open → chỉnh tiếp → Export, đổi UI vi/en; xác nhận chữ/shape vẫn sửa được trong dự án.
- Hủy/lỗi/overwrite, nguồn không đổi và dấu chưa lưu không bị xóa được kiểm tra thực tế.

Ghi `docs/bao-cao/P10.md`, cập nhật tiến độ/checklist và bàn giao theo bối cảnh chung.
