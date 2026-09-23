# Raspberry Pi 2 Model B（ARMv7）で pi を動かす

> 言語／Language：[繁體中文](armv7-pi2b.md) ｜ [English](armv7-pi2b.en.md) ｜ [简体中文](armv7-pi2b.zh-CN.md) ｜ **日本語** ｜ [한국어](armv7-pi2b.ko.md) ｜ [Español](armv7-pi2b.es.md)

**結論：動きます。実機の Pi2B で計測済み（受け入れ検査 11/11 合格）。** agent 側のコード変更は
一切不要で、**公式 npm パッケージ**を入れるだけです。このブランチが加えているのは 2 か所の
「有効化」用の小さな変更だけで、「armv7 でソースからビルドする」場合と「将来 armv7 用のネイティブ
helper を作る」場合がアーキテクチャで止まらないようにするためのものです（下記「このブランチの変更」）。

- 対象ボード：Raspberry Pi 2 Model B（armv7l、4×900 MHz、921 MiB RAM）、Raspbian GNU/Linux 13 (trixie)
- 計測日：**2026-09-23（`@earendil-works/pi-coding-agent@0.87.1`）**｜前回サイクルは 2026-09-22 の 0.87.0
- 生ログ：[`armv7-pi2b-verification.md`](armv7-pi2b-verification.md)（[英語ガイド](armv7-pi2b-verification.en.md)付き）
- 根拠は**実機計測**であり、机上の推論ではありません：受け入れ検査 11/11 合格

---

## 1. 決定的な 3 つの事実

| 事実 | 根拠 |
| --- | --- |
| **Node 22 には公式 armv7l ビルドがあり、Node 23 以降には無い** | `nodejs.org/dist/index.json`：v22 は **35/35** すべてのリリースが `linux-armv7l` を含む（22.19 以上の 11 版を含む、最新 v22.23.2）。直近 12 リリース（v23 以降）には無い。このリポジトリは `engines.node >= 22.19.0` を要求 → **v22 系でのみ満たせる** |
| **公式のプリビルドバイナリに armv7 は無い** | リリース資産は `linux-x64` / `linux-arm64` / `darwin-x64|arm64` / `windows-x64|arm64` のみで、`build-binaries.yml` のプラットフォーム判定も同じ 4 つだけ → 公式 tarball は**使えない** |
| **npm パッケージ経路にネイティブの障害は無い** | `@earendil-works/pi-coding-agent@0.87.1`：**`os`/`cpu` 制限なし**、ビルド済み CLI 同梱（`dist/bundle/*.js`）、依存は純 JS か wasm（`photon-node` が `photon_rs_bg.wasm` を内包）、`canvas` は `devDependencies` のみ、セッション backend は Node 内蔵の `node:sqlite` |

唯一の機能低下：TUI のネイティブ X11／クリップボード helper（`linux-platform-x11.node`）は
x64/arm64 のプリビルドしか無く、ローダー `packages/tui/src/native-platform.ts` はそれ以外の
アーキテクチャで `undefined` を返します。`packages/tui/native/linux/README.md` 自身が
"Coding-agent falls back to command-line tools when native reads are unavailable" と書いており、
armv7 ではこれが**設計上の許容された縮退**です（クラッシュはせず、クリップボード／画像連携だけが失われます）。

導入済み 0.87.1 を使った実機計測：

```text
process.arch = arm, process.platform = linux
getNativeClipboard()      -> undefined
getNativePlatformHelper() -> undefined
```

## 2. 実機での計測結果

| 検査項目 | 実測値 |
| --- | --- |
| アーキテクチャ | `armv7l`（Raspbian 13 trixie） |
| 実行ユーザー | uid 1000、**sudo は一切不使用**（`$HOME` にインストール） |
| Node | **v22.23.2**（公式 `linux-armv7l` tarball、26,338,176 bytes） |
| `node:sqlite` | **利用可** → セッション backend にネイティブモジュール不要 |
| CLI | **`pi --version` → 0.87.1**、`pi --help` も正常出力 |
| npm インストール | `changed 119 packages in 3m`（npm 10.9.8） |
| 同梱プリビルド | `darwin-arm64|x64`、`linux-arm64|x64`、`win32-arm64|x64` のみ —— **`linux-arm`（armv7）は無い** |
| 起動時間 | `pi --version` **4.75–4.92 秒**（Pi2B のコールドスタート、4 回計測） |
| メモリ | `node` の基準 RSS **40 MiB**（インストール時は空き 640 MiB、OOM なし） |
| ディスク | Node 187 MB ＋ pi パッケージ 156 MB（`$HOME` の空き 6.2 GB） |

> 既知の制限：**CLI 自体は検証済み**ですが、実際のモデル 1 ターンには API キーか、同一 LAN 上の
> LM Studio のような OpenAI 互換エンドポイントが必要で、このブランチの受け入れ検査はそこまで含みません。

## 3. インストールと使い方

Pi2B 上で（**sudo 不要**、すべて `$HOME` に入ります）：

