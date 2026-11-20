# 01 — 离线中文 TTS 的可行性与降级方案

Type: research
Status: resolved
Blocked by: —

## Question

`flutter_tts` 在 Android 模拟器（AVD `medium_phone`）与真机上能否离线朗读中文？需要确认：

- 系统 TTS 引擎与中文语音数据的依赖；模拟器镜像是否自带；Android 11+ 的 `<queries>` 声明是否足够。
- `flutter_tts` 的关键 API：可用性检测、语言/语速设置、`awaitSpeakCompletion`、暂停/停止、队列。
- “读题干 → 停顿 → 读结论”的朗读队列如何组织；与滑卡/遮罩交互如何不互相打断。
- 无可用中文语音时的降级路径：静默禁用、提示安装语音数据、预生成音频，或其他。

## Acceptance

研究笔记写入 `.scratch/one-page-politics/research/tts-offline.md`，附来源链接与明确结论；在本文件追加 `## Answer`，给出推荐方案与风险。不要修改应用代码。

## Answer

研究笔记：[tts-offline.md](../research/tts-offline.md)。`flutter_tts 4.2.5` 与 `TTS_SERVICE` 查询已接入；模拟器上初始化、队列、暂停/继续与进度（1/549）通过（`-no-audio`，未验听感）。真机需要系统中文语音；不可用时播控条显示安装提示与重试。结论：Go；真实音频留真机检查。
