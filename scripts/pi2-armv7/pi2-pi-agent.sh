#!/bin/bash
# pi2-pi-agent.sh - drive the `pi` agent install/verification on the Pi2B from this PC.
#
#   ./pi2-pi-agent.sh probe     # is the board reachable? (never claims success if it is not)
#   ./pi2-pi-agent.sh install   # copy the installer over and run it, keep the log here
#   ./pi2-pi-agent.sh verify    # judge the newest log against the acceptance criteria (fail-closed)
#   ./pi2-pi-agent.sh all       # probe + install + verify
#
# The Pi2 has no sudo and lives at pi2@192.168.50.90 (SSH key auth). This script never installs
# anything with root and never treats "unreachable" as success.
set -u

HOST="${HOST:-pi2@192.168.50.90}"
HERE="$(cd "$(dirname "$0")" && pwd)"
INSTALLER="$HERE/install-pi-on-pi2.sh"
LOGDIR="$HERE/logs"
SSH="ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new"

mkdir -p "$LOGDIR"

usage() { sed -n '2,12p' "$0"; exit 2; }

probe() {
  echo "=== 探測 $HOST"
  if ! timeout 25 $SSH "$HOST" 'true' 2>/dev/null; then
    echo "  ✗ 連不上（關機或不在區網）→ 不進行任何後續動作"
    return 1
  fi
  timeout 60 $SSH "$HOST" '
    echo "  ✓ 已連線: $(hostname)  $(uname -m)  $( (. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME") || echo "?" )"
    echo "    node: $(command -v node >/dev/null 2>&1 && node -v || echo "（未安裝）")"
    echo "    npm : $(command -v npm  >/dev/null 2>&1 && npm -v  || echo "（未安裝）")"
    echo "    pi  : $(command -v pi   >/dev/null 2>&1 && pi --version 2>&1 | head -1 || echo "（未安裝）")"
    echo "    mem : $(free -m | awk "/^Mem:/{print \$2\" MiB total, \"\$7\" MiB available\"}")"
    echo "    disk: $(df -h $HOME | awk "NR==2{print \$4\" free at \$HOME\"}")"
  '
}

install() {
  probe || return 1
  echo
  # The board's own download of Node is slow, so fetch the tarball here and push it over.
  CACHE="$HERE/cache"
  TB="node-v${NODE_VER:-22.23.2}-linux-armv7l.tar.xz"
  URL="https://nodejs.org/dist/v${NODE_VER:-22.23.2}/$TB"
  mkdir -p "$CACHE"
  if [ ! -s "$CACHE/$TB" ]; then
    echo "=== 在 PC 取得 Node tarball（之後 scp 給 Pi2）"
    if command -v curl >/dev/null 2>&1; then
      curl -fsSL -o "$CACHE/$TB" "$URL" || { echo "  ✗ 下載失敗 $URL"; return 1; }
    else
      echo "  ✗ 本機沒有 curl，無法預抓（Pi2 需自行下載）"
    fi
  fi
  [ -s "$CACHE/$TB" ] && echo "  ✓ tarball: $CACHE/$TB（$(stat -c%s "$CACHE/$TB") bytes）"

  echo "=== 傳腳本與 tarball 過去並執行（在 Pi2 上跑，全部安裝到 \$HOME）"
  timeout 60 $SSH "$HOST" 'cat > /tmp/install-pi-on-pi2.sh && chmod +x /tmp/install-pi-on-pi2.sh' < "$INSTALLER" \
    || { echo "  ✗ 傳腳本失敗"; return 1; }
  if [ -s "$CACHE/$TB" ]; then
    timeout 900 scp -o BatchMode=yes -o ConnectTimeout=10 "$CACHE/$TB" "$HOST:/tmp/$TB" \
      || echo "  ⚠ scp tarball 失敗 → Pi2 會自己下載"
  fi
  LOG="$LOGDIR/install-$(date +%Y%m%d-%H%M%S).log"
  # generous: npm install over a Pi2's link is slow
  timeout 3000 $SSH "$HOST" "NODE_TARBALL=/tmp/$TB bash /tmp/install-pi-on-pi2.sh" 2>&1 | tee "$LOG"
  echo
  echo "  記錄寫入 $LOG"
  ln -sf "$(basename "$LOG")" "$LOGDIR/latest.log"
}

verify() {
  LOG="${1:-$LOGDIR/latest.log}"
  [ -r "$LOG" ] || { echo "  ✗ 找不到記錄 $LOG（先跑 install）"; return 1; }
  echo "=== 驗收：$LOG"
  python3 - "$LOG" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding="utf-8", errors="replace").read()
checks = [
    ("架構是 armv7l",              "架構是 armv7l（Pi2B）",                     True),
    ("以一般使用者執行（非 root）",  "以一般使用者執行",                          True),
    ("Node 是 v22 系列",           r"Node v22\.",                               True),
    ("node:sqlite 可用",           "node:sqlite 可用",                          True),
    ("pi 執行檔存在",              "pi 執行檔存在",                             True),
    ("pi --version 有輸出",        r"pi --version → v?\d",                      True),
    ("沒有 armv7 專屬的 prebuild",  r"prebuilds/linux-arm/",                     False),
    ("沒有以 root 身分執行",       "以 root 身分執行中",                        False),
    ("沒有任何非 v22 的 Node 痕跡", r"Node v(?!22\.)\d",                        False),
    ("沒有意外出現 .node",         "意外發現原生 .node",                        False),
    ("沒有中止（fail-closed）",    "中止（fail-closed）",                       False),
]
bad = 0
for name, pat, want in checks:
    hit = re.search(pat, s) is not None
    good = hit == want
    print("  %s %s%s" % ("✓" if good else "✗", name,
                         "" if good else ("（缺少這行）" if want else "（不該出現卻出現了）")))
    bad += 0 if good else 1
print()
if bad:
    print("✗ %d 項不符 → 視為未通過（fail-closed）" % bad)
    sys.exit(1)
print("✅ 全部驗收項目通過（實機量測，非推論）")
PY
}

case "${1:-}" in
  probe)   probe ;;
  install) install ;;
  verify)  verify "${2:-}" ;;
  all)     probe && install && verify ;;
  *)       usage ;;
esac
