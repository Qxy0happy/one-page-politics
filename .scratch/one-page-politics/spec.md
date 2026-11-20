# one_page_politics 实施基线（冻结版）

> 状态：2026-11-20 由任务单 10 冻结。
> 定位：短期辅助工具，服务至 2026-12-19 初试；语料已完备，不再有新增内容。实现优先可用的 APK，不为长期维护、未来内容同步或进度备份体系投入。
> 上位文档：`brief.md`（产品语义基线）、`GLOSSARY.md`（术语）。
> 来源：`proposals/dev-spec-draft.md`（用户提供的草案）＋ 任务单 10 的七项裁定。
> 本文件是编码代理的唯一实施基线。与草案冲突时以本文件为准；与 `brief.md` 的产品语义冲突时，先回到任务单确认，不得自行取舍。

## 0. 交付目标

一个安装到 Android 手机、完全离线可用的 Flutter 应用 `one_page_politics`：

- 四个 Tab：一页纸刷眼、反射场四类微训练、工具箱、作战室。
- 一页纸内容由 `assets/default_sheet.md` 内置，并可通过导入 `.md` 增量更新。
- 三态进度、标星、个人备注、真题记录保存在本机。
- 先在 `medium_phone` 模拟器跑通；TTS 与文件导入在模拟器受限时，按任务单 01/09 的结论延到真机验证。
- 初试日期为 2026-12-19；Milestone 1 完成后应能打出 APK 装机使用。

## 1. 不可动摇的产品约束

1. 不是传统 Anki，不引入 SM-2/FSRS、到期队列、复习债务；不要求文字默写。
2. 核心是高频刺激与条件反射：单手低摩擦，每天 15–30 分钟。
3. 完全离线：无后端、无登录、无网络请求；飞行模式下全部功能可用（TTS 依赖系统离线语音数据）。
4. 内容与代码分离：一页纸内容由 Markdown 协议维护；工具箱内容在 v1 为 `const` 数据（见 §10），不因内容更新而改解析器。
5. 不惩罚中断：没有红色逾期、没有连续天数惩罚、没有强制每日配额。

## 2. 技术约束

- Flutter 3.x、Dart 3、Material 3，Android 优先。
- 依赖只允许：`provider`、`path_provider`、`shared_preferences`、`file_picker`、`flutter_tts`。Flutter 3.50 起 Material 组件由 `material_ui` 包提供，随模板引入，不计入自选依赖；`package:flutter/material.dart` 已弃用。
- 禁止 `build_runner`、`freezed`、`json_serializable`、`isar`、`drift`、`riverpod_generator`；所有 Model 手写 `toJson` / `fromJson` / `copyWith`。
- 禁止图表库；折线图用 `CustomPainter`。滑卡用原生 `GestureDetector` / `AnimatedContainer`。
- 版本组合：Gradle 9.5.0、AGP 9.3.1、Kotlin 2.4.20（Flutter 3.50 模板）；构建 JDK 使用含 `jlink` 的 OpenJDK 25（本机 `/usr/lib/jvm/java-25-openjdk`）；Temurin 17 已删除，不再保留备用。`compileSdk` / `minSdk` / `targetSdk` 保持 `flutter.*` 默认值。Gradle 发行包的网络路径见 `research/toolchain-baseline.md`。
- 工具链安装：禁止静默安装、下载或升级 JDK、Android SDK/NDK/CMake、Gradle 发行包等；缺组件时构建失败并先询问。`app/android/gradle.properties` 已设置 `android.builder.sdkDownload=false` 与 `org.gradle.java.installations.auto-download=false`；详细规则见根目录 `AGENTS.md`。
- `android/app/src/main/AndroidManifest.xml` 必须包含：

```xml
<queries>
  <intent>
    <action android:name="android.intent.action.TTS_SERVICE" />
  </intent>
</queries>
```

- release 清单不声明 `INTERNET` 权限；debug/profile 可保留 Flutter 默认调试权限。
- 不申请存储权限：导入/导出走 `file_picker` 的 SAF 接口。
- UI 语言为简体中文；日期格式化手写，不引入 `intl`。

## 3. 术语与状态

