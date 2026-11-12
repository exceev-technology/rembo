import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/data/app_state.dart';
import '../../core/widgets/rembo_widgets.dart';

/// WhatsApp number of the company's REMBO line, digits only, given at
/// build time (REMBO_WHATSAPP_NUMBER). Empty until the line exists.
const remboWhatsAppNumber = String.fromEnvironment('REMBO_WHATSAPP_NUMBER');

Future<bool> _open(String url) async {
  try {
    return await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}

/// Explains the WhatsApp channel and lets the person link their number.
Future<void> showWhatsAppSheet(BuildContext context) => showRemboSheet<void>(
  context,
  title: 'Dépenses par WhatsApp',
  subtitle:
      'Envoyez une note vocale, un message ou la photo d’un ticket : '
      'REMBO prépare la dépense, vous confirmez.',
  builder: (_) => const _WhatsAppForm(),
);

class _WhatsAppForm extends StatefulWidget {
  const _WhatsAppForm();

  @override
  State<_WhatsAppForm> createState() => _WhatsAppFormState();
}

class _WhatsAppFormState extends State<_WhatsAppForm> {
  late final _phone = TextEditingController(
    text: AppScope.read(context).user?.whatsappPhone ?? '',
  );
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save({bool unlink = false}) async {
    final phone = unlink ? null : parsePhone(_phone.text);
    if (!unlink && phone == null) {
      setState(() => _error = 'Numéro invalide. Exemple : 06 12 34 56 78.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AppScope.read(context).linkWhatsApp(phone);
      if (!mounted) return;
      if (unlink) _phone.clear();
      showRemboSnackBar(
        context,
        unlink ? 'Numéro retiré.' : 'Numéro WhatsApp enregistré.',
      );
    } on RemboException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final linked = state.user?.whatsappPhone;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Step('1', 'Reliez votre numéro WhatsApp à votre compte.'),
        const _Step(
          '2',
          'Dites par exemple : « Taxi, 45 dirhams, client Atlas ».',
        ),
        const _Step('3', 'Répondez « oui », ou confirmez dans l’application.'),
        const SizedBox(height: RemboSpace.lg),
        RemboTextField(
          fieldKey: const ValueKey('whatsapp-phone'),
          label: 'Votre numéro WhatsApp',
          hint: '06 12 34 56 78',
          icon: Icons.phone_iphone_rounded,
          controller: _phone,
          errorText: _error,
          keyboardType: TextInputType.phone,
          helper: linked == null ? null : 'Numéro relié : $linked',
        ),
        const SizedBox(height: RemboSpace.lg),
        RemboPrimaryButton(
          key: const ValueKey('whatsapp-save'),
          label: linked == null ? 'Relier mon numéro' : 'Mettre à jour',
          loading: _loading,
          onPressed: _save,
        ),
        if (linked != null) ...[
          const SizedBox(height: RemboSpace.sm),
          if (remboWhatsAppNumber.isNotEmpty)
            RemboSecondaryButton(
              key: const ValueKey('whatsapp-open'),
              label: 'Ouvrir WhatsApp',
              icon: Icons.chat_outlined,
              onPressed: () async {
                final ok = await _open('https://wa.me/$remboWhatsAppNumber');
                if (!ok && context.mounted) {
                  showRemboSnackBar(
                    context,
                    'WhatsApp n’a pas pu être ouvert.',
                    tone: MessageTone.error,
                  );
                }
              },
            ),
          Center(
            child: TextButton(
              key: const ValueKey('whatsapp-unlink'),
              onPressed: _loading ? null : () => _save(unlink: true),
              child: const Text('Retirer mon numéro'),
            ),
          ),
        ],
        const SizedBox(height: RemboSpace.sm),
        InfoStrip(
          state.isDemo
              ? 'Démonstration : aucun message n’est réellement reçu. Une '
                    'dépense d’exemple vous attend sur l’accueil.'
              : state.isLocal
              ? 'WhatsApp demande un serveur : il sera disponible quand '
                    'votre entreprise sera connectée à REMBO en ligne.'
              : (remboWhatsAppNumber.isEmpty
                    ? 'La ligne WhatsApp de votre entreprise n’est pas encore '
                          'activée : votre numéro sera prêt le jour venu.'
                    : 'Écrivez au +$remboWhatsAppNumber depuis ce numéro.'),
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
      'Démonstration : aucun enregistrement audio n’est associé.',
      tone: MessageTone.info,
    );
    return;
  }
  final url = await state.backend.voiceUrl(expense);
  final ok = url != null && await _open(url);
  if (!ok && context.mounted) {
    showRemboSnackBar(
      context,
      'Le message vocal n’a pas pu être ouvert.',
      tone: MessageTone.error,
    );
  }
}
