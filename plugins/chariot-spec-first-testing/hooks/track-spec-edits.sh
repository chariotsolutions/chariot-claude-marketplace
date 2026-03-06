#!/bin/bash
# PostToolUse hook: records timestamps when test specs or test files are modified.
# Used by check-test-spec.sh to enforce spec-first testing.
#
# State dir layout:
#   /tmp/claude-test-specs-$SESSION_ID/
#     spec/<SpecFile>.md     — timestamp of last spec edit
#     test/<TestFile>        — timestamp of last test edit

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
STATE_DIR="/tmp/claude-test-specs-$SESSION_ID"

# Track spec file edits
if [[ "$FILE_PATH" == */test-specs/*.md ]]; then
  mkdir -p "$STATE_DIR/spec"
  date +%s > "$STATE_DIR/spec/$(basename "$FILE_PATH")"
fi

# Track test file edits (Java, TypeScript, Python)
BASENAME=$(basename "$FILE_PATH")
IS_TEST=false
case "$BASENAME" in
  *Test.java)           IS_TEST=true ;;
  *.test.ts|*.test.tsx) IS_TEST=true ;;
  *.spec.ts|*.spec.tsx) IS_TEST=true ;;
  test_*.py|*_test.py)  IS_TEST=true ;;
esac

if [ "$IS_TEST" = true ]; then
  mkdir -p "$STATE_DIR/test"
  date +%s > "$STATE_DIR/test/$BASENAME"
fi

exit 0
