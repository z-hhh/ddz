import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:doudizhu/transport/local_transport.dart';
import 'package:doudizhu/ui/table_controller.dart';
import 'package:doudizhu/game/ai.dart';

class Wire implements LocalTransport {
  final String id;
  final Map<String, Wire> wires;
  final stream = StreamController<Map<String, dynamic>>.broadcast();
  Wire(this.id, this.wires) {
    wires[id] = this;
  }
  @override
  Stream<Map<String, dynamic>> get events => stream.stream;
  @override
  Stream<Map<String, dynamic>> get onMessage =>
      events.where((e) => e['type'] == 'message');
  @override
  Stream<String> get onPeerLeft =>
      events.where((e) => e['type'] == 'left').map((e) => e['peer'] as String);
  @override
  Future<void> createRoom() async {}
  @override
  Future<void> discover() async {}
  @override
  Future<void> join(String id) async {
    stream.add({'type': 'connected', 'peer': id});
    wires[id]!.stream.add({'type': 'connected', 'peer': this.id});
  }

  @override
  Future<void> send(String? peer, Map<String, dynamic> message) async {
    wires[peer]!.stream.add({
      'type': 'message',
      'peer': id,
      'message': message,
    });
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('三人星型：权威校验、隐藏对手手牌、重放拒绝、断线重连与接管', (tester) async {
    final wires = <String, Wire>{};
    final a = Wire('房主', wires), b = Wire('客一', wires), d = Wire('客二', wires);
    final host = TableController(transport: a)..capacity = 3;
    final guest = TableController(transport: b),
        other = TableController(transport: d);
    await host.create();
    await guest.discover();
    await other.discover();
    await guest.join('房主');
    await other.join('房主');
    await tester.pump();
    expect(host.connected.length, 2);
    expect(guest.self, 1);
    expect(other.self, 2);
    host.start();
    await tester.pump();
    expect(guest.hand.length, 17);
    expect((guest.view!['hands'] as List)[0], List.filled(17, -1));
    host.action('bid', value: 0);
    await tester.pump();
    guest.action('bid', value: 3);
    await tester.pump();
    expect(host.game!.landlord, 1);
    expect(guest.hand.length, 20);
    final before = host.revision;
    guest.selected = {999};
    guest.action('play');
    await tester.pump();
    expect(host.revision, before);
    expect(guest.notice, isNotNull);
    guest.selected = choose(guest.hand, guest.target).toSet();
    guest.action('play');
    await tester.pump();
    expect(host.revision, greaterThan(before));
    expect(other.view!['turn'], 2);
    final stale = {
      'kind': 'intent',
      'v': 1,
      'session': host.session,
      'seq': guest.seq,
      'revision': host.revision,
      'action': 'pass',
      'value': 0,
      'cards': <int>[],
    };
    await b.send('房主', stale);
    await tester.pump();
    expect(host.game!.turn, 2);
    a.stream.add({'type': 'left', 'peer': '客一'});
    await tester.pump();
    expect(host.paused, true);
    await guest.join('房主');
    await tester.pump();
    expect(host.paused, false);
    expect(guest.hand.length, host.game!.hands[1].length);
    a.stream.add({'type': 'left', 'peer': '客二'});
    await tester.pump();
    expect(host.paused, true);
    host.takeover();
    expect(host.peers.values.contains(2), false);
    b.stream.add({'type': 'left', 'peer': '房主'});
    await tester.pump();
    expect(guest.hostLost, true);
    host.dispose();
    guest.dispose();
    other.dispose();
    await a.stream.close();
    await b.stream.close();
    await d.stream.close();
  });
  testWidgets('两人模式第三席由 AI 运行，静默掉线30秒暂停', (tester) async {
    final wires = <String, Wire>{};
    final a = Wire('房主', wires), b = Wire('客人', wires);
    final host = TableController(transport: a),
        guest = TableController(transport: b);
    await host.create();
    await guest.discover();
    await guest.join('房主');
    await tester.pump();
    host.start();
    await tester.pump();
    host.action('bid', value: 0);
    await tester.pump();
    guest.action('bid', value: 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    expect(host.game!.phase, 'play');
    expect(host.game!.landlord, 2);
    await tester.pump(const Duration(milliseconds: 1200));
    expect(host.game!.plays[2], 1);
    host.deadlines['客人']!.last = DateTime.now().subtract(
      const Duration(seconds: 31),
    );
    await tester.pump(const Duration(seconds: 5));
    expect(host.paused, true);
    host.dispose();
    guest.dispose();
    await a.stream.close();
    await b.stream.close();
  });
}
