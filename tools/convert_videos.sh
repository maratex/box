#!/usr/bin/env bash
# Конвертирует все MP4 из assets/media/video в OGV (Theora), который понимает Godot.
set -e
cd "$(dirname "$0")/../assets/media/video"
shopt -s nullglob
for f in *.mp4 *.MP4 *.mov *.webm; do
  out="${f%.*}.ogv"
  echo "→ $f  →  $out"
  ffmpeg -y -loglevel error -i "$f" -vf "scale=1280:-2,fps=30" \
    -c:v libtheora -q:v 7 -c:a libvorbis -q:a 4 "$out"
done
echo "Готово."
