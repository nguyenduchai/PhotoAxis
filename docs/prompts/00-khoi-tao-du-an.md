# P00 — Khởi tạo nền dự án PhotoAxis

Thực hiện P00 trong repository hiện tại. Trước khi sửa, đọc `docs/prompts/BOI_CANH_CHUNG.md`, `docs/DAC_TA_V1.0.md`, checklist, tài liệu public và tiến độ. Đặc tả 1.0-draft.3 đã được duyệt; hãy triển khai công việc, không chỉ đề xuất kế hoạch.

## Công việc

1. Kiểm tra Git/remote/nhánh/thay đổi hiện có, Xcode được chọn, SDK/macOS/CPU và công cụ build/test. Repo có thể đã được triển khai một phần; tiếp tục từ đó. Không reset hoặc init lại Git. Ghi đúng trở ngại môi trường nếu có.
2. Tạo hoặc hoàn thiện dự án Xcode **PhotoAxis**, macOS 14+, arm64, Swift/AppKit; app mở cửa sổ native. Có shared scheme, Debug/Release, cấu trúc test và lệnh build từ terminal. Bản chạy local không phụ thuộc chứng thư public.
3. Phân chia DocumentModel, Commands/Undo, Renderer, Geometry, Tools, NativeWorkspace, Localization, Persistence, Export. Đặt hợp đồng tọa độ document/view/device, ma trận layer, clip, color/alpha và background jobs; chưa viết engine dư thừa.
4. Tạo quyết định kiến trúc và kế hoạch fixture: lưới bốn góc màu khác nhau, alpha edges, JPEG EXIF, sRGB/P3, tiếng Việt, dự án nhiều layer, file lỗi. Dữ liệu thử phải tự tạo hoặc có nguồn sử dụng rõ.
5. Tạo `.gitignore`, hướng dẫn build/test, script kiểm tra tối thiểu và cấu hình CI macOS phù hợp repo/toolchain. Build/test phát triển không cần secret ký; workflow release không tự public chỉ vì push/tag. Ghim dependency cần thiết, ghi license; chỉ thêm khi có nhu cầu cụ thể. Không phụ thuộc package không dùng.
6. Ghi đầu vào phát hành đang biết trong `docs/PHAT_HANH_PUBLIC.md`. Nếu bundle ID/Team/GitHub owner chưa có, nêu rõ cấu hình phát triển tạm và phần phải đổi trước release; không tự tạo danh tính công khai. Thu thập thông tin thiếu mà không chặn build local độc lập.

## Hoàn thành khi

- App native build và mở được trên máy hiện tại; có log lệnh, cấu hình và ảnh cửa sổ.
- Có `docs/KIEN_TRUC.md`, `docs/QUYET_DINH_KY_THUAT.md`, hướng dẫn build và quy ước fixture; các hợp đồng cần cho perspective/layer/save không mâu thuẫn đặc tả.
- Một kiểm tra có ý nghĩa cho phần model/geometry đã tồn tại chạy được; không tạo hàng loạt test hình thức khi chưa có chức năng.

Ghi `docs/bao-cao/P00.md`, cập nhật tiến độ, commit local nếu cấu hình Git cho phép và bàn giao theo bối cảnh chung. Không phát hành hoặc tự tạo remote.
