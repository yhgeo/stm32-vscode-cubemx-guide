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

## 目录

- [从零创建到烧录：完整流程](#从零创建到烧录完整流程)
- [1. 工具清单](#1-工具清单)
- [2. 用 CubeMX 生成 CMake 工程](#2-用-cubemx-生成-cmake-工程)
- [3. 在 VS Code 中导入、配置和构建](#3-在-vs-code-中导入配置和构建)
- [4. 代码该写在哪里](#4-代码该写在哪里)
- [5. 代码补全：clangd 与 compile_commands](#5-代码补全clangd-与-compile_commands)
- [6. 烧录与调试](#6-烧录与调试)
- [7. 常见问题排查](#7-常见问题排查)
- [8. 仓库模板](#8-仓库模板)
- [9. 参考资料](#9-参考资料)
- [10. 维护策略](#10-维护策略)

## 从零创建到烧录：完整流程

这一节只走一次最短成功路径：创建一个最小 GPIO 工程，编译后用 ST-Link 下载并运行。后面的章节再解释文件结构、代码补全和高级配置。

### 0. 准备工具和硬件

安装 VS Code、STM32CubeMX、STM32CubeIDE for Visual Studio Code 扩展和 ST-Link USB 驱动。扩展安装方式、驱动安装位置和当前版本注意事项，以 [ST 官方安装文档](https://dev.st.com/stm32cube-docs/stm32cubeide-vscode/latest/en/docs/markup/getting_started/installation.html) 为准。

准备一块 STM32F103C8T6 开发板、ST-Link、杜邦线和一个可观察的 LED。LED 可以是板载 LED，也可以是接在 GPIO 上的外部 LED；具体引脚以你的板卡原理图为准，不要盲目照抄别人的 `PC13`。

### 1. 在 CubeMX 新建工程

1. 打开 CubeMX，选择 `File → New Project`，搜索并选中目标 MCU，例如 `STM32F103C8T6`。
2. 在 `System Core → SYS → Debug` 选择 **Serial Wire**，保留 SWD 调试口。
3. 配置一个 GPIO 输出作为 LED，例如选择板卡原理图对应的引脚，并设置为 `GPIO_Output`；如果要让代码变量名清楚，可以把 GPIO Label 设为 `LED`。
4. 按实际晶振配置 `RCC` 和 `Clock Configuration`。Blue Pill 常见外部晶振是 8 MHz，但不同板卡可能不同；时钟必须以实物为准。
5. 打开 `Project Manager`，填写：

   | 项目 | 示例 |
   | --- | --- |
   | Project Name | `Blink` |
   | Project Location | `D:\\STM32\\Blink` |
   | Toolchain / IDE | `CMake` |

6. 在代码生成设置中，初学者建议选择把使用到的固件库复制到工程目录，并启用保留用户代码区域。这样工程交给另一台电脑时，不依赖某个开发者本机的固件库路径。
7. 点击 `GENERATE CODE`，确认工程目录中出现 `.ioc`、`CMakeLists.txt`、`CMakePresets.json`、`Core/`、`Drivers/` 和 `cmake/`。

### 2. 用你的 VS Code 打开工程根目录

你的 VS Code 命令行入口是：

```powershell
& 'D:\\VS Code\\Microsoft VS Code\\bin\\code.cmd' 'D:\\STM32\\Blink'
```

也可以在 VS Code 中使用 `File → Open Folder...` 打开 `D:\\STM32\\Blink`。必须打开包含 `.ioc` 和 `CMakeLists.txt` 的工程根目录，不要只打开 `Core/`。

### 3. 让 ST 扩展识别并配置工程

1. 在 VS Code 左侧打开 STM32CubeIDE 视图。
2. 如果扩展没有自动识别工程，运行 `Discover STM32Cube project`。
3. 按提示选择 MCU、工具链和主工程。
4. 在 CMake 状态栏或命令面板中选择 `Debug` preset。
5. 执行 `Configure`。成功后应出现 `build/Debug/`，其中会有 CMake/Ninja 文件和 `compile_commands.json`。

这是 ST 官方推荐的导入顺序：先打开工程根目录，再选择 CMake preset、Discover 项目并 Configure；具体界面以当前扩展版本为准。[ST 首次创建项目文档](https://dev.st.com/stm32cube-docs/stm32cubeide-vscode/latest/en/docs/markup/getting_started/first_project_creation.html) 有完整流程。

### 4. 写入最小点灯代码

打开 `Core/Src/main.c`，只在 CubeMX 留出的用户代码区域中添加逻辑。GPIO Label 为 `LED` 时，示例通常如下；如果生成的名字不同，以 `main.c` 中实际的 `LED_Pin` 和 `LED_GPIO_Port` 为准：

```c
/* USER CODE BEGIN 2 */
/* USER CODE END 2 */

/* USER CODE BEGIN WHILE */
while (1)
{
    HAL_GPIO_TogglePin(LED_GPIO_Port, LED_Pin);
    HAL_Delay(500);
}
/* USER CODE END WHILE */
```

如果你的 LED 为低电平点亮，第一次运行时可能表现为“亮灭逻辑反着”，这不代表工程失败。若使用外部 LED，还要确认串联限流电阻和极性。

### 5. 编译工程

在 VS Code 中执行 CMake `Build`，或从 STM32CubeIDE 视图执行构建。第一次构建只使用 `Debug`，不要同时切换 Release、手写 GCC 路径或添加 OpenOCD。

成功标准：

- 终端没有 `error:` 或 `undefined reference`。
- `build/Debug/` 下生成工程的 `.elf` 文件。
- `compile_commands.json` 已生成，代码补全不再完全依赖手写 include 路径。

如果构建失败，先修复构建错误再进行烧录；烧录失败通常不是通过反复按 F5 解决的。

### 6. 连接 ST-Link

连接前断开可能造成冲突的其他调试器。常见 SWD 接线如下：

| ST-Link | 目标板 |
| --- | --- |
| `SWDIO` | `SWDIO` |
| `SWCLK` | `SWCLK` |
| `GND` | `GND` |
| `3.3V / VTref` | 目标板电压参考或按板卡说明连接 |
| `NRST` | `NRST`，连接不上时再接 |

不要同时用两个电源给目标板供电；`VTref` 的接法以 ST-Link 和开发板说明为准。确认目标板供电、SWDIO/SWCLK 没接反，并且 CubeMX 中启用了 `Serial Wire`。

### 7. 烧录并运行

推荐用 ST 扩展的原生调试流程完成第一次下载：

1. 打开 `Run and Debug`。
2. 选择 `STM32Cube: STM32 Launch ST-Link GDB Server`；如果没有 `launch.json`，点击创建调试配置并选择 ST-Link。
3. 按 `F5`。
4. 扩展会构建工程、启动 ST-Link GDB Server、把当前 `.elf` 下载到芯片并复位，通常停在 `main`。
5. 点击继续运行；LED 应按代码间隔闪烁。

ST 文档说明，首次调试可能需要在 STM32Cube 设备视图中更新 ST-Link 固件；如果没有可供调试的 ELF，先回到构建步骤排查。[ST 调试文档](https://dev.st.com/stm32cube-docs/stm32cubeide-vscode/latest/en/docs/markup/development/debug.html)

如果你只想下载、不想停在断点，可以在 ST 扩展提供的烧录/程序下载入口中选择当前工程和 ST-Link。不要把不同工程的 ELF 拖进烧录工具；下载前核对工程名、preset 和输出文件。

### 8. 第一次成功后的日常循环

```text
只改业务逻辑       → 编辑 Core/Src 的用户代码 → Build → F5
改引脚/时钟/外设   → 修改 .ioc → Generate Code → 检查变更 → Configure → Build → F5
新增 .c 文件       → 加入 CMakeLists.txt 或采用自动收集模板 → Configure → Build
```

到这里，已经完成了“从空工程到能烧录、能运行、能断点调试”的最小闭环。后续再按下面章节配置 clangd、Release 和 OpenOCD。

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
