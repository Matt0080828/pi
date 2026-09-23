# 在 Raspberry Pi 2 Model B（ARMv7）上运行 pi

> 语言／Language：[繁體中文](armv7-pi2b.md) ｜ [English](armv7-pi2b.en.md) ｜ **简体中文** ｜ [日本語](armv7-pi2b.ja.md) ｜ [한국어](armv7-pi2b.ko.md) ｜ [Español](armv7-pi2b.es.md)

**结论：可以运行，已在实体 Pi2B 上量测通过（11/11）。** 不需要修改 agent 的任何代码——
用**官方 npm 包**安装即可；本分支另外补了两处小改动，让「从源码构建」与「未来的 armv7 原生 helper」
不被架构卡住（见下方「本分支的修改」）。

- 目标板：Raspberry Pi 2 Model B（armv7l, 4×900 MHz, 921 MiB RAM），Raspbian GNU/Linux 13 (trixie)
- 实测日期：**2026-09-23（`@earendil-works/pi-coding-agent@0.87.1`）**｜上一轮 2026-09-22 为 0.87.0
- 原始记录：[`armv7-pi2b-verification.md`](armv7-pi2b-verification.md)（[简体中文导读](armv7-pi2b-verification.zh-CN.md)）
- 证据是**实机量测**，不是静态推论：验收 11/11 通过

---

## 1. 三个决定性事实

| 事实 | 证据 |
| --- | --- |
| **Node 22 有官方 armv7l 构建，Node 23+ 没有** | `nodejs.org/dist/index.json`：v22 全部 **35/35** 版含 `linux-armv7l`（含 ≥ 22.19 的 11 版，最新 v22.23.2）；最近 12 个版本（v23+）皆无。本 repo 要求 `engines.node >= 22.19.0` → **只能在 v22 线满足** |
| **官方预编译二进制不含 armv7** | release 资产只有 `linux-x64`／`linux-arm64`／`darwin-x64|arm64`／`windows-x64|arm64`，`build-binaries.yml` 的平台判断同样只列这四个 → 官方 tarball **不可用** |
| **npm 包路线没有原生障碍** | `@earendil-works/pi-coding-agent@0.87.1`：无 `os`/`cpu` 限制、已含预打包 CLI（`dist/bundle/*.js`）、依赖为纯 JS 或 wasm（`photon-node` 内含 `photon_rs_bg.wasm`）、`canvas` 只在 `devDependencies`、session backend 用 Node 内建 `node:sqlite` |

唯一的功能减损：TUI 的原生 X11／剪贴板 helper（`linux-platform-x11.node`）只有 x64/arm64 预编译，
且加载器 `packages/tui/src/native-platform.ts` 对其他架构直接返回 `undefined`。
`packages/tui/native/linux/README.md` 自己写明「Coding-agent falls back to command-line tools when
native reads are unavailable」——所以在 armv7 上这是**设计允许的降级**，不会崩溃，只是少了剪贴板／图片集成。

在板上用已安装的 0.87.1 实测：

```text
process.arch = arm, process.platform = linux
getNativeClipboard()      -> undefined
getNativePlatformHelper() -> undefined
```

## 2. 实机量测结果

| 检查 | 实测值 |
| --- | --- |
| 架构 | `armv7l`（Raspbian 13 trixie） |
| 身份 | uid 1000，**全程未用 sudo**（安装到 `$HOME`） |
| Node | **v22.23.2**（官方 `linux-armv7l` tarball，26,338,176 bytes） |
| `node:sqlite` | **可用** → session backend 不需要原生模块 |
| CLI | **`pi --version` → 0.87.1**；`pi --help` 正常输出 |
| npm 安装 | `changed 119 packages in 3m`（npm 10.9.8） |
| 附带 prebuild | 只有 `darwin-arm64|x64`、`linux-arm64|x64`、`win32-arm64|x64` —— **没有 `linux-arm`（armv7）** |
| 启动耗时 | `pi --version` **4.75–4.92 s**（Pi2B 冷启动，4 次量测） |
| 内存 | `node` 基准 RSS **40 MiB**；安装时整机可用 640 MiB，未 OOM |
| 磁盘 | Node 187 MB ＋ pi 包 156 MB（`$HOME` 尚有 6.2 GB） |

> 已知限制：**CLI 本身已验证**，但一次「真实模型回合」需要 API 密钥或指向本机 OpenAI 兼容端点
> （例如同网段的 LM Studio），本分支的验收没有涵盖该项。

## 3. 安装与使用

在 Pi2B 上（**不需要 sudo**，全部装到 `$HOME`）：

