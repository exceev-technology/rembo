import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../core/widgets/rembo_widgets.dart';

/// End of the journey. Back is disabled: the expense is already submitted.
class ConfirmationScreen extends StatelessWidget {
  const ConfirmationScreen({
    super.key,
    required this.supplier,
    required this.amountCentimes,
  });
  final String supplier;
  final int amountCentimes;

  @override
  Widget build(BuildContext context) {
    void goTo(String route) =>
        Navigator.of(context).pushNamedAndRemoveUntil(route, (r) => r.isFirst);
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(automaticallyImplyLeading: false),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(RemboSpace.xl),
            children: [
              const SizedBox(height: RemboSpace.xl),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(RemboSpace.xl),
                  decoration: const BoxDecoration(
                    color: RemboColors.successTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 56,
                    color: RemboColors.successText,
                  ),
                ),
              ),
              const SizedBox(height: RemboSpace.xl),
              const Text(
                'Dépense envoyée',
                key: ValueKey('confirmation-title'),
                textAlign: TextAlign.center,
                style: RemboText.display,
              ),
              const SizedBox(height: RemboSpace.md),
              Text(
                '$supplier · ${formatMad(amountCentimes)}',
                textAlign: TextAlign.center,
                style: RemboText.subtitle,
              ),
              const SizedBox(height: RemboSpace.sm),
              const Text(
                'Votre responsable va la valider. Vous suivrez son statut '
                'depuis « Mes dépenses ».',
                textAlign: TextAlign.center,
                style: RemboText.body,
              ),
              const SizedBox(height: RemboSpace.xxl),
              RemboPrimaryButton(
                key: const ValueKey('confirmation-home'),
                label: 'Retour à mes dépenses',
                onPressed: () => goTo(AppRoutes.collaborator),
              ),
              const SizedBox(height: RemboSpace.md),
              RemboSecondaryButton(
                key: const ValueKey('confirmation-new'),
                label: 'Nouvelle dépense',
                icon: Icons.add_rounded,
                onPressed: () => goTo(AppRoutes.capture),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
