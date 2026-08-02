# 项目文件结构规范

本文定义 `ssh-depot` 的推荐项目结构。规范按本项目的桌面 SSH 运维工具定位设计：保留 `core` / `feature` / `parts` 的边界，去掉移动端、WebView、RTC、Electron 等不相关组织方式。

## 1. 总体原则

- 以 Flutter 桌面应用为主体，`lib/` 是主应用源码目录。
- `core` 放低业务耦合的基础能力，不能依赖具体运维模块。
- `feature` 放 ssh-depot 产品特有代码。
- `feature/parts` 是主要业务域组织单元，每个 part 对应一个功能模块。
- 测试目录 `test/` 按 `lib/` 结构镜像组织，方便定位归属。
- 不为了“未来可能复用”提前全局化；先放在最窄作用域，真实复用后再上提。

## 2. 顶层目录

```text
.
├── README.md                 # 产品需求文档 PRD
├── docs/                     # 项目文档、工程规范、设计说明
├── lib/                      # Flutter / Dart 主应用源码
│   ├── main.dart             # 应用入口
│   ├── core/                 # 低业务耦合基础能力
│   └── feature/              # ssh-depot 产品代码
├── test/                     # 测试代码，镜像 lib/ 结构
├── assets/                   # 应用静态资源：图标、图片、主题资源等
├── macos/                    # Flutter macOS 桌面工程，MVP 主力平台
├── linux/                    # Flutter Linux 桌面工程，后续兼容
├── windows/                  # Flutter Windows 桌面工程，后续兼容
├── scripts/                  # 本地开发、构建、打包辅助脚本
├── .flutter-version          # 项目约定 Flutter SDK 版本
├── .flutter-sha256           # Linux Flutter SDK 压缩包校验值
├── pubspec.yaml              # Flutter / Dart 依赖与资源声明
└── analysis_options.yaml     # Dart 静态分析规则
```

目录按实际工程初始化逐步创建。当前仓库只有 PRD 时，不需要提前放空目录。

## 2.1 开发环境协作约定

项目不提交 Flutter SDK 本体。不同机器、不同 clone 目录应按 `.flutter-version` 安装对应版本 Flutter，并确保 `flutter` 在 `PATH` 中。

推荐协作规则：

- 开发者可执行 `scripts/install.sh` 自动识别 Linux / macOS 并安装依赖，将 Flutter SDK 安装到 `/usr/local/src/flutter`。
- 需要系统级依赖时，由开发者在自己的终端执行脚本并输入 sudo 密码。
- Flutter SDK 安装到系统目录，不放入项目仓库；脚本会创建 `/usr/local/bin/flutter` 和 `/usr/local/bin/dart` 软链。
- `pubspec.lock` 需要提交，保证依赖解析结果在不同开发环境一致。
- 验证命令统一使用全局 `flutter`：

```bash
flutter pub get
flutter analyze
flutter test
```

## 3. `lib/` 源码结构

```text
lib/
├── main.dart
├── core/
│   ├── components/           # 通用 UI 组件
│   ├── hooks/                # 通用 hooks
│   ├── process/              # 本机进程执行基础封装，不含业务命令语义
│   ├── terminal/             # ANSI、终端缓冲、xterm.dart 适配等基础能力
│   └── utils/                # 通用工具函数
└── feature/
    ├── config.dart           # 应用配置、默认路径、运行参数
    ├── classes/              # 产品级 DTO、值对象
    ├── components/           # 产品级通用组件
    ├── cubits/               # 跨 part 的业务状态
    ├── enums/                # 产品级枚举
    ├── packages/             # 外部工具/平台能力封装
    ├── pages/                # 路由入口页面，保持薄层
    ├── parts/                # 业务域模块
    └── utils/                # 产品级工具函数
```

## 4. `core` 与 `feature` 边界

### 4.1 `lib/core/`

`core` 只放通用基础能力，要求尽量不出现 Nginx、apt、systemd、服务器配置等具体业务语义。

适合放入 `core`：

- 通用按钮、面板、空状态、错误展示等 UI 组件。
- ANSI 文本处理、终端输出缓冲、底部终端视图的基础适配。
- 本机 `Process.start` 的薄封装、进程取消、stdout/stderr 流合并等通用能力。
- 文件路径、YAML 读写基础 helper、字符串校验等不含业务语义的工具。

不适合放入 `core`：

