# 一页纸政治（one_page_politics）

服务至 2026-12-19 的个人 Android 背诵工具。学习数据保存在本机；默认使用系统离线语音。可选的 DeepSeek 云语音需要网络与 API Key，release 因此声明 `INTERNET` 权限。

功能规格与工单保存在本地 `.scratch/`，不随仓库发布；验收记录见 `app/docs/device-acceptance.md`。

当前版本：`1.2.0+3`（release `v1.2.0`），仅 arm64-v8a。

## 四个 Tab

| Tab | 用途 |
|---|---|
| 一页纸 | 路径树（科目 → 章节/类型）、条目卡三态（未看/眼熟/模糊）、标星、磨耳朵（系统离线语音或 DeepSeek 云语音，合成音频本地压制缓存） |
| 反射场 | 是非滑卡、帽子配对、双胞胎辨析、政经计算器四类微训练 |
| 工具箱 | 选择题兵法、大题与抄材料两段方法 |
| 作战室 | 双计时器与遍数、真题记录、计时/计分折线图、导入导出、版本更新与重置 |

## 应用内更新

- 更新源：`https://github.com/Qxy0happy/one-page-politics/releases/latest/download/update.json`。
- 触发：作战室手动检查；启动时静默检查，最多每 24 小时请求一次，可在版本卡关闭。启动检查只读取清单，不自动下载。
- 清单字段：`schemaVersion`、`versionCode`、`versionName`、`minSdk`、`publishedAt`、`notes`、`apk.url`、`apk.size`、`apk.sha256`。应用只接受 HTTPS 更新地址；本地联调可用 `--dart-define=UPDATE_MANIFEST_URL=... --dart-define=ALLOW_INSECURE_UPDATE=true` 覆盖，正式构建不设置后者。
- 下载：完整 APK，写入 `getTemporaryDirectory()/updates/`；中断后用 Range 续传，`.part` 保留到下次重试。Android 侧载不支持字节级差分包。
- 校验：安装前计算 SHA-256、读取安装包包名与 versionCode，并比较下载包与已安装应用的签名证书；任一不一致都拒绝安装。校验通过后再交给系统安装器。
- 安装：`UpdateInstaller.kt` 通过 FileProvider 暴露缓存目录中的 APK，调起 `application/vnd.android.package-archive`。用户在系统界面确认安装；应用不会静默安装。
- 权限与组件：`INTERNET`、`REQUEST_INSTALL_PACKAGES`、`androidx.core.content.FileProvider`（authority `${applicationId}.fileprovider`，路径 `cache/updates/`）。不申请存储权限。
- 状态与文件：
  - `lib/services/update_service.dart`：清单获取、下载、续传、大小校验。
  - `lib/services/update_gateway.dart`：版本读取、APK 校验、安装、权限设置、打开链接的平台通道。
  - `lib/providers/update_provider.dart`：24 小时缓存、跳过版本、下载进度、安装结果。
  - `lib/widgets/update_dialog.dart`：版本说明、进度、错误与重试。
  - `android/app/src/main/kotlin/com/qxyhappy/one_page_politics/UpdateInstaller.kt`：原生实现。
- 失败处理：网络失败、清单格式错误、大小不符、SHA-256 不符、包名/版本号/签名不符、系统版本过低、缺少安装权限都会在界面给出原因，不改动学习数据。

## 构建

环境：Flutter 3.50 / Dart 3.14（`sdk: ^3.14.0`），使用现有 Android SDK 与带 `jlink` 的 JDK；项目不使用代码生成。

```bash
tools/check.sh            # 格式、分析、测试、release 构建与 APK 断言
SKIP_BUILD=1 tools/check.sh  # 只查代码
```

发布包只构建 arm64-v8a：

```bash
TARGET_PLATFORM=android-arm64 tools/check.sh
```

产物为：

```text
app/build/app/outputs/flutter-apk/app-release.apk
```

指定签名证书指纹后，脚本会在 APK 签名不一致时失败：

```bash
TARGET_PLATFORM=android-arm64 RELEASE_CERT_SHA256=<证书 SHA-256> tools/check.sh
```

脚本使用 `JAVA_HOME` 指向的 JDK。GraalVM 的 `jlink` 会在 `JdkImageTransform` 失败；此时把 `JAVA_HOME` 指向 Temurin/OpenJDK。CI 使用 Temurin。

构建、权限、签名与版本的核对命令见 [docs/device-acceptance.md](docs/device-acceptance.md) 的“构建与静态检查”。

## 签名与个人侧载

