#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>

#include <flutter/method_channel.h>
#include <memory>

#include "win32_window.h"

#include <vector>

struct HitTestRect {
  double x;
  double y;
  double w;
  double h;
};

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

  // Dynamic mouse click-through methods
  void UpdateClickThrough(POINT screen_pt);
  void SetClickThrough(bool click_through);
  bool IsPointInsideHitRects(POINT screen_pt) const;

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // The theme MethodChannel
  std::unique_ptr<flutter::MethodChannel<>> theme_channel_;

  // The window MethodChannel for dragging
  std::unique_ptr<flutter::MethodChannel<>> window_channel_;

  // Dragging and click-through state
  bool is_dragging_ = false;
  bool is_click_through_ = false;
  UINT_PTR hit_test_timer_id_ = 0;

  // Hit-testing rectangles for mouse pass-through
  bool has_set_rects_ = false;
  std::vector<HitTestRect> hit_test_rects_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
