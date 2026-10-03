# PhotoAxis — toàn bộ tiến độ và phần còn thiếu để public

Đối chiếu repository ngày02/10/2026 sau khi triển khai ba nhóm mở rộng. **Ứng dụng và hai gói điều tra đã có mã nguồn, UI native, test và artifact local; chưa đủ điều kiện public.** Bản hiện hành1.0.0(3), source0169bf5,144PASS/0FAIL/4SKIP; Release/ad-hoc/DMG local PASS. Còn9chặng DONE,7chặng BLOCKED_EXTERNAL; P16 chỉ bắt đầu khi cần sau public. BLOCKED_EXTERNAL ở đây có phần implementation đã xong nhưng nghiệm thu hoặc đầu vào phát hành chưa đủ.

## P00–P16

| Chặng | Trạng thái | Đã thực hiện | Còn thiếu để đóng toàn chặng |
| --- | --- | --- | --- |
| P00 nền dự án | DONE | Xcode native arm64/minOS14, build/test/scripts, kiến trúc/fixtures/provenance | Không còn việc chặng nền; runtime máy đích thuộc P12 |
| P01 workspace VI/EN | DONE | Workspace AppKit, panels/tool rail/options/settings/persistence | Kiểm tích hợp/reference bản cuối ở P12 |
| P02 document/import/canvas | DONE | PNG/JPEG/HEIC, nhiều tab, Place/clipboard, zoom/pan, quota | Bộ ảnh camera/máy đích và pointer tích hợp còn ở P12 |
| P03 layer/Undo/Move/Transform | DONE | Typed layers, transforms, History/Undo/Redo và nguồn bất biến | Rà tích hợp thao tác cuối ở P12 |
| P04 Crop/canvas geometry | DONE | Ratio/pixel/free, size/rotate/flip, Apply/Cancel/Undo | Nghiệm thu máy đích/tích hợp cuối ở P12 |
| P05 Perspective ảnh đơn | DONE | Bốn điểm/preview/validation/mapping/source/clip | Pinch/latency/máy đích ở P12 |
| P06 Type/Shape/Color | BLOCKED_EXTERNAL | TextKit/CoreText, shape/color/Eyedropper, native/hosted/Unicode tests | A22 Telex/VNI composition/Return/Cmd+Return/Escape thực |
| P07 Perspective nhiều layer | DONE | Mapping toàn typed model, hidden/locked/clip/edit tiếp, pixel oracle | QoS/máy đích trong gate P12 |
| P08 điều chỉnh ảnh | DONE | Exposure/Brightness/Contrast/Saturation, previews/oneUndo/bypass và Save/reopen | Qualification chung P12 |
| P09 `.paxis` Save/Open | DONE | ZIP bounded/schema, nguồn nhúng, atomic Save, corruption/fault/native VI↔EN | Không còn xây Save/Open; signed install ở P13 |
| P10 Export/màu | BLOCKED_EXTERNAL | PNG/JPEG/sRGB/ICC/alpha/matte/quality/size/PPI/GPS/atomic/cancel | A33 HDR camera thật, bộ dữ liệu rộng/macOS14 |
| P11 Recovery/lifecycle/ngôn ngữ | BLOCKED_EXTERNAL | Timer/committed recovery/restart/SaveAs/quit2tab/Cancel/DontSave/fault/locale | IME, full native focus/shortcut và close trong crop/transform/tác vụ nền |
| P12 nghiệm thu/hiệu năng/RC | BLOCKED_EXTERNAL | Ma trận43ca, automated regression, benchmark renderer lịch sử, RC provenance build3 |27ca chưa đóng đầy đủ; native tổng thể/máy đích/latency/quota/Metal-QoS |
| P13 ký/notary/DMG | BLOCKED_EXTERNAL | Icon/config/scripts/localDMG3verified;16policytests | DeveloperID/Team/namespace/notary/HardenedRuntime/timestamp/staple/cài sạch |
| P14 website/tài liệu | BLOCKED_EXTERNAL |12trangVI/EN preview, guide/privacy/release notes cập nhật gói mới, asset provenance | Publisher/support/terms/license/giá/host, gallery đúng ứng viên public, URL bộ cài cuối |
| P15 public/postcheck | BLOCKED_EXTERNAL | Preflight/anonymous HTTPS-hash/signature tooling/runbook | R01–R12, repo/target/quyền/CI, ký đủ gate, tải thật/đối chiếu/rollback |
| P16 bảo trì | KHI CẦN | Runbook và khuôn chặng | Chưa public nên chưa có vận hành bản public; không chặn1.0 |

