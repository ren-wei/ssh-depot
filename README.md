# ssh depot 产品需求文档（PRD）V1.0

> 基于 SSH 的极简 Linux 运维桌面工具

项目文件结构规范见：[docs/project-structure.zh-CN.md](docs/project-structure.zh-CN.md)

本项目固定 Flutter 版本见 [`.flutter-version`](.flutter-version)。开发环境可执行 `scripts/install.sh` 自动识别 Linux / macOS 并安装依赖，将对应版本 Flutter 安装到 `/usr/local/src/flutter`。

Linux 桌面运行时如果中文显示为方框，说明系统缺少 CJK 字体；执行 `sudo apt-get install -y fonts-noto-cjk && fc-cache -fv` 后重启应用。

---
## 1. 产品概述

### 1.1 一句话定义

一个本机运行的 Flutter 桌面工具，通过 SSH 操作远程 Linux 服务器，把常用运维操作做成可视化界面；用户名默认填充为 `root`，也可按服务器实际配置改为其他用户；远端无需部署 ssh-depot 服务端组件或常驻进程。

### 1.2 核心价值

- **低服务端侵入**：远程服务器无需部署 ssh-depot 服务端组件或常驻进程，只依赖 SSH 和各功能模块本身需要的系统命令
- **复用现有 SSH 配置**：自动读取 `~/.ssh/config`、密钥、ControlMaster 等，用户只需提供用户名和地址
- **终端输出透明**：所有操作结果通过 xterm.dart 原样展示，跟手敲命令体验一致
- **模板化 Nginx 配置**：把反复编写的 Nginx 配置模板化，填变量即可生成

### 1.3 目标用户

- 维护 1-10 台 Debian/Ubuntu 服务器的开发者
- 熟悉 SSH 和 Linux 命令，但厌倦重复敲相同命令
- 不需要团队协作、权限管理、审计等企业级功能

### 1.4 技术选型

| 层级 | 选择 | 理由 |
|------|------|------|
| UI 框架 | Flutter（桌面端） | 跨平台、单二进制分发、体验好 |
| SSH 执行 | 本机 `ssh` 命令（`Process.start`） | 复用系统 SSH，零额外依赖 |
| 终端渲染 | xterm.dart | 完整 ANSI 支持，进度条/颜色/光标全搞定 |
| 配置存储 | 本地 YAML 文件（`~/.ssh-depot/`） | 简单、可移植、不依赖服务端 |
| 目标系统 | Debian / Ubuntu（apt + systemctl） | 第一版只支持 Debian 系 |

---

## 2. 连接与全局行为

### 2.1 连接配置

- 用户输入：**用户名 + 地址**（用户名默认值为 `root`，可改为其他 SSH 用户；host 可以是 IP 或 `~/.ssh/config` 里的 Host 别名）
- 认证方式：复用本机 SSH 密钥认证，不支持密码登录
- MVP 权限模型：使用用户填写的 `user@host` 执行所有命令；默认用户是 `root`。MVP 不处理 sudo、不弹 sudo 密码、不适配 sudoers，远端命令能否成功取决于该 SSH 用户本身的系统权限
- SSH 参数：
  - `BatchMode=yes`（禁止交互式密码输入）
  - `ConnectTimeout=10`
  - 自动继承 `~/.ssh/config` 中的端口、密钥路径、代理等配置
- 连接测试：`ssh user@host "echo __ssh-depot_ok__"`，返回包含标记字符串即视为成功

### 2.2 底部终端行为规则

| 阶段 | 底部单行显示 |
|------|-------------|
| 空闲 | 显示上一次操作的最终结果文本 |
| 执行中 | TerminalView 最后一行 raw 文本（原样，不加工） |
| 执行结束 | 根据 exit code 覆盖为 `✓ <命令摘要> 成功` 或 `✗ <命令摘要> 失败` |
| 用户取消 | `⏹ <命令摘要> 已取消` |

**关键规则：**
- 执行中：底部单行 = TerminalView 缓冲区最后一行可见文本，原样反射
- 跳过纯控制序列行（strip ANSI 后为空时保持上一行不动）
- 执行结束后：停止跟随，根据 exit code 替换为固定摘要文本
- 展开 TerminalView 面板后，里面的内容独立渲染，不受底部单行影响

### 2.3 全局 UI 布局

