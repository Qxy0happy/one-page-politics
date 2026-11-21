#!/usr/bin/env bash
# 生成 GitHub Release 的 update.json。
#
# 由发布工作流调用；所有输入走环境变量，便于在 CI 中复用：
#   APK, VERSION_NAME, VERSION_CODE, MIN_SDK, ASSET_NAME,
#   DOWNLOAD_URL, NOTES, OUTPUT
set -euo pipefail

fail() { printf 'make_update_manifest: %s\n' "$1" >&2; exit 1; }

: "${APK:?APK 未设置}"
: "${VERSION_NAME:?VERSION_NAME 未设置}"
: "${VERSION_CODE:?VERSION_CODE 未设置}"
: "${MIN_SDK:?MIN_SDK 未设置}"
: "${ASSET_NAME:?ASSET_NAME 未设置}"
: "${DOWNLOAD_URL:?DOWNLOAD_URL 未设置}"
: "${NOTES:?NOTES 未设置}"
: "${OUTPUT:?OUTPUT 未设置}"

[ -f "$APK" ] || fail "APK 不存在：$APK"
case "$VERSION_CODE" in
  ''|*[!0-9]*) fail "VERSION_CODE 必须是整数：$VERSION_CODE" ;;
esac
case "$MIN_SDK" in
  ''|*[!0-9]*) fail "MIN_SDK 必须是整数：$MIN_SDK" ;;
esac
case "$ASSET_NAME" in
  *.apk) ;;
  *) fail "ASSET_NAME 必须以 .apk 结尾：$ASSET_NAME" ;;
esac
case "$DOWNLOAD_URL" in
  https://*) ;;
  *) fail "DOWNLOAD_URL 必须使用 HTTPS：$DOWNLOAD_URL" ;;
esac
command -v jq >/dev/null 2>&1 || fail "需要 jq"

APK_SIZE="$(stat -c %s "$APK")"
APK_SHA256="$(sha256sum "$APK" | awk '{print $1}')"
PUBLISHED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

jq -n \
  --argjson schemaVersion 1 \
  --argjson versionCode "$VERSION_CODE" \
  --arg versionName "$VERSION_NAME" \
  --argjson minSdk "$MIN_SDK" \
  --arg publishedAt "$PUBLISHED_AT" \
  --arg notes "$NOTES" \
  --arg url "$DOWNLOAD_URL" \
  --argjson size "$APK_SIZE" \
  --arg sha256 "$APK_SHA256" \
  '{
    schemaVersion: $schemaVersion,
    versionCode: $versionCode,
    versionName: $versionName,
    minSdk: $minSdk,
    publishedAt: $publishedAt,
    notes: $notes,
    apk: {
      url: $url,
      size: $size,
      sha256: $sha256
    }
  }' > "$OUTPUT"

printf 'make_update_manifest: %s (%s bytes, sha256 %s)\n' \
  "$OUTPUT" "$APK_SIZE" "$APK_SHA256"
