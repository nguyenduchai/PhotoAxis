# Checklist nghiệm thu V1.0

Tham chiếu: [DAC_TA_V1.0.md](DAC_TA_V1.0.md), bản 1.0-draft.3 đã được người dùng xác nhận, gồm 43 ca. Kiểm tra phát hành công khai được bổ sung riêng tại [PHAT_HANH_PUBLIC.md](PHAT_HANH_PUBLIC.md).

**Trạng thái hiện tại (03/10/2026):** [Ma trận A01–A43](MA_TRAN_NGHIEM_THU.md) hiện **19 PASS/24 ca chưa đóng**. [P12-native2](bao-cao/P12-native2.md) chốt A04/A07/A26 qua UI VI/EN build3 và audit file độc lập; A22 có phím Telex/Return/CmdReturn/Escape đúng ở VI nhưng EN/VNI/composition đầy đủ còn thiếu. Suite144PASS/0FAIL/4SKIP là lượt trước cùng code; benchmark mới riêng3PASS/0FAIL/0SKIP. Corner chỉ31% mẫu worker≤33,333ms, xem [benchmark](BENCHMARK_P12.md)/PERF-03. Native tổng thể/IME/macOS14/non-Retina/M1-16GB/Metal-QoS vẫn chưa đủ, P12/R02 chưa đạt. Không dùng worker latency để chứng nhận native FPS.

Khi chạy, ghi build/commit, macOS, máy/RAM/màn hình, bộ dữ liệu, kết quả thực tế, bằng chứng và lỗi liên quan. Đối chiếu UI ở 1440×900 và 1280×800 pt; bổ sung màn hình Retina/non-Retina nếu có.

