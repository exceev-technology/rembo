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
      UserRole.manager => tr('responsables'),
      UserRole.accountant => tr('comptables'),
      UserRole.employee => tr('collaborateurs'),
    };
    return RemboPage(
      bottom: RemboPrimaryButton(
        key: const ValueKey('back-to-my-space'),
        label: tr('Retour à mon espace'),
        onPressed: () =>
            Navigator.of(context)
                .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false),
      ),
      children: [
        RemboMoment(
          title: tr('Accès réservé'),
          message: tr('Cet espace est réservé aux {who}.', {'who': who}),
          illustration: RemboArt.key,
        ),
        Center(
          child: RemboBadge(
            label: tr('Votre rôle : {label}', {'label': role.label}),
            tone: BadgeTone.info,
            icon: Icons.group_outlined,
          ),
        ),
        const SizedBox(height: RemboSpace.lg),
        Text(
          tr(
            'Pour obtenir cet accès, contactez un responsable de votre '
            'entreprise.',
          ),
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
      label: tr('Retour à mon espace'),
      onPressed: () =>
          Navigator.of(context)
              .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false),
    ),
    children: [
      RemboMoment(
        title: tr('Page introuvable'),
        message: tr('Cet écran n’existe pas ou a été déplacé.'),
        illustration: RemboArt.search,
      ),
    ],
  );
}
