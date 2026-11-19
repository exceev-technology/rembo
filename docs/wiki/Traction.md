# Traction

The jury of 8 December looks at the product **and** at its traction: interviews held, needs found, early-access sign-ups, demos, outside contributions, and the plan to continue. This page is where the team keeps the numbers, every week.

## Early access

The public site ([exceev-technology.github.io/rembo](https://exceev-technology.github.io/rembo/)) has an early-access form. It calls `join_early_access()` on the Supabase project set in `site/config.js` (public anon key only): visitors can sign up but never read the list.

| Step | How |
|---|---|
| Turn the form on | Fill `supabaseUrl` and `anonKey` in `site/config.js` (project → Settings → API). Empty, the form sends visitors to the Discussions |
| Read the sign-ups | Supabase dashboard → Table editor → `early_access` (service role); count: `select count(*), role, team_size from early_access group by 2, 3` |
| Delete on request | `delete from early_access where email = '…'` (law 09-08: within a reasonable time, and say it is done) |

Only what is needed to call back is kept: e-mail, company, role, team size, city, date of consent.

## Weekly numbers

Update every Friday with the sprint recap (Discussions › Sprint updates).

| Week | Interviews | Early-access sign-ups | Demos held | External contributors | Merged outside PRs |
|---|---|---|---|---|---|
| 23 → 27 Nov | | | | | |
| 30 Nov → 4 Dec | | | | | |

## Interviews

One line per interview; notes in Discussions › User research (no names of people without their consent).

| Date | Kind of company | Role met | Current method | Main pain | What they would pay for |
|---|---|---|---|---|---|

## Contributors

- Label beginner-friendly issues `good first issue` and keep `CONTRIBUTING.md` up to date.
- Thank every outside contribution in the sprint recap.
