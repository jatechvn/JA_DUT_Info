# Changelog

All notable changes to the **JA_DUT_Info** project will be documented in this file.

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
