# 一页纸 · 澄潇宇考研政治

个人 Android 背诵工具：把“一页纸”考点做成可逐条刷眼、磨耳朵、微训练的本地应用。学习数据保存在本机；默认使用系统离线语音，可选的 DeepSeek 云语音需要网络与 API Key，release 因此声明 `INTERNET` 权限。

**[下载最新 release](https://github.com/Qxy0happy/one-page-politics/releases/latest)** · 当前版本 `1.2.3+6`（release `v1.2.3`）

## 功能

| Tab | 用途 |
|---|---|
| 一页纸 | 科目 → 章节路径树；549 条考点；未看/眼熟/模糊三态、标星、遮罩回忆、磨耳朵 |
| 反射场 | 是非滑卡、帽子配对、双胞胎辨析、政经计算器四类微训练 |
| 工具箱 | 选择题兵法、大题与抄材料方法 |
| 作战室 | 双计时器与遍数、真题记录、计时/计分折线图、导入导出、版本更新与重置 |

- **路径树**：科目下按章节展开；思修、新思想、时政按“配对 / 判断 / 对比”拆分；记住上次路径。
- **搜索**：只搜当前路径，200 ms 防抖；无结果时可一键“在全部中搜索”。
- **本地优先**：条目、进度、真题记录都在本机；默认系统语音完全离线。DeepSeek 云语音为可选项，仅在使用时访问网络。
- **磨耳朵**：系统语音或 DeepSeek 云语音朗读当前列表；云语音合成音频在本机压制为 AAC/M4A 缓存，同一音色与文本再次朗读不再请求网络。
- **可调停顿**：题干后与结论后的停顿均可在 0–5 秒内调整。
- **应用内更新**：手动检查，或启动时静默检查（最多每 24 小时一次，可关闭）。发现新版本后下载完整 APK，校验 SHA-256、包名、版本号与签名，再调起系统安装器；安装必须由用户在系统界面确认。

## 应用内更新

- 更新源固定为 GitHub Releases 的 `update.json`：

  ```text
  https://github.com/Qxy0happy/one-page-politics/releases/latest/download/update.json
  ```

- `update.json` 包含 `versionCode`、`versionName`、`minSdk`、更新说明，以及 APK 的 `url`、`size`、`sha256`。应用只接受 HTTPS 地址；本地联调可通过编译参数覆盖。
- Android 侧载只接受完整 APK，没有字节级差分包；下载支持 Range 断点续传，失败后可继续，不必从零开始。
- 安装前校验 SHA-256、包名、版本号，以及下载包与已安装应用的签名证书是否一致；任一不一致都拒绝调起安装器。
- 应用声明 `REQUEST_INSTALL_PACKAGES`，并通过 FileProvider 把缓存中的 APK 交给系统安装器。用户仍需在系统界面允许“安装未知应用”并确认安装；应用不会静默安装。
- 启动检查只读取小清单，不自动下载；网络失败不影响学习功能。手动检查会显示失败原因。
- 更新检查失败、签名不一致或系统版本过低时，界面给出明确原因，不会改动学习数据。

## DeepSeek 云语音（可选）

1. 打开磨耳朵 → 朗读设置 → 选择 DeepSeek，填写 API Key 并保存。
2. 音色可选 `stella`（海星，女声）或 `tide`（暗潮，男声）；云端合成不支持调节语速。
3. 合成音频按“音色 + 文本”缓存在应用私有目录 `tts_cache`，优先 AAC/M4A；编码器不可用时回退 WAV。
4. API Key 以明文保存在本机 `SharedPreferences`，不随 Markdown 导出；费用按 DeepSeek 账户的字符计费规则结算。
5. 失败提示：`401/403` 密钥无效，`400` 文本为空或未通过内容审核，`429` 请求过于频繁，`503` 服务繁忙，`504` 合成超时。

## 安装

1. 从 [Releases](https://github.com/Qxy0happy/one-page-politics/releases/latest) 下载 APK（当前为 `one-page-politics-1.2.3.apk`，arm64-v8a，约 20 MB）和 `.sha256`。
2. 在手机上允许“安装未知应用”，打开 APK 安装。
3. 校验：

   ```bash
   sha256sum -c one-page-politics-1.2.3.apk.sha256
   ```

4. 覆盖安装需要签名一致。v1.2.0 起使用专用 release keystore；如果手机上仍是 v1.1.0 或更早的 debug 签名版本，必须先卸载旧版再安装。卸载会删除本机学习进度、真题记录与音频缓存，且应用不提供进度导出。
5. 首次使用磨耳朵前，请在系统设置中安装中文离线语音数据（设置 → 系统 → 语言和输入法 → 文字转语音输出；不同机型名称略有差异）。

## 从源码构建

环境：Flutter 3.50 / Dart 3.14、Android SDK、带 `jlink` 的 JDK 25 或 27（Temurin 或 OpenJDK）。

```bash
git clone https://github.com/Qxy0happy/one-page-politics.git
cd one-page-politics
tools/check.sh
```

`tools/check.sh` 依次执行格式检查、静态分析、测试、release 构建与 APK 断言（版本、权限、FileProvider、ABI、签名）。CI 使用同一脚本；只查代码时设 `SKIP_BUILD=1`（约 10 秒）。

发布包只构建 arm64-v8a：

```bash
TARGET_PLATFORM=android-arm64 tools/check.sh
```

指定签名证书指纹后，脚本会拒绝其他签名的 APK：

```bash
TARGET_PLATFORM=android-arm64 RELEASE_CERT_SHA256=<证书 SHA-256> tools/check.sh
```

产物：`app/build/app/outputs/flutter-apk/app-release.apk`。

脚本使用 `JAVA_HOME` 指向的 JDK。GraalVM 的 `jlink` 会在 `JdkImageTransform` 失败；此时显式指定 OpenJDK：

```bash
JAVA_HOME=/path/to/openjdk tools/check.sh
```

## 发布与更新清单

首次发布前，在本机运行一次签名与 secrets 向导：

```bash
tools/setup-release-key.sh
```

脚本会在 `~/.config/one-page-politics/` 生成专用 PKCS12 keystore 与密码文件，并把以下 GitHub Actions secrets 写入当前仓库：

| Secret | 内容 |
|---|---|
| `KEYSTORE_BASE64` | keystore 的 Base64 |
| `KEYSTORE_PASSWORD` | keystore 密码 |
| `KEY_ALIAS` | key 别名 |
| `KEY_PASSWORD` | key 密码 |
| `RELEASE_CERT_SHA256` | 证书 SHA-256，供 `check.sh` 断言 |

keystore 与密码必须离线备份；丢失后无法再发布可覆盖安装的新版本。脚本会明确提示首次安装需要卸载旧版。

发布步骤：

1. 修改 `app/pubspec.yaml` 的版本名与 build number，两者都要递增（例如 `1.2.2+5` → `1.2.3+6`）。
2. 运行 `TARGET_PLATFORM=android-arm64 RELEASE_CERT_SHA256=<指纹> tools/check.sh`。
3. 提交并推送 `main`，创建附注 tag：`git tag -a v1.2.2 -m "更新说明"`，再 `git push origin v1.2.2`。
4. `Release` 工作流（`.github/workflows/release.yml`）会用专用 keystore 构建 arm64 APK，上传 APK、`.sha256` 与 `update.json` 到对应 release。
5. 工作流会校验 tag 与 `pubspec.yaml` 版本一致，并断言 APK 的签名证书等于 `RELEASE_CERT_SHA256`；任一项不符即失败，不会发布。

`update.json` 由 `tools/make_update_manifest.sh` 生成，结构如下：

```json
{
  "schemaVersion": 1,
  "versionCode": 5,
  "versionName": "1.2.2",
  "minSdk": 24,
  "publishedAt": "2026-11-21T12:00:00Z",
  "notes": "更新说明",
  "apk": {
    "url": "https://github.com/Qxy0happy/one-page-politics/releases/download/v1.2.2/one-page-politics-1.2.2.apk",
    "size": 20260000,
    "sha256": "<64 位十六进制>"
  }
}
```

## 目录

```text
assets/
└── app-icon/icon.jpeg    # 图标源文件（2048×2048）
app/
├── lib/
│   ├── pages/            # 四个 Tab 与微训练页面
│   ├── providers/        # 学习状态、作战室、更新、主题
│   ├── services/         # Markdown 解析、存储、TTS、更新下载与平台通道
│   ├── models/           # 条目、路径、真题、更新清单
│   ├── widgets/          # 条目卡、路径树、TTS 面板、更新对话框
│   └── theme/
├── test/                 # 解析、合并、TTS、更新、路径树与 UI 测试
├── assets/default_sheet.md  # 内置 549 条一页纸
└── android/
.github/workflows/
├── ci.yml                # push / PR 的代码与构建检查
├── flutter-ci.yml        # 可复用工作流；release 为 true 时发布
└── release.yml           # tag 触发的发布
tools/
├── check.sh              # 唯一校验入口
├── make_update_manifest.sh
└── setup-release-key.sh
```

## 版本与边界

- 当前版本：`1.2.3+6`（release `v1.2.3`）；Android 7.0（API 24）及以上，仅 arm64-v8a。
- 仅面向 Android 个人侧载；默认系统语音离线，DeepSeek 云语音需要网络；更新检查需要访问 GitHub，可在作战室关闭启动检查。
- 应用内更新只下载完整 APK，不做字节级差分包；支持断点续传，不做后台下载、静默安装或系统级自动更新。
- v1.2.0 起使用专用 release keystore。v1.1.0 及更早的 debug 签名版本无法覆盖升级，首次安装需要卸载；卸载会丢失本机进度、真题记录与音频缓存。
- 不提供进度备份/恢复、云同步与多设备迁移；keystore 丢失后无法发布可覆盖安装的新版本。
- 不提供后台播放、锁屏播放、蓝牙/耳机路由。
- 不做 iOS/桌面、应用商店、AAB 与正式签名密钥托管。

## 内容来源

内置考点整理自澄潇宇考研政治一页纸，仅供个人备考使用；内容版权归原作者。
