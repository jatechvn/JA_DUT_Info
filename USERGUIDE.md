# Hướng Dẫn Sử Dụng JA DUT Info (v2.4.0)

Ứng dụng **JA DUT Info** là công cụ giám sát thông số phần cứng DUT trạm sản xuất thông minh dạng widget nổi màn hình, tích hợp khởi động cùng Windows (Autostart), thanh capsule đổi DUT nhanh trực quan, phát hiện hoàn tất khởi động (Boot Completion Detection), quét lặp thông số đa tầng (Multi-Retry), kiểm tra sóng vô tuyến không dây RF tự động và cập nhật qua mạng nội bộ LAN Over-The-Air (OTA).

---

## 1. Cài Đặt & Gỡ Cài Đặt Ứng Dụng

### 1.1. Cài đặt 1-Click (Không cần quyền Quản trị viên Administrator)
1. Giải nén gói phát hành `JA_DUT_Info_v2.4.0_Windows_x64.zip`.
2. Chạy đúp chuột vào tệp `install.bat` (hoặc chạy lệnh `install.bat /silent` trong kịch bản tự động).
3. Ứng dụng sẽ được cài đặt trực tiếp vào:
   ```text
   %LOCALAPPDATA%\Programs\JA_DUT_Info
   ```
4. **Tự động khởi động cùng Windows:** Kịch bản cài đặt tự động kích hoạt tính năng chạy cùng Windows cho người dùng hiện tại mà không đòi hỏi quyền Admin.
5. Kịch bản tự động tạo lối tắt (shortcut) trên màn hình Desktop và trong Start Menu (`Programs \ JA DUT Info`), đồng thời đăng ký vào Windows Control Panel (Settings > Apps & Features).

### 1.2. Gỡ cài đặt sạch sẽ
- **Cách 1:** Vào Windows Settings > Installed Apps (hoặc Control Panel > Programs and Features) $\to$ Tìm `JA DUT Info` $\to$ Chọn `Uninstall`.
- **Cách 2:** Mở menu Start $\to$ Chọn `Uninstall JA DUT Info`.
- **Cách 3:** Chạy tệp `uninstall.bat` (hoặc `uninstall.bat /silent`) trong thư mục cài đặt. Toàn bộ tệp tin, lối tắt và khóa Registry tự khởi động sẽ được dọn dẹp sạch sẽ qua cơ chế staging an toàn trong `%TEMP%`.

---

## 2. Giám Sát Thông Số Phần Cứng DUT & Đổi Thiết Bị Nhanh

Khi kết nối bảng mạch hoặc panel vào máy tính qua cáp USB ADB, widget tự động phát hiện thiết bị và hiển thị các thẻ thông tin:
1. **PCASN**: Số Serial của bo mạch chính (Primary PCA Serial Number).
2. **SYSSN**: Số Serial hệ thống của thiết bị hoàn chỉnh.
3. **SYSPN**: Mã sản phẩm hệ thống.
4. **LCMPN**: Mã linh kiện màn hình LCD / Cảm ứng.
5. **IMEI**: Số nhận dạng thiết bị di động quốc tế (đối với model có modem LTE/Cellular).
6. **CPU**: Tỷ lệ sử dụng vi xử lý và phiên bản Baseband Modem.
7. **RF**: Trạng thái kiểm tra sóng không dây vô tuyến PowerG và SRF.

### 2.1. Đổi Thiết Bị Nhanh Với Thanh Capsule Nổi (`DutSwitchHeader`)
- Khi trạm kiểm thử kết nối **từ 2 DUT trở lên**, một thanh capsule nhỏ gọn màu kính mờ sẽ tự động xuất hiện phía trên thẻ `PCASN`:
  ```text
  [ 📱 DUT: <serial> (1/2)   ⇄ ĐỔI ]
  ```
- **Thao tác 1-Click:** Nhấp chuột trực tiếp vào thanh capsule để đổi vòng lặp sang thiết bị tiếp theo ngay lập tức. Màn hình sẽ hiển thị thông báo xác nhận: `Đã chuyển sang DUT: <serial>`.
- **Tự ẩn/hiện thông minh:** Khi chỉ cắm 1 DUT, capsule tự động ẩn đi để giữ giao diện tối giản.

