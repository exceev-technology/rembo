# Supabase — mise en route

L’application fonctionne sans serveur en **mode démonstration** (données fictives). Pour de vrais comptes et de vraies données, reliez-la à un projet Supabase.

> Les migrations et les tests SQL (`supabase test db`) tournent en local avec la CLI Supabase.
> Pour des données d’essai, `supabase db reset` charge `seed.sql` (voir plus bas).

## 1. Créer le projet et appliquer le schéma
1. Créez un projet sur <https://supabase.com> (région la plus proche).
2. **SQL Editor** → exécutez, dans l’ordre de leur nom, les fichiers de `migrations/`.
   Avec la CLI : `supabase link --project-ref <ref>` puis `supabase db push`.
3. **Authentication → Sign In / Providers → Email** : laissez « Confirm email » **activé**. Une invitation n’est acceptée que pour une adresse confirmée.

## Données d’essai en local
`supabase start` puis `supabase db reset` applique les migrations et charge `seed.sql` : deux entreprises fictives, une personne par rôle et des dépenses dans chaque statut. Tous les comptes ont le mot de passe `Rembo-2026!` :

| Compte | Rôle |
|---|---|
| `sara@atlas.test`, `karim@atlas.test` | Responsables d’Atlas Conseil |
| `omar@atlas.test`, `salma@atlas.test` | Collaborateurs d’Atlas Conseil |
| `lina@atlas.test` | Comptable d’Atlas Conseil |
| `zed@autre.test` | Responsable d’Autre SARL (autre entreprise) |

`seed.sql` est réservé à un projet **local** : ne l’exécutez jamais sur un projet qui contient des données réelles.

## 2. Relier l’application
```bash
cp .env.example .env      # puis renseignez SUPABASE_URL et SUPABASE_ANON_KEY
flutter run --dart-define-from-file=.env
```
Seule la clé publique (`anon` / `publishable`) va dans `.env`. La clé `service_role` ne quitte jamais le serveur.

## 3. Vérifier (≈ 10 min, trois adresses e-mail)
| Étape | Résultat attendu |
|---|---|
| A crée un compte puis son entreprise | A est Responsable ; 4 règles par défaut dans « Règles de remboursement » |
| A invite B (Collaborateur) et C (Comptable) ; B et C créent leur compte avec ces adresses | Ils arrivent directement dans l’entreprise avec leur rôle |
| B déclare un repas de 150 MAD avec photo | « Conforme, en attente de validation » ; A la valide avec « Tout valider » dans « À examiner » |
| B déclare un repas de 260 MAD | « Transmise à votre responsable » ; visible chez A dans « Exceptions » |
| A rejette avec un motif ; B corrige et soumet à nouveau | Statuts et historique à jour des deux côtés |
| B ouvre `/responsable` | « Accès réservé » ; côté base, B ne lit aucune dépense d’autrui |
| C exporte les dépenses validées | Fichier CSV ; dépenses « Exportée » ; un second export des mêmes lignes est refusé |

## Ce que fait le schéma
| Élément | Rôle |
|---|---|
| `companies`, `profiles`, `memberships`, `invitations` | Entreprise, personnes et rôle (`employee`, `manager`, `accountant`) |
| `policies` | Plafond par catégorie et justificatif exigé |
| `expenses`, `status_events` | Dépenses (centimes de MAD) et historique des statuts |
| `export_batches` | Lots exportés |
| Bucket privé `receipts` | Justificatifs, dans un dossier par personne, lus par liens signés de 5 min |

- **Sécurité par ligne (RLS)** sur toutes les tables : chacun lit ses dépenses ; un responsable celles soumises dans son entreprise ; un comptable celles validées ou exportées.
- **Aucun statut n’est modifiable depuis l’application** : les colonnes `status`, `flags`, `export_batch_id` ne sont pas accordées en écriture. Seules les fonctions suivantes les changent, après avoir vérifié l’appelant.

