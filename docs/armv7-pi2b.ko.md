# Raspberry Pi 2 Model B(ARMv7)에서 pi 실행하기

> 언어／Language：[繁體中文](armv7-pi2b.md) ｜ [English](armv7-pi2b.en.md) ｜ [简体中文](armv7-pi2b.zh-CN.md) ｜ [日本語](armv7-pi2b.ja.md) ｜ **한국어** ｜ [Español](armv7-pi2b.es.md)

**결론: 실행됩니다. 실물 Pi2B에서 계측으로 확인했습니다(승인 검사 11/11 통과).** agent 코드는
전혀 수정할 필요가 없고 **공식 npm 패키지**를 설치하면 됩니다. 이 브랜치가 추가한 것은 두 군데의
작은 "활성화" 변경뿐이며, 목적은 "armv7에서 소스로 빌드"와 "나중에 armv7 네이티브 helper를 만드는"
경우가 아키텍처 때문에 막히지 않게 하는 것입니다(아래 "이 브랜치의 변경").

- 대상 보드: Raspberry Pi 2 Model B(armv7l, 4×900 MHz, 921 MiB RAM), Raspbian GNU/Linux 13 (trixie)
- 계측일: **2026-09-23(`@earendil-works/pi-coding-agent@0.87.1`)**｜이전 사이클은 2026-09-22의 0.87.0
- 원본 로그: [`armv7-pi2b-verification.md`](armv7-pi2b-verification.md)([한국어 해설](armv7-pi2b-verification.ko.md) 포함)
- 근거는 **실기 계측**이며 정적 추론이 아닙니다: 승인 검사 11/11 통과

---

## 1. 결정적인 세 가지 사실

| 사실 | 근거 |
| --- | --- |
| **Node 22에는 공식 armv7l 빌드가 있고 Node 23 이상에는 없다** | `nodejs.org/dist/index.json`: v22는 **35/35** 모든 릴리스가 `linux-armv7l`을 포함(22.19 이상 11개 포함, 최신 v22.23.2). 최근 12개 릴리스(v23 이상)에는 없음. 이 저장소는 `engines.node >= 22.19.0`을 요구 → **v22 계열에서만 충족** |
| **공식 사전 빌드 바이너리에 armv7이 없다** | 릴리스 자산은 `linux-x64` / `linux-arm64` / `darwin-x64|arm64` / `windows-x64|arm64`뿐이고 `build-binaries.yml`의 플랫폼 분기도 같은 네 가지뿐 → 공식 tarball은 **사용 불가** |
| **npm 패키지 경로에는 네이티브 장애물이 없다** | `@earendil-works/pi-coding-agent@0.87.1`: **`os`/`cpu` 제한 없음**, 사전 빌드 CLI 포함(`dist/bundle/*.js`), 의존성은 순수 JS 또는 wasm(`photon-node`가 `photon_rs_bg.wasm` 포함), `canvas`는 `devDependencies`만, 세션 백엔드는 Node 내장 `node:sqlite` |

유일한 기능 손실: TUI의 네이티브 X11/클립보드 helper(`linux-platform-x11.node`)는 x64/arm64
사전 빌드만 있고, 로더 `packages/tui/src/native-platform.ts`는 다른 아키텍처에서 `undefined`를
반환합니다. `packages/tui/native/linux/README.md` 자체가 "Coding-agent falls back to command-line
tools when native reads are unavailable"라고 적고 있으므로 armv7에서 이것은 **설계상 허용된 성능 저하**입니다.
(크래시는 없고 클립보드/이미지 연동만 사라집니다.)

설치된 0.87.1로 보드에서 직접 측정:

```text
process.arch = arm, process.platform = linux
getNativeClipboard()      -> undefined
getNativePlatformHelper() -> undefined
```

## 2. 보드 실측 결과

