import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../core/data/app_state.dart';
import '../../core/widgets/rembo_widgets.dart';
import '../whatsapp/whatsapp.dart';

/// « Mon profil » : identity, role-specific settings and sign-out.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key, this.embedded = true});
  final bool embedded;

  Future<void> _resetPassword(BuildContext context, AppState state) async {
    try {
      await state.backend.sendPasswordReset(state.user!.email);
      if (!context.mounted) return;
      showRemboSnackBar(
        context,
        state.isDemo
            ? 'Démonstration : aucun e-mail n’est envoyé.'
            : 'Un lien de réinitialisation a été envoyé à '
                  '${state.user!.email}.',
        tone: state.isDemo ? MessageTone.info : MessageTone.success,
      );
    } on RemboException catch (e) {
      if (context.mounted) {
        showRemboSnackBar(context, e.message, tone: MessageTone.error);
      }
    }
  }

  Future<void> _signOut(BuildContext context, AppState state) async {
    final navigator = Navigator.of(context);
    await state.signOut();
    navigator.pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final user = state.user;
    if (user == null) return const SizedBox.shrink();
    final manager = state.role == UserRole.manager;
    return RemboPage(
      embedded: embedded,
      showBack: embedded ? false : null,
      children: [
        const RemboHero(title: 'Mon\nprofil'),
        RemboCard(
          color: RemboColors.surface,
          borderColor: Colors.transparent,
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: RemboColors.indigo,
                  borderRadius: BorderRadius.circular(RemboRadius.md),
                ),
                child: Text(
                  user.initial,
                  style: RemboText.display.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(width: RemboSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      key: const ValueKey('profile-name'),
                      style: RemboText.title,
                    ),
                    Text(
                      user.role.label,
                      key: const ValueKey('profile-role'),
                      style: RemboText.body.copyWith(color: RemboColors.muted),
                    ),
                    Text(
                      user.companyName,
                      style: RemboText.body.copyWith(color: RemboColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: RemboSpace.lg),
        _Entry(Icons.mail_outline_rounded, 'Adresse e-mail', value: user.email),
        if (manager) ...[
          _Entry(
            key: const ValueKey('profile-team'),
            Icons.groups_outlined,
            'Équipe',
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.team),
          ),
          _Entry(
            key: const ValueKey('profile-rules'),
            Icons.checklist_rounded,
            'Règles de remboursement',
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.rules),
          ),
        ],
        _Entry(
          key: const ValueKey('profile-whatsapp'),
          Icons.chat_outlined,
          'WhatsApp',
          value: user.whatsappPhone ?? 'Non relié',
          onTap: () => showWhatsAppSheet(context),
        ),
        _Entry(
          key: const ValueKey('profile-password'),
          Icons.lock_outline_rounded,
          'Changer de mot de passe',
          onTap: () => _resetPassword(context, state),
        ),
        const _Entry(Icons.language_rounded, 'Langue', value: 'Français'),
        const SizedBox(height: RemboSpace.lg),
        RemboSecondaryButton(
          key: const ValueKey('profile-signout'),
          label: 'Se déconnecter',
          icon: Icons.logout_rounded,
          onPressed: () => _signOut(context, state),
        ),
        const SizedBox(height: RemboSpace.md),
        Text(
          state.isDemo
              ? 'Mode démonstration : aucune donnée n’est enregistrée.'
              : state.isLocal
              ? 'Vos données sont enregistrées sur ce téléphone uniquement. '
                    'Désinstaller l’application les efface.'
              : 'Votre rôle est géré par un responsable de votre entreprise.',
          style: RemboText.caption,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry(this.icon, this.label, {super.key, this.value, this.onTap});
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: RemboSpace.sm),
    child: RemboCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: RemboSpace.lg,
        vertical: RemboSpace.md,
      ),
      child: Row(
        children: [
          Icon(icon, color: RemboColors.night),
          const SizedBox(width: RemboSpace.md),
          Expanded(
            child: Text(
              label,
              style: RemboText.subtitle.copyWith(fontSize: 16),
            ),
          ),
          if (value != null)
            Flexible(
              child: Text(
                value!,
                style: RemboText.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (onTap != null)
            const Icon(Icons.chevron_right_rounded, color: RemboColors.night),
        ],
      ),
    ),
  );
}
