#!/usr/bin/env python3
"""Generate the Android host and enable Flutter GPU for Flutter Scene."""
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ANDROID = ROOT / 'android'

subprocess.run(
    [
        'flutter', 'create', '--platforms=android',
        '--org', 'com.duckdream',
        '--project-name', 'project_arena_flutter',
        str(ROOT),
    ],
    check=True,
)

manifest = ANDROID / 'app/src/main/AndroidManifest.xml'
if not manifest.exists():
    raise SystemExit(f'Android manifest not generated: {manifest}')

ET.register_namespace('android', 'http://schemas.android.com/apk/res/android')
tree = ET.parse(manifest)
application = tree.getroot().find('application')
if application is None:
    raise SystemExit('AndroidManifest.xml has no application element')

android_ns = '{http://schemas.android.com/apk/res/android}'
gpu_name = 'io.flutter.embedding.android.EnableFlutterGPU'
meta = next(
    (node for node in application.findall('meta-data')
     if node.get(android_ns + 'name') == gpu_name),
    None,
)
if meta is None:
    meta = ET.SubElement(application, 'meta-data')
    meta.set(android_ns + 'name', gpu_name)
meta.set(android_ns + 'value', 'true')

for activity in application.findall('activity'):
    if activity.get(android_ns + 'name', '').endswith('MainActivity'):
        activity.set(android_ns + 'screenOrientation', 'landscape')

tree.write(manifest, encoding='utf-8', xml_declaration=True)

gradle_candidates = [
    ANDROID / 'app/build.gradle.kts',
    ANDROID / 'app/build.gradle',
]
gradle = next((path for path in gradle_candidates if path.exists()), None)
if gradle is None:
    raise SystemExit('Android app Gradle file was not generated')

content = gradle.read_text(encoding='utf-8')
content = re.sub(
    r'applicationId\s*(?:=\s*)?["\']com\.duckdream\.project_arena_flutter["\']',
    'applicationId = "com.duckdream.projectarena"' if gradle.suffix == '.kts'
    else 'applicationId "com.duckdream.projectarena"',
    content,
)
if gradle.suffix == '.kts':
    content = re.sub(r'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 23', content)
else:
    content = re.sub(r'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 23', content)
gradle.write_text(content, encoding='utf-8')

print('Android host prepared: applicationId=com.duckdream.projectarena, minSdk=23, Flutter GPU enabled, landscape.')
