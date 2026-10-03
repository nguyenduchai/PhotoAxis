# Thước, Cài đặt và cách truy cập công cụ hồ sơ — 03/10/2026

**Đã thực hiện trong PhotoAxis 1.0.0 (7), DONE local.** Người dùng yêu cầu sửa chữ thước bị cắt, cải thiện Cài đặt và hướng dẫn các chức năng điều tra đã tích hợp. [Cài đặt](../HUONG_DAN_CAI_DAT.md), [quy trình điều tra](../HUONG_DAN_DIEU_TRA.md), [ADR-025](../QUYET_DINH_KY_THUAT.md).

| Nội dung | Kết quả |
| --- | --- |
| Thước | Dải ngang 28 pt, dọc 48 pt; số dọc nằm ngang; góc đơn vị riêng; gốc/zoom/pan/backing khớp canvas |
| Chữ ở mép | Chỉ vẽ nhãn nằm trọn trong bounds có lề; clip vạch; khoảng vạch tự đổi theo độ phóng |
| Đơn vị | px/mm/cm/in, quy đổi theo PPI để biểu thị kích thước in; hiệu chuẩn đo vật ở Phân tích vẫn riêng |
| Cài đặt | Bốn nhóm native Chung/Workspace/Canvas/Cọ mặc định, thẻ nội dung, cuộn/resize, reset từng nhóm và lưu tùy chọn hợp lệ |
| Workspace/Canvas | Độ rộng bảng/cột công cụ/hiện bảng/thước; nền xám tối–vừa–sáng, ô trong suốt 4/8/16 pt; cập nhật viewport trực tiếp |
| Cọ mặc định | Cỡ/độ cứng/độ đậm/Aligned cho tài liệu thêm mới; không sửa nét hoặc thông số tab hiện hữu |
| Điều tra | Thay popup thu gọn bằng bốn nút luôn hiện: Chỉnh sửa/Nguồn/Phân tích/Đầu ra, kèm mô tả theo trang |

Controller hồ sơ, audit và schema không đổi: project paint4, case2; layout JSON cũ vẫn đọc, tùy chọn mới lưu keys riêng với validation/fallback. Nền canvas chỉ đổi cách nhìn; export/project/nguồn không lấy nền hiển thị.

Full suite cuối trên macOS27.0.1/Xcode27/M1Pro32GiB/Retina2×: **191 total, 187 PASS / 1 FAIL / 3 SKIP**. FAIL duy nhất là Telex đã biết `ContentEditingTests.testInstalledVietnameseInputContext`, ASCII chưa thành tiếng Việt. Ba benchmark opt-in không chạy. **Bảy ca mới PASS**: bounds/tọa độ thước ở zoom5–1600%, backing1/2 và bốn đơn vị; góc/frame/ẩn–hiện không đổi model; legacy/corrupt/reset/persistence; cọ defaults/validation; pixel canvas khác nhưng export không đổi; bốn trang VI/EN ở260pt; Cài đặt VI/EN ở kích thước tối thiểu hosted. Ca Paint đổi screen→document dùng dung sai1e−9; equality offset giữa các nét Aligned vẫn giữ.

Release ad-hoc arm64/minOS14 **BUILD SUCCEEDED**. Project inventory, **527 khóa VI/EN/431 references**,16 release-policy tests và12 trang website PASS. `MDB_MAP_FULL`/QoS cũ vẫn hiện trong test log; gate hiệu năng không đóng.

**Native QA trên bản Release cuối:** bốn nhóm Cài đặt VI/EN; thước px/cm ở fit/100% và pan; nền đổi ngay; nhập cọ90px → tài liệu mở mới dùng90px; khởi động lại vẫn cm/nền vừa/90px. Bảng EN260pt vẫn thấy đủ bốn nút. Mở bản sao hồ sơ tổng hợp từ Nguồn, Sửa bản làm việc thành tab, Phân tích/đối chiếu trên cùng canvas, Đầu ra/xuất PNG chia sẻ. Audit độc lập14event/hash/state, byte gốc70012 và working archive/model giữ nguyên; PNG1600×640 có148200pixel che đen đục,875800pixel ngoài vùng che bằng nguồn. Không ghi ảnh riêng tư vào bằng chứng.

Native dùng Settings760×620; thử kéo cạnh qua CUA không đổi được kích thước, **không nhận đã resize native thành công**. Bố cục tối thiểu680×560 đã kiểm hosted. mm/in, alpha grid/reset/invalid controls thuộc hosted. OCR/video/hiệu chuẩn không chạy lại bằng chuột trong lượt này; bằng chứng build3/5 và hồi quy hosted vẫn đúng phạm vi đã ghi. Không thay bằng full A01–A43, máy đích hoặc dữ liệu điều tra thực.

[Bằng chứng build](bang-chung/WORKSPACE-UI-20261003/build-manifest.json), [test summary](bang-chung/WORKSPACE-UI-20261003/test-summary.json), [native audit](bang-chung/WORKSPACE-UI-20261003/native-audit.json). Ảnh thước: [VI cm](bang-chung/WORKSPACE-UI-20261003/rulers-cm-vi.png), [EN px](bang-chung/WORKSPACE-UI-20261003/rulers-px-en.png); Cài đặt [Workspace](bang-chung/WORKSPACE-UI-20261003/settings-workspace-vi.png), [Cọ](bang-chung/WORKSPACE-UI-20261003/settings-brush-vi.png); nhóm [Phân tích](bang-chung/WORKSPACE-UI-20261003/analysis-vi.png).

DMG local và GitHub CI/Pages sẽ được đối chiếu trong receipt của build7 trước bàn giao. **`releaseReady=false`**; source/website public đã được duyệt, stable installer còn thiếu Developer ID/notary/cài sạch và nghiệm thu IME/máy đích/hiệu năng/full quota. **19/43 là build3 lịch sử**, không nhận full build7. [Readiness](../READINESS_PUBLIC.json), [known issues](../KNOWN_ISSUES.md).
