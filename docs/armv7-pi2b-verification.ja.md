# ARMv7 / Pi 2B 検証 — 日本語ガイド

> 言語／Language：[繁體中文](armv7-pi2b-verification.md) ｜ [English](armv7-pi2b-verification.en.md) ｜ [简体中文](armv7-pi2b-verification.zh-CN.md) ｜ **日本語** ｜ [한국어](armv7-pi2b-verification.ko.md) ｜ [Español](armv7-pi2b-verification.es.md)

このファイルは [`armv7-pi2b-verification.md`](armv7-pi2b-verification.md) にある**実機の生ログ**の
日本語ガイドです。生ログこそが証拠であり、逐語のまま保持します（インストールスクリプトの出力自体が
中国語で、書き換えると記録としての価値が失われるため）。以下は説明と対照訳で、両者が食い違う場合は
生ログが優先します。

- ボード：Raspberry Pi 2 Model B（armv7l、921 MiB RAM）、Raspbian GNU/Linux 13 (trixie)
- サイクル：2026-10-06、`@earendil-works/pi-coding-agent@1.0.4` をインストール
- コマンド：`scripts/pi2-armv7/pi2-pi-agent.sh all`（probe → install → verify）を PC から SSH 経由で実行
- 結果：**受け入れ検査 11/11 合格**、`verify` は exit 0

## ログの各ブロックの意味

| ログのブロック | 内容 |
| --- | --- |
| `=== 0) 基本環境` | 環境：`uname -m = armv7l`、Raspbian 13 (trixie)、921 MiB 中 718 MiB 空き、`$HOME` に 5.6 GB の空き。続いて 3 つのゲートを通過：アーキテクチャは armv7l、一般ユーザー（uid 1000）で実行し `$HOME` にのみインストール、ダウンローダ（`curl`）がある。 |
| `=== 1) Node 22 armv7l` | Node v22.23.2 が既にあり（`/home/<user>/opt/node22/bin/node`、公式 armv7l ビルド系列）、`node:sqlite` も利用可能 → セッション backend にネイティブモジュール不要。 |
| `=== 2) 安裝 pi coding agent` | npm 10.9.8 で公式パッケージを `/home/<user>/.local` に導入：`added 4 packages, removed 5 packages, and changed 117 packages in 4m`。`node-domexception@1.0.0` の非推奨警告が 1 件出ますが上流依存で無害です。 |
| `=== 3) 驗收（可量測的項目）` | 実行ファイルが存在し **`pi --version` が 1.0.4 を出力**、`pi --help` も正常。同梱の 6 つのプリビルドが列挙され、すべて x64/arm64（darwin/linux/win32）—— **`linux-arm` は無い**ため、このボードではネイティブは一切読み込まれません。本当の証拠は上の `pi --version` が成功している点です。 |
| `=== 4) 量測（給日後比對用）` | 後日比較用の計測：`pi --version` 5.09 秒、`node` 基準 RSS 39 MiB、Node 187 MB、pi パッケージ 165 MB。 |
| `=== 5) 接下來（可選）` | PATH を `~/.bashrc` に書いて永続化する方法と、実際のモデル 1 ターンの実行方法（キー、または自前のローカルモデルサーバーが必要——1.0.4 の内蔵ローカル経路は `LLAMA_BASE_URL` で指す llama.cpp router で、LM Studio の OpenAI 互換 API ではありません）。 |
| `完成。記錄檔請用 --check-only 重跑輸出存證。` | インストール実行の最終行（「完了。記録を残すには `--check-only` で再実行して出力を保存してください」）。 |

## 受け入れ検査（`pi2-pi-agent.sh verify`）の対応表

検証器はログをパターン照合し、1 つでも不一致なら fail-closed です（`✓` = 存在必須、`✗` = 存在禁止）：

| 結果 | ログ上のマーカー | 意味 |
| --- | --- | --- |
| ✓ | `架構是 armv7l` | armv7l（Pi 2B）で実行された |
| ✓ | `以一般使用者執行` | 一般ユーザーで実行（root でない） |
| ✓ | `Node v22\.` | Node は v22 系 |
| ✓ | `node:sqlite 可用` | 内蔵 SQLite セッション backend が使える |
| ✓ | `pi 執行檔存在` | `pi` 実行ファイルが存在する |
| ✓ | `pi --version → v?\d` | `pi --version` が出力を返した |
| ✗ | `prebuilds/linux-arm/` | armv7 専用プリビルドが現れなかった |
| ✗ | `以 root 身分執行中` | root で実行されていない |
| ✗ | `Node v(?!22\.)\d` | ログに v22 以外の Node の痕跡がない |
| ✗ | `意外發現原生 .node` | 想定外のネイティブ `.node` が出ていない |
| ✗ | `中止（fail-closed）` | 中止した手順がない |

## 独立した再計測（同じボード、1.0.4）

インストール後に `pi --version` をさらに 3 回実行し、その時点の状態も取得：

```text
  run1: 4.98 s (1.0.4)
  run2: 4.93 s (1.0.4)
  run3: 4.90 s (1.0.4)
  node RSS: 39 MiB
  free: 611 MiB available
  disk HOME: 5.0G
```

## その他の板上の証拠（いずれも実測、記録は別ファイル）

- 導入済みのローダーはこのアーキテクチャではネイティブ helper を渡しません——1.0.4 で再計測：
  `process.arch = arm` で `getNativeClipboard()` は `undefined`（1.0.4 では `getNativePlatformHelper()` は
  再エクスポートされません）。これはドキュメント記載のコマンドライン fallback です。
- ソースビルドのゲートは記載どおりに動作：上流の `packages/tui/native/linux/build.sh` は armv7l で
  **1** で終了（`Unsupported Linux architecture: armv7l`）、この fork の版はスキップメッセージを
  出して **0** で終了。ボード上での**ソースからの全ビルド**は依然として未検証です。

完全な手順書は [`armv7-pi2b.ja.md`](armv7-pi2b.ja.md)、繁体字版は [`armv7-pi2b.md`](armv7-pi2b.md)。

## 板の上だけで完結する実モデル 1 ターン（2026-10-01）

クロスビルド、板上の router、実際の pi 1 ターン 2 回の生の出力です（モデルもサーバーも板の上）。手順は `armv7-pi2b.ja.md` 第 8 節。

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

## 1.0.4 でのボード内ターン計測（2026-10-06）

`pi` 1.0.4 を導入した状態で、同じボード内 router を使ってもう一度計測しました。どちらのターンも
`rc=0`（コールド 771 s、ウォーム 721 s、タイムアウトなし）で、ツール使用 1 回のあとに
`stopReason: stop` の最終メッセージで終了しています。速度は約 0.99–1.65 tok/s。生の出力は
[armv7-pi2b-verification.md](armv7-pi2b-verification.md) に逐語で記録しています。
