import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../core/data/app_state.dart';
import '../../core/widgets/rembo_widgets.dart';

/// Shown when a route is reserved to another role.
class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({super.key, required this.reservedTo});
  final UserRole reservedTo;

  @override
  Widget build(BuildContext context) {
    final role = AppScope.of(context).role;
    final who = switch (reservedTo) {
      UserRole.manager => 'responsables',
      UserRole.accountant => 'comptables',
      UserRole.employee => 'collaborateurs',
    };
    return RemboPage(
      bottom: RemboPrimaryButton(
        key: const ValueKey('back-to-my-space'),
        label: 'Retour à mon espace',
        onPressed: () =>
            Navigator.of(context)
                .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false),
      ),
      children: [
        RemboMoment(
          title: 'Accès réservé',
          message: 'Cet espace est réservé aux $who.',
          illustration: RemboArt.key,
        ),
        Center(
          child: RemboBadge(
            label: 'Votre rôle : ${role.label}',
            tone: BadgeTone.info,
            icon: Icons.group_outlined,
          ),
        ),
        const SizedBox(height: RemboSpace.lg),
        Text(
          'Pour obtenir cet accès, contactez un responsable de votre '
          'entreprise.',
          style: RemboText.caption,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Unknown address: one way back.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) => RemboPage(
    bottom: RemboPrimaryButton(
      label: 'Retour à mon espace',
      onPressed: () =>
          Navigator.of(context)
              .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false),
    ),
    children: const [
      RemboMoment(
        title: 'Page introuvable',
        message: 'Cet écran n’existe pas ou a été déplacé.',
        illustration: RemboArt.search,
      ),
    ],
  );
}
