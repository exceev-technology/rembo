import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../core/data/app_state.dart';
import '../../core/widgets/rembo_widgets.dart';

/// Account creation. An address invited by a manager joins that company;
/// any other one goes on to create its own company.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _email = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  final _errors = <String, String>{};
  String? _notice;
  String? _failure;
  bool _obscure = true;
  bool _loading = false;
  bool _confirm = false;

  @override
  void dispose() {
    for (final c in [_email, _first, _last, _password, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final rules = passwordRules(_password.text);
    setState(() {
      _failure = null;
      _errors
        ..clear()
        ..addAll({
          if (!isValidEmail(_email.text))
            'email': tr('Adresse e-mail invalide.'),
          if (_first.text.trim().isEmpty)
            'first': tr('Saisissez votre prénom.'),
          if (_last.text.trim().isEmpty) 'last': tr('Saisissez votre nom.'),
          if (!(rules.length && rules.mixed && rules.special))
            'password': tr('Le mot de passe ne respecte pas les règles.'),
        });
    });
    if (_errors.isNotEmpty) return;
    setState(() => _loading = true);
    final state = AppScope.read(context);
    final navigator = Navigator.of(context);
    try {
      final signedIn = await state.signUp(
        email: _email.text.trim(),
        password: _password.text,
        fullName: '${_first.text.trim()} ${_last.text.trim()}',
      );
      if (!mounted) return;
      if (signedIn) {
        navigator.pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
      } else {
        setState(() => _confirm = true);
      }
    } on RemboException catch (e) {
      if (mounted) setState(() => _failure = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Signs in with the code of the confirmation e-mail.
  Future<void> _confirmCode() async {
    final code = _code.text.trim();
    setState(() {
      _failure = null;
      _notice = null;
      _errors.remove('code');
      if (!RegExp(r'^\d{6,8}$').hasMatch(code)) {
        _errors['code'] = tr('Saisissez le code à 6 chiffres reçu par e-mail.');
      }
    });
    if (_errors.containsKey('code')) return;
    setState(() => _loading = true);
    final navigator = Navigator.of(context);
    try {
      await AppScope.read(context)
          .confirmSignUp(email: _email.text.trim(), code: code);
      if (mounted) {
        navigator.pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
      }
    } on RemboException catch (e) {
      if (mounted) setState(() => _failure = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _failure = null;
      _notice = null;
    });
    try {
      await AppScope.read(context).backend.resendSignUpCode(_email.text.trim());
      if (mounted) {
        setState(() => _notice = tr('Un nouveau code a été envoyé.'));
      }
    } on RemboException catch (e) {
      if (mounted) setState(() => _failure = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rules = passwordRules(_password.text);
    if (_confirm) {
      return RemboPage(
        bottom: RemboPrimaryButton(
          key: const ValueKey('signup-confirm'),
          label: tr('Confirmer'),
          loading: _loading,
          onPressed: _confirmCode,
        ),
        children: [
          RemboMoment(
            title: tr('Confirmez votre adresse'),
            message: tr(
              'Un code à 6 chiffres a été envoyé à {trim}. Saisissez-le '
              'ci-dessous.',
              {'trim': _email.text.trim()},
            ),
            illustration: RemboArt.envelope,
          ),
          const SizedBox(height: RemboSpace.lg),
          if (_failure != null) ...[
            RemboMessage(tone: MessageTone.error, title: _failure!),
            const SizedBox(height: RemboSpace.lg),
          ],
          if (_notice != null) ...[
            RemboMessage(tone: MessageTone.success, title: _notice!),
            const SizedBox(height: RemboSpace.lg),
          ],
          RemboTextField(
            fieldKey: const ValueKey('signup-code'),
            label: tr('Code reçu par e-mail'),
            hint: '123456',
            icon: Icons.pin_outlined,
            controller: _code,
            errorText: _errors['code'],
            keyboardType: TextInputType.number,
            onSubmitted: (_) => _confirmCode(),
          ),
          const SizedBox(height: RemboSpace.sm),
          Text(
            tr('Pas reçu ? Regardez dans les courriers indésirables.'),
            style: RemboText.caption,
          ),
          Center(
            child: TextButton(
              key: const ValueKey('signup-resend'),
              onPressed: _loading ? null : _resend,
              child: Text(tr('Renvoyer le code')),
            ),
          ),
        ],
      );
    }
    return RemboPage(
      children: [
        Semantics(
          header: true,
          child: Text(
            tr('Créer un compte'),
            style: RemboText.display,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: RemboSpace.sm),
        Text(
          tr('Invité ? Utilisez l’adresse qui a reçu l’invitation.'),
          style: RemboText.note,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: RemboSpace.xl),
        if (_failure != null) ...[
          RemboMessage(tone: MessageTone.error, title: _failure!),
          const SizedBox(height: RemboSpace.lg),
        ],
        RemboTextField(
          fieldKey: const ValueKey('signup-email'),
          label: tr('Adresse e-mail'),
          hint: 'votre@email.com',
          icon: Icons.mail_outline_rounded,
          controller: _email,
          errorText: _errors['email'],
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: RemboSpace.lg),
        RemboTextField(
          fieldKey: const ValueKey('signup-first'),
          label: tr('Prénom'),
          hint: tr('Votre prénom'),
          icon: Icons.person_outline_rounded,
          controller: _first,
          errorText: _errors['first'],
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: RemboSpace.lg),
        RemboTextField(
          fieldKey: const ValueKey('signup-last'),
          label: tr('Nom'),
          hint: tr('Votre nom'),
          icon: Icons.person_outline_rounded,
          controller: _last,
          errorText: _errors['last'],
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: RemboSpace.lg),
        RemboTextField(
          fieldKey: const ValueKey('signup-password'),
          label: tr('Mot de passe'),
          hint: tr('Votre mot de passe'),
          icon: Icons.lock_outline_rounded,
          controller: _password,
          errorText: _errors['password'],
          obscureText: _obscure,
          onChanged: (_) => setState(() {}),
          suffix: IconButton(
            tooltip: _obscure
                ? tr('Afficher le mot de passe')
                : tr('Masquer le mot de passe'),
            icon: Icon(
              _obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        const SizedBox(height: RemboSpace.md),
        Text(
          tr('Votre mot de passe doit contenir :'),
          style: RemboText.caption,
        ),
        const SizedBox(height: RemboSpace.xs),
        _Rule(tr('Au moins 8 caractères'), rules.length),
        _Rule(tr('Une lettre et un chiffre'), rules.mixed),
        _Rule(tr('Un caractère spécial (ex. : !, @, #)'), rules.special),
        const SizedBox(height: RemboSpace.xl),
        RemboPrimaryButton(
          key: const ValueKey('signup-submit'),
          label: tr('Créer mon compte'),
          loading: _loading,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule(this.text, this.ok);
  final String text;
  final bool ok;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Icon(
          ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 16,
          color: ok ? RemboColors.green : RemboColors.muted,
        ),
        const SizedBox(width: RemboSpace.sm),
        Expanded(
          child: Text(
            text,
            style: RemboText.caption.copyWith(
              color: ok ? RemboColors.successText : RemboColors.muted,
            ),
          ),
        ),
      ],
    ),
  );
}
