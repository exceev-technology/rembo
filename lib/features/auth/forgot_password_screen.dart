import 'package:flutter/material.dart';

import '../../core/widgets/rembo_widgets.dart';
import 'auth_validation.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});
  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _email = TextEditingController(text: widget.initialEmail);
  String? _error;
  bool _loading = false;
  String? _sentTo;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _error = AuthValidation.email(_email.text));
    if (_error != null) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    await Future<void>.delayed(AuthValidation.simulatedDelay);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _sentTo = _email.text.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sentTo = _sentTo;
    return Scaffold(
      appBar: AppBar(title: const Text('Mot de passe oublié')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(RemboSpace.xl),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Réinitialiser le mot de passe',
                    style: RemboText.title,
                  ),
                  const SizedBox(height: RemboSpace.sm),
                  const Text(
                    'Indiquez votre adresse e-mail : nous vous enverrons un '
                    'lien pour choisir un nouveau mot de passe.',
                    style: RemboText.body,
                  ),
                  const SizedBox(height: RemboSpace.xl),
                  if (sentTo == null) ...[
                    RemboTextField(
                      fieldKey: const ValueKey('forgot-email'),
                      label: 'Adresse e-mail professionnelle',
                      controller: _email,
                      errorText: _error,
                      keyboardType: TextInputType.emailAddress,
                      onSubmitted: (_) => _send(),
                    ),
                    const SizedBox(height: RemboSpace.xl),
                    RemboPrimaryButton(
                      key: const ValueKey('forgot-submit'),
                      label: 'Envoyer le lien',
                      loading: _loading,
                      onPressed: _send,
                    ),
                  ] else ...[
                    RemboMessage(
                      tone: MessageTone.success,
                      title: 'Lien envoyé',
                      message:
                          'Si un compte existe pour $sentTo, vous recevrez '
                          'un e-mail dans quelques minutes. Pensez à vérifier '
                          'vos courriers indésirables.',
                    ),
                    const SizedBox(height: RemboSpace.xl),
                    RemboPrimaryButton(
                      key: const ValueKey('forgot-back'),
                      label: 'Retour à la connexion',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