| 검사 | 실측값 |
| --- | --- |
| 아키텍처 | `armv7l` (Raspbian 13 trixie) |
| 실행 사용자 | uid 1000, **sudo 전혀 사용 안 함** (`$HOME`에 설치) |
| Node | **v22.23.2** (공식 `linux-armv7l` tarball, 26,338,176 bytes) |
| `node:sqlite` | **사용 가능** → 세션 백엔드에 네이티브 모듈 불필요 |
| CLI | **`pi --version` → 0.87.1**, `pi --help` 정상 출력 |
| npm 설치 | `changed 119 packages in 3m` (npm 10.9.8) |
| 동봉 사전 빌드 | `darwin-arm64|x64`, `linux-arm64|x64`, `win32-arm64|x64`뿐 —— **`linux-arm`(armv7) 없음** |
| 시작 시간 | `pi --version` **4.75–4.92초** (Pi2B 콜드 스타트, 4회 측정) |
| 메모리 | `node` 기준 RSS **40 MiB** (설치 중 여유 640 MiB, OOM 없음) |
| 디스크 | Node 187 MB + pi 패키지 156 MB (`$HOME` 여유 6.2 GB) |

> 알려진 한계: **CLI 자체는 검증되었지만** 실제 모델 1턴은 API 키나 같은 LAN의 LM Studio 같은
> OpenAI 호환 엔드포인트가 필요하며, 이 브랜치의 승인 검사는 그 단계를 포함하지 않습니다.

## 3. 설치와 사용

Pi2B에서(**sudo 불필요**, 전부 `$HOME`에 설치):

