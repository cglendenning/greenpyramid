# Green Pyramid — project rules

## Never load the specification in full

The specification lives in a separate **private** repo, `~/greenpyramid-spec`, because
this repo is public and the document contains pricing, monetization strategy,
compliance analysis and sibling-app internals.

**It is ~33,500 tokens. Do not load it whole.** A PreToolUse hook enforces this:
`Read` on that file, and whole-file readers (`cat`, `less`, `bat`) applied to it in
Bash, are denied. Targeted reads are untouched.

Read it this way:

    # 1. The index — one line per directive, ~1,800 tokens
    ~/greenpyramid-spec/SPEC_INDEX.md

    # 2. Only the directives you need, ~280 tokens each
    sed -n '/^### D-030 /,/^### D-031 /p' ~/greenpyramid-spec/GREEN_PYRAMID_SPECIFICATION.md

    # 3. A release plan from Part V
    sed -n '/^### R4 /,/^### R5 /p' ~/greenpyramid-spec/GREEN_PYRAMID_SPECIFICATION.md

Budget roughly **4,000 tokens of reading per release**, not 33,500. This is directive
D-081. The hook exists because the rule was stated repeatedly and is easy to drift
from under pressure.

**If you genuinely need the whole document, ask Craig.** The guard is at
`.claude/hooks/guard-spec-read.sh`.

## The specification is the source of truth

Update it in the **same change** as the code, never in a later pass (D-085). Amend a
directive in place when intent holds; supersede with a **new** ID when a decision
reverses. Never renumber or reuse IDs. Add a Decision Log row for every reversal.

After any spec edit, regenerate and republish:

    cd ~/greenpyramid-spec && python3 spec_to_html.py

## The specification is often wrong about this codebase

Seven inaccuracies have been found so far, every one by building rather than reading:
a directive protecting dead code, wrong table names, a colour scale documented as
eight bands that is really four. **When the document and the source disagree, verify
against the source and correct the document.** Do not assume the specification is right.

## Never commit secrets

`lib/services/secrets.dart` is gitignored. Never commit it, never print its contents.
It moved during the R2 restructure and briefly lost its ignore rule — run
`git check-ignore` after moving anything sensitive.
