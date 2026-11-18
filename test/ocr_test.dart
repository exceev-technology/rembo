import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rembo/core/ocr/device_reader_io.dart';
import 'package:rembo/core/data/models.dart';
import 'package:rembo/core/ocr/receipt_parser.dart';
import 'package:rembo/core/ocr/receipt_reader.dart';

final _today = DateTime(2026, 11, 12);

void main() {
  test('a restaurant ticket: supplier, date, total, VAT and ICE', () {
    final r = parseReceiptText([
      'CAFE ATLAS',
      '12 Bd Zerktouni, Casablanca',
      'Tél : 05 22 12 34 56',
      'ICE : 001234567000089',
      'Ticket N° 4521   Table 7',
      'Date : 10/11/2026 13:42',
      '2 Tajine poulet      160,00',
      '1 Eau minérale        20,00',
      '2 Thé à la menthe     60,00',
      'TOTAL HT             218,18',
      'TVA 10%               21,82',
      'TOTAL TTC            240,00',
      'Espèces              300,00',
      'Rendu                 60,00',
      'Merci de votre visite',
    ], today: _today);
    expect(r.unreadable, isFalse);
    expect(r.supplier, 'Cafe Atlas');
    expect(r.supplierIce, '001234567000089');
    expect(r.date, DateTime(2026, 11, 10));
    expect(r.amountCents, 24000);
    expect(r.vatCents, 2182);
  });

  test(
    'base and tax on the same line: the tax is the one matching the rate',
    () {
      final r = parseReceiptText([
        'Bureau Plus SARL',
        'Facture du 08.11.26',
        'Ramette A4 x5   300,00',
        'TVA 20,00%  300,00  60,00',
        'Net à payer  360,00 DH',
      ], today: _today);
      expect(r.amountCents, 36000);
      expect(r.vatCents, 6000);
      expect(r.date, DateTime(2026, 11, 8));
      expect(r.supplier, 'Bureau Plus SARL');
    },
  );

  test('thousands, a label alone on its line, a written date', () {
    final r = parseReceiptText([
      'HOTEL MOGADOR',
      'Le 3 novembre 2026',
      'Nuitée x2',
      'TOTAL TTC',
      '1 200,00',
    ], today: _today);
    expect(r.amountCents, 120000);
    expect(r.date, DateTime(2026, 11, 3));
    expect(r.vatCents, isNull, reason: 'no VAT printed: none proposed');
  });

  test('no label: the largest amount, but not the money handed over', () {
    final r = parseReceiptText([
      'Petit Taxi',
      '12/11/2026',
      'Course   45,00',
      'Espèces  50,00',
      'Rendu     5,00',
    ], today: _today);
    expect(r.amountCents, 4500);
  });

  test('a date in the future or impossible is not proposed', () {
    final r = parseReceiptText([
      'Librairie Al Wifaq',
      'Date 31/02/2026',
      'Valable jusqu\'au 01/01/2027',
      'Total 80,00',
    ], today: _today);
    expect(r.date, isNull);
    expect(r.amountCents, 8000);
  });

  test('quantities, phone numbers and percentages are not amounts', () {
    final r = parseReceiptText([
      'Pharmacie Centrale',
      'Tel 0522123456',
      '3 x Doliprane 1000',
      'TVA 7%',
      'Total 54,60',
    ], today: _today);
    expect(r.amountCents, 5460);
    expect(r.vatCents, isNull);
  });

  test('nothing legible is reported as unreadable', () {
    expect(parseReceiptText([]).unreadable, isTrue);
    expect(parseReceiptText(['~~', '1 2', '#']).unreadable, isTrue);
    expect(
      parseReceiptText(['Bonjour et bienvenue chez nous']).unreadable,
      isTrue,
      reason: 'text without amount nor date is not a receipt we can use',
    );
  });

  test('pieces printed at the same height are read as one row', () {
    final rows = rowsOf([
      (text: '240,00', left: 300, top: 101, bottom: 119),
      (text: 'CAFE ATLAS', left: 20, top: 10, bottom: 30),
      (text: 'TOTAL TTC', left: 20, top: 100, bottom: 120),
      (text: 'TVA 10%', left: 20, top: 70, bottom: 88),
      (text: '21,82', left: 300, top: 72, bottom: 90),
    ]);
    expect(rows, ['CAFE ATLAS', 'TVA 10% 21,82', 'TOTAL TTC 240,00']);
    final r = parseReceiptText([...rows, '10/11/2026'], today: _today);
    expect(r.amountCents, 24000);
    expect(r.vatCents, 2182);
  });

  group('phone first, server only when needed', () {
    final bytes = Uint8List(0);
    const full = ReceiptReading(supplier: 'Café Atlas', amountCents: 24000);
    const partial = ReceiptReading(amountCents: 24000);
    const arabic = ReceiptReading(supplier: 'مقهى الأطلس', amountCents: 24000);
    ReceiptReader gives(ReceiptReading? r, [List<String>? calls]) =>
        (_, _) async {
          calls?.add('called');
          return r;
        };

    test('a complete reading on the phone never calls the server', () async {
      final calls = <String>[];
      final r = await readReceipt(
        bytes,
        't.jpg',
        onDevice: gives(full),
        onServer: gives(arabic, calls),
      );
      expect(r, same(full));
      expect(calls, isEmpty);
    });

    test(
      'an incomplete or unreadable one is completed by the server',
      () async {
        for (final local in [partial, const ReceiptReading(unreadable: true)]) {
          final r = await readReceipt(
            bytes,
            't.jpg',
            onDevice: gives(local),
            onServer: gives(arabic),
          );
          expect(r, same(arabic));
        }
      },
    );

    test('without a server reader, what the phone read is kept', () async {
      final r = await readReceipt(
        bytes,
        't.jpg',
        onDevice: gives(partial),
        onServer: gives(null),
      );
      expect(r, same(partial));
    });

    test(
      'a server that reads nothing does not erase a partial reading',
      () async {
        final r = await readReceipt(
          bytes,
          't.jpg',
          onDevice: gives(partial),
          onServer: gives(const ReceiptReading(unreadable: true)),
        );
        expect(r, same(partial));
      },
    );

    test('no reader on the device: the server alone', () async {
      final r = await readReceipt(
        bytes,
        't.jpg',
        onDevice: null,
        onServer: gives(arabic),
      );
      expect(r, same(arabic));
    });
  });
}
