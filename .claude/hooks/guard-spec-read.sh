#!/usr/bin/env bash
# PreToolUse guard: block whole-file reads of the Green Pyramid specification.
#
# The specification is ~33,500 tokens. Loading it wholesale burns context that
# belongs to the task. D-081 requires reading SPEC_INDEX.md (~1,800 tokens) and
# then only the directives needed (~280 tokens each).
#
# Targeted reads stay allowed: sed -n ranges, grep, awk, head, tail, wc.
#
# Matching is done with grep -E, which works line by line. That is deliberate:
# a heredoc writing documentation may mention both "cat" and the spec filename
# on different lines without intending to read it. The reader and the filename
# must appear together on one line, in one command segment.
set -uo pipefail

payload=$(cat)
tool=$(printf '%s' "$payload" | jq -r '.tool_name // ""')

SPEC_NAME='GREEN_PYRAMID_SPECIFICATION\.md'
WHOLE_FILE_READ="(^|[|;&[:space:]])(cat|less|more|bat|pbcopy|open)[[:space:]][^|;&]*${SPEC_NAME}"

ADVICE='Read ~/greenpyramid-spec/SPEC_INDEX.md instead (~1,800 tokens), then extract only what you need:
  sed -n '"'"'/^### D-030 /,/^### D-031 /p'"'"' ~/greenpyramid-spec/GREEN_PYRAMID_SPECIFICATION.md
grep, sed, head and tail are all allowed. Ask Craig if you genuinely need the whole document.'

deny() {
  jq -n --arg r "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
  exit 0
}

case "$tool" in
  Read)
    path=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // ""')
    if printf '%s' "$path" | grep -Eq "$SPEC_NAME"; then
      deny "The Read tool loads the whole specification (~33,500 tokens). D-081 forbids this.
${ADVICE}"
    fi
    ;;
  Bash)
    cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // ""')
    if printf '%s' "$cmd" | grep -Eq "$WHOLE_FILE_READ"; then
      deny "That reads the whole specification (~33,500 tokens). D-081 forbids it.
${ADVICE}"
    fi
    ;;
esac
exit 0
