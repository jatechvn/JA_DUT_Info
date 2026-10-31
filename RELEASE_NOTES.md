# JA DUT Info — Release Notes v2.6.0

Phiên bản **v2.6.0** tích hợp module **Tự động điền Serial/Part Number (`Auto SN/PN`) & xác minh tắt USB Debug tự động** với file cấu hình JSON ngoài (`auto_sn_config.json`), bổ sung **hỗ trợ giao thức PowerG V4 Node (`-u 6`) cho dòng IQ Remote PowerG 5 (`IQR5EU0` / `IQR5NA0`)**, và **chuẩn hóa đọc phiên bản Baseband `CPU` qua `persist.version.baseband`** (loại bỏ giá trị `"msm"` ảo trên thiết bị Wi-Fi).

---

## 🌟 Điểm Mới Nổi Bật trên v2.6.0

### 1. 🤖 Tự Động Điền SN/PN (`javaw.exe`) & Xác Minh Tắt USB Debug (`AutoSnService`)
- **Tự động điền SN & PN vào cửa sổ Java:** Tự động phát hiện hộp thoại nhập SN của công cụ Java (`Please scan System SN`, `Scan the System Serial Number`), đối chiếu `SYSSN` của DUT với danh sách quy tắc tiền tố để tự động điền `SYSSN`, `Tab`, `SYSPN` và `Enter`.
- **Cấu hình JSON linh hoạt (`auto_sn_config.json`):** Toàn bộ quy tắc tiền tố (`prefix`, `length`, `partNumber`, `autoEnter`) nằm trong file `auto_sn_config.json` cạnh file thực thi, cho phép thêm/sửa model mới bằng Notepad và tự động áp dụng ngay mà không cần build lại app.
- **Đối soát sau nạp & tự động tắt USB Debug:** Sau khi cửa sổ `javaw.exe` đóng, ứng dụng tự động đọc lại `SYSSN`/`SYSPN` trên DUT: nếu khớp hoàn toàn sẽ tự động chạy `settings put global adb_enabled 0` để tắt USB Debug; nếu sai lệch sẽ giữ nguyên ADB và hiển thị cảnh báo đỏ để kiểm tra lại.
- **Nút bật/tắt 1-Click:** Chuyển đổi nhanh `AUTO SN: ON/OFF` ngay trên thanh tiêu đề hoặc menu chuột phải.

### 2. 📡 Hỗ Trợ IQ Remote PowerG 5 (`IQR5`) & Giao Thức PowerG V4 Node (`-u 6`)
- **Tự động nhận diện giao thức Node (`-u 6`):** Trên dòng bàn phím phụ IQ Remote PowerG 5 (`IQR5EU0`, `PCASN: QB95R...`, `SYSSN: QR5...`), thẻ PowerG V4 chạy firmware Node (`PGNODE`). Ứng dụng tự động kiểm tra bằng `powergv4bootload -s <slot> -u 6 -c 1` và hỗ trợ chuyển đổi dự phòng hai chiều giữa Host (`-u 0`) và Node (`-u 6`), hiển thị chính xác `MCU OK - 868 MHz (EU) [FW: 02.38]`.

### 3. 💻 Chuẩn Hóa Đọc Baseband `CPU` Trên Thiết Bị Wi-Fi (`persist.version.baseband`)
- **Loại bỏ hiển thị `"msm"`:** Bổ sung đọc `persist.version.baseband` (`BP04BP10ABM01(SC200EWFDAR14A01)`) khi `gsm.version.baseband` trống trên các model Wi-Fi (`IQR5EU0`) và lọc bỏ các giá trị nền tảng chung (`msm`, `apq`, `sdm`, `qcom`, `unknown`).

---

# JA DUT Info — Release Notes v2.5.0

