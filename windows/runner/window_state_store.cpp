#include "window_state_store.h"

#include <windows.h>
#include <flutter_windows.h>
#include <shlobj.h>

#include <string>
#include <vector>

namespace {

constexpr wchar_t kAppSupportSubdir[] = L"\\CikeSeven\\Jotsy";
constexpr wchar_t kWindowStateFileName[] = L"window_state.json";
constexpr DWORD kMaxStateFileBytes = 65536;

std::wstring GetAppSupportDirectory() {
  PWSTR roaming_dir = nullptr;
  const HRESULT hr = SHGetKnownFolderPath(FOLDERID_RoamingAppData,
                                          KF_FLAG_CREATE, nullptr,
                                          &roaming_dir);
  if (FAILED(hr) || roaming_dir == nullptr) {
    if (roaming_dir != nullptr) {
      CoTaskMemFree(roaming_dir);
    }
    return std::wstring();
  }
  std::wstring dir(roaming_dir);
  CoTaskMemFree(roaming_dir);
  dir += kAppSupportSubdir;
  return dir;
}

BOOL CALLBACK CollectMonitorProc(HMONITOR monitor,
                                 HDC hdc,
                                 LPRECT clip_rect,
                                 LPARAM user_data) {
  auto* monitors = reinterpret_cast<std::vector<MonitorWorkArea>*>(user_data);
  if (monitors == nullptr) {
    return FALSE;
  }
  MONITORINFO info{};
  info.cbSize = sizeof(info);
  if (!GetMonitorInfoW(monitor, &info)) {
    return TRUE;
  }
  const int width = static_cast<int>(info.rcWork.right - info.rcWork.left);
  const int height = static_cast<int>(info.rcWork.bottom - info.rcWork.top);
  if (width <= 0 || height <= 0) {
    return TRUE;
  }
  const UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  MonitorWorkArea entry;
  entry.work_area = WindowRect{
      static_cast<int>(info.rcWork.left),
      static_cast<int>(info.rcWork.top),
      width,
      height,
  };
  entry.dpi = dpi > 0 ? static_cast<int>(dpi) : 96;
  entry.is_primary = (info.dwFlags & MONITORINFOF_PRIMARY) != 0;
  monitors->push_back(entry);
  return TRUE;
}

}  // namespace

bool LoadWindowsWindowState(WindowState* out) {
  if (out == nullptr) {
    return false;
  }
  const std::wstring dir = GetAppSupportDirectory();
  if (dir.empty()) {
    return false;
  }
  const std::wstring path = dir + L"\\" + kWindowStateFileName;
  HANDLE file = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ,
                            nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL,
                            nullptr);
  if (file == INVALID_HANDLE_VALUE) {
    return false;
  }

  LARGE_INTEGER file_size{};
  if (!GetFileSizeEx(file, &file_size) || file_size.QuadPart <= 0 ||
      file_size.QuadPart > kMaxStateFileBytes) {
    CloseHandle(file);
    return false;
  }

  const DWORD expected_bytes = static_cast<DWORD>(file_size.QuadPart);
  std::string buffer(expected_bytes, '\0');
  DWORD total_read = 0;
  while (total_read < expected_bytes) {
    DWORD chunk_read = 0;
    if (!ReadFile(file, &buffer[total_read], expected_bytes - total_read,
                  &chunk_read, nullptr) ||
        chunk_read == 0) {
      CloseHandle(file);
      return false;
    }
    total_read += chunk_read;
  }
  CloseHandle(file);

  return ParseWindowStateJson(buffer, out);
}

void SaveWindowsWindowState(const WindowState& state) {
  if (state.width <= 0 || state.height <= 0) {
    return;
  }
  const std::wstring dir = GetAppSupportDirectory();
  if (dir.empty()) {
    return;
  }
  const int mkdir_result = SHCreateDirectoryExW(nullptr, dir.c_str(), nullptr);
  if (mkdir_result != ERROR_SUCCESS &&
      mkdir_result != ERROR_ALREADY_EXISTS &&
      mkdir_result != ERROR_FILE_EXISTS) {
    return;
  }

  const std::wstring final_path = dir + L"\\" + kWindowStateFileName;
  const std::wstring temp_path = final_path + L".tmp";
  const std::string payload = SerializeWindowStateJson(state);

  HANDLE file = CreateFileW(temp_path.c_str(), GENERIC_WRITE, 0, nullptr,
                            CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (file == INVALID_HANDLE_VALUE) {
    return;
  }

  const DWORD total_bytes = static_cast<DWORD>(payload.size());
  DWORD total_written = 0;
  bool ok = true;
  while (total_written < total_bytes) {
    DWORD chunk_written = 0;
    if (!WriteFile(file, payload.data() + total_written,
                   total_bytes - total_written, &chunk_written, nullptr) ||
        chunk_written == 0) {
      ok = false;
      break;
    }
    total_written += chunk_written;
  }
  if (ok) {
    FlushFileBuffers(file);
  }
  CloseHandle(file);

  if (!ok) {
    DeleteFileW(temp_path.c_str());
    return;
  }
  if (!MoveFileExW(temp_path.c_str(), final_path.c_str(),
                   MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)) {
    DeleteFileW(temp_path.c_str());
  }
}

std::vector<MonitorWorkArea> EnumerateWindowsMonitors() {
  std::vector<MonitorWorkArea> monitors;
  EnumDisplayMonitors(nullptr, nullptr, CollectMonitorProc,
                      reinterpret_cast<LPARAM>(&monitors));
  return monitors;
}
