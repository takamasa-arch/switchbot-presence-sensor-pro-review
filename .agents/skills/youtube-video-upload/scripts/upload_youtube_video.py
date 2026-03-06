#!/usr/bin/env python3
"""Upload a local video to YouTube with explicit metadata."""

# 何を: YouTube向けの動画アップロードCLIを提供する。なぜ: 毎回OAuthや再開可能アップロードを手書きせず、安全に再利用できるようにするため。

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

SCOPES = ["https://www.googleapis.com/auth/youtube.upload"]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Upload a local video to YouTube.")
    parser.add_argument("--video", required=True, help="Path to the local video file.")
    parser.add_argument("--title", required=True, help="YouTube video title.")
    parser.add_argument("--description", default="", help="Inline description text.")
    parser.add_argument(
        "--description-file",
        help="Path to a UTF-8 text file containing the description. Overrides --description when provided.",
    )
    parser.add_argument("--tags", default="", help="Comma-separated tag list.")
    parser.add_argument("--category-id", default="22", help="YouTube category ID. Default: 22")
    parser.add_argument(
        "--privacy",
        choices=["private", "unlisted", "public"],
        default="private",
        help="Initial privacy status.",
    )
    parser.add_argument(
        "--made-for-kids",
        action="store_true",
        help="Mark the video as made for kids.",
    )
    parser.add_argument(
        "--client-secrets",
        required=True,
        help="OAuth client secrets JSON for a Google Desktop app.",
    )
    parser.add_argument(
        "--token-file",
        required=True,
        help="Path to the OAuth token cache JSON file.",
    )
    parser.add_argument("--thumbnail", help="Optional thumbnail image path.")
    parser.add_argument(
        "--force-reauth",
        action="store_true",
        help="Ignore any existing token file and force a fresh OAuth login.",
    )
    parser.add_argument(
        "--auth-prompt",
        default="consent select_account",
        help="OAuth prompt value. Default: 'consent select_account'",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the upload payload and exit without calling Google APIs.",
    )
    return parser.parse_args()


def load_description(args: argparse.Namespace) -> str:
    if args.description_file:
        return Path(args.description_file).read_text(encoding="utf-8")
    return args.description


def build_body(args: argparse.Namespace, description: str) -> dict[str, Any]:
    tags = [tag.strip() for tag in args.tags.split(",") if tag.strip()]
    # 何を: YouTube APIに渡すメタデータ本体を組み立てる。なぜ: dry-runでも本番でも同じ内容を検証できるようにするため。
    return {
        "snippet": {
            "title": args.title,
            "description": description,
            "tags": tags,
            "categoryId": args.category_id,
        },
        "status": {
            "privacyStatus": args.privacy,
            "selfDeclaredMadeForKids": args.made_for_kids,
        },
    }


def ensure_paths(args: argparse.Namespace) -> None:
    video = Path(args.video)
    secrets = Path(args.client_secrets)
    token_path = Path(args.token_file)

    if not video.is_file():
        raise FileNotFoundError(f"Video not found: {video}")
    if not secrets.is_file():
        raise FileNotFoundError(f"Client secrets file not found: {secrets}")
    if args.thumbnail and not Path(args.thumbnail).is_file():
        raise FileNotFoundError(f"Thumbnail file not found: {args.thumbnail}")

    token_path.parent.mkdir(parents=True, exist_ok=True)


def build_service(args: argparse.Namespace):
    # 何を: Google認証ライブラリのimportを遅延させる。なぜ: dry-runや--helpだけなら依存未導入でも使えるようにするため。
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    from google_auth_oauthlib.flow import InstalledAppFlow
    from googleapiclient.discovery import build

    token_path = Path(args.token_file)
    creds = None

    if token_path.exists() and not args.force_reauth:
        creds = Credentials.from_authorized_user_file(str(token_path), SCOPES)

    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file(args.client_secrets, SCOPES)
            # 何を: アカウント選択付きでOAuthを取り直せるようにする。なぜ: 別アカウントの既存セッションを誤って再利用しないため。
            creds = flow.run_local_server(
                port=0,
                access_type="offline",
                prompt=args.auth_prompt,
            )
        token_path.write_text(creds.to_json(), encoding="utf-8")

    return build("youtube", "v3", credentials=creds)


def upload_video(args: argparse.Namespace, body: dict[str, Any]) -> dict[str, Any]:
    from googleapiclient.http import MediaFileUpload

    service = build_service(args)
    request = service.videos().insert(
        part="snippet,status",
        body=body,
        media_body=MediaFileUpload(args.video, chunksize=-1, resumable=True),
    )

    response = None
    while response is None:
        _, response = request.next_chunk()

    if args.thumbnail:
        service.thumbnails().set(
            videoId=response["id"],
            media_body=MediaFileUpload(args.thumbnail),
        ).execute()

    return response


def main() -> int:
    args = parse_args()
    description = load_description(args)
    body = build_body(args, description)

    if args.dry_run:
        payload = {
            "video": args.video,
            "thumbnail": args.thumbnail,
            "client_secrets": args.client_secrets,
            "token_file": args.token_file,
            "force_reauth": args.force_reauth,
            "auth_prompt": args.auth_prompt,
            "scope": SCOPES,
            "body": body,
        }
        print(json.dumps(payload, ensure_ascii=False, indent=2))
        return 0

    try:
        ensure_paths(args)
        response = upload_video(args, body)
    except Exception as exc:  # noqa: BLE001
        print(f"Upload failed: {exc}", file=sys.stderr)
        return 1

    result = {
        "video_id": response.get("id"),
        "requested_privacy": args.privacy,
        "title": args.title,
        "thumbnail_uploaded": bool(args.thumbnail),
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
