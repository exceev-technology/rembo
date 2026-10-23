# Architecture

Rembo is a **Flutter mobile app (Android + iOS)** backed by **Supabase**. AI agents run on the server and reach tools through **MCP**. No secret ever reaches the phone.

## Overview

```mermaid
flowchart LR
    subgraph Phone["📱 Flutter app (Android / iOS)"]
        UI[Screens: capture, review, approve, export]
        SDK[supabase_flutter client<br/>anon key + user JWT]
    end

    subgraph Supabase["☁️ Supabase"]
        Auth[Auth<br/>roles per company]
        DB[(Postgres<br/>+ Row Level Security)]
        Storage[(Storage<br/>private receipts bucket)]
        Edge[Edge Functions<br/>OCR · CSV export · agents]
    end

    subgraph AI["🤖 AI layer (server side)"]
        Agents[Agents: read, classify,<br/>check policy, spot duplicates]
        MCP[MCP servers / tools]
    end

    OCR[OCR service]

    UI --> SDK
    SDK -->|sign in| Auth
    SDK -->|queries under RLS| DB
    SDK -->|upload / signed URL| Storage
    SDK -->|invoke| Edge
    Edge -->|server-side key| OCR
    Edge --> Agents
    Agents --> MCP
    MCP --> DB
    Agents -->|escalate exceptions| DB
```

## Supabase building blocks

| Building block | Use in Rembo |
|---|---|
| **Postgres** | Expenses, categories, expense policies, clients/projects for allocation, export batches, audit log |
| **Auth** | Employee, manager and accountant accounts, with a role **per company** |
| **Row Level Security** | Everyone sees only their own expenses; a manager sees their team's; no self-approval |
| **Storage** | Receipts in a **private bucket**, accessed through short-lived **signed URLs** |
| **Edge Functions** | OCR calls, CSV export generation, agent calls. API keys stay on the server |

The client/project reference data is managed directly in Supabase for the MVP.

## AI agents, MCP and human-in-the-loop

> **Agents prepare, a human decides.**

| Agent responsibility | What it does |
|---|---|
| Read | Extracts date, supplier, amount, currency, VAT and ICE from the receipt, and keeps the source of each field |
| Classify | Suggests the category and the client/project allocation |
| Check policy | Compares the expense with the company's rules (required fields, limits) |
| Spot duplicates | Flags a receipt that looks already declared |

**Escalation rule.** Policy-compliant expenses move forward without human work. A manager is asked to decide in only two cases:

1. **An inconsistency** between the expense and the reimbursement policy
2. **An ambiguity** the agent cannot resolve on its own

**Guardrails**

