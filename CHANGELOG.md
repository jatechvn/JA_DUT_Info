# Changelog

All notable changes to the **JA_DUT_Info** project will be documented in this file.

---


## [2.4.4] - 2026-10-01 — *DUT Disconnect & Acquisition Scope Recovery Edition*

### 🚀 Nâng cấp & Sửa lỗi (Enhancements & Bug Fixes)
- **Xử Lý Ngắt Kết Nối & Rút Cáp USB Trong Khi Đọc Thông Số (Unplug During Acquisition Handling):**
  - **Khắc phục treo/đóng băng tiến trình khi rút cáp:** Trước đây vòng lặp `_checkDevices` chờ `_loadDut` hoàn tất mới quét lại, và `runCmd` dùng `Process.run(..., runInShell: true)` không giới hạn thời gian khiến ứng dụng bị treo đọc khi thiết bị bị ngắt kết nối đột ngột giữa chừng.
  - **Mô hình Quản lý Tiến trình Theo Phạm vi (`CommandScope`):** Triển khai `lib/modules/services/command_scope.dart` quản lý vòng đời toàn bộ tiến trình con (ADB commands, Java helpers, HTTP callbacks) trong phạm vi phiên đọc. Khi DUT bị rút cáp, toàn bộ tiến trình con thuộc phiên đọc được hủy ngay lập tức mà không làm ảnh hưởng đến ADB server toàn cục.
  - **Tách biệt vòng lặp quét thiết bị & nạp bất đồng bộ:** Tách tiến trình nạp DUT sang luồng chạy độc lập `unawaited(_loadDut(newDut))`, giúp vòng lặp `_checkDevices` tiếp tục quét và phát hiện ngay lập tức khi DUT biến mất khỏi danh sách `adb devices`.
  - **Xóa trạng thái và hủy tiến trình tức thời (`_clearDut`):** Khi thiết bị hiện tại ngắt kết nối, hàm `_clearDut()` được gọi ngay lập tức: đóng `_readScope`, đặt cờ `_loadGeneration++`, chuyển widget về trạng thái chờ kết nối mà không bị trễ thời gian chờ lệnh.
  - **Giới hạn thời gian chờ lệnh trực tiếp (Bounded Process Timeouts):** `runCmd` chuyển sang gọi trực tiếp file thực thi (không qua shell `cmd.exe`), áp dụng thời gian chờ chặt chẽ (5s cho lệnh monitor, 20s cho lệnh dùng chung).
  - **Bộ kiểm thử hồi quy rút cáp (`test/disconnect_read_test.dart`):** Bổ sung 6 kịch bản kiểm thử mô phỏng rút cáp giữa chừng, cắm lại cùng số serial, thiết bị unauthorized/offline, dispose monitor và timeout hủy tiến trình.

### 📦 Phát hành
- Đồng bộ version 2.4.4+12 trong pubspec.yaml, constants.dart, ABOUT.txt, CHANGELOG.md, RELEASE_NOTES.md, README.md, USERGUIDE.md.

---

## [2.4.3] - 2026-10-01 — *IQ4/IQ5 Live SRF Receiver Verification & RF Stability Edition*

### 🚀 Nâng cấp & Tính năng mới (Enhancements & Stability)
- **Xác Thực Thu Sóng Thực Tế SRF (Live DUT-Side SRF Packet Reception Verification):**
  - **Khắc phục kết luận PASS ảo:** Bãi bỏ cơ chế cũ chỉ dựa vào tín hiệu phát ACK từ Golden Panel mà không kiểm tra DUT có thực sự nhận được sóng hay không.
  - **Dịch vụ Helper Nhúng Java DEX (`SrfReceiver.jar`):** Tích hợp công cụ receiver chuyên dụng (`assets/tools/srf/SrfReceiver.jar`) chạy trực tiếp trên môi trường Android của DUT qua `app_process`.
  - **Giải mã chuẩn giao thức UDP 9950 & 19-byte Frame:** Kích hoạt transaction 11 (event 80/81) trên `srfservice_ttyHSLX`, lắng nghe socket UDP 9950, trích xuất chính xác Air ID (GE: `25390A`, Honeywell/DSC: `49CA0A`).
  - **Hiệu chuẩn đo lường RSSI chuẩn xác:** Xác định chính xác vị trí byte 14 trong frame (thay thế giả định cũ byte 6) với công thức `unsigned(byte14) / 2 - 134 dBm`, yêu cầu cường độ tín hiệu tối thiểu >= -99 dBm và nhận đủ 5 frame liên tục.
  - **Cơ chế thu dọn tài nguyên an toàn (Guaranteed Teardown):** Tự động gửi event 81 để đóng listener, đóng DatagramSocket và có watchdog fail-closed bảo vệ hệ thống không bị rò rỉ socket/binder.
