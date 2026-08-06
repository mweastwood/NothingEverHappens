---
name: code-reviewer
description: Automated PR code reviewer that performs code inspection, workspace isolation, and executes tool calls to post reviews to GitHub.
---

# Code Reviewer Skill Instructions

## 1. Workspace Isolation
Upon starting a review for a pull request (e.g., PR #`<PR_NUMBER>`):
- Create and use a dedicated directory: `/tmp/antigravity_reviews/pr_<PR_NUMBER>`
- Store all temporary files (`pr.diff`, `review.md`, `payload.json`) inside this dedicated directory to avoid workspace pollution.

---

## 2. Review Workflow & Inspection
1. **Fetch Repo & Diff**:
   - Get repo `OWNER_REPO` via `gh repo view --json nameWithOwner -q .nameWithOwner`.
   - Save PR diff via `gh pr diff <PR_NUMBER> > /tmp/antigravity_reviews/pr_<PR_NUMBER>/pr.diff`.

2. **Code Quality & Security Audit**:
   - Check for subtle bugs, logic flaws, edge cases, or broken contracts.
   - Verify security (no hardcoded secrets, credentials, or injection risks).
   - Ensure clean formatting and adherence to repository conventions.

---

## 3. Mandatory GitHub Review Submission (Tool Calls)

### A. Construct `payload.json`:
Use `write_to_file` to write `/tmp/antigravity_reviews/pr_<PR_NUMBER>/payload.json` containing:

```json
{
  "body": "## PR Review Summary\n\n[General findings, root cause analysis, summary...]",
  "event": "COMMENT",
  "comments": [
    {
      "path": "relative/path/to/file.dart",
      "line": 105,
      "side": "RIGHT",
      "body": "Line-specific feedback here.\n\n```suggestion\nreplacement code here\n```"
    }
  ]
}
```

> **Note:** If no specific inline line comments apply, set `"comments": []`.

### B. Submit via `gh api`:
Execute `run_command`:
```bash
gh api \
  --method POST \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  /repos/{OWNER_REPO}/pulls/{PR_NUMBER}/reviews \
  --input /tmp/antigravity_reviews/pr_<PR_NUMBER>/payload.json
```

---

## 4. Final Output
After Step 3.B executes via `run_command`, output ONLY:
`"Review successfully posted to GitHub PR #<PR_NUMBER>."`
