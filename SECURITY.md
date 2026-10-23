# Security Policy

Rembo handles expense reports, receipts and approval decisions: data that is
financial and personal. We take its security seriously and we are grateful to
anyone who helps us keep it safe.

## Supported versions

Rembo is in active pre-1.0 development. Security fixes land on `main` and ship
in the next release; older pre-releases are not patched.

| Version | Supported |
| --- | --- |
| `main` (latest) | ✅ |
| Latest tagged release | ✅ |
| Older releases | ❌ |

## Reporting a vulnerability

**Please do not report security vulnerabilities through public GitHub issues,
discussions, pull requests or Slack.**

Report it privately through GitHub instead:

👉 **[Report a vulnerability](https://github.com/exceev-technology/rembo/security/advisories/new)**
(repository **Security** tab → **Report a vulnerability**)

If you cannot use GitHub, email **[contact@exceev.com](mailto:contact@exceev.com)**
with the subject `[SECURITY] rembo`.

To help us triage quickly, please include:

- the type of issue (for example: RLS bypass, broken access control, secret
  exposure, injection, insecure storage of receipts)
- the affected files, tables, policies, Edge Functions or screens
- step-by-step instructions to reproduce, with a proof of concept if possible
- the impact: what an attacker could read, change or approve
- your suggested fix, if you have one

Use **fictional data only** in your report. Never include real receipts or
personal data.

## What to expect

| Step | Target |
| --- | --- |
| Acknowledgement of your report | within 3 business days |
| Initial assessment and severity | within 7 days |
| Fix for critical / high severity | as fast as possible, within 30 days |
| Fix for medium / low severity | in a following release |
| Public disclosure | coordinated with you, through a GitHub Security Advisory, after the fix |

We will keep you informed of progress and credit you in the advisory unless you
prefer to stay anonymous.

## Scope

**In scope**

- The Flutter mobile app in this repository (Android and iOS)
- Supabase migrations, Row Level Security (RLS) policies, Storage policies and
  Edge Functions in this repository
- AI agent and MCP integrations in this repository
- GitHub Actions workflows and repository configuration

**Out of scope**

- Vulnerabilities in third-party platforms (report them to Supabase, Google,
  Apple, etc. directly)
- Denial of service, spam or social engineering of maintainers or contributors
- Findings that need a rooted/jailbroken device or physical access to an
  unlocked device
- Missing best-practice headers or findings without a demonstrable impact

## Safe harbor

We will not pursue legal action against researchers who act in good faith:
who avoid privacy violations and data destruction, only test against their own
accounts and local or test environments, never access other users' data, and
give us reasonable time to fix the issue before any disclosure.

## How we keep Rembo secure

- **Least privilege by default:** every table has RLS enabled; an employee only
  sees their own expenses, a manager their team, and nobody approves their own
  expense.
- **Private receipts:** receipts live in a private Storage bucket and are served
  through short-lived signed URLs.
- **Secrets stay on the server:** the Supabase `service_role` key and OCR / AI
  provider keys are only used in Edge Functions. The mobile app only ships the
  public `anon` key.
- **Protected `main` branch:** changes land through reviewed pull requests with
  passing checks; force-pushes and deletions are blocked.
- **Automated checks:** GitHub secret scanning with push protection, TruffleHog,
  Dependabot alerts and security updates, dependency review on pull requests,
  CodeQL for workflows and OpenSSF Scorecard.
- **Pinned CI:** third-party GitHub Actions are pinned to full commit SHAs and
  updated by Dependabot.
- **Personal data:** fictional data only during development; any real use must
  first be framed under Moroccan Law 09-08 and the CNDP.

## If you accidentally commit a secret

1. **Revoke and rotate it immediately** (Supabase dashboard, provider console).
   Deleting the commit is not enough: it is already in the history and forks.
2. Tell a maintainer privately at [contact@exceev.com](mailto:contact@exceev.com).
3. Open a pull request that removes it and moves it to an environment variable
   or a server-side secret.
