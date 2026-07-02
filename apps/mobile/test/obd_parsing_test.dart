import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/elm327_client.dart';
import 'package:mobile/services/obd2_adapter.dart';

void main() {
  group('Elm327Client.parseDtcs', () {
    test('CAN frame with count byte', () {
      // 43 02 0301 0420 → 2 DTCs: P0301, P0420
      expect(Elm327Client.parseDtcs('430203010420'), ['P0301', 'P0420']);
    });

    test('legacy frame without count byte, zero-padded', () {
      // 43 0301 0420 0000 → P0301, P0420 (padding skipped)
      expect(Elm327Client.parseDtcs('43030104200000'), ['P0301', 'P0420']);
    });

    test('multi-line multi-frame response', () {
      expect(
        Elm327Client.parseDtcs('43030104200000\r43110000000000'),
        ['P0301', 'P0420', 'P1100'],
      );
    });

    test('non-P prefixes decode from top bits', () {
      // 0x4123 → type C, 0xC123 → type U
      expect(Elm327Client.parseDtcs('430241 23C123'), ['C0123', 'U0123']);
    });

    test('hex DTC digits are not decoded as decimal', () {
      // 43 01 0A2F → P0A2F (would be "P2607" with the old decimal decoding)
      expect(Elm327Client.parseDtcs('43010A2F'), ['P0A2F']);
    });

    test('no DTCs stored', () {
      expect(Elm327Client.parseDtcs('4300'), isEmpty);
      expect(Elm327Client.parseDtcs('NO DATA'), isEmpty);
    });
  });

  group('Elm327Client.parsePidBitmap', () {
    test('decodes supported PIDs from 0100 bitmap', () {
      // BE1FA813 = 1011 1110 0001 1111 1010 1000 0001 0011
      final pids = Elm327Client.parsePidBitmap('4100BE1FA813', '0100');
      expect(pids, contains('0C')); // RPM
      expect(pids, contains('0D')); // speed
      expect(pids, contains('05')); // coolant
      expect(pids, isNot(contains('02')));
    });

    test('offsets PIDs for the 0120 range', () {
      // Bit 0 set → PID 0x21
      final pids = Elm327Client.parsePidBitmap('412080000000', '0120');
      expect(pids, contains('21'));
    });

    test('rejects short responses', () {
      expect(Elm327Client.parsePidBitmap('NO DATA', '0100'), isEmpty);
    });
  });

  group('Obd2Adapter.parseResponseBytes', () {
    test('decodes two-byte PID (RPM)', () {
      // 41 0C 23 F0 → rpmX4 = 0x23F0 = 9200 → 2300 RPM
      final bytes = Obd2Adapter.parseResponseBytes('410C23F0', '41', '0C', 4);
      expect(bytes, [0x23, 0xF0]);
      expect((bytes![0] << 8) | bytes[1], 9200);
    });

    test('decodes single-byte PID (speed)', () {
      final bytes = Obd2Adapter.parseResponseBytes('410D30', '41', '0D', 2);
      expect(bytes, [0x30]);
    });

    test('coolant temp offset decoding', () {
      // 41 05 7F → 0x7F - 40 = 87 °C
      final bytes = Obd2Adapter.parseResponseBytes('41057F', '41', '05', 2);
      expect(bytes![0] - 40, 87);
    });

    test('handles responses with residual whitespace', () {
      final bytes = Obd2Adapter.parseResponseBytes('41 0C 23 F0', '41', '0C', 4);
      expect(bytes, [0x23, 0xF0]);
    });

    test('returns null when header missing or data truncated', () {
      expect(Obd2Adapter.parseResponseBytes('NO DATA', '41', '0C', 4), isNull);
      expect(Obd2Adapter.parseResponseBytes('410C23', '41', '0C', 4), isNull);
    });
  });
}
