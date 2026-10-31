#ifndef FLUTTER_DESKTOP_ENTRY_H_
#define FLUTTER_DESKTOP_ENTRY_H_

// Registers a hidden user-level desktop entry so Wayland compositors can
// resolve the application icon from it. Safe to call on every launch.
void register_desktop_entry();

#endif  // FLUTTER_DESKTOP_ENTRY_H_
