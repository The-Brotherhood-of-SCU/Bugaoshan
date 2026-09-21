# ArkWeb 本地字体

此目录随 Flutter Web 构建原样复制到 `build/web/fonts/`，不通过 `pubspec.yaml` 的 assets 打包。字体仅由 ArkWeb 启动流程主动加载；普通浏览器、Android 和其他原生平台保留原来的字体行为。

字体为 Google Fonts 的 Noto Sans SC，包含完整原始字符集，未做字符裁剪。使用 SIL Open Font License 1.1，许可证见 [OFL.txt](OFL.txt)。

| 文件 | 字重 | 原始 TTF 的 SHA-256 |
|---|---|---|
| NotoSansSC-Regular.woff2 | 400 | `a0ecca1c67a4da5a89857703b84a44eba9fce7d7b5941bf4285e8c0a8346cf60` |
| NotoSansSC-Medium.woff2 | 500 | `b85915277d672d101e3b4aa74e16e9f88d0f13e6552579e92a0d54a1291013cd` |
| NotoSansSC-SemiBold.woff2 | 600 | `a9100a1e77488d43c4dc38cfdd3602f7169181aa8b2696ff63d8ad90308ff1e3` |
| NotoSansSC-Bold.woff2 | 700 | `2179d44af51b5fc3db254102bd9710fb50e1538754cd33349f1ae1056bf7f3c8` |

原始字体来自 `google_fonts` 8.2.1 的 Noto Sans SC 文件描述，下载地址为 `https://fonts.gstatic.com/s/a/<SHA-256>.ttf`。转换前已对照描述中的长度和 SHA-256 确认下载完整。

WOFF2 文件使用 FontTools 4.65.0 和 Brotli 1.2.0 从上述 TTF 转换，保留字形、字重及排版信息。转换方法：

```python
from fontTools.ttLib import TTFont

for style in ('Regular', 'Medium', 'SemiBold', 'Bold'):
    with TTFont(f'NotoSansSC-{style}.ttf', recalcTimestamp=False) as font:
        font.flavor = 'woff2'
        font.save(f'NotoSansSC-{style}.woff2')
```

许可证来源：[Google Fonts 仓库的 Noto Sans SC OFL.txt](https://github.com/google/fonts/blob/main/ofl/notosanssc/OFL.txt)。

在 ArkWeb 中，四个字重通过 `FontLoader` 注册为同一个字体族 `BugaoshanNotoSansSC`，主题中的 `fontWeight` 负责选择对应字重。字体加载完成后才显示主界面。此目录更新后，需重新构建 Web 并将整个 `build/web/` 复制到鸿蒙的 `entry/src/main/resources/rawfile/web/`。
