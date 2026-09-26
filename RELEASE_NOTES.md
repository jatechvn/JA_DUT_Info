# JA DUT Info — Release Notes v2.4.1

Phiên bản **v2.4.1** mang đến hỗ trợ toàn diện cho nền tảng phần cứng **IQ5 (IQP5 / IQH5)**, bao gồm quy trình chẩn đoán **PowerG V4 Bootloader / MCU**, nhận diện ma trận **SRF Slot 3 & ttyHSLX**, chuẩn hóa đọc **IMEI** và cảnh báo thay màn hình **LCMPN** trên IQ5.

---

## 🌟 Điểm Mới Nổi Bật trên v2.4.1

### 1. ⚡ Hỗ Trợ Chẩn Đoán PowerG V4 Trên Nền Tảng IQ5
- **Tự động nhận diện IQ5:** Quét tiền tố PCASN `QB95` và `qolsys.sys.config` (`IQP5`, `IQH5`).
- **Giao thức PowerG V4 Bootloader:** Tự động thực thi `powergv4bootload -s <slot> -c 1` để kiểm tra toàn vẹn MCU và sóng vô tuyến Radio.
- **Tương thích đa phiên bản thư viện:** Tự động giải mã phản hồi trên cả PowerG Library v3.0 và v3.15+ (`PGHOST Received hello!`, `Found version:`, `Operation Result: SUCCESS`), trích xuất chuẩn xác phiên bản Firmware và tần số hoạt động (915 MHz US/NA hoặc 868 MHz EU).

### 2. 📡 Nhận Diện SRF Slot 3 & Dịch Vụ ttyHSLX
- **Hỗ trợ Slot 3:** Tự động nhận diện khe cắm Slot 3 chuẩn trên IQ5 (mặc định GE 319.5 MHz, linh hoạt nhận diện DSC 433 MHz hoặc Honeywell 345 MHz dựa theo Firmware flag và protocol).
- **Ánh xạ dịch vụ phát sóng Golden Panel:** Phát hiện dịch vụ `srfservice_ttyHSLX` trên IQ5 và tự động ánh xạ sang `goldenServiceName` (`srfservice_ttyHSL1`, `srfservice_ttyHSL2`, `srfservice_ttyHSL4`) để kích hoạt Golden Panel truyền phát tín hiệu kiểm thử đối soát chính xác.
- **Cơ chế dự phòng ma trận:** Bổ sung fallback kiểm tra `qolsys.srf.card`, `qolsys.srf_slot_three.card`, và `persist.qolsys.hwd.matrix` chống kết luận `N/A` sớm.

### 3. 🔍 Chuẩn Hóa Đọc IMEI & Cảnh Báo LCMPN Trên IQ5
- **Đọc IMEI:** Tự động ưu tiên lệnh `testeepapi r imeino` trên IQ5, fallback sang `testeepapi r imei` với kiểm tra regex số nguyên `^\d+$`.
- **Cảnh báo LCMPN:** Tự động phát hiện PCASN `QB95` bên cạnh tiền tố SYSSN `QP5`, `QH5`, `QP4` để hiển thị: *"Chú ý Panel này không được chạy lại màn hình"*.

### 4. 🧪 Tối Ưu Hóa Live Test Phần Cứng
- Đảm bảo chu trình ngầm của pipeline RF hoàn tất trước khi đối soát kết quả (`!monitor.isRfTesting`).

---

## 🛠️ Yêu Cầu Hệ Thống & Tương Thích
- Hệ điều hành: Windows 10, Windows 11 (64-bit).
- Quyền hạn: Người dùng tiêu chuẩn (Standard User), không yêu cầu quyền Quản trị viên (Administrator).
- Môi trường: Mạng LAN nội bộ hoặc máy trạm độc lập kết nối ADB.
