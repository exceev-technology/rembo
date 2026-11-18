import 'package:flutter/material.dart';

import '../core/theme/skeleton_colors.dart';
import 'app_routes.dart';
import 'skeleton_widgets.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.destination});
  final RemboDestination? destination;

  @override
  Widget build(BuildContext context) {
    final destination = this.destination;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Retour',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed(AppRoutes.menu);
            }
          },
        ),
        title: const RemboWordmark(),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  PreviewLabel(
                    label: destination == null
                        ? 'Destination inconnue'
                        : 'Écran provisoire',
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: SkeletonColors.surface,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      destination?.icon ?? Icons.explore_off_outlined,
                      color: SkeletonColors.primary,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    destination?.title ?? 'Cet espace est introuvable',
                    key: const ValueKey('destination-title'),
                    style: const TextStyle(
                      fontSize: 32,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    destination?.description ?? 'Revenez au menu pour choisir une destination disponible.',
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.6,
                      color: SkeletonColors.muted,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (destination != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: SkeletonColors.border),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Une place pour la suite.',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Cet écran permet pour le moment de parcourir la structure. '
                            'Son interface et ses actions seront ajoutées lors des prochaines étapes.',
                            style: TextStyle(
                              color: SkeletonColors.muted,
                              height: 1.6,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Aucune donnée saisie ou enregistrée.',
                            style: TextStyle(
                              fontSize: 12,
                              color: SkeletonColors.deep,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                  FilledButton.icon(
                    key: const ValueKey('back-to-menu'),
                    icon: const Icon(Icons.grid_view_rounded, size: 18),
                    label: const Text('Revenir aux espaces'),
                    onPressed: () => Navigator.of(context)
                        .pushNamedAndRemoveUntil(AppRoutes.menu, (_) => false),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