| Fonction | Règle |
|---|---|
| `submit_expense(id)` | Contrôle automatique (agent de conformité) : plafond, justificatif exigé, doublon (même jour et même montant, ou même fournisseur et même montant à 3 jours près), catégorie « Autre », date de plus de 60 jours, TVA incohérente avec son taux, ICE invalide, dépense en devise (montant payé exigé, conversion à vérifier). Tout passe par `needs_review` ; une dépense conforme n’y porte aucun signalement. Si l’entreprise a activé `auto_approve`, une dépense conforme passe directement à `approved` (agent) |
| `approve_compliant(ids)` | Responsable uniquement : valide en un geste les dépenses conformes (sans signalement) de son équipe, jamais la sienne ; renvoie le nombre validé |
| `set_auto_approve(on)` | Responsable uniquement : laisse le contrôle valider seul les dépenses conformes (désactivé par défaut) |
| `decide_expense(id, approve, reason)` | Responsable de l’entreprise uniquement, jamais sur sa propre dépense ; motif obligatoire pour un rejet |
| `set_managers_declare(on)`, `can_declare(profil)` | Par défaut, un responsable ne déclare pas de dépense (déclencheur sur `expenses`, WhatsApp compris) ; activé, un autre responsable décide de ses dépenses |
| `create_export(ids, request_id, file_name)` | Comptable uniquement ; tout ou rien ; le même `request_id` renvoie le même lot |
| `create_company(...)`, `accept_invitation()` | Création d’entreprise ; adhésion par invitation |

## WhatsApp et notes vocales
Parcours : la personne relie son numéro (Profil → WhatsApp), écrit ou parle à la ligne REMBO, reçoit un résumé, puis confirme par « oui » ou dans l’application. Rien n’est soumis sans cette confirmation ; le contrôle est le même que dans l’application (`control_expense`).

| Élément | Rôle |
|---|---|
| `whatsapp_links` | Numéro relié à un compte, visible de son seul propriétaire |
| `expenses.source`, `transcript`, `voice_path` | Origine du brouillon, texte compris, note vocale (non modifiables depuis l’application) |
| `whatsapp_messages` | Messages déjà traités, pour ignorer les doublons de livraison |
| `functions/whatsapp-webhook` | Reçoit les messages de l’API WhatsApp Cloud (Meta), crée le brouillon, répond |

Mise en service (environ 15 min, numéro de test gratuit de Meta) :
1. **developers.facebook.com** → Créer une app → cas d’usage « Se connecter avec les clients via WhatsApp » (type Business) → produit **WhatsApp** → *Configuration de l’API* : relevez l’**identifiant du numéro de test**, ajoutez votre propre numéro comme destinataire autorisé (5 au plus).
2. Jeton d’accès : celui de la page expire en 24 h ; pour durer, *Paramètres Business* → *Utilisateurs système* → jeton avec `whatsapp_business_messaging` et `whatsapp_business_management`. Secret de l’app : *Paramètres de l’app → Général*. Inventez un jeton de vérification.
3. `supabase secrets set WHATSAPP_TOKEN=… WHATSAPP_PHONE_NUMBER_ID=… WHATSAPP_APP_SECRET=… WHATSAPP_VERIFY_TOKEN=…` (tapez-les vous-même : ils ne vont jamais dans le dépôt).
4. `supabase functions deploy whatsapp-webhook --no-verify-jwt` (la fonction vérifie elle-même la signature de Meta ; les messages non signés sont refusés).
5. Console Meta → *WhatsApp → Configuration* → webhook : `https://<ref>.supabase.co/functions/v1/whatsapp-webhook`, même jeton de vérification, abonnement au champ **messages**.
6. Dans l’application, chacun relie son numéro (Profil → WhatsApp) ; `REMBO_WHATSAPP_NUMBER` dans `.env` affiche « Ouvrir WhatsApp ».

Ce que la fonction comprend :
- **Texte** (« Taxi, 45 dirhams, client Atlas ») : montant, catégorie par mots-clés, client ou projet ; résumé renvoyé, « oui » soumet.
- **Fil de la conversation** : chaque message est lu par **l’agent de conversation** (`whatsapp-webhook/conversation.ts`, moteur des reçus), avec les échanges du jour (`whatsapp_turns`, oubliés après 30 jours) et le dernier brouillon. « Il manque le client Marjane » ou « c’était 50 dh » complètent ce brouillon, « annule » le supprime, une autre dépense en crée un nouveau. Sans moteur, des règles simples font de même pour un client ou un projet ajouté et pour « annule ».
- **Photo** : gardée comme justificatif et **lue par le moteur de reçus** (`RECEIPT_API_URL`, le même que `read-receipt`) : fournisseur, ICE, date, montant, TVA, devise ; la légende ajoute le contexte. Sans moteur, brouillon à compléter.
### Moteur d’IA retenu : Gemini (Google AI Studio)

