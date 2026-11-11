#!/usr/bin/env bash
# Imports listing photos saved by hand from a browser into the asset catalog.
#
# 1. Open every listing in your browser:
#      bash scripts/import_pick_images.sh --open
# 2. On each page, right-click the main photo > Save Image As…, and name it
#    pick_<itemId> (the number at the end of the page's address), e.g.
#    pick_403769716050.jpg. Save them all into one folder.
# 3. Import that folder:
#      bash scripts/import_pick_images.sh ~/Downloads/picks
#
# Uses only sips (built into macOS). Re-running replaces existing photos.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PICKS="$ROOT/MonArchive/ShopPicks.swift"
ASSETS="$ROOT/MonArchive/Assets.xcassets"

ids=$(grep -oE 'itemId: "[0-9]+"' "$PICKS" | grep -oE '[0-9]+')

if [ "${1:-}" = "--open" ]; then
    for id in $ids; do
        open "https://www.ebay.com/itm/$id"
        sleep 1
    done
    echo "Opened $(echo "$ids" | wc -w | tr -d ' ') listings. Save each main photo as pick_<itemId>."
    exit 0
fi

src="${1:-}"
if [ -z "$src" ] || [ ! -d "$src" ]; then
    echo "Usage: bash scripts/import_pick_images.sh <folder with pick_<itemId> images>"
    echo "       bash scripts/import_pick_images.sh --open"
    exit 1
fi

imported=0
missing=""

for id in $ids; do
    name="pick_$id"
    file=$(find "$src" -maxdepth 1 -type f -iname "$name.*" | head -1)
    if [ -z "$file" ]; then
        missing="$missing $id"
        continue
    fi

    dir="$ASSETS/$name.imageset"
    mkdir -p "$dir"
    # Convert to JPEG and cap the longest side at 1200px to keep the app small.
    if ! sips -s format jpeg -Z 1200 "$file" --out "$dir/$name.jpg" >/dev/null 2>&1; then
        echo "! $id could not convert $(basename "$file")"
        rm -rf "$dir"
        missing="$missing $id"
        continue
    fi

    cat > "$dir/Contents.json" <<JSON
{
  "images" : [
    {
      "filename" : "$name.jpg",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON
    echo "+ $id"
    imported=$((imported + 1))
done

echo
echo "Imported $imported photos."
if [ -n "$missing" ]; then
    echo "Missing:$missing"
    echo "Check the file names, or tell Claude which listings have ended."
fi