Phiên bản **v2.5.0** bổ sung cơ chế **Chẩn đoán chuyên sâu lỗi thẻ SRF trên Golden Panel & dừng sớm (Fail-Fast)** (phân biệt rõ lỗi thẻ SRF Rev 1 `G16`/`D16`/`H16` không hỗ trợ phát TX, thiếu card hoặc lỗi MCU trên Golden so với lỗi thu sóng của DUT), **tinh chỉnh hộp thoại kính mờ không viền nền & tự động đóng khi rút cáp**, cùng bộ công cụ **kiểm tra hợp lệ phần cứng thông minh (`DutValidator`) và lịch sử DUT trong phiên (`DutHistoryDialog`)**.

---

## 🌟 Điểm Mới Nổi Bật trên v2.5.0

### 1. 🛡️ Chẩn Đoán Lỗi Thẻ SRF Trên Golden Panel & Fail-Fast (`GOLDEN ERR`)
- **Phân biệt chính xác lỗi Golden vs lỗi DUT:** Kiểm tra ma trận slot (`inspectGoldenSlot`) và đọc trực tiếp firmware từ MCU qua Binder `transact 14` (`GetFullPicVer`) trên cả DUT và Golden Panel.
- **Phát hiện thẻ SRF Rev 1 không hỗ trợ phát sóng TX:** Giải mã phản hồi `Parcel(0000000a)` (mã lỗi `10`) khi kích phát `transact 18`, cảnh báo rõ khi Golden Panel lắp nhầm thẻ SRF đời cũ (`G16`/`D16`/`H16` chỉ thu RX) và hướng dẫn thay bằng thẻ Rev 2 (`G26`/`D26`/`H26`).
- **Dừng sớm tức thời (Fail-Fast ~1–2s):** Hủy ngay tiến trình chờ thu `SrfReceiver.jar` trên DUT khi Golden báo lỗi phát sóng, không còn phải chờ hết 30 giây timeout.
- **Hiển thị trực quan cả 2 kênh `PG` & `SRF`:** Hàng thẻ `RF` trên cửa sổ chính hiển thị đồng thời kết quả PowerG và SRF, ưu tiên hiển thị huy hiệu **`GOLDEN ERR`** hoặc **`FAIL`** khi có kênh bất thường.

### 2. ✨ Hộp Thoại Chẩn Đoán Sóng Trong Suốt & Tự Đóng Khi Ngắt Kết Nối
- **Loại bỏ khung mờ bao quanh hộp thoại:** Toàn bộ các hộp thoại (`RfDiagnosticsDialog`, `DutHistoryDialog`, `GlassUpdateDialog`, `OtaSettingsDialog`) sử dụng nền trong suốt hoàn toàn (`barrierColor: Colors.transparent`) và tự động ẩn các thẻ thông số phía sau khi mở.
- **Tự động đóng khi rút cáp DUT:** Hộp thoại `RfDiagnosticsDialog` tự động đóng ngay lập tức khi thiết bị DUT bị ngắt kết nối khỏi máy tính, đồng thời căn giữa huy hiệu **`TRẠM`** hài hòa trên thanh tiêu đề.

### 3. 🔍 Kiểm Tra Hợp Lệ Thông Minh (`DutValidator`) & Lịch Sử Phiên Đo (`DutHistoryDialog`)
- **Cảnh báo sai lệch phần cứng tự động:** Kiểm tra chuẩn Luhn 15 số cho `IMEI` và đối chiếu chéo dòng máy IQ4/IQ5 giữa `PCASN`, `SYSSN` và `SYSPN`.
- **Đo lại từng kênh RF & Lịch sử 30 DUT gần nhất:** Hỗ trợ bấm đo lại riêng kênh PowerG hoặc SRF trong bảng chẩn đoán, lưu lịch sử 30 thiết bị trong phiên làm việc và sao chép nhanh báo cáo tổng hợp.

---

# JA DUT Info — Release Notes v2.4.6

Phiên bản **v2.4.6** tinh chỉnh hiển thị các thẻ thông tin (`InfoCard`) khi thiết bị được kết nối, đảm bảo giữ nguyên hiệu ứng kính mờ và đổ bóng sắc nét, đồng thời duy trì chuyển động quay liên tục cho biểu tượng kiểm tra sóng RF (`CircularProgressIndicator`) trong suốt thời gian hiển thị.

---

## 🌟 Điểm Mới Nổi Bật trên v2.4.6

