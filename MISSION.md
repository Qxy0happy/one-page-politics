# Mission: Matt Pocock 的 Agent Skills 体系

## Why
把一套可组合的工程技能变成驱动编码代理的默认工作方式：面对任务时知道自己在哪个阶段、该敲哪个命令、什么时候该换上下文，而不是把几十个技能当成随机工具箱。

## Success looks like
- 面对任意开发任务，能在半分钟内说出当前阶段与下一个命令。
- 在一个独立的小仓库上，独立跑完一次主线：grill → spec → tickets → implement 一张票。
- 能在阶段边界上按顺序判断 continue / clear / handoff / subagent / compact。
- 能按自己的仓库改造技能（issue tracker、术语表、评审标准），而不是照搬默认配置。

## Constraints
- 运行环境是 omp，技能安装在 `~/.agents/skills`，不是 Claude Code 插件。
- 中文授课，每次一课，控制在十分钟以内。
- 「一页纸」App 项目暂缓，不作为本阶段的练习对象。

## Out of scope
- TypeScript 语言教学（Total TypeScript 的内容）。
- GSD / BMAD / Spec-Kit 等同类框架的对比与迁移。
- 「一页纸」App 的产品实现与 Flutter 细节。
