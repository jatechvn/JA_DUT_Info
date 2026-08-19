#include "flutter_window.h"

#include <optional>
#include <flutter/standard_method_codec.h>
#include "theme_win10.h"
#include "theme_win11.h"

namespace {
// RTL version structure for ntdll check
typedef struct _RTL_OSVERSIONINFOW {
  ULONG dwOSVersionInfoSize;
  ULONG dwMajorVersion;
  ULONG dwMinorVersion;
  ULONG dwBuildNumber;
  ULONG dwPlatformId;
  WCHAR szCSDVersion[128];
} RTL_OSVERSIONINFOW, *PRTL_OSVERSIONINFOW;

typedef void (WINAPI *RtlGetVersionPtr)(PRTL_OSVERSIONINFOW);

bool IsWindows11OrGreater() {
  HMODULE hMod = GetModuleHandleA("ntdll.dll");
  if (hMod) {
    RtlGetVersionPtr pRtlGetVersion = (RtlGetVersionPtr)GetProcAddress(hMod, "RtlGetVersion");
    if (pRtlGetVersion) {
      RTL_OSVERSIONINFOW osvi = { 0 };
      osvi.dwOSVersionInfoSize = sizeof(osvi);
      pRtlGetVersion(&osvi);
      return osvi.dwMajorVersion > 10 || (osvi.dwMajorVersion == 10 && osvi.dwBuildNumber >= 22000);
    }
  }
  return false;
}
} // namespace

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  auto messenger = flutter_controller_->engine()->messenger();
  
  theme_channel_ = std::make_unique<flutter::MethodChannel<>>(
      messenger, "ja_route/theme",
      &flutter::StandardMethodCodec::GetInstance());

  theme_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<>& call,
             std::unique_ptr<flutter::MethodResult<>> result) {
        if (call.method_name() == "updateTheme") {
           const flutter::EncodableValue* args = call.arguments();
           bool is_dark = true;
           if (args && std::holds_alternative<bool>(*args)) {
             is_dark = std::get<bool>(*args);
           }

          HWND hwnd = GetHandle();
          if (hwnd) {
            if (IsWindows11OrGreater()) {
              ApplyThemeWin11(hwnd, is_dark, true);
            } else {
              ApplyThemeWin10(hwnd, is_dark);
            }
          }
          result->Success();
        } else {
          result->NotImplemented();
        }
      });

  window_channel_ = std::make_unique<flutter::MethodChannel<>>(
      messenger, "ja_route/window",
      &flutter::StandardMethodCodec::GetInstance());

  window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<>& call,
             std::unique_ptr<flutter::MethodResult<>> result) {
        if (call.method_name() == "startDrag") {
          HWND hwnd = GetHandle();
          if (hwnd) {
            ReleaseCapture();
            SendMessage(hwnd, WM_SYSCOMMAND, 0xF012, 0);
          }
          result->Success();
        } else {
          result->NotImplemented();
        }
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  HWND hwnd = GetHandle();
  if (hwnd != nullptr) {
    ::RemovePropW(hwnd, L"JA_DUT_INFO_INSTANCE");
  }
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
