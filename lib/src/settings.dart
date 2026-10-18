// The client of silica-daemon's Settings service (`dev.frascella.Silica.Settings1`, schema in
// silica-desktop's `crates/daemon/src/settings.rs`): one typed value per key, live.
//
//   final autohide = SilicaSettings.instance.boolean('dock.autohide', fallback: false);
//   ValueListenableBuilder<bool>(valueListenable: autohide, builder: ...);
//   SilicaSettings.instance.set('dock.autohide', true);
//
// Every key has one [ValueListenable]: it holds the fallback until the first read, then the
// daemon's value, and follows the `Changed` signal. A [set] shows at once and is sent; if the
// daemon refuses it the values are read again. Outside Silica (no daemon, tests) the values
// stay the fallbacks, or what [set] was given. Tests use [MemorySettingsBackend].

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'dbus.dart';

/// Where the settings come from: the daemon, or memory (tests).
abstract class SilicaSettingsBackend {
  /// Every key with its value.
  Future<Map<String, Object?>> getAll();

  /// Sets keys, all or none. Throws if the daemon refuses.
  Future<void> setMany(Map<String, Object> values);

  /// Back to the default of [key].
  Future<void> reset(String key);

  /// A key took a new value (the default too, after [reset]). Errors end the stream.
  Stream<MapEntry<String, Object?>> get changes;
}

/// The daemon's service over [SilicaDBus].
class DBusSettingsBackend implements SilicaSettingsBackend {
  DBusSettingsBackend([SilicaDBus? bus]) : _bus = bus ?? SilicaDBus.instance;

  final SilicaDBus _bus;

  static const String name = 'dev.frascella.Silica';
  static const String path = '/dev/frascella/Silica/Settings1';
  static const String interface = 'dev.frascella.Silica.Settings1';

  @override
  Future<Map<String, Object?>> getAll() async {
    final reply = await _bus.call(
      destination: name,
      path: path,
      interface: interface,
      method: 'GetAll',
    );
    final first = reply.isEmpty ? null : reply.first;
    return first is Map ? first.cast<String, Object?>() : const {};
  }

  @override
  Future<void> setMany(Map<String, Object> values) async {
    if (values.length == 1) {
      final entry = values.entries.first;
      await _bus.call(
        destination: name,
        path: path,
        interface: interface,
        method: 'Set',
        signature: 'sv',
        args: [entry.key, entry.value],
      );
      return;
    }
    await _bus.call(
      destination: name,
      path: path,
      interface: interface,
      method: 'SetMany',
      signature: 'a{sv}',
      args: [values],
    );
  }

  @override
  Future<void> reset(String key) => _bus.call(
    destination: name,
    path: path,
    interface: interface,
    method: 'Reset',
    signature: 's',
    args: [key],
  );

  @override
  Stream<MapEntry<String, Object?>> get changes => _bus
      .signals(
        sender: name,
        path: path,
        interface: interface,
        member: 'Changed',
      )
      .where((s) => s.args.length >= 2 && s.args.first is String)
      .map((s) => MapEntry(s.args.first! as String, s.args[1]));
}

/// A store in memory with the same behaviour as the daemon, minus the schema: for tests and
/// for apps run outside Silica. [emit] plays a change made by someone else.
class MemorySettingsBackend implements SilicaSettingsBackend {
  MemorySettingsBackend([Map<String, Object?> values = const {}])
    : values = {...values};

  /// The current values.
  final Map<String, Object?> values;

  /// Keys given to [setMany] or [reset], in order.
  final List<String> writes = [];

  /// When set, [setMany] throws it (a refusal of the daemon).
  Object? failure;

  final StreamController<MapEntry<String, Object?>> _changes =
      StreamController<MapEntry<String, Object?>>.broadcast(sync: true);

  @override
  Future<Map<String, Object?>> getAll() async => {...values};

  @override
  Future<void> setMany(Map<String, Object> next) async {
    final error = failure;
    if (error != null) throw error;
    for (final entry in next.entries) {
      writes.add(entry.key);
      if (values[entry.key] == entry.value) continue;
      values[entry.key] = entry.value;
      _changes.add(MapEntry(entry.key, entry.value));
    }
  }

  @override
  Future<void> reset(String key) async {
    writes.add(key);
    if (values.remove(key) != null) _changes.add(MapEntry(key, null));
  }