[Tiến độ](../TIEN_DO_TRIEN_KHAI.md) giữ liên kết báo cáo/bằng chứng từng chặng. Số test ở báo cáo P00–P15 là kết quả của mốc đó; lượt hồi quy mới nhất144PASS không đổi provenance ảnh native cũ.

## Hai gói phục vụ điều tra

| Phạm vi | Kết quả thực hiện | Việc còn cần nghiệm thu trước phát hành gói |
| --- | --- | --- |
| I01–I04 nguồn/bản làm việc/intake/log | Nguyên byte/metadata/SHA-256, working riêng, nhật ký bền vững/hash/state, fault/atomic/Undo | Quy trình tổ chức/bàn giao/quyền/sao lưu, dung lượng/latency thực tế; hash không chứng minh nguồn gốc |
| I05–I07 bộ ảnh/chú thích/so sánh | Case/catalog, arrow/ellipse/số/chữ/magnifier, source/result sync zoom/pan/swipe | Pinch vật lý và bộ ảnh được phép dùng trên máy đích |
| I08–I10 bản ảnh/chia sẻ/an toàn | PNG/PDF A4 raster1/2/4ảnh/trang, review model/hash, vùng che riêng, full log/catalog JSON, guard/receipt | Quy trình rà soát người dùng, full quota và lỗi filesystem/máy đích |
| I11 OCR | Nhận dạng tiếng Việt native trên ROI nguồn, raw riêng/confirm revisions/log | Khả dụng Vision tiếng Việt/cold-warm/độ đọc đúng theo OS và dữ liệu thực; không đảm bảo mọi chữ |
| I12 video | RawMOV/MP4/M4V, actualordinal/PTS/rotation/sourcehash/framePNG, offset có căn cứ | Bộ codec/VFR/clip dài/4K/HDR/quotas/timeout trên máy đích |
| I13 đo | Calibration thước/đơn vị/căn cứ/modelhash, distance/area/stale guard/overlay | Hình học/thước độc lập/độ không đảm bảo và quy trình dùng ảnh thực; không tự nhận biết camera/lens/depth |
| I14 phân tích | Typed schema2/digest/atomic, JSON snapshot/ledger/outputhash | Rà dữ liệu riêng tư trong JSON; chưa auto chèn OCR/đo vào PDF/batchOCR/search |

**I01–I14 DONE local theo phạm vi đã ghi**, không chuyển thành chứng nhận forensic hoặc acceptance đầy đủ cho public. [Investigation1 lịch sử](GOI_DIEU_TRA.md), [Investigation2 hiện hành](MO_RONG_DIEU_TRA.md), [hướng dẫn](../HUONG_DAN_DIEU_TRA.md).

## Kiểm tra hiện hành và provenance

-148test:144PASS/0FAIL/4SKIP, gồm48Core PASS/96App PASS;4SKIP là3benchmark opt-in và1Telex context.31test điều tra gồm17Inv1+14Inv2.16policytestsPASS;404khóaVI/EN/333tham chiếuPASS. Project/Release/ad-hocPASS.
- Native VI OCR/xác nhận/đo/frame/exportJSON/open/verify và EN open/read/confirm/verify có ảnh/AX đúng Release UUID. Case synthetic đối chiếu20event/hash/state,3ảnh/archive,1video,2OCR,2frame,3measure. Kết quả chỉ áp dụng dữ liệu/host này.
- DMG local build3 source0169bf5 `sourceDirty=false`, mount/copy/tree/codesign/hash/detachPASS. SHA `797ee11a3267d0fde0a90d003a97379fca3ffa442ece1a6d0c75f50aea8a84bc`. Chưa ký DeveloperID/notarized hoặc cài sạch Gatekeeper.
- Website12trang kiểm link/anchor/metadata/alt/provenance/no trackersPASS; preview có downloaddisabled/noindex. Guide/privacy/release notes nội dung gói mới đã cập nhật; gallery D54/build1 vẫn lịch sử, chưa phải gallery bản public cuối.
- macOS27.0.1/M1Pro32GiB/Retina2×/Xcode27.0; targetarm64/minOS14. Release UUID`4EFA7887-E96F-3149-B6F5-68BE3475F219`, source fingerprint`317d062da381ee744dc7b680a3b5dd40d23525e9536da30c9cb63c67fa0e9d02`. Sau build chỉ tài liệu/bằng chứng đổi; không nhận code/docs commit là cùng một commit.

