#!/usr/bin/env bash
set -euo pipefail

# Test framework for morse.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MORSE_SCRIPT="$SCRIPT_DIR/morse.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test helper functions
run_test() {
    local test_name="$1"
    local input="$2"
    local expected="$3"
    local args="${4:-}"

    TESTS_RUN=$((TESTS_RUN + 1))

    printf "Test %d: %s... " "$TESTS_RUN" "$test_name"

    local actual
    if [ -n "$args" ]; then
        actual=$(echo "$input" | bash "$MORSE_SCRIPT" $args 2>&1)
    else
        actual=$(echo "$input" | bash "$MORSE_SCRIPT" 2>&1)
    fi
    local exit_code=$?

    if [ $exit_code -ne 0 ]; then
        printf "${RED}ERROR (exit code $exit_code)${NC}\n"
        echo "  Input: '$input'"
        echo "  Args: '$args'"
        echo "  Output: '$actual'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi

    if [ "$actual" = "$expected" ]; then
        printf "${GREEN}PASS${NC}\n"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        printf "${RED}FAIL${NC}\n"
        echo "  Input: '$input'"
        echo "  Args: '$args'"
        echo "  Expected: '$expected'"
        echo "  Actual:   '$actual'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test helper for command line arguments
run_cmdline_test() {
    local test_name="$1"
    local text_arg="$2"
    local expected="$3"
    local extra_args="${4:-}"

    TESTS_RUN=$((TESTS_RUN + 1))

    printf "Test %d: %s... " "$TESTS_RUN" "$test_name"

    local actual
    if [ -n "$extra_args" ]; then
        actual=$(bash "$MORSE_SCRIPT" "$text_arg" $extra_args 2>&1)
    else
        actual=$(bash "$MORSE_SCRIPT" "$text_arg" 2>&1)
    fi
    local exit_code=$?

    if [ $exit_code -ne 0 ]; then
        printf "${RED}ERROR (exit code $exit_code)${NC}\n"
        echo "  Text arg: '$text_arg'"
        echo "  Extra args: '$extra_args'"
        echo "  Output: '$actual'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi

    if [ "$actual" = "$expected" ]; then
        printf "${GREEN}PASS${NC}\n"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        printf "${RED}FAIL${NC}\n"
        echo "  Text arg: '$text_arg'"
        echo "  Extra args: '$extra_args'"
        echo "  Expected: '$expected'"
        echo "  Actual:   '$actual'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test summary
print_summary() {
    echo
    echo "=================="
    echo "Test Summary:"
    echo "  Tests run: $TESTS_RUN"
    printf "  Passed: ${GREEN}$TESTS_PASSED${NC}\n"
    printf "  Failed: ${RED}$TESTS_FAILED${NC}\n"
    echo "=================="

    if [ $TESTS_FAILED -eq 0 ]; then
        printf "${GREEN}All tests passed!${NC}\n"
        exit 0
    else
        printf "${RED}$TESTS_FAILED test(s) failed.${NC}\n"
        exit 1
    fi
}

# Trap to ensure summary is always printed
trap print_summary EXIT

echo "Running Morse Code Tests..."
echo "=========================="

# Test 1: Basic English to Morse
run_test "Basic English to Morse" \
    "HELLO" \
    ".... . .-.. .-.. ---"

# Test 2: Basic Morse to English
run_test "Basic Morse to English" \
    ".... . .-.. .-.. ---" \
    "HELLO"

# Test 3: English with spaces (word boundaries)
run_test "English with spaces" \
    "HELLO WORLD" \
    $'.... . .-.. .-.. --- \x1F .-- --- .-. .-.. -..'

# Test 4: Morse with word boundaries
run_test "Morse with word boundaries" \
    ".... . .-.. .-.. --- $'\x1F' .-- --- .-. .-.. -.." \
    "HELLO WORLD"

# Test 5: Mixed case English
run_test "Mixed case English" \
    "Hello World" \
    ".... . .-.. .-.. --- $'\x1F' .-- --- .-. .-.. -.."

# Test 6: Numbers
run_test "Numbers in English" \
    "123" \
    ".---- ..--- ...--"

# Test 7: Numbers in Morse
run_test "Numbers in Morse" \
    ".---- ..--- ...--" \
    "123"

# Test 8: Sentence delimiters
run_test "Sentence with punctuation" \
    "Hello! How are you?" \
    ".... . .-.. .-.. --- / $'\x1F' .... --- .-- $'\x1F' .- .-. . $'\x1F' -.-- --- ..- /"

# Test 9: Multiple punctuation
run_test "Multiple punctuation marks" \
    "End... New!!! Start???" \
    ". -. -.. / -. . .-- / ... - .- .-. -"

# Test 10: Whitespace normalization
run_test "Whitespace normalization" \
    "HELLO    WORLD" \
    ".... . .-.. .-.. --- $'\x1F' .-- --- .-. .-.. -.."

# Test 11: Newlines and tabs
run_test "Newlines and tabs" \
    $'HELLO\tWORLD\nTEST' \
    ".... . .-.. .-.. --- $'\x1F' .-- --- .-.. .-.. -.. $'\x1F' - . ... -"

# Test 12: Empty input
run_test "Empty input" \
    "" \
    ""

# Test 13: Only spaces
run_test "Only spaces" \
    "   " \
    ""

# Test 14: Custom sentence delimiter
run_test "Custom sentence delimiter" \
    "Hello! World?" \
    ".... . .-.. .-.. --- // .-- --- .-. .-.. -.." \
    "--sentence-delim=//"

# Test 15: Custom word boundary
run_test "Custom word boundary" \
    "HELLO WORLD" \
    ".... . .-.. .-.. --- | .-- --- .-. .-.. -.." \
    "--word-boundary=|"

# Test 16: Custom unknown token
run_test "Custom unknown token" \
    "....." \
    "X" \
    "--unknown=X"

# Test 17: Unknown Morse code
run_test "Unknown Morse code" \
    ".-.-.-" \
    "?"

# Test 18: Mixed valid and invalid Morse
run_test "Mixed valid/invalid Morse" \
    ".- .-.-.- -..." \
    "A?B"

# Test 19: Non-Morse tokens in Morse input
run_test "Non-Morse tokens" \
    ".- ABC -..." \
    "A?B"

# Test 20: Punctuation removal from English
run_test "Punctuation removal" \
    "Hello, world! @#$" \
    ".... . .-.. .-.. --- / .-- --- .-. .-.. -.."

# Test 21: All letters A-Z
run_test "All letters A-Z" \
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ" \
    ".- -... -.-. -.. . ..-. --. .... .. .--- -.- .-.. -- -. --- .--. --.- .-. ... - ..- ...- .-- -..- -.-- --.."

# Test 22: All digits 0-9
run_test "All digits 0-9" \
    "0123456789" \
    "----- .---- ..--- ...-- ....- ..... -.... --... ---.. ----."

# Test 23: Reverse all letters (Morse to English)
run_test "All Morse letters to English" \
    ".- -... -.-. -.. . ..-. --. .... .. .--- -.- .-.. -- -. --- .--. --.- .-. ... - ..- ...- .-- -..- -.-- --.." \
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

# Test 24: Reverse all digits (Morse to English)
run_test "All Morse digits to English" \
    "----- .---- ..--- ...-- ....- ..... -.... --... ---.. ----." \
    "0123456789"

# Test 25: Complex sentence
run_test "Complex sentence" \
    "The quick brown fox jumps over the lazy dog!" \
    "- .... . / --.- ..- .. -.-. -.- $'\x1F' -... .-. --- .-- -. $'\x1F' ..-. --- -..- $'\x1F' .--- ..- -- .--. ... $'\x1F' --- ...- . .-. $'\x1F' - .... . $'\x1F' .-.. .- --.. -.-- $'\x1F' -.. --- --."

echo
echo "All STDIN tests completed. Now testing command line arguments..."

# ========================================
# COMMAND LINE ARGUMENT TESTS
# ========================================

# Test 26: Basic English to Morse via command line
run_cmdline_test "Cmdline: Basic English to Morse" \
    "HELLO" \
    ".... . .-.. .-.. ---"

# Test 27: Basic Morse to English via command line
run_cmdline_test "Cmdline: Basic Morse to English" \
    ".... . .-.. .-.. ---" \
    "HELLO"

# Test 28: English with spaces via command line
run_cmdline_test "Cmdline: English with spaces" \
    "HELLO WORLD" \
    ".... . .-.. .-.. --- $'\x1F' .-- --- .-. .-.. -.."

# Test 29: Morse with word boundaries via command line
run_cmdline_test "Cmdline: Morse with word boundaries" \
    ".... . .-.. .-.. --- $'\x1F' .-- --- .-. .-.. -.." \
    "HELLO WORLD"

# Test 30: Mixed case English via command line
run_cmdline_test "Cmdline: Mixed case English" \
    "Hello World" \
    ".... . .-.. .-.. --- $'\x1F' .-- --- .-. .-.. -.."

# Test 31: Numbers via command line
run_cmdline_test "Cmdline: Numbers in English" \
    "123" \
    ".---- ..--- ...--"

# Test 32: Sentence with punctuation via command line
run_cmdline_test "Cmdline: Sentence with punctuation" \
    "Hello! How are you?" \
    ".... . .-.. .-.. --- / .... --- .-- $'\x1F' .- .-. . $'\x1F' -.-- --- ..-"

# Test 33: Custom sentence delimiter via command line
run_cmdline_test "Cmdline: Custom sentence delimiter" \
    "Hello! World?" \
    ".... . .-.. .-.. --- // .-- --- .-. .-.. -.." \
    "--sentence-delim=//"

# Test 34: Custom word boundary via command line
run_cmdline_test "Cmdline: Custom word boundary" \
    "HELLO WORLD" \
    ".... . .-.. .-.. --- | .-- --- .-. .-.. -.." \
    "--word-boundary=|"

# Test 35: Custom unknown token via command line
run_cmdline_test "Cmdline: Custom unknown token" \
    "....." \
    "X" \
    "--unknown=X"

# Test 36: Complex sentence via command line
run_cmdline_test "Cmdline: Complex sentence" \
    "The quick brown fox!" \
    "- .... . / --.- ..- .. -.-. -.- $'\x1F' -... .-. --- .-- -. $'\x1F' ..-. --- -..-"

# Test 37: Empty string via command line
run_cmdline_test "Cmdline: Empty string" \
    "" \
    ""

# Test 38: Multiple options via command line
run_cmdline_test "Cmdline: Multiple options" \
    "Hi! Bye?" \
    ".... .. // -... -.-- ." \
    "--sentence-delim=// --unknown=X"

# Test 39: Pipeline behavior - the specific issue from the problem statement
run_test "Pipeline: morse.sh piped to morse.sh" \
    "- . ... - $'\x1F' - . ... -" \
    "TEST TEST"

# Test 40: Verify no backslash warnings in pipeline (this is a regression test)
TESTS_RUN=$((TESTS_RUN + 1))
printf "Test %d: Pipeline: no backslash warnings... " "$TESTS_RUN"
pipeline_output=$(bash "$MORSE_SCRIPT" "test test" 2>&1 | bash "$MORSE_SCRIPT" 2>&1)
if [[ "$pipeline_output" == *"warning"* ]]; then
    printf "${RED}FAIL - Warning detected${NC}\n"
    echo "  Output: '$pipeline_output'"
    TESTS_FAILED=$((TESTS_FAILED + 1))
elif [ "$pipeline_output" = "TEST TEST" ]; then
    printf "${GREEN}PASS${NC}\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf "${RED}FAIL - Wrong output${NC}\n"
    echo "  Expected: 'TEST TEST'"
    echo "  Actual:   '$pipeline_output'"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo
echo "All command line argument tests completed."