- **Tối Ưu Hóa Dò Cổng Truyền Sóng PowerG (Transmitter Port Detection):**
  - Sử dụng truy vấn WMI `Win32_SerialPort` lọc theo bộ driver `CP210|Silicon|UART`, đảm bảo nhận diện chính xác cổng COM của thiết bị nạp/phát sóng mà không bị phụ thuộc vào định dạng chuỗi tên thiết bị PnP.
- **Bổ Sung Bộ Kiểm Thử Hồi Quy Toàn Diện (Comprehensive Regression Tests):**
  - Bổ sung `test/srf_receiver_test.dart` và `test/iq5_rf_live_test.dart` kiểm tra tính toàn vẹn của chuỗi bắt tay, mã hóa/giải mã frame UDP và cơ chế dọn dẹp tiến trình receiver.

### 📦 Phát hành
- Đồng bộ version 2.4.3+11 trong pubspec.yaml, constants.dart, ABOUT.txt, CHANGELOG.md, RELEASE_NOTES.md, README.md, USERGUIDE.md.


---

## [2.4.2] - 2026-09-29 — *IQ4 868MHz / 915MHz Multi-Protocol RF & Universal Device Recognition Edition*

### 🚀 Enhancements & Bug Fixes
- **Khắc Phục Toàn Diện Nhận Diện Sóng PowerG & Tần Số 868 MHz trên IQ4:**
  - **Chuỗi giải mã giao thức đa tầng (`_resolveProtocol`):** Mở rộng quét thuộc tính `qolsys.slot_one.protocol` (đặc trưng trên IQ4), `qolsys.powergv4.protocol`, `persist.qolsys.powergv4.protocol`, `qolsys.powerg.protocol`, `persist.qolsys.powerg.protocol`, ma trận thẻ `qolsys.card.matrix` (800M/900M), và `testeepapi r syspn` (IQP4004/IQP4008/IQP4009). Khắc phục triệt để lỗi báo `N/A` tần số hoặc `N/A - Không có card`.
  - **Thuật toán nhận dạng thẻ PowerG thông minh:** Kiểm tra song song `qolsys.powerg.card`, `qolsys.powergv4.card`, mã protocol khả dụng (`9`, `8`, `6`, `4`, `7`), và trạng thái binder `service check powergservice`. Không còn bị kết luận sai `Không có card` khi Android hoàn tất `qolsys.hwd.end`.
  - **Trích xuất Firmware đa nguồn (`_resolveFirmware`):** Dự phòng quét qua `qolsys.powergv4.fw`, `qolsys.powerg.fw`, `qolsys.powerg.radio.fw`, và ma trận `persist.qolsys.hwd.matrix` (ví dụ `83.03` / `83.16`).
  - **Kích phát sóng chính xác theo tần số:** Tự động điều hướng bộ phát `PowerGTransmitter.jar` phát chuẩn `868` khi protocol là 868MHz (EU), `915` khi protocol là 915MHz (NA/LATAM/ANZ), tránh nhiễu chéo khi cắm đồng thời 2 cục phát.
