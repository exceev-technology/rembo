# Modules de l’application
Un dossier par module. Les routes sont déclarées dans app/app_routes.dart et
app/app_router.dart, qui limite chaque route aux rôles autorisés.

| Dossier | Contenu |
|---|---|
| onboarding | Écran de lancement et page d’accueil |
| auth | Connexion, inscription, mot de passe oublié, création de l’entreprise |
| shell | Onglets par rôle, aiguillage après connexion, accès refusé |
| collaborator | Accueil, liste des dépenses, détail d’une dépense, explication de la décision |
| expenses | Capture du justificatif, formulaire, récapitulatif, cas d’erreur |
| manager | Exceptions à décider, décision, équipe, règles de remboursement |
| accountant | Vue d’ensemble et export CSV |
| common | Activité et profil, communs aux trois rôles |
| whatsapp | Liaison d’un numéro WhatsApp et confirmation des dépenses reçues par ce canal |

Les écrans lisent et modifient les données par AppState (core/data/app_state.dart).
Quelques-uns appellent le backend par state.backend : images et notes vocales,
lecture d’un justificatif, e-mail de réinitialisation du mot de passe.
