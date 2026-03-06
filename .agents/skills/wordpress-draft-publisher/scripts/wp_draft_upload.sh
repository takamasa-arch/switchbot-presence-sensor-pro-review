#!/usr/bin/env bash
set -euo pipefail

# 何を: スクリプト配置ディレクトリを取得。なぜ: 補助スクリプトを相対参照せず確実に呼び出すため。
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 何を: .envファイルを自動読込。なぜ: 毎回exportせずに安全に認証情報を扱うため。
if [[ -f ".env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source ".env"
  set +a
fi

# 何を: 必須コマンドの存在を事前確認。なぜ: 途中失敗を防いで原因切り分けを容易にするため。
need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[ERROR] command not found: $1" >&2
    exit 1
  }
}

need_cmd curl
need_cmd jq
need_cmd file
need_cmd python3

# 何を: API接続設定を環境変数から受け取る。なぜ: 機密情報の直書きを避けるため。
WP_BASE="${WP_BASE:-}"
WP_USER="${WP_USER:-}"
WP_APP_PASS="${WP_APP_PASS:-}"

if [[ -z "$WP_BASE" || -z "$WP_USER" || -z "$WP_APP_PASS" ]]; then
  echo "[ERROR] WP_BASE / WP_USER / WP_APP_PASS must be set" >&2
  exit 1
fi

POST_TITLE="${POST_TITLE:-SwitchBot人感センサーPro レビュー}"
POST_SLUG="${POST_SLUG:-switchbot-presence-sensor-pro-review}"
ARTICLE_MD="${ARTICLE_MD:-switchbot-presence-sensor-pro-review.md}"
FEATURED_IMAGE="${FEATURED_IMAGE:-switchbot-presence-sensor-pro-06.jpg}"
IMAGE_GLOB_PREFIX="${IMAGE_GLOB_PREFIX:-$POST_SLUG}"

if [[ ! -f "$ARTICLE_MD" ]]; then
  echo "[ERROR] article not found: $ARTICLE_MD" >&2
  exit 1
fi

# 何を: 画像ファイルを固定順で収集。なぜ: 実行ごとの差分を減らして再現性を上げるため。
IMAGES=()
while IFS= read -r image; do
  IMAGES+=("$image")
done < <(find . -maxdepth 1 -type f \
  \( -name "${IMAGE_GLOB_PREFIX}-*.jpg" -o -name "${IMAGE_GLOB_PREFIX}-*.jpeg" -o -name "${IMAGE_GLOB_PREFIX}-*.png" \) \
  | sed 's|^./||' | sort)

if [[ ${#IMAGES[@]} -eq 0 ]]; then
  echo "[ERROR] no images found (${IMAGE_GLOB_PREFIX}-*.jpg/png)" >&2
  exit 1
fi

AUTH="${WP_USER}:${WP_APP_PASS}"

# 何を: 画像をWordPressへアップロードし、IDとURLを取得する。なぜ: アイキャッチ設定と本文参照に必要なため。
upload_image() {
  local image="$1"
  local mime
  mime="$(file --mime-type -b "$image")"

  curl -sS -u "$AUTH" \
    -X POST "${WP_BASE}/media" \
    -H "Content-Disposition: attachment; filename=\"$(basename "$image")\"" \
    -H "Content-Type: ${mime}" \
    --data-binary @"$image"
}

featured_id=""
first_uploaded_id=""
wp_media_json='[]'

for image in "${IMAGES[@]}"; do
  echo "[INFO] upload: $image"
  resp="$(upload_image "$image")"

  id="$(jq -r '.id // empty' <<<"$resp")"
  url="$(jq -r '.source_url // empty' <<<"$resp")"

  if [[ -z "$id" || -z "$url" ]]; then
    echo "[ERROR] media upload failed: $image" >&2
    echo "$resp" >&2
    exit 1
  fi

  if [[ -z "$first_uploaded_id" ]]; then
    first_uploaded_id="$id"
  fi
  if [[ "$image" == "$FEATURED_IMAGE" ]]; then
    featured_id="$id"
  fi

  # 何を: 画像メタ情報をJSON配列として保持。なぜ: HTML変換時にfigureタグへID/URLを埋め込むため。
  wp_media_json="$(jq -c \
    --arg filename "$image" \
    --arg url "$url" \
    --argjson id "$id" \
    '. + [{filename:$filename, id:$id, url:$url}]' <<<"$wp_media_json")"
done

if [[ -z "$featured_id" ]]; then
  echo "[WARN] featured image not found in upload set: $FEATURED_IMAGE" >&2
  featured_id="$first_uploaded_id"
fi

# 何を: MarkdownをWordPress向けHTMLへ変換。なぜ: 投稿時にh2/h3/h4, p, ul/li, figureの形で入稿するため。
export WP_MEDIA_JSON="$wp_media_json"
export FEATURED_IMAGE
export POST_TITLE
content_html="$(python3 "$SCRIPT_DIR/md_to_wp_html.py" "$ARTICLE_MD")"

payload="$(jq -n \
  --arg title "$POST_TITLE" \
  --arg slug "$POST_SLUG" \
  --arg content "$content_html" \
  --argjson featured "$featured_id" \
  '{
    title: $title,
    slug: $slug,
    status: "draft",
    featured_media: $featured,
    content: { raw: $content }
  }')"

echo "[INFO] create draft post"
post_resp="$(curl -sS -u "$AUTH" -X POST "${WP_BASE}/posts" -H "Content-Type: application/json" -d "$payload")"

post_id="$(jq -r '.id // empty' <<<"$post_resp")"
post_link="$(jq -r '.link // empty' <<<"$post_resp")"
edit_link="$(jq -r '.guid.rendered // empty' <<<"$post_resp")"

if [[ -z "$post_id" ]]; then
  echo "[ERROR] post create failed" >&2
  echo "$post_resp" >&2
  exit 1
fi

echo "[OK] draft created"
echo "post_id: ${post_id}"
echo "link: ${post_link}"
echo "guid: ${edit_link}"
