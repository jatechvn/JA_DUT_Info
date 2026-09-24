# JA DUT Info — Release Notes v2.3.1

Phiên bản **v2.3.1** tập trung giải quyết triệt để hiện tượng thông số `CPU` (Baseband) và `RF` hiển thị `N/A` khi khởi động lại thiết bị (DUT Reboot), nâng cao độ tin cậy và khả năng tự phục hồi của toàn bộ hệ sinh thái quét thông tin phần cứng.

---

## 🌟 Điểm Mới Nổi Bật trên v2.3.1

### 1. 🔄 Tự Động Chờ Hoàn Tất Khởi Động (Android Boot Completion Detection)
- Khi DUT khởi động lại, dịch vụ ADB (`adbd`) khởi chạy rất sớm trước khi hệ thống Android hoàn tất nạp các daemon phần cứng và modem.
- `JA_DUT_Info` tự động giám sát thuộc tính `sys.boot_completed == '1'` hoặc `dev.bootcomplete == '1'` với thời gian chờ tối đa 60 giây.
- Trong lúc thiết bị đang khởi động, quả cầu hiển thị trạng thái `BOOTING` kèm tooltip `DUT đang khởi động (Đang chờ boot xong)...`, tuyệt đối không đọc vội các thuộc tính rỗng.
- Thêm khoảng đệm an toàn **1.5 giây (Grace Period)** sau khi boot xong trước khi bắt đầu truy vấn phần cứng.
- Tự động phát hiện khi thiết bị đang kết nối bắt đầu reboot (`sys.boot_completed != '1'`) và tự động chuyển về chế độ chờ boot thông minh.

### 2. 🔁 Cơ Chế Quét Lặp Thông Số Đa Tầng (Multi-Retry Parameter Acquisition)
- **CPU (Baseband Modem):**
  - Thực hiện vòng lặp thử lại tối đa 10 lần (chu kỳ 1.5 giây, tổng cộng 15 giây).
  - Tích hợp 3 lớp cơ chế dự phòng tự động: `gsm.version.baseband` $\to$ `gsm.version.baseband1` $\to$ `ro.boot.baseband` / `ro.baseband`.
  - Loại bỏ hoàn toàn lỗi hiển thị `N/A` do tiến trình RIL (`qcrild`) khởi động trễ hơn hệ điều hành.
- **PCASN, SYSSN, SYSPN, LCMPN, IMEI:**
  - Bổ sung vòng lặp thử lại tối đa 5 lần với thời gian chờ 1 giây giữa các lần để đảm bảo bus giao tiếp I2C/EEPROM đã sẵn sàng trước khi kết luận giá trị.

### 3. 📡 Tăng Cường Độ Tin Cậy Xác Minh Sóng Vô Tuyến RF (Resilient RF Verification)
- **PowerG Card Detection:** Vòng lặp kiểm tra nhận diện card phần cứng tối đa 10 lần (1.5s/lần). Tự động kích hoạt cờ phần cứng `qolsys.factory.hwd = 1` nếu card đã được nạp protocol nhưng daemon discovery chưa kết thúc.
- **PowerG Service Auto-Start:** Kiểm tra trạng thái đăng ký của `powergservice` trong ServiceManager. Tự động gửi lệnh `start powergd` qua init nếu daemon chưa chạy.
- **SRF Matrix & Daemon Readiness:** Tự động kiểm tra và khởi chạy `srfslotd` / `srfd` khi cần thiết và thử lại đọc ma trận khe cắm tối đa 10 lần.
- Chỉ hiển thị `N/A - Không có card` sau khi toàn bộ các lần thử lại và lệnh khởi động daemon hoàn tất mà không phát hiện được phần cứng.

---

## 🛠️ Yêu Cầu Hệ Thống & Tương Thích
- Hệ điều hành: Windows 10, Windows 11 (64-bit).
- Quyền hạn: Người dùng tiêu chuẩn (Standard User), không yêu cầu quyền Quản trị viên (Administrator).
- Môi trường: Mạng LAN nội bộ hoặc máy trạm độc lập kết nối ADB.