| Đạt | Ca | Yêu cầu | Thao tác và kết quả mong đợi |
| --- | --- | --- | --- |
| [ ] | A01 | F01 | Đối chiếu workspace với mẫu cố định: Tools/Options/tabs/panels đúng vị trí; màu, mật độ, controls và icon bám thiết kế |
| [ ] | A02 | F01 | Thu gọn/resize/reset workspace; Tools một/hai cột; khởi động lại giữ bố cục; cửa sổ nhỏ không che Apply/Cancel |
| [ ] | A03 | F01,F15 | Hover/active/disabled/focus/tooltips rõ; controls có accessibility label; menu/tool không tạo hành vi giả |
| [x] | A04 | F02 | Tạo từng preset và kích thước tùy chỉnh; màu nền/alpha/PPI đúng; số sai bị chặn |
| [ ] | A05 | F02 | Mở PNG alpha, JPEG EXIF xoay, HEIC tĩnh, file tiếng Việt; hướng, kích thước và nguồn đúng |
| [ ] | A06 | F02,F05 | Place/drop/paste, nhiều file có một file lỗi; kết quả đúng layer/thứ tự/tỷ lệ, báo lỗi riêng |
| [x] | A07 | F03 | Mở 5 tab, thay đổi khác nhau, đổi tab và undo; không lẫn trạng thái; tab thứ 6 có thông báo |
| [ ] | A08 | F03,F13 | Đóng/quit có Save/Don't Save/Cancel; crop dở phải được giải quyết; Save không ghi đè ảnh nguồn |
| [ ] | A09 | F04 | Zoom 5%–1600%, 100%, Fit, pan, đổi màn hình; con trỏ và điểm điều khiển khớp tọa độ |
| [ ] | A10 | F05 | Đổi tên, order, visibility, lock, opacity, duplicate/delete; undo khôi phục đúng; chọn layer khóa được nhưng không sửa trực tiếp |
| [ ] | A11 | F06 | Move, arrows, scale, rotate, flip, nhập số, Shift, Apply/Cancel; mỗi phiên một undo |
| [ ] | A12 | F07 | Crop Free/Ratio/W×H, grid, Cancel; kết quả đúng pixel/tỷ lệ; dữ liệu nguồn được giữ |
| [ ] | A13 | F07 | Image Size/Canvas Size/rotate/flip tác động đúng toàn tài liệu; anchor và layer khóa/ẩn nhất quán |
| [x] | A14 | F08 | Ảnh lưới có TL/TR/BR/BL khác màu: crop phối cảnh đúng góc, không lật, không overlay trong output |
| [ ] | A15 | F08 | Kéo bốn góc tại nhiều zoom/pan; grid phản ánh phối cảnh; Space/pinch hoạt động trong phiên |
| [x] | A16 | F08 | Auto/Ratio/W×H/Swap/Clear/Reset/Preview; kích thước hiển thị và pixel đầu ra đúng |
| [x] | A17 | F08 | Khung giao nhau/lõm/gần thẳng, tọa độ biên và kích thước quá hạn: Apply tắt, có lý do, không crash |
| [x] | A18 | F08,F05 | Crop tài liệu nhiều layer, gồm text/shape/ảnh, hidden/locked; tất cả cùng phép chiếu, không flatten |
| [x] | A19 | F08,F09 | Sau crop thêm chữ mới nằm thẳng; sửa chữ cũ giữ phép phối cảnh; Move/Transform tiếp tục chính xác |
| [x] | A20 | F08,F13 | Crop → Save → Close → Open → chỉnh tiếp → export; canvas/layer/clip/nội dung khớp; undo cũ không được hứa phục hồi |
| [x] | A21 | F08,F12 | Crop → Undo/Redo, crop lần hai, rồi Undo; khôi phục kích thước và toàn layer, nguồn cũ không tự hiện ngoài clip |
| [ ] | A22 | F09 | Gõ tiếng Việt bằng Telex/VNI, nhiều dòng, đổi font/cỡ/căn lề; Return xuống dòng, Cmd+Return commit, Escape cancel |
| [x] | A23 | F09 | Dự án thiếu font: có thông báo, giữ tên font gốc, thay font có undo; không tuyên bố hình giống khi fallback |
| [ ] | A24 | F10 | Rectangle/Ellipse/Line, fill/stroke, Shift, màu HEX/RGB, X/D; Eyedropper bỏ overlay và lấy đúng composite |
| [x] | A25 | F11,F12 | Điều chỉnh trung tính và cực trị; toggle/reset, undo một lần kéo slider, save/reopen giữ giá trị |
| [x] | A26 | F12 | Undo/redo qua nhiều loại thao tác; chọn trạng thái History rồi sửa làm mất nhánh redo; saved marker đúng |
| [x] | A27 | F13 | `.paxis` là một file ZIP; sao chép file sang thư mục/máy khác và bỏ quyền truy cập ảnh nhập ban đầu, dự án vẫn mở đầy đủ nguồn nhúng |
| [x] | A28 | F13,F15 | Giả lập lưu lỗi/quyền/hết dung lượng/schema mới; ZIP lỗi, vượt giới hạn giải nén hoặc đường dẫn thoát vùng làm việc bị từ chối; bản lưu cũ còn nguyên và không báo Saved giả |
| [x] | A29 | F13 | Sửa đã commit → chờ recovery hoàn tất → kết thúc tiến trình bất thường → mở lại; khôi phục đúng trạng thái recovery gần nhất |
| [x] | A30 | F13 | Đóng với Don't Save không phục hồi lại; recovery lỗi không lặp alert; crop/text chưa commit không được hứa phục hồi |
| [x] | A31 | F14 | Export PNG alpha và JPEG với matte, quality, resize/PPI; pixel/kích thước/profile đúng; source không đổi |
| [x] | A32 | F14 | Export chỉ layer hiển thị; GPS bị loại; overwrite/cancel/failure không để file đích dở dang; export không xóa dấu chưa lưu |
| [ ] | A33 | F02,F14 | Ảnh sRGB/P3, grayscale, alpha và HDR/depth cao: conversion theo đặc tả, không halo rõ trên viền, không lệch hướng |
| [ ] | A34 | F15 | Tất cả phím tắt ở canvas và trường text/số/IME; không kích hoạt tool khi gõ chữ hoặc dùng Space trong text |
| [ ] | A35 | F15 | File hỏng, vượt 40 MP/cạnh 8000/50 layer/120 MP nguồn; từ chối hoặc resize có lựa chọn, tài liệu hiện tại không hỏng |
| [ ] | A36 | F15 | Đo open/pan/zoom/crop/slider/export trên tập chuẩn, tối thiểu 5 lượt; ghi số đo và cấu hình, đối chiếu mục tiêu |
| [ ] | A37 | F15 | Tập giới hạn, đổi tab nhiều lần, vòng lặp mở/sửa/xuất/đóng; theo dõi bộ nhớ, lỗi GPU, UI treo và cache không được thu hồi |
| [ ] | A38 | F15 | Cài/chạy `.app` trên máy đích, offline từ lần sử dụng đầu; mở/lưu/xuất không cần tài khoản/mạng |
| [ ] | A39 | F01–F15 | Luồng tổng: nhập ảnh nghiêng → ghép layer → Perspective Crop → thêm chữ Việt → chỉnh màu → save/reopen → sửa tiếp → export |
| [ ] | A40 | F01,F15 | Kiểm tra Tiếng Việt và English trên menu, tools, panel, tooltip/accessibility, History, Welcome, Settings và mọi hộp thoại/thông báo do app cung cấp; không thiếu dấu, lộ khóa dịch hoặc lẫn chuỗi chưa dịch |
| [ ] | A41 | F01,F13 | Kiểm tra Theo hệ thống với thứ tự ưu tiên vi/en/ngôn ngữ không hỗ trợ; chọn ngôn ngữ thủ công, mở lại giữ lựa chọn; thông báo cần mở lại rõ, không tự thoát, đóng khi chưa lưu vẫn có Save/Don't Save/Cancel |
| [ ] | A42 | F01,F09,F15 | Đối chiếu bố cục hai ngôn ngữ ở các kích thước cửa sổ quy định, kể cả 1100×700 pt; nhãn Việt không tràn/cắt dấu hoặc che Apply/Cancel; phím tắt và Telex/VNI không xung đột; nhập/hiển thị số thập phân đúng thiết lập vùng |
| [x] | A43 | F01,F13,F14 | Lưu dự án khi UI tiếng Việt → mở lại bằng UI tiếng Anh và ngược lại; tên/nội dung layer, chữ canvas, thông số và kết quả xuất không đổi; ngôn ngữ UI không được ghi vào `.paxis` |

