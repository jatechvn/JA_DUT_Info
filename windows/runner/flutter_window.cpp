#include "flutter_window.h"

#include <optional>
#include <commctrl.h>
#include <windowsx.h>
#include <flutter/standard_method_codec.h>
#include "theme_win10.h"
#include "theme_win11.h"

#pragma comment(lib, "comctl32.lib")

// Global mouse hook and instance pointer for dynamic click-through
static HHOOK g_mouse_hook = nullptr;
static FlutterWindow* g_flutter_window_instance = nullptr;

static LRESULT CALLBACK LowLevelMouseProc(int nCode, WPARAM wParam, LPARAM lParam) {
  if (nCode >= 0 && g_flutter_window_instance) {
    auto* pMouse = reinterpret_cast<MSLLHOOKSTRUCT*>(lParam);
    if (pMouse) {
      g_flutter_window_instance->UpdateClickThrough(pMouse->pt);
    }
  }
  return CallNextHookEx(g_mouse_hook, nCode, wParam, lParam);
}

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

flutter::EncodableMap GetWindowPositionInfo(HWND hwnd) {
  RECT rect;
  GetWindowRect(hwnd, &rect);

  HMONITOR hMon = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
  MONITORINFO mi = { sizeof(MONITORINFO) };
  GetMonitorInfo(hMon, &mi);

  int screen_w = mi.rcWork.right - mi.rcWork.left;
  int screen_h = mi.rcWork.bottom - mi.rcWork.top;

  int win_center_x = (rect.left + rect.right) / 2 - mi.rcWork.left;
  int win_center_y = (rect.top + rect.bottom) / 2 - mi.rcWork.top;

  bool is_right = (win_center_x > screen_w / 2);
  bool is_bottom = (win_center_y > screen_h / 2);

  int dist_left = rect.left - mi.rcWork.left;
  int dist_right = mi.rcWork.right - rect.right;
  int dist_top = rect.top - mi.rcWork.top;
  int dist_bottom = mi.rcWork.bottom - rect.bottom;

  // Docked when within 20px of monitor edge
  bool is_docked_left = (dist_left <= 20);
  bool is_docked_right = (dist_right <= 20);
  bool is_docked_top = (dist_top <= 20);
  bool is_docked_bottom = (dist_bottom <= 20);

  std::string corner = (is_bottom ? "B" : "T") + std::string(is_right ? "R" : "L");

  return flutter::EncodableMap{
    {flutter::EncodableValue("corner"), flutter::EncodableValue(corner)},
    {flutter::EncodableValue("isRight"), flutter::EncodableValue(is_right)},
    {flutter::EncodableValue("isBottom"), flutter::EncodableValue(is_bottom)},
    {flutter::EncodableValue("isDockedLeft"), flutter::EncodableValue(is_docked_left)},
    {flutter::EncodableValue("isDockedRight"), flutter::EncodableValue(is_docked_right)},
    {flutter::EncodableValue("isDockedTop"), flutter::EncodableValue(is_docked_top)},
    {flutter::EncodableValue("isDockedBottom"), flutter::EncodableValue(is_docked_bottom)},
    {flutter::EncodableValue("x"), flutter::EncodableValue(rect.left)},
    {flutter::EncodableValue("y"), flutter::EncodableValue(rect.top)},
    {flutter::EncodableValue("screenWidth"), flutter::EncodableValue(screen_w)},
    {flutter::EncodableValue("screenHeight"), flutter::EncodableValue(screen_h)},
  };
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

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // WS_EX_TRANSPARENT alone only changes painting order. A layered
  // top-level window also passes mouse input to other applications.
  HWND hwnd = GetHandle();
  SetWindowLongPtr(hwnd, GWL_EXSTYLE,
                   GetWindowLongPtr(hwnd, GWL_EXSTYLE) | WS_EX_LAYERED);
  SetLayeredWindowAttributes(hwnd, 0, 255, LWA_ALPHA);

  // Setup low-level mouse hook and backup timer for dynamic click-through
  g_flutter_window_instance = this;
  g_mouse_hook = SetWindowsHookEx(WH_MOUSE_LL, LowLevelMouseProc, GetModuleHandle(nullptr), 0);
  hit_test_timer_id_ = SetTimer(GetHandle(), 1001, 20, nullptr);

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
            is_dragging_ = true;
            SetClickThrough(false);
            ReleaseCapture();
            SendMessage(hwnd, WM_SYSCOMMAND, 0xF012, 0);
            is_dragging_ = false;

            // Magnetic Edge Snapping: If dropped within 40px of screen border, snap flush
            RECT rect;
            GetWindowRect(hwnd, &rect);
            HMONITOR hMon = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
            MONITORINFO mi = { sizeof(MONITORINFO) };
            GetMonitorInfo(hMon, &mi);

            int win_w = rect.right - rect.left;
            int win_h = rect.bottom - rect.top;
            int dist_left = rect.left - mi.rcWork.left;
            int dist_right = mi.rcWork.right - rect.right;
            int dist_top = rect.top - mi.rcWork.top;
            int dist_bottom = mi.rcWork.bottom - rect.bottom;

            int new_x = rect.left;
            int new_y = rect.top;
            bool snapped = false;

            if (dist_right <= 40) {
              new_x = mi.rcWork.right - win_w;
              snapped = true;
            } else if (dist_left <= 40) {
              new_x = mi.rcWork.left;
              snapped = true;
            }

            if (dist_top <= 40) {
              new_y = mi.rcWork.top;
              snapped = true;
            } else if (dist_bottom <= 40) {
              new_y = mi.rcWork.bottom - win_h;
              snapped = true;
            }

            if (snapped) {
              SetWindowPos(hwnd, nullptr, new_x, new_y, win_w, win_h,
                           SWP_NOZORDER | SWP_NOACTIVATE);
            }

            POINT pt;
            if (GetCursorPos(&pt)) {
              UpdateClickThrough(pt);
            }

            // After modal drag loop exits, immediately notify Flutter of the new position
            auto info = GetWindowPositionInfo(hwnd);
            window_channel_->InvokeMethod("onPositionChanged", std::make_unique<flutter::EncodableValue>(info));
          }
          result->Success();
        } else if (call.method_name() == "getPosition") {
          HWND hwnd = GetHandle();
          if (hwnd) {
            auto info = GetWindowPositionInfo(hwnd);
            result->Success(flutter::EncodableValue(info));
          } else {
            result->Error("NO_HWND", "Window handle not available");
          }
        } else if (call.method_name() == "setHitTestRects") {
          const auto* args = std::get_if<flutter::EncodableList>(call.arguments());
          if (args) {
            std::vector<HitTestRect> new_rects;
            for (const auto& item : *args) {
              if (const auto* map = std::get_if<flutter::EncodableMap>(&item)) {
                auto x_it = map->find(flutter::EncodableValue("x"));
                auto y_it = map->find(flutter::EncodableValue("y"));
                auto w_it = map->find(flutter::EncodableValue("w"));
                auto h_it = map->find(flutter::EncodableValue("h"));
                if (x_it != map->end() && y_it != map->end() &&
                    w_it != map->end() && h_it != map->end()) {
                  auto get_val = [](const flutter::EncodableValue& val) -> double {
                    if (std::holds_alternative<double>(val)) return std::get<double>(val);
                    if (std::holds_alternative<int>(val)) return static_cast<double>(std::get<int>(val));
                    if (std::holds_alternative<int64_t>(val)) return static_cast<double>(std::get<int64_t>(val));
                    return 0.0;
                  };
                  double x = get_val(x_it->second);
                  double y = get_val(y_it->second);
                  double w = get_val(w_it->second);
                  double h = get_val(h_it->second);
                  new_rects.push_back({x, y, w, h});
                }
              }
            }
            hit_test_rects_ = std::move(new_rects);
            has_set_rects_ = true;

            POINT pt;
            if (GetCursorPos(&pt)) {
              UpdateClickThrough(pt);
            }
          }
          result->Success();
        } else {
          result->NotImplemented();
        }
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
    // Notify initial window position
    HWND hwnd = GetHandle();
    if (hwnd && window_channel_) {
      auto info = GetWindowPositionInfo(hwnd);
      window_channel_->InvokeMethod("onPositionChanged", std::make_unique<flutter::EncodableValue>(info));
    }
  });

  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (g_mouse_hook) {
    UnhookWindowsHookEx(g_mouse_hook);
    g_mouse_hook = nullptr;
  }
  g_flutter_window_instance = nullptr;

  if (hit_test_timer_id_) {
    KillTimer(GetHandle(), hit_test_timer_id_);
    hit_test_timer_id_ = 0;
  }

  HWND hwnd = GetHandle();
  if (hwnd != nullptr) {
    ::RemovePropW(hwnd, L"JA_DUT_INFO_INSTANCE");
  }
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

