# Contrat d’intégration — DESIGN-000
Issue #15 — Sprint 1, octobre 2026. Ce contrat décrit le socle commun de l’interface V1 : routes, dossiers et conventions à respecter par les tickets #16 à #25.

## Points d’entrée
| Constante AppRoutes | Route | Destination actuelle | Futur ticket |
|---|---|---|---|
| menu | / | NavigationMenuScreen, menu de revue | #15 |
| login | /connexion | PlaceholderScreen : Connexion | #18 |
| collaborator | /collaborateur | PlaceholderScreen : Espace collaborateur | #19 |
| capture | /depenses/capture | PlaceholderScreen : Capture du justificatif | #20 |
| review | /depenses/verification | PlaceholderScreen : Vérification des informations | #20 |
| manager | /responsable | PlaceholderScreen : Espace responsable | #21 |
| accountant | /comptable | PlaceholderScreen : Espace comptable | #22 (fermé, à replanifier) |
| settings | /parametres | PlaceholderScreen : Paramètres | #23 |

Une seule liste de destinations alimente le menu et le routeur. Un écran réel s’enregistre dans `AppRouter.screens` ; toute autre destination affiche PlaceholderScreen. Une destination inconnue affiche une page de récupération. L’accès direct crée une seule route initiale : aucun écran intermédiaire inexistant n’est ajouté. Le retour visible revient à l’écran précédent, ou au menu si l’écran est entré directement. « Revenir aux espaces » réinitialise la pile au menu.

## Fichiers communs
- main.dart : démarrage uniquement.
- app/rembo_app.dart : MaterialApp et thème provisoire.
- app/app_routes.dart : noms et métadonnées de destination.
- app/app_router.dart : résolution et remplacement des écrans provisoires.
- app/placeholder_screen.dart : unique écran d’attente.
- app/navigation_menu_screen.dart : menu temporaire.
- app/skeleton_widgets.dart : éléments de présentation propres à ce socle, pas un design system complet.
- core/theme/skeleton_colors.dart : palette provisoire, importable par les modules.
- core/demo/demo_expenses.dart : données fictives immuables.
- features/ : modules futurs.

## Contrat avec les modules
Chaque module peut être développé isolément avec ses propres données fictives. L’intégrateur #24 remplace la destination provisoire seulement lorsque le module est disponible. Ne jamais importer un écran absent. Les noms de route restent stables ; une extension doit être coordonnée avec #17/#24. Le profil, la récupération de mot de passe et les historiques recevront leurs destinations dans leurs tickets respectifs.

Les montants des fixtures sont des centimes entiers de MAD, les dates sont civiles, les statuts disponibles sont draft, submitted, approved et rejected. Le jeu est fictif et non affiché comme un compte réel dans cette ébauche. Aucun calcul fiscal ou règle métier ajouté.

## Design provisoire
Indigo #4A35E0, nuit #2E2A7E, encre #0E0E14, surface #EEEFFD. Palette provisoire isolée dans SkeletonColors (core/theme/skeleton_colors.dart) ; polices de repli et composants Material. Le ticket #16 remplacera ces conventions par le design system partagé, en coordination avec le socle.

## Limites explicites
Tout écran métier est provisoire. Aucun effet réseau métier ou stockage. Naviguer vers « Connexion » n’authentifie personne. Le menu n’est pas un contrôle de rôles. Ni la vérification Android ni l’acceptation collective ne se déduisent du rendu navigateur.

## Conventions
- Tous les chemins sont relatifs à `lib/`. Un module vit dans `features/<module>/` ; dans `app/`, il n’importe que `app_routes.dart`. Seul `app/app_router.dart` importe les modules.
- Les noms de route sont en français, en minuscules, sans accents ; on les référence toujours par la constante `AppRoutes`, jamais par une chaîne littérale.
- Ajouter une destination : une entrée dans `AppRoutes.destinations`. Le menu, le routeur et les tests la prennent en compte automatiquement.
- Les clés de test stables sont `navigation-menu`, `destination-<route>`, `destination-title` et `back-to-menu`.
- `dart format`, `flutter analyze` et `flutter test` doivent passer avant toute PR (voir la CI).

