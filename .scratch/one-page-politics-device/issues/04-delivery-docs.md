# 04 — 交付文档：README 与真机验收清单

Type: task
Status: resolved
Blocked by: —

## Goal

按 [spec.md](../spec.md) §7 替换 `app/README.md` 的 Flutter 模板内容，并建立可重复执行的真机验收记录。

## Scope

- 只改 `app/README.md`，新增 `app/docs/device-acceptance.md`。
- 不复制完整规格；链接到 `.scratch/one-page-politics-device/spec.md` 与 `.scratch/one-page-politics/spec.md`。

## Requirements

- README 包含：应用用途与四 Tab 概览、构建命令、APK 输出位置、个人侧载签名说明、安装方式、TTS 故障排查、验收清单入口、已知边界。
- 验收记录包含 spec §6 的七步检查、设备型号/Android 版本/语音引擎/所选语言/APK 版本/SHA-256 字段、每项结果与证据位置。
- 明确真机听感与系统语音设置是人工检查点；当前未连接设备时标注“待人工”。
- 不写口号式内容；保持简短、可执行。

## Acceptance

- README 与验收记录存在、链接有效、命令可复制执行。
- 追加 `## Answer`，记录文件路径，然后 `Status: resolved`。

## Answer

- 替换 `app/README.md`：用途、四 Tab 概览、构建命令、APK 输出路径、debug 签名与覆盖安装说明、USB/手动安装、TTS 排查（系统“文字转语音输出”路径）、验收入口、已知边界；链接指向 device spec 与冻结基线。
- 新增 `app/docs/device-acceptance.md`：环境/产物字段表、构建与静态检查表（供 03/05 填写实际输出）、spec §6 七步检查表（结果与证据列）、TTS 日志命令、无设备时的人工检查点清单；未预填构建数据，真机项均为“待人工”。
- 未运行构建、测试或 `flutter analyze`（不属于本任务范围；证据留给 03/05）。
