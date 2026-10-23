# Scrum on GitHub

How the Rembo team runs Scrum with GitHub Issues, Projects and Milestones. New to Scrum? Start with the [Learning Path](Learning-Path).

## Roles

| Role | Who | Responsibility |
|---|---|---|
| **Product Owner** | Marius ([@Mavens06](https://github.com/Mavens06)) | Owns the vision, orders the backlog, accepts or rejects increments |
| **Scrum Master** | A developer, **rotating every week** ([rotation](Team#scrum-master-rotation)) | Runs the ceremonies, removes blockers, keeps the board up to date |
| **Developers** | Hafssa, Mohamed, Mohamoudou, Daouda | Commit to the sprint goal; design, build, test and review |
| **Mentors** | Hamza Lemrani (Exceev, maintainer), Hajar (Exceev), Nouhan Kourouma (ECC) | Support, technical and pedagogical follow-up |

## Ceremonies

Sprints last **one week, Monday to Friday**.

| Ceremony | When | Format | Output |
|---|---|---|---|
| **Sprint Planning** | Monday | PO presents priorities; team picks and estimates stories | Sprint goal on the milestone; issues set to **Todo** with the current **Sprint** |
| **Daily** | Every working day | **Async** in the team Slack channel, in a thread: *Yesterday / Today / Blockers* | Blockers labelled `status: blocked` |
| **Sprint Review** | Friday | Demo of the increment to the PO on Android/iOS | Accepted stories → **Done**; feedback → new backlog items |
| **Retrospective** | Friday, after the review | What went well / what to improve / one action | One improvement action as a `type: task` issue in the next sprint |

## The board

Everything lives in the [Rembo project](https://github.com/orgs/exceev-technology/projects/1).

| Status | Meaning | Who moves it |
|---|---|---|
| **Backlog** | Captured, not ready or not planned | Anyone creates; PO orders |
| **Todo** | Ready and planned in the current sprint | Team at Sprint Planning |
| **In Progress** | Someone is working on it (assigned, branch created) | Assignee |
| **In Review** | Pull request open and waiting for review | Assignee when opening the PR |
| **Done** | PR merged and meets the Definition of Done | Automatic when the PR closes the issue |

Project fields:

| Field | Use |
|---|---|
| **Sprint** | Iteration (Sprint 0 → Sprint 6) |
| **Estimate** | Story points |
| **Milestone** | Sprint goal (one milestone per sprint) |
| **Assignees** | Who does it. One owner per issue; pair-programming partners are mentioned in the description |
| **Parent issue / Sub-issues progress** | Break an epic into stories and track progress |

Milestones: `Sprint 1 · Foundations`, `Sprint 2 · First expense flow`, `Sprint 3 · Capture & OCR`, `Sprint 4 · Approval workflow`, `Sprint 5 · Mobile MVP complete`, `Sprint 6 · CSV export & user tests`, `MVP · Handover & demo day`. Dates are in the [Roadmap](Roadmap).

## Issue types

Pick the template when you [open an issue](https://github.com/exceev-technology/rembo/issues/new/choose). Each one sets the organisation's **issue type**.

| Type | Template | Use it for |
|---|---|---|
| **Feature** | `feature_request.yml` | A user story: something a user can do |
| **Bug** | `bug_report.yml` | Something that does not work as expected |
| **Task** | `task.yml` | Technical work, chores, documentation, learning |

Large pieces of work get the `epic` label and are split into sub-issues.

## Labels

| Group | Labels | Notes |
|---|---|---|
| Type | `type: bug`, `type: feature`, `type: task`, `type: docs`, `type: chore`, `type: security`, `type: learning` | Also used on PRs (PRs have no issue type) |
| Priority | `priority: critical`, `priority: high`, `priority: medium`, `priority: low` | Set by the PO |
| Area | `area: mobile-ui`, `area: auth`, `area: expenses`, `area: receipts-ocr`, `area: approval`, `area: export-csv`, `area: supabase`, `area: ai-agents`, `area: ci`, `area: accessibility`, `area: i18n` | Added automatically on PRs from the changed paths when possible |
| Status | `status: needs triage`, `status: needs info`, `status: blocked`, `status: stale` | New issues start in `needs triage` |
| Size | `size: XS`, `size: S`, `size: M`, `size: L`, `size: XL` | **Added automatically on PRs** from the diff size. Prefer small PRs |
| Community | `good first issue`, `help wanted`, `question` | For newcomers and outside contributors |
| Resolution | `duplicate`, `invalid`, `wontfix` | When closing without a fix |
| Other | `epic`, `dependencies`, `breaking change`, `skip changelog` | `dependencies` is used by Dependabot |

## Estimation

- Story points on the **Fibonacci scale: 1, 2, 3, 5, 8, 13**. Points measure effort, complexity and uncertainty, not hours.
- Estimate together at Sprint Planning (planning poker works well).
- **13 means too big:** split the story before planning it.
- After two or three sprints, use the team's average velocity to size the next sprint. Remember the holidays (6 and 18 November).

## Definition of Ready

A story can enter a sprint when:

- [ ] It follows the format **"As a \<employee / manager / accountant\>, I want \<action\> so that \<benefit\>"**
- [ ] It has clear, testable **acceptance criteria**
- [ ] It is **estimated**
- [ ] It has **no blocking dependency**
- [ ] It links a **mockup** when it changes the UI

## Definition of Done

A story is done when:

- [ ] The PR is reviewed and approved by **another team member** and **squash-merged** into `main`
- [ ] **CI is green**: format, analyze, tests
- [ ] New logic is covered by **tests**
- [ ] **Supabase RLS policies** for the feature are written **and tested**
- [ ] It is **demonstrable on Android and iOS** (emulator/simulator is fine) with **fictional receipts**
- [ ] Docs are up to date: README or wiki, database schema, environment variables
- [ ] **No secret** in the repository or in the app (only the public `anon` key)

## Writing a good user story

```markdown
**As an** employee,
**I want** to take a photo of my receipt and see the amount, date and supplier filled in for me,
**so that** I don't have to type them.

### Acceptance criteria
- [ ] Given I am signed in, when I take a photo of a receipt, then the date, supplier, amount and currency are pre-filled
- [ ] Each pre-filled field shows that it comes from the OCR, and I can edit it
- [ ] When a required field is missing, the app tells me which one
- [ ] The receipt is stored in the private bucket; only I, my manager and my company's accountant can open it

### Notes
Mockup: <link> · Depends on: #12 · Estimate: 5
```

Tips:

- One user, one action, one benefit. If you write "and", consider splitting.
- Acceptance criteria describe **behaviour**, not implementation.
- Use **fictional** examples only: Youssef, Café Atlas, 380 MAD.
