# Contributing to Rembo

First off, thank you for taking the time to contribute! 🎉 Rembo is an
open-source expense management app for small and medium-sized businesses in
Morocco, and every contribution counts: code, docs, design, tests, bug reports,
ideas and reviews.

This guide explains how we work. It applies to the core team (we work in Scrum
with one-week sprints) and to external contributors alike.

- [Code of Conduct](#code-of-conduct)
- [Ways to contribute](#ways-to-contribute)
- [Before you start](#before-you-start)
- [Development setup](#development-setup)
- [Our workflow, step by step](#our-workflow-step-by-step)
- [Branches, commits and pull requests](#branches-commits-and-pull-requests)
- [Code review](#code-review)
- [Coding standards](#coding-standards)
- [Definition of Done](#definition-of-done)
- [Issues, labels and the project board](#issues-labels-and-the-project-board)
- [Security and personal data](#security-and-personal-data)
- [License](#license)

## Code of Conduct

Everyone who takes part in this project agrees to our
[Code of Conduct](CODE_OF_CONDUCT.md). Please report unacceptable behavior to
[contact@exceev.com](mailto:contact@exceev.com).

## Ways to contribute

| You want to… | How |
| --- | --- |
| Report a bug | [Open a bug report](https://github.com/exceev-technology/rembo/issues/new?template=bug_report.yml) |
| Propose a feature | [Open a feature request](https://github.com/exceev-technology/rembo/issues/new?template=feature_request.yml) written as a user story |
| Ask a question or discuss an idea | [GitHub Discussions](https://github.com/exceev-technology/rembo/discussions) |
| Write code or docs | Pick an issue labeled [`good first issue`](https://github.com/exceev-technology/rembo/issues?q=is%3Aopen+label%3A%22good+first+issue%22) or [`help wanted`](https://github.com/exceev-technology/rembo/issues?q=is%3Aopen+label%3A%22help+wanted%22) |
| Review | Reviewing open pull requests is one of the most valuable contributions |
| Report a vulnerability | **Privately**, see [SECURITY.md](SECURITY.md) |

## Before you start

1. **Search first.** Check [existing issues](https://github.com/exceev-technology/rembo/issues)
   and [discussions](https://github.com/exceev-technology/rembo/discussions) to avoid duplicates.
2. **Open an issue before a large change.** For anything bigger than a small fix,
   agree on the approach in an issue (or an Ideas discussion) before writing code.
   It saves everyone time.
3. **Get assigned.** Comment on the issue to ask for it; a maintainer assigns it
   to you. One assignee owns an issue; pair programming is welcome.
4. **Check the scope.** The MVP targets the **Flutter mobile app (Android and iOS)**
   with a **Supabase** backend and a **CSV accounting export**. Web/PWA, desktop
   and direct ERP connectors (Sage, etc.) are out of scope for now; see the
   [Roadmap](https://github.com/exceev-technology/rembo/wiki/Roadmap).

## Development setup

Prerequisites:

- [Flutter](https://docs.flutter.dev/get-started/install) **3.47 (stable)**, which bundles Dart 3.13
- Android Studio (Android SDK + emulator) and/or Xcode (iOS simulator, macOS only)
- [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started) and Docker (local backend)

```bash
git clone https://github.com/exceev-technology/rembo.git
cd rembo
flutter pub get
cp .env.example .env          # fill in your local Supabase URL and anon key
flutter run --dart-define-from-file=.env
```

Before pushing, run the same checks as CI:

```bash
dart format .
flutter analyze
flutter test
```

The full guide (Supabase local stack, emulators, troubleshooting) is on the
wiki: [Development Setup](https://github.com/exceev-technology/rembo/wiki/Development-Setup).

## Our workflow, step by step

```text
Issue (Todo) ─▶ branch ─▶ commits ─▶ draft PR ─▶ ready for review ─▶ approval + green CI ─▶ squash merge ─▶ Done
```

1. Take an issue from the current sprint on the
   [project board](https://github.com/orgs/exceev-technology/projects/1) and move it to **In Progress**.
2. Create a branch from an up-to-date `main` (see naming below).
3. Commit in small, focused steps using Conventional Commits.
4. Open a **draft pull request** early and link the issue with `Closes #<issue>`.
5. Keep your branch up to date by rebasing on `main`.
6. Mark the PR **Ready for review** when the [Definition of Done](#definition-of-done)
   is met; the issue moves to **In Review**.
7. Address feedback, get an approval and a green CI, then **squash and merge**.
   The branch is deleted automatically and the issue closes as **Done**.

The detailed guide with every command is on the wiki:
[Git and PR Workflow](https://github.com/exceev-technology/rembo/wiki/Git-and-PR-Workflow).

## Branches, commits and pull requests

### `main` is protected

Nobody pushes to `main` directly, maintainers included. Every change goes
through a pull request that needs:

- at least **1 approval** from someone other than the last person who pushed
- **all required checks passing**: `Analyze & test` and `Validate PR title`
- **all review conversations resolved**
- a **linear history** (squash merge only); force-pushes and branch deletion are blocked

### Branch names

```text
<type>/<issue-number>-<short-description>
```

Examples: `feat/24-receipt-upload`, `fix/31-rls-manager-view`, `docs/12-setup-guide`.

### Commit messages and PR titles: Conventional Commits

We follow [Conventional Commits](https://www.conventionalcommits.org/). Because
we squash-merge, **the PR title becomes the commit on `main`**, so CI checks it.

```text
<type>(<optional scope>): <short summary in the imperative, lowercase>
```

| Type | Use it for |
| --- | --- |
| `feat` | A new feature for the user |
| `fix` | A bug fix |
| `docs` | Documentation only |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `test` | Adding or fixing tests |
| `perf` | Performance improvement |
| `build` | Dependencies, build system |
| `ci` | GitHub Actions and automation |
| `chore` | Other maintenance |
| `style` / `revert` | Formatting only / reverting a commit |

Scopes: `mobile`, `auth`, `expenses`, `receipts`, `approval`, `export`,
`supabase`, `agents`, `ci`, `docs`, `deps`, `release`.

Examples: `feat(receipts): extract amount and date with OCR`,
`fix(approval): block self-approval in RLS policy`. Add `!` for a breaking
change: `feat(export)!: rename CSV columns`.

### Pull requests

- Keep PRs **small and focused**: one issue, one PR. Under ~400 changed lines is
  easier to review (a `size:` label is added automatically).
- Fill in the PR template: what and why, how to test, and screenshots on
  **Android and iOS** for UI changes.
- Link the issue (`Closes #123`) so the board stays in sync.
- Rebase rather than merge `main` into your branch:
  `git fetch origin && git rebase origin/main && git push --force-with-lease`.

## Code review

Reviews are how we learn from each other. Every team member reviews.

**As an author:** review your own diff first, answer every comment, and push
fixes as new commits during review (they are squashed at merge). Re-request
review when ready.

**As a reviewer:** aim to respond within one working day. Be kind and specific,
and explain the *why*. Prefix optional remarks with `nit:`. Use GitHub
*suggestions* for small changes. Approve when it is good enough, not perfect.
Check correctness, tests, RLS and security, readability, and the Definition of
Done.

`CODEOWNERS` requests reviews automatically. Changes to `.github/` (CI,
templates, security config) also need a maintainer's review.

## Coding standards

- **Dart/Flutter:** follow [Effective Dart](https://dart.dev/effective-dart).
  Code must pass `dart format` and `flutter analyze` with no issues (rules in
  `analysis_options.yaml`).
- **Structure:** organize code by feature (`lib/features/<feature>/…`), keeping
  UI, state and data access separate.
- **Tests:** add unit or widget tests for new logic. Bug fixes come with a test
  that reproduces the bug.
- **Supabase:** every schema change is a migration in `supabase/migrations/`.
  **RLS is enabled on every table** with tested policies. Privileged logic lives
  in Edge Functions.
- **Accessibility and i18n:** use semantic widgets and sufficient contrast, and
  keep user-facing strings ready for French and Arabic.
- **No secrets in code:** configuration comes from `--dart-define-from-file`
  (see `.env.example`). Only the public `anon` key can reach the app.

## Definition of Done

An issue is done when:

- [ ] the PR is reviewed, approved by another member and squash-merged to `main`
- [ ] CI is green (format, analyze, tests)
- [ ] new logic has tests
- [ ] Supabase RLS policies are written and tested for the feature
- [ ] it is demonstrable on **Android and iOS** (emulator or simulator is fine) with **fictional receipts**
- [ ] docs are up to date (README, wiki, database schema, `.env.example`)
- [ ] no secret is in the repository or the client (only the public `anon` key)

## Issues, labels and the project board

We use the organization's **Issue Types** with one template each:

| Type | Template | Use it for |
| --- | --- | --- |
| **Feature** | ✨ Feature / user story | A user-facing capability: *As a… I want… so that…* plus acceptance criteria |
| **Bug** | 🐛 Bug report | Something that does not work as expected |
| **Task** | 🛠️ Task | Technical, documentation, DevOps or learning work |

Labels are grouped by prefix: `type:`, `priority:`, `area:`, `status:` and
`size:`. The full list lives in [`.github/labels.yml`](.github/labels.yml) and is
synced automatically.

Sprints are planned on the
[Rembo project](https://github.com/orgs/exceev-technology/projects/1) (Status:
Backlog → Todo → In Progress → In Review → Done), with one milestone per sprint.
See [Scrum on GitHub](https://github.com/exceev-technology/rembo/wiki/Scrum-on-GitHub).

## Security and personal data

- Use **fictional receipts and data only**: no real employee, client or supplier data.
- Never commit secrets. The Supabase `service_role` key and OCR/AI keys belong in
  server-side secrets only, never in the repo, the app or chat.
- Report vulnerabilities privately as described in [SECURITY.md](SECURITY.md).

## License

By contributing, you agree that your contributions are licensed under the
[MIT License](LICENSE) that covers this project.

Thank you for helping build Rembo! 💜
