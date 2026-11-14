import 'dart:async';

import 'package:flutter/services.dart';

abstract class LocalTransport {
  Future<void> createRoom();
  Future<void> discover();
  Future<void> join(String id);
  Future<void> send(String? peer, Map<String, dynamic> message);
  Stream<Map<String, dynamic>> get onMessage;
  Stream<String> get onPeerLeft;
  Stream<Map<String, dynamic>> get events;
  Future<void> dispose();
}

class BluetoothTransport implements LocalTransport {
  static const _method = MethodChannel('cn.offline.doudizhu/transport');
  static const _event = EventChannel('cn.offline.doudizhu/events');
  late final Stream<Map<String, dynamic>> _events = _event
      .receiveBroadcastStream()
      .map((e) => Map<String, dynamic>.from(e as Map))
      .asBroadcastStream();
  @override
  Stream<Map<String, dynamic>> get events => _events;
  @override
  Stream<Map<String, dynamic>> get onMessage =>
      _events.where((e) => e['type'] == 'message');
  @override
  Stream<String> get onPeerLeft =>
      _events.where((e) => e['type'] == 'left').map((e) => e['peer'] as String);
  @override
  Future<void> createRoom() async {
    await _method.invokeMethod('createRoom');
  }

  @override
  Future<void> discover() async {
    await _method.invokeMethod('discover');
  }

  @override
  Future<void> join(String id) async {
    await _method.invokeMethod('join', {'id': id});
  }

  @override
  Future<void> send(String? peer, Map<String, dynamic> message) async {
    await _method.invokeMethod('send', {'peer': peer, 'message': message});
  }

  @override
  Future<void> dispose() async {
    await _method.invokeMethod('dispose');
  }
}
