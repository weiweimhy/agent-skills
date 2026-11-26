# Agent Instructions

## Repository Role

- This repository is the only editable source for the shared personal skill
  library. It contains the version that is reviewed, committed, and pushed.
- A user's personal skills directory is a deployment clone. It is not a second
  worktree and must never receive direct patches, generated edits, or commits.
- Deployment paths vary by user and machine. Resolve the target from the
  environment or the repository README; do not record personal paths here.

## Finding and Introducing Skills

When asked whether a skill exists or before authoring a new skill, always search
in this order:

1. **Project directory first**: check project-local skills in the target
   workspace (`.agents/skills/`, `.codex/skills/`, `.claude/skills/`, or
   `skills list`) and project-level `AGENTS.md` conventions.
2. **Global directory second**: check this source repository (`SKILLS.md` and
   `<skill>/SKILL.md`), the global deployment clone (`~/.agents/skills`),
   `skills list -g`, and host built-in/plugin/marketplace skills.
3. **`find-skills` third**: search the open agent skills ecosystem via the
   `find-skills` skill (`skills find <query> [--owner <owner>]` /
   `npx skills find <query>` and `https://skills.sh/`). Verify install count,
   source reputation, and repository quality before recommending or adopting.
4. **GitHub fourth**: search GitHub repositories directly for mature existing
   `SKILL.md` implementations or reference wrappers not surfaced by
   `find-skills`. Prefer the authenticated `gh` CLI (`gh search repos`,
   `gh search code`, `gh api`) for exact repository and `SKILL.md` inspection
   when available, and fall back to web search if `gh` is unavailable or
   network-restricted. Evaluate coverage, maintenance, cross-host/OS
   compatibility (including Windows PowerShell), and security boundaries before
   deciding whether to adopt, adapt, or build from scratch.
5. **Author or adapt locally only when needed**: if none of the above fits
   cleanly (or requires multi-host/Windows adaptation), create or adapt the
   skill in this source repository (or the target project's `.agents/skills/`
   if project-only), cite any inspected upstream/GitHub references, and avoid
   duplicating official/plugin skills. Never run `skills add ... -g` directly
   against a Git-managed deployment clone.

## Changing and Deploying Skills

1. Make every skill, script, or documentation change in this source repository.
2. Run the relevant validation, including `pwsh ./scripts/validate-skills.ps1`
   for skill metadata. Run any focused Markdown or script checks affected by
   the change.
3. Review the diff, commit the focused change, and push it to the configured
   remote branch.
4. Only after a successful push, inspect the deployment clone. If it is clean,
   update it with `git -C <deployment-clone> pull --ff-only`.
5. If the deployment clone is dirty, do not edit it in place. Compare each
   changed path with the pushed source version:
   - If it is identical, restore only those verified paths to the clone's HEAD,
     then fast-forward the clone.
   - If it differs, stop and report the paths and differences. Preserve the
     user's changes and ask for a resolution instead of overwriting, stashing,
     or committing them.
6. After synchronization, verify the deployment clone is clean and at the
   expected revision. Tell the user to start a new Codex task or reopen one so
   skill discovery refreshes.

## Safety Boundaries

- A suggestion to update a deployed skill is not permission to modify it
  directly; the source-to-push-to-fast-forward sequence is required.
- Do not add personal paths, credentials, tokens, or user data to tracked
  documentation.
- Do not use a broad reset or destructive cleanup for a deployment clone.
  Target only verified, source-identical paths when reconciling an accidental
  local edit.

## Validation and Handoff

- Report the source commit, push result, deployment revision, validation run,
  and any unresolved deployment differences.
- Do not claim deployment succeeded if the fast-forward command was not run or
  the clone is still dirty.
