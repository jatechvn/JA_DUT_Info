#include "auto_sn_native.h"

#include <devguid.h>
#include <setupapi.h>
#include <atomic>
#include <cwctype>
#include <mutex>

#pragma comment(lib, "setupapi.lib")

namespace {

HWND g_main_hwnd = nullptr;
HHOOK g_keyboard_hook = nullptr;
std::atomic<bool> g_enabled{false};
std::atomic<bool> g_capture_busy{false};
std::atomic<bool> g_session_waiting{false};

std::mutex g_config_mutex;
std::wstring g_target_exe_lower = L"javaw.exe";
std::vector<std::wstring> g_skip_tokens = {L"1\tPanelTamper"};

std::mutex g_payload_mutex;
AutoSnCapturedPayload g_latest_payload;

std::wstring ToLowerWide(const std::wstring& input) {
  std::wstring out = input;
  for (wchar_t& ch : out) {
    ch = static_cast<wchar_t>(std::towlower(ch));
  }
  return out;
}

std::wstring TrimWide(const std::wstring& s) {
  size_t start = 0;
  while (start < s.size() &&
         (s[start] == L' ' || s[start] == L'\t' || s[start] == L'\r' ||
          s[start] == L'\n')) {
    ++start;
  }
  size_t end = s.size();
  while (end > start &&
         (s[end - 1] == L' ' || s[end - 1] == L'\t' || s[end - 1] == L'\r' ||
          s[end - 1] == L'\n')) {
    --end;
  }
  return s.substr(start, end - start);
}

std::string WideToUtf8(const std::wstring& wstr) {
  if (wstr.empty()) return std::string();
  int size_needed = WideCharToMultiByte(
      CP_UTF8, 0, wstr.data(), static_cast<int>(wstr.size()), nullptr, 0,
      nullptr, nullptr);
  if (size_needed <= 0) return std::string();
  std::string result(static_cast<size_t>(size_needed), '\0');
  WideCharToMultiByte(CP_UTF8, 0, wstr.data(), static_cast<int>(wstr.size()),
                      result.data(), size_needed, nullptr, nullptr);
  return result;
}

bool IsTargetProcessWindow(HWND hwnd) {
  if (!hwnd || !IsWindow(hwnd)) return false;
  DWORD pid = 0;
  GetWindowThreadProcessId(hwnd, &pid);
  if (pid == 0) return false;

  HANDLE hProc = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (!hProc) return false;

  wchar_t path_buf[MAX_PATH] = {0};
  DWORD buf_len = MAX_PATH;
  bool matched = false;
  if (QueryFullProcessImageNameW(hProc, 0, path_buf, &buf_len) && buf_len > 0) {
    std::wstring full_path(path_buf, buf_len);
    size_t slash_pos = full_path.find_last_of(L"\\/");
    std::wstring base_name = (slash_pos == std::wstring::npos)
                                 ? full_path
                                 : full_path.substr(slash_pos + 1);
    std::wstring base_lower = ToLowerWide(base_name);
    std::lock_guard<std::mutex> lock(g_config_mutex);
    matched = (base_lower == g_target_exe_lower);
  }
  CloseHandle(hProc);
  return matched;
}

bool EnsureTargetForeground(HWND target_hwnd) {
  if (!target_hwnd || !IsWindow(target_hwnd)) return false;
  HWND fg = GetForegroundWindow();
  if (fg == target_hwnd || IsTargetProcessWindow(fg)) {
    return true;
  }
  SetForegroundWindow(target_hwnd);
  Sleep(40);
  fg = GetForegroundWindow();
  return (fg == target_hwnd || IsTargetProcessWindow(fg));
}

void SendVirtualKey(WORD vk, bool extended = false) {
  INPUT inputs[2] = {};
  inputs[0].type = INPUT_KEYBOARD;
  inputs[0].ki.wVk = vk;
  inputs[0].ki.dwFlags = extended ? KEYEVENTF_EXTENDEDKEY : 0;

  inputs[1].type = INPUT_KEYBOARD;
  inputs[1].ki.wVk = vk;
  inputs[1].ki.dwFlags =
      KEYEVENTF_KEYUP | (extended ? KEYEVENTF_EXTENDEDKEY : 0);

  SendInput(2, inputs, sizeof(INPUT));
}

void SendComboKey(WORD modifier_vk, WORD key_vk) {
  INPUT inputs[4] = {};
  inputs[0].type = INPUT_KEYBOARD;
  inputs[0].ki.wVk = modifier_vk;

  inputs[1].type = INPUT_KEYBOARD;
  inputs[1].ki.wVk = key_vk;

  inputs[2].type = INPUT_KEYBOARD;
  inputs[2].ki.wVk = key_vk;
  inputs[2].ki.dwFlags = KEYEVENTF_KEYUP;

  inputs[3].type = INPUT_KEYBOARD;
  inputs[3].ki.wVk = modifier_vk;
  inputs[3].ki.dwFlags = KEYEVENTF_KEYUP;

  SendInput(4, inputs, sizeof(INPUT));
}

void SendUnicodeString(const std::wstring& text) {
  if (text.empty()) return;
  std::vector<INPUT> inputs;
  inputs.reserve(text.size() * 2);
  for (wchar_t ch : text) {
    INPUT down = {};
    down.type = INPUT_KEYBOARD;
    down.ki.wScan = ch;
    down.ki.dwFlags = KEYEVENTF_UNICODE;
    inputs.push_back(down);

    INPUT up = {};
    up.type = INPUT_KEYBOARD;
    up.ki.wScan = ch;
    up.ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;
    inputs.push_back(up);
  }
  SendInput(static_cast<UINT>(inputs.size()), inputs.data(), sizeof(INPUT));
}

void ClearClipboardSafe() {
  for (int attempt = 0; attempt < 5; ++attempt) {
    if (OpenClipboard(nullptr)) {
      EmptyClipboard();
      CloseClipboard();
      return;
    }
    Sleep(10);
  }
}

std::wstring WaitAndReadClipboardText(int timeout_ms) {
  int elapsed = 0;
  constexpr int step_ms = 20;
  while (elapsed <= timeout_ms) {
    if (IsClipboardFormatAvailable(CF_UNICODETEXT) && OpenClipboard(nullptr)) {
      std::wstring result;
      HANDLE hData = GetClipboardData(CF_UNICODETEXT);
      if (hData) {
        const wchar_t* ptr = static_cast<const wchar_t*>(GlobalLock(hData));
        if (ptr) {
          result.assign(ptr);
          GlobalUnlock(hData);
        }
      }
      CloseClipboard();
      if (!result.empty()) {
        return result;
      }
    }
    Sleep(step_ms);
    elapsed += step_ms;
  }
  return std::wstring();
}

bool ContainsSkipToken(const std::wstring& text) {
  std::lock_guard<std::mutex> lock(g_config_mutex);
  for (const auto& token : g_skip_tokens) {
    if (!token.empty() && text.find(token) != std::wstring::npos) {
      return true;
    }
  }
  return false;
}

DWORD WINAPI CaptureSnWorkerProc(LPVOID param) {
  HWND javaw_hwnd = reinterpret_cast<HWND>(param);
  Sleep(150);
  if (!EnsureTargetForeground(javaw_hwnd)) {
    g_capture_busy.store(false);
    return 0;
  }

  // Shift+Tab to step back to the scanned SN field
  SendComboKey(VK_SHIFT, VK_TAB);
  Sleep(150);

  ClearClipboardSafe();
  SendComboKey(VK_CONTROL, 'A');
  SendComboKey(VK_CONTROL, 'C');
  std::wstring txt = TrimWide(WaitAndReadClipboardText(400));

  if (!txt.empty() && ContainsSkipToken(txt)) {
    // Handle "1\tPanelTamper" tab jump just like L10_PN_Check.ahk
    SendComboKey(VK_CONTROL, VK_TAB);
    Sleep(200);
    ClearClipboardSafe();
    SendComboKey(VK_CONTROL, 'A');
    SendComboKey(VK_CONTROL, 'C');
    txt = TrimWide(WaitAndReadClipboardText(400));
  }

  {
    std::lock_guard<std::mutex> lock(g_payload_mutex);
    g_latest_payload.text_utf8 = WideToUtf8(txt);
    g_latest_payload.javaw_hwnd = reinterpret_cast<int64_t>(javaw_hwnd);
  }

  if (g_main_hwnd && IsWindow(g_main_hwnd)) {
    PostMessageW(g_main_hwnd, WM_APP_AUTOSN_CAPTURED, 0, 0);
  } else {
    g_capture_busy.store(false);
  }
  return 0;
}

struct FillPnTaskArgs {
  HWND javaw_hwnd;
  std::wstring pn;
  bool had_caret;
  bool append_caret;
};

DWORD WINAPI FillPnWorkerProc(LPVOID param) {
  FillPnTaskArgs* args = static_cast<FillPnTaskArgs*>(param);
  if (!args) {
    g_capture_busy.store(false);
    return 0;
  }

  HWND javaw_hwnd = args->javaw_hwnd;
  std::wstring pn = args->pn;
  bool had_caret = args->had_caret;
  bool append_caret = args->append_caret;
  delete args;

  BOOL ok = FALSE;
  if (EnsureTargetForeground(javaw_hwnd)) {
    if (!had_caret) {
      SendVirtualKey(VK_END);
      SendUnicodeString(L"^");
      Sleep(200);
    } else {
      SendVirtualKey(VK_TAB);
      Sleep(150);
    }

    SendComboKey(VK_CONTROL, 'A');
    SendVirtualKey(VK_BACK);
    SendUnicodeString(pn);
    Sleep(50);
    if (append_caret) {
      SendUnicodeString(L"^");
    }
    Sleep(100);
    ClearClipboardSafe();
    ok = TRUE;
  }

  g_capture_busy.store(false);
  if (g_main_hwnd && IsWindow(g_main_hwnd)) {
    PostMessageW(g_main_hwnd, WM_APP_AUTOSN_PN_FILLED,
                  static_cast<WPARAM>(ok), 0);
  }
  return 0;
}

DWORD WINAPI NumpadEnterWorkerProc(LPVOID param) {
  HWND javaw_hwnd = reinterpret_cast<HWND>(param);
  if (EnsureTargetForeground(javaw_hwnd)) {
    SendVirtualKey(VK_RETURN, true);
  }
  ClearClipboardSafe();
  g_capture_busy.store(false);
  return 0;
}

DWORD WINAPI InvalidSnWorkerProc(LPVOID param) {
  HWND javaw_hwnd = reinterpret_cast<HWND>(param);
  MessageBeep(MB_ICONWARNING);
  Sleep(300);
  if (EnsureTargetForeground(javaw_hwnd)) {
    SendComboKey(VK_CONTROL, VK_TAB);
    Sleep(150);
    SendComboKey(VK_SHIFT, VK_TAB);
  }
  ClearClipboardSafe();
  g_capture_busy.store(false);
  return 0;
}

DWORD WINAPI SendSpaceWorkerProc(LPVOID param) {
  HWND javaw_hwnd = reinterpret_cast<HWND>(param);
  BOOL ok = FALSE;
  if (EnsureTargetForeground(javaw_hwnd)) {
    SendVirtualKey(VK_SPACE);
    ok = TRUE;
  }
  if (g_main_hwnd && IsWindow(g_main_hwnd)) {
    PostMessageW(g_main_hwnd, WM_APP_AUTOSN_SPACE_SENT,
                 static_cast<WPARAM>(ok), 0);
  }
  return 0;
}

LRESULT CALLBACK LowLevelKeyboardProc(int nCode, WPARAM wParam, LPARAM lParam) {
  if (nCode >= 0 && g_enabled.load()) {
    const auto* pKey = reinterpret_cast<const KBDLLHOOKSTRUCT*>(lParam);
    if (pKey) {
      const bool injected =
          (pKey->flags & (LLKHF_INJECTED | LLKHF_LOWER_IL_INJECTED)) != 0;
      if (!injected && wParam == WM_KEYDOWN) {
        if (pKey->vkCode == VK_ESCAPE && g_session_waiting.load()) {
          if (g_main_hwnd && IsWindow(g_main_hwnd)) {
            PostMessageW(g_main_hwnd, WM_APP_AUTOSN_ESC, 0, 0);
          }
        } else if (pKey->vkCode == VK_RETURN) {
          const bool modifiers_down =
              ((GetAsyncKeyState(VK_SHIFT) & 0x8000) != 0) ||
              ((GetAsyncKeyState(VK_CONTROL) & 0x8000) != 0) ||
              ((GetAsyncKeyState(VK_MENU) & 0x8000) != 0);
          if (!modifiers_down) {
            HWND fg = GetForegroundWindow();
            if (IsTargetProcessWindow(fg)) {
              bool expected = false;
              if (g_capture_busy.compare_exchange_strong(expected, true)) {
                QueueUserWorkItem(CaptureSnWorkerProc,
                                  reinterpret_cast<PVOID>(fg),
                                  WT_EXECUTELONGFUNCTION);
              }
              // Swallow raw Enter inside javaw.exe so AutoSN controls the flow
              return 1;
            }
          }
        }
      }
    }
  }
  return CallNextHookEx(g_keyboard_hook, nCode, wParam, lParam);
}

}  // namespace

