/// Stable entry points. Feature screens that need an argument (an expense,
/// a draft) are pushed by their module with a `MaterialPageRoute`.
abstract final class AppRoutes {
  /// Session gate: login, company setup or the space of the signed-in role.
  static const home = '/';
  static const welcome = '/bienvenue';
  static const login = '/connexion';
  static const signup = '/inscription';
  static const forgotPassword = '/mot-de-passe-oublie';
  static const collaborator = '/collaborateur';
  static const capture = '/depenses/capture';
  static const review = '/depenses/verification';
  static const manager = '/responsable';
  static const accountant = '/comptable';
  static const team = '/equipe';
  static const rules = '/regles';
  static const settings = '/parametres';
}
