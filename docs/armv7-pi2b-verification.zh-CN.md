# ARMv7 / Pi 2B 验收 —— 简体中文导读

> 语言／Language：[繁體中文](armv7-pi2b-verification.md) ｜ [English](armv7-pi2b-verification.en.md) ｜ **简体中文** ｜ [日本語](armv7-pi2b-verification.ja.md) ｜ [한국어](armv7-pi2b-verification.ko.md) ｜ [Español](armv7-pi2b-verification.es.md)

本文件是 [`armv7-pi2b-verification.md`](armv7-pi2b-verification.md) 里**实机原始日志**的中文导读。
原始日志才是证据，且逐字保留——安装脚本本身就是中文输出，改写它会破坏其记录价值。以下内容为说明与
对照翻译；两者若有出入，以原始日志为准。

- 目标板：Raspberry Pi 2 Model B（armv7l，921 MiB RAM），Raspbian GNU/Linux 13 (trixie)
- 轮次：2026-10-05，安装 `@earendil-works/pi-coding-agent@1.0.2`
- 命令：`scripts/pi2-armv7/pi2-pi-agent.sh all`（probe → install → verify），由 PC 通过 SSH 驱动
- 结果：**验收 11/11 通过**，`verify` exit 0

## 日志各区段是什么

| 日志区段 | 内容 |
| --- | --- |
| `=== 0) 基本環境` | 环境：`uname -m = armv7l`、Raspbian 13 (trixie)、921 MiB 总量 / 718 MiB 可用、`$HOME` 剩 5.6 GB。接着三道关卡通过：架构是 armv7l；以一般用户（uid 1000）执行且只装到 `$HOME`；有下载工具（`curl`）。 |
| `=== 1) Node 22 armv7l` | 已有 Node v22.23.2（`/home/<user>/opt/node22/bin/node`，官方 armv7l 构建线），且 `node:sqlite` 可用 → session backend 不需要原生模块。 |
| `=== 2) 安裝 pi coding agent` | 用 npm 10.9.8 把官方包装进 `/home/<user>/.local`：`added 4 packages, removed 5 packages, and changed 117 packages in 4m`。出现一条 `node-domexception@1.0.0` 弃用警告，属上游依赖、无害。 |
| `=== 3) 驗收（可量測的項目）` | 执行文件存在且 **`pi --version` 输出 1.0.2**；`pi --help` 正常。列出包内 6 个 prebuild，全为 x64/arm64（darwin/linux/win32）—— **没有 `linux-arm`**，所以在这块板子上永远不会加载任何原生件；真正有说服力的是上面那句 `pi --version` 成功输出。 |
| `=== 4) 量測（給日後比對用）` | 供日后比对的量测：`pi --version` 5.09 s、`node` 基准 RSS 39 MiB、Node 187 MB、pi 包 165 MB。 |
| `=== 5) 接下來（可選）` | 如何把 PATH 写进 `~/.bashrc` 持久化，以及如何跑一次真实模型回合（需要密钥，或自架的本机模型伺服器——1.0.2 的内建本机路径是 `LLAMA_BASE_URL` 指向的 llama.cpp router，不是 LM Studio 的 OpenAI 兼容 API）。 |
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

## 独立重测（同一块板，1.0.2）

安装后又跑了三次 `pi --version`，以及当时的板子状态：

```text
  run1: 4.99 s (1.0.2)
  run2: 4.87 s (1.0.2)
  run3: 4.80 s (1.0.2)
  node RSS: 39 MiB
  free: 716 MiB available
  disk HOME: 5.5G
```

## 其他板上证据（同为实测，记录在别处）

- 已安装的加载器在这块板子上拒绝提供原生 helper——用 0.99.2 包实测：`process.arch = arm`，
  `getNativeClipboard()` 与 `getNativePlatformHelper()` 都返回 `undefined`，也就是文件里写的命令行 fallback。
- 源码构建关卡行为与文件描述一致：upstream 的 `packages/tui/native/linux/build.sh` 在 armv7l 上退出
  **1**（`Unsupported Linux architecture: armv7l`），本 fork 版本打印跳过说明并退出 **0**。
  在板上**从源码整包构建**仍未验证。