| 术语 | 含义 | 不用 |
|---|---|---|
| 一页纸 | 可逐条刷眼的考点集合 | 题库、笔记、提纲 |
| 条目 | 一条可独立复习的最小内容单元 | 卡片、题目、知识点 |
| 帽子 | “核心、根本、首要、本质、出发点”等限定词对应的固定结论 | 关键词、题眼 |
| 墓碑词 | 命题人反复用来制造干扰项的敏感词 | 陷阱词、敏感词 |
| 口诀 | 谐音、首字母或场景化短句，只作辅助 | 顺口溜、模板 |
| 大题框架 | 五向展开、十二＋一角度、戴帽子句式、三位一体、抄材料等骨架 | 模板、范文 |
| 三态 | 未看 / 眼熟 / 模糊 | 会 / 不会 |
| 标星 | 与三态正交的重点标记，可叠加在任一状态上 | 第四态 |

## 4. 数据模型

### 4.1 枚举

```dart
enum Subject { mayuan, shigang, sixiu, xinsixiang, shizheng }

enum CardType { mapping, trueFalse, pair }

enum StudyStatus { unseen, familiar, fuzzy }

enum StatusFilter { all, starred, fuzzy, round2 }
```

枚举名是 `id` 与 JSON 的一部分，不得重命名；显示名与 UI 文案可以修改。

科目别名（用于 Markdown 标题匹配）：

| 枚举 | 显示名 | 可匹配别名 |
|---|---|---|
| `mayuan` | 马原 | 马原、马克思主义基本原理 |
| `shigang` | 史纲 | 史纲、中国近现代史纲要 |
| `sixiu` | 思修 | 思修、思想道德与法治、思想道德修养与法律基础 |
| `xinsixiang` | 新思想 | 新思想、习近平新时代中国特色社会主义思想 |
| `shizheng` | 时政 | 时政、形势与政策、当代 |

### 4.2 KnowledgeItem

```dart
class KnowledgeItem {
  final String id;              // 冻结身份，格式 <subject>.<cardType>.<8位小写十六进制>
  final Subject subject;
  final String chapter;
  final CardType cardType;

  final String prompt;          // mapping: 帽子/题干；trueFalse: 待判断陈述；pair: A 的名称
  final String answer;          // mapping: 结论；trueFalse: 可空；pair: B 的名称
  final String explanation;     // 解析，可空
  final bool? isTrue;           // 仅 trueFalse 有效
  final String mnemonic;        // 口诀，可空

  final String? pairAFeature;   // 仅 pair 有效，A 的核心特征
  final String? pairBFeature;   // 仅 pair 有效，B 的核心特征

  final List<String> tombstoneWords;
  final String sourceNote;      // 来源注记/“原文如此”，不是个人备注
  final bool isRound2Focus;
  final bool isMappingDrill;     // 4×4 配对训练专用；由行尾 #配对 标记

  final StudyStatus status;
  final bool isStarred;
  final String userNote;
  final bool isCustomEdited;    // 仅内容字段被用户改过时为 true
  final int reviewCount;

  KnowledgeItem copyWith({...});
  Map<String, dynamic> toJson();
  factory KnowledgeItem.fromJson(Map<String, dynamic> json);
}
```

字段规则：

- `id` 一旦生成即冻结。长按热修题干、答案、口诀均不改 `id`。
- `isCustomEdited` 只在用户修改 `prompt`、`answer`、`explanation`、`mnemonic`、`pairAFeature`、`pairBFeature`、`sourceNote`、`isRound2Focus` 时置 `true`；修改 `status`、`isStarred`、`userNote` 不置位。
- `reviewCount` 在 Tab1 点击三态按钮、Tab2 每次判题时加一；被动浏览、TTS 朗读、标星不加。
- `trueFalse` 的 `answer` 允许为空；UI 用 `isTrue` + `explanation` 展示判定与解析。
- `pair` 的 `prompt` / `answer` 只存名称；特征存 `pairAFeature` / `pairBFeature`，避免 UI 层重复做字符串拆分。
- `copyWith` 必须保留 `id`，除非显式传入新 id（仅导入/导出工具使用）。

### 4.3 ExamRecord

```dart
class ExamRecord {
  final String id;
  final String title;           // 如“2026 真题”“模拟卷 1”
  final DateTime date;          // 考试日期
  final DateTime createdAt;     // 记录创建时间，用于同日排序
  final int singleCorrect;      // 0..16
  final int multiCorrect;       // 0..17
  final List<String> linkedWrongItemIds;
  final String note;

  int get totalScore => singleCorrect + multiCorrect * 2;
}
```

校验：`title` 非空；`singleCorrect` 在 0–16；`multiCorrect` 在 0–17；总分 0–50。`id` 用 `DateTime.now().microsecondsSinceEpoch` 加随机后缀生成，不引入 `uuid` 依赖。

### 4.4 工具箱数据

