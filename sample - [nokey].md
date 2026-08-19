MyProject/
├── lib/
│   ├── main.dart              # Program entry point
│   └── modules/               # Core application modules
│       ├── ui/                # User Interface package
│       │   ├── main_window.dart   # Main application window widget
│       │   ├── styles.dart        # Theme configuration and styling
│       │   └── dialogs.dart       # Optional dialog widgets
│       ├── native/            # Hybrid Engine Core for OS-specific performance
│       │   ├── win_core.dart      # Windows optimization (Calls Win32 API, DLL C++ via FFI)
│       │   ├── mac_core.dart      # macOS optimization (Calls dylib via FFI)
│       │   └── linux_core.dart    # Linux optimization (Calls compiled .so binary via FFI)
│       ├── native_bridge.dart     # Dynamic routing bridge connecting Business Logic and native Core
│       ├── logic.dart             # Core business logic (calls via native_bridge.dart)
│       ├── utils.dart             # Shared utility helper functions
│       ├── constants.dart         # Global constants (appId, appName, appVersion)
│       └── logger_config.dart     # Centralized logger configuration
│
├── run.bat                    # Rapid startup script on Windows (runs flutter run -d windows)
├── run.sh                     # Rapid startup script on macOS/Linux (runs flutter run)
├── build.bat                  # Release build script on Windows (compiles & copies to \dist)
├── build.sh                   # Release build script on macOS/Linux (compiles & copies to \dist)
├── pubspec.yaml               # Required dependencies list (used with flutter pub get)
├── config.ini                 # Simple configuration file (INI section-based)
├── config.json                # Advanced structured configuration file (JSON format)
├── .gitignore                 # Git ignore file configuration
├── README.md                  # Main documentation in English (Repository landing page)
├── LICENSE                    # Software license agreement (MIT, Apache, etc.)
├── ABOUT.txt                  # Project details card used for GitHub repository description
├── git_push.bat               # Windows batch script to quickly push code to GitHub
│
├── i18n/                      # Internationalization directory (Multi-language READMEs)
│   ├── README.vi.md           # Vietnamese translation (Tiếng Việt)
│   └── README.zh-CN.md       # Chinese translation (简体中文)
│
├── logs/                      # Application operation logs
│   └── yyyy-mm-dd.log         # Daily log file (errors, system info, debug)
│
└── assets/                    # Static application assets
    ├── images/
    ├── sounds/
    ├── fonts/
    ├── models/
    ├── presets/
    ├── data/
    └── temp/

================================================================================
🧩 ARCHITECTURAL RECOMMENDATION: MODULAR LOGIC
================================================================================

Do not clutter all business logic in a single huge `logic.dart` file. As the project gains features, divide them into functional modules to ensure testability and prevent bug propagation.

In Dart, there is no `__init__.py` equivalent. Instead, use **barrel exports** — a single file that re-exports public APIs from a directory (e.g., `modules.dart` that exports sub-modules).

Example:

```text
lib/modules/
├── ui/                   # Decoupled UI logic package
│   ├── main_window.dart
│   └── styles.dart
├── native/               # Native Core Engine for cross-platform optimizations
│   ├── win_core.dart
│   ├── mac_core.dart
│   └── linux_core.dart
├── native_bridge.dart    # OS detection and platform-specific routing bridge
├── logic.dart            # Main coordinator logic
├── file_service.dart     # Disk I/O, file paths, exports/imports
├── api_client.dart       # HTTP requests / API integrations
└── utils.dart            # Shared helper functions
```

Optional barrel export file (`lib/modules/modules.dart`):

```dart
export 'logic.dart';
export 'file_service.dart';
export 'api_client.dart';
export 'utils.dart';
export 'constants.dart';
export 'native_bridge.dart';
```

Rule: Keep tasks atomic. A file should have a single responsibility.

================================================================================
🌿 STANDARD GIT & .gitignore CONFIGURATION
================================================================================

The `.gitignore` file should contain the following basic rules:

