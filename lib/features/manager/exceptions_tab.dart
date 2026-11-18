import 'package:flutter/material.dart';

import '../../core/data/app_state.dart';
import '../../core/widgets/rembo_widgets.dart';
import 'decision_screen.dart';

/// « À examiner » : only what the automatic control could not settle.
class ExceptionsTab extends StatelessWidget {
  const ExceptionsTab({super.key});

  static (IconData, BadgeTone) _look(FlagKind kind) => switch (kind) {
    FlagKind.policy => (Icons.warning_amber_rounded, BadgeTone.warning),
    FlagKind.ambiguity => (Icons.help_outline_rounded, BadgeTone.info),
    FlagKind.duplicate => (Icons.content_copy_rounded, BadgeTone.info),
  };

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final pending = state.toReview;
    int count(bool Function(FlagKind) test) =>
        pending.where((e) => e.flags.any((f) => test(f.kind))).length;
    final policy = count((k) => k == FlagKind.policy);
    final ambiguous = count((k) => k != FlagKind.policy);

    return RemboPage(
      embedded: true,
      showBack: false,
      onRefresh: state.refresh,
      children: [
        RemboHero(
          overline: formatWeekday(DateTime.now()),
          title: 'À examiner',
          illustration: RemboArt.search,
        ),
        Row(
          children: [
            Expanded(
              child: _Count(
                Icons.warning_amber_rounded,
                'Écarts aux règles · $policy',
                RemboColors.warningText,
                RemboColors.warningTint,
              ),
            ),
            const SizedBox(width: RemboSpace.sm),
            Expanded(
              child: _Count(
                Icons.help_outline_rounded,
                'Ambiguïtés · $ambiguous',
                RemboColors.infoText,
                RemboColors.surface,
              ),
            ),
          ],
        ),
        const SizedBox(height: RemboSpace.lg),
        if (state.loadError != null)
          RemboMessage(
            tone: MessageTone.error,
            title: 'Chargement impossible',
            message: state.loadError!.message,
            action: TextButton(
              onPressed: state.refresh,
              child: const Text('Réessayer'),
            ),
          )
        else if (pending.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: RemboSpace.xl),
            child: Column(
              key: const ValueKey('exceptions-empty'),
              children: [
                const HeroArt(height: 120, art: RemboArt.approved),
                const SizedBox(height: RemboSpace.lg),
                Text('Rien à examiner', style: RemboText.subtitle),
                Text(
                  'Aucune dépense n’attend votre décision.',
                  style: RemboText.caption,
                ),
              ],
            ),
          ),
        for (final e in pending)
          ExpenseTile(
            e,
            key: ValueKey('exception-${e.id}'),
            title: e.employeeName,
            subtitle: e.reason,
            badge: e.flags.isEmpty
                ? null
                : RemboBadge(
                    label: e.flags.first.message,
                    tone: _look(e.flags.first.kind).$2,
                    icon: _look(e.flags.first.kind).$1,
                  ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DecisionScreen(expenseId: e.id),
              ),
            ),
          ),
        const SizedBox(height: RemboSpace.sm),
        const InfoStrip('Le reste est validé automatiquement.'),
      ],
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.icon, this.text, this.color, this.background);
  final IconData icon;
  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(RemboSpace.md),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(RemboRadius.md),
    ),
    child: Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: RemboSpace.sm),
        Expanded(
          child: Text(
            text,
            style: RemboText.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}
