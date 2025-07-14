```
ffmpeg -i video.mp4 -vf "scale=64:32" -pix_fmt rgb565le -f rawvideo video.rgb565
```