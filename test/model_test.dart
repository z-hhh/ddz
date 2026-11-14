import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:doudizhu/audio/game_audio.dart';
import 'package:doudizhu/game/game_state.dart';
import 'package:doudizhu/model/douzero.dart';
import 'package:doudizhu/model/game_observation.dart';
import 'package:doudizhu/model/master_worker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('完整三角色LSTM/MLP与PyTorch的36个输出一致', () {
    final models = {
      for (final r in ['landlord', 'landlord_down', 'landlord_up'])
        r: DouZeroNetwork(File('assets/models/$r.dzf').readAsBytesSync()),
    };
    for (final row in jsonDecode(
      File('tool/model/reference.json').readAsStringSync(),
    ) as List) {
      expect(
        models[row['role']]!.forward(
          List<double>.from(row['z'] as List),
          List<double>.from(row['x'] as List),
        ),
        closeTo(row['value'] as num, 1e-4),
      );
    }
  });
  test('大师特征不读取对手底牌身份；动作记录跨清台保留', () {
    final g = GameState();
    g.act(0, 'bid', value: 3);
    final before = gameObservation(g, 0);
    final temp = g.hands[1][0];
    g.hands[1][0] = g.hands[2][0];
    g.hands[2][0] = temp;
    final after = gameObservation(g, 0);
    expect(after.state, before.state);
    expect(after.history, before.history);
    final card = g.hands[0].first;
    g.act(0, 'play', cards: [card]);
    g.act(1, 'pass');
    g.act(2, 'pass');
    expect(g.recent, [[], [], []]);
    expect(g.playedCards[0], [card]);
    expect(g.actionHistory, [
      [card],
      [],
      [],
    ]);
  });
  test('大师难度手动选择并持久化，默认普通', () async {
    const channel = MethodChannel('test.model.settings');
    var saved = <String, dynamic>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'initialize') return saved;
          if (call.method == 'settings') {
            saved = Map<String, dynamic>.from(call.arguments as Map);
          }
          return null;
        });
    final a = GameAudio(channel: channel);
    await a.initialize();
    expect(a.difficulty, '普通');
    await a.settings(level: '大师');
    a.dispose();
    final b = GameAudio(channel: channel);
    await b.initialize();
    expect(b.difficulty, '大师');
    b.dispose();
  });
  test('模型损坏时明确失败，不返回规则AI结果', () async {
    final worker = MasterWorker();
    try {
      await expectLater(
        worker.initialize({'landlord': Uint8List(8)}),
        throwsStateError,
      );
    } finally {
      worker.dispose();
    }
  });
  test('持久isolate载入真实权重，合法候选索引与直接前向相同', () async {
    final worker = MasterWorker();
    try {
      await worker.initialize({
        for (final r in ['landlord', 'landlord_down', 'landlord_up'])
          r: File('assets/models/$r.dzf').readAsBytesSync(),
      });
      final traces = jsonDecode(
        File('tool/model/observation_traces.json').readAsStringSync(),
      ) as List;
      for (final row in traces.take(6)) {
        final candidates = [
          for (final x in row['candidates'] as List) List<int>.from(x as List),
        ];
        final result = await worker.decide(
          ModelObservation.fromMap(
            Map<String, dynamic>.from(row['observation'] as Map),
          ),
          candidates,
        );
        final scores = List<double>.from(row['scores'] as List);
        var best = 0;
        for (var i = 1; i < scores.length; i++) {
          if (scores[i] > scores[best]) best = i;
        }
        expect(result['index'], best);
        expect(
          result['winProbabilities'],
          everyElement(inInclusiveRange(0, 1)),
        );
      }
    } finally {
      worker.dispose();
    }
  });
}