  @override
  Stream<MapEntry<String, Object?>> get changes => _changes.stream;

  /// A change made by another client.
  void emit(String key, Object? value) {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
    _changes.add(MapEntry(key, value));
  }
}

/// The settings of the system, one [ValueListenable] per key.
class SilicaSettings {
  SilicaSettings({SilicaSettingsBackend? backend})
    : _backend = backend ?? DBusSettingsBackend() {
    unawaited(refresh());
    _subscribe();
  }

  /// Settings in memory that already hold [values] (tests): no read is needed.
  @visibleForTesting
  factory SilicaSettings.withValues(Map<String, Object?> values) =>
      SilicaSettings(backend: MemorySettingsBackend(values))
        .._raw.addAll({
          for (final e in values.entries)
            if (e.value != null) e.key: e.value,
        });

  /// The shared instance, on the daemon.
  static SilicaSettings instance = SilicaSettings();

  /// Replaces [instance] (tests) and returns the new one.
  @visibleForTesting
  static SilicaSettings useBackend(SilicaSettingsBackend backend) =>
      instance = SilicaSettings(backend: backend);

  final SilicaSettingsBackend _backend;
  final Map<String, ValueNotifier<Object?>> _notifiers = {};
  final Map<String, Object?> _raw = {};
  StreamSubscription<MapEntry<String, Object?>>? _sub;
  bool _disposed = false;

  void _subscribe() {
    _sub = _backend.changes.listen(
      (change) => _take(change.key, change.value),
      onError: (Object _) {
        // Outside Silica there are no signals: the values stay as they are.
      },
    );
  }

  /// Reads every value again (at the start, after the daemon appeared, after a refusal).
  Future<void> refresh() async {
    try {
      final all = await _backend.getAll();
      if (_disposed) return;
      for (final entry in all.entries) {
        _take(entry.key, entry.value);
      }
    } on MissingPluginException {
      // Outside Silica: the fallbacks.
    } on PlatformException {
      // No daemon (yet).
    }
  }

  void _take(String key, Object? value) {
    if (_disposed) return;
    final before = _raw[key];
    if (value == null) {
      _raw.remove(key);
    } else {
      _raw[key] = value;
    }
    _notifiers[key]?.value = value;
    if (!_sameValue(before, value)) {
      for (final p in List.of(_prefixes)) {
        if (key.startsWith(p.prefix)) p.fire();
      }
    }
  }

  final List<_PrefixListenable> _prefixes = [];

  static bool _sameValue(Object? a, Object? b) =>
      a == b || (a is List && b is List && listEquals(a, b));

  /// The raw value of [key], as the daemon sent it; null before it is known.
  Object? raw(String key) => _raw[key];

  ValueListenable<T> _listen<T>(String key, T Function(Object? raw) convert) {
    final source = _notifiers.putIfAbsent(
      key,
      () => ValueNotifier<Object?>(_raw[key]),
    );
    return _Converted<T>(source, convert);
  }

  /// A yes/no key.
  ValueListenable<bool> boolean(String key, {required bool fallback}) =>
      _listen(key, (v) => v is bool ? v : fallback);

  /// A whole number key.
  ValueListenable<int> integer(String key, {required int fallback}) =>
      _listen(key, (v) => v is num && v.isFinite ? v.round() : fallback);

  /// A number key.
  ValueListenable<double> number(String key, {required double fallback}) =>
      _listen(key, (v) => v is num && v.isFinite ? v.toDouble() : fallback);

  /// A text key.
  ValueListenable<String> text(String key, {required String fallback}) =>
      _listen(key, (v) => v is String ? v : fallback);

  /// A text key whose values are the names of [values].
  ValueListenable<E> enumeration<E extends Enum>(
    String key,
    List<E> values, {
    required E fallback,
  }) => _listen(
    key,
    (v) => values.where((e) => e.name == v).firstOrNull ?? fallback,
  );

  /// A list of texts.
  ValueListenable<List<String>> texts(String key) => _listen(
    key,
    (v) => v is List
        ? [
            for (final e in v)
              if (e is String) e,
          ]
        : const [],
  );

  /// A list of numbers.
  ValueListenable<List<double>> numbers(String key) => _listen(
    key,
    (v) => v is List
        ? [
            for (final e in v)
              if (e is num) e.toDouble(),
          ]
        : const [],
  );

