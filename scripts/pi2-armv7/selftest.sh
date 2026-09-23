#!/bin/bash
# selftest.sh - run on the PC. Verifies the refusal paths and the verifier without touching the Pi2
# and without changing anything on this machine.
#
# What it proves:
#   1. the installer REFUSES to run on a non-armv7 host (this PC is x86_64)
#   2. --dry-run changes nothing (no ~/opt/node22 created, no npm prefix created)
#   3. the probe does not claim success when the board is unreachable
#   4. the verifier passes a good log and FAILS a log with a violation
#      (a v24 Node, a stray .node, a root run - the "should not happen" cases)
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
INSTALLER="$HERE/install-pi-on-pi2.sh"
DRIVER="$HERE/pi2-pi-agent.sh"
TMP="$(mktemp -d)"
PASS=0; FAIL=0

check() { # name expected_exit actual_exit
  if [ "$2" = "$3" ]; then printf '  ✓ %s\n' "$1"; PASS=$((PASS+1));
  else printf '  ✗ %s（預期 exit %s，實際 %s）\n' "$1" "$2" "$3"; FAIL=$((FAIL+1)); fi
}

echo "=== 1) 安裝腳本在非 armv7 主機上必須拒絕"
OUT=$("$INSTALLER" 2>&1); RC=$?
echo "$OUT" | grep -q "預期 armv7l" && CHECK_HIT="有" || CHECK_HIT="沒有"
check "exit 非 0" 1 "$([ "$RC" -ne 0 ] && echo 1 || echo 0)"
check "訊息說明是架構不符（$CHECK_HIT）" "有" "$CHECK_HIT"

echo
echo "=== 2) --dry-run 不得改動任何東西（用放寬架構檢查的副本測）"
BEFORE=$(ls -1 "$HOME/opt" 2>/dev/null | sort | md5sum; ls -1 "$HOME/.local/bin" 2>/dev/null | sort | md5sum)
python3 - "$INSTALLER" "$TMP/relaxed.sh" <<'PY'
import sys, io
src = io.open(sys.argv[1], encoding="utf-8").read()
gate = '[ "$ARCH" = "armv7l" ] || fail "預期 armv7l（Pi2B），實際 $ARCH → 拒絕執行（這支腳本只能在 Pi2B 上跑）"'
assert gate in src, "找不到架構關卡那行，測試無法放寬（請更新測試）"
io.open(sys.argv[2], "w", encoding="utf-8").write(src.replace(gate, 'true'))
PY
chmod +x "$TMP/relaxed.sh"
OUT2=$("$TMP/relaxed.sh" --dry-run 2>&1); RC2=$?
AFTER=$(ls -1 "$HOME/opt" 2>/dev/null | sort | md5sum; ls -1 "$HOME/.local/bin" 2>/dev/null | sort | md5sum)
check "dry-run 正常結束" 0 "$RC2"
check "dry-run 有印出 [dry-run]" "有" "$(echo "$OUT2" | grep -q '\[dry-run\]' && echo 有 || echo 沒有)"
check "dry-run 前後 ~/opt 與 ~/.local/bin 不變" "$BEFORE" "$AFTER"

echo
echo "=== 3) HOST 必填，且連不上時不得宣稱成功"
OUT3=$("$DRIVER" probe 2>&1); RC3=$?
check "未設 HOST → 非 0" 1 "$([ "$RC3" -ne 0 ] && echo 1 || echo 0)"
check "明確要求設定 HOST" "有" "$(echo "$OUT3" | grep -qi 'set HOST' && echo 有 || echo 沒有)"
OUT4=$(HOST=pi2@example.invalid "$DRIVER" probe 2>&1); RC4=$?
check "連不通的主機 → 非 0" 1 "$([ "$RC4" -ne 0 ] && echo 1 || echo 0)"
check "說明連不上（不得假成功）" "有" "$(echo "$OUT4" | grep -q '連不上' && echo 有 || echo 沒有)"

echo "=== 4) 驗收器：好的記錄要過、壞的記錄必須被擋"
cat > "$TMP/good.log" <<'EOF'
=== 0) 基本環境
  ✓ 架構是 armv7l（Pi2B）
  ✓ 以一般使用者執行（uid 1000），全程安裝到 $HOME，不需要 sudo
=== 1) Node 22 armv7l（官方 tarball，不使用 NodeSource／不用 v23+）
  ✓ Node v22.23.2 ✓（armv7 官方建置線）
  ✓ node:sqlite 可用（session backend 不需要原生模組）
=== 2) 安裝 pi coding agent（用 npm 套件，不用官方 arm64/x64 tarball）
  ✓ 已安裝 @earendil-works/pi-coding-agent@0.87.1 到 /home/pi/.local
=== 3) 驗收（可量測的項目）
  ✓ pi 執行檔存在：/home/pi/.local/bin/pi
    pi --version → 0.87.1
  ✓ 沒有 linux-platform-x11.node（armv7 上預期如此，載入器會跳過）
  ✓ node_modules 內沒有任何 .node（純 JS + wasm，符合 armv7 可跑）
EOF
"$DRIVER" verify "$TMP/good.log" >/dev/null 2>&1
check "好記錄 → exit 0" 0 "$?"

for case_name in "v24 的 Node:Node v24.1.0" "跑出 .node:意外發現原生 .node：/x/y.node" "以 root 執行:以 root 身分執行中"; do
  label="${case_name%%:*}"; inject="${case_name#*:}"
  sed "s|^  ✓ 架構是 armv7l（Pi2B）|  ✓ 架構是 armv7l（Pi2B）\n  $inject|" "$TMP/good.log" > "$TMP/bad.log"
  "$DRIVER" verify "$TMP/bad.log" >/dev/null 2>&1
  check "壞記錄（$label）→ 非 0" 1 "$([ $? -ne 0 ] && echo 1 || echo 0)"
done

echo
printf '結果： %d 通過 / %d 失敗\n' "$PASS" "$FAIL"
rm -rf "$TMP"
[ "$FAIL" = 0 ] || exit 1
echo "✅ 自我測試全數通過（負向路徑都正確擋下）"
