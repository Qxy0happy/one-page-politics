#!/usr/bin/env bash
# 仓库唯一的校验入口：本地与 CI 都调用本脚本。
#
# 用法：
#   tools/check.sh              # 格式、分析、测试、release 构建、APK 断言
#   SKIP_BUILD=1 tools/check.sh # 跳过构建与 APK 断言（纯代码检查，约 10 秒）
#
# 依赖：flutter（PATH）、JAVA_HOME 指向带 jlink 的 JDK、ANDROID_HOME 指向 Android SDK。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/app"
APK="$APP/build/app/outputs/flutter-apk/app-release.apk"

: "${JAVA_HOME:?JAVA_HOME 未设置；需要带 jlink 的 JDK（GraalVM 的 jlink 会失败）}"
: "${ANDROID_HOME:?ANDROID_HOME 未设置；需要 Android SDK}"

fail() { printf 'check: %s\n' "$1" >&2; exit 1; }
step() { printf '\n==> %s\n' "$1"; }

build_tools() {
  local dir
  dir="$(find "$ANDROID_HOME/build-tools" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -1)"
  [ -n "$dir" ] || fail "未找到 build-tools"
  printf '%s\n' "$dir"
}

step "追踪路径白名单：课程转写与内部文档不得进入版本控制"
if (cd "$ROOT" && git ls-files) | grep -Eq '^(srt/|\.scratch/|澄潇宇一页纸/|learning-records/|lessons/|reference/)|^澄潇宇考研政治主张整理\.md$'; then
  (cd "$ROOT" && git ls-files) | grep -E '^(srt/|\.scratch/|澄潇宇一页纸/|learning-records/|lessons/|reference/)|^澄潇宇考研政治主张整理\.md$' >&2
  fail "上述路径被 git 跟踪；它们只应保留在本地（见 .gitignore）"
fi

cd "$APP"

step "dart format"
dart format --output=none --set-exit-if-changed lib test

step "flutter analyze"
flutter analyze

step "flutter test"
flutter test

if [ "${SKIP_BUILD:-0}" = "1" ]; then
  step "跳过 release 构建（SKIP_BUILD=1）"
  exit 0
fi

step "flutter build apk --release"
flutter build apk --release
[ -f "$APK" ] || fail "未生成 $APK"

TOOLS="$(build_tools)"
step "APK 断言：权限、TTS 查询、签名"

"$TOOLS/aapt2" dump permissions "$APK" > /tmp/check-permissions.txt
if ! grep -q 'android.permission.INTERNET' /tmp/check-permissions.txt; then
  fail "release APK 必须声明 INTERNET（可选 DeepSeek 云语音）"
fi
if grep -Eq 'android.permission.(READ|WRITE)_EXTERNAL_STORAGE|android.permission.MANAGE_EXTERNAL_STORAGE|android.permission.READ_MEDIA_' /tmp/check-permissions.txt; then
  cat /tmp/check-permissions.txt >&2
  fail "release APK 声明了多余的存储权限"
fi

"$TOOLS/aapt2" dump xmltree --file AndroidManifest.xml "$APK" > /tmp/check-manifest.xml
if ! grep -q 'TTS_SERVICE' /tmp/check-manifest.xml; then
  fail "AndroidManifest 缺少 TTS_SERVICE 查询声明"
fi

"$TOOLS/apksigner" verify --print-certs "$APK" > /tmp/check-signer.txt || fail "APK 签名校验失败"
sha256sum "$APK" | tee /tmp/check-apk.sha256

printf '\ncheck: 全部通过\n'