- **Nhận Diện Chủng Loại Thiết Bị IQ4 & IQ5 Đa Dạng (`isIq4Device` & `isIq5Device`):**
  - Hỗ trợ toàn bộ dải tiền tố PCASN trên IQ4 (`QB94`, `QB84`, `QB74`, `QB64`, `QC94`, `QD94`) và IQ5 (`QB95`, `QB85`, `QC95`).
  - Tích hợp kiểm tra thuộc tính hệ thống Android: `ro.build.product` (`lucy` cho IQ4, `tucson` cho IQ5), `ro.product.device`, và cấu hình `qolsys.sys.config` (`IQP4`, `IQH4`, `IQ4`, `IQP5`, `IQH5`).
  - Tự động nhận diện chuẩn xác ngay từ giây đầu tiên kết nối ADB, khối cầu hiển thị đúng biểu tượng `IQ4` hoặc `IQ5` thay vì rơi về `DUT` hoặc `NO DATA`.
- **Biểu Tượng Logo Ứng Dụng Mới (Multi-Resolution Windows Executable Icon):**
  - Áp dụng tệp biểu tượng mới từ `assets/logo/logo.ico` làm logo thực thi chính thức của `ja_dut_info.exe`.
  - Tự động tạo bộ icon đa tầng phân giải chuẩn Windows (`windows/runner/resources/app_icon.ico`) gồm 6 kích cỡ: 256x256, 128x128, 64x64, 48x48, 32x32, 16x16 (32-bit RGBA) sắc nét trên mọi tỉ lệ DPI màn hình, Taskbar và Desktop shortcuts.
- **Hoàn Thiện Hiển Thị Thẻ RF Trên Giao Diện:**
  - Thẻ `RF` hiển thị chuẩn trạng thái `PG: PASS (868 MHz (EU))` ngay cả khi thiết bị không trang bị card SRF (như các biến thể IQ4 868MHz).
  - Tránh hiển thị `N/A` khi card PowerG đã được cài đặt và hoạt động tốt.
- **Nâng Cấp Kịch Bản Đóng Gói Phân Phối (`package_dist.ps1`):**
  - Hoàn thiện cơ chế bảo toàn dữ liệu, chống lỗi khóa file khi cập nhật thư mục `dist/`.

---

## [2.4.1] - 2026-09-26 — *IQ5 PowerG V4 & SRF Multi-Slot Hardware Architecture Edition*

### 🚀 Enhancements & Hardware Architecture Support
- **Hỗ Trợ Nền Tảng Phần Cứng IQ5 (IQ5 Platform Support):**
  - **Tự động nhận diện thiết bị IQ5:** Nhận diện qua tiền tố PCASN `QB95` hoặc thuộc tính hệ thống `qolsys.sys.config` (`IQP5`, `IQH5`).
  - **Chẩn đoán PowerG V4 Bootloader / MCU trên IQ5:** Tự động gọi `powergv4bootload -s <slot> -c 1` để kiểm tra toàn diện MCU và Radio của card PowerG V4. Hỗ trợ nhận diện phản hồi trên cả PowerG Library v3.0 và v3.15+ (`PGHOST Received hello!`, `Found version:`, `Operation Result: SUCCESS`), tự động trích xuất Firmware và tần số hoạt động.
  - **Chẩn đoán SRF Slot 3 & Ma Trận Đa Slot trên IQ5:** Bổ sung xử lý Slot 3 (chuẩn trên IQ5, mặc định GE 319.5 MHz, hỗ trợ chuyển đổi linh hoạt sang DSC 433 MHz hoặc Honeywell 345 MHz dựa theo Firmware flag và protocol).
  - **Tương thích `srfservice_ttyHSLX`:** Tự động phát hiện dịch vụ `srfservice_ttyHSLX` trên IQ5 và ánh xạ chuẩn `goldenServiceName` (`srfservice_ttyHSL1`, `srfservice_ttyHSL2`, `srfservice_ttyHSL4`) để kích hoạt Golden Panel truyền nhận sóng chính xác.
  - **Cơ chế dự phòng ma trận SRF:** Bổ sung fallback kiểm tra `qolsys.srf.card`, `qolsys.srf_slot_three.card`, và `persist.qolsys.hwd.matrix` chống kết luận `N/A` sớm.
- **Đọc IMEI Chuẩn Hóa Trên IQ5:**
  - Ưu tiên lệnh `testeepapi r imeino` trên IQ5 với cơ chế dự phòng `testeepapi r imei`.
  - Kiểm tra tính hợp lệ bằng biểu thức chính quy số nguyên `^\d+$` nghiêm ngặt.