void AutoSnNative::Initialize(HWND main_hwnd) {
  g_main_hwnd = main_hwnd;
}

void AutoSnNative::Shutdown() {
  SetEnabled(false);
  g_session_waiting.store(false);
  g_capture_busy.store(false);
  g_main_hwnd = nullptr;
}

void AutoSnNative::SetEnabled(bool enabled) {
  g_enabled.store(enabled);
  if (enabled) {
    if (!g_keyboard_hook) {
      g_keyboard_hook = SetWindowsHookExW(
          WH_KEYBOARD_LL, LowLevelKeyboardProc, GetModuleHandleW(nullptr), 0);
    }
  } else {
    if (g_keyboard_hook) {
      UnhookWindowsHookEx(g_keyboard_hook);
      g_keyboard_hook = nullptr;
    }
    g_session_waiting.store(false);
    g_capture_busy.store(false);
  }
}

bool AutoSnNative::IsEnabled() {
  return g_enabled.load();
}

void AutoSnNative::SetTargetProcessName(const std::wstring& exe_name) {
  if (exe_name.empty()) return;
  std::lock_guard<std::mutex> lock(g_config_mutex);
  g_target_exe_lower = ToLowerWide(exe_name);
}

void AutoSnNative::SetSkipTokens(const std::vector<std::wstring>& tokens) {
  std::lock_guard<std::mutex> lock(g_config_mutex);
  g_skip_tokens = tokens;
}

