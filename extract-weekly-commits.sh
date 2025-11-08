#!/bin/bash

# Exit on errors
set -e

# Configuration
CONFIG_FILE="repos.conf"
BASE_PATH=""  # Will be read from config file

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
  echo "⚠️  Configuration file '$CONFIG_FILE' not found!"
  echo "📝 Please create it with format: repo_path:branch1,branch2"
  echo "💡 Example:"
  echo "   # BASE_PATH=/Users/username/projects"
  echo "   project1:main,develop"
  echo "   frontend-app:main"
  exit 1
fi

COMMIT_DETAIL="full"  # Default to full commit details

while IFS= read -r line; do
  # Read BASE_PATH
  if [[ "$line" =~ ^[[:space:]]*BASE_PATH[[:space:]]*=[[:space:]]*(.+)[[:space:]]*$ ]]; then
    BASE_PATH="${BASH_REMATCH[1]}"
    # Remove any trailing comments
    BASE_PATH=$(echo "$BASE_PATH" | sed 's/#.*$//' | sed 's/[[:space:]]*$//')
    echo "🔧 Using base path from config: $BASE_PATH"
  fi
  
  # Read COMMIT_DETAIL
  if [[ "$line" =~ ^[[:space:]]*COMMIT_DETAIL[[:space:]]*=[[:space:]]*(.+)[[:space:]]*$ ]]; then
    COMMIT_DETAIL="${BASH_REMATCH[1]}"
    # Remove any trailing comments
    COMMIT_DETAIL=$(echo "$COMMIT_DETAIL" | sed 's/#.*$//' | sed 's/[[:space:]]*$//')
    echo "🔧 Commit detail level: $COMMIT_DETAIL"
  fi
done < "$CONFIG_FILE"

# Get the email from git config
GIT_EMAIL=$(git config user.email 2>/dev/null || echo "")
if [ -z "$GIT_EMAIL" ]; then
  echo "⚠️  Git user.email not set. Please set it with: git config user.email 'you@example.com'"
  exit 1
fi

# Compute Monday and Friday of the current week
DAY_OF_WEEK=$(date +%u) # 1 = Monday, 7 = Sunday
DAYS_FROM_MONDAY=$((DAY_OF_WEEK - 1))
DAYS_TO_FRIDAY=$((5 - DAY_OF_WEEK))

if [ $DAYS_FROM_MONDAY -gt 0 ]; then
  MONDAY=$(date -v -"${DAYS_FROM_MONDAY}"d +%Y-%m-%d)
else
  MONDAY=$(date +%Y-%m-%d)
fi

if [ $DAYS_TO_FRIDAY -gt 0 ]; then
  FRIDAY=$(date -v +"${DAYS_TO_FRIDAY}"d +%Y-%m-%d)
elif [ $DAYS_TO_FRIDAY -eq 0 ]; then
  FRIDAY=$(date +%Y-%m-%d)
else
  # If it's weekend, get Friday of current week
  DAYS_BACK=$((DAY_OF_WEEK - 5))
  FRIDAY=$(date -v -"${DAYS_BACK}"d +%Y-%m-%d)
fi

EXPORT_DAY=$(date +%Y-%m-%d)

# Create reports directory structure
REPORTS_DIR="reports/$EXPORT_DAY"
mkdir -p "$REPORTS_DIR"

echo "📦 Extracting commits by '$GIT_EMAIL' from $MONDAY to $FRIDAY..."
echo "📁 Reports will be saved to: $REPORTS_DIR"
echo ""

# Counter for processed repositories
PROCESSED_REPOS=0

