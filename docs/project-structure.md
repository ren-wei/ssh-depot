# 项目文件结构规范

本文定义 `ssh-depot` 当前项目结构、文件职责和后续放置规则。文档以当前 Flutter 桌面 SSH 运维工具实现为准。

## 1. 总体原则

- `lib/` 是主应用源码目录。
- `lib/core/` 放低业务耦合的基础能力，不能依赖具体运维模块。
- `lib/feature/` 放 ssh-depot 产品特有代码。
- `lib/feature/parts/` 是业务界面模块，每个 part 对应一个功能域。
- `lib/feature/packages/` 是集成层，封装 SSH、本地配置、模板渲染、命令队列等能力。
- `test/` 按能力域组织，优先覆盖命令执行、输出处理、模板、配置读写等高风险逻辑。
- 不创建大量空目录；目录按实际复杂度逐步增加。

## 2. 当前顶层文件职责

```text
.
├── README.md                         # 产品需求文档和 MVP 范围说明
├── docs/
│   └── project-structure.zh-CN.md    # 当前项目结构、文件职责和放置规则
├── lib/                              # Flutter / Dart 主应用源码
├── test/                             # 单元测试和组件测试
├── assets/                           # 应用静态资源
├── scripts/                          # 协作环境一键安装脚本
├── linux/                            # Flutter Linux 桌面平台工程
├── macos/                            # Flutter macOS 桌面平台工程
├── windows/                          # Flutter Windows 桌面平台工程
├── .vscode/launch.json               # VS Code 调试入口
├── .flutter-version                  # 项目约定 Flutter SDK 版本
├── .flutter-sha256                   # Linux Flutter SDK 压缩包 SHA-256
├── .flutter-plugins-dependencies     # Flutter 插件依赖生成文件
├── .gitignore                        # Git 忽略规则
├── .metadata                         # Flutter 工程元数据
├── analysis_options.yaml             # Dart / Flutter 静态分析规则
├── pubspec.yaml                      # 依赖、资源和包元数据
├── pubspec.lock                      # 锁定依赖解析结果，需提交
└── ssh_depot.iml                     # JetBrains / IntelliJ 项目配置
```

不纳入源码规范的目录：

- `.git/`：Git 内部数据。
- `.dart_tool/`：Flutter / Dart 本地生成缓存。
- `build/`：构建产物。
- `.idea/`：IDE 本地配置，除非团队明确约定，否则不作为业务结构依据。

## 3. 协作环境脚本

```text
scripts/
├── install.sh                # 根据当前系统分发到 Linux 或 macOS 安装脚本
├── install-for-linux.sh      # Linux 依赖安装、Flutter 下载校验、软链创建、doctor 校验
└── install-for-macos.sh      # macOS Flutter 下载校验、软链创建、doctor 校验
```

协作约定：

- 项目不提交 Flutter SDK 本体。
- 默认把 Flutter SDK 安装到 `/usr/local/src/flutter`。
- 默认创建 `/usr/local/bin/flutter` 和 `/usr/local/bin/dart` 软链。
- 脚本中需要 `sudo` 时，由开发者在自己的终端输入密码。
- 不同 clone 目录共享系统级 Flutter SDK，通过 `.flutter-version` 保持版本一致。

常用验证命令：

```bash
flutter pub get
flutter analyze
flutter test
```

## 4. 资源文件职责

```text
assets/
├── .gitkeep                         # 保留资源根目录
├── icons/
│   └── .gitkeep                     # 保留图标目录
├── images/
│   ├── .gitkeep                     # 保留图片目录
│   └── png/
│       └── connection-background.png # 连接窗口背景图
└── terminal_themes/
    └── .gitkeep                     # 预留终端主题资源目录
```

资源必须在 `pubspec.yaml` 的 `flutter.assets` 中声明。Dart 代码中通过资源常量或 `AssetImage` 包装类引用资源，避免在多个 Widget 中散落硬编码路径。

## 5. `lib/` 源码职责

```text
lib/
├── main.dart                         # 应用入口、主题、路由和 AppScope 注入
├── core/                             # 低业务耦合基础能力
└── feature/                          # ssh-depot 产品代码
```

