from PIL import Image
import os

old_icon = Image.open('E:\\Programs\\Bugaoshan\\assets\\icon_old.png').convert('RGBA')

# Adaptive icon foreground sizes (108dp reference)
sizes = {
    'drawable-mdpi': 108,
    'drawable-hdpi': 162,
    'drawable-xhdpi': 216,
    'drawable-xxhdpi': 324,
    'drawable-xxxhdpi': 432,
}

res_dir = 'E:\\Programs\\Bugaoshan\\android\\app\\src\\main\\res'

for d, size in sizes.items():
    target_dir = os.path.join(res_dir, d)
    os.makedirs(target_dir, exist_ok=True)

    resized = old_icon.resize((size, size), Image.LANCZOS)
    target_path = os.path.join(target_dir, 'ic_launcher_old_foreground.png')
    resized.save(target_path, 'PNG')
    print(f'Created {target_path} ({size}x{size})')

# Create mipmap-anydpi-v26 XML
xml_dir = os.path.join(res_dir, 'mipmap-anydpi-v26')
os.makedirs(xml_dir, exist_ok=True)

xml_content = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
  <background android:drawable="@color/ic_launcher_old_background"/>
  <foreground>
      <inset
          android:drawable="@drawable/ic_launcher_old_foreground"
          android:inset="16%" />
  </foreground>
</adaptive-icon>
'''

with open(os.path.join(xml_dir, 'ic_launcher_old.xml'), 'w') as f:
    f.write(xml_content)
print(f'Created {os.path.join(xml_dir, "ic_launcher_old.xml")}')

# Add color resource
values_dir = os.path.join(res_dir, 'values')
os.makedirs(values_dir, exist_ok=True)

color_xml = '''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_old_background">#FFFFFF</color>
</resources>
'''

colors_path = os.path.join(values_dir, 'ic_launcher_old_background.xml')
with open(colors_path, 'w') as f:
    f.write(color_xml)
print(f'Created {colors_path}')

print('Done!')
