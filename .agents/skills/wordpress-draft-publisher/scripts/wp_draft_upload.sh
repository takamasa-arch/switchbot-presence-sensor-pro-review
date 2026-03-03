#!/usr/bin/env bash
set -euo pipefail

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

if [[ ! -f "$ARTICLE_MD" ]]; then
  echo "[ERROR] article not found: $ARTICLE_MD" >&2
  exit 1
fi

# 何を: 画像ファイルを固定順で収集。なぜ: 実行ごとの差分を減らして再現性を上げるため。
mapfile -t IMAGES < <(find . -maxdepth 1 -type f \
  \( -name 'switchbot-presence-sensor-pro-*.jpg' -o -name 'switchbot-presence-sensor-pro-*.jpeg' -o -name 'switchbot-presence-sensor-pro-*.png' \) \
  | sed 's|^./||' | sort)

if [[ ${#IMAGES[@]} -eq 0 ]]; then
  echo "[ERROR] no images found (switchbot-presence-sensor-pro-*.jpg/png)" >&2
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

declare -A MEDIA_ID
MEDIA_LINES=()

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

  MEDIA_ID["$image"]="$id"
  MEDIA_LINES+=("<li><a href=\"${url}\">${image}</a></li>")
done

featured_id="${MEDIA_ID[$FEATURED_IMAGE]:-}"
if [[ -z "$featured_id" ]]; then
  echo "[WARN] featured image not found in upload set: $FEATURED_IMAGE" >&2
  featured_id="${MEDIA_ID[${IMAGES[0]}]}"
fi

# 何を: Markdown本文をそのまま表示できるHTMLへ変換。なぜ: 依存を増やさずAPI投稿を安定させるため。
body_text="$(cat "$ARTICLE_MD")"
body_escaped="$(printf '%s' "$body_text" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')"
media_html="<h2>画像一覧</h2><ul>$(printf '%s' "${MEDIA_LINES[*]}")</ul>"
content_html="<pre>${body_escaped}</pre>${media_html}"

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