### 5.1 `lib/core/`

```text
lib/core/
├── components/
│   └── .gitkeep                      # 预留通用 UI 组件目录
├── process/
│   ├── local_process_runner.dart     # 本机进程启动、输出转发、超时和取消封装
│   └── process_output_chunk.dart     # 统一描述 stdout/stderr 输出片段
├── terminal/
│   ├── terminal_control_sanitizer.dart # 清理终端控制序列，保留可展示文本
│   ├── terminal_line_buffer.dart     # 将输出片段聚合为终端行缓冲
│   └── terminal_raw_output.dart      # 原始终端输出模型和回放辅助
└── utils/
    └── .gitkeep                      # 预留通用工具目录
```

`core` 不能出现 Nginx、apt、systemd、服务器配置等具体业务语义。

### 5.2 `lib/feature/`

```text
lib/feature/
├── config.dart                       # 产品级常量配置
├── assets/
│   └── connection_asset.dart         # 连接背景图的 AssetImage 封装
├── classes/                          # 产品级 DTO、值对象
├── components/                       # 产品级通用组件
├── cubits/                           # 跨页面业务状态和协调器
├── enums/                            # 预留产品级枚举目录
├── packages/                         # 外部能力和复杂业务能力封装
├── pages/                            # 路由入口页面，保持薄层
├── parts/                            # 业务界面模块
└── utils/                            # 产品级工具函数
```

#### `feature/classes`

```text
lib/feature/classes/
├── command_result.dart               # 远端命令执行结果模型
├── nginx_site.dart                   # Nginx 站点和证书信息模型
├── nginx_template_definition.dart    # Nginx 网站模板定义模型
├── overview_snapshot.dart            # 服务器概览、服务状态、资源状态快照
└── server_profile.dart               # 已保存服务器配置，包含名称、Host、用户名
```

#### `feature/components`

```text
lib/feature/components/
├── app_scope.dart                    # 多个 cubit 的创建、生命周期管理和按需访问入口
├── app_shell.dart                    # 登录后的主框架、侧边栏、顶部栏、底部终端面板
├── depot_content.dart                # 页面内容容器和统一版心组件
├── depot_scrollbar.dart              # 产品统一滚动条样式
└── depot_snack_bar.dart              # 产品统一轻量提示样式
```

#### `feature/cubits`

```text
lib/feature/cubits/
├── command_runner_cubit.dart         # 统一远端命令执行、队列、运行状态和状态栏
├── connection_cubit.dart             # SSH 连接、测试连接、断开连接和当前 target
├── operation_history_cubit.dart      # 最近操作记录
├── servers_cubit.dart                # 已保存服务器列表读写和当前服务器标题解析
└── terminal_cubit.dart               # 终端输出、raw 输出、展开/收起和清空
```

全局 cubit 只放跨模块能力。特定业务模块的状态、命令构造和解析逻辑放到对应 `parts/<part>/cubits` 与 `parts/<part>/utils`。

#### `feature/packages`

```text
lib/feature/packages/
├── command_runner/
│   ├── operation_queue.dart          # 远端操作串行队列，避免同一会话并发写入
│   └── operation_result.dart         # 操作记录、状态和结果摘要模型
├── local_config/
│   ├── config_paths.dart             # 本地配置目录和配置文件路径解析
│   ├── nginx_templates_store.dart    # 自定义 Nginx 模板本地读写
│   ├── preferences_store.dart        # 通用偏好配置读写
│   ├── servers_store.dart            # 已保存服务器列表读写
│   └── service_preferences_store.dart # 管理服务列表偏好读写
├── nginx_template/
│   ├── built_in_templates.dart       # 内置 Nginx 网站模板集合
│   ├── template_manifest.dart        # 模板元数据结构
│   └── template_renderer.dart        # 模板变量替换和 Nginx 配置渲染
├── overview/
│   └── overview_parser.dart          # 服务器概览命令输出解析
└── ssh/
    ├── pty_ssh_session.dart         # 基于 PTY 的长连接 SSH 会话、命令包装、marker 解析
    ├── ssh_command.dart             # 远端命令参数：命令文本、摘要、超时等
    ├── ssh_executor.dart            # SSH 执行统一入口，管理会话打开、运行、取消和 detached 执行
    └── ssh_target.dart              # SSH 目标地址模型：user、host、address、controlPath
```

