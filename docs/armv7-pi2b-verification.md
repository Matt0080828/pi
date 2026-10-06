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
against the Pi 2B on 2026-10-06, installing `@earendil-works/pi-coding-agent@1.0.4`:

```text
=== 0) 基本環境
    uname -m = armv7l  |  Raspbian GNU/Linux 13 (trixie)
    mem: 921 MiB total, 716 MiB available
    disk $HOME: 5.0G free
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

changed 121 packages in 4m

9 packages are looking for funding
  run `npm fund` for details
  ✓ 已安裝 @earendil-works/pi-coding-agent@1.0.4 到 /home/<user>/.local

=== 3) 驗收（可量測的項目）
  ✓ pi 執行檔存在：/home/<user>/.local/bin/pi
    pi --version → 1.0.4
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
    pi --version 耗時 4.98 s
    node RSS 基準: 39 MiB
    磁碟：Node 187M｜pi 套件 165M（注意：/home/<user>/.local 可能與其他工具共用，勿整包刪）

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

Independent re-measurement after the install (three further `pi --version` runs, same board, 1.0.4):

```text
  run1: 4.98 s (1.0.4)
  run2: 4.93 s (1.0.4)
  run3: 4.90 s (1.0.4)
  node RSS: 39 MiB
  free: 611 MiB available
  disk HOME: 5.0G
```

For reference, the previous cycle (2026-10-05, `all`, 1.0.2) measured
startup 5.09 s and 5.5 GB free; the 1.0.4 numbers above are a fresh install, not a re-read of that log.

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

## 板子自足的真實模型回合（2026-10-06，`pi` 1.0.4）

同一塊板子、同一個板子自足的 router（`llama-server --models-preset ~/llama/models.ini`，`127.0.0.1:8080`），
這次裝的是 `@earendil-works/pi-coding-agent@1.0.4`。先卸載模型，所以第一個回合是真正的冷啟
（`~/.pi/agent/models.json` 宣告 `contextWindow: 8192`，同上一節）。

```text
=== pi version: 1.0.4 ===
=== stray pi procs before (must be 0): 0 ===
=== router status before ===
[('qwen2.5-0.5b-instruct-q4_k_m', 'unloaded')]
=== unload (cold start) ===
{"error":{"code":400,"message":"model is not running","type":"invalid_request_error"}}
  mem before cold: 198 used / 649 avail
=== COLD turn #1 ===
cold rc=0 wall=771s stderr=0B out=55190B
=== WARM turn #2 ===
warm rc=0 wall=721s stderr=0B out=113876B
=== model status after ===
[('qwen2.5-0.5b-instruct-q4_k_m', 'loaded')]
=== resources ===
Mem: 921 total, 306 used, 59 free, 614 available (MiB)
llama-server RSS kB: 616112
=== router slot timing (tokens/s) ===
prompt eval time =  413433.22 ms /  681 tokens (607.10 ms per token,   1.65 tokens per second)
       eval time =  242881.06 ms /  241 tokens (1012.00 ms per token,  0.99 tokens per second)
      total time =  656314.28 ms /  922 tokens
(另一筆 slot：eval time = 49491.44 ms / 52 tokens = 1.03 tokens per second)
```

兩個回合都是 `rc=0`（沒有被 `timeout` 砍），而且各自在**一輪工具使用之後**以 `stopReason: stop`
的最終訊息收尾：冷回合回答「对不起，我找不到包含齿輪種類的文件。可能有误。」，暖回合讀了
`…/@earendil-works/pi-coding-agent/README.md` 再以英文總結。也就是說 1.0.4 在板子上端到端仍然可用：
提示 → 工具 → 最終文字，速率約 0.99–1.65 tok/s。

量測檔：板上 `~/measure104.out`，12,617 bytes，`sha256 b2f9803d37828e84…`（PC 上保留的副本同雜湊）。
