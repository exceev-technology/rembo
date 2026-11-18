# Parcours utilisateurs REMBO — V1

Issue #17. Trois profils, trois parcours. Tout est simulé : aucune donnée n’est envoyée ni enregistrée, les montants sont fictifs. Les routes citées sont les constantes de `lib/app/app_routes.dart`.

## Entrée commune
1. **Bienvenue** (`AppRoutes.welcome`) — « Commencer » ou « Passer » → Connexion.
2. **Connexion** (`AppRoutes.login`) — e-mail + mot de passe → « Se connecter » → chargement simulé → espace du profil (collaborateur en V1).
   - « Mot de passe oublié ? » → **Récupération** (écran interne du module #18) → message « lien envoyé » → retour à la connexion.
   - Sorties : champ vide → message d’erreur sous le champ ; retour système → écran précédent.

## Collaborateur — déclarer une dépense
`accueil → capture → vérification → récapitulatif → confirmation`

| Étape | Écran | Action principale | Retour arrière |
|---|---|---|---|
| 1 | Accueil collaborateur (`AppRoutes.collaborator`) | « Ajouter une dépense » | Quitte l’espace (menu de revue en V1) |
| 2 | Capture (`AppRoutes.capture`) | « Prendre une photo » / « Importer » (simulés) puis « Continuer » ; « Reprendre » efface le justificatif | Accueil, rien n’est conservé |
| 3 | Vérification (`AppRoutes.review`) | Analyse simulée, correction des champs, catégorie, motif, projet → « Voir le récapitulatif » | Capture, justificatif conservé |
| 4 | Récapitulatif (interne #20) | « Soumettre la dépense » | Vérification, valeurs conservées |
| 5 | Confirmation (interne #20) | « Retour à mes dépenses » → accueil ; « Nouvelle dépense » → capture | Désactivé : la dépense est soumise |

Suivi : accueil → « Voir toutes mes dépenses » → liste filtrable par statut → détail d’une dépense. Liste vide → état « Aucune dépense » avec « Ajouter une dépense ».

Erreurs prévues : justificatif illisible (capture), montant absent et champ obligatoire manquant (vérification) — le bouton reste actif, les champs fautifs sont signalés.

## Responsable — décider
`demandes en attente → détail → approbation ou rejet`

| Étape | Écran | Action principale | Retour arrière |
|---|---|---|---|
| 1 | Accueil responsable (`AppRoutes.manager`) | Filtre par statut, ouverture d’une demande | Quitte l’espace |
| 2 | Détail de la demande (interne #21) | « Approuver » → confirmation ; « Rejeter » → motif obligatoire | Accueil, aucune décision prise |
| 3 | Retour à l’accueil | Le statut est mis à jour dans l’état local, la décision rejoint l’historique | — |

Auto-approbation : sur sa propre dépense, les deux boutons sont désactivés avec l’explication « Une autre personne doit valider vos dépenses ». Historique : icône d’horloge dans la barre de l’accueil.

## Comptable — exporter
`dépenses approuvées → sélection → export simulé`

| Étape | Écran | Action principale | Retour arrière |
|---|---|---|---|
| 1 | Accueil comptable (`AppRoutes.accountant`) | Filtre par catégorie, sélection multiple, total recalculé | Quitte l’espace |
| 2 | Prévisualisation (interne #22) | « Exporter en CSV » → confirmation → succès fictif | Accueil, sélection conservée |
| 3 | Accueil | Les dépenses exportées sortent de la liste ; l’export rejoint l’historique | — |

## Commun
Paramètres (`AppRoutes.settings`) → Profil, Notifications (écrans internes #23). Ces écrans utilisent les états partagés : vide, chargement, erreur, hors ligne.
