import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_dut_info/modules/services/boot_gate.dart';

void main() {
  test(
    'empty properties after reboot are not ready; alternative flag is accepted',
    () async {
      var sys = '1';
      var dev = '';
      final gate = BootGate(
        (_, property) async => property == 'sys.boot_completed' ? sys : dev,
      );
      expect(await gate.isReady('dut'), isTrue);
      sys = '';
      expect(await gate.isReady('dut'), isFalse);
      dev = '1';
      expect(await gate.isReady('dut'), isTrue);
    },
  );

  test('delayed boot succeeds after retry', () async {
    var reads = 0;
    final gate = BootGate((_, property) async {
      if (property == 'sys.boot_completed') return ++reads >= 3 ? '1' : '';
      return '';
    });
    expect(
      await gate.wait(
        'dut',
        isCurrent: () => true,
        pollInterval: Duration.zero,
        grace: Duration.zero,
      ),
      isTrue,
    );
    expect(reads, 3);
  });

  test('timeout fails closed and next attempt can recover', () async {
    var ready = false;
    final gate = BootGate((_, _) async => ready ? '1' : '');
    expect(
      await gate.wait(
        'dut',
        isCurrent: () => true,
        timeout: const Duration(milliseconds: 10),
        pollInterval: const Duration(milliseconds: 1),
      ),
      isFalse,
    );
    ready = true;
    expect(
      await gate.wait('dut', isCurrent: () => true, grace: Duration.zero),
      isTrue,
    );
  });

  test('hung property read cannot defeat deadline', () async {
    final response = Completer<String>();
    final gate = BootGate((_, _) => response.future);
    expect(
      await gate.wait(
        'dut',
        isCurrent: () => true,
        timeout: const Duration(milliseconds: 10),
      ),
      isFalse,
    );
    response.complete('1');
  });

  test('stop or superseded session rejects late boot response', () async {
    final response = Completer<String>();
    var current = true;
    final gate = BootGate((_, _) => response.future);
    final result = gate.wait(
      'dut',
      isCurrent: () => current,
      grace: Duration.zero,
    );
    current = false;
    response.complete('1');
    expect(await result, isFalse);
  });

  test('stop during grace period prevents starting acquisition', () async {
    var current = true;
    final gate = BootGate((_, _) async => '1');
    final result = gate.wait(
      'dut',
      isCurrent: () => current,
      grace: const Duration(milliseconds: 10),
    );
    await Future<void>.delayed(Duration.zero);
    current = false;
    expect(await result, isFalse);
  });
}
