import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' as cg;
import 'package:flutter_test/flutter_test.dart';
import 'package:rembo/core/data/demo_backend.dart';
import 'package:rembo/core/data/encrypted_store.dart';
import 'package:rembo/core/data/local_store.dart';
import 'package:rembo/core/data/models.dart';

cg.SecretKey _key(int seed) => cg.SecretKey(List.filled(32, seed));

void main() {
  group('the data kept on the phone', () {
    test('is encrypted, and read back with its key', () async {
      final files = MemoryStore();
      final store = EncryptedStore(files, _key(1));
      await store.write('{"supplier":"Café Atlas"}');
      final picture = Uint8List.fromList(utf8.encode('receipt picture'));
      await store.writeBlob('r1', picture);

      expect(files.document, isNot(contains('Café Atlas')));
      expect(
        utf8.decode(files.blobs['r1']!, allowMalformed: true),
        isNot(contains('receipt picture')),
      );
      expect(await store.read(), '{"supplier":"Café Atlas"}');
      expect(await store.readBlob('r1'), picture);
    });

    test('cannot be read with another key', () async {
      final files = MemoryStore();
      await EncryptedStore(files, _key(1)).write('{"a":1}');
      await expectLater(
        EncryptedStore(files, _key(2)).read(),
        throwsA(isA<RemboException>()),
      );
    });

    test('written before encryption is read, then encrypted', () async {
      final files = MemoryStore()
        ..document = '{"a":1}'
        ..blobs['r1'] = Uint8List.fromList([1, 2, 3]);
      final store = EncryptedStore(files, _key(1));
      expect(await store.read(), '{"a":1}');
      expect(await store.readBlob('r1'), [1, 2, 3]);
      await store.write('{"a":1}');
      expect(files.document, isNot('{"a":1}'));
      expect(await store.read(), '{"a":1}');
    });
  });

  group('passwords kept on the phone', () {
    test('are hashed with PBKDF2 and checked', () async {
      final files = MemoryStore();
      final b = await LocalBackend.open(EncryptedStore(files, _key(1)));
      await b.signUp(email: 'a@b.ma', password: 'Secret#1', fullName: 'A');
      await b.signOut();
      final saved = await EncryptedStore(files, _key(1)).read();
      expect(saved, contains(r'pbkdf2-sha256$120000$'));
      expect(saved, isNot(contains('Secret#1')));

      final again = await LocalBackend.open(EncryptedStore(files, _key(1)));
      await expectLater(
        again.signIn('a@b.ma', 'Wrong#1'),
        throwsA(isA<RemboException>()),
      );
      expect((await again.signIn('a@b.ma', 'Secret#1')).email, 'a@b.ma');
    });

    test('kept the old way still open the account, and are upgraded', () async {
      // An account saved before PBKDF2: « salt:sha256 » hashed 5 000 times.
      const salt = '0123456789abcdef';
      var digest = sha256.convert(utf8.encode('$salt:Secret#1'));
      for (var i = 0; i < 5000; i++) {
        digest = sha256.convert(digest.bytes);
      }
      final files = MemoryStore()
        ..document = jsonEncode({
          'version': 1,
          'users': [
            {
              'id': 'u-1',
              'email': 'a@b.ma',
              'full_name': 'A',
              'role': 'employee',
              'password': '$salt:$digest',
            },
          ],
        });
      final b = await LocalBackend.open(EncryptedStore(files, _key(1)));
      expect((await b.signIn('a@b.ma', 'Secret#1')).id, 'u-1');
      final saved = await EncryptedStore(files, _key(1)).read();
      expect(saved, contains(r'pbkdf2-sha256$'));
      expect(saved, isNot(contains('$salt:$digest')));
    });
  });
}
