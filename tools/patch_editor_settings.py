#!/usr/bin/env python3
"""Point Godot's editor settings at the Android SDK and a debug keystore."""

import os
import sys
from pathlib import Path

sdk = os.environ["ANDROID_SDK_ROOT"]
java = os.environ["JAVA_HOME"]
debug_ks = os.environ.get("GODOT_DEBUG_KEYSTORE", "")

candidates = list(Path.home().glob(".config/godot/editor_settings*.tres"))
if not candidates:
    path = Path.home() / ".config/godot/editor_settings-4.7.tres"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n',
        encoding="utf-8",
    )
else:
    path = sorted(candidates)[-1]

text = path.read_text(encoding="utf-8")
if "[resource]" not in text:
    text += "\n[resource]\n"

values = {
    "export/android/android_sdk_path": sdk,
    "export/android/java_sdk_path": java,
}
if debug_ks:
    values["export/android/debug_keystore"] = debug_ks
    values["export/android/debug_keystore_user"] = "androiddebugkey"
    values["export/android/debug_keystore_pass"] = "android"

lines = text.splitlines()
kept = []
for line in lines:
    key = line.split("=", 1)[0].strip().strip('"')
    if key in values:
        continue
    kept.append(line)
if not any(line.strip() == "[resource]" for line in kept):
    kept.append("[resource]")
for key, value in values.items():
    kept.append(f'{key} = "{value}"')
path.write_text("\n".join(kept) + "\n", encoding="utf-8")
print(f"patched {path}")
