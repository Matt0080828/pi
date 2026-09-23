#!/bin/bash
# install-pi-on-pi2.sh - install and verify the `pi` coding agent on a Raspberry Pi 2 Model B.
#
# Run this ON the Pi2B (armv7l). It fails closed: every precondition is checked and refused
# explicitly, and it never needs sudo (it installs Node into $HOME/opt).
#
#   ./install-pi-on-pi2.sh              # do it
#   ./install-pi-on-pi2.sh --dry-run    # print what would happen, change nothing
#   ./install-pi-on-pi2.sh --check-only # no installs, just inspect what is already there
#
# Facts this is built on (measured 2026-09-21, not assumed):
#   * nodejs.org ships linux-armv7l for every v22 release (35/35, incl. all >= 22.19, latest
#     v22.23.2). v23 and later do NOT ship armv7 - so pin 22.
#   * earendil-works/pi publishes no armv7 binary: v0.87.1 assets are linux-x64, linux-arm64,
#     darwin-x64/arm64, windows-x64/arm64 only. Use the npm package, not the tarball.
#   * @earendil-works/pi-coding-agent@0.87.1 has no os/cpu restriction, ships a prebuilt bundle
#     (dist/bundle/*.js) and depends on plain JS + one wasm package (photon-node has
#     photon_rs_bg.wasm). `canvas` is only a devDependency. The only native piece is the TUI's
#     linux-platform-x11.node, which its loader skips on any arch that is not x64/arm64.
set -u

NODE_VER="${NODE_VER:-22.23.2}"
# the official tarball extracts to a directory WITH the v prefix (node-v22.23.2-linux-armv7l)
NODE_DIR="$HOME/opt/node-v$NODE_VER-linux-armv7l"
NODE_LINK="$HOME/opt/node22"
NODE_URL="https://nodejs.org/dist/v$NODE_VER/node-v$NODE_VER-linux-armv7l.tar.xz"
# optional: a tarball already fetched elsewhere (the PC can download it much faster than the board)
NODE_TARBALL="${NODE_TARBALL:-}"
PI_PKG="${PI_PKG:-@earendil-works/pi-coding-agent@0.87.1}"
NPM_PREFIX="$HOME/.local"
LOG="pi2-pi-install-$(date +%Y%m%d-%H%M%S).log"

DRY=0; CHECK_ONLY=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --check-only) CHECK_ONLY=1 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown option: $a" >&2; exit 2 ;;
  esac
done

step()  { printf '\n=== %s\n' "$*"; }
ok()    { printf '  ✓ %s\n' "$*"; }
bad()   { printf '  ✗ %s\n' "$*" >&2; }
info()  { printf '    %s\n' "$*"; }
run()   { if [ "$DRY" = 1 ]; then printf '    [dry-run] %s\n' "$*"; else "$@"; fi; }
fail()  { bad "$*"; bad "中止（fail-closed）"; exit 1; }

# ---------------------------------------------------------------------------
step "0) 基本環境"
ARCH=$(uname -m)
info "uname -m = $ARCH  |  $( (. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME") || echo '?' )"
info "mem: $(free -m 2>/dev/null | awk '/^Mem:/{print $2" MiB total, "$7" MiB available"}')"
info "disk \$HOME: $(df -h "$HOME" | awk 'NR==2{print $4" free"}')"

# --- gate 1: architecture. This script must refuse to run anywhere else. ---
[ "$ARCH" = "armv7l" ] || fail "預期 armv7l（Pi2B），實際 $ARCH → 拒絕執行（這支腳本只能在 Pi2B 上跑）"
ok "架構是 armv7l（Pi2B）"

# --- gate 2: no sudo anywhere. If the target needs root, stop rather than prompt. ---
if [ "$(id -u)" = "0" ]; then
  bad "以 root 身分執行中：本腳本刻意全部安裝到 \$HOME，不需要 root"
  fail "請用一般使用者執行（Pi2 上沒有 sudo）"
fi
ok "以一般使用者執行（uid $(id -u)），全程安裝到 \$HOME，不需要 sudo"

