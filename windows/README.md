# 映桥 ScreenBridge · Windows

当前目录包含 Windows 开发规格和接续提示，尚无 Windows 实现、工程文件或安装包。

## 从 Windows 接着开发

1. 克隆 `https://github.com/syczk301/ScreenBridge.git`，或在已有克隆中保留修改并更新。
2. 阅读 [完整开发说明](DEVELOPMENT.md)：功能、技术方案、接口映射、实现顺序、验收与打包要求。
3. 将 [接续提示](CONTINUE-PROMPT.md) 中的文本复制到开发助手，工作目录设为仓库根目录。

目标：Windows 11 x64，C# + .NET 10 LTS + WPF；硬件亮度、DP1/DP2、自定义映射、一键切屏、托盘与登录启动。禁止软件调暗。

[macOS 实测记录](../macos/docs/hardware-compatibility.md) 仅作候选配置依据，Windows 需要独立验证。JU27 DP2 仍未验证，不能直接套用 JU24 配置。

源码后续放在此目录，安装包发布到同一仓库的 Releases，并标明 Windows 平台及架构。
