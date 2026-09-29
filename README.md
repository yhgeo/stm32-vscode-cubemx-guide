# STM32 + VS Code + STM32CubeMX 配置指南

面向第一次接触 STM32 的开发者。本文以 **Windows + STM32F103C8T6 + ST-Link** 为例，使用 **STM32CubeMX 的 CMake 工程生成器**和 **STM32CubeIDE for Visual Studio Code**，完成从配置、编译到烧录和断点调试的完整流程。

> 本仓库是“配置方法”和可复制模板，不是一个具体的 STM32 应用工程。文中的菜单名称和扩展行为可能随 ST 工具版本变化；遇到差异时，优先以官方文档和 VS Code 中当前显示的命令为准。

## 先看结论

推荐的主线只有这一条：

```text
CubeMX 配置芯片
  → Toolchain/IDE 选择 CMake
  → Generate Code
  → VS Code 打开工程根目录
  → 选择 CMake preset（先用 Debug）
  → Discover STM32Cube project
  → Configure
  → Build / Run and Debug
```

烧录和调试优先使用 ST 扩展自己的 ST-Link GDB Server。OpenOCD 仅在你明确需要外部调试器、脚本或 CI 流程时再启用；它不是这套指南的默认依赖。

## 1. 工具清单

| 工具 | 用途 | 安装建议 |
| --- | --- | --- |
| Visual Studio Code | 编辑、构建、调试入口 | 从官方渠道安装 |
| STM32CubeMX | 配置 MCU、引脚、时钟和外设并生成代码 | 安装后确认对应 STM32 固件包可用 |
| STM32CubeIDE for Visual Studio Code | ST 的项目发现、CMake、烧录和调试集成 | 在扩展市场搜索 `STM32`，选择 STMicroelectronics 发布的扩展 |
| ST-Link USB 驱动 | 让 Windows 识别调试器 | 在 ST 扩展的 STM32Cube Resources 中安装；当前版本通常需要管理员权限 |
| STM32 固件包 | HAL、CMSIS 和设备支持文件 | 通过 CubeMX 或 ST 扩展安装 |

ST 扩展会通过 bundles 管理 CMake、Ninja、GCC/GDB、clangd 等工具。不要把某一台电脑上的 bundle 版本号或 `C:\Users\某人\...` 路径复制进仓库。

如果电脑上还残留旧版 STM32 VS Code 扩展 2.x，升级到新版前先按 ST 的迁移说明处理；不要把 2.x 的设置和新版扩展的设置混用。

### VS Code 安装在带空格的路径

你的电脑当前使用的是：

```text
程序：D:\VS Code\Microsoft VS Code\Code.exe
命令行入口：D:\VS Code\Microsoft VS Code\bin\code.cmd
```

这不会影响 VS Code 本身或 ST 扩展。安装目录可以包含空格；但创建 CubeMX 工程时，仍建议把**工程目录**放在无中文、无空格的路径中。项目模板也不应写死上述安装路径，因为换电脑或换安装方式后会失效。

如果 `code` 命令在 PowerShell 中找不到，可临时这样打开当前工程：

```powershell
& 'D:\VS Code\Microsoft VS Code\bin\code.cmd' .
```

也可以把 `D:\VS Code\Microsoft VS Code\bin` 加入用户 `PATH`，之后直接使用 `code .`。这只是命令行便利设置，不需要写入项目的 `.vscode/settings.json`、`tasks.json` 或 CMake 文件。

## 2. 用 CubeMX 生成 CMake 工程

1. 打开 CubeMX，选择 `File → New Project`，搜索目标 MCU，例如 `STM32F103C8`。
2. 配置最小硬件环境：
   - `System Core → SYS → Debug` 选择 `Serial Wire`。
   - 按实际硬件配置 HSE；没有外部晶振时不要照抄 `Crystal/Ceramic Resonator`。
   - 在 `Clock Configuration` 中确认目标频率和输入时钟与板卡一致。
3. 打开 `Project Manager`：
   - 工程名建议使用英文、数字、连字符或下划线。
   - 工程路径建议使用无中文、无空格的短路径，减少第三方工具兼容问题。
   - `Toolchain / IDE` 选择 **CMake**。
4. 点击 `GENERATE CODE`。

如果选择了 `STM32CubeIDE` 或 `Makefile`，就不会得到本指南主线所需的 CMake 工程。CubeMX 重新生成后，请查看版本控制中的变更；CMake 文件、启动文件和初始化代码都可能被更新。

### 生成后先检查

工程根目录通常应包含以下内容（不同 MCU 和 CubeMX 版本会有差异）：

```text
工程根目录/
├── <工程名>.ioc
├── CMakeLists.txt
├── CMakePresets.json
├── cmake/
│   ├── gcc-arm-none-eabi.cmake
│   └── stm32cubemx/
├── Core/
│   ├── Inc/
│   └── Src/
├── Drivers/
├── <链接脚本>.ld
└── startup_*.s
```