bool FlutterWindow::IsPointInsideHitRects(POINT screen_pt) const {
  if (!has_set_rects_) {
    return true;
  }

  HWND top_hwnd = const_cast<FlutterWindow*>(this)->GetHandle();
  if (!top_hwnd || !IsWindow(top_hwnd)) return true;

  POINT pt = screen_pt;
  ::ScreenToClient(top_hwnd, &pt);

  UINT dpi = GetDpiForWindow(top_hwnd);
  double scale = (dpi > 0) ? (static_cast<double>(dpi) / 96.0) : 1.0;

  double logical_x = pt.x / scale;
  double logical_y = pt.y / scale;

  for (const auto& r : hit_test_rects_) {
    if (logical_x >= r.x && logical_x < (r.x + r.w) &&
        logical_y >= r.y && logical_y < (r.y + r.h)) {
      return true;
    }
  }

  return false;
}

void FlutterWindow::UpdateClickThrough(POINT screen_pt) {
  HWND top_hwnd = GetHandle();
  if (!top_hwnd || !IsWindow(top_hwnd) || !IsWindowVisible(top_hwnd)) return;

  if (is_dragging_) {
    SetClickThrough(false);
    return;
  }

  RECT win_rect;
  GetWindowRect(top_hwnd, &win_rect);

  bool inside = false;
  if (PtInRect(&win_rect, screen_pt)) {
    inside = IsPointInsideHitRects(screen_pt);
  }

  SetClickThrough(!inside);
}