```
┌──────────────────────────────────────────────────────┐
│  ssh-depot · root@1.2.3.4  [断开]                    │
├──────────────┬───────────────────────────────────────┤
│              │                                       │
│  左侧 tab    │  右侧内容区（随 tab 切换）             │
│              │                                       │
├──────────────┴───────────────────────────────────────┤
│  $ apt install -y nginx ✓ 成功                 [▾]  │
└──────────────────────────────────────────────────────┘
```

- **左侧**：功能 tab 导航（图标 + 文字）
- **右侧**：当前 tab 的详细操作界面
- **底部**：默认单行状态栏，可展开查看完整终端输出

### 2.4 底部面板交互

- 默认状态：**单行**，显示最新一条操作结果
- 点击 `[▾]` 展开：弹出完整 TerminalView 面板（约 300px 高度）
- 点击 `[▴]` 或面板外区域：收起回单行
- 展开/收起过程可加简单动画（200ms 渐变）
- 所有操作的输出持续写入 TerminalView，展开后可滚动查看历史
- 切换 tab 不清空终端内容

---

## 3. 功能模块详细设计

### 3.1 概览（Overview）

**定位**：连上服务器后第一个看到的页面，一屏看清机器状态。

| 信息项 | 数据来源 | 刷新方式 |
|--------|----------|----------|
| 系统信息（发行版、内核、uptime） | `lsb_release -ds`、`uname -r`、`uptime` | 手动刷新按钮 |
| CPU / 内存 / 磁盘使用率 | `top -bn1`、`free -h`、`df -h` 解析 | 手动刷新按钮 |
| 关键服务状态速览 | 预配置的服务列表 + `systemctl is-active` | 手动刷新按钮 |
| 最近操作记录 | 本地记录的最近 5-10 条命令及结果 | 自动更新 |

**不做**：实时监控图表、历史趋势图、告警通知。

---

### 3.2 软件包管理（Packages）

**定位**：apt 安装/卸载的图形入口。MVP 只做指定包名的安装/卸载，已安装包列表和搜索放到 P1。

**核心操作：**

| 操作 | 命令 |
|------|------|
| 安装 | `apt update && apt install -y <name>` |
| 卸载 | `apt remove -y <name>` |
| 已安装列表（P1） | `apt list --installed` |
| 搜索（P1） | `apt search <keyword>` |

**界面元素：**
- 输入框 + [安装] [卸载] 按钮
- 下方已安装包列表（P1，带搜索过滤）
- 所有输出写入底部终端

**不做**：依赖树分析、版本对比、批量安装。

---

### 3.3 服务管理（Services）

**定位**：预配置服务列表的启停/重启/状态查看。

**核心操作：**

| 操作 | 命令 |
|------|------|
| 启动 | `systemctl start <svc>` |
| 停止 | `systemctl stop <svc>` |
| 重启 | `systemctl restart <svc>` |
| 状态 | `systemctl status <svc> --no-pager` |
| 是否自启 | `systemctl is-enabled <svc>` |
| 日志 | `journalctl -u <svc> --no-pager -n 50` |

**界面元素：**
- 服务列表（可配置，默认预置 nginx / mysql / redis / docker）
- 每项显示名称 + 状态指示灯（绿=running / 灰=inactive / 红=failed）
- 选中服务后下方出现操作按钮行
- 服务列表在「设置 → 服务管理」中可增删改

**不做**：全盘扫描所有 systemd 单元、依赖关系图。

---

### 3.4 Nginx 管理

**定位**：模板化生成配置 → 预览 → 写入 → 语法检查 → reload。

#### 站点管理

| 操作 | 说明 |
|------|------|
| 查看站点列表 | 读取 `sites-available/` + `sites-enabled/` 软链状态 |
| 启用站点 | `ln -s /etc/nginx/sites-available/<name> /etc/nginx/sites-enabled/<name>` |
| 禁用站点 | `rm /etc/nginx/sites-enabled/<name>` |
| 删除站点 | 禁用 + 删除 available 文件 |
| 语法检查 | `nginx -t` |
| 重载 | `systemctl reload nginx` |

#### 配置模板系统

**工作流程：**
```
选模板 → 填变量 → 生成纯文本配置 → 弹窗预览 → 手动微调 → 确认写入
```

**内置模板：**

MVP 先内置静态网站和反向代理两个模板；SSL 反向代理和 PHP 网站放到 P1。

**① 静态网站**
```
变量：domain（域名）、root_path（网站根目录）、enable_logs（是否开日志）
```

**② 反向代理**
```
变量：domain（域名）、upstream_host（后端地址）、upstream_port（后端端口）
```

