# PhotoAxis — Quyết định kỹ thuật

## ADR-001 — Native AppKit và core độc lập (20/09/2026)

**Chấp nhận.** Xcode project có app, PhotoAxisCore framework và test bundle; shared scheme PhotoAxis, Debug/Release, arm64, deployment macOS 14.0, Swift 6. AppKit quản lý cửa sổ và input; MetalKit/Core Image được nối ở P02. Core không import AppKit và không I/O. Tách thư mục còn lại theo hợp đồng trong `KIEN_TRUC.md`, chưa tạo engine hoặc thư viện không dùng.

## ADR-002 — Build local không cần danh tính public

**Chấp nhận.** Bundle ID tạm `local.photoaxis.development`, framework `local.photoaxis.core`, tests `local.photoaxis.tests`; Team rỗng, ký ad-hoc `-`, Hardened Runtime chưa bật cho build local. Marketing version **1.0.0**, build **1**; mã đặc tả không dùng làm app version. Đây là cấu hình phát triển, không đủ để public. P13 phải chọn bundle ID/UTI, Developer ID, **bật Hardened Runtime** và quy trình notarization riêng.

Kiểm tra mở Release phát hiện DYLD từ chối framework ad-hoc khi Hardened Runtime bật mà app/framework không có Team ID. Cấu hình local dùng runtime NO; không thêm entitlement bỏ library validation, không sửa Gatekeeper/SIP/quarantine. R04 chỉ được đánh dấu khi có bản Developer ID đã ký đúng cả app/framework và runtime YES ở P13.

Script chọn Xcode hiện tại hoặc `/Applications/Xcode.app` qua DEVELOPER_DIR khi máy đang chọn CLT; không chạy `sudo xcode-select` và không tự chấp nhận license. Dùng một đường build/test Xcode chính thức. CLT 27 trên máy thiếu TestingMacros khi thử SwiftPM, nên không giữ đường fallback chưa hoạt động. Chủ máy đã xử lý license Xcode trong P00.

DerivedData/test result mặc định ở `~/Library/Developer/PhotoAxisBuilds/<hash-path-repo>/`, có thể override bằng `PHOTOAXIS_BUILD_ROOT`. Build thử dưới Documents đã bị File Provider gắn FinderInfo làm codesign từ chối; dùng vị trí build ngoài vùng đồng bộ thay vì sửa metadata file người dùng hoặc tắt kiểm tra chữ ký.

## ADR-003 — Project có thể tái tạo không cần dependency

**Chấp nhận.** `scripts/generate-project.py` (Python standard library) tạo project.pbxproj xác định từ source inventory và cấu hình; `--check` phát hiện membership bị cũ. Shared scheme lưu trong Git. Khi thêm nguồn hoặc đổi target phải sửa generator/chạy lại; xcconfig là nguồn cấu hình Debug/Release. Không thêm XcodeGen/CocoaPods/gem chỉ để sinh vài target. Project tạo ra được commit để mở trực tiếp bằng Xcode.

## ADR-004 — Geometry Double, source bất biến và clip theo layer

**Chấp nhận cho hợp đồng; Crop chữ nhật đã triển khai P04, solver Perspective Crop ở P05.** Ma trận row-major/vector cột, `H × M` khi biến đổi toàn tài liệu, kiểm soát miền kỳ dị; giữ text/shape và nguồn dùng chung. Clip tích lũy trong tọa độ nội bộ mỗi layer, không flatten. Định nghĩa chi tiết và nghĩa vụ thử nghiệm ở `KIEN_TRUC.md`; P05/P07 có thể tinh chỉnh biểu diễn trước schema chính thức nhưng không được làm mất yêu cầu bảo toàn.

## ADR-005 — Localization và UI trung thực ở P00

**Chấp nhận.** Dùng Localizable.strings vi/en và Bundle lookup; hệ thống chọn ngôn ngữ hiện tại. P01 sẽ bổ sung lựa chọn Theo hệ thống/Tiếng Việt/English, áp dụng khi mở lại. New/Open/Save disabled, có giải thích; không tạo tài liệu giả. Cửa sổ Welcome P00 chưa đại diện workspace Photoshop hoàn tất.

## ADR-006 — CI build/test, chưa có publish

**Chấp nhận.** GitHub Actions kiểm tra macos-15 arm64, Xcode 16.4, Swift 6, Debug/test + Release ad-hoc; checkout được ghim SHA. Local hiện Xcode 27/SDK 27. Chọn CI Xcode 16.4 làm mốc tương thích rộng hơn cho macOS 14. CI chưa chạy khi chưa có remote; label/path có guard và phải xác minh ở lần chạy đầu. Workflow chỉ có quyền contents:read, không secret, không trigger theo tag và không có tác vụ release/upload/publish.

