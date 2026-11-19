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
| `submit_expense(id)` | Contrôle automatique : plafond, justificatif exigé, doublon (même jour, même montant), catégorie « Autre », date de plus de 60 jours. Tout passe par `needs_review` ; une dépense conforme n’y porte aucun signalement. Si l’entreprise a activé `auto_approve`, une dépense conforme passe directement à `approved` (agent) |
| `approve_compliant(ids)` | Responsable uniquement : valide en un geste les dépenses conformes (sans signalement) de son équipe, jamais la sienne ; renvoie le nombre validé |
| `set_auto_approve(on)` | Responsable uniquement : laisse le contrôle valider seul les dépenses conformes (désactivé par défaut) |
| `decide_expense(id, approve, reason)` | Responsable de l’entreprise uniquement, jamais sur sa propre dépense ; motif obligatoire pour un rejet |
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

Mise en service :
1. Créez une application Meta avec le produit **WhatsApp** et un numéro ; relevez le jeton d’accès, l’identifiant du numéro et le secret de l’application.
2. `supabase secrets set WHATSAPP_VERIFY_TOKEN=… WHATSAPP_APP_SECRET=… WHATSAPP_TOKEN=… WHATSAPP_PHONE_NUMBER_ID=…`
3. `supabase functions deploy whatsapp-webhook --no-verify-jwt` (la fonction vérifie elle-même la signature de Meta).
4. Dans la console Meta, déclarez l’URL de la fonction comme webhook avec le même `WHATSAPP_VERIFY_TOKEN`, et abonnez-vous au champ `messages`.
5. Renseignez `REMBO_WHATSAPP_NUMBER` dans `.env` pour afficher « Ouvrir WhatsApp » dans l’application.

Ce que la fonction comprend aujourd’hui :
- **Texte** (« Taxi, 45 dirhams, client Atlas ») : montant, catégorie par mots-clés, client ou projet. Sans IA : une phrase inhabituelle donne un brouillon à compléter.
- **Photo** : enregistrée comme justificatif, brouillon à compléter.
- **Note vocale** : enregistrée et écoutable dans l’application. Elle n’est transcrite que si `TRANSCRIBE_URL` pointe vers un service de transcription (à choisir, notamment pour la darija) ; sinon le brouillon est à compléter.
- Pas de réponse vocale de l’agent.

## Pas encore en place
- **Lecture automatique des reçus** : aucune Edge Function n’est fournie. L’application appelle `read-receipt` seulement si `REMBO_OCR=true` (contrat décrit dans `lib/core/data/supabase_backend.dart`) ; sinon la saisie est manuelle, photo jointe.
- **E-mails d’invitation** : l’invitation est enregistrée, aucun e-mail n’est envoyé.
- **CSV** : généré sur le téléphone à partir des lignes que le serveur vient de marquer exportées (le wiki prévoit une Edge Function).
- **Tests RLS automatisés** (pgTAP) : à écrire ; exigés par la Definition of Done.
- Une entreprise avec un seul responsable ne peut pas faire valider les exceptions de ce responsable.
