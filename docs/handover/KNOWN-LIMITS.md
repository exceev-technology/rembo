# Known limits

What Rembo does not do yet, or only partly, at the end of the MVP. The jury
asked for « the gaps between our targets and our results »: here they are,
each with what would close it.

## Platforms

| Limit | Why | What would close it |
|---|---|---|
| iOS is **built** by the CI on every push to main, and the end-to-end journey is tried on an iPhone simulator, but the app has **not run on a real iPhone** (camera, ML Kit) | No iPhone or Mac in the team | One session on an iPhone with a Mac (Xcode, a free Apple ID is enough for a debug install) |
| No web app, no desktop app | Out of the MVP scope (wiki, 23 Oct.) | Flutter web build; the code already runs on the web in demo mode |

## Reading receipts

| Limit | Why | What would close it |
|---|---|---|
| On the phone, about **9 fields in 10** are right on the 30-receipt bench (91 %, see `docs/test-report`); handwritten receipts drop to 71 % | ML Kit reads print well, handwriting poorly | The server reader, or an engine trained on Moroccan receipts |
| **Arabic receipts** are not read on the phone (supplier, words); amounts and dates are | ML Kit has no Arabic script | The server reader (`read-receipt`) with a vision model that reads Arabic |
| The server reader is **not switched on** in the dev project (`REMBO_OCR=false`) | It needs an engine: a model hosted by the company (free, private) or a free cloud model with fictional data only | Host Ollama with a vision model, set the secrets, deploy the function (`supabase/README.md`) |
| A PDF of several pages: only the **first page** is kept and read | Kept simple for the MVP | Keep the PDF itself in storage and read every page |
| The phone's OCR engine (Google ML Kit) is free but **proprietary** | Best accuracy available on a phone, offline | Plug an open-source engine behind `ReceiptReader`; the bench compares them |

## Agents and rules

| Limit | Why | What would close it |
|---|---|---|
| The agents are **explainable rules**, not learned models: the classification agent knows a list of Moroccan supplier names and learns only from each person's own history | Free, predictable, testable on a phone; every proposal says why | A shared, company-wide history; a small local model for classification |
| Categories are a **fixed list** of five (accounts per category are configurable) | Kept in step between SQL, phone and export | A `categories` table edited by the accountant |
| A receipt in another currency: the person types the **converted amount**; nothing converts it | No exchange-rate source in the MVP | A daily rate (Bank Al-Maghrib) proposed on the form |
| Duplicates are found by date, amount and supplier only | Simple and explainable | Compare the receipt pictures themselves |

## Company and accounts

| Limit | Why | What would close it |
|---|---|---|
| A person belongs to **one company** | MVP rule (`memberships_one_company`) | Several memberships, with a company switch |
| Invitations are **not e-mailed**: the person creates an account with the invited address | No e-mail sending configured | Supabase SMTP and an invitation e-mail |
| The CSV export is a **documented draft**, not yet checked with accountants; no direct connector (Sage or other) | CSV only in the MVP scope | Sprint 6 tests with accountants; export adapters after the MVP |

## Channels

| Limit | Why | What would close it |
|---|---|---|
| **WhatsApp** (text, photo, voice note) works end to end against the local stack (simulator playing Meta and Gemini) but is not yet connected to a Meta number | It needs a Meta app (a free test number writes to 5 numbers) and a Gemini key (AI Studio, free tier: fictional data only) | The Meta app and its secrets, the Gemini key, the webhook deployed (`supabase/README.md`) |
| The early-access form on the site is ready but **not connected** | It needs the public key of the chosen Supabase project in `site/config.js` | Fill `site/config.js` and publish the site |

## Law and compliance

| Limit | Why | What would close it |
|---|---|---|
| No **CNDP** declaration (law 09-08) has been made; real personal data must not be used yet | A step for the company that deploys Rembo | Declare the processing, choose the hosting country |
| Rembo claims **no fiscal compliance** and **no evidentiary value** for copies of receipts | Out of the MVP scope | Legal review; certified archiving |
| The Arabic interface has **not been reviewed by a native speaker** | Written by the team | A review, screen by screen |
