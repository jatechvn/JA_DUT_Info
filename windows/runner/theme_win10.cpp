#include "theme_win10.h"
#include <dwmapi.h>

// Undocumented API structures for WindowCompositionAttribute
typedef enum _WINDOWCOMPOSITIONATTRIB {
  WCA_ACCENT_POLICY = 19
} WINDOWCOMPOSITIONATTRIB;

typedef enum _ACCENT_STATE {
  ACCENT_DISABLED = 0,
  ACCENT_ENABLE_GRADIENT = 1,
  ACCENT_ENABLE_TRANSPARENTBACKGROUND = 2,
  ACCENT_ENABLE_BLURBEHIND = 3,
  ACCENT_ENABLE_ACRYLICBLURBEHIND = 4,
  ACCENT_INVALID_STATE = 5
} ACCENT_STATE;

typedef struct _ACCENT_POLICY {
  ACCENT_STATE AccentState;
  DWORD AccentFlags;
  DWORD Color;
  DWORD AnimationId;
} ACCENT_POLICY;

typedef struct _WINDOWCOMPOSITIONATTRIBDATA {
  WINDOWCOMPOSITIONATTRIB Attribute;
  PVOID pData;
  DWORD SizeOfData;
} WINDOWCOMPOSITIONATTRIBDATA;

typedef BOOL(WINAPI* pSetWindowCompositionAttribute)(HWND, WINDOWCOMPOSITIONATTRIBDATA*);

void ApplyThemeWin10(HWND hwnd, bool is_dark) {
  BOOL enable_dark_mode = is_dark ? TRUE : FALSE;
  DwmSetWindowAttribute(hwnd, 19, &enable_dark_mode, sizeof(enable_dark_mode));
  DwmSetWindowAttribute(hwnd, 20, &enable_dark_mode, sizeof(enable_dark_mode));

  HMODULE hUser = GetModuleHandleA("user32.dll");
  if (hUser) {
    pSetWindowCompositionAttribute setWindowCompAttr = 
        (pSetWindowCompositionAttribute)GetProcAddress(hUser, "SetWindowCompositionAttribute");
    if (setWindowCompAttr) {
      ACCENT_POLICY policy = { ACCENT_ENABLE_TRANSPARENTBACKGROUND, 2u, 0x00000000, 0u };
      WINDOWCOMPOSITIONATTRIBDATA data = { WCA_ACCENT_POLICY, &policy, sizeof(policy) };
      setWindowCompAttr(hwnd, &data);
    }
  }

  // Extend frame to entire client area for transparency
  MARGINS margins = { -1, -1, -1, -1 };
  DwmExtendFrameIntoClientArea(hwnd, &margins);

  // Force window repaint
  RECT rect;
  GetWindowRect(hwnd, &rect);
  SetWindowPos(hwnd, nullptr, 0, 0, (rect.right - rect.left) - 1, (rect.bottom - rect.top), SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
  SetWindowPos(hwnd, nullptr, 0, 0, (rect.right - rect.left), (rect.bottom - rect.top), SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);

  SendMessage(hwnd, WM_NCACTIVATE, FALSE, 0);
  SendMessage(hwnd, WM_NCACTIVATE, TRUE, 0);
}
