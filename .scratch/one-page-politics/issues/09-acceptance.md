# 09 — 验收清单与交付方式

Type: grilling
Status: resolved
Blocked by: —

## Question

定义“做完”的可验证标准与交付路径：

- 模拟器上必须走通的流程（首次启动、导入 md、刷眼一轮、四类微训练各一次、重启后进度保留、深浅色切换）。
- 静态检查与测试：`flutter analyze`、`flutter test`、`flutter build apk --debug` 的通过标准；哪些交互需要 widget test。
- TTS 与文件导入在模拟器受限时，哪些结论允许延到真机；真机验证的最小清单。
- APK 输出路径、版本号、安装步骤；是否需要 release 构建与签名。
- 哪些问题允许留到 v1.1；哪些是阻塞交付的缺陷。

## Acceptance

回答中给出可勾选的验收清单、命令与预期输出、交付物路径；用户确认后作为实施阶段的完成定义。

## Comments

- 2026-11-20：[spec.md](../spec.md) §12 已给出临时验收门槛（`flutter analyze`、`flutter test`、debug build、模拟器手动清单、真机最小项）。本任务单保留最终验收、release 构建与签名、v1.1 缺陷分级；待 02 完成后展开。

## Answer

验收证据：`flutter analyze` 0 issue；`flutter test` 20 个通过；`flutter build apk --debug` 成功；`medium_phone` 冒烟覆盖 Tab1 遮罩/三态/标星/长按热修、Tab2 四模式、Tab3 两段、Tab4 计时/计分/折线图/导入/导出/清空、TTS 播控与降级。

APK：`app/build/app/outputs/flutter-apk/app-debug.apk`。debug APK 作为短期个人交付；release 签名与商店分发按地图 Out of scope。真机 TTS 音频留设备检查。无 v1.1 阻塞项。
