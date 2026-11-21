# 真机验收记录

配套文档：[app/README.md](../README.md)；验收流程依据 [spec.md §6](../../.scratch/one-page-politics-device/spec.md)。

执行规则：

- 在飞行模式下按顺序执行；每项记录“通过 / 失败 / 待人工”与证据位置（截图文件名、日志片段或命令输出）。
- 只记录实际观察到的结果，不预填构建产物数据；构建结果由 release 构建任务写入“构建与静态检查”。
- 2026-11-20 已连接真机 HONOR AAK-AN00 完成七步检查；模拟器结果不再替代真机结论。无中文 TTS 引擎一项因设备上没有现成的无中文引擎而未复现，单独标注。

> 以下记录对应 DeepSeek 云语音加入之前的版本。当前 release 主清单已声明 `android.permission.INTERNET`，用于可选的 DeepSeek 后端；“无网络权限”一项不再适用，系统语音仍可离线使用。新增能力的规格与验收项见 [.scratch/deepseek-tts/spec.md](../../.scratch/deepseek-tts/spec.md)。

## 2026-11-21 增量构建记录

- 构建：`cd app/android && JAVA_HOME=/usr/lib/jvm/java-27-openjdk ./gradlew assembleRelease`；`assembleRelease` 成功，约 1 分 30 秒。
- 产物：`app/build/app/outputs/flutter-apk/app-release.apk`，54,640,110 字节（约 52.1 MiB），versionName `1.1.0`、versionCode `2`，SHA-256 `411963a8bbe12d792257bc0a989647155ee4e5aa856f0c7cd7184565612e672c`。
- 权限：`aapt2 dump permissions` 显示 `android.permission.INTERNET` 与 AndroidX 私有权限；INTERNET 仅用于可选的 DeepSeek 后端。
- 签名：沿用本机 debug 签名，`apksigner` 证书 SHA-256 摘要 `9ee59fcf9f36e0699079ae7ce2d7ce1f94215010db5a3b0373d19bbc41e97e50`。
- 已覆盖：Dart 静态检查、92 项单元与组件测试、原生 Kotlin 编译、完整 release 打包、清单权限与签名核对。
- 未覆盖：真实 DeepSeek API Key 下的合成、`filesDir/tts_cache` 落盘、AAC 听感与两处停顿；本次 `adb devices` 为空，需要真机人工确认。

## 环境与产物

| 字段 | 值 | 采集方式 |
|---|---|---|
| 记录日期 / 记录人 | 2026-11-20；构建、模拟器回归、真机操作由代理执行；中文语音可用性由用户确认 | — |
| 设备型号 | HONOR `AAK-AN00`（`AAK_AN00`，序列号 `A4UF6R6113000198`） | `adb shell getprop ro.product.model` |
| Android 版本 | 16（SDK 36；`ro.build.version.release=16`） | `adb shell getprop ro.build.version.release` |
| 系统 TTS 引擎 | `com.hihonor.voiceengine`（验收中曾临时切换到 `com.google.android.tts`，结束后已恢复） | 播控条诊断行，或 `adb shell settings get secure tts_default_synth` |
| 所选语言 | `zh-Hans`（HONOR 引擎）；Google TTS 下为 `zh-CN` | 播控条诊断行，或 `adb shell settings get secure tts_default_locale` |
| APK 版本（versionName+code） | `1.0.0`（versionCode `1`） | `aapt2 dump badging app-release.apk \| head -1` |
| APK 路径 | `app/build/app/outputs/flutter-apk/app-release.apk` | 构建输出 |
| APK 大小 | `52 582 418` 字节（约 50.1 MiB） | `stat -c '%s' app-release.apk` |
| SHA-256 | `4b13a8cbe49740de78bbf8a8c44ddb44a643bef1fb67b3d10185ab0706b97b23` | `sha256sum app-release.apk` |
| 签名证书摘要 | 主题 `C=US, O=Android, CN=Android Debug`；SHA-256 `9ee59fcf9f36e0699079ae7ce2d7ce1f94215010db5a3b0373d19bbc41e97e50` | `apksigner verify --print-certs app-release.apk` |

## 构建与静态检查

由 release 构建任务于 2026-11-20 执行，以下为实际输出摘要。