`toolbox_models.dart` 定义 `TombstoneCategory`、`ChoiceStrategy`、`BigQuestionAngle`、`FrameworkCard`、`SubjectPocketCard`、`ThreeInOneTemplate`；`toolbox_seed_data.dart` 用 `const` 列表填充真实内容。v1 不从 Markdown 读取工具箱。

## 5. 持久化

- `StorageService` 使用 `path_provider` 的 `getApplicationDocumentsDirectory()`：
  - `knowledge_items.json`
  - `exam_records.json`
- `shared_preferences` 保存：主题模式、两个计时器的状态、一页纸遍数与最后日期、上次导入摘要。
- JSON 外层带 `schemaVersion`：

```json
{ "schemaVersion": 1, "items": [ ... ] }
```

- 写入采用原子替换：写 `<file>.tmp` → flush → rename；保留 `<file>.bak`。读取失败时先尝试 `.bak`；两者都失败则把损坏文件改名为 `<file>.corrupt-<timestamp>`，并以内置 seed 启动，同时在 UI 提示。
- 未知 `schemaVersion` 不静默丢弃数据：拒绝加载并提示用户先导出/备份。
- 计时器不依赖后台服务：保存 `endAt`（epoch ms）或 `remainingMs`，`Timer.periodic` 只负责刷新显示；应用回到前台时按墙钟重算。
- 不做数据库、不做加密、不做云备份。

## 6. Markdown 协议

### 6.1 总体

- UTF-8；LF 或 CRLF 均可。
- `# <科目>` 切换当前科目；`## <章节>` 切换当前章节；空行、非 `- ` 开头行忽略并计入 `ignoredLines`。
- 每条条目一行，以 `- ` 开头；不支持嵌套列表。
- 行尾可带 `#二轮` 或 `#配对`，解析前剥离并分别置 `isRound2Focus` / `isMappingDrill`；两个标记可同时出现。
- 用 `|` 分隔主文与扩展字段；`|` 为保留字符，正文中不得出现。
- 扩展字段格式 `键: 值`，键为 `口诀`、`解析`、`墓碑词`、`备注`、`id`；未知键记警告并忽略；重复键报错。
- `墓碑词` 用 `,`、`，`、`、` 分隔。
- `备注` 映射到 `sourceNote`，不得覆盖 `userNote`。

### 6.2 行类型

| 前缀 | cardType | 主文拆分 | 字段 |
|---|---|---|---|
| `[配对]` | `mapping` | `题干 == 结论` | `prompt` / `answer` |
| `[对]` | `trueFalse` | 整段为陈述 | `isTrue = true` |
| `[错]` | `trueFalse` | 整段为陈述 | `isTrue = false` |
| `[对比]` | `pair` | `A（A特征） <> B（B特征）` | `prompt` / `pairAFeature` / `answer` / `pairBFeature` |

- `[配对]` 必须且只能有一个 `==`；两侧非空。
- `[对比]` 必须且只能有一个 `<>`；两侧用全角 `（）` 或半角 `()` 包裹特征。解析器取**最后一个左括号**与其匹配的右括号：括号内为特征，括号前为名称；名称与特征均非空。名称中若还含括号，保留在名称中并记警告。没有括号时，整段作为名称、特征为空，并记警告；该条目在双胞胎训练中跳过，不崩溃。
- `[对]` / `[错]` 的正文不再按 `==` 或 `<>` 拆分。
- 未识别前缀、空主文、缺少分隔符、科目/章节缺失：均报错，带行号，整次导入失败。

### 6.3 标题匹配

- `# ` 后的文本必须命中且只命中一个科目别名；否则报错。
- `## ` 后的文本为章节名；空章节名记为“未分章”。
- 第一个 `#` 之前出现 `- ` 条目：报错。
- `###` 等更深标题按普通非条目行忽略；seed 生成时必须压平为两级。

### 6.4 身份与规范化

- 导入时若无 `id:`，计算：

```text
id = "<subject>.<cardType>." + fnv1a32(normalize(subject + "|" + cardType + "|" + prompt))
```

- `normalize` 的确定性规则（不引入 Unicode 依赖）：
  1. 全角 ASCII（U+FF01–U+FF5E）转半角；
  2. 全角空格 U+3000 转半角空格；
  3. 中文标点映射为 ASCII：`，。；：！？（）“”‘’、`；
  4. ASCII 字母转小写；
  5. 连续空白折叠为一个空格；
  6. 去首尾空白；
  7. 不删除标点，不做同义词替换。
