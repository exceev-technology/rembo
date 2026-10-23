# Learning Path

This page goes with the five **onboarding learning tasks** of Sprint 1 (`type: learning`). There is one task per subject, and each one is assigned to every team member:

| Learning task | Sections of this page |
|---|---|
| 🔄 Agile Scrum on GitHub | [1. Scrum](#1-scrum) |
| 🤝 Open-source collaboration: Git, branches, pull requests and reviews | [2. Git & GitHub](#2-git--github) and [3. Open-source collaboration](#3-open-source-collaboration) |
| 📱 Discover Flutter | [4. Dart & Flutter](#4-dart--flutter) |
| 🗄️ Discover Supabase | [5. Supabase](#5-supabase) |
| 🔌 Discover MCP | [6. MCP](#6-mcp-model-context-protocol) |

Follow the suggested order, do the hands-on exercise of each topic, and tick your name in the matching task when you are done. Share what you learn in the team channel or in [Discussions → Show and tell](https://github.com/exceev-technology/rembo/discussions/categories/show-and-tell).

## Suggested order

| # | Topic | Why first |
|---|---|---|
| 1 | Scrum basics | We plan, build and demo in one-week sprints from Sprint 1 |
| 2 | Git & GitHub flow | Every line of code goes through a branch and a pull request |
| 3 | Open-source collaboration | How to write issues, review PRs and work in public |
| 4 | Dart & Flutter | The mobile app |
| 5 | Supabase | Database, Auth, RLS, Storage and Edge Functions |
| 6 | MCP | How our AI agents reach tools |

---

## 1. Scrum

**Read**

- [The Scrum Guide](https://scrumguides.org/scrum-guide.html): the official, short definition of Scrum
- Our own rules: [Scrum on GitHub](Scrum-on-GitHub)

**Understand:** the 3 accountabilities (Product Owner, Scrum Master, Developers), the 5 events, the 3 artifacts, Definition of Done, sprint goal.

**Exercise:** write one user story for Rembo with three acceptance criteria, following [the template](Scrum-on-GitHub#writing-a-good-user-story). Post it as a comment on your learning task for the PO to review.

## 2. Git & GitHub

**Read**

- [Pro Git, chapters 1–3](https://git-scm.com/book/en/v2): basics and branching
- [GitHub flow](https://docs.github.com/en/get-started/using-github/github-flow)
- [About pull requests](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/about-pull-requests)
- [GitHub Issues](https://docs.github.com/en/issues) and [GitHub Projects](https://docs.github.com/en/issues/planning-and-tracking-with-projects/learning-about-projects/about-projects)
- [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)
- Our own rules: [Git & PR Workflow](Git-and-PR-Workflow)

**Exercise: your first PR.** Add your GitHub handle to the [Team](Team) page:

1. Create a branch `docs/<issue-number>-add-<your-name>-to-team`
2. Edit `docs/wiki/Team.md`
3. Commit with `docs(wiki): add <your name> to team page`
4. Open a PR, get one review from a teammate, address the comments, squash-merge
5. Review **another teammate's** PR the same way

## 3. Open-source collaboration

**Read**

- [How to Contribute to Open Source](https://opensource.guide/how-to-contribute/)
- [Building Welcoming Communities](https://opensource.guide/building-community/)
- Our [CONTRIBUTING.md](https://github.com/exceev-technology/rembo/blob/main/CONTRIBUTING.md) and [Code of Conduct](https://github.com/exceev-technology/rembo/blob/main/CODE_OF_CONDUCT.md)

**Exercise:** find a bug or a missing piece in this wiki or the README. Open an issue with the right template, then fix it in a PR that closes the issue.

---

## 4. Dart & Flutter

**Read and code along**

- [Dart language tour](https://dart.dev/language): variables, null safety, classes, async/await
- [Install Flutter](https://docs.flutter.dev/get-started/install), then run `flutter doctor`
- [Your first Flutter app (codelab)](https://docs.flutter.dev/get-started/codelab)
- [Building user interfaces](https://docs.flutter.dev/ui): widgets, layout, navigation
- [State management introduction](https://docs.flutter.dev/data-and-backend/state-mgmt/intro)
- [Testing Flutter apps](https://docs.flutter.dev/testing/overview)

**Exercise:** on a personal branch (no PR needed), build a screen that lists three fictional expenses (supplier, date, amount in MAD) with a widget test that checks the total. Run it on **both** an Android emulator and an iOS simulator (or pair with someone who has a Mac).

## 5. Supabase

**Read**

- [Supabase docs](https://supabase.com/docs), especially:
  - [Flutter quickstart](https://supabase.com/docs/guides/getting-started/quickstarts/flutter)
  - [Local development with the CLI](https://supabase.com/docs/guides/local-development)
  - [Auth](https://supabase.com/docs/guides/auth)
  - [Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security)
  - [Storage](https://supabase.com/docs/guides/storage)
  - [Edge Functions](https://supabase.com/docs/guides/functions)
- [Flutter client reference (`supabase_flutter`)](https://supabase.com/docs/reference/dart/introduction)
- Our [Architecture](Architecture) page

**Exercise:** run `supabase start` locally. Create an `expenses` table with RLS so that a user only sees their own rows. Prove it: sign in as two test users and show that user B cannot read user A's expense. Write down what you did and post it on your learning task.

## 6. MCP (Model Context Protocol)

**Read**

- [modelcontextprotocol.io](https://modelcontextprotocol.io): what MCP is, the client/server model, tools, resources and prompts
- [Supabase MCP server](https://supabase.com/docs/guides/getting-started/mcp): connect an AI assistant to a Supabase project
- Our [AI agents, MCP and human-in-the-loop](Architecture#ai-agents-mcp-and-human-in-the-loop) section

**Safety rules for MCP**

- Connect MCP servers **only to a local or dev Supabase project**, never to a project with real data
- Use **read-only mode** and scope the server to that single project
- Never paste keys into prompts, chats or Slack

**Exercise:** connect an MCP-capable AI assistant to your **local** Supabase in read-only mode. Ask it to describe your `expenses` table and its RLS policies. Note one thing it did well and one risk you noticed. We use this when designing the agents.

---

## Done with the path?

- [ ] Every exercise is done and linked in your learning task
- [ ] Your first PR (Team page) is merged
- [ ] You reviewed at least one teammate's PR
- [ ] You can run the app on Android and iOS and the local Supabase stack ([Development Setup](Development-Setup))

You are ready for Sprint 1 stories. 🚀
