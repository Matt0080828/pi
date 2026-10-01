# ARMv7 / Pi 2B 検証 — 日本語ガイド

> 言語／Language：[繁體中文](armv7-pi2b-verification.md) ｜ [English](armv7-pi2b-verification.en.md) ｜ [简体中文](armv7-pi2b-verification.zh-CN.md) ｜ **日本語** ｜ [한국어](armv7-pi2b-verification.ko.md) ｜ [Español](armv7-pi2b-verification.es.md)

このファイルは [`armv7-pi2b-verification.md`](armv7-pi2b-verification.md) にある**実機の生ログ**の
日本語ガイドです。生ログこそが証拠であり、逐語のまま保持します（インストールスクリプトの出力自体が
中国語で、書き換えると記録としての価値が失われるため）。以下は説明と対照訳で、両者が食い違う場合は
生ログが優先します。

- ボード：Raspberry Pi 2 Model B（armv7l、921 MiB RAM）、Raspbian GNU/Linux 13 (trixie)
- サイクル：2026-10-01、`@earendil-works/pi-coding-agent@0.99.2` をインストール
- コマンド：`scripts/pi2-armv7/pi2-pi-agent.sh all`（probe → install → verify）を PC から SSH 経由で実行
- 結果：**受け入れ検査 11/11 合格**、`verify` は exit 0

## ログの各ブロックの意味

| ログのブロック | 内容 |
| --- | --- |
| `=== 0) 基本環境` | 環境：`uname -m = armv7l`、Raspbian 13 (trixie)、921 MiB 中 734 MiB 空き、`$HOME` に 5.8 GB の空き。続いて 3 つのゲートを通過：アーキテクチャは armv7l、一般ユーザー（uid 1000）で実行し `$HOME` にのみインストール、ダウンローダ（`curl`）がある。 |
| `=== 1) Node 22 armv7l` | Node v22.23.2 が既にあり（`/home/<user>/opt/node22/bin/node`、公式 armv7l ビルド系列）、`node:sqlite` も利用可能 → セッション backend にネイティブモジュール不要。 |
| `=== 2) 安裝 pi coding agent` | npm 10.9.8 で公式パッケージを `/home/<user>/.local` に導入：`added 122 packages in 2m`。`node-domexception@1.0.0` の非推奨警告が 1 件出ますが上流依存で無害です。 |
| `=== 3) 驗收（可量測的項目）` | 実行ファイルが存在し **`pi --version` が 0.99.2 を出力**、`pi --help` も正常。同梱の 6 つのプリビルドが列挙され、すべて x64/arm64（darwin/linux/win32）—— **`linux-arm` は無い**ため、このボードではネイティブは一切読み込まれません。本当の証拠は上の `pi --version` が成功している点です。 |
| `=== 4) 量測（給日後比對用）` | 後日比較用の計測：`pi --version` 4.89 秒、`node` 基準 RSS 39 MiB、Node 187 MB、pi パッケージ 168 MB。 |
| `=== 5) 接下來（可選）` | PATH を `~/.bashrc` に書いて永続化する方法と、実際のモデル 1 ターンの実行方法（キー、または自前のローカルモデルサーバーが必要——0.99.2 の内蔵ローカル経路は `LLAMA_BASE_URL` で指す llama.cpp router で、LM Studio の OpenAI 互換 API ではありません）。 |
| `完成。記錄檔請用 --check-only 重跑輸出存證。` | インストール実行の最終行（「完了。記録を残すには `--check-only` で再実行して出力を保存してください」）。 |

## 受け入れ検査（`pi2-pi-agent.sh verify`）の対応表

検証器はログをパターン照合し、1 つでも不一致なら fail-closed です（`✓` = 存在必須、`✗` = 存在禁止）：

| 結果 | ログ上のマーカー | 意味 |
| --- | --- | --- |
| ✓ | `架構是 armv7l` | armv7l（Pi 2B）で実行された |
| ✓ | `以一般使用者執行` | 一般ユーザーで実行（root でない） |
| ✓ | `Node v22\.` | Node は v22 系 |
| ✓ | `node:sqlite 可用` | 内蔵 SQLite セッション backend が使える |
| ✓ | `pi 執行檔存在` | `pi` 実行ファイルが存在する |
| ✓ | `pi --version → v?\d` | `pi --version` が出力を返した |
| ✗ | `prebuilds/linux-arm/` | armv7 専用プリビルドが現れなかった |
| ✗ | `以 root 身分執行中` | root で実行されていない |
| ✗ | `Node v(?!22\.)\d` | ログに v22 以外の Node の痕跡がない |
| ✗ | `意外發現原生 .node` | 想定外のネイティブ `.node` が出ていない |
| ✗ | `中止（fail-closed）` | 中止した手順がない |

## 独立した再計測（同じボード、0.99.2）

インストール後に `pi --version` をさらに 3 回実行し、その時点の状態も取得：

```text
  run1: 5.04 s (0.99.2)
  run2: 4.99 s (0.99.2)
  run3: 4.80 s (0.99.2)
  node RSS: 39 MiB
  free: 725 MiB available
  disk HOME: 5.6G
```

## その他の板上の証拠（いずれも実測、記録は別ファイル）

- 導入済みのローダーはこのアーキテクチャではネイティブ helper を渡しません——0.99.2 で実測：
  `process.arch = arm` で `getNativeClipboard()` と `getNativePlatformHelper()` はどちらも
  `undefined`（ドキュメント記載のコマンドライン fallback）。
- ソースビルドのゲートは記載どおりに動作：上流の `packages/tui/native/linux/build.sh` は armv7l で
  **1** で終了（`Unsupported Linux architecture: armv7l`）、この fork の版はスキップメッセージを
  出して **0** で終了。ボード上での**ソースからの全ビルド**は依然として未検証です。

完全な手順書は [`armv7-pi2b.ja.md`](armv7-pi2b.ja.md)、繁体字版は [`armv7-pi2b.md`](armv7-pi2b.md)。