- FNV-1a 32 位，结果取 8 位小写十六进制，左侧补零。实现固定，跨平台一致。
- `id:` 字段用于导出/再导入，格式必须为 `<subject>.<cardType>.<8hex>`，且前缀与解析出的科目/类型一致；不一致报错。
- 同一文件内重复 `id` 报错；不同条目规范化后题干相同但 `id` 不同，记“疑似重复”警告，不自动合并。
- `prompt` 编辑后 `id` 不变；导出时写入 `id:`，保证往返。

## 7. 导入、导出与重置

### 7.1 导入

- 入口：Tab4“导入新版一页纸 (.md)”，`file_picker` 选择 `.md`。
- 用户已确认不再有新版一页纸文件，现有语料即完整集合；因此导入只做**增量合并**，不提供“删除缺失条目/整库替换”模式。
- 流程：
  1. 读取文件，完整解析到暂存列表；任一语法错误则展示行号与原因，原数据不变。
  2. 以 `id` 匹配现有条目。无 `id:` 的导入按 §6.4 现算 id；因此题干一旦改动就会算出新 id，旧条目保留并计入 `missing`。这是“源文件改字视为新条目”的预期行为；只有带 `id:` 的导出/再导入才会按 id 命中并更新题干。
  3. 命中且 `isCustomEdited == false`：更新内容字段；保留 `status`、`isStarred`、`reviewCount`、`userNote`、`id`。
  4. 命中且 `isCustomEdited == true`：默认保留本地内容（题干、答案、解析、口诀、特征、来源注记、二轮标记），只报告冲突；用户在导入弹窗勾选“覆盖手动编辑内容”时，用导入内容替换并置 `isCustomEdited = false`。进度字段始终保留。v1 用整条 `isCustomEdited` 做保守保留，不做字段级合并；字段级合并留到 v1.1。
  5. 未命中的导入条目：新增，`status = unseen`、`isStarred = false`、`reviewCount = 0`、`userNote = ""`。
  6. 现有条目未出现在导入文件中：保留，计入 `missing`；不删除。
  7. 汇总：新增、更新、保留本地修改、缺失、忽略行、疑似重复；用户确认后写入。
  8. 写入前备份当前 JSON；写入失败则恢复备份并提示。
- 导入不改变筛选、主题、计时器。
- 解析器是纯 Dart，不依赖第三方 Markdown 扩展；单元测试覆盖全部行类型与错误路径。

### 7.2 导出

- 生成可再次导入的完整 `.md`：
  - 按科目、章节分组；
  - `mapping` 写 `[配对] 题干 == 结论`；`trueFalse` 按 `isTrue` 写 `[对]` / `[错]`；`pair` 写 `[对比] A（A特征） <> B（B特征）`；
  - 每条写入 `id:`、`口诀:`、`解析:`、`墓碑词:`、`备注:`、`#二轮` / `#配对`（有则写）；
  - 不导出 `status`、`isStarred`、`reviewCount`、`userNote`（这些是本机进度，不是内容）。
- 使用 `FilePicker.platform.saveFile` 写 bytes；失败时提示，不静默丢内容。
- 导出后再导入必须按 `id` 命中同一条目，不产生重复。

### 7.3 重置

- “恢复内置一页纸”：用内置 `assets/default_sheet.md` 重建内容。
  - 命中 `id` 的条目：替换内容，保留三态、标星、`reviewCount`、`userNote`，`isCustomEdited = false`。
  - 本地有、seed 没有的条目：删除。
  - seed 新增的条目：以 `unseen` 加入。
  - 执行前二次确认，提示“本地新增条目会被删除，建议先导出”。
- “清空全部数据”：删除两个 JSON 与相关 prefs，重新载入 seed；所有进度、标星、备注、真题记录、计时器、遍数归零；二次确认。
- 两个入口分开，不得合并成一个无提示的按钮。

## 8. Tab 1：一页纸

### 8.1 顶部吸顶区

- 路径栏：吸顶显示当前路径（`全部`、`马原`、`马原 › 1.1`）；点按打开底部目录树。
  - 树按“科目 → 章节”展开；仅含“未分章”的科目（思修、新思想、时政）隐藏“未分章”层，直接以卡片类型（配对/判断/对比）作为子节点。
  - 每个节点显示条目数与三态进度（眼熟、模糊）；进度按全部条目统计，不受状态芯片或搜索词影响。点行选中并收起，点尾部箭头只展开/收起。
  - 选择结果写入本地，冷启动恢复；路径失效时先回退到科目，再回退到全部。
