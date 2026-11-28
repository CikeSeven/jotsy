#ifndef RUNNER_WINDOW_STATE_H_
#define RUNNER_WINDOW_STATE_H_

#include <string>
#include <vector>

// Pure C++14 persistence format and multi-monitor visibility clamping for the
// Linux desktop window. Kept free of GTK/GDK headers so the parsing,
// serialization, and monitor-clamping edge cases can be unit-tested directly.

struct WindowRect {
  int x = 0;
  int y = 0;
  int width = 0;
  int height = 0;
};

struct MonitorWorkArea {
  WindowRect work_area;
  bool is_primary = false;
};

struct WindowState {
  // Position is only meaningful on X11; Wayland compositors do not expose
  // global window coordinates, so Wayland leaves has_position as false.
  bool has_position = false;
  int x = 0;
  int y = 0;
  int width = 0;
  int height = 0;
  bool maximized = false;
};

// Parses a window_state.json payload into |out|. Returns false on malformed
// JSON, unsupported versions, or missing/out-of-range dimensions so the caller
// cleanly falls back to default window bounds.
bool ParseWindowStateJson(const std::string& json, WindowState* out);

// Serializes |state| to a compact JSON object. Omits x/y when has_position is
// false so Wayland sessions never overwrite saved coordinates with (0, 0).
std::string SerializeWindowStateJson(const WindowState& state);

// Clamps |saved| to the current monitor work areas and minimum logical size.
// Keeps the saved position untouched whenever the window title bar has enough
// visible area on at least one monitor; otherwise centers on the primary
// monitor (when completely off-screen, e.g. an unplugged external display) or
// clamps inside the target monitor's work area.
WindowState ResolveWindowStateForMonitors(
    const WindowState& saved,
    const std::vector<MonitorWorkArea>& monitors,
    int min_width,
    int min_height,
    bool allow_position);

#endif  // RUNNER_WINDOW_STATE_H_