void AutoSnNative::SetSessionWaiting(bool waiting) {
  g_session_waiting.store(waiting);
}

int AutoSnNative::CountComPortsByKeyword(const std::wstring& keyword) {
  if (keyword.empty()) return 0;
  std::wstring target_lower = ToLowerWide(keyword);

  HDEVINFO hDevInfo = SetupDiGetClassDevsW(
      &GUID_DEVCLASS_PORTS, nullptr, nullptr, DIGCF_PRESENT);
  if (hDevInfo == INVALID_HANDLE_VALUE) {
    return 0;
  }

  int match_count = 0;
  SP_DEVINFO_DATA devInfoData = {};
  devInfoData.cbSize = sizeof(SP_DEVINFO_DATA);

  for (DWORD i = 0; SetupDiEnumDeviceInfo(hDevInfo, i, &devInfoData); ++i) {
    wchar_t friendly_name[512] = {0};
    DWORD reg_type = 0;
    DWORD req_size = 0;
    if (SetupDiGetDeviceRegistryPropertyW(
            hDevInfo, &devInfoData, SPDRP_FRIENDLYNAME, &reg_type,
            reinterpret_cast<PBYTE>(friendly_name),
            sizeof(friendly_name) - sizeof(wchar_t), &req_size)) {
      std::wstring name_lower = ToLowerWide(friendly_name);
      if (name_lower.find(target_lower) != std::wstring::npos) {
        ++match_count;
      }
    }
  }

  SetupDiDestroyDeviceInfoList(hDevInfo);
  return match_count;
}

