#!/bin/bash
# Le Chariot product trailer — assembles title cards and real simulator footage
# into a 1080x1920 vertical cut. Source: take1.mov (iPhone 17 Pro, live backend).
#
# Usage: tools/trailer-build.sh [source.mp4]
#
# The source must be constant frame rate. Raw `xcrun simctl io … recordVideo`
# output is not — its PTS are erratic and -ss/-t will cut segments many times
# longer than asked. Normalize once first:
#
#   ffmpeg -i take.mov -an -vf "fps=30,format=yuv420p,setsar=1" \
#          -c:v libx264 -preset veryfast -crf 16 take_cfr.mp4
#
# The scene timings below are specific to that recording; re-time them if you
# shoot new footage (tile a crop of the region that changes at 1 fps to find
# the transitions).
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$REPO/assets/trailer"
WORK="$REPO/build/trailer"
mkdir -p "$OUT" "$WORK"
cd "$WORK"

SRC="${1:-$WORK/take_cfr.mp4}"
if [ ! -f "$SRC" ]; then
  echo "source footage not found: $SRC" >&2
  echo "pass one as an argument, or drop take_cfr.mp4 in $WORK" >&2
  exit 1
fi
CREAM=0xECE6BE
FPS=30
W=1080
H=1920
# 1206x2622 screen scaled to full height, padded to 1080 wide on the brand cream.
FIT="scale=884:1920:flags=lanczos,pad=${W}:${H}:98:0:color=${CREAM},fps=${FPS},format=yuv420p,setsar=1"
CARDFIT="scale=${W}:${H},fps=${FPS},format=yuv420p,setsar=1"

seg_video () { # start duration out
  ffmpeg -y -v error -ss "$1" -t "$2" -i "$SRC" -an -vf "$FIT" \
    -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p "$3"
}
seg_card () { # png duration out
  ffmpeg -y -v error -loop 1 -t "$2" -i "$1" -vf "$CARDFIT" \
    -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p "$3"
}

rm -f s*.mp4

# 1  hook
seg_card "$OUT/card1.png"    2.4 s01.mp4
# 2  empty list, then the first answer lands           (transition at ~22.0s)
seg_video 20.0        3.5 s02.mp4
# 3  answer grows: 0,49 -> 2,08                        (transition at ~47.0s)
seg_video 45.8        2.5 s03.mp4
# 4  2,08 -> 3,08                                      (transition at ~69.0s)
seg_video 67.8        2.5 s04.mp4
# 5  3,08 -> ALDI Nord 5,06, the shop flips            (transition at ~96.0s)
seg_video 94.8        2.5 s05.mp4
# 6  5,06 -> 7,55, five of five, held                  (transition at ~112.0s)
seg_video 110.5       5.0 s06.mp4
# 7  claim
seg_card "$OUT/card3.png"    2.4 s07.mp4
# 8  the matched offers behind the number
seg_video 136.0       4.5 s08.mp4
# 9  positioning
seg_card "$OUT/card4.png"    2.4 s09.mp4
# 10 end card
seg_card "$OUT/card_end.png" 3.8 s10.mp4

# Cross-dissolve the ten segments. Offsets are cumulative duration minus the
# overlap already consumed by earlier fades.
X=0.3
ffmpeg -y -v error \
  -i s01.mp4 -i s02.mp4 -i s03.mp4 -i s04.mp4 -i s05.mp4 \
  -i s06.mp4 -i s07.mp4 -i s08.mp4 -i s09.mp4 -i s10.mp4 \
  -filter_complex "\
[0][1]xfade=transition=fade:duration=$X:offset=2.1[v1];\
[v1][2]xfade=transition=fade:duration=$X:offset=5.3[v2];\
[v2][3]xfade=transition=fade:duration=$X:offset=7.5[v3];\
[v3][4]xfade=transition=fade:duration=$X:offset=9.7[v4];\
[v4][5]xfade=transition=fade:duration=$X:offset=11.9[v5];\
[v5][6]xfade=transition=fade:duration=$X:offset=16.6[v6];\
[v6][7]xfade=transition=fade:duration=$X:offset=18.7[v7];\
[v7][8]xfade=transition=fade:duration=$X:offset=22.9[v8];\
[v8][9]xfade=transition=fade:duration=$X:offset=25.0[v9];\
[v9]fps=$FPS,format=yuv420p[vout]" \
  -map "[vout]" -c:v libx264 -preset slow -crf 19 -pix_fmt yuv420p \
  -movflags +faststart cut.mp4

# Carry a silent stereo track — some players and social uploaders choke on a
# file with no audio stream at all. Swap anullsrc for a real bed when licensed.
ffmpeg -y -v error -i cut.mp4 \
  -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=48000 -shortest \
  -c:v copy -c:a aac -b:a 96k -movflags +faststart "$OUT/le-chariot-trailer.mp4"
rm -f cut.mp4

ffprobe -v error -show_entries format=duration:stream=width,height,r_frame_rate \
  -of default=noprint_wrappers=1 "$OUT/le-chariot-trailer.mp4"
