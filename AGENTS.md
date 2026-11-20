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
