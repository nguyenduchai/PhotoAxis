# PhotoAxis

**Build5 — workspace tích hợp:** chức năng điều tra đã hợp nhất vào Nguồn/Phân tích/Đầu ra bên cạnh bảng Chỉnh sửa. Không còn menu/cửa sổ/form modal Điều tra riêng. Chọn ROI/điểm trên canvas, đối chiếu và OCR review cùng cửa sổ. Full168ca164PASS/1knownTelexFAIL/3benchmarkSKIP;9ca mớiPASS, Release/nativeVIEN scopedPASS. [Báo cáo và giới hạn](docs/bao-cao/HOP_NHAT_WORKSPACE_2026-10-03.md), [hướng dẫn](docs/HUONG_DAN_DIEU_TRA.md).

Ứng dụng chỉnh sửa ảnh native trên macOS, có layer editable, Perspective Crop và bộ công cụ rà soát ảnh/hồ sơ.

[Website Việt/Anh](https://nguyenduchai.github.io/PhotoAxis/) · [Mã nguồn](https://github.com/nguyenduchai/PhotoAxis) · [Báo lỗi](https://github.com/nguyenduchai/PhotoAxis/issues)

**Giấy phép: GNU GPL phiên bản 3 (GPL-3.0-only).** Copyright (C) 2026 PhotoAxis contributors. Bạn có thể phân phối lại và sửa đổi theo GNU General Public License phiên bản 3 do Free Software Foundation công bố. Phần mềm được cung cấp không có bảo đảm, kể cả bảo đảm về khả năng thương mại hoặc phù hợp một mục đích cụ thể. Xem [toàn văn LICENSE](LICENSE). Framework hệ thống và tài nguyên bên ngoài theo điều khoản của chủ sở hữu tương ứng.

**Mới trong build4 — Scan1:** phát hiện trang/góc chữ, làm trắng giấy/giảm bóng và nhiễu/làm rõ chữ/đen trắng thích nghi; nắn cong hai trục thủ công; A4/Letter/custom/PPI; batch1–50ảnh xuất PNG/project giữ nguồn/PDF/manifest. Preview trước/sau, Apply một Undo, Save/Open schema3 và audit hồ sơ. Fullsuite cuối **155PASS/1FAILTelex/3SKIP**,11caScan mớiPASS; Release/localcodesignPASS,16policytestsPASS. [Hướng dẫn Scan](docs/HUONG_DAN_SCAN.md), [đặc tả](docs/DAC_TA_SCAN.md), [báo cáo/bằng chứng](docs/bao-cao/SCAN_2026-10-03.md). Chưa tự dựng3D mọi trang sách hoặc qualification bộ camera/sách/fullquota; bộ cài stable public vẫn chờ gate.

Repo public bắt đầu từ snapshot source build 3; lịch sử triển khai trước khi công khai giữ local trên nhánh `local/implementation-history`. Mã commit cũ trong bằng chứng là provenance lịch sử, không phải commit của nhánh public. Ảnh Adobe nội bộ không được đưa vào snapshot public.

**Kiểm tra source build3 khi công khai (lịch sử):** đã sửa tương thích UndoManager với Xcode16.4 và điều kiện API HDR SDK26. Local fullsuite mới144PASS/1FAILTelex/3SKIP; Release mới build/codesignPASS, CI GitHub Xcode16.4/macOS15.7.9:143PASS/0FAIL/5SKIP, Debug/test và ReleasePASS. HDR/bố cục riêng trênMaclocal2PASS/0FAIL/0SKIP. CIskip3benchmark/IME/màn hình lớn không thay các gate này. Đây vẫn là bản phát triển; xem báo cáo để phân biệt evidence lịch sử và binary cuối.

**Phân phối build3 trước Scan (lịch sử):** website và mã nguồn công khai; bản DMG build 3 đã xuất để kiểm thử local, chưa Developer ID/notarized. Nút tải bộ cài public còn tắt. [Báo cáo Pages và DMG](docs/bao-cao/GITHUB_PAGES_DMG_2026-10-03.md).

**Trạng thái:** ứng dụng native đã triển khai luồng chỉnh ảnh, Perspective Crop nhiều layer giữ editable, Type/Shape, điều chỉnh ảnh, Save/Open `.paxis`, Export PNG/JPEG và recovery. Version/build local **1.0.0 (5)**; baseline **1.0-draft.3**. P12–P15 đã có nghiệm thu/benchmark local, icon/archive/DMG local, website và công cụ phát hành; các chặng phát hành vẫn chưa đóng đầy đủ ở nghiệm thu native tổng thể/IME/thiết bị/ký/cài sạch. Target mã nguồn và website đã chốt GitHub/GitHub Pages. Xem [tiến độ thực tế](docs/TIEN_DO_TRIEN_KHAI.md), [ma trận 43 ca](docs/MA_TRAN_NGHIEM_THU.md) và [báo cáo P12](docs/bao-cao/P12.md).

Nghiệm thu bổ sung03/10: **19/43 PASS**, chốt A04/A07/A26 bằng nativeVI/EN build3; benchmark mới3PASS. Telex VI có nhập/lưu/hủy thực, nhưng A22 chưa hoàn tấtEN/VNI. [Báo cáo và bằng chứng mới](docs/bao-cao/P12-native2.md).

Gói điều tra giữ file tiếp nhận đúng byte/metadata/hash riêng, working copy và nhật ký bền vững, quản lý bộ ảnh/chú thích/so sánh nguồn, xuất PDF A4 và bản PNG/PDF chia sẻ có vùng che đã rà soát. Hash kiểm toàn vẹn, không xác nhận nguồn gốc/thời gian. Đã thêm OCR tiếng Việt trên ROI nguồn, bản máy/các xác nhận riêng; video nguồn/khung hình có ordinal–PTS/hash và offset có căn cứ; đo đoạn/diện tích với thước chuẩn/đơn vị/điều kiện hình học. JSON phân tích riêng chứa thông tin nguồn chưa che. [Báo cáo mở rộng](docs/bao-cao/MO_RONG_DIEU_TRA.md).

Giao diện Tiếng Việt/English, có Theo hệ thống và áp dụng lựa chọn lần mở sau. Nội dung/layer/thông số trong dự án không phụ thuộc ngôn ngữ UI. `.paxis` là một file ZIP tự chứa nguồn nhúng và layer editable; PNG/JPEG là ảnh xuất phẳng. App chạy offline, không có tài khoản/cloud/telemetry/AI.

Bản mở rộng Investigation2 source0169bf5 có **144PASS/0FAIL/4SKIP**, Release/ad-hoc và DMG local build3 PASS; native VI OCR/xác nhận/đo/frame/JSON và EN mở/đọc/xác nhận/verify đã kiểm. [Toàn bộ tiến độ/public](docs/bao-cao/TONG_TIEN_DO_VA_PUBLIC_2026-10-02.md), [gói điều tra1 lịch sử](docs/bao-cao/GOI_DIEU_TRA.md), [hướng dẫn](docs/HUONG_DAN_DIEU_TRA.md). Còn Telex/VNI, native tổng thể/macOS14/non-Retina/M1-16GB/hiệu năng/quota và qualification dữ liệu thực/OCR/codec/hình học. Chưa DeveloperID/notarization hoặc bộ cài public; hiện19/43ca PASS,24ca chưa đóng. Không suy chứng nhận phát hành từ test xanh.

```sh
./scripts/check.sh
./scripts/build.sh Debug
open PhotoAxis.xcodeproj
```

- [Build/test, mở app và cấu hình máy](docs/HUONG_DAN_BUILD.md)
- [Kiến trúc và hợp đồng tọa độ/layer/clip/màu/jobs](docs/KIEN_TRUC.md)
- [Hợp đồng dữ liệu `.paxis` bàn giao P09](docs/HOP_DONG_DU_LIEU_PAXIS.md)
- [Quyết định kỹ thuật](docs/QUYET_DINH_KY_THUAT.md)
- [Fixture tự tạo và kế hoạch dữ liệu thử](Fixtures/README.md)
- [Thành phần và giấy phép](docs/THANH_PHAN_VA_GIAY_PHEP.md)

- [Bắt đầu: bộ prompt xây dựng đến public](docs/prompts/README.md)
- [Đặc tả V1.0 — bản 1.0-draft.3 đã duyệt](docs/DAC_TA_V1.0.md)
- [43 ca nghiệm thu V1.0 — chưa hoàn tất](docs/CHECKLIST_NGHIEM_THU_V1.0.md)
- [Bộ mockup giao diện và phạm vi tương tác](docs/BO_MOCKUP_V1.0.md)
- [Định hướng ban đầu](docs/DAC_TA_SAN_PHAM.md)
- [Phần bổ sung: phát hành công khai](docs/PHAT_HANH_PUBLIC.md)
- [Trạng thái thực hiện và bàn giao](docs/TIEN_DO_TRIEN_KHAI.md)

Đặc tả đã được duyệt; kiểm thử và mục tiêu hiệu năng vẫn cần thực hiện, đo và lưu bằng chứng. Bộ prompt là kế hoạch thực thi, không phải báo cáo đã hoàn thành ứng dụng.

Đầu ra chuẩn bị phát hành: [P13 ký/DMG](docs/bao-cao/P13.md), [P14 website/docs](docs/bao-cao/P14.md), [P15 preflight](docs/bao-cao/P15.md), [website preview](website/README.md), [kế hoạch public](docs/KE_HOACH_PUBLIC.md). Không có bản public signed/notarized; localDMG không thay bản tải công khai.

Brush/Clone Stamp và live preview build6: [hướng dẫn](docs/HUONG_DAN_BRUSH_CLONE.md), [phạm vi](docs/DAC_TA_PAINT.md). Project paint dùng schema4; bản cũ từ chối. Bộ cài stable vẫn đang nghiệm thu/ký/notarize.
