#include "window_state_gtk.h"

#include <gdk/gdk.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include <string>
#include <vector>

#include "window_state.h"

namespace {

// Short stabilization delay before promoting a configure-event's geometry into
// committed normal bounds. When a user maximizes or fullscreens a window, some
// X11 window managers deliver the enlarged configure-event a few milliseconds
// before window-state-event; waiting briefly lets window-state-event cancel
// the pending promotion so maximized dimensions never overwrite normal bounds.
constexpr guint kCommitNormalDelayMs = 150;
// Startup grace window when launching straight into maximized state so initial
// pre-maximize configure events do not clear the restored maximized flag.
constexpr guint kStartupMaximizeGraceMs = 400;

struct LinuxWindowStateTracker {
  GtkWindow* window = nullptr;
  std::string file_path;
  bool is_x11 = false;
  int min_width = 0;
  int min_height = 0;

  WindowState committed;
  bool has_pending_normal = false;
  WindowState pending_normal;
  bool dirty = false;

  bool is_maximized = false;
  bool is_fullscreen = false;
  bool is_iconified = false;
  bool awaiting_initial_maximize = false;

  guint commit_timer_id = 0;
  guint startup_grace_timer_id = 0;
};

std::string BuildWindowStatePath() {
  const gchar* data_dir = g_get_user_data_dir();
  if (data_dir == nullptr || data_dir[0] == '\0') {
    return std::string();
  }
  g_autofree gchar* path =
      g_build_filename(data_dir, APPLICATION_ID, "window_state.json", nullptr);
  return path != nullptr ? std::string(path) : std::string();
}

bool LoadWindowStateFromDisk(const std::string& path, WindowState* out) {
  if (path.empty() || out == nullptr) {
    return false;
  }
  g_autofree gchar* contents = nullptr;
  gsize length = 0;
  if (!g_file_get_contents(path.c_str(), &contents, &length, nullptr)) {
    return false;
  }
  if (contents == nullptr || length == 0 || length > 65536) {
    return false;
  }
  return ParseWindowStateJson(std::string(contents, length), out);
}

void WriteWindowStateToDisk(const std::string& path, const WindowState& state) {
  if (path.empty() || state.width <= 0 || state.height <= 0) {
    return;
  }
  g_autofree gchar* dir = g_path_get_dirname(path.c_str());
  if (dir != nullptr) {
    g_mkdir_with_parents(dir, 0700);
  }
  const std::string payload = SerializeWindowStateJson(state);
  // g_file_set_contents writes to a sibling temporary file and atomically
  // renames it over the destination.
  g_file_set_contents(path.c_str(), payload.c_str(),
                      static_cast<gssize>(payload.size()), nullptr);
}

std::vector<MonitorWorkArea> CollectMonitors(GtkWindow* window) {
  std::vector<MonitorWorkArea> result;
  GdkDisplay* display = gtk_widget_get_display(GTK_WIDGET(window));
  if (display == nullptr) {
    return result;
  }
  const int count = gdk_display_get_n_monitors(display);
  for (int i = 0; i < count; ++i) {
    GdkMonitor* monitor = gdk_display_get_monitor(display, i);
    if (monitor == nullptr) {
      continue;
    }
    GdkRectangle area = {};
    gdk_monitor_get_workarea(monitor, &area);
    if (area.width <= 0 || area.height <= 0) {
      gdk_monitor_get_geometry(monitor, &area);
    }
    if (area.width <= 0 || area.height <= 0) {
      continue;
    }
    MonitorWorkArea entry;
    entry.work_area = WindowRect{area.x, area.y, area.width, area.height};
    entry.is_primary = gdk_monitor_is_primary(monitor) != FALSE;
    result.push_back(entry);
  }
  return result;
}

bool IsX11Display(GtkWindow* window) {
#ifdef GDK_WINDOWING_X11
  GdkDisplay* display = gtk_widget_get_display(GTK_WIDGET(window));
  return display != nullptr && GDK_IS_X11_DISPLAY(display);
#else
  (void)window;
  return false;
#endif
}

bool StatesEqual(const WindowState& a, const WindowState& b) {
  return a.has_position == b.has_position && a.x == b.x && a.y == b.y &&
         a.width == b.width && a.height == b.height &&
         a.maximized == b.maximized;
}

bool IsWindowInSpecialState(GtkWindow* window,
                            const LinuxWindowStateTracker* tracker) {
  if (tracker->is_maximized || tracker->is_fullscreen ||
      tracker->is_iconified) {
    return true;
  }
  if (gtk_window_is_maximized(window)) {
    return true;
  }
  GdkWindow* gdk_window = gtk_widget_get_window(GTK_WIDGET(window));
  if (gdk_window != nullptr) {
    const GdkWindowState state = gdk_window_get_state(gdk_window);
    if ((state & (GDK_WINDOW_STATE_MAXIMIZED | GDK_WINDOW_STATE_FULLSCREEN |
                  GDK_WINDOW_STATE_ICONIFIED)) != 0) {
      return true;
    }
  }
  return false;
}

bool ReadCurrentNormalGeometry(GtkWindow* window,
                               const LinuxWindowStateTracker* tracker,
                               WindowState* out) {
  if (!gtk_widget_get_mapped(GTK_WIDGET(window))) {
    return false;
  }
  // Use gtk_window_get_size/position rather than GdkEventConfigure dimensions:
  // with GtkHeaderBar CSD shadows, GdkEventConfigure includes invisible shadow
  // margins whereas gtk_window_get_size matches gtk_window_set_default_size.
  gint width = 0;
  gint height = 0;
  gtk_window_get_size(window, &width, &height);
  if (width < tracker->min_width || height < tracker->min_height) {
    return false;
  }
  WindowState sample = tracker->committed;
  sample.width = width;
  sample.height = height;
  sample.maximized = false;
  if (tracker->is_x11) {
    gint x = 0;
    gint y = 0;
    gtk_window_get_position(window, &x, &y);
    sample.has_position = true;
    sample.x = x;
    sample.y = y;
  } else {
    sample.has_position = false;
    sample.x = 0;
    sample.y = 0;
  }
  *out = sample;
  return true;
}

void CancelCommitTimer(LinuxWindowStateTracker* tracker) {
  if (tracker->commit_timer_id != 0) {
    g_source_remove(tracker->commit_timer_id);
    tracker->commit_timer_id = 0;
  }
  tracker->has_pending_normal = false;
}

void FlushToDisk(LinuxWindowStateTracker* tracker) {
  if (!tracker->dirty) {
    return;
  }
  WriteWindowStateToDisk(tracker->file_path, tracker->committed);
  tracker->dirty = false;
}

gboolean OnCommitTimerElapsed(gpointer user_data) {
  auto* tracker = static_cast<LinuxWindowStateTracker*>(user_data);
  tracker->commit_timer_id = 0;
  if (tracker->window == nullptr) {
    return G_SOURCE_REMOVE;
  }
  if (!tracker->has_pending_normal) {
    FlushToDisk(tracker);
    return G_SOURCE_REMOVE;
  }
  tracker->has_pending_normal = false;
  if (tracker->awaiting_initial_maximize ||
      IsWindowInSpecialState(tracker->window, tracker)) {
    return G_SOURCE_REMOVE;
  }
  if (!StatesEqual(tracker->committed, tracker->pending_normal)) {
    tracker->committed = tracker->pending_normal;
    tracker->dirty = true;
  }
  FlushToDisk(tracker);
  return G_SOURCE_REMOVE;
}

gboolean OnStartupMaximizeGraceElapsed(gpointer user_data) {
  auto* tracker = static_cast<LinuxWindowStateTracker*>(user_data);
  tracker->startup_grace_timer_id = 0;
  tracker->awaiting_initial_maximize = false;
  return G_SOURCE_REMOVE;
}

void ScheduleCommit(LinuxWindowStateTracker* tracker) {
  if (tracker->commit_timer_id != 0) {
    g_source_remove(tracker->commit_timer_id);
  }
  tracker->commit_timer_id =
      g_timeout_add(kCommitNormalDelayMs, OnCommitTimerElapsed, tracker);
}

gboolean OnConfigureEvent(GtkWidget* widget,
                          GdkEventConfigure* event,
                          gpointer user_data) {
  (void)event;
  auto* tracker = static_cast<LinuxWindowStateTracker*>(user_data);
  if (tracker->awaiting_initial_maximize) {
    return FALSE;
  }
  GtkWindow* window = GTK_WINDOW(widget);
  if (IsWindowInSpecialState(window, tracker)) {
    return FALSE;
  }
  WindowState sample;
  if (!ReadCurrentNormalGeometry(window, tracker, &sample)) {
    return FALSE;
  }
  tracker->pending_normal = sample;
  tracker->has_pending_normal = true;
  ScheduleCommit(tracker);
  return FALSE;
}

gboolean OnWindowStateEvent(GtkWidget* widget,
                            GdkEventWindowState* event,
                            gpointer user_data) {
  auto* tracker = static_cast<LinuxWindowStateTracker*>(user_data);
  const GdkWindowState state = event->new_window_state;
  const bool maximized = (state & GDK_WINDOW_STATE_MAXIMIZED) != 0;
  const bool fullscreen = (state & GDK_WINDOW_STATE_FULLSCREEN) != 0;
  const bool iconified = (state & GDK_WINDOW_STATE_ICONIFIED) != 0;

  tracker->is_maximized = maximized;
  tracker->is_fullscreen = fullscreen;
  tracker->is_iconified = iconified;

  if (maximized) {
    tracker->awaiting_initial_maximize = false;
    if (tracker->startup_grace_timer_id != 0) {
      g_source_remove(tracker->startup_grace_timer_id);
      tracker->startup_grace_timer_id = 0;
    }
  }

  if (maximized || fullscreen || iconified) {
    // Discard any unpromoted normal geometry captured just before maximizing or
    // entering fullscreen so the expanded dimensions never overwrite normal
    // bounds.
    CancelCommitTimer(tracker);
  }

  if (!iconified && !fullscreen) {
    if (tracker->awaiting_initial_maximize && !maximized) {
      // Still waiting for the WM to apply the startup gtk_window_maximize call.
      return FALSE;
    }
    if (tracker->committed.maximized != maximized) {
      tracker->committed.maximized = maximized;
      tracker->dirty = true;
      ScheduleCommit(tracker);
    }
    if (!maximized) {
      WindowState sample;
      if (ReadCurrentNormalGeometry(GTK_WINDOW(widget), tracker, &sample)) {
        tracker->pending_normal = sample;
        tracker->has_pending_normal = true;
        ScheduleCommit(tracker);
      }
    }
  }
  return FALSE;
}

gboolean OnDeleteEvent(GtkWidget* widget,
                       GdkEvent* event,
                       gpointer user_data) {
  (void)event;
  auto* tracker = static_cast<LinuxWindowStateTracker*>(user_data);
  GtkWindow* window = GTK_WINDOW(widget);
  if (!tracker->awaiting_initial_maximize &&
      !IsWindowInSpecialState(window, tracker)) {
    WindowState sample;
    if (ReadCurrentNormalGeometry(window, tracker, &sample)) {
      if (!StatesEqual(tracker->committed, sample)) {
        tracker->committed = sample;
        tracker->dirty = true;
      }
    }
  }
  CancelCommitTimer(tracker);
  FlushToDisk(tracker);
  // Always return FALSE so Flutter's exit-guard / close handler still runs.
  return FALSE;
}

void OnDestroy(GtkWidget* widget, gpointer user_data) {
  (void)widget;
  auto* tracker = static_cast<LinuxWindowStateTracker*>(user_data);
  CancelCommitTimer(tracker);
  if (tracker->startup_grace_timer_id != 0) {
    g_source_remove(tracker->startup_grace_timer_id);
    tracker->startup_grace_timer_id = 0;
  }
  FlushToDisk(tracker);
  tracker->window = nullptr;
}

void FreeTracker(gpointer user_data) {
  auto* tracker = static_cast<LinuxWindowStateTracker*>(user_data);
  CancelCommitTimer(tracker);
  if (tracker->startup_grace_timer_id != 0) {
    g_source_remove(tracker->startup_grace_timer_id);
    tracker->startup_grace_timer_id = 0;
  }
  delete tracker;
}

}  // namespace

