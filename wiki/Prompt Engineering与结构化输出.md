---
tags: [Claude, Anthropic, Prompt Engineering, 认证考试]
sources: [[../raw/claude-architect-exam-notes.pdf]], [[../raw/claude-architect-guide-en.pdf]], [[../raw/claude-architect-study-guide.pdf]]
updated: 2026-08-27
---

# Prompt Engineering 与结构化输出

对应 [[Claude Certified Architect认证-总览]] 的 Domain 4（占比20%，6个Task Statement）。

## Prompt优化的层级递进（必考，反复出现）

遇到"输出不一致"类问题，按下面这个顺序判断该用哪一层手段：

1. **第一层：Prompt模糊（没有判断标准）** → 精确化标准（explicit criteria）。比如"check comments for accuracy, be conservative"这种话没用，要换成"仅当注释描述的行为与代码实际行为矛盾/引用不存在的函数/TODO指向已修复的bug时才标记；不要标记纯粹过时的措辞、轻微用词不准确、缺失注释（这是另一类）"这种可执行的具体标准
2. **第二层：标准清楚但执行不一致** → few-shot examples（给具体示例示范，包括推理过程）
3. **第三层：动态变化的遗漏（每次缺的不一样）** → 自我审查（Evaluator-Optimizer pattern）

关键词快速判断：
- 题目说"no clear criteria"/prompt模糊 → 选精确化标准
- 题目说"instructions already added but inconsistent"（已经加了指令但还是不一致）→ 选few-shot
- 题目说"gaps vary by case"（遗漏内容每次不一样）→ 选自我审查

**False Positive管理**：高误报率 + 用户对系统信任崩塌 → 先临时**关掉**高误报的类别（止血），保留高精度类别，等改好了再重新启用；"be conservative"/"only report high-confidence"这种模糊指令解决不了问题，必须换成具体的分类标准（比如给每个severity等级配代码示例）。

## Few-shot Examples 设计原则

三个设计原则：
1. **针对出错场景**——不要教模型已经会的东西，示例应该聚焦在容易出错/模糊的场景
2. **展示推理过程**——不只给答案，给"为什么选这个"（rationale），这样模型能学到判断逻辑而不只是死记硬背具体case
3. **数量精而不多**——2-4个精准示例 > 10-15个泛泛示例

Few-shot能做的事：模糊场景下的工具选择（展示推理过程）；区分可接受的代码模式 vs 真正的问题（减少误报）；不同文档结构的正确提取方式（内联引用 vs 参考文献列表）；减少提取任务中的幻觉（比如非正式度量单位"a pinch of salt"→"~1g"这种没有严格规则可循的换算）。

**Few-shot不是万能药（速记：先排除再上few-shot）**：
- 基础标准没有 → 先精确化标准，不是给例子
- 工具描述/名字本身有重叠问题 → 先修描述/改名
- 涉及钱/安全 → 程序级保障，不靠例子
- 动态遗漏（每次缺的不一样）→ 自我审查
- system prompt里有无意的路由指令 → 先查system prompt

## 结构化输出：JSON Schema + Tool Use

**最可靠的结构化输出方式**：定义一个带JSON schema的tool，用 `tool_use` 强制结构化输出。

**关键区分**：`tool_use` 消除的是**语法错误**，不是**语义错误**！
- ✅ 消除：JSON格式错误、必填字段缺失、字段类型错误
- ❌ 不消除：行项目求和不等于total、值被填到了错误的字段、幻觉编造的数值

`tool_choice` 与结构化输出的搭配：

| 场景 | 用什么 |
|---|---|
| 多个提取schema，不确定文档类型 | `tool_choice: "any"` |
| 必须先提取元数据，再做后续处理 | `tool_choice: {"type": "tool", "name": "extract_metadata"}` |
| 一般对话 | `tool_choice: "auto"` |

### Schema设计要点

- 字段值**不一定**在源文档中出现 → 设为nullable（`["string", "null"]`），**不要**设为required → 防止模型为了填满必填字段而编造数值
- 情感判断不了（比如讽刺）→ 加 `"unclear"` 这个enum选项，诚实地承认判断不了比强行分错类更好
- 需要保留扩展性 → `"other"` + detail string字段，避免超出预定义类别的数据被丢弃
- 格式不统一的源数据 → 在prompt里加格式标准化规则（比如日期统一转ISO 8601、"five bucks"转成 `{"amount": 5, "currency": "USD"}`、"half"转成0.5）

