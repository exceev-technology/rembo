# Revue de la V1 REMBO — Sprint 1

Issue #25. Revue des interfaces et des comportements simulés de la V1 ; aucun service backend n’est concerné. Version revue : branche `feat/24-integration-modules` (tous les modules raccordés).

**Méthode.** Chaque parcours a été vérifié par des tests automatisés (`flutter test` : 51 tests, dont 4 parcours de bout en bout dans `test/journeys_test.dart`) et par relecture du code. Les points marqués *à vérifier sur téléphone* n’ont pas pu l’être sans appareil : ils restent ouverts jusqu’au passage sur émulateur Android ou téléphone réel.

## 1. Parcours
| Parcours | Résultat | Preuve |
|---|---|---|
| Connexion : champs vides, mot de passe masqué/affiché, chargement, récupération | ✅ | `test/features/auth_test.dart` |
| Tableau de bord collaborateur : total, statuts, liste filtrée, détail, liste vide | ✅ | `test/features/collaborator_test.dart` |
| Déclaration : capture, lecture simulée, correction, champs manquants, récapitulatif, confirmation | ✅ | `test/features/expenses_test.dart`, `journeys_test.dart` |
| Approbation et rejet, motif obligatoire, auto-approbation bloquée, historique | ✅ | `test/features/manager_test.dart`, `journeys_test.dart` |
| Export comptable : filtre, sélection, total, prévisualisation, export simulé, historique | ✅ | `test/features/accountant_test.dart`, `journeys_test.dart` |
| Profil, paramètres, notifications, états vide / chargement / erreur / hors ligne | ✅ | `test/features/common_test.dart` |
| Toutes les routes : menu, accès direct, retour système, route inconnue | ✅ | `test/widget_test.dart` |

## 2. Expérience utilisateur
| Point | Résultat |
|---|---|
| Lisibilité à 320 px avec texte agrandi ×2 | ✅ aucun débordement sur les 9 destinations (tests) — rendu réel *à vérifier sur téléphone* |
| Montants en MAD, virgule décimale, espaces fines, chiffres tabulaires | ✅ `formatMad` partagé |
| Couleurs et composants communs | ✅ modules #18–#23 ; ⚠ écran Bienvenue hors design system (voir P4) |
| Boutons et retours arrière | ✅ retour conservant les saisies, confirmation non réversible |
| Écrans incomplets ou provisoires | Aucun : `PlaceholderScreen` ne sert plus qu’aux routes inconnues |
| Lecteur d’écran (TalkBack / VoiceOver) | *À vérifier sur téléphone* |

