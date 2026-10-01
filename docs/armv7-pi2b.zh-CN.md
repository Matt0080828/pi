# 在 Raspberry Pi 2 Model B（ARMv7）上运行 pi

> 语言／Language：[繁體中文](armv7-pi2b.md) ｜ [English](armv7-pi2b.en.md) ｜ **简体中文** ｜ [日本語](armv7-pi2b.ja.md) ｜ [한국어](armv7-pi2b.ko.md) ｜ [Español](armv7-pi2b.es.md)

**结论：可以运行，已在实体 Pi2B 上量测通过（11/11）。** 不需要修改 agent 的任何代码——
用**官方 npm 包**安装即可；本分支另外补了两处小改动，让「从源码构建」与「未来的 armv7 原生 helper」
不被架构卡住（见下方「本分支的修改」）。

- 目标板：Raspberry Pi 2 Model B（armv7l, 4×900 MHz, 921 MiB RAM），Raspbian GNU/Linux 13 (trixie)
- 实测日期：**2026-10-01（`@earendil-works/pi-coding-agent@0.99.2`）**｜上一轮 2026-10-01 为 0.99.1
- 原始记录：[`armv7-pi2b-verification.md`](armv7-pi2b-verification.md)（[简体中文导读](armv7-pi2b-verification.zh-CN.md)）
- 证据是**实机量测**，不是静态推论：验收 11/11 通过

---

## 1. 三个决定性事实

| 事实 | 证据 |
| --- | --- |
| **Node 22 有官方 armv7l 构建，Node 23+ 没有** | `nodejs.org/dist/index.json`：v22 全部 **35/35** 版含 `linux-armv7l`（含 ≥ 22.19 的 11 版，最新 v22.23.2）；最近 12 个版本（v23+）皆无。本 repo 要求 `engines.node >= 22.19.0` → **只能在 v22 线满足** |
| **官方预编译二进制不含 armv7** | release 资产只有 `linux-x64`／`linux-arm64`／`darwin-x64|arm64`／`windows-x64|arm64`，`build-binaries.yml` 的平台判断同样只列这四个 → 官方 tarball **不可用** |
| **npm 包路线没有原生障碍** | `@earendil-works/pi-coding-agent@0.99.2`：无 `os`/`cpu` 限制、已含预打包 CLI（`dist/bundle/*.js`）、依赖为纯 JS 或 wasm（`photon-node` 内含 `photon_rs_bg.wasm`）、`canvas` 只在 `devDependencies`、session backend 用 Node 内建 `node:sqlite` |

唯一的功能减损：TUI 的原生 X11／剪贴板 helper（`linux-platform-x11.node`）只有 x64/arm64 预编译，
且加载器 `packages/tui/src/native-platform.ts` 对其他架构直接返回 `undefined`。
`packages/tui/native/linux/README.md` 自己写明「Coding-agent falls back to command-line tools when
native reads are unavailable」——所以在 armv7 上这是**设计允许的降级**，不会崩溃，只是少了剪贴板／图片集成。

在板上用已安装的 0.99.2 实测：

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
| CLI | **`pi --version` → 0.99.2**；`pi --help` 正常输出 |
| npm 安装 | `added 122 packages in 2m`（npm 10.9.8） |
| 附带 prebuild | 只有 `darwin-arm64|x64`、`linux-arm64|x64`、`win32-arm64|x64` —— **没有 `linux-arm`（armv7）** |
| 启动耗时 | `pi --version` **4.80–5.04 s**（Pi2B 冷启动，4 次量测） |
| 内存 | `node` 基准 RSS **39 MiB**；安装时整机可用 734 MiB，未 OOM |
| 磁盘 | Node 187 MB ＋ pi 包 168 MB（`$HOME` 尚有 5.8 GB） |

> 真实模型回合：**已于 2026-10-01 在板子上实机验证**（板子自己跑 `llama-server`，不需要 PC 或
> 外部 API），做法与实测值见第 8 节。0.99.2 的内建本机路径仍是 `LLAMA_BASE_URL` 指向的
> llama.cpp router（不是 LM Studio 的 OpenAI 兼容 API）。

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
pi --version                 # 0.99.2

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
- **0.99.2 的包元数据重新查过**：仍无 `os`/`cpu` 限制，`pi-tui` 仍只附 6 个 x64/arm64 prebuild（没有 `linux-arm`）。
- **上游同步不影响 ARMv7 工作**：合并上游 `005af57d88`（v0.99.2）后，20 个 ARMv7 delta 文件全部逐位元不变
  （本轮上游没有改动其中任何一个，`packages/tui/src/native-platform.ts` 也保留 `arm` 许可）。

## 8. 板子自足的真实模型回合（已实机验证，2026-10-01）

pi 0.99.2 在 Pi 2B 上用**板子自己执行的模型与伺服器**完成了真实回合，不需要 PC、也不需要外部 API：

- **交叉编译 `llama-server`**：板子没有 cmake、PC 没有交叉工具链时，用 `apt-get download` ＋
  `dpkg -x` 把 Ubuntu 的 armhf-cross `.deb` 解到 `$HOME`（免 sudo）；`as` 需要
  `LD_LIBRARY_PATH=<prefix>/usr/lib/x86_64-linux-gnu`，链接要加 `--sysroot=<prefix>` 与
  `-static-libstdc++ -static-libgcc`。实测产物 13.5 MB，板上 `llama-server --version` =
  `0.3.0-dev (build 10734)`。
- **用 router 模式启动**：`llama-server --models-preset <ini>`。必须走 `--models-preset`
  （`source=preset`）；`--models-dir` 会回 `source=models_dir`，被 pi 的 `modelIsSelectable()`
  滤掉（症状：`/models` 看得到、pi 却说 Unknown provider）。
- **`~/.pi/agent/models.json` 的 `contextWindow` 必须大于「提示 + 输出上限 + 4096」**：
  `clampMaxTokensToContext()` 会算 `contextWindow − 提示 − 4096` 并夹到下限 1，声明太小会让 pi
  送出 `max_completion_tokens: 1`，只生一个 token 就 `finish_reason=length`。本实测：声明 8192、
  输出上限 512、router `ctx-size` 同步 8192（KV 用 q8_0）。
- **另两个坑**：`auth.json` 内的凭据 URL **优先于** `LLAMA_BASE_URL`；pi 在 stdin 非 TTY 时会
  吃掉 stdin，远程要写 `< /dev/null`。
- **实测值**（`-t 4`、8K ctx）：270M Q4 提示 10.95 tok/s、生成 2.76 tok/s、单回合 46 s；0.5B Q4
  首回合 77 s（`stopReason: stop`）、暖机后 16 s；llama-server RSS 530 MiB、板子可用 636 MiB。
- 注意：**链路**已验证，不代表小模型答得对（0.5B 事实正确率很差）。
