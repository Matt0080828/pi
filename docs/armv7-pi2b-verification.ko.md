# ARMv7 / Pi 2B 검증 — 한국어 해설

> 언어／Language：[繁體中文](armv7-pi2b-verification.md) ｜ [English](armv7-pi2b-verification.en.md) ｜ [简体中文](armv7-pi2b-verification.zh-CN.md) ｜ [日本語](armv7-pi2b-verification.ja.md) ｜ **한국어** ｜ [Español](armv7-pi2b-verification.es.md)

이 문서는 [`armv7-pi2b-verification.md`](armv7-pi2b-verification.md)의 **실기 원본 로그**에 대한
한국어 해설입니다. 원본 로그가 곧 증거이며 그대로 보존합니다(설치 스크립트 출력 자체가 중국어이고,
고쳐 쓰면 기록으로서의 가치가 사라집니다). 아래는 설명과 대조 번역이며, 둘이 다르면 원본 로그가 기준입니다.

- 보드: Raspberry Pi 2 Model B(armv7l, 921 MiB RAM), Raspbian GNU/Linux 13 (trixie)
- 사이클: 2026-10-05, `@earendil-works/pi-coding-agent@1.0.2` 설치
- 명령: `scripts/pi2-armv7/pi2-pi-agent.sh all`(probe → install → verify)을 PC에서 SSH로 구동
- 결과: **승인 검사 11/11 통과**, `verify` exit 0

## 로그 블록별 의미

| 로그 블록 | 내용 |
| --- | --- |
| `=== 0) 基本環境` | 환경: `uname -m = armv7l`, Raspbian 13 (trixie), 921 MiB 중 718 MiB 여유, `$HOME` 5.6 GB 여유. 이어서 세 개의 게이트 통과: 아키텍처가 armv7l, 일반 사용자(uid 1000)로 실행하며 `$HOME`에만 설치, 다운로더(`curl`) 존재. |
| `=== 1) Node 22 armv7l` | Node v22.23.2가 이미 있고(`/home/<user>/opt/node22/bin/node`, 공식 armv7l 빌드 계열), `node:sqlite`도 사용 가능 → 세션 백엔드에 네이티브 모듈 불필요. |
| `=== 2) 安裝 pi coding agent` | npm 10.9.8로 공식 패키지를 `/home/<user>/.local`에 설치: `added 4 packages, removed 5 packages, and changed 117 packages in 4m`. `node-domexception@1.0.0` 폐기 예정 경고 1건은 업스트림 의존성이며 무해합니다. |
| `=== 3) 驗收（可量測的項目）` | 실행 파일이 존재하고 **`pi --version`이 1.0.2을 출력**, `pi --help`도 정상. 동봉된 6개 사전 빌드가 나열되며 모두 x64/arm64(darwin/linux/win32) —— **`linux-arm` 없음**, 따라서 이 보드에서는 네이티브가 전혀 로드되지 않습니다. 진짜 증거는 위의 `pi --version` 성공입니다. |
| `=== 4) 量測（給日後比對用）` | 이후 비교용 계측: `pi --version` 5.09초, `node` 기준 RSS 39 MiB, Node 187 MB, pi 패키지 165 MB. |
| `=== 5) 接下來（可選）` | PATH를 `~/.bashrc`에 넣어 영구 적용하는 방법과 실제 모델 1턴 실행 방법(키 또는 자체 로컬 모델 서버 필요 — 1.0.2의 내장 로컬 경로는 `LLAMA_BASE_URL`로 지정하는 llama.cpp router이며, LM Studio의 OpenAI 호환 API가 아닙니다). |
| `完成。記錄檔請用 --check-only 重跑輸出存證。` | 설치 실행의 마지막 줄("완료. 기록을 남기려면 `--check-only`로 다시 실행해 출력을 저장하세요"). |

## 승인 검사(`pi2-pi-agent.sh verify`) 대응표

검증기는 로그를 패턴 매칭하며 하나라도 어긋나면 fail-closed입니다(`✓` = 반드시 존재, `✗` = 존재 금지):

| 결과 | 로그 마커 | 의미 |
| --- | --- | --- |
| ✓ | `架構是 armv7l` | armv7l(Pi 2B)에서 실행됨 |
| ✓ | `以一般使用者執行` | 일반 사용자로 실행(root 아님) |
| ✓ | `Node v22\.` | Node가 v22 계열 |
| ✓ | `node:sqlite 可用` | 내장 SQLite 세션 백엔드 사용 가능 |
| ✓ | `pi 執行檔存在` | `pi` 실행 파일 존재 |
| ✓ | `pi --version → v?\d` | `pi --version`이 출력을 냄 |
| ✗ | `prebuilds/linux-arm/` | armv7 전용 사전 빌드가 나타나지 않음 |
| ✗ | `以 root 身分執行中` | root로 실행되지 않음 |
| ✗ | `Node v(?!22\.)\d` | 로그에 v22가 아닌 Node 흔적이 없음 |
| ✗ | `意外發現原生 .node` | 예상치 못한 네이티브 `.node` 없음 |
| ✗ | `中止（fail-closed）` | 중단된 단계 없음 |

## 독립 재측정(같은 보드, 1.0.2)

설치 후 `pi --version`을 3회 더 실행하고 그 시점의 상태도 기록:

```text
  run1: 4.99 s (1.0.2)
  run2: 4.87 s (1.0.2)
  run3: 4.80 s (1.0.2)
  node RSS: 39 MiB
  free: 716 MiB available
  disk HOME: 5.5G
```

## 그 밖의 보드 증거(모두 실측, 기록은 별도 파일)

- 설치된 로더는 이 아키텍처에서 네이티브 helper를 제공하지 않습니다 —— 0.99.2로 실측:
  `process.arch = arm`에서 `getNativeClipboard()`와 `getNativePlatformHelper()` 모두 `undefined`
  (문서에 적힌 명령줄 fallback).
- 소스 빌드 게이트는 문서대로 동작합니다: 업스트림의 `packages/tui/native/linux/build.sh`는 armv7l에서
  **1**로 종료(`Unsupported Linux architecture: armv7l`), 이 fork의 버전은 건너뛴다는 메시지를 출력하고
  **0**으로 종료. 보드에서의 **소스 전체 빌드**는 여전히 미검증입니다.

전체 설명서는 [`armv7-pi2b.ko.md`](armv7-pi2b.ko.md), 번체 원본은 [`armv7-pi2b.md`](armv7-pi2b.md).

## 보드 자체만으로 완결되는 실제 모델 1턴(2026-10-01)

크로스 빌드, 보드의 router, 실제 pi 1턴 2회의 원시 출력입니다(모델과 서버 모두 보드에서 실행). 절차는 `armv7-pi2b.ko.md` 8절.

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
