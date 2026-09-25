import 'dart:async';

class BootGate {
  BootGate(this.readProperty);

  final Future<String> Function(String serial, String property) readProperty;

  Future<bool> isReady(String serial) async {
    if ((await readProperty(serial, 'sys.boot_completed')).trim() == '1') {
      return true;
    }
    return (await readProperty(serial, 'dev.bootcomplete')).trim() == '1';
  }

  Future<bool> wait(
    String serial, {
    required bool Function() isCurrent,
    Duration timeout = const Duration(seconds: 60),
    Duration pollInterval = const Duration(seconds: 1),
    Duration grace = const Duration(milliseconds: 1500),
  }) async {
    final clock = Stopwatch()..start();
    while (isCurrent() && clock.elapsed < timeout) {
      final remaining = timeout - clock.elapsed;
      bool ready;
      try {
        ready = await isReady(serial).timeout(remaining);
      } catch (_) {
        ready = false;
      }
      if (!isCurrent()) return false;
      if (ready) {
        await Future<void>.delayed(grace);
        return isCurrent();
      }
      final left = timeout - clock.elapsed;
      if (left <= Duration.zero) return false;
      await Future<void>.delayed(left < pollInterval ? left : pollInterval);
    }
    return false;
  }
}
