# JA DUT Info — Release Notes v2.4.0

Phiên bản **v2.4.0** mang đến tính năng **Tự động khởi động cùng Windows (Autostart)**, **Thanh Capsule đổi DUT nhanh trực quan nổi phía trên thẻ PCASN (`DutSwitchHeader`)**, **Tái cấu trúc tương tác thẻ RF**, và **Tối ưu hóa quy trình đóng gói phát hành**.

---

## 🌟 Điểm Mới Nổi Bật trên v2.4.0

### 1. ⚡ Tùy Chọn Khởi Động Cùng Windows (Windows Autostart Option)
- **Mặc định bật khi cài đặt:** Bộ cài `install.bat` tự động đăng ký khóa `HKCU\Software\Microsoft\Windows\CurrentVersion\Run\JA_DUT_Info` (không yêu cầu quyền Quản trị viên Administrator).
- **Gỡ bỏ sạch sẽ:** `uninstall.bat` và `uninstall.ps1` tự động làm sạch khóa Registry khi gỡ bỏ ứng dụng.
- **Bật/Tắt 1-Click trong App:** Nhấp chuột phải vào Chathead bubble, chọn mục **`[✓] Khởi động cùng Windows`** để bật hoặc tắt bất kỳ lúc nào kèm thông báo xác nhận tức thời.

### 2. 📱 Thanh Capsule Đổi DUT Nhanh Nổi Trên Thẻ PCASN (`DutSwitchHeader`)
- Thiết kế thanh capsule mỏng (cao 18px, rộng 175px) hiển thị trực quan thông số thiết bị: Icon `📱` + `DUT: <serial> (<vị_trí>/<tổng_số>)` + Nút chip chuyển đổi `[⇄ ĐỔI]`.
- **Thao tác 1-Click:** Nhấp chuột trực tiếp vào capsule để chuyển đổi xoay vòng sang DUT tiếp theo với thông báo xác nhận `Đã chuyển sang DUT: <serial>`.
- **Thông minh & Thích ứng theo vị trí:**
  - Tự động ẩn khi chỉ có 1 DUT để giữ giao diện tối giản; tự động xuất hiện khi có $\ge 2$ thiết bị DUT kết nối.
  - Vị trí tự căn lệch đối xứng tránh va chạm với Chathead bubble hoặc nhãn Station.
  - Đồng bộ hiệu ứng nảy / thu gọn ăn khớp 100% với các thẻ thông số.
  - Tích hợp Win32 Native Hit-Test chống click xuyên thấu nền.

### 3. 🎯 Tái Cấu Trúc Tương Tác Thẻ RF (RF Card Tap & Layout Refactor)
- Nhấp chuột vào bất kỳ đâu trên hàng thẻ RF để kích hoạt kiểm tra lại sóng vô tuyến (`retestRf()`).
- Nhấp vào biểu tượng cài đặt `tune` ở cuối hàng để mở hộp thoại Chẩn đoán Bento chi tiết (`RfDiagnosticsDialog`).
- Loại bỏ nút refresh riêng lẻ để giải phóng toàn bộ không gian ngang cho chữ marquee cuộn thông số RF.

### 4. 📦 Tối Ưu Hóa Kịch Bản Đóng Gói Phát Hành (`build.bat` & `package_dist.ps1`)
- Chuyển đổi cơ chế đồng bộ sang Robocopy `/MIR` in-place, loại bỏ triệt để lỗi xung đột khóa file `ERROR_SHARING_VIOLATION` khi đóng gói vào `dist/`.

---

## 🛠️ Yêu Cầu Hệ Thống & Tương Thích
- Hệ điều hành: Windows 10, Windows 11 (64-bit).
- Quyền hạn: Người dùng tiêu chuẩn (Standard User), không yêu cầu quyền Quản trị viên (Administrator).
- Môi trường: Mạng LAN nội bộ hoặc máy trạm độc lập kết nối ADB.