Pour la démo et les tests utilisateurs, la lecture des photos et la transcription des notes vocales passent par **Gemini**, avec une clé gratuite de [Google AI Studio](https://aistudio.google.com/apikey). L’offre gratuite peut réutiliser ce qu’on lui envoie : **reçus et notes vocales fictifs uniquement** (d’où le verrou `…_SHARED_ENGINE=fictitious-data-only`). Pour de vraies données, passer à l’offre payante (données non réutilisées) ou à un moteur hébergé par l’entreprise.

```bash
supabase secrets set \
  RECEIPT_API_URL=https://generativelanguage.googleapis.com/v1beta/openai \
  RECEIPT_MODEL=gemini-2.5-flash RECEIPT_API_KEY=<clé> \
  RECEIPT_SHARED_ENGINE=fictitious-data-only \
  TRANSCRIBE_API_URL=https://generativelanguage.googleapis.com/v1beta \
  TRANSCRIBE_MODEL=gemini-2.5-flash TRANSCRIBE_API_KEY=<clé> \
  TRANSCRIBE_SHARED_ENGINE=fictitious-data-only
```

Un moteur gratuit est souvent saturé (« high demand », erreur 503) ou à court de quota (20 lectures par jour pour certains modèles). Le serveur réessaie une fois (pas quand le quota du jour est épuisé), puis essaie tour à tour les modèles de secours, chacun avec son propre quota :
`RECEIPT_FALLBACK_MODEL=gemini-3.5-flash,gemini-3.5-flash-lite,gemini-2.5-flash` (idem pour `TRANSCRIBE_FALLBACK_MODEL`).
Une seule clé, dans les règles : ne pas multiplier les projets pour contourner les limites (interdit par les conditions de Google).

Pour la lecture d’un ticket, le serveur abandonne après 14 s et l’appli après 16 s : le formulaire s’ouvre alors avec ce que le téléphone a lu. Personne n’attend plus longtemps.
Les photos passent par la porte compatible OpenAI de Gemini (`…/v1beta/openai`) ; les notes vocales par son API d’origine (`…/v1beta`, audio OGG de WhatsApp envoyé tel quel). `RECEIPT_MODEL` et `TRANSCRIBE_MODEL` : le modèle Flash proposé par AI Studio au moment du déploiement.

- **Note vocale** (darija, français) : gardée, écoutable dans l’application, **transcrite** (Gemini, ou Whisper) puis comprise comme un texte. Autres moteurs possibles :

| Choix | Secrets |
|---|---|
| Whisper hébergé par l’entreprise (gratuit, privé ; faible en darija sans modèle spécialisé), ex. [faster-whisper-server](https://github.com/fedirz/faster-whisper-server) | `TRANSCRIBE_API_URL=http://<serveur>:8000/v1`, `TRANSCRIBE_MODEL=Systran/faster-whisper-small` |
| Service en ligne gratuit (ex. Groq, `whisper-large-v3`) : **données fictives uniquement** | `TRANSCRIBE_API_URL=https://api.groq.com/openai/v1`, `TRANSCRIBE_MODEL=whisper-large-v3`, `TRANSCRIBE_API_KEY=…`, `TRANSCRIBE_SHARED_ENGINE=fictitious-data-only` |

**Tester sans Meta** (pile locale) : `supabase db reset` relie le numéro d’Omar (+212600000003), puis
```bash
supabase functions serve whatsapp-webhook --no-verify-jwt --env-file tool/whatsapp/local.env
python3 tool/whatsapp/simulate.py "Taxi, 45 dirhams, client Atlas"   # brouillon
python3 tool/whatsapp/simulate.py oui                                  # soumise
python3 tool/whatsapp/simulate.py image assets/bench/r01.jpg --caption "client Atlas"
python3 tool/whatsapp/simulate.py audio note.ogg
```
Le simulateur joue Meta et Gemini sur le port 8765 (mêmes chemins que les vrais services) et affiche les réponses de Rembo.
Tests : `deno test --allow-env supabase/functions/whatsapp-webhook/`.

## Pas encore en place
- **Lecture automatique des reçus** : le téléphone lit d’abord le reçu lui-même (Google ML Kit, hors ligne). Quand il n’y arrive pas (reçu en arabe, manuscrit), l’application appelle `functions/read-receipt`, si `REMBO_OCR=true`.

## Lecteur de reçus côté serveur (`read-receipt`)

Il parle l’API « chat completions » d’OpenAI, que proposent la plupart des moteurs. Deux façons de le brancher :

| Choix | Secrets | Données |
|---|---|---|
| **Modèle hébergé par l’entreprise** (recommandé) : Ollama avec un modèle de vision, ex. `ollama pull qwen2.5vl:7b` | `RECEIPT_API_URL=http://<serveur>:11434/v1`, `RECEIPT_MODEL=qwen2.5vl:7b` | La photo ne quitte pas les serveurs de l’entreprise. Gratuit. |
| **Modèle en ligne gratuit**, ex. Gemini | `RECEIPT_API_URL=https://generativelanguage.googleapis.com/v1beta/openai`, `RECEIPT_MODEL=gemini-2.5-flash`, `RECEIPT_API_KEY=…`, **`RECEIPT_SHARED_ENGINE=fictitious-data-only`** | Une offre gratuite peut réutiliser ce qu’on lui envoie : réservé aux projets de démonstration ou de tests utilisateurs, avec des reçus **fictifs**. Sans la dernière variable, la fonction refuse ce moteur. |

```bash
supabase secrets set RECEIPT_API_URL=… RECEIPT_MODEL=…
supabase functions deploy read-receipt
```
Puis `REMBO_OCR=true` dans `.env`. Chaque lecture est journalisée dans `receipt_readings` (moteur, modèle, durée, résultat, nombre de champs trouvés), jamais le contenu du reçu ; 40 lectures par personne et par jour (`RECEIPT_DAILY_LIMIT`). Tests : `deno test supabase/functions/read-receipt/`.
- **E-mails d’invitation** : l’invitation est enregistrée, aucun e-mail n’est envoyé.
- **CSV** : généré sur le téléphone à partir des lignes que le serveur vient de marquer exportées (le wiki prévoit une Edge Function).
- **Tests RLS automatisés** (pgTAP) : à écrire ; exigés par la Definition of Done.
- Une entreprise avec un seul responsable ne peut pas faire valider les exceptions de ce responsable.

## Politique de remboursement de l’entreprise (`read-policy`)

Par défaut, REMBO applique ses propres règles : un plafond par catégorie, un délai de déclaration de 60 jours, et le projet ou client facultatif. Dans **Profil → Règles de remboursement**, un responsable peut importer la politique de son entreprise (PDF de 6 pages au plus, photo ou fichier texte) ou en coller le texte.

1. `functions/read-policy` la fait lire par **le moteur des reçus** (mêmes secrets `RECEIPT_*`, même règle de confidentialité). Le moteur en tire ce que REMBO sait vérifier : délai, projet obligatoire, plafond et justificatif par catégorie. Les autres règles (« pas d’alcool », « classe économique »…) sont listées à part, pour que les responsables les vérifient eux-mêmes.
2. L’application montre ces **propositions** face aux règles en place. Rien ne change tant que le responsable n’a pas touché **Appliquer ces règles**.
3. `apply_policy` (SQL) vérifie et enregistre ce qu’il a accepté. `control_expense` suit ensuite le délai et la règle du projet de l’entreprise. `reset_policy` revient aux règles de REMBO.

```bash
supabase db push                       # migration 20261128000000_company_policy
supabase functions deploy read-policy
```
Sans serveur (mode local ou démo), seul un texte collé est lu, par des règles simples (`lib/core/agents/policy_reader.dart`). Tests : `deno test supabase/functions/read-policy/` et `supabase/tests/database/10_company_policy.test.sql`.
À terme, un modèle hébergé par l’entreprise est préférable : la politique interne ne quitte alors pas ses serveurs.

## E-mails de confirmation (projet hébergé)

L’appli confirme une adresse et change un mot de passe avec un **code à 6 chiffres** reçu par e-mail et tapé dans l’appli : aucun lien à ouvrir, aucune page web nécessaire.

Le service d’envoi intégré de Supabase n’envoie que quelques e-mails par heure, et seulement aux membres de l’organisation. Pour de vrais utilisateurs, brancher un SMTP, par exemple **Brevo** (gratuit, 300 e-mails par jour, sans nom de domaine) :

1. brevo.com → compte gratuit → *Senders, Domains & Dedicated IPs* : ajouter et vérifier l’adresse d’expéditeur.
2. *SMTP & API* → onglet SMTP : relever le serveur (`smtp-relay.brevo.com`, port 587), l’identifiant, et générer une clé SMTP.
3. Tableau de bord Supabase → *Authentication* :
   - *Emails* → *SMTP Settings* : activer, coller serveur, port, identifiant, clé, adresse et nom d’expéditeur (« Rembo »).
   - *Emails* → *Templates* : « Confirm signup » et « Reset password », coller `supabase/templates/confirmation.html` et `recovery.html` (sujets dans `config.toml`).
   - *Sign In / Providers* → *Email* : longueur du code (Email OTP length) à 6.
   - *Rate Limits* : e-mails par heure, par exemple 30.
