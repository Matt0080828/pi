# ARMv7 / Pi 2B verification output

> **Note:** the paths below were redacted (`/home/<user>` instead of the real home directory)
> before publication. Nothing else was altered - the order and every number are as they came
> off the board.
>
> Guides to this log (explanations and reference translations; the log below stays verbatim):
> [English](armv7-pi2b-verification.en.md) ｜ [简体中文](armv7-pi2b-verification.zh-CN.md) ｜
> [日本語](armv7-pi2b-verification.ja.md) ｜ [한국어](armv7-pi2b-verification.ko.md) ｜
> [Español](armv7-pi2b-verification.es.md)

Raw output of `scripts/pi2-armv7/pi2-pi-agent.sh all` (probe → install → verify) driven from the PC
against the Pi 2B on 2026-10-01, installing `@earendil-works/pi-coding-agent@0.99.2`:

```text
=== 0) 基本環境
    uname -m = armv7l  |  Raspbian GNU/Linux 13 (trixie)
    mem: 921 MiB total, 734 MiB available
    disk $HOME: 5.8G free
  ✓ 架構是 armv7l（Pi2B）
  ✓ 以一般使用者執行（uid 1000），全程安裝到 $HOME，不需要 sudo
  ✓ 下載工具：curl

=== 1) Node 22 armv7l（官方 tarball，不使用 NodeSource／不用 v23+）
  ✓ 已有 /home/<user>/opt/node22/bin/node：v22.23.2
  ✓ Node v22.23.2 ✓（armv7 官方建置線）
  ✓ node:sqlite 可用（session backend 不需要原生模組）

=== 2) 安裝 pi coding agent（用 npm 套件，不用官方 arm64/x64 tarball）
    npm 10.9.8  |  目標 prefix: /home/<user>/.local
npm warn deprecated node-domexception@1.0.0: Use your platform's native DOMException instead

added 122 packages in 2m

9 packages are looking for funding
  run `npm fund` for details
  ✓ 已安裝 @earendil-works/pi-coding-agent@0.99.2 到 /home/<user>/.local

=== 3) 驗收（可量測的項目）
  ✓ pi 執行檔存在：/home/<user>/.local/bin/pi
    pi --version → 0.99.2
    pi --help   → pi - AI coding assistant with read, bash, edit, write tools  Usage: 
  套件內附的 prebuild（其他平台，armv7 不會載入）：
    @earendil-works/pi-coding-agent/node_modules/@earendil-works/pi-tui/native/darwin/prebuilds/darwin-arm64/darwin-platform.node
    @earendil-works/pi-coding-agent/node_modules/@earendil-works/pi-tui/native/darwin/prebuilds/darwin-x64/darwin-platform.node
    @earendil-works/pi-coding-agent/node_modules/@earendil-works/pi-tui/native/linux/prebuilds/linux-arm64/linux-platform-x11.node
    @earendil-works/pi-coding-agent/node_modules/@earendil-works/pi-tui/native/linux/prebuilds/linux-x64/linux-platform-x11.node
    @earendil-works/pi-coding-agent/node_modules/@earendil-works/pi-tui/native/win32/prebuilds/win32-arm64/win32-platform.node
    @earendil-works/pi-coding-agent/node_modules/@earendil-works/pi-tui/native/win32/prebuilds/win32-x64/win32-platform.node
  ✓ 沒有 linux-arm（armv7）的 prebuild（armv7 走 JS 路徑 ✓）
  ✓ （真正的證明：pi --version 已在上面正常輸出 ✓）

=== 4) 量測（給日後比對用）
    pi --version 耗時 4.89 s
    node RSS 基準: 39 MiB
    磁碟：Node 187M｜pi 套件 168M（注意：/home/<user>/.local 可能與其他工具共用，勿整包刪）

=== 5) 接下來（可選，需要你的 API key 或本機端點）
    export PATH="/home/<user>/opt/node22/bin:/home/<user>/.local/bin:$PATH"     # 加進 ~/.bashrc 才會持久
    pi --version
    # 真實回合（需要 API 金鑰；本機端點走 pi 內建的 llama.cpp router，不吃 LM Studio 的 OpenAI 相容 API）
    LLAMA_BASE_URL=http://<同一網段的機器>:8080 pi "hello"   # 由 pi 的 llama.cpp 擴充使用

完成。記錄檔請用 --check-only 重跑輸出存證。
```

The same run's fail-closed acceptance step (`scripts/pi2-armv7/pi2-pi-agent.sh verify`), judged
against the log above:

```text
=== 驗收：scripts/pi2-armv7/logs/latest.log
  ✓ 架構是 armv7l
  ✓ 以一般使用者執行（非 root）
  ✓ Node 是 v22 系列
  ✓ node:sqlite 可用
  ✓ pi 執行檔存在
  ✓ pi --version 有輸出
  ✓ 沒有 armv7 專屬的 prebuild
  ✓ 沒有以 root 身分執行
  ✓ 沒有任何非 v22 的 Node 痕跡
  ✓ 沒有意外出現 .node
  ✓ 沒有中止（fail-closed）

✅ 全部驗收項目通過（實機量測，非推論）
```

Independent re-measurement after the install (three further `pi --version` runs, same board, 0.99.2):

```text
  run1: 5.04 s (0.99.2)
  run2: 4.99 s (0.99.2)
  run3: 4.80 s (0.99.2)
  node RSS: 39 MiB
  free: 725 MiB available
  disk HOME: 5.6G
```

For reference, the previous cycle (earlier the same day, 2026-10-01, `all`, 0.99.1) measured
startup 4.79 s and 5.8 GB free; the 0.99.2 numbers above are a fresh install, not a re-read of that log.

## Board-local model turn (2026-10-01)

Raw output from the cross-build, the on-board router and two real pi turns with the model and server running on the board. `EN` / `ZH-CN` / `JA` / `KO` / `ES` copies carry the same block; the narrative recipe is in `armv7-pi2b.md` §7 (English: §8).

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