- 状态芯片：全量 / 仅标星 / 仅模糊 / 二轮冲刺；计数按“当前路径 + 搜索词”统计，不含状态本身。
  - 仅标星：`isStarred == true`；
  - 仅模糊：`status == fuzzy`；
  - 二轮冲刺：`isRound2Focus == true`，不再叠加“史纲+新思想+时政帽子”的隐式规则；该规则由 seed 标注实现。
- 搜索：折叠图标展开，200 ms 防抖；只在当前路径内匹配 `prompt`、`answer`、`explanation`、`mnemonic`、`tombstoneWords`、`sourceNote`、`userNote`，不区分 ASCII 大小写。
- 遮罩模式开关：全局；切换时清空已揭晓集合。

过滤条件之间为 AND。无结果时显示“没有符合条件的条目”；若当前不在“全部”，提供“在全部中搜索”（保留搜索词、清空路径）。

### 8.2 条目卡片

- `mapping`：题干 → 结论。
- `pair`：A / B 两行，各显示名称与特征；名称常显，特征可遮罩。
- `trueFalse`：左侧红/绿“错/对”徽章；徽章与解析可遮罩。
- `mnemonic` 非空时显示蓝色小胶囊，点击展开；遮罩模式下，主答案未揭晓前不显示胶囊内容。
- 遮罩：轻点遮罩块单独揭晓/重新遮盖；揭晓状态是临时的，切换筛选或重新加载后清空。遮罩不改变数据。
- 底部操作栏：眼熟 / 模糊 / 标星。
  - 眼熟：`status = familiar`；再次点击回到 `unseen`。
  - 模糊：`status = fuzzy`；再次点击回到 `unseen`。
  - 标星：切换 `isStarred`，不改变 `status`。
  - 三态按钮点击时 `reviewCount++`；标星不增加。轻震动反馈。
- 长按条目打开 BottomSheet：
  - 可编辑 `prompt`、`answer`、`explanation`、`mnemonic`、`pairAFeature`、`pairBFeature`、`sourceNote`、`isRound2Focus`、`userNote`；
  - 不可改 `subject`、`cardType`、`id`；
  - 保存校验：`prompt` 非空；`mapping` 的 `answer` 非空；`pair` 的名称与特征非空；`trueFalse` 不显示 `answer` 编辑框；
  - 内容字段变化时置 `isCustomEdited = true`；仅 `userNote` 变化不置位；
  - 保存后立即写 JSON 并刷新列表。

### 8.3 空态

- 一页纸为空：“一页纸为空。请到作战室导入 `.md`，或恢复内置一页纸。”
- 筛选为空：“没有符合条件的条目。试试切换路径、状态或清除搜索。”
- 当前路径搜索无命中：显示搜索词与路径，提供“在全部中搜索”（保留搜索词、清空路径）和“清除搜索”。

### 8.4 TTS

- 右下角悬浮按钮打开底部迷你播控条；按当前过滤列表顺序朗读。
- 队列：朗读 `prompt` → 停顿 1.5 秒 → 朗读 `answer` → 下一条。
- 控件：播放/暂停、上一条/下一条、语速 1.0x / 1.25x / 1.5x、单列表循环开关。
- 关闭播控条即停止朗读；切换筛选后从新列表当前项继续。
- 朗读不受遮罩影响（遮罩是视觉训练，TTS 是磨耳朵）。
- 启动时检测中文语音可用性；不可用时禁用入口并提示“系统未安装中文离线语音”，不阻塞其他功能。具体检测与引擎处理按任务单 01 的结论。

## 9. Tab 2：反射场

### 9.1 入口与选题

- 四张入口卡：是非滑卡、帽子配对、双胞胎辨析、政经计算器；显示可用题量与“开始”。
- 每局题量：是非 15、双胞胎 15、配对 16（4 批 × 4）、计算器 15。
- 题池为全库，不受 Tab1 筛选影响；按 `cardType` 取卡。配对模式只消费 `isMappingDrill == true` 的自洽单条对应；若旧数据没有任何 `#配对` 标记，回退到全部 mapping 卡。碎片与聚合卡仍留在 Tab1，不进入 4×4。
- 优先级：
  1. `status == fuzzy` 或 `isStarred == true`；
  2. `status == unseen`；
  3. `status == familiar`。
- 同优先级内按 `reviewCount` 升序，再随机打乱。
- 题量不足时用现有题量开一局；配对少于 4 条时禁用入口，提示“至少需要 4 条配对条目”。
- 不持久化未完成的会话；离开即结束，已写入的判题结果保留。

### 9.2 是非滑卡