### 1. 🎨 Hiệu Ứng Thẻ Thông Tin Khi Kết Nối (Connected Information Rows Polish)
- **Duy trì hiệu ứng Frosted Glass:** Các hàng thẻ thông số DUT (`InfoCard`) giữ nguyên bộ lọc làm mờ (`BackdropFilter`) và đổ bóng khi thiết bị đang kết nối, thẻ mở rộng và cửa sổ đang hiển thị, không bị tắt nhầm khi quả cầu chathead ở trạng thái nghỉ/mất focus.

### 2. 📡 Con Trỏ Quay Đo Kiểm RF Linh Hoạt (Continuous RF Testing Motion)
- **Chuyển động quay không gián đoạn:** Biểu tượng quay đo kiểm sóng RF chuyển sang sử dụng cổng phản ứng `TickerMode` đọc dữ liệu, duy trì hiệu ứng quay mượt mà khi cửa sổ đang mở và tự động tạm dừng an toàn khi cửa sổ bị ẩn/thu nhỏ.

### 3. 🧪 Mở Rộng Bộ Kiểm Thử Hồi Quy
- Bổ sung các bài kiểm thử tự động trong `test/main_window_power_test.dart` xác minh toàn bộ 7 thẻ thông số và con trỏ quay RF hoạt động đồng bộ.

---

# JA DUT Info — Release Notes v2.4.5

Phiên bản **v2.4.5** triển khai giải pháp tối ưu hóa năng lượng chuyên sâu **Flutter Desktop Power Optimizer** (giảm thiểu 100% tải rendering vô ích khi ứng dụng không hoạt động hoặc mất tiêu điểm, đưa mức tiêu thụ CPU/GPU về 0), đồng thời **đồng bộ tiêu đề cửa sổ Win32 và metadata nhị phân thành tên app chính thức (`JA_DUT_Info`)** thay vì tên file thực thi (`ja_dut_info`).

---

## 🌟 Điểm Mới Nổi Bật trên v2.4.5

### 1. ⚡ Flutter Desktop Power Optimizer (Tối Ưu Năng Lượng 0 FPS Khi Nghỉ)
- **Bộ điều phối năng lượng (`PowerCoordinator`):** Giám sát liên tục 4 trạng thái: hiển thị (`isVisible`), tiêu điểm OS (`isFocused`), tương tác người dùng (`isInteracting`), và thời gian nghỉ (`isIdle` sau 12 giây không thao tác).
- **Cổng phản ứng `TickerMode` toàn cục:** Đặt cổng kiểm soát Ticker ở tầng `MaterialApp.builder` phía trên toàn bộ cây widget, tự động tắt toàn bộ Ticker và con trỏ khung hình (0 FPS) khi cửa sổ mất tiêu điểm hoặc bước vào chế độ nghỉ, triệt tiêu tải GPU/CPU lặp vô hạn.
- **Bảo toàn pha & chiều chuyển động (Phase & Direction Continuity):** Quản lý chu kỳ lặp đảo chiều (`repeat(reverse: true)`) cho `_pulseAnimController` và `_stationAnimController`, đóng băng chính xác tại vị trí dừng và khôi phục mượt mà theo đúng chiều tiến/lùi trước đó mà không bị giật hay nhảy hình.
- **Tối ưu hóa an toàn thế hệ cho chữ cuộn (`MarqueeText`):** Quản lý cờ thế hệ `_epoch` cho các tác vụ trì hoãn `_waitHold` và `animateTo`, hủy ngay lập tức các timer giữ chữ khi tạm dừng, đóng băng độ lệch cuộn hiện tại và loại bỏ toàn bộ callback rò rỉ khi unmount.
- **Cách ly tuyệt đối nghiệp vụ chạy ngầm (Background Business Isolation):** Vòng lặp quét thiết bị `AdbMonitor._loop`, xử lý đo kiểm phần cứng RF (PowerG, SRF), và quét cập nhật mạng LAN OTA hoàn toàn độc lập với cổng Ticker UI. Khi có thiết bị mới cắm/rút trong chế độ nghỉ, `notifyListeners()` chỉ vẽ đúng 1 khung hình cập nhật rồi lập tức đưa ứng dụng trở lại trạng thái ngủ 0 FPS.
- **Bộ kiểm thử tự động toàn diện (`test/power_coordinator_test.dart`):** Bổ sung 8 bài kiểm thử unit & widget test xác minh trọn vẹn logic chuyển đổi trạng thái, cổng `TickerMode`, bảo toàn pha chuyển động, chữ cuộn và tính độc lập của tác vụ ngầm.

