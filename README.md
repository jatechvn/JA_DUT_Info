# 💬 JA DUT Info — RF Wireless Verification & LAN OTA Updates Edition (v2.3.0)

> **Widget nổi màn hình thông minh (Floating Desktop Overlay)** giám sát và hiển thị thông số phần cứng thiết bị DUT qua ADB với phong cách **Bong bóng chat Messenger**, **QQ Guardian 80% Edge Docking**, **Kiểm tra sóng RF không dây tự động (PowerG 868/915MHz & SRF đa slot)**, **Cập nhật LAN OTA 1-Click**, **Bộ cài đặt Windows không cần Admin (install.bat / uninstall.bat)**, **Nhãn Station nghiêng theo đường cong dây**, **Thẻ kính mờ Frosted Glass**, và **Per-region Click-Through** cho phép click chuột xuyên qua khoảng trống xuống ứng dụng nền.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078D6?logo=windows)](https://microsoft.com)
[![Release](https://img.shields.io/badge/Release-v2.3.0-10B981)](#)

---

## 🌟 Điểm Nổi Bật & Tính Năng Mới trên v2.3.0

### 1. 📡 Kiểm Tra Sóng Vô Tuyến Không Dây Tự Động (RF Wireless Verification Suite)
- **PowerG (868 MHz EU / 915 MHz US/NA):**
  - Tự động nhận diện card PowerG, giải mã tần số theo giao thức phần cứng (Protocol 8: 915 MHz, Protocol 9: 868 MHz).
  - Kích hoạt chế độ AutoLearn (`service call powergservice 2 i32 1/0`), xóa bộ đệm đăng ký cũ (`transact 201`).
  - Tích hợp công cụ phát sóng `PowerGTransmitter.jar` tự động tìm kiếm cổng COM Silicon Labs CP210x, gửi gói tín hiệu đăng ký cảm biến (`REGISTER_COMMAND`).
  - Thăm dò ID tin nhắn đăng ký (`transact 202`) để trả về kết quả `PASS` kèm Sensor ID và phiên bản Firmware.
- **SRF Đa Slot (319.5 MHz GE / 345 MHz Honeywell / 433 MHz DSC):**
  - Tự động đọc và giải mã ma trận phần cứng `qolsys.srfslot.matrix` (Slot 1 GE, Slot 2 DSC, Slot 4 Honeywell).
  - Kiểm tra trạng thái sống của vi điều khiển MCU (`service call srfservice 50`).
  - Tự động nhận diện thiết bị đối chuẩn **Golden Panel** (`persist.auto.run == '1'`) và gửi lệnh kích hoạt phát sóng chéo (`transact 18`).
- **Hộp thoại Chẩn đoán Bento Frosted Glass (`RfDiagnosticsDialog`):**
  - Hiển thị trực quan hai khối thông tin PowerG và SRF với các chỉ số đo sâu (Firmware, COM Port, Sensor ID, Matrix Slots, MCU Ping).
  - Nút **"Kiểm tra lại sóng RF"** 1-click kích hoạt kiểm thử tức thời. Phím tắt `Esc` đóng nhanh.

### 2. 🚀 Cập Nhật Qua Mạng Nội Bộ LAN Over-The-Air (LAN OTA Updates Suite)
- **Cập nhật 1-Click qua UNC SMB:** Quét tự động thư mục chia sẻ nội bộ nhà máy (`\\server\share\...`) để tìm gói nén cập nhật mới nhất theo chuẩn SemVer.
- **Hộp thoại Kính Mờ Cập Nhật (`GlassUpdateDialog`):** Hiển thị dung lượng tải về, thanh tiến trình % động, khung Release Notes cuộn mượt mà.
- **Tự động áp dụng và khôi phục:** Sử dụng kịch bản `apply_update.bat` và Robocopy để cập nhật nguyên tử, bảo toàn cấu hình người dùng và tự động rollback khi gặp sự cố.
- **Cấu hình chu kỳ linh hoạt:** Hỗ trợ kiểm tra theo chu kỳ `Hàng ngày`, `Hàng tuần`, `Hàng tháng`, hoặc `Tắt` thông qua hộp thoại Cài đặt OTA.
- **Đèn báo TopBar:** Đèn LED ngọc lục bảo nhấp nháy trên bong bóng chat khi có bản phát hành mới.

### 3. 📦 Bộ Ba Cài Đặt & Gỡ Bỏ Chuẩn Windows Không Cần Quyền Admin
- **`install.bat`**: Cài đặt 1-click vào `%LOCALAPPDATA%\Programs\JA_DUT_Info` (hỗ trợ cờ `/silent`), tạo shortcut Desktop và Start Menu, đăng ký vào Windows Control Panel (Programs and Features).
- **`uninstall.bat` & `uninstall.ps1`**: Cơ chế staging qua `%TEMP%` giúp xóa sạch thư mục cài đặt, dọn dẹp shortcuts và registry mà không bị lỗi khóa file.
- **Bảo toàn dữ liệu người dùng:** Giữ nguyên các tệp cấu hình `update_config.json`, `config.json`, `config.ini`, và thư mục `logs/`.

### 4. 🏷️ Nhãn Station Nghiêng Theo Dây Khi Ẩn Mép (Tilted Wire Station Badge)
- Khi quả cầu thụt vào mép 80%, nhãn Station (`_WireStationBadge`) tự động chuyển vị trí ra chính giữa đoạn dây cong Bézier nối từ quả cầu đến thẻ đầu tiên.
- Chữ nghiêng mượt mà theo góc tiếp tuyến đạo hàm $\theta = \operatorname{atan2}(dy, dx)$ và tự động chuẩn hóa $[-\frac{\pi}{2}, \frac{\pi}{2}]$ đảm bảo chữ luôn đọc xuôi từ trái sang phải ở cả 4 góc.
- Bấm vào nhãn Station để sao chép nhanh tên trạm vào Clipboard kèm thông báo Toast.

### 5. 🖱️ Click Chuột Xuyên Khoảng Trống (Per-Region Click-Through via Win32)
- Nhờ cơ chế chuyển đổi động `WS_EX_TRANSPARENT` kết hợp Hook chuột mức thấp `WH_MOUSE_LL` (Win32) và Timer 50 FPS, toàn bộ vùng trống trong suốt quanh widget cho phép click, bôi đen văn bản, cuộn chuột xuyên thẳng xuống Telegram, IDE, trình duyệt với **độ trễ 0ms** và **0% CPU**.
- Các vùng nhận chuột (Quả cầu tròn, 7 thẻ thông số, nhãn station trên dây, menu chuột phải, toast) vẫn giữ tính tương tác 100%.

### 6. 📐 Thích Ứng 4 Góc & Bám Sát Taskbar
- **Góc Dưới (`BL`, `BR`):** Quả cầu nằm ở trên, các thẻ thông tin ở dưới bám sát ngay trên thanh Windows Taskbar (`startY = 115px`).
- **Góc Trên (`TL`, `TR`):** Tự động đảo ngược trọng tâm — các thẻ thông số chuyển lên trên bám sát mép trên màn hình (`startY = 10px`), quả cầu chuyển xuống dưới.

---

## 🖱️ Bảng Phím Tắt & Thao Tác

| Thao Tác | Vùng Áp Dụng | Hành Động |
| :--- | :--- | :--- |
| **Kéo chuột trái** | Quả cầu tròn | Di chuyển cửa sổ widget tự do khắp màn hình (`startDrag`) |
| **Click chuột trái** | Quả cầu tròn | Thu gọn / Mở rộng các dây và thẻ thông tin |
| **Click chuột phải** | Quả cầu tròn | Menu ngữ cảnh (Đổi Theme, Đổi DUT, Kiểm tra RF, Cài đặt OTA, Đóng app) |
| **Rê chuột vào mép** | Tab lưỡi liềm 25px | Bật nhô quả cầu ra ngoài |
| **Click chuột trái** | Thẻ thông tin | Sao chép thông số vào Clipboard |
| **Click icon ⚙️ trên thẻ RF** | Thẻ RF | Mở hộp thoại Chẩn đoán RF chi tiết (`RfDiagnosticsDialog`) |
| **Click badge OTA xanh lá** | Quả cầu tròn | Mở hộp thoại Cập nhật phiên bản mới (`GlassUpdateDialog`) |
| **Click / Cuộn chuột** | Vùng trống trong suốt | Xuyên thẳng xuống ứng dụng bên dưới (Telegram, IDE, Browser) |

---

## 📁 Cấu Trúc Dự Án

```
JA_DUT_Info/
├── ABOUT.txt                          # Metadata dự án (v2.3.0)
├── README.md                          # Hướng dẫn chi tiết & tài liệu tính năng
├── CHANGELOG.md                       # Lịch sử các phiên bản
├── USERGUIDE.md                       # Hướng dẫn sử dụng chi tiết cho người vận hành
├── RELEASE_NOTES.md                   # Ghi chú phát hành phiên bản v2.3.0
├── pubspec.yaml                       # Cấu hình gói & phiên bản Flutter (v2.3.0+6)
├── build.bat                          # Kịch bản biên dịch Release & đóng gói tự động
├── install.bat                        # Bộ cài đặt Windows 1-click (%LOCALAPPDATA%)
├── uninstall.bat                      # Kịch bản staging gỡ cài đặt sạch sẽ
├── uninstall.ps1                      # Logic gỡ bỏ shortcut và Windows registry
├── assets/
│   └── tools/
│       └── powerg/                    # PowerGTransmitter.jar & thư viện vô tuyến
├── lib/
│   ├── main.dart                      # Khởi chạy ứng dụng Flutter
│   └── modules/
│       ├── constants.dart             # Hằng số appId, appName, appVersion (2.3.0)
│       ├── logic.dart                 # ADB Monitor, đọc PCASN, SYSSN, LCMPN, RF Pipeline
│       ├── logger_config.dart         # Cấu hình ghi log ứng dụng
│       ├── services/
│       │   ├── powerg_service.dart    # Dịch vụ kiểm tra và truyền sóng PowerG
│       │   ├── srf_service.dart       # Dịch vụ kiểm tra và kích hoạt sóng SRF
│       │   └── ota_update_service.dart # Dịch vụ cập nhật tự động LAN OTA qua UNC
│       └── ui/
│           ├── main_window.dart       # Giao diện chính Messenger Bubble & 7 thẻ thông tin
│           ├── rf_diagnostics_dialog.dart # Hộp thoại chẩn đoán sóng RF Frosted Glass
│           ├── glass_update_dialog.dart   # Hộp thoại cập nhật LAN OTA Frosted Glass
│           ├── ota_settings_dialog.dart   # Hộp thoại cài đặt cấu hình LAN OTA
│           ├── bubble_hover_region.dart   # Vùng hover ổn định cho edge docking
│           └── styles.dart            # Quản lý ThemeProvider & Design Tokens
├── test/
│   ├── widget_test.dart               # Smoke test metadata
│   ├── rf_service_test.dart           # Unit test dịch vụ PowerG & SRF
│   ├── ota_update_service_test.dart   # Unit test SemVer & cơ chế cập nhật OTA
│   ├── adb_monitor_rf_test.dart       # Unit test tích hợp RF pipeline
│   └── adb_monitor_live_test.dart     # Kiểm thử trực tiếp với phần cứng DUT thật
├── dist/                              # Thư mục chứa gói phát hành và file zip (.exe)
└── windows/
    ├── packaging/
    │   └── package_dist.ps1           # Kịch bản đóng gói chuẩn dart-build-pro
    └── runner/
        ├── flutter_window.cpp         # Dynamic WS_EX_TRANSPARENT & WH_MOUSE_LL hook
        └── theme_win11.cpp            # Cấu hình DWM 100% trong suốt không viền
```

---

## 🛠️ Hướng Dẫn Biên Dịch & Đóng Gói (Build)

### 1. Biên dịch và đóng gói tự động chuẩn dart-build-pro:
```cmd
build.bat
```
Kịch bản sẽ tự động:
- Đóng các phiên bản cũ đang chạy.
- Biên dịch ứng dụng Flutter Windows Release.
- Tự động đồng bộ `install.bat`, `uninstall.bat`, `uninstall.ps1`, `PowerGTransmitter.jar` và tài liệu vào thư mục `Release/`.
- Đóng gói bản cài đặt portable và tệp nén zip kèm mã băm SHA-256 vào thư mục `dist/`.

### 2. Kiểm thử phần cứng và tự động hóa:
```bash
# Kiểm tra phân tích tĩnh
flutter analyze

# Chạy toàn bộ 29 bài kiểm thử đơn vị & kiểm thử phần cứng thật
flutter test
```

---

## 📄 Bản Quyền & Phát Triển
- **Dự án:** JA_DUT_Info
- **Được quản lý bởi:** JA Auto Git / JA Tech VN
- **Website:** [https://jatechvn.github.io/](https://jatechvn.github.io/)
