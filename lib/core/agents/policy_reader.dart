/// Policy reader without a server: finds in a pasted text the rules REMBO
/// can apply (deadline, project, limits per category). The server reads any
/// document with the receipt engine (Edge Function read-policy); this one
/// serves the local and demo backends, on plain French text only.
library;

import '../data/models.dart';
import '../format/parsers.dart';

const _keywords = {
  'Repas': ['repas', 'restaurant', 'déjeuner', 'dîner', 'diner'],
  'Transport': ['transport', 'taxi', 'train', 'carburant', 'déplacement'],
  'Hébergement': ['hébergement', 'hôtel', 'hotel', 'nuitée'],
  'Fournitures': ['fournitures', 'papeterie'],
};

final _amount = RegExp(
  r'(\d[\d  .,]*)\s*(?:dh|mad|dirhams?)\b',
  caseSensitive: false,
);
final _days = RegExp(r'(\d{1,3})\s*jours', caseSensitive: false);
final _forbidden = RegExp(
  r'interdit|exclu|obligatoire|doit|doivent|(?:pas|non|jamais)\b.*rembours',
  caseSensitive: false,
);

/// « 1.200 », « 1 200,50 », « 150 » → centimes.
int? _cents(String written) {
  var text = written.trim();
  if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(text)) {
    text = text.replaceAll('.', '');
  }
  return parseAmount(text);
}

PolicyProposal readPolicyText(String text, {required String documentName}) {
  final lines = text
      .split(RegExp(r'[\n;]+|\.(?=\s|$)'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  int? deadline;
  bool? project;
  final rules = <PolicyRule>[];
  final used = <String>{};
  for (final line in lines) {
    final lower = line.toLowerCase();
    if (deadline == null &&
        RegExp(r'délai|déclar|soum|dans les|sous').hasMatch(lower)) {
      final days = int.tryParse(_days.firstMatch(lower)?.group(1) ?? '');
      if (days != null && days >= 1 && days <= 365) {
        deadline = days;
        used.add(line);
      }
    }
    if (project == null && RegExp(r'projet|client|mission').hasMatch(lower)) {
      if (RegExp(r'facultati|optionnel').hasMatch(lower)) {
        project = false;
        used.add(line);
      } else if (RegExp(r'obligatoire|doit|exig|indiquer').hasMatch(lower)) {
        project = true;
        used.add(line);
      }
    }
    for (final entry in _keywords.entries) {
      if (rules.any((r) => r.category == entry.key)) continue;
      if (!entry.value.any(lower.contains)) continue;
      final cents = _cents(_amount.firstMatch(line)?.group(1) ?? '');
      if (cents == null || cents <= 0) continue;
      rules.add(
        PolicyRule(
          category: entry.key,
          limitCents: cents,
          receiptRequired: !lower.contains('sans justificatif'),
        ),
      );
      used.add(line);
    }
  }
  final others = [
    for (final line in lines)
      if (!used.contains(line) && _forbidden.hasMatch(line)) line,
  ].take(10).toList();
  return PolicyProposal(
    documentName: documentName,
    summary: rules.isEmpty && deadline == null && project == null
        ? ''
        : 'Règles trouvées dans le texte de la politique.',
    deadlineDays: deadline,
    projectRequired: project,
    rules: rules,
    notApplied: others,
  );
}
