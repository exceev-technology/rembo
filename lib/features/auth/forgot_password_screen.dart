import 'package:flutter/material.dart';

import '../../core/data/app_state.dart';
import '../../core/widgets/rembo_widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  String? _error;
  String? _failure;
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _failure = null;
      _error = isValidEmail(_email.text)
          ? null
          : tr('Adresse e-mail invalide.');
    });
    if (_error != null) return;
    setState(() => _loading = true);
    try {
      await AppScope.read(context).backend
          .sendPasswordReset(_email.text.trim());
      if (mounted) setState(() => _sent = true);
    } on RemboException catch (e) {
      if (mounted) setState(() => _failure = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final demo = AppScope.of(context).isDemo;
    return RemboPage(
      children: [
        const SizedBox(height: RemboSpace.sm),
        const Center(child: HeroArt(height: 190, art: RemboArt.envelope)),
        const SizedBox(height: RemboSpace.xl),
        Semantics(
          header: true,
          child: Text(tr('Mot de passe\noublié ?'), style: RemboText.display),
        ),
        const SizedBox(height: RemboSpace.sm),
        Text(
          tr('Recevez un lien de réinitialisation par e-mail.'),
          style: RemboText.note.copyWith(fontSize: 14),
        ),
        const SizedBox(height: RemboSpace.xl),
        if (_sent)
          RemboMessage(
            key: const ValueKey('reset-sent'),
            tone: demo ? MessageTone.info : MessageTone.success,
            title: demo
                ? tr('Démonstration : aucun e-mail envoyé')
                : tr('Demande envoyée'),
            message: demo
                ? tr(
                    'Avec un serveur configuré, un lien serait envoyé à {trim}.',
                    {'trim': _email.text.trim()},
                  )
                : tr(
                    'Si un compte existe pour {trim}, vous recevrez un lien dans '
                    'quelques minutes.',
                    {'trim': _email.text.trim()},
                  ),
          )
        else ...[
          if (_failure != null) ...[
            RemboMessage(tone: MessageTone.error, title: _failure!),
            const SizedBox(height: RemboSpace.lg),
          ],
          RemboTextField(
            fieldKey: const ValueKey('reset-email'),
            label: tr('Adresse e-mail'),
            hint: 'votre@email.com',
            icon: Icons.mail_outline_rounded,
            controller: _email,
            errorText: _error,
            keyboardType: TextInputType.emailAddress,
            onSubmitted: (_) => _send(),
          ),
          const SizedBox(height: RemboSpace.xl),
          RemboPrimaryButton(
            key: const ValueKey('reset-submit'),
            label: tr('Envoyer le lien'),
            loading: _loading,
            onPressed: _send,
          ),
        ],
        const SizedBox(height: RemboSpace.sm),
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(tr('Retour à la connexion')),
          ),
        ),
      ],
    );
  }
}
