#!/bin/zsh
set -euo pipefail
script_dir=${0:A:h}
dest_dir=${1:-${script_dir}/dist}
app_path="${dest_dir}/U7 Codex Boot.app"
mkdir -p "${app_path}/Contents/MacOS" "${app_path}/Contents/Resources"
swiftc -O -framework AppKit -framework AVFoundation -framework CoreGraphics \
  "${script_dir}/U7Boot.swift" -o "${app_path}/Contents/MacOS/U7CodexBoot"
cp "${script_dir}/Info.plist" "${app_path}/Contents/Info.plist"
cp "${script_dir}/u7-entrance-final.mp4" "${app_path}/Contents/Resources/startup.mp4"
codesign --force --sign - --timestamp=none "${app_path}"
echo "Built: ${app_path}"
