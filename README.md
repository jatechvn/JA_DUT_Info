# 💬 JA DUT Info — Dynamic Click-Through & QQ Edge Docking Edition (v2.1.0)

> **Widget nổi màn hình thông minh (Floating Desktop Overlay)** giám sát và hiển thị thông số phần cứng thiết bị DUT qua ADB với phong cách **Bong bóng chat Messenger**, **QQ Guardian 80% Edge Docking**, **Dây kết nối Bézier động**, **Thẻ kính mờ Frosted Glass**, và **Per-region Click-Through** cho phép click xuyên qua toàn bộ khoảng trống xuống ứng dụng nền.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078D6?logo=windows)](https://microsoft.com)
[![Release](https://img.shields.io/badge/Release-v2.1.0-10B981)](#)

---

## 🌟 Điểm Nổi Bật & Tính Năng

### 1. 🖱️ Click Chuột Xuyên Khoảng Trống (Per-Region Click-Through via Win32)
- **Tương tác xuyên thấu xuống ứng dụng nền:**
  - Nhờ cơ chế chuyển đổi động `WS_EX_TRANSPARENT` kết hợp Hook chuột mức thấp `WH_MOUSE_LL` (Win32) và Timer 50 FPS, toàn bộ vùng trống trong suốt quanh widget cho phép click, bôi đen văn bản, cuộn chuột xuyên thẳng xuống Telegram, IDE, trình duyệt với **độ trễ 0ms** và **0% CPU**.
  - Các vùng nhận chuột (Quả cầu tròn, từng thẻ thông số, station pill, menu chuột phải, toast) vẫn giữ tính tương tác 100%.

### 2. 🛡️ Ẩn Mép 80% Kiểu QQ Guardian & Tab Lưỡi Liềm Phát Sáng
- **Nép mép màn hình gọn gàng:**
  - Khi người dùng đẩy widget sát vào mép trái/phải màn hình, quả cầu tự động thụt vào mép 80%, chỉ để lại một **tab lưỡi liềm phát sáng 25px** kèm đèn LED xung nhịp.
  - Các thẻ thông tin tự động ép sát vào mép màn hình, dây trục dọc uốn chữ S mềm mại nối từ tab mép vào thẻ.
  - **Hover mở rộng ổn định:** Tích hợp `BubbleHoverRegion` độc lập giúp việc di chuột vào tab mép mở rộng quả cầu ra ngoài mà không bị giật hay rung viền.

### 3. 📐 Tự Động Thích Ứng 4 Góc & Bám Sát Taskbar (Dynamic Corner Adaptation)
- **Góc Dưới (`BL`, `BR`):** Quả cầu nằm ở trên, các thẻ thông tin ở dưới bám sát ngay trên thanh Windows Taskbar (`startY = 115px`, đáy thẻ cuối cùng cách mép Taskbar đúng 10px).
- **Góc Trên (`TL`, `TR`):** Tự động đảo ngược trọng tâm — các thẻ thông số chuyển lên trên bám sát mép trên màn hình (`startY = 10px`), quả cầu chuyển xuống dưới (`actualBubbleTop = 256px`), trục dây dẫn đổi hướng vươn ngược từ đáy lên trên.
- **Huy hiệu Trạm (Station Pill):** Tự động đảo vị trí phía trên/dưới quả cầu tương ứng.

### 4. 💬 Bong Bóng Chat Messenger Nổi & Nhận Diện Thiết Bị
- 🟢 **`IQ5`**: Gradient xanh Cyan/Blue (`QB95...`).
- 🟣 **`IQ4`**: Gradient tím Neon (`QB94...`).
- 🟡 **`⏳` / `READING`**: Khi đang đọc dữ liệu qua ADB.
- ⚪ **`DUT` / `WAIT ADB`**: Khi ngắt kết nối thiết bị.

### 5. ⚡ Dây Kết Nối Động Bézier GPU-Accelerated
- Dây dẫn xung nhịp mọc ra khi cắm DUT (`Sprout`) và co rút về tâm khi rút DUT (`Retract`).
- Highlight rực sáng neon tại nhánh thẻ đang được hover chuột.

### 6. 🪟 Thẻ Kính Mờ Frosted Glass & Cuộn Chữ Bất Đối Xứng
- **BackdropFilter Kính Mờ:** Bọc bộ lọc làm mờ `sigmaX: 14, sigmaY: 14` phía sau từng thẻ.
- **Cuộn Chữ `_MarqueeText` Bất Đối Xứng:**
  - Chu trình cơ học 4 pha (Dừng 1.5s $\to$ Cuộn chậm tuyến tính $L \times 60\text{ms}$ $\to$ Dừng 1.5s $\to$ Bật nảy đàn hồi $800\text{ms}$).
  - Đảm bảo hiển thị **trọn vẹn 100% không bị cắt đuôi chữ** cho các dòng cảnh báo dài như `Chú ý Panel này không được chạy lại màn hình`.
- **Sao chép 1-Click:** Nhấp vào thẻ bất kỳ để copy giá trị vào Clipboard (kèm Toast thông báo).

---

## 🖱️ Bảng Phím Tắt & Thao Tác

| Thao Tác | Vùng Áp Dụng | Hành Động |
| :--- | :--- | :--- |
| **Kéo chuột trái** | Quả cầu tròn | Di chuyển cửa sổ widget tự do khắp màn hình (`startDrag`) |
| **Click chuột trái** | Quả cầu tròn | Thu gọn / Mở rộng các dây và thẻ thông tin |
| **Click chuột phải** | Quả cầu tròn | Menu ngữ cảnh (Đổi Theme, Đổi DUT, Đóng app) |
| **Rê chuột vào mép** | Tab lưỡi liềm 25px | Bật nhô quả cầu ra ngoài |
| **Click chuột trái** | Thẻ thông tin | Sao chép thông số vào Clipboard |
| **Click / Cuộn chuột** | Vùng trống trong suốt | Xuyên thẳng xuống ứng dụng bên dưới (Telegram, IDE, Browser) |

---

## 📁 Cấu Trúc Dự Án

```
JA_DUT_Info/
├── ABOUT.txt                          # Thẻ thông tin metadata dự án
├── README.md                          # Tài liệu hướng dẫn & tính năng
├── CHANGELOG.md                       # Lịch sử phiên bản & thay đổi
├── pubspec.yaml                       # Cấu hình gói & phiên bản Flutter (v2.1.0)
├── build.bat                          # Script biên dịch bản Release Windows
├── lib/
│   ├── main.dart                      # Điểm khởi chạy ứng dụng Flutter
│   └── modules/
│       ├── constants.dart             # Hằng số appId, appName, appVersion (2.1.0)
│       ├── logic.dart                 # ADB Monitor, đọc PCASN, SYSSN, LCMPN, IMEI,...
│       ├── logger_config.dart         # Cấu hình ghi log ứng dụng
│       └── ui/
│           ├── main_window.dart       # Giao diện chính Messenger Bubble & Dynamic Wires
│           ├── bubble_hover_region.dart # Vùng hover ổn định cho edge docking
│           └── styles.dart            # Quản lý ThemeProvider & Design Tokens
├── test/
│   └── bubble_hover_region_test.dart  # Unit test kiểm thử hành vi hover 4 góc
├── dist/                              # Thư mục chứa file chạy độc lập (.exe)
└── windows/
    └── runner/
        ├── flutter_window.cpp         # Dynamic WS_EX_TRANSPARENT & WH_MOUSE_LL hook
        ├── flutter_window.h           # Bounding boxes hit-test interface
        └── theme_win11.cpp            # Cấu hình DWM 100% trong suốt không viền
```

---

## 🛠️ Hướng Dẫn Biên Dịch & Đóng Gói (Build)

### Cách 1: Chạy file script tự động
```cmd
build.bat
```

### Cách 2: Chạy lệnh Flutter CLI
```bash
# Cài đặt thư viện phụ thuộc
flutter pub get

# Kiểm tra cú pháp
flutter analyze

# Chạy unit test
flutter test test/bubble_hover_region_test.dart

# Biên dịch bản Release cho Windows
flutter build windows --release
```

---

## 📄 Bản Quyền & Phát Triển
- **Dự án:** JA_DUT_Info
- **Được quản lý bởi:** JA Auto Git / JA Tech VN
- **Website:** [https://jatechvn.github.io/](https://jatechvn.github.io/)