```ini
# Flutter/Dart
.dart_tool/
.packages
build/

# Native OS binaries (C++/Rust compiled cores via FFI)
lib/modules/native/*.dll
lib/modules/native/*.so
lib/modules/native/*.dylib

# Platform build outputs
windows/flutter/ephemeral/
macos/Flutter/ephemeral/
linux/flutter/ephemeral/

# Logs and temporary files
logs/*.log
assets/temp/

# Local IDE / OS files
.vscode/
.idea/
.DS_Store
Thumbs.db

# Generated files
*.g.dart
*.freezed.dart

# Personal config - uncomment if config contains secrets/tokens/keys
# config.ini
# config.json
```

If you manage multiple templates, we suggest using a single `dart-template` repository with dedicated branches:

```bash
git checkout main        # Basic nokey
git checkout nokey-fvm   # Nokey + FVM
git checkout key         # Key/License
git checkout key-fvm     # Key/License + FVM
```

When instantiating a new project:

```bash
git clone <template-url> my-new-project
cd my-new-project
git checkout main
git init
git add .
git commit -m "Initial commit from nokey template"
```

Batch script to automatically initialize and push to GitHub (`git_push.bat`):

```bat
@echo off
cd /d %~dp0

set /p remote_url="Enter GitHub repository URL: "
set /p commit_msg="Enter commit message (default 'Update project'): "
if "%commit_msg%"=="" set commit_msg=Update project

if not exist ".git" (
    git init
    git branch -M main
)

git add .
git commit -m "%commit_msg%"
git remote remove origin 2>nul
git remote add origin "%remote_url%"
git push -u origin main

pause
```

================================================================================
🎯 DEFAULT DART/FLUTTER SYSTEM
================================================================================

- The system defaults to Flutter 3.x / Dart 3.x for run and build targets.
- On Windows, verify `flutter --version` points to a Flutter 3.x installation in your PATH.
- This sample configuration installs dependencies globally on the system-wide Flutter SDK (no FVM).

================================================================================
💡 WINDOWS TASKBAR ICON CONFIGURATION (AppUserModelID)
================================================================================

Flutter desktop on Windows uses a native C++ runner located at `windows/runner/main.cpp` to bootstrap the application window. Unlike Python/PySide6, there is no need to call `ctypes` or manually set an `AppUserModelID` — Flutter handles the window creation and taskbar identity natively through the Windows runner.

To customize the application icon displayed on the Windows taskbar and title bar:

1. Replace the icon file at `windows/runner/resources/app_icon.ico` with your custom `.ico` file.
2. The `AppUserModelID` can be set in `windows/runner/main.cpp` if needed:

```cpp
// windows/runner/main.cpp (auto-generated by Flutter)
// The AppUserModelID is derived from your application's package name.
// To customize, modify the following line in the Flutter-generated runner:
// ::SetCurrentProcessExplicitAppUserModelID(L"com.example.my_app");
```

3. For most Flutter desktop apps, the default behavior is sufficient. The window title is set programmatically in Dart:

```dart
// In MaterialApp or via the platform window title
MaterialApp(
  title: '$appName  v$appVersion',
  // ...
)
```

================================================================================
🔢 VERSION MANAGEMENT
================================================================================

Every project must declare its version in `lib/modules/constants.dart` so that:
- **JA Auto Git** can auto-detect it and display it in the **Version** column.
- The **Release Manager** can auto-fill the tag name (e.g. `v1.2.0`).
- The application can expose its version at runtime.

## 1. Declare version in `lib/modules/constants.dart`

```dart
// lib/modules/constants.dart

const String appVersion = '1.0.0'; // ← Bump this before every release
```

## 2. Use it in `lib/main.dart`

```dart
import 'package:my_app/modules/constants.dart';

const String appId = 'YOUR_APP_ID';
const String appName = 'Your App Display Name';
// appVersion is imported from constants.dart — no need to redeclare
```

## 3. Display version in the UI (optional)

```dart
// e.g., in AppBar title
AppBar(title: Text('$appName  v$appVersion'))
```

## 4. Version bump workflow (before every push)

