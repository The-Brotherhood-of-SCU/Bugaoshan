# AUR packaging

Bugaoshan has no native Linux WebView, so nothing needs WPE WebKit. A future
PKGBUILD should declare these direct runtime dependencies instead of copying
their shared libraries into the application bundle:

- `gtk3`
- `libepoxy`
- `libsecret`
- `wayland`

After packaging, verify that `ldd` resolves every dependency from the system,
and that the application bundle contains no leftover WebView / WPE libraries
(`libflutter_inappwebview_linux_plugin.so`, `libWPEWebKit`, `libWPEBackend-fdo`,
`libwpe`).