不要把 `build/`、`*.elf`、`*.map` 等构建产物提交到仓库。`.ioc`、CMake 文件和能复现构建所需的源文件应提交。

## 3. 在 VS Code 中导入、配置和构建

1. 用 `File → Open Folder...` 打开**包含 `.ioc` 和 `CMakeLists.txt` 的工程根目录**，不要只打开 `Core/`。如果用命令行打开，可在路径带空格时加引号：`code "D:\\Projects\\Blink"`。
2. 从 CMake 状态栏或命令面板选择 `Debug` preset。
3. 打开左侧 STM32CubeIDE 视图，运行 `Discover STM32Cube project`；按提示选择设备、工具链和目标工程。
4. 运行 CMake `Configure`。
5. 在 CMake 视图或 STM32CubeIDE 视图中执行 `Build`。
6. 第一次构建成功后，再从 `Run and Debug` 启动 ST-Link 调试。

Debug 和 Release 是两套独立的配置上下文。切换 preset 后要重新 Configure，并确保编辑器索引、构建输出和调试使用的是同一个 preset。

### 为什么默认不用手写 settings.json

ST 扩展和 CMake Tools 会从 `CMakePresets.json`、已安装 bundles 和当前工作区推导工具路径。固定写入 `cube-cmake`、`CUBE_BUNDLE_PATH`、clangd 版本号等内部细节，会使模板随着扩展升级失效。

如果项目团队确实需要共享 VS Code 设置，可复制 [`templates/settings.json`](templates/settings.json)。该文件只保留 preset 和项目发现相关设置，不包含机器路径。

## 4. 代码该写在哪里

CubeMX 生成的文件和用户文件混在一个工程里，这是最容易误操作的地方。

| 文件/目录 | 维护方式 |
| --- | --- |
| `.ioc` | 通过 CubeMX 修改，是硬件和中间件配置的源文件 |
| `Core/Src`、`Core/Inc` | 业务代码和头文件；生成文件优先写在 `USER CODE BEGIN/END` 区域 |
| `Drivers` | 通常由 CubeMX/固件包生成，不要随意改动 |
| `CMakeLists.txt`、`CMakePresets.json` | 构建配置；修改前先确认 CubeMX 版本的生成结构 |
| `cmake/stm32cubemx` | CubeMX 管理的源文件和库清单，除非知道影响，否则不要手改 |
| `.vscode` | 团队共享的编辑器、任务和调试配置；本机路径不要提交 |
| `build` | CMake 生成的临时目录，不提交 |

### 新增源文件

稳妥做法是把新文件加入工程根目录 `CMakeLists.txt` 的 `target_sources()`。如果你希望新增 `Core/Src/*.c` 后自动参与构建，可以使用 [`templates/CMakeLists-auto-sources.cmake`](templates/CMakeLists-auto-sources.cmake)。

自动收集方案必须排除 CubeMX 已经登记的源文件，否则会产生重复定义。它只收集 `Core/Src` 的一级目录；更复杂的 `bsp/`、`App/` 等目录应显式加入 CMake，避免文件边界不清晰。

## 5. 代码补全：clangd 与 compile_commands

本指南主推 ST 扩展提供的 clangd：

1. 先成功 Configure/Build，让 CMake 生成 `build/Debug/compile_commands.json`。
2. 将 [`templates/dot-clangd`](templates/dot-clangd) 复制到工程根目录并改名为 `.clangd`。
3. 如果你还安装了 Microsoft C/C++ 扩展，不要同时让两套语言服务器争夺诊断；需要使用 cpptools 时再复制 [`templates/c_cpp_properties.json`](templates/c_cpp_properties.json)，并关闭另一套诊断功能。
4. 修改 preset 后，重新 Configure；必要时执行 `clangd: Restart language server`。

三个路径必须保持一致：

| 位置 | Debug 示例 |
| --- | --- |
| CMake preset | `Debug` |
| `compile_commands.json` | `build/Debug/compile_commands.json` |
| `.clangd` | `CompilationDatabase: build/Debug` |

不要把 `compile_commands.json` 复制到仓库根目录作为“修复”；它是当前机器和当前构建目录的生成结果。

## 6. 烧录与调试

### 推荐：ST-Link 原生调试

新版 ST 扩展可以在 Run and Debug 中生成默认的 ST-Link GDB Server 配置；如果项目需要将配置提交给团队，可复制 [`templates/launch.json`](templates/launch.json)。该配置不写死 GDB、ELF 和用户目录，实际目标由当前工程和 preset 决定。

开始调试前检查：

- ST-Link 已连接且驱动正常。
- 目标板供电、SWDIO、SWCLK、GND 和 NRST（如需要）连接正确。
- CubeMX 的 `SYS → Debug` 是 `Serial Wire`。
- Run and Debug 选中的项目、preset 和目标板是当前要操作的对象。

### 可选：OpenOCD 外部路线

