---
tags: [Claude, Anthropic, AI Agent, Agent SDK, 认证考试]
sources: [[../raw/claude-architect-exam-notes.pdf]], [[../raw/claude-architect-guide-en.pdf]], [[../raw/claude-architect-study-guide.pdf]]
updated: 2026-08-27
---

# Claude Agent SDK：Agentic Loop 与多Agent编排

对应 [[Claude Certified Architect认证-总览]] 的 Domain 1（占比27%，7个Task Statement，是分值最大的部分）。

## Agentic Loop（自主循环机制）

Claude 不是一次性回答，而是自己循环执行：发请求 → 收到响应 → 检查 `stop_reason` → 如果是工具调用就执行并把结果传回继续循环，如果任务完成就结束。

```
你发请求给 Claude → Claude 返回响应 → 检查 stop_reason
"tool_use" → 执行工具 → 结果传回 Claude → 继续循环
"end_turn" → 任务完成 → 回复给用户
```

`stop_reason` 字段的四个取值：
- `"tool_use"` → Claude 想用工具 → 执行并继续
- `"end_turn"` → 回答完成 → 结束
- `"max_tokens"` → 达到token上限 → 响应被截断，可能需要提高上限
- `"stop_sequence"` → 遇到停止序列 → 按应用逻辑处理

`"tool_use"` 和 `"end_turn"` 是控制循环最关键的两个值。**这是一种模型驱动（model-driven）的方式**：由 Claude 根据上下文和工具结果决定下一步做什么，区别于硬编码的固定决策树。

**三大反模式（必考，看到就排除）**：
- 不要用自然语言解析判断循环终止（比如检测 "Is there anything else?" / "Task completed" 这类文本）
- 不要靠最大迭代数（如 `max_iterations=5`）作为**主要**停止机制
- 不要检查 assistant 是否生成了文本内容作为完成标志

速记：**`stop_reason` 是唯一正确的循环控制信号**。

## Coordinator-Subagent 模式（Hub-and-Spoke架构）

多agent系统通常搭建成中心辐射（hub-and-spoke）拓扑：coordinator 是中央枢纽，管所有 subagent 的通信、错误处理、信息路由；**子agent之间不直接通信**。

Coordinator 职责：任务分解 → 委派 → 结果聚合与验证 → 错误处理与重试 → 决定下一步 → 汇总给用户。

三个关键规则：
1. coordinator 必须明确划分研究空间，给每个subagent分配**不重叠**的范围（按子话题或数据源类型分），避免重复劳动、浪费token
2. coordinator 应**动态选择**调用哪些subagent，而不是每次都走完整流水线
3. coordinator 可以做迭代精炼循环：评估合成结果 → 发现缺口 → 重新派子agent补充 → 直到覆盖充分

**保持coordinator作为中心枢纽的价值**：集中观测所有交互、统一错误处理、精细控制每个subagent能拿到什么信息——这是star型拓扑的核心优势，让subagent之间跳过coordinator直连会失去这些保障。

### 子agent的上下文隔离（关键原则）

子agent的上下文是**隔离**的：
- 不会自动继承coordinator的对话历史
- 所有必要上下文必须**显式**写进subagent的prompt里
- 子agent之间不共享记忆，多次调用之间也不共享

上下文传递最佳实践：
- 把前序agent的**完整发现**直接放进子agent prompt（如：搜索结果 + 文档分析 → 传给合成agent），不要只给一句摘要
- 用结构化格式**分离内容和元数据**（source URL、文档名、页码），保留引用归属
- coordinator prompt 应指定**研究目标和质量标准**，而不是逐步操作指令 → 让子agent自适应

### Task 工具与并行生成

`Task` 工具是 Agent SDK 中用来生成子agent的机制：
- coordinator 的 `allowedTools` 必须包含 `"Task"` 才能调用子agent
- **并行生成子agent**：coordinator 在一轮响应中发出多个 `Task` 调用 → 并行执行，不要一个一个分多轮发（这样会白白增加延迟）

`AgentDefinition` 配置对象定义每种子agent：`name`/`description`（识别与描述）、`system_prompt`（行为指令）、`allowed_tools`（工具限制，遵循最小权限原则）。

```python
agent = AgentDefinition(
    name="customer_support",
    description="Handles customer requests for returns and order issues",
    system_prompt="You are a customer support agent...",
    allowed_tools=["get_customer", "lookup_order", "process_refund", "escalate_to_human"],
)
```

### Scoped Tool（有限工具授权）

子agent频繁需要验证简单事实时，可以给它一个受限的小工具（如 `verify_fact`），让它自己解决大部分（比如85%）简单查询，复杂验证仍然走coordinator。这是最小权限原则在多agent场景的应用：既减少了往返延迟，又不放开全部权限给子agent。

