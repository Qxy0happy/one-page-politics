# 工具链基线

日期：2026-11-20。目标：确认 Flutter 3.50 / OpenJDK 25（含 jlink）/ Android SDK 36 能创建、分析、测试并构建 `one_page_politics` 的 debug APK。

## 实际环境

| 项 | 值 |
|---|---|
| Flutter | 3.50.0 stable（mirror `https://mirrors.cernet.edu.cn/flutter-sdk.git`） |
| Dart | 3.14.0 |
| 系统 Java | OpenJDK 25.0.5.1（`/usr/lib/jvm/java-25-openjdk`，**含 jlink**） |
| 构建 JDK | 同上；`flutter config --jdk-dir=/usr/lib/jvm/java-25-openjdk` |
| Android SDK | 36.0.0，`ANDROID_HOME=/home/qxyhappy/develop/Android/Sdk` |
| Build tools | 36.0.0 |
| 模拟器 | AVD `medium_phone`（Medium Phone） |
| 真机 | 当前未连接 |
| Gradle | 9.5.0（wrapper，`gradle-9.5.0-all`） |
| AGP / Kotlin | 9.3.1 / 2.4.20（Flutter 3.50 模板） |

`flutter doctor -v`：Android toolchain 通过，licenses 已接受；Flutter 仅提示 mirror 不是标准 remote，不影响构建。`flutter devices` 只列出 Linux/Chrome，说明模拟器未启动，不是工具链缺失。

## 创建与依赖

命令：

```bash
flutter create --platforms=android --project-name one_page_politics --org com.qxyhappy app
cd app
flutter pub add provider path_provider shared_preferences file_picker flutter_tts
```

解析到的版本：

- `provider 6.1.5+1`
- `path_provider 2.1.6`
- `shared_preferences 2.5.6`
- `file_picker 13.4.0`
- `flutter_tts 4.2.5`
- `material_ui 1.1.0`（Flutter 3.50 模板自带）

**重要变化**：Flutter 3.50 起 Material 组件从 `package:flutter/material.dart` 迁到 `package:material_ui/material_ui.dart`；旧入口已标记弃用。因此 `material_ui` 不是额外自选依赖，而是当前 SDK 的 Material 3 入口。`cupertino_icons` 未使用，已移除。

## 网络与 Gradle

`flutter build apk --debug` 首次失败：

```text
Exception in thread "main" java.net.ConnectException: Connection timed out
at org.gradle.wrapper.Download...
Gradle task assembleDebug failed with exit code 1
```

原因：wrapper 从 `services.gradle.org` 下载 `gradle-9.5.0-all.zip`，该地址 307 到 GitHub；本机代理对 GitHub 不稳定。不是 AGP/JDK 兼容问题。

处理：

1. 代理可用：`HTTP_PROXY=http://127.0.0.1:7890`，`HTTPS_PROXY` 同。
2. 从腾讯镜像下载 Gradle 9.5.0-all（约 230 MB）：

```bash
curl -L -x http://127.0.0.1:7890 \
  -o /tmp/gradle-9.5.0-all.zip \
  https://mirrors.cloud.tencent.com/gradle/gradle-9.5.0-all.zip
```

3. 放入 wrapper 缓存：

```text
~/.gradle/wrapper/dists/gradle-9.5.0-all/aca6g93cdtcf0oapcfka748qh/
```

4. 在 `~/.gradle/gradle.properties` 增加 JVM 代理（Gradle 的 Java 进程不读 shell 的 `HTTP_PROXY`）：

```properties
systemProp.http.proxyHost=127.0.0.1
systemProp.http.proxyPort=7890
systemProp.https.proxyHost=127.0.0.1
systemProp.https.proxyPort=7890
```

5. 重新运行 `flutter build apk --debug`。

这条网络路径是本机环境问题，不写进项目代码；换机器时按同样方式配置代理或使用可达的 Gradle 镜像。

