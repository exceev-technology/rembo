import 'package:flutter/material.dart';

import '../accountant/accounts_screen.dart';
import '../manager/agent_metrics_screen.dart';
import 'bench_screen.dart';

import '../../app/app_routes.dart';
import '../../core/data/app_state.dart';
import '../auth/forgot_password_screen.dart';
import '../../core/data/demo_build.dart';
import '../../core/widgets/rembo_widgets.dart';
import '../whatsapp/whatsapp.dart';

/// « Mon profil » : a member card with three figures of the person's role,
/// then their settings in short groups, and sign-out.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key, this.embedded = true});
  final bool embedded;

  /// A code is e-mailed, then typed with the new password.
  void _resetPassword(BuildContext context, AppState state) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ForgotPasswordScreen(email: state.user!.email),
        ),
      );

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
    final accountant = state.role == UserRole.accountant;
    final whatsApp = whatsAppOffered(state.isDemo) && state.canDeclare;
    return RemboPage(
      embedded: embedded,
      showBack: embedded ? false : null,
      children: [
        const SizedBox(height: RemboSpace.sm),
        Semantics(
          header: true,
          child: Text(tr('Mon profil'), style: RemboText.title),
        ),
        const SizedBox(height: RemboSpace.md),
        _MemberCard(state: state, user: user),
        const SizedBox(height: RemboSpace.xl),
        if (manager || accountant)
          _Group(
            title: user.companyName.isEmpty
                ? tr('Entreprise')
                : user.companyName,
            entries: [
              if (manager) ...[
                _Entry(
                  key: const ValueKey('profile-team'),
                  Icons.groups_outlined,
                  tr('Équipe'),
                  value: state.membersLoaded
                      ? tr('{n} membres', {'n': state.members.length})
                      : null,
                  onTap: () => Navigator.of(context).pushNamed(AppRoutes.team),
                ),
                _Entry(
                  key: const ValueKey('profile-rules'),
                  Icons.checklist_rounded,
                  tr('Règles de remboursement'),
                  onTap: () => Navigator.of(context).pushNamed(AppRoutes.rules),
                ),
              ],
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
            ],
          ),
        _Group(
          title: tr('Mon compte'),
          entries: [
            if (whatsApp)
              _Entry(
                key: const ValueKey('profile-whatsapp'),
                Icons.chat_outlined,
                'WhatsApp',
                value: user.whatsappPhone == null
                    ? tr('Non relié')
                    : ltr(user.whatsappPhone!),
                onTap: () => showWhatsAppSheet(context),
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
              onTap: () => _resetPassword(context, state),
            ),
          ],
        ),
        if (teamTools)
          _Group(
            title: tr('Outils de l’équipe REMBO'),
            entries: [
              _Entry(
                key: const ValueKey('profile-bench'),
                Icons.document_scanner_outlined,
                tr('Banc d’essai OCR'),
                onTap: () => BenchScreen.open(context),
              ),
            ],
          ),
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

/// Three figures that matter to this role, as on the stub of a receipt.
List<(String, String)> _figures(AppState state) {
  int sum(Iterable<Expense> list) =>
      list.fold(0, (total, e) => total + e.amountCents);
  switch (state.role) {
    case UserRole.manager:
      return [
        (tr('À décider'), '${state.toReview.length}'),
        (tr('Exceptions'), '${state.exceptions.length}'),
        (tr('Membres'), state.membersLoaded ? '${state.members.length}' : '–'),
      ];
    case UserRole.accountant:
      return [
        (tr('À exporter'), '${state.toExport.length}'),
        (tr('Montant'), formatMad(sum(state.toExport))),
        (tr('Exports'), '${state.exports.length}'),
      ];
    case UserRole.employee:
      final now = DateTime.now();
      final sent = state.mine
          .where((e) => e.status != ExpenseStatus.draft)
          .toList();
      final thisMonth = sent.where(
        (e) => e.createdAt.year == now.year && e.createdAt.month == now.month,
      );
      final waiting = sent.where(
        (e) =>
            e.status == ExpenseStatus.submitted ||
            e.status == ExpenseStatus.needsReview,
      );
      final approved = sent.where(
        (e) =>
            e.status == ExpenseStatus.approved ||
            e.status == ExpenseStatus.exported,
      );
      return [
        (tr('Ce mois'), formatMad(sum(thisMonth))),
        (tr('En attente'), '${waiting.length}'),
        (tr('Validées'), '${approved.length}'),
      ];
  }
}

/// The member card: who I am, where, and my figures under a torn edge.
/// A tap opens the profile in detail.
class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.state, required this.user});
  final AppState state;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    const onNight = Colors.white;
    final soft = Colors.white.withValues(alpha: 0.75);
    // With large text or a narrow screen, everything takes the full width.
    final media = MediaQuery.of(context);
    final roomy = media.size.width >= 340 && media.textScaler.scale(10) <= 13;
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          user.fullName,
          key: const ValueKey('profile-name'),
          style: RemboText.display.copyWith(fontSize: 21, color: onNight),
        ),
        const SizedBox(height: 2),
        Text(
          user.companyName.isEmpty
              ? user.role.label
              : tr('{role} chez {company}', {
                  'role': user.role.label,
                  'company': user.companyName,
                }),
          key: const ValueKey('profile-role'),
          style: RemboText.body.copyWith(color: soft),
        ),
      ],
    );
    final figures = _figures(state);
    return Semantics(
      button: true,
      label: tr('Voir le détail de mon profil'),
      child: ClipPath(
        clipper: const _TornEdge(),
        child: Material(
          color: RemboColors.night,
          child: InkWell(
            key: const ValueKey('profile-card'),
            onTap: () => showProfileSheet(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                RemboSpace.lg,
                RemboSpace.lg,
                RemboSpace.lg,
                RemboSpace.lg + _TornEdge.depth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (roomy)
                    Row(
                      children: [
                        _Initial(user: user, radius: 26),
                        const SizedBox(width: RemboSpace.md),
                        Expanded(child: identity),
                        Icon(Icons.chevron_right_rounded, color: soft),
                      ],
                    )
                  else ...[
                    _Initial(user: user, radius: 22),
                    const SizedBox(height: RemboSpace.sm),
                    identity,
                  ],
                  const SizedBox(height: RemboSpace.lg),
                  CustomPaint(
                    size: const Size(double.infinity, 1),
                    painter: _Perforation(Colors.white.withValues(alpha: 0.35)),
                  ),
                  const SizedBox(height: RemboSpace.md),
                  if (roomy)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final (label, value) in figures)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Text(
                                    value,
                                    style: RemboText.amount.copyWith(
                                      fontSize: 19,
                                      color: onNight,
                                    ),
                                  ),
                                ),
                                Text(
                                  label,
                                  style: RemboText.caption.copyWith(
                                    color: soft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    )
                  else
                    for (final (label, value) in figures)
                      Padding(
                        padding: const EdgeInsets.only(bottom: RemboSpace.xs),
                        child: Wrap(
                          spacing: RemboSpace.sm,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              value,
                              style: RemboText.amount.copyWith(
                                fontSize: 17,
                                color: onNight,
                              ),
                            ),
                            Text(
                              label,
                              style: RemboText.caption.copyWith(color: soft),
                            ),
                          ],
                        ),
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

class _Initial extends StatelessWidget {
  const _Initial({required this.user, required this.radius});
  final AppUser user;
  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: Colors.white,
    child: Text(
      user.initials,
      style: RemboText.display.copyWith(
        fontSize: radius * 0.72,
        color: RemboColors.indigo,
      ),
    ),
  );
}

/// The bottom of the card is torn like a till receipt.
class _TornEdge extends CustomClipper<Path> {
  const _TornEdge();
  static const depth = 6.0;
  static const tooth = 12.0;

  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - depth);
    final teeth = (size.width / tooth).ceil();
    final step = size.width / teeth;
    for (var i = teeth; i > 0; i--) {
      path
        ..lineTo((i - 0.5) * step, size.height)
        ..lineTo((i - 1) * step, size.height - depth);
    }
    return path..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// The dotted line where a receipt is torn off.
class _Perforation extends CustomPainter {
  const _Perforation(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, 0), Offset(x + 3, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_Perforation old) => old.color != color;
}

/// What this role does in REMBO, in plain words.
String _roleDescription(AppState state) => switch (state.role) {
  UserRole.employee => tr(
    'Vous déclarez vos dépenses avec la photo du reçu ou par WhatsApp, puis vous suivez leur remboursement.',
  ),
  UserRole.manager =>
    state.managersDeclare
        ? tr(
            'Vous décidez des dépenses de votre équipe et déclarez aussi les vôtres : un autre responsable les décide.',
          )
        : tr(
            'Vous décidez des dépenses de votre équipe : les conformes se confirment d’un geste, les exceptions attendent votre avis.',
          ),
  UserRole.accountant => tr(
    'Vous préparez les exports comptables des dépenses validées.',
  ),
};

/// The profile in detail, opened from the member card.
Future<void> showProfileSheet(BuildContext context) {
  final state = AppScope.of(context);
  final user = state.user;
  if (user == null) return Future.value();
  return showRemboSheet<void>(
    context,
    title: tr('Mon profil'),
    builder: (sheet) => Column(
      key: const ValueKey('profile-sheet'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: RemboColors.night,
              child: Text(
                user.initials,
                style: RemboText.display.copyWith(
                  fontSize: 22,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: RemboSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    style: RemboText.display.copyWith(fontSize: 21),
                  ),
                  const SizedBox(height: RemboSpace.xs),
                  RemboBadge(label: user.role.label, tone: BadgeTone.info),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: RemboSpace.lg),
        Text(_roleDescription(state), style: RemboText.body),
        const SizedBox(height: RemboSpace.lg),
        RemboCard(
          padding: const EdgeInsets.symmetric(horizontal: RemboSpace.lg),
          child: Column(
            children: [
              _Fact(tr('E-mail'), ltr(user.email)),
              if (user.companyName.isNotEmpty)
                _Fact(tr('Entreprise'), user.companyName),
              if (whatsAppOffered(state.isDemo) && state.canDeclare)
                _Fact(
                  'WhatsApp',
                  user.whatsappPhone == null
                      ? tr('Non relié')
                      : ltr(user.whatsappPhone!),
                ),
              _Fact(tr('Langue'), currentLanguageName),
              _Fact(
                tr('Données'),
                state.isDemo
                    ? tr('Démonstration')
                    : state.isLocal
                    ? tr('Sur ce téléphone')
                    : tr('En ligne, sur le serveur de l’entreprise'),
                last: true,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value, {this.last = false});
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: RemboSpace.md),
    decoration: BoxDecoration(
      border: last
          ? null
          : const Border(bottom: BorderSide(color: RemboColors.border)),
    ),
    // A Wrap: with large text the value goes under its label.
    child: Wrap(
      spacing: RemboSpace.md,
      runSpacing: RemboSpace.xs,
      children: [
        SizedBox(width: 96, child: Text(label, style: RemboText.caption)),
        Text(value, style: RemboText.body),
      ],
    ),
  );
}

/// A short group of settings under its name.
class _Group extends StatelessWidget {
  const _Group({required this.title, required this.entries});
  final String title;
  final List<_Entry> entries;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: RemboSpace.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: RemboSpace.xs,
            bottom: RemboSpace.sm,
          ),
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: RemboText.label.copyWith(color: RemboColors.muted),
            ),
          ),
        ),
        RemboCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < entries.length; i++)
                entries[i].copyWith(last: i == entries.length - 1),
            ],
          ),
        ),
      ],
    ),
  );
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

  _Entry copyWith({required bool last}) =>
      _Entry(icon, label, key: key, value: value, onTap: onTap, last: last);

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
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: RemboColors.surface,
              borderRadius: BorderRadius.circular(RemboRadius.sm),
            ),
            child: Icon(icon, size: 18, color: RemboColors.night),
          ),
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
