# Test helper functions for weekly-commits-export tests

# Setup function for creating temporary git repositories
setup_test_repo() {
    local repo_name="$1"
    local branch_name="${2:-}"  # Optional branch name
    local test_dir="${BATS_TMPDIR}/test_repos/${repo_name}"
    
    mkdir -p "$test_dir"
    cd "$test_dir"
    
    git init --quiet
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Create initial commit
    echo "Initial content" > README.md
    git add README.md
    git commit -m "Initial commit" --quiet
    
    # Rename branch if specified
    if [ -n "$branch_name" ]; then
        git branch -m "$branch_name" 2>/dev/null || true
    fi
    
    echo "$test_dir"
}

# Get the default branch name of a repository
get_default_branch() {
    local repo_path="$1"
    local current_dir=$(pwd)
    cd "$repo_path" 2>/dev/null || return 1
    local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    cd "$current_dir"
    echo "$branch"
}

# Create a commit with specific date
create_commit_with_date() {
    local message="$1"
    local date="$2"
    local random_id=$((RANDOM % 9999 + 1000))
    local file="${3:-test_file_$(date +%s)_${random_id}.txt}"
    
    echo "Content for $message at $(date)" > "$file"
    git add "$file"
    GIT_COMMITTER_DATE="$date" git commit --date="$date" -m "$message"
}

# Setup test configuration file
setup_test_config() {
    local config_file="$1"
    local base_path="$2"
    local repos="$3"
    local commit_detail="${4:-full}"
    local user_email="${5:-}"
    
    cat > "$config_file" << EOF
# Test configuration for weekly-commits-export
BASE_PATH=$base_path
COMMIT_DETAIL=$commit_detail
EOF

    # Add USER_EMAIL if specified
    if [ -n "$user_email" ]; then
        echo "USER_EMAIL=$user_email" >> "$config_file"
    fi
    
    cat >> "$config_file" << EOF

# Test repositories
$repos
EOF
}

# Cleanup function
cleanup_test_env() {
    if [ -n "${BATS_TMPDIR:-}" ]; then
        rm -rf "${BATS_TMPDIR}/test_repos"
        rm -f "${BATS_TMPDIR}/repos.conf"
        rm -rf "${BATS_TMPDIR}/reports"
    fi
}

# Mock git config
mock_git_config() {
    local email="$1"
    
    # Create a temporary git repository for configuration
    git init --quiet
    git config user.name "Test User"
    git config user.email "$email"
}

# Save and restore git configuration functions
save_git_config() {
    export ORIGINAL_GLOBAL_EMAIL=$(git config --global user.email 2>/dev/null || echo "")
    export ORIGINAL_GLOBAL_NAME=$(git config --global user.name 2>/dev/null || echo "")
    export ORIGINAL_LOCAL_EMAIL=$(git config user.email 2>/dev/null || echo "")
    export ORIGINAL_LOCAL_NAME=$(git config user.name 2>/dev/null || echo "")
}

restore_git_config() {
    # Restore global config
    if [ -n "$ORIGINAL_GLOBAL_EMAIL" ]; then
        git config --global user.email "$ORIGINAL_GLOBAL_EMAIL"
    fi
    if [ -n "$ORIGINAL_GLOBAL_NAME" ]; then
        git config --global user.name "$ORIGINAL_GLOBAL_NAME"
    fi
    
    # Restore local config
    if [ -n "$ORIGINAL_LOCAL_EMAIL" ]; then
        git config user.email "$ORIGINAL_LOCAL_EMAIL"
    fi
    if [ -n "$ORIGINAL_LOCAL_NAME" ]; then
        git config user.name "$ORIGINAL_LOCAL_NAME"
    fi
    
    # Clear environment variables
    unset ORIGINAL_GLOBAL_EMAIL ORIGINAL_GLOBAL_NAME ORIGINAL_LOCAL_EMAIL ORIGINAL_LOCAL_NAME
}

# Get current week's Monday and Friday
get_test_week_dates() {
    local day_of_week=$(date +%u)
    local days_from_monday=$((day_of_week - 1))
    local days_to_friday=$((5 - day_of_week))
    
    if [ $days_from_monday -gt 0 ]; then
        MONDAY=$(date -v -"${days_from_monday}"d +%Y-%m-%d)
    else
        MONDAY=$(date +%Y-%m-%d)
    fi
    
    if [ $days_to_friday -gt 0 ]; then
        FRIDAY=$(date -v +"${days_to_friday}"d +%Y-%m-%d)
    elif [ $days_to_friday -eq 0 ]; then
        FRIDAY=$(date +%Y-%m-%d)
    else
        local days_back=$((day_of_week - 5))
        FRIDAY=$(date -v -"${days_back}"d +%Y-%m-%d)
    fi
    
    # Calculate other days of the week
    if [ $days_from_monday -eq 1 ]; then  
        TUESDAY=$(date +%Y-%m-%d)  
    else  
        TUESDAY=$(date -v -"$((days_from_monday - 1))"d +%Y-%m-%d)  
    fi  
      
    if [ $days_from_monday -eq 2 ]; then  
        WEDNESDAY=$(date +%Y-%m-%d)  
    else  
        WEDNESDAY=$(date -v -"$((days_from_monday - 2))"d +%Y-%m-%d)  
    fi  
    
    if [ $days_from_monday -eq 3 ]; then  
        THURSDAY=$(date +%Y-%m-%d)  
    else  
        THURSDAY=$(date -v -"$((days_from_monday - 3))"d +%Y-%m-%d) 
    fi
    
    echo "MONDAY=$MONDAY"
    echo "TUESDAY=$TUESDAY"
    echo "WEDNESDAY=$WEDNESDAY"
    echo "THURSDAY=$THURSDAY"
    echo "FRIDAY=$FRIDAY"
}