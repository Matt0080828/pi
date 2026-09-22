# ARMv7 / Pi 2B verification output

> **Note:** the paths below were redacted (`/home/<user>` instead of the real home directory)
> before publication. Nothing else was altered - the order and every number are as they came
> off the board.

Raw output of `scripts/pi2-armv7/install-pi-on-pi2.sh --check-only` on the Pi 2B, 2026-09-22:

```text

=== 0) 基本環境
    uname -m = armv7l  |  Raspbian GNU/Linux 13 (trixie)
    mem: 921 MiB total, 628 MiB available
    disk $HOME: 6.4G free
  ✓ 架構是 armv7l（Pi2B）
  ✓ 以一般使用者執行（uid 1000），全程安裝到 $HOME，不需要 sudo
  ✓ 下載工具：curl

=== 1) Node 22 armv7l（官方 tarball，不使用 NodeSource／不用 v23+）
  ✓ 已有 /home/<user>/opt/node22/bin/node：v22.23.2
  ✓ Node v22.23.2 ✓（armv7 官方建置線）
  ✓ node:sqlite 可用（session backend 不需要原生模組）

=== 2) 安裝 pi coding agent（用 npm 套件，不用官方 arm64/x64 tarball）
    npm 10.9.8  |  目標 prefix: /home/<user>/.local
    [check-only] 略過 npm install

=== 3) 驗收（可量測的項目）
  ✓ pi 執行檔存在：/home/<user>/.local/bin/pi
    pi --version → 0.87.0
    pi --help   → pi - AI coding assistant with read, bash, edit, write tools  Usage: 
  套件內附的 prebuild（其他平台，armv7 不會載入）：
    @earendil-works/pi-coding-agent/node_modules/@earendil-works/pi-tui/native/darwin/prebuilds/darwin-arm64/darwin-platform.node
    @earendil-works/pi-coding-agent/node_modules/@earendil-works/pi-tui/native/darwin/prebuilds/darwin-x64/darwin-platform.node
    @earendil-works/pi-coding-agent/node_modules/@earendil-works/pi-tui/native/linux/prebuilds/linux-arm64/linux-platform-x11.node
    @earendil-works/pi-coding-agent/node_modules/@earendil-works/pi-tui/native/linux/prebuilds/linux-x64/linux-platform-x11.node
    @earendil-works/pi-coding-agent/node_modules/@earendil-works/pi-tui/native/win32/prebuilds/win32-arm64/win32-platform.node
    @earendil-works/pi-coding-agent/node_modules/@earendil-works/pi-tui/native/win32/prebuilds/win32-x64/win32-platform.node
  ✓ 沒有 linux-arm（armv7）的 prebuild（armv7 走 JS 路徑 ✓）
  ✓ （真正的證明：pi --version 已在上面正常輸出 ✓）

=== 4) 量測（給日後比對用）
    pi --version 耗時 5.13 s
    node RSS 基準: 40 MiB
    磁碟：Node 187M｜pi 套件 156M（注意：/home/<user>/.local 可能與其他工具共用，勿整包刪）

=== 5) 接下來（可選，需要你的 API key 或本機端點）
    export PATH="/home/<user>/opt/node22/bin:/home/<user>/.local/bin:$PATH"     # 加進 ~/.bashrc 才會持久
    pi --version
    # 真實回合（需要金鑰；或指向本機 OpenAI 相容端點，例：LM Studio）
    OPENAI_API_KEY=... pi "hello"

完成。記錄檔請用 --check-only 重跑輸出存證。
```
