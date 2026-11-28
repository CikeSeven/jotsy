#include "win32_window.h"

#include <dwmapi.h>
#include <flutter_windows.h>

#include <vector>

#include "resource.h"
#include "window_state_store.h"

namespace {

/// Window attribute that enables dark mode window decorations.
///
/// Redefined in case the developer's machine has a Windows SDK older than
/// version 10.0.22000.0.
/// See: https://docs.microsoft.com/windows/win32/api/dwmapi/ne-dwmapi-dwmwindowattribute
#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

/// Registry key for app theme preference.
///
/// A value of 0 indicates apps should use dark mode. A non-zero or missing
/// value indicates apps should use light mode.
constexpr const wchar_t kGetPreferredBrightnessRegKey[] =
  L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";
constexpr const wchar_t kGetPreferredBrightnessRegValue[] = L"AppsUseLightTheme";

// Minimum window size in logical pixels. Below 400 wide the phone layout
// starts to clip, so the window is not allowed to shrink further. Scaled to
// physical pixels with the DPI of the monitor the window is on.
constexpr int kMinWindowWidth = 400;
constexpr int kMinWindowHeight = 600;

// Timer ID and debounce interval for persisting window geometry after moves,
// keyboard snaps, or maximize toggles without writing every drag frame.
constexpr UINT_PTR kSaveWindowStateTimerId = 0x4A545753;
constexpr UINT kSaveWindowStateDelayMs = 300;

bool WindowStatesEqual(const WindowState& a, const WindowState& b) {
  return a.has_position == b.has_position && a.x == b.x && a.y == b.y &&
         a.width == b.width && a.height == b.height &&
         a.maximized == b.maximized && a.dpi == b.dpi;
}

// The number of Win32Window objects that currently exist.
static int g_active_window_count = 0;

using EnableNonClientDpiScaling = BOOL __stdcall(HWND hwnd);

// Scale helper to convert logical scaler values to physical using passed in
// scale factor
int Scale(int source, double scale_factor) {
  return static_cast<int>(source * scale_factor);
}

// Dynamically loads the |EnableNonClientDpiScaling| from the User32 module.
// This API is only needed for PerMonitor V1 awareness mode.
void EnableFullDpiSupportIfAvailable(HWND hwnd) {
  HMODULE user32_module = LoadLibraryA("User32.dll");
  if (!user32_module) {
    return;
  }
  auto enable_non_client_dpi_scaling =
      reinterpret_cast<EnableNonClientDpiScaling*>(
          GetProcAddress(user32_module, "EnableNonClientDpiScaling"));
  if (enable_non_client_dpi_scaling != nullptr) {
    enable_non_client_dpi_scaling(hwnd);
  }
  FreeLibrary(user32_module);
}

}  // namespace

// Manages the Win32Window's window class registration.
class WindowClassRegistrar {
 public:
  ~WindowClassRegistrar() = default;

  // Returns the singleton registrar instance.
  static WindowClassRegistrar* GetInstance() {
    if (!instance_) {
      instance_ = new WindowClassRegistrar();
    }
    return instance_;
  }

  // Returns the name of the window class, registering the class if it hasn't
  // previously been registered.
  const wchar_t* GetWindowClass();

  // Unregisters the window class. Should only be called if there are no
  // instances of the window.
  void UnregisterWindowClass();

 private:
  WindowClassRegistrar() = default;

  static WindowClassRegistrar* instance_;

  bool class_registered_ = false;
};

WindowClassRegistrar* WindowClassRegistrar::instance_ = nullptr;

