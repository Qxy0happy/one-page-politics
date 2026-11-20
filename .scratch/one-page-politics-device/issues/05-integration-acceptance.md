# 05 — 集成验收：analyze、测试、release 构建与记录

Type: task
Status: resolved
Blocked by: 01, 02, 03, 04

## Goal

在集成分支上完成 [spec.md](../spec.md) §6 与 Testing Decisions 的代理可执行部分，并把证据写入验收记录。

## Scope

- 不改功能代码；只修验收中发现的问题。
- 不执行需要真机听感或系统语音设置交互的项；这些标注人工待办。

## Requirements

- `flutter analyze` 0 issue。
- `flutter test` 全部通过，记录总数。
- `flutter build apk --release` 成功，复核权限、签名、版本与 SHA-256。
- 尽可能用模拟器/无头方式做 UI 与队列回归；模拟器无音频，不替代真机听感。
- 更新 `app/docs/device-acceptance.md`：每项结果、证据、人工待办。
- 确认未引入新依赖、未改工具链版本、未静默安装组件。

## Acceptance

- 验收记录完整，所有代理可执行项有结果；真机项明确标注待人工。
- 追加 `## Answer`，汇总测试数量、APK 信息与待人工项，然后 `Status: resolved`。

## Answer

- `cd app && flutter analyze`：`No issues found!`。
- `cd app && flutter test`：`+47: All tests passed!`（复查修复后 47 个测试，全通过）。
- 最终 release APK：`app/build/app/outputs/flutter-apk/app-release.apk`，52 582 418 字节（约 50.1 MiB），SHA-256 `4b13a8cbe49740de78bbf8a8c44ddb44a643bef1fb67b3d10185ab0706b97b23`。
- 无头模拟器回归已在复查修复后的最终包（SHA-256 `4b13a8cbe49740de78bbf8a8c44ddb44a643bef1fb67b3d10185ab0706b97b23`）上重跑（`medium_phone`，Android 16，`-no-window -no-audio -no-boot-anim`）：`adb install -r` 成功；冷启动 `Status: ok`（`TotalTime: 2569`）且 Activity 保持 resumed；`uiautomator dump` 确认四个 Tab（`一页纸 / 反射场 / 工具箱 / 作战室`，各带 `Tab N of 4`）与 549 条内置内容；打开 `磨耳朵` 后面板显示诊断行 `引擎 com.google.android.tts · 语言 zh-CN`、`试听`、语速与循环控件，关闭后回主列表；logcat 匹配 `FATAL EXCEPTION`/`E/flutter`/ANR 的数量为 0。`adb emu kill` 后设备列表为空、无残留进程。旧包（`ce73abec…`）的回归结论不再引用。
- 模拟器环境注记：首次 `uiautomator dump` 被预装 `com.android.cli.interact.instrumentation` 占用 UiAutomation 注册阻断，`am force-stop` 后恢复，与应用无关。
- 证据已写入 `app/docs/device-acceptance.md` 的“代理回归（无头模拟器，2026-11-20）”一节。
- 待人工：真机听感（语速、断句、连续朗读）、系统“文字转语音输出”设置（引擎切换、中文语音数据安装、试听）、飞行模式离线行为、真机覆盖安装与升级后进度保留、七步检查中所有听感与交互项。
- 未引入新依赖，未改工具链版本，未安装任何组件；模拟器为本机既有 AVD。

## Comments

- 2026-11-20：真机 HONOR AAK-AN00（Android 16）七步验收完成。第 1–3、5–7 项通过；第 4 项因设备上没有现成的无中文 TTS 引擎而只验证了引擎切换与语言选择，不可用面板由单元测试覆盖。覆盖安装 `adb install -r` 后数据保留；飞行模式冷启动与朗读通过。验收后已清空测试数据，应用恢复 549 条、0 进度，设备音量/常亮/飞行模式/TTS 引擎均已恢复。证据见 `app/docs/device-acceptance.md` 的“真机验收（HONOR AAK-AN00，2026-11-20）”。
