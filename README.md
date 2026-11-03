# 映桥 ScreenBridge

跨平台的轻量显示器控制工具，提供硬件亮度、输入源切换和一键切屏。macOS 与 Windows 实现在同一个仓库维护。

## 平台状态

| 平台 | 状态 | 源码与说明 |
|---|---|---|
| macOS | 已发布 1.1.16，Apple Silicon，macOS 14+ | [macos/](macos/) |
| Windows | 待开发，尚无可用安装包 | [windows/](windows/) |

## 下载

[前往 Releases](https://github.com/syczk301/ScreenBridge/releases)。当前可下载 macOS DMG；Windows 版本完成后也将在此仓库发布，附件将标明平台与架构。

macOS：打开 DMG，将映桥.app 拖入应用程序。当前包使用 ad-hoc 签名，未经过 Developer ID 签名和公证，详见 [macOS 安装说明](macos/README.md)。

## 核心功能与原则

- 使用硬件亮度控制，禁用软件调暗。
- DP1 / DP2 点击直接发送，支持每台显示器自定义数值。
- 一键将外接显示器切换到 DP1，按各自型号选择命令。
- 区分“命令已发送”和“实际切换成功”，不根据通信 ACK 宣称切换完成。
- 分开处理输入源写入值和读回值；不把某型号配置泛化到所有显示器。

以上功能已在 macOS 实现；Windows 计划遵循相同原则，具体支持情况以各平台说明为准。

## 开发

```text
macos/     Swift / SwiftUI 应用、CLI、构建脚本与测试
windows/   Windows 实现预留目录，目前只有开发说明
```

macOS 构建：

```sh
cd macos
bash build-local.sh
```

测试：在 `macos/` 目录执行 `bash local-tools/check.sh`。硬件实测与限制见 [兼容记录](macos/docs/hardware-compatibility.md)。这些记录来自 macOS，Windows 必须独立验证。

## 来源与许可

macOS 版本基于 [didriksg/Crisp](https://github.com/didriksg/Crisp) 1.7.1，保留 MIT 许可与原作者署名。本项目不是 Crisp 或 BetterDisplay 官方发行版，未使用 BetterDisplay 未公开源码。

详见 [LICENSE](LICENSE)、[macOS 致谢](macos/ACKNOWLEDGMENTS.md) 和 [上游来源](macos/UPSTREAM.txt)。
