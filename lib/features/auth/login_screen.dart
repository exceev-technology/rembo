import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../core/widgets/rembo_widgets.dart';
import 'auth_validation.dart';
import 'forgot_password_screen.dart';

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
  bool _hidden = true;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _emailError = AuthValidation.email(_email.text);
      _passwordError = AuthValidation.password(_password.text);
    });
    if (_emailError != null || _passwordError != null) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    await Future<void>.delayed(AuthValidation.simulatedDelay);
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.of(context).pushReplacementNamed(AppRoutes.collaborator);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          RemboSpace.xl,
          RemboSpace.sm,
          RemboSpace.xl,
          RemboSpace.xl,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const RemboLogo(size: 44),
                  const SizedBox(height: RemboSpace.xxl),
                  const Text(
                    'Connexion',
                    key: ValueKey('destination-title'),
                    style: RemboText.display,
                  ),
                  const SizedBox(height: RemboSpace.sm),
                  const Text(
                    'Retrouvez vos dépenses et celles de votre équipe.',
                    style: RemboText.body,
                  ),
                  const SizedBox(height: RemboSpace.xl),
                  RemboTextField(
                    fieldKey: const ValueKey('login-email'),
                    label: 'Adresse e-mail professionnelle',
                    hint: 'prenom.nom@entreprise.ma',
                    controller: _email,
                    errorText: _emailError,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    onChanged: (_) {
                      if (_emailError != null) {
                        setState(() => _emailError = null);
                      }
                    },
                  ),
                  const SizedBox(height: RemboSpace.lg),
                  RemboTextField(
                    fieldKey: const ValueKey('login-password'),
                    label: 'Mot de passe',
                    controller: _password,
                    errorText: _passwordError,
                    obscureText: _hidden,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _submit(),
                    onChanged: (_) {
                      if (_passwordError != null) {
                        setState(() => _passwordError = null);
                      }
                    },
                    suffix: IconButton(
                      key: const ValueKey('toggle-password'),
                      tooltip: _hidden
                          ? 'Afficher le mot de passe'
                          : 'Masquer le mot de passe',
                      icon: Icon(
                        _hidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => _hidden = !_hidden),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: const ValueKey('login-forgot'),
                      onPressed: _loading
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ForgotPasswordScreen(
                                  initialEmail: _email.text.trim(),
                                ),
                              ),
                            ),
                      child: const Text('Mot de passe oublié ?'),
                    ),
                  ),
                  const SizedBox(height: RemboSpace.md),
                  RemboPrimaryButton(
                    key: const ValueKey('login-submit'),
                    label: 'Se connecter',
                    loading: _loading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: RemboSpace.xl),
                  const Row(
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 16,
                        color: RemboColors.muted,
                      ),
                      SizedBox(width: RemboSpace.sm),
                      Expanded(
                        child: Text(
                          'Données personnelles traitées selon la loi 09-08.',
                          style: RemboText.caption,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
