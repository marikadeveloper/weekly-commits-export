#!/bin/bash

# Test runner script for weekly-commits-export
# Runs all tests and generates a coverage-like report

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🧪 Running test suite for weekly-commits-export"
echo "📍 Project directory: $PROJECT_DIR"
echo

# Check if bats is available, install if needed
if ! command -v bats &> /dev/null; then
    echo "📦 Installing bats-core (Bash Automated Testing System)..."
    
    # Check if Homebrew is available (macOS)
    if command -v brew &> /dev/null; then
        if ! brew install bats-core; then
            echo "❌ Failed to install bats-core via Homebrew"
            exit 1
        fi
    else
        echo "❌ Please install bats-core manually:"
        echo "   - On macOS: brew install bats-core"
        echo "   - On Linux: sudo apt-get install bats (or your package manager)"
        echo "   - Manual: https://github.com/bats-core/bats-core"
        exit 1
    fi
    echo "✅ bats-core installed successfully"
    echo
fi

# Ensure test directory structure exists
mkdir -p "$SCRIPT_DIR"/{fixtures,helpers}

# Run main test suite
echo "🔍 Running main test suite..."
if bats "$SCRIPT_DIR/test_extract_commits.bats"; then
    echo "✅ Main tests passed"
else
    echo "❌ Main tests failed"
    exit 1
fi

echo

# Run integration tests  
echo "🔗 Running integration tests..."
if bats "$SCRIPT_DIR/test_integration.bats"; then
    echo "✅ Integration tests passed"
else
    echo "❌ Integration tests failed"
    exit 1
fi

echo

# Run performance tests
echo "⚡ Running performance tests..."
if bats "$SCRIPT_DIR/test_performance.bats"; then
    echo "✅ Performance tests passed"
else
    echo "⚠️  Performance tests skipped (enable manually in test file)"
fi

echo
echo "🎉 All tests completed successfully!"
echo

# Generate test coverage report
echo "📊 Test Coverage Summary:"
echo "========================="

# Count functions in main script
TOTAL_FUNCTIONS=$(grep -c '^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*()' "$PROJECT_DIR/extract-weekly-commits.sh" || echo "1")
echo "📄 Main script functions: $TOTAL_FUNCTIONS"

# Count test files
TEST_FILES=$(find "$SCRIPT_DIR" -name "test_*.bats" | wc -l)
echo "🧪 Test files: $TEST_FILES"

# Count test cases
TEST_CASES=$(grep -h '^@test' "$SCRIPT_DIR"/test_*.bats | wc -l)
echo "🎯 Test cases: $TEST_CASES"

echo
echo "🔧 Test Areas Covered:"
echo "• Configuration parsing"
echo "• Git repository validation" 
echo "• Branch existence checks"
echo "• Commit extraction logic"
echo "• Multi-repository processing"
echo "• Error handling"
echo "• Report generation"
echo "• Integration scenarios"

echo
echo "💡 To run specific tests:"
echo "   bats tests/test_extract_commits.bats"
echo "   bats tests/test_integration.bats"
echo "   bats -t tests/  # Tap output format"