## Điều kiện nghiệm thu

Ghi nhận P00: A03 có disabled/tooltip và menu thực trong phạm vi Welcome; A40 có 16 khóa vi/en và ảnh/AX hiện có. Chưa có workspace đầy đủ, Settings, tài liệu, tool, History hoặc hộp thoại nên hai ca này vẫn để trống. Geometry tests là đầu vào cho A09/A14–A21/A35, không phải kết quả của các luồng UI đó. A41–A43 chưa chạy.

- Mọi ca trên có kết quả; ca phụ thuộc thiết bị không có phải ghi CHƯA KIỂM CHỨNG và được quyết định phạm vi rõ ràng.
- Không còn lỗi gây mất dữ liệu, sai ảnh xuất, sai phối cảnh, sai trạng thái lưu, crash tái hiện hoặc thao tác bắt buộc không dùng được.
- Báo cáo gồm ảnh chụp UI, file mẫu dự án/ảnh xuất, log kiểm thử phù hợp và bảng số đo thực tế.
- Không dùng số lượng công cụ hoặc việc build thành công làm bằng chứng thay cho các luồng nghiệp vụ.

## Ghi nhận P01 — 21/09/2026

| Ca | Phần đã kiểm chứng | Phần còn thiếu để tick toàn ca |
| --- | --- | --- |
| A01 | Bộ tham chiếu cố định có nguồn/hash; 6 ảnh native vi/en tại 3 kích thước; các vùng và kích thước chính đúng hợp đồng | Tab/tên tài liệu thật, canvas/layer/phiên công cụ có dữ liệu và đối chiếu bản tích hợp |
| A02 | Thu gọn/mở bảng, nhập số/stepper/phím mũi tên, giới hạn 260–420, một/hai cột, lưu/mở lại/Reset; component overflow giữ Apply/Cancel | Kéo chuột/trackpad vật lý ở lượt nghiệm thu; Apply/Cancel trong phiên công cụ thực sau P03–P08 |
| A03 | Disabled/tooltip/AX labels; flyout chỉ mở nhóm, items disabled; active History/Properties và focus splitter/trường số; Tab canvas không chiếm ô nhập | Hover/pressed/active của công cụ khi có backend, điều khiển overlay/text và lượt keyboard/accessibility đầy đủ |
| A40 | 114 khóa vi/en khớp; menu/tools/panel/tooltip/AX/Welcome/Settings/help hiện có, có ảnh hai ngôn ngữ | History có thao tác, New/Save/Export/Recovery/progress/error và các hộp thoại chưa xây |
| A41 | Resolver thứ tự hệ thống/fallback; chọn thủ công, thông báo, không tự thoát, quit/reopen giữ ngôn ngữ và bố cục | Thoát với tài liệu dirty và Save/Don't Save/Cancel; kiểm tra thiết lập vùng/ngôn ngữ trên máy nghiệm thu |
| A42 | Ba kích thước cửa sổ × vi/en; nhãn/Apply/Cancel không bị che; component overflow; Tab tôn trọng NSTextView; validation số nguyên độ rộng bảng | Telex/VNI trong Type, nhập số thập phân ở các controls tương lai và các trạng thái phiên công cụ |

Giới hạn công cụ kéo máy và cách kiểm tra bổ sung được ghi rõ trong P01; không suy ra hành vi chuột vật lý từ kiểm tra callback. A43 và các Axx dữ liệu ảnh vẫn chưa chạy. Các ca R01–R12 vẫn chưa đạt public.

## Ghi nhận P02 — 23/09/2026

