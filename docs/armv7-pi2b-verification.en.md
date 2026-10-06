# ARMv7 / Pi 2B verification — English guide

> Language／語言：[繁體中文](armv7-pi2b-verification.md) ｜ [**English**](armv7-pi2b-verification.en.md) ｜ [简体中文](armv7-pi2b-verification.zh-CN.md) ｜ [日本語](armv7-pi2b-verification.ja.md) ｜ [한국어](armv7-pi2b-verification.ko.md) ｜ [Español](armv7-pi2b-verification.es.md)

This is an English guide to the **raw board log** in
[`armv7-pi2b-verification.md`](armv7-pi2b-verification.md). The raw log is the evidence and is kept
verbatim — the install script prints in Chinese, and rewriting it would destroy its value as a record.
Everything below is explanation and reference translation; where the two disagree, the raw log wins.

- Board: Raspberry Pi 2 Model B (armv7l, 921 MiB RAM), Raspbian GNU/Linux 13 (trixie)
- Cycle: 2026-10-06, installing `@earendil-works/pi-coding-agent@1.0.4`
- Command: `scripts/pi2-armv7/pi2-pi-agent.sh all` (probe → install → verify), driven from a PC over SSH
- Result: **11/11 acceptance checks passed**, `verify` exit 0

## What each block of the log means

| Log block | Contents |
| --- | --- |
| `=== 0) 基本環境` | Environment: `uname -m = armv7l`, Raspbian 13 (trixie), 921 MiB total / 716 MiB available RAM, 5.0 GB free in `$HOME`. Then the first three gates pass: the architecture is armv7l; the script runs as an unprivileged user (uid 1000) and installs only into `$HOME`; a downloader (`curl`) exists. |
| `=== 1) Node 22 armv7l` | Node v22.23.2 is already present at `/home/<user>/opt/node22/bin/node` (official armv7l build line), and `node:sqlite` is available, so the session backend needs no native module. |
| `=== 2) 安裝 pi coding agent` | npm 10.9.8 installs the published package into `/home/<user>/.local`: `added 4 packages, removed 5 packages, and changed 117 packages in 4m`. One deprecation warning (`node-domexception@1.0.0`) is upstream's and harmless. |
| `=== 3) 驗收（可量測的項目）` | The executable exists and **`pi --version` prints 1.0.4**; `pi --help` prints the expected banner. The six bundled prebuilds are listed and are all x64/arm64 (darwin/linux/win32) — **no `linux-arm`**, so nothing native is ever loaded on this board; the passing `pi --version` is the real proof. |
| `=== 4) 量測（給日後比對用）` | Measurements for later comparison: `pi --version` took 5.09 s, `node` baseline RSS 39 MiB, 187 MB for Node and 165 MB for the package. |
| `=== 5) 接下來（可選）` | How to persist the PATH in `~/.bashrc`, and how to run a real model turn (needs an API key, or a local model server of your own — with 1.0.4 the built-in local path is the llama.cpp router via `LLAMA_BASE_URL`, not LM Studio's OpenAI-compatible API). |
| `完成。記錄檔請用 --check-only 重跑輸出存證。` | The final line of the install run ("Done. To keep a record, re-run with `--check-only`"). |

## Acceptance checks (`pi2-pi-agent.sh verify`) — English labels

The verifier greps the log for these markers and fails closed on any mismatch
(`✓` = must be present, `✗` = must be absent):

| Result | Marker in the log | Meaning |
| --- | --- | --- |
| ✓ | `架構是 armv7l` | It ran on armv7l (Pi 2B) |
| ✓ | `以一般使用者執行` | It ran unprivileged, not as root |
| ✓ | `Node v22\.` | Node is on the v22 line |
| ✓ | `node:sqlite 可用` | The built-in SQLite session backend is usable |
| ✓ | `pi 執行檔存在` | The `pi` executable exists |
| ✓ | `pi --version → v?\d` | `pi --version` produced output |
| ✗ | `prebuilds/linux-arm/` | No ARMv7-specific prebuild appeared |
| ✗ | `以 root 身分執行中` | It was not run as root |
| ✗ | `Node v(?!22\.)\d` | No non-v22 Node trace anywhere in the log |
| ✗ | `意外發現原生 .node` | No unexpected native `.node` was found |
| ✗ | `中止（fail-closed）` | No step aborted |

## Independent re-measurement (same board, 1.0.4)

Three further `pi --version` runs after the install, plus the environment at that moment:

```text
  run1: 4.98 s (1.0.4)
  run2: 4.93 s (1.0.4)
  run3: 4.90 s (1.0.4)
  node RSS: 39 MiB
  free: 611 MiB available
  disk HOME: 5.0G
```

## Related board evidence (also measured, recorded elsewhere)

- The installed loader refuses to hand out a native helper on this architecture — re-measured on
  the board with the 1.0.4 package: `process.arch = arm` and `getNativeClipboard()` returns
  `undefined` (`getNativePlatformHelper()` is no longer re-exported by `@earendil-works/pi-tui`),
  which is the documented command-line fallback.
- The source-build gate behaves as documented: upstream's `packages/tui/native/linux/build.sh` exits
  **1** on armv7l (`Unsupported Linux architecture: armv7l`), while this fork's version prints a skip
  notice and exits **0**. A full from-source monorepo build on the board remains **unverified**.

See [`armv7-pi2b.en.md`](armv7-pi2b.en.md) for the full manual and
[`armv7-pi2b.md`](armv7-pi2b.md) for the Chinese original.

## Board-local model turn (2026-10-01)

Raw output from the cross-build, the on-board router and two real pi turns with the model and server running on the board. Recipe: `armv7-pi2b.en.md` §8.

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

## Board-local turn run with 1.0.4 (2026-10-06)

A second board-local run was taken with `pi` 1.0.4 installed, on the same board-local router. Both turns
returned `rc=0` (cold 771 s, warm 721 s — no timeout), each ending in a final message with
`stopReason: stop` after one round of tool use, at ~0.99–1.65 tok/s. The raw output is recorded verbatim
in [armv7-pi2b-verification.md](armv7-pi2b-verification.md).
