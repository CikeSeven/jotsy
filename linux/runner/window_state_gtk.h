#ifndef RUNNER_WINDOW_STATE_GTK_H_
#define RUNNER_WINDOW_STATE_GTK_H_

#include <gtk/gtk.h>

// Restores the saved window size, X11 position, and maximized state (falling
// back to default_width x default_height) and attaches lifecycle handlers to
// persist future normal-state bounds and maximized transitions cleanly.
// Must be called after creating |window| (and setting its geometry hints) and
// before calling gtk_widget_show().
void RestoreAndTrackLinuxWindowState(GtkWindow* window,
                                     int default_width,
                                     int default_height,
                                     int min_width,
                                     int min_height);

#endif  // RUNNER_WINDOW_STATE_GTK_H_
