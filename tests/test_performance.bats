#!/usr/bin/env bats

# Performance and stress tests for extract-weekly-commits.sh

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

# Test: Large number of repositories
@test "handles many repositories efficiently" {
    eval $(get_test_week_dates)
    
    # Create 10 test repositories with master branch
    local config_content="BASE_PATH=${BATS_TMPDIR}/test_repos"$'\n'"COMMIT_DETAIL=title"$'\n'
    
    for i in {1..10}; do
        local test_repo=$(setup_test_repo "repo$i" "master")
        cd "$test_repo"
        create_commit_with_date "Commit in repo $i" "${MONDAY} 10:$(printf '%02d' $i):00"
        config_content+="repo$i:master"$'\n'
    done
    
    cd "${BATS_TMPDIR}"
    echo "$config_content" > repos.conf
    
    run timeout 30 bash extract-weekly-commits.sh
    [ "$status" -eq 0 ]
    [[ "$output" =~ "10 repositories processed" ]]
}

# Test: Repository with very long history
@test "performs well with repository having long history" {
    local test_repo=$(setup_test_repo "history_repo" "master")
    cd "$test_repo"
    eval $(get_test_week_dates)
    
    # Create old history (should not affect performance much)
    for i in {1..100}; do
        create_commit_with_date "Old commit $i" "2020-01-$((i % 28 + 1)) 10:00:00"
    done
    
    # Create current week commits
    create_commit_with_date "Current week commit" "${MONDAY} 10:00:00"
    
    cd "${BATS_TMPDIR}"
    setup_test_config "repos.conf" "${BATS_TMPDIR}/test_repos" "history_repo:master"
    
    start_time=$(date +%s)
    run bash extract-weekly-commits.sh
    end_time=$(date +%s)
    
    [ "$status" -eq 0 ]
    
    # Should still be fast despite long history
    execution_time=$((end_time - start_time))
    [ "$execution_time" -lt 5 ]
}