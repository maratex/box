@echo off
chcp 65001 >nul
rem Конвертирует все MP4 из assets\media\video в OGV (Theora), который понимает Godot.
cd /d "%~dp0..\assets\media\video"
for %%f in (*.mp4 *.mov *.webm) do (
  echo %%f  -^>  %%~nf.ogv
  ffmpeg -y -loglevel error -i "%%f" -vf "scale=1280:-2,fps=30" -c:v libtheora -q:v 7 -c:a libvorbis -q:a 4 "%%~nf.ogv"
)
echo Готово.
pause
