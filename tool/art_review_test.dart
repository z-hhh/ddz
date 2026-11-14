import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doudizhu/main.dart';
import 'package:doudizhu/game/ai.dart';
import 'package:doudizhu/game/rules.dart';
import 'package:doudizhu/game/cards.dart';
import 'package:doudizhu/game/game_state.dart';
import 'package:doudizhu/ui/table_widgets.dart';
import 'package:doudizhu/ui/game_app.dart';
import 'package:doudizhu/ui/table_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('生成手机原生界面截图', (tester) async {
    final bytes = File('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc')
        .readAsBytesSync();
    for (final family in ['Roboto', 'Ahem', 'sans-serif']) {
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('cn.offline.doudizhu/transport'),
          (call) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('cn.offline.doudizhu/events'),
          (call) async => null,
        );
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File(
              '/home/comma/.comma/station/sessions/ember/c-aae7762ba8/workspace/sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ).readAsBytesSync(),
          ),
        ),
      );
    await icons.load();
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(key: key, child: const DoudizhuApp()),
    );
    await tester.runAsync(() async {
      await Future.wait([
        for (final name in [
          'friends-v2',
          'table-linen-v2',
          'player-owner-v2',
          'player-woman-v2',
          'player-man-v2',
          'card-back-v2',
          'result-seal-v2',
          'oak-ui-v2',
          'joker-big-v2',
          'joker-small-v2',
        ])
          precacheImage(
            AssetImage('assets/art/$name.webp'),
            key.currentContext!,
          ),
      ]);
    });
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('/work/dist/$name.png')
            .writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('终图-首页');
    for (final size in [const Size(568, 320), const Size(640, 360)]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('单机')).bottom, lessThan(size.height));
      await capture('小屏-首页-${size.width.toInt()}');
      expect(tester.takeException(), null);
    }
    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    await capture('美术-首页竖屏');
    final TableController c =
        (tester.state(find.byType(GameApp)) as dynamic).c as TableController;
    tester.view.physicalSize = const Size(844, 390);
    c.screen = 'audio';
    c.update();
    await tester.pumpAndSettle();
    expect(find.text('中文报牌'), findsOneWidget);
    await tester.tap(find.widgetWithText(SwitchListTile, '总静音'));
    await tester.pumpAndSettle();
    expect(c.audio.muted, true);
    await tester.tap(find.widgetWithText(SwitchListTile, '总静音'));
    await tester.pumpAndSettle();
    expect(c.audio.muted, false);
    await capture('声音设置-1.7.0');
    tester.view.physicalSize = const Size(568, 320);
    await tester.pumpAndSettle();
    expect(tester.takeException(), null);
    await capture('声音设置-小屏');
    tester.view.physicalSize = const Size(390, 844);
    c.screen = 'lobby';
    c.host = true;
    c.status = '等待朋友加入，请允许系统蓝牙可发现请求';
    c.update();
    await tester.pumpAndSettle();
    await capture('美术-联机等候');
    c.screen = 'rules';
    c.update();
    await tester.pumpAndSettle();
    await capture('美术-规则说明');
    c.screen = 'menu';
    c.update();
    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();
    await tester.tap(find.text('单机'));
    await tester.pumpAndSettle();
    await capture('美术-叫地主');
    await tester.tap(find.text('3 分'));
    await tester.pumpAndSettle();
    await capture('横屏牌桌');
    await tester.tap(find.text('提示'));
    await tester.pumpAndSettle();
    await capture('美术-横屏出牌');
    for (final size in [const Size(568, 320), const Size(640, 360)]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      final fan = find.byType(HandFan);
      expect(
        find.descendant(of: fan, matching: find.byType(CardFace)),
        findsNWidgets(20),
      );
      final rect = tester.getRect(fan);
      c.setSelection({});
      await tester.pump();
      await tester.tapAt(Offset(rect.right - 12, rect.top + 40));
      expect(c.selected.contains(c.hand.last), true, reason: '最右侧手牌可触达');
      await tester.dragFrom(
        Offset(rect.left + 12, rect.top + 40),
        Offset(rect.width - 24, 0),
      );
      await tester.pumpAndSettle();
      expect(c.selected.length, greaterThan(15), reason: '横滑可连续选牌');
      expect(c.hand.length, 20);
      await capture('小屏-对局-${size.width.toInt()}');
      expect(tester.takeException(), null);
    }
    tester.view.physicalSize = const Size(844, 390);
    c.setSelection({});
    await tester.pumpAndSettle();
    await tester.tap(find.text('提示'));
    await tester.pumpAndSettle();
    await capture('终图-对局');

    // 完整真实 54 张对局：三席均调用共享 AI，每步通过权威状态机校验。
    final g = c.game!;
    // 双王展示局仍保持54张牌唯一；长按预览不等于出牌。
    final reviewGame = GameState();
    expect(reviewGame.act(0, 'bid', value: 3), null);
    for (final joker in [52, 53]) {
      final seat = reviewGame.hands.indexWhere((h) => h.contains(joker));
      if (seat != 0) {
        final swap = reviewGame.hands[0].firstWhere((id) => id < 52);
        reviewGame.hands[0].remove(swap);
        reviewGame.hands[seat].remove(joker);
        reviewGame.hands[0].add(joker);
        reviewGame.hands[seat].add(swap);
      }
    }
    reviewGame.hands[0] = sorted(reviewGame.hands[0]);
    expect(reviewGame.hands.expand((h) => h).toSet().length, 54);
    c.setSelection({});
    c.view = reviewGame.snapshot(c.self);
    c.update();
    await tester.pumpAndSettle();
    await capture('大小王-双王手牌');
    for (final size in [const Size(568, 320), const Size(640, 360)]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(HandFan),
          matching: find.byType(JokerArt),
        ),
        findsNWidgets(2),
      );
      expect(tester.takeException(), null);
      await capture('大小王-双王手牌-${size.width.toInt()}');
    }
    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();
    final king = find.descendant(
      of: find.byType(HandFan),
      matching: find.byWidgetPredicate((w) => w is CardFace && w.id == 53),
    );
    // CardFace IgnorePointer，触摸由外层 HandFan 统一处理。
    await tester.longPress(king, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('大王 · 牌面预览'), findsOneWidget);
    await capture('大小王-双王在手与大王预览');
    await tester.tap(find.text('关闭预览'));
    await tester.pumpAndSettle();
    expect(reviewGame.act(0, 'play', cards: [53]), null);
    c.view = reviewGame.snapshot(c.self);
    c.update();
    await tester.pumpAndSettle();
    await capture('大小王-实际出王');
    expect(tester.takeException(), null);
    c.view = g.snapshot(c.self);
    c.update();
    // 在真实发牌状态机中连续出三手合法单张，检查独立出牌区。
    for (int i = 0; i < 3; i++) {
      final seat = g.turn;
      final card = g.hands[seat].firstWhere(
        (id) => legal(g.hands[seat], [id], g.target),
      );
      expect(g.act(seat, 'play', cards: [card]), null);
    }
    expect(g.recent.every((cards) => cards.isNotEmpty), true);
    c.setSelection({});
    c.view = g.snapshot(c.self);
    c.update();
    for (final size in [
      const Size(844, 390),
      const Size(568, 320),
      const Size(640, 360),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      final zones = [
        for (int i = 0; i < 3; i++) find.byKey(ValueKey('played-$i')),
      ];
      for (final zone in zones) {
        expect(
          find.descendant(of: zone, matching: find.byType(CardFace)),
          findsOneWidget,
        );
      }
      for (int i = 0; i < 3; i++) {
        for (int j = i + 1; j < 3; j++) {
          expect(
            tester.getRect(zones[i]).overlaps(tester.getRect(zones[j])),
            false,
          );
        }
        expect(
          tester
              .getRect(zones[i])
              .overlaps(tester.getRect(find.byType(HandFan))),
          false,
        );
      }
      for (final zone in zones) {
        expect(
          tester.getRect(zone).overlaps(tester.getRect(find.text('提示'))),
          false,
        );
      }
      expect(tester.takeException(), null);
      final handFinder = find.descendant(
        of: find.byType(HandFan),
        matching: find.byType(CardFace),
      );
      final handCard = tester.widget<CardFace>(handFinder.first);
      final playedCard = tester.widget<CardFace>(
        find.descendant(of: zones.first, matching: find.byType(CardFace)).first,
      );
      final handRect = tester.getRect(find.byType(HandFan));
      final exposed =
          (handRect.width - 24 - handCard.width) / (c.hand.length - 1);
      expect(handCard.width * .4, greaterThanOrEqualTo(13));
      expect(exposed, greaterThanOrEqualTo(22));
      expect(playedCard.width / handCard.width, closeTo(1.4, .01));
      expect(
        tester.getSize(find.widgetWithText(OutlinedButton, '提示')).height,
        greaterThanOrEqualTo(44),
      );
      File('/work/dist/牌面尺寸-${size.width.toInt()}.json').writeAsStringSync(
        jsonEncode({
          'viewport': [size.width, size.height],
          'handWidth': handCard.width,
          'playedWidth': playedCard.width,
          'handCornerFont': handCard.width * .4,
          'playedCornerFont': playedCard.width * .4,
          'exposedWidth': exposed,
          'handCount': c.hand.length,
          'handHitHeight': handRect.height,
        }),
      );
      await capture('三家独立出牌-${size.width.toInt()}');
    }
    tester.view.physicalSize = const Size(844, 390);
    final transcript = <Map<String, dynamic>>[];
    int steps = 0;
    while (g.phase != 'over' && steps++ < 600) {
      final seat = g.turn;
      final cards = choose(g.hands[seat], g.target);
      final action = cards.isEmpty ? 'pass' : 'play';
      expect(g.act(seat, action, cards: cards), null);
      transcript.add({'seat': seat, 'action': action, 'cards': cards});
    }
    expect(g.phase, 'over');
    expect(g.hands[g.winner], isEmpty);
    expect(g.scores.reduce((a, b) => a + b), 0);
    final unit = g.bid * g.multiplier;
    for (int i = 0; i < 3; i++) {
      expect(
        g.scores[i],
        (i == g.landlord ? 2 : -1) * (g.winner == g.landlord ? 1 : -1) * unit,
      );
    }
    expect(g.multiplier, (1 << g.bombCount) * (g.springApplied ? 2 : 1));
    c.view = g.snapshot(c.self);
    c.update();
    await tester.pumpAndSettle();
    await capture('终图-真实结算');
    final evidence = {
      'aiGame': {
        'steps': steps,
        'bid': g.bid,
        'multiplier': g.multiplier,
        'bombCount': g.bombCount,
        'springApplied': g.springApplied,
        'winner': g.winner,
        'landlord': g.landlord,
        'scores': g.scores,
        'remaining': g.hands.map((h) => h.length).toList(),
        'actions': transcript,
      },
    };
    for (final size in [const Size(568, 320), const Size(640, 360)]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      await capture('小屏-真实结算-${size.width.toInt()}');
      expect(tester.getRect(find.text('再来一局')).bottom, lessThan(size.height));
      expect(tester.takeException(), null);
    }

    // 额外完整发牌，农民合法过牌，地主 AI 出完，验证实际春天路径。
    final springGame = GameState();
    expect(springGame.act(0, 'bid', value: 3), null);
    int springSteps = 0;
    while (springGame.phase != 'over' && springSteps++ < 600) {
      final seat = springGame.turn;
      final cards = seat == springGame.landlord
          ? choose(springGame.hands[seat], springGame.target)
          : <int>[];
      expect(
        springGame.act(seat, cards.isEmpty ? 'pass' : 'play', cards: cards),
        null,
      );
    }
    expect(springGame.phase, 'over');
    expect(springGame.springApplied, true);
    expect(springGame.multiplier, 2 * (1 << springGame.bombCount));
    expect(springGame.scores, [
      6 * springGame.multiplier,
      -3 * springGame.multiplier,
      -3 * springGame.multiplier,
    ]);
    c.view = springGame.snapshot(0);
    c.update();
    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();
    expect(find.textContaining('春天加倍'), findsOneWidget);
    await capture('补充-真实春天结算');
    evidence['springGame'] = {
      'steps': springSteps,
      'scores': springGame.scores,
      'bid': springGame.bid,
      'multiplier': springGame.multiplier,
      'bombCount': springGame.bombCount,
      'springApplied': springGame.springApplied,
    };
    await tester.runAsync(
      () => File('/work/dist/真实对局验证.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert(evidence)),
    );
    await tester.tap(find.text('返回菜单'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