| Ca | Phần đã kiểm chứng | Phần còn thiếu để tick toàn ca |
| --- | --- | --- |
| A04 | Core/hosted tests 4 preset, swap, tùy chỉnh, PPI/nền/alpha, sai số/overflow; native 1080² trắng, A4 đen 2480×3508/300 PPI, width 8001 bị chặn | Lượt tích hợp đủ mọi preset/nền qua UI trên máy nghiệm thu và kích thước cửa sổ quy định |
| A05 | Unicode nguồn bất biến, EXIF 6 đối chiếu 4 góc, PNG alpha, HEIC tĩnh tự sinh; native mở và chọn các tab ảnh | Bộ ảnh thực đa dạng hơn/EXIF khác, chạy lại trên macOS 14 và máy đích |
| A06 | Place ở giữa, không phóng lớn/thu nhỏ đúng tỷ lệ, trên selection; batch valid–corrupt–valid giữ phần thành công; private NSPasteboard PNG/file URL và callback drop đúng ngữ cảnh; native Place A4/Open/báo lỗi | Finder drag và clipboard liên ứng dụng bằng pointer thực; Undo cho thao tác nhập sau P03 |
| A07 | Native 5 tab/tab thứ 6 bị chặn; test model/viewport/selection/tool/UndoManager riêng; đổi tab trong lúc render không hiện frame cũ; đóng đích khi nhập không chuyển sang tab khác | Thao tác chỉnh khác nhau và Undo/Redo thật giữa các tab sau P03 |
| A08 | Một coordinator quản lý close/quit; native Cancel giữ nguyên tab, Don’t Save đóng tài liệu thử; Save disabled và giải thích đúng | Save `.paxis`, crop/text dở và recovery qua P09/P11 |
| A09 | Native 100%/Fit/12,5%/scroll pan; test 5–1600%, anchor, backing 1×/2×, màu pixel render sau pan, overlay theo frame; Space/mouse responder không dirty/Undo | Pinch/drag vật lý, màn hình non-Retina/đổi màn hình, overlay công cụ khi có P03–P07; không coi backing mô phỏng là thiết bị thật |
| A33 | sRGB/P3 qua oracle ColorSync độc lập, alpha 0/1/bán trong suốt, grayscale 16-bit/SDR, ảnh không profile/HEIC tĩnh; native checkerboard không có viền đen rõ | HDR/gain map thực, đánh giá halo trên bộ ảnh rộng hơn và export P10 |
| A35 | Metadata/resize có consent, 8001×1, budget 10k pixel, quota 50 layer/120 MP dedup nguyên tử; PNG hỏng/TIFF/APNG bị từ chối, cache thu hồi; source file không đổi | Stress ảnh 40/120 MP thực, tài liệu lớn đầy đủ thao tác, bộ nhớ/GPU trong P12 |
| A40 | 158 khóa/152 tham chiếu khớp; New/Open/Place/progress/error/tab/close được dịch; ảnh native vi/en | Hộp thoại/chức năng các chặng còn lại và lượt đầy đủ mọi trạng thái |
| A41 | Quit dirty hỏi Cancel/Don’t Save/Save disabled; Cancel không tự thoát; NSDocumentController không mở review cạnh tranh | Save đang bật khi P09 hoàn thành, phục hồi và thiết lập ngôn ngữ trên máy nghiệm thu |
| A42 | New/zoom/PPI theo vùng; vi_VN dấu phẩy, en_US dấu chấm trong tests; native zoom 12,5% và English UI giữ số theo vùng máy; 7 test layout P01 qua | Telex/VNI Type, toàn bộ phiên công cụ/hộp thoại trên mọi kích thước; ảnh layout P01 hồi quy là workspace rỗng |

Chi tiết lệnh, source fingerprint, fixture/hash, ảnh và giới hạn ở [P02](bao-cao/P02.md). Save/Export chưa triển khai; A36/A37 và R01–R12 chưa đạt. Không suy ra kết quả công cụ chỉnh sửa hoặc thiết bị vật lý từ test model/render.

## Ghi nhận P03 — 24/09/2026