[Build manifest](bang-chung/INVESTIGATION2/build-manifest.json), [native inspection](bang-chung/INVESTIGATION2/native-analysis-inspection.json), [DMG manifest](bang-chung/INVESTIGATION2/distribution-manifest.json), [kiểm tra tổng hợp](bang-chung/INVESTIGATION2/overall-public-checks.json).

## Những mục chưa hoàn thiện để public

Ma trận A01–A43 hiện có **16PASS và27chưa đóng**.16PASS: A14/A16/A17/A18/A19/A20/A21/A23/A25/A27/A28/A29/A30/A31/A32/A43 theo phạm vi bằng chứng từng mốc; không coi tất cả là full native build3.27ca còn lại không đồng nghĩa27chức năng chưa xây: đa số implementation/test đã có, thiếu một phần nghiệm thu tổng hợp hoặc máy đích. [Ma trận](../MA_TRAN_NGHIEM_THU.md).

| Ưu tiên | Phần còn thiếu | Điều kiện/đầu ra cần có |
| --- | --- | --- |
|1 | Native tổng thể và bộ gõ | Chốt27ca: reference1100×700/1280/1440pt, resize/reorder/clipboard/Finder/transform/crop/History/presets/shortcuts/menu/tooltip/error/focus/locale; close/quit cùng session/tác vụ nền; Telex/VNI composition/multiline/commit/cancel thật |
|2 | Máy đích/dữ liệu/hiệu năng | macOS14/non-Retina/M1-16GB; ảnh HDR camera thực; native input-to-present/fps/low-resource/longrun; khoanh MetalMDB_MAP_FULL/QoS; full casequota và OCRcold-warm/VIavailability/video codec/calibrationgeometry |
|3 | Chủ thể và ký phân phối | DeveloperIDApplication hiện0; AppleDevelopment1 không thay thế. Cần Team/bundleID/UTI/notaryprofile, HardenedRuntime/timestamp, Accepted cho app+DMG/staple/validate, checksum cuối |
|4 | Cài thật từ ứng viên đã ký | Máy/tài khoản sạch/quarantine/Gatekeeper, macOS14 và OS mới được hỗ trợ; offline Open/Save/Export/Recovery/Investigation; upgrade/lỗi/cancel đúng dữ liệu |
|5 | Hồ sơ public/đích/quyền | Publisher/support/điều kiện phân phối/license/giá, owner/repo/source visibility/quyềnrelease/domainhost. Repo hiện không remote; không tự suy danh tính từ Gitauthor |
|6 | Website/phát hành/vận hành | Gallery đúng artifact đã nghiệm thu, URLversioned/checksum/releasenotes; draft/tag/manifest/site cùng build/commit; tải ẩn danhHTTPS và so hash/ký/staple/cài lại; quyềnrollback/maintenance và thử quy trình |

R01–R12 **chưa gate nào PASS đầy đủ**; R03/R06 có bằng chứng artifact local nhưng thiếu public signed artifact. Preflight read-only giữ BLOCKED_EXTERNAL/`publicReady=false`. [Readiness](../READINESS_PUBLIC.json), [candidate](../RELEASE_CANDIDATE.json), [known issues](../KNOWN_ISSUES.md), [release manifest](../RELEASE_MANIFEST.md), [runbook](../RUNBOOK_PHAT_HANH.md).

Chữ ký số hồ sơ/timestamp bên ngoài/mã hóa/kho tập trung vẫn là phạm vi sau; không tự biến thành điều kiện mới của baseline1.0. Nếu dự án cần chúng cho quy trình điều tra tổ chức, phải có phạm vi/acceptance riêng. Các tính năng batchOCR/timeline/clickpoints/PDFbảngOCR cũng chưa có và không được quảng bá như đã triển khai.

**Chặng tiếp theo:** đóng P06/A22 và các ca native độc lập trên ứng viên hiện hành, song song chuẩn bị máy đích/dữ liệu được phép dùng/đo hiệu năng để chốt P12. Sau khi có danh tính/target và nghiệm thu, mới ký P13 → hoàn thiện websiteP14 → public/postcheckP15. Hiện có thể chạy thử local với dữ liệu synthetic/được phép dùng; chưa nên phát hành rộng rãi bộ cài này.
