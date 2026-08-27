---
tags: [Claude, Anthropic, 认证考试, 速查表]
sources: [[../raw/claude-architect-exam-notes.pdf]], [[../raw/claude-architect-guide-en.pdf]], [[../raw/claude-architect-study-guide.pdf]]
updated: 2026-08-27
---

# Claude Certified Architect：高频考点与决策树速查

这是 [[Claude Certified Architect认证-总览]] 下5个Domain笔记（[[Claude Agent SDK-Agentic Loop与多Agent编排]]、[[MCP协议与工具设计]]、[[Claude Code-配置与工作流]]、[[Prompt Engineering与结构化输出]]、[[Agent系统-上下文管理与可靠性]]）的速查合集，用来考前快速过一遍判断逻辑，不重复展开原理。

## 高频考点决策树

**"输出不一致"怎么选？**
→ Prompt有没有清晰的判断标准？
&nbsp;&nbsp;→ 没有 → 精确化标准
&nbsp;&nbsp;→ 有，但执行不统一，题目提到"加了指令但不一致"？→ few-shot examples
&nbsp;&nbsp;→ 遗漏是动态变化的？→ 自我审查（Evaluator-Optimizer）

**"工具选错了"怎么选？**
→ 工具描述/名字是否清晰、无重叠？
&nbsp;&nbsp;→ 不清晰/有重叠 → 修描述/改名
&nbsp;&nbsp;→ 清晰，但特定关键词触发系统性偏差 → 查system prompt
&nbsp;&nbsp;→ 清晰，但模糊场景选错 → few-shot（针对模糊场景+展示推理）

**"要不要升级给人工"怎么选？**
→ 有没有政策/规则覆盖这个情况？
&nbsp;&nbsp;→ 没有（政策空白）→ 升级
&nbsp;&nbsp;→ 有标准流程 → 不升级，agent自己处理
→ 后果是否涉及金钱/安全？→ 是 → 程序级保障（不是升级，是硬限制）

**"Prompt够还是要程序保障"怎么选？**
→ 错误后果严重吗？
&nbsp;&nbsp;→ 格式/风格/效率问题 → Prompt优化够了
&nbsp;&nbsp;→ 金钱/安全/身份验证 → 程序级硬限制（Hook / 前置条件）

**"该用什么配置机制"怎么选？**
→ 规则是否始终适用？→ 是 → CLAUDE.md
→ 只在特定文件类型/路径适用 → path rules（`.claude/rules/`）
→ 只在特定任务时需要 → skills（`.claude/skills/`）
→ 谁需要这个规则？团队所有人 → 项目级（`.claude/`）；只有自己 → 用户级（`~/`）

**"输出太多/上下文爆了"怎么选？**
→ 子agent输出太多 → 源头过滤（让子agent返回结构化关键信息，而非加中间摘要agent）
→ skill输出太verbose → `context: fork` 隔离
→ 代码探索输出太多 → Explore subagent
→ 长对话丢关键信息 → case facts块持久化

## 解决问题的优先级（万能判断框架）

1. **先优化prompt**（写清标准+给例子）—— 最简单、最快、成本最低
2. **再调工具/流程**（修描述、拆工具、改工作流）
3. **最后上架构/基础设施**（额外模型、ML分类器、程序级保障）

例外：涉及金钱、安全、合规时直接上程序级保障，跳过前两步。

## 易混淆概念对比速查

| 概念A | 概念B | 区别 |
|---|---|---|
| Hook | Tool | Hook自动确定性 vs Tool是Claude主动选择、概率性 |
| `isRetryable: true` | `isRetryable: false` | 超时可重试 vs 业务规则违规不要重试 |
| "0 results" | "timeout" | 查询成功无匹配 vs 查询失败没完成 |
| Plan Mode | Direct Execution | 复杂/模糊/跨文件 vs 简单/明确/单文件 |
| `tool_choice: "any"` | `tool_choice: "auto"` | 必须调工具 vs 可能不调 |
| Path Rules | 子目录CLAUDE.md | 跨目录按文件类型 vs 单目录全局 |
| Skills | Commands | 有frontmatter超能力 vs 纯文本 |
| `context: fork` | Explore subagent | 反复使用的隔离skill vs 临时探索任务 |
| 升级（escalation） | 程序保障（hook） | 需要人判断（政策空白）vs 需要100%执行的规则 |
| Sync API | Batch API | 实时阻塞 vs 24h处理窗口换50%折扣 |
| Few-shot | JSON Schema | 教Claude怎么做（语义/推理层面）vs 验证做得对不对（语法层面） |
| 精确化标准 | Few-shot | 没标准先加标准 vs 有标准但执行不一致才加例子 |
| `--resume` | 新会话+摘要 | 上下文大部分有效 vs 旧的工具结果已过期 |

## 基础概念速查

| 术语 | 解释 |
|---|---|
| Agentic Loop | Claude自主循环（用工具→看结果→再用工具…）直到 `stop_reason: "end_turn"` |
| `stop_reason` | API返回的循环控制信号："tool_use"继续 / "end_turn"结束 / "max_tokens"截断 / "stop_sequence"按逻辑处理 |
| Hub-and-spoke | coordinator中心辐射架构，子agent不直接通信 |
| Task tool | Agent SDK中生成子agent的工具 |
| `AgentDefinition` | 子agent的配置（name/description、system_prompt、allowed_tools） |
| `fork_session` | 从共享分析基线创建独立探索分支 |
| Atomic Operation | 一步完成、中间不可打断的操作，用于避免竞态条件 |
| Confirmation Bias | 倾向于支持自己已有的判断；同session生成+审查=确认偏差 |
| Graceful Degradation | 部分功能失败时用已有数据继续工作，同时标明覆盖缺口 |
| Least Privilege | 给agent的工具/权限只够做它该做的事 |
| Prompt Chaining | 固定顺序的多步骤流水线，适合可预测的重复性任务 |
| Dynamic Decomposition | 根据中间发现动态生成子任务，适合开放式探索 |
| MCP Resources | MCP暴露的内容目录，让agent知道有什么数据可用，不用试探性调用去发现 |
| `custom_id` | Batch API中关联请求和响应的标识符 |
| `detected_pattern` | 结构化finding中记录触发代码模式的字段，用于系统性分析误报 |
| `@import` / `@path` | CLAUDE.md中引用外部文件的语法，保持配置模块化 |
| Lost in the Middle | LLM对长输入的开头结尾关注度高，中间内容容易漏 |

## 考试基本信息

- 5个Domain权重：D1智能体架构27% / D2工具设计与MCP 18% / D3 Claude Code配置20% / D4提示工程20% / D5上下文与可靠性15%
- 全选择题，单选，猜错不扣分 → 不会就猜，别空着
- 及格线：720/1000
- 8个场景随机抽4个：客服Agent、Claude Code代码生成、多Agent研究系统、开发者工具、CI/CD集成、结构化数据提取、对话式AI架构模式、Agentic AI Tools（细节未公开）

## 相关
- [[Claude Certified Architect认证-总览]]
- [[Claude Agent SDK-Agentic Loop与多Agent编排]]
- [[MCP协议与工具设计]]
- [[Claude Code-配置与工作流]]
- [[Prompt Engineering与结构化输出]]
- [[Agent系统-上下文管理与可靠性]]