- `apt install`、`systemctl restart`、`nginx -t` 这类具体命令组装。
- 服务器列表、Nginx 模板、服务配置等产品模型。
- 某个页面或业务模块专用的组件。

### 4.2 `lib/feature/`

`feature` 放 ssh-depot 产品级代码，允许出现运维业务语义。

适合放入 `feature`：

- 产品级配置，例如 `~/.myctl/` 路径、默认服务列表、模板目录。
- 产品级组件，例如服务器选择器、命令状态栏、确认弹窗。
- 产品级 DTO，例如 `ServerProfile`、`CommandResult`、`OperationSummary`。
- 外部工具封装，例如 SSH 执行器、本地配置仓库、模板渲染器。

## 5. `feature/packages` 集成层

`packages` 用来隔离外部命令、系统能力和第三方库，让业务 part 不直接面对复杂底层细节。

推荐结构：

```text
lib/feature/packages/
├── ssh/
│   ├── ssh_target.dart       # root@host、连接参数、SSH 选项
│   ├── ssh_executor.dart     # 统一执行远程命令
│   └── ssh_command.dart      # 命令摘要、超时、stdin 等参数
├── local_config/
│   ├── config_paths.dart     # ~/.myctl/ 路径定义
│   ├── servers_store.dart    # servers.yaml 读写
│   └── preferences_store.dart
├── command_runner/
│   ├── operation_queue.dart  # 同一连接的命令串行化
│   └── operation_result.dart
└── nginx_template/
    ├── template_manifest.dart
    ├── template_renderer.dart
    └── built_in_templates.dart
```

放置规则：

- SSH、scp、本地 YAML 存储、模板渲染等跨多个 part 的集成能力放在这里。
- `packages` 可以依赖 `core`，可以暴露产品级接口给 part 使用。
- part 不应直接散落调用 `Process.start('ssh', ...)`；统一走 `feature/packages/ssh`。

## 6. `feature/pages` 路由入口层

`pages` 只做路由入口，不承载复杂业务逻辑。

推荐结构：

```text
lib/feature/pages/
├── overview_page.dart
├── packages_page.dart
├── services_page.dart
├── nginx_page.dart
└── settings_page.dart
```

典型模式：

```dart
class ServicesPage extends StatelessWidget {
  const ServicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ServicesView();
  }
}
```

页面内复杂逻辑应下沉到 `parts/<part>/views`、`cubits` 或 `packages`。

## 7. `feature/parts` 业务模块

每个 part 对应一个业务域。MVP 推荐 parts：

```text
lib/feature/parts/
├── connection/               # 连接状态、服务器选择、连接测试
├── terminal_panel/           # 底部单行状态 + 可展开终端
├── packages/                 # apt 安装/卸载
├── services/                 # systemd 服务管理
├── nginx/                    # Nginx 站点与模板配置
└── settings/                 # 服务器列表、偏好设置
```

单个 part 的推荐结构：

```text
lib/feature/parts/<part>/
├── classes/                  # part 内 DTO、参数对象、值对象
├── components/               # part 内复用组件
├── cubits/                   # part 内共享业务状态
├── enums/                    # part 内枚举
├── layouts/                  # 页面骨架、响应式布局
├── utils/                    # part 内工具函数
└── views/                    # 业务视图、页面片段、组合层
```

不是每个 part 都需要所有目录。目录按实际复杂度创建。

## 8. part 边界规则

推荐：

- `parts/nginx` 可以引用 `feature/packages/ssh`、`feature/packages/nginx_template`、`feature/components` 和 `core`。
- `parts/services` 可以引用 `feature/packages/ssh`，但不直接引用 `parts/nginx` 的内部文件。
- `parts/terminal_panel` 可以消费全局命令输出状态，但不负责组装业务命令。

避免：

- 一个 part 直接 import 另一个 part 的 `components/`、`cubits/`、`views/`。
- 把只在 Nginx 模块使用的组件提前放到 `feature/components`。
- 在 UI widget 里直接拼接高风险 shell 命令。

如果两个 part 需要共享同一段代码，应上提到最窄共享层：

- 完全通用：`lib/core/`
- 产品内共享：`lib/feature/classes`、`feature/components`、`feature/enums`、`feature/utils`、`feature/packages`

## 9. 状态管理放置

推荐按状态作用域放置：

