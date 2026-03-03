# wordpress-draft-publisher

目的: WordPress REST API を使って、記事本文と画像を下書き投稿として一括登録する。

## 使う場面
- 「WordPressに下書きをAPIで上げたい」
- 「アイキャッチ画像と本文内画像をまとめてアップロードしたい」
- 「ローカルMarkdownから下書きを作りたい」

## 前提
- WordPress 側で Application Password を発行済み
- `jq` が使える
- 投稿先が `https://example.com/wp-json/wp/v2` で到達可能

## 入力
- 記事Markdown: `switchbot-presence-sensor-pro-review.md`
- 画像: `switchbot-presence-sensor-pro-*.jpg/png`

## 実行手順
1. 環境変数を設定
2. スクリプトを実行

```bash
export WP_BASE="https://your-site.com/wp-json/wp/v2"
export WP_USER="your_wp_user"
export WP_APP_PASS="xxxx xxxx xxxx xxxx xxxx xxxx"

# 任意（未指定時のデフォルトあり）
export POST_TITLE="【実機レビュー】SwitchBot人感センサーPro"
export POST_SLUG="switchbot-presence-sensor-pro-review"
export FEATURED_IMAGE="switchbot-presence-sensor-pro-06.jpg"

bash .agents/skills/wordpress-draft-publisher/scripts/wp_draft_upload.sh
```

## 出力
- WordPress の `draft` 投稿1件
- 画像メディア登録（重複は都度新規）
- 実行ログに `post_id` / `edit_url` を表示

## 注意
- 本スクリプトは投稿を新規作成する（更新ではない）
- 画像URLはアップロード後の `source_url` を本文末に一覧として追記
- 公開はしない（`status=draft` 固定）
