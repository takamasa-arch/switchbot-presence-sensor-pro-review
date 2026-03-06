# DIGILINE 作業ガイド

## 概要

DIGILINE はガジェット記事の下書き・関連スキル・投稿補助ファイルを管理するリポジトリです。主な作業対象は Markdown 記事、画像、WordPress 投稿補助スクリプト、記事品質を揃えるスキル定義です。

## 主要パス

- `.agents/skills/wordpress-draft-publisher/`: WordPress 下書き投稿用スキル
- `.agents/skills/gadget-blog-article-best-practices/`: 記事執筆品質を揃えるスキル
- `articles/`: 実記事と画像の作業ディレクトリ
- `.env.example`: WordPress 投稿で使う環境変数の雛形

## よく使うコマンド

- `make test`: スキル定義と軽量テストを実行
- `make lint`: スキル Markdown とテストファイルの構文確認
- `make dev`: このリポジトリで使うスキル一覧を表示

## 環境変数

- `WP_BASE`: WordPress REST API のベース URL
- `WP_USER`: WordPress ユーザー名
- `WP_APP_PASS`: Application Password
- `POST_TITLE`, `POST_SLUG`, `ARTICLE_MD`, `FEATURED_IMAGE`: 投稿時の任意指定

## 運用メモ

- `.env` はコミットしない
- 記事作成時は、結論先出し・実体験起点・買うべき人/見送る人の明記を優先する
- 新しい大きめの作業は `.agents/PLANS.md` の ExecPlan 方針に従う
