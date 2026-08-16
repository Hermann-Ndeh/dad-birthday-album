#!/usr/bin/env bash
# scripts/upload.sh
#
# Uploads photos to S3 and regenerates photos.json manifest.
#
# Usage:
#   1. Put your photos in a local folder (default: ./uploads)
#   2. Set BUCKET and REGION below
#   3. chmod +x scripts/upload.sh && ./scripts/upload.sh
#
# Requirements: AWS CLI configured with credentials that can write to the bucket.

set -euo pipefail

BUCKET="thembuas"
REGION="us-east-1"  # confirmed
UPLOADS_DIR="./uploads"
BASE_URL="https://${BUCKET}.s3.${REGION}.amazonaws.com"

if [ ! -d "$UPLOADS_DIR" ]; then
  echo "Create an 'uploads' folder and put your photos in it first."
  exit 1
fi

echo "→ Uploading photos to s3://${BUCKET}/photos/ ..."
aws s3 sync "$UPLOADS_DIR" "s3://${BUCKET}/photos/" \
  --exclude "*" \
  --include "*.jpg" --include "*.jpeg" \
  --include "*.png" --include "*.webp" \
  --region "$REGION"

echo "→ Building photos.json manifest ..."
MANIFEST="["
FIRST=true
while IFS= read -r key; do
  [ -z "$key" ] && continue
  ENTRY="{\"src\":\"${BASE_URL}/photos/${key}\",\"alt\":\"\"}"
  if [ "$FIRST" = true ]; then
    MANIFEST="${MANIFEST}${ENTRY}"
    FIRST=false
  else
    MANIFEST="${MANIFEST},${ENTRY}"
  fi
done < <(aws s3 ls "s3://${BUCKET}/photos/" --region "$REGION" \
  | awk '{print $4}' \
  | grep -iE '\.(jpg|jpeg|png|webp)$' \
  | sort)
MANIFEST="${MANIFEST}]"

echo "$MANIFEST" > /tmp/photos.json

echo "→ Uploading manifest to s3://${BUCKET}/photos.json ..."
aws s3 cp /tmp/photos.json "s3://${BUCKET}/photos.json" \
  --region "$REGION" \
  --content-type "application/json"

COUNT=$(echo "$MANIFEST" | grep -o '"src"' | wc -l | tr -d ' ')
echo "✓ Done — ${COUNT} photo(s) in manifest."
echo "  Manifest: ${BASE_URL}/photos.json"