```sh
# 1) Node 22 armv7l（公式 tarball。NodeSource や v23 以降は使わない）
curl -fsSLO https://nodejs.org/dist/v22.23.2/node-v22.23.2-linux-armv7l.tar.xz
mkdir -p ~/opt && tar -xJf node-v22.23.2-linux-armv7l.tar.xz -C ~/opt
ln -sfn ~/opt/node-v22.23.2-linux-armv7l ~/opt/node22

# 2) CLI
export PATH="$HOME/opt/node22/bin:$HOME/.local/bin:$PATH"
node -v                      # v22.23.2
npm install -g --prefix ~/.local @earendil-works/pi-coding-agent
pi --version                 # 0.87.1

# 3) 永続化（~/.bashrc に追記）
echo 'export PATH="$HOME/opt/node22/bin:$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

**ソースから**ビルドする場合（このリポジトリ自身）：

```sh
git clone https://github.com/matttest0080-prog/pi.git && cd pi
npm ci && npm run build      # armv7 では下記の build.sh 変更が必要
```

> このソースビルド経路は、ボード上で端から端まで**検証していません**。実機で計測したのは
> アーキテクチャ判定の部分そのものです：上流の `packages/tui/native/linux/build.sh` は **1** で終了
> （`Unsupported Linux architecture: armv7l`）、この fork の版はスキップのメッセージを出して **0** で終了。
> その先（921 MiB のボードで TypeScript モノレポ全体をビルド）は未検証です。

このブランチには実機で検証した 3 本のスクリプトと自己テストが付属します（`scripts/pi2-armv7/`）：

```sh
scripts/pi2-armv7/install-pi-on-pi2.sh              # Pi 側：ゲート → インストール → 検査 → 計測
scripts/pi2-armv7/install-pi-on-pi2.sh --dry-run    # 手順を表示するだけで何も変更しない
scripts/pi2-armv7/install-pi-on-pi2.sh --check-only # 現状を調べるだけでインストールしない
scripts/pi2-armv7/pi2-pi-agent.sh probe|install|verify|all   # PC から SSH 経由で操作
scripts/pi2-armv7/selftest.sh                       # ツール自身の自己テスト（負のパスも含む）
```

これらは意図的に **fail-closed** です：`armv7l` でない、root で実行、Node が v22 でない、
armv7 専用プリビルドが現れた、ログに v22 以外の Node の痕跡がある、いずれかの手順が失敗——の
いずれでも明確に拒否し、非 0 で終了します。

## 4. このブランチの変更点

**CLI を動かすのにコード変更は一切不要です**（実機の結果がその証明です）。以下の 2 か所は
「armv7 でソースからビルドする」「将来本当に armv7 ネイティブ helper を作る」場合が止まらないように
するための**任意の有効化変更**で、いずれも理由をコメントで残しています：

| ファイル | 変更 | 理由 |
| --- | --- | --- |
| `packages/tui/native/linux/build.sh` | `armv7l`／`armv6l` では明示メッセージを出して **exit 0**（コンパイルしない） | 元の `case` は `x86_64`／`aarch64` しか知らず、他は `exit 1` → Pi2 では `npm run build` が失敗する。armv7 にプリビルドは無くローダーも要求しないので、「明示的にスキップ」が「ワークスペース全体のビルド失敗」より正しい |
| `packages/tui/src/native-platform.ts` | ローダーのアーキテクチャ判定が `arm` も受け入れる | **自分でビルドした** armv7 helper を持つ人が実際に使えるようにするため。helper が無ければ挙動は従来と同一（`require` が失敗し `undefined` を返す）。注意：npm パッケージはビルド済み JS なので、この変更は**再ビルド後**にのみ効きます |

どちらも x64／arm64 の挙動には影響しません。

## 5. 元に戻す

```sh
# pi の部分だけを削除（~/.local は同じボード上の hermes など他ツールと共有している可能性がある）
rm -rf ~/.local/lib/node_modules/@earendil-works ~/.local/bin/pi
rm -rf ~/opt/node22 ~/opt/node-v22.23.2-linux-armv7l
```

## 6. この検証の再現

```sh
scripts/pi2-armv7/selftest.sh                                   # ツールの自己テスト（PC 上、ボードは触らない）
scripts/pi2-armv7/pi2-pi-agent.sh all                            # probe → install → verify
scripts/pi2-armv7/pi2-pi-agent.sh verify docs/armv7-pi2b-verification.md
```

## 7. 注意点と、この作業で踏んだ落とし穴

- **インストール中に見つかった 2 つの実バグは、いずれもゲートが止めたもので事後発見ではなかった**：
  公式 Node tarball は展開後のディレクトリ名に `v` が残る（`node-v22.23.2-linux-armv7l`。最初は `v` を
  落として失敗）。また受け入れ条件を最初「`node_modules` に `.node` を一切含めない」と書いたのは誤りで、
  パッケージは他プラットフォームのプリビルドを正当に同梱します。正しい不変条件は
  「**armv7 専用プリビルドが無い** *かつ* CLI が起動する」です。
- **0.87.1 のパッケージ メタデータも再確認済み**：`os`/`cpu` 制限なし、`pi-tui` のプリビルドは依然
  x64/arm64 の 6 つのみ（`linux-arm` なし）。
- **上流への同期は ARMv7 の作業に影響しません**：上流 `898ab8040`（v0.87.1）をマージした後も、
  ARMv7 の 9 ファイルはバイト単位で同一で、マージ後のツリーと上流の差分はちょうどその 9 ファイルだけです。
