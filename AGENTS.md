# AGENTS.md – Project Rules for Agentic Development

## Tool Preferences (important for /goal and subagents)

- Prefer the built-in **Write** and **Edit** tools over shell commands when creating or updating files.
- Do **not** use `cat <<EOF > file`, `cat > file <<EOF`, or similar here-document patterns to write JSON, results, reports, or scratch files.
- Using shell here-documents (`cat <<EOF`, `tee`, etc.) to write files is discouraged and should be avoided unless the Write tool is unavailable.
- When a skeptic agent (or any subagent) needs to save analysis/results, use the Write tool directly to the target path (including Grok scratch/temporary locations).
- Shell `cat` is acceptable only for simple reading of existing files, not for writing content.

## Git

- **Always commit new work after an appropriate milestone is met** (feature complete, tests green, docs/TODO updated, or a clearly finished subtask). Do not leave substantial finished work uncommitted waiting for a later prompt.
- Do not commit `.DS_Store` or other OS junk.
- Prefer small, focused commits with complete-sentence messages explaining *why*.
- If a git repository is not present in the project root, run `git init` immediately and install git-lfs, and then configure lfs to track binary file types common for large assets in the project.

### Branching Strategy (Mandatory for Agents)

Agents **must** follow this workflow. Direct commits to `main` are forbidden except for trivial one-line fixes that do not touch multiple files or critical configuration.

1. **Default branch** is `main`. It must always be in a buildable, validation-passing state.
2. **Feature / task branches**  
   - Create before any non-trivial work:  
     `git checkout -b feature/<short-kebab-description>`  
     or `git checkout -b fix/<short-kebab-description>`  
   - Name must be descriptive and kebab-case. Examples:  
     `feature/user-auth-flow`  
     `feature/data-pipeline-polish`  
     `fix/silent-null-handling`
3. **Release branches** (only when preparing a tagged build):  
   `release/vX.Y.Z` (or `release/0.3.0-alpha` etc.).  
   These are short-lived. Only bugfixes and version bumps land here.
4. **Hotfix branches** (production-critical only):  
   `hotfix/<description>` → merge to both `main` and the active release branch.

### Working on a Branch

- Always start from an up-to-date `main`:  
  `git checkout main && git pull --ff-only && git checkout -b feature/...`
- Keep the branch short-lived (hours to a couple of days of agent work). Long-lived branches are discouraged.
- After every meaningful change, run the full project validation (tests, lint, type-check, format, etc. as applicable) **on the feature branch** before committing.
- Commit messages stay imperative and explain *why*, not just *what*. Prefer Conventional Commits style when it fits:  
  `feat: add user authentication flow`  
  `fix: prevent null pointer on missing config`  
  `chore: update INDEX.md with new systems doc`

### Merging Back to `main` (proactive branch hygiene)

Agents do **not** force-push or rewrite `main` history.

**Default posture: merge completed work without waiting to be asked.** When a feature, fix, chore, or other scoped task is **done** — acceptance criteria met, validation green, commits in good shape, no intentional follow-ups left on that branch — agents **must** integrate it into `main` promptly as part of finishing the task. Do not leave finished branches unmerged for the user to discover later.

“Done enough to merge” means all of the following:
- The branch’s scoped work is complete (not a half-implemented WIP commit)
- Project validation passes on the branch
- No known blockers that would leave `main` broken or misleading
- The agent is not mid-plan with more checklist items still required for that same branch

Preferred path (when the environment supports it):
1. Ensure the feature branch is clean and validation passes.
2. `git checkout main && git pull --ff-only`
3. `git merge --no-ff feature/<name>` (or `git rebase main` then fast-forward if the history is linear and the agent is confident).
4. Re-run validation on `main` after the merge.
5. Only then delete the feature branch: `git branch -d feature/<name>`
6. Push `main` to `origin` when a remote is configured and the environment allows it (this repo is single-user; do not force-push).

If a pull-request / code-review flow is active in the repo, prefer opening a PR instead of a local merge — but still treat “open a ready PR” as the completion step, not parking an unmerged branch silently. Agents should leave the branch in a review-ready state (validation green, clear commit messages, no WIP commits).

**Do not merge** when work is incomplete, validation fails, or the user explicitly asked to keep the change on a branch / unmerged. In those cases, leave the branch as-is and state what remains.

### Conflict & Safety Rules

- Never resolve merge conflicts by blindly accepting “ours” or “theirs” on files that contain critical identifiers, configuration, generated references, binary data, or complex structured formats that text merges can corrupt. Prefer regenerating or carefully reconciling such files after the textual conflict is cleaned.
- If a conflict touches complex structured files (configs, schemas, serialized data), treat it as a high-risk change: re-validate thoroughly before considering the merge done.
- Agents must not `git push --force` to `main` or to any shared branch.
- When in doubt about completeness or safety, leave the feature branch unmerged and document the exact state + remaining work in the commit message or a short note in `INDEX.md` / the relevant design doc — but do **not** use “when in doubt” as an excuse to skip merging clearly finished work.

### LFS & Binary Hygiene

After any branch that adds large assets or binaries, verify `git lfs status` and that `.gitattributes` still covers the expected extensions before merging to `main`.

## Project Knowledge Index

Before making design, architecture, or other high-level decisions, agents **must** consult `INDEX.md` (project root).

- `INDEX.md` is the single source of truth for the location and purpose of all major project documents (architecture notes, design docs, API contracts, roadmaps, etc.).
- Read the relevant documents listed there when the task requires broader context.
- If `INDEX.md` does not exist, create a minimal stub and populate it as documents are added.
- If `INDEX.md` references any files that do not yet exist, the agent should create minimal stubs for those files (with a clear header describing their intended purpose) rather than inventing content or treating their absence as a blocker.
- Documents referenced in `INDEX.md` should be maintained and kept up to date as the project progresses. When an agent makes a lasting design, architecture, or systems decision, it should update the relevant indexed document (or create/update an entry in `INDEX.md` if a new document is warranted).
- Do not invent design decisions that are already documented elsewhere — prefer the indexed sources.

### Read-Only Documents

If `READONLY.md` exists in the project root, treat it similarly to `INDEX.md`: it lists important documents and their purposes.

- The agent **must not modify** any files listed in `READONLY.md`.
- The user may edit those files outside of agent sessions. Therefore, agents should re-consult the relevant read-only documents as needed (especially at the start of a new task or when design constraints may have changed) rather than relying solely on earlier session memory.
- `READONLY.md` itself should also not be modified by the agent.

## Style & Conventions

- Prefer composition and clear interfaces/events over deep inheritance hierarchies.
- Prefer data-driven design and configuration where practical.
- Prefer typed code and explicit contracts where the language supports them.
- Build foundation (utils, data models, core systems, shared libraries) before high-level features.
- Follow the project’s established formatting, typing, and naming conventions. Format and lint changed files before committing.
- Add a short header comment block on key files describing purpose, important classes/functions, and critical constants when useful.

## Validation & Done Criteria

After every meaningful code or configuration change, agents must re-run the project’s existing validation steps (tests, linters, type checkers, formatters, build checks, etc.) and iterate until they succeed.

A change is complete only when:
- Project validation passes
- Style and convention rules are followed
- No known failure patterns remain unaddressed

Keep this `AGENTS.md` updated whenever project conventions, tooling, or preferred patterns change. It is the single source of truth for agents working on this repository.