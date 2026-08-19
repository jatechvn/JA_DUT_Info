#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {

struct FindInstanceParams {
  HWND hwndFound = nullptr;
};

BOOL CALLBACK FindInstanceWindowProc(HWND hwnd, LPARAM lParam) {
  FindInstanceParams* params = reinterpret_cast<FindInstanceParams*>(lParam);
  wchar_t className[256];
  if (::GetClassNameW(hwnd, className, 256) > 0) {
    if (::wcscmp(className, L"FLUTTER_RUNNER_WIN32_WINDOW") == 0) {
      if (::GetPropW(hwnd, L"JA_DUT_INFO_INSTANCE") == (HANDLE)1) {
        params->hwndFound = hwnd;
        return FALSE; // Stop enumerating
      }
    }
  }
  return TRUE; // Continue enumerating
}

} // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Use a named mutex to detect if another instance is running
  HANDLE hMutex = ::CreateMutexW(nullptr, TRUE, L"Local\\ja_dut_info_single_instance_mutex");
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
      // If the window is minimized (iconic), restore it
      if (::IsIconic(existing_hwnd)) {
        ::ShowWindow(existing_hwnd, SW_RESTORE);
      } else {
        ::ShowWindow(existing_hwnd, SW_SHOW);
      }
      // Bring it to foreground
      ::SetForegroundWindow(existing_hwnd);
      ::SetFocus(existing_hwnd);
    }
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS)) {
    if (::IsDebuggerPresent()) {
      CreateAndAttachConsole();
    } else {
      ::AllocConsole();
      HWND hwnd = ::GetConsoleWindow();
      if (hwnd) {
        ::ShowWindow(hwnd, SW_HIDE);
      }
    }
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  // Set size to 410 x 300
  Win32Window::Size size(410, 300);
  if (!window.Create(L"ja_dut_info", origin, size)) {
    ::ReleaseMutex(hMutex);
    ::CloseHandle(hMutex);
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  // Set property to identify this window as the main ja_dut_info instance
  ::SetPropW(window.GetHandle(), L"JA_DUT_INFO_INSTANCE", (HANDLE)1);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();

  ::ReleaseMutex(hMutex);
  ::CloseHandle(hMutex);

  return EXIT_SUCCESS;
}