## 多步工作流：Prompt保障 vs 程序级保障

这是全场景通用的**核心判断题**：

| 后果 | 方案 | 可靠性 |
|---|---|---|
| 格式不一致、回复质量波动 | Prompt 优化 | 概率性（>90%，不到100%，够用） |
| 退错款、认错人、安全漏洞 | 程序级硬限制（hook/前置条件） | 确定性（100%，必须） |

速记：**prompt 是"建议"，程序是"法律"**。

程序级前置条件示例：`process_refund` 被阻塞，直到 `get_customer` 返回已验证的 customer ID → 没验证就根本调不了退款工具。这种**架构级**的强制顺序（比如"预览-执行"两个工具，执行工具必须携带预览工具生成的一次性token）比"改prompt让agent记得先验证"或"加时间窗口校验"更可靠，因为它让违规操作在代码层面变得不可能，而不是依赖LLM遵守指令。

多问题请求拆解：客户一条消息里提多个问题 → 拆成独立项 → 用共享上下文并行调查 → 合成统一回复。

结构化交接摘要（升级给人工时）：必须包含 customer ID、问题根因、退款金额、已采取的操作、建议操作——人工接手后**不需要**再读整段对话，因为人工看不到完整对话记录，只看得到这个摘要。

## Agent SDK Hooks（确定性拦截）

Hook = 在特定事件发生时**自动执行**的代码，确定性的，Claude 控制不了、也不知道。

| Hook类型 | 触发时机 | 用途 | 示例 |
|---|---|---|---|
| `PreToolUse` | 工具执行之前 | 权限检查、参数验证、阻止高风险操作 | 退款 > $500 → 拦截 → 转人工 |
| `PostToolUse` | 工具执行之后 | 结果转换、格式统一 | Unix时间戳 → ISO 8601 人类可读格式；多个MCP工具的日期格式不一致时统一格式 |

**Hook vs Tool 的区别（必考）**：
- Hook = 自动触发，确定性，Claude都不知道发生了
- Tool = Claude主动选择调用，概率性，可能选错或忘了用

什么时候选Hook而非Prompt：业务规则需要100%执行（钱、安全、合规）→ Hook；格式偏好、风格要求 → Prompt就够。

`PostToolUse` hook也常用于**从源头裁剪冗余字段**：比如 `lookup_order` 返回40+字段但只需要5个，用hook只保留相关字段返回给agent，节省上下文（这也是 [[Agent系统-上下文管理与可靠性]] 里"源头过滤优于中间摘要agent"原则的具体实现）。

## 任务分解策略

| 模式 | 适用场景 | 示例 |
|---|---|---|
| **Prompt Chaining**（固定流水线） | 可预测的、重复性的多步骤任务 | per-file 分析 → cross-file 整合；文档→元数据提取→数据提取→验证→输出 |
| **Dynamic Decomposition**（动态分解） | 开放式探索任务，全貌未知 | 先扫描结构 → 发现重点 → 动态生成子任务；边做边根据中间发现调整 |

**Multi-pass Review（高频考点）**：大PR一次性单pass审查全部文件 → 注意力稀释（attention dilution）→ 前后矛盾（同样的代码模式，一个文件被标记有问题，另一个文件却放过）→ 应该拆成：
- **per-file local pass**：找局部bug，保证每个文件分析深度一致
- **cross-file integration pass**：找跨文件数据流问题、类型不一致、循环依赖

反例（都不对）：切换到更大context窗口的模型一次读完全部文件（大context不能修复"注意力质量"问题）；要求开发者把大PR拆成3-4个文件提交（转嫁负担，没解决系统问题）；跑三次全量review取多数票（会压制真实bug，因为检测本身就不稳定）。

## 会话状态、恢复与分叉

| 机制 | 用途 | 适用场景 |
|---|---|---|
| `--resume <session-name>` | 恢复命名会话 | 跨工作时段继续同一个调查 |
| `fork_session` | 从共享分析基线创建独立探索分支 | 对比两种重构方案（如Redux vs Context API），两个分支共享分叉点之前的上下文，之后独立发展 |
| 新会话 + 注入摘要 | 从头开始但带上下文 | 旧工具结果已过期（比如代码改了） |

选择决策：
- 之前的上下文大部分还有效 → `--resume`
- 之前的工具结果已过期（代码改了）→ 新会话 + 结构化摘要更可靠
- 恢复后有文件改动 → 告诉agent具体改了哪些文件，做定向重分析，而非全部重来

## 相关
- [[Claude Certified Architect认证-总览]]
- [[MCP协议与工具设计]]
- [[Claude Code-配置与工作流]]
- [[Agent系统-上下文管理与可靠性]]
- [[Claude Certified Architect-高频考点与决策树]]
