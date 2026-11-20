# DeepSeek 云语音与可调停顿

## 目标

在保留系统离线语音为默认后端的前提下，增加可选的 DeepSeek 云语音；把题干与结论之间固定的 1.5 秒停顿改为可调设置。合成音频在本机压制为有损格式并保存，同一音色与文本再次朗读时不再请求网络。

## 与既有约束的关系

- 取代 [一页纸实施基线](../one-page-politics/spec.md) §8.4 中“停顿 1.5 秒固定”的约束。
- 取代 [真机交付规格](../one-page-politics-device/spec.md) §2 中“release 合并清单不含 `INTERNET`”的约束：release 现在声明 `INTERNET`，只用于可选的 DeepSeek 后端；系统语音仍不依赖网络。
- 不改四 Tab 信息结构、学习算法、三态语义、seed 内容与 Markdown 协议。

## 功能要求

### 1. 后端与设置

- 默认 `system`：`flutter_tts` 驱动手机自带中文语音，完全离线。
- 可选 `deepseek`：调用 `POST https://api.deepseek.com/v1/tools/tts`。
- 切换后端、音色或保存新 API Key 时，停止当前朗读并重建服务；队列清空，再次播放从当前筛选列表第一条开始。
- 设置保存在 `SharedPreferences`：

| 键 | 含义 | 默认值 |
|---|---|---|
| `tts.backend` | `system` / `deepseek` | `system` |
| `tts.deepseekApiKey` | DeepSeek API Key，保存前去首尾空白 | 空 |
| `tts.deepseekVoiceId` | `stella` / `tide` | `stella` |
| `tts.promptPauseMs` | 题干后停顿，0–5000 毫秒 | 1500 |
| `tts.answerPauseMs` | 结论后停顿，0–5000 毫秒 | 600 |

- API Key 只保存在本机应用数据中，不写入 Markdown 导出；以明文保存，仅适用于个人设备。

### 2. DeepSeek 请求

| 字段 | 值 |
|---|---|
| 方法 | `POST` |
| 地址 | `https://api.deepseek.com/v1/tools/tts` |
| 鉴权 | `Authorization: Bearer <API Key>` |
| 请求体 | `text`、`voice_id`、`format: "wav"`、`filter_markdown: true` |
| 音色 | `stella`（海星，女声，默认）或 `tide`（暗潮，男声） |
| 超时 | 30 秒 |
| 语速 | 不支持；`supportsRate=false`，界面隐藏三档语速控件 |

- 状态码映射：
  - `401` / `403`：`DeepSeek API Key 无效或没有权限`
  - `400`：`DeepSeek 无法朗读该文本（可能为空或未通过内容审核）`
  - `429`：`DeepSeek 请求过于频繁，请稍后重试`
  - `503`：`DeepSeek 服务繁忙，请稍后重试`
  - `504`：`DeepSeek 合成超时`
- 其余状态码显示 `DeepSeek 合成失败（HTTP <code>）`。
- 文本长度由 API 限制（单次最多 10,000 计费字符、请求体 64 KiB）；应用不截断内容，超限时按 API 的错误码显示。
- API Key 不得出现在任何错误文案、日志或导出内容中。

### 3. 本地压制与缓存

- 缓存键：对 UTF-8 字符串 `v1|<voiceId>|<text>` 做 64 位 FNV-1a，输出 16 位小写十六进制。修改缓存格式或音色语义时递增版本前缀。
- 命中：本地已有非空文件时直接播放，不发起 HTTP 请求。
- 未命中：取回 WAV 后解析 RIFF，读取 `fmt ` 与 `data` 块；支持 16 位 PCM、1–2 声道，以及 `WAVE_FORMAT_EXTENSIBLE` 的 PCM 子格式。
- 压制：Android `MediaCodec` 编码 AAC-LC（单声道 48 kbps，双声道 64 kbps），`MediaMuxer` 写入 MPEG-4 容器，扩展名 `.m4a`。
- 存储位置：`filesDir/tts_cache/<key>.m4a`；解析或编码失败时回退保存 `<key>.wav`，仍可播放。
- 写入使用 `.tmp` 文件加原子重命名；已有文件直接复用。
- 暂停、下一条、关闭面板或切换设置发生在 HTTP 或压制期间时，不得在压缩完成后补播；已写入的文件可以保留。
- 本版本不提供缓存容量上限与清理入口；清除应用数据或卸载会删除缓存。

### 4. 停顿

- 题干后停顿：0–5 秒，0.1 秒步长，默认 1.5 秒。
- 结论后停顿：0–5 秒，0.1 秒步长，默认 0.6 秒。
- 修改立即作用于下一次停顿；滑杆释放时写入 `SharedPreferences`。
- 播控条说明文字随设置显示当前秒数，不再硬编码 1.5 秒。

### 5. 播放状态机与失败

- 保留每次播放会话的代次、单列表循环、暂停/继续、上一条/下一条、60 秒 utterance 看门狗与连续 3 条失败降级。
- DeepSeek 的网络、存储或播放失败按单条失败处理；连续 3 条进入“语音引擎无响应”，用户可点“重试”从当前索引继续。
- 用户主动取消（暂停、切条、关闭、切换设置）不计入失败，不写 `lastError`。
- TTS 的任何失败都不写入条目的三态、标星、复习次数或真题记录。

### 6. 实现边界

- Dart 层：`TtsEngine` 接口；`SystemTtsEngine` 与 `DeepSeekTtsEngine` 两个实现；`TtsService` 只负责队列与状态机；`TtsSettings` 负责持久化；`TtsAudioStore` 封装平台通道。
- Android 层：`TtsAudioStore.kt` 使用 `MediaCodec`、`MediaMuxer`、`MediaPlayer`，不新增 pub 依赖。
- 平台通道：`one_page_politics/tts_audio`，方法 `has`、`play`、`storeAndPlay`、`stop`；播放完成与错误回传令牌，Dart 侧忽略过期令牌。
- 主清单增加 `android.permission.INTERNET`。

## 验收

- `flutter analyze` 无问题。
- `flutter test` 全部通过；新增用例覆盖缓存键稳定性、缓存命中/未命中、HTTP 错误与超时、请求期间取消、播放期间取消、设置往返与越界回退、平台通道令牌隔离。
- `./gradlew :app:compileReleaseKotlin` 通过，证明原生压缩与播放代码可以编译。
- 本机以 OpenJDK 27 运行 `./gradlew assembleRelease` 成功，release APK 54,640,110 字节（versionName `1.1.0`，versionCode `2`），SHA-256 `411963a8bbe12d792257bc0a989647155ee4e5aa856f0c7cd7184565612e672c`；`aapt2 dump permissions` 显示 `android.permission.INTERNET`；`classes.dex` 含 `one_page_politics/tts_audio`。
- 真机人工确认：首次合成后 `filesDir/tts_cache` 出现 `.m4a`；同一音色与文本第二次朗读不产生网络请求；暂停后不再出声；两处停顿的听感符合设置。
- 真实 API Key 下的人工项：`401`、`429`、`503`、`504` 的实际提示，内容审核失败，以及按字符计费。

## 已知限制

- DeepSeek 不支持调节语速。
- AAC 压制依赖设备编码器；编码失败会回退保存 WAV，体积更大但可播放。
- API Key 明文保存在 `SharedPreferences`，不加密。
- 没有缓存管理界面；缓存随应用数据清除或卸载删除。
- 网络失败不自动重试；沿用现有“重试”按钮。
