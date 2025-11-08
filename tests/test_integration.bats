#!/usr/bin/env bats

# Integration tests for extract-weekly-commits.sh
# These tests simulate real-world scenarios

load helpers/test_helpers

setup() {
    export BATS_TMPDIR="${BATS_TMPDIR:-$(mktemp -d)}"
    export ORIGINAL_DIR="$(pwd)"
    
    cp "${BATS_TEST_DIRNAME}/../extract-weekly-commits.sh" "${BATS_TMPDIR}/"
    cd "${BATS_TMPDIR}"
    
    mock_git_config "test@example.com"
}

teardown() {
    cd "${ORIGINAL_DIR}"
    cleanup_test_env
}

# Test: Full workflow with realistic scenario
@test "full workflow: multi-repo project with different branches" {
    # Create a realistic project structure with master branch
    local frontend_repo=$(setup_test_repo "frontend" "master")
    local backend_repo=$(setup_test_repo "backend" "master")
    
    # Frontend commits
    cd "$frontend_repo"
    eval $(get_test_week_dates)
    
    git checkout -b feature/login
    create_commit_with_date "Add login form component" "${MONDAY} 09:30:00"
    create_commit_with_date "Fix login validation" "${MONDAY} 14:15:00"
    
    git checkout master
    git merge feature/login --no-ff -m "Merge feature/login"
    create_commit_with_date "Update version to 1.2.0" "${FRIDAY} 16:00:00"
    
    # Backend commits
    cd "$backend_repo"
    create_commit_with_date "Add user authentication API" "${TUESDAY} 10:30:00"
    create_commit_with_date "Fix database connection timeout" "${WEDNESDAY} 11:45:00"
    
    git checkout -b hotfix/security
    create_commit_with_date "Security patch for auth endpoint" "${THURSDAY} 15:20:00"
    
    # Setup configuration
    cd "${BATS_TMPDIR}"
    cat > repos.conf << EOF
# Company projects
BASE_PATH=${BATS_TMPDIR}/test_repos
COMMIT_DETAIL=full

# Web application repositories
frontend:master,feature/login
backend:master,hotfix/security
EOF
    
    run bash extract-weekly-commits.sh
    [ "$status" -eq 0 ]
    
    # Verify processing messages
    [[ "$output" =~ "Using base path from config" ]]
    [[ "$output" =~ "Processing: ${BATS_TMPDIR}/test_repos/frontend" ]]
    [[ "$output" =~ "Processing: ${BATS_TMPDIR}/test_repos/backend" ]]
    
    # Verify report files
    local report_dir="reports/$(date +%Y-%m-%d)"
    [ -d "$report_dir" ]
    [ -f "$report_dir/frontend.txt" ]
    [ -f "$report_dir/backend.txt" ]
    
    # Check frontend report content
    grep -q "Repository: frontend" "$report_dir/frontend.txt"
    grep -q "Branch: master" "$report_dir/frontend.txt"
    grep -q "Branch: feature/login" "$report_dir/frontend.txt"
    grep -q "Add login form component" "$report_dir/frontend.txt"
    
    # Check backend report content
    grep -q "Repository: backend" "$report_dir/backend.txt"
    grep -q "Branch: master" "$report_dir/backend.txt"
    grep -q "Branch: hotfix/security" "$report_dir/backend.txt"
    grep -q "Security patch for auth endpoint" "$report_dir/backend.txt"
}

# Test: Edge case - Empty week (no commits)
@test "handles week with no commits gracefully" {
    # Setup repository but don't add any commits this week
    local test_repo=$(setup_test_repo "empty_repo")
    
    # Add commits from last month (outside current week)
    create_commit_with_date "Old commit" "2024-01-15 10:00:00"
    
    cd "${BATS_TMPDIR}"
    setup_test_config "repos.conf" "${BATS_TMPDIR}/test_repos" "empty_repo:master"
    
    run bash extract-weekly-commits.sh
    [ "$status" -eq 0 ]
    [[ "$output" =~ "0 repositories with commits" ]]
    
    # Report directory should be created but no individual repo files
    local report_dir="reports/$(date +%Y-%m-%d)"
    [ -d "$report_dir" ]
    [ ! -f "$report_dir/empty_repo.txt" ]
}