### 2.2. Cơ Chế Chờ Hoàn Tất Khởi Động & Chống N/A (DUT Reboot)
- Nếu DUT đang khởi động lại hoặc cắm vào khi chưa boot xong, quả cầu sẽ hiển thị trạng thái `BOOTING`. Hệ thống sẽ kiên nhẫn chờ Android khởi động hoàn tất (`sys.boot_completed == 1`) và tự động thử lại nhiều lần (multi-retry) để lấy đầy đủ Baseband CPU và sóng RF, loại bỏ hoàn toàn tình trạng hiển thị `N/A` ảo.

> [!TIP]
> **Sao chép nhanh 1-Click:** Nhấp chuột trái vào bất kỳ thẻ nào để sao chép giá trị trực tiếp vào Clipboard. Thông báo Toast sẽ xuất hiện xác nhận nội dung đã sao chép.

---

## 3. Kiểm Tra Sóng Vô Tuyến Không Dây RF Tự Động

### 3.1. Thao Tác Thẻ RF
- **Kiểm tra lại sóng tức thời (Retest RF):** Nhấp chuột trực tiếp vào hàng thẻ `RF` để kích hoạt kiểm tra lại sóng vô tuyến ngay tại chỗ.
- **Mở hộp thoại Chẩn đoán chi tiết:** Nhấp vào biểu tượng bánh răng cài đặt `tune` ở góc phải hàng thẻ `RF` (hoặc mở menu chuột phải $\to$ Chọn "Chẩn đoán RF chi tiết...").

### 3.2. Chu Trình Tự Động Thu Phát Sóng
- **PowerG (868 MHz / 915 MHz):**
  - Tự động nhận diện card PowerG, bật chế độ AutoLearn và xóa bộ đệm cũ.
  - Công cụ phát sóng `PowerGTransmitter.jar` tự động kết nối qua cổng COM thiết bị nạp (Silicon Labs CP210x) và bắn gói tin cảm biến đăng ký.
  - Sau khi nhận diện thành công, hệ thống đọc ID tin nhắn đăng ký, tắt chế độ AutoLearn và hiển thị kết quả `PASS` kèm Sensor ID.
- **SRF Đa Tần Số (319.5 MHz, 345 MHz, 433 MHz):**
  - Tự động giải mã ma trận khe cắm `qolsys.srfslot.matrix` để nhận diện các module tần số hỗ trợ.
  - Gửi mã ping kiểm tra sức khỏe vi điều khiển MCU.
  - Khi có thiết bị đối chuẩn **Golden Panel** (`persist.auto.run == '1'`) kết nối đồng thời, hệ thống tự động phát tín hiệu phát sóng chéo (`transact 18`) để kích hoạt kiểm tra thu phát giữa hai thiết bị.

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

- **Khởi động cùng Windows:** Bấm chuột phải vào quả cầu $\to$ Tích chọn hoặc bỏ chọn **`[✓] Khởi động cùng Windows`** để bật hoặc tắt bất kỳ lúc nào.
- **Di chuyển vị trí:** Kéo giữ chuột trái vào quả cầu tròn và thả tại bất kỳ vị trí nào trên màn hình.
- **Ẩn nép mép màn hình (Edge Docking):** Kéo widget sát mép trái hoặc phải màn hình. Quả cầu sẽ tự động thụt vào mép 80% chỉ để lại một tab lưỡi liềm phát sáng 25px.
- **Nhãn Station nghiêng theo dây:** Khi ở trạng thái nép mép, nhãn tên trạm sản xuất tự động trượt ra giữa đoạn dây cong Bézier và nghiêng mượt theo chiều của dây, giúp quan sát kết quả trạm dễ dàng mà không bị che khuất.
- **Click xuyên khoảng trống:** Mọi khoảng trống trong suốt xung quanh widget cho phép click chuột, quét khối và cuộn chuột tương tác bình thường với các ứng dụng nền (Telegram, trình duyệt, Word, Excel).
- **Thu gọn / Mở rộng:** Nhấp chuột trái vào quả cầu để co rút hoặc bung tỏa các thẻ thông số.
- **Menu chuột phải:** Đổi chủ đề Sáng / Tối, bật/tắt khởi động cùng Windows, đổi thiết bị DUT (khi cắm nhiều thiết bị), kích hoạt kiểm tra sóng RF, hoặc đóng ứng dụng.
