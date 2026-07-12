#!/usr/bin/env bash

echo debaz4205_wrapper_20250916.bit.bin >  /sys/class/fpga_manager/fpga0/firmware

for i in 1 2 3 4 6 8; 
do 
  sudo devmem $((0x43c50000 + (($i*10) + 8) * 4)) 32 0xffff0023;
  sudo devmem $((0x43c50000 + (($i*10) + 9) * 4)) 32 0xed200000;
done

for i in 0 5 7; 
do 
  sudo devmem $((0x43c50000 + (($i*10) + 8) * 4)) 32 0x80000004; 
done

/home/ebaz/hdmi2.elf &

ffmpeg -nostdin -stream_loop -1 -re -i /home/ebaz/test24-1280-8MBps.mp4 -pix_fmt bgra -f fbdev /dev/fb0 -loglevel quiet &


devmem $((0x43c50000 + (83) * 4)) 32 0x01
devmem $((0x43d00000)) 32 $((0x80000a11))
devmem $((0x44d00000)) 32 $((0x80000002))
devmem $((0x43c50000 + (81) * 4)) 32 0x40
devmem $((0x43c50000 + (33) * 4)) 32 0x03
devmem $((0x43c50000 + (30) * 4)) 32 0x20
devmem $((0x43c50000 + (10) * 4)) 32 0xff
devmem $((0x43c50000 + (11) * 4)) 32 0xff
devmem 0x41230008 32 0x130000

while true
do
  for j in 2 5 1290; 
    do
    devmem $((0x44d00000)) 32 $((0x80000000 + $j))
    for i in {0..255}; 
      do devmem 0x41260008 32 $(($i*0x020000 + 0x010000 + $i*0x0100 + $i*0x01)); 
      sleep 0.1; 
    done

    for i in {255..0..5}; 
      do devmem 0x41260008 32 $(($i*0x010000 + $i*0x0100 + $i*0x01)); 
      sleep 0.1; 
    done
    
    for i in {255..0..2};                                            
      do devmem 0x41260000 32 $(($i*0x010000 + $i*0x0100 + $i*0x01));           
      sleep 0.1;                                                     
    done

    for i in {0..255..2};
      do devmem 0x41260000 32 $(($i*0x010000 + $i*0x0100 + $i*0x01));
      sleep 0.1;
    done

    osc1=$(devmem $((0x43d00000)) 32)
    if [[ "$osc1" -gt 0x8000ffff ]]; then
      devmem $((0x43d00000)) 32 $((0x80000000 + (0xa11)))
    else
     devmem $((0x43d00000)) 32 $((0x80000000 + (0xa12 *750) + 163))  
    fi
  done
  osc2=$(devmem 0x41230008 32)
  if [[ "$osc2" -eq 0x00130000 ]]; then
    devmem 0x41230008 32 0x00204000
  else
    devmem 0x41230008 32 0x00130000
  fi
done

#EOF
