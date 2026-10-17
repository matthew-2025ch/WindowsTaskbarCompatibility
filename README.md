# WindowsTaskbarCompability

Windows 自动隐藏任务栏兼容工具，适用于 Codex、Snow Shot 和 oCam。

后台工具为目标软件的窗口设置 Windows `NonRudeHWND` 属性，避免整屏窗口压住任务栏的鼠标触边触发区域。不改变窗口大小或录制区域。

## 使用

- 双击 `Start-TaskbarCompatibility.cmd` 启动，重复启动不会产生多个常驻实例。
- 双击 `Stop-TaskbarCompatibility.cmd` 停止并移除工具添加的兼容标记。
- 双击 `Enable-Autostart.cmd` 启用当前账户的登录自动启动。
- 双击 `Remove-TaskbarCompatibility.cmd` 取消自动启动并停止工具。

工具以隐藏的 Windows PowerShell 进程运行，也可通过托盘菜单退出。依赖 Windows PowerShell 5.1、.NET Framework 和 Windows 桌面会话，无需额外下载依赖。

启用自动启动后请保留文件夹路径；再次迁移前先取消自动启动，在新目录重新启用。

## 文件

- `TaskbarCompatibility.ps1`：后台兼容工具。
- `Setup-TaskbarCompatibility.ps1`：安装与移除登录启动快捷方式。
- `使用说明.txt`：原理、限制与已验证的使用场景。
- `tools/`：初始问题定位所用诊断脚本；日常使用无需运行。
- `runtime/status.json`：本地运行状态，已从 Git 排除。

本工具是兼容措施，并非原软件的官方补丁。新窗口通常在下一次 0.5 秒检查时应用；不同进程名的版本或管理员运行的软件需另外验证。

## 验证

在 Windows 10 上已由用户确认：Codex 最大化及切换窗口后可正常触边唤出任务栏；Snow Shot 完整屏幕录制时也正常，无需缩小录制区域。后台工具已通过编译、启动、停止和重新启动检查。

## 参考

- [微软窗口全屏判定文档](https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nf-shobjidl_core-itaskbarlist2-markfullscreenwindow)
- [Codex 类似问题报告](https://github.com/openai/codex/issues/52877)