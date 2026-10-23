# Git & PR Workflow

How we collaborate on Rembo like a real open-source project: short-lived branches, Conventional Commits, small pull requests and kind, thorough reviews.

## The rules in one table

| Rule | Detail |
|---|---|
| `main` is protected | No direct push, no force-push, no deletion. Every change goes through a pull request |
| One issue → one branch → one PR | The PR closes its issue with `Closes #N` |
| Branch name | `<type>/<issue-number>-<short-kebab-description>`, e.g. `feat/24-receipt-upload` |
| Commit messages | [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/): `<type>(<scope>): <imperative summary>` |
| PR title | Must be a Conventional Commit too. It becomes the commit message on `main` (checked by **Validate PR title**) |
| Review | **1 approval** from someone other than the last person who pushed. New pushes dismiss earlier approvals. Maintainers (repository admins) may merge their own PRs without one; the bypass is logged |
| Checks | **Analyze & test** and **Validate PR title** must pass. All review conversations must be resolved |
| Merge | **Squash merge only**, linear history. The branch is deleted automatically after merge |

## Types and scopes

| Type | Use for |
|---|---|
| `feat` | A new user-facing feature |
| `fix` | A bug fix |
| `docs` | Documentation and wiki only |
| `chore` | Maintenance, tooling, dependencies |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `test` | Adding or fixing tests |
| `ci` | GitHub Actions and CI configuration |
| `perf` | Performance improvement |
| `build` | Build system, platform projects, release configuration |

Scopes: `mobile`, `auth`, `expenses`, `receipts`, `approval`, `export`, `supabase`, `agents`, `ci`, `docs`.

Examples:

```text
feat(receipts): upload receipt photo to private storage
fix(approval): block managers from approving their own expenses
docs(wiki): add CSV export format
test(supabase): cover RLS on receipts bucket
```

Breaking change: add `!` after the type or scope (`feat(export)!: rename CSV columns`) and explain it in the PR. Add the `breaking change` label.

## Step by step

### 1. Pick an issue

Take an issue in **Todo** for the current sprint, **assign yourself** and move it to **In Progress** on the [board](https://github.com/orgs/exceev-technology/projects/1).

### 2. Create your branch from an up-to-date `main`

```bash
git switch main
git pull origin main
git switch -c feat/24-receipt-upload
```

### 3. Commit small, meaningful steps

```bash
dart format .
flutter analyze
flutter test

git add lib/features/receipts/
git commit -m "feat(receipts): upload receipt photo to private storage"
```

Never commit `.env`, keys, real receipts or build output.

### 4. Push and open a pull request

```bash
git push -u origin feat/24-receipt-upload
gh pr create --fill        # or use the "Compare & pull request" button on GitHub
```

In the PR:

- Title: a Conventional Commit, e.g. `feat(receipts): upload receipt photo to private storage`
- Description: fill the template, including **`Closes #24`**
- Add **screenshots or a short screen recording** for any UI change (Android and iOS)
- Move the issue to **In Review**
- Open it as a **draft** if you want early feedback

### 5. Keep your branch up to date

When `main` moves, rebase rather than merge:

```bash
git fetch origin
git rebase origin/main
# fix conflicts if any (see below), then:
git push --force-with-lease
```

`--force-with-lease` refuses to overwrite commits you have not seen. Never use plain `--force`.

### 6. Address the review

Push new commits for requested changes and reply to each comment. The **reviewer** resolves the conversation when satisfied.

### 7. Merge

Once approved and green, the author clicks **Squash and merge**. Check that the final commit message is the PR title. The branch is deleted automatically and the issue moves to **Done**.

## Resolving conflicts

```bash
git fetch origin
git rebase origin/main
# Git stops on each conflicting commit
git status                        # lists the conflicted files
# edit the files, remove the <<<<<<< ======= >>>>>>> markers, keep the right code
git add <file>
git rebase --continue
# repeat until the rebase finishes; to give up: git rebase --abort
flutter analyze && flutter test   # make sure it still works
git push --force-with-lease
```

If a conflict is unclear, ask the author of the other change. Don't guess.

## Reviewing a pull request

Everyone reviews. Reviewing is how we learn from each other's code.

**What to check**

- [ ] Does it do what the issue asks? Are the acceptance criteria met?
- [ ] Is it understandable? Names, structure, no dead code
- [ ] Are there tests, and do they test behaviour?
- [ ] Security: RLS policies for new tables, no secret, no real personal data
- [ ] UI: screenshots for Android and iOS, accessible labels, works on a small screen
- [ ] Docs: README, wiki, schema or env vars updated if needed

**How to try it locally**

```bash
gh pr checkout 31
flutter pub get
flutter run --dart-define-from-file=.env
```

**Review etiquette**

- Be kind and specific. Comment on the code, not the person.
- Explain the *why* and suggest an alternative ("What do you think about…?").
- Prefix optional remarks with **nit:** so the author knows they are not blocking.
- Use **Approve** only when you would be happy to maintain this code.
- As an author: keep PRs small (`size: XS`–`M`), answer every comment, and say thanks.
- Aim to give a first review within **one working day**.

## Contributing from a fork

Outside contributors don't have write access. They use the fork workflow:

```bash
# 1. Fork exceev-technology/rembo on GitHub, then:
git clone https://github.com/<your-username>/rembo.git
cd rembo
git remote add upstream https://github.com/exceev-technology/rembo.git

# 2. Branch from the latest upstream main
git fetch upstream
git switch -c fix/42-csv-decimal-separator upstream/main

# 3. Commit, push to your fork, and open a PR against exceev-technology/rembo:main
git push -u origin fix/42-csv-decimal-separator

# 4. Later, to update your branch
git fetch upstream
git rebase upstream/main
git push --force-with-lease
```

Read [CONTRIBUTING.md](https://github.com/exceev-technology/rembo/blob/main/CONTRIBUTING.md) and the [Code of Conduct](https://github.com/exceev-technology/rembo/blob/main/CODE_OF_CONDUCT.md) first. Look for issues labelled `good first issue` or `help wanted`.

## Useful commands

| Goal | Command |
|---|---|
| See what changed | `git status`, `git diff`, `git log --oneline --graph -15` |
| Undo local changes to a file | `git restore <file>` |
| Unstage a file | `git restore --staged <file>` |
| Amend the last commit (not pushed yet) | `git commit --amend` |
| Save work in progress | `git stash` / `git stash pop` |
| Clean up merged local branches | `git fetch --prune` then `git branch -d <branch>` |
