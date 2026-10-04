# Bằng chứng build 9 — Cài đặt và kiểm thử toàn ứng dụng

`final-*.png/txt`, `native-final-observations.json`, `native-final-audit.json` thuộc Release cuối UUID7071B413-36F3-3955-B896-7BA783D2A75F. Các ảnh không có tiền tố `final-` và `prototype-native-observations.json` là lượt native trước sửa validation độc lập ở Cài đặt; giữ lịch sử, không dùng thay bằng chứng binary cuối. `settings-brush-resize-attempt-vi.png` chỉ ghi nỗ lực resize không thành công. Minimum layout được kiểm bằng hosted tests.

`debug-test.log`/`test-summary.json`: 210 tổng,206PASS/1FAILTelex/3SKIPbenchmark. `ci-summary.json`/`ci.log`: 210 tổng,205PASS/0FAIL/5SKIP, toolchain khác; không phủ nhận FAIL local. `release-policy.log`:16PASS. `release-benchmark.log` và benchmark JSON:3PASS riêng, trước sửa Settings-only validation, UUID/commit/testability riêng tại `benchmark-provenance.json`. Không nhận worker throughput là native input-to-present.

`build-manifest.json` ghi compiledProductCodeCommit và inventory fingerprint sau cập nhật số liệu website; chỉ scripts/build-website.py đổi sau compile, byte Sources/Tests/Config/Fixtures/project không đổi. QA bundleID/name/signature riêng nên executableSHA khác, UUID/Core bằng Release.

Chỉ fixture tổng hợp được dùng trong ảnh. Paths được thay bằng $BUILD_ROOT/$REPO. DMG local ad-hoc và Pages có receipt riêng khi hoàn tất giao.
