import 'package:flutter_test/flutter_test.dart';
import 'package:rembo/core/data/supabase_backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('a receipt refused by the storage rules', () {
    test('a 403 is a locked receipt', () {
      expect(
        isLockedReceipt(
          const StorageException('Unauthorized', statusCode: '403'),
        ),
        isTrue,
      );
    });

    test('a row level security message is a locked receipt', () {
      expect(
        isLockedReceipt(
          const StorageException(
            'new row violates row-level security policy',
            statusCode: '400',
          ),
        ),
        isTrue,
      );
    });

    test('other storage failures are not', () {
      expect(
        isLockedReceipt(
          const StorageException('Payload too large', statusCode: '413'),
        ),
        isFalse,
      );
      expect(isLockedReceipt(const StorageException('timeout')), isFalse);
    });
  });
}
