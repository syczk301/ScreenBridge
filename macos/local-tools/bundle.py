"""Package localizations and icon using only macOS Command Line Tools."""
import json
from pathlib import Path
import plistlib
import shutil
import struct
import sys

root = Path(__file__).resolve().parents[1]
app = Path(sys.argv[1])
resources = app / 'Contents/Resources'
resources.mkdir(parents=True, exist_ok=True)
info = {
    'CFBundleIdentifier': 'local.screenbridge.app',
    'CFBundleName': '映桥',
    'CFBundleDisplayName': '映桥',
    'CFBundleExecutable': 'ScreenBridge',
    'CFBundlePackageType': 'APPL',
    'CFBundleShortVersionString': '1.1.16',
    'CFBundleVersion': '19',
    'LSMinimumSystemVersion': '14.0',
    'LSUIElement': True,
    'NSHighResolutionCapable': True,
    'CFBundleDevelopmentRegion': 'en',
    'CFBundleLocalizations': ['en', 'zh-Hans', 'zh-Hant'],
    'CFBundleIconFile': 'AppIcon',
    'NSAppleEventsUsageDescription': '映桥 使用系统自动化来切换显示相关设置。',
    'NSHumanReadableCopyright': 'Based on Crisp, Copyright (c) 2026 Didrik Galteland. MIT License; see bundled notices.',
}
with (app / 'Contents/Info.plist').open('wb') as f:
    plistlib.dump(info, f)
catalog = json.loads((root / 'Crisp/Resources/Localizable.xcstrings').read_text())
for lang in info['CFBundleLocalizations']:
    folder = resources / f'{lang}.lproj'
    folder.mkdir(exist_ok=True)
    lines = []
    for key, value in catalog['strings'].items():
        unit = value.get('localizations', {}).get(lang, {}).get('stringUnit', {})
        translated = unit.get('value', key)
        lines.append(f'{json.dumps(key, ensure_ascii=False)} = {json.dumps(translated, ensure_ascii=False)};')
    (folder / 'Localizable.strings').write_text('\n'.join(lines) + '\n')
# ICNS supports PNG payloads; package the original images losslessly.
source = root / 'local-assets/AppIcon'
chunks = []
for kind, size in [(b'icp4',16),(b'icp5',32),(b'icp6',64),(b'ic07',128),
                   (b'ic08',256),(b'ic09',512),(b'ic10',1024)]:
    png = (source / f'icon_{size}.png').read_bytes()
    chunks.append(kind + struct.pack('>I',len(png)+8) + png)
body = b''.join(chunks)
(resources / 'AppIcon.icns').write_bytes(b'icns' + struct.pack('>I',len(body)+8) + body)
for name in ['LICENSE', 'ACKNOWLEDGMENTS.md']:
    shutil.copy2(root / name, resources / name)
