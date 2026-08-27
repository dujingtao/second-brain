---
tags: [Claude, Anthropic, 认证考试, AI Agent]
sources: [[../raw/claude-architect-exam-notes.pdf]], [[../raw/claude-architect-guide-en.pdf]], [[../raw/claude-architect-study-guide.pdf]]
updated: 2026-08-27
---

# Claude Certified Architect — Foundations 认证总览

Anthropic 推出的"solution architect"认证，考察用 Claude Agent SDK / Claude Code / Claude API / MCP 构建生产级应用的实战判断力。题型全部是单选题（4选1），100–1000分制，**720分及格**，猜错不扣分。

## 考试内容：5个Domain

| Domain | 权重 |
|---|---|
| D1 Agentic Architecture & Orchestration（智能体架构与编排） | 27% |
| D2 Tool Design & MCP Integration（工具设计与MCP集成） | 18% |
| D3 Claude Code Configuration & Workflows（Claude Code配置与工作流） | 20% |
| D4 Prompt Engineering & Structured Output（提示工程与结构化输出） | 20% |
| D5 Context Management & Reliability（上下文管理与可靠性） | 15% |

速记口诀：**架构27 提示20 代码20 工具18 可靠15**（前两大 Domain 占比接近一半，是拿分重点）。

5个Domain对应的详细笔记：
- [[Claude Agent SDK-Agentic Loop与多Agent编排]]（D1）
- [[MCP协议与工具设计]]（D2）
- [[Claude Code-配置与工作流]]（D3）
- [[Prompt Engineering与结构化输出]]（D4）
- [[Agent系统-上下文管理与可靠性]]（D5）
- 速查版可参考 [[Claude Certified Architect-高频考点与决策树]]
- 场景7"对话式AI架构模式"的专题笔记见 [[对话式AI架构模式]]

## 考试场景（8选4随机抽取）

1. **Customer Support Agent** — 用 Agent SDK 处理退款/账单纠纷，MCP工具（get_customer / lookup_order / process_refund / escalate_to_human），目标80%+首次解决率
2. **Code Generation with Claude Code** — 代码生成/重构/调试/文档，自定义slash command + CLAUDE.md配置，何时用planning mode
3. **Multi-Agent Research System** — coordinator委派给web研究/文档分析/合成/报告生成等子agent，输出带引用的完整报告
4. **Developer Productivity Tools** — 探索陌生代码库、生成样板代码，内置工具（Read/Write/Bash/Grep/Glob）+ MCP servers
5. **Claude Code for CI/CD** — 集成进CI/CD做自动代码审查/测试生成/PR反馈，需要把误报率降到最低
6. **Structured Data Extraction** — 从非结构化文档提取信息，用JSON schema验证输出，处理边界情况
7. **Conversational AI Architecture Patterns** — 多轮对话系统的上下文窗口管理、跨轮指令持久化、记忆策略、安全执行的工具设计、处理模糊/矛盾的用户输入
8. **Agentic AI Tools** — 官方exam guide里提到但细节尚未公开确认的场景

## 万能判断框架（解题总原则）

解决问题的优先级递进：
1. **先优化 prompt**（写清标准 + 给例子）—— 最简单、最快、成本最低
2. **再调工具/流程**（修描述、拆工具、改工作流）
3. **最后上架构/基础设施**（额外模型、ML分类器、程序级保障）

**唯一例外**：涉及金钱、安全、合规时，跳过前两步直接用程序级保障（hook/前置条件），因为这类失败后果是确定性的，prompt只能给概率性保证。

## 官方文档索引

- Claude API: [Messages](https://platform.claude.com/docs/en/api/messages) | [Tool Use](https://platform.claude.com/docs/en/build-with-claude/tool-use) | [Message Batches](https://platform.claude.com/docs/en/build-with-claude/message-batches)
- Claude Agent SDK: [Overview](https://platform.claude.com/docs/en/agent-sdk/overview) | [Hooks](https://platform.claude.com/docs/en/agent-sdk/hooks) | [Subagents](https://platform.claude.com/docs/en/agent-sdk/subagents) | [Sessions](https://platform.claude.com/docs/en/agent-sdk/sessions)
- [Model Context Protocol](https://modelcontextprotocol.io/)：[Tools](https://modelcontextprotocol.io/docs/concepts/tools) | [Resources](https://modelcontextprotocol.io/docs/concepts/resources) | [Servers](https://modelcontextprotocol.io/docs/concepts/servers)
- Claude Code: [Docs](https://code.claude.com/docs/en/overview) | [CLAUDE.md/Memory](https://code.claude.com/docs/en/memory) | [Skills](https://code.claude.com/docs/en/skills) | [Hooks](https://code.claude.com/docs/en/hooks) | [Sub-agents](https://code.claude.com/docs/en/sub-agents) | [MCP集成](https://code.claude.com/docs/en/mcp) | [GitHub Actions](https://code.claude.com/docs/en/github-actions) | [Headless模式](https://code.claude.com/docs/en/headless)
- [Prompt Engineering Guide](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/overview) | [Extended Thinking](https://platform.claude.com/docs/en/build-with-claude/extended-thinking)

## 考试不涉及的内容（Out of Scope）

模型微调/训练自定义模型、API鉴权/计费、特定编程语言/框架的详细实现、MCP server的部署/托管（基础设施/网络/容器编排）、Claude内部架构/训练过程、Constitutional AI/RLHF、embedding模型/向量数据库实现细节、Computer Use（浏览器/桌面自动化）、Vision图像分析、Streaming API、限流/配额/详细成本计算、OAuth/密钥轮换、云厂商特定配置、性能基准对比、prompt caching实现细节、token计数算法。

## 备考建议

1. 用 Agent SDK 实际搭一个完整agent loop（工具调用+错误处理+会话管理），练习subagent与显式上下文传递
2. 在真实项目里配置 Claude Code：CLAUDE.md层级、`.claude/rules/` 路径规则、带 `context: fork` 和 `allowed-tools` 的skill、MCP server集成
3. 设计并测试MCP工具：写出能区分相似工具的描述，返回带分类和重试标记的结构化错误
4. 搭一个数据抽取pipeline：`tool_use` + JSON schema、验证/重试循环、可选/nullable字段、Batch API批处理
5. 练习prompt工程：为模糊场景加few-shot示例、写明确的审查标准、为大型代码审查设计multi-pass架构
6. 学习上下文管理模式：从冗长输出中提取关键事实、用scratchpad文件、把探索工作委派给subagent
7. 理解升级（escalation）与human-in-the-loop：什么时候该升级（政策空白/用户明确要求/无法推进），以及基于置信度的路由
8. 考前做一遍模拟题，场景和格式与正式考试一致

## 相关
- [[Claude Agent SDK-Agentic Loop与多Agent编排]]
- [[MCP协议与工具设计]]
- [[Claude Code-配置与工作流]]
- [[Prompt Engineering与结构化输出]]
- [[Agent系统-上下文管理与可靠性]]
- [[Claude Certified Architect-高频考点与决策树]]
- [[对话式AI架构模式]]
