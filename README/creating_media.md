```
ffmpeg -i video.mp4 -vf "scale=64:32" -pix_fmt rgb565le -f rawvideo video.rgb565

ffmpeg -i video.mp4 -vf "scale=128:32" -pix_fmt rgb565le -f rawvideo video.rgb565
```

ffmpeg -i "input.mpg" -filter_complex "fps=15,scale=220:-1:flags=bilinear:sws_dither=none[x];[x]split[x1][x2];[x1]palettegen=reserve_transparent=off:stats_mode=single:max_colors=256[p];[x2][p]paletteuse=new=1:dither=none,format=rgb565le" frames/%03d.bmp

show media with frame#
```
ffplay video.mp4 -vf "drawtext=fontfile=Arial.ttf: \
text=%{n}: x=(w-tw)/2: y=h-(2*lh): \
fontcolor=white: fontsize=100: box=1: \
boxcolor=0x00000099"
```
python3 video_player.py --width=128 --source=/home/pi/aly_file128.rgb565 -b 2444444 --step --start-frame=182
python3 image_printer.py --src blahlocal.uart --src-width=128 --src-height=32 --src-depth=2 --target=/dev/ttyAMA3 --target-freq=2444444

tool for showing rgb565 content
https://www.kernellabs.com/rawpixels/index.html