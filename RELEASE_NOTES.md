# JA DUT Info — Release Notes v2.3.0

Phiên bản phát hành chính thức **v2.3.0** bổ sung bộ giải pháp toàn diện cho việc kiểm tra sóng vô tuyến không dây (PowerG & SRF), tích hợp cơ chế cập nhật tự động qua mạng nội bộ LAN Over-The-Air (OTA) và bộ cài đặt Windows chuẩn không cần quyền Administrator.

---

## 🌟 Điểm Mới Nổi Bật

### 1. 📡 Kiểm Tra Sóng Vô Tuyến Không Dây Tự Động (RF Verification)
- **PowerG (868 MHz EU / 915 MHz US/NA):**
  - Tự động nhận diện card PowerG và ánh xạ dải tần số dựa trên giao thức (Protocol 8: 915 MHz, Protocol 9: 868 MHz).
  - Tự động kích hoạt chế độ AutoLearn và xóa bộ đệm cảm biến trước khi kiểm thử.
  - Tích hợp công cụ phát sóng `PowerGTransmitter.jar` tự động kết nối qua cổng COM Silicon Labs CP210x USB UART Bridge.
  - Thăm dò ID đăng ký của cảm biến (`transact 202`) và hiển thị kết quả `PASS` kèm Sensor ID và phiên bản Firmware.
- **SRF Đa Slot (319.5 MHz, 345 MHz, 433 MHz):**
  - Tự động giải mã ma trận `qolsys.srfslot.matrix` (Slot 1 GE, Slot 2 DSC, Slot 4 Honeywell).
  - Kiểm tra trạng thái sống của MCU qua mã giao dịch `transact 50`.
  - Tự động phát hiện panel đối chuẩn **Golden Panel** (`persist.auto.run == '1'`) và gửi lệnh kích hoạt phát sóng chéo (`transact 18`).
- **Hộp thoại Chẩn đoán Bento Frosted Glass (`RfDiagnosticsDialog`):**
  - Giao diện kính mờ với hai khối thông số riêng biệt cho PowerG và SRF.
  - Nút **"Kiểm tra lại sóng RF"** và phím tắt `Esc` đóng nhanh.

### 2. 🚀 Cập Nhật Qua Mạng LAN Over-The-Air (LAN OTA Updates)
- Tự động quét gói cập nhật mới từ thư mục chia sẻ nội bộ UNC (`\\server\share\...`) theo chuẩn SemVer.
- Hộp thoại Kính mờ `GlassUpdateDialog` hiển thị tiến trình tải, dung lượng gói và nhật ký cập nhật.
- Cơ chế cập nhật nguyên tử bằng Robocopy và `apply_update.bat`, bảo toàn toàn bộ cấu hình và file nhật ký (logs).
- Hộp thoại cấu hình chu kỳ kiểm tra tự động (`Hàng ngày`, `Hàng tuần`, `Hàng tháng`, `Tắt`).

### 3. 📦 Bộ Ba Cài Đặt & Gỡ Bỏ Windows Chuẩn (Zero-Privilege)
- `install.bat`: Cài đặt 1-click vào `%LOCALAPPDATA%\Programs\JA_DUT_Info` không đòi hỏi quyền Admin, tạo shortcut Desktop, Start Menu và đăng ký Control Panel.
- `uninstall.bat` & `uninstall.ps1`: Kịch bản staging an toàn qua `%TEMP%` giúp gỡ cài đặt sạch sẽ mà không bị lỗi khóa file đang chạy.

### 4. 📐 Tối Ưu Bố Cục 7 Thẻ & Click Xuyên Khoảng Trống
- Thêm thẻ thứ 7 (`RF`) với thông số chiều cao `cardHeight = 26.0px` và khoảng cách `cardGap = 5.0px`, giữ tổng chiều cao widget gọn trong 212px.
- Cập nhật vùng nhận diện chuột Win32 native hit-testing cho 7 thẻ, đảm bảo click xuyên khoảng trống xuống ứng dụng nền hoạt động mượt mà với 0% CPU.

---

## 🛠️ Yêu Cầu Hệ Thống & Tương Thích
- Hệ điều hành: Windows 10, Windows 11 (64-bit).
- Quyền hạn: Người dùng tiêu chuẩn (Standard User), không yêu cầu quyền Quản trị viên (Administrator).
- Môi trường: Mạng LAN nội bộ hoặc máy trạm độc lập kết nối ADB.
