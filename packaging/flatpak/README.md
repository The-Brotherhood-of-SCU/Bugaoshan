# Flatpak packaging

`flatpak-flutter.yml` is the source manifest. Generate the offline manifest
with [flatpak-flutter](https://github.com/TheAppgineer/flatpak-flutter):

```sh
flatpak-flutter flatpak-flutter.yml
```

Build and install the generated manifest in a sandbox:

```sh
flatpak run org.flatpak.Builder \
  --user --install --force-clean --sandbox \
  --install-deps-from=flathub \
  build io.github.the_brotherhood_of_scu.bugaoshan.yml
```

The manifest builds only the Flutter application; Linux has no in-app WebView,
so no WPE WebKit stack is built or linked. `foreign.json` supplies the offline
sqlite3 native asset.