`packages` 可以依赖 `core`，但 UI 和 part 不应绕过它直接调用底层进程或拼装 SSH 进程。

#### `feature/pages`

```text
lib/feature/pages/
├── nginx_page.dart                   # 网站管理路由入口
├── overview_page.dart                # 概览路由入口
├── packages_page.dart                # 软件包路由入口
├── services_page.dart                # 服务管理路由入口
├── settings_page.dart                # 设置路由入口
└── ssl_page.dart                     # SSL 证书路由入口
```

页面文件只负责承接路由并组合对应 view，复杂逻辑应下沉到 `parts/` 的 cubit / util 或 `packages/`。

#### `feature/parts`

```text
lib/feature/parts/
├── connection/
│   └── views/
│       └── connection_view.dart      # 登录窗口、服务器表单、测试连接、授权命令和排查命令复制
├── nginx/
│   ├── cubits/
│   │   └── nginx_cubit.dart          # Nginx 站点、模板、配置读写和 reload 状态编排
│   ├── utils/
│   │   └── nginx_utils.dart          # Nginx 命令构造、站点/证书解析和内置网站模板
│   └── views/
│       └── nginx_view.dart           # Nginx 站点列表、模板创建、配置编辑和操作 UI
├── packages/
│   ├── cubits/
│   │   └── packages_cubit.dart       # apt 安装/卸载业务编排
│   ├── utils/
│   │   └── packages_utils.dart       # 包名校验和 apt 命令构造
│   └── views/
│       └── packages_view.dart        # apt 软件包安装、卸载、常用包操作
├── overview/
│   ├── cubits/
│   │   └── overview_cubit.dart       # 概览快照和刷新状态
│   └── utils/
│       └── overview_utils.dart       # 概览命令构造
├── services/
│   ├── cubits/
│   │   └── services_cubit.dart       # 关注服务、服务快照和日志状态
│   ├── utils/
│   │   └── services_utils.dart       # systemctl/journalctl 命令、服务名校验和输出解析
│   └── views/
│       └── services_view.dart        # systemd 服务状态、启动、停止、重启和日志查看
├── settings/
│   └── views/
│       └── settings_view.dart        # 服务器列表、偏好设置、自定义模板管理
├── ssl/
│   ├── cubits/
│   │   └── ssl_cubit.dart            # 证书列表、申请、续期、域名更新和删除状态编排
│   ├── utils/
│   │   └── ssl_utils.dart            # certbot 命令构造和证书参数校验
│   └── views/
│       └── ssl_view.dart             # Certbot 检测、证书申请、续期和域名维护 UI
└── terminal_panel/
    └── views/
        └── .gitkeep                  # 预留独立终端面板目录；当前终端面板实现在 AppShell
```

#### `feature/utils`

```text
lib/feature/utils/
├── .gitkeep                          # 保留工具目录
├── home_directory.dart               # 本机 HOME 目录解析，兼容 macOS 沙盒环境
└── shell_quote.dart                  # Shell 参数安全引用工具
```

## 6. 当前命令执行架构

当前远端命令链路：

```text
View/Button
  -> 对应 part cubit 或全局 cubit
  -> CommandRunnerCubit
  -> OperationQueue
  -> feature/packages/ssh/SshExecutor
  -> feature/packages/ssh/PtySshSession
  -> 本机 PTY 启动 ssh user@host
  -> 在 SSH 会话中写入远端命令
  -> 命令包装为 begin/end marker + 子 shell
  -> 统一 stdout 监听
  -> TerminalLineBuffer / 页面解析器 / 状态栏
```

关键规则：