Follow **Semantic Versioning** (`MAJOR.MINOR.PATCH`):

| Change type | Action | Example |
|---|---|---|
| Bug fix / tiny tweak | Bump PATCH | `1.0.0` → `1.0.1` |
| New feature (backward-compatible) | Bump MINOR | `1.0.1` → `1.1.0` |
| Breaking change / major rewrite | Bump MAJOR | `1.1.0` → `2.0.0` |

**Before committing + pushing:**

1. Open `lib/modules/constants.dart` and bump `appVersion`.
2. Sync `pubspec.yaml → version: x.y.z` to match (used by Flutter build system).
3. Commit normally via JA Auto Git (auto-changelog will record what changed).
4. Optionally push a GitHub Release via the **🚀 Release** button in JA Auto Git.

## 5. Auto-detection by JA Auto Git

JA Auto Git scans the following files in priority order to detect a project's version:

```
1. pubspec.yaml           →  version: x.y.z
2. package.json           →  "version": "x.y.z"
3. pyproject.toml         →  version = "x.y.z"
4. setup.cfg              →  version = x.y.z
5. setup.py               →  version="x.y.z"
6. *.csproj               →  <Version>x.y.z</Version>
7. constants.dart/version.dart → appVersion = 'x.y.z'
8. constants.py/version.py → APP_VERSION = "x.y.z"
9. ABOUT.txt              →  Version : x.y.z
10. Latest Git tag         →  vx.y.z
```

Keeping `appVersion` in `constants.dart` ensures automatic detection (step 7), and syncing `pubspec.yaml` ensures detection at the highest priority (step 1).

================================================================================
📝 PROJECT INFORMATION CARD (ABOUT.txt)
================================================================================

The `ABOUT.txt` file acts as the project metadata card, which is parsed by `JA Auto Git` to automatically populate the repository's 'About' section on GitHub.

Structure format:

```text
========================================================================
                       PROJECT INFORMATION CARD
========================================================================
Project Name : <Project_Name>
Tech Stack   : Flutter 3.x / Dart 3.x
Managed By   : JA Auto Git
Website      : https://jatechvn.github.io/
------------------------------------------------------------------------
Description  : <A_Concise_About_Description_For_GitHub>
========================================================================
```

Note:
- The line starting with `Description  :` will be automatically extracted by `JA Auto Git` as the repository description.
- If you format the file as a plain-text description, the first non-empty line will be used as a fallback.

================================================================================
🧩 CROSS-PLATFORM NATIVE CORE BRIDGE (HYBRID ENGINE)
================================================================================

To support low-level native performance optimizations (C++, assembly, OS-specific APIs) across Windows, macOS, and Linux without cluttering the business logic:

1. Dynamic Router (`lib/modules/native_bridge.dart`):

```dart
// lib/modules/native_bridge.dart
import 'dart:io' show Platform;
import 'package:logging/logging.dart';
import 'native/win_core.dart';
import 'native/mac_core.dart';
import 'native/linux_core.dart';

final _logger = Logger('NativeBridge');

abstract class NativeEngine {
  dynamic heavyCompute(dynamic dataInput);
}

class NativeBridge {
  final String osName;
  NativeEngine? engine;

  NativeBridge() : osName = Platform.operatingSystem {
    _initializeEngine();
  }

  /// Dynamically initializes OS-specific optimized engine
  void _initializeEngine() {
    try {
      if (Platform.isWindows) {
        engine = WindowsNativeEngine();
      } else if (Platform.isMacOS) {
        engine = MacNativeEngine();
      } else if (Platform.isLinux) {
        engine = LinuxNativeEngine();
      } else {
        _logger.warning('[BRIDGE] OS $osName is not supported by Hybrid Core. Using fallback.');
      }
    } catch (e) {
      _logger.severe('[BRIDGE] Failed to initialize engine for $osName: $e');
    }
  }

  /// Executes low-level native calls if available
  dynamic executeHeavyTask(dynamic dataInput) {
    if (engine != null) {
      return engine!.heavyCompute(dataInput);
    }
    return _pureDartFallback(dataInput);
  }

  /// Standard Dart fallback logic for maximum compatibility
  dynamic _pureDartFallback(dynamic dataInput) {
    _logger.info('[BRIDGE] Processing using pure Dart algorithm (slower).');
    // Fallback business logic goes here...
    return dataInput;
  }
}

// Singleton instance to be shared across modules
final nativeAgent = NativeBridge();
```

