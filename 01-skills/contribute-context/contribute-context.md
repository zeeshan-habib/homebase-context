---
name: contribute-context
description: Start a contribution workflow for the homebase-context repo - pulls main, creates a branch, and gets ready to edit
disable-model-invocation: true
argument-hint: [branch-name]
---

Help the user contribute to the homebase-context repo.

## Steps

1. Check if the current working directory is inside the homebase-context repo. If not, ask the user where their local clone lives.
2. Check if `git config user.name` and `git config user.email` are set. If either is missing, ask the user to set them before continuing.
3. Check if there are any uncommitted changes or if we're on a non-main branch. If so, warn the user and ask how to proceed before continuing.
4. Switch to main: `git checkout main`
5. Pull latest: `git pull origin main`
6. Create a new branch. If the user provided a branch name via `$ARGUMENTS`, use it. Otherwise, ask what they're planning to work on and suggest a branch name.
7. Confirm the branch is created and tell the user they're ready to go. Remind them they can edit files directly or ask Claude to make edits, and when they're done to ask Claude to commit and open a PR.

## Rules

- Always create new commits. Never amend existing commits or force push - this is a shared repo.
- Before writing or editing any context file, read `context-file-style-guide.md` for authoring guidelines.
- When adding a new file, update the folder's `CLAUDE.md` index to include it.
