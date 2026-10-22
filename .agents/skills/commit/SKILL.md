---
name: commit
description: Commit all pending Koda app repository changes in logical groups using Koda's fixed Conventional Commits policy. Use when the user asks to commit, create commits, group changes into commits, or finish local work without pushing. Not for pushing, branch management, or rewriting history unless explicitly requested.
---

# Commit Pending Changes

Commit staged, unstaged, and untracked work in coherent groups without changing the implementation.

## Project convention

Koda uses Gitflow for branch lifecycle and Conventional Commits for commit subjects. Gitflow branch names do not change the commit message format.

Use exactly:

```text
<type>(<scope>): <description>
```

### Type

Choose the type from the change's intent:

| Type | Use for |
| --- | --- |
| `feat` | New user-visible behavior or capability |
| `fix` | Correcting faulty behavior |
| `refactor` | Restructuring without changing behavior |
| `chore` | Repository maintenance, agent configuration, or non-product work |
| `docs` | Documentation-only changes |
| `test` | Test-only additions or corrections |
| `build` | Build system or dependency configuration |
| `ci` | Continuous-integration configuration |
| `style` | Formatting-only changes |
| `perf` | Performance improvements |
| `revert` | Reverting an earlier commit |

Do not use `create`, `update`, or `delete` as types. Express those actions in the description with verbs such as `add`, `update`, or `remove`.

### Scope

- Use exactly one lowercase noun naming the dominant area. Prefer a feature (`auth`, `today`, `planning`, `recipes`, `products`, `shopping`, `profile`, `intents`, `widgets`) or a repository area (`app`, `core`, `api`, `database`, `sync`, `notifications`, `navigation`, `theme`, `ui`, `macos`, `localization`, `icons`, `build`, `fastlane`, `ci`, `deployment`, `testing`, `skills`, `agents`, `rules`).
- Never concatenate scopes with `/`, `,`, `+`, or another hierarchy separator.
- Prefer a stable product or repository area over a filename.
- If no meaningful scope exists, omit the parentheses and use `<type>: <description>`.

### Description

- Write it in English.
- Start with a lowercase imperative verb.
- Describe the outcome, not the editing process.
- Keep it concise, on one line, with no trailing period.
- Do not add generated-by trailers. Add a `Co-Authored-By` trailer only when the user or the session instructions explicitly require it.

Valid examples:

```text
refactor(app): extract macOS application delegate
chore(skills): add local-first sync guidance
chore(agents): share skills with Claude and Cursor
fix(localization): load strings from the module bundle
```

Invalid examples:

```text
create(chore/agents/skills): Added new stuff
update(app/ios): Update AppDelegate.
feat(build,ios): xcode changes
```

## Gitflow boundary

Do not create, switch, merge, finish, or delete branches unless the user explicitly asks. When branch management is requested, keep Gitflow branch roles separate from commit types: `feature/*`, `release/*`, and `hotfix/*` describe branches; `feat`, `fix`, and the other types above describe commits.

## Workflow

### 1. Inspect the complete state

Read:

```bash
git branch --show-current
git status --short
git diff --cached --stat
git diff --stat
git diff --cached
git diff
git ls-files --others --exclude-standard
git log --oneline --no-merges -10
```

Read every untracked file that may belong in a commit. If there are no pending changes, report that and stop.

Never include secrets or signing material (`*.private.xcconfig`, `fastlane/.env`, `fastlane/apikey.json`, `*.p8`, certificates, provisioning profiles, `.ipa`, `.pkg`), `.DS_Store`, `xcuserdata/`, `.build/`, DerivedData, or `fastlane/report.xml`. Flag suspicious files instead of committing them.

`Configuration/version.xcconfig` changes made by the release lanes (or the monthly TestFlight workflow, which commits `chore: bump build to N [skip ci]`) and the shared `Package.resolved` belong in commits together with the change that produced them.

### 2. Form logical groups

Use one commit per coherent outcome:

1. Keep a feature together across UI, domain code, resources, and its tests.
2. Keep a fix together with the regression test that proves it.
3. Separate unrelated app behavior, build configuration, documentation, and agent configuration.
4. Keep dependency manifests and lockfiles together when they represent the same dependency change.
5. Keep generated files with the source change that intentionally regenerated them; otherwise flag them.
6. Do not split files merely because they live in different folders, and do not combine unrelated work merely because it shares a folder.

If two interpretations would produce materially different history, show the proposed groups and ask before committing. Otherwise proceed.

### 3. Validate before committing

- Run `git diff --check` over the pending work.
- Run proportionate checks when the changes have not already been verified in this session: `scripts/swiftlint.sh` for Swift changes, and the `development` validation for product changes. The `.githooks/pre-commit` hook also checks staged Swift files with `swift format lint --strict`; never bypass it with `--no-verify`.
- Do not alter product code merely to make a commit look cleaner unless the user also asked for that change.
- Preserve all user changes. Index operations may reorganize staging but must never discard worktree content.

### 4. Stage and commit each group

For every group:

1. Stage only its explicit paths with `git add <paths>`; never use `git add .` or `git add -A`.
2. If pre-staged files span several groups, reorganize only the index with targeted `git restore --staged -- <paths>` and confirm the worktree remains unchanged.
3. Review `git diff --cached --stat` and `git diff --cached`.
4. Commit with one approved-format subject.
5. Confirm success with `git status --short` and the new `git log -1 --oneline` entry.

Do not push. Do not rewrite existing commits unless the user explicitly asks to amend or correct history.

### 5. Report

Return each new hash, subject, and file count, followed by the current branch and whether the working tree is clean. Mention skipped or suspicious files explicitly.
