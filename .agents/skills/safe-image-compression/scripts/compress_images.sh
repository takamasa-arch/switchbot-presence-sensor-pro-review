#!/bin/zsh
set -euo pipefail

# 何を: ffmpegで記事用画像の圧縮コピーを作る。なぜ: 原本を上書きせず、安全に連番リネーム済みの圧縮版を生成するため。

usage() {
  cat <<'EOF'
Usage:
  compress_images.sh --src-dir DIR --dest-dir DIR --base-name NAME [--long-edge PX]

Options:
  --src-dir     Source directory containing original images
  --dest-dir    Destination directory for compressed copies
  --base-name   Base filename such as switchbot-ai-art-frame
  --long-edge   Max long edge for JPEG output (default: 2400)
EOF
}

src_dir=""
dest_dir=""
base_name=""
long_edge="2400"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --src-dir)
      src_dir="${2:-}"
      shift 2
      ;;
    --dest-dir)
      dest_dir="${2:-}"
      shift 2
      ;;
    --base-name)
      base_name="${2:-}"
      shift 2
      ;;
    --long-edge)
      long_edge="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$src_dir" || -z "$dest_dir" || -z "$base_name" ]]; then
  usage >&2
  exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg is required but was not found in PATH." >&2
  exit 1
fi

mkdir -p "$dest_dir"

index=1

# 何を: 画像だけを安定順で処理する。なぜ: .DS_Storeや動画を巻き込まず、再実行時も同じ連番を得るため。
while IFS= read -r -d '' file; do
  ext="${file##*.}"
  ext_lower="${ext:l}"
  printf -v seq "%02d" "$index"

  case "$ext_lower" in
    jpg|jpeg)
      out_file="$dest_dir/$base_name-$seq.jpg"
      # 何を: JPEGはffmpegで別ファイル出力する。なぜ: 原本を壊さず、sipsより安定して品質を確保しやすいため。
      ffmpeg -y -i "$file" \
        -vf "scale='if(gt(iw,ih),${long_edge},-2)':'if(gt(iw,ih),-2,${long_edge})'" \
        -q:v 2 \
        "$out_file" \
        >/dev/null 2>&1
      ;;
    png)
      out_file="$dest_dir/$base_name-$seq.png"
      # 何を: PNGは既存画質を優先してそのまま複製する。なぜ: 不用意な変換で表示崩れを起こさないため。
      cp "$file" "$out_file"
      ;;
    *)
      continue
      ;;
  esac

  index=$((index + 1))
done < <(find "$src_dir" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) | sort | tr '\n' '\0')

echo "Created compressed copies in: $dest_dir"
