# ARMv7 / Pi 2B 验收 —— 简体中文导读

> 语言／Language：[繁體中文](armv7-pi2b-verification.md) ｜ [English](armv7-pi2b-verification.en.md) ｜ **简体中文** ｜ [日本語](armv7-pi2b-verification.ja.md) ｜ [한국어](armv7-pi2b-verification.ko.md) ｜ [Español](armv7-pi2b-verification.es.md)

本文件是 [`armv7-pi2b-verification.md`](armv7-pi2b-verification.md) 里**实机原始日志**的中文导读。
原始日志才是证据，且逐字保留——安装脚本本身就是中文输出，改写它会破坏其记录价值。以下内容为说明与
对照翻译；两者若有出入，以原始日志为准。

- 目标板：Raspberry Pi 2 Model B（armv7l，921 MiB RAM），Raspbian GNU/Linux 13 (trixie)
- 轮次：2026-09-23，安装 `@earendil-works/pi-coding-agent@0.87.1`
- 命令：`scripts/pi2-armv7/pi2-pi-agent.sh all`（probe → install → verify），由 PC 通过 SSH 驱动
- 结果：**验收 11/11 通过**，`verify` exit 0

## 日志各区段是什么

| 日志区段 | 内容 |
| --- | --- |
| `=== 0) 基本環境` | 环境：`uname -m = armv7l`、Raspbian 13 (trixie)、921 MiB 总量 / 640 MiB 可用、`$HOME` 剩 6.2 GB。接着三道关卡通过：架构是 armv7l；以一般用户（uid 1000）执行且只装到 `$HOME`；有下载工具（`curl`）。 |
| `=== 1) Node 22 armv7l` | 已有 Node v22.23.2（`/home/<user>/opt/node22/bin/node`，官方 armv7l 构建线），且 `node:sqlite` 可用 → session backend 不需要原生模块。 |
| `=== 2) 安裝 pi coding agent` | 用 npm 10.9.8 把官方包装进 `/home/<user>/.local`：`changed 119 packages in 3m`。出现一条 `node-domexception@1.0.0` 弃用警告，属上游依赖、无害。 |
| `=== 3) 驗收（可量測的項目）` | 执行文件存在且 **`pi --version` 输出 0.87.1**；`pi --help` 正常。列出包内 6 个 prebuild，全为 x64/arm64（darwin/linux/win32）—— **没有 `linux-arm`**，所以在这块板子上永远不会加载任何原生件；真正有说服力的是上面那句 `pi --version` 成功输出。 |
| `=== 4) 量測（給日後比對用）` | 供日后比对的量测：`pi --version` 4.92 s、`node` 基准 RSS 40 MiB、Node 187 MB、pi 包 156 MB。 |
| `=== 5) 接下來（可選）` | 如何把 PATH 写进 `~/.bashrc` 持久化，以及如何跑一次真实模型回合（需要密钥，或同一网段上的 LM Studio 之类 OpenAI 兼容端点）。 |
| `完成。記錄檔請用 --check-only 重跑輸出存證。` | 安装运行的收尾行（「完成。要留证请用 `--check-only` 重跑并保存输出」）。 |

## 验收项（`pi2-pi-agent.sh verify`）对照

验收器对日志做模式匹配，任一不符即 fail-closed（`✓` = 必须出现，`✗` = 必须不出现）：

| 结果 | 日志标记 | 含义 |
| --- | --- | --- |
| ✓ | `架構是 armv7l` | 跑在 armv7l（Pi 2B）上 |
| ✓ | `以一般使用者執行` | 以一般用户执行，非 root |
| ✓ | `Node v22\.` | Node 在 v22 线 |
| ✓ | `node:sqlite 可用` | 内建 SQLite session backend 可用 |
| ✓ | `pi 執行檔存在` | `pi` 执行文件存在 |
| ✓ | `pi --version → v?\d` | `pi --version` 有输出 |
| ✗ | `prebuilds/linux-arm/` | 没有出现 armv7 专属 prebuild |
| ✗ | `以 root 身分執行中` | 没有以 root 执行 |
| ✗ | `Node v(?!22\.)\d` | 日志中没有任何非 v22 的 Node 痕迹 |
| ✗ | `意外發現原生 .node` | 没有意外出现原生 `.node` |
| ✗ | `中止（fail-closed）` | 没有任何步骤中止 |

## 独立重测（同一块板，0.87.1）

安装后又跑了三次 `pi --version`，以及当时的板子状态：

```text
  run1: 4.75 s (0.87.1)
  run2: 4.83 s (0.87.1)
  run3: 4.81 s (0.87.1)
  node RSS: 40 MiB
  free: 655 MiB available
  disk HOME: 6.2G
```

## 其他板上证据（同为实测，记录在别处）

- 已安装的加载器在这块板子上拒绝提供原生 helper——用 0.87.1 包实测：`process.arch = arm`，
  `getNativeClipboard()` 与 `getNativePlatformHelper()` 都返回 `undefined`，也就是文件里写的命令行 fallback。
- 源码构建关卡行为与文件描述一致：upstream 的 `packages/tui/native/linux/build.sh` 在 armv7l 上退出
  **1**（`Unsupported Linux architecture: armv7l`），本 fork 版本打印跳过说明并退出 **0**。
  在板上**从源码整包构建**仍未验证。

完整手册见 [`armv7-pi2b.zh-CN.md`](armv7-pi2b.zh-CN.md)，繁体原版见 [`armv7-pi2b.md`](armv7-pi2b.md)。