void FlutterWindow::SetClickThrough(bool click_through) {
  if (is_click_through_ == click_through) return;

  HWND top_hwnd = GetHandle();
  if (!top_hwnd || !IsWindow(top_hwnd)) return;

  LONG_PTR style = GetWindowLongPtr(top_hwnd, GWL_EXSTYLE);
  bool currently_transparent = (style & WS_EX_TRANSPARENT) != 0;

  if (click_through && !currently_transparent) {
    SetWindowLongPtr(top_hwnd, GWL_EXSTYLE, style | WS_EX_TRANSPARENT);
    SetWindowPos(top_hwnd, nullptr, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
    is_click_through_ = true;
  } else if (!click_through && currently_transparent) {
    SetWindowLongPtr(top_hwnd, GWL_EXSTYLE, style & ~WS_EX_TRANSPARENT);
    SetWindowPos(top_hwnd, nullptr, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
    is_click_through_ = false;
  }
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_TIMER && wparam == 1001) {
    POINT pt;
    if (GetCursorPos(&pt)) {
      UpdateClickThrough(pt);
    }
    return 0;
  }

  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_EXITSIZEMOVE:
    case WM_MOVE: {
      if (hwnd && window_channel_) {
        auto info = GetWindowPositionInfo(hwnd);
        window_channel_->InvokeMethod("onPositionChanged", std::make_unique<flutter::EncodableValue>(info));
      }
      break;
    }
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
