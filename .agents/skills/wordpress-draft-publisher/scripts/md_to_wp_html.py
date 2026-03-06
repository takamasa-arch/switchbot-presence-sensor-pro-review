#!/usr/bin/env python3
import html
import json
import os
import re
import sys
from pathlib import Path
from typing import Dict, List


# 何を: インライン記法をWordPress向けHTMLへ変換。なぜ: Markdown本文を崩さずp/hタグ内へ移すため。
def format_inline(text: str) -> str:
    escaped = html.escape(text.strip())
    escaped = re.sub(r"`([^`]+)`", r"<code>\1</code>", escaped)
    escaped = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", escaped)
    escaped = re.sub(r"(https?://[^\s<]+)", r'<a href="\1">\1</a>', escaped)
    return escaped


# 何を: WordPress用figureタグを生成。なぜ: 画像を指定フォーマットで本文差し込みするため。
def make_figure(media: Dict[str, str], alt_text: str) -> str:
    src = html.escape(str(media["url"]), quote=True)
    image_id = html.escape(str(media["id"]), quote=True)
    alt = html.escape(alt_text, quote=True)
    return (
        f'<figure class="wp-block-image size-full">'
        f'<img src="{src}" alt="{alt}" class="wp-image-{image_id}"/>'
        f"</figure>"
    )


def parse_markdown_image(stripped: str) -> tuple[str, str] | None:
    match = re.match(r'^!\[([^\]]*)\]\(([^)\s]+)(?:\s+"[^"]*")?\)$', stripped)
    if not match:
        return None
    return match.group(1).strip(), Path(match.group(2).strip()).name


def build_media_map() -> Dict[str, Dict[str, str]]:
    raw = os.environ.get("WP_MEDIA_JSON", "[]")
    media_list = json.loads(raw)
    return {str(item["filename"]): item for item in media_list}


def build_insert_plan(media_map: Dict[str, Dict[str, str]]) -> Dict[str, Dict[str, str]]:
    featured = os.environ.get("FEATURED_IMAGE", "")
    body_media = [v for k, v in sorted(media_map.items()) if k != featured]

    default_anchors = [
        "なぜ注目したか: 書斎で集中していると照明が消えることがあった",
        "mmWaveとは何か（家庭で使う価値）",
        "実際に使って感じたこと（本編）",
        "誤検知まわりで気になった点",
        "比較表（旧製品・競合・電池持ち）",
    ]

    # 何を: 差し込み位置を外部指定できるようにする。なぜ: 記事ごとの見出し構成差に対応するため。
    custom = os.environ.get("IMAGE_INSERT_MAP", "").strip()
    if custom:
        custom_map = json.loads(custom)
        plan: Dict[str, Dict[str, str]] = {}
        for h2_text, filename in custom_map.items():
            if filename in media_map:
                plan[h2_text] = media_map[filename]
        return plan

    plan = {}
    for idx, anchor in enumerate(default_anchors):
        if idx < len(body_media):
            plan[anchor] = body_media[idx]
    return plan


def build_alt_map() -> Dict[str, str]:
    custom_alt = os.environ.get("IMAGE_ALT_MAP", "").strip()
    if custom_alt:
        return json.loads(custom_alt)
    return {}


def parse_table_row(line: str) -> List[str]:
    row = line.strip().strip("|")
    return [cell.strip() for cell in row.split("|")]


def convert_markdown(
    md_text: str,
    media_map: Dict[str, Dict[str, str]],
    insert_plan: Dict[str, Dict[str, str]],
    alt_map: Dict[str, str],
) -> str:
    lines = md_text.splitlines()
    out: List[str] = []
    paragraph: List[str] = []
    i = 0
    in_comment = False

    def flush_paragraph() -> None:
        nonlocal paragraph
        if not paragraph:
            return
        joined = "<br>".join(format_inline(x) for x in paragraph if x.strip())
        if joined:
            out.append(f"<p>{joined}</p>")
        paragraph = []

    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        if in_comment:
            if "-->" in stripped:
                in_comment = False
            i += 1
            continue
        if stripped.startswith("<!--"):
            if "-->" not in stripped:
                in_comment = True
            i += 1
            continue

        if not stripped:
            flush_paragraph()
            i += 1
            continue

        if stripped == "---":
            flush_paragraph()
            i += 1
            continue

        image = parse_markdown_image(stripped)
        if image:
            flush_paragraph()
            alt_text, filename = image
            if filename in media_map:
                media = media_map[filename]
                alt = alt_map.get(filename, alt_text or f"{filename}のイメージ")
                out.append(make_figure(media, alt))
            i += 1
            continue

        heading = re.match(r"^(#{1,4})\s+(.*)$", stripped)
        if heading:
            flush_paragraph()
            level = len(heading.group(1))
            title = heading.group(2).strip()
            # 何を: H1は本文へ出力しない。なぜ: WordPress側の投稿タイトルと重複させないため。
            if level == 1:
                i += 1
                continue
            out.append(f"<h{level}>{format_inline(title)}</h{level}>")
            if level == 2 and title in insert_plan:
                media = insert_plan[title]
                filename = str(media["filename"])
                alt = alt_map.get(filename, f"{title}のイメージ")
                out.append(make_figure(media, alt))
            i += 1
            continue

        if stripped.startswith("- "):
            flush_paragraph()
            out.append("<ul>")
            while i < len(lines) and lines[i].strip().startswith("- "):
                li = lines[i].strip()[2:].strip()
                out.append(f"<li>{format_inline(li)}</li>")
                i += 1
            out.append("</ul>")
            continue

        if "|" in stripped and i + 1 < len(lines):
            sep = lines[i + 1].strip()
            if re.match(r"^\|?(\s*:?-+:?\s*\|)+\s*:?-+:?\s*\|?$", sep):
                flush_paragraph()
                headers = parse_table_row(lines[i])
                out.append('<figure class="wp-block-table"><table><thead><tr>')
                for h in headers:
                    out.append(f"<th>{format_inline(h)}</th>")
                out.append("</tr></thead><tbody>")
                i += 2
                while i < len(lines):
                    row_line = lines[i].strip()
                    if not row_line or "|" not in row_line:
                        break
                    cols = parse_table_row(lines[i])
                    out.append("<tr>")
                    for c in cols:
                        out.append(f"<td>{format_inline(c)}</td>")
                    out.append("</tr>")
                    i += 1
                out.append("</tbody></table></figure>")
                continue

        paragraph.append(stripped)
        i += 1

    flush_paragraph()
    return "\n".join(out)


def main() -> None:
    if len(sys.argv) < 2:
        print("usage: md_to_wp_html.py <article.md>", file=sys.stderr)
        sys.exit(1)

    article_path = sys.argv[1]
    with open(article_path, "r", encoding="utf-8") as f:
        md_text = f.read()

    media_map = build_media_map()
    insert_plan = build_insert_plan(media_map)
    alt_map = build_alt_map()

    html_body = convert_markdown(md_text, media_map, insert_plan, alt_map)
    print(html_body)


if __name__ == "__main__":
    main()