**③ SSL 反向代理（P1）**
```
变量：domain（域名）、upstream_host（后端地址）、upstream_port（后端端口）
自动引用：/etc/letsencrypt/live/<domain>/fullchain.pem
```

**④ PHP 网站（P1）**
```
变量：domain（域名）、root_path（网站根目录）、php_version（PHP 版本号）
```

**模板存储：**
```
~/.ssh-depot/templates/
├── static_site.nginx       # 模板内容（含 {{variable}} 占位符）
├── static_site.yaml        # 模板元数据（名称、描述、变量定义）
├── reverse_proxy.nginx
├── reverse_proxy.yaml
├── ssl_proxy.nginx
├── ssl_proxy.yaml
├── php_site.nginx
└── php_site.yaml
```

**模板变量类型：**
- `string`：文本输入
- `number`：数字输入
- `boolean`：复选框（用于条件块）

**写入流程：**
1. 渲染模板生成配置文本
2. 弹窗预览（SelectableText，等宽字体）
3. 用户可手动微调文本
4. 确认后 base64 编码通过 SSH 写入目标文件
5. `nginx -t` 语法检查 → 失败则报错并回滚
6. 软链到 `sites-enabled/`
7. `systemctl reload nginx`
8. 终端输出全过程

**不做**：可视化表单编辑（端口、server_name 各一个输入框那种），直接给纯文本编辑。

---

### 3.5 SSL 证书管理（P1）

**定位**：Let's Encrypt / Certbot 的可视化管理。

| 操作 | 命令 |
|------|------|
| 查看证书列表 | `certbot certificates` |
| 申请新证书 | `certbot --nginx --non-interactive --agree-tos --email <email> -d <domain>` |
| 手动续期 | `certbot renew` |
| 自动续期状态 | `systemctl status certbot.timer` |

**界面元素：**
- 证书列表：域名、绑定域名列表、到期日期、剩余天数、状态指示灯
- 到期 < 30 天标黄，< 7 天标红
- [申请新证书] 按钮 → 填域名 + 邮箱 → 执行
- [续期] 按钮（对单个证书或全局）
- 自动续期 timer 状态显示

**申请流程中的联动：**
- 申请前检查 80 端口可达性
- 申请成功后自动 reload nginx
- 输出写入终端

**不做**：多 CA 支持、DNS-01 验证方式、通配符证书。

---

### 3.6 文件管理（P2）

**定位**：轻量浏览和编辑，不是 FTP 替代品。

| 操作 | 说明 |
|------|------|
| 目录浏览 | `ls -lh <path>` 解析为列表 |
| 查看文件内容 | `cat <file>`（限制大小，如 1MB 以内） |
| 编辑文件 | 拉取 → 本地编辑 → base64 写回 → 备份旧版本 |
| 文件权限查看 | `stat <file>` 解析 |
| 简单上传/下载 | 本机 `scp` 命令调用 |

**不做**：拖拽上传、权限修改界面、大文件传输进度。

---

### 3.7 日志查看（P2）

**定位**：快速查看常见日志源。

| 日志源 | 命令 |
|--------|------|
| Journal 日志 | `journalctl -u <svc> --no-pager -n 100` |
| Nginx 访问日志 | `tail -n 100 /var/log/nginx/<domain>_access.log` |
| Nginx 错误日志 | `tail -n 100 /var/log/nginx/<domain>_error.log` |
| 系统日志 | `tail -n 100 /var/log/syslog` |

**界面元素：**
- 日志源下拉选择
- 行数输入
- 关键字过滤（前端过滤，不高亮）
- 输出直接写入终端区

---

### 3.8 Cron 管理（P2）

**定位**：查看和简单编辑定时任务。

| 操作 | 命令 |
|------|------|
| 查看当前用户 crontab | `crontab -l` |
| 查看系统 cron 文件 | `ls /etc/cron.d/` |
| 写入 crontab | `crontab -` + stdin 传入内容 |

**界面元素：**
- 当前 cron 条目列表（解析后展示）
- 新增/编辑条目（文本编辑模式）
- 保存前展示 diff

---

### 3.9 设置

#### 服务器管理
- 已保存服务器列表（名称、host、user、备注）
- 新增/编辑/删除
- 连接测试按钮
- 存储位置：`~/.ssh-depot/servers.yaml`

#### 服务列表配置
- 添加/删除/排序关注的服务
- 设置默认选中的服务

#### 模板管理
- 查看/编辑/删除现有模板
- 新建模板（模板内容 + 元数据 YAML）
- 导入/导出模板（方便跨机器迁移）

