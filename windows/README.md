# 映桥 ScreenBridge · Windows

此目录预留给 Windows 实现，目前尚未开发，没有 Windows 安装包。

计划提供原生系统托盘界面、DDC/CI 硬件亮度、DP1/DP2 直接切换、每屏自定义映射、一键全部切到 DP1 和登录启动。

建议采用 C#、稳定 LTS .NET 与 WPF，使用 Windows Monitor Configuration API 建立原生 DDC 通道。硬件调用不得阻塞界面，需正确处理设备身份、热插拔、休眠恢复、句柄释放与每屏操作队列。

可参考 [macOS 实现](../macos/) 和 [硬件兼容记录](../macos/docs/hardware-compatibility.md)，但其接口数值和连接限制必须在 Windows 上独立验证，不能直接宣称跨平台已实测。

Windows 源码和测试后续放入此目录，安装包通过本仓库 Releases 发布，并注明 Windows 平台和架构。
