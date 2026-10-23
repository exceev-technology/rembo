# Testing Protocol

How we check that Rembo actually reduces re-entry and errors, and that its security rules hold. The protocol runs mainly in **Sprint 6** ([Roadmap](Roadmap)). Results go into the handover package on 7 December.

## Hypothesis under test

> An expense flow adapted to Moroccan business rules reduces re-entry and errors.

We measure the gain with real users. We make **no promise about OCR accuracy**: we measure how many fields the user has to correct.

## Test material

- A set of **30 fictional receipts** of varying quality: clean, crumpled, faded, handwritten, with and without VAT and ICE, different categories
- **Fictional data only**: no real employee, client or supplier data (see [Data Protection & Security](Data-Protection-and-Security))
- The Rembo app on **Android and iOS**, connected to a test Supabase project with seed data (companies, users per role, categories, policies)

## User tests

- Up to **5 target users** (employees, managers, accountants of Moroccan SMBs), depending on availability
- Each user processes receipts **with Rembo** and **with their current method** (paper, spreadsheet, email…)

| Measure | How |
|---|---|
| **OCR fields corrected** | For each receipt, number of fields the user had to fix (date, supplier, amount, currency, VAT, ICE) |
| **Time to declare** | From opening the app (or starting the current method) to submitted expense |
| **Comparison** | Same measures with the current method |
| **Feedback** | Short interview after the session: what was easy, what was confusing, would they use it |

## Control checks

These must pass before demo day. Each one is a test case with a fictional scenario.

| # | Control | Expected result |
|---|---|---|
| C1 | **No self-approval**: an employee who is also a manager tries to approve their own expense | Refused by the app **and** by the database (RLS / constraint) |
| C2 | **Receipt isolation**: user B tries to open user A's receipt (direct query and Storage URL) | Access denied by RLS and Storage policies |
| C3 | **Export consistency**: total of approved expenses vs total in the exported CSV | Totals are **identical**; every approved expense appears exactly once |
| C4 | **Escalation**: an expense above the alert limit, and an ambiguous receipt | Both are routed to a manager with the reason shown |
| C5 | **No secret on the client**: inspect the app build and the repository | Only the public `anon` key is present |

## Reporting

Record the results in a test report (in the repository, under `docs/`):

- Receipts processed, fields corrected per receipt, time per declaration
- Comparison with the current method
- Results of controls C1–C5, with screenshots
- Known limits and bugs found (each bug becomes a `type: bug` issue)
