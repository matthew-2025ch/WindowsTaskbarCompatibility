# WindowsTaskbarCompability

Windows 自动隐藏任务栏兼容工具，默认启用 Codex、Snow Shot 和 oCam，可添加其他软件。

后台工具为目标软件的窗口设置 Windows `NonRudeHWND` 属性，避免整屏窗口压住任务栏的鼠标触边触发区域。不改变窗口大小或录制区域。

### 用途

修复部分窗口覆盖整屏后，Windows 自动隐藏任务栏无法通过鼠标触边唤出的问题。
不改变窗口尺寸、录制区域、分辨率或录制文件，不需要留下底部空隙。

### 原理与限制

这是后台兼容工具，不是对原软件安装文件的补丁。
每 0.5 秒检查这些软件的可见顶层窗口，使用微软文档说明的 NonRudeHWND 窗口属性，
阻止 Windows 将它们作为应压住任务栏的全屏窗口处理，并刷新任务栏状态。
窗口重建后通常在下一次检查时应用。默认处理 ChatGPT、snow_shot、ocam 进程。
可在同文件夹的 apps.txt 中添加其他进程名，每行一个，例如 example.exe；无需修改程序。
大小写不限，.exe 后缀可省略。保存后约 2 秒内生效；删除一行会撤销该软件的兼容标记。
可右击工具托盘图标，选择 Edit application list 打开名单。配置出错时保留上次有效名单。
仅在当前登录账户和会话生效；其他名称的软件版本、管理员身份运行的目标软件仍需单独验证。

真正全屏的视频或其他程序不在处理范围内，但通过这些目标软件自身打开的全屏窗口也会允许任务栏弹出。

不模拟按键、不读取窗口标题、不联网、不修改原软件文件。

## 使用

- 双击 `Start-TaskbarCompatibility.cmd` 启动，重复启动不会产生多个常驻实例。
- 双击 `Stop-TaskbarCompatibility.cmd` 停止并移除工具添加的兼容标记。
- 双击 `Enable-Autostart.cmd` 启用当前账户的登录自动启动。
- 双击 `Remove-TaskbarCompatibility.cmd` 取消自动启动并停止工具。

工具以隐藏的 Windows PowerShell 进程运行，也可通过托盘菜单退出。依赖 Windows PowerShell 5.1、.NET Framework 和 Windows 桌面会话，无需额外下载依赖。

启用自动启动后请保留文件夹路径；再次迁移前先取消自动启动，在新目录重新启用。

## 添加其他软件

编辑同目录的 `apps.txt`，每行填写一个软件的进程名，例如 `example.exe`。可以在任务管理器的“详细信息”中查到进程名，`.exe` 后缀可省略，大小写不限。也可右击工具托盘图标，选择 `Edit application list` 打开名单。

保存后约 2 秒内自动生效，无需重启工具。删除对应行会撤销该软件由工具添加的兼容标记；以 `#` 开头的行是注释。只填写进程名，不填写路径或通配符。名单为空时不处理任何软件。

配置读取失败或格式错误时，会保留之前生效的名单，并在 `runtime/status.json` 的 `configError` 中记录错误；首次启动读取失败时使用默认名单。

适用于同类任务栏层级或全屏判定问题；其他软件需要实际验证。请只添加确实希望鼠标触边时弹出任务栏的软件，名单中的软件即使进入真正全屏也会应用兼容处理。

## 文件

- `TaskbarCompatibility.ps1`：后台兼容工具。
- `Setup-TaskbarCompatibility.ps1`：安装与移除登录启动快捷方式。
- `apps.txt`：支持的软件进程名单，支持自动重新加载。
- `tools/`：初始问题定位所用诊断脚本；日常使用无需运行。
- `runtime/status.json`：本地运行状态，已从 Git 排除。

本工具是兼容措施，并非原软件的官方补丁。新窗口通常在下一次 0.5 秒检查时应用；不同进程名的版本或管理员运行的软件需另外验证。

## 验证

在 Windows 10 上已确认生效：Codex 最大化及切换窗口后可正常触边唤出任务栏；Snow Shot 完整屏幕录制时也正常，无需缩小录制区域。后台工具已通过编译、启动、停止和重新启动检查。

配置测试：`powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File .\tools\test-configuration.ps1`。

后台工具运行时，可在上述命令末尾添加 `-Integration`，使用屏幕外测试窗口验证新增、移除、不重启重新加载和错误配置恢复；测试会临时修改名单，并在结束后恢复。

## 参考

- [微软窗口全屏判定文档](https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nf-shobjidl_core-itaskbarlist2-markfullscreenwindow)
- [Codex 类似问题报告](https://github.com/openai/codex/issues/52877)
