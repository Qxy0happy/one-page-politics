#!/usr/bin/env bash
# 仓库唯一的校验入口：本地与 CI 都调用本脚本。
#
# 用法：
#   tools/check.sh              # 格式、分析、测试、release 构建、APK 断言
#   SKIP_BUILD=1 tools/check.sh # 跳过构建与 APK 断言（纯代码检查，约 10 秒）
#
# 依赖：flutter（PATH）；构建阶段另需 JAVA_HOME（带 jlink 的 JDK）与 ANDROID_HOME。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/app"
APK="$APP/build/app/outputs/flutter-apk/app-release.apk"
FORBIDDEN='^(srt/|\.scratch/|澄潇宇一页纸/|learning-records/|lessons/|reference/)|^澄潇宇考研政治主张整理\.md$'

fail() { printf 'check: %s\n' "$1" >&2; exit 1; }
step() { printf '\n==> %s\n' "$1"; }

step "追踪路径白名单：课程转写与内部文档不进版本控制"
TRACKED="$(cd "$ROOT" && git ls-files)"
if printf '%s\n' "$TRACKED" | grep -Eq "$FORBIDDEN"; then
  printf '%s\n' "$TRACKED" | grep -E "$FORBIDDEN" >&2
  fail "上述路径被 git 跟踪；它们只保留在本地（见 .gitignore）"
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

: "${JAVA_HOME:?JAVA_HOME 未设置；需要带 jlink 的 JDK（GraalVM 的 jlink 会失败）}"
: "${ANDROID_HOME:?ANDROID_HOME 未设置；需要 Android SDK}"

step "flutter build apk --release"
flutter build apk --release
[ -f "$APK" ] || fail "未生成 $APK"

BUILD_TOOLS="$(find "$ANDROID_HOME/build-tools" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -1)"
[ -n "$BUILD_TOOLS" ] || fail "未找到 build-tools"

step "APK 断言：权限、TTS 查询、签名"

"$BUILD_TOOLS/aapt2" dump permissions "$APK" > /tmp/check-permissions.txt
grep -q 'android.permission.INTERNET' /tmp/check-permissions.txt \
  || fail "release APK 必须声明 INTERNET（可选 DeepSeek 云语音）"
if grep -Eq 'android.permission.(READ|WRITE)_EXTERNAL_STORAGE|android.permission.MANAGE_EXTERNAL_STORAGE|android.permission.READ_MEDIA_' /tmp/check-permissions.txt; then
  cat /tmp/check-permissions.txt >&2
  fail "release APK 声明了多余的存储权限"
fi

"$BUILD_TOOLS/aapt2" dump xmltree --file AndroidManifest.xml "$APK" > /tmp/check-manifest.xml
grep -q 'TTS_SERVICE' /tmp/check-manifest.xml || fail "AndroidManifest 缺少 TTS_SERVICE 查询声明"

"$BUILD_TOOLS/apksigner" verify --print-certs "$APK" > /tmp/check-signer.txt || fail "APK 签名校验失败"
sha256sum "$APK" | tee /tmp/check-apk.sha256

printf '\ncheck: 全部通过\n'
