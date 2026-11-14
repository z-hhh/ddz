import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:doudizhu/game/cards.dart';
import 'package:doudizhu/game/rules.dart';
import 'package:doudizhu/game/ai.dart';
import 'package:doudizhu/game/game_state.dart';
import 'package:doudizhu/game/protocol.dart';

List<int> cards(List<int> ranks) {
  final used = <int, int>{};
  return ranks.map((r) {
    final n = used[r] ?? 0;
    used[r] = n + 1;
    return r >= 16 ? r + 36 : (r - 3) * 4 + n;
  }).toList();
}

void main() {
  test('各席最近出牌保留，不出仅标记；两家过牌后统一清台', () {
    final g = GameState()..phase = 'play';
    g.turn = 0;
    g.hands = [
      [0, 4, 40],
      [8, 12, 44],
      [16, 20, 48],
    ];
    expect(g.act(0, 'play', cards: [0]), null);
    expect(g.act(1, 'play', cards: [8]), null);
    expect(g.act(2, 'play', cards: [16]), null);
    expect(g.recent, [
      [0],
      [8],
      [16],
    ]);
    expect(g.act(0, 'pass'), null);
    expect(g.recent[0], [0]);
    expect(g.passed[0], true);
    expect(g.act(1, 'pass'), null);
    expect(g.recent, [[], [], []]);
    expect(g.target, null);
    expect(g.turn, 2);
  });

  final cases = <String, List<int>>{
    '单张': [3],
    '对子': [4, 4],
    '三张': [5, 5, 5],
    '三带一': [5, 5, 5, 3],
    '三带二': [5, 5, 5, 3, 3],
    '顺子': [3, 4, 5, 6, 7],
    '连对': [3, 3, 4, 4, 5, 5],
    '飞机': [3, 3, 3, 4, 4, 4],
    '飞机带单': [3, 3, 3, 4, 4, 4, 6, 7],
    '飞机带对': [3, 3, 3, 4, 4, 4, 6, 6, 7, 7],
    '四带二单': [3, 3, 3, 3, 4, 5],
    '四带二对': [3, 3, 3, 3, 4, 4, 5, 5],
    '炸弹': [3, 3, 3, 3],
    '王炸': [16, 17],
  };
  for (final e in cases.entries) {
    test('识别 ${e.key}', () {
      expect(identify(cards(e.value))?.type, e.key);
    });
  }
  test('牌组54张与王点数', () {
    expect(deck(Random(42)).toSet().length, 54);
    expect(rank(52), 16);
    expect(rank(53), 17);
  });
  test('大小、类型、长度与炸弹优先级', () {
    final single = identify(cards([7]))!;
    expect(beats(identify(cards([8]))!, single), true);
    expect(beats(identify(cards([6, 6]))!, single), false);
    final bomb = identify(cards([3, 3, 3, 3]))!;
    expect(beats(bomb, single), true);
    expect(beats(identify(cards([16, 17]))!, bomb), true);
    expect(beats(bomb, identify(cards([16, 17]))!), false);
    expect(beats(bomb, bomb), false);
    expect(
      beats(
        identify(cards([4, 5, 6, 7, 8, 9]))!,
        identify(cards([3, 4, 5, 6, 7]))!,
      ),
      false,
    );
  });
  test('顺子与连续主体边界', () {
    for (final r in [
      [11, 12, 13, 14, 15],
      [12, 13, 14, 15, 16],
      [13, 14, 15, 16, 17],
      [3, 4, 5, 6],
      [3, 3, 4, 4],
      [14, 14, 15, 15, 16, 16],
      [14, 14, 14, 15, 15, 15],
    ]) {
      expect(identify(cards(r)), null, reason: r.toString());
    }
    expect(identify(cards([10, 11, 12, 13, 14]))?.type, '顺子');
  });
  test('四带两单允许对子，两对要求不同点数', () {
    expect(identify(cards([3, 3, 3, 3, 4, 4]))?.type, '四带二单');
    expect(identify(cards([3, 3, 3, 3, 4, 4, 4, 4])), null);
    expect(identify(cards([3, 3, 3, 4, 4, 4, 5, 5]))?.type, '飞机带单');
    expect(identify(cards([3, 3, 3, 4, 4, 4, 5, 5, 6, 7])), null);
  });
  test('重复牌、越界牌、伪造出牌被拒绝', () {
    expect(identify([0, 0]), null);
    expect(identify([-1]), null);
    expect(legal([0], [1], null), false);
  });
  for (int i = 0; i < 24; i++) {
    test('AI 典型/随机局面 $i 始终合法', () {
      final h = sorted(deck(Random(i)).take(i % 2 == 0 ? 20 : 17));
      final previous = i < cases.length
          ? identify(cards(cases.values.elementAt(i)))
          : null;
      for (final normal in [false, true]) {
        final m = choose(h, previous, normal: normal);
        if (m.isEmpty) {
          expect(moves(h, previous), isEmpty);
          expect(previous, isNotNull);
        } else {
          expect(legal(h, m, previous), true);
        }
      }
    });
  }
  test('AI 会拆牌跟单、地主主动出牌', () {
    final h = cards([3, 3, 3, 4, 4]);
    expect(choose(h, identify(cards([3]))), isNotEmpty);
    expect(choose(h, null), isNotEmpty);
  });
  test('叫分、无人叫重发、3分立即定地主、过牌重置', () {
    final g = GameState();
    for (int i = 0; i < 3; i++) {
      expect(g.act(i, 'bid', value: 0), null);
    }
    expect(g.phase, 'bid');
    expect(g.hands.every((h) => h.length == 17), true);
    expect(g.act(0, 'bid', value: 3), null);
    expect(g.landlord, 0);
    expect(g.hands[0].length, 20);
    expect(g.act(0, 'pass'), isNotNull);
    final c = choose(g.hands[0], null);
    expect(g.act(0, 'play', cards: c), null);
    expect(g.act(1, 'pass'), null);
    expect(g.act(2, 'pass'), null);
    expect(g.turn, 0);
    expect(g.target, null);
  });
  test('农民共同胜利、春天与零和得分', () {
    final g = GameState()..spring = false;
    g.act(0, 'bid', value: 3);
    g.hands = [
      [0, 4],
      [8],
      [12],
    ];
    g.turn = 1;
    expect(g.act(1, 'play', cards: [8]), null);
    expect(g.phase, 'over');
    expect(g.scores, [-6, 3, 3]);
    final h = GameState();
    h.act(0, 'bid', value: 3);
    h.hands = [
      [0],
      [4],
      [8],
    ];
    h.act(0, 'play', cards: [0]);
    expect(h.scores, [12, -6, -6]);
  });
  test('30 局三 AI 快进完整对局，无死循环', () {
    for (int n = 0; n < 30; n++) {
      final g = GameState();
      int steps = 0;
      while (g.phase != 'over' && steps++ < 600) {
        final seat = g.turn;
        if (g.phase == 'bid') {
          expect(g.act(seat, 'bid', value: 3), null);
        } else {
          final m = choose(g.hands[seat], g.target);
          expect(g.act(seat, m.isEmpty ? 'pass' : 'play', cards: m), null);
        }
      }
      expect(g.phase, 'over', reason: '对局 $n 卡死');
      expect(g.scores.reduce((a, b) => a + b), 0);
    }
  });
  test('协议：拆包/粘包/UTF-8/断线/非法长度', () {
    final m = {
      'kind': '出牌',
      'cards': [1, 2],
    };
    final frame = encodeFrame(m);
    final decoder = FrameDecoder();
    final output = <Map<String, dynamic>>[];
    for (final b in frame) {
      output.addAll(decoder.feed([b]));
    }
    expect(output, [m]);
    expect(decoder.feed([...frame, ...frame]), [m, m]);
    decoder.feed(frame.take(5).toList());
    decoder.close();
    expect(() => decoder.feed(frame), throwsStateError);
    expect(() => FrameDecoder().feed([0, 0, 0, 0]), throwsFormatException);
    expect(() => FrameDecoder().feed([0, 5, 0, 0]), throwsFormatException);
  });
  test('协议：超时与重连、版本/会话/序号防重放', () {
    final now = DateTime(2026);
    final deadline = PeerDeadline(now);
    expect(deadline.expired(now.add(const Duration(seconds: 29))), false);
    expect(deadline.expired(now.add(const Duration(seconds: 30))), true);
    deadline.touch(now.add(const Duration(seconds: 31)));
    expect(deadline.expired(now.add(const Duration(seconds: 32))), false);
    final guard = IntentGuard('局1');
    final m = {'v': 1, 'session': '局1', 'seq': 1};
    expect(guard.accept('客人', m), true);
    expect(guard.accept('客人', m), false);
    expect(guard.accept('客人', {'v': 1, 'session': '旧局', 'seq': 2}), false);
    guard.resetPeer('客人');
    expect(guard.accept('客人', m), true);
  });
}
