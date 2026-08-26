---
tags: [AI Token, SpaceTiD, Cloudflare, 部署, 运维]
sources: [[../raw/aitoken-README.md]], [[../raw/aitoken-schema.sql]], [[../raw/aitoken-console.html]]
updated: 2026-08-26
---

# AI Token 站点部署与访问控制

[[AI Token 业务]]（SpaceTiD）的内部知识库网站和业务管理台部署在 **Cloudflare Pages**，仓库名建议 `aitoken-internal`，**必须设为 Private**（站点内容含成本结构、毛利水位、渠道分润底线，属于商业机密）。

## 仓库结构与部署

```
aitoken-internal/
├── functions/_middleware.js   边缘访问网关（做访问码校验）
├── public/                    构建输出目录（index.html 门户、kb/ 知识库、console/ 管理台）
├── wrangler.example.toml
└── README.md
```

`functions/` 和 `public/` 必须在仓库根目录，不能多包一层，否则 Cloudflare 识别不到 `functions/`，门禁失效。

Cloudflare Pages 项目配置：Framework preset 选 `None`（纯静态站，无需构建），Build output directory 必须填 `public`（填错会 404），Root directory 保持 `/`。首次部署完成后应看到"站点未完成配置"页面——这是正确状态，说明中间件在跑，只是访问码还没设，此时整站关闭；如果看到的是门户首页而非该提示，说明 Functions 未生效（八成是目录填错），**此时站点完全公开，必须立即停下排查**。

## 访问控制

通过 Cloudflare Pages 的 Production 环境变量（类型一律选 `Secret`，不用 Plaintext）设置：

| 变量名 | 作用 |
|---|---|
| `ACCESS_CODE` | 6 位数字，门户/知识库入口访问码 |
| `CONSOLE_CODE` | 管理台 `/console/` 专用访问码（选填，只给决策层/财务/销售主管） |
| `SESSION_SECRET` | 会话签名密钥；不设则从访问码派生，改访问码时会顺带使所有会话失效 |
| `SESSION_HOURS` | 会话有效期，默认建议 12 |

改环境变量后必须手动 **Retry deployment** 才生效。验证流程建议用无痕窗口逐项检查：首页应显示访问码输入框而非内容、`/console/index.html` 同样受拦截、登录页源码里搜不到"贡献毛利""采购折扣"等敏感字段、错误码应被拒绝、退出登录后刷新应重新要求输码。

**改访问码**：改 `ACCESS_CODE` 值后 Retry deployment 即可，建议每季度轮换，有人离职当天就换。

## 防暴力破解

6 位数字访问码只有 100 万种组合，需要绑定 Cloudflare KV（命名空间 `RATE`）供中间件做按 IP 的失败计数（10 次锁 15 分钟），并可在 WAF → Rate limiting rules 里对 `/__auth` 路径加限流（每 IP 每分钟 5 次）。

## 访问审计日志（D1）

审计日志表结构见 [[../raw/aitoken-schema.sql]]，绑定名必须是 `LOGS`（中间件按此名查找，填错会静默失效）：

```sql
CREATE TABLE IF NOT EXISTS access_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ts INTEGER NOT NULL, ip TEXT, country TEXT, city TEXT, asn TEXT, colo TEXT,
  path TEXT, ua TEXT, event TEXT NOT NULL,  -- view / login_ok / login_fail / locked
  scope TEXT  -- site / console
);
```

保留期 90 天，由中间件在写入时按约 1/200 的概率触发删除旧记录，不需要额外的定时任务。D1 控制台粘贴 SQL 时要注意换行会被压成一行，因此该文件全程用块注释 `/* */` 而不是 `--` 行注释，避免注释吞掉后续语句。

管理台侧栏有"访问审计 →"入口（`/__logs`）指向这些日志。

## 业务管理台（console）

`/console/index.html` 是一个单文件 SPA 原型（v1.0 · 演示数据，数据存于内存，刷新即重置，需用"数据管理"页导出 JSON/CSV 留档），包含以下页面，且明确与知识库模块对应：

| 管理台功能 | 依据的知识库模块 |
|---|---|
| 总览看板（收入/毛利趋势、客户结构、风险预警） | 模块 04、05、09 |
| 客户管理、商机漏斗、订单与充值 | 模块 09 客户全生命周期六阶段 |
| 毛利测算器 | [[AI Token-定价体系与单位经济模型]]（模块 04） |
| 代理商分润 | [[AI Token-渠道与代理商体系]]（模块 07） |
| 上游价格表 | 模块 01、04 |
| 数据管理（导出/导入/全局参数） | — |

毛利测算器的核心公式（与模块 04 一致）：对客收入 = Σ(token量 × 官方价 × 对客折扣)，采购成本 = Σ(token量 × 官方价 × 采购折扣)，贡献毛利 = 订单毛利 − 技术成本(收入×3%) − 服务成本(收入×服务强度率) − 风险计提(收入×2%)。健康度分级：贡献毛利率 >20% 优质，>10% 健康，>3% 薄利，>0% 临界，≤0 失血（应限期改善或主动退出）。报价审批层级随毛利率降低而上收：≥15% 销售自主，≥10% 销售主管，≥8% 业务负责人，否则需决策层审批。

## 相关
- [[AI Token 业务]]
- [[AI Token-定价体系与单位经济模型]]
- [[AI Token-合规与风险控制]]
