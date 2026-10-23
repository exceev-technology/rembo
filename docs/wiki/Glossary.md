# Glossary

Interviews, mockups and Slack discussions often use French terms. Code, issues and docs use English. This table maps the two.

## Business terms (French → English)

| French | English | Used in code as | Notes |
|---|---|---|---|
| Note de frais | Expense report / expense | `expense` | One declared expense with its receipt |
| Justificatif | Receipt / supporting document | `receipt` | Photo or file proving the expense |
| Ticket (de caisse) | Receipt (till receipt) | `receipt` | |
| Facture | Invoice | `invoice` | |
| Collaborateur / salarié | Employee | `employee` | Declares expenses |
| Responsable / manager | Manager | `manager` | Approves or rejects |
| Comptable | Accountant | `accountant` | Controls and exports |
| Direction | Management | | Follows the dashboard (post-MVP) |
| Déclarer une dépense | Declare / submit an expense | `submit` | |
| Valider / approuver | Approve | `approve` | |
| Rejeter / refuser | Reject | `reject` | Always with a reason |
| Motif | Reason / purpose | `reason` | Why the expense was made, or why it was rejected |
| Imputation | Allocation (cost assignment) | `allocation` | Client or project the expense is charged to |
| Plafond | Limit / cap | `alert_limit` | Above it, the expense is escalated |
| Politique de dépenses | Expense policy | `policy` | Required fields and limits per category |
| Catégorie | Category | `category` | Meals, taxi, fuel, hotel… |
| Fournisseur / marchand | Supplier / merchant | `supplier` | |
| Remboursement | Reimbursement | `reimbursement` | Out of scope for the MVP (no transfers) |
| Export comptable | Accounting export | `export` | CSV only in the MVP |
| Lot d'export | Export batch | `export_batch` | One export run |
| Logiciel comptable / ERP | Accounting software / ERP | | Imports the CSV |
| Ressaisie | Re-entry (retyping) | | What Rembo removes |
| Archivage à valeur probante | Legally binding archiving | | Out of scope |
| TPE / PME | Very small / small and medium-sized businesses (SMBs) | | Rembo's target |

## Moroccan specifics

| Term | Meaning |
|---|---|
| **MAD** | Moroccan dirham, the default currency |
| **TVA** | *Taxe sur la valeur ajoutée*, value-added tax (VAT). Captured as rate and amount |
| **TTC / HT** | *Toutes taxes comprises* / *hors taxes*: amount including / excluding VAT |
| **ICE** | *Identifiant Commun de l'Entreprise*, the company identifier printed on invoices |
| **Loi 09-08** | Moroccan law on the protection of personal data |
| **CNDP** | *Commission Nationale de contrôle de la protection des Données à caractère Personnel*, the data-protection authority |
| **Darija** | Moroccan Arabic. Voice input in darija is part of the post-MVP vision |

## Technical terms

| Term | Meaning |
|---|---|
| **OCR** | Optical character recognition: reading text from a receipt photo |
| **RLS** | Row Level Security: Postgres rules that decide which rows each user can see or change |
| **Edge Function** | Server-side function hosted by Supabase, where secrets live |
| **Signed URL** | Temporary link to a private file in Supabase Storage |
| **`anon` key** | Public Supabase key, safe in the app because RLS protects the data |
| **`service_role` key** | Admin Supabase key that bypasses RLS. **Server side only** |
| **MCP** | Model Context Protocol: an open standard that lets AI agents use tools and data sources |
| **Human-in-the-loop** | A person makes the final decision on exceptions the agents escalate |
| **PR** | Pull request: a proposed change, reviewed before it is merged |
| **DoR / DoD** | Definition of Ready / Definition of Done ([Scrum on GitHub](Scrum-on-GitHub)) |
