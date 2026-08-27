---
tags: [Claude, Anthropic, MCP, AI Agent, 认证考试]
sources: [[../raw/claude-architect-exam-notes.pdf]], [[../raw/claude-architect-guide-en.pdf]]
updated: 2026-08-27
---

# MCP协议与工具设计

对应 [[Claude Certified Architect认证-总览]] 的 Domain 2（占比18%，5个Task Statement）。

## 工具描述是LLM选工具的首要依据

LLM挑选工具**主要依据工具描述本身**，而不是别的什么隐藏机制。描述写得太简单（比如"Retrieves customer information"）在工具功能有重叠时会直接导致选错。

好的工具描述应该包含：
- 这个工具做什么、返回什么
- 接受什么输入格式（附带示例值）
- 什么时候用它（示例查询）
- 什么时候**不**用它（和相似工具的边界）

**工具名称/描述重叠 → 模型分不清**：比如 `analyze_content`（网页搜索agent的工具）和 `analyze_document`（文档分析agent的工具）描述几乎一样，会导致误路由。修复思路是**改名+改描述消除重叠**，比如把 `analyze_content` 改名为 `extract_web_results`，并在描述里明确写"处理并返回来自网页搜索和URL的信息"。这比加路由分类器、加few-shot示例、只改一边描述都更能从根源解决问题。

**拆分泛化工具**：一个 `analyze_document` 做太多事 → 拆成 `extract_data_points` + `summarize_content` + `verify_claim_against_source`，每个工具职责单一、边界清晰。

**System prompt也会影响工具选择**：关键词敏感的指令可能无意中引导agent系统性地选错工具。比如系统提示里写"always verify the customer"这类话，会导致消息里出现"account"这个词时78%概率优先调用 `get_customer`，而不含这个词时93%概率正确调用 `lookup_order`。当**工具描述本身已经清晰无重叠**，但发现某个关键词触发系统性偏差时，要去查system prompt里有没有无意的路由指令，而不是继续改工具描述。

## 工具设计原则

- **消除无效状态**：一个工具接受太多参数组合，其中很多是无效搭配（比如 `log_workout` 有23%的参数搭配错误）→ 拆分为多个更窄的工具（`log_cardio_workout` + `log_strength_workout`）
- **竞态条件合并为原子操作**：两步操作之间存在时间窗口会有竞态风险（比如"查可用时段"和"预约"之间时段可能被别人订走）→ 合并成一个原子工具 `find_and_book_appointment`
- **统一返回schema**：多个数据源格式不同 → 工具内部做格式转换，对agent统一返回一致的schema
- **最小权限原则（Least Privilege）**：工具太通用 → agent会滥用 → 换成功能更窄的工具，例如把什么都能访问的 `fetch_url` 换成只能加载文档格式的 `load_document`
- **工具数量控制**：一个agent挂载的工具太多（比如18个）会让选择可靠性下降 → 缩减到4-5个角色相关的工具

## MCP结构化错误响应（高频考点）

工具调用失败时要**分类返回**，不能统一甩一个"Operation failed"——那样agent根本没法判断该怎么恢复。

| 字段 | 作用 | 示例 |
|---|---|---|
| `isError` | 告诉agent调用失败了 | `true` |
| `errorCategory` | 错误类型 | `transient`（瞬时）/ `validation`（校验）/ `business`（业务规则）/ `permission`（权限） |
| `isRetryable` | 该不该重试 | `true`（超时可重试）/ `false`（业务规则违规不该重试） |
| 人类可读描述 | 给用户看的信息 | "Refund exceeds policy limit" |

四种错误类别对应的行为：
- **Transient**（超时、503、网络故障）：可重试 → 指数退避重试
- **Validation**（输入格式无效、缺必填字段）：不可重试 → 修改请求参数后重试
- **Business**（策略违反、超过阈值）：不可重试 → 向用户解释，提出替代方案
- **Permission**（访问被拒）：不可重试 → 升级给人工