- **Cảnh Báo Thay Màn Hình LCMPN Trên IQ5:**
  - Nhận diện PCASN `QB95` bên cạnh tiền tố SYSSN `QP5`, `QH5`, `QP4` để hiển thị chính xác cảnh báo: *"Chú ý Panel này không được chạy lại màn hình"*.
- **Tối Ưu Hóa Live Test Phần Cứng:**
  - Bổ sung điều kiện kiểm tra `!monitor.isRfTesting` trong `test/adb_monitor_live_test.dart` đảm bảo chu trình kiểm thử RF hoàn tất trước khi đối soát kết quả.

---

## [2.4.0] - 2026-09-25 — *Windows Autostart & Quick DUT Switch Capsule Edition*

### 🚀 Enhancements & New Features
- **Tùy Chọn Khởi Động Cùng Windows (Windows Autostart Option):**
  - **Mặc định kích hoạt khi cài đặt:** `install.bat` tự động ghi khóa Registry `HKCU\Software\Microsoft\Windows\CurrentVersion\Run\JA_DUT_Info` (chạy ở không gian User, không đòi hỏi quyền Admin).
  - **Dọn dẹp sạch sẽ khi gỡ cài đặt:** `uninstall.ps1` tự động xóa khóa Registry khi người dùng gỡ ứng dụng.
  - **Bật/Tắt 1-Click trong App:** Bổ sung service `autostart_service.dart` và mục menu ngữ cảnh `[✓] Khởi động cùng Windows` trên Chathead bubble, phản hồi trạng thái bằng toast thông báo tức thời.
- **Thanh Capsule Đổi DUT Nhanh Nổi Phía Trên Thẻ PCASN (`DutSwitchHeader`):**
  - Widget dạng capsule mỏng (cao 18px, rộng 175px) hiển thị trực quan thông số thiết bị: Icon `📱` + `DUT: <serial> (<vị_trí>/<tổng_số>)` + Nút chip chuyển đổi `[⇄ ĐỔI]`.
  - Hiệu ứng kính mờ Frosted Glass và viền sáng Cyan (`#00ADB5`) khi di chuột qua, kèm Tooltip hướng dẫn chi tiết.
  - Nhấp chuột trực tiếp vào capsule để chuyển đổi xoay vòng sang DUT tiếp theo với thông báo xác nhận `Đã chuyển sang DUT: <serial>`.
  - **Thông minh & Thích ứng theo vị trí:** Tự động ẩn khi chỉ có 1 DUT để giữ giao diện tối giản; tự động xuất hiện khi $\ge 2$ DUT. Vị trí tự căn lệch đối xứng tránh va chạm với Chathead bubble hoặc nhãn Station.
  - **Đồng bộ Win32 Native Hit-Test:** Đăng ký vùng tương tác `dutHeaderHitRect` vào C++ Runner, đảm bảo click nhạy 100% không xuyên thấu nền.
- **Tái Cấu Trúc Tương Tác Thẻ RF (RF Card Tap & Layout Refactor):**
  - Nhấp chuột vào hàng thẻ RF kích hoạt kiểm tra lại sóng vô tuyến (`retestRf()`).
  - Biểu tượng cài đặt `tune` ở cuối hàng chuyên dụng để mở hộp thoại Chẩn đoán Bento (`RfDiagnosticsDialog`).
  - Loại bỏ nút refresh riêng lẻ để giải phóng toàn bộ chiều rộng cho chữ marquee cuộn thông số RF.
- **Tối Ưu Hóa Kịch Bản Đóng Gói Phát Hành (`build.bat` & `package_dist.ps1`):**
  - Chuyển đổi sang Robocopy `/MIR` in-place, khắc phục triệt để lỗi khóa tệp `ERROR_SHARING_VIOLATION` khi đóng gói thư mục `dist/`.

---

## [2.3.1] - 2026-09-24 — *Boot Completion Detection & Multi-Retry Reliability Edition*