```sh
# 1) Node 22 armv7l（官方 tarball；不要用 NodeSource 或 v23+）
curl -fsSLO https://nodejs.org/dist/v22.23.2/node-v22.23.2-linux-armv7l.tar.xz
mkdir -p ~/opt && tar -xJf node-v22.23.2-linux-armv7l.tar.xz -C ~/opt
ln -sfn ~/opt/node-v22.23.2-linux-armv7l ~/opt/node22

# 2) CLI
export PATH="$HOME/opt/node22/bin:$HOME/.local/bin:$PATH"
node -v                      # v22.23.2
npm install -g --prefix ~/.local @earendil-works/pi-coding-agent
pi --version                 # 0.87.1

# 3) 持久化（加进 ~/.bashrc）
echo 'export PATH="$HOME/opt/node22/bin:$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

要从**源码**构建（本 repo 自己）：

```sh
git clone https://github.com/matttest0080-prog/pi.git && cd pi
npm ci && npm run build      # 这一步在 armv7 上需要本分支的 build.sh 修改（见下）
```

> 这条源码构建路径**尚未**在板上端到端验证。板上实际量测的是那个架构关卡本身：upstream 版
> `packages/tui/native/linux/build.sh` 退出 **1**（`Unsupported Linux architecture: armv7l`），
> 本 fork 版退出 **0**（打印跳过的说明）。关卡之后的整包 TypeScript monorepo 构建（921 MiB 内存的板子）
> 仍未测试。

本分支附带三个在实机上测过的脚本（`scripts/pi2-armv7/`）：

```sh
scripts/pi2-armv7/install-pi-on-pi2.sh          # 在 Pi2 上跑：关卡 → 安装 → 验收 → 量测
scripts/pi2-armv7/install-pi-on-pi2.sh --dry-run    # 只打印步骤，不改任何东西
scripts/pi2-armv7/install-pi-on-pi2.sh --check-only # 只检查现状，不安装
scripts/pi2-armv7/pi2-pi-agent.sh probe|install|verify|all   # 从 PC 通过 SSH 驱动
scripts/pi2-armv7/selftest.sh                   # 工具本身的自我测试（含负向路径）
```

它们刻意 **fail-closed**：架构不是 `armv7l`、以 root 运行、Node 不是 v22、出现 armv7 专属 prebuild、
日志里有任何非 v22 的 Node 痕迹、或任何一步失败——都会明确拒绝并以非 0 结束。

## 4. 本分支的修改

**跑 CLI 不需要任何代码修改**（实机结果就是证明）。以下两处只是为了让「在 armv7 上从源码构建」与
「未来真的要有 armv7 原生 helper」不被挡住，属于**可选的使能修改**，都已附原因注释：

| 文件 | 修改 | 为什么 |
| --- | --- | --- |
| `packages/tui/native/linux/build.sh` | 对 `armv7l`／`armv6l` 打印明确说明后 **exit 0**（不编译） | 原本 `case` 只认 `x86_64`／`aarch64`，其他架构直接 `exit 1` → 在 Pi2 上 `npm run build` 会失败。armv7 没有 prebuild、加载器也不会加载它，所以「明确跳过」比「整包构建失败」正确 |
| `packages/tui/src/native-platform.ts` | 加载器的架构检查多接受 `arm` | 让**自行构建**好 armv7 helper 的人真的用得到它；没有 helper 时行为与现在完全相同（`try/catch` 后返回 `undefined`）。注意：npm 包附的是预打包 JS，这个改动只有在**重新构建**后才生效 |

两者都不影响 x64／arm64 行为。

## 5. 恢复原状

```sh
# 只移除 pi 的部分（~/.local 可能与其他工具共用，例如同一块板子上的 hermes）
rm -rf ~/.local/lib/node_modules/@earendil-works ~/.local/bin/pi
rm -rf ~/opt/node22 ~/opt/node-v22.23.2-linux-armv7l
```

## 6. 重现这份验收

```sh
scripts/pi2-armv7/selftest.sh                                   # 工具自我测试（PC 上，不动板子）
scripts/pi2-armv7/pi2-pi-agent.sh all                            # 探测 → 安装 → 验收
scripts/pi2-armv7/pi2-pi-agent.sh verify docs/armv7-pi2b-verification.md
```

## 7. 注意事项与踩到的坑

- **安装过程中抓到两个真 bug，都是被关卡挡下、不是事后发现**：官方 Node tarball 解开的目录名保留了 `v`
  前缀（`node-v22.23.2-linux-armv7l`，我一开始漏了 `v`）；以及我最初写「node_modules 不得有任何 `.node`」
  是错的——包本来就会附其他平台的 prebuild。正确的不变量是「**没有 armv7 专属 prebuild** 且 CLI 能启动」。
- **0.87.1 的包元数据重新查过**：仍无 `os`/`cpu` 限制，`pi-tui` 仍只附 6 个 x64/arm64 prebuild（没有 `linux-arm`）。
- **上游同步不影响 ARMv7 工作**：合并上游 `898ab8040`（v0.87.1）后，9 个 ARMv7 文件逐位元不变，
  合并后的树与上游的差异恰好只有那 9 个文件。
