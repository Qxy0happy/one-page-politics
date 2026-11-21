## Agent skills

### Issue tracker

Issues and specs live as markdown files under `.scratch/<feature>/` in this repo. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage roles map to the default label strings. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: root `GLOSSARY.md` plus `docs/adr/`. See `docs/agents/domain.md`.

## 工具链与安装

- 不得静默安装、下载或升级工具链组件：JDK、Android SDK/NDK/CMake/platforms/build-tools、Gradle 发行包、系统包、字体、模拟器镜像等。
- 需要安装时，先说明名称、版本、来源、大小、影响与回退方式，并用 `ask` 获得同意；批准后再执行。
- 构建工具若仍尝试自动安装，立即停止，并在报告中列出安装了哪些组件；不得把自动安装当作没有发生。
- 不得擅自修改全局工具链配置（`flutter config`、`~/.gradle/gradle.properties`、`JAVA_HOME` 等）；需要修改时先说明并征得同意。
- 删除或降级工具链同样需要确认。

## 校验

`tools/check.sh` 是唯一校验入口：格式、分析、测试、release 构建与 APK 断言；`.github/workflows` 调用同一脚本。提交前运行；只查代码时设 `SKIP_BUILD=1`（约 10 秒）。

`lefthook.yml` 为 git CLI 提供 pre-commit（只查代码）与 pre-push（完整）两个钩子。`jj git push` 不执行 git hooks，推送前仍需运行 `tools/check.sh`。

`flutter` 与 `adb` 在 PATH；`JAVA_HOME` 需指向带 `jlink` 的 JDK——GraalVM 的 `jlink` 会在 `JdkImageTransform` 失败。

## 版本控制

jj colocated 仓库：改动完成后依次 `jj describe`、`jj bookmark set main -r @`、`jj git push --bookmark main`。`origin` 是公开仓库。

子代理开工前先 `jj new`：`jj describe` 只改当前提交的描述，直接在同一提交上编辑会改写共享基线。

## 发布范围

公开仓库只放代码与门禁：`app/`、`.github/`、`tools/`、`assets/`、`docs/`、`README.md`、`AGENTS.md`、`GLOSSARY.md`、`lefthook.yml`、`skills-lock.json`、`.gitignore`。

课程转写 `srt/`、内部工单与规格 `.scratch/`、语料 `澄潇宇一页纸/`、教学笔记 `learning-records/`、`lessons/`、`reference/` 只保留在本地：`.gitignore` 忽略它们，`tools/check.sh` 校验它们未被跟踪。
