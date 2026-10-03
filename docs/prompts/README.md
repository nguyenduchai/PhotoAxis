# PhotoAxis — Bộ prompt từ xây dựng đến public

**Cơ sở:** đặc tả 1.0-draft.3 đã duyệt. **Kênh public:** website/GitHub Releases. **Tình trạng:** bộ prompt đã sẵn sàng; các chặng xây dựng chưa chạy.

## Cách dùng

Mở đúng repository PhotoAxis trong công cụ lập trình, rồi dùng prompt khởi động dưới đây. Mỗi file P00–P16 là một prompt hoàn chỉnh có thể sao chép nguyên nội dung; các file tự yêu cầu đọc bối cảnh chung và tài liệu trong repo. Không cần dán lại đặc tả dài vào từng tin nhắn.

```text
Bắt đầu xây dựng PhotoAxis theo đặc tả 1.0-draft.3 đã được tôi duyệt.
Đọc docs/prompts/BOI_CANH_CHUNG.md và thực hiện đầy đủ
docs/prompts/00-khoi-tao-du-an.md trong repository hiện tại.
Hãy thực hiện công việc thực tế, kiểm tra đầu ra và cập nhật
docs/TIEN_DO_TRIEN_KHAI.md; không chỉ trả về kế hoạch.
```

Sau một chặng, dùng [prompt tiếp tục](TIEP_TUC.md), hoặc yêu cầu chạy file của chặng cụ thể. Nếu đổi task/công cụ, vẫn dùng cùng repo và trạng thái bàn giao. Không chạy các chặng phụ thuộc đồng thời trên cùng checkout. Người thực hiện có thể chia việc nội bộ khi được cho phép, nhưng đầu ra phải tích hợp và kiểm chứng trước khi đánh dấu chặng DONE.

P00–P14 chuẩn bị và kiểm tra. **P15 là prompt thực hiện public** khi đầu vào và kiểm tra đã đầy đủ. Việc soạn bộ prompt hiện tại không thực thi các hành động phát hành.

## Thứ tự thực hiện

| Prompt | Kết quả | Phụ thuộc | Nghiệm thu chính |
| --- | --- | --- | --- |
| [P00 — Nền dự án](00-khoi-tao-du-an.md) | Dự án Xcode build/chạy, kiến trúc và dữ liệu thử | Tài liệu đã duyệt | Nền cho A01–A43 |
| [P01 — Workspace và Việt/Anh](01-workspace-va-ngon-ngu.md) | Shell native, menu/panel, Settings ngôn ngữ | P00 | A01–A03, A40–A42 sơ bộ |
| [P02 — Tài liệu và canvas](02-tai-lieu-va-canvas.md) | Import/tab/render/zoom/pan | P01 | A04–A07, A09, A33/A35 phần nhập |
| [P03 — Layer, undo, transform](03-layer-undo-transform.md) | Layer thật, lệnh và biến đổi | P02 | A10–A11, A26 |
| [P04 — Crop và kích thước](04-crop-va-kich-thuoc.md) | Crop/Image Size/Canvas Size/rotate/flip | P03 | A12–A13 |
| [P05 — Perspective Crop](05-perspective-crop.md) | Bốn góc, grid, preview/apply trên ảnh đơn | P04 | A14–A17, A21 sơ bộ |
| [P06 — Text, Shape, Color](06-text-shape-color.md) | Chữ Việt và hình có thể sửa | P05 | A22–A24 |
| [P07 — Phối cảnh nhiều layer](07-phoi-canh-nhieu-layer.md) | Giữ loại layer, clip và chỉnh tiếp | P06 | A18–A19, A21 |
| [P08 — Điều chỉnh ảnh](08-dieu-chinh-anh.md) | Exposure/Brightness/Contrast/Saturation | P07 | A25 phần chỉnh/undo |
| [P09 — `.paxis`](09-dinh-dang-paxis.md) | Save/Open toàn dự án, ghi an toàn | P08 | A20/A25 phần lưu, A27–A28, A43 phần lưu |
| [P10 — Export](10-xuat-anh.md) | PNG/JPEG đúng hình học/màu/kích thước | P09 | A20/A43 phần xuất, A31–A33 |
| [P11 — Recovery và hoàn thiện](11-recovery-va-hoan-thien.md) | Vòng đời tài liệu, focus, bản dịch đầy đủ | P10 | A08, A29–A30, A34, A40–A42 đầy đủ |
| [P12 — Nghiệm thu và hiệu năng](12-nghiem-thu-va-hieu-nang.md) | Release Candidate có bằng chứng A01–A43 | P11 | Tất cả A01–A43, nhất là A35–A39 |
| [P13 — Ký và đóng gói](13-ky-va-dong-goi.md) | App/DMG ký, notarize, cài sạch | P12 + danh tính ký | R01–R08 liên quan |
| [P14 — Trang tải và tài liệu](14-trang-tai-va-tai-lieu.md) | Website/tài liệu/asset sẵn sàng public | P13 + thông tin phát hành | R09, R12; chuẩn bị R10 |
| [P15 — Public và hậu kiểm](15-public-va-hau-kiem.md) | Release public, website và bản tải được kiểm tra | P14 + quyền phát hành | R01–R12 đầy đủ |
| [P16 — Bảo trì và bản vá](16-bao-tri-va-ban-va.md) | Sửa lỗi/nâng patch khi có yêu cầu | Sau P15, khi cần | Hồi quy phần ảnh hưởng + Rxx |

P05 chỉ là mốc kỹ thuật ảnh đơn; chưa đáp ứng toàn bộ Perspective Crop V1.0 cho đến P07/P09/P10. P01 có thể kiểm tra khung dịch; A40–A42 chỉ hoàn tất sau khi mọi UI của các chức năng đã xuất hiện. Không đánh dấu một ca nhiều phần là PASS khi mới kiểm tra một phần.

## Hồ sơ luôn phải cập nhật

- [Đặc tả đã duyệt](../DAC_TA_V1.0.md): nguồn yêu cầu; chỉ thay đổi phạm vi khi người dùng yêu cầu.
- [Checklist A01–A43](../CHECKLIST_NGHIEM_THU_V1.0.md): kết quả chức năng và bằng chứng.
- [Phát hành và checklist R01–R12](../PHAT_HANH_PUBLIC.md): thông tin cần có, đóng gói và public.
- [Tiến độ](../TIEN_DO_TRIEN_KHAI.md): chặng đang làm, commit, blocker, chặng tiếp theo.
- `docs/bao-cao/Pxx.md`: người thực hiện tạo khi chạy mỗi chặng; không có báo cáo giả được điền trước.

Các giá trị Apple Team, bundle ID, GitHub repository, website và liên hệ hỗ trợ được lấy từ cấu hình thật hoặc hỏi khi cần; không có tài khoản/token mẫu để vô tình phát hành sai. Thiếu quyền ký vẫn tiếp tục được các chặng phát triển độc lập.
