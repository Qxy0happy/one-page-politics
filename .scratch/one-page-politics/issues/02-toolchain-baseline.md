# 02 — Flutter 3.50 / OpenJDK 25 / AGP 与 medium_phone 模拟器基线

Type: research
Status: resolved
Blocked by: —

## Question

本机基线：Flutter 3.50.0 stable、Dart 3.14.0、Java 25、`ANDROID_HOME=/home/qxyhappy/develop/Android/Sdk`、AVD `medium_phone`、无真机连接。需要确认：

- `flutter doctor -v` 的实际状态；Android licenses、cmdline-tools、platform/build-tools 是否齐全。
- Java 25 与当前 Flutter 3.50 默认 Gradle/AGP 是否兼容；若不兼容，应固定哪个 JDK/Gradle/AGP 组合。
- 用 `/tmp` 下的空 Flutter 工程验证 `flutter create`、`flutter build apk --debug`，并在 `medium_phone` 上启动（优先 `-no-window` 无头模拟器，避免抢占桌面焦点；结束即关闭）。
- `provider`、`path_provider`、`shared_preferences`、`file_picker`、`flutter_tts` 在当前 Flutter/Dart 下的可用版本与已知坑；给出 `pubspec.yaml` 建议版本。
- 需要固定的 `compileSdk`、`minSdk`、`targetSdk`、Kotlin/AGP/Gradle 版本。

## Acceptance

研究笔记写入 `.scratch/one-page-politics/research/toolchain-baseline.md`，记录可复现命令、实际输出摘要、版本锁定建议与 go/no-go；在本文件追加 `## Answer`。不要修改仓库代码，临时工程放 `/tmp` 并在结束时清理。

## Answer

研究笔记：[toolchain-baseline.md](../research/toolchain-baseline.md)。

### 结论

Go。工具链可用，APK 已构建并在模拟器启动。

- Flutter 3.50.0 stable / Dart 3.14.0；Android SDK 36.0.0；AVD `medium_phone`。
- **构建 JDK：OpenJDK 25.0.5.1**（`/usr/lib/jvm/java-25-openjdk`，含 `jlink`）。早期系统 JBR 25 是精简运行时、缺 `jlink`，AGP `JdkImageTransform` 失败；系统切换到 OpenJDK 25 后已重新构建成功。`flutter config --jdk-dir` 现指向 OpenJDK 25；Temurin 17 已按用户要求删除，不再保留备用。
- Gradle 9.5.0 / AGP 9.3.1 / Kotlin 2.4.20（Flutter 3.50 模板）。
- 依赖：`provider 6.1.5+1`、`path_provider 2.1.6`、`shared_preferences 2.5.6`、`file_picker 13.4.0`、`flutter_tts 4.2.5`；Flutter 3.50 模板另带 `material_ui 1.1.0`（Material 入口）。
- Gradle 发行包从 `services.gradle.org` 下载会 307 到 GitHub 并超时；已从腾讯镜像下载 9.5.0-all 放入 wrapper 缓存，并在 `~/.gradle/gradle.properties` 配置 JVM 代理。
- `flutter analyze` 0 issue；`flutter test` 11 个通过；`flutter build apk --debug` 在 OpenJDK 25 下成功，产物 `app/build/app/outputs/flutter-apk/app-debug.apk`。
- `medium_phone` 无头启动成功；APK 安装、启动、遮罩、单条揭晓、眼熟状态、重启后进度保留、工具箱两个分段均通过手动冒烟。
- 工具链规则：`AGENTS.md` 已规定不得静默安装；`app/android/gradle.properties` 已禁止 AGP 自动下载 SDK 与 Gradle 自动下载 JDK。Temurin 17 已删除。

### 风险

- `flutter_tts` 仍以旧方式应用 Kotlin Gradle Plugin，Flutter 输出未来兼容性警告；当前不影响构建，后续若升级 Flutter 需换插件版本或迁移 Built-in Kotlin。
- 本机网络需要代理/镜像；换机器时按研究笔记步骤配置。
