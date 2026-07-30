# AUR packaging

Bugaoshan keeps the native Linux WebView plugin but dynamically links WPE
WebKit from the host system. A future PKGBUILD should declare these direct
runtime dependencies instead of copying their shared libraries into the
application bundle:

- `gtk3`
- `libepoxy`
- `libsecret`
- `libwpe`
- `wayland`
- `wpebackend-fdo`
- `wpewebkit`

After packaging, verify that `libflutter_inappwebview_linux_plugin.so` exists,
that the application bundle contains no `libWPEWebKit`, `libWPEBackend-fdo`, or
`libwpe` copies, and that `ldd` resolves every dependency from the system.
