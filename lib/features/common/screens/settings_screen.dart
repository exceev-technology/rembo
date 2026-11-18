import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../core/widgets/rembo_widgets.dart';
import '../demo_session.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _push = true;
  bool _weeklyReminder = false;

  void _open(Widget screen) =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => screen));

  void _saved(String what) => showRemboSnackBar(context, '$what enregistré');

  @override
  Widget build(BuildContext context) {
    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(
        RemboSpace.xs,
        RemboSpace.xl,
        RemboSpace.xs,
        RemboSpace.sm,
      ),
      child: Text(
        title.toUpperCase(),
        style: RemboText.label.copyWith(color: RemboColors.muted),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: SafeArea(
        child: Column(
          children: [
            ValueListenableBuilder(
              valueListenable: demoOffline,
              builder: (_, offline, _) =>
                  offline ? const OfflineBanner() : const SizedBox.shrink(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(RemboSpace.xl),
                children: [
                  const Text(
                    'Paramètres',
                    key: ValueKey('destination-title'),
                    style: RemboText.display,
                  ),
                  section('Compte'),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          key: const ValueKey('open-profile'),
                          leading: const CircleAvatar(
                            backgroundColor: RemboColors.indigo,
                            child: Text(
                              DemoProfile.initials,
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          title: const Text(DemoProfile.name),
                          subtitle: const Text(DemoProfile.email),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _open(const ProfileScreen()),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          key: const ValueKey('open-notifications'),
                          leading: const Icon(Icons.notifications_outlined),
                          title: const Text('Notifications'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _open(const NotificationsScreen()),
                        ),
                      ],
                    ),
                  ),
                  section('Préférences'),
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          key: const ValueKey('pref-push'),
                          title: const Text('Notifications push'),
                          subtitle: const Text('Changement de statut'),
                          value: _push,
                          onChanged: (v) {
                            setState(() => _push = v);
                            _saved('Choix');
                          },
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          key: const ValueKey('pref-reminder'),
                          title: const Text('Rappel hebdomadaire'),
                          subtitle: const Text(
                            'Justificatifs non déclarés, chaque vendredi',
                          ),
                          value: _weeklyReminder,
                          onChanged: (v) {
                            setState(() => _weeklyReminder = v);
                            _saved('Choix');
                          },
                        ),
                        const Divider(height: 1),
                        const ListTile(
                          title: Text('Langue'),
                          trailing: Text('Français'),
                        ),
                        const Divider(height: 1),
                        const ListTile(
                          title: Text('Devise'),
                          trailing: Text('MAD'),
                        ),
                      ],
                    ),
                  ),
                  section('Démonstration'),
                  Card(
                    child: ValueListenableBuilder(
                      valueListenable: demoOffline,
                      builder: (_, offline, _) => SwitchListTile(
                        key: const ValueKey('demo-offline'),
                        title: const Text('Simuler une absence de connexion'),
                        value: offline,
                        onChanged: (v) => demoOffline.value = v,
                      ),
                    ),
                  ),
                  section('Confidentialité'),
                  const RemboMessage(
                    tone: MessageTone.info,
                    title: 'Loi 09-08',
                    message:
                        'Vos données personnelles sont traitées par votre '
                        'employeur pour la gestion des notes de frais.',
                  ),
                  const SizedBox(height: RemboSpace.xl),
                  RemboSecondaryButton(
                    key: const ValueKey('logout'),
                    label: 'Se déconnecter',
                    icon: Icons.logout_rounded,
                    onPressed: () {
                      demoOffline.value = false;
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        AppRoutes.login,
                        (r) => r.isFirst,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
