# Scan1 native Release QA — 03/10/2026

App1.0.0(4), UUID 8A2E6A7C-4058-391B-A8F6-24F1BB32D380. Hai bản QA VI/EN có BundleID riêng, ad-hoc resign và recovery riêng; UUID/Core đã đối chiếu Release. Source implementation 4947ff7f821929a4982085a5611442f3ccfe20e8, fingerprint c8955473c908b16e1d9f402141b6f796b9c7b71360038fdfe36aee5470d39aeb.

- NativeVI: mở fixture dirty-paper.png72PPI; menuẢnh có Scan/batch. Preview nguồn giấy ám màu bên trái/kết quả trắng bên phải, đầy đủ nhãn kích thước/PPI; chụp native-scan-final-vi.png. Apply→300PPI;CmdZ→72PPI;CmdShiftZ→300PPI.
- NativeEN: mở cùng fixture; DocumentScan/controlsEnglish, preview đúng; native-scan-final-en.png. Cancel giữ72PPI.
- NativeENbatch: OpenPanel chọn01.png/02.png; pageDown đổi thành02/01. Preview/sample được ghi tên riêng. Folderpicker GoTo đặt QA/Scan-Final-20261003/BatchOutput; Export hoàn tất và trả workspace. Đối chiếu sourcebyte/hash/PNG/project/PDF/hash/schema3/thứ tự PASS, native-batch-check.json/manifest.json. Autopage/deskew bật, các trang có warnings cần rà.
- Screenshot native-batch-final-en.png chụp trước đổi thứ tự, không suy screenshot là receipt thứ tự cuối. native-scan-vi.png là capture trước lượt final, giữ lịch sử.

Không dùng ảnh người dùng; mọi input là fixture tự tạo. Testhost native không chứng nhận chuột vật lý/fullaccessibility/macOS14 hoặc fullquota. Binary Final không thay khi bổ sung test về pageorder sau buildRelease; chỉ Tests thay, fullsuite159ca đã chạy lại trên mã cuối.
