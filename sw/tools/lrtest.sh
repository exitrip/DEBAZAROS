#!/bin/sh
# lrtest.sh [stream] - one L/R cycle through a Linux PCM FIFO: 3 s 440 Hz
# left, 3 s 660 Hz right. stream 0 = HDMI_0 (default), 1 = HDMI_1, 2 = I2S.
ffmpeg -nostdin -loglevel error -f lavfi -i "aevalsrc=exprs=if(lt(t\,3)\,0.7*sin(2*PI*440*t)\,0)|if(gte(t\,3)\,0.7*sin(2*PI*660*t)\,0):s=48000:d=6" -f s16le -ac 2 -ar 48000 - | sudo /home/ebaz/bin/pcmplay -s ${1:-0}