| Ca | Phần đã kiểm chứng | Phần còn thiếu để tick toàn ca |
| --- | --- | --- |
| A06 | Place vào tài liệu tạo import command, asset được history giữ cho Undo/Redo; quota vẫn nguyên tử | Native drag/clipboard và luồng import Undo end-to-end |
| A07 | Hosted test: preview Transform ở tab A được giữ khi đổi B, B duplicate/Undo không ảnh hưởng A, A Apply một entry | Lượt native tab/session với UI cuối |
| A09 | Native responder trong test window: handles theo frame/viewport/Retina, Space-pan/release; geometry/render backing và overlay khớp | Kéo/pinch vật lý, non-Retina/đổi màn hình |
| A10 | Model + UndoManager: rename, reorder, visibility, lock, opacity, duplicate/delete; locked protection; shared source; pixel Normal/opacity/order/alpha | Chuỗi Layers UI Release, kéo reorder vật lý; text/shape P06/P07 |
| A11 | Hosted canvas: scale, Shift đảo liên kết, rotate Shift 15°, arrow repeat/Shift, numeric/flip, Apply một entry/Cancel rollback, ma trận projective giữ; renderer PNG 30° | Chuỗi screenshot Release trước/preview/Apply/Undo/Redo, focus/overflow thực, kéo tay nắm vật lý |
| A26 | API/UndoManager: nhiều command, History cursor, redo branch cắt, saved UUID, prune 100 bước/128 MiB gồm redo source; gesture về gốc không cắt redo | Native chọn History rồi chỉnh; saved marker với Save thật P09 |
| A34/A42 | NSTextView được ưu tiên, number parser signed theo locale; W/H liên kết field refresh; tab Move options; slider action; 7 P01 layout tests qua | UI Transform vi/en đủ kích thước, input/IME và toàn bộ tool về sau |
| A40 | 199 khóa vi/en/193 tham chiếu qua scanner; command IDs độc lập nhãn dịch | Native History/Transform/resolve dialog vi/en và các phần UI chưa xây |

Kết quả chi tiết trong [P03](bao-cao/P03.md), [test summary](bao-cao/bang-chung/P03/test-summary.json) và [native QA](bao-cao/bang-chung/P03/native-qa.txt). **P03 đã DONE trong phạm vi layer ảnh:** thêm native Layers/rename/opacity/lock/order/delete/Undo/History branch, Transform fields/Apply/Undo/Redo Việt–Anh, resolve dialog và pointer Move. Xem nhật ký để phân biệt source trước/sau sửa overlay. A10/A11/A26 vẫn chưa tick toàn V1.0 vì text/shape, Save thật và nghiệm thu tích hợp/thiết bị còn thiếu. P04 tiếp tục crop/kích thước.

## Ghi nhận P04 — 26/09/2026

**P04 DONE trong phạm vi image/nền rectangle đang triển khai.** [Báo cáo P04](bao-cao/P04.md), [47 test PASS](bao-cao/bang-chung/P04/test-summary.json), [native QA](bao-cao/bang-chung/P04/native-qa.txt). Các ô toàn V1.0 vẫn chưa tick thay cho nghiệm thu tích hợp text/shape/Persistence hoặc phần thiết bị còn thiếu.

| Ca | Bằng chứng PASS tại P04 | Phần còn ở chặng sau |
| --- | --- | --- |
| A12 / F07 | Free/Original/presets/Custom/W×H; geometry + pixel output; native Free 320×240, Ratio 640×360, Swap/Reset 270×480, W×H 160×120; lưới/Cancel/Undo/Redo; giữ byte nguồn. Nhập 8001 bị chặn, sửa 160 phục hồi; test chuỗi chữ số và ratio overflow | Nghiệm thu tích hợp V1.0 sau Type/Shape; macOS 14/non-Retina ở P12 |
| A13 / F07 | Image Size, PPI-only giữ pixel/layer, 9 anchors, hidden/locked, rotate/flip; native Image Size 320×240/300 PPI, Canvas Size neo trên trái, rotate 480×640, flip đúng màu góc | Text/shape editable P06/P07; thiết bị/hiệu năng P12 |
| A08/A21/A26 | Session theo tab, một Apply/command, Cancel, Undo/Redo, repeat crop/clip, resolve tại đổi tool/quit; source không lộ sau expand + move + rotate; shared image-only renderer không overlay | Save/Export/recovery và Perspective Crop thuộc các chặng tương ứng |

Native Release Việt/Anh dùng fixture tự tạo. Nhật ký phân biệt các capture trước sửa nhập số và bản cuối; lỗi đã có regression test. 221 khóa vi/en, 213 tham chiếu; 0 fail/skip/runtimeWarnings. Không suy ra toàn A01–A43 hay R01–R12 đã đạt từ kết quả P04.

## Ghi nhận P05 — 27/09/2026

**P05 DONE trong phạm vi Perspective Crop trên ảnh đơn.** [Báo cáo P05](bao-cao/P05.md), [60 test PASS](bao-cao/bang-chung/P05/test-summary.json), [native QA](bao-cao/bang-chung/P05/native-qa.txt). F08 chưa hoàn tất trước P07/P09/P10; chưa tick toàn các ca có phụ thuộc tích hợp hoặc thiết bị.

