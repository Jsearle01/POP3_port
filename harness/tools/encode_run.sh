#!/bin/bash
# harness/tools/encode_run.sh — turn capture_run.lua's AVI segments into one small mp4.
#
# ---------------------------------------------------------------------------
# WHY 640x472 AND NOT THE IDIOM'S 1280x944
# ---------------------------------------------------------------------------
# mame-idioms-coco3-port.md §27 encodes at 1280x944 and gives the reason: at 640 wide,
# 4:2:0's chroma subsampling would smear the NTSC fringe colour the conversion exists to
# reproduce. Worked through for THIS source that turns out to be one doubling too many:
#
#   MAME emits 640x236 for a 320-pixel mode, so one source pixel is already 2 luma px wide
#   and 1 luma row tall. Output 640x472 is x1 horizontal, x2 vertical, and its yuv420p
#   chroma plane is 320x236 -- which is EXACTLY ONE CHROMA SAMPLE PER SOURCE PIXEL, both
#   axes. 1280x944 gives two, which is redundant, not safer.
#
# So 640x472 is chroma-exact AND the luma is 1:1 horizontally -- the pixels cannot get
# softer than the source. It is 1.356:1, the same 1.7%-off-4:3 as 1280x944, and `-aspect
# 4:3` carries the real ratio for a player that honours it.
#
# ---------------------------------------------------------------------------
# THE AUDIO IS THE HALF THAT COSTS
# ---------------------------------------------------------------------------
# Measured on a 10-second sample: video 20 KB, audio 43 KB at 32 kbps. On near-static
# content the picture is almost free and the soundtrack is the file. MAME records the
# coco3 as 3-channel 48 kHz; the port drives a 1-bit DAC, so it is downmixed to mono.
# Pass AUDIO=none for a silent cut when size is the only thing that matters.
#
# ---------------------------------------------------------------------------
# ★★★ THE KEYFRAME INTERVAL IS THE BIG LEVER, NOT THE CRF
# ---------------------------------------------------------------------------
# Measured on one segment (2,700 frames of mostly-static dithered artwork), crf 23 fixed:
#
#     -g 250 (x264's default)   960 KB   11 keyframes
#     -g 600                    570 KB    6
#     -g 1200                   422 KB    4
#     -g 3000                   284 KB    1
#
# 56% of the file was PERIODIC keyframes re-sending a picture that had not changed. The
# artwork is converted Apple II DHR, so every still frame is full of dither detail and an
# I-frame of it is expensive; the P-frames between are nearly free. Scene-cut detection
# still inserts an I-frame where the picture ACTUALLY changes, so raising -g costs nothing
# but seek granularity. 1200 = one keyframe per 20 s, which a review video can afford.
#
# By contrast the CRF sweep on the busiest segment moved 1,048 KB (crf 18, 50.9 dB PSNR) to
# 723 KB (crf 28, 42.2 dB) -- a third of the size for 8.7 dB. The GOP change costs 0 dB.
#
# `-tune animation` earns its place too: 850 KB at 46.4 dB against 816 KB at 44.0 dB
# untuned, i.e. +2.4 dB for +4%. `stillimage`, `film` and `deblock=-3,-3` were all worse.
#
#   CRF=<n>      x264 quality, lower is bigger (default 23)
#   GOP=<n>      keyframe interval in frames (default 1200 = 20 s)
#   ABR=<rate>   audio bitrate (default 32k)
#   AUDIO=none   drop the soundtrack
#   OUT=<path>   output (default build/pop_intro.mp4)
set -u

cd "$(dirname "$0")/../.." || exit 1

FF="${FF:-C:/Users/jayse/AppData/Local/Microsoft/WinGet/Packages/Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe/ffmpeg-8.1.2-full_build/bin/ffmpeg.exe}"
[ -x "$FF" ] || { echo "[encode] ffmpeg not at $FF"; exit 1; }

CRF="${CRF:-23}"
GOP="${GOP:-1200}"
ABR="${ABR:-32k}"
AUDIO="${AUDIO:-aac}"
OUT="${OUT:-build/pop_intro.mp4}"
PREFIX="${PREFIX:-snap/pop_seg}"

LIST=build/tmp/segments.txt
: > "$LIST"
n=0
for f in ${PREFIX}_*.avi; do
    [ -f "$f" ] || continue
    # ★ THE CONCAT DEMUXER TAKES A PATH, AND A RELATIVE ONE IS RESOLVED AGAINST THE LIST
    # FILE, not the working directory. Absolute paths remove the question entirely.
    echo "file '$(pwd -W 2>/dev/null || pwd)/$f'" >> "$LIST"
    n=$((n+1))
done
[ "$n" -gt 0 ] || { echo "[encode] no segments matching ${PREFIX}_*.avi"; exit 1; }
echo "[encode] $n segment(s), $(du -ch ${PREFIX}_*.avi | tail -1 | cut -f1) raw"

if [ "$AUDIO" = "none" ]; then
    AOPT="-an"
else
    AOPT="-ac 1 -c:a $AUDIO -b:a $ABR"
fi

# One encode over the concatenated segments, so the joins are inside a single GOP structure
# rather than four files stitched after the fact.
"$FF" -y -hide_banner -loglevel error -f concat -safe 0 -i "$LIST" \
    -vf "scale=640:472:flags=neighbor" \
    -c:v libx264 -preset veryslow -tune animation -crf "$CRF" -g "$GOP" \
    -pix_fmt yuv420p -profile:v high \
    -aspect 4:3 -movflags +faststart \
    $AOPT \
    "$OUT" || exit 1

echo "[encode] -> $OUT  $(stat -c%s "$OUT" | awk '{printf "%.2f MB", $1/1048576}')"
"${FF%ffmpeg.exe}ffprobe.exe" -hide_banner "$OUT" 2>&1 | sed -n '/Duration/,$p' | sed 's/^/  /'
