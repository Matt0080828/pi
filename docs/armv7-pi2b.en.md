# Running `pi` on a Raspberry Pi 2 Model B (ARMv7)

**Verdict: yes, it runs — measured on a physical Pi 2B (11/11 acceptance checks).** No agent source
changes are required: install the **official npm package**. This branch adds two small enabling changes
so that "building from source on ARMv7" and "a future ARMv7 native helper" are not blocked by the
architecture (see [What this fork changes](#4-what-this-fork-changes)).

- Target board: Raspberry Pi 2 Model B (armv7l, 4x900 MHz, 921 MiB RAM), Raspbian GNU/Linux 13 (trixie)
- Measured: **2026-09-23 with `@earendil-works/pi-coding-agent@0.87.1`** (previous cycle: 2026-09-22, 0.87.0)
- Raw board log: [`armv7-pi2b-verification.md`](armv7-pi2b-verification.md) — with an English guide to
  the same log: [`armv7-pi2b-verification.en.md`](armv7-pi2b-verification.en.md)
- The evidence is **hardware measurement, not static reasoning**: 11/11 acceptance checks passed
- 繁體中文原版：[`armv7-pi2b.md`](armv7-pi2b.md)

---

## 1. Three decisive facts

| Fact | Evidence |
| --- | --- |
| **Node 22 has official armv7l builds; Node 23+ does not** | `nodejs.org/dist/index.json`: every v22 release ships `linux-armv7l` (**35/35**, including all 11 releases >= 22.19, latest v22.23.2); none of the 12 most recent releases (v23+) do. This repo requires `engines.node >= 22.19.0` → **only the v22 line satisfies it** |
| **The official prebuilt binaries contain no armv7** | Release assets are `linux-x64` / `linux-arm64` / `darwin-x64|arm64` / `windows-x64|arm64` only, and `build-binaries.yml` lists exactly those four platform cases → the official tarball is **not usable** |
| **The npm package route has no native obstacle** | `@earendil-works/pi-coding-agent@0.87.1`: **no `os`/`cpu` restriction**, ships a prebuilt CLI (`dist/bundle/*.js`), depends only on plain JS or wasm (`photon-node` carries `photon_rs_bg.wasm`), `canvas` is a `devDependency` only, and the session backend uses Node's built-in `node:sqlite` |

The only functional loss: the TUI's native X11/clipboard helper (`linux-platform-x11.node`) ships
prebuilds for x64/arm64 only, and the loader `packages/tui/src/native-platform.ts` returns `undefined`
for any other architecture. `packages/tui/native/linux/README.md` states this itself — "Coding-agent
falls back to command-line tools when native reads are unavailable" — so on ARMv7 this is a
**documented, intentional degradation**: nothing crashes, it just loses clipboard/image integration.

Measured on the board with the installed 0.87.1 package (armv7l):

```text
process.arch = arm, process.platform = linux
getNativeClipboard()      -> undefined
getNativePlatformHelper() -> undefined
```

## 2. Measured on the board

| Check | Measured |
| --- | --- |
| Architecture | `armv7l` (Raspbian 13 trixie), kernel-provided `uname -m` |
| Identity | uid 1000, **no sudo anywhere** (installed into `$HOME`) |
| Node | **v22.23.2** (official `linux-armv7l` tarball, 26,338,176 bytes) |
| `node:sqlite` | **available** → the session backend needs no native module |
| CLI | **`pi --version` → 0.87.1**; `pi --help` prints normally |
| npm install | `changed 119 packages in 3m` (npm 10.9.8) |
| Bundled prebuilds | only `darwin-arm64|x64`, `linux-arm64|x64`, `win32-arm64|x64` — **no `linux-arm` (armv7)** |
| Startup | `pi --version` **4.75-4.92 s** (Pi2B cold start, four runs) |
| Memory | `node` baseline RSS **40 MiB**; 640 MiB available during install, no OOM |
| Disk | Node 187 MB + pi package 156 MB (6.2 GB free in `$HOME`) |

> Known limitation: the **CLI itself is verified**, but a real model turn needs an API key or a local
> OpenAI-compatible endpoint (for example LM Studio on the same LAN). This branch's acceptance does not
> cover that step.

## 3. Install and use

On the Pi 2B (**no sudo needed**; everything installs into `$HOME`):

```sh
# 1) Node 22 armv7l (official tarball; do not use NodeSource or v23+)
curl -fsSLO https://nodejs.org/dist/v22.23.2/node-v22.23.2-linux-armv7l.tar.xz
mkdir -p ~/opt && tar -xJf node-v22.23.2-linux-armv7l.tar.xz -C ~/opt
ln -sfn ~/opt/node-v22.23.2-linux-armv7l ~/opt/node22

# 2) CLI
export PATH="$HOME/opt/node22/bin:$HOME/.local/bin:$PATH"
node -v                      # v22.23.2
npm install -g --prefix ~/.local @earendil-works/pi-coding-agent
pi --version                 # 0.87.1

# 3) Persist it (append to ~/.bashrc)
echo 'export PATH="$HOME/opt/node22/bin:$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

To build **from source** (this repo itself):

```sh
git clone https://github.com/matttest0080-prog/pi.git && cd pi
npm ci && npm run build      # on armv7 this needs the build.sh change below
```

> That source-build path has **not** been verified end to end on the board. What *is* measured on the
> board is the architecture gate itself: upstream's `packages/tui/native/linux/build.sh` exits **1**
> ("Unsupported Linux architecture: armv7l"), this fork's version prints a skip notice and exits **0**.
> Everything after that gate (a full TypeScript monorepo build on a 921 MiB board) is untested.

This branch ships three scripts tested against real hardware and a self-test (`scripts/pi2-armv7/`):

```sh
scripts/pi2-armv7/install-pi-on-pi2.sh              # on the Pi: gates -> install -> verify -> measure
scripts/pi2-armv7/install-pi-on-pi2.sh --dry-run    # print the steps, change nothing
scripts/pi2-armv7/install-pi-on-pi2.sh --check-only # inspect the current state, install nothing
scripts/pi2-armv7/pi2-pi-agent.sh probe|install|verify|all   # drive the board over SSH from a PC
scripts/pi2-armv7/selftest.sh                       # the tools' own self-test (negative paths included)
```

They are deliberately **fail-closed**: not `armv7l`, running as root, Node that is not v22, an
ARMv7-specific prebuild appearing, any non-v22 Node trace in the log, or any failing step — each is
refused explicitly with a non-zero exit status.

## 4. What this fork changes

**Running the CLI needs no code change at all** (the hardware result above is the proof). The two
changes below only keep "build from source on armv7" and "a real ARMv7 native helper, if someone builds
one" from being blocked; both carry the reason in a comment:

| File | Change | Why |
| --- | --- | --- |
| `packages/tui/native/linux/build.sh` | for `armv7l`/`armv6l` print an explicit notice and **exit 0** (compile nothing) | the original `case` only knew `x86_64`/`aarch64` and `exit 1` for everything else, so `npm run build` failed on a Pi 2. ARMv7 has no prebuild and the loader never requests one, so an explicit skip is correct where "fail the whole workspace build" is not |
| `packages/tui/src/native-platform.ts` | the loader's architecture check also accepts `arm` | so an operator who **compiles an ARMv7 helper locally** can actually use it; with no helper the behaviour is unchanged (the `require` throws and the function returns `undefined`). Note: the npm package ships prebuilt JS, so this only takes effect after a **rebuild** |

Neither change affects x64/arm64 behaviour.

## 5. Undo

```sh
# remove only the pi part (~/.local may be shared with other tools, e.g. hermes on the same board)
rm -rf ~/.local/lib/node_modules/@earendil-works ~/.local/bin/pi
rm -rf ~/opt/node22 ~/opt/node-v22.23.2-linux-armv7l
```

## 6. Reproducing this verification

```sh
scripts/pi2-armv7/selftest.sh                                   # tool self-test (on the PC, board untouched)
scripts/pi2-armv7/pi2-pi-agent.sh all                            # probe -> install -> verify
scripts/pi2-armv7/pi2-pi-agent.sh verify docs/armv7-pi2b-verification.md
```

## 7. Notes and failure modes this work caught

- **The two real bugs found during installation were caught by the gates, not afterwards.** The
  official Node tarball extracts into a directory that keeps the `v` prefix
  (`node-v22.23.2-linux-armv7l`); and the first version of the acceptance criterion said
  "`node_modules` must contain no `.node` at all", which is wrong — the package legitimately ships
  other platforms' prebuilds. The correct invariant is "**no ARMv7-specific prebuild** exists *and* the
  CLI starts".
- **Package metadata was re-checked before restating the claim for 0.87.1**: still no `os`/`cpu`
  restriction, and `pi-tui` still ships exactly six prebuilds (x64/arm64 for darwin/linux/win32) with no
  `linux-arm`.
- **The upstream sync does not touch the ARMv7 work**: after merging upstream `898ab8040` (v0.87.1), the
  nine ARMv7 files are byte-identical, and the merged tree's only difference from upstream is exactly
  that ARMv7 delta.

---

## 中文摘要（Chinese summary）

**結論：可以跑，已在實體 Pi2B 上量測通過（11/11），不需要改動 agent 程式碼。** 唯一功能減損是 TUI 的原生
X11／剪貼簿 helper（x64/arm64 才有預編譯），armv7 上由載入器跳過、走命令列 fallback。本分支只加了兩處
「使能」修改，讓 armv7 上從原始碼建置不會整包失敗。完整中文說明見 [`armv7-pi2b.md`](armv7-pi2b.md)。
