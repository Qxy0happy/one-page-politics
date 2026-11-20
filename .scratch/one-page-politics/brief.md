# one_page_politics 产品规格（用户原始输入）

> 来源：用户 2026-11-19 在 wayfinder grilling 中粘贴的规格。终端把部分换行压平了，这里只重排 Markdown 结构，未改动语义。
> 本文件是产品约束基线；后续 ticket 若推翻其中某条，必须在 map 的 Decisions so far 中记录，并同步更新本文件。

## Role & Project Goal

你是一名精通 Flutter 与 Android 端移动端交互的高级工程师。请为我开发一个离线自用的 Android Flutter 应用原型（项目名：`one_page_politics`），用于辅助背诵考研政治“一页纸”与选择题/大题应试方法。

## 核心产品哲学（严格遵守，不可跑偏）

1. **不是传统 Anki / 刷题库**：禁止引入复杂的 SM-2/FSRS 间隔重复债务机制，禁止强迫用户输入文字默写。
2. **核心目标是“高频刺激 + 条件反射”**：主打单手低摩擦操作，帮用户在每天 15~30 分钟内快速建立对考点的“熟悉感”、训练对“是非判断 / 对应关系 / 墓碑词”的条件反射。
3. **绝对离线可用**：无后端、无登录，数据全部持久化在设备本地，支持通过导入本地 `.md` 文件热更新题库。

---

## 一、硬性技术约束（Technical Guardrails）

- **框架与平台**：Flutter 3.x (Material 3, Dart 3)，Android 优先（适配单手握持与全面屏手势）。
- **零代码生成（Strict Rule）**：**严禁使用** `build_runner`、`freezed`、`json_serializable`、`isar`、`drift`、`riverpod_generator`。所有 Model 必须手写 `toJson` / `fromJson` / `copyWith`，确保 `flutter run` 零折腾通过。
- **精简依赖（`pubspec.yaml` 仅限以下成熟包）**：
  - `provider`（状态管理）
  - `path_provider`（本地 JSON 数据持久化）
  - `shared_preferences`（主题、计时器、遍数与轻量配置）
  - `file_picker`（从 Android 本地文件管理器导入 `.md` 文件）
  - `flutter_tts`（离线语音播报磨耳朵）
  - *注：不要引入 `fl_chart` 等易产生版本冲突的图表库，真题分数折线图请用原生 `CustomPainter` 手绘；滑卡交互请用原生 `GestureDetector` / `AnimatedContainer` 实现。*
- **Android 11+ TTS 兼容**：必须在 `android/app/src/main/AndroidManifest.xml` 中添加 `<queries>` 声明 `android.intent.action.TTS_SERVICE`，防止真机上 `flutter_tts` 无法发声。

---

## 二、视觉与单手交互规范（Design Tokens）

采用**高对比“语义纸感”风格**，支持浅色（护眼纸感）与深色（OLED 纯黑）切换。颜色严格服务于学习语义，禁止多余装饰渐变：

- **背景与文字**：
  - 浅色：背景 `#F7F5F0`，卡片 `#FFFFFF`，主文字 `#1E1E1E`，次文字 `#6B7280`。
  - 深色：背景 `#0D0D0D`，卡片 `#18181B`，主文字 `#E6E6E6`，次文字 `#9CA3AF`。
- **四大语义色**：
  - **琥珀黄 (`#D97706` / 浅底 `#FEF3C7`)**：核心结论、帽子关键词、遮罩色块。
  - **警示红 (`#DC2626` / 浅底 `#FEE2E2`)**：墓碑词、错误表述、干扰项陷阱。
  - **安全绿 (`#16A34A` / 浅底 `#DCFCE7`)**：白名单词（如“有利于/有助于”）、正确原话、反例提醒。
  - **克莱因蓝 (`#2563EB` / 浅底 `#DBEAFE`)**：谐音口诀胶囊、大题框架标签。
- **拇指热区原则**：遮罩总开关、三态标记按钮、滑卡判对/判错、TTS 播放控制条均尽量放置在屏幕下半区或底部弹出层，方便单手操作。

---

## 三、核心数据模型与目录结构

### 推荐目录结构

```text
lib/
├── main.dart
├── theme/app_theme.dart
├── models/
│   ├── knowledge_item.dart      # 考点条目模型
│   ├── exam_record.dart         # 真题/模拟卷计分记录
│   └── toolbox_models.dart      # 墓碑词、兵法、大题框架静态模型
├── services/
│   ├── md_parser_service.dart   # 确定性 Markdown 解析与增量合并引擎
│   ├── storage_service.dart     # 本地 JSON + SharedPreferences 读写
│   ├── tts_service.dart         # 朗读队列管理（读题干 -> 停顿 -> 读结论）
│   └── calc_generator.dart      # 马原政经计算题随机出题引擎
├── providers/
│   ├── study_provider.dart      # 题库、筛选、三态标记、导入合并、热修
│   └── war_room_provider.dart   # 真题分数、双计时器、遍数记录
├── data/
│   └── toolbox_seed_data.dart   # 内置兵法、墓碑词红黑榜、大题口袋卡完整数据
├── pages/
│   ├── home_shell.dart          # 4-Tab 底部导航壳
│   ├── tab1_sheet_page.dart     # Tab 1: 一页纸刷眼主场
│   ├── tab2_reflex_page.dart    # Tab 2: 反射场（4种微训练入口与子页）
│   ├── tab3_toolbox_page.dart   # Tab 3: 兵法与大题工具箱
│   └── tab4_war_room_page.dart  # Tab 4: 作战室（真题计分/计时/MD导入）
└── widgets/
    ├── mask_text_chip.dart      # 可点击局部揭晓的琥珀色遮罩组件
    ├── swipe_tf_view.dart       # 是非左右滑卡训练组件
    ├── tap_match_view.dart      # 帽子点击配对（4x4）训练组件
    ├── pair_contrast_view.dart  # 双胞胎易混辨析组件
    ├── polecon_calc_view.dart   # 马原计算器训练组件
    └── score_line_chart.dart    # 原生 CustomPainter 折线图（含35/40分参考线）
assets/
└── default_sheet.md             # 内置初始一页纸数据（按下方 MD 协议编写）
```

> 注：原始规格到这里结束，未附“下方 MD 协议”。协议由 `spec.md` §6 冻结。
