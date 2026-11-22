import 'package:flutter/material.dart';

import '../accountant/accounts_screen.dart';
import '../manager/agent_metrics_screen.dart';
import 'bench_screen.dart';

import '../../app/app_routes.dart';
import '../../core/data/app_state.dart';
import '../../core/data/demo_build.dart';
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
            ? tr('Démonstration : aucun e-mail n’est envoyé.')
            : tr('Un lien de réinitialisation a été envoyé à {email}.', {
                'email': state.user!.email,
              }),
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
        RemboHero(title: tr('Mon profil')),
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: RemboColors.indigo,
              child: Text(
                user.initial,
                style: RemboText.title.copyWith(color: Colors.white),
              ),
            ),
            const SizedBox(width: RemboSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // A Wrap: with large text the role goes under the name.
                  Wrap(
                    spacing: RemboSpace.sm,
                    runSpacing: RemboSpace.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        user.fullName,
                        key: const ValueKey('profile-name'),
                        style: RemboText.subtitle.copyWith(fontSize: 17),
                      ),
                      RemboBadge(
                        key: const ValueKey('profile-role'),
                        label: user.role.label,
                        tone: BadgeTone.info,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    style: RemboText.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: RemboSpace.xl),
        RemboCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              if (manager) ...[
                _Entry(
                  key: const ValueKey('profile-team'),
                  Icons.groups_outlined,
                  tr('Équipe'),
                  value: user.companyName,
                  onTap: () => Navigator.of(context).pushNamed(AppRoutes.team),
                ),
                _Entry(
                  key: const ValueKey('profile-rules'),
                  Icons.checklist_rounded,
                  tr('Règles de remboursement'),
                  onTap: () => Navigator.of(context).pushNamed(AppRoutes.rules),
                ),
              ],
              if (manager || state.role == UserRole.accountant)
                _Entry(
                  key: const ValueKey('profile-accounts'),
                  Icons.account_balance_outlined,
                  tr('Comptes comptables'),
                  onTap: () => AccountsScreen.open(context),
                ),
              if (manager)
                _Entry(
                  key: const ValueKey('profile-metrics'),
                  Icons.insights_outlined,
                  tr('Mesures des agents'),
                  onTap: () => AgentMetricsScreen.open(context),
                ),
              if (whatsAppOffered(state.isDemo))
                _Entry(
                  key: const ValueKey('profile-whatsapp'),
                  Icons.chat_outlined,
                  'WhatsApp',
                  value: user.whatsappPhone == null
                      ? tr('Non relié')
                      : ltr(user.whatsappPhone!),
                  onTap: () => showWhatsAppSheet(context),
                ),
              if (teamTools)
                _Entry(
                  key: const ValueKey('profile-bench'),
                  Icons.document_scanner_outlined,
                  tr('Banc d’essai OCR'),
                  onTap: () => BenchScreen.open(context),
                ),
              _Entry(
                key: const ValueKey('profile-language'),
                Icons.language_rounded,
                tr('Langue'),
                value: currentLanguageName,
                onTap: () => showLanguageSheet(context),
              ),
              _Entry(
                key: const ValueKey('profile-password'),
                Icons.lock_outline_rounded,
                tr('Mot de passe'),
                last: true,
                onTap: () => _resetPassword(context, state),
              ),
            ],
          ),
        ),
        const SizedBox(height: RemboSpace.md),
        Center(
          child: TextButton.icon(
            key: const ValueKey('profile-signout'),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: Text(tr('Se déconnecter')),
            style: TextButton.styleFrom(foregroundColor: RemboColors.danger),
            onPressed: () => _signOut(context, state),
          ),
        ),
        if (state.isDemo || state.isLocal)
          Text(
            state.isDemo
                ? tr('Démonstration : rien n’est enregistré.')
                : tr('Données enregistrées sur ce téléphone uniquement.'),
            style: RemboText.caption,
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry(
    this.icon,
    this.label, {
    super.key,
    this.value,
    this.onTap,
    this.last = false,
  });
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;

  /// The last row of the group has no line under it.
  final bool last;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: RemboSpace.lg),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: RemboColors.border)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: RemboColors.night),
          const SizedBox(width: RemboSpace.md),
          Expanded(child: Text(label, style: RemboText.body)),
          if (value != null && value!.isNotEmpty)
            Flexible(
              child: Text(
                value!,
                style: RemboText.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(width: RemboSpace.xs),
          const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: RemboColors.muted,
          ),
        ],
      ),
    ),
  );
}