- 连接阶段和登录后命令都通过 `SshExecutor` / `PtySshSession` 统一处理。
- UI 层不能直接调用 `Process.start('ssh', ...)`。
- 业务命令应通过对应 part cubit 进入 `CommandRunnerCubit`，再由 `OperationQueue` 串行执行。
- 每条远端命令由 `PtySshSession` 包装 marker，用 marker 识别命令结束和 exit code。
- 业务解析器不应看到或解析 marker 行。
- 命令片段中允许出现 `exit`，但应依赖执行器的子 shell 包装，不能假设 `exit` 会关闭整个 SSH 会话。
- `runDetached` 仅用于确实需要一次性 SSH 子进程的特殊场景，默认不要使用。

## 7. 平台工程文件职责

平台目录主要由 Flutter 生成，原则上只做桌面壳层、插件注册、图标、窗口入口和构建配置修改，不放产品业务逻辑。

### Linux

```text
linux/
├── .gitignore                         # Linux 平台构建忽略规则
├── CMakeLists.txt                     # Linux 顶层 CMake 配置
├── flutter/
│   ├── CMakeLists.txt                 # Flutter Linux 引擎和插件构建配置
│   ├── generated_plugin_registrant.cc # Flutter 生成的插件注册实现
│   ├── generated_plugin_registrant.h  # Flutter 生成的插件注册声明
│   └── generated_plugins.cmake        # Flutter 生成的插件 CMake 清单
└── runner/
    ├── CMakeLists.txt                 # Linux runner 构建配置
    ├── main.cc                        # Linux 应用入口
    ├── my_application.cc              # GTK 应用窗口实现
    └── my_application.h               # GTK 应用窗口声明
```

### macOS

```text
macos/
├── .gitignore                                      # macOS 平台构建忽略规则
├── Flutter/
│   ├── Flutter-Debug.xcconfig                      # Debug Flutter 构建配置
│   ├── Flutter-Release.xcconfig                    # Release Flutter 构建配置
│   └── GeneratedPluginRegistrant.swift             # Flutter 生成的插件注册
├── Runner.xcodeproj/
│   ├── project.pbxproj                             # Xcode 工程配置
│   ├── project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist # Xcode workspace 检查配置
│   └── xcshareddata/xcschemes/Runner.xcscheme      # 共享运行 scheme
├── Runner.xcworkspace/
│   ├── contents.xcworkspacedata                    # Xcode workspace 描述
│   └── xcshareddata/IDEWorkspaceChecks.plist       # Xcode workspace 检查配置
├── Runner/
│   ├── AppDelegate.swift                           # macOS 应用代理入口
│   ├── MainFlutterWindow.swift                     # Flutter 主窗口创建
│   ├── Info.plist                                  # 应用包元数据和权限声明
│   ├── DebugProfile.entitlements                   # Debug/Profile 权限
│   ├── Release.entitlements                        # Release 权限
│   ├── Base.lproj/MainMenu.xib                     # macOS 菜单和主窗口资源
│   ├── Configs/AppInfo.xcconfig                    # 应用名称、Bundle ID 等配置
│   ├── Configs/Debug.xcconfig                      # Debug 构建配置
│   ├── Configs/Release.xcconfig                    # Release 构建配置
│   ├── Configs/Warnings.xcconfig                   # 编译警告配置
│   └── Assets.xcassets/AppIcon.appiconset/         # macOS 应用图标集合
└── RunnerTests/
    └── RunnerTests.swift                           # macOS runner 示例测试
```

macOS 图标文件：

```text
macos/Runner/Assets.xcassets/AppIcon.appiconset/
├── Contents.json
├── app_icon_16.png
├── app_icon_32.png
├── app_icon_64.png
├── app_icon_128.png
├── app_icon_256.png
├── app_icon_512.png
└── app_icon_1024.png
```

### Windows

