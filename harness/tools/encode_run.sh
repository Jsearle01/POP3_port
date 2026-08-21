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
# ★★★ THE AUDIO NEEDS THREE FIXES BEFORE IT IS AUDIBLE AT ALL
# ---------------------------------------------------------------------------
# The first cut of this script shipped a soundtrack Jay could not hear, and every check it
# passed was a check of the wrong thing: ffprobe showed an AAC stream, the stream was
# full-length, and it measured -15 dB RMS. All true, and all irrelevant.
#
#   1. MAME RECORDS THE coco3 AS 3 CHANNELS AND ONLY c0 CARRIES SIGNAL.
#      c1 and c2 are digital silence (RMS -inf). `-ac 1` AVERAGES them, so the music was
#      divided by three -- a silent -9.5 dB attenuation. Take c0, do not downmix.
#
#   2. c0 CARRIES A HUGE DC OFFSET: measured -0.2487 of full scale, i.e. -12 dB of pure
#      0 Hz. The music sits at about -30 dB. So the recording is 18 dB of inaudible DC on
#      top of the thing you want, which is what made -15 dB RMS look healthy. Worse, AAC
#      then spends its budget coding the DC: the shipped 32k mono encode had a noise floor
#      of -35 dB against music at -30 dB -- a 5 dB SNR, where the source has 20 dB.
#      `highpass=f=20` removes it; measured DC after: 0.000023.
#
#   3. THE RESULT IS QUIET AND PEAKY (peak -4.8 dB over the whole run, RMS -31.9 dB, a 27 dB
#      crest -- the peaks are clicks, not music), so a flat +1.8 dB puts the peak at -3 dBFS.
#      Pure gain: no compression, no limiting, nothing that would edit sound Jay gated by ear
#      on a live machine, and still LOUDER than MAME's own unity playback of c0.
#      ★ MEASURE THE PEAK OVER THE WHOLE RUN, not a sample. +4.3 dB from a 30 s window
#      decoded at +1.4 dBFS, because AAC overshoots transients by ~2.4 dB here.
#
# `lowpass=f=16000` is the one liberty taken: the port drives the DAC with PWM, so there is
# real energy above 16 kHz (-40.9 dB against -29.1 full-band, ~7% of the total). It is above
# the limit of hearing and it is expensive for the encoder on already-noisy content.
#
# ★ AND THE LESSON, because it is the same one §27 already records one level up: validating
# the CONTAINER proves nothing about the CONTENT. "There is an audio stream, it is the right
# length, and it has a healthy RMS" is three container facts and zero audible ones.
#
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
#   ABR=<rate>   audio bitrate (default 64k — the source is broadband PWM, not a tone)
#   GAIN=<n>dB   post-DC-removal gain (default 1.8dB: measured peak over the WHOLE run is
#                -4.80 dBFS, so this lands it at -3, leaving room for AAC's overshoot —
#                +4.3dB, taken from a 30 s sample, decoded at +1.4 dBFS, i.e. clipped)
#   AUDIO=none   drop the soundtrack
#   OUT=<path>   output (default build/pop_intro.mp4)
set -u

cd "$(dirname "$0")/../.." || exit 1

FF="${FF:-C:/Users/jayse/AppData/Local/Microsoft/WinGet/Packages/Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe/ffmpeg-8.1.2-full_build/bin/ffmpeg.exe}"
[ -x "$FF" ] || { echo "[encode] ffmpeg not at $FF"; exit 1; }

CRF="${CRF:-23}"
GOP="${GOP:-1200}"
ABR="${ABR:-64k}"
GAIN="${GAIN:-1.8dB}"
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
    AF=""
else
    # See the header. c0 only (never -ac 1), DC out, gain to -1 dBFS peak, PWM carrier off.
    AOPT="-c:a $AUDIO -b:a $ABR"
    AF="-af pan=mono|c0=c0,highpass=f=20,lowpass=f=16000,volume=${GAIN}"
fi

# One encode over the concatenated segments, so the joins are inside a single GOP structure
# rather than four files stitched after the fact.
"$FF" -y -hide_banner -loglevel error -f concat -safe 0 -i "$LIST" \
    -vf "scale=640:472:flags=neighbor" \
    -c:v libx264 -preset veryslow -tune animation -crf "$CRF" -g "$GOP" \
    -pix_fmt yuv420p -profile:v high \
    -aspect 4:3 -movflags +faststart \
    $AF $AOPT \
    "$OUT" || exit 1

echo "[encode] -> $OUT  $(stat -c%s "$OUT" | awk '{printf "%.2f MB", $1/1048576}')"
"${FF%ffmpeg.exe}ffprobe.exe" -hide_banner "$OUT" 2>&1 | sed -n '/Duration/,$p' | sed 's/^/  /'

# ★★★ THE CHECK THE FIRST CUT DID NOT DO. `there is an audio stream` is not `you can hear
# it`. DC must be ~0, and the level must MOVE between a silent stretch and a musical one --
# a flat level across the whole run is the DC-only signature that shipped last time.
if [ "$AUDIO" != "none" ]; then
    echo "[encode] audible-content check:"
    "$FF" -hide_banner -i "$OUT" -vn -af astats=metadata=0 -f null - 2>&1 \
        | grep -E "DC offset|Peak level|RMS level" | head -3 | sed 's/^.*\] /    /'
    for t in 6 24 100 150; do
        v=$("$FF" -hide_banner -ss $t -t 3 -i "$OUT" -vn -af volumedetect -f null - 2>&1 \
            | grep -o "mean_volume: [-0-9.]*" | cut -d' ' -f2)
        printf "    %3ds  %8s dB\n" "$t" "$v"
    done
fi
