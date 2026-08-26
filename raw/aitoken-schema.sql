/* SpaceTiD · AI Token 业务中心 —— 访问审计日志表 */

/* 用法：Cloudflare 控制台 → 存储和数据库 → D1 SQL 数据库 → 选中 aitoken-logs
        → 控制台标签 → 粘贴以下全部语句 → 执行。
   然后在 Pages 项目 → 设置 → 绑定 → 添加 D1 数据库绑定，
   变量名必须填 LOGS（中间件按这个名字查找，填错会静默失效）。 */

/* 注意：本文件一律使用块注释，不用 -- 行注释。
   D1 控制台的输入框会把粘贴内容的换行压成一行，
   届时 -- 之后的全部内容（包括真正的 SQL）都会被当成注释吞掉。 */

CREATE TABLE IF NOT EXISTS access_log (
  id      INTEGER PRIMARY KEY AUTOINCREMENT,
  ts      INTEGER NOT NULL,   /* Unix 毫秒时间戳 */
  ip      TEXT,               /* CF-Connecting-IP */
  country TEXT,               /* 两位国家码，如 CN */
  city    TEXT,
  asn     TEXT,               /* 网络运营商名称 */
  colo    TEXT,               /* Cloudflare 边缘节点 */
  path    TEXT,               /* 只存路径，不含查询参数 */
  ua      TEXT,
  event   TEXT NOT NULL,      /* view / login_ok / login_fail / locked */
  scope   TEXT                /* site / console */
);

CREATE INDEX IF NOT EXISTS idx_log_ts    ON access_log(ts);
CREATE INDEX IF NOT EXISTS idx_log_event ON access_log(event);
CREATE INDEX IF NOT EXISTS idx_log_ip    ON access_log(ip);

/* 保留期：中间件在写入时按概率（平均每 200 次）执行一次
     DELETE FROM access_log WHERE ts < (now - 90 天)
   无需额外配置定时任务。若要改保留期，改 _middleware.js 的 LOG_RETENTION_DAYS。 */

/* ---- 若上面整段粘贴仍失败，改用这一行（无换行依赖） ----
CREATE TABLE IF NOT EXISTS access_log (id INTEGER PRIMARY KEY AUTOINCREMENT, ts INTEGER NOT NULL, ip TEXT, country TEXT, city TEXT, asn TEXT, colo TEXT, path TEXT, ua TEXT, event TEXT NOT NULL, scope TEXT); CREATE INDEX IF NOT EXISTS idx_log_ts ON access_log(ts); CREATE INDEX IF NOT EXISTS idx_log_event ON access_log(event); CREATE INDEX IF NOT EXISTS idx_log_ip ON access_log(ip);
---- */
