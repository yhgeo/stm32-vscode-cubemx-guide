# 模板文件对照表

把这里的文件复制到你的 CubeMX 工程里，**注意目标位置和文件名**。

| 本目录文件 | 复制到工程的 | 要改的地方 |
| --- | --- | --- |
| `settings.json` | `.vscode/settings.json` | `--query-driver` 里的工具链版本号 |
| `c_cpp_properties.json` | `.vscode/c_cpp_properties.json` | 构建目录要和 preset 一致（默认 Debug） |
| `dot-clangd` | 工程根目录，**改名为 `.clangd`** | 同上 |
| `launch.json` | `.vscode/launch.json` | 一般不用改 |
| `tasks.json` | `.vscode/tasks.json` | CMake / 工具链版本号、OpenOCD 路径 |
| `openocd.cfg` | 工程根目录 `openocd.cfg` | OpenOCD 脚本目录的绝对路径 |
| `CMakeLists-auto-sources.cmake` | **粘贴**进工程根目录的 `CMakeLists.txt` | 无（替换掉原来的 `target_sources` 段） |

## 三个必须一致的路径

补全失效最常见的原因，就是下面这三处指向了不同的构建目录：

| 文件 | 内容 | 说明 |
| --- | --- | --- |
| `.vscode/settings.json` | `"cmake.configurePreset": "Debug"` | 构建用哪个 preset |
| `.vscode/c_cpp_properties.json` | `build/Debug/compile_commands.json` | 代码地图在哪 |
| `.clangd` | `CompilationDatabase: build/Debug` | 代码地图在哪 |

**统一用 `Debug`。** 学习阶段不需要 Release。

## 版本号怎么查

`settings.json` 和 `tasks.json` 里的 `14.3.1+st.2`、`4.3.1+st.1`、`1.13.2+st.1` 是写死的版本号。扩展升级工具链后会变，去这里看实际值：

```
%LOCALAPPDATA%\stm32cube\bundles\gnu-tools-for-stm32\
%LOCALAPPDATA%\stm32cube\bundles\cmake\
%LOCALAPPDATA%\stm32cube\bundles\ninja\
```

把目录名（如 `14.3.1+st.2`）填回配置文件即可。
