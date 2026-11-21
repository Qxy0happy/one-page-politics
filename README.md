# 一页纸 · 澄潇宇考研政治

个人 Android 背诵工具：把“一页纸”考点做成可逐条刷眼、磨耳朵、微训练的本地应用。学习数据保存在本机；默认使用系统离线语音，可选的 DeepSeek 云语音需要网络与 API Key，release 因此声明 `INTERNET` 权限。

**[下载最新 release](https://github.com/Qxy0happy/one-page-politics/releases/latest)** · 当前版本 `v1.1.0`

## 功能

| Tab | 用途 |
|---|---|
| 一页纸 | 科目 → 章节路径树；549 条考点；未看/眼熟/模糊三态、标星、遮罩回忆、磨耳朵 |
| 反射场 | 是非滑卡、帽子配对、双胞胎辨析、政经计算器四类微训练 |
| 工具箱 | 选择题兵法、大题与抄材料方法 |
| 作战室 | 双计时器与遍数、真题记录、计时/计分折线图、导入导出与重置 |

- **路径树**：科目下按章节展开；思修、新思想、时政按“配对 / 判断 / 对比”拆分；记住上次路径。
- **搜索**：只搜当前路径，200 ms 防抖；无结果时可一键“在全部中搜索”。
- **本地优先**：条目、进度、真题记录都在本机；默认系统语音完全离线。DeepSeek 云语音为可选项，仅在使用时访问网络。
- **磨耳朵**：系统语音或 DeepSeek 云语音朗读当前列表；云语音合成音频在本机压制为 AAC/M4A 缓存，同一音色与文本再次朗读不再请求网络。
- **可调停顿**：题干后与结论后的停顿均可在 0–5 秒内调整。

## DeepSeek 云语音（可选）

1. 打开磨耳朵 → 朗读设置 → 选择 DeepSeek，填写 API Key 并保存。
2. 音色可选 `stella`（海星，女声）或 `tide`（暗潮，男声）；云端合成不支持调节语速。
3. 合成音频按“音色 + 文本”缓存在应用私有目录 `tts_cache`，优先 AAC/M4A；编码器不可用时回退 WAV。
4. API Key 以明文保存在本机 `SharedPreferences`，不随 Markdown 导出；费用按 DeepSeek 账户的字符计费规则结算。
5. 失败提示：`401/403` 密钥无效，`400` 文本为空或未通过内容审核，`429` 请求过于频繁，`503` 服务繁忙，`504` 合成超时。

## 安装

1. 从 [Releases](https://github.com/Qxy0happy/one-page-politics/releases/latest) 下载 APK（当前为 `one-page-politics-1.1.0.apk`）和 `.sha256`。
2. 在手机上允许“安装未知应用”，打开 APK 安装。
3. 校验：

   ```bash
   sha256sum -c one-page-politics-1.1.0.apk.sha256
   ```

4. 覆盖安装需要签名一致。当前 release 使用 debug 签名，仅用于个人侧载，不可用于商店分发。
5. 首次使用磨耳朵前，请在系统设置中安装中文离线语音数据（设置 → 系统 → 语言和输入法 → 文字转语音输出；不同机型名称略有差异）。

## 从源码构建

环境：Flutter 3.50 / Dart 3.14、Android SDK、带 `jlink` 的 JDK 25 或 27（Temurin 或 OpenJDK）。

```bash
git clone https://github.com/Qxy0happy/one-page-politics.git
cd one-page-politics
tools/check.sh
```

`tools/check.sh` 依次执行格式检查、静态分析、测试、release 构建与 APK 断言（权限、TTS 查询、签名、SHA-256），CI 使用同一脚本；只查代码时设 `SKIP_BUILD=1`。

产物：`app/build/app/outputs/flutter-apk/app-release.apk`（universal APK）。

脚本使用 `JAVA_HOME` 指向的 JDK。GraalVM 的 `jlink` 会在 `JdkImageTransform` 失败；此时显式指定 OpenJDK：

```bash
JAVA_HOME=/path/to/openjdk tools/check.sh
```

## 目录

```text
app/
├── lib/
│   ├── pages/            # 四个 Tab 与微训练页面
│   ├── providers/        # 学习状态、作战室、主题
│   ├── services/         # Markdown 解析、存储、TTS、合并导出
│   ├── models/           # 条目、路径、真题
│   ├── widgets/          # 条目卡、路径树、TTS 面板
│   └── theme/
├── test/                 # 解析、合并、TTS、路径树与 UI 测试
├── assets/default_sheet.md  # 内置 549 条一页纸
└── android/
```

## 版本与边界

- 当前版本：`1.1.0+2`（release `v1.1.0`）。
- 仅面向 Android 个人侧载；默认系统语音离线，DeepSeek 云语音需要网络。不做 iOS/桌面、商店分发、AAB、自动更新。
- API Key 以明文保存在本机 `SharedPreferences`；音频缓存占用应用私有存储，暂无清理入口。
- 不提供云同步、进度备份/恢复与多设备迁移；卸载或更换签名会丢失本机进度。
- 不提供后台播放、锁屏播放、蓝牙/耳机路由。
- 新思想、时政等没有二级标题的科目当前按卡片类型拆分；后续可通过补 seed 二级标题继续细化。

## 内容来源

内置考点整理自澄潇宇考研政治一页纸，仅供个人备考使用；内容版权归原作者。
