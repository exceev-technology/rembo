import 'package:flutter/material.dart';

import '../theme/rembo_tokens.dart';
import 'rembo_buttons.dart';

/// Nothing to show yet: icon, explanation and an optional way forward.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  const EmptyState.noExpenses({Key? key, VoidCallback? onAdd})
    : this(
        key: key,
        icon: Icons.receipt_long_outlined,
        title: 'Aucune dépense',
        message: 'Ajoutez votre premier justificatif pour commencer.',
        actionLabel: onAdd == null ? null : 'Ajouter une dépense',
        onAction: onAdd,
      );

  const EmptyState.noNotifications({Key? key})
    : this(
        key: key,
        icon: Icons.notifications_none_rounded,
        title: 'Aucune notification',
        message: 'Vous serez prévenu ici quand une dépense change de statut.',
      );

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => _Centered(
    children: [
      Container(
        padding: const EdgeInsets.all(RemboSpace.xl),
        decoration: const BoxDecoration(
          color: RemboColors.surface,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 40, color: RemboColors.indigo),
      ),
      const SizedBox(height: RemboSpace.lg),
      Text(title, style: RemboText.title, textAlign: TextAlign.center),
      const SizedBox(height: RemboSpace.sm),
      Text(message, style: RemboText.caption, textAlign: TextAlign.center),
      if (actionLabel != null && onAction != null) ...[
        const SizedBox(height: RemboSpace.xl),
        RemboPrimaryButton(
          label: actionLabel!,
          expand: false,
          onPressed: onAction,
        ),
      ],
    ],
  );
}

class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.message = 'Chargement…'});
  final String message;

  @override
  Widget build(BuildContext context) => _Centered(
    children: [
      const CircularProgressIndicator(),
      const SizedBox(height: RemboSpace.lg),
      Text(message, style: RemboText.caption, textAlign: TextAlign.center),
    ],
  );
}

class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    this.title = 'Une erreur est survenue',
    this.message = 'Vérifiez votre connexion puis réessayez.',
    this.onRetry,
  });
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => _Centered(
    children: [
      Container(
        padding: const EdgeInsets.all(RemboSpace.xl),
        decoration: const BoxDecoration(
          color: RemboColors.dangerTint,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.cloud_off_rounded,
          size: 40,
          color: RemboColors.danger,
        ),
      ),
      const SizedBox(height: RemboSpace.lg),
      Text(title, style: RemboText.title, textAlign: TextAlign.center),
      const SizedBox(height: RemboSpace.sm),
      Text(message, style: RemboText.caption, textAlign: TextAlign.center),
      if (onRetry != null) ...[
        const SizedBox(height: RemboSpace.xl),
        RemboSecondaryButton(
          key: const ValueKey('retry'),
          label: 'Réessayer',
          icon: Icons.refresh_rounded,
          expand: false,
          onPressed: onRetry,
        ),
      ],
    ],
  );
}

/// Thin banner placed at the top of a screen while the device is offline.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: RemboSpace.lg,
        vertical: RemboSpace.md,
      ),
      color: RemboColors.ink,
      child: const Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
          SizedBox(width: RemboSpace.md),
          Expanded(
            child: Text(
              'Pas de connexion internet. Vos saisies restent sur '
              'le téléphone.',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Centered extends StatelessWidget {
  const _Centered({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(RemboSpace.xl),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    ),
  );
}
