import 'package:flutter/foundation.dart';

/// Fictional signed-in person shown by the common screens.
abstract final class DemoProfile {
  static const name = 'Amina Berrada';
  static const initials = 'AB';
  static const email = 'amina.berrada@atlas-logistique.ma';
  static const role = 'Collaboratrice';
  static const team = 'Ventes · Casablanca';
  static const manager = 'Nadia Tazi';
  static const company = 'Atlas Logistique SARL';
}

/// Lets the demo show the offline state without touching the network.
final demoOffline = ValueNotifier<bool>(false);
