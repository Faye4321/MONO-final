#!/usr/bin/env bash
# Downloads the main photo of every "Picked for You" eBay listing into the
# asset catalog as pick_<itemId>, and reports which listings have ended.
#
# Run on a Mac from the repository root:
#   bash scripts/fetch_pick_images.sh
#
# Uses only curl and sips (both built into macOS). Fetches 20 pages once,
# two seconds apart. Re-running skips images that already exist.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PICKS="$ROOT/MonArchive/ShopPicks.swift"
ASSETS="$ROOT/MonArchive/Assets.xcassets"
REPORT="$ROOT/scripts/pick_images_report.csv"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ids=$(grep -oE 'itemId: "[0-9]+"' "$PICKS" | grep -oE '[0-9]+')
if [ -z "$ids" ]; then
    echo "No item IDs found in $PICKS" >&2
    exit 1
fi

echo "item_id,status,image_url" > "$REPORT"
saved=0
problems=0

for id in $ids; do
    name="pick_$id"
    dir="$ASSETS/$name.imageset"

    if [ -f "$dir/$name.jpg" ]; then
        echo "= $id already downloaded"
        echo "$id,EXISTS," >> "$REPORT"
        continue
    fi

    page="$TMP/$id.html"
    if ! curl -sL --compressed --max-time 30 -A "$UA" -o "$page" "https://www.ebay.com/itm/$id"; then
        echo "! $id could not load the listing page"
        echo "$id,FAILED," >> "$REPORT"
        problems=$((problems + 1))
        continue
    fi

    size=$(wc -c < "$page" | tr -d ' ')
    title=$(grep -o '<title>[^<]*' "$page" | head -1 | sed 's/<title>//')

    if grep -qiE "Pardon Our Interruption|Security Measure|captcha|Checking your browser|splashui" "$page"; then
        echo "! $id eBay showed a bot check (page: \"$title\"); save this image manually"
        echo "$id,BLOCKED," >> "$REPORT"
        problems=$((problems + 1))
        continue
    fi

    status="ACTIVE"
    if grep -qiE "This listing (was|has) ended|listing has ended|no longer available|This listing sold" "$page"; then
        status="ENDED"
    fi

    # Image URLs may be JSON-escaped (https:\/\/i.ebayimg.com\/...); unescape first.
    clean="$TMP/$id.clean.html"
    sed 's#\\/#/#g' "$page" > "$clean"

    # Prefer the og:image tag (attributes in either order), then a gallery
    # image, then any ebayimg photo on the page.
    url=$(grep -oE '<meta[^>]*og:image[^>]*>' "$clean" | grep -oE 'https://i\.ebayimg\.com[^"]+' | head -1)
    if [ -z "$url" ]; then
        url=$(grep -oE 'https://i\.ebayimg\.com/images/g/[^"'"'"' ?]+/s-l[0-9]+\.(jpg|jpeg|png|webp)' "$clean" | head -1)
    fi
    if [ -z "$url" ]; then
        url=$(grep -oE 'https://i\.ebayimg\.com/[^"'"'"' ?]+\.(jpg|jpeg|png|webp)' "$clean" | grep -viE 'logo|icon|sprite' | head -1)
    fi
    if [ -z "$url" ]; then
        echo "! $id no image found ($status) — got ${size} bytes, page title: \"$title\""
        echo "$id,NO_IMAGE_$status," >> "$REPORT"
        problems=$((problems + 1))
        continue
    fi

    # Ask for the large rendition.
    url=$(echo "$url" | sed -E 's/s-l[0-9]+\./s-l1600./')

    raw="$TMP/$id.img"
    if ! curl -sL --max-time 30 -A "$UA" -o "$raw" "$url"; then
        echo "! $id image download failed"
        echo "$id,DOWNLOAD_FAILED,$url" >> "$REPORT"
        problems=$((problems + 1))
        continue
    fi

    mkdir -p "$dir"
    # Convert to JPEG and cap the longest side at 1200px to keep the app small.
    if ! sips -s format jpeg -Z 1200 "$raw" --out "$dir/$name.jpg" >/dev/null 2>&1; then
        echo "! $id could not convert the image"
        rm -rf "$dir"
        echo "$id,CONVERT_FAILED,$url" >> "$REPORT"
        problems=$((problems + 1))
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

    echo "+ $id saved ($status)"
    echo "$id,$status,$url" >> "$REPORT"
    saved=$((saved + 1))
    sleep 2
done

echo
echo "Saved $saved new images. $problems need attention."
echo "Report: $REPORT"
echo "Listings marked ENDED should be replaced; send the report back."
