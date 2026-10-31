#ifndef RUNNER_AUTO_SN_NATIVE_H_
#define RUNNER_AUTO_SN_NATIVE_H_

#include <windows.h>
#include <string>
#include <vector>

// Custom window messages posted from worker/hook threads to FlutterWindow
constexpr UINT WM_APP_AUTOSN_CAPTURED = WM_APP + 101;
constexpr UINT WM_APP_AUTOSN_PN_FILLED = WM_APP + 102;
constexpr UINT WM_APP_AUTOSN_SPACE_SENT = WM_APP + 103;
constexpr UINT WM_APP_AUTOSN_ESC = WM_APP + 104;

struct AutoSnCapturedPayload {
  std::string text_utf8;
  int64_t javaw_hwnd = 0;
};

class AutoSnNative {
 public:
  static void Initialize(HWND main_hwnd);
  static void Shutdown();

  // Dynamic hook lifecycle: only installs WH_KEYBOARD_LL when enabled is true.
  static void SetEnabled(bool enabled);
  static bool IsEnabled();

  static void SetTargetProcessName(const std::wstring& exe_name);
  static void SetSkipTokens(const std::vector<std::wstring>& tokens);
  static void SetSessionWaiting(bool waiting);

  // Fast native SetupAPI scan for COM ports matching keyword (e.g. "Qualcomm HS-USB Diagnostics 9091")
  static int CountComPortsByKeyword(const std::wstring& keyword);

  // Consumes the latest captured SN payload on the main UI thread
  static AutoSnCapturedPayload ConsumeCapturedPayload();

  // Asynchronous input actions executed on OS worker threads
  static void SendNumpadEnterAsync(int64_t javaw_hwnd);
  static void RestoreInvalidSnFocusAsync(int64_t javaw_hwnd);
  static void FillPnAsync(int64_t javaw_hwnd, const std::wstring& pn,
                          bool had_caret, bool append_caret);
  static void SendSpaceAsync(int64_t javaw_hwnd);
};

#endif  // RUNNER_AUTO_SN_NATIVE_H_