- 大卡片堆叠，左滑判错、右滑判对；阈值：水平位移超过卡片宽度 25%，或速度超过 800 px/s。底部同时提供大号“错 / 对”按钮。
- 判对：`reviewCount++`，播放退出动画，下一张。
- 判错：`status = fuzzy`，`reviewCount++`，卡片原地展开解析，墓碑词用警示红高亮；该条目在本局队尾再出现一次，最多回炉一次。
- 回炉集合按条目 id 记录；第二次判错不再回炉，直接下一张。
- 本局结束显示：答对、答错、回炉次数；提供“再来一局”和“返回”。

### 9.3 帽子配对

- 单屏左栏 4 个 `prompt`、右栏 4 个打乱的 `answer`；只做点击配对，不做拖拽连线。
- 先点左项，再点右项：
  - 匹配：两项变绿并淡出；该条目 `reviewCount++`。
  - 不匹配：短时标红、`HapticFeedback.mediumImpact()`、取消选中；该左项 `status = fuzzy`（同一条目在本批只记一次）。
- 4 组全消后进入下一批；共 4 批。
- 同一批内避免重复 `prompt` 或重复 `answer`。

### 9.4 双胞胎辨析

- 每条 `pair` 取 A/B 两侧的名称与特征；随机选一侧的特征作为题干：
  “下列哪一项的核心特征是「<特征>」？”
- 下方两个大按钮：A 名称 / B 名称。
- 判定：
  - 正确：`reviewCount++`；
  - 错误：`status = fuzzy`，`reviewCount++`。
- 判定后同屏展示 A/B 的完整名称、特征与口诀；下一题。
- 特征为空的条目跳过，并记录内容警告；不崩溃。

### 9.5 政经计算器

- 不依赖 Markdown；纯算法生成，题型可切换“A / B / 混合”，默认混合。
- 题型 A（利润）：
  - 从合法组合中选 `V`（万元）、`C:V`、`m'`，保证 `C`、`M` 为整数；
  - 题面给出总投资 `C+V`、有机构成、剩余价值率，求利润 `M`；
  - 答案输入数字，容差 0.01；折叠提示：先求 `V = 总投资 / (1 + C:V)`，再求 `M = V × m'`。
- 题型 B（剩余价值率）：
  - 选总工时 `T`、必要劳动时间 `V_t`，`S = T - V_t`；
  - 绝对方式：剩余时间增加 `X` 小时，求新 `m' = (S + X) / V_t`；
  - 相对方式：总工时不变，剩余时间变为 `Y`，求新 `m' = Y / (T - Y)`；
  - 保证分母非零、答案可解释；容差 0.1 个百分点；展示算式。
- 计算器不写回任何条目状态，只计入本局统计。

## 10. Tab 3：工具箱

顶部双段：`选择题兵法` / `大题与抄材料`。内容全部来自 `lib/data/toolbox_seed_data.dart` 的 `const` 数据，禁止占位符；数据来源为《澄潇宇考研政治主张整理.md》的方法与附录部分。

### 10.1 选择题兵法

- 单/多选防错速览卡（可折叠）：
  - 单选：读题画圈、先错后对夹逼、三项连连看、举例代入、反驳自己；
  - 多选：疑罪从无、找错不找对、每排必有理、含正反两面仍选。
- 墓碑词红黑榜：
  - 顶部安全绿卡片固定置顶“白名单与反例警示区”：有利于/有助于沾边就选；根本/唯一/一切/直接并非见字就错，附具体反例。
  - 下方 10 类墓碑词（绝对化、“一”字类、过度具体、简单化/加和、夸张程度、时态陷阱、唯心、范围错配、数量/质量、范畴不统一），每类显示典型词、处理策略、边界说明。
  - 实时搜索：匹配类型名、典型词、策略文本。

### 10.2 大题与抄材料

- 十二＋一角度交互网格：党、理论、制度、路线、历史、文化、现实、成就、人民、环境、需求、未来、问题；点击展开一句话用法。
- 三位一体句式转换器：输入短词，实时生成：
  - 原因：“<词>是……的必然要求／必然选择”；
  - 意义：“有助于……”；
  - 措施：“我们要……”。
  输入为空时禁用；提供“高质量发展”“制度型开放”等快捷示例；每段可复制到剪贴板。
- 通用框架卡片：五向展开、戴帽子句式（红字标注避开最高级词）、抄材料铁律（四不抄、降重四法、定位法、首尾点题＋分段不分点）。
- 分科目口袋卡（横向 Chip）：马原、新思想、思修、史纲、当代；内容与语料一致。
- 所有文本保持原表述；ASR 不确定处在数据中以注释或 `sourceNote` 标注，不在 UI 中擅自补全。

