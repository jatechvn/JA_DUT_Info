import 'dart:async';
import 'dart:io';

class CommandCancelled implements Exception {
  @override
  String toString() => 'DUT read cancelled';
}

/// Tracks only processes started by this DUT session, never the ADB server.
class CommandScope {
  static final Object _key = Object();
  static CommandScope? get current => Zone.current[_key] as CommandScope?;
  final _processes = <Process>{};
  final _callbacks = <void Function()>{};
  bool cancelled = false;

  T run<T>(T Function() body) => runZoned(body, zoneValues: {_key: this});
  void check() {
    if (cancelled) throw CommandCancelled();
  }

  void attach(Process process) {
    if (cancelled) {
      process.kill();
    } else {
      _processes.add(process);
    }
  }

  void detach(Process process) => _processes.remove(process);
  void onCancel(void Function() callback) {
    if (cancelled) {
      callback();
    } else {
      _callbacks.add(callback);
    }
  }

  void removeCallback(void Function() callback) => _callbacks.remove(callback);
  void cancel() {
    if (cancelled) return;
    cancelled = true;
    for (final process in _processes.toList()) {
      process.kill();
    }
    for (final callback in _callbacks.toList()) {
      callback();
    }
    _processes.clear();
    _callbacks.clear();
  }
}
