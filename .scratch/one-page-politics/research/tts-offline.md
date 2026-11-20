# 离线中文 TTS

日期：2026-11-20。目标：确认 `flutter_tts` 在 Android 上的离线中文朗读、队列与降级方案。

## 环境

- `flutter_tts 4.2.5`；`AndroidManifest.xml` 已声明 `android.intent.action.TTS_SERVICE` 查询。
- 模拟器：`medium_phone`，无头启动（`-no-window -no-audio`）。
- 真机：当前未连接。

## 结果

- 模拟器上 `flutter_tts` 初始化成功；`getLanguages` / `isLanguageAvailable('zh-CN')` 返回可用，播控条能进入播放态，进度从 0/549 走到 1/549，暂停/继续按钮状态正确。
- 因为模拟器用 `-no-audio` 启动，无法用耳朵确认音频输出；这验证的是引擎/队列/UI，不验证扬声器。
- 真机需要系统 TTS 引擎与中文语音数据。若 `isLanguageAvailable('zh-CN')` 为 false，且 `getLanguages` 不含 `zh`，播控条显示“系统未安装中文离线语音”，提供“重试”，不阻塞其他功能。
- 队列：题干 → 停顿 1.5 秒 → 结论 → 停顿 0.6 秒 → 下一条；`awaitSpeakCompletion(true)`。
- 语速：`setSpeechRate` 使用 0.5 / 0.6 / 0.7 对应 1.0x / 1.25x / 1.5x。
- 支持上一条/下一条、单列表循环；关闭面板即 `stop()` 并释放。
- 是非卡朗读“题干 → 正确/错误 + 解析”；配对/对比卡朗读“题干 → 答案”。

## 降级

- 中文语音不可用：禁用播放，显示安装提示与重试；不崩溃、不阻塞 Tab1/Tab2。
- 朗读过程中切换筛选：播控条使用打开时的筛选快照；关闭重开即刷新。
- 真机验收：安装中文离线语音后，确认音色、停顿、语速和循环；模拟器结果不能替代音频验收。

## 结论

Go。实现与降级已完成；真实音频输出留作真机检查项，不阻塞 debug APK 交付。
