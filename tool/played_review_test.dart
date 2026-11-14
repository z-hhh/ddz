import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doudizhu/main.dart';
import 'package:doudizhu/ui/game_app.dart';
import 'package:doudizhu/ui/table_controller.dart';
import 'package:doudizhu/ui/table_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('长牌型同屏与紧凑玩家信息实测', (tester) async {
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
    final examples = <String, List<int>>{
      '1张': [28],
      '5张': [20, 24, 28, 32, 36],
      '8张': [0, 4, 8, 12, 16, 20, 24, 28],
      '12张': [20, 21, 22, 24, 25, 26, 28, 29, 30, 52, 53, 36],
    };
    final measurements = [];
    for (final size in [const Size(844, 390), const Size(640, 360)]) {
      tester.view.physicalSize = size;
      for (final example in examples.entries) {
        c.view = {
          ...c.view!,
          'phase': 'play',
          'turn': 0,
          'owner': 1,
          'target': {
            'type': example.key,
            'high': 9,
            'length': example.value.length,
            'chain': 1,
          },
          'recent': example.value.length == 5
              ? [
                  [5, 9, 13, 17, 21],
                  [10, 14, 18, 22, 26],
                  [0, 4, 8, 12, 16],
                ]
              : [example.value, example.value, example.value],
          'passed': [false, false, false],
        };
        c.update();
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await Future.wait([
            for (final asset in [
              'table-linen-v2',
              'player-owner-v2',
              'player-woman-v2',
              'player-man-v2',
              'joker-big-v2',
              'joker-small-v2',
            ])
              precacheImage(
                AssetImage('assets/art/$asset.webp'),
                boundaryKey.currentContext!,
              ),
          ]);
        });
        await tester.pumpAndSettle();
        expect(find.text('牌友1'), findsOneWidget);
        expect(find.text('牌友2'), findsOneWidget);
        expect(find.textContaining(RegExp(r'AI\s*\d|压牌友|领出')), findsNothing);
        expect(
          find.descendant(
            of: find.byType(PlayedZone),
            matching: find.textContaining(RegExp('牌友|当前|不出|等待|地主|农民|你')),
          ),
          findsNothing,
        );
        final zones = [
          for (var i = 0; i < 3; i++) find.byKey(ValueKey('played-$i')),
        ];
        final rects = zones.map(tester.getRect).toList();
        final sorted = [...rects]..sort((a, b) => a.left.compareTo(b.left));
        for (var i = 1; i < 3; i++) {
          expect(
            sorted[i].left - sorted[i - 1].right,
            greaterThanOrEqualTo(19.99),
          );
        }
        for (var i = 0; i < 3; i++) {
          expect(rects[i].left, greaterThanOrEqualTo(0));
          expect(rects[i].right, lessThanOrEqualTo(size.width));
          for (var j = i + 1; j < 3; j++) {
            expect(rects[i].overlaps(rects[j]), false);
          }
          final cardFinder = find.descendant(
            of: zones[i],
            matching: find.byType(CardFace),
          );
          expect(cardFinder, findsNWidgets(example.value.length));
          for (final card in cardFinder.evaluate()) {
            final rect = tester.getRect(
              find.byElementPredicate((e) => identical(e, card)),
            );
            expect(rect.left, greaterThanOrEqualTo(rects[i].left - .01));
            expect(rect.right, lessThanOrEqualTo(rects[i].right + .01));
            expect(rect.bottom, lessThanOrEqualTo(rects[i].bottom + .01));
          }
          final bounds = cardFinder
              .evaluate()
              .map(
                (e) => tester.getRect(
                  find.byElementPredicate((other) => identical(other, e)),
                ),
              )
              .reduce((a, b) => a.expandToInclude(b));
          expect(bounds.center.dx, closeTo(rects[i].center.dx, .01));
          expect(bounds.center.dy, closeTo(rects[i].center.dy, .01));
          final card = tester.widget<CardFace>(cardFinder.first);
          final layout = PlayedLayout(
            example.value.length,
            rects[i].width,
            rects[i].height - 16,
            56,
          );
          final renderedCards = cardFinder.evaluate().toList();
          for (var index = 0; index < renderedCards.length; index++) {
            final element = renderedCards[index];
            final finder = find.byElementPredicate(
              (e) => identical(e, element),
            );
            final rect = tester.getRect(finder);
            final nextLeft =
                index % layout.columns < layout.columns - 1 &&
                    index + 1 < renderedCards.length
                ? rect.left + layout.step
                : rect.right;
            for (final text
                in find
                    .descendant(of: finder, matching: find.byType(Text))
                    .evaluate()) {
              final textRect = tester.getRect(
                find.byElementPredicate((e) => identical(e, text)),
              );
              expect(
                textRect.right,
                lessThanOrEqualTo(nextLeft + .1),
                reason: '点数花色不得被下一张遮住',
              );
              expect(textRect.bottom, lessThanOrEqualTo(rect.bottom + .1));
            }
          }
          measurements.add({
            'screen': '${size.width.toInt()}×${size.height.toInt()}',
            'type': example.key,
            'seat': i,
            'zoneWidth': rects[i].width,
            'cardWidth': card.width,
            'cardHeight': card.height,
            'rows': layout.rows,
            'step': layout.step,
            'cornerFont': card.width * .4 < 13 ? 13 : card.width * .4,
          });
        }
        for (final seat in [1, 2]) {
          final panel = tester.getRect(
            find.byKey(ValueKey('opponent-info-$seat')),
          );
          expect(panel.width, 84);
          for (final rect in rects) {
            expect(panel.overlaps(rect), false);
          }
        }
        expect(
          find.descendant(
            of: find.byType(PlayedZone),
            matching: find.byType(Scrollable),
          ),
          findsNothing,
        );
        expect(tester.takeException(), null);
        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '../../dist/1.9.4-出牌-${size.width.toInt()}-${example.key}.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
    File('../../dist/1.9.4-出牌尺寸.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(measurements),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