| Ca | Bằng chứng PASS tại P05 | Phần còn ở chặng sau |
| --- | --- | --- |
| A14 / F08 | Shift+C, kéo tạo khung, bốn góc cố định TL/TR/BR/BL, kéo giữa; homography/corners/inverse/grid đối chiếu số học độc lập; render 4 màu góc và EXIF 6 đúng hướng | Tài liệu text/shape/nhiều layer và luồng tổng P07/P12 |
| A15 / F08,F03 | Hosted AppKit responder kéo cả bốn góc ở 50/100/200%, dịch khung, Space-pan, overlay theo frame; Core round-trip backing 1×/2×; native CUA kéo quad và riêng TR trên Retina 2× | Pinch vật lý, non-Retina/đổi màn hình thật, macOS 14 tại P12 |
| A16 / F08 | Auto trung bình cạnh, Ratio gần diện tích Auto, W×H, Swap không tráo góc, Clear/Reset, grid/Preview không history; native Auto 595×438 và W×H 320×240, A4→Swap 659×466; Preview/Apply pixel bytes bằng nhau trong tests | Save/reopen/export thật ở P09/P10, tích hợp P07 |
| A17 / F08,F15 | Trùng/lõm/chéo/gần thẳng/nhỏ/NaN/quota bị chặn; Apply disabled và lỗi vi/en; native 8001→320 phục hồi. Pole trên miền giữ bị chặn, pole ngoài clip vẫn render đúng bằng Metal kernel có extent hữu hạn | Stress/quota thực và thiết bị P12 |
| A21 / F08,F12 | Apply một command, Undo/Redo, crop lần hai/Undo, source bytes/UUID/payload giữ nguyên; expand/move/rotate không hồi sinh vùng cắt; native Apply 595×438→Undo 640×480→Redo và Undo bản 320×240 | Text/shape/multilayer editable P07, persistence P09 |
| A33/A40/A42 | Reference gradient sRGB, alpha premultiplied, EXIF; 231 khóa vi/en/223 tham chiếu; native vi/en; hosted layout 1440/1100 và overflow component ép rộng 900 pt giữ Apply/Cancel | HDR/export/IME, lượt giao diện tích hợp và thiết bị P12 |

Không có lỗi đã biết chặn P06. ROI toàn nguồn là giới hạn hiệu năng chưa benchmark; ad-hoc local không phải nghiệm thu public. A18–A20, A39/A43 và R01–R12 vẫn theo chặng tương ứng.


## Bằng chứng P06 — 29/09/2026

**P06 BLOCKED_EXTERNAL ở nghiệm thu bộ gõ thực A22; phần triển khai đã có bản chạy.** [Báo cáo](bao-cao/P06.md), [69 PASS/1 IME SKIP](bao-cao/bang-chung/P06/test-summary.json), [nhật ký native](bao-cao/bang-chung/P06/native-qa.txt). Không tick các ô toàn V1.0 từ compile hoặc Unicode paste.

| Ca | Bằng chứng đã có | Phần còn thiếu |
| --- | --- | --- |
| A22 / F09 | Core Text Unicode nhiều dòng/alignment/alpha; NSTextView thật với marked composition, Return/Cmd+Return/Escape; native VI/EN, font style/size/spacing, Undo/Redo/Cancel và phím V/T/C/X/D | Telex/VNI thực: context test chỉ có ABC, ca IME skip; chờ kiểm tra tay có tên bộ gõ/kết quả, là điều kiện chốt P06 |
| A23 / F09 | Font thiếu giữ tên/model, fallback render không sửa payload, cảnh báo chứa tên gốc vi/en, explicit replacement có Undo | Dự án .paxis thiếu font sau Open thuộc P09; tích hợp toàn luồng P12 |
| A24 / F10 | Native rectangle/ellipse/line, Fill None/Stroke 4, HEX/RGB, X/D; Shift bằng hosted responder; native sample ellipse alpha .5 ra #1278FF/18,120,255/128 alpha; model tests không lấy checkerboard/handles | Thử phím Shift vật lý và toàn bộ kích thước/cấu hình thiết bị ở P12 |
| A10/A11 / F05/F06 | Typed payload/bounds, duplicate/lock/opacity/clip/matrix/history; hit alpha; projective text sửa Properties giữ matrix | Mixed-layer Perspective và chỉnh tiếp P07; nghiệm thu hành vi layer/transform tổng thể P12 |
| A26/A34/A40/A42 | Transaction Apply một command, Cancel không layer rác; numeric Apply/Cancel kết thúc focus trước transaction; invalid 1e100 giữ editor an toàn; 258 khóa/250 tham chiếu, native VI/EN và layout inspector hẹp | Telex/VNI thực, các hộp thoại/tính năng sau P06 và mọi kích thước/thiết bị P12 |

## Bằng chứng P07 — 01/10/2026

**P07 DONE theo prompt 07; P06 A22 vẫn BLOCKED_EXTERNAL.** [Báo cáo](bao-cao/P07.md), [77 PASS/1 IME SKIP/1 QoS warning](bao-cao/bang-chung/P07/test-summary.json), [manifest](bao-cao/bang-chung/P07/build-manifest.json), [native QA](bao-cao/bang-chung/P07/native-qa.txt). Checkbox A18/A19/A21 phản ánh kết quả trên máy macOS 27/M1 Pro/Retina; không thay điều kiện thiết bị/hiệu năng và full integration P12.

