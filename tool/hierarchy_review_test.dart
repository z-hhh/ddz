import 'dart:io';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doudizhu/main.dart';
import 'package:doudizhu/ui/game_app.dart';
import 'package:doudizhu/ui/table_widgets.dart';
import 'package:doudizhu/ui/table_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('固定叠牌与操作区层次实测', (tester) async {
    final bytes = File('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc')
        .readAsBytesSync();
    for (final family in ['Roboto', 'Ahem', 'sans-serif']) {
      await (FontLoader(
        family,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
    final icons = File(
      '${Platform.environment['FLUTTER_ROOT'] ?? '../../sdk/flutter'}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytesSync();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.sublistView(icons)))).load();
    for (final name in ['transport', 'events', 'audio']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel('cn.offline.doudizhu/$name'),
            (call) async => null,
          );
    }
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(key: boundaryKey, child: const DoudizhuApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('单机'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3 分'));
    await tester.pumpAndSettle();
    final c =
        (tester.state(find.byType(GameApp)) as dynamic).c as TableController;

    await tester.runAsync(() async {
      for (final name in [
        'table-linen-v2',
        'player-owner-v2',
        'player-woman-v2',
        'player-man-v2',
        'result-seal-v2',
        'joker-big-v2',
        'joker-small-v2',
      ]) {
        await precacheImage(
          AssetImage('assets/art/$name.webp'),
          boundaryKey.currentContext!,
        );
      }
    });
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('../../dist/1.9.4-$name.png')
            .writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    for (final size in [const Size(844, 390), const Size(640, 360)]) {
      tester.view.physicalSize = size;
      double? fullStep;
      for (final count in [20, 12, 5]) {
        final hand = [
          0,
          4,
          5,
          8,
          9,
          12,
          13,
          16,
          17,
          20,
          24,
          25,
          28,
          32,
          36,
          40,
          44,
          48,
          52,
          53,
        ].take(count).toList();
        c.view = {
          ...c.view!,
          'phase': 'play',
          'turn': c.self,
          'owner': (c.self + 1) % 3,
          'target': {'type': '单张', 'high': 3, 'length': 1, 'chain': 1},
          'hands': [
            for (var i = 0; i < 3; i++)
              i == c.self ? hand : [20, 24, 28, 32, 36],
          ],
          'recent': [
            for (var i = 0; i < 3; i++)
              i == c.self
                  ? <int>[]
                  : i == (c.self + 1) % 3
                  ? [0]
                  : [20, 24, 28, 32, 36],
          ],
          'passed': [false, false, false],
        };
        c.selected = {4};
        c.update();
        await capture('${size.width.toInt()}-手牌$count张');
        final handCards = find.descendant(
          of: find.byType(HandFan),
          matching: find.byType(CardFace),
        );
        final first = tester.getRect(handCards.first);
        final last = tester.getRect(handCards.last);
        final step = tester.getRect(handCards.at(1)).left - first.left;
        fullStep ??= step;
        expect((step - fullStep).abs(), lessThanOrEqualTo(2.001));
        expect((first.left + last.right) / 2, closeTo(size.width / 2, .01));
        expect(first.left, greaterThanOrEqualTo(16));
        expect(last.right, lessThanOrEqualTo(size.width - 16));
        expect(find.textContaining('张手牌'), findsNothing);
        print('HAND ${size.width} count=$count step=$step');
        if (count == 5) {
          final primary = find.widgetWithText(FilledButton, '出牌 (1)');
          expect(tester.widget<FilledButton>(primary).onPressed, isNotNull);
          final top = tester.getTopLeft(primary).dy;
          final gesture = await tester.startGesture(tester.getCenter(primary));
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.getTopLeft(primary).dy, closeTo(top + 2, .01));
          await capture('${size.width.toInt()}-按钮按下');
          await gesture.cancel();
          await tester.pumpAndSettle();
        }
      }
      tester.view.padding = const FakeViewPadding(
        left: 24,
        right: 24,
        top: 0,
        bottom: 12,
      );
      tester.view.viewPadding = const FakeViewPadding(
        left: 24,
        right: 24,
        top: 0,
        bottom: 12,
      );
      await capture('${size.width.toInt()}-安全区');
      final zone = tester.getRect(find.byKey(const ValueKey('played-0')));
      expect(zone.left, greaterThanOrEqualTo(24));
      expect(zone.right, lessThanOrEqualTo(size.width - 24));
      final handBottom = tester.getBottomRight(find.byType(HandFan)).dy;
      expect(handBottom, lessThanOrEqualTo(size.height - 12));
      tester.view.resetPadding();
      tester.view.resetViewPadding();
      final g = c.game!;
      g.phase = 'play';
      g.turn = c.self;
      g.landlord = c.self;
      g.bid = 3;
      g.plays = [1, 1, 1];
      g.bottom = [36, 40, 44];
      g.hands = [
        [0],
        [4, 8],
        [12, 16],
      ];
      g.recent = [
        [],
        [20],
        [24],
      ];
      g.owner = -1;
      g.target = null;
      c.view = g.snapshot(c.self);
      c.audio.reset();
      c.audio.observe(c.view!, c.self);
      c.selected = {0};
      c.action('play');
      await capture('${size.width.toInt()}-最后一手');
      expect(c.showResult, false);
      await tester.pump(const Duration(milliseconds: 1200));
      await capture('${size.width.toInt()}-结算层次');
      await tester.tap(find.text('查看牌桌'));
      await capture('${size.width.toInt()}-查看牌桌');
      c.start();
      await tester.pumpAndSettle();
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
