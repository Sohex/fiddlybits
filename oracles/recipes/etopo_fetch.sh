#!/bin/bash
# Fetch every ETOPO 2022 15 arc-second bedrock and ice-surface tile from the NCEI THREDDS file server (public, no auth).
set -u
BASE=https://www.ngdc.noaa.gov/thredds
OUT=/home/cfutro/git/fiddlybits/oracles/data/etopo2022
for kind in bed surface; do
  dir=15s_${kind}_elev_netcdf
  list=$(curl -s "$BASE/catalog/global/ETOPO2022/15s/$dir/catalog.html" | grep -o "ETOPO_2022_v1_15s_[NS][0-9]*[EW][0-9]*_${kind}\.nc" | sort -u)
  n=$(echo "$list" | wc -l); echo "$kind: $n tiles"; i=0
  for f in $list; do
    i=$((i+1)); dst="$OUT/$kind/$f"
    [ -s "$dst" ] && continue
    for attempt in 1 2 3 4; do
      curl -sS -f --retry 3 -o "$dst.part" "$BASE/fileServer/global/ETOPO2022/15s/$dir/$f" && mv "$dst.part" "$dst" && break
      sleep $((attempt*20))
    done
    [ -s "$dst" ] || echo "FAILED $f"
    [ $((i % 25)) -eq 0 ] && echo "$kind $i/$n $(du -sh $OUT/$kind | cut -f1)"
  done
done
echo "done: bed=$(ls $OUT/bed | wc -l) surface=$(ls $OUT/surface | wc -l) size=$(du -sh $OUT | cut -f1)"