#### 全局偏好
- 终端字体大小
- 终端配色方案（预设几套：Dark+、Monokai、Solarized Dark）
- 底部面板默认高度
- 操作前是否弹出确认框

---

## 4. 非功能需求

| 维度 | 要求 |
|------|------|
| 平台 | macOS 主力支持，Linux/Windows 后续兼容 |
| 部署 | 单目录分发，双击运行；客户端除系统 `ssh` 外不引入额外运行时依赖 |
| 配置 | 复用系统 `~/.ssh/*`，不管理密钥 |
| 网络 | 仅出 SSH 22 端口，不监听任何端口 |
| 数据 | 全部存本地 `~/.ssh-depot/`，不上传任何数据 |
| 权限 | MVP 默认用户名为 root，但可改为其他 SSH 用户；不处理 sudo、不弹 sudo 密码、不适配 sudoers |
| 远端依赖 | 目标机需具备对应模块所需命令：`apt`、`systemctl`、`nginx`、`journalctl` 等 |
| 容错 | SSH 断开有明确提示；操作超时可控；取消操作可杀进程 |
| 性能 | 终端输出流畅，大量输出不卡 UI（xterm.dart 负责渲染优化） |

---

## 5. 版本规划

### P0 — MVP（必须有，否则没法用）

| 功能 | 说明 |
|------|------|
| SSH 连接（用户名 + 地址） | 用户名默认 root 且可编辑，测试连通性，复用系统 SSH 配置；MVP 不处理 sudo |
| 软件包安装/卸载 | apt install/remove + 终端输出 |
| 服务启停/重启/状态/日志 | 预配置服务列表 |
| Nginx 站点列表 + 启用/禁用 | 读取 sites-available/enabled |
| Nginx 模板生成 + 预览 + 写入 | 2 个内置模板：静态网站、反向代理；支持文本微调 |
| Nginx 语法检查 + reload | `nginx -t` + systemctl reload |
| Nginx 写入备份 + 失败回滚 | 写入前自动备份，`nginx -t` 失败自动恢复旧配置 |
| 底部终端（单行 + 可展开） | xterm.dart，执行中跟随最后一行，结束后覆盖为成功/失败文本 |
| 服务器管理（设置页） | 增删改服务器配置 |

### P1 — 做完 P0 很自然接的

| 功能 | 说明 |
|------|------|
| 概览页（系统信息 + 资源快照 + 服务状态） | 手动刷新 |
| SSL 证书查看 + 申请 + 续期 | certbot 非交互模式 |
| SSL 反向代理 / PHP 网站模板 | 扩展内置模板 |
| 已安装包列表 + 搜索 | apt list --installed 解析 |
| 服务列表可配置 | 设置页增删改 |
| 终端配色方案选择 | 预设 3 套深色主题 |

### P2 — 舒适型功能

| 功能 | 说明 |
|------|------|
| 轻量文件浏览/查看/编辑 | 拉取 → 编辑 → 写回 |
| 多日志源查看 | journalctl + 常见 log 文件 |
| Cron 查看/编辑 | crontab 解析 + 写入 |
| 操作历史记录 | 本地记录最近执行的命令 |
| 模板导入/导出 | 跨机器迁移 |

### P3 — 规模上来才考虑

| 功能 | 说明 |
|------|------|
| Docker 容器管理 | docker ps / start / stop / logs |
| 多服务器批量操作 | 同一命令发多台 |
| 端口占用查看 | ss -ltnp 解析 |
| UFW 防火墙状态查看 | ufw status（只读） |
| 快速命令片段库 | 自定义按钮执行常用命令 |

---

## 6. 成功标准

> 自己用了一周，有 3 个以上场景会主动打开这个工具而不是开终端敲命令。

---

## 7. 设计原则总结

1. **TerminalView 只负责看**：不接收键盘输入，纯粹当输出窗口
2. **所有操作在外面**：按钮、输入框、下拉选择都在 Flutter 控件上完成
3. **执行有反馈**：每个操作前后都在终端里写一行提示（命令白色、成功绿色、失败红色、信息蓝色）
4. **连接态控制**：未连接时所有操作按钮 disable，内容区显示连接提示
5. **一个终端实例**：全局一个 TerminalController，所有输出汇聚一处
6. **不破坏肌肉记忆**：工具行为必须和手动 SSH 操作完全一致
7. **可逆操作**：写配置前自动备份，出错可回滚
8. **快**：打开就干活，没有欢迎页、向导、更新弹窗
