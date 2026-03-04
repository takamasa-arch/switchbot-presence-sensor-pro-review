# wordpress-draft-publisher

目的: WordPress REST API を使って、記事本文と画像を下書き投稿として一括登録する。

## 使う場面
- 「WordPressに下書きをAPIで上げたい」
- 「アイキャッチ画像と本文内画像を、指定位置で差し込みたい」
- 「Markdown記事をWordPress向けHTML（h2/h3/h4, p, ul/li, figure）へ変換して投稿したい」

## 前提
- WordPress 側で Application Password を発行済み
- `jq` / `python3` が使える
- 投稿先が `https://example.com/wp-json/wp/v2` で到達可能

## 入力
- 記事Markdown: `switchbot-presence-sensor-pro-review.md`
- 画像: `switchbot-presence-sensor-pro-*.jpg/png`

## 実行手順
1. `.env.example` を `.env` にコピーして値を設定
2. スクリプトを実行

```bash
cp .env.example .env
# .env を編集して WP_USER / WP_APP_PASS を設定

bash .agents/skills/wordpress-draft-publisher/scripts/wp_draft_upload.sh
```

## HTML変換ルール
- 見出し: `##` → `<h2>`, `###` → `<h3>`, `####` → `<h4>`
- 箇条書き: `- ` を `<ul><li>..</li></ul>`
- 通常文: `<p>..</p>`
- 表: Markdown表を `<figure class="wp-block-table">...` に変換
- 画像: 差し込み位置で以下形式を生成

```html
<figure class="wp-block-image size-full"><img src="https://simple-was-best.com/wp-content/uploads/2026/02/IMG_1993.jpg" alt="xxxxxx" class="wp-image-31220"/></figure>
```

## 差し込み位置の指定
`IMAGE_INSERT_MAP` にJSONで「H2見出し => 画像ファイル名」を指定すると、そのH2直下に画像を入れる。

例:
```bash
export IMAGE_INSERT_MAP='{"なぜ注目したか: 書斎で集中していると照明が消えることがあった":"switchbot-presence-sensor-pro-01.jpg","比較表（旧製品・競合・電池持ち）":"switchbot-presence-sensor-pro-05.png"}'
```

`IMAGE_ALT_MAP` でファイルごとのalt文言も指定可能。

## 出力
- WordPress の `draft` 投稿1件
- 画像メディア登録（重複は都度新規）
- 実行ログに `post_id` / `link` を表示

## 注意
- 本スクリプトは投稿を新規作成する（更新ではない）
- 公開はしない（`status=draft` 固定）
- `.env` はGit除外し、`.env.example` のみコミットする