```text
windows/
├── .gitignore                         # Windows 平台构建忽略规则
├── CMakeLists.txt                     # Windows 顶层 CMake 配置
├── flutter/
│   ├── CMakeLists.txt                 # Flutter Windows 引擎和插件构建配置
│   ├── generated_plugin_registrant.cc # Flutter 生成的插件注册实现
│   ├── generated_plugin_registrant.h  # Flutter 生成的插件注册声明
│   └── generated_plugins.cmake        # Flutter 生成的插件 CMake 清单
└── runner/
    ├── CMakeLists.txt                 # Windows runner 构建配置
    ├── main.cpp                       # Windows 应用入口
    ├── flutter_window.cpp             # Flutter 窗口实现
    ├── flutter_window.h               # Flutter 窗口声明
    ├── win32_window.cpp               # Win32 基础窗口实现
    ├── win32_window.h                 # Win32 基础窗口声明
    ├── utils.cpp                      # Windows 工具函数实现
    ├── utils.h                        # Windows 工具函数声明
    ├── resource.h                     # Windows 资源 ID
    ├── Runner.rc                      # Windows 资源脚本
    ├── runner.exe.manifest            # Windows 应用清单
    └── resources/app_icon.ico         # Windows 应用图标
```

## 8. 测试文件职责

```text
test/
├── widget_test.dart                         # Flutter 应用基础组件测试
├── core/
│   ├── terminal_control_sanitizer_test.dart # 终端控制序列清理测试
│   ├── terminal_line_buffer_test.dart       # 终端行缓冲测试
│   └── terminal_raw_output_test.dart        # 原始终端输出模型测试
└── feature/
    ├── nginx_template_test.dart             # Nginx 模板渲染测试
    ├── overview_parser_test.dart            # 概览输出解析测试
    ├── pty_ssh_session_test.dart            # PTY SSH 会话、marker 和命令结束识别测试
    ├── servers_store_test.dart              # 服务器配置本地读写测试
    └── shell_quote_test.dart                # Shell 参数引用测试
```

新增测试应优先覆盖：

- SSH 会话输出解析、超时、取消、exit code。
- 远端命令参数转义和输入校验。
- Nginx 写入、备份、失败回滚和 reload 流程。
- 本地 YAML 配置读写兼容性。
- 连接窗口首次授权、连接失败排查、host key 确认等关键交互。

## 9. 放置规则

推荐：

- 低业务耦合能力放 `lib/core/`。
- 产品内共享模型放 `lib/feature/classes/`。
- 产品内共享组件放 `lib/feature/components/`。
- 路由入口放 `lib/feature/pages/`。
- 页面主体和业务 UI 放 `lib/feature/parts/<part>/views/`。
- 模块状态和业务编排放 `lib/feature/parts/<part>/cubits/`。
- 模块专用命令构造、参数校验和输出解析放 `lib/feature/parts/<part>/utils/`。
- SSH、配置存储、通用模板渲染等跨模块集成能力放 `lib/feature/packages/`。
- 仅某个 part 使用的组件，先放在该 part 内；真实跨 part 复用后再上提。

避免：

- 在 Widget 中直接拼接完整 SSH 进程命令。
- 在 part 之间直接 import 对方的内部 `views/`、`components/`、`cubits/`。
- 把 Nginx、apt、systemd 等产品业务对象放到 `core`。
- 把 marker 解析逻辑散落到页面层。
- 在没有备份和回滚的情况下写 `/etc/nginx`。
- 为了保持目录完整创建空的 `classes/components/cubits` 子目录。

## 10. 命名约定

- 文件名使用 `snake_case.dart`。
- class 使用 `UpperCamelCase`。
- 页面入口以 `_page.dart` 结尾。
- 业务视图以 `_view.dart` 结尾。
- Store 以 `_store.dart` 结尾。
- Parser 以 `_parser.dart` 结尾。
- Renderer 以 `_renderer.dart` 结尾。
- Cubit 以 `_cubit.dart` 结尾。
- 产品级值对象按语义命名，例如 `server_profile.dart`、`command_result.dart`。

## 11. 推荐演进顺序

1. 保持 `part cubit -> CommandRunnerCubit -> OperationQueue -> SshExecutor -> PtySshSession` 的统一命令链路。
2. 补齐 SSH 会话、host key 弹窗、授权命令、排查命令的自动化测试。
3. 将 Nginx 写入、站点解析和证书扫描继续补充模块级测试。
4. 需要独立终端能力时，再把当前 `AppShell` 内终端面板拆到 `parts/terminal_panel/`。
5. 随业务扩展增加 `files`、`logs`、`cron` 等 part，仍遵守 part 边界。
