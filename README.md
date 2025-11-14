# 🐿️ Weekly Commit Extractor

A powerful macOS shell script that exports all your **Git commits from the current work week (Monday → Friday)** from **multiple repositories** into a neat text file.  
Perfect for writing weekly reports, standups, or just keeping track of what you've done across all your projects. ✨

## 📦 Features

- ✅ **Multiple repositories support** with flexible configuration
- ✅ **Configurable branches** per repository
- ✅ **Optional base path** for relative repository paths
- ✅ **Multiple email addresses support** for filtering commits
- ✅ **Configurable commit detail level** (title only or full)
- ✅ Filters commits by **your Git email** (configurable or auto-detected)
- 🗓️ Includes commits **only from Monday to Friday** of the current week
- 🕒 Adds the **date and time** before each commit
- 🧹 Flattens multi-line commit messages into a single clean line
- 📂 **Organizes output by repository and branch**
- 📁 **Separate file per repository** in organized folder structure
- 💾 **Saves reports to** `reports/<date>/` with individual `.txt` files

Example output structure:

```
reports/
└── 2025-11-08/
    ├── frontend-app.txt
    ├── backend-api.txt
    └── mobile-app.txt
```

Example file content (`frontend-app.txt`):

```markdown
# Weekly Commits Report

Repository: frontend-app
Period: 2025-11-03 to 2025-11-07
Author: you@example.com
Generated: Fri Nov 8 10:21:38 CET 2025

## Branch: main (3 commits)

04-11-2025 10:42 | feat: implement handling of decreased rates
05-11-2025 09:13 | refactor: remove unused prop
06-11-2025 14:28 | test: add new test data for rate decrease

## Branch: develop (2 commits)

07-11-2025 11:02 | fix: pick location state correctly
08-11-2025 09:30 | feat: add new API endpoint for user preferences

---

Total commits: 5
```

## 🚀 Quick Start

1. **Make script executable:**

   ```bash
   chmod +x extract-weekly-commits.sh
   ```

2. **Setup configuration:**

   ```bash
   # Edit repos.conf with your repositories
   # The file contains detailed comments and examples
   ```

3. **Run the script:**

   ```bash
   ./extract-weekly-commits.sh
   ```

4. **Find your reports in `reports/<date>/`**

## 🔧 Detailed Configuration

### 1. Setup Configuration

Create a `repos.conf` file with your repositories:

```bash
# Optional: Set base path for relative repository paths
BASE_PATH=/Users/username/projects

# User email(s) to filter commits (optional, fallback to git config)
# Use comma-separated list for multiple emails
USER_EMAIL=you@example.com
# USER_EMAIL=work@company.com,personal@gmail.com

# Commit detail level: "title" (subject only) or "full" (subject + body)
COMMIT_DETAIL=title

# Format: repo_path:branch1,branch2,branch3
# Lines starting with # are ignored

# Example with relative paths (when BASE_PATH is set above):
frontend-app:main,develop
backend-api:main,staging,feature/new-api
mobile-app:main

# Example with absolute paths:
/Users/username/projects/legacy-project:main
/Users/username/work/client-site:main,develop
```

### 2. Run the Script

```bash
./extract-weekly-commits.sh
```

### 3. Find Your Reports

Your commit reports will be saved to:

```
reports/<YYYY-MM-DD>/
├── repo1.txt
├── repo2.txt
└── repo3.txt
```

Each repository gets its own detailed report file with:

- 📋 Repository metadata and generation info
- 🌿 Commits organized by branch
- 📊 Total commit count summary

## 📋 Configuration Examples

### Scenario 1: All repos in same parent directory

```bash
# repos.conf
BASE_PATH=/Users/username/projects

frontend:main,develop
backend:main
mobile-app:main,feature/redesign
```

### Scenario 2: Mixed paths

```bash
# repos.conf
/Users/username/work/project1:main
/Users/username/personal/hobby-project:main,experimental
../other-project:main
```

### Scenario 3: Multiple branches per repo

```bash
# repos.conf
BASE_PATH=/Users/username/projects

main-project:main,develop,staging,feature/new-ui
api-service:main,v2-development
docs:main
```

## ⚙️ Requirements

- macOS (uses `date -v` syntax)
- Git repositories with configured `user.email`:
  ```bash
  git config user.email "you@example.com"
  ```
- Configuration file `repos.conf` with your repository definitions

## 🔧 Configuration Options

### Base Path

Set a common base directory for relative repository paths:

```bash
BASE_PATH=/Users/username/projects
```

### User Email

Configure which email addresses to use for filtering commits. If not specified, falls back to your git configuration:

**Single email:**

```bash
USER_EMAIL=you@example.com
```

**Multiple emails (comma-separated):**

```bash
USER_EMAIL=work@company.com,personal@gmail.com
```

The script will search for commits from all specified email addresses and merge the results. This is useful when you use different email addresses for work and personal projects.

### GitHub Hidden Email Addresses

