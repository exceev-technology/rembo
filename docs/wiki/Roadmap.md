# Roadmap

Scrum with **one-week sprints, Monday to Friday**. Each sprint maps to:

- an iteration of the **Sprint** field in the [Rembo project](https://github.com/orgs/exceev-technology/projects/1), and
- a [milestone](https://github.com/exceev-technology/rembo/milestones) carrying the sprint goal, due on the Friday.

## Sprints

| Sprint | Dates (2026) | Milestone | Sprint goal |
|---|---|---|---|
| Sprint 0 · Bootcamp | 19 → 23 Oct | — | Interviews, user journeys and mockups, initial backlog, Supabase project created |
| Sprint 1 | 26 → 30 Oct | **Sprint 1 · Foundations** | Database schema, Auth, roles (employee, manager, accountant), base RLS + team onboarding (learning tasks) |
| Sprint 2 | 2 → 6 Nov | **Sprint 2 · First expense flow** | First runnable flow: create an expense and upload its receipt (Storage) |
| Sprint 3 | 9 → 13 Nov | **Sprint 3 · Capture & OCR** | Field extraction, review and correction screen |
| Sprint 4 | 16 → 20 Nov | **Sprint 4 · Approval workflow** | Submit, approve/reject with a reason, expense policy, status history |
| Sprint 5 | 23 → 27 Nov | **Sprint 5 · Mobile MVP complete** | Capture, correction, submission and decision working end to end on **Android and iOS** |
| Sprint 6 | 30 Nov → 4 Dec | **Sprint 6 · CSV export & user tests** | Accounting **CSV export**, user tests, fixes |
| Wrap-up | 7 Dec | **MVP · Handover & demo day** | Handover package: code, installation guide, licences, test report, known limits |
| Demo day | 8 Dec | **MVP · Handover & demo day** | MVP demo and presentation of the results |

## Public holidays

Plan sprint capacity around them:

- **6 November**: Green March (Sprint 2 is four days)
- **18 November**: Independence Day (Sprint 4 is four days)

## What changed

**2026-10-23**

- 📱 **Mobile only.** The MVP is a Flutter app for **Android and iOS**. The installable web app (PWA) and desktop targets are out of scope. Sprint 5 is now "Mobile MVP complete".
- 📤 **CSV export only.** The Sage connection is removed. The MVP ships a documented CSV that any accounting software or ERP can import. Specific export adapters may come after the MVP.

## After the MVP

See [Product Vision → Vision after the MVP](Product-Vision#vision-after-the-mvp): WhatsApp and voice notes in darija, five specialised agents connected through MCP, export adapters, dashboard, self-hosting.