| 检查项 | 命令 | 结果 | 证据 |
|---|---|---|---|
| 静态分析 | `cd app && flutter analyze` | 通过：`No issues found! (ran in 1.1s)` | 终端输出 |
| 单元/组件测试 | `cd app && flutter test` | 通过：`+47: All tests passed!`（47 个测试） | 终端输出 |
| release 构建 | `cd app && flutter build apk --release` | 成功：`Built build/app/outputs/flutter-apk/app-release.apk (52.6MB)`，Gradle `assembleRelease` 用时 55.3s；为 TTS 试听隔离与状态辅助的复查修复后重建，体积与上次一致，SHA-256 更新 | 终端输出、APK 路径 |
| 无网络权限 | `aapt2 dump permissions app-release.apk` | 通过：只列出 `com.qxyhappy.one_page_politics.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`，无 `android.permission.INTERNET`，无需 merger 移除规则 | 见本节末输出摘要 |
| TTS 服务查询 | `aapt2 dump xmltree --file AndroidManifest.xml app-release.apk` | 通过：`<queries>` 保留 `android.intent.action.TTS_SERVICE`（另有 `PROCESS_TEXT`、`GET_CONTENT`） | 见本节末输出摘要 |
| 签名有效 | `apksigner verify --print-certs app-release.apk` | 通过：`Signer #1 certificate DN: C=US, O=Android, CN=Android Debug`；证书 SHA-256 `9ee59fcf9f36e0699079ae7ce2d7ce1f94215010db5a3b0373d19bbc41e97e50` | 终端输出 |
| 包名/版本/SDK | `aapt2 dump badging app-release.apk` | 通过：包名 `com.qxyhappy.one_page_politics`、`versionCode='1'`、`versionName='1.0.0'`、`minSdkVersion:'24'`、`targetSdkVersion:'36'`、`compileSdkVersion='36'` | 终端输出 |

命令输出摘要：

```text
$ sha256sum app-release.apk
4b13a8cbe49740de78bbf8a8c44ddb44a643bef1fb67b3d10185ab0706b97b23  app-release.apk

$ aapt2 dump permissions app-release.apk
package: com.qxyhappy.one_page_politics
permission: com.qxyhappy.one_page_politics.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION
uses-permission: name='com.qxyhappy.one_page_politics.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION'

$ aapt2 dump xmltree --file AndroidManifest.xml app-release.apk   # 节选
E: intent
    E: action
        A: android:name="android.intent.action.TTS_SERVICE"
E: intent
    E: action
        A: android:name="android.intent.action.GET_CONTENT"
```

说明：`DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` 是 AndroidX Core 自动生成的应用私有签名级权限，不是网络权限；release 清单不含 `INTERNET`。

## 代理回归（无头模拟器，2026-11-20）

本节记录代理在最终产物上的无头模拟器回归。所用的 APK 即“环境与产物”与“构建与静态检查”记录的最终 release 包（复查修复后重建，SHA-256 `4b13a8cbe49740de78bbf8a8c44ddb44a643bef1fb67b3d10185ab0706b97b23`，52 582 418 字节），未使用修复前的旧包。模拟器无音频、无真实语音引擎配置，因此下列结果只证明构建、安装、启动、四 Tab 与播控条结构，不构成听感或系统语音设置结论。

命令与结果：

```bash
$ sha256sum app/build/app/outputs/flutter-apk/app-release.apk   # 本节回归所用产物
4b13a8cbe49740de78bbf8a8c44ddb44a643bef1fb67b3d10185ab0706b97b23  …/app-release.apk

$ adb install -r app-release.apk
Performing Streamed Install
Success
```

`flutter analyze` 与 `flutter test` 的结果见“构建与静态检查”（同一提交、同一产物：0 issue、47 个测试通过）；本轮回归只重跑设备侧步骤。

