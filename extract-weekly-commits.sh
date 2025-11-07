#!/bin/bash

# Exit on errors
set -e

# Get the email from git config
GIT_EMAIL=$(git config user.email)
if [ -z "$GIT_EMAIL" ]; then
  echo "⚠️  Git user.email not set. Please set it with: git config user.email 'you@example.com'"
  exit 1
fi

# Compute Monday and Friday of the current week
DAY_OF_WEEK=$(date +%u) # 1 = Monday, 7 = Sunday
MONDAY=$(date -v -"$(($DAY_OF_WEEK - 1))"d +%Y-%m-%d)
FRIDAY=$(date -v +"$((5 - $DAY_OF_WEEK))"d +%Y-%m-%d)
EXPORT_DAY=$(date +%Y-%m-%d)

OUTPUT_FILE="commits-$EXPORT_DAY.txt"

echo "📦 Extracting commits by '$GIT_EMAIL' from $MONDAY to $FRIDAY..."

# Extract commits made by the current user during the week
# Include date in dd-mm-yyyy hh:mm format
git log \
  --author="$GIT_EMAIL" \
  --since="$MONDAY 00:00" \
  --until="$FRIDAY 23:59" \
  --pretty=format:"%ad | %s %b" \
  --date=format:"%d-%m-%Y %H:%M" |
  sed 's/[\r\n]\+/ /g' |       # Replace newlines inside messages with spaces
  sed 's/  */ /g' |            # Collapse multiple spaces
  sed 's/^ *//; s/ *$//' > "$OUTPUT_FILE"  # Trim leading/trailing spaces

echo "✅ Commits saved to: $OUTPUT_FILE"