const wchar_t* WindowClassRegistrar::GetWindowClass() {
  if (!class_registered_) {
    WNDCLASS window_class{};
    window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
    window_class.lpszClassName = kWindowClassName;
    window_class.style = CS_HREDRAW | CS_VREDRAW;
    window_class.cbClsExtra = 0;
    window_class.cbWndExtra = 0;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.hIcon =
        LoadIcon(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
    window_class.hbrBackground = 0;
    window_class.lpszMenuName = nullptr;
    window_class.lpfnWndProc = Win32Window::WndProc;
    RegisterClass(&window_class);
    class_registered_ = true;
  }
  return kWindowClassName;
}

void WindowClassRegistrar::UnregisterWindowClass() {
  UnregisterClass(kWindowClassName, nullptr);
  class_registered_ = false;
}

Win32Window::Win32Window() {
  ++g_active_window_count;
}

Win32Window::~Win32Window() {
  --g_active_window_count;
  Destroy();
}

bool Win32Window::Create(const std::wstring& title,
                         const Point& origin,
                         const Size& size) {
  Destroy();
  persist_window_state_ = false;
  start_maximized_ = false;
  has_shown_ = false;
  in_size_move_ = false;
  has_tracked_state_ = false;
  has_last_saved_state_ = false;

  const wchar_t* window_class =
      WindowClassRegistrar::GetInstance()->GetWindowClass();

  const POINT target_point = {static_cast<LONG>(origin.x),
                              static_cast<LONG>(origin.y)};
  HMONITOR monitor = MonitorFromPoint(target_point, MONITOR_DEFAULTTONEAREST);
  UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  double scale_factor = dpi / 96.0;

  HWND window = CreateWindow(
      window_class, title.c_str(), WS_OVERLAPPEDWINDOW,
      Scale(origin.x, scale_factor), Scale(origin.y, scale_factor),
      Scale(size.width, scale_factor), Scale(size.height, scale_factor),
      nullptr, nullptr, GetModuleHandle(nullptr), this);

  if (!window) {
    return false;
  }

  UpdateTheme(window);

  return OnCreate();
}

bool Win32Window::CreateWithRestoredState(const std::wstring& title,
                                          const Point& default_origin,
                                          const Size& default_size) {
  Destroy();
  persist_window_state_ = true;
  has_shown_ = false;
  in_size_move_ = false;
  has_tracked_state_ = false;
  has_last_saved_state_ = false;

  const std::vector<MonitorWorkArea> monitors = EnumerateWindowsMonitors();
  WindowState saved;
  WindowState initial;
  if (LoadWindowsWindowState(&saved)) {
    has_last_saved_state_ = true;
    last_saved_state_ = saved;
    initial = ResolveWindowStateForMonitors(
        saved, monitors, kMinWindowWidth, kMinWindowHeight);
  } else {
    initial = BuildDefaultWindowStateForMonitors(
        static_cast<int>(default_origin.x), static_cast<int>(default_origin.y),
        static_cast<int>(default_size.width),
        static_cast<int>(default_size.height), kMinWindowWidth,
        kMinWindowHeight, monitors);
  }

  start_maximized_ = initial.maximized;
  tracked_state_ = initial;
  has_tracked_state_ = true;

  const wchar_t* window_class =
      WindowClassRegistrar::GetInstance()->GetWindowClass();
  HWND window = CreateWindow(
      window_class, title.c_str(), WS_OVERLAPPEDWINDOW, initial.x, initial.y,
      initial.width, initial.height, nullptr, nullptr, GetModuleHandle(nullptr),
      this);

  if (!window) {
    return false;
  }

  // Re-apply physical bounds before creating the Flutter surface in case
  // cross-DPI creation adjusted the initial frame to the primary monitor's DPI.
  RECT actual{};
  if (GetWindowRect(window, &actual)) {
    const int actual_w = static_cast<int>(actual.right - actual.left);
    const int actual_h = static_cast<int>(actual.bottom - actual.top);
    if (actual.left != initial.x || actual.top != initial.y ||
        actual_w != initial.width || actual_h != initial.height) {
      SetWindowPos(window, nullptr, initial.x, initial.y, initial.width,
                   initial.height, SWP_NOZORDER | SWP_NOACTIVATE);
    }
  }

  UpdateTheme(window);

  return OnCreate();
}

bool Win32Window::Show() {
  const int show_cmd = start_maximized_ ? SW_SHOWMAXIMIZED : SW_SHOWNORMAL;
  const bool shown = ShowWindow(window_handle_, show_cmd) != FALSE;
  has_shown_ = true;
  return shown;
}

void Win32Window::FlushWindowState() {
  if (!persist_window_state_ || !has_shown_ || window_handle_ == nullptr) {
    return;
  }
  CancelWindowStateSaveTimer(window_handle_);
  if (IsIconic(window_handle_)) {
    WINDOWPLACEMENT wp{};
    wp.length = sizeof(wp);
    if (GetWindowPlacement(window_handle_, &wp)) {
      tracked_state_.maximized = (wp.flags & WPF_RESTORETOMAXIMIZED) != 0;
    }
  } else if (IsZoomed(window_handle_)) {
    tracked_state_.maximized = true;
    has_tracked_state_ = true;
  } else {
    CaptureNormalWindowState(window_handle_);
  }
  CommitWindowStateToDisk();
}

void Win32Window::ActivateExisting(const std::wstring& title) {
  HWND window = FindWindow(kWindowClassName, title.c_str());
  if (window != nullptr) {
    ShowWindow(window, IsIconic(window) ? SW_RESTORE : SW_SHOW);
    SetForegroundWindow(window);
  }
}

// static
LRESULT CALLBACK Win32Window::WndProc(HWND const window,
                                      UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto window_struct = reinterpret_cast<CREATESTRUCT*>(lparam);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(window_struct->lpCreateParams));

    auto that = static_cast<Win32Window*>(window_struct->lpCreateParams);
    EnableFullDpiSupportIfAvailable(window);
    that->window_handle_ = window;
  } else if (Win32Window* that = GetThisFromHandle(window)) {
    return that->MessageHandler(window, message, wparam, lparam);
  }

  return DefWindowProc(window, message, wparam, lparam);
}

