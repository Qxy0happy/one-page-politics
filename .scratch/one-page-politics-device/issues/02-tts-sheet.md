# 02 — 播控条：诊断行、试听、失败提示与重试

Type: task
Status: resolved
Blocked by: 01

## Goal

按 [spec.md](../spec.md) §5 改造 `app/lib/widgets/tts_sheet.dart`，把 01 暴露的诊断与失败状态呈现给用户。

## Scope

- 只改 `app/lib/widgets/tts_sheet.dart`；如需微调 01 的公开 API，只做向后兼容的小改动。
- 不新增依赖，不改四 Tab 信息结构。

## Requirements

- 增加一行诊断：引擎名称与所选语言；超长省略，不换行挤压控件。
- 增加“试听”按钮，调用 `preview()`；试听不改变队列索引；失败时 SnackBar 显示原因，按钮恢复可用。
- 增加失败提示区：已跳过条数、最近错误；提供“重试”，从当前索引继续；不可用时重新初始化。
- 保留播放/暂停、上一条/下一条、1.0x/1.25x/1.5x、单列表循环与进度显示。
- 无中文语音时保留说明与“重试”，补充系统设置路径文字；不做应用内跳转。
- 关闭面板立即停止并释放引擎。

## Acceptance

- `flutter analyze` 0 issue；`flutter test` 全部通过。
- 用现有假 TTS 或临时脚本验证：诊断行可渲染、试听失败会提示、不可用时重试会重新初始化。
- 追加 `## Answer`，记录改动与验证，然后 `Status: resolved`。

## Answer

实现完成。

- 改动文件：`app/lib/widgets/tts_sheet.dart`、本 ticket。
- 诊断行：标题下方显示“引擎 <engineName> · 语言 <selectedLanguage>”，单行 `TextOverflow.ellipsis`，不挤压右侧控件；引擎或语言为空时回退为“系统默认”“未选择”。
- 试听：新增“试听”按钮调用 `preview()`；朗读期间按钮禁用并显示“试听中…”，完成后恢复；失败时用 SnackBar 显示 `lastError`（为空时用固定文案）。试听不经过 `play()`，不改队列索引。
- 失败区：`degraded`、`skippedCount > 0` 或 `lastError` 非空时显示，包含“语音引擎无响应/播报异常”、已跳过条数与最近错误，并提供“重试”调用 `retry()`（不可用时由服务重新初始化）；重试仍失败时用 SnackBar 提示。
- 不可用视图：保留说明与“重试”，补充“设置 → 无障碍（辅助功能）→ 文字转语音”的系统路径文字；重试走原有重新初始化流程。
- 关闭：关闭按钮先 `await _service.close()` 停止当前朗读，再 `pop()`；`dispose()` 仍负责释放引擎。
- 布局：整段内容包在 `SingleChildScrollView` 中，新增行不会撑破底部面板；原有播放/暂停、上一条/下一条、三档语速、单列表循环、进度与 `widget.items` 快照全部保留。
- 验证：`flutter analyze` 0 issue；`flutter test` 43 个全部通过。
