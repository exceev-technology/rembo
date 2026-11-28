import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../core/data/app_state.dart';
import '../../core/widgets/rembo_widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.email});

  /// Filled in when a signed-in person changes their password.
  final String? email;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _email = TextEditingController(text: widget.email ?? '');
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _errors = <String, String>{};
  bool _obscure = true;
  String? _error;
  String? _failure;
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
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

  /// Sets the new password with the e-mailed code; signs in.
  Future<void> _reset() async {
    final rules = passwordRules(_password.text);
    setState(() {
      _failure = null;
      _errors
        ..clear()
        ..addAll({
          if (!RegExp(r'^\d{6,8}$').hasMatch(_code.text.trim()))
            'code': tr('Saisissez le code à 6 chiffres reçu par e-mail.'),
          if (!(rules.length && rules.mixed && rules.special))
            'password': tr('Le mot de passe ne respecte pas les règles.'),
        });
    });
    if (_errors.isNotEmpty) return;
    setState(() => _loading = true);
    final navigator = Navigator.of(context);
    try {
      await AppScope.read(context).resetPassword(
        email: _email.text.trim(),
        code: _code.text.trim(),
        newPassword: _password.text,
      );
      if (mounted) {
        navigator.pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
      }
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
          tr(
            'Recevez un code par e-mail pour choisir un nouveau mot de passe.',
          ),
          style: RemboText.note.copyWith(fontSize: 14),
        ),
        const SizedBox(height: RemboSpace.xl),
        if (_sent && !demo) ...[
          RemboMessage(
            key: const ValueKey('reset-sent'),
            tone: MessageTone.success,
            title: tr('Code envoyé'),
            message: tr(
              'Si un compte existe pour {trim}, un code à 6 chiffres arrive '
              'dans quelques minutes (pensez aux courriers indésirables).',
              {'trim': _email.text.trim()},
            ),
          ),
          const SizedBox(height: RemboSpace.lg),
          if (_failure != null) ...[
            RemboMessage(tone: MessageTone.error, title: _failure!),
            const SizedBox(height: RemboSpace.lg),
          ],
          RemboTextField(
            fieldKey: const ValueKey('reset-code'),
            label: tr('Code reçu par e-mail'),
            hint: '123456',
            icon: Icons.pin_outlined,
            controller: _code,
            errorText: _errors['code'],
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: RemboSpace.lg),
          RemboTextField(
            fieldKey: const ValueKey('reset-password'),
            label: tr('Nouveau mot de passe'),
            icon: Icons.lock_outline_rounded,
            controller: _password,
            obscureText: _obscure,
            errorText: _errors['password'],
            helper: tr(
              'Au moins 8 caractères, une lettre, un chiffre et un caractère spécial.',
            ),
            suffix: IconButton(
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
            onSubmitted: (_) => _reset(),
          ),
          const SizedBox(height: RemboSpace.xl),
          RemboPrimaryButton(
            key: const ValueKey('reset-confirm'),
            label: tr('Changer le mot de passe'),
            loading: _loading,
            onPressed: _reset,
          ),
        ] else if (_sent)
          RemboMessage(
            key: const ValueKey('reset-sent'),
            tone: MessageTone.info,
            title: tr('Démonstration : aucun e-mail envoyé'),
            message: demo
                ? tr(
                    'Avec un serveur configuré, un lien serait envoyé à {trim}.',
                    {'trim': _email.text.trim()},
                  )
                : null,
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
            label: tr('Envoyer le code'),
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
