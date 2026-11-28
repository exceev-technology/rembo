/// What people kept of the agents' proposals, and how long they took to
/// declare: the measures the jury asks for (« champs OCR corrigés et
/// propositions d'agent acceptées telles quelles », « temps de
/// déclaration »).
///
/// Computed from the expenses a person may read, the same way as the SQL
/// view `agent_metrics` (supabase/migrations): keep both in step.
library;

import '../data/models.dart';

/// The value an expense finally holds for [field], written as the agents
/// wrote their proposal.
String? submittedValue(Expense e, String field) => switch (field) {
  'supplier' => e.supplier,
  'ice' => e.supplierIce,
  'date' => e.date == null ? null : isoDay(e.date!),
  'amount' => '${e.amountCents}',
  'vat' => '${e.vatCents}',
  'rate' => e.vatRate?.toString(),
  'currency' => e.currency,
  'foreign' => e.foreignAmountCents?.toString(),
  'category' => e.category,
  'project' => e.project,
  _ => null,
};

bool _same(String? kept, String proposed) =>
    (kept ?? '').trim().toLowerCase() == proposed.trim().toLowerCase();

/// One submitted expense: what was proposed, what was corrected.
class AgentMeasure {
  const AgentMeasure({
    required this.expense,
    required this.engine,
    required this.proposed,
    required this.corrected,
    this.declareTime,
  });
  final Expense expense;
  final String engine;

  /// Fields proposed, by agent: `reading` or `classification`.
  final Map<String, String> proposed;
  final Set<String> corrected;

  /// From the capture to the submission.
  final Duration? declareTime;

  int get accepted => proposed.length - corrected.length;

  static AgentMeasure? of(Expense e) {
    if (e.status == ExpenseStatus.draft) return null;
    final fields = (e.agentProposal?['fields'] as Map?) ?? const {};
    final proposed = <String, String>{};
    final corrected = <String>{};
    fields.forEach((field, value) {
      if (value is! Map) return;
      proposed['$field'] = '${value['agent'] ?? ''}';
      if (!_same(submittedValue(e, '$field'), '${value['value'] ?? ''}')) {
        corrected.add('$field');
      }
    });
    final submitted = e.events
        .where((ev) => ev.status == ExpenseStatus.submitted)
        .map((ev) => ev.at)
        .fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);
    final start = e.captureStartedAt;
    return AgentMeasure(
      expense: e,
      engine: '${e.agentProposal?['engine'] ?? ''}',
      proposed: proposed,
      corrected: corrected,
      declareTime: start == null || submitted == null
          ? null
          : submitted.difference(start),
    );
  }
}

/// Field by field: how often the proposal was kept.
class FieldScore {
  FieldScore(this.field);
  final String field;
  int proposed = 0;
  int accepted = 0;
  double get rate => proposed == 0 ? 0 : accepted / proposed;
}

class AgentMetrics {
  AgentMetrics._(this.measures);

  /// The measures of every submitted expense in [expenses].
  factory AgentMetrics.of(Iterable<Expense> expenses) =>
      AgentMetrics._([for (final e in expenses) ?AgentMeasure.of(e)]);

  final List<AgentMeasure> measures;

  /// Submitted expenses on which at least one agent proposed something.
  List<AgentMeasure> get assisted =>
      measures.where((m) => m.proposed.isNotEmpty).toList();

  int get proposed => assisted.fold(0, (s, m) => s + m.proposed.length);
  int get accepted => assisted.fold(0, (s, m) => s + m.accepted);
  int get corrected => proposed - accepted;
  double get acceptance => proposed == 0 ? 0 : accepted / proposed;

  /// Receipts whose every proposed field was kept as it was.
  int get untouched => assisted.where((m) => m.corrected.isEmpty).length;

  List<FieldScore> get byField {
    final scores = <String, FieldScore>{};
    for (final m in assisted) {
      for (final f in m.proposed.keys) {
        final s = scores.putIfAbsent(f, () => FieldScore(f));
        s.proposed++;
        if (!m.corrected.contains(f)) s.accepted++;
      }
    }
    return scores.values.toList()
      ..sort((a, b) => b.proposed.compareTo(a.proposed));
  }

  /// Median time to declare: with and without a reading agent.
  Duration? medianDeclare({bool? assisted}) {
    final times = [
      for (final m in measures)
        if (m.declareTime != null &&
            !m.declareTime!.isNegative &&
            (assisted == null || assisted == m.proposed.isNotEmpty))
          m.declareTime!,
    ]..sort();
    if (times.isEmpty) return null;
    final mid = times.length ~/ 2;
    return times.length.isOdd
        ? times[mid]
        : Duration(
            milliseconds:
                (times[mid - 1].inMilliseconds + times[mid].inMilliseconds) ~/
                2,
          );
  }
}