- 单个 widget 内的临时 UI 状态：放在 widget 本地，可使用 hooks 或 `StatefulWidget`。
- 同一 part 内多个 view 共享的业务状态：放在 `parts/<part>/cubits/`。
- 跨多个 part 的连接状态、当前服务器、命令执行队列：放在 `feature/cubits/` 或 `feature/packages/command_runner/`。

MVP 可以先采用 Cubit 管理业务状态；不要为简单表单引入全局状态。

## 10. 命令与安全边界

所有远程命令应遵守统一分层：

```text
View/Button
  -> Part Cubit / Controller
  -> feature/packages/<domain> command builder
  -> feature/packages/ssh/SshExecutor
  -> core/process Process.start wrapper
  -> Terminal output stream
```

要求：

- UI 层不直接调用 `Process.start`。
- UI 层不直接拼完整 SSH 命令。
- 业务命令 builder 负责参数校验、命令摘要和危险操作确认标记。
- SSH executor 负责统一添加 `BatchMode=yes`、`ConnectTimeout=10` 等参数。
- 同一服务器的写操作默认串行执行，避免两个按钮同时改远端状态。
- Nginx 写入必须走备份、写入、`nginx -t`、失败回滚、reload 的固定流程。

## 11. 资源目录

推荐结构：

```text
assets/
├── icons/
│   ├── svg/                 # 可预编译或直接加载的 SVG 图标
│   └── png/                 # PNG 图标
├── images/
│   ├── png/
│   └── jpg/
└── terminal_themes/         # 终端主题配置，如 Dark+、Monokai
```

资源必须在 `pubspec.yaml` 中声明。业务模块专属的大量资源可以按模块名前缀命名，避免拆出复杂目录。

## 12. 文档目录

推荐结构：

```text
docs/
├── project-structure.zh-CN.md
├── architecture.zh-CN.md
├── command-execution.zh-CN.md
├── nginx-workflow.zh-CN.md
└── release.zh-CN.md
```

文档职责：

- `project-structure.zh-CN.md`：目录结构和放置规则。
- `architecture.zh-CN.md`：运行时架构、状态流、核心对象关系。
- `command-execution.zh-CN.md`：SSH、本机进程、命令队列、取消、超时、输出处理。
- `nginx-workflow.zh-CN.md`：模板、写入、备份、回滚、reload 流程。
- `release.zh-CN.md`：桌面端打包和发布步骤。

## 13. 测试结构

测试目录镜像 `lib/`：

```text
lib/core/...                 -> test/core/...
lib/feature/packages/ssh/... -> test/feature/packages/ssh/...
lib/feature/parts/nginx/...  -> test/feature/parts/nginx/...
```

优先测试：

- 命令 builder 的参数转义和输入校验。
- Nginx 模板渲染结果。
- Nginx 写入流程的成功、失败回滚分支。
- SSH executor 对 exit code、stdout/stderr、取消和超时的处理。
- Cubit 状态流，尤其是执行中、成功、失败、取消状态。

## 14. 命名约定

- 文件名使用 `snake_case.dart`。
- class 使用 `UpperCamelCase`。
- Cubit 文件以 `_cubit.dart` 结尾，状态文件以 `_state.dart` 结尾。
- 页面入口以 `_page.dart` 结尾。
- 业务视图以 `_view.dart` 结尾。
- 复用组件按组件名命名，不加 `widget` 后缀。
- DTO、值对象按语义命名，例如 `server_profile.dart`、`command_result.dart`。

## 15. 反模式

避免以下做法：

- 在任意 widget 中直接拼接 `ssh root@host "..."`。
- 一个 part 直接 import 另一个 part 的内部组件或 Cubit。
- 把 Nginx 专用组件放进 `feature/components`。
- 把产品业务对象放进 `core`。
- 为了保持目录完整创建大量空目录。
- 把远端命令输出解析逻辑散落在多个 view 中。
- 在没有备份和回滚的情况下写 `/etc/nginx`。

## 16. 推荐演进顺序

1. 初始化 Flutter 桌面工程和基础目录。
2. 建立 `core/process`、`core/terminal`、`feature/packages/ssh`。
3. 建立 `feature/cubits` 管理当前连接和命令执行队列。
4. 建立 `parts/terminal_panel`，先打通全局终端输出。
5. 按 MVP 顺序实现 `connection`、`services`、`packages`、`nginx`、`settings`。
6. 为 SSH 执行、命令 builder、Nginx 模板和回滚流程补测试。
