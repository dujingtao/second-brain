# AI Token 业务中心 · GitHub → Cloudflare Pages 部署指南

> 上海火棘果数字科技有限公司 SpaceTiD ｜ 内部资料
> 站点含成本结构、毛利水位与渠道分润底线，**仓库必须设为 Private**。

---

## 仓库结构

```
aitoken-internal/            ← 这一层就是仓库根目录
├── functions/
│   └── _middleware.js       边缘访问网关（Pages 自动识别 functions/）
├── public/                  站点内容，即构建输出目录
│   ├── index.html           门户首页
│   ├── kb/index.html        业务知识库
│   ├── console/index.html   业务管理台
│   ├── favicon.svg
│   ├── robots.txt
│   └── _headers
├── wrangler.example.toml    仅供本地调试参考，不参与部署
├── .gitignore
└── README.md
```

**注意这个层级关系**：`functions/` 和 `public/` 必须在仓库根目录，不要多包一层。
Cloudflare 在项目根目录寻找 `functions/`，多包一层会导致门禁不生效。

---

## 第一步 · 建仓库并推代码

在 GitHub 新建仓库，名字建议 `aitoken-internal`，**可见性务必选 Private**。
不要勾选自动生成 README（这里已经有了）。

然后在本地把这个目录推上去：

```bash
cd aitoken-internal

git init
git branch -M main
git add .
git commit -m "AI Token 业务中心：知识库、管理台与边缘访问门禁"

git remote add origin https://github.com/<你的账号>/aitoken-internal.git
git push -u origin main
```

推之前建议先跑一下 `git status`，确认没有把 `.dev.vars`、`.env` 之类的文件带进去。
`.gitignore` 已经拦了，但养成确认的习惯——**访问码一旦进了 git 历史，删文件是没用的，
必须改访问码。**

---

## 第二步 · 在 Cloudflare 连接仓库

打开 Cloudflare Dashboard → **Workers & Pages** → **Create** → **Pages** →
**Connect to Git**。

首次使用会要求授权 GitHub。授权时可以选择「只授权指定仓库」，
把权限收窄到 `aitoken-internal` 一个仓库即可，不需要给全账号权限。

选中仓库后进入构建配置页，按下表填：

| 配置项 | 填什么 | 说明 |
|---|---|---|
| Project name | `aitoken-internal` | 决定 `xxx.pages.dev` 的域名前缀 |
| Production branch | `main` | |
| Framework preset | `None` | 这是纯静态站，没有框架 |
| Build command | **留空** | 不需要构建 |
| Build output directory | `public` | ⚠️ 最关键的一项，填错会 404 |
| Root directory | `/` | 仓库根目录就是项目根，保持默认 |

**先不要急着加环境变量**，点 **Save and Deploy**，让它先跑一次。

第一次部署大约 30 秒。部署完成后访问 `https://aitoken-internal.pages.dev`，
这时应该看到一个 **「站点未完成配置」** 的页面——**这是正确的**。
说明 Functions 已经在运行，只是还没设访问码，所以整站处于关闭状态。

> 如果这一步看到的是门户首页而不是「未完成配置」，说明 Functions 没有生效，
> 八成是 Build output directory 填错了，或者目录多包了一层。停下来检查，
> 不要继续——那种状态下站点是完全公开的。

---

## 第三步 · 设置访问码

进入项目 → **Settings** → **Environment variables** → **Production** → **Add variable**。

逐条添加，**类型全部选 `Secret`（加密），不要选 Plaintext**：

| 变量名 | 值 | 必填 |
|---|---|---|
| `ACCESS_CODE` | 你定的 6 位数字，如 `729416` | ✅ |
| `SESSION_SECRET` | 一串长随机字符，如 `a7f3k9x2m5q8w1e4r6t0y3u7i9o2p5` | 建议 |
| `CONSOLE_CODE` | 管理台专用的另一个 6 位数字 | 选填 |
| `SESSION_HOURS` | `12` | 选填 |

关于 `SESSION_SECRET`：随便敲一串足够长的乱码就行，不需要记住它。
不设的话系统会从访问码派生——那样每次改访问码会顺带让所有人的登录失效，
通常这反而是想要的效果，所以不设也不算错。

