# JA DUT Info — Release Notes v2.4.3

Phiên bản **v2.4.3** nâng cấp toàn diện cơ chế đo kiểm và thu nhận sóng không dây **SRF (GE 319.5 MHz, Honeywell 345 MHz, DSC 433 MHz)** trên cả hai dòng thiết bị **IQ4** và **IQ5**, đảm bảo kết quả **RF PASS** phản ánh chính xác việc DUT thực sự thu nhận đủ gói tin không dây với cường độ tín hiệu đạt chuẩn, thay vì chỉ dựa vào tín hiệu phát từ Golden Panel.

---

## 🌟 Điểm Mới Nổi Bật trên v2.4.3

### 1. 📡 Xác Thực Thu Sóng Thực Tế SRF (Live DUT-Side Packet Reception)
- **Bãi bỏ PASS ảo:** Không còn suy đoán RF PASS từ phản hồi phát của Golden Panel. Ứng dụng hiện trực tiếp giám sát luồng dữ liệu thu trên DUT.
- **Helper Nhúng Java DEX (`SrfReceiver.jar`):** Triển khai receiver chuyên dụng chạy trực tiếp trong không gian người dùng của thiết bị DUT qua `app_process`.
- **Giải mã khung truyền UDP 9950 (19-byte):** Lắng nghe cổng UDP 9950 khi kích hoạt transaction 11 (event 80) trên dịch vụ `srfservice_ttyHSLX`, trích xuất chuẩn xác Air ID (`25390A` cho GE 319.5MHz; `49CA0A` cho Honeywell/DSC).
- **Đo lường RSSI chuẩn xác theo Disassembly:** Hiệu chuẩn chuẩn xác vị trí byte 14 trong khung truyền theo công thức `unsigned(byte14) / 2 - 134 dBm`, yêu cầu cường độ tín hiệu >= -99 dBm và nhận đủ tối thiểu 5 gói tin.
- **Bảo vệ hệ thống & dọn dẹp an toàn:** Tự động gửi event 81 để đóng listener ngay khi hoàn tất, đóng DatagramSocket và kích hoạt cơ chế watchdog fail-closed chống kẹt cổng hoặc rò rỉ socket trên DUT.

### 2. 🔌 Tối Ưu Hóa Dò Cổng Bộ Phát Sóng PowerG
- Sử dụng truy vấn WMI `Win32_SerialPort` kết hợp bộ lọc driver phần cứng `CP210|Silicon|UART`, đảm bảo trích xuất chính xác tên cổng COM (`COMx`) của bộ nạp/phát sóng PowerG.

### 3. 🧪 Bổ Sung Bộ Kiểm Thử Tự Động & Hồi Quy Chặt Chẽ
- Thêm kiểm thử mô phỏng tiến trình receiver và bộ kiểm thử trực tiếp trên thiết bị IQ5 thực tế (`test/iq5_rf_live_test.dart`), đảm bảo độ ổn định cao nhất trong dây chuyền sản xuất.

---

# JA DUT Info — Release Notes v2.4.2

Phiên bản **v2.4.2** nâng cấp toàn diện cơ chế nhận diện phần cứng và đo kiểm sóng vô tuyến RF cho dòng thiết bị **IQ4 (cả biến thể 868 MHz EU và 915 MHz NA/LATAM/ANZ)**, khắc phục triệt để lỗi thiết bị bị nhận diện thành `DUT` / `N/A` và tần số PowerG bị hiển thị `N/A` khi cắm đồng thời 2 cục phát.

---

## 🌟 Điểm Mới Nổi Bật trên v2.4.2

### 1. 📡 Giải Mã Giao Thức Đa Tầng Cho Card PowerG 868 MHz & 915 MHz
- **Quét toàn diện thuộc tính IQ4:** Ưu tiên đọc `qolsys.slot_one.protocol` (chuẩn do `hw_discov` thiết lập trên IQ4: 9 = 868MHz, 8 = 915MHz), kết hợp chuỗi dự phòng `qolsys.powergv4.protocol`, `persist.qolsys.powergv4.protocol`, `qolsys.powerg.protocol`, `persist.qolsys.powerg.protocol`, ma trận thẻ `qolsys.card.matrix` (800M/900M) và `syspn` (IQP4004/4008/4009 vs IQP4001/4002/4003).
- **Chống phán đoán vội `Không có card`:** Kiểm tra song song `qolsys.powerg.card`, `qolsys.powergv4.card`, mã protocol khả dụng và trạng thái `service check powergservice`. Không còn bị kết luận sai `N/A - Không có card`.
- **Đọc Firmware dự phòng đa nguồn:** Tự động quét qua `qolsys.powergv4.fw`, `qolsys.powerg.fw`, `qolsys.powerg.radio.fw`, và ma trận phần cứng `persist.qolsys.hwd.matrix` (trích xuất `83.03` / `83.16`).
- **Kích phát sóng theo đúng tần số:** Tự động điều hướng bộ phát `PowerGTransmitter.jar` phát chuẩn `868` cho card 868MHz, `915` cho card 915MHz khi cắm đồng thời 2 cục sóng trên máy tính.

### 2. 🎯 Nhận Diện Chủng Loại Thiết Bị IQ4 Đa Dạng
- **Hỗ trợ toàn diện tiền tố:** Tự động nhận diện IQ4 qua mọi tiền tố PCASN (`QB94`, `QB84`, `QB74`, `QB64`, `QC94`, `QD94`), thuộc tính hệ thống Android `ro.build.product` (`lucy`), `ro.product.device`, và cấu hình `qolsys.sys.config` (`IQP4`, `IQH4`, `IQ4`).
- **Khối cầu nổi thông minh:** Hiển thị tức thời biểu tượng tím `IQ4` ngay từ giây đầu tiên cắm DUT, không còn rơi về `DUT` hoặc `NO DATA`.

### 3. 📊 Hoàn Thiện Hiển Thị Thẻ RF
- Thẻ `RF` hiển thị chuẩn trạng thái `PG: PASS (868 MHz (EU))` hoặc `MCU OK - 868 MHz (EU)` ngay cả khi panel không có card SRF (như dòng IQ4 868MHz).

### 4. 🎨 Biểu Tượng Logo Ứng Dụng Mới (Multi-Resolution Windows Executable Icon)
- Thay thế icon mặc định bằng bộ biểu tượng chính thức từ `assets/logo/logo.ico`.
- Nhúng bộ icon đa kích cỡ chuẩn Windows (256x256 đến 16x16, 32-bit RGBA) trực tiếp vào file thực thi `ja_dut_info.exe` và các lối tắt Desktop/Start Menu.

### 5. 📦 Đóng Gói Phân Phối Chuẩn & Nâng Cấp Kịch Bản
- Tối ưu hóa `package_dist.ps1` bảo toàn cấu hình `dist/`, cập nhật gói cài đặt tự động `install.bat` và `uninstall.bat`.

---

# JA DUT Info — Release Notes v2.4.1

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
