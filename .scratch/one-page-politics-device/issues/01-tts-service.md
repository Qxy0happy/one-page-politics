# 01 — TTS 服务：中文语音选择、诊断与播放状态机

Type: task
Status: resolved
Blocked by: —

## Goal

按 [spec.md](../spec.md) §3、§4 与 Testing Decisions 重写 `app/lib/services/tts_service.dart`，让 TTS 在引擎报错、无回调或语音缺失时不会卡死，并暴露播控条需要的诊断状态。

## Scope

- 只改 `app/lib/services/tts_service.dart`，新增 `app/test/tts_service_test.dart`；必要时新增最小的测试辅助文件。
- 不改 `app/lib/widgets/tts_sheet.dart`（由 02 处理），不改学习算法、seed、Markdown 协议、四 Tab 信息结构。
- 不新增依赖。

## Requirements

- 初始化读取语言列表、引擎列表、默认引擎；任一失败不影响其他项。
- BCP-47 归一化：大小写不敏感，`_` → `-`。
- 语言选择顺序：精确 `zh-CN` → 任意 `zh-Hans*` → 第一个 `zh-*` → 依次探测 `zh-CN`、`zh-TW`、`zh-HK`、`zh`；每个候选都调用 `setLanguage` 并检查返回值，失败继续。
- 只读诊断：`available`、`selectedLanguage`、`engineName`（取不到时“系统默认”）、`languageCount`、`lastError`。
- 播放状态机：单一播放循环；播放/暂停/继续/上一条/下一条/关闭/试听都递增会话代次；旧循环在每个 `await` 后检查代次。
- 暂停、上一条、下一条、关闭显式结束当前 utterance 等待；停止后旧循环不得推进索引或写状态。
- 每条 utterance 默认 60 秒看门狗，可通过构造参数注入更短超时；超时调用停止、记录错误、跳过并继续。
- 订阅平台错误回调，错误到达立即结束当前等待；`speak` 返回 0 或抛异常按失败处理。
- 连续 3 条失败停止整队并进入 `degraded`，错误为“语音引擎无响应”；单条失败只跳过。
- 暂停后继续从当前索引；播放态下上一条/下一条立即切换，暂停态只移动索引；循环在一轮结束后回索引 0。
- `preview()` 朗读固定中文短句，不改变队列索引，不写学习状态。
- 朗读文本格式化提取为纯函数并测试；是非条目包含“正确/错误”与解析。
- `dispose()` 停止并释放引擎，之后不得再通知 UI。

## Acceptance

- `flutter analyze` 0 issue；`flutter test` 全部通过（现有 20 个 + 新增 TTS 测试）。
- 新增测试覆盖 spec Testing Decisions 的 15 条行为，使用注入的假 `FlutterTts`，不依赖平台通道、不等待 60 秒。
- 在 ticket 末尾追加 `## Answer`，记录测试数量与关键实现取舍，然后 `Status: resolved`。

## Answer

实现完成。

- 测试数量：`flutter test` 共 43 个，全部通过（现有 20 个 + `tts_service_test.dart` 新增 23 个）；`flutter analyze` 0 issue。
- 新增测试用一个覆写全部平台方法的 `FakeFlutterTts`，通过构造参数注入 40 ms 看门狗与零停顿，覆盖 Testing Decisions 的 15 条行为，不依赖平台通道、不等待 60 秒。
- 关键取舍：
  - 语言候选先按列表优先级（精确 `zh-CN` → `zh-Hans*` → 列表中的其余 `zh-*`），列表候选全部失败后才按 `isLanguageAvailable` 探测 `zh-CN`、`zh-TW`、`zh-HK`、`zh`；每个候选都调用并检查 `setLanguage` 返回值。列表其余 `zh-*` 作为兜底，保证 `zh-CN` 失败时可回退到列表中的 `zh-TW`。
  - 播放状态机用自增会话代次 + 单一 `_pending` utterance 等待器；暂停/上一条/下一条/关闭/试听先递增代次并结束等待，旧循环在每个 `await` 后校验代次，不再推进索引或写状态。
  - `_stopBarrier` 串行化停止与下一次朗读，快速播放/暂停/继续时最大并发朗读数保持为 1。
  - 看门狗、平台错误回调、`speak` 返回 0 或抛异常都汇入同一种失败结果；单条失败跳过，连续 3 条进入 `degraded` 并显示“语音引擎无响应”。
  - 朗读文本格式化为顶层纯函数 `ttsPromptText` / `ttsAnswerText`，播控条可直接复用。
  - `dispose()` 后所有 `notifyListeners` 均被守卫，引擎停止但不再通知 UI。