⚠️ **Important for GitHub users**: If you have enabled "Keep my email addresses private" in your GitHub settings, your commits might be authored with a GitHub-generated email address instead of your real email.

GitHub uses the format: `<number>+<username>@users.noreply.github.com`

**How to find your GitHub hidden email:**

1. Go to [GitHub Settings → Emails](https://github.com/settings/emails)
2. Look for the email address in the format: `123456789+yourusername@users.noreply.github.com`
3. Use this email address in your configuration:

```bash
# Example with GitHub hidden email
USER_EMAIL=123456789+yourusername@users.noreply.github.com

# Or combine with your real email
USER_EMAIL=you@example.com,123456789+yourusername@users.noreply.github.com
```

**To check which email Git is currently using:**

```bash
git config user.email
```

If this shows a GitHub noreply address, make sure to use that same address in your `USER_EMAIL` configuration to properly filter your commits.

### Commit Detail Level

Control how much information is extracted from each commit:

- **`COMMIT_DETAIL=title`**: Only commit subject/title (clean, concise)

  ```
  04-11-2025 10:42 | feat: implement new feature
  05-11-2025 09:13 | fix: resolve bug in authentication
  ```

- **`COMMIT_DETAIL=full`**: Subject + body (complete information)
  ```
  04-11-2025 10:42 | feat: implement new feature Add user authentication system with JWT tokens and role-based access control
  05-11-2025 09:13 | fix: resolve bug in authentication Fixed issue where expired tokens were not properly handled
  ```

## 💡 Tips

### Include Weekends

Want to include weekends too? The script currently calculates Monday-Friday of the current week using complex conditional logic. To include weekends, you need to modify the date calculation logic around lines 50-66 in the script:

**Current logic (Monday-Friday):**

```bash
DAYS_TO_FRIDAY=$((5 - DAY_OF_WEEK))
```

**Change to (Monday-Sunday):**

```bash
DAYS_TO_FRIDAY=$((7 - DAY_OF_WEEK))
```

You'll also need to update the weekend handling logic in the `else` block that currently handles Saturday/Sunday by finding Friday of the current week.

### Default Branch

If no branches are specified in `repos.conf`, the script defaults to `main`.

## 🚨 Troubleshooting

### No repositories found

If you see: `⚠️ No repositories found to process in repos.conf`

1. Create the configuration file:
   ```bash
   # Create repos.conf with your repositories
   echo "# Add your repositories here" > repos.conf
   echo "# Format: repo_path:branch1,branch2" >> repos.conf
   ```
2. Edit `repos.conf` and add your repository entries
3. Ensure proper format: `repo_path:branch1,branch2`

### Git email not set

If you see: `⚠️ Git user.email not set`

Set your Git email globally:

```bash
git config --global user.email "your.email@example.com"
```

### Repository not found

Check that:

- Repository paths are correct (absolute or relative to BASE_PATH)
- You have read access to the repositories
- Repositories are valid Git repositories

### Branch not found

- Ensure branch names are correct (case sensitive)
- Verify branches exist: `git branch -a`
- Check if you're on the right remote

## 📁 File Structure

```
weekly-commits-export/
├── extract-weekly-commits.sh    # Main script
├── repos.conf                  # Your configuration file
└── reports/
    └── YYYY-MM-DD/
        ├── repository1.txt      # Individual repository reports
        ├── repository2.txt
        └── repository3.txt
```

### Error Handling

- Missing repositories are reported but don't stop the script
- Non-existent branches are skipped with a warning
- Invalid git repositories are skipped
- Empty repositories (no commits) don't create output files

## 🧪 Testing

The project includes a comprehensive test suite using [bats](https://bats-core.readthedocs.io/) (Bash Automated Testing System).

### Run Tests

```bash
# Run all tests (automatically installs bats if needed)
./tests/run_tests.sh

# Run specific test suites
bats tests/test_extract_commits.bats    # Core functionality tests
bats tests/test_integration.bats        # Integration scenarios
bats tests/test_performance.bats        # Performance tests (manual enable)

# Run with verbose output
bats -t tests/
```

### Test Coverage

The test suite covers:

- ✅ Configuration file parsing
- ✅ Git repository validation
- ✅ Branch existence checks
- ✅ Commit extraction and counting
- ✅ Multi-repository processing
- ✅ Error handling scenarios
- ✅ Report file generation
- ✅ Integration workflows
- ✅ Edge cases (empty repos, complex branching)

### Writing New Tests

Tests are located in `tests/` directory:

- `test_extract_commits.bats` - Core functionality
- `test_integration.bats` - End-to-end scenarios
- `test_performance.bats` - Performance benchmarks
- `helpers/test_helpers.bash` - Shared test utilities

Example test:

```bash
@test "description of what you're testing" {
    # Setup test data
    setup_test_repo "my_repo"

    # Run the script
    run bash extract-weekly-commits.sh

    # Assert results
    [ "$status" -eq 0 ]
    [[ "$output" =~ "expected string" ]]
}
```

🪶 **Powerful. Flexible. Perfect for weekly reports.**