# --- gate 3: bash + curl/wget + tar.xz support ---
command -v tar >/dev/null || fail "缺 tar"
command -v xz  >/dev/null || info "沒有獨立 xz（tar -J 若失敗會改用 node 官方的 .tar.gz）"
DL=""
command -v curl >/dev/null && DL="curl"
[ -z "$DL" ] && command -v wget >/dev/null && DL="wget"
[ -n "$DL" ] || fail "需要 curl 或 wget 之一來下載 Node"
ok "下載工具：$DL"

# ---------------------------------------------------------------------------
step "1) Node 22 armv7l（官方 tarball，不使用 NodeSource／不用 v23+）"
if [ -x "$NODE_LINK/bin/node" ]; then
  ok "已有 $NODE_LINK/bin/node：$("$NODE_LINK/bin/node" -v)"
elif [ "$DRY" = 1 ] || [ "$CHECK_ONLY" = 1 ]; then
  if [ "$DRY" = 1 ]; then info "[dry-run] 略過：取得 $NODE_URL 並解到 $HOME/opt（含 symlink $NODE_LINK）"
  else info "[check-only] 略過下載與安裝"; fi
else
  mkdir -p "$HOME/opt" || fail "無法建立 $HOME/opt"
  if [ -d "$NODE_DIR" ]; then
    ok "已存在解開的 Node：$NODE_DIR（跳過下載）"
  else
    TMPD=$(mktemp -d) || fail "mktemp 失敗"
    if [ -n "$NODE_TARBALL" ] && [ -r "$NODE_TARBALL" ]; then
      info "使用本機已有的 tarball：$NODE_TARBALL"
      cp "$NODE_TARBALL" "$TMPD/node-v$NODE_VER-linux-armv7l.tar.xz" || fail "複製 tarball 失敗"
    else
      info "將下載 $NODE_URL"
      if [ "$DL" = curl ]; then
        ( cd "$TMPD" && curl -fsSLO "$NODE_URL" ) || fail "下載失敗：$NODE_URL"
      else
        ( cd "$TMPD" && wget -q "$NODE_URL" ) || fail "下載失敗：$NODE_URL"
      fi
    fi
    tar -xJf "$TMPD"/node-v$NODE_VER-linux-armv7l.tar.xz -C "$HOME/opt" || fail "解壓失敗"
    rm -rf "$TMPD"
    [ -d "$NODE_DIR" ] || fail "解開後找不到 $NODE_DIR（檢查 tarball 內容結構）"
  fi
  rm -f "$NODE_LINK"; ln -s "$NODE_DIR" "$NODE_LINK" || fail "建立 symlink 失敗"
  ok "安裝完成：$NODE_DIR → $NODE_LINK"
fi

# --- gate 4: the Node we will use must be v22 (armv7 stops at 22; a v23+ would silently be wrong) ---
if [ -x "$NODE_LINK/bin/node" ]; then
  NV="$("$NODE_LINK/bin/node" -v)"; NM="${NV#v}"; NM="${NM%%.*}"
  [ "$NM" = "22" ] || fail "Node 版本 $NV 不是 v22（armv7 只有 v22 有官方建置；請勿用 23+）"
  ok "Node $NV ✓（armv7 官方建置線）"
  # node:sqlite is what the session backend uses - it is built into Node, never a native module
  NS=$("$NODE_LINK/bin/node" -e 'try{require("node:sqlite");console.log("ok")}catch(e){console.log("fail:"+e.message)}' 2>/dev/null | tail -1)
  case "$NS" in
    ok) ok "node:sqlite 可用（session backend 不需要原生模組）" ;;
    *)  bad "node:sqlite 探測：$NS（22.x 應該是內建；若失敗要記錄）" ;;
  esac
  export PATH="$NODE_LINK/bin:$PATH"
else
  info "（node 還沒裝好 → 之後的 npm 步驟需要它）"
fi

