# ARMv7 / Pi 2B 검증 — 한국어 해설

> 언어／Language：[繁體中文](armv7-pi2b-verification.md) ｜ [English](armv7-pi2b-verification.en.md) ｜ [简体中文](armv7-pi2b-verification.zh-CN.md) ｜ [日本語](armv7-pi2b-verification.ja.md) ｜ **한국어** ｜ [Español](armv7-pi2b-verification.es.md)

이 문서는 [`armv7-pi2b-verification.md`](armv7-pi2b-verification.md)의 **실기 원본 로그**에 대한
한국어 해설입니다. 원본 로그가 곧 증거이며 그대로 보존합니다(설치 스크립트 출력 자체가 중국어이고,
고쳐 쓰면 기록으로서의 가치가 사라집니다). 아래는 설명과 대조 번역이며, 둘이 다르면 원본 로그가 기준입니다.

- 보드: Raspberry Pi 2 Model B(armv7l, 921 MiB RAM), Raspbian GNU/Linux 13 (trixie)
- 사이클: 2026-09-23, `@earendil-works/pi-coding-agent@0.87.1` 설치
- 명령: `scripts/pi2-armv7/pi2-pi-agent.sh all`(probe → install → verify)을 PC에서 SSH로 구동
- 결과: **승인 검사 11/11 통과**, `verify` exit 0

## 로그 블록별 의미

| 로그 블록 | 내용 |
| --- | --- |
| `=== 0) 基本環境` | 환경: `uname -m = armv7l`, Raspbian 13 (trixie), 921 MiB 중 640 MiB 여유, `$HOME` 6.2 GB 여유. 이어서 세 개의 게이트 통과: 아키텍처가 armv7l, 일반 사용자(uid 1000)로 실행하며 `$HOME`에만 설치, 다운로더(`curl`) 존재. |
| `=== 1) Node 22 armv7l` | Node v22.23.2가 이미 있고(`/home/<user>/opt/node22/bin/node`, 공식 armv7l 빌드 계열), `node:sqlite`도 사용 가능 → 세션 백엔드에 네이티브 모듈 불필요. |
| `=== 2) 安裝 pi coding agent` | npm 10.9.8로 공식 패키지를 `/home/<user>/.local`에 설치: `changed 119 packages in 3m`. `node-domexception@1.0.0` 폐기 예정 경고 1건은 업스트림 의존성이며 무해합니다. |
| `=== 3) 驗收（可量測的項目）` | 실행 파일이 존재하고 **`pi --version`이 0.87.1을 출력**, `pi --help`도 정상. 동봉된 6개 사전 빌드가 나열되며 모두 x64/arm64(darwin/linux/win32) —— **`linux-arm` 없음**, 따라서 이 보드에서는 네이티브가 전혀 로드되지 않습니다. 진짜 증거는 위의 `pi --version` 성공입니다. |
| `=== 4) 量測（給日後比對用）` | 이후 비교용 계측: `pi --version` 4.92초, `node` 기준 RSS 40 MiB, Node 187 MB, pi 패키지 156 MB. |
| `=== 5) 接下來（可選）` | PATH를 `~/.bashrc`에 넣어 영구 적용하는 방법과 실제 모델 1턴 실행 방법(키 또는 같은 LAN의 LM Studio 등 OpenAI 호환 엔드포인트 필요). |
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

## 독립 재측정(같은 보드, 0.87.1)

설치 후 `pi --version`을 3회 더 실행하고 그 시점의 상태도 기록:

```text
  run1: 4.75 s (0.87.1)
  run2: 4.83 s (0.87.1)
  run3: 4.81 s (0.87.1)
  node RSS: 40 MiB
  free: 655 MiB available
  disk HOME: 6.2G
```

## 그 밖의 보드 증거(모두 실측, 기록은 별도 파일)

- 설치된 로더는 이 아키텍처에서 네이티브 helper를 제공하지 않습니다 —— 0.87.1로 실측:
  `process.arch = arm`에서 `getNativeClipboard()`와 `getNativePlatformHelper()` 모두 `undefined`
  (문서에 적힌 명령줄 fallback).
- 소스 빌드 게이트는 문서대로 동작합니다: 업스트림의 `packages/tui/native/linux/build.sh`는 armv7l에서
  **1**로 종료(`Unsupported Linux architecture: armv7l`), 이 fork의 버전은 건너뛴다는 메시지를 출력하고
  **0**으로 종료. 보드에서의 **소스 전체 빌드**는 여전히 미검증입니다.

전체 설명서는 [`armv7-pi2b.ko.md`](armv7-pi2b.ko.md), 번체 원본은 [`armv7-pi2b.md`](armv7-pi2b.md).
