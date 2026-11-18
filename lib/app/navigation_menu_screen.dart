import 'package:flutter/material.dart';

import '../core/theme/skeleton_colors.dart';
import 'app_routes.dart';
import 'skeleton_widgets.dart';

class NavigationMenuScreen extends StatelessWidget {
  const NavigationMenuScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        key: const ValueKey('navigation-menu'),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [RemboWordmark(), PreviewLabel()],
                ),
                const SizedBox(height: 36),
                const _Introduction(),
                const SizedBox(height: 36),
                const Text(
                  'Explorer les espaces',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choisissez une destination pour découvrir la structure de REMBO.',
                  style: TextStyle(color: SkeletonColors.muted, height: 1.6),
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 900
                        ? 3
                        : constraints.maxWidth >= 580
                        ? 2
                        : 1;
                    final width =
                        (constraints.maxWidth - (columns - 1) * 16) / columns;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final destination in AppRoutes.destinations)
                          SizedBox(
                            width: width,
                            child: _DestinationCard(destination: destination),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
                const Divider(color: SkeletonColors.border),
                const SizedBox(height: 12),
                const Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    Text(
                      'Conçu pour les petites entreprises marocaines.',
                      style: TextStyle(
                        color: SkeletonColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Version de travail · Navigation uniquement',
                      style: TextStyle(
                        color: SkeletonColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Introduction extends StatelessWidget {
  const _Introduction();
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: SkeletonColors.surface,
      borderRadius: BorderRadius.circular(24),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'UN JUSTIFICATIF. UN PARCOURS CLAIR.',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: SkeletonColors.deep,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Les frais,\nsimplement.',
            style: TextStyle(
              fontSize: constraints.maxWidth < 400 ? 38 : 58,
              height: 1.06,
              fontWeight: FontWeight.w800,
              color: SkeletonColors.deep,
              letterSpacing: -1.8,
            ),
          ),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: const Text(
              'Du reçu à la comptabilité, un espace pour chacun. '
              'Voici les premiers repères de votre future application.',
              style: TextStyle(
                fontSize: 16,
                height: 1.6,
                color: SkeletonColors.deep,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _JourneyStep('01', 'Déclarer'),
              _JourneyStep('02', 'Examiner'),
              _JourneyStep('03', 'Exporter'),
            ],
          ),
        ],
      ),
    ),
  );
}

class _JourneyStep extends StatelessWidget {
  const _JourneyStep(this.number, this.label);
  final String number;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      '$number  $label',
      style: const TextStyle(
        fontSize: 13,
        color: SkeletonColors.deep,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({required this.destination});
  final RemboDestination destination;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: SkeletonColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      key: ValueKey('destination-${destination.route}'),
      onTap: () => Navigator.of(context).pushNamed(destination.route),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: SkeletonColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    destination.icon,
                    color: SkeletonColors.primary,
                    size: 24,
                  ),
                ),
                const Spacer(),
                Text(
                  destination.number,
                  style: const TextStyle(
                    color: SkeletonColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              destination.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              destination.description,
              style: const TextStyle(color: SkeletonColors.muted, height: 1.6),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: Text(
                    destination.action,
                    style: const TextStyle(
                      color: SkeletonColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: SkeletonColors.primary,
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
