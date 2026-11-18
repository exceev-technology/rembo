# Design system REMBO — V1

Issue #16. Tout le design system s’importe en une ligne :

```dart
import 'package:rembo/core/widgets/rembo_widgets.dart';
```

Le thème est appliqué dans `RemboApp` (`theme: RemboTheme.light()`). Dans un test de module : `MaterialApp(theme: RemboTheme.light(), home: …)`.

## Fondations — `lib/core/theme/rembo_tokens.dart`

| Classe | Contenu |
|---|---|
| `RemboColors` | Charte : `indigo #4A35E0`, `night #2E2A7E`, `ink #0E0E14`, `surface #EEEFFD`, `green #1F9D6B`, `orange #D9822B`, plus `background`, `card`, `muted`, `border`, `danger` et les paires texte/teinte accessibles (`successText`/`successTint`, …). |
| `RemboSpace` | `xs 4`, `sm 8`, `md 12`, `lg 16`, `xl 24`, `xxl 32`. |
| `RemboRadius` | `sm 10`, `md 14`, `lg 20`, `pill`. |
| `RemboElevation` | Ombres `card` et `floating`. |
| `RemboFonts` | Archivo (titres), Instrument Sans (texte), JetBrains Mono (montants), embarquées en polices variables dans `assets/fonts/` (licence SIL OFL). Chaque style gras fixe aussi l’axe `wght`. |
| `RemboText` | `display`, `title`, `subtitle`, `body`, `caption`, `label`, `amount` (chiffres tabulaires). |

Formatage — `lib/core/format/formatters.dart` : `formatMad(16500)` → `165,00 MAD` ; `formatDate(DateTime(2026, 10, 27))` → `27 oct. 2026`. Les montants restent des centimes entiers.

## Composants — `lib/core/widgets/`

| Composant | Paramètres | Exemple |
|---|---|---|
| `RemboPrimaryButton` | `label`, `onPressed`, `icon?`, `loading`, `expand` | `RemboPrimaryButton(label: 'Continuer', onPressed: next)` |
| `RemboSecondaryButton` | `label`, `onPressed`, `icon?`, `expand` | `RemboSecondaryButton(label: 'Reprendre', onPressed: retake)` |
| `RemboTextField` | `label`, `controller?`, `hint?`, `helper?`, `errorText?`, `obscureText`, `suffix?`, `keyboardType?`, `fieldKey?`, `maxLines` | `RemboTextField(label: 'E-mail', errorText: error)` |
| `RemboBadge` | `label`, `tone` (`neutral`, `info`, `success`, `warning`, `danger`), `icon?` | `RemboBadge(label: 'À compléter', tone: BadgeTone.warning)` |
| `StatusBadge` | `status` (`DemoExpenseStatus`) | `StatusBadge(status: DemoExpenseStatus.approved)` |
| `ExpenseCard` | `supplier`, `date`, `amountCentimes`, `status`, `subtitle?`, `onTap?`, `trailing?` | `ExpenseCard.fromDemo(demoExpenses.first, onTap: open)` |
| `RemboMessage` | `tone` (`info`, `success`, `warning`, `error`), `title`, `message?`, `action?` | `RemboMessage(tone: MessageTone.error, title: 'Reçu illisible')` |
| `showRemboSnackBar` | `context`, `text`, `tone` | `showRemboSnackBar(context, 'Dépense envoyée')` |
| `RemboLogo` | `size` (hauteur), `showWordmark` | `RemboLogo(size: 32)` — logo du pitch, pour fond clair |
| `RemboIllustration` | `height` | `RemboIllustration(height: 140)` — reçu 3D décoratif, un par écran au plus |

L’application est en français (`flutter_localizations`, locale `fr`) : textes Material, sélecteurs de date et infobulles.

Libellés de statut partagés : Brouillon, Soumise, Approuvée, Rejetée.

## Règles
- Aucun code couleur en dur dans un module : passer par `RemboColors`.
- Les composants s’adaptent à 320 px de large et au texte agrandi ×2 (testé dans `test/design_system_test.dart`).
- Les écrans communs (états vide, chargement, erreur) appartiennent à #23 et vivent aussi dans `core/widgets/`.