# Function to extract commits from a repository
extract_repo_commits() {
  local repo_path="$1"
  local branches="$2"
  local full_path="$repo_path"
  
  # Construct full path if BASE_PATH is set
  if [ -n "$BASE_PATH" ] && [[ "$repo_path" != /* ]]; then
    full_path="$BASE_PATH/$repo_path"
  fi
  
  # Check if repository exists
  if [ ! -d "$full_path" ]; then
    echo "⚠️  Repository not found: $full_path"
    return 1
  fi
  
  # Check if it's a git repository
  if [ ! -d "$full_path/.git" ]; then
    echo "⚠️  Not a git repository: $full_path"
    return 1
  fi
  
  echo "📂 Processing: $full_path"
  
  # Create output file for this repository
  local repo_name=$(basename "$repo_path")
  local repo_output_file="$REPORTS_DIR/${repo_name}.txt"
  
  # Initialize the repository file with header
  echo "# Weekly Commits Report" > "$repo_output_file"
  echo "Repository: $repo_path" >> "$repo_output_file"
  echo "Period: $MONDAY to $FRIDAY" >> "$repo_output_file"
  echo "Author: $GIT_EMAIL" >> "$repo_output_file"
  echo "Generated: $(date)" >> "$repo_output_file"
  echo "" >> "$repo_output_file"
  
  local total_commits=0
  
  # Convert comma-separated branches to array
  IFS=',' read -ra BRANCH_ARRAY <<< "$branches"
  
  for branch in "${BRANCH_ARRAY[@]}"; do
    # Trim whitespace
    branch=$(echo "$branch" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    echo "  🌿 Checking branch: $branch"
    
    # Change to repository directory and extract commits
    pushd "$full_path" > /dev/null
    
    # Check if branch exists
    if ! git rev-parse --verify "$branch" >/dev/null 2>&1; then
      echo "    ⚠️  Branch '$branch' not found in $repo_path"
      popd > /dev/null
      continue
    fi
    
    # Extract commits for this branch with appropriate format
    local git_format=""
    if [ "$COMMIT_DETAIL" = "title" ]; then
      git_format="%ad | %s"
    else
      git_format="%ad | %s %b"
    fi
    
    # Count commits first (before text processing)
    local commit_count=$(git rev-list \
      --author="$GIT_EMAIL" \
      --since="$MONDAY 00:00" \
      --until="$FRIDAY 23:59" \
      --count \
      "$branch" 2>/dev/null)
    
    # Get formatted commit text
    local commits=$(git log \
      --author="$GIT_EMAIL" \
      --since="$MONDAY 00:00" \
      --until="$FRIDAY 23:59" \
      --pretty=format:"$git_format" \
      --date=format:"%d-%m-%Y %H:%M" \
      "$branch" 2>/dev/null | \
      sed 's/[\r\n]\+/ /g' | \
      sed 's/  */ /g' | \
      sed 's/^ *//; s/ *$//')
    
    popd > /dev/null
    
    # Add commits to repository-specific file
    if [ -n "$commits" ] && [ "$commit_count" -gt 0 ]; then
      if [ "$commit_count" -eq 1 ]; then
        echo "## Branch: $branch ($commit_count commit)" >> "$repo_output_file"
        echo "    ✅ Found $commit_count commit on $branch"
      else
        echo "## Branch: $branch ($commit_count commits)" >> "$repo_output_file"
        echo "    ✅ Found $commit_count commits on $branch"
      fi
      echo "" >> "$repo_output_file"
      echo "$commits" >> "$repo_output_file"
      echo "" >> "$repo_output_file"
      total_commits=$((total_commits + commit_count))
    else
      echo "    ℹ️  No commits found on $branch"
    fi
  done
  
  # Add summary to repository file
  if [ $total_commits -gt 0 ]; then
    echo "---" >> "$repo_output_file"
    echo "Total commits: $total_commits" >> "$repo_output_file"
    if [ "$total_commits" -eq 1 ]; then  
      echo "Total commit: $total_commits" >> "$repo_output_file"  
      echo "📄 Repository report saved: $repo_output_file ($total_commits commit)"  
    else  
      echo "Total commits: $total_commits" >> "$repo_output_file"  
      echo "📄 Repository report saved: $repo_output_file ($total_commits commits)"  
    fi 
  else
    echo "ℹ️  No commits found in $repo_path"
    rm "$repo_output_file"  # Remove empty file
  fi
  
  echo ""
}

# Read configuration file and process repositories
while IFS=':' read -r repo_path branches; do
  # Skip empty lines, comments, and configuration variables
    if [ -z "$repo_path" ] || [[ "$repo_path" =~ ^[[:space:]]*# ]] || [[ "$repo_path" =~ ^[[:space:]]*BASE_PATH[[:space:]]*= ]] || [[ "$repo_path" =~ ^[[:space:]]*COMMIT_DETAIL[[:space:]]*=.*[[:space:]]*$ ]]; then  
    continue
  fi
  
  # Remove leading/trailing whitespace
  repo_path=$(echo "$repo_path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  branches=$(echo "$branches" | sed 's/#.*$//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  
  # Default to 'main' if no branches specified
  if [ -z "$branches" ]; then
    branches="main"
  fi
  
  # Call extract_repo_commits and continue even if it fails
  if extract_repo_commits "$repo_path" "$branches"; then
    PROCESSED_REPOS=$((PROCESSED_REPOS + 1))
  fi
  
done < "$CONFIG_FILE"

# Final summary message
if [ $PROCESSED_REPOS -eq 0 ]; then
  echo "⚠️  No repositories found to process in $CONFIG_FILE"
  echo "💡 Please add repository configurations or copy from repos.conf.example"
  echo "📝 Format: repo_path:branch1,branch2"
else
  echo "✅ All repository reports saved to: $REPORTS_DIR"
  if [ "$PROCESSED_REPOS" -eq 1 ]; then  
    REPO_WORD="repository"  
  else  
    REPO_WORD="repositories"  
  fi  
  echo "📊 Weekly summary generated for $MONDAY to $FRIDAY ($PROCESSED_REPOS $REPO_WORD processed)" 
fi