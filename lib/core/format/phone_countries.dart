import '../l10n/l10n.dart';

/// A country offered when linking a WhatsApp number.
class PhoneCountry {
  const PhoneCountry(
    this.iso,
    this.name,
    this.nameAr,
    this.dial,
    this.minDigits,
    this.maxDigits,
    this.example, {
    this.trunkZero = false,
    this.first,
  });

  /// ISO 3166 code, used as a stable key.
  final String iso;
  final String name;
  final String nameAr;

  /// Name in the language of the app.
  String get localName => isArabic ? nameAr : name;

  /// Calling code without the plus sign: « 212 ».
  final String dial;

  /// Length of the number once the calling code and trunk zero are removed.
  final int minDigits;
  final int maxDigits;

  /// A number as people of that country write it.
  final String example;

  /// True when people write a leading 0 that disappears abroad (06… → +212 6…).
  final bool trunkZero;

  /// Allowed first digits of the national number, when the country has a rule.
  final String? first;

  /// National number (no calling code) → +dial…, or null when it cannot be one.
  String? toInternational(String digits) {
    if (!RegExp(r'^\d+$').hasMatch(digits)) return null;
    var national = digits;
    if (trunkZero && national.startsWith('0')) national = national.substring(1);
    if (national.length < minDigits || national.length > maxDigits) return null;
    if (first != null && !first!.contains(national[0])) return null;
    return '+$dial$national';
  }

  /// +dial… → the number as written in the country.
  String toNational(String international) {
    final national = international.substring(dial.length + 1);
    return trunkZero ? '0$national' : national;
  }
}

const morocco = PhoneCountry(
  'MA',
  'Maroc',
  'المغرب',
  '212',
  9,
  9,
  '06 12 34 56 78',
  trunkZero: true,
  first: '567',
);

/// Morocco first, then by region. Any other country: type the number with +.
const phoneCountries = <PhoneCountry>[
  morocco,
  PhoneCountry(
    'DZ',
    'Algérie',
    'الجزائر',
    '213',
    9,
    9,
    '0551 23 45 67',
    trunkZero: true,
  ),
  PhoneCountry('TN', 'Tunisie', 'تونس', '216', 8, 8, '20 123 456'),
  PhoneCountry(
    'LY',
    'Libye',
    'ليبيا',
    '218',
    9,
    9,
    '091 234 5678',
    trunkZero: true,
  ),
  PhoneCountry(
    'EG',
    'Égypte',
    'مصر',
    '20',
    10,
    10,
    '0100 123 4567',
    trunkZero: true,
  ),
  PhoneCountry('MR', 'Mauritanie', 'موريتانيا', '222', 8, 8, '22 12 34 56'),
  PhoneCountry('SN', 'Sénégal', 'السنغال', '221', 9, 9, '77 123 45 67'),
  PhoneCountry(
    'CI',
    'Côte d’Ivoire',
    'ساحل العاج',
    '225',
    10,
    10,
    '07 12 34 56 78',
  ),
  PhoneCountry('ML', 'Mali', 'مالي', '223', 8, 8, '65 12 34 56'),
  PhoneCountry(
    'BF',
    'Burkina Faso',
    'بوركينا فاسو',
    '226',
    8,
    8,
    '70 12 34 56',
  ),
  PhoneCountry('NE', 'Niger', 'النيجر', '227', 8, 8, '93 12 34 56'),
  PhoneCountry('TG', 'Togo', 'توغو', '228', 8, 8, '90 12 34 56'),
  PhoneCountry('BJ', 'Bénin', 'بنين', '229', 8, 10, '01 97 12 34 56'),
  PhoneCountry('CM', 'Cameroun', 'الكاميرون', '237', 9, 9, '6 71 23 45 67'),
  PhoneCountry(
    'GH',
    'Ghana',
    'غانا',
    '233',
    9,
    9,
    '024 123 4567',
    trunkZero: true,
  ),
  PhoneCountry(
    'NG',
    'Nigeria',
    'نيجيريا',
    '234',
    10,
    10,
    '0803 123 4567',
    trunkZero: true,
  ),
  PhoneCountry(
    'FR',
    'France',
    'فرنسا',
    '33',
    9,
    9,
    '06 12 34 56 78',
    trunkZero: true,
  ),
  PhoneCountry(
    'BE',
    'Belgique',
    'بلجيكا',
    '32',
    8,
    9,
    '0470 12 34 56',
    trunkZero: true,
  ),
  PhoneCountry(
    'CH',
    'Suisse',
    'سويسرا',
    '41',
    9,
    9,
    '078 123 45 67',
    trunkZero: true,
  ),
  PhoneCountry('ES', 'Espagne', 'إسبانيا', '34', 9, 9, '612 34 56 78'),
  PhoneCountry('PT', 'Portugal', 'البرتغال', '351', 9, 9, '912 345 678'),
  PhoneCountry('IT', 'Italie', 'إيطاليا', '39', 9, 10, '312 345 6789'),
  PhoneCountry(
    'DE',
    'Allemagne',
    'ألمانيا',
    '49',
    10,
    11,
    '0151 23456789',
    trunkZero: true,
  ),
  PhoneCountry(
    'NL',
    'Pays-Bas',
    'هولندا',
    '31',
    9,
    9,
    '06 12345678',
    trunkZero: true,
  ),
  PhoneCountry(
    'GB',
    'Royaume-Uni',
    'المملكة المتحدة',
    '44',
    10,
    10,
    '07400 123456',
    trunkZero: true,
  ),
  PhoneCountry(
    'US',
    'États-Unis / Canada',
    'الولايات المتحدة / كندا',
    '1',
    10,
    10,
    '202 555 0123',
  ),
  PhoneCountry(
    'TR',
    'Turquie',
    'تركيا',
    '90',
    10,
    10,
    '0501 234 56 78',
    trunkZero: true,
  ),
  PhoneCountry(
    'SA',
    'Arabie saoudite',
    'السعودية',
    '966',
    9,
    9,
    '050 123 4567',
    trunkZero: true,
  ),
  PhoneCountry(
    'AE',
    'Émirats arabes unis',
    'الإمارات',
    '971',
    9,
    9,
    '050 123 4567',
    trunkZero: true,
  ),
  PhoneCountry('QA', 'Qatar', 'قطر', '974', 8, 8, '3312 3456'),
  PhoneCountry('KW', 'Koweït', 'الكويت', '965', 8, 8, '500 12345'),
];

/// The listed country a +… number belongs to (longest calling code wins).
PhoneCountry? countryOf(String international) {
  PhoneCountry? best;
  for (final c in phoneCountries) {
    if (international.startsWith('+${c.dial}') &&
        (best == null || c.dial.length > best.dial.length)) {
      best = c;
    }
  }
  return best;
}
