# Product Vision

> 🧾 Open-source expense reports for Moroccan small and medium-sized businesses. **AI agents prepare each expense, a person decides.**

## The problem

In many Moroccan SMBs, a single person handles payroll, HR **and** expense reports. They receive receipts that fade, crumpled tickets and invoices without an ICE. VAT is often hard to recover. Everything is retyped into a spreadsheet.

Today's typical journey (to be confirmed in user interviews):

1. The paper receipt stays in a pocket, or someone takes a photo of it
2. The employee copies the amounts into a spreadsheet
3. The manager approves by email or chat
4. The accountant re-enters every line
5. Reimbursement is tracked by hand

**To check in interviews:** who declares, who approves, who enters the data, and which software is actually used.

## Question and hypothesis

**Question:** how can an employee declare an expense on mobile, and their company check and export it, without needless re-entry and without depending on a single accounting tool?

**Hypothesis:** an expense flow adapted to Moroccan business rules reduces re-entry and errors. The gain has to show in user tests ([Testing Protocol](Testing-Protocol)). We make no promise about OCR accuracy.

## Personas

| Persona | Role in Rembo | Needs |
|---|---|---|
| **Employee** (*collaborateur*) | Declares expenses | Capture a receipt in seconds, fix what the OCR got wrong, know the status of each expense |
| **Manager** (*responsable*) | Approves or rejects | Handle only the exceptions, decide quickly with the receipt and the policy at hand |
| **Accountant** (*comptable*) | Controls and exports | Approved, complete expenses (VAT, ICE, allocation) exported without retyping |

Field personas from the pitch, used for scenarios and mockups:

- **Youssef, field sales rep.** He photographs his lunch receipt. The agent extracts the date, merchant, 380 MAD and 10% VAT, and shows the source of each field. When the reason is missing, the agent says so. Youssef completes it and submits.
- **Ahmed, delivery driver.** He is more comfortable with WhatsApp than with forms. He sends a voice note in darija ("taxi, 45 dirhams, client Atlas") and confirms with a simple "yes". *(Post-MVP, see below.)*

## MVP scope (8 December 2026)

| Capability | Description |
|---|---|
| 📸 **Capture** | Photo or import of a receipt in the Flutter app (Android + iOS). OCR suggests date, supplier, amount and currency; the user reviews and corrects |
| 💰 **Expense in MAD** | Category, reason, client or project allocation. Simple policy: required fields and alert limits |
| ✅ **Approval** | The manager approves or rejects with a reason. **No self-approval.** Status history is kept |
| 📤 **CSV export** | The accountant reviews approved expenses and exports a **documented CSV** that any accounting software or ERP can import |
| 📱 **Platform** | Native mobile app built with Flutter for **Android and iOS** |

## AI agents: they prepare, a human decides

Agents read the receipt, classify the expense, check it against the company rules and spot duplicates. Expenses that comply with the policy move forward on their own. A manager is asked to decide in only two cases:

1. **An inconsistency** between the expense and the reimbursement policy
2. **An ambiguity** the agent cannot resolve on its own

An employee can never approve their own expense. Every agent action is logged. See [Architecture](Architecture#ai-agents-mcp-and-human-in-the-loop).

## Vision after the MVP

- 💬 **WhatsApp channel:** declare an expense by photo or voice note in darija; Rembo replies with a voice summary and the employee confirms with "yes". Nothing to install, nothing to read, nothing to write.
- 🤖 **Five specialised agents:** reading, classification, policy check, duplicate detection and export preparation, connected to company tools through **MCP**.
- 🔌 **Export adapters** for specific accounting software and ERPs, on top of the CSV export.
- 📊 **Management dashboard** for the month's spending.
- 🏢 **Self-hosting** in Morocco or on the company's own servers.

## Out of scope for the MVP

- Web app / PWA and desktop apps
- Direct connectors to Sage or any other ERP (CSV export only)
- WhatsApp and voice input
- Bank transfers, payment cards, payroll
- Archiving with legal evidentiary value
- Full offline synchronisation

## Why Morocco-specific

- **MAD first:** amounts, policies and exports are in Moroccan dirhams
- **TVA (VAT):** rate and amount captured per receipt so VAT can be recovered
- **ICE:** the supplier's *Identifiant Commun de l'Entreprise* is captured when it is on the receipt
- **Law 09-08 / CNDP:** personal data is framed under Moroccan data-protection law before any real use ([Data Protection & Security](Data-Protection-and-Security))
- **Open source (MIT):** auditable code, self-hostable, no per-employee licence fee
