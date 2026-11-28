/// Classification and allocation agent: proposes the category and the
/// client or project of an expense from its supplier.
///
/// It runs on the phone, without a model: first what this person did with
/// the same supplier before (their own history is the best guide), then a
/// list of Moroccan supplier names and kinds of shops. Every proposal says
/// why; the person keeps the last word on the form.
library;

import '../data/models.dart';

/// A value an agent proposes for one field, and why.
class Proposal {
  const Proposal(this.value, this.note);
  final String value;
  final FieldNote note;
}

class Classification {
  const Classification({this.category, this.project});
  final Proposal? category;
  final Proposal? project;

  bool get isEmpty => category == null && project == null;
}

/// « Hôtel  Farah » and « HOTEL FARAH » are the same supplier.
String normalizeSupplier(String name) {
  const accents = {
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'ç': 'c',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'ï': 'i',
    'ô': 'o',
    'ö': 'o',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ÿ': 'y',
  };
  final lower = name.toLowerCase().split('').map((c) => accents[c] ?? c).join();
  return lower.replaceAll(RegExp(r'[^a-z0-9؀-ۿ]+'), ' ').trim();
}

/// Words that tell the kind of shop, by category. Matched as whole words
/// in the normalised supplier name.
const supplierKeywords = <String, List<String>>{
  'Transport': [
    'taxi',
    'petit taxi',
    'grand taxi',
    'careem',
    'indrive',
    'uber',
    'heetch',
    'oncf',
    'boraq',
    'al boraq',
    'ctm',
    'supratours',
    'autoroute',
    'adm',
    'peage',
    'parking',
    'afriquia',
    'shell',
    'totalenergies',
    'winxo',
    'petrom',
    'ziz',
    'carburant',
    'station',
    'essence',
    'gasoil',
    'royal air maroc',
    'air arabia',
    'ryanair',
    'hertz',
    'avis',
    'sixt',
    'tramway',
    'busway',
    'alsa',
    'طاكسي',
    'سيارة أجرة',
    'محطة',
  ],
  'Repas': [
    'restaurant',
    'resto',
    'cafe',
    'snack',
    'patisserie',
    'boulangerie',
    'mcdonald',
    'mcdonalds',
    'kfc',
    'pizza',
    'pizzeria',
    'burger',
    'tajine',
    'brasserie',
    'glacier',
    'traiteur',
    'rotisserie',
    'sushi',
    'grill',
    'مطعم',
    'مقهى',
    'حلويات',
  ],
  'Hébergement': [
    'hotel',
    'riad',
    'ibis',
    'novotel',
    'sofitel',
    'marriott',
    'hilton',
    'kenzi',
    'onomo',
    'airbnb',
    'booking',
    'auberge',
    'residence',
    'appart hotel',
    'فندق',
    'رياض',
  ],
  'Fournitures': [
    'librairie',
    'papeterie',
    'bureau',
    'imprimerie',
    'marjane',
    'carrefour',
    'bim',
    'acima',
    'aswak assalam',
    'label vie',
    'jumia',
    'electroplanet',
    'virgin',
    'ikea',
    'photocopie',
    'informatique',
    'مكتبة',
    'مطبعة',
  ],
};

/// The category and project to propose for [supplier] (and its [ice]),
/// given the person's earlier [history]. Drafts and rejected expenses do
/// not count: they were never accepted as they were.
Classification classifyExpense({
  required String supplier,
  String ice = '',
  required Iterable<Expense> history,
}) {
  final name = normalizeSupplier(supplier);
  if (name.isEmpty && ice.isEmpty) return const Classification();

  final same = history.where(
    (e) =>
        e.status != ExpenseStatus.draft &&
        e.status != ExpenseStatus.rejected &&
        ((ice.isNotEmpty && e.supplierIce == ice) ||
            (name.isNotEmpty && normalizeSupplier(e.supplier) == name)),
  );

  Proposal? category;
  final counts = <String, int>{};
  for (final e in same) {
    if (e.category.isEmpty || e.category == 'Autre') continue;
    counts[e.category] = (counts[e.category] ?? 0) + 1;
  }
  if (counts.isNotEmpty) {
    final best = counts.entries.reduce((a, b) => b.value > a.value ? b : a);
    category = Proposal(
      best.key,
      FieldNote(
        best.value >= 2 ? Confidence.high : Confidence.medium,
        'Catégorie de vos dépenses précédentes chez ce fournisseur',
      ),
    );
  } else {
    final padded = ' $name ';
    for (final entry in supplierKeywords.entries) {
      if (entry.value.any((k) => padded.contains(' $k '))) {
        category = Proposal(
          entry.key,
          const FieldNote(
            Confidence.medium,
            'Type de fournisseur reconnu à son nom',
          ),
        );
        break;
      }
    }
  }

  Proposal? project;
  final withProject = same.where((e) => e.project.trim().isNotEmpty).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  if (withProject.isNotEmpty) {
    project = Proposal(
      withProject.first.project,
      const FieldNote(
        Confidence.medium,
        'Projet de votre dernière dépense chez ce fournisseur',
      ),
    );
  }
  return Classification(category: category, project: project);
}