## 3. Problèmes observés
| # | Problème | Gravité | Module | Correction proposée |
|---|---|---|---|---|
| P1 | Aucune exécution sur Android ou iOS : seule la cible Linux et les tests ont été utilisés | **Bloquant** pour la validation | #25 | Lancer `flutter run` sur un émulateur Android avant la Sprint Review |
| P2 | Les données ne circulent pas entre modules : une dépense soumise (#20) n’apparaît ni dans la liste du collaborateur (#19) ni chez le responsable (#21) | Démo — à annoncer | #19, #20, #21, #22 | Sprint 2 : un dépôt de dépenses partagé (puis Supabase) remplaçant les données fictives par module |
| P3 | La connexion mène toujours à l’espace collaborateur ; responsable et comptable ne sont accessibles que par le menu de revue | Démo — à annoncer | #18, #17 | Sprint 2 : redirection selon le rôle du compte |
| P4 | ~~L’écran Bienvenue utilise ses propres couleurs au lieu de `RemboColors`~~ | Corrigé | #17 | Couleurs, logo et police mono du design system |
| P5 | ~~Les polices de la charte ne sont pas embarquées~~ | Corrigé | #16 | Polices variables embarquées (SIL OFL), axe `wght` explicite |
| P6 | Prénom « Amina » écrit en dur dans l’accueil collaborateur alors que #23 définit `DemoProfile` | Amélioration | #19 | Lire le nom depuis un profil partagé |
| P7 | Pas d’accès aux paramètres depuis les espaces responsable et comptable | Amélioration | #21, #22 | Ajouter l’icône Paramètres dans leur barre |
| P8 | L’application démarre sur le menu de revue (`/`) | À décider | #17, #24 | Démarrer sur `/bienvenue` une fois le menu retiré |
| P10 | Les statuts diffèrent de la vision V6 des maquettes et de l’album (Brouillon, À examiner, Validée, Rejetée, Exportée ; validation possible par un agent) | **À décider** | #15, #19–#22 | Fixer un cycle de vie unique avec l’équipe, puis renommer `DemoExpenseStatus` et ses libellés dans un seul ticket |
| P9 | L’issue #22 est fermée sur GitHub alors que son écran est livré | Suivi | #22 | Rouvrir l’issue ou rattacher la PR à un nouveau ticket |

## 4. Album Flutter « 30 écrans » : ce qui a été repris
L’album livré avec les maquettes a été comparé au code. Ses pages sont des démonstrations courtes, toutes branchées sur un état global de démo (`RemboDemoStore`, `activeId`) ; elles n’ont pas été copiées, pour garder un seul design system et les modules de chaque membre.

| Élément de l’album | Décision | Où |
|---|---|---|
| Polices Archivo, Instrument Sans, JetBrains Mono + licences | Repris | #16 `assets/fonts/` |
| Logo extrait du pitch | Repris (fond rendu transparent) | #16 `RemboLogo` |
| Reçu 3D | Repris, optimisé en WebP (1,3 Mo → 28 Ko), un par écran au plus | #16 `RemboIllustration`, #19, #20 |
| Fond lavande et bordures `#DED9F2`, thème de barre de navigation | Repris | #16 |
| Interface Material en français (`flutter_localizations`) | Repris | #16 `RemboApp` |
| Montant lu en entiers, 2 décimales au plus, sans virgule flottante | Repris (corrige un bug) | #20 `ExpenseDraft.parseAmount` |
| Date contrôlée sur le calendrier (31/02 refusé), ni future ni avant 2000 | Repris (corrige un bug) | #20 `ExpenseDraft.parseDate` |
| « Saisir manuellement » | Ajouté | #20 capture |
| Inscription, entreprise, équipe, règles, WhatsApp, doublon, explication, suivi, correction, envoi interrompu | Hors périmètre du sprint 1 : backlog | — |
| `RemboDemoStore`, catalogue, `main.dart`, `pubspec.yaml`, dossier Android de l’album | Écartés (démo ou en conflit avec le dépôt) | — |
| Statuts V6 | En attente de décision | P10 |

## 5. Limites connues de la V1
- Aucune donnée réelle : comptes, dépenses, décisions et exports sont fictifs et disparaissent à la fermeture.
- Pas de caméra, d’import de fichier, de lecture OCR ni de fichier CSV : tout est simulé.
- Pas d’authentification : tout e-mail valide ouvre l’espace collaborateur.
- Aucun calcul fiscal : la TVA est saisie ou « lue », jamais recalculée.
- Pas de mode sombre ni de traduction (français uniquement).

## 6. Parcours de démonstration (≈ 8 min)
1. **Bienvenue → Connexion** (#17, #18) : laisser un champ vide pour montrer l’erreur, afficher le mot de passe, se connecter.
2. **Accueil collaborateur** (#19) : total, filtre « Approuvée », détail d’une dépense.
3. **Nouvelle dépense** (#20) : « Prendre une photo » → lecture → choisir « Repas », écrire le motif → récapitulatif → soumettre. Puis rejouer avec « Tester avec un reçu illisible ».
4. **Paramètres** (#23) : profil, notifications, activer « Simuler une absence de connexion » puis ouvrir les notifications.
5. **Menu → Espace responsable** (#21) : demande avec alerte, rejet avec motif ; ouvrir sa propre dépense (action indisponible) ; historique.
6. **Menu → Espace comptable** (#22) : filtre « Transport », tout sélectionner, prévisualiser, exporter, historique.
7. Conclure sur P2, P3 et les limites.

## 7. Contributions
| Membre | Tickets | À présenter |
|---|---|---|
| Mavens06 | #15, #17, #20, #25 | Squelette et routes, parcours et Bienvenue, déclaration de dépense, cette revue |
| MohamoudouSanogo | #16, #21, #24 | Design system, espace responsable, intégration |
| Hafssa250 | #18, #23 | Connexion, écrans communs et états |
| Mohamed-CHAKIR | #19, #22 | Espace collaborateur, espace comptable |

Chaque membre présente l’étape de démonstration correspondant à son ticket et une chose apprise pendant le sprint.
