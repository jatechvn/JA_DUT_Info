# Sổ Tay Kỹ Thuật: Cơ Chế & Khắc Phục Sự Cố Kiểm Thử Sóng PowerG & SRF
> **Dự án:** Lucy L10 MMI Test System & JA_DUT_Info  
> **Ngày cập nhật:** 24/09/2026  
> **Tác giả:** Đội ngũ Kỹ thuật & Antigravity Pair-Programming  

---

## 📑 MỤC LỤC
1. [Kiến trúc & Cơ chế hoạt động của bài test](#1-kiến-trúc--cơ-chế-hoạt-động-của-bài-test)
2. [Phân biệt Mục 11 (PowerGCardDetect) và Mục 12 (PowerGCard)](#2-phân-biệt-mục-11-powergcarddetect-và-mục-12-powergcard)
3. [Các nguyên nhân gốc rễ gây lỗi mục 12 (PowerGCard FAILED)](#3-các-nguyên-nhân-gốc-rễ-gây-lỗi-mục-12-powergcard-failed)
4. [Bản chất hiện tượng "Bắt ké sóng từ máy bên cạnh" (False Pass)](#4-bản-chất-hiện-tượng-bắt-ké-sóng-từ-máy-bên-cạnh-false-pass)
5. [Quy trình đổi sóng 915 MHz ◄► 868 MHz siêu tốc (Không cần reboot)](#5-quy-trình-đổi-sóng-915-mhz--868-mhz-siêu-tốc-không-cần-reboot)
6. [Cắm đồng thời 2 cục phát (868 MHz & 915 MHz): Lưu ý & Vận hành](#6-cắm-đồng-thời-2-cục-phát-868-mhz--915-mhz-lưu-ý--vận-hành)
7. [Quy trình chẩn đoán khoanh vùng lỗi trong 5 giây bằng ADB](#7-quy-trình-chẩn-đoán-khoanh-vùng-lỗi-trong-5-giây-bằng-adb)
8. [Kế hoạch triển khai Verify RF vào app JA_DUT_Info](#8-kế-hoạch-triển-khai-verify-rf-vào-app-ja_dut_info)

---

## 1. KIẾN TRÚC & CƠ CHẾ HOẠT ĐỘNG CỦA BÀI TEST

Hệ thống kiểm thử chức năng vô tuyến bao gồm 3 thành phần chính:

```
┌──────────────────────────────────────────────────────────────┐
│                    MÁY TÍNH KIỂM THỬ (PC)                    │
│                                                              │
│   Tool Java MMI (L10Gen4MMITest)                             │
│     ├── Quét cổng COM: Tìm chip CP210x / FTDI                │
│     ├── Điều khiển USB Dongle PowerG (COM28): Phát 868/915   │
│     └── Điều khiển Golden Panel (ADB): Kích phát SRF 18      │
└──────────────┬───────────────────────────────┬───────────────┘
               │ Cáp USB COM                   │ Cáp USB ADB
               ▼                               ▼
    ┌──────────────────────┐        ┌──────────────────────┐
    │  USB DONGLE POWERG   │        │     GOLDEN PANEL     │
    │ (Phát sóng PowerG)   │        │ (Chỉ phát sóng SRF)  │
    └──────────┬───────────┘        └──────────┬───────────┘
               │ Sóng RF PowerG                │ Sóng RF SRF
               │ (868M / 915M)                 │ (319M/345M/433M)
               ▼                               ▼
    ┌──────────────────────────────────────────────────────────┐
    │                        PANEL DUT                         │
    │  (Chạy APK MMI + powergservice + srfservice)             │
    └──────────────────────────────────────────────────────────┘
```

- **Bộ phát PowerG:** Là chiếc USB-to-UART Dongle (chip Silicon Labs CP210x hoặc FTDI) cắm trực tiếp vào cổng USB của PC, **hoàn toàn không dùng Golden Panel để phát PowerG**.
- **Golden Panel:** Là một chiếc Panel đặc biệt có thuộc tính `persist.auto.run = 1`, **chỉ dùng để phát sóng SRF** (319.5MHz GE, 345MHz Honeywell, 433.92MHz DSC).

---

## 2. PHÂN BIỆT MỤC 11 (PowerGCardDetect) VÀ MỤC 12 (PowerGCard)

| Tiêu chí | Mục 11: PowerGCardDetect | Mục 12: PowerGCard |
|---|---|---|
| **Bản chất** | Kiểm tra nhận diện phần cứng (Hardware Presence) | Kiểm tra chức năng thu sóng RF thực tế (Functional RF Test) |
| **Cơ chế kiểm tra** | Đọc các thuộc tính Android hệ thống do `hw_discov` thiết lập: <br>• `qolsys.powerg.card == 1`<br>• `qolsys.powergv4.fw == 83.03`<br>• `qolsys.powergv4.slot == 1`<br>• `qolsys.slot_one.protocol` (8: 915MHz, 9: 868MHz) | **Bước 1:** Transact 200 (Ping vi điều khiển modem & radio MCU).<br>**Bước 2:** Transact 202 (Đọc mã gói tin đăng ký RF `getLastRegistrationMessageId`). |
| **Khi nào PASS?** | Card được cắm đúng khe và firmware khớp SKU. | Ping MCU thành công VÀ nhận được gói tin RF từ bộ phát. |
| **Khi nào FAIL?** | Chưa cắm card, lỏng chân, hoặc sai version FW. | Không nhận được sóng RF, hoặc lỗi vi điều khiển trên card. |

---

## 3. CÁC NGUYÊN NHÂN GỐC RỄ GÂY LỖI MỤC 12 (PowerGCard FAILED)

Qua dịch ngược bytecode APK và mã nguồn Java của PC Tool, đã phát hiện **5 nguyên nhân chính**:

### 🔴 Nguyên nhân 1: Lỗi thiết kế vòng lặp đọc `readingMessage()` trên APK (Race Condition)
Code trong APK `PowerGCard.class`:
```java
int check = 0;
int i = 0;
while (check == 0 && i < 3) {
    this.powergBinder.transact(202, data, reply, 0); // Đọc message
    check = reply.readInt();
    i++;
}
```
- **Lỗi chí mạng:** Vòng lặp `while` trên **hoàn toàn không có lệnh `Thread.sleep()`**!
- Cả 3 lần đọc diễn ra liên tiếp trong vòng **dưới 1 mili-giây (0.001s)**!
- Trong khi đó bộ phát PC phát chu kỳ **10 giây/lần**. Nếu thời điểm APK quét mà gói tin RF chưa kịp bay vào buffer $\rightarrow$ APK kết luận `FAILED` ngay lập tức!

### 🔴 Nguyên nhân 2: Code PC Tool trói buộc PowerG vào điều kiện `goldenPanel != null`
Xem tại `L10Gen4MMITest.java` dòng 1394:
```java
private void runTransmitter() {
    if (goldenPanel != null && transmitTimer == null) { // <-- LỖI TẠI ĐÂY
        powergDevice = PowergDeviceHandler.getPowergDeviceHandler();
        // ... phát sóng PowerG ...
    }
}
```
- Bộ phát PowerG cắm qua USB trên PC, **không hề cần Golden Panel**.
- Nhưng code tool lại bọc toàn bộ việc phát PowerG vào `if (goldenPanel != null)`.
- Khi trạm test chỉ cắm 1 panel DUT (hoặc cáp Golden bị lỏng adb) $\rightarrow$ `goldenPanel = null` $\rightarrow$ **Bộ phát PowerG bị tắt hoàn toàn, không phát sóng** $\rightarrow$ DUT rớt 100%!

### 🔴 Nguyên nhân 3: Mất nhận diện cổng COM của USB Dongle trên PC
- Bộ phát sử dụng chip CP210x / FTDI. Nếu lỏng cáp USB, thiếu driver, hoặc cắm sau khi mở tool PC $\rightarrow$ Tool PC không tìm thấy thiết bị $\rightarrow$ Không phát sóng.

### 🔴 Nguyên nhân 4: Lệch tần số RF (868 MHz vs 915 MHz)
- SKU 345 dùng card 868 MHz (`POWERG: 9`).
- Nếu cắm nhầm cục phát 915 MHz (Bắc Mỹ), card 868 MHz trên DUT sẽ lọc bỏ toàn bộ sóng 915 MHz $\rightarrow$ DUT không nhận được gì $\rightarrow$ FAIL.

### 🔴 Nguyên nhân 5: Suy hao sóng hoặc buồng chắn sóng (Shielding Box)
- Đầu nối ăng-ten SMA bị lỏng, cáp RF bị đứt lõi, hoặc buồng chắn sóng bị hở làm suy giảm tín hiệu RF dưới ngưỡng thu của card.

---

## 4. BẢN CHẤT HIỆN TƯỢNG "BẮT KÉ SÓNG TỪ MÁY BÊN CẠNH" (FALSE PASS)

### Tại sao không cắm Golden và cục phát ở máy mình mà bài test vẫn PASS?
1. **Sóng PowerG truyền rất xa:** Sóng Sub-1GHz (868/915MHz) có khả năng xuyên tường hàng chục mét. Cục phát ở máy bên cạnh cứ 10s phát quảng bá 1 lần, DUT ở máy bạn thu được qua không gian.
2. **Buffer trong `powergservice` lưu vĩnh viễn không tự xóa:**
   - Khi DUT bắt được dù chỉ 1 gói tin, hàm native `process_reg_req` lưu `last_received_registration_message = 1011230`.
   - Lệnh xóa bộ đệm (Transact 201) trong `L10Gen4MMITest.java` **đã bị comment out**:
     ```java
     // Runtime.getRuntime().exec("adb -s " + dutPanel.getDeviceID() + " shell service call powergservice 201").waitFor();
     ```
   - Do đó, gói tin bắt ké từ máy bên cạnh được lưu mãi trong RAM của DUT. Khi bạn bấm test, APK đọc thấy có sẵn dữ liệu $\rightarrow$ **Báo PASS ảo**!
3. **Tại sao có lúc lại FAIL?**
   - Khi DUT vừa reboot (RAM về 0), nếu lúc đó máy bên cạnh không phát hoặc bị lệch chu kỳ 10s $\rightarrow$ APK quét trong 1ms không thấy dữ liệu $\rightarrow$ FAIL.

---

## 5. QUY TRÌNH ĐỔI SÓNG 915 MHz ◄► 868 MHz SIÊU TỐC (KHÔNG CẦN REBOOT)

### Tại sao trước đây phải reboot cả PC, Golden và DUT?
- **PC:** Class `PowergDeviceHandler` là **Singleton** trong Java, chỉ quét COM 1 lần lúc bật tool. Khi rút cắm dongle khác, cổng COM bị đơ luồng nếu tool đang mở. Người dùng tưởng Windows treo nên reboot cả PC.
- **DUT:** Hệ thống Android lưu cache thuộc tính `qolsys.slot_one.protocol` từ lúc boot. Khi cắm nóng card khác tần số, thuộc tính không tự cập nhật nếu không restart service.
- **Golden:** Hoàn toàn không liên quan gì đến PowerG, reboot Golden là vô ích!

### Quy trình chuẩn mới (Chỉ mất 5 – 10 giây):

```
BƯỚC 1 (Trên PC):
  1. Rút dongle cũ, cắm dongle mới vào USB.
  2. TẮT VÀ BẬT LẠI TOOL PC MMI (hoặc kill java.exe).
     (Giải phóng cổng COM cũ và quét nhận cổng COM mới).

BƯỚC 2 (Trên DUT):
  Sau khi thay card mới, chạy lệnh ADB (mất 2 giây):
  adb shell "pkill -9 powergvirtualmodem; pkill -9 powergservice; hw_discov; service call powergservice 201"
  (Hoặc: adb reboot nếu muốn khởi động lại sạch sẽ).

BƯỚC 3 (Golden Panel):
  GIỮ NGUYÊN 100%, TUYỆT ĐỐI KHÔNG CẦN CHẠM VÀO.
```

---

## 6. CẮM ĐỒNG THỜI 2 CỤC PHÁT (868 MHz & 915 MHz): LƯU Ý & VẬN HÀNH

### Có cắm được cả 2 cục cùng lúc không?
👉 **HOÀN TOÀN CẮM ĐƯỢC VÀ NÊN CẮM CẢ 2 CỤC!**  
Code của `PowergDeviceHandler` trong file jar đã được thiết kế sẵn mảng `powerg_devices[]` để hỗ trợ đa thiết bị:
- Khi bật tool: Cục 868MHz $\rightarrow$ `Radio 0`; Cục 915MHz $\rightarrow$ `Radio 1`.
- Vòng lặp `PowerGThread` cứ 10 giây sẽ tự phát cả 2 tần số:
  `send_registration(0)` (868MHz) VÀ `send_registration(1)` (915MHz).
- Card 868MHz trên DUT chỉ bắt sóng 868MHz và bỏ qua 915MHz (và ngược lại), không sợ xung đột.

### 4 Quy tắc vàng để không bao giờ bị lỗi khi cắm 2 cục:
1. **Cắm cả 2 cục USB vào máy trước khi mở Tool PC.** Tuyệt đối không cắm/rút khi phần mềm đang mở.
2. **Cắm vào 2 cổng USB riêng biệt phía sau case PC**, tránh dùng USB Hub không nguồn ngoài (tránh sụt áp khi cả 2 cục cùng phát RF).
3. **Đặt 2 ăng-ten cách nhau tối thiểu 20 – 30 cm** trên bàn làm việc (tránh bão hòa tầng thu RF do để quá gần).
4. **Sau khi cắm DUT, chờ 3 – 5 giây** rồi mới bấm nút Start để bộ phát kịp gửi 1 chu kỳ sóng vào buffer của DUT.

---

## 7. QUY TRÌNH CHẨN ĐOÁN KHOANG VÙNG LỖI TRONG 5 GIÂY BẰNG ADB

Khi bài test báo `PowerGCard FAILED`, chạy ngay lệnh sau trên máy tính:
```cmd
adb shell "service call powergservice 200; service call powergservice 202"
```

### Bảng kết quả chẩn đoán:

| Kết quả Transact 200 | Kết quả Transact 202 | Ý nghĩa thực tế | Cách xử lý |
|:---:|:---:|---|---|
| `00000000` (Fail) | Bất kỳ | **Lỗi phần cứng card trên DUT:** Bo mạch không giao tiếp được với vi điều khiển card PowerG. | Cắm lại chân card PowerG cho chặt, vệ sinh socket UART, hoặc thay card DUT khác. |
| `00000001` (OK) | **Khác `00000000`** <br>(Ví dụ `000f6e1e`) | **Sóng RF đã vào DUT thành công!** Lỗi trước đó chỉ do APK đọc quá sớm trong 1ms. | **Bấm "Start" test lại ngay $\rightarrow$ Đảm bảo PASS 100%!** Không cần sửa gì cả. |
| `00000001` (OK) | `00000000` (Không có data) | Card DUT tốt nhưng **chưa nhận được gói tin RF nào** từ bộ phát PC. | 1. Xem lại tool PC có nhận đủ 2 cục không (`Total Found: 2`).<br>2. Kiểm tra khoảng cách 2 ăng-ten.<br>3. Tắt mở lại Tool PC. |

---

## 8. KẾ HOẠCH TRIỂN KHAI VERIFY RF VÀO APP JA_DUT_INFO

### Mục tiêu:
Tích hợp khả năng tự động kiểm tra sóng PowerG (868/915MHz) và SRF (319/345/433MHz) trực tiếp vào widget nổi **JA_DUT_Info** ([`PROJECT_DART\JA_DUT_Info`](file:///D:/OS-Software/OneDrive/OpenClaw_Workspace/JA_PROJECT/PROJECT_DART/JA_DUT_Info)).

### Kiến trúc giải pháp:
1. **`PowerGVerifyService` ([lib/modules/services/powerg_service.dart](file:///D:/OS-Software/OneDrive/OpenClaw_Workspace/JA_PROJECT/PROJECT_DART/JA_DUT_Info/lib/modules/)):**
   - Tự động quét cổng COM (CP210x/FTDI) trên Windows.
   - Gửi xung RF đăng ký trực tiếp (`5A 0F BE 0B 00 05 1A 1F 0A EB 90`).
   - Kiểm tra Transact 200 (Ping MCU) và Transact 202 (Đọc ID).
   - Vòng lặp retry 15 lần (mỗi lần 200ms) $\rightarrow$ **khắc phục dứt điểm lỗi quét 1ms của APK gốc**.
2. **`SrfVerifyService` ([lib/modules/services/srf_service.dart](file:///D:/OS-Software/OneDrive/OpenClaw_Workspace/JA_PROJECT/PROJECT_DART/JA_DUT_Info/lib/modules/)):**
   - Đọc SKU DUT: Nếu SKU không có SRF (như SKU 345) $\rightarrow$ báo `N/A`, không báo lỗi giả.
   - Tự động nhận diện Golden Panel qua `persist.auto.run == 1`.
   - Ra lệnh cho Golden Panel phát gói tin SRF (Transact 18) và kiểm tra DUT (Transact 50).
3. **Giao diện người dùng (UI):**
   - Thêm 2 thẻ hiển thị trạng thái: `PowerG: PASS (868M - 83.03)` và `SRF: N/A`.
   - Hộp thoại kính mờ `RfDiagnosticsDialog` kèm nút **"Test RF Ngay" (1-Click Diagnostics)** giúp kỹ thuật viên kiểm tra sóng bất kỳ lúc nào chỉ với một cú nhấp chuột.
