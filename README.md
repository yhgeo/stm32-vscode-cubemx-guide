# STM32 + VS Code + STM32CubeMX 配置指南

面向零基础。以 **Windows + STM32F103C8T6 + ST-Link** 为例，用 **ST 官方 VS Code 扩展**搭一条能编译、能烧录、能打断点调试的完整链路。

> 这份指南记录的是「配置方法」，不是某个具体工程的代码。照着做，从空电脑到能点灯。

---

## 目录

- [0. 先搞懂：这套方案在干什么](#0-先搞懂这套方案在干什么)
- [1. 概念扫盲：编译一个 STM32 程序需要哪些东西](#1-概念扫盲编译一个-stm32-程序需要哪些东西)
- [2. 安装清单](#2-安装清单)
- [3. 第一步：用 CubeMX 生成工程](#3-第一步用-cubemx-生成工程)
- [4. 认识 CubeMX 生成的文件](#4-认识-cubemx-生成的文件)
- [5. 第二步：配置 .vscode 三件套](#5-第二步配置-vscode-三件套)
- [6. 第三步：日常开发循环](#6-第三步日常开发循环)
- [7. 常见坑与排查](#7-常见坑与排查)
- [8. 速查表](#8-速查表)
- [附录：国内网络给 git 配代理](#附录国内网络给-git-配代理)

---

## 0. 先搞懂：这套方案在干什么

三个软件，各干一件事：

| 软件 | 角色 | 干什么 |
| --- | --- | --- |
| **STM32CubeMX** | 配置器 | 图形界面点一点，配好引脚/时钟/外设，生成工程骨架 |
| **VS Code + ST 官方扩展** | 编辑器 + 指挥部 | 写代码、编译、烧录、调试 |
| **ST-Link 调试器** | 桥梁 | 一根 USB 线，让电脑能往芯片里写程序、读状态 |

一句话流程：

```
CubeMX 配好芯片 ──> 生成工程 ──> VS Code 写代码 ──> 编译 ──> 烧进芯片 ──> 调试
```

**关键认知**：CubeMX 只负责「生成骨架」和「外设初始化代码」，你写的业务代码（点灯逻辑、按键逻辑）要自己加，而且要手动登记到构建清单里。它不会自动帮你找到新文件。

---

## 1. 概念扫盲：编译一个 STM32 程序需要哪些东西

你写的是 C 语言，芯片只认机器码。中间要过好几道手，每一道都对应一个工具。**看不懂这些名词，配置时就会一头雾水**，所以先花两分钟。

### 1.1 翻译官：编译器（arm-none-eabi-gcc）

`gcc` 是 Linux 世界最常见的编译器。你电脑上跑的是 Windows，芯片是 ARM 架构，所以要用**交叉编译器**——名字里的 `arm-none-eabi` 就是「给 ARM 芯片、没有操作系统（bare metal）」的意思。

它把 `.c` 翻译成 `.o`，再把一堆 `.o` 拼成 `.elf`（可执行文件）。

### 1.2 施工图：链接脚本（.ld）

芯片的内存不是一块整的，分 **Flash**（存程序，断电不丢，F103C8 有 64KB）和 **RAM**（运行时的变量，20KB）。链接脚本 `STM32F103xx_FLASH.ld` 就是告诉链接器：代码从哪开始放、变量放哪、堆栈多大。

**你一般不用改它**，但要知道它的存在——「程序太大烧不进去」这类问题就出在这。

### 1.3 包工头：构建系统（CMake + Ninja）

一个工程有几十个源文件，手敲编译命令不现实。所以要有工具自动按顺序调用编译器：

- **CMake**：读 `CMakeLists.txt`（构建说明书），生成具体的构建命令
- **Ninja**：真正执行这些命令，速度快

这俩的关系：CMake 是「出图纸的」，Ninja 是「干活的」。

### 1.4 地图：compile_commands.json

VS Code 想知道「每个文件是用什么参数编译的」，才能给你正确的代码补全和跳转。CMake 在配置阶段会顺手生成这个文件（`CMAKE_EXPORT_COMPILE_COMMANDS=TRUE`），**代码智能工具（clangd）读它来建索引**。

⚠️ 这是后面最容易踩坑的地方——地图和实际构建目录对不上，补全就会乱。

### 1.5 下载线和翻译官：ST-Link + GDB Server + GDB

烧录和调试是两件事，工具也不同：

| 事情 | 工具 | 说明 |
| --- | --- | --- |
| 把程序写进 Flash | ST-Link + 烧录程序 | 一次性写入 |
| 打断点、单步、看变量 | ST-Link + **GDB Server** + **GDB** | GDB Server 负责和芯片对话，GDB 负责控制 |

ST 官方扩展把这三样都打包好了，**你不用自己配**。

### 1.6 代码智能：clangd

负责补全、跳转、找定义、看错误。它读 1.4 说的那张地图。ST 扩展自带一个专门给 ARM 用的 clangd，不需要另外装社区版。

---

## 2. 安装清单

| # | 装什么 | 从哪装 | 备注 |
| --- | --- | --- | --- |
| 1 | **VS Code** | code.visualstudio.com | 装哪个盘都行 |
| 2 | **STM32CubeMX** | st.com（需注册 ST 账号） | 建议装到**路径无中文无空格**的地方 |
| 3 | **STM32Cube for Visual Studio Code** | VS Code 扩展市场搜 `STM32Cube` | 装官方那个（发布者 STMicroelectronics） |
| 4 | **ST-Link 驱动** | 装 CubeMX 或 CubeProgrammer 时勾选 | 不装的话电脑认不出调试器 |

### 装扩展时要注意

搜 `STM32Cube`，会看到发布者是 **STMicroelectronics** 的那个。**装上它之后会自动带一堆子扩展**（`stm32cube-ide-*` 开头的十几个），这些不用管，是配套的。

装完确认一下有没有这些（缺了会出问题）：

```
stmicroelectronics.stm32-vscode-extension        ← 主扩展
stmicroelectronics.stm32cube-ide-core
stmicroelectronics.stm32cube-ide-clangd          ← 代码补全
stmicroelectronics.stm32cube-ide-build-cmake     ← 构建集成
stmicroelectronics.stm32cube-ide-debug-stlink-gdbserver  ← ST-Link 调试
ms-vscode.cmake-tools                            ← CMake 工具（一般会自动装）
```

### 关于「工具从哪来」

ST 这套扩展有个特点：**编译器、CMake、Ninja、GDB 这些工具它自己下载并管理**，不会污染系统 PATH。它们放在：

```
%LOCALAPPDATA%\stm32cube\bundles\
```

里面是 `cmake`、`ninja`、`gnu-tools-for-stm32`、`gnu-gdb-for-stm32`、`st-arm-clangd`、`stlink-gdbserver`、`programmer` 等一堆目录，每个目录下是版本号。

**这意味着**：

- 你在普通终端里敲 `cmake`、`arm-none-eabi-gcc` 可能找不到——这是正常的
- 扩展在运行时会把对应路径临时注入 PATH，所以 VS Code 里的任务能跑
- 扩展 ID 里的 `cube-cmake`、`cube` 这类命令，只有扩展启动的环境里才有效

---

## 3. 第一步：用 CubeMX 生成工程

### 3.1 新建工程

1. 打开 CubeMX → `File` → `New Project`
2. 选芯片：搜索你的型号（如 `STM32F103C8`）→ 双击选中
3. 配置外设：
   - 点引脚图上的引脚，选功能（如 `GPIO_Output` 点灯、`GPIO_Input` 接按键）
   - `System Core` → `SYS` → Debug 选 **Serial Wire**（不选的话烧一次就锁死芯片）
   - `System Core` → `RCC` → HSE 选 `Crystal/Ceramic Resonator`（板上有晶振就选）
4. 配时钟：`Clock Configuration` 标签页，直接填目标频率（F103 一般 72MHz），让它自动算

### 3.2 ⚠️ 最关键的一步：Toolchain 选 CMake

`Project Manager` 标签页：

| 项目 | 选什么 |
| --- | --- |
| **Project Name** | 英文，无空格（如 `2-key-led`） |
| **Project Location** | **纯英文路径，不要有中文和空格** |
| **Toolchain / IDE** | **`CMake`** ← 选错这里，后面全白干 |

选 `CMake` 才会生成我们需要的 `CMakeLists.txt` 和 `CMakePresets.json`。如果你看到的是 `STM32CubeIDE`、`Makefile`，那就是选错了。

### 3.3 生成代码

点右上角 `GENERATE CODE`。

### 3.4 以后每次改配置都要重新生成

改了引脚、加了外设之后，回到 CubeMX 再点一次 `GENERATE CODE`。

**注意**：CubeMX 会重新生成 `Core/` 下的初始化代码，但**不会覆盖你在 `CMakeLists.txt` 里手动加的源文件**（它只在第一次生成这个文件）。所以你加的文件会一直保留——这是好事，也是坑（见 [7.2](#72-自己写的-c-文件编译不进去)）。

---

## 4. 认识 CubeMX 生成的文件

生成完，工程目录长这样：

```
你的工程/
├── 你的工程.ioc              ← CubeMX 的配置存档，双击能重新打开 CubeMX
├── CMakeLists.txt            ← 构建说明书（★ 你要手动改）
├── CMakePresets.json         ← 预设：定义 Debug / Release 两套构建
├── STM32F103xx_FLASH.ld      ← 链接脚本（内存布局）
├── startup_stm32f103xb.s     ← 启动汇编，芯片上电后第一段代码
├── openocd.cfg               ← OpenOCD 调试配置（可选）
├── .clangd                   ← 告诉 clangd 去哪找代码地图
├── .mxproject                ← CubeMX 内部记录，别动
├── cmake/
│   ├── gcc-arm-none-eabi.cmake   ← 工具链定义（编译器参数都在这）
│   └── stm32cubemx/              ← CubeMX 自动收集的源文件清单
├── Core/
│   ├── Inc/                  ← 头文件
│   └── Src/                  ← 源文件（main.c 在这）
├── Drivers/                  ← HAL 库（ST 官方的硬件抽象层）
├── build/                    ← 编译产物（Debug/ 和 Release/）
└── .vscode/                  ← VS Code 配置（★ 你要手动建）
```

### 几个你要关心的

**`cmake/gcc-arm-none-eabi.cmake`** —— 编译器参数。打开能看到：

```cmake
set(TARGET_FLAGS "-mcpu=cortex-m3 ")          # 目标芯片架构
set(CMAKE_C_FLAGS_DEBUG "-O0 -g3")            # Debug：不优化，带调试信息
set(CMAKE_C_FLAGS_RELEASE "-Os -g0")          # Release：优化体积，去掉调试信息
```

`-O0` 不优化，方便打断点看变量；`-Os` 优化到最小体积。**学习阶段一律用 Debug**。

**`CMakePresets.json`** —— 定义了两套预设，产物分别落在 `build/Debug/` 和 `build/Release/`：

```json
"binaryDir": "${sourceDir}/build/${presetName}"
```

---

## 5. 第二步：配置 .vscode 三件套

在工程根目录新建 `.vscode/` 文件夹，放三个文件。**模板见本仓库 [`templates/`](templates/) 目录，可直接复制。**

### 5.1 settings.json —— 告诉 VS Code 用哪套工具

```json
{
    "cmake.cmakePath": "cube-cmake",
    "cmake.configureArgs": [
        "-DCMAKE_COMMAND=cube-cmake"
    ],
    "cmake.preferredGenerators": [
        "Ninja"
    ],
    "stm32cube-ide-clangd.path": "cube",
    "stm32cube-ide-clangd.arguments": [
        "starm-clangd",
        "--query-driver=${env:CUBE_BUNDLE_PATH}/gnu-tools-for-stm32/14.3.1+st.2/bin/arm-none-eabi-gcc*",
        "--query-driver=${env:CUBE_BUNDLE_PATH}/gnu-tools-for-stm32/14.3.1+st.2/bin/arm-none-eabi-g++*"
    ],
    "stm32cube-ide-build-cmake.ignoreCubeProjectDiscovery": false,
    "cmake.configurePreset": "Debug",
    "cmake.buildPreset": "Debug"
}
```

逐项解释：

| 设置 | 作用 |
| --- | --- |
| `cmake.cmakePath: "cube-cmake"` | 用 ST 扩展管理的 cmake，不是系统里的 |
| `cmake.preferredGenerators: ["Ninja"]` | 用 Ninja 而不是 Make |
| `stm32cube-ide-clangd.path: "cube"` | 用 ST 扩展管理的 clangd |
| `--query-driver=...` | 让 clangd 去问编译器「你的头文件在哪」，**不写会导致满屏红波浪线** |
| `cmake.configurePreset/buildPreset: "Debug"` | 默认用 Debug 预设 |

⚠️ `--query-driver` 里的版本号 `14.3.1+st.2` 是写死的。扩展升级工具链后版本号会变，**那时要回来改这两行**。对照实际目录：

```
%LOCALAPPDATA%\stm32cube\bundles\gnu-tools-for-stm32\
```

### 5.2 c_cpp_properties.json —— 代码地图的位置

```json
{
    "configurations": [
        {
            "name": "STM32",
            "compileCommands": "${workspaceFolder}/build/Debug/compile_commands.json"
        }
    ]
}
```

**这一行路径必须和你的构建预设一致**。如果你用 Debug 构建，这里就写 `build/Debug`。

### 5.3 .clangd —— 同样指向代码地图

放在工程根目录（不是 `.vscode/` 里）：

```yaml
CompileFlags:
  CompilationDatabase: build/Debug
```

**5.2 和 5.3 必须指向同一个目录，而且要和 settings.json 里的 preset 一致。** 三处对不上就是补全失效的经典原因。

### 5.4 launch.json —— 调试配置（推荐 ST 官方路线）

ST 扩展提供了自己的调试类型，**不用手写路径**，它会自动找到编译产物：

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "type": "stlinkgdbtarget",
            "request": "launch",
            "name": "STM32Cube: Launch ST-Link GDB Server",
            "origin": "snippet",
            "cwd": "${workspaceFolder}",
            "preBuild": "${command:st-stm32-ide-debug-launch.build}",
            "runEntry": "main",
            "imagesAndSymbols": [
                {
                    "imageFileName": "${command:st-stm32-ide-debug-launch.get-projects-binary-from-context1}"
                }
            ]
        }
    ]
}
```

关键点：

- `preBuild` —— 按 F5 前自动先编译，不用手动构建
- `get-projects-binary-from-context1` —— 扩展动态解析产物路径，**这就是为什么不用写死绝对路径**
- 前提：`.vscode/settings.json` 里配了正确的 preset

### 5.5 tasks.json —— 一键编译 + 烧录（可选）

如果你想要「按一个键，编译完自动烧进芯片」，加这个。**注意把路径换成你机器上的实际路径**：

```json
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "CMake: Build (Debug)",
            "type": "shell",
            "command": "${env:LOCALAPPDATA}/stm32cube/bundles/cmake/4.3.1+st.1/bin/cmake.exe",
            "args": ["--build", "${workspaceFolder}/build/Debug"],
            "options": {
                "env": {
                    "PATH": "${env:LOCALAPPDATA}/stm32cube/bundles/gnu-tools-for-stm32/14.3.1+st.2/bin;${env:LOCALAPPDATA}/stm32cube/bundles/ninja/1.13.2+st.1/bin;${env:PATH}"
                }
            },
            "group": { "kind": "build", "isDefault": true },
            "presentation": { "reveal": "always", "panel": "shared" },
            "problemMatcher": {
                "owner": "gcc",
                "fileLocation": ["relative", "${workspaceFolder}"],
                "pattern": {
                    "regexp": "^(.*):(\\d+):(\\d+):\\s+(warning|error):\\s+(.*)$",
                    "file": 1, "line": 2, "column": 3, "severity": 4, "message": 5
                }
            }
        },
        {
            "label": "OpenOCD: Flash",
            "type": "shell",
            "command": "D:/OpenOCD/bin/openocd.exe",
            "args": [
                "-f", "${workspaceFolder}/openocd.cfg",
                "-c", "program ${workspaceFolder}/build/Debug/${workspaceFolderBasename}.elf verify reset exit"
            ],
            "dependsOn": "CMake: Build (Debug)",
            "group": "build",
            "presentation": { "reveal": "always", "panel": "shared" },
            "problemMatcher": []
        },
        {
            "label": "Build + Flash",
            "dependsOn": ["CMake: Build (Debug)", "OpenOCD: Flash"],
            "dependsOrder": "sequence",
            "group": "build",
            "presentation": { "reveal": "always", "panel": "shared" },
            "problemMatcher": []
        }
    ]
}
```

用 `${env:LOCALAPPDATA}` 而不是写死 `C:/Users/你的名字`，换电脑/换用户名就不用改。

### 5.6 openocd.cfg —— 只有走 OpenOCD 路线才需要

```tcl
add_script_search_dir "D:/OpenOCD/share/openocd/scripts"
source [find interface/stlink.cfg]
source [find target/stm32f1x.cfg]
reset_config none
```

第一行**一定要有**。它告诉 OpenOCD 去哪找自己的脚本；不写的话，能不能找到取决于你从哪个目录启动它，时好时坏。

### 5.7 改用 Release 模式

默认推荐 Debug（能打断点）。如果想用 Release（体积小、跑得快），**四个地方必须一起改**：

| 文件 | 改成 |
| --- | --- |
| `.vscode/settings.json` | `"cmake.configurePreset": "Release"`、`"cmake.buildPreset": "Release"` |
| `.vscode/c_cpp_properties.json` | `build/Release/compile_commands.json` |
| `.clangd` | `CompilationDatabase: build/Release` |
| `.vscode/tasks.json` | 所有 `build/Debug` 换成 `build/Release` |

⚠️ **Release 默认是 `-Os -g0`**。`-g0` 表示不生成调试信息，**断点和看变量都会失效**。以后想调试，要么改回 Debug，要么把 `cmake/gcc-arm-none-eabi.cmake` 里的 `-g0` 改成 `-g3`——那样既享受优化，又保留调试信息。

### 5.8 自动收集源文件（不用每次改 CMakeLists）

默认情况下每加一个 `.c` 都要去 `CMakeLists.txt` 登记，很烦。用 CMake 的 `GLOB` 可以自动化。

把 `CMakeLists.txt` 里原来的：

```cmake
target_sources(${CMAKE_PROJECT_NAME} PRIVATE
    # Add user sources here
)
```

换成：

```cmake
# ---- 自动收集用户源文件 ----
# CubeMX 已经登记过的文件必须排除，否则会重复编译、报符号冲突
set(MX_MANAGED_SRC
    main.c
    stm32f1xx_it.c
    stm32f1xx_hal_msp.c
    sysmem.c
    syscalls.c
    system_stm32f1xx.c
)

# CONFIGURE_DEPENDS：每次构建都检查目录变化，新增 .c 自动生效
file(GLOB USER_SRC_FILES CONFIGURE_DEPENDS
    "${CMAKE_SOURCE_DIR}/Core/Src/*.c"
)

foreach(_src ${USER_SRC_FILES})
    get_filename_component(_name "${_src}" NAME)
    if(NOT _name IN_LIST MX_MANAGED_SRC)
        list(APPEND USER_SOURCES "${_src}")
    endif()
endforeach()

target_sources(${CMAKE_PROJECT_NAME} PRIVATE ${USER_SOURCES})
```

之后：

- 新写的 `.c` 丢进 `Core/Src/`，**直接编译就生效**，不用改任何配置
- `.h` 放进 `Core/Inc/` 就能被 include，**头文件本来就不需要登记**
- 排除清单里的 6 个文件名，就是 CubeMX 在 `cmake/stm32cubemx/CMakeLists.txt` 里已经登记过的那些

> 为什么要排除？因为 CubeMX 生成的 `cmake/stm32cubemx/CMakeLists.txt` 里已经显式列了 `main.c`、`stm32f1xx_it.c` 等 6 个文件。如果 GLOB 把它们也收进来，同一个文件会被编译两次，链接时报**重复符号**。

---

## 6. 第三步：日常开发循环

配好之后，日常就是这样：

```
1. 改需求
   ├─ 改引脚/外设 → 打开 .ioc → CubeMX 改 → GENERATE CODE
   └─ 只改逻辑   → 直接编辑 Core/Src/*.c

2. 编译
   └─ VS Code 底部状态栏点 Build，或 Ctrl+Shift+B

3. 烧录
   └─ 跑 "Build + Flash" 任务（编译 + 烧录一条龙）

4. 调试
   └─ 按 F5 → 自动编译 → 下载 → 停在 main

5. 加新的 .c 文件
   └─ ⚠️ 必须手动登记到 CMakeLists.txt（见下）
```

### 加新源文件的操作

**用了 [5.8 自动收集方案](#58-自动收集源文件不用每次改-cmakelists)的话**：把 `.c` 丢进 `Core/Src/` 就行，什么都不用改，直接编译。

**没用的话**，要手工登记：

```cmake
target_sources(${CMAKE_PROJECT_NAME} PRIVATE
    Core/Src/bsp_key.c          # ← 加这行
)
```

**不加就编译不进去**，会报「undefined reference to `xxx`」。改完 `CMakeLists.txt` 要重新 configure 一次。

---

## 7. 常见坑与排查

### 7.1 满屏红波浪线 / 补全跳错地方

**症状**：代码明明能编译通过，编辑器里却到处标红；或者 Ctrl+点击跳到错误的位置。

**原因**：clangd 的「代码地图」和实际构建目录不一致。

**检查三处是否指向同一个目录**：

| 文件 | 该写什么 |
| --- | --- |
| `.vscode/settings.json` | `"cmake.configurePreset": "Debug"` |
| `.vscode/c_cpp_properties.json` | `build/Debug/compile_commands.json` |
| `.clangd` | `build/Debug` |

**修复**：统一成 `Debug` → 重新构建一次 → 命令面板跑 `clangd: Restart language server`。

### 7.2 自己写的 .c 文件编译不进去

**症状**：`undefined reference to '你的函数名'`

**原因**：没登记到 `CMakeLists.txt` 的 `target_sources`。

**修复**：手工加一行，或者用 [5.8 的自动收集方案](#58-自动收集源文件不用每次改-cmakelists)一劳永逸。

### 7.3 调试器启动不了

**症状**：按 F5 报错，说找不到 `gdb-multiarch` 或类似。

**原因**：手写的调试配置里 `miDebuggerPath` 指向了一个系统里没有的 GDB。

**修复**：**直接用 ST 扩展的原生调试配置**（[5.4](#54-launchjson--调试配置推荐-st-官方路线)），它用扩展自带的 `gnu-gdb-for-stm32`，不存在找不到的问题。

如果你非要走手写 OpenOCD 路线，GDB 路径应该指向：

```
%LOCALAPPDATA%\stm32cube\bundles\gnu-gdb-for-stm32\14.3.1+st.2\bin\arm-none-eabi-gdb.exe
```

### 7.4 换了电脑 / 挪了工程位置就失效

**症状**：配置里写死的绝对路径（`d:\.Project-FJUT\...`）全部失效。

**修复**：用变量代替写死的路径：

| 写死的 | 换成 |
| --- | --- |
| `C:/Users/tea/AppData/Local/...` | `${env:LOCALAPPDATA}/...` |
| `d:\.Project-FJUT\MCU\xxx\build\Debug\xxx.elf` | `${workspaceFolder}/build/Debug/...` |
| 具体的 `.elf` 文件名 | `${workspaceFolderBasename}.elf` |

### 7.5 OpenOCD 报找不到脚本

**症状**：`Can't find interface/stlink.cfg`

**修复**：`openocd.cfg` 第一行加绝对路径：

```tcl
add_script_search_dir "D:/OpenOCD/share/openocd/scripts"
```

### 7.6 烧录一次之后再也连不上

**原因**：CubeMX 里 `SYS → Debug` 没选 `Serial Wire`，芯片把调试口当成了普通 GPIO。

**修复**：CubeMX 里选上，重新生成。已经锁死的话，把 BOOT0 拉高进 bootloader 模式再烧。

### 7.7 扩展升级后突然不能用了

**原因**：`settings.json` 里 `--query-driver` 的版本号（`14.3.1+st.2`）和实际 bundle 目录对不上了。

**修复**：去 `%LOCALAPPDATA%\stm32cube\bundles\gnu-tools-for-stm32\` 看实际版本号，改 `settings.json`。

### 7.8 编译报错但看不到具体信息

**修复**：看 `build/Debug/` 下的 `.map` 文件（内存占用），或者直接看终端里 Ninja 的原始输出。`--print-memory-usage` 会打印 Flash/RAM 占用百分比。

---

## 8. 速查表

### 关键路径（Windows）

| 内容 | 路径 |
| --- | --- |
| ST 扩展管理的工具链 | `%LOCALAPPDATA%\stm32cube\bundles\` |
| VS Code 扩展安装目录 | `%USERPROFILE%\.vscode\extensions\` |
| VS Code 全局设置 | `%APPDATA%\Code\User\settings.json` |
| CubeMX 固件包 | `%USERPROFILE%\STM32Cube\` |

### bundle 里有什么

| 目录 | 作用 |
| --- | --- |
| `cmake` | 构建系统 |
| `ninja` | 构建执行器 |
| `gnu-tools-for-stm32` | 编译器（gcc/g++/objcopy/size） |
| `gnu-gdb-for-stm32` | 调试器（gdb） |
| `st-arm-clangd` | 代码补全 |
| `stlink-gdbserver` | ST-Link 调试服务器 |
| `stlink-server` | ST-Link 服务 |
| `programmer` | CubeProgrammer CLI（命令行烧录） |
| `cortex-svd` | 寄存器查看 |
| `rtos-proxy` | RTOS 感知调试 |

### 常用快捷键

| 操作 | 快捷键 |
| --- | --- |
| 编译 | `Ctrl+Shift+B` |
| 调试（自动编译+下载） | `F5` |
| 运行任务列表 | `Ctrl+Shift+P` → `Tasks: Run Task` |
| 重启 clangd | `Ctrl+Shift+P` → `clangd: Restart language server` |

### 编译参数在哪改

`cmake/gcc-arm-none-eabi.cmake`：

```cmake
set(TARGET_FLAGS "-mcpu=cortex-m3 ")      # 芯片架构
set(CMAKE_C_FLAGS_DEBUG "-O0 -g3")        # Debug 优化级别
set(CMAKE_C_FLAGS_RELEASE "-Os -g0")      # Release 优化级别
```

### 需要链接额外库

`CMakeLists.txt`：

```cmake
target_link_libraries(${CMAKE_PROJECT_NAME}
    stm32cubemx
    m          # ← 数学库，用到 sin/cos/sqrt 时加
)
```

---

## 附录：国内网络给 git 配代理

如果 `git clone` / `git push` GitHub 报 `Empty reply from server` 或超时，说明需要走代理。

先确认代理端口（Clash Verge 默认混合端口是 `7897`）：

```bash
curl -s -o /dev/null -w "%{http_code}\n" -x http://127.0.0.1:7897 https://github.com
# 返回 200 说明端口对
```

**只对 GitHub 走代理**（推荐，不影响 Gitee、内网仓库）：

```bash
git config --global http.https://github.com.proxy http://127.0.0.1:7897
git config --global http.https://raw.githubusercontent.com.proxy http://127.0.0.1:7897
```

**取消**：

```bash
git config --global --unset http.https://github.com.proxy
git config --global --unset http.https://raw.githubusercontent.com.proxy
```

⚠️ 这个配置**依赖 Clash 一直开着**。Clash 关掉时 git 访问 GitHub 会失败（其他仓库不受影响）。

想让所有仓库都走代理（含 Gitee）：

```bash
git config --global http.proxy http://127.0.0.1:7897
git config --global https.proxy http://127.0.0.1:7897
```

---

## 参考

- [STM32Cube for Visual Studio Code 官方文档](https://www.st.com/en/development-tools/vscode-stm32.html)
- [STM32CubeMX 用户手册 (UM1718)](https://www.st.com/resource/en/user_manual/um1718-stm32cubemx-for-stm32-configuration-and-initialization-c-code-generation-stmicroelectronics.pdf)
- [CMake 官方文档](https://cmake.org/documentation/)

---

## License

MIT
