import 'package:flutter/material.dart';

/// Stable entry points for the future feature modules.
abstract final class AppRoutes {
  static const menu = '/';
  static const welcome = '/bienvenue';
  static const login = '/connexion';
  static const collaborator = '/collaborateur';
  static const capture = '/depenses/capture';
  static const review = '/depenses/verification';
  static const manager = '/responsable';
  static const accountant = '/comptable';
  static const settings = '/parametres';

  static const destinations = <RemboDestination>[
    RemboDestination(
      welcome,
      'Bienvenue',
      'Découvrir REMBO',
      'La scène d’accueil animée qui présente REMBO au premier lancement.',
      Icons.auto_awesome_outlined,
      '00',
    ),
    RemboDestination(
      login,
      'Connexion',
      'Accéder à mon espace',
      'Le point de départ de chaque membre de l’entreprise.',
      Icons.login_rounded,
      '01',
    ),
    RemboDestination(
      collaborator,
      'Espace collaborateur',
      'Mes dépenses',
      'Retrouver ses déclarations et suivre leur progression.',
      Icons.receipt_long_rounded,
      '02',
    ),
    RemboDestination(
      capture,
      'Capture du justificatif',
      'Ajouter un justificatif',
      'Le futur point d’entrée pour photographier ou importer un reçu.',
      Icons.add_a_photo_outlined,
      '03',
    ),
    RemboDestination(
      review,
      'Vérification des informations',
      'Vérifier les détails',
      'Relire les informations proposées et compléter la déclaration.',
      Icons.fact_check_outlined,
      '04',
    ),
    RemboDestination(
      manager,
      'Espace responsable',
      'Examiner les demandes',
      'Consulter les dépenses de son équipe et leur justificatif.',
      Icons.task_alt_rounded,
      '05',
    ),
    RemboDestination(
      accountant,
      'Espace comptable',
      'Préparer la comptabilité',
      'Retrouver les dépenses approuvées avant leur export.',
      Icons.account_balance_outlined,
      '06',
    ),
    RemboDestination(
      settings,
      'Paramètres',
      'Mes préférences',
      'Retrouver les réglages communs de son espace.',
      Icons.tune_rounded,
      '07',
    ),
  ];

  static RemboDestination? destinationFor(String? route) {
    for (final destination in destinations) {
      if (destination.route == route) return destination;
    }
    return null;
  }
}

class RemboDestination {
  const RemboDestination(
    this.route,
    this.title,
    this.action,
    this.description,
    this.icon,
    this.number,
  );
  final String route;
  final String title;
  final String action;
  final String description;
  final IconData icon;
  final String number;
}
