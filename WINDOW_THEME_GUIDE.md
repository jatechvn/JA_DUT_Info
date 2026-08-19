# Window Theming and Customization Guide (Windows 10 & 11 Integration Guide)

This document describes how the window titlebar theme, transparency/blur effects (Aero Blur for Win10 & Acrylic for Win11), single-instance window activation, and background lazy-loading patterns are implemented in the application.

---

## 1. Dynamic Platform Detection

Windows 11 supports native rounded corners and fluid design languages, whereas Windows 10 relies on sharp rectangular frames. Trying to clip a transparent window with rounded corners on Windows 10 causes black corner rendering artifacts.

To solve this, the application dynamically detects whether it is running on Windows 11 or an older version (Windows 10) inside the Dart styling layer.

### Dart Detection Logic ([styles.dart](file:///d:/OS-Software/OneDrive/OpenClaw_Workspace/JA_PROJECT/PROJECT_DART/JA_adb_tool/lib/modules/ui/styles.dart))
Windows 11 build numbers start at `22000`. The app reads `Platform.operatingSystemVersion` and parses the build number:
```dart
  void _detectWindowsVersion() {
    if (!Platform.isWindows) return;
    try {
      final versionStr = Platform.operatingSystemVersion;
      final match = RegExp(r'Build\s+(\d+)').firstMatch(versionStr);
      if (match != null) {
        final buildNumber = int.tryParse(match.group(1) ?? '') ?? 0;
        _isWin11 = buildNumber >= 22000;
      }
    } catch (_) {}
  }
```

---

## 2. C++ Runner Architecture (Windows Theming Modules)

To prevent code pollution and build conflicts, the native theme drawing logic is split into isolated files under `windows/runner/`:

```text
windows/runner/
├── theme_win10.h / theme_win10.cpp   # Windows 10 composition blur (Aero Blur)
├── theme_win11.h / theme_win11.cpp   # Windows 11 native Acrylic title bar
└── win32_window.h / win32_window.cpp # Version check dispatcher & window frame creation
```

### 1. Windows 11 Theming ([theme_win11.cpp](file:///d:/OS-Software/OneDrive/OpenClaw_Workspace/JA_PROJECT/PROJECT_DART/JA_adb_tool/windows/runner/theme_win11.cpp))
Windows 11 uses the official DWM attributes to set the native system backdrop to transparent Acrylic without drawing blocking solid backgrounds over caption buttons:
```cpp
void ApplyThemeWin11(HWND hwnd, bool is_dark, bool is_startup) {
  BOOL enable_dark_mode = is_dark ? TRUE : FALSE;
  DwmSetWindowAttribute(hwnd, 20, &enable_dark_mode, sizeof(enable_dark_mode));

  if (is_startup) {
    // Set backdrop type to DWMSBT_TRANSIENTWINDOW (Acrylic = 3)
    int backdrop_type = 3;
    DwmSetWindowAttribute(hwnd, 38, &backdrop_type, sizeof(backdrop_type));

    // Extend frame into client area
    MARGINS margins = { -1, -1, -1, -1 };
    DwmExtendFrameIntoClientArea(hwnd, &margins);
  }
}
```

### 2. Windows 10 Theming ([theme_win10.cpp](file:///d:/OS-Software/OneDrive/OpenClaw_Workspace/JA_PROJECT/PROJECT_DART/JA_adb_tool/windows/runner/theme_win10.cpp))
Windows 10 uses the undocumented `SetWindowCompositionAttribute` API from `user32.dll`. To maintain performance and visual excellence, the implementation applies three critical optimizations:
- **Aero Blur (`ACCENT_ENABLE_BLURBEHIND` = 3)**: Classic Aero blur is used instead of Acrylic. Aero Blur is fully hardware-accelerated, ensuring **100% lag-free dragging, movement, and resizing** of desktop windows.
- **Zero-Alpha Guard**: Acrylic/Blur composition fails (renders solid black) if the alpha channel is exactly `0`. We force alpha to `1` as a safety check.
- **Optimized Frame Extension margins `{0, 0, 1, 0}`**: Extending margins completely (`-1`) instructs DWM to draw duplicate window borders inside the client area. We extend only the top by `1px` to authorize transparent backdrop composition without rendering duplicate borders.

