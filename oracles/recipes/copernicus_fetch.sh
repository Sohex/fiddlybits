#!/bin/bash
# Fetch Copernicus DEM GLO-90 COG tiles for declared regions from the public AWS Open Data bucket (no credentials).
# Input: a tab-separated list  <region>\t<tile_id>  ; output: oracles/data/copernicus-dem-90m/<region>/<tile_id>.tif
set -u
LIST=$1; OUT=/home/cfutro/git/fiddlybits/oracles/data/copernicus-dem-90m
while IFS=$'\t' read -r region tile; do
  [ -z "$tile" ] && continue; mkdir -p "$OUT/$region"; dst="$OUT/$region/$tile.tif"
  [ -s "$dst" ] && continue
  for a in 1 2 3; do curl -sS -f --retry 3 -o "$dst.part" "https://copernicus-dem-90m.s3.amazonaws.com/$tile/$tile.tif" && mv "$dst.part" "$dst" && break; sleep $((a*10)); done
  [ -s "$dst" ] || echo "FAILED $region $tile"
done < "$LIST"
echo "done: $(find $OUT -name '*.tif' | wc -l) tiles, $(du -sh $OUT | cut -f1)"
