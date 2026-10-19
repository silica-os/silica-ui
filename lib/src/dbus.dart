// The embedder's silica/dbus channel, shared by the library, the apps and the shell: one handler
// for the channel (a channel has only one), so every listener gets its signals. D-Bus calls and signals with JSON values
// (crates/embedder/src/dbus). Values go with the argument signature; replies arrive as
// argument lists (structs as lists, dictionaries as maps).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A D-Bus bus.
enum SilicaDBusBus { session, system }

/// A received signal.
@immutable
class SilicaDBusSignal {
  const SilicaDBusSignal({
    required this.sender,
    required this.path,
    required this.interface,
    required this.member,
    required this.args,
  });

  final String sender;
  final String path;
  final String interface;
  final String member;
  final List<Object?> args;
}

class SilicaDBus {
  SilicaDBus._() {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'signal') _dispatch(call.arguments);
      return null;
    });
  }

  static final SilicaDBus instance = SilicaDBus._();

  static const MethodChannel channel = MethodChannel(
    'silica/dbus',
    JSONMethodCodec(),
  );

  final Map<int, StreamController<SilicaDBusSignal>> _subscriptions = {};

  /// Calls a method; returns the reply arguments. A D-Bus error is a
  /// [PlatformException] with the error name as `code`.
  Future<List<Object?>> call({
    SilicaDBusBus bus = SilicaDBusBus.session,
    required String destination,
    required String path,
    String? interface,
    required String method,
    String signature = '',
    List<Object?> args = const [],
  }) async {
    final reply = await channel.invokeMethod<List<Object?>>('call', {
      'bus': bus.name,
      'destination': destination,
      'path': path,
      'interface': ?interface,
      'method': method,
      'signature': signature,
      'args': args,
    });
    return reply ?? const [];
  }

  /// A property (`org.freedesktop.DBus.Properties.Get`).
  Future<Object?> getProperty({
    SilicaDBusBus bus = SilicaDBusBus.session,
    required String destination,
    required String path,
    required String interface,
    required String name,
  }) async {
    final reply = await call(
      bus: bus,
      destination: destination,
      path: path,
      interface: 'org.freedesktop.DBus.Properties',
      method: 'Get',
      signature: 'ss',
      args: [interface, name],
    );
    return reply.isEmpty ? null : reply.first;
  }

  /// All properties of an interface (`org.freedesktop.DBus.Properties.GetAll`).
  Future<Map<String, Object?>> getAll({
    SilicaDBusBus bus = SilicaDBusBus.session,
    required String destination,
    required String path,
    required String interface,
  }) async {
    final reply = await call(
      bus: bus,
      destination: destination,
      path: path,
      interface: 'org.freedesktop.DBus.Properties',
      method: 'GetAll',
      signature: 's',
      args: [interface],
    );
    final first = reply.isEmpty ? null : reply.first;
    return first is Map ? first.cast<String, Object?>() : const {};
  }

  /// The signals matching the filters. The bus match is removed when the last
  /// listener cancels its stream subscription.
  Stream<SilicaDBusSignal> signals({
    SilicaDBusBus bus = SilicaDBusBus.session,
    String? sender,
    String? path,
    String? interface,
    String? member,
  }) {
    int? id;
    late final StreamController<SilicaDBusSignal> controller;
    controller = StreamController<SilicaDBusSignal>(
      onListen: () async {
        try {
          id = await channel.invokeMethod<int>('subscribe', {
            'bus': bus.name,
            'sender': ?sender,
            'path': ?path,
            'interface': ?interface,
            'member': ?member,
          });
        } on PlatformException catch (error, stack) {
          controller.addError(error, stack);
          await controller.close();
          return;
        } on MissingPluginException catch (error, stack) {
          // Outside Silica (tests, another embedder): no signals.
          controller.addError(error, stack);
          await controller.close();
          return;
        } on TypeError catch (error, stack) {
          // A handler that answers something else than a subscription id (a test's mock of
          // the channel written for calls only): no signals either.
          controller.addError(error, stack);
          await controller.close();
          return;
        }
        final subscribed = id;
        if (subscribed == null) return;
        if (controller.isClosed) {
          await channel.invokeMethod<bool>('unsubscribe', {'id': subscribed});
          return;
        }
        _subscriptions[subscribed] = controller;
      },
      onCancel: () async {
        final subscribed = id;
        if (subscribed == null) return;
        _subscriptions.remove(subscribed);
        try {
          await channel.invokeMethod<bool>('unsubscribe', {'id': subscribed});
        } on PlatformException {
          // The match is already removed.
        }
      },
    );
    return controller.stream;
  }

  void _dispatch(Object? arguments) {
    if (arguments is! Map) return;
    final id = arguments['id'];
    final controller = id is int ? _subscriptions[id] : null;
    if (controller == null || controller.isClosed) return;
    final args = arguments['args'];
    controller.add(
      SilicaDBusSignal(
        sender: '${arguments['sender'] ?? ''}',
        path: '${arguments['path'] ?? ''}',
        interface: '${arguments['interface'] ?? ''}',
        member: '${arguments['member'] ?? ''}',
        args: args is List ? args : const [],
      ),
    );
  }
}