| 步骤 | 命令 | 结果 |
|---|---|---|
| 启动模拟器 | `emulator -avd medium_phone -no-window -no-audio -no-boot-anim -no-snapshot-save` | 成功，设备连上后 `sys.boot_completed=1`，全过程约 14 秒；设备 `emulator-5554`，Android 16（`ro.build.version.release=16`），型号 `sdk_gphone64_x86_64` |
| 安装 | `adb install -r app-release.apk` | `Success`；`dumpsys package` 显示 `versionName=1.0.0`、`versionCode=1`、`minSdk=24`、`targetSdk=36` |
| 冷启动 | `adb shell am start -W -n com.qxyhappy.one_page_politics/.MainActivity` | `Status: ok`，`LaunchState: COLD`，`TotalTime: 2569`；`dumpsys activity` 中 `topResumedActivity` 为该 Activity，且保持前台 |
| 四 Tab | `uiautomator dump` | 底部四个 Tab 均存在：`一页纸 · Tab 1 of 4`、`反射场 · Tab 2 of 4`、`工具箱 · Tab 3 of 4`、`作战室 · Tab 4 of 4` |
| 内置内容 | 同上 dump | 标题 `一页纸\n549 / 549 条`；分类按钮 `马原 142`、`史纲 199`、`思修 33`、`新思想 114`（另有 `二轮冲刺 201`、`仅标星 0`、`仅模糊 0`、`全部`）；条目卡片含题干与解析，三态按钮 `眼熟 / 模糊 / 标星` 可见 |
| 磨耳朵面板 | 点击 `磨耳朵` 后再次 dump | 面板标题 `离线磨耳朵`；诊断行 `引擎 com.google.android.tts · 语言 zh-CN`；`试听` 按钮、进度 `0 / 0`、语速 `1.0x / 1.25x / 1.5x`、`单列表循环`、说明文字均可见；点 `关闭并停止朗读` 后回到主列表（`549 / 549 条` 重新可见），Activity 仍为 resumed |
| 异常日志 | `adb logcat -d \| grep -icE "FATAL EXCEPTION\|E/flutter\|Unhandled Exception\|ANR in com.qxyhappy"` | 输出 `0`（无匹配）；应用进程 `pidof` 存活（`5000`） |
| 收尾 | `adb emu kill` | `OK: killing emulator, bye bye`；`adb devices` 列表为空，无 emulator/qemu-system 残留进程 |

注：模拟器内预装的 `com.android.cli.interact.instrumentation` 会占用 UiAutomation 注册导致首次 `uiautomator dump` 返回空层级（`java.lang.IllegalStateException: UiAutomationService … already registered!`）。执行 `adb shell am force-stop com.android.cli.interact.instrumentation`、待界面渲染后重跑 dump 即正常。该问题属于模拟器环境，与应用无关。

结论：最终产物在模拟器上的安装、冷启动、四 Tab、549 条内置内容、磨耳朵面板诊断/试听/语速/循环控件均通过，无崩溃与 ANR 记录；模拟器无音频，以下人工项仍未覆盖。模拟器报告的引擎与语言来自其自带 Google TTS 配置，不作为真机语音设置证据。

## 真机验收（HONOR AAK-AN00，2026-11-20）

设备：HONOR `AAK-AN00`，Android 16（SDK 36），1272×2800 / 560 dpi。应用此前未安装；本轮为全新安装，验收结束后已用“清空全部数据”恢复到 549 条、0 进度的初始状态。

关键命令：

```bash
adb devices -l
# A4UF6R6113000198 device product:AAK-AN00 model:AAK_AN00

adb install -r app/build/app/outputs/flutter-apk/app-release.apk
# Success

adb shell am start -W -n com.qxyhappy.one_page_politics/.MainActivity
# Status: ok；首次冷启动 TotalTime: 204，飞行模式冷启动 198，覆盖安装后 202
```

关键观察：

