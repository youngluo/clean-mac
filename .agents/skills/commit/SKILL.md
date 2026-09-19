---
name: commit
description: Mandatory workflow for any task that generates a git commit or commit message. Use this skill whenever the user asks to commit changes, stage and commit, create a commit, or write a Conventional Commits/commitlint message, even if they do not explicitly say "skill".
---

## Enforcement

**This skill MUST be followed exactly. Steps MUST execute in order. Do not skip, merge, or reorder any step.**

## Format

```
<type>(<scope>): <description>
[optional body]
[optional footer(s)]
```

## Types

`feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`

## Rules

- **type**: Required, lowercase, from the list above
- **scope**: Optional. Only include when it clearly adds context (e.g. `feat(ui):` vs `feat:`). Lowercase, kebab-case if multi-word.
- **description**: Required, lowercase start, no period at end, imperative mood (what the change does, not what it did), max 72 chars
- **body**: Optional, wrap at 100 chars, explain "what" and "why" (not "how")
- **footer**: Optional, for breaking changes (`BREAKING CHANGE:`) or issue refs (`Closes #123`, `Fixes #456`)

## Breaking Changes

Append `!` to type/scope, or add `BREAKING CHANGE:` footer.

## Examples

```
feat(auth): add OAuth2 login support
fix(ui): resolve button alignment on mobile
docs: update API documentation
refactor(auth): simplify error handling logic
chore(deps): upgrade React to v19
```

## Workflow — Execute in Exact Order

1. **MANDATORY** — Run exactly `git add -A`. Before confirmation, no other `git` command is allowed, including `git config`, `git status`, `git diff`, or `git log`.
2. **MANDATORY** — Abort if the commit would use an AI author name/email, AI credentials, `Co-Authored-By`, or `--author` with an AI identity.
3. **MANDATORY** — Generate the commit message in Conventional Commits format.
4. **MANDATORY** — Output the commit message **on its own line at the END of your response**. Nothing — no explanation, no commentary, no emoji — should follow it:

   feat(auth): add OAuth2 login

5. **MANDATORY** — Wait for user confirmation. If confirmed, run only the direct `git commit` command for the generated message. If declined, stop.
