import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doudizhu/main.dart';
import 'package:doudizhu/ui/game_app.dart';
import 'package:doudizhu/ui/asset_menu_button.dart';
import 'package:doudizhu/ui/table_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('两种横屏首页对局结算设置与首次首页帧', (t) async {
    final font = File('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc')
        .readAsBytesSync();
    for (final family in ['Roboto', 'Ahem', 'sans-serif']) {
      await (FontLoader(
        family,
      )..addFont(Future.value(ByteData.sublistView(font)))).load();
    }
    final icons = File(
      '../../sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
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
    final orientations = <List<dynamic>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemChrome.setPreferredOrientations')
            orientations.add(List.from(call.arguments as List));
          return null;
        });
    t.view.devicePixelRatio = 1;
    for (final size in [const Size(844, 390), const Size(640, 360)]) {
      t.view.physicalSize = size;
      final key = GlobalKey();
      await t.pumpWidget(RepaintBoundary(key: key, child: const DoudizhuApp()));
      final c = (t.state(find.byType(GameApp)) as dynamic).c as TableController;
      await t.runAsync(() async {
        for (final file in Directory(
          'assets/art',
        ).listSync().whereType<File>().where((f) => f.path.endsWith('.webp'))) {
          await precacheImage(AssetImage(file.path), key.currentContext!);
        }
      });
      Future<void> capture(String name, {bool settle = true}) async {
        if (settle)
          await t.pumpAndSettle();
        else
          await t.pump();
        expect(t.takeException(), null);
        final visible = t
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data ?? '')
            .join('\n');
        expect(
          RegExp('田园|乡村|牧歌|田野|茶馆|一副好牌|无需账号|两位 AI|离线 · 好牌友').hasMatch(visible),
          false,
        );
        await t.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          File('../../dist/2.1.2-${size.width.toInt()}-$name.png')
              .writeAsBytesSync(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      expect(
        orientations.every(
          (v) =>
              v.length == 2 &&
              v.every((x) => x.toString().contains('landscape')),
        ),
        true,
      );
      await capture('首次首页帧', settle: false);
      await capture('首页');
      final gesture = await t.startGesture(
        t.getCenter(find.bySemanticsLabel('单机')),
      );
      await t.pump(const Duration(milliseconds: 120));
      await capture('按钮按下', settle: false);
      await gesture.cancel();
      await t.pumpAndSettle();
      // Actual menu settings navigation, then all four tempo controls.
      await t.tap(find.bySemanticsLabel('难度'));
      await t.pumpAndSettle();
      expect(find.text('难度'), findsOneWidget);
      c.screen = 'audio';
      c.update();
      await capture('设置');
      expect(find.text('极速'), findsOneWidget);
      c.single();
      c.view = {
        ...c.view!,
        'phase': 'play',
        'turn': 0,
        'landlord': 1,
        'owner': 2,
        'bid': 3,
        'multiplier': 2,
        'target': {'type': '单张', 'high': 7, 'length': 1, 'chain': 1},
        'hands': [
          [0, 4, 5, 8, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48, 52, 53],
          [1, 9, 17, 25, 33],
          [2, 10, 18, 26, 34, 42],
        ],
        'recent': [
          [0, 4, 8],
          [52],
          [12, 16, 20, 24, 28],
        ],
        'passed': [false, false, false],
      };
      c.update();
      await capture('对局');
      c.view = {
        ...c.view!,
        'phase': 'over',
        'winner': 1,
        'scores': [-12, 24, -12],
      };
      c.update();
      await capture('结算');
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      final disabledKey = GlobalKey();
      int clicks = 0;
      await t.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: disabledKey,
            child: Scaffold(
              backgroundColor: const Color(0xffeee7d4),
              body: Center(
                child: SizedBox(
                  width: 280,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AssetMenuButton(
                        label: '单机',
                        asset: 'single',
                        onPressed: () => clicks++,
                        height: 64,
                      ),
                      const SizedBox(height: 24),
                      const AssetMenuButton(
                        label: '单机',
                        asset: 'single',
                        onPressed: null,
                        height: 64,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.bySemanticsLabel('单机').last);
      await t.pumpAndSettle();
      expect(clicks, 0);
      await t.runAsync(() async {
        final boundary =
            disabledKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('../../dist/2.1.2-${size.width.toInt()}-禁用态.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    }
  });
}
