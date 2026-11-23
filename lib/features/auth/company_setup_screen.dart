import 'package:flutter/material.dart';

import '../../core/data/app_state.dart';
import '../../core/widgets/rembo_widgets.dart';

/// First step of an account that belongs to no company yet.
class CompanySetupScreen extends StatefulWidget {
  const CompanySetupScreen({super.key});

  @override
  State<CompanySetupScreen> createState() => _CompanySetupScreenState();
}

class _CompanySetupScreenState extends State<CompanySetupScreen> {
  final _name = TextEditingController();
  final _ice = TextEditingController();
  final _city = TextEditingController();
  String? _nameError;
  String? _iceError;
  String? _failure;
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [_name, _ice, _city]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final ice = _ice.text.trim();
    setState(() {
      _failure = null;
      _nameError = _name.text.trim().length < 2
          ? tr('Saisissez le nom de l’entreprise.')
          : null;
      _iceError = ice.isEmpty || RegExp(r'^\d{15}$').hasMatch(ice)
          ? null
          : tr('L’ICE compte 15 chiffres.');
    });
    if (_nameError != null || _iceError != null) return;
    setState(() => _loading = true);
    try {
      await AppScope.read(context)
          .createCompany(name: _name.text, ice: ice, city: _city.text.trim());
    } on RemboException catch (e) {
      if (mounted) setState(() => _failure = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Joins the company that invited the person, on their answer.
  Future<void> _join() async {
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      await AppScope.read(context).acceptInvitation();
    } on RemboException catch (e) {
      if (mounted) setState(() => _failure = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invitation = AppScope.of(context).invitation;
    return RemboPage(
      showBack: false,
      trailing: TextButton(
        onPressed: () => AppScope.read(context).signOut(),
        child: Text(tr('Se déconnecter')),
      ),
      bottom: RemboPrimaryButton(
        key: const ValueKey('company-submit'),
        label: tr('Créer l’entreprise'),
        loading: _loading,
        onPressed: _submit,
      ),
      children: [
        RemboHero(title: tr('Votre entreprise')),
        if (invitation == null)
          InfoStrip(tr('Aucune invitation : créez votre entreprise.'))
        else ...[
          RemboMessage(
            key: const ValueKey('company-invitation'),
            tone: MessageTone.info,
            title: tr('{company} vous invite', {
              'company': isolate(invitation.companyName),
            }),
            message: tr('Votre rôle : {role}.', {
              'role': tr(invitation.role.label),
            }),
            action: RemboSecondaryButton(
              key: const ValueKey('company-join'),
              label: tr('Rejoindre l’entreprise'),
              onPressed: _loading ? null : _join,
            ),
          ),
          const SizedBox(height: RemboSpace.lg),
          Text(
            tr('Ou créez votre propre entreprise :'),
            style: RemboText.subtitle,
          ),
        ],
        const SizedBox(height: RemboSpace.lg),
        if (_failure != null) ...[
          RemboMessage(tone: MessageTone.error, title: _failure!),
          const SizedBox(height: RemboSpace.lg),
        ],
        RemboTextField(
          fieldKey: const ValueKey('company-name'),
          label: tr('Nom de l’entreprise'),
          hint: 'Atlas Conseil',
          icon: Icons.storefront_outlined,
          controller: _name,
          errorText: _nameError,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: RemboSpace.lg),
        RemboTextField(
          fieldKey: const ValueKey('company-ice'),
          label: tr('ICE (facultatif)'),
          hint: tr('15 chiffres'),
          icon: Icons.description_outlined,
          controller: _ice,
          errorText: _iceError,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: RemboSpace.lg),
        RemboTextField(
          label: tr('Ville'),
          hint: tr('Casablanca'),
          icon: Icons.place_outlined,
          controller: _city,
        ),
      ],
    );
  }
}
