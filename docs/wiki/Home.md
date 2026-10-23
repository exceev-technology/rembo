# Welcome to the Rembo wiki

**Rembo** is the open-source expense management app for small and medium-sized businesses in Morocco.
An employee snaps a receipt on their phone, AI agents prepare the expense, and a person decides.
The accountant gets a clean CSV export with no re-entry.

> **AI agents prepare, a human decides.**

Rembo started as **Project 02 of the ECC Innovation program 2026** (École Centrale Casablanca × Exceev Technology).
The MVP will be presented on **8 December 2026**.

---

## Quick links

| | |
|---|---|
| 📦 Repository | [exceev-technology/rembo](https://github.com/exceev-technology/rembo) |
| 🗂️ Sprint board | [GitHub Project "Rembo"](https://github.com/orgs/exceev-technology/projects/1) |
| 🐛 Report a bug / 💡 propose a feature | [New issue](https://github.com/exceev-technology/rembo/issues/new/choose) |
| 💬 Questions & ideas | [GitHub Discussions](https://github.com/exceev-technology/rembo/discussions) |
| 🤝 How to contribute | [CONTRIBUTING.md](https://github.com/exceev-technology/rembo/blob/main/CONTRIBUTING.md) |
| 🔐 Report a vulnerability | [Security policy](https://github.com/exceev-technology/rembo/security/policy) |

## MVP at a glance

| Step | What happens |
|---|---|
| 📸 **Capture** | Photo or upload of a receipt from the Android / iOS app |
| 🧠 **Understand** | OCR suggests date, supplier, amount, currency and VAT; the employee checks and corrects |
| ✅ **Approve** | Agents check the company policy; the manager approves or rejects with a reason. No self-approval |
| 📤 **Export** | The accountant exports approved expenses as a documented **CSV** that any accounting software can import |

**Stack:** Flutter (Android + iOS) · Supabase (Postgres, Auth, RLS, Storage, Edge Functions) · AI agents connected through MCP.

## Wiki index

**Product**
- [Product Vision](Product-Vision): problem, personas, MVP scope, what is out of scope
- [Roadmap](Roadmap): sprints, milestones and dates
- [Glossary](Glossary): French → English terms used in the project

**Engineering**
- [Architecture](Architecture): Flutter + Supabase, AI agents and MCP, security model, draft data model
- [Development Setup](Development-Setup): run the app and the local Supabase stack
- [Testing Protocol](Testing-Protocol): how we validate the MVP with users
- [Data Protection & Security](Data-Protection-and-Security): ground rules for data and secrets

**Ways of working**
- [Scrum on GitHub](Scrum-on-GitHub): roles, ceremonies, board, labels, Definition of Ready and Done
- [Git & PR Workflow](Git-and-PR-Workflow): branches, commits, pull requests and reviews
- [Learning Path](Learning-Path): Scrum, Git/GitHub, Flutter, Supabase and MCP resources
- [Team](Team): who does what, Scrum Master rotation

## About this wiki

The wiki source lives in [`docs/wiki/`](https://github.com/exceev-technology/rembo/tree/main/docs/wiki) in the repository.
It is published here automatically by the **Publish wiki** workflow on every merge to `main`.

✏️ **To edit a page, open a pull request that changes `docs/wiki/`.** Edits made in the GitHub web editor are overwritten at the next publish.
