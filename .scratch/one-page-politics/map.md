# 一页纸背诵应用（one_page_politics）

## Destination

一个装到 Android 手机上、完全离线可用的 Flutter 应用 `one_page_politics`：按四 Tab 规格完成“一页纸刷眼、反射场四类微训练、工具箱、作战室”，题库由可热更新的 Markdown 协议驱动，三态进度与标星保存在本机；先在 `medium_phone` 模拟器跑通，必要时真机验证。

## Notes

- 产品规格见 [brief.md](brief.md)（用户原始输入，语义基线）；实施基线见 [spec.md](spec.md)（2026-11-20 冻结，任务单 10）。原草案留在 [proposals/dev-spec-draft.md](proposals/dev-spec-draft.md)。
- 语料：`srt/` 下 5 份 SRT；整理文档《澄潇宇考研政治主张整理.md》。其中“一页纸内容”是依据三小时带背视频逐条还原的版本，不是原始 PDF。用户已确认不再有新版一页纸文件，现有语料即完整集合；一页纸内容仍走 Markdown，工具箱 v1 为 `const` 数据。
- 本机基线：Flutter 3.50.0 stable、Dart 3.14.0、OpenJDK 25.0.5.1（含 jlink，Flutter 构建 JDK）、`ANDROID_HOME=/home/qxyhappy/develop/Android/Sdk`、AVD `medium_phone`、当前无真机连接、磁盘约 1 TB 空闲。
- 已定事实：内容用专用 Markdown 协议维护；条目身份在导入时计算并冻结（源文件改字视为新条目，长按热修不改 id）；首版按四 Tab 全量交付；验证先模拟器，必要时真机。
- 定位：短期辅助工具，服务至 2026-12-19 初试；语料已完备，不再有新增内容。范围以 [spec.md](spec.md) 为准，不为长期维护、未来内容同步、进度备份体系投入。
- 技术约束（详见 brief）：Material 3、Android 离线、provider / path_provider / shared_preferences / file_picker / flutter_tts；禁 build_runner、freezed、json_serializable、isar、drift、riverpod_generator；手写序列化；图表用 CustomPainter；滑卡用原生手势。
- 工具链：不得静默安装、下载或升级 JDK、Android SDK/NDK/CMake、Gradle 发行包等；缺组件先询问并记录（见 `AGENTS.md`）。
- 工作方式：本图只收敛决策与原型验证；spec 冻结、M1 原型验证后即 handoff。M2/M3 是实现阶段，不在地图内推进，也不再拆成 wayfinder 任务单。
- Handoff：实施基线为 [spec.md](spec.md)；M1 原型（Tab1/Tab3/seed/解析器）已在 `medium_phone` 验证。后续实现按 spec 的 Milestone 2/3 独立推进。
- 实施状态：M1–M3 已按 spec 完成并验证（debug APK）；地图只保留决策索引，不再跟踪实现细节。
- 会话技能：`grilling`、`domain-modeling`；Flutter 相关任务按需读 `flutter-*`、`dart-*`、`adaptive`、`edge-to-edge`、`android-cli` 技能。术语见根目录 `GLOSSARY.md`。

## Decisions so far

<!-- 每关闭一张 ticket，追加一行：- [标题](issues/NN-slug.md)：一句话结论 -->

- [开发文档审定：冻结实施基线](issues/10-dev-spec-confirmation.md)：草案经七项裁定后冻结为 [spec.md](spec.md)；正交标星、冻结 id、仅增量合并（无新版文件）、仅错误回写、M1 全量 seed、工具箱 const、重置仅内容。
- [生成 seed 题库与工具箱种子数据](issues/07-seed-content.md)：549 条（马原 142、史纲 199、思修 33、新思想 114、时政 61；mapping 484、trueFalse 55、pair 10），解析 0 error；78 条 `#配对` 供 4×4、201 条 `#二轮`，聚合卡留在 Tab1；工具箱 const 数据与解析器已落。
- [Flutter 3.50 / OpenJDK 25 / AGP 与 medium_phone 模拟器基线](issues/02-toolchain-baseline.md)：构建 JDK 为 OpenJDK 25（含 jlink；早期 JBR 25 缺 jlink 的问题已由系统切换解决）、Gradle 9.5 / AGP 9.3.1；debug APK 构建、安装与启动通过；确立“不静默安装工具链”规则。
- [离线中文 TTS 的可行性与降级方案](issues/01-tts-offline.md)：flutter_tts 接入；模拟器队列、暂停、进度通过，真机音频留查；不可用时安装提示与重试。
- [MD 协议、卡片类型与内容指纹](issues/03-md-protocol.md)：协议冻结在 spec §6–§7；解析、导出、合并实现并测试。
- [复习会话算法与三态调度](issues/04-session-algorithm.md)：spec §8–§9/§11.1；三态 + 正交标星，判错回写模糊。
- [四类微训练与一页纸条目的映射](issues/05-microtraining-mapping.md)：四模式实现；78 条 `#配对`；回写与测试通过。
- [作战室的数据模型与交互](issues/06-war-room.md)：双计时、遍数、计分/折线图、导入导出/清空实现并冒烟。
- [关键交互原型：遮罩揭晓、滑卡、配对](issues/08-interaction-prototype.md)：M1 构建承担原型；独立原型取消。
- [验收清单与交付方式](issues/09-acceptance.md)：analyze 0、20 tests、debug APK、模拟器全流程；release 签名 out of scope。

## Not yet specified

- 无。地图已 handoff；实现按 spec 独立完成。

短期定位下，进度备份、可访问性、应用元数据、时政时效标记与扩展统计已移入 Out of scope；首次启动空态、源文档同步由 spec 解决。

## Out of scope

- 进度备份与恢复：短期工具只导出内容，不导出进度；数据丢失的恢复路径是重新导入/恢复内置一页纸。
- 可访问性完整适配：系统字体缩放、色弱模式、TalkBack 语义；只保证基本点击区域与可读字号。
- 应用元数据与分发：图标精修、版本号策略、应用商店、签名分发、自动更新。
- 时政条目的时效标记与更新节奏：考试窗口内按现有语料使用。
- 扩展统计：连续天数、正确率曲线等；只保留遍数与真题分数。

- 多用户、账号体系、云同步、后端服务。
- iOS 与桌面端的正式支持与验收（Flutter 代码可跨平台，但不作为目标）。
- SM-2/FSRS 等间隔重复算法、复习债务、到期队列。
- 通用题库导入（Anki `.apkg`、任意第三方 Markdown、Excel）。
- 多科目（英语、专业课）内容与界面。
- 批量/可视化题库编辑器（内容在 Markdown 文件中维护）；单条长按热修在范围内。
- 应用商店发布、签名分发、自动更新。
- 在线题库、爬虫、时政自动抓取。
- 复杂图表库、动画库、代码生成器。