2. Windows Optimized Engine (`lib/modules/native/win_core.dart`):

```dart
// lib/modules/native/win_core.dart
import 'dart:ffi';
import 'dart:io';
import '../native_bridge.dart';

class WindowsNativeEngine implements NativeEngine {
  DynamicLibrary? _dll;

  WindowsNativeEngine() {
    _loadNativeLibrary();
  }

  /// Loads C++/Rust compiled DLL for Windows high-performance computation
  void _loadNativeLibrary() {
    final dllPath = '${Directory.current.path}/lib/modules/native/core_x64.dll';
    if (File(dllPath).existsSync()) {
      try {
        _dll = DynamicLibrary.open(dllPath);
      } catch (_) {}
    }
  }

  @override
  dynamic heavyCompute(dynamic dataInput) {
    if (_dll != null) {
      // If high-performance C++ DLL is loaded, delegate execution
      // return _dll!.lookupFunction<...>(...);
    }

    // Windows-specific fallback (e.g., calling platform channels or system commands)
    return 'Windows Optimized Result';
  }
}
```

3. macOS Optimized Engine (`lib/modules/native/mac_core.dart`):

```dart
// lib/modules/native/mac_core.dart
import 'dart:ffi';
import 'dart:io';
import '../native_bridge.dart';

class MacNativeEngine implements NativeEngine {
  DynamicLibrary? _dylib;

  MacNativeEngine() {
    _loadNativeLibrary();
  }

  /// Loads C++/Objective-C/Rust compiled dylib for macOS high-performance computation
  void _loadNativeLibrary() {
    final dylibPath = '${Directory.current.path}/lib/modules/native/libcore.dylib';
    if (File(dylibPath).existsSync()) {
      try {
        _dylib = DynamicLibrary.open(dylibPath);
      } catch (_) {}
    }
  }

  @override
  dynamic heavyCompute(dynamic dataInput) {
    if (_dylib != null) {
      // If high-performance C++/Obj-C dylib is loaded, delegate execution
      // return _dylib!.lookupFunction<...>(...);
    }

    // macOS-specific fallback (e.g., calling shell commands or Swift APIs)
    return 'macOS Optimized Result';
  }
}
```

4. Linux Optimized Engine (`lib/modules/native/linux_core.dart`):

```dart
// lib/modules/native/linux_core.dart
import 'dart:ffi';
import 'dart:io';
import '../native_bridge.dart';

class LinuxNativeEngine implements NativeEngine {
  DynamicLibrary? _so;

  LinuxNativeEngine() {
    _loadNativeLibrary();
  }

  /// Loads C++/Rust compiled shared object (so) for Linux high-performance computation
  void _loadNativeLibrary() {
    final soPath = '${Directory.current.path}/lib/modules/native/libcore.so';
    if (File(soPath).existsSync()) {
      try {
        _so = DynamicLibrary.open(soPath);
      } catch (_) {}
    }
  }

  @override
  dynamic heavyCompute(dynamic dataInput) {
    if (_so != null) {
      // If high-performance C++ so is loaded, delegate execution
      // return _so!.lookupFunction<...>(...);
    }

    // Linux-specific fallback (e.g., calling bash commands)
    return 'Linux Optimized Result';
  }
}
```

============================================================================================================================================================
🎛️ WINDOWS 10 & 11 THEMING & COMPOSITION BLUR (SPLIT ARCHITECTURE)
================================================================================

To dynamically control the native title bar theme (Light/Dark mode) and enable transparent composition blur on Windows 10 & 11:

