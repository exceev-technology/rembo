import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/data/app_state.dart';
import '../../core/widgets/rembo_widgets.dart';
import '../../core/log.dart';

/// WhatsApp number of the company's REMBO line, digits only, given at
/// build time (REMBO_WHATSAPP_NUMBER). Empty until the line exists.
const remboWhatsAppNumber = String.fromEnvironment('REMBO_WHATSAPP_NUMBER');

Future<bool> _open(String url) async {
  try {
    return await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (e, st) {
    logFailure('link not opened', e, st);
    return false;
  }
}

/// Explains the WhatsApp channel and lets the person link their number.
Future<void> showWhatsAppSheet(BuildContext context) => showRemboSheet<void>(
  context,
  title: tr('Dépenses par WhatsApp'),
  subtitle: tr(
    'Envoyez une note vocale, un message ou la photo d’un ticket : '
    'REMBO prépare la dépense, vous confirmez.',
  ),
  builder: (_) => const _WhatsAppForm(),
);

class _WhatsAppForm extends StatefulWidget {
  const _WhatsAppForm();

  @override
  State<_WhatsAppForm> createState() => _WhatsAppFormState();
}

class _WhatsAppFormState extends State<_WhatsAppForm> {
  WhatsAppLinkCode? _code;
  String? _error;
  bool _loading = false;

  Future<void> _run(Future<void> Function(AppState state) action) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action(AppScope.read(context));
    } on RemboException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestCode() => _run((state) async {
    final code = await state.requestWhatsAppCode();
    if (mounted) setState(() => _code = code);
  });

  /// The number is linked by the server when the code arrives from it.
  Future<void> _check() => _run((state) async {
    await state.checkWhatsAppLink();
    if (!mounted) return;
    if (state.user?.whatsappPhone == null) {
      setState(
        () =>
            _error = tr('Pas encore reçu. Envoyez le message, puis réessayez.'),
      );
      return;
    }
    setState(() => _code = null);
    showRemboSnackBar(context, tr('Numéro WhatsApp enregistré.'));
  });

  Future<void> _unlink() => _run((state) async {
    await state.unlinkWhatsApp();
    if (mounted) showRemboSnackBar(context, tr('Numéro retiré.'));
  });

  Future<void> _send(WhatsAppLinkCode code) async {
    final text = Uri.encodeComponent(code.message);
    final ok = await _open('https://wa.me/$remboWhatsAppNumber?text=$text');
    if (!ok && mounted) {
      showRemboSnackBar(
        context,
        tr('WhatsApp n’a pas pu être ouvert.'),
        tone: MessageTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final linked = state.user?.whatsappPhone;
    final code = _code;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Step('1', tr('Obtenez un code à usage unique.')),
        _Step(
          '2',
          tr(
            'Envoyez « LIER » suivi du code depuis votre WhatsApp : '
            'ce numéro est relié.',
          ),
        ),
        _Step(
          '3',
          tr('Dites par exemple : « Taxi, 45 dirhams, client Atlas ».'),
        ),
        _Step('4', tr('Répondez « oui », ou confirmez dans l’application.')),
        const SizedBox(height: RemboSpace.lg),
        if (linked != null) ...[
          Text(
            tr('Numéro relié : {linked}', {'linked': ltr(linked)}),
            key: const ValueKey('whatsapp-linked'),
            style: RemboText.subtitle,
          ),
          const SizedBox(height: RemboSpace.md),
        ],
        if (_error != null) ...[
          RemboMessage(
            key: const ValueKey('whatsapp-error'),
            tone: MessageTone.error,
            title: _error!,
          ),
          const SizedBox(height: RemboSpace.md),
        ],
        if (code == null)
          RemboPrimaryButton(
            key: const ValueKey('whatsapp-request'),
            label: tr('Obtenir un code'),
            loading: _loading,
            onPressed: _requestCode,
          )
        else ...[
          RemboCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('Envoyez ce message depuis votre WhatsApp :'),
                  style: RemboText.body,
                ),
                const SizedBox(height: RemboSpace.sm),
                Text(
                  ltr(code.message),
                  key: const ValueKey('whatsapp-code'),
                  style: RemboText.amount.copyWith(fontSize: 26),
                ),
                const SizedBox(height: RemboSpace.xs),
                Text(
                  tr('Valable jusqu’à {time}.', {
                    'time': formatTime(code.expiresAt),
                  }),
                  style: RemboText.caption,
                ),
              ],
            ),
          ),
          const SizedBox(height: RemboSpace.md),
          if (remboWhatsAppNumber.isNotEmpty) ...[
            RemboSecondaryButton(
              key: const ValueKey('whatsapp-open'),
              label: tr('Envoyer par WhatsApp'),
              icon: Icons.chat_outlined,
              onPressed: () => _send(code),
            ),
            const SizedBox(height: RemboSpace.sm),
          ],
          RemboPrimaryButton(
            key: const ValueKey('whatsapp-check'),
            label: tr('J’ai envoyé le code'),
            loading: _loading,
            onPressed: _check,
          ),
        ],
        if (linked != null)
          Center(
            child: TextButton(
              key: const ValueKey('whatsapp-unlink'),
              onPressed: _loading ? null : _unlink,
              child: Text(tr('Retirer mon numéro')),
            ),
          ),
        const SizedBox(height: RemboSpace.sm),
        InfoStrip(
          state.isDemo
              ? tr(
                  'Démonstration : aucun message n’est réellement reçu. Une '
                  'dépense d’exemple vous attend sur l’accueil.',
                )
              : state.isLocal
              ? tr(
                  'WhatsApp demande un serveur : il sera disponible quand votre '
                  'entreprise sera connectée à REMBO en ligne.',
                )
              : (remboWhatsAppNumber.isEmpty
                    ? tr(
                        'La ligne WhatsApp de votre entreprise n’est pas encore '
                        'activée : votre numéro sera prêt le jour venu.',
                      )
                    : tr('Écrivez au {numero} depuis ce numéro.', {
                        'numero': ltr('+$remboWhatsAppNumber'),
                      })),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.number, this.text);
  final String number;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: RemboSpace.sm),
    child: Row(
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: RemboColors.surface,
          child: Text(
            number,
            style: RemboText.label.copyWith(color: RemboColors.indigo),
          ),
        ),
        const SizedBox(width: RemboSpace.md),
        Expanded(child: Text(text, style: RemboText.body)),
      ],
    ),
  );
}

/// Opens the voice note in the phone's player.
Future<void> playVoiceNote(BuildContext context, Expense expense) async {
  final state = AppScope.read(context);
  if (state.isDemo) {
    showRemboSnackBar(
      context,
      tr('Démonstration : aucun enregistrement audio n’est associé.'),
      tone: MessageTone.info,
    );
    return;
  }
  final url = await state.backend.voiceUrl(expense);
  final ok = url != null && await _open(url);
  if (!ok && context.mounted) {
    showRemboSnackBar(
      context,
      tr('Le message vocal n’a pas pu être ouvert.'),
      tone: MessageTone.error,
    );
  }
}
