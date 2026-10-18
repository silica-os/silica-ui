import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';

enum _Pos { left, bottom, right }

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'typed values: fallbacks first, then the daemon, then its changes',
    () async {
      final backend = MemorySettingsBackend({'dock.autohide': true});
      final settings = SilicaSettings(backend: backend);
      addTearDown(settings.dispose);
      final autohide = settings.boolean('dock.autohide', fallback: false);
      final size = settings.integer('dock.tileSize', fallback: 60);
      final position = settings.enumeration(
        'dock.position',
        _Pos.values,
        fallback: _Pos.bottom,
      );
      expect(autohide.value, isFalse); // not read yet
      await settings.refresh();
      expect(autohide.value, isTrue);
      expect(size.value, 60);

      var seen = 0;
      size.addListener(() => seen++);
      backend.emit('dock.tileSize', 100);
      expect(size.value, 100);
      expect(seen, 1);
      backend.emit('dock.position', 'left');
      expect(position.value, _Pos.left);
      backend.emit('dock.position', 'top'); // not a name: the fallback
      expect(position.value, _Pos.bottom);
      // A whole number sent as a double is still an integer.
      backend.emit('dock.tileSize', 90.0);
      expect(size.value, 90);
      // Back to the default: the key is gone.
      backend.emit('dock.tileSize', null);
      expect(size.value, 60);
    },
  );

  test('lists, numbers and texts', () async {
    final backend = MemorySettingsBackend({
      'controlcenter.modules': ['wifi:large', 3, 'dnd:small'],
      'screenshot.bar': [10, 20.5],
      'wallpaper.color': '#102030',
      'x': 'not a number',
    });
    final settings = SilicaSettings(backend: backend);
    addTearDown(settings.dispose);
    await settings.refresh();
    expect(settings.texts('controlcenter.modules').value, [
      'wifi:large',
      'dnd:small',
    ]);
    expect(settings.numbers('screenshot.bar').value, [10.0, 20.5]);
    expect(settings.text('wallpaper.color', fallback: '').value, '#102030');
    expect(settings.number('x', fallback: 1.5).value, 1.5);
  });

  test(
    'set shows at once, is sent, and a refusal reads the values again',
    () async {
      final backend = MemorySettingsBackend({'dock.autohide': false});
      final settings = SilicaSettings(backend: backend);
      addTearDown(settings.dispose);
      await settings.refresh();
      final autohide = settings.boolean('dock.autohide', fallback: false);
      final position = settings.enumeration(
        'dock.position',
        _Pos.values,
        fallback: _Pos.bottom,
      );
      expect(await settings.set('dock.autohide', true), isTrue);
      expect(autohide.value, isTrue);
      expect(backend.values['dock.autohide'], true);
      expect(await settings.set('dock.position', _Pos.right), isTrue);
      expect(position.value, _Pos.right);
      expect(backend.values['dock.position'], 'right');

      backend.failure = PlatformException(
        code: 'org.freedesktop.DBus.Error.InvalidArgs',
      );
      expect(await settings.set('dock.autohide', false), isFalse);
      // The daemon still has true: so does the listenable after the read.
      expect(autohide.value, isTrue);

      backend.failure = null;
      expect(await settings.reset('dock.autohide'), isTrue);
      expect(autohide.value, isFalse);
    },
  );

  test(
    'without a daemon the values stay the fallbacks, set lasts in memory',
    () async {
      final settings = SilicaSettings(backend: _Missing());
      addTearDown(settings.dispose);
      final tile = settings.integer('dock.tileSize', fallback: 60);
      await settings.refresh();
      expect(tile.value, 60);
      expect(await settings.set('dock.tileSize', 80), isTrue);
      expect(tile.value, 80);
      expect(await settings.reset('dock.tileSize'), isTrue);
      expect(tile.value, 60);
    },
  );
}

class _Missing implements SilicaSettingsBackend {
  @override
  Future<Map<String, Object?>> getAll() async => throw MissingPluginException();

  @override
  Future<void> setMany(Map<String, Object> values) async =>
      throw MissingPluginException();

  @override
  Future<void> reset(String key) async => throw MissingPluginException();

  @override
  Stream<MapEntry<String, Object?>> get changes => const Stream.empty();
}