完整手册见 [`armv7-pi2b.zh-CN.md`](armv7-pi2b.zh-CN.md)，繁体原版见 [`armv7-pi2b.md`](armv7-pi2b.md)。

## 板子自足的真实模型回合（2026-10-01）

交叉编译、板上 router 与两次 pi 真实回合的原始输出（模型与伺服器都在板子上）。做法见 `armv7-pi2b.zh-CN.md` 第 8 节。

```text
=== host: cross toolchain without sudo + llama-server build ===
  arm-linux-gnueabihf-gcc 11.4.0   (sysroot 2.35, target ld-linux-armhf.so.3)
  source: llama.cpp @ 121201a7b, cmake 3.22 toolchain file (no CMakePresets v4)
  flags: -march=armv7-a -mtune=cortex-a7 -mfpu=neon-vfpv4 -mfloat-abi=hard
         -DGGML_NATIVE=OFF -DGGML_NEON=ON -DGGML_CPU_ARM_ARCH=armv7-a -DGGML_OPENMP=ON -DLLAMA_CURL=OFF
         -static-libstdc++ -static-libgcc
  bin/llama-server  13.5 MB
  ELF 32-bit LSB pie executable, ARM, EABI5 version 1 (GNU/Linux), dynamically linked,
      interpreter /lib/ld-linux-armhf.so.3, for GNU/Linux 3.2.0
  NEEDED: libgomp.so.1, libm.so.6, libc.so.6, ld-linux-armhf.so.3

=== board: llama-server --version ===
  version: 0.3.0-dev (build 10734, commit 121201a7b)
  built with GNU 11.4.0 for Linux arm

=== board: router mode (llama-server --models-preset <ini>) ===
  load_models: Loaded 2 local model presets from /home/<user>/models
  Available models (2) (*: custom preset)
      functiongemma-270m-it-q4_k_m
      qwen2.5-0.5b-instruct-q4_k_m
  llama_server:     router mode

=== board: GET /models and /props ===
  functiongemma-270m-it-q4_k_m   status=unloaded  source=preset
  qwen2.5-0.5b-instruct-q4_k_m   status=unloaded  source=preset
  /props -> {"role":"router","max_instances":4,"models_autoload":true,"model_path":"none", ...}

=== board: pi real turn 1 - 270M Q4_K_M (46 s wall) ===
  slot print_timing: id  3 | task 0 | prompt eval time =  6577.32 ms /  72 tokens ( 10.95 tokens per second)
  slot print_timing: id  3 | task 0 |        eval time =  6877.79 ms /  20 tokens (  2.76 tokens per second)
  slot print_timing: id  3 | task 0 |       total time = 13455.10 ms /  92 tokens
  pi rc=0  wall=46s   (answer printed; 20 generated tokens, finish_reason=stop)

=== board: pi real turn 2 - 0.5B Q4_K_M, --mode json ===
  pi rc=0  wall=77s
  stopReason: stop | raw: stop
  usage: input 55 output 19 total 74
  answer: "台大山是台灣最高的山，海拔為1,253公尺。"
  # the pipeline is what was verified; a 0.5B model's factual accuracy is not a pass criterion

=== board: same loaded model, warm second turn ===
  wall=16s   (prompt eval 11 tokens, eval 7 tokens)

=== board: resources during the turns ===
  Mem: 921 total / 636 available MiB
  llama-server child RSS: 530 MiB
  KV cache type k/v: q8_0, ctx-size 8192, threads 4
```

Two findings that made the difference and are worth keeping next to these numbers:

- pi's router client only accepts models reported as `source=preset` (with `models_autoload: true`).
  Starting `llama-server --models-dir` makes `/models` list them with `source=models_dir`, and pi then
  reports `Unknown provider "llama.cpp"` because `modelIsSelectable()` filters them out.
- `clampMaxTokensToContext()` (`packages/ai/src/api/simple-options.ts`, `CONTEXT_SAFETY_TOKENS = 4096`,
  `MIN_MAX_TOKENS = 1`) computes `contextWindow - estimatedPrompt - 4096` and floors at 1. Declaring
  `contextWindow: 2048` in `~/.pi/agent/models.json` therefore sent `max_completion_tokens: 1` and every
  turn ended after a single token with `finish_reason=length`. Declaring 8192 (router `ctx-size` kept in
  step, q8_0 KV) produced the turns above.
