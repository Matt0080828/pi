# 在 Raspberry Pi 2 Model B（ARMv7）上跑 pi

**結論：可以跑，已在實體 Pi2B 上量測通過。** 不需要改動 agent 的任何程式碼——
用**官方 npm 套件**安裝即可；本分支另外補了兩個讓「從原始碼建置」與「未來的 armv7 原生 helper」不會卡住的
小修改（見下方「本分支的修改」）。

- 目標板：Raspberry Pi 2 Model B（armv7l, 4×900 MHz, 921 MiB RAM），Raspbian GNU/Linux 13 (trixie)
- 實測日期：**2026-09-23（`@earendil-works/pi-coding-agent@0.87.1`）**｜前一輪 2026-09-22 為 0.87.0
- 原始記錄：[`armv7-pi2b-verification.md`](armv7-pi2b-verification.md)
- English version of this manual: [`armv7-pi2b.en.md`](armv7-pi2b.en.md)
- 證據是**實機量測**，不是靜態推論：驗收 11/11 通過

---

## 1. 三個決定性事實

| 事實 | 證據 |
| --- | --- |
| **Node 22 有官方 armv7l 建置，Node 23+ 沒有** | `nodejs.org/dist/index.json`：v22 全 **35/35** 版含 `linux-armv7l`（含 ≥ 22.19 的 11 版，最新 v22.23.2）；最近 12 個版本（v23+）皆無。本 repo 要求 `engines.node >= 22.19.0` → **只能在 v22 線滿足** |
| **官方預編譯二進位不含 armv7** | release 資產只有 `linux-x64`／`linux-arm64`／`darwin-x64|arm64`／`windows-x64|arm64`，`build-binaries.yml` 的平台判斷同樣只列這四個 → 官方 tarball **不可用** |
| **npm 套件路線沒有原生障礙** | `@earendil-works/pi-coding-agent`：無 `os`/`cpu` 限制、已含預打包 CLI（`dist/bundle/*.js`）、依賴為純 JS 或 wasm（`photon-node` 內含 `photon_rs_bg.wasm`）、`canvas` 只在 `devDependencies`、session backend 用 Node 內建 `node:sqlite` |

唯一的功能減損：TUI 的原生 X11／剪貼簿 helper（`linux-platform-x11.node`）只有 x64/arm64 prebuild，
且載入器 `packages/tui/src/native-platform.ts` 會對其他架構直接回 `undefined`。
`packages/tui/native/linux/README.md` 自己寫明「Coding-agent falls back to command-line tools when
native reads are unavailable」——所以 armv7 上這是**設計允許的降級**，不會崩，只是少了剪貼簿／圖片整合。

## 2. 實機量測結果

| 檢查 | 實測值 |
| --- | --- |
| 架構 | `armv7l`（Raspbian 13 trixie） |
| 身份 | uid 1000，**全程未用 sudo**（安裝到 `$HOME`） |
| Node | **v22.23.2**（官方 `linux-armv7l` tarball，26,338,176 bytes） |
| `node:sqlite` | **可用** → session backend 不需要原生模組 |
| CLI | **`pi --version` → 0.87.1**；`pi --help` 正常輸出 |
| npm 安裝 | `changed 119 packages in 3m`（npm 10.9.8） |
| 附帶 prebuild | 只有 `darwin-arm64|x64`、`linux-arm64|x64`、`win32-arm64|x64` —— **沒有 `linux-arm`（armv7）** |
| 啟動耗時 | `pi --version` **4.75–4.92 s**（Pi2B 冷啟動） |
| 記憶體 | `node` 基準 RSS **40 MiB**；安裝時整機可用 640 MiB，未 OOM |
| 磁碟 | Node 187 MB ＋ pi 套件 156 MB（`$HOME` 尚有 6.2 GB） |

> 已知限制：**CLI 本身已驗證**，但一次「真實模型回合」需要 API 金鑰或指向本機 OpenAI 相容端點
> （例如同網段的 LM Studio），本分支的驗收沒有涵蓋那一項。

## 3. 安裝與使用（適用方式）

在 Pi2B 上（**不需要 sudo**，全部裝到 `$HOME`）：

