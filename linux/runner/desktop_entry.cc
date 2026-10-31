#include "desktop_entry.h"

#include <glib.h>
#include <glib/gstdio.h>
#include <string.h>

// APPLICATION_ID is injected by the runner CMake target.

// Whether a packaged installation (system package, Flatpak or Snap) provides
// the desktop entry. In that case it owns the icon association and this
// process must not shadow it with a user-level entry.
static gboolean has_system_desktop_entry() {
  const gchar* const* data_dirs = g_get_system_data_dirs();
  for (gsize i = 0; data_dirs[i] != nullptr; i++) {
    g_autofree gchar* path = g_build_filename(
        data_dirs[i], "applications", APPLICATION_ID ".desktop", nullptr);
    if (g_file_test(path, G_FILE_TEST_IS_REGULAR)) {
      return TRUE;
    }
  }
  return FALSE;
}

static gboolean is_generated_desktop_entry(const gchar* path) {
  g_autoptr(GKeyFile) key_file = g_key_file_new();
  if (!g_key_file_load_from_file(key_file, path, G_KEY_FILE_NONE, nullptr)) {
    return FALSE;
  }
  g_autofree gchar* generated = g_key_file_get_string(
      key_file, "Desktop Entry", "X-Bugaoshan-Generated", nullptr);
  return g_strcmp0(generated, "true") == 0;
}

// Quotes a single Exec argument as required by the Desktop Entry spec.
static gchar* quote_desktop_exec_arg(const gchar* arg) {
  GString* quoted = g_string_new("\"");
  for (const gchar* p = arg; *p != '\0'; p++) {
    if (*p == '"' || *p == '\\' || *p == '`' || *p == '$') {
      g_string_append_c(quoted, '\\');
    }
    g_string_append_c(quoted, *p);
  }
  g_string_append_c(quoted, '"');
  return g_string_free(quoted, FALSE);
}

// The generated entry uses a private icon name so it never shadows an icon
// installed by a real package.
static gchar* get_generated_icon_path() {
  g_autofree gchar* icon_dir = g_build_filename(
      g_get_user_data_dir(), "icons", "hicolor", "512x512", "apps", nullptr);
  return g_build_filename(icon_dir, APPLICATION_ID ".generated.png", nullptr);
}

// Registers a hidden user-level desktop entry. Wayland compositors match the
// window icon through the application's desktop file, so an unpackaged bundle
// shows a generic icon without one.
void register_desktop_entry() {
  g_autofree gchar* user_entry_path = g_build_filename(
      g_get_user_data_dir(), "applications", APPLICATION_ID ".desktop",
      nullptr);
  gboolean user_entry_exists =
      g_file_test(user_entry_path, G_FILE_TEST_IS_REGULAR);
  gboolean user_entry_generated =
      user_entry_exists && is_generated_desktop_entry(user_entry_path);

  if (has_system_desktop_entry()) {
    // Drop a previously generated entry and icon so they cannot shadow a real
    // package.
    if (user_entry_generated) {
      g_remove(user_entry_path);
      g_autofree gchar* generated_icon_path = get_generated_icon_path();
      g_remove(generated_icon_path);
    }
    return;
  }
  if (user_entry_exists && !user_entry_generated) {
    return;
  }

  g_autofree gchar* executable_path =
      g_file_read_link("/proc/self/exe", nullptr);
  if (executable_path == nullptr) {
    return;
  }
  g_autofree gchar* bundle_dir = g_path_get_dirname(executable_path);

  g_autofree gchar* template_path = g_build_filename(
      bundle_dir, "share", "applications", APPLICATION_ID ".desktop", nullptr);
  g_autoptr(GKeyFile) key_file = g_key_file_new();
  if (!g_key_file_load_from_file(key_file, template_path,
                                 G_KEY_FILE_KEEP_TRANSLATIONS, nullptr)) {
    return;
  }

  g_autofree gchar* icon_path = g_build_filename(
      bundle_dir, "share", "icons", "hicolor", "512x512", "apps",
      APPLICATION_ID ".png", nullptr);
  if (!g_file_test(icon_path, G_FILE_TEST_IS_REGULAR)) {
    return;
  }

  // NoDisplay keeps the entry out of application launchers; it only exists so
  // the desktop environment can resolve the icon for this window.
  g_autofree gchar* quoted_exec = quote_desktop_exec_arg(executable_path);
  g_key_file_set_boolean(key_file, "Desktop Entry", "NoDisplay", TRUE);
  g_key_file_set_string(key_file, "Desktop Entry", "Exec", quoted_exec);
  g_key_file_set_string(key_file, "Desktop Entry", "Icon",
                        APPLICATION_ID ".generated");
  g_key_file_set_string(key_file, "Desktop Entry", "X-Bugaoshan-Generated",
                        "true");

  g_autofree gchar* applications_dir = g_path_get_dirname(user_entry_path);
  if (g_mkdir_with_parents(applications_dir, 0755) != 0) {
    return;
  }

  g_autoptr(GError) error = nullptr;
  if (!g_key_file_save_to_file(key_file, user_entry_path, &error)) {
    g_warning("Failed to write desktop entry: %s", error->message);
    return;
  }

  // Use the themed icon name (not the bundle path) so compositors resolve it
  // through the icon theme. The bundle directory is not in the system icon
  // search path, so copy the icon into the user's hicolor theme.
  g_autofree gchar* user_icon_path = get_generated_icon_path();
  g_autofree gchar* icon_dir = g_path_get_dirname(user_icon_path);
  if (g_mkdir_with_parents(icon_dir, 0755) != 0) {
    return;
  }

  g_autofree gchar* icon_data = nullptr;
  gsize icon_size = 0;
  if (!g_file_get_contents(icon_path, &icon_data, &icon_size, nullptr)) {
    return;
  }

  gboolean icon_changed = TRUE;
  g_autofree gchar* user_icon_data = nullptr;
  gsize user_icon_size = 0;
  if (g_file_get_contents(user_icon_path, &user_icon_data, &user_icon_size,
                          nullptr)) {
    icon_changed = icon_size != user_icon_size ||
                   memcmp(icon_data, user_icon_data, icon_size) != 0;
  }
  if (icon_changed &&
      g_file_set_contents(user_icon_path, icon_data, icon_size, nullptr)) {
    g_autofree gchar* icon_theme_dir =
        g_build_filename(g_get_user_data_dir(), "icons", "hicolor", nullptr);
    gchar* argv[] = {(gchar*)"gtk-update-icon-cache", (gchar*)"-f",
                     (gchar*)"-t", icon_theme_dir, nullptr};
    g_spawn_async(
        nullptr, argv, nullptr,
        (GSpawnFlags)(G_SPAWN_SEARCH_PATH | G_SPAWN_STDOUT_TO_DEV_NULL |
                      G_SPAWN_STDERR_TO_DEV_NULL),
        nullptr, nullptr, nullptr, nullptr);
  }
}
