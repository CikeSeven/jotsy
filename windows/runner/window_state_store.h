#ifndef RUNNER_WINDOW_STATE_STORE_H_
#define RUNNER_WINDOW_STATE_STORE_H_

#include <vector>

#include "window_state.h"

// Win32 storage and monitor enumeration helpers for desktop window state.
// State is stored in %APPDATA%\CikeSeven\Jotsy\window_state.json, matching
// path_provider's default application support directory so it stays per-machine
// and never migrates or syncs with diary content.

// Loads saved window state from disk. Returns false if no file exists or if
// the payload cannot be parsed cleanly.
bool LoadWindowsWindowState(WindowState* out);

// Atomically persists |state| to %APPDATA%\CikeSeven\Jotsy\window_state.json.
void SaveWindowsWindowState(const WindowState& state);

// Enumerates all active display monitors, their work areas (excluding taskbar),
// and per-monitor DPIs.
std::vector<MonitorWorkArea> EnumerateWindowsMonitors();

#endif  // RUNNER_WINDOW_STATE_STORE_H_