1. **Native C++ Runner Customization**:
   Split the implementation into isolated modules to avoid codebase pollution and compile issues:
   - **theme_win11.cpp**: Uses official DWM attributes to set the native system backdrop to transparent Acrylic (`DWMSBT_TRANSIENTWINDOW` = 3) on Windows 11 without drawing blocking solid caption backgrounds.
   - **theme_win10.cpp**: Uses undocumented `SetWindowCompositionAttribute` to apply Aero Blur (`ACCENT_ENABLE_BLURBEHIND` = 3) for 100% lag-free dragging on Windows 10, using a 1px top margin `cyTopHeight` to authorize client composition without drawing duplicate inner borders.
   - **win32_window.cpp**: Dispatcher based on version check. Passes an empty string `L""` as the window title text on Windows 10 to prevent GDI text rendering bounding box (halo) glitches.

2. **Register files in windows/runner/CMakeLists.txt**:
   ```cmake
   add_executable(${BINARY_NAME} WIN32
     "flutter_window.cpp"
     "main.cpp"
     "utils.cpp"
     "win32_window.cpp"
     "theme_win10.cpp"
     "theme_win11.cpp"
     "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
     "Runner.rc"
     "runner.exe.manifest"
   )
   ```

3. **MethodChannel Platform Link**:
   Use a method channel named `"ja_route/theme"` in `flutter_window.cpp` to receive theme changes from Dart and trigger window updates.

4. **Dart Split Theme modules**:
   - **styles.dart**: Platform coordinator, dynamically resolves the styles module at runtime using the `isWindows11` check.
   - **styles_win10.dart**: Set `scaffoldBackgroundColor` to `Colors.transparent` and apply custom translucency to layouts (50% alpha), sidebars (70% alpha), and panels/cards (85% alpha) to allow the Aero Blur background to show through clearly.
   - **styles_win11.dart**: Transparent scaffold and native titlebar Acrylic configurations.

====
🐧 UNIX RUNTIME SCRIPTS (macOS / LINUX)
================================================================================

To make the project run on macOS and Linux, include `.sh` UNIX scripts parallel to the Windows `.bat` scripts.

Execution Script (`run.sh`):

```bash
#!/bin/bash
# Move to the directory containing this script
cd "$(dirname "$0")"

# Detect OS to select target desktop platform
OS_NAME="$(uname -s)"
case "$OS_NAME" in
    Darwin*)
        TARGET="macos"
        ;;
    Linux*)
        TARGET="linux"
        ;;
    *)
        TARGET="linux"
        ;;
esac

flutter run -d "$TARGET"
```

================================================================================
🚀 RELEASE BUILD WORKFLOW (build.bat / build.sh)
================================================================================

To package the application for release and copy the compiled files to a `dist/` directory in the project root, add the following build scripts:

Release Build Script on Windows (`build.bat`):

```bat
@echo off
cd /d %~dp0
echo [BUILD] Compiling Windows desktop application in Release mode...
flutter build windows
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Build failed!
    pause
    exit /b %ERRORLEVEL%
)

echo [DIST] Copying release files to \dist...
if not exist "dist" mkdir "dist"
xcopy /s /e /y "build\windows\x64\runner\Release\*" "dist\"
echo [SUCCESS] Release build is complete. Output files copied to \dist
pause
```

Release Build Script on macOS/Linux (`build.sh`):

```bash
#!/bin/bash
cd "$(dirname "$0")"

OS_NAME="$(uname -s)"
case "$OS_NAME" in
    Darwin*)
        TARGET="macos"
        SRC_DIR="build/macos/Build/Products/Release"
        ;;
    *)
        TARGET="linux"
        SRC_DIR="build/linux/x64/release/bundle"
        ;;
esac

echo "[BUILD] Compiling $TARGET desktop application in Release mode..."
flutter build "$TARGET"
if [ $? -ne 0 ]; then
    echo "[ERROR] Build failed!"
    exit 1
fi

echo "[DIST] Copying release files to /dist..."
mkdir -p dist
cp -R "$SRC_DIR"/* dist/
echo "[SUCCESS] Release build is complete. Output files copied to /dist"
```
