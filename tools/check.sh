#!/usr/bin/env bash
# 仓库唯一的校验入口：本地与 CI 都调用本脚本。
#
# 用法：
#   tools/check.sh              # 格式、分析、测试、release 构建、APK 断言
#   SKIP_BUILD=1 tools/check.sh # 跳过构建与 APK 断言（纯代码检查，约 10 秒）
#   TARGET_PLATFORM=android-arm64 tools/check.sh  # 只构建 arm64-v8a
#   RELEASE_CERT_SHA256=<sha256> tools/check.sh   # 断言 APK 签名证书
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
BUILD_ARGS=(--release)
if [ -n "${TARGET_PLATFORM:-}" ]; then
  BUILD_ARGS+=(--target-platform "$TARGET_PLATFORM")
fi
flutter build apk "${BUILD_ARGS[@]}"
[ -f "$APK" ] || fail "未生成 $APK"

BUILD_TOOLS="$(find "$ANDROID_HOME/build-tools" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -1)"
[ -n "$BUILD_TOOLS" ] || fail "未找到 build-tools"

step "APK 断言：版本、权限、FileProvider、ABI、签名"

"$BUILD_TOOLS/aapt2" dump badging "$APK" > /tmp/check-badging.txt
VERSION_LINE="$(awk '/^version:/{print $2; exit}' pubspec.yaml)"
case "$VERSION_LINE" in
  *+*) ;;
  *) fail "pubspec.yaml 的 version 必须包含 build number（例如 1.2.0+3）" ;;
esac
VERSION_NAME="${VERSION_LINE%%+*}"
VERSION_CODE="${VERSION_LINE##*+}"
grep -q "versionCode='$VERSION_CODE'" /tmp/check-badging.txt \
  || fail "APK versionCode 与 pubspec.yaml 的 $VERSION_CODE 不一致"
grep -q "versionName='$VERSION_NAME'" /tmp/check-badging.txt \
  || fail "APK versionName 与 pubspec.yaml 的 $VERSION_NAME 不一致"
PACKAGE_NAME="$(sed -n "s/^package: name='\([^']*\)'.*/\1/p" /tmp/check-badging.txt)"
[ -n "$PACKAGE_NAME" ] || fail "无法从 APK 读取包名"

if [ -n "${TARGET_PLATFORM:-}" ]; then
  case "$TARGET_PLATFORM" in
    android-arm64) EXPECTED_ABI="arm64-v8a" ;;
    android-arm) EXPECTED_ABI="armeabi-v7a" ;;
    android-x64) EXPECTED_ABI="x86_64" ;;
    android-x86) EXPECTED_ABI="x86" ;;
    *) EXPECTED_ABI="" ;;
  esac
  if [ -n "$EXPECTED_ABI" ]; then
    ABI_LIBS="$(unzip -l "$APK" | awk '/lib\// && $4 ~ /^lib\/[^/]+\// {print $4}' | awk -F/ '{print $2}' | sort -u)"
    [ "$ABI_LIBS" = "$EXPECTED_ABI" ] \
      || fail "APK ABI 为 [$ABI_LIBS]，预期仅 [$EXPECTED_ABI]"
  fi
fi

"$BUILD_TOOLS/aapt2" dump permissions "$APK" > /tmp/check-permissions.txt
grep -q 'android.permission.INTERNET' /tmp/check-permissions.txt \
  || fail "release APK 必须声明 INTERNET（可选 DeepSeek 云语音）"
grep -q 'android.permission.REQUEST_INSTALL_PACKAGES' /tmp/check-permissions.txt \
  || fail "release APK 必须声明 REQUEST_INSTALL_PACKAGES（应用内更新）"
if grep -Eq 'android.permission.(READ|WRITE)_EXTERNAL_STORAGE|android.permission.MANAGE_EXTERNAL_STORAGE|android.permission.READ_MEDIA_' /tmp/check-permissions.txt; then
  cat /tmp/check-permissions.txt >&2
  fail "release APK 声明了多余的存储权限"
fi

"$BUILD_TOOLS/aapt2" dump xmltree --file AndroidManifest.xml "$APK" > /tmp/check-manifest.xml
grep -q 'TTS_SERVICE' /tmp/check-manifest.xml \
  || fail "AndroidManifest 缺少 TTS_SERVICE 查询声明"
grep -q "$PACKAGE_NAME.fileprovider" /tmp/check-manifest.xml \
  || fail "AndroidManifest 缺少更新用 FileProvider"

"$BUILD_TOOLS/apksigner" verify --print-certs "$APK" > /tmp/check-signer.txt \
  || fail "APK 签名校验失败"
CERT_SHA256="$(awk -F': ' '/certificate SHA-256 digest/ {print $2; exit}' /tmp/check-signer.txt)"
[ -n "$CERT_SHA256" ] || fail "无法读取 APK 签名证书摘要"
if [ -n "${RELEASE_CERT_SHA256:-}" ]; then
  ACTUAL_CERT="$(printf '%s' "$CERT_SHA256" | tr 'A-F' 'a-f')"
  EXPECTED_CERT="$(printf '%s' "$RELEASE_CERT_SHA256" | tr 'A-F' 'a-f' | tr -d ':')"
  [ "$ACTUAL_CERT" = "$EXPECTED_CERT" ] \
    || fail "APK 签名证书与 RELEASE_CERT_SHA256 不一致"
fi
sha256sum "$APK" | tee /tmp/check-apk.sha256

printf '\ncheck: 全部通过\n'
