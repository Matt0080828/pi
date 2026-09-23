# ARMv7 / Pi 2B verification — English guide

> Language／語言：[繁體中文](armv7-pi2b-verification.md) ｜ [**English**](armv7-pi2b-verification.en.md) ｜ [简体中文](armv7-pi2b-verification.zh-CN.md) ｜ [日本語](armv7-pi2b-verification.ja.md) ｜ [한국어](armv7-pi2b-verification.ko.md) ｜ [Español](armv7-pi2b-verification.es.md)

This is an English guide to the **raw board log** in
[`armv7-pi2b-verification.md`](armv7-pi2b-verification.md). The raw log is the evidence and is kept
verbatim — the install script prints in Chinese, and rewriting it would destroy its value as a record.
Everything below is explanation and reference translation; where the two disagree, the raw log wins.

- Board: Raspberry Pi 2 Model B (armv7l, 921 MiB RAM), Raspbian GNU/Linux 13 (trixie)
- Cycle: 2026-09-23, installing `@earendil-works/pi-coding-agent@0.87.1`
- Command: `scripts/pi2-armv7/pi2-pi-agent.sh all` (probe → install → verify), driven from a PC over SSH
- Result: **11/11 acceptance checks passed**, `verify` exit 0

## What each block of the log means

| Log block | Contents |
| --- | --- |
| `=== 0) 基本環境` | Environment: `uname -m = armv7l`, Raspbian 13 (trixie), 921 MiB total / 640 MiB available RAM, 6.2 GB free in `$HOME`. Then the first three gates pass: the architecture is armv7l; the script runs as an unprivileged user (uid 1000) and installs only into `$HOME`; a downloader (`curl`) exists. |
| `=== 1) Node 22 armv7l` | Node v22.23.2 is already present at `/home/<user>/opt/node22/bin/node` (official armv7l build line), and `node:sqlite` is available, so the session backend needs no native module. |
| `=== 2) 安裝 pi coding agent` | npm 10.9.8 installs the published package into `/home/<user>/.local`: `changed 119 packages in 3m`. One deprecation warning (`node-domexception@1.0.0`) is upstream's and harmless. |
| `=== 3) 驗收（可量測的項目）` | The executable exists and **`pi --version` prints 0.87.1**; `pi --help` prints the expected banner. The six bundled prebuilds are listed and are all x64/arm64 (darwin/linux/win32) — **no `linux-arm`**, so nothing native is ever loaded on this board; the passing `pi --version` is the real proof. |
| `=== 4) 量測（給日後比對用）` | Measurements for later comparison: `pi --version` took 4.92 s, `node` baseline RSS 40 MiB, 187 MB for Node and 156 MB for the package. |
| `=== 5) 接下來（可選）` | How to persist the PATH in `~/.bashrc`, and how to run a real model turn (needs an API key or a local OpenAI-compatible endpoint such as LM Studio on the same LAN). |
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

## Independent re-measurement (same board, 0.87.1)

Three further `pi --version` runs after the install, plus the environment at that moment:

```text
  run1: 4.75 s (0.87.1)
  run2: 4.83 s (0.87.1)
  run3: 4.81 s (0.87.1)
  node RSS: 40 MiB
  free: 655 MiB available
  disk HOME: 6.2G
```

## Related board evidence (also measured, recorded elsewhere)

- The installed loader refuses to hand out a native helper on this architecture — measured on the
  board with the 0.87.1 package: `process.arch = arm`, and both `getNativeClipboard()` and
  `getNativePlatformHelper()` return `undefined`, which is the documented command-line fallback.
- The source-build gate behaves as documented: upstream's `packages/tui/native/linux/build.sh` exits
  **1** on armv7l (`Unsupported Linux architecture: armv7l`), while this fork's version prints a skip
  notice and exits **0**. A full from-source monorepo build on the board remains **unverified**.

See [`armv7-pi2b.en.md`](armv7-pi2b.en.md) for the full manual and
[`armv7-pi2b.md`](armv7-pi2b.md) for the Chinese original.
