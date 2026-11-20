# 一页纸 · 澄潇宇考研政治

离线 Android 背诵工具：把“一页纸”考点做成可逐条刷眼、磨耳朵、微训练的本地应用。数据与语音均在本机，release 不申请网络权限。

**[下载最新 release](https://github.com/Qxy0happy/one-page-politics/releases/latest)** · 当前版本 `v1.0.0`

## 功能

| Tab | 用途 |
|---|---|
| 一页纸 | 科目 → 章节路径树；549 条考点；未看/眼熟/模糊三态、标星、遮罩回忆、磨耳朵 |
| 反射场 | 是非滑卡、帽子配对、双胞胎辨析、政经计算器四类微训练 |
| 工具箱 | 选择题兵法、大题与抄材料方法 |
| 作战室 | 双计时器与遍数、真题记录、计时/计分折线图、导入导出与重置 |

- **路径树**：科目下按章节展开；思修、新思想、时政按“配对 / 判断 / 对比”拆分；记住上次路径。
- **搜索**：只搜当前路径，200 ms 防抖；无结果时可一键“在全部中搜索”。
- **全离线**：条目、进度、真题记录都在本机；release 无 `INTERNET` 权限。
- **磨耳朵**：使用系统 TTS 朗读当前列表；需系统安装中文离线语音数据。

## 安装

1. 从 [Releases](https://github.com/Qxy0happy/one-page-politics/releases/latest) 下载 APK（当前为 `one-page-politics-1.0.0.apk`）和 `.sha256`。
2. 在手机上允许“安装未知应用”，打开 APK 安装。
3. 校验：

   ```bash
   sha256sum -c one-page-politics-1.0.0.apk.sha256
   ```

4. 覆盖安装需要签名一致。当前 release 使用 debug 签名，仅用于个人侧载，不可用于商店分发。
5. 首次使用磨耳朵前，请在系统设置中安装中文离线语音数据（设置 → 系统 → 语言和输入法 → 文字转语音输出；不同机型名称略有差异）。

## 从源码构建

环境：Flutter 3.50 / Dart 3.14、Android SDK、标准 JDK 25（含 `jlink`，如 Temurin）。

```bash
git clone https://github.com/Qxy0happy/one-page-politics.git
cd one-page-politics/app
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

产物：`app/build/app/outputs/flutter-apk/app-release.apk`（universal APK）。

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

- 当前版本：`1.0.0+1`（release `v1.0.0`）。
- 仅面向 Android 离线个人侧载；不做 iOS/桌面、商店分发、AAB、自动更新。
- 不提供云同步、进度备份/恢复与多设备迁移；卸载或更换签名会丢失本机进度。
- 不提供后台播放、锁屏播放、蓝牙/耳机路由。
- 新思想、时政等没有二级标题的科目当前按卡片类型拆分；后续可通过补 seed 二级标题继续细化。

## 内容来源

内置考点整理自澄潇宇考研政治一页纸，仅供个人备考使用；内容版权归原作者。