## 11. Tab 4：作战室

### 11.1 双计时器与遍数

- 两个独立倒计时卡片：“解题方法 30min”“一页纸 30min”。
- 状态：`idle / running / paused / completed`；支持开始、暂停、重置。
- 用墙钟时间戳计算剩余时间；应用切到后台继续计时，回到前台重算；重启后恢复。
- 到 0：震动一次，显示“今日政治时间已够，请把精力留给数学/英语/专业课”，计时器停在 0。
- 若应用关闭期间到期：下次打开时标记 completed 并显示提示，不补震动。
- “一页纸已过遍数”大字计数器 + “+1 记一遍”：手动增加，记录最后日期；不自动累计。

### 11.2 真题/模拟卷计分

- 记录字段见 §4.3；表单：
  - 套卷名称（必填）；
  - 日期（默认今天）；
  - 单选对题数 0–16；
  - 多选对题数 0–17；
  - 备注；
  - 关联错题：可搜索条目并多选。
- 实时显示总分：`单选 + 多选 × 2`，满分 50。
- 保存后，关联条目的 `isStarred = true`，保留原 `status`。
- 关联 id 在当前一页纸中找不到时，记录保留该 id，列表显示“条目已删除”，不崩溃、不静默清除。
- 记录列表按日期倒序；支持编辑与删除（删除二次确认）。
- 折线图用 `CustomPainter`：
  - 横轴按考试日期升序，同日按 `createdAt`；
  - 纵轴 0–50；
  - 35 分琥珀色虚线、40 分绿色虚线；
  - 空态：“还没有记录，先记一套卷。”
- 图表与列表同页；不做多科目分层。

### 11.3 导入、导出、重置

- 导入：见 §7.1；导入前展示摘要，确认后写入；失败不动原数据。
- 导出：见 §7.2。
- 查看 MD 语法规范：只读弹窗，展示 §6 的语法摘要与一条示例；可复制示例。
- 恢复内置一页纸 / 清空全部数据：见 §7.3。
- 数据管理区显示当前条目数、分科目计数、真题记录数。

## 12. 里程碑与验收

### 12.1 Milestone 1：核心闭环与数据基建

交付：

- 项目结构、主题 Tokens、全部 Model、`MdParserService`、`StorageService`。
- `assets/default_sheet.md`：**全量**提取语料第三部分（215 条候选行，拆分多义项后更多），覆盖 5 科目与 3 种题型；不得以 40 条样张代替。全量 seed 的具体提取由任务单 07 执行，M1 消费其产物。
- Tab 1（遮罩、筛选、搜索、三态、标星、长按热修、空态）。
- Tab 3（全部兵法、墓碑词、大题框架、13 角度、三位一体、分科目口袋卡）。
- 单元测试：解析器全部行类型与错误路径、id 规范化、合并的新增/更新/保留本地/缺失、存储原子写入与损坏恢复。

验收：

- `flutter analyze` 0 error。
- `flutter test` 全部通过。
- `flutter build apk --debug` 成功，APK 路径 `build/app/outputs/flutter-apk/app-debug.apk`。
- `medium_phone` 模拟器手动走通：首次启动、科目/状态筛选、遮罩揭晓、三态与标星、长按保存、Tab3 全部折叠与搜索。
- seed 统计报告：总数、分科目、分类型、重复 id、忽略行；与语料条数对账。

### 12.2 Milestone 2：反射训练场

交付：

- Tab 2 四种模式、选题优先级、回炉上限、配对批处理、双胞胎拆分与降级、计算器两种题型与混合模式。
- 判题回写：判错写 `fuzzy`；判对只加 `reviewCount`；标星正交不被覆盖。
- 单元测试：选题优先级、题量不足、回炉只一次、配对错误只标一次、计算器整数与容差。

验收：

- `flutter analyze` / `flutter test` / `flutter build apk --debug` 通过。
- 模拟器手动走通四种模式各一局，检查状态回写与结算。

### 12.3 Milestone 3：作战室与 Android 能力

交付：

- Tab 4：双计时器、遍数、计分记录、CustomPainter 折线图、错题联动标星、导入/导出/重置、语法说明。
- Tab 1 的 TTS 播控条与离线语音检测；`AndroidManifest.xml` 的 TTS `<queries>`。
- 单元测试：计时器墙钟恢复、导入原子性、导出再导入按 id 命中、重置保留匹配进度。

验收：