Nguồn kiểm tra 20/09/2026: [Apple build settings](https://developer.apple.com/documentation/xcode/build-settings-reference), [GitHub runner images](https://github.com/actions/runner-images), [macOS 15 arm64 image](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-arm64-Readme.md). Toolchain local và lệnh thực chạy được lưu trong báo cáo P00.

## ADR-007 — Workspace AppKit, preference tách khỏi model (21/09/2026)

**Chấp nhận, P01 đã triển khai.** Các vùng UI dùng NSView/NSControl/NSMenu native với frame point cố định theo hợp đồng, NSStackView cho nhóm controls. Tools vector tự vẽ và SF Symbols hệ thống, không đưa tài nguyên Adobe vào app. Rulers chưa gắn số pixel khi chưa có document; Save/Export/Recovery chỉ có lệnh disabled. Flyout nhóm là điều hướng thật, mọi lựa chọn công cụ chưa có backend vẫn disabled.

UserDefaults lưu layout phiên bản riêng và lựa chọn ngôn ngữ; validate/corrupt fallback, Reset không xóa ngôn ngữ. Không lưu preference UI vào Core hoặc `.paxis`. L10n chọn bundle một lần mỗi phiên, có English fallback; Settings báo mở lại, không gọi terminate. Luồng dirty/Save khi quit thuộc P11, không được suy ra đã đạt từ P01.

Tab nằm trong canvas responder; không chặn NSTextView/IME bằng monitor global. Splitter hỗ trợ mouse drag, bàn phím và accessibility. Tắt NSWindow automatic tabbing để tránh thanh tab cửa sổ hệ thống cạnh tranh với tab tài liệu P02. Controls hệ thống giữ hình thức/ngôn ngữ hệ thống theo cơ chế macOS.

## ADR-008 — Hosted tests cho hành vi AppKit và đo point (21/09/2026)

**Chấp nhận.** Thêm PhotoAxisAppTests (XCTest, host PhotoAxis.app, bundle ID local.photoaxis.apptests) vào generator và shared scheme. Bộ 7 test kiểm tra language lifecycle, restore/reset/corrupt preferences, numeric validation, mouse/keyboard/responder, disabled/flyout và layout vi/en. Dùng UserDefaults suite riêng cho từng test; không xóa preference người dùng.

Ảnh layout lấy từ NSView trong cửa sổ thật của test host; JSON lưu window/content frames và backing scale. Chụp trực tiếp Release qua công cụ native để bổ sung kiểm tra thực tế. Không dùng ảnh HTML làm bằng chứng, không coi screenshot đã thu nhỏ là số đo point. Tự động hóa drag của công cụ điều khiển máy trả AXError.notImplemented; hit-test và mouseDown/Dragged được kiểm tra tại responder của view với tọa độ cửa sổ trong host; thử dispatch chuột qua NSWindow không nhận được sự kiện vì host không active/key, còn kéo bằng chuột/trackpad vật lý cần lượt nghiệm thu P12.

## ADR-009 — Một bộ điều phối và nguồn sở hữu riêng (22–23/09/2026)

**Chấp nhận, đã triển khai P02.** PhotoDocument/NSDocument giữ dirty/UndoManager/trạng thái tab; DocumentCoordinator sở hữu tối đa 5 tab cùng mọi quyết định close/quit. Không đăng ký vào NSDocumentController: kiểm tra native phát hiện review-unsaved mặc định xuất hiện trước delegate; đã bỏ cơ chế cạnh tranh và thêm regression test. Close-all hỏi trước toàn bộ rồi mới bỏ; Cancel ở bất kỳ tài liệu nào giữ tất cả. Save chưa có nên disabled, mặc định Cancel; P09/P11 mở rộng chính luồng này.

Asset sở hữu Data bất biến, ID SHA-256; không dùng mapped file vì file bên ngoài có thể bị viết lại. Nguồn được giữ nguyên encoded bytes, resize có consent/clipboard nhúng PNG sRGB. Không gắn URL ảnh nhập làm fileURL dự án. Place tái kiểm tra quota trên MainActor; đóng tab đích không chuyển kết quả nhập sang tab khác.

## ADR-010 — Preview worker tuần tự, cache hữu hạn (22–23/09/2026)

**Chấp nhận.** ImagePipeline actor thực hiện Image I/O, màu/orientation, composite/evaluation viewport ngoài MainActor. CIContext dùng Metal nếu có; MTKView encode trình bày bitmap kết quả. Guard ID/revision/generation bỏ frame cũ; overlay gắn viewport của frame nhận được. LRU decoded cache 256 MiB, bỏ nguồn tab nền. Không tuyên bố tổng RAM 256 MiB hoặc benchmark A36 đã đạt.

Đối chiếu [Apple CIContext](https://developer.apple.com/documentation/coreimage/cicontext), [Image I/O SDR decode](https://developer.apple.com/documentation/imageio/kcgimagesourcedecodetosdr) và header SDK: decode-to-SDR có từ macOS 14, ISO gain map guard macOS 15. Chạy macOS 14 thực cần P12.

## ADR-011 — Fixture test bundle và số theo vùng (23/09/2026)

**Chấp nhận.** Fixture tự tạo nhỏ 108 KiB trong Fixtures/P02 chỉ nhúng vào PhotoAxisAppTests, không phụ thuộc Documents/File Provider của tiến trình test; Cmd+U/CLI không cần sinh trước. Ảnh sinh riêng và output ở ngoài Git. Giữ ENABLE_USER_SCRIPT_SANDBOXING=YES, không thêm quyền hệ thống.

PPI/zoom dùng vùng macOS độc lập vi/en. NSTextField.integerValue trên vi_VN tự chèn dấu nhóm (1080 → 1.080); preset dùng stringValue số nguyên không nhóm. Oracle pixel gắn colorSpace của bitmap trước đối chiếu sRGB, không coi NSCalibratedRGBColorSpace là sRGB.

## ADR-012 — History metadata và state identity (24/09/2026)

**Chấp nhận, P03 đã triển khai.** Core `DocumentHistory` giữ snapshot value metadata và command ID, tài liệu giữ encoded assets theo SHA-256 một lần. Budget tính cả nguồn chỉ cần bởi Undo hoặc Redo ở mọi cursor, tối đa 100 bước/128 MiB; prune oldest và thu hồi byte khi không còn live/history reference. Bản sao layer không nhân đôi nguồn. Saved marker là UUID state, không phải số cursor hoặc revision; cắt nhánh và prune không tạo Saved giả. P09 nối Save thật vào marker của snapshot đã ghi thành công.

Bridge NSUndoManager có nhóm tường minh và callback đối nghịch cho Redo; snapshot/bytes không nằm trong closure. [Apple groupsByEvent](https://developer.apple.com/documentation/foundation/undomanager/groupsbyevent) yêu cầu quản lý group khi tắt nhóm theo sự kiện; [UndoManager](https://developer.apple.com/documentation/foundation/undomanager) đăng ký thao tác nghịch trong Undo/Redo. Test chạy nhiều command, nhảy History, saved marker, nhánh mới và pruning; thao tác không đổi nội dung không tạo entry.

## ADR-013 — Transform preview và hệ tọa độ canvas (24/09/2026)

**Chấp nhận.** Session tạm thuộc PhotoDocument, bắt đầu từ snapshot committed; Apply một command, Escape/Cancel bỏ preview. Các tab giữ session độc lập. X/Y/W/H là axis-aligned bbox trong canvas; mọi phép mới nhân bên trái projective matrix cũ. Không rasterize/reset phối cảnh. Tay nắm scale giữ anchor đối diện, Shift đảo liên kết; tay nắm quay Shift bắt góc tuyệt đối 15°. Giữ 8 resize handles và rotate handle trong point ở mọi zoom/backing.

Alpha-aware hit test qua worker, khóa/ẩn bỏ qua khi Auto-Select nhưng vẫn chọn được ở bảng. NSTableView hỗ trợ drag reorder nội bộ bằng UUID và drop-above; thêm nút lên/xuống để truy cập bằng control native. Quy tắc khóa thực thi cả ở model, không chỉ disabled UI. Callback drag được nối theo [Apple NSTableView drop validation](https://developer.apple.com/documentation/appkit/nstableviewdatasource/tableview(_:validatedrop:proposedrow:proposeddropoperation:)); mức bằng chứng pointer thực tách khỏi hosted responder test trong báo cáo.

## ADR-014 — Clip local và composite chung (25–26/09/2026)

**Chấp nhận, đã triển khai P04.** Giao footprint document của từng layer với khung crop trước khi inverse-map về local, rồi giao clip cũ. Giữ một đa giác lồi, `[[]]` biểu diễn layer hoàn toàn ngoài khung; không xóa nguồn hoặc flatten. Mọi hidden/locked layer nhận cùng phép đổi document. Renderer grayscale-mask trong local trước CIPerspectiveTransform; mask kiểm tra quota trước cấp phát, không có cache mask không giới hạn. `renderDocument` dùng cùng composite với viewport nhưng không thêm checkerboard/overlay. Pixel tests và native Canvas Size xác nhận vùng cũ không lộ lại. Text/bounds mới sẽ tích hợp P06/P07, lưu clip ở P09.

## ADR-015 — Basis ổn định cho nhập Crop và command kích thước (26/09/2026)

**Chấp nhận.** Crop session giữ basis từ lần kéo/Reset cuối, mọi lần sửa ratio/W×H fit từ basis đó. Native QA phát hiện fit nối tiếp từng chữ số làm khung co dần và không hồi phục sau lỗi; giữ geometry hợp lệ đến khi giá trị mới qua preflight. Ratio/output hữu hạn, kích thước nguyên/quota được kiểm tra trước render. Crop/Transform dùng chung resolve Apply/Discard/Cancel; Apply lỗi không cho entry point tiếp tục bỏ session. Hộp thoại Image Size/Canvas Size và rotate/flip đều atomic, một command; PPI-only không sửa layer. Pan/zoom và Fit là view state, không thêm History.

## ADR-016 — Homography và phiên Perspective Crop (27/09/2026)

**Chấp nhận, triển khai P05.** Thứ tự TL/TR/BR/BL cố định trong tọa độ document y-down; không tự sắp xếp góc. Chuẩn hóa theo canvas, giải ma trận unit-square → quad rồi đảo để có document → output. Từ chối cạnh dưới 1 px, diện tích dưới 4 px², sin góc dưới 1e-4, tứ giác không lồi/giao chéo/ra canvas và miền mẫu số không cùng dấu (margin tương đối 1e-8). Kiểm lại ánh xạ bốn góc và inverse trước khi tạo candidate.

Auto lấy trung bình cặp cạnh đối diện, làm tròn pixel. Ratio giữ gần diện tích Auto rồi ép W:H, làm tròn cuối; sai số tỷ lệ chỉ do số pixel nguyên. Swap chỉ đảo ràng buộc đầu ra, không hoán đổi góc. Clear giữ quad/về Auto; Reset full canvas/giữ mode. Preview dùng candidate tạm, lưu/khôi phục viewport chỉnh góc, không tạo history; Apply chốt một snapshot metadata. Generation token ngăn frame cũ ghi đè; overlay dùng presentedViewport. Tay nắm 8 point, bán kính hit 8 point không phụ thuộc zoom/backing.

## ADR-017 — Miền giữ lại và inverse sampling hữu hạn (27/09/2026)

**Chấp nhận, triển khai P05.** Một quad hợp lệ có thể có pole ở phần nguồn đã cắt. Không được đánh đồng trường hợp này với pole trên vùng giữ lại. `LayerGeometry.support` giao clip trong local rồi kiểm tra miền trước khi map; Crop lặp sử dụng support này. Bounds/angle giữ hành vi full source khi hữu hạn; fallback sang support khi full source đi qua pole. Overlay có thể vẽ đa giác nhiều hơn bốn đỉnh sau giao clip.

Renderer dùng CIPerspectiveTransform cho full source hữu hạn. Khi full source không hữu hạn, `Perspective.ci.metal` là CIWarpKernel lấy mẫu ngược từ ma trận inverse vào nguồn bất biến đã áp clip; extent chỉ bằng canvas hợp lệ. Guard mẫu số/finite trong kernel trả tọa độ ngoài ảnh (transparent) ở pole ngoài support. ROI bảo thủ là toàn source đã giới hạn quota; chưa tối ưu tile/benchmark P12. Cả hai đường dùng cùng CIContext linear-sRGB → RGBA8 sRGB; preview và renderDocument dùng chung composite.

Kernel biên dịch offline bằng Metal Toolchain chính thức của Xcode (`-fcikernel`, `metallib -cikernel`), nhúng `Perspective.metallib` vào app. Build phase khai báo input/output, dùng TEMP_DIR cho file tạm; giữ `ENABLE_USER_SCRIPT_SANDBOXING=YES`. Không biên dịch shader runtime hoặc thêm dependency bên thứ ba. Tham chiếu [Apple CIWarpKernel](https://developer.apple.com/documentation/coreimage/ciwarpkernel), [apply/ROI](https://developer.apple.com/documentation/coreimage/ciwarpkernel/apply(extent:roicallback:image:arguments:)) và [Metal kernel build](https://developer.apple.com/videos/play/wwdc2020/10021/). Fixture riêng có pole nguồn y=50, support y=150…450; test pixel độc lập và chuỗi expand/move/rotate/crop lại xác minh không hồi sinh pixel đã cắt.


## ADR-018 — Nội dung chữ/hình và phiên nhập native (28/09/2026)

**Chấp nhận, triển khai P06.** Text giữ Unicode, PostScript font name, family/style, cỡ px, màu sRGB/alpha, alignment, line spacing và local layout size. Shape giữ loại, kích thước, fill, stroke và hai đầu line chuẩn hóa. Raster Core Text/Core Graphics là sản phẩm render tạm; không đổi kiểu layer thành ảnh. Composite/thumbnail/hit-test dùng cùng nội dung với matrix/clip/opacity hiện có. Rectangle không stroke tiếp tục dùng CIImage màu để tránh cấp phát bitmap nền lớn.

`ContentSession` giữ candidate riêng, draft lỗi và trạng thái composition. Apply hợp lệ tạo một command; Cancel khôi phục selection/model, text trắng rỗng không để layer rác. Giới hạn font 1–1000 px, line spacing/stroke 0–1000 px; text tối đa 1 MiB UTF-8 và 8000 dòng trước layout, bitmap tối đa 8000 px/cạnh và 40 MP trước cấp phát. Đây là guard tài nguyên, chưa phải cam kết tốc độ cho text cực lớn ở P12.

`NSTextView` giữ input context/marked text, selection và typing undo riêng. Return qua responder native; Cmd+Return chốt composition rồi Apply; Escape ngoài composition hủy phiên. Canvas không nhận V/T/C/X/D/Space khi trình nhập có focus. Inline editor dùng nền giấy dễ đọc và một định dạng cho toàn nội dung, không tự wrap; trình render canvas giữ màu/alpha thật. Text có projective coefficients chỉnh trong Properties, giữ matrix/clip khi đổi nội dung; P07 còn phải kiểm tra chuỗi crop nhiều layer đầy đủ.

Font không có: Core Text fallback chỉ để xem; giữ tên gốc trong model, hiển thị cảnh báo; chọn family/style thay thế mới thay payload và có Undo. Không hứa hình fallback khớp font gốc. Font lấy từ hệ thống, không sao chép font binary. Tham chiếu [Apple NSTextInputContext](https://developer.apple.com/documentation/appkit/nstextinputcontext), [nguồn nhập khả dụng](https://developer.apple.com/documentation/appkit/nstextinputcontext/keyboardinputsources), [CTLine](https://developer.apple.com/documentation/coretext/ctline).

Eyedropper lấy composite committed tại tâm document pixel, trả sRGB không premultiply cùng alpha; alpha=0 trả clear. Không lấy màu checkerboard/handles. FG/BG là trạng thái công cụ của từng tài liệu, thay màu không tạo History hoặc sửa ngược layer cũ.

## ADR-019 — Tích hợp editable sau Perspective Crop (29/09/2026)

**Chấp nhận, P07.** Dùng lại transaction H × M và clip support chung của P05 với local bounds/renderer typed P06. Không thêm nguồn raster thay thế cho chữ/hình. Clip local là miền cố định đã giữ: sửa text/shape và Move/Transform giữ clip; crop lần sau giao tiếp. Layer tạo mới sử dụng canvas mới với clip không giới hạn, không lấy H từ layer đang chọn. Hợp đồng dữ liệu bàn giao P09 ở [HOP_DONG_DU_LIEU_PAXIS.md](HOP_DONG_DU_LIEU_PAXIS.md).

Routing Properties dựa vào hàng mẫu số đã chuẩn hóa tương đối của matrix, không dựa vào độ lớn tuyệt đối. Hai ma trận khác nhau bởi hệ số vô hướng phải có cùng routing và cùng hình học. Trình sửa Properties tự cuộn vào vùng nhìn thấy trước focus; shape tới trường kích thước, text projective tới NSTextView. Full-clip/opacity-zero bỏ qua trước raster allocation, vẫn giữ payload/nguồn cho chỉnh tiếp và Undo. Composite khởi tạo canvas trong suốt hữu hạn thay CIImage.empty(), vì canvas bị crop hết nội dung vẫn phải render được và nhận layer mới.

Oracle pixel P07 chiếu ngược composite trước crop bằng ma trận độc lập biết trước; so sánh vùng màu trơn và nội dung foreground, tránh nhập nhằng sai khác kernel nội suy ở biên tương phản. Test riêng giữ alpha/clip, nguồn và typed payload, hidden/locked, Preview/Apply, Undo/Redo hai crop, sửa nội dung và layer mới. Thời gian/cache ghi ở fixture nhỏ không được dùng làm kết quả benchmark toàn quota P12.

## ADR-020 — Điều chỉnh ảnh theo layer (01/10/2026)

**Chấp nhận, P08.** ImageAdjustments là metadata value trong Core: enabled và bốn số theo đơn vị UI. Image-only setter kiểm finite/range/lock nguyên tử. Một gesture hoặc phiên nhập số dùng EditingSession `.adjustments`, preview riêng và một commit; Cancel/Undo khôi phục snapshot. Enable/Reset có lịch sử, Reset đồng thời bật nhóm. Duplicate sao chép tham số nhưng không nhân bản nguồn ảnh.

Renderer dùng working space linear-sRGB hiện có. Thứ tự CIExposureAdjust(inputEV=EV), CIColorControls(inputBrightness=b/100, inputContrast=1+c/100, inputSaturation=1), rồi CIColorControls(inputSaturation=1+s/100, các giá trị còn lại trung tính), trước clip/transform/composite. Skip toàn filter khi neutral hoặc disabled; alpha không được sửa. Apple mô tả Contrast quanh 0.5, Brightness cộng bias và Saturation=0 nội suy về grayscale trong [Core Image Filter Reference](https://developer.apple.com/library/archive/documentation/GraphicsImaging/Reference/CoreImageFilterReference/index.html). Đây là mapping PhotoAxis, không hứa giống số Photoshop.

Nguồn đã chuẩn hóa tiếp tục ở decoded cache theo source ID; không lưu raster điều chỉnh vào model hoặc decode mỗi tick. Canvas dùng cancellation/generation guard sẵn có để bỏ frame cũ. Thumbnail thêm adjustments vào key và đổi generation ngay cả khi Undo trở về key đã cache, để completion cũ không ghi đè kết quả mới.

Properties dùng slider transaction và ô số theo locale macOS, EV/% rõ; Return commit số, Escape Cancel, Apply/Cancel chung cho preview. Không gửi numeric action tự động khi focus kết thúc, vì Cancel không được vô tình commit giá trị trước khi hủy. Giá trị ô số và slider được chụp trước callback refresh khi mở session, kể cả action keyboard/accessibility không có mouse gesture. Canvas arrow không ghép Move vào session điều chỉnh ảnh. Đo fixture nhỏ ghi riêng, không suy ra đạt benchmark P12.


Slider giữ control `NSSlider` và cell native, xử lý pointer theo mouseDown/Dragged/Up, clamp theo bar/knob và giữ offset khi nắm knob. Refresh không ghi đè cell đang tracking; mouseUp kết thúc tracking trước commit. Native QA ban đầu nhận giá trị điểm bắt đầu nhưng không theo điểm nhả với tracking loop cũ; implementation theo responder events đã kiểm trên Release. Cùng control dùng cho opacity, có assertion hồi quy preview/one Undo/Undo trong NSWindow. Không suy ra đã kiểm chuột vật lý hoặc toàn bộ accessibility ở P12.

## P11 — Recovery theo state và manifest

Recovery dùng archive nguồn nhúng riêng với manifest atomic; không autosave-in-place hoặc ghi file dự án. Manifest chỉ xuất bản state sau archive hoàn tất. Writer token và cleanup theo state UUID ngăn Save cũ/Discard cạnh tranh xóa nhầm hoặc phục hồi lại state mới. Timer 10s bỏ qua state không đổi; lỗi báo một lần. Close nhiều tab hoãn Dont Save cleanup đến sau tất cả lựa chọn, freeze editing trong preflight và đợi atomic file task; Cancel giữ tab/record. Debug-only child crash fixture không có trong Release.

## P12 — Chất lượng preview có giới hạn, 02/10/2026

Mask toàn nguồn 24MP trong mỗi candidate Perspective gây worker ~63ms. Preview tương tác dùng một pixel/point ở Retina và mask theo tỷ lệ zoom, chỉ trong render viewport. Sau 150ms không đổi, request full quality có key riêng bao gồm clip quality; không để coalescing 1× nuốt lượt full. Save/Export/sample/preview.png luôn composite full. Model, ma trận, clip và nguồn nhúng không thay. Lưu số liệu trước/sau và regression byte final; native FPS phải đo riêng. Ngày Recovery theo vùng hệ thống, không theo ngôn ngữ UI.

## ADR-021 — Hồ sơ điều tra và bản chia sẻ đã rà soát (02/10/2026)

**Chấp nhận trong yêu cầu triển khai gói điều tra, Investigation 1.** Native/offline, tách `.paxcase` package khỏi `.paxis` ZIP. File tiếp nhận giữ đúng byte và SHA-256 trước decode; metadata Image I/O giữ trong intake riêng với trường do người dùng khai báo. Bản làm việc vẫn chịu quota editor. Profile `.paxis` thường schema 1 giữ nguyên; working archive gắn hồ sơ dùng schema 2 với case/item UUID để reader cũ từ chối an toàn. Mở working file thiếu hồ sơ khóa chỉnh sửa/chia sẻ.

Nhật ký chứa full model/tham số sau mỗi committed operation, Undo/Redo, intake, rà soát và export; hash nối và state digest cuối kiểm sai khác nội bộ. Không dùng Undo History làm nhật ký lâu dài, không quay vòng/xóa event khi tới quota. Candidate model chỉ commit sau manifest atomic thành công; lỗi ENOSPC/EACCES giữ model/history/checkpoint cũ. Save publish archive theo hash rồi chuyển manifest; giữ archive intake chuẩn hóa và checkpoint mới nhất để Delete → Save → Undo có nguồn khi mở lại. Writer POSIX flock, regular/O_NOFOLLOW và đối chiếu manifest tránh ghi đè ngoài phiên trong phạm vi filesystem local.

Chú thích là layer typed/shared source, không raster hóa nguồn. Magnifier giữ source ID/ROI/clip và adjustment tại thời điểm tạo, sau đó chỉnh độc lập. Comparison cùng pan/zoom hiển thị và swipe; không tự đăng ký hình học sau crop. Drag dùng tọa độ con trỏ liên tiếp, không phụ thuộc NSEvent.deltaX/Y của công cụ QA.

Review regions gắn SHA-256 model; mọi thay đổi model làm review cũ mất hiệu lực. Export riêng dùng raster đục rồi che black ROI, không chứa nguồn/layer riêng tư. PNG chỉ ghi metadata output tối thiểu. PDF native CG/Core Text dùng trang A4 raster150PPI, 1/2/4 ảnh; kiểm visible character range và từ chối quá dài thay vì cắt nội dung. Stream render một trang/lần, chặn PDF buffer lớn; file output atomic trên worker utility. Started/Completed tách nhau, completed ghi hash; lỗi ghi receipt sau output phải báo chưa hoàn tất.

Manifest serialized theo hồ sơ vẫn có I/O trong ngữ cảnh UI; chưa cam kết thời gian tương tác ở manifest32MiB hoặc filesystem đồng bộ/mạng. Dùng ổ local, sao lưu cả package sau khi nhả writer. Hash không xác thực danh tính/nguyên gốc/thời gian; quyền0444 không ngăn chủ filesystem thay byte. Chữ ký/timestamp/mã hóa, OCR/video/đo có hiệu chuẩn và chứng nhận phục vụ hồ sơ pháp lý thuộc phạm vi sau. [Đặc tả](DAC_TA_GOI_DIEU_TRA.md), [file](DINH_DANG_PAXCASE.md), [kiểm chứng](bao-cao/GOI_DIEU_TRA.md).

## Investigation 2 — 02/10/2026

- Người dùng giao triển khai ngay OCR tiếng Việt/video/đo có hiệu chuẩn, mở rộng riêng baseline 1.0-draft.3, app build3. Apple Vision xử lý local nhận dạng OCR có xác nhận; không có API/cloud/generative reconstruction. Ngôn ngữ kiểm tại runtime theo `vi-*` thực trả về (host là `vi-VT`), không hardcode `vi-VN` hoặc lấy tiếng Anh làm fallback. Giữ bản máy/confirmation riêng và ROI nguồn chuẩn hóa lúc intake.
- `.paxcase` v2 dùng `analysis` tùy chọn, v1 không encode trường nil nên giữ digest cũ; chuyển version trong atomic mutation đầu tiên dùng extension. Old app phải từ chối version2. Phép đo/confirmation/PTS/hash liên kết đều được state digest cuối ràng buộc và validate lại khi mở. `.paxis` thường/working không đổi version1/2.
- AVAssetReader đếm frame presentation thực từ đầu track để không đoán số khung VFR bằng FPS. Giữ preferredTransform/track/PTSrational/video bytes; giới hạn512MiB,8000px/40MP,100.000ordinal/120s. Original video giữ đuôi container bên cạnh hash vì AVFoundation trên host không mở MOV extensionless. Cấm tất cả media references ra ngoài container; một track video rõ ràng. PNG SDR dẫn xuất không được gọi là video nguyên bản.
- Phép đo chỉ dùng tỷ lệ đồng nhất do người dùng xác nhận căn cứ/thước cùng mặt phẳng; không đoán thước từ zoom/PPI hoặc ảnh phối cảnh bất kỳ. Canvas/model SHA giữ chuẩn; sửa model chặn đo mới bằng chuẩn cũ; số đo lịch sử vẫn giữ. Polygon đơn và bounds/finite/degenerate/result được kiểm.
- Phân tích JSON riêng chứa dữ liệu chưa che, có xác nhận UI trước xuất ở build3; build5 chuyển thông báo sang bảng Đầu ra, chọn đích lưu là hành động xuất rõ ràng; giữ bản OCR/confirmation/source thời gian và model hashes hiện tại. Không tự chèn chữ hay bảng phép đo vào bản ảnh chia sẻ. Cleanup temp sau rename dùng POSIX unlink best-effort để không tạo NSError ENOENT khi stage đã publish; lỗi commit gốc không bị thông báo cleanup che mất.


## ADR-022 — Scan1, preview có thể hủy và lô xuất riêng (03/10/2026)

Người dùng giao bổ sung bản scan, build4. Vision rectangles/text chạy trên actor, chỉ đề xuất hình học cần người rà soát. Core Image làm sạch nền bằng Gaussian/local division trong linear-sRGB; hai Metal kernel compile offline trong Perspective.metallib xử lý màu/threshold và bow hai trục. Clip áp dụng trước và sau warp; alpha và nguồn nhúng giữ nguyên. Các phép chuẩn hóa trang fit giữ tỷ lệ, PPI chỉ là metadata/kích thước xuất. Chú thích typed vẫn editable, không tự uốn theo bow image. Tham chiếu Apple [CIColorKernel](https://developer.apple.com/documentation/coreimage/cicolorkernel), [Vision quadratureTolerance](https://developer.apple.com/documentation/vision/vndetectrectanglesrequest/quadraturetolerance), [Core Image Metal kernel reference](https://developer.apple.com/metal/CoreImageKernelLanguageReference11.pdf).

Một Scan session dùng original snapshot/candidate; generation/cancellation bỏ completion cũ, một Apply một Undo. Thay controls khóa Apply đến preview mới. Text notification chỉ nhận controls trong panel để folder picker không phá readyRecipe; batch khóa controls và chụp recipe trước chạy. Mỗi trang phân tích riêng; preview trang mẫu không biến thành geometry áp dụng chung.

Schema3 chỉ khi có Scan metadata; reader1/2/3, downgrade chứa Scan bị từ chối. Layer duplicate giữ Scan và sourceID. Case audit lấy version/build runtime; Scan làm review/calibration cũ stale qua model hash. Batch xuất thư mục UUID mới, staging ẩn và rename một lần sau PNG/project/PDF/manifest; lỗi/Cancel dọn staging nhưng crash cleanup không được cam kết. Manifest có OS/build/settings/source-output hashes, confidence/warnings và requiresReview cho mọi trang. Batch không thay intake hoặc bản chia sẻ đã che của hồ sơ.


## ADR-023 — Hợp nhất hồ sơ và phân tích vào workspace (03/10/2026)

Theo yêu cầu người dùng, build5 bỏ menu Điều tra và các NSWindowController riêng của hồ sơ/so sánh/OCR/đo. Controller hồ sơ là NSObject quản lý session/store, cung cấp ba NSView bên cạnh bảng Chỉnh sửa. Nguồn chứa intake, danh mục, thông tin hồ sơ và toàn vẹn; Phân tích chứa so sánh/chú thích/OCR/khung hình/chuẩn đo; Đầu ra chứa rà soát che, PNG/PDF và các hồ sơ JSON. File picker native vẫn chọn nơi đọc/ghi. Nhập thuộc tính và lựa chọn chưa chốt nằm ngay trong sidebar; dùng continuation được resume đúng một lần khi Apply/Cancel.

Các view nguồn/so sánh/overlay dùng chung vùng canvas. ROI được lấy qua rect fit của chính nguồn hiển thị, không lấy tọa độ màn hình hoặc zoom làm pixel/đơn vị thật. OCR dùng intake; đo/che dùng model hiện tại; magnifier dùng nguồn nhúng đầu tiên, giữ clip và không validate ROI theo canvas đã crop. Model/tab/page thay đổi hủy bản nháp; completion ảnh dùng request ID hoặc anchor để không gắn vào tab khác. Áp dụng chú thích là một command/Undo/audit; bản gốc và format case/project giữ nguyên. Tab orphan có cùng ID được từ chối, giữ model chưa lưu.

Lượt native trên macOS27.0.1 ghi nhận worker OCR chờ lâu ở Vision/TextRecognition → dịch vụ ANE load model trong bản QA đầu. Build5 dùng `VNRequest.supportedComputeStageDevices` và gán `.cpu` cho từng stage hỗ trợ CPU, ghi computePolicy vào event OCR; stage không báo CPU vẫn do hệ thống chọn. Giữ Vision revision3, tiếng Việt runtime, vùng nguồn và kết quả/confirmation. Tham chiếu [Apple compute-device assignment](https://developer.apple.com/documentation/vision/visionrequest/setcomputedevice(_:for:)); API VNRequest/CoreML hiện tại được đối chiếu trong SDK với availability macOS14. Không xem đây là chứng minh mọi máy/OS hoặc full quota đã được nghiệm thu.


## ADR-024 — Paint typed và preview tự động (03/10/2026)

Yêu cầu mới cho phép Brush/Clone ngoài baseline. Nét giữ điểm/settings trong layer paint; mask8-bit linear-gray của từng ROI hợp theo lighten, alpha áp một lần cho stroke. Dab cách tối đa15%diameter (ít nhất1px); pointer sampling theo viewport, export đầy đủ. PNG clone lấy composite model đã chốt, sRGB/SHA256 riêng và offset top-left; mẫu cố định tránh phản hồi từ dấu vừa đóng. Không snapshot source mỗi tick. Schema4 khi có paint, reader1–4; metadata paint tính trong ngân sách Undo. Quota điểm/mẫu/ROI/source kiểm trước mutation và raster.

Phiên pointer original/candidate, changed render trực tiếp; mouseUp một Undo, Escape/focus/tab/navigation hủy nét đang kéo. Token/model/canvas không gắn mẫu muộn cho tab/model khác. Mẫu case publish read-only `derived/SHA256` trước atomic audit/model; manifest lỗi dọn file mới. Case reopen kiểm hash/định dạng/kích thước mẫu chưa có trong archive saved. Intake không viết lại.

Scan continuous sliders/text notifications debounce85ms, worker/generation/cancellation; bỏ Preview khỏi product. Perspective inset512px debounce45ms giữ original quad để sửa; Apply/Return chốt Undo. Adjustment continuous giữ nguyên. Debounce không chứng minh nativeFPS/full quota. [Phạm vi](DAC_TA_PAINT.md), [thao tác](HUONG_DAN_BRUSH_CLONE.md).

Mask và ảnh nhìn thấy của nét được giới hạn tường minh vào ROI có nền trong suốt trước composite. Kiểm native đã phát hiện nền đen ngoài ROI khi Scan xoay 3°; sửa clip này và thêm oracle alpha độc lập tại −3°/+3°/+14° và Perspective. Crop thường, Image Size và Canvas Size cũng tự preview, Cancel khôi phục viewport, Apply ghi một Undo.
