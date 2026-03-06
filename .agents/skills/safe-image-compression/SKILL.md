---
name: safe-image-compression
description: Safely compress and rename article images with ffmpeg without overwriting originals. Use when Codex needs to shrink JPEG/PNG assets for blog posts, reorganize raw camera files into article-ready sequential names, or avoid broken output caused by destructive in-place image compression.
---

# Safe Image Compression

## Overview

Use this skill when preparing blog or media assets that need both renaming and compression.  
Prefer the bundled script and the `ffmpeg` workflow in this skill over ad hoc `sips`-based in-place conversion.

<!-- 何を: 画像圧縮の安全手順を固定。なぜ: 原本上書きや不正な圧縮品質で記事素材を壊す事故を防ぐため。 -->
## Core Rules

- Never overwrite originals during compression.
- Always write compressed files to a separate destination first.
- Use `ffmpeg` as the default JPEG compressor.
- Treat deletion of originals as a separate, explicit cleanup step after verification.
- If an image looks suspiciously tiny after compression, stop and inspect the output before continuing.

## Workflow

1. Inspect the source directory.
   Confirm which files are images, which are videos, and whether all expected originals are present.

2. Compress into a separate output directory.
   Use the bundled script so output files are generated as sequential article assets such as `product-name-01.jpg`.

3. Verify the output.
   Check file count, file sizes, and image metadata before deleting or moving anything.

4. Only after verification, decide whether to replace originals.
   Do not delete originals unless the user explicitly asks for that cleanup step.

## Default Command

Use the bundled script:

```bash
.agents/skills/safe-image-compression/scripts/compress_images.sh \
  --src-dir articles/my-article \
  --dest-dir articles/my-article/compressed \
  --base-name my-article
```

Default behavior:

- JPEG/JPG: compress with `ffmpeg`
- PNG: copy as-is unless the user explicitly wants PNG optimization
- Originals: preserved
- Output names: sequential, zero-padded, article-friendly

## Recommended Settings

- Long edge: `2400`
- JPEG quality: `2` for `ffmpeg -q:v`
- Destination: sibling `compressed/` directory first
- Rename pattern: `<article-slug>-01.jpg`

These defaults are tuned for article use where visual breakage is worse than a slightly larger file.

## Verification Checklist

- Run `file` on the compressed outputs.
- Compare output count with the intended source image count.
- Check sizes with `ls -lh`.
- If the user reports visual corruption, discard the output set and retry with the script, not with in-place `sips` conversion.

## Anti-Patterns

- Do not compress in place.
- Do not rename originals first and then compress over them.
- Do not treat tiny file size as success.
- Do not delete originals before checking the generated copies.
- Do not assume hidden files like `.DS_Store` are part of the image set.

## Resources

- `scripts/compress_images.sh`
  Safe wrapper around `ffmpeg` for producing article-ready copies without touching source files.
