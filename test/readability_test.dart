import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doudizhu/audio/game_audio.dart';
import 'package:doudizhu/ui/table_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('牌面大小即时变更、持久化与恢复', () async {
    Map<String, dynamic> saved = {};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('cn.offline.doudizhu/audio'),
          (call) async {
            if (call.method == 'settings') {
              saved = Map<String, dynamic>.from(call.arguments);
            }
            if (call.method == 'initialize') return saved;
            return null;
          },
        );
    final a = GameAudio();
    expect(a.cardSize, 1);
    await a.settings(size: 2);
    expect(a.cardSize, 2);
    final b = GameAudio();
    await b.initialize();
    expect(b.cardSize, 2);
    a.dispose();
    b.dispose();
  });
  testWidgets('20张手牌完整同屏，三档尺寸、窄屏双排均可读', (t) async {
    for (final viewport in [
      const Size(844, 390),
      const Size(640, 360),
      const Size(320, 360),
    ]) {
      t.view.physicalSize = viewport;
      t.view.devicePixelRatio = 1;
      for (final width in [52.0, 56.0, 60.0]) {
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HandFan(
                cards: List.generate(20, (i) => i),
                selected: const {},
                compact: true,
                enabled: true,
                cardWidth: width,
                onChanged: (_) {},
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final cards = find.byType(CardFace);
        expect(cards, findsNWidgets(20));
        for (final e in cards.evaluate()) {
          final rect = t.getRect(find.byWidget(e.widget));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(viewport.width));
          expect((e.widget as CardFace).width * .4, greaterThanOrEqualTo(13));
        }
        expect(t.takeException(), null);
      }
    }
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
  });
  testWidgets('手牌张数变化时步长不变、居中且选中不挤牌', (t) async {
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    for (final viewport in [const Size(640, 360), const Size(844, 390)]) {
      t.view.physicalSize = viewport;
      double? previous;
      for (final count in [20, 12, 5]) {
        for (final selected in [
          <int>{},
          <int>{1},
        ]) {
          await t.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HandFan(
                  cards: List.generate(count, (i) => i),
                  selected: selected,
                  compact: true,
                  enabled: true,
                  onChanged: (_) {},
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          final cards = find.byType(CardFace);
          final first = t.getRect(cards.first), last = t.getRect(cards.last);
          final step = t.getRect(cards.at(1)).left - first.left;
          if (previous != null) expect(step, closeTo(previous, .01));
          previous = step;
          expect(step, lessThan(56 - 10));
          expect(
            (first.left + last.right) / 2,
            closeTo(viewport.width / 2, .01),
          );
          expect(t.takeException(), null);
        }
      }
    }
  });
}
