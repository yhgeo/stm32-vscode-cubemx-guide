# 模板说明

这些文件是“复制到实际 CubeMX 工程”的片段，不是可独立编译的 STM32 工程。

| 文件 | 目标位置 | 备注 |
| --- | --- | --- |
| `settings.json` | `.vscode/settings.json` | Debug preset 示例；不含版本号和本机路径 |
| `dot-clangd` | 根目录并改名为 `.clangd` | 指向 `build/Debug` 的编译数据库 |
| `c_cpp_properties.json` | `.vscode/c_cpp_properties.json` | 仅在使用 cpptools 时复制 |
| `launch.json` | `.vscode/launch.json` | ST-Link 原生调试；也可让扩展自动生成 |
| `tasks.json` | `.vscode/tasks.json` | OpenOCD 外部路线；要求 `cmake`、`openocd` 在 PATH |
| `openocd.cfg` | 根目录 | OpenOCD 外部路线 |
| `CMakeLists-auto-sources.cmake` | 粘贴进根目录 `CMakeLists.txt` | 自动收集 `Core/Src/*.c` |

切换到 Release 时，把 `settings.json`、`.clangd`、`c_cpp_properties.json` 和任务中的 `Debug` 一起改为 `Release`，并重新 Configure。

