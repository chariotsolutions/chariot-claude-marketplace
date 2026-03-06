#!/bin/bash
# PreToolUse hook: blocks Edit/Write on test files unless the corresponding
# test-specs/*.md file was modified MORE RECENTLY in this session.
#
# Supports: Java (*Test.java), TypeScript (*.test.ts, *.spec.ts),
#           Python (test_*.py, *_test.py)

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
STATE_DIR="/tmp/claude-test-specs-$SESSION_ID"

BASENAME=$(basename "$FILE_PATH")

# Determine if this is a test file and derive the spec filename.
# Spec filename = test filename with extension replaced by .md
SPEC_FILENAME=""
case "$BASENAME" in
  *Test.java)          SPEC_FILENAME="${BASENAME%.java}.md" ;;
  *.test.ts|*.test.tsx) SPEC_FILENAME="${BASENAME%.*}.md" ;;
  *.spec.ts|*.spec.tsx) SPEC_FILENAME="${BASENAME%.*}.md" ;;
  test_*.py|*_test.py)  SPEC_FILENAME="${BASENAME%.py}.md" ;;
esac

# Not a test file — allow
if [ -z "$SPEC_FILENAME" ]; then
  exit 0
fi

SPEC_TS_FILE="$STATE_DIR/spec/$SPEC_FILENAME"
TEST_TS_FILE="$STATE_DIR/test/$BASENAME"

# Spec must have been touched at least once this session
if [ ! -f "$SPEC_TS_FILE" ]; then
  echo "BLOCKED: Spec-first testing required. Update test-specs/$SPEC_FILENAME before modifying $BASENAME. Use /chariot-spec-first-testing:test-spec-format for the spec format and workflow." >&2
  exit 2
fi

# If the test was previously edited, the spec must have been touched more recently
if [ -f "$TEST_TS_FILE" ]; then
  SPEC_TS=$(cat "$SPEC_TS_FILE")
  TEST_TS=$(cat "$TEST_TS_FILE")
  if [ "$SPEC_TS" -lt "$TEST_TS" ]; then
    echo "BLOCKED: test-specs/$SPEC_FILENAME must be updated before making further changes to $BASENAME. Use /chariot-spec-first-testing:test-spec-format for the spec format and workflow." >&2
    exit 2
  fi
fi

exit 0