**自动交叉校验**：加 `calculated_total`（行项目求和）+ `stated_total`（文档上写的数值），两者不匹配时标记 `conflict_detected: true`，交给人工审查。这是让模型自己检测内部矛盾的自校验模式。

## 验证、重试与反馈循环

**验证失败重试**：直接重试等于重复同样的错误 → 必须把原始文档 + 失败的提取结果 + **具体的**验证错误信息都带上再试（比如"Field 'total' = 150, but sum(line_items) = 145. Re-check values."），而不是笼统地说"重新提取一遍"。

**重试的局限**：
- 有效：格式错误（日期格式不对）、结构错误（字段填错位置）、算术不一致（模型可以自己重算校验）
- 无效：信息根本不在提供的文档里；所需上下文在另一份没提供的文档中——重试再多次也没用，要能识别出这种"重试无效"的情况

`detected_pattern` 字段：在结构化finding里加入这个字段，记录是什么代码模式触发了这条finding。这样当开发者dismiss某条finding时，可以系统性分析出误报模式（比如"某个detected_pattern对应的finding总是被开发者拒绝，说明这条规则该调整了"）。

## Message Batches API

| | Synchronous API | Batch API |
|---|---|---|
| 延迟 | 实时响应 | 最长24小时，**没有延迟SLA保证** |
| 成本 | 全价 | 50%折扣 |
| 是否支持多轮工具调用 | 支持 | **不支持**（一个request对应一个response，无法在request中途执行工具再继续，属于fire-and-forget） |
| 适用 | 阻塞工作流（比如pre-merge检查，开发者在等） | 非阻塞、延迟可容忍（夜间报告、每周审计、批量处理海量文档） |

**三大限制**：①不能等的工作流不能用；②需要多轮工具调用/中途交互的工作流不能用；③没有延迟SLA（最长24h，不是保证快，不能假设"通常几分钟就好"）。

`custom_id` 字段：每个batch request带一个 `custom_id`，用于关联请求和响应；失败时可以只重新提交失败的那部分（通过 `custom_id` 识别出哪些失败了），不用重新处理已成功的。

批次调度举例：如果30小时内要出结果，而处理窗口最长24小时，那么提交窗口 = 30-24 = 6小时，也就是必须提前至少24小时提交批次；如果要频繁提交，可以拆成更小的提交窗口（比如每4-6小时提交一批）。

大批量处理策略：先用小样本优化prompt → 确认效果后全量用Batch API提交 → 失败的逐批重试。

## Multi-instance 与 Multi-pass Review（必考）

**自我审查的局限**：同一个session既生成代码又审查代码 → 模型保留了生成时的推理上下文 → 产生确认偏差（confirmation bias）→ 不太会质疑自己当初的决定，即使它当时其实考虑过风险场景。

**解法**：用**独立的Claude实例**（没有生成时的推理上下文）去审查，这种"新鲜眼光"能捕捉到原作者已经"合理化"过的问题，类似人类同行评审中另一个人来看的价值。

**Multi-pass Review**：大PR单pass审查 → 注意力稀释 + 前后矛盾 → 拆成per-file local pass（找局部问题，保证深度一致）+ cross-file integration pass（找跨文件数据流问题）。

**置信度自报**：让模型对每条finding自报置信度分数 → 实现校准化的review路由（比如高置信度的可以自动处理，低置信度的排优先人工看）。

**关键词敏感偏差**：工具描述本身没问题、但选择出现系统性偏差（比如某个关键词出现时78%选错）→ 应该去查system prompt里有没有无意的路由指令，而不是继续调工具描述。

## 相关
- [[Claude Certified Architect认证-总览]]
- [[Claude Agent SDK-Agentic Loop与多Agent编排]]
- [[MCP协议与工具设计]]
- [[Agent系统-上下文管理与可靠性]]
- [[Claude Certified Architect-高频考点与决策树]]
