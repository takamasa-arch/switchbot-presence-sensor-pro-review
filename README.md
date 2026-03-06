# DIGILINE

DIGILINE は、ガジェットブログ記事の下書き・画像・記事作成スキル・WordPress 投稿補助設定をまとめて管理するリポジトリです。

記事本体は `articles/` 配下に置く前提です。1 記事につき 1 ディレクトリを作り、その中に Markdown 本文と記事用画像をまとめます。

## ディレクトリ構成

```text
.
├── .agents/
│   ├── PLANS.md
│   └── skills/
├── .devcontainer/
├── articles/
│   └── <article-slug>/
│       ├── <article-slug>.md
│       └── image files...
├── tests/
├── .env.example
├── AGENTS.md
└── Makefile
```

## 記事の置き方

- 記事は `articles/<article-slug>/` に配置する
- 本文ファイルは基本的に `articles/<article-slug>/<article-slug>.md`
- 画像も同じディレクトリにまとめる

例:

```text
articles/switchbot-presence-sensor-pro-review/
├── switchbot-presence-sensor-pro-review.md
├── switchbot-presence-sensor-pro-01.jpg
└── switchbot-presence-sensor-pro-02.jpg
```

## 使うスキル

- `.agents/skills/gadget-blog-article-best-practices/`
  ガジェット記事の構成、トーン、比較軸、買うべき人 / 見送る人の書き分けを揃えるためのスキルです。
- `.agents/skills/wordpress-draft-publisher/`
  WordPress REST API に下書き投稿するためのスキルです。

## よく使うコマンド

```bash
make dev
make lint
make test
```

- `make dev`: 利用可能なスキル一覧を表示
- `make lint`: テストファイルの構文チェック
- `make test`: リポジトリの軽量テストを実行

## 環境変数

WordPress 投稿を使う場合は `.env.example` をもとに `.env` を用意します。

主な変数:

- `WP_BASE`
- `WP_USER`
- `WP_APP_PASS`
- `POST_TITLE`
- `POST_SLUG`
- `ARTICLE_MD`
- `FEATURED_IMAGE`
- `YOUTUBE_CLIENT_SECRETS`
- `YOUTUBE_TOKEN_FILE`
- `YOUTUBE_PRIVACY`

## 運用メモ

- `.env` はコミットしない
- 記事作成時は、結論先出し・実体験起点・生活上の変化を重視する
- 大きめの変更は `.agents/PLANS.md` の ExecPlan 方針に従う