```cpp
void ApplyThemeWin10(HWND hwnd, bool is_dark) {
  BOOL enable_dark_mode = is_dark ? TRUE : FALSE;
  DwmSetWindowAttribute(hwnd, 19, &enable_dark_mode, sizeof(enable_dark_mode));
  DwmSetWindowAttribute(hwnd, 20, &enable_dark_mode, sizeof(enable_dark_mode));

  HMODULE hUser = GetModuleHandleA("user32.dll");
  if (hUser) {
    pSetWindowCompositionAttribute setWindowCompAttr = 
        (pSetWindowCompositionAttribute)GetProcAddress(hUser, "SetWindowCompositionAttribute");
    if (setWindowCompAttr) {
      int alpha = 0x66; // ~40% opacity
      if (alpha == 0) alpha = 1; // Zero-alpha guard
      
      int r = is_dark ? 0x1B : 0xF3;
      int g = is_dark ? 0x15 : 0xF4;
      int b = is_dark ? 0x14 : 0xF6;
      int tint_color = (alpha << 24) | (b << 16) | (g << 8) | r; // ABGR format
      
      ACCENT_POLICY policy = { ACCENT_ENABLE_BLURBEHIND, 2, tint_color, 0 };
      WINDOWCOMPOSITIONATTRIBDATA data = { 19, &policy, sizeof(policy) };
      setWindowCompAttr(hwnd, &data);
    }
  }

  // Authorize composition with a 1px top margin to prevent duplicate border rendering
  MARGINS margins = { 0, 0, 1, 0 };
  DwmExtendFrameIntoClientArea(hwnd, &margins);

  // Force window repaint to apply layout alterations
  RECT rect;
  GetWindowRect(hwnd, &rect);
  SetWindowPos(hwnd, nullptr, 0, 0, (rect.right - rect.left) - 1, (rect.bottom - rect.top), SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
  SetWindowPos(hwnd, nullptr, 0, 0, (rect.right - rect.left), (rect.bottom - rect.top), SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);

  SendMessage(hwnd, WM_NCACTIVATE, FALSE, 0);
  SendMessage(hwnd, WM_NCACTIVATE, TRUE, 0);
}
```

### 3. Window Title Bounding Box Fix ([win32_window.cpp](file:///d:/OS-Software/OneDrive/OpenClaw_Workspace/JA_PROJECT/PROJECT_DART/JA_adb_tool/windows/runner/win32_window.cpp))
- **The Issue**: GDI text rendering on transparent windows draws a fallback solid white/black box around the native title text.
- **The Fix**: During window creation, if the OS is Windows 10, we pass an empty string `L""` as the window title. This completely hides the title bar text and removes the visual box. The taskbar entry remains identifiable because it automatically falls back to the executable name (`ja_adb_tool`).
```cpp
  HWND window = CreateWindow(
      window_class, IsWindows11OrGreater() ? title.c_str() : L"", WS_OVERLAPPEDWINDOW,
      Scale(origin.x, scale_factor), Scale(origin.y, scale_factor),
      Scale(size.width, scale_factor), Scale(size.height, scale_factor),
      nullptr, nullptr, GetModuleHandle(nullptr), this);
```

---

## 3. Single-Instance Window Activation (C++)

To prevent users from opening parallel windows of the application, we implement native single-instance Mutex checks and window redirection when launching.

### 1. Verification Logic ([main.cpp](file:///d:/OS-Software/OneDrive/OpenClaw_Workspace/JA_PROJECT/PROJECT_DART/JA_adb_tool/windows/runner/main.cpp))
We attempt to create a named Mutex at the start of `wWinMain`. If `GetLastError() == ERROR_ALREADY_EXISTS`, we find and activate the first instance window, then exit:
```cpp
  HANDLE hMutex = ::CreateMutexW(nullptr, TRUE, L"Local\\ja_adb_tool_single_instance_mutex");
  if (hMutex == nullptr) {
    return EXIT_FAILURE;
  }

  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    ::CloseHandle(hMutex);

    // Try to find the existing window of the first instance
    HWND existing_hwnd = nullptr;
    for (int i = 0; i < 20; ++i) { // Retry for up to 2 seconds
      FindInstanceParams params;
      ::EnumWindows(FindInstanceWindowProc, reinterpret_cast<LPARAM>(&params));
      if (params.hwndFound != nullptr) {
        existing_hwnd = params.hwndFound;
        break;
      }
      ::Sleep(100);
    }

    if (existing_hwnd != nullptr) {
      if (::IsIconic(existing_hwnd)) {
        ::ShowWindow(existing_hwnd, SW_RESTORE);
      } else {
        ::ShowWindow(existing_hwnd, SW_SHOW);
      }
      ::SetForegroundWindow(existing_hwnd);
      ::SetFocus(existing_hwnd);
    }
    return EXIT_SUCCESS;
  }
```

### 2. Window Property Identification ([main.cpp](file:///d:/OS-Software/OneDrive/OpenClaw_Workspace/JA_PROJECT/PROJECT_DART/JA_adb_tool/windows/runner/main.cpp))
On successful creation, we attach a custom property string `JA_ADB_TOOL_INSTANCE` to the window handle:
```cpp
  ::SetPropW(window.GetHandle(), L"JA_ADB_TOOL_INSTANCE", (HANDLE)1);
```
During window enumeration, we fetch the property to ensure we target only our specific app:
```cpp
BOOL CALLBACK FindInstanceWindowProc(HWND hwnd, LPARAM lParam) {
  FindInstanceParams* params = reinterpret_cast<FindInstanceParams*>(lParam);
  wchar_t className[256];
  if (::GetClassNameW(hwnd, className, 256) > 0) {
    if (::wcscmp(className, L"FLUTTER_RUNNER_WIN32_WINDOW") == 0) {
      if (::GetPropW(hwnd, L"JA_ADB_TOOL_INSTANCE") == (HANDLE)1) {
        params->hwndFound = hwnd;
        return FALSE; // Stop search
      }
    }
  }
  return TRUE;
}
```