```sh
# 1) Node 22 armv7l（官方 tarball；不要用 NodeSource 或 v23+）
curl -fsSLO https://nodejs.org/dist/v22.23.2/node-v22.23.2-linux-armv7l.tar.xz
mkdir -p ~/opt && tar -xJf node-v22.23.2-linux-armv7l.tar.xz -C ~/opt
ln -sfn ~/opt/node-v22.23.2-linux-armv7l ~/opt/node22

# 2) CLI
export PATH="$HOME/opt/node22/bin:$HOME/.local/bin:$PATH"
node -v                      # v22.23.2
npm install -g --prefix ~/.local @earendil-works/pi-coding-agent
pi --version                 # 0.87.1

# 3) 持久化（加進 ~/.bashrc）
echo 'export PATH="$HOME/opt/node22/bin:$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

要從**原始碼**建置（本 repo 自己）：

```sh
git clone https://github.com/matttest0080-prog/pi.git && cd pi
npm ci && npm run build      # 這一步在 armv7 上需要本分支的 build.sh 修改（見下）
```

本分支附了三個在實機上測過的腳本（`scripts/pi2-armv7/`）：

```sh
scripts/pi2-armv7/install-pi-on-pi2.sh          # 在 Pi2 上跑：關卡 → 安裝 → 驗收 → 量測
scripts/pi2-armv7/install-pi-on-pi2.sh --dry-run    # 只印步驟，不改任何東西
scripts/pi2-armv7/install-pi-on-pi2.sh --check-only # 只檢查現況，不安裝
scripts/pi2-armv7/pi2-pi-agent.sh probe|install|verify|all   # 從 PC 遙控（SSH）
scripts/pi2-armv7/selftest.sh                   # 工具本身的自我測試（含負向路徑）
```

它們刻意 **fail-closed**：架構不是 `armv7l`、以 root 執行、Node 不是 v22、出現 armv7 專屬 prebuild、
日誌裡有任何非 v22 的 Node 痕跡、或任何一步失敗——都會明確拒絕並以非 0 結束。

## 4. 本分支的修改

**跑 CLI 不需要任何程式碼修改**（實測即證明）。以下兩處是為了讓「在 armv7 上從原始碼建置」與
「未來真的要有 armv7 原生 helper」不被擋住，屬於**可選的使能修改**，都已附原因註解：

| 檔案 | 修改 | 為什麼 |
| --- | --- | --- |
| `packages/tui/native/linux/build.sh` | 對 `armv7l`／`armv6l` 印出明確訊息後 **exit 0**（不編譯） | 原本 `case` 只認 `x86_64`／`aarch64`，其他架構直接 `exit 1` → 在 Pi2 上 `npm run build` 會失敗。armv7 沒有 prebuild、載入器也不會載入它，所以「明確跳過」比「整包建置失敗」正確 |
| `packages/tui/src/native-platform.ts` | 載入器的架構檢查多接受 `arm` | 讓**自行建好** armv7 helper 的人真的用得到它；沒有 helper 時行為與現在完全相同（`try/catch` 後回 `undefined`）。注意：npm 套件附的是預打包 JS，這個改動只有在**重新建置**後才生效 |

兩者都不影響 x64／arm64 行為。

## 5. 回復原狀

```sh
# 只移除 pi 的部分（~/.local 可能與其他工具共用，例如同一台板子上的 hermes）
rm -rf ~/.local/lib/node_modules/@earendil-works ~/.local/bin/pi
rm -rf ~/opt/node22 ~/opt/node-v22.23.2-linux-armv7l
```

## 6. 重現這份驗收

```sh
scripts/pi2-armv7/selftest.sh                                   # 工具自我測試（PC 上，不動板子）
scripts/pi2-armv7/pi2-pi-agent.sh all                            # 探測 → 安裝 → 驗收
scripts/pi2-armv7/pi2-pi-agent.sh verify docs/armv7-pi2b-verification.md
```

---

## English summary

**Yes — the CLI runs on a Raspberry Pi 2 Model B (ARMv7), verified on real hardware (11/11 checks).**
No source changes are required: install Node **v22 armv7l** (the only major with official ARMv7 builds;
v23+ have none) and the published npm package, which has no `os`/`cpu` restriction, ships a prebuilt
bundle, depends only on plain JS/wasm, and uses the built-in `node:sqlite`. The published binaries carry
**no `linux-arm` asset**, so the npm route is the only one. The TUI's native X11 helper is x64/arm64-only
and is skipped by design on other architectures (the package documents a command-line fallback), so ARMv7
loses clipboard/image integration but nothing crashes.

This branch adds two optional enabling changes — `native/linux/build.sh` no longer fails the whole build on
ARMv7 (it skips with a notice instead of `exit 1`), and the native loader also accepts `arm` so a locally
built helper would be used — plus the tested install/verify scripts in `scripts/pi2-armv7/` and the raw
hardware log in `docs/armv7-pi2b-verification.md`. Measured: `pi --version` 0.87.1, startup 4.75–4.92 s,
node RSS 40 MiB, no OOM, ~156 MB for the package.
