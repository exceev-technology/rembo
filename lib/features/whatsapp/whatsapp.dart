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
  late PhoneCountry _country;
  late final TextEditingController _phone;
  final _countryLabel = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // A linked number comes back as +212…: show it the way its country
    // writes it, or as it is when the country is not in the list.
    final linked = AppScope.read(context).user?.whatsappPhone;
    final known = linked == null ? null : countryOf(linked);
    _country = known ?? morocco;
    _showCountry();
    _phone = TextEditingController(
      text: known == null ? linked ?? '' : known.toNational(linked!),
    );
  }

  void _showCountry() => _countryLabel.text =
      '${_country.localName} (${ltr('+${_country.dial}')})';

  Future<void> _pickCountry() async {
    final picked = await showRemboSheet<PhoneCountry>(
      context,
      title: tr('Pays du numéro'),
      builder: (_) => _CountryList(selected: _country),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _country = picked;
      _showCountry();
      _error = null;
    });
  }

  @override
  void dispose() {
    _phone.dispose();
    _countryLabel.dispose();
    super.dispose();
  }

  Future<void> _save({bool unlink = false}) async {
    final phone = unlink ? null : parsePhone(_phone.text, country: _country);
    if (!unlink && phone == null) {
      setState(
        () => _error = tr(
          'Numéro invalide pour {country}. Exemple : {example}.',
          {'country': _country.localName, 'example': _country.example},
        ),
      );
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
        unlink ? tr('Numéro retiré.') : tr('Numéro WhatsApp enregistré.'),
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
        _Step('1', tr('Reliez votre numéro WhatsApp à votre compte.')),
        _Step(
          '2',
          tr('Dites par exemple : « Taxi, 45 dirhams, client Atlas ».'),
        ),
        _Step('3', tr('Répondez « oui », ou confirmez dans l’application.')),
        const SizedBox(height: RemboSpace.lg),
        RemboTextField(
          fieldKey: const ValueKey('whatsapp-country'),
          label: tr('Pays'),
          icon: Icons.public_rounded,
          controller: _countryLabel,
          readOnly: true,
          onTap: _pickCountry,
          suffix: const Icon(Icons.expand_more_rounded),
          helper: tr('Autre pays : écrivez le numéro complet, avec le +.'),
        ),
        const SizedBox(height: RemboSpace.md),
        RemboTextField(
          fieldKey: const ValueKey('whatsapp-phone'),
          label: tr('Votre numéro WhatsApp'),
          hint: _country.example,
          icon: Icons.phone_iphone_rounded,
          controller: _phone,
          errorText: _error,
          keyboardType: TextInputType.phone,
          helper: linked == null
              ? null
              : tr('Numéro relié : {linked}', {'linked': ltr(linked)}),
        ),
        const SizedBox(height: RemboSpace.lg),
        RemboPrimaryButton(
          key: const ValueKey('whatsapp-save'),
          label: linked == null ? tr('Relier mon numéro') : tr('Mettre à jour'),
          loading: _loading,
          onPressed: _save,
        ),
        if (linked != null) ...[
          const SizedBox(height: RemboSpace.sm),
          if (remboWhatsAppNumber.isNotEmpty)
            RemboSecondaryButton(
              key: const ValueKey('whatsapp-open'),
              label: tr('Ouvrir WhatsApp'),
              icon: Icons.chat_outlined,
              onPressed: () async {
                final ok = await _open('https://wa.me/$remboWhatsAppNumber');
                if (!ok && context.mounted) {
                  showRemboSnackBar(
                    context,
                    tr('WhatsApp n’a pas pu être ouvert.'),
                    tone: MessageTone.error,
                  );
                }
              },
            ),
          Center(
            child: TextButton(
              key: const ValueKey('whatsapp-unlink'),
              onPressed: _loading ? null : () => _save(unlink: true),
              child: Text(tr('Retirer mon numéro')),
            ),
          ),
        ],
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

/// Searchable list of countries; pops the one chosen.
class _CountryList extends StatefulWidget {
  const _CountryList({required this.selected});
  final PhoneCountry selected;

  @override
  State<_CountryList> createState() => _CountryListState();
}

class _CountryListState extends State<_CountryList> {
  String _query = '';

  /// « Algérie » is found by typing « algerie », and any country by its code.
  static String _plain(String text) {
    const from = 'àâäéèêëîïôöùûüç’';
    const to = 'aaaeeeeiioouuuc\'';
    var out = text.toLowerCase();
    for (var i = 0; i < from.length; i++) {
      out = out.replaceAll(from[i], to[i]);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final q = _plain(_query.trim().replaceAll('+', ''));
    final found = [
      for (final c in phoneCountries)
        if (q.isEmpty ||
            _plain(c.name).contains(q) ||
            c.nameAr.contains(q) ||
            c.dial.startsWith(q))
          c,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RemboTextField(
          fieldKey: const ValueKey('country-search'),
          label: tr('Rechercher'),
          hint: tr('Pays ou indicatif'),
          icon: Icons.search_rounded,
          onChanged: (text) => setState(() => _query = text),
        ),
        const SizedBox(height: RemboSpace.sm),
        if (found.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: RemboSpace.lg),
            child: Text(
              tr(
                'Aucun pays trouvé. Fermez et écrivez le numéro complet, avec '
                'le +.',
              ),
              style: RemboText.body.copyWith(color: RemboColors.muted),
            ),
          ),
        for (final c in found)
          ListTile(
            key: ValueKey('country-${c.iso}'),
            contentPadding: EdgeInsets.zero,
            title: Text(c.localName, style: RemboText.body),
            trailing: Text(
              ltr('+${c.dial}'),
              style: RemboText.label.copyWith(color: RemboColors.muted),
            ),
            leading: Icon(
              c.iso == widget.selected.iso
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: c.iso == widget.selected.iso
                  ? RemboColors.indigo
                  : RemboColors.muted,
            ),
            onTap: () => Navigator.of(context).pop(c),
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
