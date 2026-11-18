import 'package:flutter/material.dart';

import '../../core/data/app_state.dart';
import '../../core/widgets/rembo_widgets.dart';

/// « Équipe » : members, their role, and invitations.
class TeamScreen extends StatelessWidget {
  const TeamScreen({super.key});

  static BadgeTone _tone(UserRole role) => switch (role) {
    UserRole.employee => BadgeTone.info,
    UserRole.manager => BadgeTone.success,
    UserRole.accountant => BadgeTone.neutral,
  };

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return RemboPage(
      onRefresh: state.refresh,
      bottom: RemboPrimaryButton(
        key: const ValueKey('team-invite'),
        label: 'Inviter un membre',
        icon: Icons.person_add_alt_1_outlined,
        onPressed: () => showRemboSheet<void>(
          context,
          title: 'Inviter un membre',
          subtitle: 'Ajoutez un collaborateur à votre équipe.',
          builder: (_) => const _InviteForm(),
        ),
      ),
      children: [
        const RemboHero(title: 'Équipe', illustration: RemboArt.team),
        for (final m in state.members)
          Padding(
            padding: const EdgeInsets.only(bottom: RemboSpace.sm),
            child: RemboCard(
              key: ValueKey('member-${m.email}'),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: RemboColors.surface,
                    child: Text(
                      m.name.isEmpty ? '?' : m.name[0].toUpperCase(),
                      style: RemboText.subtitle.copyWith(
                        color: RemboColors.night,
                      ),
                    ),
                  ),
                  const SizedBox(width: RemboSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.name,
                          style: RemboText.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: RemboSpace.xs),
                        Wrap(
                          spacing: RemboSpace.sm,
                          runSpacing: RemboSpace.xs,
                          children: [
                            RemboBadge(
                              label: m.role.label,
                              tone: _tone(m.role),
                            ),
                            if (m.pending)
                              const RemboBadge(
                                label: 'Invitation en attente',
                                tone: BadgeTone.warning,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _InviteForm extends StatefulWidget {
  const _InviteForm();

  @override
  State<_InviteForm> createState() => _InviteFormState();
}

class _InviteFormState extends State<_InviteForm> {
  final _email = TextEditingController();
  UserRole _role = UserRole.employee;
  String? _error;
  bool _loading = false;
  bool _done = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!isValidEmail(_email.text)) {
      setState(() => _error = 'Adresse e-mail invalide.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AppScope.read(context).invite(_email.text.trim(), _role);
      if (mounted) setState(() => _done = true);
    } on RemboException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return Column(
        children: [
          RemboMessage(
            key: const ValueKey('invite-done'),
            tone: MessageTone.success,
            title: 'Invitation enregistrée',
            message: AppScope.read(context).isLocal
                ? '${_email.text.trim()} peut maintenant créer son compte '
                      'sur ce téléphone avec cette adresse. Son rôle sera '
                      'attribué automatiquement.'
                : 'REMBO n’envoie pas encore d’e-mail : demandez à '
                      '${_email.text.trim()} de créer son compte avec cette '
                      'adresse. Son rôle sera attribué automatiquement.',
          ),
          const SizedBox(height: RemboSpace.lg),
          RemboPrimaryButton(
            label: 'Terminer',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RemboTextField(
          fieldKey: const ValueKey('invite-email'),
          label: 'Adresse e-mail',
          hint: 'personne@exemple.ma',
          icon: Icons.mail_outline_rounded,
          controller: _email,
          errorText: _error,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: RemboSpace.lg),
        Text('Rôle', style: RemboText.subtitle),
        const SizedBox(height: RemboSpace.sm),
        DropdownButtonFormField<UserRole>(
          key: const ValueKey('invite-role'),
          initialValue: _role,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.group_outlined, color: RemboColors.night),
          ),
          items: [
            for (final r in UserRole.values)
              DropdownMenuItem(value: r, child: Text(r.label)),
          ],
          onChanged: (r) => setState(() => _role = r ?? _role),
        ),
        const SizedBox(height: RemboSpace.xl),
        RemboPrimaryButton(
          key: const ValueKey('invite-submit'),
          label: 'Enregistrer l’invitation',
          loading: _loading,
          onPressed: _send,
        ),
      ],
    );
  }
}
