# Hướng Dẫn Sử Dụng JA DUT Info (v2.3.0)

Ứng dụng **JA DUT Info** là công cụ giám sát thông số phần cứng DUT trạm sản xuất thông minh dạng widget nổi màn hình, tích hợp kiểm tra sóng vô tuyến không dây RF tự động và cập nhật qua mạng nội bộ LAN Over-The-Air (OTA).

---

## 1. Cài Đặt & Gỡ Cài Đặt Ứng Dụng

### 1.1. Cài đặt 1-Click (Không cần quyền Quản trị viên Administrator)
1. Giải nén gói phát hành `JA_DUT_Info_v2.3.0_Windows_x64.zip`.
2. Chạy đúp chuột vào tệp `install.bat` (hoặc chạy lệnh `install.bat /silent` trong kịch bản tự động).
3. Ứng dụng sẽ được cài đặt trực tiếp vào:
   ```text
   %LOCALAPPDATA%\Programs\JA_DUT_Info
   ```
4. Kịch bản tự động tạo lối tắt (shortcut) trên màn hình Desktop và trong Start Menu (`Programs \ JA DUT Info`), đồng thời đăng ký vào Windows Control Panel (Settings > Apps & Features).

### 1.2. Gỡ cài đặt sạch sẽ
- **Cách 1:** Vào Windows Settings > Installed Apps (hoặc Control Panel > Programs and Features) $\to$ Tìm `JA DUT Info` $\to$ Chọn `Uninstall`.
- **Cách 2:** Mở menu Start $\to$ Chọn `Uninstall JA DUT Info`.
- **Cách 3:** Chạy tệp `uninstall.bat` (hoặc `uninstall.bat /silent`) trong thư mục cài đặt. Toàn bộ tệp tin, lối tắt và khóa registry sẽ được dọn dẹp sạch sẽ qua cơ chế staging an toàn trong `%TEMP%`.

---

## 2. Giám Sát Thông Số Phần Cứng DUT

Khi kết nối bảng mạch hoặc panel vào máy tính qua cáp USB ADB, widget tự động phát hiện thiết bị và hiển thị 7 thẻ thông tin:
1. **PCASN**: Số Serial của bo mạch chính (Primary PCA Serial Number).
2. **SYSSN**: Số Serial hệ thống của thiết bị hoàn chỉnh.
3. **LCMPN**: Mã linh kiện màn hình LCD / Cảm ứng.
4. **IMEI**: Số nhận dạng thiết bị di động quốc tế (đối với model có modem LTE/Cellular).
5. **BATTERY**: Phần trăm pin và trạng thái sạc (`⚡ 100%`).
6. **CPU**: Tỷ lệ sử dụng vi xử lý thời gian thực.
7. **RF**: Trạng thái kiểm tra sóng không dây vô tuyến PowerG và SRF.

> [!TIP]
> **Sao chép nhanh 1-Click:** Nhấp chuột trái vào bất kỳ thẻ nào để sao chép giá trị trực tiếp vào Clipboard. Thông báo Toast sẽ xuất hiện xác nhận nội dung đã sao chép.

---

## 3. Kiểm Tra Sóng Vô Tuyến Không Dây (RF Verification)

### 3.1. Quy trình kiểm tra tự động
- **PowerG (868 MHz EU / 915 MHz US/NA):**
  - Khi cắm DUT, hệ thống tự động xác định thẻ PowerG được lắp đặt trên bo mạch và xác định tần số theo giao thức phần cứng.
  - Bật chế độ AutoLearn (`service call powergservice 2 i32 1`) và xóa bộ đệm ID trước đó.
  - Công cụ phát sóng `PowerGTransmitter.jar` tự động kết nối qua cổng COM thiết bị nạp (Silicon Labs CP210x) và bắn gói tin cảm biến đăng ký.
  - Sau khi nhận diện thành công, hệ thống đọc ID tin nhắn đăng ký (`transact 202`), tắt chế độ AutoLearn và gắn nhãn xanh `PASS` kèm Sensor ID trên thẻ RF.
