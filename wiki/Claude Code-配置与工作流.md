---
tags: [Claude, Anthropic, Claude Code, 认证考试]
sources: [[../raw/claude-architect-exam-notes.pdf]], [[../raw/claude-architect-guide-en.pdf]]
updated: 2026-08-27
---

# Claude Code：配置与工作流

对应 [[Claude Certified Architect认证-总览]] 的 Domain 3（占比20%，6个Task Statement）。

## CLAUDE.md 三级层级

| 层级 | 位置 | 生效范围 |
|---|---|---|
| 用户级 | `~/.claude/CLAUDE.md` | 只对该用户生效，不共享，不纳入版本控制 |
| 项目级 | `.claude/CLAUDE.md` 或根目录 `CLAUDE.md` | 跟着repo走，团队共享，纳入版本控制 |
| 目录级 | 子目录下的 `CLAUDE.md` | 只对该子目录生效 |

**诊断思路（常考）**：当"部分人有效、部分人无效"（比如新入职同事发现某条团队规范没生效）时 → 规则放错了层级，多半是该放项目级却放到了用户级 `~/.claude/CLAUDE.md`。修复方式是把规则**移到项目级**，而不是让新同事重复声明或清理个人配置。

### `@path` / `@import` 语法（模块化引用）

CLAUDE.md 可以用 `@path` 引用外部文件，保持模块化：

```markdown
Coding standards are described in @./standards/coding-style.md
Test requirements are in @./standards/testing-requirements.md
```

规则：`@` 紧跟文件路径（不留空格）；支持相对和绝对路径；相对路径相对于**包含该import的文件**解析；最大嵌套深度5层。这样每个子包可以只导入和自己相关的规范文件，避免重复。

### `.claude/rules/` 路径规则

太长的CLAUDE.md（比如超过400-500行混杂了编码规范/测试规范/PR审查清单/部署流程/数据库迁移步骤）应该拆到 `.claude/rules/` 下的专题文件，比如 `testing.md`、`api-conventions.md`、`deployment.md`。

**核心机制**：每个规则文件用YAML frontmatter的 `paths` 字段指定glob pattern，**只有编辑匹配的文件时该规则才会被加载**：

```yaml
---
paths: ["src/api/**/*"]
---
For API files, use async/await with explicit error handling.
```

好处：减少无关上下文、节省token；且用glob pattern可以按文件类型应用规范而不管文件散布在哪个目录（比如所有 `**/*.test.tsx`，无论测试文件放在哪个目录，都能统一套用同一套约定）。

## 三选一：Path Rules vs 子目录CLAUDE.md vs Skills（高频考点）

| 机制 | 触发方式 | 适用场景 |
|---|---|---|
| `.claude/rules/`（path rules） | 文件路径匹配（glob pattern），**自动、确定性** | 按文件类型/位置应用不同规范，尤其规范要应用到**散布在多个目录**的文件（如所有测试文件） |
| `.claude/skills/`（skills） | **任务触发**（手动调用或Claude按需加载） | 特定任务的工作流，非"每次编辑都要用" |
| CLAUDE.md（含目录级） | **始终加载**，不区分文件 | 全局通用规则；如果规范只属于**一个目录**，用该目录的CLAUDE.md比path rules更直接 |

判断口诀：看到"自动" + "按文件类型/路径" → path rules；看到"规范只适用于单个目录" → 子目录CLAUDE.md；看到"特定任务才需要、按需触发" → skills。

## Skills vs Commands

Rules 和 Skills 都有 frontmatter，但字段不同：

| | Rules的frontmatter | Skills的frontmatter |
|---|---|---|
| 字段 | `paths`（管哪些文件）、`description` | `context: fork`、`allowed-tools`、`argument-hint` |

Skills的frontmatter详解：

| 字段 | 作用 | 示例 |
|---|---|---|
| `context: fork` | 在隔离的子agent上下文中运行，verbose输出不污染主会话 | 代码分析、头脑风暴/方案探索类的skill |
| `allowed-tools` | 限制skill可用的工具（安全考虑） | 只允许读操作，禁止写/删 |
| `argument-hint` | 没传参数时提示用户输入 | "请输入要分析的文件路径" |

**Commands（`.claude/commands/`）**是纯文本指令，**不支持frontmatter**；**Skills（`.claude/skills/`）= Commands + 超能力**（有frontmatter配置能力，可隔离运行、限制工具、提示参数）。当前版本里两者已经统一，都创建 `/name` 命令，`.claude/commands/` 是旧格式但仍受支持。

配置文件位置总览（万能规律：项目目录下的 = 团队共享/版本控制，`~/` 下的 = 个人专属）：