只有需要 OpenOCD 脚本、第三方调试器或独立命令行流程时才使用它。复制 [`templates/openocd.cfg`](templates/openocd.cfg)，确保 `openocd` 已安装并在 VS Code 进程的 `PATH` 中，然后再使用 [`templates/tasks.json`](templates/tasks.json)。

该路线与 ST 原生调试是两套独立方案：不要同时启动两个 GDB Server，也不要把 OpenOCD 的 `miDebuggerPath` 复制到 ST 原生配置中。首次烧录前确认 ELF 文件名和路径，避免把错误工程写入目标板。

## 7. 常见问题排查

### “找不到 cmake / arm-none-eabi-gcc”

先在 VS Code 内运行 Configure/Build。ST bundles 注入的工具环境不一定出现在普通 PowerShell 的 `PATH` 中；不要因为终端找不到命令就重复安装一套互相冲突的 GCC/CMake。

### 满屏红波浪线，但构建成功

通常是没有 Configure、`.clangd` 指向了旧 build 目录，或同时启用了两套语言服务器。删除对应 `build/<preset>` 后重新 Configure，再重启 clangd。

### F5 找不到 ELF 或调试器

确认工程根目录已打开、项目已被 Discover、preset 已选择且 Build 成功。优先使用 ST 扩展生成的默认调试配置；不要手动填写网上复制来的 `gdb-multiarch` 路径。

### “Can't find interface/stlink.cfg”

这是 OpenOCD 路线的问题。确认 OpenOCD 安装完整、命令来自正确版本，并让 `openocd` 自己定位 `scripts` 目录；不要提交某个开发者电脑上的 `D:/OpenOCD/...`。

### 烧录后无法连接

检查 SWD 接线、供电、NRST 和 `SYS → Debug → Serial Wire`。必要时用 BOOT0 进入系统 Bootloader 或使用 ST-LINK Utility/CubeProgrammer 的连接选项恢复调试口；具体操作按芯片参考手册和板卡原理图执行。

### 扩展升级后配置失效

先查看 ST 扩展的迁移说明和 Output 面板。重点检查：是否混用了 2.x 配置、项目是否需要重新 Discover、CMake preset 是否仍存在、bundle 是否安装完整。不要直接把旧模板里的版本号改成一个猜测值。

## 8. 仓库模板

| 文件 | 复制到 | 说明 |
| --- | --- | --- |
| `settings.json` | `.vscode/settings.json` | 只放稳定的工作区设置和 preset |
| `dot-clangd` | 工程根目录并改名 `.clangd` | clangd 使用的编译数据库目录 |
| `c_cpp_properties.json` | `.vscode/c_cpp_properties.json` | cpptools 可选配置，不是 clangd 必需项 |
| `launch.json` | `.vscode/launch.json` | ST-Link 原生调试配置，可先让扩展自动生成 |
| `tasks.json` | `.vscode/tasks.json` | OpenOCD 外部路线，可选；要求 `openocd` 在 PATH |
| `openocd.cfg` | 工程根目录 | OpenOCD 外部路线，可选 |
| `CMakeLists-auto-sources.cmake` | 粘贴到工程 `CMakeLists.txt` | 自动收集 `Core/Src/*.c` 的示例 |

复制模板后，先运行 `pwsh -File scripts/validate.ps1` 检查 JSON、路径和文档链接；模板不包含真实设备，所以不能在本仓库直接完成 MCU 编译。

## 9. 参考资料

- [STM32CubeIDE for Visual Studio Code：Installation](https://dev.st.com/stm32cube-docs/stm32cubeide-vscode/latest/en/docs/markup/getting_started/installation.html)
- [STM32CubeIDE for Visual Studio Code：First project creation](https://dev.st.com/stm32cube-docs/stm32cubeide-vscode/latest/en/docs/markup/getting_started/first_project_creation.html)
- [STM32CubeIDE for Visual Studio Code：Project files](https://dev.st.com/stm32cube-docs/stm32cubeide-vscode/latest/en/docs/markup/workspace_and_extension_workflow/project_files.html)
- [STM32CubeIDE for Visual Studio Code：Debug](https://dev.st.com/stm32cube-docs/stm32cubeide-vscode/latest/en/docs/markup/development/debug.html)
- [STM32CubeIDE for Visual Studio Code：2.x → 3.x 迁移](https://dev.st.com/stm32cube-docs/stm32cubeide-vscode/latest/en/docs/markup/tutorials/migration.html)
- [STM32CubeMX 用户手册 UM1718](https://www.st.com/resource/en/user_manual/dm00104712-stm32cubemx-for-stm32-configuration-and-initialization-c-code-generation-stmicroelectronics.pdf)

## 10. 维护策略

- README 只描述稳定流程，不写具体 bundle 版本号。
- 模板不写开发者本机的绝对路径。
- ST 扩展或 CubeMX 大版本变化时，先更新“工具清单”“导入流程”和模板，再运行校验脚本。
- 每次修改后检查 `.ioc`、CMake 文件和生成代码的版本控制差异。

## License

MIT