LRESULT
Win32Window::MessageHandler(HWND hwnd,
                            UINT const message,
                            WPARAM const wparam,
                            LPARAM const lparam) noexcept {
  switch (message) {
    case WM_DESTROY:
      CancelWindowStateSaveTimer(hwnd);
      if (persist_window_state_ && has_shown_) {
        CommitWindowStateToDisk();
      }
      window_handle_ = nullptr;
      Destroy();
      if (quit_on_close_) {
        PostQuitMessage(0);
      }
      return 0;

    case WM_ENTERSIZEMOVE:
      in_size_move_ = true;
      break;

    case WM_EXITSIZEMOVE:
      in_size_move_ = false;
      if (persist_window_state_ && has_shown_) {
        CancelWindowStateSaveTimer(hwnd);
        if (IsZoomed(hwnd)) {
          // Preserve pre-drag normal bounds when Aero Snap maximizes on drop.
          tracked_state_.maximized = true;
          has_tracked_state_ = true;
        } else if (!IsIconic(hwnd)) {
          CaptureNormalWindowState(hwnd);
        }
        CommitWindowStateToDisk();
      }
      break;

    case WM_MOVE:
      if (persist_window_state_ && has_shown_ && !in_size_move_ &&
          !IsIconic(hwnd) && !IsZoomed(hwnd)) {
        if (CaptureNormalWindowState(hwnd)) {
          ScheduleWindowStateSave(hwnd);
        }
      }
      break;

    case WM_DPICHANGED: {
      auto newRectSize = reinterpret_cast<RECT*>(lparam);
      LONG newWidth = newRectSize->right - newRectSize->left;
      LONG newHeight = newRectSize->bottom - newRectSize->top;

      SetWindowPos(hwnd, nullptr, newRectSize->left, newRectSize->top, newWidth,
                   newHeight, SWP_NOZORDER | SWP_NOACTIVATE);

      if (persist_window_state_ && has_shown_ && !in_size_move_ &&
          !IsIconic(hwnd) && !IsZoomed(hwnd)) {
        if (CaptureNormalWindowState(hwnd)) {
          ScheduleWindowStateSave(hwnd);
        }
      }

      return 0;
    }
    case WM_GETMINMAXINFO: {
      // Use the window's current monitor so the limit follows per-monitor
      // DPI when the window is dragged between screens.
      HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
      double scale_factor = FlutterDesktopGetDpiForMonitor(monitor) / 96.0;
      auto info = reinterpret_cast<MINMAXINFO*>(lparam);
      info->ptMinTrackSize.x = Scale(kMinWindowWidth, scale_factor);
      info->ptMinTrackSize.y = Scale(kMinWindowHeight, scale_factor);
      return 0;
    }
    case WM_SIZE: {
      RECT rect = GetClientArea();
      if (child_content_ != nullptr) {
        // Size and position the child window.
        MoveWindow(child_content_, rect.left, rect.top, rect.right - rect.left,
                   rect.bottom - rect.top, TRUE);
      }
      if (persist_window_state_ && has_shown_) {
        if (wparam == SIZE_MINIMIZED) {
          WINDOWPLACEMENT wp{};
          wp.length = sizeof(wp);
          if (GetWindowPlacement(hwnd, &wp)) {
            tracked_state_.maximized =
                (wp.flags & WPF_RESTORETOMAXIMIZED) != 0;
          }
        } else if (wparam == SIZE_MAXIMIZED) {
          tracked_state_.maximized = true;
          has_tracked_state_ = true;
          ScheduleWindowStateSave(hwnd);
        } else if (wparam == SIZE_RESTORED && !in_size_move_ &&
                   !IsIconic(hwnd) && !IsZoomed(hwnd)) {
          if (CaptureNormalWindowState(hwnd)) {
            ScheduleWindowStateSave(hwnd);
          }
        }
      }
      return 0;
    }

    case WM_TIMER:
      if (wparam == kSaveWindowStateTimerId) {
        CancelWindowStateSaveTimer(hwnd);
        CommitWindowStateToDisk();
        return 0;
      }
      break;

    case WM_ACTIVATE:
      if (child_content_ != nullptr) {
        SetFocus(child_content_);
      }
      return 0;

    case WM_DWMCOLORIZATIONCOLORCHANGED:
      UpdateTheme(hwnd);
      return 0;
  }

  return DefWindowProc(window_handle_, message, wparam, lparam);
}

