import 'package:flutter/material.dart';

import '../../core/data/app_state.dart';
import '../../core/widgets/rembo_widgets.dart';
import '../collaborator/expense_detail_screen.dart';
import '../manager/decision_screen.dart';

/// « Activité » : status changes that concern the signed-in person.
class ActivityTab extends StatelessWidget {
  const ActivityTab({super.key});

  static (String, String, IconData, BadgeTone) _look(
    ActivityItem item,
    bool own,
  ) {
    final e = item.expense;
    final ev = item.event;
    return switch (ev.status) {
      ExpenseStatus.needsReview =>
        own
            ? (
                'Transmise au responsable',
                'Un point est à examiner sur « ${e.title} ».',
                Icons.visibility_outlined,
                BadgeTone.warning,
              )
            : (
                'Décision demandée',
                '${e.employeeName} · ${e.title}',
                Icons.warning_amber_rounded,
                BadgeTone.warning,
              ),
      ExpenseStatus.approved => (
        'Dépense validée',
        ev.byAgent
            ? '« ${e.title} » est conforme aux règles.'
            : '« ${e.title} » validée par ${ev.actorName}.',
        Icons.check_rounded,
        BadgeTone.success,
      ),
      ExpenseStatus.rejected => (
        'Correction demandée',
        ev.reason ?? 'Des informations sont à ajuster.',
        Icons.edit_note_rounded,
        BadgeTone.danger,
      ),
      ExpenseStatus.exported => (
        'Dépense exportée',
        '« ${e.title} » est partie en comptabilité.',
        Icons.cloud_done_outlined,
        BadgeTone.info,
      ),
      _ => (
        ev.status.label,
        e.title,
        Icons.receipt_long_outlined,
        BadgeTone.neutral,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final items = state.activity;
    final now = DateTime.now();
    String group(DateTime at) {
      final days = DateTime(
        now.year,
        now.month,
        now.day,
      ).difference(DateTime(at.year, at.month, at.day)).inDays;
      return days <= 0 ? 'Aujourd’hui' : (days == 1 ? 'Hier' : 'Plus tôt');
    }

    final children = <Widget>[];
    String? current;
    for (final item in items.take(40)) {
      final g = group(item.event.at);
      if (g != current) {
        current = g;
        children.add(SectionTitle(g));
      }
      final own = item.expense.employeeId == state.user?.id;
      final (title, message, icon, tone) = _look(item, own);
      final (fg, bg) = RemboBadge.colors(tone);
      final unread = state.isUnread(item);
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: RemboSpace.sm),
          child: RemboCard(
            key: ValueKey('activity-${item.key}'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    !own &&
                        item.expense.status == ExpenseStatus.needsReview &&
                        state.role == UserRole.manager
                    ? DecisionScreen(expenseId: item.expense.id)
                    : ExpenseDetailScreen(expenseId: item.expense.id),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconTile(icon, color: fg, background: bg),
                const SizedBox(width: RemboSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: RemboText.subtitle.copyWith(fontSize: 16),
                      ),
                      Text(message, style: RemboText.caption),
                      const SizedBox(height: RemboSpace.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: RemboSpace.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: RemboColors.surface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          formatMad(item.expense.amountCents),
                          style: RemboText.amount.copyWith(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: RemboSpace.sm),
                Text(formatTime(item.event.at), style: RemboText.caption),
                if (unread)
                  const Padding(
                    padding: EdgeInsets.only(left: 6, top: 5),
                    child: CircleAvatar(
                      radius: 4,
                      backgroundColor: RemboColors.indigo,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return RemboPage(
      embedded: true,
      showBack: false,
      onRefresh: state.refresh,
      children: [
        const RemboHero(
          title: 'Activité',
          subtitle: 'Suivez l’avancement de vos dépenses.',
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: RemboSpace.xl),
            child: Column(
              key: const ValueKey('activity-empty'),
              children: [
                Text('Aucune activité', style: RemboText.subtitle),
                Text(
                  'Vous serez prévenu ici quand une dépense change de statut.',
                  style: RemboText.caption,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey('activity-read-all'),
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Tout marquer comme lues'),
              onPressed: state.unreadCount == 0 ? null : state.markAllRead,
            ),
          ),
        ...children,
      ],
    );
  }
}