### 2. 🏷️ Đồng Bộ Tiêu Đề Cửa Sổ & Metadata Thành Tên App (`JA_DUT_Info`)
- **Tiêu đề cửa sổ Win32:** Cập nhật tiêu đề cửa sổ native trong `windows/runner/main.cpp` từ tên file thực thi `ja_dut_info` thành tên ứng dụng chính thức `JA_DUT_Info`.
- **Khởi tạo cửa sổ popup:** Trong `windows/runner/win32_window.cpp`, truyền chuỗi tiêu đề `JA_DUT_Info` trực tiếp cho `CreateWindowEx` đồng nhất trên cả Windows 10 và Windows 11, đảm bảo Task Manager, Alt-Tab, Volume Mixer và accessibility tools luôn hiển thị đúng tên app.
- **Metadata nhị phân Windows Runner (`Runner.rc`):** Đồng bộ `FileDescription`, `InternalName`, `ProductName` thành `JA_DUT_Info` (trong khi giữ nguyên `OriginalFilename` là `ja_dut_info.exe`), giúp thông tin thuộc tính file trong Windows Explorer và Task Manager hiển thị chuyên nghiệp.

---

# JA DUT Info — Release Notes v2.4.4

Phiên bản **v2.4.4** giải quyết triệt để vấn đề ứng dụng bị treo, đơ hoặc giữ kết quả cũ khi **rút cáp USB đột ngột trong quá trình đọc thông số DUT (Unplug During Acquisition)**, bổ sung cơ chế quản lý tiến trình theo phạm vi **`CommandScope`** và hủy tiến trình con an toàn.

---

## 🌟 Điểm Mới Nổi Bật trên v2.4.4

### 1. ⚡ Khắc Phục Đơ/Treo Khi Rút Cáp USB Trong Khi Đọc
- **Tách biệt luồng nạp & quét thiết bị:** Vòng lặp `_checkDevices` không còn bị chặn chờ `_loadDut` hoàn tất. Khi rút cáp USB, ứng dụng phát hiện ngay lập tức ở chu kỳ quét kế tiếp và chuyển về trạng thái `Waiting for DUT connection...` mà không bị kẹt.
- **Quản lý tiến trình theo phạm vi (`CommandScope`):** Toàn bộ tiến trình ADB, Java helper và HTTP callback phát sinh trong phiên đọc được gắn vào `CommandScope`. Khi thiết bị ngắt kết nối, phạm vi được hủy ngay lập tức và toàn bộ tiến trình con được dọn dẹp sạch sẽ mà không ảnh hưởng tới tiến trình ADB server hệ thống.
- **Giới hạn thời gian chờ lệnh (`runCmd` timeouts):** Loại bỏ việc thực thi lệnh qua shell `cmd.exe`, gọi trực tiếp tiến trình với timeout nghiêm ngặt (5s cho lệnh kiểm tra monitor, 20s cho lệnh dùng chung).
- **Ngăn ngừa ghi nhận kết quả cũ (Session Generation Guards):** Cơ chế `_loopEpoch` và `_loadGeneration` ngăn chặn các kết quả đọc muộn hoặc kết quả từ thiết bị cũ ghi đè lên phiên kết nối mới khi cắm lại cùng một thiết bị.

### 2. 🧪 Bổ Sung Bộ Kiểm Thử Hồi Quy Ngắt Kết Nối
- Tích hợp `test/disconnect_read_test.dart` bao gồm các trường hợp rút cáp khi đang đọc thông số, kết nối lại cùng serial, thiết bị offline/unauthorized, và hủy monitor an toàn.

---

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