  /// The raw values of the keys that start with [prefix] (keys that are set to something other
  /// than the default, and the static keys read so far), for families of keys such as
  /// `notifications.apps.<app>.*`.
  Map<String, Object?> withPrefix(String prefix) => {
    for (final e in _raw.entries)
      if (e.key.startsWith(prefix)) e.key: e.value,
  };

  /// A listenable that fires when any key starting with [prefix] changes, now or later.
  Listenable watchPrefix(String prefix) => _PrefixListenable(this, prefix);

  /// A listenable that fires when any of [keys] changes.
  Listenable watch(Iterable<String> keys) => Listenable.merge([
    for (final key in keys)
      _notifiers.putIfAbsent(key, () => ValueNotifier<Object?>(_raw[key])),
  ]);

  /// The current value of a key, without listening (for code that already listens to
  /// [watch]).
  bool getBool(String key, {required bool fallback}) {
    final v = _raw[key];
    return v is bool ? v : fallback;
  }

  int getInt(String key, {required int fallback}) {
    final v = _raw[key];
    return v is num && v.isFinite ? v.round() : fallback;
  }

  double getNumber(String key, {required double fallback}) {
    final v = _raw[key];
    return v is num && v.isFinite ? v.toDouble() : fallback;
  }

  String getText(String key, {required String fallback}) {
    final v = _raw[key];
    return v is String ? v : fallback;
  }

  E getEnum<E extends Enum>(
    String key,
    List<E> values, {
    required E fallback,
  }) => values.where((e) => e.name == _raw[key]).firstOrNull ?? fallback;

  List<String> getTexts(String key) {
    final v = _raw[key];
    return v is List
        ? [
            for (final e in v)
              if (e is String) e,
          ]
        : const [];
  }

  List<double> getNumbers(String key) {
    final v = _raw[key];
    return v is List
        ? [
            for (final e in v)
              if (e is num) e.toDouble(),
          ]
        : const [];
  }

  /// Sets [key] to [value] (`bool`, `int`, `double`, `String`, `List<String>` or
  /// `List<double>`; an enum by its name). Shown at once; sent to the daemon. Returns false
  /// when the daemon refused it (the values are then read again).
  Future<bool> set(String key, Object value) => setMany({key: value});

  /// Sets several keys at once: all or none.
  Future<bool> setMany(Map<String, Object> values) async {
    final sent = {
      for (final e in values.entries)
        e.key: e.value is Enum ? (e.value as Enum).name : e.value,
    };
    for (final e in sent.entries) {
      _take(e.key, e.value);
    }
    try {
      await _backend.setMany(sent);
      return true;
    } on MissingPluginException {
      // Outside Silica: the value lasts in memory.
      return true;
    } on PlatformException {
      await refresh();
      return false;
    }
  }

  /// Back to the default of [key].
  Future<bool> reset(String key) async {
    try {
      await _backend.reset(key);
      return true;
    } on MissingPluginException {
      _take(key, null);
      return true;
    } on PlatformException {
      return false;
    }
  }

  /// Stops following the daemon (tests).
  @visibleForTesting
  void dispose() {
    _disposed = true;
    unawaited(_sub?.cancel());
    for (final n in _notifiers.values) {
      n.dispose();
    }
    _notifiers.clear();
  }
}

/// A view of a notifier through a conversion; listeners are added to the source only while
/// someone listens.
class _Converted<T> extends ValueListenable<T> {
  _Converted(this._source, this._convert);

  final ValueListenable<Object?> _source;
  final T Function(Object? raw) _convert;

  @override
  T get value => _convert(_source.value);

  @override
  void addListener(VoidCallback listener) => _source.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _source.removeListener(listener);
}

/// Fires when a key with the prefix changes (see [SilicaSettings.watchPrefix]).
class _PrefixListenable extends ChangeNotifier {
  _PrefixListenable(this._settings, this.prefix);

  final SilicaSettings _settings;
  final String prefix;
  bool _attached = false;

  void fire() => notifyListeners();

  @override
  void addListener(VoidCallback listener) {
    if (!_attached) {
      _attached = true;
      _settings._prefixes.add(this);
    }
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners && _attached) {
      _attached = false;
      _settings._prefixes.remove(this);
    }
  }
}