| Ca | Đã kiểm chứng | Còn riêng ở chặng sau |
| --- | --- | --- |
| A18 / F08,F05 | 6 layer: hai ảnh dùng chung source, text Việt, ellipse, hidden rectangle, locked line; cùng H, typed payload/order/flags/source giữ nguyên; rollback khi layer cuối lỗi; oracle 2.111 mẫu sai số tối đa 2/255 | Full quota/macOS 14/non-Retina P12; persistence thuộc A20 |
| A19 / F08,F09 | Chữ cũ Properties giữ matrix/clip, chữ mới nằm thẳng; shape Fill/Stroke giữ editable; projective hit-test, Move +12/+8 và resize ×1.2; layer mới không kế thừa H/clip; native VI và hosted VI/EN | Chuỗi pointer English bổ sung P12 do CUA lỗi sheet hệ thống; bộ gõ thực riêng A22 |
| A21 / F08,F12 | Preview/Apply bytes trùng; một Apply một entry; hai crop Undo/Redo khôi phục model/canvas/source; mở rộng canvas/Move/sửa payload không lộ vùng cắt, full-clip vẫn render canvas trong suốt | Luồng save/reopen/export A20; cross-operation integration tổng A26/P12 |
| A20 / F08,F13 | Đã ghi [contract nguồn/type/matrix/clip/canvas/text/shape/order/params](HOP_DONG_DU_LIEU_PAXIS.md) | **Chưa đạt**, reader/writer P09 và Export P10 chưa có |
| A22 / F09 | Recheck context yêu cầu Simple Telex, selected vẫn ABC; [giá trị thực](bao-cao/bang-chung/P07/native-ime-recheck.txt); Unicode/marked-text có tests | **Chưa đạt**, chưa có nghiệm thu Telex/VNI thực và kết quả kiểm tra tay |
| A36/A37/A42 | 24 vòng fixture nhỏ: nguồn nguyên vẹn, History 49 bước/471.875 byte, decoded cache 1.228.800 byte → 0; Properties thấy/focus đúng ở 1100×700 pt VI/EN | Benchmark full quota/RSS/GPU/thiết bị; một QoS warning ở shape Cancel/focus cần tìm nguyên nhân và đo độ trễ, pointer EN và IME P12 |

Không tick A20/A22/A36/A37/A40/A42/A43 từ bằng chứng từng phần. Các phần P05/P06 phía trên giữ kết quả tại mốc cũ; trạng thái tiếp tục hiện hành theo [tiến độ](TIEN_DO_TRIEN_KHAI.md).


## Ghi nhận P08 — 01/10/2026

| Ca | Phần đã kiểm chứng | Phần còn thiếu để tick toàn ca |
| --- | --- | --- |
| A25 | **PASS phần P08:** neutral/bypass byte RGBA đúng, extrema/mapping/oracle, Saturation −100 xám, alpha edge, layer khác không đổi và ảnh đã Perspective; Enable/Reset/Cancel/Undo/Redo; 12 tick trong một drag chỉ 1 entry, action AX cũng 1 entry; lock/model guards và duplicate giữ params/chung source | **Save/reopen giữ giá trị và render ở P09**, nên A25 vẫn `[ ]` |
| A40/A42 | 268 khóa vi/en/255 tham chiếu; NSWindow 1100×700 VI/EN, Properties cuộn và EV/%; numeric theo locale máy hiện tại; Release VI exposure drag và EN đầy đủ theo nhật ký có UUID | Không thay nghiệm thu toàn A40/A42, locale khác, full accessibility/macOS 14/non-Retina và IME ở P12; P06 A22 chưa đạt |
| A20/A43 | Nhóm tham số và reader/writer contract được ghi cho P09; model/source/matrix/clip giữ qua chỉnh ảnh | Chưa có serializer/Save/Open/Export; A20/A43 chưa tick |

Bộ toàn suite **84 PASS, 0 FAIL, 1 IME SKIP**, có một runtime warning QoS cũ P07 trong summary. 20 render 640×480 trung vị **3,32 ms**, lớn nhất **4,75 ms**, decoded cache không decode mới qua các tick và release về 0. Đây là kiểm tra fixture nhỏ, chưa nghiệm thu benchmark P12. [Báo cáo P08](bao-cao/P08.md) và [bằng chứng](bao-cao/bang-chung/P08/build-manifest.json) phân biệt binary Release cuối với ảnh native trước sửa action AX. P08 DONE theo prompt 08; A25 full vẫn chờ P09, P06 vẫn BLOCKED_EXTERNAL A22.