# Test: Complex branch structure
@test "handles complex git branching scenarios" {
    local test_repo=$(setup_test_repo "complex_repo" "master")
    cd "$test_repo"
    eval $(get_test_week_dates)
    
    # Create complex branch structure
    git checkout -b develop
    create_commit_with_date "Initial develop work" "${MONDAY} 08:00:00"
    
    git checkout -b feature/feature1
    create_commit_with_date "Feature 1 implementation" "${MONDAY} 10:00:00"
    
    git checkout develop
    git checkout -b feature/feature2
    create_commit_with_date "Feature 2 implementation" "${TUESDAY} 11:00:00"
    
    # Merge features back
    git checkout develop
    git merge feature/feature1 --no-ff -m "Merge feature1"
    git merge feature/feature2 --no-ff -m "Merge feature2"
    
    git checkout master
    create_commit_with_date "Hotfix on master" "${WEDNESDAY} 14:00:00"
    
    cd "${BATS_TMPDIR}"
    setup_test_config "repos.conf" "${BATS_TMPDIR}/test_repos" "complex_repo:master,develop,feature/feature1"
    
    run bash extract-weekly-commits.sh
    [ "$status" -eq 0 ]
    
    local report_file="reports/$(date +%Y-%m-%d)/complex_repo.txt"
    [ -f "$report_file" ]
    
    # Verify all branches are processed
    grep -q "Branch: master" "$report_file"
    grep -q "Branch: develop" "$report_file" 
    grep -q "Branch: feature/feature1" "$report_file"
    
    # Verify commits are found
    grep -q "Hotfix on master" "$report_file"
    grep -q "Initial develop work" "$report_file"
    grep -q "Feature 1 implementation" "$report_file"
}

# Test: Performance with many commits
@test "handles repository with many commits efficiently" {
    local test_repo=$(setup_test_repo "busy_repo" "master")
    cd "$test_repo"
    eval $(get_test_week_dates)
    
    # Create many commits throughout the week
    for i in {1..20}; do
        local hour=$((9 + i % 8))
        create_commit_with_date "Commit $i" "${MONDAY} ${hour}:30:00"
    done
    
    cd "${BATS_TMPDIR}"
    setup_test_config "repos.conf" "${BATS_TMPDIR}/test_repos" "busy_repo:master"
    
    # Time the execution (should complete in reasonable time)
    start_time=$(date +%s)
    run bash extract-weekly-commits.sh
    end_time=$(date +%s)
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Found 20 commits" ]]
    
    # Should complete within reasonable time (10 seconds)
    execution_time=$((end_time - start_time))
    [ "$execution_time" -lt 10 ]
    
    # Verify report is created
    local report_file="reports/$(date +%Y-%m-%d)/busy_repo.txt"
    [ -f "$report_file" ]
}

# Test: Configuration with comments and whitespace
@test "handles configuration file with comments and formatting" {
    local test_repo=$(setup_test_repo "test_repo" "master")
    cd "$test_repo"
    eval $(get_test_week_dates)
    create_commit_with_date "Test commit" "${MONDAY} 10:00:00"
    
    cd "${BATS_TMPDIR}"
    
    # Create config with various formatting
    cat > repos.conf << EOF
# Configuration for weekly commit extraction
# Base path for all repositories
BASE_PATH = ${BATS_TMPDIR}/test_repos   # Comment after value

# Output format configuration  
COMMIT_DETAIL=full # Use full commit messages

# Repository definitions
test_repo:master    # Main repository

# Empty lines and comments are ignored

EOF
    
    run bash extract-weekly-commits.sh
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Using base path from config" ]]
    [[ "$output" =~ "Found 1 commit" ]]
}