AutoSnCapturedPayload AutoSnNative::ConsumeCapturedPayload() {
  std::lock_guard<std::mutex> lock(g_payload_mutex);
  AutoSnCapturedPayload copy = g_latest_payload;
  g_latest_payload.text_utf8.clear();
  return copy;
}

void AutoSnNative::SendNumpadEnterAsync(int64_t javaw_hwnd) {
  QueueUserWorkItem(NumpadEnterWorkerProc,
                    reinterpret_cast<PVOID>(static_cast<intptr_t>(javaw_hwnd)),
                    WT_EXECUTELONGFUNCTION);
}

void AutoSnNative::RestoreInvalidSnFocusAsync(int64_t javaw_hwnd) {
  QueueUserWorkItem(InvalidSnWorkerProc,
                    reinterpret_cast<PVOID>(static_cast<intptr_t>(javaw_hwnd)),
                    WT_EXECUTELONGFUNCTION);
}

void AutoSnNative::FillPnAsync(int64_t javaw_hwnd, const std::wstring& pn,
                               bool had_caret, bool append_caret) {
  auto* args = new FillPnTaskArgs{
      reinterpret_cast<HWND>(static_cast<intptr_t>(javaw_hwnd)), pn, had_caret,
      append_caret};
  if (!QueueUserWorkItem(FillPnWorkerProc, args, WT_EXECUTELONGFUNCTION)) {
    delete args;
    g_capture_busy.store(false);
  }
}

void AutoSnNative::SendSpaceAsync(int64_t javaw_hwnd) {
  QueueUserWorkItem(SendSpaceWorkerProc,
                    reinterpret_cast<PVOID>(static_cast<intptr_t>(javaw_hwnd)),
                    WT_EXECUTELONGFUNCTION);
}