- An employee can never approve their own expense, whether a human or an agent does the approving.
- Every agent action is written to an audit log: who or what acted, when, on which expense, and why.
- Agents run server side only (Edge Functions). They use **MCP** to reach tools such as the Supabase database or a company's accounting tools.
- The MVP delivers the read and review flow first ([Roadmap](Roadmap)). The full multi-agent setup is part of the [post-MVP vision](Product-Vision#vision-after-the-mvp).

## Security model

| Rule | Enforced by |
|---|---|
| A user only reads their own expenses and receipts | RLS on `expenses` and Storage policies on the receipts bucket |
| A manager reads and decides on their team's expenses only | RLS based on company membership and role |
| Nobody approves their own expense | RLS / check constraint on the decision (`decided_by <> employee_id`) |
| The accountant reads approved expenses of their company and creates exports | RLS by role and company |
| The `service_role` key and OCR / AI keys never leave the server | Edge Functions secrets; only the public `anon` key is in the app |

Every feature ships with its RLS policies **and tests for them** (see the Definition of Done in [Scrum on GitHub](Scrum-on-GitHub#definition-of-done)).

## Data model

> ⚠️ **Draft – to be validated in Sprint 1.** Names and columns will change. The migrations in the repository are the source of truth.

```mermaid
erDiagram
    COMPANY ||--o{ MEMBERSHIP : has
    PROFILE ||--o{ MEMBERSHIP : has
    COMPANY ||--o{ CATEGORY : defines
    COMPANY ||--o{ POLICY : defines
    COMPANY ||--o{ ALLOCATION : "clients / projects"
    PROFILE ||--o{ EXPENSE : declares
    EXPENSE ||--o{ RECEIPT : "has"
    EXPENSE ||--o{ STATUS_EVENT : history
    EXPENSE }o--|| CATEGORY : "classified as"
    EXPENSE }o--o| ALLOCATION : "allocated to"
    EXPORT_BATCH ||--o{ EXPENSE : contains
    EXPENSE ||--o{ AUDIT_LOG : "traced by"
```

| Table | Key columns (draft) |
|---|---|
| `companies` | `id`, `name`, `ice`, `currency` (default `MAD`) |
| `profiles` | `id` (= auth user), `full_name` |
| `memberships` | `company_id`, `profile_id`, `role` (`employee` \| `manager` \| `accountant`), `manager_id` |
| `categories` | `company_id`, `name`, `default_vat_rate` |
| `policies` | `company_id`, `category_id`, `alert_limit_mad`, `required_fields` |
| `allocations` | `company_id`, `kind` (`client` \| `project`), `name` |
| `expenses` | `id`, `company_id`, `employee_id`, `expense_date`, `supplier_name`, `supplier_ice`, `amount_ttc_mad`, `vat_rate`, `vat_amount_mad`, `category_id`, `allocation_id`, `reason`, `status` |
| `receipts` | `expense_id`, `storage_path`, `ocr_payload`, `field_sources` |
| `status_events` | `expense_id`, `from_status`, `to_status`, `actor_id`, `actor_kind` (`human` \| `agent`), `reason`, `created_at` |
| `export_batches` | `id`, `company_id`, `created_by`, `created_at`, `expense_count`, `total_mad` |
| `audit_log` | `actor_id`, `actor_kind`, `action`, `expense_id`, `details`, `created_at` |

Expense status flow (draft): `draft` → `submitted` → `needs_review` (escalated) → `approved` \| `rejected` → `exported`.

## CSV export

> ⚠️ **Draft – to be validated in Sprint 6** with the accountants we interview.

- One row per approved expense, UTF-8, header row, `;` separator, decimal point `.`, dates `YYYY-MM-DD`
- The approved total must equal the exported total (checked in the [Testing Protocol](Testing-Protocol))
- The format is documented in the repository so any accounting software or ERP can map it

| Column | Example | Notes |
|---|---|---|
| `expense_id` | `e7c1…` | Stable identifier |
| `expense_date` | `2026-11-12` | Date on the receipt |
| `employee` | `Youssef A.` | Declaring employee |
| `supplier_name` | `Café Atlas` | |
| `supplier_ice` | `001234567000089` | When printed on the receipt |
| `category` | `Meals` | |
| `allocation` | `Client Atlas` | Client or project |
| `amount_ttc_mad` | `380.00` | Amount including VAT, in MAD |
| `vat_rate` | `10` | Percent |
| `vat_amount_mad` | `34.55` | |
| `amount_ht_mad` | `345.45` | Amount excluding VAT |
| `reason` | `Client lunch` | |
| `approved_by` | `Manager name` | |
| `approved_at` | `2026-11-13` | |
| `export_batch_id` | `b42…` | Groups one export |

## Repository layout

| Path | Content |
|---|---|
| `lib/` | Flutter app source |
| `test/` | Unit and widget tests |
| `android/`, `ios/` | Mobile platform projects (other platform folders are not part of the MVP) |
| `supabase/` | Migrations, seed data, Edge Functions (added in Sprint 1) |
| `docs/wiki/` | Source of this wiki |
| `.github/` | Issue/PR templates, CI and automation workflows |