关于 `CONSOLE_CODE`：设了之后 `/console/` 需要单独输码，知识库不受影响。
建议 `ACCESS_CODE` 发全员看知识库，`CONSOLE_CODE` 只给决策层、财务和销售主管。

**环境变量不会自动生效**，回到 **Deployments** 页，在最新那次部署右侧点
**⋯ → Retry deployment**，重新部署一次。

---

## 第四步 · 验证

用**无痕窗口**逐项确认（普通窗口可能有残留 Cookie，验不准）：

打开首页应看到 6 格访问码输入框，不是内容；
直接访问 `/console/index.html` 应同样被拦；
在登录页按 Ctrl+U 查看源代码，搜「贡献毛利」「采购折扣」应该搜不到；
输入错误的码应提示不正确且进不去；
输入正确的码应能进入首页，两个入口都能打开；
点页脚「退出登录」后刷新，应重新要求输码。

六项都对，就部署成功了。

---

## 日常更新

改完内容 push 一下就自动重新部署，几十秒生效：

```bash
git add .
git commit -m "更新知识库模块 04 价格数据"
git push
```

**改访问码**：Settings → Environment variables 改掉 `ACCESS_CODE` 的值，
然后 Deployments → Retry deployment。改完所有人需要重新输码。
建议每季度轮换一次，有人离职当天就换。

**回滚**：Deployments 页找到之前的某次部署，点 **Rollback to this deployment**，
秒级恢复。这是 Git 方式相比拖拽上传最实用的好处。

---

## 建议补一步：防暴力破解

6 位数字只有 100 万种组合，对着链接跑脚本是能爆破的。中间件里已经写好了
按 IP 的失败计数逻辑（10 次锁 15 分钟），绑个 KV 就生效：

```bash
npx wrangler kv namespace create RATE
# 记下返回的 id
```

然后在 Dashboard → 项目 Settings → **Bindings** → **Add** → **KV namespace**，
Variable name 填 `RATE`，选中刚建的命名空间，保存后重新部署。

另外可以在 **Security → WAF → Rate limiting rules** 加一条规则：
对路径 `/__auth` 限制每 IP 每分钟 5 次请求。免费版可以配一条，正好用在这。

---

## 本地调试

改动 `functions/_middleware.js` 后想先本地验证：

```bash
npx wrangler pages dev public --binding ACCESS_CODE=482913
# 浏览器打开 http://localhost:8788
```

在仓库根目录执行，`functions/` 会被自动识别。
示例码 `482913` 仅供本地测试，别用在正式环境。

---

## 自定义域名与备案提醒

如果要挂 `spacetid.com` 的子域名（如 `kb.spacetid.com`）：

该域名已备案在国内（沪ICP备2023030137号-1），而 Cloudflare 节点在境外。
用已备案域名指向境外服务器，建议先跟负责备案的同事或服务商确认口径，
必要时改用未备案的独立域名。

另外 Cloudflare 免费版在大陆的访问稳定性波动较大。如果团队日常高频使用，
可以考虑国内的静态托管方案——但要注意，**换到纯静态托管后这套 Functions 门禁
不再生效**，需要用对方平台的鉴权能力替代，不能直接搬。

---

## 出问题时先看这里

**部署后看到 404**：Build output directory 没填 `public`。

**看到门户首页而不是访问码页面**：Functions 没生效。检查 `functions/` 是否在仓库根目录、
是否被 `.gitignore` 误伤（`git ls-files functions/` 应该能列出 `_middleware.js`）。
**这种状态下站点是公开的，要立刻处理。**

**一直显示「站点未完成配置」**：`ACCESS_CODE` 没设，或者设完没重新部署。

**输对了码还是进不去**：检查变量名拼写；确认设在 **Production** 环境而不是 Preview；
确认用的是 https（Cookie 带 Secure 标记，http 下不会被保存）。

**改了内容但页面没变**：站点响应头是 `no-store`，正常不会有缓存问题；
先去 Deployments 确认那次 push 的构建是否成功。