### 3. Cleanup on Destruction ([flutter_window.cpp](file:///d:/OS-Software/OneDrive/OpenClaw_Workspace/JA_PROJECT/PROJECT_DART/JA_adb_tool/windows/runner/flutter_window.cpp))
Always remove the property list entry before the window is destroyed:
```cpp
  HWND hwnd = GetHandle();
  if (hwnd != nullptr) {
    ::RemovePropW(hwnd, L"JA_ADB_TOOL_INSTANCE");
  }
```

---

## 4. Dart Styling Architecture (Split Modules)

To allow the native Windows backdrop blur to show through, the Dart layer uses OS-specific theme configurations:

```text
lib/modules/ui/
├── styles.dart        # Platform coordinate dispatcher
├── styles_win10.dart  # Translucent theme colors tailored for Windows 10
└── styles_win11.dart  # Transparent theme colors tailored for Windows 11
```

### 1. Translucency Adaptations
- **Windows 10 ([styles_win10.dart](file:///d:/OS-Software/OneDrive/OpenClaw_Workspace/JA_PROJECT/PROJECT_DART/JA_adb_tool/lib/modules/ui/styles_win10.dart))**: Uses semi-opaque solid overlays to contrast with the Aero composition blur:
  - `sidebarBg` has a higher opacity (`~70%`) to block high-frequency desktop changes.
  - `cardBg` utilizes `~85%` opacity for clear item definition.
- **Windows 11 ([styles_win11.dart](file:///d:/OS-Software/OneDrive/OpenClaw_Workspace/JA_PROJECT/PROJECT_DART/JA_adb_tool/lib/modules/ui/styles_win11.dart))**: Uses lower opacities and subtle borders to let the fluid native system Acrylic bleed through cleanly.

### 2. Font and Text Color Adaptations
- **Premium Font Family**: The application applies the premium modern font `Outfit` codebase-wide. It is registered inside the global `ThemeData` textTheme to ensure it applies automatically to all Text widgets:
  ```dart
  ThemeData get themeData {
    return ThemeData(
      // ...
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontFamily: 'Outfit'),
      ),
    );
  }
  ```
- **Dynamic Text Colors**: When the theme switches (Light/Dark mode), text colors must adapt dynamically to maintain legibility over blurred backgrounds:
  - **Primary Text (`textPrimary`)**: Transitions between `Colors.white` (Dark Mode) and `Colors.black87` (Light Mode).
  - **Secondary Text (`textSecondary`)**: Transitions between `Colors.white70` (Dark Mode) and `Colors.black54` (Light Mode).
  - **Component Borders (`borderTheme`)**: Transitions between `Colors.white10` (Dark Mode) and `Colors.black12` (Light Mode).
- **State Integration**: Text widgets must listen to the active `ThemeProvider` rather than declaring static colors:
  ```dart
  Text(
    'Sample Text',
    style: TextStyle(color: theme.textPrimary, fontSize: 13),
  )
  ```

---

## 5. UI Best Practices for Glassmorphic & Performance-Minded Apps

### 1. Glassmorphic Modal Backdrops (Popup Blurring)
When opening modal dialogs over a transparent/blurred window client area, wrap the returned widget in a `BackdropFilter` using blur variables to separate content layers:
```dart
showDialog(
  context: context,
  builder: (context) => BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
    child: AlertDialog(
      backgroundColor: themeProvider.cardBg,
      title: Text('Dialog Title'),
      content: Text('Dialog Content'),
    ),
  ),
);
```

### 2. Lazy Loading Asynchronous Data Pattern
When querying heavy hardware info or list details (such as package labels or files via ADB shell):
1. **Immediate Initial Load**: Fetch basic keys or IDs (e.g. package names) first and render the list immediately using default placeholders.
2. **Background Query**: Spawn a secondary asynchronous background task to fetch details (e.g. application labels using `dumpsys package | grep ...`).
3. **In-place State Update**: Once background futures return, write details back to the active models in-place and notify listeners. This prevents blocking UI loads and keeps lists responsive.

Implementation Example ([logic.dart](file:///d:/OS-Software/OneDrive/OpenClaw_Workspace/JA_PROJECT/PROJECT_DART/JA_adb_tool/lib/modules/logic.dart)):
```dart
  Future<void> loadApps() async {
    // 1. Instantly pull package names
    final userResult = await getAdbShellOutput(['pm', 'list', 'packages', '-3']);
    _apps = parsePackages(userResult);
    _loadingApps = false;
    notifyListeners(); // Render initial list immediately

    // 2. Fetch app names in background without blocking UI
    unawaited(_loadLabelsInBackground());
  }
```

### 3. Cycle Locale Globals (Lightweight i18n)
Instead of importing heavy localization setups, implement a cyclic i18n structure:
- Bind translations to a ChangeNotifier `LanguageProvider`.
- Use a lightweight extension on BuildContext `context.tr('key')`.
- Place a single icon button (`Icons.language`) in settings to cycle languages (`en` -> `vi` -> `zh`) instantly.