| 项目 | 结果 |
|---|---|
| 内置内容 | 首次启动 `549 / 549 条`；导入验收条目后 `550 / 550 条`；清空后回到 `549 / 549 条` |
| TTS 诊断 | HONOR 引擎：`引擎 com.hihonor.voiceengine · 语言 zh-Hans`；临时切到 Google TTS：`引擎 com.google.android.tts · 语言 zh-CN` |
| 试听 | 面板显示“试听中…”后正常回到“试听”，无失败 SnackBar；用户在媒体音量约 11/16 时确认中文语音可用。初始媒体音量为 0/16（静音），验收后已恢复为 0 |
| 整队朗读 | 进度从 `1 / 550` 前进到 `2 / 550`；暂停后停在 `3 / 549`，3 秒内不前进；继续后到 `4 / 549`；下一条 `5 / 549`，上一条 `4 / 549` |
| 语速/循环 | `1.25x`、`1.5x`、`1.0x` 逐项选中状态正确；`单列表循环` 可打开 |
| 持久化 | 标星 1、模糊 12（是非训练产生）、真题 `Mock1_acceptance` 26 分（10 + 8×2）、遍数 1、计时器 `29:55`；`am force-stop` 后重开仍为计时器 `29:36`、标星 1、模糊 12、真题 26 分、遍数 1 |
| 覆盖安装 | 标星 1 后 `adb install -r` 成功；重开后仍为 `549 / 549 条`、`仅标星 1`，数据未被清除 |
| 飞行模式 | `cmd connectivity airplane-mode enable` 后 `airplane_mode_on=1`，冷启动 `550 / 550 条`，TTS 队列推进到 `2 / 550`；随后 `disable`，移动数据恢复 `IN_SERVICE` |
| 导入 | 选择 `device_acceptance.md`：预览“新增 1、更新 0、保留 0、缺失 549”；确认后 `550 / 550 条` |
| 导出 | 保存 `one_page_politics_2026-11-20.md`，文件 `73 131` 字节 |
| 导出再导入 | 预览“新增 0、更新 550、保留 0、缺失 0”；确认后仍为 `550` 条，标星/模糊/真题保持 |
| 反射场 | 是非滑卡进入 `1 / 15` 并判定后到 `2 / 15`；帽子配对第一批 4 组全部匹配后进入 `第 2 / 4 批`；双胞胎辨析选择“五四运动”后显示“回答正确”与 A/B 特征；政经计算器利润题输入 `60` 后显示“回答正确”与算式 |
| 工具箱 | 两段均可切换；单选卡展开显示 5 条；十二＋一角度、三位一体（“高质量发展”生成原因/意义/措施）、戴帽子句式、分科目口袋卡均可见 |
| 作战室 | 双计时器、遍数、真题记录、CustomPainter 折线图（0–50、35/40 虚线、26 分点）均可见并可用 |
| 清空全部数据 | 二次确认后回到 `549` 条、模糊 0、标星 0、真题 0、遍数 0、计时器 `30:00` |
| 收尾 | 删除设备上的验收 `.md` 与导出文件；媒体音量恢复 0；`svc power stayon false`；TTS 引擎恢复 `com.hihonor.voiceengine`；飞行模式关闭 |

未覆盖：设备上没有现成的“无中文 TTS 引擎”。把默认引擎切到 Google TTS 后仍有 `zh-CN`，因此“系统未安装中文语音”的不可用面板与重试路径未能在真机复现；该路径由 `tts_service_test.dart` 的不可用/重试用例覆盖。

## 七步真机检查

| # | 检查项 | 操作要点 | 结果 | 证据 |
|---|---|---|---|---|
| 1 | 冷启动与内置内容 | 飞行模式下从最近任务清除后冷启动，确认内置一页纸加载完成、条目可滚动 | 通过：飞行模式冷启动 `Status: ok`，`550 / 550 条`（验收时；清空后 `549`），四 Tab、条目卡与三态按钮正常，滚动无异常 | 见“真机验收”关键观察 |
| 2 | 磨耳朵初始化 | 打开磨耳朵，确认诊断行显示引擎与所选语言，“试听”朗读固定短句且不改队列与学习状态 | 通过：诊断行 `引擎 com.hihonor.voiceengine · 语言 zh-Hans`；试听从“试听中…”正常回到“试听”，无失败 SnackBar；用户确认中文语音可用 | 见“真机验收”；音频可用性由用户确认 |
| 3 | 整队朗读控制 | 开始朗读，逐项验证暂停/继续、上一条/下一条、1.0x/1.25x/1.5x 语速、单列表循环与进度显示 | 通过：`1/550→2/550`；暂停停在 `3/549`，继续 `4/549`；下一条 `5/549`，上一条 `4/549`；三档语速选中状态正确；循环开关可打开 | 操作序列见“真机验收” |
| 4 | 无中文语音与恢复 | 在系统设置停用中文语音或切换到无中文引擎，重开播控条确认提示与“重试”；恢复语音后重试成功 | 部分通过：临时把默认引擎切到 `com.google.android.tts`，应用正确选择 `zh-CN`；恢复 `com.hihonor.voiceengine` 后回到 `zh-Hans`。设备上没有现成的无中文引擎，不可用面板与重试未在真机复现，由 47 个测试覆盖 | 引擎切换命令与诊断行见“真机验收” |
| 5 | 学习状态持久化 | 设置若干条三态与标星、记录一套真题、启动计时器，强制停止应用后重开，确认全部保留 | 通过：标星 1、模糊 12、真题 26 分、遍数 1、计时器 `29:55`；`am force-stop` 后重开为计时器 `29:36`，其余全部保留；同签名 `adb install -r` 覆盖安装后标星仍为 1 | 见“真机验收” |
| 6 | Markdown 导入/导出 | 用系统文件选择器导入 `.md`，确认摘要与写入；导出后再次导入，确认按 `id` 命中而非重复新增 | 通过：导入预览“新增 1、更新 0、缺失 549”，确认后 `550` 条；导出 `73 131` 字节；导出再导入预览“新增 0、更新 550、缺失 0”，确认后仍为 `550` 条，进度保留 | 见“真机验收” |
| 7 | 其余功能走查 | 反射场四种模式、工具箱两段、作战室计时/计分/折线图各走通一遍 | 通过（关键交互）：是非 `1/15→2/15`；配对第一批 4 组全消后进入 `2/4`；双胞胎选择“五四运动”后显示“回答正确”与 A/B 特征；计算器利润题 `60` 正确并显示算式；工具箱两段与三位一体可用；作战室计时、真题记录、35/40 折线图可见。未完整跑完每局全部题量，逻辑由 47 个测试覆盖 | 见“真机验收” |

