import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/agents/ocr_bench.dart';
import '../../core/data/app_state.dart';
import '../../core/ocr/receipt_reader.dart';
import '../../core/widgets/rembo_widgets.dart';

/// « Banc d'essai OCR » : the 30 fictional receipts of the Testing
/// Protocol, read on this phone (or by the server reader), field by field
/// against what they print. The measure the jury asks for, on real
/// pictures and a real phone.
class BenchScreen extends StatefulWidget {
  const BenchScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const BenchScreen()));

  @override
  State<BenchScreen> createState() => _BenchScreenState();
}

class _BenchScreenState extends State<BenchScreen> {
  List<BenchCase>? _cases;
  BenchReport? _report;
  int _done = 0;
  bool _running = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    rootBundle
        .loadString('assets/bench/manifest.json')
        .then((json) {
          if (mounted) setState(() => _cases = BenchCase.parseManifest(json));
        })
        .catchError((Object _) {
          if (mounted) {
            setState(() => _failure = tr('Le banc d’essai est introuvable.'));
          }
        });
  }

  Future<void> _run({required bool server}) async {
    final cases = _cases;
    if (cases == null || _running) return;
    final backend = AppScope.read(context).backend;
    final reader = server ? backend.readReceipt : deviceReceiptReader;
    if (reader == null) return;
    setState(() {
      _running = true;
      _done = 0;
      _report = null;
      _failure = null;
    });
    final results = <BenchResult>[];
    for (final c in cases) {
      final bytes = (await rootBundle.load('assets/bench/${c.file}')).buffer
          .asUint8List();
      final watch = Stopwatch()..start();
      ReceiptReading? reading;
      try {
        reading = await reader(bytes, c.file);
      } catch (_) {
        reading = null;
      }
      watch.stop();
      results.add(
        BenchResult(
          c,
          compareReading(reading, c),
          reading: reading,
          time: watch.elapsed,
        ),
      );
      if (!mounted) return;
      setState(() => _done = results.length);
    }
    setState(() {
      _running = false;
      _report = BenchReport(server ? 'server' : 'device', results);
    });
  }

  Future<void> _share(BenchReport report) async {
    final csv = report.toCsv();
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/rembo_banc_${report.engine}.csv');
      await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: 'text/csv')]),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: csv));
      if (mounted) {
        showRemboSnackBar(
          context,
          tr('Partage indisponible ici : le contenu du CSV a été copié.'),
          tone: MessageTone.info,
        );
      }
    }
  }

  static String _fieldName(String f) => switch (f) {
    'supplier' => tr('Fournisseur'),
    'ice' => 'ICE',
    'date' => tr('Date'),
    'amount' => tr('Montant TTC (MAD)'),
    'vat' => tr('TVA incluse'),
    'rate' => tr('Taux de TVA'),
    'currency' => tr('Devise du reçu'),
    _ => f,
  };

  static String _qualityName(String q) => switch (q) {
    'clean' => tr('Net'),
    'blur' => tr('Flou'),
    'faded' => tr('Délavé'),
    'tilt' => tr('Incliné'),
    'crumpled' => tr('Froissé'),
    'shadow' => tr('Ombre'),
    'lowres' => tr('Basse résolution'),
    'hand' => tr('Manuscrit'),
    _ => q,
  };

  String _percent(double rate) => '${(rate * 100).round()} %';

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final cases = _cases;
    final report = _report;
    return RemboPage(
      children: [
        RemboHero(
          title: tr('Banc d’essai OCR'),
          subtitle: tr(
            '30 reçus fictifs de qualités différentes, lus puis comparés '
            'champ par champ à ce qu’ils impriment.',
          ),
        ),
        if (_failure != null) ...[
          RemboMessage(tone: MessageTone.error, title: _failure!),
          const SizedBox(height: RemboSpace.lg),
        ],
        if (deviceReceiptReader == null)
          InfoStrip(
            tr(
              'Pas de lecteur sur cet appareil : lancez le banc sur un téléphone.',
            ),
          )
        else
          RemboPrimaryButton(
            key: const ValueKey('bench-device'),
            label: tr('Lire avec le téléphone'),
            icon: Icons.phone_android_rounded,
            loading: _running,
            onPressed: cases == null ? null : () => _run(server: false),
          ),
        if (!state.isDemo && !state.isLocal) ...[
          const SizedBox(height: RemboSpace.md),
          RemboSecondaryButton(
            key: const ValueKey('bench-server'),
            label: tr('Lire avec le lecteur du serveur'),
            icon: Icons.cloud_outlined,
            onPressed: cases == null || _running
                ? null
                : () => _run(server: true),
          ),
        ],
        if (_running && cases != null) ...[
          const SizedBox(height: RemboSpace.lg),
          LinearProgressIndicator(value: _done / cases.length),
          const SizedBox(height: RemboSpace.xs),
          Text(
            tr('Reçu {done} sur {total}', {
              'done': _done,
              'total': cases.length,
            }),
            style: RemboText.caption,
          ),
        ],
        if (report != null) ...[
          SectionTitle(
            tr('Résultat : {rate} des champs justes', {
              'rate': _percent(report.overall),
            }),
          ),
          RemboCard(
            key: const ValueKey('bench-report'),
            child: Column(
              children: [
                for (final f in benchFields)
                  DetailRow(
                    Icons.check_circle_outline_rounded,
                    _fieldName(f),
                    _percent(report.rate(f)),
                    mono: true,
                  ),
              ],
            ),
          ),
          SectionTitle(tr('Par qualité de photo')),
          RemboCard(
            child: Column(
              children: [
                for (final q in report.byQuality.entries)
                  DetailRow(
                    Icons.photo_outlined,
                    _qualityName(q.key),
                    _percent(q.value),
                    mono: true,
                  ),
              ],
            ),
          ),
          const SizedBox(height: RemboSpace.lg),
          RemboSecondaryButton(
            key: const ValueKey('bench-share'),
            label: tr('Partager le rapport (CSV)'),
            icon: Icons.ios_share_rounded,
            onPressed: () => _share(report),
          ),
        ],
        const SizedBox(height: RemboSpace.lg),
        InfoStrip(
          tr(
            'Rien n’est enregistré : le banc mesure seulement la lecture. '
            'Les reçus en arabe sont prévus pour le lecteur du serveur.',
          ),
        ),
      ],
    );
  }
}