### 🚀 Enhancements & Bug Fixes
- **Automated Boot Completion Detection (`_waitForBootComplete`):**
  - Added detection for Android `sys.boot_completed == '1'` and `dev.bootcomplete == '1'` during device reboot or early ADB connection.
  - When the DUT is rebooting, the floating bubble dynamically displays `BOOTING` status with `DUT đang khởi động (Đang chờ boot xong)...`, preventing premature reading of uninitialized properties.
  - Added an extra 1.5-second stabilization grace period after boot completion before polling hardware daemons.
  - Runtime reboot detection in `_checkDevices()`: immediately catches when an active DUT begins rebooting and smoothly transitions into boot-waiting mode.
- **Multi-Retry Parameter Acquisition with Fallbacks:**
  - **CPU (Baseband Modem):** Implemented a 10-attempt retry loop (1.5s interval, up to 15s) with triple-layer fallbacks (`gsm.version.baseband` $\to$ `gsm.version.baseband1` $\to$ `ro.boot.baseband` / `ro.baseband`). Completely resolves false `N/A` readings caused by RIL daemon startup delays during reboot.
  - **PCASN, SYSSN, SYSPN, LCMPN, IMEI:** Added 5-attempt retry loops with 1s delays to ensure EEPROM I2C buses are fully accessible before falling back to `N/A`.
- **Resilient RF Wireless Verification on Boot:**
  - **PowerG Card Detection Loop:** Added a 10-attempt retry loop (1.5s interval) checking `qolsys.powerg.card`, `qolsys.powergv4.card`, and persistent protocol settings. Automatically triggers `qolsys.factory.hwd = 1` if hardware discovery is not yet completed.
  - **PowerG Service Readiness & Auto-Start:** Automatically verifies `service check powergservice` in ServiceManager and issues `start powergd` if the daemon has not yet been started by `init`.
  - **SRF Matrix Retry Loop:** Added multi-attempt matrix polling and daemon readiness checks (`srfslotd` / `srfd`) to avoid premature `N/A` on reboot.
  - Only concludes `N/A - Không có card` after all discovery and daemon start attempts fail.

---

## [2.3.0] - 2026-09-24 — *RF Wireless Verification & LAN OTA Updates Edition*

### 🚀 Major Features & Enhancements
- **Automated RF Wireless Verification Suite:**
  - **PowerG 868 / 915 MHz:** Hardware card detection, protocol mapping (Protocol 8: 915 MHz US/NA, Protocol 9: 868 MHz EU), AutoLearn toggling (`service call powergservice 2 i32 1/0`), buffer reset (`transact 201`), standalone runner tool `PowerGTransmitter.jar` with Silicon Labs CP210x COM port auto-discovery, and registration ID polling (`transact 202`).
  - **SRF Multi-Slot (319.5 MHz, 345 MHz, 433 MHz):** Hardware matrix decoding from `qolsys.srfslot.matrix` (Slot 1 GE, Slot 2 DSC, Slot 4 Honeywell), MCU health verification (`service call srfservice 50`), and automated Golden Panel pairing (`persist.auto.run == '1'`) with slot broadcast triggers (`transact 18`).
  - **Dual Pipeline in AdbMonitor:** Non-blocking asynchronous RF testing loop running in background threads without blocking serial or ADB metadata polling.
- **Dynamic 7th Card Layout & Diagnostics Dialog:**
  - Integrated 7th floating card (`RF`) with optimized compact metrics (`cardHeight = 26.0px`, `cardGap = 5.0px`), fitting neatly within the 335px transparent canvas.
  - Per-region transparent mouse click-through updated dynamically for 7 cards with 0% CPU overhead.
  - Live status indicators on the RF card: active spinner during test, emerald `PASS` badge, and amber `MCU OK` badge.
  - Dedicated **Bento Frosted Glass RF Diagnostics Dialog** (`RfDiagnosticsDialog`) providing deep telemetry (Firmware, COM port, Protocol, AutoLearn status, MCU ping, Matrix slots) and 1-click Retest button.
