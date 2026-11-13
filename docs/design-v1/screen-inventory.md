# Inventaire des écrans REMBO — V1

Issue #17. État au début du sprint : seuls le menu et l’écran Bienvenue sont réels ; toutes les autres routes affichent `PlaceholderScreen` jusqu’à leur raccordement par #24.

| Écran | Classe | Route ou accès | Module | Ticket | Données fictives nécessaires |
|---|---|---|---|---|---|
| Menu de revue | `NavigationMenuScreen` | `/` | `app/` | #15 | — |
| Bienvenue | `WelcomeScreen` | `/bienvenue` | `features/onboarding/` | #17 | Reçu illustratif |
| Connexion | `LoginScreen` | `/connexion` | `features/auth/` | #18 | Aucune (tout e-mail valide est accepté) |
| Récupération | `ForgotPasswordScreen` | interne (Connexion) | `features/auth/` | #18 | — |
| Accueil collaborateur | `CollaboratorHomeScreen` | `/collaborateur` | `features/collaborator/` | #19 | `demoExpenses` (statuts, montants) |
| Mes dépenses | `ExpensesListScreen` | interne | `features/collaborator/` | #19 | idem |
| Détail d’une dépense | `ExpenseDetailScreen` | interne | `features/collaborator/` | #19 | idem |
| Capture | `CaptureScreen` | `/depenses/capture` | `features/expenses/` | #20 | Justificatif fictif |
| Vérification | `ReviewScreen` | `/depenses/verification` | `features/expenses/` | #20 | Champs « lus » : fournisseur, date, montant, TVA, ICE |
| Récapitulatif | `SummaryScreen` | interne | `features/expenses/` | #20 | Brouillon en cours |
| Confirmation | `ConfirmationScreen` | interne | `features/expenses/` | #20 | — |
| Demandes en attente | `ManagerHomeScreen` | `/responsable` | `features/manager/` | #21 | Demandes de l’équipe, dont une du responsable |
| Détail de la demande | `ApprovalDetailScreen` | interne | `features/manager/` | #21 | idem + alertes |
| Historique des décisions | `ApprovalHistoryScreen` | interne | `features/manager/` | #21 | Décisions passées |
| Dépenses approuvées | `AccountantHomeScreen` | `/comptable` | `features/accountant/` | #22 | Dépenses approuvées : TVA, catégorie, projet |
| Prévisualisation de l’export | `ExportPreviewScreen` | interne | `features/accountant/` | #22 | Sélection |
| Historique des exports | `ExportHistoryScreen` | interne | `features/accountant/` | #22 | Exports passés |
| Paramètres | `SettingsScreen` | `/parametres` | `features/common/` | #23 | Préférences |
| Profil | `ProfileScreen` | interne | `features/common/` | #23 | Collaborateur fictif |
| Notifications | `NotificationsScreen` | interne | `features/common/` | #23 | Notifications fictives |

## Comportement des boutons principaux
| Bouton | Écran | Effet |
|---|---|---|
| Se connecter | Connexion | Valide les champs ; chargement ~1 s ; ouvre l’accueil collaborateur en remplaçant la connexion |
| Ajouter une dépense | Accueil, liste vide | `pushNamed(AppRoutes.capture)` |
| Continuer | Capture | Actif seulement avec un justificatif ; ouvre la vérification avec le brouillon |
| Voir le récapitulatif | Vérification | Bloque et signale les champs obligatoires vides |
| Soumettre la dépense | Récapitulatif | Envoi simulé puis confirmation |
| Approuver / Rejeter | Détail de la demande | Confirmation / motif obligatoire ; met à jour la liste locale |
| Exporter en CSV | Prévisualisation | Confirmation puis succès fictif ; ajoute un export à l’historique |
