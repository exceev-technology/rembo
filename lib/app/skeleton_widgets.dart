import 'package:flutter/material.dart';

import '../core/theme/skeleton_colors.dart';

class RemboWordmark extends StatelessWidget {
  const RemboWordmark({super.key});
  @override
  Widget build(BuildContext context) => const Text.rich(
    TextSpan(
      children: [
        TextSpan(text: 'rembo'),
        TextSpan(
          text: '.',
          style: TextStyle(color: SkeletonColors.primary),
        ),
      ],
    ),
    semanticsLabel: 'Rembo',
    style: TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.5,
    ),
  );
}

class PreviewLabel extends StatelessWidget {
  const PreviewLabel({super.key, this.label = 'Première ébauche'});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: SkeletonColors.surface,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        color: SkeletonColors.deep,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