- **Enterprise LAN OTA Updates Suite:**
  - **OtaUpdateService:** Full Semantic Versioning parser, UNC server share scanner (`\\server\share\...`), credentials management, and atomic self-updating via `apply_update.bat` and Robocopy with automatic rollback on error.
  - **GlassUpdateDialog & OtaSettingsDialog:** Bento Frosted Glass UI for configuring update frequency (`daily`, `weekly`, `monthly`, `off`), UNC paths, viewing changelog/release notes, and executing updates with a progress bar.
  - **TopBar Badge:** Glowing emerald badge indicator on the floating chathead bubble when an update is available.
- **Windows Zero-Privilege Application Lifecycle Suite:**
  - `install.bat`: 1-click Windows installer to `%LOCALAPPDATA%\Programs\JA_DUT_Info` without requiring administrator privileges, creating Desktop & Start Menu shortcuts and Control Panel uninstaller registration.
  - `uninstall.bat` & `uninstall.ps1`: Safe staging driver operating from `%TEMP%` to cleanly delete binaries, shortcuts, and registry keys without file lock conflicts.
  - `build.bat` & `windows\packaging\package_dist.ps1`: Automated packaging script creating portable releases and verified SHA-256 ZIP archives in `dist/`.

---

## [2.2.1] - 2026-09-14 — *Adaptive Toast Alignment & Smooth Motion Edition*

### 🚀 Enhancements & Refinements
- **Adaptive Toast Notification Alignment:**
  - **Docked Mode:** When the bubble is tucked into the monitor edge, the copy notification toast aligns closer to the bubble (`left = 230px` on right, `45px` on left), neatly positioned directly above the card stack.
  - **Popped-out Mode:** When the bubble expands into view upon hover, the toast smoothly slides leftward (`left = 175px` on right, `100px` on left) via `AnimatedPositioned` (260ms, `Curves.easeOutCubic`) to avoid collision and sit adjacent to the sphere.
  - **Card Width Centering:** In both states, the toast is strictly bounded within the card column's horizontal span (`[134, 420]` for right corner), eliminating previous awkward drift to the window's far-left corner.
- **Accurate Hit-Test Registration:**
  - Dynamic `toastHitRect` bounding box registered with Win32 native hit-testing, keeping click-through capability 100% transparent for all surrounding empty space.

---

## [2.2.0] - 2026-09-14 — *Tilted Wire Station & Edge Docking Edition*

### 🚀 Major Features & Enhancements
- **Tilted Wire Station Badge on Edge Docking:**
  - When the bubble is docked 80% into the monitor edge, instead of hiding the station result, the Station label (`_WireStationBadge`) is dynamically positioned at the parametric midpoint ($t = 0.48$) of the curved lead-in Bézier wire connecting the bubble to the first/target card.
  - Rotates along the wire's tangent derivative angle $\theta = \operatorname{atan2}(dy, dx)$, normalized to $[-\frac{\pi}{2}, \frac{\pi}{2}]$ so text is always right-side-up and readable from left to right.
  - Positioned along the normal vector $\vec{n} = \frac{(-dy, dx)}{\|(dx, dy)\|}$ into the open convex space (above wire for bottom corners `BL`/`BR`, below wire for top corners `TL`/`TR`), preventing wire collision.
- **Sticker Aesthetic & Interaction:**
  - Designed as a glossy sticker pill: white/frosted background in light mode with electric blue border and text (`#0084FF`), slate-900 with neon cyan (`#38BDF8`) in dark mode.
  - Tapping the wire station badge copies the station string to the clipboard with toast feedback.
  - Transparent click-through is preserved around the badge via dedicated native hit-test rect registration.
- **Smooth Cross-Fade Hover Transitions:**
  - Moving the cursor onto the edge crescent tab expands the bubble into full view, smoothly cross-fading the wire station badge into the traditional bubble station pill via `AnimatedOpacity` (220ms) and `AnimatedPositioned` (260ms).

---

## [2.1.0] - 2026-09-14 — *Dynamic Click-Through & QQ Edge Docking Edition*

### 🚀 Major Features & Enhancements
- **Per-Region Transparent Mouse Click-Through:**
  - Integrated dynamic `WS_EX_TRANSPARENT` extended window style combined with low-level mouse hook (`WH_MOUSE_LL`) and 50 FPS backup timer.
  - Clicks, double clicks, text selection, and scroll events on all transparent empty areas now pass directly through to background applications (browsers, Telegram, IDEs) with 0ms latency and 0% CPU overhead.
  - Interactive elements (chathead bubble, individual info cards, station pill, context menu, toast notification) remain 100% responsive.
