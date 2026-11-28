#ifndef RUNNER_WINDOW_STATE_H_
#define RUNNER_WINDOW_STATE_H_

#include <string>
#include <vector>

// Pure C++17 persistence format, DPI scaling, and multi-monitor visibility
// clamping for the Windows desktop window. Kept free of <windows.h> and
// exceptions (_HAS_EXCEPTIONS=0) so every geometry/JSON edge case can be
// compiled and unit-tested independently.

struct WindowRect {
  int x = 0;
  int y = 0;
  int width = 0;
  int height = 0;
};

struct MonitorWorkArea {
  WindowRect work_area;
  int dpi = 96;
  bool is_primary = false;
};

struct WindowState {
  bool has_position = false;
  int x = 0;
  int y = 0;
  int width = 0;
  int height = 0;
  bool maximized = false;
  // Monitor DPI at the time |width| and |height| were recorded (96 = 100%).
  // When restored on a monitor with a different DPI, dimensions scale by
  // target_dpi / dpi so logical window size stays consistent.
  int dpi = 96;
};

// Parses a window_state.json payload into |out|. Returns false on malformed
// JSON, unsupported versions, or missing/out-of-range dimensions.
bool ParseWindowStateJson(const std::string& json, WindowState* out);

// Serializes |state| to a compact JSON object.
std::string SerializeWindowStateJson(const WindowState& state);

// Resolves |saved| physical bounds against the current monitor work areas and
// per-monitor DPIs, ensuring minimum logical size and an accessible title bar.
WindowState ResolveWindowStateForMonitors(
    const WindowState& saved,
    const std::vector<MonitorWorkArea>& monitors,
    int min_logical_width,
    int min_logical_height);

// Computes initial physical bounds for a first launch (no saved state yet),
// scaling default logical bounds to the primary monitor's DPI and clamping
// inside its work area so smaller displays do not clip the bottom edge.
WindowState BuildDefaultWindowStateForMonitors(
    int default_logical_x,
    int default_logical_y,
    int default_logical_width,
    int default_logical_height,
    int min_logical_width,
    int min_logical_height,
    const std::vector<MonitorWorkArea>& monitors);

#endif  // RUNNER_WINDOW_STATE_H_