| 要共享什么 | 项目级（团队共享） | 用户级（个人） |
|---|---|---|
| 指令/规则 | `.claude/CLAUDE.md` | `~/.claude/CLAUDE.md` |
| Skills | `.claude/skills/` | `~/.claude/skills/` |
| Commands | `.claude/commands/` | `~/.claude/commands/` |
| MCP服务器 | `.mcp.json` | `~/.claude.json` |
| Path rules | `.claude/rules/` | — |

**个人定制**：想在不影响团队的前提下自定义团队的skill/command（比如不同的commit message格式），在 `~/.claude/skills/<同名目录>/SKILL.md` 下创建**同名**的个人版本——个人skill会**优先于**项目skill生效，这样既定制了个人工作流又保留了熟悉的命令名，比新建一个不同名字的命令更好。

## Plan Mode vs Direct Execution

| | Plan Mode | Direct Execution |
|---|---|---|
| 适用 | 大规模/跨文件架构变更、需求模糊、多种可行方案、不熟悉的代码库 | 简单、明确、小范围改动，有清晰stack trace的单文件bug |
| 示例 | 微服务重构、45+文件的库迁移、如何定义服务边界 | 加一个日期校验、单文件bug fix |
| 好处 | 只探索和规划、不做改动，先设计再动手，避免返工 | 快速完成 |

组合用法：Plan mode做调研 → 确定方案 → 切Direct execution执行。

**Explore subagent**：verbose探索阶段（比如读几十上百个文件摸清代码结构）用Explore subagent隔离输出 → 主会话只收到精简摘要 → 防止多阶段任务把context window撑爆。

## 迭代精炼技术

三种迭代模式，按场景选择：

| 模式 | 适用场景 | 做法 |
|---|---|---|
| 具体I/O示例 | 自然语言描述导致模型理解不一致（比如"转换成内部格式"，字段嵌套/时间戳格式总不对） | 给2-3个input/output对，比重写更精确的文字描述更有效 |
| 测试驱动迭代 | 复杂实现 | 先写测试 → 分享失败结果 → 逐步修正 |
| Interview Pattern | 不熟悉的领域（金融科技、医疗、法律系统） | 让Claude先提问（缓存失效策略？故障模式？）→ 再实现，用于有非显而易见影响的任务 |

批量 vs 逐个修bug：多个bug互相影响 → 一条消息说清全部问题；多个bug相互独立 → 逐个迭代修复。

## CI/CD 集成

三个CLI flag（递进关系）：

| Flag | 作用 |
|---|---|
| `-p` / `--print` | 非交互模式，CI必加，不加就会挂起等待交互输入 |
| `--output-format json` | 输出JSON格式，程序可解析 |
| `--json-schema` | 强制输出符合指定schema |

```bash
claude -p "分析这个PR" --output-format json --json-schema '{"type":"object"...}'
```

CLAUDE.md 可以给CI提供上下文：在CLAUDE.md里写测试标准、fixture规范、review标准 → CI调用的Claude自动获得这些上下文，不用每次在prompt里重复写。

**会话隔离**：生成代码的同一个Claude session去审查自己的代码，会保留生成时的推理上下文，产生**确认偏差**，不太会质疑自己的决定 → 应该用独立实例审查（详见 [[Prompt Engineering与结构化输出]] 里的Multi-instance Review）。

**避免重复评论**：re-run review时，把之前的findings带上，指示Claude只报告新的或未解决的问题，不要对已经在新commit里修复的代码重复评论。

**提供已有测试文件**：让Claude知道哪些场景已经被测试覆盖 → 生成新测试时不会建议重复的测试用例；同理，在CLAUDE.md里写清测试标准和可用fixture，能显著提升测试生成质量。

## `/compact` 与 `/memory` 命令

- `/compact`：压缩上下文，把之前的历史摘要化以腾出context window空间，用于长时间调查session里工具输出把上下文塞满的场景。**风险**：精确的数值、日期等具体细节在摘要化过程中可能丢失（详见 [[Agent系统-上下文管理与可靠性]]）
- `/memory`：管理跨session的记忆，打开CLAUDE.md供编辑，保存笔记/偏好/上下文，这些信息会在下次启动时自动加载；也用于**验证加载了哪些memory文件**，诊断"跨会话行为不一致"的问题

## 会话管理：`--resume` 与 `fork_session`

详见 [[Claude Agent SDK-Agentic Loop与多Agent编排]] 的"会话状态、恢复与分叉"一节——这两个机制在D1和D3都会考。

## 相关
- [[Claude Certified Architect认证-总览]]
- [[Claude Agent SDK-Agentic Loop与多Agent编排]]
- [[MCP协议与工具设计]]
- [[Prompt Engineering与结构化输出]]
- [[Claude Certified Architect-高频考点与决策树]]