## Ghi nhận P09 — 02/10/2026

A25/A27/A28 PASS: typed/parameter/source/model/render round-trip, copied project độc lập original URL, safe atomic write/failure/cancel/saved marker và bounded hostile ZIP/JSON/newer version. 94 PASS/0 FAIL/1 IME SKIP; native VI↔EN Save As và Finder Open With, overwrite Cancel giữ hash. Xem [P09](bao-cao/P09.md) và [format](DINH_DANG_PAXIS.md). A20/A43 chỉ đạt persistence, chờ Export P10. A22 không thay đổi. QoS/console MDB_MAP_FULL tiếp tục P12, recovery P11. Native screenshots có provenance framework trước hardening JSON cuối, không gán cho hash Release khác.

## Ghi nhận P10 — 02/10/2026

[P10](bao-cao/P10.md): 102 PASS/0 FAIL/1 IME SKIP, Release PASS. A20/A31–A33/A43 có model/render/Save/Open/Export, ICC/PPI/alpha/matte/GPS và ISO HDR tổng hợp; sheet hosted VI/EN. Cửa sổ Release/pointer/overwrite chưa kiểm chứng vì desktop khóa; macOS14/Telex/VNI vẫn còn. Không tick toàn ca từ build/test.

## Ghi nhận P11 — 02/10/2026

[P11](bao-cao/P11.md): 109 PASS/0 FAIL/1 IME SKIP. A08/A29/A30 có recovery atomic/token/state/timer ~10s, controlled child abnormal exit/restart store, Cancel nhiều tab/Dont Save; A40/A41 có recovery/missing-font/wording/lifecycle menu native và capture hosted VI/EN. Startup Release/pointer/Telex/VNI, toàn màn hình/kích thước và macOS14 còn chưa kiểm chứng; các ô toàn ca giữ chưa tick.

## Ghi nhận P12 — 02/10/2026

[Báo cáo P12](bao-cao/P12.md), [ma trận 43 ca](MA_TRAN_NGHIEM_THU.md) và [tồn đọng](KNOWN_ISSUES.md) thay các mô tả “chưa xây” mang tính lịch sử phía trên. A20/A39/A43 data workflow đã PASS với Save→Close→Open→edit→PNG/JPEG, immutable bytes và typed projective/affine layers; toàn ca chưa tick vì lượt native cuối/IME còn thiếu. A35/A37 đã thử quota 40MP/50 layers/120MP/5 tabs và 5 vòng thực; không suy kết quả máy32GB cho máy16GB. A36 có 5 lượt open/export/settle và 100 mẫu mỗi tương tác worker; pointer-to-present còn chờ desktop. A29/A30 có controlled child crash/timer/race atomic/Don’t Save tests; chưa thay startup native Release. Không có thay đổi phạm vi nghiệm thu được chủ dự án duyệt.

## Ghi nhận P15 native — 02/10/2026

[P15-native](bao-cao/P15-native.md) bổ sung bằng chứng trên binary D54 sau sửa tiến độ, 113 PASS/0 FAIL/4 SKIP. A20/A23/A29/A30/A31/A32/A43 đã PASS theo phạm vi host và loại test ghi ở [ma trận](MA_TRAN_NGHIEM_THU.md): crop/save/open/edit/export native; missing-font/Undo; timer/startup VI/EN/SaveAs; quit Cancel ở tab thứ hai/Don’t Save/restart; metadata và Cancel thật 40 MP giữ byte đích. Fault/corrupt/alpha-matte-oracle có tests, không tuyên bố mọi fault alert đều đã click native. Các ghi nhận cũ phía trên giữ nguyên theo mốc lịch sử.

A22, IME trong A34/A42, layout/reference/shortcut/focus toàn diện và close trong tác vụ nền, macOS14/non-Retina/máy chuẩn, native present latency và đánh giá Metal/QoS vẫn chưa đạt. CUA thử resize cạnh cửa sổ không tìm được window tại điểm kéo; chưa dùng attempted action thay kết quả layout. R02/releaseReady=false và public giữ BLOCKED_EXTERNAL.


## Ghi nhận P12-native2 — 03/10/2026

A04/A07/A26 tick theo nativeVI/EN trên build3/host27.0.1/Retina2×1280×800pt. Bằng chứng10preset,3fileHistory,ảnh/AX và kiểm độc lập được ghi trong [P12-native2](bao-cao/P12-native2.md). Telex VI hai dòng/cancel file đúng là tiến bộ từng phần A22; không tick VNI hoặc input context EN chưa xác minh. Benchmark mới3PASS và tỷ lệ corner31%≤33,333ms không thay nghiệm thu nativeFPS/máy chuẩn. P06/P12/R02 vẫn BLOCKED_EXTERNAL.
