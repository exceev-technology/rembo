/// Local checks only: V1 never contacts an authentication service.
abstract final class AuthValidation {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String value) {
    final v = value.trim();
    if (v.isEmpty) return 'Saisissez votre adresse e-mail.';
    if (!_email.hasMatch(v)) return 'Cette adresse e-mail n’est pas valide.';
    return null;
  }

  static String? password(String value) =>
      value.isEmpty ? 'Saisissez votre mot de passe.' : null;

  /// Stands in for the network round trip of a real sign-in.
  static const simulatedDelay = Duration(milliseconds: 900);
}
