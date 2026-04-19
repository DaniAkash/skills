# Agentic Pipeline Integration

How to wire `angry-reviewer` as a pre-merge gate in a multi-agent workflow.

---

## Input Contract

Pass the review target as the prompt. Acceptable formats:

- Raw `git diff` output (preferred)
- File contents with filename headers
- A PR description + diff combined

The reviewer is stateless — no memory of prior reviews. Every invocation is a fresh review of exactly what's in the prompt.

---

## Output Contract

The structured review always contains a `Verdict` line in this exact form:

```
### Verdict: BLOCKED
### Verdict: APPROVED WITH CONCERNS
### Verdict: APPROVED
```

Parse this line to drive pipeline branching. Do not rely on parsing individual findings — the Verdict line is the machine-readable signal.

---

## Orchestrator Logic

```pseudocode
MAX_ITERATIONS = 3
iteration = 0

diff = get_git_diff(branch)

while iteration < MAX_ITERATIONS:
  review = angry_reviewer(diff)
  verdict = parse_verdict(review)

  if verdict == "APPROVED":
    merge(branch)
    break

  if verdict == "APPROVED WITH CONCERNS":
    attach_comment_to_pr(review)
    merge(branch)
    break

  if verdict == "BLOCKED":
    iteration += 1
    if iteration == MAX_ITERATIONS:
      escalate_to_human(branch, review)
      break
    fixed_diff = worker_agent(diff, findings=review)
    diff = fixed_diff

# Never silently skip the reviewer or bypass on timeout
```

**Key rules:**
- Never merge on `BLOCKED` — always loop back to the worker or escalate
- Cap iterations at 3 — if a worker can't fix P0s in 3 attempts, a human needs to look at it
- Attach `APPROVED WITH CONCERNS` findings as a PR comment so they're visible in review history
- Never skip the reviewer on timeout — a timeout is not an approval

---

## Passing Findings Back to the Worker

When the verdict is `BLOCKED`, extract the findings section and pass it to the worker agent alongside the original diff:

```pseudocode
findings = extract_findings_section(review)
# findings contains all [P0], [P1], etc. blocks

worker_prompt = f"""
You previously submitted this diff:

{diff}

The code reviewer found the following blocking issues:

{findings}

Fix all issues and return the corrected diff.
"""
```

The worker receives all findings at once — not one at a time — because the reviewer always surfaces everything in a single pass.

---

## Example: Claude Code Pipeline

```bash
# 1. Get the diff
git diff main..HEAD > /tmp/review_target.diff

# 2. Run the angry reviewer
claude -p "$(cat /tmp/review_target.diff)" \
  --skill angry-reviewer \
  > /tmp/review_output.txt

# 3. Parse verdict
VERDICT=$(grep "### Verdict:" /tmp/review_output.txt | awk -F': ' '{print $2}')

# 4. Branch on verdict
if [ "$VERDICT" = "APPROVED" ]; then
  gh pr merge --squash
elif [ "$VERDICT" = "APPROVED WITH CONCERNS" ]; then
  gh pr comment --body "$(cat /tmp/review_output.txt)"
  gh pr merge --squash
else
  echo "BLOCKED — review findings:"
  cat /tmp/review_output.txt
  exit 1
fi
```

---

## Notes

- The reviewer does not have access to the full codebase — only what's in the diff. If context from other files is needed for a finding, the orchestrator should include relevant file snippets alongside the diff.
- For large diffs (>500 lines), consider splitting by file and running reviews in parallel, then aggregating verdicts (most severe wins).
- The reviewer's persona is intentionally abrasive — this is a feature, not a bug. The structured output format is what matters for automation; the tone is for when humans read the review.