## JDK 与 jlink

早期构建使用系统 JBR 25（`/usr/lib/jvm/jre-jetbrains`）。它是精简运行时，不含 `jlink`，AGP 的 `JdkImageTransform` 报错：

```text
Execution failed for task ':jni:compileDebugJavaWithJavac'
> jlink executable /usr/lib/jvm/jre-jetbrains/bin/jlink does not exist.
```

之后系统切换到 **OpenJDK 25.0.5.1**（`/usr/lib/jvm/java-25-openjdk`）。检查结果：

```bash
readlink -f "$(command -v java)"
# /usr/lib/jvm/java-25-openjdk/bin/java

/usr/lib/jvm/java-25-openjdk/bin/jlink --version
# 25.0.5.1
```

`jlink` 不在 shell 的 `PATH` 里，但这不影响 AGP；它使用工具链 JDK 的 `bin/jlink`，而不是 `PATH`。当前 `flutter config` 已指向：

```bash
flutter config --jdk-dir=/usr/lib/jvm/java-25-openjdk
```

`flutter doctor -v` 显示 `OpenJDK Runtime Environment (build 25.0.5.1)`，并注明来自 Flutter 配置。用该 JDK 重新执行 `flutter analyze`、`flutter test`、`flutter build apk --debug`，全部通过；APK 安装到 `medium_phone` 并启动成功。

Temurin 17.0.21 已按用户要求从 `~/.gradle/jdks` 删除（连同其锁文件），不再保留兼容性备用。若未来 AGP/Kotlin 与 JDK 25 出现兼容问题，先停止并询问，不自行安装或切换工具链。

## 工具链安装记录

构建过程中实际发生的安装/下载（透明化）：

| 组件 | 方式 | 说明 |
|---|---|---|
| Gradle 9.5.0-all | 手动从腾讯镜像下载 | 约 230 MB，放入 wrapper 缓存 |
| Android SDK Platform 35 | AGP 构建时自动安装 | 首次构建 |
| Android NDK 28.2.13676358 | AGP 构建时自动安装 | 约 1 GB |
| CMake 3.22.1 | AGP 构建时自动安装 | 首次构建 |
| Temurin 17.0.21 | `~/.gradle/jdks` 中已有 | 曾用于构建，已按用户要求删除 |
| OpenJDK 25.0.5.1 | 用户自行切换的系统 JDK | 当前构建 JDK |

这些自动安装是本次任务中实际发生的。后续按 `AGENTS.md` 的规则，缺组件时构建失败并先询问；项目 `android/gradle.properties` 已设置：

```properties
android.builder.sdkDownload=false
org.gradle.java.installations.auto-download=false
```

## 版本锁定建议

- 保持 Flutter 3.50.0 / Dart 3.14.0；不要升级到未验证的 channel。
- 构建 JDK 固定 OpenJDK 25.0.5.1（含 jlink）；不再保留 Temurin 17 备用。
- Gradle 9.5.0、AGP 9.3.1、Kotlin 2.4.20 使用模板默认组合。
- `compileSdk` / `minSdk` / `targetSdk` 保持 `flutter.*` 默认值；当前 SDK 36。不要在 M1 手写版本号。
- `material_ui` 固定 1.1.x；它是 Flutter 3.50 的 Material 入口。

## 验证状态

- `flutter create`：通过。
- `flutter pub get` / `pub add`：通过。
- `flutter analyze`：0 issue。
- `flutter test`：11 个测试通过（seed 解析、MD 协议、模型 JSON、合并/导出）。
- `flutter build apk --debug`：通过（OpenJDK 25，22.4s）。
- `medium_phone` 无头启动、APK 安装与启动：通过；进度数据在重装后保留。

## 结论

Go。Gradle 发行包需要镜像/代理；Gradle JDK 使用含 `jlink` 的 OpenJDK 25。两者都不涉及应用代码。APK 构建、安装与启动均已验证。
