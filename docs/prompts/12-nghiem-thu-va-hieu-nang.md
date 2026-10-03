# P12 — Nghiệm thu V1.0 và tạo Release Candidate

Thực hiện P12 sau P11. Đọc `docs/prompts/BOI_CANH_CHUNG.md`, toàn bộ đặc tả, A01–A43, báo cáo P00–P11 và `docs/PHAT_HANH_PUBLIC.md`. Không suy ra chất lượng từ việc build thành công hoặc từ mockup.

## Công việc

1. Tạo ma trận yêu cầu → implementation → test → bằng chứng cho **từng A01–A43**. Dùng code/test thực tế, không chỉ danh sách đã tick. Rà các phần từng ghi kiểm tra một phần hoặc chưa có thiết bị.
2. Chạy build/test phù hợp, kiểm tra native vi/en, full workflow A39 và save/reopen/export. Sửa mọi lỗi trong phạm vi V1.0, thêm regression test cho lỗi dữ liệu/hình học có thể tự động kiểm tra; không nới assertion để che sai ảnh.
3. Đo benchmark theo mục 15.2: máy/cấu hình/toolchain, fixture cố định, tối thiểu 5 lượt mỗi chỉ tiêu, trung vị/lớn nhất và p95/frame sampling phù hợp. Dùng máy thực và nêu khác biệt nếu không có M1/16 GB; không suy diễn số đo.
4. Thử 40 MP/50 layer/120 MP nguồn/5 tab và vòng lặp mở/sửa/xuất/đóng, memory/cache/GPU, lỗi giải nén/ghi file/cancel, macOS tối thiểu và phiên bản khác thực có. Bảo đảm trường hợp chạm giới hạn báo rõ, không mất dữ liệu.
5. Đối chiếu giao diện native với nguồn tham chiếu cố định ở các kích thước, đặc biệt bản tiếng Việt; sửa controls mất focus/không truy cập được. Ghi hình ảnh trước/sau cần thiết.
6. Chốt cấu hình Release Candidate version/build và commit sau các sửa lỗi. Báo cáo phải phân biệt code commit được test với commit chỉ bổ sung báo cáo; khi code thay đổi, đánh giá và chạy lại nhóm liên quan, không dùng bằng chứng stale.

## Hoàn thành khi

- A01–A43 có kết quả thực, bằng chứng và không còn lỗi bắt buộc. Mục chưa có thiết bị vẫn ghi CHƯA KIỂM CHỨNG và không coi là PASS; chỉ thay phạm vi khi người dùng quyết định rõ.
- Có báo cáo tổng, benchmark, known issues thực tế và phạm vi hỗ trợ được chứng minh. R02 được đánh giá dựa trên dữ liệu này.
- Có Release Candidate tái tạo được từ checkout/commit đã ghi, sẵn sàng P13. Thiếu chứng thư ký không làm thất bại kiểm thử chức năng local.

Ghi `docs/bao-cao/P12.md` cùng ma trận đầy đủ, cập nhật tiến độ/checklist. Nếu còn blocker, sửa hoặc mô tả chính xác điều kiện bên ngoài cần có; không tự public bản thiếu nghiệm thu.