void RestoreAndTrackLinuxWindowState(GtkWindow* window,
                                     int default_width,
                                     int default_height,
                                     int min_width,
                                     int min_height) {
  auto* tracker = new LinuxWindowStateTracker();
  tracker->window = window;
  tracker->file_path = BuildWindowStatePath();
  tracker->is_x11 = IsX11Display(window);
  tracker->min_width = min_width;
  tracker->min_height = min_height;

  WindowState saved;
  const bool loaded = LoadWindowStateFromDisk(tracker->file_path, &saved);
  if (loaded) {
    const std::vector<MonitorWorkArea> monitors = CollectMonitors(window);
    const WindowState resolved = ResolveWindowStateForMonitors(
        saved, monitors, min_width, min_height, tracker->is_x11);
    tracker->committed = resolved;
    gtk_window_set_default_size(window, resolved.width, resolved.height);
    if (tracker->is_x11 && resolved.has_position) {
      // Position before maximize so multi-monitor setups maximize onto the
      // previously used monitor as well as remembering the restore origin.
      gtk_window_move(window, resolved.x, resolved.y);
    }
    if (resolved.maximized) {
      tracker->is_maximized = true;
      tracker->awaiting_initial_maximize = true;
      tracker->startup_grace_timer_id = g_timeout_add(
          kStartupMaximizeGraceMs, OnStartupMaximizeGraceElapsed, tracker);
      gtk_window_maximize(window);
    }
  } else {
    tracker->committed.width = default_width;
    tracker->committed.height = default_height;
    tracker->committed.maximized = false;
    gtk_window_set_default_size(window, default_width, default_height);
  }

  g_object_set_data_full(G_OBJECT(window), "jotsy-window-state-tracker",
                         tracker, FreeTracker);
  g_signal_connect(window, "configure-event", G_CALLBACK(OnConfigureEvent),
                   tracker);
  g_signal_connect(window, "window-state-event",
                   G_CALLBACK(OnWindowStateEvent), tracker);
  g_signal_connect(window, "delete-event", G_CALLBACK(OnDeleteEvent), tracker);
  g_signal_connect(window, "destroy", G_CALLBACK(OnDestroy), tracker);
}