- `flutter analyze` / `flutter test` / `flutter build apk --debug` 通过。
- 模拟器手动走通：计时器开始/暂停/重启恢复、记录一套卷并标星、导出后重新导入不重复、重置后进度保留。
- TTS：模拟器无中文语音时验证禁用与提示；有真机时验证朗读、暂停、上下条、语速、循环。
- 真机最小清单按任务单 09 执行。

### 12.4 通用禁止

- 不使用 `build_runner` 或任何代码生成。
- 不以“占位数据”交付；Tab3 与 seed 必须是真实内容。
- 不引入第六个依赖；不以版本冲突为由替换为图表库/数据库。
- 不在 M1 用 40 条样张冒充全量 seed。

## 13. 未决依赖与范围外

### 13.1 已关闭的任务单

- 任务单 01：TTS 已实现并验证队列、暂停与降级；真实音频留真机检查，见 `research/tts-offline.md`。
- 任务单 02：工具链已冻结为 OpenJDK 25 / Gradle 9.5 / AGP 9.3.1；见 `research/toolchain-baseline.md`。
- 任务单 08：M1 可安装构建承担交互原型职责；独立原型取消。
- 任务单 09：验收由 §12 执行；`flutter analyze` 0、20 个测试、debug APK 与模拟器全流程通过。

### 13.2 仍在地图“Not yet specified”的雾

- 无。地图已 handoff；实现按本文件独立完成。

已由本文件解决、不再作为雾：源文档同步（用户确认不再有新版文件，现有语料即完整集合）；首次启动空态（§8.3、§11.2 已给文案与恢复路径）。

短期定位下，下列长期事项不做，列入 §13.3：进度备份与恢复、可访问性完整适配、应用元数据与分发、时政时效标记、扩展统计、长期数据迁移。

### 13.3 范围外

- 多用户、账号、云同步、后端。
- iOS/桌面端正式支持与验收。
- SM-2/FSRS、复习债务、到期队列。
- Anki `.apkg`、任意第三方 Markdown、Excel 导入。
- 多科目（英语、专业课）内容与界面。
- 批量/可视化一页纸编辑器；单条长按热修在范围内。
- 应用商店发布、签名分发、自动更新。
- 在线一页纸内容、爬虫、时政自动抓取。
- 复杂图表库、动画库、代码生成器。
- 进度备份与恢复：短期工具只导出内容，不导出进度；数据丢失的恢复路径是重新导入/恢复内置一页纸。
- 可访问性完整适配：系统字体缩放、色弱模式、TalkBack 语义；只保证基本点击区域与可读字号。
- 应用元数据与分发：图标精修、版本号策略、签名分发；只保留应用名、`applicationId` 与可安装 APK。
- 时政条目的时效标记与更新节奏：考试窗口内按现有语料使用。
- 扩展统计：连续天数、正确率曲线等；只保留遍数与真题分数。
- 长期数据迁移与多版本 schema 兼容：v1 只保证当前版本可读。

## 附录 A：协议样例

```markdown
# 马原
## 1.1 基础概念与帽子
- [配对] 理解政治经济学的枢纽 == 劳动二重性理论 | 口诀: 劳二枢纽 | 备注: 原文如此 #二轮 #配对
- [错] 意识和观念具有直接现实性 | 解析: 直接现实性是实践的特有属性。 | 墓碑词: 直接现实性
- [对] 人体解剖是猴体解剖的一把钥匙 | 解析: 马克思在《资本论》中的比喻。
- [对比] 工作重心转向城市（七届二中全会） <> 革命重心转向城市（1949 年进北平） | 口诀: 工作七二，革命进京 #二轮
```

导出时额外带 `id:`：

```markdown
- [配对] 理解政治经济学的枢纽 == 劳动二重性理论 | 口诀: 劳二枢纽 | id: mayuan.mapping.3f2a1b0c #二轮 #配对
```

## 附录 B：seed 统计基线

语料第三部分“一页纸内容”当前统计：

| 科目 | 候选行数 |
|---|---:|
| 马原 | 75 |
| 史纲 | 85 |
| 思修 | 14 |
| 新思想 | 18 |
| 时政 | 23 |
| 合计 | 215 |

候选行中的多义项（如“实践三特征”“六个寓于”）在 seed 中按协议拆分，最终条目数会大于 215。M1 验收以任务单 07 的统计报告为准：总数、分科目、分类型、重复 id、忽略行、抽样核对记录。

当前生成结果（2026-11-20）：549 条 —— 马原 142、史纲 199、思修 33、新思想 114、时政 61；mapping 484、trueFalse 55、pair 10。种子文件 `app/assets/default_sheet.md`，解析 0 error、0 warning。
