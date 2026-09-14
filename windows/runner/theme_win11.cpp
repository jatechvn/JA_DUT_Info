#include "theme_win11.h"
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

void ApplyThemeWin11(HWND hwnd, bool is_dark, bool is_startup) {
  BOOL enable_dark_mode = is_dark ? TRUE : FALSE;
  // DWMWA_USE_IMMERSIVE_DARK_MODE is 20
  DwmSetWindowAttribute(hwnd, 20, &enable_dark_mode, sizeof(enable_dark_mode));

  if (is_startup) {
    // Set backdrop type to DWMSBT_NONE (1) for 100% transparent see-through (no acrylic/blur box)
    int backdrop_type = 1;
    DwmSetWindowAttribute(hwnd, 38, &backdrop_type, sizeof(backdrop_type));

    // Do not round outer invisible window rect (DWMWCP_DONOTROUND = 1)
    int corner_preference = 1; 
    DwmSetWindowAttribute(hwnd, 33, &corner_preference, sizeof(corner_preference));

    // Extend full frame into client area for transparency
    MARGINS margins = { -1, -1, -1, -1 };
    DwmExtendFrameIntoClientArea(hwnd, &margins);
  }

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
}