- v1.2.0 起使用专用 release keystore。首次配置运行：

  ```bash
  tools/setup-release-key.sh
  ```

  脚本在 `~/.config/one-page-politics/` 生成 PKCS12 keystore 与密码文件，并写入 GitHub Actions secrets；keystore 与密码必须离线备份。
- 本地没有 `app/android/key.properties` 时，Gradle 退回 debug 签名，便于开发；正式发布必须由 Release 工作流注入专用 keystore。
- `app/android/key.properties` 与 `*.keystore` 已被 `.gitignore` 忽略，不得提交。
- 包名固定为 `com.qxyhappy.one_page_politics`；版本号取自 `pubspec.yaml`（当前 `1.2.0+3`）。
- 覆盖安装要求签名一致。v1.1.0 及更早版本使用本机 debug 签名，无法覆盖升级到专用签名版本；首次安装 v1.2.0 前必须卸载旧版，学习进度、真题记录与音频缓存会丢失。
- 后续更新递增 build number，不更换签名。`tools/check.sh` 的 `RELEASE_CERT_SHA256` 断言与 Release 工作流会阻止错误签名的发布。

## 安装

USB 调试方式：

```bash
adb devices
adb install -r app/build/app/outputs/flutter-apk/app-release.apk
```

手动方式：把 `app-release.apk` 传到手机，用文件管理器打开并按提示允许“安装未知应用”。已安装旧版时直接覆盖安装；签名不一致时必须先卸载。

应用内更新：作战室 → 版本与更新 → 检查更新；或等待启动时的静默提示。下载完成后按系统界面提示确认安装。首次使用前需允许本应用安装未知应用。

## TTS 故障排查

系统设置路径（不同厂商名称略有差异）：**设置 → 系统 → 语言和输入法 → 文字转语音输出**（Text-to-speech output）。

1. 确认默认引擎可用，并对引擎执行一次“试听”。
2. 确认已安装中文语音数据；应用不下载、不捆绑语音包。
3. 回到应用打开磨耳朵，播控条诊断行应显示引擎名称与所选语言。
4. 点“试听”朗读固定短句；失败时按 SnackBar 给出的原因处理后重试。
5. 连续 3 条朗读失败会进入“语音引擎无响应”降级态，点“重试”从当前条目继续。
6. 仍无中文语音时，按面板提示安装语音数据后点“重试”重新初始化。

TTS 的任何失败都不会写入条目的三态、标星、复习次数或真题记录。

### DeepSeek 云语音（可选）

1. 打开磨耳朵 → 朗读设置 → 选择 DeepSeek → 填写 API Key → 保存并连接。
2. 音色可选 `stella`（海星，女声）或 `tide`（暗潮，男声）；云端合成不支持调节语速。
3. 首次合成后，音频压制为 AAC/M4A 并保存到应用私有目录 `filesDir/tts_cache`；编码器不可用时回退保存 WAV。同一音色与文本再次朗读直接播放本地文件，不再请求网络。
4. 失败提示对应关系：`401/403` 密钥无效，`400` 文本为空或未通过内容审核，`429` 请求过于频繁，`503` 服务繁忙，`504` 合成超时。按提示处理后可点“重试”。
5. API Key 以明文保存在本机 `SharedPreferences`，不随 Markdown 导出；清除应用数据或卸载会同时删除密钥与音频缓存。
6. 切回“系统语音”即恢复完全离线，不受 DeepSeek 网络错误影响。

## 验收

真机验收清单、环境字段与证据记录见 [docs/device-acceptance.md](docs/device-acceptance.md)。真机音频听感、系统语音设置交互与最终系统安装确认只能人工确认；模拟器用于构建、下载、校验与权限流程回归。

## 已知边界

- 仅面向 Android 个人侧载；仅 arm64-v8a，最低 Android 7.0（API 24）。不做应用商店、AAB、iOS/桌面。
- 应用内更新只下载完整 APK，不做字节级差分包；不做后台下载、静默安装与系统级自动更新。
- 启动检查需要访问 GitHub；可在版本卡关闭，关闭后只保留手动检查。
- 不提供进度备份/恢复、云同步与多设备迁移；卸载或更换签名会丢失本机进度与真题记录。
- 专用 keystore 与密码丢失后，无法再发布可覆盖安装的新版本；脚本会提示备份，但不提供密钥托管。
- DeepSeek API Key 以明文保存在本机 `SharedPreferences`，仅适合个人设备；不提供加密存储与缓存容量管理。
- 不提供后台播放、锁屏播放、蓝牙/耳机路由、音频焦点与通话打断处理。
- 不改学习算法、三态语义、seed 内容、Markdown 协议与四 Tab 信息结构。
