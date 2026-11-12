import 'package:flutter/material.dart';

import '../../../core/widgets/rembo_widgets.dart';
import '../demo_session.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String value) => ListTile(
      title: Text(label, style: RemboText.caption),
      subtitle: Text(value, style: RemboText.body),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(RemboSpace.xl),
          children: [
            const Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: RemboColors.indigo,
                child: Text(
                  DemoProfile.initials,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: RemboSpace.lg),
            const Text(
              DemoProfile.name,
              textAlign: TextAlign.center,
              style: RemboText.title,
            ),
            const SizedBox(height: RemboSpace.xs),
            const Center(
              child: RemboBadge(label: DemoProfile.role, tone: BadgeTone.info),
            ),
            const SizedBox(height: RemboSpace.xl),
            Card(
              child: Column(
                children: [
                  row('E-mail', DemoProfile.email),
                  const Divider(height: 1),
                  row('Équipe', DemoProfile.team),
                  const Divider(height: 1),
                  row('Responsable', DemoProfile.manager),
                  const Divider(height: 1),
                  row('Entreprise', DemoProfile.company),
                ],
              ),
            ),
            const SizedBox(height: RemboSpace.lg),
            const Text(
              'Ces informations sont gérées par votre entreprise. '
              'Contactez votre administrateur pour les modifier.',
              style: RemboText.caption,
            ),
          ],
        ),
      ),
    );
  }
}