- **SRF Đa Tần Số (319.5 MHz, 345 MHz, 433 MHz):**
  - Tự động giải mã ma trận khe cắm `qolsys.srfslot.matrix` để nhận diện các module tần số hỗ trợ.
  - Gửi mã ping kiểm tra sức khỏe vi điều khiển MCU (`service call srfservice 50`).
  - Khi có thiết bị đối chuẩn **Golden Panel** (`persist.auto.run == '1'`) kết nối đồng thời, hệ thống tự động phát tín hiệu phát sóng chéo (`transact 18`) để kích hoạt kiểm tra thu phát giữa hai thiết bị.

### 3.2. Hộp thoại Chẩn đoán RF Chuyên Sâu
- Nhấp vào biểu tượng bánh răng ⚙️ trên thẻ `RF` hoặc bấm chuột phải vào quả cầu $\to$ Chọn **"Chẩn đoán RF chi tiết..."**.
- Hộp thoại **Bento Frosted Glass** sẽ hiển thị chi tiết:
  - Phiên bản Firmware PowerG, cổng COM phát sóng, tần số và ID cảm biến thu nhận.
  - Ma trận slot SRF, trạng thái vi điều khiển MCU, và thông số Golden Panel.
- Bấm nút **"Kiểm tra lại sóng RF"** để chạy lại quy trình kiểm tra sóng tức thời mà không cần rút cắm lại cáp USB.

---

## 4. Tự Động Cập Nhật Qua Mạng Nội Bộ (LAN OTA Updates)

1. **Kiểm tra tự động ngầm:**
   - Ứng dụng tự động kiểm tra bản cập nhật mới trên thư mục chia sẻ mạng LAN SMB (`\\server\share\...`) theo chu kỳ cấu hình (`Hàng ngày`, `Hàng tuần`, `Hàng tháng`).
   - Khi có phiên bản mới hơn, một đèn LED ngọc lục bảo sẽ xuất hiện trên quả cầu bong bóng.
2. **Cập nhật 1-Click:**
   - Nhấp vào đèn báo cập nhật để mở hộp thoại Kính Mờ `GlassUpdateDialog`.
   - Xem chi tiết phiên bản mới, dung lượng gói và nhật ký cập nhật (Release Notes).
   - Nhấp **"Cập nhật ngay"**: Ứng dụng sẽ tự động tải gói nén, giải nén và kích hoạt kịch bản nâng cấp nguyên tử, tự khởi động lại ứng dụng mà không làm mất cấu hình hay log kiểm tra.
3. **Cài đặt LAN OTA:**
   - Bấm chuột phải vào quả cầu $\to$ Chọn **"Cài đặt LAN OTA..."**.
   - Cung cấp đường dẫn UNC máy chủ chia sẻ, thiết lập chu kỳ quét tự động hoặc bấm **"Kiểm tra bản cập nhật ngay"**.

---

## 5. Thao Tác Giao Diện & Điều Khiển

- **Di chuyển vị trí:** Kéo giữ chuột trái vào quả cầu tròn và thả tại bất kỳ vị trí nào trên màn hình.
- **Ẩn nép mép màn hình (Edge Docking):** Kéo widget sát mép trái hoặc phải màn hình. Quả cầu sẽ tự động thụt vào mép 80% chỉ để lại một tab lưỡi liềm phát sáng 25px.
- **Nhãn Station nghiêng theo dây:** Khi ở trạng thái nép mép, nhãn tên trạm sản xuất tự động trượt ra giữa đoạn dây cong Bézier và nghiêng mượt theo chiều của dây, giúp quan sát kết quả trạm dễ dàng mà không bị che khuất.
- **Click xuyên khoảng trống:** Mọi khoảng trống trong suốt xung quanh widget cho phép click chuột, quét khối và cuộn chuột tương tác bình thường với các ứng dụng nền (Telegram, trình duyệt, Word, Excel).
- **Thu gọn / Mở rộng:** Nhấp chuột trái vào quả cầu để co rút hoặc bung tỏa các thẻ thông số.
- **Menu chuột phải:** Đổi chủ đề Sáng / Tối, đổi thiết bị DUT (khi cắm nhiều thiết bị), kích hoạt kiểm tra sóng RF, hoặc đóng ứng dụng.
