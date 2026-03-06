---
name: youtube-video-upload
description: Upload local video files to YouTube safely with the YouTube Data API v3. Use when Codex needs to publish a recorded video from the local filesystem, prepare upload metadata such as title/description/tags/privacy, run an OAuth-based resumable upload, or avoid reimplementing YouTube upload steps by hand.
---

# Youtube Video Upload

## Overview

Use this skill to upload a local video file to YouTube with explicit metadata and a resumable API workflow.  
Prefer the bundled Python script over ad hoc browser automation when the user wants a repeatable upload path.

<!-- 何を: YouTubeアップロードの前提条件を固定。なぜ: OAuth設定漏れや誤った公開設定で手戻りするのを防ぐため。 -->
## Preconditions

- A Google Cloud project with the YouTube Data API v3 enabled is required.
- OAuth client credentials for a Desktop app are required.
- The operator must have permission to upload to the target YouTube channel.
- The local machine needs Python 3 plus `google-api-python-client`, `google-auth-oauthlib`, and `google-auth-httplib2`.

## Core Rules

- Do not hardcode OAuth credentials into scripts or committed files.
- Default to `private` unless the user explicitly asks for `public` or `unlisted`.
- Run a dry run first when metadata is still being reviewed.
- Keep the upload script resumable and metadata-driven.
- If the Google API project is unverified, warn that uploaded videos may be restricted to private mode until the project passes audit or the account qualifies.

## Workflow

1. Confirm the source video and metadata.
   Collect title, description, tags, privacy, optional category, and optional thumbnail path.

2. Confirm credentials location.
   Expect a local OAuth client secrets JSON file and a writable token cache path.

3. Run a dry run first.
   Use `--dry-run` to verify the payload without requiring Google dependencies or uploading anything.

4. Install dependencies if needed.
   Use:

```bash
python3 -m pip install google-api-python-client google-auth-oauthlib google-auth-httplib2
```

5. Run the uploader.
   Use the bundled script with explicit arguments.

6. Report the result.
   Return the YouTube video ID and the requested privacy setting. If a thumbnail upload was requested, report whether it succeeded.

## Default Commands

Dry run:

```bash
python3 .agents/skills/youtube-video-upload/scripts/upload_youtube_video.py \
  --video articles/my-article/video.mov \
  --title "Video Title" \
  --description-file articles/my-article/youtube-description.txt \
  --tags "tag1,tag2" \
  --privacy private \
  --client-secrets ~/.config/youtube/client_secret.json \
  --token-file ~/.config/youtube/token.json \
  --dry-run
```

Actual upload:

```bash
python3 .agents/skills/youtube-video-upload/scripts/upload_youtube_video.py \
  --video articles/my-article/video.mov \
  --title "Video Title" \
  --description-file articles/my-article/youtube-description.txt \
  --tags "tag1,tag2" \
  --privacy unlisted \
  --client-secrets ~/.config/youtube/client_secret.json \
  --token-file ~/.config/youtube/token.json
```

Optional thumbnail:

```bash
python3 .agents/skills/youtube-video-upload/scripts/upload_youtube_video.py \
  --video articles/my-article/video.mov \
  --title "Video Title" \
  --description-file articles/my-article/youtube-description.txt \
  --privacy private \
  --client-secrets ~/.config/youtube/client_secret.json \
  --token-file ~/.config/youtube/token.json \
  --thumbnail articles/my-article/thumbnail.jpg
```

## Notes

- The script uses the `youtube.upload` scope.
- The API uses `videos.insert` for upload and `thumbnails.set` for optional thumbnail updates.
- Official docs currently show mixed quota descriptions in different places; treat video upload as a relatively expensive operation and avoid unnecessary retries.
- If the video is intended for publication later, upload as `private` or `unlisted` first and change visibility after verification.

## Verification Checklist

- Confirm the source video exists before running the upload.
- Confirm the dry-run output matches the intended title, privacy, and tags.
- After upload, capture the returned video ID.
- If the user asked for public release, remind them to verify visibility on YouTube Studio.

## Resources

- `scripts/upload_youtube_video.py`
  OAuth-based YouTube uploader with dry-run support and optional thumbnail upload.