**关键区分（必考）**：
- `isRetryable: false` + 业务规则违规 → agent不要无意义地重试，应直接告知用户
- **"0 results"（查询成功，没匹配上）≠ "timeout"（查询没完成）**——这是两种性质完全不同的结果，coordinator的后续决策也不同：前者是有意义的空结果，后者需要决定重不重试

错误处理的常见反模式：
- 通用状态如"search unavailable" → coordinator没法判断怎么恢复
- **静默吞掉错误（silent skip）**，把空结果当成功返回 → coordinator以为没有匹配项，实际上是失败了，藏错误=最终输出有缺口但没人知道
- 一处失败就中止整个工作流 → 白白丢弃已经拿到的部分结果
- 子agent内部无限重试 → 浪费延迟和资源，正确做法是子agent做1-2次本地恢复，无法解决的再带着尝试过程和部分结果，上抛给coordinator

## `tool_choice` 配置

| 值 | 行为 | 适用场景 |
|---|---|---|
| `{"type": "auto"}` | Claude自己决定用不用工具（可能不调） | 一般对话 |
| `{"type": "any"}` | 必须调用某个工具，但不指定哪个 | 需要保证有结构化输出、但不确定具体走哪个schema时 |
| `{"type": "tool", "name": "xxx"}` | 强制调用指定工具 | 需要保证确定性的执行顺序（比如必须先提取元数据再做后续处理） |

## MCP（Model Context Protocol）

MCP的核心价值是**标准化接口，一次构建、处处复用**：写一个MCP server，所有MCP兼容的AI应用都能直接连接使用。

MCP定义三类主要资源：
1. **Tools**：agent可以调用来执行动作的函数（CRUD、API调用、命令执行）
2. **Resources**：agent可以读取来获取上下文的数据（文档、数据库schema、内容目录），**不需要通过试探性工具调用去发现有什么数据可用**——这是Resources相对于让agent一遍遍试探性调用工具去摸索数据结构的优势
3. **Prompts**：常见任务的预定义提示模板

MCP **不提供**：自动重试、自动鉴权/限流、更快的协议——这些都需要自己在应用层实现。

MCP配置文件：

| 文件 | 作用 |
|---|---|
| 项目级 `.mcp.json` | 团队共享的MCP服务器配置，纳入版本控制 |
| 用户级 `~/.claude.json` | 个人的MCP服务器配置，不共享 |

密钥管理：永远不把secret写死在配置文件里，用 `${ENV_VAR}` 环境变量展开（如 `${GITHUB_TOKEN}`），配置文件本身可以安全提交到仓库，同时在README里说明需要哪个环境变量。

选社区 vs 自建：标准集成（如 Jira、GitHub、Slack）优先用已有的社区MCP server；只有团队专属工作流才值得自建。

MCP工具描述要写详细：描述写太简单 → agent会优先选内置工具（比如Grep）而不用功能更强的MCP工具，因为它分不清MCP工具相对内置工具的具体优势。

## 内置工具选择指南

| 工具 | 用途 | 典型场景 |
|---|---|---|
| `Grep` | 搜索文件内容 | 找函数调用者、定位错误信息、搜import |
| `Glob` | 按文件名/路径匹配 | 找 `**/*.test.tsx` |
| `Read` | 读取完整文件 | 理解文件内容、跟踪import链 |
| `Write` | 创建/完整重写文件 | Edit找不到唯一锚点时的备选方案 |
| `Edit` | 精确替换文件中的**唯一**文本 | 小范围修改 |
| `Bash` | 执行系统命令 | 运行测试、安装依赖 |

**Edit失败处理**：文本不唯一匹配 → 用Read读完整文件 + Write重写（不要死磕Edit）。

代码探索策略（增量式，而非一次性读完所有文件）：Grep找入口（函数定义/export）→ Read跟踪import → Grep找调用位置 → Read消费者文件 → 循环直到形成完整理解。

## 相关
- [[Claude Certified Architect认证-总览]]
- [[Claude Agent SDK-Agentic Loop与多Agent编排]]
- [[Claude Code-配置与工作流]]
- [[Claude Certified Architect-高频考点与决策树]]