void Win32Window::Destroy() {
  OnDestroy();

  if (window_handle_) {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }
  if (g_active_window_count == 0) {
    WindowClassRegistrar::GetInstance()->UnregisterWindowClass();
  }
}

Win32Window* Win32Window::GetThisFromHandle(HWND const window) noexcept {
  return reinterpret_cast<Win32Window*>(
      GetWindowLongPtr(window, GWLP_USERDATA));
}

void Win32Window::SetChildContent(HWND content) {
  child_content_ = content;
  SetParent(content, window_handle_);
  RECT frame = GetClientArea();

  MoveWindow(content, frame.left, frame.top, frame.right - frame.left,
             frame.bottom - frame.top, true);

  SetFocus(child_content_);
}

RECT Win32Window::GetClientArea() {
  RECT frame;
  GetClientRect(window_handle_, &frame);
  return frame;
}

HWND Win32Window::GetHandle() {
  return window_handle_;
}

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

bool Win32Window::OnCreate() {
  // No-op; provided for subclasses.
  return true;
}

void Win32Window::OnDestroy() {
  // No-op; provided for subclasses.
}

void Win32Window::UpdateTheme(HWND const window) {
  DWORD light_mode;
  DWORD light_mode_size = sizeof(light_mode);
  LSTATUS result = RegGetValue(HKEY_CURRENT_USER, kGetPreferredBrightnessRegKey,
                               kGetPreferredBrightnessRegValue,
                               RRF_RT_REG_DWORD, nullptr, &light_mode,
                               &light_mode_size);

  if (result == ERROR_SUCCESS) {
    BOOL enable_dark_mode = light_mode == 0;
    DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE,
                          &enable_dark_mode, sizeof(enable_dark_mode));
  }
}

bool Win32Window::CaptureNormalWindowState(HWND hwnd) {
  RECT rect{};
  if (!GetWindowRect(hwnd, &rect)) {
    return false;
  }
  const int width = static_cast<int>(rect.right - rect.left);
  const int height = static_cast<int>(rect.bottom - rect.top);
  if (width <= 0 || height <= 0) {
    return false;
  }
  HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
  const UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);

  tracked_state_.has_position = true;
  tracked_state_.x = static_cast<int>(rect.left);
  tracked_state_.y = static_cast<int>(rect.top);
  tracked_state_.width = width;
  tracked_state_.height = height;
  tracked_state_.maximized = false;
  tracked_state_.dpi = dpi > 0 ? static_cast<int>(dpi) : 96;
  has_tracked_state_ = true;
  return true;
}

void Win32Window::ScheduleWindowStateSave(HWND hwnd) {
  if (!persist_window_state_ || hwnd == nullptr) {
    return;
  }
  SetTimer(hwnd, kSaveWindowStateTimerId, kSaveWindowStateDelayMs, nullptr);
}

void Win32Window::CancelWindowStateSaveTimer(HWND hwnd) {
  if (hwnd != nullptr) {
    KillTimer(hwnd, kSaveWindowStateTimerId);
  }
}

void Win32Window::CommitWindowStateToDisk() {
  if (!persist_window_state_ || !has_tracked_state_) {
    return;
  }
  if (has_last_saved_state_ &&
      WindowStatesEqual(tracked_state_, last_saved_state_)) {
    return;
  }
  SaveWindowsWindowState(tracked_state_);
  last_saved_state_ = tracked_state_;
  has_last_saved_state_ = true;
}
