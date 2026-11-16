# 映桥 ScreenBridge · macOS

轻量的 macOS 菜单栏显示器工具：硬件亮度、DP 输入源切换，以及按实际接线批量切换和返回。

基于 [didriksg/Crisp](https://github.com/didriksg/Crisp) 1.7.1 修改，保留 MIT 许可证与原作者署名。本项目是独立衍生版本，不是 Crisp 或 BetterDisplay 的官方发行版，未使用 BetterDisplay 的未公开源码。

## 下载与安装

从 [Releases](https://github.com/syczk301/ScreenBridge/releases/latest) 下载 DMG，将 **映桥.app** 拖入 **Applications / 应用程序**。

- 当前版本：**1.3.3**。
- 预编译版本：Apple Silicon（arm64），macOS 14 及以上。
- 使用 ad-hoc 签名，未经过 Apple Developer ID 签名和公证，系统可能拦截首次启动。确认来源后可按 macOS 提示在“隐私与安全性”中允许打开，或从源码构建。
- 应用设置中可开启登录后自动启动。

## 功能

- **硬件亮度**：通过 DDC/CI 调整硬件亮度，采用硬件 0–100% 标尺，禁用软件调暗。
- **输入源切换**：按每屏配置提供“切到目标”和“返回本机”，点击直接发送，无需先读取当前输入。
- **自定义接口数值**：支持每屏十进制或十六进制配置，具名 `DP1` / `DP2` 自定义值优先。
- **批量切换与返回**：按当前外接屏各自的接线配置切换；未配置屏幕跳过并提示，某台失败不阻止其他目标。
- **显示设置**：分辨率、刷新率、颜色配置和排列显示器等功能；识别可变刷新率模式。
- **托盘与启动**：双显示器菜单栏图标、后台运行、登录启动设置。

“命令已发送”仅表示传输成功，不保证实际切换。读回编号和写入编号可能不同；切换到其他设备后，部分显示器不再响应原接口的 DDC。详见 [硬件兼容记录](docs/hardware-compatibility.md)。

## 按实际接线配置

展开显示器的“输入源”→“接线设置…”，填写显示器一端连接这台 Mac 的**本机接口**，以及另一台设备的**切换目标**。两者分别保存名称与最终 DDC 写入值。可选 DP1、DP2、HDMI1、HDMI2、USB-C 或自定义，选择时按型号映射预填，未验证值仍需核对。

例如 JU24 的 Mac 接 DP2、另一设备接 DP1：本机 DP2 写入 15，目标 DP1 写入 18。换线后需更新配置，不能把此示例自动套用到所有设备。

首次打开未配置显示器的接线窗口时自动读取当前输入；已验证型号会按读回→写入映射预填本机接口，必须确认显示器当前显示此 Mac 的画面后才能保存。JU27 DP2、未知型号和未知读回值不猜测，读取失败可手动填写。目标接口仍由用户指定。已有配置不自动覆盖，读取期间的手动编辑也不会被迟到结果覆盖；主动“使用检测结果”才替换本机草稿。保存或清除配置不会切屏。已有自定义输入列表保持可用，接线设置保存的是具体数值快照，之后修改列表不会静默改动接线目标；需重新选择并保存。

尚未配置时不会猜测本机为 DP2、目标为 DP1。只对当前可枚举的显示器发送命令；若切走后通道消失或显示器拒绝非当前输入上的 DDC，“返回本机”仍可能失败，需要实体菜单返回。

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

## 输出色彩模式

展开每屏的“色彩模式”，可选择当前连接实际支持的位深、RGB/YCbCr、全范围/有限范围和 SDR/HDR 组合。数据来自 CADisplay 的输出模式，不使用 CG 帧缓冲深度、ICC 配置或 DDC 色温预设代替。仅提供与当前物理分辨率、刷新率和 VRR 状态匹配的模式；需要其他刷新率的格式仅提示数量。

点击后以系统读回为准更新选中项，15 秒内选择“保留”，否则请求恢复原模式；关闭菜单也会继续倒计时。切换可能短暂黑屏。此版本不提供跨分辨率的配置锁定。使用运行时检查的 macOS 私有 API，不支持的连接显示不可用，不显示虚构模式。

实测：JU24 在 3840×2160、160 Hz、1920×1080 HiDPI 下从 10-bit RGB 全范围切至 8-bit，再恢复 10-bit；系统读回通过，分辨率与刷新率未变；正式服务的 15 秒自动恢复亦已实测通过。其他格式和 HDR 的画面表现尚未逐项实测。

接线设置仅自动预填经过实测的写入值。未验证的 HDMI/DP 接口留空；读回值不直接作为写入值。同值往返配置即时提示并禁止保存。JU27 当前 HDMI2 读回 18，经使用者确认物理接线；Windows 当前接法已由用户截图确认 HDMI2 写入 17、读回 18（2026-11-15）。17 可作为 macOS 的待验证候选值，不能把 Windows 验证视为 macOS 验证，也不能以读回 18 替代。