```sh
# 1) Node 22 armv7l (공식 tarball; NodeSource나 v23 이상은 사용하지 말 것)
curl -fsSLO https://nodejs.org/dist/v22.23.2/node-v22.23.2-linux-armv7l.tar.xz
mkdir -p ~/opt && tar -xJf node-v22.23.2-linux-armv7l.tar.xz -C ~/opt
ln -sfn ~/opt/node-v22.23.2-linux-armv7l ~/opt/node22

# 2) CLI
export PATH="$HOME/opt/node22/bin:$HOME/.local/bin:$PATH"
node -v                      # v22.23.2
npm install -g --prefix ~/.local @earendil-works/pi-coding-agent
pi --version                 # 0.87.1

# 3) 영구 적용 (~/.bashrc에 추가)
echo 'export PATH="$HOME/opt/node22/bin:$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

**소스에서** 빌드하는 경우(이 저장소 자체):

```sh
git clone https://github.com/matttest0080-prog/pi.git && cd pi
npm ci && npm run build      # armv7에서는 아래 build.sh 변경이 필요
```

> 이 소스 빌드 경로는 보드에서 처음부터 끝까지 **검증하지 않았습니다**. 보드에서 측정한 것은
> 아키텍처 판정 부분 자체입니다: 업스트림의 `packages/tui/native/linux/build.sh`는 **1**로 종료
> (`Unsupported Linux architecture: armv7l`), 이 fork의 버전은 건너뛴다는 메시지를 출력하고 **0**으로 종료.
> 그 이후(921 MiB 보드에서 TypeScript 모노레포 전체 빌드)는 아직 미검증입니다.

이 브랜치에는 실기로 검증한 스크립트 세 개와 자체 테스트가 들어 있습니다(`scripts/pi2-armv7/`):

```sh
scripts/pi2-armv7/install-pi-on-pi2.sh              # Pi에서: 게이트 → 설치 → 검사 → 계측
scripts/pi2-armv7/install-pi-on-pi2.sh --dry-run    # 단계만 출력하고 아무것도 변경하지 않음
scripts/pi2-armv7/install-pi-on-pi2.sh --check-only # 현재 상태만 확인하고 설치하지 않음
scripts/pi2-armv7/pi2-pi-agent.sh probe|install|verify|all   # PC에서 SSH로 구동
scripts/pi2-armv7/selftest.sh                       # 도구 자체의 자체 테스트(부정 경로 포함)
```

이들은 의도적으로 **fail-closed**입니다: `armv7l`이 아님, root로 실행, Node가 v22가 아님,
armv7 전용 사전 빌드 발견, 로그에 v22가 아닌 Node 흔적, 어느 단계든 실패 —— 어느 하나라도
해당하면 명확히 거부하고 0이 아닌 코드로 종료합니다.

## 4. 이 브랜치의 변경

**CLI를 실행하는 데 코드 변경은 전혀 필요 없습니다**(실기 결과가 그 증거입니다). 아래 두 곳은
"armv7에서 소스 빌드"와 "나중에 실제로 armv7 네이티브 helper를 만드는" 경우가 막히지 않게 하기 위한
**선택적 활성화 변경**이며, 각각 이유를 주석으로 남겼습니다:

| 파일 | 변경 | 이유 |
| --- | --- | --- |
| `packages/tui/native/linux/build.sh` | `armv7l`/`armv6l`에서 명시적 메시지를 출력하고 **exit 0**(컴파일 안 함) | 원래 `case`는 `x86_64`/`aarch64`만 알고 나머지는 `exit 1` → Pi2에서 `npm run build`가 실패. armv7에는 사전 빌드가 없고 로더도 요청하지 않으므로 "명시적 건너뛰기"가 "워크스페이스 전체 빌드 실패"보다 옳음 |
| `packages/tui/src/native-platform.ts` | 로더의 아키텍처 검사가 `arm`도 허용 | **직접 빌드한** armv7 helper를 가진 사람이 실제로 사용할 수 있게 함. helper가 없으면 동작은 기존과 완전히 동일(`require` 실패 후 `undefined` 반환). 참고: npm 패키지는 사전 빌드 JS이므로 이 변경은 **재빌드 후에만** 적용됨 |

둘 다 x64/arm64 동작에는 영향을 주지 않습니다.

## 5. 원상 복구

```sh
# pi 부분만 제거(~/.local은 같은 보드의 hermes 등 다른 도구와 공유될 수 있음)
rm -rf ~/.local/lib/node_modules/@earendil-works ~/.local/bin/pi
rm -rf ~/opt/node22 ~/opt/node-v22.23.2-linux-armv7l
```

## 6. 이 검증의 재현

```sh
scripts/pi2-armv7/selftest.sh                                   # 도구 자체 테스트(PC에서, 보드 미접촉)
scripts/pi2-armv7/pi2-pi-agent.sh all                            # probe → install → verify
scripts/pi2-armv7/pi2-pi-agent.sh verify docs/armv7-pi2b-verification.md
```

## 7. 주의 사항과 이 작업에서 걸린 함정

- **설치 중 발견한 실제 버그 두 개는 모두 게이트가 막아낸 것이며 사후 발견이 아니었습니다**: 공식 Node
  tarball은 압축을 풀면 디렉터리 이름에 `v`가 남습니다(`node-v22.23.2-linux-armv7l`). 또 처음에 승인 조건을
  "`node_modules`에 `.node`가 전혀 없어야 한다"고 적은 것은 잘못이었습니다 —— 패키지는 다른 플랫폼의
  사전 빌드를 정당하게 동봉합니다. 올바른 불변식은 "**armv7 전용 사전 빌드가 없음** *그리고* CLI가 시작함"입니다.
- **0.87.1 패키지 메타데이터도 다시 확인했습니다**: 여전히 `os`/`cpu` 제한 없음, `pi-tui`의 사전 빌드는
  여전히 x64/arm64 6개뿐(`linux-arm` 없음).
- **업스트림 동기화는 ARMv7 작업에 영향을 주지 않습니다**: 업스트림 `898ab8040`(v0.87.1)을 병합한 뒤에도
  ARMv7 9개 파일은 바이트 단위로 동일했고, 병합된 트리와 업스트림의 차이는 정확히 그 9개 파일뿐입니다.
