import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../core/data/app_state.dart';
import '../../core/data/demo_backend.dart';
import '../../core/widgets/rembo_widgets.dart';
import '../../core/data/demo_build.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _emailError;
  String? _passwordError;
  String? _failure;
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _failure = null;
      _emailError = _email.text.trim().isEmpty
          ? tr('Saisissez votre adresse e-mail.')
          : (isValidEmail(_email.text) ? null : tr('Adresse e-mail invalide.'));
      _passwordError = _password.text.isEmpty
          ? tr('Saisissez votre mot de passe.')
          : null;
    });
    if (_emailError != null || _passwordError != null) return;
    await _signIn(_email.text.trim(), _password.text);
  }

  Future<void> _signIn(String email, String password) async {
    setState(() => _loading = true);
    final state = AppScope.read(context);
    final navigator = Navigator.of(context);
    try {
      await state.signIn(email, password);
      if (!mounted) return;
      navigator.pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
    } on RemboException catch (e) {
      if (mounted) setState(() => _failure = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final demo = demoAllowed && AppScope.of(context).isDemo;
    return RemboPage(
      logo: true,
      showBack: false,
      trailing: const LanguageButton(),
      children: [
        const SizedBox(height: RemboSpace.sm),
        const Center(child: HeroArt(height: 140)),
        const SizedBox(height: RemboSpace.lg),
        Semantics(
          header: true,
          child: Text(
            tr('Vos frais,\nsimplement.'),
            style: RemboText.display.copyWith(fontSize: 34),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: RemboSpace.xl),
        if (_failure != null) ...[
          RemboMessage(tone: MessageTone.error, title: _failure!),
          const SizedBox(height: RemboSpace.lg),
        ],
        AutofillGroup(
          child: Column(
            children: [
              RemboTextField(
                fieldKey: const ValueKey('login-email'),
                label: tr('Adresse e-mail'),
                hint: 'votre@email.com',
                icon: Icons.mail_outline_rounded,
                controller: _email,
                errorText: _emailError,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: RemboSpace.lg),
              RemboTextField(
                fieldKey: const ValueKey('login-password'),
                label: tr('Mot de passe'),
                hint: tr('Votre mot de passe'),
                icon: Icons.lock_outline_rounded,
                controller: _password,
                errorText: _passwordError,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                autofillHints: const [AutofillHints.password],
                suffix: IconButton(
                  key: const ValueKey('login-toggle-password'),
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
            ],
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            key: const ValueKey('login-forgot'),
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.forgotPassword),
            child: Text(tr('Mot de passe oublié ?')),
          ),
        ),
        const SizedBox(height: RemboSpace.sm),
        RemboPrimaryButton(
          key: const ValueKey('login-submit'),
          label: tr('Se connecter'),
          loading: _loading,
          onPressed: _submit,
        ),
        const SizedBox(height: RemboSpace.sm),
        Center(
          child: TextButton(
            key: const ValueKey('login-signup'),
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.signup),
            child: Text(tr('Pas encore de compte ? Créer un compte')),
          ),
        ),
        if (demo) ...[
          const SizedBox(height: RemboSpace.lg),
          RemboCard(
            color: RemboColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('Mode démonstration'), style: RemboText.subtitle),
                const SizedBox(height: RemboSpace.xs),
                Text(
                  tr(
                    'Aucun serveur n’est configuré : les comptes et les dépenses '
                    'sont fictifs et rien n’est enregistré.',
                  ),
                  style: RemboText.caption,
                ),
                const SizedBox(height: RemboSpace.md),
                Wrap(
                  spacing: RemboSpace.sm,
                  runSpacing: RemboSpace.sm,
                  children: [
                    for (final u in const [
                      DemoBackend.marius,
                      DemoBackend.salma,
                      DemoBackend.nadia,
                    ])
                      ActionChip(
                        key: ValueKey('demo-${u.role.name}'),
                        avatar: const Icon(Icons.login_rounded, size: 18),
                        label: Text(u.role.label),
                        onPressed: _loading
                            ? null
                            : () => _signIn(u.email, 'demo'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: RemboSpace.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 14,
              color: RemboColors.muted,
            ),
            const SizedBox(width: RemboSpace.xs),
            // Always on one line: it shrinks rather than wraps.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  tr('Données personnelles traitées selon la loi 09-08.'),
                  maxLines: 1,
                  softWrap: false,
                  style: RemboText.caption.copyWith(fontSize: 11.5),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