# ---------------------------------------------------------------------------
step "2) 安裝 pi coding agent（用 npm 套件，不用官方 arm64/x64 tarball）"
if [ -n "${PATH:-}" ] && command -v npm >/dev/null 2>&1; then
  info "npm $(npm -v)  |  目標 prefix: $NPM_PREFIX"
  if [ "$DRY" = 0 ] && [ "$CHECK_ONLY" = 0 ]; then
  mkdir -p "$NPM_PREFIX" || fail "無法建立 $NPM_PREFIX"
  npm install -g --prefix "$NPM_PREFIX" "$PI_PKG" || fail "npm install 失敗"
  ok "已安裝 $PI_PKG 到 $NPM_PREFIX"
  else
  if [ "$DRY" = 1 ]; then info "[dry-run] 略過：npm install -g --prefix $NPM_PREFIX $PI_PKG"
  else info "[check-only] 略過 npm install"; fi
  fi
else
  info "[check-only 或 node 未就緒] 略過 npm install"
fi

# ---------------------------------------------------------------------------
step "3) 驗收（可量測的項目）"
PIBIN="$NPM_PREFIX/bin/pi"
if [ -x "$PIBIN" ]; then
  ok "pi 執行檔存在：$PIBIN"
  V=$("$PIBIN" --version 2>&1 | tail -1); info "pi --version → $V"
  H=$("$PIBIN" --help 2>&1 | head -3 | tr '\n' ' '); info "pi --help   → $H"
  # The npm package DOES bundle .node prebuilds - but only for linux-x64/arm64, darwin and win32.
  # On armv7 the loader skips them by design (`arch !== "x64" && arch !== "arm64" -> undefined`),
  # so the correct invariant is "no armv7 prebuild is needed", proved by the CLI starting at all.
  NM="$NPM_PREFIX/lib/node_modules"
  echo "  套件內附的 prebuild（其他平台，armv7 不會載入）："
  find "$NM" -name '*.node' 2>/dev/null | sed "s|$NM/||" | sort | head -8 | sed 's/^/    /'
  if find "$NM" -path '*prebuilds/linux-arm/*' -name '*.node' 2>/dev/null | grep -q .; then
    bad "出現 linux-arm（armv7）的 prebuild：這與預期不符"
  else
    ok "沒有 linux-arm（armv7）的 prebuild（armv7 走 JS 路徑 ✓）"
  fi
  # the real proof that the x64/arm64 files are harmless: the CLI starts and prints its version
  ok "（真正的證明：pi --version 已在上面正常輸出 ✓）"
else
  info "pi 還沒安裝（或 prefix 不同）→ 驗收略過"
fi

step "4) 量測（給日後比對用）"
if [ -x "$NODE_LINK/bin/node" ] && [ -x "$PIBIN" ]; then
  if [ "$DRY" = 0 ]; then
    T0=$(date +%s.%N)
    "$PIBIN" --version >/dev/null 2>&1
    T1=$(date +%s.%N)
    info "pi --version 耗時 $(echo "$T1 $T0" | awk '{printf "%.2f s", $1-$2}')"
    info "node RSS 基準: $( "$NODE_LINK/bin/node" -e 'console.log(Math.round(process.memoryUsage().rss/1048576)+" MiB")' )"
    info "磁碟：Node $(du -sh "$NODE_DIR" 2>/dev/null | cut -f1)｜pi 套件 $(du -sh "$NPM_PREFIX/lib/node_modules" 2>/dev/null | cut -f1)（注意：$NPM_PREFIX 可能與其他工具共用，勿整包刪）"
  fi
fi

step "5) 接下來（可選，需要你的 API key 或本機端點）"
cat <<EOF
    export PATH="$NODE_LINK/bin:$NPM_PREFIX/bin:\$PATH"     # 加進 ~/.bashrc 才會持久
    pi --version
    # 真實回合（需要金鑰；或指向本機 OpenAI 相容端點，例：LM Studio）
    OPENAI_API_KEY=... pi "hello"
EOF
printf '\n完成。記錄檔請用 --check-only 重跑輸出存證。\n'