- **QQ Guardian 80% Edge Docking & Crescent Tab:**
  - When the widget is pushed against the monitor edge, the circular bubble smoothly docks 80% into the screen margin, leaving a glowing 25px crescent tab with an active pulse LED.
  - Hovering over the crescent tab springs the bubble out into full view; info cards align snugly against the display boundary.
  - Isolated, drift-free `BubbleHoverRegion` ensures rock-solid hover stability without boundary jitter.
- **Dynamic 4-Corner Auto-Adaptation & Center-of-Gravity Inversion:**
  - **Bottom Corners (`BL`, `BR`):** Cards are shifted down (`startY = 115px`), with the bottom-most card (`CPU`) finishing flush against the Windows Taskbar (10px margin). The bubble sits above the cards with downward wire growth.
  - **Top Corners (`TL`, `TR`):** Inverted layout where info cards automatically mount to the top of the window (`startY = 10px`), and the bubble docks beneath them (`actualBubbleTop = 256px`). Wires reverse direction, growing upwards from the bubble top.
  - Station pill automatically inverts position (above or below the bubble) accordingly.

### 🐛 Bug Fixes & Refinements
- Resolved an issue where `WM_NCHITTEST` returning `HTTRANSPARENT` swallowed clicks instead of passing them across process boundaries to background windows.
- Fixed boundary jitter during bubble edge docking using a dedicated static `BubbleHoverRegion` overlay.
- Corrected individual card bounding boxes to allow mouse interaction between card gaps without blocking background clicks.

---

## [2.0.0] - 2026-08-27 — *Messenger Floating Bubble Edition*


### 🌟 Added & Redesigned
- **Messenger Chathead Bubble UI:**
  - Replaced the legacy rectangular window header and static table layout with a circular Messenger chathead bubble (`IQ5` cyan/blue, `IQ4` purple/neon, `READING` amber, `WAIT ADB` slate).
  - Added live pulsing status LED dot with real-time VSync glow.
  - Added floating Station Badge pill with smooth vertical translation animation.
- **Dynamic Bézier Connecting Leader Wires (`_WirePainter`):**
  - High-performance GPU-accelerated Bézier curves connecting the chat bubble anchor to each individual info card.
  - Sprout (grow out) animation upon device connection and retract (collapse) animation upon disconnect.
  - Tip glow dots and hover line accent highlights.
- **Frosted Glass Info Cards (`_InfoCard`):**
  - Integrated `BackdropFilter` (`sigmaX: 14, sigmaY: 14`) behind cards to softly blur background window text and guarantee 100% legibility.
- **Asymmetric Marquee Scrolling (`_MarqueeText`):**
  - Integrated 4-phase mechanic scroll cycle (1.5s initial hold $\to$ linear slow scroll $\to$ 1.5s end hold $\to$ 800ms bounce return) for long warnings like `LCMPN` (`Chú ý Panel này không được chạy lại màn hình`) with 100% extent accuracy without clipping the tail.
- **100% Transparent Pass-Through Window Background:**
  - Removed rectangular Acrylic/Mica background box in native C++ Win32 runner; entire area outside the bubble and cards is crystal-clear transparent.
- **Interactive Controls:**
  - Native window dragging (`WM_SYSCOMMAND 0xF012`) on bubble and card tap/drag.
  - Right-click context menu (Theme toggle, DUT switch, Exit).
  - Hover mini close button `✕`.

### ⚡ Performance & Optimization
- Wrapped individual cards, wires canvas, and chat bubble in isolated `RepaintBoundary` widgets to prevent full-window redraws during marquee scrolling or LED pulsing.
- Cached static `Paint` objects to eliminate garbage collection pressure.
- Automated zero-overhead static mode when text fits inside the card viewport.

---

## [1.0.0] - 2026-08-11
- Initial release of JA_DUT_Info with ADB monitoring, Aero/Acrylic blur table UI.
