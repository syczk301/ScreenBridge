# 映桥 ScreenBridge · macOS

轻量的 macOS 菜单栏显示器工具：硬件亮度、DP 输入源切换，以及一键将外接显示器切到 DP1。

基于 [didriksg/Crisp](https://github.com/didriksg/Crisp) 1.7.1 修改，保留 MIT 许可证与原作者署名。本项目是独立衍生版本，不是 Crisp 或 BetterDisplay 的官方发行版，未使用 BetterDisplay 的未公开源码。

## 下载与安装

从 [Releases](https://github.com/syczk301/ScreenBridge/releases/latest) 下载 DMG，将 **映桥.app** 拖入 **Applications / 应用程序**。

- 当前版本：**1.1.16**。
- 预编译版本：Apple Silicon（arm64），macOS 14 及以上。
- 使用 ad-hoc 签名，未经过 Apple Developer ID 签名和公证，系统可能拦截首次启动。确认来源后可按 macOS 提示在“隐私与安全性”中允许打开，或从源码构建。
- 应用设置中可开启登录后自动启动。

## 功能

- **硬件亮度**：通过 DDC/CI 调整硬件亮度，采用硬件 0–100% 标尺，禁用软件调暗。
- **输入源切换**：界面只显示 DP1、DP2，点击即发送，无需先读取或记录当前接口。
- **自定义接口数值**：支持每屏十进制或十六进制配置，具名 `DP1` / `DP2` 自定义值优先。
- **全部切到 DP1**：根据当前物理外接显示器及各自映射分别发送命令，某台失败不阻止其他目标。
- **显示设置**：分辨率、刷新率、颜色配置和排列显示器等功能；识别可变刷新率模式。
- **托盘与启动**：双显示器菜单栏图标、后台运行、登录启动设置。

“命令已发送”仅表示传输成功，不保证实际切换。读回编号和写入编号可能不同；切换到其他设备后，部分显示器不再响应原接口的 DDC。详见 [硬件兼容记录](docs/hardware-compatibility.md)。

## 构建与测试

需要 macOS、Apple Command Line Tools 和支持 Swift 6 的工具链。提供独立命令行构建，不依赖完整 Xcode 工程或 Sparkle 下载。

```sh
xcode-select --install
cd macos
bash build-local.sh
open build/映桥.app
```

脚本按当前机器架构编译，输出 `build/映桥.app`。已验证发行架构为 arm64，Intel 构建和硬件行为未验证。

```sh
cd macos # 从仓库根目录开始
bash local-tools/check.sh
```

检查覆盖输入解析、自定义配置、型号映射、批量发送、硬件亮度换算、禁止软件调暗和 MST 报文校验。模拟测试不操作真实显示器，不能代替硬件验证。

## CLI

```sh
"/Applications/映桥.app/Contents/MacOS/crispctl" display list --json
"/Applications/映桥.app/Contents/MacOS/crispctl" display input list <显示器UUID> --json
"/Applications/映桥.app/Contents/MacOS/crispctl" display input set <显示器UUID> dp1 --json
```

`dp1` / `dp2` 使用型号映射；显式数字按原值发送，例如 `18` 不会再次转换。

## 目录

- `Crisp/`：应用、服务、模型和界面，沿用上游目录名称。
- `Sources/crispctl/`：本地控制 CLI。
- `local-tools/`：构建辅助与独立测试。
- `local-assets/`：映桥图标资源。
- `CrispTests/`：保留的上游测试；`check.sh` 不表示运行了全部上游 XCTest。

## 限制

- DDC/CI 支持取决于显示器固件、线材和连接路径。
- HP G2 MST 实现仅针对已核验设备与拓扑，不是通用 MST 支持。
- JU27F160L 的 DP2 写入值未验证，仍保留标准候选值 16。
- 部分显示控制依赖 macOS 私有接口，系统更新可能影响兼容性。
- 此目录包含 macOS 实现；Windows 状态见仓库根目录说明。

## 来源与许可

MIT License，详见 [LICENSE](LICENSE)、[ACKNOWLEDGMENTS.md](ACKNOWLEDGMENTS.md)、[UPSTREAM.txt](UPSTREAM.txt)。`UPSTREAM-README.md` 是上游历史说明，其中的产品承诺不代表本发行版的验证范围。
