#!/bin/bash
# Show galleRE download counts per release/asset, plus the total.
# Requires the GitHub CLI (gh) to be authenticated.
REPO="hessclark/galleRE"

echo "galleRE downloads — $(date '+%Y-%m-%d %H:%M')"
echo "----------------------------------------"
gh api "repos/$REPO/releases" --jq '.[] |
  "\(.tag_name)  (\(.published_at[0:10]))",
  (.assets[] | "   • \(.name): \(.download_count)")'
echo "----------------------------------------"
total=$(gh api "repos/$REPO/releases" --jq '[.[].assets[].download_count] | add // 0')
echo "TOTAL: $total downloads"
