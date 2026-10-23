# Data Protection & Security

Expense data is sensitive: names, amounts, places, habits. These ground rules apply to **everyone** working on Rembo, in code, tests, demos and chats.

## Ground rules

| ✅ Do | ❌ Never |
|---|---|
| Use **fictional receipts** and fictional people (Youssef, Café Atlas…) | Use real employee, client or supplier data, even "just for a test" |
| Keep the `service_role` key, OCR keys and AI keys **server side** (Edge Functions secrets) | Put any of these keys in the repository, in the app, in `.env` committed files, in Slack or in an issue |
| Put only `SUPABASE_URL` and the public `anon` key in the app | Disable RLS "temporarily" on a table that holds expense data |
| Write **and test** RLS policies for every new table | Expose receipts through public buckets or permanent links |
| Use **signed URLs** with a short lifetime for receipts | Share screenshots that show real personal data |
| Ask in a thread or in [Discussions](https://github.com/exceev-technology/rembo/discussions) when unsure | Connect AI tools or MCP servers to a project with real data |

## Law 09-08 and the CNDP

Rembo targets Moroccan companies. Personal data processing in Morocco falls under **Law 09-08** and the supervision of the **CNDP** (*Commission Nationale de contrôle de la protection des Données à caractère Personnel*).

- During the program we process **fictional data only**, so no declaration is needed.
- **Before any real use** (pilot with a real company), the processing must be framed under Law 09-08: purpose, data minimisation, retention period, access rights, hosting location and, where required, the CNDP formalities.
- Product design follows privacy by default: collect only what an expense report needs, role-based access, encryption in transit and at rest (provided by Supabase), and an audit log of every human and agent action.

## Secrets

- Local secrets live in `.env` (git-ignored). The repository only contains `.env.example` with placeholder values.
- Server secrets are set with `supabase secrets set` and read inside Edge Functions.
- GitHub **secret scanning with push protection** blocks most known key formats at push time. If a push is blocked, remove the secret and don't bypass the block.
- **A secret was committed or shared by mistake?** Rotate it immediately in the Supabase dashboard (or the provider's console), then tell a maintainer. Deleting the commit is not enough: the key is already exposed.

## Security in the development workflow

| Safeguard | What it does |
|---|---|
| Protected `main` | Every change is reviewed in a PR. No force-push, no deletion |
| CI checks | Format, static analysis and tests on every PR |
| Dependabot | Alerts and update PRs for vulnerable Flutter packages and GitHub Actions |
| Dependency review | Flags vulnerable dependencies introduced by a PR |
| Secret scanning | GitHub secret scanning with push protection, plus a secret scan in CI |
| CodeQL & OpenSSF Scorecard | Analyse the workflows and the repository's security practices |

## Reporting a vulnerability

**Do not open a public issue.** Use [private vulnerability reporting](https://github.com/exceev-technology/rembo/security/advisories/new) as described in the [security policy](https://github.com/exceev-technology/rembo/security/policy).