任何一项失败时记录复现步骤；TTS 异常另附日志：

```bash
adb logcat -d | grep -iE "tts|texttospeech|speech" > tts-logcat.txt
```

## 人工检查点（真机验收后）

- [x] 真机音频可用性：用户确认中文语音可用；详细音质、断句与语速舒适度未量化。
- [x] 系统“文字转语音输出”中的引擎切换：HONOR 与 Google TTS 均可用，均能选中中文；验收后恢复 HONOR 引擎。
- [x] 飞行模式下的离线冷启动与朗读：冷启动 `550` 条，队列推进到 `2/550`。
- [x] 暂停/继续、上一条/下一条、三档语速、循环与进度：真机逐项通过。
- [x] 同签名覆盖安装：`adb install -r` 成功，标星与条目数据保留。
- [x] 七步中除“无中文引擎降级”外的项目。
- [ ] 无中文 TTS 引擎/停用中文语音数据的降级复现：设备上两个引擎都带中文；需要在系统设置中停用中文语音数据，或安装一个不含中文的引擎后再验证。
- [ ] 音质主观评价（可选）：如需量化断句、语速舒适度，建议由用户按日常听力习惯再听一轮。

结论：真机验收通过（1–3、5–7 通过；第 4 项的无中文降级路径因设备上没有现成无中文引擎而未复现，已由单元测试覆盖）。最终 APK 为 `4b13a8…`，应用在验收后已清空测试数据并恢复到 `549` 条、0 进度；媒体音量、常亮、飞行模式与 TTS 引擎均已恢复。

## 应用内更新验收（2026-11-21，模拟器）

应用内更新需要两个同签名、versionCode 递增的构建，以及一个可被设备访问的更新源。正式发布包为 arm64-v8a；下面的模拟器流程用 x86_64 构建验证清单获取、下载、校验、权限提示与系统安装器链路，不替代真机的最终安装确认。

本次实测环境：`sdk_gphone64_x86_64`，Android 16（SDK 36）；首包 `1.2.0（3）`，次包 `1.2.1（4）`，均为 x86_64、本机 debug 签名，更新源为宿主机 `http://10.0.2.2:8000`。正式包为 arm64-v8a 与专用签名。

### 构建

首包（v1.2.0，versionCode 3）：

```bash
cd app
flutter build apk --release --target-platform android-x64 \
  --build-name=1.2.0 --build-number=3 \
  --dart-define=UPDATE_MANIFEST_URL=http://10.0.2.2:8000/update.json \
  --dart-define=ALLOW_INSECURE_UPDATE=true
cp build/app/outputs/flutter-apk/app-release.apk /tmp/update-acceptance/first.apk
```

次包（v1.2.1，versionCode 4）：同样的命令，改 `--build-name=1.2.1 --build-number=4`，输出为 `second.apk`。两次必须使用同一签名（本地默认为 `~/.android/debug.keystore`）。

### 本地更新源

