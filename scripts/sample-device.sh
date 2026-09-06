#!/bin/sh
set -eu
serial=${ADB_SERIAL:-$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')}
[ -n "$serial" ] || { echo 'No online ADB device' >&2; exit 1; }
adb -s "$serial" shell '
i=0
while [ "$i" -lt 60 ]; do
  p=$(pidof love.aarch64)
  [ -n "$p" ] || break
  printf "%s " "$(cut -d" " -f1 /proc/uptime)"
  awk "/^VmRSS:|^VmSwap:/ {printf \"%s=%s \", \$1, \$2}" /proc/$p/status
  awk "/^MemAvailable:/ {printf \"avail_kb=%s \", \$2}" /proc/meminfo
  awk "/^pswpin |^pswpout / {printf \"%s=%s \", \$1, \$2}" /proc/vmstat
  printf "gpu="
  cat /sys/class/devfreq/fde60000.gpu/load
  sleep 2
  i=$((i+1))
done'
