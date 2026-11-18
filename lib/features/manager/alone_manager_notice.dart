import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../core/data/app_state.dart';
import '../../core/widgets/rembo_widgets.dart';

/// A manager never decides on their own expense. When nobody else in the
/// company is a manager, that expense would wait for ever: this tells them
/// and opens the team page to invite one.
class AloneManagerNotice extends StatelessWidget {
  const AloneManagerNotice({super.key, required this.expense});
  final Expense expense;

  /// True when [expense] is the signed-in manager's own expense, waiting for
  /// a decision, and no other active manager can take it.
  static bool appliesTo(AppState state, Expense expense) {
    final me = state.user;
    if (me == null || state.role != UserRole.manager) return false;
    if (expense.employeeId != me.id) return false;
    if (expense.status != ExpenseStatus.needsReview) return false;
    final myEmail = me.email.toLowerCase();
    return !state.members.any(
      (m) =>
          m.role == UserRole.manager &&
          !m.pending &&
          m.email.toLowerCase() != myEmail,
    );
  }

  @override
  Widget build(BuildContext context) => RemboMessage(
    key: const ValueKey('detail-alone-manager'),
    tone: MessageTone.info,
    title: 'Vous êtes le seul responsable',
    message:
        'Personne ne décide de sa propre dépense. Invitez un autre '
        'responsable : il pourra approuver ou rejeter celle-ci.',
    action: TextButton.icon(
      key: const ValueKey('detail-invite-manager'),
      icon: const Icon(Icons.person_add_alt_1_outlined),
      label: const Text('Inviter un responsable'),
      onPressed: () => Navigator.of(context).pushNamed(AppRoutes.team),
    ),
  );
}