```bash
mkdir -p /tmp/update-acceptance
cd /tmp/update-acceptance
cp /path/to/second.apk one-page-politics-1.2.1.apk
SHA="$(sha256sum one-page-politics-1.2.1.apk | awk '{print $1}')"
SIZE="$(stat -c %s one-page-politics-1.2.1.apk)"
jq -n --arg sha "$SHA" --argjson size "$SIZE" '{
  schemaVersion: 1,
  versionCode: 4,
  versionName: "1.2.1",
  minSdk: 24,
  publishedAt: "2026-11-21T12:00:00Z",
  notes: "验收用更新",
  apk: {url: "http://10.0.2.2:8000/one-page-politics-1.2.1.apk", size: $size, sha256: $sha}
}' > update.json
python3 -m http.server 8000 --bind 0.0.0.0
```

模拟器通过 `10.0.2.2` 访问宿主机；`ALLOW_INSECURE_UPDATE=true` 只用于本地联调，正式构建不设置。

### 步骤与结果

| # | 检查项 | 操作要点 | 结果 | 证据 |
|---|---|---|---|---|
| 1 | 首包安装与启动 | `adb install -r first.apk`，冷启动，确认版本卡显示 `1.2.0（3）` | 通过：安装成功；版本卡显示 `当前 1.2.0（3）` | 模拟器截图 |
| 2 | 静默检查 | 启动后等待 SnackBar“发现新版本 v1.2.1”；点“查看”进入作战室 | 通过：启动后出现 SnackBar `发现新版本 v1.2.1`；本地 HTTP 日志 `GET /update.json 200` | 服务日志、截图 |
| 3 | 更新对话框 | 版本卡点“查看”，确认版本、大小、日期与说明；点“稍后”后保留“新版本”入口 | 通过：显示 `发现新版本 v1.2.1`、`当前版本 1.2.0（3）`、`19.4 MB · 2026-11-21` 与说明；`稍后` 后版本卡保留 `新版本 v1.2.1 / 查看` | 截图 |
| 4 | 下载与续传 | 点“下载并安装”，观察进度；中途取消，再次下载应从 `.part` 续传 | 部分通过：点击后日志出现 `GET /one-page-politics-1.2.1.apk 200`，下载与校验完成；取消/续传未在模拟器重复，由 `update_service_test.dart` 的 Range、取消与 416 用例覆盖 | 服务日志、测试输出 |
| 5 | 校验与安装 | 下载完成后显示校验，再调起系统安装器；允许“安装未知应用”并确认安装 | 通过：未授权时打开系统“安装未知应用”页；授权后点“下载并安装”调起 `PackageInstallerActivity`，确认后安装成功 | 截图、`dumpsys window` |
| 6 | 升级结果 | 返回应用后版本卡显示 `1.2.1（4）`；再次检查显示已是最新 | 通过：`dumpsys package` 显示 `versionCode=4`、`versionName=1.2.1`；版本卡 `当前 1.2.1（4）`，无更新提示 | 命令输出、截图 |
| 7 | 校验失败 | 把 `update.json` 的 `sha256` 改错，手动检查应显示 SHA-256 不一致且不调起安装器 | 未执行：Dart 层“校验失败不调起安装器”由 `update_provider_test.dart` 覆盖；原生 SHA-256 计算未在模拟器构造错包 | 测试输出、代码审查 |
| 8 | 签名不一致 | 用另一把 keystore 签次包，校验应显示签名不一致且不调起安装器 | 未执行：同一单元测试覆盖 `VerifyResult` 失败路径；原生签名比对未在模拟器构造异签名包 | 测试输出、代码审查 |

补充观察：首包发现 `1.2.1` 后强制停止并重开，24 小时缓存内未重复请求 `update.json`，版本卡与 SnackBar 仍从本地保存的清单恢复；升级到 `1.2.1（4）` 后更新提示清除。

失败时记录 `adb logcat -d | grep -iE "update|packageinstaller|PackageInstaller"` 的相关片段，并附截图。

结论：应用内更新主链路在模拟器上通过（清单获取、对话框、下载、权限、系统安装器、升级到 `1.2.1/4`）。负向的 SHA-256/签名不一致路径未在模拟器构造，分别由单元测试与代码审查覆盖；真机 OEM 安装器、正式 arm64 包与专用签名包仍需在发布前人工确认。
