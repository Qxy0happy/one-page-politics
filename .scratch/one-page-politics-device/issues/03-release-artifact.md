# 03 — Release APK：构建、权限、签名与版本核对

Type: task
Status: resolved
Blocked by: 02

## Goal

按 [spec.md](../spec.md) §1、§2、§6 产出可个人侧载的 universal release APK，并记录可核对的构建证据。

## Scope

- 只做构建与验证；不改学习算法、seed、协议、四 Tab 结构。
- 不新建密钥库，沿用当前 debug 签名；不生成 AAB；不新增依赖或工具链组件。

## Requirements

- `flutter build apk --release` 成功，产物为 universal APK。
- 用 `aapt2 dump permissions` 确认 release 合并清单不含 `android.permission.INTERNET`；若被插件合并进来，在主清单加移除规则并复查。
- 确认 `<queries>` 保留 `TTS_SERVICE`。
- 用 `apksigner verify --print-certs` 确认已签名并记录证书摘要。
- 用 `aapt2 dump badging` 核对包名 `com.qxyhappy.one_page_politics`、版本号、SDK 范围。
- 记录 APK 路径、大小、SHA-256、版本号、证书摘要。
- 证据写入 `app/docs/device-acceptance.md` 的“构建与静态检查”小节（若文件不存在，先按 04 的结构创建）。

## Acceptance

- 命令输出摘要与 APK 路径写入验收记录；`flutter analyze` 0、`flutter test` 全部通过。
- 追加 `## Answer`，记录实际大小与 SHA-256，然后 `Status: resolved`。

## Answer

2026-11-20 在本机完成 universal release 构建与静态核对，产物可直接侧载；真机安装、听感与七步检查仍待人工。

产物：

- 路径：`app/build/app/outputs/flutter-apk/app-release.apk`
- 大小：52 582 418 字节（约 50.1 MiB；debug 包约 200 MB，release 明显更小）
- SHA-256：`4b13a8cbe49740de78bbf8a8c44ddb44a643bef1fb67b3d10185ab0706b97b23`（TTS 试听隔离与播放状态辅助的复查修复后重建的最终产物；首次构建为 `ce73abec…`，体积不变）
- 版本：`com.qxyhappy.one_page_politics`，versionName `1.0.0`，versionCode `1`，minSdk 24，targetSdk/compileSdk 36
- 签名：`C=US, O=Android, CN=Android Debug`（沿用 debug 签名，未新建密钥库），证书 SHA-256 `9ee59fcf9f36e0699079ae7ce2d7ce1f94215010db5a3b0373d19bbc41e97e50`

执行的命令与结果：

```bash
cd app
flutter analyze                 # No issues found!
flutter test                    # +43: All tests passed!（复查修复后为 +47）
flutter build apk --release     # Built .../app-release.apk (52.6MB)，assembleRelease 84.7s

BT=$HOME/develop/Android/Sdk/build-tools/36.0.0
$BT/aapt2 dump permissions app-release.apk
# 仅 DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION，无 android.permission.INTERNET

$BT/aapt2 dump xmltree --file AndroidManifest.xml app-release.apk | grep TTS_SERVICE
# A: android:name="android.intent.action.TTS_SERVICE"（queries 内保留）

$BT/aapt2 dump badging app-release.apk | head -2
# package: name='com.qxyhappy.one_page_politics' versionCode='1' versionName='1.0.0'
# minSdkVersion:'24'  targetSdkVersion:'36'

$BT/apksigner verify --print-certs app-release.apk
# Signer #1 certificate DN: C=US, O=Android, CN=Android Debug
# Signer #1 certificate SHA-256 digest: 9ee59fcf...
```

结论与取舍：

- 合并清单未引入 `INTERNET`，因此未修改主清单，也没有加 manifest merger 移除规则。
- `TTS_SERVICE` 查询存在，`flutter_tts` 可以发现系统引擎。
- 仍是 debug 签名，只能个人侧载；换机器重建需保留同一 debug keystore 才能覆盖安装。
- 构建产生一条 Flutter 警告：`flutter_tts` 仍使用 Kotlin Gradle Plugin，未来 Flutter 版本可能拒绝构建；本次不升级插件，仅记录。
- 构建、签名与权限证据已写入 `app/docs/device-acceptance.md` 的“环境与产物”和“构建与静态检查”；设备型号、Android 版本、语音引擎、所选语言与七步检查保持“待人工”。
- 复查修复后重建的最终包（SHA-256 `4b13a8…`，52 582 418 字节）已重跑无头模拟器回归：`adb install -r` 成功，冷启动 `Status: ok` 且保持 resumed，dump 确认四个 Tab 与 549 条内容、磨耳朵面板诊断/试听/语速/循环控件，logcat 无 `FATAL EXCEPTION`/`E/flutter`/ANR，`adb emu kill` 后无残留；详见验收记录“代理回归”一节。
