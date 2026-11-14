import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doudizhu/main.dart';
import 'package:doudizhu/ui/game_app.dart';
import 'package:doudizhu/ui/table_controller.dart';
import 'package:doudizhu/ui/table_widgets.dart';
import 'package:doudizhu/audio/game_audio.dart';

void fixture(TableController c, {bool last = false}) {
  final g = c.game!;
  g.phase = 'play';
  g.turn = 0;
  g.landlord = 0;
  g.bid = 3;
  g.hands = [
    last ? [0] : [0, 4, 24],
    [8, 12, 28],
    [16, 20, 32],
  ];
  g.recent = [[], [], []];
  g.owner = -1;
  g.target = null;
  c.view = g.snapshot(0);
  c.audio.reset();
  c.audio.observe(c.view!, 0);
  c.selected = {0};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('cn.offline.doudizhu/audio');
  final said = <String>[];
  Completer<void>? speech;
  var saved = <String, dynamic>{};
  setUp(() {
    said.clear();
    speech = null;
    saved = {};
    for (final name in ['transport', 'events']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel('cn.offline.doudizhu/$name'),
            (call) async => null,
          );
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'initialize') return saved;
          if (call.method == 'settings') {
            saved = Map<String, dynamic>.from(call.arguments as Map);
          }
          if (call.method == 'speak') {
            said.add((call.arguments as Map)['text'] as String);
            await speech?.future;
          }
          return null;
        });
  });
  testWidgets('标准节奏：AI逐次行动间隔至少600ms，先保留本手再思考', (t) async {
    final c = TableController();
    await t.pump();
    c.single();
    fixture(c);
    await c.audio.settings(tempo: 1);
    c.action('play');
    expect(c.presentationBusy, true);
    expect(c.presentationSeat, 0);
    var elapsed = 0;
    final times = <int>[0];
    var revision = c.revision;
    while (times.length < 3 && elapsed < 10000) {
      await t.pump(const Duration(milliseconds: 50));
      elapsed += 50;
      if (c.revision != revision) {
        times.add(elapsed);
        revision = c.revision;
      }
    }
    expect(times.length, 3);
    expect(times[1] - times[0], greaterThanOrEqualTo(1200));
    expect(times[2] - times[1], greaterThanOrEqualTo(1200));
    print('AI时间轴(ms): $times');
    c.dispose();
    await t.pump(const Duration(seconds: 3));
  });
  for (final level in ['简单', '普通', '大师']) {
    for (final pace in [3, 0, 1, 2]) {
      testWidgets('$level 节奏$pace：实际两次AI行动保留停留与思考下限', (t) async {
        final c = TableController();
        await t.pump();
        if (level == '大师') {
          // Load and run the real built-in network, without replacing its worker.
          await t.runAsync(() => c.setDifficulty(level));
          expect(c.modelReady, true);
        } else {
          await c.setDifficulty(level);
        }
        await c.audio.settings(tempo: pace, speech: false);
        final minThink = pace == 3
            ? 200
            : pace == 2
            ? 1000
            : 600;
        final maxThink = pace == 3
            ? 400
            : pace == 2
            ? 1800
            : pace == 0
            ? 800
            : 1200;
        final minHold = pace == 3
            ? 200
            : pace == 2
            ? 900
            : 600;
        final maxHold = pace == 3
            ? 200
            : pace == 2
            ? 1200
            : pace == 0
            ? 600
            : 800;
        for (var sample = 0; sample < 30; sample++) {
          expect(c.thinkingMs, inInclusiveRange(minThink, maxThink));
          expect(c.dwellMs, inInclusiveRange(minHold, maxHold));
        }
        c.single();
        fixture(c);
        c.action('play');
        var elapsed = 0, revision = c.revision;
        final actions = <int>[0], releases = <int>[];
        final origin = t.binding.clock.now();
        var wasBusy = c.presentationBusy;
        void record() {
          final now = t.binding.clock.now().difference(origin).inMilliseconds;
          if (wasBusy && !c.presentationBusy) releases.add(now);
          if (c.revision != revision) {
            actions.add(now);
            revision = c.revision;
          }
          wasBusy = c.presentationBusy;
        }

        c.addListener(record);
        while (actions.length < 3 && elapsed < 15000) {
          await t.pump(const Duration(milliseconds: 25));
          elapsed += 25;
          if (c.modelThinking) {
            // Only yield the test harness to the actual isolate; app delays
            // remain asynchronous Timers in the Flutter virtual clock.
            await t.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
          }
        }
        c.removeListener(record);
        expect(c.modelFailed, false);
        expect(actions, hasLength(3));
        expect(releases, hasLength(2));
        for (var i = 0; i < 2; i++) {
          expect(
            releases[i] - actions[i],
            inInclusiveRange(minHold, maxHold + 25),
          );
          expect(actions[i + 1] - releases[i], greaterThanOrEqualTo(minThink));
          expect(
            actions[i + 1] - actions[i],
            greaterThanOrEqualTo(minHold + minThink),
          );
        }
        if (pace == 3) {
          expect(actions[1] - actions[0], lessThanOrEqualTo(800));
          expect(actions[2] - actions[1], lessThanOrEqualTo(800));
        }
        print('$level pace=$pace actions(ms)=$actions holdEnds(ms)=$releases');
        c.dispose();
        await t.pump(const Duration(seconds: 3));
      });
    }
  }
  testWidgets('极速自己出牌停留200ms，未结束报牌不拖慢下一位AI', (t) async {
    final c = TableController();
    await t.pump();
    c.single();
    fixture(c);
    await c.audio.settings(tempo: 3, speech: true);
    speech = Completer<void>();
    c.action('play');
    final revision = c.revision;
    await t.pump(const Duration(milliseconds: 199));
    expect(c.presentationBusy, true);
    await t.pump(const Duration(milliseconds: 1));
    expect(c.presentationBusy, false);
    await t.pump(const Duration(milliseconds: 600));
    expect(c.revision, greaterThan(revision));
    speech!.complete();
    c.dispose();
    await t.pump(const Duration(seconds: 3));
  });
  testWidgets('慢档叫分等待也不超过800ms', (t) async {
    final c = TableController();
    await t.pump();
    await c.audio.settings(tempo: 2);
    c.single();
    c.action('bid', value: 0);
    final revision = c.revision;
    await t.pump(const Duration(milliseconds: 800));
    expect(c.revision, greaterThan(revision));
    c.dispose();
    await t.pump(const Duration(seconds: 3));
  });
  testWidgets('自己的非终局出牌先亮牌再报牌，播完之前禁止下一步', (t) async {
    final c = TableController();
    await t.pump();
    c.single();
    fixture(c);
    await c.audio.settings(speech: true, tempo: 1);
    speech = Completer<void>();
    c.action('play');
    expect((c.view!['recent'] as List)[0], [0]);
    expect(said, isEmpty);
    await t.pump(const Duration(milliseconds: 150));
    expect(said.single, contains('单张，1张'));
    await t.pump(const Duration(milliseconds: 1000));
    expect(c.presentationBusy, true);
    speech!.complete();
    await t.pump();
    expect(c.presentationBusy, false);
    c.dispose();
    await t.pump(const Duration(seconds: 3));
  });
  testWidgets('终局最后一手完整显示>=1.2s，自己播报完成后才结算，可查看牌桌', (t) async {
    t.view.physicalSize = const Size(844, 390);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(const DoudizhuApp());
    await t.pumpAndSettle();
    await t.tap(find.bySemanticsLabel('单机'));
    await t.pumpAndSettle();
    final c = (t.state(find.byType(GameApp)) as dynamic).c as TableController;
    fixture(c, last: true);
    await c.audio.settings(speech: true, tempo: 1);
    speech = Completer<void>();
    c.action('play');
    await t.pump();
    final zone = find.byKey(const ValueKey('played-0'));
    final cards = find.descendant(of: zone, matching: find.byType(CardFace));
    expect(cards, findsOneWidget);
    expect(t.widget<CardFace>(cards).id, 0);
    expect(t.widget<PlayedZone>(zone).highlighted, true);
    expect(find.text('查看牌桌'), findsNothing);
    await t.pump(const Duration(milliseconds: 1199));
    expect(c.showResult, false);
    expect(cards, findsOneWidget);
    expect(said, ['单张，1张，3']);
    await t.pump(const Duration(milliseconds: 101));
    expect(c.showResult, false);
    speech!.complete();
    await t.pump();
    await t.pumpAndSettle();
    expect(c.showResult, true);
    expect(find.text('查看牌桌'), findsOneWidget);
    await t.tap(find.text('查看牌桌'));
    await t.pumpAndSettle();
    expect(find.text('再来一局'), findsNothing);
    expect(cards, findsOneWidget);
    await t.tap(find.text('查看结算'));
    await t.pumpAndSettle();
    expect(find.text('再来一局'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  });
  testWidgets('报牌关闭时结算恰在1.2s后开放；TTS无回调不超过1.6s', (t) async {
    for (final voice in [false, true]) {
      final c = TableController();
      await t.pump();
      c.single();
      fixture(c, last: true);
      await c.audio.settings(speech: voice);
      speech = voice ? Completer<void>() : null;
      c.action('play');
      await t.pump(const Duration(milliseconds: 1199));
      expect(c.showResult, false);
      await t.pump(const Duration(milliseconds: 1));
      expect(c.showResult, !voice);
      if (voice) {
        await t.pump(const Duration(milliseconds: 400));
        expect(c.showResult, true);
      }
      speech?.complete();
      c.dispose();
      await t.pump(const Duration(seconds: 3));
    }
  });
  testWidgets('静音不额外拖延、返回菜单取消旧结算和后续AI', (t) async {
    final c = TableController();
    await t.pump();
    c.single();
    fixture(c, last: true);
    await c.audio.settings(mute: true, speech: true);
    c.action('play');
    await t.pump(const Duration(milliseconds: 1200));
    expect(c.showResult, true);
    expect(said, isEmpty);
    c.start();
    fixture(c, last: true);
    c.action('play');
    await c.menu();
    await t.pump(const Duration(seconds: 4));
    expect(c.screen, 'menu');
    expect(c.view, null);
    expect(c.showResult, false);
    c.dispose();
  });
  test('节奏默认快，四档设置均持久化恢复', () async {
    final initial = GameAudio();
    await initial.initialize();
    expect(initial.pace, 0);
    initial.dispose();
    for (final pace in [3, 0, 1, 2]) {
      final a = GameAudio();
      await a.initialize();
      await a.settings(tempo: pace);
      a.dispose();
      final b = GameAudio();
      await b.initialize();
      expect(b.pace, pace);
      b.dispose();
    }
  });
}
