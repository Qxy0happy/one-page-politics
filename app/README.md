# 一页纸政治（one_page_politics）

服务至 2026-12-19 的个人 Android 背诵工具。学习数据保存在本机；默认使用系统离线语音。可选的 DeepSeek 云语音需要网络与 API Key，release 因此声明 `INTERNET` 权限。

功能规格、验收记录与工单保存在本地 `.scratch/` 与 `app/docs/`，不随仓库发布。

## 四个 Tab

| Tab | 用途 |
|---|---|
| 一页纸 | 路径树（科目 → 章节/类型）、条目卡三态（未看/眼熟/模糊）、标星、磨耳朵（系统离线语音或 DeepSeek 云语音，合成音频本地压制缓存） |
| 反射场 | 是非滑卡、帽子配对、双胞胎辨析、政经计算器四类微训练 |
| 工具箱 | 选择题兵法、大题与抄材料两段方法 |
| 作战室 | 双计时器与遍数、真题记录、计时/计分/折线图、导入导出与重置 |

## 构建

环境：Flutter 3.50 / Dart 3.14（`sdk: ^3.14.0`），使用现有 Android SDK 与带 `jlink` 的 JDK；项目不使用代码生成。

```bash
tools/check.sh            # 格式、分析、测试、release 构建与 APK 断言
SKIP_BUILD=1 tools/check.sh  # 只查代码
```

产物为 universal release APK：

```
app/build/app/outputs/flutter-apk/app-release.apk
```

脚本使用 `JAVA_HOME` 指向的 JDK。GraalVM 的 `jlink` 会在 `JdkImageTransform` 失败；此时把 `JAVA_HOME` 指向 Temurin/OpenJDK。CI 使用 Temurin。

构建、权限、签名与版本的核对命令见 [docs/device-acceptance.md](docs/device-acceptance.md) 的“构建与静态检查”。

## 签名与个人侧载

- release 沿用本机 debug 签名（默认 `~/.android/debug.keystore`），仅用于个人手机安装，不可用于商店分发，也不生成 AAB。
- 包名固定为 `com.qxyhappy.one_page_politics`；版本号取自 `pubspec.yaml`（当前 `1.1.0+2`）。
- 覆盖安装要求签名一致：换机器重建时须保留同一 debug keystore，否则只能卸载重装，本机进度会丢失。
- 后续更新递增 build number，不更换签名。

## 安装

USB 调试方式：

```bash
adb devices
adb install -r app/build/app/outputs/flutter-apk/app-release.apk
```

手动方式：把 `app-release.apk` 传到手机，用文件管理器打开并按提示允许“安装未知应用”。已安装旧版时直接覆盖安装。

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
2. 音色可选 `stella`（海星，女声）或 `tide`（暗潮，男声）；云端合成不支持调节语速，界面会隐藏三档语速。
3. 首次合成后，音频压制为 AAC/M4A 并保存到应用私有目录 `filesDir/tts_cache`；编码器不可用时回退保存 WAV。同一音色与文本再次朗读直接播放本地文件，不再请求网络。
4. 失败提示对应关系：`401/403` 密钥无效，`400` 文本为空或未通过内容审核，`429` 请求过于频繁，`503` 服务繁忙，`504` 合成超时。按提示处理后可点“重试”。
5. API Key 以明文保存在本机 `SharedPreferences`，不随 Markdown 导出；清除应用数据或卸载会同时删除密钥与音频缓存。
6. 切回“系统语音”即恢复完全离线，不受 DeepSeek 网络错误影响。

## 验收

真机验收清单、环境字段与证据记录见 [docs/device-acceptance.md](docs/device-acceptance.md)。真机音频听感与系统语音设置交互只能人工确认；模拟器仅用于 UI 与队列回归。

## 已知边界

- 仅面向 Android 个人侧载；默认系统语音离线，可选 DeepSeek 云语音需要网络。不做应用商店、AAB、自动更新与正式签名密钥管理。
- DeepSeek API Key 以明文保存在本机 `SharedPreferences`，仅适合个人设备；不提供加密存储与缓存容量管理。
- 不提供后台播放、锁屏播放、蓝牙/耳机路由、音频焦点与通话打断处理。
- 不提供进度备份/恢复、云同步与多设备迁移。
- iOS 与桌面端不在验收范围。
- 不改学习算法、三态语义、seed 内容、Markdown 协议与四 Tab 信息结构。
