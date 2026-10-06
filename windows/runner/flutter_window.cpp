#include "flutter_window.h"

#include <optional>
#include <algorithm>

#include "flutter/generated_plugin_registrant.h"

namespace {
constexpr wchar_t kWindowKey[] = L"Software\\dq52099\\RE0\\Window";

void RestoreWindow(HWND hwnd) {
  WINDOWPLACEMENT placement{};
  DWORD bytes = sizeof(placement);
  if (RegGetValue(HKEY_CURRENT_USER, kWindowKey, L"Placement", RRF_RT_REG_BINARY,
                  nullptr, &placement, &bytes) == ERROR_SUCCESS &&
      bytes == sizeof(placement) && placement.length == sizeof(placement) &&
      MonitorFromRect(&placement.rcNormalPosition, MONITOR_DEFAULTTONULL)) {
    placement.showCmd = SW_HIDE;
    SetWindowPlacement(hwnd, &placement);
  } else {
    RECT area{};
    SystemParametersInfo(SPI_GETWORKAREA, 0, &area, 0);
    const int width = (std::min)(1360, static_cast<int>(area.right - area.left));
    const int height = (std::min)(880, static_cast<int>(area.bottom - area.top));
    SetWindowPos(hwnd, nullptr, area.left + (area.right - area.left - width) / 2,
                 area.top + (area.bottom - area.top - height) / 2,
                 width, height, SWP_NOZORDER | SWP_NOACTIVATE);
  }
}

void SaveWindow(HWND hwnd) {
  WINDOWPLACEMENT placement{};
  placement.length = sizeof(placement);
  if (GetWindowPlacement(hwnd, &placement)) {
    RegSetKeyValue(HKEY_CURRENT_USER, kWindowKey, L"Placement", REG_BINARY,
                    &placement, sizeof(placement));
  }
}
}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RestoreWindow(GetHandle());

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
    case WM_CLOSE:
      SaveWindow(hwnd);
      break;
    case WM_GETMINMAXINFO: {
      const UINT dpi = GetDpiForWindow(hwnd);
      auto limits = reinterpret_cast<MINMAXINFO*>(lparam);
      limits->ptMinTrackSize.x = MulDiv(720, dpi, 96);
      limits->ptMinTrackSize.y = MulDiv(560, dpi, 96);
      return 0;
    }
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
